import Foundation
import SwiftData

/// Demo content, off by default and loaded only from the "אני" tab.
///
/// Dates are generated relative to today so the journal, the filters and the
/// month grouping always have something recent to show.
enum SampleData {

    private struct Seed {
        let daysAgo: Int
        let type: EntryType?
        let projectIndex: Int?
        let effort: Effort?
        let sensitive: Bool
        let body: String

        init(_ daysAgo: Int, _ type: EntryType?, _ projectIndex: Int?, _ effort: Effort?, _ body: String, sensitive: Bool = false) {
            self.daysAgo = daysAgo
            self.type = type
            self.projectIndex = projectIndex
            self.effort = effort
            self.sensitive = sensitive
            self.body = body
        }
    }

    static func load(into context: ModelContext) {
        let cal = Calendar.current
        let now = Date()

        let projects: [Project] = [
            Project(name: "מיגרציית תשלומים", origin: .selfInitiated, startedAt: cal.date(byAdding: .month, value: -5, to: now)),
            Project(name: "טיקטים ותקלות", origin: .assigned),
            Project(name: "תפעול שוטף", origin: .assigned),
            Project(name: "מנטורינג לדנה", origin: .selfInitiated, startedAt: cal.date(byAdding: .month, value: -6, to: now)),
            Project(name: "קמפיין Q1", origin: .assigned, status: .done),
            Project(name: "בדיקת Kafka", origin: .selfInitiated, status: .done)
        ]
        projects[4].endedAt = cal.date(byAdding: .month, value: -4, to: now)
        projects[5].endedAt = cal.date(byAdding: .month, value: -5, to: now)
        projects.forEach { context.insert($0) }

        let seeds: [Seed] = [
            Seed(0, nil, nil, nil, "אחרי הסטנדאפ הבנתי שאף אחד לא באמת יודע מי אחראי על ה-retry logic."),
            Seed(1, nil, 1, nil, "עוד יום שרובו טיקטים. לא הספקתי לגעת במיגרציה בכלל."),
            Seed(2, .win, 0, .m, "סגרנו את המיגרציה של התשלומים אחרי שלושה שבועות. עשיתי rollback plan שאף אחד לא ביקש והוא הציל אותנו ב־2:00 בלילה."),
            Seed(4, .friction, 2, .s, "הבוס דחה את ההצעה לפצל את הצוות. אמר שזה \"לא הזמן\", בלי להסביר מה כן הזמן. יצאתי מזה מתוסכל יותר ממה שהודיתי.", sensitive: true),
            Seed(6, .learning, 0, .s, "הבנתי סוף סוף איך תמחור החוזים עובד אצלנו — זה לא לפי שימוש אלא לפי מדרגות שנקבעו ב-2019."),
            Seed(8, .decision, 0, .m, "בחרנו לא לעבור ל-Kafka השנה. ההנחה: הנפח לא יגדל פי 3. שווה לחזור לזה ברבעון הבא."),
            Seed(9, .people, 3, .s, "עזרתי לדנה להיכנס לקוד של הבילינג. שעתיים pairing, והיא סגרה את הבאג לבד למחרת."),
            Seed(11, .win, 1, .s, "צמצמתי את זמן ה-p95 של ה-checkout מ-1.9 שניות ל-1.1 בלי לשנות ארכיטקטורה."),
            Seed(12, .friction, 1, .l, "שלושה ימים על תקלת ייצור שהתבררה כקונפיג ידני שמישהו שינה לפני חודש ולא תיעד."),
            Seed(14, .learning, 2, .s, "קראתי על backpressure ולראשונה הבנתי למה התור שלנו מתפוצץ דווקא בשעות השקטות."),
            Seed(16, .win, 3, .s, "דנה הציגה את העבודה שלה בסקירת הצוות. חצי מהמסקנות שם היו מהסשנים שלנו."),
            Seed(18, .decision, 2, .m, "החלטנו להקפיא את הפיצ׳ר של ההתראות עד שיהיה מדד לכמה אנשים בכלל פותחים אותן."),
            Seed(20, .friction, nil, .m, "התראיינתי פנימית לתפקיד של tech lead ולא קיבלתי. הפידבק היה \"עוד לא מספיק visibility\", וזה בדיוק מה שאני מנסה לפתור.", sensitive: true),
            Seed(22, .people, 2, .s, "ישבתי עם צוות הדאטה על הסכמה החדשה. יצא שיתוף פעולה טוב שאף אחד לא תכנן."),
            Seed(24, .win, 0, .l, "כתבתי את מסמך העיצוב של המיגרציה. 11 עמודים, אושר בלי סבב שני."),
            Seed(26, .learning, 0, .m, "SwiftData לא אוהב predicates על יחסים אופציונליים. עברתי לסינון בזיכרון וזה פתר שלוש שעות של דיבוג."),
            Seed(28, .goal, nil, nil, "מטרת הרבעון: לקחת בעלות על תחום התשתית — שלושה מסמכי עיצוב שאני מוביל."),
            Seed(30, .friction, 1, .m, "שוב נקראתי לתקלה ב-23:00. זו הפעם הרביעית החודש ואף אחד לא סופר את זה."),
            Seed(33, .win, 2, .s, "העברתי את הריטיינר של הדוחות מסקריפט ידני ל-cron. חסך לי יום בחודש."),
            Seed(35, .decision, 1, .s, "בחרנו להשאיר את השירות הישן בחיים עוד רבעון. ההנחה: אף לקוח משמעותי לא תלוי בו."),
            Seed(37, .learning, 3, .s, "גיליתי שכשאני שואל \"מה ניסית\" במקום \"למה זה לא עובד\" דנה מגיעה לתשובה לבד."),
            Seed(40, .people, 0, .m, "עבדתי מול הפיננסים על ההתאמות. פעם ראשונה שמישהו משם מסביר לי איך הם באמת מודדים."),
            Seed(43, .win, 0, .m, "הרצתי את המיגרציה על סביבת staging עם נתוני אמת. אפס אי-התאמות."),
            Seed(46, .friction, 2, .s, "ישיבת התכנון נמשכה שעתיים וחצי והסתיימה בלי החלטה אחת. שלישית ברציפות."),
            Seed(49, .learning, 1, .s, "למדתי לקרוא flame graphs כמו שצריך. רוב הזמן שלנו הולך לסריאליזציה, לא ל-DB."),
            Seed(52, .win, 1, .s, "סגרתי 14 טיקטים בשבוע אחד כדי לנקות את התור לפני הרבעון."),
            Seed(55, .decision, 0, .l, "החלטנו לפצל את המיגרציה לשני שלבים. עלות: עוד חודש. תמורה: אפשרות rollback בכל רגע."),
            Seed(58, .people, 3, .s, "המלצתי על דנה לתפקיד בצוות הפלטפורמה. היא לא ידעה שזה בכלל אופציה."),
            Seed(61, .friction, nil, .m, "אמרתי בישיבה משהו שיצא חד מדי ומיכל נעלבה. התנצלתי אחר כך אבל זה עדיין מציק לי.", sensitive: true),
            Seed(64, .learning, 2, .s, "הבנתי שרוב ה\"דחיפויות\" שמגיעות אליי נולדות בצוות אחר שאין לו PM."),
            Seed(67, .win, 2, .m, "בניתי דשבורד שמראה מאיפה מגיעות הפניות. מאז יש על מה לדבר ב-1:1."),
            Seed(70, .goal, nil, nil, "מטרת הרבעון: פחות זמן בכיבוי שרפות — לא יותר מ-20% מהרשומות בתחום תפעול."),
            Seed(74, .decision, 2, .s, "בחרתי לא לקחת את הפרויקט של הדוחות. אין לי רוחב פס והוא היה נופל."),
            Seed(78, .win, 4, .m, "קמפיין Q1 יצא בזמן. הצד הטכני שלי לא היה הצוואר בקבוק אף פעם."),
            Seed(82, .learning, 5, .s, "הבדיקה של Kafka הוכיחה שהבעיה שלנו היא לא throughput אלא סדר הודעות."),
            Seed(86, .friction, 4, .m, "הקמפיין דרש שלושה שינויי scope בשבועיים. אף אחד לא עדכן את הלו\"ז."),
            Seed(90, .people, 4, .s, "עבדתי צמוד לשיווק לראשונה. הבנתי כמה מעט הם יודעים על מה שאנחנו בונים.")
        ]

        for seed in seeds {
            guard let date = cal.date(byAdding: .day, value: -seed.daysAgo, to: now) else { continue }
            let stamped = cal.date(
                bySettingHour: 9 + (seed.daysAgo % 9),
                minute: (seed.daysAgo * 7) % 60,
                second: 0,
                of: date
            ) ?? date

            let entry = Entry(body: seed.body, createdAt: stamped, type: seed.type)
            if let idx = seed.projectIndex { entry.project = projects[idx] }
            entry.effort = seed.effort
            entry.sensitivity = seed.sensitive ? .sensitive : .normal
            context.insert(entry)
        }

        try? context.save()
    }

    /// Wipes every entry and project. Used only to get back to a clean first
    /// run while testing — the app itself never deletes anything (spec §03.04).
    static func clearAll(context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        for entry in entries {
            entry.attachmentNames.forEach(AttachmentStore.delete)
            context.delete(entry)
        }
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        projects.forEach { context.delete($0) }
        try? context.save()
    }
}
