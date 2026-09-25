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

/// One roadmap with planned checkpoints and individual journal entries.
struct GoalDetailSheet: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var allEntries: [Entry]
    @Query(sort: \GoalCheckpoint.sortIndex, order: .forward) private var allCheckpoints: [GoalCheckpoint]
    @Query(sort: \EntryBox.sortIndex, order: .forward) private var boxes: [EntryBox]
    @Query(sort: \EntryTag.name, order: .forward) private var tags: [EntryTag]

    @State private var viewingCheckpoint: GoalCheckpoint?
    @State private var selectedEntry: Entry?
    @State private var isAddingCheckpoint = false
    @State private var isImportingBox = false
    @State private var roadmapEditMode: EditMode = .inactive
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

    private enum RoadmapItem: Identifiable {
        case checkpoint(GoalCheckpoint)
        case entry(Entry)

        var id: String {
            switch self {
            case .checkpoint(let checkpoint): "checkpoint-\(checkpoint.persistentModelID)"
            case .entry(let entry): "entry-\(entry.persistentModelID)"
            }
        }

        var manualSortIndex: Int? {
            switch self {
            case .checkpoint(let checkpoint): checkpoint.goalRoadmapSortIndex
            case .entry(let entry): entry.goalRoadmapSortIndex
            }
        }

        func setManualSortIndex(_ index: Int) {
            switch self {
            case .checkpoint(let checkpoint): checkpoint.goalRoadmapSortIndex = index
            case .entry(let entry): entry.goalRoadmapSortIndex = index
            }
        }
    }

    /// A manual drag wins over date placement. New items still enter near their
    /// date-based neighbors without rearranging previously positioned items.
    private var roadmapItems: [RoadmapItem] {
        let initial = datePlacedRoadmapItems
        let positioned = initial.filter { $0.manualSortIndex != nil }
        guard !positioned.isEmpty else { return initial }

        var result = positioned.sorted { lhs, rhs in
            let left = lhs.manualSortIndex ?? 0
            let right = rhs.manualSortIndex ?? 0
            return left == right ? lhs.id < rhs.id : left < right
        }

        for (index, item) in initial.enumerated() where item.manualSortIndex == nil {
            let following = initial[(index + 1)...].first { $0.manualSortIndex != nil }
            if let following, let insertion = result.firstIndex(where: { $0.id == following.id }) {
                result.insert(item, at: insertion)
            } else if let preceding = initial[..<index].reversed().first(where: { prior in
                result.contains(where: { $0.id == prior.id })
            }), let insertion = result.firstIndex(where: { $0.id == preceding.id }) {
                result.insert(item, at: insertion + 1)
            } else {
                result.append(item)
            }
        }
        return result
    }

    /// Before the first drag, an Entry's creation day places it before the
    /// first Checkpoint whose target day is the same or later.
    private var datePlacedRoadmapItems: [RoadmapItem] {
        let orderedCheckpoints = checkpoints
        let datedEntries = entriesBeyondCheckpoints.sorted {
            if $0.createdAt == $1.createdAt {
                return String(describing: $0.persistentModelID) < String(describing: $1.persistentModelID)
            }
            return $0.createdAt < $1.createdAt
        }
        var slots = Array(repeating: [Entry](), count: orderedCheckpoints.count + 1)
        let calendar = Calendar.current

        for entry in datedEntries {
            let entryDay = calendar.startOfDay(for: entry.createdAt)
            let slot = orderedCheckpoints.firstIndex { checkpoint in
                guard let target = checkpoint.dueAt else { return false }
                return entryDay <= calendar.startOfDay(for: target)
            } ?? orderedCheckpoints.count
            slots[slot].append(entry)
        }

        var result: [RoadmapItem] = []
        for index in orderedCheckpoints.indices {
            result.append(contentsOf: slots[index].map(RoadmapItem.entry))
            result.append(.checkpoint(orderedCheckpoints[index]))
        }
        result.append(contentsOf: slots[orderedCheckpoints.count].map(RoadmapItem.entry))
        return result
    }

    var body: some View {
        let items = roadmapItems
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

                    if items.isEmpty {
                        roadmapEmptyState
                            .padding(.horizontal, Metrics.hMargin)
                            .padding(.bottom, 8)
                            .journalListRow()
                    } else {
                        ForEach(items) { item in
                            Group {
                                switch item {
                                case .checkpoint(let checkpoint):
                                    checkpointShelf(checkpoint, isLast: item.id == items.last?.id)
                                case .entry(let entry):
                                    standaloneEntryRow(entry, isLast: item.id == items.last?.id)
                                }
                            }
                            .padding(.horizontal, Metrics.hMargin)
                            .padding(.trailing, roadmapEditMode.isEditing ? -44 : 0)
                            .journalListRow()
                        }
                        .onMove(perform: moveRoadmapItems)
                    }

                    Color.clear
                        .frame(height: isWriting ? 235 : 100)
                        .journalListRow()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.editMode, $roadmapEditMode)

                if isWriting {
                    VStack(spacing: 9) {
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
            .sheet(item: $viewingCheckpoint) { checkpoint in
                GoalEntryCollectionSheet(goal: goal, checkpoint: checkpoint)
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
            if roadmapEditMode.isEditing {
                Button("Done") {
                    withAnimation(Motion.spring) {
                        roadmapEditMode = .inactive
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
                    if roadmapItems.count > 1 {
                        Button {
                            withAnimation(Motion.spring) { roadmapEditMode = .active }
                        } label: {
                            Label("Reorder roadmap", systemImage: "arrow.up.arrow.down")
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

    private func checkpointShelf(_ checkpoint: GoalCheckpoint, isLast: Bool) -> some View {
        let entryCount = entries.filter { $0.checkpoint?.persistentModelID == checkpoint.persistentModelID }.count

        return HStack(alignment: .top, spacing: 9) {
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
            .disabled(roadmapEditMode.isEditing)
            .accessibilityLabel(checkpoint.completedAt == nil ? "Complete checkpoint" : "Reopen checkpoint")

            Button {
                viewingCheckpoint = checkpoint
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(checkpoint.title)
                            .font(.bodyText(17, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 5)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.meta)
                            .padding(.top, 5)
                    }

                    if let details = checkpoint.details, !details.isEmpty {
                        Text(details)
                            .font(.bodyText(13.5))
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 10) {
                        if checkpoint.completedAt != nil {
                            Text("Completed")
                        }
                        if let dueAt = checkpoint.dueAt {
                            Text("Target \(dueAt.formatted(.dateTime.day().month(.abbreviated)))")
                        }
                        Text(entryCount == 1 ? "1 entry" : "\(entryCount) entries")
                    }
                    .font(.utility(11))
                    .foregroundStyle(Palette.meta)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(roadmapEditMode.isEditing)
            .accessibilityLabel("Open \(checkpoint.title), \(entryCount) entries")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(
                    isLast ? Color.clear : Palette.line
                )
                .frame(width: 1)
                .padding(.leading, 9)
                .padding(.top, 32)
                .allowsHitTesting(false)
        }
    }

    private func moveRoadmapItems(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = roadmapItems
        guard fromOffsets.allSatisfy(reordered.indices.contains) else { return }
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, item) in reordered.enumerated() {
            item.setManualSortIndex(index)
        }
        let orderedCheckpoints = reordered.compactMap { item -> GoalCheckpoint? in
            if case .checkpoint(let checkpoint) = item { return checkpoint }
            return nil
        }
        for (index, checkpoint) in orderedCheckpoints.enumerated() {
            checkpoint.sortIndex = index
        }
        try? context.save()
    }

    private func standaloneEntryRow(_ entry: Entry, isLast: Bool) -> some View {
        Button {
            if !roadmapEditMode.isEditing { selectedEntry = entry }
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Circle()
                    .fill(Palette.ink2)
                    .frame(width: 7, height: 7)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(entry.createdAt.formatted(.dateTime.day().month(.abbreviated).year()))
                            .font(.utility(11))
                            .foregroundStyle(Palette.meta)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.meta)
                    }
                    Text(entry.body)
                        .font(.bodyText(15))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
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
        .accessibilityLabel("Entry from \(entry.createdAt.formatted(date: .abbreviated, time: .omitted)): \(entry.body)")
    }

    private func openDirections() {
        isWriting = false
        isChoosingDirection = true
    }

    private func beginWriting() {
        selectedPrompt = nil
        selectedBox = boxes.first(where: { $0.systemKey == "inbox" }) ?? boxes.first
        withAnimation(Motion.spring) { isWriting = true }
    }

    private func saveEntry() {
        guard GoalEntryCreation.save(
            text: text,
            goal: goal,
            checkpoint: nil,
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
