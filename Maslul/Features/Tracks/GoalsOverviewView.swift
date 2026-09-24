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

/// A goal is a timeline first. Writing directions appear only when someone
/// opens the composer and asks for help getting started.
struct GoalDetailSheet: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var allEntries: [Entry]
    @Query(sort: \EntryBox.sortIndex, order: .forward) private var boxes: [EntryBox]
    @Query(sort: \EntryTag.name, order: .forward) private var tags: [EntryTag]

    @State private var selectedEntry: Entry?
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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        goalHeader
                        timelineSection
                    }
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.top, 25)
                    .padding(.bottom, isWriting ? 235 : 110)
                }
                .scrollIndicators(.hidden)

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
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
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

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionLabel(text: "TIMELINE")
            if entries.isEmpty {
                Text("No entries yet. A small thought is enough to begin.")
                    .font(.bodyText(14))
                    .foregroundStyle(Palette.meta)
                    .padding(.vertical, 10)
            } else {
                ForEach(entries) { entry in
                    Button { selectedEntry = entry } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Fmt.stamp(entry.createdAt).uppercased())
                                .font(.utility(10.5))
                                .foregroundStyle(Palette.meta)
                            if let prompt = entry.reflectionPromptText, !prompt.isEmpty {
                                Text(prompt)
                                    .font(.bodyText(12, weight: .medium))
                                    .foregroundStyle(Palette.ink2)
                                    .multilineTextAlignment(.leading)
                            }
                            Text(entry.body)
                                .font(.bodyText(15))
                                .foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 30)
                        .padding(.bottom, 24)
                        .overlay(alignment: .topLeading) {
                            Rectangle()
                                .fill(entry.persistentModelID == entries.last?.persistentModelID ? Color.clear : Palette.line)
                                .frame(width: 1)
                                .padding(.leading, 4)
                                .padding(.top, 12)
                        }
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .fill(Palette.ink)
                                .frame(width: 9, height: 9)
                                .padding(.top, 3)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 35)
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
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let entry = Entry(body: body)
        CalendarEntryOrdering.placeAtFront(entry, in: context)
        entry.goal = goal
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
        selectedBox = nil
        reminderAt = nil
        selection = NSRange(location: 0, length: 0)
        withAnimation(Motion.spring) { isWriting = false }
    }
}
