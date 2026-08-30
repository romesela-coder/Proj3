import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(SettingsKey.onboarded) private var onboarded = false
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
            case .capture(let type):
                CaptureView(presetType: type)
            case .entry(let entry):
                EntryDetailView(entry: entry)
            }
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
                            }
                        }
                }
            case .me:
                NavigationStack(path: $router.mePath) {
                    MeView()
                        .navigationDestination(for: MeRoute.self) { route in
                            switch route {
                            case .projects: ProjectsView()
                            case .export: ExportView()
                            case .privacy: PrivacyView()
                            case .reminder: ReminderView()
                            case .entryPoints: EntryPointsView()
                            case .roadmap: RoadmapView()
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Floating dock (spec §05.06)
//
// Navigation and the write button live in floating black pills at the bottom,
// not in a conventional tab bar. It leaves the content breathing.

struct DockBar: View {
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                segment(.journal)
                segment(.me)
            }
            .padding(4)
            .background(Capsule().fill(Palette.control))

            Spacer(minLength: 8)

            Button {
                router.newEntry()
            } label: {
                Circle()
                    .fill(Palette.control)
                    .frame(width: Metrics.dockHeight, height: Metrics.dockHeight)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.white)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("רשומה חדשה")
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
                .foregroundStyle(isOn ? Color.white : Palette.muted)
                .padding(.horizontal, 17)
                .frame(minHeight: Metrics.tapTarget)
                .background(Capsule().fill(isOn ? Palette.controlOn : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

/// Common chrome for the three root screens.
extension View {
    func withDock() -> some View {
        self.safeAreaInset(edge: .bottom, spacing: 0) { DockBar() }
    }

    func screenBackground() -> some View {
        self.background(Palette.ground.ignoresSafeArea())
    }
}
