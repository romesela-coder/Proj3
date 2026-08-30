import SwiftUI
import Observation

enum RootTab: String, Hashable {
    case journal
    case me

    var title: String { self == .journal ? "יומן" : "אני" }
}

/// Where the journal list should open from.
enum JournalPreset: Hashable {
    /// Everything, no filter.
    case all
    /// Only entries still waiting to be classified.
    case pending
    /// Opens with the search field focused.
    case search
}

enum JournalRoute: Hashable {
    case journal(JournalPreset)
}

enum MeRoute: Hashable {
    case projects
    case timeReport
    case goals
    case export
    case privacy
    case reminder
    case entryPoints
    case roadmap
}

enum SheetRoute: Identifiable {
    case capture(EntryType?)
    case entry(Entry)
    /// The weekly ritual: tidy straight into the allocation.
    case ritual(atAllocation: Bool)

    var id: String {
        switch self {
        case .capture(let type): return "capture-\(type?.rawValue ?? "free")"
        case .entry(let entry): return "entry-\(entry.persistentModelID.hashValue)"
        case .ritual(let atAllocation): return "ritual-\(atAllocation)"
        }
    }
}

@Observable
final class Router {
    var tab: RootTab = .journal
    var sheet: SheetRoute?
    var journalPath: [JournalRoute] = []
    var mePath: [MeRoute] = []

    func newEntry(type: EntryType? = nil) {
        sheet = .capture(type)
    }

    func open(_ entry: Entry) {
        sheet = .entry(entry)
    }

    func startRitual(atAllocation: Bool = false) {
        sheet = .ritual(atAllocation: atAllocation)
    }

    func openJournal(_ preset: JournalPreset) {
        tab = .journal
        journalPath = [.journal(preset)]
    }
}
