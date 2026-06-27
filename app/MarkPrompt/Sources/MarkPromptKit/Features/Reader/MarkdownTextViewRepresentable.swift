import AppKit
import SwiftUI

public enum MarkdownReaderLayoutMetrics {
    public static func renderSignature(for attributedText: NSAttributedString) -> String {
        var hasher = Hasher()
        hasher.combine(attributedText.string)
        hasher.combine(attributedText.length)

        attributedText.enumerateAttributes(
            in: NSRange(location: 0, length: attributedText.length)
        ) { attributes, range, _ in
            hasher.combine(range.location)
            hasher.combine(range.length)
            signature(attributes: attributes, into: &hasher)
        }

        return String(hasher.finalize())
    }

    public static func maximumTableContentWidth(in attributedText: NSAttributedString) -> CGFloat {
        guard attributedText.length > 0 else {
            return 0
        }

        var maximumWidth: CGFloat = 0
        attributedText.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            guard let paragraph = value as? NSParagraphStyle else {
                return
            }

            for textBlock in paragraph.textBlocks {
                guard let tableBlock = textBlock as? NSTextTableBlock,
                      tableBlock.table.valueType(for: .width) == .absoluteValueType
                else {
                    continue
                }

                maximumWidth = max(maximumWidth, tableBlock.table.value(for: .width))
            }
        }

