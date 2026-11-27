import Foundation

/// Where a search looks: the whole Bible, a testament, the Apocrypha or one book.
public enum SearchScope: Hashable, Codable, Sendable {
    case wholeBible, oldTestament, newTestament, apocrypha
    case book(String)

    public var title: String {
        switch self {
        case .wholeBible: "Whole Bible"
        case .oldTestament: "Old Testament"
        case .newTestament: "New Testament"
        case .apocrypha: "Apocrypha"
        case .book(let code): BookCatalog.book(code: code)?.name ?? code
        }
    }

    public func contains(_ book: Book) -> Bool {
        switch self {
        case .wholeBible: true
        case .oldTestament: book.canon == .oldTestament
        case .newTestament: book.canon == .newTestament
        case .apocrypha: book.canon == .apocrypha
        case .book(let code): book.id == code
        }
    }

    /// Whole Bible, then each section `books` has a book of, in canon order (Apocrypha only then).
    public static func sections(in books: [TranslationBook]) -> [SearchScope] {
        let canons = Set(books.map(\.book.canon))
        var result: [SearchScope] = [.wholeBible]
        if canons.contains(.oldTestament) { result.append(.oldTestament) }
        if canons.contains(.newTestament) { result.append(.newTestament) }
        if canons.contains(.apocrypha) { result.append(.apocrypha) }
        return result
    }

    /// The scope ⌃Tab (`step` 1) or ⌃⇧Tab (`step` -1) moves to: round the scope menu's top level,
    /// `sections(in:)` then This Book, always listed when a chapter is open (`currentBook`), as the
    /// menu lists it. A scope not on that list (another single book, chosen from the Book submenu)
    /// steps forward to Whole Bible and back to the last.
    public static func next(after scope: SearchScope, in books: [TranslationBook], currentBook: Book?, by step: Int) -> SearchScope {
        var list = sections(in: books)
        if let currentBook { list.append(.book(currentBook.id)) }
        guard let index = list.firstIndex(of: scope) else { return step < 0 ? list[list.count - 1] : list[0] }
        let count = list.count
        return list[((index + step) % count + count) % count]
    }
}

public enum SearchOrder: String, Codable, Sendable, CaseIterable {
    case bestMatch, bibleOrder

    public var title: String {
        switch self {
        case .bestMatch: "Best match"
        case .bibleOrder: "Bible order"
        }
    }
}

public struct SearchPage: Equatable, Sendable {
    public let verses: [Verse]
    /// Every matching verse in the scope.
    public let total: Int

    public init(verses: [Verse], total: Int) {
        self.verses = verses
        self.total = total
    }

    public static let empty = SearchPage(verses: [], total: 0)
}
