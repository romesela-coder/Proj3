import SwiftUI
import SwiftData

/// The focused view for one checkpoint's journal entries.
struct GoalEntryCollectionSheet: View {
    let goal: Goal
    let checkpoint: GoalCheckpoint

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .forward)
    private var allEntries: [Entry]
    @Query(sort: \EntryBox.sortIndex, order: .forward)
    private var boxes: [EntryBox]
    @Query(sort: \EntryTag.name, order: .forward)
    private var tags: [EntryTag]

    @State private var selectedEntry: Entry?
    @State private var isEditingCheckpoint = false
    @State private var isEditingHeader = false
    @State private var headerTitle = ""
    @State private var headerDetails = ""
    @FocusState private var focusedHeaderField: HeaderField?
    @State private var isConfirmingDelete = false
    @State private var isShowingDeleteError = false
    @State private var timelineEditMode: EditMode = .inactive
    @State private var isWriting = false
    @State private var isChoosingDirection = false
    @State private var selectedPrompt: TrackQuestion?
    @State private var text = ""
    @State private var selectedTags: [EntryTag] = []
    @State private var selectedBox: EntryBox?
    @State private var reminderAt: Date?
    @State private var reminderDelivery: EntryReminderDelivery = .notification
    @State private var selection = NSRange(location: 0, length: 0)

    private enum HeaderField: Hashable {
        case title
        case details
    }

    private var entries: [Entry] {
        allEntries.filter {
            $0.goal?.persistentModelID == goal.persistentModelID
                && $0.checkpoint?.persistentModelID == checkpoint.persistentModelID
        }
        .sorted { left, right in
            switch (left.checkpointSortIndex, right.checkpointSortIndex) {
            case let (leftIndex?, rightIndex?) where leftIndex != rightIndex:
                return leftIndex < rightIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
                return String(describing: left.persistentModelID) < String(describing: right.persistentModelID)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    header
                        .padding(.horizontal, Metrics.hMargin)
                        .padding(.top, 26)
                        .padding(.bottom, 22)
                        .journalListRow()

                    timelineHeader
                        .padding(.horizontal, Metrics.hMargin)
                        .padding(.bottom, 10)
                        .journalListRow()

                    if entries.isEmpty {
                        emptyState
                            .padding(.horizontal, Metrics.hMargin)
                            .journalListRow()
                    } else {
                        ForEach(entries) { entry in
                            timelineRow(
                                entry,
                                isLast: entry.persistentModelID == entries.last?.persistentModelID
                            )
                            .padding(.horizontal, Metrics.hMargin)
                            .padding(.trailing, timelineEditMode.isEditing ? -44 : 0)
                            .journalListRow()
                        }
                        .onMove(perform: moveEntries)
                    }

                    Color.clear
                        .frame(height: isWriting ? 250 : 110)
                        .journalListRow()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.editMode, $timelineEditMode)

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
                } else if !isChoosingDirection && !timelineEditMode.isEditing {
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
                    Menu("Manage") {
                        Button("Edit checkpoint", systemImage: "pencil") {
                            isEditingCheckpoint = true
                        }
                        Button("Delete checkpoint", systemImage: "trash", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
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
            .confirmationDialog(
                "Delete this checkpoint?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete checkpoint", role: .destructive, action: deleteCheckpoint)
            } message: {
                Text("Its entries will stay in the goal and journal.")
            }
            .alert("Couldn't delete checkpoint", isPresented: $isShowingDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
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
            Text(goal.title)
                .font(.bodyText(13, weight: .medium))
                .foregroundStyle(Palette.meta)

            if isEditingHeader {
                TextField("Checkpoint name", text: $headerTitle, axis: .vertical)
                    .font(.display(29))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...3)
                    .focused($focusedHeaderField, equals: .title)
            } else {
                Button { beginHeaderEditing(.title) } label: {
                    Text(checkpoint.title)
                        .font(.display(29))
                        .displayTracking(29)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit checkpoint name: \(checkpoint.title)")
            }

            if isEditingHeader {
                TextField("Description (optional)", text: $headerDetails, axis: .vertical)
                    .font(.bodyText(14))
                    .lineLimit(2...5)
                    .focused($focusedHeaderField, equals: .details)

                HStack(spacing: 18) {
                    Button("Save", action: saveHeader)
                        .font(.bodyText(13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .disabled(headerTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel", action: cancelHeaderEditing)
                        .font(.bodyText(13))
                        .foregroundStyle(Palette.meta)
                }
            } else {
                Button { beginHeaderEditing(.details) } label: {
                    Text(checkpoint.details.flatMap { $0.isEmpty ? nil : $0 } ?? "Add description")
                        .font(.bodyText(14))
                        .foregroundStyle(checkpoint.details?.isEmpty == false ? Palette.ink2 : Palette.meta)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit checkpoint description")
            }

            if let dueAt = checkpoint.dueAt {
                fact("Target \(dueAt.formatted(.dateTime.day().month(.abbreviated).year()))")
            }

            Button {
                checkpoint.completedAt = checkpoint.completedAt == nil ? .now : nil
                try? context.save()
            } label: {
                Group {
                    if checkpoint.completedAt != nil {
                        Label("Completed · Reopen", systemImage: "checkmark.circle.fill")
                    } else {
                        Label("Mark as complete", systemImage: "checkmark.circle")
                    }
                }
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(checkpoint.completedAt == nil ? Color.white : Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(checkpoint.completedAt == nil ? Palette.control : Palette.neutralTile)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checkpoint.completedAt == nil ? "Mark checkpoint as complete" : "Reopen checkpoint")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timelineHeader: some View {
        HStack {
            SectionLabel(text: "TIMELINE")
            Spacer()
            if timelineEditMode.isEditing {
                Button("Done") {
                    withAnimation(Motion.spring) { timelineEditMode = .inactive }
                }
                .font(.bodyText(12, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            } else if entries.count > 1 {
                Button("Reorder") {
                    withAnimation(Motion.spring) { timelineEditMode = .active }
                }
                .font(.bodyText(12, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            }
        }
    }

    private func fact(_ title: String) -> some View {
        Text(title)
            .font(.bodyText(12, weight: .medium))
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 10)
            .frame(minHeight: 31)
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.neutralTile))
    }

    private func timelineRow(_ entry: Entry, isLast: Bool) -> some View {
        Button {
            if !timelineEditMode.isEditing { selectedEntry = entry }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Palette.ink2)
                    .frame(width: 8, height: 8)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.createdAt.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.utility(11))
                        .foregroundStyle(Palette.meta)

                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.title)
                            .font(.bodyText(16, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.meta)
                            .padding(.top, 4)
                    }

                    if entry.title != entry.body {
                        InlineMentionText(
                            text: entry.body,
                            tags: entry.tags,
                            fontSize: 13,
                            maximumNumberOfLines: 2,
                            mentionAppearance: .compact
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(isLast ? Color.clear : Palette.line)
                .frame(width: 1)
                .padding(.leading, 9)
                .padding(.top, 32)
                .allowsHitTesting(false)
        }
        .accessibilityLabel("Entry from \(entry.createdAt.formatted(date: .abbreviated, time: .omitted)): \(entry.title)")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("This checkpoint has no entries yet")
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("It can stand on its own. Use + to capture what happens along the way.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.neutralTile))
    }

    private func beginHeaderEditing(_ field: HeaderField) {
        headerTitle = checkpoint.title
        headerDetails = checkpoint.details ?? ""
        isEditingHeader = true
        focusedHeaderField = field
    }

    private func saveHeader() {
        let cleanTitle = headerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let cleanDetails = headerDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        checkpoint.title = cleanTitle
        checkpoint.details = cleanDetails.isEmpty ? nil : cleanDetails
        try? context.save()
        focusedHeaderField = nil
        isEditingHeader = false
    }

    private func cancelHeaderEditing() {
        focusedHeaderField = nil
        isEditingHeader = false
    }

    private func moveEntries(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = entries
        guard fromOffsets.allSatisfy(reordered.indices.contains) else { return }
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, entry) in reordered.enumerated() {
            entry.checkpointSortIndex = index
        }
        try? context.save()
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

    private func deleteCheckpoint() {
        for entry in entries {
            entry.checkpoint = nil
            entry.checkpointSortIndex = nil
        }
        context.delete(checkpoint)
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            isShowingDeleteError = true
        }
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
