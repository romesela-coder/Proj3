import Foundation
import SwiftUI

/// Formatting is stored separately from `Entry.body` so search, export and
/// existing entries keep a stable plain-text representation. Ranges use UTF-16
/// offsets, matching TextKit and `NSRange`.
struct EntryRichTextDocument: Codable, Equatable {
    static let currentVersion = 2

    var version = currentVersion
    var inlineMarks: [InlineMark] = []
    var blocks: [Block] = []

    var isEmpty: Bool { inlineMarks.isEmpty && blocks.isEmpty }

    struct InlineMark: Codable, Equatable {
        enum Kind: String, Codable {
            case bold
            case italic
            case underline
            case fontSize
            case highlight
        }

        var location: Int
        var length: Int
        var kind: Kind
        var value: String? = nil
    }

    struct Block: Codable, Equatable {
        enum Kind: String, Codable {
            case bulletedList
            case numberedList
            case checklist
        }

        var location: Int
        var length: Int
        var kind: Kind
        var isChecked = false
    }
}

enum EntryRichTextCodec {
    static func decode(_ data: Data?) -> EntryRichTextDocument {
        guard let data,
              let document = try? JSONDecoder().decode(EntryRichTextDocument.self, from: data),
              document.version <= EntryRichTextDocument.currentVersion else {
            return EntryRichTextDocument()
        }
        return document
    }

    static func encode(_ document: EntryRichTextDocument) -> Data? {
        guard !document.isEmpty else { return nil }
        return try? JSONEncoder().encode(document)
    }

    /// The iOS 26 editor owns an `AttributedString` directly. The envelope
    /// distinguishes it from the version 1/2 range metadata already stored by
    /// development builds, which remains readable through the legacy fallback.
    private struct NativeEnvelope: Codable {
        static let currentVersion = 3

        var version = currentVersion
        var text: AttributedString
    }

    static func decodeAttributed(_ data: Data?, fallback body: String) -> AttributedString {
        if let data,
           let envelope = try? JSONDecoder().decode(NativeEnvelope.self, from: data),
           envelope.version <= NativeEnvelope.currentVersion,
           String(envelope.text.characters) == body {
            return envelope.text
        }

        var text = AttributedString(body)
        let legacy = decode(data)
        guard !legacy.isEmpty else { return text }
        applyLegacyMarks(legacy.inlineMarks, to: &text, body: body)
        return text
    }

    static func encodeAttributed(_ text: AttributedString) -> Data? {
        guard !text.characters.isEmpty else { return nil }
        return try? JSONEncoder().encode(NativeEnvelope(text: text))
    }

    private static func applyLegacyMarks(
        _ marks: [EntryRichTextDocument.InlineMark],
        to text: inout AttributedString,
        body: String
    ) {
        let sourceLength = (body as NSString).length
        var boundaries: Set<Int> = [0, sourceLength]
        for mark in marks {
            let start = min(max(0, mark.location), sourceLength)
            let end = min(max(start, mark.location + mark.length), sourceLength)
            boundaries.insert(start)
            boundaries.insert(end)
        }

        let sorted = boundaries.sorted()
        guard sorted.count > 1 else { return }
        for index in 0..<(sorted.count - 1) {
            let startOffset = sorted[index]
            let endOffset = sorted[index + 1]
            guard startOffset < endOffset,
                  let range = attributedRange(
                    location: startOffset,
                    length: endOffset - startOffset,
                    in: text,
                    body: body
                  ) else { continue }

            let active = marks.filter {
                $0.location <= startOffset && $0.location + $0.length >= endOffset
            }
            let size = active.first(where: { $0.kind == .fontSize })
                .flatMap(\.value)
                .flatMap(RichTextFontSize.init(rawValue:)) ?? .body
            var font = Font.system(size: 17 * size.scale)
            if active.contains(where: { $0.kind == .bold }) { font = font.bold() }
            if active.contains(where: { $0.kind == .italic }) { font = font.italic() }
            if active.contains(where: { $0.kind == .bold || $0.kind == .italic || $0.kind == .fontSize }) {
                text[range].font = font
            }
            if active.contains(where: { $0.kind == .underline }) {
                text[range].underlineStyle = .single
            }
            if let highlight = active.first(where: { $0.kind == .highlight })
                .flatMap(\.value)
                .flatMap(RichTextHighlightColor.init(rawValue:)) {
                text[range].backgroundColor = highlight.color
            }
        }
    }

    private static func attributedRange(
        location: Int,
        length: Int,
        in text: AttributedString,
        body: String
    ) -> Range<AttributedString.Index>? {
        guard location >= 0, length >= 0, location + length <= (body as NSString).length else {
            return nil
        }
        let stringStart = String.Index(utf16Offset: location, in: body)
        let stringEnd = String.Index(utf16Offset: location + length, in: body)
        guard let start = AttributedString.Index(stringStart, within: text),
              let end = AttributedString.Index(stringEnd, within: text) else { return nil }
        return start..<end
    }
}

