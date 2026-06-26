import CryptoKit
import Foundation
import Markdown

public struct MarkdownParser {
    public init() {}

    public func parse(_ source: String, fileURL: URL? = nil) -> MarkdownDocument {
        _ = Document(parsing: source)

        let outline = OutlineBuilder.build(from: source)
        let renderModel = MarkdownAttributedRenderer().render(
            source: source,
            outline: outline,
            baseURL: fileURL?.deletingLastPathComponent()
        )
        let displayName = fileURL?.lastPathComponent ?? "Untitled Markdown"

        return MarkdownDocument(
            fileURL: fileURL,
            displayName: displayName,
            rawMarkdown: source,
            sourceHash: Self.sourceHash(for: source),
            outline: outline,
            renderModel: renderModel
        )
    }

    public static func sourceHash(for source: String) -> String {
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
