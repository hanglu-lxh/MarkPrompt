import SwiftUI

@MainActor
public struct AnnotationPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @State private var comment = ""
    @State private var quickPrompts: [QuickPromptUsage] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加批注")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("批注意见")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $comment)
                    .font(.body)
                    .frame(width: 300, height: 94)
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
                .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 330)
        .onAppear {
            comment = ""
            quickPrompts = []
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
