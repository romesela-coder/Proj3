import SwiftUI
import SwiftData

enum TrackQuestionCategory: String, CaseIterable, Sendable {
    case progress
    case obstacles
    case decisions
    case learning
    case people
    case focus
    case courage
    case energy
    case perspective
    case nextStep

    var title: String {
        switch self {
        case .progress: return "Progress"
        case .obstacles: return "Obstacles"
        case .decisions: return "Decisions"
        case .learning: return "Learning"
        case .people: return "People"
        case .focus: return "Focus"
        case .courage: return "Courage"
        case .energy: return "Energy"
        case .perspective: return "Perspective"
        case .nextStep: return "Next"
        }
    }

    var symbol: String {
        switch self {
        case .progress: return "arrow.up.right"
        case .obstacles: return "exclamationmark.triangle"
        case .decisions: return "arrow.triangle.branch"
        case .learning: return "book"
        case .people: return "person.2"
        case .focus: return "scope"
        case .courage: return "bolt"
        case .energy: return "battery.75percent"
        case .perspective: return "binoculars"
        case .nextStep: return "arrow.right"
        }
    }
}

struct TrackQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let category: TrackQuestionCategory
    let text: String
}

/// A private, offline starting bank. Selection is deliberately deterministic
/// for the first build. A future local ranker can replace `featured` while the
/// question, Track selection, and Entry persistence contracts stay unchanged.
enum TrackQuestionBank {
    static let noMovement = TrackQuestion(
        id: "check-in-no-progress",
        category: .obstacles,
        text: "Nothing moved. What got in the way, or what took priority?"
    )

    static func find(_ id: String) -> TrackQuestion? {
        if id == noMovement.id { return noMovement }
        return all.first { $0.id == id }
    }

