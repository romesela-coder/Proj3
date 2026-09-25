import SwiftUI
import SwiftData
import UIKit

/// The home view is about ongoing goals. Prompts belong to the goal itself.
struct GoalsOverviewView: View {
    let goals: [Goal]
    let entries: [Entry]
    let openGoal: (Goal) -> Void
    let createGoal: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if goals.isEmpty {
                    emptyState
                } else {
                    HStack {
                        SectionLabel(text: "YOUR GOALS")
                        Spacer()
                        Button("New goal", action: createGoal)
                            .font(.bodyText(13, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    .padding(.bottom, 2)

                    ForEach(goals) { goal in
                        Button { openGoal(goal) } label: {
                            goalCard(goal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.top, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
    }

    private func goalCard(_ goal: Goal) -> some View {
        let goalEntries = entries
            .filter { $0.goal?.persistentModelID == goal.persistentModelID }
            .sorted { $0.createdAt > $1.createdAt }
        let latest = goalEntries.first

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 11) {
                Text(goal.emoji)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.goal))

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.bodyText(17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(goalEntries.count == 1 ? "1 entry" : "\(goalEntries.count) entries")
                        .font(.utility(11))
                        .foregroundStyle(Palette.meta)
                }
                Spacer(minLength: 5)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.meta)
                    .padding(.top, 12)
            }

            Rectangle().fill(Palette.lineSoft).frame(height: 1)

            if let latest {
                Text(Fmt.stamp(latest.createdAt))
                    .font(.utility(10.5))
                    .foregroundStyle(Palette.meta)
                Text(latest.body)
                    .font(.bodyText(14))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } else {
                Text("No entries yet. Start with a thought or a check-in.")
                    .font(.bodyText(13.5))
                    .foregroundStyle(Palette.meta)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius).stroke(Palette.cardLine))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 17) {
            Image(systemName: "target")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Palette.goal))
            Text("What do you want to move forward?")
                .font(.display(25))
                .displayTracking(25)
                .foregroundStyle(Palette.ink)
            Text("Name a goal first. Its entries will form a timeline you can return to, even when nothing has moved.")
                .font(.bodyText(15))
                .foregroundStyle(Palette.ink2)
            Button(action: createGoal) {
                HStack {
                    Text("Create your first goal")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.control))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 18)
    }
}

