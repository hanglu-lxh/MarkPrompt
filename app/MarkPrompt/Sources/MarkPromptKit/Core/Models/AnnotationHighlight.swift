import Foundation

public struct AnnotationHighlight: Identifiable, Equatable, Sendable {
    public var id: String
    public var range: RenderedTextRange
    public var isSelected: Bool
    public var isIncludedInPrompt: Bool
    public var isAnchorLost: Bool

    public init(
        id: String,
        range: RenderedTextRange,
        isSelected: Bool,
        isIncludedInPrompt: Bool,
        isAnchorLost: Bool
    ) {
        self.id = id
        self.range = range
        self.isSelected = isSelected
        self.isIncludedInPrompt = isIncludedInPrompt
        self.isAnchorLost = isAnchorLost
    }
}
