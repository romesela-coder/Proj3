import SwiftUI

/// Aggregation for the time-allocation report (§11).
///
/// Built from the declared weekly allocations, never from counting entries.
/// Those are two different claims and only one of them was collected before
/// the need for it existed.
struct TimeReport {
    struct Bucket: Identifiable {
        let id: String
        let label: String
        /// project id -> average percent across the weeks in this bucket
        let shares: [PersistentIdentifier: Double]
    }

    struct Line: Identifiable {
        let project: Project
        let percent: Double
        var id: PersistentIdentifier { project.persistentModelID }
    }

    enum Grouping: String, CaseIterable, Identifiable {
        case month
        case week
        var id: String { rawValue }
        var title: String { self == .month ? "חודשים" : "שבועות" }
    }

    var buckets: [Bucket]
    var lines: [Line]
    var originSplit: [(origin: TaskOrigin, percent: Double)]
    var recordedWeeks: Int
    var skippedWeeks: Int
    var notes: [(week: Date, note: String)]

    var isEmpty: Bool { recordedWeeks == 0 }

    static func build(
        allocations: [WeeklyAllocation],
        range: ExportRange,
        grouping: Grouping,
        now: Date = .now
    ) -> TimeReport {
        let start = range.start(from: now).map { Week.start(of: $0) } ?? allocations.map(\.weekStart).min() ?? Week.start(of: now)
        let end = Week.start(of: now)

        let inRange = allocations
            .filter { $0.weekStart >= start && $0.weekStart <= end }
            .sorted { $0.weekStart < $1.weekStart }

        // Every week in the window, so a gap can be reported as a gap rather
        // than quietly averaged away.
        var allWeeks: [Date] = []
        var cursor = start
        while cursor <= end {
            allWeeks.append(cursor)
            cursor = Week.offset(1, from: cursor)
        }

        let recorded = Set(inRange.map(\.weekStart))
        let skipped = allWeeks.filter { !recorded.contains($0) }.count

        let cal = Calendar.current
        let grouped: [(key: Date, items: [WeeklyAllocation])]
        switch grouping {
        case .week:
            grouped = inRange.map { (key: $0.weekStart, items: [$0]) }
        case .month:
            let dict = Dictionary(grouping: inRange) { allocation -> Date in
                let parts = cal.dateComponents([.year, .month], from: allocation.weekStart)
                return cal.date(from: parts) ?? allocation.weekStart
            }
            grouped = dict.map { (key: $0.key, items: $0.value) }.sorted { $0.key < $1.key }
        }

        let buckets = grouped.map { entry -> Bucket in
            var shares: [PersistentIdentifier: Double] = [:]
            for allocation in entry.items {
                for slice in allocation.slices {
                    guard let project = slice.project else { continue }
                    shares[project.persistentModelID, default: 0] += Double(slice.percent)
                }
            }
            let weeks = Double(max(entry.items.count, 1))
            shares = shares.mapValues { $0 / weeks }

            let label = grouping == .month
                ? monthLabel(entry.key)
                : Week.label(entry.key)
            return Bucket(id: ISO8601DateFormatter().string(from: entry.key), label: label, shares: shares)
        }

        // Overall averages across every recorded week in the window.
        var totals: [PersistentIdentifier: Double] = [:]
        var projectsByID: [PersistentIdentifier: Project] = [:]
        for allocation in inRange {
            for slice in allocation.slices {
                guard let project = slice.project else { continue }
                totals[project.persistentModelID, default: 0] += Double(slice.percent)
                projectsByID[project.persistentModelID] = project
            }
        }
        let weekCount = Double(max(inRange.count, 1))
        let lines = totals
            .compactMap { id, sum -> Line? in
                guard let project = projectsByID[id] else { return nil }
                return Line(project: project, percent: sum / weekCount)
            }
            .sorted { $0.percent > $1.percent }

        // The second split: not only where the time went, but who pointed it
        // there (§07).
        var byOrigin: [TaskOrigin: Double] = [:]
        for line in lines {
            byOrigin[line.project.origin, default: 0] += line.percent
        }
        let originSplit = TaskOrigin.allCases
            .compactMap { origin -> (TaskOrigin, Double)? in
                guard let value = byOrigin[origin], value > 0 else { return nil }
                return (origin, value)
            }
            .sorted { $0.1 > $1.1 }
            .map { (origin: $0.0, percent: $0.1) }

        let notes = inRange
            .compactMap { allocation -> (Date, String)? in
                guard let note = allocation.note, !note.isEmpty else { return nil }
                return (allocation.weekStart, note)
            }
            .map { (week: $0.0, note: $0.1) }

        return TimeReport(
            buckets: buckets,
            lines: lines,
            originSplit: originSplit,
            recordedWeeks: inRange.count,
            skippedWeeks: skipped,
            notes: notes
        )
    }

    private static func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Fmt.locale
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f.string(from: date)
    }

    /// The sentence that appears on every export, and on the screen (§07).
    static let disclaimer = "דיווח עצמי שבועי, לא מדידת שעות."

    /// A neutral ramp on purpose. The six pastels in §05 are bound to entry
    /// types; reusing them for projects would make the colour mean two things.
    static func shade(_ index: Int, of count: Int) -> Color {
        guard count > 1 else { return Color(white: 0.29) }
        let step = 0.59 / Double(count - 1)
        return Color(white: 0.29 + step * Double(index))
    }
}
