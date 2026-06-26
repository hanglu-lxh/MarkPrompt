import Foundation

public struct DocumentHeading: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var level: Int
    public var title: String
    public var sourceRange: SourceTextRange
    public var children: [DocumentHeading]

    public init(
        id: UUID = UUID(),
        level: Int,
        title: String,
        sourceRange: SourceTextRange,
        children: [DocumentHeading] = []
    ) {
        self.id = id
        self.level = level
        self.title = title
        self.sourceRange = sourceRange
        self.children = children
    }
}

public extension Array where Element == DocumentHeading {
    func flattened() -> [DocumentHeading] {
        flatMap { heading in
            [heading] + heading.children.flattened()
        }
    }

    func headingPath(to id: UUID) -> [String]? {
        for heading in self {
            if heading.id == id {
                return [heading.title]
            }

            if let childPath = heading.children.headingPath(to: id) {
                return [heading.title] + childPath
            }
        }

        return nil
    }
}
