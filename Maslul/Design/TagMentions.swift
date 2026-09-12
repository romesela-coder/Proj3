import SwiftUI
import SwiftData

enum TagMentionVisual {
    static func background(for tag: EntryTag) -> Color {
        if tag.colorRaw != TagColorOption.neutral.rawValue,
           let selected = TagColorOption(rawValue: tag.colorRaw) {
            return selected.color
        }
        return Palette.neutralTile
    }
}

enum MentionText {
    static func query(in text: String) -> String? {
        guard let at = text.lastIndex(of: "@") else { return nil }
        let after = text[text.index(after: at)...]
        guard !after.contains(where: { $0.isWhitespace || $0.isNewline }) else { return nil }
        return String(after)
    }

    static func insert(_ tag: EntryTag, into text: inout String) {
        guard let at = text.lastIndex(of: "@") else { return }
        text.replaceSubrange(at..<text.endIndex, with: "@\(tag.name) ")
    }
}

struct TagMentionSuggestions: View {
    @Binding var text: String
    @Binding var selectedTags: [EntryTag]
    let tags: [EntryTag]

    @Environment(\.modelContext) private var context
    @Query(sort: \TagGroup.createdAt, order: .forward) private var groups: [TagGroup]
    @State private var isChoosingGroup = false

    private var query: String? { MentionText.query(in: text) }

    private var matches: [EntryTag] {
        guard let query else { return [] }
        let needle = TagNameRules.canonical(query)
        var seen: Set<String> = []
        return tags
            .filter { tag in
                TagNameRules.isValid(tag.name) &&
                !tag.isArchived &&
                !selectedTags.contains(where: { $0.persistentModelID == tag.persistentModelID }) &&
                (needle.isEmpty || TagNameRules.canonical(tag.name).contains(needle)) &&
                seen.insert(TagNameRules.canonical(tag.name)).inserted
            }
            .prefix(6)
            .map { $0 }
    }

    private var proposedName: String {
        TagNameRules.normalized(query ?? "")
    }

    private var hasExactMatch: Bool {
        tags.contains { TagNameRules.canonical($0.name) == TagNameRules.canonical(proposedName) }
    }

    private var canCreate: Bool {
        TagNameRules.isValid(proposedName) && !hasExactMatch
    }

    private var activeGroups: [TagGroup] {
        groups.filter { !$0.isArchived }
    }

    var body: some View {
        if query != nil, !matches.isEmpty || canCreate {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if isChoosingGroup {
                        Text("Add “\(proposedName)” to")
                            .font(.bodyText(12.5, weight: .semibold))
                            .foregroundStyle(Palette.ink2)

                        ForEach(activeGroups) { group in
                            Button { createTag(in: group) } label: {
                                HStack(spacing: 5) {
                                    Text(group.emoji)
                                    Text(group.name)
                                }
                                .font(.bodyText(12.5, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Palette.neutralTile)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button { isChoosingGroup = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Palette.muted)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(matches) { tag in
                            Button { select(tag) } label: {
                                MentionCard(tag: tag, showsGroup: true)
                            }
                            .buttonStyle(.plain)
                        }

                        if canCreate {
                            Button { isChoosingGroup = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Create “\(proposedName)”")
                                }
                                .font(.bodyText(12.5, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Palette.neutralTile)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .onChange(of: query) { _, _ in
                if isChoosingGroup { isChoosingGroup = false }
            }
        }
    }

    private func select(_ tag: EntryTag) {
        guard TagNameRules.isValid(tag.name) else { return }
        if !selectedTags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
            selectedTags.append(tag)
        }
        MentionText.insert(tag, into: &text)
        isChoosingGroup = false
    }

    private func createTag(in group: TagGroup) {
        guard canCreate else { return }
        if let existing = tags.first(where: {
            TagNameRules.canonical($0.name) == TagNameRules.canonical(proposedName)
        }) {
            select(existing)
            return
        }

        let tag = EntryTag(name: proposedName, group: group)
        context.insert(tag)
        try? context.save()
        select(tag)
    }
}

struct MentionCard: View {
    let tag: EntryTag
    var showsGroup = false

    private var background: Color {
        TagMentionVisual.background(for: tag)
    }

    private var icon: String? {
        if tag.group?.systemKey == "projects",
           !tag.emoji.isEmpty,
           tag.emoji != "🏷️" {
            return tag.emoji
        }
        return tag.group?.emoji
    }

    private var entryType: EntryType? {
        guard tag.group?.systemKey == "entry-type",
              let key = tag.legacyKey else { return nil }
        return EntryType(rawValue: key)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let entryType {
                Image(systemName: EntryArtifact(type: entryType).symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 16)
            } else if let icon, !icon.isEmpty {
                Text(icon)
                    .font(.system(size: 12))
            }

            Text(tag.name)
                .lineLimit(1)

            if showsGroup, let group = tag.group {
                Text(group.name)
                    .font(.bodyText(10.5, weight: .medium))
                    .foregroundStyle(Palette.ink2.opacity(0.72))
                    .lineLimit(1)
            }

        }
        .font(.bodyText(12.5, weight: .semibold))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .frame(minHeight: 32)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Palette.ink.opacity(0.06), lineWidth: 1)
        )
    }
}
