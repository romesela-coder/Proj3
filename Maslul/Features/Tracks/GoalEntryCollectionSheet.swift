import SwiftUI
import SwiftData

/// The focused view for one checkpoint's journal entries.
struct GoalEntryCollectionSheet: View {
    let goal: Goal
    let checkpoint: GoalCheckpoint

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var allEntries: [Entry]
    @Query(sort: \EntryBox.sortIndex, order: .forward)
    private var boxes: [EntryBox]
    @Query(sort: \EntryTag.name, order: .forward)
    private var tags: [EntryTag]

    @State private var selectedEntry: Entry?
    @State private var isEditingCheckpoint = false
    @State private var isWriting = false
    @State private var isChoosingDirection = false
    @State private var selectedPrompt: TrackQuestion?
    @State private var text = ""
    @State private var selectedTags: [EntryTag] = []
    @State private var selectedBox: EntryBox?
    @State private var reminderAt: Date?
    @State private var reminderDelivery: EntryReminderDelivery = .notification
    @State private var selection = NSRange(location: 0, length: 0)

    private var entries: [Entry] {
        allEntries.filter {
            $0.goal?.persistentModelID == goal.persistentModelID
                && $0.checkpoint?.persistentModelID == checkpoint.persistentModelID
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        VStack(alignment: .leading, spacing: 14) {
                            SectionLabel(text: "ENTRIES")

                            if entries.isEmpty {
                                emptyState
                            } else {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)
                                    ],
                                    spacing: 10
                                ) {
                                    ForEach(entries) { entry in
                                        Button { selectedEntry = entry } label: {
                                            FocusedBoxEntryCard(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.top, 26)
                    .padding(.bottom, isWriting ? 250 : 110)
                }
                .scrollIndicators(.hidden)

                if isWriting {
                    VStack(spacing: 9) {
                        Text("Writing in \(checkpoint.title)")
                            .font(.bodyText(12, weight: .medium))
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Metrics.hMargin + 10)

                        if selectedPrompt == nil {
                            EntryDirectionAccessory(open: openDirections)
                        }

                        QuickCaptureBar(
                            text: $text,
                            selectedTags: $selectedTags,
                            selectedBox: $selectedBox,
                            reminderAt: $reminderAt,
                            reminderDelivery: $reminderDelivery,
                            selection: $selection,
                            selectedGoal: .constant(goal),
                            availableGoals: [goal],
                            goalIsFixed: true,
                            availableTags: tags,
                            prompt: selectedPrompt?.text,
                            save: saveEntry,
                            dismiss: { withAnimation(Motion.spring) { isWriting = false } },
                            clearPrompt: { selectedPrompt = nil }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !isChoosingDirection {
                    Button(action: beginWriting) {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(Palette.control))
                            .shadow(color: Palette.ink.opacity(0.16), radius: 9, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add entry to checkpoint")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.bottom, 20)
                }
            }
            .screenBackground()
            .navigationTitle("Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") { isEditingCheckpoint = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
            }
            .sheet(isPresented: $isEditingCheckpoint) {
                GoalCheckpointEditor(goal: goal, checkpoint: checkpoint, onDelete: { dismiss() })
            }
            .sheet(isPresented: $isChoosingDirection, onDismiss: {
                withAnimation(Motion.spring) { isWriting = true }
            }) {
                GoalDirectionsView { direction in
                    selectedPrompt = direction
                    isChoosingDirection = false
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(checkpoint.title)
                .font(.display(29))
                .displayTracking(29)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(goal.title)
                .font(.bodyText(13, weight: .medium))
                .foregroundStyle(Palette.meta)

            if let details = checkpoint.details, !details.isEmpty {
                Text(details)
                    .font(.bodyText(14))
                    .foregroundStyle(Palette.ink2)
            }

            ChipFlow(spacing: 7, rowSpacing: 7) {
                fact(entries.count == 1 ? "1 entry" : "\(entries.count) entries")
                if let dueAt = checkpoint.dueAt {
                    fact("Target \(dueAt.formatted(.dateTime.day().month(.abbreviated).year()))")
                }
            }

            Button {
                checkpoint.completedAt = checkpoint.completedAt == nil ? .now : nil
                try? context.save()
            } label: {
                Group {
                    if let completedAt = checkpoint.completedAt {
                        Label(
                            "Completed \(completedAt.formatted(.dateTime.day().month(.abbreviated)))",
                            systemImage: "checkmark.circle.fill"
                        )
                    } else {
                        Label("Mark as complete", systemImage: "circle")
                    }
                }
                .font(.bodyText(13, weight: .semibold))
                .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fact(_ title: String) -> some View {
        Text(title)
            .font(.bodyText(12, weight: .medium))
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 10)
            .frame(minHeight: 31)
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.neutralTile))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("No entries here yet")
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("A checkpoint can stand on its own. Write when there's something worth noting.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.neutralTile))
    }

    private func beginWriting() {
        selectedPrompt = nil
        selectedBox = boxes.first(where: { $0.systemKey == "inbox" }) ?? boxes.first
        withAnimation(Motion.spring) { isWriting = true }
    }

    private func openDirections() {
        isWriting = false
        isChoosingDirection = true
    }

    private func saveEntry() {
        guard GoalEntryCreation.save(
            text: text,
            goal: goal,
            checkpoint: checkpoint,
            tags: selectedTags,
            prompt: selectedPrompt,
            box: selectedBox,
            reminderAt: reminderAt,
            reminderDelivery: reminderDelivery,
            in: context
        ) else { return }

        text = ""
        selectedTags = []
        selectedPrompt = nil
        selectedBox = nil
        reminderAt = nil
        selection = NSRange(location: 0, length: 0)
        withAnimation(Motion.spring) { isWriting = false }
    }
}

@MainActor
enum GoalEntryCreation {
    @discardableResult
    static func save(
        text: String,
        goal: Goal,
        checkpoint: GoalCheckpoint?,
        tags: [EntryTag],
        prompt: TrackQuestion?,
        box: EntryBox?,
        reminderAt: Date?,
        reminderDelivery: EntryReminderDelivery,
        in context: ModelContext
    ) -> Bool {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return false }

        let entry = Entry(body: body)
        CalendarEntryOrdering.placeAtFront(entry, in: context)
        entry.goal = goal
        entry.checkpoint = checkpoint
        entry.tags = tags
        entry.reflectionPromptID = prompt?.id
        entry.reflectionPromptText = prompt?.text
        entry.reminderAt = reminderAt
        entry.reminderDelivery = reminderDelivery
        EntryBoxEntryOrdering.move(entry, to: box ?? EntryBoxBootstrap.inbox(in: context))
        context.insert(entry)
        try? context.save()

        if entry.reminderAt != nil {
            Task { @MainActor in
                _ = await EntryReminderScheduler.schedule(entry)
                try? context.save()
            }
        }
        Task { @MainActor in
            entry.titleText = await LocalMetadataGenerator.title(
                for: body,
                projectName: nil,
                type: nil
            )
            try? context.save()
        }
        return true
    }
}
