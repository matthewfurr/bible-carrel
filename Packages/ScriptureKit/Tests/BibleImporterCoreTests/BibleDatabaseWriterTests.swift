import Foundation
import GRDB
import Testing
@testable import BibleImporterCore
import ScriptureData

@Suite struct BibleDatabaseWriterTests {
    @Test func importsFixturesIntoSQLite() throws {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: out) }

        let writer = try BibleDatabaseWriter(outputURL: out)
        let report = try writer.importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "test")

        #expect(report.bookCount == 4)        // MAT/WEB, PSA/KJV, TOB/WEB, SUS/WEB; LKA and empty MAN skipped
        #expect(report.warnings.count == 3)   // LKA skip, empty MAN book, empty SUS 1:3 marker
        #expect(report.verseCount > 3000)

        let q = try DatabaseQueue(path: out.path)
        try q.read { db in
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM translation") == 2)
            try #expect(Int.fetchOne(db, sql: "SELECT chapter_count FROM translation_book WHERE translation_id='KJV' AND book_id='PSA'") == 150)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse WHERE translation_id='KJV' AND book_id='PSA' AND chapter=119") == 176)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse WHERE translation_id='WEB' AND book_id='MAT' AND chapter=5") == 48)
            try #expect(String.fetchOne(db, sql: "SELECT canon FROM book WHERE id='TOB'") == "AP")
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse_fts_WEB WHERE verse_fts_WEB MATCH '\"poor in spirit\"'") == 1)
            try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key='source_commit'") == "test")
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse WHERE book_id='LKA'") == 0)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse WHERE verse_end IS NOT NULL") == 0)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM translation_book WHERE book_id='MAN'") == 0)
            try #expect(Int.fetchOne(db, sql: "SELECT chapter_count FROM translation_book WHERE translation_id='WEB' AND book_id='SUS'") == 1)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM cross_reference") == 0)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM person") == 0 && Int.fetchOne(db, sql: "SELECT count(*) FROM place") == 0)
            try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'theographic_commit'") == nil)
        }
    }

    @Test func theFixtureLibraryLandsAtSchemaSix() throws {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: out) }
        let report = try BibleDatabaseWriter(outputURL: out).importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "test",
            theographic: root.appendingPathComponent("Theographic"))
        #expect(report.personCount == 13 && report.placeCount == 9 && report.eventCount == 15)
        let q = try DatabaseQueue(path: out.path)
        try q.read { db in
            func count(_ table: String) throws -> Int? { try Int.fetchOne(db, sql: "SELECT count(*) FROM \(table)") }
            try #expect(count("person_verse") == 37 && count("place_verse") == 22 && count("event_passage") == 18)
            try #expect(count("person_relation") == 14 && count("book_writer") == 3)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM person WHERE name = 'Jacob'") == 2)          // ids, not names, are the keys
            try #expect(Int.fetchOne(db, sql: "SELECT verse_count FROM person WHERE id = 905") == 7)
            try #expect(String.fetchOne(db, sql: "SELECT point FROM place WHERE id = 1263") == "31.777,35.235")
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM place WHERE latitude IS NULL") == 2)
            try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'schema_version'") == "6")
            try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'theographic_commit'") == "fixture")
            let jacob = try #require(try Row.fetchOne(db, sql: "SELECT duration_days, part_of, person_id FROM event WHERE id = 86"))
            #expect(jacob["duration_days"] == 147 * 365.25 && (jacob["part_of"] as Int?) == nil && jacob["person_id"] == 682)
            try #expect(Int.fetchOne(db, sql: "SELECT part_of FROM event WHERE id = 129") == 121)
        }
    }

    /// A Theographic folder that yields no person (a re-pin to tables in a new shape) fails the import.
    @Test func aFolderWithNoPeopleFailsTheImport() throws {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: out)
            try? FileManager.default.removeItem(at: folder)
        }
        try FileManager.default.copyItem(at: root.appendingPathComponent("Theographic"), to: folder)
        try "[]".write(to: folder.appendingPathComponent("people.json"), atomically: true, encoding: .utf8)
        #expect(throws: BibleDatabaseWriter.ImportFailure.noPeople(folder)) {
            try BibleDatabaseWriter(outputURL: out).importAll(
                from: SourceTree(root: root), translations: ["WEB": "World English Bible"], sourceCommit: "test", theographic: folder)
        }
    }

    @Test func theFixtureLinksLandKeyedBothWaysAtSchemaSix() throws {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: out) }
        let report = try BibleDatabaseWriter(outputURL: out).importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "test",
            crossReferences: root.appendingPathComponent("CrossRefs/cross_references.txt"))
        #expect(report.crossReferenceCount == 20)
        let q = try DatabaseQueue(path: out.path)
        try q.read { db in
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM cross_reference WHERE votes >= 1") == 20)
            try #expect(Int.fetchOne(db, sql: "SELECT votes FROM cross_reference WHERE source = 40005003 AND target_start = 40005047 AND target_end = 40006004") == 2)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM cross_reference WHERE 64001014 IN (source, target_end)") == 2)
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM cross_reference WHERE 64001015 IN (source, target_end)") == 0)
            let indexes = try Set(String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'cross_reference' AND name NOT LIKE 'sqlite_%'"))
            #expect(indexes == ["cross_reference_target", "cross_reference_spanning"])
            try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'schema_version'") == "6")
        }
    }

    /// A cross-reference file given that yields no link (a re-pin to a file in a new shape) fails the
    /// import, rather than building a database with no cross-references in it.
    @Test func aCrossReferenceFileThatYieldsNoLinkFailsTheImport() throws {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-cross_references.txt")
        defer {
            try? FileManager.default.removeItem(at: out)
            try? FileManager.default.removeItem(at: file)
        }
        try "From Verse\tTo Verse\tVotes\tnotes\nMatthew 5:3 -> James 2:5 (12)\nMatt.5\tPs.1.1\t5\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(throws: BibleDatabaseWriter.ImportFailure.noCrossReferences(file)) {
            try BibleDatabaseWriter(outputURL: out).importAll(
                from: SourceTree(root: root), translations: ["WEB": "World English Bible"], sourceCommit: "test", crossReferences: file)
        }
    }

    @Test func eachTranslationHasItsOwnUnstemmedIndexOverUnbrokenRuns() throws {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: out) }
        _ = try BibleDatabaseWriter(outputURL: out).importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "test")
        let q = try DatabaseQueue(path: out.path)
        try q.read { db in
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse_fts_KJV WHERE verse_fts_KJV MATCH '\"poor in spirit\"'") == 0)   // Matthew is WEB's
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master WHERE name = 'verse_fts'") == 0)
            // The words as written: "bless" and "blessed" are two words.
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse_vocab_WEB WHERE term IN ('bless', 'blessed')") == 2)
            // Each book is one unbroken run of ids, recorded, and the runs follow canon order in a translation.
            let runs = try Row.fetchAll(db, sql: """
                SELECT tb.first_verse_id = min(v.id) AND tb.last_verse_id = max(v.id) AND max(v.id) - min(v.id) + 1 = count(*) AS whole, min(v.id) AS first
                FROM translation_book tb JOIN verse v ON v.translation_id = tb.translation_id AND v.book_id = tb.book_id
                JOIN book b ON b.id = tb.book_id GROUP BY tb.translation_id, tb.book_id ORDER BY tb.translation_id, b.sort_order
                """)
            #expect(runs.count == 4 && runs.allSatisfy { $0["whole"] == true })
            #expect(runs.map { $0["first"] as Int } == runs.map { $0["first"] as Int }.sorted())
            for id in ["", "E SV", "x\"; DROP TABLE verse; --", "ÉSV"] { #expect(BibleSchema.searchTable(for: id) == nil, "\(id)") }
        }
    }
}
