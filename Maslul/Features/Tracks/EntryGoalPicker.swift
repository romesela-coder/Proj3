import SwiftUI
import SwiftData

/// Goal selection in the entry drawer follows the same bottom-sheet pattern
/// as Box selection. Creating a goal keeps the unfinished entry in place.
struct EntryGoalPicker: View {
    @Binding var selectedGoal: Goal?
    let availableGoals: [Goal]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var isCreating = false
    @State private var title = ""
    @State private var motivation = ""
    @State private var desiredChange = ""
    @State private var currentChallenge = ""
    @State private var saveError: String?
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if isCreating {
                creationForm
            } else {
                goalList
            }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .screenBackground()
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .alert("Could not create goal", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private var header: some View {
        HStack {
            if isCreating {
                Button("Back") {
                    isTitleFocused = false
                    withAnimation(Motion.spring) { isCreating = false }
                }
                .font(.bodyText(14, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            } else {
                Text("GOAL")
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

    private var goalList: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button {
                    selectedGoal = nil
                    dismiss()
                } label: {
                    goalRow(symbol: "minus.circle", title: "No goal", isSelected: selectedGoal == nil)
                }
                .buttonStyle(.plain)

                ForEach(availableGoals) { goal in
                    Button {
                        selectedGoal = goal
                        dismiss()
                    } label: {
                        goalRow(
                            symbol: "target",
                            title: "\(goal.emoji) \(goal.title)",
                            isSelected: selectedGoal?.persistentModelID == goal.persistentModelID
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    selectedDetent = .large
                    withAnimation(Motion.spring) { isCreating = true }
                    isTitleFocused = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("New goal")
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
            .padding(.bottom, 24)
        }
    }

    private func goalRow(symbol: String, title: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 13).fill(Palette.card))

            Text(title)
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Palette.tagLemon : Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.lineSoft, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var creationForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "NAME")
                    TextField("Goal name", text: $title)
                        .font(.bodyText(16))
                        .textFieldStyle(.plain)
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                        .onSubmit(createGoal)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
                }

                SectionLabel(text: "OPTIONAL CONTEXT")
                contextField("Why does this matter to you?", text: $motivation)
                contextField("What would you like to change?", text: $desiredChange)
                contextField("What feels difficult right now?", text: $currentChallenge)

                Button(action: createGoal) {
                    Text("Create goal")
                        .font(.bodyText(14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canCreate ? Palette.control : Palette.line)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func contextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.bodyText(14))
            .lineLimit(2...4)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty
            && trimmedTitle.count <= 100
            && !availableGoals.contains {
                $0.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    == trimmedTitle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
    }

    private func createGoal() {
        guard canCreate else { return }
        let goal = Goal.track(title: trimmedTitle)
        goal.motivation = motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.desiredChange = desiredChange.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.currentChallenge = currentChallenge.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(goal)
        do {
            try context.save()
            selectedGoal = goal
            dismiss()
        } catch {
            context.delete(goal)
            saveError = "Your goal was not saved. Please try again."
        }
    }
}