    static let all: [TrackQuestion] = [
        question("progress-01", .progress, "What moved forward, even a little?"),
        question("progress-02", .progress, "What is easier now than it was a month ago?"),
        question("progress-03", .progress, "What evidence shows that something is changing?"),
        question("progress-04", .progress, "What did you finish that deserves to be remembered?"),
        question("progress-05", .progress, "Where did you take more ownership than before?"),
        question("progress-06", .progress, "What became clearer through action?"),
        question("progress-07", .progress, "Which small win could compound over time?"),
        question("progress-08", .progress, "What did you handle differently this time?"),
        question("progress-09", .progress, "What are you proud of that nobody else may notice?"),
        question("progress-10", .progress, "What changed because you showed up?"),

        question("obstacles-01", .obstacles, "What feels stuck right now?"),
        question("obstacles-02", .obstacles, "What keeps becoming harder than it should be?"),
        question("obstacles-03", .obstacles, "Which assumption may be blocking progress?"),
        question("obstacles-04", .obstacles, "What are you avoiding because it feels uncomfortable?"),
        question("obstacles-05", .obstacles, "Where are you waiting for clarity that may not arrive?"),
        question("obstacles-06", .obstacles, "What constraint do you need to accept or challenge?"),
        question("obstacles-07", .obstacles, "What repeatedly drains momentum?"),
        question("obstacles-08", .obstacles, "What conversation would make this less stuck?"),
        question("obstacles-09", .obstacles, "What is outside your control, and what is still yours?"),
        question("obstacles-10", .obstacles, "What are you treating as one problem that may be several?"),

        question("decisions-01", .decisions, "What decision are you postponing?"),
        question("decisions-02", .decisions, "What did you decide, and what changed afterward?"),
        question("decisions-03", .decisions, "Which tradeoff are you actually making?"),
        question("decisions-04", .decisions, "What would you choose if both options were reversible?"),
        question("decisions-05", .decisions, "What information is truly needed before deciding?"),
        question("decisions-06", .decisions, "Which decision no longer fits what you know now?"),
        question("decisions-07", .decisions, "What are you saying yes to by saying no here?"),
        question("decisions-08", .decisions, "Where would a clear boundary improve the situation?"),
        question("decisions-09", .decisions, "What decision are you implicitly making through inaction?"),
        question("decisions-10", .decisions, "What is the smallest reversible decision you can make?"),

        question("learning-01", .learning, "What did reality teach you that planning did not?"),
        question("learning-02", .learning, "What did you misunderstand at first?"),
        question("learning-03", .learning, "What feedback changed how you see the situation?"),
        question("learning-04", .learning, "What worked, and why do you think it worked?"),
        question("learning-05", .learning, "What failed in a useful way?"),
        question("learning-06", .learning, "What pattern are you starting to notice?"),
        question("learning-07", .learning, "What question do you know how to ask now?"),
        question("learning-08", .learning, "What would you teach someone else from this experience?"),
        question("learning-09", .learning, "What belief became more nuanced?"),
        question("learning-10", .learning, "What should you test before drawing a conclusion?"),

        question("people-01", .people, "Who helped move this forward, and how?"),
        question("people-02", .people, "Whose perspective is missing?"),
        question("people-03", .people, "Who needs more context from you?"),
        question("people-04", .people, "Where did trust increase or decrease?"),
        question("people-05", .people, "What did you learn about how someone else works?"),
        question("people-06", .people, "Which relationship deserves deliberate attention?"),
        question("people-07", .people, "Where could you ask for help sooner?"),
        question("people-08", .people, "What contribution from someone else should you acknowledge?"),
        question("people-09", .people, "Which expectation has not been said out loud?"),
        question("people-10", .people, "What would make the next conversation more honest?"),

        question("focus-01", .focus, "What matters most here right now?"),
        question("focus-02", .focus, "What is getting attention without earning it?"),
        question("focus-03", .focus, "If only one thing moved this week, what should it be?"),
        question("focus-04", .focus, "What can you deliberately leave unfinished?"),
        question("focus-05", .focus, "Where are you confusing urgency with importance?"),
        question("focus-06", .focus, "What would make the rest of the work easier?"),
        question("focus-07", .focus, "What outcome are you optimizing for?"),
        question("focus-08", .focus, "What deserves a protected block of attention?"),
        question("focus-09", .focus, "Which commitment no longer deserves its place?"),
        question("focus-10", .focus, "What is the essential version of this?"),

        question("courage-01", .courage, "What would you do if you trusted your judgment?"),
        question("courage-02", .courage, "What truth are you softening too much?"),
        question("courage-03", .courage, "Where do you need to be more visible?"),
        question("courage-04", .courage, "What are you ready to ask for?"),
        question("courage-05", .courage, "Which risk is worth taking deliberately?"),
        question("courage-06", .courage, "What boundary are you responsible for setting?"),
        question("courage-07", .courage, "What would a braver version of the next step look like?"),
        question("courage-08", .courage, "Where are you playing smaller than the situation requires?"),
        question("courage-09", .courage, "What useful discomfort are you willing to choose?"),
        question("courage-10", .courage, "What would you regret not attempting?"),

        question("energy-01", .energy, "What gave you energy recently?"),
        question("energy-02", .energy, "What drained more energy than expected?"),
        question("energy-03", .energy, "When did the work feel most natural?"),
        question("energy-04", .energy, "What pace would make this sustainable?"),
        question("energy-05", .energy, "What are you carrying that belongs to someone else?"),
        question("energy-06", .energy, "What kind of work do you want more of?"),
        question("energy-07", .energy, "What recovery does this effort require?"),
        question("energy-08", .energy, "Which part of this consistently creates resistance?"),
        question("energy-09", .energy, "What would reduce unnecessary cognitive load?"),
        question("energy-10", .energy, "What is your current capacity, honestly?"),

        question("perspective-01", .perspective, "What might you see differently six months from now?"),
        question("perspective-02", .perspective, "What story are you telling yourself about this?"),
        question("perspective-03", .perspective, "What would this look like from the other side?"),
        question("perspective-04", .perspective, "What has changed since you first chose this direction?"),
        question("perspective-05", .perspective, "What are you measuring that may not matter?"),
        question("perspective-06", .perspective, "What would count as enough?"),
        question("perspective-07", .perspective, "Which part of this is a season rather than a permanent truth?"),
        question("perspective-08", .perspective, "What would you advise a friend in the same position?"),
        question("perspective-09", .perspective, "What possibility have you not considered?"),
        question("perspective-10", .perspective, "What deserves to be interpreted more generously?"),

        question("next-01", .nextStep, "What is the next meaningful move?"),
        question("next-02", .nextStep, "What can you do in the next twenty minutes?"),
        question("next-03", .nextStep, "What conversation should happen next?"),
        question("next-04", .nextStep, "What would create useful momentum?"),
        question("next-05", .nextStep, "What needs to be true before the next step?"),
        question("next-06", .nextStep, "What experiment would reduce uncertainty?"),
        question("next-07", .nextStep, "What will you try differently next time?"),
        question("next-08", .nextStep, "What can you make easier for your future self?"),
        question("next-09", .nextStep, "What is the smallest action that would make this real?"),
        question("next-10", .nextStep, "What do you want to remember when you return to this?"),
    ]

