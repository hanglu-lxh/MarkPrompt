import CoreGraphics
import Foundation

public struct ReaderSelection: Equatable, Sendable {
    public var selectedText: String
    public var renderedRange: RenderedTextRange
    public var sourceRange: SourceTextRange?
    public var visibleSelectionRect: CGRect?
    public var annotationButtonRect: CGRect?

    public init(
        selectedText: String,
        renderedRange: RenderedTextRange,
        sourceRange: SourceTextRange?,
        visibleSelectionRect: CGRect? = nil,
        annotationButtonRect: CGRect? = nil
    ) {
        self.selectedText = selectedText
        self.renderedRange = renderedRange
        self.sourceRange = sourceRange
        self.visibleSelectionRect = visibleSelectionRect
        self.annotationButtonRect = annotationButtonRect
    }
}
