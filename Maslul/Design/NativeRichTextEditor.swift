import SwiftUI

private struct MaslulMentionValue: Codable, Hashable, Sendable {
    let token: String
    let presentation: String
}

private enum MaslulMentionTokenAttribute: AttributedStringKey {
    typealias Value = MaslulMentionValue
    static let name = "com.romesela.maslul.mention-token"
    static let inheritedByAddedText = false
}

/// iOS 26 owns editing, selection, keyboard integration and formatting. This
/// view deliberately contains no TextKit bridge and never rebuilds the text
/// while the user types.
struct NativeRichTextEditor: View {
    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection

    let placeholder: String
    var fontSize: CGFloat = 18
    var scrolls = false
    var autoFocus = false
    var focusRequest = 0
    var onFocus: (() -> Void)?
    var onPlainTextChange: ((String) -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isApplyingListContinuation = false
    @State private var isRepairingMention = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.characters.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: fontSize))
                    .foregroundStyle(Palette.meta)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text, selection: $selection)
                .font(.system(size: fontSize))
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .scrollDisabled(!scrolls)
                .fixedSize(horizontal: false, vertical: !scrolls)
                .focused($isFocused)
                .textInputFormattingControlVisibility(.hidden, for: .inputAssistant)
                .textInputFormattingControlVisibility(.visible, for: .contextMenu)
                .background(
                    ChecklistTapObserver { location in
                        toggleChecklist(at: location)
                    }
                )
        }
        .onChange(of: text) { oldValue, newValue in
            if isRepairingMention {
                isRepairingMention = false
                onPlainTextChange?(NativeRichTextMentions.plainText(in: newValue))
                return
            }
            if isApplyingListContinuation {
                isApplyingListContinuation = false
                onPlainTextChange?(NativeRichTextMentions.plainText(in: newValue))
                return
            }
            if NativeRichTextMentions.repairEditedMention(
                from: oldValue,
                text: &text,
                selection: &selection
            ) {
                isRepairingMention = true
                return
            }
            if continueListAfterReturn(from: oldValue, to: newValue) {
                return
            }
            onPlainTextChange?(NativeRichTextMentions.plainText(in: newValue))
        }
        .onChange(of: isFocused) { _, focused in
            if focused { onFocus?() }
        }
        .onChange(of: focusRequest) {
            isFocused = true
        }
        .onAppear {
            guard autoFocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isFocused = true
            }
        }
    }

    /// TextEditor intentionally treats semantic content as app-owned. Our
    /// visible list controls use stable textual delimiters, so continue them
    /// after a single Return without involving TextKit or resetting selection.
    private func continueListAfterReturn(
        from oldValue: AttributedString,
        to newValue: AttributedString
    ) -> Bool {
        let oldBody = String(oldValue.characters)
        let newBody = String(newValue.characters)
        guard let insertionOffset = insertedNewlineOffset(from: oldBody, to: newBody) else {
            return false
        }

        let oldSource = oldBody as NSString
        guard oldSource.length > 0 else { return false }
        let probe = min(max(0, insertionOffset - 1), oldSource.length - 1)
        var paragraph = oldSource.paragraphRange(for: NSRange(location: probe, length: 0))
        while paragraph.length > 0 {
            let final = oldSource.substring(with: NSRange(location: NSMaxRange(paragraph) - 1, length: 1))
            guard final == "\n" || final == "\r" else { break }
            paragraph.length -= 1
        }
        let line = oldSource.substring(with: paragraph)
        guard let prefix = listPrefix(in: line) else { return false }

        let content = String(line.dropFirst(prefix.length))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        isApplyingListContinuation = true

        if content.isEmpty {
            text.transform(updating: &selection) { value in
                guard let range = attributedRange(
                    NSRange(location: paragraph.location, length: prefix.length),
                    in: value,
                    body: String(value.characters)
                ) else { return }
                value.replaceSubrange(range, with: AttributedString())
            }
        } else {
            let nextPrefix: String
            switch prefix.kind {
            case .bulleted:
                nextPrefix = "• "
            case .numbered(let number):
                nextPrefix = "\(number + 1). "
            case .checklist:
                nextPrefix = "○ "
            }
            text.transform(updating: &selection) { value in
                let body = String(value.characters)
                guard let range = attributedRange(
                    NSRange(location: insertionOffset + 1, length: 0),
                    in: value,
                    body: body
                ) else { return }
                value.replaceSubrange(range, with: AttributedString(nextPrefix))
            }
        }
        return true
    }

    private func toggleChecklist(at utf16Location: Int) {
        let body = String(text.characters)
        let source = body as NSString
        guard utf16Location >= 0, utf16Location <= source.length else { return }
        let probe = min(utf16Location, max(0, source.length - 1))
        var paragraph = source.paragraphRange(for: NSRange(location: probe, length: 0))
        while paragraph.length > 0 {
            let final = source.substring(with: NSRange(location: NSMaxRange(paragraph) - 1, length: 1))
            guard final == "\n" || final == "\r" else { break }
            paragraph.length -= 1
        }
        guard paragraph.length >= 2 else { return }
        let line = source.substring(with: paragraph)
        let isChecked: Bool
        if line.hasPrefix("○ ") {
            isChecked = false
        } else if line.hasPrefix("✓ ") {
            isChecked = true
        } else {
            return
        }

        text.transform(updating: &selection) { value in
            let currentBody = String(value.characters)
            guard let markerRange = attributedRange(
                NSRange(location: paragraph.location, length: 1),
                in: value,
                body: currentBody
            ) else { return }
            value.replaceSubrange(markerRange, with: AttributedString(isChecked ? "○" : "✓"))

            let contentLocation = paragraph.location + 2
            let contentLength = max(0, paragraph.length - 2)
            guard contentLength > 0,
                  let contentRange = attributedRange(
                    NSRange(location: contentLocation, length: contentLength),
                    in: value,
                    body: String(value.characters)
                  ) else { return }
            value[contentRange].strikethroughStyle = isChecked ? nil : .single
            value[contentRange].foregroundColor = isChecked ? nil : Palette.meta
        }
    }

    private enum ListPrefixKind {
        case bulleted
        case numbered(Int)
        case checklist
    }

    private func listPrefix(in line: String) -> (kind: ListPrefixKind, length: Int)? {
        if line.hasPrefix("• ") {
            return (.bulleted, 2)
        }
        if line.hasPrefix("○ ") || line.hasPrefix("✓ ") {
            return (.checklist, 2)
        }

        let source = line as NSString
        var index = 0
        while index < source.length,
              let scalar = UnicodeScalar(source.character(at: index)),
              CharacterSet.decimalDigits.contains(scalar) {
            index += 1
        }
        guard index > 0, index + 1 < source.length,
              source.substring(with: NSRange(location: index, length: 2)) == ". ",
              let number = Int(source.substring(with: NSRange(location: 0, length: index))) else {
            return nil
        }
        return (.numbered(number), index + 2)
    }

    private func insertedNewlineOffset(from oldBody: String, to newBody: String) -> Int? {
        let old = Array(oldBody.utf16)
        let new = Array(newBody.utf16)
        guard new.count == old.count + 1 else { return nil }

        var prefix = 0
        while prefix < old.count, old[prefix] == new[prefix] {
            prefix += 1
        }
        guard new[prefix] == 10 else { return nil }
        var oldIndex = prefix
        var newIndex = prefix + 1
        while oldIndex < old.count, old[oldIndex] == new[newIndex] {
            oldIndex += 1
            newIndex += 1
        }
        return oldIndex == old.count && newIndex == new.count ? prefix : nil
    }

    private func attributedRange(
        _ range: NSRange,
        in value: AttributedString,
        body: String
    ) -> Range<AttributedString.Index>? {
        guard range.location >= 0, NSMaxRange(range) <= (body as NSString).length else { return nil }
        let stringStart = String.Index(utf16Offset: range.location, in: body)
        let stringEnd = String.Index(utf16Offset: NSMaxRange(range), in: body)
        guard let start = AttributedString.Index(stringStart, within: value),
              let end = AttributedString.Index(stringEnd, within: value) else { return nil }
        return start..<end
    }
}

