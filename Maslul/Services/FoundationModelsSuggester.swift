#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Classification on Apple's on-device model (§13).
///
/// The whole file is compiled out on SDKs older than iOS 26, so the app still
/// builds — and still works — on toolchains and devices that have never heard
/// of `SystemLanguageModel`.
///
/// Two constraints from the spec shape everything here:
///
/// 1. **A fresh session per entry.** The context window is small (a few
///    thousand tokens), and feeding more text into a small window lowers answer
///    quality rather than raising it. One entry, one session, a tiny structured
///    output.
/// 2. **On device only.** No Private Cloud Compute, no external provider, even
///    where the API would allow it. That is a product decision, not a technical
///    limit — without certainty that nothing leaves the phone there is no
///    honesty, and without honesty the journal is worth nothing in a year.
@available(iOS 26, *)
struct FoundationModelsSuggester: Suggesting {
    var sourceLabel: String { "מודל מקומי על המכשיר" }

    /// Entries are short by design; this only guards against a pathological
    /// paste. The point is to stay far inside the window, not to fill it.
    private static let bodyLimit = 1_200

    static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available: return true
        default: return false
        }
    }

    static var availabilityNote: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "המודל המקומי פעיל. ההצעות בסידור השבועי מגיעות ממנו, והכל רץ על המכשיר."
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "המכשיר הזה לא תומך ב-Apple Intelligence. ההצעות מבוססות מילות מפתח."
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence כבוי. אפשר להפעיל אותו בהגדרות המכשיר."
            case .modelNotReady:
                return "המודל עדיין יורד או לא מוכן. ההצעות יחזרו אליו לבד."
            @unknown default:
                return "המודל המקומי לא זמין כרגע. ההצעות מבוססות מילות מפתח."
            }
        @unknown default:
            return "המודל המקומי לא זמין כרגע. ההצעות מבוססות מילות מפתח."
        }
    }

    // MARK: - Structured output
    //
    // Deliberately thin: three short strings. A wide schema costs tokens and
    // buys nothing here.

    @Generable
    struct Classification {
        @Guide(description: "One of: win, learning, friction, decision, goal, people")
        var type: String

        @Guide(description: "Exact project name from the provided list, or empty if none fits")
        var project: String

        @Guide(description: "One of: S, M, L")
        var effort: String
    }

    // MARK: - Suggest

    func suggest(for entry: Entry, projects: [Project], goals: [Goal]) async -> Suggestion {
        // Start from the heuristic so a model failure is never worse than no
        // model at all.
        var suggestion = HeuristicSuggester().classify(entry, projects: projects, goals: goals)

        let selectable = projects.filter(\.isSelectable)
        guard Self.isAvailable else { return suggestion }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(for: entry, projects: selectable),
                generating: Classification.self
            )
            let result = response.content

            if let type = EntryType(rawValue: result.type.trimmed.lowercased()) {
                suggestion.type = type
            }
            if let effort = Effort(rawValue: result.effort.trimmed.uppercased()) {
                suggestion.effort = effort
            }
            // Only accept a project the user actually has. A name the model
            // invented is worse than no suggestion.
            let name = result.project.trimmed
            if !name.isEmpty,
               let match = selectable.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                suggestion.project = match
            }
        } catch {
            // Availability can lapse mid-session — low battery, model unloaded.
            // The heuristic result already in hand is the answer.
        }

        return suggestion
    }

    // MARK: - Prompt
    //
    // Written in English even though the entries are Hebrew: the model is
    // stronger at instruction-following in English, and the output tokens are
    // fixed identifiers that never reach the user as text.

    private static let instructions = """
    You classify a single entry from a personal career journal.
    Answer only with the requested fields. Do not explain.

    Types:
    - win: something done that had an outcome
    - learning: a skill, technology, or insight about how the business works
    - friction: a rejection, harsh feedback, a stall, a mistake
    - decision: what was decided, the alternatives, the assumption behind it
    - goal: a quarterly goal or an update on progress toward one
    - people: who you helped, who helped you, cross-team collaboration

    Effort: S for something under a day, M for a few days, L for a week or more.
    Prefer friction over win when the entry describes something that went wrong.
    """

    private static func prompt(for entry: Entry, projects: [Project]) -> String {
        let body = String(entry.body.prefix(bodyLimit))
        let names = projects.map(\.name).joined(separator: ", ")
        let list = names.isEmpty ? "(none)" : names
        return """
        Projects: \(list)

        Entry:
        \(body)
        """
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
#endif
