import Foundation
import GRDB
import Synchronization

public enum BibleStoreError: Error, Equatable {
    case databaseMissing(URL)
    /// The file was built by a different importer version; rebuild with `Scripts/build-bible.sh`.
    case schemaMismatch(found: Int?, expected: Int)
}

/// Read-only access to a bundled `bible.sqlite`.
public final class BibleStore: Sendable {
    let queue: DatabaseQueue
    /// Each translation's index words, read once (see `words(in:)`).
    let keptWords = Mutex<[String: [WordCount]]>([:])

    public init(databaseURL: URL) throws {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw BibleStoreError.databaseMissing(databaseURL)
        }
        var config = Configuration()
        config.readonly = true
        queue = try DatabaseQueue(path: databaseURL.path, configuration: config)
        let found: Int? = try queue.read { db in
            guard try db.tableExists("meta") else { return nil }
            return try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'schema_version'").flatMap(Int.init)
        }
        guard found == BibleSchema.version else {
            throw BibleStoreError.schemaMismatch(found: found, expected: BibleSchema.version)
        }
    }

    func readWords(in translationID: String) throws -> [WordCount] {
        guard let table = BibleSchema.vocabularyTable(for: translationID) else { return [] }
        return try queue.read { db in
            guard try db.tableExists(table) else { return [] }
            return try Row.fetchAll(db, sql: "SELECT term, doc FROM \(table) ORDER BY term")
                .map { WordCount(word: $0["term"], verses: $0["doc"]) }
        }
    }

    public func translations() throws -> [Translation] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT id, title FROM translation ORDER BY id").map {
                Translation(id: $0["id"], title: $0["title"])
            }
        }
    }

    /// Books present in a translation, in canon order.
    public func books(in translationID: String) throws -> [TranslationBook] {
        try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT tb.book_id, tb.chapter_count
                FROM translation_book tb JOIN book b ON b.id = tb.book_id
                WHERE tb.translation_id = ?
                ORDER BY b.sort_order
                """, arguments: [translationID])
            .compactMap { row in
                BookCatalog.book(code: row["book_id"]).map { TranslationBook(book: $0, chapterCount: row["chapter_count"]) }
            }
        }
    }

    /// The verses of one chapter in verse order. Empty when the chapter does not exist.
    public func chapter(_ location: ChapterLocation, translationID: String) throws -> [Verse] {
        try chapter((book: location.book, chapter: location.chapter), translationID: translationID)
    }

    /// The verses of one chapter in verse order. Empty when the chapter does not exist.
    public func chapter(_ location: (book: String, chapter: Int), translationID: String) throws -> [Verse] {
        try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT book_id, chapter, verse, verse_end, text, break_after
                FROM verse
                WHERE translation_id = ? AND book_id = ? AND chapter = ?
                ORDER BY verse
                """, arguments: [translationID, location.book, location.chapter])
            .map { Self.verse(from: $0, translationID: translationID) }
        }
    }

    /// The verses `verse` through `endVerse` of one chapter in each of `translationIDs`, keyed by translation,
    /// in verse order; a translation with none is absent. A verse a translation combines with its neighbor
    /// ("12-13") answers for every verse it holds.
    public func verses(in location: ChapterLocation, verse: Int, endVerse: Int, translationIDs: [String]) throws -> [String: [Verse]] {
        guard !translationIDs.isEmpty else { return [:] }
        return try queue.read { db in
            let marks = Array(repeating: "?", count: translationIDs.count).joined(separator: ", ")
            let rows = try Row.fetchAll(db, sql: """
                SELECT translation_id, book_id, chapter, verse, verse_end, text, break_after
                FROM verse
                WHERE translation_id IN (\(marks)) AND book_id = ? AND chapter = ?
                  AND verse <= ? AND coalesce(verse_end, verse) >= ?
                ORDER BY translation_id, verse
                """, arguments: StatementArguments(translationIDs) + [location.book, location.chapter, endVerse, verse])
            var found: [String: [Verse]] = [:]
            for row in rows {
                let id: String = row["translation_id"]
                found[id, default: []].append(Self.verse(from: row, translationID: id))
            }
            return found
        }
    }

    /// Every chapter of a book, keyed by chapter number, verses in order (one query).
    public func bookChapters(_ bookID: String, translationID: String) throws -> [Int: [Verse]] {
        try queue.read { db in
            let verses = try Row.fetchAll(db, sql: """
                SELECT book_id, chapter, verse, verse_end, text, break_after
                FROM verse
                WHERE translation_id = ? AND book_id = ?
                ORDER BY chapter, verse
                """, arguments: [translationID, bookID])
                .map { Self.verse(from: $0, translationID: translationID) }
            return Dictionary(grouping: verses, by: \.id.chapter)
        }
    }

    // MARK: Cross-references

    /// What `verse` points to: the links whose source it is, strongest first, a tie in canon order.
    /// Each row carries the target's first verse in `translationID`, and for a target that runs past its first
    /// chapter, that chapter's last verse.
    public func crossReferences(from verse: VerseLocation, translationID: String) throws -> [CrossReference] {
        guard let key = VerseKey.key(verse) else { return [] }
        return try queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT source, target_start, target_end, votes FROM cross_reference
                WHERE source = ? ORDER BY votes DESC, target_start, target_end
                """, arguments: [key])
            return try rows.compactMap { try Self.link($0, pointingTo: true, translationID: translationID, in: db) }
        }
    }

    /// What points to `verse`: the links whose target is it or a range holding it, never the verse's own,
    /// strongest first, a tie in canon order. Each row carries the source verse in `translationID`.
    /// Two bounded statements joined here: one statement with `OR` makes the planner scan the table.
    public func crossReferences(to verse: VerseLocation, translationID: String) throws -> [CrossReference] {
        guard let key = VerseKey.key(verse),
              let chapterKey = VerseKey.key(VerseLocation(book: verse.book, chapter: verse.chapter, verse: 0)) else { return [] }
        return try queue.read { db in
            // A range that starts in the verse's own chapter.
            var rows = try Row.fetchAll(db, sql: """
                SELECT source, target_start, target_end, votes FROM cross_reference
                WHERE target_start BETWEEN ? AND ? AND target_end >= ?
                """, arguments: [chapterKey, key, key])
            // A range begun in an earlier chapter or book: only the few in the partial index are looked at.
            rows += try Row.fetchAll(db, sql: """
                SELECT source, target_start, target_end, votes FROM cross_reference
                WHERE target_end / 1000 > target_start / 1000 AND target_end >= ? AND target_start < ?
                """, arguments: [key, chapterKey])
            let ordered = rows.filter { ($0["source"] as Int) != key }.sorted {
                let (a, b): (Int, Int) = ($0["votes"], $1["votes"])
                return a != b ? a > b : ($0["source"] as Int) < ($1["source"] as Int)
            }
            var seen = Set<Int>()   // one row per source, its strongest link
            return try ordered.filter { seen.insert($0["source"]).inserted }
                .compactMap { try Self.link($0, pointingTo: false, translationID: translationID, in: db) }
        }
    }

    private static func link(_ row: Row, pointingTo: Bool, translationID: String, in db: Database) throws -> CrossReference? {
        guard let source = VerseKey.location(row["source"]), let target = VerseKey.location(row["target_start"]),
              let targetEnd = VerseKey.location(row["target_end"]) else { return nil }
        let own = pointingTo ? target : source
        // The verse row holding the verse, a combined row ("12-13") answering for each verse it holds.
        let text = try String.fetchOne(db, sql: """
            SELECT text FROM (
                SELECT text, coalesce(verse_end, verse) AS last FROM verse
                WHERE translation_id = ? AND book_id = ? AND chapter = ? AND verse <= ?
                ORDER BY verse DESC LIMIT 1
            ) WHERE last >= ?
            """, arguments: [translationID, own.book, own.chapter, own.verse, own.verse])
        var chapterEnd: Int?
        if pointingTo, targetEnd.book != target.book || targetEnd.chapter != target.chapter {
            chapterEnd = try Int.fetchOne(db, sql: """
                SELECT max(coalesce(verse_end, verse)) FROM verse WHERE translation_id = ? AND book_id = ? AND chapter = ?
                """, arguments: [translationID, target.book, target.chapter])
        }
        return CrossReference(source: source, target: target, targetEnd: targetEnd, votes: row["votes"], openingText: text, chapterEnd: chapterEnd)
    }

    /// Translations that carry no section headings of their own and borrow none.
    public static let headingFreeTranslations: Set<String> = ["CPDV"]

    /// The BSB's section headings for a book, attached to the translation's own verses: each heading goes on the
    /// first verse of its chapter at or after the heading's verse (a combined verse counts when its range holds it).
    /// A heading with no such verse is dropped. Headings for one verse are ordered by `ordinal`.
    public func headings(bookID: String, translationID: String) throws -> [VerseLocation: [SectionHeading]] {
        guard !Self.headingFreeTranslations.contains(translationID) else { return [:] }
        return try queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT chapter, verse, level, text
                FROM heading
                WHERE source = 'bsb' AND book_id = ?
                ORDER BY chapter, verse, ordinal
                """, arguments: [bookID])
            guard !rows.isEmpty else { return [:] }
            var spans: [Int: [(start: Int, end: Int)]] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT chapter, verse, verse_end FROM verse
                WHERE translation_id = ? AND book_id = ?
                ORDER BY chapter, verse
                """, arguments: [translationID, bookID]) {
                let start: Int = row["verse"]
                let end: Int? = row["verse_end"]
                spans[row["chapter"], default: []].append((start, end ?? start))
            }
            var result: [VerseLocation: [SectionHeading]] = [:]
            for row in rows {
                let chapter: Int = row["chapter"]
                let verse: Int = row["verse"]
                guard let target = spans[chapter]?.first(where: { $0.end >= verse }) else { continue }
                let location = VerseLocation(book: bookID, chapter: chapter, verse: target.start)
                result[location, default: []].append(SectionHeading(text: row["text"], level: row["level"]))
            }
            return result
        }
    }

    /// The KJV's own title row when present, else the app's table, else the bare book name.
    public func bookTitle(bookID: String, translationID: String) throws -> BookTitle {
        let stored: BookTitle? = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT title, subtitle FROM book_title WHERE translation_id = ? AND book_id = ?",
                             arguments: [translationID, bookID])
                .map { BookTitle(title: $0["title"], subtitle: $0["subtitle"]) }
        }
        if let stored { return stored }
        if let app = BookTitles.app(for: bookID) { return app }
        return BookTitle(title: BookCatalog.book(code: bookID)?.name ?? bookID, subtitle: nil)
    }

    /// Verses of one translation matching `query` within `scope`: the first `limit` of them in `order`, and
    /// how many match in all. `.empty` when there is nothing to find or nothing to search in.
    public func search(_ query: SearchQuery, translationID: String, scope: SearchScope = .wholeBible,
                       order: SearchOrder = .bestMatch, limit: Int) throws -> SearchPage {
        guard let match = query.ftsMatch, let table = BibleSchema.searchTable(for: translationID) else { return .empty }
        return try queue.read { db in
            guard try db.tableExists(table) else { return .empty }
            var range: (first: Int, last: Int)?
            if scope != .wholeBible {
                let books = try Row.fetchAll(db, sql: """
                    SELECT tb.book_id, tb.first_verse_id, tb.last_verse_id
                    FROM translation_book tb JOIN book b ON b.id = tb.book_id
                    WHERE tb.translation_id = ?
                    """, arguments: [translationID])
                var first = Int.max, last = Int.min
                for row in books {
                    guard let book = BookCatalog.book(code: row["book_id"]), scope.contains(book) else { continue }
                    first = min(first, row["first_verse_id"])
                    last = max(last, row["last_verse_id"])
                }
                guard first <= last else { return .empty }
                range = (first, last)
            }
            var arguments: [any DatabaseValueConvertible] = [match]
            var within = ""
            if let range {
                within = " AND rowid BETWEEN ? AND ?"
                arguments += [range.first, range.last]
            }
            let total = try Int.fetchOne(
                db, sql: "SELECT count(*) FROM \(table) WHERE \(table) MATCH ?\(within)",
                arguments: StatementArguments(arguments)) ?? 0
            guard total > 0, limit > 0 else { return SearchPage(verses: [], total: total) }
            let ordering = order == .bestMatch ? "rank" : "f.rowid"
            let verses = try Row.fetchAll(db, sql: """
                SELECT v.book_id, v.chapter, v.verse, v.verse_end, v.text, v.break_after
                FROM \(table) f JOIN verse v ON v.id = f.rowid
                WHERE \(table) MATCH ?\(within.replacingOccurrences(of: "rowid", with: "f.rowid"))
                ORDER BY \(ordering)
                LIMIT ?
                """, arguments: StatementArguments(arguments + [limit]))
                .map { Self.verse(from: $0, translationID: translationID) }
            return SearchPage(verses: verses, total: total)
        }
    }

    private static func verse(from row: Row, translationID: String) -> Verse {
        Verse(
            id: VerseLocation(book: row["book_id"], chapter: row["chapter"], verse: row["verse"]),
            translationID: translationID,
            endVerse: row["verse_end"],
            text: row["text"],
            breakAfter: row["break_after"])
    }
}
