import UIKit
import UserNotifications

extension Notification.Name {
    static let openEntryReminder = Notification.Name("maslul.open-entry-reminder")
}

@MainActor
enum EntryReminderNotificationRoute {
    static var pendingIdentifier: UUID?
}

final class MaslulAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let rawIdentifier = response.notification.request.content
            .userInfo[EntryReminderScheduler.notificationEntryKey] as? String

        if let rawIdentifier, let identifier = UUID(uuidString: rawIdentifier) {
            Task { @MainActor in
                EntryReminderNotificationRoute.pendingIdentifier = identifier
                NotificationCenter.default.post(
                    name: .openEntryReminder,
                    object: nil,
                    userInfo: [EntryReminderScheduler.notificationEntryKey: rawIdentifier]
                )
            }
        }
        completionHandler()
    }
}
