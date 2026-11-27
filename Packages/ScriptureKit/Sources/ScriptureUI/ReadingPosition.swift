import ScriptureData

/// Where the reader left off: a translation-independent place plus the translation it was read in.
public struct ReadingPosition: Codable, Equatable, Sendable {
    public var book: String
    public var chapter: Int
    public var firstVisibleVerse: Int
    public var translationID: String

    public init(book: String, chapter: Int, firstVisibleVerse: Int, translationID: String) {
        self.book = book
        self.chapter = chapter
        self.firstVisibleVerse = firstVisibleVerse
        self.translationID = translationID
    }

    public var chapterLocation: ChapterLocation {
        ChapterLocation(book: book, chapter: chapter)
    }
}
