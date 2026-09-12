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
    var onFocus: (() -> Void)? = nil
    var onInputLanguageChange: ((String?) -> Void)? = nil
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
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
        if context.coordinator.plainText(from: view.attributedText) != text ||
            context.coordinator.renderedTagIDs != tags.map(\.persistentModelID) {
            context.coordinator.render(in: view, plainText: text, tags: tags)
        }
        context.coordinator.reportContentHeight(of: view)
        (view.viewWithTag(Coordinator.placeholderTag) as? UILabel)?.isHidden = !text.isEmpty
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        static let placeholderTag = 7_411
        var parent: InlineMentionEditor
        var isRendering = false
        var renderedTagIDs: [PersistentIdentifier] = []
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
            reportContentHeight(of: textView)
            (textView.viewWithTag(Self.placeholderTag) as? UILabel)?.isHidden = !parent.text.isEmpty
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocus?()
            parent.onInputLanguageChange?(textView.textInputMode?.primaryLanguage)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText: String
        ) -> Bool {
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
            mutable.replaceCharacters(
                in: range,
                with: NSAttributedString(
                    string: plainName,
                    attributes: baseAttributes(fontSize: parent.fontSize)
                )
            )
            textView.attributedText = mutable
            textView.typingAttributes = baseAttributes(fontSize: parent.fontSize)
            textView.selectedRange = NSRange(location: range.location + (plainName as NSString).length, length: 0)
            parent.tags.removeAll { $0.persistentModelID == attachment.tagID }
            parent.text = plainText(from: mutable)
            renderedTagIDs = parent.tags.map(\.persistentModelID)
            return false
        }

        func render(in view: UITextView, plainText: String, tags: [EntryTag]) {
            isRendering = true
            defer { isRendering = false }

            let result = NSMutableAttributedString(
                string: plainText,
                attributes: baseAttributes(fontSize: parent.fontSize)
            )

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
                result.replaceCharacters(in: match.range, with: NSAttributedString(attachment: attachment))
            }

            let wasFirstResponder = view.isFirstResponder
            view.attributedText = result
            view.typingAttributes = baseAttributes(fontSize: parent.fontSize)
            if parent.isEditable {
                view.selectedRange = NSRange(location: result.length, length: 0)
            }
            if view.isScrollEnabled, result.length > 0 {
                view.scrollRangeToVisible(NSRange(location: result.length - 1, length: 1))
            }
            renderedTagIDs = tags.map(\.persistentModelID)
            if wasFirstResponder { view.becomeFirstResponder() }
            reportContentHeight(of: view)
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

private final class MentionAttachment: NSTextAttachment {
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

    @State private var measuredHeight: CGFloat = 24

    var body: some View {
        InlineMentionEditor(
            text: .constant(text),
            tags: .constant(tags),
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