/// Finds the UITextView owned by SwiftUI's TextEditor and adds one
/// non-cancelling recognizer for checklist markers. Editing, layout and
/// selection remain fully native.
private struct ChecklistTapObserver: UIViewRepresentable {
    let onTap: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onWindowChange = { [weak coordinator = context.coordinator] window, frame in
            coordinator?.install(in: window, nearestTo: frame)
        }
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        context.coordinator.onTap = onTap
        uiView.resolveTextView()
    }

    final class ProbeView: UIView {
        var onWindowChange: ((UIWindow, CGRect) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resolveTextView()
        }

        func resolveTextView() {
            guard let window else { return }
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                onWindowChange?(window, convert(bounds, to: window))
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: (Int) -> Void
        private weak var textView: UITextView?
        private weak var recognizer: UITapGestureRecognizer?

        init(onTap: @escaping (Int) -> Void) {
            self.onTap = onTap
        }

        func install(in window: UIWindow, nearestTo probeFrame: CGRect) {
            let candidates = window.allTextViews.filter(\.isEditable)
            guard let candidate = candidates.min(by: {
                distance(from: $0, to: probeFrame, in: window) <
                    distance(from: $1, to: probeFrame, in: window)
            }) else { return }
            guard candidate !== textView else { return }

            if let recognizer, let textView {
                textView.removeGestureRecognizer(recognizer)
            }
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            candidate.addGestureRecognizer(recognizer)
            self.textView = candidate
            self.recognizer = recognizer
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let textView else { return }
            let point = recognizer.location(in: textView)
            guard let position = textView.closestPosition(to: point) else { return }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            let source = textView.text as NSString
            guard source.length > 0 else { return }
            let probe = min(max(0, offset), source.length - 1)
            let paragraph = source.paragraphRange(for: NSRange(location: probe, length: 0))
            guard paragraph.length >= 2 else { return }
            let prefix = source.substring(with: NSRange(location: paragraph.location, length: 2))
            guard prefix == "○ " || prefix == "✓ ",
                  let markerStart = textView.position(
                    from: textView.beginningOfDocument,
                    offset: paragraph.location
                  ),
                  let markerEnd = textView.position(from: markerStart, offset: 1) else { return }

            let startRect = textView.caretRect(for: markerStart)
            let endRect = textView.caretRect(for: markerEnd)
            let hitRect = startRect.union(endRect).insetBy(dx: -10, dy: -8)
            guard hitRect.contains(point) else { return }
            onTap(paragraph.location)
        }

        private func distance(from textView: UITextView, to frame: CGRect, in window: UIWindow) -> CGFloat {
            let candidateFrame = textView.convert(textView.bounds, to: window)
            let dx = candidateFrame.midX - frame.midX
            let dy = candidateFrame.midY - frame.midY
            return dx * dx + dy * dy
        }
    }
}