enum EntryRichTextMarkdown {
    static func render(_ body: String, document: EntryRichTextDocument) -> String {
        guard !document.isEmpty, !body.isEmpty else { return body }
        let source = body as NSString
        var output = ""
        var cursor = 0
        var numberedItem = 0
        var previousNumberedEnd: Int?

        while cursor < source.length {
            let paragraphRange = source.paragraphRange(for: NSRange(location: cursor, length: 0))
            var contentRange = paragraphRange
            while contentRange.length > 0 {
                let last = source.substring(with: NSRange(location: NSMaxRange(contentRange) - 1, length: 1))
                guard last == "\n" || last == "\r" else { break }
                contentRange.length -= 1
            }

            let block = document.blocks.first {
                $0.location <= paragraphRange.location &&
                    $0.location + $0.length >= NSMaxRange(paragraphRange)
            }
            let prefix: String
            switch block?.kind {
            case .bulletedList:
                prefix = "- "
                numberedItem = 0
                previousNumberedEnd = nil
            case .numberedList:
                if previousNumberedEnd == paragraphRange.location {
                    numberedItem += 1
                } else {
                    numberedItem = 1
                }
                prefix = "\(numberedItem). "
                previousNumberedEnd = NSMaxRange(paragraphRange)
            case .checklist:
                prefix = block?.isChecked == true ? "- [x] " : "- [ ] "
                numberedItem = 0
                previousNumberedEnd = nil
            case nil:
                prefix = ""
                numberedItem = 0
                previousNumberedEnd = nil
            }

            output += prefix
            output += renderInline(source, range: contentRange, marks: document.inlineMarks)
            if contentRange.length < paragraphRange.length { output += "\n" }

            let next = NSMaxRange(paragraphRange)
            guard next > cursor else { break }
            cursor = next
        }
        return output
    }

    private static func renderInline(
        _ source: NSString,
        range: NSRange,
        marks: [EntryRichTextDocument.InlineMark]
    ) -> String {
        guard range.length > 0 else { return "" }
        var boundaries: Set<Int> = [range.location, NSMaxRange(range)]
        for mark in marks {
            let intersection = NSIntersectionRange(
                range,
                NSRange(location: mark.location, length: mark.length)
            )
            guard intersection.length > 0 else { continue }
            boundaries.insert(intersection.location)
            boundaries.insert(NSMaxRange(intersection))
        }

        let sorted = boundaries.sorted()
        var output = ""
        for index in 0..<(sorted.count - 1) {
            let segment = NSRange(location: sorted[index], length: sorted[index + 1] - sorted[index])
            guard segment.length > 0 else { continue }
            let active = marks.filter {
                $0.location <= segment.location && $0.location + $0.length >= NSMaxRange(segment)
            }
            let isBold = active.contains { $0.kind == .bold }
            let isItalic = active.contains { $0.kind == .italic }
            let isUnderlined = active.contains { $0.kind == .underline }
            let fontSize = active.first(where: { $0.kind == .fontSize })
                .flatMap(\.value)
                .flatMap(RichTextFontSize.init(rawValue:))
            let highlight = active.first(where: { $0.kind == .highlight })
                .flatMap(\.value)
                .flatMap(RichTextHighlightColor.init(rawValue:))
            let rawText = source.substring(with: segment)
            var text = isUnderlined ? "<u>\(rawText)</u>" : rawText
            if let highlight {
                text = "<mark style=\"background-color: \(highlight.cssColor)\">\(text)</mark>"
            }
            if let fontSize, fontSize != .body {
                text = "<span style=\"font-size: \(fontSize.scale)em\">\(text)</span>"
            }
            if isBold && isItalic {
                output += "***\(text)***"
            } else if isBold {
                output += "**\(text)**"
            } else if isItalic {
                output += "*\(text)*"
            } else {
                output += text
            }
        }
        return output
    }
}

enum RichTextFormatCommandKind: Equatable {
    case bold
    case italic
    case underline
    case fontSize(RichTextFontSize)
    case highlight(RichTextHighlightColor?)
    case bulletedList
    case numberedList
    case checklist
}

struct RichTextFormatCommand: Equatable {
    let id = UUID()
    let kind: RichTextFormatCommandKind
}

struct RichTextSelectionState: Equatable {
    var isBold = false
    var isItalic = false
    var isUnderlined = false
    var fontSize: RichTextFontSize = .body
    var highlightColor: RichTextHighlightColor?
    var block: EntryRichTextDocument.Block.Kind?
    var isChecklistChecked = false
}

enum RichTextFontSize: String, Codable, CaseIterable, Identifiable {
    case small
    case body
    case large
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .body: return "Body"
        case .large: return "Large"
        case .title: return "Title"
        }
    }

    var scale: Double {
        switch self {
        case .small: return 0.84
        case .body: return 1
        case .large: return 1.2
        case .title: return 1.45
        }
    }
}

enum RichTextHighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var cssColor: String {
        switch self {
        case .yellow: return "#FFD647"
        case .green: return "#89D67A"
        case .blue: return "#78BDF9"
        case .pink: return "#FA94B8"
        case .purple: return "#B897F2"
        }
    }
}
