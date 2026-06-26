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
        QuickPromptDefinition(id: "improve-expression", label: "优化表达", insertedText: "请优化这段表达，让它更清晰、更直接，但保持原意。"),
        QuickPromptDefinition(id: "rewrite-section", label: "重写这段", insertedText: "请重写这段内容，使结构更清楚，语气更适合产品文档。"),
        QuickPromptDefinition(id: "improve-tone", label: "优化语气", insertedText: "请优化语气，让表达更自然、更适合目标读者。"),
        QuickPromptDefinition(id: "add-evidence", label: "补充措施", insertedText: "请补充一个具体措施或示例，让这段更可执行。"),
        QuickPromptDefinition(id: "strengthen-argument", label: "强化论证", insertedText: "请强化这段论证，补足因果关系和判断依据。"),
        QuickPromptDefinition(id: "compress", label: "压缩精简", insertedText: "请压缩这段内容，删除重复表达，保留关键信息。")
    ]

    public static func insertedComment(
        currentComment: String,
        definition: QuickPromptDefinition
    ) -> String {
        let trimmed = currentComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return definition.insertedText
        }

        return "\(trimmed)\n\(definition.insertedText)"
    }
}
