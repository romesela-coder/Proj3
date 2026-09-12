import SwiftUI
import SwiftData

struct EntryBoxTile: View {
    let box: EntryBox?
    var size: CGFloat = 52

    private var symbol: String {
        box?.iconSymbol ?? "tray.full.fill"
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                    .stroke(Palette.lineSoft, lineWidth: 1)
            )
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityLabel(box?.name ?? "Inbox")
    }
}

struct EntryBoxChip: View {
    let box: EntryBox?

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: box?.iconSymbol ?? "tray.full.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(box?.name ?? "Inbox")
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.meta)
        }
        .font(.bodyText(12, weight: .semibold))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

struct EntryBoxPicker: View {
    @Binding var selectedBox: EntryBox?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \EntryBox.sortIndex, order: .forward)
    private var boxes: [EntryBox]

    @State private var editingBox: EntryBox?
    @State private var isCreating = false
    @State private var draftName = ""
    @State private var draftSymbol = "folder.fill"
    @State private var validationMessage: String?

    private let iconColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if isCreating || editingBox != nil {
                editor
            } else {
                boxList
            }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            if isCreating || editingBox != nil {
                Button("Back") { closeEditor() }
                    .font(.bodyText(14, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
            } else {
                Text("BOX")
                    .font(.utility(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Palette.meta)
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(.bodyText(14, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
    }

    private var boxList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(boxes) { box in
                    HStack(spacing: 12) {
                        Button {
                            selectedBox = box
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                EntryBoxTile(box: box, size: 46)
                                Text(box.name)
                                    .font(.bodyText(15, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                if selectedBox?.persistentModelID == box.persistentModelID {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button { beginEditing(box) } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ink2)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Palette.neutralTile))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(box.name)")
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                selectedBox?.persistentModelID == box.persistentModelID
                                    ? Palette.tagLemon
                                    : Color.white
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Palette.lineSoft, lineWidth: 1)
                    )
                }

                Button { beginCreating() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("New box")
                            .font(.bodyText(14, weight: .semibold))
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.neutralTile)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "NAME")
                    TextField("Box name", text: $draftName)
                        .font(.bodyText(16))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Palette.line, lineWidth: 1)
                        )
                        .disabled(editingBox?.systemKey == "inbox")
                        .opacity(editingBox?.systemKey == "inbox" ? 0.55 : 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "ICON")
                    LazyVGrid(columns: iconColumns, spacing: 10) {
                        ForEach(EntryIconChoice.allCases) { choice in
                            Button { draftSymbol = choice.symbol } label: {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(
                                        draftSymbol == choice.symbol
                                            ? Palette.tagLemon
                                            : Color.white
                                    )
                                    .frame(height: 48)
                                    .overlay(
                                        Image(systemName: choice.symbol)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(Palette.ink)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .stroke(Palette.lineSoft, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice.title)
                        }
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.bodyText(12.5))
                        .foregroundStyle(Palette.ink2)
                }

                Button(action: saveEditor) {
                    Text(isCreating ? "Create box" : "Save changes")
                        .font(.bodyText(14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSave ? Palette.control : Palette.line)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        guard EntryBoxNameRules.isValid(draftName) else { return false }
        let canonical = EntryBoxNameRules.canonical(draftName)
        return !boxes.contains { box in
            box.persistentModelID != editingBox?.persistentModelID
                && EntryBoxNameRules.canonical(box.name) == canonical
        }
    }

    private func beginCreating() {
        isCreating = true
        editingBox = nil
        draftName = ""
        draftSymbol = "folder.fill"
        validationMessage = nil
    }

    private func beginEditing(_ box: EntryBox) {
        isCreating = false
        editingBox = box
        draftName = box.name
        draftSymbol = box.iconSymbol
        validationMessage = nil
    }

    private func closeEditor() {
        isCreating = false
        editingBox = nil
        validationMessage = nil
    }

    private func saveEditor() {
        guard canSave else {
            validationMessage = "Choose a unique name with 1–50 characters."
            return
        }

        if let editingBox {
            if editingBox.systemKey != "inbox" {
                editingBox.name = EntryBoxNameRules.normalized(draftName)
            }
            editingBox.iconSymbol = draftSymbol
            try? context.save()
            closeEditor()
            return
        }

        let box = EntryBox(
            name: EntryBoxNameRules.normalized(draftName),
            iconSymbol: draftSymbol,
            sortIndex: (boxes.map(\.sortIndex).max() ?? -1) + 1
        )
        context.insert(box)
        selectedBox = box
        try? context.save()
        dismiss()
    }
}
