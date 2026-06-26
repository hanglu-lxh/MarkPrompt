import Foundation

public struct PromptBuilder {
    public init() {}

    public func build(
        document: MarkdownDocument,
        session: ReviewSession,
        template: PromptTemplate = CodexFileModificationTemplate()
    ) -> PromptBuildResult {
        let includedNotes = session.notes.filter { note in
            note.includeInPrompt && note.status != .excluded && note.status != .draft
        }

        guard !includedNotes.isEmpty else {
            return PromptBuildResult(
                prompt: "",
                warnings: ["至少需要一条纳入 Prompt 的批注。"],
                includedNoteCount: 0
            )
        }

        let context = PromptRenderContext(document: document, session: session, notes: includedNotes)
        return PromptBuildResult(
            prompt: template.render(context: context),
            warnings: [],
            includedNoteCount: includedNotes.count
        )
    }
}
