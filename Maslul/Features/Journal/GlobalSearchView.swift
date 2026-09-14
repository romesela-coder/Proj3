import SwiftUI
import SwiftData

private enum SearchSortOrder: String, CaseIterable, Identifiable {
    case relevance = "Relevance"
    case newest = "Newest"
    case oldest = "Oldest"

    var id: String { rawValue }
}

private enum SearchPrivacyFilter: String, CaseIterable, Identifiable {
    case all = "Any privacy"
    case standard = "Not private"
    case privateOnly = "Private"

    var id: String { rawValue }
}

private enum SearchDateFilter: String, CaseIterable, Identifiable {
    case anytime = "Any date"
    case today = "Today"
    case yesterday = "Yesterday"
    case lastSevenDays = "Last 7 days"
    case lastThirtyDays = "Last 30 days"
    case custom = "Custom range"

    var id: String { rawValue }
}

struct GlobalSearchView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<Entry> { $0.trashedAt == nil },
        sort: \Entry.createdAt,
        order: .reverse
    )
    private var entries: [Entry]

    @Query(sort: \EntryTag.name, order: .forward)
    private var tags: [EntryTag]

    @Query(sort: \EntryBox.sortIndex, order: .forward)
    private var boxes: [EntryBox]

    @State private var query = ""
    @State private var selectedTag: EntryTag?
    @State private var selectedBox: EntryBox?
    @State private var dateFilter: SearchDateFilter = .anytime
    @State private var privacyFilter: SearchPrivacyFilter = .all
    @State private var attachmentsOnly = false
    @State private var sortOrder: SearchSortOrder = .relevance
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    @State private var customEndDate = Date.now
    @State private var showCustomDateRange = false
    @FocusState private var searchFocused: Bool

    private var normalizedQuery: String {
        SearchText.normalized(query)
    }

    private var queryTerms: [String] {
        normalizedQuery.split(whereSeparator: \Character.isWhitespace).map(String.init)
    }

    private var entryResults: [Entry] {
        let needle = normalizedQuery
        return entries
            .filter(matchesFilters)
            .filter { entry in
                needle.isEmpty || SearchMatcher.matches(
                    terms: queryTerms,
                    in: SearchText.searchableText(for: entry)
                )
            }
            .sorted { lhs, rhs in
                switch sortOrder {
                case .newest:
                    return lhs.createdAt > rhs.createdAt
                case .oldest:
                    return lhs.createdAt < rhs.createdAt
                case .relevance:
                    guard !needle.isEmpty else { return lhs.createdAt > rhs.createdAt }
                    let leftScore = relevanceScore(for: lhs, needle: needle)
                    let rightScore = relevanceScore(for: rhs, needle: needle)
                    if leftScore == rightScore {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return leftScore > rightScore
                }
            }
    }

    private var activeTags: [EntryTag] {
        var seen: Set<String> = []
        return tags.filter { tag in
            !tag.isArchived
                && TagNameRules.isValid(tag.name)
                && seen.insert(TagNameRules.canonical(tag.name)).inserted
        }
    }

    private var tagResults: [EntryTag] {
        guard !normalizedQuery.isEmpty else { return [] }
        return activeTags.filter { SearchMatcher.matches(terms: queryTerms, in: $0.name) }
    }

    private var boxResults: [EntryBox] {
        guard !normalizedQuery.isEmpty else { return [] }
        return boxes.filter { SearchMatcher.matches(terms: queryTerms, in: $0.name) }
    }

    private var recentTags: [EntryTag] {
        activeTags
            .filter { latestUse(of: $0) != nil }
            .sorted {
                (latestUse(of: $0) ?? .distantPast) > (latestUse(of: $1) ?? .distantPast)
            }
            .prefix(6)
            .map { $0 }
    }

    private var recentBoxes: [EntryBox] {
        boxes
            .filter { latestUse(of: $0) != nil }
            .sorted {
                (latestUse(of: $0) ?? .distantPast) > (latestUse(of: $1) ?? .distantPast)
            }
            .prefix(5)
            .map { $0 }
    }

    private var hasResults: Bool {
        !tagResults.isEmpty || !boxResults.isEmpty || !entryResults.isEmpty
    }

    private var hasActiveFilters: Bool {
        selectedTag != nil
            || selectedBox != nil
            || dateFilter != .anytime
            || privacyFilter != .all
            || attachmentsOnly
            || sortOrder != .relevance
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            filterBar

            if normalizedQuery.isEmpty && !hasActiveFilters {
                if recentTags.isEmpty && recentBoxes.isEmpty {
                    initialState
                } else {
                    recentList
                }
            } else if !hasResults {
                noResultsState
            } else {
                resultList
            }
        }
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await Task.yield()
            searchFocused = true
        }
        .sheet(isPresented: $showCustomDateRange) {
            SearchDateRangeSheet(
                startDate: $customStartDate,
                endDate: $customEndDate,
                apply: {
                    dateFilter = .custom
                    showCustomDateRange = false
                }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "chevron.forward") { dismiss() }

            VStack(alignment: .leading, spacing: 2) {
                Text("Search")
                    .font(.display(30))
                    .displayTracking(30)
                    .foregroundStyle(Palette.ink)
                Text("Entries, tags, and boxes")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.meta)
            }

            Spacer()
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Palette.muted)

            TextField("Search entries, tags, and boxes", text: $query)
                .font(.bodyText(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(false)
                .focused($searchFocused)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Palette.meta)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
        .padding(.horizontal, Metrics.hMargin)
        .padding(.bottom, 12)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("All boxes") { selectedBox = nil }
                    Divider()
                    ForEach(boxes) { box in
                        Button(box.name) { selectedBox = box }
                    }
                } label: {
                    SearchFilterChip(
                        title: selectedBox?.name ?? "Box",
                        symbol: "archivebox",
                        isActive: selectedBox != nil
                    )
                }

                Menu {
                    Button("All tags") { selectedTag = nil }
                    Divider()
                    ForEach(activeTags) { tag in
                        Button(tag.name) { selectedTag = tag }
                    }
                } label: {
                    SearchFilterChip(
                        title: selectedTag?.name ?? "Tag",
                        symbol: "tag",
                        isActive: selectedTag != nil
                    )
                }

                Menu {
                    ForEach(SearchDateFilter.allCases) { candidate in
                        Button(candidate.rawValue) {
                            if candidate == .custom {
                                showCustomDateRange = true
                            } else {
                                dateFilter = candidate
                            }
                        }
                    }
                } label: {
                    SearchFilterChip(
                        title: dateFilter.rawValue,
                        symbol: "calendar",
                        isActive: dateFilter != .anytime
                    )
                }

                Button {
                    attachmentsOnly.toggle()
                } label: {
                    SearchFilterChip(
                        title: "Attachments",
                        symbol: "paperclip",
                        isActive: attachmentsOnly
                    )
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(SearchPrivacyFilter.allCases) { candidate in
                        Button(candidate.rawValue) { privacyFilter = candidate }
                    }
                } label: {
                    SearchFilterChip(
                        title: privacyFilter.rawValue,
                        symbol: privacyFilter == .privateOnly ? "lock.fill" : "lock.open",
                        isActive: privacyFilter != .all
                    )
                }

                Menu {
                    ForEach(SearchSortOrder.allCases) { candidate in
                        Button(candidate.rawValue) { sortOrder = candidate }
                    }
                } label: {
                    SearchFilterChip(
                        title: sortOrder.rawValue,
                        symbol: "arrow.up.arrow.down",
                        isActive: sortOrder != .relevance
                    )
                }

                if hasActiveFilters {
                    Button("Clear") { clearFilters() }
                        .font(.bodyText(12.5, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Metrics.hMargin)
        }
        .padding(.bottom, 6)
    }

    private var resultList: some View {
        List {
            if !tagResults.isEmpty {
                searchSectionLabel("TAGS", topPadding: 10)

                ForEach(tagResults) { tag in
                    Button { router.open(tag) } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .journalListRow()
                }
            }

            if !boxResults.isEmpty {
                searchSectionLabel("BOXES", topPadding: tagResults.isEmpty ? 10 : 18)

                ForEach(boxResults) { box in
                    Button { router.open(box) } label: {
                        boxRow(box)
                    }
                    .buttonStyle(.plain)
                    .journalListRow()
                }
            }

            if !entryResults.isEmpty {
                searchSectionLabel(
                    "\(entryResults.count) \(entryResults.count == 1 ? "ENTRY" : "ENTRIES")",
                    topPadding: tagResults.isEmpty && boxResults.isEmpty ? 10 : 18
                )

                ForEach(entryResults) { entry in
                    Button {
                        router.open(entry)
                    } label: {
                        EntryRowView(entry: entry)
                            .padding(.horizontal, Metrics.hMargin)
                    }
                    .buttonStyle(.plain)
                    .journalListRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    private var recentList: some View {
        List {
            if !recentTags.isEmpty {
                searchSectionLabel("RECENT TAGS", topPadding: 10)

                ForEach(recentTags) { tag in
                    Button { router.open(tag) } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .journalListRow()
                }
            }

            if !recentBoxes.isEmpty {
                searchSectionLabel("RECENT BOXES", topPadding: recentTags.isEmpty ? 10 : 18)

                ForEach(recentBoxes) { box in
                    Button { router.open(box) } label: {
                        boxRow(box)
                    }
                    .buttonStyle(.plain)
                    .journalListRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    private func searchSectionLabel(_ text: String, topPadding: CGFloat) -> some View {
        SectionLabel(text: text)
            .padding(.top, topPadding)
            .padding(.bottom, 4)
            .padding(.horizontal, Metrics.hMargin)
            .journalListRow()
    }

    private func tagRow(_ tag: EntryTag) -> some View {
        HStack(spacing: 12) {
            Text(TagMentionVisual.emoji(for: tag) ?? "🏷️")
                .font(.system(size: 19))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(TagMentionVisual.background(for: tag))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(tag.name)
                    .font(.bodyText(15.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(tagSubtitle(tag))
                    .font(.bodyText(12))
                    .foregroundStyle(Palette.meta)
                    .lineLimit(1)
            }

            Spacer()
            Chevron()
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, Metrics.hMargin)
    }

    private func boxRow(_ box: EntryBox) -> some View {
        HStack(spacing: 12) {
            EntryBoxTile(box: box, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(box.name)
                    .font(.bodyText(15.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(entryCountText(activeEntries(in: box).count))
                    .font(.bodyText(12))
                    .foregroundStyle(Palette.meta)
            }

            Spacer()
            Chevron()
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, Metrics.hMargin)
    }

    private var initialState: some View {
        searchState(
            symbol: "text.magnifyingglass",
            title: "Find anything you wrote",
            detail: "Search is local, fast, and works across titles and notes."
        )
    }

    private var noResultsState: some View {
        searchState(
            symbol: "magnifyingglass",
            title: "No matching entries",
            detail: "Try fewer words or a different spelling."
        )
    }

    private func searchState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.muted)
            Text(title)
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            Text(detail)
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 42)
    }

    private func activeEntries(in tag: EntryTag) -> [Entry] {
        tag.entries.filter { !$0.isTrashed }
    }

    private func activeEntries(in box: EntryBox) -> [Entry] {
        box.entries.filter { !$0.isTrashed }
    }

    private func latestUse(of tag: EntryTag) -> Date? {
        activeEntries(in: tag).map(\.createdAt).max()
    }

    private func latestUse(of box: EntryBox) -> Date? {
        activeEntries(in: box).map(\.createdAt).max()
    }

    private func tagSubtitle(_ tag: EntryTag) -> String {
        let count = activeEntries(in: tag).count
        if let group = tag.group {
            return "\(entryCountText(count)) · \(group.name)"
        }
        return entryCountText(count)
    }

    private func entryCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "entry" : "entries")"
    }

    private func matchesFilters(_ entry: Entry) -> Bool {
        if let selectedBox,
           entry.box?.persistentModelID != selectedBox.persistentModelID {
            return false
        }
        if let selectedTag,
           !entry.tags.contains(where: {
               $0.persistentModelID == selectedTag.persistentModelID
           }) {
            return false
        }
        if attachmentsOnly && entry.attachmentNames.isEmpty {
            return false
        }
        switch privacyFilter {
        case .all:
            break
        case .standard where entry.isSensitive:
            return false
        case .privateOnly where !entry.isSensitive:
            return false
        default:
            break
        }
        return matchesDateFilter(entry.createdAt)
    }

    private func matchesDateFilter(_ date: Date) -> Bool {
        let calendar = Calendar.current
        switch dateFilter {
        case .anytime:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .yesterday:
            return calendar.isDateInYesterday(date)
        case .lastSevenDays:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .distantPast
            return date >= start
        case .lastThirtyDays:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now)) ?? .distantPast
            return date >= start
        case .custom:
            let lower = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let upperDay = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let upper = calendar.date(byAdding: .day, value: 1, to: upperDay) ?? .distantFuture
            return date >= lower && date < upper
        }
    }

    private func clearFilters() {
        selectedTag = nil
        selectedBox = nil
        dateFilter = .anytime
        privacyFilter = .all
        attachmentsOnly = false
        sortOrder = .relevance
    }

    private func relevanceScore(for entry: Entry, needle: String) -> Int {
        let title = SearchText.normalized(entry.title)
        let body = SearchText.normalized(entry.body)
        let metadata = SearchText.normalized(
            "\(entry.box?.name ?? "") \(entry.tags.map(\.name).joined(separator: " ")) \(SearchText.dateTerms(for: entry.createdAt))"
        )

        if title == needle { return 400 }
        if title.hasPrefix(needle) { return 300 }
        if title.contains(needle) { return 200 }
        if body.contains(needle) { return 100 }
        if metadata.contains(needle) { return 60 }
        return 20
    }
}

private struct SearchFilterChip: View {
    let title: String
    let symbol: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .opacity(0.72)
        }
        .font(.bodyText(12.5, weight: isActive ? .semibold : .regular))
        .foregroundStyle(isActive ? Color.white : Palette.ink2)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(isActive ? Palette.control : Color.white))
        .overlay(Capsule().stroke(isActive ? Palette.control : Palette.line, lineWidth: 1))
    }
}

