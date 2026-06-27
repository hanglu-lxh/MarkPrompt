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
        XCTAssertEqual(normal.origin.x, 124, accuracy: 0.01)
        XCTAssertEqual(normal.origin.y, 166, accuracy: 0.01)
        XCTAssertEqual(normal.maxX, 196, accuracy: 0.01)

        let nearRightEdge = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 450, y: 220, width: 42, height: 24),
            viewportSize: viewport
        ))
        XCTAssertEqual(nearRightEdge.origin.x, 416, accuracy: 0.01)
        XCTAssertEqual(nearRightEdge.origin.y, 166, accuracy: 0.01)

        let nearTopEdge = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 180, y: 4, width: 120, height: 18),
            viewportSize: viewport
        ))
        XCTAssertEqual(nearTopEdge.origin.x, 204, accuracy: 0.01)
        XCTAssertEqual(nearTopEdge.origin.y, 32, accuracy: 0.01)

        let nearBottomEdge = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 180, y: 576, width: 120, height: 18),
            viewportSize: viewport
        ))
        XCTAssertEqual(nearBottomEdge.origin.x, 204, accuracy: 0.01)
        XCTAssertEqual(nearBottomEdge.origin.y, 522, accuracy: 0.01)

        let tallVisibleSelection = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: 90, y: 240, width: 280, height: 96),
            viewportSize: viewport
        ))
        XCTAssertEqual(tallVisibleSelection.origin.x, 194, accuracy: 0.01)
        XCTAssertEqual(tallVisibleSelection.origin.y, 186, accuracy: 0.01)

        let oversizedSelection = try XCTUnwrap(MarkdownReaderLayoutMetrics.annotationButtonRect(
            forVisibleSelectionRect: CGRect(x: -30, y: -40, width: 640, height: 720),
            viewportSize: viewport
        ))
        XCTAssertGreaterThanOrEqual(oversizedSelection.minX, 12)
        XCTAssertGreaterThanOrEqual(oversizedSelection.minY, 12)
        XCTAssertLessThanOrEqual(oversizedSelection.maxX, viewport.width - 12)
        XCTAssertLessThanOrEqual(oversizedSelection.maxY, viewport.height - 12)
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
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("Application Programming Interface"))
        XCTAssertFalse(inline.renderModel.renderedPlainText.contains("~~removed wording~~"))
        XCTAssertTrue(inline.outline.flattened().contains { $0.title == "Setext H1 with heading code" })
        XCTAssertTrue(inline.outline.flattened().contains { $0.title == "Setext H2 with navigation link" })
        XCTAssertTrue(hasSubscriptAttribute(for: "H2O", character: "2", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasSuperscriptAttribute(for: "x2", character: "2", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "heading code", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "highlighted decisions", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasSingleUnderline(for: "inserted wording", in: inline.renderModel.attributedText))
        XCTAssertTrue(hasLinkAttribute("https://example.com/setext", in: inline.renderModel.attributedText))
        XCTAssertEqual(
            tooltip(for: "API design", in: inline.renderModel.attributedText),
            "Application Programming Interface"
        )
        XCTAssertTrue(hasDottedUnderline(for: "API design", in: inline.renderModel.attributedText))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Setext H1 with heading code", kind: .heading, in: inline))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Second line should stay visually separated", kind: .paragraph, in: inline))

        let lists = try XCTUnwrap(documents["02_lists_tasks.md"])
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("☑ Confirm local-first behavior"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("☐ Review anchor recovery"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Continuation line that explains the rationale with a link."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Continuation should stay part of the task item"))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Continuation under child should align with child text."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Loose continuation paragraph after a blank line with extra context."))
        XCTAssertTrue(lists.renderModel.renderedPlainText.contains("Loose task paragraph should still map to the task list item."))
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
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Continuation should stay part of the task item", kind: .taskList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Loose continuation paragraph after a blank line", kind: .unorderedList, in: lists))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Loose task paragraph should still map", kind: .taskList, in: lists))
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
        XCTAssertFalse(lists.renderModel.renderedPlainText.contains(": Application Programming Interface"))
        XCTAssertTrue(hasBoldFont(for: "API", in: lists.renderModel.attributedText))
        XCTAssertTrue(hasBackgroundAttribute(for: "anchors", in: lists.renderModel.attributedText))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Application Programming Interface", kind: .definitionList, in: lists))

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
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("⚠️"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("Selection & anchor mapping"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("最低显存"))
        XCTAssertTrue(tables.renderModel.renderedPlainText.contains("非商用免费/商用需授权"))
        XCTAssertTrue(tableSelectionMapsBackToSource(text: "FLUX.2 [dev] (4bit)", in: tables))
        XCTAssertTrue(tableSelectionMapsBackToSource(text: "非商用免费/商用需授权", in: tables))
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
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("> Nested quote"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Lazy continuation should stay inside the quote block"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Second quoted paragraph keeps inline emphasis"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Nested quote should hide the extra marker"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Note\nCallouts should hide"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("Warning\nRisky changes"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[^local-first]"))
        XCTAssertFalse(footnotes.renderModel.renderedPlainText.contains("[^anchor]"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("reference.¹"))
        XCTAssertTrue(footnotes.renderModel.renderedPlainText.contains("2. Anchors need"))
        XCTAssertTrue(containsFullWidthTextBlock(in: footnotes.renderModel.attributedText, for: "A good reader"))
        XCTAssertTrue(containsFullWidthTextBlock(in: footnotes.renderModel.attributedText, for: "Callouts should hide"))
        XCTAssertTrue(hasBoldFont(for: "Note", in: footnotes.renderModel.attributedText))
        XCTAssertTrue(hasBoldFont(for: "Warning", in: footnotes.renderModel.attributedText))
        XCTAssertTrue(hasDifferentForegroundColor(
            first: "Warning",
            second: "Risky changes",
            in: footnotes.renderModel.attributedText
        ))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Callouts should hide", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Lazy continuation should stay", kind: .blockquote, in: footnotes))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Nested quote should hide", kind: .blockquote, in: footnotes))
        XCTAssertTrue(hasBoldFont(for: "inline emphasis", in: footnotes.renderModel.attributedText))
        XCTAssertGreaterThan(
            firstLineIndent(for: "Nested quote should hide", in: footnotes.renderModel.attributedText),
            firstLineIndent(for: "Second quoted paragraph", in: footnotes.renderModel.attributedText)
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
        XCTAssertTrue(media.renderModel.renderedPlainText.contains("Image: Reference local image"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("[reader-ref]:"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("[Markdown Reader reference][reader-ref]"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("![Build badge]"))
        XCTAssertFalse(media.renderModel.renderedPlainText.contains("![Reference badge][inline-image-ref]"))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Architecture overview", kind: .image, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Reference local image", kind: .image, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Build badge", kind: .paragraph, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "Image: Reference badge", kind: .paragraph, in: media))
        XCTAssertTrue(blockSelectionMapsBackToSource(text: "https://example.com/diagram.png", kind: .image, in: media))
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
        XCTAssertTrue(frontmatter.renderModel.sourceMap.blocks.contains { $0.kind == .htmlBlock })
        XCTAssertTrue(frontmatter.renderModel.sourceMap.blocks.contains { $0.kind == .table })
        XCTAssertTrue(frontmatter.renderModel.sourceMap.blocks.contains { $0.kind == .thematicBreak })
        XCTAssertTrue(containsFullWidthTextBlock(in: frontmatter.renderModel.attributedText, for: "Metadata:"))
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
