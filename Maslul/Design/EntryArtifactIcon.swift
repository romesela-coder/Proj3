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
    var needsAttention = false
    var size: CGFloat = 74

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                        .stroke(Palette.lineSoft, lineWidth: 1)
                }

            Image(systemName: artifact.symbol)
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
        .accessibilityLabel(artifact.accessibilityLabel)
        .accessibilityValue(needsAttention ? "Needs attention" : "")
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
