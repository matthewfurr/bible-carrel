import BibleImporterCore
import Foundation
import GRDB
import ScriptureData

/// Builds a small bible.sqlite from the public-domain fixtures once per test process.
enum FixtureDatabase {
    private static let shared: Result<URL, Error> = {
        Result {
            let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
            let out = FileManager.default.temporaryDirectory
                .appendingPathComponent("ScriptureDataTests-\(UUID().uuidString).sqlite")
            let writer = try BibleDatabaseWriter(outputURL: out)
            _ = try writer.importAll(
                from: SourceTree(root: root),
                translations: ["WEB": "World English Bible", "KJV": "King James Version"],
                sourceCommit: "fixture",
                crossReferences: root.appendingPathComponent("CrossRefs/cross_references.txt"),
                theographic: root.appendingPathComponent("Theographic"))
            try addHeadingsAndTitles(to: out)
            return out
        }
    }()

    /// A few BSB heading rows and a KJV book title, written straight into the built file.
    private static func addHeadingsAndTitles(to url: URL) throws {
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            let headings: [(String, Int, Int, Int, Int, String)] = [
                ("SUS", 1, 3, 0, 1, "Fixture Heading"),     // WEB has no SUS 1:3, so it lands on 1:4
                ("SUS", 1, 9, 0, 1, "Past The End"),        // after the chapter's last verse: dropped
                ("MAT", 5, 3, 1, 2, "Second Heading"),      // inserted first, ordered by ordinal
                ("MAT", 5, 3, 0, 1, "First Heading"),
            ]
            for (book, chapter, verse, ordinal, level, text) in headings {
                try db.execute(
                    sql: "INSERT INTO heading (source, book_id, chapter, verse, ordinal, level, text) VALUES ('bsb', ?, ?, ?, ?, ?, ?)",
                    arguments: [book, chapter, verse, ordinal, level, text])
            }
            try db.execute(
                sql: "INSERT INTO book_title (translation_id, book_id, title, subtitle) VALUES ('KJV', 'PSA', 'Psalms', 'The Book of Psalms')")
        }
    }

    static func build() throws -> URL {
        try shared.get()
    }

    /// A database of its own: John 3 verses as given (translation, verse, verse end) and `links`
    /// (source, target start, target end, votes: verse keys), nothing else.
    static func tinyStore(_ verses: [(String, Int, Int?)], links: [(Int, Int, Int, Int)] = []) throws -> BibleStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScriptureDataTests-tiny-\(UUID().uuidString).sqlite")
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            try BibleSchema.create(in: db)
            try db.execute(sql: "INSERT INTO meta VALUES ('schema_version', ?)", arguments: [String(BibleSchema.version)])
            for (translation, verse, end) in verses {
                try db.execute(
                    sql: "INSERT INTO verse (translation_id, book_id, chapter, verse, verse_end, text, break_after) VALUES (?, 'JHN', 3, ?, ?, ?, 0)",
                    arguments: [translation, verse, end, "\(translation) \(verse)"])
            }
            for (source, start, end, votes) in links {
                try db.execute(sql: "INSERT INTO cross_reference VALUES (?, ?, ?, ?)", arguments: [source, start, end, votes])
            }
        }
        try queue.close()
        return try BibleStore(databaseURL: url)
    }
}
