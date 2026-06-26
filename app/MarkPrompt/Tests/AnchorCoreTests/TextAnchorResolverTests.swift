import MarkPromptKit
import XCTest

final class TextAnchorResolverTests: XCTestCase {
    func testResolverUsesRenderedRangeWhenHashMatches() throws {
        let document = MarkdownParser().parse("# 标题\n\n这是一段核心价值文本。")
        let selection = try makeSelection(text: "核心价值", in: document)
        let anchor = TextAnchorBuilder().makeAnchor(for: selection, in: document)
        let note = ReviewNote(id: "note_001", anchor: anchor, comment: "改清楚")

        let resolved = TextAnchorResolver().resolve(note: note, in: document)

        XCTAssertEqual(resolved.status, .confirmed)
        XCTAssertEqual(resolved.anchor.renderedRange, selection.renderedRange)
    }

    func testResolverFallsBackToHeadingTextAndContextWhenHashChanges() throws {
        let original = MarkdownParser().parse("# 标题\n\n前文 需要修改的文本 后文")
        let selection = try makeSelection(text: "需要修改的文本", in: original)
        let anchor = TextAnchorBuilder().makeAnchor(for: selection, in: original)
        let changed = MarkdownParser().parse("# 标题\n\n新增句子。\n\n前文 需要修改的文本 后文")

        let resolution = TextAnchorResolver().resolve(anchor: anchor, in: changed)

        XCTAssertEqual(resolution.status, .confirmed)
        XCTAssertNotNil(resolution.anchor.renderedRange)
        XCTAssertEqual(resolution.anchor.documentHash, changed.sourceHash)
    }

    func testResolverMarksAnchorLostWhenTextCannotBeRecovered() throws {
        let original = MarkdownParser().parse("# 标题\n\n原文本")
        let selection = try makeSelection(text: "原文本", in: original)
        let anchor = TextAnchorBuilder().makeAnchor(for: selection, in: original)
        let changed = MarkdownParser().parse("# 标题\n\n完全不同")

        let resolution = TextAnchorResolver().resolve(anchor: anchor, in: changed)

        XCTAssertEqual(resolution.status, .anchorLost)
        XCTAssertNil(resolution.anchor.renderedRange)
    }

    private func makeSelection(text: String, in document: MarkdownDocument) throws -> ReaderSelection {
        let rendered = document.renderModel.renderedPlainText as NSString
        let match = rendered.range(of: text)
        XCTAssertNotEqual(match.location, NSNotFound)
        guard match.location != NSNotFound else {
            throw NSError(domain: "TextAnchorResolverTests", code: 1)
        }

        let renderedRange = RenderedTextRange(location: match.location, length: match.length)
        return ReaderSelection(
            selectedText: text,
            renderedRange: renderedRange,
            sourceRange: document.renderModel.sourceMap.sourceRange(containing: renderedRange)
        )
    }
}
