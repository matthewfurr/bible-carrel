import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ReaderTextLogicTests {
    private func verse(_ n: Int, _ text: String) -> Verse {
        Verse(id: VerseLocation(book: "PSA", chapter: 3, verse: n), translationID: "ESV", endVerse: nil, text: text, breakAfter: false)
    }

    // "1 Blessed are the LORD's poor, in spirit. 2 For theirs is the kingdom’s gate."
    private var chapter: [Verse] {
        [verse(1, "Blessed are the LORD's poor, in spirit."), verse(2, "For theirs is the kingdom’s gate.")]
    }
    private var layout: BookLayout { Self.book(chapter) }
    private var string: NSString { layout.attributedString.string as NSString }

    /// The range of `word` in the chapter string.
    private func range(of word: String) -> NSRange {
        let found = string.range(of: word)
        precondition(found.location != NSNotFound, "\(word) is not in the fixture")
        return found
    }

    /// One chapter alone in a book layout, after its opening (a label, or the title block at chapter 1).
    private static func book(_ verses: [Verse]) -> BookLayout {
        let first = verses[0].id
        return BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: first.book, chapter: first.chapter), verses: verses)],
                                opening: BookOpening(bookName: "Book", title: BookTitle(title: "Book", subtitle: nil)), typography: .default)
    }

    private func highlight(_ range: NSRange, id: UUID = UUID()) -> RangeDecoration {
        RangeDecoration(id: id, range: range, style: .background(MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00")))
    }

    @Test func aRangeInsideAWordGrowsToTheWord() {
        let blessed = range(of: "Blessed")
        let inside = NSRange(location: blessed.location + 2, length: 3)
        #expect(ReaderTextLogic.snapToWords(inside, in: layout) == blessed)
        // A range that starts and ends mid-word grows at both ends.
        let across = NSRange(location: blessed.location + 3, length: range(of: "are").location + 1 - (blessed.location + 3))
        #expect(ReaderTextLogic.snapToWords(across, in: layout) == NSRange(location: blessed.location, length: NSMaxRange(range(of: "are")) - blessed.location))
    }

    @Test func aRangeAcrossTwoVersesSnapsToOneRangeAndReportsBothVerses() {
        let spirit = range(of: "spirit")
        let theirs = range(of: "theirs")
        let drag = NSRange(location: spirit.location + 2, length: theirs.location + 2 - (spirit.location + 2))
        let snapped = ReaderTextLogic.snapToWords(drag, in: layout)
        let expected = NSRange(location: spirit.location, length: NSMaxRange(theirs) - spirit.location)
        #expect(snapped == expected)
        // The verse number between them stays inside the one range.
        #expect(NSLocationInRange(layout.spans[1].numberRange.location, expected))

        let report = snapped.flatMap { ReaderTextLogic.report(for: $0, layout: layout, decorations: .none) }
        #expect(report?.range == expected)
        #expect(report?.selection.verse == 1)
        #expect(report?.selection.endVerse == 2)
        #expect(report?.selection.verse != report?.selection.endVerse)
        #expect(report?.selection.quotedText == "spirit. For theirs")
    }

    @Test func aRangeOverOnlyAVerseNumberOrSpaceIsNil() {
        let first = layout.spans[0], second = layout.spans[1]
        let separator = NSRange(location: NSMaxRange(first.textRange), length: 1)
        let spaceAfterNumber = NSRange(location: NSMaxRange(second.numberRange), length: 1)
        let spaceBetweenWords = NSRange(location: NSMaxRange(range(of: "Blessed")), length: 1)
        let comma = range(of: ",")
        let numberAndSpaces = NSRange(location: separator.location, length: second.textRange.location - separator.location)
        let drags = [first.numberRange, second.numberRange, separator, spaceAfterNumber, spaceBetweenWords, comma, numberAndSpaces]
        for drag in drags {
            #expect(ReaderTextLogic.snapToWords(drag, in: layout) == nil, "\(drag)")
            // What the pen does: snap, then report. Nothing to snap means nothing to report.
            let report = ReaderTextLogic.snapToWords(drag, in: layout).flatMap {
                ReaderTextLogic.report(for: $0, layout: layout, decorations: .none)
            }
            #expect(report == nil, "\(drag)")
        }
    }

    @Test func anEmptyRangeOutsideAnyHighlightReportsNothing() {
        let caret = NSRange(location: range(of: "kingdom").location + 2, length: 0)
        let decorations = BookDecorations(highlights: [highlight(range(of: "Blessed"))], bookmarks: [], outlinedID: nil)
        // A tap snaps to nothing and reports nothing.
        #expect(ReaderTextLogic.snapToWords(caret, in: layout) == nil)
        #expect(ReaderTextLogic.report(for: caret, layout: layout, decorations: decorations) == nil)
        #expect(ReaderTextLogic.report(for: caret, layout: layout, decorations: .none) == nil)
        #expect(ReaderTextLogic.innermostHighlight(containing: caret, in: decorations) == nil)
    }

    @Test func nestedHighlightsResolveToTheInnermost() {
        let outer = highlight(NSRange(location: range(of: "Blessed").location, length: NSMaxRange(range(of: "the")) - range(of: "Blessed").location))
        let inner = highlight(range(of: "are"))
        // Listed outer-last as well as outer-first: the order in the list does not decide.
        for highlights in [[outer, inner], [inner, outer]] {
            let decorations = BookDecorations(highlights: highlights, bookmarks: [], outlinedID: nil)
            let caret = NSRange(location: inner.range.location + 1, length: 0)
            #expect(ReaderTextLogic.innermostHighlight(containing: caret, in: decorations) == inner)
            #expect(ReaderTextLogic.innermostHighlight(containing: NSRange(location: inner.range.location, length: 2), in: decorations) == inner)
            // A range wider than the inner highlight falls back to the outer.
            #expect(ReaderTextLogic.innermostHighlight(containing: range(of: "Blessed"), in: decorations) == outer)

            // A caret reports the innermost highlight's text as the selection and names it primary.
            let report = ReaderTextLogic.report(for: caret, layout: layout, decorations: decorations)
            #expect(report?.primaryHighlightID == inner.id)
            #expect(report?.range == caret)
            #expect(Set(report?.highlightIDs ?? []) == [outer.id, inner.id])
            #expect(report?.selection.quotedText == "are")
        }
    }

    @Test func aCaretAtAHighlightsEndStillFindsIt() {
        let poor = highlight(range(of: "poor"))
        let decorations = BookDecorations(highlights: [poor], bookmarks: [], outlinedID: nil)
        for caret in [NSRange(location: poor.range.location, length: 0), NSRange(location: NSMaxRange(poor.range), length: 0)] {
            #expect(ReaderTextLogic.innermostHighlight(containing: caret, in: decorations) == poor)
            let report = ReaderTextLogic.report(for: caret, layout: layout, decorations: decorations)
            #expect(report?.primaryHighlightID == poor.id)
            #expect(report?.selection.quotedText == "poor")
        }
        // One past the end is outside it.
        let past = NSRange(location: NSMaxRange(poor.range) + 1, length: 0)
        #expect(ReaderTextLogic.innermostHighlight(containing: past, in: decorations) == nil)
    }

    @Test func coveredPunctuationStaysAndSpacesAreTrimmed() {
        let poor = range(of: "poor")
        // " poor, " : the leading and trailing spaces go; the comma, covered and attached, stays.
        let drag = NSRange(location: poor.location - 1, length: poor.length + 3)
        #expect(ReaderTextLogic.snapToWords(drag, in: layout) == NSRange(location: poor.location, length: poor.length + 1))
        // The full stop at the end of a verse stays when the range covered it.
        let spirit = range(of: "spirit")
        #expect(ReaderTextLogic.snapToWords(NSRange(location: spirit.location + 1, length: spirit.length), in: layout)
                == NSRange(location: spirit.location, length: spirit.length + 1))
    }

    // MARK: Punctuation you cover stays (Task 19, F2)

    // "18 And straightway they forsook their nets, and followed him. 19 "Follow me," he said."
    private var markChapter: [Verse] {
        [Verse(id: VerseLocation(book: "MRK", chapter: 1, verse: 18), translationID: "KJV", endVerse: nil,
               text: "And straightway they forsook their nets, and followed him.", breakAfter: true),
         Verse(id: VerseLocation(book: "MRK", chapter: 1, verse: 19), translationID: "KJV", endVerse: nil,
               text: "\u{201C}Follow me,\u{201D} he said.", breakAfter: true)]
    }
    private var markLayout: BookLayout { Self.book(markChapter) }
    private func markRange(of text: String) -> NSRange {
        let found = (markLayout.attributedString.string as NSString).range(of: text)
        precondition(found.location != NSNotFound, "\(text) is not in the fixture")
        return found
    }

    @Test func aRangeCoveringAFullStopKeepsIt() {
        let him = markRange(of: "him.")
        #expect(ReaderTextLogic.snapToWords(him, in: markLayout) == him)
        // From the verse's first word to its full stop: the whole verse text.
        let verse = markLayout.spans[0].textRange
        #expect(ReaderTextLogic.snapToWords(verse, in: markLayout) == verse)
    }

    @Test func aRangeCoveringACommaKeepsIt() {
        let nets = markRange(of: "nets,")
        #expect(ReaderTextLogic.snapToWords(nets, in: markLayout) == nets)
        // Starting inside the word grows it and still keeps the comma it covered.
        #expect(ReaderTextLogic.snapToWords(NSRange(location: nets.location + 2, length: 3), in: markLayout) == nets)
    }

    @Test func aRangeEndingInsideAWordDoesNotGainItsPunctuation() {
        let him = markRange(of: "him")
        #expect(ReaderTextLogic.snapToWords(NSRange(location: him.location, length: 2), in: markLayout) == him)
        // Ending at the word's end is not covering the full stop either.
        #expect(ReaderTextLogic.snapToWords(him, in: markLayout) == him)
    }

    @Test func anOpeningQuotationMarkCoveredAtTheStartStays() {
        let follow = markRange(of: "\u{201C}Follow")
        #expect(ReaderTextLogic.snapToWords(follow, in: markLayout) == follow)
        // Starting at the word leaves the mark before it out.
        let word = NSRange(location: follow.location + 1, length: follow.length - 1)
        #expect(ReaderTextLogic.snapToWords(word, in: markLayout) == word)
        // A closing mark after a comma, both covered: both stay.
        let me = markRange(of: "me,\u{201D}")
        #expect(ReaderTextLogic.snapToWords(me, in: markLayout) == me)
    }

    @Test func aRangeCoveringOnlyAFullStopIsNil() {
        let stop = NSRange(location: NSMaxRange(markRange(of: "him")), length: 1)
        #expect(ReaderTextLogic.snapToWords(stop, in: markLayout) == nil)
        // The full stop, the separator and the next verse's number: still nothing.
        let next = markLayout.spans[1]
        #expect(ReaderTextLogic.snapToWords(NSRange(location: stop.location, length: NSMaxRange(next.numberRange) + 1 - stop.location), in: markLayout) == nil)
    }

    @Test func aTrailingSpaceAndTheNextVersesNumberAreTrimmed() {
        let him = markRange(of: "him.")
        let next = markLayout.spans[1]
        // "him.\n19 " : the separator, the number and the space after it go; the full stop stays.
        let drag = NSRange(location: him.location, length: next.textRange.location - him.location)
        #expect(ReaderTextLogic.snapToWords(drag, in: markLayout) == him)
        // Across into the next verse: one range, the number inside it.
        let follow = markRange(of: "Follow")
        let across = NSRange(location: him.location, length: NSMaxRange(follow) - him.location)
        #expect(ReaderTextLogic.snapToWords(across, in: markLayout) == across)
    }

    @Test func aRangeThatWasNotFoundIsNil() {
        // UIKit's text APIs answer NSNotFound when they find nothing; NSMaxRange of it overflows.
        #expect(ReaderTextLogic.snapToWords(NSRange(location: NSNotFound, length: 0), in: layout) == nil)
        #expect(ReaderTextLogic.snapToWords(NSRange(location: NSNotFound, length: 3), in: layout) == nil)
    }

    @Test func aRangeOutsideTheTextIsNil() {
        let length = string.length
        #expect(ReaderTextLogic.snapToWords(NSRange(location: length, length: 4), in: layout) == nil)
        #expect(ReaderTextLogic.snapToWords(NSRange(location: length + 10, length: 2), in: layout) == nil)
        #expect(ReaderTextLogic.snapToWords(NSRange(location: -1, length: 2), in: layout) == nil)
        // A length that would overflow past the end is cut at the end, not trapped on; the full
        // stop it covers stays.
        let gate = range(of: "gate.")
        #expect(ReaderTextLogic.snapToWords(NSRange(location: gate.location, length: Int.max), in: layout) == gate)
    }

    @Test func anApostropheWordStaysWhole() {
        let lords = range(of: "LORD's")
        #expect(ReaderTextLogic.snapToWords(NSRange(location: lords.location + 1, length: 2), in: layout) == lords)
        #expect(ReaderTextLogic.snapToWords(NSRange(location: NSMaxRange(lords) - 1, length: 1), in: layout) == lords)
        let kingdoms = range(of: "kingdom’s")
        #expect(ReaderTextLogic.snapToWords(NSRange(location: kingdoms.location, length: 3), in: layout) == kingdoms)
    }

    // MARK: Book layout

    private func span(_ layout: BookLayout, _ chapter: Int, _ verse: Int) -> VerseSpan {
        layout.span(for: VerseLocation(book: "JHN", chapter: chapter, verse: verse))!
    }

    /// The range of `word` inside a verse's text in a book layout.
    private func range(of word: String, in layout: BookLayout, _ chapter: Int, _ verse: Int) -> NSRange {
        let text = span(layout, chapter, verse).textRange
        let found = (layout.attributedString.string as NSString).range(of: word, options: [], range: text)
        precondition(found.location != NSNotFound, "\(word) is not in \(chapter):\(verse)")
        return found
    }

    @Test func aRangeInsideAWordOfABookGrowsToTheWord() {
        let layout = JohnFixture.layout()
        let words = range(of: "words", in: layout, 2, 4)
        #expect(ReaderTextLogic.snapToWords(NSRange(location: words.location + 1, length: 2), in: layout) == words)
    }

    @Test(arguments: PageStyle.allCases)
    func snappingNeverCrossesAnOpening(style: PageStyle) {
        let layout = JohnFixture.layout(style: style)
        let mark = range(of: "mark", in: layout, 1, 51)
        let verse = range(of: "Verse", in: layout, 2, 1)
        let drag = NSRange(location: mark.location + 1, length: verse.location + 2 - (mark.location + 1))
        // The covered full stop stays; chapter 2's opening and its words do not join.
        #expect(ReaderTextLogic.snapToWords(drag, in: layout) == NSRange(location: mark.location, length: mark.length + 1))
        // A drag from the start of chapter 2's opening snaps to chapter 2's first word.
        let start = layout.section(for: 2)!.range.location
        #expect(ReaderTextLogic.snapToWords(NSRange(location: start, length: verse.location + 2 - start), in: layout) == verse)
    }

    @Test func anOpeningAloneSnapsToNothing() {
        let layout = JohnFixture.layout()
        #expect(ReaderTextLogic.snapToWords(layout.section(for: 2)!.openingRange, in: layout) == nil)
        #expect(ReaderTextLogic.snapToWords(layout.sections[0].openingRange, in: layout) == nil)
    }

    /// A drag from 1:50 into 2:2 is a chapter 1 selection: its range and highlights stop at 1:51.
    @Test func aReportAcrossAChapterLabelCoversOnlyItsFirstChapter() {
        let layout = JohnFixture.layout()
        let fifty = highlight(range(of: "words", in: layout, 1, 50))
        let next = highlight(range(of: "Verse", in: layout, 2, 1))
        let decorations = BookDecorations(highlights: [fifty, next], bookmarks: [], outlinedID: nil)
        let from = span(layout, 1, 50).textRange.location + 6
        let drag = NSRange(location: from, length: span(layout, 2, 2).textRange.location + 5 - from)
        let report = ReaderTextLogic.report(for: drag, layout: layout, decorations: decorations)
        #expect(report?.selection.chapter == 1 && report?.selection.endVerse == 51)
        #expect(report?.range == NSRange(location: from, length: NSMaxRange(span(layout, 1, 51).textRange) - from))
        #expect(report?.highlightIDs == [fifty.id] && report?.primaryHighlightID == nil)
        // A drag inside one chapter keeps its range.
        let inside = NSRange(location: from, length: 4)
        #expect(ReaderTextLogic.report(for: inside, layout: layout, decorations: decorations)?.range == inside)
    }

    @Test func aCaretInAHighlightOfAnotherChapterReportsIt() {
        let layout = JohnFixture.layout()
        let words = highlight(range(of: "words", in: layout, 3, 16))
        let decorations = BookDecorations(highlights: [words], bookmarks: [], outlinedID: nil)
        let caret = NSRange(location: words.range.location + 2, length: 0)
        #expect(ReaderTextLogic.innermostHighlight(containing: caret, in: decorations) == words)
        let report = ReaderTextLogic.report(for: caret, layout: layout, decorations: decorations)
        #expect(report?.primaryHighlightID == words.id && report?.highlightIDs == [words.id])
        #expect(report?.selection.chapter == 3 && report?.selection.verse == 16 && report?.selection.quotedText == "words")
        // A caret away from every highlight reports nothing; a drag reports its words.
        #expect(ReaderTextLogic.report(for: NSRange(location: span(layout, 2, 1).textRange.location, length: 0), layout: layout, decorations: decorations) == nil)
        let book = range(of: "book", in: layout, 2, 7)
        let text = span(layout, 2, 7).textRange.location
        #expect(ReaderTextLogic.report(for: book, layout: layout, decorations: .none)?.selection
                == TextSelection(book: "JHN", chapter: 2, verse: 7, endVerse: 7, startOffset: book.location - text,
                                 endOffset: NSMaxRange(book) - text, quotedText: "book"))
    }
}
