import SwiftUI

public struct AnnotationPanelScrollInstruction: Equatable, Sendable {
    public var targetNoteID: String
    public var animationDuration: Double?

    public init(targetNoteID: String, animationDuration: Double?) {
        self.targetNoteID = targetNoteID
        self.animationDuration = animationDuration
    }
}

public enum AnnotationPanelScrollBehavior {
    public static func targetNoteID(selectedNoteID: String?, availableNoteIDs: [String]) -> String? {
        guard let selectedNoteID,
              availableNoteIDs.contains(selectedNoteID)
        else {
            return nil
        }

        return selectedNoteID
    }

    public static func targetNoteID(selectedNoteID: String?, visibleNoteIDs: [String]) -> String? {
        targetNoteID(selectedNoteID: selectedNoteID, availableNoteIDs: visibleNoteIDs)
    }

    public static func instruction(
        selectedNoteID: String?,
        availableNoteIDs: [String],
        visibleNoteIDs: [String],
        isInitialAppearance: Bool
    ) -> AnnotationPanelScrollInstruction? {
        guard let targetNoteID = targetNoteID(
            selectedNoteID: selectedNoteID,
            availableNoteIDs: availableNoteIDs
        ) else {
            return nil
        }

        guard isInitialAppearance || !visibleNoteIDs.contains(targetNoteID) else {
            return nil
        }

        return AnnotationPanelScrollInstruction(
            targetNoteID: targetNoteID,
            animationDuration: isInitialAppearance ? nil : 0.16
        )
    }

    public static func instruction(
        selectedNoteID: String?,
        visibleNoteIDs: [String],
        isInitialAppearance: Bool
    ) -> AnnotationPanelScrollInstruction? {
        instruction(
            selectedNoteID: selectedNoteID,
            availableNoteIDs: visibleNoteIDs,
            visibleNoteIDs: visibleNoteIDs,
            isInitialAppearance: isInitialAppearance
        )
    }
}

public enum AnnotationPanelVisibilityBehavior {
    public static func currentVisibleNoteIDs(
        measuredNoteIDs: [String],
        currentNoteIDs: [String],
        visibleNoteIDs: [String]
    ) -> [String] {
        measuredNoteIDs == currentNoteIDs ? visibleNoteIDs : []
    }

    public static func visibleNoteIDs(
        noteIDs: [String],
        noteFrames: [String: CGRect],
        viewport: CGRect,
        minimumVisibleHeight: CGFloat = 12
    ) -> [String] {
        noteIDs.filter { noteID in
            guard let frame = noteFrames[noteID],
                  !frame.isNull,
                  !frame.isEmpty
            else {
                return false
            }

            let intersection = viewport.intersection(frame)
            guard !intersection.isNull,
                  !intersection.isEmpty
            else {
                return false
            }

            let requiredVisibleHeight = min(frame.height, max(0, minimumVisibleHeight))
            return intersection.height >= requiredVisibleHeight
        }
    }
}

public struct AnnotationActionStatusPresentation: Equatable, Sendable {
    public var message: String
    public var systemImage: String
    public var isFailure: Bool
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var showsRetrySaveAction: Bool
    public var retrySaveHelp: String?
    public var retrySaveAccessibilityLabel: String?
    public var retrySaveAccessibilityHint: String?

