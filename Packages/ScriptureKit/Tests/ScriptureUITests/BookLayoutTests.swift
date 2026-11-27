#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// John 1–3 shaped chapters (51, 25 and 36 verses) with headings, a paragraph break and a poetry
/// verse, for the book-scale suites.
@MainActor enum JohnFixture {
    static let counts = [1: 51, 2: 25, 3: 36]

    static func text(_ chapter: Int, _ verse: Int) -> String {
        if chapter == 1, verse == 23 { return "I am the voice of one crying in the wilderness,\nMake straight the way of the Lord." }
        return "Verse \(chapter):\(verse) of the book, with words to mark."
    }

    static func verses(_ chapter: Int, translation: String = "ESV") -> [Verse] {
        (1...counts[chapter]!).map { verse in
            Verse(id: VerseLocation(book: "JHN", chapter: chapter, verse: verse), translationID: translation,
                  text: text(chapter, verse), breakAfter: verse % 5 == 0)
        }
    }

    static let headings: [Int: [Int: [SectionHeading]]] = [
        1: [1: [SectionHeading(text: "The Word Became Flesh", level: 1)], 19: [SectionHeading(text: "The Testimony of John", level: 1)]],
        2: [1: [SectionHeading(text: "The Wedding at Cana", level: 1)]],
        3: [16: [SectionHeading(text: "For God So Loved the World", level: 1)]],
    ]

    static func inputs(_ chapters: ClosedRange<Int>, translation: String = "ESV") -> [BookChapterInput] {
        chapters.map { BookChapterInput(location: ChapterLocation(book: "JHN", chapter: $0), verses: verses($0, translation: translation), headings: headings[$0] ?? [:]) }
    }

    static let opening = BookOpening(bookName: "John", title: BookTitle(title: "John", subtitle: "The Gospel According to John"))

    static func layout(_ chapters: ClosedRange<Int> = 1...3, style: PageStyle = .printed, configure: (inout ReaderPreferences) -> Void = { _ in }) -> BookLayout {
        var prefs = ReaderPreferences.default
        prefs.style = style
        configure(&prefs)
        return BookLayout.build(chapters: inputs(chapters), opening: opening, typography: .styled(prefs))
    }
}

/// True when `color` is `token`'s color: the same named color on the Mac; on UIKit, whose dynamic
/// colors never compare equal, the same color in the light, dark and Sepia appearances.
func isToken(_ color: Any?, _ token: ColorToken) -> Bool {
    #if canImport(AppKit)
    return color as? NSColor == token.platformColor
    #else
    guard let color = color as? UIColor else { return false }
    let appearances = [
        UITraitCollection(userInterfaceStyle: .light), UITraitCollection(userInterfaceStyle: .dark),
        UITraitCollection { $0.userInterfaceStyle = .light; $0[SepiaTrait.self] = true },
    ]
    return appearances.allSatisfy { color.resolvedColor(with: $0) == token.platformColor.resolvedColor(with: $0) }
    #endif
}

@MainActor @Suite struct BookLayoutTests {
    private func string(_ layout: BookLayout, _ range: NSRange) -> String {
        (layout.attributedString.string as NSString).substring(with: range)
    }

    private func roles(in layout: BookLayout, _ range: NSRange) -> [ReaderRole] {
        var roles: [ReaderRole] = []
        layout.attributedString.enumerateAttribute(.readerRole, in: range) { value, _, _ in
            if let role = (value as? ReaderRoleBox)?.role, roles.last != role { roles.append(role) }
        }
        return roles
    }

    @Test(arguments: PageStyle.allCases)
    func everyVerseOfEveryChapterKeepsItsText(style: PageStyle) {
        let layout = JohnFixture.layout(style: style)
        #expect(layout.spans.count == 51 + 25 + 36)
        for span in layout.spans {
            #expect(string(layout, span.textRange) == JohnFixture.text(span.location.chapter, span.location.verse))
        }
        #expect(layout.sections.map(\.location.chapter) == [1, 2, 3])
        #expect(layout.sections.flatMap(\.spans) == layout.spans)
        #expect(layout.chapters == 1...3)
    }

