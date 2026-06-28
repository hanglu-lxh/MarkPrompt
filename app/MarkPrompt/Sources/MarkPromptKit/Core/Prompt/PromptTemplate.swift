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
    public let name = "Markdown 修改任务"

    public init() {}

    public func render(context: PromptRenderContext) -> String {
        let targetPath = context.document.fileURL?.path
            ?? context.session.sourceFile
            ?? context.document.displayName

        var output: [String] = [
            "# Markdown 修改任务",
            "",
            "目标文件：",
            targetPath,
            "",
            "请根据以下批注修改内容。",
            "",
            "## 批注列表"
        ]

        for note in context.notes {
            output.append("")
            output.append("[NOTE \(note.id)]")
            output.append("位置：\(positionDescription(for: note, in: context.document))")
            output.append("批注内容：\(compactSelectedText(note.anchor.selectedText))")
            output.append("批注意见：\(note.comment)")
        }

        return output.joined(separator: "\n")
    }

    private func positionDescription(for note: ReviewNote, in document: MarkdownDocument) -> String {
        guard note.status != .anchorLost, let sourceRange = note.anchor.sourceRange else {
            return "未精确定位，请搜索批注内容"
        }

        if let lineRange = lineRangeDescription(for: sourceRange, in: document.rawMarkdown) {
            return lineRange
        }

        return "字符 \(sourceRange.lowerBound)-\(sourceRange.upperBound)"
    }

    private func lineRangeDescription(for sourceRange: SourceTextRange, in rawMarkdown: String) -> String? {
        let source = rawMarkdown as NSString
        guard sourceRange.lowerBound >= 0,
              sourceRange.upperBound >= sourceRange.lowerBound,
              sourceRange.upperBound <= source.length
        else {
            return nil
        }

        let endOffset = sourceRange.upperBound > sourceRange.lowerBound
            ? sourceRange.upperBound - 1
            : sourceRange.lowerBound
        let startLine = lineNumber(at: sourceRange.lowerBound, in: source)
        let endLine = lineNumber(at: endOffset, in: source)

        if startLine == endLine {
            return "第 \(startLine) 行"
        }

        return "第 \(startLine)-\(endLine) 行"
    }

    private func lineNumber(at offset: Int, in source: NSString) -> Int {
        let safeOffset = min(max(0, offset), source.length)
        let prefix = source.substring(to: safeOffset)
        return prefix.reduce(1) { line, character in
            character == "\n" ? line + 1 : line
        }
    }

    private func compactSelectedText(_ value: String) -> String {
        let normalized = TextNormalizer.normalized(value)
        let maximumLength = 240
        guard normalized.count > maximumLength else {
            return normalized
        }

        return "\(normalized.prefix(maximumLength))..."
    }
}
