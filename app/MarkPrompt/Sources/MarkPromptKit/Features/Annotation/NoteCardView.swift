import SwiftUI

public struct NoteInclusionPresentation: Equatable, Sendable {
    public var label: String
    public var detail: String
    public var isToggleOn: Bool
    public var help: String
    public var accessibilityHint: String
    public var isToggleEnabled: Bool

    public init(
        label: String,
        detail: String,
        isToggleOn: Bool,
        help: String,
        accessibilityHint: String,
        isToggleEnabled: Bool
    ) {
        self.label = label
        self.detail = detail
        self.isToggleOn = isToggleOn
        self.help = help
        self.accessibilityHint = accessibilityHint
        self.isToggleEnabled = isToggleEnabled
    }

    public static func presentation(includeInPrompt: Bool, status: ReviewNoteStatus) -> NoteInclusionPresentation {
        if status == .excluded {
            return NoteInclusionPresentation(
                label: "已排除",
                detail: "不会进入 Prompt",
                isToggleOn: false,
                help: "定位丢失的批注暂不能纳入 Prompt；重新选择原文后会自动恢复",
                accessibilityHint: "定位丢失的批注暂不能纳入 Prompt；请先在阅读区重新选择原文，恢复后可重新纳入 Prompt",
                isToggleEnabled: false
            )
        }

        if includeInPrompt && status != .excluded {
            return NoteInclusionPresentation(
                label: "纳入 Prompt",
                detail: "会进入生成结果",
                isToggleOn: true,
                help: "从 Prompt 中排除这条批注",
                accessibilityHint: "按 Return 从 Prompt 中排除这条批注",
                isToggleEnabled: true
            )
        }

        return NoteInclusionPresentation(
            label: "已排除",
            detail: "不会进入 Prompt",
            isToggleOn: false,
            help: "纳入 Prompt",
            accessibilityHint: "按 Return 将这条批注纳入 Prompt",
            isToggleEnabled: true
        )
    }
}

public enum NoteCardTapBehavior {
    public static func shouldSelectNote(isEditing: Bool) -> Bool {
        !isEditing
    }
}

public struct NoteCardPrimaryActionPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String
    public var keyboardShortcutHint: String?

    public init(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        help: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        keyboardShortcutHint: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.help = help
        self.accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityHint = accessibilityHint ?? help
        self.keyboardShortcutHint = keyboardShortcutHint
    }

    public static func presentation(isEditing: Bool, canSave: Bool) -> NoteCardPrimaryActionPresentation {
        if isEditing {
            return NoteCardPrimaryActionPresentation(
                title: "保存修改",
                systemImage: "checkmark",
                isEnabled: canSave,
                help: canSave ? "保存当前批注修改（⌘↩）；保存后回到批注卡片" : "修改批注内容后可保存",
                accessibilityLabel: canSave ? "保存批注修改" : "保存修改",
                accessibilityHint: canSave ? "按 ⌘↩ 保存修改并退出编辑；焦点回到批注卡片" : "当前不可保存；修改批注内容后可用，焦点仍留在输入框",
                keyboardShortcutHint: canSave ? "⌘↩" : nil
            )
        }

        return NoteCardPrimaryActionPresentation(
            title: "修改批注",
            systemImage: "pencil",
            isEnabled: true,
            help: "编辑这条批注",
            accessibilityHint: "按 Return 进入编辑；焦点会移动到批注意见输入框，Esc 可取消"
        )
    }
}

public struct NoteCardCancelActionPresentation: Equatable, Sendable {
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

    public static func presentation(hasUnsavedDraft: Bool) -> NoteCardCancelActionPresentation {
        if hasUnsavedDraft {
            return NoteCardCancelActionPresentation(
                title: "取消",
                help: "放弃未保存修改并回到批注卡片",
                accessibilityLabel: "放弃未保存修改并取消编辑",
                accessibilityHint: "按 Esc 放弃未保存修改并退出编辑；不会保存草稿"
            )
        }

        return NoteCardCancelActionPresentation(
            title: "取消",
            help: "退出编辑并回到批注卡片",
            accessibilityLabel: "取消编辑",
            accessibilityHint: "按 Esc 退出编辑；不会修改批注"
        )
    }
}

