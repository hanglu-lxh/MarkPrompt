public struct SidecarLoadWarningPresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public static func presentation(from message: String) -> SidecarLoadWarningPresentation? {
        let warningPresentations = [
            (
                prefix: "批注文件读取失败，已从应用数据目录恢复：",
                title: "批注已恢复",
                message: "文档已打开，批注已从应用数据目录恢复。"
            ),
            (
                prefix: "批注从应用数据目录恢复。",
                title: "批注已恢复",
                message: "文档已打开，批注已从应用数据目录恢复。"
            ),
            (
                prefix: "批注文件读取失败，已创建空会话：",
                title: "批注未恢复",
                message: "文档已打开，批注未恢复；已使用空批注会话继续。"
            ),
            (
                prefix: "备用批注文件读取失败，已创建空会话：",
                title: "批注未恢复",
                message: "文档已打开，批注未恢复；已使用空批注会话继续。"
            )
        ]

        guard let presentation = warningPresentations.first(where: { message.hasPrefix($0.prefix) }) else {
            return nil
        }

        let detail = String(message.dropFirst(presentation.prefix.count))
        return SidecarLoadWarningPresentation(
            title: presentation.title,
            message: "\(presentation.message)\(detail)",
            systemImage: "exclamationmark.triangle"
        )
    }
}
