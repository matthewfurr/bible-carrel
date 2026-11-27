import BibleImporterCore
import ScriptureData
import Testing
@testable import ScriptureUI

/// The dictionary entry's first paragraph, and where a long one stops.
@Suite struct DictionaryEntryTests {
    private typealias Shown = DictionaryEntry.Shown

    @Test func aOneParagraphEntryShowsWholeWithNoShowMore() {
        #expect(DictionaryEntry.shown("One. Two.", fits: { _ in true })
                == Shown(text: "One. Two.", endsInEllipsis: false, hidesMore: false))
    }

    @Test func theFirstParagraphShowsWholeAndTheRestIsHidden() {
        #expect(DictionaryEntry.shown("A. B.\n\nC.", fits: { _ in true })
                == Shown(text: "A. B.", endsInEllipsis: false, hidesMore: true))
    }

    @Test func paragraphsSplitOnBlankLinesAndDropEmptyOnes() {
        #expect(DictionaryEntry.paragraphs("A.\n\n\n\nB.\n \nC.") == ["A.", "B.", "C."])
        #expect(DictionaryEntry.paragraphs("A.\nB.") == ["A.\nB."])
    }

    @Test func aLongFirstParagraphStopsAtASentenceEnd() {
        let sentence = "Word " + String(repeating: "x", count: 24) + "."
        #expect(sentence.count == 30)
        let entry = [sentence, sentence, sentence, sentence].joined(separator: " ")
        let shown = DictionaryEntry.shown(entry, fits: { $0.count <= 70 })
        #expect(shown.text == sentence + " " + sentence)
        #expect(shown.hidesMore && !shown.endsInEllipsis && shown.text.hasSuffix("."))
    }

    @Test func oneSentencePastTenLinesIsCutWithAnEllipsis() {
        let sentence = String(repeating: "word ", count: 99) + "end."
        #expect(sentence.count >= 400)
        let shown = DictionaryEntry.shown(sentence, fits: { $0.count <= 100 })
        #expect(shown == Shown(text: sentence, endsInEllipsis: true, hidesMore: true))
    }

    @Test func linesAreCountedAtTheWidth() {
        let font = PageFace.literata.font(size: 12, italic: true)
        let long = String(repeating: "A line of the dictionary. ", count: 80)
        #expect(long.count > 2000)
        #expect(DictionaryEntry.lineCount(long, font: font, width: 200) > DictionaryEntry.lineCount(long, font: font, width: 472))
        #expect(DictionaryEntry.lineCount("Word", font: font, width: 200) == 1)
    }

    @Test(.needsRealBible) func theRealEntriesFollowTheRule() throws {
        let store = try BenchmarkChapter.realStore()
        let font = PageFace.literata.quotePlatformFont()
        func shown(_ id: Int) throws -> (Shown, firstParagraph: String) {
            let entry = try #require(try store.person(id)?.dictionary)
            let first = try #require(DictionaryEntry.paragraphs(entry).first)
            return (DictionaryEntry.shown(entry) { DictionaryEntry.lineCount($0, font: font, width: 472) <= DictionaryEntry.shownLines }, first)
        }
        let jesse = try shown(903)
        #expect(!jesse.0.hidesMore && !jesse.0.endsInEllipsis)
        let david = try shown(994)
        #expect(david.0.hidesMore && !david.0.endsInEllipsis && david.0.text == david.firstParagraph && david.firstParagraph.count == 331)
        let nehemiah = try shown(2172)
        #expect(nehemiah.firstParagraph.count == 4016)
        #expect(nehemiah.0.hidesMore && !nehemiah.0.endsInEllipsis && nehemiah.0.text.count < nehemiah.firstParagraph.count)
        #expect(DictionaryEntry.lineCount(nehemiah.0.text, font: font, width: 472) <= DictionaryEntry.shownLines)
    }
}
