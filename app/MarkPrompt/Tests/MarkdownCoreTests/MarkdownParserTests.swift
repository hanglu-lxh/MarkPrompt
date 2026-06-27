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

    func testRendersFrontmatterAsReadablePropertiesBlock() {
        let markdown = """
        ---
        title: Reader Fixture Frontmatter
        owner: MarkPrompt
        tags:
          - markdown
          - reader
        ---

        # Body
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.hasPrefix("Properties\n"))
        XCTAssertTrue(renderedText.contains("Title: Reader Fixture Frontmatter"))
        XCTAssertTrue(renderedText.contains("Owner: MarkPrompt"))
        XCTAssertTrue(renderedText.contains("Tags: markdown  reader"))
        XCTAssertFalse(renderedText.contains("Metadata:"))
        XCTAssertFalse(renderedText.contains("---"))
        XCTAssertFalse(renderedText.contains("  - markdown"))
        XCTAssertTrue(containsTextBlock(in: attributed, for: "Properties"))
        XCTAssertNotNil(attribute(.backgroundColor, for: "markdown", in: attributed))
        XCTAssertNotNil(attribute(.backgroundColor, for: "reader", in: attributed))
        XCTAssertEqual(blockKind(containing: "Properties", in: document), .metadata)
        XCTAssertEqual(blockKind(containing: "markdown", in: document), .metadata)
        XCTAssertEqual(blockKind(containing: "Body", in: document), .heading)
    }

    func testRendersReaderFocusedMarkdownExtensions() {
        let markdown = """
        # Reader Fixtures

        - [x] Checked task
          Completed continuation should look done.
        - [ ] Open task
        - [-] Rejected task
        - [/] In-progress task
        - [!] Important task
        - [a] Arbitrary completed task

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
        let attributed = document.renderModel.attributedText

        XCTAssertTrue(renderedText.contains("☑ Checked task"))
        XCTAssertTrue(renderedText.contains("☐ Open task"))
        XCTAssertTrue(renderedText.contains("☒ Rejected task"))
        XCTAssertTrue(renderedText.contains("◩ In-progress task"))
        XCTAssertTrue(renderedText.contains("⚠ Important task"))
        XCTAssertTrue(renderedText.contains("☑ Arbitrary completed task"))
        XCTAssertFalse(renderedText.contains("[-] Rejected task"))
        XCTAssertFalse(renderedText.contains("[/] In-progress task"))
        XCTAssertFalse(renderedText.contains("[!] Important task"))
        XCTAssertFalse(renderedText.contains("[a] Arbitrary completed task"))
        XCTAssertTrue(hasStrikethroughAttribute(for: "Checked task", in: attributed))
        XCTAssertTrue(hasStrikethroughAttribute(for: "Completed continuation should look done.", in: attributed))
        XCTAssertTrue(hasStrikethroughAttribute(for: "Arbitrary completed task", in: attributed))
        XCTAssertFalse(hasStrikethroughAttribute(for: "Open task", in: attributed))
        XCTAssertFalse(hasStrikethroughAttribute(for: "In-progress task", in: attributed))
        XCTAssertFalse(hasStrikethroughAttribute(for: "Important task", in: attributed))
        XCTAssertEqual(
            taskMarkerSourceRange(for: "☑ Checked task", in: attributed),
            sourceRange(of: "[x]", in: markdown)
        )
        XCTAssertEqual(
            taskMarkerSourceRange(for: "☐ Open task", in: attributed),
            sourceRange(of: "[ ]", in: markdown)
        )
        XCTAssertEqual(
            attribute(NSAttributedString.Key("MarkPromptTaskMarkerCharacter"), for: "☐ Open task", in: attributed) as? String,
            " "
        )
        XCTAssertEqual(
            attribute(NSAttributedString.Key("MarkPromptTaskMarkerCharacter"), for: "◩ In-progress task", in: attributed) as? String,
            "/"
        )
        XCTAssertNil(attribute(NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"), for: "Checked task", in: attributed))
        XCTAssertNil(attribute(NSAttributedString.Key("MarkPromptTaskMarkerCharacter"), for: "Checked task", in: attributed))
        XCTAssertEqual(
            attribute(.toolTip, for: "☑ Checked task", in: attributed) as? String,
            "点击或按 Space/⌘L 切换完成/待办；⌘⌥J/K 跳转任务；右键可标记待办/完成/取消/进行中/重要。"
        )
        XCTAssertTrue(renderedText.contains("deleted"))
        XCTAssertFalse(renderedText.contains("~~deleted~~"))
        XCTAssertTrue(renderedText.contains("Image: Architecture diagram"))
        XCTAssertTrue(renderedText.contains("footnote.¹"))
        XCTAssertTrue(renderedText.contains("1. Footnote text with formatting."))
        XCTAssertFalse(renderedText.contains("[^note]"))
        XCTAssertEqual(
            attribute(.toolTip, for: "¹", in: attributed) as? String,
            "Footnote text with formatting."
        )
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
        XCTAssertEqual(blockKind(containing: "Completed continuation should look done.", in: document), .taskList)
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

    func testRendersObsidianImageEmbedsInsideTables() {
        let markdown = """
        | Evidence | Preview | Status |
        |---|---|---|
        | Screenshot | ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|140]] | Ready |
        """

        let document = MarkdownParser().parse(markdown, fileURL: readerFixtureURL(named: "03_tables_wide.md"))
        let attributedText = document.renderModel.attributedText
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(containsNativeTextTable(in: attributedText))
        XCTAssertTrue(renderedText.contains("Screenshot"))
        XCTAssertTrue(renderedText.contains("Ready"))
        XCTAssertTrue(renderedText.contains("Embed: markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: ../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: 140"))
        XCTAssertFalse(renderedText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|140]]"))
        XCTAssertEqual(attachmentCount(in: attributedText), 1)
        XCTAssertEqual(firstAttachmentSize(in: attributedText)?.width ?? 0, 140, accuracy: 0.5)
        XCTAssertEqual(
            attribute(.toolTip, for: "Embed: markprompt_interaction_prototype_v4.png", in: attributedText) as? String,
            "../../../docs/assets/markprompt_interaction_prototype_v4.png"
        )
        XCTAssertEqual(blockKind(containing: "Embed: markprompt_interaction_prototype_v4.png", in: document), .table)
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
        let markdown = "Paragraph with **bold**, *italic*, ~~deleted~~, ==highlighted==, ++inserted text++, `inline code`, H~2~O, x^2^, :rocket:, A &amp; B &lt; C, &#9731;, and [link](https://example.com). Literal technical text keeps API_TOKEN, snake_case, a_b_c, and 2 * 3. Tags style #reader/tag, but code `#not-a-tag` stays code. Bare URLs link https://example.com/live-url and autolinks link <https://example.com/autolink-url>, but code URLs `https://example.com/code-url` and `<https://example.com/code-autolink>` stay code. Escaped markers keep \\*literal asterisks\\*, \\_literal underscores\\_, \\[not link](https://example.com/no-link), and \\![not image](https://example.com/no-image.png)."
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
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("#reader/tag"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("#not-a-tag"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("https://example.com/live-url"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("https://example.com/autolink-url"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("https://example.com/code-url"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("<https://example.com/code-autolink>"))
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
        XCTAssertTrue(hasFixedPitchFont(for: "#not-a-tag", in: attributed))
        XCTAssertFalse(hasFixedPitchFont(for: "#reader/tag", in: attributed))
        XCTAssertNotNil(attribute(.backgroundColor, for: "#reader/tag", in: attributed) as? NSColor)
        XCTAssertEqual(attribute(.link, for: "https://example.com/live-url", in: attributed) as? String, "https://example.com/live-url")
        XCTAssertEqual(attribute(.link, for: "https://example.com/autolink-url", in: attributed) as? String, "https://example.com/autolink-url")
        XCTAssertNil(attribute(.link, for: "https://example.com/code-url", in: attributed))
        XCTAssertNil(attribute(.link, for: "https://example.com/code-autolink", in: attributed))
        XCTAssertTrue(hasFixedPitchFont(for: "https://example.com/code-url", in: attributed))
        XCTAssertTrue(hasFixedPitchFont(for: "https://example.com/code-autolink", in: attributed))
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

        > [!todo]+ Ship review workflow
        > Create a focused note.

        > [!faq]- Why keep source text?
        > Anchors need selectable text.

        > [!bug]
        > Renderer bug reports should stand out.

        > [!review]
        > Custom callout types should fall back to note styling.

        > [!design-review]- Needs design check
        > Custom folded callouts should still hide source syntax.
        """
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertFalse(renderedText.contains("[!NOTE]"))
        XCTAssertFalse(renderedText.contains("[!WARNING]"))
        XCTAssertFalse(renderedText.contains("[!todo]+"))
        XCTAssertFalse(renderedText.contains("[!faq]-"))
        XCTAssertFalse(renderedText.contains("[!bug]"))
        XCTAssertFalse(renderedText.contains("[!review]"))
        XCTAssertFalse(renderedText.contains("[!design-review]-"))
        XCTAssertFalse(renderedText.contains("+ Ship review workflow"))
        XCTAssertFalse(renderedText.contains("- Why keep source text?"))
        XCTAssertTrue(renderedText.contains("Note\nReader callouts"))
        XCTAssertTrue(renderedText.contains("Warning\nRisk needs"))
        XCTAssertTrue(renderedText.contains("▾ Ship review workflow\nCreate a focused note."))
        XCTAssertTrue(renderedText.contains("▸ Why keep source text?\nAnchors need selectable text."))
        XCTAssertTrue(renderedText.contains("Bug\nRenderer bug reports"))
        XCTAssertTrue(renderedText.contains("Review\nCustom callout types should fall back"))
        XCTAssertTrue(renderedText.contains("▸ Needs design check\nCustom folded callouts"))
        XCTAssertTrue(document.renderModel.sourceMap.blocks.contains { $0.kind == .blockquote })
        XCTAssertNotNil(attribute(.font, for: "Note", in: attributed) as? NSFont)
        XCTAssertNotNil(attribute(.foregroundColor, for: "Warning", in: attributed) as? NSColor)
        XCTAssertEqual(
            attribute(.toolTip, for: "▾", in: attributed) as? String,
            "Default expanded in Obsidian"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "▸", in: attributed) as? String,
            "Default collapsed in Obsidian"
        )
        XCTAssertNotNil(attribute(.foregroundColor, for: "Bug", in: attributed) as? NSColor)
        XCTAssertEqual(blockKind(containing: "Custom callout types should fall back", in: document), .blockquote)
        XCTAssertEqual(blockKind(containing: "Needs design check", in: document), .blockquote)
    }

    func testRendersNestedObsidianCalloutMarkersAsReadableIndentedTitles() {
        let markdown = """
        > [!NOTE] Parent review context
        > Parent context should stay visible.
        > > [!tip]- Nested reviewer hint
        > > Inner nested detail should keep indentation.
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("Parent review context"))
        XCTAssertTrue(renderedText.contains("Parent context should stay visible."))
        XCTAssertTrue(renderedText.contains("▸ Nested reviewer hint"))
        XCTAssertTrue(renderedText.contains("Inner nested detail should keep indentation."))
        XCTAssertFalse(renderedText.contains("[!tip]-"))
        XCTAssertFalse(renderedText.contains("- Nested reviewer hint"))
        XCTAssertEqual(blockKind(containing: "Nested reviewer hint", in: document), .blockquote)
        XCTAssertGreaterThan(
            firstLineIndent(for: "▸ Nested reviewer hint", in: attributed),
            firstLineIndent(for: "Parent context should stay visible", in: attributed)
        )
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

        A stable API remains selectable, while code `API()` stays plain code.
        """
        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("A stable API remains selectable, while code API() stays plain code."))
        XCTAssertFalse(renderedText.contains("Application Programming Interface"))
        XCTAssertEqual(
            attribute(.toolTip, for: "API", in: attributed) as? String,
            "Application Programming Interface"
        )
        XCTAssertTrue(hasDottedUnderline(for: "API", in: attributed))
        XCTAssertNil(attribute(.toolTip, for: "API()", in: attributed))
        XCTAssertFalse(hasDottedUnderline(for: "API()", in: attributed))
        XCTAssertTrue(hasFixedPitchFont(for: "API()", in: attributed))
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

    func testRendersObsidianFlavoredInlineSyntaxAsReadableText() {
        let markdown = """
        Link to [[Daily note]] and [[Project plan|project plan]] with #review/urgent.
        Jump to [[Prompt Quality#Review checklist]] and [[Decision Log#^accepted]] without losing anchors.
        Extension targets should read cleanly as [[Research/Prompt Notes.md#Methods]].
        Encoded targets should read cleanly as [[Research/Prompt%20Notes.md#Method%20Plan]].
        Alias still wins for [[Reader Vault/Weekly Review#Retro|weekly retro]].

        Attachment ![[Architecture.png]] next to a hidden %%draft-only comment%% note. ^review-block
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = attributed.string

        XCTAssertTrue(renderedText.contains("Link to Daily note and project plan with #review/urgent."))
        XCTAssertTrue(renderedText.contains("Jump to Prompt Quality#Review checklist and Decision Log#^accepted without losing anchors."))
        XCTAssertTrue(renderedText.contains("Extension targets should read cleanly as Prompt Notes#Methods."))
        XCTAssertTrue(renderedText.contains("Encoded targets should read cleanly as Prompt Notes#Method Plan."))
        XCTAssertTrue(renderedText.contains("Alias still wins for weekly retro."))
        XCTAssertTrue(renderedText.contains("Attachment Embed: Architecture.png next to a hidden note."))
        XCTAssertFalse(renderedText.contains("[[Daily note]]"))
        XCTAssertFalse(renderedText.contains("[[Project plan|project plan]]"))
        XCTAssertFalse(renderedText.contains("[[Prompt Quality#Review checklist]]"))
        XCTAssertFalse(renderedText.contains("[[Decision Log#^accepted]]"))
        XCTAssertFalse(renderedText.contains("Prompt Notes.md#Methods"))
        XCTAssertFalse(renderedText.contains("Prompt%20Notes"))
        XCTAssertFalse(renderedText.contains("Method%20Plan"))
        XCTAssertFalse(renderedText.contains("[[Reader Vault/Weekly Review#Retro|weekly retro]]"))
        XCTAssertFalse(renderedText.contains("![[Architecture.png]]"))
        XCTAssertFalse(renderedText.contains("%%draft-only comment%%"))
        XCTAssertFalse(renderedText.contains("^review-block"))
        XCTAssertEqual(attribute(.link, for: "Daily note", in: attributed) as? String, "obsidian://Daily%20note")
        XCTAssertEqual(attribute(.link, for: "project plan", in: attributed) as? String, "obsidian://Project%20plan")
        XCTAssertEqual(attribute(.link, for: "Prompt Quality#Review checklist", in: attributed) as? String, "obsidian://Prompt%20Quality#Review%20checklist")
        XCTAssertEqual(attribute(.toolTip, for: "Prompt Quality#Review checklist", in: attributed) as? String, "Prompt Quality#Review checklist")
        XCTAssertEqual(attribute(.link, for: "Decision Log#^accepted", in: attributed) as? String, "obsidian://Decision%20Log#^accepted")
        XCTAssertEqual(attribute(.link, for: "Prompt Notes#Methods", in: attributed) as? String, "obsidian://Research/Prompt%20Notes.md#Methods")
        XCTAssertEqual(attribute(.toolTip, for: "Prompt Notes#Methods", in: attributed) as? String, "Research/Prompt Notes.md#Methods")
        XCTAssertEqual(attribute(.link, for: "Prompt Notes#Method Plan", in: attributed) as? String, "obsidian://Research/Prompt%20Notes.md#Method%20Plan")
        XCTAssertEqual(attribute(.toolTip, for: "Prompt Notes#Method Plan", in: attributed) as? String, "Research/Prompt Notes.md#Method Plan")
        XCTAssertEqual(attribute(.link, for: "weekly retro", in: attributed) as? String, "obsidian://Reader%20Vault/Weekly%20Review#Retro")
        XCTAssertNotNil(attribute(.backgroundColor, for: "#review/urgent", in: attributed))
        XCTAssertNotNil(attribute(.backgroundColor, for: "Embed: Architecture.png", in: attributed))
    }

    func testHidesStandaloneObsidianBlockIDsBeforeParagraphParsing() {
        let markdown = """
        Visible decision paragraph.

        ^accepted-decision

        Follow-up paragraph with [[Decision Log#^accepted-decision]].
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Visible decision paragraph."))
        XCTAssertTrue(renderedText.contains("Follow-up paragraph with Decision Log#^accepted-decision."))
        XCTAssertFalse(renderedText.contains("^accepted-decision\n"))
        XCTAssertFalse(renderedText.contains("\n^accepted-decision"))
        XCTAssertEqual(
            attribute(.link, for: "Decision Log#^accepted-decision", in: attributed) as? String,
            "obsidian://Decision%20Log#^accepted-decision"
        )
        XCTAssertEqual(blockKind(containing: "Visible decision paragraph", in: document), .paragraph)
        XCTAssertEqual(blockKind(containing: "Follow-up paragraph", in: document), .paragraph)
    }

    func testRendersObsidianMarkdownFormatInternalLinksAsLocalLinks() {
        let markdown = """
        Markdown internal [review checklist](Prompt%20Quality.md#Review%20checklist), nested [weekly retro](Reader%20Vault/Weekly%20Review.md#Retro), extensionless [plain note](Three%20laws%20of%20motion), extensionless anchored [retro note](Reader%20Vault/Weekly%20Review#Retro), and same-note [decision block](#^accepted) should behave like wikilinks.
        External [docs](https://example.com/docs) should stay external.
        """

        let document = MarkdownParser().parse(markdown)
        let attributed = document.renderModel.attributedText
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Markdown internal review checklist, nested weekly retro, extensionless plain note, extensionless anchored retro note, and same-note decision block should behave like wikilinks."))
        XCTAssertFalse(renderedText.contains("Prompt%20Quality.md"))
        XCTAssertFalse(renderedText.contains("Reader%20Vault/Weekly%20Review.md"))
        XCTAssertFalse(renderedText.contains("Three%20laws%20of%20motion"))
        XCTAssertFalse(renderedText.contains("Reader%20Vault/Weekly%20Review#Retro"))
        XCTAssertFalse(renderedText.contains("#^accepted)"))
        XCTAssertEqual(
            attribute(.link, for: "review checklist", in: attributed) as? String,
            "obsidian://Prompt%20Quality#Review%20checklist"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "review checklist", in: attributed) as? String,
            "Prompt Quality#Review checklist"
        )
        XCTAssertEqual(
            attribute(.link, for: "weekly retro", in: attributed) as? String,
            "obsidian://Reader%20Vault/Weekly%20Review#Retro"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "weekly retro", in: attributed) as? String,
            "Reader Vault/Weekly Review#Retro"
        )
        XCTAssertEqual(
            attribute(.link, for: "plain note", in: attributed) as? String,
            "obsidian://Three%20laws%20of%20motion"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "plain note", in: attributed) as? String,
            "Three laws of motion"
        )
        XCTAssertEqual(
            attribute(.link, for: "retro note", in: attributed) as? String,
            "obsidian://Reader%20Vault/Weekly%20Review#Retro"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "retro note", in: attributed) as? String,
            "Reader Vault/Weekly Review#Retro"
        )
        XCTAssertEqual(
            attribute(.link, for: "decision block", in: attributed) as? String,
            "obsidian://#^accepted"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "decision block", in: attributed) as? String,
            "#^accepted"
        )
        XCTAssertEqual(
            attribute(.link, for: "docs", in: attributed) as? String,
            "https://example.com/docs"
        )
        XCTAssertEqual(blockKind(containing: "review checklist", in: document), .paragraph)
    }

    func testHidesObsidianBlockCommentsBeforeBlockParsing() {
        let markdown = """
        Visible before.

        %%
        Reviewer-only checklist:
        - hidden task marker should never become a list

        Hidden paragraph after a blank line.
        %%

        Visible after with [[Daily note]].
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Visible before."))
        XCTAssertTrue(renderedText.contains("Visible after with Daily note."))
        XCTAssertFalse(renderedText.contains("%%"))
        XCTAssertFalse(renderedText.contains("Reviewer-only checklist"))
        XCTAssertFalse(renderedText.contains("hidden task marker"))
        XCTAssertFalse(renderedText.contains("Hidden paragraph after a blank line"))
        XCTAssertEqual(blockKind(containing: "Visible after with Daily note.", in: document), .paragraph)
        XCTAssertEqual(attribute(.link, for: "Daily note", in: document.renderModel.attributedText) as? String, "obsidian://Daily%20note")
    }

    func testRendersObsidianInlineFootnotesAsReadableReferences() {
        let markdown = """
        Inline review evidence^[Keep this reviewer context out of selected text.] stays readable.
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Inline review evidence¹ stays readable."))
        XCTAssertFalse(renderedText.contains("^[Keep this reviewer context out of selected text.]"))
        XCTAssertEqual(blockKind(containing: "Inline review evidence", in: document), .paragraph)
        XCTAssertEqual(
            attribute(.toolTip, for: "¹", in: document.renderModel.attributedText) as? String,
            "Keep this reviewer context out of selected text."
        )
        XCTAssertNotNil(attribute(.baselineOffset, for: "¹", in: document.renderModel.attributedText))
        XCTAssertEqual(
            attribute(.underlineStyle, for: "¹", in: document.renderModel.attributedText) as? Int,
            NSUnderlineStyle.single.union(.patternDot).rawValue
        )
        XCTAssertNotNil(attribute(.underlineColor, for: "¹", in: document.renderModel.attributedText) as? NSColor)
    }

    func testRendersTwoSpaceFootnoteContinuationsInsideFootnoteBlock() {
        let markdown = """
        Claim needs context.[^review]

        [^review]: First reviewer detail.
          Second detail uses Obsidian two-space continuation.

        After footnote paragraph.
        """

        let document = MarkdownParser().parse(markdown)
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Claim needs context.¹"))
        XCTAssertTrue(renderedText.contains("1. First reviewer detail. Second detail uses Obsidian two-space continuation."))
        XCTAssertEqual(
            attribute(.toolTip, for: "¹", in: document.renderModel.attributedText) as? String,
            "First reviewer detail. Second detail uses Obsidian two-space continuation."
        )
        XCTAssertEqual(
            blockKind(containing: "Second detail uses Obsidian two-space continuation", in: document),
            .footnote
        )
        XCTAssertEqual(blockKind(containing: "After footnote paragraph.", in: document), .paragraph)
    }

    func testRendersLocalObsidianImageEmbedsWithPreviewAndConciseSelectableFallback() {
        let markdown = """
        Image embed ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|220]] stays selectable.
        """

        let document = MarkdownParser().parse(markdown, fileURL: readerFixtureURL(named: "10_review_prd_mix.md"))
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Embed: markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: ../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: 220"))
        XCTAssertFalse(renderedText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|220]]"))
        XCTAssertEqual(attachmentCount(in: document.renderModel.attributedText), 1)
        XCTAssertTrue(document.renderModel.attributedText.string.contains(
            "Image embed\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png"
        ))
        XCTAssertEqual(
            attribute(.toolTip, for: "Embed: markprompt_interaction_prototype_v4.png", in: document.renderModel.attributedText) as? String,
            "../../../docs/assets/markprompt_interaction_prototype_v4.png"
        )
        let previewSize = firstAttachmentSize(in: document.renderModel.attributedText)
        XCTAssertEqual(previewSize?.width ?? 0, 220, accuracy: 0.5)
        XCTAssertGreaterThan(previewSize?.height ?? 0, 0)
        XCTAssertEqual(blockKind(containing: "Embed: markprompt_interaction_prototype_v4.png", in: document), .paragraph)
    }

    func testRendersObsidianImageEmbedBoxDimensionsWithoutAliasText() {
        let markdown = """
        Boxed image ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|300x80]] keeps its target text.
        """

        let document = MarkdownParser().parse(markdown, fileURL: readerFixtureURL(named: "10_review_prd_mix.md"))
        let renderedText = document.renderModel.renderedPlainText
        let previewSize = firstAttachmentSize(in: document.renderModel.attributedText)

        XCTAssertTrue(renderedText.contains("Embed: markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: ../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: 300x80"))
        XCTAssertEqual(attachmentCount(in: document.renderModel.attributedText), 1)
        XCTAssertLessThanOrEqual(previewSize?.width ?? 0, 300.5)
        XCTAssertEqual(previewSize?.height ?? 0, 80, accuracy: 0.5)
    }

    func testSeparatesObsidianImageEmbedFallbackFromFollowingText() {
        let markdown = """
        Paragraph ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|120]] continues after media.
        Punctuated ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|120]]. Next sentence.
        """

        let document = MarkdownParser().parse(markdown, fileURL: readerFixtureURL(named: "10_review_prd_mix.md"))
        let attributedText = document.renderModel.attributedText.string

        XCTAssertEqual(attachmentCount(in: document.renderModel.attributedText), 2)
        XCTAssertTrue(attributedText.contains(
            "Paragraph\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png\ncontinues after media."
        ))
        XCTAssertTrue(attributedText.contains(
            "Punctuated\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png.\nNext sentence."
        ))
        XCTAssertFalse(attributedText.contains("markprompt_interaction_prototype_v4.png continues"))
        XCTAssertFalse(attributedText.contains("markprompt_interaction_prototype_v4.png. Next"))
        XCTAssertFalse(attributedText.contains("../../../docs/assets/markprompt_interaction_prototype_v4.png"))
    }

    func testRendersObsidianImageEmbedsInsideListsAndBlockquotes() {
        let markdown = """
        - Evidence item ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|180]] stays in the list.
        > Quoted evidence ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|160]] stays in the quote.
        """

        let document = MarkdownParser().parse(markdown, fileURL: readerFixtureURL(named: "10_review_prd_mix.md"))
        let renderedText = document.renderModel.renderedPlainText
        let previewSizes = attachmentSizes(in: document.renderModel.attributedText)

        XCTAssertTrue(renderedText.contains("Evidence item"))
        XCTAssertTrue(renderedText.contains("Quoted evidence"))
        XCTAssertEqual(attachmentCount(in: document.renderModel.attributedText), 2)
        XCTAssertEqual(previewSizes.map(\.width), [180, 160])
        XCTAssertTrue(document.renderModel.attributedText.string.contains(
            "• Evidence item\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png\nstays in the list."
        ))
        XCTAssertTrue(document.renderModel.attributedText.string.contains(
            "Quoted evidence\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png\nstays in the quote."
        ))
        XCTAssertFalse(renderedText.contains("Embed: 180"))
        XCTAssertFalse(renderedText.contains("Embed: 160"))
        XCTAssertFalse(renderedText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|180]]"))
        XCTAssertFalse(renderedText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|160]]"))
        XCTAssertEqual(blockKind(containing: "Evidence item", in: document), .unorderedList)
        XCTAssertEqual(blockKind(containing: "Quoted evidence", in: document), .blockquote)
    }

    func testRendersObsidianImageEmbedsInsideDefinitionLists() {
        let markdown = """
        Evidence artifact
        : Screenshot ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|150]] documents the review surface.
        """

        let document = MarkdownParser().parse(markdown, fileURL: readerFixtureURL(named: "02_lists_tasks.md"))
        let renderedText = document.renderModel.renderedPlainText
        let previewSizes = attachmentSizes(in: document.renderModel.attributedText)

        XCTAssertTrue(renderedText.contains("Evidence artifact"))
        XCTAssertTrue(renderedText.contains("Screenshot"))
        XCTAssertTrue(renderedText.contains("Embed: markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: ../../../docs/assets/markprompt_interaction_prototype_v4.png"))
        XCTAssertFalse(renderedText.contains("Embed: 150"))
        XCTAssertFalse(renderedText.contains("![[../../../docs/assets/markprompt_interaction_prototype_v4.png|150]]"))
        XCTAssertEqual(attachmentCount(in: document.renderModel.attributedText), 1)
        XCTAssertEqual(previewSizes.map(\.width), [150])
        XCTAssertTrue(document.renderModel.attributedText.string.contains(
            "Screenshot\n\u{FFFC}\nEmbed: markprompt_interaction_prototype_v4.png\ndocuments the review surface."
        ))
        XCTAssertEqual(
            attribute(.toolTip, for: "Embed: markprompt_interaction_prototype_v4.png", in: document.renderModel.attributedText) as? String,
            "../../../docs/assets/markprompt_interaction_prototype_v4.png"
        )
        XCTAssertEqual(blockKind(containing: "Embed: markprompt_interaction_prototype_v4.png", in: document), .definitionList)
    }

    func testRendersObsidianFileEmbedsWithMediaTypeFallbacks() {
        let markdown = """
        Review packet ![[docs/assets/review-brief.pdf]] with call audio ![[captures/interview.m4a]] and prototype ![[demos/prototype.mov|prototype walkthrough]].
        """

        let document = MarkdownParser().parse(markdown)
        let attributedText = document.renderModel.attributedText
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("PDF: review-brief.pdf"))
        XCTAssertTrue(renderedText.contains("Audio: interview.m4a"))
        XCTAssertTrue(renderedText.contains("Video: prototype walkthrough"))
        XCTAssertFalse(renderedText.contains("Embed: docs/assets/review-brief.pdf"))
        XCTAssertFalse(renderedText.contains("Embed: captures/interview.m4a"))
        XCTAssertFalse(renderedText.contains("Embed: prototype walkthrough"))
        XCTAssertFalse(renderedText.contains("docs/assets/review-brief.pdf"))
        XCTAssertFalse(renderedText.contains("captures/interview.m4a"))
        XCTAssertFalse(renderedText.contains("![[docs/assets/review-brief.pdf]]"))
        XCTAssertEqual(
            attribute(.toolTip, for: "PDF: review-brief.pdf", in: attributedText) as? String,
            "docs/assets/review-brief.pdf"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Audio: interview.m4a", in: attributedText) as? String,
            "captures/interview.m4a"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Video: prototype walkthrough", in: attributedText) as? String,
            "demos/prototype.mov"
        )
        XCTAssertNotNil(attribute(.backgroundColor, for: "PDF: review-brief.pdf", in: attributedText))
        XCTAssertEqual(blockKind(containing: "PDF: review-brief.pdf", in: document), .paragraph)
    }

    func testRendersObsidianNoteEmbedsAsReadablePlaceholders() {
        let markdown = """
        Embedded context ![[Reader Vault/Weekly Review.md#Retro]] and aliased note ![[Research/Prompt Notes|prompt notes]] plus plain note ![[Research/Review Appendix.md#Risks]] plus encoded note ![[Research/Review%20Appendix.md#Risk%20Map]] should stay concise.
        """

        let document = MarkdownParser().parse(markdown)
        let attributedText = document.renderModel.attributedText
        let renderedText = document.renderModel.renderedPlainText

        XCTAssertTrue(renderedText.contains("Embedded context Note: Weekly Review#Retro and aliased note Note: prompt notes plus plain note Note: Review Appendix#Risks plus encoded note Note: Review Appendix#Risk Map should stay concise."))
        XCTAssertFalse(renderedText.contains("Embed: Reader Vault/Weekly Review.md#Retro"))
        XCTAssertFalse(renderedText.contains("Embed: prompt notes"))
        XCTAssertFalse(renderedText.contains("Note: Weekly Review.md#Retro"))
        XCTAssertFalse(renderedText.contains("Note: Review Appendix.md#Risks"))
        XCTAssertFalse(renderedText.contains("Review%20Appendix"))
        XCTAssertFalse(renderedText.contains("Risk%20Map"))
        XCTAssertFalse(renderedText.contains("[[Reader Vault/Weekly Review.md#Retro]]"))
        XCTAssertFalse(renderedText.contains("[[Research/Prompt Notes|prompt notes]]"))
        XCTAssertFalse(renderedText.contains("[[Research/Review Appendix.md#Risks]]"))
        XCTAssertFalse(renderedText.contains("[[Research/Review%20Appendix.md#Risk%20Map]]"))
        XCTAssertEqual(
            attribute(.toolTip, for: "Note: Weekly Review#Retro", in: attributedText) as? String,
            "Reader Vault/Weekly Review.md#Retro"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Note: prompt notes", in: attributedText) as? String,
            "Research/Prompt Notes"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Note: Review Appendix#Risks", in: attributedText) as? String,
            "Research/Review Appendix.md#Risks"
        )
        XCTAssertEqual(
            attribute(.toolTip, for: "Note: Review Appendix#Risk Map", in: attributedText) as? String,
            "Research/Review Appendix.md#Risk Map"
        )
        XCTAssertNotNil(attribute(.backgroundColor, for: "Note: Weekly Review#Retro", in: attributedText))
        XCTAssertEqual(blockKind(containing: "Note: Weekly Review#Retro", in: document), .paragraph)
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

    private func readerFixtureURL(named filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("samples/markdown/reader-fixtures")
            .appendingPathComponent(filename)
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

    private func hasDottedUnderline(for needle: String, in attributedText: NSAttributedString) -> Bool {
        guard let style = attribute(.underlineStyle, for: needle, in: attributedText) as? Int else {
            return false
        }
        return style & NSUnderlineStyle.patternDot.rawValue != 0
    }

    private func hasStrikethroughAttribute(for needle: String, in attributedText: NSAttributedString) -> Bool {
        guard let style = attribute(.strikethroughStyle, for: needle, in: attributedText) as? Int else {
            return false
        }
        return style & NSUnderlineStyle.single.rawValue != 0
    }

    private func taskMarkerSourceRange(for linePrefix: String, in attributedText: NSAttributedString) -> SourceTextRange? {
        let rendered = attributedText.string as NSString
        let match = rendered.range(of: linePrefix)
        guard match.location != NSNotFound else {
            return nil
        }
        return attributedText.attribute(NSAttributedString.Key("MarkPromptTaskMarkerSourceRange"), at: match.location, effectiveRange: nil) as? SourceTextRange
    }

    private func sourceRange(of needle: String, in source: String) -> SourceTextRange? {
        let nsSource = source as NSString
        let range = nsSource.range(of: needle)
        guard range.location != NSNotFound else {
            return nil
        }
        return SourceTextRange(lowerBound: range.location, upperBound: range.location + range.length)
    }
}
