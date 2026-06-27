import SwiftUI

public enum AnnotationPanelScrollBehavior {
    public static func targetNoteID(selectedNoteID: String?, visibleNoteIDs: [String]) -> String? {
        guard let selectedNoteID,
              visibleNoteIDs.contains(selectedNoteID)
        else {
            return nil
        }

        return selectedNoteID
    }
}

public struct AnnotationActionStatusPresentation: Equatable, Sendable {
    public var message: String
    public var systemImage: String
    public var isFailure: Bool
    public var showsRetrySaveAction: Bool

    public init(
        message: String,
        systemImage: String,
        isFailure: Bool,
        showsRetrySaveAction: Bool = false
    ) {
        self.message = message
        self.systemImage = systemImage
        self.isFailure = isFailure
        self.showsRetrySaveAction = showsRetrySaveAction
    }

    public static func presentation(for saveState: SaveState) -> AnnotationActionStatusPresentation? {
        switch saveState {
        case .copied:
            return AnnotationActionStatusPresentation(
                message: "Prompt 已复制",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case let .copiedWithReviewFallback(path):
            return AnnotationActionStatusPresentation(
                message: "Prompt 已复制；批注已保存到应用数据目录：\(path)",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case let .promptSaved(path):
            return AnnotationActionStatusPresentation(
                message: "Prompt 已保存：\(path)",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case let .promptSavedToFallback(path):
            return AnnotationActionStatusPresentation(
                message: "Prompt 已保存到应用数据目录：\(path)",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case let .promptSavedWithReviewFallback(promptPath, reviewPath):
            return AnnotationActionStatusPresentation(
                message: "Prompt 已保存：\(promptPath)；批注已保存到应用数据目录：\(reviewPath)",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case let .promptSavedToFallbackWithReviewFallback(promptPath, reviewPath):
            return AnnotationActionStatusPresentation(
                message: "Prompt 已保存到应用数据目录：\(promptPath)；批注已保存到应用数据目录：\(reviewPath)",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case .saved:
            return AnnotationActionStatusPresentation(
                message: "批注已保存",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case let .savedToFallback(path):
            return AnnotationActionStatusPresentation(
                message: "批注已保存到应用数据目录：\(path)",
                systemImage: "checkmark.circle",
                isFailure: false
            )
        case let .failed(message):
            if let sidecarWarning = SidecarLoadWarningPresentation.presentation(from: message) {
                return AnnotationActionStatusPresentation(
                    message: sidecarWarning.message,
                    systemImage: sidecarWarning.systemImage,
                    isFailure: false
                )
            }
            if let reviewSaveFailure = reviewSaveFailureMessage(from: message) {
                return AnnotationActionStatusPresentation(
                    message: reviewSaveFailure,
                    systemImage: "exclamationmark.triangle",
                    isFailure: true,
                    showsRetrySaveAction: true
                )
            }
            if isReaderImportFailure(message) {
                return nil
            }

            return AnnotationActionStatusPresentation(
                message: message,
                systemImage: "exclamationmark.triangle",
                isFailure: true
            )
        case .idle, .loading, .loaded, .saving:
            return nil
        }
    }

    private static func reviewSaveFailureMessage(from message: String) -> String? {
        let blockedImportPrefix = "批注保存失败，已暂停打开/导入以避免丢失批注："
        if message.hasPrefix(blockedImportPrefix) {
            return messageWithRecoveryHint(
                message,
                hint: "请处理保存位置后重试保存，再重新导入。"
            )
        }

        let saveFailurePrefix = "批注保存失败："
        guard message.hasPrefix(saveFailurePrefix) else {
            return nil
        }

        return messageWithRecoveryHint(
            message,
            hint: "请处理保存位置后重试保存。"
        )
    }

    private static func isReaderImportFailure(_ message: String) -> Bool {
        let readerImportFailurePrefixes = [
            "只能打开 .md 或 .markdown 文件",
            "无法读取 Markdown 文件",
            "请拖入 .md 或 .markdown 文件",
            "拖拽导入失败：",
            "无法读取拖入的文件"
        ]

        return readerImportFailurePrefixes.contains { message.hasPrefix($0) }
    }

    private static func messageWithRecoveryHint(_ message: String, hint: String) -> String {
        let sentenceEndings: Set<Character> = ["。", "！", "？", ".", "!", "?"]
        let separator = message.last.map { sentenceEndings.contains($0) ? "" : "。" } ?? ""
        return "\(message)\(separator)\(hint)"
    }
}

@MainActor
public struct AnnotationPanelView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("批注与 Prompt")
                    .font(.headline)

                Picker("", selection: $appState.panelMode) {
                    ForEach(InspectorPanelMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if appState.panelMode == .annotations {
                annotationsFirstLayout
            } else {
                promptFirstLayout
            }

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    Button {
                        appState.copyPromptToPasteboard()
                    } label: {
                        Label("复制 Prompt", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.promptPreview.prompt.isEmpty)

                    Button {
                        appState.savePromptToDisk()
                    } label: {
                        Label("保存 .prompt.md", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appState.promptPreview.prompt.isEmpty)
                }

                if let status = AnnotationActionStatusPresentation.presentation(for: appState.saveState) {
                    Label(status.message, systemImage: status.systemImage)
                        .font(.caption)
                        .foregroundStyle(status.isFailure ? .orange : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if status.showsRetrySaveAction {
                        Button {
                            appState.saveReviewSessionNow()
                        } label: {
                            Label("重试保存", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var annotationsFirstLayout: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        if notes.isEmpty {
                            emptyNotesView
                        } else {
                            ForEach(notes) { note in
                                NoteCardView(note: note)
                                    .id(note.id)
                            }
                        }
                    }
                    .padding(14)
                }
                .frame(maxHeight: .infinity)
                .onAppear {
                    scrollToSelectedNote(in: proxy)
                }
                .onChange(of: appState.selectedNoteID) {
                    scrollToSelectedNote(in: proxy)
                }
            }

            Divider()

            PromptPreviewView(state: appState.promptPreview, compact: true)
                .padding(14)
        }
    }

    private var promptFirstLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(notes.isEmpty ? "暂无批注" : "\(notes.count) 条批注")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                if notes.isEmpty {
                    emptyNotesView
                }

                PromptPreviewView(state: appState.promptPreview, compact: false)
            }
            .padding(14)
        }
    }

    private var emptyNotesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(appState.currentDocument == nil ? "打开文档后可添加批注" : "暂无批注")
                .font(.callout)
                .foregroundStyle(.secondary)
            if appState.currentDocument != nil {
                Text("在阅读区选择文本后点击“批注 +”。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var notes: [ReviewNote] {
        appState.reviewSession?.notes ?? []
    }

    private func scrollToSelectedNote(in proxy: ScrollViewProxy) {
        let visibleNoteIDs = notes.map(\.id)
        guard let targetID = AnnotationPanelScrollBehavior.targetNoteID(
            selectedNoteID: appState.selectedNoteID,
            visibleNoteIDs: visibleNoteIDs
        ) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            proxy.scrollTo(targetID, anchor: .center)
        }
    }
}
