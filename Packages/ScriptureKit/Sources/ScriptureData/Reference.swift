/// A parsed scripture reference: a book, optionally a chapter, optionally a verse or verse range.
public struct Reference: Hashable, Sendable {
    public let book: Book
    public let chapter: Int?
    public let verse: Int?
    public let endVerse: Int?

    public init(book: Book, chapter: Int? = nil, verse: Int? = nil, endVerse: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
    }

    /// `"1 Corinthians 13:4-7"`, `"Psalm 23"`, `"Psalms"`, `"John"`.
    public var displayString: String {
        guard let chapter else { return book.name }
        var result = "\(book.chapterName) \(chapter)"
        if let verse {
            result += ":\(verse)"
            if let endVerse {
                result += "-\(endVerse)"
            }
        }
        return result
    }
}
