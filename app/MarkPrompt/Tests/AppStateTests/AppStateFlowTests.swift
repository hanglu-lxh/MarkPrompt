import CoreGraphics
import MarkPromptKit
import XCTest

@MainActor
final class AppStateFlowTests: XCTestCase {
    func testOpenAnnotateSaveRestoreEditExcludeDeleteAndSavePrompt() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "请把这句话改得更清晰。", quickPrompts: [])

        XCTAssertEqual(state.reviewSession?.notes.count, 1)
        XCTAssertEqual(state.reviewSession?.notes.first?.id, "note_001")
        XCTAssertEqual(state.annotationHighlights.count, 1)
        XCTAssertTrue(state.promptPreview.prompt.contains("[NOTE note_001]"))

        state.saveReviewSessionNow()
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecarURL.path))

        let restored = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        restored.openDocument(at: sourceURL)
        XCTAssertEqual(restored.reviewSession?.notes.count, 1)
        XCTAssertEqual(restored.annotationHighlights.count, 1)

        restored.updateNoteComment(id: "note_001", comment: "请压缩并保留重点。")
        XCTAssertTrue(restored.promptPreview.prompt.contains("请压缩并保留重点。"))

        restored.setNoteIncluded(id: "note_001", includeInPrompt: false)
        XCTAssertTrue(restored.promptPreview.prompt.isEmpty)

        restored.setNoteIncluded(id: "note_001", includeInPrompt: true)
        restored.savePromptToDisk()
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.promptURL(for: sourceURL).path))

        restored.deleteNote(id: "note_001")
        XCTAssertTrue(restored.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(restored.promptPreview.prompt.isEmpty)
    }

    func testSelectionClearsPendingScrollTargetsWithoutChangingDocument() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "核心价值" })
        state.selectHeading(heading)

        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertNil(state.scrollTargetRange)

        let selection = try makeSelection(text: "核心价值", in: document)
        state.updateSelection(selection)

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(state.currentDocument?.sourceHash, document.sourceHash)
    }

    func testVisibleHeadingUpdatesOutlineStateWithoutChangingSelectionOrScrollTargets() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let title = try XCTUnwrap(document.outline.flattened().first { $0.title == "示例 PRD" })
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "核心价值" })
        let selection = try makeSelection(text: "核心价值", in: document)

        XCTAssertEqual(state.currentReadingHeadingID, title.id)

        state.selectHeading(heading)
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertEqual(state.currentReadingHeadingID, heading.id)

        state.updateSelection(selection)
        state.updateVisibleHeading(title.id)

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(state.currentReadingHeadingID, title.id)
        XCTAssertEqual(state.currentDocument?.sourceHash, document.sourceHash)
    }

    func testRealSamplePRDAnnotationSaveRestoreAndPromptPreview() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try FileManager.default.copyItem(at: samplePRDURL(), to: sourceURL)
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        XCTAssertEqual(document.displayName, "sample_prd.md")
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("Reader"))
        XCTAssertTrue(document.renderModel.renderedPlainText.contains("struct ReviewNote"))

        let selection = try makeSelection(text: "本地 Mac 工具", in: document)
        state.updateSelection(selection)
        state.createAnnotation(comment: "请强调本地优先和审稿定位。", quickPrompts: [])
        state.saveReviewSessionNow()

        XCTAssertEqual(state.annotationHighlights.count, 1)
        XCTAssertTrue(state.promptPreview.prompt.contains("请强调本地优先和审稿定位。"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: sourceURL).path))

        let restored = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        restored.openDocument(at: sourceURL)

        XCTAssertEqual(restored.reviewSession?.notes.count, 1)
        XCTAssertEqual(restored.annotationHighlights.count, 1)
        XCTAssertTrue(restored.promptPreview.prompt.contains("[NOTE note_001]"))
    }

    private func makeSelection(text: String, in document: MarkdownDocument) throws -> ReaderSelection {
        let rendered = document.renderModel.renderedPlainText as NSString
        let match = rendered.range(of: text)
        XCTAssertNotEqual(match.location, NSNotFound)
        guard match.location != NSNotFound else {
            throw NSError(domain: "AppStateFlowTests", code: 1)
        }

        let renderedRange = RenderedTextRange(location: match.location, length: match.length)
        return ReaderSelection(
            selectedText: text,
            renderedRange: renderedRange,
            sourceRange: document.renderModel.sourceMap.sourceRange(containing: renderedRange),
            selectionRect: CGRect(x: 120, y: 120, width: 100, height: 32)
        )
    }

    private func sampleSource() -> String {
        """
        # 示例 PRD

        ## 核心价值

        MarkPrompt 的核心价值是让批注更精准，让 AI 修改更可控。
        """
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
}
