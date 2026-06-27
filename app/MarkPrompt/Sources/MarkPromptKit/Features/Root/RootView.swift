import AppKit
import SwiftUI
import UniformTypeIdentifiers

public enum RootLayoutMetrics {
    public static let expandedOutlineWidth: CGFloat = 240
    public static let collapsedOutlineWidth: CGFloat = 52
    public static let defaultInspectorWidth: CGFloat = 360
    public static let minimumInspectorWidth: CGFloat = 320
    public static let maximumInspectorWidth: CGFloat = 620

    public static func clampedInspectorWidth(_ width: CGFloat) -> CGFloat {
        min(maximumInspectorWidth, max(minimumInspectorWidth, width))
    }

    public static func inspectorWidth(startingWidth: CGFloat, dragTranslationX: CGFloat) -> CGFloat {
        clampedInspectorWidth(startingWidth - dragTranslationX)
    }

    public static func inspectorLiveWidth(
        storedWidth: CGFloat,
        dragStartWidth: CGFloat,
        dragTranslationX: CGFloat
    ) -> CGFloat {
        inspectorWidth(startingWidth: dragStartWidth, dragTranslationX: dragTranslationX)
    }

    public static func committedInspectorWidth(afterLiveDragWidth width: CGFloat) -> CGFloat {
        clampedInspectorWidth(width)
    }

    public static func inspectorResizeBoundary(for width: CGFloat) -> InspectorResizeBoundary? {
        let clampedWidth = clampedInspectorWidth(width)
        if abs(clampedWidth - minimumInspectorWidth) < 0.5 {
            return .minimum
        }
        if abs(clampedWidth - maximumInspectorWidth) < 0.5 {
            return .maximum
        }
        return nil
    }
}

public enum InspectorResizeBoundary: Equatable, Sendable {
    case minimum
    case maximum
}

public struct InspectorResizeHandlePresentation: Equatable, Sendable {
    public var hitTargetWidth: CGFloat
    public var indicatorWidth: CGFloat
    public var backgroundOpacity: Double
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityValue: String
    public var accessibilityHint: String

    public init(
        hitTargetWidth: CGFloat,
        indicatorWidth: CGFloat,
        backgroundOpacity: Double,
        help: String,
        accessibilityLabel: String,
        accessibilityValue: String,
        accessibilityHint: String
    ) {
        self.hitTargetWidth = hitTargetWidth
        self.indicatorWidth = indicatorWidth
        self.backgroundOpacity = backgroundOpacity
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        width: CGFloat,
        isHovering: Bool,
        isDragging: Bool
    ) -> InspectorResizeHandlePresentation {
        let clampedWidth = RootLayoutMetrics.clampedInspectorWidth(width)
        let roundedWidth = Int(clampedWidth.rounded())
        let boundary = RootLayoutMetrics.inspectorResizeBoundary(for: clampedWidth)
        let help: String
        let accessibilityValue: String

        if isDragging {
            help = "拖动中，松开后应用 \(roundedWidth) 点宽度"
        } else {
            switch boundary {
            case .minimum:
                help = "批注与 Prompt 宽度已到最小值"
            case .maximum:
                help = "批注与 Prompt 宽度已到最大值"
            case nil:
                help = "拖动调整批注与 Prompt 宽度"
            }
        }

        switch boundary {
        case .minimum:
            accessibilityValue = "最小宽度 \(roundedWidth) 点"
        case .maximum:
            accessibilityValue = "最大宽度 \(roundedWidth) 点"
        case nil:
            accessibilityValue = "\(roundedWidth) 点"
        }

        return InspectorResizeHandlePresentation(
            hitTargetWidth: 14,
            indicatorWidth: isDragging ? 3 : (isHovering || boundary != nil ? 2 : 1),
            backgroundOpacity: isDragging ? 0.10 : (isHovering ? 0.06 : 0),
            help: help,
            accessibilityLabel: "调整批注与 Prompt 宽度",
            accessibilityValue: accessibilityValue,
            accessibilityHint: isDragging ? "松开鼠标应用当前宽度" : "拖动可调整右侧批注与 Prompt 面板宽度"
        )
    }
}

public struct ToolbarOpenPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var actionTitle: String
    public var actionHelp: String
    public var actionAccessibilityLabel: String
    public var actionAccessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        actionTitle: String,
        actionHelp: String,
        actionAccessibilityLabel: String,
        actionAccessibilityHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.actionTitle = actionTitle
        self.actionHelp = actionHelp
        self.actionAccessibilityLabel = actionAccessibilityLabel
        self.actionAccessibilityHint = actionAccessibilityHint
    }

    public static func presentation() -> ToolbarOpenPresentation {
        ToolbarOpenPresentation(
            title: "打开",
            systemImage: "folder",
            help: "打开 Markdown（⌘O）",
            accessibilityLabel: "打开 Markdown",
            accessibilityHint: "按 ⌘O 选择 Markdown 文件",
            actionTitle: "打开 Markdown...",
            actionHelp: "选择 Markdown 文件开始阅读（⌘O）",
            actionAccessibilityLabel: "打开 Markdown 文件",
            actionAccessibilityHint: "按 Return 选择 Markdown 文件"
        )
    }
}

public struct ToolbarSearchPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var keyboardShortcutHint: String?

    public init(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        keyboardShortcutHint: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.keyboardShortcutHint = keyboardShortcutHint
    }

    public static func presentation(hasOpenDocument: Bool) -> ToolbarSearchPresentation {
        ToolbarSearchPresentation(
            title: "查找",
            systemImage: "magnifyingglass",
            isEnabled: hasOpenDocument,
            help: hasOpenDocument ? "在阅读区查找（⌘F）" : "打开 Markdown 后可在阅读区查找",
            accessibilityLabel: hasOpenDocument ? "查找文档内容" : "查找",
            accessibilityHint: hasOpenDocument ? "按 ⌘F 在阅读区查找" : "打开 Markdown 后可在阅读区查找",
            keyboardShortcutHint: hasOpenDocument ? "⌘F" : nil
        )
    }
}

public struct ToolbarDocumentTitlePresentation: Equatable, Sendable {
    public var title: String
    public var help: String
    public var accessibilityLabel: String

