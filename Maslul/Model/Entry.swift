import Foundation
import SwiftData

/// The single central entity (spec §06).
///
/// `body` is the only field required at write time. Everything else is optional
/// and deferred to the later confirmation step — structure comes after writing.
@Model
final class Entry {
    var body: String = ""
    /// Short, editable headline generated locally from the note.
    var titleText: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Soft deletion keeps accidental swipes recoverable for 48 hours.
    var trashedAt: Date?

    /// Ephemeral UI state while the local model replaces the fallback title.
    @Transient var isGeneratingTitle = false

    /// Optional user override for the leading SF Symbol shown in entry lists.
    /// Nil keeps the icon derived from the legacy entry type.
    var iconSymbol: String?

    /// Classification is optional. The user or the local model can set it while
    /// writing, and it remains editable later.
    var typeRaw: String?
    var effortRaw: String?

    /// Per-entry override of the project's origin. `nil` means "inherit".
    var originOverrideRaw: String?

    var sensitivityRaw: String = Sensitivity.normal.rawValue
    var mood: Int?

    /// File names inside the app's attachment directory. Never external links —
    /// the file is copied into the container (US-A4).
    var attachmentNames: [String] = []

    var project: Project?
    var box: EntryBox?

    @Relationship(deleteRule: .nullify, inverse: \EntryTag.entries)
    var tags: [EntryTag] = []

    /// Link to an active quarterly goal (§06, `goalRef`). Optional — most
    /// entries never belong to a declared goal, and that is itself the finding.
    var goal: Goal?

    init(
        body: String = "",
        createdAt: Date = .now,
        type: EntryType? = nil,
        project: Project? = nil
    ) {
        self.body = body
        self.titleText = Entry.makeTitle(from: body)
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.trashedAt = nil
        self.iconSymbol = nil
        self.typeRaw = type?.rawValue
        self.project = project
        self.box = nil
        self.tags = []
        self.sensitivityRaw = Sensitivity.normal.rawValue
        self.attachmentNames = []
    }
}

extension Entry {
    var type: EntryType? {
        get { typeRaw.flatMap(EntryType.init(rawValue:)) }
        set { typeRaw = newValue?.rawValue }
    }

    var effort: Effort? {
        get { effortRaw.flatMap(Effort.init(rawValue:)) }
        set { effortRaw = newValue?.rawValue }
    }

    var originOverride: TaskOrigin? {
        get { originOverrideRaw.flatMap(TaskOrigin.init(rawValue:)) }
        set { originOverrideRaw = newValue?.rawValue }
    }

    /// The origin actually in force: the entry's override, else the project's.
    var effectiveOrigin: TaskOrigin? {
        originOverride ?? project?.origin
    }

    var sensitivity: Sensitivity {
        get { Sensitivity(rawValue: sensitivityRaw) ?? .normal }
        set { sensitivityRaw = newValue.rawValue }
    }

    var isSensitive: Bool { sensitivity == .sensitive }

    var isTrashed: Bool { trashedAt != nil }

    var title: String {
        if !titleText.isEmpty { return titleText }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        return firstLine.isEmpty ? "Empty entry" : firstLine
    }

    static func makeTitle(from body: String) -> String {
        let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentence = clean.split(whereSeparator: { ".!?\n".contains($0) }).first.map(String.init) ?? clean
        let words = sentence.split(separator: " ").prefix(8)
        return words.joined(separator: " ")
    }

    func touch() { updatedAt = .now }

    func moveToTrash() {
        trashedAt = .now
        touch()
    }

    func restoreFromTrash() {
        trashedAt = nil
        touch()
    }

    static let trashLifetime: TimeInterval = 2 * 24 * 60 * 60
}