        return maximumWidth
    }

    private static func signature(
        attributes: [NSAttributedString.Key: Any],
        into hasher: inout Hasher
    ) {
        if let font = attributes[.font] as? NSFont {
            hasher.combine("font")
            hasher.combine(font.fontName)
            hasher.combine(font.pointSize)
            hasher.combine(font.fontDescriptor.symbolicTraits.rawValue)
        }

        if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle {
            hasher.combine("paragraph")
            hasher.combine(paragraph.alignment.rawValue)
            hasher.combine(paragraph.lineSpacing)
            hasher.combine(paragraph.paragraphSpacing)
            hasher.combine(paragraph.paragraphSpacingBefore)
            hasher.combine(paragraph.headIndent)
            hasher.combine(paragraph.firstLineHeadIndent)
            hasher.combine(paragraph.lineBreakMode.rawValue)
            hasher.combine(paragraph.textBlocks.count)
            for textBlock in paragraph.textBlocks {
                signature(textBlock: textBlock, into: &hasher)
            }
        }

        if let link = attributes[.link] {
            hasher.combine("link")
            hasher.combine(String(describing: link))
        }

        if let attachment = attributes[.attachment] as? NSTextAttachment {
            hasher.combine("attachment")
            hasher.combine(String(describing: type(of: attachment)))
            hasher.combine(attachment.bounds.origin.x)
            hasher.combine(attachment.bounds.origin.y)
            hasher.combine(attachment.bounds.size.width)
            hasher.combine(attachment.bounds.size.height)
        }

        if let backgroundColor = attributes[.backgroundColor] {
            hasher.combine("background")
            hasher.combine(String(describing: backgroundColor))
        }

        if let foregroundColor = attributes[.foregroundColor] {
            hasher.combine("foreground")
            hasher.combine(String(describing: foregroundColor))
        }

        if let underlineStyle = attributes[.underlineStyle] {
            hasher.combine("underline")
            hasher.combine(String(describing: underlineStyle))
        }

        if let strikethroughStyle = attributes[.strikethroughStyle] {
            hasher.combine("strikethrough")
            hasher.combine(String(describing: strikethroughStyle))
        }

        if let baselineOffset = attributes[.baselineOffset] {
            hasher.combine("baseline")
            hasher.combine(String(describing: baselineOffset))
        }

        if let taskMarkerSourceRange = attributes[.markPromptTaskMarkerSourceRange] as? SourceTextRange {
            hasher.combine("taskMarkerSourceRange")
            hasher.combine(taskMarkerSourceRange.lowerBound)
            hasher.combine(taskMarkerSourceRange.upperBound)
        }
        if let taskMarkerCharacter = attributes[.markPromptTaskMarkerCharacter] as? String {
            hasher.combine("taskMarkerCharacter")
            hasher.combine(taskMarkerCharacter)
        }
    }

    private static func signature(textBlock: NSTextBlock, into hasher: inout Hasher) {
        hasher.combine(String(describing: type(of: textBlock)))

        if let tableBlock = textBlock as? NSTextTableBlock {
            hasher.combine("tableBlock")
            hasher.combine(tableBlock.startingRow)
            hasher.combine(tableBlock.rowSpan)
            hasher.combine(tableBlock.startingColumn)
            hasher.combine(tableBlock.columnSpan)
            hasher.combine(tableBlock.verticalAlignment.rawValue)
            hasher.combine(tableBlock.valueType(for: .width).rawValue)
            hasher.combine(tableBlock.value(for: .width))
            hasher.combine(tableBlock.table.numberOfColumns)
            hasher.combine(tableBlock.table.layoutAlgorithm.rawValue)
            hasher.combine(tableBlock.table.collapsesBorders)
            hasher.combine(tableBlock.table.valueType(for: .width).rawValue)
            hasher.combine(tableBlock.table.value(for: .width))
        }
    }

    public static func currentHeadingID(
        forVisibleLocation visibleLocation: Int,
        in sourceMap: MarkdownSourceMap
    ) -> UUID? {
        sourceMap.headingRenderRanges
            .sorted { first, second in
                first.value.location < second.value.location
            }
            .last { _, range in
                range.location <= visibleLocation
            }?
            .key
    }

    public static func annotationButtonRect(
        forVisibleSelectionRect selectionRect: CGRect,
        viewportSize: CGSize,
        buttonSize: CGSize = CGSize(width: 84, height: 36),
        margin: CGFloat = 12,
        gap: CGFloat = 8
    ) -> CGRect? {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              selectionRect.isNull == false,
              selectionRect.isInfinite == false
        else {
            return nil
        }

        let maximumX = max(margin, viewportSize.width - buttonSize.width - margin)
        let maximumY = max(margin, viewportSize.height - buttonSize.height - margin)
        let centeredY = min(maximumY, max(margin, selectionRect.midY - buttonSize.height / 2))
        let rightSideX = selectionRect.maxX + gap
        if rightSideX <= maximumX {
            return CGRect(origin: CGPoint(x: rightSideX, y: centeredY), size: buttonSize)
        }

        let leftSideX = selectionRect.minX - buttonSize.width - gap
        if leftSideX >= margin {
            return CGRect(origin: CGPoint(x: leftSideX, y: centeredY), size: buttonSize)
        }

        let preferredX = selectionRect.midX - buttonSize.width / 2
        let aboveY = selectionRect.minY - buttonSize.height - gap
        let belowY = selectionRect.maxY + gap
        let preferredY = aboveY >= margin ? aboveY : belowY
        let x = min(maximumX, max(margin, preferredX))
        let y = min(maximumY, max(margin, preferredY))

        return CGRect(origin: CGPoint(x: x, y: y), size: buttonSize)
    }

    public static func annotationPopoverArrowEdge(
        visibleSelectionRect: CGRect?,
        annotationButtonRect: CGRect
    ) -> Edge {
        guard let visibleSelectionRect else {
            return .leading
        }

        return annotationButtonRect.midX >= visibleSelectionRect.midX ? .leading : .trailing
    }

    public static func annotationPopoverRect(
        forAnnotationButtonRect buttonRect: CGRect,
        avoidingVisibleSelectionRect selectionRect: CGRect? = nil,
        viewportSize: CGSize,
        popoverSize: CGSize = CGSize(width: 380, height: 330),
        margin: CGFloat = 12,
        gap: CGFloat = 12
    ) -> CGRect {
        let maximumX = max(margin, viewportSize.width - popoverSize.width - margin)
        let maximumY = max(margin, viewportSize.height - popoverSize.height - margin)
        let preferredX = buttonRect.midX - popoverSize.width / 2
        let upperBoundary = min(buttonRect.minY, selectionRect?.minY ?? buttonRect.minY)
        let lowerBoundary = max(buttonRect.maxY, selectionRect?.maxY ?? buttonRect.maxY)
        let aboveY = upperBoundary - popoverSize.height - gap
        let belowY = lowerBoundary + gap
        let preferredY = if belowY + popoverSize.height <= viewportSize.height - margin {
            belowY
        } else if aboveY >= margin {
            aboveY
        } else if buttonRect.midY < viewportSize.height / 2 {
            belowY
        } else {
            aboveY
        }
        let x = min(maximumX, max(margin, preferredX))
        let y = min(maximumY, max(margin, preferredY))
        return CGRect(origin: CGPoint(x: x, y: y), size: popoverSize)
    }
}

