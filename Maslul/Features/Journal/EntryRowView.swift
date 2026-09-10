import SwiftUI

struct EntryRowView: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(Fmt.dayDot(entry.createdAt))
                .font(.utility(11.5))
                .foregroundStyle(Palette.meta)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 2)

            Circle()
                .fill(entry.type?.tint ?? Palette.line)
                .frame(width: 9, height: 9)
                .padding(.top, 8)

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
                        .font(.bodyText(14.5))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if entry.title != entry.body {
                    Text(entry.body)
                        .font(.bodyText(12.5))
                        .foregroundStyle(Palette.meta)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
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
        .padding(.vertical, 15)
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
