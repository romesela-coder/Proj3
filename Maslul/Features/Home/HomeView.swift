import SwiftUI
import SwiftData
import UIKit

/// One clear entry point for capture. Classification belongs inside the entry,
/// while the home screen answers what needs attention next.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.userName) private var userName = ""

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    @Query(sort: \EntryTag.name, order: .forward)
    private var availableTags: [EntryTag]

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var isQuickCapturePresented = false
    @State private var quickText = ""
    @State private var quickTags: [EntryTag] = []

    private var calendar: Calendar { Calendar.current }

    private var selectedEntries: [Entry] {
        entries.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }
    }

    private var week: [Date] {
        (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: .now) }
    }

    private var canWriteOnSelectedDay: Bool {
        selectedDate <= calendar.startOfDay(for: .now)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 0) {
                    dayTitle
                    dayStrip
                    dayFeed
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isQuickCapturePresented {
                QuickCaptureBar(
                    text: $quickText,
                    selectedTags: $quickTags,
                    availableTags: availableTags,
                    suggestedTags: suggestedTags,
                    save: saveQuickEntry,
                    dismiss: dismissQuickCaptureInteractively
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .screenBackground()
        .withDock(
            showsCompose: canWriteOnSelectedDay,
            isVisible: !isQuickCapturePresented,
            composeAction: presentQuickCapture
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            CircleButton(symbol: "questionmark") {
                router.tab = .me
                router.mePath = [.privacy]
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
    }

    private var dayTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(calendar.isDateInToday(selectedDate) ? "Today" : Fmt.weekday(calendar.component(.weekday, from: selectedDate)))
                .font(.display(34))
                .displayTracking(34)
            Text(calendar.isDateInToday(selectedDate) ? "What happened today?" : Fmt.longDate(selectedDate))
                .font(.bodyText(14.5))
                .foregroundStyle(Palette.meta)
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
                Button {
                    withAnimation(Motion.spring) { selectedDate = calendar.startOfDay(for: day) }
                } label: {
                    VStack(spacing: 6) {
                        Text(shortWeekday(day))
                            .font(.utility(10))
                            .foregroundStyle(Palette.meta)
                        Text("\(calendar.component(.day, from: day))")
                            .font(.bodyText(14, weight: calendar.isDate(day, inSameDayAs: selectedDate) ? .bold : .regular))
                            .foregroundStyle(calendar.isDate(day, inSameDayAs: selectedDate) ? Palette.ink : Palette.muted)
                        Capsule().fill(calendar.isDate(day, inSameDayAs: selectedDate) ? Palette.ink : Color.clear).frame(width: 24, height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 22)
    }

    private var dayFeed: some View {
        List {
            if !canWriteOnSelectedDay {
                Text("Future dates are here for planning. Entries can be added when the day arrives.")
                    .font(.bodyText(14))
                    .foregroundStyle(Palette.meta)
                    .padding(.vertical, 18)
                    .journalListRow()
            }

            if selectedEntries.isEmpty {
                Text(calendar.isDateInToday(selectedDate) ? "Nothing here yet. What mattered today?" : "No entries on this day.")
                    .font(.bodyText(14)).foregroundStyle(Palette.meta)
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .center)
                    .journalListRow()
            } else {
                ForEach(selectedEntries) { entry in
                    Button { router.open(entry) } label: { EntryRowView(entry: entry) }
                        .buttonStyle(.plain)
                        .journalListRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { moveToTrash(entry) } label: {
                                Label("Trash", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func moveToTrash(_ entry: Entry) {
        entry.moveToTrash()
        try? context.save()
    }

    private func shortWeekday(_ date: Date) -> String {
        String(Fmt.weekday(calendar.component(.weekday, from: date)).prefix(2))
    }

    private func presentQuickCapture() {
        withAnimation(Motion.spring) { isQuickCapturePresented = true }
    }

    private func dismissQuickCapture() {
        withAnimation(.easeOut(duration: 0.2)) { isQuickCapturePresented = false }
    }

    private func dismissQuickCaptureInteractively() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        // Keep the composer alive while it follows the keyboard's own dismissal
        // animation. Removing it first creates a visible two-step jump.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isQuickCapturePresented = false
        }
    }

    private func saveQuickEntry() {
        let body = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let entry = Entry(body: body, createdAt: selectedDate)
        entry.tags = quickTags
        let initialTitle = entry.titleText
        entry.isGeneratingTitle = true
        context.insert(entry)
        try? context.save()
        Task { @MainActor in
            let generated = await LocalMetadataGenerator.title(
                for: body,
                projectName: entry.project?.name,
                type: entry.type
            )
            guard entry.titleText == initialTitle else {
                entry.isGeneratingTitle = false
                return
            }
            entry.titleText = generated
            entry.isGeneratingTitle = false
            try? context.save()
        }
        quickText = ""
        quickTags = []
        dismissQuickCapture()
    }

    private var suggestedTags: [EntryTag] {
        let active = availableTags.filter { !$0.isArchived && TagNameRules.isValid($0.name) }
        var usage: [PersistentIdentifier: (count: Int, recency: Int)] = [:]
        for (index, entry) in entries.prefix(100).enumerated() {
            for tag in entry.tags {
                let current = usage[tag.persistentModelID] ?? (0, 0)
                usage[tag.persistentModelID] = (current.count + 1, max(current.recency, 100 - index))
            }
        }

        let normalizedText = TagNameRules.canonical(quickText)
        var seen: Set<String> = []
        return active
            .filter { seen.insert(TagNameRules.canonical($0.name)).inserted }
            .sorted { lhs, rhs in
                let left = usage[lhs.persistentModelID] ?? (0, 0)
                let right = usage[rhs.persistentModelID] ?? (0, 0)
                let leftMentioned = !normalizedText.isEmpty && normalizedText.contains(TagNameRules.canonical(lhs.name))
                let rightMentioned = !normalizedText.isEmpty && normalizedText.contains(TagNameRules.canonical(rhs.name))
                let leftScore = (leftMentioned ? 10_000 : 0) + left.count * 100 + left.recency
                let rightScore = (rightMentioned ? 10_000 : 0) + right.count * 100 + right.recency
                if leftScore == rightScore {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return leftScore > rightScore
            }
            .prefix(5)
            .map { $0 }
    }
}

private struct QuickCaptureBar: View {
    @Binding var text: String
    @Binding var selectedTags: [EntryTag]
    let availableTags: [EntryTag]
    let suggestedTags: [EntryTag]
    let save: () -> Void
    let dismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var inputLanguage: String?
    @State private var editorHeight: CGFloat = 44
    @State private var isSubmitting = false
    @StateObject private var dictation = SpeechDictationController()

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                InlineMentionEditor(
                    text: $text,
                    tags: $selectedTags,
                    placeholder: "Write something…",
                    fontSize: 18,
                    scrolls: editorHeight >= 108,
                    autoFocus: true,
                    onInputLanguageChange: { inputLanguage = $0 },
                    onContentHeightChange: { measuredHeight in
                        withAnimation(.easeOut(duration: 0.16)) {
                            editorHeight = min(max(measuredHeight, 44), 108)
                        }
                    }
                )
                .frame(height: editorHeight)
                .frame(maxWidth: .infinity)

                Button {
                    dictation.toggle(text: text, language: inputLanguage) { text = $0 }
                } label: {
                    Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(dictation.isRecording ? Color.white : Palette.ink2)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle().fill(dictation.isRecording ? Palette.accent : Color.white)
                        )
                        .overlay(
                            Circle().stroke(
                                dictation.isRecording ? Palette.accent : Palette.ink.opacity(0.18),
                                lineWidth: 1
                            )
                        )
                        .shadow(color: Palette.ink.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dictation.isRecording ? "Stop dictation" : "Start dictation")

                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Palette.line : Palette.control))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }

            TagMentionSuggestions(text: $text, selectedTags: $selectedTags, tags: availableTags)

            suggestedTagRow
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .offset(y: dragOffset)
        .opacity(1 - min(dragOffset / 240, 0.4))
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 64 || value.predictedEndTranslation.height > 110 {
                        dismiss()
                    } else {
                        withAnimation(Motion.spring) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onDisappear { dictation.stop() }
        .alert("Dictation unavailable", isPresented: Binding(
            get: { dictation.errorMessage != nil },
            set: { if !$0 { dictation.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dictation.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var suggestedTagRow: some View {
        let visible = suggestedTags.filter { candidate in
            !selectedTags.contains { $0.persistentModelID == candidate.persistentModelID }
        }
        if !visible.isEmpty, MentionText.query(in: text) == nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(visible) { tag in
                        Button { insertSuggested(tag) } label: {
                            MentionCard(tag: tag)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func submit() {
        guard !isSubmitting,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSubmitting = true

        Task { @MainActor in
            await dictation.stopAndWait()
            save()
        }
    }

    private func insertSuggested(_ tag: EntryTag) {
        guard !selectedTags.contains(where: { $0.persistentModelID == tag.persistentModelID }) else {
            return
        }
        selectedTags.append(tag)
        if let last = text.last, !last.isWhitespace { text.append(" ") }
        text.append("@\(tag.name) ")
    }
}