private struct SearchDateRangeSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let apply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                CircleButton(symbol: "xmark") { dismiss() }
                Spacer()
                Text("DATE RANGE")
                    .font(.utility(11.5))
                    .tracking(1.5)
                    .foregroundStyle(Palette.meta)
                Spacer()
                Button("Apply", action: apply)
                    .font(.bodyText(13, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 15)
                    .frame(height: 40)
                    .background(Capsule().fill(Palette.control))
                    .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                DatePicker(
                    "From",
                    selection: $startDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .padding(.vertical, 13)

                Rectangle().fill(Palette.lineSoft).frame(height: 1)

                DatePicker(
                    "To",
                    selection: $endDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .padding(.vertical, 13)
            }
            .font(.bodyText(15, weight: .medium))
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )

            Text("Both selected days are included.")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 16)
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
    }
}

struct TagEntriesView: View {
    let tag: EntryTag

    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private var entries: [Entry] {
        tag.entries
            .filter { !$0.isTrashed }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "chevron.forward") { dismiss() }

            Text(TagMentionVisual.emoji(for: tag) ?? "🏷️")
                .font(.system(size: 20))
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TagMentionVisual.background(for: tag))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.display(26))
                    .displayTracking(26)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.meta)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var entryList: some View {
        List {
            ForEach(entries) { entry in
                Button { router.open(entry) } label: {
                    EntryRowView(entry: entry)
                        .padding(.horizontal, Metrics.hMargin)
                }
                .buttonStyle(.plain)
                .journalListRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        EntryReminderScheduler.cancel(entry)
                        entry.moveToTrash()
                        try? context.save()
                    } label: {
                        Label("Trash", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No entries with this tag")
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            Text("Mention this tag in an entry to find it here.")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 42)
    }
}

private enum SearchText {
    static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func searchableText(for entry: Entry) -> String {
        [
            entry.title,
            entry.body,
            entry.box?.name ?? "",
            entry.tags.map(\.name).joined(separator: " "),
            dateTerms(for: entry.createdAt)
        ]
        .joined(separator: "\n")
    }

    static func dateTerms(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        let day = components.day ?? 0
        let month = components.month ?? 0
        let year = components.year ?? 0

        var values = [
            "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))",
            "\(day).\(month).\(year)",
            "\(month)/\(day)/\(year)"
        ]

        for localeIdentifier in ["en_US", "he_IL"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: localeIdentifier)
            formatter.calendar = calendar
            formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM y")
            values.append(formatter.string(from: date))
        }

        if calendar.isDateInToday(date) {
            values.append("today היום")
        } else if calendar.isDateInYesterday(date) {
            values.append("yesterday אתמול")
        }
        return values.joined(separator: " ")
    }
}

