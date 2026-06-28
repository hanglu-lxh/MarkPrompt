import CoreGraphics
import Foundation
import MarkPromptKit
import UniformTypeIdentifiers
import XCTest

@MainActor
final class AppStateFlowTests: XCTestCase {
    func testTogglingTaskMarkerUpdatesMarkdownFileAndReaderModel() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        - [x] Confirm local-first behavior
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        let originalDocument = try XCTUnwrap(state.currentDocument)
        let openMarkerRange = try XCTUnwrap(sourceRange(of: "[ ]", in: originalDocument.rawMarkdown))

        XCTAssertTrue(state.toggleTaskMarker(sourceRange: openMarkerRange))

        let toggledDocument = try XCTUnwrap(state.currentDocument)
        XCTAssertTrue(toggledDocument.rawMarkdown.contains("- [x] Review anchor recovery"))
        XCTAssertTrue(toggledDocument.renderModel.renderedPlainText.contains("☑ Review anchor recovery"))
        XCTAssertTrue(toggledDocument.renderModel.renderedPlainText.contains("☑ Confirm local-first behavior"))
        XCTAssertNotEqual(toggledDocument.sourceHash, originalDocument.sourceHash)
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), toggledDocument.rawMarkdown)
        XCTAssertEqual(state.saveState, .saved)

        let completedMarkerRange = try XCTUnwrap(sourceRange(of: "[x] Review", in: toggledDocument.rawMarkdown))
        XCTAssertTrue(state.toggleTaskMarker(sourceRange: SourceTextRange(
            lowerBound: completedMarkerRange.lowerBound,
            upperBound: completedMarkerRange.lowerBound + 3
        )))

        let reopenedDocument = try XCTUnwrap(state.currentDocument)
        XCTAssertTrue(reopenedDocument.rawMarkdown.contains("- [ ] Review anchor recovery"))
        XCTAssertTrue(reopenedDocument.renderModel.renderedPlainText.contains("☐ Review anchor recovery"))
    }

    func testUndoingTaskMarkerToggleRestoresMarkdownFileAndReaderModel() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        XCTAssertFalse(state.canUndoTaskMarkerToggle)
        let originalDocumentID = try XCTUnwrap(state.currentDocument?.id)
        let openMarkerRange = try XCTUnwrap(sourceRange(of: "[ ]", in: source))

        XCTAssertTrue(state.toggleTaskMarker(sourceRange: openMarkerRange))
        XCTAssertTrue(state.canUndoTaskMarkerToggle)
        XCTAssertTrue(try String(contentsOf: sourceURL, encoding: .utf8).contains("- [x] Review anchor recovery"))

        XCTAssertTrue(state.undoLastTaskMarkerToggle())

        let restoredDocument = try XCTUnwrap(state.currentDocument)
        XCTAssertEqual(restoredDocument.id, originalDocumentID)
        XCTAssertEqual(restoredDocument.rawMarkdown, source)
        XCTAssertTrue(restoredDocument.renderModel.renderedPlainText.contains("☐ Review anchor recovery"))
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), source)
        XCTAssertEqual(state.saveState, .saved)
        XCTAssertFalse(state.canUndoTaskMarkerToggle)
        XCTAssertFalse(state.undoLastTaskMarkerToggle())
    }

    func testUndoingTaskMarkerTogglesWalksBackMultipleMarkdownWrites() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        - [ ] Confirm local-first behavior
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))

        let firstMarkerRange = try XCTUnwrap(sourceRange(of: "[ ] Review", in: source))
        XCTAssertTrue(state.toggleTaskMarker(sourceRange: SourceTextRange(
            lowerBound: firstMarkerRange.lowerBound,
            upperBound: firstMarkerRange.lowerBound + 3
        )))

        let firstToggledMarkdown = try XCTUnwrap(state.currentDocument?.rawMarkdown)
        XCTAssertTrue(firstToggledMarkdown.contains("- [x] Review anchor recovery"))
        XCTAssertTrue(firstToggledMarkdown.contains("- [ ] Confirm local-first behavior"))

        let secondMarkerRange = try XCTUnwrap(sourceRange(of: "[ ] Confirm", in: firstToggledMarkdown))
        XCTAssertTrue(state.toggleTaskMarker(sourceRange: SourceTextRange(
            lowerBound: secondMarkerRange.lowerBound,
            upperBound: secondMarkerRange.lowerBound + 3
        )))

        XCTAssertTrue(try String(contentsOf: sourceURL, encoding: .utf8).contains("- [x] Confirm local-first behavior"))

        XCTAssertTrue(state.undoLastTaskMarkerToggle())
        XCTAssertEqual(state.currentDocument?.rawMarkdown, firstToggledMarkdown)
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), firstToggledMarkdown)
        XCTAssertTrue(state.canUndoTaskMarkerToggle)

        XCTAssertTrue(state.undoLastTaskMarkerToggle())
        XCTAssertEqual(state.currentDocument?.rawMarkdown, source)
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), source)
        XCTAssertFalse(state.canUndoTaskMarkerToggle)
    }

    func testUndoingTaskMarkerToggleReportsExternalModificationSummary() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        """
        let externallyModifiedAfterToggle = """
        # Tasks

        - [x] Review anchor recovery
        - [ ] Preserve external reviewer note
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        let markerRange = try XCTUnwrap(sourceRange(of: "[ ]", in: source))
        XCTAssertTrue(state.toggleTaskMarker(sourceRange: markerRange))
        try externallyModifiedAfterToggle.write(to: sourceURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(state.undoLastTaskMarkerToggle())
        XCTAssertTrue(state.canUndoTaskMarkerToggle)
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), externallyModifiedAfterToggle)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            ),
            ReaderStatusBannerPresentation(
                title: "保存未完成",
                message: "任务状态保存失败：文件已在外部修改（第 4 行起，外部版本新增 1 行），请先重新载入后再撤销任务状态。当前文档仍保持打开。",
                systemImage: "exclamationmark.triangle",
                actionTitle: "重新载入文件",
                copyTitle: "复制详情",
                copyHelp: "复制完整失败详情；不会隐藏保存失败",
                copyValue: "任务状态保存失败：文件已在外部修改（第 4 行起，外部版本新增 1 行），请先重新载入后再撤销任务状态。当前文档仍保持打开。"
            )
        )
    }

    func testSettingTaskMarkerStatusUpdatesMarkdownFileAndReaderModel() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        let markerRange = try XCTUnwrap(sourceRange(of: "[ ]", in: source))

        XCTAssertTrue(state.setTaskMarker(sourceRange: markerRange, markerCharacter: "/"))

        let updatedDocument = try XCTUnwrap(state.currentDocument)
        XCTAssertTrue(updatedDocument.rawMarkdown.contains("- [/] Review anchor recovery"))
        XCTAssertTrue(updatedDocument.renderModel.renderedPlainText.contains("◩ Review anchor recovery"))
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), updatedDocument.rawMarkdown)
        XCTAssertTrue(state.canUndoTaskMarkerToggle)

        XCTAssertTrue(state.undoLastTaskMarkerToggle())
        XCTAssertEqual(state.currentDocument?.rawMarkdown, source)
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), source)
    }

    func testTogglingInvalidTaskMarkerRangeLeavesDocumentUnchanged() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        XCTAssertFalse(state.toggleTaskMarker(sourceRange: SourceTextRange(lowerBound: 0, upperBound: 3)))
        XCTAssertEqual(state.currentDocument?.rawMarkdown, source)
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), source)
    }

    func testTogglingTaskMarkerPreservesVisibleHeading() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery

        ## Later

        Preserve the current outline position.
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        let document = try XCTUnwrap(state.currentDocument)
        let visibleHeadingID = try XCTUnwrap(document.outline.flattened().first { $0.title == "Later" }?.id)
        state.updateVisibleHeading(visibleHeadingID, from: document.id)

        let openMarkerRange = try XCTUnwrap(sourceRange(of: "[ ]", in: document.rawMarkdown))
        XCTAssertTrue(state.toggleTaskMarker(sourceRange: openMarkerRange))

        let updatedDocument = try XCTUnwrap(state.currentDocument)
        let updatedVisibleHeadingID = try XCTUnwrap(updatedDocument.outline.flattened().first { $0.title == "Later" }?.id)
        XCTAssertEqual(state.currentReadingHeadingID, updatedVisibleHeadingID)
    }

    func testTogglingTaskMarkerDoesNotOverwriteExternallyModifiedMarkdown() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        """
        let externalSource = """
        # Tasks

        - [ ] Review anchor recovery
        - [ ] Preserve external reviewer note
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        let document = try XCTUnwrap(state.currentDocument)
        let markerRange = try XCTUnwrap(sourceRange(of: "[ ]", in: document.rawMarkdown))
        try externalSource.write(to: sourceURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(state.toggleTaskMarker(sourceRange: markerRange))
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), externalSource)
        XCTAssertEqual(state.currentDocument?.rawMarkdown, source)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            ),
            ReaderStatusBannerPresentation(
                title: "保存未完成",
                message: "任务状态保存失败：文件已在外部修改（第 4 行起，外部版本新增 1 行），请先重新载入后再切换任务状态。当前文档仍保持打开。",
                systemImage: "exclamationmark.triangle",
                actionTitle: "重新载入文件",
                copyTitle: "复制详情",
                copyHelp: "复制完整失败详情；不会隐藏保存失败",
                copyValue: "任务状态保存失败：文件已在外部修改（第 4 行起，外部版本新增 1 行），请先重新载入后再切换任务状态。当前文档仍保持打开。"
            )
        )

        XCTAssertTrue(state.reloadCurrentDocumentFromDisk())
        XCTAssertEqual(state.currentDocument?.rawMarkdown, externalSource)
        XCTAssertTrue(state.currentDocument?.renderModel.renderedPlainText.contains("☐ Preserve external reviewer note") == true)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertFalse(state.canUndoTaskMarkerToggle)
    }

    func testTogglingTaskMarkerReportsExternalModificationChangedLineSummary() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = """
        # Tasks

        - [ ] Review anchor recovery
        """
        let externalSource = """
        # Tasks

        - [ ] Review anchor recovery with reviewer context
        """
        let sourceURL = temp.appendingPathComponent("tasks.md")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        XCTAssertTrue(state.openDocument(at: sourceURL))
        let document = try XCTUnwrap(state.currentDocument)
        let markerRange = try XCTUnwrap(sourceRange(of: "[ ]", in: document.rawMarkdown))
        try externalSource.write(to: sourceURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(state.toggleTaskMarker(sourceRange: markerRange))
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), externalSource)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            ),
            ReaderStatusBannerPresentation(
                title: "保存未完成",
                message: "任务状态保存失败：文件已在外部修改（第 3 行起，外部版本修改 1 行），请先重新载入后再切换任务状态。当前文档仍保持打开。",
                systemImage: "exclamationmark.triangle",
                actionTitle: "重新载入文件",
                copyTitle: "复制详情",
                copyHelp: "复制完整失败详情；不会隐藏保存失败",
                copyValue: "任务状态保存失败：文件已在外部修改（第 3 行起，外部版本修改 1 行），请先重新载入后再切换任务状态。当前文档仍保持打开。"
            )
        )
    }

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

    func testSelectingTextInsideExistingAnnotationSelectsMatchingRightPanelCard() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let firstSelection = try makeSelection(text: "核心价值", in: document)
        let secondSelection = try makeSelection(text: "批注更精准", in: document)
        let unannotatedSelection = try makeSelection(text: "AI 修改更可控", in: document)

        state.updateSelection(firstSelection)
        state.createAnnotation(comment: "第一条批注。", quickPrompts: [])
        state.updateSelection(secondSelection)
        state.createAnnotation(comment: "第二条批注。", quickPrompts: [])
        XCTAssertEqual(state.selectedNoteID, "note_002")

        state.updateSelection(firstSelection)

        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.panelMode, .annotations)
        XCTAssertFalse(state.canCreateAnnotation)

        state.beginAnnotationFromCurrentSelection()

        XCTAssertFalse(state.isAnnotationPopoverPresented)
        XCTAssertEqual(state.reviewSession?.notes.count, 2)
        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.saveState, .failed("该选区已有批注，请在右侧卡片编辑原批注。"))

        state.createAnnotation(comment: "不要重复创建。", quickPrompts: [])

        XCTAssertEqual(state.reviewSession?.notes.count, 2)
        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.saveState, .failed("该选区已有批注，请在右侧卡片编辑原批注。"))

        state.updateSelection(unannotatedSelection)

        XCTAssertNil(state.selectedNoteID)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingExistingNoteCardClearsDuplicateSelectionWarning() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "这条批注已经存在。", quickPrompts: [])
        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertEqual(state.saveState, .failed("该选区已有批注，请在右侧卡片编辑原批注。"))

        state.selectNote(id: "note_001")

        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.scrollTargetRange, selection.renderedRange)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testDeletingSelectedNoteClearsStaleScrollTargetAndPrompt() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "删除时不要残留定位目标。", quickPrompts: [])
        state.selectNote(id: "note_001")
        XCTAssertEqual(state.scrollTargetRange, selection.renderedRange)

        state.deleteNote(id: "note_001")

        XCTAssertNil(state.selectedNoteID)
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertTrue(state.annotationHighlights.isEmpty)
    }

    func testDeletingMissingNoteDoesNotTriggerSpuriousSaveState() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        XCTAssertEqual(state.saveState, .loaded)

        state.deleteNote(id: "note_404")

        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertTrue(state.annotationHighlights.isEmpty)
    }

    func testSettingNoteIncludedToCurrentValueDoesNotTriggerSpuriousSaveState() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let firstState = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))

        firstState.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(firstState.currentDocument))
        firstState.updateSelection(selection)
        firstState.createAnnotation(comment: "这条批注默认纳入 Prompt。", quickPrompts: [])
        firstState.saveReviewSessionNow()

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: sourceURL)
        XCTAssertEqual(state.saveState, .loaded)
        let sessionBeforeNoOp = state.reviewSession
        let promptBeforeNoOp = state.promptPreview

        state.setNoteIncluded(id: "note_001", includeInPrompt: true)

        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertEqual(state.reviewSession, sessionBeforeNoOp)
        XCTAssertEqual(state.promptPreview, promptBeforeNoOp)
    }

    func testUpdatingNoteCommentToCurrentValueDoesNotTriggerSpuriousSaveState() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let firstState = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))

        firstState.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(firstState.currentDocument))
        firstState.updateSelection(selection)
        firstState.createAnnotation(comment: "这条批注保持不变。", quickPrompts: [])
        firstState.saveReviewSessionNow()

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: sourceURL)
        XCTAssertEqual(state.saveState, .loaded)
        let sessionBeforeNoOp = state.reviewSession
        let promptBeforeNoOp = state.promptPreview

        state.updateNoteComment(id: "note_001", comment: "  这条批注保持不变。  ")

        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertEqual(state.reviewSession, sessionBeforeNoOp)
        XCTAssertEqual(state.promptPreview, promptBeforeNoOp)
    }

    func testDeletingNoteForCurrentSelectionClearsReaderSelectionAndFloatingAnnotationEntry() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "删除后不要保留旧选区。", quickPrompts: [])
        state.updateSelection(selection)
        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertFalse(state.canCreateAnnotation)
        XCTAssertFalse(state.isAnnotationPopoverPresented)

        state.deleteNote(id: "note_001")

        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.canCreateAnnotation)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
    }

    func testCreatingAnnotationClearsTransientReaderSelectionAndFloatingEntry() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        state.createAnnotation(comment: "保存后继续阅读，不要留下浮动入口。", quickPrompts: [])

        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.canCreateAnnotation)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.annotationHighlights.count, 1)
        XCTAssertTrue(state.promptPreview.prompt.contains("保存后继续阅读，不要留下浮动入口。"))
    }

    func testChangingSelectionWhileAnnotationPopoverIsOpenDismissesStalePopover() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let originalSelection = try makeSelection(text: "核心价值", in: document)
        let newSelection = try makeSelection(text: "AI 修改更可控", in: document)

        state.updateSelection(originalSelection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        state.updateSelection(newSelection)

        XCTAssertEqual(state.readerSelection, newSelection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
    }

    func testClearingSelectionWhileAnnotationPopoverIsOpenKeepsDraftPopover() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "核心价值", in: document)

        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        state.updateSelection(nil)

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertTrue(state.isAnnotationPopoverPresented)
    }

    func testSelectingNoteClearsTransientReaderSelectionAndFloatingAnnotationEntry() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let annotatedSelection = try makeSelection(text: "核心价值", in: document)
        state.updateSelection(annotatedSelection)
        state.createAnnotation(comment: "点击卡片时回到这条批注。", quickPrompts: [])

        let pendingSelection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(pendingSelection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        state.selectNote(id: "note_001")

        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.panelMode, .annotations)
        XCTAssertEqual(state.scrollTargetRange, annotatedSelection.renderedRange)
        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.canCreateAnnotation)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
    }

    func testSelectingAnchorLostNoteClearsStaleScrollTarget() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let confirmedSelection = try makeSelection(text: "核心价值", in: document)
        state.updateSelection(confirmedSelection)
        state.createAnnotation(comment: "这条批注可以定位。", quickPrompts: [])

        var session = try XCTUnwrap(state.reviewSession)
        var lostAnchor = try XCTUnwrap(session.notes.first?.anchor)
        lostAnchor.selectedText = "这段原文已经移动"
        lostAnchor.normalizedSelectedText = "这段原文已经移动"
        lostAnchor.renderedRange = nil
        session.notes.append(ReviewNote(
            id: "note_002",
            status: .anchorLost,
            anchor: lostAnchor,
            comment: "这条批注需要重新确认。"
        ))
        state.reviewSession = session

        state.selectNote(id: "note_001")
        XCTAssertEqual(state.scrollTargetRange, confirmedSelection.renderedRange)

        state.selectNote(id: "note_002")

        XCTAssertEqual(state.selectedNoteID, "note_002")
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(state.saveState, .failed("该批注的原文位置需要重新确认。"))
    }

    func testSelectingConfirmedNoteClearsAnchorLostSelectionWarning() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let confirmedSelection = try makeSelection(text: "核心价值", in: document)
        state.updateSelection(confirmedSelection)
        state.createAnnotation(comment: "这条批注可以定位。", quickPrompts: [])

        var session = try XCTUnwrap(state.reviewSession)
        var lostAnchor = try XCTUnwrap(session.notes.first?.anchor)
        lostAnchor.selectedText = "这段原文已经移动"
        lostAnchor.normalizedSelectedText = "这段原文已经移动"
        lostAnchor.renderedRange = nil
        session.notes.append(ReviewNote(
            id: "note_002",
            status: .anchorLost,
            anchor: lostAnchor,
            comment: "这条批注需要重新确认。"
        ))
        state.reviewSession = session

        state.selectNote(id: "note_002")
        XCTAssertEqual(state.saveState, .failed("该批注的原文位置需要重新确认。"))

        state.selectNote(id: "note_001")

        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.scrollTargetRange, confirmedSelection.renderedRange)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingNewTextClearsAnchorLostSelectionWarningBeforeAddingAnnotation() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let confirmedSelection = try makeSelection(text: "核心价值", in: document)
        let newSelection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(confirmedSelection)
        state.createAnnotation(comment: "这条批注可以定位。", quickPrompts: [])

        var session = try XCTUnwrap(state.reviewSession)
        var lostAnchor = try XCTUnwrap(session.notes.first?.anchor)
        lostAnchor.selectedText = "这段原文已经移动"
        lostAnchor.normalizedSelectedText = "这段原文已经移动"
        lostAnchor.renderedRange = nil
        session.notes.append(ReviewNote(
            id: "note_002",
            status: .anchorLost,
            anchor: lostAnchor,
            comment: "这条批注需要重新确认。"
        ))
        state.reviewSession = session

        state.selectNote(id: "note_002")
        XCTAssertEqual(state.saveState, .failed("该批注的原文位置需要重新确认。"))

        state.updateSelection(newSelection)
        state.beginAnnotationFromCurrentSelection()

        XCTAssertNil(state.selectedNoteID)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertTrue(state.isAnnotationPopoverPresented)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testUpdatingNoteCommentRejectsEmptyEditAndKeepsPreviousPrompt() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "保留这条有效批注。", quickPrompts: [])

        state.updateNoteComment(id: "note_001", comment: "   \n")

        XCTAssertEqual(state.reviewSession?.notes.first?.comment, "保留这条有效批注。")
        XCTAssertTrue(state.promptPreview.prompt.contains("保留这条有效批注。"))
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))
    }

    func testSuccessfulAnnotationEditClearsStaleFailureWhileWaitingForAutosave() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "先保留一条有效批注。", quickPrompts: [])
        state.updateNoteComment(id: "note_001", comment: "   \n")
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.updateNoteComment(id: "note_001", comment: "改成一条有效批注。")

        XCTAssertEqual(state.saveState, .saving)
        XCTAssertTrue(state.promptPreview.prompt.contains("改成一条有效批注。"))
        XCTAssertNil(ReaderStatusBannerPresentation.presentation(for: state.saveState))
    }

    func testSavingCurrentValidCommentClearsEmptyEditFailureWithoutDirtyingSession() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "先保留一条有效批注。", quickPrompts: [])
        let sessionBeforeNoOp = state.reviewSession
        let promptBeforeNoOp = state.promptPreview
        state.updateNoteComment(id: "note_001", comment: "   \n")
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.updateNoteComment(id: "note_001", comment: "先保留一条有效批注。")

        XCTAssertEqual(state.saveState, .saving)
        XCTAssertEqual(state.reviewSession, sessionBeforeNoOp)
        XCTAssertEqual(state.promptPreview, promptBeforeNoOp)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testClearingTransientFailureAfterAutosaveCompletesDoesNotReturnToSaving() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "先保留一条有效批注。", quickPrompts: [])

        try await waitUntil(timeout: 1.0) {
            state.saveState == .saved
        }

        let sessionAfterAutosave = state.reviewSession
        let promptAfterAutosave = state.promptPreview
        state.updateNoteComment(id: "note_001", comment: "   \n")
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.updateNoteComment(id: "note_001", comment: "先保留一条有效批注。")

        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertEqual(state.reviewSession, sessionAfterAutosave)
        XCTAssertEqual(state.promptPreview, promptAfterAutosave)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testManualReviewSaveClearsPendingAutosaveBeforeTransientFailureRestoresState() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "手动保存后不应残留保存中。", quickPrompts: [])
        XCTAssertEqual(state.saveState, .saving)

        state.saveReviewSessionNow()
        XCTAssertEqual(state.saveState, .saved)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: sourceURL).path))
        let sessionAfterManualSave = state.reviewSession
        let promptAfterManualSave = state.promptPreview

        state.updateNoteComment(id: "note_001", comment: "   \n")
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.updateNoteComment(id: "note_001", comment: "手动保存后不应残留保存中。")

        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertEqual(state.reviewSession, sessionAfterManualSave)
        XCTAssertEqual(state.promptPreview, promptAfterManualSave)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingNewTextClearsEmptyAnnotationCommentFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let firstSelection = try makeSelection(text: "核心价值", in: document)
        let secondSelection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(firstSelection)

        state.createAnnotation(comment: "   \n", quickPrompts: [])
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.updateSelection(secondSelection)

        XCTAssertEqual(state.readerSelection, secondSelection)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testReemittingSameTextSelectionClearsEmptyAnnotationCommentFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)

        state.createAnnotation(comment: "   \n", quickPrompts: [])
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.updateSelection(selection)

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testCancelingAnnotationClearsEmptyAnnotationCommentFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        state.createAnnotation(comment: "   \n", quickPrompts: [])
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.cancelAnnotation()

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingTextClearsMissingSelectionAnnotationFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertEqual(state.saveState, .failed("请先在阅读区选择需要批注的文本。"))

        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingCurrentHeadingClearsMissingSelectionAnnotationFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let heading = try XCTUnwrap(document.outline.flattened().first)
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)

        state.beginAnnotationFromCurrentSelection()
        XCTAssertEqual(state.saveState, .failed("请先在阅读区选择需要批注的文本。"))

        state.selectHeading(heading)

        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingExistingNoteClearsMissingSelectionAnnotationFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "这条批注可以定位。", quickPrompts: [])
        let promptBeforeFailure = state.promptPreview

        state.beginAnnotationFromCurrentSelection()
        XCTAssertEqual(state.saveState, .failed("请先在阅读区选择需要批注的文本。"))

        state.selectNote(id: "note_001")

        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertNil(state.readerSelection)
        XCTAssertEqual(state.scrollTargetRange, selection.renderedRange)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertEqual(state.reviewSession?.notes.count, 1)
        XCTAssertEqual(state.promptPreview, promptBeforeFailure)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingTextClearsMissingSavedSelectionAnnotationFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        state.createAnnotation(comment: "这条批注没有选区。", quickPrompts: [])
        XCTAssertEqual(state.saveState, .failed("没有可保存的文本选区。"))

        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testCancelAnnotationClearsMissingSavedSelectionAnnotationFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        state.createAnnotation(comment: "这条批注没有选区。", quickPrompts: [])
        XCTAssertEqual(state.saveState, .failed("没有可保存的文本选区。"))

        state.cancelAnnotation()

        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingHeadingClearsEmptyAnnotationCommentFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "AI 修改更可控", in: document)
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "核心价值" })
        state.updateSelection(selection)

        state.createAnnotation(comment: "   \n", quickPrompts: [])
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.selectHeading(heading)

        XCTAssertNil(state.readerSelection)
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.reviewSession?.notes.isEmpty ?? false)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingExistingNoteClearsEmptyAnnotationCommentFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let noteSelection = try makeSelection(text: "核心价值", in: document)
        let failedSelection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(noteSelection)
        state.createAnnotation(comment: "这条批注可以定位。", quickPrompts: [])
        let promptBeforeFailure = state.promptPreview
        state.updateSelection(failedSelection)

        state.createAnnotation(comment: "   \n", quickPrompts: [])
        XCTAssertEqual(state.saveState, .failed("批注意见不能为空。"))

        state.selectNote(id: "note_001")

        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertNil(state.readerSelection)
        XCTAssertEqual(state.scrollTargetRange, noteSelection.renderedRange)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertEqual(state.reviewSession?.notes.count, 1)
        XCTAssertEqual(state.promptPreview, promptBeforeFailure)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testAnnotationPanelScrollBehaviorTargetsOnlyAvailableSelectedNotes() {
        XCTAssertEqual(
            AnnotationPanelScrollBehavior.targetNoteID(
                selectedNoteID: "note_002",
                availableNoteIDs: ["note_001", "note_002", "note_003"]
            ),
            "note_002"
        )
        XCTAssertNil(AnnotationPanelScrollBehavior.targetNoteID(
            selectedNoteID: "note_004",
            availableNoteIDs: ["note_001", "note_002", "note_003"]
        ))
        XCTAssertNil(AnnotationPanelScrollBehavior.targetNoteID(
            selectedNoteID: nil,
            availableNoteIDs: ["note_001"]
        ))
    }

    func testAnnotationPanelScrollBehaviorSkipsAlreadyVisibleSelectionChanges() {
        XCTAssertNil(
            AnnotationPanelScrollBehavior.instruction(
                selectedNoteID: "note_002",
                availableNoteIDs: ["note_001", "note_002", "note_003"],
                visibleNoteIDs: ["note_001", "note_002"],
                isInitialAppearance: false
            )
        )
    }

    func testAnnotationPanelScrollBehaviorScrollsOffscreenSelectionChanges() {
        XCTAssertEqual(
            AnnotationPanelScrollBehavior.instruction(
                selectedNoteID: "note_002",
                availableNoteIDs: ["note_001", "note_002", "note_003"],
                visibleNoteIDs: ["note_001", "note_003"],
                isInitialAppearance: false
            ),
            AnnotationPanelScrollInstruction(targetNoteID: "note_002", animationDuration: 0.16)
        )
        XCTAssertNil(
            AnnotationPanelScrollBehavior.instruction(
                selectedNoteID: "note_004",
                availableNoteIDs: ["note_001", "note_002", "note_003"],
                visibleNoteIDs: ["note_001", "note_003"],
                isInitialAppearance: false
            )
        )
    }

    func testAnnotationPanelScrollBehaviorAvoidsInitialAppearAnimation() {
        XCTAssertEqual(
            AnnotationPanelScrollBehavior.instruction(
                selectedNoteID: "note_002",
                availableNoteIDs: ["note_001", "note_002"],
                visibleNoteIDs: [],
                isInitialAppearance: true
            ),
            AnnotationPanelScrollInstruction(targetNoteID: "note_002", animationDuration: nil)
        )
        XCTAssertNil(
            AnnotationPanelScrollBehavior.instruction(
                selectedNoteID: "note_003",
                availableNoteIDs: ["note_001", "note_002"],
                visibleNoteIDs: [],
                isInitialAppearance: true
            )
        )
    }

    func testAnnotationPanelVisibilityBehaviorUsesViewportAndStableOrder() {
        let noteFrames: [String: CGRect] = [
            "note_001": CGRect(x: 0, y: -12, width: 200, height: 20),
            "note_002": CGRect(x: 0, y: 12, width: 200, height: 80),
            "note_003": CGRect(x: 0, y: 198, width: 200, height: 80),
            "note_004": CGRect(x: 0, y: 240, width: 200, height: 80)
        ]

        XCTAssertEqual(
            AnnotationPanelVisibilityBehavior.visibleNoteIDs(
                noteIDs: ["note_004", "note_002", "note_001", "note_003"],
                noteFrames: noteFrames,
                viewport: CGRect(x: 0, y: 0, width: 220, height: 220),
                minimumVisibleHeight: 10
            ),
            ["note_002", "note_003"]
        )
    }

    func testAnnotationPanelVisibilityBehaviorIgnoresStaleMeasurementsAfterNoteListChanges() {
        XCTAssertEqual(
            AnnotationPanelVisibilityBehavior.currentVisibleNoteIDs(
                measuredNoteIDs: ["old-doc|note_001", "old-doc|note_002"],
                currentNoteIDs: ["old-doc|note_001", "old-doc|note_002"],
                visibleNoteIDs: ["note_002"]
            ),
            ["note_002"]
        )
        XCTAssertEqual(
            AnnotationPanelVisibilityBehavior.currentVisibleNoteIDs(
                measuredNoteIDs: ["old-doc|note_001"],
                currentNoteIDs: ["new-doc|note_001"],
                visibleNoteIDs: ["note_001"]
            ),
            []
        )
    }

    func testReaderStatusBannerOnlyShowsImportAndOpenFailures() {
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(for: .failed("只能打开 .md 或 .markdown 文件。")),
            ReaderStatusBannerPresentation(
                title: "需要处理",
                message: "只能打开 .md 或 .markdown 文件。",
                systemImage: "exclamationmark.triangle",
                copyTitle: "复制详情",
                copyHelp: "复制完整错误详情；不会关闭提示",
                copyValue: "只能打开 .md 或 .markdown 文件。",
                dismissTitle: "关闭",
                dismissHelp: "关闭这条提示",
                dismissShortcutHint: "Esc"
            )
        )
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(for: .failed("拖拽导入失败：无法读取文件 URL"))?.message,
            "拖拽导入失败：无法读取文件 URL"
        )
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: .failed("拖拽导入失败：无法读取文件 URL"),
                hasOpenDocument: true
            )?.message,
            "拖拽导入失败：无法读取文件 URL。当前文档仍保持打开。"
        )
        XCTAssertNil(ReaderStatusBannerPresentation.presentation(for: .failed("批注意见不能为空。")))
        XCTAssertNil(ReaderStatusBannerPresentation.presentation(for: .failed("没有可复制的有效 Prompt。")))
        XCTAssertNil(ReaderStatusBannerPresentation.presentation(for: .loaded))
        XCTAssertNil(ReaderStatusBannerPresentation.presentation(for: .saved))
        XCTAssertNil(ReaderStatusBannerPresentation.presentation(for: .saving))
    }

    func testReaderStatusBannerShowsTaskMarkerSaveFailuresWithDocumentContext() {
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: .failed("任务状态保存失败：权限不足"),
                hasOpenDocument: true
            ),
            ReaderStatusBannerPresentation(
                title: "保存未完成",
                message: "任务状态保存失败：权限不足。当前文档仍保持打开。",
                systemImage: "exclamationmark.triangle",
                actionTitle: nil,
                copyTitle: "复制详情",
                copyHelp: "复制完整失败详情；不会隐藏保存失败",
                copyValue: "任务状态保存失败：权限不足。当前文档仍保持打开。",
                dismissTitle: nil,
                dismissHelp: nil,
                dismissShortcutHint: nil
            )
        )
    }

    func testReaderStatusBannerDismissActionOnlyAppearsForTransientImportFailures() {
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: .failed("拖拽导入失败：无法读取文件 URL"),
                hasOpenDocument: true
            )?.dismissTitle,
            "关闭"
        )
        XCTAssertNil(
            ReaderStatusBannerPresentation.presentation(
                for: .failed("任务状态保存失败：权限不足"),
                hasOpenDocument: true
            )?.dismissTitle
        )
    }

    func testReaderStatusBannerExposesCopyActionForFullMessage() {
        let message = "拖拽导入失败：无法读取文件 URL"
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: .failed(message),
                hasOpenDocument: true
            ),
            ReaderStatusBannerPresentation(
                title: "导入未完成",
                message: "\(message)。当前文档仍保持打开。",
                systemImage: "exclamationmark.triangle",
                copyTitle: "复制详情",
                copyHelp: "复制完整错误详情；不会关闭提示",
                copyValue: "\(message)。当前文档仍保持打开。",
                dismissTitle: "关闭",
                dismissHelp: "关闭这条提示",
                dismissShortcutHint: "Esc"
            )
        )

        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: .failed("任务状态保存失败：权限不足"),
                hasOpenDocument: true
            )?.copyTitle,
            "复制详情"
        )
    }

    func testReaderStatusBannerCopyButtonShowsCopiedFeedback() {
        XCTAssertEqual(
            ReaderStatusBannerCopyButtonPresentation.presentation(
                title: "复制详情",
                help: "复制完整错误详情；不会关闭提示",
                isCopied: false
            ),
            ReaderStatusBannerCopyButtonPresentation(
                title: "复制错误详情",
                systemImage: "doc.on.doc",
                hitTargetSize: 24,
                backgroundOpacity: 0,
                help: "复制完整错误详情；不会关闭提示",
                accessibilityLabel: "复制错误详情",
                accessibilityHint: "按 Return 复制完整错误详情；提示会保持显示"
            )
        )
        XCTAssertEqual(
            ReaderStatusBannerCopyButtonPresentation.presentation(
                title: "复制详情",
                help: "复制完整错误详情；不会关闭提示",
                isCopied: true
            ),
            ReaderStatusBannerCopyButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                hitTargetSize: 24,
                backgroundOpacity: 0.10,
                help: "已复制错误详情",
                accessibilityLabel: "已复制错误详情",
                accessibilityHint: "错误详情已复制到剪切板，可继续复制；提示会保持显示，按钮会短暂恢复"
            )
        )
        XCTAssertEqual(
            ReaderStatusBannerCopyButtonPresentation.presentation(
                title: "复制详情",
                help: "复制完整失败详情；不会隐藏保存失败",
                isCopied: false
            ),
            ReaderStatusBannerCopyButtonPresentation(
                title: "复制失败详情",
                systemImage: "doc.on.doc",
                hitTargetSize: 24,
                backgroundOpacity: 0,
                help: "复制完整失败详情；不会隐藏保存失败",
                accessibilityLabel: "复制失败详情",
                accessibilityHint: "按 Return 复制完整失败详情；提示会保持显示，保存失败仍会继续可见"
            )
        )
        XCTAssertEqual(
            ReaderStatusBannerCopyButtonPresentation.presentation(
                title: "复制详情",
                help: "复制完整提示；不会关闭提示",
                isCopied: false
            ),
            ReaderStatusBannerCopyButtonPresentation(
                title: "复制提示详情",
                systemImage: "doc.on.doc",
                hitTargetSize: 24,
                backgroundOpacity: 0,
                help: "复制完整提示；不会关闭提示",
                accessibilityLabel: "复制提示详情",
                accessibilityHint: "按 Return 复制完整提示；提示会保持显示"
            )
        )
        XCTAssertEqual(
            ReaderStatusBannerCopyButtonPresentation.presentation(
                title: "复制详情",
                help: "复制完整提示；不会关闭提示",
                isCopied: true
            ),
            ReaderStatusBannerCopyButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                hitTargetSize: 24,
                backgroundOpacity: 0.10,
                help: "已复制提示详情",
                accessibilityLabel: "已复制提示详情",
                accessibilityHint: "提示详情已复制到剪切板，可继续复制；提示会保持显示，按钮会短暂恢复"
            )
        )
    }

    func testCopyingReaderStatusMessageDoesNotChangeVisibleSaveState() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        let state = AppState()
        let message = "拖拽导入失败：无法读取文件 URL。当前文档仍保持打开。"
        state.saveState = .failed("拖拽导入失败：无法读取文件 URL")

        XCTAssertTrue(state.copyStatusMessageToPasteboard(message, pasteboard: pasteboard))

        XCTAssertEqual(pasteboard.string(forType: .string), message)
        XCTAssertEqual(state.saveState, .failed("拖拽导入失败：无法读取文件 URL"))
        XCTAssertFalse(state.copyStatusMessageToPasteboard("   ", pasteboard: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), message)
    }

    func testReaderEmptyStatePresentationMakesOpenActionDiscoverable() {
        XCTAssertEqual(
            ReaderEmptyStatePresentation.presentation(),
            ReaderEmptyStatePresentation(
                title: "打开 Markdown",
                message: "选择 .md 或 .markdown 文件开始阅读和批注",
                systemImage: "doc.text",
                actionTitle: "选择 .md 文件",
                help: "打开 Markdown 文档",
                keyboardShortcutHint: "Return",
                accessibilityLabel: "打开 Markdown，选择 .md 或 .markdown 文件开始阅读和批注",
                accessibilityHint: "按 Return 选择 Markdown 文件"
            )
        )
    }

    func testReaderFooterStatusPresentationExposesCopyActionForTruncatedStatus() {
        let message = "批注保存失败：无法写入文件 /Users/example/Documents/Very/Long/Path/sample.review.json，请检查权限后重试。"
        let presentation = ReaderFooterStatusPresentation.presentation(
            documentText: "2048 字符    80 行",
            saveState: .failed(message),
            maximumSaveStateLength: 28
        )

        XCTAssertEqual(presentation.saveStateText, "批注保存失败：无法写入文件 /Users/exampl…")
        XCTAssertEqual(presentation.documentAccessibilityLabel, "文档状态：2048 字符    80 行")
        XCTAssertEqual(presentation.saveStateAccessibilityLabel, "保存状态：\(message)")
        XCTAssertEqual(
            presentation.saveStateAccessibilityHint,
            "保存失败且状态已截断；可悬停查看或复制完整失败状态，复制不会改变当前保存状态"
        )
        XCTAssertEqual(presentation.copyTitle, "复制失败状态")
        XCTAssertEqual(presentation.copyHelp, "复制完整失败状态；不会改变当前保存状态")
        XCTAssertEqual(presentation.copyValue, message)
        let idlePresentation = ReaderFooterStatusPresentation.presentation(
            documentText: "未打开文档",
            saveState: .idle
        )
        XCTAssertEqual(idlePresentation.documentAccessibilityLabel, "文档状态：未打开文档")
        XCTAssertEqual(idlePresentation.saveStateAccessibilityLabel, "保存状态：就绪")
        XCTAssertNil(idlePresentation.saveStateAccessibilityHint)
        XCTAssertNil(idlePresentation.copyTitle)
    }

    func testReaderFooterStatusPresentationExposesCopyActionForVisibleFailures() {
        let message = "任务状态保存失败：权限不足"
        let presentation = ReaderFooterStatusPresentation.presentation(
            documentText: "2048 字符    80 行",
            saveState: .failed(message),
            maximumSaveStateLength: 80
        )

        XCTAssertEqual(presentation.saveStateText, message)
        XCTAssertEqual(presentation.saveStateAccessibilityHint, "保存失败；可复制完整失败状态，复制不会改变当前保存状态")
        XCTAssertEqual(presentation.copyTitle, "复制失败状态")
        XCTAssertEqual(presentation.copyHelp, "复制完整失败状态；不会改变当前保存状态")
        XCTAssertEqual(presentation.copyValue, message)
    }

    func testReaderFooterStatusCopyButtonShowsCopiedFeedback() {
        XCTAssertEqual(
            ReaderFooterStatusCopyButtonPresentation.presentation(
                title: "复制状态",
                help: "复制完整状态信息",
                isCopied: false
            ),
            ReaderFooterStatusCopyButtonPresentation(
                title: "复制状态",
                systemImage: "doc.on.doc",
                hitTargetSize: 24,
                backgroundOpacity: 0,
                help: "复制完整状态信息",
                accessibilityLabel: "复制状态",
                accessibilityHint: "按 Return 复制完整状态信息；状态栏会保持显示"
            )
        )
        XCTAssertEqual(
            ReaderFooterStatusCopyButtonPresentation.presentation(
                title: "复制状态",
                help: "复制完整状态信息",
                isCopied: true
            ),
            ReaderFooterStatusCopyButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                hitTargetSize: 24,
                backgroundOpacity: 0.10,
                help: "已复制状态信息",
                accessibilityLabel: "已复制状态",
                accessibilityHint: "完整状态信息已复制到剪切板，可继续复制；按钮会短暂恢复"
            )
        )
        XCTAssertEqual(
            ReaderFooterStatusCopyButtonPresentation.presentation(
                title: "复制失败状态",
                help: "复制完整失败状态；不会改变当前保存状态",
                isCopied: false
            ),
            ReaderFooterStatusCopyButtonPresentation(
                title: "复制失败状态",
                systemImage: "doc.on.doc",
                hitTargetSize: 24,
                backgroundOpacity: 0,
                help: "复制完整失败状态；不会改变当前保存状态",
                accessibilityLabel: "复制失败状态",
                accessibilityHint: "按 Return 复制完整失败状态；不会改变当前保存状态，状态栏会保持显示"
            )
        )
    }

    func testReaderStatusBannerShowsSidecarLoadWarningsWithoutCallingImportFailed() {
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: .failed("批注文件读取失败，已创建空会话：JSON 格式错误"),
                hasOpenDocument: true
            ),
            ReaderStatusBannerPresentation(
                title: "批注未恢复",
                message: "文档已打开，批注未恢复；已使用空批注会话继续。JSON 格式错误",
                systemImage: "exclamationmark.triangle",
                copyTitle: "复制详情",
                copyHelp: "复制完整提示；不会关闭提示",
                copyValue: "文档已打开，批注未恢复；已使用空批注会话继续。JSON 格式错误",
                dismissTitle: "关闭",
                dismissHelp: "关闭这条提示",
                dismissShortcutHint: "Esc"
            )
        )
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: .failed("批注文件读取失败，已从应用数据目录恢复：JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid"),
                hasOpenDocument: true
            ),
            ReaderStatusBannerPresentation(
                title: "批注已恢复",
                message: "文档已打开，批注已从应用数据目录恢复。JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid",
                systemImage: "exclamationmark.triangle",
                copyTitle: "复制详情",
                copyHelp: "复制完整提示；不会关闭提示",
                copyValue: "文档已打开，批注已从应用数据目录恢复。JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid",
                dismissTitle: "关闭",
                dismissHelp: "关闭这条提示",
                dismissShortcutHint: "Esc"
            )
        )
    }

    func testReaderFooterStatusPresentationKeepsLongMessagesScannable() {
        let longPath = "/Users/example/Documents/Very/Long/Path/That/Can/Overflow/sample.review.json"
        let presentation = ReaderFooterStatusPresentation.presentation(
            documentText: "3200 字符    140 行",
            saveState: .failed("批注保存失败：无法写入文件 \(longPath)，请检查权限后重试。")
        )

        XCTAssertEqual(presentation.documentText, "3200 字符    140 行")
        XCTAssertLessThanOrEqual(presentation.saveStateText.count, 72)
        XCTAssertTrue(presentation.saveStateText.hasSuffix("…"))
        XCTAssertEqual(
            presentation.fullSaveStateText,
            "批注保存失败：无法写入文件 \(longPath)，请检查权限后重试。"
        )
    }

    func testPromptPreviewPresentationSeparatesEmptyDocumentAndWarningStates() {
        XCTAssertEqual(
            PromptPreviewPresentation.presentation(
                state: .empty,
                hasOpenDocument: false
            ),
            PromptPreviewPresentation(
                previewText: "打开 Markdown 后显示 Prompt。",
                systemImage: "doc.text",
                isPlaceholder: true,
                placeholderLineLimit: 3,
                placeholderMinimumScaleFactor: 0.86,
                accessibilityLabel: "Prompt 预览，未打开文档",
                accessibilityHint: "按 ⌘O 打开 Markdown；生成 Prompt 后复制和保存动作会可用"
            )
        )
        XCTAssertEqual(
            PromptPreviewPresentation.presentation(
                state: .empty,
                hasOpenDocument: true
            ),
            PromptPreviewPresentation(
                previewText: "暂无纳入 Prompt 的批注。",
                systemImage: "text.badge.plus",
                isPlaceholder: true,
                placeholderLineLimit: 3,
                placeholderMinimumScaleFactor: 0.86,
                accessibilityLabel: "Prompt 预览，暂无纳入 Prompt 的批注",
                accessibilityHint: "先在批注卡片勾选纳入 Prompt；复制动作会提示但不会修改剪切板"
            )
        )
        XCTAssertEqual(
            PromptPreviewPresentation.presentation(
                state: PromptPreviewState(warnings: ["有 1 条批注需要重新定位。"]),
                hasOpenDocument: true
            ),
            PromptPreviewPresentation(
                previewText: "有 1 条批注需要重新定位。",
                systemImage: "exclamationmark.triangle",
                isPlaceholder: true,
                placeholderLineLimit: 3,
                placeholderMinimumScaleFactor: 0.86,
                accessibilityLabel: "Prompt 预览，有批注需要确认",
                accessibilityHint: "先重新定位或排除失效批注；Prompt 暂不可复制或保存"
            )
        )
        XCTAssertEqual(
            PromptPreviewPresentation.presentation(
                state: PromptPreviewState(prompt: "请按批注修改", includedNoteCount: 1),
                hasOpenDocument: true
            ),
            PromptPreviewPresentation(
                previewText: "请按批注修改",
                systemImage: nil,
                isPlaceholder: false,
                placeholderLineLimit: 3,
                placeholderMinimumScaleFactor: 0.86,
                accessibilityLabel: "Prompt 预览，已生成 Prompt，1 条批注",
                accessibilityHint: "可选择文本复制；复制或保存按钮会先同步批注再执行"
            )
        )
    }

    func testPromptPreviewHeaderPresentationClarifiesDocumentAndSelectionState() {
        XCTAssertEqual(
            PromptPreviewHeaderPresentation.presentation(
                state: .empty,
                hasOpenDocument: false
            ),
            PromptPreviewHeaderPresentation(
                countText: "未打开文档",
                help: "打开 Markdown 后会统计纳入 Prompt 的批注；复制和保存动作会随 Prompt 启用",
                accessibilityLabel: "Prompt 预览状态：未打开文档",
                accessibilityHint: "打开 Markdown 后会统计纳入 Prompt 的批注；复制和保存动作会随 Prompt 启用"
            )
        )
        XCTAssertEqual(
            PromptPreviewHeaderPresentation.presentation(
                state: .empty,
                hasOpenDocument: true
            ),
            PromptPreviewHeaderPresentation(
                countText: "未选择批注",
                help: "勾选批注后会进入 Prompt；复制动作会提示但不会修改剪切板",
                accessibilityLabel: "Prompt 预览状态：未选择批注",
                accessibilityHint: "勾选批注后会进入 Prompt；复制动作会提示但不会修改剪切板"
            )
        )
        XCTAssertEqual(
            PromptPreviewHeaderPresentation.presentation(
                state: PromptPreviewState(warnings: ["有 1 条批注需要重新定位。"], includedNoteCount: 1),
                hasOpenDocument: true
            ),
            PromptPreviewHeaderPresentation(
                countText: "1 条需确认",
                help: "有批注需要重新定位或排除后再使用 Prompt；复制和保存暂不可用",
                accessibilityLabel: "Prompt 预览状态：1 条需确认",
                accessibilityHint: "有批注需要重新定位或排除后再使用 Prompt；复制和保存暂不可用"
            )
        )
        XCTAssertEqual(
            PromptPreviewHeaderPresentation.presentation(
                state: PromptPreviewState(prompt: "请按批注修改", includedNoteCount: 3),
                hasOpenDocument: true
            ),
            PromptPreviewHeaderPresentation(
                countText: "已选择 3 条批注",
                help: "当前 Prompt 将使用 3 条批注；复制或保存会先同步批注",
                accessibilityLabel: "Prompt 预览状态：已选择 3 条批注",
                accessibilityHint: "当前 Prompt 将使用 3 条批注；复制或保存会先同步批注"
            )
        )
    }

    func testPromptPreviewWarningPresentationStaysVisibleWhenPromptExists() {
        XCTAssertNil(
            PromptPreviewWarningPresentation.presentation(state: PromptPreviewState(prompt: "请按批注修改", includedNoteCount: 1))
        )

        XCTAssertEqual(
            PromptPreviewWarningPresentation.presentation(
                state: PromptPreviewState(
                    prompt: "请按可用批注修改",
                    warnings: ["有 1 条批注需要重新定位。"],
                    includedNoteCount: 2
                )
            ),
            PromptPreviewWarningPresentation(
                message: "有 1 条批注需要重新定位。",
                systemImage: "exclamationmark.triangle",
                help: "重新定位或排除这条批注后再使用 Prompt；可用批注仍会显示在预览中",
                accessibilityLabel: "Prompt 警告：有 1 条批注需要重新定位。",
                accessibilityHint: "先处理这条批注；可用批注仍可复制和保存",
                lineLimit: 2
            )
        )
    }

    func testReaderStatusBannerActionAndDismissButtonsExplainKeyboardFlow() {
        XCTAssertEqual(
            ReaderStatusBannerActionButtonPresentation.presentation(title: "重新载入文件"),
            ReaderStatusBannerActionButtonPresentation(
                title: "重新载入文件",
                help: "重新载入磁盘上的 Markdown 文件，并重新同步任务状态",
                accessibilityLabel: "重新载入文件",
                accessibilityHint: "按 Return 重新载入磁盘上的 Markdown 文件；外部修改会以磁盘内容为准"
            )
        )
        XCTAssertEqual(
            ReaderStatusBannerDismissButtonPresentation.presentation(
                title: "关闭",
                help: "关闭这条提示",
                shortcutHint: "Esc"
            ),
            ReaderStatusBannerDismissButtonPresentation(
                title: "关闭",
                hitTargetSize: 24,
                backgroundOpacity: 0,
                help: "关闭这条提示（Esc）",
                accessibilityLabel: "关闭提示",
                accessibilityHint: "按 Esc 关闭当前提示；不会重试打开文件，不会修改当前文档或批注"
            )
        )
    }

    func testReaderAnnotationCursorStateTracksAnnotationOperation() {
        XCTAssertEqual(
            ReaderAnnotationCursorState.state(
                canCreateAnnotation: false,
                isAnnotationPopoverPresented: false,
                hasExistingAnnotationSelection: false
            ),
            .textSelection
        )
        XCTAssertEqual(
            ReaderAnnotationCursorState.state(
                canCreateAnnotation: true,
                isAnnotationPopoverPresented: false,
                hasExistingAnnotationSelection: false
            ),
            .annotationReady
        )
        XCTAssertEqual(
            ReaderAnnotationCursorState.state(
                canCreateAnnotation: true,
                isAnnotationPopoverPresented: true,
                hasExistingAnnotationSelection: false
            ),
            .annotationEditing
        )
        XCTAssertEqual(
            ReaderAnnotationCursorState.state(
                canCreateAnnotation: false,
                isAnnotationPopoverPresented: false,
                hasExistingAnnotationSelection: true
            ),
            .existingAnnotation
        )
        XCTAssertEqual(ReaderAnnotationCursorState.annotationReady.cursorKind, .crosshair)
        XCTAssertEqual(ReaderAnnotationCursorState.annotationEditing.cursorKind, .arrow)
        XCTAssertEqual(ReaderAnnotationCursorState.existingAnnotation.cursorKind, .pointingHand)
    }

    func testAnnotationEntryButtonPresentationShowsHoverActiveAndPressedFeedback() {
        XCTAssertEqual(
            AnnotationEntryButtonPresentation.presentation(
                isActive: false,
                isHovered: false,
                isPressed: false
            ),
            AnnotationEntryButtonPresentation(
                title: "批注 +",
                help: "为当前选区添加批注",
                accessibilityLabel: "为选区添加批注",
                accessibilityHelp: "按 Return 打开批注输入框；会保留当前选区",
                backgroundAlpha: 0,
                borderWidth: 1,
                shadowOpacity: 0.14,
                shadowRadius: 9,
                shadowYOffset: 3
            )
        )

        XCTAssertEqual(
            AnnotationEntryButtonPresentation.presentation(
                isActive: false,
                isHovered: true,
                isPressed: false
            ),
            AnnotationEntryButtonPresentation(
                title: "批注 +",
                help: "点击为当前选区添加批注",
                accessibilityLabel: "为选区添加批注",
                accessibilityHelp: "按 Return 打开批注输入框；会保留当前选区",
                backgroundAlpha: 0.08,
                borderWidth: 1.1,
                shadowOpacity: 0.18,
                shadowRadius: 11,
                shadowYOffset: 4
            )
        )

        XCTAssertEqual(
            AnnotationEntryButtonPresentation.presentation(
                isActive: false,
                isHovered: true,
                isPressed: true
            ).help,
            "正在打开批注输入框"
        )

        XCTAssertEqual(
            AnnotationEntryButtonPresentation.presentation(
                isActive: true,
                isHovered: false,
                isPressed: false
            ),
            AnnotationEntryButtonPresentation(
                title: "批注 +",
                help: "批注输入框已打开",
                accessibilityLabel: "批注输入框已打开",
                accessibilityHelp: "输入意见后按 ⌘↩ 保存，按 Esc 取消",
                backgroundAlpha: 0.14,
                borderWidth: 1.2,
                shadowOpacity: 0.22,
                shadowRadius: 12,
                shadowYOffset: 4
            )
        )
    }

    func testReaderCursorRefreshImmediatelyAppliesChangedCursorInsideReader() {
        XCTAssertEqual(
            ReaderCursorRefreshDecision.decision(
                from: .textSelection,
                to: .annotationReady,
                isPointerInsideReader: true,
                isPointerOverTaskMarker: false
            ),
            ReaderCursorRefreshDecision(
                invalidatesCursorRects: true,
                immediateCursorKind: .crosshair
            )
        )
        XCTAssertEqual(
            ReaderCursorRefreshDecision.decision(
                from: .annotationReady,
                to: .annotationEditing,
                isPointerInsideReader: true,
                isPointerOverTaskMarker: false
            ).immediateCursorKind,
            .arrow
        )
    }

    func testReaderCursorRefreshDoesNotLeakCursorOutsideReader() {
        XCTAssertEqual(
            ReaderCursorRefreshDecision.decision(
                from: .textSelection,
                to: .annotationReady,
                isPointerInsideReader: false,
                isPointerOverTaskMarker: false
            ),
            ReaderCursorRefreshDecision(
                invalidatesCursorRects: true,
                immediateCursorKind: nil
            )
        )
    }

    func testReaderCursorRefreshKeepsTaskMarkerHandCursorPriority() {
        XCTAssertEqual(
            ReaderCursorRefreshDecision.decision(
                from: .textSelection,
                to: .annotationReady,
                isPointerInsideReader: true,
                isPointerOverTaskMarker: true
            ),
            ReaderCursorRefreshDecision(
                invalidatesCursorRects: true,
                immediateCursorKind: .pointingHand
            )
        )
    }

    func testReaderCursorRefreshIgnoresUnchangedState() {
        XCTAssertEqual(
            ReaderCursorRefreshDecision.decision(
                from: .annotationReady,
                to: .annotationReady,
                isPointerInsideReader: true,
                isPointerOverTaskMarker: false
            ),
            ReaderCursorRefreshDecision(
                invalidatesCursorRects: false,
                immediateCursorKind: nil
            )
        )
    }

    func testSidecarLoadWarningPresentationFeedsReaderAndAnnotationStatus() throws {
        let rawWarning = "批注文件读取失败，已从应用数据目录恢复：JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid"
        let shared = try XCTUnwrap(SidecarLoadWarningPresentation.presentation(from: rawWarning))

        XCTAssertEqual(shared.title, "批注已恢复")
        XCTAssertEqual(
            shared.message,
            "文档已打开，批注已从应用数据目录恢复。JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid"
        )
        XCTAssertEqual(shared.systemImage, "exclamationmark.triangle")
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(for: .failed(rawWarning), hasOpenDocument: true),
            ReaderStatusBannerPresentation(
                title: shared.title,
                message: shared.message,
                systemImage: shared.systemImage,
                copyTitle: "复制详情",
                copyHelp: "复制完整提示；不会关闭提示",
                copyValue: shared.message,
                dismissTitle: "关闭",
                dismissHelp: "关闭这条提示",
                dismissShortcutHint: "Esc"
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed(rawWarning)),
            AnnotationActionStatusPresentation(
                message: shared.message,
                systemImage: shared.systemImage,
                isFailure: false
            )
        )
    }

    func testSidecarLoadWarningSurvivesAutomaticAnchorRecoveryAutosave() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        try sampleSource(title: "当前阅读", heading: "恢复批注")
            .write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        let fallbackURL = locator.fallbackReviewSessionURL(for: sourceURL)
        try "{ invalid review json".write(to: sidecarURL, atomically: true, encoding: .utf8)

        let staleSession = ReviewSession(
            sourceFile: sourceURL.path,
            sourceHash: "stale-hash",
            lastNoteSequence: 1,
            notes: [
                ReviewNote(
                    id: "note_001",
                    anchor: TextAnchor(
                        headingPath: ["恢复批注"],
                        selectedText: "核心价值",
                        normalizedSelectedText: TextNormalizer.normalized("核心价值"),
                        sourceRange: nil,
                        renderedRange: nil,
                        contextBefore: "",
                        contextAfter: "",
                        documentHash: "stale-hash"
                    ),
                    comment: "恢复后仍要让用户看到提示。"
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: fallbackURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(staleSession).write(to: fallbackURL)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))

        state.openDocument(at: sourceURL)
        guard case let .failed(initialMessage) = state.saveState else {
            return XCTFail("Expected sidecar load warning, got \(state.saveState).")
        }
        XCTAssertTrue(initialMessage.hasPrefix("批注文件读取失败，已从应用数据目录恢复："))
        XCTAssertEqual(state.reviewSession?.notes.first?.anchor.documentHash, document.sourceHash)
        XCTAssertNotNil(state.reviewSession?.notes.first?.anchor.renderedRange)

        try await Task.sleep(nanoseconds: 520_000_000)

        XCTAssertEqual(state.saveState, .failed(initialMessage))
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: true
            )?.title,
            "批注已恢复"
        )
    }

    func testAnnotationActionStatusShowsPromptAndReviewActionFeedback() {
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .copied),
            AnnotationActionStatusPresentation(
                message: "Prompt 已复制",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .promptSaved("/tmp/sample.prompt.md"))?.message,
            "Prompt 已保存：/tmp/sample.prompt.md"
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .saved),
            AnnotationActionStatusPresentation(
                message: "批注已保存",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed("没有可复制的有效 Prompt。")),
            AnnotationActionStatusPresentation(
                message: "没有可复制的有效 Prompt。",
                systemImage: "exclamationmark.triangle",
                isFailure: true
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed("该批注的原文位置需要重新确认。")),
            AnnotationActionStatusPresentation(
                message: "该批注的原文位置需要重新确认。请在阅读区重新选择原文，恢复后提示会自动消失。",
                systemImage: "exclamationmark.triangle",
                isFailure: true
            )
        )
        XCTAssertNil(
            AnnotationActionStatusPresentation.presentation(
                for: .failed("只能打开 .md 或 .markdown 文件，当前文件类型为 .txt。")
            )
        )
        XCTAssertNil(
            AnnotationActionStatusPresentation.presentation(
                for: .failed("拖拽导入失败：无法读取文件 URL")
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed("批注保存失败：磁盘已满"))?.message,
            "批注保存失败：磁盘已满。请处理保存位置后重试保存。"
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed("批注保存失败：磁盘已满"))?.showsRetrySaveAction,
            true
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(
                for: .failed("批注保存失败，已暂停打开/导入以避免丢失批注：磁盘已满")
            )?.message,
            "批注保存失败，已暂停打开/导入以避免丢失批注：磁盘已满。请处理保存位置后重试保存，再重新导入。"
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(
                for: .failed("批注保存失败，已暂停打开/导入以避免丢失批注：磁盘已满")
            )?.showsRetrySaveAction,
            true
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed("Prompt 保存失败：磁盘已满"))?.showsRetrySaveAction,
            false
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed("批注从应用数据目录恢复。")),
            AnnotationActionStatusPresentation(
                message: "文档已打开，批注已从应用数据目录恢复。",
                systemImage: "exclamationmark.triangle",
                isFailure: false
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(for: .failed("批注文件读取失败，已创建空会话：JSON 格式错误")),
            AnnotationActionStatusPresentation(
                message: "文档已打开，批注未恢复；已使用空批注会话继续。JSON 格式错误",
                systemImage: "exclamationmark.triangle",
                isFailure: false
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(
                for: .failed("批注文件读取失败，已创建空会话：JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid")
            ),
            AnnotationActionStatusPresentation(
                message: "文档已打开，批注未恢复；已使用空批注会话继续。JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid",
                systemImage: "exclamationmark.triangle",
                isFailure: false
            )
        )
        XCTAssertEqual(
            AnnotationActionStatusPresentation.presentation(
                for: .failed("批注文件读取失败，已从应用数据目录恢复：JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid")
            ),
            AnnotationActionStatusPresentation(
                message: "文档已打开，批注已从应用数据目录恢复。JSON 格式错误。原文件已备份到：/tmp/sample.review.json.invalid",
                systemImage: "exclamationmark.triangle",
                isFailure: false
            )
        )
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: .loaded))
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: .saving))
    }

    func testAnnotationActionStatusCompactsLongMessagesForPanelFooter() throws {
        let longPath = "/Users/example/Documents/Specs/Very/Long/Folder/sample.prompt.md"
        let status = try XCTUnwrap(
            AnnotationActionStatusPresentation.presentation(for: .promptSaved(longPath))
        )

        XCTAssertEqual(status.message, "Prompt 已保存：\(longPath)")
        XCTAssertLessThanOrEqual(status.displayMessage.count, 64)
        XCTAssertTrue(status.displayMessage.hasSuffix("…"))
        XCTAssertEqual(status.fullMessage, status.message)
        XCTAssertEqual(status.accessibilityLabel, "状态：Prompt 已保存：\(longPath)")
        XCTAssertEqual(status.accessibilityHint, "状态提示已截断，悬停可查看完整信息")
    }

    func testAnnotationActionStatusProvidesRetryHelpForSaveFailures() throws {
        let status = try XCTUnwrap(
            AnnotationActionStatusPresentation.presentation(for: .failed("批注保存失败：磁盘已满"))
        )

        XCTAssertTrue(status.showsRetrySaveAction)
        XCTAssertEqual(status.retrySaveHelp, "重新保存当前批注文件")
        XCTAssertEqual(status.retrySaveAccessibilityLabel, "重试保存批注")
        XCTAssertEqual(status.retrySaveAccessibilityHint, "按 Return 重新保存当前批注文件")
    }

    func testAnnotationPanelEmptyStatePresentationIsActionableWithoutDocument() {
        XCTAssertEqual(
            AnnotationPanelEmptyStatePresentation.presentation(
                hasOpenDocument: false,
                noteCount: 0
            ),
            AnnotationPanelEmptyStatePresentation(
                title: "未打开文档",
                message: "打开 Markdown 后显示批注",
                systemImage: "doc.text",
                actionTitle: "打开 Markdown",
                actionHelp: "选择 Markdown 文件开始阅读",
                actionShortcutHint: "Return",
                accessibilityLabel: "批注列表未打开文档",
                accessibilityHint: "可打开 Markdown 后查看和新增批注",
                actionAccessibilityLabel: "打开 Markdown 文件",
                actionAccessibilityHint: "按 Return 选择 Markdown 文件"
            )
        )
        XCTAssertEqual(
            AnnotationPanelEmptyStatePresentation.presentation(
                hasOpenDocument: true,
                noteCount: 0
            ),
            AnnotationPanelEmptyStatePresentation(
                title: "暂无批注",
                message: "批注会出现在这里",
                systemImage: "quote.bubble",
                actionTitle: nil,
                actionHelp: nil,
                actionShortcutHint: nil,
                accessibilityLabel: "批注列表暂无批注",
                accessibilityHint: "在阅读区选择文本后可添加批注",
                actionAccessibilityLabel: nil,
                actionAccessibilityHint: nil
            )
        )
        XCTAssertNil(
            AnnotationPanelEmptyStatePresentation.presentation(
                hasOpenDocument: true,
                noteCount: 2
            )
        )
    }

    func testAnnotationPanelModeSummaryPresentationClarifiesPromptListHeader() {
        XCTAssertEqual(
            AnnotationPanelModeSummaryPresentation.presentation(
                hasOpenDocument: false,
                noteCount: 0
            ),
            AnnotationPanelModeSummaryPresentation(
                title: "未打开文档",
                help: "打开 Markdown 后显示批注列表"
            )
        )
        XCTAssertEqual(
            AnnotationPanelModeSummaryPresentation.presentation(
                hasOpenDocument: true,
                noteCount: 0
            ),
            AnnotationPanelModeSummaryPresentation(
                title: "暂无批注",
                help: "在阅读区选择文本后添加批注"
            )
        )
        XCTAssertEqual(
            AnnotationPanelModeSummaryPresentation.presentation(
                hasOpenDocument: true,
                noteCount: 3
            ),
            AnnotationPanelModeSummaryPresentation(
                title: "3 条批注",
                help: "当前文档共有 3 条批注"
            )
        )
    }

    func testInspectorPanelModeExplainsSegmentedPickerChoices() {
        XCTAssertEqual(InspectorPanelMode.annotations.title, "批注")
        XCTAssertEqual(InspectorPanelMode.annotations.help, "查看和编辑当前文档批注")
        XCTAssertEqual(InspectorPanelMode.annotations.accessibilityLabel, "切换到批注面板")
        XCTAssertEqual(InspectorPanelMode.annotations.accessibilityHint, "按 Return 显示批注列表和单条批注操作")

        XCTAssertEqual(InspectorPanelMode.prompt.title, "Prompt")
        XCTAssertEqual(InspectorPanelMode.prompt.help, "预览由已选批注生成的 Prompt")
        XCTAssertEqual(InspectorPanelMode.prompt.accessibilityLabel, "切换到 Prompt 面板")
        XCTAssertEqual(InspectorPanelMode.prompt.accessibilityHint, "按 Return 显示 Prompt 预览和批注摘要")
    }

    func testNoteInclusionPresentationMakesPromptExclusionReadable() {
        let included = NoteInclusionPresentation.presentation(includeInPrompt: true, status: .confirmed)
        XCTAssertEqual(
            included,
            NoteInclusionPresentation(
                label: "纳入 Prompt",
                detail: "会进入生成结果",
                isToggleOn: true,
                help: "从 Prompt 中排除这条批注",
                accessibilityHint: "按 Return 从 Prompt 中排除这条批注",
                isToggleEnabled: true
            )
        )
        XCTAssertTrue(included.isToggleOn)

        let manuallyExcluded = NoteInclusionPresentation.presentation(includeInPrompt: false, status: .confirmed)
        XCTAssertEqual(
            manuallyExcluded,
            NoteInclusionPresentation(
                label: "已排除",
                detail: "不会进入 Prompt",
                isToggleOn: false,
                help: "纳入 Prompt",
                accessibilityHint: "按 Return 将这条批注纳入 Prompt",
                isToggleEnabled: true
            )
        )
        XCTAssertFalse(manuallyExcluded.isToggleOn)

        let statusExcluded = NoteInclusionPresentation.presentation(includeInPrompt: true, status: .excluded)
        XCTAssertEqual(
            statusExcluded,
            NoteInclusionPresentation(
                label: "已排除",
                detail: "不会进入 Prompt",
                isToggleOn: false,
                help: "定位丢失的批注暂不能纳入 Prompt；重新选择原文后会自动恢复",
                accessibilityHint: "定位丢失的批注暂不能纳入 Prompt；请先在阅读区重新选择原文，恢复后可重新纳入 Prompt",
                isToggleEnabled: false
            )
        )
        XCTAssertFalse(statusExcluded.isToggleOn)
    }

    func testNoteCardTapBehaviorDoesNotRetargetReaderWhileEditing() {
        XCTAssertTrue(NoteCardTapBehavior.shouldSelectNote(isEditing: false))
        XCTAssertFalse(NoteCardTapBehavior.shouldSelectNote(isEditing: true))
    }

    func testNoteCardChromePresentationSeparatesHoverActiveAndExcludedStates() {
        XCTAssertEqual(
            NoteCardChromePresentation.presentation(
                isActive: false,
                isHovering: false,
                isIncludedInPrompt: true
            ),
            NoteCardChromePresentation(emphasis: .normal, borderWidth: 1, opacity: 1)
        )
        XCTAssertEqual(
            NoteCardChromePresentation.presentation(
                isActive: false,
                isHovering: true,
                isIncludedInPrompt: true
            ),
            NoteCardChromePresentation(emphasis: .hover, borderWidth: 1.2, opacity: 1)
        )
        XCTAssertEqual(
            NoteCardChromePresentation.presentation(
                isActive: true,
                isHovering: false,
                isIncludedInPrompt: true
            ),
            NoteCardChromePresentation(emphasis: .active, borderWidth: 1.6, opacity: 1)
        )
        XCTAssertEqual(
            NoteCardChromePresentation.presentation(
                isActive: false,
                isHovering: false,
                isIncludedInPrompt: false
            ),
            NoteCardChromePresentation(emphasis: .excluded, borderWidth: 1, opacity: 0.68)
        )
    }

    func testNoteCardPrimaryActionPresentationDistinguishesEditAndSave() {
        XCTAssertEqual(
            NoteCardPrimaryActionPresentation.presentation(
                isEditing: false,
                canSave: false
            ),
            NoteCardPrimaryActionPresentation(
                title: "修改批注",
                systemImage: "pencil",
                isEnabled: true,
                help: "编辑这条批注",
                accessibilityLabel: "修改批注",
                accessibilityHint: "按 Return 进入编辑；焦点会移动到批注意见输入框，Esc 可取消",
                keyboardShortcutHint: nil
            )
        )
        XCTAssertEqual(
            NoteCardPrimaryActionPresentation.presentation(
                isEditing: true,
                canSave: false
            ),
            NoteCardPrimaryActionPresentation(
                title: "保存修改",
                systemImage: "checkmark",
                isEnabled: false,
                help: "修改批注内容后可保存",
                accessibilityLabel: "保存修改",
                accessibilityHint: "当前不可保存；修改批注内容后可用，焦点仍留在输入框",
                keyboardShortcutHint: nil
            )
        )
        XCTAssertEqual(
            NoteCardPrimaryActionPresentation.presentation(
                isEditing: true,
                canSave: true
            ),
            NoteCardPrimaryActionPresentation(
                title: "保存修改",
                systemImage: "checkmark",
                isEnabled: true,
                help: "保存当前批注修改（⌘↩）；保存后回到批注卡片",
                accessibilityLabel: "保存批注修改",
                accessibilityHint: "按 ⌘↩ 保存修改并退出编辑；焦点回到批注卡片",
                keyboardShortcutHint: "⌘↩"
            )
        )
    }

    func testNoteCardCancelActionPresentationWarnsBeforeDiscardingDrafts() {
        XCTAssertEqual(
            NoteCardCancelActionPresentation.presentation(hasUnsavedDraft: false),
            NoteCardCancelActionPresentation(
                title: "取消",
                help: "退出编辑并回到批注卡片",
                accessibilityLabel: "取消编辑",
                accessibilityHint: "按 Esc 退出编辑；不会修改批注"
            )
        )
        XCTAssertEqual(
            NoteCardCancelActionPresentation.presentation(hasUnsavedDraft: true),
            NoteCardCancelActionPresentation(
                title: "取消",
                help: "放弃未保存修改并回到批注卡片",
                accessibilityLabel: "放弃未保存修改并取消编辑",
                accessibilityHint: "按 Esc 放弃未保存修改并退出编辑；不会保存草稿"
            )
        )
    }

    func testNoteCardKeyboardShortcutPresentationRequiresFocusedEditor() {
        XCTAssertNil(
            NoteCardKeyboardShortcutPresentation.presentation(
                isEditing: false,
                canSave: true,
                isEditorFocused: true
            )
        )
        XCTAssertNil(
            NoteCardKeyboardShortcutPresentation.presentation(
                isEditing: true,
                canSave: true,
                isEditorFocused: false
            )
        )
        XCTAssertNil(
            NoteCardKeyboardShortcutPresentation.presentation(
                isEditing: true,
                canSave: false,
                isEditorFocused: true
            )
        )
        XCTAssertEqual(
            NoteCardKeyboardShortcutPresentation.presentation(
                isEditing: true,
                canSave: true,
                isEditorFocused: true
            ),
            .saveComment
        )
    }

    func testNoteCardEditorPlaceholderPresentationShowsOnlyForBlankEditingDrafts() {
        XCTAssertNil(
            NoteCardEditorPlaceholderPresentation.presentation(
                isEditing: false,
                draftComment: ""
            )
        )
        XCTAssertNil(
            NoteCardEditorPlaceholderPresentation.presentation(
                isEditing: true,
                draftComment: "请补充限制条件。"
            )
        )
        XCTAssertEqual(
            NoteCardEditorPlaceholderPresentation.presentation(
                isEditing: true,
                draftComment: "   \n"
            ),
            NoteCardEditorPlaceholderPresentation(
                text: "输入批注意见...",
                help: "批注意见不能为空"
            )
        )
    }

    func testNoteCardDeleteActionPresentationRequiresConfirmation() {
        XCTAssertEqual(
            NoteCardDeleteActionPresentation.presentation(isConfirmingDelete: false),
            NoteCardDeleteActionPresentation(
                title: "删除",
                systemImage: "trash",
                help: "进入删除确认；第一次不会删除",
                isDestructiveConfirmation: false,
                hitTargetHeight: 28,
                backgroundOpacity: 0,
                accessibilityLabel: "删除批注",
                accessibilityHint: "按 Return 进入删除确认；不会立即删除这条批注"
            )
        )
        XCTAssertEqual(
            NoteCardDeleteActionPresentation.presentation(isConfirmingDelete: true),
            NoteCardDeleteActionPresentation(
                title: "确认删除",
                systemImage: "trash.fill",
                help: "再次点击将永久删除；删除后焦点回到批注列表；按 Esc 或移出卡片取消",
                isDestructiveConfirmation: true,
                hitTargetHeight: 28,
                backgroundOpacity: 0.10,
                accessibilityLabel: "确认删除批注",
                accessibilityHint: "再次按 Return 将永久删除这条批注；删除后焦点回到批注列表；按 Esc 取消删除且不会修改批注"
            )
        )
    }

    func testNoteCardDeleteConfirmationResetBehaviorCancelsOnlyPendingConfirmation() {
        XCTAssertFalse(NoteCardDeleteConfirmationResetBehavior.shouldReset(isConfirmingDelete: false))
        XCTAssertTrue(NoteCardDeleteConfirmationResetBehavior.shouldReset(isConfirmingDelete: true))
    }

    func testNoteCardLocateActionPresentationExplainsAnchorState() {
        XCTAssertEqual(
            NoteCardLocateActionPresentation.presentation(status: .confirmed),
            NoteCardLocateActionPresentation(
                title: "定位",
                systemImage: "scope",
                help: "在阅读区滚动并高亮这条批注原文",
                accessibilityLabel: "定位批注",
                accessibilityHint: "按 Return 在阅读区定位这条批注；焦点会回到阅读区"
            )
        )
        XCTAssertEqual(
            NoteCardLocateActionPresentation.presentation(status: .anchorLost),
            NoteCardLocateActionPresentation(
                title: "定位需确认",
                systemImage: "scope",
                help: "原文位置已失效，点击后会提示在阅读区重新选择原文",
                accessibilityLabel: "定位需确认的批注",
                accessibilityHint: "按 Return 查看定位失效提示；焦点会回到阅读区，请重新选择原文"
            )
        )
    }

    func testNoteCardInteractionPresentationKeepsSelectedNoteReadOnlyUntilEditing() {
        XCTAssertEqual(
            NoteCardInteractionPresentation.presentation(
                isSelected: false,
                isEditing: false,
                canSave: false
            ),
            NoteCardInteractionPresentation(
                isChromeActive: false,
                showsEditor: false,
                allowsTapSelection: true,
                primaryAction: NoteCardPrimaryActionPresentation(
                    title: "修改批注",
                    systemImage: "pencil",
                    isEnabled: true,
                    help: "编辑这条批注",
                    accessibilityLabel: "修改批注",
                    accessibilityHint: "按 Return 进入编辑；焦点会移动到批注意见输入框，Esc 可取消",
                    keyboardShortcutHint: nil
                )
            )
        )
        XCTAssertEqual(
            NoteCardInteractionPresentation.presentation(
                isSelected: true,
                isEditing: false,
                canSave: false
            ),
            NoteCardInteractionPresentation(
                isChromeActive: true,
                showsEditor: false,
                allowsTapSelection: true,
                primaryAction: NoteCardPrimaryActionPresentation(
                    title: "修改批注",
                    systemImage: "pencil",
                    isEnabled: true,
                    help: "编辑这条批注",
                    accessibilityLabel: "修改批注",
                    accessibilityHint: "按 Return 进入编辑；焦点会移动到批注意见输入框，Esc 可取消",
                    keyboardShortcutHint: nil
                )
            )
        )
        XCTAssertEqual(
            NoteCardInteractionPresentation.presentation(
                isSelected: true,
                isEditing: true,
                canSave: true
            ),
            NoteCardInteractionPresentation(
                isChromeActive: true,
                showsEditor: true,
                allowsTapSelection: false,
                primaryAction: NoteCardPrimaryActionPresentation(
                    title: "保存修改",
                    systemImage: "checkmark",
                    isEnabled: true,
                    help: "保存当前批注修改（⌘↩）；保存后回到批注卡片",
                    accessibilityLabel: "保存批注修改",
                    accessibilityHint: "按 ⌘↩ 保存修改并退出编辑；焦点回到批注卡片",
                    keyboardShortcutHint: "⌘↩"
                )
            )
        )
    }

    func testNoteCardSelectionChangePresentationClosesCleanDraftsOnly() {
        XCTAssertEqual(
            NoteCardSelectionChangePresentation.presentation(
                noteID: "note_001",
                selectedNoteID: "note_002",
                isEditing: true,
                hasUnsavedDraft: false
            ),
            .endEditing
        )
        XCTAssertEqual(
            NoteCardSelectionChangePresentation.presentation(
                noteID: "note_001",
                selectedNoteID: "note_002",
                isEditing: true,
                hasUnsavedDraft: true
            ),
            .keepEditing
        )
        XCTAssertEqual(
            NoteCardSelectionChangePresentation.presentation(
                noteID: "note_001",
                selectedNoteID: "note_001",
                isEditing: true,
                hasUnsavedDraft: false
            ),
            .syncDraftToCurrentNote
        )
    }

    func testNoteCardStatusPresentationExplainsAnchorLostState() {
        XCTAssertNil(NoteCardStatusPresentation.presentation(status: .confirmed))
        guard let presentation = NoteCardStatusPresentation.presentation(status: .anchorLost) else {
            XCTFail("Expected anchor-lost note status presentation.")
            return
        }

        XCTAssertEqual(presentation.title, "定位需确认")
        XCTAssertEqual(presentation.systemImage, "exclamationmark.triangle")
        XCTAssertEqual(presentation.help, "原文位置已失效；在阅读区重新选择原文后会恢复定位并可继续纳入 Prompt")
        XCTAssertEqual(mirroredStringField("accessibilityLabel", in: presentation), "批注定位需确认")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: presentation),
            "原文位置已失效；点击定位需确认后回到阅读区重新选择原文"
        )
    }

    func testNoteCardDraftStatusPresentationShowsUnsavedEdits() {
        XCTAssertNil(
            NoteCardDraftStatusPresentation.presentation(
                isEditing: false,
                hasUnsavedDraft: true
            )
        )
        XCTAssertNil(
            NoteCardDraftStatusPresentation.presentation(
                isEditing: true,
                hasUnsavedDraft: false
            )
        )
        guard let presentation = NoteCardDraftStatusPresentation.presentation(
            isEditing: true,
            hasUnsavedDraft: true
        ) else {
            XCTFail("Expected unsaved draft status presentation.")
            return
        }

        XCTAssertEqual(presentation.title, "未保存修改")
        XCTAssertEqual(presentation.systemImage, "circle.fill")
        XCTAssertEqual(presentation.help, "保存或取消后会离开编辑状态")
        XCTAssertEqual(mirroredStringField("accessibilityLabel", in: presentation), "有未保存的批注修改")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: presentation),
            "按 ⌘↩ 保存，或按 Esc 放弃修改"
        )
    }

    func testNoteInclusionPresentationExplainsToggleAvailability() {
        XCTAssertEqual(
            NoteInclusionPresentation.presentation(includeInPrompt: true, status: .confirmed).help,
            "从 Prompt 中排除这条批注"
        )
        XCTAssertTrue(
            NoteInclusionPresentation.presentation(includeInPrompt: true, status: .confirmed).isToggleEnabled
        )
        XCTAssertEqual(
            NoteInclusionPresentation.presentation(includeInPrompt: false, status: .confirmed).help,
            "纳入 Prompt"
        )
        XCTAssertTrue(
            NoteInclusionPresentation.presentation(includeInPrompt: false, status: .confirmed).isToggleEnabled
        )
        XCTAssertEqual(
            NoteInclusionPresentation.presentation(includeInPrompt: true, status: .excluded).help,
            "定位丢失的批注暂不能纳入 Prompt；重新选择原文后会自动恢复"
        )
        XCTAssertFalse(
            NoteInclusionPresentation.presentation(includeInPrompt: true, status: .excluded).isToggleEnabled
        )
    }

    func testNoteCardEditPresentationTrimsAndRejectsBlankDrafts() {
        XCTAssertEqual(
            NoteCardEditPresentation.presentation(currentComment: "原批注", draftComment: "  请保留重点。 \n"),
            NoteCardEditPresentation(
                trimmedComment: "请保留重点。",
                canSave: true,
                accessibilityLabel: "批注意见输入框",
                accessibilityHint: "按 ⌘↩ 保存修改，按 Esc 取消编辑"
            )
        )
        XCTAssertEqual(
            NoteCardEditPresentation.presentation(currentComment: "原批注", draftComment: "\n  \t"),
            NoteCardEditPresentation(
                trimmedComment: "",
                canSave: false,
                accessibilityLabel: "批注意见输入框",
                accessibilityHint: "批注意见不能为空；输入内容后可保存"
            )
        )
    }

    func testNoteCardEditPresentationRequiresMeaningfulCommentChange() {
        XCTAssertEqual(
            NoteCardEditPresentation.presentation(currentComment: "请保留重点。", draftComment: "  请保留重点。 \n"),
            NoteCardEditPresentation(
                trimmedComment: "请保留重点。",
                canSave: false,
                accessibilityLabel: "批注意见输入框",
                accessibilityHint: "内容未变化；修改批注意见后可保存"
            )
        )
        XCTAssertEqual(
            NoteCardEditPresentation.presentation(currentComment: "请保留重点。", draftComment: "请补充权衡。"),
            NoteCardEditPresentation(
                trimmedComment: "请补充权衡。",
                canSave: true,
                accessibilityLabel: "批注意见输入框",
                accessibilityHint: "按 ⌘↩ 保存修改，按 Esc 取消编辑"
            )
        )
    }

    func testAnnotationPopoverPresentationKeepsSelectedTextContextCompact() {
        XCTAssertEqual(
            AnnotationPopoverPresentation.presentation(
                selectedText: "核心价值",
                comment: "  "
            ),
            AnnotationPopoverPresentation(
                selectedTextPreview: "核心价值",
                selectedTextHelp: "批注原文：核心价值",
                selectedTextAccessibilityLabel: "批注原文：核心价值",
                selectedTextAccessibilityHint: "当前批注会绑定到这段原文",
                shortcutHint: "保存 ⌘↩ · 取消 Esc",
                cancelTitle: "取消",
                cancelHelp: "取消批注（Esc）；不会保存当前草稿",
                cancelAccessibilityLabel: "取消批注",
                cancelAccessibilityHint: "按 Esc 关闭批注窗口；不会保存当前草稿，阅读位置保持不变",
                saveTitle: "添加批注",
                saveHelp: "输入批注意见后可添加批注；当前不会保存空批注",
                saveAccessibilityLabel: "添加批注",
                saveAccessibilityHint: "当前不可添加；批注意见不能为空，输入内容后可按 ⌘↩ 添加批注",
                commentAccessibilityLabel: "批注意见",
                commentAccessibilityHint: "批注意见不能为空；输入内容后可按 ⌘↩ 添加批注",
                canSave: false
            )
        )

        let longText = String(repeating: "这是一段很长的选中文本", count: 6)
        let presentation = AnnotationPopoverPresentation.presentation(
            selectedText: longText,
            comment: "请修改"
        )

        XCTAssertEqual(presentation.selectedTextPreview.count, 61)
        XCTAssertTrue(presentation.selectedTextPreview.hasSuffix("…"))
        XCTAssertEqual(presentation.selectedTextHelp, "批注原文：\(longText)")
        XCTAssertEqual(presentation.selectedTextAccessibilityHint, "预览已截断；完整原文可通过帮助提示查看")
        XCTAssertEqual(presentation.cancelTitle, "取消")
        XCTAssertTrue(presentation.canSave)
    }

    func testAnnotationPopoverPrimaryActionExplainsDisabledAndEnabledStates() {
        XCTAssertEqual(
            AnnotationPopoverPresentation.presentation(
                selectedText: "核心价值",
                comment: "   "
            ).saveHelp,
            "输入批注意见后可添加批注；当前不会保存空批注"
        )

        let readyPresentation = AnnotationPopoverPresentation.presentation(
            selectedText: "核心价值",
            comment: "请补充限制条件。"
        )
        XCTAssertEqual(readyPresentation.saveTitle, "添加批注")
        XCTAssertEqual(readyPresentation.saveHelp, "添加批注（⌘↩）；保存后会选中新批注")
        XCTAssertEqual(readyPresentation.saveAccessibilityLabel, "添加批注")
        XCTAssertEqual(readyPresentation.saveAccessibilityHint, "按 ⌘↩ 添加批注；保存后会选中新批注并关闭输入框")
        XCTAssertEqual(readyPresentation.commentAccessibilityHint, "按 ⌘↩ 添加批注；Esc 取消，快捷批注会追加到此输入框")
        XCTAssertEqual(readyPresentation.cancelHelp, "取消批注（Esc）；不会保存当前草稿")
        XCTAssertEqual(
            readyPresentation.cancelAccessibilityHint,
            "按 Esc 关闭批注窗口；不会保存当前草稿，阅读位置保持不变"
        )
        XCTAssertTrue(readyPresentation.canSave)
    }

    func testAnnotationQuickPromptButtonPresentationExplainsSelectionState() {
        XCTAssertEqual(
            AnnotationQuickPromptButtonPresentation.presentation(
                title: "润色",
                isSelected: false
            ),
            AnnotationQuickPromptButtonPresentation(
                title: "润色",
                help: "插入快捷批注：润色",
                accessibilityLabel: "快捷批注：润色",
                accessibilityHint: "按 Return 插入并回到批注意见输入框"
            )
        )
        XCTAssertEqual(
            AnnotationQuickPromptButtonPresentation.presentation(
                title: "润色",
                isSelected: true
            ),
            AnnotationQuickPromptButtonPresentation(
                title: "润色",
                help: "已插入「润色」，再次点击会回到输入框",
                accessibilityLabel: "已选择快捷批注：润色",
                accessibilityHint: "已插入，按 Return 回到批注意见输入框"
            )
        )
    }

    func testAnnotationQuickPromptLabelPresentationExplainsAttachedPrompt() {
        XCTAssertEqual(
            AnnotationQuickPromptLabelPresentation.presentation(title: "润色"),
            AnnotationQuickPromptLabelPresentation(
                title: "润色",
                help: "已附加快捷批注：润色",
                accessibilityLabel: "已附加快捷批注：润色"
            )
        )
    }

    func testAnnotationSourceQuotePresentationKeepsQuoteAccessible() {
        XCTAssertEqual(
            AnnotationSourceQuotePresentation.presentation(text: "  核心价值\n更可控  "),
            AnnotationSourceQuotePresentation(
                displayText: "核心价值 更可控",
                help: "批注原文：核心价值 更可控",
                accessibilityLabel: "批注原文：核心价值 更可控"
            )
        )
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

    func testSelectingHeadingClearsTransientReaderSelectionAndFloatingAnnotationEntry() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "AI 修改更可控", in: document)
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "核心价值" })

        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        state.selectHeading(heading)

        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertEqual(state.currentReadingHeadingID, heading.id)
        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.canCreateAnnotation)
        XCTAssertFalse(state.isAnnotationPopoverPresented)
    }

    func testSelectingHeadingClearsExistingAnnotationSelectionWarning() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "核心价值", in: document)
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "核心价值" })

        state.updateSelection(selection)
        state.createAnnotation(comment: "这条批注已经存在。", quickPrompts: [])
        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertEqual(state.saveState, .failed("该选区已有批注，请在右侧卡片编辑原批注。"))

        state.selectHeading(heading)

        XCTAssertNil(state.readerSelection)
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
    }

    func testSelectingHeadingClearsAnchorLostSelectionWarning() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "核心价值", in: document)
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "核心价值" })
        state.updateSelection(selection)
        state.createAnnotation(comment: "这条批注可以定位。", quickPrompts: [])

        var session = try XCTUnwrap(state.reviewSession)
        var lostAnchor = try XCTUnwrap(session.notes.first?.anchor)
        lostAnchor.selectedText = "这段原文已经移动"
        lostAnchor.normalizedSelectedText = "这段原文已经移动"
        lostAnchor.renderedRange = nil
        session.notes.append(ReviewNote(
            id: "note_002",
            status: .anchorLost,
            anchor: lostAnchor,
            comment: "这条批注需要重新确认。"
        ))
        state.reviewSession = session

        state.selectNote(id: "note_002")
        XCTAssertEqual(state.saveState, .failed("该批注的原文位置需要重新确认。"))

        state.selectHeading(heading)

        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertEqual(state.saveState, .saving)
        XCTAssertNil(AnnotationActionStatusPresentation.presentation(for: state.saveState))
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

    func testPendingHeadingTargetIgnoresIntermediateVisibleHeadingFromPreviousSection() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample_prd.md")
        try sampleSource().write(to: sourceURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: sourceURL)
        let document = try XCTUnwrap(state.currentDocument)
        let previousHeading = try XCTUnwrap(document.outline.flattened().first { $0.title == "示例 PRD" })
        let targetHeading = try XCTUnwrap(document.outline.flattened().first { $0.title == "核心价值" })

        state.selectHeading(targetHeading)
        XCTAssertEqual(state.scrollTargetHeadingID, targetHeading.id)
        XCTAssertEqual(state.currentReadingHeadingID, targetHeading.id)

        state.updateVisibleHeading(previousHeading.id)

        XCTAssertEqual(state.scrollTargetHeadingID, targetHeading.id)
        XCTAssertEqual(state.currentReadingHeadingID, targetHeading.id)

        state.clearScrollTarget(headingID: targetHeading.id, range: nil)
        state.updateVisibleHeading(previousHeading.id)

        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertEqual(state.currentReadingHeadingID, previousHeading.id)
    }

    func testOpeningAnotherDocumentFlushesPendingAnnotationAutosaveForPreviousDocument() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleSource(title: "第一份", heading: "核心价值")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "后续文档")
            .write(to: secondURL, atomically: true, encoding: .utf8)

        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )

        state.openDocument(at: firstURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "切换文档前也要保留这条批注。", quickPrompts: [])

        state.openDocument(at: secondURL)
        try await Task.sleep(nanoseconds: 500_000_000)

        let firstDocument = try DocumentLoader().loadDocument(from: firstURL)
        let firstSession = ReviewSessionStore(locator: locator).loadSessionResult(for: firstDocument).session
        XCTAssertEqual(firstSession.notes.first?.comment, "切换文档前也要保留这条批注。")
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: firstURL).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: secondURL).path))
    }

    func testOpeningAnotherDocumentDoesNotHidePendingAnnotationAutosaveFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "第一份", heading: "保存失败")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "不能覆盖失败")
            .write(to: secondURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: firstURL)
        let sidecarURL = locator.reviewSessionURL(for: firstURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "打开其他文档前必须保存失败可见。", quickPrompts: [])
        XCTAssertEqual(state.saveState, .saving)

        state.openDocument(at: secondURL)

        XCTAssertEqual(state.currentDocument?.displayName, "first.md")
        guard case let .failed(message) = state.saveState else {
            return XCTFail("Expected sidecar save failure, got \(state.saveState).")
        }
        XCTAssertTrue(message.hasPrefix("批注保存失败，已暂停打开/导入以避免丢失批注："))
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(for: state.saveState, hasOpenDocument: true),
            ReaderStatusBannerPresentation(
                title: "导入未完成",
                message: "\(message)当前文档仍保持打开。",
                systemImage: "exclamationmark.triangle",
                copyTitle: "复制详情",
                copyHelp: "复制完整失败详情；不会隐藏保存失败",
                copyValue: "\(message)当前文档仍保持打开。"
            )
        )
    }

    func testOpeningAnotherDocumentDoesNotBypassExplicitAnnotationSaveFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "第一份", heading: "保存失败")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "不能越过失败")
            .write(to: secondURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: firstURL)
        let sidecarURL = locator.reviewSessionURL(for: firstURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "手动保存失败后也不能继续打开。", quickPrompts: [])

        state.saveReviewSessionNow()
        guard case let .failed(saveFailureMessage) = state.saveState else {
            return XCTFail("Expected sidecar save failure, got \(state.saveState).")
        }
        XCTAssertTrue(saveFailureMessage.hasPrefix("批注保存失败："))

        XCTAssertFalse(state.openDocument(at: secondURL))

        XCTAssertEqual(state.currentDocument?.displayName, "first.md")
        XCTAssertEqual(state.reviewSession?.notes.first?.comment, "手动保存失败后也不能继续打开。")
        guard case let .failed(blockedMessage) = state.saveState else {
            return XCTFail("Expected blocked import failure, got \(state.saveState).")
        }
        XCTAssertTrue(blockedMessage.hasPrefix("批注保存失败，已暂停打开/导入以避免丢失批注："))
    }

    func testUnsupportedImportDoesNotHideExplicitAnnotationSaveFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        let unsupportedURL = temp.appendingPathComponent("notes.txt")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: activeURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: unsupportedURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: activeURL)
        let sidecarURL = locator.reviewSessionURL(for: activeURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "拖错文件也不能盖掉保存失败。", quickPrompts: [])
        state.saveReviewSessionNow()
        guard case let .failed(saveFailureMessage) = state.saveState else {
            return XCTFail("Expected sidecar save failure, got \(state.saveState).")
        }
        XCTAssertTrue(saveFailureMessage.hasPrefix("批注保存失败："))

        XCTAssertFalse(state.openFirstSupportedDocument(at: [unsupportedURL]))

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.reviewSession?.notes.first?.comment, "拖错文件也不能盖掉保存失败。")
        guard case let .failed(blockedMessage) = state.saveState else {
            return XCTFail("Expected blocked import failure, got \(state.saveState).")
        }
        XCTAssertTrue(blockedMessage.hasPrefix("批注保存失败，已暂停打开/导入以避免丢失批注："))
    }

    func testUnsupportedDroppedItemsDoNotHideExplicitAnnotationSaveFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: activeURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: activeURL)
        let sidecarURL = locator.reviewSessionURL(for: activeURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "拖错内容也不能盖掉保存失败。", quickPrompts: [])
        state.saveReviewSessionNow()
        guard case let .failed(saveFailureMessage) = state.saveState else {
            return XCTFail("Expected sidecar save failure, got \(state.saveState).")
        }
        XCTAssertTrue(saveFailureMessage.hasPrefix("批注保存失败："))

        XCTAssertFalse(state.openDroppedDocument(from: [NSItemProvider(object: "plain text" as NSString)]))

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.reviewSession?.notes.first?.comment, "拖错内容也不能盖掉保存失败。")
        guard case let .failed(blockedMessage) = state.saveState else {
            return XCTFail("Expected blocked import failure, got \(state.saveState).")
        }
        XCTAssertTrue(blockedMessage.hasPrefix("批注保存失败，已暂停打开/导入以避免丢失批注："))
    }

    func testPromptActionsDoNotHideAnnotationSaveFailure() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: sourceURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        state.openDocument(at: sourceURL)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "Prompt 可以生成，但批注必须继续提醒保存失败。", quickPrompts: [])
        XCTAssertFalse(state.promptPreview.prompt.isEmpty)

        state.saveReviewSessionNow()
        let copyFailureState = state.saveState
        guard case let .failed(copyFailureMessage) = copyFailureState else {
            return XCTFail("Expected annotation save failure, got \(copyFailureState).")
        }
        XCTAssertTrue(copyFailureMessage.hasPrefix("批注保存失败："))

        state.copyPromptToPasteboard()

        XCTAssertEqual(state.saveState, copyFailureState)

        state.saveReviewSessionNow()
        let promptSaveFailureState = state.saveState
        guard case let .failed(promptSaveFailureMessage) = promptSaveFailureState else {
            return XCTFail("Expected annotation save failure, got \(promptSaveFailureState).")
        }
        XCTAssertTrue(promptSaveFailureMessage.hasPrefix("批注保存失败："))

        state.savePromptToDisk()

        XCTAssertEqual(state.saveState, promptSaveFailureState)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.promptURL(for: sourceURL).path))
    }

    func testSavingPromptFlushesPendingAnnotationAutosave() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "Prompt 保存")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "Prompt 保存前也要同步批注。", quickPrompts: [])

        XCTAssertEqual(state.saveState, .saving)
        XCTAssertFalse(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: sourceURL).path))

        state.savePromptToDisk()

        XCTAssertEqual(state.saveState, .promptSaved(locator.promptURL(for: sourceURL).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.promptURL(for: sourceURL).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: sourceURL).path))

        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let restoredSession = ReviewSessionStore(locator: locator).loadSessionResult(for: document).session

        XCTAssertEqual(restoredSession.notes.count, 1)
        XCTAssertEqual(restoredSession.notes.first?.comment, "Prompt 保存前也要同步批注。")
    }

    func testCopyingPromptFlushesPendingAnnotationAutosave() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "Prompt 复制")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "Prompt 复制前也要同步批注。", quickPrompts: [])
        let prompt = state.promptPreview.prompt

        XCTAssertEqual(state.saveState, .saving)
        XCTAssertFalse(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: sourceURL).path))

        NSPasteboard.general.clearContents()
        state.copyPromptToPasteboard()

        XCTAssertEqual(state.saveState, .copied)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), prompt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: sourceURL).path))

        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let restoredSession = ReviewSessionStore(locator: locator).loadSessionResult(for: document).session

        XCTAssertEqual(restoredSession.notes.count, 1)
        XCTAssertEqual(restoredSession.notes.first?.comment, "Prompt 复制前也要同步批注。")
    }

    func testCopyingPromptReportsReviewFallbackWhenPendingAutosaveUsesFallback() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "Prompt 复制")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        state.openDocument(at: sourceURL)
        try FileManager.default.createDirectory(
            at: locator.reviewSessionURL(for: sourceURL),
            withIntermediateDirectories: true
        )
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "复制前 fallback 保存也要可见。", quickPrompts: [])
        let fallbackURL = locator.fallbackReviewSessionURL(for: sourceURL)

        state.copyPromptToPasteboard()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fallbackURL.path))
        let presentation = try XCTUnwrap(AnnotationActionStatusPresentation.presentation(for: state.saveState))
        XCTAssertTrue(presentation.message.contains("Prompt 已复制"))
        XCTAssertTrue(presentation.message.contains("批注已保存到应用数据目录"))
        XCTAssertTrue(presentation.message.contains(fallbackURL.path))
    }

    func testSavingPromptReportsReviewFallbackWhenPendingAutosaveUsesFallback() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "Prompt 保存")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        state.openDocument(at: sourceURL)
        try FileManager.default.createDirectory(
            at: locator.reviewSessionURL(for: sourceURL),
            withIntermediateDirectories: true
        )
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "保存 Prompt 前 fallback 保存也要可见。", quickPrompts: [])
        let fallbackURL = locator.fallbackReviewSessionURL(for: sourceURL)
        let promptURL = locator.promptURL(for: sourceURL)

        state.savePromptToDisk()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fallbackURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: promptURL.path))
        let presentation = try XCTUnwrap(AnnotationActionStatusPresentation.presentation(for: state.saveState))
        XCTAssertTrue(presentation.message.contains("Prompt 已保存：\(promptURL.path)"))
        XCTAssertTrue(presentation.message.contains("批注已保存到应用数据目录"))
        XCTAssertTrue(presentation.message.contains(fallbackURL.path))
    }

    func testPromptSaveFailureReportsReviewFallbackWhenPendingAutosaveUsesFallback() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "Prompt 保存失败")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        state.openDocument(at: sourceURL)
        try FileManager.default.createDirectory(
            at: locator.reviewSessionURL(for: sourceURL),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: locator.promptURL(for: sourceURL),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: locator.fallbackPromptURL(for: sourceURL),
            withIntermediateDirectories: true
        )
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "Prompt 保存失败也要说明批注保存位置。", quickPrompts: [])
        let fallbackReviewURL = locator.fallbackReviewSessionURL(for: sourceURL)

        state.savePromptToDisk()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fallbackReviewURL.path))
        let presentation = try XCTUnwrap(AnnotationActionStatusPresentation.presentation(for: state.saveState))
        XCTAssertTrue(presentation.isFailure)
        XCTAssertTrue(presentation.message.contains("Prompt 保存失败"))
        XCTAssertTrue(presentation.message.contains("批注已保存到应用数据目录"))
        XCTAssertTrue(presentation.message.contains(fallbackReviewURL.path))
    }

    func testPromptSaveFailureShowsPrimaryAndFallbackPromptPaths() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "Prompt 保存失败")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let state = AppState(
            reviewSessionStore: ReviewSessionStore(locator: locator),
            promptFileStore: PromptFileStore(locator: locator)
        )
        state.openDocument(at: sourceURL)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "保存失败时要知道 Prompt 路径。", quickPrompts: [])
        state.saveReviewSessionNow()

        let promptURL = locator.promptURL(for: sourceURL)
        let fallbackPromptURL = locator.fallbackPromptURL(for: sourceURL)
        try FileManager.default.createDirectory(at: promptURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fallbackPromptURL, withIntermediateDirectories: true)

        state.savePromptToDisk()

        let presentation = try XCTUnwrap(AnnotationActionStatusPresentation.presentation(for: state.saveState))
        XCTAssertTrue(presentation.isFailure)
        XCTAssertTrue(presentation.message.contains("Prompt 保存失败"))
        XCTAssertTrue(presentation.message.contains(promptURL.path))
        XCTAssertTrue(presentation.message.contains(fallbackPromptURL.path))
    }

    func testExcludingNoteAfterAnnotationSaveFailureKeepsFailureVisibleAndRefreshesPrompt() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: sourceURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: sourceURL)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "保存失败时排除也要继续提醒。", quickPrompts: [])
        XCTAssertFalse(state.promptPreview.prompt.isEmpty)

        state.saveReviewSessionNow()
        guard case let .failed(saveFailureMessage) = state.saveState else {
            return XCTFail("Expected annotation save failure, got \(state.saveState).")
        }
        XCTAssertTrue(saveFailureMessage.hasPrefix("批注保存失败："))

        state.setNoteIncluded(id: "note_001", includeInPrompt: false)

        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        guard case let .failed(visibleFailureMessage) = state.saveState else {
            return XCTFail("Expected annotation save failure to remain visible, got \(state.saveState).")
        }
        XCTAssertTrue(visibleFailureMessage.hasPrefix("批注保存失败："))
    }

    func testSelectingAnchorLostNoteAfterAnnotationSaveFailureKeepsFailureVisible() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: sourceURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: sourceURL)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "保存失败时定位其他批注也要继续提醒。", quickPrompts: [])
        var session = try XCTUnwrap(state.reviewSession)
        var lostAnchor = try XCTUnwrap(session.notes.first?.anchor)
        lostAnchor.selectedText = "这段原文已经移动"
        lostAnchor.normalizedSelectedText = TextNormalizer.normalized("这段原文已经移动")
        lostAnchor.renderedRange = nil
        session.notes.append(ReviewNote(
            id: "note_002",
            status: .anchorLost,
            anchor: lostAnchor,
            comment: "这条批注需要重新确认。"
        ))
        state.reviewSession = session

        state.saveReviewSessionNow()
        guard case let .failed(saveFailureMessage) = state.saveState else {
            return XCTFail("Expected annotation save failure, got \(state.saveState).")
        }
        XCTAssertTrue(saveFailureMessage.hasPrefix("批注保存失败："))

        state.selectNote(id: "note_002")

        XCTAssertEqual(state.selectedNoteID, "note_002")
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(state.saveState, .failed(saveFailureMessage))
    }

    func testEditingAfterAnnotationSaveFailureDoesNotStartBackgroundAutosaveRetry() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: sourceURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: sourceURL)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "保存失败后排除也不应后台反复保存。", quickPrompts: [])
        state.saveReviewSessionNow()
        guard case let .failed(saveFailureMessage) = state.saveState else {
            return XCTFail("Expected annotation save failure, got \(state.saveState).")
        }
        XCTAssertTrue(saveFailureMessage.hasPrefix("批注保存失败："))

        state.setNoteIncluded(id: "note_001", includeInPrompt: false)
        let editedSessionUpdatedAt = try XCTUnwrap(state.reviewSession?.updatedAt)
        let visibleFailureState = state.saveState
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)

        try await Task.sleep(nanoseconds: 520_000_000)

        XCTAssertEqual(state.reviewSession?.updatedAt, editedSessionUpdatedAt)
        XCTAssertEqual(state.saveState, visibleFailureState)
    }

    func testPendingAnnotationAutosaveFlushesWhenAppStateIsReleased() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "快速关闭")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        do {
            let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
            state.openDocument(at: sourceURL)
            let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
            state.updateSelection(selection)
            state.createAnnotation(comment: "快速关闭前也要保存。", quickPrompts: [])
            state.setNoteIncluded(id: "note_001", includeInPrompt: false)

            XCTAssertEqual(state.saveState, .saving)
            XCTAssertTrue(state.promptPreview.prompt.isEmpty)
        }

        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let restoredSession = ReviewSessionStore(locator: locator).loadSessionResult(for: document).session

        XCTAssertEqual(restoredSession.notes.count, 1)
        XCTAssertEqual(restoredSession.notes.first?.comment, "快速关闭前也要保存。")
        XCTAssertEqual(restoredSession.notes.first?.includeInPrompt, false)
    }

    func testClosingCurrentDocumentFlushesAutosaveAndClearsDocumentState() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "关闭文档")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        XCTAssertFalse(state.closeCurrentDocument())
        XCTAssertTrue(state.openDocument(at: sourceURL))
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "核心价值", in: document)
        state.updateSelection(selection)
        state.createAnnotation(comment: "关闭当前文档前保存。", quickPrompts: [])

        XCTAssertEqual(state.saveState, .saving)
        XCTAssertFalse(state.promptPreview.prompt.isEmpty)
        XCTAssertNotNil(state.reviewSession)
        XCTAssertNotNil(state.selectedNoteID)
        XCTAssertNotNil(state.scrollTargetRange)

        XCTAssertTrue(state.closeCurrentDocument())

        XCTAssertNil(state.currentDocument)
        XCTAssertNil(state.reviewSession)
        XCTAssertNil(state.readerSelection)
        XCTAssertNil(state.selectedNoteID)
        XCTAssertEqual(state.promptPreview, .empty)
        XCTAssertEqual(state.saveState, .idle)
        XCTAssertEqual(state.panelMode, .annotations)
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertNil(state.currentReadingHeadingID)
        XCTAssertFalse(state.isAnnotationPopoverPresented)

        let restoredSession = ReviewSessionStore(locator: locator).loadSessionResult(for: document).session
        XCTAssertEqual(restoredSession.notes.count, 1)
        XCTAssertEqual(restoredSession.notes.first?.comment, "关闭当前文档前保存。")
    }

    func testClosingCurrentDocumentKeepsDocumentWhenAnnotationSaveFails() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: sourceURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        XCTAssertTrue(state.openDocument(at: sourceURL))
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)
        state.createAnnotation(comment: "保存失败时不能关闭。", quickPrompts: [])

        state.saveReviewSessionNow()
        let failureState = state.saveState
        guard case let .failed(message) = failureState else {
            return XCTFail("Expected sidecar save failure, got \(failureState).")
        }
        XCTAssertTrue(message.hasPrefix("批注保存失败："))

        XCTAssertFalse(state.closeCurrentDocument())

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.reviewSession?.notes.first?.comment, "保存失败时不能关闭。")
        XCTAssertEqual(state.saveState, failureState)
    }

    func testStaleSelectionFromPreviousDocumentDoesNotPolluteNewDocument() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try """
        # 第一份

        旧文档唯一选区文本，只属于第一份 Markdown。
        """
        .write(to: firstURL, atomically: true, encoding: .utf8)
        try """
        # 第二份

        第二篇文档用于继续阅读，不能接收第一份的迟到选区。
        """
        .write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let staleSelection = try makeSelection(text: "旧文档唯一选区文本", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(staleSelection)
        XCTAssertTrue(state.canCreateAnnotation)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)

        state.updateSelection(staleSelection)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.canCreateAnnotation)
        XCTAssertEqual(state.scrollTargetHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
    }

    func testStaleSelectionFromPreviousDocumentWithSameTextDoesNotPolluteNewDocument() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        let sharedSource = """
        # 相同内容

        共享选区文本在两个文档里位置完全一致。
        """
        try sharedSource.write(to: firstURL, atomically: true, encoding: .utf8)
        try sharedSource.write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let staleSelection = try makeSelection(text: "共享选区文本", in: firstDocument)
        state.updateSelection(staleSelection, from: firstDocument.id)
        XCTAssertTrue(state.canCreateAnnotation)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)

        state.updateSelection(staleSelection, from: firstDocument.id)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertNil(state.readerSelection)
        XCTAssertFalse(state.canCreateAnnotation)
        XCTAssertEqual(state.scrollTargetHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetRange)
    }

    func testStaleVisibleHeadingFromPreviousDocumentDoesNotPolluteNewDocument() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleSource(title: "第一份", heading: "旧文档章节")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "新文档章节")
            .write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let staleHeading = try XCTUnwrap(firstDocument.outline.flattened().last)
        state.updateVisibleHeading(staleHeading.id)
        XCTAssertEqual(state.currentReadingHeadingID, staleHeading.id)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)

        state.updateVisibleHeading(staleHeading.id)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertEqual(state.currentReadingHeadingID, topHeading.id)
        XCTAssertEqual(state.scrollTargetHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetRange)
    }

    func testStaleSelectedHeadingFromPreviousDocumentDoesNotPolluteNewDocument() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleSource(title: "第一份", heading: "旧文档章节")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "新文档章节")
            .write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let staleHeading = try XCTUnwrap(firstDocument.outline.flattened().last)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)

        state.selectHeading(staleHeading)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertEqual(state.currentReadingHeadingID, topHeading.id)
        XCTAssertEqual(state.scrollTargetHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetRange)
    }

    func testStaleNilVisibleHeadingFromPreviousDocumentDoesNotClearNewDocumentTopHeading() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleSource(title: "第一份", heading: "旧文档章节")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "新文档章节")
            .write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let staleHeading = try XCTUnwrap(firstDocument.outline.flattened().last)
        state.updateVisibleHeading(staleHeading.id)
        XCTAssertEqual(state.currentReadingHeadingID, staleHeading.id)
        state.clearScrollTargets()
        state.updateVisibleHeading(nil)
        XCTAssertNil(state.currentReadingHeadingID)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)

        state.updateVisibleHeading(nil)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertEqual(state.currentReadingHeadingID, topHeading.id)
        XCTAssertEqual(state.scrollTargetHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetRange)
    }

    func testStaleNilVisibleHeadingAfterNewDocumentTargetIsConsumedDoesNotClearNewDocumentHeading() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleSource(title: "第一份", heading: "旧文档章节")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "新文档章节")
            .write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        state.clearScrollTargets()
        state.updateVisibleHeading(nil, from: firstDocument.id)
        XCTAssertNil(state.currentReadingHeadingID)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)
        state.clearScrollTarget(headingID: topHeading.id, range: nil, from: secondDocument.id)
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertEqual(state.currentReadingHeadingID, topHeading.id)

        state.updateVisibleHeading(nil, from: firstDocument.id)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertEqual(state.currentReadingHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertNil(state.scrollTargetRange)
    }

    func testStaleScrollTargetConsumptionFromPreviousDocumentDoesNotClearNewDocumentTopTarget() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleSource(title: "第一份", heading: "旧文档章节")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "新文档章节")
            .write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let staleHeading = try XCTUnwrap(firstDocument.outline.flattened().first)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)

        state.clearScrollTarget(headingID: staleHeading.id, range: nil)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertEqual(state.scrollTargetHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(state.currentReadingHeadingID, topHeading.id)
    }

    func testStaleRangeConsumptionFromPreviousDocumentDoesNotClearNewDocumentRangeTarget() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        let sharedSource = """
        # 相同内容

        共享定位文本在两个文档里位置完全一致。
        """
        try sharedSource.write(to: firstURL, atomically: true, encoding: .utf8)
        try sharedSource.write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState()

        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let firstSelection = try makeSelection(text: "共享定位文本", in: firstDocument)
        state.updateSelection(firstSelection, from: firstDocument.id)
        state.createAnnotation(comment: "第一份文档的批注定位。", quickPrompts: [])
        let staleRange = try XCTUnwrap(state.scrollTargetRange)

        state.openDocument(at: secondURL)
        let secondDocument = try XCTUnwrap(state.currentDocument)
        let secondSelection = try makeSelection(text: "共享定位文本", in: secondDocument)
        state.updateSelection(secondSelection, from: secondDocument.id)
        state.createAnnotation(comment: "第二份文档的批注定位。", quickPrompts: [])
        let currentRange = try XCTUnwrap(state.scrollTargetRange)
        XCTAssertEqual(currentRange, staleRange)

        state.clearScrollTarget(headingID: nil, range: staleRange, from: firstDocument.id)

        XCTAssertEqual(state.currentDocument?.displayName, "second.md")
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertEqual(state.scrollTargetRange, currentRange)
        XCTAssertEqual(state.selectedNoteID, "note_001")
    }

    func testOpeningDocumentRequestsReaderScrollToTopHeading() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleSource(title: "第一份", heading: "核心价值")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "第二份", heading: "导入后顶部")
            .write(to: secondURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let firstHeading = try XCTUnwrap(firstDocument.outline.flattened().last)
        state.selectHeading(firstHeading)
        XCTAssertEqual(state.scrollTargetHeadingID, firstHeading.id)

        state.openDocument(at: secondURL)

        let secondDocument = try XCTUnwrap(state.currentDocument)
        let topHeading = try XCTUnwrap(secondDocument.outline.flattened().first)
        XCTAssertEqual(state.currentReadingHeadingID, topHeading.id)
        XCTAssertEqual(state.scrollTargetHeadingID, topHeading.id)
        XCTAssertNil(state.scrollTargetRange)
    }

    func testOpeningDocumentWithoutHeadingsRequestsReaderScrollToTopRange() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("plain.md")
        try sampleSource(title: "第一份", heading: "核心价值")
            .write(to: firstURL, atomically: true, encoding: .utf8)
        try "Plain introduction without headings.\n\nMore reader text."
            .write(to: secondURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: firstURL)
        let firstDocument = try XCTUnwrap(state.currentDocument)
        let firstHeading = try XCTUnwrap(firstDocument.outline.flattened().last)
        state.selectHeading(firstHeading)

        state.openDocument(at: secondURL)

        XCTAssertNil(state.currentReadingHeadingID)
        XCTAssertNil(state.scrollTargetHeadingID)
        XCTAssertEqual(state.scrollTargetRange, RenderedTextRange(location: 0, length: 0))
    }

    func testOpenFirstSupportedDocumentSkipsUnsupportedDroppedFiles() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let textURL = temp.appendingPathComponent("notes.txt")
        let markdownURL = temp.appendingPathComponent("imported.markdown")
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "拖拽导入", heading: "Markdown")
            .write(to: markdownURL, atomically: true, encoding: .utf8)

        let state = AppState()
        XCTAssertTrue(state.openFirstSupportedDocument(at: [textURL, markdownURL]))

        XCTAssertEqual(state.currentDocument?.displayName, "imported.markdown")
        XCTAssertEqual(state.saveState, .loaded)
    }

    func testOpenFirstSupportedDocumentSkipsUnreadableMarkdownCandidates() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let unreadableMarkdownURL = temp.appendingPathComponent("broken.md", isDirectory: true)
        let markdownURL = temp.appendingPathComponent("imported.markdown")
        try FileManager.default.createDirectory(at: unreadableMarkdownURL, withIntermediateDirectories: true)
        try sampleSource(title: "拖拽导入", heading: "可读取文档")
            .write(to: markdownURL, atomically: true, encoding: .utf8)

        let state = AppState()
        XCTAssertTrue(state.openFirstSupportedDocument(at: [unreadableMarkdownURL, markdownURL]))

        XCTAssertEqual(state.currentDocument?.displayName, "imported.markdown")
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertEqual(state.currentReadingHeadingID, state.currentDocument?.outline.flattened().first?.id)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
    }

    func testOpenFirstSupportedDocumentPreservesAnnotationEntryWhenAllMarkdownCandidatesAreUnreadable() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        let brokenMarkdownURL = temp.appendingPathComponent("broken.md", isDirectory: true)
        let brokenMarkdownLongURL = temp.appendingPathComponent("broken.markdown", isDirectory: true)
        try sampleSource(title: "正在阅读", heading: "保留文档")
            .write(to: activeURL, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: brokenMarkdownURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: brokenMarkdownLongURL, withIntermediateDirectories: true)

        let state = AppState()
        state.openDocument(at: activeURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        XCTAssertFalse(state.openFirstSupportedDocument(at: [brokenMarkdownURL, brokenMarkdownLongURL]))

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertTrue(state.isAnnotationPopoverPresented)
        guard case let .failed(message) = state.saveState else {
            return XCTFail("Expected aggregated import failure, got \(state.saveState).")
        }
        XCTAssertTrue(message.hasPrefix("无法读取拖入的文件（已尝试 2 个 Markdown）："))
        XCTAssertTrue(message.contains("broken.md"))

        state.createAnnotation(comment: "导入失败后继续保存当前批注。", quickPrompts: [])

        XCTAssertEqual(state.reviewSession?.notes.first?.comment, "导入失败后继续保存当前批注。")
        XCTAssertTrue(state.promptPreview.prompt.contains("导入失败后继续保存当前批注。"))
    }

    func testOpenFirstSupportedDocumentFailurePreservesTransientAnnotationEntry() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let textURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "保留文档")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        XCTAssertFalse(state.openFirstSupportedDocument(at: [textURL]))

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertTrue(state.isAnnotationPopoverPresented)
        XCTAssertEqual(state.saveState, .failed("请拖入 .md 或 .markdown 文件。"))
    }

    func testDismissingTransientImportFailureRestoresNeutralStateOnlyForImportFailures() throws {
        let state = AppState()
        XCTAssertFalse(state.openFirstSupportedDocument(at: []))
        XCTAssertEqual(state.saveState, .failed("请拖入 .md 或 .markdown 文件。"))

        state.dismissTransientImportFailure()

        XCTAssertEqual(state.saveState, .idle)

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        let unsupportedURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "保留文档")
            .write(to: sourceURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: unsupportedURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(state.openDocument(at: sourceURL))
        XCTAssertFalse(state.openDocument(at: unsupportedURL))
        XCTAssertEqual(
            state.saveState,
            .failed("只能打开 .md 或 .markdown 文件，当前文件类型为 .txt。")
        )

        state.dismissTransientImportFailure()

        XCTAssertEqual(state.saveState, .loaded)

        state.saveState = .failed("批注保存失败：磁盘已满")
        state.dismissTransientImportFailure()

        XCTAssertEqual(state.saveState, .failed("批注保存失败：磁盘已满"))
    }

    func testFailedImportBannerClarifiesCurrentDocumentRemainsOpen() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let textURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "保留文档")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        XCTAssertEqual(state.currentDocument?.displayName, "active.md")

        state.openDocument(at: textURL)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        let banner = ReaderStatusBannerPresentation.presentation(
            for: state.saveState,
            hasOpenDocument: state.currentDocument != nil
        )
        XCTAssertEqual(banner?.title, "导入未完成")
        XCTAssertEqual(
            banner?.message,
            "只能打开 .md 或 .markdown 文件，当前文件类型为 .txt。当前文档仍保持打开。"
        )
    }

    func testFailedImportBannerExplainsFilesWithoutExtension() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let extensionlessURL = temp.appendingPathComponent("README")
        try sampleSource(title: "正在阅读", heading: "保留文档")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "# Missing extension".write(to: extensionlessURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        XCTAssertEqual(state.currentDocument?.displayName, "active.md")

        state.openDocument(at: extensionlessURL)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        let banner = ReaderStatusBannerPresentation.presentation(
            for: state.saveState,
            hasOpenDocument: state.currentDocument != nil
        )
        XCTAssertEqual(banner?.title, "导入未完成")
        XCTAssertEqual(
            banner?.message,
            "只能打开 .md 或 .markdown 文件，当前文件没有扩展名。当前文档仍保持打开。"
        )
    }

    func testFailedImportPreservesTransientAnnotationEntryWhileKeepingCurrentDocumentOpen() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let textURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "保留文档")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(selection)
        state.beginAnnotationFromCurrentSelection()
        XCTAssertTrue(state.isAnnotationPopoverPresented)

        state.openDocument(at: textURL)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertTrue(state.isAnnotationPopoverPresented)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )?.title,
            "导入未完成"
        )
    }

    func testSelectingTextAfterFailedImportClearsStaleImportBanner() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let textURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "继续批注")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        let document = try XCTUnwrap(state.currentDocument)

        state.openDocument(at: textURL)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )?.title,
            "导入未完成"
        )

        let selection = try makeSelection(text: "AI 修改更可控", in: document)
        state.updateSelection(selection)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertNil(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )
        )
    }

    func testSelectingExistingNoteAfterFailedImportClearsStaleImportBanner() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let textURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "继续定位")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        let document = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "核心价值", in: document)
        state.updateSelection(selection)
        state.createAnnotation(comment: "这条批注需要继续定位。", quickPrompts: [])
        state.saveReviewSessionNow()

        state.openDocument(at: textURL)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )?.title,
            "导入未完成"
        )

        state.selectNote(id: "note_001")

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.selectedNoteID, "note_001")
        XCTAssertEqual(state.scrollTargetRange, selection.renderedRange)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertNil(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )
        )
    }

    func testSelectingHeadingAfterFailedImportClearsStaleImportBanner() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let textURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "继续阅读")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        let document = try XCTUnwrap(state.currentDocument)
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "继续阅读" })
        state.clearScrollTargets()

        state.openDocument(at: textURL)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )?.title,
            "导入未完成"
        )

        state.selectHeading(heading)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(state.currentReadingHeadingID, heading.id)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertNil(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )
        )
    }

    func testSelectingTextAfterSidecarLoadWarningClearsReaderBanner() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "正在阅读", heading: "继续批注")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "{ invalid review json".write(
            to: locator.reviewSessionURL(for: markdownURL),
            atomically: true,
            encoding: .utf8
        )

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: markdownURL)
        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )?.title,
            "批注未恢复"
        )

        let selection = try makeSelection(text: "核心价值", in: XCTUnwrap(state.currentDocument))
        state.updateSelection(selection)

        XCTAssertEqual(state.readerSelection, selection)
        XCTAssertTrue(state.canCreateAnnotation)
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertNil(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )
        )
    }

    func testFailedImportPreservesPendingScrollTargetsWhileKeepingCurrentDocumentOpen() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let markdownURL = temp.appendingPathComponent("active.md")
        let textURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "正在阅读", heading: "保留文档")
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: markdownURL)
        let document = try XCTUnwrap(state.currentDocument)
        let heading = try XCTUnwrap(document.outline.flattened().first { $0.title == "保留文档" })
        state.selectHeading(heading)
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)

        state.openDocument(at: textURL)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.scrollTargetHeadingID, heading.id)
        XCTAssertNil(state.scrollTargetRange)
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )?.title,
            "导入未完成"
        )
    }

    func testDroppedFileProvidersOpenMarkdownEvenWhenUnsupportedFileIsFirst() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let textURL = temp.appendingPathComponent("notes.txt")
        let markdownURL = temp.appendingPathComponent("dropped.markdown")
        try "plain text".write(to: textURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "拖拽导入", heading: "Markdown")
            .write(to: markdownURL, atomically: true, encoding: .utf8)

        let state = AppState()
        let textProvider = try XCTUnwrap(NSItemProvider(contentsOf: textURL))
        let markdownProvider = try XCTUnwrap(NSItemProvider(contentsOf: markdownURL))

        XCTAssertTrue(state.openDroppedDocument(from: [textProvider, markdownProvider]))
        try await waitUntil(timeout: 1.0) {
            state.currentDocument?.displayName == "dropped.markdown"
        }

        XCTAssertEqual(state.currentDocument?.displayName, "dropped.markdown")
        XCTAssertEqual(state.saveState, .loaded)
    }

    func testDroppedFileProviderShowsLoadingWhileFileURLIsResolving() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        let droppedURL = temp.appendingPathComponent("delayed-drop.md")
        try sampleSource(title: "当前阅读", heading: "继续保留")
            .write(to: activeURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "拖拽导入", heading: "等待解析")
            .write(to: droppedURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: activeURL)
        XCTAssertEqual(state.saveState, .loaded)

        XCTAssertTrue(state.openDroppedDocument(from: [delayedFileURLProvider(for: droppedURL, delay: 0.18)]))

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.saveState, .loading)

        try await waitUntil(timeout: 1.0) {
            state.currentDocument?.displayName == "delayed-drop.md"
        }
        XCTAssertEqual(state.saveState, .loaded)
    }

    func testDroppedFileProviderKeepsLoadingWhilePendingAnnotationAutosaveIsFlushed() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        let droppedURL = temp.appendingPathComponent("delayed-drop.md")
        let supportURL = temp.appendingPathComponent("Support", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "带未保存批注")
            .write(to: activeURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "拖拽导入", heading: "等待解析")
            .write(to: droppedURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: activeURL)
        let activeDocument = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "核心价值", in: activeDocument)
        state.updateSelection(selection)
        state.createAnnotation(comment: "拖拽前的批注也要保存。", quickPrompts: [])
        XCTAssertEqual(state.saveState, .saving)

        XCTAssertTrue(state.openDroppedDocument(from: [delayedFileURLProvider(for: droppedURL, delay: 0.8)]))
        try await Task.sleep(nanoseconds: 460_000_000)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.saveState, .loading)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locator.reviewSessionURL(for: activeURL).path))

        try await waitUntil(timeout: 1.0) {
            state.currentDocument?.displayName == "delayed-drop.md"
        }
        XCTAssertEqual(state.saveState, .loaded)
    }

    func testDroppedFileProviderDoesNotHidePendingAnnotationAutosaveFailure() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        let droppedURL = temp.appendingPathComponent("delayed-drop.md")
        let supportURL = temp.appendingPathComponent("Support")
        let locator = SidecarFileLocator(applicationSupportDirectory: supportURL)
        try sampleSource(title: "当前阅读", heading: "保存失败")
            .write(to: activeURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "拖拽导入", heading: "不应覆盖失败")
            .write(to: droppedURL, atomically: true, encoding: .utf8)
        try "fallback root is not a directory".write(to: supportURL, atomically: true, encoding: .utf8)

        let state = AppState(reviewSessionStore: ReviewSessionStore(locator: locator))
        state.openDocument(at: activeURL)
        let sidecarURL = locator.reviewSessionURL(for: activeURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)
        let activeDocument = try XCTUnwrap(state.currentDocument)
        let selection = try makeSelection(text: "核心价值", in: activeDocument)
        state.updateSelection(selection)
        state.createAnnotation(comment: "保存失败时不能继续导入。", quickPrompts: [])
        XCTAssertEqual(state.saveState, .saving)

        XCTAssertFalse(state.openDroppedDocument(from: [delayedFileURLProvider(for: droppedURL, delay: 0.05)]))
        try await Task.sleep(nanoseconds: 160_000_000)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        guard case let .failed(message) = state.saveState else {
            return XCTFail("Expected sidecar save failure, got \(state.saveState).")
        }
        XCTAssertTrue(message.hasPrefix("批注保存失败，已暂停打开/导入以避免丢失批注："))
    }

    func testDroppedFileProviderReportsUnparseableFileURLItems() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        try sampleSource(title: "当前阅读", heading: "继续保留")
            .write(to: activeURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: activeURL)

        XCTAssertTrue(state.openDroppedDocument(from: [unparseableFileURLProvider()]))
        try await waitUntil(timeout: 1.0) {
            if case .failed = state.saveState {
                return true
            }
            return false
        }

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.saveState, .failed("拖拽导入失败：无法读取文件 URL"))
        XCTAssertEqual(
            ReaderStatusBannerPresentation.presentation(
                for: state.saveState,
                hasOpenDocument: state.currentDocument != nil
            )?.message,
            "拖拽导入失败：无法读取文件 URL。当前文档仍保持打开。"
        )
    }

    func testDroppedFileProviderOpensMarkdownFromUTF8PathData() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let droppedURL = temp
            .appendingPathComponent("Folder With Spaces", isDirectory: true)
            .appendingPathComponent("utf8 path drop.markdown")
        try FileManager.default.createDirectory(
            at: droppedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try sampleSource(title: "UTF8 路径拖拽", heading: "可读取文档")
            .write(to: droppedURL, atomically: true, encoding: .utf8)

        let state = AppState()

        XCTAssertTrue(state.openDroppedDocument(from: [utf8PathDataFileURLProvider(for: droppedURL)]))
        try await waitUntil(timeout: 1.0) {
            state.currentDocument?.displayName == "utf8 path drop.markdown"
        }

        XCTAssertEqual(state.currentDocument?.fileURL, droppedURL)
        XCTAssertEqual(state.saveState, .loaded)
    }

    func testDroppedFileProviderOpensMarkdownFromNewlineTerminatedUTF8PathData() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let droppedURL = temp.appendingPathComponent("newline-terminated.markdown")
        try sampleSource(title: "换行路径拖拽", heading: "可读取文档")
            .write(to: droppedURL, atomically: true, encoding: .utf8)

        let state = AppState()

        XCTAssertTrue(state.openDroppedDocument(from: [
            utf8PathDataFileURLProvider(for: droppedURL, trailingText: "\n")
        ]))
        try await waitUntil(timeout: 1.0) {
            state.currentDocument?.displayName == "newline-terminated.markdown"
        }

        XCTAssertEqual(state.currentDocument?.fileURL, droppedURL)
        XCTAssertEqual(state.saveState, .loaded)
    }

    func testDroppedFileProviderOpensMarkdownFromWhitespaceTerminatedUTF8PathData() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let droppedURL = temp.appendingPathComponent("whitespace-terminated.markdown")
        try sampleSource(title: "空白路径拖拽", heading: "可读取文档")
            .write(to: droppedURL, atomically: true, encoding: .utf8)

        let state = AppState()

        XCTAssertTrue(state.openDroppedDocument(from: [
            utf8PathDataFileURLProvider(for: droppedURL, trailingText: " \t")
        ]))
        try await waitUntil(timeout: 1.0) {
            state.currentDocument?.displayName == "whitespace-terminated.markdown"
        }

        XCTAssertEqual(state.currentDocument?.fileURL, droppedURL)
        XCTAssertEqual(state.saveState, .loaded)
    }

    func testLaterDroppedDocumentWinsWhenEarlierDropFinishesAfterIt() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let slowURL = temp.appendingPathComponent("slow.md")
        let latestURL = temp.appendingPathComponent("latest.markdown")
        try sampleSource(title: "旧拖拽", heading: "慢返回")
            .write(to: slowURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "最新拖拽", heading: "应该保留")
            .write(to: latestURL, atomically: true, encoding: .utf8)

        let state = AppState()
        let slowProvider = delayedFileURLProvider(for: slowURL, delay: 0.18)
        let latestProvider = delayedFileURLProvider(for: latestURL, delay: 0)

        XCTAssertTrue(state.openDroppedDocument(from: [slowProvider]))
        XCTAssertTrue(state.openDroppedDocument(from: [latestProvider]))
        try await waitUntil(timeout: 1.0) {
            state.currentDocument?.displayName == "latest.markdown"
        }
        try await Task.sleep(nanoseconds: 320_000_000)

        XCTAssertEqual(state.currentDocument?.displayName, "latest.markdown")
        XCTAssertEqual(state.saveState, .loaded)
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
    }

    func testUnsupportedImportCancelsPendingSlowDrop() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let activeURL = temp.appendingPathComponent("active.md")
        let slowURL = temp.appendingPathComponent("slow.md")
        let unsupportedURL = temp.appendingPathComponent("notes.txt")
        try sampleSource(title: "当前阅读", heading: "继续保留")
            .write(to: activeURL, atomically: true, encoding: .utf8)
        try sampleSource(title: "旧拖拽", heading: "慢返回")
            .write(to: slowURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: unsupportedURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.openDocument(at: activeURL)
        XCTAssertEqual(state.currentDocument?.displayName, "active.md")

        XCTAssertTrue(state.openDroppedDocument(from: [
            delayedFileURLProvider(for: slowURL, delay: 0.18)
        ]))
        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.saveState, .loading)

        XCTAssertFalse(state.openFirstSupportedDocument(at: [unsupportedURL]))
        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.saveState, .failed("请拖入 .md 或 .markdown 文件。"))

        try await Task.sleep(nanoseconds: 360_000_000)

        XCTAssertEqual(state.currentDocument?.displayName, "active.md")
        XCTAssertEqual(state.saveState, .failed("请拖入 .md 或 .markdown 文件。"))
        XCTAssertTrue(state.promptPreview.prompt.isEmpty)
    }

    func testDroppedFileURLResolverTreatsAbsolutePathStringsAsFileURLs() throws {
        let path = "/tmp/MarkPrompt Drag Test/dropped.md"

        XCTAssertEqual(
            DroppedFileURLResolver.fileURL(from: path as NSString),
            URL(fileURLWithPath: path)
        )
        XCTAssertEqual(
            DroppedFileURLResolver.fileURL(from: "file:///tmp/dropped.markdown" as NSString),
            URL(fileURLWithPath: "/tmp/dropped.markdown")
        )
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
            visibleSelectionRect: CGRect(x: 120, y: 120, width: 100, height: 24),
            annotationButtonRect: CGRect(x: 230, y: 116, width: 100, height: 32)
        )
    }

    private func sourceRange(of needle: String, in source: String) -> SourceTextRange? {
        let nsSource = source as NSString
        let range = nsSource.range(of: needle)
        guard range.location != NSNotFound else {
            return nil
        }
        return SourceTextRange(lowerBound: range.location, upperBound: range.location + range.length)
    }

    private func waitUntil(
        timeout: TimeInterval,
        predicate: @escaping @MainActor () -> Bool
    ) async throws {
        let start = Date()
        while !predicate() {
            if Date().timeIntervalSince(start) >= timeout {
                XCTFail("Timed out waiting for condition.")
                return
            }

            try await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    private func delayedFileURLProvider(for url: URL, delay: TimeInterval) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                completion(url.dataRepresentation, nil)
            }
            return Progress(totalUnitCount: 1)
        }
        return provider
    }

    private func utf8PathDataFileURLProvider(for url: URL, trailingText: String = "") -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            completion(Data((url.path + trailingText).utf8), nil)
            return Progress(totalUnitCount: 1)
        }
        return provider
    }

    private func unparseableFileURLProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            completion(Data("not a file url".utf8), nil)
            return Progress(totalUnitCount: 1)
        }
        return provider
    }

    private func sampleSource() -> String {
        """
        # 示例 PRD

        ## 核心价值

        MarkPrompt 的核心价值是让批注更精准，让 AI 修改更可控。
        """
    }

    private func sampleSource(title: String, heading: String) -> String {
        """
        # \(title)

        ## \(heading)

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

    private func mirroredStringField(_ fieldName: String, in value: Any?) -> String? {
        guard let value else {
            return nil
        }

        return Mirror(reflecting: value).children.first { $0.label == fieldName }?.value as? String
    }
}
