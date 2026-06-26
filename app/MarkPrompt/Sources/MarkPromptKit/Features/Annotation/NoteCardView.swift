import SwiftUI

@MainActor
public struct NoteCardView: View {
    @EnvironmentObject private var appState: AppState

    public var note: ReviewNote
    @State private var isEditing = false
    @State private var draftComment = ""

    public init(note: ReviewNote) {
        self.note = note
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(note.status == .anchorLost ? Color.orange : Color.yellow)
                    .frame(width: 9, height: 9)

                Text(note.id)
                    .font(.headline)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { note.includeInPrompt },
                    set: { appState.setNoteIncluded(id: note.id, includeInPrompt: $0) }
                ))
                .labelsHidden()
                .disabled(note.status == .excluded)
                .help("是否纳入 Prompt")
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                HStack {
                    Button("取消") {
                        draftComment = note.comment
                        isEditing = false
                    }

                    Spacer()

                    Button("保存") {
                        appState.updateNoteComment(id: note.id, comment: draftComment)
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .opacity(note.includeInPrompt && note.status != .excluded ? 1 : 0.62)
        .onTapGesture {
            appState.selectNote(id: note.id)
        }
        .onAppear {
            draftComment = note.comment
        }
    }
}
