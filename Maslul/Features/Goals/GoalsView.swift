import SwiftUI
import SwiftData

/// Declared versus recorded, side by side (§12).
///
/// No score, no percentage of success, no emoji. The mechanism is the
/// juxtaposition itself — and the gap between what you said mattered and what
/// actually got into the journal is the most valuable thing in the product.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Goal.createdAt, order: .forward) private var goals: [Goal]
    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }) private var entries: [Entry]

    @State private var quarter: Quarter = .current()
    @State private var showQuarterPicker = false
    @State private var showClose = false
    @State private var showNewGoal = false

    private var goalsInQuarter: [Goal] {
        goals.filter { $0.quarterKey == quarter.key }
    }

    private var entriesInQuarter: [Entry] {
        entries.filter { quarter.interval.contains($0.createdAt) }
    }

    private var knownQuarters: [Quarter] {
        let keys = Set(goals.map(\.quarterKey)).union([Quarter.current().key])
        return keys.compactMap(Quarter.from(key:)).sorted(by: >)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("מה הצהרת מול מה שבאמת תיעדת. בלי ציון.")
                        .font(.bodyText(14))
                        .foregroundStyle(Palette.muted)
                        .padding(.bottom, 6)

                    if goalsInQuarter.isEmpty {
                        emptyState
                    } else {
                        ForEach(goalsInQuarter) { goal in
                            goalRow(goal)
                        }
                        if let observation { observationCard(observation) }
                    }

                    actions
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("רבעון", isPresented: $showQuarterPicker, titleVisibility: .visible) {
            ForEach(knownQuarters) { candidate in
                Button(candidate.title) { quarter = candidate }
            }
            Button("ביטול", role: .cancel) {}
        }
        .sheet(isPresented: $showClose) {
            QuarterCloseView(quarter: quarter)
        }
        .sheet(isPresented: $showNewGoal) {
            GoalEditView(quarter: quarter)
        }
    }

    private var header: some View {
        HStack {
            CircleButton(symbol: "chevron.forward") { dismiss() }
            Spacer()
            Text(quarter.title)
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Chip(title: "היסטוריה") { showQuarterPicker = true }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Goal row

    private func goalRow(_ goal: Goal) -> some View {
        let linked = entriesInQuarter.filter {
            $0.goal?.persistentModelID == goal.persistentModelID
        }
        let share = entriesInQuarter.isEmpty
            ? 0
            : Double(linked.count) / Double(entriesInQuarter.count) * 100

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                if goal.isGeneratingEmoji {
                    AIActivityIndicator(messages: ["Matching", "Choosing emoji"], compact: true)
                } else {
                    Text(goal.emoji)
                    Text(goal.title)
                        .font(.bodyText(16, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "הצהרת")
                    Text(goal.metric ?? "בלי מדד — השוואה איכותנית")
                        .font(.bodyText(14))
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "בפועל")
                    Text(actualText(linked))
                        .font(.bodyText(14))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Capsule()
                            .fill(Palette.lineSoft)
                            .frame(width: geo.size.width, height: 10)
                            .position(x: geo.size.width / 2, y: 5)
                        Capsule()
                            .fill(Palette.meta)
                            .frame(width: geo.size.width * share / 100, height: 10)
                            .position(x: geo.size.width - geo.size.width * share / 100 / 2, y: 5)
                    }
                }
                .frame(height: 10)

                // Share of records, not of measured effort — the allocation is
                // the only thing entitled to speak about time (§07).
                Text("\(Int(share.rounded()))% מהרשומות")
                    .font(.bodyText(11.5))
                    .foregroundStyle(Palette.meta)
                    .frame(width: 86, alignment: .leading)
            }

            if let note = goal.closingNote, !note.isEmpty {
                Text(note)
                    .font(.bodyText(13))
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
    }

    private func actualText(_ linked: [Entry]) -> String {
        guard !linked.isEmpty else { return "אף רשומה" }
        let last = linked.map(\.createdAt).max() ?? .now
        return "\(linked.count) רשומות · אחרונה ב\(Fmt.monthYear(last))"
    }

    /// The finding that matters most is usually the effort that belonged to no
    /// declared goal at all.
    private var observation: String? {
        guard !entriesInQuarter.isEmpty, !goalsInQuarter.isEmpty else { return nil }
        let unlinked = entriesInQuarter.filter { $0.goal == nil }
        let share = Int((Double(unlinked.count) / Double(entriesInQuarter.count) * 100).rounded())
        guard share >= 50 else { return nil }

        let byProject = Dictionary(grouping: unlinked.compactMap(\.project)) { $0.persistentModelID }
            .values
            .sorted { $0.count > $1.count }
        guard let top = byProject.first?.first else {
            return "\(share)% מהרשומות ברבעון לא נקשרו לאף מטרה מוצהרת."
        }
        return "\(share)% מהרשומות ברבעון לא נקשרו לאף מטרה. רובן ב\"\(top.name)\"."
    }

    private func observationCard(_ text: String) -> some View {
        CardBox {
            Text(text)
                .font(.bodyText(14))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("לא הוגדרו מטרות ברבעון הזה.")
                .font(.bodyText(15.5))
                .foregroundStyle(Palette.ink)
            Text("מטרה היא הצהרה בתחילת רבעון, לא משימה. בלי הצהרה אין מול מה להשוות — אבל אפשר להסתכל על חלוקת המאמץ בפועל בדוח הקצאת הזמן.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 20)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if goalsInQuarter.filter(\.isOpen).count < Goal.activeLimit {
                PrimaryButton(title: "הוסף מטרה", isGhost: true) { showNewGoal = true }
            }
            if !goalsInQuarter.isEmpty {
                PrimaryButton(title: "סגור רבעון והגדר מטרות חדשות") { showClose = true }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Add a goal

struct GoalEditView: View {
    let quarter: Quarter

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var metric = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Chip(title: "ביטול") { dismiss() }
                Spacer()
                Text("מטרה חדשה")
                    .font(.utility(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Palette.meta)
                Spacer()
                Chip(title: "שמור", isOn: !trimmedTitle.isEmpty) { save() }
                    .opacity(trimmedTitle.isEmpty ? 0.45 : 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "המטרה")
                TextField("לקחת בעלות על תחום התשתית", text: $title)
                    .font(.bodyText(17))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "מדד אישי (אופציונלי)")
                TextField("3 מסמכי עיצוב שאני מוביל", text: $metric)
                    .font(.bodyText(17))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
                Text("המדד קיים רק כדי שהשוואה סופית תהיה אפשרית. מטרה בלי מדד מותרת לגמרי.")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.meta)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 20)
        .screenBackground()
        .presentationDetents([.medium])
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        let trimmedMetric = metric.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = Goal(
            title: trimmedTitle,
            metric: trimmedMetric.isEmpty ? nil : trimmedMetric,
            quarter: quarter
        )
        goal.isGeneratingEmoji = true
        context.insert(goal)
        try? context.save()
        let initialEmoji = goal.emoji
        Task { @MainActor in
            let generated = await LocalMetadataGenerator.emoji(for: goal.title, fallback: initialEmoji)
            guard goal.emoji == initialEmoji else {
                goal.isGeneratingEmoji = false
                return
            }
            goal.emoji = generated
            goal.isGeneratingEmoji = false
            try? context.save()
        }
        dismiss()
    }
}
