import Foundation

public enum OutlineBuilder {
    public static func build(from markdown: String) -> [DocumentHeading] {
        let flatHeadings = flatHeadings(from: markdown)
        return nestedHeadings(from: flatHeadings)
    }

    public static func flatHeadings(from markdown: String) -> [DocumentHeading] {
        var headings: [DocumentHeading] = []
        var isInsideFence = false
        let lines = MarkdownLineScanner.lines(in: markdown)
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)

            if isFence(trimmed) {
                isInsideFence.toggle()
                index += 1
                continue
            }

            guard !isInsideFence else {
                index += 1
                continue
            }

            if let parsed = parseHeadingLine(line.text) {
                headings.append(
                    DocumentHeading(
                        level: parsed.level,
                        title: outlineTitle(from: parsed.title),
                        sourceRange: line.sourceRange
                    )
                )
                index += 1
                continue
            }

            if let parsed = parseSetextHeading(lines, at: index) {
                headings.append(
                    DocumentHeading(
                        level: parsed.level,
                        title: outlineTitle(from: parsed.title),
                        sourceRange: parsed.sourceRange
                    )
                )
                index = parsed.nextIndex
                continue
            }

            index += 1
        }

        return headings
    }

    static func parseHeadingLine(_ line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let hashes = trimmed.prefix { $0 == "#" }.count

        guard (1...6).contains(hashes) else {
            return nil
        }

        let afterHashes = trimmed.dropFirst(hashes)
        guard afterHashes.first == " " || afterHashes.first == "\t" else {
            return nil
        }

        let rawTitle = afterHashes
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+#+\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawTitle.isEmpty else {
            return nil
        }

        return (hashes, rawTitle)
    }

    static func parseSetextHeading(
        _ lines: [MarkdownSourceLine],
        at index: Int
    ) -> (level: Int, title: String, sourceRange: SourceTextRange, nextIndex: Int)? {
        guard index + 1 < lines.count else {
            return nil
        }

        let titleLine = lines[index]
        let underlineLine = lines[index + 1]
        let title = titleLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPotentialSetextTitleLine(titleLine.text, trimmedTitle: title),
              let level = parseSetextUnderline(underlineLine.text)
        else {
            return nil
        }

        return (
            level,
            title,
            SourceTextRange(
                lowerBound: titleLine.sourceRange.lowerBound,
                upperBound: underlineLine.sourceRange.upperBound
            ),
            index + 2
        )
    }

    static func isFence(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
    }

    private static func isPotentialSetextTitleLine(_ line: String, trimmedTitle: String) -> Bool {
        guard !trimmedTitle.isEmpty,
              parseHeadingLine(line) == nil,
              !isFence(trimmedTitle),
              !trimmedTitle.hasPrefix(">"),
              !trimmedTitle.hasPrefix("|"),
              !trimmedTitle.hasPrefix("![]("),
              !trimmedTitle.hasPrefix("$$")
        else {
            return false
        }

        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces < 4 else {
            return false
        }

        return trimmedTitle.range(of: #"^(\d+\.\s+|[-*+]\s+|\[[ xX]\]\s+)"#, options: .regularExpression) == nil
    }

    private static func parseSetextUnderline(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first,
              first == "=" || first == "-"
        else {
            return nil
        }

        guard trimmed.allSatisfy({ character in
            character == first || character == " " || character == "\t"
        }) else {
            return nil
        }

        return first == "=" ? 1 : 2
    }

    private static func outlineTitle(from rawTitle: String) -> String {
        var title = rawTitle
        let replacements: [(String, String)] = [
            (#"!\[([^\]]*)\]\([^)]+\)"#, "$1"),
            (#"\[([^\]]+)\]\([^)]+\)"#, "$1"),
            (#"`([^`]+)`"#, "$1"),
            (#"(\*\*|__)(.+?)\1"#, "$2"),
            (#"~~(.+?)~~"#, "$1"),
            (#"==(.+?)=="#, "$1"),
            (#"\+\+(.+?)\+\+"#, "$1"),
            (#"<[^>]+>"#, "")
        ]

        for replacement in replacements {
            title = title.replacingOccurrences(
                of: replacement.0,
                with: replacement.1,
                options: .regularExpression
            )
        }

        title = title
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? rawTitle : title
    }

    private static func nestedHeadings(from flatHeadings: [DocumentHeading]) -> [DocumentHeading] {
        final class MutableHeading {
            var heading: DocumentHeading
            var children: [MutableHeading] = []

            init(_ heading: DocumentHeading) {
                self.heading = heading
            }
        }

        var roots: [MutableHeading] = []
        var stack: [MutableHeading] = []

        for heading in flatHeadings {
            let node = MutableHeading(heading)

            while let last = stack.last, last.heading.level >= heading.level {
                stack.removeLast()
            }

            if let parent = stack.last {
                parent.children.append(node)
            } else {
                roots.append(node)
            }

            stack.append(node)
        }

        func freeze(_ node: MutableHeading) -> DocumentHeading {
            var heading = node.heading
            heading.children = node.children.map(freeze)
            return heading
        }

        return roots.map(freeze)
    }
}
