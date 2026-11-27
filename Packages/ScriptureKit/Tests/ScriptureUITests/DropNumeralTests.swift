#if os(macOS)
import AppKit
import ScriptureData
import Testing
@testable import ScriptureUI

/// Poetry chapters for the drop numeral's suites: every line its own paragraph, each verse two
/// lines, the first long enough to wrap and hang. A `short` chapter opens with a one-line
/// superscription and a section heading before verse 2.
@MainActor enum PsalmsFixture {
    static func layout(_ chapters: [(chapter: Int, verses: Int, short: Bool)], typography: ReaderTypography) -> BookLayout {
        let inputs = chapters.map { item in
            BookChapterInput(location: ChapterLocation(book: "PSA", chapter: item.chapter), verses: (1...item.verses).map { verse in
                let text = item.short && verse == 1
                    ? "A Psalm of David."
                    : "Blessed is the man who walks not in the counsel of the wicked, nor stands in the way of sinners,\nnor sits in the seat of scoffers;"
                return Verse(id: VerseLocation(book: "PSA", chapter: item.chapter, verse: verse), translationID: "ESV", text: text,
                             breakAfter: verse % 2 == 0)
            }, headings: item.short ? [2: [SectionHeading(text: "The Second Part", level: 1)]] : [:])
        }
        return BookLayout.build(chapters: inputs, opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                typography: typography)
    }
}

/// Lectern's drop numeral on the Mac (DESIGN.md, Page Styles; R16 superseded 2026-11-12): the
/// chapter's number drawn three lines deep beside its first paragraph, the first lines wrapping
/// to its right, laid out by `DropZoneContainer` without the numeral ever being text.
@MainActor @Suite struct DropNumeralTests {
    private typealias F = ControllerFixture
    static let lectern = ReaderTypography.styled(ReaderPreferences(style: .lectern))

    /// One line as laid out: its frame in text-container coordinates and its text.
    struct Line {
        let frame: NSRect
        let text: String
    }

    func show(_ controller: ChapterTextController, _ layout: BookLayout, typography: ReaderTypography = Self.lectern,
                      target: ScrollTarget? = nil, decorations: BookDecorations = .none) {
        controller.update(layout: layout, typography: typography, scrollTarget: target, decorations: decorations)
    }

    /// The lines of `paragraphs` paragraphs from the one holding `index`, paragraph by paragraph.
    func lines(_ controller: ChapterTextController, from index: Int, paragraphs: Int) -> [[Line]] {
        let layoutManager = controller.textView.textLayoutManager!
        let storage = controller.textView.textContentStorage!
        guard let location = storage.location(storage.documentRange.location, offsetBy: index) else { return [] }
        var result: [[Line]] = []
        layoutManager.enumerateTextLayoutFragments(from: location, options: [.ensuresLayout]) { fragment in
            result.append(fragment.textLineFragments.map { line in
                Line(frame: line.typographicBounds.offsetBy(dx: fragment.layoutFragmentFrame.minX, dy: fragment.layoutFragmentFrame.minY),
                     text: line.attributedString.attributedSubstring(from: line.characterRange).string)
            })
            return result.count < paragraphs
        }
        return result
    }

    /// The baseline of the `line`th line of the paragraph holding `index`, in text-view coordinates.
    private func baseline(_ controller: ChapterTextController, paragraphAt index: Int, line: Int) throws -> CGFloat {
        let storage = controller.textView.textContentStorage!
        let location = try #require(storage.location(storage.documentRange.location, offsetBy: index))
        let fragment = try #require(controller.textView.textLayoutManager!.textLayoutFragment(for: location))
        let fragmentLine = fragment.textLineFragments[line]
        return fragment.layoutFragmentFrame.minY + fragmentLine.typographicBounds.minY + fragmentLine.glyphOrigin.y
            + controller.textView.textContainerInset.height
    }