    @Test func sectionsTileTheString() {
        let layout = JohnFixture.layout()
        var next = 0
        for section in layout.sections {
            #expect(section.range.location == next)
            #expect(section.openingRange.location == section.range.location)
            next = NSMaxRange(section.range)
        }
        #expect(next == layout.attributedString.length)
    }

    @Test(arguments: PageStyle.allCases)
    func openingsAreOutsideSpansAndTagged(style: PageStyle) {
        let layout = JohnFixture.layout(style: style)
        for section in layout.sections {
            for span in layout.spans {
                #expect(NSIntersectionRange(span.fullRange, section.openingRange).length == 0)
            }
            #expect(section.openingRange.length > 0, "every style opens every chapter with a line")
            layout.attributedString.enumerateAttribute(.readerRole, in: section.openingRange) { value, _, _ in
                #expect(value is ReaderRoleBox)
            }
        }
    }

    /// Matt, 2026-11-13: the page carries no chapter label, the running head names the chapter.
    /// A later chapter opens on an empty hairline in the styles with no numeral: a word joiner a
    /// point tall with role `.chapterStart(n)`, nothing below it, and no label text ("CHAPTER 2",
    /// "JOHN 2", "John 2") anywhere. Set after another chapter (only tests do), it keeps the
    /// air between chapters above it.
    @Test(arguments: [PageStyle.printed, .study, .classic])
    func laterChaptersOpenOnAnEmptyHairline(style pageStyle: PageStyle) {
        let layout = JohnFixture.layout(style: pageStyle)
        let typography = ReaderTypography.styled(ReaderPreferences(style: pageStyle))
        for chapter in [2, 3] {
            let opening = layout.section(for: chapter)!.openingRange
            #expect(string(layout, opening) == "\u{2060}\n")
            #expect(roles(in: layout, opening) == [.chapterStart(chapter)])
            let style = layout.attributedString.attribute(.paragraphStyle, at: opening.location, effectiveRange: nil) as! NSParagraphStyle
            #expect(style.minimumLineHeight == 1 && style.maximumLineHeight == 1)
            #expect(style.paragraphSpacingBefore == BookLayout.openingAir(for: typography))
            #expect(style.paragraphSpacing == 0)
            #expect(style.alignment == .natural)
            let font = layout.attributedString.attribute(.font, at: opening.location, effectiveRange: nil) as! PlatformFont
            #expect(font.pointSize == 1)
            // The chapter's text follows at once: its heading, or verse 1.
            let next = NSMaxRange(opening)
            #expect(next == layout.section(for: chapter)!.spans[0].fullRange.location
                || layout.attributedString.readerRole(at: next) == .sectionHeading)
        }
        if pageStyle == .printed { #expect(BookLayout.openingAir(for: typography) == (2.4 * 18).rounded()) }
        let text = layout.attributedString.string
        for label in ["CHAPTER 2", "CHAPTER 3", "JOHN 2", "JOHN 3", "John 2", "John 3"] {
            #expect(!text.contains(label), "\(label)")
        }
        // No joiner in any span: copying, highlights and search see the verse text alone.
        for span in layout.spans {
            #expect(!string(layout, span.fullRange).contains("\u{2060}"))
        }
    }

    @Test func printedBookOpeningIsTitleSubtitleAndChapterOne() {
        let layout = JohnFixture.layout()
        let opening = layout.sections[0].openingRange
        #expect(string(layout, opening) == "John\nThe Gospel According to John\nCHAPTER 1\n")
        #expect(roles(in: layout, opening) == [.title, .subtitle, .chapterLabel(1)])
    }

