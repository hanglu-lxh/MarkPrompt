import Foundation
import CryptoKit

public struct SidecarFileLocator {
    public var applicationSupportDirectory: URL

    public init(applicationSupportDirectory: URL? = nil) {
        if let applicationSupportDirectory {
            self.applicationSupportDirectory = applicationSupportDirectory
        } else {
            self.applicationSupportDirectory = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("MarkPrompt", isDirectory: true)
                ?? FileManager.default.temporaryDirectory.appendingPathComponent("MarkPrompt", isDirectory: true)
        }
    }

    public func reviewSessionURL(for sourceURL: URL) -> URL {
        sourceURL
            .deletingPathExtension()
            .appendingPathExtension("review.json")
    }

    public func promptURL(for sourceURL: URL) -> URL {
        sourceURL
            .deletingPathExtension()
            .appendingPathExtension("prompt.md")
    }

    public func fallbackReviewSessionURL(for sourceURL: URL) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("Reviews", isDirectory: true)
            .appendingPathComponent("\(sourceURL.deletingPathExtension().lastPathComponent)-\(shortHash(sourceURL.path)).review.json")
    }

    public func fallbackPromptURL(for sourceURL: URL) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("Prompts", isDirectory: true)
            .appendingPathComponent("\(sourceURL.deletingPathExtension().lastPathComponent)-\(shortHash(sourceURL.path)).prompt.md")
    }

    private func shortHash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
