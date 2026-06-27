import Foundation

public struct RecentDocumentStore {
    public static let defaultRecentDocumentLimit = 50

    private let userDefaults: UserDefaults
    private let maximumCount: Int

    public init(
        userDefaults: UserDefaults = .standard,
        maximumCount: Int = Self.defaultRecentDocumentLimit
    ) {
        self.userDefaults = userDefaults
        self.maximumCount = maximumCount
    }

    public func recentDocumentURLs() -> [URL] {
        userDefaults.stringArray(forKey: Self.recentDocumentPathsKey)?
            .map { URL(fileURLWithPath: $0) } ?? []
    }

    public func lastOpenedDocumentURL() -> URL? {
        guard let path = userDefaults.string(forKey: Self.lastOpenedDocumentPathKey) else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    public func recordOpenedDocument(at url: URL) {
        let path = normalizedPath(for: url)
        var paths = userDefaults.stringArray(forKey: Self.recentDocumentPathsKey) ?? []
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        if paths.count > maximumCount {
            paths = Array(paths.prefix(maximumCount))
        }

        userDefaults.set(paths, forKey: Self.recentDocumentPathsKey)
        userDefaults.set(path, forKey: Self.lastOpenedDocumentPathKey)
    }

    public func clear() {
        userDefaults.removeObject(forKey: Self.recentDocumentPathsKey)
        userDefaults.removeObject(forKey: Self.lastOpenedDocumentPathKey)
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private static let recentDocumentPathsKey = "markprompt.recentDocumentPaths"
    private static let lastOpenedDocumentPathKey = "markprompt.lastOpenedDocumentPath"
}
