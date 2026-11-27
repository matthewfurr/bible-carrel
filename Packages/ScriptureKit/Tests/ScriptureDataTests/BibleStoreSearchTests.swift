import Foundation
import Testing
@testable import ScriptureData

@Suite struct BibleStoreSearchTests {
    let store: BibleStore

    init() throws {
        store = try BibleStore(databaseURL: try FixtureDatabase.build())
    }

    func find(_ typed: String, _ translation: String = "WEB", _ scope: SearchScope = .wholeBible,
              order: SearchOrder = .bibleOrder, limit: Int = 10_000) throws -> SearchPage {
        try store.search(SearchQuery(typed), translationID: translation, scope: scope, order: order, limit: limit)
    }

    func offered(_ typed: String, _ scope: SearchScope = .wholeBible) throws -> SearchSuggestion? {
        try store.suggestion(for: SearchQuery(typed), translationID: "WEB", scope: scope)
    }

    /// The matching verses in John, as "15:4".
    func john(_ typed: String, _ translation: String = "WEB") throws -> [String] {
        try find(typed, translation).verses.filter { $0.id.book == "JHN" }.map { "\($0.id.chapter):\($0.id.verse)" }
    }

    @Test func everyWordInAnyOrderAndWordStartsLetterForLetter() throws {
        // The spec's three, and 12:24, which has both words too.
        for typed in ["remain fruit", "fruit remain"] { #expect(try john(typed, "WEB") == ["12:24", "15:4", "15:5", "15:16"]) }
        let abid = try find("abid", "KJV", .book("JHN"))
        #expect(abid.total == 12 && abid.verses.contains { $0.text.contains("abide ") } && abid.verses.contains { $0.text.contains("abideth") })
        #expect(try john("abidi", "KJV") == ["5:38"] && john("ABÍD", "KJV").count == 12)   // "abiding", which the stemmed index lost
        let his = try find("his", "KJV", .book("JHN"))
        #expect(his.total > 100 && his.verses.allSatisfy { SearchQuery("his").matches($0.text) })
        #expect(!his.verses.contains { $0.id.chapter == 1 && $0.id.verse == 10 })    // "him" twice, "his" never
    }

    @Test func aPhraseIsExactAndAnExclusionIsAWholeWord() throws {
        for typed in ["\"living water\"", "“living water”", "\"LIVING water"] { #expect(try john(typed, "WEB") == ["4:10", "4:11", "7:38"]) }
        #expect(try john("\"water living\"", "WEB").isEmpty && john("\"living wat\"", "WEB").isEmpty)
        let kept = try john("jews -fear", "KJV")
        #expect(kept.contains("9:22"))                                              // "they feared the Jews"
        #expect(Set(kept).isDisjoint(with: ["7:13", "19:38", "20:19"]))             // "for fear of the Jews"
        #expect(try find("-fear", "KJV") == .empty)
    }

    @Test func aHyphenJoinsAndAnApostropheFindsThePossessive() throws {
        #expect(try john("years thirty-eight", "WEB") == ["5:5"])                   // joined, not an exclusion
        for typed in ["peter's", "Peter’s"] { #expect(try john(typed, "KJV") == ["1:40", "6:8"]) }   // never "Peter said"
    }

    @Test func eachScopeReturnsOnlyItsBooksAndTheCountsMatch() throws {
        func lord(_ scope: SearchScope, _ translation: String = "WEB") throws -> SearchPage { try find("lord", translation, scope) }
        let whole = try lord(.wholeBible), nt = try lord(.newTestament), ap = try lord(.apocrypha)
        #expect(Set(nt.verses.map(\.id.book)) == ["MAT", "JHN"] && Set(ap.verses.map(\.id.book)) == ["TOB"])
        // The Apocrypha scope reaches SUS (a word only SUS has ("fourth" is also in the NT)); the New Testament scope does not.
        #expect(try find("fifth", "WEB", .apocrypha).verses.map(\.id.book) == ["SUS"])
        #expect(try find("fifth", "WEB", .newTestament) == .empty)
        #expect(whole.total == nt.total + ap.total && whole.total == whole.verses.count)
        #expect(nt.total == (try lord(.book("MAT")).total) + (try lord(.book("JHN")).total))
        #expect(try lord(.oldTestament) == .empty)                                  // the fixture's WEB has no Old Testament
        #expect(Set(try lord(.oldTestament, "KJV").verses.map(\.id.book)) == ["PSA"])
        #expect(try lord(.book("GEN")) == .empty && lord(.wholeBible, "NIV") == .empty && lord(.wholeBible, "x\" OR 1=1 --") == .empty)
        let three = try store.search(SearchQuery("lord"), translationID: "WEB", limit: 3)
        #expect(three.verses.count == 3 && three.total == whole.total)              // a limit never shortens the count
        let none = try store.search(SearchQuery("lord"), translationID: "WEB", limit: 0)
        #expect(none.verses.isEmpty && none.total == whole.total)                   // limit 0 is the count alone
        #expect(SearchScope.sections(in: try store.books(in: "WEB")) == [.wholeBible, .newTestament, .apocrypha])
        // Bible order is canon order; best match holds the same verses.
        func key(_ verse: VerseLocation) -> [Int] { [BookCatalog.book(code: verse.book)!.order, verse.chapter, verse.verse] }
        let ordered = whole.verses.map(\.id)
        #expect(ordered == ordered.sorted { key($0).lexicographicallyPrecedes(key($1)) })
        #expect(Set(try find("lord", order: .bestMatch).verses.map(\.id)) == Set(ordered))
    }

    @Test func aPastedVerseFindsItselfAndNoTypedTextThrows() throws {
        let verse = try store.chapter((book: "JHN", chapter: 15), translationID: "WEB")[4]
        #expect(try find(verse.text + "\n").verses.map(\.id) == [verse.id])
        let long = Array(repeating: "the lord said", count: 100).joined(separator: " ")
        for typed in ["\"; DROP TABLE verse; --", "((((", "\"\"\"x", "NEAR/2 y", "a\u{0}b", "*", long] { _ = try find(typed) }
    }

    @Test func aSuggestionComesFromTheTranslationsOwnWordsAndOnlyWhenItFindsSomething() throws {
        let web = try store.words(in: "WEB"), kjv = try store.words(in: "KJV")
        let niv = try store.words(in: "NIV")
        #expect(web.map(\.word) == web.map(\.word).sorted() && niv.isEmpty)
        #expect(kjv.contains { $0.word == "abideth" } && !web.contains { $0.word == "abideth" })
        #expect(web.first { $0.word == "fruit" }?.verses == (try find("\"fruit\"").total))
        #expect(try offered("frut") == SearchSuggestion(query: "fruit", verseCount: try find("fruit").total))
        #expect(try offered("remain frut", .book("JHN")) == SearchSuggestion(query: "remain fruit", verseCount: 4))
        for typed in ["\"frut\"", "frut -vine", "qqqqzz", "frut 144000"] { #expect(try offered(typed) == nil, "\(typed)") }
        #expect(try offered("frut", .oldTestament) == nil)                          // nothing there to find
    }
}
