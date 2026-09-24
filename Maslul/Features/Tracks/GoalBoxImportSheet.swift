import SwiftUI
import SwiftData

/// An opt-in bridge from the old Box board. It adds goal/checkpoint links but
/// never moves or deletes the original Box or its journal entries.
struct GoalBoxImportSheet: View {
    let goal: Goal
    let boxes: [EntryBox]
    let entries: [Entry]
    let nextSortIndex: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var selectedBox: EntryBox?

    private var importableBoxes: [EntryBox] {
        boxes.filter { $0.systemKey != "inbox" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let selectedBox {
                        preview(for: selectedBox)
                    } else {
                        Text("Choose a Box to turn into a checkpoint. Its original Box will stay exactly where it is.")
                            .font(.bodyText(14))
                            .foregroundStyle(Palette.ink2)
                            .padding(.bottom, 4)

                        ForEach(importableBoxes) { box in
                            Button { selectedBox = box } label: {
                                HStack(spacing: 12) {
                                    EntryBoxTile(box: box, size: 42)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(box.name)
                                            .font(.bodyText(15, weight: .semibold))
                                            .foregroundStyle(Palette.ink)
                                        Text("\(eligibleEntries(in: box).count) entries can be linked")
                                            .font(.bodyText(12))
                                            .foregroundStyle(Palette.meta)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Palette.meta)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                            }
                            .buttonStyle(.plain)
                        }

                        if importableBoxes.isEmpty {
                            Text("No Boxes to bring in yet.")
                                .font(.bodyText(14))
                                .foregroundStyle(Palette.meta)
                        }
                    }
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle(selectedBox == nil ? "Use an existing Box" : "Review checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedBox == nil ? "Cancel" : "Back") {
                        if selectedBox == nil { dismiss() } else { selectedBox = nil }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func preview(for box: EntryBox) -> some View {
        let eligible = eligibleEntries(in: box)
        let skipped = boxEntries(in: box).count - eligible.count

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                EntryBoxTile(box: box, size: 48)
                Text(box.name)
                    .font(.display(24))
                    .foregroundStyle(Palette.ink)
            }

            Text("This creates a checkpoint in \(goal.title) and links \(eligible.count) \(eligible.count == 1 ? "entry" : "entries") to it. Their content and Box membership will stay unchanged in the Boxes view.")
                .font(.bodyText(14))
                .foregroundStyle(Palette.ink2)

            if skipped > 0 {
                Text("\(skipped) \(skipped == 1 ? "entry is" : "entries are") already linked to another goal or checkpoint and will be left alone.")
                    .font(.bodyText(13))
                    .foregroundStyle(Palette.meta)
            }

            if !eligible.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(eligible.prefix(5)) { entry in
                            BoxEntryCard(entry: entry)
                        }
                    }
                }
            }

            Button {
                importBox(box, entries: eligible)
            } label: {
                Text("Create checkpoint from Box")
                    .font(.bodyText(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 15).fill(Palette.control))
            }
            .buttonStyle(.plain)
        }
    }

    private func boxEntries(in box: EntryBox) -> [Entry] {
        entries.filter { $0.box?.persistentModelID == box.persistentModelID }
    }

    private func eligibleEntries(in box: EntryBox) -> [Entry] {
        boxEntries(in: box)
            .filter { entry in
                entry.checkpoint == nil &&
                    (entry.goal == nil || entry.goal?.persistentModelID == goal.persistentModelID)
            }
            .sorted { $0.boxSortIndex < $1.boxSortIndex }
    }

    private func importBox(_ box: EntryBox, entries: [Entry]) {
        let checkpoint = GoalCheckpoint(title: box.name, goal: goal, sortIndex: nextSortIndex)
        context.insert(checkpoint)
        for entry in entries {
            entry.goal = goal
            entry.checkpoint = checkpoint
        }
        try? context.save()
        dismiss()
    }
}
