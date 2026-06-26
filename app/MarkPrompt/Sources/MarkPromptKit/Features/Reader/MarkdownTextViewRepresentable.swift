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
        forSelectionRectInViewport selectionRect: CGRect,
        viewportSize: CGSize,
        buttonSize: CGSize = CGSize(width: 100, height: 32),
        margin: CGFloat = 12,
        gap: CGFloat = 10
    ) -> CGRect? {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              selectionRect.isNull == false,
              selectionRect.isInfinite == false
        else {
            return nil
        }

        let maximumX = max(margin, viewportSize.width - buttonSize.width - margin)
        let rightSideX = selectionRect.maxX + gap
        let leftSideX = selectionRect.minX - buttonSize.width - gap
        let preferredX = if rightSideX + buttonSize.width <= viewportSize.width - margin {
            rightSideX
        } else if leftSideX >= margin {
            leftSideX
        } else {
            min(maximumX, max(margin, rightSideX))
        }

        let maximumY = max(margin, viewportSize.height - buttonSize.height - margin)
        let preferredY = viewportSize.height - selectionRect.maxY
        let x = min(maximumX, max(margin, preferredX))
        let y = min(maximumY, max(margin, preferredY))

        return CGRect(origin: CGPoint(x: x, y: y), size: buttonSize)
    }
}

public struct MarkdownTextViewRepresentable: NSViewRepresentable {
    public var attributedText: NSAttributedString
    public var sourceMap: MarkdownSourceMap
    public var highlights: [AnnotationHighlight]
    public var scrollTargetHeadingID: UUID?
    public var scrollTargetRange: RenderedTextRange?
    public var onSelectionChange: (ReaderSelection?) -> Void
    public var onScrollTargetConsumed: () -> Void
    public var onVisibleHeadingChange: (UUID?) -> Void

    public init(
        attributedText: NSAttributedString,
        sourceMap: MarkdownSourceMap,
        highlights: [AnnotationHighlight],
        scrollTargetHeadingID: UUID?,
        scrollTargetRange: RenderedTextRange?,
        onSelectionChange: @escaping (ReaderSelection?) -> Void,
        onScrollTargetConsumed: @escaping () -> Void = {},
        onVisibleHeadingChange: @escaping (UUID?) -> Void = { _ in }
    ) {
        self.attributedText = attributedText
        self.sourceMap = sourceMap
        self.highlights = highlights
        self.scrollTargetHeadingID = scrollTargetHeadingID
        self.scrollTargetRange = scrollTargetRange
        self.onSelectionChange = onSelectionChange
        self.onScrollTargetConsumed = onScrollTargetConsumed
        self.onVisibleHeadingChange = onVisibleHeadingChange
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
        context.coordinator.sourceMap = sourceMap

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
            context.coordinator.lastLayoutWidth = contentWidth

            if !hasExplicitScrollTarget {
                restoreScrollPosition(in: scrollView, to: preservedScrollOrigin)
            }
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
            DispatchQueue.main.async {
                onScrollTargetConsumed()
            }
        } else if scrollTargetHeadingID == nil {
            context.coordinator.lastScrollTargetHeadingID = nil
        }

        if let scrollTargetRange,
           context.coordinator.lastScrollTargetRange != scrollTargetRange {
            textView.scrollRangeToVisible(scrollTargetRange.nsRange)
            textView.showFindIndicator(for: scrollTargetRange.nsRange)
            context.coordinator.lastScrollTargetRange = scrollTargetRange
            context.coordinator.emitVisibleHeading(from: scrollView)
            DispatchQueue.main.async {
                onScrollTargetConsumed()
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
        var lastRenderSignature = ""
        var lastHighlightSignature = ""
        var lastLayoutWidth: CGFloat = 0
        var lastScrollTargetHeadingID: UUID?
        var lastScrollTargetRange: RenderedTextRange?
        var lastEmittedSelection: ReaderSelection?
        var lastEmittedVisibleHeadingID: UUID?
        private weak var observedScrollView: NSScrollView?

        deinit {
            NotificationCenter.default.removeObserver(self)
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
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
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
                selectionRect: selectionRect(in: textView, range: selectedRange)
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

        private func selectionRect(in textView: NSTextView, range: NSRange) -> CGRect? {
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
            let anchorRect = visibleSelectionRect.isNull ? rect : visibleSelectionRect
            let converted = textView.convert(anchorRect, to: scrollView)
            return MarkdownReaderLayoutMetrics.annotationButtonRect(
                forSelectionRectInViewport: converted,
                viewportSize: scrollView.bounds.size
            )
        }
    }
}