public struct MarkdownTextViewRepresentable: NSViewRepresentable {
    public var attributedText: NSAttributedString
    public var sourceMap: MarkdownSourceMap
    public var highlights: [AnnotationHighlight]
    public var annotationButtonRect: CGRect?
    public var isAnnotationButtonActive: Bool
    public var annotationCursorState: ReaderAnnotationCursorState
    public var scrollTargetHeadingID: UUID?
    public var scrollTargetRange: RenderedTextRange?
    public var onAnnotationButtonPress: () -> Void
    public var onSelectionChange: (ReaderSelection?) -> Void
    public var onScrollTargetConsumed: (UUID?, RenderedTextRange?) -> Void
    public var onVisibleHeadingChange: (UUID?) -> Void
    public var onTaskMarkerToggle: (SourceTextRange) -> Bool
    public var onTaskMarkerStatusChange: (SourceTextRange, String) -> Bool
    public var onTaskMarkerUndo: () -> Bool

    public init(
        attributedText: NSAttributedString,
        sourceMap: MarkdownSourceMap,
        highlights: [AnnotationHighlight],
        annotationButtonRect: CGRect? = nil,
        isAnnotationButtonActive: Bool = false,
        annotationCursorState: ReaderAnnotationCursorState = .textSelection,
        scrollTargetHeadingID: UUID?,
        scrollTargetRange: RenderedTextRange?,
        onAnnotationButtonPress: @escaping () -> Void = {},
        onSelectionChange: @escaping (ReaderSelection?) -> Void,
        onScrollTargetConsumed: @escaping (UUID?, RenderedTextRange?) -> Void = { _, _ in },
        onVisibleHeadingChange: @escaping (UUID?) -> Void = { _ in },
        onTaskMarkerToggle: @escaping (SourceTextRange) -> Bool = { _ in false },
        onTaskMarkerStatusChange: @escaping (SourceTextRange, String) -> Bool = { _, _ in false },
        onTaskMarkerUndo: @escaping () -> Bool = { false }
    ) {
        self.attributedText = attributedText
        self.sourceMap = sourceMap
        self.highlights = highlights
        self.annotationButtonRect = annotationButtonRect
        self.isAnnotationButtonActive = isAnnotationButtonActive
        self.annotationCursorState = annotationCursorState
        self.scrollTargetHeadingID = scrollTargetHeadingID
        self.scrollTargetRange = scrollTargetRange
        self.onAnnotationButtonPress = onAnnotationButtonPress
        self.onSelectionChange = onSelectionChange
        self.onScrollTargetConsumed = onScrollTargetConsumed
        self.onVisibleHeadingChange = onVisibleHeadingChange
        self.onTaskMarkerToggle = onTaskMarkerToggle
        self.onTaskMarkerStatusChange = onTaskMarkerStatusChange
        self.onTaskMarkerUndo = onTaskMarkerUndo
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.contentView.postsBoundsChangedNotifications = true

        let initialSize = NSSize(width: max(scrollView.contentSize.width, 480), height: max(scrollView.contentSize.height, 640))
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: initialSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = ReaderTextView(frame: NSRect(origin: .zero, size: initialSize), textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.onTaskMarkerClick = { _ in false }
        textView.onTaskMarkerStatusChange = { _, _ in false }
        textView.onTaskMarkerUndo = { false }
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = []
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: initialSize.width, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.attach(to: scrollView)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ReaderTextView else {
            return
        }

        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onVisibleHeadingChange = onVisibleHeadingChange
        context.coordinator.onAnnotationButtonPress = onAnnotationButtonPress
        textView.annotationCursorState = annotationCursorState
        textView.onTaskMarkerClick = onTaskMarkerToggle
        textView.onTaskMarkerStatusChange = onTaskMarkerStatusChange
        textView.onTaskMarkerUndo = onTaskMarkerUndo
        context.coordinator.sourceMap = sourceMap
        context.coordinator.updateAnnotationButton(
            in: scrollView,
            rect: annotationButtonRect,
            isActive: isAnnotationButtonActive
        )

        let highlightSignature = highlights.map {
            "\($0.id):\($0.range.location):\($0.range.length):\($0.isSelected):\($0.isIncludedInPrompt):\($0.isAnchorLost)"
        }.joined(separator: "|")
        let contentWidth = max(scrollView.contentSize.width, 480)
        let renderSignature = MarkdownReaderLayoutMetrics.renderSignature(for: attributedText)
        let isRenderChanged = context.coordinator.lastRenderSignature != renderSignature
        let isHighlightChanged = context.coordinator.lastHighlightSignature != highlightSignature
        let isWidthChanged = abs(context.coordinator.lastLayoutWidth - contentWidth) > 0.5
        let hasExplicitScrollTarget = scrollTargetHeadingID != nil || scrollTargetRange != nil
        let preservedScrollOrigin = scrollView.contentView.bounds.origin

        if isRenderChanged || isHighlightChanged {
            let selectedRange = textView.selectedRange()
            textView.textStorage?.setAttributedString(highlightedText())
            if selectedRange.location != NSNotFound,
               selectedRange.location + selectedRange.length <= (textView.string as NSString).length {
                textView.setSelectedRange(selectedRange)
            }
            context.coordinator.lastRenderSignature = renderSignature
            context.coordinator.lastHighlightSignature = highlightSignature
        }

        if isRenderChanged || isWidthChanged {
            updateTextViewLayout(textView, in: scrollView, contentWidth: contentWidth)
            textView.invalidateTaskMarkerCursorRects()
            context.coordinator.lastLayoutWidth = contentWidth

            if !hasExplicitScrollTarget {
                restoreScrollPosition(in: scrollView, to: preservedScrollOrigin)
            }
        } else if isHighlightChanged {
            textView.invalidateTaskMarkerCursorRects()
        }
        if isRenderChanged || isWidthChanged {
            context.coordinator.emitVisibleHeading(from: scrollView)
        }

        if let scrollTargetHeadingID,
           context.coordinator.lastScrollTargetHeadingID != scrollTargetHeadingID,
           let renderedRange = sourceMap.headingRenderRanges[scrollTargetHeadingID] {
            textView.scrollRangeToVisible(renderedRange.nsRange)
            context.coordinator.lastScrollTargetHeadingID = scrollTargetHeadingID
            context.coordinator.emitVisibleHeading(from: scrollView)
            let consumedHeadingID = scrollTargetHeadingID
            DispatchQueue.main.async {
                onScrollTargetConsumed(consumedHeadingID, nil)
            }
        } else if scrollTargetHeadingID == nil {
            context.coordinator.lastScrollTargetHeadingID = nil
        }

        if let scrollTargetRange,
           context.coordinator.lastScrollTargetRange != scrollTargetRange {
            let targetRange = scrollTargetRange.nsRange
            let textLength = (textView.string as NSString).length
            if targetRange.location != NSNotFound,
               targetRange.location + targetRange.length <= textLength {
                textView.setSelectedRange(targetRange)
            }
            textView.scrollRangeToVisible(scrollTargetRange.nsRange)
            if scrollTargetRange.length > 0 {
                textView.showFindIndicator(for: scrollTargetRange.nsRange)
            }
            context.coordinator.lastScrollTargetRange = scrollTargetRange
            context.coordinator.emitVisibleHeading(from: scrollView)
            let consumedRange = scrollTargetRange
            DispatchQueue.main.async {
                onScrollTargetConsumed(nil, consumedRange)
            }
        } else if scrollTargetRange == nil {
            context.coordinator.lastScrollTargetRange = nil
        }
    }

    private func updateTextViewLayout(_ textView: ReaderTextView, in scrollView: NSScrollView, contentWidth: CGFloat) {
        let articleWidth = min(max(contentWidth - 96, 360), 760)
        let horizontalInset = max(48, (contentWidth - articleWidth) / 2)
        let tableContentWidth = MarkdownReaderLayoutMetrics.maximumTableContentWidth(in: textView.attributedString())
        let containerWidth = max(articleWidth, min(tableContentWidth, 880))
        let documentWidth = max(contentWidth, containerWidth + horizontalInset * 2)
        textView.textContainerInset = NSSize(width: horizontalInset, height: 34)
        textView.textContainer?.containerSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false

        if abs(textView.frame.width - documentWidth) > 0.5 {
            textView.frame.size.width = documentWidth
        }

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            textView.frame.size.height = max(scrollView.contentSize.height, 640)
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        let verticalInset = textView.textContainerInset.height * 2
        let nextHeight = max(scrollView.contentSize.height, usedHeight + verticalInset + 48)
        if abs(textView.frame.height - nextHeight) > 0.5 {
            textView.frame.size.height = nextHeight
        }
    }

    private func restoreScrollPosition(in scrollView: NSScrollView, to origin: NSPoint) {
        guard let documentView = scrollView.documentView else {
            return
        }

        let maxY = max(0, documentView.frame.height - scrollView.contentView.bounds.height)
        let maxX = max(0, documentView.frame.width - scrollView.contentView.bounds.width)
        let restoredOrigin = NSPoint(
            x: min(max(0, origin.x), maxX),
            y: min(max(0, origin.y), maxY)
        )
        scrollView.contentView.scroll(to: restoredOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func highlightedText() -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        for highlight in highlights where !highlight.isAnchorLost {
            guard highlight.range.location >= 0,
                  highlight.range.upperBound <= mutable.length
            else {
                continue
            }

            let color: NSColor = if highlight.isSelected {
                NSColor.systemYellow.withAlphaComponent(0.35)
            } else if highlight.isIncludedInPrompt {
                NSColor.systemYellow.withAlphaComponent(0.18)
            } else {
                NSColor.secondaryLabelColor.withAlphaComponent(0.08)
            }

            mutable.addAttribute(.backgroundColor, value: color, range: highlight.range.nsRange)
            mutable.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: highlight.range.nsRange
            )
            mutable.addAttribute(
                .underlineColor,
                value: highlight.isIncludedInPrompt ? NSColor.systemYellow : NSColor.secondaryLabelColor,
                range: highlight.range.nsRange
            )
        }

        return mutable
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: ReaderTextView?
        var sourceMap = MarkdownSourceMap()
        var onSelectionChange: (ReaderSelection?) -> Void = { _ in }
        var onVisibleHeadingChange: (UUID?) -> Void = { _ in }
        var onAnnotationButtonPress: () -> Void = {}
        var lastRenderSignature = ""
        var lastHighlightSignature = ""
        var lastLayoutWidth: CGFloat = 0
        var lastScrollTargetHeadingID: UUID?
        var lastScrollTargetRange: RenderedTextRange?
        var lastEmittedSelection: ReaderSelection?
        var lastEmittedVisibleHeadingID: UUID?
        private weak var observedScrollView: NSScrollView?
        private var annotationButton: AnnotationButton?

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func updateAnnotationButton(in scrollView: NSScrollView, rect: CGRect?, isActive: Bool) {
            guard let rect else {
                annotationButton?.removeFromSuperview()
                annotationButton = nil
                return
            }

            let button = annotationButton ?? makeAnnotationButton()
            if button.superview !== scrollView {
                button.removeFromSuperview()
                scrollView.addSubview(button, positioned: .above, relativeTo: nil)
            }

            button.onPress = { [weak self] in
                self?.onAnnotationButtonPress()
            }
            button.applyAppearance(isActive: isActive)
            let originY = scrollView.isFlipped ? rect.minY : scrollView.bounds.height - rect.maxY
            button.frame = CGRect(x: rect.minX, y: originY, width: rect.width, height: rect.height)
        }

        private func makeAnnotationButton() -> AnnotationButton {
            let button = AnnotationButton(title: "批注 +", target: nil, action: nil)
            button.image = nil
            button.isBordered = false
            button.controlSize = .small
            button.setButtonType(.momentaryPushIn)
            button.focusRingType = .none
            button.setAccessibilityLabel("添加批注")
            button.toolTip = "添加批注"
            button.wantsLayer = true
            annotationButton = button
            return button
        }

        func attach(to scrollView: NSScrollView) {
            guard observedScrollView !== scrollView else {
                return
            }

            if let observedScrollView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedScrollView.contentView
                )
            }

            observedScrollView = scrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
            )
        }

        @objc private func scrollViewBoundsDidChange(_ notification: Notification) {
            guard let scrollView = observedScrollView,
                  notification.object as? NSClipView === scrollView.contentView
            else {
                return
            }

            emitVisibleHeading(from: scrollView)
            emitCurrentSelection(from: scrollView.documentView as? NSTextView)
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            emitCurrentSelection(from: textView)
        }

        private func emitCurrentSelection(from textView: NSTextView?) {
            guard let textView else {
                emitSelection(nil)
                return
            }

            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0,
                  selectedRange.location >= 0,
                  selectedRange.location + selectedRange.length <= (textView.string as NSString).length
            else {
                emitSelection(nil)
                return
            }

            let selectedText = (textView.string as NSString).substring(with: selectedRange)
            let renderedRange = RenderedTextRange(location: selectedRange.location, length: selectedRange.length)
            let selection = ReaderSelection(
                selectedText: selectedText,
                renderedRange: renderedRange,
                sourceRange: sourceMap.sourceRange(containing: renderedRange),
                visibleSelectionRect: visibleSelectionRect(in: textView, range: selectedRange),
                annotationButtonRect: annotationButtonRect(in: textView, range: selectedRange)
            )

            emitSelection(selection)
        }

        private func emitSelection(_ selection: ReaderSelection?) {
            guard selection != lastEmittedSelection else {
                return
            }

            lastEmittedSelection = selection
            DispatchQueue.main.async { [onSelectionChange] in
                onSelectionChange(selection)
            }
        }

        func emitVisibleHeading(from scrollView: NSScrollView) {
            guard let textView,
                  let visibleLocation = visibleTextLocation(in: textView, scrollView: scrollView)
            else {
                emitVisibleHeadingID(nil)
                return
            }

            let headingID = MarkdownReaderLayoutMetrics.currentHeadingID(
                forVisibleLocation: visibleLocation,
                in: sourceMap
            )
            emitVisibleHeadingID(headingID)
        }

        private func emitVisibleHeadingID(_ headingID: UUID?) {
            guard headingID != lastEmittedVisibleHeadingID else {
                return
            }

            lastEmittedVisibleHeadingID = headingID
            DispatchQueue.main.async { [onVisibleHeadingChange] in
                onVisibleHeadingChange(headingID)
            }
        }

        private func visibleTextLocation(in textView: NSTextView, scrollView: NSScrollView) -> Int? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  textView.string.isEmpty == false
            else {
                return nil
            }

            layoutManager.ensureLayout(for: textContainer)
            let visibleRect = scrollView.documentVisibleRect
            let containerOrigin = textView.textContainerOrigin
            let probeY = max(0, visibleRect.minY - containerOrigin.y + 72)
            let probePoint = NSPoint(x: 4, y: probeY)
            let characterIndex = layoutManager.characterIndex(
                for: probePoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            return min(characterIndex, max(0, (textView.string as NSString).length - 1))
        }

        private func visibleSelectionRect(in textView: NSTextView, range: NSRange) -> CGRect? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let scrollView = textView.enclosingScrollView
            else {
                return nil
            }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            rect.origin.x += textView.textContainerOrigin.x
            rect.origin.y += textView.textContainerOrigin.y

            let visibleRect = scrollView.documentVisibleRect
            let visibleSelectionRect = rect.intersection(visibleRect)
            guard visibleSelectionRect.isNull == false,
                  visibleSelectionRect.isEmpty == false
            else {
                return nil
            }

            let converted = textView.convert(visibleSelectionRect, to: scrollView)
            return CGRect(
                x: converted.minX,
                y: converted.minY,
                width: converted.width,
                height: converted.height
            )
        }

        private func annotationButtonRect(in textView: NSTextView, range: NSRange) -> CGRect? {
            guard let scrollView = textView.enclosingScrollView,
                  let visibleSelectionRect = visibleSelectionRect(in: textView, range: range)
            else {
                return nil
            }

            return MarkdownReaderLayoutMetrics.annotationButtonRect(
                forVisibleSelectionRect: visibleSelectionRect,
                viewportSize: scrollView.bounds.size
            )
        }
    }
}

