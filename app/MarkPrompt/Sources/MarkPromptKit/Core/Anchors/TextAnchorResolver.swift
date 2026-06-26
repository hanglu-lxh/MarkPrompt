import Foundation

public struct TextAnchorResolution: Equatable, Sendable {
    public var anchor: TextAnchor
    public var status: ReviewNoteStatus

    public init(anchor: TextAnchor, status: ReviewNoteStatus) {
        self.anchor = anchor
        self.status = status
    }
}

public struct TextAnchorResolver {
    public init() {}

    public func resolve(note: ReviewNote, in document: MarkdownDocument) -> ReviewNote {
        let resolution = resolve(anchor: note.anchor, in: document)
        var resolvedNote = note
        resolvedNote.anchor = resolution.anchor

        if note.status != .excluded {
            resolvedNote.status = resolution.status
        }

        return resolvedNote
    }

    public func resolve(anchor: TextAnchor, in document: MarkdownDocument) -> TextAnchorResolution {
        if let resolvedByRange = resolveBySourceRangeAndHash(anchor: anchor, in: document) {
            return resolvedByRange
        }

        if let resolvedByText = resolveByHeadingTextAndContext(anchor: anchor, in: document) {
            return resolvedByText
        }

        var unresolved = anchor
        unresolved.renderedRange = nil
        return TextAnchorResolution(anchor: unresolved, status: .anchorLost)
    }

    private func resolveBySourceRangeAndHash(
        anchor: TextAnchor,
        in document: MarkdownDocument
    ) -> TextAnchorResolution? {
        guard anchor.documentHash == document.sourceHash else {
            return nil
        }

        if let renderedRange = anchor.renderedRange,
           renderedRange.upperBound <= (document.renderModel.renderedPlainText as NSString).length,
           renderedText(in: document, range: renderedRange) == anchor.selectedText {
            var resolved = anchor
            resolved.renderedRange = renderedRange
            resolved.documentHash = document.sourceHash
            return TextAnchorResolution(anchor: resolved, status: .confirmed)
        }

        guard let sourceRange = anchor.sourceRange,
              let blockRange = document.renderModel.sourceMap.renderedRange(containing: sourceRange)
        else {
            return nil
        }

        let renderedText = document.renderModel.renderedPlainText as NSString
        guard blockRange.upperBound <= renderedText.length else {
            return nil
        }

        let blockText = renderedText.substring(with: blockRange.nsRange) as NSString
        let match = blockText.range(of: anchor.selectedText)
        guard match.location != NSNotFound else {
            return nil
        }

        var resolved = anchor
        resolved.renderedRange = RenderedTextRange(
            location: blockRange.location + match.location,
            length: match.length
        )
        resolved.documentHash = document.sourceHash
        return TextAnchorResolution(anchor: resolved, status: .confirmed)
    }

    private func resolveByHeadingTextAndContext(
        anchor: TextAnchor,
        in document: MarkdownDocument
    ) -> TextAnchorResolution? {
        let renderedText = document.renderModel.renderedPlainText as NSString
        let searchStart = headingSearchStart(for: anchor.headingPath, in: document)
        let searchRange = NSRange(location: searchStart, length: renderedText.length - searchStart)
        let selectedText = anchor.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedText.isEmpty else {
            return nil
        }

        var bestRange: NSRange?
        var bestScore = Int.min
        var remainingRange = searchRange

        while remainingRange.length > 0 {
            let match = renderedText.range(of: selectedText, options: [], range: remainingRange)
            guard match.location != NSNotFound else {
                break
            }

            let score = contextScore(for: match, text: renderedText, anchor: anchor)
            if score > bestScore {
                bestScore = score
                bestRange = match
            }

            let nextLocation = match.location + max(match.length, 1)
            guard nextLocation < searchRange.location + searchRange.length else {
                break
            }

            remainingRange = NSRange(
                location: nextLocation,
                length: searchRange.location + searchRange.length - nextLocation
            )
        }

        guard let bestRange else {
            return nil
        }

        let renderedRange = RenderedTextRange(location: bestRange.location, length: bestRange.length)
        var resolved = anchor
        resolved.renderedRange = renderedRange
        resolved.sourceRange = document.renderModel.sourceMap.sourceRange(containing: renderedRange)
        resolved.documentHash = document.sourceHash
        return TextAnchorResolution(anchor: resolved, status: .confirmed)
    }

    private func headingSearchStart(for headingPath: [String], in document: MarkdownDocument) -> Int {
        guard let lastHeading = headingPath.last,
              let heading = document.outline.flattened().first(where: { $0.title == lastHeading }),
              let renderedRange = document.renderModel.sourceMap.headingRenderRanges[heading.id]
        else {
            return 0
        }

        return renderedRange.location
    }

    private func contextScore(for range: NSRange, text: NSString, anchor: TextAnchor) -> Int {
        var score = 0
        let beforeStart = max(0, range.location - 120)
        let before = text.substring(with: NSRange(location: beforeStart, length: range.location - beforeStart))
        let afterStart = min(text.length, range.location + range.length)
        let after = text.substring(with: NSRange(location: afterStart, length: min(120, text.length - afterStart)))

        if !anchor.contextBefore.isEmpty,
           TextNormalizer.normalized(before).contains(anchor.contextBefore) {
            score += 2
        }

        if !anchor.contextAfter.isEmpty,
           TextNormalizer.normalized(after).contains(anchor.contextAfter) {
            score += 2
        }

        return score
    }

    private func renderedText(in document: MarkdownDocument, range: RenderedTextRange) -> String {
        (document.renderModel.renderedPlainText as NSString).substring(with: range.nsRange)
    }
}
