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
    case promptSaved(String)
    case promptSavedToFallback(String)
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
        case let .promptSaved(path):
            return "Prompt 已保存：\(path)"
        case let .promptSavedToFallback(path):
            return "Prompt 已保存到应用数据目录：\(path)"
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

@MainActor
public final class AppState: ObservableObject {
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

    private let documentLoader: DocumentLoader
    private let reviewSessionStore: ReviewSessionStore
    private let promptFileStore: PromptFileStore
    private let promptBuilder: PromptBuilder
    private let textAnchorBuilder: TextAnchorBuilder
    private let textAnchorResolver: TextAnchorResolver
    private var autosaveTask: Task<Void, Never>?

    public init(
        documentLoader: DocumentLoader = DocumentLoader(),
        reviewSessionStore: ReviewSessionStore = ReviewSessionStore(),
        promptFileStore: PromptFileStore = PromptFileStore(),
        promptBuilder: PromptBuilder = PromptBuilder(),
        textAnchorBuilder: TextAnchorBuilder = TextAnchorBuilder(),
        textAnchorResolver: TextAnchorResolver = TextAnchorResolver()
    ) {
        self.documentLoader = documentLoader
        self.reviewSessionStore = reviewSessionStore
        self.promptFileStore = promptFileStore
        self.promptBuilder = promptBuilder
        self.textAnchorBuilder = textAnchorBuilder
        self.textAnchorResolver = textAnchorResolver
    }

    deinit {
        autosaveTask?.cancel()
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

    public func openDocument(at url: URL) {
        saveState = .loading

        do {
            let document = try documentLoader.loadDocument(from: url)
            let loadResult = reviewSessionStore.loadSessionResult(for: document)
            let resolvedSession = resolvedReviewSession(loadResult.session, for: document)
            let didResolveAnchors = resolvedSession != loadResult.session
            currentDocument = document
            reviewSession = resolvedSession
            selectedNoteID = nil
            readerSelection = nil
            isAnnotationPopoverPresented = false
            scrollTargetHeadingID = nil
            scrollTargetRange = nil
            currentReadingHeadingID = document.outline.flattened().first?.id
            saveState = loadResult.warning.map(SaveState.failed) ?? .loaded
            refreshPromptPreview()
            if didResolveAnchors {
                scheduleAutosave()
            }
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    public func selectHeading(_ heading: DocumentHeading) {
        guard scrollTargetHeadingID != heading.id || scrollTargetRange != nil else {
            return
        }

        scrollTargetHeadingID = heading.id
        scrollTargetRange = nil
        currentReadingHeadingID = heading.id
    }

    public func updateVisibleHeading(_ headingID: UUID?) {
        guard currentReadingHeadingID != headingID else {
            return
        }

        currentReadingHeadingID = headingID
    }

    public func updateSelection(_ selection: ReaderSelection?) {
        guard readerSelection != selection else {
            return
        }

        readerSelection = selection
        if scrollTargetHeadingID != nil {
            scrollTargetHeadingID = nil
        }
        if scrollTargetRange != nil {
            scrollTargetRange = nil
        }
        if selection == nil {
            isAnnotationPopoverPresented = false
        }
    }

    public func clearScrollTargets() {
        guard scrollTargetHeadingID != nil || scrollTargetRange != nil else {
            return
        }

        scrollTargetHeadingID = nil
        scrollTargetRange = nil
    }

    public var canCreateAnnotation: Bool {
        guard let selectedText = readerSelection?.selectedText.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        return currentDocument != nil && !selectedText.isEmpty
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
        guard canCreateAnnotation else {
            saveState = .failed("请先在阅读区选择需要批注的文本。")
            return
        }

        panelMode = .annotations
        isAnnotationPopoverPresented = true
    }

    public func cancelAnnotation() {
        isAnnotationPopoverPresented = false
    }

    public func createAnnotation(comment: String, quickPrompts: [QuickPromptUsage]) {
        guard let currentDocument, let selection = readerSelection else {
            saveState = .failed("没有可保存的文本选区。")
            return
        }

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            saveState = .failed("批注意见不能为空。")
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
        isAnnotationPopoverPresented = false
        refreshPromptPreview()
        scheduleAutosave()
    }

    public func selectNote(id: String) {
        guard let note = reviewSession?.notes.first(where: { $0.id == id }) else {
            return
        }

        selectedNoteID = id
        panelMode = .annotations

        if let renderedRange = note.anchor.renderedRange, note.status != .anchorLost {
            scrollTargetRange = renderedRange
            scrollTargetHeadingID = nil
        } else {
            saveState = .failed("该批注的原文位置需要重新确认。")
        }
    }

    public func updateNoteComment(id: String, comment: String) {
        mutateNote(id: id) { note in
            note.comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            note.updatedAt = Date()
        }
    }

    public func setNoteIncluded(id: String, includeInPrompt: Bool) {
        mutateNote(id: id) { note in
            note.includeInPrompt = includeInPrompt
            note.updatedAt = Date()
        }
    }

    public func deleteNote(id: String) {
        guard var session = reviewSession else {
            return
        }

        session.notes.removeAll { $0.id == id }
        session.updatedAt = Date()
        reviewSession = session

        if selectedNoteID == id {
            selectedNoteID = nil
        }

        refreshPromptPreview()
        scheduleAutosave()
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
        guard !promptPreview.prompt.isEmpty else {
            saveState = .failed("没有可复制的有效 Prompt。")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(promptPreview.prompt, forType: .string)
        saveState = .copied
    }

    public func savePromptToDisk() {
        guard let currentDocument else {
            saveState = .failed("请先打开 Markdown 文档。")
            return
        }

        guard !promptPreview.prompt.isEmpty else {
            saveState = .failed("没有可保存的有效 Prompt。")
            return
        }

        do {
            let result = try promptFileStore.save(prompt: promptPreview.prompt, for: currentDocument)
            saveState = result.usedFallback
                ? .promptSavedToFallback(result.url.path)
                : .promptSaved(result.url.path)
        } catch {
            saveState = .failed("Prompt 保存失败：\(error.localizedDescription)")
        }
    }

    public func saveReviewSessionNow() {
        guard let currentDocument, var session = reviewSession else {
            return
        }

        saveState = .saving
        session.sourceFile = currentDocument.fileURL?.path
        session.sourceHash = currentDocument.sourceHash
        session.updatedAt = Date()
        reviewSession = session

        do {
            let result = try reviewSessionStore.save(session, for: currentDocument)
            saveState = result.usedFallback ? .savedToFallback(result.url.path) : .saved
        } catch {
            saveState = .failed("批注保存失败：\(error.localizedDescription)")
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

    private func mutateNote(id: String, mutation: (inout ReviewNote) -> Void) {
        guard var session = reviewSession,
              let index = session.notes.firstIndex(where: { $0.id == id })
        else {
            return
        }

        mutation(&session.notes[index])
        session.updatedAt = Date()
        reviewSession = session
        refreshPromptPreview()
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            self?.saveReviewSessionNow()
        }
    }
}