public struct AnnotationEntryButtonPresentation: Equatable, Sendable {
    public var title: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHelp: String
    public var backgroundAlpha: Double
    public var borderWidth: Double
    public var shadowOpacity: Double
    public var shadowRadius: Double
    public var shadowYOffset: Double

    public init(
        title: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHelp: String,
        backgroundAlpha: Double,
        borderWidth: Double,
        shadowOpacity: Double,
        shadowRadius: Double,
        shadowYOffset: Double
    ) {
        self.title = title
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHelp = accessibilityHelp
        self.backgroundAlpha = backgroundAlpha
        self.borderWidth = borderWidth
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowYOffset = shadowYOffset
    }

    public static func presentation(
        isActive: Bool,
        isHovered: Bool,
        isPressed: Bool
    ) -> AnnotationEntryButtonPresentation {
        if isActive {
            return AnnotationEntryButtonPresentation(
                title: "批注 +",
                help: "批注输入框已打开",
                accessibilityLabel: "批注输入框已打开",
                accessibilityHelp: "输入意见后按 ⌘↩ 保存，按 Esc 取消",
                backgroundAlpha: 0.14,
                borderWidth: 1.2,
                shadowOpacity: 0.22,
                shadowRadius: 12,
                shadowYOffset: 4
            )
        }

        if isPressed {
            return AnnotationEntryButtonPresentation(
                title: "批注 +",
                help: "正在打开批注输入框",
                accessibilityLabel: "正在打开批注输入框",
                accessibilityHelp: "松开后会打开批注输入框；会保留当前选区",
                backgroundAlpha: 0.18,
                borderWidth: 1.3,
                shadowOpacity: 0.2,
                shadowRadius: 12,
                shadowYOffset: 4
            )
        }

        if isHovered {
            return AnnotationEntryButtonPresentation(
                title: "批注 +",
                help: "点击为当前选区添加批注",
                accessibilityLabel: "为选区添加批注",
                accessibilityHelp: "按 Return 打开批注输入框；会保留当前选区",
                backgroundAlpha: 0.08,
                borderWidth: 1.1,
                shadowOpacity: 0.18,
                shadowRadius: 11,
                shadowYOffset: 4
            )
        }

        return AnnotationEntryButtonPresentation(
            title: "批注 +",
            help: "为当前选区添加批注",
            accessibilityLabel: "为选区添加批注",
            accessibilityHelp: "按 Return 打开批注输入框；会保留当前选区",
            backgroundAlpha: 0,
            borderWidth: 1,
            shadowOpacity: 0.14,
            shadowRadius: 9,
            shadowYOffset: 3
        )
    }
}

