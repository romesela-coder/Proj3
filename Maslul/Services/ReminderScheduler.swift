import Foundation
import UserNotifications

/// One reminder a week, at a time the user picks. No streaks, no daily nagging,
/// no "you missed a day" (spec §03.06, US-F1/F2).
enum ReminderScheduler {
    static let identifier = "maslul.weekly"
    static let maxPerWeek = 2

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// `weekday` uses Foundation's 1 = Sunday convention.
    static func schedule(weekday: Int, hour: Int, minute: Int) {
        cancel()

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "רגע לסדר את השבוע"
        content.body = "כמה דקות לעבור על מה שכתבת."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Re-applies the stored preference. Called on launch and whenever the
    /// reminder settings change.
    static func sync() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: SettingsKey.reminderEnabled) else {
            cancel()
            return
        }
        let weekday = defaults.object(forKey: SettingsKey.reminderWeekday) as? Int ?? Defaults.reminderWeekday
        let hour = defaults.object(forKey: SettingsKey.reminderHour) as? Int ?? Defaults.reminderHour
        let minute = defaults.object(forKey: SettingsKey.reminderMinute) as? Int ?? Defaults.reminderMinute
        schedule(weekday: weekday, hour: hour, minute: minute)
    }
}