    public init(
        message: String,
        systemImage: String,
        isFailure: Bool,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        showsRetrySaveAction: Bool = false,
        retrySaveHelp: String? = nil,
        retrySaveAccessibilityLabel: String? = nil,
        retrySaveAccessibilityHint: String? = nil
    ) {
        self.message = message
        self.systemImage = systemImage
        self.isFailure = isFailure
        self.accessibilityLabel = accessibilityLabel ?? "\(isFailure ? "错误" : "状态")：\(message)"
        self.accessibilityHint = accessibilityHint ?? (
            Self.compactMessage(message, limit: 64) == message
                ? "状态提示"
                : "状态提示已截断，悬停可查看完整信息"
        )
        self.showsRetrySaveAction = showsRetrySaveAction
        self.retrySaveHelp = retrySaveHelp
        self.retrySaveAccessibilityLabel = retrySaveAccessibilityLabel
        self.retrySaveAccessibilityHint = retrySaveAccessibilityHint
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
                    showsRetrySaveAction: true,
                    retrySaveHelp: "重新保存当前批注文件",
                    retrySaveAccessibilityLabel: "重试保存批注",
                    retrySaveAccessibilityHint: "按 Return 重新保存当前批注文件"
                )
            }
            if let anchorLostSelectionFailure = anchorLostSelectionMessage(from: message) {
                return AnnotationActionStatusPresentation(
                    message: anchorLostSelectionFailure,
                    systemImage: "exclamationmark.triangle",
                    isFailure: true
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
        case .idle, .loading, .loaded, .saving, .historyCleaned, .historyCleared:
            return nil
        }
    }

    public var displayMessage: String {
        Self.compactMessage(message, limit: 64)
    }

    public var fullMessage: String {
        message
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

    private static func anchorLostSelectionMessage(from message: String) -> String? {
        guard message == "该批注的原文位置需要重新确认。" else {
            return nil
        }

        return "该批注的原文位置需要重新确认。请在阅读区重新选择原文，恢复后提示会自动消失。"
    }

    private static func compactMessage(_ message: String, limit: Int) -> String {
        guard message.count > limit, limit > 1 else {
            return message
        }

        return String(message.prefix(limit - 1)) + "…"
    }
}

public struct AnnotationPanelEmptyStatePresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String
    public var actionTitle: String?
    public var actionHelp: String?
    public var actionShortcutHint: String?
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var actionAccessibilityLabel: String?
    public var actionAccessibilityHint: String?

    public init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String?,
        actionHelp: String? = nil,
        actionShortcutHint: String? = nil,
        accessibilityLabel: String,
        accessibilityHint: String,
        actionAccessibilityLabel: String? = nil,
        actionAccessibilityHint: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.actionHelp = actionHelp
        self.actionShortcutHint = actionShortcutHint
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.actionAccessibilityLabel = actionAccessibilityLabel
        self.actionAccessibilityHint = actionAccessibilityHint
    }

    public static func presentation(
        hasOpenDocument: Bool,
        noteCount: Int
    ) -> AnnotationPanelEmptyStatePresentation? {
        guard noteCount == 0 else {
            return nil
        }

        if hasOpenDocument {
            return AnnotationPanelEmptyStatePresentation(
                title: "暂无批注",
                message: "批注会出现在这里",
                systemImage: "quote.bubble",
                actionTitle: nil,
                accessibilityLabel: "批注列表暂无批注",
                accessibilityHint: "在阅读区选择文本后可添加批注"
            )
        }

        return AnnotationPanelEmptyStatePresentation(
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
    }
}

public struct AnnotationPanelModeSummaryPresentation: Equatable, Sendable {
    public var title: String
    public var help: String

    public init(title: String, help: String) {
        self.title = title
        self.help = help
    }

    public static func presentation(
        hasOpenDocument: Bool,
        noteCount: Int
    ) -> AnnotationPanelModeSummaryPresentation {
        guard hasOpenDocument else {
            return AnnotationPanelModeSummaryPresentation(
                title: "未打开文档",
                help: "打开 Markdown 后显示批注列表"
            )
        }

        guard noteCount > 0 else {
            return AnnotationPanelModeSummaryPresentation(
                title: "暂无批注",
                help: "在阅读区选择文本后添加批注"
            )
        }

        return AnnotationPanelModeSummaryPresentation(
            title: "\(noteCount) 条批注",
            help: "当前文档共有 \(noteCount) 条批注"
        )
    }
}

