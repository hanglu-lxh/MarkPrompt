import Foundation

struct MarkdownSourceLine {
    var text: String
    var sourceRange: SourceTextRange
    var nextLineStart: Int
}

enum MarkdownLineScanner {
    static func lines(in source: String) -> [MarkdownSourceLine] {
        let nsSource = source as NSString
        var lines: [MarkdownSourceLine] = []
        var location = 0

        while location < nsSource.length {
            var lineEnd = 0
            var contentsEnd = 0
            nsSource.getLineStart(
                nil,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: location, length: 0)
            )

            let text = nsSource.substring(with: NSRange(location: location, length: contentsEnd - location))
            lines.append(
                MarkdownSourceLine(
                    text: text,
                    sourceRange: SourceTextRange(lowerBound: location, upperBound: contentsEnd),
                    nextLineStart: lineEnd
                )
            )
            location = lineEnd
        }

        return lines
    }
}
