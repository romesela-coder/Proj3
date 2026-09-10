import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SpeechDictationController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var errorMessage: String?

    private var modernSessionStorage: AnyObject?
    private var legacySession: LegacyDictationSession?
    private var finishingTask: Task<Void, Never>?

    func clearError() {
        errorMessage = nil
    }

    func toggle(text: String, language: String?, update: @escaping (String) -> Void) {
        if isRecording {
            stop()
        } else {
            Task { await start(text: text, language: language, update: update) }
        }
    }

    func stop() {
        Task { await stopAndWait() }
    }

    /// Finalizes the last volatile phrase before callers consume the text.
    /// Saving a note while this is still running can otherwise persist a stale
    /// transcript and start title generation while Speech still owns its model.
    func stopAndWait() async {
        if let finishingTask {
            await finishingTask.value
            return
        }
        guard isRecording else { return }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performStop()
        }
        finishingTask = task
        await task.value
        finishingTask = nil
    }

    private func performStop() async {
        isRecording = false

        if #available(iOS 26.0, *),
           let modernSession = modernSessionStorage as? ModernDictationSession {
            modernSessionStorage = nil
            await modernSession.finish()
        } else {
            legacySession?.stop()
            legacySession = nil
            deactivateAudioSession()
        }
    }

    private func start(
        text: String,
        language: String?,
        update: @escaping (String) -> Void
    ) async {
        errorMessage = nil

        guard await speechPermission() == .authorized else {
            errorMessage = "Speech recognition permission is required."
            return
        }
        guard await microphonePermission() else {
            errorMessage = "Microphone permission is required."
            return
        }

        let locale = preferredLocale(for: language)

        do {
            try configureAudioSession()

            if #available(iOS 26.0, *) {
                let session = try await ModernDictationSession(
                    locale: locale,
                    prefix: text,
                    update: update,
                    failure: { [weak self] message in
                        Task { @MainActor in
                            guard let self else { return }
                            self.errorMessage = message
                            self.isRecording = false
                            self.modernSessionStorage = nil
                            self.deactivateAudioSession()
                        }
                    }
                )
                modernSessionStorage = session
                try await session.start()
            } else {
                let session = try LegacyDictationSession(
                    locale: locale,
                    prefix: text,
                    update: update,
                    failure: { [weak self] message in
                        Task { @MainActor in
                            guard let self else { return }
                            self.errorMessage = message
                            self.isRecording = false
                            self.legacySession = nil
                            self.deactivateAudioSession()
                        }
                    }
                )
                legacySession = session
                try session.start()
            }

            isRecording = true
        } catch let error as DictationError {
            errorMessage = error.message
            modernSessionStorage = nil
            legacySession = nil
            deactivateAudioSession()
        } catch {
            errorMessage = "Could not start dictation."
            modernSessionStorage = nil
            legacySession = nil
            deactivateAudioSession()
        }
    }

    private func preferredLocale(for keyboardLanguage: String?) -> Locale {
        let identifier = keyboardLanguage ?? Locale.preferredLanguages.first ?? "en-US"
        if identifier.lowercased().hasPrefix("he") {
            return Locale(identifier: "he-IL")
        }
        if identifier.lowercased().hasPrefix("en") {
            return Locale(identifier: "en-US")
        }
        return Locale(identifier: identifier)
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func speechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private func microphonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission {
                continuation.resume(returning: $0)
            }
        }
    }
}

private enum DictationError: Error {
    case unsupportedLanguage
    case unavailable
    case modelInstallFailed
    case audioSetupFailed

    var message: String {
        switch self {
        case .unsupportedLanguage:
            return "Dictation is unavailable for this language."
        case .unavailable:
            return "Dictation is temporarily unavailable."
        case .modelInstallFailed:
            return "The dictation language could not be prepared."
        case .audioSetupFailed:
            return "Could not start dictation."
        }
    }
}

@available(iOS 26.0, *)
private final class ModernDictationSession {
    private let audioEngine = AVAudioEngine()
    private let transcriber: DictationTranscriber
    private let analyzer: SpeechAnalyzer
    private let analyzerFormat: AVAudioFormat
    private let prefix: String
    private let update: (String) -> Void
    private let failure: (String) -> Void

    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerTask: Task<Void, Error>?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?
    private var hasAudioTap = false
    private var isFinishing = false
    private var finalizedTranscript = ""
    private var volatileTranscript = ""