/// One goal journey: ordered checkpoints with their entries, followed by
/// goal notes that were written without choosing a checkpoint.
struct GoalDetailSheet: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var allEntries: [Entry]
    @Query(sort: \GoalCheckpoint.sortIndex, order: .forward) private var allCheckpoints: [GoalCheckpoint]
    @Query(sort: \EntryBox.sortIndex, order: .forward) private var boxes: [EntryBox]
    @Query(sort: \EntryTag.name, order: .forward) private var tags: [EntryTag]

    @State private var selectedEntry: Entry?
    @State private var editingCheckpoint: GoalCheckpoint?
    @State private var isAddingCheckpoint = false
    @State private var isImportingBox = false
    @State private var checkpointEditMode: EditMode = .inactive
    @State private var isWriting = false
    @State private var isChoosingDirection = false
    @State private var selectedPrompt: TrackQuestion?
    @State private var selectedCheckpoint: GoalCheckpoint?
    @State private var text = ""
    @State private var selectedTags: [EntryTag] = []
    @State private var selectedBox: EntryBox?
    @State private var reminderAt: Date?
    @State private var reminderDelivery: EntryReminderDelivery = .notification
    @State private var selection = NSRange(location: 0, length: 0)

    private var entries: [Entry] {
        allEntries.filter { $0.goal?.persistentModelID == goal.persistentModelID }
    }

    private var entriesBeyondCheckpoints: [Entry] {
        let checkpointIDs = Set(checkpoints.map(\.persistentModelID))
        return entries.filter { entry in
            guard let checkpoint = entry.checkpoint else { return true }
            return !checkpointIDs.contains(checkpoint.persistentModelID)
        }
    }

    private var checkpoints: [GoalCheckpoint] {
        allCheckpoints
            .filter { $0.goal?.persistentModelID == goal.persistentModelID }
            .sorted { lhs, rhs in
            if lhs.sortIndex == rhs.sortIndex { return lhs.createdAt < rhs.createdAt }
            return lhs.sortIndex < rhs.sortIndex
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    goalHeader
                        .padding(.horizontal, Metrics.hMargin)
                        .padding(.top, 25)
                        .padding(.bottom, 22)
                        .journalListRow()

                    roadmapHeader
                        .padding(.horizontal, Metrics.hMargin)
                        .padding(.bottom, 12)
                        .journalListRow()

                    if checkpoints.isEmpty {
                        roadmapEmptyState
                            .padding(.horizontal, Metrics.hMargin)
                            .padding(.bottom, 8)
                            .journalListRow()
                    } else {
                        ForEach(checkpoints) { checkpoint in
                            checkpointShelf(checkpoint)
                                .padding(.horizontal, Metrics.hMargin)
                                .padding(.trailing, checkpointEditMode.isEditing ? -44 : 0)
                                .journalListRow()
                        }
                        .onMove(perform: moveCheckpoints)
                    }

                    if !entriesBeyondCheckpoints.isEmpty {
                        goalNotesShelf
                            .padding(.horizontal, Metrics.hMargin)
                            .journalListRow()
                    }

                    Color.clear
                        .frame(height: isWriting ? 235 : 100)
                        .journalListRow()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.editMode, $checkpointEditMode)

                if isWriting {
                    VStack(spacing: 9) {
                        if let selectedCheckpoint {
                            HStack(spacing: 8) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(selectedCheckpoint.title)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    self.selectedCheckpoint = nil
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove checkpoint link")
                            }
                            .font(.bodyText(12, weight: .medium))
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.neutralTile))
                            .padding(.horizontal, 8)
                        }
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
                    Button { beginWriting() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(Palette.control))
                            .shadow(color: Palette.ink.opacity(0.16), radius: 9, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add entry to goal")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.bottom, 20)
                }
            }
            .screenBackground()
            .navigationTitle("Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
            }
            .sheet(isPresented: $isAddingCheckpoint) {
                GoalCheckpointEditor(goal: goal, nextSortIndex: checkpoints.count)
            }
            .sheet(isPresented: $isImportingBox) {
                GoalBoxImportSheet(
                    goal: goal,
                    boxes: boxes,
                    entries: allEntries,
                    nextSortIndex: checkpoints.count
                )
            }
            .sheet(item: $editingCheckpoint) { checkpoint in
                GoalCheckpointEditor(goal: goal, checkpoint: checkpoint)
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

    private var goalHeader: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(goal.title)
                .font(.display(29))
                .displayTracking(29)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let motivation = goal.motivation, !motivation.isEmpty {
                Text(motivation)
                    .font(.bodyText(14))
                    .foregroundStyle(Palette.ink2)
            }

            ChipFlow(spacing: 7, rowSpacing: 7) {
                goalFact(entries.count == 1 ? "1 entry" : "\(entries.count) entries")
                if !checkpoints.isEmpty {
                    goalFact("\(checkpoints.filter { $0.completedAt != nil }.count) of \(checkpoints.count) checkpoints")
                }
                goalFact("Started \((goal.trackCreatedAt ?? goal.createdAt).formatted(.dateTime.day().month(.abbreviated)))")
            }
        }
    }

    private func goalFact(_ title: String) -> some View {
        Text(title)
            .font(.bodyText(12, weight: .medium))
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 10)
            .frame(minHeight: 31)
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.neutralTile))
    }

    private var roadmapHeader: some View {
        HStack(spacing: 10) {
            SectionLabel(text: "ROADMAP")
            Spacer()
            if checkpointEditMode.isEditing {
                Button("Done") {
                    withAnimation(Motion.spring) {
                        checkpointEditMode = .inactive
                    }
                }
                .font(.bodyText(12, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            } else {
                Menu {
                    Button {
                        isImportingBox = true
                    } label: {
                        Label("Use an existing Box", systemImage: "square.grid.2x2")
                    }
                    if checkpoints.count > 1 {
                        Button {
                            withAnimation(Motion.spring) { checkpointEditMode = .active }
                        } label: {
                            Label("Reorder checkpoints", systemImage: "arrow.up.arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Roadmap options")
            }
            Button {
                isAddingCheckpoint = true
            } label: {
                Label("Checkpoint", systemImage: "plus")
                    .font(.bodyText(12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.ink)
        }
    }

    private var roadmapEmptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("What needs to happen along the way?")
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("Add a checkpoint to sketch the path. It can be a simple task or a larger milestone.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
            Button("Use an existing Box") {
                isImportingBox = true
            }
            .font(.bodyText(13, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.neutralTile))
    }

    private func checkpointShelf(_ checkpoint: GoalCheckpoint) -> some View {
        let linkedEntries = entries
            .filter { $0.checkpoint?.persistentModelID == checkpoint.persistentModelID }
            .sorted { $0.createdAt > $1.createdAt }

        return VStack(alignment: .leading, spacing: 11) {
            Button {
                editingCheckpoint = checkpoint
            } label: {
                HStack(alignment: .top, spacing: 9) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(checkpoint.title)
                            .font(.bodyText(17, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        if let details = checkpoint.details, !details.isEmpty {
                            Text(details)
                                .font(.bodyText(13.5))
                                .foregroundStyle(Palette.ink2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 5)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.meta)
                        .padding(.top, 5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(checkpointEditMode.isEditing)

            HStack(spacing: 10) {
                if let completedAt = checkpoint.completedAt {
                    Label("Completed \(completedAt.formatted(.dateTime.day().month(.abbreviated)))", systemImage: "checkmark")
                }
                if let dueAt = checkpoint.dueAt {
                    Label("Target \(dueAt.formatted(.dateTime.day().month(.abbreviated)))", systemImage: "calendar")
                }
                Text(linkedEntries.count == 1 ? "1 entry" : "\(linkedEntries.count) entries")
            }
            .font(.utility(11))
            .foregroundStyle(Palette.meta)

            if !linkedEntries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(linkedEntries) { entry in
                            Button { selectedEntry = entry } label: {
                                BoxEntryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, Metrics.hMargin)
                }
            }

            Button {
                beginWriting(for: checkpoint)
            } label: {
                Label(linkedEntries.isEmpty ? "Write about this step" : "Add another entry", systemImage: "square.and.pencil")
                    .font(.bodyText(12.5, weight: .medium))
                    .foregroundStyle(Palette.ink2)
            }
            .buttonStyle(.plain)
            .disabled(checkpointEditMode.isEditing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 29)
        .padding(.bottom, 22)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(
                    checkpoint.persistentModelID == checkpoints.last?.persistentModelID && entriesBeyondCheckpoints.isEmpty
                        ? Color.clear : Palette.line
                )
                .frame(width: 1)
                .padding(.leading, 9)
                .padding(.top, 20)
        }
        .overlay(alignment: .topLeading) {
            Button {
                checkpoint.completedAt = checkpoint.completedAt == nil ? .now : nil
                try? context.save()
            } label: {
                Image(systemName: checkpoint.completedAt == nil ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(checkpoint.completedAt == nil ? Palette.meta : Palette.ink)
                    .frame(width: 20, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(checkpointEditMode.isEditing)
            .accessibilityLabel(checkpoint.completedAt == nil ? "Complete checkpoint" : "Reopen checkpoint")
        }
    }

    private func moveCheckpoints(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = checkpoints
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, checkpoint) in reordered.enumerated() {
            checkpoint.sortIndex = index
        }
        try? context.save()
    }

    private var goalNotesShelf: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Along the way")
                .font(.bodyText(17, weight: .semibold))
                .foregroundStyle(Palette.ink)

            Text(entriesBeyondCheckpoints.count == 1
                 ? "1 goal note"
                 : "\(entriesBeyondCheckpoints.count) goal notes")
                .font(.utility(11))
                .foregroundStyle(Palette.meta)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(entriesBeyondCheckpoints) { entry in
                        Button { selectedEntry = entry } label: {
                            BoxEntryCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, Metrics.hMargin)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 29)
        .padding(.bottom, 22)
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Palette.neutralTile)
                .frame(width: 20, height: 20)
                .overlay {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                }
        }
    }

    private func openDirections() {
        isWriting = false
        isChoosingDirection = true
    }

    private func beginWriting(for checkpoint: GoalCheckpoint? = nil) {
        selectedPrompt = nil
        selectedCheckpoint = checkpoint
        selectedBox = boxes.first(where: { $0.systemKey == "inbox" }) ?? boxes.first
        withAnimation(Motion.spring) { isWriting = true }
    }

    private func saveEntry() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let entry = Entry(body: body)
        CalendarEntryOrdering.placeAtFront(entry, in: context)
        entry.goal = goal
        entry.checkpoint = selectedCheckpoint
        entry.tags = selectedTags
        entry.reflectionPromptID = selectedPrompt?.id
        entry.reflectionPromptText = selectedPrompt?.text
        entry.reminderAt = reminderAt
        entry.reminderDelivery = reminderDelivery
        EntryBoxEntryOrdering.move(
            entry,
            to: selectedBox ?? EntryBoxBootstrap.inbox(in: context)
        )
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

        text = ""
        selectedTags = []
        selectedPrompt = nil
        selectedCheckpoint = nil
        selectedBox = nil
        reminderAt = nil
        selection = NSRange(location: 0, length: 0)
        withAnimation(Motion.spring) { isWriting = false }
    }
}