    public init(title: String, help: String, accessibilityLabel: String) {
        self.title = title
        self.help = help
        self.accessibilityLabel = accessibilityLabel
    }

    public static func presentation(displayName: String?, fileURL: URL?) -> ToolbarDocumentTitlePresentation {
        guard let displayName, !displayName.isEmpty else {
            return ToolbarDocumentTitlePresentation(
                title: "MarkPrompt",
                help: "未打开文档",
                accessibilityLabel: "MarkPrompt"
            )
        }

        return ToolbarDocumentTitlePresentation(
            title: displayName,
            help: fileURL?.path ?? displayName,
            accessibilityLabel: "当前文档：\(displayName)"
        )
    }
}

public struct DropTargetPresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String
    public var isFailure: Bool
    public var showsDropBoundary: Bool
    public var showsProgress: Bool
    public var dismissTitle: String?
    public var dismissHelp: String?
    public var dismissShortcutHint: String?
    public var dismissAccessibilityLabel: String?
    public var dismissAccessibilityHint: String?
    public var copyTitle: String?
    public var copyHelp: String?
    public var copyValue: String?
    public var copyAccessibilityLabel: String?
    public var copyAccessibilityHint: String?
    public var messageLineLimit: Int?
    public var messageHelp: String?
    public var accessibilityLabel: String
    public var accessibilityHint: String?

    public init(
        title: String,
        message: String,
        systemImage: String,
        isFailure: Bool = false,
        showsDropBoundary: Bool = true,
        showsProgress: Bool = false,
        dismissTitle: String? = nil,
        dismissHelp: String? = nil,
        dismissShortcutHint: String? = nil,
        dismissAccessibilityLabel: String? = nil,
        dismissAccessibilityHint: String? = nil,
        copyTitle: String? = nil,
        copyHelp: String? = nil,
        copyValue: String? = nil,
        copyAccessibilityLabel: String? = nil,
        copyAccessibilityHint: String? = nil,
        messageLineLimit: Int? = nil,
        messageHelp: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.isFailure = isFailure
        self.showsDropBoundary = showsDropBoundary
        self.showsProgress = showsProgress
        self.dismissTitle = dismissTitle
        self.dismissHelp = dismissHelp
        self.dismissShortcutHint = dismissShortcutHint
        self.dismissAccessibilityLabel = dismissAccessibilityLabel
        self.dismissAccessibilityHint = dismissAccessibilityHint
        self.copyTitle = copyTitle
        self.copyHelp = copyHelp
        self.copyValue = copyValue
        self.copyAccessibilityLabel = copyAccessibilityLabel
        self.copyAccessibilityHint = copyAccessibilityHint
        self.messageLineLimit = messageLineLimit
        self.messageHelp = messageHelp
        self.accessibilityLabel = accessibilityLabel ?? "\(title)，\(message)"
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(isTargeted: Bool) -> DropTargetPresentation? {
        presentation(isTargeted: isTargeted, saveState: .idle)
    }

    public static func presentation(
        isTargeted: Bool,
        saveState: SaveState,
        hasOpenDocument: Bool = false
    ) -> DropTargetPresentation? {
        if isTargeted {
            return DropTargetPresentation(
                title: "松开以打开 Markdown",
                message: "支持 .md/.markdown；多个文件会打开第一个可读取 Markdown",
                systemImage: "arrow.down.doc",
                accessibilityHint: "松开鼠标后打开第一个可读取 Markdown 文件"
            )
        }

        if saveState == .loading {
            return DropTargetPresentation(
                title: "正在打开 Markdown",
                message: "正在读取拖入的文件",
                systemImage: "clock",
                showsDropBoundary: false,
                showsProgress: true,
                accessibilityHint: "文件正在打开，请稍候"
            )
        }

        guard let failureMessage = importFailureMessage(from: saveState) else {
            return nil
        }
        let visibleMessage = hasOpenDocument ? messageWithCurrentDocumentContext(failureMessage) : failureMessage
        let title = hasOpenDocument ? "导入未完成" : "未打开文件"
        let accessibilityHint = hasOpenDocument
            ? "导入失败提示，当前文档仍保持打开；可复制完整错误详情，按 Esc 关闭"
            : "导入失败提示，可复制完整错误详情，按 Esc 关闭"

        return DropTargetPresentation(
            title: title,
            message: visibleMessage,
            systemImage: "exclamationmark.triangle",
            isFailure: true,
            showsDropBoundary: false,
            dismissTitle: "关闭",
            dismissHelp: "关闭这条导入提示",
            dismissShortcutHint: "Esc",
            dismissAccessibilityLabel: "关闭导入提示",
            dismissAccessibilityHint: "按 Esc 关闭当前导入提示；不会重试打开文件",
            copyTitle: "复制错误详情",
            copyHelp: "复制完整错误详情；不会关闭提示",
            copyValue: visibleMessage,
            copyAccessibilityLabel: "复制导入失败详情",
            copyAccessibilityHint: "按 Return 复制完整错误详情；提示会保持显示",
            messageLineLimit: 3,
            messageHelp: visibleMessage,
            accessibilityHint: accessibilityHint
        )
    }

    private static func importFailureMessage(from saveState: SaveState) -> String? {
        guard case let .failed(message) = saveState else {
            return nil
        }

        let importFailurePrefixes = [
            "只能打开 .md 或 .markdown 文件",
            "无法读取 Markdown 文件",
            "请拖入 .md 或 .markdown 文件",
            "拖拽导入失败：",
            "无法读取拖入的文件"
        ]
        return importFailurePrefixes.contains { message.hasPrefix($0) } ? message : nil
    }

    private static func messageWithCurrentDocumentContext(_ message: String) -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceEndings: Set<Character> = ["。", "！", "？", ".", "!", "?"]
        let separator = trimmedMessage.last.map { sentenceEndings.contains($0) ? "" : "。" } ?? ""
        return "\(trimmedMessage)\(separator)当前文档仍保持打开。"
    }
}

