import SwiftUI
import SwiftData

/// Full-text search plus filtering by type, project and date range (US-C3, 0.1).
/// Semantic search and the two-line summary above the results are 1.0.
struct JournalView: View {
    let preset: JournalPreset

    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    @Query(sort: \Project.createdAt, order: .forward)
    private var projects: [Project]

    @State private var query = ""
    @State private var typeFilter: EntryType?
    @State private var onlyPending = false
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
        .confirmationDialog("פרויקט", isPresented: $showProjectPicker, titleVisibility: .visible) {
            Button("כל הפרויקטים") { projectFilter = nil }
            ForEach(projects) { project in
                Button(project.name) { projectFilter = project }
            }
            Button("ביטול", role: .cancel) {}
        }
        .confirmationDialog("טווח", isPresented: $showRangePicker, titleVisibility: .visible) {
            ForEach(ExportRange.allCases) { candidate in
                Button(candidate.title) { range = candidate }
            }
            Button("ביטול", role: .cancel) {}
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
            if onlyPending, !entry.needsTidy { return false }
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
        case .pending:
            onlyPending = true
            range = .all
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
            Text(onlyPending ? "ממתינות לסידור" : "יומן")
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
            TextField("חפש ביומן", text: $query)
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
                Chip(title: "הכל", isOn: typeFilter == nil && !onlyPending) {
                    withAnimation(Motion.spring) {
                        typeFilter = nil
                        onlyPending = false
                    }
                }
                Chip(title: "ממתינות", isOn: onlyPending) {
                    withAnimation(Motion.spring) {
                        onlyPending.toggle()
                        if onlyPending { typeFilter = nil }
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
                            if typeFilter != nil { onlyPending = false }
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
            Chip(title: projectFilter?.name ?? "כל הפרויקטים", isSquare: true) {
                showProjectPicker = true
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.bottom, 10)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(months, id: \.key) { month in
                    SectionLabel(text: "\(Fmt.monthYear(month.key)) · \(month.entries.count) רשומות")
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    ForEach(month.entries) { entry in
                        Button { router.open(entry) } label: {
                            EntryRowView(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(query.isEmpty ? "אין רשומות בטווח הזה" : "אין תוצאות ל\"\(query)\"")
                .font(.bodyText(15))
                .foregroundStyle(Palette.muted)
            Text(query.isEmpty ? "נסה טווח רחב יותר" : "אין כאן ניחוש — רק מה שכתבת")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
