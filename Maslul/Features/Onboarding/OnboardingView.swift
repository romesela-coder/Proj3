import SwiftUI
import SwiftData

/// Under 60 seconds to the first entry, and not one sign-up screen (F7).
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.onboarded) private var onboarded = false
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderWeekday) private var reminderWeekday = Defaults.reminderWeekday
    @AppStorage(SettingsKey.reminderHour) private var reminderHour = Defaults.reminderHour
    @AppStorage(SettingsKey.reminderMinute) private var reminderMinute = Defaults.reminderMinute

    @State private var step = 0
    @State private var name = ""
    @State private var projectNames: [String] = []
    @State private var draftProject = ""
    @State private var wantsReminder = true

    @FocusState private var nameFocused: Bool
    @FocusState private var projectFocused: Bool

    private let stepCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 20) {
                content
                Spacer(minLength: 0)
                dots
                PrimaryButton(title: buttonTitle, isEnabled: canAdvance) { advance() }
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.top, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .screenBackground()
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Color.clear.frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
            Spacer()
            Text("\(step + 1) מתוך \(stepCount)")
                .font(.utility(10.5))
                .tracking(1.4)
                .foregroundStyle(Palette.meta)
            Spacer()
            Chip(title: "דלג") { finish() }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index == step ? Palette.ink : Palette.line)
                    .frame(width: 9, height: 9)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var buttonTitle: String {
        switch step {
        case 0: return "הבנתי, ממשיכים"
        case stepCount - 1: return "לרשומה הראשונה"
        default: return "ממשיכים"
        }
    }

    private var canAdvance: Bool {
        true
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: privacyStep
        case 1: nameStep
        case 2: projectsStep
        case 3: reminderStep
        default: entryPointsStep
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge("lock.shield")

            Text("היומן הזה\nלא יוצא מהטלפון.")
                .font(.display(30))
                .displayTracking(30)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 14) {
                bullet("אין חשבון ואין הרשמה. גם לא בהמשך.")
                bullet("אין שרת. האפליקציה נבנתה בלי קוד רשת בכלל.")
                bullet("הכל נשמר על המכשיר הזה בלבד.")
            }

            CardBox {
                Text("בגלל זה אפשר לכתוב כאן גם על מה שלא הלך — פידבק שצרב, ריג׳קט, טעות. זה החלק שיהיה שווה הכי הרבה בעוד שנה.")
                    .font(.bodyText(14))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge("person")

            Text("איך לפנות\nאליך?")
                .font(.display(30))
                .displayTracking(30)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            TextField("השם שלך", text: $name)
                .font(.bodyText(17))
                .focused($nameFocused)
                .submitLabel(.next)
                .onSubmit { advance() }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(Palette.line, lineWidth: 1))

            Text("זה מופיע רק בכותרת של מסך הבית, ורק אצלך.")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
        }
        .task { nameFocused = true }
    }

    private var projectsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge("folder")

            Text("על מה אתה\nעובד עכשיו?")
                .font(.display(30))
                .displayTracking(30)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("שלושה עד חמישה פרויקטים. אפשר לשנות בכל רגע, ואפשר גם לדלג.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TextField("שם פרויקט", text: $draftProject)
                    .font(.bodyText(16))
                    .focused($projectFocused)
                    .submitLabel(.done)
                    .onSubmit(addProject)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Palette.line, lineWidth: 1))

                Button(action: addProject) {
                    Circle()
                        .fill(Palette.control)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(Color.white)
                        )
                }
                .buttonStyle(.plain)
                .opacity(canAddProject ? 1 : 0.35)
                .disabled(!canAddProject)
            }

            if !projectNames.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(projectNames, id: \.self) { projectName in
                        Chip(title: projectName, isOn: true) {
                            withAnimation(Motion.spring) {
                                projectNames.removeAll { $0 == projectName }
                            }
                        }
                    }
                }
                Text("נגיעה בפרויקט מסירה אותו.")
                    .font(.bodyText(12))
                    .foregroundStyle(Palette.meta)
            }
        }
    }

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge("bell")

            Text("תזכורת אחת\nבשבוע.")
                .font(.display(30))
                .displayTracking(30)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("לא יומית, ולא עונשית. שבוע שהוחמץ הוא שבוע שהוחמץ.")
                .font(.bodyText(13.5))
                .foregroundStyle(Palette.meta)

            SettingRow(symbol: nil, title: "שלח לי תזכורת") {
                Toggle("", isOn: $wantsReminder)
                    .labelsHidden()
                    .tint(Palette.ink)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "יום")
                WrapChips(items: Array(1...7).map(Fmt.weekday)) { index in
                    reminderWeekday = index + 1
                } isOn: { index in
                    reminderWeekday == index + 1
                }
            }
            .opacity(wantsReminder ? 1 : 0.4)
            .disabled(!wantsReminder)

            HStack {
                SectionLabel(text: "שעה")
                Spacer()
                DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.locale, Fmt.locale)
            }
            .opacity(wantsReminder ? 1 : 0.4)
            .disabled(!wantsReminder)
        }
    }

    private var entryPointsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge("square.grid.2x2")

            Text("המרחק בין\nמחשבה לרשומה.")
                .font(.display(30))
                .displayTracking(30)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 14) {
                bullet("כפתור ה-+ השחור למטה פותח כתיבה חופשית, בלי לבחור סוג.")
                bullet("ארבעת האריחים במסך הבית פותחים כתיבה כשהסוג כבר נבחר.")
                bullet("סיווג, פרויקט ותאריך אפשר להוסיף אחר כך. הטקסט הוא השדה היחיד שחייב.")
            }

            CardBox {
                Text("הווידג׳טים למסך הבית ולמסך הנעילה הם החלק החשוב באמת, והם עוד לא בבילד הזה. עד אז, כדאי להשאיר את האפליקציה בשורה התחתונה של מסך הבית.")
                    .font(.bodyText(13.5))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Bits

    private func iconBadge(_ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.tileLine, lineWidth: 1)
            )
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Palette.ink)
            )
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Palette.ink)
                .frame(width: 5, height: 5)
                .padding(.top, 8)
            Text(text)
                .font(.bodyText(15.5))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now
                ) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = parts.hour ?? Defaults.reminderHour
                reminderMinute = parts.minute ?? Defaults.reminderMinute
            }
        )
    }

    private var canAddProject: Bool {
        let trimmed = draftProject.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && projectNames.count < Project.activeLimit
            && !projectNames.contains(trimmed)
    }

    private func addProject() {
        let trimmed = draftProject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAddProject else { return }
        withAnimation(Motion.spring) {
            projectNames.append(trimmed)
            draftProject = ""
        }
        projectFocused = true
    }

    // MARK: - Flow

    private func advance() {
        if step == 1 {
            userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if step < stepCount - 1 {
            withAnimation(Motion.spring) { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skipping the projects question leaves a single "general" project,
        // which can be split later (F7, edge case).
        let names = projectNames.isEmpty ? ["כללי"] : projectNames
        for projectName in names {
            context.insert(Project(name: projectName))
        }
        try? context.save()

        reminderEnabled = wantsReminder
        if wantsReminder {
            Task {
                let granted = await ReminderScheduler.requestAuthorization()
                await MainActor.run {
                    reminderEnabled = granted
                    ReminderScheduler.sync()
                }
            }
        }

        withAnimation(Motion.spring) { onboarded = true }
    }
}
