import SwiftUI

@MainActor
public struct RootView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Divider()

            HStack(spacing: 0) {
                OutlineSidebarView()
                    .frame(width: 240)

                Divider()

                MarkdownReaderView()
                    .frame(minWidth: 520, maxWidth: .infinity)

                Divider()

                AnnotationPanelView()
                    .frame(width: 360)
            }
        }
        .frame(minWidth: 1120, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onOpenURL { url in
            appState.openDocument(at: url)
        }
    }

    private var topToolbar: some View {
        HStack(spacing: 12) {
            Button {
                appState.openDocumentWithPanel()
            } label: {
                Label("打开", systemImage: "folder")
            }
            .help("打开 Markdown")

            Spacer()

            Text(appState.currentDocument?.displayName ?? "MarkPrompt")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            TextField("搜索 (⌘F)", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .disabled(true)

            Button {
                appState.copyPromptToPasteboard()
            } label: {
                Label("复制 Prompt", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.promptPreview.prompt.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
