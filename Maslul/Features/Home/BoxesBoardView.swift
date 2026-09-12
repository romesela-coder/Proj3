import SwiftUI

struct BoxesBoardView: View {
    let boxes: [EntryBox]
    let entries: [Entry]
    let openEntry: (Entry) -> Void

    var body: some View {
        if boxes.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(boxes) { box in
                        boxShelf(box)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func entries(in box: EntryBox) -> [Entry] {
        entries
            .filter { $0.box?.persistentModelID == box.persistentModelID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func boxShelf(_ box: EntryBox) -> some View {
        let boxEntries = entries(in: box)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                EntryBoxTile(box: box, size: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(box.name)
                        .font(.bodyText(17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("\(boxEntries.count) \(boxEntries.count == 1 ? "entry" : "entries")")
                        .font(.bodyText(11.5))
                        .foregroundStyle(Palette.meta)
                }

                Spacer()
            }
            .padding(.horizontal, Metrics.hMargin)

            if boxEntries.isEmpty {
                Text("Nothing in this box yet")
                    .font(.bodyText(13.5))
                    .foregroundStyle(Palette.meta)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Palette.neutralTile.opacity(0.72))
                    )
                    .padding(.horizontal, Metrics.hMargin)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(boxEntries) { entry in
                            Button { openEntry(entry) } label: {
                                BoxEntryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metrics.hMargin)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No boxes yet")
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            Text("Choose a box while writing to start your board.")
                .font(.bodyText(13))
                .foregroundStyle(Palette.meta)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.hMargin)
    }
}

private struct BoxEntryCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.bodyText(15.5, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if entry.title != entry.body {
                InlineMentionText(
                    text: entry.body,
                    tags: entry.tags,
                    fontSize: 12.5,
                    maximumNumberOfLines: 2
                )
            }

            Spacer(minLength: 2)

            Text(Fmt.longDate(entry.createdAt))
                .font(.utility(10))
                .foregroundStyle(Palette.meta)
        }
        .padding(14)
        .frame(width: 226, height: 126, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.lineSoft, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
