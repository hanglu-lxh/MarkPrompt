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

    func testClearingRecentDocumentsReportsClearedCount() throws {
        let defaults = try isolatedUserDefaults()
        let store = RecentDocumentStore(userDefaults: defaults, maximumCount: 4)
        let firstURL = URL(fileURLWithPath: "/tmp/first-\(UUID().uuidString).md")
        let secondURL = URL(fileURLWithPath: "/tmp/second-\(UUID().uuidString).md")
        store.recordOpenedDocument(at: firstURL)
        store.recordOpenedDocument(at: secondURL)
        let state = AppState(recentDocumentStore: store)

        XCTAssertEqual(state.recentDocumentURLs.count, 2)

        state.clearRecentDocuments()

        XCTAssertTrue(state.recentDocumentURLs.isEmpty)
        XCTAssertTrue(store.recentDocumentURLs().isEmpty)
        XCTAssertEqual(state.saveState, .historyCleared(2))

        state.clearRecentDocuments()
        XCTAssertEqual(state.saveState, .historyCleared(2))
    }

    func testDismissingTransientHistoryFeedbackRestoresNeutralSaveState() throws {
        let defaults = try isolatedUserDefaults()
        let store = RecentDocumentStore(userDefaults: defaults, maximumCount: 4)
        let state = AppState(recentDocumentStore: store)

        state.saveState = .historyCleared(2)
        state.dismissTransientHistoryFeedback()
        XCTAssertEqual(state.saveState, .idle)

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let documentURL = temp.appendingPathComponent("active.md")
        try sampleMarkdown(title: "Active").write(to: documentURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(state.openDocument(at: documentURL))

        state.saveState = .historyCleaned(1)
        state.dismissTransientHistoryFeedback()
        XCTAssertEqual(state.saveState, .loaded)

        state.saveState = .failed("需要用户处理")
        state.dismissTransientHistoryFeedback()
        XCTAssertEqual(state.saveState, .failed("需要用户处理"))
    }

    func testOpeningMissingRecentDocumentRemovesItAndReportsFeedback() throws {
        let defaults = try isolatedUserDefaults()
        let store = RecentDocumentStore(userDefaults: defaults, maximumCount: 4)
        let missingURL = URL(fileURLWithPath: "/tmp/markprompt-missing-\(UUID().uuidString).md")
        store.recordOpenedDocument(at: missingURL)
        let state = AppState(recentDocumentStore: store)

        XCTAssertEqual(state.recentDocumentURLs, [missingURL.standardizedFileURL])
        XCTAssertFalse(state.openRecentDocument(at: missingURL))

        XCTAssertTrue(state.recentDocumentURLs.isEmpty)
        XCTAssertTrue(store.recentDocumentURLs().isEmpty)
        XCTAssertEqual(
            state.saveState,
            .failed("打开历史中的文件不存在，已从历史移除：\(missingURL.lastPathComponent)")
        )
    }

    func testRemovingMissingRecentDocumentsKeepsExistingHistoryAndReportsCount() throws {
        let defaults = try isolatedUserDefaults()
        let store = RecentDocumentStore(userDefaults: defaults, maximumCount: 4)
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let existingURL = temp.appendingPathComponent("active.md")
        let missingURL = temp.appendingPathComponent("missing.md")
        try sampleMarkdown(title: "Active").write(to: existingURL, atomically: true, encoding: .utf8)
        store.recordOpenedDocument(at: existingURL)
        store.recordOpenedDocument(at: missingURL)
        let state = AppState(recentDocumentStore: store)

        XCTAssertEqual(state.removeMissingRecentDocuments(), 1)

        XCTAssertEqual(state.recentDocumentURLs, [existingURL.standardizedFileURL])
        XCTAssertEqual(store.recentDocumentURLs(), [existingURL.standardizedFileURL])
        XCTAssertEqual(state.saveState, .historyCleaned(1))
        XCTAssertEqual(state.removeMissingRecentDocuments(), 0)
        XCTAssertEqual(state.saveState, .historyCleaned(1))
    }

    func testRemovingUnavailableRecentDocumentsRemovesMissingAndUnsupportedHistoryAndReportsCount() throws {
        let defaults = try isolatedUserDefaults()
        let store = RecentDocumentStore(userDefaults: defaults, maximumCount: 4)
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let existingURL = temp.appendingPathComponent("active.md")
        let unsupportedURL = temp.appendingPathComponent("notes.txt")
        let missingURL = temp.appendingPathComponent("missing.md")
        try sampleMarkdown(title: "Active").write(to: existingURL, atomically: true, encoding: .utf8)
        try "plain text".write(to: unsupportedURL, atomically: true, encoding: .utf8)
        store.recordOpenedDocument(at: existingURL)
        store.recordOpenedDocument(at: unsupportedURL)
        store.recordOpenedDocument(at: missingURL)
        let state = AppState(recentDocumentStore: store)

        XCTAssertEqual(state.removeUnavailableRecentDocuments(), 2)

        XCTAssertEqual(state.recentDocumentURLs, [existingURL.standardizedFileURL])
        XCTAssertEqual(store.recentDocumentURLs(), [existingURL.standardizedFileURL])
        XCTAssertEqual(state.saveState, .historyCleaned(2))
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
