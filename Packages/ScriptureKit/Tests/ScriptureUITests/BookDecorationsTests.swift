import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// Highlights and bookmarks mapped onto a book layout, including the chapter edges.
@MainActor @Suite struct BookDecorationsTests {
    private let yellow = MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00")
    private let layout = JohnFixture.layout()

    private func item(_ chapter: Int, _ v: Int, _ ev: Int, _ s: Int, _ e: Int, translation: String = "ESV", color: MarkupColor? = nil) -> MarkupItem {
        MarkupItem(id: UUID(), chapter: chapter, verse: v, endVerse: ev, startOffset: s, endOffset: e, translationID: translation, color: color, hasNote: false)
    }
    private func item(_ chapter: Int, _ v: Int, _ s: Int, _ e: Int, translation: String = "ESV", color: MarkupColor? = nil) -> MarkupItem {
        item(chapter, v, v, s, e, translation: translation, color: color)
    }
    private func build(_ items: [MarkupItem], bookmarks: [Int: [Int]] = [:], outlined: UUID? = nil, viewing: String = "ESV", layout: BookLayout? = nil) -> BookDecorations {
        BookDecorations.build(itemsByChapter: Dictionary(grouping: items, by: \.chapter), bookmarksByChapter: bookmarks,
                              outlinedID: outlined, viewingTranslationID: viewing, layout: layout ?? self.layout)
    }
    private func string(_ range: NSRange, in layout: BookLayout? = nil) -> String {
        ((layout ?? self.layout).attributedString.string as NSString).substring(with: range)
    }
    private func words(_ chapter: Int, _ verse: Int, _ range: Range<Int>) -> String {
        (JohnFixture.text(chapter, verse) as NSString).substring(with: NSRange(location: range.lowerBound, length: range.count))
    }

    @Test func firstAndLastVerseHighlightsLandOnTheirWords() {
        let last = item(1, 51, 4, 12, color: yellow), first = item(2, 1, 4, 12, color: yellow)
        let d = build([last, first])
        #expect(d.highlights.count == 2)
        #expect(string(d.decoration(id: last.id)!.range) == words(1, 51, 4..<12))
        #expect(string(d.decoration(id: first.id)!.range) == words(2, 1, 4..<12))
    }

    @Test func firstVerseHighlightLandsOnItsWordsInLectern() {
        let lectern = JohnFixture.layout(style: .lectern)
        let first = item(3, 1, 0, 9, color: yellow)
        let d = build([first], layout: lectern)
        #expect(string(d.highlights[0].range, in: lectern) == words(3, 1, 0..<9))
    }

    @Test func sameTranslationHighlightMapsToExactRange() {
        let d = build([item(3, 16, 6, 9, color: yellow)])
        let span = layout.span(for: VerseLocation(book: "JHN", chapter: 3, verse: 16))!
        #expect(d.highlights[0].range == NSRange(location: span.textRange.location + 6, length: 3))
        #expect(d.highlights[0].style == .background(yellow))
    }

    @Test func colorlessHighlightIsDotted() {
        #expect(build([item(2, 3, 0, 5)]).highlights[0].style == .dottedUnderline)
    }

    @Test func crossVerseHighlightSpansTheNumber() {
        let d = build([item(2, 3, 4, 0, 5, color: yellow)])
        let start = layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 3))!
        let end = layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 4))!
        #expect(d.highlights[0].range == NSRange(location: start.textRange.location, length: end.textRange.location + 5 - start.textRange.location))
        #expect(string(d.highlights[0].range).hasSuffix(" 4 Verse"))
    }

    @Test func foreignTranslationUnderlinesWholeVerses() {
        let d = build([item(2, 3, 4, 6, 3, translation: "KJV", color: yellow)])
        let start = layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 3))!
        let end = layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 4))!
        #expect(d.highlights[0].range == NSRange(location: start.textRange.location, length: NSMaxRange(end.textRange) - start.textRange.location))
        #expect(d.highlights[0].style == .dashedUnderline)
    }

    @Test func foreignHighlightOnCombinedVerseUnderlinesTheSpan() {
        let verses = [
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: 11), translationID: "ERV", text: "Eleven.", breakAfter: false),
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: 12), translationID: "ERV", endVerse: 13, text: "Twelve and thirteen.", breakAfter: false),
        ]
        let combined = BookLayout.build(
            chapters: [BookChapterInput(location: ChapterLocation(book: "MAT", chapter: 5), verses: verses)],
            opening: BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: nil)),
            typography: .default)
        let d = build([item(5, 13, 0, 4, translation: "KJV", color: yellow)], bookmarks: [5: [13]], viewing: "ERV", layout: combined)
        #expect(d.highlights[0].range == combined.spans[1].textRange)
        #expect(d.bookmarks == [VerseLocation(book: "MAT", chapter: 5, verse: 12)])
    }

    @Test func offsetsBeyondVerseAreClamped() {
        let d = build([item(2, 2, 4, 999, color: yellow), item(2, 2, 500, 600, color: yellow)])
        #expect(d.highlights.count == 1)
        let span = layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 2))!
        #expect(d.highlights[0].range == NSRange(location: span.textRange.location + 4, length: span.textRange.length - 4))
    }

    @Test func highlightOnAbsentVerseOrChapterIsSkipped() {
        let d = build([item(2, 30, 0, 4, color: yellow), item(4, 1, 0, 4, color: yellow)], bookmarks: [2: [30, 4], 4: [1]])
        #expect(d.highlights.isEmpty)
        #expect(d.bookmarks == [VerseLocation(book: "JHN", chapter: 2, verse: 4)])
    }

    @Test func bookmarksCarryTheirChapter() {
        let d = build([], bookmarks: [2: [1]])
        #expect(d.bookmarks == [VerseLocation(book: "JHN", chapter: 2, verse: 1)])
    }

    @Test func bookmarksAreInLayoutOrder() {
        let d = build([], bookmarks: [3: [2, 1], 1: [40, 40], 2: [9]])
        #expect(d.bookmarks.map { [$0.chapter, $0.verse] } == [[1, 40], [2, 9], [3, 1], [3, 2]])
    }

    @Test func theOutlineIsKept() {
        let a = item(1, 1, 0, 5, color: yellow)
        #expect(build([a], outlined: a.id).outlinedID == a.id)
        #expect(BookDecorations.none.highlights.isEmpty && BookDecorations.none.bookmarks.isEmpty && BookDecorations.none.outlinedID == nil)
    }

    @Test func intersectingIDsIncludeACaretInsideARange() {
        let a = item(2, 1, 0, 7, color: yellow), b = item(2, 1, 4, 11, color: yellow)
        let d = build([a, b])
        let start = layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 1))!.textRange.location
        #expect(Set(d.ids(intersecting: NSRange(location: start + 7, length: 0))) == [a.id, b.id])
        #expect(d.ids(intersecting: NSRange(location: start + 2, length: 1)) == [a.id])
        #expect(d.ids(intersecting: NSRange(location: start + 20, length: 2)).isEmpty)
    }
}
