import CoreGraphics
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The book readers' shared, platform-neutral rules (`ReadingPositionRule.swift`), tested on
/// layouts and made-up line frames, without a text view.
@MainActor @Suite struct ReadingPositionRuleTests {
    private let opening = BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: nil))

    private func verses(_ chapter: Int, _ count: Int, combined: Int? = nil) -> [Verse] {
        // A combined verse ("3-4") takes its second number's place.
        (1...count).filter { n in combined.map { n != $0 + 1 } ?? true }.map { n in
            Verse(id: VerseLocation(book: "MAT", chapter: chapter, verse: n), translationID: "WEB",
                  endVerse: n == combined ? n + 1 : nil, text: "Verse \(n) text.", breakAfter: false)
        }
    }

    private func book(_ range: ClosedRange<Int>, count: Int = 5, translation: String = "WEB", style: PageStyle = .printed,
                      combinedIn chapter: Int? = nil, at verse: Int? = nil) -> BookLayout {
        var prefs = ReaderPreferences.default
        prefs.style = style
        let inputs = range.map { c in
            BookChapterInput(location: ChapterLocation(book: "MAT", chapter: c),
                             verses: verses(c, count, combined: c == chapter ? verse : nil).map {
                                 Verse(id: $0.id, translationID: translation, endVerse: $0.endVerse, text: $0.text, breakAfter: false)
                             })
        }
        return BookLayout.build(chapters: inputs, opening: opening, typography: .styled(prefs))
    }

    private func at(_ chapter: Int, _ verse: Int) -> VerseLocation {
        VerseLocation(book: "MAT", chapter: chapter, verse: verse)
    }

    // MARK: Layout helpers

    @Test func aSectionIndexCountsFromTheWindowsFirstChapter() {
        let layout = book(3...5)
        #expect(layout.sectionIndex(of: 3) == 0 && layout.sectionIndex(of: 5) == 2)
        #expect(layout.sectionIndex(of: 2) == nil && layout.sectionIndex(of: 6) == nil)
    }

    /// The mark's line is the opening's last that is not Study's rule: chapter 1's label in the
    /// title block, a later chapter's hairline. Matt, 2026-11-13: a later chapter has no label,
    /// so in every style its mark line is its hairline (`.chapterStart`, Lectern's
    /// `.dropNumeral`) and the mark sits above it, as only Lectern's did; chapter 1's stays
    /// beside its label (Lectern's title block ends on its hairline too).
    @Test func aMarkSitsBesideTheOpeningsLastLineNotStudysRule() throws {
        let printed = book(1...2)
        let label = printed.openingMarkLineIndex(of: printed.sections[1])
        #expect(printed.attributedString.readerRole(at: label) == .chapterStart(2))
        #expect(printed.attributedString.readerRole(at: printed.openingMarkLineIndex(of: printed.sections[0])) == .chapterLabel(1))
        let study = book(1...2, style: .study)
        let one = study.openingMarkLineIndex(of: study.sections[0])
        #expect(study.attributedString.readerRole(at: one) == .chapterLabel(1), "past the title block's hairline")
        let lectern = book(1...2, style: .lectern)
        let numeral = lectern.openingMarkLineIndex(of: lectern.sections[1])
        #expect(lectern.attributedString.readerRole(at: numeral) == .dropNumeral(2), "beside the chapter's numeral")
        for style in PageStyle.allCases {
            let layout = book(1...2, style: style)
            #expect(layout.marksAboveOpeningLine(of: layout.sections[1]), "\(style): above a later chapter's hairline")
            #expect(layout.marksAboveOpeningLine(of: layout.sections[0]) == (style == .lectern), "\(style): beside chapter 1's label")
            let alone = book(2...2, style: style)
            let line = alone.openingMarkLineIndex(of: alone.sections[0])
            #expect(alone.attributedString.readerRole(at: line) == (style == .lectern ? .dropNumeral(2) : .chapterStart(2)), "\(style)")
            #expect(alone.marksAboveOpeningLine(of: alone.sections[0]), "\(style): on its own page too")
        }
    }

    // MARK: Bands

    /// The page's band runs from its opening's first line to its last text line, offset by the
    /// inset, for chapter 1 (the title block) and a later chapter alike.
    @Test func theBandComesFromTheOpeningAndTextLines() throws {
        for style in [PageStyle.printed, .lectern] {
            for chapter in [1, 3] {
                let layout = book(chapter...chapter, style: style)
                let section = layout.sections[0]
                // A made-up layout: every character on a line of its own, 10 pt high.
                let band = try #require(ChapterBand.band(for: layout, inset: 5) { CGRect(x: 0, y: CGFloat($0) * 10, width: 10, height: 10) })
                #expect(band.chapter == chapter)
                #expect(band.openingMinY == CGFloat(section.openingRange.location) * 10 + 5, "\(style) \(chapter)")
                #expect(band.openingMaxY == CGFloat(NSMaxRange(section.openingRange)) * 10 + 5, "\(style) \(chapter)")
                let last = try #require(section.spans.last)
                #expect(band.textMaxY == CGFloat(NSMaxRange(last.textRange)) * 10 + 5)
            }
        }
        // No line frames at all: the band falls back to the inset.
        let empty = try #require(ChapterBand.band(for: book(2...2), inset: 5) { _ in nil })
        #expect(empty.openingMinY == 5 && empty.textMaxY == 5)
    }

    // MARK: The reading position

    @Test func theFirstVisibleVerseIsTheDefault() {
        let layout = book(2...2)
        let result = ReadingPositionRule.resolve(firstVisible: at(2, 3), landed: nil, layout: layout)
        #expect(result.position == at(2, 3) && result.landed == nil)
    }

    /// A combined verse reports the verse a jump asked for while it stays the first visible; once
    /// another verse is at the top the landing ends.
    @Test func aLandedVerseInACombinedSpanIsReported() {
        let layout = book(2...2, combinedIn: 2, at: 3)
        let kept = ReadingPositionRule.resolve(firstVisible: at(2, 3), landed: at(2, 4), layout: layout)
        #expect(kept.position == at(2, 4) && kept.landed == at(2, 4))
        let moved = ReadingPositionRule.resolve(firstVisible: at(2, 5), landed: at(2, 4), layout: layout)
        #expect(moved.position == at(2, 5) && moved.landed == nil)
    }

    /// As on `main`, a jump to a verse the page cannot bring to the top (near the chapter's end)
    /// reports the first visible verse, and the landing ends.
    @Test func aLandingThePageCannotRestOnReportsTheFirstVisibleVerse() {
        let layout = book(3...3)
        let result = ReadingPositionRule.resolve(firstVisible: at(3, 3), landed: at(3, 5), layout: layout)
        #expect(result.position == at(3, 3) && result.landed == nil)
        let exact = ReadingPositionRule.resolve(firstVisible: at(3, 5), landed: at(3, 5), layout: layout)
        #expect(exact.position == at(3, 5) && exact.landed == at(3, 5))
    }
}
