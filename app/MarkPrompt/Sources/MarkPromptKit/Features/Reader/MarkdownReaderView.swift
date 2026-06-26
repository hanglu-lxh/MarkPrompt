import SwiftUI

@MainActor
public struct MarkdownReaderView: View {
    @EnvironmentObject private var appState: AppState

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

            if let document = appState.currentDocument {
                ZStack(alignment: .topLeading) {
                    MarkdownTextViewRepresentable(
                        attributedText: document.renderModel.attributedText,
                        sourceMap: document.renderModel.sourceMap,
                        highlights: appState.annotationHighlights,
                        scrollTargetHeadingID: appState.scrollTargetHeadingID,
                        scrollTargetRange: appState.scrollTargetRange,
                        onSelectionChange: { selection in
                            appState.updateSelection(selection)
                        },
                        onScrollTargetConsumed: {
                            appState.clearScrollTargets()
                        },
                        onVisibleHeadingChange: { headingID in
                            appState.updateVisibleHeading(headingID)
                        }
                    )

                    if appState.canCreateAnnotation,
                       let rect = appState.readerSelection?.selectionRect {
                        Button {
                            appState.beginAnnotationFromCurrentSelection()
                        } label: {
                            Label("批注 +", systemImage: "text.bubble")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .position(x: rect.midX, y: rect.midY)
                        .popover(isPresented: $appState.isAnnotationPopoverPresented, arrowEdge: .trailing) {
                            AnnotationPopoverView()
                                .environmentObject(appState)
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("打开 Markdown")
                        .font(.title3.weight(.semibold))
                    Button {
                        appState.openDocumentWithPanel()
                    } label: {
                        Label("选择 .md 文件", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack(spacing: 20) {
                Text(statusText)
                Spacer()
                Text(appState.saveState.label)
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
}
