import AppKit
import SwiftUI

public struct ReaderStatusBannerPresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String
    public var actionTitle: String?
    public var copyTitle: String?
    public var copyHelp: String?
    public var copyValue: String?
    public var dismissTitle: String?
    public var dismissHelp: String?
    public var dismissShortcutHint: String?

    public init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        copyTitle: String? = nil,
        copyHelp: String? = nil,
        copyValue: String? = nil,
        dismissTitle: String? = nil,
        dismissHelp: String? = nil,
        dismissShortcutHint: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.copyTitle = copyTitle
        self.copyHelp = copyHelp
        self.copyValue = copyValue
        self.dismissTitle = dismissTitle
        self.dismissHelp = dismissHelp
        self.dismissShortcutHint = dismissShortcutHint
    }

    public static func presentation(
        for saveState: SaveState,
        hasOpenDocument: Bool = false
    ) -> ReaderStatusBannerPresentation? {
        guard case let .failed(message) = saveState else {
            return nil
        }
        if let sidecarWarning = SidecarLoadWarningPresentation.presentation(from: message) {
            let dismissTitle = dismissTitle(for: message)
            return ReaderStatusBannerPresentation(
                title: sidecarWarning.title,
                message: sidecarWarning.message,
                systemImage: sidecarWarning.systemImage,
                copyTitle: "复制详情",
                copyHelp: "复制完整提示；不会关闭提示",
                copyValue: sidecarWarning.message,
                dismissTitle: dismissTitle,
                dismissHelp: dismissHelp(for: message),
                dismissShortcutHint: dismissTitle == nil ? nil : "Esc"
            )
        }
        guard shouldShowReaderBanner(for: message) else {
            return nil
        }
        let displayMessage = hasOpenDocument ? messageWithCurrentDocumentContext(message) : message
        let dismissTitle = dismissTitle(for: message)

        return ReaderStatusBannerPresentation(
            title: title(for: message, hasOpenDocument: hasOpenDocument),
            message: displayMessage,
            systemImage: "exclamationmark.triangle",
            actionTitle: actionTitle(for: message, hasOpenDocument: hasOpenDocument),
            copyTitle: "复制详情",
            copyHelp: copyHelp(for: message),
            copyValue: displayMessage,
            dismissTitle: dismissTitle,
            dismissHelp: dismissHelp(for: message),
            dismissShortcutHint: dismissTitle == nil ? nil : "Esc"
        )
    }

    private static func shouldShowReaderBanner(for message: String) -> Bool {
        let readerFailurePrefixes = [
            "只能打开 .md 或 .markdown 文件",
            "无法读取 Markdown 文件",
            "请拖入 .md 或 .markdown 文件",
            "拖拽导入失败：",
            "无法读取拖入的文件",
            "批注保存失败，已暂停打开/导入以避免丢失批注",
            "任务状态保存失败："
        ]

        return readerFailurePrefixes.contains { message.hasPrefix($0) }
    }

    private static func dismissTitle(for message: String) -> String? {
        isDismissibleTransientFailure(message) ? "关闭" : nil
    }

    private static func copyHelp(for message: String) -> String {
        if message.hasPrefix("任务状态保存失败：")
            || message.hasPrefix("批注保存失败，已暂停打开/导入以避免丢失批注") {
            return "复制完整失败详情；不会隐藏保存失败"
        }

        return "复制完整错误详情；不会关闭提示"
    }

    private static func dismissHelp(for message: String) -> String? {
        isDismissibleTransientFailure(message) ? "关闭这条提示" : nil
    }

    private static func isDismissibleTransientFailure(_ message: String) -> Bool {
        let dismissiblePrefixes = [
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

        return dismissiblePrefixes.contains { message.hasPrefix($0) }
    }

    private static func title(for message: String, hasOpenDocument: Bool) -> String {
        if message.hasPrefix("任务状态保存失败：") {
            return "保存未完成"
        }

        return hasOpenDocument ? "导入未完成" : "需要处理"
    }

    private static func actionTitle(for message: String, hasOpenDocument: Bool) -> String? {
        guard hasOpenDocument,
              message.hasPrefix("任务状态保存失败："),
              message.contains("文件已在外部修改")
        else {
            return nil
        }

        return "重新载入文件"
    }

    private static func messageWithCurrentDocumentContext(_ message: String) -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceEndings: Set<Character> = ["。", "！", "？", ".", "!", "?"]
        let separator = trimmedMessage.last.map { sentenceEndings.contains($0) ? "" : "。" } ?? ""
        return "\(trimmedMessage)\(separator)当前文档仍保持打开。"
    }
}

public struct ReaderStatusBannerCopyButtonPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var hitTargetSize: CGFloat
    public var backgroundOpacity: Double
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        hitTargetSize: CGFloat,
        backgroundOpacity: Double,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.hitTargetSize = hitTargetSize
        self.backgroundOpacity = backgroundOpacity
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        title: String,
        help: String?,
        isCopied: Bool
    ) -> ReaderStatusBannerCopyButtonPresentation {
        let resolvedHelp = help ?? title
        let detailKind = detailKind(for: resolvedHelp)
        if isCopied {
            return ReaderStatusBannerCopyButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                hitTargetSize: 24,
                backgroundOpacity: 0.10,
                help: "已复制\(detailKind.title)",
                accessibilityLabel: "已复制\(detailKind.title)",
                accessibilityHint: detailKind.copiedHint
            )
        }

        return ReaderStatusBannerCopyButtonPresentation(
            title: title == "复制详情" ? "复制\(detailKind.title)" : title,
            systemImage: "doc.on.doc",
            hitTargetSize: 24,
            backgroundOpacity: 0,
            help: resolvedHelp,
            accessibilityLabel: title == "复制详情" ? "复制\(detailKind.title)" : title,
            accessibilityHint: detailKind.copyHint
        )
    }

    private static func detailKind(for help: String) -> (
        title: String,
        copyHint: String,
        copiedHint: String
    ) {
        if help.contains("失败") {
            return (
                "失败详情",
                "按 Return 复制完整失败详情；提示会保持显示，保存失败仍会继续可见",
                "失败详情已复制到剪切板，可继续复制；提示会保持显示，保存失败仍会继续可见，按钮会短暂恢复"
            )
        }

        if help.contains("提示"), !help.contains("错误") {
            return (
                "提示详情",
                "按 Return 复制完整提示；提示会保持显示",
                "提示详情已复制到剪切板，可继续复制；提示会保持显示，按钮会短暂恢复"
            )
        }

        return (
            "错误详情",
            "按 Return 复制完整错误详情；提示会保持显示",
            "错误详情已复制到剪切板，可继续复制；提示会保持显示，按钮会短暂恢复"
        )
    }
}

public struct ReaderStatusBannerActionButtonPresentation: Equatable, Sendable {
    public var title: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(title: String) -> ReaderStatusBannerActionButtonPresentation {
        if title == "重新载入文件" {
            return ReaderStatusBannerActionButtonPresentation(
                title: title,
                help: "重新载入磁盘上的 Markdown 文件，并重新同步任务状态",
                accessibilityLabel: title,
                accessibilityHint: "按 Return 重新载入磁盘上的 Markdown 文件；外部修改会以磁盘内容为准"
            )
        }

        return ReaderStatusBannerActionButtonPresentation(
            title: title,
            help: title,
            accessibilityLabel: title,
            accessibilityHint: "按 Return 执行\(title)"
        )
    }
}