    @Test func theTitleBlockAppearsOnlyWhenTheWindowStartsAtChapterOne() {
        let layout = JohnFixture.layout(2...3)
        #expect(!layout.attributedString.string.contains("The Gospel According to John"))
        let first = layout.sections[0].openingRange
        // Matt, 2026-11-13: no label either; the page opens on chapter 2's empty hairline.
        #expect(string(layout, first) == "\u{2060}\n")
        #expect(roles(in: layout, first) == [.chapterStart(2)])
        #expect(!layout.attributedString.string.contains("CHAPTER"))
        let style = layout.attributedString.attribute(.paragraphStyle, at: first.location, effectiveRange: nil) as! NSParagraphStyle
        #expect(style.paragraphSpacingBefore == 0)
        #expect(layout.chapters == 2...3)
        #expect(!layout.opensWithTitleBlock)
        #expect(JohnFixture.layout(1...2).opensWithTitleBlock && JohnFixture.layout(1...1).opensWithTitleBlock)
        #expect(!JohnFixture.layout(3...3).opensWithTitleBlock)
    }

    /// Lectern's drop numeral (DESIGN.md, Page Styles; R16 superseded 2026-11-12): every chapter
    /// opens on a hairline of its own (a word joiner a point tall, role `.dropNumeral(n)`, the
    /// later chapters' air above it), and verse 1's number gives way to the numeral drawn beside
    /// the chapter's first paragraph. That paragraph and the next ones up to three, stopping at a
    /// heading, are the numeral's zone; the paragraph after is its follower. Nothing of it is in
    /// a span, and verse text carries no role.
    @Test func lecternOpensEachChapterOnAHairlineAndTagsItsNumeralsZone() {
        let layout = JohnFixture.layout(style: .lectern)
        let string = layout.attributedString.string as NSString
        let opening = layout.sections[0].openingRange
        #expect(self.string(layout, opening) == "John\nThe Gospel According to John\n· · ·\n\u{2060}\n")
        #expect(roles(in: layout, opening) == [.title, .subtitle, .ornament, .dropNumeral(1)])
        func zone(at index: Int) -> DropZone? {
            layout.attributedString.attribute(.dropZone, at: index, effectiveRange: nil) as? DropZone
        }
        for section in layout.sections {
            let chapter = section.location.chapter
            let hairline = NSRange(location: NSMaxRange(section.openingRange) - 2, length: 2)
            #expect(self.string(layout, hairline) == "\u{2060}\n")
            #expect(roles(in: layout, hairline) == [.dropNumeral(chapter)])
            let style = layout.attributedString.attribute(.paragraphStyle, at: hairline.location, effectiveRange: nil) as! NSParagraphStyle
            #expect(style.minimumLineHeight == 1 && style.maximumLineHeight == 1)
            #expect(!section.spans.contains { NSIntersectionRange($0.fullRange, section.openingRange).length > 0 })
            let first = section.spans[0]
            #expect(first.numberRange.length == 0)
            #expect(first.numberRange.location == first.textRange.location)
            #expect(layout.attributedString.readerRole(at: first.textRange.location) == nil, "verse text carries no role")
            #expect(self.string(layout, section.spans[1].numberRange) == "2", "verse 2 keeps its number")

            // The zone: verse 1's paragraph first, its notch the numeral's width and gap, three lines deep.
            let lectern = ReaderTypography.styled(ReaderPreferences(style: .lectern))
            let firstZone = zone(at: first.textRange.location)
            #expect(firstZone?.chapter == chapter && firstZone?.part == .first)
            #expect(firstZone?.notch == DropNumeral.notch(chapter, typography: lectern))
            #expect(abs((firstZone?.notch.height ?? 0) - 3 * lectern.bodyLineHeight) < 0.01)
            // Every verse number in the zone and its follower has a strut before it, outside the span.
            for span in section.spans where span.numberRange.length > 0 && zone(at: span.numberRange.location)?.chapter == chapter {
                #expect(string.substring(with: NSRange(location: span.numberRange.location - 2, length: 2)) == "\u{200B}\u{2060}")
                let paragraphStyle = layout.attributedString.attribute(.paragraphStyle, at: span.numberRange.location, effectiveRange: nil) as! NSParagraphStyle
                #expect(paragraphStyle.hyphenationFactor == 0, "no hyphens beside the numeral")
            }
        }
        // No strut or joiner in any span: copying, highlights and search see the verse text alone.
        for span in layout.spans {
            let full = string.substring(with: span.fullRange)
            #expect(!full.contains("\u{2060}") && !full.contains("\u{200B}"))
        }
        // John 2 opens on its heading: its zone starts at verse 1's paragraph below it.
        let second = layout.section(for: 2)!
        #expect(self.string(layout, second.openingRange) == "\u{2060}\n")
        #expect(zone(at: NSMaxRange(second.openingRange)) == nil, "the heading is not in the zone")
        #expect(zone(at: second.spans[0].textRange.location)?.part == .first)
        // The later chapter's air sits on its hairline, not on its first paragraph (here its section heading).
        let paragraph = { (index: Int) in layout.attributedString.attribute(.paragraphStyle, at: index, effectiveRange: nil) as! NSParagraphStyle }
        #expect(paragraph(second.openingRange.location).paragraphSpacingBefore == (2.4 * 18).rounded())
        #expect(paragraph(NSMaxRange(second.openingRange)).paragraphSpacingBefore == 0)
        // The other styles set no zone and no strut. Their only joiners are their later chapters'
        // empty hairlines (Matt, 2026-11-13), one a chapter, each an opening's whole text.
        let printed = JohnFixture.layout()
        #expect(!printed.attributedString.string.contains("\u{200B}"))
        #expect(printed.attributedString.string.filter { $0 == "\u{2060}" }.count == 2)
        for section in printed.sections.dropFirst() {
            #expect(self.string(printed, section.openingRange) == "\u{2060}\n")
        }
        #expect(!self.string(printed, printed.sections[0].range).contains("\u{2060}"))
        var zones = 0
        printed.attributedString.enumerateAttribute(.dropZone, in: NSRange(location: 0, length: printed.attributedString.length)) { value, _, _ in
            if value != nil { zones += 1 }
        }
        #expect(zones == 0)
    }