    /// The page's numeral, for `chapter`: one chapter has one, drawn by one view.
    private func numeral(_ controller: ChapterTextController, chapter: Int) throws -> DropNumeralView {
        let view = try #require(controller.numeralView)
        #expect(view.chapter == chapter)
        let views = controller.textView.subviews.filter { $0 is DropNumeralView }
        #expect(views.count == 1 && views.first === view)
        return view
    }

    // MARK: The wrap

    /// John 3 alone opens its first paragraph beside its numeral: the first three lines start
    /// right of the notch, the fourth at the column's edge. The numeral is drawn flush with the
    /// column's edge, its figures from the first line's capital height to the third line's
    /// baseline, and it is not in the text. The other styles have no numeral and TextKit's own
    /// fragments.
    @Test func theFirstThreeLinesWrapAroundTheNumeral() throws {
        let controller = F.makeController(width: 740, height: 500)
        let layout = JohnFixture.layout(3...3, style: .lectern)
        show(controller, layout, target: ScrollTarget(chapter: 3, verse: 1))
        let section = try #require(layout.section(for: 3))
        let start = section.spans[0].textRange.location
        let notch = DropNumeral.notch(3, typography: Self.lectern)
        let first = try #require(lines(controller, from: start, paragraphs: 1).first)
        #expect(first.count >= 4)
        for line in first.prefix(3) { #expect(abs(line.frame.minX - notch.width) < 0.5, "\(line.text)") }
        for line in first.dropFirst(3) { #expect(line.frame.minX == 0, "\(line.text)") }

        let inset = controller.textView.textContainerInset
        let three = try numeral(controller, chapter: 3)
        #expect(abs(three.origin.y - (try baseline(controller, paragraphAt: start, line: 2))) < 0.5, "on the third line's baseline")
        let capTop = try baseline(controller, paragraphAt: start, line: 0) - Self.lectern.bodyFont.capHeight
        #expect(abs(three.ink.minY - capTop) < 2, "from the first line's capital height: \(three.ink.minY) vs \(capTop)")
        #expect(abs(three.ink.minX - inset.width) < 0.5, "flush with the column's edge")
        #expect(three.ink.maxX <= inset.width + notch.width - DropNumeral.gap(for: Self.lectern) + 0.5, "the gap kept")
        #expect(three.font == DropNumeral.font(for: Self.lectern))
        let string = controller.textView.string as NSString
        #expect(string.substring(with: NSRange(location: section.openingRange.location, length: start - section.openingRange.location)) == "\u{2060}\n",
                "never text: the hairline, then verse 1's words")

        show(controller, JohnFixture.layout(3...3), typography: .default)
        #expect(controller.numeralView == nil)
        #expect(!controller.textView.subviews.contains { $0 is DropNumeralView })
        #expect(controller.textView.textLayoutManager?.delegate == nil, "the other styles lay out with TextKit's own fragments")
        #expect(controller.textView.textContainer?.isSimpleRectangularTextContainer == true)
    }

    /// Every line beside the numeral keeps the body's pitch, as tall as a wrapped line outside
    /// the zone, including those that start with a verse number (the strut's work), at every size.
    @Test(arguments: [14.0, 18.0, 24.0, 28.0])
    func linesBesideTheNumeralKeepTheBodysHeight(size: Double) throws {
        var prefs = ReaderPreferences(style: .lectern)
        prefs.fontSize = size
        let typography = ReaderTypography.styled(prefs)
        let controller = F.makeController(width: 900, height: 500)
        let layout = JohnFixture.layout(3...3, style: .lectern) { $0.fontSize = size }
        show(controller, layout, typography: typography, target: ScrollTarget(chapter: 3, verse: 1))
        let section = try #require(layout.section(for: 3))
        // The three paragraphs of the zone, the heading at 3:16, then a paragraph wholly outside.
        let paragraphs = lines(controller, from: section.spans[0].textRange.location, paragraphs: 5)
        let zone = paragraphs.prefix(3).flatMap { $0 }
        let outside = try #require(paragraphs.last?.dropFirst().first)
        #expect(zone.allSatisfy { abs($0.frame.height - outside.frame.height) < 0.5 }, "\(zone.map(\.frame.height)) vs \(outside.frame.height)")
        #expect(zone.contains { $0.text.hasPrefix(DropNumeral.strut) }, "a line starting with a strutted number")
        let notch = DropNumeral.notch(3, typography: typography)
        #expect(zone.prefix(3).allSatisfy { abs($0.frame.minX - notch.width) < 0.5 })
    }

    // MARK: Text, copy and highlights

    /// The strut before the numbers beside the numeral is in no span and never copied: a
    /// selection from the chapter's hairline opening through verse 2 copies the verses' words.
    @Test func theStrutIsNeverCopied() throws {
        let controller = F.makeController(width: 740, height: 500)
        let layout = JohnFixture.layout(3...3, style: .lectern)
        show(controller, layout, target: ScrollTarget(chapter: 3, verse: 1))
        let section = try #require(layout.section(for: 3))
        let two = section.spans[1]
        let string = controller.textView.string as NSString
        #expect(string.substring(with: NSRange(location: two.numberRange.location - 2, length: 2)) == DropNumeral.strut)
        let range = NSRange(location: section.openingRange.location, length: NSMaxRange(two.textRange) - section.openingRange.location)
        controller.textView.setSelectedRange(range)
        let expected = JohnFixture.text(3, 1) + " " + JohnFixture.text(3, 2)
        #expect(controller.selectionReport()?.selection.quotedText == expected)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("drop-numeral-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        #expect(controller.textView.writeSelection(to: pasteboard, types: [.string]))
        let copied = try #require(pasteboard.string(forType: .string))
        #expect(copied == expected)
        #expect(!copied.contains("\u{2060}") && !copied.contains("\u{200B}"))
    }

    /// A highlight on John 3:1's first words is painted on its own words right of the numeral,
    /// clear of its figures, and the outline strokes the same rect.
    @Test func aHighlightOnVerseOneIsPaintedBesideTheNumeral() throws {
        let controller = F.makeController(width: 740, height: 500)
        let layout = JohnFixture.layout(3...3, style: .lectern)
        let text = try #require(layout.section(for: 3)?.spans[0].textRange)
        let id = UUID()
        let highlight = RangeDecoration(id: id, range: NSRange(location: text.location, length: 9),
                                        style: .background(MarkupColor(lightHex: "#F8E18A", darkHex: "#554704")))
        show(controller, layout, target: ScrollTarget(chapter: 3, verse: 1),
             decorations: BookDecorations(highlights: [highlight], bookmarks: [], outlinedID: id))
        let three = try numeral(controller, chapter: 3)
        let fills = controller.backgroundFills.filter { $0.id == id }
        #expect(fills.count == 1)
        let fill = try #require(fills.first)
        let notch = DropNumeral.notch(3, typography: Self.lectern)
        #expect(abs(fill.rect.minX - (controller.textView.textContainerInset.width + notch.width)) < 0.5, "at the text's start, right of the notch")
        #expect(!fill.rect.intersects(three.ink))
        #expect(fill.rect.minY < three.ink.midY, "on the first line, beside the numeral's top")
        #expect(controller.outlineView.segmentRects == [fill.rect.insetBy(dx: -2, dy: -2)])
        controller.textView.setSelectedRange(NSRange(location: text.location, length: 5))
        #expect(controller.selectionReport()?.selection.quotedText == "Verse")
    }

    // MARK: Reflow and poetry

    /// A narrower window reflows the column: the wrap follows (three lines right of the notch, the
    /// rest at the edge) and the numeral moves with its paragraph; another translation's text of
    /// the same chapter keeps both.
    @Test func reflowingKeepsTheWrapAndTheNumeral() throws {
        let controller = F.makeController(width: 900, height: 500)
        show(controller, JohnFixture.layout(3...3, style: .lectern), target: ScrollTarget(chapter: 3, verse: 1))
        let notch = DropNumeral.notch(3, typography: Self.lectern)
        func expectWrap(_ label: String) throws {
            let section = try #require(controller.layout?.section(for: 3))
            let first = try #require(lines(controller, from: section.spans[0].textRange.location, paragraphs: 1).first)
            #expect(first.count >= 4, "\(label)")
            #expect(first.prefix(3).allSatisfy { abs($0.frame.minX - notch.width) < 0.5 }, "\(label)")
            #expect(first.dropFirst(3).allSatisfy { $0.frame.minX == 0 }, "\(label)")
            let three = try numeral(controller, chapter: 3)
            let inset = controller.textView.textContainerInset
            #expect(abs(three.ink.minX - inset.width) < 0.5, "\(label)")
            #expect(abs(three.origin.y - (try baseline(controller, paragraphAt: section.spans[0].textRange.location, line: 2))) < 0.5, "\(label)")
        }
        try expectWrap("wide")
        let reflows = controller.reflowCount
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 520, height: 500)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()
        #expect(controller.reflowCount == reflows + 1)
        #expect(try #require(controller.textView.textContainer?.size.width) < 640)
        try expectWrap("narrow")
        var prefs = ReaderPreferences(style: .lectern)
        prefs.fontSize = Self.lectern.bodyFont.pointSize
        show(controller, BookLayout.build(chapters: JohnFixture.inputs(3...3, translation: "KJV"), opening: JohnFixture.opening,
                                          typography: .styled(prefs)))
        try expectWrap("another translation")
    }

