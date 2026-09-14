import SwiftUI
import UIKit
import SwiftData

enum InlineMentionAppearance {
    case standard
    case compact

    var fontSize: CGFloat {
        switch self {
        case .standard: TagMentionVisual.fontSize
        case .compact: 10
        }
    }

    var height: CGFloat {
        switch self {
        case .standard: TagMentionVisual.height
        case .compact: 18
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .standard: TagMentionVisual.horizontalPadding
        case .compact: 5
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .standard: TagMentionVisual.cornerRadius
        case .compact: 5
        }
    }

    var emojiFontSize: CGFloat {
        switch self {
        case .standard: 12
        case .compact: 9
        }
    }

    var iconGap: CGFloat {
        switch self {
        case .standard: 6
        case .compact: 3
        }
    }
}

struct InlineMentionEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var tags: [EntryTag]
    let placeholder: String
    var fontSize: CGFloat = 18
    var textColor: Color = Palette.ink
    var scrolls = false
    var autoFocus = false
    var isEditable = true
    var maximumNumberOfLines = 0
    var mentionAppearance: InlineMentionAppearance = .standard
    var selection: Binding<NSRange>? = nil
    var richText: Binding<EntryRichTextDocument>? = nil
    var formatCommand: RichTextFormatCommand? = nil
    var onFocus: (() -> Void)? = nil
    var onSelectionFormattingChange: ((RichTextSelectionState) -> Void)? = nil
    var onInputLanguageChange: ((String?) -> Void)? = nil
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        // TextKit 2 renders semantic NSTextList markers without inserting
        // bullets or checkbox glyphs into the canonical plain body.
        let view = richText == nil ? UITextView() : UITextView(usingTextLayoutManager: true)
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.font = .systemFont(ofSize: fontSize)
        view.textColor = UIColor(textColor)
        view.isScrollEnabled = scrolls
        view.isEditable = isEditable
        view.isSelectable = isEditable
        view.isUserInteractionEnabled = isEditable
        view.keyboardDismissMode = scrolls ? .interactive : .none
        view.textContainer.maximumNumberOfLines = maximumNumberOfLines
        view.textContainer.lineBreakMode = maximumNumberOfLines > 0 ? .byTruncatingTail : .byWordWrapping
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if isEditable {
            context.coordinator.observeInputLanguage(of: view)
            let checklistTap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleChecklistTap(_:))
            )
            checklistTap.cancelsTouchesInView = false
            view.addGestureRecognizer(checklistTap)
        }

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = .systemFont(ofSize: fontSize)
        placeholderLabel.textColor = UIColor(Palette.meta)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.tag = Coordinator.placeholderTag
        view.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: view.topAnchor)
        ])

        context.coordinator.render(in: view, plainText: text, tags: tags)
        context.coordinator.reportContentHeight(of: view)
        placeholderLabel.isHidden = !text.isEmpty
        if autoFocus, isEditable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { view.becomeFirstResponder() }
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        view.textColor = UIColor(textColor)
        view.isScrollEnabled = scrolls
        view.isEditable = isEditable
        view.isSelectable = isEditable
        view.isUserInteractionEnabled = isEditable
        view.keyboardDismissMode = scrolls ? .interactive : .none
        view.textContainer.maximumNumberOfLines = maximumNumberOfLines
        view.textContainer.lineBreakMode = maximumNumberOfLines > 0 ? .byTruncatingTail : .byWordWrapping
        let renderedPlainText = context.coordinator.plainText(from: view.attributedText)
        if renderedPlainText != text ||
            context.coordinator.renderedTagIDs != tags.map(\.persistentModelID) {
            if renderedPlainText != text, let document = richText?.wrappedValue {
                richText?.wrappedValue = context.coordinator.adjusted(
                    document: document,
                    from: renderedPlainText,
                    to: text
                )
            }
            context.coordinator.render(in: view, plainText: text, tags: tags)
        }
        context.coordinator.applyRequestedSelection(to: view)
        context.coordinator.applyFormatCommandIfNeeded(to: view)
        context.coordinator.reportContentHeight(of: view)
        (view.viewWithTag(Coordinator.placeholderTag) as? UILabel)?.isHidden = !text.isEmpty
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        static let placeholderTag = 7_411
        var parent: InlineMentionEditor
        var isRendering = false
        var renderedTagIDs: [PersistentIdentifier] = []
        private var handledFormatCommandID: UUID?
        private var inputModeObserver: NSObjectProtocol?

        init(_ parent: InlineMentionEditor) { self.parent = parent }

        deinit {
            if let inputModeObserver {
                NotificationCenter.default.removeObserver(inputModeObserver)
            }
        }

        func observeInputLanguage(of view: UITextView) {
            parent.onInputLanguageChange?(view.textInputMode?.primaryLanguage)
            inputModeObserver = NotificationCenter.default.addObserver(
                forName: UITextInputMode.currentInputModeDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self, weak view] _ in
                guard let self, let view else { return }
                self.parent.onInputLanguageChange?(view.textInputMode?.primaryLanguage)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isRendering else { return }
            parent.text = plainText(from: textView.attributedText)
            persistFormatting(from: textView)
            parent.selection?.wrappedValue = textView.selectedRange
            reportSelectionFormatting(of: textView)
            reportContentHeight(of: textView)
            (textView.viewWithTag(Self.placeholderTag) as? UILabel)?.isHidden = !parent.text.isEmpty
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            applyRequestedSelection(to: textView)
            parent.onFocus?()
            parent.onInputLanguageChange?(textView.textInputMode?.primaryLanguage)
            reportSelectionFormatting(of: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isRendering else { return }
            parent.selection?.wrappedValue = textView.selectedRange
            reportSelectionFormatting(of: textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText: String
        ) -> Bool {
            if replacementText == "\n",
               continueChecklistIfNeeded(replacing: range, in: textView) {
                return false
            }

            if replacementText.isEmpty,
               range.length > 0,
               range.location < textView.attributedText.length,
               textView.attributedText.attribute(
                   .attachment,
                   at: range.location,
                   effectiveRange: nil
               ) is BlockPresentationAttachment {
                removeBlockMarker(containing: range.location, in: textView)
                return false
            }

            guard replacementText.isEmpty,
                  range.length > 0,
                  range.location < textView.attributedText.length,
                  let attachment = textView.attributedText.attribute(
                    .attachment,
                    at: range.location,
                    effectiveRange: nil
                  ) as? MentionAttachment else { return true }

            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            let plainName = String(attachment.token.dropFirst())
            var inherited = textView.attributedText.attributes(at: range.location, effectiveRange: nil)
            inherited.removeValue(forKey: .attachment)
            inherited[.font] = styledFont(from: inherited, fontSize: parent.fontSize)
            mutable.replaceCharacters(
                in: range,
                with: NSAttributedString(
                    string: plainName,
                    attributes: baseAttributes(fontSize: parent.fontSize).merging(inherited) { _, inherited in inherited }
                )
            )
            textView.attributedText = mutable
            textView.typingAttributes = baseAttributes(fontSize: parent.fontSize)
            textView.selectedRange = NSRange(location: range.location + (plainName as NSString).length, length: 0)
            parent.selection?.wrappedValue = textView.selectedRange
            parent.tags.removeAll { $0.persistentModelID == attachment.tagID }
            parent.text = plainText(from: mutable)
            persistFormatting(from: textView)
            renderedTagIDs = parent.tags.map(\.persistentModelID)
            return false
        }

        private func continueChecklistIfNeeded(
            replacing range: NSRange,
            in view: UITextView
        ) -> Bool {
            guard view.attributedText.length > 0 else { return false }
            let string = view.attributedText.string as NSString
            let caret = min(max(0, range.location), string.length)
            let paragraphRange = string.paragraphRange(for: NSRange(location: caret, length: 0))
            guard paragraphRange.length > 0,
                  blockKind(at: paragraphRange.location, in: view.attributedText) == .checklist else {
                return false
            }

            let paragraph = view.attributedText.attributedSubstring(from: paragraphRange)
            let isEmptyItem = plainText(from: paragraph)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            if isEmptyItem {
                var markerRange: NSRange?
                view.attributedText.enumerateAttribute(.attachment, in: paragraphRange) { value, found, stop in
                    if value is ChecklistAttachment {
                        markerRange = found
                        stop.pointee = true
                    }
                }
                if let markerRange { view.textStorage.deleteCharacters(in: markerRange) }
                let remaining = NSRange(
                    location: paragraphRange.location,
                    length: max(0, paragraphRange.length - (markerRange?.length ?? 0))
                )
                if remaining.length > 0 {
                    view.textStorage.removeAttribute(.maslulBlock, range: remaining)
                    view.textStorage.removeAttribute(.maslulChecklistChecked, range: remaining)
                    view.textStorage.removeAttribute(.paragraphStyle, range: remaining)
                    view.textStorage.removeAttribute(.strikethroughStyle, range: remaining)
                }
                view.typingAttributes = baseAttributes(fontSize: parent.fontSize)
                view.selectedRange = NSRange(location: paragraphRange.location, length: 0)
            } else {
                var typing = view.typingAttributes
                typing.removeValue(forKey: .attachment)
                typing.removeValue(forKey: .strikethroughStyle)
                typing[.foregroundColor] = UIColor(parent.textColor)
                typing[.maslulBlock] = EntryRichTextDocument.Block.Kind.checklist.rawValue
                typing[.maslulChecklistChecked] = false
                typing[.paragraphStyle] = paragraphStyle(for: .checklist, list: nil)

                let insertion = NSMutableAttributedString(string: "\n", attributes: typing)
                let marker = NSMutableAttributedString(
                    attachment: ChecklistAttachment(isChecked: false, fontSize: parent.fontSize)
                )
                marker.addAttributes(typing, range: NSRange(location: 0, length: 1))
                insertion.append(marker)
                view.textStorage.replaceCharacters(in: range, with: insertion)
                view.selectedRange = NSRange(location: range.location + insertion.length, length: 0)
                view.typingAttributes = typing
            }

            parent.text = plainText(from: view.attributedText)
            persistFormatting(from: view)
            parent.selection?.wrappedValue = view.selectedRange
            reportSelectionFormatting(of: view)
            reportContentHeight(of: view)
            return true
        }

        func render(in view: UITextView, plainText: String, tags: [EntryTag]) {
            isRendering = true
            defer { isRendering = false }

            let result = NSMutableAttributedString(
                string: plainText,
                attributes: baseAttributes(fontSize: parent.fontSize)
            )
            apply(document: parent.richText?.wrappedValue ?? EntryRichTextDocument(), to: result)

            struct Match { let range: NSRange; let tag: EntryTag }
            var matches: [Match] = []
            var occupied = IndexSet()
            let source = plainText as NSString
            for tag in tags.sorted(by: { $0.name.count > $1.name.count }) {
                guard TagNameRules.isValid(tag.name) else { continue }
                let token = "@\(tag.name)"
                var search = NSRange(location: 0, length: source.length)
                while search.length > 0 {
                    let found = source.range(of: token, options: [.caseInsensitive], range: search)
                    guard found.location != NSNotFound else { break }
                    let foundIndexes = IndexSet(integersIn: found.location..<(found.location + found.length))
                    let end = found.location + found.length
                    let hasValidBoundary = end == source.length || {
                        let next = source.substring(with: NSRange(location: end, length: 1))
                        return next.first?.isWhitespace == true || next.first?.isNewline == true
                    }()
                    if hasValidBoundary && occupied.intersection(foundIndexes).isEmpty {
                        matches.append(Match(range: found, tag: tag))
                        occupied.formUnion(foundIndexes)
                    }
                    let next = found.location + found.length
                    search = NSRange(location: next, length: source.length - next)
                }
            }

            for match in matches.sorted(by: { $0.range.location > $1.range.location }) {
                let attachment = MentionAttachment(
                    tag: match.tag,
                    fontSize: parent.fontSize,
                    appearance: parent.mentionAppearance
                )
                let replacement = NSMutableAttributedString(attachment: attachment)
                if match.range.location < result.length {
                    let inherited = result.attributes(at: match.range.location, effectiveRange: nil)
                    for (key, value) in inherited where key != .font {
                        replacement.addAttribute(key, value: value, range: NSRange(location: 0, length: 1))
                    }
                }
                result.replaceCharacters(in: match.range, with: replacement)
            }
            insertBlockAttachments(
                from: parent.richText?.wrappedValue ?? EntryRichTextDocument(),
                into: result
            )

            let wasFirstResponder = view.isFirstResponder
            let requestedSelection = parent.selection?.wrappedValue
                ?? (wasFirstResponder ? view.selectedRange : NSRange(location: result.length, length: 0))
            view.attributedText = result
            view.typingAttributes = baseAttributes(fontSize: parent.fontSize)
            if parent.isEditable {
                view.selectedRange = clamped(requestedSelection, to: result.length)
                view.typingAttributes = typingAttributes(for: view.selectedRange, in: result)
                applyTrailingBlockTypingAttributesIfNeeded(
                    document: parent.richText?.wrappedValue ?? EntryRichTextDocument(),
                    plainTextLength: (plainText as NSString).length,
                    to: view
                )
                parent.selection?.wrappedValue = view.selectedRange
            }
            if view.isScrollEnabled, result.length > 0 {
                view.scrollRangeToVisible(NSRange(location: result.length - 1, length: 1))
            }
            renderedTagIDs = tags.map(\.persistentModelID)
            if wasFirstResponder { view.becomeFirstResponder() }
            reportSelectionFormatting(of: view)
            reportContentHeight(of: view)
        }

        func applyRequestedSelection(to view: UITextView) {
            guard parent.isEditable, let requested = parent.selection?.wrappedValue else { return }
            let next = clamped(requested, to: view.attributedText.length)
            guard view.selectedRange != next else { return }
            view.selectedRange = next
        }

        func applyFormatCommandIfNeeded(to view: UITextView) {
            guard parent.isEditable,
                  let command = parent.formatCommand,
                  handledFormatCommandID != command.id else { return }
            handledFormatCommandID = command.id

            var shouldRebuildBlockMarkers = false
            switch command.kind {
            case .bold:
                toggleInlineAttribute(.maslulBold, in: view)
            case .italic:
                toggleInlineAttribute(.maslulItalic, in: view)
            case .underline:
                toggleInlineAttribute(.maslulUnderline, in: view)
            case .fontSize(let size):
                applyValueAttribute(
                    .maslulFontSize,
                    value: size == .body ? nil : size.rawValue,
                    in: view
                )
            case .highlight(let color):
                applyValueAttribute(.maslulHighlight, value: color?.rawValue, in: view)
            case .bulletedList:
                shouldRebuildBlockMarkers = toggleBlock(.bulletedList, in: view)
            case .numberedList:
                shouldRebuildBlockMarkers = toggleBlock(.numberedList, in: view)
            case .checklist:
                shouldRebuildBlockMarkers = toggleBlock(.checklist, in: view)
            }

            persistFormatting(from: view)
            if shouldRebuildBlockMarkers {
                rebuildRenderedTextPreservingSelection(in: view)
            }
            parent.selection?.wrappedValue = view.selectedRange
            reportSelectionFormatting(of: view)
            reportContentHeight(of: view)
        }

        func adjusted(
            document: EntryRichTextDocument,
            from oldText: String,
            to newText: String
        ) -> EntryRichTextDocument {
            let oldUnits = Array(oldText.utf16)
            let newUnits = Array(newText.utf16)
            var prefix = 0
            while prefix < oldUnits.count,
                  prefix < newUnits.count,
                  oldUnits[prefix] == newUnits[prefix] {
                prefix += 1
            }

            var suffix = 0
            while suffix < oldUnits.count - prefix,
                  suffix < newUnits.count - prefix,
                  oldUnits[oldUnits.count - suffix - 1] == newUnits[newUnits.count - suffix - 1] {
                suffix += 1
            }

            let oldEditEnd = oldUnits.count - suffix
            let insertedLength = newUnits.count - prefix - suffix
            let delta = newUnits.count - oldUnits.count

            func transformed(location: Int, length: Int, allowsEmpty: Bool = false) -> NSRange? {
                let oldLower = location
                let oldUpper = location + length

                let lower: Int
                if oldLower <= prefix {
                    lower = oldLower
                } else if oldLower >= oldEditEnd {
                    lower = oldLower + delta
                } else {
                    lower = prefix
                }

                let upper: Int
                if oldUpper <= prefix {
                    upper = oldUpper
                } else if oldUpper >= oldEditEnd {
                    upper = oldUpper + delta
                } else {
                    upper = prefix + insertedLength
                }

                let safeLower = min(max(0, lower), newUnits.count)
                let safeUpper = min(max(safeLower, upper), newUnits.count)
                guard safeUpper > safeLower || allowsEmpty else { return nil }
                return NSRange(location: safeLower, length: safeUpper - safeLower)
            }

            var result = EntryRichTextDocument()
            result.inlineMarks = document.inlineMarks.compactMap { mark in
                transformed(location: mark.location, length: mark.length).map {
                    .init(
                        location: $0.location,
                        length: $0.length,
                        kind: mark.kind,
                        value: mark.value
                    )
                }
            }
            result.blocks = document.blocks.compactMap { block in
                transformed(
                    location: block.location,
                    length: block.length,
                    allowsEmpty: true
                ).map {
                    .init(
                        location: $0.location,
                        length: $0.length,
                        kind: block.kind,
                        isChecked: block.isChecked
                    )
                }
            }
            return result
        }

        private func toggleInlineAttribute(_ key: NSAttributedString.Key, in view: UITextView) {
            let range = clamped(view.selectedRange, to: view.attributedText.length)
            if range.length == 0 {
                var attributes = view.typingAttributes
                let isOn = (attributes[key] as? Bool) == true
                if isOn {
                    attributes.removeValue(forKey: key)
                    if key == .maslulUnderline { attributes.removeValue(forKey: .underlineStyle) }
                } else {
                    attributes[key] = true
                    if key == .maslulUnderline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
                }
                attributes[.font] = styledFont(from: attributes, fontSize: parent.fontSize)
                view.typingAttributes = attributes
                return
            }

            var isOnThroughout = true
            view.attributedText.enumerateAttribute(key, in: range) { value, _, stop in
                if (value as? Bool) != true {
                    isOnThroughout = false
                    stop.pointee = true
                }
            }

            let storage = view.textStorage
            storage.beginEditing()
            if isOnThroughout {
                storage.removeAttribute(key, range: range)
                if key == .maslulUnderline { storage.removeAttribute(.underlineStyle, range: range) }
            } else {
                storage.addAttribute(key, value: true, range: range)
                if key == .maslulUnderline {
                    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
            }
            refreshFonts(in: storage, range: range)
            storage.endEditing()
        }

        private func applyValueAttribute(
            _ key: NSAttributedString.Key,
            value: String?,
            in view: UITextView
        ) {
            let range = clamped(view.selectedRange, to: view.attributedText.length)
            if range.length == 0 {
                var attributes = view.typingAttributes
                if let value {
                    attributes[key] = value
                } else {
                    attributes.removeValue(forKey: key)
                }
                refreshPresentation(in: &attributes)
                view.typingAttributes = attributes
                return
            }

            let storage = view.textStorage
            storage.beginEditing()
            if let value {
                storage.addAttribute(key, value: value, range: range)
            } else {
                storage.removeAttribute(key, range: range)
            }
            refreshFonts(in: storage, range: range)
            refreshHighlights(in: storage, range: range)
            storage.endEditing()
        }

        @discardableResult
        private func toggleBlock(
            _ kind: EntryRichTextDocument.Block.Kind,
            in view: UITextView
        ) -> Bool {
            func prepareTypingAttributes() {
                var attributes = view.typingAttributes
                attributes[.maslulBlock] = kind.rawValue
                attributes[.maslulChecklistChecked] = false
                attributes[.paragraphStyle] = paragraphStyle(
                    for: kind,
                    list: textList(for: kind, isChecked: false)
                )
                view.typingAttributes = attributes
            }

            guard view.attributedText.length > 0 else {
                prepareTypingAttributes()
                return true
            }

            let string = view.attributedText.string as NSString
            let selection = clamped(view.selectedRange, to: string.length)
            let paragraphRange = string.paragraphRange(for: selection)
            guard paragraphRange.length > 0 else {
                prepareTypingAttributes()
                return true
            }
            let current = blockKind(at: paragraphRange.location, in: view.attributedText)
            let shouldRemove = current == kind
            let storage = view.textStorage
            let list = textList(for: kind, isChecked: false)
            var cursor = paragraphRange.location

            storage.beginEditing()
            while cursor < NSMaxRange(paragraphRange) {
                let itemRange = string.paragraphRange(for: NSRange(location: cursor, length: 0))
                if shouldRemove {
                    storage.removeAttribute(.maslulBlock, range: itemRange)
                    storage.removeAttribute(.maslulChecklistChecked, range: itemRange)
                    storage.removeAttribute(.paragraphStyle, range: itemRange)
                } else {
                    storage.addAttribute(.maslulBlock, value: kind.rawValue, range: itemRange)
                    storage.addAttribute(.maslulChecklistChecked, value: false, range: itemRange)
                    storage.addAttribute(
                        .paragraphStyle,
                        value: paragraphStyle(for: kind, list: list),
                        range: itemRange
                    )
                }
                let next = NSMaxRange(itemRange)
                guard next > cursor else { break }
                cursor = next
            }
            storage.endEditing()
            return true
        }

        private func rebuildRenderedTextPreservingSelection(in view: UITextView) {
            let semanticSelection = plainRange(for: view.selectedRange, in: view.attributedText)
                ?? NSRange(location: 0, length: 0)
            let plain = plainText(from: view.attributedText)
            render(in: view, plainText: plain, tags: parent.tags)
            let lower = renderedOffset(for: semanticSelection.location, in: view.attributedText)
            let upper = renderedOffset(for: NSMaxRange(semanticSelection), in: view.attributedText)
            view.selectedRange = clamped(
                NSRange(location: lower, length: max(0, upper - lower)),
                to: view.attributedText.length
            )
            view.typingAttributes = typingAttributes(for: view.selectedRange, in: view.attributedText)
            parent.selection?.wrappedValue = view.selectedRange
        }

        @objc func handleChecklistTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let view = recognizer.view as? UITextView,
                  view.attributedText.length > 0 else { return }
            let point = recognizer.location(in: view)
            guard point.x <= 38,
                  let position = view.closestPosition(to: point) else { return }
            let offset = view.offset(from: view.beginningOfDocument, to: position)
            let string = view.attributedText.string as NSString
            let safeOffset = min(max(0, offset), string.length)
            let paragraphRange = string.paragraphRange(for: NSRange(location: safeOffset, length: 0))
            guard paragraphRange.length > 0,
                  blockKind(at: paragraphRange.location, in: view.attributedText) == .checklist else { return }
            let probe = min(paragraphRange.location, view.attributedText.length - 1)
            let isChecked = (view.attributedText.attribute(
                .maslulChecklistChecked,
                at: probe,
                effectiveRange: nil
            ) as? Bool) == true
            setChecklistState(!isChecked, paragraphRange: paragraphRange, in: view)
            persistFormatting(from: view)
            reportSelectionFormatting(of: view)
            reportContentHeight(of: view)
        }

        private func setChecklistState(
            _ isChecked: Bool,
            paragraphRange: NSRange,
            in view: UITextView
        ) {
            let storage = view.textStorage
            var markerRange: NSRange?
            storage.enumerateAttribute(.attachment, in: paragraphRange) { value, range, stop in
                if value is ChecklistAttachment {
                    markerRange = range
                    stop.pointee = true
                }
            }

            storage.beginEditing()
            storage.addAttribute(.maslulChecklistChecked, value: isChecked, range: paragraphRange)
            storage.addAttribute(
                .paragraphStyle,
                value: paragraphStyle(for: .checklist, list: nil),
                range: paragraphRange
            )
            if isChecked {
                storage.addAttributes(
                    [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: UIColor(Palette.meta)
                    ],
                    range: paragraphRange
                )
            } else {
                storage.removeAttribute(.strikethroughStyle, range: paragraphRange)
                storage.addAttribute(.foregroundColor, value: UIColor(parent.textColor), range: paragraphRange)
            }
            if let markerRange {
                let marker = NSMutableAttributedString(
                    attachment: ChecklistAttachment(isChecked: isChecked, fontSize: parent.fontSize)
                )
                marker.addAttributes(
                    [
                        .maslulBlock: EntryRichTextDocument.Block.Kind.checklist.rawValue,
                        .maslulChecklistChecked: isChecked,
                        .paragraphStyle: paragraphStyle(for: .checklist, list: nil)
                    ],
                    range: NSRange(location: 0, length: 1)
                )
                storage.replaceCharacters(in: markerRange, with: marker)
            }
            storage.endEditing()
        }

        private func removeBlockMarker(containing location: Int, in view: UITextView) {
            let string = view.attributedText.string as NSString
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let storage = view.textStorage
            storage.beginEditing()
            storage.deleteCharacters(in: NSRange(location: location, length: 1))
            let remainingLength = max(0, paragraphRange.length - 1)
            if remainingLength > 0 {
                let remaining = NSRange(location: paragraphRange.location, length: remainingLength)
                storage.removeAttribute(.maslulBlock, range: remaining)
                storage.removeAttribute(.maslulChecklistChecked, range: remaining)
                storage.removeAttribute(.paragraphStyle, range: remaining)
                storage.removeAttribute(.strikethroughStyle, range: remaining)
                storage.addAttribute(.foregroundColor, value: UIColor(parent.textColor), range: remaining)
            }
            storage.endEditing()
            view.selectedRange = NSRange(location: paragraphRange.location, length: 0)
            parent.text = plainText(from: view.attributedText)
            persistFormatting(from: view)
            parent.selection?.wrappedValue = view.selectedRange
            reportSelectionFormatting(of: view)
        }

        private func apply(document: EntryRichTextDocument, to result: NSMutableAttributedString) {
            for mark in document.inlineMarks {
                let range = clamped(
                    NSRange(location: mark.location, length: mark.length),
                    to: result.length
                )
                guard range.length > 0 else { continue }
                let key: NSAttributedString.Key
                switch mark.kind {
                case .bold: key = .maslulBold
                case .italic: key = .maslulItalic
                case .underline: key = .maslulUnderline
                case .fontSize: key = .maslulFontSize
                case .highlight: key = .maslulHighlight
                }
                if mark.kind == .fontSize || mark.kind == .highlight {
                    guard let value = mark.value else { continue }
                    result.addAttribute(key, value: value, range: range)
                } else {
                    result.addAttribute(key, value: true, range: range)
                }
                if mark.kind == .underline {
                    result.addAttribute(
                        .underlineStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: range
                    )
                }
            }
            refreshFonts(in: result, range: NSRange(location: 0, length: result.length))
            refreshHighlights(in: result, range: NSRange(location: 0, length: result.length))

            var previousKind: EntryRichTextDocument.Block.Kind?
            var previousChecked = false
            var previousEnd = -1
            var activeList: NSTextList?
            for block in document.blocks.sorted(by: { $0.location < $1.location }) {
                let range = clamped(
                    NSRange(location: block.location, length: block.length),
                    to: result.length
                )
                guard range.length > 0 else { continue }
                if previousKind != block.kind ||
                    previousEnd != range.location ||
                    (block.kind == .checklist && previousChecked != block.isChecked) {
                    activeList = textList(for: block.kind, isChecked: block.isChecked)
                }
                result.addAttribute(.maslulBlock, value: block.kind.rawValue, range: range)
                result.addAttribute(.maslulChecklistChecked, value: block.isChecked, range: range)
                result.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle(for: block.kind, list: activeList),
                    range: range
                )
                if block.kind == .checklist, block.isChecked {
                    result.addAttributes(
                        [
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .foregroundColor: UIColor(Palette.meta)
                        ],
                        range: range
                    )
                }
                previousKind = block.kind
                previousChecked = block.isChecked
                previousEnd = NSMaxRange(range)
            }
        }

        private func insertBlockAttachments(
            from document: EntryRichTextDocument,
            into result: NSMutableAttributedString
        ) {
            for block in document.blocks
                .filter({ $0.kind == .checklist || $0.length == 0 })
                .sorted(by: { $0.location > $1.location }) {
                let renderedLocation = renderedOffset(for: block.location, in: result)
                let attachment: NSTextAttachment = block.kind == .checklist
                    ? ChecklistAttachment(isChecked: block.isChecked, fontSize: parent.fontSize)
                    : EmptyBlockAnchorAttachment(fontSize: parent.fontSize)
                let marker = NSMutableAttributedString(attachment: attachment)
                marker.addAttributes(
                    [
                        .maslulBlock: block.kind.rawValue,
                        .maslulChecklistChecked: block.isChecked,
                        .paragraphStyle: paragraphStyle(
                            for: block.kind,
                            list: textList(for: block.kind, isChecked: block.isChecked)
                        )
                    ],
                    range: NSRange(location: 0, length: 1)
                )
                result.insert(marker, at: renderedLocation)
            }
        }

        private func persistFormatting(from view: UITextView) {
            guard let binding = parent.richText else { return }
            var document = formattingDocument(from: view.attributedText)
            let renderedString = view.attributedText.string as NSString
            let caret = min(max(0, view.selectedRange.location), renderedString.length)
            let currentParagraph = renderedString.paragraphRange(
                for: NSRange(location: caret, length: 0)
            )
            let currentParagraphIsEmpty = currentParagraph.length == 0 || plainText(
                from: view.attributedText.attributedSubstring(from: currentParagraph)
            )
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            if view.selectedRange.length == 0,
               view.selectedRange.location == view.attributedText.length,
               currentParagraphIsEmpty,
               let rawKind = view.typingAttributes[.maslulBlock] as? String,
               let kind = EntryRichTextDocument.Block.Kind(rawValue: rawKind) {
                let location = (plainText(from: view.attributedText) as NSString).length
                if !document.blocks.contains(where: { $0.location == location && $0.length == 0 }) {
                    document.blocks.append(
                        .init(
                            location: location,
                            length: 0,
                            kind: kind,
                            isChecked: (view.typingAttributes[.maslulChecklistChecked] as? Bool) == true
                        )
                    )
                }
            }
            binding.wrappedValue = document
        }

        private func applyTrailingBlockTypingAttributesIfNeeded(
            document: EntryRichTextDocument,
            plainTextLength: Int,
            to view: UITextView
        ) {
            guard view.selectedRange.length == 0,
                  view.selectedRange.location == view.attributedText.length,
                  let block = document.blocks.last(where: {
                      $0.location == plainTextLength && $0.length == 0
                  }) else { return }
            var attributes = view.typingAttributes
            attributes[.maslulBlock] = block.kind.rawValue
            attributes[.maslulChecklistChecked] = block.isChecked
            attributes[.paragraphStyle] = paragraphStyle(
                for: block.kind,
                list: textList(for: block.kind, isChecked: block.isChecked)
            )
            view.typingAttributes = attributes
        }

        private func formattingDocument(from attributed: NSAttributedString) -> EntryRichTextDocument {
            var document = EntryRichTextDocument()
            let fullRange = NSRange(location: 0, length: attributed.length)

            for (key, kind) in [
                (NSAttributedString.Key.maslulBold, EntryRichTextDocument.InlineMark.Kind.bold),
                (.maslulItalic, .italic),
                (.maslulUnderline, .underline)
            ] {
                attributed.enumerateAttribute(key, in: fullRange) { value, range, _ in
                    guard (value as? Bool) == true,
                          let plainRange = plainRange(for: range, in: attributed),
                          plainRange.length > 0 else { return }
                    document.inlineMarks.append(
                        .init(location: plainRange.location, length: plainRange.length, kind: kind)
                    )
                }
            }
            for (key, kind) in [
                (NSAttributedString.Key.maslulFontSize, EntryRichTextDocument.InlineMark.Kind.fontSize),
                (.maslulHighlight, .highlight)
            ] {
                attributed.enumerateAttribute(key, in: fullRange) { value, range, _ in
                    guard let value = value as? String,
                          let plainRange = plainRange(for: range, in: attributed),
                          plainRange.length > 0 else { return }
                    document.inlineMarks.append(
                        .init(
                            location: plainRange.location,
                            length: plainRange.length,
                            kind: kind,
                            value: value
                        )
                    )
                }
            }
            document.inlineMarks = merged(document.inlineMarks)

            let string = attributed.string as NSString
            var cursor = 0
            while cursor < string.length {
                let renderedRange = string.paragraphRange(for: NSRange(location: cursor, length: 0))
                if let kind = blockKind(at: renderedRange.location, in: attributed),
                   let plainRange = plainRange(for: renderedRange, in: attributed) {
                    let isChecked = (attributed.attribute(
                        .maslulChecklistChecked,
                        at: min(renderedRange.location, attributed.length - 1),
                        effectiveRange: nil
                    ) as? Bool) == true
                    document.blocks.append(
                        .init(
                            location: plainRange.location,
                            length: plainRange.length,
                            kind: kind,
                            isChecked: isChecked
                        )
                    )
                }
                let next = NSMaxRange(renderedRange)
                guard next > cursor else { break }
                cursor = next
            }
            return document
        }

        private func merged(
            _ marks: [EntryRichTextDocument.InlineMark]
        ) -> [EntryRichTextDocument.InlineMark] {
            let sorted = marks.sorted {
                $0.kind.rawValue == $1.kind.rawValue
                    ? $0.location < $1.location
                    : $0.kind.rawValue < $1.kind.rawValue
            }
            var result: [EntryRichTextDocument.InlineMark] = []
            for mark in sorted {
                if let last = result.last,
                   last.kind == mark.kind,
                   last.value == mark.value,
                   mark.location <= last.location + last.length {
                    result[result.count - 1].length = max(
                        last.location + last.length,
                        mark.location + mark.length
                    ) - last.location
                } else {
                    result.append(mark)
                }
            }
            return result
        }

        private func plainRange(for renderedRange: NSRange, in attributed: NSAttributedString) -> NSRange? {
            let lower = plainOffset(for: renderedRange.location, in: attributed)
            let upper = plainOffset(for: NSMaxRange(renderedRange), in: attributed)
            guard upper >= lower else { return nil }
            return NSRange(location: lower, length: upper - lower)
        }

        private func plainOffset(for renderedOffset: Int, in attributed: NSAttributedString) -> Int {
            let target = min(max(0, renderedOffset), attributed.length)
            var plainOffset = 0
            var renderedCursor = 0
            attributed.enumerateAttributes(
                in: NSRange(location: 0, length: attributed.length),
                options: []
            ) { attributes, range, stop in
                guard range.location < target else {
                    stop.pointee = true
                    return
                }
                let consumed = min(NSMaxRange(range), target) - range.location
                if let attachment = attributes[.attachment] as? MentionAttachment {
                    if consumed > 0 { plainOffset += (attachment.token as NSString).length }
                } else if attributes[.attachment] is BlockPresentationAttachment {
                    // List anchors and checklist controls are presentation
                    // only and occupy no position in Entry.body.
                } else {
                    plainOffset += consumed
                }
                renderedCursor = NSMaxRange(range)
                if renderedCursor >= target { stop.pointee = true }
            }
            return plainOffset
        }

        private func renderedOffset(for plainOffset: Int, in attributed: NSAttributedString) -> Int {
            let target = max(0, plainOffset)
            var plainCursor = 0
            var resolved = attributed.length
            attributed.enumerateAttributes(
                in: NSRange(location: 0, length: attributed.length),
                options: []
            ) { attributes, range, stop in
                if attributes[.attachment] is BlockPresentationAttachment {
                    // A list marker has zero semantic width. Skip over it so a
                    // caret at the paragraph start lands after the control.
                    return
                }
                let semanticLength: Int
                if let attachment = attributes[.attachment] as? MentionAttachment {
                    semanticLength = (attachment.token as NSString).length
                } else {
                    semanticLength = range.length
                }

                guard target <= plainCursor + semanticLength else {
                    plainCursor += semanticLength
                    return
                }
                if attributes[.attachment] is MentionAttachment {
                    resolved = target == plainCursor ? range.location : NSMaxRange(range)
                } else {
                    resolved = min(range.location + (target - plainCursor), NSMaxRange(range))
                }
                stop.pointee = true
            }
            return min(max(0, resolved), attributed.length)
        }

        private func reportSelectionFormatting(of view: UITextView) {
            guard let callback = parent.onSelectionFormattingChange else { return }
            let state = selectionFormatting(of: view)
            DispatchQueue.main.async { callback(state) }
        }

        private func selectionFormatting(of view: UITextView) -> RichTextSelectionState {
            let attributes: [NSAttributedString.Key: Any]
            if view.selectedRange.length == 0 {
                attributes = view.typingAttributes
            } else if view.attributedText.length > 0 {
                let location = min(view.selectedRange.location, view.attributedText.length - 1)
                attributes = view.attributedText.attributes(at: location, effectiveRange: nil)
            } else {
                attributes = [:]
            }
            return RichTextSelectionState(
                isBold: (attributes[.maslulBold] as? Bool) == true,
                isItalic: (attributes[.maslulItalic] as? Bool) == true,
                isUnderlined: (attributes[.maslulUnderline] as? Bool) == true,
                fontSize: (attributes[.maslulFontSize] as? String)
                    .flatMap(RichTextFontSize.init(rawValue:)) ?? .body,
                highlightColor: (attributes[.maslulHighlight] as? String)
                    .flatMap(RichTextHighlightColor.init(rawValue:)),
                block: (attributes[.maslulBlock] as? String).flatMap(EntryRichTextDocument.Block.Kind.init(rawValue:)),
                isChecklistChecked: (attributes[.maslulChecklistChecked] as? Bool) == true
            )
        }

        private func blockKind(
            at location: Int,
            in attributed: NSAttributedString
        ) -> EntryRichTextDocument.Block.Kind? {
            guard attributed.length > 0 else { return nil }
            let safeLocation = min(max(0, location), attributed.length - 1)
            guard let rawValue = attributed.attribute(
                .maslulBlock,
                at: safeLocation,
                effectiveRange: nil
            ) as? String else { return nil }
            return EntryRichTextDocument.Block.Kind(rawValue: rawValue)
        }

        private func refreshFonts(in attributed: NSMutableAttributedString, range: NSRange) {
            guard range.length > 0 else { return }
            attributed.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
                attributed.addAttribute(
                    .font,
                    value: styledFont(from: attributes, fontSize: parent.fontSize),
                    range: subrange
                )
            }
        }

        private func styledFont(from attributes: [NSAttributedString.Key: Any], fontSize: CGFloat) -> UIFont {
            var traits: UIFontDescriptor.SymbolicTraits = []
            if (attributes[.maslulBold] as? Bool) == true { traits.insert(.traitBold) }
            if (attributes[.maslulItalic] as? Bool) == true { traits.insert(.traitItalic) }
            let selectedSize = (attributes[.maslulFontSize] as? String)
                .flatMap(RichTextFontSize.init(rawValue:)) ?? .body
            let resolvedSize = fontSize * CGFloat(selectedSize.scale)
            let base = UIFont.systemFont(ofSize: resolvedSize)
            guard !traits.isEmpty,
                  let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
            return UIFont(descriptor: descriptor, size: resolvedSize)
        }

        private func refreshPresentation(in attributes: inout [NSAttributedString.Key: Any]) {
            attributes[.font] = styledFont(from: attributes, fontSize: parent.fontSize)
            if let rawColor = attributes[.maslulHighlight] as? String,
               let color = RichTextHighlightColor(rawValue: rawColor) {
                attributes[.backgroundColor] = UIColor(color.color.opacity(0.46))
            } else {
                attributes.removeValue(forKey: .backgroundColor)
            }
        }

        private func refreshHighlights(in attributed: NSMutableAttributedString, range: NSRange) {
            guard range.length > 0 else { return }
            attributed.enumerateAttribute(.maslulHighlight, in: range) { value, subrange, _ in
                if let rawColor = value as? String,
                   let color = RichTextHighlightColor(rawValue: rawColor) {
                    attributed.addAttribute(
                        .backgroundColor,
                        value: UIColor(color.color.opacity(0.46)),
                        range: subrange
                    )
                } else {
                    attributed.removeAttribute(.backgroundColor, range: subrange)
                }
            }
        }

        private func typingAttributes(
            for selection: NSRange,
            in attributed: NSAttributedString
        ) -> [NSAttributedString.Key: Any] {
            guard attributed.length > 0 else { return baseAttributes(fontSize: parent.fontSize) }
            let location: Int
            if selection.location > 0 {
                location = min(selection.location - 1, attributed.length - 1)
            } else {
                location = 0
            }
            var attributes = attributed.attributes(at: location, effectiveRange: nil)
            attributes.removeValue(forKey: .attachment)
            attributes[.font] = styledFont(from: attributes, fontSize: parent.fontSize)
            attributes[.foregroundColor] = UIColor(parent.textColor)
            refreshPresentation(in: &attributes)
            return attributes
        }

        private func textList(
            for kind: EntryRichTextDocument.Block.Kind,
            isChecked: Bool
        ) -> NSTextList? {
            let marker: NSTextList.MarkerFormat
            switch kind {
            case .bulletedList: marker = .disc
            case .numberedList: marker = NSTextList.MarkerFormat(rawValue: "{decimal}.")
            case .checklist: return nil
            }
            return NSTextList(markerFormat: marker, options: 0)
        }

        private func paragraphStyle(
            for kind: EntryRichTextDocument.Block.Kind,
            list: NSTextList?
        ) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            if let list { style.textLists = [list] }
            style.firstLineHeadIndent = 0
            style.headIndent = kind == .checklist ? 28 : 24
            style.paragraphSpacing = 4
            return style
        }

        private func clamped(_ range: NSRange, to textLength: Int) -> NSRange {
            let location = min(max(0, range.location), textLength)
            let length = min(max(0, range.length), textLength - location)
            return NSRange(location: location, length: length)
        }

        func reportContentHeight(of view: UITextView) {
            guard view.bounds.width > 0, let callback = parent.onContentHeightChange else { return }
            let measured = view.sizeThatFits(
                CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)
            ).height
            DispatchQueue.main.async { callback(measured) }
        }

        func plainText(from attributed: NSAttributedString?) -> String {
            guard let attributed else { return "" }
            var result = ""
            attributed.enumerateAttributes(
                in: NSRange(location: 0, length: attributed.length),
                options: []
            ) { attributes, range, _ in
                if let attachment = attributes[.attachment] as? MentionAttachment {
                    result += attachment.token
                } else if attributes[.attachment] is BlockPresentationAttachment {
                    // The visual control is represented structurally by the
                    // block metadata, never by a glyph in the plain body.
                } else {
                    result += attributed.attributedSubstring(from: range).string
                }
            }
            return result
        }

        private func baseAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
            [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor(parent.textColor)
            ]
        }
    }
}

