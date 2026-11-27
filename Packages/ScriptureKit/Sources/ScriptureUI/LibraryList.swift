import ScriptureData

/// The phone's Library as a list: the books of one testament in the translation's order, with at
/// most one book open to show its chapters. Platform-neutral, so its decisions are tested on the
/// Mac; the view only draws it.
public struct LibraryList: Equatable, Sendable {
    /// The two tabs over the list.
    public enum Testament: CaseIterable, Hashable, Sendable {
        case old, new

        public var title: String {
            switch self {
            case .old: "Old Testament"
            case .new: "New Testament"
            }
        }
    }

    public let books: [TranslationBook]
    public var testament: Testament
    /// The book whose chapters show under its name.
    public private(set) var openBookID: String?
    /// The book being read, when the translation has it, whether or not it is open.
    public let readingBookID: String?

    /// Opens on the testament of the book being read, with that book open; on the Old Testament
    /// with nothing open when no chapter is open or the translation lacks its book. `opening` is the
    /// book to open in its place (a Library page's, as Library reopens on it), when the translation has it.
    public init(books: [TranslationBook], current: ChapterLocation?, opening: String? = nil) {
        self.books = books
        let reading = current.flatMap { location in books.first { $0.book.id == location.book } }
        let opened = opening.flatMap { id in books.first { $0.book.id == id } } ?? reading
        testament = opened.map { Self.testament(of: $0.book) } ?? .old
        readingBookID = reading?.book.id
        openBookID = opened?.book.id
    }

    /// The phone's Library as it opens: on the book of the Library page it reopens on, else on the
    /// book being read. The book chosen on the Mac's front page (`selectedBookID`) plays no part.
    @MainActor public init(navigation: NavigationModel) {
        self.init(books: navigation.books, current: navigation.location, opening: navigation.libraryPlace?.book)
    }

    /// The Apocrypha, where a translation has it, is listed with the Old Testament.
    public static func testament(of book: Book) -> Testament {
        book.canon == .newTestament ? .new : .old
    }

    /// The books of the chosen testament, in the translation's order.
    public var shownBooks: [TranslationBook] {
        books.filter { Self.testament(of: $0.book) == testament }
    }

    /// A group's heading and its books.
    public struct Section: Equatable, Sendable {
        public let group: BookGroup
        public let books: [TranslationBook]
    }

    /// The chosen testament's groups in order (the Old Testament's end with the Apocrypha), each
    /// with its books in the translation's order; a group the translation has no book of is left out.
    public var shownSections: [Section] {
        let shown = shownBooks
        return BookGroup.allCases.compactMap { group in
            let inGroup = shown.filter { BookGroup.group(of: $0.book) == group }
            return inGroup.isEmpty ? nil : Section(group: group, books: inGroup)
        }
    }

    /// A tap on a book's row opens it (closing any other) or, if it was open, closes it. A book
    /// of one chapter is no different: its chapters are its icons and a single "1" (Matt,
    /// 2026-11-16, replacing a name that read the chapter at once).
    public mutating func tap(bookID: String) {
        openBookID = openBookID == bookID ? nil : bookID
    }
}