    /// Psalm 1 opens on poetry: its first three lines (two paragraphs, the first wrapping) step
    /// right of the notch, starting at its edge (the poetry indent taken back out there) with the
    /// wrapped line keeping its hang; the fourth is back at the poetry indent, and the lines follow
    /// on as they would without the numeral.
    @Test func aPoetryChapterWrapsAcrossItsShortParagraphsAndKeepsItsHang() throws {
        let controller = F.makeController(width: 740, height: 600)
        let layout = PsalmsFixture.layout([(1, 4, false)], typography: Self.lectern)
        show(controller, layout, target: ScrollTarget(chapter: 1, verse: 1))
        let notch = DropNumeral.notch(1, typography: Self.lectern)
        let indent = Self.lectern.poetryIndent, hang = Self.lectern.poetryHang
        let paragraphs = lines(controller, from: layout.sections[0].spans[0].textRange.location, paragraphs: 4)
        let all = paragraphs.flatMap { $0 }
        #expect(paragraphs[0].count == 2, "the first poetry line wraps")
        #expect(abs(all[0].frame.minX - notch.width) < 0.5)
        #expect(abs(all[1].frame.minX - (notch.width + hang)) < 0.5, "the wrapped line keeps its hang")
        #expect(abs(all[2].frame.minX - notch.width) < 0.5, "the next paragraph's line is beside the numeral too")
        #expect(abs(all[3].frame.minX - indent) < 0.5, "the fourth line is below it")
        #expect(abs(all[4].frame.minX - (indent + hang)) < 0.5)
        for (a, b) in zip(all, all.dropFirst()) {
            #expect(abs(b.frame.minY - a.frame.maxY) < 0.5, "lines follow on without a gap: \(a.text)")
        }
    }