private extension UIView {
    var allTextViews: [UITextView] {
        var result = self as? UITextView == nil ? [] : [self as! UITextView]
        for child in subviews {
            result.append(contentsOf: child.allTextViews)
        }
        return result
    }
}

enum NativeRichTextMentions {
    static func query(in text: AttributedString, selection: AttributedTextSelection) -> String? {
        guard let caret = caretIndex(in: text, selection: selection) else { return nil }
        let prefix = text.characters[..<caret]
        guard let at = prefix.lastIndex(of: "@") else { return nil }
        let queryStart = text.characters.index(after: at)
        let query = text.characters[queryStart..<caret]
        guard !query.contains(where: { $0.isWhitespace || $0.isNewline }) else { return nil }
        return String(query)
    }

    static func styledText(_ body: String, tags: [EntryTag]) -> AttributedString {
        applyingStyles(to: AttributedString(body), tags: tags)
    }

    static func applyingStyles(to source: AttributedString, tags: [EntryTag]) -> AttributedString {
        var result = source
        let body = plainText(in: result)
        let nsBody = body as NSString
        var occupied = IndexSet()
        var matches: [(range: NSRange, tag: EntryTag)] = []

        for tag in tags.sorted(by: { $0.name.count > $1.name.count }) {
            guard TagNameRules.isValid(tag.name) else { continue }
            let token = "@\(tag.name)"
            var search = NSRange(location: 0, length: nsBody.length)
            while search.length > 0 {
                let found = nsBody.range(of: token, options: [.caseInsensitive], range: search)
                guard found.location != NSNotFound else { break }
                let indexes = IndexSet(integersIn: found.location..<NSMaxRange(found))
                if hasValidBoundary(after: found, in: nsBody),
                   occupied.intersection(indexes).isEmpty {
                    matches.append((found, tag))
                    occupied.formUnion(indexes)
                }
                let next = NSMaxRange(found)
                search = NSRange(location: next, length: nsBody.length - next)
            }
        }

        for match in matches.sorted(by: { $0.range.location > $1.range.location }) {
            guard let range = attributedRange(match.range, body: body, attributed: result) else { continue }
            result.replaceSubrange(range, with: presentationMention(for: match.tag))
        }
        return result
    }