public struct ReaderStatusBannerDismissButtonPresentation: Equatable, Sendable {
    public var title: String
    public var hitTargetSize: CGFloat
    public var backgroundOpacity: Double
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        hitTargetSize: CGFloat,
        backgroundOpacity: Double,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.hitTargetSize = hitTargetSize
        self.backgroundOpacity = backgroundOpacity
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        title: String,
        help: String?,
        shortcutHint: String?
    ) -> ReaderStatusBannerDismissButtonPresentation {
        let baseHelp = help ?? title
        let fullHelp = shortcutHint.map { "\(baseHelp)（\($0)）" } ?? baseHelp
        let actionHint = title == "关闭" ? "关闭当前提示；不会重试打开文件，不会修改当前文档或批注" : baseHelp
        let accessibilityHint = shortcutHint.map { "按 \($0) \(actionHint)" } ?? baseHelp

        return ReaderStatusBannerDismissButtonPresentation(
            title: title,
            hitTargetSize: 24,
            backgroundOpacity: 0,
            help: fullHelp,
            accessibilityLabel: title == "关闭" ? "关闭提示" : title,
            accessibilityHint: accessibilityHint
        )
    }
}

public struct ReaderFooterStatusCopyButtonPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var hitTargetSize: CGFloat
    public var backgroundOpacity: Double
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        hitTargetSize: CGFloat,
        backgroundOpacity: Double,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.hitTargetSize = hitTargetSize
        self.backgroundOpacity = backgroundOpacity
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        title: String,
        help: String?,
        isCopied: Bool
    ) -> ReaderFooterStatusCopyButtonPresentation {
        if isCopied {
            return ReaderFooterStatusCopyButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                hitTargetSize: 24,
                backgroundOpacity: 0.10,
                help: "已复制状态信息",
                accessibilityLabel: "已复制状态",
                accessibilityHint: "完整状态信息已复制到剪切板，可继续复制；按钮会短暂恢复"
            )
        }

        let resolvedHelp = help ?? title
        let isFailureStatus = title.contains("失败")
        return ReaderFooterStatusCopyButtonPresentation(
            title: title,
            systemImage: "doc.on.doc",
            hitTargetSize: 24,
            backgroundOpacity: 0,
            help: resolvedHelp,
            accessibilityLabel: title,
            accessibilityHint: isFailureStatus
                ? "按 Return 复制完整失败状态；不会改变当前保存状态，状态栏会保持显示"
                : "按 Return \(resolvedHelp)；状态栏会保持显示"
        )
    }
}

public struct ReaderEmptyStatePresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String
    public var actionTitle: String
    public var help: String
    public var keyboardShortcutHint: String?
    public var accessibilityLabel: String
    public var accessibilityHint: String?

    public init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String,
        help: String,
        keyboardShortcutHint: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.help = help
        self.keyboardShortcutHint = keyboardShortcutHint
        self.accessibilityLabel = accessibilityLabel ?? "\(title)，\(message)"
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation() -> ReaderEmptyStatePresentation {
        ReaderEmptyStatePresentation(
            title: "打开 Markdown",
            message: "选择 .md 或 .markdown 文件开始阅读和批注",
            systemImage: "doc.text",
            actionTitle: "选择 .md 文件",
            help: "打开 Markdown 文档",
            keyboardShortcutHint: "Return",
            accessibilityHint: "按 Return 选择 Markdown 文件"
        )
    }
}

public struct ReaderFooterStatusPresentation: Equatable, Sendable {
    public var documentText: String
    public var saveStateText: String
    public var fullSaveStateText: String
    public var documentAccessibilityLabel: String
    public var saveStateAccessibilityLabel: String
    public var saveStateAccessibilityHint: String?
    public var copyTitle: String?
    public var copyHelp: String?
    public var copyValue: String?

