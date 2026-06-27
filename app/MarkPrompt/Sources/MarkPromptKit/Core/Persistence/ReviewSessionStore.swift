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
                let backupURL = backupUnreadableSidecar(at: sidecarURL)
                let fallbackURL = locator.fallbackReviewSessionURL(for: fileURL)
                if FileManager.default.fileExists(atPath: fallbackURL.path) {
                    do {
                        let fallbackData = try Data(contentsOf: fallbackURL)
                        let fallbackSession = try decoder.decode(ReviewSession.self, from: fallbackData)
                        mirrorFallbackSidecar(fallbackData, to: sidecarURL)
                        return ReviewSessionLoadResult(
                            session: fallbackSession,
                            url: fallbackURL,
                            usedFallback: true,
                            warning: unreadableSidecarWarning(
                                prefix: "批注文件读取失败，已从应用数据目录恢复",
                                error: error,
                                backupURL: backupURL
                            )
                        )
                    } catch let fallbackError {
                        let fallbackBackupURL = backupUnreadableSidecar(at: fallbackURL)
                        return ReviewSessionLoadResult(
                            session: makeEmptySession(for: document),
                            url: sidecarURL,
                            usedFallback: false,
                            warning: unreadableMainAndFallbackSidecarsWarning(
                                mainError: error,
                                mainBackupURL: backupURL,
                                fallbackError: fallbackError,
                                fallbackBackupURL: fallbackBackupURL
                            )
                        )
                    }
                }

                return ReviewSessionLoadResult(
                    session: makeEmptySession(for: document),
                    url: sidecarURL,
                    usedFallback: false,
                    warning: unreadableSidecarWarning(
                        prefix: "批注文件读取失败，已创建空会话",
                        error: error,
                        backupURL: backupURL
                    )
                )
            }
        }

        let fallbackURL = locator.fallbackReviewSessionURL(for: fileURL)
        guard FileManager.default.fileExists(atPath: fallbackURL.path) else {
            return ReviewSessionLoadResult(session: makeEmptySession(for: document), url: nil, usedFallback: false)
        }

        do {
            let data = try Data(contentsOf: fallbackURL)
            let fallbackSession = try decoder.decode(ReviewSession.self, from: data)
            mirrorFallbackSidecar(data, to: sidecarURL)
            return ReviewSessionLoadResult(
                session: fallbackSession,
                url: fallbackURL,
                usedFallback: true,
                warning: "批注从应用数据目录恢复。"
            )
        } catch {
            let backupURL = backupUnreadableSidecar(at: fallbackURL)
            return ReviewSessionLoadResult(
                session: makeEmptySession(for: document),
                url: fallbackURL,
                usedFallback: true,
                warning: unreadableSidecarWarning(
                    prefix: "备用批注文件读取失败，已创建空会话",
                    error: error,
                    backupURL: backupURL
                )
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

    private func mirrorFallbackSidecar(_ data: Data, to sidecarURL: URL) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: sidecarURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            try? FileManager.default.removeItem(at: sidecarURL)
        }

        try? write(data, to: sidecarURL)
    }

    private func makeEmptySession(for document: MarkdownDocument) -> ReviewSession {
        ReviewSession(
            sourceFile: document.fileURL?.path,
            sourceHash: document.sourceHash
        )
    }

    private func unreadableSidecarWarning(prefix: String, error: Error, backupURL: URL?) -> String {
        var message = "\(prefix)：\(error.localizedDescription)"
        if let backupURL {
            message += "。原文件已备份到：\(backupURL.path)"
        }
        return message
    }

    private func unreadableMainAndFallbackSidecarsWarning(
        mainError: Error,
        mainBackupURL: URL?,
        fallbackError: Error,
        fallbackBackupURL: URL?
    ) -> String {
        let mainWarning = unreadableSidecarWarning(
            prefix: "批注文件读取失败，已创建空会话",
            error: mainError,
            backupURL: mainBackupURL
        )
        let fallbackWarning = unreadableSidecarWarning(
            prefix: "备用批注文件读取失败",
            error: fallbackError,
            backupURL: fallbackBackupURL
        )
        return "\(mainWarning)。\(fallbackWarning)"
    }

    private func backupUnreadableSidecar(at url: URL) -> URL? {
        let backupURL = availableUnreadableSidecarBackupURL(for: url)
        do {
            try FileManager.default.copyItem(at: url, to: backupURL)
            return backupURL
        } catch {
            return nil
        }
    }

    private func availableUnreadableSidecarBackupURL(for url: URL) -> URL {
        let firstBackupURL = url.appendingPathExtension("invalid")
        guard FileManager.default.fileExists(atPath: firstBackupURL.path) else {
            return firstBackupURL
        }

        var suffix = 2
        while true {
            let candidateURL = firstBackupURL.appendingPathExtension("\(suffix)")
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            suffix += 1
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