public enum NoteCardKeyboardShortcutPresentation: Equatable, Sendable {
    case saveComment

    public static func presentation(
        isEditing: Bool,
        canSave: Bool,
        isEditorFocused: Bool
    ) -> NoteCardKeyboardShortcutPresentation? {
        guard isEditing, canSave, isEditorFocused else {
            return nil
        }

        return .saveComment
    }
}

public struct NoteCardEditorPlaceholderPresentation: Equatable, Sendable {
    public var text: String
    public var help: String

    public init(text: String, help: String) {
        self.text = text
        self.help = help
    }

    public static func presentation(
        isEditing: Bool,
        draftComment: String
    ) -> NoteCardEditorPlaceholderPresentation? {
        guard isEditing,
              draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return NoteCardEditorPlaceholderPresentation(
            text: "输入批注意见...",
            help: "批注意见不能为空"
        )
    }
}

public struct NoteCardDeleteActionPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var isDestructiveConfirmation: Bool
    public var hitTargetHeight: CGFloat
    public var backgroundOpacity: Double
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        help: String,
        isDestructiveConfirmation: Bool,
        hitTargetHeight: CGFloat,
        backgroundOpacity: Double,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.isDestructiveConfirmation = isDestructiveConfirmation
        self.hitTargetHeight = hitTargetHeight
        self.backgroundOpacity = backgroundOpacity
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(isConfirmingDelete: Bool) -> NoteCardDeleteActionPresentation {
        if isConfirmingDelete {
            return NoteCardDeleteActionPresentation(
                title: "确认删除",
                systemImage: "trash.fill",
                help: "再次点击将永久删除；删除后焦点回到批注列表；按 Esc 或移出卡片取消",
                isDestructiveConfirmation: true,
                hitTargetHeight: 28,
                backgroundOpacity: 0.10,
                accessibilityLabel: "确认删除批注",
                accessibilityHint: "再次按 Return 将永久删除这条批注；删除后焦点回到批注列表；按 Esc 取消删除且不会修改批注"
            )
        }

        return NoteCardDeleteActionPresentation(
            title: "删除",
            systemImage: "trash",
            help: "进入删除确认；第一次不会删除",
            isDestructiveConfirmation: false,
            hitTargetHeight: 28,
            backgroundOpacity: 0,
            accessibilityLabel: "删除批注",
            accessibilityHint: "按 Return 进入删除确认；不会立即删除这条批注"
        )
    }
}

public enum NoteCardDeleteConfirmationResetBehavior {
    public static func shouldReset(isConfirmingDelete: Bool) -> Bool {
        isConfirmingDelete
    }
}

public struct NoteCardLocateActionPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public static func presentation(status: ReviewNoteStatus) -> NoteCardLocateActionPresentation {
        guard status == .anchorLost else {
            return NoteCardLocateActionPresentation(
                title: "定位",
                systemImage: "scope",
                help: "在阅读区滚动并高亮这条批注原文",
                accessibilityLabel: "定位批注",
                accessibilityHint: "按 Return 在阅读区定位这条批注；焦点会回到阅读区"
            )
        }

        return NoteCardLocateActionPresentation(
            title: "定位需确认",
            systemImage: "scope",
            help: "原文位置已失效，点击后会提示在阅读区重新选择原文",
            accessibilityLabel: "定位需确认的批注",
            accessibilityHint: "按 Return 查看定位失效提示；焦点会回到阅读区，请重新选择原文"
        )
    }
}

public enum NoteCardSelectionChangePresentation: Equatable, Sendable {
    case endEditing
    case keepEditing
    case syncDraftToCurrentNote
    case none

