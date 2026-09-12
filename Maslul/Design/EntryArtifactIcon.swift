import SwiftUI

/// A semantic icon for every entry type. The symbol must be understandable
/// without a legend; the surrounding tile is the shared visual language.
enum EntryArtifact {
    case win
    case learning
    case friction
    case decision
    case goal
    case people
    case note

    init(type: EntryType?) {
        switch type {
        case .win: self = .win
        case .learning: self = .learning
        case .friction: self = .friction
        case .decision: self = .decision
        case .goal: self = .goal
        case .people: self = .people
        case .none: self = .note
        }
    }
}

/// One fixed container throughout the product. `needsAttention` belongs to
/// the tile itself, so its lime dot is always in the same top-right corner.
struct EntryIconTile: View {
    let artifact: EntryArtifact
    var customSymbol: String? = nil
    var needsAttention = false
    var size: CGFloat = 74

    private var symbol: String {
        customSymbol ?? artifact.symbol
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                        .stroke(Palette.lineSoft, lineWidth: 1)
                }

            Image(systemName: symbol)
                .font(.system(size: size * artifact.symbolScale, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Palette.ink)
                .frame(width: size, height: size)

            if needsAttention {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .overlay(Circle().stroke(Color.white, lineWidth: max(1.5, size * 0.035)))
                    .offset(x: size * 0.045, y: -size * 0.045)
            }
        }
        .frame(width: size, height: size)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(customSymbol == nil ? artifact.accessibilityLabel : "Custom entry icon")
        .accessibilityValue(needsAttention ? "Needs attention" : "")
    }
}

enum EntryIconChoice: String, CaseIterable, Identifiable {
    case note
    case spark
    case win
    case learning
    case warning
    case decision
    case goal
    case people
    case work
    case project
    case build
    case done
    case chart
    case calendar
    case bookmark
    case favorite

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .note: "note.text"
        case .spark: "sparkles"
        case .win: "trophy.fill"
        case .learning: "lightbulb.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .decision: "signpost.right.and.left.fill"
        case .goal: "scope"
        case .people: "person.2.fill"
        case .work: "briefcase.fill"
        case .project: "folder.fill"
        case .build: "hammer.fill"
        case .done: "checkmark.circle.fill"
        case .chart: "chart.bar.fill"
        case .calendar: "calendar"
        case .bookmark: "bookmark.fill"
        case .favorite: "heart.fill"
        }
    }

    var title: String {
        switch self {
        case .note: "Note"
        case .spark: "Highlight"
        case .win: "Win"
        case .learning: "Learning"
        case .warning: "Friction"
        case .decision: "Decision"
        case .goal: "Goal"
        case .people: "People"
        case .work: "Work"
        case .project: "Project"
        case .build: "Build"
        case .done: "Done"
        case .chart: "Progress"
        case .calendar: "Date"
        case .bookmark: "Saved"
        case .favorite: "Favorite"
        }
    }
}

struct EntryIconPicker: View {
    @Binding var selectedSymbol: String?
    let automaticArtifact: EntryArtifact

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 4
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("ENTRY ICON")
                    .font(.utility(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Palette.meta)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.bodyText(14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                iconButton(
                    symbol: automaticArtifact.symbol,
                    title: "Automatic",
                    isSelected: selectedSymbol == nil
                ) {
                    selectedSymbol = nil
                }

                ForEach(EntryIconChoice.allCases) { choice in
                    iconButton(
                        symbol: choice.symbol,
                        title: choice.title,
                        isSelected: selectedSymbol == choice.symbol
                    ) {
                        selectedSymbol = choice.symbol
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
        .presentationDetents([.height(410)])
        .presentationDragIndicator(.visible)
    }

    private func iconButton(
        symbol: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? Palette.tagLemon : Color.white)
                    .frame(height: 54)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(isSelected ? Palette.ink.opacity(0.12) : Palette.lineSoft, lineWidth: 1)
                    )

                Text(title)
                    .font(.bodyText(10.5, weight: .medium))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension EntryArtifact {
    var symbol: String {
        switch self {
        case .win: "trophy.fill"
        case .learning: "lightbulb.fill"
        case .friction: "exclamationmark.triangle.fill"
        case .decision: "signpost.right.and.left.fill"
        case .goal: "scope"
        case .people: "person.2.fill"
        case .note: "note.text"
        }
    }

    var symbolScale: CGFloat {
        switch self {
        case .people, .decision: 0.34
        case .friction: 0.35
        default: 0.38
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .win: "Win"
        case .learning: "Learning"
        case .friction: "Friction"
        case .decision: "Decision"
        case .goal: "Goal"
        case .people: "People"
        case .note: "Note"
        }
    }
}
