import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct CrossReferencesTests {
    private func mt(_ chapter: Int, _ verse: Int) -> VerseLocation { VerseLocation(book: "MAT", chapter: chapter, verse: verse) }
    private func load(_ verse: VerseLocation) throws -> CrossReferences {
        try CrossReferences.load(verse, translationID: "WEB", store: FixtureStore.make())
    }
    private func names(_ rows: [CrossReferences.Row]) -> [String] { rows.map(\.reference.displayString) }

    @Test func theShortListIsSixOfFourVotesOrMore() throws {
        let x = try load(mt(5, 3))
        #expect(names(x.pointsTo.short) == ["Psalm 1:1", "Matthew 6:19-21", "Psalm 2:12", "Matthew 5:10", "Matthew 4:17", "Matthew 3:2"])
        #expect(x.pointsTo.count == 11 && x.pointsTo.showAllTitle == "Show all (11)")
        // This fixture's Matthew 5 ends at verse 5, before the target's first verse: the single verse.
        #expect(names(Array(x.pointsTo.all.suffix(5))) == ["Matthew 6:33", "Isaiah 57:15", "Matthew 5:47", "Matthew 5:1-4", "Luke 6:20"])
        let runsOn = CrossReference(source: mt(5, 3), target: mt(5, 47), targetEnd: mt(6, 4), votes: 2, openingText: "x", chapterEnd: 48)
        #expect(CrossReferences.Row(pointingTo: runsOn).reference.displayString == "Matthew 5:47-48")    // cut to its first chapter's part
        #expect(names(x.pointsHere.short) == ["Matthew 6:33", "Psalm 1:1", "Matthew 6:20", "Psalm 2:12", "Matthew 4:25"])
        #expect(x.pointsHere.count == 7 && names(x.pointsHere.all).last == "3 John 1:14")
        let first = x.pointsTo.short[0], isaiah = x.pointsTo.all[7]
        #expect(first.canOpen && first.opening?.contains("\n") == false && first.accessibilityLabel == "Psalm 1:1, \(first.opening ?? "")")
        #expect(isaiah.opening == nil && !isaiah.canOpen && isaiah.accessibilityLabel == "Isaiah 57:15")
    }

    @Test func aGroupUnderFourVotesStillOffersItsLinks() throws {
        let x = try load(mt(5, 4))
        #expect(x.pointsTo.short.isEmpty && x.pointsTo.count == 1 && x.pointsTo.showsShowAll && !x.isEmpty)
        #expect(names(x.pointsHere.all) == ["Matthew 6:33", "Matthew 6:20", "Matthew 5:3"] && x.pointsHere.short.count == 2)
        #expect(try !load(mt(6, 20)).pointsTo.showsShowAll)                  // one link at six votes: nothing more to show
    }

    @Test func aVerseWithNoLinksSaysSoAndTheChevronsStopAtTheChaptersEnds() throws {
        #expect(try load(mt(5, 20)).isEmpty && CrossReferences.emptyLine == "No cross-references for this verse.")
        let three = try load(mt(5, 3))
        #expect(three.previous == mt(5, 2) && three.next == mt(5, 4))
        let one = try load(mt(5, 1)), five = try load(mt(5, 5))
        #expect(one.previous == nil && five.next == nil)     // this fixture's Matthew 5 is verses 1 to 5
        let tobit = try load(VerseLocation(book: "TOB", chapter: 1, verse: 1))   // the data covers the 66 books
        #expect(tobit.isEmpty && tobit.previous == nil && tobit.next != nil)
    }

    @Test func askNeedsAVerseAndAShortList() throws {
        #expect(try load(mt(5, 3)).canAsk && !load(mt(5, 20)).canAsk)
        let four = try load(mt(5, 4))                                        // nothing out at four votes; two in
        let question = try four.question(store: FixtureStore.make())
        #expect(four.canAsk && !question.contains("This verse points to:"))
        #expect(CrossReferences.credit == "Cross-references: OpenBible.info" && CrossReferences.creditLink.host() == "www.openbible.info")
    }

    @Test func aPassageOfSeveralVersesCarriesEachVersesNumber() throws {
        let store = try FixtureStore.make()
        let reference = Reference(book: BookCatalog.book(code: "PSA")!, chapter: 1, verse: 1, endVerse: 2)
        let text = try #require(try CrossReferences.passageText(reference, translationID: "WEB", store: store))
        #expect(text.hasPrefix("1 ") && text.contains(" 2 ") && !text.contains("\n"))
    }
}