    static func insert(_ tag: EntryTag, into text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard let caret = caretIndex(in: text, selection: selection) else { return }
        let prefix = text.characters[..<caret]
        guard let at = prefix.lastIndex(of: "@") else { return }
        let queryStart = text.characters.index(after: at)
        guard !text.characters[queryStart..<caret].contains(where: { $0.isWhitespace || $0.isNewline }) else {
            return
        }

        selection = AttributedTextSelection(range: at..<caret)
        var mention = presentationMention(for: tag)
        mention += AttributedString(" ")
        text.replaceSelection(&selection, with: mention)
        if let caret = caretIndex(in: text, selection: selection) {
            selection = AttributedTextSelection(
                insertionPoint: caret,
                typingAttributes: AttributeContainer()
            )
        }
    }

    /// The editor uses the same inline attachment as the original Maslul
    /// mention card. Persistence and search keep the stable `@name` token.
    static func storageText(from presentation: AttributedString) -> AttributedString {
        var result = presentation
        let mentions = presentation.runs.compactMap { run -> (Range<AttributedString.Index>, String)? in
            guard let mention = run[MaslulMentionTokenAttribute.self] else { return nil }
            return (run.range, mention.token)
        }
        for mention in mentions.reversed() {
            result.replaceSubrange(mention.0, with: AttributedString(mention.1))
        }
        return result
    }

