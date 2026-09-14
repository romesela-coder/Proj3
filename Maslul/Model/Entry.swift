import Foundation
import SwiftData

/// The single central entity (spec §06).
///
/// `body` is the only field required at write time. Everything else is optional
/// and deferred to the later confirmation step — structure comes after writing.
@Model
final class Entry {
    var body: String = ""
    /// Versioned rich-text metadata. The plain body remains canonical and this
    /// optional additive field makes old stores migrate without rewriting text.
    var richTextData: Data?
    /// Short, editable headline generated locally from the note.
    var titleText: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Soft deletion keeps accidental swipes recoverable for 48 hours.
    var trashedAt: Date?

    /// Optional, one-shot time at which this entry should resurface.
    /// Keeping this on Entry preserves capture as the single entry point.
    var reminderAt: Date?
    /// Stable across edits so rescheduling replaces the same notification.
    var reminderIdentifier: UUID?
    /// Nil migrates existing reminders to the quiet, backwards-compatible mode.
    var reminderDeliveryRaw: String?
    /// The most recent reminder that already fired. Kept locally so the entry
    /// can be found and scheduled again from the Reminders archive.
    var archivedReminderAt: Date?

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
    /// Stable user-controlled position inside the assigned Box. Existing
    /// stores are normalized by EntryBoxBootstrap in newest-first order.
    var boxSortIndex: Int = 0
    /// Independent manual position inside a Calendar day.
    var calendarSortIndex: Int = 0

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
        self.richTextData = nil
        self.titleText = Entry.makeTitle(from: body)
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.trashedAt = nil
        self.reminderAt = nil
        self.reminderIdentifier = nil
        self.reminderDeliveryRaw = nil
        self.archivedReminderAt = nil
        self.iconSymbol = nil
        self.typeRaw = type?.rawValue
        self.project = project
        self.box = nil
        self.boxSortIndex = 0
        self.calendarSortIndex = 0
        self.tags = []
        self.sensitivityRaw = Sensitivity.normal.rawValue
        self.attachmentNames = []
    }
}

enum CalendarEntryOrdering {
    static func placeAtFront(_ entry: Entry, in context: ModelContext) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: entry.createdAt)
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let firstIndex = entries
            .filter {
                $0.persistentModelID != entry.persistentModelID
                    && calendar.isDate($0.createdAt, inSameDayAs: day)
            }
            .map(\.calendarSortIndex)
            .min() ?? 1
        entry.calendarSortIndex = firstIndex - 1
    }
}

extension Entry {
    var attributedBody: AttributedString {
        get { EntryRichTextCodec.decodeAttributed(richTextData, fallback: body) }
        set {
            body = String(newValue.characters)
            richTextData = EntryRichTextCodec.encodeAttributed(newValue)
        }
    }

    var richTextDocument: EntryRichTextDocument {
        get { EntryRichTextCodec.decode(richTextData) }
        set { richTextData = EntryRichTextCodec.encode(newValue) }
    }

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

    var hasReminder: Bool { reminderAt != nil }

    var isReminderDue: Bool {
        guard let reminderAt else { return false }
        return reminderAt <= .now
    }

    var reminderDelivery: EntryReminderDelivery {
        get { reminderDeliveryRaw.flatMap(EntryReminderDelivery.init(rawValue:)) ?? .notification }
        set { reminderDeliveryRaw = newValue.rawValue }
    }

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

enum EntryReminderDelivery: String, CaseIterable, Identifiable {
    case notification
    case alarm

    var id: Self { self }

    var title: String {
        switch self {
        case .notification: "Notification"
        case .alarm: "Alarm"
        }
    }

    var detail: String {
        switch self {
        case .notification: "A standard alert and sound"
        case .alarm: "Sounds until you stop it"
        }
    }

    var symbol: String {
        switch self {
        case .notification: "bell"
        case .alarm: "alarm"
        }
    }
}
