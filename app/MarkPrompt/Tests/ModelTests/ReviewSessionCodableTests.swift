import MarkPromptKit
import XCTest

final class ReviewSessionCodableTests: XCTestCase {
    func testReviewSessionRoundTripsThroughJSON() throws {
        let session = ReviewSession(
            version: "1",
            sourceFile: "/tmp/sample.md",
            sourceHash: "abc123",
            notes: [
                ReviewNote(
                    id: "note_001",
                    status: .confirmed,
                    includeInPrompt: true,
                    anchor: TextAnchor(
                        headingPath: ["示例 PRD", "核心价值"],
                        selectedText: "原文",
                        normalizedSelectedText: "原文",
                        sourceRange: SourceTextRange(lowerBound: 10, upperBound: 20),
                        renderedRange: RenderedTextRange(location: 3, length: 2),
                        contextBefore: "前",
                        contextAfter: "后",
                        documentHash: "abc123"
                    ),
                    comment: "请改清楚",
                    quickPrompts: [
                        QuickPromptUsage(id: "improve-expression", label: "优化表达", insertedText: "请优化表达")
                    ],
                    createdAt: Date(timeIntervalSince1970: 100),
                    updatedAt: Date(timeIntervalSince1970: 200)
                )
            ],
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(session)
        let decoded = try decoder.decode(ReviewSession.self, from: data)

        XCTAssertEqual(decoded, session)
        XCTAssertEqual(decoded.lastNoteSequence, 1)
        XCTAssertEqual(decoded.notes.first?.anchor.headingPath, ["示例 PRD", "核心价值"])
        XCTAssertEqual(decoded.notes.first?.quickPrompts.first?.label, "优化表达")
    }

    func testReviewSessionDecodesLegacyJSONAndPreservesHighestNoteSequence() throws {
        let json = """
        {
          "version": "1",
          "sourceFile": "/tmp/sample.md",
          "sourceHash": "abc123",
          "notes": [
            {
              "id": "note_007",
              "status": "confirmed",
              "includeInPrompt": true,
              "anchor": {
                "headingPath": [],
                "selectedText": "文本",
                "normalizedSelectedText": "文本",
                "sourceRange": null,
                "renderedRange": null,
                "contextBefore": "",
                "contextAfter": "",
                "documentHash": "abc123"
              },
              "comment": "修改",
              "quickPrompts": [],
              "inferredMetadata": null,
              "createdAt": "1970-01-01T00:00:01Z",
              "updatedAt": "1970-01-01T00:00:02Z"
            }
          ],
          "createdAt": "1970-01-01T00:00:01Z",
          "updatedAt": "1970-01-01T00:00:02Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(ReviewSession.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.lastNoteSequence, 7)
    }

    func testNoteIDGeneratorUsesMonotonicPaddedIDs() {
        let notes = [
            makeNote(id: "note_001"),
            makeNote(id: "note_009")
        ]

        XCTAssertEqual(NoteIDGenerator.highestSequence(in: notes), 9)
        XCTAssertEqual(NoteIDGenerator.nextSequence(after: 9), 10)
        XCTAssertEqual(NoteIDGenerator.id(for: 10), "note_010")
    }

    func testQuickPromptCatalogContainsRequiredPromptsAndAppliesSingleSelectionRules() {
        let labels = QuickPromptCatalog.defaults.map(\.label)
        let polish = QuickPromptCatalog.defaults[0]
        let rewrite = QuickPromptCatalog.defaults[1]
        let selectedPolish = QuickPromptCatalog.usage(for: polish)

        XCTAssertEqual(labels, ["润色", "重写", "扩写", "缩短", "修复语法", "译为英文", "译为中文"])
        XCTAssertEqual(
            QuickPromptCatalog.commentAfterSelecting(
                currentComment: "",
                selectedQuickPrompt: nil,
                definition: polish
            ),
            polish.insertedText
        )
        XCTAssertEqual(
            QuickPromptCatalog.commentAfterSelecting(
                currentComment: polish.insertedText,
                selectedQuickPrompt: selectedPolish,
                definition: rewrite
            ),
            rewrite.insertedText
        )
        XCTAssertEqual(
            QuickPromptCatalog.commentAfterSelecting(
                currentComment: "用户意见",
                selectedQuickPrompt: nil,
                definition: rewrite
            ),
            "用户意见\n\(rewrite.insertedText)"
        )
        XCTAssertEqual(
            QuickPromptCatalog.commentAfterSelecting(
                currentComment: "\(polish.insertedText)\n请保留现在的语气。",
                selectedQuickPrompt: selectedPolish,
                definition: rewrite
            ),
            "\(polish.insertedText)\n请保留现在的语气。\n\(rewrite.insertedText)"
        )
    }

    private func makeNote(id: String) -> ReviewNote {
        ReviewNote(
            id: id,
            anchor: TextAnchor(
                headingPath: [],
                selectedText: "文本",
                normalizedSelectedText: "文本",
                sourceRange: nil,
                renderedRange: nil,
                contextBefore: "",
                contextAfter: "",
                documentHash: "abc123"
            ),
            comment: "修改"
        )
    }
}
