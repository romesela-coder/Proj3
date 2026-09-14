import SwiftUI
import SwiftData

@main
struct MaslulApp: App {
    @UIApplicationDelegateAdaptor(MaslulAppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        FontLoader.registerBundledFonts()

        do {
            // Local store inside the app container, protected until first
            // unlock. There is no CloudKit configuration and no network code
            // anywhere in this target (spec §14).
            let configuration = ModelConfiguration(
                "Maslul",
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(
                for: Entry.self, EntryBox.self, Project.self, Goal.self, TagGroup.self, EntryTag.self,
                WeeklyAllocation.self, AllocationSlice.self,
                configurations: configuration
            )
        } catch {
            fatalError("לא ניתן לפתוח את מאגר הנתונים: \(error)")
        }

        ReminderScheduler.sync()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .leftToRight)
                .environment(\.locale, Locale(identifier: "en_US"))
                .tint(Palette.ink)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
