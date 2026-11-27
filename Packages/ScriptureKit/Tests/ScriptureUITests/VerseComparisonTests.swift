import Foundation
import Testing
import ScriptureData
@testable import ScriptureUI

@Suite struct VerseComparisonTests {
    private func compare(_ book: String, _ chapter: Int, _ verses: ClosedRange<Int>, reading: String, set: [String]) throws -> VerseComparison {
        let selection = TextSelection(book: book, chapter: chapter, verse: verses.lowerBound, endVerse: verses.upperBound,
                                      startOffset: 0, endOffset: 0, quotedText: "")
        return try VerseComparison.load(selection: selection, readingTranslationID: reading, compareSet: set,
                                        translations: ["AMP", "KJV", "NASB", "WEB"].map { Translation(id: $0, title: $0) },
                                        store: try FixtureStore.make())
    }

    @Test func theReadingTranslationLeadsThenTheSetInTheListsOrder() throws {
        let c = try compare("MAT", 5, 3...3, reading: "WEB", set: ["WEB", "NASB", "KJV", "XYZ"])
        #expect(c.rows.map(\.translationID) == ["WEB", "KJV", "NASB"])       // the list's order; WEB once; XYZ is not bundled
        #expect(c.rows.map(\.isReading) == [true, false, false] && c.countLabel == "3 translations" && c.cutLine == nil)
        #expect(c.rows[1].text.hasPrefix("Blessed are the poor in spirit: for theirs"))     // one verse: no number
        #expect(c.rows[1].accessibilityLabel.hasPrefix("KJV: Blessed") && c.rows[0].accessibilityLabel.hasPrefix("WEB, reading: "))
        // A translation lacking the verse says so, cannot be opened, and is neither asked about nor copied.
        #expect(c.rows[2].missingLine == "Not in the NASB." && !c.rows[2].canOpen && c.rows[1].canOpen)
        #expect(c.otherTranslationIDs == ["KJV"] && c.copyText.components(separatedBy: "\n").count == 2)
        // The row being read is the verse the reader is on: it closes the panel and looks nothing up.
        #expect(c.rows[0].canOpen && !c.rows[0].looksUp && c.rows[1].looksUp && !c.rows[2].looksUp)
        let alone = try compare("MAT", 5, 3...3, reading: "WEB", set: [])
        #expect(alone.rows.map(\.translationID) == ["WEB"] && alone.countLabel == "1 translation" && alone.otherTranslationIDs.isEmpty)
    }

    @Test func aRangeShowsEachVerseAndMoreThanFiveIsCutWithItsLine() throws {
        let psalm = try compare("PSA", 1, 1...2, reading: "KJV", set: ["WEB"])
        #expect(psalm.reference.displayString == "Psalm 1:1-2")
        #expect(psalm.rows.allSatisfy { $0.text.hasPrefix("1 ") && $0.text.contains(" 2 ") && !$0.text.contains("\n") })   // poetry runs together
        let c = try compare("PSA", 118, 3...12, reading: "KJV", set: ["WEB"])           // the fixture's one long chapter, in the KJV alone
        #expect(c.reference.displayString == "Psalm 118:3-7" && c.cutLine == "Showing the first 5 of 10 verses.")
        #expect(c.rows[0].verses.map(\.id.verse) == [3, 4, 5, 6, 7] && c.rows[1].missingLine == "Not in the WEB." && c.selection.endVerse == 7)
    }

    @Test func theCPDVsLineShowsInPsalmsOnlyAndCopyIsEveryRowWithItsReference() throws {
        #expect(VerseComparison.note(translationID: "CPDV", book: "PSA") == "The CPDV numbers the Psalms differently; this may be a neighboring verse.")
        #expect(VerseComparison.note(translationID: "CPDV", book: "JHN") == nil && VerseComparison.note(translationID: "KJV", book: "PSA") == nil)
        let lines = try compare("MAT", 5, 3...4, reading: "WEB", set: ["KJV"]).copyText.components(separatedBy: "\n")
        #expect(lines.count == 2 && lines[0].hasSuffix("\u{201D} \u{2014} Matthew 5:3-4 (WEB)"))
        #expect(lines[1].hasPrefix("\u{201C}Blessed are the poor in spirit: for theirs") && lines[1].hasSuffix("\u{201D} \u{2014} Matthew 5:3-4 (KJV)"))
        #expect(!lines[1].contains("4 Blessed"))                              // no verse numbers on the pasteboard
    }

