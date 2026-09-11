import SwiftUI

// MARK: - Color tokens
//
// The wireframes are deliberately greyscale; the binding palette is spec §05.
// Six low-saturation tints, one live accent, black ink and controls.

extension Color {
    init(rgb: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Palette {
    // Surfaces
    static let ground = Color(rgb: 0xF8F7F3)
    static let neutralTile = Color(rgb: 0xF1F0EC)
    static let card = Color.white

    // Ink
    static let ink = Color(rgb: 0x1A1A1A)
    static let ink2 = Color(rgb: 0x5A5A5A)
    static let muted = Color(rgb: 0x8C8C8C)
    static let meta = Color(rgb: 0xA6A6A6)

    // Lines
    static let line = Color(rgb: 0xDEDEDE)
    static let lineSoft = Color(rgb: 0xEDEDED)
    static let tileLine = Color(rgb: 0xE3E3E3)
    static let cardLine = Color(rgb: 0xE6E6E6)

    // Controls
    static let control = Color(rgb: 0x1A1A1A)
    static let controlOn = Color(rgb: 0x3A3A3A)

    // The one live accent — only for state that needs attention (spec §05.05)
    static let accent = Color(rgb: 0xC7FF32)

    // Entry-type tints
    static let win = Color(rgb: 0xE1F7DD)
    static let learning = Color(rgb: 0xDEF3FA)
    static let friction = Color(rgb: 0xFFE9E3)
    static let decision = Color(rgb: 0xEAE6FA)
    static let goal = Color(rgb: 0xFFF5C0)
    static let people = Color(rgb: 0xDCF4F1)
}

// MARK: - Metrics (spec §05, "צורה ותנועה")

enum Metrics {
    static let base: CGFloat = 8
    static let hMargin: CGFloat = 20
    static let tileGap: CGFloat = 12
    static let tileRadius: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let rowMinHeight: CGFloat = 56
    static let tapTarget: CGFloat = 44
    static let dockHeight: CGFloat = 52
}

enum Motion {
    /// One spring for the whole app.
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

// MARK: - Typography
//
// Hebrew headlines need gentler tracking than Latin (spec §05): ~-1.5%, not -3%.

extension Font {
    static func display(_ size: CGFloat) -> Font {
        .custom("SpaceGrotesk-Bold", fixedSize: size)
    }

    static func bodyText(_ size: CGFloat = 15.5, weight: Font.Weight = .regular) -> Font {
        let name: String
        if weight == .bold || weight == .heavy || weight == .black {
            name = "InstrumentSans-Bold"
        } else if weight == .semibold {
            name = "InstrumentSans-SemiBold"
        } else if weight == .medium {
            name = "InstrumentSans-Medium"
        } else {
            name = "InstrumentSans-Regular"
        }
        return .custom(name, fixedSize: size)
    }

    /// DM Mono for dates, counters and system labels.
    static func utility(_ size: CGFloat = 11) -> Font {
        .custom("DMMono-Medium", fixedSize: size)
    }
}

extension View {
    /// Display tracking calibrated for Hebrew.
    func displayTracking(_ size: CGFloat) -> some View {
        self.tracking(-0.015 * size)
    }
}

// MARK: - Hebrew formatting

enum Fmt {
    static let locale = Locale(identifier: "en_US")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate(format)
        return f
    }

    /// "29.8"
    static func dayDot(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: date)
        return "\(c.day ?? 0).\(c.month ?? 0)"
    }

    /// "אוגוסט 2026"
    static func monthYear(_ date: Date) -> String {
        formatter("yMMMM").string(from: date)
    }

    /// "29 באוגוסט 2026"
    static func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// "16:24"
    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// "היום · 16:24" / "אתמול · 09:10" / "22 ביולי · 14:02"
    static func stamp(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today · \(time(date))" }
        if cal.isDateInYesterday(date) { return "Yesterday · \(time(date))" }
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("dMMMM")
        return "\(f.string(from: date)) · \(time(date))"
    }

    static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// `weekday` uses Foundation's 1 = Sunday convention.
    static func weekday(_ weekday: Int) -> String {
        let idx = max(1, min(7, weekday)) - 1
        return weekdayNames[idx]
    }
}
