import MarkPromptKit
import XCTest

final class SidecarPersistenceTests: XCTestCase {
    func testSidecarLocatorUsesSourceDirectoryAndFallbackDirectories() {
        let support = URL(fileURLWithPath: "/tmp/MarkPromptSupport", isDirectory: true)
        let locator = SidecarFileLocator(applicationSupportDirectory: support)
        let source = URL(fileURLWithPath: "/tmp/source/sample_prd.md")

        XCTAssertEqual(locator.reviewSessionURL(for: source).path, "/tmp/source/sample_prd.review.json")
        XCTAssertEqual(locator.promptURL(for: source).path, "/tmp/source/sample_prd.prompt.md")
        XCTAssertTrue(locator.fallbackReviewSessionURL(for: source).path.contains("/tmp/MarkPromptSupport/Reviews/sample_prd-"))
        XCTAssertTrue(locator.fallbackPromptURL(for: source).path.contains("/tmp/MarkPromptSupport/Prompts/sample_prd-"))
    }

    func testReviewSessionStoreWritesAndReadsSidecar() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let session = ReviewSession(
            sourceFile: sourceURL.path,
            sourceHash: document.sourceHash,
            lastNoteSequence: 1,
            notes: [
                ReviewNote(
                    id: "note_001",
                    anchor: TextAnchor(
                        headingPath: ["标题"],
                        selectedText: "正文",
                        normalizedSelectedText: "正文",
                        sourceRange: SourceTextRange(lowerBound: 6, upperBound: 8),
                        renderedRange: RenderedTextRange(location: 3, length: 2),
                        contextBefore: "",
                        contextAfter: "",
                        documentHash: document.sourceHash
                    ),
                    comment: "修改"
                )
            ]
        )

        let result = try store.save(session, for: document)
        let loaded = store.loadSessionResult(for: document)

