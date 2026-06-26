import SwiftUI

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
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var annotationsFirstLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    if notes.isEmpty {
                        emptyNotesView
                    } else {
                        ForEach(notes) { note in
                            NoteCardView(note: note)
                        }
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: .infinity)

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
}
