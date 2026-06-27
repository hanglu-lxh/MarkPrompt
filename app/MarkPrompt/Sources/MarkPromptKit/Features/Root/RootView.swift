import AppKit
import SwiftUI
import UniformTypeIdentifiers

public enum RootLayoutMetrics {
    public static let expandedOutlineWidth: CGFloat = 240
    public static let collapsedOutlineWidth: CGFloat = 52
    public static let defaultInspectorWidth: CGFloat = 360
    public static let minimumInspectorWidth: CGFloat = 320
    public static let maximumInspectorWidth: CGFloat = 620

    public static func clampedInspectorWidth(_ width: CGFloat) -> CGFloat {
        min(maximumInspectorWidth, max(minimumInspectorWidth, width))
    }

    public static func inspectorWidth(startingWidth: CGFloat, dragTranslationX: CGFloat) -> CGFloat {
        clampedInspectorWidth(startingWidth - dragTranslationX)
    }
}

@MainActor
public struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("markprompt.outlineCollapsed") private var isOutlineCollapsed = false
    @AppStorage("markprompt.inspectorWidth") private var storedInspectorWidth = Double(RootLayoutMetrics.defaultInspectorWidth)
    @State private var inspectorDragStartWidth: CGFloat?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Divider()

            if let candidate = appState.clipboardMarkdownCandidate {
                ClipboardMarkdownBannerView(
                    candidate: candidate,
                    onOpen: {
                        appState.openDocument(at: candidate.url)
                    },
                    onDismiss: {
                        appState.dismissClipboardMarkdownCandidate()
                    }
                )
                Divider()
            }

            HStack(spacing: 0) {
                if isOutlineCollapsed {
                    CollapsedOutlineRailView {
                        isOutlineCollapsed = false
                    }
                    .frame(width: RootLayoutMetrics.collapsedOutlineWidth)
                } else {
                    OutlineSidebarView {
                        isOutlineCollapsed = true
                    }
                    .frame(width: RootLayoutMetrics.expandedOutlineWidth)
                }

                Divider()

                MarkdownReaderView()
                    .frame(minWidth: 520, maxWidth: .infinity)

                InspectorResizeHandle(
                    width: inspectorWidthBinding,
                    dragStartWidth: $inspectorDragStartWidth
                )

                AnnotationPanelView()
                    .frame(width: inspectorWidth)
            }
        }
        .frame(minWidth: 1120, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.refreshClipboardMarkdownCandidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshClipboardMarkdownCandidate()
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            appState.refreshClipboardMarkdownCandidate()
        }
        .onOpenURL { url in
            appState.openDocument(at: url)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            appState.openDroppedDocument(from: providers)
        }
        .onPasteCommand(of: [.fileURL]) { providers in
            appState.openDroppedDocument(from: providers)
        }
    }

    private var inspectorWidth: CGFloat {
        RootLayoutMetrics.clampedInspectorWidth(CGFloat(storedInspectorWidth))
    }

    private var inspectorWidthBinding: Binding<CGFloat> {
        Binding(
            get: { inspectorWidth },
            set: { storedInspectorWidth = Double(RootLayoutMetrics.clampedInspectorWidth($0)) }
        )
    }

    private var topToolbar: some View {
        HStack(spacing: 12) {
            Menu {
                Button("打开 Markdown...") {
                    appState.openDocumentWithPanel()
                }

                if appState.recentDocumentURLs.isEmpty == false {
                    Divider()

                    Section("打开历史") {
                        ForEach(appState.recentDocumentURLs, id: \.path) { url in
                            Button(url.lastPathComponent) {
                                appState.openDocument(at: url)
                            }
                            .help(url.path)
                        }
                    }

                    Divider()

                    Button("清除打开历史") {
                        appState.clearRecentDocuments()
                    }
                }
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

private struct ClipboardMarkdownBannerView: View {
    var candidate: ClipboardMarkdownCandidate
    var onOpen: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label("剪切板中有 Markdown 文件：\(candidate.displayName)", systemImage: "doc.text")
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button("打开") {
                onOpen()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("忽略") {
                onDismiss()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }
}

private struct CollapsedOutlineRailView: View {
    var onExpand: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onExpand()
            } label: {
                Image(systemName: "sidebar.leading")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("展开大纲")
            .accessibilityLabel("展开大纲")

            Image(systemName: "list.bullet")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct InspectorResizeHandle: View {
    @Binding var width: CGFloat
    @Binding var dragStartWidth: CGFloat?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)

            ResizeCursorView()
                .frame(width: 10)

            Rectangle()
                .fill(Color.clear)
                .frame(width: 10)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            NSCursor.resizeLeftRight.set()
                            let startWidth = dragStartWidth ?? width
                            if dragStartWidth == nil {
                                dragStartWidth = startWidth
                            }
                            width = RootLayoutMetrics.inspectorWidth(
                                startingWidth: startWidth,
                                dragTranslationX: value.translation.width
                            )
                        }
                        .onEnded { _ in
                            dragStartWidth = nil
                            NSCursor.arrow.set()
                        }
                )
        }
        .frame(width: 10)
        .onHover { isHovering in
            if isHovering {
                NSCursor.resizeLeftRight.set()
            } else if dragStartWidth == nil {
                NSCursor.arrow.set()
            }
        }
        .help("拖动调整批注与 Prompt 宽度")
        .accessibilityLabel("调整批注与 Prompt 宽度")
    }
}

private struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ResizeCursorNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ResizeCursorNSView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
