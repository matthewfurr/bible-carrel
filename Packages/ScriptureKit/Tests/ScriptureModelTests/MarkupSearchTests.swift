import ScriptureData
import Testing
@testable import ScriptureModel

@Suite struct MarkupSearchTests {
    @Test func referenceStringsMatchTheColumn() {
        #expect(MarkupReferenceText.string(book: "MAT", chapter: 5, verse: 3, endVerse: 3) == "Matthew 5:3")
        #expect(MarkupReferenceText.string(book: "MAT", chapter: 5, verse: 3, endVerse: 4) == "Matthew 5:3-4")
        #expect(MarkupReferenceText.string(book: "MAT", chapter: 5, verse: nil, endVerse: nil) == "Matthew 5")
        #expect(MarkupReferenceText.string(book: "PSA", chapter: 23, verse: 1, endVerse: 1) == "Psalm 23:1")
        #expect(MarkupReferenceText.string(book: "XYZ", chapter: 1, verse: 1, endVerse: 1) == "XYZ 1:1")
    }

    @Test func substringMatchesTheDisplayString() {
        #expect(MarkupSearch.matchesReference("thew 5:3", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(!MarkupSearch.matchesReference("Mark", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(!MarkupSearch.matchesReference("  ", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
    }

    @Test func referenceQueryMatchesByBookChapterAndVerse() {
        #expect(MarkupSearch.matchesReference("Matt", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(MarkupSearch.matchesReference("matt 5", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(!MarkupSearch.matchesReference("matt 6", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(MarkupSearch.matchesReference("Mt 5:4", book: "MAT", chapter: 5, verse: 3, endVerse: 5))
        #expect(!MarkupSearch.matchesReference("Mt 5:9", book: "MAT", chapter: 5, verse: 3, endVerse: 5))
        #expect(MarkupSearch.matchesReference("Mt 5:1-3", book: "MAT", chapter: 5, verse: 3, endVerse: 5))
        #expect(MarkupSearch.matchesReference("ps 23", book: "PSA", chapter: 23, verse: 1, endVerse: 1))
    }
}