        XCTAssertFalse(result.usedFallback)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        XCTAssertEqual(loaded.session.notes.first?.id, "note_001")
        XCTAssertEqual(loaded.session.lastNoteSequence, 1)
    }

    func testReviewSessionStoreBacksUpUnreadableSidecarBeforeUsingEmptySession() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        let backupURL = sidecarURL.appendingPathExtension("invalid")
        let invalidSidecar = "{ invalid review json"
        try invalidSidecar.write(to: sidecarURL, atomically: true, encoding: .utf8)

        let loaded = store.loadSessionResult(for: document)

        XCTAssertTrue(loaded.session.notes.isEmpty)
        XCTAssertTrue(loaded.warning?.hasPrefix("批注文件读取失败") ?? false)
        XCTAssertTrue(loaded.warning?.contains(backupURL.path) ?? false)
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), invalidSidecar)

        try store.save(loaded.session, for: document)

        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), invalidSidecar)
    }

    func testReviewSessionStoreDoesNotOverwritePreviousUnreadableSidecarBackups() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        let firstBackupURL = sidecarURL.appendingPathExtension("invalid")
        let secondBackupURL = firstBackupURL.appendingPathExtension("2")
        let firstInvalidSidecar = "{ first invalid review json"
        let secondInvalidSidecar = "{ second invalid review json"
        try firstInvalidSidecar.write(to: sidecarURL, atomically: true, encoding: .utf8)

        let firstLoaded = store.loadSessionResult(for: document)

        XCTAssertTrue(firstLoaded.warning?.contains(firstBackupURL.path) ?? false)
        XCTAssertEqual(try String(contentsOf: firstBackupURL, encoding: .utf8), firstInvalidSidecar)

        try secondInvalidSidecar.write(to: sidecarURL, atomically: true, encoding: .utf8)

        let secondLoaded = store.loadSessionResult(for: document)

        XCTAssertTrue(secondLoaded.warning?.contains(secondBackupURL.path) ?? false)
        XCTAssertEqual(try String(contentsOf: firstBackupURL, encoding: .utf8), firstInvalidSidecar)
        XCTAssertEqual(try String(contentsOf: secondBackupURL, encoding: .utf8), secondInvalidSidecar)
    }

    func testReviewSessionStoreRestoresFallbackWhenMainSidecarIsUnreadable() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        let fallbackURL = locator.fallbackReviewSessionURL(for: sourceURL)
        let backupURL = sidecarURL.appendingPathExtension("invalid")
        let invalidSidecar = "{ invalid review json"
        let fallbackSession = ReviewSession(
            sourceFile: sourceURL.path,
            sourceHash: document.sourceHash,
            lastNoteSequence: 1,
            notes: [
                ReviewNote(
                    id: "note_001",
                    anchor: TextAnchor(
                        headingPath: ["标题"],
                        selectedText: "正文",
                        normalizedSelectedText: "正文",
                        sourceRange: SourceTextRange(lowerBound: 6, upperBound: 8),
                        renderedRange: RenderedTextRange(location: 3, length: 2),
                        contextBefore: "",
                        contextAfter: "",
                        documentHash: document.sourceHash
                    ),
                    comment: "从 fallback 恢复"
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: fallbackURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(fallbackSession).write(to: fallbackURL)
        try invalidSidecar.write(to: sidecarURL, atomically: true, encoding: .utf8)

        let loaded = store.loadSessionResult(for: document)

        XCTAssertEqual(loaded.session.notes.first?.comment, "从 fallback 恢复")
        XCTAssertEqual(loaded.url, fallbackURL)
        XCTAssertTrue(loaded.usedFallback)
        XCTAssertTrue(loaded.warning?.hasPrefix("批注文件读取失败，已从应用数据目录恢复") ?? false)
        XCTAssertTrue(loaded.warning?.contains(backupURL.path) ?? false)
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), invalidSidecar)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let repairedSession = try? decoder.decode(
            ReviewSession.self,
            from: Data(contentsOf: sidecarURL)
        )
        XCTAssertEqual(repairedSession?.notes.first?.comment, "从 fallback 恢复")

        let reopened = store.loadSessionResult(for: document)
        XCTAssertEqual(reopened.session.notes.first?.comment, "从 fallback 恢复")
        XCTAssertFalse(reopened.usedFallback)
        XCTAssertNil(reopened.warning)
    }

    func testReviewSessionStoreReplacesUnreadableSidecarDirectoryWhenRestoringFallback() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        let fallbackURL = locator.fallbackReviewSessionURL(for: sourceURL)
        let fallbackSession = ReviewSession(
            sourceFile: sourceURL.path,
            sourceHash: document.sourceHash,
            lastNoteSequence: 1,
            notes: [
                ReviewNote(
                    id: "note_001",
                    anchor: TextAnchor(
                        headingPath: ["标题"],
                        selectedText: "正文",
                        normalizedSelectedText: "正文",
                        sourceRange: SourceTextRange(lowerBound: 6, upperBound: 8),
                        renderedRange: RenderedTextRange(location: 3, length: 2),
                        contextBefore: "",
                        contextAfter: "",
                        documentHash: document.sourceHash
                    ),
                    comment: "目录损坏后从 fallback 修复"
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: fallbackURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(fallbackSession).write(to: fallbackURL)
        try FileManager.default.createDirectory(at: sidecarURL, withIntermediateDirectories: true)

        let loaded = store.loadSessionResult(for: document)

        XCTAssertEqual(loaded.session.notes.first?.comment, "目录损坏后从 fallback 修复")
        XCTAssertEqual(loaded.url, fallbackURL)
        XCTAssertTrue(loaded.usedFallback)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecarURL.path, isDirectory: &isDirectory))
        XCTAssertFalse(isDirectory.boolValue)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let repairedSession = try decoder.decode(
            ReviewSession.self,
            from: Data(contentsOf: sidecarURL)
        )
        XCTAssertEqual(repairedSession.notes.first?.comment, "目录损坏后从 fallback 修复")

        let reopened = store.loadSessionResult(for: document)
        XCTAssertEqual(reopened.session.notes.first?.comment, "目录损坏后从 fallback 修复")
        XCTAssertFalse(reopened.usedFallback)
        XCTAssertNil(reopened.warning)
    }

    func testReviewSessionStoreMirrorsFallbackWhenMainSidecarIsMissing() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        let fallbackURL = locator.fallbackReviewSessionURL(for: sourceURL)
        let fallbackSession = ReviewSession(
            sourceFile: sourceURL.path,
            sourceHash: document.sourceHash,
            lastNoteSequence: 1,
            notes: [
                ReviewNote(
                    id: "note_001",
                    anchor: TextAnchor(
                        headingPath: ["标题"],
                        selectedText: "正文",
                        normalizedSelectedText: "正文",
                        sourceRange: SourceTextRange(lowerBound: 6, upperBound: 8),
                        renderedRange: RenderedTextRange(location: 3, length: 2),
                        contextBefore: "",
                        contextAfter: "",
                        documentHash: document.sourceHash
                    ),
                    comment: "从 fallback 写回同名 sidecar"
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: fallbackURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(fallbackSession).write(to: fallbackURL)

        let loaded = store.loadSessionResult(for: document)

        XCTAssertEqual(loaded.session.notes.first?.comment, "从 fallback 写回同名 sidecar")
        XCTAssertEqual(loaded.url, fallbackURL)
        XCTAssertTrue(loaded.usedFallback)
        XCTAssertEqual(loaded.warning, "批注从应用数据目录恢复。")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecarURL.path))

        let reopened = store.loadSessionResult(for: document)
        XCTAssertEqual(reopened.session.notes.first?.comment, "从 fallback 写回同名 sidecar")
        XCTAssertFalse(reopened.usedFallback)
        XCTAssertNil(reopened.warning)
    }

    func testReviewSessionStoreBacksUpMainAndFallbackWhenBothAreUnreadable() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题\n\n正文".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let store = ReviewSessionStore(locator: locator)
        let sidecarURL = locator.reviewSessionURL(for: sourceURL)
        let fallbackURL = locator.fallbackReviewSessionURL(for: sourceURL)
        let sidecarBackupURL = sidecarURL.appendingPathExtension("invalid")
        let fallbackBackupURL = fallbackURL.appendingPathExtension("invalid")
        let invalidSidecar = "{ invalid main review json"
        let invalidFallback = "{ invalid fallback review json"
        try FileManager.default.createDirectory(
            at: fallbackURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try invalidSidecar.write(to: sidecarURL, atomically: true, encoding: .utf8)
        try invalidFallback.write(to: fallbackURL, atomically: true, encoding: .utf8)

        let loaded = store.loadSessionResult(for: document)

        XCTAssertTrue(loaded.session.notes.isEmpty)
        XCTAssertFalse(loaded.usedFallback)
        XCTAssertEqual(loaded.url, sidecarURL)
        XCTAssertTrue(loaded.warning?.hasPrefix("批注文件读取失败，已创建空会话") ?? false)
        XCTAssertTrue(loaded.warning?.contains(sidecarBackupURL.path) ?? false)
        XCTAssertTrue(loaded.warning?.contains("备用批注文件读取失败") ?? false)
        XCTAssertTrue(loaded.warning?.contains(fallbackBackupURL.path) ?? false)
        XCTAssertEqual(try String(contentsOf: sidecarBackupURL, encoding: .utf8), invalidSidecar)
        XCTAssertEqual(try String(contentsOf: fallbackBackupURL, encoding: .utf8), invalidFallback)

        try store.save(loaded.session, for: document)

        XCTAssertEqual(try String(contentsOf: sidecarBackupURL, encoding: .utf8), invalidSidecar)
        XCTAssertEqual(try String(contentsOf: fallbackBackupURL, encoding: .utf8), invalidFallback)
    }

    func testPromptFileStoreWritesPromptFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let store = PromptFileStore(
            locator: SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        )

        let result = try store.save(prompt: "# Prompt", for: document)

        XCTAssertEqual(result.url.lastPathComponent, "sample.prompt.md")
        XCTAssertEqual(try String(contentsOf: result.url, encoding: .utf8), "# Prompt")
    }

    func testPromptFileStoreFailureReportsPrimaryAndFallbackPromptPaths() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let sourceURL = temp.appendingPathComponent("sample.md")
        try "# 标题".write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = try DocumentLoader().loadDocument(from: sourceURL)
        let locator = SidecarFileLocator(applicationSupportDirectory: temp.appendingPathComponent("Support", isDirectory: true))
        let promptURL = locator.promptURL(for: sourceURL)
        let fallbackURL = locator.fallbackPromptURL(for: sourceURL)
        try FileManager.default.createDirectory(at: promptURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fallbackURL, withIntermediateDirectories: true)
        let store = PromptFileStore(locator: locator)

        XCTAssertThrowsError(try store.save(prompt: "# Prompt", for: document)) { error in
            let promptError = error as? PromptFileSaveError
            XCTAssertEqual(promptError?.primaryURL.path, promptURL.path)
            XCTAssertEqual(promptError?.fallbackURL.path, fallbackURL.path)
            XCTAssertTrue(error.localizedDescription.contains(promptURL.path))
            XCTAssertTrue(error.localizedDescription.contains(fallbackURL.path))
        }
    }
}
