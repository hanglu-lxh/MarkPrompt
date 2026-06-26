import Foundation

public struct SourceTextRange: Codable, Equatable, Sendable {
    public var lowerBound: Int
    public var upperBound: Int

    public init(lowerBound: Int, upperBound: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public var length: Int {
        max(0, upperBound - lowerBound)
    }
}

public struct RenderedTextRange: Codable, Equatable, Sendable {
    public var location: Int
    public var length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }

    public var nsRange: NSRange {
        NSRange(location: location, length: length)
    }

    public var upperBound: Int {
        location + length
    }
}
