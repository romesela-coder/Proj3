import SwiftUI

/// The journal's tangible visual language. The glyph names describe what
/// remains from an entry, while tags and text continue to carry its subject.
enum EntryArtifact {
    case ticket
    case foldedNote
    case flag
    case bookmark

    init(type: EntryType?) {
        switch type {
        case .decision: self = .flag
        case .goal: self = .bookmark
        case .learning, .friction: self = .foldedNote
        case .win, .people, .none: self = .ticket
        }
    }
}

/// A fixed icon container. Attention belongs to the tile, never to the glyph.
struct EntryIconTile: View {
    let artifact: EntryArtifact
    var needsAttention = false
    var size: CGFloat = 74

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                        .stroke(Palette.lineSoft, lineWidth: 1)
                }

            glyph
                .frame(width: size * 0.54, height: size * 0.54)

            if needsAttention {
                Circle()
                    .fill(Color(rgb: 0xC7FF32))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .offset(x: size * 0.03, y: -size * 0.03)
            }
        }
        .frame(width: size, height: size)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(artifact.accessibilityLabel)
    }

    @ViewBuilder
    private var glyph: some View {
        switch artifact {
        case .ticket: TicketGlyph()
        case .foldedNote: FoldedNoteGlyph()
        case .flag: FlagGlyph()
        case .bookmark: BookmarkGlyph()
        }
    }
}

private extension EntryArtifact {
    var accessibilityLabel: String {
        switch self {
        case .ticket: "Moment"
        case .foldedNote: "Thought"
        case .flag: "Decision"
        case .bookmark: "Return to this"
        }
    }
}

private struct TicketGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.18
        let r = rect.height * 0.20
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notch))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY + notch), control1: CGPoint(x: rect.maxX - notch, y: rect.midY - notch), control2: CGPoint(x: rect.maxX - notch, y: rect.midY + notch))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + notch))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY - notch), control1: CGPoint(x: rect.minX + notch, y: rect.midY + notch), control2: CGPoint(x: rect.minX + notch, y: rect.midY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}

private struct FoldedNoteGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let fold = rect.width * 0.29
        let r = rect.width * 0.16
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}

private struct FlagGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let pole = rect.width * 0.16
        var path = Path()
        path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: pole, height: rect.height), cornerSize: CGSize(width: pole / 2, height: pole / 2))
        path.move(to: CGPoint(x: rect.minX + pole * 0.75, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.08))
        path.addCurve(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.midY), control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28), control2: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY - rect.height * 0.10))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.08), control1: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY + rect.height * 0.10), control2: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.minX + pole * 0.75, y: rect.maxY - rect.height * 0.08))
        path.closeSubpath()
        return path
    }
}

private struct BookmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width * 0.13
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.27))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}