    public static func presentation(
        noteID: String,
        selectedNoteID: String?,
        isEditing: Bool,
        hasUnsavedDraft: Bool
    ) -> NoteCardSelectionChangePresentation {
        guard selectedNoteID == noteID else {
            guard isEditing else {
                return .none
            }
            return hasUnsavedDraft ? .keepEditing : .endEditing
        }

        return .syncDraftToCurrentNote
    }
}

public struct NoteCardInteractionPresentation: Equatable, Sendable {
    public var isChromeActive: Bool
    public var showsEditor: Bool
    public var allowsTapSelection: Bool
    public var primaryAction: NoteCardPrimaryActionPresentation

    public init(
        isChromeActive: Bool,
        showsEditor: Bool,
        allowsTapSelection: Bool,
        primaryAction: NoteCardPrimaryActionPresentation
    ) {
        self.isChromeActive = isChromeActive
        self.showsEditor = showsEditor
        self.allowsTapSelection = allowsTapSelection
        self.primaryAction = primaryAction
    }

    public static func presentation(
        isSelected: Bool,
        isEditing: Bool,
        canSave: Bool
    ) -> NoteCardInteractionPresentation {
        NoteCardInteractionPresentation(
            isChromeActive: isSelected || isEditing,
            showsEditor: isEditing,
            allowsTapSelection: NoteCardTapBehavior.shouldSelectNote(isEditing: isEditing),
            primaryAction: NoteCardPrimaryActionPresentation.presentation(
                isEditing: isEditing,
                canSave: canSave
            )
        )
    }
}

public struct NoteCardStatusPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityHint = accessibilityHint ?? help
    }

    public static func presentation(status: ReviewNoteStatus) -> NoteCardStatusPresentation? {
        guard status == .anchorLost else {
            return nil
        }

        return NoteCardStatusPresentation(
            title: "定位需确认",
            systemImage: "exclamationmark.triangle",
            help: "原文位置已失效；在阅读区重新选择原文后会恢复定位并可继续纳入 Prompt",
            accessibilityLabel: "批注定位需确认",
            accessibilityHint: "原文位置已失效；点击定位需确认后回到阅读区重新选择原文"
        )
    }
}

public struct NoteCardDraftStatusPresentation: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var help: String
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        title: String,
        systemImage: String,
        help: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityHint = accessibilityHint ?? help
    }

    public static func presentation(
        isEditing: Bool,
        hasUnsavedDraft: Bool
    ) -> NoteCardDraftStatusPresentation? {
        guard isEditing, hasUnsavedDraft else {
            return nil
        }

        return NoteCardDraftStatusPresentation(
            title: "未保存修改",
            systemImage: "circle.fill",
            help: "保存或取消后会离开编辑状态",
            accessibilityLabel: "有未保存的批注修改",
            accessibilityHint: "按 ⌘↩ 保存，或按 Esc 放弃修改"
        )
    }
}

public enum NoteCardChromeEmphasis: Equatable, Sendable {
    case normal
    case hover
    case active
    case excluded
}

public struct NoteCardChromePresentation: Equatable, Sendable {
    public var emphasis: NoteCardChromeEmphasis
    public var borderWidth: CGFloat
    public var opacity: Double

    public init(emphasis: NoteCardChromeEmphasis, borderWidth: CGFloat, opacity: Double) {
        self.emphasis = emphasis
        self.borderWidth = borderWidth
        self.opacity = opacity
    }

    public static func presentation(
        isActive: Bool,
        isHovering: Bool,
        isIncludedInPrompt: Bool
    ) -> NoteCardChromePresentation {
        if isActive {
            return NoteCardChromePresentation(emphasis: .active, borderWidth: 1.6, opacity: 1)
        }
        if !isIncludedInPrompt {
            return NoteCardChromePresentation(emphasis: .excluded, borderWidth: 1, opacity: 0.68)
        }
        if isHovering {
            return NoteCardChromePresentation(emphasis: .hover, borderWidth: 1.2, opacity: 1)
        }
        return NoteCardChromePresentation(emphasis: .normal, borderWidth: 1, opacity: 1)
    }
}