    /// Spec 4.1: part of a verse counts as the whole verse. Ask persists the selection's offsets and a reply
    /// saved as a note makes a highlight of them, so they are the verses shown, whole, exactly as the reader
    /// reports a J or ⇧J selection of them, with the first row's words as the quoted text.
    @MainActor @Test func itsSelectionIsTheVersesShownWholeAsTheReaderReportsThem() throws {
        let store = try FixtureStore.make()
        func whole(_ book: String, _ chapter: Int, _ verses: ClosedRange<Int>, in translationID: String) throws -> TextSelection {
            let location = ChapterLocation(book: book, chapter: chapter)
            let layout = BookLayout.build(chapters: [BookChapterInput(location: location, verses: try store.chapter((book: book, chapter: chapter), translationID: translationID))],
                                          opening: BookOpening(bookName: book, title: BookTitle(title: book, subtitle: nil)), typography: .default)
            let span = { try #require(layout.span(for: VerseLocation(book: book, chapter: chapter, verse: $0))).textRange }
            let first = try span(verses.lowerBound), last = try span(verses.upperBound)
            return try #require(SelectionResolver.resolve(NSRange(location: first.location, length: NSMaxRange(last) - first.location), in: layout))
        }
        let translations = ["KJV", "WEB"].map { Translation(id: $0, title: $0) }
        let part = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 4, startOffset: 9, endOffset: 12, quotedText: "the poor … those")
        let c = try VerseComparison.load(selection: part, readingTranslationID: "WEB", compareSet: ["KJV"], translations: translations, store: store)
        let matthew = try whole("MAT", 5, 3...4, in: "WEB")
        #expect(c.selection.startOffset == matthew.startOffset && c.selection.endOffset == matthew.endOffset && c.selection.endOffset > 12)
        #expect(c.selection.verse == 3 && c.selection.endVerse == 4 && c.selection.quotedText == c.rows[0].plainText)
        // Cut to five: the fifth verse's end, not the selection's.
        let long = TextSelection(book: "PSA", chapter: 118, verse: 3, endVerse: 12, startOffset: 4, endOffset: 2, quotedText: "")
        let cut = try VerseComparison.load(selection: long, readingTranslationID: "KJV", compareSet: [], translations: translations, store: store)
        let psalm = try whole("PSA", 118, 3...7, in: "KJV")
        #expect(cut.selection.startOffset == psalm.startOffset && cut.selection.endOffset == psalm.endOffset && cut.selection.endVerse == 7)
    }

    /// The selection names only text that exists: lacking a verse at either end, the translation being read
    /// ends it at the nearest verse it has, each end's offset from that verse; lacking them all, Ask is off.
    /// The reference and Copy still name every verse shown.
    @Test func itsSelectionEndsAtVersesTheReadingTranslationHas() {
        let translations = ["ESV", "KJV"].map { Translation(id: $0, title: $0) }
        func verse(_ n: Int, _ id: String, _ text: String) -> Verse {
            Verse(id: VerseLocation(book: "MAT", chapter: 17, verse: n), translationID: id, text: text, breakAfter: false)
        }
        func compare(_ reading: [Verse]) -> VerseComparison {
            VerseComparison(selection: TextSelection(book: "MAT", chapter: 17, verse: 20, endVerse: 21, startOffset: 3, endOffset: 2, quotedText: ""),
                            readingTranslationID: "ESV", compareSet: ["KJV"], translations: translations,
                            verses: ["ESV": reading, "KJV": [verse(20, "KJV", "And Jesus said."), verse(21, "KJV", "Howbeit this kind.")]])
        }
        let lacksLast = compare([verse(20, "ESV", " He said to them, ")])           // as the ESV lacks Matthew 17:21
        #expect(lacksLast.selection.verse == 20 && lacksLast.selection.endVerse == 20)
        #expect(lacksLast.selection.startOffset == 1 && lacksLast.selection.endOffset == 17 && lacksLast.canAsk)
        #expect(lacksLast.reference.displayString == "Matthew 17:20-21" && lacksLast.copyText.hasSuffix("Matthew 17:20-21 (KJV)"))
        let lacksFirst = compare([verse(21, "ESV", "But this kind.")])
        #expect(lacksFirst.selection.verse == 21 && lacksFirst.selection.endVerse == 21)
        #expect(lacksFirst.selection.startOffset == 0 && lacksFirst.selection.endOffset == 14)
        let lacksAll = compare([])
        #expect(!lacksAll.canAsk && lacksAll.otherTranslationIDs == ["KJV"] && lacksAll.reference.displayString == "Matthew 17:20-21")
    }

    @Test func aCombinedVerseFillsItsRowWithItsNumbers() {
        let john3 = { VerseLocation(book: "JHN", chapter: 3, verse: $0) }
        let c = VerseComparison(selection: TextSelection(book: "JHN", chapter: 3, verse: 13, endVerse: 13, startOffset: 0, endOffset: 0, quotedText: ""),
                                readingTranslationID: "KJV", compareSet: ["ERV"], translations: ["ERV", "KJV"].map { Translation(id: $0, title: $0) },
                                verses: ["KJV": [Verse(id: john3(13), translationID: "KJV", text: "k", breakAfter: false)],
                                         "ERV": [Verse(id: john3(12), translationID: "ERV", endVerse: 13, text: "a\nb", breakAfter: false)]])
        #expect(c.rows.map(\.text) == ["k", "12-13 a b"])
    }
}
