import Foundation
import SwiftData

/// The single central entity (spec §06).
///
/// `body` is the only field required at write time. Everything else is optional
/// and deferred to the later confirmation step — structure comes after writing.
@Model
final class Entry {
    var body: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// `nil` means the entry has not been classified yet and is still waiting in
    /// the tidy queue. It is still searchable and still exported.
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

    init(
        body: String = "",
        createdAt: Date = .now,
        type: EntryType? = nil,
        project: Project? = nil
    ) {
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.typeRaw = type?.rawValue
        self.project = project
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

    /// Waiting for the weekly tidy pass.
    var needsTidy: Bool { typeRaw == nil }

    var title: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        return firstLine.isEmpty ? "רשומה ריקה" : firstLine
    }

    func touch() { updatedAt = .now }
}
