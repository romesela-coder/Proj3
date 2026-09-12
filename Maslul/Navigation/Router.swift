import SwiftUI
import Observation

enum RootTab: String, Hashable {
    case journal
    case me

    var title: String { self == .journal ? "Journal" : "Me" }
}

/// Where the journal list should open from.
enum JournalPreset: Hashable {
    /// Everything, no filter.
    case all
    /// Opens with the search field focused.
    case search
}

enum JournalRoute: Hashable {
    case journal(JournalPreset)
    case box(EntryBox)
}

enum MeRoute: Hashable {
    case tags
    case projects
    case timeReport
    case goals
    case export
    case privacy
    case reminder
    case entryPoints
    case trash
}

enum SheetRoute: Identifiable {
    case capture(EntryType?, Date?)
    case entry(Entry)
    case allocation

    var id: String {
        switch self {
        case .capture(let type, let date):
            return "capture-\(type?.rawValue ?? "free")-\(date?.timeIntervalSinceReferenceDate ?? 0)"
        case .entry(let entry): return "entry-\(entry.persistentModelID.hashValue)"
        case .allocation: return "allocation"
        }
    }
}

@Observable
final class Router {
    var tab: RootTab = .journal
    var sheet: SheetRoute?
    var journalPath: [JournalRoute] = []
    var mePath: [MeRoute] = []

    func newEntry(type: EntryType? = nil, date: Date? = nil) {
        sheet = .capture(type, date)
    }

    func open(_ entry: Entry) {
        sheet = .entry(entry)
    }

    func open(_ box: EntryBox) {
        tab = .journal
        journalPath.append(.box(box))
    }

    func startAllocation() {
        sheet = .allocation
    }

    func openTags() {
        tab = .me
        mePath = [.tags]
    }

    func closeTagsToHome() {
        mePath = []
        journalPath = []
        tab = .journal
    }

    func openJournal(_ preset: JournalPreset) {
        tab = .journal
        journalPath = [.journal(preset)]
    }
}