public struct NoteCardEditPresentation: Equatable, Sendable {
    public var trimmedComment: String
    public var canSave: Bool
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(
        trimmedComment: String,
        canSave: Bool,
        accessibilityLabel: String = "批注意见输入框",
        accessibilityHint: String? = nil
    ) {
        self.trimmedComment = trimmedComment
        self.canSave = canSave
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint ?? (canSave ? "按 ⌘↩ 保存修改，按 Esc 取消编辑" : "修改批注意见后可保存")
    }

    public static func presentation(currentComment: String, draftComment: String) -> NoteCardEditPresentation {
        let trimmedCurrentComment = currentComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComment = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSave = !trimmedComment.isEmpty && trimmedComment != trimmedCurrentComment
        let accessibilityHint: String
        if canSave {
            accessibilityHint = "按 ⌘↩ 保存修改，按 Esc 取消编辑"
        } else if trimmedComment.isEmpty {
            accessibilityHint = "批注意见不能为空；输入内容后可保存"
        } else {
            accessibilityHint = "内容未变化；修改批注意见后可保存"
        }

        return NoteCardEditPresentation(
            trimmedComment: trimmedComment,
            canSave: canSave,
            accessibilityHint: accessibilityHint
        )
    }
}

@MainActor
public struct NoteCardView: View {
    @EnvironmentObject private var appState: AppState

    public var note: ReviewNote
    @State private var isEditing = false
    @State private var draftComment = ""
    @State private var isHovering = false
    @State private var isConfirmingDelete = false
    @FocusState private var isCommentFocused: Bool

    public init(note: ReviewNote) {
        self.note = note
    }

    public var body: some View {
        let inclusion = NoteInclusionPresentation.presentation(
            includeInPrompt: note.includeInPrompt,
            status: note.status
        )
        let editPresentation = NoteCardEditPresentation.presentation(
            currentComment: note.comment,
            draftComment: draftComment
        )
        let hasUnsavedDraft = trimmedDraftCommentChanged(
            currentComment: note.comment,
            draftComment: draftComment
        )
        let draftStatus = NoteCardDraftStatusPresentation.presentation(
            isEditing: isEditing,
            hasUnsavedDraft: hasUnsavedDraft
        )
        let editorPlaceholder = NoteCardEditorPlaceholderPresentation.presentation(
            isEditing: isEditing,
            draftComment: draftComment
        )

        let isSelected = appState.selectedNoteID == note.id
        let interaction = NoteCardInteractionPresentation.presentation(
            isSelected: isSelected,
            isEditing: isEditing,
            canSave: editPresentation.canSave
        )
        let chrome = NoteCardChromePresentation.presentation(
            isActive: interaction.isChromeActive,
            isHovering: isHovering,
            isIncludedInPrompt: inclusion.isToggleOn
        )
        let deleteAction = NoteCardDeleteActionPresentation.presentation(
            isConfirmingDelete: isConfirmingDelete
        )
        let locateAction = NoteCardLocateActionPresentation.presentation(status: note.status)
        let cancelAction = NoteCardCancelActionPresentation.presentation(
            hasUnsavedDraft: hasUnsavedDraft
        )
        let keyboardShortcut = NoteCardKeyboardShortcutPresentation.presentation(
            isEditing: isEditing,
            canSave: editPresentation.canSave,
            isEditorFocused: isCommentFocused
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                AnnotationSourceQuoteView(text: note.anchor.selectedText, lineLimit: 2)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(inclusion.label)
                        .font(.caption.weight(.semibold))
                    Text(inclusion.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Toggle("", isOn: Binding(
                        get: { inclusion.isToggleOn },
                        set: { appState.setNoteIncluded(id: note.id, includeInPrompt: $0) }
                    ))
                    .labelsHidden()
                    .disabled(!inclusion.isToggleEnabled)
                    .help(inclusion.help)
                    .accessibilityLabel(inclusion.label)
                    .accessibilityHint(inclusion.accessibilityHint)
                }
            }

            if let statusPresentation = NoteCardStatusPresentation.presentation(status: note.status) {
                Label(statusPresentation.title, systemImage: statusPresentation.systemImage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(statusPresentation.help)
                    .accessibilityLabel(statusPresentation.accessibilityLabel)
                    .accessibilityHint(statusPresentation.accessibilityHint)
            }

            if let draftStatus {
                Label(draftStatus.title, systemImage: draftStatus.systemImage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(draftStatus.help)
                    .accessibilityLabel(draftStatus.accessibilityLabel)
                    .accessibilityHint(draftStatus.accessibilityHint)
            }

            if note.quickPrompts.isEmpty == false {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(note.quickPrompts, id: \.id) { quickPrompt in
                        AnnotationQuickPromptLabel(title: quickPrompt.label)
                    }
                }
            }

            if interaction.showsEditor {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draftComment)
                        .font(.body)
                        .frame(minHeight: 96)
                        .focused($isCommentFocused)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .accessibilityLabel(editPresentation.accessibilityLabel)
                        .accessibilityHint(editPresentation.accessibilityHint)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isCommentFocused ? Color(nsColor: .secondaryLabelColor) : Color(nsColor: .separatorColor),
                                    lineWidth: isCommentFocused ? 1.4 : 1
                                )
                        )
                        .onAppear {
                            if isEditing {
                                focusCommentEditor()
                            }
                        }

