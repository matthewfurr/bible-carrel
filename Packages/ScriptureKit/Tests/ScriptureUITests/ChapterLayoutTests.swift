import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ChapterLayoutTests {
    private func verse(_ n: Int, _ text: String, end: Int? = nil, breakAfter: Bool = false) -> Verse {
        Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "WEB", endVerse: end, text: text, breakAfter: breakAfter)
    }

    @Test func proseVersesFlowWithSpacesAndNumbersAreSuperscript() {
        let layout = ChapterLayout.build(verses: [verse(1, "Alpha beta."), verse(2, "Gamma.")])
        #expect(layout.attributedString.string == "1 Alpha beta. 2 Gamma.")
        #expect(layout.spans.count == 2)
        #expect(layout.spans[0].numberRange == NSRange(location: 0, length: 1))
        #expect(layout.spans[0].textRange == NSRange(location: 2, length: 11))
        #expect(layout.spans[1].textRange == NSRange(location: 16, length: 6))
        let numberAttributes = layout.attributedString.attributes(at: 0, effectiveRange: nil)
        #expect((numberAttributes[.baselineOffset] as? CGFloat) == ReaderTypography.default.verseNumberBaselineOffset)
        #expect((numberAttributes[.font] as? PlatformFont)?.pointSize == ReaderTypography.default.verseNumberFont.pointSize)
    }

    @Test func breakAfterInsertsParagraphBreak() {
        let layout = ChapterLayout.build(verses: [verse(1, "One.", breakAfter: true), verse(2, "Two.")])
        #expect(layout.attributedString.string == "1 One.\n2 Two.")
    }

    @Test func poetryVerseStartsOnItsOwnLine() {
        let layout = ChapterLayout.build(verses: [
            verse(1, "Prose."),
            verse(2, "Line one,\nline two."),
            verse(3, "Line three,\nline four."),
            verse(4, "Prose again."),
        ])
        // Every poetry line is its own paragraph, so the separators are paragraph breaks.
        #expect(layout.attributedString.string == "1 Prose.\n2 Line one,\nline two.\n3 Line three,\nline four.\n4 Prose again.")
        #expect(layout.spans[1].textRange.length == "Line one,\nline two.".utf16.count)
    }

    @Test func combinedVerseSpanCoversEndVerse() {
        let layout = ChapterLayout.build(verses: [verse(11, "Eleven."), verse(12, "Twelve thirteen.", end: 13), verse(14, "Fourteen.")])
        #expect(layout.spans[1].label == "12-13")
        #expect(layout.span(forVerse: 13) == layout.spans[1])
        #expect(layout.span(forVerse: 12) == layout.spans[1])
        #expect(layout.span(forVerse: 14)?.location.verse == 14)
    }

    @Test func spanForMissingVerseReturnsNil() {
        let layout = ChapterLayout.build(verses: [verse(20, "Twenty."), verse(22, "Twenty-two.")])
        #expect(layout.span(forVerse: 21) == nil)
        #expect(layout.span(forVerse: 22)?.location.verse == 22)
    }

    @Test func characterIndexMapsToVerseAndOffset() {
        let layout = ChapterLayout.build(verses: [verse(1, "Alpha beta."), verse(2, "Gamma.")])
        // "1 Alpha beta. 2 Gamma." — index 8 is the 'b' of "beta", offset 6 within verse 1.
        let hit = layout.offsetWithinVerse(of: 8)
        #expect(hit?.span.location.verse == 1)
        #expect(hit?.offset == 6)
        #expect(layout.span(containing: 14)?.location.verse == 2)   // the "2" label
        #expect(layout.offsetWithinVerse(of: 14) == nil)             // not inside verse text
        #expect(layout.span(containing: 99) == nil)
    }

    @Test func firstVisibleVerseIsTheNextLabelFromALineStart() {
        // "1 Alpha beta. 2 Gamma." — a line starting mid-verse 1 reports verse 2, so a relaunch
        // that scrolls verse 2's line to the top reports verse 2 again instead of drifting.
        let layout = ChapterLayout.build(verses: [verse(1, "Alpha beta."), verse(2, "Gamma.")])
        #expect(layout.firstVisibleVerse(fromLineStart: 0) == 1)
        #expect(layout.firstVisibleVerse(fromLineStart: 3) == 2)
        #expect(layout.firstVisibleVerse(fromLineStart: 14) == 2)
        #expect(layout.firstVisibleVerse(fromLineStart: 18) == 2)    // inside the last verse: no later label
        #expect(ChapterLayout.build(verses: []).firstVisibleVerse(fromLineStart: 0) == nil)
    }

    @Test func emptyChapterProducesEmptyLayout() {
        let layout = ChapterLayout.build(verses: [])
        #expect(layout.attributedString.length == 0)
        #expect(layout.spans.isEmpty)
    }

    @Test func proseParagraphsIndentExceptTheFirstAndAfterPoetry() {
        let t = ReaderTypography.default
        let layout = ChapterLayout.build(verses: [
            verse(1, "Opening prose.", breakAfter: true),
            verse(2, "Second paragraph.", breakAfter: true),
            verse(3, "Line one,\nline two.", breakAfter: true),
            verse(4, "After poetry."),
        ], typography: t)
        func style(atVerse n: Int) -> NSParagraphStyle {
            layout.attributedString.attribute(.paragraphStyle, at: layout.span(forVerse: n)!.textRange.location, effectiveRange: nil) as! NSParagraphStyle
        }
        #expect(style(atVerse: 1).firstLineHeadIndent == 0)
        #expect(style(atVerse: 1).paragraphSpacing == t.paragraphSpacing)
        #expect(style(atVerse: 2).firstLineHeadIndent == t.firstLineIndent)
        #expect(style(atVerse: 2).paragraphSpacing == t.indentedParagraphSpacing)
        #expect(style(atVerse: 4).firstLineHeadIndent == 0)
    }

    @Test func poetryLinesAreHangingParagraphs() {
        let t = ReaderTypography.default
        let layout = ChapterLayout.build(verses: [verse(1, "Line one,\nline two."), verse(2, "Line three,\nline four.", breakAfter: true), verse(3, "Prose.")], typography: t)
        #expect(layout.attributedString.string == "1 Line one,\nline two.\n2 Line three,\nline four.\n3 Prose.")
        let first = layout.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        #expect(first.firstLineHeadIndent == t.poetryIndent)
        #expect(first.headIndent == t.poetryIndent + t.poetryHang)
        #expect(first.paragraphSpacing == 0)
        let secondLine = layout.attributedString.attribute(.paragraphStyle, at: "1 Line one,\n".utf16.count, effectiveRange: nil) as! NSParagraphStyle
        #expect(secondLine.firstLineHeadIndent == t.poetryIndent)
        let stanzaEnd = layout.attributedString.attribute(.paragraphStyle, at: "1 Line one,\nline two.\n2 Line three,\n".utf16.count, effectiveRange: nil) as! NSParagraphStyle
        #expect(stanzaEnd.paragraphSpacing == t.stanzaSpacing)
    }

    @Test func aChapterOpeningInPoetryHasNoIndent() {
        let t = ReaderTypography.default
        let layout = ChapterLayout.build(verses: [verse(1, "Blessed is the man\nwho walks not.")], typography: t)
        let style = layout.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        #expect(style.firstLineHeadIndent == t.poetryIndent)
        #expect(style.headIndent == t.poetryIndent + t.poetryHang)
    }

    @Test func offsetsAcrossLineAndParagraphBreaksStillMap() {
        let verses = [verse(1, "Line one,\nline two.", breakAfter: true), verse(2, "Prose after.")]
        let layout = ChapterLayout.build(verses: verses)
        for (span, verse) in zip(layout.spans, verses) {
            #expect(span.textRange.length == verse.text.utf16.count)
            #expect((layout.attributedString.string as NSString).substring(with: span.textRange) == verse.text)
        }
        #expect(layout.offsetWithinVerse(of: layout.spans[0].textRange.location + 12)?.offset == 12)
    }

    // MARK: Headings and reader options

    private func john1(_ range: ClosedRange<Int>) -> [Verse] {
        range.map { n in
            Verse(id: VerseLocation(book: "JHN", chapter: 1, verse: n), translationID: "WEB", endVerse: nil,
                  text: "In the beginning was the Word, number \(n).", breakAfter: false)
        }
    }

    private func styled(_ edit: (inout ReaderPreferences) -> Void) -> ReaderTypography {
        var p = ReaderPreferences.default
        edit(&p)
        return ReaderTypography.styled(p)
    }

    @Test func aHeadingIsItsOwnParagraphOutsideEverySpan() {
        let l = ChapterLayout.build(verses: john1(1...8), headings: [6: [SectionHeading(text: "The Witness of John", level: 1)]], typography: .styled(.default))
        let s = l.attributedString.string as NSString
        let h = s.range(of: "The Witness of John")
        #expect(h.location != NSNotFound && !l.spans.contains { NSIntersectionRange($0.fullRange, h).length > 0 })
        #expect(s.substring(with: l.span(forVerse: 6)!.textRange) == john1(6...6)[0].text)
        #expect(l.attributedString.readerRole(at: h.location) == .sectionHeading)
        #expect(l.attributedString.readerRole(at: l.span(forVerse: 6)!.textRange.location) == nil)
        // The heading paragraph is its own line, and the verse after it opens (no indent).
        #expect(s.substring(with: NSRange(location: NSMaxRange(h), length: 1)) == "\n")
        let after = l.attributedString.attribute(.paragraphStyle, at: l.span(forVerse: 6)!.numberRange.location, effectiveRange: nil) as! NSParagraphStyle
        #expect(after.firstLineHeadIndent == 0)
        let hs = l.attributedString.attribute(.paragraphStyle, at: h.location, effectiveRange: nil) as! NSParagraphStyle
        let size = ReaderTypography.default.bodyFont.pointSize
        #expect(hs.paragraphSpacingBefore == size && hs.paragraphSpacing == (0.45 * size).rounded())
    }

    @Test func aHeadingBeforeTheFirstVerseHasNoSpaceBefore() {
        let l = ChapterLayout.build(verses: john1(1...2), headings: [1: [SectionHeading(text: "The Word", level: 1)]])
        #expect(l.attributedString.string.hasPrefix("The Word\n1 "))
        let hs = l.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        #expect(hs.paragraphSpacingBefore == 0)
        #expect(l.spans[0].numberRange.location == "The Word\n".utf16.count)
    }

    @Test func headingsHiddenLeaveTheOldText() {
        let hidden = styled { $0.showsSectionHeadings = false }
        let withHeadings = ChapterLayout.build(verses: john1(1...8), headings: [6: [SectionHeading(text: "The Witness of John", level: 1)]], typography: hidden)
        #expect(withHeadings.attributedString.string == ChapterLayout.build(verses: john1(1...8), typography: hidden).attributedString.string)
        #expect(!withHeadings.attributedString.string.contains("Witness"))
    }

    @Test func versesWithoutNumbersKeepTheirOffsets() {
        let t = styled { $0.showsVerseNumbers = false }
        let verses = john1(1...4)
        let l = ChapterLayout.build(verses: verses, headings: [3: [SectionHeading(text: "Heading", level: 1)]], typography: t)
        let s = l.attributedString.string as NSString
        for (span, verse) in zip(l.spans, verses) {
            #expect(s.substring(with: span.textRange) == verse.text)
            #expect(span.numberRange == NSRange(location: span.textRange.location, length: 0))
            #expect(span.label == "\(verse.id.verse)")
        }
        #expect(!l.attributedString.string.contains("1 In"))
        #expect(!l.attributedString.string.contains("2 In"))
        #expect(l.attributedString.string.hasPrefix("In the beginning"))
    }

    @Test func versePerLineBreaksEveryVerse() {
        let l = ChapterLayout.build(verses: john1(1...4), typography: styled { $0.layout = .versePerLine })
        let s = l.attributedString.string as NSString
        for span in l.spans.dropFirst() {
            #expect(s.substring(with: NSRange(location: span.numberRange.location - 1, length: 1)) == "\n")
            let style = l.attributedString.attribute(.paragraphStyle, at: span.numberRange.location, effectiveRange: nil) as! NSParagraphStyle
            #expect(style.firstLineHeadIndent == 0)
        }
    }

    @Test func justifiedProseHyphenates() {
        let t = styled { $0.justified = true }
        let verses = [john1(1...1)[0],
                      Verse(id: VerseLocation(book: "JHN", chapter: 1, verse: 2), translationID: "WEB", endVerse: nil, text: "Line one,\nline two.", breakAfter: false)]
        let l = ChapterLayout.build(verses: verses, typography: t)
        let prose = l.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        #expect(prose.alignment == .justified && prose.hyphenationFactor > 0)
        let poetry = l.attributedString.attribute(.paragraphStyle, at: l.spans[1].textRange.location, effectiveRange: nil) as! NSParagraphStyle
        #expect(poetry.alignment == .natural && poetry.hyphenationFactor == 0)
    }

    @Test func readerRoleSurvivesCopyingAndComparesByValue() {
        #expect(ReaderRoleBox(.sectionHeading).isEqual(ReaderRoleBox(.sectionHeading)))
        #expect(!ReaderRoleBox(.sectionHeading).isEqual(ReaderRoleBox(.dropNumeral(2))))
        let l = ChapterLayout.build(verses: john1(1...2), headings: [1: [SectionHeading(text: "H", level: 1)]])
        let copy = NSMutableAttributedString(attributedString: l.attributedString)
        #expect(copy.readerRole(at: 0) == .sectionHeading)
        #expect(copy.isEqual(to: l.attributedString))
    }
}
