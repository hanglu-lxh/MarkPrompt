import MarkPromptKit
import XCTest

final class PromptBuilderTests: XCTestCase {
    func testMarkdownModificationPromptIncludesOnlyIncludedConfirmedNotes() {
        let parser = MarkdownParser()
        let fileURL = URL(fileURLWithPath: "/tmp/sample_prd.md")
        let document = parser.parse("# 示例 PRD\n\nMarkPrompt 的核心价值。", fileURL: fileURL)
        let included = makeNote(
            id: "note_001",
            includeInPrompt: true,
            status: .confirmed,
            comment: "请优化表达。",
            selectedText: "MarkPrompt 的核心价值。"
        )
        let excluded = makeNote(
            id: "note_002",
            includeInPrompt: false,
            status: .confirmed,
            comment: "不应出现。",
            selectedText: "隐藏文本"
        )
        let session = ReviewSession(
            sourceFile: fileURL.path,
            sourceHash: document.sourceHash,
            notes: [included, excluded]
        )

        let result = PromptBuilder().build(document: document, session: session)

        XCTAssertEqual(result.includedNoteCount, 1)
        XCTAssertTrue(result.prompt.contains("# Markdown 修改任务"))
        XCTAssertTrue(result.prompt.contains("目标文件：\n/tmp/sample_prd.md"))
        XCTAssertTrue(result.prompt.contains("请根据以下批注修改内容。"))
        XCTAssertTrue(result.prompt.contains("## 批注列表"))
        XCTAssertTrue(result.prompt.contains("[NOTE note_001]"))
        XCTAssertTrue(result.prompt.contains("位置：第 3 行"))
        XCTAssertTrue(result.prompt.contains("批注内容：MarkPrompt 的核心价值。"))
        XCTAssertTrue(result.prompt.contains("批注意见：请优化表达。"))
        XCTAssertFalse(result.prompt.contains("全局修改原则"))
        XCTAssertFalse(result.prompt.contains("source range"))
        XCTAssertFalse(result.prompt.contains("context before"))
        XCTAssertFalse(result.prompt.contains("document hash"))
        XCTAssertFalse(result.prompt.contains("输出要求"))
        XCTAssertFalse(result.prompt.contains("note_002"))
        XCTAssertFalse(result.prompt.contains("不应出现"))
    }

    func testPromptBuilderReturnsEmptyStateWithoutIncludedNotes() {
        let document = MarkdownParser().parse("# Empty")
        let session = ReviewSession(sourceFile: nil, sourceHash: document.sourceHash)

        let result = PromptBuilder().build(document: document, session: session)

        XCTAssertEqual(result.prompt, "")
        XCTAssertEqual(result.includedNoteCount, 0)
        XCTAssertEqual(result.warnings.first, "至少需要一条纳入 Prompt 的批注。")
    }

    func testPromptIncludesAnchorLostWarning() {
        let document = MarkdownParser().parse("# 示例 PRD\n\n旧文本。", fileURL: URL(fileURLWithPath: "/tmp/lost.md"))
        let note = makeNote(
            id: "note_003",
            includeInPrompt: true,
            status: .anchorLost,
            comment: "请确认定位后修改。",
            selectedText: "找不到的文本"
        )
        let session = ReviewSession(sourceFile: "/tmp/lost.md", sourceHash: document.sourceHash, notes: [note])

        let result = PromptBuilder().build(document: document, session: session)

        XCTAssertTrue(result.prompt.contains("[NOTE note_003]"))
        XCTAssertTrue(result.prompt.contains("位置：未精确定位，请搜索批注内容"))
        XCTAssertTrue(result.prompt.contains("批注内容：找不到的文本"))
        XCTAssertTrue(result.prompt.contains("批注意见：请确认定位后修改。"))
        XCTAssertFalse(result.prompt.contains("锚点状态"))
        XCTAssertFalse(result.prompt.contains("document hash"))
    }

    func testPromptFallsBackToCharacterRangeWhenSourceRangeCannotResolveToLines() {
        let document = MarkdownParser().parse("# 示例 PRD\n\n正文。")
        let note = makeNote(
            id: "note_005",
            includeInPrompt: true,
            status: .confirmed,
            comment: "请修改。",
            selectedText: "正文",
            sourceRange: SourceTextRange(lowerBound: 900, upperBound: 920)
        )
        let session = ReviewSession(sourceFile: nil, sourceHash: document.sourceHash, notes: [note])

        let result = PromptBuilder().build(document: document, session: session)

        XCTAssertTrue(result.prompt.contains("位置：字符 900-920"))
    }

    func testPromptExcludesExcludedStatusEvenWhenIncludedFlagIsTrue() {
        let document = MarkdownParser().parse("# 示例 PRD\n\n正文。")
        let note = makeNote(
            id: "note_004",
            includeInPrompt: true,
            status: .excluded,
            comment: "不应出现。",
            selectedText: "正文"
        )
        let session = ReviewSession(sourceFile: nil, sourceHash: document.sourceHash, notes: [note])

        let result = PromptBuilder().build(document: document, session: session)

        XCTAssertEqual(result.includedNoteCount, 0)
        XCTAssertFalse(result.prompt.contains("note_004"))
    }

    private func makeNote(
        id: String,
        includeInPrompt: Bool,
        status: ReviewNoteStatus,
        comment: String,
        selectedText: String,
        sourceRange: SourceTextRange? = SourceTextRange(lowerBound: 10, upperBound: 27)
    ) -> ReviewNote {
        ReviewNote(
            id: id,
            status: status,
            includeInPrompt: includeInPrompt,
            anchor: TextAnchor(
                headingPath: ["示例 PRD"],
                selectedText: selectedText,
                normalizedSelectedText: TextNormalizer.normalized(selectedText),
                sourceRange: sourceRange,
                renderedRange: RenderedTextRange(location: 8, length: selectedText.count),
                contextBefore: "前文",
                contextAfter: "后文",
                documentHash: "hash"
            ),
            comment: comment
        )
    }
}
