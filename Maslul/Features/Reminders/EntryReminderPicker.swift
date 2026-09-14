import SwiftUI
import UIKit

struct EntryReminderPicker: View {
    @Binding private var reminderAt: Date?
    @Binding private var delivery: EntryReminderDelivery

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAt: Date
    @State private var selectedDelivery: EntryReminderDelivery
    @State private var authorizationDenied = false
    @State private var isSaving = false

    init(reminderAt: Binding<Date?>, delivery: Binding<EntryReminderDelivery>) {
        _reminderAt = reminderAt
        _delivery = delivery
        _selectedAt = State(initialValue: reminderAt.wrappedValue ?? ReminderSuggestion.tomorrow.date)
        _selectedDelivery = State(initialValue: delivery.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Bring this entry back")
                            .font(.display(28))
                            .displayTracking(28)
                            .foregroundStyle(Palette.ink)
                        Text("Choose when Maslul should remind you.")
                            .font(.bodyText(14.5))
                            .foregroundStyle(Palette.meta)

                        if reminderAt != nil {
                            Button(role: .destructive) {
                                reminderAt = nil
                                dismiss()
                            } label: {
                                Label("Remove reminder", systemImage: "bell.slash")
                                    .font(.bodyText(12, weight: .semibold))
                                    .foregroundStyle(Color.red)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(Palette.line, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 9)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "DELIVERY")
                        HStack(spacing: 8) {
                            ForEach(EntryReminderDelivery.allCases) { option in
                                Button { selectedDelivery = option } label: {
                                    HStack(alignment: .top, spacing: 9) {
                                        Image(systemName: option.symbol)
                                            .font(.system(size: 15, weight: .semibold))
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(option.title)
                                                .font(.bodyText(13, weight: .semibold))
                                            Text(option.detail)
                                                .font(.bodyText(10.5))
                                                .foregroundStyle(selectedDelivery == option ? Palette.ink2 : Palette.meta)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                        }
                                    }
                                    .foregroundStyle(Palette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(selectedDelivery == option ? Palette.tagLemon : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(selectedDelivery == option ? Palette.ink.opacity(0.08) : Palette.lineSoft, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(ReminderSuggestion.allCases) { suggestion in
                            Button {
                                selectedAt = suggestion.date
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: suggestion.symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Palette.neutralTile))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.bodyText(15, weight: .semibold))
                                        Text(Fmt.reminderStamp(suggestion.date))
                                            .font(.utility(10.5))
                                            .foregroundStyle(Palette.meta)
                                    }

                                    Spacer()

                                    if Calendar.current.isDate(
                                        selectedAt,
                                        equalTo: suggestion.date,
                                        toGranularity: .minute
                                    ) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                }
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Palette.lineSoft, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "CUSTOM")
                        DatePicker(
                            "Date and time",
                            selection: $selectedAt,
                            in: Date.now.addingTimeInterval(60)...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .tint(Palette.ink)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                        )
                    }
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isSaving || selectedAt <= .now)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.ground)
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .alert(selectedDelivery == .alarm ? "Alarms are off" : "Notifications are off", isPresented: $authorizationDenied) {
            Button("Not now", role: .cancel) {}
            Button("Open Settings") { openRelevantSettings() }
        } message: {
            Text(
                selectedDelivery == .alarm
                    ? "Enable Alarms for Maslul in Settings, then return to schedule this alarm."
                    : "Enable Notifications for Maslul in Settings, then return to schedule this reminder."
            )
        }
    }

    private func save() {
        isSaving = true
        Task { @MainActor in
            let authorized = selectedDelivery == .alarm
                ? await EntryReminderScheduler.ensureAlarmAuthorization()
                : await EntryReminderScheduler.ensureAuthorization()
            if authorized {
                delivery = selectedDelivery
                reminderAt = selectedAt
                dismiss()
            } else {
                isSaving = false
                authorizationDenied = true
            }
        }
    }

    private func openRelevantSettings() {
        let urlString = selectedDelivery == .notification
            ? UIApplication.openNotificationSettingsURLString
            : UIApplication.openSettingsURLString
        guard let url = URL(string: urlString) else { return }
        Task { @MainActor in
            _ = await UIApplication.shared.open(url)
        }
    }
}

private enum ReminderSuggestion: CaseIterable, Identifiable {
    case hour
    case laterToday
    case tomorrow
    case nextWeek

    var id: Self { self }

    var title: String {
        switch self {
        case .hour: "In 1 hour"
        case .laterToday:
            Calendar.current.isDateInToday(date) ? "Later today" : "In 2 hours"
        case .tomorrow: "Tomorrow morning"
        case .nextWeek: "Next week"
        }
    }

    var symbol: String {
        switch self {
        case .hour: "clock"
        case .laterToday:
            Calendar.current.isDateInToday(date) ? "sun.max" : "moon"
        case .tomorrow: "sunrise"
        case .nextWeek: "calendar"
        }
    }

    var date: Date {
        let calendar = Calendar.current
        switch self {
        case .hour:
            return Date.now.addingTimeInterval(60 * 60)
        case .laterToday:
            let sixPM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
            return sixPM > .now.addingTimeInterval(15 * 60)
                ? sixPM
                : (calendar.date(byAdding: .hour, value: 2, to: .now) ?? .now.addingTimeInterval(2 * 60 * 60))
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        case .nextWeek:
            let nextWeek = calendar.date(byAdding: .day, value: 7, to: .now) ?? .now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek
        }
    }
}

struct EntryReminderMark: View {
    let reminderAt: Date?
    let isDue: Bool
    let isArchived: Bool
    var showsTime = false

    init(
        entry: Entry,
        reminderAt: Date? = nil,
        isArchived: Bool = false,
        showsTime: Bool = false
    ) {
        self.reminderAt = reminderAt ?? entry.reminderAt
        self.isDue = !isArchived && (reminderAt ?? entry.reminderAt ?? .distantFuture) <= .now
        self.isArchived = isArchived
        self.showsTime = showsTime
    }

    var body: some View {
        if let reminderAt {
            HStack(spacing: 5) {
                Image(systemName: isDue ? "bell.fill" : "bell")
                    .font(.system(size: 12.5, weight: .semibold))
                if showsTime {
                    Text(Fmt.reminderStamp(reminderAt))
                        .font(.utility(10))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, showsTime ? 8 : 6)
            .frame(height: 24)
            .background(
                Capsule().fill(isArchived ? Palette.neutralTile : Palette.accent)
            )
            .accessibilityLabel("Reminder \(Fmt.reminderStamp(reminderAt))")
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

extension Fmt {
    static func reminderStamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today · \(time(date))" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow · \(time(date))" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
