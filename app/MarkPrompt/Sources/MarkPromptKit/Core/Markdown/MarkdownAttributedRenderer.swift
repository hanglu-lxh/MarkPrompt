import AppKit
import Foundation

public struct MarkdownAttributedRenderer {
    private static let taskMarkerMetadataPrefix = "\u{0014}task:"
    private static let taskMarkerMetadataSuffix = "\u{0015}"
    private static let completedTaskLooseContinuationPrefix = "\u{0018}"
    private static let completedTaskContinuationPrefix = "\u{0019}"
    private static let listLooseContinuationPrefix = "\u{001C}"
    private static let listContinuationPrefix = "\u{001D}"
    private static let definitionTermPrefix = "\u{001E}"
    private static let definitionTextPrefix = "\u{001F}"
    private static let blockquoteNestingPrefix = "\u{001A}"
    private static let inlineFootnoteIdentifierPrefix = "\u{001B}inline-footnote:"
    private static let taskMarkerTooltip = "点击或按 Space/⌘L 切换完成/待办；⌘⌥J/K 跳转任务；右键可标记待办/完成/取消/进行中/重要。"

    private struct LinkReferenceDefinition {
        var destination: String
        var title: String?
    }

    private struct ObsidianEmbedImageSize {
        var width: CGFloat?
        var height: CGFloat?
    }

    private enum ObsidianFileEmbedKind {
        case pdf
        case audio
        case video

        var label: String {
            switch self {
            case .pdf:
                return "PDF"
            case .audio:
                return "Audio"
            case .video:
                return "Video"
            }
        }
    }

    private enum CalloutFoldState: String {
        case expanded
        case collapsed

        init?(marker: String?) {
            switch marker {
            case "+":
                self = .expanded
            case "-":
                self = .collapsed
            default:
                return nil
            }
        }

        init?(disclosureGlyph: Character?) {
            switch disclosureGlyph {
            case "▾":
                self = .expanded
            case "▸":
                self = .collapsed
            default:
                return nil
            }
        }

        var disclosureGlyph: String {
            switch self {
            case .expanded:
                return "▾"
            case .collapsed:
                return "▸"
            }
        }

        var tooltip: String {
            switch self {
            case .expanded:
                return "Default expanded in Obsidian"
            case .collapsed:
                return "Default collapsed in Obsidian"
            }
        }
    }

    private enum CalloutKind: String {
        case abstract
        case bug
        case caution
        case danger
        case example
        case failure
        case info
        case important
        case note
        case question
        case quote
        case success
        case tip
        case todo
        case warning

        var title: String {
            switch self {
            case .abstract:
                return "Abstract"
            case .bug:
                return "Bug"
            case .caution:
                return "Caution"
            case .danger:
                return "Danger"
            case .example:
                return "Example"
            case .failure:
                return "Failure"
            case .info:
                return "Info"
            case .important:
                return "Important"
            case .note:
                return "Note"
            case .question:
                return "Question"
            case .quote:
                return "Quote"
            case .success:
                return "Success"
            case .tip:
                return "Tip"
            case .todo:
                return "Todo"
            case .warning:
                return "Warning"
            }
        }

