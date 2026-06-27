import SwiftUI

public struct ReaderStatusBannerPresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public static func presentation(
        for saveState: SaveState,
        hasOpenDocument: Bool = false
    ) -> ReaderStatusBannerPresentation? {
        guard case let .failed(message) = saveState else {
            return nil
        }
        if let sidecarWarning = SidecarLoadWarningPresentation.presentation(from: message) {
            return ReaderStatusBannerPresentation(
                title: sidecarWarning.title,
                message: sidecarWarning.message,
                systemImage: sidecarWarning.systemImage
            )
        }
        guard shouldShowReaderBanner(for: message) else {
            return nil
        }

        return ReaderStatusBannerPresentation(
            title: hasOpenDocument ? "导入未完成" : "需要处理",
            message: hasOpenDocument ? messageWithCurrentDocumentContext(message) : message,
            systemImage: "exclamationmark.triangle"
        )
    }

    private static func shouldShowReaderBanner(for message: String) -> Bool {
        let readerFailurePrefixes = [
            "只能打开 .md 或 .markdown 文件",
            "无法读取 Markdown 文件",
            "请拖入 .md 或 .markdown 文件",
            "拖拽导入失败：",
            "无法读取拖入的文件",
            "批注保存失败，已暂停打开/导入以避免丢失批注"
        ]

        return readerFailurePrefixes.contains { message.hasPrefix($0) }
    }

    private static func messageWithCurrentDocumentContext(_ message: String) -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceEndings: Set<Character> = ["。", "！", "？", ".", "!", "?"]
        let separator = trimmedMessage.last.map { sentenceEndings.contains($0) ? "" : "。" } ?? ""
        return "\(trimmedMessage)\(separator)当前文档仍保持打开。"
    }
}

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

            if let banner = ReaderStatusBannerPresentation.presentation(
                for: appState.saveState,
                hasOpenDocument: appState.currentDocument != nil
            ) {
                ReaderStatusBannerView(presentation: banner)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)

                Divider()
            }

            if let document = appState.currentDocument {
                ZStack(alignment: .topLeading) {
                    let documentID = document.id
                    MarkdownTextViewRepresentable(
                        attributedText: document.renderModel.attributedText,
                        sourceMap: document.renderModel.sourceMap,
                        highlights: appState.annotationHighlights,
                        scrollTargetHeadingID: appState.scrollTargetHeadingID,
                        scrollTargetRange: appState.scrollTargetRange,
                        onSelectionChange: { selection in
                            appState.updateSelection(selection, from: documentID)
                        },
                        onScrollTargetConsumed: { headingID, range in
                            appState.clearScrollTarget(headingID: headingID, range: range, from: documentID)
                        },
                        onVisibleHeadingChange: { headingID in
                            appState.updateVisibleHeading(headingID, from: documentID)
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

private struct ReaderStatusBannerView: View {
    var presentation: ReaderStatusBannerPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: presentation.systemImage)
                .foregroundStyle(.orange)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(presentation.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
