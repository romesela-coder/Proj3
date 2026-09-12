import Foundation
import SwiftData

enum EntryBoxNameRules {
    static let maxLength = 50

    static func normalized(_ value: String) -> String {
        String(value.prefix(maxLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canonical(_ value: String) -> String {
        normalized(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func isValid(_ value: String) -> Bool {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= maxLength
    }
}

/// A single home for an entry. Boxes power alternate views independently from
/// dates and tags; Inbox is the default home for every unfiled entry.
@Model
final class EntryBox {
    var name: String = ""
    var iconSymbol: String = "tray.full.fill"
    var systemKey: String?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Entry.box)
    var entries: [Entry] = []

    init(
        name: String,
        iconSymbol: String = "tray.full.fill",
        systemKey: String? = nil,
        createdAt: Date = .now
    ) {
        self.name = name
        self.iconSymbol = iconSymbol
        self.systemKey = systemKey
        self.createdAt = createdAt
        self.entries = []
    }
}

@MainActor
enum EntryBoxBootstrap {
    static func inbox(in context: ModelContext) -> EntryBox {
        let boxes = (try? context.fetch(FetchDescriptor<EntryBox>())) ?? []
        if let inbox = boxes.first(where: { $0.systemKey == "inbox" }) {
            return inbox
        }

        let inbox = EntryBox(
            name: "Inbox",
            iconSymbol: "tray.full.fill",
            systemKey: "inbox"
        )
        context.insert(inbox)
        try? context.save()
        return inbox
    }

    static func ensureDefaults(in context: ModelContext) {
        let inbox = inbox(in: context)
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        var changed = false

        for entry in entries where entry.box == nil {
            entry.box = inbox
            changed = true
        }

        if changed {
            try? context.save()
        }
    }
}
