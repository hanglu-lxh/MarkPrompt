import AppKit
import SwiftUI

public struct AnnotationPopoverPresentation: Equatable, Sendable {
    public var selectedTextPreview: String
    public var shortcutHint: String
    public var canSave: Bool

    public init(selectedTextPreview: String, shortcutHint: String, canSave: Bool) {
        self.selectedTextPreview = selectedTextPreview
        self.shortcutHint = shortcutHint
        self.canSave = canSave
    }

    public static func presentation(selectedText: String, comment: String) -> AnnotationPopoverPresentation {
        AnnotationPopoverPresentation(
            selectedTextPreview: compactPreview(for: selectedText),
            shortcutHint: "保存 ⌘↩ · 取消 Esc",
            canSave: comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        )
    }

    private static func compactPreview(for text: String, limit: Int = 60) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard normalized.count > limit else {
            return normalized
        }

        return String(normalized.prefix(limit)) + "…"
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
        let selectedQuickPromptID = quickPrompts.first?.id

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
                .help("关闭")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("批注原文")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                AnnotationSourceQuoteView(text: presentation.selectedTextPreview, lineLimit: 1)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(QuickPromptCatalog.defaults) { definition in
                    AnnotationQuickPromptButton(
                        title: definition.label,
                        isSelected: selectedQuickPromptID == definition.id
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
                    Label("删除", systemImage: "trash")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    appState.createAnnotation(comment: comment, quickPrompts: quickPrompts)
                } label: {
                    AnnotationPrimaryPillLabel(
                        title: "添加批注",
                        systemImage: "checkmark",
                        isEnabled: presentation.canSave
                    )
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.plain)
                .disabled(!presentation.canSave)
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
        guard quickPrompts.first?.id != definition.id else {
            focusCommentEditor()
            return
        }

        comment = quickPrompts.isEmpty
            ? QuickPromptCatalog.insertedComment(currentComment: comment, definition: definition)
            : definition.insertedText
        quickPrompts = [
            QuickPromptUsage(
                id: definition.id,
                label: definition.label,
                insertedText: definition.insertedText
            )
        ]
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
