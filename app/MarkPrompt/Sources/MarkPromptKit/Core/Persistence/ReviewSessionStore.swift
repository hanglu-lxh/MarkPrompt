import Foundation

public struct PersistenceWriteResult: Equatable, Sendable {
    public var url: URL
    public var usedFallback: Bool

    public init(url: URL, usedFallback: Bool) {
        self.url = url
        self.usedFallback = usedFallback
    }
}

public struct ReviewSessionLoadResult: Equatable, Sendable {
    public var session: ReviewSession
    public var url: URL?
    public var usedFallback: Bool
    public var warning: String?

    public init(session: ReviewSession, url: URL?, usedFallback: Bool, warning: String? = nil) {
        self.session = session
        self.url = url
        self.usedFallback = usedFallback
        self.warning = warning
    }
}

public struct ReviewSessionStore {
    private let locator: SidecarFileLocator
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(locator: SidecarFileLocator = SidecarFileLocator()) {
        self.locator = locator
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadSession(for document: MarkdownDocument) -> ReviewSession {
        loadSessionResult(for: document).session
    }

    public func loadSessionResult(for document: MarkdownDocument) -> ReviewSessionLoadResult {
        guard let fileURL = document.fileURL else {
            return ReviewSessionLoadResult(session: makeEmptySession(for: document), url: nil, usedFallback: false)
        }

        let sidecarURL = locator.reviewSessionURL(for: fileURL)
        if FileManager.default.fileExists(atPath: sidecarURL.path) {
            do {
                let data = try Data(contentsOf: sidecarURL)
                return ReviewSessionLoadResult(
                    session: try decoder.decode(ReviewSession.self, from: data),
                    url: sidecarURL,
                    usedFallback: false
                )
            } catch {
                return ReviewSessionLoadResult(
                    session: makeEmptySession(for: document),
                    url: sidecarURL,
                    usedFallback: false,
                    warning: "批注文件读取失败，已创建空会话：\(error.localizedDescription)"
                )
            }
        }

        let fallbackURL = locator.fallbackReviewSessionURL(for: fileURL)
        guard FileManager.default.fileExists(atPath: fallbackURL.path) else {
            return ReviewSessionLoadResult(session: makeEmptySession(for: document), url: nil, usedFallback: false)
        }

        do {
            let data = try Data(contentsOf: fallbackURL)
            return ReviewSessionLoadResult(
                session: try decoder.decode(ReviewSession.self, from: data),
                url: fallbackURL,
                usedFallback: true,
                warning: "批注从应用数据目录恢复。"
            )
        } catch {
            return ReviewSessionLoadResult(
                session: makeEmptySession(for: document),
                url: fallbackURL,
                usedFallback: true,
                warning: "备用批注文件读取失败，已创建空会话：\(error.localizedDescription)"
            )
        }
    }

    @discardableResult
    public func save(_ session: ReviewSession, for document: MarkdownDocument) throws -> PersistenceWriteResult {
        guard let fileURL = document.fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let sidecarURL = locator.reviewSessionURL(for: fileURL)
        let data = try encoder.encode(session)

        do {
            try write(data, to: sidecarURL)
            return PersistenceWriteResult(url: sidecarURL, usedFallback: false)
        } catch {
            let fallbackURL = locator.fallbackReviewSessionURL(for: fileURL)
            try write(data, to: fallbackURL)
            return PersistenceWriteResult(url: fallbackURL, usedFallback: true)
        }
    }

    private func makeEmptySession(for document: MarkdownDocument) -> ReviewSession {
        ReviewSession(
            sourceFile: document.fileURL?.path,
            sourceHash: document.sourceHash
        )
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }
}
