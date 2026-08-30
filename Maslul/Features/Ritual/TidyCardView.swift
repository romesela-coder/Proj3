import SwiftUI

/// One entry, one card. Swipe right to confirm, left to skip — or use the
/// buttons, because a ritual you can only do by gesture is a ritual you skip
/// when your other hand is full.
struct TidyCardView: View {
    let entry: Entry
    let position: Int
    let total: Int
    let projects: [Project]
    let goals: [Goal]
    let onConfirm: (Entry, Suggestion) -> Void
    let onSkip: () -> Void
    let onClose: () -> Void

    @State private var draft = Suggestion()
    @State private var offset: CGFloat = 0
    @State private var showTypePicker = false
    @State private var showProjectPicker = false

    private let suggester = HeuristicSuggester()
    private static let swipeThreshold: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            progress
            card
            hints
            buttons
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .task { draft = suggester.suggest(for: entry, projects: projects, goals: goals) }
        .confirmationDialog("סוג", isPresented: $showTypePicker, titleVisibility: .visible) {
            ForEach(EntryType.allCases) { type in
                Button(type.title) { draft.type = type }
            }
            Button("ללא סוג", role: .destructive) { draft.type = nil }
            Button("ביטול", role: .cancel) {}
        }
        .confirmationDialog("פרויקט", isPresented: $showProjectPicker, titleVisibility: .visible) {
            ForEach(projects) { project in
                Button(project.name) { draft.project = project }
            }
            Button("ללא פרויקט", role: .destructive) { draft.project = nil }
            Button("ביטול", role: .cancel) {}
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            CircleButton(symbol: "xmark", action: onClose)
            Spacer()
            Text("סידור שבועי")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Text("\(position) / \(total)")
                .font(.utility(11.5))
                .foregroundStyle(Palette.meta)
                .frame(width: Metrics.tapTarget, alignment: .trailing)
        }
    }

    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { step in
                Capsule()
                    .fill(step < position ? Palette.ink : Palette.lineSoft)
                    .frame(height: 9)
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Fmt.longDate(entry.createdAt))
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)

            Text(entry.body)
                .font(.bodyText(17))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    SectionLabel(text: "הצעות")
                        .fixedSize()
                    Text(suggester.sourceLabel)
                        .font(.bodyText(11))
                        .foregroundStyle(Palette.meta)
                    Spacer()
                }

                suggestionRow(label: "סוג") {
                    Chip(title: draft.type?.title ?? "ללא", isOn: draft.type != nil) {
                        showTypePicker = true
                    }
                    Chip(title: "שנה") { showTypePicker = true }
                }

                suggestionRow(label: "פרויקט") {
                    Chip(title: draft.project?.name ?? "ללא", isOn: draft.project != nil) {
                        showProjectPicker = true
                    }
                    Chip(title: "שנה") { showProjectPicker = true }
                }

                suggestionRow(label: "מאמץ") {
                    ForEach(Effort.allCases) { effort in
                        Chip(title: effort.title, isOn: draft.effort == effort) {
                            draft.effort = (draft.effort == effort) ? nil : effort
                        }
                    }
                }
            }

            if let goal = draft.goal ?? goals.first {
                Divider().overlay(Palette.cardLine)
                HStack(spacing: 10) {
                    Circle()
                        .fill(draft.goal == nil ? Palette.line : Palette.ink)
                        .frame(width: 9, height: 9)
                    Text(draft.goal == nil
                         ? "לקשר למטרה \"\(goal.title)\"?"
                         : "מקושר ל\"\(goal.title)\"")
                        .font(.bodyText(14.5))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    Chip(title: draft.goal == nil ? "קשר" : "נתק", isOn: draft.goal != nil) {
                        withAnimation(Motion.spring) {
                            draft.goal = draft.goal == nil ? goal : nil
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .stroke(Palette.cardLine, lineWidth: 1)
        )
        .offset(x: offset)
        .rotationEffect(.degrees(Double(offset) / 40))
        .gesture(
            DragGesture()
                .onChanged { value in offset = value.translation.width }
                .onEnded { value in
                    // In RTL the gesture still reads left-to-right physically:
                    // push away to skip, pull in to confirm.
                    if value.translation.width > Self.swipeThreshold {
                        commit(confirm: true)
                    } else if value.translation.width < -Self.swipeThreshold {
                        commit(confirm: false)
                    } else {
                        withAnimation(Motion.spring) { offset = 0 }
                    }
                }
        )
    }

    private func suggestionRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
                .frame(width: 52, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private var hints: some View {
        HStack {
            Label("דילוג", systemImage: "arrow.left")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
            Spacer()
            Label("אישור", systemImage: "arrow.right")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            PrimaryButton(title: "דלג", isGhost: true) { commit(confirm: false) }
                .frame(maxWidth: .infinity)
            PrimaryButton(title: "אשר והמשך") { commit(confirm: true) }
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 14)
    }

    private func commit(confirm: Bool) {
        withAnimation(Motion.spring) { offset = confirm ? 500 : -500 }
        if confirm {
            onConfirm(entry, draft)
        } else {
            onSkip()
        }
    }
}
