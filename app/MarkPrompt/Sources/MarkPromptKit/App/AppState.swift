import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

public enum InspectorPanelMode: String, CaseIterable, Identifiable {
    case annotations
    case prompt

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .annotations:
            return "批注"
        case .prompt:
            return "Prompt"
        }
    }
}

public enum SaveState: Equatable {
    case idle
    case loading
    case loaded
    case saving
    case saved
    case savedToFallback(String)
    case copied
    case copiedWithReviewFallback(String)
    case promptSaved(String)
    case promptSavedToFallback(String)
    case promptSavedWithReviewFallback(promptPath: String, reviewPath: String)
    case promptSavedToFallbackWithReviewFallback(promptPath: String, reviewPath: String)
    case failed(String)

    public var label: String {
        switch self {
        case .idle:
            return "就绪"
        case .loading:
            return "打开中"
        case .loaded:
            return "已打开"
        case .saving:
            return "保存中"
        case .saved:
            return "已保存"
        case let .savedToFallback(path):
            return "已保存到应用数据目录：\(path)"
        case .copied:
            return "已复制"
        case let .copiedWithReviewFallback(path):
            return "Prompt 已复制；批注已保存到应用数据目录：\(path)"
        case let .promptSaved(path):
            return "Prompt 已保存：\(path)"
        case let .promptSavedToFallback(path):
            return "Prompt 已保存到应用数据目录：\(path)"
        case let .promptSavedWithReviewFallback(promptPath, reviewPath):
            return "Prompt 已保存：\(promptPath)；批注已保存到应用数据目录：\(reviewPath)"
        case let .promptSavedToFallbackWithReviewFallback(promptPath, reviewPath):
            return "Prompt 已保存到应用数据目录：\(promptPath)；批注已保存到应用数据目录：\(reviewPath)"
        case let .failed(message):
            return message
        }
    }
}

public struct PromptPreviewState: Equatable, Sendable {
    public var prompt: String
    public var warnings: [String]
    public var includedNoteCount: Int

    public init(prompt: String = "", warnings: [String] = [], includedNoteCount: Int = 0) {
        self.prompt = prompt
        self.warnings = warnings
        self.includedNoteCount = includedNoteCount
    }

    public static let empty = PromptPreviewState()
}

public enum DroppedFileURLResolver {
    public static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return normalizedFileURL(from: url)
        }

        if let data = item as? Data {
            if let string = String(data: data, encoding: .utf8),
               let url = fileURL(from: string) {
                return url
            }
            return URL(dataRepresentation: data, relativeTo: nil).flatMap(normalizedFileURL)
        }

        if let string = item as? String {
            return fileURL(from: string)
        }

        if let string = item as? NSString {
            return fileURL(from: string as String)
        }

        return nil
    }

    private static func fileURL(from string: String) -> URL? {
        let normalizedString = string.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedString.hasPrefix("/") {
            return URL(fileURLWithPath: normalizedString)
        }

        guard let url = URL(string: normalizedString) else {
            return nil
        }

        return normalizedFileURL(from: url)
    }

    private static func normalizedFileURL(from url: URL) -> URL? {
        if url.isFileURL {
            return url
        }

        if url.scheme == nil, url.path.hasPrefix("/") {
            return URL(fileURLWithPath: url.path)
        }

        return nil
    }
}

@MainActor
public final class AppState: ObservableObject {
    private static let existingAnnotationSelectionMessage = "该选区已有批注，请在右侧卡片编辑原批注。"
    private static let anchorLostSelectionMessage = "该批注的原文位置需要重新确认。"
    private static let emptyCommentMessage = "批注意见不能为空。"
    private static let missingAnnotationSelectionMessage = "请先在阅读区选择需要批注的文本。"
    private static let missingAnnotationSaveSelectionMessage = "没有可保存的文本选区。"
    private static let annotationSaveFailurePrefix = "批注保存失败："
    private static let importBlockedByAnnotationSaveFailurePrefix = "批注保存失败，已暂停打开/导入以避免丢失批注："
    private static let transientImportFailurePrefixes = [
        "只能打开 .md 或 .markdown 文件",
        "无法读取 Markdown 文件",
        "请拖入 .md 或 .markdown 文件",
        "拖拽导入失败：",
        "无法读取拖入的文件",
        "批注文件读取失败，已从应用数据目录恢复",
        "批注从应用数据目录恢复。",
        "批注文件读取失败，已创建空会话",
        "备用批注文件读取失败，已创建空会话"
    ]

