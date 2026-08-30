import SwiftUI
import SwiftData
import PhotosUI

/// Ten seconds from tap to saved text: one screen, one required field.
/// Everything else sits behind a single tap and can be ignored entirely (F1).
struct CaptureView: View {
    let presetType: EntryType?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.draftBody) private var draftBody = ""
    @AppStorage(SettingsKey.draftType) private var draftType = ""

    @Query(sort: \Project.createdAt, order: .forward)
    private var projects: [Project]

    @State private var text = ""
    @State private var type: EntryType?
    @State private var project: Project?
    @State private var date = Date()
    @State private var isSensitive = false
    @State private var attachmentNames: [String] = []

    @State private var showProjectPicker = false
    @State private var showDatePicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var didSave = false

    @FocusState private var isFocused: Bool

    private var activeProjects: [Project] {
        projects.filter(\.isSelectable)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(Fmt.stamp(date))
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
                .padding(.horizontal, Metrics.hMargin)

            editor

            typeRow
            toolRow
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .screenBackground()
        .task {
            restoreDraftIfNeeded()
            try? await Task.sleep(for: .milliseconds(320))
            isFocused = true
        }
        .onDisappear(perform: persistDraftIfNeeded)
        .confirmationDialog("פרויקט", isPresented: $showProjectPicker, titleVisibility: .visible) {
            ForEach(activeProjects) { candidate in
                Button(candidate.name) { project = candidate }
            }
            Button("ללא פרויקט", role: .destructive) { project = nil }
            Button("ביטול", role: .cancel) {}
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date)
        }
        .onChange(of: photoItems) { _, items in
            Task { await load(items) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Chip(title: "ביטול") { dismiss() }
            Spacer()
            Text("רשומה חדשה")
                .font(.utility(10.5))
                .tracking(1.4)
                .foregroundStyle(Palette.meta)
            Spacer()
            Chip(title: "שמור", isOn: canSave) {
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
                Text(type?.hint ?? "מה קרה?")
                    .font(.bodyText(17))
                    .foregroundStyle(Palette.meta)
                    .padding(.horizontal, Metrics.hMargin + 5)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.bodyText(17))
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($isFocused)
                .padding(.horizontal, Metrics.hMargin)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Type row

    private var typeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EntryType.allCases) { candidate in
                    Chip(
                        title: candidate.title,
                        isOn: type == candidate,
                        tint: type == candidate ? nil : candidate.tint
                    ) {
                        withAnimation(Motion.spring) {
                            type = (type == candidate) ? nil : candidate
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.hMargin)
        }
    }

    // MARK: - Optional tools

    private var toolRow: some View {
        HStack(spacing: 10) {
            toolButton(
                symbol: project == nil ? "folder" : "folder.fill",
                isActive: project != nil
            ) {
                guard !activeProjects.isEmpty else { return }
                showProjectPicker = true
            }

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
        .padding(.horizontal, Metrics.hMargin)
        .padding(.bottom, 10)
    }

    private var subtitleForTools: String {
        if let project { return project.name }
        if isSensitive { return "רגישה" }
        return "אופציונלי"
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
        entry.sensitivity = isSensitive ? .sensitive : .normal
        entry.attachmentNames = attachmentNames
        context.insert(entry)
        try? context.save()

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
        if presetType == nil, !draftBody.isEmpty {
            text = draftBody
            type = EntryType(rawValue: draftType)
        }
    }

    private func clearDraft() {
        draftBody = ""
        draftType = ""
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
                Chip(title: "סיום", isOn: true) { dismiss() }
                Spacer()
                Text("תאריך הרשומה")
                    .font(.utility(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Palette.meta)
                Spacer()
                Chip(title: "עכשיו") { date = .now }
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.top, 20)

            DatePicker("", selection: $date, in: ...Date.now)
                .datePickerStyle(.graphical)
                .environment(\.locale, Fmt.locale)
                .padding(.horizontal, Metrics.hMargin)

            Text("אפשר לתארך אחורה. אי אפשר לתארך קדימה.")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)

            Spacer()
        }
        .screenBackground()
        .presentationDetents([.medium, .large])
    }
}
