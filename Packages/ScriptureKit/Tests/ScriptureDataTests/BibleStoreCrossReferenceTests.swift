import Foundation
import Testing
@testable import ScriptureData

@Suite struct BibleStoreCrossReferenceTests {
    private var store: BibleStore { get throws { try BibleStore(databaseURL: try FixtureDatabase.build()) } }
    private func mt(_ chapter: Int, _ verse: Int) -> VerseLocation { VerseLocation(book: "MAT", chapter: chapter, verse: verse) }
    private func ps(_ chapter: Int, _ verse: Int) -> VerseLocation { VerseLocation(book: "PSA", chapter: chapter, verse: verse) }
    private func at(_ book: String, _ chapter: Int, _ verse: Int) -> VerseLocation { VerseLocation(book: book, chapter: chapter, verse: verse) }

    @Test func pointsToIsInVoteOrderWithOpeningWords() throws {
        let store = try store
        let to = try store.crossReferences(from: mt(5, 3), translationID: "WEB")
        #expect(to.map(\.votes) == [12, 9, 7, 6, 5, 4, 4, 3, 2, 1, 1])
        #expect(to.map(\.target) == [ps(1, 1), mt(6, 19), ps(2, 12), mt(5, 10), mt(4, 17), mt(3, 2), mt(6, 33),
                                     at("ISA", 57, 15), mt(5, 47), mt(5, 1), at("LUK", 6, 20)])      // a tie goes in canon order
        #expect(to[1].targetEnd == mt(6, 21) && to[1].chapterEnd == nil)
        #expect(to[8].targetEnd == mt(6, 4) && to[8].chapterEnd == 48)                               // runs into chapter 6
        #expect(to[3].openingText == (try store.chapter((book: "MAT", chapter: 5), translationID: "WEB"))[9].text)
        #expect(to[0].openingText == nil && to[7].openingText == nil)                                // no Psalms or Isaiah in this WEB
        let joined = try FixtureDatabase.tinyStore([("ERV", 12, 13)], links: [(43003001, 43003013, 43003013, 5)])
        #expect(try joined.crossReferences(from: VerseLocation(book: "JHN", chapter: 3, verse: 1), translationID: "ERV").first?.openingText != nil)
    }

    @Test func pointsHereFindsRangesThatHoldTheVerseAndNeverTheVerseItself() throws {
        let store = try store
        let here = try store.crossReferences(to: mt(5, 3), translationID: "WEB")
        #expect(here.map(\.source) == [mt(6, 33), ps(1, 1), mt(6, 20), ps(2, 12), mt(4, 25), mt(5, 4), at("3JN", 1, 14)])
        #expect(here.map(\.votes) == [9, 8, 6, 5, 4, 2, 2])                  // Matthew 5:3's own 5:1-4 is not among them
        #expect(try store.crossReferences(to: mt(1, 1), translationID: "WEB").map(\.source) == [at("MAL", 4, 6)])   // begun in another book
        #expect(try store.crossReferences(to: mt(5, 1), translationID: "WEB").map(\.source) == [mt(6, 33), ps(2, 12), mt(4, 25), mt(5, 3)])
        #expect(try store.crossReferences(to: mt(5, 20), translationID: "WEB").isEmpty)
        #expect(try store.crossReferences(from: at("TOB", 1, 1), translationID: "WEB").isEmpty)
    }
}
