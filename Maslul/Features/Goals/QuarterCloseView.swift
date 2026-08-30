import SwiftUI
import SwiftData

/// Closing one quarter and opening the next (F6).
///
/// A quarter with no goals is not scolded — the screen simply shows what was
/// recorded and moves on.
struct QuarterCloseView: View {
    let quarter: Quarter

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Goal.createdAt, order: .forward) private var goals: [Goal]

    @State private var notes: [PersistentIdentifier: String] = [:]
    @State private var carried: Set<PersistentIdentifier> = []
    @State private var newTitles: [String] = []
    @State private var draft = ""

    private var closing: [Goal] {
        goals.filter { $0.quarterKey == quarter.key && $0.isOpen }
    }

    private var next: Quarter { quarter.next }

    private var plannedCount: Int { carried.count + newTitles.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if closing.isEmpty {
                        Text("אין מטרות פתוחות ברבעון הזה. אפשר פשוט להגדיר את מטרות \(next.shortTitle).")
                            .font(.bodyText(14))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "סיכום \(quarter.shortTitle)")
                            Text("שורה אחת לכל מטרה — למה זה קרה או למה לא. אופציונלי.")
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                        }

                        ForEach(closing) { goal in
                            closingRow(goal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "מטרות \(next.shortTitle)")
                        Text("שתיים עד ארבע. מדד אפשר להוסיף אחר כך.")
                            .font(.bodyText(12.5))
                            .foregroundStyle(Palette.meta)
                    }

                    ForEach(Array(newTitles.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 10) {
                            Text(title)
                                .font(.bodyText(15))
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                withAnimation(Motion.spring) { newTitles.remove(at: index) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundStyle(Palette.meta)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Palette.lineSoft).frame(height: 1)
                        }
                    }

                    if plannedCount < Goal.activeLimit {
                        HStack(spacing: 8) {
                            TextField("מטרה חדשה", text: $draft)
                                .font(.bodyText(16))
                                .submitLabel(.done)
                                .onSubmit(addDraft)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 50)
                                .background(Capsule().fill(Color.white))
                                .overlay(Capsule().stroke(Palette.line, lineWidth: 1))

                            Button(action: addDraft) {
                                Circle()
                                    .fill(Palette.control)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 19, weight: .medium))
                                            .foregroundStyle(Color.white)
                                    )
                            }
                            .buttonStyle(.plain)
                            .opacity(canAdd ? 1 : 0.35)
                            .disabled(!canAdd)
                        }
                    } else {
                        Text("ארבע מטרות זה המקסימום. חמישית היא כבר רשימת משימות.")
                            .font(.bodyText(12.5))
                            .foregroundStyle(Palette.meta)
                    }

                    PrimaryButton(title: "סגור רבעון") { commit() }
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, Metrics.hMargin)
            }
        }
        .screenBackground()
    }

    private var header: some View {
        HStack {
            Chip(title: "ביטול") { dismiss() }
            Spacer()
            Text("סגירת רבעון")
                .font(.utility(10.5))
                .tracking(1.4)
                .foregroundStyle(Palette.meta)
            Spacer()
            Color.clear.frame(width: 60, height: Metrics.tapTarget)
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private func closingRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(goal.title)
                .font(.bodyText(15.5, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            TextField("מה קרה, או למה לא", text: Binding(
                get: { notes[goal.persistentModelID] ?? "" },
                set: { notes[goal.persistentModelID] = $0 }
            ))
            .font(.bodyText(14.5))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )

            Chip(
                title: carried.contains(goal.persistentModelID)
                    ? "עוברת ל\(next.shortTitle)"
                    : "העבר ל\(next.shortTitle)",
                isOn: carried.contains(goal.persistentModelID)
            ) {
                withAnimation(Motion.spring) {
                    if carried.contains(goal.persistentModelID) {
                        carried.remove(goal.persistentModelID)
                    } else if plannedCount < Goal.activeLimit {
                        carried.insert(goal.persistentModelID)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
    }

    private var canAdd: Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && plannedCount < Goal.activeLimit && !newTitles.contains(trimmed)
    }

    private func addDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAdd else { return }
        withAnimation(Motion.spring) {
            newTitles.append(trimmed)
            draft = ""
        }
    }

    private func commit() {
        for goal in closing {
            goal.closedAt = .now
            let note = (notes[goal.persistentModelID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            goal.closingNote = note.isEmpty ? nil : note

            if carried.contains(goal.persistentModelID) {
                context.insert(Goal(title: goal.title, metric: goal.metric, quarter: next))
            }
        }

        for title in newTitles {
            context.insert(Goal(title: title, quarter: next))
        }

        try? context.save()
        dismiss()
    }
}
