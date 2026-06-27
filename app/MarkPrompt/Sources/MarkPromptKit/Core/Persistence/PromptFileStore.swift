import Foundation

public struct PromptFileSaveError: LocalizedError, Sendable {
    public var primaryURL: URL
    public var fallbackURL: URL
    public var primaryErrorDescription: String
    public var fallbackErrorDescription: String

    public init(
        primaryURL: URL,
        fallbackURL: URL,
        primaryErrorDescription: String,
        fallbackErrorDescription: String
    ) {
        self.primaryURL = primaryURL
        self.fallbackURL = fallbackURL
        self.primaryErrorDescription = primaryErrorDescription
        self.fallbackErrorDescription = fallbackErrorDescription
    }

    public var errorDescription: String? {
        "主路径写入失败：\(primaryURL.path)（\(primaryErrorDescription)）；备用路径写入失败：\(fallbackURL.path)（\(fallbackErrorDescription)）"
    }
}

public struct PromptFileStore {
    private let locator: SidecarFileLocator

    public init(locator: SidecarFileLocator = SidecarFileLocator()) {
        self.locator = locator
    }

    @discardableResult
    public func save(prompt: String, for document: MarkdownDocument) throws -> PersistenceWriteResult {
        guard let fileURL = document.fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = Data(prompt.utf8)
        let promptURL = locator.promptURL(for: fileURL)

        do {
            try write(data, to: promptURL)
            return PersistenceWriteResult(url: promptURL, usedFallback: false)
        } catch {
            let primaryError = error
            let fallbackURL = locator.fallbackPromptURL(for: fileURL)
            do {
                try write(data, to: fallbackURL)
                return PersistenceWriteResult(url: fallbackURL, usedFallback: true)
            } catch {
                throw PromptFileSaveError(
                    primaryURL: promptURL,
                    fallbackURL: fallbackURL,
                    primaryErrorDescription: primaryError.localizedDescription,
                    fallbackErrorDescription: error.localizedDescription
                )
            }
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }
}