private extension NSAttributedString.Key {
    static let maslulBold = NSAttributedString.Key("com.romesela.maslul.richText.bold")
    static let maslulItalic = NSAttributedString.Key("com.romesela.maslul.richText.italic")
    static let maslulUnderline = NSAttributedString.Key("com.romesela.maslul.richText.underline")
    static let maslulFontSize = NSAttributedString.Key("com.romesela.maslul.richText.fontSize")
    static let maslulHighlight = NSAttributedString.Key("com.romesela.maslul.richText.highlight")
    static let maslulBlock = NSAttributedString.Key("com.romesela.maslul.richText.block")
    static let maslulChecklistChecked = NSAttributedString.Key("com.romesela.maslul.richText.checklistChecked")
}

private protocol BlockPresentationAttachment: AnyObject {}

private final class EmptyBlockAnchorAttachment: NSTextAttachment, BlockPresentationAttachment {
    init(fontSize: CGFloat) {
        super.init(data: nil, ofType: nil)
        image = UIImage()
        bounds = CGRect(x: 0, y: 0, width: 0.01, height: fontSize)
    }

    required init?(coder: NSCoder) { nil }
}

private final class ChecklistAttachment: NSTextAttachment, BlockPresentationAttachment {
    init(isChecked: Bool, fontSize: CGFloat) {
        super.init(data: nil, ofType: nil)
        let symbol = isChecked ? "checkmark.circle.fill" : "circle"
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize * 0.9, weight: .regular)
        image = UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(UIColor(Palette.ink2), renderingMode: .alwaysOriginal)
        let size = fontSize + 5
        let bodyFont = UIFont.systemFont(ofSize: fontSize)
        bounds = CGRect(
            x: 0,
            y: (bodyFont.capHeight - size) / 2,
            width: size + 5,
            height: size
        )
    }

    required init?(coder: NSCoder) { nil }
}

