import Foundation
import GRDB
import Testing
@testable import ScriptureData

@Suite struct BibleStoreTests {
    private func store() throws -> BibleStore {
        try BibleStore(databaseURL: try FixtureDatabase.build())
    }

    @Test func translationsAndBooks() throws {
        let store = try store()
        #expect(try store.translations().map(\.id) == ["KJV", "WEB"])
        let web = try store.books(in: "WEB")
        #expect(web.map(\.book.id) == ["MAT", "JHN", "TOB", "SUS"])      // canon order; empty MAN absent
        #expect(web.first?.chapterCount == 28)
    }

    @Test func chapterReturnsVersesInOrderWithPoetry() throws {
        let verses = try store().chapter((book: "MAT", chapter: 5), translationID: "WEB")
        #expect(verses.count == 48)
        #expect(verses[2].id == VerseLocation(book: "MAT", chapter: 5, verse: 3))
        #expect(verses[2].text.contains("\n"))
        #expect(verses[1].breakAfter)
        #expect(verses[2].endVerse == nil)
    }

    @Test func chapterWithGapsIsNotPadded() throws {
        let verses = try store().chapter((book: "PSA", chapter: 119), translationID: "KJV")
        #expect(verses.map(\.id.verse) == Array(1...176))
    }

    @Test func sparseChapterReturnsOnlyPresentVerses() throws {
        let verses = try store().chapter((book: "SUS", chapter: 1), translationID: "WEB")
        #expect(verses.map(\.id.verse) == [1, 2, 4, 5])
        #expect(verses[1].breakAfter)   // the omitted verse 3 marked a paragraph break
    }

    @Test func missingChapterReturnsEmpty() throws {
        #expect(try store().chapter((book: "MAT", chapter: 99), translationID: "WEB") == [])
    }

    /// `Scripts/ensure-bible.sh` reads the version from the source with this pattern, so an old database is rebuilt.
    @Test func theBuildScriptsPatternReadsTheSchemaVersion() throws {
        let schemaSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/ScriptureData/BibleSchema.swift")
        let source = try String(contentsOf: schemaSourceURL, encoding: .utf8)
        let match = try #require(source.firstMatch(of: /static let version = ([0-9]+)/))
        #expect(Int(match.1) == BibleSchema.version && BibleSchema.version == 6)
    }

    @Test func schemaMismatchThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("old-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let q = try DatabaseQueue(path: url.path)
        try q.write { db in
            try db.execute(sql: "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL); INSERT INTO meta VALUES ('schema_version', '0')")
        }
        #expect(throws: BibleStoreError.schemaMismatch(found: 0, expected: BibleSchema.version)) {
            try BibleStore(databaseURL: url)
        }
    }

    /// What makes `Scripts/ensure-bible.sh` rebuild a database built before schema 6.
    @Test func aDatabaseAtSchemaFiveIsRefused() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("five-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let q = try DatabaseQueue(path: url.path)
        try q.write { db in
            try db.execute(sql: "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL); INSERT INTO meta VALUES ('schema_version', '5')")
        }
        #expect(throws: BibleStoreError.schemaMismatch(found: 5, expected: 6)) {
            try BibleStore(databaseURL: url)
        }
    }

    @Test func missingDatabaseThrows() {
        #expect(throws: BibleStoreError.self) {
            try BibleStore(databaseURL: URL(fileURLWithPath: "/nonexistent/bible.sqlite"))
        }
    }
}
