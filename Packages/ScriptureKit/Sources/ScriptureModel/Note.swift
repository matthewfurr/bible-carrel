import Foundation
import ScriptureData
import SwiftData

/// What a note is attached to.
public enum NoteScope: String, Codable, Sendable {
    case highlight
    case verseRange
    case chapter
}

/// A markdown note. Text notes hang off a `Highlight` (their anchor); chapter notes stand alone.
/// The location, translation and quoted text are copied at creation so the note still reads
/// sensibly if the anchor changes or the Notes browser lists it on its own.
@Model
public final class Note {
    public var uuid: UUID = UUID()
    public var body: String = ""
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()
    public var scopeRaw: String = NoteScope.highlight.rawValue
    public var book: String = ""
    public var chapter: Int = 0
    public var verse: Int = 0
    public var endVerse: Int = 0
    public var translationID: String = ""
    public var quotedText: String = ""
    /// The conversation a reply was saved from (Add as Note); nil for the reader's own notes.
    public var sourceThreadID: UUID?
    /// The version the note is now, `<token>.<digest>`; nil before this device's first save of its text (`NoteVersion`).
    public var versionMark: String?
    /// What the sitting that wrote the text started from (`NoteVersion.ancestry`).
    public var versionAncestry: String?
    /// The kind of device that wrote the text: "Mac", "iPhone" or "iPad".
    public var deviceKind: String?
    public var highlight: Highlight?

    public init(
        body: String,
        scope: NoteScope,
        book: String,
        chapter: Int,
        verse: Int,
        endVerse: Int,
        translationID: String,
        quotedText: String
    ) {
        self.body = body
        self.scopeRaw = scope.rawValue
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
        self.translationID = translationID
        self.quotedText = quotedText
    }

    public var scope: NoteScope {
        get { NoteScope(rawValue: scopeRaw) ?? .highlight }
        set { scopeRaw = newValue.rawValue }
    }

    public var location: VerseLocation { VerseLocation(book: book, chapter: chapter, verse: verse) }
    public var chapterLocation: ChapterLocation { ChapterLocation(book: book, chapter: chapter) }
}
