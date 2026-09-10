import Foundation

/// Metadata suggested while the user is writing an entry.
struct Suggestion {
    var type: EntryType?
    var project: Project?
    var effort: Effort?
    var goal: Goal?

    var isEmpty: Bool { type == nil && project == nil && effort == nil && goal == nil }
}

/// Two implementations sit behind this: Apple's on-device model where the
/// hardware and OS allow it (§13), and keyword matching everywhere else.
///
/// Async because the model is; `@MainActor` so SwiftData objects never cross
/// an actor boundary.
@MainActor
protocol Suggesting {
    var sourceLabel: String { get }
    func suggest(for entry: Entry, projects: [Project], goals: [Goal]) async -> Suggestion
}

/// The fallback the spec requires: the tidy screen opens either way, and every
/// suggestion is one tap from being corrected. Keyword matching, not a model,
/// and the UI says so.
struct HeuristicSuggester: Suggesting {
    var sourceLabel: String { "Keyword matching" }

    // Friction first: it is the most specific, and the type most likely to be
    // quietly dropped if the guess goes the flattering way (§16).
    private static let rules: [(EntryType, [String])] = [
        (.friction, ["דחה", "דחתה", "דחו", "ריג׳קט", "ריגקט", "נתקע", "תקלה", "טעות",
                     "נכשל", "לא הצלחתי", "פספס", "ויכוח", "נעלב", "מתסכל", "תסכול",
                     "באג", "לא אישרו", "בלי החלטה", "מציק", "לא הסכמתי"]),
        (.decision, ["החלטנו", "החלטתי", "בחרנו", "בחרתי", "ההנחה", "חלופה", "הכרענו",
                     "החלטה", "להקפיא", "לא לקחת", "לא לעבור"]),
        (.learning, ["למדתי", "הבנתי", "גיליתי", "קראתי", "תובנה", "לראשונה",
                     "התברר", "הסתבר", "לומד"]),
        (.people, ["עזרתי", "עזר לי", "עזרה", "מנטור", "פגישה עם", "שיתוף פעולה",
                   "המלצתי", "ישבתי עם", "pairing", "צמוד ל"]),
        (.goal, ["מטרת הרבעון", "מטרה", "יעד רבעוני"]),
        (.win, ["סגרנו", "סגרתי", "סיימתי", "שחררנו", "השקנו", "הצלחתי", "צמצמתי",
                "שיפרתי", "אישרו", "חסך", "בזמן", "עבר", "הרצתי"])
    ]

    private static let heavy = ["שבועות", "שלושה שבועות", "חודש", "חודשים", "מסמך העיצוב"]
    private static let medium = ["ימים", "יומיים", "שלושה ימים", "שעתיים"]

    func suggest(for entry: Entry, projects: [Project], goals: [Goal]) async -> Suggestion {
        classify(entry, projects: projects, goals: goals)
    }

    /// Synchronous, so the card can show something the instant it appears while
    /// the model — if there is one — is still thinking.
    func classify(_ entry: Entry, projects: [Project], goals: [Goal]) -> Suggestion {
        let body = entry.body.lowercased()

        var suggestion = Suggestion()
        suggestion.type = entry.type ?? Self.rules.first { _, keys in
            keys.contains { body.contains($0.lowercased()) }
        }?.0

        suggestion.project = entry.project ?? Self.bestMatch(in: body, among: projects)
        suggestion.effort = entry.effort ?? Self.effort(for: body)
        suggestion.goal = entry.goal ?? Self.bestGoal(in: body, among: goals, project: suggestion.project)

        return suggestion
    }

    /// Matches a project by its own name appearing in the text — honest, and it
    /// gets better as the user names projects the way they talk about them.
    private static func bestMatch(in body: String, among projects: [Project]) -> Project? {
        let candidates = projects.filter(\.isSelectable)
        return candidates.first { project in
            let words = project.name
                .lowercased()
                .split(separator: " ")
                .filter { $0.count >= 4 }
            return words.contains { body.contains($0) }
        }
    }

    private static func effort(for body: String) -> Effort? {
        if heavy.contains(where: { body.contains($0) }) { return .l }
        if medium.contains(where: { body.contains($0) }) { return .m }
        if body.count > 220 { return .m }
        if body.count < 60 { return .s }
        return nil
    }

    private static func bestGoal(in body: String, among goals: [Goal], project: Project?) -> Goal? {
        let open = goals.filter(\.isCurrent)
        guard !open.isEmpty else { return nil }

        return open.first { goal in
            let words = (goal.title + " " + (goal.metric ?? ""))
                .lowercased()
                .split(separator: " ")
                .filter { $0.count >= 4 }
            return words.contains { body.contains($0) }
        }
    }
}


// MARK: - Picking one

enum SuggesterFactory {
    /// The on-device model when the device can actually run it, keyword
    /// matching otherwise. Nothing else in the app has to know which it got.
    @MainActor
    static func make() -> any Suggesting {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), FoundationModelsSuggester.isAvailable {
            return FoundationModelsSuggester()
        }
        #endif
        return HeuristicSuggester()
    }

    /// Why the model isn't being used, when it isn't. Shown in settings so the
    /// answer is never a mystery.
    @MainActor
    static var availabilityNote: String {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return FoundationModelsSuggester.availabilityNote
        }
        return "The local model requires iOS 26. This device is running an earlier version."
        #else
        return "This build uses an SDK older than iOS 26, so the local model is not included."
        #endif
    }
}