    @Published public var currentDocument: MarkdownDocument?
    @Published public var reviewSession: ReviewSession?
    @Published public var readerSelection: ReaderSelection?
    @Published public var selectedNoteID: String?
    @Published public var promptPreview: PromptPreviewState = .empty
    @Published public var saveState: SaveState = .idle
    @Published public var panelMode: InspectorPanelMode = .annotations
    @Published public var scrollTargetHeadingID: UUID?
    @Published public var scrollTargetRange: RenderedTextRange?
    @Published public var currentReadingHeadingID: UUID?
    @Published public var isAnnotationPopoverPresented = false
    @Published public private(set) var recentDocumentURLs: [URL] = []
    @Published public var clipboardMarkdownCandidate: ClipboardMarkdownCandidate?

    private let documentLoader: DocumentLoader
    private let reviewSessionStore: ReviewSessionStore
    private let promptFileStore: PromptFileStore
    private let recentDocumentStore: RecentDocumentStore
    private let promptBuilder: PromptBuilder
    private let textAnchorBuilder: TextAnchorBuilder
    private let textAnchorResolver: TextAnchorResolver
    private var autosaveTask: Task<Void, Never>?
    private var importGeneration = 0
    private var dismissedClipboardMarkdownPath: String?

    public init(
        documentLoader: DocumentLoader = DocumentLoader(),
        reviewSessionStore: ReviewSessionStore = ReviewSessionStore(),
        promptFileStore: PromptFileStore = PromptFileStore(),
        recentDocumentStore: RecentDocumentStore = RecentDocumentStore(),
        promptBuilder: PromptBuilder = PromptBuilder(),
        textAnchorBuilder: TextAnchorBuilder = TextAnchorBuilder(),
        textAnchorResolver: TextAnchorResolver = TextAnchorResolver()
    ) {
        self.documentLoader = documentLoader
        self.reviewSessionStore = reviewSessionStore
        self.promptFileStore = promptFileStore
        self.recentDocumentStore = recentDocumentStore
        self.promptBuilder = promptBuilder
        self.textAnchorBuilder = textAnchorBuilder
        self.textAnchorResolver = textAnchorResolver
        self.recentDocumentURLs = recentDocumentStore.recentDocumentURLs()
    }

    deinit {
        MainActor.assumeIsolated {
            let hasPendingAutosave = autosaveTask != nil
            autosaveTask?.cancel()
            if hasPendingAutosave,
               let currentDocument,
               var session = reviewSession {
                session.sourceFile = currentDocument.fileURL?.path
                session.sourceHash = currentDocument.sourceHash
                session.updatedAt = Date()
                _ = try? reviewSessionStore.save(session, for: currentDocument)
            }
        }
    }