        init?(calloutName: String) {
            switch calloutName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "abstract", "summary", "tldr":
                self = .abstract
            case "bug":
                self = .bug
            case "caution":
                self = .caution
            case "danger", "error":
                self = .danger
            case "example":
                self = .example
            case "fail", "failure", "missing":
                self = .failure
            case "info":
                self = .info
            case "important":
                self = .important
            case "note":
                self = .note
            case "faq", "help", "question":
                self = .question
            case "cite", "quote":
                self = .quote
            case "check", "done", "success":
                self = .success
            case "hint", "tip":
                self = .tip
            case "todo":
                self = .todo
            case "attention", "warning":
                self = .warning
            default:
                return nil
            }
        }
    }

    public init() {}

    public func render(
        source: String,
        outline: [DocumentHeading],
        baseURL: URL? = nil
    ) -> MarkdownRenderModel {
        let attributed = NSMutableAttributedString()
        var blocks: [MarkdownRenderBlock] = []
        var headingRenderRanges: [UUID: RenderedTextRange] = [:]
        let lines = MarkdownLineScanner.lines(in: source)
        let footnoteOrdinals = footnoteReferenceOrdinals(in: lines)
        let abbreviations = abbreviationDefinitions(in: lines)
        let linkReferences = linkReferenceDefinitions(in: lines)
        let footnoteDefinitions = footnoteDefinitionTooltips(
            in: lines,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences
        )
        let headingBySourceStart = Dictionary(
            uniqueKeysWithValues: outline.flattened().map { ($0.sourceRange.lowerBound, $0) }
        )

        var index = 0
        if let frontmatter = collectFrontmatter(from: lines) {
            appendBlock(
                frontmatter.text,
                kind: .metadata,
                sourceRange: frontmatter.sourceRange,
                headingID: nil,
                attributes: metadataAttributes(),
                to: attributed,
                blocks: &blocks,
                headingRenderRanges: &headingRenderRanges
            )
            index = frontmatter.nextIndex
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if isStandaloneObsidianBlockID(trimmed) {
                index += 1
                continue
            }

            if let nextIndex = collectObsidianCommentBlock(from: lines, startingAt: index) {
                index = nextIndex
                continue
            }

            if parseAbbreviationDefinition(trimmed) != nil {
                index += 1
                continue
            }

            if parseLinkReferenceDefinition(trimmed) != nil {
                index += 1
                continue
            }

            if OutlineBuilder.isFence(trimmed) {
                let result = collectCodeBlock(from: lines, startingAt: index)
                appendBlock(
                    codeBlockDisplayText(code: result.text, language: result.language),
                    kind: .codeBlock,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: codeAttributes(),
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if isIndentedCodeBlockStart(lines, at: index) {
                let result = collectIndentedCodeBlock(from: lines, startingAt: index)
                appendBlock(
                    result.text,
                    kind: .codeBlock,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: codeAttributes(),
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if trimmed == "$$" {
                let result = collectMathBlock(from: lines, startingAt: index)
                appendBlock(
                    mathBlockDisplayText(result.text),
                    kind: .mathBlock,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: mathAttributes(),
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if let parsed = OutlineBuilder.parseSetextHeading(lines, at: index),
               let heading = headingBySourceStart[line.sourceRange.lowerBound] {
                appendBlock(
                    parsed.title,
                    kind: .heading,
                    sourceRange: parsed.sourceRange,
                    headingID: heading.id,
                    attributes: headingAttributes(level: parsed.level),
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = parsed.nextIndex
                continue
            }

            if let heading = headingBySourceStart[line.sourceRange.lowerBound],
               let parsed = OutlineBuilder.parseHeadingLine(line.text) {
                appendBlock(
                    parsed.title,
                    kind: .heading,
                    sourceRange: line.sourceRange,
                    headingID: heading.id,
                    attributes: headingAttributes(level: parsed.level),
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index += 1
                continue
            }

            if let image = parseImageLine(trimmed, linkReferences: linkReferences) {
                let localPreviewURL = localImageURL(for: image.url, baseURL: baseURL)
                appendBlock(
                    imagePlaceholder(altText: image.altText, url: image.url),
                    kind: .image,
                    sourceRange: line.sourceRange,
                    headingID: nil,
                    attributes: imageAttributes(),
                    localImageURL: localPreviewURL,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index += 1
                continue
            }

            if parseFootnoteDefinition(trimmed) != nil {
                let result = collectFootnoteDefinition(
                    from: lines,
                    startingAt: index,
                    footnoteOrdinals: footnoteOrdinals
                )
                appendBlock(
                    result.text,
                    kind: .footnote,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: footnoteAttributes(),
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if let htmlTable = collectHTMLTable(from: lines, startingAt: index) {
                appendBlock(
                    htmlTable.text,
                    kind: .table,
                    sourceRange: htmlTable.sourceRange,
                    headingID: nil,
                    attributes: tableAttributes(),
                    tableColumnAlignments: [],
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = htmlTable.nextIndex
                continue
            }

            if isHTMLBlockStart(trimmed) {
                let result = collectHTMLBlock(from: lines, startingAt: index)
                appendBlock(
                    result.text,
                    kind: .htmlBlock,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: htmlBlockAttributes(),
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if isTableStart(lines, at: index) {
                let result = collectTable(from: lines, startingAt: index)
                appendBlock(
                    result.text,
                    kind: .table,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: tableAttributes(),
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    tableColumnAlignments: result.alignments,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if isDefinitionListStart(lines, at: index) {
                let result = collectDefinitionList(from: lines, startingAt: index)
                appendBlock(
                    result.text,
                    kind: .definitionList,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: bodyAttributes(),
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if parseListItem(line.text) != nil {
                let result = collectList(from: lines, startingAt: index)
                appendBlock(
                    result.text,
                    kind: result.kind,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: bodyAttributes(),
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if trimmed.hasPrefix(">") {
                let result = collectBlockquote(from: lines, startingAt: index)
                appendBlock(
                    result.text,
                    kind: .blockquote,
                    sourceRange: result.sourceRange,
                    headingID: nil,
                    attributes: quoteAttributes(
                        calloutKind: result.calloutKind,
                        calloutFoldState: result.calloutFoldState
                    ),
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL,
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index = result.nextIndex
                continue
            }

            if trimmed == "---" || trimmed == "***" {
                appendBlock(
                    " ",
                    kind: .thematicBreak,
                    sourceRange: line.sourceRange,
                    headingID: nil,
                    attributes: thematicBreakAttributes(),
                    to: attributed,
                    blocks: &blocks,
                    headingRenderRanges: &headingRenderRanges
                )
                index += 1
                continue
            }

            let result = collectParagraph(from: lines, startingAt: index)
            appendBlock(
                result.text,
                kind: .paragraph,
                sourceRange: result.sourceRange,
                headingID: nil,
                attributes: bodyAttributes(),
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL,
                to: attributed,
                blocks: &blocks,
                headingRenderRanges: &headingRenderRanges
            )
            index = result.nextIndex
        }

        if attributed.length == 0 {
            attributed.append(NSAttributedString(string: "", attributes: bodyAttributes()))
        }

        return MarkdownRenderModel(
            attributedText: attributed,
            renderedPlainText: attributed.string,
            sourceMap: MarkdownSourceMap(blocks: blocks, headingRenderRanges: headingRenderRanges)
        )
    }

    private func appendBlock(
        _ text: String,
        kind: MarkdownRenderBlockKind,
        sourceRange: SourceTextRange,
        headingID: UUID?,
        attributes: [NSAttributedString.Key: Any],
        footnoteOrdinals: [String: Int] = [:],
        footnoteDefinitions: [String: String] = [:],
        tableColumnAlignments: [NSTextAlignment]? = nil,
        localImageURL: URL? = nil,
        abbreviations: [String: String] = [:],
        linkReferences: [String: LinkReferenceDefinition] = [:],
        baseURL: URL? = nil,
        to attributed: NSMutableAttributedString,
        blocks: inout [MarkdownRenderBlock],
        headingRenderRanges: inout [UUID: RenderedTextRange]
    ) {
        if attributed.length > 0 {
            attributed.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
        }

        let start = attributed.length
        attributed.append(attributedText(
            for: text,
            kind: kind,
            attributes: attributes,
            footnoteOrdinals: footnoteOrdinals,
            footnoteDefinitions: footnoteDefinitions,
            tableColumnAlignments: tableColumnAlignments,
            localImageURL: localImageURL,
            abbreviations: abbreviations,
            linkReferences: linkReferences,
            baseURL: baseURL
        ))
        let renderedRange = RenderedTextRange(location: start, length: attributed.length - start)
        attributed.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))

        blocks.append(
            MarkdownRenderBlock(
                kind: kind,
                sourceRange: sourceRange,
                renderedRange: renderedRange,
                headingID: headingID
            )
        )

        if let headingID {
            headingRenderRanges[headingID] = renderedRange
        }
    }

    private func collectCodeBlock(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, language: String?, sourceRange: SourceTextRange, nextIndex: Int) {
        let opening = lines[startIndex]
        var codeLines: [String] = []
        var index = startIndex + 1
        var closing = opening

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            closing = line

            if OutlineBuilder.isFence(trimmed) {
                index += 1
                break
            }

            codeLines.append(line.text)
            index += 1
        }

        return (
            codeLines.joined(separator: "\n"),
            fenceLanguage(from: opening.text),
            SourceTextRange(lowerBound: opening.sourceRange.lowerBound, upperBound: closing.sourceRange.upperBound),
            index
        )
    }

    private func fenceLanguage(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let marker: String
        if trimmed.hasPrefix("```") {
            marker = "```"
        } else if trimmed.hasPrefix("~~~") {
            marker = "~~~"
        } else {
            return nil
        }

        let language = trimmed
            .dropFirst(marker.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)

        return language?.isEmpty == false ? language : nil
    }

    private func isIndentedCodeBlockStart(_ lines: [MarkdownSourceLine], at index: Int) -> Bool {
        guard lines.indices.contains(index) else {
            return false
        }

        let line = lines[index]
        return line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && isIndentedCodeLine(line.text)
    }

    private func collectIndentedCodeBlock(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int) {
        var codeLines: [String] = []
        var pendingBlankLines: [MarkdownSourceLine] = []
        var index = startIndex
        var lastCodeLine = lines[startIndex]

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                pendingBlankLines.append(line)
                index += 1
                continue
            }

            guard isIndentedCodeLine(line.text) else {
                break
            }

            for blankLine in pendingBlankLines {
                codeLines.append("")
                lastCodeLine = blankLine
            }
            pendingBlankLines.removeAll()

            codeLines.append(removingIndentedCodePrefix(from: line.text))
            lastCodeLine = line
            index += 1
        }

        return (
            codeLines.joined(separator: "\n"),
            SourceTextRange(
                lowerBound: lines[startIndex].sourceRange.lowerBound,
                upperBound: lastCodeLine.sourceRange.upperBound
            ),
            index
        )
    }

    private func isIndentedCodeLine(_ line: String) -> Bool {
        leadingWhitespaceWidth(in: line) >= 4
    }

    private func removingIndentedCodePrefix(from line: String) -> String {
        var remainingColumns = 4
        var index = line.startIndex

        while index < line.endIndex, remainingColumns > 0 {
            let character = line[index]
            if character == " " {
                remainingColumns -= 1
                index = line.index(after: index)
            } else if character == "\t" {
                remainingColumns = 0
                index = line.index(after: index)
            } else {
                break
            }
        }

        return String(line[index...])
    }

    private func codeBlockDisplayText(code: String, language: String?) -> String {
        guard let language, !language.isEmpty else {
            return code
        }

        return "\(codeBlockLanguageTitle(language))\n\(code)"
    }

    private func codeBlockLanguageTitle(_ language: String) -> String {
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let knownTitles = [
            "bash": "Bash",
            "css": "CSS",
            "diff": "Diff",
            "html": "HTML",
            "javascript": "JavaScript",
            "js": "JavaScript",
            "json": "JSON",
            "markdown": "Markdown",
            "md": "Markdown",
            "mermaid": "Mermaid",
            "python": "Python",
            "py": "Python",
            "patch": "Diff",
            "shell": "Shell",
            "sh": "Shell",
            "swift": "Swift",
            "typescript": "TypeScript",
            "ts": "TypeScript",
            "yaml": "YAML",
            "yml": "YAML"
        ]

        if let knownTitle = knownTitles[normalized] {
            return knownTitle
        }

        return normalized.isEmpty
            ? "Code"
            : normalized.prefix(1).uppercased() + normalized.dropFirst()
    }

    private func collectMathBlock(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int) {
        let opening = lines[startIndex]
        var mathLines: [String] = []
        var index = startIndex + 1
        var closing = opening

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            closing = line

            if trimmed == "$$" {
                index += 1
                break
            }

            mathLines.append(line.text)
            index += 1
        }

        return (
            mathLines.joined(separator: "\n"),
            SourceTextRange(lowerBound: opening.sourceRange.lowerBound, upperBound: closing.sourceRange.upperBound),
            index
        )
    }

    private func mathBlockDisplayText(_ math: String) -> String {
        let trimmed = math.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Formula" : "Formula\n\(trimmed)"
    }

    private func collectFrontmatter(
        from lines: [MarkdownSourceLine]
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int)? {
        guard lines.count >= 2,
              lines[0].text.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        else {
            return nil
        }

        var index = 1
        var metadataLines: [String] = []
        var closingLine: MarkdownSourceLine?

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" {
                closingLine = line
                index += 1
                break
            }

            metadataLines.append(line.text)
            index += 1
        }

        guard let closingLine else {
            return nil
        }

        return (
            frontmatterSummary(from: metadataLines),
            SourceTextRange(lowerBound: lines[0].sourceRange.lowerBound, upperBound: closingLine.sourceRange.upperBound),
            index
        )
    }

    private func frontmatterSummary(from lines: [String]) -> String {
        var entries: [String] = []
        var index = 0

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                index += 1
                continue
            }

            if trimmed.hasSuffix(":") {
                let key = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                var values: [String] = []
                var valueIndex = index + 1
                while valueIndex < lines.count {
                    let valueLine = lines[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard valueLine.hasPrefix("- ") else {
                        break
                    }
                    values.append(String(valueLine.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                    valueIndex += 1
                }

                if !key.isEmpty, !values.isEmpty {
                    entries.append("\(frontmatterDisplayKey(key)): \(values.joined(separator: "  "))")
                    index = valueIndex
                    continue
                }
            }

            if let separator = trimmed.firstIndex(of: ":") {
                let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty, !value.isEmpty {
                    entries.append("\(frontmatterDisplayKey(String(key))): \(frontmatterDisplayValue(String(value)))")
                }
            }

            index += 1
        }

        guard !entries.isEmpty else {
            return "Properties"
        }

        return "Properties\n\(entries.joined(separator: "\n"))"
    }

    private func frontmatterDisplayKey(_ key: String) -> String {
        let words = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: "-_ "))
            .filter { !$0.isEmpty }
            .map { word -> String in
                let lowercased = word.lowercased()
                guard let first = lowercased.first else {
                    return ""
                }
                return first.uppercased() + lowercased.dropFirst()
            }
            .filter { !$0.isEmpty }

        return words.isEmpty ? key : words.joined(separator: " ")
    }

    private func frontmatterDisplayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return trimmed
        }

        let first = trimmed.first
        let last = trimmed.last
        if first == last,
           first == "\"" || first == "'" {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private func collectTable(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, alignments: [NSTextAlignment], sourceRange: SourceTextRange, nextIndex: Int) {
        var rows: [String] = []
        var alignments: [NSTextAlignment] = []
        var index = startIndex
        var lastLine = lines[startIndex]

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard isTableRow(trimmed) else {
                break
            }

            if isTableSeparator(trimmed) {
                alignments = tableAlignments(from: trimmed)
            } else {
                let cells = tableCells(from: trimmed)
                rows.append(cells.joined(separator: "\t"))
            }

            lastLine = line
            index += 1
        }

        return (
            rows.joined(separator: "\n"),
            alignments,
            SourceTextRange(lowerBound: lines[startIndex].sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func collectDefinitionList(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int) {
        var renderedLines: [String] = []
        var index = startIndex
        var lastLine = lines[startIndex]

        while index < lines.count {
            let termLine = lines[index]
            let term = termLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isDefinitionTermLine(term, lines: lines, at: index),
                  index + 1 < lines.count,
                  parseDefinitionLine(lines[index + 1].text.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
            else {
                break
            }

            renderedLines.append(Self.definitionTermPrefix + term)
            lastLine = termLine
            index += 1

            while index < lines.count {
                let line = lines[index]
                let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let definition = parseDefinitionLine(trimmed) else {
                    break
                }

                renderedLines.append(Self.definitionTextPrefix + definition)
                lastLine = line
                index += 1
            }

            guard index < lines.count else {
                break
            }

            let nextTrimmed = lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if nextTrimmed.isEmpty {
                break
            }
        }

        return (
            renderedLines.joined(separator: "\n"),
            SourceTextRange(lowerBound: lines[startIndex].sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func collectList(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, kind: MarkdownRenderBlockKind, sourceRange: SourceTextRange, nextIndex: Int) {
        var renderedLines: [String] = []
        var index = startIndex
        var lastLine = lines[startIndex]
        var kind: MarkdownRenderBlockKind = .unorderedList

        while index < lines.count {
            let line = lines[index]
            guard let item = parseListItem(line.text) else {
                break
            }

            if item.isTask {
                kind = .taskList
            } else {
                kind = item.isOrdered ? .orderedList : .unorderedList
            }

            let indentation = String(repeating: "  ", count: item.indentLevel)
            let marker: String
            if item.isTask {
                marker = item.taskGlyph
            } else {
                marker = item.isOrdered ? item.marker : "•"
            }
            let isCompletedTask = item.isTask && marker == "☑"
            let continuationPrefix = isCompletedTask ? Self.completedTaskContinuationPrefix : Self.listContinuationPrefix
            let looseContinuationPrefix = isCompletedTask ? Self.completedTaskLooseContinuationPrefix : Self.listLooseContinuationPrefix
            let taskMetadataPrefix = item.isTask
                ? taskMarkerSourceMetadata(in: line).map(taskMarkerMetadataPrefix(for:)) ?? ""
                : ""

            renderedLines.append("\(indentation)\(taskMetadataPrefix)\(marker) \(item.text)")
            lastLine = line
            index += 1

            while index < lines.count,
                  let continuation = listContinuationLine(
                    in: lines,
                    at: index,
                    itemIndentLevel: item.indentLevel
                  ) {
                renderedLines.append("\(indentation)\(continuationPrefix)\(continuation)")
                lastLine = lines[index]
                index += 1
            }

            while index + 1 < lines.count,
                  lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let continuation = listContinuationLine(
                    in: lines,
                    at: index + 1,
                    itemIndentLevel: item.indentLevel
                  ) {
                renderedLines.append("\(indentation)\(looseContinuationPrefix)\(continuation)")
                lastLine = lines[index + 1]
                index += 2

                while index < lines.count,
                      let continuation = listContinuationLine(
                        in: lines,
                        at: index,
                        itemIndentLevel: item.indentLevel
                      ) {
                    renderedLines.append("\(indentation)\(continuationPrefix)\(continuation)")
                    lastLine = lines[index]
                    index += 1
                }
            }
        }

        return (
            renderedLines.joined(separator: "\n"),
            kind,
            SourceTextRange(lowerBound: lines[startIndex].sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func collectBlockquote(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (
        text: String,
        calloutKind: CalloutKind?,
        calloutFoldState: CalloutFoldState?,
        sourceRange: SourceTextRange,
        nextIndex: Int
    ) {
        var renderedLines: [String] = []
        var index = startIndex
        var lastLine = lines[startIndex]
        var calloutKind: CalloutKind?
        var calloutFoldState: CalloutFoldState?
        var currentLevel = 1

        while index < lines.count {
            let line = lines[index]
            let quoteLine = parseBlockquoteLine(line.text)
            let lazyContinuation = quoteLine == nil && !renderedLines.isEmpty
                ? blockquoteLazyContinuationLine(in: lines, at: index)
                : nil
            guard quoteLine != nil || lazyContinuation != nil else {
                break
            }

            let quoteText: String
            let quoteLevel: Int
            if let quoteLine {
                quoteText = quoteLine.text
                quoteLevel = quoteLine.level
                currentLevel = quoteLevel
            } else {
                quoteText = lazyContinuation ?? ""
                quoteLevel = currentLevel
            }

            if renderedLines.isEmpty,
               let callout = parseCalloutMarker(quoteText) {
                calloutKind = callout.kind
                calloutFoldState = callout.foldState
                renderedLines.append(blockquoteDisplayLine(
                    callout.title,
                    level: quoteLevel
                ))
            } else if let nestedCallout = parseCalloutMarker(quoteText) {
                renderedLines.append(blockquoteDisplayLine(
                    nestedCalloutDisplayTitle(nestedCallout),
                    level: quoteLevel
                ))
            } else {
                renderedLines.append(blockquoteDisplayLine(quoteText, level: quoteLevel))
            }
            lastLine = line
            index += 1
        }

        return (
            renderedLines.joined(separator: "\n"),
            calloutKind,
            calloutFoldState,
            SourceTextRange(lowerBound: lines[startIndex].sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func nestedCalloutDisplayTitle(
        _ callout: (kind: CalloutKind, title: String, foldState: CalloutFoldState?)
    ) -> String {
        guard let foldState = callout.foldState else {
            return callout.title
        }
        return "\(foldState.disclosureGlyph) \(callout.title)"
    }

    private func parseBlockquoteLine(_ line: String) -> (level: Int, text: String)? {
        var index = line.startIndex
        while index < line.endIndex, line[index].isWhitespace {
            index = line.index(after: index)
        }

        guard index < line.endIndex, line[index] == ">" else {
            return nil
        }

        var level = 0
        while index < line.endIndex, line[index] == ">" {
            level += 1
            index = line.index(after: index)

            if index < line.endIndex, line[index] == " " || line[index] == "\t" {
                index = line.index(after: index)
            }
        }

        return (
            max(1, level),
            String(line[index...]).trimmingCharacters(in: .whitespaces)
        )
    }

    private func blockquoteDisplayLine(_ text: String, level: Int) -> String {
        String(repeating: Self.blockquoteNestingPrefix, count: max(0, level - 1)) + text
    }

    private func blockquoteLazyContinuationLine(
        in lines: [MarkdownSourceLine],
        at index: Int
    ) -> String? {
        let line = lines[index]
        let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              parseBlockquoteLine(line.text) == nil,
              !OutlineBuilder.isFence(trimmed),
              OutlineBuilder.parseHeadingLine(line.text) == nil,
              OutlineBuilder.parseSetextHeading(lines, at: index) == nil,
              !isTableStart(lines, at: index),
              !isDefinitionListStart(lines, at: index),
              parseImageLine(trimmed, linkReferences: [:]) == nil,
              parseFootnoteDefinition(trimmed) == nil,
              parseAbbreviationDefinition(trimmed) == nil,
              parseLinkReferenceDefinition(trimmed) == nil,
              !isObsidianCommentBlockStart(trimmed),
              !isHTMLBlockStart(trimmed),
              parseListItem(line.text) == nil,
              trimmed != "$$",
              trimmed != "---",
              trimmed != "***"
        else {
            return nil
        }

        return line.text.trimmingCharacters(in: .whitespaces)
    }

    private func parseCalloutMarker(_ text: String) -> (kind: CalloutKind, title: String, foldState: CalloutFoldState?)? {
        let nsText = text as NSString
        let pattern = #"^\[!([A-Za-z][A-Za-z0-9_-]*)\]([+-])?\s*(.*)$"#
        guard let match = (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) else {
            return nil
        }

        let rawKind = nsText.substring(with: match.range(at: 1))
        let knownKind = CalloutKind(calloutName: rawKind)
        let kind = knownKind ?? .note
        let foldMarker = match.range(at: 2).location == NSNotFound ? nil : nsText.substring(with: match.range(at: 2))
        let foldState = CalloutFoldState(marker: foldMarker)

        let customTitle = match.range(at: 3).location == NSNotFound
            ? ""
            : nsText.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = knownKind?.title ?? fallbackCalloutTitle(from: rawKind)
        return (kind, customTitle.isEmpty ? defaultTitle : customTitle, foldState)
    }

    private func fallbackCalloutTitle(from rawKind: String) -> String {
        let cleaned = rawKind.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned
            .components(separatedBy: CharacterSet(charactersIn: "-_"))
            .filter { !$0.isEmpty }
            .map { word -> String in
                let lowercased = word.lowercased()
                guard let first = lowercased.first else {
                    return ""
                }
                return first.uppercased() + lowercased.dropFirst()
            }
            .filter { !$0.isEmpty }

        return words.isEmpty ? CalloutKind.note.title : words.joined(separator: " ")
    }

    private func collectParagraph(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int) {
        var paragraphLines: [(text: String, hasHardBreak: Bool)] = []
        var index = startIndex
        var lastLine = lines[startIndex]

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty,
                  !OutlineBuilder.isFence(trimmed),
                  OutlineBuilder.parseHeadingLine(line.text) == nil,
                  OutlineBuilder.parseSetextHeading(lines, at: index) == nil,
                  !isTableStart(lines, at: index),
                  !isDefinitionListStart(lines, at: index),
                  parseImageLine(trimmed, linkReferences: [:]) == nil,
                  parseFootnoteDefinition(trimmed) == nil,
                  parseAbbreviationDefinition(trimmed) == nil,
                  parseLinkReferenceDefinition(trimmed) == nil,
                  !isObsidianCommentBlockStart(trimmed),
                  !isHTMLBlockStart(trimmed),
                  parseListItem(line.text) == nil,
                  !trimmed.hasPrefix(">"),
                  trimmed != "$$",
                  trimmed != "---",
                  trimmed != "***"
            else {
                break
            }

            paragraphLines.append(paragraphLineDisplay(from: line.text))
            lastLine = line
            index += 1
        }

        return (
            joinedParagraphLines(paragraphLines),
            SourceTextRange(lowerBound: lines[startIndex].sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func collectObsidianCommentBlock(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> Int? {
        let opening = lines[startIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isObsidianCommentBlockStart(opening) else {
            return nil
        }

        if let sameLineClosing = obsidianCommentClosingRange(in: opening, afterOpeningAt: opening.startIndex) {
            let trailingText = opening[sameLineClosing.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return trailingText.isEmpty ? (startIndex + 1) : nil
        }

        var index = startIndex + 1
        while index < lines.count {
            let trimmed = lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: "%%") != nil {
                return index + 1
            }
            index += 1
        }

        return (lines.count)
    }

    private func isObsidianCommentBlockStart(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("%%")
    }

    private func obsidianCommentClosingRange(
        in trimmedLine: String,
        afterOpeningAt openingIndex: String.Index
    ) -> Range<String.Index>? {
        let searchStart = trimmedLine.index(openingIndex, offsetBy: 2, limitedBy: trimmedLine.endIndex) ?? trimmedLine.endIndex
        return trimmedLine.range(of: "%%", range: searchStart..<trimmedLine.endIndex)
    }

    private func paragraphLineDisplay(from line: String) -> (text: String, hasHardBreak: Bool) {
        let hardBreakBySpaces = line.hasSuffix("  ")
        let trailingBackslashCount = line.reversed().prefix { $0 == "\\" }.count
        let hardBreakByBackslash = trailingBackslashCount % 2 == 1

        var display = line
        if hardBreakByBackslash {
            display.removeLast()
        }

        display = display.trimmingCharacters(in: .whitespacesAndNewlines)
        return (display, hardBreakBySpaces || hardBreakByBackslash)
    }

    private func joinedParagraphLines(_ lines: [(text: String, hasHardBreak: Bool)]) -> String {
        var result = ""

        for index in lines.indices {
            if index > lines.startIndex {
                let previousIndex = lines.index(before: index)
                result += lines[previousIndex].hasHardBreak ? "\n" : " "
            }
            result += lines[index].text
        }

        return result
    }

    private func parseListItem(_ line: String) -> (isOrdered: Bool, number: Int?, marker: String, isTask: Bool, taskGlyph: String, indentLevel: Int, text: String)? {
        let indentWidth = leadingWhitespaceWidth(in: line)
        let indentLevel = min(4, indentWidth / 2)
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            let text = String(trimmed.dropFirst(2))
            if let task = parseTaskMarker(in: text) {
                return (false, nil, "", true, task.glyph, indentLevel, task.text)
            }

            return (false, nil, "", false, "", indentLevel, text)
        }

        guard let match = trimmed.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) else {
            return nil
        }

        let marker = String(trimmed[match]).trimmingCharacters(in: .whitespaces)
        let number = Int(marker.dropLast())
        let text = String(trimmed[match.upperBound...])
        return (true, number, marker, false, "", indentLevel, text)
    }

    private func listContinuationLine(
        in lines: [MarkdownSourceLine],
        at index: Int,
        itemIndentLevel: Int
    ) -> String? {
        let line = lines[index]
        let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              parseListItem(line.text) == nil,
              leadingWhitespaceWidth(in: line.text) >= itemIndentLevel * 2 + 2,
              !OutlineBuilder.isFence(trimmed),
              OutlineBuilder.parseHeadingLine(line.text) == nil,
              OutlineBuilder.parseSetextHeading(lines, at: index) == nil,
              !isTableStart(lines, at: index),
              !isDefinitionListStart(lines, at: index),
              parseImageLine(trimmed, linkReferences: [:]) == nil,
              parseFootnoteDefinition(trimmed) == nil,
              parseAbbreviationDefinition(trimmed) == nil,
              parseLinkReferenceDefinition(trimmed) == nil,
              !isObsidianCommentBlockStart(trimmed),
              !isHTMLBlockStart(trimmed),
              !trimmed.hasPrefix(">"),
              trimmed != "$$",
              trimmed != "---",
              trimmed != "***"
        else {
            return nil
        }

        return trimmed
    }

    private func leadingWhitespaceWidth(in line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }
            .reduce(0) { width, character in
                width + (character == "\t" ? 4 : 1)
            }
    }

    private func parseAbbreviationDefinition(_ trimmedLine: String) -> (term: String, definition: String)? {
        let nsLine = trimmedLine as NSString
        let pattern = #"^\*\[([^\]]+)\]:\s*(.+)$"#
        guard let match = (try? NSRegularExpression(pattern: pattern))?.firstMatch(
            in: trimmedLine,
            range: NSRange(location: 0, length: nsLine.length)
        ) else {
            return nil
        }

        let term = nsLine.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let definition = nsLine.substring(with: match.range(at: 2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              !definition.isEmpty
        else {
            return nil
        }

        return (term, definition)
    }

    private func abbreviationDefinitions(in lines: [MarkdownSourceLine]) -> [String: String] {
        lines.reduce(into: [:]) { definitions, line in
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let abbreviation = parseAbbreviationDefinition(trimmed) else {
                return
            }
            definitions[abbreviation.term] = abbreviation.definition
        }
    }

    private func parseLinkReferenceDefinition(_ trimmedLine: String) -> (label: String, definition: LinkReferenceDefinition)? {
        let nsLine = trimmedLine as NSString
        let pattern = #"^\[([^\]\^][^\]]*)\]:\s*(<[^>]+>|\S+)(?:\s+(.+))?$"#
        guard let match = (try? NSRegularExpression(pattern: pattern))?.firstMatch(
            in: trimmedLine,
            range: NSRange(location: 0, length: nsLine.length)
        ) else {
            return nil
        }

        let label = nsLine.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = imageDestination(from: nsLine.substring(with: match.range(at: 2)))
        let title: String?
        if match.range(at: 3).location == NSNotFound {
            title = nil
        } else {
            title = linkReferenceTitle(from: nsLine.substring(with: match.range(at: 3)))
        }

        guard !label.isEmpty,
              !destination.isEmpty
        else {
            return nil
        }

        return (
            normalizedReferenceLabel(label),
            LinkReferenceDefinition(destination: destination, title: title)
        )
    }

    private func linkReferenceDefinitions(in lines: [MarkdownSourceLine]) -> [String: LinkReferenceDefinition] {
        lines.reduce(into: [:]) { definitions, line in
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let reference = parseLinkReferenceDefinition(trimmed) else {
                return
            }
            definitions[reference.label] = reference.definition
        }
    }

    private func linkReferenceTitle(from rawTitle: String) -> String? {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return nil
        }

        let first = trimmed.first
        let last = trimmed.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") || (first == "(" && last == ")") {
            return String(trimmed.dropFirst().dropLast())
        }
        return nil
    }

    private func normalizedReferenceLabel(_ label: String) -> String {
        label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()
    }

    private func parseTaskMarker(in text: String) -> (glyph: String, text: String)? {
        let nsText = text as NSString
        let pattern = #"^\[([^\]\n])\]\s+"#
        guard let match = (try? NSRegularExpression(pattern: pattern))?.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) else {
            return nil
        }

        let marker = nsText.substring(with: match.range(at: 1))
        let taskText = nsText.substring(from: match.range.location + match.range.length)
        return (taskGlyph(for: marker), taskText)
    }

    private struct TaskMarkerSourceMetadata {
        var sourceRange: SourceTextRange
        var markerCharacter: String
    }

    private func taskMarkerSourceMetadata(in line: MarkdownSourceLine) -> TaskMarkerSourceMetadata? {
        let nsLine = line.text as NSString
        let pattern = #"^\s*[-*+]\s+(\[([^\]\n])\])\s+"#
        guard let match = (try? NSRegularExpression(pattern: pattern))?.firstMatch(
            in: line.text,
            range: NSRange(location: 0, length: nsLine.length)
        ) else {
            return nil
        }

        let markerRange = match.range(at: 1)
        let markerCharacterRange = match.range(at: 2)
        guard markerRange.location != NSNotFound,
              markerCharacterRange.location != NSNotFound
        else {
            return nil
        }

        return TaskMarkerSourceMetadata(
            sourceRange: SourceTextRange(
                lowerBound: line.sourceRange.lowerBound + markerRange.location,
                upperBound: line.sourceRange.lowerBound + markerRange.location + markerRange.length
            ),
            markerCharacter: nsLine.substring(with: markerCharacterRange)
        )
    }

    private func taskMarkerMetadataPrefix(for metadata: TaskMarkerSourceMetadata) -> String {
        let scalarValue = metadata.markerCharacter.unicodeScalars.first?.value ?? 0
        return "\(Self.taskMarkerMetadataPrefix)\(metadata.sourceRange.lowerBound):\(metadata.sourceRange.upperBound):\(scalarValue)\(Self.taskMarkerMetadataSuffix)"
    }

    private func taskGlyph(for marker: String) -> String {
        switch marker {
        case " ":
            return "☐"
        case "x", "X":
            return "☑"
        case "-":
            return "☒"
        case "/":
            return "◩"
        case "!":
            return "⚠"
        case "?":
            return "?"
        case "*":
            return "★"
        case ">":
            return "›"
        default:
            return "☑"
        }
    }

    private func isTableRow(_ trimmedLine: String) -> Bool {
        let normalized = normalizedTablePipeLine(trimmedLine)
        return tableCells(from: normalized).count >= 2
            && !normalized.hasPrefix("#")
            && !normalized.hasPrefix(">")
            && !OutlineBuilder.isFence(normalized)
    }

    private func isTableStart(_ lines: [MarkdownSourceLine], at index: Int) -> Bool {
        guard index + 1 < lines.count else {
            return false
        }

        let current = lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = lines[index + 1].text.trimmingCharacters(in: .whitespacesAndNewlines)
        let headerCells = tableCells(from: current)
        guard headerCells.count >= 2,
              headerCells.allSatisfy({ isTableSeparatorCell($0) }) == false,
              let separatorCells = tableSeparatorCells(from: next)
        else {
            return false
        }
        return tableColumnCountsAreCompatible(
            headerCount: headerCells.count,
            separatorCount: separatorCells.count
        )
    }

    private func tableColumnCountsAreCompatible(headerCount: Int, separatorCount: Int) -> Bool {
        guard headerCount >= 2, separatorCount >= 2 else {
            return false
        }

        if headerCount == separatorCount {
            return true
        }

        return abs(headerCount - separatorCount) <= 1
    }

    private func isTableSeparator(_ trimmedLine: String) -> Bool {
        tableSeparatorCells(from: trimmedLine) != nil
    }

    private func tableAlignments(from separatorLine: String) -> [NSTextAlignment] {
        tableSeparatorCells(from: separatorLine)?
            .map { rawCell in
                let cell = rawCell.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasLeadingColon = cell.hasPrefix(":")
                let hasTrailingColon = cell.hasSuffix(":")

                if hasLeadingColon && hasTrailingColon {
                    return .center
                }
                if hasTrailingColon {
                    return .right
                }
                return .left
            }
            ?? []
    }

    private func tableSeparatorCells(from line: String) -> [String]? {
        let cells = tableCells(from: normalizedTableSeparatorLine(line))
        guard cells.count >= 2,
              cells.allSatisfy({ isTableSeparatorCell($0) })
        else {
            return nil
        }
        return cells
    }

    private func isTableSeparatorCell(_ cell: String) -> Bool {
        let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
        let dashCount = trimmed.filter { $0 == "-" }.count
        let cleaned = trimmed
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return dashCount >= 1 && cleaned.isEmpty
    }

    private func tableCells(from line: String) -> [String] {
        var trimmed = normalizedTablePipeLine(line).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        var cells: [String] = []
        var current = ""
        var isEscaped = false
        var isInsideObsidianLink = false

        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let character = trimmed[index]

            if isEscaped {
                if character == "|" {
                    current.append(character)
                } else {
                    current.append("\\")
                    current.append(character)
                }
                isEscaped = false
                index = trimmed.index(after: index)
                continue
            }

            if character == "\\" {
                isEscaped = true
                index = trimmed.index(after: index)
                continue
            }

            let nextIndex = trimmed.index(after: index)
            if character == "[",
               nextIndex < trimmed.endIndex,
               trimmed[nextIndex] == "[" {
                isInsideObsidianLink = true
                current.append("[[")
                index = trimmed.index(after: nextIndex)
                continue
            }

            if isInsideObsidianLink,
               character == "]",
               nextIndex < trimmed.endIndex,
               trimmed[nextIndex] == "]" {
                isInsideObsidianLink = false
                current.append("]]")
                index = trimmed.index(after: nextIndex)
                continue
            }

            if character == "|", !isInsideObsidianLink {
                cells.append(tableCellText(current))
                current = ""
            } else {
                current.append(character)
            }

            index = trimmed.index(after: index)
        }

        if isEscaped {
            current.append("\\")
        }
        cells.append(tableCellText(current))
        return cells
    }

    private func tableCellText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\|", with: "|")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedTableSeparatorLine(_ line: String) -> String {
        String(line.map { character in
            switch character {
            case "｜":
                return "|"
            case "‐", "‑", "‒", "–", "—", "―", "−", "﹘", "﹣", "－":
                return "-"
            default:
                return character
            }
        })
    }

    private func normalizedTablePipeLine(_ line: String) -> String {
        line.replacingOccurrences(of: "｜", with: "|")
    }

    private func isDefinitionListStart(_ lines: [MarkdownSourceLine], at index: Int) -> Bool {
        guard index + 1 < lines.count else {
            return false
        }

        let current = lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = lines[index + 1].text.trimmingCharacters(in: .whitespacesAndNewlines)
        return isDefinitionTermLine(current, lines: lines, at: index) && parseDefinitionLine(next) != nil
    }

    private func isDefinitionTermLine(_ trimmedLine: String, lines: [MarkdownSourceLine], at index: Int) -> Bool {
        guard !trimmedLine.isEmpty,
              parseDefinitionLine(trimmedLine) == nil,
              !OutlineBuilder.isFence(trimmedLine),
              OutlineBuilder.parseHeadingLine(lines[index].text) == nil,
              !isTableStart(lines, at: index),
              parseImageLine(trimmedLine, linkReferences: [:]) == nil,
              parseFootnoteDefinition(trimmedLine) == nil,
              parseAbbreviationDefinition(trimmedLine) == nil,
              parseLinkReferenceDefinition(trimmedLine) == nil,
              !isHTMLBlockStart(trimmedLine),
              parseListItem(lines[index].text) == nil,
              !trimmedLine.hasPrefix(">"),
              trimmedLine != "$$",
              trimmedLine != "---",
              trimmedLine != "***"
        else {
            return false
        }
        return true
    }

    private func parseDefinitionLine(_ trimmedLine: String) -> String? {
        let nsLine = trimmedLine as NSString
        let pattern = #"^:\s+(.+)$"#
        guard let match = (try? NSRegularExpression(pattern: pattern))?.firstMatch(
            in: trimmedLine,
            range: NSRange(location: 0, length: nsLine.length)
        ) else {
            return nil
        }

        let definition = nsLine.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return definition.isEmpty ? nil : definition
    }

    private func isHTMLBlockStart(_ trimmedLine: String) -> Bool {
        trimmedLine.range(
            of: #"^<([A-Za-z][A-Za-z0-9-]*)(?:\s[^>]*)?>\s*$"#,
            options: .regularExpression
        ) != nil
    }

    private func collectHTMLBlock(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int) {
        let opening = lines[startIndex]
        let openingTrimmed = opening.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagName = htmlTagName(from: openingTrimmed)
        var renderedLines: [String] = []
        var index = startIndex
        var lastLine = opening

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            lastLine = line

            if index == startIndex {
                index += 1
                continue
            }

            if let tagName,
               trimmed.range(of: #"^</\#(tagName)>\s*$"#, options: .regularExpression) != nil {
                index += 1
                break
            }

            if !trimmed.isEmpty {
                renderedLines.append(stripInlineMarkdown(trimmed))
            }
            index += 1
        }

        let body = renderedLines.joined(separator: "\n")
        let label = "HTML"
        let text = body.isEmpty ? label : "\(label)\n\(body)"
        return (
            text,
            SourceTextRange(lowerBound: opening.sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func htmlTagName(from trimmedLine: String) -> String? {
        let nsLine = trimmedLine as NSString
        let pattern = #"^<([A-Za-z][A-Za-z0-9-]*)(?:\s[^>]*)?>\s*$"#
        guard let match = (try? NSRegularExpression(pattern: pattern))?.firstMatch(
            in: trimmedLine,
            range: NSRange(location: 0, length: nsLine.length)
        ) else {
            return nil
        }

        return nsLine.substring(with: match.range(at: 1))
    }

    private func collectHTMLTable(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int)? {
        let opening = lines[startIndex]
        let openingTrimmed = opening.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard htmlTagName(from: openingTrimmed)?.lowercased() == "table" else {
            return nil
        }

        var rawLines: [String] = []
        var index = startIndex
        var lastLine = opening
        var didFindClosingTable = false

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            rawLines.append(line.text)
            lastLine = line
            index += 1

            if trimmed.range(of: #"^</table>\s*$"#, options: [.caseInsensitive, .regularExpression]) != nil {
                didFindClosingTable = true
                break
            }
        }

        guard didFindClosingTable else {
            return nil
        }

        let rows = htmlTableRows(from: rawLines.joined(separator: "\n"))
        let columnCount = rows.map(\.count).max() ?? 0
        guard rows.count >= 1, columnCount >= 2 else {
            return nil
        }

        let normalizedRows = rows.map { row in
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }

        return (
            normalizedRows.map { $0.joined(separator: "\t") }.joined(separator: "\n"),
            SourceTextRange(lowerBound: opening.sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func htmlTableRows(from html: String) -> [[String]] {
        let nsHTML = html as NSString
        let rowMatches = (try? NSRegularExpression(
            pattern: #"<tr\b[^>]*>(.*?)</tr>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ))?.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)) ?? []

        return rowMatches.compactMap { rowMatch in
            let rowHTML = nsHTML.substring(with: rowMatch.range(at: 1))
            let nsRow = rowHTML as NSString
            let cellMatches = (try? NSRegularExpression(
                pattern: #"<t[hd]\b[^>]*>(.*?)</t[hd]>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ))?.matches(in: rowHTML, range: NSRange(location: 0, length: nsRow.length)) ?? []
            let cells = cellMatches.map { cellMatch in
                htmlTableCellText(nsRow.substring(with: cellMatch.range(at: 1)))
            }
            return cells.isEmpty ? nil : cells
        }
    }

    private func htmlTableCellText(_ rawHTML: String) -> String {
        rawHTML
            .replacingOccurrences(of: #"<br\s*/?>"#, with: " ", options: [.caseInsensitive, .regularExpression])
            .replacingOccurrences(of: #"</p\s*>"#, with: " ", options: [.caseInsensitive, .regularExpression])
            .replacingOccurrences(of: #"(?is)<script\b[^>]*>.*?</script>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<style\b[^>]*>.*?</style>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripInlineMarkdown(
        _ text: String,
        footnoteOrdinals: [String: Int] = [:],
        linkReferences: [String: LinkReferenceDefinition] = [:]
    ) -> String {
        var stripped = replaceReferenceLinks(
            in: replaceFootnoteReferences(in: text, footnoteOrdinals: footnoteOrdinals),
            linkReferences: linkReferences
        )
        stripped = replaceObsidianEmbeds(
            in: replaceObsidianWikilinks(
                in: replaceObsidianComments(in: replaceObsidianBlockID(in: stripped))
            )
        )
            .replacingOccurrences(of: inlineMathPattern(), with: "$1", options: .regularExpression)
            .replacingOccurrences(of: inlineMarkPattern(), with: "$1", options: .regularExpression)
            .replacingOccurrences(of: inlineInsertedPattern(), with: "$1", options: .regularExpression)
            .replacingOccurrences(of: inlineSuperscriptPattern(), with: "$1", options: .regularExpression)
            .replacingOccurrences(of: inlineSubscriptPattern(), with: "$1", options: .regularExpression)
            .replacingEmojiShortcodes(using: emojiShortcodes())

        stripped = replaceInlineMarkdownImages(in: stripped, linkReferences: linkReferences)
        stripped = stripped
            .replacingOccurrences(of: #"(?<!!)(?<!\\)\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?<!`)<(https?://[^>\s]+)>(?!`)"#, with: "$1", options: .regularExpression)

        stripped = replaceInlineHTMLImages(in: stripped)
        stripped = replaceInlineHTMLLinks(in: stripped)
        stripped = stripped
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.caseInsensitive, .regularExpression])
            .replacingOccurrences(of: #"(?<!`)</?[A-Za-z][^>]*>(?!`)"#, with: "", options: .regularExpression)
            .decodingHTMLEntities()
            .replacingOccurrences(of: #"(?<!\\)`([^`\n]+)(?<!\\)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?<!\\)~~(.+?)(?<!\\)~~"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?<!\\)(\*\*|__)(.+?)(?<!\\)\1"#, with: "$2", options: .regularExpression)
            .replacingOccurrences(of: #"(?<![\\*])\*([^*\s][^*\n]{0,160}?)(?<!\\)\*(?!\*)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(
                of: #"(?<![A-Za-z0-9_\\])_([^_\s][^_\n]{0,160}?)(?<!\\)_(?![A-Za-z0-9_])"#,
                with: "$1",
                options: .regularExpression
            )
            .unescapingMarkdownBackslashEscapes()

        return stripped
    }

    private func replaceObsidianComments(in text: String) -> String {
        text.replacingOccurrences(
            of: #"(?s)\s*%%.*?%%\s*"#,
            with: " ",
            options: [.regularExpression]
        )
    }

    private func replaceObsidianBlockID(in text: String) -> String {
        text.replacingOccurrences(
            of: #"\s+\^[A-Za-z0-9_-]+(?=\s*$)"#,
            with: "",
            options: .regularExpression
        )
    }

    private func isStandaloneObsidianBlockID(_ trimmedLine: String) -> Bool {
        trimmedLine.range(
            of: #"^\^[A-Za-z0-9_-]+$"#,
            options: .regularExpression
        ) != nil
    }

    private func replaceObsidianWikilinks(in text: String) -> String {
        replaceObsidianLinkMatches(
            in: text,
            pattern: #"(?<!!)(?<!\\)\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#
        ) { target, alias in
            let cleanedAlias = alias?.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedAlias?.isEmpty == false ? cleanedAlias! : obsidianDisplayTitle(from: target)
        }
    }

    private func replaceObsidianEmbeds(in text: String) -> String {
        replaceObsidianLinkMatches(
            in: text,
            pattern: #"(?<!\\)!\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#
        ) { target, alias in
            obsidianEmbedDisplayText(target: target, alias: alias)
        }
    }

    private func obsidianEmbedDisplayText(target: String, alias: String?) -> String {
        let kind = obsidianFileEmbedKind(for: target)
        let display = obsidianEmbedDisplayName(target: target, alias: alias, kind: kind)
        if let kind {
            return display.isEmpty ? kind.label : "\(kind.label): \(display)"
        }
        if obsidianEmbedIsNoteReference(target) {
            let noteDisplay = obsidianNoteEmbedDisplayName(target: target, alias: alias)
            return noteDisplay.isEmpty ? "Note" : "Note: \(noteDisplay)"
        }
        return display.isEmpty ? "Embed" : "Embed: \(display)"
    }

    private func obsidianEmbedDisplayName(
        target: String,
        alias: String?,
        kind: ObsidianFileEmbedKind? = nil
    ) -> String {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cleanedAlias = alias?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cleanedAlias.isEmpty
        else {
            guard kind != nil else {
                return trimmedTarget
            }
            return obsidianEmbedFilename(from: trimmedTarget)
        }

        return obsidianEmbedImageSize(from: cleanedAlias) == nil ? cleanedAlias : trimmedTarget
    }

    private func obsidianFileEmbedKind(for target: String) -> ObsidianFileEmbedKind? {
        switch obsidianEmbedFileExtension(from: target) {
        case "pdf":
            return .pdf
        case "aac", "aif", "aiff", "flac", "m4a", "mp3", "oga", "ogg", "opus", "wav":
            return .audio
        case "avi", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "ogv", "webm":
            return .video
        default:
            return nil
        }
    }

    private func obsidianEmbedFileExtension(from target: String) -> String {
        (obsidianEmbedFilename(from: target) as NSString).pathExtension.lowercased()
    }

    private func obsidianEmbedIsNoteReference(_ target: String) -> Bool {
        let fileExtension = obsidianEmbedFileExtension(from: target)
        return fileExtension.isEmpty || fileExtension == "md"
    }

    private func obsidianNoteEmbedDisplayName(target: String, alias: String?) -> String {
        if let cleanedAlias = alias?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cleanedAlias.isEmpty {
            return cleanedAlias
        }

        let display = obsidianDisplayTitle(from: target)
        guard display.lowercased().hasSuffix(".md") else {
            return display
        }
        return String(display.dropLast(3))
    }

    private func obsidianEmbedFilename(from target: String) -> String {
        let withoutAnchor = decodedObsidianTarget(from: target)
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? target
        let normalized = withoutAnchor
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
        return normalized.split(separator: "/").last.map(String.init) ?? normalized
    }

    private func obsidianEmbedImageSize(from alias: String?) -> ObsidianEmbedImageSize? {
        guard let alias else {
            return nil
        }

        let normalized = alias
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "×", with: "x")
        guard !normalized.isEmpty else {
            return nil
        }

        let parts = normalized.split(separator: "x", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 1,
           let width = obsidianEmbedDimension(String(parts[0])) {
            return ObsidianEmbedImageSize(width: width, height: nil)
        }

        if parts.count == 2,
           let width = obsidianEmbedDimension(String(parts[0])),
           let height = obsidianEmbedDimension(String(parts[1])) {
            return ObsidianEmbedImageSize(width: width, height: height)
        }

        return nil
    }

    private func obsidianEmbedDimension(_ rawValue: String) -> CGFloat? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed),
              value.isFinite,
              value > 0
        else {
            return nil
        }

        return CGFloat(min(value, 1_600))
    }

    private func replaceObsidianLinkMatches(
        in text: String,
        pattern: String,
        replacement: (String, String?) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let target = nsText.substring(with: match.range(at: 1))
            let aliasRange = match.range(at: 2)
            let alias = aliasRange.location == NSNotFound ? nil : nsText.substring(with: aliasRange)
            mutable.replaceCharacters(in: match.range, with: replacement(target, alias))
        }
        return mutable as String
    }

    private func obsidianDisplayTitle(from target: String) -> String {
        let cleaned = decodedObsidianTarget(from: target)
        guard !cleaned.isEmpty else {
            return cleaned
        }

        let parts = cleaned.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let notePath = parts.first.map(String.init) ?? cleaned
        let anchor = parts.count > 1 ? "#\(parts[1])" : ""
        let noteTitle = notePath.split(separator: "/").last.map(String.init) ?? notePath
        let displayTitle = noteTitle.lowercased().hasSuffix(".md")
            ? String(noteTitle.dropLast(3))
            : noteTitle
        return displayTitle.isEmpty ? anchor : "\(displayTitle)\(anchor)"
    }

    private func decodedObsidianTarget(from target: String) -> String {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.removingPercentEncoding ?? trimmed
    }

    private func replaceInlineMarkdownImages(
        in text: String,
        linkReferences: [String: LinkReferenceDefinition]
    ) -> String {
        var replaced = replaceInlineMarkdownReferenceImages(in: text, linkReferences: linkReferences)
        replaced = replaceInlineMarkdownDirectImages(in: replaced)
        return replaced
    }

    private func replaceInlineMarkdownDirectImages(in text: String) -> String {
        let pattern = #"(?<!\\)!\[([^\]\n]*)\]\(([^)\n]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let altText = nsText.substring(with: match.range(at: 1))
            let destination = imageDestination(from: nsText.substring(with: match.range(at: 2)))
            guard !destination.isEmpty else {
                continue
            }
            mutable.replaceCharacters(
                in: match.range,
                with: inlineImagePlaceholder(altText: altText, url: destination)
            )
        }
        return mutable as String
    }

    private func replaceInlineMarkdownReferenceImages(
        in text: String,
        linkReferences: [String: LinkReferenceDefinition]
    ) -> String {
        guard !linkReferences.isEmpty else {
            return text
        }

        let pattern = #"(?<!\\)!\[([^\]\n]*)\]\[([^\]\n]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let altText = nsText.substring(with: match.range(at: 1))
            let referenceLabel = nsText.substring(with: match.range(at: 2))
            guard let reference = resolveLinkReference(
                label: altText,
                referenceLabel: referenceLabel,
                linkReferences: linkReferences
            ) else {
                continue
            }
            mutable.replaceCharacters(
                in: match.range,
                with: inlineImagePlaceholder(altText: altText, url: reference.destination)
            )
        }
        return mutable as String
    }

    private func inlineImagePlaceholder(altText: String, url: String) -> String {
        let cleanedAltText = altText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedAltText.isEmpty {
            return "Image: \(url)"
        }
        return "Image: \(cleanedAltText) (\(url))"
    }

    private func replaceInlineHTMLLinks(in text: String) -> String {
        let pattern = #"<a\b([^>]*)>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else {
                continue
            }

            let attributeText = nsText.substring(with: match.range(at: 1))
            guard let href = htmlAttribute("href", in: attributeText),
                  !href.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }

            let rawLabel = nsText.substring(with: match.range(at: 2))
            let label = htmlInlineText(rawLabel).trimmingCharacters(in: .whitespacesAndNewlines)
            mutable.replaceCharacters(in: match.range, with: label.isEmpty ? href : label)
        }

        return mutable as String
    }

    private func replaceInlineHTMLImages(in text: String) -> String {
        let pattern = #"<img\b([^>]*)/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let attributeText = nsText.substring(with: match.range(at: 1))
            guard let source = htmlAttribute("src", in: attributeText),
                  !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }

            let altText = htmlAttribute("alt", in: attributeText)
                ?? htmlAttribute("title", in: attributeText)
                ?? ""
            let label = altText.trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = label.isEmpty ? "Image: \(source)" : "Image: \(label) (\(source))"
            mutable.replaceCharacters(in: match.range, with: replacement)
        }

        return mutable as String
    }

    private func htmlInlineText(_ html: String) -> String {
        replaceInlineHTMLImages(in: html)
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.caseInsensitive, .regularExpression])
            .replacingOccurrences(of: #"</?[A-Za-z][^>]*>"#, with: "", options: .regularExpression)
            .decodingHTMLEntities()
    }

    private func htmlAttribute(_ name: String, in attributeText: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\b\#(escapedName)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsText = attributeText as NSString
        guard let match = regex.firstMatch(
            in: attributeText,
            range: NSRange(location: 0, length: nsText.length)
        ) else {
            return nil
        }

        for groupIndex in 1..<match.numberOfRanges {
            let range = match.range(at: groupIndex)
            if range.location != NSNotFound {
                return nsText.substring(with: range).decodingHTMLEntities()
            }
        }

        return nil
    }

    private func inlineMathPattern() -> String {
        #"(?<![$\\])\$([A-Za-z\\(][^$\n]{0,160}?[=^_\\+\-*/][^$\n]{0,160}?)\$(?![$\d])"#
    }

    private func inlineMarkPattern() -> String {
        #"(?<![=\\])==([^=\s][^=\n]{0,160}?)(?<!\\)==(?![=])"#
    }

    private func inlineInsertedPattern() -> String {
        #"(?<![\+\\])\+\+([^\+\s][^\+\n]{0,160}?)(?<!\\)\+\+(?!\+)"#
    }

    private func inlineHTMLTagPattern(_ tagName: String, maximumLength: Int = 160) -> String {
        let escapedTag = NSRegularExpression.escapedPattern(for: tagName)
        return #"<\#(escapedTag)\b[^>]*>([^<\n]{1,\#(maximumLength)})</\#(escapedTag)>"#
    }

    private func inlineSuperscriptPattern() -> String {
        #"(?<![\^\\])\^([^\^\s][^\^\n]{0,40}?)(?<!\\)\^(?!\^)"#
    }

    private func inlineSubscriptPattern() -> String {
        #"(?<![~\\])~([^~\s][^~\n]{0,40}?)(?<!\\)~(?!~)"#
    }

    private func inlineFootnotePattern() -> String {
        #"(?<!\\)\^\[([^\]\n]{1,280})\]"#
    }

    private func emojiShortcodes() -> [String: String] {
        [
            "bug": "🐛",
            "bulb": "💡",
            "check": "✓",
            "eyes": "👀",
            "fire": "🔥",
            "information_source": "ℹ️",
            "link": "🔗",
            "lock": "🔒",
            "memo": "📝",
            "rocket": "🚀",
            "sparkles": "✨",
            "tada": "🎉",
            "unlock": "🔓",
            "warning": "⚠️",
            "white_check_mark": "✅",
            "x": "✕"
        ]
    }

    private func parseImageLine(
        _ trimmedLine: String,
        linkReferences: [String: LinkReferenceDefinition]
    ) -> (altText: String, url: String)? {
        let nsLine = trimmedLine as NSString
        let inlinePattern = #"^!\[([^\]]*)\]\(([^)]+)\)\s*$"#
        if let match = (try? NSRegularExpression(pattern: inlinePattern))?.firstMatch(
            in: trimmedLine,
            range: NSRange(location: 0, length: nsLine.length)
        ) {
            return (
                nsLine.substring(with: match.range(at: 1)),
                nsLine.substring(with: match.range(at: 2))
            )
        }

        let referencePattern = #"^!\[([^\]]*)\]\[([^\]]*)\]\s*$"#
        guard let match = (try? NSRegularExpression(pattern: referencePattern))?.firstMatch(
            in: trimmedLine,
            range: NSRange(location: 0, length: nsLine.length)
        ) else {
            return nil
        }

        let altText = nsLine.substring(with: match.range(at: 1))
        let rawReferenceLabel = nsLine.substring(with: match.range(at: 2))
        let referenceLabel = rawReferenceLabel.isEmpty ? altText : rawReferenceLabel
        guard let reference = linkReferences[normalizedReferenceLabel(referenceLabel)] else {
            return nil
        }

        return (
            altText,
            reference.destination
        )
    }

    private func imagePlaceholder(altText: String, url: String) -> String {
        let title = altText.isEmpty ? "Image" : "Image: \(altText)"
        return "\(title)\n\(url)"
    }

    private func localImageURL(for destination: String, baseURL: URL?) -> URL? {
        let trimmed = imageDestination(from: destination)
        guard !trimmed.isEmpty else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("http://")
            || lowercased.hasPrefix("https://")
            || lowercased.hasPrefix("data:")
        {
            return nil
        }

        let url: URL
        if let parsedURL = URL(string: trimmed),
           parsedURL.scheme == "file" {
            url = parsedURL
        } else if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            url = URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath)
        } else if let baseURL {
            url = URL(fileURLWithPath: trimmed, relativeTo: baseURL).standardizedFileURL
        } else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path),
              NSImage(contentsOf: url) != nil
        else {
            return nil
        }
        return url
    }

    private func imageDestination(from rawDestination: String) -> String {
        let trimmed = rawDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<"),
           let closingIndex = trimmed.firstIndex(of: ">") {
            return String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingIndex])
        }

        return trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? trimmed
    }

    private func parseFootnoteDefinition(_ trimmedLine: String) -> (identifier: String, text: String)? {
        let nsLine = trimmedLine as NSString
        let pattern = #"^\[\^([^\]]+)\]:\s*(.*)$"#
        guard let match = (try? NSRegularExpression(pattern: pattern))?.firstMatch(
            in: trimmedLine,
            range: NSRange(location: 0, length: nsLine.length)
        ) else {
            return nil
        }

        return (
            nsLine.substring(with: match.range(at: 1)),
            nsLine.substring(with: match.range(at: 2))
        )
    }

    private func collectFootnoteDefinition(
        from lines: [MarkdownSourceLine],
        startingAt startIndex: Int,
        footnoteOrdinals: [String: Int]
    ) -> (text: String, sourceRange: SourceTextRange, nextIndex: Int) {
        let opening = lines[startIndex]
        let trimmed = opening.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let footnote = parseFootnoteDefinition(trimmed) else {
            return (trimmed, opening.sourceRange, startIndex + 1)
        }

        let label = footnoteDefinitionLabel(identifier: footnote.identifier, footnoteOrdinals: footnoteOrdinals)
        var renderedLines = [
            "\(label) \(stripInlineMarkdown(footnote.text, footnoteOrdinals: footnoteOrdinals))"
        ]
        var index = startIndex + 1
        var lastLine = opening

        while index < lines.count {
            let line = lines[index]
            guard isFootnoteContinuation(line.text) else {
                break
            }

            let continuation = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !continuation.isEmpty {
                renderedLines.append(stripInlineMarkdown(continuation, footnoteOrdinals: footnoteOrdinals))
            }
            lastLine = line
            index += 1
        }

        return (
            renderedLines.joined(separator: " "),
            SourceTextRange(lowerBound: opening.sourceRange.lowerBound, upperBound: lastLine.sourceRange.upperBound),
            index
        )
    }

    private func isFootnoteContinuation(_ line: String) -> Bool {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }

        let leadingSpaces = line.prefix { $0 == " " }.count
        return leadingSpaces >= 2 || line.hasPrefix("\t")
    }

    private func footnoteReferenceOrdinals(in lines: [MarkdownSourceLine]) -> [String: Int] {
        guard let referenceRegex = try? NSRegularExpression(pattern: #"\[\^([^\]]+)\]"#),
              let inlineRegex = try? NSRegularExpression(pattern: inlineFootnotePattern())
        else {
            return [:]
        }

        var ordinals: [String: Int] = [:]
        var isInsideObsidianCommentBlock = false
        for line in lines {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if isInsideObsidianCommentBlock {
                if trimmed.range(of: "%%") != nil {
                    isInsideObsidianCommentBlock = false
                }
                continue
            }

            if isObsidianCommentBlockStart(trimmed) {
                if obsidianCommentClosingRange(in: trimmed, afterOpeningAt: trimmed.startIndex) == nil {
                    isInsideObsidianCommentBlock = true
                }
                continue
            }

            if parseFootnoteDefinition(trimmed) != nil {
                continue
            }

            let nsLine = line.text as NSString
            let referenceMatches = referenceRegex.matches(in: line.text, range: NSRange(location: 0, length: nsLine.length))
                .map { match in (range: match.range, identifier: nsLine.substring(with: match.range(at: 1))) }
            let inlineMatches = inlineRegex.matches(in: line.text, range: NSRange(location: 0, length: nsLine.length))
                .compactMap { match -> (range: NSRange, identifier: String)? in
                    let text = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else {
                        return nil
                    }
                    return (match.range, inlineFootnoteIdentifier(text: text))
                }

            for match in (referenceMatches + inlineMatches).sorted(by: { $0.range.location < $1.range.location }) {
                let identifier = match.identifier
                if ordinals[identifier] == nil {
                    ordinals[identifier] = ordinals.count + 1
                }
            }
        }

        return ordinals
    }

    private func footnoteDefinitionTooltips(
        in lines: [MarkdownSourceLine],
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition]
    ) -> [String: String] {
        var definitions: [String: String] = [:]
        var index = 0
        var isInsideObsidianCommentBlock = false

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if isInsideObsidianCommentBlock {
                if trimmed.range(of: "%%") != nil {
                    isInsideObsidianCommentBlock = false
                }
                index += 1
                continue
            }

            if isObsidianCommentBlockStart(trimmed) {
                if obsidianCommentClosingRange(in: trimmed, afterOpeningAt: trimmed.startIndex) == nil {
                    isInsideObsidianCommentBlock = true
                }
                index += 1
                continue
            }

            guard let footnote = parseFootnoteDefinition(trimmed) else {
                index += 1
                continue
            }

            var parts: [String] = []
            let firstLine = stripInlineMarkdown(
                footnote.text,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if !firstLine.isEmpty {
                parts.append(firstLine)
            }

            index += 1
            while index < lines.count,
                  isFootnoteContinuation(lines[index].text) {
                let continuation = lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !continuation.isEmpty {
                    let renderedContinuation = stripInlineMarkdown(
                        continuation,
                        footnoteOrdinals: footnoteOrdinals,
                        linkReferences: linkReferences
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !renderedContinuation.isEmpty {
                        parts.append(renderedContinuation)
                    }
                }
                index += 1
            }

            let tooltip = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !tooltip.isEmpty {
                definitions[footnote.identifier] = tooltip
            }
        }

        return definitions
    }

    private func replaceFootnoteReferences(in text: String, footnoteOrdinals: [String: Int]) -> String {
        let pattern = #"\[\^([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        let replacedReferences: String
        if matches.isEmpty {
            replacedReferences = text
        } else {
            let mutable = NSMutableString(string: text)
            for match in matches.reversed() {
                let identifier = nsText.substring(with: match.range(at: 1))
                mutable.replaceCharacters(
                    in: match.range,
                    with: footnoteReferenceLabel(identifier: identifier, footnoteOrdinals: footnoteOrdinals)
                )
            }
            replacedReferences = mutable as String
        }
        return replaceInlineFootnotes(in: replacedReferences, footnoteOrdinals: footnoteOrdinals)
    }

    private func replaceInlineFootnotes(in text: String, footnoteOrdinals: [String: Int]) -> String {
        guard let regex = try? NSRegularExpression(pattern: inlineFootnotePattern()) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let footnoteText = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            mutable.replaceCharacters(
                in: match.range,
                with: footnoteReferenceLabel(identifier: inlineFootnoteIdentifier(text: footnoteText), footnoteOrdinals: footnoteOrdinals)
            )
        }
        return mutable as String
    }

    private func replaceReferenceLinks(
        in text: String,
        linkReferences: [String: LinkReferenceDefinition]
    ) -> String {
        guard !linkReferences.isEmpty else {
            return text
        }

        let pattern = #"(?<!!)(?<!\\)\[([^\]\n]+)\]\[([^\]\n]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let label = nsText.substring(with: match.range(at: 1))
            let referenceLabel = nsText.substring(with: match.range(at: 2))
            guard resolveLinkReference(label: label, referenceLabel: referenceLabel, linkReferences: linkReferences) != nil else {
                continue
            }
            mutable.replaceCharacters(in: match.range, with: label)
        }
        return mutable as String
    }

    private func resolveLinkReference(
        label: String,
        referenceLabel: String,
        linkReferences: [String: LinkReferenceDefinition]
    ) -> LinkReferenceDefinition? {
        let effectiveLabel = referenceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? label : referenceLabel
        return linkReferences[normalizedReferenceLabel(effectiveLabel)]
    }

    private func footnoteReferenceLabel(identifier: String, footnoteOrdinals: [String: Int]) -> String {
        guard let ordinal = footnoteOrdinals[identifier] else {
            return "[\(identifier)]"
        }
        return superscriptNumber(ordinal)
    }

    private func footnoteDefinitionLabel(identifier: String, footnoteOrdinals: [String: Int]) -> String {
        guard let ordinal = footnoteOrdinals[identifier] else {
            return "[\(identifier)]"
        }
        return "\(ordinal)."
    }

    private func inlineFootnoteIdentifier(text: String) -> String {
        Self.inlineFootnoteIdentifierPrefix + text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func superscriptNumber(_ number: Int) -> String {
        let digits: [Character: Character] = [
            "0": "⁰",
            "1": "¹",
            "2": "²",
            "3": "³",
            "4": "⁴",
            "5": "⁵",
            "6": "⁶",
            "7": "⁷",
            "8": "⁸",
            "9": "⁹"
        ]
        return String(String(number).map { digits[$0] ?? $0 })
    }

    private func attributedText(
        for text: String,
        kind: MarkdownRenderBlockKind,
        attributes: [NSAttributedString.Key: Any],
        footnoteOrdinals: [String: Int],
        footnoteDefinitions: [String: String],
        tableColumnAlignments: [NSTextAlignment]? = nil,
        localImageURL: URL? = nil,
        abbreviations: [String: String] = [:],
        linkReferences: [String: LinkReferenceDefinition] = [:],
        baseURL: URL? = nil
    ) -> NSAttributedString {
        switch kind {
        case .codeBlock:
            return codeBlockAttributedString(text: text, attributes: attributes)
        case .table:
            return tableAttributedString(
                text: text,
                attributes: attributes,
                columnAlignments: tableColumnAlignments ?? [],
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL
            )
        case .htmlBlock:
            return labeledFallbackBlockAttributedString(text: text, attributes: attributes, label: "HTML")
        case .mathBlock:
            return mathBlockAttributedString(text: text, attributes: attributes)
        case .image:
            return imageAttributedString(text: text, attributes: attributes, localImageURL: localImageURL)
        case .footnote, .thematicBreak:
            return NSAttributedString(string: text, attributes: attributes)
        case .metadata:
            return metadataAttributedString(text: text, attributes: attributes)
        case .heading:
            return inlineStyledAttributedString(
                markdown: text,
                baseAttributes: attributes,
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL
            )
        case .unorderedList, .orderedList, .taskList:
            return listAttributedString(
                text: text,
                attributes: attributes,
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL
            )
        case .definitionList:
            return definitionListAttributedString(
                text: text,
                attributes: attributes,
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL
            )
        case .paragraph:
            return inlineStyledAttributedString(
                markdown: text,
                baseAttributes: attributes,
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL
            )
        case .blockquote:
            return blockquoteAttributedString(
                markdown: text,
                attributes: attributes,
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL
            )
        }
    }

    private func blockquoteAttributedString(
        markdown: String,
        attributes: [NSAttributedString.Key: Any],
        footnoteOrdinals: [String: Int],
        footnoteDefinitions: [String: String],
        abbreviations: [String: String],
        linkReferences: [String: LinkReferenceDefinition],
        baseURL: URL?
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let calloutKind = (attributes[.markPromptCalloutKind] as? String).flatMap(CalloutKind.init(rawValue:))
        let calloutFoldState = (attributes[.markPromptCalloutFoldState] as? String).flatMap(CalloutFoldState.init(rawValue:))
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for lineIndex in lines.indices {
            let rawLine = lines[lineIndex]
            let nestingLevel = blockquoteNestingLevel(in: rawLine)
            let displayLine = blockquoteLineText(rawLine)
            var lineAttributes = attributes
            lineAttributes[.paragraphStyle] = quoteParagraphStyle(
                calloutKind: calloutKind,
                nestingLevel: nestingLevel
            )

            let lineAttributed = NSMutableAttributedString(attributedString: inlineStyledAttributedString(
                    markdown: displayLine,
                    baseAttributes: lineAttributes,
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL
            ))

            if lineIndex != lines.startIndex,
               let nestedFoldState = CalloutFoldState(disclosureGlyph: lineAttributed.string.first) {
                lineAttributed.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                        .toolTip: nestedFoldState.tooltip
                    ],
                    range: NSRange(location: 0, length: min(1, lineAttributed.length))
                )
            }

            if lineIndex == lines.startIndex,
               let calloutKind,
               lineAttributed.length > 0 {
                if let calloutFoldState {
                    let disclosure = NSAttributedString(
                        string: "\(calloutFoldState.disclosureGlyph) ",
                        attributes: lineAttributes
                    )
                    lineAttributed.insert(disclosure, at: 0)
                    lineAttributed.addAttributes(
                        [
                            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                            .foregroundColor: calloutColor(for: calloutKind),
                            .toolTip: calloutFoldState.tooltip
                        ],
                        range: NSRange(location: 0, length: 1)
                    )
                }
                let trimmedTitleLength = (lineAttributed.string as NSString)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .count
                if trimmedTitleLength > 0 {
                    lineAttributed.addAttributes(
                        [
                            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                            .foregroundColor: calloutColor(for: calloutKind)
                        ],
                        range: NSRange(location: 0, length: min(trimmedTitleLength, lineAttributed.length))
                    )
                }
            }

            result.append(lineAttributed)
            if lineIndex < lines.index(before: lines.endIndex) {
                result.append(NSAttributedString(string: "\n", attributes: lineAttributes))
            }
        }

        return result
    }

    private func metadataAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return result
        }

        if text.hasPrefix("Properties") {
            result.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 13.5, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ],
                range: NSRange(location: 0, length: min("Properties".count, nsText.length))
            )
        }

        var lineStart = 0
        while lineStart < nsText.length {
            var lineEnd = lineStart
            while lineEnd < nsText.length,
                  !isLineBreak(nsText.character(at: lineEnd)) {
                lineEnd += 1
            }

            let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
            let line = nsText.substring(with: lineRange)
            if let separator = line.firstIndex(of: ":") {
                let keyLength = line.distance(from: line.startIndex, to: separator) + 1
                result.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                        .foregroundColor: NSColor.labelColor
                    ],
                    range: NSRange(location: lineStart, length: keyLength)
                )

                let key = String(line[..<separator])
                if key.caseInsensitiveCompare("Tags") == .orderedSame {
                    let valueStart = lineStart + keyLength
                    let valueLength = max(0, lineRange.upperBound - valueStart)
                    applyMetadataTagTokenStyle(
                        to: result,
                        in: NSRange(location: valueStart, length: valueLength)
                    )
                }
            }

            lineStart = lineEnd + 1
        }

        return result
    }

    private func applyMetadataTagTokenStyle(
        to attributed: NSMutableAttributedString,
        in range: NSRange
    ) {
        let nsText = attributed.string as NSString
        guard range.location < nsText.length,
              range.length > 0
        else {
            return
        }

        var tokenStart: Int?
        var location = range.location
        let upperBound = min(range.upperBound, nsText.length)
        while location <= upperBound {
            let isEnd = location == upperBound
            let character = isEnd ? 32 : nsText.character(at: location)
            let isSeparator = isEnd || isHorizontalWhitespace(character) || isLineBreak(character)

            if isSeparator {
                if let start = tokenStart,
                   location > start {
                    attributed.addAttributes(
                        [
                            .font: NSFont.systemFont(ofSize: 12.8, weight: .medium),
                            .foregroundColor: NSColor.systemPurple,
                            .backgroundColor: obsidianTokenBackgroundColor()
                        ],
                        range: NSRange(location: start, length: location - start)
                    )
                }
                tokenStart = nil
            } else if tokenStart == nil {
                tokenStart = location
            }

            location += 1
        }
    }

    private func blockquoteNestingLevel(in line: String) -> Int {
        guard let prefix = Self.blockquoteNestingPrefix.first else {
            return 0
        }
        return line.prefix { $0 == prefix }.count
    }

    private func blockquoteLineText(_ line: String) -> String {
        guard let prefix = Self.blockquoteNestingPrefix.first else {
            return line
        }
        return String(line.drop(while: { $0 == prefix }))
    }

    private func listAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        footnoteOrdinals: [String: Int],
        footnoteDefinitions: [String: String],
        abbreviations: [String: String],
        linkReferences: [String: LinkReferenceDefinition],
        baseURL: URL?
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for lineIndex in lines.indices {
            let rawLine = lines[lineIndex]
            let indentLevel = renderedListIndentLevel(rawLine)
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
            let taskMarkerMetadata = taskMarkerMetadata(in: trimmedLine)
            let lineWithoutTaskMetadata = if let taskMarkerMetadata {
                String(trimmedLine.dropFirst(taskMarkerMetadata.prefixLength))
            } else {
                trimmedLine
            }
            let continuationKind = listContinuationKind(in: lineWithoutTaskMetadata)
            let isContinuation = continuationKind != nil
            let isLooseContinuation = continuationKind?.isLoose == true
            let displayLine = if let continuationKind {
                String(lineWithoutTaskMetadata.dropFirst(continuationKind.prefix.count))
            } else {
                lineWithoutTaskMetadata
            }
            let lineAttributed = NSMutableAttributedString(
                attributedString: inlineStyledAttributedString(
                    markdown: displayLine,
                    baseAttributes: attributes,
                    footnoteOrdinals: footnoteOrdinals,
                    footnoteDefinitions: footnoteDefinitions,
                    abbreviations: abbreviations,
                    linkReferences: linkReferences,
                    baseURL: baseURL
                )
            )
            let paragraphRange = NSRange(location: 0, length: lineAttributed.length)
            lineAttributed.addAttribute(
                .paragraphStyle,
                value: isContinuation
                    ? listContinuationParagraphStyle(
                        indentLevel: indentLevel,
                        startsLooseParagraph: isLooseContinuation
                    )
                    : listParagraphStyle(indentLevel: indentLevel),
                range: paragraphRange
            )

            if !isContinuation,
               let markerRange = listMarkerRange(in: displayLine) {
                lineAttributed.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: 15.5, weight: .semibold),
                        .foregroundColor: listMarkerColor(displayLine)
                    ],
                    range: markerRange
                )
                if let taskMarkerMetadata {
                    var taskMarkerAttributes: [NSAttributedString.Key: Any] = [
                        .markPromptTaskMarkerSourceRange: taskMarkerMetadata.sourceRange,
                        .toolTip: Self.taskMarkerTooltip
                    ]
                    if let markerCharacter = taskMarkerMetadata.markerCharacter {
                        taskMarkerAttributes[.markPromptTaskMarkerCharacter] = markerCharacter
                    }
                    lineAttributed.addAttributes(
                        taskMarkerAttributes,
                        range: markerRange
                    )
                }

                if let completedTaskTextRange = completedTaskTextRange(in: displayLine, markerRange: markerRange) {
                    lineAttributed.addAttributes(
                        [
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .strikethroughColor: NSColor.secondaryLabelColor
                        ],
                        range: completedTaskTextRange
                    )
                }
            } else if continuationKind?.inheritsCompletedTaskStyle == true,
                      lineAttributed.length > 0 {
                lineAttributed.addAttributes(
                    [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: NSColor.secondaryLabelColor
                    ],
                    range: NSRange(location: 0, length: lineAttributed.length)
                )
            }

            result.append(lineAttributed)
            if lineIndex < lines.index(before: lines.endIndex) {
                result.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }

        return result
    }

    private func taskMarkerMetadata(in line: String) -> (sourceRange: SourceTextRange, markerCharacter: String?, prefixLength: Int)? {
        guard line.hasPrefix(Self.taskMarkerMetadataPrefix) else {
            return nil
        }

        let nsLine = line as NSString
        let suffixRange = nsLine.range(of: Self.taskMarkerMetadataSuffix)
        let payloadStart = (Self.taskMarkerMetadataPrefix as NSString).length
        guard suffixRange.location != NSNotFound,
              suffixRange.location > payloadStart
        else {
            return nil
        }

        let payload = nsLine.substring(
            with: NSRange(location: payloadStart, length: suffixRange.location - payloadStart)
        )
        let payloadParts = payload.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        let bounds = payloadParts.prefix(2).compactMap { Int($0) }
        guard bounds.count == 2 else {
            return nil
        }
        let markerCharacter = markerCharacter(fromEncodedPayloadPart: payloadParts.dropFirst(2).first)

        return (
            SourceTextRange(lowerBound: bounds[0], upperBound: bounds[1]),
            markerCharacter,
            suffixRange.location + suffixRange.length
        )
    }

    private func markerCharacter(fromEncodedPayloadPart payloadPart: Substring?) -> String? {
        guard let payloadPart,
              let scalarValue = UInt32(payloadPart),
              let scalar = UnicodeScalar(scalarValue)
        else {
            return nil
        }

        return String(Character(scalar))
    }

    private func listContinuationKind(in line: String) -> (prefix: String, isLoose: Bool, inheritsCompletedTaskStyle: Bool)? {
        if line.hasPrefix(Self.completedTaskLooseContinuationPrefix) {
            return (Self.completedTaskLooseContinuationPrefix, true, true)
        }
        if line.hasPrefix(Self.completedTaskContinuationPrefix) {
            return (Self.completedTaskContinuationPrefix, false, true)
        }
        if line.hasPrefix(Self.listLooseContinuationPrefix) {
            return (Self.listLooseContinuationPrefix, true, false)
        }
        if line.hasPrefix(Self.listContinuationPrefix) {
            return (Self.listContinuationPrefix, false, false)
        }
        return nil
    }

    private func definitionListAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        footnoteOrdinals: [String: Int],
        footnoteDefinitions: [String: String],
        abbreviations: [String: String],
        linkReferences: [String: LinkReferenceDefinition],
        baseURL: URL?
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for lineIndex in lines.indices {
            let rawLine = lines[lineIndex]
            let isTerm = rawLine.hasPrefix(Self.definitionTermPrefix)
            let markdown: String
            if isTerm {
                markdown = String(rawLine.dropFirst(Self.definitionTermPrefix.count))
            } else if rawLine.hasPrefix(Self.definitionTextPrefix) {
                markdown = String(rawLine.dropFirst(Self.definitionTextPrefix.count))
            } else {
                markdown = rawLine
            }
            let lineAttributes = isTerm
                ? definitionTermAttributes(from: attributes)
                : definitionTextAttributes(from: attributes)
            result.append(inlineStyledAttributedString(
                markdown: markdown,
                baseAttributes: lineAttributes,
                footnoteOrdinals: footnoteOrdinals,
                footnoteDefinitions: footnoteDefinitions,
                abbreviations: abbreviations,
                linkReferences: linkReferences,
                baseURL: baseURL
            ))
            if lineIndex < lines.index(before: lines.endIndex) {
                result.append(NSAttributedString(string: "\n", attributes: lineAttributes))
            }
        }

        return result
    }

    private func renderedListIndentLevel(_ line: String) -> Int {
        let leadingSpaces = line.prefix { $0 == " " }.count
        return min(4, leadingSpaces / 2)
    }

    private func listMarkerRange(in line: String) -> NSRange? {
        let nsLine = line as NSString
        let pattern = #"^(☑|☐|☒|◩|⚠|\?|★|›|•|\d+[.)])"#
        return (try? NSRegularExpression(pattern: pattern))?
            .firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length))?
            .range(at: 1)
    }

    private func listMarkerColor(_ line: String) -> NSColor {
        if line.hasPrefix("☑") {
            return NSColor.systemBlue
        }
        if line.hasPrefix("☒") || line.hasPrefix("⚠") {
            return NSColor.systemOrange
        }
        if line.hasPrefix("◩") {
            return NSColor.systemPurple
        }
        return NSColor.secondaryLabelColor
    }

    private func completedTaskTextRange(in line: String, markerRange: NSRange) -> NSRange? {
        guard line.hasPrefix("☑") else {
            return nil
        }

        let nsLine = line as NSString
        var location = markerRange.upperBound
        if location < nsLine.length,
           CharacterSet.whitespaces.contains(UnicodeScalar(nsLine.character(at: location)) ?? UnicodeScalar(32)) {
            location += 1
        }
        guard location < nsLine.length else {
            return nil
        }

        return NSRange(location: location, length: nsLine.length - location)
    }

    private func tableAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        columnAlignments: [NSTextAlignment],
        footnoteOrdinals: [String: Int],
        footnoteDefinitions: [String: String],
        abbreviations: [String: String],
        linkReferences: [String: LinkReferenceDefinition],
        baseURL: URL?
    ) -> NSAttributedString {
        let markdownRows = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { row in
                row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            }
            .filter { row in
                row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }

        guard !markdownRows.isEmpty else {
            return NSAttributedString(string: text, attributes: attributes)
        }

        let displayRows = markdownRows.map { row in
            row.map { stripInlineMarkdown($0, linkReferences: linkReferences) }
        }
        let columnCount = max(1, markdownRows.map(\.count).max() ?? 1)
        let baseFont = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 13.5)
        let headerFont = NSFont.systemFont(ofSize: max(11.4, baseFont.pointSize - 0.5), weight: .semibold)
        let columnWidths = tableColumnWidths(
            rows: displayRows,
            bodyFont: baseFont,
            headerFont: headerFont
        )
        let tableWidth = columnWidths.reduce(0, +)
        let table = NSTextTable()
        table.numberOfColumns = columnCount
        table.layoutAlgorithm = .fixedLayoutAlgorithm
        table.collapsesBorders = true
        table.hidesEmptyCells = false
        table.setContentWidth(tableWidth, type: .absoluteValueType)
        table.setWidth(0, type: .absoluteValueType, for: .margin)

        let result = NSMutableAttributedString()

        for rowIndex in markdownRows.indices {
            let row = markdownRows[rowIndex]

            for columnIndex in 0..<columnCount {
                let value = row.indices.contains(columnIndex) ? row[columnIndex] : ""
                let block = NSTextTableBlock(
                    table: table,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: columnIndex,
                    columnSpan: 1
                )
                block.setValue(columnWidths[columnIndex], type: .absoluteValueType, for: .width)
                block.setWidth(0.5, type: .absoluteValueType, for: .border)
                block.setWidth(6, type: .absoluteValueType, for: .padding)
                block.setBorderColor(NSColor.separatorColor)
                block.verticalAlignment = .middleAlignment
                if rowIndex == 0 {
                    block.backgroundColor = NSColor.controlBackgroundColor
                }

                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 2.5
                paragraph.paragraphSpacing = 0
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.alignment = tableColumnAlignment(
                    rows: displayRows,
                    columnIndex: columnIndex,
                    declaredAlignments: columnAlignments
                )
                paragraph.textBlocks = [block]

                var cellAttributes = attributes
                cellAttributes[.paragraphStyle] = paragraph
                cellAttributes[.font] = rowIndex == 0 ? headerFont : baseFont
                cellAttributes[.backgroundColor] = NSColor.clear

                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(NSAttributedString(string: " \n", attributes: cellAttributes))
                } else {
                    result.append(inlineStyledAttributedString(
                        markdown: value,
                        baseAttributes: cellAttributes,
                        footnoteOrdinals: footnoteOrdinals,
                        footnoteDefinitions: footnoteDefinitions,
                        abbreviations: abbreviations,
                        linkReferences: linkReferences,
                        baseURL: baseURL
                    ))
                    result.append(NSAttributedString(string: "\n", attributes: cellAttributes))
                }
            }
        }

        return result
    }

    private func tableColumnWidths(
        rows: [[String]],
        bodyFont: NSFont,
        headerFont: NSFont
    ) -> [CGFloat] {
        let columnCount = max(1, rows.map(\.count).max() ?? 1)
        let paddingAndBorder: CGFloat = 18
        var measuredWidths = Array(repeating: CGFloat(72), count: columnCount)

        for columnIndex in 0..<columnCount {
            let columnValues = rows.indices.map { rowIndex in
                rows[rowIndex].indices.contains(columnIndex) ? rows[rowIndex][columnIndex] : ""
            }
            let isNumericColumn = tableColumnLooksNumeric(rows: rows, columnIndex: columnIndex)
            let maximumColumnWidth: CGFloat = isNumericColumn ? 118 : 175
            let minimumColumnWidth: CGFloat = isNumericColumn ? 98 : 106

            for rowIndex in columnValues.indices {
                let value = columnValues[rowIndex].isEmpty ? " " : columnValues[rowIndex]
                let font = rowIndex == 0 ? headerFont : bodyFont
                let measured = ceil((value as NSString).size(withAttributes: [.font: font]).width) + paddingAndBorder
                measuredWidths[columnIndex] = max(
                    measuredWidths[columnIndex],
                    min(maximumColumnWidth, max(minimumColumnWidth, measured))
                )
            }
        }

        let naturalWidth = measuredWidths.reduce(0, +)
        let readableMinimumWidth = min(CGFloat(760), max(CGFloat(420), CGFloat(columnCount) * 110))
        let targetWidth = min(CGFloat(880), max(readableMinimumWidth, naturalWidth))

        guard naturalWidth > 0, abs(targetWidth - naturalWidth) > 0.5 else {
            return measuredWidths
        }

        let scale = targetWidth / naturalWidth
        return measuredWidths.map { ceil($0 * scale) }
    }

    private func tableColumnAlignment(
        rows: [[String]],
        columnIndex: Int,
        declaredAlignments: [NSTextAlignment]
    ) -> NSTextAlignment {
        if declaredAlignments.indices.contains(columnIndex) {
            return declaredAlignments[columnIndex]
        }

        return tableColumnLooksNumeric(rows: rows, columnIndex: columnIndex) ? .right : .left
    }

    private func tableColumnLooksNumeric(rows: [[String]], columnIndex: Int) -> Bool {
        let bodyValues = rows.dropFirst().compactMap { row -> String? in
            guard row.indices.contains(columnIndex) else {
                return nil
            }
            let value = row[columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        guard !bodyValues.isEmpty else {
            return false
        }

        let numericLikeValues = bodyValues.filter { value in
            value.range(
                of: #"^(?:~?\$?)?[0-9]+(?:\.[0-9]+)?(?:[A-Za-z%]+)?$|^--$"#,
                options: .regularExpression
            ) != nil
        }

        return numericLikeValues.count * 2 >= bodyValues.count
    }

    private func codeBlockAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: attributes)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var mermaidPreview: NSAttributedString?

        if let firstLineRange = text.range(of: "\n"),
           isCodeBlockLabel(String(text[..<firstLineRange.lowerBound])) {
            let label = String(text[..<firstLineRange.lowerBound])
            let labelLength = text.distance(from: text.startIndex, to: firstLineRange.lowerBound)
            let labelRange = NSRange(location: 0, length: labelLength)
            attributed.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .backgroundColor: NSColor.clear
                ],
                range: labelRange
            )
            let codeStart = labelRange.upperBound + 1
            if codeStart < nsText.length {
                let codeText = nsText.substring(from: codeStart)
                if label == "Mermaid",
                   let previewImage = mermaidFlowchartPreviewImage(from: codeText) {
                    mermaidPreview = previewAttachmentString(image: previewImage, attributes: attributes)
                }

                applyCodeSyntaxHighlighting(
                    language: label,
                    to: attributed,
                    in: NSRange(location: codeStart, length: nsText.length - codeStart)
                )
            }
        } else {
            applyCodeSyntaxHighlighting(language: nil, to: attributed, in: fullRange)
        }

        if let mermaidPreview {
            let result = NSMutableAttributedString(attributedString: mermaidPreview)
            result.append(NSAttributedString(string: "\n", attributes: attributes))
            result.append(attributed)
            return result
        }

        return attributed
    }

    private func mathBlockAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let latex = mathSourceText(from: text)

        if let previewText = mathPreviewText(from: latex),
           let previewImage = mathPreviewImage(previewText) {
            result.append(previewAttachmentString(image: previewImage, attributes: attributes))
            result.append(NSAttributedString(string: "\n", attributes: attributes))
        }

        result.append(NSAttributedString(string: text, attributes: attributes))
        return result
    }

    private func mathSourceText(from displayText: String) -> String {
        guard displayText.hasPrefix("Formula\n") else {
            return displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(displayText.dropFirst("Formula\n".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mathPreviewText(from latex: String) -> String? {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        var preview = trimmed
        preview = replaceFractions(in: preview)
        preview = preview
            .replacingOccurrences(of: #"\\int_([^\s\^]+)\^([^\s]+)"#, with: "∫_$1^$2", options: .regularExpression)
            .replacingOccurrences(of: #"\\int"#, with: "∫", options: .regularExpression)
            .replacingOccurrences(of: #"\\sum"#, with: "∑", options: .regularExpression)
            .replacingOccurrences(of: #"\\alpha"#, with: "α", options: .regularExpression)
            .replacingOccurrences(of: #"\\beta"#, with: "β", options: .regularExpression)
            .replacingOccurrences(of: #"\\gamma"#, with: "γ", options: .regularExpression)
            .replacingOccurrences(of: #"\\Delta"#, with: "Δ", options: .regularExpression)
            .replacingOccurrences(of: #"\\times"#, with: "×", options: .regularExpression)
            .replacingOccurrences(of: #"\\cdot"#, with: "·", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        preview = replaceScriptMarkers(in: preview, marker: "^", digits: superscriptDigits())
        preview = replaceScriptMarkers(in: preview, marker: "_", digits: subscriptDigits())
        return preview == trimmed ? nil : preview
    }

    private func replaceFractions(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\\frac\{([^{}]+)\}\{([^{}]+)\}"#) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let numerator = nsText.substring(with: match.range(at: 1))
            let denominator = nsText.substring(with: match.range(at: 2))
            mutable.replaceCharacters(in: match.range, with: "\(numerator)⁄\(denominator)")
        }
        return mutable as String
    }

    private func replaceScriptMarkers(
        in text: String,
        marker: Character,
        digits: [Character: Character]
    ) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            guard character == marker else {
                result.append(character)
                index = text.index(after: index)
                continue
            }

            let nextIndex = text.index(after: index)
            guard nextIndex < text.endIndex else {
                result.append(character)
                index = nextIndex
                continue
            }

            let scriptCharacter = text[nextIndex]
            guard let replacement = digits[scriptCharacter] else {
                result.append(character)
                index = nextIndex
                continue
            }

            result.append(replacement)
            index = text.index(after: nextIndex)
        }

        return result
    }

    private func superscriptDigits() -> [Character: Character] {
        [
            "0": "⁰",
            "1": "¹",
            "2": "²",
            "3": "³",
            "4": "⁴",
            "5": "⁵",
            "6": "⁶",
            "7": "⁷",
            "8": "⁸",
            "9": "⁹"
        ]
    }

    private func subscriptDigits() -> [Character: Character] {
        [
            "0": "₀",
            "1": "₁",
            "2": "₂",
            "3": "₃",
            "4": "₄",
            "5": "₅",
            "6": "₆",
            "7": "₇",
            "8": "₈",
            "9": "₉"
        ]
    }

    private func mathPreviewImage(_ previewText: String) -> NSImage? {
        let width: CGFloat = 560
        let height: CGFloat = 104

        return dynamicPreviewImage(size: NSSize(width: width, height: height)) { bounds, palette in
            palette.background.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

            palette.border.setStroke()
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
            border.lineWidth = 1
            border.stroke()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: palette.secondaryText
            ]
            ("Formula preview" as NSString).draw(
                in: NSRect(x: 18, y: bounds.height - 30, width: 160, height: 18),
                withAttributes: titleAttributes
            )

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingMiddle
            let formulaAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 25, weight: .regular),
                .foregroundColor: palette.primaryText,
                .paragraphStyle: paragraph
            ]
            (previewText as NSString).draw(
                in: NSRect(x: 28, y: 28, width: bounds.width - 56, height: 36),
                withAttributes: formulaAttributes
            )
        }
    }

    private func previewAttachmentString(
        image: NSImage,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(origin: .zero, size: image.size)

        let attributed = NSMutableAttributedString(attachment: attachment)
        attributed.addAttributes(attributes, range: NSRange(location: 0, length: attributed.length))
        return attributed
    }

    private func mermaidFlowchartPreviewImage(from code: String) -> NSImage? {
        let graph = parseSimpleMermaidFlowchart(code)
        guard graph.nodes.count >= 2,
              !graph.edges.isEmpty
        else {
            return nil
        }

        let nodeSize = NSSize(width: 112, height: 42)
        let horizontalGap: CGFloat = 36
        let outerInset: CGFloat = 18
        let titleHeight: CGFloat = 28
        let nodeCount = min(graph.nodes.count, 5)
        let contentWidth = CGFloat(nodeCount) * nodeSize.width + CGFloat(max(0, nodeCount - 1)) * horizontalGap
        let width = min(620, max(360, contentWidth + outerInset * 2))
        let height: CGFloat = 132
        return dynamicPreviewImage(size: NSSize(width: width, height: height)) { bounds, palette in
            palette.background.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

            palette.border.setStroke()
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
            border.lineWidth = 1
            border.stroke()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: palette.secondaryText
            ]
            ("Mermaid preview" as NSString).draw(
                in: NSRect(x: outerInset, y: bounds.height - titleHeight, width: 160, height: 18),
                withAttributes: titleAttributes
            )

            let visibleNodes = Array(graph.nodes.prefix(nodeCount))
            let visibleNodeIDs = Set(visibleNodes.map(\.id))
            let startX = (bounds.width - contentWidth) / 2
            let nodeY: CGFloat = 34
            var nodeRects: [String: NSRect] = [:]

            for (index, node) in visibleNodes.enumerated() {
                let rect = NSRect(
                    x: startX + CGFloat(index) * (nodeSize.width + horizontalGap),
                    y: nodeY,
                    width: nodeSize.width,
                    height: nodeSize.height
                )
                nodeRects[node.id] = rect
            }

            for edge in graph.edges where visibleNodeIDs.contains(edge.from) && visibleNodeIDs.contains(edge.to) {
                guard let fromRect = nodeRects[edge.from],
                      let toRect = nodeRects[edge.to]
                else {
                    continue
                }

                drawArrow(
                    from: NSPoint(x: fromRect.maxX + 3, y: fromRect.midY),
                    to: NSPoint(x: toRect.minX - 3, y: toRect.midY),
                    palette: palette
                )
            }

            let nodeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
                .foregroundColor: palette.primaryText,
                .paragraphStyle: centeredParagraphStyle()
            ]

            for node in visibleNodes {
                guard let rect = nodeRects[node.id] else {
                    continue
                }

                palette.nodeBackground.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
                palette.nodeBorder.setStroke()
                let nodeBorder = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
                nodeBorder.lineWidth = 1
                nodeBorder.stroke()

                (node.label as NSString).draw(
                    in: rect.insetBy(dx: 8, dy: 9),
                    withAttributes: nodeAttributes
                )
            }
        }
    }

    private func dynamicPreviewImage(
        size: NSSize,
        drawing: @escaping (NSRect, PreviewPalette) -> Void
    ) -> NSImage {
        NSImage(size: size, flipped: false) { bounds in
            drawing(bounds, PreviewPalette.current)
            return true
        }
    }

    private func centeredParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    private func drawArrow(from start: NSPoint, to end: NSPoint, palette: PreviewPalette) {
        palette.arrow.setStroke()
        palette.arrow.setFill()

        let line = NSBezierPath()
        line.move(to: start)
        line.line(to: end)
        line.lineWidth = 1.4
        line.stroke()

        let arrowSize: CGFloat = 6
        let arrow = NSBezierPath()
        arrow.move(to: end)
        arrow.line(to: NSPoint(x: end.x - arrowSize, y: end.y + arrowSize * 0.55))
        arrow.line(to: NSPoint(x: end.x - arrowSize, y: end.y - arrowSize * 0.55))
        arrow.close()
        arrow.fill()
    }

    private func parseSimpleMermaidFlowchart(_ code: String) -> MermaidFlowchartPreview {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var nodes: [MermaidPreviewNode] = []
        var nodeIndexByID: [String: Int] = [:]
        var edges: [MermaidPreviewEdge] = []

        func addNode(id: String, label: String?) {
            let cleanedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedID.isEmpty else {
                return
            }

            let cleanedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = nodeIndexByID[cleanedID] {
                if let cleanedLabel, !cleanedLabel.isEmpty {
                    nodes[index].label = cleanedLabel
                }
            } else {
                nodeIndexByID[cleanedID] = nodes.count
                nodes.append(MermaidPreviewNode(id: cleanedID, label: cleanedLabel?.isEmpty == false ? cleanedLabel! : cleanedID))
            }
        }

        let endpointPattern = #"([A-Za-z0-9_]+)(?:\[([^\]]+)\])?"#
        let edgePattern = #"^\s*"# + endpointPattern + #"\s*-->\s*"# + endpointPattern + #"\s*$"#
        let regex = try? NSRegularExpression(pattern: edgePattern)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("flowchart"),
                  !trimmed.hasPrefix("graph")
            else {
                continue
            }

            let nsLine = trimmed as NSString
            guard let match = regex?.firstMatch(
                in: trimmed,
                range: NSRange(location: 0, length: nsLine.length)
            ) else {
                continue
            }

            let fromID = nsLine.substring(with: match.range(at: 1))
            let fromLabel = match.range(at: 2).location == NSNotFound ? nil : nsLine.substring(with: match.range(at: 2))
            let toID = nsLine.substring(with: match.range(at: 3))
            let toLabel = match.range(at: 4).location == NSNotFound ? nil : nsLine.substring(with: match.range(at: 4))
            addNode(id: fromID, label: fromLabel)
            addNode(id: toID, label: toLabel)
            edges.append(MermaidPreviewEdge(from: fromID, to: toID))
        }

        return MermaidFlowchartPreview(nodes: nodes, edges: edges)
    }

    private func imageAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        localImageURL: URL?
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if let localImageURL,
           let image = NSImage(contentsOf: localImageURL),
           let thumbnail = thumbnailImage(from: image) {
            let attachment = NSTextAttachment()
            attachment.image = thumbnail
            attachment.bounds = NSRect(origin: .zero, size: thumbnail.size)

            let attachmentString = NSMutableAttributedString(attachment: attachment)
            attachmentString.addAttributes(attributes, range: NSRange(location: 0, length: attachmentString.length))
            result.append(attachmentString)
            result.append(NSAttributedString(string: "\n", attributes: attributes))
        }

        result.append(NSAttributedString(string: text, attributes: attributes))
        return result
    }

    private func thumbnailImage(
        from image: NSImage,
        preferredSize: ObsidianEmbedImageSize? = nil
    ) -> NSImage? {
        let sourceSize = usableImageSize(for: image)
        guard sourceSize.width > 0,
              sourceSize.height > 0
        else {
            return nil
        }

        let scale: CGFloat
        if let preferredSize {
            let widthScale = preferredSize.width.map { $0 / sourceSize.width }
            let heightScale = preferredSize.height.map { $0 / sourceSize.height }
            scale = [
                widthScale,
                heightScale
            ]
            .compactMap { $0 }
            .min() ?? 1
        } else {
            let maxSize = NSSize(width: 520, height: 260)
            scale = min(1, maxSize.width / sourceSize.width, maxSize.height / sourceSize.height)
        }
        let targetSize = NSSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )
        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1
        )
        thumbnail.unlockFocus()
        return thumbnail
    }

    private func usableImageSize(for image: NSImage) -> NSSize {
        if image.size.width > 0,
           image.size.height > 0 {
            return image.size
        }

        guard let representation = image.representations.first,
              representation.pixelsWide > 0,
              representation.pixelsHigh > 0
        else {
            return .zero
        }

        return NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }

    private func labeledFallbackBlockAttributedString(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        label: String
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: attributes)
        guard text.hasPrefix(label),
              attributed.length >= label.count
        else {
            return attributed
        }

        attributed.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
                .backgroundColor: NSColor.clear
            ],
            range: NSRange(location: 0, length: label.count)
        )
        return attributed
    }

    private func isCodeBlockLabel(_ label: String) -> Bool {
        [
            "Bash", "CSS", "Code", "Diff", "HTML", "JavaScript", "JSON", "Markdown", "Mermaid",
            "Python", "Shell", "Swift", "TypeScript", "YAML"
        ].contains(label)
    }

    private func applyCodeSyntaxHighlighting(
        language: String?,
        to attributed: NSMutableAttributedString,
        in range: NSRange
    ) {
        let text = attributed.string as NSString
        let normalizedLanguage = language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let commentColor = NSColor.secondaryLabelColor
        let deletedColor = NSColor.systemRed
        let keyColor = NSColor.systemBlue
        let keywordColor = NSColor.systemPurple
        let numberColor = NSColor.systemOrange
        let stringColor = NSColor.systemGreen

        switch normalizedLanguage {
        case "diff", "patch":
            applyCodePattern(#"(?m)^@@.*$"#, color: keyColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"(?m)^\+.*$"#, color: stringColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"(?m)^-.*$"#, color: deletedColor, text: text, attributed: attributed, range: range)

        case "json":
            applyCodePattern(#"\b\d+(?:\.\d+)?\b"#, color: numberColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"\b(true|false|null)\b"#, color: keywordColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#""(?:\\.|[^"\\])*""#, color: stringColor, text: text, attributed: attributed, range: range)
            applyCodeCapturePattern(#"(?m)"((?:\\.|[^"\\])*)"\s*:"#, color: keyColor, text: text, attributed: attributed, range: range)

        case "yaml", "yml":
            applyCodePattern(#"\b\d+(?:\.\d+)?\b"#, color: numberColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"\b(true|false|null|yes|no|on|off)\b"#, color: keywordColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, color: stringColor, text: text, attributed: attributed, range: range)
            applyCodeCapturePattern(#"(?m)^\s*-?\s*([A-Za-z_][A-Za-z0-9_.-]*)(?=\s*:)"#, color: keyColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"(?m)#.*$"#, color: commentColor, text: text, attributed: attributed, range: range)

        case "bash", "shell", "sh":
            applyCodePattern(#"\b\d+(?:\.\d+)?\b"#, color: numberColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|export|local|return|echo|cd)\b"#, color: keywordColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"\$[A-Za-z_][A-Za-z0-9_]*"#, color: keyColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, color: stringColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"(?m)#.*$"#, color: commentColor, text: text, attributed: attributed, range: range)

        case "mermaid":
            applyCodePattern(#"\b(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram|erDiagram|journey|gantt|pie|TD|TB|BT|LR|RL|subgraph|end)\b"#, color: keywordColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"(?m)%%.*$"#, color: commentColor, text: text, attributed: attributed, range: range)

        default:
            applyCodePattern(#"\b\d+(?:\.\d+)?\b"#, color: numberColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"\b(true|false|null|nil|let|var|func|struct|class|enum|protocol|extension|import|return|if|else|for|while|guard|switch|case|break|continue|async|await|throws|try|public|private|internal|static|const|function|def|from|interface|type|export|default)\b"#, color: keywordColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, color: stringColor, text: text, attributed: attributed, range: range)
            applyCodePattern(#"(?m)//.*$|#.*$"#, color: commentColor, text: text, attributed: attributed, range: range)
        }
    }

    private func applyCodePattern(
        _ pattern: String,
        color: NSColor,
        text: NSString,
        attributed: NSMutableAttributedString,
        range: NSRange
    ) {
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: text as String,
            range: range
        ) ?? []

        for match in matches {
            attributed.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }

    private func applyCodeCapturePattern(
        _ pattern: String,
        captureGroup: Int = 1,
        color: NSColor,
        text: NSString,
        attributed: NSMutableAttributedString,
        range: NSRange
    ) {
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: text as String,
            range: range
        ) ?? []

        for match in matches {
            guard match.numberOfRanges > captureGroup else {
                continue
            }

            let captureRange = match.range(at: captureGroup)
            guard captureRange.location != NSNotFound,
                  captureRange.length > 0
            else {
                continue
            }

            attributed.addAttribute(.foregroundColor, value: color, range: captureRange)
        }
    }

    private func inlineStyledAttributedString(
        markdown: String,
        baseAttributes: [NSAttributedString.Key: Any],
        footnoteOrdinals: [String: Int] = [:],
        footnoteDefinitions: [String: String] = [:],
        abbreviations: [String: String] = [:],
        linkReferences: [String: LinkReferenceDefinition] = [:],
        baseURL: URL? = nil
    ) -> NSAttributedString {
        let displayText = stripInlineMarkdown(
            markdown,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences
        )
        let attributed = NSMutableAttributedString(string: displayText, attributes: baseAttributes)
        let baseFont = baseAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 16)

        applyInlineStyle(
            pattern: #"(?<!\\)`([^`\n]+)(?<!\\)`"#,
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed,
            preserveInnerMarkdown: true
        ) { innerText in
            [
                .font: NSFont.monospacedSystemFont(ofSize: max(12, baseFont.pointSize - 1), weight: .regular),
                .foregroundColor: inlineCodeForegroundColor(),
                .backgroundColor: inlineCodeBackgroundColor()
            ]
        }

        applyInlineStyle(
            pattern: #"(?<!\\)(\*\*|__)(.+?)(?<!\\)\1"#,
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            [.font: NSFont.boldSystemFont(ofSize: baseFont.pointSize)]
        }

        applyInlineStyle(
            pattern: #"(?<![\\*])\*([^*\s][^*\n]{0,160}?)(?<!\\)\*(?!\*)|(?<![A-Za-z0-9_\\])_([^_\s][^_\n]{0,160}?)(?<!\\)_(?![A-Za-z0-9_])"#,
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            return [.font: italicFont]
        }

        applyInlineStyle(
            pattern: #"(?<!\\)~~(.+?)(?<!\\)~~"#,
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        applyInlineStyle(
            pattern: inlineMarkPattern(),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            [
                .backgroundColor: markInlineBackgroundColor()
            ]
        }

        applyInlineStyle(
            pattern: inlineInsertedPattern(),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            [
                .foregroundColor: insertedInlineForegroundColor(),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: insertedInlineUnderlineColor()
            ]
        }

        applyInlineStyle(
            pattern: inlineHTMLTagPattern("kbd", maximumLength: 80),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed,
            options: [.caseInsensitive]
        ) { _ in
            [
                .font: NSFont.monospacedSystemFont(ofSize: max(12, baseFont.pointSize - 1), weight: .medium),
                .foregroundColor: inlineCodeForegroundColor(),
                .backgroundColor: inlineCodeBackgroundColor()
            ]
        }

        applyInlineStyle(
            pattern: inlineHTMLTagPattern("mark"),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed,
            options: [.caseInsensitive]
        ) { _ in
            [
                .backgroundColor: markInlineBackgroundColor()
            ]
        }

        for tagName in ["ins", "u"] {
            applyInlineStyle(
                pattern: inlineHTMLTagPattern(tagName),
                markdown: markdown,
                displayText: displayText,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences,
                to: attributed,
                options: [.caseInsensitive]
            ) { _ in
                [
                    .foregroundColor: insertedInlineForegroundColor(),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: insertedInlineUnderlineColor()
                ]
            }
        }

        for tagName in ["del", "s"] {
            applyInlineStyle(
                pattern: inlineHTMLTagPattern(tagName),
                markdown: markdown,
                displayText: displayText,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences,
                to: attributed,
                options: [.caseInsensitive]
            ) { _ in
                [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            }
        }

        applyInlineStyle(
            pattern: inlineHTMLTagPattern("sup", maximumLength: 80),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed,
            options: [.caseInsensitive]
        ) { _ in
            [
                .font: NSFont.systemFont(ofSize: max(10.5, baseFont.pointSize - 3), weight: .medium),
                .baselineOffset: max(3, baseFont.pointSize * 0.34),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        applyInlineStyle(
            pattern: inlineHTMLTagPattern("sub", maximumLength: 80),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed,
            options: [.caseInsensitive]
        ) { _ in
            [
                .font: NSFont.systemFont(ofSize: max(10.5, baseFont.pointSize - 3), weight: .medium),
                .baselineOffset: -max(1.8, baseFont.pointSize * 0.18),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        applyInlineStyle(
            pattern: inlineHTMLTagPattern("small"),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed,
            options: [.caseInsensitive]
        ) { _ in
            [
                .font: NSFont.systemFont(ofSize: max(11, baseFont.pointSize - 2), weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        applyInlineStyle(
            pattern: inlineMathPattern(),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            [
                .font: NSFont.monospacedSystemFont(ofSize: max(12, baseFont.pointSize - 0.5), weight: .regular),
                .foregroundColor: mathInlineForegroundColor(),
                .backgroundColor: mathInlineBackgroundColor()
            ]
        }

        applyInlineStyle(
            pattern: inlineSuperscriptPattern(),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            [
                .font: NSFont.systemFont(ofSize: max(10.5, baseFont.pointSize - 3), weight: .medium),
                .baselineOffset: max(3, baseFont.pointSize * 0.34),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        applyInlineStyle(
            pattern: inlineSubscriptPattern(),
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        ) { _ in
            [
                .font: NSFont.systemFont(ofSize: max(10.5, baseFont.pointSize - 3), weight: .medium),
                .baselineOffset: -max(1.8, baseFont.pointSize * 0.18),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        }

        applyFootnoteReferenceStyle(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            footnoteDefinitions: footnoteDefinitions,
            to: attributed
        )
        applyInlineFootnoteReferenceStyle(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        )
        applyAbbreviationStyle(abbreviations: abbreviations, displayText: displayText, to: attributed)
        applyAutolinkStyle(markdown: markdown, displayText: displayText, to: attributed)
        applyLinkStyle(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        )
        applyReferenceLinkStyle(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        )
        applyHTMLLinkStyle(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        )
        applyObsidianWikilinkStyle(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        )
        applyObsidianEmbedStyle(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            to: attributed
        )
        applyBareURLStyle(displayText: displayText, to: attributed)
        applyObsidianTagStyle(displayText: displayText, to: attributed)
        insertObsidianEmbedPreviews(
            markdown: markdown,
            displayText: displayText,
            footnoteOrdinals: footnoteOrdinals,
            linkReferences: linkReferences,
            baseURL: baseURL,
            attributes: baseAttributes,
            into: attributed
        )
        return attributed
    }

    private func applyAbbreviationStyle(
        abbreviations: [String: String],
        displayText: String,
        to attributed: NSMutableAttributedString
    ) {
        guard !abbreviations.isEmpty else {
            return
        }

        let nsDisplay = displayText as NSString
        let fullRange = NSRange(location: 0, length: nsDisplay.length)
        let sortedAbbreviations = abbreviations.sorted { lhs, rhs in
            lhs.key.count > rhs.key.count
        }

        for (term, definition) in sortedAbbreviations {
            let escapedTerm = NSRegularExpression.escapedPattern(for: term)
            let pattern = #"(?<![A-Za-z0-9_])"# + escapedTerm + #"(?![A-Za-z0-9_])"#
            let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
                in: displayText,
                range: fullRange
            ) ?? []

            for match in matches {
                guard !hasFixedPitchFont(in: attributed, at: match.range.location) else {
                    continue
                }
                attributed.addAttributes(
                    [
                        .toolTip: definition,
                        .underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue,
                        .underlineColor: NSColor.tertiaryLabelColor
                    ],
                    range: match.range
                )
            }
        }
    }

    private func mathInlineForegroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.97, alpha: 1)
            }
            return NSColor(calibratedRed: 0.17, green: 0.19, blue: 0.27, alpha: 1)
        }
    }

    private func mathInlineBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.25, alpha: 1)
            }
            return NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.98, alpha: 1)
        }
    }

    private func markInlineBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedRed: 0.42, green: 0.34, blue: 0.10, alpha: 0.72)
            }
            return NSColor(calibratedRed: 1.00, green: 0.90, blue: 0.34, alpha: 0.55)
        }
    }

    private func insertedInlineForegroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedRed: 0.64, green: 0.88, blue: 0.66, alpha: 1)
            }
            return NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.17, alpha: 1)
        }
    }

    private func insertedInlineUnderlineColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedRed: 0.44, green: 0.74, blue: 0.47, alpha: 1)
            }
            return NSColor(calibratedRed: 0.21, green: 0.58, blue: 0.25, alpha: 1)
        }
    }

    private func applyInlineStyle(
        pattern: String,
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition] = [:],
        to attributed: NSMutableAttributedString,
        options: NSRegularExpression.Options = [],
        preserveInnerMarkdown: Bool = false,
        attributes: (String) -> [NSAttributedString.Key: Any]
    ) {
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern, options: options))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        var searchLocation = 0
        let nsDisplay = displayText as NSString

        for match in matches {
            let captureRange = (1..<match.numberOfRanges)
                .map { match.range(at: $0) }
                .reversed()
                .first { $0.location != NSNotFound && $0.length > 0 }

            guard let captureRange else {
                continue
            }

            let innerText = nsMarkdown.substring(with: captureRange)
            let displayInnerText = preserveInnerMarkdown
                ? innerText
                : stripInlineMarkdown(
                    innerText,
                    footnoteOrdinals: footnoteOrdinals,
                    linkReferences: linkReferences
                )
            let displayLocation = (stripInlineMarkdown(
                nsMarkdown.substring(to: match.range.location),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ) as NSString).length
            let displayRange = NSRange(location: displayLocation, length: (displayInnerText as NSString).length)

            guard displayRange.location >= searchLocation,
                  displayRange.upperBound <= nsDisplay.length,
                  nsDisplay.substring(with: displayRange) == displayInnerText
            else {
                continue
            }

            attributed.addAttributes(attributes(innerText), range: displayRange)
            searchLocation = displayRange.location + displayRange.length
        }
    }

    private func inlineCodeForegroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedRed: 0.86, green: 0.89, blue: 0.94, alpha: 1)
            }
            return NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.23, alpha: 1)
        }
    }

    private func inlineCodeBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedWhite: 0.20, alpha: 1)
            }
            return NSColor(calibratedWhite: 0.92, alpha: 1)
        }
    }

    private func applyLinkStyle(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition],
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"(?<!!)(?<!\\)\[([^\]]+)\]\(([^)]+)\)"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            let labelRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            guard labelRange.location != NSNotFound,
                  urlRange.location != NSNotFound
            else {
                continue
            }

            let label = nsMarkdown.substring(with: labelRange)
            let url = nsMarkdown.substring(with: urlRange)
            let displayLabel = stripInlineMarkdown(
                label,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            )
            let displayLocation = (stripInlineMarkdown(
                nsMarkdown.substring(to: match.range.location),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ) as NSString).length
            let displayRange = NSRange(location: displayLocation, length: (displayLabel as NSString).length)

            guard displayRange.location >= searchLocation,
                  displayRange.upperBound <= nsDisplay.length
            else {
                continue
            }

            attributed.addAttributes(linkAttributes(url: url), range: displayRange)
            searchLocation = displayRange.upperBound
        }
    }

    private func applyReferenceLinkStyle(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition],
        to attributed: NSMutableAttributedString
    ) {
        guard !linkReferences.isEmpty else {
            return
        }

        let pattern = #"(?<!!)(?<!\\)\[([^\]\n]+)\]\[([^\]\n]*)\]"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            let labelRange = match.range(at: 1)
            let referenceRange = match.range(at: 2)
            guard labelRange.location != NSNotFound,
                  referenceRange.location != NSNotFound
            else {
                continue
            }

            let label = nsMarkdown.substring(with: labelRange)
            let referenceLabel = nsMarkdown.substring(with: referenceRange)
            guard let reference = resolveLinkReference(
                label: label,
                referenceLabel: referenceLabel,
                linkReferences: linkReferences
            ) else {
                continue
            }

            let displayLabel = stripInlineMarkdown(
                label,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            )
            let displayLocation = (stripInlineMarkdown(
                nsMarkdown.substring(to: match.range.location),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ) as NSString).length
            let displayRange = NSRange(location: displayLocation, length: (displayLabel as NSString).length)

            guard displayRange.location >= searchLocation,
                  displayRange.upperBound <= nsDisplay.length
            else {
                continue
            }

            attributed.addAttributes(linkAttributes(url: reference.destination, title: reference.title), range: displayRange)
            searchLocation = displayRange.upperBound
        }
    }

    private func applyHTMLLinkStyle(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition],
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"<a\b([^>]*)>(.*?)</a>"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            guard match.numberOfRanges >= 3 else {
                continue
            }

            let attributeText = nsMarkdown.substring(with: match.range(at: 1))
            guard let href = htmlAttribute("href", in: attributeText),
                  !href.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }

            let rawLabel = nsMarkdown.substring(with: match.range(at: 2))
            let label = htmlInlineText(rawLabel).trimmingCharacters(in: .whitespacesAndNewlines)
            let effectiveLabel = label.isEmpty ? href : label
            let displayLabel = stripInlineMarkdown(
                effectiveLabel,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            )
            let displayLocation = (stripInlineMarkdown(
                nsMarkdown.substring(to: match.range.location),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ) as NSString).length
            let displayRange = NSRange(location: displayLocation, length: (displayLabel as NSString).length)

            guard displayRange.location >= searchLocation,
                  displayRange.upperBound <= nsDisplay.length
            else {
                continue
            }

            attributed.addAttributes(
                linkAttributes(url: href, title: htmlAttribute("title", in: attributeText)),
                range: displayRange
            )
            searchLocation = displayRange.upperBound
        }
    }

    private func applyObsidianWikilinkStyle(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition],
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"(?<!!)(?<!\\)\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            let targetRange = match.range(at: 1)
            guard targetRange.location != NSNotFound else {
                continue
            }

            let target = nsMarkdown.substring(with: targetRange)
            let aliasRange = match.range(at: 2)
            let rawLabel = aliasRange.location == NSNotFound ? obsidianDisplayTitle(from: target) : nsMarkdown.substring(with: aliasRange)
            let displayLabel = stripInlineMarkdown(
                rawLabel,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            )
            let displayLocation = (stripInlineMarkdown(
                nsMarkdown.substring(to: match.range.location),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ) as NSString).length
            let displayRange = NSRange(location: displayLocation, length: (displayLabel as NSString).length)

            guard displayRange.location >= searchLocation,
                  displayRange.upperBound <= nsDisplay.length
            else {
                continue
            }

            attributed.addAttributes(obsidianLinkAttributes(target: target), range: displayRange)
            searchLocation = displayRange.upperBound
        }
    }

    private func applyObsidianEmbedStyle(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition],
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"(?<!\\)!\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            let targetRange = match.range(at: 1)
            guard targetRange.location != NSNotFound else {
                continue
            }

            let target = nsMarkdown.substring(with: targetRange)
            let displayPlaceholder = stripInlineMarkdown(
                nsMarkdown.substring(with: match.range),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            )
            let displayLocation = (stripInlineMarkdown(
                nsMarkdown.substring(to: match.range.location),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ) as NSString).length
            let displayRange = NSRange(location: displayLocation, length: (displayPlaceholder as NSString).length)

            guard displayRange.location >= searchLocation,
                  displayRange.upperBound <= nsDisplay.length
            else {
                continue
            }

            attributed.addAttributes(obsidianEmbedAttributes(target: target), range: displayRange)
            searchLocation = displayRange.upperBound
        }
    }

    private func insertObsidianEmbedPreviews(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition],
        baseURL: URL?,
        attributes: [NSAttributedString.Key: Any],
        into attributed: NSMutableAttributedString
    ) {
        guard baseURL != nil else {
            return
        }

        let pattern = #"(?<!\\)!\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var edits: [(range: NSRange, replacement: NSAttributedString)] = []
        var searchLocation = 0

        for match in matches {
            let target = nsMarkdown.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let aliasRange = match.range(at: 2)
            let alias = aliasRange.location == NSNotFound ? nil : nsMarkdown.substring(with: aliasRange)
            guard let localImageURL = localImageURL(for: target, baseURL: baseURL),
                  let image = NSImage(contentsOf: localImageURL),
                  let thumbnail = thumbnailImage(from: image, preferredSize: obsidianEmbedImageSize(from: alias))
            else {
                continue
            }

            let displayPlaceholder = stripInlineMarkdown(
                nsMarkdown.substring(with: match.range),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            )
            let displayLocation = (stripInlineMarkdown(
                nsMarkdown.substring(to: match.range.location),
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            ) as NSString).length
            let displayRange = NSRange(location: displayLocation, length: (displayPlaceholder as NSString).length)

            guard displayRange.location >= searchLocation,
                  displayRange.upperBound <= nsDisplay.length
            else {
                continue
            }

            let preview = obsidianEmbedPreviewAttributedString(thumbnail: thumbnail, attributes: attributes)
            let fallbackText = obsidianLocalImageEmbedFallbackText(target: target, localImageURL: localImageURL)
            edits.append((
                displayRange,
                obsidianLocalImageEmbedFallbackAttributedString(
                    text: fallbackText,
                    target: target,
                    attributes: attributes
                )
            ))
            if let leadingWhitespaceRange = horizontalWhitespaceRangeBeforeObsidianEmbedPreview(
                displayLocation: displayRange.location,
                displayText: nsDisplay
            ) {
                let replacement = NSMutableAttributedString(string: "\n", attributes: attributes)
                replacement.append(preview)
                edits.append((leadingWhitespaceRange, replacement))
            } else {
                let replacement = NSMutableAttributedString()
                if needsLineBreakBeforeObsidianEmbedPreview(
                    displayLocation: displayRange.location,
                    displayText: nsDisplay
                ) {
                    replacement.append(NSAttributedString(string: "\n", attributes: attributes))
                }
                replacement.append(preview)
                edits.append((
                    NSRange(location: displayRange.location, length: 0),
                    replacement
                ))
            }
            if let lineBreakEdit = lineBreakAfterObsidianEmbedFallbackEdit(
                displayRange: displayRange,
                displayText: nsDisplay,
                attributes: attributes
            ) {
                edits.append(lineBreakEdit)
            }
            searchLocation = displayRange.upperBound
        }

        for edit in edits.sorted(by: { lhs, rhs in
            if lhs.range.location == rhs.range.location {
                return lhs.range.length > rhs.range.length
            }
            return lhs.range.location > rhs.range.location
        }) {
            attributed.replaceCharacters(in: edit.range, with: edit.replacement)
        }
    }

    private func obsidianLocalImageEmbedFallbackText(target: String, localImageURL: URL) -> String {
        let filename = localImageURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = filename.isEmpty ? obsidianDisplayTitle(from: target) : filename
        return fallbackName.isEmpty ? "Embed" : "Embed: \(fallbackName)"
    }

    private func obsidianLocalImageEmbedFallbackAttributedString(
        text: String,
        target: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        var fallbackAttributes = attributes
        for (key, value) in obsidianEmbedAttributes() {
            fallbackAttributes[key] = value
        }
        fallbackAttributes[.toolTip] = target.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSAttributedString(string: text, attributes: fallbackAttributes)
    }

    private func obsidianEmbedPreviewAttributedString(
        thumbnail: NSImage,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = thumbnail
        attachment.bounds = NSRect(origin: .zero, size: thumbnail.size)

        let result = NSMutableAttributedString()
        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.addAttributes(attributes, range: NSRange(location: 0, length: attachmentString.length))
        result.append(attachmentString)
        result.append(NSAttributedString(string: "\n", attributes: attributes))
        return result
    }

    private func needsLineBreakBeforeObsidianEmbedPreview(
        displayLocation: Int,
        displayText: NSString
    ) -> Bool {
        guard displayLocation > 0 else {
            return false
        }

        let previousCharacter = displayText.character(at: displayLocation - 1)
        return previousCharacter != 10
            && previousCharacter != 13
    }

    private func horizontalWhitespaceRangeBeforeObsidianEmbedPreview(
        displayLocation: Int,
        displayText: NSString
    ) -> NSRange? {
        guard displayLocation > 0 else {
            return nil
        }

        var start = displayLocation
        while start > 0 {
            let previousCharacter = displayText.character(at: start - 1)
            guard isHorizontalWhitespace(previousCharacter) else {
                break
            }
            start -= 1
        }

        guard start < displayLocation else {
            return nil
        }

        return NSRange(location: start, length: displayLocation - start)
    }

    private func lineBreakAfterObsidianEmbedFallbackEdit(
        displayRange: NSRange,
        displayText: NSString,
        attributes: [NSAttributedString.Key: Any]
    ) -> (range: NSRange, replacement: NSAttributedString)? {
        let replacementStart = displayRange.upperBound
        var scan = replacementStart
        guard scan < displayText.length,
              !isLineBreak(displayText.character(at: scan))
        else {
            return nil
        }

        while scan < displayText.length,
              isHorizontalWhitespace(displayText.character(at: scan)) {
            scan += 1
        }

        guard scan < displayText.length,
              !isLineBreak(displayText.character(at: scan))
        else {
            return nil
        }

        if isObsidianEmbedTrailingPunctuation(displayText.character(at: scan)) {
            let punctuationRange = NSRange(location: scan, length: 1)
            let punctuation = displayText.substring(with: punctuationRange)
            scan += 1
            while scan < displayText.length,
                  isHorizontalWhitespace(displayText.character(at: scan)) {
                scan += 1
            }

            guard scan < displayText.length,
                  !isLineBreak(displayText.character(at: scan))
            else {
                return nil
            }

            return (
                NSRange(location: replacementStart, length: scan - replacementStart),
                NSAttributedString(string: "\(punctuation)\n", attributes: attributes)
            )
        }

        if scan > replacementStart {
            return (
                NSRange(location: replacementStart, length: scan - replacementStart),
                NSAttributedString(string: "\n", attributes: attributes)
            )
        }

        return (
            NSRange(location: replacementStart, length: 0),
            NSAttributedString(string: "\n", attributes: attributes)
        )
    }

    private func isHorizontalWhitespace(_ character: unichar) -> Bool {
        character == 9 || character == 32 || character == 0x00A0
    }

    private func isLineBreak(_ character: unichar) -> Bool {
        character == 10 || character == 13
    }

    private func isObsidianEmbedTrailingPunctuation(_ character: unichar) -> Bool {
        switch character {
        case 33, 44, 46, 58, 59, 63,
             0x3002, 0xFF01, 0xFF0C, 0xFF1A, 0xFF1B, 0xFF1F:
            return true
        default:
            return false
        }
    }

    private func applyObsidianTagStyle(
        displayText: String,
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"(?<![A-Za-z0-9_/#])#[\p{L}_][\p{L}\p{N}_/-]*"#
        let nsDisplay = displayText as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: displayText,
            range: NSRange(location: 0, length: nsDisplay.length)
        ) ?? []

        for match in matches {
            guard !hasFixedPitchFont(in: attributed, at: match.range.location) else {
                continue
            }
            attributed.addAttributes(obsidianTagAttributes(), range: match.range)
        }
    }

    private func hasFixedPitchFont(in attributed: NSAttributedString, at location: Int) -> Bool {
        guard location >= 0,
              location < attributed.length,
              let font = attributed.attribute(.font, at: location, effectiveRange: nil) as? NSFont
        else {
            return false
        }

        return NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask)
    }

    private func linkAttributes(url: String, title: String? = nil) -> [NSAttributedString.Key: Any] {
        if let obsidianTarget = obsidianMarkdownLinkTarget(from: url) {
            return obsidianLinkAttributes(target: obsidianTarget)
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: url
        ]
        if let title {
            attributes[.toolTip] = title
        }
        return attributes
    }

    private func obsidianMarkdownLinkTarget(from rawURL: String) -> String? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let destination = markdownLinkDestination(from: trimmed)
        guard !destination.isEmpty,
              !hasExplicitURLScheme(destination)
        else {
            return nil
        }

        let decoded = destination.removingPercentEncoding ?? destination
        let normalized = decoded
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.hasPrefix("#") {
            return normalized
        }

        let parts = normalized.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawPath = parts.first else {
            return nil
        }

        var path = String(rawPath).trimmingCharacters(in: .whitespacesAndNewlines)
        while path.hasPrefix("./") {
            path.removeFirst(2)
        }

        let fileExtension = (path as NSString).pathExtension.lowercased()
        guard fileExtension.isEmpty || fileExtension == "md" else {
            return nil
        }

        let notePath = fileExtension == "md" ? String(path.dropLast(3)) : path
        guard !notePath.isEmpty else {
            return nil
        }

        if parts.count > 1 {
            return "\(notePath)#\(parts[1])"
        }
        return notePath
    }

    private func markdownLinkDestination(from rawURL: String) -> String {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<"),
           let closingIndex = trimmed.firstIndex(of: ">") {
            let startIndex = trimmed.index(after: trimmed.startIndex)
            return String(trimmed[startIndex..<closingIndex])
        }

        if let whitespaceIndex = trimmed.firstIndex(where: { $0.isWhitespace }) {
            return String(trimmed[..<whitespaceIndex])
        }
        return trimmed
    }

    private func hasExplicitURLScheme(_ destination: String) -> Bool {
        destination.range(
            of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#,
            options: .regularExpression
        ) != nil
    }

    private func obsidianLinkAttributes(target: String) -> [NSAttributedString.Key: Any] {
        let decodedTarget = decodedObsidianTarget(from: target)
        return [
            .foregroundColor: NSColor.systemPurple,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: obsidianInternalURL(for: decodedTarget),
            .toolTip: decodedTarget
        ]
    }

    private func obsidianInternalURL(for target: String) -> String {
        "obsidian://\(target.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "%20"))"
    }

    private func obsidianTagAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 13.2, weight: .medium),
            .foregroundColor: NSColor.systemPurple,
            .backgroundColor: obsidianTokenBackgroundColor()
        ]
    }

    private func obsidianEmbedAttributes(target: String? = nil) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.2, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .backgroundColor: obsidianTokenBackgroundColor()
        ]
        if let target,
           !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes[.toolTip] = decodedObsidianTarget(from: target)
        }
        return attributes
    }

    private func obsidianTokenBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor.systemPurple.withAlphaComponent(0.22)
            }
            return NSColor.systemPurple.withAlphaComponent(0.12)
        }
    }

    private func applyAutolinkStyle(
        markdown: String,
        displayText: String,
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"<(https?://[^>\s]+)>"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            let urlRange = match.range(at: 1)
            guard urlRange.location != NSNotFound else {
                continue
            }

            let url = nsMarkdown.substring(with: urlRange)
            let displayRange = nsDisplay.range(
                of: url,
                range: NSRange(location: searchLocation, length: nsDisplay.length - searchLocation)
            )

            guard displayRange.location != NSNotFound else {
                continue
            }

            guard !hasFixedPitchFont(in: attributed, at: displayRange.location) else {
                continue
            }

            attributed.addAttributes(
                [
                    .foregroundColor: NSColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: url
                ],
                range: displayRange
            )
            searchLocation = displayRange.location + displayRange.length
        }
    }

    private func applyBareURLStyle(
        displayText: String,
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"https?://[^\s<>)\]]+"#
        let nsDisplay = displayText as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: displayText,
            range: NSRange(location: 0, length: nsDisplay.length)
        ) ?? []

        for match in matches {
            let linkRange = bareURLLinkRange(from: match.range, in: nsDisplay)
            guard linkRange.length > 0 else {
                continue
            }

            let url = nsDisplay.substring(with: linkRange)
            guard attributed.attribute(.link, at: linkRange.location, effectiveRange: nil) == nil,
                  !hasFixedPitchFont(in: attributed, at: linkRange.location)
            else {
                continue
            }
            attributed.addAttributes(
                [
                    .foregroundColor: NSColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: url
                ],
                range: linkRange
            )
        }
    }

    private func bareURLLinkRange(from range: NSRange, in text: NSString) -> NSRange {
        var length = range.length
        while length > 0 {
            let character = text.character(at: range.location + length - 1)
            guard isTrailingBareURLPunctuation(character) else {
                break
            }
            length -= 1
        }
        return NSRange(location: range.location, length: length)
    }

    private func isTrailingBareURLPunctuation(_ character: unichar) -> Bool {
        switch character {
        case 33, 44, 46, 58, 59, 63:
            return true
        default:
            return false
        }
    }

    private func applyFootnoteReferenceStyle(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        footnoteDefinitions: [String: String],
        to attributed: NSMutableAttributedString
    ) {
        let pattern = #"\[\^([^\]]+)\]"#
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: pattern))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            let identifier = nsMarkdown.substring(with: match.range(at: 1))
            let label = footnoteReferenceLabel(identifier: identifier, footnoteOrdinals: footnoteOrdinals)
            let displayRange = nsDisplay.range(
                of: label,
                range: NSRange(location: searchLocation, length: nsDisplay.length - searchLocation)
            )

            guard displayRange.location != NSNotFound else {
                continue
            }

            attributed.addAttributes(
                footnoteReferenceAttributes(tooltip: footnoteDefinitions[identifier]),
                range: displayRange
            )
            searchLocation = displayRange.location + displayRange.length
        }
    }

    private func applyInlineFootnoteReferenceStyle(
        markdown: String,
        displayText: String,
        footnoteOrdinals: [String: Int],
        linkReferences: [String: LinkReferenceDefinition],
        to attributed: NSMutableAttributedString
    ) {
        let nsMarkdown = markdown as NSString
        let matches = (try? NSRegularExpression(pattern: inlineFootnotePattern()))?.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        ) ?? []
        let nsDisplay = displayText as NSString
        var searchLocation = 0

        for match in matches {
            let rawFootnote = nsMarkdown.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let identifier = inlineFootnoteIdentifier(text: rawFootnote)
            let label = footnoteReferenceLabel(identifier: identifier, footnoteOrdinals: footnoteOrdinals)
            let displayRange = nsDisplay.range(
                of: label,
                range: NSRange(location: searchLocation, length: nsDisplay.length - searchLocation)
            )

            guard displayRange.location != NSNotFound else {
                continue
            }

            let tooltip = stripInlineMarkdown(
                rawFootnote,
                footnoteOrdinals: footnoteOrdinals,
                linkReferences: linkReferences
            )
            attributed.addAttributes(
                footnoteReferenceAttributes(tooltip: tooltip),
                range: displayRange
            )
            searchLocation = displayRange.location + displayRange.length
        }
    }

    private func footnoteReferenceAttributes(tooltip: String? = nil) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.systemBlue,
            .baselineOffset: 4,
            .underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue,
            .underlineColor: NSColor.tertiaryLabelColor
        ]
        if let tooltip,
           !tooltip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes[.toolTip] = tooltip
        }
        return attributes
    }

    private func bodyAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5.5
        paragraph.paragraphSpacing = 13
        paragraph.minimumLineHeight = 24
        return [
            .font: NSFont.systemFont(ofSize: 16.2),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func blockParagraphStyle(
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat,
        padding: CGFloat = 8,
        borderWidth: CGFloat = 0.5
    ) -> NSMutableParagraphStyle {
        let block = NSTextBlock()
        block.setValue(100, type: .percentageValueType, for: .width)
        block.setWidth(borderWidth, type: .absoluteValueType, for: .border)
        block.setWidth(padding, type: .absoluteValueType, for: .padding)
        block.setWidth(0, type: .absoluteValueType, for: .margin)
        block.setBorderColor(NSColor.separatorColor)
        block.backgroundColor = readerBlockBackgroundColor()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = paragraphSpacing
        paragraph.paragraphSpacingBefore = 2
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.textBlocks = [block]
        return paragraph
    }

    private func readerBlockBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedWhite: 0.14, alpha: 1)
            }
            return NSColor(calibratedWhite: 0.965, alpha: 1)
        }
    }

    private func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let sizes: [Int: CGFloat] = [1: 31, 2: 25, 3: 21, 4: 18.5, 5: 16.5, 6: 15.5]
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = level <= 2 ? 18 : 13
        paragraph.paragraphSpacingBefore = level == 1 ? 8 : 22

        return [
            .font: NSFont.boldSystemFont(ofSize: sizes[level] ?? 15),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func quoteAttributes(
        calloutKind: CalloutKind? = nil,
        calloutFoldState: CalloutFoldState? = nil
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: quoteParagraphStyle(calloutKind: calloutKind)
        ]
        if let calloutKind {
            attributes[.markPromptCalloutKind] = calloutKind.rawValue
        }
        if let calloutFoldState {
            attributes[.markPromptCalloutFoldState] = calloutFoldState.rawValue
        }
        return attributes
    }

    private func quoteParagraphStyle(
        calloutKind: CalloutKind? = nil,
        nestingLevel: Int = 0
    ) -> NSMutableParagraphStyle {
        let block = NSTextBlock()
        block.setValue(100, type: .percentageValueType, for: .width)
        block.setWidth(0, type: .absoluteValueType, for: .border)
        block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        block.setWidth(11, type: .absoluteValueType, for: .padding)
        block.setWidth(0, type: .absoluteValueType, for: .margin)
        block.setBorderColor(calloutKind.map(calloutColor(for:)) ?? NSColor.tertiaryLabelColor)
        block.backgroundColor = quoteBlockBackgroundColor()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 2
        paragraph.firstLineHeadIndent = CGFloat(nestingLevel) * 18
        paragraph.headIndent = CGFloat(nestingLevel) * 18
        paragraph.minimumLineHeight = 23
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.textBlocks = [block]
        return paragraph
    }

    private func quoteBlockBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedWhite: 0.12, alpha: 1)
            }
            return NSColor(calibratedWhite: 0.975, alpha: 1)
        }
    }

    private func calloutColor(for kind: CalloutKind) -> NSColor {
        switch kind {
        case .abstract:
            return NSColor.systemTeal
        case .bug:
            return NSColor.systemRed
        case .caution:
            return NSColor.systemRed
        case .danger:
            return NSColor.systemRed
        case .example:
            return NSColor.systemPurple
        case .failure:
            return NSColor.systemRed
        case .info:
            return NSColor.systemBlue
        case .important:
            return NSColor.systemPurple
        case .note:
            return NSColor.systemBlue
        case .question:
            return NSColor.systemOrange
        case .quote:
            return NSColor.secondaryLabelColor
        case .success:
            return NSColor.systemGreen
        case .tip:
            return NSColor.systemGreen
        case .todo:
            return NSColor.systemBlue
        case .warning:
            return NSColor.systemOrange
        }
    }

    private func codeAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = blockParagraphStyle(lineSpacing: 3.5, paragraphSpacing: 16, padding: 9)
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func tableAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3.5
        paragraph.paragraphSpacing = 16
        return [
            .font: NSFont.systemFont(ofSize: 12.2),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func footnoteAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.5
        paragraph.paragraphSpacing = 6
        paragraph.headIndent = 22
        paragraph.firstLineHeadIndent = 0
        paragraph.minimumLineHeight = 18
        return [
            .font: NSFont.systemFont(ofSize: 12.8),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func metadataAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = blockParagraphStyle(lineSpacing: 2, paragraphSpacing: 11, padding: 7, borderWidth: 0.5)
        return [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func htmlBlockAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = blockParagraphStyle(lineSpacing: 4, paragraphSpacing: 15, padding: 10)
        return [
            .font: NSFont.systemFont(ofSize: 14.2),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func imageAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = blockParagraphStyle(lineSpacing: 4, paragraphSpacing: 15, padding: 10)
        return [
            .font: NSFont.systemFont(ofSize: 14.5, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func mathAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = blockParagraphStyle(lineSpacing: 4, paragraphSpacing: 16, padding: 10)
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func thematicBreakAttributes() -> [NSAttributedString.Key: Any] {
        let block = NSTextBlock()
        block.setValue(100, type: .percentageValueType, for: .width)
        block.setWidth(0, type: .absoluteValueType, for: .border)
        block.setWidth(0.8, type: .absoluteValueType, for: .border, edge: .minY)
        block.setWidth(0, type: .absoluteValueType, for: .padding)
        block.setWidth(0, type: .absoluteValueType, for: .margin)
        block.setBorderColor(NSColor.separatorColor)

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 14
        paragraph.maximumLineHeight = 14
        paragraph.paragraphSpacing = 18
        paragraph.paragraphSpacingBefore = 10
        paragraph.textBlocks = [block]
        return [
            .font: NSFont.systemFont(ofSize: 1),
            .foregroundColor: NSColor.clear,
            .paragraphStyle: paragraph
        ]
    }

    private func listParagraphStyle(indentLevel: Int) -> NSMutableParagraphStyle {
        let baseIndent = CGFloat(indentLevel) * 26
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.5
        paragraph.paragraphSpacing = 5
        paragraph.minimumLineHeight = 22
        paragraph.firstLineHeadIndent = baseIndent
        paragraph.headIndent = baseIndent + 24
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    private func listContinuationParagraphStyle(
        indentLevel: Int,
        startsLooseParagraph: Bool = false
    ) -> NSMutableParagraphStyle {
        let baseIndent = CGFloat(indentLevel) * 26
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.5
        paragraph.paragraphSpacing = 5
        paragraph.paragraphSpacingBefore = startsLooseParagraph ? 8 : 0
        paragraph.minimumLineHeight = 22
        paragraph.firstLineHeadIndent = baseIndent + 24
        paragraph.headIndent = baseIndent + 24
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    private func definitionTermAttributes(from baseAttributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        let baseFont = baseAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 16.2)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 3
        paragraph.paragraphSpacingBefore = 4
        paragraph.minimumLineHeight = 22
        paragraph.lineBreakMode = .byWordWrapping

        var attributes = baseAttributes
        attributes[.font] = NSFont.systemFont(ofSize: max(14.5, baseFont.pointSize - 0.2), weight: .semibold)
        attributes[.foregroundColor] = NSColor.labelColor
        attributes[.paragraphStyle] = paragraph
        return attributes
    }

    private func definitionTextAttributes(from baseAttributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        let baseFont = baseAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 16.2)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 8
        paragraph.minimumLineHeight = 22
        paragraph.firstLineHeadIndent = 24
        paragraph.headIndent = 24
        paragraph.lineBreakMode = .byWordWrapping

        var attributes = baseAttributes
        attributes[.font] = NSFont.systemFont(ofSize: max(14.2, baseFont.pointSize - 0.7))
        attributes[.foregroundColor] = NSColor.secondaryLabelColor
        attributes[.paragraphStyle] = paragraph
        return attributes
    }
}

private struct MermaidFlowchartPreview {
    var nodes: [MermaidPreviewNode]
    var edges: [MermaidPreviewEdge]
}

private struct MermaidPreviewNode {
    var id: String
    var label: String
}

private struct MermaidPreviewEdge {
    var from: String
    var to: String
}

private struct PreviewPalette {
    var background: NSColor
    var border: NSColor
    var primaryText: NSColor
    var secondaryText: NSColor
    var nodeBackground: NSColor
    var nodeBorder: NSColor
    var arrow: NSColor

    static var current: PreviewPalette {
        let bestMatch = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua])
        if bestMatch == .darkAqua {
            return PreviewPalette(
                background: NSColor(calibratedWhite: 0.16, alpha: 1),
                border: NSColor(calibratedWhite: 0.34, alpha: 1),
                primaryText: NSColor(calibratedWhite: 0.90, alpha: 1),
                secondaryText: NSColor(calibratedWhite: 0.62, alpha: 1),
                nodeBackground: NSColor(calibratedWhite: 0.11, alpha: 1),
                nodeBorder: NSColor(calibratedRed: 0.37, green: 0.47, blue: 0.64, alpha: 1),
                arrow: NSColor(calibratedRed: 0.54, green: 0.63, blue: 0.76, alpha: 1)
            )
        }

        return PreviewPalette(
            background: NSColor(calibratedWhite: 0.97, alpha: 1),
            border: NSColor(calibratedWhite: 0.82, alpha: 1),
            primaryText: NSColor(calibratedWhite: 0.14, alpha: 1),
            secondaryText: NSColor(calibratedWhite: 0.50, alpha: 1),
            nodeBackground: NSColor(calibratedWhite: 1, alpha: 1),
            nodeBorder: NSColor(calibratedRed: 0.66, green: 0.72, blue: 0.82, alpha: 1),
            arrow: NSColor(calibratedRed: 0.40, green: 0.48, blue: 0.62, alpha: 1)
        )
    }
}

extension NSAttributedString.Key {
    static let markPromptTaskMarkerSourceRange = NSAttributedString.Key("MarkPromptTaskMarkerSourceRange")
    static let markPromptTaskMarkerCharacter = NSAttributedString.Key("MarkPromptTaskMarkerCharacter")
}

private extension NSAttributedString.Key {
    static let markPromptCalloutKind = NSAttributedString.Key("MarkPromptCalloutKind")
    static let markPromptCalloutFoldState = NSAttributedString.Key("MarkPromptCalloutFoldState")
}

private extension String {
    func unescapingMarkdownBackslashEscapes() -> String {
        replacingOccurrences(
            of: #"\\([\\`*_{}\[\]()#+\-.!|<>])"#,
            with: "$1",
            options: .regularExpression
        )
    }

    func replacingEmojiShortcodes(using shortcodes: [String: String]) -> String {
        shortcodes.reduce(self) { result, entry in
            result.replacingOccurrences(of: ":\(entry.key):", with: entry.value)
        }
    }

    func decodingHTMLEntities() -> String {
        var decoded = self
        let namedEntities = [
            "amp": "&",
            "apos": "'",
            "gt": ">",
            "lt": "<",
            "nbsp": " ",
            "quot": "\""
        ]

        for (name, value) in namedEntities {
            decoded = decoded.replacingOccurrences(of: "&\(name);", with: value)
        }

        decoded = decoded.replacingNumericHTMLEntities(pattern: #"&#([0-9]+);"#) { value in
            UInt32(value)
        }
        decoded = decoded.replacingNumericHTMLEntities(pattern: #"&#x([0-9A-Fa-f]+);"#) { value in
            UInt32(value, radix: 16)
        }
        return decoded
    }

    private func replacingNumericHTMLEntities(
        pattern: String,
        decode: (String) -> UInt32?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        let nsText = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return self
        }

        let mutable = NSMutableString(string: self)
        for match in matches.reversed() {
            let rawValue = nsText.substring(with: match.range(at: 1))
            guard let value = decode(rawValue),
                  let scalar = UnicodeScalar(value)
            else {
                continue
            }
            mutable.replaceCharacters(in: match.range, with: String(Character(scalar)))
        }
        return mutable as String
    }
}
