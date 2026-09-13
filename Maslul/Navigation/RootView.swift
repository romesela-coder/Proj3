import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(SettingsKey.onboarded) private var onboarded = false
    @Environment(\.modelContext) private var context
    @State private var router = Router()

    var body: some View {
        @Bindable var router = router

        return Group {
            if onboarded {
                tabs
            } else {
                OnboardingView()
            }
        }
        .environment(router)
        .background(Palette.ground)
        .sheet(item: $router.sheet) { route in
            switch route {
            case .capture(let type, let date):
                CaptureView(presetType: type, presetDate: date)
            case .entry(let entry):
                EntryDetailView(entry: entry)
            case .allocation:
                AllocationView(weekStart: Week.start()) { router.sheet = nil }
            }
        }
        .task {
            EntryBoxBootstrap.ensureDefaults(in: context)
            purgeExpiredTrash()
        }
    }

    private var tabs: some View {
        @Bindable var router = router

        return ZStack {
            switch router.tab {
            case .journal:
                NavigationStack(path: $router.journalPath) {
                    HomeView()
                        .navigationDestination(for: JournalRoute.self) { route in
                            switch route {
                            case .journal(let preset):
                                JournalView(preset: preset)
                            case .box(let box):
                                BoxDetailView(box: box)
                            case .tag(let tag):
                                TagEntriesView(tag: tag)
                            case .search:
                                GlobalSearchView()
                            }
                        }
                }
            case .me:
                NavigationStack(path: $router.mePath) {
                    MeView()
                        .navigationDestination(for: MeRoute.self) { route in
                            switch route {
                            case .tags: TagsView()
                            case .projects: ProjectsView()
                            case .timeReport: TimeReportView()
                            case .goals: GoalsView()
                            case .export: ExportView()
                            case .privacy: PrivacyView()
                            case .reminder: ReminderView()
                            case .entryPoints: EntryPointsView()
                            case .trash: TrashView()
                            }
                        }
                }
            }
        }
    }

    private func purgeExpiredTrash() {
        let cutoff = Date.now.addingTimeInterval(-Entry.trashLifetime)
        let allEntries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let expired = allEntries.filter { entry in
            guard let trashedAt = entry.trashedAt else { return false }
            return trashedAt <= cutoff
        }
        guard !expired.isEmpty else { return }
        expired.forEach(context.delete)
        try? context.save()
    }
}

// MARK: - Floating dock (spec §05.06)
//
// Navigation and the write button live in floating black pills at the bottom,
// not in a conventional tab bar. It leaves the content breathing.

struct DockBar: View {
    @Environment(Router.self) private var router
    var showsCompose = true
    var composeAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 2) {
                segment(.journal)
                segment(.me)
            }
            .padding(4)
            .background(Capsule().fill(Palette.control))

            if showsCompose {
                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    Button {
                        withAnimation(Motion.spring) {
                            router.openTags()
                        }
                    } label: {
                        Circle()
                            .fill(Palette.ground)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "tag")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                            )
                            .overlay(
                                Circle().stroke(Palette.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tags")

                    Button {
                        if let composeAction {
                            composeAction()
                        } else {
                            router.newEntry()
                        }
                    } label: {
                        Circle()
                            .fill(Palette.control)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New entry")
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Palette.ground.opacity(0), Palette.ground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func segment(_ tab: RootTab) -> some View {
        let isOn = router.tab == tab
        return Button {
            withAnimation(Motion.spring) { router.tab = tab }
        } label: {
            Text(tab.title)
                .font(.bodyText(13.5, weight: .semibold))
                .foregroundStyle(isOn ? Palette.ink : Color.white)
                .padding(.horizontal, 21)
                .frame(minHeight: 48)
                .background(Capsule().fill(isOn ? Palette.ground : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

/// Common chrome for the three root screens.
extension View {
    func withDock(
        showsCompose: Bool = true,
        isVisible: Bool = true,
        composeAction: (() -> Void)? = nil
    ) -> some View {
        self.safeAreaInset(edge: .bottom, spacing: 0) {
            if isVisible {
                DockBar(showsCompose: showsCompose, composeAction: composeAction)
            }
        }
    }

    func screenBackground() -> some View {
        self.background(Palette.ground.ignoresSafeArea())
    }
}
