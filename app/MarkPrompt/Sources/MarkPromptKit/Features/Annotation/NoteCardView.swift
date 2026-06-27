import SwiftUI

public struct NoteInclusionPresentation: Equatable, Sendable {
    public var label: String
    public var detail: String
    public var isToggleOn: Bool

    public init(label: String, detail: String, isToggleOn: Bool) {
        self.label = label
        self.detail = detail
        self.isToggleOn = isToggleOn
    }

    public static func presentation(includeInPrompt: Bool, status: ReviewNoteStatus) -> NoteInclusionPresentation {
        if includeInPrompt && status != .excluded {
            return NoteInclusionPresentation(label: "纳入 Prompt", detail: "会进入生成结果", isToggleOn: true)
        }

        return NoteInclusionPresentation(label: "已排除", detail: "不会进入 Prompt", isToggleOn: false)
    }
}

public enum NoteCardTapBehavior {
    public static func shouldSelectNote(isEditing: Bool) -> Bool {
        !isEditing
    }
}

public struct NoteCardEditPresentation: Equatable, Sendable {
    public var trimmedComment: String
    public var canSave: Bool

    public init(trimmedComment: String, canSave: Bool) {
        self.trimmedComment = trimmedComment
        self.canSave = canSave
    }

    public static func presentation(currentComment: String, draftComment: String) -> NoteCardEditPresentation {
        let trimmedCurrentComment = currentComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComment = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        return NoteCardEditPresentation(
            trimmedComment: trimmedComment,
            canSave: !trimmedComment.isEmpty && trimmedComment != trimmedCurrentComment
        )
    }
}

@MainActor
public struct NoteCardView: View {
    @EnvironmentObject private var appState: AppState

    public var note: ReviewNote
    @State private var isEditing = false
    @State private var draftComment = ""
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

        let isActive = appState.selectedNoteID == note.id || isEditing

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
                    .disabled(note.status == .excluded)
                    .help("是否纳入 Prompt")
                    .accessibilityLabel(inclusion.label)
                }
            }

            if note.status == .anchorLost {
                Label("定位需确认", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if note.quickPrompts.isEmpty == false {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(note.quickPrompts, id: \.id) { quickPrompt in
                        AnnotationQuickPromptLabel(title: quickPrompt.label)
                    }
                }
            }

            if isActive {
                TextEditor(text: $draftComment)
                    .font(.body)
                    .frame(minHeight: 96)
                    .focused($isCommentFocused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
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
                Button(role: .destructive) {
                    appState.deleteNote(id: note.id)
                } label: {
                    Label("删除", systemImage: "trash")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if isEditing {
                    Button("取消") {
                        draftComment = note.comment
                        isEditing = false
                        isCommentFocused = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                }

                Button {
                    appState.selectNote(id: note.id)
                } label: {
                    Label("定位", systemImage: "scope")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    if isActive {
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
                        title: "修改批注",
                        systemImage: isActive ? "checkmark" : "pencil",
                        isEnabled: !(isActive && !editPresentation.canSave)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isActive && !editPresentation.canSave)
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.orange : Color(nsColor: .separatorColor), lineWidth: isActive ? 1.4 : 1)
        )
        .opacity(inclusion.isToggleOn ? 1 : 0.62)
        .onTapGesture {
            guard NoteCardTapBehavior.shouldSelectNote(isEditing: isActive) else {
                return
            }

            appState.selectNote(id: note.id)
        }
        .onAppear {
            draftComment = note.comment
        }
        .onChange(of: appState.selectedNoteID) {
            guard appState.selectedNoteID == note.id else {
                isCommentFocused = false
                return
            }
            draftComment = note.comment
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
}
