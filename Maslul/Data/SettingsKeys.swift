import Foundation

/// Every preference lives in UserDefaults. There is no account and no server,
/// so there is nothing else for it to live in.
enum SettingsKey {
    static let onboarded = "maslul.onboarded"
    static let userName = "maslul.userName"

    static let reminderEnabled = "maslul.reminder.enabled"
    /// Foundation weekday numbering: 1 = Sunday. Default 5 = Thursday.
    static let reminderWeekday = "maslul.reminder.weekday"
    static let reminderHour = "maslul.reminder.hour"
    static let reminderMinute = "maslul.reminder.minute"

    static let hideProjectNames = "maslul.hideProjectNames"
    static let sampleDataLoaded = "maslul.sampleDataLoaded"

    static let draftBody = "maslul.draft.body"
    static let draftType = "maslul.draft.type"
}

enum Defaults {
    static let reminderWeekday = 5   // חמישי
    static let reminderHour = 16
    static let reminderMinute = 30
}
