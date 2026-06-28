import Foundation

public struct QuickPromptDefinition: Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var insertedText: String

    public init(id: String, label: String, insertedText: String) {
        self.id = id
        self.label = label
        self.insertedText = insertedText
    }
}

public enum QuickPromptCatalog {
    public static let defaults: [QuickPromptDefinition] = [
        QuickPromptDefinition(id: "polish", label: "润色", insertedText: "请润色这段内容，让表达更自然、更清晰，但保持原意。"),
        QuickPromptDefinition(id: "rewrite", label: "重写", insertedText: "请重写这段内容，保留核心意思，但换一种更顺畅的表达方式。"),
        QuickPromptDefinition(id: "expand", label: "扩写", insertedText: "请扩写这段内容，补足必要背景、细节或例子。"),
        QuickPromptDefinition(id: "shorten", label: "缩短", insertedText: "请缩短这段内容，删除重复表达，保留关键信息。"),
        QuickPromptDefinition(id: "fix-grammar", label: "修复语法", insertedText: "请修复这段内容的语法、标点和用词问题。"),
        QuickPromptDefinition(id: "translate-en", label: "译为英文", insertedText: "请将这段内容翻译成自然、准确的英文。"),
        QuickPromptDefinition(id: "translate-zh", label: "译为中文", insertedText: "请将这段内容翻译成自然、准确的中文。")
    ]

    public static func usage(for definition: QuickPromptDefinition) -> QuickPromptUsage {
        QuickPromptUsage(
            id: definition.id,
            label: definition.label,
            insertedText: definition.insertedText
        )
    }

    public static func commentAfterSelecting(
        currentComment: String,
        selectedQuickPrompt: QuickPromptUsage?,
        definition: QuickPromptDefinition
    ) -> String {
        let trimmed = currentComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return definition.insertedText
        }

        if let selectedQuickPrompt,
           trimmed == selectedQuickPrompt.insertedText.trimmingCharacters(in: .whitespacesAndNewlines) {
            return definition.insertedText
        }

        return "\(trimmed)\n\(definition.insertedText)"
    }
}
