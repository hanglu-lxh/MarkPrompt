import AppKit
import SwiftUI

struct AnnotationSourceQuoteView: View {
    var text: String
    var lineLimit: Int? = 2

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.orange)
                .frame(width: 3, height: 25)

            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AnnotationQuickPromptButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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
        .accessibilityLabel(title)
    }
}

struct AnnotationQuickPromptLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
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