    public init(
        documentText: String,
        saveStateText: String,
        fullSaveStateText: String,
        documentAccessibilityLabel: String? = nil,
        saveStateAccessibilityLabel: String? = nil,
        saveStateAccessibilityHint: String? = nil,
        copyTitle: String? = nil,
        copyHelp: String? = nil,
        copyValue: String? = nil
    ) {
        self.documentText = documentText
        self.saveStateText = saveStateText
        self.fullSaveStateText = fullSaveStateText
        self.documentAccessibilityLabel = documentAccessibilityLabel ?? "文档状态：\(documentText)"
        self.saveStateAccessibilityLabel = saveStateAccessibilityLabel ?? "保存状态：\(fullSaveStateText)"
        self.saveStateAccessibilityHint = saveStateAccessibilityHint
        self.copyTitle = copyTitle
        self.copyHelp = copyHelp
        self.copyValue = copyValue
    }

    public static func presentation(
        documentText: String,
        saveState: SaveState,
        maximumSaveStateLength: Int = 72
    ) -> ReaderFooterStatusPresentation {
        let fullText = saveState.label
        let compactedText = compactText(fullText, limit: maximumSaveStateLength)
        let isCompacted = compactedText != fullText
        let isFailure: Bool
        if case .failed = saveState {
            isFailure = true
        } else {
            isFailure = false
        }
        let shouldExposeCopy = isCompacted || isFailure
        return ReaderFooterStatusPresentation(
            documentText: documentText,
            saveStateText: compactedText,
            fullSaveStateText: fullText,
            saveStateAccessibilityHint: footerAccessibilityHint(isCompacted: isCompacted, isFailure: isFailure),
            copyTitle: shouldExposeCopy ? (isFailure ? "复制失败状态" : "复制状态") : nil,
            copyHelp: shouldExposeCopy
                ? (isFailure ? "复制完整失败状态；不会改变当前保存状态" : "复制完整状态信息")
                : nil,
            copyValue: shouldExposeCopy ? fullText : nil
        )
    }

    private static func footerAccessibilityHint(isCompacted: Bool, isFailure: Bool) -> String? {
        if isCompacted, isFailure {
            return "保存失败且状态已截断；可悬停查看或复制完整失败状态，复制不会改变当前保存状态"
        }
        if isFailure {
            return "保存失败；可复制完整失败状态，复制不会改变当前保存状态"
        }
        if isCompacted {
            return "状态已截断，可悬停查看或复制完整状态信息"
        }
        return nil
    }

    private static func compactText(_ text: String, limit: Int) -> String {
        guard text.count > limit, limit > 1 else {
            return text
        }

        return String(text.prefix(limit - 1)) + "…"
    }
}

