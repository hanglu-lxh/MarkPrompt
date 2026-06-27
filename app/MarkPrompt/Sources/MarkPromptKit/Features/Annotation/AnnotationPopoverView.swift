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
            shortcutHint: "保存 Return · 取消 Esc",
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
    @FocusState private var isCommentFocused: Bool

    public init() {}

    public var body: some View {
        let presentation = AnnotationPopoverPresentation.presentation(
            selectedText: appState.readerSelection?.selectedText ?? "",
            comment: comment
        )

        VStack(alignment: .leading, spacing: 12) {
            Text("添加批注")
                .font(.headline)

            VStack(alignment: .leading, spacing: 5) {
                Text("选中文本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(presentation.selectedTextPreview)
                    .font(.callout)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("批注意见")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $comment)
                    .font(.body)
                    .frame(width: 300, height: 94)
                    .focused($isCommentFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
                ForEach(QuickPromptCatalog.defaults) { definition in
                    Button(definition.label) {
                        applyQuickPrompt(definition)
                    }
                    .controlSize(.small)
                }
            }

            HStack {
                Text(presentation.shortcutHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("取消") {
                    appState.cancelAnnotation()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    appState.createAnnotation(comment: comment, quickPrompts: quickPrompts)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!presentation.canSave)
            }
        }
        .padding(14)
        .frame(width: 330)
        .onAppear {
            comment = ""
            quickPrompts = []
            isCommentFocused = true
        }
    }

    private func applyQuickPrompt(_ definition: QuickPromptDefinition) {
        comment = QuickPromptCatalog.insertedComment(currentComment: comment, definition: definition)

        guard !quickPrompts.contains(where: { $0.id == definition.id }) else {
            return
        }

        quickPrompts.append(
            QuickPromptUsage(
                id: definition.id,
                label: definition.label,
                insertedText: definition.insertedText
            )
        )
    }
}
