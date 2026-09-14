import SwiftUI
import SwiftData
import PhotosUI

/// Structure comes after writing (spec §03.03). This is where an entry gets
/// its type, project, origin and evidence — never at capture time.
struct EntryDetailView: View {
    @Bindable var entry: Entry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.createdAt, order: .forward)
    private var projects: [Project]

    @Query(sort: \EntryTag.name, order: .forward)
    private var availableTags: [EntryTag]

    @State private var showProjectPicker = false
    @State private var showDatePicker = false
    @State private var showBoxPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var selectedDetent: PresentationDetent = .fraction(0.68)
    @State private var bodyText: AttributedString
    @State private var bodyPlainText: String
    @State private var bodyTags: [EntryTag]
    @State private var bodySelection = AttributedTextSelection()
    @State private var editorFocusRequest = 0

    init(entry: Entry) {
        self.entry = entry
        let attributed = NativeRichTextMentions.applyingStyles(
            to: entry.attributedBody,
            tags: entry.tags
        )
        _bodyText = State(initialValue: attributed)
        _bodyPlainText = State(initialValue: entry.body)
        _bodyTags = State(initialValue: entry.tags)
    }

    private var activeProjects: [Project] {
        // A closed project stays on the entries already filed under it.
        projects.filter { $0.isSelectable || $0.persistentModelID == entry.project?.persistentModelID }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        Button { showBoxPicker = true } label: {
                            EntryBoxTile(box: entry.box, size: 52)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(Palette.tagLemon))
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .offset(x: 3, y: 3)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change entry box")

                        VStack(alignment: .leading, spacing: 2) {
                            ZStack(alignment: .leading) {
                                if entry.titleText.isEmpty {
                                    Text("Title")
                                        .font(.display(24))
                                        .foregroundStyle(Palette.line)
                                        .allowsHitTesting(false)
                                }

                                TextField("", text: $entry.titleText)
                                    .font(.display(24))
                                    .foregroundStyle(Palette.ink)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .onTapGesture { selectedDetent = .large }

                            Text("\(Fmt.stamp(entry.createdAt)) · \(entry.box?.name ?? "Inbox")")
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.bottom, 16)

                    bodyCard(minimumEditorHeight: max(150, proxy.size.height * 0.52))
                    actionRow
                    attachmentStrip
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.top, 22)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .presentationDetents([.fraction(0.68), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.ground)
        .confirmationDialog("Project", isPresented: $showProjectPicker, titleVisibility: .visible) {
            ForEach(activeProjects) { candidate in
                Button(candidate.name) { mutate { entry.project = candidate } }
            }
            Button("No project", role: .destructive) { mutate { entry.project = nil } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $entry.createdAt)
        }
        .sheet(isPresented: $showBoxPicker) {
            EntryBoxPicker(
                selectedBox: Binding(
                    get: { entry.box },
                    set: { value in
                        guard let value else { return }
                        mutate { EntryBoxEntryOrdering.move(entry, to: value) }
                    }
                )
            )
        }
        .onChange(of: photoItems) { _, items in
            Task { await addAttachments(items) }
        }
        .onChange(of: entry.createdAt) { oldValue, newValue in
            guard !Calendar.current.isDate(oldValue, inSameDayAs: newValue) else { return }
            CalendarEntryOrdering.placeAtFront(entry, in: context)
        }
        .onDisappear {
            entry.body = bodyPlainText
            entry.richTextData = EntryRichTextCodec.encodeAttributed(
                NativeRichTextMentions.storageText(from: bodyText)
            )
            entry.tags = bodyTags
            entry.touch()
            try? context.save()
        }
    }

    // MARK: - Reading-first layout

    private var metadataPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            metadataGroup("TYPE") {
                chipFlow {
                    ForEach(EntryType.allCases) { candidate in
                        Chip(title: candidate.title, isOn: entry.type == candidate) {
                            mutate { entry.type = entry.type == candidate ? nil : candidate }
                        }
                    }
                }
            }

            metadataGroup("PROJECT") {
                Button {
                    guard !activeProjects.isEmpty else { return }
                    showProjectPicker = true
                } label: {
                    Chip(title: entry.project.map { "\($0.emoji) \($0.name)" } ?? "+ Project", isOn: entry.project != nil)
                }
                .buttonStyle(.plain)
            }

            metadataGroup("ORIGIN & EFFORT") {
                chipFlow {
                    Chip(title: entry.originOverride?.shortTitle ?? "From project", isOn: entry.originOverride != nil) {
                        mutate { entry.originOverride = entry.originOverride == nil ? .selfInitiated : nil }
                    }
                    ForEach(Effort.allCases) { candidate in
                        Chip(title: candidate.title, isOn: entry.effort == candidate) {
                            mutate { entry.effort = entry.effort == candidate ? nil : candidate }
                        }
                    }
                    Chip(title: entry.isSensitive ? "Sensitive" : "Private", isOn: entry.isSensitive) {
                        mutate { entry.sensitivity = entry.isSensitive ? .normal : .sensitive }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(Palette.cardLine, lineWidth: 1))
        .padding(.bottom, 28)
    }

    private func metadataGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func chipFlow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ChipFlow(spacing: 8, rowSpacing: 10) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
    }

    private func bodyCard(minimumEditorHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NativeRichTextEditor(
                text: $bodyText,
                selection: $bodySelection,
                placeholder: "Write something…",
                fontSize: 21,
                scrolls: false,
                focusRequest: editorFocusRequest,
                onFocus: { selectedDetent = .large },
                onPlainTextChange: richTextDidChange
            )
            .frame(minHeight: minimumEditorHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    if selectedDetent != .large {
                        withAnimation(Motion.spring) { selectedDetent = .large }
                    }
                    editorFocusRequest += 1
                }
            )
            TagMentionSuggestions(
                text: $bodyPlainText,
                selectedTags: $bodyTags,
                tags: availableTags,
                query: NativeRichTextMentions.query(in: bodyText, selection: bodySelection),
                onInsert: insertMention
            )
            NativeRichTextToolbar(
                text: $bodyText,
                selection: $bodySelection,
                baseFontSize: 21
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
        .padding(.bottom, 16)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button { showDatePicker = true } label: {
                compactAction(symbol: "calendar", title: Fmt.dayDot(entry.createdAt), isOn: false)
            }
            .buttonStyle(.plain)

            PhotosPicker(
                selection: $photoItems,
                maxSelectionCount: AttachmentStore.maxPerEntry - entry.attachmentNames.count,
                matching: .images
            ) {
                compactAction(
                    symbol: "paperclip",
                    title: entry.attachmentNames.isEmpty ? "Attach" : "\(entry.attachmentNames.count)",
                    isOn: !entry.attachmentNames.isEmpty
                )
            }
            .disabled(entry.attachmentNames.count >= AttachmentStore.maxPerEntry)

            Button {
                mutate { entry.sensitivity = entry.isSensitive ? .normal : .sensitive }
            } label: {
                compactAction(symbol: entry.isSensitive ? "lock.fill" : "lock.open", title: "Private", isOn: entry.isSensitive)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { moveEntryToTrash() } label: {
                compactAction(symbol: "trash", title: "Trash", isOn: false, isDestructive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1).offset(y: -8)
        }
    }

    private func compactAction(
        symbol: String,
        title: String,
        isOn: Bool,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium))
            Text(title).lineLimit(1)
        }
        .font(.bodyText(12, weight: .semibold))
        .foregroundStyle(isDestructive ? Color.red : (isOn ? Color.white : Palette.ink2))
        .padding(.horizontal, 10)
        .frame(minHeight: 32)
        .background(Capsule().fill(isOn ? Palette.control : Palette.neutralTile))
    }

    private func moveEntryToTrash() {
        entry.body = bodyPlainText
        entry.richTextData = EntryRichTextCodec.encodeAttributed(
            NativeRichTextMentions.storageText(from: bodyText)
        )
        entry.tags = bodyTags
        entry.moveToTrash()
        try? context.save()
        dismiss()
    }

    private func richTextDidChange(_ plainText: String) {
        bodyPlainText = plainText
        bodyTags.removeAll { !NativeRichTextMentions.contains($0, in: plainText) }
    }

    private func insertMention(_ tag: EntryTag) {
        NativeRichTextMentions.insert(tag, into: &bodyText, selection: &bodySelection)
        bodyPlainText = NativeRichTextMentions.plainText(in: bodyText)
    }

    @ViewBuilder
    private var attachmentStrip: some View {
        if !entry.attachmentNames.isEmpty {
            VStack(spacing: 12) {
                ForEach(entry.attachmentNames, id: \.self) { name in
                    attachmentCard(name)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private func attachmentCard(_ name: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = AttachmentStore.image(named: name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Palette.neutralTile
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(Palette.meta)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .allowsHitTesting(false)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.ink.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            )

            Button {
                mutate {
                    entry.attachmentNames.removeAll { $0 == name }
                    AttachmentStore.delete(name)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.ink.opacity(0.78)))
                    .overlay(Circle().stroke(Color.white.opacity(0.32), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private var typeRow: some View {
        DetailRow(label: "סוג") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EntryType.allCases) { candidate in
                        EntryTypeChip(type: candidate, isOn: entry.type == candidate) {
                            mutate {
                                withAnimation(Motion.spring) {
                                    entry.type = (entry.type == candidate) ? nil : candidate
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var projectRow: some View {
        Button {
            guard !activeProjects.isEmpty else { return }
            showProjectPicker = true
        } label: {
            DetailRow(label: "פרויקט", trailingChevron: true) {
                Chip(title: entry.project?.name ?? "ללא פרויקט", isOn: entry.project != nil)
            }
        }
        .buttonStyle(.plain)
    }

    private var originRow: some View {
        DetailRow(
            label: "מקור המשימה",
            note: entry.originOverride == nil ? "יורש מהפרויקט" : "נדרס ברשומה זו"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "ירושה", isOn: entry.originOverride == nil) {
                        mutate { entry.originOverride = nil }
                    }
                    ForEach(TaskOrigin.allCases) { candidate in
                        Chip(title: candidate.shortTitle, isOn: entry.originOverride == candidate) {
                            mutate { entry.originOverride = candidate }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var effortRow: some View {
        DetailRow(label: "מאמץ", note: "רמז איכותני בלבד") {
            HStack(spacing: 8) {
                ForEach(Effort.allCases) { candidate in
                    Chip(title: candidate.title, isOn: entry.effort == candidate) {
                        mutate { entry.effort = (entry.effort == candidate) ? nil : candidate }
                    }
                }
            }
        }
    }

    private var dateRow: some View {
        Button { showDatePicker = true } label: {
            DetailRow(label: "DATE", trailingChevron: true) {
                Text(Fmt.longDate(entry.createdAt))
                    .font(.bodyText(15))
                    .foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
        }
        .buttonStyle(.plain)
    }

    private var sensitivityRow: some View {
        DetailRow(label: "Sensitivity", note: "Excluded from exports and summaries") {
            Toggle("", isOn: Binding(
                get: { entry.isSensitive },
                set: { newValue in mutate { entry.sensitivity = newValue ? .sensitive : .normal } }
            ))
            .labelsHidden()
            .tint(Palette.ink)
        }
    }

    private var evidenceRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "ATTACHMENTS")
                .padding(.top, 15)

            HStack(spacing: 8) {
                ForEach(entry.attachmentNames, id: \.self) { name in
                    thumbnail(name)
                }
                if entry.attachmentNames.count < AttachmentStore.maxPerEntry {
                    PhotosPicker(
                        selection: $photoItems,
                        maxSelectionCount: AttachmentStore.maxPerEntry - entry.attachmentNames.count,
                        matching: .images
                    ) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Palette.line)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundStyle(Palette.meta)
                            )
                    }
                }
                Spacer()
            }

            Text("Attachments stay on this device.")
                .font(.bodyText(12))
                .foregroundStyle(Palette.meta)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
    }

    private func thumbnail(_ name: String) -> some View {
        ZStack(alignment: .topLeading) {
            if let image = AttachmentStore.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.neutralTile)
                    .frame(width: 60, height: 60)
            }

            Button {
                mutate {
                    entry.attachmentNames.removeAll { $0 == name }
                    AttachmentStore.delete(name)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.ink)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
            .offset(x: -6, y: -6)
        }
    }

    // MARK: - Helpers

    private func mutate(_ mutation: () -> Void) {
        mutation()
        entry.touch()
    }

    private func addAttachments(_ items: [PhotosPickerItem]) async {
        var added: [String] = []
        for item in items {
            guard entry.attachmentNames.count + added.count < AttachmentStore.maxPerEntry else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = AttachmentStore.save(imageData: data) {
                added.append(name)
            }
        }
        await MainActor.run {
            entry.attachmentNames.append(contentsOf: added)
            entry.touch()
            photoItems = []
        }
    }
}

// MARK: - Row shell

private struct DetailRow<Content: View>: View {
    let label: String
    var note: String? = nil
    var trailingChevron: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: label)
                if let note {
                    Text(note)
                        .font(.bodyText(12))
                        .foregroundStyle(Palette.meta)
                }
            }
            .frame(width: 96, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .trailing)

            if trailingChevron { Chevron() }
        }
        .padding(.vertical, 15)
        .frame(minHeight: Metrics.rowMinHeight)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}
