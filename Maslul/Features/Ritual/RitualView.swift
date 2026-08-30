import SwiftUI
import SwiftData

/// The weekly ritual: tidy (F2) straight into the allocation (F3).
///
/// This is stage two of the three-stage core loop. Without it, entries pile up
/// unclassified and nothing downstream — the time report, goals versus
/// reality — has anything to read.
struct RitualView: View {
    /// Starting straight at the allocation, from "אני".
    var startAtAllocation = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Entry.createdAt, order: .forward) private var entries: [Entry]
    @Query private var projects: [Project]
    @Query private var goals: [Goal]

    @State private var stage: Stage = .tidy
    @State private var queue: [Entry] = []
    @State private var index = 0
    @State private var tidied: [Entry] = []
    @State private var didPrepare = false

    private enum Stage { case tidy, done, allocation }

    /// Forty entries after a holiday is not a queue, it's a wall. Ten at a
    /// time, with an offer to come back (F2, edge case).
    private static let batchSize = 10

    var body: some View {
        Group {
            switch stage {
            case .tidy:
                if let entry = current {
                    TidyCardView(
                        entry: entry,
                        position: index + 1,
                        total: queue.count,
                        projects: projects.filter(\.isSelectable),
                        goals: goals.filter(\.isCurrent),
                        onConfirm: confirm,
                        onSkip: skip,
                        onClose: { dismiss() }
                    )
                    .id(entry.persistentModelID)
                } else {
                    Color.clear.onAppear { stage = .done }
                }

            case .done:
                TidyDoneView(
                    insight: insight,
                    remainingPending: pending.count,
                    onMore: startNextBatch,
                    onContinue: { stage = .allocation },
                    onClose: { dismiss() },
                    onResolve: resolve
                )

            case .allocation:
                AllocationView(weekStart: Week.start(), onFinish: { dismiss() })
            }
        }
        .screenBackground()
        .task {
            guard !didPrepare else { return }
            didPrepare = true
            if startAtAllocation {
                stage = .allocation
            } else {
                startNextBatch()
            }
        }
    }

    // MARK: - Queue

    private var pending: [Entry] { entries.filter(\.needsTidy) }

    private var current: Entry? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    private var insight: WeeklyInsight {
        WeeklyInsight.make(
            tidied: tidied,
            allEntries: entries,
            projects: projects,
            goals: goals
        )
    }

    private func startNextBatch() {
        queue = Array(pending.prefix(Self.batchSize))
        index = 0
        tidied = []
        stage = queue.isEmpty ? .done : .tidy
    }

    private func confirm(_ entry: Entry, _ draft: Suggestion) {
        entry.type = draft.type
        entry.project = draft.project
        entry.effort = draft.effort
        entry.goal = draft.goal
        entry.touch()
        try? context.save()

        tidied.append(entry)
        advance()
    }

    /// Skipping leaves the entry in the queue. It is still searchable and still
    /// exported — being unclassified is not being lost (US-B1).
    private func skip() {
        advance()
    }

    private func advance() {
        withAnimation(Motion.spring) {
            if index + 1 < queue.count {
                index += 1
            } else {
                stage = .done
            }
        }
    }

    /// Acting on the one closing question.
    private func resolve(_ question: InsightQuestion, keep: Bool) {
        guard !keep else { return }
        switch question {
        case .staleProject(let project):
            project.status = .done
        case .untouchedGoal(let goal):
            goal.closedAt = .now
        case .lowFriction, .assignedHeavy:
            break
        }
        try? context.save()
    }
}