    static func featured(
        on date: Date = .now,
        activeTrackCount: Int,
        entryCount: Int,
        limit: Int = 6
    ) -> [TrackQuestion] {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        let categories = TrackQuestionCategory.allCases
        let categoryStart = (day + activeTrackCount) % categories.count
        let wanted = min(max(limit, 0), categories.count)

        return (0..<wanted).compactMap { offset in
            let category = categories[(categoryStart + offset) % categories.count]
            let pool = all.filter { $0.category == category }
            guard !pool.isEmpty else { return nil }
            let questionIndex = (day + entryCount + activeTrackCount * 3 + offset * 5) % pool.count
            return pool[questionIndex]
        }
    }

    private static func question(
        _ id: String,
        _ category: TrackQuestionCategory,
        _ text: String
    ) -> TrackQuestion {
        TrackQuestion(id: id, category: category, text: text)
    }
}

struct GoalCreationSheet: View {
    let existingTracks: [Goal]
    let onCreated: (Goal) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var motivation = ""
    @State private var desiredChange = ""
    @State private var currentChallenge = ""
    @State private var saveError: String?
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you want to move forward?")
                            .font(.display(25))
                            .displayTracking(25)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Give it a name you will recognize later. The rest is optional.")
                            .font(.bodyText(14))
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    TextField("e.g. Lead technical decisions with confidence", text: $title)
                        .font(.bodyText(16))
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                        .onSubmit(create)
                        .padding(.horizontal, 15)
                        .frame(minHeight: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Palette.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Palette.line, lineWidth: 1)
                        )

                    SectionLabel(text: "Optional context")

                    TextField("Why does this matter to you?", text: $motivation, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))

                    TextField("What would you like to change?", text: $desiredChange, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))

                    TextField("What feels difficult right now?", text: $currentChallenge, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))

                    Button(action: create) {
                        Text("Create goal")
                            .font(.bodyText(15, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(canCreate ? Palette.control : Palette.line)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.top, 20)
            }
            .screenBackground()
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Could not create goal", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { isTitleFocused = true }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty
            && trimmedTitle.count <= 100
            && !existingTracks.contains {
                $0.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    == trimmedTitle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
    }

    private func create() {
        guard canCreate else { return }
        let track = Goal.track(title: trimmedTitle)
        track.motivation = motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        track.desiredChange = desiredChange.trimmingCharacters(in: .whitespacesAndNewlines)
        track.currentChallenge = currentChallenge.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(track)
        do {
            try context.save()
            dismiss()
            onCreated(track)
        } catch {
            context.delete(track)
            saveError = "Your goal was not saved. Please try again."
        }
    }
}
