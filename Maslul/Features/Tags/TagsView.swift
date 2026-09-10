import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    @Query(sort: \TagGroup.createdAt, order: .forward) private var groups: [TagGroup]
    @Query(sort: \Project.createdAt, order: .forward) private var projects: [Project]

    @State private var editingGroup: TagGroup?
    @State private var openedGroup: TagGroup?
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""
    @State private var backSwipeOffset: CGFloat = 0

    private var visibleGroups: [TagGroup] { groups.filter { !$0.isArchived } }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header

                List {
                    Text("Tags turn names, projects and recurring themes into things you can find again.")
                        .font(.bodyText(14))
                        .foregroundStyle(Palette.meta)
                        .padding(.bottom, 10)
                        .tagListRow()

                    SectionLabel(text: "GROUPS")
                        .tagListRow()

                    ForEach(visibleGroups) { group in
                        groupRow(group)
                            .tagListRow()
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if group.systemKey == nil {
                                    Button(role: .destructive) {
                                        deleteGroup(group)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }

            if isCreatingGroup {
                InlineCreateBar(
                    text: $newGroupName,
                    placeholder: "Group name…",
                    save: saveNewGroup,
                    dismiss: dismissNewGroup
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { TagBootstrap.ensureDefaults(in: context, projects: projects) }
        .sheet(item: $editingGroup) { group in
            TagGroupEditView(group: group)
        }
        .sheet(item: $openedGroup) { group in
            TagGroupDetailView(group: group)
        }
        .offset(x: backSwipeOffset)
        .shadow(
            color: Palette.ink.opacity(backSwipeOffset > 0 ? 0.10 : 0),
            radius: 14,
            x: -5
        )
        .simultaneousGesture(backSwipe)
    }

    private var header: some View {
        HStack {
            CircleButton(symbol: "chevron.forward") { closeToHomeAnimated() }
            Spacer()
            Text("Tags")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Chip(title: "New group", isOn: true) { createGroup() }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private func groupRow(_ group: TagGroup) -> some View {
        Button { openedGroup = group } label: {
            HStack(spacing: 12) {
                Group {
                    if group.isGeneratingEmoji {
                        AIActivityGlyph(size: 17)
                    } else {
                        Text(group.emoji.isEmpty ? "🏷️" : group.emoji)
                            .font(.system(size: 20))
                    }
                }
                .frame(width: 38, height: 38)
                .background(Circle().fill(Palette.neutralTile))

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.bodyText(15.5, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(groupSubtitle(group))
                        .font(.bodyText(12.5))
                        .foregroundStyle(Palette.meta)
                        .lineLimit(1)
                }

                Spacer()
                Chevron()
            }
            .padding(.vertical, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.lineSoft).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit group") { editingGroup = group }
        }
    }

    private func groupSubtitle(_ group: TagGroup) -> String {
        let active = Set(
            group.tags
                .filter { !$0.isArchived && TagNameRules.isValid($0.name) }
                .map { TagNameRules.canonical($0.name) }
        ).count
        let choice = group.allowsMultiple ? "multiple" : "single choice"
        return "\(active) tags · \(choice)"
    }

    private func createGroup() {
        newGroupName = ""
        withAnimation(Motion.spring) { isCreatingGroup = true }
    }

    private func dismissNewGroup() {
        withAnimation(.easeOut(duration: 0.18)) { isCreatingGroup = false }
    }

    private func saveNewGroup() {
        guard TagNameRules.isValid(newGroupName) else { return }
        let name = TagNameRules.normalized(newGroupName)
        let group = TagGroup(name: name, emoji: TagGroup.suggestedEmoji(for: name))
        group.isGeneratingEmoji = true
        context.insert(group)
        try? context.save()
        dismissNewGroup()

        Task { @MainActor in
            group.emoji = await LocalMetadataGenerator.emoji(
                for: name,
                fallback: TagGroup.suggestedEmoji(for: name)
            )
            group.isGeneratingEmoji = false
            try? context.save()
        }
    }

    private var backSwipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard value.startLocation.x < 32,
                      value.translation.width > 0,
                      abs(value.translation.height) < 90 else { return }
                backSwipeOffset = value.translation.width
            }
            .onEnded { value in
                guard value.startLocation.x < 32 else { return }
                let shouldClose = value.translation.width > 85 || value.predictedEndTranslation.width > 180
                if shouldClose {
                    closeToHomeAnimated()
                } else {
                    withAnimation(Motion.spring) { backSwipeOffset = 0 }
                }
            }
    }

    private func closeToHomeAnimated() {
        withAnimation(.easeOut(duration: 0.22)) {
            backSwipeOffset = UIScreen.main.bounds.width + 24
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            router.closeTagsToHome()
            backSwipeOffset = 0
        }
    }

    private func deleteGroup(_ group: TagGroup) {
        guard group.systemKey == nil else { return }
        context.delete(group)
        try? context.save()
    }
}

private struct TagGroupDetailView: View {
    @Bindable var group: TagGroup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var editingTag: EntryTag?
    @State private var editingGroup: TagGroup?
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var duplicateTagName = false

    @Query private var allTags: [EntryTag]

    private var activeTags: [EntryTag] {
        var seen: Set<String> = []
        return group.tags
            .filter { !$0.isArchived && TagNameRules.isValid($0.name) }
            .sorted { $0.createdAt < $1.createdAt }
            .filter { seen.insert(TagNameRules.canonical($0.name)).inserted }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    CircleButton(symbol: "xmark") { dismiss() }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(group.emoji) \(group.name)")
                            .font(.bodyText(16, weight: .bold))
                        Text(group.allowsMultiple ? "Multiple selection" : "Single selection")
                            .font(.bodyText(11.5))
                            .foregroundStyle(Palette.meta)
                    }
                    Spacer()
                    CircleButton(symbol: "slider.horizontal.3") { editingGroup = group }
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.top, 14)
                .padding(.bottom, 18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(text: "TAGS")
                            .padding(.bottom, 10)

                        TagCloudLayout(spacing: 8) {
                            Button { createTag() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("New tag")
                                }
                                .font(.bodyText(14, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 15)
                                .frame(minHeight: 40)
                                .background(Capsule().fill(Palette.control))
                            }
                            .buttonStyle(.plain)

                            ForEach(activeTags) { tag in tagPill(tag) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                    }
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.bottom, 30)
                }
            }

            if isCreatingTag {
                InlineCreateBar(
                    text: $newTagName,
                    placeholder: "Tag name…",
                    errorMessage: duplicateTagName ? "A tag with this name already exists." : nil,
                    save: saveNewTag,
                    dismiss: dismissNewTag
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .sheet(item: $editingTag) { tag in TagEditView(tag: tag) }
        .sheet(item: $editingGroup) { group in TagGroupEditView(group: group) }
    }

    private func tagPill(_ tag: EntryTag) -> some View {
        Button { editingTag = tag } label: {
            Text(tag.name)
                .lineLimit(1)
            .font(.bodyText(14, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 15)
            .frame(minHeight: 40)
            .background(Capsule().fill(TagColorOption(rawValue: tag.colorRaw)?.color ?? Palette.neutralTile))
            .overlay(Capsule().stroke(tag.colorRaw == "neutral" ? Palette.line : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit tag")
        .contextMenu {
            Button(role: .destructive) {
                deleteTag(tag)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func createTag() {
        newTagName = ""
        duplicateTagName = false
        withAnimation(Motion.spring) { isCreatingTag = true }
    }

    private func dismissNewTag() {
        withAnimation(.easeOut(duration: 0.18)) { isCreatingTag = false }
    }

    private func saveNewTag() {
        guard TagNameRules.isValid(newTagName) else { return }
        let name = TagNameRules.normalized(newTagName)
        guard !allTags.contains(where: { TagNameRules.canonical($0.name) == TagNameRules.canonical(name) }) else {
            duplicateTagName = true
            return
        }
        context.insert(EntryTag(name: name, group: group))
        try? context.save()
        dismissNewTag()
    }

    private func deleteTag(_ tag: EntryTag) {
        context.delete(tag)
        try? context.save()
    }
}

private struct TagGroupEditView: View {
    @Bindable var group: TagGroup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var focusedField: Field?

    private enum Field { case name }

    private var trimmedName: String { TagNameRules.normalized(group.name) }

    var body: some View {
        editorShell(
            title: "TAG GROUP",
            height: 330,
            canSave: TagNameRules.isValid(group.name),
            save: save,
            cancel: cancel
        ) {
            editorField(label: "NAME", placeholder: "People, Projects…", text: $group.name)
                .focused($focusedField, equals: .name)

            VStack(alignment: .leading, spacing: 7) {
                SectionLabel(text: "ICON")
                TextField("🏷️", text: $group.emoji)
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .frame(width: 62, height: 50)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "SELECTION")
                HStack(spacing: 8) {
                    Chip(title: "One", isOn: !group.allowsMultiple) { group.allowsMultiple = false }
                    Chip(title: "Multiple", isOn: group.allowsMultiple) { group.allowsMultiple = true }
                }
            }

        }
        .onAppear { if group.name.isEmpty { focusedField = .name } }
    }

    private func save() {
        guard TagNameRules.isValid(group.name) else { return }
        group.name = trimmedName
        let enteredEmoji = normalizedEmoji(group.emoji)
        group.emoji = enteredEmoji ?? TagGroup.suggestedEmoji(for: trimmedName)
        try? context.save()
        dismiss()

        guard enteredEmoji == nil else { return }
        group.isGeneratingEmoji = true
        Task { @MainActor in
            let generated = await LocalMetadataGenerator.emoji(
                for: group.name,
                fallback: TagGroup.suggestedEmoji(for: group.name)
            )
            group.emoji = generated
            group.isGeneratingEmoji = false
            try? context.save()
        }
    }

    private func cancel() {
        if trimmedName.isEmpty { context.delete(group); try? context.save() }
        dismiss()
    }
}

private struct TagEditView: View {
    @Bindable var tag: EntryTag
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var focusedField: Field?
    @Query private var allTags: [EntryTag]

    private enum Field { case name }

    private var trimmedName: String { TagNameRules.normalized(tag.name) }
    private var isUnique: Bool {
        !allTags.contains {
            $0.persistentModelID != tag.persistentModelID &&
            TagNameRules.canonical($0.name) == TagNameRules.canonical(tag.name)
        }
    }

    var body: some View {
        editorShell(
            title: "TAG",
            height: 305,
            canSave: TagNameRules.isValid(tag.name) && isUnique,
            save: save,
            cancel: cancel
        ) {
            editorField(label: "NAME", placeholder: "Tag name", text: $tag.name)
                .focused($focusedField, equals: .name)

            if !isUnique {
                Text("A tag with this name already exists.")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.accent)
            }

            VStack(alignment: .leading, spacing: 9) {
                SectionLabel(text: "COLOR")
                HStack(spacing: 10) {
                    ForEach(TagColorOption.allCases) { option in
                        Button {
                            tag.colorRaw = option.rawValue
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Palette.line, lineWidth: option == .neutral ? 1 : 0))
                                .overlay {
                                    if tag.colorRaw == option.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Palette.ink)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                    }
                }
            }

            Button("Delete tag", role: .destructive) {
                deleteTag()
            }
            .font(.bodyText(14.5, weight: .semibold))
        }
        .onAppear { if tag.name.isEmpty { focusedField = .name } }
    }

    private func save() {
        guard TagNameRules.isValid(tag.name), isUnique else { return }
        tag.name = trimmedName
        try? context.save()
        dismiss()
    }

    private func cancel() {
        if trimmedName.isEmpty { context.delete(tag); try? context.save() }
        dismiss()
    }

    private func deleteTag() {
        context.delete(tag)
        try? context.save()
        dismiss()
    }
}

enum TagColorOption: String, CaseIterable, Identifiable {
    case neutral
    case green
    case blue
    case coral
    case violet
    case yellow
    case mint

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .neutral: return Palette.neutralTile
        case .green: return Palette.win
        case .blue: return Palette.learning
        case .coral: return Palette.friction
        case .violet: return Palette.decision
        case .yellow: return Palette.goal
        case .mint: return Palette.people
        }
    }
}

private func normalizedEmoji(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.first.map(String.init)
}

private func editorField(
    label: String,
    placeholder: String,
    text: Binding<String>,
    width: CGFloat? = nil
) -> some View {
    VStack(alignment: .leading, spacing: 7) {
        SectionLabel(text: label)
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.bodyText(16))
                    .foregroundStyle(Palette.line)
                    .allowsHitTesting(false)
            }
            TextField("", text: text)
                .font(.bodyText(16))
                .multilineTextAlignment(.leading)
                .textInputAutocapitalization(.sentences)
                .textFieldStyle(.plain)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.count > TagNameRules.maxLength {
                        text.wrappedValue = String(newValue.prefix(TagNameRules.maxLength))
                    }
                }
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: width ?? .infinity, minHeight: 50, alignment: .leading)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
        .environment(\.layoutDirection, .leftToRight)
    }
}

