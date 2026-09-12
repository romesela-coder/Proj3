import SwiftUI

struct EntryRowView: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 7) {
                EntryBoxTile(box: entry.box, size: 44)
                Text(Fmt.dayDot(entry.createdAt))
                    .font(.utility(10))
                    .foregroundStyle(Palette.meta)
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 2) {
                if let type = entry.type {
                    Text(type.title)
                        .font(.utility(10.5))
                        .tracking(1.2)
                        .foregroundStyle(Palette.meta)
                }

                if entry.isGeneratingTitle {
                    AIActivityIndicator(messages: ["Naming", "Summarizing"], compact: true)
                } else {
                    Text(entry.title)
                        .font(.bodyText(16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if entry.title != entry.body {
                    InlineMentionText(
                        text: entry.body,
                        tags: entry.tags,
                        fontSize: 13.5,
                        maximumNumberOfLines: 1
                    )
                }

                if let project = entry.project {
                    Text(project.name)
                        .font(.bodyText(12))
                        .foregroundStyle(Palette.meta)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let effort = entry.effort {
                Text(effort.title)
                    .font(.utility(11.5))
                    .foregroundStyle(Palette.meta)
                    .padding(.top, 2)
            }

            if entry.isSensitive {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.meta)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 18)
        .frame(minHeight: Metrics.rowMinHeight)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

extension View {
    /// Keeps native List behavior while preserving Maslul's edge-to-edge rows.
    func journalListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Palette.ground)
    }
}
