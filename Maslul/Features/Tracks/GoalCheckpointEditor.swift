import SwiftUI
import SwiftData

struct GoalCheckpointEditor: View {
    let goal: Goal
    let checkpoint: GoalCheckpoint?
    let nextSortIndex: Int
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var details: String
    @State private var hasDueDate: Bool
    @State private var dueAt: Date
    @State private var isConfirmingDelete = false

    init(goal: Goal, checkpoint: GoalCheckpoint? = nil, nextSortIndex: Int = 0, onDelete: (() -> Void)? = nil) {
        self.goal = goal
        self.checkpoint = checkpoint
        self.nextSortIndex = nextSortIndex
        self.onDelete = onDelete
        _title = State(initialValue: checkpoint?.title ?? "")
        _details = State(initialValue: checkpoint?.details ?? "")
        _hasDueDate = State(initialValue: checkpoint?.dueAt != nil)
        _dueAt = State(initialValue: checkpoint?.dueAt ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs to happen?", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                    TextField("A little more context (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                } footer: {
                    Text("A checkpoint can be a small task or a larger milestone. It does not need any entries.")
                }

                Section {
                    Toggle("Target date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueAt, displayedComponents: .date)
                    }
                } footer: {
                    Text("Moving a checkpoint later will not change its target date.")
                }

                if checkpoint != nil {
                    Section {
                        Button("Delete checkpoint", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    } footer: {
                        Text("Entries linked to this checkpoint will remain in the goal and journal.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(checkpoint == nil ? "New checkpoint" : "Edit checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this checkpoint?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete checkpoint", role: .destructive, action: delete)
            } message: {
                Text("Its entries will not be deleted.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        if let checkpoint {
            checkpoint.title = cleanTitle
            checkpoint.details = cleanDetails.isEmpty ? nil : cleanDetails
            checkpoint.dueAt = hasDueDate ? dueAt : nil
        } else {
            let newCheckpoint = GoalCheckpoint(
                title: cleanTitle,
                goal: goal,
                sortIndex: nextSortIndex,
                details: cleanDetails.isEmpty ? nil : cleanDetails,
                dueAt: hasDueDate ? dueAt : nil
            )
            context.insert(newCheckpoint)
        }
        try? context.save()
        dismiss()
    }

    private func delete() {
        guard let checkpoint else { return }
        context.delete(checkpoint)
        try? context.save()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDelete?()
        }
    }
}
