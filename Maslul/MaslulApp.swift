import SwiftUI
import SwiftData

@main
struct MaslulApp: App {
    private let container: ModelContainer

    init() {
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
                for: Entry.self, Project.self,
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
                // The whole product is written in Hebrew, so the layout is RTL
                // regardless of the simulator's own language setting.
                .environment(\.layoutDirection, .rightToLeft)
                .tint(Palette.ink)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
