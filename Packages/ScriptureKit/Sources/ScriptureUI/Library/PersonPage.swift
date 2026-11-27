import ScriptureData

/// One person's page: the family the data links, and the verses that name them.
public struct PersonPage: Equatable, Sendable {
    public let person: PersonRecord
    /// The family the data links, as a tree (spec 5.1).
    public let family: FamilyTree
    /// The book's own verses; nil for the whole Bible, or when it has none.
    public let here: VerseGroup?
    /// Every other book in canon order; for the whole Bible, every book.
    public let elsewhere: [VerseGroup]

    /// The names the data gives them besides: "Lord, Son"; nil with none.
    public var alsoCalled: String? {
        person.alsoCalled.isEmpty ? nil : person.alsoCalled.joined(separator: ", ")
    }

    public var hasDate: Bool { person.birthYear != nil || person.deathYear != nil }

    /// The Lived fact: "about 1085 to 1015 BC"; nil with Show dates off or without a year (Departure 20).
    public func lived(showingDates: Bool) -> String? {
        showingDates ? LibraryYear.lived(birth: person.birthYear, death: person.deathYear) : nil
    }

    /// The Named fact (Departure 22): "226 verses here, 896 in 28 books"; "12 verses here" when every verse is in
    /// this book; "896 verses in 28 books" on a whole-Bible page and where this book has none of them; nil
    /// when the person has no verse at all (the row is left out).
    public var namedLine: String? {
        func verses(_ count: Int) -> String { "\(count.formatted()) verse\(count == 1 ? "" : "s")" }
        let total = (here?.count ?? 0) + elsewhere.reduce(0) { $0 + $1.count }
        let books = elsewhere.count + (here == nil ? 0 : 1)
        guard total > 0 else { return nil }
        let inBooks = "\(books.formatted()) book\(books == 1 ? "" : "s")"
        guard let here else { return "\(verses(total)) in \(inBooks)" }
        return elsewhere.isEmpty ? "\(verses(here.count)) here" : "\(verses(here.count)) here, \(total.formatted()) in \(inBooks)"
    }

    /// Every book's verses show when the page holds this many references or fewer.
    public static let opensEveryBookUpTo = 40

    public var opensEveryBook: Bool {
        (here?.references.count ?? 0) + elsewhere.reduce(0) { $0 + $1.references.count } <= Self.opensEveryBookUpTo
    }

    /// nil when there is no such person.
    public static func load(_ id: Int, inBook book: String?, store: BibleStore) throws -> PersonPage? {
        guard let person = try store.person(id) else { return nil }
        let relatives = try store.relatives(of: id)
        let parentIDs = relatives.filter { $0.kind == .father || $0.kind == .mother }.map(\.person.id)
        let childIDs = relatives.filter { $0.kind == .child }.map(\.person.id)
        let family = FamilyTree.make(
            person: PersonSummary(id: person.id, name: person.name, label: person.label, verseCount: person.verseCount),
            relatives: relatives, parentsOfChildren: try store.parents(of: childIDs), parentsOfParents: try store.parents(of: parentIDs))
        let verses = VerseGroup.split(try store.verses(ofPerson: id), inBook: book)
        return PersonPage(person: person, family: family, here: verses.here, elsewhere: verses.elsewhere)
    }
}
