import Foundation
import GRDB
import Testing
@testable import BibleImporterCore
import ScriptureData

private func fixture(_ name: String) throws -> String {
    let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/USFM/\(name)")
    return try String(contentsOf: url, encoding: .utf8)
}

@Suite struct USFMHeadingsTests {
    @Test func bsbHeadingsAttachToTheNextVerse() throws {
        let book = try #require(USFMHeadings.parse(fixture("73-JHNengbsb.usfm")))
        #expect(book.bookID == "JHN")
        #expect(book.headings.prefix(3) == [
            USFMHeading(chapter: 1, verse: 1, ordinal: 0, level: 1, text: "The Beginning"),
            USFMHeading(chapter: 1, verse: 6, ordinal: 0, level: 1, text: "The Witness of John"),
            USFMHeading(chapter: 1, verse: 14, ordinal: 0, level: 1, text: "The Word Became Flesh"),
        ])
    }

    @Test func parallelReferencesAndPsalmTitlesAreNotHeadings() throws {
        let usfm = """
        \\id PSA - Test
        \\c 3
        \\s1 A Psalm
        \\r (Psalm 4:1)
        \\d A Psalm of David.
        \\ms1 BOOK I
        \\q1
        \\v 1 O \\w LORD|strong="H3068"\\w*
        """
        let book = try #require(USFMHeadings.parse(usfm))
        #expect(book.headings == [USFMHeading(chapter: 3, verse: 1, ordinal: 0, level: 1, text: "A Psalm")])
    }

    @Test func aHeadingBeforeAChapterMarkerBelongsToThatChaptersFirstVerse() throws {
        let usfm = "\\id GEN - Test\n\\c 1\n\\v 1 In the beginning\n\\s1 X\n\\c 2\n\\p\n\\v 1 Thus"
        let book = try #require(USFMHeadings.parse(usfm))
        #expect(book.headings == [USFMHeading(chapter: 2, verse: 1, ordinal: 0, level: 1, text: "X")])
    }

    @Test func severalHeadingsBeforeOneVerseAreOrderedAndStripped() throws {
        let usfm = "\\id GEN - Test\n\\c 1\n\\s1 The \\w Creation|strong=\"H1\"\\w*\\f + \\fr 1:1 \\ft note\\f*\n\\s2 The First Day\n\\v 1 In"
        let book = try #require(USFMHeadings.parse(usfm))
        #expect(book.headings == [
            USFMHeading(chapter: 1, verse: 1, ordinal: 0, level: 1, text: "The Creation"),
            USFMHeading(chapter: 1, verse: 1, ordinal: 1, level: 2, text: "The First Day"),
        ])
    }

    @Test func kjvMainTitleIsTitleCased() throws {
        let book = try #require(USFMHeadings.parse(fixture("73-JHNeng-kjv.usfm")))
        #expect(book.mainTitle.map(USFMHeadings.titleCased) == "The Gospel According to St. John")
        #expect(USFMHeadings.titleCased("THE FIRST BOOK OF MOSES, CALLED GENESIS") == "The First Book of Moses, called Genesis")
        #expect(USFMHeadings.titleCased("Already Mixed Case") == "Already Mixed Case")
    }

    @Test func writerStoresHeadingsAndTitles() throws {
        let fm = FileManager.default
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let ebible = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: ebible) }
        let usfm = root.appendingPathComponent("USFM")
        for (folder, name) in [("engbsb_usfm", "73-JHNengbsb.usfm"), ("eng-kjv_usfm", "73-JHNeng-kjv.usfm")] {
            let dir = ebible.appendingPathComponent(folder)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try fm.copyItem(at: usfm.appendingPathComponent(name), to: dir.appendingPathComponent(name))
        }
        let out = fm.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        defer { try? fm.removeItem(at: out) }

        let writer = try BibleDatabaseWriter(outputURL: out)
        _ = try writer.importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "test",
            ebible: ebible)

        let q = try DatabaseQueue(path: out.path)
        try q.read { db in
            try #expect(String.fetchOne(db, sql: "SELECT text FROM heading WHERE source='bsb' AND book_id='JHN' AND chapter=1 AND verse=14") == "The Word Became Flesh")
            try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM heading WHERE source='bsb'") == 9)
            try #expect(String.fetchOne(db, sql: "SELECT title FROM book_title WHERE translation_id='KJV' AND book_id='JHN'") == "John")
            try #expect(String.fetchOne(db, sql: "SELECT subtitle FROM book_title WHERE translation_id='KJV' AND book_id='JHN'") == "The Gospel According to St. John")
            try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key='schema_version'") == String(BibleSchema.version))
            try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key='ebible_bsb_sha256'") != nil)
        }
    }
}