                    if let editorPlaceholder {
                        Text(editorPlaceholder.text)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                            .help(editorPlaceholder.help)
                            .accessibilityHidden(true)
                        }
                }
            } else {
                Text(note.comment)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                Button(role: deleteAction.isDestructiveConfirmation ? .destructive : nil) {
                    if isConfirmingDelete {
                        appState.deleteNote(id: note.id)
                    } else {
                        isConfirmingDelete = true
                    }
                } label: {
                    Label(deleteAction.title, systemImage: deleteAction.systemImage)
                        .font(.callout)
                        .frame(minHeight: deleteAction.hitTargetHeight)
                        .padding(.horizontal, 6)
                        .background(Color.red.opacity(deleteAction.backgroundOpacity))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(deleteAction.isDestructiveConfirmation ? .red : .secondary)
                .contentShape(Rectangle())
                .help(deleteAction.help)
                .accessibilityLabel(deleteAction.accessibilityLabel)
                .accessibilityHint(deleteAction.accessibilityHint)

                if isEditing {
                    Button(cancelAction.title) {
                        draftComment = note.comment
                        isEditing = false
                        isCommentFocused = false
                        isConfirmingDelete = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(cancelAction.help)
                    .accessibilityLabel(cancelAction.accessibilityLabel)
                    .accessibilityHint(cancelAction.accessibilityHint)
                    .keyboardShortcut(.cancelAction)
                }

                Button {
                    isConfirmingDelete = false
                    appState.selectNote(id: note.id)
                } label: {
                    Label(locateAction.title, systemImage: locateAction.systemImage)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(locateAction.help)
                .accessibilityLabel(locateAction.accessibilityLabel)
                .accessibilityHint(locateAction.accessibilityHint)

                Spacer()

                if keyboardShortcut == nil {
                    primaryActionButton(
                        interaction: interaction,
                        editPresentation: editPresentation
                    )
                } else {
                    primaryActionButton(
                        interaction: interaction,
                        editPresentation: editPresentation
                    )
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
        }
        .padding(12)
        .background(chrome.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(chrome.borderColor, lineWidth: chrome.borderWidth)
        )
        .shadow(color: chrome.shadowColor, radius: chrome.shadowRadius, x: 0, y: 2)
        .opacity(chrome.opacity)
        .onHover { isHovering in
            self.isHovering = isHovering
            if !isHovering {
                isConfirmingDelete = false
            }
        }
        .onExitCommand {
            if NoteCardDeleteConfirmationResetBehavior.shouldReset(isConfirmingDelete: isConfirmingDelete) {
                isConfirmingDelete = false
            }
        }
        .onTapGesture {
            guard interaction.allowsTapSelection else {
                return
            }

            isConfirmingDelete = false
            appState.selectNote(id: note.id)
        }
        .onAppear {
            draftComment = note.comment
        }
        .onChange(of: appState.selectedNoteID) {
            let hasUnsavedDraft = trimmedDraftCommentChanged(
                currentComment: note.comment,
                draftComment: draftComment
            )

            switch NoteCardSelectionChangePresentation.presentation(
                noteID: note.id,
                selectedNoteID: appState.selectedNoteID,
                isEditing: isEditing,
                hasUnsavedDraft: hasUnsavedDraft
            ) {
            case .endEditing:
                draftComment = note.comment
                isEditing = false
                isCommentFocused = false
                isConfirmingDelete = false
                return
            case .keepEditing:
                isCommentFocused = false
                return
            case .syncDraftToCurrentNote:
                draftComment = note.comment
            case .none:
                isCommentFocused = false
            }
        }
        .onChange(of: note.comment) {
            draftComment = note.comment
        }
    }

    private func focusCommentEditor() {
        DispatchQueue.main.async {
            isCommentFocused = true
        }
    }

    private func trimmedDraftCommentChanged(currentComment: String, draftComment: String) -> Bool {
        let current = currentComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        return current != draft
    }

    private func primaryActionButton(
        interaction: NoteCardInteractionPresentation,
        editPresentation: NoteCardEditPresentation
    ) -> some View {
        Button {
            isConfirmingDelete = false
            if interaction.showsEditor {
                appState.updateNoteComment(id: note.id, comment: editPresentation.trimmedComment)
                isEditing = false
                isCommentFocused = false
            } else {
                draftComment = note.comment
                isEditing = true
                isCommentFocused = true
                focusCommentEditor()
            }
        } label: {
            AnnotationPrimaryPillLabel(
                title: interaction.primaryAction.title,
                systemImage: interaction.primaryAction.systemImage,
                isEnabled: interaction.primaryAction.isEnabled
            )
        }
        .buttonStyle(.plain)
        .disabled(!interaction.primaryAction.isEnabled)
        .help(interaction.primaryAction.help)
        .accessibilityLabel(interaction.primaryAction.accessibilityLabel)
        .accessibilityHint(interaction.primaryAction.accessibilityHint)
    }
}

private extension NoteCardChromePresentation {
    var backgroundColor: Color {
        switch emphasis {
        case .normal, .excluded:
            return Color(nsColor: .textBackgroundColor)
        case .hover:
            return Color(nsColor: .textBackgroundColor).opacity(0.98)
        case .active:
            return Color.orange.opacity(0.07)
        }
    }

    var borderColor: Color {
        switch emphasis {
        case .normal:
            return Color(nsColor: .separatorColor)
        case .hover:
            return Color.orange.opacity(0.5)
        case .active:
            return Color.orange
        case .excluded:
            return Color(nsColor: .separatorColor).opacity(0.75)
        }
    }

    var shadowColor: Color {
        switch emphasis {
        case .hover:
            return Color.black.opacity(0.08)
        case .active:
            return Color.orange.opacity(0.10)
        case .normal, .excluded:
            return Color.clear
        }
    }

    var shadowRadius: CGFloat {
        switch emphasis {
        case .hover:
            return 5
        case .active:
            return 8
        case .normal, .excluded:
            return 0
        }
    }
}
