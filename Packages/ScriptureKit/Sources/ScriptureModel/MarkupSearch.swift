import Foundation
import ScriptureData

/// The reference text shown for a markup record: `"Matthew 5:3"`, `"Matthew 5:3-4"`, or
/// `"Matthew 5"` when `verse` is nil. Shared by the notes column, the Notes browser and search.
public enum MarkupReferenceText {
    public static func string(book: String, chapter: Int, verse: Int?, endVerse: Int?) -> String {
        let bookEntry = BookCatalog.book(code: book) ?? Book(id: book, canon: .oldTestament, order: 0, name: book, shortName: book)
        let end = (endVerse == verse) ? nil : endVerse
        return Reference(book: bookEntry, chapter: chapter, verse: verse, endVerse: verse == nil ? nil : end).displayString
    }
}

/// Reference matching for the Notes browser search: a query matches a record when it is a
/// substring of the record's display reference, or when it parses as a reference whose book,
/// chapter (if given) and verse or verse range (if given) cover the record.
public enum MarkupSearch {
    public static func matchesReference(_ query: String, book: String, chapter: Int, verse: Int, endVerse: Int) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let display = MarkupReferenceText.string(book: book, chapter: chapter, verse: verse, endVerse: endVerse)
        if display.localizedCaseInsensitiveContains(trimmed) { return true }
        guard let reference = ReferenceParser.parse(trimmed), reference.book.id == book else { return false }
        guard let wantedChapter = reference.chapter else { return true }
        guard wantedChapter == chapter else { return false }
        guard let wantedVerse = reference.verse else { return true }
        let wantedEnd = reference.endVerse ?? wantedVerse
        return wantedVerse <= max(verse, endVerse) && wantedEnd >= verse
    }
}
