import ScriptureData

/// A selection resolved to verse offsets: UTF-16 `startOffset` in `verse` through `endOffset` in
/// `endVerse`, with the selected scripture text (verse numbers excluded).
public struct TextSelection: Equatable, Sendable {
    public let book: String
    public let chapter: Int
    public let verse: Int
    public let endVerse: Int
    public let startOffset: Int
    public let endOffset: Int
    public let quotedText: String

    public init(book: String, chapter: Int, verse: Int, endVerse: Int, startOffset: Int, endOffset: Int, quotedText: String) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.quotedText = quotedText
    }

    public var chapterLocation: ChapterLocation { ChapterLocation(book: book, chapter: chapter) }

    public var reference: Reference {
        Reference(
            book: BookCatalog.book(code: book) ?? Book(id: book, canon: .oldTestament, order: 0, name: book, shortName: book, aliases: []),
            chapter: chapter,
            verse: verse,
            endVerse: endVerse == verse ? nil : endVerse)
    }

    /// `"Matthew 5:3"` or `"Psalm 23:1-2"`.
    public var referenceString: String { reference.displayString }

    /// `“text” — Matthew 5:3 (ESV)`
    public func copyWithReference(translationID: String) -> String {
        "\u{201C}\(quotedText)\u{201D} \u{2014} \(referenceString) (\(translationID))"
    }
}
