import SwiftUI
import SwiftData

/// The weekly declaration of where the time went, by project (§07, F3).
///
/// This is what turns the journal from a pile of stories into a document you
/// can put on a table. An achievement without context is an anecdote; the same
/// achievement next to "this area got 8% of my time because I was told the
/// tickets were more urgent" is an argument.
struct AllocationView: View {
    let weekStart: Date
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context

    @Query private var projects: [Project]
    @Query(sort: \WeeklyAllocation.weekStart, order: .reverse)
    private var allocations: [WeeklyAllocation]

    @State private var week: Date = Week.start()
    @State private var rows: [Row] = []
    @State private var note = ""
    @State private var didLoad = false

    private struct Row: Identifiable {
        let project: Project
        var percent: Int
        var locked: Bool
        var id: PersistentIdentifier { project.persistentModelID }
    }

    private var activeProjects: [Project] {
        projects.filter(\.isSelectable).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Group {
            if activeProjects.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .screenBackground()
        .task {
            guard !didLoad else { return }
            didLoad = true
            week = weekStart
            load()
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("איך התחלק השבוע?")
                        .font(.display(21))
                        .displayTracking(21)
                        .foregroundStyle(Palette.ink)
                        .padding(.bottom, 4)

                    Text("\(Week.label(week)) · \(seedLabel)")
                        .font(.bodyText(12.5))
                        .foregroundStyle(Palette.meta)
                        .padding(.bottom, 8)

                    if backfillWeeks.count > 1 { weekPicker }

                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        sliderRow(index: index, row: row)
                    }

                    remainderRow
                    noteField

                    if let comparison { comparisonCard(comparison) }

                    PrimaryButton(title: "אשר וסיים", isEnabled: rows.contains { $0.percent > 0 }) {
                        save()
                        onFinish()
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, Metrics.hMargin)
            }
        }
    }

    private var header: some View {
        HStack {
            CircleButton(symbol: "xmark") { onFinish() }
            Spacer()
            Text("הקצאת זמן")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            // Skipping is allowed. A skipped week stays missing, and is never
            // counted as zero (§07).
            Chip(title: "דלג") { onFinish() }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var weekPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(backfillWeeks, id: \.self) { candidate in
                    Chip(
                        title: candidate == Week.start() ? "השבוע" : Week.label(candidate),
                        isOn: candidate == week,
                        isSquare: true
                    ) {
                        week = candidate
                        load()
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 10)
    }

    /// Two weeks back and no further. A number invented a month later makes
    /// the whole report worthless.
    private var backfillWeeks: [Date] {
        (0...Week.backfillLimit).compactMap { Week.offset(-$0) }
    }

    // MARK: - Slider row

    private func sliderRow(index: Int, row: Row) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Text(row.project.name)
                    .font(.bodyText(15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(row.project.origin.shortTitle)
                    .font(.bodyText(11))
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 26)
                    .background(Capsule().stroke(Palette.line, lineWidth: 1))

                Spacer(minLength: 4)

                Text("\(row.percent)%")
                    .font(.bodyText(16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)

                Button {
                    rows[index].locked.toggle()
                } label: {
                    Image(systemName: row.locked ? "lock.fill" : "lock.open")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(row.locked ? Palette.ink : Palette.meta)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            PercentSlider(value: row.percent, isLocked: row.locked) { newValue in
                apply(newValue, at: index)
            }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
    }

    private var remainderRow: some View {
        let left = AllocationMath.remainder(rows.map(\.percent))
        return HStack(spacing: 10) {
            Text(left == 0 ? "מחולק במלואו" : "נותרו לחלוקה")
                .font(.bodyText(14))
                .foregroundStyle(Palette.muted)
            Spacer()
            Text("\(left)%")
                .font(.bodyText(16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(left == 0 ? Palette.ink : Palette.accent)
            if left != 0 {
                Chip(title: "פזר") {
                    let spread = AllocationMath.distributeRemainder(
                        rows.map(\.percent),
                        locked: lockedIndices
                    )
                    for (i, value) in spread.enumerated() { rows[i].percent = value }
                }
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
    }

    private var noteField: some View {
        TextField("הערה על השבוע (אופציונלי)", text: $note)
            .font(.bodyText(15))
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
    }

    private func comparisonCard(_ text: String) -> some View {
        CardBox {
            Text(text)
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("אין פרויקטים פעילים")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("הקצאת זמן דורשת לפחות פרויקט אחד. אפשר ליצור אותם ב\"אני ← פרויקטים\".")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            PrimaryButton(title: "סגור", action: onFinish)
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 24)
        }
    }

    // MARK: - State

    private var lockedIndices: Set<Int> {
        Set(rows.indices.filter { rows[$0].locked })
    }

    private func apply(_ newValue: Int, at index: Int) {
        let balanced = AllocationMath.rebalance(
            rows.map(\.percent),
            changing: index,
            to: newValue,
            locked: lockedIndices
        )
        for (i, value) in balanced.enumerated() { rows[i].percent = value }
    }

    private var existing: WeeklyAllocation? {
        allocations.first { Calendar.current.isDate($0.weekStart, inSameDayAs: week) }
    }

    private var previous: WeeklyAllocation? {
        allocations.first { $0.weekStart < week }
    }

    private var seedLabel: String {
        if existing != nil { return "נשמר קודם" }
        return previous == nil ? "חלוקה שווה להתחלה" : "מאותחל מהשבוע שעבר"
    }

    private func load() {
        let source = existing ?? previous
        note = existing?.note ?? ""

        if let source {
            rows = activeProjects.map {
                Row(project: $0, percent: source.percent(for: $0), locked: false)
            }
            // A project added mid-week arrives at 0 and does not disturb the
            // weeks already recorded (§07).
            let spread = AllocationMath.distributeRemainder(rows.map(\.percent))
            for (i, value) in spread.enumerated() { rows[i].percent = value }
        } else {
            let each = AllocationMath.total / max(activeProjects.count, 1)
            rows = activeProjects.map { Row(project: $0, percent: each, locked: false) }
            let spread = AllocationMath.distributeRemainder(rows.map(\.percent))
            for (i, value) in spread.enumerated() { rows[i].percent = value }
        }
    }

    private var comparison: String? {
        guard let previous else { return nil }

        let deltas = rows
            .map { (name: $0.project.name, delta: $0.percent - previous.percent(for: $0.project)) }
            .filter { $0.delta != 0 }
            .sorted { abs($0.delta) > abs($1.delta) }
            .prefix(2)

        guard !deltas.isEmpty else { return "זהה לשבוע שעבר." }

        let parts = deltas.map { "\($0.name) \($0.delta > 0 ? "+" : "")\($0.delta)" }
        return "מול שבוע שעבר: " + parts.joined(separator: " · ") + "."
    }

    private func save() {
        let allocation = existing ?? WeeklyAllocation(weekStart: week)
        if existing == nil { context.insert(allocation) }

        allocation.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        allocation.updatedAt = .now

        for slice in allocation.slices { context.delete(slice) }
        allocation.slices = []

        for row in rows where row.percent > 0 {
            let slice = AllocationSlice(percent: row.percent, project: row.project)
            context.insert(slice)
            // Only the to-one side is set; SwiftData maintains the inverse.
            slice.allocation = allocation
        }

        try? context.save()
    }
}

// MARK: - Slider
//
// Hand-rolled to match the wireframe's 8pt track and 26pt thumb, and because
// positioning is absolute here — the layout is RTL, and `offset`/`position`
// are not mirrored by SwiftUI, so the geometry is computed explicitly.

struct PercentSlider: View {
    let value: Int
    let isLocked: Bool
    let onChange: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let fraction = min(max(Double(value) / 100, 0), 1)
            let filled = width * fraction
            let midY = geo.size.height / 2

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Palette.lineSoft)
                    .frame(width: width, height: 8)
                    .position(x: width / 2, y: midY)

                Capsule()
                    .fill(isLocked ? Palette.meta : Palette.ink)
                    .frame(width: filled, height: 8)
                    // Fills from the right, matching the reading direction.
                    .position(x: width - filled / 2, y: midY)

                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(isLocked ? Palette.meta : Palette.ink, lineWidth: 1.5))
                    .frame(width: 26, height: 26)
                    .position(x: width - filled, y: midY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard !isLocked else { return }
                        let ratio = 1 - (drag.location.x / width)
                        onChange(Int((min(max(ratio, 0), 1) * 100).rounded()))
                    }
            )
        }
        .frame(height: 26)
    }
}