@MainActor
public struct MarkdownReaderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var copiedFooterStatusValue: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Markdown 阅读区")
                    .font(.headline)
                Spacer()
                if let selection = appState.readerSelection {
                    Text("已选择 \(selection.selectedText.count) 字")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            Divider()

            if let banner = ReaderStatusBannerPresentation.presentation(
                for: appState.saveState,
                hasOpenDocument: appState.currentDocument != nil
            ) {
                ReaderStatusBannerView(
                    presentation: banner,
                    onAction: {
                        appState.reloadCurrentDocumentFromDisk()
                    },
                    onCopy: { message in
                        appState.copyStatusMessageToPasteboard(message)
                    },
                    onDismiss: {
                        appState.dismissTransientImportFailure()
                    }
                )
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)

                Divider()
            }

            if let document = appState.currentDocument {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        let documentID = document.id
                        let annotationSelection = appState.readerSelection
                        MarkdownTextViewRepresentable(
                            attributedText: document.renderModel.attributedText,
                            sourceMap: document.renderModel.sourceMap,
                            highlights: activeAnnotationHighlights,
                            annotationButtonRect: annotationEntryRect,
                            isAnnotationButtonActive: appState.isAnnotationPopoverPresented,
                            annotationCursorState: annotationCursorState,
                            scrollTargetHeadingID: appState.scrollTargetHeadingID,
                            scrollTargetRange: appState.scrollTargetRange,
                            onAnnotationButtonPress: {
                                if let annotationSelection {
                                    appState.beginAnnotation(from: annotationSelection)
                                } else {
                                    appState.beginAnnotationFromCurrentSelection()
                                }
                            },
                            onSelectionChange: { selection in
                                appState.updateSelection(selection, from: documentID)
                            },
                            onScrollTargetConsumed: { headingID, range in
                                appState.clearScrollTarget(headingID: headingID, range: range, from: documentID)
                            },
                            onVisibleHeadingChange: { headingID in
                                appState.updateVisibleHeading(headingID, from: documentID)
                            },
                            onTaskMarkerToggle: { sourceRange in
                                appState.toggleTaskMarker(sourceRange: sourceRange)
                            },
                            onTaskMarkerStatusChange: { sourceRange, markerCharacter in
                                appState.setTaskMarker(
                                    sourceRange: sourceRange,
                                    markerCharacter: markerCharacter
                                )
                            },
                            onTaskMarkerUndo: {
                                appState.undoLastTaskMarkerToggle()
                            }
                        )

                        if appState.isAnnotationPopoverPresented,
                           let rect = annotationEntryRect {
                            let popoverRect = MarkdownReaderLayoutMetrics.annotationPopoverRect(
                                forAnnotationButtonRect: rect,
                                avoidingVisibleSelectionRect: appState.readerSelection?.visibleSelectionRect,
                                viewportSize: proxy.size
                            )
                            AnnotationPopoverView()
                                .environmentObject(appState)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(nsColor: .textBackgroundColor))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: Color.black.opacity(0.18), radius: 22, x: 0, y: 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                )
                                .position(x: popoverRect.midX, y: popoverRect.midY)
                                .zIndex(20)
                        }
                    }
                }
            } else {
                let emptyState = ReaderEmptyStatePresentation.presentation()
                VStack(spacing: 16) {
                    Image(systemName: emptyState.systemImage)
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        Text(emptyState.title)
                            .font(.title3.weight(.semibold))
                        Text(emptyState.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    Button {
                        appState.openDocumentWithPanel()
                    } label: {
                        Label(emptyState.actionTitle, systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .help(emptyStateHelpText(emptyState))
                    .accessibilityLabel(emptyState.help)
                    .accessibilityHint(emptyState.accessibilityHint ?? emptyStateHelpText(emptyState))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(emptyState.accessibilityLabel)
                .accessibilityHint(emptyState.accessibilityHint ?? "")
            }

            Divider()

            let footer = ReaderFooterStatusPresentation.presentation(
                documentText: statusText,
                saveState: appState.saveState
            )
            HStack(spacing: 20) {
                Text(footer.documentText)
                    .lineLimit(1)
                    .layoutPriority(1)
                    .accessibilityLabel(footer.documentAccessibilityLabel)
                Spacer(minLength: 8)
                Text(footer.saveStateText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(2)
                    .help(footer.fullSaveStateText)
                    .accessibilityLabel(footer.saveStateAccessibilityLabel)
                    .accessibilityHint(footer.saveStateAccessibilityHint ?? "")
                if let copyTitle = footer.copyTitle,
                   let copyValue = footer.copyValue {
                    let copyButton = ReaderFooterStatusCopyButtonPresentation.presentation(
                        title: copyTitle,
                        help: footer.copyHelp,
                        isCopied: copiedFooterStatusValue == copyValue
                    )
                    Button {
                        appState.copyStatusMessageToPasteboard(copyValue)
                        copiedFooterStatusValue = copyValue
                        resetCopiedFooterStatusValue(copyValue)
                    } label: {
                        Image(systemName: copyButton.systemImage)
                            .imageScale(.small)
                            .frame(width: copyButton.hitTargetSize, height: copyButton.hitTargetSize)
                            .background(Color.accentColor.opacity(copyButton.backgroundOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help(copyButton.help)
                    .accessibilityLabel(copyButton.accessibilityLabel)
                    .accessibilityHint(copyButton.accessibilityHint)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var statusText: String {
        guard let document = appState.currentDocument else {
            return "未打开文档"
        }

        let lineCount = document.rawMarkdown.split(separator: "\n", omittingEmptySubsequences: false).count
        return "\(document.rawMarkdown.count) 字符    \(lineCount) 行"
    }

    private var annotationEntryRect: CGRect? {
        guard appState.canCreateAnnotation else {
            return nil
        }

        return appState.readerSelection?.annotationButtonRect
    }

    private var activeAnnotationHighlights: [AnnotationHighlight] {
        var highlights = appState.annotationHighlights
        if appState.isAnnotationPopoverPresented,
           let selection = appState.readerSelection {
            highlights.append(
                AnnotationHighlight(
                    id: "draft-annotation-selection",
                    range: selection.renderedRange,
                    isSelected: true,
                    isIncludedInPrompt: true,
                    isAnchorLost: false
                )
            )
        }

        return highlights
    }

    private var annotationCursorState: ReaderAnnotationCursorState {
        ReaderAnnotationCursorState.state(
            canCreateAnnotation: appState.canCreateAnnotation,
            isAnnotationPopoverPresented: appState.isAnnotationPopoverPresented,
            hasExistingAnnotationSelection: appState.readerSelection != nil && appState.selectedNoteID != nil
        )
    }

    private func emptyStateHelpText(_ presentation: ReaderEmptyStatePresentation) -> String {
        guard let shortcut = presentation.keyboardShortcutHint else {
            return presentation.help
        }

        return "\(presentation.help)（\(shortcut)）"
    }

    private func resetCopiedFooterStatusValue(_ value: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard copiedFooterStatusValue == value else {
                return
            }

            copiedFooterStatusValue = nil
        }
    }
}

private struct ReaderStatusBannerView: View {
    var presentation: ReaderStatusBannerPresentation
    var onAction: () -> Void = {}
    var onCopy: (String) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    @State private var copiedValue: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: presentation.systemImage)
                .foregroundStyle(.orange)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(presentation.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let actionTitle = presentation.actionTitle {
                let actionButton = ReaderStatusBannerActionButtonPresentation.presentation(title: actionTitle)
                Button(actionButton.title) {
                    onAction()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(actionButton.help)
                .accessibilityLabel(actionButton.accessibilityLabel)
                .accessibilityHint(actionButton.accessibilityHint)
            }

            if let copyTitle = presentation.copyTitle,
               let copyValue = presentation.copyValue {
                let copyButton = ReaderStatusBannerCopyButtonPresentation.presentation(
                    title: copyTitle,
                    help: presentation.copyHelp,
                    isCopied: copiedValue == copyValue
                )
                Button {
                    onCopy(copyValue)
                    copiedValue = copyValue
                    resetCopiedValue(copyValue)
                } label: {
                    Image(systemName: copyButton.systemImage)
                        .imageScale(.medium)
                        .frame(width: copyButton.hitTargetSize, height: copyButton.hitTargetSize)
                        .background(Color.accentColor.opacity(copyButton.backgroundOpacity))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .help(copyButton.help)
                .accessibilityLabel(copyButton.accessibilityLabel)
                .accessibilityHint(copyButton.accessibilityHint)
            }

            if let dismissTitle = presentation.dismissTitle {
                let dismissButton = ReaderStatusBannerDismissButtonPresentation.presentation(
                    title: dismissTitle,
                    help: presentation.dismissHelp,
                    shortcutHint: presentation.dismissShortcutHint
                )
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                        .frame(width: dismissButton.hitTargetSize, height: dismissButton.hitTargetSize)
                        .background(Color.accentColor.opacity(dismissButton.backgroundOpacity))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .help(dismissButton.help)
                .accessibilityLabel(dismissButton.accessibilityLabel)
                .accessibilityHint(dismissButton.accessibilityHint)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func resetCopiedValue(_ value: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard copiedValue == value else {
                return
            }

            copiedValue = nil
        }
    }
}
