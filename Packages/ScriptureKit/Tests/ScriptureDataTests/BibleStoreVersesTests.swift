import Foundation
import Testing
@testable import ScriptureData

@Suite struct BibleStoreVersesTests {
    private var store: BibleStore { get throws { try BibleStore(databaseURL: try FixtureDatabase.build()) } }

    @Test func oneReadReturnsTheVersesInEachTranslationThatHasThem() throws {
        let john15 = ChapterLocation(book: "JHN", chapter: 15)
        let found = try store.verses(in: john15, verse: 4, endVerse: 5, translationIDs: ["KJV", "WEB", "ESV"])
        #expect(Set(found.keys) == ["KJV", "WEB"])                                   // the fixture has no ESV
        #expect(found["KJV"] == (try store.chapter(john15, translationID: "KJV")).filter { (4...5).contains($0.id.verse) })
        #expect(try store.verses(in: ChapterLocation(book: "MAT", chapter: 5), verse: 3, endVerse: 3, translationIDs: ["KJV", "WEB"]).keys.sorted() == ["WEB"])
        #expect(try store.verses(in: john15, verse: 4, endVerse: 5, translationIDs: []).isEmpty)
    }

    @Test func aCombinedVerseAnswersForEveryVerseItHolds() throws {
        let store = try FixtureDatabase.tinyStore([("ERV", 11, nil), ("ERV", 12, 13), ("KJV", 12, nil), ("KJV", 13, nil)])
        let found = try store.verses(in: ChapterLocation(book: "JHN", chapter: 3), verse: 13, endVerse: 13, translationIDs: ["ERV", "KJV"])
        #expect(found["ERV"]?.map(\.id.verse) == [12] && found["ERV"]?.first?.endVerse == 13 && found["KJV"]?.map(\.id.verse) == [13])
    }
}