private enum SearchMatcher {
    static func matches(terms: [String], in value: String) -> Bool {
        let candidate = SearchText.normalized(value)
        let words = candidate
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        return terms.allSatisfy { term in
            if candidate.contains(term) { return true }
            let limit = typoLimit(for: term.count)
            guard limit > 0 else { return false }
            return words.contains { word in
                abs(word.count - term.count) <= limit
                    && editDistance(term, word, stoppingAfter: limit) <= limit
            }
        }
    }

    private static func typoLimit(for length: Int) -> Int {
        switch length {
        case 0...3: return 0
        case 4...7: return 1
        default: return 2
        }
    }

    private static func editDistance(
        _ lhs: String,
        _ rhs: String,
        stoppingAfter limit: Int
    ) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        guard abs(left.count - right.count) <= limit else { return limit + 1 }

        var previous = Array(0...right.count)
        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1]
            current.reserveCapacity(right.count + 1)

            for (rightIndex, rightCharacter) in right.enumerated() {
                let insertion = current[rightIndex] + 1
                let deletion = previous[rightIndex + 1] + 1
                let substitution = previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                current.append(min(insertion, deletion, substitution))
            }
            if current.min() ?? 0 > limit { return limit + 1 }
            previous = current
        }
        return previous[right.count]
    }
}
