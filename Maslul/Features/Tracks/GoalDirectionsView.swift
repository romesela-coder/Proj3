import SwiftUI

/// The invitation stays visually separate from the capture bar. Once a
/// direction is chosen, its text moves into the composer itself.
struct EntryDirectionAccessory: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Need a direction?")
                        .font(.bodyText(13.5, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Explore ideas for your entry")
                        .font(.bodyText(11.5))
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(RoundedRectangle(cornerRadius: 15).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.cardLine))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .shadow(color: Palette.ink.opacity(0.08), radius: 12, y: 4)
    }
}

/// Short labels make the bank feel like browsable directions rather than a
/// second questionnaire. The full question is attached to the Entry as context.
private struct GoalDirectionOption: Identifiable {
    let prompt: TrackQuestion
    let label: String

    var id: String { prompt.id }
}

private enum GoalDirectionCatalog {
    static let suggested = options([
        ("check-in-no-progress", "Nothing moved"),
        ("progress-01", "What moved, even a little?"),
        ("decisions-01", "A decision I postponed"),
        ("people-10", "A conversation worth having")
    ])

    static let checkIn = options([
        ("progress-08", "I did it differently"),
        ("energy-10", "My capacity right now"),
        ("focus-03", "What matters this week?"),
        ("next-01", "My next move")
    ])

    static let untangle = options([
        ("obstacles-04", "What am I avoiding?"),
        ("decisions-03", "A tradeoff I'm making"),
        ("people-07", "Who could help?"),
        ("obstacles-01", "What feels stuck?")
    ])

    static let reflect = options([
        ("learning-06", "A pattern I notice"),
        ("perspective-04", "What changed since I started?"),
        ("next-09", "One small action"),
        ("energy-04", "A sustainable pace")
    ])

    private static func options(_ labels: [(String, String)]) -> [GoalDirectionOption] {
        labels.compactMap { pair in
            let (id, label) = pair
            guard let prompt = TrackQuestionBank.find(id) else { return nil }
            return GoalDirectionOption(prompt: prompt, label: label)
        }
    }
}

struct GoalDirectionsView: View {
    let choose: (TrackQuestion) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Find a direction")
                            .font(.display(27))
                            .displayTracking(27)
                            .foregroundStyle(Palette.ink)
                        Text("Tap one to add it as context to your entry.")
                            .font(.bodyText(14))
                            .foregroundStyle(Palette.ink2)
                    }

                    directionGroup("Start here", options: GoalDirectionCatalog.suggested)
                    directionGroup("Check in", options: GoalDirectionCatalog.checkIn)
                    directionGroup("Untangle something", options: GoalDirectionCatalog.untangle)
                    directionGroup("Look back / look ahead", options: GoalDirectionCatalog.reflect)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.hMargin)
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func directionGroup(_ title: String, options: [GoalDirectionOption]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: title)
            ChipFlow(spacing: 8, rowSpacing: 8) {
                ForEach(options) { option in
                    Button { choose(option.prompt) } label: {
                        Text(option.label)
                            .font(.bodyText(13.5, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .padding(.horizontal, 13)
                            .frame(maxWidth: 270, minHeight: 44, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Palette.neutralTile)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
