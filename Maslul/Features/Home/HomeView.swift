import SwiftUI
import SwiftData

/// One clear entry point for capture. Classification belongs inside the entry,
/// while the home screen answers what needs attention next.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.userName) private var userName = ""

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    @Query(sort: \Project.createdAt, order: .forward)
    private var projects: [Project]

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var isQuickCapturePresented = false
    @State private var quickText = ""
    @State private var quickType: EntryType?
    @State private var quickProject: Project?

    @AppStorage(SettingsKey.draftBody) private var draftBody = ""
    @AppStorage(SettingsKey.draftType) private var draftType = ""

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
                    type: $quickType,
                    project: $quickProject,
                    projects: projects.filter(\.isSelectable),
                    save: saveQuickEntry,
                    expand: expandQuickCapture,
                    dismiss: dismissQuickCapture
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

    private func saveQuickEntry() {
        let body = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let entry = Entry(body: body, createdAt: selectedDate, type: quickType, project: quickProject)
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
        quickType = nil
        quickProject = nil
        dismissQuickCapture()
    }

    private func expandQuickCapture() {
        draftBody = quickText
        draftType = quickType?.rawValue ?? ""
        isQuickCapturePresented = false
        router.newEntry(date: selectedDate)
    }
}

private struct QuickCaptureBar: View {
    @Binding var text: String
    @Binding var type: EntryType?
    @Binding var project: Project?
    let projects: [Project]
    let save: () -> Void
    let expand: () -> Void
    let dismiss: () -> Void

    @FocusState private var isFocused: Bool
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Write something…", text: $text, axis: .vertical)
                    .font(.bodyText(18))
                    .lineLimit(1...3)
                    .focused($isFocused)

                Button(action: save) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Palette.line : Palette.control))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Menu {
                    Button("No type") { type = nil }
                    ForEach(EntryType.allCases) { candidate in
                        Button(candidate.title) { type = candidate }
                    }
                } label: {
                    quickChip(type?.title ?? "+ Type", isOn: type != nil)
                }

                Menu {
                    Button("No project") { project = nil }
                    ForEach(projects) { candidate in
                        Button(candidate.name) { project = candidate }
                    }
                } label: {
                    quickChip(project.map { "\($0.emoji) \($0.name)" } ?? "+ Project", isOn: project != nil)
                }

                Spacer()

                Button(action: expand) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open full entry")
            }
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
                    if dragOffset > 18 {
                        isFocused = false
                    }
                }
                .onEnded { value in
                    if value.translation.height > 64 || value.predictedEndTranslation.height > 110 {
                        withAnimation(.easeOut(duration: 0.18)) {
                            dragOffset = 180
                        }
                        dismiss()
                    } else if value.translation.height < -52 {
                        expand()
                    } else {
                        withAnimation(Motion.spring) {
                            dragOffset = 0
                        }
                        Task {
                            try? await Task.sleep(for: .milliseconds(120))
                            isFocused = true
                        }
                    }
                }
        )
        .task {
            try? await Task.sleep(for: .milliseconds(180))
            isFocused = true
        }
    }

    private func quickChip(_ title: String, isOn: Bool) -> some View {
        Text(title)
            .font(.bodyText(13.5, weight: isOn ? .semibold : .regular))
            .foregroundStyle(isOn ? Color.white : Palette.ink2)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .frame(minHeight: 34)
            .background(Capsule().fill(isOn ? Palette.control : Palette.card))
            .overlay(Capsule().stroke(isOn ? Palette.control : Palette.cardLine, lineWidth: 1))
    }
}
