import SwiftUI

// MARK: - Shared header

struct ScreenHeader: View {
    let title: String
    var onBack: () -> Void

    var body: some View {
        HStack {
            CircleButton(symbol: "chevron.forward", action: onBack)
            Spacer()
            Text(title)
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Color.clear.frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}

// MARK: - Privacy

/// Privacy here is a functional feature, not a policy page (spec §03.02).
/// Without certainty that nothing leaves the device there is no honesty, and
/// without honesty the journal is worth nothing in a year.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    private let claims: [(String, String)] = [
        ("person.crop.circle.badge.xmark", "אין חשבון ואין הרשמה. גם לא בהמשך."),
        ("network.slash", "אין שרת. האפליקציה נבנתה בלי קוד רשת בכלל."),
        ("iphone", "כל הנתונים יושבים בקונטיינר של האפליקציה על המכשיר הזה."),
        ("chart.bar.xaxis", "אין אנליטיקס, אין crash reporting, אין SDK של צד שלישי."),
        ("square.and.arrow.up", "ייצוא קורה רק ביוזמתך, ועובר דרך ה-share sheet של המערכת.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: "פרטיות") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("היומן הזה\nלא יוצא מהטלפון.")
                        .font(.display(28))
                        .displayTracking(28)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(claims, id: \.1) { claim in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: claim.0)
                                    .font(.system(size: 17, weight: .light))
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 24)
                                Text(claim.1)
                                    .font(.bodyText(15.5))
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    CardBox {
                        Text("בגלל זה אפשר לכתוב כאן גם על מה שלא הלך — פידבק שצרב, ריג׳קט, טעות. זה החלק שיהיה שווה הכי הרבה בעוד שנה.")
                            .font(.bodyText(14))
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "מה עוד אין כאן")
                        Text("גיבוי אוטומטי לא קיים בגרסה הזו. אם המכשיר אובד, היומן אובד איתו. הדרך היחידה לשמור עותק היא ייצוא ידני מתוך מסך \"אני\". זו החלטה פתוחה במסמך האפיון, ולא השמטה.")
                            .font(.bodyText(13.5))
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Reminder

struct ReminderView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.reminderEnabled) private var enabled = false
    @AppStorage(SettingsKey.reminderWeekday) private var weekday = Defaults.reminderWeekday
    @AppStorage(SettingsKey.reminderHour) private var hour = Defaults.reminderHour
    @AppStorage(SettingsKey.reminderMinute) private var minute = Defaults.reminderMinute

