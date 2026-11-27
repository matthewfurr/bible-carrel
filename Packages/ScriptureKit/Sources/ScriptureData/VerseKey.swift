/// A verse as one integer: `Book.order × 1,000,000 + chapter × 1,000 + verse` (John 3:16 is 43003016).
/// It needs no join to read and sorts in canon order, so "a range holds this verse" is two comparisons.
public enum VerseKey {
    /// nil for a book `BookCatalog` does not know.
    public static func key(_ verse: VerseLocation) -> Int? {
        guard let book = BookCatalog.book(code: verse.book) else { return nil }
        return book.order * 1_000_000 + verse.chapter * 1_000 + verse.verse
    }

    /// nil when no book has that order.
    public static func location(_ key: Int) -> VerseLocation? {
        let order = key / 1_000_000
        guard key >= 0, BookCatalog.all.indices.contains(order - 1) else { return nil }
        return VerseLocation(book: BookCatalog.all[order - 1].id, chapter: key / 1_000 % 1_000, verse: key % 1_000)
    }
}
