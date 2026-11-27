import Foundation
import ScriptureData

/// What the front page's toolbar search offers: a reference to go to, when the query names an
/// openable one, and the translation's books that match.
public struct FrontPageSearchResults: Equatable, Sendable {
    public let reference: Reference?
    public let books: [TranslationBook]

    public init(reference: Reference?, books: [TranslationBook]) {
        self.reference = reference
        self.books = books
    }
}

/// Filters the front page's book list. A reference is offered under the ⌘K palette's rule
/// (`PaletteRanker`): its book is in the translation and its chapter, if any, is within the book.
/// Books are those whose names start with the query, in canon order, with the parsed book first;
/// the parsed book stays even when its chapter is past the end, so "Matt 99" still lists Matthew.
public enum FrontPageSearch {
    public static func results(query: String, books: [TranslationBook]) -> FrontPageSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return FrontPageSearchResults(reference: nil, books: books) }

        var reference: Reference?
        var parsedBook: TranslationBook?
        if let parsed = ReferenceParser.parse(trimmed),
           let available = books.first(where: { $0.book.id == parsed.book.id }) {
            parsedBook = available
            if parsed.chapter.map({ (1...available.chapterCount).contains($0) }) ?? true {
                reference = parsed
            }
        }

        // A half-typed reference ("Matt 5:") does not parse; match on its leading book words instead.
        let prefix = parsedBook == nil ? leadingBookPart(of: trimmed) : trimmed
        let matchedIDs = Set(ReferenceParser.matchBooks(prefix: prefix).map(\.id))
        let matches = books.filter { matchedIDs.contains($0.book.id) && $0.book.id != parsedBook?.book.id }
        return FrontPageSearchResults(reference: reference, books: (parsedBook.map { [$0] } ?? []) + matches)
    }

    /// The query's book words, read as `ReferenceParser` reads them: an optional leading digit
    /// ("1 Cor"), then letters and spaces up to the first digit or colon. A lone digit ("1") lists
    /// the numbered books; "5:3" lists none, since no book starts with 5.
    private static func leadingBookPart(of query: String) -> String {
        var rest = Substring(query)
        var part = ""
        if let first = rest.first, first.isNumber {
            part.append(first)
            rest = rest.dropFirst()
        }
        part += rest.prefix { !$0.isNumber && $0 != ":" }
        return part.trimmingCharacters(in: .whitespaces)
    }
}
