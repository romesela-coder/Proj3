import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates small pieces of editable metadata on device. Saving never waits
/// for the model; deterministic fallbacks are returned whenever it is absent.
enum LocalMetadataGenerator {
    private static let logger = Logger(subsystem: "com.romesela.maslul", category: "TitleGeneration")

    static func title(
        for note: String,
        projectName: String? = nil,
        type: EntryType? = nil
    ) async -> String {
        // Speech transcription may prepend bidirectional control characters
        // (for example U+200F). They are useful for display, but can make the
        // language detector reject an otherwise supported Hebrew prompt.
        let modelNote = removingInvisibleDirectionControls(from: note)
        let fallback = extractiveTitle(from: modelNote)

        #if canImport(FoundationModels)
        if #available(iOS 26, *), await FoundationModelsSuggester.isAvailable {
            do {
                logger.info("Starting local title generation")
                let generated = try await FoundationMetadataGenerator.title(
                    for: modelNote,
                    projectName: projectName,
                    type: type
                )
                if !generated.isEmpty,
                   !isProjectOnlyTitle(generated, projectName: projectName) {
                    logger.info("Local title generation succeeded")
                    return generated
                }
                logger.error("Local title generation returned an unusable title")
            } catch {
                logger.error("Local title generation failed: \(String(describing: error), privacy: .public)")
            }
        } else if #available(iOS 26, *) {
            let availabilityNote = await FoundationModelsSuggester.availabilityNote
            logger.error("Local title model unavailable: \(availabilityNote, privacy: .public)")
        }
        #endif

        logger.info("Using deterministic fallback title")
        return fallback
    }

    static func emoji(for name: String, fallback: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), await FoundationModelsSuggester.isAvailable {
            do {
                let generated = try await FoundationMetadataGenerator.emoji(for: name)
                if isEmoji(generated) { return generated }
            } catch {}
        }
        #endif

        return fallback
    }

    private static func isProjectOnlyTitle(_ title: String, projectName: String?) -> Bool {
        guard let projectName, !projectName.isEmpty else { return false }
        return normalized(title) == normalized(projectName)
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func removingInvisibleDirectionControls(from value: String) -> String {
        let filtered = value.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069, 0xFEFF:
                return false
            default:
                return true
            }
        }
        return String(String.UnicodeScalarView(filtered))
    }

    private static func extractiveTitle(from note: String) -> String {
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstThought = clean
            .split(whereSeparator: { ".!?\n".contains($0) })
            .first
            .map(String.init) ?? clean
        let edgeCharacters = CharacterSet.punctuationCharacters
            .union(.symbols)
            .union(.controlCharacters)
        let originalWords = firstThought
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: edgeCharacters) }
            .filter { !$0.isEmpty }

        let fillerWords: Set<String> = [
            "אה", "אמ", "אוקיי", "כאילו", "בעצם", "ממ", "מממ", "טוב",
            "בוא", "בואי", "בואו", "רגע", "סתם", "כזה", "כזאת",
            "אני", "אנחנו", "זה", "זאת", "הזה", "הזאת",
            "uh", "um", "okay", "well", "like", "actually", "basically",
            "i", "we", "this", "that"
        ]

        var seen: Set<String> = []
        let meaningful = originalWords.filter { word in
            let key = word.lowercased()
            guard !fillerWords.contains(key) else { return false }
            return seen.insert(key).inserted
        }
        let chosen = meaningful.count >= 2 ? meaningful : originalWords
        let title = chosen.prefix(6).joined(separator: " ")
        return title.isEmpty ? Entry.makeTitle(from: note) : title
    }

    private static func isEmoji(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.contains { $0.properties.isEmoji }
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
private enum FoundationMetadataGenerator {
    @Generable
    struct GeneratedTitle {
        @Guide(description: "A concise 2 to 6 word memory cue in the note's language. It names the action, decision, outcome, tension, or person—not merely the topic.")
        var title: String
    }

    @Generable
    struct GeneratedEmoji {
        @Guide(description: "Exactly one emoji that best represents the named project or category.")
        var emoji: String
    }

    static func title(
        for note: String,
        projectName: String?,
        type: EntryType?
    ) async throws -> String {
        let session = LanguageModelSession(instructions: """
        Create a short memory cue for one personal journal entry.
        Preserve the language of the entry and use 2 to 6 words.
        Capture the specific action, decision, outcome, tension, or person involved.
        Prefer a verb-led phrase when the writer plans to do something.
        Never return only a topic, category, or project name.
        Do not explain, add quotes, or use generic labels such as Note, Update, or Project.
        """)
        let project = projectName.flatMap { $0.isEmpty ? nil : $0 } ?? "None"
        let entryType = type?.title ?? "Unclassified"
        let response = try await session.respond(
            to: """
            Known project: \(project)
            Entry type: \(entryType)

            Note:
            \(String(note.prefix(1_200)))
            """,
            generating: GeneratedTitle.self
        )
        return cleanTitle(response.content.title)
    }

    static func emoji(for name: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
        Match a project or category name to one clear, familiar emoji.
        Return a single emoji only. Prefer a concrete subject emoji over a generic folder.
        """)
        let response = try await session.respond(
            to: String(name.prefix(120)),
            generating: GeneratedEmoji.self
        )
        let clean = response.content.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.first.map(String.init) ?? ""
    }

    private static func cleanTitle(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        return trimmed.split(whereSeparator: \.isWhitespace).prefix(8).joined(separator: " ")
    }
}
#endif
