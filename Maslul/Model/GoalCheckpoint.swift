import Foundation
import SwiftData

/// A user-ordered step in a goal's plan. A date is a target, not the source of
/// its position; moving a checkpoint never silently changes its deadline.
@Model
final class GoalCheckpoint {
    var title: String = ""
    var details: String?
    var createdAt: Date = Date()
    var dueAt: Date?
    var completedAt: Date?
    var sortIndex: Int = 0
    var goal: Goal?

    /// Removing a plan step must never remove journal entries written about it.
    @Relationship(deleteRule: .nullify, inverse: \Entry.checkpoint)
    var entries: [Entry] = []

    init(title: String, goal: Goal, sortIndex: Int, details: String? = nil, dueAt: Date? = nil) {
        self.title = title
        self.goal = goal
        self.sortIndex = sortIndex
        self.details = details
        self.dueAt = dueAt
        self.createdAt = .now
        self.completedAt = nil
        self.entries = []
    }
}
