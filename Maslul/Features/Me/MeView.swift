import SwiftUI
import SwiftData

struct MeView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderWeekday) private var reminderWeekday = Defaults.reminderWeekday
    @AppStorage(SettingsKey.reminderHour) private var reminderHour = Defaults.reminderHour
    @AppStorage(SettingsKey.reminderMinute) private var reminderMinute = Defaults.reminderMinute
    @AppStorage(SettingsKey.sampleDataLoaded) private var sampleDataLoaded = false

    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query private var projects: [Project]

    @State private var showClearConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                Text("אני")
                    .font(.display(30))
                    .displayTracking(30)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, 12)

                stats

                SectionLabel(text: "שליפה").padding(.top, 20).padding(.bottom, 2)

                Button { router.mePath.append(.export) } label: {
                    SettingRow(
                        symbol: "square.and.arrow.up",
                        title: "ייצוא נתונים",
                        subtitle: "Markdown · JSON"
                    )
                }
                .buttonStyle(.plain)

                Button { router.mePath.append(.roadmap) } label: {
                    SettingRow(
                        symbol: "doc.text.magnifyingglass",
                        title: "חבילת ריוויו",
                        subtitle: "בגרסה 0.2",
                        isEnabled: false
                    )
                }
                .buttonStyle(.plain)

                Button { router.mePath.append(.roadmap) } label: {
                    SettingRow(
                        symbol: "chart.bar",
                        title: "דוח הקצאת זמן",
                        subtitle: "בגרסה 0.2",
                        isEnabled: false
                    )
                }
                .buttonStyle(.plain)

                Button { router.mePath.append(.roadmap) } label: {
                    SettingRow(
                        symbol: "target",
                        title: "מטרות הרבעון",
                        subtitle: "בגרסה 0.2",
                        isEnabled: false
                    )
                }
                .buttonStyle(.plain)

                SectionLabel(text: "פרטיות").padding(.top, 20).padding(.bottom, 8)

                Button { router.mePath.append(.privacy) } label: {
                    CardBox {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 9) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 17, weight: .light))
                                    .foregroundStyle(Palette.ink)
                                Text("אין חשבון · אין שרת · אין אנליטיקס")
                                    .font(.bodyText(14.5))
                                    .foregroundStyle(Palette.ink)
                            }
                            Text("האפליקציה נבנתה בלי קוד רשת. שום דבר לא עוזב את המכשיר.")
                                .font(.bodyText(12.5))
                                .foregroundStyle(Palette.meta)
                        }
                    }
                }
                .buttonStyle(.plain)

                SectionLabel(text: "הגדרות").padding(.top, 20).padding(.bottom, 2)

                Button { router.mePath.append(.reminder) } label: {
                    SettingRow(
                        symbol: "bell",
                        title: "תזכורת שבועית",
                        subtitle: reminderEnabled
                            ? "\(Fmt.weekday(reminderWeekday)) · \(timeText)"
                            : "כבויה"
                    )
                }
                .buttonStyle(.plain)

                Button { router.mePath.append(.projects) } label: {
                    SettingRow(
                        symbol: "folder",
                        title: "פרויקטים",
                        subtitle: projectSubtitle
                    )
                }
                .buttonStyle(.plain)

                Button { router.mePath.append(.entryPoints) } label: {
                    SettingRow(
                        symbol: "square.grid.2x2",
                        title: "ווידג׳טים ונקודות כניסה",
                        subtitle: "מסך בית · נעילה · כפתור פעולה"
                    )
                }
                .buttonStyle(.plain)

                SettingRow(
                    symbol: "faceid",
                    title: "נעילה ב-Face ID",
                    subtitle: "בגרסה 1.0",
                    isEnabled: false
                ) {
                    EmptyView()
                }

                SectionLabel(text: "בדיקה").padding(.top, 20).padding(.bottom, 2)

                SettingRow(
                    symbol: "text.badge.plus",
                    title: "נתוני דוגמה",
                    subtitle: sampleDataLoaded ? "נטענו" : "כבוי — היומן ריק"
                ) {
                    Toggle("", isOn: Binding(
                        get: { sampleDataLoaded },
                        set: { newValue in
                            if newValue { loadSample() } else { showClearConfirm = true }
                        }
                    ))
                    .labelsHidden()
                    .tint(Palette.ink)
                }

                Text("מחיקת נתוני הדוגמה מוחקת את כל הרשומות והפרויקטים. האפליקציה עצמה לא מוחקת רשומות לעולם — זה כלי בדיקה בלבד.")
                    .font(.bodyText(12))
                    .foregroundStyle(Palette.meta)
                    .padding(.top, 10)
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .withDock()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("למחוק הכל?", isPresented: $showClearConfirm) {
            Button("מחק", role: .destructive) { clearAll() }
            Button("ביטול", role: .cancel) {}
        } message: {
            Text("כל הרשומות והפרויקטים יימחקו מהמכשיר. אין ביטול.")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            CircleButton(symbol: "questionmark") { router.mePath.append(.privacy) }
            Spacer()
            CircleButton(symbol: "square.and.arrow.up") { router.mePath.append(.export) }
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    /// The only measurement in the product. No telemetry — in an app with no
    /// network, the numbers come out of the data itself (spec §16).
    private var stats: some View {
        HStack(spacing: Metrics.tileGap) {
            statTile(value: "\(entries.count)", label: "רשומות")
            statTile(value: "\(entriesThisMonth)", label: "החודש")
            statTile(value: frictionShare, label: "חיכוך")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.display(24))
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.utility(10.5))
                .tracking(1.2)
                .foregroundStyle(Palette.meta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Palette.neutralTile)
        )
    }

    private var entriesThisMonth: Int {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }.count
    }

    /// Below 25% means only the flattering half is being written down, and the
    /// honesty mechanism isn't working (spec §16).
    private var frictionShare: String {
        let typed = entries.filter { $0.type != nil }
        guard !typed.isEmpty else { return "—" }
        let friction = typed.filter { $0.type == .friction }.count
        return "\(Int((Double(friction) / Double(typed.count) * 100).rounded()))%"
    }

    private var timeText: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }

    private var projectSubtitle: String {
        let active = projects.filter { $0.status == .active }.count
        let closed = projects.filter { $0.status == .done }.count
        if projects.isEmpty { return "אין עדיין פרויקטים" }
        return closed > 0 ? "\(active) פעילים · \(closed) סגורים" : "\(active) פעילים"
    }

    // MARK: - Actions

    private func loadSample() {
        guard entries.isEmpty, projects.isEmpty else {
            sampleDataLoaded = true
            return
        }
        SampleData.load(into: context)
        sampleDataLoaded = true
    }

    private func clearAll() {
        SampleData.clearAll(context: context)
        sampleDataLoaded = false
    }
}
