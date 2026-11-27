import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct SelectionResolverTests {
    private func verse(_ n: Int, _ text: String, end: Int? = nil) -> Verse {
        Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "ESV", endVerse: end, text: text, breakAfter: false)
    }

    // "1 Blessed are the poor. 2 For theirs is." after chapter 5's label → verse 1 text at
    // o(2)..<o(23), verse 2 text at o(26)..<o(40), where o(n) is n past the chapter's first number.
    private var chapter: [Verse] { [verse(1, "Blessed are the poor."), verse(2, "For theirs is.")] }
    private var layout: BookLayout { Self.book(chapter) }
    private func o(_ offset: Int) -> Int { layout.spans[0].numberRange.location + offset }

    /// One chapter alone in a book layout, after its label.
    private static func book(_ verses: [Verse]) -> BookLayout {
        BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "MAT", chapter: 5), verses: verses)],
                         opening: BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: nil)), typography: .default)
    }

    @Test func selectionInsideOneVerse() {
        let sel = SelectionResolver.resolve(NSRange(location: o(2), length: 7), in: layout)
        #expect(sel == TextSelection(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, quotedText: "Blessed"))
    }

    @Test func selectionAcrossVersesSkipsTheNumber() {
        let sel = SelectionResolver.resolve(NSRange(location: o(14), length: 15), in: layout)   // "the poor. 2 For"
        #expect(sel?.verse == 1 && sel?.endVerse == 2)
        #expect(sel?.startOffset == 12 && sel?.endOffset == 3)
        #expect(sel?.quotedText == "the poor. For")
    }

    @Test func selectionStartingInNumberClipsToText() {
        let sel = SelectionResolver.resolve(NSRange(location: o(23), length: 6), in: layout)    // " 2 For"
        #expect(sel == TextSelection(book: "MAT", chapter: 5, verse: 2, endVerse: 2, startOffset: 0, endOffset: 3, quotedText: "For"))
    }

    @Test func selectionOfOnlySeparatorIsNil() {
        #expect(SelectionResolver.resolve(NSRange(location: o(23), length: 3), in: layout) == nil)   // " 2 "
        #expect(SelectionResolver.resolve(NSRange(location: o(0), length: 0), in: layout) == nil)
    }

    @Test func selectionInCombinedVerseUsesSpanStart() {
        let combined = [verse(11, "Eleven."), verse(12, "Twelve and thirteen.", end: 13)]
        let layout = Self.book(combined)
        let start = layout.spans[1].textRange.location
        let sel = SelectionResolver.resolve(NSRange(location: start + 11, length: 8), in: layout)
        #expect(sel?.verse == 12 && sel?.endVerse == 12 && sel?.quotedText == "thirteen")
        #expect(sel?.referenceString == "Matthew 5:12")
    }

    @Test func copyWithReferenceFormat() {
        let one = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, quotedText: "Blessed are the poor in spirit")
        #expect(one.copyWithReference(translationID: "ESV") == "\u{201C}Blessed are the poor in spirit\u{201D} \u{2014} Matthew 5:3 (ESV)")
        let range = TextSelection(book: "PSA", chapter: 23, verse: 1, endVerse: 2, startOffset: 0, endOffset: 4, quotedText: "The LORD is my shepherd")
        #expect(range.copyWithReference(translationID: "KJV") == "\u{201C}The LORD is my shepherd\u{201D} \u{2014} Psalm 23:1-2 (KJV)")
    }

    @Test func poetryLineBreaksSurviveInQuotedText() {
        let poem = [verse(1, "Line one,\nline two.")]
        let layout = Self.book(poem)
        let sel = SelectionResolver.resolve(layout.spans[0].textRange, in: layout)
        #expect(sel?.quotedText == "Line one,\nline two.")
    }

    // MARK: Book layout

    private func span(_ layout: BookLayout, _ chapter: Int, _ verse: Int) -> VerseSpan {
        layout.span(for: VerseLocation(book: "JHN", chapter: chapter, verse: verse))!
    }

    @Test func aSelectionInsideOneVerseOfABookResolvesToItsChapter() {
        let layout = JohnFixture.layout()
        let start = span(layout, 2, 3).textRange.location
        let sel = SelectionResolver.resolve(NSRange(location: start + 6, length: 3), in: layout)
        #expect(sel == TextSelection(book: "JHN", chapter: 2, verse: 3, endVerse: 3, startOffset: 6, endOffset: 9, quotedText: "2:3"))
    }

    @Test func aSelectionAcrossAChapterLabelClampsToItsFirstChapter() {
        let layout = JohnFixture.layout()
        let from = span(layout, 1, 50).textRange.location + 6
        let to = span(layout, 2, 2).textRange.location + 5
        let sel = SelectionResolver.resolve(NSRange(location: from, length: to - from), in: layout)
        let fifty = JohnFixture.text(1, 50) as NSString
        #expect(sel?.chapter == 1 && sel?.verse == 50 && sel?.endVerse == 51)
        #expect(sel?.startOffset == 6 && sel?.endOffset == (JohnFixture.text(1, 51) as NSString).length)
        #expect(sel?.quotedText == fifty.substring(from: 6) + " " + JohnFixture.text(1, 51))
    }

    @Test func aSelectionStartingInAnOpeningResolvesToThatChapter() {
        let layout = JohnFixture.layout()
        let opening = layout.section(for: 2)!.openingRange
        let end = span(layout, 2, 1).textRange.location + 5
        let sel = SelectionResolver.resolve(NSRange(location: opening.location, length: end - opening.location), in: layout)
        #expect(sel == TextSelection(book: "JHN", chapter: 2, verse: 1, endVerse: 1, startOffset: 0, endOffset: 5, quotedText: "Verse"))
        // An opening alone is no verse text.
        #expect(SelectionResolver.resolve(opening, in: layout) == nil)
    }

    @Test(arguments: PageStyle.allCases)
    func verseOneResolvesWholeInEveryStyle(style: PageStyle) {
        let layout = JohnFixture.layout(style: style)
        let sel = SelectionResolver.resolve(span(layout, 3, 1).textRange, in: layout)
        #expect(sel?.chapter == 3 && sel?.verse == 1 && sel?.endVerse == 1)
        #expect(sel?.quotedText == JohnFixture.text(3, 1))
    }

    @Test func aSelectionWithVerseNumbersHiddenStillResolves() {
        let layout = JohnFixture.layout { $0.showsVerseNumbers = false }
        let first = span(layout, 1, 2).textRange, second = span(layout, 1, 3).textRange
        let sel = SelectionResolver.resolve(NSRange(location: first.location, length: NSMaxRange(second) - first.location), in: layout)
        #expect(sel?.verse == 2 && sel?.endVerse == 3)
        #expect(sel?.quotedText == JohnFixture.text(1, 2) + " " + JohnFixture.text(1, 3))
    }

    @Test func poetryLineBreaksSurviveInABook() {
        let layout = JohnFixture.layout()
        #expect(SelectionResolver.resolve(span(layout, 1, 23).textRange, in: layout)?.quotedText == JohnFixture.text(1, 23))
    }
}
