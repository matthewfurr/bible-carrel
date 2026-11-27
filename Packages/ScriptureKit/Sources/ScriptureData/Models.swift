/// A bundled translation such as ESV or WEB.
public struct Translation: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// A chapter address independent of translation.
public struct ChapterLocation: Hashable, Codable, Sendable {
    public let book: String
    public let chapter: Int

    public init(book: String, chapter: Int) {
        self.book = book
        self.chapter = chapter
    }
}

/// A verse address independent of translation.
public struct VerseLocation: Hashable, Codable, Sendable {
    public let book: String
    public let chapter: Int
    public let verse: Int

    public init(book: String, chapter: Int, verse: Int) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
    }
}

/// One verse of one translation.
public struct Verse: Identifiable, Hashable, Sendable {
    public var id: VerseLocation
    public let translationID: String
    /// Set when the translation combines several verses into one (e.g. ERV 12-13); `id.verse` is the first.
    public let endVerse: Int?
    /// Lines separated by `"\n"` are poetry.
    public let text: String
    /// True when a paragraph break follows this verse.
    public let breakAfter: Bool

    public init(id: VerseLocation, translationID: String, endVerse: Int? = nil, text: String, breakAfter: Bool) {
        self.id = id
        self.translationID = translationID
        self.endVerse = endVerse
        self.text = text
        self.breakAfter = breakAfter
    }
}

/// All of one book's verses in one translation, by chapter. Equal by `book` and `translationID`
/// only: the text for a pair never changes, so comparing the chapters would be wasted work.
public struct BookText: Equatable, Sendable {
    public let book: String
    public let translationID: String
    public let chapters: [Int: [Verse]]

    public init(book: String, translationID: String, chapters: [Int: [Verse]]) {
        self.book = book
        self.translationID = translationID
        self.chapters = chapters
    }

    public static func == (lhs: BookText, rhs: BookText) -> Bool {
        lhs.book == rhs.book && lhs.translationID == rhs.translationID
    }
}

/// A book as present in a particular translation.
public struct TranslationBook: Hashable, Sendable {
    public let book: Book
    public let chapterCount: Int

    public init(book: Book, chapterCount: Int) {
        self.book = book
        self.chapterCount = chapterCount
    }
}
