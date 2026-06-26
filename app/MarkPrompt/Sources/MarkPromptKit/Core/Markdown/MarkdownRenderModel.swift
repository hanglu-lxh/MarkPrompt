import AppKit
import Foundation

public enum MarkdownRenderBlockKind: String, Codable, Equatable, Sendable {
    case heading
    case paragraph
    case unorderedList
    case orderedList
    case blockquote
    case codeBlock
    case table
    case taskList
    case definitionList
    case footnote
    case image
    case metadata
    case mathBlock
    case thematicBreak
    case htmlBlock
}

public struct MarkdownRenderBlock: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: MarkdownRenderBlockKind
    public var sourceRange: SourceTextRange
    public var renderedRange: RenderedTextRange
    public var headingID: UUID?

    public init(
        id: UUID = UUID(),
        kind: MarkdownRenderBlockKind,
        sourceRange: SourceTextRange,
        renderedRange: RenderedTextRange,
        headingID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.sourceRange = sourceRange
        self.renderedRange = renderedRange
        self.headingID = headingID
    }
}

public struct MarkdownSourceMap: Equatable {
    public var blocks: [MarkdownRenderBlock]
    public var headingRenderRanges: [UUID: RenderedTextRange]

    public init(
        blocks: [MarkdownRenderBlock] = [],
        headingRenderRanges: [UUID: RenderedTextRange] = [:]
    ) {
        self.blocks = blocks
        self.headingRenderRanges = headingRenderRanges
    }

    public func sourceRange(containing renderedRange: RenderedTextRange) -> SourceTextRange? {
        blocks.first { block in
            block.renderedRange.location <= renderedRange.location
                && block.renderedRange.upperBound >= renderedRange.upperBound
        }?.sourceRange
    }

    public func renderedRange(containing sourceRange: SourceTextRange) -> RenderedTextRange? {
        blocks.first { block in
            block.sourceRange.lowerBound <= sourceRange.lowerBound
                && block.sourceRange.upperBound >= sourceRange.upperBound
        }?.renderedRange
    }

    public func block(containing renderedRange: RenderedTextRange) -> MarkdownRenderBlock? {
        blocks.first { block in
            block.renderedRange.location <= renderedRange.location
                && block.renderedRange.upperBound >= renderedRange.upperBound
        }
    }

    public func block(containing sourceRange: SourceTextRange) -> MarkdownRenderBlock? {
        blocks.first { block in
            block.sourceRange.lowerBound <= sourceRange.lowerBound
                && block.sourceRange.upperBound >= sourceRange.upperBound
        }
    }
}

public struct MarkdownRenderModel: Equatable {
    public var attributedText: NSAttributedString
    public var renderedPlainText: String
    public var sourceMap: MarkdownSourceMap

    public init(
        attributedText: NSAttributedString,
        renderedPlainText: String,
        sourceMap: MarkdownSourceMap
    ) {
        self.attributedText = attributedText
        self.renderedPlainText = renderedPlainText
        self.sourceMap = sourceMap
    }

    public static func == (lhs: MarkdownRenderModel, rhs: MarkdownRenderModel) -> Bool {
        lhs.renderedPlainText == rhs.renderedPlainText
            && lhs.sourceMap == rhs.sourceMap
    }
}
