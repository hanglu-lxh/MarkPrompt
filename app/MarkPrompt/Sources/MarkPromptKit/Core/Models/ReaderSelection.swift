import CoreGraphics
import Foundation

public struct ReaderSelection: Equatable, Sendable {
    public var selectedText: String
    public var renderedRange: RenderedTextRange
    public var sourceRange: SourceTextRange?
    public var selectionRect: CGRect?

    public init(
        selectedText: String,
        renderedRange: RenderedTextRange,
        sourceRange: SourceTextRange?,
        selectionRect: CGRect? = nil
    ) {
        self.selectedText = selectedText
        self.renderedRange = renderedRange
        self.sourceRange = sourceRange
        self.selectionRect = selectionRect
    }
}
