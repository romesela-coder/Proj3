import SwiftUI

// MARK: - Entry type (spec §06)
//
// Six types. None of them is an arbitrary category: each exists because a
// specific retrieval surface consumes it.

enum EntryType: String, CaseIterable, Identifiable, Codable {
    case win
    case learning
    case friction
    case decision
    case goal
    case people

    var id: String { rawValue }

    /// The four that sit on the home screen. Decision and people are rarer and
    /// are picked inside the capture screen instead (spec §05).
    static let homeTiles: [EntryType] = [.win, .learning, .friction, .goal]

    var title: String {
        switch self {
        case .win: return "הישג"
        case .learning: return "למידה"
        case .friction: return "חיכוך"
        case .decision: return "החלטה"
        case .goal: return "מטרה"
        case .people: return "אנשים"
        }
    }

    var latin: String { rawValue.uppercased() }

    var tint: Color {
        switch self {
        case .win: return Palette.win
        case .learning: return Palette.learning
        case .friction: return Palette.friction
        case .decision: return Palette.decision
        case .goal: return Palette.goal
        case .people: return Palette.people
        }
    }

    /// Thin monoline symbols against heavy type — the contrast is the whole
    /// personality of the design (spec §05.04).
    var symbol: String {
        switch self {
        case .win: return "checkmark"
        case .learning: return "doc.text"
        case .friction: return "xmark"
        case .decision: return "arrow.triangle.branch"
        case .goal: return "target"
        case .people: return "person.2"
        }
    }

    var hint: String {
        switch self {
        case .win: return "משהו שנעשה ויש לו תוצאה"
        case .learning: return "מיומנות, טכנולוגיה או תובנה"
        case .friction: return "ריג׳קט, פידבק צורב, משהו שנתקע"
        case .decision: return "מה הוחלט, מה היו החלופות"
        case .goal: return "מטרה או עדכון התקדמות"
        case .people: return "למי עזרת, מי עזר לך"
        }
    }
}

// MARK: - Task origin (spec §07)
//
// The field that turns "60% tickets" from a neutral fact into an argument.

enum TaskOrigin: String, CaseIterable, Identifiable, Codable {
    case assigned
    case selfInitiated = "self"
    case interrupt
    case external

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assigned: return "הוגדר לי"
        case .selfInitiated: return "יזמתי"
        case .interrupt: return "הפרעה או תקלה"
        case .external: return "בקשה מצוות אחר"
        }
    }

    var shortTitle: String {
        switch self {
        case .assigned: return "הוגדר לי"
        case .selfInitiated: return "יזמתי"
        case .interrupt: return "הפרעה"
        case .external: return "חיצוני"
        }
    }
}

// MARK: - Effort
//
// Kept as a qualitative hint only. The source of truth for time split is the
// weekly allocation (spec §06, "שינוי מגרסה 0.2").

enum Effort: String, CaseIterable, Identifiable, Codable {
    case s = "S"
    case m = "M"
    case l = "L"

    var id: String { rawValue }
    var title: String { rawValue }
}

// MARK: - Sensitivity (spec §06, US-B3)

enum Sensitivity: String, CaseIterable, Codable {
    case normal
    case sensitive = "private"

    var title: String {
        switch self {
        case .normal: return "רגילה"
        case .sensitive: return "רגישה"
        }
    }
}

// MARK: - Project status (spec §07)

enum ProjectStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case paused
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "פעיל"
        case .paused: return "מושהה"
        case .done: return "סגור"
        }
    }
}