    public func openDocumentWithPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText
        ]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        openDocument(at: url)
    }

    @discardableResult
    public func openLastDocumentIfAvailable() -> Bool {
        guard let url = recentDocumentStore.lastOpenedDocumentURL(),
              FileManager.default.fileExists(atPath: url.path),
              documentLoader.canLoadDocument(from: url)
        else {
            return false
        }

        return openDocument(at: url)
    }

    public func clearRecentDocuments() {
        recentDocumentStore.clear()
        recentDocumentURLs = []
    }

    public func refreshClipboardMarkdownCandidate(pasteboard: NSPasteboard = .general) {
        let candidateURL = ClipboardMarkdownDocumentResolver.markdownFileURLs(from: pasteboard).first
        guard let candidateURL,
              candidateURL.standardizedFileURL != currentDocument?.fileURL?.standardizedFileURL
        else {
            clipboardMarkdownCandidate = nil
            return
        }

        let candidatePath = candidateURL.standardizedFileURL.path
        guard candidatePath != dismissedClipboardMarkdownPath else {
            clipboardMarkdownCandidate = nil
            return
        }

        clipboardMarkdownCandidate = ClipboardMarkdownCandidate(url: candidateURL)
    }

    public func dismissClipboardMarkdownCandidate() {
        dismissedClipboardMarkdownPath = clipboardMarkdownCandidate?.url.standardizedFileURL.path
        clipboardMarkdownCandidate = nil
    }

    @discardableResult
    public func openMarkdownFromPasteboard(pasteboard: NSPasteboard = .general) -> Bool {
        let urls = ClipboardMarkdownDocumentResolver.markdownFileURLs(from: pasteboard)
        guard urls.isEmpty == false else {
            clipboardMarkdownCandidate = nil
            return false
        }

        let didOpen = openFirstSupportedDocument(at: urls)
        if didOpen {
            dismissedClipboardMarkdownPath = nil
            clipboardMarkdownCandidate = nil
        } else {
            refreshClipboardMarkdownCandidate(pasteboard: pasteboard)
        }
        return didOpen
    }

    @discardableResult
    public func openFirstSupportedDocument(at urls: [URL]) -> Bool {
        _ = nextImportGeneration()
        guard flushPendingAutosave() else {
            return false
        }

        let supportedURLs = urls.filter { documentLoader.canLoadDocument(from: $0) }
        guard supportedURLs.isEmpty == false else {
            saveState = .failed("请拖入 .md 或 .markdown 文件。")
            return false
        }

        saveState = .loading

        var failureMessages: [String] = []
        for url in supportedURLs {
            if openDocumentWithoutFlushingAutosave(at: url) {
                return true
            }
            if case let .failed(message) = saveState {
                failureMessages.append(message)
            }
        }

        saveState = .failed(droppedMarkdownFailureMessage(
            attemptedCount: supportedURLs.count,
            failureMessages: failureMessages
        ))
        return false
    }

    @discardableResult
    public func openDroppedDocument(from providers: [NSItemProvider]) -> Bool {
        let generation = nextImportGeneration()
        guard flushPendingAutosave() else {
            return false
        }

        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard fileProviders.isEmpty == false else {
            saveState = .failed("请拖入 .md 或 .markdown 文件。")
            return false
        }

        saveState = .loading

        let collector = DroppedFileURLCollector(expectedCount: fileProviders.count) { [weak self] urls, errorMessages in
            Task { @MainActor in
                guard let self else {
                    return
                }
                guard self.importGeneration == generation else {
                    return
                }

                guard urls.isEmpty == false else {
                    self.saveState = .failed(errorMessages.first.map { "拖拽导入失败：\($0)" } ?? "无法读取拖入的文件。")
                    return
                }

                self.openFirstSupportedDocument(at: urls)
            }
        }

        for (index, provider) in fileProviders.enumerated() {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                collector.record(
                    url: DroppedFileURLResolver.fileURL(from: item),
                    errorMessage: error?.localizedDescription,
                    at: index
                )
            }
        }

        return true
    }

    @discardableResult
    public func openDocument(at url: URL) -> Bool {
        _ = nextImportGeneration()
        guard flushPendingAutosave() else {
            return false
        }
        saveState = .loading

        return openDocumentWithoutFlushingAutosave(at: url)
    }

    private func openDocumentWithoutFlushingAutosave(at url: URL) -> Bool {
        do {
            let document = try documentLoader.loadDocument(from: url)
            let loadResult = reviewSessionStore.loadSessionResult(for: document)
            let resolvedSession = resolvedReviewSession(loadResult.session, for: document)
            let didResolveAnchors = resolvedSession != loadResult.session
            let topHeadingID = document.outline.flattened().first?.id
            currentDocument = document
            reviewSession = resolvedSession
            selectedNoteID = nil
            readerSelection = nil
            isAnnotationPopoverPresented = false
            scrollTargetHeadingID = topHeadingID
            scrollTargetRange = topHeadingID == nil ? RenderedTextRange(location: 0, length: 0) : nil
            currentReadingHeadingID = topHeadingID
            saveState = loadResult.warning.map(SaveState.failed) ?? .loaded
            refreshPromptPreview()
            if didResolveAnchors {
                scheduleAutosave(preservingSidecarLoadWarning: loadResult.warning != nil)
            }
            recordRecentDocument(url)
            refreshClipboardMarkdownCandidate()
            return true
        } catch {
            saveState = .failed(error.localizedDescription)
            return false
        }
    }

    private func recordRecentDocument(_ url: URL) {
        recentDocumentStore.recordOpenedDocument(at: url)
        recentDocumentURLs = recentDocumentStore.recentDocumentURLs()
    }

    public func selectHeading(_ heading: DocumentHeading) {
        guard visibleHeadingMatchesCurrentDocument(heading.id) else {
            return
        }

        clearTransientAnnotationFailures()
        guard scrollTargetHeadingID != heading.id || scrollTargetRange != nil else {
            return
        }

        scrollTargetHeadingID = heading.id
        scrollTargetRange = nil
        currentReadingHeadingID = heading.id
        readerSelection = nil
        isAnnotationPopoverPresented = false
        clearTransientImportFailure()
    }

    public func updateVisibleHeading(_ headingID: UUID?) {
        if let headingID, !visibleHeadingMatchesCurrentDocument(headingID) {
            return
        }
        if headingID == nil, scrollTargetHeadingID != nil || scrollTargetRange != nil {
            return
        }

        guard currentReadingHeadingID != headingID else {
            return
        }

        currentReadingHeadingID = headingID
    }

    public func updateVisibleHeading(_ headingID: UUID?, from documentID: UUID) {
        guard currentDocument?.id == documentID else {
            return
        }

        updateVisibleHeading(headingID)
    }

    public func updateSelection(_ selection: ReaderSelection?) {
        if let selection, !selectionMatchesCurrentDocument(selection) {
            return
        }

        guard readerSelection != selection else {
            if selection != nil {
                clearTransientAnnotationFailures()
            }
            return
        }

        if selection == nil, isAnnotationPopoverPresented {
            // Opening the draft editor can move focus away from the reader and clear NSTextView selection.
            clearTransientAnnotationFailures()
            if scrollTargetHeadingID != nil {
                scrollTargetHeadingID = nil
            }
            if scrollTargetRange != nil {
                scrollTargetRange = nil
            }
            return
        }

        readerSelection = selection
        clearTransientAnnotationFailures()
        if scrollTargetHeadingID != nil {
            scrollTargetHeadingID = nil
        }
        if scrollTargetRange != nil {
            scrollTargetRange = nil
        }
        isAnnotationPopoverPresented = false
        if selection == nil {
            return
        }

        clearTransientImportFailure()
        if let matchingNoteID = noteID(matching: selection) {
            selectedNoteID = matchingNoteID
            panelMode = .annotations
        } else {
            selectedNoteID = nil
        }
    }

    public func updateSelection(_ selection: ReaderSelection?, from documentID: UUID) {
        guard currentDocument?.id == documentID else {
            return
        }

        updateSelection(selection)
    }

    public func clearScrollTargets() {
        guard scrollTargetHeadingID != nil || scrollTargetRange != nil else {
            return
        }

        scrollTargetHeadingID = nil
        scrollTargetRange = nil
    }

    public func clearScrollTarget(headingID: UUID?, range: RenderedTextRange?) {
        guard scrollTargetHeadingID == headingID,
              scrollTargetRange == range
        else {
            return
        }

        clearScrollTargets()
    }

    public func clearScrollTarget(headingID: UUID?, range: RenderedTextRange?, from documentID: UUID) {
        guard currentDocument?.id == documentID else {
            return
        }

        clearScrollTarget(headingID: headingID, range: range)
    }

    public var canCreateAnnotation: Bool {
        guard let selection = readerSelection,
              currentDocument != nil,
              !selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return noteID(matching: selection) == nil
    }

    public var annotationHighlights: [AnnotationHighlight] {
        (reviewSession?.notes ?? []).compactMap { note in
            guard let renderedRange = note.anchor.renderedRange,
                  note.status != .anchorLost
            else {
                return nil
            }

            return AnnotationHighlight(
                id: note.id,
                range: renderedRange,
                isSelected: selectedNoteID == note.id,
                isIncludedInPrompt: note.includeInPrompt && note.status != .excluded,
                isAnchorLost: note.status == .anchorLost
            )
        }
    }

    public func beginAnnotationFromCurrentSelection() {
        if let matchingNoteID = noteID(matching: readerSelection) {
            handleExistingAnnotationSelection(noteID: matchingNoteID)
            return
        }

        guard canCreateAnnotation else {
            saveState = .failed(Self.missingAnnotationSelectionMessage)
            return
        }

        panelMode = .annotations
        isAnnotationPopoverPresented = true
    }

    public func beginAnnotation(from selection: ReaderSelection) {
        updateSelection(selection)
        beginAnnotationFromCurrentSelection()
    }

    public func cancelAnnotation() {
        isAnnotationPopoverPresented = false
        clearTransientAnnotationFailures()
    }

    public func createAnnotation(comment: String, quickPrompts: [QuickPromptUsage]) {
        guard let currentDocument, let selection = readerSelection else {
            saveState = .failed(Self.missingAnnotationSaveSelectionMessage)
            return
        }

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            saveState = .failed(Self.emptyCommentMessage)
            return
        }

        if let matchingNoteID = noteID(matching: selection) {
            handleExistingAnnotationSelection(noteID: matchingNoteID)
            return
        }

        var session = reviewSession ?? ReviewSession(sourceFile: currentDocument.fileURL?.path, sourceHash: currentDocument.sourceHash)
        let sequence = NoteIDGenerator.nextSequence(after: session.lastNoteSequence)
        let noteID = NoteIDGenerator.id(for: sequence)
        let now = Date()
        let anchor = textAnchorBuilder.makeAnchor(for: selection, in: currentDocument)
        let note = ReviewNote(
            id: noteID,
            status: .confirmed,
            includeInPrompt: true,
            anchor: anchor,
            comment: trimmedComment,
            quickPrompts: quickPrompts,
            createdAt: now,
            updatedAt: now
        )

        session.lastNoteSequence = sequence
        session.notes.append(note)
        session.updatedAt = now
        reviewSession = session
        selectedNoteID = noteID
        scrollTargetRange = anchor.renderedRange
        readerSelection = nil
        isAnnotationPopoverPresented = false
        markReviewSessionChanged()
    }

    public func selectNote(id: String) {
        guard let note = reviewSession?.notes.first(where: { $0.id == id }) else {
            return
        }

        selectedNoteID = id
        panelMode = .annotations
        readerSelection = nil
        isAnnotationPopoverPresented = false

        if let renderedRange = note.anchor.renderedRange, note.status != .anchorLost {
            scrollTargetRange = renderedRange
            scrollTargetHeadingID = nil
            clearTransientAnnotationFailures()
            clearTransientImportFailure()
        } else {
            scrollTargetHeadingID = nil
            scrollTargetRange = nil
            saveState = currentAnnotationSaveFailureState() ?? .failed(Self.anchorLostSelectionMessage)
        }
    }

    public func updateNoteComment(id: String, comment: String) {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            saveState = .failed(Self.emptyCommentMessage)
            return
        }

        guard let currentComment = reviewSession?.notes.first(where: { $0.id == id })?.comment,
              currentComment != trimmedComment
        else {
            clearTransientEmptyCommentFailure()
            return
        }

        mutateNote(id: id) { note in
            note.comment = trimmedComment
            note.updatedAt = Date()
        }
    }

    public func setNoteIncluded(id: String, includeInPrompt: Bool) {
        guard let currentValue = reviewSession?.notes.first(where: { $0.id == id })?.includeInPrompt,
              currentValue != includeInPrompt
        else {
            return
        }

        mutateNote(id: id) { note in
            note.includeInPrompt = includeInPrompt
            note.updatedAt = Date()
        }
    }

    public func deleteNote(id: String) {
        guard var session = reviewSession else {
            return
        }

        guard let deletedNote = session.notes.first(where: { $0.id == id }) else {
            return
        }
        session.notes.removeAll { $0.id == id }
        session.updatedAt = Date()
        reviewSession = session

        let deletedWasSelected = selectedNoteID == id
        if deletedWasSelected {
            selectedNoteID = nil
        }
        if deletedWasSelected || scrollTargetRange == deletedNote.anchor.renderedRange {
            scrollTargetHeadingID = nil
            scrollTargetRange = nil
        }
        if let deletedRange = deletedNote.anchor.renderedRange,
           let selectionRange = readerSelection?.renderedRange,
           Self.rangesOverlap(selectionRange, deletedRange) {
            readerSelection = nil
            isAnnotationPopoverPresented = false
        }

        markReviewSessionChanged()
    }

    public func refreshPromptPreview() {
        guard let currentDocument, let reviewSession else {
            promptPreview = .empty
            return
        }

        let result = promptBuilder.build(document: currentDocument, session: reviewSession)
        promptPreview = PromptPreviewState(
            prompt: result.prompt,
            warnings: result.warnings,
            includedNoteCount: result.includedNoteCount
        )
    }

    public func copyPromptToPasteboard() {
        var annotationSaveFailureState = currentAnnotationSaveFailureState()
        var reviewFallbackPath: String?
        guard !promptPreview.prompt.isEmpty else {
            saveState = annotationSaveFailureState ?? .failed("没有可复制的有效 Prompt。")
            return
        }

        if annotationSaveFailureState == nil, autosaveTask != nil {
            saveReviewSessionNow()
            if case let .savedToFallback(path) = saveState {
                reviewFallbackPath = path
            }
            annotationSaveFailureState = currentAnnotationSaveFailureState()
            if let annotationSaveFailureState {
                saveState = annotationSaveFailureState
                return
            }
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(promptPreview.prompt, forType: .string)
        saveState = annotationSaveFailureState
            ?? reviewFallbackPath.map(SaveState.copiedWithReviewFallback)
            ?? .copied
    }

    public func savePromptToDisk() {
        var annotationSaveFailureState = currentAnnotationSaveFailureState()
        var reviewFallbackPath: String?
        guard let currentDocument else {
            saveState = annotationSaveFailureState ?? .failed("请先打开 Markdown 文档。")
            return
        }

        guard !promptPreview.prompt.isEmpty else {
            saveState = annotationSaveFailureState ?? .failed("没有可保存的有效 Prompt。")
            return
        }

        if annotationSaveFailureState == nil, autosaveTask != nil {
            saveReviewSessionNow()
            if case let .savedToFallback(path) = saveState {
                reviewFallbackPath = path
            }
            annotationSaveFailureState = currentAnnotationSaveFailureState()
            if let annotationSaveFailureState {
                saveState = annotationSaveFailureState
                return
            }
        }

        do {
            let result = try promptFileStore.save(prompt: promptPreview.prompt, for: currentDocument)
            if let annotationSaveFailureState {
                saveState = annotationSaveFailureState
            } else if let reviewFallbackPath {
                saveState = result.usedFallback
                    ? .promptSavedToFallbackWithReviewFallback(
                        promptPath: result.url.path,
                        reviewPath: reviewFallbackPath
                    )
                    : .promptSavedWithReviewFallback(
                        promptPath: result.url.path,
                        reviewPath: reviewFallbackPath
                    )
            } else {
                saveState = result.usedFallback
                    ? .promptSavedToFallback(result.url.path)
                    : .promptSaved(result.url.path)
            }
        } catch {
            if let annotationSaveFailureState {
                saveState = annotationSaveFailureState
            } else if let reviewFallbackPath {
                saveState = .failed(
                    "Prompt 保存失败：\(error.localizedDescription)。批注已保存到应用数据目录：\(reviewFallbackPath)"
                )
            } else {
                saveState = .failed("Prompt 保存失败：\(error.localizedDescription)")
            }
        }
    }

    public func saveReviewSessionNow() {
        guard let currentDocument, var session = reviewSession else {
            return
        }

        autosaveTask?.cancel()
        autosaveTask = nil
        saveState = .saving
        session.sourceFile = currentDocument.fileURL?.path
        session.sourceHash = currentDocument.sourceHash
        session.updatedAt = Date()
        reviewSession = session

        do {
            let result = try reviewSessionStore.save(session, for: currentDocument)
            saveState = result.usedFallback ? .savedToFallback(result.url.path) : .saved
        } catch {
            saveState = .failed("\(Self.annotationSaveFailurePrefix)\(error.localizedDescription)")
        }
    }

    private func resolvedReviewSession(_ session: ReviewSession, for document: MarkdownDocument) -> ReviewSession {
        var resolved = session
        resolved.sourceFile = document.fileURL?.path
        resolved.sourceHash = document.sourceHash
        resolved.notes = session.notes.map { textAnchorResolver.resolve(note: $0, in: document) }
        resolved.lastNoteSequence = max(resolved.lastNoteSequence, NoteIDGenerator.highestSequence(in: resolved.notes))
        return resolved
    }

    private func nextImportGeneration() -> Int {
        importGeneration &+= 1
        return importGeneration
    }

    @discardableResult
    private func flushPendingAutosave() -> Bool {
        if currentAnnotationSaveFailureState() != nil {
            markImportBlockedByAnnotationSaveFailure()
            return false
        }

        guard autosaveTask != nil else {
            return true
        }

        autosaveTask?.cancel()
        autosaveTask = nil
        saveReviewSessionNow()
        if case .failed = saveState {
            markImportBlockedByAnnotationSaveFailure()
            return false
        }
        return true
    }

    private func markImportBlockedByAnnotationSaveFailure() {
        guard case let .failed(message) = saveState,
              message.hasPrefix(Self.annotationSaveFailurePrefix)
        else {
            return
        }

        let detail = String(message.dropFirst(Self.annotationSaveFailurePrefix.count))
        saveState = .failed("\(Self.importBlockedByAnnotationSaveFailurePrefix)\(detail)")
    }

    private func currentAnnotationSaveFailureState() -> SaveState? {
        guard case let .failed(message) = saveState,
              message.hasPrefix(Self.annotationSaveFailurePrefix)
                || message.hasPrefix(Self.importBlockedByAnnotationSaveFailurePrefix)
        else {
            return nil
        }

        return .failed(message)
    }

    private func currentSidecarLoadWarningState() -> SaveState? {
        guard case let .failed(message) = saveState,
              SidecarLoadWarningPresentation.presentation(from: message) != nil
        else {
            return nil
        }

        return .failed(message)
    }

    private func droppedMarkdownFailureMessage(attemptedCount: Int, failureMessages: [String]) -> String {
        guard let firstFailureMessage = failureMessages.first else {
            return "无法读取拖入的文件。"
        }
        guard attemptedCount > 1 else {
            return firstFailureMessage
        }

        return "无法读取拖入的文件（已尝试 \(attemptedCount) 个 Markdown）：\(firstFailureMessage)"
    }

    private func mutateNote(id: String, mutation: (inout ReviewNote) -> Void) {
        guard var session = reviewSession,
              let index = session.notes.firstIndex(where: { $0.id == id })
        else {
            return
        }

        mutation(&session.notes[index])
        session.updatedAt = Date()
        reviewSession = session
        markReviewSessionChanged()
    }

    private func markReviewSessionChanged() {
        let annotationSaveFailureState = currentAnnotationSaveFailureState()
        refreshPromptPreview()
        if let annotationSaveFailureState {
            autosaveTask?.cancel()
            autosaveTask = nil
            saveState = annotationSaveFailureState
            return
        }

        saveState = .saving
        scheduleAutosave()
    }

    private func handleExistingAnnotationSelection(noteID: String) {
        selectedNoteID = noteID
        panelMode = .annotations
        isAnnotationPopoverPresented = false
        saveState = .failed(Self.existingAnnotationSelectionMessage)
    }

    private func clearTransientAnnotationFailures() {
        clearTransientExistingAnnotationSelectionFailure()
        clearTransientAnchorLostSelectionFailure()
        clearTransientEmptyCommentFailure()
        clearTransientMissingAnnotationSelectionFailure()
        clearTransientMissingAnnotationSaveSelectionFailure()
    }

    private func clearTransientExistingAnnotationSelectionFailure() {
        guard saveState == .failed(Self.existingAnnotationSelectionMessage) else {
            return
        }

        restoreNeutralSaveState()
    }

    private func clearTransientAnchorLostSelectionFailure() {
        guard saveState == .failed(Self.anchorLostSelectionMessage) else {
            return
        }

        restoreNeutralSaveState()
    }

    private func clearTransientEmptyCommentFailure() {
        guard saveState == .failed(Self.emptyCommentMessage) else {
            return
        }

        restoreNeutralSaveState()
    }

    private func clearTransientMissingAnnotationSelectionFailure() {
        guard saveState == .failed(Self.missingAnnotationSelectionMessage) else {
            return
        }

        restoreNeutralSaveState()
    }

    private func clearTransientMissingAnnotationSaveSelectionFailure() {
        guard saveState == .failed(Self.missingAnnotationSaveSelectionMessage) else {
            return
        }

        restoreNeutralSaveState()
    }

    private func clearTransientImportFailure() {
        guard case let .failed(message) = saveState,
              Self.transientImportFailurePrefixes.contains(where: { message.hasPrefix($0) })
        else {
            return
        }

        restoreNeutralSaveState()
    }

    private func restoreNeutralSaveState() {
        if autosaveTask != nil {
            saveState = .saving
        } else if currentDocument != nil {
            saveState = .loaded
        } else {
            saveState = .idle
        }
    }

    private func noteID(matching selection: ReaderSelection?) -> String? {
        guard let selection else {
            return nil
        }

        return reviewSession?.notes.first { note in
            guard note.status != .anchorLost,
                  let renderedRange = note.anchor.renderedRange
            else {
                return false
            }

            return Self.rangesOverlap(selection.renderedRange, renderedRange)
        }?.id
    }

    private func selectionMatchesCurrentDocument(_ selection: ReaderSelection) -> Bool {
        guard let currentDocument else {
            return false
        }

        let renderedText = currentDocument.renderModel.renderedPlainText as NSString
        let range = selection.renderedRange.nsRange
        guard range.location >= 0,
              range.length >= 0,
              range.location + range.length <= renderedText.length
        else {
            return false
        }

        return renderedText.substring(with: range) == selection.selectedText
    }

    private func visibleHeadingMatchesCurrentDocument(_ headingID: UUID) -> Bool {
        currentDocument?.outline.flattened().contains { $0.id == headingID } == true
    }

    private static func rangesOverlap(_ first: RenderedTextRange, _ second: RenderedTextRange) -> Bool {
        first.location < second.upperBound && second.location < first.upperBound
    }

    private func scheduleAutosave(preservingSidecarLoadWarning: Bool = false) {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }

            guard let self,
                  !Task.isCancelled
            else {
                return
            }

            let sidecarLoadWarningState = preservingSidecarLoadWarning
                ? self.currentSidecarLoadWarningState()
                : nil
            self.saveReviewSessionNow()
            if case .failed = self.saveState {
                return
            }
            self.autosaveTask = nil
            if let sidecarLoadWarningState {
                self.saveState = sidecarLoadWarningState
            }
        }
    }
}

private final class DroppedFileURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let completion: @Sendable ([URL], [String]) -> Void
    private var remaining: Int
    private var urlsByIndex: [(Int, URL)] = []
    private var errorMessages: [String] = []

    init(
        expectedCount: Int,
        completion: @escaping @Sendable ([URL], [String]) -> Void
    ) {
        self.remaining = expectedCount
        self.completion = completion
    }

    func record(url: URL?, errorMessage: String?, at index: Int) {
        let result: ([URL], [String])?
        lock.lock()
        if let url {
            urlsByIndex.append((index, url))
        }
        if let errorMessage {
            errorMessages.append(errorMessage)
        } else if url == nil {
            errorMessages.append("无法读取文件 URL")
        }
        remaining -= 1
        if remaining == 0 {
            let sortedURLs = urlsByIndex
                .sorted { $0.0 < $1.0 }
                .map(\.1)
            result = (sortedURLs, errorMessages)
        } else {
            result = nil
        }
        lock.unlock()

        if let result {
            completion(result.0, result.1)
        }
    }
}
