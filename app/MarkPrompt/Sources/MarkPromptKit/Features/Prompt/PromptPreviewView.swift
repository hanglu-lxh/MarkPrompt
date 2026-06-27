import SwiftUI

public struct PromptPreviewPresentation: Equatable, Sendable {
    public var previewText: String
    public var systemImage: String?
    public var isPlaceholder: Bool
    public var placeholderLineLimit: Int
    public var placeholderMinimumScaleFactor: CGFloat
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        previewText: String,
        systemImage: String?,
        isPlaceholder: Bool,
        placeholderLineLimit: Int = 3,
        placeholderMinimumScaleFactor: CGFloat = 0.86,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.previewText = previewText
        self.systemImage = systemImage
        self.isPlaceholder = isPlaceholder
        self.placeholderLineLimit = placeholderLineLimit
        self.placeholderMinimumScaleFactor = placeholderMinimumScaleFactor
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        state: PromptPreviewState,
        hasOpenDocument: Bool
    ) -> PromptPreviewPresentation {
        if !state.prompt.isEmpty {
            let noteCountText = state.includedNoteCount > 0 ? "，\(state.includedNoteCount) 条批注" : ""
            return PromptPreviewPresentation(
                previewText: state.prompt,
                systemImage: nil,
                isPlaceholder: false,
                accessibilityLabel: "Prompt 预览，已生成 Prompt\(noteCountText)",
                accessibilityHint: "可选择文本复制；复制或保存按钮会先同步批注再执行"
            )
        }

        if let warning = state.warnings.first {
            return PromptPreviewPresentation(
                previewText: warning,
                systemImage: "exclamationmark.triangle",
                isPlaceholder: true,
                accessibilityLabel: "Prompt 预览，有批注需要确认",
                accessibilityHint: "先重新定位或排除失效批注；Prompt 暂不可复制或保存"
            )
        }

        if hasOpenDocument {
            return PromptPreviewPresentation(
                previewText: "暂无纳入 Prompt 的批注。",
                systemImage: "text.badge.plus",
                isPlaceholder: true,
                accessibilityLabel: "Prompt 预览，暂无纳入 Prompt 的批注",
                accessibilityHint: "先在批注卡片勾选纳入 Prompt；复制动作会提示但不会修改剪切板"
            )
        }

        return PromptPreviewPresentation(
            previewText: "打开 Markdown 后显示 Prompt。",
            systemImage: "doc.text",
            isPlaceholder: true,
            accessibilityLabel: "Prompt 预览，未打开文档",
            accessibilityHint: "按 ⌘O 打开 Markdown；生成 Prompt 后复制和保存动作会可用"
        )
    }
}

public struct PromptPreviewHeaderPresentation: Equatable, Sendable {
    public var countText: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        countText: String,
        help: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.countText = countText
        self.help = help
        self.accessibilityLabel = accessibilityLabel ?? "Prompt 预览状态：\(countText)"
        self.accessibilityHint = accessibilityHint ?? help
    }

    public static func presentation(
        state: PromptPreviewState,
        hasOpenDocument: Bool
    ) -> PromptPreviewHeaderPresentation {
        guard hasOpenDocument else {
            return PromptPreviewHeaderPresentation(
                countText: "未打开文档",
                help: "打开 Markdown 后会统计纳入 Prompt 的批注；复制和保存动作会随 Prompt 启用"
            )
        }

        if state.warnings.isEmpty == false {
            return PromptPreviewHeaderPresentation(
                countText: "\(state.warnings.count) 条需确认",
                help: "有批注需要重新定位或排除后再使用 Prompt；复制和保存暂不可用"
            )
        }

        guard state.includedNoteCount > 0 else {
            return PromptPreviewHeaderPresentation(
                countText: "未选择批注",
                help: "勾选批注后会进入 Prompt；复制动作会提示但不会修改剪切板"
            )
        }

        return PromptPreviewHeaderPresentation(
            countText: "已选择 \(state.includedNoteCount) 条批注",
            help: "当前 Prompt 将使用 \(state.includedNoteCount) 条批注；复制或保存会先同步批注"
        )
    }
}

public struct PromptPreviewWarningPresentation: Equatable, Sendable {
    public var message: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var lineLimit: Int

    public init(
        message: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        lineLimit: Int = 2
    ) {
        self.message = message
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel ?? "Prompt 警告：\(message)"
        self.accessibilityHint = accessibilityHint ?? help
        self.lineLimit = lineLimit
    }

    public static func presentation(state: PromptPreviewState) -> PromptPreviewWarningPresentation? {
        guard let warning = state.warnings.first else {
            return nil
        }

        return PromptPreviewWarningPresentation(
            message: warning,
            systemImage: "exclamationmark.triangle",
            help: "重新定位或排除这条批注后再使用 Prompt；可用批注仍会显示在预览中",
            accessibilityHint: "先处理这条批注；可用批注仍可复制和保存"
        )
    }
}

@MainActor
public struct PromptPreviewView: View {
    public var state: PromptPreviewState
    public var hasOpenDocument: Bool
    public var compact: Bool

    public init(state: PromptPreviewState, hasOpenDocument: Bool = true, compact: Bool = false) {
        self.state = state
        self.hasOpenDocument = hasOpenDocument
        self.compact = compact
    }

    public var body: some View {
        let presentation = PromptPreviewPresentation.presentation(
            state: state,
            hasOpenDocument: hasOpenDocument
        )
        let headerPresentation = PromptPreviewHeaderPresentation.presentation(
            state: state,
            hasOpenDocument: hasOpenDocument
        )
        let warningPresentation = state.prompt.isEmpty
            ? nil
            : PromptPreviewWarningPresentation.presentation(state: state)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prompt 预览")
                    .font(.headline)
                Spacer()
                Text(headerPresentation.countText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(headerPresentation.help)
                    .accessibilityLabel(headerPresentation.accessibilityLabel)
                    .accessibilityHint(headerPresentation.accessibilityHint)
            }

            if let warningPresentation {
                Label(warningPresentation.message, systemImage: warningPresentation.systemImage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(warningPresentation.lineLimit)
                    .truncationMode(.middle)
                    .help(warningPresentation.help)
                    .accessibilityLabel(warningPresentation.accessibilityLabel)
                    .accessibilityHint(warningPresentation.accessibilityHint)
            }

            ScrollView {
                if presentation.isPlaceholder {
                    VStack(spacing: 8) {
                        if let systemImage = presentation.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: compact ? 18 : 24))
                                .foregroundStyle(.secondary)
                        }
                        Text(presentation.previewText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(presentation.placeholderLineLimit)
                            .minimumScaleFactor(presentation.placeholderMinimumScaleFactor)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? 92 : 220)
                    .padding(12)
                } else {
                    Text(presentation.previewText)
                        .font(.system(size: compact ? 12 : 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
            .frame(minHeight: compact ? 130 : 320)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityHint(presentation.accessibilityHint)
        }
    }
}
