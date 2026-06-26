import AppKit
import MarkPromptKit
import XCTest

final class MarkdownParserTests: XCTestCase {
    func testParsesSamplePRDOutline() throws {
        let source = try String(contentsOf: samplePRDURL(), encoding: .utf8)
        let document = MarkdownParser().parse(source, fileURL: samplePRDURL())
        let flattened = document.outline.flattened()

        XCTAssertEqual(flattened.first?.title, "示例 PRD")
        XCTAssertTrue(flattened.contains { $0.title == "1. 产品概述" })
        XCTAssertTrue(flattened.contains { $0.title == "4. 技术要求" })
        XCTAssertEqual(document.displayName, "sample_prd.md")
    }

    func testRendersCommonMarkdownBlocksAsSelectableText() {
        let markdown = """
        # Title

        Intro paragraph with `code`.

        - One
        - Two

        > Quote line

        ```swift
        let value = 1
        ```

        | 模块 | 责任 |
        |---|---|
        | Reader | 阅读和选择文本 |
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Title"))
        XCTAssertTrue(renderedText.contains("• One"))
        XCTAssertTrue(renderedText.contains("Quote line"))
        XCTAssertFalse(renderedText.contains("┃ Quote line"))
        XCTAssertTrue(renderedText.contains("let value = 1"))
        XCTAssertTrue(renderedText.contains("Reader"))
        XCTAssertFalse(document.renderModel.sourceMap.headingRenderRanges.isEmpty)
    }

    func testRendersIndentedCodeBlocksAsCodeBlocks() {
        let markdown = """
        Paragraph before.

            let value = 42
                let nested = true

            print(value)

        Paragraph after.
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("let value = 42"))
        XCTAssertTrue(renderedText.contains("    let nested = true"))
        XCTAssertTrue(renderedText.contains("print(value)"))
        XCTAssertFalse(renderedText.contains("    let value = 42"))
        XCTAssertEqual(blockKind(containing: "let value = 42", in: document), .codeBlock)
        XCTAssertEqual(blockKind(containing: "print(value)", in: document), .codeBlock)
        XCTAssertEqual(blockKind(containing: "Paragraph after", in: document), .paragraph)
        XCTAssertTrue(containsTextBlock(in: document.renderModel.attributedText, for: "let value = 42"))
    }

    func testRendersSetextHeadingsInOutlineAndReader() {
        let markdown = """
        Setext **Title**
        ===============

        Setext `Subheading`
        -------------------

        Paragraph before rule.

        ---

        Body after rule.
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string
        let headings = document.outline.flattened()

        XCTAssertEqual(headings.map(\.title), ["Setext Title", "Setext Subheading"])
        XCTAssertTrue(renderedText.contains("Setext Title"))
        XCTAssertTrue(renderedText.contains("Setext Subheading"))
        XCTAssertFalse(renderedText.contains("**Title**"))
        XCTAssertFalse(renderedText.contains("==============="))
        XCTAssertFalse(renderedText.contains("-------------------"))
        XCTAssertNotNil(attribute(.backgroundColor, for: "Subheading", in: attributed))
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .thematicBreak })

        let rendered = renderedText as NSString
        let titleRange = rendered.range(of: "Setext Title")
        XCTAssertNotEqual(titleRange.location, NSNotFound)
        let block = document.renderModel.sourceMap.block(
            containing: RenderedTextRange(location: titleRange.location, length: titleRange.length)
        )
        XCTAssertEqual(block?.kind, .heading)
        XCTAssertGreaterThan(block?.sourceRange.length ?? 0, titleRange.length)
    }

    func testRendersReaderFocusedMarkdownExtensions() {
        let markdown = """
        # Reader Fixtures

        - [x] Checked task
        - [ ] Open task

        Paragraph with **bold**, *italic*, ~~deleted~~, `inline code`, [link](https://example.com), and a footnote.[^note]

        ![Architecture diagram](images/architecture.png)

        [^note]: Footnote text with **formatting**.

        $$
        E = mc^2
        $$

        | Name | Status |
        |:---|---:|
        | Reader | Better |
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("☑ Checked task"))
        XCTAssertTrue(renderedText.contains("☐ Open task"))
        XCTAssertTrue(renderedText.contains("deleted"))
        XCTAssertFalse(renderedText.contains("~~deleted~~"))
        XCTAssertTrue(renderedText.contains("Image: Architecture diagram"))
        XCTAssertTrue(renderedText.contains("footnote.¹"))
        XCTAssertTrue(renderedText.contains("1. Footnote text with formatting."))
        XCTAssertFalse(renderedText.contains("[^note]"))
        XCTAssertTrue(renderedText.contains("Formula"))
        XCTAssertFalse(renderedText.contains("$$"))
        XCTAssertTrue(renderedText.contains("Name"))
        XCTAssertTrue(renderedText.contains("Status"))
        XCTAssertTrue(renderedText.contains("Reader"))
        XCTAssertTrue(renderedText.contains("Better"))
        XCTAssertTrue(containsNativeTextTable(in: document.renderModel.attributedText))
        XCTAssertEqual(
            paragraphAlignment(for: "Better", in: document.renderModel.attributedText),
            .right
        )
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .taskList })
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .image })
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .footnote })
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .mathBlock })
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .table })
    }

    func testRendersRealChineseModelOverviewTableAsNativeTable() {
        let markdown = """
        ### 2.1 模型总览表

        | 模型 | 开发方 | 参数量 | 架构 | 开源协议 | 最低显存 | 发布时间 |
        |------|--------|--------|------|----------|----------|----------|
        | **FLUX.2 [dev]** | Black Forest Labs | 32B | MMDiT + VLM | 非商用免费/商用需授权 | ~20GB (4bit) | 2025.11 |
        | **FLUX.1 [dev]** | Black Forest Labs | 12B | MMDiT | 非商用免费 | ~16GB (4bit) | 2024.08 |
        | **FLUX.1 [schnell]** | Black Forest Labs | 12B | MMDiT (蒸馏) | **Apache 2.0** ✅ | ~12GB (4bit) | 2024.08 |
        | **Qwen-Image-2512** | 阿里巴巴 | 20B | MMDiT | **Apache 2.0** ✅ | ~16GB (4bit) | 2025.08 |
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .table })
        XCTAssertTrue(containsNativeTextTable(in: document.renderModel.attributedText))
        XCTAssertTrue(renderedText.contains("FLUX.2 [dev]"))
        XCTAssertTrue(renderedText.contains("非商用免费/商用需授权"))
        XCTAssertFalse(renderedText.contains("| **FLUX.2 [dev]**"))
        XCTAssertFalse(renderedText.contains("|------|"))
    }

    func testRendersReportTableWhenSeparatorColumnCountDriftsByOne() {
        let markdown = """
        ### 2.1 模型总览表

        | 模型 | 开发方 | 参数量 | 架构 | 开源协议 | 最低显存 | 发布时间 |
        |------|--------|--------|------|----------|----------|
        | **FLUX.2 [dev]** | Black Forest Labs | 32B | MMDiT + VLM | 非商用免费/商用需授权 | ~20GB (4bit) | 2025.11 |
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .table })
        XCTAssertTrue(containsNativeTextTable(in: document.renderModel.attributedText))
        XCTAssertTrue(renderedText.contains("FLUX.2 [dev]"))
        XCTAssertTrue(renderedText.contains("发布时间"))
        XCTAssertFalse(renderedText.contains("| 模型"))
        XCTAssertFalse(renderedText.contains("|------|"))
    }

    func testRendersTolerantPipeTablesAsNativeTables() {
        let markdown = """
        | 模型 ｜ 开发方 ｜ 参数量 |
        |———｜:———:｜———:|
        | FLUX\\|2 | Black Forest Labs | 32B |
        """

        let document = MarkdownParser().parse(markdown)
        let attributedText = document.renderModel.attributedText
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .table })
        XCTAssertTrue(containsNativeTextTable(in: attributedText))
        XCTAssertTrue(renderedText.contains("FLUX|2"))
        XCTAssertFalse(renderedText.contains("|———"))
        XCTAssertEqual(paragraphAlignment(for: "32B", in: attributedText)?.rawValue, NSTextAlignment.right.rawValue)
    }

    func testGFMTableAlignmentMarkersDriveTextKitParagraphAlignment() {
        let markdown = """
        | Left | Center | Right |
        |:---|:---:|---:|
        | alpha | centered value | omega |
        """

        let document = MarkdownParser().parse(markdown)
        let attributedText = document.renderModel.attributedText

        XCTAssertTrue(containsNativeTextTable(in: attributedText))
        XCTAssertEqual(paragraphAlignment(for: "alpha", in: attributedText)?.rawValue, NSTextAlignment.left.rawValue)
        XCTAssertEqual(paragraphAlignment(for: "centered value", in: attributedText)?.rawValue, NSTextAlignment.center.rawValue)
        XCTAssertEqual(paragraphAlignment(for: "omega", in: attributedText)?.rawValue, NSTextAlignment.right.rawValue)
        XCTAssertFalse(document.renderModel.renderedPlainText.contains(":---:"))
    }

    func testRendersSimpleHTMLTablesAsNativeTables() {
        let markdown = """
        <table>
          <tr><th>Capability</th><th>Status</th></tr>
          <tr><td>HTML table fallback</td><td>Native table</td></tr>
          <tr><td>Anchor mapping</td><td>Preserved</td></tr>
        </table>

        After table paragraph.
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(containsNativeTextTable(in: attributed))
        XCTAssertTrue(renderedText.contains("Capability"))
        XCTAssertTrue(renderedText.contains("HTML table fallback"))
        XCTAssertTrue(renderedText.contains("After table paragraph."))
        XCTAssertFalse(renderedText.contains("<table>"))
        XCTAssertFalse(renderedText.contains("<td>"))
        XCTAssertEqual(blockKind(containing: "HTML table fallback", in: document), .table)
        XCTAssertEqual(blockKind(containing: "After table paragraph", in: document), .paragraph)
    }

    func testRendersMarkdownHardLineBreaksInsideParagraphs() {
        let markdown = "Address line one  \nAddress line two\\\nAddress line three\nsoft wrapped line"

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Address line one\nAddress line two\nAddress line three soft wrapped line"))
        XCTAssertFalse(renderedText.contains("Address line two\\"))
        XCTAssertFalse(renderedText.contains("Address line three\nsoft wrapped line"))
        XCTAssertEqual(blockKind(containing: "Address line two", in: document), .paragraph)
    }

    func testRendersIndentedListContinuationLinesInsideListBlock() {
        let markdown = """
        - Decision item
          Continuation with **detail** and [link](https://example.com/list).
          More context with `inline code`.

          Loose paragraph with *extra detail*.
          Loose follow-up with `more code`.
        - Follow-up item

        Outside paragraph.
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("• Decision item"))
        XCTAssertTrue(renderedText.contains("Continuation with detail and link."))
        XCTAssertTrue(renderedText.contains("More context with inline code."))
        XCTAssertTrue(renderedText.contains("Loose paragraph with extra detail."))
        XCTAssertTrue(renderedText.contains("Loose follow-up with more code."))
        XCTAssertTrue(renderedText.contains("Outside paragraph."))
        XCTAssertFalse(renderedText.contains("\n  Continuation"))
        XCTAssertFalse(renderedText.contains("\n  Loose paragraph"))
        XCTAssertFalse(renderedText.contains("**detail**"))
        XCTAssertFalse(renderedText.contains("`inline code`"))
        XCTAssertEqual(attribute(.link, for: "link", in: attributed) as? String, "https://example.com/list")
        XCTAssertNotNil(attribute(.backgroundColor, for: "inline code", in: attributed))
        XCTAssertNotNil(attribute(.backgroundColor, for: "more code", in: attributed))
        XCTAssertEqual(blockKind(containing: "Continuation with detail", in: document), .unorderedList)
        XCTAssertEqual(blockKind(containing: "Loose paragraph with extra detail", in: document), .unorderedList)
        XCTAssertEqual(blockKind(containing: "Outside paragraph", in: document), .paragraph)
        XCTAssertGreaterThan(
            firstLineIndent(for: "Continuation with detail", in: attributed),
            firstLineIndent(for: "• Decision item", in: attributed)
        )
        XCTAssertGreaterThan(
            firstLineIndent(for: "Loose paragraph with extra detail", in: attributed),
            firstLineIndent(for: "• Decision item", in: attributed)
        )
    }

    func testPreservesOrderedListStartNumbersAndParenthesizedMarkers() {
        let markdown = """
        3. Preserve the author's starting number.
        4. Continue from the authored number.
        10) Parenthesized ordered marker.
        11) Another parenthesized marker.
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("3. Preserve the author's starting number."))
        XCTAssertTrue(renderedText.contains("4. Continue from the authored number."))
        XCTAssertTrue(renderedText.contains("10) Parenthesized ordered marker."))
        XCTAssertTrue(renderedText.contains("11) Another parenthesized marker."))
        XCTAssertFalse(renderedText.contains("10. Parenthesized ordered marker."))
        XCTAssertEqual(blockKind(containing: "Parenthesized ordered marker", in: document), .orderedList)
        XCTAssertTrue(hasBoldFont(for: "10)", in: attributed))
    }

    func testAppliesInlineMarkdownAttributesWithoutBreakingPlainText() {
        let markdown = "Paragraph with **bold**, *italic*, ~~deleted~~, ==highlighted==, ++inserted text++, `inline code`, H~2~O, x^2^, :rocket:, A &amp; B &lt; C, &#9731;, and [link](https://example.com). Literal technical text keeps API_TOKEN, snake_case, a_b_c, and 2 * 3. Escaped markers keep \\*literal asterisks\\*, \\_literal underscores\\_, \\[not link](https://example.com/no-link), and \\![not image](https://example.com/no-image.png)."
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string as NSString

        let boldRange = renderedText.range(of: "bold")
        let codeRange = renderedText.range(of: "inline code")
        let deletedRange = renderedText.range(of: "deleted")
        let highlightedRange = renderedText.range(of: "highlighted")
        let insertedRange = renderedText.range(of: "inserted text")
        let subscriptRange = renderedText.range(of: "2")
        let superscriptRange = renderedText.range(of: "2", options: [], range: NSRange(location: subscriptRange.upperBound, length: renderedText.length - subscriptRange.upperBound))
        let linkRange = renderedText.range(of: "link")

        XCTAssertNotEqual(boldRange.location, NSNotFound)
        XCTAssertNotEqual(codeRange.location, NSNotFound)
        XCTAssertNotEqual(deletedRange.location, NSNotFound)
        XCTAssertNotEqual(highlightedRange.location, NSNotFound)
        XCTAssertNotEqual(insertedRange.location, NSNotFound)
        XCTAssertNotEqual(subscriptRange.location, NSNotFound)
        XCTAssertNotEqual(superscriptRange.location, NSNotFound)
        XCTAssertNotEqual(linkRange.location, NSNotFound)
        XCTAssertFalse(renderedText.contains("==highlighted=="))
        XCTAssertFalse(renderedText.contains("++inserted text++"))
        XCTAssertFalse(renderedText.contains("H~2~O"))
        XCTAssertFalse(renderedText.contains("x^2^"))
        XCTAssertFalse(renderedText.contains(":rocket:"))
        XCTAssertFalse(renderedText.contains("&amp;"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("A & B < C"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("☃"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("🚀"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("API_TOKEN"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("snake_case"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("a_b_c"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("2 * 3"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("*literal asterisks*"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("_literal underscores_"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("[not link](https://example.com/no-link)"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("![not image](https://example.com/no-image.png)"))
        XCTAssertFalse(document.renderModel.renderedPlainText.contains("\\*literal asterisks\\*"))
        XCTAssertFalse(document.renderModel.renderedPlainText.contains("\\_literal underscores\\_"))
        XCTAssertFalse(document.renderModel.renderedPlainText.contains("Image: not image"))
        XCTAssertNotNil(attributed.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertNotNil(attributed.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil))
        XCTAssertNotNil(attributed.attribute(.foregroundColor, at: codeRange.location, effectiveRange: nil) as? NSColor)
        XCTAssertEqual(attributed.attribute(.strikethroughStyle, at: deletedRange.location, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertNotNil(attributed.attribute(.backgroundColor, at: highlightedRange.location, effectiveRange: nil) as? NSColor)
        XCTAssertEqual(attributed.attribute(.underlineStyle, at: insertedRange.location, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertNotNil(attributed.attribute(.foregroundColor, at: insertedRange.location, effectiveRange: nil) as? NSColor)
        XCTAssertLessThan(
            attributed.attribute(.baselineOffset, at: subscriptRange.location, effectiveRange: nil) as? CGFloat ?? 0,
            0
        )
        XCTAssertGreaterThan(
            attributed.attribute(.baselineOffset, at: superscriptRange.location, effectiveRange: nil) as? CGFloat ?? 0,
            0
        )
        XCTAssertEqual(attributed.attribute(.link, at: linkRange.location, effectiveRange: nil) as? String, "https://example.com")
        XCTAssertFalse(hasItalicFont(for: "snake_case", in: attributed))
        XCTAssertFalse(hasItalicFont(for: "a_b_c", in: attributed))
        XCTAssertFalse(hasItalicFont(for: "literal asterisks", in: attributed))
        XCTAssertFalse(hasItalicFont(for: "literal underscores", in: attributed))
        XCTAssertNil(attribute(.link, for: "not link", in: attributed))
    }

    func testInlineMathRendersAsTokenWithoutEatingPrices() {
        let markdown = "Formula $E = mc^2$ should render cleanly, but $19.99/month should remain a price."
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("Formula E = mc^2 should"))
        XCTAssertFalse(renderedText.contains("$E = mc^2$"))
        XCTAssertTrue(renderedText.contains("$19.99/month"))
        XCTAssertNotNil(attribute(.backgroundColor, for: "E = mc^2", in: attributed))
    }

    func testRendersGFMCalloutMarkersAsReadableBlockquoteLabels() {
        let markdown = """
        > [!NOTE]
        > Reader callouts should be clean.

        > [!WARNING]
        > Risk needs attention.
        """
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertFalse(renderedText.contains("[!NOTE]"))
        XCTAssertFalse(renderedText.contains("[!WARNING]"))
        XCTAssertTrue(renderedText.contains("Note\nReader callouts"))
        XCTAssertTrue(renderedText.contains("Warning\nRisk needs"))
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .blockquote })
        XCTAssertNotNil(attribute(.font, for: "Note", in: attributed) as? NSFont)
        XCTAssertNotNil(attribute(.foregroundColor, for: "Warning", in: attributed) as? NSColor)
    }

    func testRendersBlockquoteLazyContinuationsAndNestedMarkers() {
        let markdown = """
        > First **quote** line.
        Lazy continuation without marker.
        >
        > Second paragraph.
        > > Nested marker should be hidden.

        Outside paragraph.
        """
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("First quote line."))
        XCTAssertTrue(renderedText.contains("Lazy continuation without marker."))
        XCTAssertTrue(renderedText.contains("Second paragraph."))
        XCTAssertTrue(renderedText.contains("Nested marker should be hidden."))
        XCTAssertTrue(renderedText.contains("Outside paragraph."))
        XCTAssertFalse(renderedText.contains("> Nested marker"))
        XCTAssertTrue(hasBoldFont(for: "quote", in: attributed))
        XCTAssertEqual(blockKind(containing: "Lazy continuation without marker", in: document), .blockquote)
        XCTAssertEqual(blockKind(containing: "Nested marker should be hidden", in: document), .blockquote)
        XCTAssertEqual(blockKind(containing: "Outside paragraph", in: document), .paragraph)
        XCTAssertGreaterThan(
            firstLineIndent(for: "Nested marker should be hidden", in: attributed),
            firstLineIndent(for: "Second paragraph", in: attributed)
        )
    }

    func testRendersDefinitionListsWithoutColonMarkers() {
        let markdown = """
        API
        : Application Programming Interface
        : Stable `anchor` contract

        PromptBuilder
        : Builds prompts.
        """
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .definitionList })
        XCTAssertTrue(renderedText.contains("API\nApplication Programming Interface"))
        XCTAssertTrue(renderedText.contains("Stable anchor contract"))
        XCTAssertFalse(renderedText.contains(": Application Programming Interface"))
        XCTAssertFalse(renderedText.contains(": Stable"))
        XCTAssertTrue(hasBoldFont(for: "API", in: attributed))
        XCTAssertNotNil(attribute(.backgroundColor, for: "anchor", in: attributed))
        XCTAssertGreaterThan(
            firstLineIndent(for: "Application Programming Interface", in: attributed),
            firstLineIndent(for: "API", in: attributed)
        )
    }

    func testAppliesSafeInlineHTMLAttributesWithoutExposingTags() {
        let markdown = "Use <kbd>Command</kbd> + <kbd>F</kbd>, <mark>marked HTML</mark>, H<sub>2</sub>O, x<sup>2</sup>, <ins>inserted HTML</ins>, <del>removed HTML</del>, and <small>quiet HTML</small>. Link to <a href=\"https://example.com/html-link\" title=\"HTML link title\">HTML link label</a><br>Next line with <img src=\"https://example.com/html-image.png\" alt=\"HTML diagram\">."
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string as NSString

        XCTAssertTrue(renderedText.contains("Command + F"))
        XCTAssertTrue(renderedText.contains("marked HTML"))
        XCTAssertTrue(renderedText.contains("H2O"))
        XCTAssertTrue(renderedText.contains("x2"))
        XCTAssertTrue(renderedText.contains("inserted HTML"))
        XCTAssertTrue(renderedText.contains("removed HTML"))
        XCTAssertTrue(renderedText.contains("quiet HTML"))
        XCTAssertTrue(renderedText.contains("HTML link label\nNext line"))
        XCTAssertTrue(renderedText.contains("Image: HTML diagram (https://example.com/html-image.png)"))
        XCTAssertFalse(renderedText.contains("<kbd>"))
        XCTAssertFalse(renderedText.contains("<mark>"))
        XCTAssertFalse(renderedText.contains("<sub>"))
        XCTAssertFalse(renderedText.contains("<sup>"))
        XCTAssertFalse(renderedText.contains("<ins>"))
        XCTAssertFalse(renderedText.contains("<del>"))
        XCTAssertFalse(renderedText.contains("<small>"))
        XCTAssertFalse(renderedText.contains("<a "))
        XCTAssertFalse(renderedText.contains("href="))
        XCTAssertFalse(renderedText.contains("<br"))
        XCTAssertFalse(renderedText.contains("<img"))
        XCTAssertNotNil(attribute(.backgroundColor, for: "Command", in: attributed))
        XCTAssertNotNil(attribute(.backgroundColor, for: "marked HTML", in: attributed))
        XCTAssertEqual(attribute(.underlineStyle, for: "inserted HTML", in: attributed) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attribute(.strikethroughStyle, for: "removed HTML", in: attributed) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertNotNil(attribute(.foregroundColor, for: "quiet HTML", in: attributed) as? NSColor)
        XCTAssertEqual(attribute(.link, for: "HTML link label", in: attributed) as? String, "https://example.com/html-link")
        XCTAssertEqual(attribute(.toolTip, for: "HTML link label", in: attributed) as? String, "HTML link title")
        XCTAssertEqual(attribute(.link, for: "https://example.com/html-image.png", in: attributed) as? String, "https://example.com/html-image.png")

        let h2oRange = renderedText.range(of: "H2O")
        let x2Range = renderedText.range(of: "x2")
        XCTAssertNotEqual(h2oRange.location, NSNotFound)
        XCTAssertNotEqual(x2Range.location, NSNotFound)
        guard h2oRange.location != NSNotFound,
              x2Range.location != NSNotFound
        else {
            return
        }

        let h2oSubscriptRange = renderedText.range(of: "2", range: h2oRange)
        let x2SuperscriptRange = renderedText.range(of: "2", range: x2Range)
        XCTAssertLessThan(
            attributed.attribute(.baselineOffset, at: h2oSubscriptRange.location, effectiveRange: nil) as? CGFloat ?? 0,
            0
        )
        XCTAssertGreaterThan(
            attributed.attribute(.baselineOffset, at: x2SuperscriptRange.location, effectiveRange: nil) as? CGFloat ?? 0,
            0
        )
    }

    func testRendersAbbreviationDefinitionsAsInlineHints() {
        let markdown = """
        *[API]: Application Programming Interface

        A stable API remains selectable.
        """
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("A stable API remains selectable."))
        XCTAssertFalse(renderedText.contains("Application Programming Interface"))
        XCTAssertEqual(
            attribute(.toolTip, for: "API", in: attributed) as? String,
            "Application Programming Interface"
        )
        XCTAssertTrue(hasDottedUnderline(for: "API", in: attributed))
    }

    func testRendersReferenceStyleLinksAndImages() {
        let markdown = """
        Reference [Markdown Reader][reader].
        Collapsed [Docs][].
        Regular duplicate [Docs](https://example.com/regular-docs).
        Missing [Nope][missing].
        Inline image ![Build badge](https://example.com/badge.svg) and referenced icon ![Local icon][diagram].

        ![Diagram][diagram]

        [reader]: https://md-reader.github.io/ "Reader"
        [Docs]: https://example.com/docs
        [diagram]: images/architecture.png
        """
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string
        let rendered = renderedText as NSString

        XCTAssertTrue(renderedText.contains("Reference Markdown Reader."))
        XCTAssertTrue(renderedText.contains("Collapsed Docs."))
        XCTAssertTrue(renderedText.contains("Regular duplicate Docs."))
        XCTAssertTrue(renderedText.contains("Missing [Nope][missing]."))
        XCTAssertTrue(renderedText.contains("Inline image Image: Build badge (https://example.com/badge.svg)"))
        XCTAssertTrue(renderedText.contains("referenced icon Image: Local icon (images/architecture.png)."))
        XCTAssertTrue(renderedText.contains("Image: Diagram"))
        XCTAssertTrue(renderedText.contains("images/architecture.png"))
        XCTAssertFalse(renderedText.contains("[reader]:"))
        XCTAssertFalse(renderedText.contains("[Markdown Reader][reader]"))
        XCTAssertFalse(renderedText.contains("![Build badge]"))
        XCTAssertFalse(renderedText.contains("![Local icon][diagram]"))
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .image })
        XCTAssertEqual(
            attribute(.link, for: "Markdown Reader", in: attributed) as? String,
            "https://md-reader.github.io/"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Markdown Reader", in: attributed) as? String,
            "Reader"
        )
        XCTAssertEqual(
            attribute(.link, for: "Docs", in: attributed) as? String,
            "https://example.com/docs"
        )
        XCTAssertEqual(
            attribute(.link, for: "https://example.com/badge.svg", in: attributed) as? String,
            "https://example.com/badge.svg"
        )

        let duplicateLineRange = rendered.range(of: "Regular duplicate Docs.")
        XCTAssertNotEqual(duplicateLineRange.location, NSNotFound)
        if duplicateLineRange.location != NSNotFound {
            let duplicateDocsRange = rendered.range(of: "Docs", range: duplicateLineRange)
            XCTAssertNotEqual(duplicateDocsRange.location, NSNotFound)
            XCTAssertEqual(
                attributed.attribute(.link, at: duplicateDocsRange.location, effectiveRange: nil) as? String,
                "https://example.com/regular-docs"
            )
        }
    }

    func testParsesLargeMarkdownDocument() {
        let paragraph = "这是一段用于验证长文档解析和渲染稳定性的中文内容，包含产品目标、背景、约束和修改建议。"
        let body = (1...900)
            .map { index in "## 第 \(index) 节\n\n\(paragraph)\(paragraph)\(paragraph)" }
            .joined(separator: "\n\n")
        let markdown = "# 长文档\n\n\(body)"

        let document = MarkdownParser().parse(markdown)

        XCTAssertGreaterThan(document.rawMarkdown.count, 50_000)
        XCTAssertEqual(document.outline.flattened().count, 901)
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("第 900 节"))
    }

    private func samplePRDURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("samples/markdown/sample_prd.md")
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

    private func containsTextBlock(in attributedText: NSAttributedString, for needle: String) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound,
              let paragraph = attributedText.attribute(
                .paragraphStyle,
                at: match.location,
                effectiveRange: nil
              ) as? NSParagraphStyle
        else {
            return false
        }

        return paragraph.textBlocks.isEmpty == false
    }

    private func paragraphAlignment(
        for needle: String,
        in attributedText: NSAttributedString
    ) -> NSTextAlignment? {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return nil
        }

        let paragraphStyle = attributedText.attribute(
            .paragraphStyle,
            at: match.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        return paragraphStyle?.alignment
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

    private func blockKind(containing needle: String, in document: MarkdownDocument) -> MarkdownRenderBlockKind? {
        let rendered = document.renderModel.renderedPlainText as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound else {
            return nil
        }

        return document.renderModel.sourceMap.block(
            containing: RenderedTextRange(location: match.location, length: match.length)
        )?.kind
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

    private func hasItalicFont(for needle: String, in attributedText: NSAttributedString) -> Bool {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: needle)
        guard match.location != NSNotFound,
              let font = attributedText.attribute(.font, at: match.location, effectiveRange: nil) as? NSFont
        else {
            return false
        }

        return NSFontManager.shared.traits(of: font).contains(.italicFontMask)
    }

    private func hasDottedUnderline(for needle: String, in attributedText: NSAttributedString) -> Bool {
        guard let style = attribute(.underlineStyle, for: needle, in: attributedText) as? Int else {
            return false
        }
        return style & NSUnderlineStyle.patternDot.rawValue != 0
    }
}