final class MentionAttachment: NSTextAttachment {
    let token: String
    let tagID: PersistentIdentifier

    init(tag: EntryTag, fontSize: CGFloat, appearance: InlineMentionAppearance) {
        token = "@\(tag.name)"
        tagID = tag.persistentModelID
        super.init(data: nil, ofType: nil)

        let labelFont = UIFont(name: "InstrumentSans-SemiBold", size: appearance.fontSize)
            ?? UIFont.systemFont(ofSize: appearance.fontSize, weight: .semibold)
        let textSize = (tag.name as NSString).size(withAttributes: [.font: labelFont])
        let emoji = TagMentionVisual.emoji(for: tag)
        let emojiFont = UIFont.systemFont(ofSize: appearance.emojiFontSize)
        let emojiSize = emoji.map {
            ($0 as NSString).size(withAttributes: [.font: emojiFont])
        } ?? .zero
        let iconGap: CGFloat = emoji == nil ? 0 : appearance.iconGap
        let size = CGSize(
            width: ceil(textSize.width)
                + ceil(emojiSize.width)
                + iconGap
                + (appearance.horizontalPadding * 2),
            height: appearance.height
        )

        let color = UIColor(TagMentionVisual.background(for: tag))

        image = UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            let path = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: appearance.cornerRadius
            )
            path.fill()
            UIColor(Palette.ink.opacity(0.06)).setStroke()
            path.lineWidth = 1
            path.stroke()

