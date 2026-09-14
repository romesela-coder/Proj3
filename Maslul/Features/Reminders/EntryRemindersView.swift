import SwiftUI
import SwiftData

struct EntryRemindersView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    private var upcoming: [Entry] {
        entries
            .filter { ($0.reminderAt ?? .distantPast) > .now }
            .sorted { ($0.reminderAt ?? .distantFuture) < ($1.reminderAt ?? .distantFuture) }
    }

    private var archived: [Entry] {
        entries
            .filter { $0.reminderAt == nil && $0.archivedReminderAt != nil }
            .sorted { ($0.archivedReminderAt ?? .distantPast) > ($1.archivedReminderAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if archived.isEmpty && upcoming.isEmpty {
                emptyState
            } else {
                reminderList
            }
        }
        .screenBackground()
        .withDock()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .task {
            EntryReminderScheduler.archivePassedReminders(in: entries)
            try? context.save()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "chevron.forward") { dismiss() }

            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders")
                    .font(.display(28))
                    .displayTracking(28)
                    .foregroundStyle(Palette.ink)
                Text("Entries waiting to resurface.")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.meta)
            }

            Spacer()
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var reminderList: some View {
        List {
            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { entry in
                        reminderRow(
                            entry,
                            reminderDate: entry.reminderAt ?? .now,
                            isArchived: false
                        )
                    }
                } header: {
                    SectionLabel(text: "UPCOMING")
                }
            }

            if !archived.isEmpty {
                Section {
                    ForEach(archived) { entry in
                        reminderRow(
                            entry,
                            reminderDate: entry.archivedReminderAt ?? .now,
                            isArchived: true
                        )
                    }
                } header: {
                    SectionLabel(text: "ARCHIVED")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func reminderRow(_ entry: Entry, reminderDate: Date, isArchived: Bool) -> some View {
        Button {
            router.open(entry)
        } label: {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 9) {
                    EntryBoxTile(box: entry.box, size: 48)
                    Text(Fmt.dayDot(reminderDate))
                        .font(.utility(11.5))
                        .foregroundStyle(Palette.meta)
                }
                .frame(width: 58)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(entry.title)
                            .font(.bodyText(18, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        EntryReminderMark(
                            entry: entry,
                            reminderAt: reminderDate,
                            isArchived: isArchived
                        )
                    }

                    Text(Fmt.reminderStamp(reminderDate))
                        .font(.utility(11))
                        .foregroundStyle(Palette.meta)

                    if entry.title != entry.body {
                        InlineMentionText(
                            text: entry.body,
                            tags: entry.tags,
                            fontSize: 14.5,
                            maximumNumberOfLines: 2
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, Metrics.hMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .environment(\.layoutDirection, .leftToRight)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.lineSoft).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .journalListRow()
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation(Motion.spring) {
                    if isArchived {
                        EntryReminderScheduler.removeArchivedReminder(from: entry)
                    } else {
                        EntryReminderScheduler.removeReminder(from: entry)
                    }
                    try? context.save()
                }
            } label: {
                Label(isArchived ? "Delete from archive" : "Remove reminder", systemImage: "bell.slash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.meta)
            Text("No reminders")
                .font(.bodyText(16, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            Text("Tap the bell while capturing an entry to bring it back later.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.hMargin)
    }
}