private extension View {
    func tagListRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: Metrics.hMargin, bottom: 0, trailing: Metrics.hMargin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

/// The shared lightweight creation convention: one focused line directly
/// above the keyboard, matching the journal's quick-capture composer.
private struct InlineCreateBar: View {
    @Binding var text: String
    let placeholder: String
    var errorMessage: String? = nil
    let save: () -> Void
    let dismiss: () -> Void

    @FocusState private var isFocused: Bool

    private var canSave: Bool {
        TagNameRules.isValid(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.bodyText(17))
                        .foregroundStyle(Palette.meta)
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .font(.bodyText(17))
                    .multilineTextAlignment(.leading)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { if canSave { save() } }
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > TagNameRules.maxLength {
                            text = String(newValue.prefix(TagNameRules.maxLength))
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)

                Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")

                Button(action: save) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(canSave ? Palette.control : Palette.line))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityLabel("Save")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.bodyText(11.5, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .environment(\.layoutDirection, .leftToRight)
        .task {
            try? await Task.sleep(for: .milliseconds(160))
            isFocused = true
        }
    }
}

/// Packs variable-width tag pills from left to right and wraps them naturally.
private struct TagCloudLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + (x == 0 ? 0 : spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .init(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private func editorShell<Content: View>(
    title: String,
    height: CGFloat,
    canSave: Bool,
    save: @escaping () -> Void,
    cancel: @escaping () -> Void,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 18) {
        HStack {
            Chip(title: "Cancel", action: cancel)
            Spacer()
            Text(title).font(.utility(10.5)).tracking(1.4).foregroundStyle(Palette.meta)
            Spacer()
            Chip(title: "Save", isOn: canSave, action: save)
                .opacity(canSave ? 1 : 0.45)
        }
        content()
        Spacer()
    }
    .padding(.horizontal, Metrics.hMargin)
    .padding(.top, 20)
    .screenBackground()
    .environment(\.layoutDirection, .leftToRight)
    .environment(\.locale, Locale(identifier: "en_US"))
    .presentationDetents([.height(height)])
}