    /// TextEditor can place a selection inside our styled label. One deletion
    /// first unwraps the entire visual mention to its canonical `@name`, just
    /// like the original attachment editor, instead of leaving half a card.
    static func repairEditedMention(
        from oldValue: AttributedString,
        text: inout AttributedString,
        selection: inout AttributedTextSelection
    ) -> Bool {
        let malformed = text.runs.compactMap { run -> (Range<AttributedString.Index>, String)? in
            guard let mention = run[MaslulMentionTokenAttribute.self],
                  String(text.characters[run.range]) != mention.presentation else { return nil }
            return (run.range, mention.token)
        }
        if !malformed.isEmpty {
            text.transform(updating: &selection) { updated in
                for mention in malformed.reversed() {
                    updated.replaceSubrange(mention.0, with: AttributedString(mention.1))
                }
            }
            return true
        }

        let oldMentions = oldValue.runs.compactMap { $0[MaslulMentionTokenAttribute.self] }
        guard !oldMentions.isEmpty,
              text.characters.count < oldValue.characters.count else { return false }
        let newMentions = text.runs.compactMap { $0[MaslulMentionTokenAttribute.self] }
        var remaining = newMentions
        guard let removed = oldMentions.first(where: { mention in
            guard let index = remaining.firstIndex(of: mention) else { return true }
            remaining.remove(at: index)
            return false
        }) else { return false }

        let oldCharacters = Array(oldValue.characters)
        let newCharacters = Array(text.characters)
        var insertionOffset = 0
        while insertionOffset < oldCharacters.count,
              insertionOffset < newCharacters.count,
              oldCharacters[insertionOffset] == newCharacters[insertionOffset] {
            insertionOffset += 1
        }
        text.transform(updating: &selection) { updated in
            let insertion = updated.characters.index(
                updated.startIndex,
                offsetBy: min(insertionOffset, updated.characters.count)
            )
            updated.replaceSubrange(insertion..<insertion, with: AttributedString(removed.token))
        }
        return true
    }

    static func plainText(in presentation: AttributedString) -> String {
        String(storageText(from: presentation).characters)
    }

    /// SwiftUI's native AttributedString editor does not support the legacy
    /// NSTextAttachment card, and a programmatically-created HEIC is not a
    /// valid Apple adaptive glyph. Keep the mention atomic through our token
    /// attribute while using only attributes TextEditor renders safely.
    private static func presentationMention(for tag: EntryTag) -> AttributedString {
        let token = "@\(tag.name)"
        let label = [TagMentionVisual.emoji(for: tag), tag.name]
            .compactMap { $0 }
            .joined(separator: " ")
        let presentation = "\u{00A0}\(label)\u{00A0}"
        var result = AttributedString(presentation)
        result.backgroundColor = TagMentionVisual.background(for: tag)
        result.foregroundColor = Palette.ink
        result.font = .system(size: 17, weight: .semibold)
        result[result.startIndex..<result.endIndex][MaslulMentionTokenAttribute.self] = .init(
            token: token,
            presentation: presentation
        )
        return result
    }

    private static func caretIndex(
        in text: AttributedString,
        selection: AttributedTextSelection
    ) -> AttributedString.Index? {
        switch selection.indices(in: text) {
        case .insertionPoint(let index):
            return index
        case .ranges(let ranges):
            // Mentions are only offered for a caret or one ordinary selection.
            // Using the selection's trailing edge also keeps replacement stable
            // during the brief state transition after typing `@`.
            return ranges.ranges.last?.upperBound
        }
    }

    static func contains(_ tag: EntryTag, in body: String) -> Bool {
        let source = body as NSString
        let token = "@\(tag.name)"
        var search = NSRange(location: 0, length: source.length)
        while search.length > 0 {
            let found = source.range(of: token, options: [.caseInsensitive], range: search)
            guard found.location != NSNotFound else { return false }
            if hasValidBoundary(after: found, in: source) { return true }
            let next = NSMaxRange(found)
            search = NSRange(location: next, length: source.length - next)
        }
        return false
    }

    private static func hasValidBoundary(after range: NSRange, in text: NSString) -> Bool {
        let end = NSMaxRange(range)
        guard end < text.length else { return true }
        let next = text.substring(with: NSRange(location: end, length: 1))
        return next.first?.isWhitespace == true || next.first?.isNewline == true
    }

    private static func attributedRange(
        _ range: NSRange,
        body: String,
        attributed: AttributedString
    ) -> Range<AttributedString.Index>? {
        let startIndex = String.Index(utf16Offset: range.location, in: body)
        let endIndex = String.Index(utf16Offset: NSMaxRange(range), in: body)
        guard let start = AttributedString.Index(startIndex, within: attributed),
              let end = AttributedString.Index(endIndex, within: attributed) else { return nil }
        return start..<end
    }
}
