/// One person in a list: what a row shows.
public struct PersonSummary: Hashable, Identifiable, Sendable {
    public let id: Int, name: String, label: String?, verseCount: Int

    public init(id: Int, name: String, label: String?, verseCount: Int) {
        self.id = id
        self.name = name
        self.label = label
        self.verseCount = verseCount
    }
}

public struct PersonRecord: Equatable, Sendable {
    public let id: Int, name: String, label: String?, alsoCalled: [String], birthYear: Int?, deathYear: Int?, verseCount: Int, dictionary: String?
}

/// How a relative stands to a person, in the order a page lays them out.
public enum Relation: String, CaseIterable, Sendable { case father, mother, partner, sibling, halfSibling, child }

public struct Relative: Hashable, Sendable {
    public let kind: Relation, person: PersonSummary

    public init(kind: Relation, person: PersonSummary) {
        self.kind = kind
        self.person = person
    }
}

public struct PlaceSummary: Hashable, Identifiable, Sendable {
    public let id: Int, name: String, label: String?, kind: String?
    public let latitude: Double?, longitude: Double?, point: String?, isApproximate: Bool, verseCount: Int

    public init(id: Int, name: String, label: String?, kind: String?, latitude: Double?, longitude: Double?, point: String?,
                isApproximate: Bool, verseCount: Int) {
        self.id = id
        self.name = name
        self.label = label
        self.kind = kind
        self.latitude = latitude
        self.longitude = longitude
        self.point = point
        self.isApproximate = isApproximate
        self.verseCount = verseCount
    }
}

/// A place named in one chapter of a book: its first verse there and how many verses name it there
/// (project 4, spec 7; Departure 4).
public struct PlaceChapterMention: Equatable, Sendable {
    public let placeID: Int, chapter: Int, firstVerse: Int, verseCount: Int

    public init(placeID: Int, chapter: Int, firstVerse: Int, verseCount: Int) {
        self.placeID = placeID
        self.chapter = chapter
        self.firstVerse = firstVerse
        self.verseCount = verseCount
    }
}

public struct PlaceRecord: Equatable, Sendable { public let summary: PlaceSummary, alsoCalled: [String], dictionary: String? }

/// An event in a book, with its first passage there.
public struct BookEvent: Hashable, Identifiable, Sendable { public let id: Int, title: String, year: Int, start: VerseLocation, end: VerseLocation }

/// An event as the data keeps it: when it was, how long it lasted and what it belongs to.
public struct EventRecord: Hashable, Identifiable, Sendable {
    public let id: Int, title: String, year: Int, sortKey: Double
    /// Its length in days, when the data gives one that is read.
    public let durationDays: Double?
    /// The event it is part of: a life when it is part of one.
    public let partOf: Int?
    /// The person of a "Lifetime of" event.
    public let personID: Int?

    public init(id: Int, title: String, year: Int, sortKey: Double, durationDays: Double?, partOf: Int?, personID: Int?) {
        self.id = id
        self.title = title
        self.year = year
        self.sortKey = sortKey
        self.durationDays = durationDays
        self.partOf = partOf
        self.personID = personID
    }
}

/// The first rows of a name search and how many matched in all.
public struct NameMatches<Row: Equatable & Sendable>: Equatable, Sendable {
    public let rows: [Row], total: Int

    public init(rows: [Row], total: Int) {
        self.rows = rows
        self.total = total
    }

    public static var none: NameMatches { NameMatches(rows: [], total: 0) }
}