private final class AnnotationButton: NSButton {
    var onPress: () -> Void = {}
    private var isActiveAppearance = false
    private var isHovering = false
    private var hoverTrackingArea: NSTrackingArea?

    func applyAppearance(isActive: Bool) {
        isActiveAppearance = isActive
        updateAppearance()
    }

    override var isHighlighted: Bool {
        didSet {
            updateAppearance()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    private func updateAppearance() {
        wantsLayer = true
        let presentation = AnnotationEntryButtonPresentation.presentation(
            isActive: isActiveAppearance,
            isHovered: isHovering,
            isPressed: isHighlighted
        )
        let isInteractive = isActiveAppearance || isHovering || isHighlighted
        let foregroundColor = NSColor.systemOrange
        let backgroundColor = presentation.backgroundAlpha > 0
            ? NSColor.systemOrange.withAlphaComponent(presentation.backgroundAlpha)
            : NSColor.textBackgroundColor
        let borderColor = isInteractive ? NSColor.systemOrange : NSColor.separatorColor

        attributedTitle = NSAttributedString(
            string: presentation.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: foregroundColor
            ]
        )
        contentTintColor = foregroundColor
        toolTip = presentation.help
        setAccessibilityLabel(presentation.accessibilityLabel)
        setAccessibilityHelp(presentation.accessibilityHelp)
        layer?.cornerRadius = 8
        layer?.borderWidth = presentation.borderWidth
        layer?.borderColor = borderColor.cgColor
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = Float(presentation.shadowOpacity)
        layer?.shadowRadius = presentation.shadowRadius
        layer?.shadowOffset = CGSize(width: 0, height: presentation.shadowYOffset)
        layer?.masksToBounds = false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        isHighlighted = true
        defer {
            isHighlighted = false
        }
        onPress()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
