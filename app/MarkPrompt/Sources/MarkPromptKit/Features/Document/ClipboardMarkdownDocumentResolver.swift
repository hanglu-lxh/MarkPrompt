import AppKit
import Foundation
import UniformTypeIdentifiers

public struct ClipboardMarkdownCandidate: Equatable, Sendable {
    public var url: URL

    public init(url: URL) {
        self.url = url.standardizedFileURL
    }

    public var displayName: String {
        url.lastPathComponent
    }
}

public enum ClipboardMarkdownDocumentResolver {
    public static func markdownFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        uniqueFileURLs(from: pasteboard).filter(isSupportedMarkdownURL)
    }

    private static func uniqueFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        if let readURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            urls.append(contentsOf: readURLs)
        }

        if let filenames = pasteboard.propertyList(forType: filenamesPasteboardType) as? [String] {
            urls.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        }

        for item in pasteboard.pasteboardItems ?? [] {
            urls.append(contentsOf: fileURLs(from: item))
        }

        var seenPaths: Set<String> = []
        return urls.compactMap { url in
            guard let normalized = normalizedFileURL(from: url) else {
                return nil
            }

            let path = normalized.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else {
                return nil
            }

            return normalized
        }
    }

    private static func fileURLs(from item: NSPasteboardItem) -> [URL] {
        [
            item.string(forType: .fileURL),
            item.string(forType: .URL),
            item.string(forType: .string)
        ].compactMap { string in
            guard let string else {
                return nil
            }

            return fileURL(from: string)
        }
    }

    private static func fileURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }

        return URL(string: trimmed).flatMap(normalizedFileURL)
    }

    private static func normalizedFileURL(from url: URL) -> URL? {
        if url.isFileURL {
            return url.standardizedFileURL
        }

        if url.scheme == nil, url.path.hasPrefix("/") {
            return URL(fileURLWithPath: url.path).standardizedFileURL
        }

        return nil
    }

    private static func isSupportedMarkdownURL(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static let supportedExtensions: Set<String> = ["md", "markdown"]
    private static let filenamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
}
