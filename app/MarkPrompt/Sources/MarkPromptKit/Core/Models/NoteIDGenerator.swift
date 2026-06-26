import Foundation

public enum NoteIDGenerator {
    public static func id(for sequence: Int) -> String {
        "note_\(String(format: "%03d", sequence))"
    }

    public static func nextSequence(after lastSequence: Int) -> Int {
        max(0, lastSequence) + 1
    }

    public static func highestSequence(in notes: [ReviewNote]) -> Int {
        notes
            .compactMap { sequence(from: $0.id) }
            .max() ?? 0
    }

    public static func sequence(from noteID: String) -> Int? {
        guard noteID.hasPrefix("note_") else {
            return nil
        }

        return Int(noteID.dropFirst("note_".count))
    }
}
