import SwiftUI
import SwiftData

/// The reference layout, converted directly (spec §05):
/// the four tiles are the four common entry types, the rounded field is the
/// free question, and the black FAB is writing with no type at all.
struct HomeView: View {
    @Environment(Router.self) private var router
    @AppStorage(SettingsKey.userName) private var userName = ""

    @Query(sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    private var pendingCount: Int {
        entries.filter(\.needsTidy).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 16) {
                greeting
                tiles
                searchField
                footer
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .screenBackground()
        .withDock()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            CircleButton(symbol: "questionmark") {
                router.tab = .me
                router.mePath = [.privacy]
            }
            Spacer()
            CircleButton(symbol: "bell", badge: pendingCount) {
                router.journalPath = [.journal(.pending)]
            }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
    }

    private var greeting: some View {
        // The headline addresses the user in the second person. Not "my
        // journal", not a dashboard of numbers (spec §05.02).
        Text(userName.isEmpty ? "היי,\nמה קרה היום?" : "היי \(userName),\nמה קרה היום?")
            .font(.display(30))
            .displayTracking(30)
            .lineSpacing(2)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tiles: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Metrics.tileGap),
                GridItem(.flexible(), spacing: Metrics.tileGap)
            ],
            spacing: Metrics.tileGap
        ) {
            ForEach(EntryType.homeTiles) { type in
                TypeTile(type: type) { router.newEntry(type: type) }
            }
        }
    }

    private var searchField: some View {
        Button {
            router.journalPath = [.journal(.search)]
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Palette.muted)
                Text("חפש ביומן")
                    .font(.bodyText(15))
                    .foregroundStyle(Palette.muted)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var footer: some View {
        if entries.isEmpty {
            Text("היומן ריק. הרשומה הראשונה לוקחת עשר שניות.")
                .font(.bodyText(13))
                .foregroundStyle(Palette.meta)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        } else if pendingCount > 0 {
            Button {
                router.journalPath = [.journal(.pending)]
            } label: {
                Text("\(pendingCount) רשומות ממתינות לסידור")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.meta)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
        } else {
            Text("\(entries.count) רשומות ביומן")
                .font(.bodyText(12.5))
                .foregroundStyle(Palette.meta)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
