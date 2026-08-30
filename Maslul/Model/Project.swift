import Foundation
import SwiftData

/// A project is whatever the user calls a project — a team, a workstream, an
/// initiative, or "day-to-day ops" (spec §07). Created and managed by hand.
@Model
final class Project {
    var name: String = ""
    var statusRaw: String = ProjectStatus.active.rawValue

    /// Default origin inherited by entries filed under this project.
    var originRaw: String = TaskOrigin.assigned.rawValue

    /// A single letter for quick identification in rows and reports.
    var mark: String = ""

    var startedAt: Date?
    var endedAt: Date?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Entry.project)
    var entries: [Entry] = []

    init(
        name: String,
        origin: TaskOrigin = .assigned,
        status: ProjectStatus = .active,
        startedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.name = name
        self.originRaw = origin.rawValue
        self.statusRaw = status.rawValue
        self.startedAt = startedAt
        self.createdAt = createdAt
        self.mark = Project.defaultMark(for: name)
        self.entries = []
    }

    /// A deliberate ceiling. Past eight, the weekly allocation becomes a table
    /// nobody fills in and the number stops being worth anything (spec §07).
    static let activeLimit = 8

    static func defaultMark(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "•" : String(trimmed.prefix(1))
    }
}

extension Project {
    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set {
            statusRaw = newValue.rawValue
            if newValue == .done, endedAt == nil { endedAt = .now }
            if newValue != .done { endedAt = nil }
        }
    }

    var origin: TaskOrigin {
        get { TaskOrigin(rawValue: originRaw) ?? .assigned }
        set { originRaw = newValue.rawValue }
    }

    var isSelectable: Bool { status == .active }
}
