import AppKit
@testable import MarkPromptKit
import XCTest

@MainActor
final class AppPersistenceAndClipboardTests: XCTestCase {
    func testRecentDocumentStoreKeepsMostRecentUniquePathsWithinLimit() throws {
        let defaults = try isolatedUserDefaults()
        let store = RecentDocumentStore(userDefaults: defaults, maximumCount: 2)
        let firstURL = URL(fileURLWithPath: "/tmp/first.md")
        let secondURL = URL(fileURLWithPath: "/tmp/second.md")
        let thirdURL = URL(fileURLWithPath: "/tmp/third.md")

        store.recordOpenedDocument(at: firstURL)
        store.recordOpenedDocument(at: secondURL)
        store.recordOpenedDocument(at: firstURL)
        store.recordOpenedDocument(at: thirdURL)

        XCTAssertEqual(store.lastOpenedDocumentURL(), thirdURL)
        XCTAssertEqual(store.recentDocumentURLs(), [thirdURL, firstURL])
    }

    func testOpeningDocumentRecordsRecentHistoryAndRestoresLastDocument() throws {
        let defaults = try isolatedUserDefaults()
        let store = RecentDocumentStore(userDefaults: defaults, maximumCount: 4)
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let firstURL = temp.appendingPathComponent("first.md")
        let secondURL = temp.appendingPathComponent("second.md")
        try sampleMarkdown(title: "First").write(to: firstURL, atomically: true, encoding: .utf8)
        try sampleMarkdown(title: "Second").write(to: secondURL, atomically: true, encoding: .utf8)
        let state = AppState(recentDocumentStore: store)

        XCTAssertTrue(state.openDocument(at: firstURL))
        XCTAssertTrue(state.openDocument(at: secondURL))

        XCTAssertEqual(state.recentDocumentURLs.map(\.lastPathComponent), ["second.md", "first.md"])

        let restored = AppState(recentDocumentStore: store)
        XCTAssertTrue(restored.openLastDocumentIfAvailable())
        XCTAssertEqual(restored.currentDocument?.displayName, "second.md")
    }

    func testClipboardResolverFindsMarkdownFileURLs() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        let markdownURL = URL(fileURLWithPath: "/tmp/from-clipboard.md")
        let textURL = URL(fileURLWithPath: "/tmp/not-markdown.txt")

        pasteboard.writeObjects([markdownURL as NSURL, textURL as NSURL])

        XCTAssertEqual(
            ClipboardMarkdownDocumentResolver.markdownFileURLs(from: pasteboard),
            [markdownURL.standardizedFileURL]
        )
    }

    func testClipboardResolverFindsMarkdownPathStrings() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        let markdownURL = URL(fileURLWithPath: "/tmp/from-string.markdown")
        pasteboard.setString(markdownURL.path, forType: .string)

        XCTAssertEqual(
            ClipboardMarkdownDocumentResolver.markdownFileURLs(from: pasteboard),
            [markdownURL.standardizedFileURL]
        )
    }

    func testDismissedClipboardCandidateDoesNotReappearUntilClipboardChanges() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        let firstURL = URL(fileURLWithPath: "/tmp/first.md")
        let secondURL = URL(fileURLWithPath: "/tmp/second.md")
        let state = AppState()

        pasteboard.setString(firstURL.path, forType: .string)
        state.refreshClipboardMarkdownCandidate(pasteboard: pasteboard)
        XCTAssertEqual(state.clipboardMarkdownCandidate?.url, firstURL.standardizedFileURL)

        state.dismissClipboardMarkdownCandidate()
        state.refreshClipboardMarkdownCandidate(pasteboard: pasteboard)
        XCTAssertNil(state.clipboardMarkdownCandidate)

        pasteboard.clearContents()
        pasteboard.setString(secondURL.path, forType: .string)
        state.refreshClipboardMarkdownCandidate(pasteboard: pasteboard)

        XCTAssertEqual(state.clipboardMarkdownCandidate?.url, secondURL.standardizedFileURL)
    }

    private func isolatedUserDefaults() throws -> UserDefaults {
        let suiteName = "MarkPromptTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func sampleMarkdown(title: String) -> String {
        """
        # \(title)

        Body.
        """
    }
}
