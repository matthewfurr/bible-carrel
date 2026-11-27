import Foundation
import ScriptureData

/// The verses a reference in an assistant's reply names, in one translation, for the popover
/// (Mac) or sheet (iPhone) a click on the reference shows.
public struct VersePreview: Identifiable, Equatable, Sendable {
    public let reference: Reference
    public let translationID: String
    public let verses: [Verse]

    public var id: String { reference.displayString + translationID }
    public var title: String { reference.displayString }

    /// The reference's verses in `translationID`; nil when no verse exists. A verse the
    /// translation combines with its neighbour ("12-13") is included when it overlaps the range.
    public static func load(_ reference: Reference, translationID: String, store: BibleStore) throws -> VersePreview? {
        guard let chapter = reference.chapter else { return nil }
        let all = try store.chapter((book: reference.book.id, chapter: chapter), translationID: translationID)
        let verses: [Verse]
        if let first = reference.verse {
            let last = reference.endVerse ?? first
            verses = all.filter { $0.id.verse <= last && ($0.endVerse ?? $0.id.verse) >= first }
        } else {
            verses = all
        }
        guard !verses.isEmpty else { return nil }
        return VersePreview(reference: reference, translationID: translationID, verses: verses)
    }
}
