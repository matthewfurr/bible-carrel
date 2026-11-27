import Foundation
import GRDB
import ScriptureData

public struct ImportReport: Sendable {
    public var verseCount = 0
    public var bookCount = 0
    public var crossReferenceCount = 0
    public var personCount = 0
    public var placeCount = 0
    public var eventCount = 0
    public var warnings: [ImportWarning] = []

    public init() {}
}

/// Builds `bible.sqlite` from a holybooks source tree.
public struct BibleDatabaseWriter {
    /// An import that cannot make a sound database.
    public enum ImportFailure: Error, Equatable, CustomStringConvertible {
        /// The cross-reference file given yielded no link (every line warned): OpenBible's file has a new shape.
        case noCrossReferences(URL)
        /// The Theographic folder given yielded no person: its tables have a new shape.
        case noPeople(URL)

        public var description: String {
            switch self {
            case .noCrossReferences(let file):
                "\(file.path) yielded no cross-reference; check its format before re-pinning it"
            case .noPeople(let folder):
                "\(folder.path) yielded no person; check Theographic's tables before re-pinning them"
            }
        }
    }

    private let queue: DatabaseQueue

    /// Creates a fresh database at `outputURL`, replacing any existing file.
    public init(outputURL: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm", "-journal"] {
            try? fm.removeItem(atPath: outputURL.path + suffix)
        }
        queue = try DatabaseQueue(path: outputURL.path)
        try queue.write { db in
            try BibleSchema.create(in: db)
            for book in BookCatalog.all {
                try db.execute(
                    sql: "INSERT INTO book (id, canon, sort_order, name, short_name) VALUES (?, ?, ?, ?, ?)",
                    arguments: [book.id, book.canon.rawValue, book.order, book.name, book.shortName])
            }
        }
    }

    /// Imports every book file for the given translations (`id → title`). `ebible` is the folder holding
    /// `engbsb_usfm/` and `eng-kjv_usfm/`; when given, BSB headings and KJV book titles are imported too.
    /// `crossReferences` is OpenBible's `cross_references.txt`; its `.sha256` beside it becomes the `crossrefs_sha256` meta row.
    /// A cross-reference file that yields no link throws `ImportFailure.noCrossReferences`.
    /// `theographic` is the folder of Theographic's five tables and its `commit` file; one that yields no person throws `ImportFailure.noPeople`.
    public func importAll(from tree: SourceTree, translations: [String: String], sourceCommit: String, ebible: URL? = nil, crossReferences: URL? = nil, theographic: URL? = nil) throws -> ImportReport {
        var report = ImportReport()
        try queue.write { db in
            for (id, title) in translations.sorted(by: { $0.key < $1.key }) {
                try db.execute(sql: "INSERT INTO translation (id, title) VALUES (?, ?)", arguments: [id, title])
            }
        }

        // Translation, then canon order: each book's verses take an unbroken run of ids.
        let refs = try tree.bookFiles(translations: Set(translations.keys)).sorted {
            if $0.translationID != $1.translationID { return $0.translationID < $1.translationID }
            return (BookCatalog.book(code: $0.bookCode)?.order ?? Int.max) < (BookCatalog.book(code: $1.bookCode)?.order ?? Int.max)
        }
        for ref in refs {
            guard BookCatalog.book(code: ref.bookCode) != nil else {
                report.warnings.append(ImportWarning("Skipped unknown book code \(ref.bookCode) (\(ref.translationID))"))
                continue
            }
            let file = try JSONDecoder().decode(HolyBookFile.self, from: Data(contentsOf: ref.url))
            try queue.write { db in
                var chapterCount = 0
                var firstID: Int64?
                var lastID: Int64?
                for chapter in file.text {
                    guard let number = chapter.number else {
                        report.warnings.append(ImportWarning("Skipped chapter with malformed ID \"\(chapter.ID)\" in \(ref.bookCode)/\(ref.translationID)"))
                        continue
                    }
                    var warnings: [ImportWarning] = []
                    let verses = VerseMerger.merge(chapter.text, warnings: &warnings)
                    report.warnings.append(contentsOf: warnings.map {
                        ImportWarning("\(ref.bookCode) \(number) (\(ref.translationID)): \($0.message)")
                    })
                    guard !verses.isEmpty else { continue }
                    chapterCount += 1
                    for verse in verses {
                        try db.execute(
                            sql: "INSERT INTO verse (translation_id, book_id, chapter, verse, verse_end, text, break_after) VALUES (?, ?, ?, ?, ?, ?, ?)",
                            arguments: [ref.translationID, ref.bookCode, number, verse.number, verse.endNumber, verse.text, verse.breakAfter])
                        lastID = db.lastInsertedRowID
                        firstID = firstID ?? lastID
                        report.verseCount += 1
                    }
                }
                guard chapterCount > 0 else {
                    report.warnings.append(ImportWarning("Skipped empty book \(ref.bookCode) (\(ref.translationID))"))
                    return
                }
                try db.execute(
                    sql: "INSERT INTO translation_book (translation_id, book_id, chapter_count, first_verse_id, last_verse_id) VALUES (?, ?, ?, ?, ?)",
                    arguments: [ref.translationID, ref.bookCode, chapterCount, firstID, lastID])
                report.bookCount += 1
            }
        }

        var extraMeta: [(String, String)] = []
        if let ebible {
            try importHeadings(from: ebible, into: &report)
            for (key, folder) in [("ebible_bsb_sha256", "engbsb_usfm"), ("ebible_kjv_sha256", "eng-kjv_usfm")] {
                let digest = try? String(contentsOf: ebible.appendingPathComponent("\(folder).sha256"), encoding: .utf8)
                extraMeta.append((key, digest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"))
            }
        }

        if let crossReferences {
            try importCrossReferences(from: crossReferences, into: &report)
            let digest = try? String(contentsOf: crossReferences.appendingPathExtension("sha256"), encoding: .utf8)
            extraMeta.append(("crossrefs_sha256", digest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"))
        }

        if let theographic {
            try importTheographic(from: theographic, into: &report)
            let commit = try? String(contentsOf: theographic.appendingPathComponent("commit"), encoding: .utf8)
            let trimmed = commit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            extraMeta.append(("theographic_commit", trimmed.isEmpty ? "unknown" : trimmed))
        }

        try queue.write { db in
            for id in translations.keys.sorted() {
                try BibleSchema.createSearchIndex(for: id, in: db)
            }
            let now = ISO8601DateFormatter().string(from: Date())
            let meta = [("schema_version", String(BibleSchema.version)), ("source_commit", sourceCommit), ("built_at", now)] + extraMeta
            for (key, value) in meta {
                try db.execute(sql: "INSERT INTO meta (key, value) VALUES (?, ?)", arguments: [key, value])
            }
        }
        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM")
        }
        return report
    }

    private func importCrossReferences(from file: URL, into report: inout ImportReport) throws {
        var warnings: [ImportWarning] = []
        let links = CrossReferenceFile.parse(try String(contentsOf: file, encoding: .utf8), warnings: &warnings)
        report.warnings.append(contentsOf: warnings)
        guard !links.isEmpty else { throw ImportFailure.noCrossReferences(file) }
        try queue.write { db in
            let insert = try db.makeStatement(sql: "INSERT INTO cross_reference (source, target_start, target_end, votes) VALUES (?, ?, ?, ?)")
            for link in links {
                try insert.execute(arguments: [link.source, link.targetStart, link.targetEnd, link.votes])
            }
        }
        report.crossReferenceCount = links.count
    }

    /// People, places, events, families and book writers, in one transaction.
    private func importTheographic(from folder: URL, into report: inout ImportReport) throws {
        var warnings: [ImportWarning] = []
        let tables = try TheographicTables.load(from: folder, warnings: &warnings)
        report.warnings.append(contentsOf: warnings)
        guard !tables.people.isEmpty else { throw ImportFailure.noPeople(folder) }
        try queue.write { db in
            let person = try db.makeStatement(sql: "INSERT INTO person (id, name, label, also_called, birth_year, death_year, verse_count, search_names, dictionary) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
            let personVerse = try db.makeStatement(sql: "INSERT INTO person_verse (verse, person_id) VALUES (?, ?)")
            for p in tables.people {
                try person.execute(arguments: [p.id, p.name, p.label, Self.joined(p.alsoCalled), p.birthYear, p.deathYear, p.verses.count, p.searchNames, p.dictionary])
                for verse in p.verses { try personVerse.execute(arguments: [verse, p.id]) }
            }
            let relation = try db.makeStatement(sql: "INSERT INTO person_relation (person_id, kind, ordinal, relative_id) VALUES (?, ?, ?, ?)")
            for r in tables.relations { try relation.execute(arguments: [r.personID, r.kind, r.ordinal, r.relativeID]) }
            let place = try db.makeStatement(sql: "INSERT INTO place (id, name, label, also_called, kind, latitude, longitude, point, approximate, verse_count, search_names, dictionary) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
            let placeVerse = try db.makeStatement(sql: "INSERT INTO place_verse (verse, place_id) VALUES (?, ?)")
            for p in tables.places {
                try place.execute(arguments: [p.id, p.name, p.label, Self.joined(p.alsoCalled), p.kind, p.latitude, p.longitude, p.point, p.isApproximate, p.verses.count, p.searchNames, p.dictionary])
                for verse in p.verses { try placeVerse.execute(arguments: [verse, p.id]) }
            }
            let event = try db.makeStatement(sql: "INSERT INTO event (id, title, year, sort_key, duration_days, part_of, person_id) VALUES (?, ?, ?, ?, ?, ?, ?)")
            let passage = try db.makeStatement(sql: "INSERT INTO event_passage (start, event_id, end) VALUES (?, ?, ?)")
            for e in tables.events {
                try event.execute(arguments: [e.id, e.title, e.year, e.sortKey, e.durationDays, e.partOf, e.personID])
                for run in e.passages { try passage.execute(arguments: [run.lowerBound, e.id, run.upperBound]) }
            }
            let writer = try db.makeStatement(sql: "INSERT INTO book_writer (book_id, ordinal, person_id) VALUES (?, ?, ?)")
            for w in tables.writers { try writer.execute(arguments: [w.book, w.ordinal, w.personID]) }
        }
        report.personCount = tables.people.count
        report.placeCount = tables.places.count
        report.eventCount = tables.events.count
    }

    /// The `also_called` column: the names as a JSON array of strings.
    private static func joined(_ names: [String]) -> String {
        (try? String(data: JSONEncoder().encode(names), encoding: .utf8)) ?? "[]"
    }

    private func usfmBooks(in folder: URL) throws -> [USFMBook] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "usfm" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { USFMHeadings.parse(try String(contentsOf: $0, encoding: .utf8)) }
            .filter { BookCatalog.book(code: $0.bookID) != nil }
    }

    /// BSB section headings for every book, and the KJV's own book titles.
    private func importHeadings(from ebible: URL, into report: inout ImportReport) throws {
        let bsb = try usfmBooks(in: ebible.appendingPathComponent("engbsb_usfm"))
        let kjv = try usfmBooks(in: ebible.appendingPathComponent("eng-kjv_usfm"))
        if bsb.isEmpty { report.warnings.append(ImportWarning("No BSB USFM books found in \(ebible.path)")) }
        if kjv.isEmpty { report.warnings.append(ImportWarning("No KJV USFM books found in \(ebible.path)")) }
        try queue.write { db in
            for book in bsb {
                for heading in book.headings {
                    try db.execute(
                        sql: "INSERT INTO heading (source, book_id, chapter, verse, ordinal, level, text) VALUES ('bsb', ?, ?, ?, ?, ?, ?)",
                        arguments: [book.bookID, heading.chapter, heading.verse, heading.ordinal, heading.level, heading.text])
                }
            }
            for book in kjv {
                guard let name = BookCatalog.book(code: book.bookID)?.name else { continue }
                try db.execute(
                    sql: "INSERT INTO book_title (translation_id, book_id, title, subtitle) VALUES ('KJV', ?, ?, ?)",
                    arguments: [book.bookID, name, book.mainTitle.map(USFMHeadings.titleCased)])
            }
        }
    }
}
