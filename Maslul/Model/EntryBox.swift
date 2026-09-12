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
    /// Stable user-controlled shelf order. Existing stores receive the default
    /// value and are normalized once by EntryBoxBootstrap.
    var sortIndex: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Entry.box)
    var entries: [Entry] = []

    init(
        name: String,
        iconSymbol: String = "tray.full.fill",
        systemKey: String? = nil,
        createdAt: Date = .now,
        sortIndex: Int = 0
    ) {
        self.name = name
        self.iconSymbol = iconSymbol
        self.systemKey = systemKey
        self.createdAt = createdAt
        self.sortIndex = sortIndex
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

        let boxes = (try? context.fetch(FetchDescriptor<EntryBox>())) ?? []
        let orderedBoxes = boxes.sorted { lhs, rhs in
            if lhs.sortIndex == rhs.sortIndex {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortIndex < rhs.sortIndex
        }
        for (index, box) in orderedBoxes.enumerated() where box.sortIndex != index {
            box.sortIndex = index
            changed = true
        }

        for box in orderedBoxes {
            let orderedEntries = entries
                .filter { $0.box?.persistentModelID == box.persistentModelID }
                .sorted { lhs, rhs in
                    if lhs.boxSortIndex == rhs.boxSortIndex {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return lhs.boxSortIndex < rhs.boxSortIndex
                }
            for (index, entry) in orderedEntries.enumerated() where entry.boxSortIndex != index {
                entry.boxSortIndex = index
                changed = true
            }
        }

        let calendar = Calendar.current
        let entriesByDay = Dictionary(grouping: entries) {
            calendar.startOfDay(for: $0.createdAt)
        }
        for dayEntries in entriesByDay.values {
            let orderedEntries = dayEntries.sorted { lhs, rhs in
                if lhs.calendarSortIndex == rhs.calendarSortIndex {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.calendarSortIndex < rhs.calendarSortIndex
            }
            for (index, entry) in orderedEntries.enumerated()
            where entry.calendarSortIndex != index {
                entry.calendarSortIndex = index
                changed = true
            }
        }

        if changed {
            try? context.save()
        }
    }
}

enum EntryBoxEntryOrdering {
    static func move(_ entry: Entry, to box: EntryBox) {
        guard entry.box?.persistentModelID != box.persistentModelID else { return }
        let firstIndex = box.entries
            .filter { $0.persistentModelID != entry.persistentModelID }
            .map(\.boxSortIndex)
            .min() ?? 1
        entry.boxSortIndex = firstIndex - 1
        entry.box = box
    }
}