    /// Poetry: every line is its own paragraph, so the zone runs over the chapter's first three
    /// lines (verse numbers strutted), and the fourth is the follower. A chapter whose text is
    /// shorter than the zone hands its follower to the next chapter's opening.
    @Test func aPoetryChaptersZoneRunsOverItsFirstThreeLines() {
        let lectern = ReaderTypography.styled(ReaderPreferences(style: .lectern))
        func poem(_ chapter: Int, verses: Int) -> BookChapterInput {
            BookChapterInput(location: ChapterLocation(book: "PSA", chapter: chapter), verses: (1...verses).map { verse in
                Verse(id: VerseLocation(book: "PSA", chapter: chapter, verse: verse), translationID: "ESV",
                      text: "The first line of verse \(verse),\nand its second line.", breakAfter: verse % 2 == 0)
            })
        }
        let layout = BookLayout.build(chapters: [poem(1, verses: 3), poem(2, verses: 1), poem(3, verses: 2)],
                                      opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                      typography: lectern)
        let string = layout.attributedString.string as NSString
        func parts(_ section: BookSection) -> [DropZone.Part] {
            var parts: [DropZone.Part] = []
            var location = NSMaxRange(section.openingRange)
            while location < NSMaxRange(section.range) {
                let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
                if let zone = layout.attributedString.attribute(.dropZone, at: paragraph.location, effectiveRange: nil) as? DropZone,
                   zone.chapter == section.location.chapter {
                    parts.append(zone.part)
                }
                location = NSMaxRange(paragraph)
            }
            return parts
        }
        #expect(parts(layout.sections[0]) == [.first, .wrap, .wrap, .follower])
        // Psalm 2 has two lines: both in the zone, and Psalm 3's opening follows its numeral.
        #expect(parts(layout.sections[1]) == [.first, .wrap])
        let third = layout.sections[2].openingRange
        let follower = layout.attributedString.attribute(.dropZone, at: third.location, effectiveRange: nil) as? DropZone
        #expect(follower?.chapter == 2 && follower?.part == .follower)
        #expect(follower?.spacingBelow == 0, "below the notch, the air after Psalm 2's last line (none), then Psalm 3's own")
        // Verse 2 of Psalm 1 opens the third line: strutted.
        let two = layout.sections[0].spans[1].numberRange
        #expect(string.substring(with: NSRange(location: two.location - 2, length: 2)) == "\u{200B}\u{2060}")
    }