@MainActor
public struct AnnotationPanelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var visibleNoteIDs: [String] = []
    @State private var measuredNoteIdentityIDs: [String] = []

    private static let scrollCoordinateSpaceName = "annotation-panel-scroll"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("批注与 Prompt")
                    .font(.headline)

                Picker("右侧面板模式", selection: $appState.panelMode) {
                    ForEach(InspectorPanelMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                            .help(mode.help)
                            .accessibilityLabel(mode.accessibilityLabel)
                            .accessibilityHint(mode.accessibilityHint)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("右侧面板模式")
                .accessibilityHint("在批注列表和 Prompt 预览之间切换")
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
                let copyPresentation = PromptActionButtonPresentation.copy(
                    hasPrompt: !appState.promptPreview.prompt.isEmpty,
                    saveState: appState.saveState
                )
                let savePresentation = PromptActionButtonPresentation.save(
                    hasPrompt: !appState.promptPreview.prompt.isEmpty,
                    saveState: appState.saveState
                )

                HStack(spacing: 10) {
                    Button {
                        appState.copyPromptToPasteboard()
                    } label: {
                        Label(copyPresentation.title, systemImage: copyPresentation.systemImage)
                            .lineLimit(copyPresentation.lineLimit)
                            .minimumScaleFactor(copyPresentation.minimumScaleFactor)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!copyPresentation.isEnabled)
                    .help(copyPresentation.help)
                    .accessibilityLabel(copyPresentation.accessibilityLabel)
                    .accessibilityHint(copyPresentation.accessibilityHint)

                    Button {
                        appState.savePromptToDisk()
                    } label: {
                        Label(savePresentation.title, systemImage: savePresentation.systemImage)
                            .lineLimit(savePresentation.lineLimit)
                            .minimumScaleFactor(savePresentation.minimumScaleFactor)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!savePresentation.isEnabled)
                    .help(savePresentation.help)
                    .accessibilityLabel(savePresentation.accessibilityLabel)
                    .accessibilityHint(savePresentation.accessibilityHint)
                }

                if let status = AnnotationActionStatusPresentation.presentation(for: appState.saveState) {
                    Label(status.displayMessage, systemImage: status.systemImage)
                        .font(.caption)
                        .foregroundStyle(status.isFailure ? .orange : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(status.fullMessage)
                        .accessibilityLabel(status.accessibilityLabel)
                        .accessibilityHint(status.accessibilityHint)

                    if status.showsRetrySaveAction {
                        Button {
                            appState.saveReviewSessionNow()
                        } label: {
                            Label("重试保存", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .help(status.retrySaveHelp ?? "重试保存")
                        .accessibilityLabel(status.retrySaveAccessibilityLabel ?? "重试保存")
                        .accessibilityHint(status.retrySaveAccessibilityHint ?? "")
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
                GeometryReader { viewportProxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if notes.isEmpty {
                                emptyNotesView
                            } else {
                                ForEach(notes) { note in
                                    NoteCardView(note: note)
                                        .id(note.id)
                                        .background(noteFrameReader(for: note.id))
                                }
                            }
                        }
                        .padding(14)
                    }
                    .coordinateSpace(name: Self.scrollCoordinateSpaceName)
                    .frame(maxHeight: .infinity)
                    .onPreferenceChange(AnnotationPanelNoteFramePreferenceKey.self) { noteFrames in
                        updateVisibleNoteIDs(noteFrames: noteFrames, viewportSize: viewportProxy.size)
                    }
                    .onAppear {
                        scrollToSelectedNote(in: proxy, isInitialAppearance: true)
                    }
                    .onChange(of: appState.selectedNoteID) {
                        scrollToSelectedNote(in: proxy, isInitialAppearance: false)
                    }
                }
            }

            Divider()

            PromptPreviewView(
                state: appState.promptPreview,
                hasOpenDocument: appState.currentDocument != nil,
                compact: true
            )
                .padding(14)
        }
    }

    private var promptFirstLayout: some View {
        ScrollView {
            let summary = AnnotationPanelModeSummaryPresentation.presentation(
                hasOpenDocument: appState.currentDocument != nil,
                noteCount: notes.count
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                        .help(summary.help)
                        .accessibilityLabel(summary.help)
                    Spacer()
                }

                if notes.isEmpty {
                    emptyNotesView
                }

                PromptPreviewView(
                    state: appState.promptPreview,
                    hasOpenDocument: appState.currentDocument != nil,
                    compact: false
                )
            }
            .padding(14)
        }
    }

    private var emptyNotesView: some View {
        let presentation = AnnotationPanelEmptyStatePresentation.presentation(
            hasOpenDocument: appState.currentDocument != nil,
            noteCount: notes.count
        )

        return VStack(spacing: 10) {
            if let presentation {
                Image(systemName: presentation.systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text(presentation.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(presentation.message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if let actionTitle = presentation.actionTitle {
                    Button {
                        appState.openDocumentWithPanel()
                    } label: {
                        Label(actionTitle, systemImage: "folder")
                    }
                    .controlSize(.small)
                    .help(emptyActionHelpText(presentation, fallbackTitle: actionTitle))
                    .accessibilityLabel(presentation.actionAccessibilityLabel ?? actionTitle)
                    .accessibilityHint(presentation.actionAccessibilityHint ?? "")
                    .keyboardShortcut(.defaultAction)
                }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation?.accessibilityLabel ?? "")
        .accessibilityHint(presentation?.accessibilityHint ?? "")
    }

    private var notes: [ReviewNote] {
        appState.reviewSession?.notes ?? []
    }

    private var noteMeasurementIdentityIDs: [String] {
        notes.map(noteMeasurementIdentityID(for:))
    }

    private func noteFrameReader(for noteID: String) -> some View {
        GeometryReader { noteProxy in
            Color.clear.preference(
                key: AnnotationPanelNoteFramePreferenceKey.self,
                value: [noteID: noteProxy.frame(in: .named(Self.scrollCoordinateSpaceName))]
            )
        }
    }

    private func updateVisibleNoteIDs(noteFrames: [String: CGRect], viewportSize: CGSize) {
        let currentNoteIDs = notes.map(\.id)
        let currentNoteIdentityIDs = noteMeasurementIdentityIDs
        let nextVisibleNoteIDs = AnnotationPanelVisibilityBehavior.visibleNoteIDs(
            noteIDs: currentNoteIDs,
            noteFrames: noteFrames,
            viewport: CGRect(origin: .zero, size: viewportSize)
        )

        if measuredNoteIdentityIDs != currentNoteIdentityIDs {
            measuredNoteIdentityIDs = currentNoteIdentityIDs
        }

        if visibleNoteIDs != nextVisibleNoteIDs {
            visibleNoteIDs = nextVisibleNoteIDs
        }
    }

    private func emptyActionHelpText(
        _ presentation: AnnotationPanelEmptyStatePresentation,
        fallbackTitle: String
    ) -> String {
        let help = presentation.actionHelp ?? fallbackTitle
        guard let shortcut = presentation.actionShortcutHint else {
            return help
        }

        return "\(help)（\(shortcut)）"
    }

    private func scrollToSelectedNote(in proxy: ScrollViewProxy, isInitialAppearance: Bool) {
        let currentNoteIDs = notes.map(\.id)
        let currentNoteIdentityIDs = noteMeasurementIdentityIDs
        let currentVisibleNoteIDs = AnnotationPanelVisibilityBehavior.currentVisibleNoteIDs(
            measuredNoteIDs: measuredNoteIdentityIDs,
            currentNoteIDs: currentNoteIdentityIDs,
            visibleNoteIDs: visibleNoteIDs
        )
        guard let instruction = AnnotationPanelScrollBehavior.instruction(
            selectedNoteID: appState.selectedNoteID,
            availableNoteIDs: currentNoteIDs,
            visibleNoteIDs: currentVisibleNoteIDs,
            isInitialAppearance: isInitialAppearance
        ) else {
            return
        }

        if let animationDuration = instruction.animationDuration {
            withAnimation(.easeInOut(duration: animationDuration)) {
                proxy.scrollTo(instruction.targetNoteID, anchor: .center)
            }
        } else {
            proxy.scrollTo(instruction.targetNoteID, anchor: .center)
        }
    }

    private func noteMeasurementIdentityID(for note: ReviewNote) -> String {
        let sourceFile = appState.reviewSession?.sourceFile ?? ""
        let sourceHash = appState.reviewSession?.sourceHash ?? ""
        let renderedRange = note.anchor.renderedRange.map {
            "\($0.location)-\($0.upperBound)"
        } ?? "nil"

        return [
            sourceFile,
            sourceHash,
            note.id,
            note.anchor.documentHash,
            renderedRange,
            note.anchor.selectedText
        ].joined(separator: "|")
    }
}

private struct AnnotationPanelNoteFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
