import Foundation
import Testing
@testable import BibleImporterCore

@Suite struct VerseMergerTests {
    private func entries(_ pairs: [(String, String)]) -> [HolyBookFile.Entry] {
        pairs.map { HolyBookFile.Entry(ID: $0.0, text: $0.1) }
    }

    @Test func mergesPoetryLinesAndBreaks() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([
            ("1", "Seeing the multitudes."), ("2", "He opened his mouth,"), ("2", ""),
            ("3", "Blessed are the poor in spirit,"), ("3", "for theirs is the Kingdom."), ("3", ""),
            ("4", "Blessed are those who mourn,"), ("4", "for they shall be comforted."),
        ]), warnings: &warnings)
        #expect(merged == [
            MergedVerse(number: 1, text: "Seeing the multitudes.", breakAfter: false),
            MergedVerse(number: 2, text: "He opened his mouth,", breakAfter: true),
            MergedVerse(number: 3, text: "Blessed are the poor in spirit,\nfor theirs is the Kingdom.", breakAfter: true),
            MergedVerse(number: 4, text: "Blessed are those who mourn,\nfor they shall be comforted.", breakAfter: false),
        ])
        #expect(warnings.isEmpty)
    }

    @Test func skipsNonIntegerIdsWithWarning() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("1", "a"), ("1a", "b"), ("2", "c")]), warnings: &warnings)
        #expect(merged.map(\.number) == [1, 2])
        #expect(warnings.count == 1)
    }

    @Test func verseWithOnlyEmptyEntriesIsDropped() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("1", "a"), ("2", ""), ("3", "c")]), warnings: &warnings)
        #expect(merged.map(\.number) == [1, 3])
        #expect(warnings.count == 1)
    }

    @Test func rangeIdsBecomeOneVerseWithEndNumber() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("11", "a"), ("12-13", "b"), ("12-13", "c"), ("14", "d")]), warnings: &warnings)
        #expect(merged == [
            MergedVerse(number: 11, text: "a", breakAfter: false),
            MergedVerse(number: 12, endNumber: 13, text: "b\nc", breakAfter: false),
            MergedVerse(number: 14, text: "d", breakAfter: false),
        ])
        #expect(warnings.isEmpty)
    }

    @Test func malformedRangesAreSkipped() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("1", "a"), ("15+SIR", "b"), ("5-3", "c"), ("6", "d")]), warnings: &warnings)
        #expect(merged.map(\.number) == [1, 6])
        #expect(warnings.count == 2)
    }

    @Test func trimsWhitespaceAndTreatsBlankAsEmpty() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("1", "  a line "), ("1", " second  "), ("1", "   "), ("2", "\tb")]), warnings: &warnings)
        #expect(merged == [
            MergedVerse(number: 1, text: "a line\nsecond", breakAfter: true),
            MergedVerse(number: 2, text: "b", breakAfter: false),
        ])
        #expect(warnings.isEmpty)
    }

    @Test func trimsLinesEmbeddedInOneEntry() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("1", "He said, \n“Come.” \n\n"), ("2", "b")]), warnings: &warnings)
        #expect(merged[0].text == "He said,\n“Come.”")
        #expect(merged[0].breakAfter == false)
    }

    @Test func matthew5FixtureYields48Verses() throws {
        let file = try Fixtures.load("NT/MAT/WEB.json")
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(file.text[4].text, warnings: &warnings)
        #expect(merged.count == 48)
        #expect(merged.map(\.number) == Array(1...48))
        #expect(merged[2].text.contains("\n"))
    }
}
