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

    @State private var showProjectPicker = false
    @State private var showDatePicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @FocusState private var bodyFocused: Bool

    private var activeProjects: [Project] {
        // A closed project stays on the entries already filed under it.
        projects.filter { $0.isSelectable || $0.persistentModelID == entry.project?.persistentModelID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    metadataPanel
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
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.bottom, 12)
                    bodyCard
                    dateRow
                    evidenceRow
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
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
        .onChange(of: photoItems) { _, items in
            Task { await addAttachments(items) }
        }
        .onDisappear {
            entry.touch()
            try? context.save()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            CircleButton(symbol: "chevron.forward") { dismiss() }
            Spacer()
            Text("ENTRY")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Chip(title: "Done", isOn: true) { dismiss() }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 20)
        .padding(.bottom, 20)
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

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "NOTE")
            TextEditor(text: $entry.body)
                .font(.bodyText(21))
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 220)
                .focused($bodyFocused)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
        .padding(.bottom, 22)
    }

    private var typeRow: some View {
        DetailRow(label: "סוג") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EntryType.allCases) { candidate in
                        Chip(
                            title: candidate.title,
                            isOn: entry.type == candidate,
                            tint: entry.type == candidate ? nil : candidate.tint
                        ) {
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
