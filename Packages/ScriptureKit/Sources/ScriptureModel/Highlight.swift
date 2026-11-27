import Foundation
import ScriptureData
import SwiftData

/// A character range of scripture text with an optional color, and the anchor for a text note.
/// Offsets are UTF-16 units within `Verse.text` of `translationID`: `startOffset` in `verse`,
/// `endOffset` in `endVerse` (usually the same verse). A highlight with neither color nor note
/// has no reason to exist and is deleted by `MarkupStore.deleteIfEmpty`.
///
/// CloudKit-ready even though sync is off: every attribute defaulted or optional, no unique
/// attributes, optional relationships, a `uuid` for cross-device identity.
@Model
public final class Highlight {
    public var uuid: UUID = UUID()
    public var book: String = ""
    public var chapter: Int = 0
    public var verse: Int = 0
    public var endVerse: Int = 0
    public var startOffset: Int = 0
    public var endOffset: Int = 0
    public var translationID: String = ""
    public var colorID: UUID?
    public var quotedText: String = ""
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Note.highlight)
    public var note: Note?

    public init(
        book: String,
        chapter: Int,
        verse: Int,
        endVerse: Int,
        startOffset: Int,
        endOffset: Int,
        translationID: String,
        colorID: UUID?,
        quotedText: String
    ) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.translationID = translationID
        self.colorID = colorID
        self.quotedText = quotedText
    }

    public var location: VerseLocation { VerseLocation(book: book, chapter: chapter, verse: verse) }
    public var endLocation: VerseLocation { VerseLocation(book: book, chapter: chapter, verse: endVerse) }
    public var chapterLocation: ChapterLocation { ChapterLocation(book: book, chapter: chapter) }

    /// True when nothing is left to show: no color and no note.
    public var isEmpty: Bool { colorID == nil && note == nil }
}
