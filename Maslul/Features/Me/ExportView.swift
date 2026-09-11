import SwiftUI
import SwiftData

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Your data is yours even if you stop using the app (US-E3). The file goes
/// through the system share sheet; the app sends nothing anywhere.
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    @State private var range: ExportRange = .quarter
    @State private var format: ExportFormat = .markdown
    @State private var includeSensitive = false
    @State private var shareItem: ShareItem?
    @State private var errorText: String?

    private var inRange: [Entry] {
        guard let start = range.start() else { return entries }
        return entries.filter { $0.createdAt >= start }
    }

    private var sensitiveCount: Int {
        inRange.filter(\.isSensitive).count
    }

    private var exportCount: Int {
        includeSensitive ? inRange.count : inRange.count - sensitiveCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("טווח") {
                        WrapChips(items: ExportRange.allCases.map(\.title)) { index in
                            range = ExportRange.allCases[index]
                        } isOn: { index in
                            ExportRange.allCases[index] == range
                        }
                    }

                    section("פורמט") {
                        HStack(spacing: 8) {
                            ForEach(ExportFormat.allCases) { candidate in
                                Chip(title: candidate.title, isOn: format == candidate) {
                                    format = candidate
                                }
                            }
                        }
                    }

                    SettingRow(
                        symbol: "lock",
                        title: "כלול רשומות רגישות",
                        subtitle: "ברירת מחדל: לא"
                    ) {
                        Toggle("", isOn: $includeSensitive)
                            .labelsHidden()
                            .tint(Palette.ink)
                    }

                    CardBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(exportCount) רשומות ייכללו")
                                .font(.bodyText(15, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text(includeSensitive
                                 ? "כולל \(sensitiveCount) רשומות רגישות."
                                 : "\(sensitiveCount) רשומות רגישות יוחרגו, והמספר יופיע בראש המסמך.")
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                            Text("קבצים מצורפים נשארים במכשיר ולא נכנסים לקובץ.")
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.bodyText(13))
                            .foregroundStyle(Palette.ink2)
                    }

                    PrimaryButton(title: "ייצא ושתף", isEnabled: exportCount > 0) {
                        runExport()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var header: some View {
        HStack {
            CircleButton(symbol: "chevron.forward") { dismiss() }
            Spacer()
            Text("ייצוא נתונים")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Color.clear.frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            content()
        }
    }

    private func runExport() {
        do {
            let result = try Exporter.export(
                entries: entries,
                range: range,
                format: format,
                includeSensitive: includeSensitive
            )
            errorText = nil
            shareItem = ShareItem(url: result.url)
        } catch {
            errorText = "הייצוא נכשל: \(error.localizedDescription)"
        }
    }
}

/// A chip row that wraps instead of scrolling.
struct WrapChips: View {
    let items: [String]
    let onTap: (Int) -> Void
    let isOn: (Int) -> Bool

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                Chip(title: title, isOn: isOn(index)) { onTap(index) }
            }
        }
    }
}
