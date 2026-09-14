import Foundation
import UserNotifications
import AlarmKit
import SwiftUI

private struct EntryAlarmMetadata: AlarmMetadata {
    let entryReminderIdentifier: UUID
}

@MainActor
enum EntryReminderScheduler {
    private static let identifierPrefix = "maslul.entry."
    static let notificationEntryKey = "entryReminderIdentifier"

    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func ensureAlarmAuthorization() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized:
            return true
        case .notDetermined:
            return (try? await manager.requestAuthorization()) == .authorized
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    @discardableResult
    static func schedule(_ entry: Entry) async -> Bool {
        guard !entry.isTrashed,
              let reminderAt = entry.reminderAt,
              reminderAt > .now else { return false }

        let authorized: Bool
        switch entry.reminderDelivery {
        case .notification:
            authorized = await ensureAuthorization()
        case .alarm:
            authorized = await ensureAlarmAuthorization()
        }
        guard authorized else { return false }

        let reminderIdentifier = entry.reminderIdentifier ?? UUID()
        entry.reminderIdentifier = reminderIdentifier
        let requestIdentifier = identifier(for: reminderIdentifier)

        cancel(entry)

        if entry.reminderDelivery == .alarm {
            return await scheduleAlarm(
                at: reminderAt,
                identifier: reminderIdentifier
            )
        }

        let content = UNMutableNotificationContent()
        content.title = "Maslul reminder"
        content.body = entry.isSensitive ? "Return to a private entry." : entry.title
        content.sound = .default
        content.userInfo = [notificationEntryKey: reminderIdentifier.uuidString]

        var components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderAt
        )
        components.calendar = Calendar.current
        components.timeZone = .current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    static func cancel(_ entry: Entry) {
        guard let reminderIdentifier = entry.reminderIdentifier else { return }
        let requestIdentifier = identifier(for: reminderIdentifier)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
        try? AlarmManager.shared.cancel(id: reminderIdentifier)
    }

    static func removeReminder(from entry: Entry) {
        cancel(entry)
        entry.reminderAt = nil
        entry.reminderIdentifier = nil
        entry.touch()
    }

    static func archive(_ entry: Entry) {
        guard let reminderAt = entry.reminderAt else { return }
        cancel(entry)
        entry.archivedReminderAt = reminderAt
        entry.reminderAt = nil
        entry.reminderIdentifier = nil
        entry.touch()
    }

    static func archivePassedReminders(in entries: [Entry]) {
        for entry in entries where !entry.isTrashed && (entry.reminderAt ?? .distantFuture) <= .now {
            archive(entry)
        }
    }

    static func removeArchivedReminder(from entry: Entry) {
        entry.archivedReminderAt = nil
        entry.touch()
    }

    /// Rebuilds the finite pending queue after launches, clock changes, or restores.
    /// A small reserve is left for the app's weekly reflection reminder.
    static func reconcile(_ entries: [Entry]) async {
        let active = entries
            .filter { !$0.isTrashed && ($0.reminderAt ?? .distantPast) > .now }
            .sorted { ($0.reminderAt ?? .distantFuture) < ($1.reminderAt ?? .distantFuture) }
            .prefix(60)
        for entry in active {
            _ = await schedule(entry)
        }
    }

    private static func identifier(for reminderIdentifier: UUID) -> String {
        identifierPrefix + reminderIdentifier.uuidString
    }

    private static func scheduleAlarm(at date: Date, identifier: UUID) async -> Bool {
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: "Maslul reminder")
        } else {
            let stopButton = AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.circle.fill"
            )
            alert = AlarmPresentation.Alert(
                title: "Maslul reminder",
                stopButton: stopButton
            )
        }
        let presentation = AlarmPresentation(
            alert: alert
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: EntryAlarmMetadata(entryReminderIdentifier: identifier),
            tintColor: Palette.accent
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(date),
            attributes: attributes
        )

        do {
            _ = try await AlarmManager.shared.schedule(
                id: identifier,
                configuration: configuration
            )
            return true
        } catch {
            return false
        }
    }
}
