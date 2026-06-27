import AppKit
@testable import MarkPromptKit
import XCTest

@MainActor
final class ReaderFixtureRenderingTests: XCTestCase {
    func testReaderFixtureSetContainsTenMarkdownDocuments() throws {
        let fixtures = try fixtureURLs()

        XCTAssertEqual(fixtures.count, 10)
        XCTAssertEqual(fixtures.first?.lastPathComponent, "01_headings_inline.md")
        XCTAssertEqual(fixtures.last?.lastPathComponent, "10_review_prd_mix.md")
    }

    func testAllReaderFixturesParseAndLayoutAtReaderWidths() throws {
        for url in try fixtureURLs() {
            let source = try String(contentsOf: url, encoding: .utf8)
            let document = MarkdownParser().parse(source, fileURL: url)

            XCTAssertFalse(document.renderModel.renderedPlainText.isEmpty, url.lastPathComponent)
            XCTAssertFalse(document.renderModel.sourceMap.blocks.isEmpty, url.lastPathComponent)
            XCTAssertFalse(document.renderModel.renderedPlainText.contains("┌"), url.lastPathComponent)
            XCTAssertFalse(document.renderModel.renderedPlainText.contains("└"), url.lastPathComponent)
            XCTAssertNoThrow(try layout(document.renderModel.attributedText, width: 760), url.lastPathComponent)
            XCTAssertNoThrow(try layout(document.renderModel.attributedText, width: 520), url.lastPathComponent)
        }
    }

