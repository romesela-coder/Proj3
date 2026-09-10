import SwiftUI
import SwiftData

/// Full-text search plus filtering by type, project and date range (US-C3, 0.1).
/// Semantic search and the two-line summary above the results are 1.0.
struct JournalView: View {
    let preset: JournalPreset

    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    @Query(sort: \Project.createdAt, order: .forward)
    private var projects: [Project]

    @State private var query = ""
    @State private var typeFilter: EntryType?
    @State private var range: ExportRange = .quarter
    @State private var projectFilter: Project?
    @State private var isSearching = false
    @State private var showProjectPicker = false
    @State private var showRangePicker = false

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if isSearching { searchField }
            typeChips
            secondaryChips

            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .screenBackground()
        .withDock()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { applyPreset() }
        .confirmationDialog("Project", isPresented: $showProjectPicker, titleVisibility: .visible) {
            Button("All projects") { projectFilter = nil }
            ForEach(projects) { project in
                Button(project.name) { projectFilter = project }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Range", isPresented: $showRangePicker, titleVisibility: .visible) {
            ForEach(ExportRange.allCases) { candidate in
                Button(candidate.title) { range = candidate }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Filtering
    //
    // Done in memory on purpose. The dataset is one person's journal, and
    // SwiftData predicates over optional relationships are a source of bugs
    // out of proportion to what they'd save here.

    private var filtered: [Entry] {
        let start = range.start()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entries.filter { entry in
            if let typeFilter, entry.type != typeFilter { return false }
            if let projectFilter,
               entry.project?.persistentModelID != projectFilter.persistentModelID { return false }
            if let start, entry.createdAt < start { return false }
            if !needle.isEmpty, !entry.body.lowercased().contains(needle) { return false }
            return true
        }
    }

    private var months: [(key: Date, entries: [Entry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filtered) { entry -> Date in
            let components = cal.dateComponents([.year, .month], from: entry.createdAt)
            return cal.date(from: components) ?? entry.createdAt
        }
        return grouped
            .map { (key: $0.key, entries: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.key > $1.key }
    }

    private func applyPreset() {
        switch preset {
        case .all:
            break
        case .search:
            isSearching = true
            range = .all
            searchFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            CircleButton(symbol: "chevron.forward") { dismiss() }
            Spacer()
            Text("Journal")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            CircleButton(symbol: isSearching ? "xmark" : "magnifyingglass") {
                withAnimation(Motion.spring) {
                    isSearching.toggle()
                    if isSearching {
                        searchFocused = true
                    } else {
                        query = ""
                    }
                }
            }
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
            TextField("Search journal", text: $query)
                .font(.bodyText(15))
                .focused($searchFocused)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.meta)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
        .padding(.horizontal, Metrics.hMargin)
        .padding(.bottom, 12)
    }

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", isOn: typeFilter == nil) {
                    withAnimation(Motion.spring) {
                        typeFilter = nil
                    }
                }
                ForEach(EntryType.allCases) { candidate in
                    Chip(
                        title: candidate.title,
                        isOn: typeFilter == candidate,
                        tint: typeFilter == candidate ? nil : candidate.tint
                    ) {
                        withAnimation(Motion.spring) {
                            typeFilter = (typeFilter == candidate) ? nil : candidate
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.hMargin)
        }
        .padding(.bottom, 12)
    }

    private var secondaryChips: some View {
        HStack(spacing: 8) {
            Chip(title: range.title, isSquare: true) { showRangePicker = true }
            Chip(title: projectFilter?.name ?? "All projects", isSquare: true) {
                showProjectPicker = true
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.bottom, 10)
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(months, id: \.key) { month in
                SectionLabel(text: "\(Fmt.monthYear(month.key)) · \(month.entries.count) entries")
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                    .journalListRow()

                ForEach(month.entries) { entry in
                    Button { router.open(entry) } label: {
                        EntryRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .journalListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { moveToTrash(entry) } label: {
                            Label("Trash", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(query.isEmpty ? "No entries in this range" : "No results for \"\(query)\"")
                .font(.bodyText(15))
                .foregroundStyle(Palette.muted)
            Text(query.isEmpty ? "Try a wider range" : "No guessing — only what you wrote")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func moveToTrash(_ entry: Entry) {
        entry.moveToTrash()
        try? context.save()
    }
}

struct TrashView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt != nil }, sort: \Entry.trashedAt, order: .reverse)
    private var entries: [Entry]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleButton(symbol: "chevron.forward") { dismiss() }
                Spacer()
                Text("Trash")
                    .font(.bodyText(16, weight: .bold))
                Spacer()
                Color.clear.frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Text("Entries are permanently deleted 48 hours after being moved here.")
                .font(.bodyText(13))
                .foregroundStyle(Palette.meta)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 14)

            if entries.isEmpty {
                Spacer()
                Text("Trash is empty")
                    .font(.bodyText(15))
                    .foregroundStyle(Palette.meta)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            HStack(spacing: 10) {
                                EntryRowView(entry: entry)
                                Button { restore(entry) } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Palette.neutralTile))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Restore entry")
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.hMargin)
                    .padding(.bottom, 30)
                }
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func restore(_ entry: Entry) {
        entry.restoreFromTrash()
        try? context.save()
    }
}