public struct DropTargetCopyButtonPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        title: String,
        help: String?,
        isCopied: Bool
    ) -> DropTargetCopyButtonPresentation {
        if isCopied {
            return DropTargetCopyButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                help: "已复制错误详情",
                accessibilityLabel: "已复制错误详情",
                accessibilityHint: "错误详情已复制到剪切板，可继续复制；按钮会短暂恢复"
            )
        }

        return DropTargetCopyButtonPresentation(
            title: title,
            systemImage: "doc.on.doc",
            help: help ?? title,
            accessibilityLabel: title,
            accessibilityHint: "按 Return 复制完整错误详情；提示会保持显示"
        )
    }
}

public struct DropTargetDismissButtonPresentation: Equatable, Sendable {
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

    public static func presentation(
        title: String,
        help: String?,
        shortcutHint: String?
    ) -> DropTargetDismissButtonPresentation {
        let baseHelp = help ?? title
        let fullHelp = shortcutHint.map { "\(baseHelp)（\($0)）" } ?? baseHelp
        let actionHint = title == "关闭" ? "关闭当前导入提示；不会重试打开文件" : baseHelp

        return DropTargetDismissButtonPresentation(
            title: title,
            help: fullHelp,
            accessibilityLabel: title == "关闭" ? "关闭导入提示" : title,
            accessibilityHint: shortcutHint.map { "按 \($0) \(actionHint)" } ?? actionHint
        )
    }
}

public struct ClipboardMarkdownBannerPresentation: Equatable, Sendable {
    public var title: String
    public var help: String
    public var openHelp: String
    public var dismissHelp: String
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var openAccessibilityLabel: String
    public var openAccessibilityHint: String
    public var dismissAccessibilityLabel: String
    public var dismissAccessibilityHint: String

    public init(
        title: String,
        help: String,
        openHelp: String,
        dismissHelp: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        openAccessibilityLabel: String,
        openAccessibilityHint: String,
        dismissAccessibilityLabel: String,
        dismissAccessibilityHint: String
    ) {
        self.title = title
        self.help = help
        self.openHelp = openHelp
        self.dismissHelp = dismissHelp
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.openAccessibilityLabel = openAccessibilityLabel
        self.openAccessibilityHint = openAccessibilityHint
        self.dismissAccessibilityLabel = dismissAccessibilityLabel
        self.dismissAccessibilityHint = dismissAccessibilityHint
    }

    public static func presentation(candidate: ClipboardMarkdownCandidate) -> ClipboardMarkdownBannerPresentation {
        let title = "剪切板中有 Markdown 文件：\(candidate.displayName)"
        return ClipboardMarkdownBannerPresentation(
            title: title,
            help: candidate.url.path,
            openHelp: "打开剪切板中的 Markdown 文件",
            dismissHelp: "忽略这次剪切板文件提示",
            accessibilityLabel: title,
            accessibilityHint: "可打开剪切板中的 Markdown 文件，或忽略这次提示",
            openAccessibilityLabel: "打开剪切板中的 Markdown 文件",
            openAccessibilityHint: "按 Return 打开 \(candidate.displayName)",
            dismissAccessibilityLabel: "忽略剪切板 Markdown 提示",
            dismissAccessibilityHint: "按 Return 忽略这次提示；文件不会被修改"
        )
    }
}

