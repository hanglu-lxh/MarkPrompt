import Foundation

public enum DocumentLoaderError: LocalizedError, Equatable {
    case unsupportedFileExtension(String)
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFileExtension(ext):
            guard !ext.isEmpty else {
                return "只能打开 .md 或 .markdown 文件，当前文件没有扩展名。"
            }
            return "只能打开 .md 或 .markdown 文件，当前文件类型为 .\(ext)。"
        case let .unreadable(message):
            return "无法读取 Markdown 文件：\(message)"
        }
    }
}

public struct DocumentLoader {
    private let parser: MarkdownParser

    public init(parser: MarkdownParser = MarkdownParser()) {
        self.parser = parser
    }

    public func canLoadDocument(from url: URL) -> Bool {
        Self.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    public func loadDocument(from url: URL) throws -> MarkdownDocument {
        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            throw DocumentLoaderError.unsupportedFileExtension(ext)
        }

        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            return parser.parse(source, fileURL: url)
        } catch {
            throw DocumentLoaderError.unreadable(error.localizedDescription)
        }
    }

    private static let supportedExtensions: Set<String> = ["md", "markdown"]
}