    init(
        locale requestedLocale: Locale,
        prefix: String,
        update: @escaping (String) -> Void,
        failure: @escaping (String) -> Void
    ) async throws {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw DictationError.unsupportedLanguage
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
        let modules: [any SpeechModule] = [transcriber]
        let status = await AssetInventory.status(forModules: modules)
        guard status != .unsupported else { throw DictationError.unsupportedLanguage }

        if status != .installed {
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                    try await request.downloadAndInstall()
                }
            } catch {
                throw DictationError.modelInstallFailed
            }
        }

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
            throw DictationError.unavailable
        }

        self.transcriber = transcriber
        self.analyzer = SpeechAnalyzer(modules: modules)
        self.analyzerFormat = format
        self.prefix = prefix
        self.update = update
        self.failure = failure
    }

    func start() async throws {
        let inputNode = audioEngine.inputNode
        let captureFormat = inputNode.outputFormat(forBus: 0)
        guard captureFormat.sampleRate > 0, captureFormat.channelCount > 0 else {
            throw DictationError.audioSetupFailed
        }

        if captureFormat != analyzerFormat {
            converter = AVAudioConverter(from: captureFormat, to: analyzerFormat)
            guard converter != nil else { throw DictationError.audioSetupFailed }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("maslul-dictation-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        recordingURL = url
        recordingFile = try AVAudioFile(forWriting: url, settings: captureFormat.settings)

        let (inputSequence, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        inputContinuation = continuation

        resultsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        finalizedTranscript += text
                        volatileTranscript = ""
                    } else {
                        volatileTranscript = text
                    }
                    publishTranscript()
                }
            } catch is CancellationError {
                // Expected only when the owning view disappears.
            } catch {
                if !isFinishing {
                    failure("Dictation stopped unexpectedly.")
                }
            }
        }

        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        analyzerTask = Task { [analyzer] in
            try await analyzer.start(inputSequence: inputSequence)
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: 4_096,
            format: captureFormat
        ) { [weak self] buffer, time in
            guard let self else { return }
            do {
                try recordingFile?.write(from: buffer)
                for input in try analyzerInputs(from: buffer, at: time) {
                    inputContinuation?.yield(input)
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.failure("Dictation stopped unexpectedly.")
                }
            }
        }
        hasAudioTap = true
        audioEngine.prepare()
        try audioEngine.start()
    }

    func finish() async {
        guard !isFinishing else { return }
        isFinishing = true
        stopCapturingAudio()

        if let converter {
            let outputCapacity: AVAudioFrameCount = 8_192
            while let output = AVAudioPCMBuffer(
                pcmFormat: analyzerFormat,
                frameCapacity: outputCapacity
            ) {
                var conversionError: NSError?
                let status = converter.convert(to: output, error: &conversionError) { _, state in
                    state.pointee = .endOfStream
                    return nil
                }
                if output.frameLength > 0 {
                    inputContinuation?.yield(AnalyzerInput(buffer: output))
                }
                if status != .haveData { break }
            }
        }

        inputContinuation?.finish()
        inputContinuation = nil

        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            _ = try await analyzerTask?.value
            await resultsTask?.value
        } catch {
            await analyzer.cancelAndFinishNow()
        }

        cleanup()
        await SpeechModels.endRetention()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopCapturingAudio() {
        audioEngine.stop()
        if hasAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasAudioTap = false
        }
        recordingFile = nil
    }

    private func analyzerInputs(from buffer: AVAudioPCMBuffer, at time: AVAudioTime) throws -> [AnalyzerInput] {
        guard let converter else {
            return [AnalyzerInput(buffer: buffer)]
        }

        let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let capacity = max(1, AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else {
            throw DictationError.audioSetupFailed
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, state in
            if suppliedInput {
                state.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            state.pointee = .haveData
            return buffer
        }

        if let conversionError { throw conversionError }
        guard status == .haveData, output.frameLength > 0 else { return [] }
        return [AnalyzerInput(buffer: output)]
    }

    private func publishTranscript() {
        let transcript = finalizedTranscript + volatileTranscript
        let needsSpace = !prefix.isEmpty
            && prefix.last?.isWhitespace != true
            && transcript.first?.isWhitespace != true
            && !transcript.isEmpty
        update(prefix + (needsSpace ? " " : "") + transcript)
    }

    private func cleanup() {
        analyzerTask = nil
        resultsTask = nil
        converter = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    deinit {
        if hasAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine.stop()
        inputContinuation?.finish()
        analyzerTask?.cancel()
        resultsTask?.cancel()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
    }
}

private final class LegacyDictationSession {
    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer
    private let prefix: String
    private let update: (String) -> Void
    private let failure: (String) -> Void
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasAudioTap = false

    init(
        locale: Locale,
        prefix: String,
        update: @escaping (String) -> Void,
        failure: @escaping (String) -> Void
    ) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw DictationError.unavailable
        }
        self.recognizer = recognizer
        self.prefix = prefix
        self.update = update
        self.failure = failure
    }

    func start() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasAudioTap = true
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [prefix, update, failure] result, error in
            if let result {
                let transcript = result.bestTranscription.formattedString
                let separator = prefix.isEmpty || prefix.last?.isWhitespace == true || transcript.isEmpty ? "" : " "
                update(prefix + separator + transcript)
            } else if error != nil {
                failure("Dictation stopped unexpectedly.")
            }
        }
    }

    func stop() {
        audioEngine.stop()
        request?.endAudio()
        if hasAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasAudioTap = false
        }
        task?.cancel()
        task = nil
        request = nil
    }

    deinit {
        stop()
    }
}