public struct RecentHistoryPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String?
    public var emptyMessage: String?
    public var emptyActionTitle: String?
    public var emptyActionHelp: String?
    public var emptyActionShortcutHint: String?
    public var emptyActionAccessibilityLabel: String?
    public var emptyActionAccessibilityHint: String?
    public var cleanupTitle: String?
    public var cleanupHelp: String?
    public var cleanupAccessibilityLabel: String?
    public var cleanupAccessibilityHint: String?

    public init(
        title: String,
        systemImage: String = "clock.arrow.circlepath",
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        emptyMessage: String? = nil,
        emptyActionTitle: String? = nil,
        emptyActionHelp: String? = nil,
        emptyActionShortcutHint: String? = nil,
        emptyActionAccessibilityLabel: String? = nil,
        emptyActionAccessibilityHint: String? = nil,
        cleanupTitle: String? = nil,
        cleanupHelp: String? = nil,
        cleanupAccessibilityLabel: String? = nil,
        cleanupAccessibilityHint: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.emptyMessage = emptyMessage
        self.emptyActionTitle = emptyActionTitle
        self.emptyActionHelp = emptyActionHelp
        self.emptyActionShortcutHint = emptyActionShortcutHint
        self.emptyActionAccessibilityLabel = emptyActionAccessibilityLabel
        self.emptyActionAccessibilityHint = emptyActionAccessibilityHint
        self.cleanupTitle = cleanupTitle
        self.cleanupHelp = cleanupHelp
        self.cleanupAccessibilityLabel = cleanupAccessibilityLabel
        self.cleanupAccessibilityHint = cleanupAccessibilityHint
    }

    public static func presentation(
        recentDocumentCount: Int,
        missingDocumentCount: Int = 0,
        unavailableDocumentCount: Int? = nil,
        saveState: SaveState = .idle
    ) -> RecentHistoryPresentation {
        let cleanedCount: Int? = {
            guard case let .historyCleaned(count) = saveState, count > 0 else {
                return nil
            }
            return count
        }()
        let clearedCount: Int? = {
            guard case let .historyCleared(count) = saveState, count > 0 else {
                return nil
            }
            return count
        }()
        let emptyHistoryHint = "暂无记录，按 Return 打开菜单；菜单焦点会停在打开 Markdown 动作"
        let emptyActionHelp = "选择 Markdown 文件开始阅读；成功打开后会加入历史（Return）"
        let emptyActionAccessibilityHint = "按 Return 选择 Markdown 文件；成功打开后会加入历史"

        guard recentDocumentCount > 0 else {
            if let clearedCount {
                return RecentHistoryPresentation(
                    title: "已清除",
                    systemImage: "checkmark.circle",
                    help: "已清除 \(clearedCount) 项打开历史；暂无打开历史，可打开 Markdown 后出现在这里",
                    accessibilityLabel: "打开历史，已清除 \(clearedCount) 项，暂无记录",
                    accessibilityHint: "清除完成，按 Return 打开菜单；菜单焦点会停在打开 Markdown 动作",
                    emptyMessage: "暂无打开历史",
                    emptyActionTitle: "打开 Markdown...",
                    emptyActionHelp: emptyActionHelp,
                    emptyActionShortcutHint: "Return",
                    emptyActionAccessibilityLabel: "打开 Markdown 文件",
                    emptyActionAccessibilityHint: emptyActionAccessibilityHint
                )
            }

            if let cleanedCount {
                return RecentHistoryPresentation(
                    title: "已清理",
                    systemImage: "checkmark.circle",
                    help: "已从打开历史移除 \(cleanedCount) 个失效项；暂无打开历史，可打开 Markdown 后出现在这里",
                    accessibilityLabel: "打开历史，已清理 \(cleanedCount) 个失效项，暂无记录",
                    accessibilityHint: "清理完成，按 Return 打开菜单；菜单焦点会停在打开 Markdown 动作",
                    emptyMessage: "暂无打开历史",
                    emptyActionTitle: "打开 Markdown...",
                    emptyActionHelp: emptyActionHelp,
                    emptyActionShortcutHint: "Return",
                    emptyActionAccessibilityLabel: "打开 Markdown 文件",
                    emptyActionAccessibilityHint: emptyActionAccessibilityHint
                )
            }

            return RecentHistoryPresentation(
                title: "历史",
                help: "暂无打开历史，可打开 Markdown 后出现在这里",
                accessibilityLabel: "打开历史，暂无记录",
                accessibilityHint: emptyHistoryHint,
                emptyMessage: "暂无打开历史",
                emptyActionTitle: "打开 Markdown...",
                emptyActionHelp: emptyActionHelp,
                emptyActionShortcutHint: "Return",
                emptyActionAccessibilityLabel: "打开 Markdown 文件",
                emptyActionAccessibilityHint: emptyActionAccessibilityHint
            )
        }

        let cleanupCount = unavailableDocumentCount ?? missingDocumentCount
        let missingSummary = cleanupCount > 0 ? "；\(cleanupCount) 项失效可清理" : ""
        let help = "打开历史菜单，共 \(recentDocumentCount) 项\(missingSummary)"
        let accessibilityHint = cleanupCount > 0
            ? "按 Return 打开历史菜单；菜单焦点会停在最近打开项；可清理 \(cleanupCount) 项失效记录"
            : "按 Return 打开历史菜单；菜单焦点会停在最近打开项"
        let cleanupTitle = cleanupCount > 0 ? "清理 \(cleanupCount) 个失效项" : nil
        let cleanupHelp = cleanupCount > 0 ? "从打开历史移除 \(cleanupCount) 个不存在或不是 Markdown 的文件记录" : nil
        let cleanupAccessibilityLabel = cleanupCount > 0 ? "清理 \(cleanupCount) 个失效历史项" : nil
        let cleanupAccessibilityHint = cleanupCount > 0 ? "按 Return 从打开历史移除 \(cleanupCount) 个失效记录并更新菜单；不会删除磁盘文件" : nil
        if let clearedCount {
            return RecentHistoryPresentation(
                title: "已清除",
                systemImage: "checkmark.circle",
                help: "已清除 \(clearedCount) 项打开历史；\(help)",
                accessibilityLabel: "打开历史，已清除 \(clearedCount) 项，\(recentDocumentCount) 项",
                accessibilityHint: "清除完成，仍可继续打开历史菜单；菜单焦点会停在最近打开项",
                cleanupTitle: cleanupTitle,
                cleanupHelp: cleanupHelp,
                cleanupAccessibilityLabel: cleanupAccessibilityLabel,
                cleanupAccessibilityHint: cleanupAccessibilityHint
            )
        }

        if let cleanedCount {
            return RecentHistoryPresentation(
                title: "已清理",
                systemImage: "checkmark.circle",
                help: "已从打开历史移除 \(cleanedCount) 个失效项；\(help)",
                accessibilityLabel: "打开历史，已清理 \(cleanedCount) 个失效项，\(recentDocumentCount) 项",
                accessibilityHint: "清理完成，仍可继续打开历史菜单；菜单焦点会停在最近打开项",
                cleanupTitle: cleanupTitle,
                cleanupHelp: cleanupHelp,
                cleanupAccessibilityLabel: cleanupAccessibilityLabel,
                cleanupAccessibilityHint: cleanupAccessibilityHint
            )
        }

        return RecentHistoryPresentation(
            title: "历史",
            help: help,
            accessibilityLabel: "打开历史，\(recentDocumentCount) 项",
            accessibilityHint: accessibilityHint,
            cleanupTitle: cleanupTitle,
            cleanupHelp: cleanupHelp,
            cleanupAccessibilityLabel: cleanupAccessibilityLabel,
            cleanupAccessibilityHint: cleanupAccessibilityHint
        )
    }
}

public struct RecentHistoryItemPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        url: URL,
        fileExists: Bool,
        isSupportedMarkdown: Bool = true,
        duplicateFilenameCount: Int = 1
    ) -> RecentHistoryItemPresentation {
        let filename = url.lastPathComponent
        let parentFolder = url.deletingLastPathComponent().lastPathComponent
        let needsParentFolder = duplicateFilenameCount > 1 && !parentFolder.isEmpty
        let titleSuffix = needsParentFolder ? " — \(parentFolder)" : ""
        let accessibilitySuffix = needsParentFolder ? "，位于 \(parentFolder)" : ""
        let pathDisambiguatedOpenHint = needsParentFolder
            ? "按 Return 打开 \(parentFolder) 中的 \(filename)；打开后菜单会关闭；完整路径可在提示中查看"
            : "按 Return 打开 \(filename)；打开后菜单会关闭；完整路径可在提示中查看"
        let removeAccessibilityHint = needsParentFolder
            ? "按 Return 从打开历史移除 \(parentFolder) 中的 \(filename) 并更新菜单；不会删除磁盘文件"
            : "按 Return 从打开历史移除该记录并更新菜单；不会删除磁盘文件"

        guard fileExists else {
            return RecentHistoryItemPresentation(
                title: "失效：\(filename)\(titleSuffix)",
                systemImage: "exclamationmark.triangle",
                help: "文件不存在，选择后会从历史移除：\(url.path)",
                accessibilityLabel: "失效的历史文件：\(filename)\(accessibilitySuffix)",
                accessibilityHint: removeAccessibilityHint
            )
        }

        guard isSupportedMarkdown else {
            return RecentHistoryItemPresentation(
                title: "不支持：\(filename)\(titleSuffix)",
                systemImage: "exclamationmark.triangle",
                help: "不是 Markdown 文件，选择后会从历史移除：\(url.path)",
                accessibilityLabel: "不支持的历史文件：\(filename)\(accessibilitySuffix)",
                accessibilityHint: removeAccessibilityHint
            )
        }

        return RecentHistoryItemPresentation(
            title: "\(filename)\(titleSuffix)",
            systemImage: "doc.text",
            help: url.path,
            accessibilityLabel: "打开历史文件：\(filename)\(accessibilitySuffix)",
            accessibilityHint: pathDisambiguatedOpenHint
        )
    }
}

