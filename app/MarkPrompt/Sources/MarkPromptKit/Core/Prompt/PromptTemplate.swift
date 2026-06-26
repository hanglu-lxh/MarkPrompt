import Foundation

public protocol PromptTemplate {
    var id: String { get }
    var name: String { get }
    func render(context: PromptRenderContext) -> String
}

public struct PromptRenderContext {
    public var document: MarkdownDocument
    public var session: ReviewSession
    public var notes: [ReviewNote]

    public init(document: MarkdownDocument, session: ReviewSession, notes: [ReviewNote]) {
        self.document = document
        self.session = session
        self.notes = notes
    }
}

public struct PromptBuildResult: Equatable {
    public var prompt: String
    public var warnings: [String]
    public var includedNoteCount: Int

    public init(prompt: String, warnings: [String] = [], includedNoteCount: Int) {
        self.prompt = prompt
        self.warnings = warnings
        self.includedNoteCount = includedNoteCount
    }
}

public struct CodexFileModificationTemplate: PromptTemplate {
    public let id = "codex-file-modification"
    public let name = "Codex 文件修改模式"

    public init() {}

    public func render(context: PromptRenderContext) -> String {
        let targetPath = context.document.fileURL?.path
            ?? context.session.sourceFile
            ?? context.document.displayName

        var output: [String] = [
            "# Codex 文件修改模式",
            "",
            "目标文件：",
            targetPath,
            "",
            "全局修改原则：",
            "- 保持 Markdown 标题层级",
            "- 不新增未经证实的信息",
            "- 语言更直接，更易读",
            "- 以用户批注意见为准",
            "",
            "批注列表："
        ]

        for note in context.notes {
            output.append("")
            output.append("[NOTE \(note.id)]")
            output.append("章节：\(note.anchor.headingPath.isEmpty ? "未定位章节" : note.anchor.headingPath.joined(separator: " > "))")
            output.append("选中文本：\(note.anchor.selectedText)")
            output.append("批注意见：\(note.comment)")
            if note.status == .anchorLost {
                output.append("锚点状态：anchor_lost，定位需要人工确认。")
            }
            output.append("定位信息：")

            if let sourceRange = note.anchor.sourceRange {
                output.append("- source range: \(sourceRange.lowerBound)-\(sourceRange.upperBound)")
            } else {
                output.append("- source range: unavailable")
            }

            output.append("- context before: \(emptyPlaceholder(note.anchor.contextBefore))")
            output.append("- context after: \(emptyPlaceholder(note.anchor.contextAfter))")
            output.append("- document hash: \(note.anchor.documentHash)")
        }

        output.append("")
        output.append("输出要求：")
        output.append("- 直接修改目标文件")
        output.append("- 完成后说明修改了哪些位置")
        output.append("- 如果定位不确定，先说明原因，不要擅自改写无关段落")

        return output.joined(separator: "\n")
    }

    private func emptyPlaceholder(_ value: String) -> String {
        value.isEmpty ? "无" : value
    }
}