            var textX = appearance.horizontalPadding
            if let emoji {
                (emoji as NSString).draw(
                    at: CGPoint(x: textX, y: (size.height - emojiSize.height) / 2),
                    withAttributes: [.font: emojiFont]
                )
                textX += emojiSize.width + iconGap
            }

            (tag.name as NSString).draw(
                at: CGPoint(
                    x: textX,
                    y: (size.height - textSize.height) / 2
                ),
                withAttributes: [.font: labelFont, .foregroundColor: UIColor(Palette.ink)]
            )
        }
        let bodyFont = UIFont.systemFont(ofSize: fontSize)
        let baselineOffset = (bodyFont.capHeight - size.height) / 2
        bounds = CGRect(x: 0, y: baselineOffset, width: size.width, height: size.height)
    }

    required init?(coder: NSCoder) { nil }
}

struct InlineMentionText: View {
    let text: String
    let tags: [EntryTag]
    var fontSize: CGFloat
    var textColor: Color = Palette.meta
    var maximumNumberOfLines = 2
    var mentionAppearance: InlineMentionAppearance = .standard

    @Query(sort: \EntryTag.name, order: .forward) private var availableTags: [EntryTag]
    @State private var measuredHeight: CGFloat = 24

    private var resolvedTags: [EntryTag] {
        var result = tags
        var ids = Set(tags.map(\.persistentModelID))
        for tag in availableTags where NativeRichTextMentions.contains(tag, in: text) {
            if ids.insert(tag.persistentModelID).inserted {
                result.append(tag)
            }
        }
        return result
    }

    var body: some View {
        InlineMentionEditor(
            text: .constant(text),
            tags: .constant(resolvedTags),
            placeholder: "",
            fontSize: fontSize,
            textColor: textColor,
            scrolls: false,
            isEditable: false,
            maximumNumberOfLines: maximumNumberOfLines,
            mentionAppearance: mentionAppearance,
            onContentHeightChange: { height in
                // TextKit has already applied maximumNumberOfLines and its
                // measured height includes taller inline attachments. Capping
                // this with a font-only estimate clips mention line fragments.
                measuredHeight = ceil(height)
            }
        )
        .frame(height: max(measuredHeight, mentionAppearance.height))
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
    }
}
