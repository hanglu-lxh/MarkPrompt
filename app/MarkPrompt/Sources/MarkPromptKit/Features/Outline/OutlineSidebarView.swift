import SwiftUI

@MainActor
public struct OutlineSidebarView: View {
    @EnvironmentObject private var appState: AppState
    private var onCollapse: (() -> Void)?

    public init(onCollapse: (() -> Void)? = nil) {
        self.onCollapse = onCollapse
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                Text("大纲")
                    .font(.headline)
                Spacer()
                if let onCollapse {
                    Button {
                        onCollapse()
                    } label: {
                        Image(systemName: "sidebar.leading")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("收起大纲")
                    .accessibilityLabel("收起大纲")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if let document = appState.currentDocument, !document.outline.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(document.outline) { heading in
                                OutlineNodeView(heading: heading, depth: 0)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: appState.currentReadingHeadingID) { _, headingID in
                        guard let headingID else {
                            return
                        }

                        withAnimation(.easeOut(duration: 0.16)) {
                            proxy.scrollTo(headingID, anchor: .center)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "text.justify.left")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text(appState.currentDocument == nil ? "未打开文档" : "当前文档没有标题")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

@MainActor
private struct OutlineNodeView: View {
    @EnvironmentObject private var appState: AppState

    var heading: DocumentHeading
    var depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                appState.selectHeading(heading)
            } label: {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color.clear)
                        .frame(width: 3, height: 16)
                    Text(heading.title)
                        .font(.system(size: depth == 0 ? 14 : 13, weight: textWeight))
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .id(heading.id)
            .padding(.leading, CGFloat(depth * 14))

            ForEach(heading.children) { child in
                OutlineNodeView(heading: child, depth: depth + 1)
            }
        }
    }

    private var isSelected: Bool {
        appState.scrollTargetHeadingID == heading.id
    }

    private var isActive: Bool {
        appState.currentReadingHeadingID == heading.id || isSelected
    }

    private var textWeight: Font.Weight {
        if isActive {
            return .semibold
        }
        return depth == 0 ? .semibold : .regular
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }
        if isActive {
            return Color.accentColor.opacity(0.10)
        }
        return Color.clear
    }
}
