import SwiftUI
import SwiftData

private struct ReportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct TimeReportView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WeeklyAllocation.weekStart, order: .reverse)
    private var allocations: [WeeklyAllocation]

    @State private var grouping: TimeReport.Grouping = .month
    @State private var range: ExportRange = .quarter
    @State private var showRangePicker = false
    @State private var shareItem: ReportShareItem?

    private var report: TimeReport {
        TimeReport.build(allocations: allocations, range: range, grouping: grouping)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if report.isEmpty {
                emptyState
            } else {
                ScrollView {
                    let report = self.report
                    VStack(alignment: .leading, spacing: 0) {
                        controls
                        bands(report)
                        originBar(report)
                        legend(report)
                        notes(report)
                        disclaimer(report)
                    }
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.bottom, 40)
                }
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("טווח", isPresented: $showRangePicker, titleVisibility: .visible) {
            ForEach(ExportRange.allCases) { candidate in
                Button(candidate.title) { range = candidate }
            }
            Button("ביטול", role: .cancel) {}
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            CircleButton(symbol: "chevron.forward") { dismiss() }
            Spacer()
            Text("דוח הקצאת זמן")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            CircleButton(symbol: "square.and.arrow.up") { export() }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            ForEach(TimeReport.Grouping.allCases) { candidate in
                Chip(title: candidate.title, isOn: grouping == candidate, isSquare: true) {
                    withAnimation(Motion.spring) { grouping = candidate }
                }
            }
            Spacer()
            Chip(title: range.title, isSquare: true) { showRangePicker = true }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Bands

    private func bands(_ report: TimeReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(report.buckets) { bucket in
                HStack(spacing: 10) {
                    Text(bucket.label)
                        .font(.utility(11))
                        .foregroundStyle(Palette.meta)
                        .frame(width: 62, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(Array(report.lines.enumerated()), id: \.element.id) { index, line in
                                let share = bucket.shares[line.id] ?? 0
                                Rectangle()
                                    .fill(TimeReport.shade(index, of: report.lines.count))
                                    .frame(width: geo.size.width * share / 100)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(.vertical, 9)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Origin split

    private func originBar(_ report: TimeReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "לפי מקור המשימה")
                .padding(.top, 14)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(Array(report.originSplit.enumerated()), id: \.offset) { index, item in
                        let width = geo.size.width * item.percent / 100
                        Rectangle()
                            .fill(TimeReport.shade(index, of: max(report.originSplit.count, 2)))
                            .frame(width: width)
                            .overlay(
                                Text("\(item.origin.shortTitle) · \(Int(item.percent.rounded()))%")
                                    .font(.bodyText(12.5, weight: .bold))
                                    .foregroundStyle(index == 0 ? Color.white : Palette.ink)
                                    .lineLimit(1)
                                    .opacity(width > 96 ? 1 : 0)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: - Legend

    private func legend(_ report: TimeReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "פרויקטים")
                .padding(.top, 16)
                .padding(.bottom, 2)

            ForEach(Array(report.lines.enumerated()), id: \.element.id) { index, line in
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(TimeReport.shade(index, of: report.lines.count))
                        .frame(width: 16, height: 16)

                    Text(line.project.name)
                        .font(.bodyText(14.5))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    Text(line.project.origin.shortTitle)
                        .font(.bodyText(11.5))
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 26)
                        .background(Capsule().stroke(Palette.line, lineWidth: 1))

                    Spacer(minLength: 4)

                    Text("\(Int(line.percent.rounded()))%")
                        .font(.bodyText(12.5))
                        .monospacedDigit()
                        .foregroundStyle(Palette.meta)
                }
                .padding(.vertical, 7)
            }
        }
    }

    @ViewBuilder
    private func notes(_ report: TimeReport) -> some View {
        if !report.notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "הערות שבועיות")
                    .padding(.top, 16)
                ForEach(Array(report.notes.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(Week.label(item.week))
                            .font(.utility(11))
                            .foregroundStyle(Palette.meta)
                            .frame(width: 84, alignment: .leading)
                        Text(item.note)
                            .font(.bodyText(13.5))
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func disclaimer(_ report: TimeReport) -> some View {
        CardBox {
            Text("\(TimeReport.disclaimer) \(report.skippedWeeks) מתוך \(report.recordedWeeks + report.skippedWeeks) שבועות דולגו ואינם נספרים.")
                .font(.bodyText(13))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("אין עדיין הקצאות שבועיות")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("הדוח נבנה מההצהרות השבועיות, לא מספירת רשומות. אחרי שבוע אחד כבר יהיה מה להראות.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func export() {
        guard let url = try? Exporter.exportTimeReport(report, range: range) else { return }
        shareItem = ReportShareItem(url: url)
    }
}
