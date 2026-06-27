import SwiftUI

public struct OutlineEmptyStatePresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        message: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(hasOpenDocument: Bool) -> OutlineEmptyStatePresentation {
        guard hasOpenDocument else {
            return OutlineEmptyStatePresentation(
                title: "未打开文档",
                message: "打开 Markdown 后显示大纲",
                systemImage: "doc.text",
                help: "打开 Markdown 后可通过大纲跳转标题；可按 ⌘O 打开文档",
                accessibilityLabel: "大纲未打开文档",
                accessibilityHint: "按 ⌘O 打开 Markdown；打开后会显示标题层级"
            )
        }

        return OutlineEmptyStatePresentation(
            title: "当前文档没有标题",
            message: "添加 Markdown 标题后会显示层级导航",
            systemImage: "text.justify.left",
            help: "当前文档没有可跳转标题；添加 # 或 ## 标题后会显示在这里",
            accessibilityLabel: "大纲暂无标题",
            accessibilityHint: "在 Markdown 中添加 # 或 ## 标题后可通过大纲跳转"
        )
    }
}

public enum OutlineRowEmphasis: Equatable, Sendable {
    case normal
    case hover
    case active
    case selected
}

public enum OutlineRowTextWeight: Equatable, Sendable {
    case regular
    case semibold
}

public struct OutlineRowPresentation: Equatable, Sendable {
    public var emphasis: OutlineRowEmphasis
    public var textWeight: OutlineRowTextWeight
    public var showsAccentIndicator: Bool
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        emphasis: OutlineRowEmphasis,
        textWeight: OutlineRowTextWeight,
        showsAccentIndicator: Bool,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.emphasis = emphasis
        self.textWeight = textWeight
        self.showsAccentIndicator = showsAccentIndicator
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        title: String,
        depth: Int,
        isHovered: Bool,
        isActive: Bool,
        isSelected: Bool
    ) -> OutlineRowPresentation {
        let emphasis: OutlineRowEmphasis
        if isSelected {
            emphasis = .selected
        } else if isActive {
            emphasis = .active
        } else if isHovered {
            emphasis = .hover
        } else {
            emphasis = .normal
        }

        let textWeight: OutlineRowTextWeight = (depth == 0 || isActive || isSelected) ? .semibold : .regular
        let isCurrentOrSelected = isActive || isSelected
        let levelText = outlineLevelText(depth: depth)
        let help: String
        let accessibilityLabel: String
        let accessibilityHint: String

        if isSelected {
            help = "正在跳转到标题：\(title)"
            accessibilityLabel = "已选择\(levelText)标题：\(title)"
            accessibilityHint = "阅读区正在滚动到\(title)；再次按 Return 可重新定位"
        } else if isActive {
            help = "当前阅读标题：\(title)"
            accessibilityLabel = "当前阅读的\(levelText)标题：\(title)"
            accessibilityHint = "当前阅读区已在\(title)；按 Return 可重新定位到该章节"
        } else {
            help = "跳转到\(levelText)标题：\(title)"
            accessibilityLabel = "\(levelText)标题：\(title)"
            accessibilityHint = "按 Return 跳转到\(title)；阅读区会滚动到该章节"
        }

        return OutlineRowPresentation(
            emphasis: emphasis,
            textWeight: textWeight,
            showsAccentIndicator: isCurrentOrSelected,
            help: help,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint
        )
    }

    private static func outlineLevelText(depth: Int) -> String {
        switch depth {
        case 0:
            return "一级"
        case 1:
            return "二级"
        case 2:
            return "三级"
        case 3:
            return "四级"
        case 4:
            return "五级"
        case 5:
            return "六级"
        default:
            return "\(depth + 1)级"
        }
    }
}

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
                let presentation = OutlineEmptyStatePresentation.presentation(
                    hasOpenDocument: appState.currentDocument != nil
                )

                VStack(spacing: 10) {
                    Image(systemName: presentation.systemImage)
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text(presentation.title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(presentation.message)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .help(presentation.help)
                .accessibilityLabel(presentation.accessibilityLabel)
                .accessibilityHint(presentation.accessibilityHint)
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
    @State private var isHovered = false

    var body: some View {
        let presentation = OutlineRowPresentation.presentation(
            title: heading.title,
            depth: depth,
            isHovered: isHovered,
            isActive: isActive,
            isSelected: isSelected
        )

        VStack(alignment: .leading, spacing: 2) {
            Button {
                appState.selectHeading(heading)
            } label: {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(presentation.showsAccentIndicator ? Color.accentColor : Color.clear)
                        .frame(width: 3, height: 16)
                    Text(heading.title)
                        .font(.system(size: depth == 0 ? 14 : 13, weight: presentation.textWeight.fontWeight))
                        .foregroundStyle(presentation.foregroundColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(presentation.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help(presentation.help)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityHint(presentation.accessibilityHint)
            .id(heading.id)
            .padding(.leading, CGFloat(depth * 14))
            .onHover { isHovered = $0 }

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
}

private extension OutlineRowTextWeight {
    var fontWeight: Font.Weight {
        switch self {
        case .regular:
            return .regular
        case .semibold:
            return .semibold
        }
    }
}

private extension OutlineRowPresentation {
    var foregroundColor: Color {
        switch emphasis {
        case .active, .selected:
            return .primary
        case .normal, .hover:
            return .secondary
        }
    }

    var backgroundColor: Color {
        switch emphasis {
        case .selected:
            return Color.accentColor.opacity(0.18)
        case .active:
            return Color.accentColor.opacity(0.10)
        case .hover:
            return Color.accentColor.opacity(0.06)
        case .normal:
            return Color.clear
        }
    }
}
