import SwiftUI
import SwiftData
import PhotosUI

private enum SuggestedField: Hashable {
    case type, project, effort, goal
}

/// Ten seconds from tap to saved text: one screen, one required field.
/// Everything else sits behind a single tap and can be ignored entirely (F1).
struct CaptureView: View {
    let presetType: EntryType?
    let presetDate: Date?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.draftBody) private var draftBody = ""
    @AppStorage(SettingsKey.draftType) private var draftType = ""

    @Query(sort: \Project.createdAt, order: .forward)
    private var projects: [Project]

    @Query(sort: \Goal.createdAt, order: .forward)
    private var goals: [Goal]

    @Query(sort: \EntryTag.name, order: .forward)
    private var availableTags: [EntryTag]

    @State private var text = ""
    @State private var type: EntryType?
    @State private var project: Project?
    @State private var origin: TaskOrigin?
    @State private var effort: Effort?
    @State private var goal: Goal?
    @State private var date = Date()
    @State private var isSensitive = false
    @State private var attachmentNames: [String] = []
    @State private var selectedTags: [EntryTag] = []

    @State private var showDatePicker = false
    @State private var addingProject = false
    @State private var addingGoal = false
    @State private var newProjectName = ""
    @State private var newGoalTitle = ""
    @State private var suggestionSource: String?
    @State private var suggestedFields: Set<SuggestedField> = []
    @State private var isGeneratingSuggestions = false
    @State private var suggestionRequestID: UUID?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var didSave = false
    @State private var selectedDetent: PresentationDetent = .large

    private var activeProjects: [Project] {
        projects.filter(\.isSelectable)
    }

    private var activeGoals: [Goal] {
        goals.filter(\.isCurrent)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if selectedDetent == .large {
                expandedComposer
            } else {
                quickComposer
            }
        }
        .presentationDetents([.height(174), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.ground)
        .task {
            restoreDraftIfNeeded()
        }
        .onDisappear(perform: persistDraftIfNeeded)
        .task(id: text) { await refreshSuggestions() }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date)
        }
        .onChange(of: photoItems) { _, items in
            Task { await load(items) }
        }
    }

    // MARK: - Compact composer

    /// This is intentionally a single line above the keyboard.  It keeps the
    /// home screen in writing mode; drag the sheet up only when more context is
    /// actually useful.
    private var quickComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                InlineMentionEditor(
                    text: $text,
                    tags: $selectedTags,
                    placeholder: type?.hint ?? "Write something…",
                    fontSize: 18,
                    autoFocus: true
                )
                .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 72)

                Button {
                    guard canSave else { return }
                    save()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(canSave ? Palette.control : Palette.line))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save entry")
            }

            TagMentionSuggestions(text: $text, selectedTags: $selectedTags, tags: availableTags)

            HStack(spacing: 8) {
                if isGeneratingSuggestions {
                    AIActivityIndicator(messages: ["Reading", "Matching", "Organizing"], compact: true)
                } else {
                    Button { selectedDetent = .large } label: {
                        compactChoice(title: type?.title ?? "+ Type", isSelected: type != nil)
                    }
                    .buttonStyle(.plain)

                    Button { selectedDetent = .large } label: {
                        compactChoice(title: project.map { "\($0.emoji) \($0.name)" } ?? "+ Project", isSelected: project != nil)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button { selectedDetent = .large } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func compactChoice(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.bodyText(13.5, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Palette.ink2)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .frame(minHeight: 34)
            .background(Capsule().fill(isSelected ? Palette.control : Palette.card))
            .overlay(Capsule().stroke(isSelected ? Palette.control : Palette.cardLine, lineWidth: 1))
    }

    // MARK: - Expanded composer

    private var expandedComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(Fmt.stamp(date))
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
                .padding(.horizontal, Metrics.hMargin)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editor
                    TagMentionSuggestions(text: $text, selectedTags: $selectedTags, tags: availableTags)
                    suggestionNote
                    typeSection
                    projectSection
                    originSection
                    effortSection
                    goalSection
                    toolRow
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .screenBackground()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Chip(title: "Cancel") { dismiss() }
            Spacer()
            Text("NEW ENTRY")
                .font(.utility(10.5))
                .tracking(1.4)
                .foregroundStyle(Palette.meta)
            Spacer()
            Chip(title: "Save", isOn: canSave) {
                guard canSave else { return }
                save()
            }
            .opacity(canSave ? 1 : 0.45)
        }
        .padding(.horizontal, Metrics.hMargin)
    }

    // MARK: - Editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(type?.hint ?? "What happened?")
                    .font(.bodyText(17))
                    .foregroundStyle(Palette.meta)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
            InlineMentionEditor(
                text: $text,
                tags: $selectedTags,
                placeholder: "",
                fontSize: 17,
                scrolls: true
            )
            .padding(16)
        }
        .frame(minHeight: 176)
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    // MARK: - Classification

    @ViewBuilder
    private var suggestionNote: some View {
        if isGeneratingSuggestions {
            AIActivityIndicator(messages: ["Reading", "Matching", "Organizing"])
        } else if let suggestionSource, !suggestedFields.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("Suggestions from \(suggestionSource) — tap to change")
            }
            .font(.bodyText(12.5))
            .foregroundStyle(Palette.meta)
        }
    }

    private var typeSection: some View {
        classificationSection("Type") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(EntryType.allCases) { candidate in
                    Button {
                        suggestedFields.remove(.type)
                        withAnimation(Motion.spring) { type = type == candidate ? nil : candidate }
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            EntryIconTile(
                                artifact: EntryArtifact(type: candidate),
                                needsAttention: suggestedFields.contains(.type) && type == candidate,
                                size: 38
                            )
                            Text(candidate.title)
                                .font(.bodyText(13.5, weight: .semibold))
                                .foregroundStyle(type == candidate ? Color.white : Palette.ink)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                        .padding(11)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(type == candidate ? Palette.control : Color.white)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(type == candidate ? Palette.control : Palette.lineSoft, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var projectSection: some View {
        classificationSection("Project") {
            VStack(alignment: .leading, spacing: 8) {
                chipGrid {
                    Chip(title: "No project", isOn: project == nil) { project = nil; suggestedFields.remove(.project) }
                    ForEach(activeProjects) { candidate in
                        Chip(
                            title: chipTitle(candidate.isGeneratingEmoji ? candidate.name : "\(candidate.emoji) \(candidate.name)", field: .project, selected: project === candidate),
                            isOn: project === candidate,
                            isAIWorking: candidate.isGeneratingEmoji
                        ) {
                            project = candidate; suggestedFields.remove(.project)
                        }
                    }
                    if activeProjects.count < Project.activeLimit {
                        Chip(title: "+ Project", isOn: addingProject) { addingProject.toggle() }
                    }
                }
                if addingProject { inlineCreator("Project name", text: $newProjectName, action: addProject) }
            }
        }
    }

    private var originSection: some View {
        classificationSection("Origin") {
            chipGrid {
                Chip(title: "From project", isOn: origin == nil) { origin = nil }
                ForEach(TaskOrigin.allCases) { candidate in
                    Chip(title: candidate.shortTitle, isOn: origin == candidate) { origin = origin == candidate ? nil : candidate }
                }
            }
        }
    }

    private var effortSection: some View {
        classificationSection("Effort") {
            chipGrid {
                ForEach(Effort.allCases) { candidate in
                    Chip(title: chipTitle(candidate.title, field: .effort, selected: effort == candidate), isOn: effort == candidate) {
                        effort = effort == candidate ? nil : candidate; suggestedFields.remove(.effort)
                    }
                }
            }
        }
    }

    private var goalSection: some View {
        classificationSection("Quarterly goal") {
            VStack(alignment: .leading, spacing: 8) {
                chipGrid {
                    Chip(title: "No goal", isOn: goal == nil) { goal = nil; suggestedFields.remove(.goal) }
                    ForEach(activeGoals) { candidate in
                        Chip(
                            title: chipTitle(candidate.isGeneratingEmoji ? candidate.title : "\(candidate.emoji) \(candidate.title)", field: .goal, selected: goal === candidate),
                            isOn: goal === candidate,
                            isAIWorking: candidate.isGeneratingEmoji
                        ) {
                            goal = candidate; suggestedFields.remove(.goal)
                        }
                    }
                    if activeGoals.count < Goal.activeLimit {
                        Chip(title: "+ Goal", isOn: addingGoal) { addingGoal.toggle() }
                    }
                }
                if addingGoal { inlineCreator("Goal name", text: $newGoalTitle, action: addGoal) }
            }
        }
    }

    private func classificationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            content()
        }
    }

    private func chipGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) { content() }
    }

    private func inlineCreator(_ placeholder: String, text: Binding<String>, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: text)
                .font(.bodyText(15)).padding(.horizontal, 14).frame(minHeight: 42)
                .background(Capsule().fill(Color.white)).overlay(Capsule().stroke(Palette.line, lineWidth: 1))
            Button(action: action) {
                Image(systemName: "checkmark").foregroundStyle(Color.white).frame(width: 42, height: 42).background(Circle().fill(Palette.control))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Optional tools

    private var toolRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "More details")
            HStack(spacing: 10) {
            toolButton(symbol: "calendar", isActive: !Calendar.current.isDateInToday(date)) {
                showDatePicker = true
            }

            toolButton(
                symbol: isSensitive ? "lock.fill" : "lock",
                isActive: isSensitive
            ) {
                withAnimation(Motion.spring) { isSensitive.toggle() }
            }

            PhotosPicker(
                selection: $photoItems,
                maxSelectionCount: AttachmentStore.maxPerEntry,
                matching: .images
            ) {
                toolCircle(
                    symbol: attachmentNames.isEmpty ? "paperclip" : "paperclip.badge.ellipsis",
                    isActive: !attachmentNames.isEmpty
                )
            }

            Spacer()

            Text(subtitleForTools)
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
                .lineLimit(1)
            }
        }
    }

    private var subtitleForTools: String {
        if let project { return project.name }
        if isSensitive { return "Sensitive" }
        return "Optional"
    }

    private func toolButton(symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolCircle(symbol: symbol, isActive: isActive)
        }
        .buttonStyle(.plain)
    }

    private func toolCircle(symbol: String, isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? Palette.ink : Palette.neutralTile)
            .overlay(Circle().stroke(isActive ? Palette.ink : Palette.tileLine, lineWidth: 1))
            .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(isActive ? Color.white : Palette.muted)
            )
    }

    // MARK: - Actions

    private func save() {
        let entry = Entry(
            body: text.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: date,
            type: type,
            project: project
        )
        CalendarEntryOrdering.placeAtFront(entry, in: context)
        entry.originOverride = origin
        entry.effort = effort
        entry.goal = goal
        entry.sensitivity = isSensitive ? .sensitive : .normal
        entry.attachmentNames = attachmentNames
        entry.tags = selectedTags
        EntryBoxEntryOrdering.move(entry, to: EntryBoxBootstrap.inbox(in: context))
        context.insert(entry)
        entry.isGeneratingTitle = true
        try? context.save()

        let initialTitle = entry.titleText
        Task { @MainActor in
            let generated = await LocalMetadataGenerator.title(
                for: entry.body,
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

        didSave = true
        clearDraft()
        dismiss()
    }

    /// Leaving mid-write keeps a draft; nothing is thrown away (F1, edge case).
    private func persistDraftIfNeeded() {
        guard !didSave else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearDraft()
            return
        }
        draftBody = text
        draftType = type?.rawValue ?? ""
    }

    private func restoreDraftIfNeeded() {
        type = presetType
        if let presetDate { date = presetDate }
        if presetType == nil, !draftBody.isEmpty {
            text = draftBody
            type = EntryType(rawValue: draftType)
        }
    }

    private func clearDraft() {
        draftBody = ""
        draftType = ""
    }

    private func addProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, activeProjects.count < Project.activeLimit else { return }
        if let existing = activeProjects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            project = existing
        } else {
            let created = Project(name: name)
            context.insert(created)
            project = created
            suggestEmoji(for: created)
        }
        newProjectName = ""
        addingProject = false
    }

    private func addGoal() {
        let title = newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, activeGoals.count < Goal.activeLimit else { return }
        if let existing = activeGoals.first(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame }) {
            goal = existing
        } else {
            let created = Goal(title: title)
            context.insert(created)
            goal = created
            suggestEmoji(for: created)
        }
        newGoalTitle = ""
        addingGoal = false
    }

    private func suggestEmoji(for project: Project) {
        let initial = project.emoji
        project.isGeneratingEmoji = true
        Task { @MainActor in
            let generated = await LocalMetadataGenerator.emoji(for: project.name, fallback: initial)
            guard project.emoji == initial else {
                project.isGeneratingEmoji = false
                return
            }
            project.emoji = generated
            project.isGeneratingEmoji = false
            try? context.save()
        }
    }

    private func suggestEmoji(for goal: Goal) {
        let initial = goal.emoji
        goal.isGeneratingEmoji = true
        Task { @MainActor in
            let generated = await LocalMetadataGenerator.emoji(for: goal.title, fallback: initial)
            guard goal.emoji == initial else {
                goal.isGeneratingEmoji = false
                return
            }
            goal.emoji = generated
            goal.isGeneratingEmoji = false
            try? context.save()
        }
    }

    private func chipTitle(_ title: String, field: SuggestedField, selected: Bool) -> String {
        selected && suggestedFields.contains(field) ? "\(title) ✦" : title
    }

    @MainActor
    private func refreshSuggestions() async {
        let requestID = UUID()
        suggestionRequestID = requestID
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else {
            isGeneratingSuggestions = false
            suggestionSource = nil
            suggestedFields = []
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(650))
        } catch {
            return
        }
        guard !Task.isCancelled, suggestionRequestID == requestID else { return }
        isGeneratingSuggestions = true

        let draft = Entry(body: trimmed, createdAt: date, type: type, project: project)
        draft.effort = effort
        draft.goal = goal
        let suggester = SuggesterFactory.make()
        let result = await suggester.suggest(for: draft, projects: activeProjects, goals: activeGoals)
        guard !Task.isCancelled, suggestionRequestID == requestID else { return }
        isGeneratingSuggestions = false

        var fields: Set<SuggestedField> = []
        if type == nil, let value = result.type { type = value; fields.insert(.type) }
        if project == nil, let value = result.project { project = value; fields.insert(.project) }
        if effort == nil, let value = result.effort { effort = value; fields.insert(.effort) }
        if goal == nil, let value = result.goal { goal = value; fields.insert(.goal) }
        suggestedFields = fields
        suggestionSource = fields.isEmpty ? nil : suggester.sourceLabel
    }

    private func load(_ items: [PhotosPickerItem]) async {
        var names: [String] = []
        for item in items.prefix(AttachmentStore.maxPerEntry) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = AttachmentStore.save(imageData: data) {
                names.append(name)
            }
        }
        await MainActor.run {
            attachmentNames.forEach(AttachmentStore.delete)
            attachmentNames = names
        }
    }
}

// MARK: - Date sheet

struct DatePickerSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Chip(title: "Done", isOn: true) { dismiss() }
                Spacer()
                Text("ENTRY DATE")
                    .font(.utility(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Palette.meta)
                Spacer()
                Chip(title: "Now") { date = .now }
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.top, 20)

            DatePicker("", selection: $date, in: ...Date.now)
                .datePickerStyle(.graphical)
                .environment(\.locale, Fmt.locale)
                .padding(.horizontal, Metrics.hMargin)

            Text("You can backdate an entry, but not date it in the future.")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)

            Spacer()
        }
        .screenBackground()
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
    }
}
