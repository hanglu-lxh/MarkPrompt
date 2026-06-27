import AppKit
import SwiftUI

public struct AnnotationPopoverPresentation: Equatable, Sendable {
    public var selectedTextPreview: String
    public var selectedTextHelp: String
    public var selectedTextAccessibilityLabel: String
    public var selectedTextAccessibilityHint: String
    public var shortcutHint: String
    public var cancelTitle: String
    public var cancelHelp: String
    public var cancelAccessibilityLabel: String
    public var cancelAccessibilityHint: String
    public var saveTitle: String
    public var saveHelp: String
    public var saveAccessibilityLabel: String
    public var saveAccessibilityHint: String
    public var commentAccessibilityLabel: String
    public var commentAccessibilityHint: String
    public var canSave: Bool

    public init(
        selectedTextPreview: String,
        selectedTextHelp: String,
        selectedTextAccessibilityLabel: String,
        selectedTextAccessibilityHint: String,
        shortcutHint: String,
        cancelTitle: String = "取消",
        cancelHelp: String = "取消批注（Esc）；不会保存当前草稿",
        cancelAccessibilityLabel: String = "取消批注",
        cancelAccessibilityHint: String = "按 Esc 关闭批注窗口；不会保存当前草稿，阅读位置保持不变",
        saveTitle: String = "添加批注",
        saveHelp: String,
        saveAccessibilityLabel: String? = nil,
        saveAccessibilityHint: String? = nil,
        commentAccessibilityLabel: String = "批注意见",
        commentAccessibilityHint: String = "输入批注意见；可使用快捷批注按钮补全文本",
        canSave: Bool
    ) {
        self.selectedTextPreview = selectedTextPreview
        self.selectedTextHelp = selectedTextHelp
        self.selectedTextAccessibilityLabel = selectedTextAccessibilityLabel
        self.selectedTextAccessibilityHint = selectedTextAccessibilityHint
        self.shortcutHint = shortcutHint
        self.cancelTitle = cancelTitle
        self.cancelHelp = cancelHelp
        self.cancelAccessibilityLabel = cancelAccessibilityLabel
        self.cancelAccessibilityHint = cancelAccessibilityHint
        self.saveTitle = saveTitle
        self.saveHelp = saveHelp
        self.saveAccessibilityLabel = saveAccessibilityLabel ?? saveTitle
        self.saveAccessibilityHint = saveAccessibilityHint ?? (canSave ? "按 ⌘↩ 添加批注" : saveHelp)
        self.commentAccessibilityLabel = commentAccessibilityLabel
        self.commentAccessibilityHint = commentAccessibilityHint
        self.canSave = canSave
    }

    public static func presentation(selectedText: String, comment: String) -> AnnotationPopoverPresentation {
        let canSave = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let normalizedSelectedText = normalizedPreviewText(for: selectedText)
        let isSelectedTextTruncated = normalizedSelectedText.count > 60
        let selectedTextLabel = normalizedSelectedText.isEmpty
            ? "批注原文：未选中文本"
            : "批注原文：\(normalizedSelectedText)"
        return AnnotationPopoverPresentation(
            selectedTextPreview: compactPreview(for: selectedText),
            selectedTextHelp: selectedTextLabel,
            selectedTextAccessibilityLabel: selectedTextLabel,
            selectedTextAccessibilityHint: isSelectedTextTruncated
                ? "预览已截断；完整原文可通过帮助提示查看"
                : "当前批注会绑定到这段原文",
            shortcutHint: "保存 ⌘↩ · 取消 Esc",
            cancelTitle: "取消",
            saveTitle: "添加批注",
            saveHelp: canSave
                ? "添加批注（⌘↩）；保存后会选中新批注"
                : "输入批注意见后可添加批注；当前不会保存空批注",
            saveAccessibilityHint: canSave
                ? "按 ⌘↩ 添加批注；保存后会选中新批注并关闭输入框"
                : "当前不可添加；批注意见不能为空，输入内容后可按 ⌘↩ 添加批注",
            commentAccessibilityHint: canSave
                ? "按 ⌘↩ 添加批注；Esc 取消，快捷批注会追加到此输入框"
                : "批注意见不能为空；输入内容后可按 ⌘↩ 添加批注",
            canSave: canSave
        )
    }