    @State private var deniedNotice = false

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour, minute: minute, second: 0, of: .now
                ) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hour = parts.hour ?? Defaults.reminderHour
                minute = parts.minute ?? Defaults.reminderMinute
                ReminderScheduler.sync()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: "תזכורת שבועית") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingRow(symbol: "bell", title: "תזכורת פעילה") {
                        Toggle("", isOn: Binding(
                            get: { enabled },
                            set: { newValue in
                                enabled = newValue
                                if newValue { requestAndSchedule() } else { ReminderScheduler.cancel() }
                            }
                        ))
                        .labelsHidden()
                        .tint(Palette.ink)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "יום")
                        WrapChips(items: Array(1...7).map(Fmt.weekday)) { index in
                            weekday = index + 1
                            ReminderScheduler.sync()
                        } isOn: { index in
                            weekday == index + 1
                        }
                    }
                    .opacity(enabled ? 1 : 0.4)
                    .disabled(!enabled)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "שעה")
                        DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Fmt.locale)
                            .frame(maxWidth: .infinity)
                    }
                    .opacity(enabled ? 1 : 0.4)
                    .disabled(!enabled)

                    CardBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("תזכורת אחת בשבוע. לא יותר משתיים.")
                                .font(.bodyText(14, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text("אין streaks, אין אדום, אין \"פספסת\". שבוע שהוחמץ הוא שבוע שהוחמץ — אפליקציה שמענישה על שתיקה נמחקת בפעם השנייה שהיא מענישה.")
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if deniedNotice {
                        Text("ההרשאה להתראות נדחתה. אפשר להפעיל אותה בהגדרות המכשיר — האפליקציה תמשיך לעבוד בלעדיה.")
                            .font(.bodyText(13))
                            .foregroundStyle(Palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func requestAndSchedule() {
        Task {
            let granted = await ReminderScheduler.requestAuthorization()
            await MainActor.run {
                deniedNotice = !granted
                if granted {
                    ReminderScheduler.sync()
                } else {
                    enabled = false
                }
            }
        }
    }
}

// MARK: - Entry points

/// Section §10 is the reason 0.1 might work at all — but widgets need a second
/// target and an App Group. This build is the app alone; the screen says so
/// rather than pretending.
struct EntryPointsView: View {
    @Environment(\.dismiss) private var dismiss

    private let family: [(String, String, String)] = [
        ("W1", "כתיבה מהירה · Home small", "כפתור אחד. נגיעה פותחת כתיבה עם המקלדת פתוחה."),
        ("W2", "ארבעה סוגים · Home medium", "הישג · למידה · חיכוך · מטרה, כל אחד פותח כתיבה עם הסוג נבחר."),
        ("W3", "טאלי פרויקטים · medium / large", "נגיעה מסמנת \"עבדתי על זה עכשיו\" בלי לפתוח את האפליקציה. גרסה 0.2."),
        ("W4", "מסך נעילה · accessory", "מלבני: מונה ממתינות. עגול: משגר כתיבה."),
        ("W5", "מרכז הבקרה · ControlWidget", "פקד \"רשומה חדשה\", ניתן להצמדה לכפתור הפעולה."),
        ("W6", "כפתור הפעולה · App Intents", "שלושה Intents בשמות עבריים.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: "נקודות כניסה") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CardBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("לא בבילד הזה")
                                .font(.bodyText(14, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text("הווידג׳טים דורשים טארגט נוסף ו-App Group עם מאגר SwiftData משותף. הבילד הזה הוא האפליקציה בלבד; המודל בנוי כך שהם ייכנסו בלי לשכתב אותו.")
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ForEach(family, id: \.0) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(item.0)
                                    .font(.utility(10.5))
                                    .tracking(1.2)
                                    .foregroundStyle(Palette.meta)
                                Text(item.1)
                                    .font(.bodyText(15, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                            }
                            Text(item.2)
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Palette.lineSoft).frame(height: 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "כלל שלא משתנה")
                        Text("שום ווידג׳ט לא יציג טקסט של רשומה. מונים, שמות פרויקטים ותוויות בלבד. אפליקציה שמזמינה אותך לכתוב על ריג׳קט מהבוס לא יכולה להציג את זה למי שמרים את הטלפון מהשולחן.")
                            .font(.bodyText(13.5))
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Roadmap

struct RoadmapView: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(String, String, String)] = [
        ("0.2", "חבילת ריוויו", "תקצירים חודשיים, הישגים מובילים, ציר למידה."),
        ("0.2", "הכתבה קולית מקומית", "תמלול על המכשיר בלבד, בלי שליחה לשרת."),
        ("0.2", "ווידג׳ט טאלי פרויקטים", "נגיעה מסמנת מעבר הקשר, בלי לפתוח את האפליקציה."),
        ("0.2", "תיוג אוטומטי במודל מקומי", "כרגע ההצעות בסידור השבועי מבוססות מילות מפתח, לא מודל."),
        ("1.0", "שורות קורות חיים", "פעולה → תוצאה → מדד, כטיוטה לצד הרשומה המקורית."),
        ("1.0", "שאלה חופשית", "חיפוש סמנטי מקומי וסיכום בשתי שורות מעל התוצאות."),
        ("1.0", "נעילה ב-Face ID", "נעילה בכניסה, נעילה מחדש אחרי 60 שניות ברקע."),
        ("1.0", "גיבוי מוצפן", "ההחלטה הפתוחה הגדולה ביותר במסמך.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: "מה עוד לא נבנה") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CardBox {
                        Text("הבילד הזה מכסה את היקף 0.1 ואת הליבה של 0.2: תפיסה, סידור שבועי, הקצאת זמן, דוח, מטרות מול מציאות וייצוא. מה שנשאר כאן דורש מודל מקומי או טארגט נוסף.")
                            .font(.bodyText(13.5))
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 8)

                    ForEach(items, id: \.1) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Text(item.0)
                                .font(.utility(10.5))
                                .tracking(1.2)
                                .foregroundStyle(Palette.meta)
                                .frame(width: 32, alignment: .leading)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.1)
                                    .font(.bodyText(15))
                                    .foregroundStyle(Palette.ink)
                                Text(item.2)
                                    .font(.bodyText(12.5))
                                    .foregroundStyle(Palette.meta)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Palette.lineSoft).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