public struct RecentHistoryClearPresentation: Equatable, Sendable {
    public var title: String
    public var help: String
    public var isEnabled: Bool
    public var isDestructive: Bool
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        help: String,
        isEnabled: Bool,
        isDestructive: Bool,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.help = help
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(recentDocumentCount: Int) -> RecentHistoryClearPresentation {
        guard recentDocumentCount > 0 else {
            return RecentHistoryClearPresentation(
                title: "清除打开历史",
                help: "暂无可清除的打开历史",
                isEnabled: false,
                isDestructive: false,
                accessibilityLabel: "清除打开历史",
                accessibilityHint: "暂无可清除的打开历史；打开 Markdown 后会出现在这里，清除动作会启用"
            )
        }

        return RecentHistoryClearPresentation(
            title: "清除打开历史",
            help: "清除 \(recentDocumentCount) 项历史记录，仅影响列表；菜单会更新，不会删除磁盘文件",
            isEnabled: true,
            isDestructive: true,
            accessibilityLabel: "清除 \(recentDocumentCount) 项打开历史",
            accessibilityHint: "按 Return 清除 \(recentDocumentCount) 项历史记录并更新菜单；不会删除磁盘文件"
        )
    }
}

public struct CollapsedOutlineRailPresentation: Equatable, Sendable {
    public var headingCountText: String?
    public var currentHeadingTitle: String?
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        headingCountText: String?,
        currentHeadingTitle: String?,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.headingCountText = headingCountText
        self.currentHeadingTitle = currentHeadingTitle
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        outline: [DocumentHeading],
        currentHeadingID: UUID?
    ) -> CollapsedOutlineRailPresentation {
        let flattened = outline.flattened()
        let currentTitle = currentHeadingID.flatMap { id in
            flattened.first { $0.id == id }?.title
        }
        let headingCountText = flattened.isEmpty ? nil : "\(flattened.count)"
        let helpParts = [
            "展开大纲",
            currentTitle.map { "当前章节：\($0)" },
            headingCountText.map { "共 \($0) 个标题" }
        ].compactMap(\.self)
        let accessibilityParts = [
            "大纲已折叠",
            currentTitle.map { "当前章节：\($0)" },
            headingCountText.map { "共 \($0) 个标题" }
        ].compactMap(\.self)

        return CollapsedOutlineRailPresentation(
            headingCountText: headingCountText,
            currentHeadingTitle: currentTitle,
            help: helpParts.joined(separator: "；"),
            accessibilityLabel: accessibilityParts.joined(separator: "，"),
            accessibilityHint: currentTitle.map { "按 Return 展开大纲；展开后可继续从当前章节\($0)导航" }
                ?? "按 Return 展开大纲；展开后可浏览标题列表"
        )
    }
}

public struct PromptActionButtonPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var lineLimit: Int
    public var minimumScaleFactor: CGFloat

    public init(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        lineLimit: Int = 1,
        minimumScaleFactor: CGFloat = 0.82
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.lineLimit = lineLimit
        self.minimumScaleFactor = minimumScaleFactor
    }

    public static func copy(
        hasPrompt: Bool,
        saveState: SaveState = .idle
    ) -> PromptActionButtonPresentation {
        if saveState.isPromptCopiedFeedback {
            return PromptActionButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                isEnabled: true,
                help: "Prompt 已复制",
                accessibilityLabel: "Prompt 已复制",
                accessibilityHint: "可继续复制当前 Prompt；按钮会短暂恢复"
            )
        }

        return PromptActionButtonPresentation(
            title: "复制 Prompt",
            systemImage: "doc.on.doc",
            isEnabled: true,
            help: hasPrompt ? "复制当前 Prompt" : "没有可复制内容时会提示先添加并勾选批注；不会修改剪切板",
            accessibilityLabel: "复制 Prompt",
            accessibilityHint: hasPrompt
                ? "按 Return 复制当前 Prompt；会先同步批注，复制后短暂显示已复制"
                : "按 Return 显示需要先添加并勾选批注的提示；不会修改剪切板"
        )
    }

    public static func save(
        hasPrompt: Bool,
        saveState: SaveState = .idle
    ) -> PromptActionButtonPresentation {
        if saveState.isPromptSavedFeedback {
            return PromptActionButtonPresentation(
                title: "已保存",
                systemImage: "checkmark.circle",
                isEnabled: true,
                help: "Prompt 已保存",
                accessibilityLabel: "Prompt 已保存",
                accessibilityHint: "可继续保存当前 Prompt；按钮会短暂恢复"
            )
        }

        return PromptActionButtonPresentation(
            title: "保存 .prompt.md",
            systemImage: "doc.badge.plus",
            isEnabled: hasPrompt,
            help: hasPrompt ? "保存当前 Prompt" : "添加并勾选批注生成 Prompt 后可保存",
            accessibilityLabel: "保存 Prompt 文件",
            accessibilityHint: hasPrompt
                ? "按 Return 保存当前 Prompt 到 .prompt.md 文件；会先同步批注，保存后短暂显示已保存"
                : "添加并勾选批注生成 Prompt 后可保存；当前不可用"
        )
    }
}

private extension SaveState {
    var isPromptCopiedFeedback: Bool {
        switch self {
        case .copied, .copiedWithReviewFallback:
            return true
        default:
            return false
        }
    }

    var isPromptSavedFeedback: Bool {
        switch self {
        case .promptSaved,
             .promptSavedToFallback,
             .promptSavedWithReviewFallback,
             .promptSavedToFallbackWithReviewFallback:
            return true
        default:
            return false
        }
    }
}

