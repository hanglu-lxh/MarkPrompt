import SwiftUI

@MainActor
public struct PromptPreviewView: View {
    public var state: PromptPreviewState
    public var compact: Bool

    public init(state: PromptPreviewState, compact: Bool = false) {
        self.state = state
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prompt 预览")
                    .font(.headline)
                Spacer()
                Text("已选择 \(state.includedNoteCount) 条批注")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(previewText)
                    .font(.system(size: compact ? 12 : 13, design: .monospaced))
                    .foregroundStyle(state.prompt.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: compact ? 130 : 320)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }

    private var previewText: String {
        if !state.prompt.isEmpty {
            return state.prompt
        }

        if let warning = state.warnings.first {
            return warning
        }

        return "打开文档并添加批注后，会在这里生成 Codex 文件修改模式 Prompt。"
    }
}
