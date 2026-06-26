import AppKit
import Foundation
import MarkPromptKit

struct FixtureMetric: Codable {
    var appearance: String
    var file: String
    var title: String
    var renderedCharacters: Int
    var sourceCharacters: Int
    var headingCount: Int
    var blockCount: Int
    var blockKinds: [String: Int]
    var snapshotWidth: Int
    var snapshotHeight: Int
    var outputImage: String
}

@main
enum ReaderFixtureSnapshotTool {
    @MainActor
    static func main() {
        do {
            try run()
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }

    @MainActor
    private static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let workspaceRoot = try findWorkspaceRoot()
        let fixturesDirectory = argumentValue("--fixtures", in: arguments)
            .map { URL(fileURLWithPath: $0, relativeTo: workspaceRoot).standardizedFileURL }
            ?? workspaceRoot.appendingPathComponent("samples/markdown/reader-fixtures")
        let outputDirectory = argumentValue("--output", in: arguments)
            .map { URL(fileURLWithPath: $0, relativeTo: workspaceRoot).standardizedFileURL }
            ?? workspaceRoot.appendingPathComponent("docs/assets/reader-fixture-snapshots")
        let width = CGFloat(Int(argumentValue("--width", in: arguments) ?? "760") ?? 760)
        let appearanceValue = argumentValue("--appearance", in: arguments) ?? SnapshotAppearance.light.rawValue
        guard let appearance = SnapshotAppearance(rawValue: appearanceValue) else {
            throw SnapshotError.invalidAppearance(appearanceValue)
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let fixtures = try FileManager.default.contentsOfDirectory(
            at: fixturesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !fixtures.isEmpty else {
            throw SnapshotError.noFixtures(fixturesDirectory.path)
        }

        let parser = MarkdownParser()
        var metrics: [FixtureMetric] = []

        for fixture in fixtures {
            let source = try String(contentsOf: fixture, encoding: .utf8)
            let document = parser.parse(source, fileURL: fixture)
            let rendered = try renderSnapshot(
                attributedText: document.renderModel.attributedText,
                width: width,
                appearance: appearance
            )
            let outputName = fixture.deletingPathExtension().lastPathComponent + ".png"
            let outputURL = outputDirectory.appendingPathComponent(outputName)
            try rendered.pngData.write(to: outputURL)

            metrics.append(
                FixtureMetric(
                    appearance: appearance.rawValue,
                    file: fixture.lastPathComponent,
                    title: document.outline.flattened().first?.title ?? document.displayName,
                    renderedCharacters: document.renderModel.renderedPlainText.count,
                    sourceCharacters: document.rawMarkdown.count,
                    headingCount: document.outline.flattened().count,
                    blockCount: document.renderModel.sourceMap.blocks.count,
                    blockKinds: blockKindCounts(in: document),
                    snapshotWidth: Int(rendered.size.width),
                    snapshotHeight: Int(rendered.size.height),
                    outputImage: outputName
                )
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metrics)
        try data.write(to: outputDirectory.appendingPathComponent("metrics.json"))

        print("Rendered \(metrics.count) \(appearance.rawValue) reader fixture snapshots")
        print("Output: \(outputDirectory.path)")
    }

    @MainActor
    private static func renderSnapshot(
        attributedText: NSAttributedString,
        width: CGFloat,
        appearance: SnapshotAppearance
    ) throws -> (pngData: Data, size: NSSize) {
        let inset = NSSize(width: 48, height: 34)
        let initialHeight: CGFloat = 800
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let articleWidth = min(max(width - inset.width * 2, 360), 760)
        let tableContentWidth = MarkdownReaderLayoutMetrics.maximumTableContentWidth(in: attributedText)
        let containerWidth = max(articleWidth, min(tableContentWidth, 880))
        let documentWidth = max(width, containerWidth + inset.width * 2)
        let textContainer = NSTextContainer(size: NSSize(
            width: containerWidth,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = ReaderTextView(
            frame: NSRect(x: 0, y: 0, width: documentWidth, height: initialHeight),
            textContainer: textContainer
        )
        textView.appearance = appearance.nsAppearance
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = inset
        textStorage.setAttributedString(attributedText)

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let height = ceil(max(240, usedRect.height + inset.height * 2 + 28))
        textView.frame = NSRect(x: 0, y: 0, width: documentWidth, height: height)

        guard let bitmap = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else {
            throw SnapshotError.bitmapUnavailable
        }

        bitmap.size = textView.bounds.size
        appearance.nsAppearance.performAsCurrentDrawingAppearance {
            textView.cacheDisplay(in: textView.bounds, to: bitmap)
        }

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError.pngEncodingFailed
        }

        return (pngData, textView.bounds.size)
    }

    private static func blockKindCounts(in document: MarkdownDocument) -> [String: Int] {
        document.renderModel.sourceMap.blocks.reduce(into: [:]) { counts, block in
            counts[block.kind.rawValue, default: 0] += 1
        }
    }

    private static func argumentValue(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }

        return arguments[index + 1]
    }

    private static func findWorkspaceRoot() throws -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .standardizedFileURL

        while true {
            let fixtures = current.appendingPathComponent("samples/markdown/reader-fixtures")
            if FileManager.default.fileExists(atPath: fixtures.path) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                throw SnapshotError.workspaceRootNotFound
            }
            current = parent
        }
    }
}

enum SnapshotAppearance: String {
    case light
    case dark

    var nsAppearance: NSAppearance {
        switch self {
        case .light:
            return NSAppearance(named: .aqua)!
        case .dark:
            return NSAppearance(named: .darkAqua)!
        }
    }
}

enum SnapshotError: Error, LocalizedError {
    case workspaceRootNotFound
    case noFixtures(String)
    case invalidAppearance(String)
    case layoutUnavailable
    case bitmapUnavailable
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .workspaceRootNotFound:
            return "Could not find a workspace root containing samples/markdown/reader-fixtures."
        case let .noFixtures(path):
            return "No Markdown fixtures found at \(path)."
        case let .invalidAppearance(value):
            return "Unsupported appearance '\(value)'. Use 'light' or 'dark'."
        case .layoutUnavailable:
            return "Could not create TextKit layout objects."
        case .bitmapUnavailable:
            return "Could not create a bitmap snapshot."
        case .pngEncodingFailed:
            return "Could not encode the snapshot as PNG."
        }
    }
}