@MainActor
public struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("markprompt.outlineCollapsed") private var isOutlineCollapsed = false
    @AppStorage("markprompt.inspectorWidth") private var storedInspectorWidth = Double(RootLayoutMetrics.defaultInspectorWidth)
    @State private var inspectorDragStartWidth: CGFloat?
    @State private var liveInspectorWidth: CGFloat?
    @State private var isFileDropTargeted = false
    @State private var historyFeedbackDismissalTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Divider()

            if let candidate = appState.clipboardMarkdownCandidate {
                ClipboardMarkdownBannerView(
                    candidate: candidate,
                    onOpen: {
                        appState.openDocument(at: candidate.url)
                    },
                    onDismiss: {
                        appState.dismissClipboardMarkdownCandidate()
                    }
                )
                Divider()
            }

            HStack(spacing: 0) {
                if isOutlineCollapsed {
                    CollapsedOutlineRailView(
                        presentation: CollapsedOutlineRailPresentation.presentation(
                            outline: appState.currentDocument?.outline ?? [],
                            currentHeadingID: appState.currentReadingHeadingID
                        )
                    ) {
                        isOutlineCollapsed = false
                    }
                    .frame(width: RootLayoutMetrics.collapsedOutlineWidth)
                } else {
                    OutlineSidebarView {
                        isOutlineCollapsed = true
                    }
                    .frame(width: RootLayoutMetrics.expandedOutlineWidth)
                }

                Divider()

                MarkdownReaderView()
                    .frame(minWidth: 520, maxWidth: .infinity)

                InspectorResizeHandle(
                    width: inspectorWidthBinding,
                    dragStartWidth: $inspectorDragStartWidth,
                    onCommit: commitInspectorWidth
                )

                AnnotationPanelView()
                    .frame(width: inspectorWidth)
            }
        }
        .frame(minWidth: 1120, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if let presentation = DropTargetPresentation.presentation(
                isTargeted: isFileDropTargeted,
                saveState: appState.saveState,
                hasOpenDocument: appState.currentDocument != nil
            ) {
                DropTargetOverlayView(
                    presentation: presentation,
                    onCopy: { message in
                        appState.copyStatusMessageToPasteboard(message)
                    },
                    onDismiss: {
                        appState.dismissTransientImportFailure()
                    }
                )
                .allowsHitTesting(presentation.dismissTitle != nil)
            }
        }
        .onAppear {
            appState.refreshClipboardMarkdownCandidate()
            scheduleHistoryFeedbackDismissal(for: appState.saveState)
        }
        .onDisappear {
            historyFeedbackDismissalTask?.cancel()
            historyFeedbackDismissalTask = nil
        }
        .onChange(of: appState.saveState) { _, saveState in
            scheduleHistoryFeedbackDismissal(for: saveState)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshClipboardMarkdownCandidate()
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            appState.refreshClipboardMarkdownCandidate()
        }
        .onOpenURL { url in
            appState.openDocument(at: url)
        }
        .onDrop(of: [.fileURL], isTargeted: $isFileDropTargeted) { providers in
            appState.openDroppedDocument(from: providers)
        }
        .onPasteCommand(of: [.fileURL]) { providers in
            appState.openDroppedDocument(from: providers)
        }
    }

    private var inspectorWidth: CGFloat {
        liveInspectorWidth ?? RootLayoutMetrics.clampedInspectorWidth(CGFloat(storedInspectorWidth))
    }

    private var inspectorWidthBinding: Binding<CGFloat> {
        Binding(
            get: { inspectorWidth },
            set: { liveInspectorWidth = RootLayoutMetrics.clampedInspectorWidth($0) }
        )
    }

    private func commitInspectorWidth(_ width: CGFloat) {
        let committedWidth = RootLayoutMetrics.committedInspectorWidth(afterLiveDragWidth: width)
        storedInspectorWidth = Double(committedWidth)
        liveInspectorWidth = nil
    }

    private func scheduleHistoryFeedbackDismissal(for saveState: SaveState) {
        historyFeedbackDismissalTask?.cancel()
        historyFeedbackDismissalTask = nil

        guard saveState.isTransientHistoryFeedback else {
            return
        }

        historyFeedbackDismissalTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else {
                return
            }

            appState.dismissTransientHistoryFeedback()
        }
    }

    private var topToolbar: some View {
        let openPresentation = ToolbarOpenPresentation.presentation()
        let searchPresentation = ToolbarSearchPresentation.presentation(
            hasOpenDocument: appState.currentDocument != nil
        )
        let copyPresentation = PromptActionButtonPresentation.copy(
            hasPrompt: !appState.promptPreview.prompt.isEmpty,
            saveState: appState.saveState
        )
        let titlePresentation = ToolbarDocumentTitlePresentation.presentation(
            displayName: appState.currentDocument?.displayName,
            fileURL: appState.currentDocument?.fileURL
        )
        let historyDuplicateFilenameCounts = recentHistoryDuplicateFilenameCounts(
            for: appState.recentDocumentURLs
        )

        return HStack(spacing: 12) {
            Menu {
                Button(openPresentation.actionTitle) {
                    appState.openDocumentWithPanel()
                }
                .help(openPresentation.actionHelp)
                .accessibilityLabel(openPresentation.actionAccessibilityLabel)
                .accessibilityHint(openPresentation.actionAccessibilityHint)

                if appState.recentDocumentURLs.isEmpty == false {
                    Divider()

                    Section("打开历史") {
                        ForEach(appState.recentDocumentURLs, id: \.path) { url in
                            let itemPresentation = RecentHistoryItemPresentation.presentation(
                                url: url,
                                fileExists: FileManager.default.fileExists(atPath: url.path),
                                isSupportedMarkdown: supportedRecentHistoryMarkdownExtensions.contains(url.pathExtension.lowercased()),
                                duplicateFilenameCount: historyDuplicateFilenameCounts[url.lastPathComponent] ?? 1
                            )

                            Button {
                                appState.openRecentDocument(at: url)
                            } label: {
                                Label(itemPresentation.title, systemImage: itemPresentation.systemImage)
                            }
                            .help(itemPresentation.help)
                            .accessibilityLabel(itemPresentation.accessibilityLabel)
                            .accessibilityHint(itemPresentation.accessibilityHint)
                        }
                    }

                    Divider()

                    let clearPresentation = RecentHistoryClearPresentation.presentation(
                        recentDocumentCount: appState.recentDocumentURLs.count
                    )
                    Button(clearPresentation.title, role: clearPresentation.isDestructive ? .destructive : nil) {
                        appState.clearRecentDocuments()
                    }
                    .disabled(!clearPresentation.isEnabled)
                    .help(clearPresentation.help)
                    .accessibilityLabel(clearPresentation.accessibilityLabel)
                    .accessibilityHint(clearPresentation.accessibilityHint)
                }
            } label: {
                Label(openPresentation.title, systemImage: openPresentation.systemImage)
            }
            .help(openPresentation.help)
            .accessibilityLabel(openPresentation.accessibilityLabel)
            .accessibilityHint(openPresentation.accessibilityHint)

            RecentHistoryMenu(
                recentDocumentURLs: appState.recentDocumentURLs,
                saveState: appState.saveState,
                onOpenDocument: {
                    appState.openDocumentWithPanel()
                },
                onOpen: { url in
                    appState.openRecentDocument(at: url)
                },
                onRemoveMissing: {
                    appState.removeUnavailableRecentDocuments()
                },
                onClear: {
                    appState.clearRecentDocuments()
                }
            )

            Spacer()

            Text(titlePresentation.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
                .help(titlePresentation.help)
                .accessibilityLabel(titlePresentation.accessibilityLabel)

            Spacer()

            Button {
                performFindInReader()
            } label: {
                Label(searchPresentation.title, systemImage: searchPresentation.systemImage)
            }
            .disabled(!searchPresentation.isEnabled)
            .help(searchPresentation.help)
            .accessibilityLabel(searchPresentation.accessibilityLabel)
            .accessibilityHint(searchPresentation.accessibilityHint)

            Button {
                appState.copyPromptToPasteboard()
            } label: {
                Label(copyPresentation.title, systemImage: copyPresentation.systemImage)
                    .lineLimit(copyPresentation.lineLimit)
                    .minimumScaleFactor(copyPresentation.minimumScaleFactor)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!copyPresentation.isEnabled)
            .help(copyPresentation.help)
            .accessibilityLabel(copyPresentation.accessibilityLabel)
            .accessibilityHint(copyPresentation.accessibilityHint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func performFindInReader() {
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: item)
    }
}

private struct RecentHistoryMenu: View {
    var recentDocumentURLs: [URL]
    var saveState: SaveState
    var onOpenDocument: () -> Void
    var onOpen: (URL) -> Void
    var onRemoveMissing: () -> Void
    var onClear: () -> Void

    var body: some View {
        let unavailableDocumentCount = recentHistoryUnavailableDocumentCount(for: recentDocumentURLs)
        let presentation = RecentHistoryPresentation.presentation(
            recentDocumentCount: recentDocumentURLs.count,
            unavailableDocumentCount: unavailableDocumentCount,
            saveState: saveState
        )
        let duplicateFilenameCounts = recentHistoryDuplicateFilenameCounts(for: recentDocumentURLs)

        Menu {
            if recentDocumentURLs.isEmpty {
                if let emptyMessage = presentation.emptyMessage {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                }

                if let emptyActionTitle = presentation.emptyActionTitle {
                    Button(emptyActionTitle) {
                        onOpenDocument()
                    }
                .help(presentation.emptyActionHelp ?? emptyActionTitle)
                    .accessibilityLabel(presentation.emptyActionAccessibilityLabel ?? emptyActionTitle)
                    .accessibilityHint(presentation.emptyActionAccessibilityHint ?? "")
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                ForEach(recentDocumentURLs, id: \.path) { url in
                    let itemPresentation = RecentHistoryItemPresentation.presentation(
                        url: url,
                        fileExists: FileManager.default.fileExists(atPath: url.path),
                        isSupportedMarkdown: supportedRecentHistoryMarkdownExtensions.contains(url.pathExtension.lowercased()),
                        duplicateFilenameCount: duplicateFilenameCounts[url.lastPathComponent] ?? 1
                    )

                    Button {
                        onOpen(url)
                    } label: {
                        Label(itemPresentation.title, systemImage: itemPresentation.systemImage)
                    }
                    .help(itemPresentation.help)
                    .accessibilityLabel(itemPresentation.accessibilityLabel)
                    .accessibilityHint(itemPresentation.accessibilityHint)
                }

                Divider()

                if let cleanupTitle = presentation.cleanupTitle {
                    Button(cleanupTitle) {
                        onRemoveMissing()
                    }
                    .help(presentation.cleanupHelp ?? cleanupTitle)
                    .accessibilityLabel(presentation.cleanupAccessibilityLabel ?? cleanupTitle)
                    .accessibilityHint(presentation.cleanupAccessibilityHint ?? "")

                    Divider()
                }

                let clearPresentation = RecentHistoryClearPresentation.presentation(
                    recentDocumentCount: recentDocumentURLs.count
                )
                Button(clearPresentation.title, role: clearPresentation.isDestructive ? .destructive : nil) {
                    onClear()
                }
                .disabled(!clearPresentation.isEnabled)
                .help(clearPresentation.help)
                .accessibilityLabel(clearPresentation.accessibilityLabel)
                .accessibilityHint(clearPresentation.accessibilityHint)
            }
        } label: {
            Label(presentation.title, systemImage: presentation.systemImage)
        }
        .help(presentation.help)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityHint(presentation.accessibilityHint ?? "")
    }
}

private struct ClipboardMarkdownBannerView: View {
    var candidate: ClipboardMarkdownCandidate
    var onOpen: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        let presentation = ClipboardMarkdownBannerPresentation.presentation(candidate: candidate)

        HStack(spacing: 10) {
            Label(presentation.title, systemImage: "doc.text")
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(presentation.help)
                .accessibilityLabel(presentation.accessibilityLabel)
                .accessibilityHint(presentation.accessibilityHint)

            Spacer()

            Button("打开") {
                onOpen()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help(presentation.openHelp)
            .accessibilityLabel(presentation.openAccessibilityLabel)
            .accessibilityHint(presentation.openAccessibilityHint)

            Button("忽略") {
                onDismiss()
            }
            .controlSize(.small)
            .help(presentation.dismissHelp)
            .accessibilityLabel(presentation.dismissAccessibilityLabel)
            .accessibilityHint(presentation.dismissAccessibilityHint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }
}

private struct DropTargetOverlayView: View {
    var presentation: DropTargetPresentation
    var onCopy: (String) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    @State private var copiedValue: String?

    private var indicatorColor: Color {
        presentation.isFailure ? .orange : .accentColor
    }

    var body: some View {
        ZStack {
            if presentation.showsDropBoundary {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(indicatorColor.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .background(indicatorColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(14)
            }

            overlayCard
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: presentation.showsDropBoundary ? .center : .top
        )
        .padding(.top, presentation.showsDropBoundary ? 0 : 18)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityHint(presentation.accessibilityHint ?? "")
    }

    private var overlayCard: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 8) {
                if presentation.showsProgress {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: presentation.systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(indicatorColor)
                }
                Text(presentation.title)
                    .font(.headline)
                Text(presentation.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(presentation.messageLineLimit)
                    .truncationMode(.middle)
                    .help(presentation.messageHelp ?? presentation.message)
            }

            if let copyTitle = presentation.copyTitle,
               let copyValue = presentation.copyValue {
                let copyButton = DropTargetCopyButtonPresentation.presentation(
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
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(copyButton.help)
                .accessibilityLabel(copiedValue == copyValue ? copyButton.accessibilityLabel : presentation.copyAccessibilityLabel ?? copyButton.accessibilityLabel)
                .accessibilityHint(copiedValue == copyValue ? copyButton.accessibilityHint : presentation.copyAccessibilityHint ?? copyButton.accessibilityHint)
            }

            if let dismissTitle = presentation.dismissTitle {
                let dismissButton = DropTargetDismissButtonPresentation.presentation(
                    title: dismissTitle,
                    help: presentation.dismissHelp,
                    shortcutHint: presentation.dismissShortcutHint
                )
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(dismissButton.help)
                .accessibilityLabel(presentation.dismissAccessibilityLabel ?? dismissButton.accessibilityLabel)
                .accessibilityHint(presentation.dismissAccessibilityHint ?? dismissButton.accessibilityHint)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(indicatorColor.opacity(0.35), lineWidth: 1)
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

private func recentHistoryDuplicateFilenameCounts(for urls: [URL]) -> [String: Int] {
    Dictionary(grouping: urls, by: \.lastPathComponent).mapValues(\.count)
}

private func recentHistoryUnavailableDocumentCount(for urls: [URL]) -> Int {
    urls.filter { url in
        FileManager.default.fileExists(atPath: url.path) == false || supportedRecentHistoryMarkdownExtensions.contains(url.pathExtension.lowercased()) == false
    }.count
}

private let supportedRecentHistoryMarkdownExtensions: Set<String> = ["md", "markdown"]

private struct CollapsedOutlineRailView: View {
    var presentation: CollapsedOutlineRailPresentation
    var onExpand: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onExpand()
            } label: {
                Image(systemName: "sidebar.leading")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help(presentation.help)
            .accessibilityLabel("展开大纲")
            .accessibilityHint(presentation.accessibilityHint)

            VStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .foregroundStyle(presentation.currentHeadingTitle == nil ? .secondary : .primary)

                if let headingCountText = presentation.headingCountText {
                    Text(headingCountText)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                }

                if presentation.currentHeadingTitle != nil {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 18, height: 3)
                }
            }
            .help(presentation.help)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityHint(presentation.accessibilityHint)

            Spacer()
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct InspectorResizeHandle: View {
    @Binding var width: CGFloat
    @Binding var dragStartWidth: CGFloat?
    var onCommit: (CGFloat) -> Void
    @State private var isHovering = false

    var body: some View {
        let isDragging = dragStartWidth != nil
        let boundary = RootLayoutMetrics.inspectorResizeBoundary(for: width)
        let isActive = isHovering || isDragging
        let presentation = InspectorResizeHandlePresentation.presentation(
            width: width,
            isHovering: isHovering,
            isDragging: isDragging
        )

        ZStack {
            Rectangle()
                .fill(indicatorColor(boundary: boundary, isActive: isActive))
                .frame(width: presentation.indicatorWidth)

            ResizeCursorView()
                .frame(width: presentation.hitTargetWidth)

            Rectangle()
                .fill(Color.clear)
                .frame(width: presentation.hitTargetWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            NSCursor.resizeLeftRight.set()
                            let startWidth = dragStartWidth ?? width
                            if dragStartWidth == nil {
                                dragStartWidth = startWidth
                            }
                            withTransaction(Transaction(animation: nil)) {
                                width = RootLayoutMetrics.inspectorLiveWidth(
                                    storedWidth: width,
                                    dragStartWidth: startWidth,
                                    dragTranslationX: value.translation.width
                                )
                            }
                        }
                        .onEnded { _ in
                            let committedWidth = RootLayoutMetrics.committedInspectorWidth(afterLiveDragWidth: width)
                            dragStartWidth = nil
                            onCommit(committedWidth)
                            NSCursor.arrow.set()
                        }
                )
        }
        .frame(width: presentation.hitTargetWidth)
        .background(
            Rectangle()
                .fill(Color.accentColor.opacity(presentation.backgroundOpacity))
        )
        .contentShape(Rectangle())
        .onHover { isHovering in
            self.isHovering = isHovering
            if isHovering {
                NSCursor.resizeLeftRight.set()
            } else if dragStartWidth == nil {
                NSCursor.arrow.set()
            }
        }
        .onDisappear {
            if dragStartWidth == nil {
                NSCursor.arrow.set()
            }
        }
        .help(presentation.help)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint(presentation.accessibilityHint)
    }

    private func indicatorColor(boundary: InspectorResizeBoundary?, isActive: Bool) -> Color {
        if boundary != nil {
            return Color.accentColor.opacity(isActive ? 0.85 : 0.55)
        }

        return isActive ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor)
    }
}

private struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ResizeCursorNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ResizeCursorNSView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
