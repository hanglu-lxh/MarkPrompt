import MarkPromptKit
import XCTest

final class PromptBuilderTests: XCTestCase {
    func testCodexFileModificationPromptIncludesOnlyIncludedConfirmedNotes() {
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
        XCTAssertTrue(result.prompt.contains("# Codex 文件修改模式"))
        XCTAssertTrue(result.prompt.contains("目标文件：\n/tmp/sample_prd.md"))
        XCTAssertTrue(result.prompt.contains("[NOTE note_001]"))
        XCTAssertTrue(result.prompt.contains("批注意见：请优化表达。"))
        XCTAssertTrue(result.prompt.contains("- source range: 18-32"))
        XCTAssertTrue(result.prompt.contains("- 直接修改目标文件"))
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
        XCTAssertTrue(result.prompt.contains("锚点状态：anchor_lost"))
        XCTAssertTrue(result.prompt.contains("- document hash: hash"))
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
        selectedText: String
    ) -> ReviewNote {
        ReviewNote(
            id: id,
            status: status,
            includeInPrompt: includeInPrompt,
            anchor: TextAnchor(
                headingPath: ["示例 PRD"],
                selectedText: selectedText,
                normalizedSelectedText: TextNormalizer.normalized(selectedText),
                sourceRange: SourceTextRange(lowerBound: 18, upperBound: 32),
                renderedRange: RenderedTextRange(location: 8, length: selectedText.count),
                contextBefore: "前文",
                contextAfter: "后文",
                documentHash: "hash"
            ),
            comment: comment
        )
    }
}