    /// Lectern's numeral: the page face in lining figures (the body's are old-style), sized so a
    /// figure rises from the first line's capital height to the third line's baseline.
    @Test func theNumeralRisesFromTheFirstCapitalToTheThirdBaselineInLiningFigures() {
        for size in [14.0, 18.0, 24.0, 28.0] {
            var prefs = ReaderPreferences(style: .lectern)
            prefs.fontSize = size
            let lectern = ReaderTypography.styled(prefs)
            let font = DropNumeral.font(for: lectern)
            #expect(font.familyName == lectern.bodyFont.familyName)
            let figure = font.capHeight
            #expect(abs(figure - (2 * lectern.bodyLineHeight + lectern.bodyFont.capHeight)) < 0.5, "\(size) pt")
            #expect(DropNumeral.depth(for: lectern) == 3 * lectern.bodyLineHeight)
            // Lining: a 3 sits on the baseline, where the body's old-style 3 descends below it.
            // (A round figure overshoots the baseline by a hair.)
            #expect(inkBottom(of: "3", in: font) > -0.03 * font.pointSize, "\(size) pt: \(inkBottom(of: "3", in: font)) at \(font.pointSize)")
            #expect(inkBottom(of: "3", in: lectern.bodyFont) < -0.1 * lectern.bodyFont.pointSize, "the body's old-style figures, on both platforms")
        }
    }

