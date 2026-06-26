import Foundation

public struct ReviewSession: Codable, Equatable, Sendable {
    public var version: String
    public var sourceFile: String?
    public var sourceHash: String
    public var lastNoteSequence: Int
    public var notes: [ReviewNote]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        version: String = "1",
        sourceFile: String?,
        sourceHash: String,
        lastNoteSequence: Int = 0,
        notes: [ReviewNote] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.sourceFile = sourceFile
        self.sourceHash = sourceHash
        self.lastNoteSequence = max(lastNoteSequence, NoteIDGenerator.highestSequence(in: notes))
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case sourceFile
        case sourceHash
        case lastNoteSequence
        case notes
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        sourceFile = try container.decodeIfPresent(String.self, forKey: .sourceFile)
        sourceHash = try container.decode(String.self, forKey: .sourceHash)
        notes = try container.decode([ReviewNote].self, forKey: .notes)
        let decodedSequence = try container.decodeIfPresent(Int.self, forKey: .lastNoteSequence) ?? 0
        lastNoteSequence = max(decodedSequence, NoteIDGenerator.highestSequence(in: notes))
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(sourceFile, forKey: .sourceFile)
        try container.encode(sourceHash, forKey: .sourceHash)
        try container.encode(lastNoteSequence, forKey: .lastNoteSequence)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public struct ReviewNote: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var status: ReviewNoteStatus
    public var includeInPrompt: Bool
    public var anchor: TextAnchor
    public var comment: String
    public var quickPrompts: [QuickPromptUsage]
    public var inferredMetadata: InferredNoteMetadata?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        status: ReviewNoteStatus = .confirmed,
        includeInPrompt: Bool = true,
        anchor: TextAnchor,
        comment: String,
        quickPrompts: [QuickPromptUsage] = [],
        inferredMetadata: InferredNoteMetadata? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.includeInPrompt = includeInPrompt
        self.anchor = anchor
        self.comment = comment
        self.quickPrompts = quickPrompts
        self.inferredMetadata = inferredMetadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ReviewNoteStatus: String, Codable, Equatable, Sendable {
    case draft
    case confirmed
    case excluded
    case anchorLost = "anchor_lost"
}

public struct TextAnchor: Codable, Equatable, Sendable {
    public var headingPath: [String]
    public var selectedText: String
    public var normalizedSelectedText: String
    public var sourceRange: SourceTextRange?
    public var renderedRange: RenderedTextRange?
    public var contextBefore: String
    public var contextAfter: String
    public var documentHash: String

    public init(
        headingPath: [String],
        selectedText: String,
        normalizedSelectedText: String,
        sourceRange: SourceTextRange?,
        renderedRange: RenderedTextRange?,
        contextBefore: String,
        contextAfter: String,
        documentHash: String
    ) {
        self.headingPath = headingPath
        self.selectedText = selectedText
        self.normalizedSelectedText = normalizedSelectedText
        self.sourceRange = sourceRange
        self.renderedRange = renderedRange
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.documentHash = documentHash
    }
}

public struct QuickPromptUsage: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var insertedText: String

    public init(id: String, label: String, insertedText: String) {
        self.id = id
        self.label = label
        self.insertedText = insertedText
    }
}

public struct InferredNoteMetadata: Codable, Equatable, Sendable {
    public var suggestedAction: String?

    public init(suggestedAction: String? = nil) {
        self.suggestedAction = suggestedAction
    }
}
