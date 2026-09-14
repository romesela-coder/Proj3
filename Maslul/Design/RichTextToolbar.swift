import SwiftUI

struct RichTextToolbar: View {
    let selectionState: RichTextSelectionState
    let perform: (RichTextFormatCommandKind) -> Void
    @State private var showsHighlightPicker = false

    var body: some View {
        HStack(spacing: 5) {
                fontSizeMenu
                formatButton(
                    symbol: "bold",
                    label: "Bold",
                    isOn: selectionState.isBold,
                    command: .bold
                )
                formatButton(
                    symbol: "italic",
                    label: "Italic",
                    isOn: selectionState.isItalic,
                    command: .italic
                )
                formatButton(
                    symbol: "underline",
                    label: "Underline",
                    isOn: selectionState.isUnderlined,
                    command: .underline
                )
                highlightMenu

                divider

                formatButton(
                    symbol: "list.bullet",
                    label: "Bulleted list",
                    isOn: selectionState.block == .bulletedList,
                    command: .bulletedList
                )
                formatButton(
                    symbol: "list.number",
                    label: "Numbered list",
                    isOn: selectionState.block == .numberedList,
                    command: .numberedList
                )
                formatButton(
                    symbol: "checklist",
                    label: "Checklist",
                    isOn: selectionState.block == .checklist,
                    command: .checklist
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var fontSizeMenu: some View {
        Menu {
            ForEach(RichTextFontSize.allCases) { option in
                Button {
                    perform(.fontSize(option))
                } label: {
                    HStack {
                        Text(option.label)
                        if selectionState.fontSize == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text("Aa")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selectionState.fontSize == .body ? Palette.ink2 : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(controlBackground(isOn: selectionState.fontSize != .body))
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Text size")
    }

    private var highlightMenu: some View {
        Button { showsHighlightPicker.toggle() } label: {
            Image(systemName: "highlighter")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(selectionState.highlightColor?.color ?? Palette.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(controlBackground(isOn: false))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Highlight color")
        .popover(isPresented: $showsHighlightPicker, arrowEdge: .bottom) {
            HStack(spacing: 12) {
                ForEach(RichTextHighlightColor.allCases) { option in
                    Button {
                        perform(.highlight(option))
                        showsHighlightPicker = false
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if selectionState.highlightColor == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                            .overlay(Circle().stroke(Palette.ink.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                }

                Button {
                    perform(.highlight(nil))
                    showsHighlightPicker = false
                } label: {
                    Circle()
                        .fill(Palette.neutralTile)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "eraser")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ink2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove highlight")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.lineSoft)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
    }

    private func formatButton(
        symbol: String,
        label: String,
        isOn: Bool,
        command: RichTextFormatCommandKind
    ) -> some View {
        Button { perform(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Palette.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(controlBackground(isOn: isOn))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func controlBackground(isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(isOn ? Palette.control : Palette.neutralTile)
    }
}

extension RichTextHighlightColor {
    var color: Color {
        switch self {
        case .yellow: return Color(red: 1.00, green: 0.84, blue: 0.28)
        case .green: return Color(red: 0.54, green: 0.84, blue: 0.48)
        case .blue: return Color(red: 0.47, green: 0.74, blue: 0.98)
        case .pink: return Color(red: 0.98, green: 0.58, blue: 0.72)
        case .purple: return Color(red: 0.72, green: 0.59, blue: 0.95)
        }
    }
}

/// A one-tap Maslul toolbar backed exclusively by the iOS 26
/// `AttributedString` selection APIs. It does not reach into TextKit or rebuild
/// the editor view.
struct NativeRichTextToolbar: View {
    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    var baseFontSize: CGFloat = 17

    @Environment(\.fontResolutionContext) private var fontResolutionContext

    var body: some View {
        RichTextToolbar(selectionState: selectionState, perform: apply)
    }

    private var selectionState: RichTextSelectionState {
        let attributes = selection.typingAttributes(in: text)
        let font = attributes.font ?? .system(size: baseFontSize)
        let resolved = font.resolve(in: fontResolutionContext)
        return RichTextSelectionState(
            isBold: resolved.isBold,
            isItalic: resolved.isItalic,
            isUnderlined: attributes.underlineStyle != nil,
            fontSize: RichTextFontSize.closest(to: resolved.pointSize, base: baseFontSize),
            highlightColor: RichTextHighlightColor.allCases.first {
                attributes.backgroundColor == $0.color
            },
            block: currentBlock.kind,
            isChecklistChecked: currentBlock.isChecked
        )
    }

    private func apply(_ command: RichTextFormatCommandKind) {
        let state = selectionState
        switch command {
        case .bold:
            text.transformAttributes(in: &selection) { attributes in
                attributes.font = (attributes.font ?? .system(size: baseFontSize))
                    .bold(!state.isBold)
            }
        case .italic:
            text.transformAttributes(in: &selection) { attributes in
                attributes.font = (attributes.font ?? .system(size: baseFontSize))
                    .italic(!state.isItalic)
            }
        case .underline:
            text.transformAttributes(in: &selection) { attributes in
                attributes.underlineStyle = state.isUnderlined ? nil : .single
            }
        case .fontSize(let size):
            text.transformAttributes(in: &selection) { attributes in
                attributes.font = (attributes.font ?? .system(size: baseFontSize))
                    .pointSize(baseFontSize * size.scale)
            }
        case .highlight(let color):
            text.transformAttributes(in: &selection) { attributes in
                attributes.backgroundColor = color?.color
            }
        case .bulletedList:
            toggleParagraphPrefix(kind: .bulletedList)
        case .numberedList:
            toggleParagraphPrefix(kind: .numberedList)
        case .checklist:
            toggleParagraphPrefix(kind: .checklist)
        }
    }

    private var currentBlock: (kind: EntryRichTextDocument.Block.Kind?, isChecked: Bool) {
        let body = String(text.characters)
        guard !body.isEmpty else { return (nil, false) }
        let source = body as NSString
        let selected = selectedNSRange(in: text)
        let location = min(selected.location, source.length)
        let paragraph = source.paragraphRange(for: NSRange(location: location, length: 0))
        let line = source.substring(with: paragraph)
        if line.hasPrefix("• ") { return (.bulletedList, false) }
        if numberedPrefixLength(in: line) > 0 { return (.numberedList, false) }
        if line.hasPrefix("○ ") { return (.checklist, false) }
        if line.hasPrefix("✓ ") { return (.checklist, true) }
        return (nil, false)
    }

    private func toggleParagraphPrefix(kind: EntryRichTextDocument.Block.Kind) {
        let body = String(text.characters)
        let source = body as NSString
        let paragraphs = selectedParagraphRanges(in: source)
        guard !paragraphs.isEmpty else { return }

        let allMatch = paragraphs.allSatisfy { range in
            prefixKind(in: source.substring(with: contentRange(for: range, source: source))) == kind
        }
        let singleChecklistState: (
            kind: EntryRichTextDocument.Block.Kind?,
            isChecked: Bool
        ) = paragraphs.count == 1 ? currentBlock : (nil, false)

        text.transform(updating: &selection) { value in
            for (reverseIndex, paragraph) in paragraphs.enumerated().reversed() {
                let latestBody = String(value.characters)
                let latestSource = latestBody as NSString
                let content = contentRange(for: paragraph, source: latestSource)
                let line = latestSource.substring(with: content)
                let oldPrefixLength = recognizedPrefixLength(in: line)

                let newPrefix: String
                if kind == .checklist, paragraphs.count == 1,
                   singleChecklistState.kind == .checklist {
                    newPrefix = singleChecklistState.isChecked ? "" : "✓ "
                } else if allMatch {
                    newPrefix = ""
                } else {
                    switch kind {
                    case .bulletedList: newPrefix = "• "
                    case .numberedList: newPrefix = "\(reverseIndex + 1). "
                    case .checklist: newPrefix = "○ "
                    }
                }

                let replacementRange = NSRange(location: content.location, length: oldPrefixLength)
                guard let attributedRange = attributedRange(replacementRange, in: value, body: latestBody) else {
                    continue
                }
                value.replaceSubrange(attributedRange, with: AttributedString(newPrefix))
            }
        }
    }

    private func selectedParagraphRanges(in source: NSString) -> [NSRange] {
        let selected = selectedNSRange(in: text)
        let safeLocation = min(selected.location, source.length)
        let safeLength = min(selected.length, source.length - safeLocation)
        let encompassing = source.paragraphRange(for: NSRange(location: safeLocation, length: safeLength))
        if encompassing.length == 0 { return [encompassing] }

        var ranges: [NSRange] = []
        var cursor = encompassing.location
        let end = NSMaxRange(encompassing)
        while cursor < end {
            let paragraph = source.paragraphRange(for: NSRange(location: cursor, length: 0))
            ranges.append(paragraph)
            let next = NSMaxRange(paragraph)
            guard next > cursor else { break }
            cursor = next
        }
        return ranges
    }

    private func selectedNSRange(in value: AttributedString) -> NSRange {
        switch selection.indices(in: value) {
        case .insertionPoint(let index):
            return NSRange(index..<index, in: value)
        case .ranges(let ranges):
            guard let first = ranges.ranges.first,
                  let last = ranges.ranges.last else { return NSRange(location: 0, length: 0) }
            return NSRange(first.lowerBound..<last.upperBound, in: value)
        }
    }

    private func contentRange(for paragraph: NSRange, source: NSString) -> NSRange {
        var result = paragraph
        while result.length > 0 {
            let final = source.substring(with: NSRange(location: NSMaxRange(result) - 1, length: 1))
            guard final == "\n" || final == "\r" else { break }
            result.length -= 1
        }
        return result
    }

    private func prefixKind(in line: String) -> EntryRichTextDocument.Block.Kind? {
        if line.hasPrefix("• ") { return .bulletedList }
        if numberedPrefixLength(in: line) > 0 { return .numberedList }
        if line.hasPrefix("○ ") || line.hasPrefix("✓ ") { return .checklist }
        return nil
    }

    private func recognizedPrefixLength(in line: String) -> Int {
        if line.hasPrefix("• ") || line.hasPrefix("○ ") || line.hasPrefix("✓ ") {
            return 2
        }
        return numberedPrefixLength(in: line)
    }

    private func numberedPrefixLength(in line: String) -> Int {
        let source = line as NSString
        var index = 0
        while index < source.length,
              CharacterSet.decimalDigits.contains(
                UnicodeScalar(source.character(at: index)) ?? UnicodeScalar(0)
              ) {
            index += 1
        }
        guard index > 0, index + 1 < source.length,
              source.substring(with: NSRange(location: index, length: 2)) == ". " else {
            return 0
        }
        return index + 2
    }

    private func attributedRange(
        _ range: NSRange,
        in value: AttributedString,
        body: String
    ) -> Range<AttributedString.Index>? {
        guard range.location >= 0, NSMaxRange(range) <= (body as NSString).length else { return nil }
        let stringStart = String.Index(utf16Offset: range.location, in: body)
        let stringEnd = String.Index(utf16Offset: NSMaxRange(range), in: body)
        guard let start = AttributedString.Index(stringStart, within: value),
              let end = AttributedString.Index(stringEnd, within: value) else { return nil }
        return start..<end
    }
}

private extension RichTextFontSize {
    static func closest(to pointSize: CGFloat, base: CGFloat) -> RichTextFontSize {
        allCases.min { lhs, rhs in
            abs(base * lhs.scale - pointSize) < abs(base * rhs.scale - pointSize)
        } ?? .body
    }
}
