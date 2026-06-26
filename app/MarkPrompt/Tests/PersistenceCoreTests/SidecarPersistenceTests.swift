import MarkPromptKit
import XCTest

final class SidecarPersistenceTests: XCTestCase {
    func testSidecarLocatorUsesSourceDirectoryAndFallbackDirectories() {
        let support = URL(fileURLWithPath: "/tmp/MarkPromptSupport", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: support)
        let source = URL(fileURLWithPath: "/tmp/source/sample_prd.md")

        XCTAssertEqual(locator.reviewSessionURL(for: source).path, "/tmp/source/sample_prd.review.json")
        XCTAssertEqual(locator.promptURL(for: source).path, "/tmp/source/sample_prd.prompt.md")
        XCTAssertTrue(locator.fallbackReviewSessionURL(for: source).path.contains("/tmp/MarkPromptSupport/Reviews/sample_prd-"))
        XCTAssertTrue(locator.fallbackPromptURL(for: source).path.contains("/tmp/MarkPromptSupport/Prompts/sample_prd-"))
    }

    func testReviewSessionStoreWritesAndReadsSidecar() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let session = ReviewSession(
            sourceFile: sourceURL.path,
            sourceHash: document.sourceHash,
            lastNoteSequence: 1,
            notes: [
                ReviewNote(
                    id: "note_001",
                    anchor: TextAnchor(
                        headingPath: ["标题"],
                        selectedText: "正文",
                        normalizedSelectedText: "正文",
                        sourceRange: SourceTextRange(lowerBound: 6, upperBound: 8),
                        renderedRange: RenderedTextRange(location: 3, length: 2),
                        contextBefore: "",
                        contextAfter: "",
                        documentHash: document.sourceHash
                    ),
                    comment: "修改"
                )
            ]
        )

        let result = try store.save(session, for: document)
        let loaded = store.loadSessionResult(for: document)

        XCTAssertFalse(result.usedFallback)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        XCTAssertEqual(loaded.session.notes.first?.id, "note_001")
        XCTAssertEqual(loaded.session.lastNoteSequence, 1)
    }

    func testPromptFileStoreWritesPromptFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let store = PromptFileStore(
            locator: SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        )

        let result = try store.save(prompt: "# Prompt", for: document)

        XCTAssertEqual(result.url.lastPathComponent, "sample.prompt.md")
        XCTAssertEqual(try String(contentsOf: result.url, encoding: .utf8), "# Prompt")
    }
}
