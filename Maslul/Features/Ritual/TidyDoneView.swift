import SwiftUI

struct TidyDoneView: View {
    let insight: WeeklyInsight
    let remainingPending: Int
    let onMore: () -> Void
    let onContinue: () -> Void
    let onClose: () -> Void
    let onResolve: (InsightQuestion, Bool) -> Void

    @State private var answered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Text(headline)
                .font(.display(30))
                .displayTracking(30)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            CardBox {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "השבוע")
                    Text(insight.summary)
                        .font(.bodyText(15.5))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if !insight.counts.isEmpty {
                        Divider().overlay(Palette.cardLine).padding(.top, 2)
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(insight.counts) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    SectionLabel(text: item.type.title)
                                    Text("\(item.count)")
                                        .font(.bodyText(16, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if let question = insight.question, !answered {
                questionCard(question)
            }

            Spacer(minLength: 0)

            if remainingPending > 0 {
                PrimaryButton(title: "סדר עוד \(min(remainingPending, 10))", isGhost: true, action: onMore)
            }

            PrimaryButton(title: "המשך להקצאת הזמן", action: onContinue)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
    }

    private var headline: String {
        switch insight.tidiedCount {
        case 0: return "אין רשומות\nממתינות."
        case 1: return "סודרה רשומה אחת."
        default: return "סודרו \(insight.tidiedCount) רשומות."
        }
    }

    private var header: some View {
        HStack {
            CircleButton(symbol: "xmark", action: onClose)
            Spacer()
            Text("סידור שבועי")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Chip(title: "סיום", action: onClose)
        }
    }

    /// The dashed card is the one place the app asks something back. It is
    /// derived from the data and it always offers a way out — there is no
    /// version of this that scolds.
    private func questionCard(_ question: InsightQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "שאלה אחת")

            Text(question.text)
                .font(.bodyText(17))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Chip(title: question.keepTitle) { answer(question, keep: true) }
                if let closeTitle = question.closeTitle {
                    Chip(title: closeTitle) { answer(question, keep: false) }
                }
                Chip(title: "אחר כך") {
                    withAnimation(Motion.spring) { answered = true }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Palette.ground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(Palette.line)
        )
    }

    private func answer(_ question: InsightQuestion, keep: Bool) {
        onResolve(question, keep)
        withAnimation(Motion.spring) { answered = true }
    }
}