    /// Coordinator's note on Psalm 109 (2026-11-12): its first notched line (verse 1, one line of
    /// prose, no indent) started 18 points left of the poetry lines after it (indented). Every
    /// line beside the numeral now starts at the notch's edge, whatever its paragraph's indent:
    /// a prose verse, poetry lines, and an indented prose paragraph; a wrapped poetry line keeps
    /// only its hang past that edge, and a wrapped prose line none. Each chapter alone.
    @Test func everyLineBesideTheNumeralStartsAtTheNotchsEdge() throws {
        let typography = Self.lectern
        let hang = typography.poetryHang
        func verse(_ chapter: Int, _ number: Int, _ text: String, breakAfter: Bool = false) -> Verse {
            Verse(id: VerseLocation(book: "PSA", chapter: chapter, verse: number), translationID: "ESV", text: text, breakAfter: breakAfter)
        }
        let poem = "For wicked and deceitful mouths are opened against me, speaking against me with lying tongues and words,\nthey encircle me with words of hate."
        let inputs = [
            // Psalm 109's shape: a one-line prose verse, then poetry.
            BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 109), verses: [
                verse(109, 1, "Be not silent, O God of my praise!"), verse(109, 2, poem), verse(109, 3, poem),
            ]),
            // A short prose paragraph, then an indented one that wraps beside the numeral.
            BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 110), verses: [
                verse(110, 1, "The Lord says to my Lord.", breakAfter: true),
                verse(110, 2, "The Lord sends forth from Zion your mighty scepter, and you rule in the midst of your enemies, your people offering themselves freely."),
            ]),
        ]
        let controller = F.makeController(width: 640, height: 600)
        for input in inputs {
            let layout = BookLayout.build(chapters: [input], opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                          typography: typography)
            let chapter = input.location.chapter
            show(controller, layout, target: ScrollTarget(chapter: chapter, verse: 1))
            let section = layout.sections[0]
            let notch = DropNumeral.notch(chapter, typography: typography).width
            let paragraphs = lines(controller, from: section.spans[0].textRange.location, paragraphs: 3)
            let top = try #require(paragraphs.first?.first).frame
            var notched = 0
            for paragraph in paragraphs {
                for (index, line) in paragraph.enumerated() where line.frame.minY < top.minY + 3 * top.height - 0.5 {
                    notched += 1
                    let isPoetry = paragraph.count > 0 && (paragraph[0].text.contains("wicked") || paragraph[0].text.contains("encircle"))
                    let expected = index == 0 ? notch : notch + (isPoetry ? hang : 0)
                    #expect(abs(line.frame.minX - expected) < 0.5, "Psalm \(chapter): \(line.text) at \(line.frame.minX), not \(expected)")
                }
            }
            #expect(notched == 3, "Psalm \(chapter): three lines beside the numeral")
            _ = try numeral(controller, chapter: chapter)
        }
    }

    /// A first paragraph shorter than the numeral (a one-line superscription) holds the section
    /// heading after it below the numeral, with the air it would have after three full lines.
    @Test func aShortFirstParagraphHoldsWhatFollowsBelowTheNumeral() throws {
        let controller = F.makeController(width: 740, height: 600)
        let layout = PsalmsFixture.layout([(2, 3, true)], typography: Self.lectern)
        show(controller, layout, target: ScrollTarget(chapter: 2, verse: 1))
        let inset = controller.textView.textContainerInset
        let two = try #require(layout.section(for: 2))
        let paragraphs = lines(controller, from: two.spans[0].textRange.location, paragraphs: 2)
        #expect(paragraphs[0].count == 1)
        let first = paragraphs[0][0], heading = paragraphs[1][0]
        #expect(heading.text.hasPrefix("The Second Part"))
        #expect(heading.frame.minY + inset.height > (try numeral(controller, chapter: 2)).ink.maxY, "the heading clears the numeral")
        let below = 3 * first.frame.height + Self.lectern.paragraphSpacing + Self.lectern.bodyFont.pointSize
        #expect(abs(heading.frame.minY - (first.frame.minY + below)) < 0.5, "as after three lines, with the heading's own air")
    }

    // MARK: Around the opening

    /// The chapter's hairline opening sits just above its text: a jump to verse 1 rests at the
    /// page's top, the hairline right under the head (Matt, 2026-11-13: no air above a later
    /// chapter, whose head is shown from the top and carries the chapter-note mark, the page's
    /// own being hidden); the band opens there. Chapter 1's title block ends on its hairline,
    /// and there the mark still sits in the air above it, flush with the column's trailing edge,
    /// clear of the text and the numeral.
    @Test func theMarkTheJumpAndTheBandFollowTheHairline() throws {
        let controller = F.makeController(width: 740, height: 500)
        controller.headLineY = 40
        let layout = JohnFixture.layout(3...3, style: .lectern)
        show(controller, layout, target: ScrollTarget(chapter: 3, verse: 20))
        show(controller, layout, target: ScrollTarget(chapter: 3, verse: 1))
        controller.chapterNoteCounts = [3: 2]
        let section = try #require(layout.section(for: 3))
        let inset = controller.textView.textContainerInset
        let hairline = try #require(controller.lineFrame(forCharacterIndex: section.openingRange.location))
        let text = try #require(controller.lineFrame(forCharacterIndex: section.spans[0].textRange.location))
        #expect(hairline.height <= 1.5 && abs(text.minY - hairline.maxY) < 0.5, "the text starts at the hairline")
        let mark = try #require(controller.chapterNoteMarkViews[3])
        #expect(mark.isHidden && mark.alphaValue == 0, "the head carries the mark")
        #expect(controller.scrollView.contentView.bounds.minY == 0)
        #expect(inset.height == max(ChapterTextController.verticalInset, 40 + ChapterTextController.scrollLeadIn))
        #expect(abs(hairline.minY + inset.height - (controller.headLineY + ChapterTextController.scrollLeadIn)) < 0.5, "right under the head")
        #expect(hairline.minY + inset.height >= controller.headLineY + ChapterTextController.scrollLeadIn, "below the head's line")
        #expect(try numeral(controller, chapter: 3).ink.minY >= controller.headLineY, "the numeral clears the head")
        #expect(controller.runningHead?.chapter == 3 && controller.runningHead?.headOpacity == 1)
        let band = try #require(controller.chapterBand)
        #expect(band.chapter == 3)
        #expect(abs(band.openingMinY - (hairline.minY + inset.height)) < 0.5)

        // Chapter 1: the head is hidden over the title block, whose hairline carries the mark above it.
        let one = JohnFixture.layout(1...1, style: .lectern)
        show(controller, one, target: ScrollTarget(chapter: 1, verse: 1))
        controller.chapterNoteCounts = [1: 2]
        let opening = try #require(one.section(for: 1))
        #expect(one.marksAboveOpeningLine(of: opening))
        let oneInset = controller.textView.textContainerInset
        #expect(oneInset.height == ChapterTextController.verticalInset)
        let oneText = try #require(controller.lineFrame(forCharacterIndex: opening.spans[0].textRange.location))
        let oneMark = try #require(controller.chapterNoteMarkViews[1])
        #expect(!oneMark.isHidden && oneMark.alphaValue == 1)
        let column = try #require(controller.textView.textContainer?.size.width)
        #expect(abs(oneMark.frame.maxX - (oneInset.width + column)) < 0.5)
        #expect(!oneMark.frame.intersects(try numeral(controller, chapter: 1).ink))
        #expect(oneMark.frame.minY >= 0 && oneMark.frame.maxY <= oneText.minY + oneInset.height - AppSpacing.xs + 0.5, "above the text's first line")
        #expect(controller.runningHead?.chapter == 1 && controller.runningHead?.headOpacity == 0)
    }

    /// VoiceOver: the numeral is a text element reading "Chapter 3" at its figures, and the
    /// headings rotor lists the chapter's opening.
    @Test func voiceOverReadsTheNumeralAndTheRotorListsTheChapter() throws {
        let controller = F.makeController(width: 740, height: 500)
        show(controller, JohnFixture.layout(3...3, style: .lectern), target: ScrollTarget(chapter: 3, verse: 1))
        let numerals = (controller.textView.accessibilityChildren() ?? []).compactMap { $0 as? DropNumeralView }
        #expect(numerals.compactMap { $0.accessibilityLabel() } == ["Chapter 3"])
        #expect(numerals.allSatisfy { $0.isAccessibilityElement() && $0.accessibilityRole() == .staticText })
        #expect(numerals.first?.frame.contains(try numeral(controller, chapter: 3).ink) == true)
        #expect(controller.headingItems.map(\.label).filter { $0.hasPrefix("John ") } == ["John 3"])
    }

    // MARK: Psalms one at a time

    /// Matt's report (2026-11-12): Psalm 119's numeral over Psalm 108's first lines, after the
    /// window had been resized. Psalms 119 and 108 loaded one at a time, through a reflow and a
    /// size change: the page has one numeral, in one small view (never one overlay the height
    /// of the page, whose stale backing showed on screen), naming its own chapter and sitting in
    /// its own notch: its figures end no lower than the notch, flush with the column's edge, and
    /// no line outside the notch touches them. Psalm 108 opens on a one-line superscription and
    /// a heading.
    @Test func eachPsalmsNumeralStaysInItsOwnNotchThroughReflowAndSizeChanges() throws {
        let helper = self
        let controller = F.makeController(width: 900, height: 700)
        var typography = Self.lectern
        func load(_ chapter: Int) throws -> BookLayout {
            let layout = PsalmsFixture.layout([(chapter, 2 + chapter % 3, chapter % 7 == 3)], typography: typography)
            helper.show(controller, layout, typography: typography, target: ScrollTarget(chapter: chapter, verse: 1))
            return layout
        }
        func expectInItsNotch(_ layout: BookLayout, _ label: String) throws {
            let inset = controller.textView.textContainerInset
            let section = layout.sections[0]
            let chapter = section.location.chapter
            let view = try helper.numeral(controller, chapter: chapter)
            #expect(view.superview === controller.textView, "\(label)")
            let paragraphs = helper.lines(controller, from: section.spans[0].textRange.location, paragraphs: 5)
            let all = paragraphs.flatMap { $0 }
            let top = try #require(all.first).frame.minY, pitch = try #require(all.first).frame.height
            let depth = 3 * pitch
            let notch = DropNumeral.notch(chapter, typography: typography)
            #expect(view.frame.height < depth, "\(label): a small view, \(view.frame)")
            #expect(view.ink.maxY <= top + depth + inset.height, "\(label): no lower than its notch")
            #expect(abs(view.ink.minY - (top + inset.height)) < pitch, "\(label): beside its first line")
            #expect(abs(view.ink.minX - inset.width) < 0.5, "\(label)")
            #expect(view.ink.maxX <= inset.width + notch.width - DropNumeral.gap(for: typography) + 0.5, "\(label)")
            for line in all where line.frame.minY < top + depth - 0.5 {
                #expect(line.frame.minX >= notch.width - 0.5, "\(label): notched \(line.text)")
            }
            for line in all where line.frame.minY >= top + depth - 0.5 {
                #expect(!line.frame.offsetBy(dx: inset.width, dy: inset.height).insetBy(dx: 0, dy: 1).intersects(view.ink),
                        "\(label): \(line.text) clear of the figures")
            }
        }
        var layout = try load(119)
        try expectInItsNotch(layout, "119")
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 620, height: 800)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()
        try expectInItsNotch(layout, "119 reflowed")
        layout = try load(108)
        try expectInItsNotch(layout, "108 after 119")
        var prefs = ReaderPreferences(style: .lectern)
        prefs.fontSize = 24
        typography = ReaderTypography.styled(prefs)
        layout = try load(108)
        try expectInItsNotch(layout, "108 at 24 pt")
        typography = Self.lectern
        layout = try load(119)
        try expectInItsNotch(layout, "119 at 18 pt")
    }
}
#endif
