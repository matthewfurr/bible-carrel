import ScriptureData

/// About a book: the facts its head and fact list show, and its timeline (spec 5.4).
public struct BookAbout: Equatable, Sendable {
    public let book: Book, subtitle: String?, testamentLine: String, lengthLine: String
    public let writers: [PersonSummary]
    public let topPeople: [PersonSummary], peopleCount: Int
    public let topPlaces: [PlaceSummary], placeCount: Int
    public let timeline: BookTimeline

    /// How many names the People and Places rows list before "and n more".
    public static let mostNamed = 5

    public var morePeople: Int { peopleCount - topPeople.count }
    public var morePlaces: Int { placeCount - topPlaces.count }
    public var hasDate: Bool { timeline.years != nil }

    /// "about 4004 to 1635 BC"; nil with dates off or no dated entry.
    public func spans(showingDates: Bool) -> String? {
        showingDates ? timeline.years.map(LibraryYear.spans) : nil
    }

    /// "Old Testament, the Law": the canon, then the group's name in words.
    static func testamentLine(for book: Book) -> String {
        let group: String = switch BookGroup.group(of: book) {
        case .law: "the Law"
        case .history: "History"
        case .poetryAndWisdom: "Poetry and Wisdom"
        case .majorProphets: "the Major Prophets"
        case .minorProphets: "the Minor Prophets"
        case .gospelsAndActs: "the Gospels and Acts"
        case .paulsLetters: "Paul's Letters"
        case .generalLetters: "the General Letters"
        case .revelation: "Revelation"
        case .apocrypha: "Apocrypha"
        }
        return "\(book.canon.displayName), \(group)"
    }

    /// nil outside the 66.
    public static func load(book code: String, translationID: String, store: BibleStore) throws -> BookAbout? {
        guard let book = BookCatalog.book(code: code), book.canon != .apocrypha else { return nil }
        let chapters = try store.books(in: translationID).first { $0.book.id == code }?.chapterCount ?? 0
        let verses = try store.verseCount(ofBook: code, translationID: translationID)
        let people = try store.people(inBook: code), places = try store.placesNamed(inBook: code)
        return BookAbout(
            book: book,
            subtitle: try store.bookTitle(bookID: code, translationID: translationID).subtitle,
            testamentLine: testamentLine(for: book),
            lengthLine: "\(chapters.formatted()) \(chapters == 1 ? "chapter" : "chapters"), \(verses.formatted()) \(verses == 1 ? "verse" : "verses")",
            writers: try store.writers(ofBook: code),
            topPeople: Array(people.prefix(mostNamed)), peopleCount: people.count,
            topPlaces: Array(places.prefix(mostNamed)), placeCount: places.count,
            timeline: try BookTimeline.load(book: code, translationID: translationID, store: store))
    }
}
