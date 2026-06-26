import Foundation

public struct TextAnchorBuilder {
    private let contextLimit: Int

    public init(contextLimit: Int = 80) {
        self.contextLimit = contextLimit
    }

    public func makeAnchor(
        for selection: ReaderSelection,
        in document: MarkdownDocument
    ) -> TextAnchor {
        let sourceRange = refinedSourceRange(for: selection, in: document)
        let headingPath = headingPath(for: sourceRange, in: document)
        let renderedText = document.renderModel.renderedPlainText as NSString
        let safeRenderedRange = safeRange(selection.renderedRange.nsRange, in: renderedText.length)

        return TextAnchor(
            headingPath: headingPath,
            selectedText: selection.selectedText,
            normalizedSelectedText: TextNormalizer.normalized(selection.selectedText),
            sourceRange: sourceRange,
            renderedRange: selection.renderedRange,
            contextBefore: contextBefore(range: safeRenderedRange, text: renderedText),
            contextAfter: contextAfter(range: safeRenderedRange, text: renderedText),
            documentHash: document.sourceHash
        )
    }

    private func refinedSourceRange(
        for selection: ReaderSelection,
        in document: MarkdownDocument
    ) -> SourceTextRange? {
        guard let blockSourceRange = selection.sourceRange else {
            return nil
        }

        let source = document.rawMarkdown as NSString
        guard blockSourceRange.upperBound <= source.length else {
            return blockSourceRange
        }

        let blockText = source.substring(
            with: NSRange(location: blockSourceRange.lowerBound, length: blockSourceRange.length)
        )
        let selectedText = selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedText.isEmpty else {
            return blockSourceRange
        }

        let match = (blockText as NSString).range(of: selectedText)
        guard match.location != NSNotFound else {
            return blockSourceRange
        }

        return SourceTextRange(
            lowerBound: blockSourceRange.lowerBound + match.location,
            upperBound: blockSourceRange.lowerBound + match.location + match.length
        )
    }

    private func headingPath(
        for sourceRange: SourceTextRange?,
        in document: MarkdownDocument
    ) -> [String] {
        guard let sourceRange else {
            return []
        }

        let precedingHeadings = document.outline.flattened()
            .filter { $0.sourceRange.lowerBound <= sourceRange.lowerBound }
            .sorted { $0.sourceRange.lowerBound < $1.sourceRange.lowerBound }

        guard let nearestHeading = precedingHeadings.last else {
            return []
        }

        return document.outline.headingPath(to: nearestHeading.id) ?? [nearestHeading.title]
    }

    private func contextBefore(range: NSRange, text: NSString) -> String {
        let start = max(0, range.location - contextLimit)
        let length = max(0, range.location - start)
        return TextNormalizer.normalized(text.substring(with: NSRange(location: start, length: length)))
    }

    private func contextAfter(range: NSRange, text: NSString) -> String {
        let start = min(text.length, range.location + range.length)
        let length = min(contextLimit, text.length - start)
        return TextNormalizer.normalized(text.substring(with: NSRange(location: start, length: length)))
    }

    private func safeRange(_ range: NSRange, in textLength: Int) -> NSRange {
        let location = min(max(0, range.location), textLength)
        let length = min(max(0, range.length), textLength - location)
        return NSRange(location: location, length: length)
    }
}