    private static func compactPreview(for text: String, limit: Int = 60) -> String {
        let normalized = normalizedPreviewText(for: text)
        guard normalized.count > limit else {
            return normalized
        }

        return String(normalized.prefix(limit)) + "…"
    }

    private static func normalizedPreviewText(for text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

@MainActor
public struct AnnotationPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @State private var comment = ""
    @State private var quickPrompts: [QuickPromptUsage] = []
    @State private var isCommentFocused = false
    @State private var focusRequest = 0

    public init() {}

    public var body: some View {
        let presentation = AnnotationPopoverPresentation.presentation(
            selectedText: appState.readerSelection?.selectedText ?? "",
            comment: comment
        )
        let selectedQuickPromptIDs = Set(quickPrompts.map(\.id))

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("批注")
                    .font(.headline)

                Spacer()

                Button {
                    appState.cancelAnnotation()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(presentation.cancelHelp)
                .accessibilityLabel(presentation.cancelAccessibilityLabel)
                .accessibilityHint(presentation.cancelAccessibilityHint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("批注原文")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                AnnotationSourceQuoteView(
                    text: presentation.selectedTextPreview,
                    lineLimit: 1,
                    help: presentation.selectedTextHelp,
                    accessibilityLabel: presentation.selectedTextAccessibilityLabel,
                    accessibilityHint: presentation.selectedTextAccessibilityHint
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(QuickPromptCatalog.defaults) { definition in
                    AnnotationQuickPromptButton(
                        title: definition.label,
                        isSelected: selectedQuickPromptIDs.contains(definition.id)
                    ) {
                        applyQuickPrompt(definition)
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                CommentTextEditor(
                    text: $comment,
                    isFocused: $isCommentFocused,
                    focusRequest: focusRequest
                )

                if comment.isEmpty, !isCommentFocused {
                    Text("输入批注意见...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(height: 102)
            .accessibilityLabel(presentation.commentAccessibilityLabel)
            .accessibilityHint(presentation.commentAccessibilityHint)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isCommentFocused ? Color(nsColor: .secondaryLabelColor) : Color(nsColor: .separatorColor),
                        lineWidth: isCommentFocused ? 1.4 : 1
                    )
            )

            HStack {
                Button {
                    appState.cancelAnnotation()
                } label: {
                    Label(presentation.cancelTitle, systemImage: "xmark")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(presentation.cancelHelp)
                .accessibilityLabel(presentation.cancelAccessibilityLabel)
                .accessibilityHint(presentation.cancelAccessibilityHint)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    appState.createAnnotation(comment: comment, quickPrompts: quickPrompts)
                } label: {
                    AnnotationPrimaryPillLabel(
                        title: presentation.saveTitle,
                        systemImage: "checkmark",
                        isEnabled: presentation.canSave
                    )
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.plain)
                .disabled(!presentation.canSave)
                .help(presentation.saveHelp)
                .accessibilityLabel(presentation.saveAccessibilityLabel)
                .accessibilityHint(presentation.saveAccessibilityHint)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 380, height: 330, alignment: .top)
        .onAppear {
            comment = ""
            quickPrompts = []
            focusCommentEditor()
        }
    }

    private func applyQuickPrompt(_ definition: QuickPromptDefinition) {
        guard !quickPrompts.contains(where: { $0.id == definition.id }) else {
            focusCommentEditor()
            return
        }

        comment = QuickPromptCatalog.insertedComment(currentComment: comment, definition: definition)
        quickPrompts.append(
            QuickPromptUsage(
                id: definition.id,
                label: definition.label,
                insertedText: definition.insertedText
            )
        )
        focusCommentEditor()
    }

    private func focusCommentEditor() {
        DispatchQueue.main.async {
            focusRequest += 1
        }
    }
}

private struct CommentTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var focusRequest: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = Self.textFont
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.string = text

        context.coordinator.textView = textView
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }
        if textView.font != Self.textFont {
            textView.font = Self.textFont
        }

        guard context.coordinator.lastFocusRequest != focusRequest else {
            return
        }

        context.coordinator.lastFocusRequest = focusRequest
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
    }

    private static var textFont: NSFont {
        NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        weak var textView: NSTextView?
        var lastFocusRequest = 0

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text.wrappedValue = textView.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            isFocused.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isFocused.wrappedValue = false
        }
    }
}
