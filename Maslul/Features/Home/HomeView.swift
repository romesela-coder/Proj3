import SwiftUI
import SwiftData
import UIKit

/// One clear entry point for capture. Classification belongs inside the entry,
/// while the home screen answers what needs attention next.
struct HomeView: View {
    private enum ViewMode {
        case calendar
        case boxes
    }

    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.userName) private var userName = ""

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    @Query(sort: \EntryTag.name, order: .forward)
    private var availableTags: [EntryTag]

    @Query(sort: \EntryBox.sortIndex, order: .forward)
    private var boxes: [EntryBox]

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var isQuickCapturePresented = false
    @State private var quickText = ""
    @State private var quickTags: [EntryTag] = []
    @State private var quickBox: EntryBox?
    @State private var viewMode: ViewMode = .calendar
    @State private var weekAnchorDate = Calendar.current.startOfDay(for: .now)
    @State private var calendarEntryRowFrames: [CGRect] = []
    @State private var calendarEditMode: EditMode = .inactive

    private var calendar: Calendar { Calendar.current }

    private var selectedEntries: [Entry] {
        entries
            .filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }
            .sorted { lhs, rhs in
                if lhs.calendarSortIndex == rhs.calendarSortIndex {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.calendarSortIndex < rhs.calendarSortIndex
            }
    }

    private var week: [Date] {
        (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: weekAnchorDate) }
    }

    private var canWriteOnSelectedDay: Bool {
        selectedDate <= calendar.startOfDay(for: .now)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                if viewMode == .calendar {
                    VStack(alignment: .leading, spacing: 0) {
                        modeHeading(
                            title: calendar.isDateInToday(selectedDate)
                                ? "Today"
                                : Fmt.weekday(calendar.component(.weekday, from: selectedDate)),
                            subtitle: calendar.isDateInToday(selectedDate)
                                ? "What happened today?"
                                : Fmt.longDate(selectedDate)
                        )
                        dayStrip
                        dayFeed
                    }
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.top, 30)
                    .coordinateSpace(name: "home-calendar")
                    .onPreferenceChange(CalendarEntryRowFramesKey.self) { frames in
                        calendarEntryRowFrames = frames
                    }
                    .simultaneousGesture(daySwipeGesture)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        modeHeading(
                            title: "Boxes",
                            subtitle: "Everything, where it belongs."
                        )
                            .padding(.horizontal, Metrics.hMargin)
                        BoxesBoardView(
                            boxes: boxes,
                            entries: entries,
                            openBox: { router.open($0) },
                            openEntry: { router.open($0) }
                        )
                    }
                    .padding(.top, 30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isQuickCapturePresented {
                QuickCaptureBar(
                    text: $quickText,
                    selectedTags: $quickTags,
                    selectedBox: $quickBox,
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

    private func viewModeButton(_ mode: ViewMode, symbol: String) -> some View {
        let isSelected = viewMode == mode
        return Button {
            withAnimation(Motion.spring) { viewMode = mode }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Palette.muted)
                .frame(width: 46, height: 40)
                .background(Capsule().fill(isSelected ? Palette.control : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .calendar ? "Calendar view" : "Boxes view")
    }

    private func modeHeading(title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.display(34))
                    .displayTracking(34)
                Text(subtitle)
                    .font(.bodyText(15.5))
                    .foregroundStyle(Palette.meta)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                CircleButton(symbol: "magnifyingglass") {
                    router.openSearch()
                }
                .accessibilityLabel("Global search")

                HStack(spacing: 2) {
                    viewModeButton(.calendar, symbol: "calendar")
                    viewModeButton(.boxes, symbol: "square.grid.2x2")
                }
                .padding(4)
                .background(Capsule().fill(Palette.neutralTile))
            }
            .padding(.top, 1)
        }
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(
            minimumDistance: 36,
            coordinateSpace: .named("home-calendar")
        )
            .onEnded { value in
                guard !calendarEditMode.isEditing else { return }
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height),
                      abs(horizontal) > 54 else { return }

                // Keep drags that start on an entry available for that row's
                // native actions. Any other horizontal drag changes the day.
                guard selectedEntries.isEmpty || !calendarEntryRowFrames.isEmpty else { return }
                guard !calendarEntryRowFrames.contains(where: {
                    $0.insetBy(dx: -8, dy: -8).contains(value.startLocation)
                }) else { return }
                moveSelectedDay(by: horizontal < 0 ? 1 : -1)
            }
    }

    private func moveSelectedDay(by offset: Int) {
        guard let next = calendar.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        let nextDay = calendar.startOfDay(for: next)
        withAnimation(Motion.spring) {
            stopCalendarReordering()
            selectedDate = nextDay
            if let first = week.first, let last = week.last,
               next < first || next > last {
                weekAnchorDate = nextDay
            }
        }
    }

    private func selectDay(_ day: Date) {
        let selectedDay = calendar.startOfDay(for: day)
        withAnimation(Motion.spring) {
            stopCalendarReordering()
            selectedDate = selectedDay
        }
    }

    private var dayStrip: some View {
        VStack(spacing: 13) {
            HStack {
                Text(monthLabel)
                    .font(.utility(11))
                    .tracking(2.2)
                    .foregroundStyle(Palette.meta)
                Spacer()
                Text("\(selectedEntries.count) CAUGHT")
                    .font(.utility(11))
                    .tracking(1.6)
                    .foregroundStyle(Palette.meta)

                calendarSortControl
            }

            HStack(spacing: 7) {
                ForEach(week, id: \.self) { day in
                    Button {
                        selectDay(day)
                    } label: {
                        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                        VStack(spacing: 8) {
                            Text(shortWeekday(day).uppercased())
                                .font(.utility(10))
                                .foregroundStyle(Palette.meta)
                            Text("\(calendar.component(.day, from: day))")
                                .font(.bodyText(15.5, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? Color.white : Palette.ink2)
                                .frame(width: 43, height: 48)
                                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(isSelected ? Palette.ink : Palette.neutralTile))
                            Circle()
                                .fill(entries.contains { calendar.isDate($0.createdAt, inSameDayAs: day) } ? Color(rgb: 0xC7FF32) : Color.clear)
                                .frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var calendarSortControl: some View {
        if calendarEditMode.isEditing {
            Button {
                withAnimation(Motion.spring) { stopCalendarReordering() }
            } label: {
                calendarSortLabel(title: "Done", symbol: "checkmark", isActive: true)
            }
            .buttonStyle(.plain)
        } else {
            Menu {
                Button {
                    withAnimation(Motion.spring) {
                        calendarEditMode = .active
                    }
                } label: {
                    Label("Manual order", systemImage: "line.3.horizontal")
                }

                Divider()

                Button {
                    applyCalendarSort(newestFirst: true)
                } label: {
                    Label("Newest first", systemImage: "arrow.down")
                }

                Button {
                    applyCalendarSort(newestFirst: false)
                } label: {
                    Label("Oldest first", systemImage: "arrow.up")
                }
            } label: {
                calendarSortLabel(title: "Sort", symbol: "arrow.up.arrow.down", isActive: false)
            }
        }
    }

    private func calendarSortLabel(title: String, symbol: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
        }
        .font(.bodyText(11.5, weight: .semibold))
        .foregroundStyle(isActive ? Color.white : Palette.ink2)
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(Capsule().fill(isActive ? Palette.control : Palette.neutralTile))
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
                    Button { router.open(entry) } label: {
                        TodayEntryRow(entry: entry)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: CalendarEntryRowFramesKey.self,
                                        value: [proxy.frame(in: .named("home-calendar"))]
                                    )
                                }
                            )
                    }
                        .buttonStyle(.plain)
                        .disabled(calendarEditMode.isEditing)
                        .journalListRow()
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: !calendarEditMode.isEditing
                        ) {
                            if !calendarEditMode.isEditing {
                                Button(role: .destructive) { moveToTrash(entry) } label: {
                                    Label("Trash", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                }
                .onMove(perform: moveCalendarEntries)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .environment(\.editMode, $calendarEditMode)
    }

    private func stopCalendarReordering() {
        calendarEditMode = .inactive
    }

    private func applyCalendarSort(newestFirst: Bool) {
        let ordered = selectedEntries.sorted {
            newestFirst ? $0.createdAt > $1.createdAt : $0.createdAt < $1.createdAt
        }
        persistCalendarOrder(ordered)
    }

    private func moveCalendarEntries(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = selectedEntries
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persistCalendarOrder(reordered)
    }

    private func persistCalendarOrder(_ ordered: [Entry]) {
        for (index, entry) in ordered.enumerated() {
            entry.calendarSortIndex = index
        }
        try? context.save()
    }

    private func moveToTrash(_ entry: Entry) {
        entry.moveToTrash()
        try? context.save()
    }

    private func shortWeekday(_ date: Date) -> String {
        String(Fmt.weekday(calendar.component(.weekday, from: date)).prefix(2))
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedDate).uppercased()
    }

    private func presentQuickCapture() {
        quickBox = boxes.first(where: { $0.systemKey == "inbox" }) ?? boxes.first
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
        let entry = Entry(body: body, createdAt: timestampForSubmission())
        CalendarEntryOrdering.placeAtFront(entry, in: context)
        entry.tags = quickTags
        EntryBoxEntryOrdering.move(
            entry,
            to: quickBox ?? EntryBoxBootstrap.inbox(in: context)
        )
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
        quickBox = nil
        dismissQuickCapture()
    }

    private func timestampForSubmission(at submittedAt: Date = .now) -> Date {
        let submissionDay = calendar.startOfDay(for: submittedAt)
        if selectedDate != submissionDay {
            selectedDate = submissionDay
            weekAnchorDate = submissionDay
        }
        return submittedAt
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

private struct TodayEntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 9) {
                EntryBoxTile(box: entry.box, size: 48)
                Text(Fmt.time(entry.createdAt))
                    .font(.utility(11.5))
                    .foregroundStyle(Palette.meta)
            }
            .frame(width: 58)

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.bodyText(18, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

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
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

private struct CalendarEntryRowFramesKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct QuickCaptureBar: View {
    @Binding var text: String
    @Binding var selectedTags: [EntryTag]
    @Binding var selectedBox: EntryBox?
    let availableTags: [EntryTag]
    let suggestedTags: [EntryTag]
    let save: () -> Void
    let dismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var inputLanguage: String?
    @State private var editorHeight: CGFloat = 44
    @State private var isSubmitting = false
    @State private var showBoxPicker = false
    @StateObject private var dictation = SpeechDictationController()

    var body: some View {
        VStack(spacing: 8) {
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
                        .foregroundStyle(dictation.isRecording ? Palette.ink : Palette.ink2)
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

            composerAccessoryRow
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
        .sheet(isPresented: $showBoxPicker) {
            EntryBoxPicker(selectedBox: $selectedBox)
        }
        .alert("Dictation unavailable", isPresented: Binding(
            get: { dictation.errorMessage != nil },
            set: { if !$0 { dictation.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dictation.errorMessage ?? "")
        }
    }

    private var composerAccessoryRow: some View {
        let visible = suggestedTags.filter { candidate in
            !selectedTags.contains { $0.persistentModelID == candidate.persistentModelID }
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Button { showBoxPicker = true } label: {
                    EntryBoxChip(box: selectedBox)
                }
                .buttonStyle(.plain)

                if !visible.isEmpty, MentionText.query(in: text) == nil {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 2)

                    ForEach(visible) { tag in
                        Button { insertSuggested(tag) } label: {
                            MentionCard(tag: tag)
                        }
                        .buttonStyle(.plain)
                    }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