    func testAnnotationButtonRectStaysNearVisibleSelectionAndInsideViewport() throws {
        let viewport = CGSize(width: 500, height: 600)

        let normal = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 120, y: 220, width: 80, height: 24),
            viewportSize: viewport
        ))
        XCTAssertEqual(normal.origin.x, 208, accuracy: 0.01)
        XCTAssertEqual(normal.origin.y, 214, accuracy: 0.01)
        XCTAssertEqual(normal.maxX, 292, accuracy: 0.01)

        let nearRightEdge = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 450, y: 220, width: 42, height: 24),
            viewportSize: viewport
        ))
        XCTAssertEqual(nearRightEdge.origin.x, 358, accuracy: 0.01)
        XCTAssertEqual(nearRightEdge.origin.y, 214, accuracy: 0.01)

        let nearTopEdge = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 180, y: 4, width: 120, height: 18),
            viewportSize: viewport
        ))
        XCTAssertEqual(nearTopEdge.origin.x, 308, accuracy: 0.01)
        XCTAssertEqual(nearTopEdge.origin.y, 12, accuracy: 0.01)

        let nearBottomEdge = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 180, y: 576, width: 120, height: 18),
            viewportSize: viewport
        ))
        XCTAssertEqual(nearBottomEdge.origin.x, 308, accuracy: 0.01)
        XCTAssertEqual(nearBottomEdge.origin.y, 552, accuracy: 0.01)

        let tallVisibleSelection = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 90, y: 240, width: 280, height: 96),
            viewportSize: viewport
        ))
        XCTAssertEqual(tallVisibleSelection.origin.x, 378, accuracy: 0.01)
        XCTAssertEqual(tallVisibleSelection.origin.y, 270, accuracy: 0.01)

        let oversizedSelection = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: -30, y: -40, width: 640, height: 720),
            viewportSize: viewport
        ))
        XCTAssertGreaterThanOrEqual(oversizedSelection.minX, 12)
        XCTAssertGreaterThanOrEqual(oversizedSelection.minY, 12)
        XCTAssertLessThanOrEqual(oversizedSelection.maxX, viewport.width - 12)
        XCTAssertLessThanOrEqual(oversizedSelection.maxY, viewport.height - 12)
    }

    func testAnnotationButtonRectFallsBackAboveWhenSelectionConsumesSideGutters() throws {
        let buttonRect = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 40, y: 220, width: 420, height: 24),
            viewportSize: CGSize(width: 500, height: 600)
        ))

        XCTAssertEqual(buttonRect.origin.x, 208, accuracy: 0.01)
        XCTAssertEqual(buttonRect.origin.y, 176, accuracy: 0.01)
    }

    func testAnnotationPopoverArrowEdgePointsBackTowardSelection() {
        let selectionRect = CGRect(x: 120, y: 220, width: 80, height: 24)

        XCTAssertEqual(
            MarkdownReaderLayoutMetrics.annotationPopoverArrowEdge(
                visibleSelectionRect: selectionRect,
                annotationButtonRect: CGRect(x: 210, y: 216, width: 100, height: 32)
            ),
            .leading
        )
        XCTAssertEqual(
            MarkdownReaderLayoutMetrics.annotationPopoverArrowEdge(
                visibleSelectionRect: selectionRect,
                annotationButtonRect: CGRect(x: 10, y: 216, width: 100, height: 32)
            ),
            .trailing
        )
    }

    func testAnnotationPopoverRectPrefersVerticalSpaceAwayFromAnnotationLine() {
        let viewport = CGSize(width: 500, height: 600)
        let selectionRect = CGRect(x: 120, y: 160, width: 120, height: 24)
        let upperButton = CGRect(x: 144, y: 106, width: 72, height: 44)

        let lowerPopoverForUpperButton = MarkdownReaderLayoutMetrics.annotationPopoverRect(
            forAnnotationButtonRect: upperButton,
            avoidingVisibleSelectionRect: selectionRect,
            viewportSize: viewport
        )

        XCTAssertGreaterThanOrEqual(lowerPopoverForUpperButton.minY, selectionRect.maxY + 11.99)

        let lowerButton = CGRect(x: 210, y: 360, width: 100, height: 32)

        let upperPopover = MarkdownReaderLayoutMetrics.annotationPopoverRect(
            forAnnotationButtonRect: lowerButton,
            viewportSize: viewport
        )

        XCTAssertLessThanOrEqual(upperPopover.maxY, lowerButton.minY - 9.99)
        XCTAssertGreaterThanOrEqual(upperPopover.minY, 11.99)

        let topButton = CGRect(x: 210, y: 40, width: 100, height: 32)

        let lowerPopover = MarkdownReaderLayoutMetrics.annotationPopoverRect(
            forAnnotationButtonRect: topButton,
            viewportSize: viewport
        )

        XCTAssertGreaterThanOrEqual(lowerPopover.minY, topButton.maxY + 9.99)
        XCTAssertLessThanOrEqual(lowerPopover.maxY, viewport.height - 11.99)
    }

    func testScrollingReemitsSelectionWithUpdatedAnnotationButtonRect() throws {
        let text = """
        Target paragraph for annotation.

        The reader keeps this document long enough to scroll while preserving selection.
        The reader keeps this document long enough to scroll while preserving selection.
        The reader keeps this document long enough to scroll while preserving selection.
        The reader keeps this document long enough to scroll while preserving selection.
        """
        let storage = NSTextStorage(attributedString: NSAttributedString(string: text))
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 300))
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 420, height: 520),
            textContainer: textContainer
        )
        textView.textContainerInset = NSSize(width: 24, height: 24)
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        layoutManager.ensureLayout(for: textContainer)

        let coordinator = MarkdownTextViewRepresentable.Coordinator()
        coordinator.textView = textView
        coordinator.attach(to: scrollView)

        var emittedSelections: [ReaderSelection] = []
        coordinator.onSelectionChange = { selection in
            if let selection {
                emittedSelections.append(selection)
            }
        }

        let selectedRange = (textView.string as NSString).range(of: "The reader keeps")
        textView.setSelectedRange(selectedRange)
        coordinator.textViewDidChangeSelection(Notification(
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        ))
        waitForMainQueue()
        let initialVisibleSelectionRect = try XCTUnwrap(emittedSelections.last?.visibleSelectionRect)
        let initialButtonRect = try XCTUnwrap(emittedSelections.last?.annotationButtonRect)

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 18))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        NotificationCenter.default.post(
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        waitForMainQueue()

        XCTAssertGreaterThanOrEqual(emittedSelections.count, 2)
        let scrolledVisibleSelectionRect = try XCTUnwrap(emittedSelections.last?.visibleSelectionRect)
        let scrolledButtonRect = try XCTUnwrap(emittedSelections.last?.annotationButtonRect)
        XCTAssertNotEqual(scrolledVisibleSelectionRect, initialVisibleSelectionRect)
        XCTAssertNotEqual(scrolledButtonRect, initialButtonRect)
        let expectedButtonRect = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: scrolledVisibleSelectionRect,
            viewportSize: scrollView.bounds.size
        ))
        XCTAssertEqual(scrolledButtonRect.origin.x, expectedButtonRect.origin.x, accuracy: 0.01)
        XCTAssertEqual(scrolledButtonRect.origin.y, expectedButtonRect.origin.y, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(scrolledButtonRect.minX, 12)
        XCTAssertGreaterThanOrEqual(scrolledButtonRect.minY, 12)
        XCTAssertLessThanOrEqual(scrolledButtonRect.maxX, scrollView.bounds.width - 12)
        XCTAssertLessThanOrEqual(scrolledButtonRect.maxY, scrollView.bounds.height - 12)
    }

    func testRenderSignatureChangesWhenTextBecomesNativeTableBlock() {
        let plain = NSAttributedString(string: "Model\n")
        let table = NSTextTable()
        table.numberOfColumns = 1
        table.layoutAlgorithm = .fixedLayoutAlgorithm
        table.setContentWidth(160, type: .absoluteValueType)

        let block = NSTextTableBlock(
            table: table,
            startingRow: 0,
            rowSpan: 1,
            startingColumn: 0,
            columnSpan: 1
        )
        block.setValue(160, type: .absoluteValueType, for: .width)
        block.setWidth(0.5, type: .absoluteValueType, for: .border)
        block.setWidth(6, type: .absoluteValueType, for: .padding)

        let paragraph = NSMutableParagraphStyle()
        paragraph.textBlocks = [block]
        let nativeTable = NSAttributedString(
            string: "Model\n",
            attributes: [.paragraphStyle: paragraph]
        )

        XCTAssertEqual(plain.string, nativeTable.string)
        XCTAssertNotEqual(
            MarkdownReaderLayoutMetrics.renderSignature(for: plain),
            MarkdownReaderLayoutMetrics.renderSignature(for: nativeTable)
        )
    }

    func testReaderTextViewTaskMarkerHitTestingUsesOnlyCheckboxGlyph() throws {
        let markerRange = SourceTextRange(lowerBound: 12, upperBound: 15)
        let attributed = NSMutableAttributedString(string: "☐ Review anchor recovery")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: markerRange,
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 80),
            textContainer: textContainer
        )
        layoutManager.ensureLayout(for: textContainer)

        XCTAssertEqual(textView.taskMarkerSourceRange(atCharacterIndex: 0), markerRange)
        XCTAssertNil(textView.taskMarkerSourceRange(atCharacterIndex: 2))
        XCTAssertNil(textView.taskMarkerSourceRange(atCharacterIndex: attributed.length))

        let markerGlyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: 0, length: 1),
            actualCharacterRange: nil
        )
        var markerRect = layoutManager.boundingRect(
            forGlyphRange: markerGlyphRange,
            in: textContainer
        )
        markerRect.origin.x += textView.textContainerOrigin.x
        markerRect.origin.y += textView.textContainerOrigin.y

        let markerHitRect = try XCTUnwrap(textView.taskMarkerHitRect(atCharacterIndex: 0))
        XCTAssertTrue(markerHitRect.contains(NSPoint(x: markerRect.midX, y: markerRect.midY)))
        XCTAssertFalse(markerHitRect.contains(NSPoint(x: markerRect.maxX + 12, y: markerRect.midY)))
        XCTAssertNil(textView.taskMarkerHitRect(atCharacterIndex: 2))
        XCTAssertEqual(textView.taskMarkerHitRects(), [markerHitRect])

        XCTAssertEqual(
            textView.taskMarkerSourceRange(at: NSPoint(x: markerRect.midX, y: markerRect.midY)),
            markerRange
        )
        XCTAssertNil(textView.taskMarkerSourceRange(at: NSPoint(x: markerRect.maxX + 12, y: markerRect.midY)))
    }

    func testReaderTextViewKeyboardToggleUsesOnlyCheckboxSelection() {
        let markerRange = SourceTextRange(lowerBound: 12, upperBound: 15)
        let attributed = NSMutableAttributedString(string: "◩ Review anchor recovery")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: markerRange,
            range: NSRange(location: 0, length: 1)
        )
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerCharacter"),
            value: "/",
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 80),
            textContainer: textContainer
        )

        textView.setSelectedRange(NSRange(location: 0, length: 1))
        XCTAssertEqual(textView.taskMarkerSourceRangeForKeyboardToggle(), markerRange)

        textView.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertEqual(textView.taskMarkerSourceRangeForKeyboardToggle(), markerRange)

        textView.setSelectedRange(NSRange(location: 2, length: 1))
        XCTAssertNil(textView.taskMarkerSourceRangeForKeyboardToggle())

        textView.setSelectedRange(NSRange(location: 0, length: 3))
        XCTAssertNil(textView.taskMarkerSourceRangeForKeyboardToggle())
    }

    func testReaderTextViewKeyboardToggleIgnoresModifiedSpaceShortcuts() {
        let markerRange = SourceTextRange(lowerBound: 12, upperBound: 15)
        let attributed = NSMutableAttributedString(string: "◩ Review anchor recovery")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: markerRange,
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 80),
            textContainer: textContainer
        )
        var toggleCount = 0
        textView.onTaskMarkerClick = { sourceRange in
            XCTAssertEqual(sourceRange, markerRange)
            toggleCount += 1
            return true
        }
        textView.setSelectedRange(NSRange(location: 0, length: 1))

        textView.keyDown(with: spaceKeyEvent())
        XCTAssertEqual(toggleCount, 1)

        for flags in [NSEvent.ModifierFlags.command, .option, .control] {
            textView.keyDown(with: spaceKeyEvent(modifierFlags: flags))
        }
        XCTAssertEqual(toggleCount, 1)
    }

    func testReaderTextViewTaskMarkerCommandTogglesOnlyCheckboxSelection() {
        let markerRange = SourceTextRange(lowerBound: 12, upperBound: 15)
        let attributed = NSMutableAttributedString(string: "◩ Review anchor recovery")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: markerRange,
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 80),
            textContainer: textContainer
        )
        let commandSelector = #selector(ReaderTextView.toggleTaskMarkerStatus(_:))
        var receivedSourceRange: SourceTextRange?
        textView.onTaskMarkerClick = { sourceRange in
            receivedSourceRange = sourceRange
            return true
        }

        textView.setSelectedRange(NSRange(location: 0, length: 1))

        XCTAssertTrue(textView.responds(to: commandSelector))
        XCTAssertTrue(textView.tryToPerform(commandSelector, with: nil))
        XCTAssertEqual(receivedSourceRange, markerRange)

        let forwardedTextView = ReaderTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 80), textContainer: nil)
        let probeResponder = TaskMarkerCommandProbeResponder()
        forwardedTextView.nextResponder = probeResponder

        XCTAssertTrue(forwardedTextView.tryToPerform(commandSelector, with: nil))
        XCTAssertEqual(probeResponder.toggleCount, 1)
    }

    func testReaderTextViewValidatesTaskMarkerCommandOnlyForCheckboxSelection() {
        let markerRange = SourceTextRange(lowerBound: 12, upperBound: 15)
        let attributed = NSMutableAttributedString(string: "◩ Review anchor recovery")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: markerRange,
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 80),
            textContainer: textContainer
        )
        let commandItem = NSMenuItem(
            title: "切换任务状态",
            action: #selector(ReaderTextView.toggleTaskMarkerStatus(_:)),
            keyEquivalent: "l"
        )

        textView.setSelectedRange(NSRange(location: 0, length: 1))
        XCTAssertTrue(textView.validateUserInterfaceItem(commandItem))

        textView.setSelectedRange(NSRange(location: 2, length: 1))
        XCTAssertFalse(textView.validateUserInterfaceItem(commandItem))

        textView.setSelectedRange(NSRange(location: 0, length: 3))
        XCTAssertFalse(textView.validateUserInterfaceItem(commandItem))
    }

    func testReaderTextViewTaskMarkerNavigationMovesSelectionBetweenCheckboxes() {
        let attributed = NSMutableAttributedString(string: "☐ First task\nBody copy\n◩ Second task\n☑ Third task")
        let firstIndex = 0
        let secondIndex = (attributed.string as NSString).range(of: "◩").location
        let thirdIndex = (attributed.string as NSString).range(of: "☑").location
        for (index, sourceLocation) in [(firstIndex, 2), (secondIndex, 18), (thirdIndex, 36)] {
            attributed.addAttribute(
                NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
                value: SourceTextRange(lowerBound: sourceLocation, upperBound: sourceLocation + 3),
                range: NSRange(location: index, length: 1)
            )
        }
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 360, height: 120),
            textContainer: textContainer
        )
        let nextSelector = #selector(ReaderTextView.selectNextTaskMarker(_:))
        let previousSelector = #selector(ReaderTextView.selectPreviousTaskMarker(_:))

        textView.setSelectedRange(NSRange(location: firstIndex, length: 1))

        XCTAssertTrue(textView.responds(to: nextSelector))
        XCTAssertTrue(textView.tryToPerform(nextSelector, with: nil))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: secondIndex, length: 1))

        XCTAssertTrue(textView.tryToPerform(nextSelector, with: nil))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: thirdIndex, length: 1))

        XCTAssertTrue(textView.tryToPerform(nextSelector, with: nil))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: firstIndex, length: 1))

        XCTAssertTrue(textView.responds(to: previousSelector))
        XCTAssertTrue(textView.tryToPerform(previousSelector, with: nil))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: thirdIndex, length: 1))

        textView.setSelectedRange(NSRange(location: 4, length: 1))
        XCTAssertTrue(textView.tryToPerform(nextSelector, with: nil))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: secondIndex, length: 1))
    }

    func testReaderTextViewValidatesTaskMarkerNavigationOnlyWhenTasksExist() {
        let attributed = NSMutableAttributedString(string: "☐ First task")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: SourceTextRange(lowerBound: 2, upperBound: 5),
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 80),
            textContainer: textContainer
        )
        let nextItem = NSMenuItem(
            title: "下一个任务",
            action: #selector(ReaderTextView.selectNextTaskMarker(_:)),
            keyEquivalent: "j"
        )
        let previousItem = NSMenuItem(
            title: "上一个任务",
            action: #selector(ReaderTextView.selectPreviousTaskMarker(_:)),
            keyEquivalent: "k"
        )

        XCTAssertTrue(textView.validateUserInterfaceItem(nextItem))
        XCTAssertTrue(textView.validateUserInterfaceItem(previousItem))

        let emptyTextView = ReaderTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 80), textContainer: nil)
        XCTAssertFalse(emptyTextView.validateUserInterfaceItem(nextItem))
        XCTAssertFalse(emptyTextView.validateUserInterfaceItem(previousItem))
    }

    func testReaderTextViewUndoActionDelegatesToTaskMarkerUndoHandler() {
        let textView = ReaderTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 80), textContainer: nil)
        var undoCount = 0

        textView.onTaskMarkerUndo = {
            undoCount += 1
            return true
        }

        textView.undo(nil)

        XCTAssertEqual(undoCount, 1)

        let forwardedTextView = ReaderTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 80), textContainer: nil)
        let probeResponder = UndoProbeResponder()
        var rejectedUndoCount = 0
        forwardedTextView.nextResponder = probeResponder
        forwardedTextView.onTaskMarkerUndo = {
            rejectedUndoCount += 1
            return false
        }

        forwardedTextView.undo(nil)

        XCTAssertEqual(rejectedUndoCount, 1)
        XCTAssertEqual(probeResponder.undoCount, 1)
    }

    func testReaderTextViewTaskMarkerContextMenuOffersStatusChangesOnlyOnCheckboxGlyph() throws {
        let markerRange = SourceTextRange(lowerBound: 12, upperBound: 15)
        let attributed = NSMutableAttributedString(string: "◩ Review anchor recovery")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: markerRange,
            range: NSRange(location: 0, length: 1)
        )
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerCharacter"),
            value: "/",
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 80),
            textContainer: textContainer
        )
        layoutManager.ensureLayout(for: textContainer)

        let markerGlyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: 0, length: 1),
            actualCharacterRange: nil
        )
        var markerRect = layoutManager.boundingRect(
            forGlyphRange: markerGlyphRange,
            in: textContainer
        )
        markerRect.origin.x += textView.textContainerOrigin.x
        markerRect.origin.y += textView.textContainerOrigin.y

        let menu = try XCTUnwrap(textView.taskMarkerStatusMenu(at: NSPoint(x: markerRect.midX, y: markerRect.midY)))
        XCTAssertEqual(menu.title, "任务状态：进行中")
        XCTAssertEqual(menu.items.map(\.title), [
            "标记为待办",
            "标记为完成",
            "标记为取消",
            "当前：进行中",
            "标记为重要"
        ])
        let currentItem = try XCTUnwrap(menu.items.first { $0.title == "当前：进行中" })
        XCTAssertEqual(currentItem.state, .on)
        XCTAssertFalse(currentItem.isEnabled)
        XCTAssertEqual(currentItem.toolTip, "当前状态：进行中。选择其它状态只更改这一项任务，阅读位置保持不变。")
        let importantItem = try XCTUnwrap(menu.items.first { $0.title == "标记为重要" })
        XCTAssertEqual(importantItem.toolTip, "将当前任务标记为重要；只更改这一项任务，阅读位置保持不变")
        XCTAssertEqual(importantItem.accessibilityLabel(), "将当前任务标记为重要")
        XCTAssertEqual(importantItem.accessibilityHelp(), "只更改这一项任务；菜单关闭后阅读位置保持不变")
        XCTAssertNil(textView.taskMarkerStatusMenu(at: NSPoint(x: markerRect.maxX + 12, y: markerRect.midY)))

        var receivedSourceRange: SourceTextRange?
        var receivedMarkerCharacter: String?
        textView.onTaskMarkerStatusChange = { sourceRange, markerCharacter in
            receivedSourceRange = sourceRange
            receivedMarkerCharacter = markerCharacter
            return true
        }

        textView.changeTaskMarkerStatus(importantItem)

        XCTAssertEqual(receivedSourceRange, markerRange)
        XCTAssertEqual(receivedMarkerCharacter, "!")
    }

    func testReaderTextViewTaskMarkerContextMenuTreatsCustomCompletedMarkersAsCurrentCompleted() throws {
        let markerRange = SourceTextRange(lowerBound: 12, upperBound: 15)
        let attributed = NSMutableAttributedString(string: "☑ Arbitrary completed review task")
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"),
            value: markerRange,
            range: NSRange(location: 0, length: 1)
        )
        attributed.addAttribute(
            NSAttributedString.Key("MarkPromptTaskMarkerCharacter"),
            value: "a",
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 80),
            textContainer: textContainer
        )
        layoutManager.ensureLayout(for: textContainer)

        let markerRect = try XCTUnwrap(textView.taskMarkerHitRect(atCharacterIndex: 0))
        let menu = try XCTUnwrap(textView.taskMarkerStatusMenu(at: NSPoint(x: markerRect.midX, y: markerRect.midY)))

        XCTAssertEqual(menu.title, "任务状态：完成")
        XCTAssertEqual(menu.items.map(\.title), [
            "标记为待办",
            "当前：完成",
            "标记为取消",
            "标记为进行中",
            "标记为重要"
        ])
        let currentItem = try XCTUnwrap(menu.items.first { $0.title == "当前：完成" })
        XCTAssertFalse(currentItem.isEnabled)
        XCTAssertEqual(currentItem.state, .on)
    }

    func testReaderTextViewExposesTaskMarkersAsAccessibleCheckboxes() throws {
        let openRange = SourceTextRange(lowerBound: 2, upperBound: 5)
        let doneRange = SourceTextRange(lowerBound: 32, upperBound: 35)
        let attributed = NSMutableAttributedString(string: "☐ Review anchor recovery\n☑ Confirm local-first behavior")
        attributed.addAttributes(
            [
                NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"): openRange,
                NSAttributedString.Key("MarkPromptTaskMarkerCharacter"): " "
            ],
            range: NSRange(location: 0, length: 1)
        )
        attributed.addAttributes(
            [
                NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"): doneRange,
                NSAttributedString.Key("MarkPromptTaskMarkerCharacter"): "x"
            ],
            range: NSRange(location: 25, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 360, height: 120),
            textContainer: textContainer
        )
        layoutManager.ensureLayout(for: textContainer)

        let accessibleTasks = try XCTUnwrap(textView.accessibilityChildren()?.filter {
            ($0 as? NSAccessibilityElement)?.accessibilityRole() == .checkBox
        })
        XCTAssertEqual(accessibleTasks.count, 2)

        let firstTask = try XCTUnwrap(accessibleTasks.first as? NSAccessibilityElement)
        XCTAssertEqual(firstTask.accessibilityLabel(), "任务：Review anchor recovery")
        XCTAssertEqual(firstTask.accessibilityValue() as? NSNumber, NSNumber(value: false))
        XCTAssertEqual(firstTask.accessibilityValueDescription(), "待办")
        XCTAssertEqual(
            firstTask.accessibilityHelp(),
            "状态：待办。按 Space 或 Return 切换完成/待办；右键或自定义动作可设为待办、完成、取消、进行中、重要；⌘⌥J/K 跳到上/下一个任务。"
        )
        XCTAssertEqual(firstTask.accessibilityParent() as? ReaderTextView, textView)

        let secondTask = try XCTUnwrap(accessibleTasks.last as? NSAccessibilityElement)
        XCTAssertEqual(secondTask.accessibilityLabel(), "任务：Confirm local-first behavior")
        XCTAssertEqual(secondTask.accessibilityValue() as? NSNumber, NSNumber(value: true))
        XCTAssertEqual(secondTask.accessibilityValueDescription(), "完成")
        XCTAssertEqual(
            secondTask.accessibilityHelp(),
            "状态：完成。按 Space 或 Return 切换完成/待办；右键或自定义动作可设为待办、完成、取消、进行中、重要；⌘⌥J/K 跳到上/下一个任务。"
        )

        var pressedSourceRange: SourceTextRange?
        textView.onTaskMarkerClick = { sourceRange in
            pressedSourceRange = sourceRange
            return true
        }

        XCTAssertTrue(firstTask.accessibilityPerformPress())
        XCTAssertEqual(pressedSourceRange, openRange)
    }

    func testReaderTextViewAccessibleTaskCheckboxOffersStatusActions() throws {
        let markerRange = SourceTextRange(lowerBound: 18, upperBound: 21)
        let attributed = NSMutableAttributedString(string: "◩ Investigate annotation anchor drift")
        attributed.addAttributes(
            [
                NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"): markerRange,
                NSAttributedString.Key("MarkPromptTaskMarkerCharacter"): "/"
            ],
            range: NSRange(location: 0, length: 1)
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: 360, height: 80),
            textContainer: textContainer
        )
        layoutManager.ensureLayout(for: textContainer)

        let accessibleTask = try XCTUnwrap(textView.accessibilityChildren()?.compactMap {
            $0 as? NSAccessibilityElement
        }.first { $0.accessibilityRole() == .checkBox })
        XCTAssertEqual(accessibleTask.accessibilityValue() as? NSNumber, NSNumber(value: false))
        XCTAssertEqual(accessibleTask.accessibilityValueDescription(), "进行中")
        let actions = try XCTUnwrap(accessibleTask.accessibilityCustomActions())
        XCTAssertEqual(actions.map(\.name), [
            "仅当前任务：标记为待办",
            "仅当前任务：标记为完成",
            "仅当前任务：标记为取消",
            "仅当前任务：标记为重要"
        ])

        var receivedSourceRange: SourceTextRange?
        var receivedMarkerCharacter: String?
        textView.onTaskMarkerStatusChange = { sourceRange, markerCharacter in
            receivedSourceRange = sourceRange
            receivedMarkerCharacter = markerCharacter
            return true
        }

        let importantAction = try XCTUnwrap(actions.first { $0.name == "仅当前任务：标记为重要" })
        XCTAssertTrue(try XCTUnwrap(importantAction.handler?()))
        XCTAssertEqual(receivedSourceRange, markerRange)
        XCTAssertEqual(receivedMarkerCharacter, "!")
    }

    func testFixtureSpecificRenderingExpectations() throws {
        let documents = try parsedFixturesByName()

        let inline = try XCTUnwrap(documents["01_headings_inline.md"])
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("**bold claims**"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("H~2~O"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("x^2^"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains(":rocket:"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains(":sparkles:"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("==highlighted decisions=="))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("++inserted wording++"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("&amp;"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("&lt;"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("H2O"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("🚀"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("✨"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("highlighted decisions"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("inserted wording"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("A & B < C"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("API_TOKEN"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("snake_case"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("a_b_c"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("2 * 3"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("#reader/tag"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("#not-a-tag"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("https://example.com/live-url"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("https://example.com/code-url"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("*not italic*"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("_not emphasis_"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("[not a link](https://example.com/no-link)"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("![not an image](https://example.com/no-image.png)"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("\\*not italic\\*"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("\\_not emphasis\\_"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("Image: not an image"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("First hard-break line uses a backslash\nSecond line should stay visually separated. Soft wrapped text should merge with this line."))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("backslash\\"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("Setext H1 with heading code"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("Setext H2 with navigation link"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("Setext **H1**"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("================================="))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("------------------------------------------------------------"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("API design remains readable"))
        XCTAssertTrue(inline.renderModel.renderedPlainText.contains("API() should stay code"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("Application Programming Interface"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("~~removed wording~~"))
        XCTAssertTrue(inline.outline.flattened().contains { $0.title == "Setext H1 with heading code" })
        XCTAssertTrue(inline.outline.flattened().contains { $0.title == "Setext H2 with navigation link" })
        XCTAssertTrue(hasSubscriptAttribute(for: "H2O", character: "2", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasSuperscriptAttribute(for: "x2", character: "2", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "heading code", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "highlighted decisions", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "#reader/tag", in: inline.renderModel.attributedText))
        XCTAssertFalse(hasFixedPitchFont(for: "#reader/tag", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasFixedPitchFont(for: "#not-a-tag", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://example.com/live-url", in: inline.renderModel.attributedText))
        XCTAssertNil(attribute(.link, for: "https://example.com/code-url", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasFixedPitchFont(for: "https://example.com/code-url", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasSingleUnderline(for: "inserted wording", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://example.com/setext", in: inline.renderModel.attributedText))
        XCTAssertEqual(
            tooltip(for: "API design", in: inline.renderModel.attributedText),
            "Application Programming Interface"
        )
        XCTAssertTrue(hasDottedUnderline(for: "API design", in: inline.renderModel.attributedText))
        XCTAssertNil(attribute(.toolTip, for: "API()", in: inline.renderModel.attributedText))
        XCTAssertFalse(hasDottedUnderline(for: "API()", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasFixedPitchFont(for: "API()", in: inline.renderModel.attributedText))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Setext H1 with heading code", kind: .heading, in: inline))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Second line should stay visually separated", kind: .paragraph, in: inline))

        let lists = try XCTUnwrap(documents["02_lists_tasks.md"])
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("☑ Confirm local-first behavior"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("☐ Review anchor recovery"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("☒ Reject stale prompt draft"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("◩ Investigate annotation anchor drift"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("⚠ Escalate blocked review note"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("☑ Arbitrary completed review task"))
        XCTAssertNotNil(attribute(NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"), for: "☑ Confirm local-first behavior", in: lists.renderModel.attributedText))
        XCTAssertNil(attribute(NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"), for: "Confirm local-first behavior", in: lists.renderModel.attributedText))
        XCTAssertEqual(
            attribute(.toolTip, for: "☑ Confirm local-first behavior", in: lists.renderModel.attributedText) as? String,
            "点击或按 Space/⌘L 切换完成/待办；⌘⌥J/K 跳转任务；右键可标记待办/完成/取消/进行中/重要。"
        )
        XCTAssertTrue(hasStrikethroughAttribute(for: "Confirm local-first behavior", in: lists.renderModel.attributedText))
        XCTAssertTrue(hasStrikethroughAttribute(for: "Done evidence should inherit the completed state.", in: lists.renderModel.attributedText))
        XCTAssertTrue(hasStrikethroughAttribute(for: "Arbitrary completed review task", in: lists.renderModel.attributedText))
        XCTAssertFalse(hasStrikethroughAttribute(for: "Review anchor recovery", in: lists.renderModel.attributedText))
        XCTAssertFalse(hasStrikethroughAttribute(for: "Continuation should stay part of the task item", in: lists.renderModel.attributedText))
        XCTAssertFalse(hasStrikethroughAttribute(for: "Investigate annotation anchor drift", in: lists.renderModel.attributedText))
        XCTAssertFalse(hasStrikethroughAttribute(for: "Escalate blocked review note", in: lists.renderModel.attributedText))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("[-] Reject stale prompt draft"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("[/] Investigate annotation anchor drift"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("[!] Escalate blocked review note"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("[a] Arbitrary completed review task"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Continuation line that explains the rationale with a link."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Continuation should stay part of the task item"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Continuation under child should align with child text."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Loose continuation paragraph after a blank line with extra context."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Loose task paragraph should still map to the task list item."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Evidence screenshot"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("Embed: 180"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|180]]"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("Embed: 150"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|150]]"))
        XCTAssertEqual(attachmentCount(in: lists.renderModel.attributedText), 2)
        let listAttachmentSizes = attachmentSizes(in: lists.renderModel.attributedText)
        if listAttachmentSizes.count >= 2 {
            XCTAssertEqual(listAttachmentSizes[0].width, 180, accuracy: 0.5)
            XCTAssertEqual(listAttachmentSizes[1].width, 150, accuracy: 0.5)
        } else {
            XCTFail("Expected unordered-list and definition-list image previews")
        }
        XCTAssertTrue(lists.renderModel.attributedText.string.contains(
            "• Evidence screenshot\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png\nshould stay inside the list item."
        ))
        XCTAssertTrue(lists.renderModel.attributedText.string.contains(
            "Screenshot\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png\ndocuments the review surface."
        ))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertEqual(
            attribute(.toolTip, for: "Embed: markprompt_interaction_prototype_v4.png", in: lists.renderModel.attributedText) as? String,
            "../../../docs/assets/markprompt_interaction_prototype_v4.png"
        )
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("3. Preserve the author's starting number."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("10) Parenthesized ordered marker."))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("10. Parenthesized ordered marker."))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("\n  Continuation line"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("\n  Loose continuation"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("• Child item A.1"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("1. Ordered child B.1"))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains("\n  • Child item A.1"))
        XCTAssertTrue(hasLinkAttribute("https://example.com/list-continuation", in: lists.renderModel.attributedText))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Continuation line that explains the rationale", kind: .unorderedList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Done evidence should inherit the completed state", kind: .taskList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Continuation should stay part of the task item", kind: .taskList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Investigate annotation anchor drift", kind: .taskList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Escalate blocked review note", kind: .taskList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Arbitrary completed review task", kind: .taskList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Loose continuation paragraph after a blank line", kind: .unorderedList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Loose task paragraph should still map", kind: .taskList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Evidence screenshot", kind: .unorderedList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Parenthesized ordered marker", kind: .orderedList, in: lists))
        XCTAssertGreaterThan(
            firstLineIndent(for: "• Child item A.1", in: lists.renderModel.attributedText),
            firstLineIndent(for: "• Parent item A", in: lists.renderModel.attributedText)
        )
        XCTAssertGreaterThan(
            firstLineIndent(for: "Continuation line that explains", in: lists.renderModel.attributedText),
            firstLineIndent(for: "• Second product decision", in: lists.renderModel.attributedText)
        )
        XCTAssertGreaterThan(
            firstLineIndent(for: "Continuation under child", in: lists.renderModel.attributedText),
            firstLineIndent(for: "• Child item A.1", in: lists.renderModel.attributedText)
        )
        XCTAssertGreaterThan(
            firstLineIndent(for: "Loose continuation paragraph", in: lists.renderModel.attributedText),
            firstLineIndent(for: "• Second product decision", in: lists.renderModel.attributedText)
        )
        XCTAssertTrue(lists.renderModel.sourceMap.blocks.contains { $0.kind == .definitionList })
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("API\nApplication Programming Interface"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Stable review contract with anchors"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Evidence artifact\nScreenshot"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("documents the review surface."))
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains(": Application Programming Interface"))
        XCTAssertTrue(hasBoldFont(for: "API", in: lists.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "anchors", in: lists.renderModel.attributedText))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Application Programming Interface", kind: .definitionList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "documents the review surface", kind: .definitionList, in: lists))

        let tables = try XCTUnwrap(documents["03_tables_wide.md"])
        XCTAssertTrue(tables.renderModel.sourceMap.blocks.contains { $0.kind == .table })
        XCTAssertTrue(containsNativeTextTable(in: tables.renderModel.attributedText))
        XCTAssertGreaterThanOrEqual(tables.renderModel.sourceMap.blocks.filter { $0.kind == .table }.count, 3)
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("| FLUX.2"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("| 模型"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("|------|"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("**FLUX.2"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("[Apache 2.0]("))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("`generation`"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains(":warning:"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("Selection &amp; anchor"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("Embed: 140"))
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|140]]"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("⚠️"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("Selection & anchor mapping"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("最低显存"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("非商用免费/商用需授权"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("Embed: markprompt_interaction_prototype_v4.png"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("Ready for annotation"))
        XCTAssertEqual(attachmentCount(in: tables.renderModel.attributedText), 1)
        XCTAssertEqual(firstAttachmentSize(in: tables.renderModel.attributedText)?.width ?? 0, 140, accuracy: 0.5)
        XCTAssertFalse(tables.renderModel.renderedPlainText.contains("../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertEqual(
            attribute(.toolTip, for: "Embed: markprompt_interaction_prototype_v4.png", in: tables.renderModel.attributedText) as? String,
            "../../../docs/assets/markprompt_interaction_prototype_v4.png"
        )
        XCTAssertTrue(tableSelectionMapsBackToSource(text: "FLUX.2 [dev] (4bit)", in: tables))
        XCTAssertTrue(tableSelectionMapsBackToSource(text: "非商用免费/商用需授权", in: tables))
        XCTAssertTrue(tableSelectionMapsBackToSource(text: "Embed: markprompt_interaction_prototype_v4.png", in: tables))
        XCTAssertTrue(hasBoldFont(for: "FLUX.2 [dev]", in: tables.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://www.apache.org/licenses/LICENSE-2.0", in: tables.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "generation", in: tables.renderModel.attributedText))
        XCTAssertTrue(hasStrikethroughAttribute(for: "Needs careful license review", in: tables.renderModel.attributedText))
        XCTAssertGreaterThan(
            MarkdownReaderLayoutMetrics.maximumTableContentWidth(in: tables.renderModel.attributedText),
            760
        )
        let wideTableColumnWidths = tableColumnWidths(in: tables.renderModel.attributedText)
        let releaseWidth = try XCTUnwrap(wideTableColumnWidths[2])
        let licenseWidth = try XCTUnwrap(wideTableColumnWidths[5])
        let notesWidth = try XCTUnwrap(wideTableColumnWidths[7])
        XCTAssertGreaterThanOrEqual(releaseWidth, 98)
        XCTAssertGreaterThanOrEqual(licenseWidth, 112)
        XCTAssertGreaterThanOrEqual(notesWidth, 106)

        let code = try XCTUnwrap(documents["04_code_blocks.md"])
        XCTAssertTrue(code.renderModel.renderedPlainText.contains("Swift\n"))
        XCTAssertTrue(code.renderModel.renderedPlainText.contains("JSON\n"))
        XCTAssertTrue(code.renderModel.renderedPlainText.contains("Bash\n"))
        XCTAssertTrue(code.renderModel.renderedPlainText.contains("YAML\n"))
        XCTAssertTrue(code.renderModel.renderedPlainText.contains("Diff\n"))
        XCTAssertTrue(code.renderModel.renderedPlainText.contains("MARKPROMPT_REVIEW=1"))
        XCTAssertTrue(code.renderModel.renderedPlainText.contains("    echo \"native indented code\""))
        XCTAssertFalse(code.renderModel.renderedPlainText.contains("    MARKPROMPT_REVIEW=1"))
        XCTAssertFalse(code.renderModel.renderedPlainText.contains("language: swift"))
        XCTAssertFalse(code.renderModel.renderedPlainText.contains("```"))
        XCTAssertTrue(containsFullWidthTextBlock(in: code.renderModel.attributedText, for: "struct ReviewNote"))
        XCTAssertTrue(containsFullWidthTextBlock(in: code.renderModel.attributedText, for: "MARKPROMPT_REVIEW=1"))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "MARKPROMPT_REVIEW=1", kind: .codeBlock, in: code))
        XCTAssertTrue(
            hasDifferentForegroundColor(
                first: "title",
                second: "Reader settings",
                in: code.renderModel.attributedText
            )
        )
        XCTAssertTrue(
            hasDifferentForegroundColor(
                first: "+ render native TextKit table",
                second: "context unchanged",
                in: code.renderModel.attributedText
            )
        )
        XCTAssertTrue(
            hasDifferentForegroundColor(
                first: "- render raw pipe table",
                second: "context unchanged",
                in: code.renderModel.attributedText
            )
        )

        let footnotes = try XCTUnwrap(documents["05_quotes_footnotes.md"])
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("┃"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[!NOTE]"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[!WARNING]"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[!todo]+"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[!faq]-"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[!bug]"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[!review]-"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("+ Ship review workflow"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("- Why keep source text?"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("- Needs reviewer follow-up"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("> Nested quote"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Lazy continuation should stay inside the quote block"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Second quoted paragraph keeps inline emphasis"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Nested quote should hide the extra marker"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Embedded evidence"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("▸ Nested reviewer hint"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Inner nested detail should keep indentation"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[!tip]-"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("Embed: 160"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|160]]"))
        XCTAssertEqual(attachmentCount(in: footnotes.renderModel.attributedText), 1)
        XCTAssertEqual(firstAttachmentSize(in: footnotes.renderModel.attributedText)?.width ?? 0, 160, accuracy: 0.5)
        XCTAssertTrue(footnotes.renderModel.attributedText.string.contains(
            "Embedded evidence\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png\nshould stay inside the quote block."
        ))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertEqual(
            attribute(.toolTip, for: "Embed: markprompt_interaction_prototype_v4.png", in: footnotes.renderModel.attributedText) as? String,
            "../../../docs/assets/markprompt_interaction_prototype_v4.png"
        )
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Note\nCallouts should hide"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("▸ Nested reviewer hint\nInner nested detail"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Warning\nRisky changes"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("▾ Ship review workflow\nFold markers"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("▸ Why keep source text?\nObsidian aliases"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Bug\nRenderer regressions"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("▸ Needs reviewer follow-up\nCustom callouts should fall back"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[^local-first]"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[^anchor]"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("reference.¹"))
        XCTAssertEqual(
            attribute(.toolTip, for: "¹", in: footnotes.renderModel.attributedText) as? String,
            "Local-first rendering means the Markdown content is processed on the user's device."
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "²", in: footnotes.renderModel.attributedText) as? String,
            "Anchors need selected text, source context, and rendered ranges. Continuation lines should remain part of the same footnote when possible."
        )
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("2. Anchors need"))
        XCTAssertTrue(containsFullWidthTextBlock(in: footnotes.renderModel.attributedText, for: "A good reader"))
        XCTAssertTrue(containsFullWidthTextBlock(in: footnotes.renderModel.attributedText, for: "Callouts should hide"))
        XCTAssertTrue(containsFullWidthTextBlock(in: footnotes.renderModel.attributedText, for: "Ship review workflow"))
        XCTAssertTrue(hasBoldFont(for: "Note", in: footnotes.renderModel.attributedText))
        XCTAssertTrue(hasBoldFont(for: "Warning", in: footnotes.renderModel.attributedText))
        XCTAssertTrue(hasBoldFont(for: "Bug", in: footnotes.renderModel.attributedText))
        XCTAssertTrue(hasDifferentForegroundColor(
            first: "Warning",
            second: "Risky changes",
            in: footnotes.renderModel.attributedText
        ))
        XCTAssertTrue(hasDifferentForegroundColor(
            first: "Ship review workflow",
            second: "Fold markers",
            in: footnotes.renderModel.attributedText
        ))
        XCTAssertEqual(
            attribute(.toolTip, for: "▾", in: footnotes.renderModel.attributedText) as? String,
            "Default expanded in Obsidian"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "▸", in: footnotes.renderModel.attributedText) as? String,
            "Default collapsed in Obsidian"
        )
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Callouts should hide", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Nested reviewer hint", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Lazy continuation should stay", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Nested quote should hide", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Why keep source text?", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Needs reviewer follow-up", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Embedded evidence", kind: .blockquote, in: footnotes))
        XCTAssertTrue(hasBoldFont(for: "inline emphasis", in: footnotes.renderModel.attributedText))
        XCTAssertGreaterThan(
            firstLineIndent(for: "Nested quote should hide", in: footnotes.renderModel.attributedText),
            firstLineIndent(for: "Second quoted paragraph", in: footnotes.renderModel.attributedText)
        )
        XCTAssertGreaterThan(
            firstLineIndent(for: "▸ Nested reviewer hint", in: footnotes.renderModel.attributedText),
            firstLineIndent(for: "Callouts should hide", in: footnotes.renderModel.attributedText)
        )
        XCTAssertTrue(footnoteBlock(in: footnotes, contains: "Continuation lines should remain part of the same footnote"))

        let media = try XCTUnwrap(documents["06_images_links.md"])
        XCTAssertTrue(media.renderModel.sourceMap.blocks.contains { $0.kind == .image })
        XCTAssertTrue(containsFullWidthTextBlock(in: media.renderModel.attributedText, for: "Image: Architecture overview"))
        XCTAssertEqual(attachmentCount(in: media.renderModel.attributedText), 2)
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("Reference link: Markdown Reader reference"))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("Collapsed reference: Local docs"))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("Inline image fallback: release badge Image: Build badge (https://example.com/badge.svg)"))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("reference icon Image: Reference badge (assets/icon.svg)."))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("PDF: review-brief.pdf"))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("Audio: interview.m4a"))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("Video: prototype walkthrough"))
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("Image: Reference local image"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("[reader-ref]:"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("[Markdown Reader reference][reader-ref]"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("![Build badge]"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("![Reference badge][inline-image-ref]"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("Embed: docs/assets/review-brief.pdf"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("Embed: captures/interview.m4a"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("Embed: prototype walkthrough"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("![[docs/assets/review-brief.pdf]]"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("docs/assets/review-brief.pdf"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("captures/interview.m4a"))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Architecture overview", kind: .image, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Reference local image", kind: .image, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Build badge", kind: .paragraph, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Reference badge", kind: .paragraph, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "PDF: review-brief.pdf", kind: .paragraph, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "https://example.com/diagram.png", kind: .image, in: media))
        XCTAssertEqual(
            attribute(.toolTip, for: "PDF: review-brief.pdf", in: media.renderModel.attributedText) as? String,
            "docs/assets/review-brief.pdf"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Audio: interview.m4a", in: media.renderModel.attributedText) as? String,
            "captures/interview.m4a"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Video: prototype walkthrough", in: media.renderModel.attributedText) as? String,
            "demos/prototype.mov"
        )
        XCTAssertTrue(hasLinkAttribute("https://md-reader.github.io/", in: media.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://example.com/local-docs", in: media.renderModel.attributedText))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("<https://example.com/autolink>"))
        XCTAssertTrue(hasLinkAttribute("https://example.com/autolink", in: media.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://example.com/bare-url", in: media.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://example.com/badge.svg", in: media.renderModel.attributedText))

        let math = try XCTUnwrap(documents["07_math_mermaid_fallback.md"])
        XCTAssertTrue(math.renderModel.renderedPlainText.contains("E = mc^2"))
        XCTAssertFalse(math.renderModel.renderedPlainText.contains("$E = mc^2$"))
        XCTAssertTrue(math.renderModel.renderedPlainText.contains("$19.99/month"))
        XCTAssertTrue(math.renderModel.renderedPlainText.contains("$0.04 per render"))
        XCTAssertTrue(hasBackgroundAttribute(for: "E = mc^2", in: math.renderModel.attributedText))
        XCTAssertTrue(math.renderModel.sourceMap.blocks.contains { $0.kind == .mathBlock })
        XCTAssertTrue(math.renderModel.renderedPlainText.contains("Formula"))
        XCTAssertFalse(math.renderModel.renderedPlainText.contains("$$\n"))
        XCTAssertTrue(math.renderModel.renderedPlainText.contains("Mermaid\n"))
        XCTAssertEqual(attachmentCount(in: math.renderModel.attributedText), 2)
        XCTAssertTrue(allAttachmentsUseDynamicDrawing(in: math.renderModel.attributedText))
        XCTAssertTrue(containsFullWidthTextBlock(in: math.renderModel.attributedText, for: "Formula"))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: #"\int_0^1 x^2 dx = \frac{1}{3}"#, kind: .mathBlock, in: math))
        XCTAssertTrue(containsFullWidthTextBlock(in: math.renderModel.attributedText, for: "flowchart TD"))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "A[Open Markdown] --> B[Select Text]", kind: .codeBlock, in: math))

        let outline = try XCTUnwrap(documents["08_long_outline.md"])
        let outlineHeadings = outline.outline.flattened()
        XCTAssertGreaterThanOrEqual(outlineHeadings.count, 16)
        let firstOutlineHeading = try XCTUnwrap(outlineHeadings.first)
        let laterOutlineHeading = try XCTUnwrap(outlineHeadings.first { $0.title == "4.2 Current Section" })
        let firstOutlineRange = try XCTUnwrap(outline.renderModel.sourceMap.headingRenderRanges[firstOutlineHeading.id])
        let laterOutlineRange = try XCTUnwrap(outline.renderModel.sourceMap.headingRenderRanges[laterOutlineHeading.id])
        XCTAssertEqual(
            MarkdownReaderLayoutMetrics.currentHeadingID(
                forVisibleLocation: firstOutlineRange.location,
                in: outline.renderModel.sourceMap
            ),
            firstOutlineHeading.id
        )
        XCTAssertEqual(
            MarkdownReaderLayoutMetrics.currentHeadingID(
                forVisibleLocation: laterOutlineRange.location + 12,
                in: outline.renderModel.sourceMap
            ),
            laterOutlineHeading.id
        )

        let frontmatter = try XCTUnwrap(documents["09_frontmatter_html.md"])
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.hasPrefix("────────────"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("────────────"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("\ntags:\n"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("Metadata:"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.hasPrefix("Properties\n"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("Title: Reader Fixture Frontmatter"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("Owner: MarkPrompt"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("Tags: markdown  reader"))
        XCTAssertTrue(frontmatter.renderModel.sourceMap.blocks.contains { $0.kind == .htmlBlock })
        XCTAssertTrue(frontmatter.renderModel.sourceMap.blocks.contains { $0.kind == .table })
        XCTAssertTrue(frontmatter.renderModel.sourceMap.blocks.contains { $0.kind == .thematicBreak })
        XCTAssertTrue(containsFullWidthTextBlock(in: frontmatter.renderModel.attributedText, for: "Properties"))
        XCTAssertTrue(hasBackgroundAttribute(for: "markdown", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "reader", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(containsFullWidthTextBlock(in: frontmatter.renderModel.attributedText, for: "HTML blocks should be visible"))
        XCTAssertTrue(containsNativeTextTable(in: frontmatter.renderModel.attributedText))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<aside>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("</aside>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<table>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<td>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<kbd>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<mark>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<sub>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<sup>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<ins>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<del>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<small>"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<a "))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("href="))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<br"))
        XCTAssertFalse(frontmatter.renderModel.renderedPlainText.contains("<img"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("Command + F"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("marked HTML"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("H2O"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("x2"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("inserted HTML"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("removed HTML"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("quiet HTML"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("HTML link label\nNext HTML line should remain visually separated."))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("Image: HTML diagram (https://example.com/html-image.png)"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("HTML table fallback"))
        XCTAssertTrue(frontmatter.renderModel.renderedPlainText.contains("Native TextKit table"))
        XCTAssertTrue(tableSelectionMapsBackToSource(text: "HTML table fallback", in: frontmatter))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Next HTML line should remain visually separated", kind: .paragraph, in: frontmatter))
        XCTAssertTrue(hasBackgroundAttribute(for: "Command", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "marked HTML", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(hasSubscriptAttribute(for: "H2O", character: "2", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(hasSuperscriptAttribute(for: "x2", character: "2", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(hasSingleUnderline(for: "inserted HTML", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(hasStrikethroughAttribute(for: "removed HTML", in: frontmatter.renderModel.attributedText))
        XCTAssertNotNil(attribute(.foregroundColor, for: "quiet HTML", in: frontmatter.renderModel.attributedText) as? NSColor)
        XCTAssertTrue(hasLinkAttribute("https://example.com/html-link", in: frontmatter.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://example.com/html-image.png", in: frontmatter.renderModel.attributedText))

        let mixed = try XCTUnwrap(documents["10_review_prd_mix.md"])
        XCTAssertTrue(mixed.renderModel.sourceMap.blocks.contains { $0.kind == .taskList })
        XCTAssertTrue(mixed.renderModel.sourceMap.blocks.contains { $0.kind == .table })
        XCTAssertTrue(mixed.renderModel.sourceMap.blocks.contains { $0.kind == .footnote })
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[^mix]"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("weekly review"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Prompt Quality"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Prompt Quality#Review checklist"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Decision Log#^accepted"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Markdown-format internal links should behave the same: review checklist, extensionless retro, and current block."))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("#review/anchor"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Embed: markprompt_interaction_prototype_v4.png"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Note: review appendix"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Note: Review Appendix#Risks"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Note: Review Appendix#Risk Map"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Embed: ../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Embed: review appendix"))
        XCTAssertEqual(attachmentCount(in: mixed.renderModel.attributedText), 1)
        let mixedEmbedPreviewSize = firstAttachmentSize(in: mixed.renderModel.attributedText)
        XCTAssertEqual(mixedEmbedPreviewSize?.width ?? 0, 220, accuracy: 0.5)
        XCTAssertGreaterThan(mixedEmbedPreviewSize?.height ?? 0, 0)
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Inline reviewer context² should stay compact."))
        XCTAssertEqual(
            attribute(.underlineStyle, for: "²", in: mixed.renderModel.attributedText) as? Int,
            NSUnderlineStyle.single.union(.patternDot).rawValue
        )
        XCTAssertNotNil(attribute(.underlineColor, for: "²", in: mixed.renderModel.attributedText) as? NSColor)
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[[Reader Vault/Weekly Review|weekly review]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[[Prompt Quality]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[[Prompt Quality#Review checklist]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[[Decision Log#^accepted]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Prompt%20Quality.md#Review%20checklist"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Reader%20Vault/Weekly%20Review#Retro"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[current block](#^review-context)"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[[Research/Review Appendix#Findings|review appendix]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Note: Review Appendix.md#Risks"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[[Research/Review Appendix.md#Risks]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Review%20Appendix"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Risk%20Map"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("[[Research/Review%20Appendix.md#Risk%20Map]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Embed: 220"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|220]]"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("^[This should become a tooltip"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("%%needs a better example before sharing%%"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Reviewer-only TODO"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Hidden implementation concern"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("Private paragraph after blank line"))
        XCTAssertTrue(mixed.renderModel.renderedPlainText.contains("Visible review note after the hidden scratchpad."))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("^review-context"))
        XCTAssertFalse(mixed.renderModel.renderedPlainText.contains("^visible-review-note"))
        XCTAssertEqual(
            attribute(.link, for: "weekly review", in: mixed.renderModel.attributedText) as? String,
            "obsidian://Reader%20Vault/Weekly%20Review"
        )
        XCTAssertEqual(
            attribute(.link, for: "Prompt Quality#Review checklist", in: mixed.renderModel.attributedText) as? String,
            "obsidian://Prompt%20Quality#Review%20checklist"
        )
        XCTAssertEqual(
            attribute(.link, for: "Decision Log#^accepted", in: mixed.renderModel.attributedText) as? String,
            "obsidian://Decision%20Log#^accepted"
        )
        XCTAssertEqual(
            attribute(.link, for: "review checklist", in: mixed.renderModel.attributedText) as? String,
            "obsidian://Prompt%20Quality#Review%20checklist"
        )
        XCTAssertEqual(
            attribute(.link, for: "extensionless retro", in: mixed.renderModel.attributedText) as? String,
            "obsidian://Reader%20Vault/Weekly%20Review#Retro"
        )
        XCTAssertEqual(
            attribute(.link, for: "current block", in: mixed.renderModel.attributedText) as? String,
            "obsidian://#^review-context"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "review checklist", in: mixed.renderModel.attributedText) as? String,
            "Prompt Quality#Review checklist"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "extensionless retro", in: mixed.renderModel.attributedText) as? String,
            "Reader Vault/Weekly Review#Retro"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "current block", in: mixed.renderModel.attributedText) as? String,
            "#^review-context"
        )
        XCTAssertNotNil(attribute(.backgroundColor, for: "#review/anchor", in: mixed.renderModel.attributedText))
        XCTAssertNotNil(attribute(.backgroundColor, for: "Embed: markprompt_interaction_prototype_v4.png", in: mixed.renderModel.attributedText))
        XCTAssertEqual(
            attribute(.toolTip, for: "Embed: markprompt_interaction_prototype_v4.png", in: mixed.renderModel.attributedText) as? String,
            "../../../docs/assets/markprompt_interaction_prototype_v4.png"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Note: review appendix", in: mixed.renderModel.attributedText) as? String,
            "Research/Review Appendix#Findings"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Note: Review Appendix#Risks", in: mixed.renderModel.attributedText) as? String,
            "Research/Review Appendix.md#Risks"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Note: Review Appendix#Risk Map", in: mixed.renderModel.attributedText) as? String,
            "Research/Review Appendix.md#Risk Map"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "²", in: mixed.renderModel.attributedText) as? String,
            "This should become a tooltip without polluting selected text."
        )
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "weekly review", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Prompt Quality#Review checklist", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Decision Log#^accepted", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "review checklist", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "extensionless retro", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "current block", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Embed: markprompt_interaction_prototype_v4.png", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Note: review appendix", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Note: Review Appendix#Risks", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Note: Review Appendix#Risk Map", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Inline reviewer context", kind: .paragraph, in: mixed))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Visible review note after the hidden scratchpad", kind: .paragraph, in: mixed))
    }

    private func layout(_ attributedText: NSAttributedString, width: CGFloat) throws {
        let tableContentWidth = MarkdownReaderLayoutMetrics.maximumTableContentWidth(in: attributedText)
        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        XCTAssertGreaterThan(usedRect.height, 0)
        XCTAssertLessThanOrEqual(usedRect.width, max(width, tableContentWidth) + 8)
    }

    private func waitForMainQueue() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    private func footnoteBlock(in document: MarkdownDocument, contains text: String) -> Bool {
        let rendered = document.renderModel.renderedPlainText as NSString
        return document.renderModel.sourceMap.blocks.contains { block in
            guard block.kind == .footnote,
                  block.renderedRange.upperBound <= rendered.length
            else {
                return false
            }

            return rendered.substring(with: block.renderedRange.nsRange).contains(text)
        }
    }

    private func containsNativeTextTable(in attributedText: NSAttributedString) -> Bool {
        var foundTable = false
        attributedText.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, stop in
            guard let paragraph = value as? NSParagraphStyle else {
                return
            }

            if paragraph.textBlocks.contains(where: { $0 is NSTextTableBlock }) {
                foundTable = true
                stop.pointee = true
            }
        }

        return foundTable
    }

    private func tableColumnWidths(in attributedText: NSAttributedString) -> [Int: CGFloat] {
        var widths: [Int: CGFloat] = [:]
        attributedText.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            guard let paragraph = value as? NSParagraphStyle else {
                return
            }

            for textBlock in paragraph.textBlocks {
                guard let tableBlock = textBlock as? NSTextTableBlock,
                      tableBlock.startingRow == 0,
                      tableBlock.valueType(for: .width) == .absoluteValueType
                else {
                    continue
                }

                let width = tableBlock.value(for: .width)
                widths[tableBlock.startingColumn] = max(widths[tableBlock.startingColumn, default: 0], width)
            }
        }
        return widths
    }

    private func containsTextBlock(in attributedText: NSAttributedString, for needle: String) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return false
        }

        let paragraphStyle = attributedText.attribute(
            .paragraphStyle,
            at: match.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        return paragraphStyle?.textBlocks.isEmpty == false
    }

    private func firstLineIndent(for needle: String, in attributedText: NSAttributedString) -> CGFloat {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound,
              let paragraphStyle = attributedText.attribute(
                .paragraphStyle,
                at: match.location,
                effectiveRange: nil
              ) as? NSParagraphStyle
        else {
            return 0
        }

        return paragraphStyle.firstLineHeadIndent
    }

    private func containsFullWidthTextBlock(in attributedText: NSAttributedString, for needle: String) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return false
        }

        let paragraphStyle = attributedText.attribute(
            .paragraphStyle,
            at: match.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        return paragraphStyle?.textBlocks.contains { block in
            block.valueType(for: .width) == .percentageValueType
                && abs(block.value(for: .width) - 100) < 0.5
        } == true
    }

    private func hasLinkAttribute(_ url: String, in attributedText: NSAttributedString) -> Bool {
        var foundLink = false
        attributedText.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, stop in
            if value as? String == url {
                foundLink = true
                stop.pointee = true
            }
        }

        return foundLink
    }

    private func hasBoldFont(for needle: String, in attributedText: NSAttributedString) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound,
              let font = attributedText.attribute(.font, at: match.location, effectiveRange: nil) as? NSFont
        else {
            return false
        }

        return NSFontManager.shared.traits(of: font).contains(.boldFontMask)
    }

    private func hasFixedPitchFont(for needle: String, in attributedText: NSAttributedString) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound,
              let font = attributedText.attribute(.font, at: match.location, effectiveRange: nil) as? NSFont
        else {
            return false
        }

        return NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask)
    }

    private func hasBackgroundAttribute(for needle: String, in attributedText: NSAttributedString) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return false
        }

        return attributedText.attribute(.backgroundColor, at: match.location, effectiveRange: nil) != nil
    }

    private func hasStrikethroughAttribute(for needle: String, in attributedText: NSAttributedString) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return false
        }

        return attributedText.attribute(.strikethroughStyle, at: match.location, effectiveRange: nil) as? Int
            == NSUnderlineStyle.single.rawValue
    }

    private func hasDifferentForegroundColor(
        first: String,
        second: String,
        in attributedText: NSAttributedString
    ) -> Bool {
        guard let firstColor = foregroundColor(for: first, in: attributedText),
              let secondColor = foregroundColor(for: second, in: attributedText)
        else {
            return false
        }

        return !firstColor.isEqual(secondColor)
    }

    private func foregroundColor(for needle: String, in attributedText: NSAttributedString) -> NSColor? {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return nil
        }

        return attributedText.attribute(.foregroundColor, at: match.location, effectiveRange: nil) as? NSColor
    }

    private func tooltip(for needle: String, in attributedText: NSAttributedString) -> String? {
        attribute(.toolTip, for: needle, in: attributedText) as? String
    }

    private func hasDottedUnderline(for needle: String, in attributedText: NSAttributedString) -> Bool {
        guard let style = attribute(.underlineStyle, for: needle, in: attributedText) as? Int else {
            return false
        }
        return style & NSUnderlineStyle.patternDot.rawValue != 0
    }

    private func hasSingleUnderline(for needle: String, in attributedText: NSAttributedString) -> Bool {
        guard let style = attribute(.underlineStyle, for: needle, in: attributedText) as? Int else {
            return false
        }
        return style & NSUnderlineStyle.single.rawValue != 0
    }

    private func attribute(
        _ key: NSAttributedString.Key,
        for needle: String,
        in attributedText: NSAttributedString
    ) -> Any? {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return nil
        }

        return attributedText.attribute(key, at: match.location, effectiveRange: nil)
    }

    private func attachmentCount(in attributedText: NSAttributedString) -> Int {
        var count = 0
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            if value is NSTextAttachment {
                count += 1
            }
        }
        return count
    }

    private func firstAttachmentSize(in attributedText: NSAttributedString) -> NSSize? {
        var size: NSSize?
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, stop in
            guard let attachment = value as? NSTextAttachment else {
                return
            }

            size = attachment.bounds.size
            stop.pointee = true
        }
        return size
    }

    private func attachmentSizes(in attributedText: NSAttributedString) -> [NSSize] {
        var sizes: [NSSize] = []
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            guard let attachment = value as? NSTextAttachment else {
                return
            }

            sizes.append(attachment.bounds.size)
        }
        return sizes
    }

    private func allAttachmentsUseDynamicDrawing(in attributedText: NSAttributedString) -> Bool {
        var attachments: [NSTextAttachment] = []
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            if let attachment = value as? NSTextAttachment {
                attachments.append(attachment)
            }
        }

        guard !attachments.isEmpty else {
            return false
        }

        return attachments.allSatisfy { attachment in
            guard let image = attachment.image else {
                return false
            }
            return image.representations.contains { $0 is NSCustomImageRep }
        }
    }

    private func hasSuperscriptAttribute(
        for needle: String,
        character: String,
        in attributedText: NSAttributedString
    ) -> Bool {
        baselineOffset(for: needle, character: character, in: attributedText) > 0
    }

    private func hasSubscriptAttribute(
        for needle: String,
        character: String,
        in attributedText: NSAttributedString
    ) -> Bool {
        baselineOffset(for: needle, character: character, in: attributedText) < 0
    }

    private func baselineOffset(
        for needle: String,
        character: String,
        in attributedText: NSAttributedString
    ) -> CGFloat {
        let rendered = attributedText.string as NSString
        let wordRange = rendered.range(of: needle)
        guard wordRange.location != NSNotFound else {
            return 0
        }

        let characterRange = rendered.range(of: character, range: wordRange)
        guard characterRange.location != NSNotFound else {
            return 0
        }

        return attributedText.attribute(.baselineOffset, at: characterRange.location, effectiveRange: nil) as? CGFloat ?? 0
    }

    private func tableSelectionMapsBackToSource(text: String, in document: MarkdownDocument) -> Bool {
        blockSelectionMapsBackToSource(text: text, kind: .table, in: document)
    }

    private func blockSelectionMapsBackToSource(
        text: String,
        kind: MarkdownRenderBlockKind,
        in document: MarkdownDocument
    ) -> Bool {
        let rendered = document.renderModel.renderedPlainText as NSString
        let match = rendered.range(of: text)
        guard match.location != NSNotFound else {
            return false
        }

        let renderedRange = RenderedTextRange(location: match.location, length: match.length)
        guard let sourceRange = document.renderModel.sourceMap.sourceRange(containing: renderedRange),
              let block = document.renderModel.sourceMap.block(containing: renderedRange)
        else {
            return false
        }

        return block.kind == kind && sourceRange.length > 0
    }

    private func spaceKeyEvent(modifierFlags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        )!
    }

    private func parsedFixturesByName() throws -> [String: MarkdownDocument] {
        var documents: [String: MarkdownDocument] = [:]
        for url in try fixtureURLs() {
            let source = try String(contentsOf: url, encoding: .utf8)
            documents[url.lastPathComponent] = MarkdownParser().parse(source, fileURL: url)
        }
        return documents
    }

    private func fixtureURLs() throws -> [URL] {
        let directory = fixturesDirectoryURL()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return urls
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func fixturesDirectoryURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("samples/markdown/reader-fixtures")
    }
}

private final class UndoProbeResponder: NSResponder {
    var undoCount = 0

    @objc(undo:)
    func undo(_ sender: Any?) {
        undoCount += 1
    }
}

private final class TaskMarkerCommandProbeResponder: NSResponder {
    var toggleCount = 0

    @objc(toggleTaskMarkerStatus:)
    func toggleTaskMarkerStatus(_ sender: Any?) {
        toggleCount += 1
    }
}
