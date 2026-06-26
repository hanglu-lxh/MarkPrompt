import Foundation

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
            let fallbackURL = locator.fallbackPromptURL(for: fileURL)
            try write(data, to: fallbackURL)
            return PersistenceWriteResult(url: fallbackURL, usedFallback: true)
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
