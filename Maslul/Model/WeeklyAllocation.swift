import Foundation
import SwiftData

// MARK: - Week

enum Week {
    /// Weeks start on Sunday under the Hebrew calendar locale.
    static func start(of date: Date = .now) -> Date {
        let cal = Calendar.current
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
    }

    static func end(of date: Date = .now) -> Date {
        let cal = Calendar.current
        return cal.dateInterval(of: .weekOfYear, for: date)?.end ?? date
    }

    static func offset(_ weeks: Int, from date: Date = .now) -> Date {
        start(of: Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: start(of: date)) ?? date)
    }

    /// "24—30 באוגוסט"
    static func label(_ weekStart: Date) -> String {
        let cal = Calendar.current
        let last = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

        let dayOnly = DateFormatter()
        dayOnly.locale = Fmt.locale
        dayOnly.setLocalizedDateFormatFromTemplate("d")

        let dayMonth = DateFormatter()
        dayMonth.locale = Fmt.locale
        dayMonth.setLocalizedDateFormatFromTemplate("dMMMM")

        let sameMonth = cal.isDate(weekStart, equalTo: last, toGranularity: .month)
        let first = sameMonth ? dayOnly.string(from: weekStart) : dayMonth.string(from: weekStart)
        return "\(first)—\(dayMonth.string(from: last))"
    }

    /// How far back a missed week may still be filled in (§07).
    ///
    /// A number invented a month after the fact makes the whole report
    /// worthless, so the window closes permanently at two weeks.
    static let backfillLimit = 2

    static func isBackfillable(_ weekStart: Date, now: Date = .now) -> Bool {
        let current = start(of: now)
        guard weekStart <= current else { return false }
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: weekStart, to: current).weekOfYear ?? 0
        return weeks <= backfillLimit
    }
}

// MARK: - Weekly allocation

/// A declared weekly split, in percentages, across active projects (§07).
///
/// Percentages rather than hours on purpose: nobody fills in accurate hours,
/// and the moment one number is invented the whole dataset is disqualified.
/// Percentages force the real trade-off — if tickets got 60, something else
/// got less, and that is exactly the claim you will need to make later.
@Model
final class WeeklyAllocation {
    var weekStart: Date = Date()

    /// "שבוע קצר בגלל חג", "שני ימים על תקלת ייצור". This is what explains an
    /// anomaly in a report read a year from now.
    var note: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \AllocationSlice.allocation)
    var slices: [AllocationSlice] = []

    init(weekStart: Date, note: String? = nil, createdAt: Date = .now) {
        self.weekStart = weekStart
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.slices = []
    }
}

extension WeeklyAllocation {
    var total: Int { slices.reduce(0) { $0 + $1.percent } }

    func percent(for project: Project?) -> Int {
        guard let project else { return 0 }
        return slices
            .first { $0.project?.persistentModelID == project.persistentModelID }?
            .percent ?? 0
    }

    /// Share of the week attributed to work the user did not choose.
    func percent(forOrigin origin: TaskOrigin) -> Int {
        slices
            .filter { $0.project?.origin == origin }
            .reduce(0) { $0 + $1.percent }
    }
}

@Model
final class AllocationSlice {
    var percent: Int = 0
    var project: Project?
    var allocation: WeeklyAllocation?

    init(percent: Int, project: Project?) {
        self.percent = percent
        self.project = project
    }
}
