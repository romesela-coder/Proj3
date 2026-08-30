import Foundation

struct TypeCount: Identifiable {
    let type: EntryType
    let count: Int
    var id: String { type.rawValue }
}

/// The one question at the end of the weekly tidy (F2).
///
/// Derived from the data, never generated. A question the numbers don't
/// support is worse than no question.
enum InsightQuestion {
    case staleProject(Project)
    case untouchedGoal(Goal)
    case lowFriction(Int)
    case assignedHeavy(Int)

    var text: String {
        switch self {
        case .staleProject(let project):
            return "הפרויקט \"\(project.name)\" לא הופיע שלושה שבועות. עדיין פעיל?"
        case .untouchedGoal(let goal):
            return "המטרה \"\(goal.title)\" לא קיבלה אף רשומה הרבעון. עדיין רלוונטית?"
        case .lowFriction(let percent):
            return "רק \(percent)% מהרשומות הן חיכוך. מה לא עבד החודש?"
        case .assignedHeavy(let percent):
            return "\(percent)% מהעבודה שתיעדת הוגדרה לך. זה מה שרצית?"
        }
    }

    /// Only the first two are actionable — the other two are observations, and
    /// offering a button would turn them into a verdict.
    var closeTitle: String? {
        switch self {
        case .staleProject: return "לא, סגור אותו"
        case .untouchedGoal: return "לא, סגור אותה"
        case .lowFriction, .assignedHeavy: return nil
        }
    }

    var keepTitle: String {
        switch self {
        case .staleProject, .untouchedGoal: return "כן, נשארת"
        case .lowFriction, .assignedHeavy: return "הבנתי"
        }
    }
}

struct WeeklyInsight {
    var tidiedCount: Int
    var summary: String
    var counts: [TypeCount]
    var question: InsightQuestion?

    static func make(
        tidied: [Entry],
        allEntries: [Entry],
        projects: [Project],
        goals: [Goal],
        now: Date = .now
    ) -> WeeklyInsight {
        let counts = EntryType.allCases
            .map { type in TypeCount(type: type, count: tidied.filter { $0.type == type }.count) }
            .filter { $0.count > 0 }

        return WeeklyInsight(
            tidiedCount: tidied.count,
            summary: summarize(tidied),
            counts: counts,
            question: question(allEntries: allEntries, projects: projects, goals: goals, now: now)
        )
    }

    // MARK: - Summary

    private static func summarize(_ entries: [Entry]) -> String {
        guard !entries.isEmpty else { return "לא סודרו רשומות הפעם." }

        var lines: [String] = []

        let byProject = Dictionary(grouping: entries.compactMap(\.project)) { $0.persistentModelID }
            .values
            .sorted { $0.count > $1.count }
        let topNames = byProject.prefix(2).compactMap(\.first?.name)

        switch topNames.count {
        case 2: lines.append("רוב המאמץ הלך ל\(topNames[0]) ול\(topNames[1]).")
        case 1: lines.append("רוב המאמץ הלך ל\(topNames[0]).")
        default: lines.append("רוב הרשומות לא שויכו לפרויקט.")
        }

        let friction = entries.filter { $0.type == .friction }.count
        if friction == 0 {
            lines.append("אף רשומת חיכוך.")
        } else {
            lines.append("\(friction) רשומות חיכוך.")
        }

        return lines.joined(separator: " ")
    }

    // MARK: - Question

    private static func question(
        allEntries: [Entry],
        projects: [Project],
        goals: [Goal],
        now: Date
    ) -> InsightQuestion? {
        let threeWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: now) ?? now

        // 1. An active project that has gone quiet.
        let stale = projects.filter { project in
            guard project.status == .active, project.createdAt < threeWeeksAgo else { return false }
            return !allEntries.contains {
                $0.project?.persistentModelID == project.persistentModelID && $0.createdAt >= threeWeeksAgo
            }
        }
        if let project = stale.first { return .staleProject(project) }

        // 2. A declared goal with nothing recorded against it.
        let quarter = Quarter.current(now)
        let untouched = goals.filter { goal in
            goal.isCurrent && !allEntries.contains {
                $0.goal?.persistentModelID == goal.persistentModelID
                    && quarter.interval.contains($0.createdAt)
            }
        }
        if let goal = untouched.first { return .untouchedGoal(goal) }

        // 3. Only the flattering half is being written down (§16).
        let typed = allEntries.filter { $0.type != nil }
        if typed.count >= 10 {
            let friction = typed.filter { $0.type == .friction }.count
            let share = Int((Double(friction) / Double(typed.count) * 100).rounded())
            if share < 15 { return .lowFriction(share) }

            let assigned = allEntries.filter { $0.effectiveOrigin == .assigned }.count
            let assignedShare = Int((Double(assigned) / Double(allEntries.count) * 100).rounded())
            if assignedShare > 70 { return .assignedHeavy(assignedShare) }
        }

        return nil
    }
}
