import SwiftUI
import UIKit

// MARK: - Circle button (header controls)

struct CircleButton: View {
    let symbol: String
    var badge: Int = 0
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(Palette.neutralTile)
                    .overlay(Circle().stroke(Palette.tileLine, lineWidth: 1))
                    .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 19, weight: .light))
                            .foregroundStyle(Palette.muted)
                    )

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 21, minHeight: 21)
                        .background(Capsule().fill(Palette.accent))
                        .offset(x: -3, y: -3)
                }
            }
            .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entry type tile (home screen)

struct TypeTile: View {
    let type: EntryType
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Palette.tileLine, lineWidth: 1))
                    Image(systemName: type.symbol)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 40, height: 40)

                Spacer(minLength: 12)

                Text(type.latin)
                    .font(.utility(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                Text(type.title)
                    .font(.bodyText(16.5, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .fill(type.tint)
            )
        }
        .buttonStyle(TilePressStyle())
    }
}

private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
    }
}

// MARK: - Chip

struct Chip: View {
    let title: String
    var isOn: Bool = false
    var isSquare: Bool = false
    var tint: Color? = nil
    var isAIWorking: Bool = false
    var action: (() -> Void)? = nil

    private var shape: AnyShape {
        isSquare
            ? AnyShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            : AnyShape(Capsule())
    }

    @ViewBuilder
    private var label: some View {
        HStack(spacing: 6) {
            if isAIWorking {
                AIActivityGlyph(size: 13)
            }
            Text(title)
                .lineLimit(1)
        }
            .font(.bodyText(13.5, weight: isOn ? .semibold : .regular))
            .foregroundStyle(isOn ? Color.white : (isAIWorking ? AIVisual.violet : Palette.ink2))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(shape.fill(isOn ? Palette.control : (isAIWorking ? AIVisual.wash : (tint ?? Color.white))))
            .overlay(shape.stroke(isOn ? Palette.control : (isAIWorking ? AIVisual.violet.opacity(0.35) : Palette.line), lineWidth: 1))
    }

    var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}

// MARK: - Local AI activity

enum AIVisual {
    static let violet = Color(rgb: 0x7756E8)
    static let electric = Color(rgb: 0xB35CFF)
    static let wash = Color(rgb: 0xF5F0FF)
}

/// A quiet, inline acknowledgement that the on-device model is working.
/// It intentionally avoids a modal spinner: the user can keep writing while
/// the shimmer and changing verb explain what will update next.
struct AIActivityIndicator: View {
    let messages: [String]
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messageIndex = 0
    @State private var shimmerIsForward = false

    private var message: String {
        messages.isEmpty ? "Working" : messages[messageIndex % messages.count]
    }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            AIActivityGlyph(size: compact ? 12 : 14)
            Text(message)
                .id(message)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .font(.bodyText(compact ? 11.5 : 12.5, weight: .semibold))
        .foregroundStyle(
            LinearGradient(
                colors: [AIVisual.violet, AIVisual.electric, AIVisual.violet],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.horizontal, compact ? 9 : 11)
        .frame(minHeight: compact ? 28 : 32)
        .background(Capsule().fill(AIVisual.wash))
        .overlay(Capsule().stroke(AIVisual.violet.opacity(0.22), lineWidth: 1))
        .overlay {
            if !reduceMotion {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.8), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(28, proxy.size.width * 0.36))
                        .offset(x: shimmerIsForward ? proxy.size.width : -proxy.size.width * 0.45)
                }
                .clipShape(Capsule())
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                shimmerIsForward = true
            }
        }
        .task(id: messages) {
            guard !reduceMotion, messages.count > 1 else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(720))
                } catch {
                    return
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI is \(message.lowercased())")
    }
}

struct AIActivityGlyph: View {
    var size: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBright = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [AIVisual.violet, AIVisual.electric],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(isBright ? 1.08 : 0.92)
            .opacity(isBright ? 1 : 0.65)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    isBright = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Natural chip wrapping

/// Unlike an adaptive grid, each chip keeps the width its label needs. This is
/// used for metadata and filters, where a deliberate, editorial flow is more
/// readable than equal-width columns.
struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > width {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            x += size.width + (x > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if point.x > bounds.minX, point.x + spacing + size.width > bounds.maxX {
                point.x = bounds.minX
                point.y += rowHeight + rowSpacing
                rowHeight = 0
            }
            view.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Card

struct CardBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .stroke(Palette.cardLine, lineWidth: 1)
            )
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.utility(10.5))
            .tracking(1.4)
            .foregroundStyle(Palette.meta)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings-style row

struct SettingRow<Trailing: View>: View {
    let symbol: String?
    let title: String
    var subtitle: String? = nil
    var isEnabled: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyText(15.5))
                    .foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.bodyText(12.5))
                        .foregroundStyle(Palette.meta)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 15)
        .frame(minHeight: Metrics.rowMinHeight)
        .opacity(isEnabled ? 1 : 0.45)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.lineSoft).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

extension SettingRow where Trailing == Chevron {
    init(symbol: String?, title: String, subtitle: String? = nil, isEnabled: Bool = true) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, isEnabled: isEnabled) {
            Chevron()
        }
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.meta)
    }
}

// MARK: - Primary pill button

struct PrimaryButton: View {
    let title: String
    var isGhost: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(isGhost ? Palette.ink : Color.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(isGhost ? Color.white : Palette.control))
                .overlay(Capsule().stroke(isGhost ? Palette.line : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
    }
}

// MARK: - Share sheet
//
// The app never sends anything anywhere itself; it hands a file to the system.

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
