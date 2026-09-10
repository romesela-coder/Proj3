import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates small pieces of editable metadata on device. Saving never waits
/// for the model; deterministic fallbacks are returned whenever it is absent.
enum LocalMetadataGenerator {
    static func title(
        for note: String,
        projectName: String? = nil,
        type: EntryType? = nil
    ) async -> String {
        let fallback = Entry.makeTitle(from: note)

        #if canImport(FoundationModels)
        if #available(iOS 26, *), await FoundationModelsSuggester.isAvailable {
            do {
                let generated = try await FoundationMetadataGenerator.title(
                    for: note,
                    projectName: projectName,
                    type: type
                )
                if !generated.isEmpty,
                   !isProjectOnlyTitle(generated, projectName: projectName) {
                    return generated
                }
            } catch {}
        }
        #endif

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