    /// Matt (2026-11-12): the numeral was too wide. Its figures are proportional and tracked so
    /// each one's ink stands `figureGap` of the size from the next: nearly touching, never
    /// colliding, at every size; "119" is about a quarter narrower than in the face's default
    /// (tabular) figures, and the notch follows the drawn width.
    @Test(arguments: [14.0, 18.0, 24.0, 28.0])
    func theNumeralsFiguresAreTrackedTight(size: Double) {
        var prefs = ReaderPreferences(style: .lectern)
        prefs.fontSize = size
        let lectern = ReaderTypography.styled(prefs)
        let font = DropNumeral.font(for: lectern)
        for chapter in [10, 11, 17, 71, 88, 100, 111, 119, 147, 150] {
            let line = DropNumeral.line(chapter, font: font)
            // Each glyph's ink, left to right, from its position in the line.
            var boxes: [CGRect] = []
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let count = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: count), positions = [CGPoint](repeating: .zero, count: count)
                CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
                let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
                var rects = [CGRect](repeating: .zero, count: count)
                CTFontGetBoundingRectsForGlyphs(runFont, .default, glyphs, &rects, count)
                boxes += zip(rects, positions).map { $0.offsetBy(dx: $1.x, dy: $1.y) }
            }
            #expect(boxes.count == "\(chapter)".count)
            for (left, right) in zip(boxes, boxes.dropFirst()) {
                let gap = (right.minX - left.maxX) / font.pointSize
                #expect(abs(gap - DropNumeral.figureGap) < 0.005, "\(size) pt, \(chapter): \(gap)")
            }
            let notch = DropNumeral.notch(chapter, typography: lectern)
            #expect(abs(notch.width - ceil(DropNumeral.ink(of: line).width + DropNumeral.gap(for: lectern))) < 0.01)
        }
        // The same face and size in its default (tabular) lining figures, untracked.
        var attributes = font.fontDescriptor.fontAttributes
        attributes[.featureSettings] = [[PlatformFontDescriptor.typeKey: kNumberCaseType, PlatformFontDescriptor.selectorKey: kUpperCaseNumbersSelector]]
        let untracked = CTLineCreateWithAttributedString(NSAttributedString(string: "119", attributes: [
            .font: PlatformFont(descriptor: PlatformFontDescriptor(fontAttributes: attributes), size: font.pointSize) as Any,
        ]))
        let tracked = DropNumeral.ink(of: DropNumeral.line(119, font: font)).width
        #expect(tracked < 0.8 * DropNumeral.ink(of: untracked).width, "\(size) pt: \(tracked) vs \(DropNumeral.ink(of: untracked).width)")
    }

    /// The lowest point of `text`'s glyphs as set in `font` (features applied), from the baseline.
    private func inkBottom(of text: String, in font: PlatformFont) -> CGFloat {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).minY
    }

    @Test func studyOpensWithItsLabelNameAndRule() {
        let layout = JohnFixture.layout(style: .study)
        let opening = layout.sections[0].openingRange
        #expect(string(layout, opening) == "THE GOSPEL ACCORDING TO JOHN\nJohn 1\n\u{00A0}\n")
        #expect(roles(in: layout, opening) == [.subtitle, .chapterLabel(1), .rule])
        let numberIndex = opening.location + ("THE GOSPEL ACCORDING TO JOHN\nJohn " as NSString).length
        // "John" in the title's face, the number in the chapter label's (ink.tertiary, per ReaderTypography).
        let study = ReaderTypography.styled(ReaderPreferences(style: .study))
        let font = { (index: Int) in layout.attributedString.attribute(.font, at: index, effectiveRange: nil) as? PlatformFont }
        #expect(font(numberIndex) == study.chapterLabelFont)
        #expect(font(numberIndex - 2) == study.titleFont)
        // Matt, 2026-11-13: a later chapter has no "JOHN 3" label and no rule, only its empty hairline.
        let later = layout.section(for: 3)!.openingRange
        #expect(string(layout, later) == "\u{2060}\n")
        #expect(roles(in: layout, later) == [.chapterStart(3)])
        #expect(!layout.attributedString.string.contains("JOHN 3") && !layout.attributedString.string.contains("John 3"))
    }

    @Test func classicOpensWithTheChapterInDisplay() {
        let layout = JohnFixture.layout(style: .classic)
        let opening = layout.sections[0].openingRange
        #expect(string(layout, opening) == "John 1\nThe Gospel According to John\n")
        #expect(roles(in: layout, opening) == [.chapterLabel(1), .subtitle])
        // Matt, 2026-11-13: a later chapter has no "John 2" at the headline size, only its empty
        // hairline; the running head, set at that size, names it.
        let later = layout.section(for: 2)!.openingRange
        #expect(string(layout, later) == "\u{2060}\n")
        #expect(roles(in: layout, later) == [.chapterStart(2)])
        #expect(!layout.attributedString.string.contains("John 2"))
        let font = layout.attributedString.attribute(.font, at: later.location, effectiveRange: nil) as! PlatformFont
        #expect(font.pointSize == 1)
    }

    @Test func aBookWithoutASubtitleLeavesNoGap() {
        let opening = BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil))
        let inputs = [BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 1),
                                       verses: [Verse(id: VerseLocation(book: "PSA", chapter: 1, verse: 1), translationID: "ESV", text: "Blessed is the man.", breakAfter: false)])]
        let layout = BookLayout.build(chapters: inputs, opening: opening, typography: .default)
        #expect(string(layout, layout.sections[0].openingRange) == "Psalms\nCHAPTER 1\n")
    }

    @Test func spansAreFoundByChapterAndVerse() {
        let layout = JohnFixture.layout()
        let span = layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 3))!
        #expect(span.location.chapter == 2 && span.location.verse == 3)
        #expect(layout.span(for: VerseLocation(book: "JHN", chapter: 4, verse: 1)) == nil)
        #expect(layout.span(for: VerseLocation(book: "MAT", chapter: 2, verse: 3)) == nil)
        #expect(layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 26)) == nil)
    }

    @Test func spanContainingMatchesALinearScan() {
        let layout = JohnFixture.layout()
        for index in stride(from: 0, through: layout.attributedString.length, by: 7) {
            let linear = layout.spans.first { NSLocationInRange(index, $0.fullRange) }
            #expect(layout.span(containing: index) == linear)
            let linearText = layout.spans.first { NSLocationInRange(index, $0.textRange) }
            #expect(layout.offsetWithinVerse(of: index)?.span == linearText)
            if let linearText { #expect(layout.offsetWithinVerse(of: index)?.offset == index - linearText.textRange.location) }
        }
    }

    @Test func sectionsAreFoundByChapterAndIndex() {
        let layout = JohnFixture.layout()
        #expect(layout.section(for: 2)?.location.chapter == 2)
        #expect(layout.section(for: 4) == nil)
        let second = layout.section(for: 2)!
        #expect(layout.section(containing: second.range.location)?.location.chapter == 2)
        #expect(layout.section(containing: second.range.location - 1)?.location.chapter == 1)
        #expect(layout.section(containing: layout.attributedString.length)?.location.chapter == 3)
        #expect(layout.section(containing: layout.attributedString.length + 1) == nil)
    }

    @Test func aLineStartInsideAnOpeningIsThatChaptersFirstVerse() {
        let layout = JohnFixture.layout()
        let first = VerseLocation(book: "JHN", chapter: 1, verse: 1)
        #expect(layout.firstVisibleVerse(fromLineStart: 0) == first)                 // the title
        let second = layout.section(for: 2)!
        #expect(layout.firstVisibleVerse(fromLineStart: second.openingRange.location) == VerseLocation(book: "JHN", chapter: 2, verse: 1))
        // The heading after the opening's hairline opens chapter 2 too.
        let heading = NSMaxRange(second.openingRange)
        #expect(layout.attributedString.readerRole(at: heading) == .sectionHeading)
        #expect(layout.firstVisibleVerse(fromLineStart: heading) == VerseLocation(book: "JHN", chapter: 2, verse: 1))
        // A line starting on a verse's number is that verse.
        let verse = layout.span(for: VerseLocation(book: "JHN", chapter: 3, verse: 16))!
        #expect(layout.firstVisibleVerse(fromLineStart: verse.numberRange.location) == verse.location)
        // Past the last opening, the verse containing the line.
        let last = layout.spans.last!
        #expect(layout.firstVisibleVerse(fromLineStart: last.textRange.location + 3) == last.location)
    }

    @Test func theLastVersesWrappedTailStaysInItsChapter() {
        let layout = JohnFixture.layout()
        let last = layout.span(for: VerseLocation(book: "JHN", chapter: 1, verse: 51))!
        // A line that starts inside 1:51's text (its wrapped tail) is still 1:51, not 2:1.
        #expect(layout.firstVisibleVerse(fromLineStart: last.textRange.location + 10) == last.location)
        // The "\n" that ends chapter 1 belongs to chapter 1.
        let closing = NSMaxRange(last.textRange)
        #expect((layout.attributedString.string as NSString).character(at: closing) == 0x0A)
        #expect(layout.section(containing: closing)?.location.chapter == 1)
        #expect(layout.firstVisibleVerse(fromLineStart: closing) == last.location)
        // Past the end of the string there is no line.
        #expect(layout.firstVisibleVerse(fromLineStart: layout.attributedString.length + 1) == nil)
    }

    @Test func hiddenVerseNumbersStillFindTheFirstVerse() {
        let layout = JohnFixture.layout { $0.showsVerseNumbers = false }
        let second = layout.section(for: 2)!
        #expect(layout.firstVisibleVerse(fromLineStart: second.openingRange.location) == VerseLocation(book: "JHN", chapter: 2, verse: 1))
    }

    @Test func theIDNamesTheWindowAndTheTypography() {
        let printed = JohnFixture.layout()
        #expect(printed.id.book == "JHN" && printed.id.translationID == "ESV" && printed.id.chapters == 1...3)
        #expect(JohnFixture.layout().id == printed.id)
        #expect(JohnFixture.layout(style: .study).id != printed.id)
        #expect(JohnFixture.layout { $0.fontSize = 20 }.id != printed.id)
        #expect(JohnFixture.layout { $0.justified = true }.id != printed.id)
        #expect(JohnFixture.layout(1...2).id != printed.id)
    }
}
