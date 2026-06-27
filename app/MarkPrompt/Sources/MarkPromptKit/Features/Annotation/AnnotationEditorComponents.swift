import AppKit
import SwiftUI

public struct AnnotationSourceQuotePresentation: Equatable, Sendable {
    public var displayText: String
    public var help: String
    public var accessibilityLabel: String

    public init(displayText: String, help: String, accessibilityLabel: String) {
        self.displayText = displayText
        self.help = help
        self.accessibilityLabel = accessibilityLabel
    }

    public static func presentation(text: String) -> AnnotationSourceQuotePresentation {
        let displayText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let label = "批注原文：\(displayText)"

        return AnnotationSourceQuotePresentation(
            displayText: displayText,
            help: label,
            accessibilityLabel: label
        )
    }
}

struct AnnotationSourceQuoteView: View {
    var text: String
    var lineLimit: Int? = 2
    var help: String?
    var accessibilityLabel: String?
    var accessibilityHint: String?

    var body: some View {
        let presentation = AnnotationSourceQuotePresentation.presentation(text: text)

        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.orange)
                .frame(width: 3, height: 25)

            Text(presentation.displayText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(help ?? presentation.help)
        .accessibilityLabel(accessibilityLabel ?? presentation.accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

public struct AnnotationQuickPromptButtonPresentation: Equatable, Sendable {
    public var title: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(
        title: String,
        isSelected: Bool
    ) -> AnnotationQuickPromptButtonPresentation {
        if isSelected {
            return AnnotationQuickPromptButtonPresentation(
                title: title,
                help: "已插入「\(title)」，再次点击会回到输入框",
                accessibilityLabel: "已选择快捷批注：\(title)",
                accessibilityHint: "已插入，按 Return 回到批注意见输入框"
            )
        }

        return AnnotationQuickPromptButtonPresentation(
            title: title,
            help: "插入快捷批注：\(title)",
            accessibilityLabel: "快捷批注：\(title)",
            accessibilityHint: "按 Return 插入并回到批注意见输入框"
        )
    }
}

struct AnnotationQuickPromptButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        let presentation = AnnotationQuickPromptButtonPresentation.presentation(
            title: title,
            isSelected: isSelected
        )

        Button(action: action) {
            Text(presentation.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.orange.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.orange.opacity(0.7) : Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(presentation.help)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityHint(presentation.accessibilityHint)
    }
}

public struct AnnotationQuickPromptLabelPresentation: Equatable, Sendable {
    public var title: String
    public var help: String
    public var accessibilityLabel: String

    public init(title: String, help: String, accessibilityLabel: String) {
        self.title = title
        self.help = help
        self.accessibilityLabel = accessibilityLabel
    }

    public static func presentation(title: String) -> AnnotationQuickPromptLabelPresentation {
        let label = "已附加快捷批注：\(title)"
        return AnnotationQuickPromptLabelPresentation(
            title: title,
            help: label,
            accessibilityLabel: label
        )
    }
}

struct AnnotationQuickPromptLabel: View {
    var title: String

    var body: some View {
        let presentation = AnnotationQuickPromptLabelPresentation.presentation(title: title)

        Text(presentation.title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .help(presentation.help)
            .accessibilityLabel(presentation.accessibilityLabel)
    }
}

struct AnnotationPrimaryPillLabel: View {
    var title: String
    var systemImage: String
    var isEnabled: Bool = true

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(backgroundColor))
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        isEnabled ? Color.orange : Color.orange.opacity(0.16)
    }

    private var foregroundColor: Color {
        isEnabled ? Color.white : Color.orange.opacity(0.72)
    }
}
