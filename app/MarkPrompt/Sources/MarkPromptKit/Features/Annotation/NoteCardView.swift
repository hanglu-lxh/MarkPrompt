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

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(note.status == .anchorLost ? Color.orange : Color.yellow)
                    .frame(width: 9, height: 9)

                Text(note.id)
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(inclusion.label)
                        .font(.caption.weight(.semibold))
                    Text(inclusion.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Toggle("", isOn: Binding(
                    get: { inclusion.isToggleOn },
                    set: { appState.setNoteIncluded(id: note.id, includeInPrompt: $0) }
                ))
                .labelsHidden()
                .disabled(note.status == .excluded)
                .help("是否纳入 Prompt")
                .accessibilityLabel(inclusion.label)
            }

            if note.status == .anchorLost {
                Label("定位需确认", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("选中文本")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(note.anchor.selectedText)
                .font(.callout)
                .lineLimit(3)

            Text("批注意见")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isEditing {
                TextEditor(text: $draftComment)
                    .frame(minHeight: 76)
                    .focused($isCommentFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .onAppear {
                        isCommentFocused = true
                    }

                HStack {
                    Button("取消") {
                        draftComment = note.comment
                        isEditing = false
                        isCommentFocused = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("保存") {
                        appState.updateNoteComment(id: note.id, comment: editPresentation.trimmedComment)
                        isEditing = false
                        isCommentFocused = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!editPresentation.canSave)
                }
                .controlSize(.small)
            } else {
                Text(note.comment)
                    .font(.callout)
            }

            HStack(spacing: 8) {
                Button {
                    appState.selectNote(id: note.id)
                } label: {
                    Label("定位", systemImage: "scope")
                }

                Button {
                    draftComment = note.comment
                    isEditing = true
                    isCommentFocused = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Spacer()

                Button(role: .destructive) {
                    appState.deleteNote(id: note.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(appState.selectedNoteID == note.id ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .opacity(inclusion.isToggleOn ? 1 : 0.62)
        .onTapGesture {
            guard NoteCardTapBehavior.shouldSelectNote(isEditing: isEditing) else {
                return
            }

            appState.selectNote(id: note.id)
        }
        .onAppear {
            draftComment = note.comment
        }
    }
}
