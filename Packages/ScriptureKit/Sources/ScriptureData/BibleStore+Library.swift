import Foundation
import GRDB

/// The Library's reads: people, places and events, by the data's integer ids. A verse is a `VerseKey`.
extension BibleStore {
    // MARK: In a book

    /// Everyone the data names in `book`, most verses first (counted in the book), then name, then id.
    /// Empty for a book outside the 66.
    public func people(inBook book: String) throws -> [PersonSummary] {
        guard let range = Self.keys(ofBook: book) else { return [] }
        return try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT p.id, p.name, p.label, count(*) AS n
                FROM person_verse v JOIN person p ON p.id = v.person_id
                WHERE v.verse BETWEEN ? AND ?
                GROUP BY p.id
                ORDER BY n DESC, p.name COLLATE NOCASE, p.id
                """, arguments: [range.lowerBound, range.upperBound])
            .map { PersonSummary(id: $0["id"], name: $0["name"], label: $0["label"], verseCount: $0["n"]) }
        }
    }

    /// The places the data names in `book`, most verses first (counted in the book), then name, then id.
    public func placesNamed(inBook book: String) throws -> [PlaceSummary] {
        guard let range = Self.keys(ofBook: book) else { return [] }
        return try queue.read { db in try Self.placesIn(range: range, point: nil, excluding: nil, db) }
    }

    /// Each place named in `book`, once for each chapter that names it: the chapter, its first verse there and the
    /// verses naming it there (project 4, spec 7). One read, in chapter order, then first verse, then place id.
    /// Empty for a book outside the 66.
    public func placeChapters(inBook book: String) throws -> [PlaceChapterMention] {
        guard let range = Self.keys(ofBook: book) else { return [] }
        return try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT place_id, verse / 1000 % 1000 AS chapter, MIN(verse % 1000) AS first, count(*) AS verses
                FROM place_verse
                WHERE verse BETWEEN ? AND ?
                GROUP BY place_id, chapter
                ORDER BY chapter, first, place_id
                """, arguments: [range.lowerBound, range.upperBound])
            .map { PlaceChapterMention(placeID: $0["place_id"], chapter: $0["chapter"], firstVerse: $0["first"], verseCount: $0["verses"]) }
        }
    }

    /// The book's events by `sort_key` then id, each with its first passage in the book.
    public func events(inBook book: String) throws -> [BookEvent] {
        guard let range = Self.keys(ofBook: book) else { return [] }
        return try queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT e.id, e.title, e.year, p.start, p.end
                FROM event_passage p JOIN event e ON e.id = p.event_id
                WHERE p.start BETWEEN ? AND ?
                ORDER BY e.sort_key, e.id, p.start
                """, arguments: [range.lowerBound, range.upperBound])
            var seen = Set<Int>()
            return rows.compactMap { row -> BookEvent? in
                let id: Int = row["id"]
                guard let start = VerseKey.location(row["start"]), let end = VerseKey.location(row["end"]),
                      seen.insert(id).inserted else { return nil }
                return BookEvent(id: id, title: row["title"], year: row["year"], start: start, end: end)
            }
        }
    }

    /// Every event, by `sort_key` then id. Read through a cursor by column index: About reads all of them for
    /// each book (departure 16), and decoding rows by name cost twice as long.
    public func eventRecords() throws -> [EventRecord] {
        try queue.read { db in
            var records: [EventRecord] = []
            let rows = try Row.fetchCursor(db, sql: """
                SELECT id, title, year, sort_key, duration_days, part_of, person_id FROM event ORDER BY sort_key, id
                """)
            while let row = try rows.next() {
                records.append(EventRecord(id: row[0], title: row[1], year: row[2], sortKey: row[3],
                                           durationDays: row[4], partOf: row[5], personID: row[6]))
            }
            return records
        }
    }

    /// The people the data names as writers of `book`, in its order, with whole-Bible counts.
    public func writers(ofBook book: String) throws -> [PersonSummary] {
        try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT p.id, p.name, p.label, p.verse_count
                FROM book_writer w JOIN person p ON p.id = w.person_id
                WHERE w.book_id = ? ORDER BY w.ordinal
                """, arguments: [book])
            .map(Self.summary)
        }
    }

    // MARK: A person

    public func person(_ id: Int) throws -> PersonRecord? {
        try queue.read { db in
            try Row.fetchOne(db, sql: """
                SELECT id, name, label, also_called, birth_year, death_year, verse_count, dictionary FROM person WHERE id = ?
                """, arguments: [id])
            .map { PersonRecord(id: $0["id"], name: $0["name"], label: $0["label"], alsoCalled: Self.names($0["also_called"]),
                                birthYear: $0["birth_year"], deathYear: $0["death_year"], verseCount: $0["verse_count"],
                                dictionary: $0["dictionary"]) }
        }
    }

    /// A person's relatives in `Relation.allCases` order, then the data's.
    public func relatives(of id: Int) throws -> [Relative] {
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT r.kind, r.ordinal, p.id, p.name, p.label, p.verse_count
                FROM person_relation r JOIN person p ON p.id = r.relative_id
                WHERE r.person_id = ?
                """, arguments: [id])
        }
        let order = Dictionary(uniqueKeysWithValues: Relation.allCases.enumerated().map { ($1, $0) })
        return rows.compactMap { row -> (Int, Int, Relative)? in
            guard let kind = Relation(rawValue: row["kind"]) else { return nil }
            return (order[kind] ?? 0, row["ordinal"], Relative(kind: kind, person: Self.summary(row)))
        }
        .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
        .map(\.2)
    }

    /// The father and mother the data names for each of `ids`, in one read: each id's father before its
    /// mother. An id with neither is absent; no ids read nothing.
    public func parents(of ids: [Int]) throws -> [Int: [Relative]] {
        let ids = Array(Set(ids))
        guard !ids.isEmpty else { return [:] }
        let marks = ids.map { _ in "?" }.joined(separator: ", ")
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT r.person_id, r.kind, r.ordinal, p.id, p.name, p.label, p.verse_count
                FROM person_relation r JOIN person p ON p.id = r.relative_id
                WHERE r.kind IN ('father', 'mother') AND r.person_id IN (\(marks))
                """, arguments: StatementArguments(ids))
        }
        var found: [Int: [(Int, Int, Relative)]] = [:]
        for row in rows {
            guard let kind = Relation(rawValue: row["kind"]) else { continue }
            let order = kind == .father ? 0 : 1
            found[row["person_id"], default: []].append((order, row["ordinal"], Relative(kind: kind, person: Self.summary(row))))
        }
        return found.mapValues { $0.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map(\.2) }
    }

    /// Every verse that names the person, in canon order.
    public func verses(ofPerson id: Int) throws -> [VerseLocation] {
        try queue.read { db in
            try Int.fetchAll(db, sql: "SELECT verse FROM person_verse WHERE person_id = ? ORDER BY verse", arguments: [id])
        }
        .compactMap(VerseKey.location)
    }

    // MARK: A place

    public func place(_ id: Int) throws -> PlaceRecord? {
        try queue.read { db in
            try Row.fetchOne(db, sql: """
                SELECT id, name, label, kind, latitude, longitude, point, approximate, verse_count, also_called, dictionary
                FROM place WHERE id = ?
                """, arguments: [id])
            .map { PlaceRecord(summary: Self.placeSummary($0, count: $0["verse_count"]), alsoCalled: Self.names($0["also_called"]),
                               dictionary: $0["dictionary"]) }
        }
    }

    /// The other places at `id`'s point; in `book` with its counts there, else with whole-Bible counts.
    /// None for a place with no point.
    public func places(sharingPointWith id: Int, inBook book: String?) throws -> [PlaceSummary] {
        try queue.read { db in
            guard let point = try String.fetchOne(db, sql: "SELECT point FROM place WHERE id = ?", arguments: [id]) else { return [] }
            if let book {
                guard let range = Self.keys(ofBook: book) else { return [] }
                return try Self.placesIn(range: range, point: point, excluding: id, db)
            }
            return try Row.fetchAll(db, sql: """
                SELECT id, name, label, kind, latitude, longitude, point, approximate, verse_count AS n
                FROM place WHERE point = ? AND id <> ? ORDER BY verse_count DESC, name COLLATE NOCASE, id
                """, arguments: [point, id])
            .map { Self.placeSummary($0, count: $0["n"]) }
        }
    }

    /// Every verse that names the place, in canon order.
    public func verses(ofPlace id: Int) throws -> [VerseLocation] {
        try queue.read { db in
            try Int.fetchAll(db, sql: "SELECT verse FROM place_verse WHERE place_id = ? ORDER BY verse", arguments: [id])
        }
        .compactMap(VerseKey.location)
    }

    // MARK: Counting a book

    /// How many verses the translation gives the book; a joined verse counts every verse it holds.
    public func verseCount(ofBook book: String, translationID: String) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT coalesce(sum(coalesce(verse_end, verse) - verse + 1), 0)
                FROM verse WHERE translation_id = ? AND book_id = ?
                """, arguments: [translationID, book]) ?? 0
        }
    }

    /// The translation's last verse of each of the book's chapters, by chapter: the last row's, a joined verse's
    /// last ("12-13" is 13). One read for the book; a chapter the translation lacks is absent.
    public func lastVerses(ofBook book: String, translationID: String) throws -> [Int: Int] {
        try queue.read { db in
            // SQLite gives the bare `verse_end` from the row holding `max(verse)`.
            var last: [Int: Int] = [:]
            let rows = try Row.fetchCursor(db, sql: """
                SELECT chapter, max(verse), verse_end FROM verse WHERE translation_id = ? AND book_id = ? GROUP BY chapter
                """, arguments: [translationID, book])
            while let row = try rows.next() {
                let verse: Int = row[1], end: Int? = row[2]
                last[row[0]] = end ?? verse
            }
            return last
        }
    }

    // MARK: By name

    /// People whose name, surname or "also called" has a word starting each typed word; `.none` for fewer than
    /// two characters. Most verses first, then name, then id.
    public func searchPeople(_ text: String, limit: Int) throws -> NameMatches<PersonSummary> {
        guard let patterns = Self.namePatterns(text) else { return .none }
        return try queue.read { db in
            let (condition, arguments) = Self.nameCondition(patterns)
            let total = try Int.fetchOne(db, sql: "SELECT count(*) FROM person WHERE \(condition)", arguments: arguments) ?? 0
            guard total > 0, limit > 0 else { return NameMatches(rows: [], total: total) }
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, name, label, verse_count FROM person WHERE \(condition)
                ORDER BY verse_count DESC, name COLLATE NOCASE, id LIMIT ?
                """, arguments: arguments + [limit])
            return NameMatches(rows: rows.map(Self.summary), total: total)
        }
    }

    /// Places whose title, names or aliases have a word starting each typed word; as `searchPeople`.
    public func searchPlaces(_ text: String, limit: Int) throws -> NameMatches<PlaceSummary> {
        guard let patterns = Self.namePatterns(text) else { return .none }
        return try queue.read { db in
            let (condition, arguments) = Self.nameCondition(patterns)
            let total = try Int.fetchOne(db, sql: "SELECT count(*) FROM place WHERE \(condition)", arguments: arguments) ?? 0
            guard total > 0, limit > 0 else { return NameMatches(rows: [], total: total) }
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, name, label, kind, latitude, longitude, point, approximate, verse_count AS n FROM place
                WHERE \(condition) ORDER BY verse_count DESC, name COLLATE NOCASE, id LIMIT ?
                """, arguments: arguments + [limit])
            return NameMatches(rows: rows.map { Self.placeSummary($0, count: $0["n"]) }, total: total)
        }
    }

    // MARK: Helpers

    /// The keys of a book's verses; nil outside the 66.
    private static func keys(ofBook book: String) -> ClosedRange<Int>? {
        guard let found = BookCatalog.book(code: book), found.canon != .apocrypha else { return nil }
        return found.order * 1_000_000 ... found.order * 1_000_000 + 999_999
    }

    /// `LIKE` patterns, one for each typed word; nil when the words hold fewer than two characters in all.
    private static func namePatterns(_ text: String) -> [String]? {
        let words = SearchQuery.tokens(in: text).map(\.word)
        guard words.reduce(0, { $0 + $1.count }) >= 2 else { return nil }
        return words.map { "% \($0)%" }
    }

    private static func nameCondition(_ patterns: [String]) -> (String, StatementArguments) {
        (patterns.map { _ in "search_names LIKE ?" }.joined(separator: " AND "), StatementArguments(patterns))
    }

    private static func summary(_ row: Row) -> PersonSummary {
        PersonSummary(id: row["id"], name: row["name"], label: row["label"], verseCount: row["verse_count"])
    }

    private static func placeSummary(_ row: Row, count: Int) -> PlaceSummary {
        PlaceSummary(id: row["id"], name: row["name"], label: row["label"], kind: row["kind"],
                     latitude: row["latitude"], longitude: row["longitude"], point: row["point"],
                     isApproximate: row["approximate"], verseCount: count)
    }

    /// The places with verses in `range` (counted there), optionally only those at `point`, without `excluding`.
    private static func placesIn(range: ClosedRange<Int>, point: String?, excluding: Int?, _ db: Database) throws -> [PlaceSummary] {
        var arguments: [any DatabaseValueConvertible] = [range.lowerBound, range.upperBound]
        var extra = ""
        if let point { extra += " AND p.point = ?"; arguments.append(point) }
        if let excluding { extra += " AND p.id <> ?"; arguments.append(excluding) }
        return try Row.fetchAll(db, sql: """
            SELECT p.id, p.name, p.label, p.kind, p.latitude, p.longitude, p.point, p.approximate, count(*) AS n
            FROM place_verse v JOIN place p ON p.id = v.place_id
            WHERE v.verse BETWEEN ? AND ?\(extra)
            GROUP BY p.id
            ORDER BY n DESC, p.name COLLATE NOCASE, p.id
            """, arguments: StatementArguments(arguments))
        .map { placeSummary($0, count: $0["n"]) }
    }

    /// The `also_called` column: a JSON array of strings.
    private static func names(_ json: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
    }
}
