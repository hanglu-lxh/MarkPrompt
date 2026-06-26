import Foundation

public struct MarkdownDocument: Identifiable, Equatable {
    public let id: UUID
    public let fileURL: URL?
    public var displayName: String
    public var rawMarkdown: String
    public var sourceHash: String
    public var outline: [DocumentHeading]
    public var renderModel: MarkdownRenderModel

    public init(
        id: UUID = UUID(),
        fileURL: URL?,
        displayName: String,
        rawMarkdown: String,
        sourceHash: String,
        outline: [DocumentHeading],
        renderModel: MarkdownRenderModel
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.rawMarkdown = rawMarkdown
        self.sourceHash = sourceHash
        self.outline = outline
        self.renderModel = renderModel
    }
}
