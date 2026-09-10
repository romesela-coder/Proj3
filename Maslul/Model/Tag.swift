import Foundation
import SwiftData

enum TagNameRules {
    static let maxLength = 50

    static func normalized(_ value: String) -> String {
        String(value.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValid(_ value: String) -> Bool {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= maxLength
    }

    static func canonical(_ value: String) -> String {
        normalized(value).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

/// A user-defined namespace for tags, such as Projects, People or Entry type.
@Model
final class TagGroup {
    var name: String = ""
    var emoji: String = "🏷️"
    var note: String = ""
    var allowsMultiple: Bool = true
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Transient var isGeneratingEmoji = false

    /// Identifies groups supplied by the app without making custom groups special.
    var systemKey: String?

    @Relationship(deleteRule: .cascade, inverse: \EntryTag.group)
    var tags: [EntryTag] = []

    init(
        name: String,
        emoji: String = "🏷️",
        note: String = "",
        allowsMultiple: Bool = true,
        systemKey: String? = nil,
        createdAt: Date = .now
    ) {
        self.name = name
        self.emoji = emoji
        self.note = note
        self.allowsMultiple = allowsMultiple
        self.systemKey = systemKey
        self.createdAt = createdAt
    }
}

@Model
final class EntryTag {
    var name: String = ""
    var emoji: String = "🏷️"
    var note: String = ""
    var colorRaw: String = "neutral"
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Transient var isGeneratingEmoji = false

    /// Stable key used while the existing type/project data is migrated in stages.
    var legacyKey: String?
    var group: TagGroup?

    var entries: [Entry] = []

    init(
        name: String,
        emoji: String = "🏷️",
        note: String = "",
        legacyKey: String? = nil,
        group: TagGroup? = nil,
        createdAt: Date = .now
    ) {
        self.name = name
        self.emoji = emoji
        self.note = note
        self.legacyKey = legacyKey
        self.group = group
        self.createdAt = createdAt
        self.entries = []
    }
}

extension TagGroup {
    static func suggestedEmoji(for name: String) -> String {
        EntryTag.suggestedEmoji(for: name, fallback: "🏷️")
    }
}

extension EntryTag {
    static func suggestedEmoji(for name: String, fallback: String = "🏷️") -> String {
        let value = name.lowercased()
        if value.contains("people") || value.contains("person") || value.contains("team") { return "👥" }
        if value.contains("project") || value.contains("work") { return "📁" }
        if value.contains("client") || value.contains("customer") { return "🤝" }
        if value.contains("idea") || value.contains("learn") { return "💡" }
        if value.contains("goal") || value.contains("target") { return "🎯" }
        if value.contains("product") { return "📦" }
        if value.contains("design") { return "🎨" }
        if value.contains("data") || value.contains("metric") { return "📊" }
        return fallback
    }
}

@MainActor
enum TagBootstrap {
    static func ensureDefaults(in context: ModelContext, projects: [Project]) {
        let existing = (try? context.fetch(FetchDescriptor<TagGroup>())) ?? []

        let typeGroup = existing.first { $0.systemKey == "entry-type" } ?? {
            let group = TagGroup(
                name: "Entry type",
                emoji: "✨",
                note: "What kind of moment is this?",
                allowsMultiple: false,
                systemKey: "entry-type"
            )
            context.insert(group)
            return group
        }()

        for type in EntryType.allCases where !typeGroup.tags.contains(where: { $0.legacyKey == type.rawValue }) {
            let tag = EntryTag(
                name: type.title,
                emoji: emoji(for: type),
                note: type.hint,
                legacyKey: type.rawValue,
                group: typeGroup
            )
            context.insert(tag)
        }

        let projectGroup = existing.first { $0.systemKey == "projects" } ?? {
            let group = TagGroup(
                name: "Projects",
                emoji: "📁",
                note: "Workstreams, products and initiatives",
                allowsMultiple: false,
                systemKey: "projects"
            )
            context.insert(group)
            return group
        }()

        for project in projects {
            guard TagNameRules.isValid(project.name) else { continue }
            let key = "project-\(TagNameRules.canonical(project.name))"
            guard !projectGroup.tags.contains(where: {
                $0.legacyKey == key || TagNameRules.canonical($0.name) == TagNameRules.canonical(project.name)
            }) else { continue }
            let tag = EntryTag(
                name: project.name,
                emoji: project.emoji,
                legacyKey: key,
                group: projectGroup,
                createdAt: project.createdAt
            )
            tag.isArchived = project.status == .done
            context.insert(tag)
        }

        try? context.save()
    }

    private static func emoji(for type: EntryType) -> String {
        switch type {
        case .win: return "🏆"
        case .learning: return "💡"
        case .friction: return "🧱"
        case .decision: return "🔀"
        case .goal: return "🎯"
        case .people: return "👥"
        }
    }
}
