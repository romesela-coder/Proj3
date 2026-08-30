import Foundation

/// What the tidy screen offers for one entry.
struct Suggestion {
    var type: EntryType?
    var project: Project?
    var effort: Effort?
    var goal: Goal?

    var isEmpty: Bool { type == nil && project == nil && effort == nil && goal == nil }
}

/// §13 puts classification on Apple's on-device model. That model needs
/// iOS 26 with Apple Intelligence enabled, and it is absent from the simulator,
/// so the shipping implementation here is the fallback the spec already
/// requires: the screen opens either way, and every suggestion is correctable
/// in one tap.
///
/// This is keyword matching, not a language model, and the UI says so. The
/// seam is deliberate — a `FoundationModelsSuggester` conforming to the same
/// protocol drops in without touching the flow.
protocol Suggesting {
    var sourceLabel: String { get }
    func suggest(for entry: Entry, projects: [Project], goals: [Goal]) -> Suggestion
}

struct HeuristicSuggester: Suggesting {
    var sourceLabel: String { "מבוסס מילות מפתח, לא מודל" }

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

    func suggest(for entry: Entry, projects: [Project], goals: [Goal]) -> Suggestion {
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
