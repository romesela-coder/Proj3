import Foundation
import SwiftData

// MARK: - Quarter

/// Goals live in calendar quarters. Everything about §12 is a comparison
/// between two columns inside one of these.
struct Quarter: Hashable, Comparable, Identifiable {
    let year: Int
    /// 1...4
    let index: Int

    var id: String { key }
    var key: String { "\(year)-Q\(index)" }
    var title: String { "רבעון Q\(index) · \(year)" }
    var shortTitle: String { "Q\(index) \(year)" }

    static func current(_ date: Date = .now) -> Quarter {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let month = components.month ?? 1
        return Quarter(year: components.year ?? 2026, index: (month - 1) / 3 + 1)
    }

    static func from(key: String) -> Quarter? {
        let parts = key.split(separator: "-Q")
        guard parts.count == 2, let year = Int(parts[0]), let index = Int(parts[1]) else { return nil }
        return Quarter(year: year, index: index)
    }

    var interval: DateInterval {
        let cal = Calendar.current
        let startMonth = (index - 1) * 3 + 1
        let start = cal.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? .now
        let end = cal.date(byAdding: .month, value: 3, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    var previous: Quarter {
        index == 1 ? Quarter(year: year - 1, index: 4) : Quarter(year: year, index: index - 1)
    }

    var next: Quarter {
        index == 4 ? Quarter(year: year + 1, index: 1) : Quarter(year: year, index: index + 1)
    }

    static func < (lhs: Quarter, rhs: Quarter) -> Bool {
        lhs.year == rhs.year ? lhs.index < rhs.index : lhs.year < rhs.year
    }
}

// MARK: - Goal

/// A declared intention with an optional personal metric (§12, US-D1).
///
/// The measurable target exists only so a final comparison is possible. A goal
/// with no metric at all is allowed, and is compared qualitatively.
@Model
final class Goal {
    var title: String = ""
    var emoji: String = "🎯"

    /// "3 מסמכי עיצוב שאני מוביל" — free text, deliberately not a number.
    var metric: String?

    var quarterKey: String = ""
    var createdAt: Date = Date()

    /// Set when the quarter is closed. Closed goals stay in history forever.
    var closedAt: Date?

    /// Ephemeral UI state while the local model chooses the first emoji.
    @Transient var isGeneratingEmoji = false

    /// One line the user writes at closing: why it happened, or why it didn't.
    var closingNote: String?

    @Relationship(deleteRule: .nullify, inverse: \Entry.goal)
    var entries: [Entry] = []

    init(title: String, metric: String? = nil, quarter: Quarter = .current(), createdAt: Date = .now) {
        self.title = title
        self.emoji = "🎯"
        self.metric = metric
        self.quarterKey = quarter.key
        self.createdAt = createdAt
        self.entries = []
    }

    /// A deliberate ceiling (US-D1). A fifth goal is not a plan.
    static let activeLimit = 4
}

extension Goal {
    var quarter: Quarter { Quarter.from(key: quarterKey) ?? .current() }
    var isOpen: Bool { closedAt == nil }

    var isCurrent: Bool {
        isOpen && quarter == Quarter.current()
    }
}
