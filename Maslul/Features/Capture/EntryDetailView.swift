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
                    bodyCard
                    typeRow
                    projectRow
                    originRow
                    effortRow
                    dateRow
                    sensitivityRow
                    evidenceRow
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .confirmationDialog("פרויקט", isPresented: $showProjectPicker, titleVisibility: .visible) {
            ForEach(activeProjects) { candidate in
                Button(candidate.name) { mutate { entry.project = candidate } }
            }
            Button("ללא פרויקט", role: .destructive) { mutate { entry.project = nil } }
            Button("ביטול", role: .cancel) {}
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
            Text("פרטי רשומה")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Chip(title: "סיום", isOn: true) { dismiss() }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Rows

    private var bodyCard: some View {
        CardBox {
            TextEditor(text: $entry.body)
                .font(.bodyText(15.5))
                .foregroundStyle(Palette.ink2)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 96)
                .focused($bodyFocused)
        }
        .padding(.bottom, 6)
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
            DetailRow(label: "תאריך", trailingChevron: true) {
                Text(Fmt.longDate(entry.createdAt))
                    .font(.bodyText(15))
                    .foregroundStyle(Palette.ink)
            }
        }
        .buttonStyle(.plain)
    }

    private var sensitivityRow: some View {
        DetailRow(label: "רגישות", note: "לא ייכנס לייצוא ולחבילת ריוויו") {
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
            SectionLabel(text: "ראיות")
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

            Text("הקבצים מועתקים לאפליקציה ונשארים במכשיר.")
                .font(.bodyText(12))
                .foregroundStyle(Palette.meta)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
