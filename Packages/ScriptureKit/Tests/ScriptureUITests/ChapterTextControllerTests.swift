#if os(macOS)
import AppKit
import ScriptureData
import Testing
@testable import ScriptureUI

/// Book layouts for the controller suites: Matthew-shaped chapters of long verses that wrap in the
/// column, a paragraph break every four verses.
@MainActor enum ControllerFixture {
    static let opening = BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: "The Gospel According to Matthew"))

    static func verses(chapter: Int = 5, count: Int, translation: String = "WEB", book: String = "MAT") -> [Verse] {
        (1...count).map { n in
            Verse(
                id: VerseLocation(book: book, chapter: chapter, verse: n),
                translationID: translation,
                text: "Verse \(n) of \(translation) says enough words to wrap onto a second line in a narrow column, surely.",
                breakAfter: n % 4 == 0)
        }
    }

    /// One chapter alone in the window: its opening is the title block for chapter 1, an empty hairline otherwise.
    static func layout(_ verses: [Verse], typography: ReaderTypography = .default) -> BookLayout {
        let first = verses[0].id
        return BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: first.book, chapter: first.chapter), verses: verses)],
                                opening: opening, typography: typography)
    }

    /// Chapters `range` of a book whose chapter n has `counts[n]` verses (30 when not given).
    static func book(_ range: ClosedRange<Int>, counts: [Int: Int] = [:], translation: String = "WEB", book: String = "MAT",
                     headings: [Int: [Int: [SectionHeading]]] = [:], typography: ReaderTypography = .default) -> BookLayout {
        let inputs = range.map { chapter in
            BookChapterInput(location: ChapterLocation(book: book, chapter: chapter),
                             verses: verses(chapter: chapter, count: counts[chapter] ?? 30, translation: translation, book: book),
                             headings: headings[chapter] ?? [:])
        }
        return BookLayout.build(chapters: inputs, opening: opening, typography: typography)
    }

    static func decorations(_ items: [MarkupItem], bookmarks: [VerseLocation] = [], outlinedID: UUID? = nil,
                            viewing translation: String = "WEB", layout: BookLayout) -> BookDecorations {
        BookDecorations.build(
            itemsByChapter: Dictionary(grouping: items, by: \.chapter),
            bookmarksByChapter: Dictionary(grouping: bookmarks, by: \.chapter).mapValues { $0.map(\.verse) },
            outlinedID: outlinedID, viewingTranslationID: translation, layout: layout)
    }

    static func makeController(width: CGFloat = 700, height: CGFloat = 300, reported: @escaping (VerseLocation) -> Void = { _ in }) -> ChapterTextController {
        let controller = ChapterTextController(onReadingPositionChange: reported)
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        controller.scrollView.layoutSubtreeIfNeeded()
        return controller
    }

    /// On screen the text view grows to hold the text after layout; headless, the test does that itself.
    static func sizeToContent(_ controller: ChapterTextController) {
        let textView = controller.textView
        let height = textView.textLayoutManager!.usageBoundsForTextContainer.maxY + 2 * textView.textContainerInset.height
        textView.setFrameSize(NSSize(width: textView.frame.width, height: height))
    }

    static func scroll(_ controller: ChapterTextController, toY y: CGFloat) {
        controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
        controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
    }

    /// The rendering attributes TextKit holds at `index`.
    static func renderingAttributes(_ controller: ChapterTextController, at index: Int) -> [NSAttributedString.Key: Any] {
        // Only runs that carry attributes are enumerated, so find the one containing `index`.
        let storage = controller.textView.textContentStorage!
        let layoutManager = controller.textView.textLayoutManager!
        var found: [NSAttributedString.Key: Any] = [:]
        layoutManager.enumerateRenderingAttributes(from: layoutManager.documentRange.location, reverse: false) { _, attributes, range in
            let start = storage.offset(from: storage.documentRange.location, to: range.location)
            let end = storage.offset(from: storage.documentRange.location, to: range.endLocation)
            if index >= start && index < end { found = attributes; return false }
            return start <= index
        }
        return found
    }
}

/// Drives the TextKit 2 controller without a window: an NSScrollView with a fixed frame lays out off screen.
@MainActor @Suite struct ChapterTextControllerTests {
    private typealias F = ControllerFixture

    private func verses(count: Int, translation: String = "WEB") -> [Verse] {
        F.verses(count: count, translation: translation)
    }

    /// A verse of Matthew 5.
    private func at(_ verse: Int) -> VerseLocation {
        VerseLocation(book: "MAT", chapter: 5, verse: verse)
    }

    private func at(_ chapter: Int, _ verse: Int, book: String = "MAT") -> VerseLocation {
        VerseLocation(book: book, chapter: chapter, verse: verse)
    }

    private func makeController(reported: @escaping (VerseLocation) -> Void) -> ChapterTextController {
        F.makeController(reported: reported)
    }

    private func sizeToContent(_ controller: ChapterTextController) {
        F.sizeToContent(controller)
    }

    /// The layout's verses shown with `.default` typography.
    private func show(_ controller: ChapterTextController, _ layout: BookLayout, typography: ReaderTypography = .default,
                      target: ScrollTarget? = nil, decorations: BookDecorations = .none) {
        controller.update(layout: layout, typography: typography, scrollTarget: target, decorations: decorations)
    }

    /// The column is as wide as the typography's measure when the window allows, centred, and
    /// narrows with the window when it does not; a measure alone (the column width setting)
    /// changes it without new text.
    @Test func columnWidthFollowsTheMeasure() {
        let controller = F.makeController(width: 1200)
        let chapter = verses(count: 5)
        show(controller, F.layout(chapter))
        #expect(controller.textView.textContainer?.size.width == 640)
        let large = typo(24, .normal)
        show(controller, F.layout(chapter, typography: large), typography: large)
        #expect(controller.textView.textContainer?.size.width == large.measure)
        let inset = controller.textView.textContainerInset.width
        #expect(abs(inset * 2 + large.measure - controller.textView.frame.width) < 1)
        var narrower = large
        narrower.measure = large.measure - 100
        let layout = controller.layout
        show(controller, F.layout(chapter, typography: large), typography: narrower)
        #expect(controller.textView.textContainer?.size.width == narrower.measure)
        #expect(controller.layout?.attributedString === layout?.attributedString)
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 600, height: 300)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()      // the resize settles
        #expect(controller.textView.textContainer!.size.width < narrower.measure)
        #expect(controller.textView.textContainerInset.width == ChapterTextController.horizontalInset)
    }

    @Test func scrollingToAVerseReportsThatVerse() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.layout(verses(count: 60)), target: ScrollTarget(chapter: 5, verse: 40))
        // The controller sizes the text view itself after a full layout, so the scroll lands at once.
        #expect(controller.scrollView.contentView.bounds.minY > 0)
        #expect(reported == [at(40)])
        sizeToContent(controller)
        #expect(reported == [at(40)])
    }

    @Test func anAtEndTargetLandsAtTheClipsMaximum() {
        let controller = makeController { _ in }
        show(controller, F.layout(verses(count: 60)), target: ScrollTarget(chapter: 5, verse: 1, atEnd: true))
        let clip = controller.scrollView.contentView.bounds
        let documentHeight = controller.scrollView.documentView?.frame.height ?? 0
        #expect(clip.minY > 0)
        #expect(abs(clip.maxY - documentHeight) < 0.5)
    }

    @Test func replacingTheTextNeverReportsVerseOneOnTheWay() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.layout(verses(count: 60)), target: ScrollTarget(chapter: 5, verse: 40))
        sizeToContent(controller)
        show(controller, F.layout(verses(count: 60, translation: "KJV")), target: ScrollTarget(chapter: 5, verse: 40))
        sizeToContent(controller)
        #expect(reported == [at(40), at(40)])
    }

    /// The text is replaced only when the layout's id changes, not for another copy of the same layout.
    @Test func aLayoutWithTheSameIDIsNotReapplied() {
        let controller = makeController { _ in }
        let first = F.layout(verses(count: 10))
        show(controller, first, target: ScrollTarget(chapter: 5, verse: 1))
        show(controller, F.layout(verses(count: 10)), target: ScrollTarget(chapter: 5, verse: 1))
        #expect(controller.layout?.attributedString === first.attributedString)
    }

    @Test func typographyChangeReappliesTheText() {
        let controller = makeController { _ in }
        show(controller, F.layout(verses(count: 10)))
        var larger = ReaderTypography.default
        larger.bodyFont = ReaderTypography.serifFont(size: 24)
        let layout = F.layout(verses(count: 10), typography: larger)
        show(controller, layout, typography: larger)
        let index = layout.spans[0].textRange.location + 2
        let font = controller.textView.textStorage?.attribute(.font, at: index, effectiveRange: nil) as? NSFont
        #expect(font?.pointSize == 24)
    }

    @Test func selectionMapsToVerseAndOffset() {
        let layout = F.layout(verses(count: 3))
        let hit = layout.offsetWithinVerse(of: layout.spans[0].textRange.location + 6)
        #expect(hit?.span.location == at(1))
        #expect(hit?.offset == 6)
    }

    private var yellow: MarkupColor { MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00") }
    private var blue: MarkupColor { MarkupColor(lightHex: "#B9DDFF", darkHex: "#1F4C7A") }

    private func item(_ chapter: Int, _ verse: Int, _ start: Int, _ end: Int, endVerse: Int? = nil, translation: String = "WEB",
                      color: MarkupColor?, note: Bool = false) -> MarkupItem {
        MarkupItem(id: UUID(), chapter: chapter, verse: verse, endVerse: endVerse ?? verse, startOffset: start, endOffset: end,
                   translationID: translation, color: color, hasNote: note)
    }

    /// A highlight in Matthew 5.
    private func item(_ verse: Int, _ start: Int, _ end: Int, endVerse: Int? = nil, translation: String = "WEB",
                      color: MarkupColor?, note: Bool = false) -> MarkupItem {
        item(5, verse, start, end, endVerse: endVerse, translation: translation, color: color, note: note)
    }

    @Test func highlightsBecomeBackgroundFillsAndUnderlinesStayStorageAttributes() {
        let controller = makeController { _ in }
        let layout = F.layout(verses(count: 3))
        let a = item(1, 0, 10, color: yellow)
        let c = item(2, 0, 5, color: nil, note: true)
        show(controller, layout, decorations: F.decorations([a, c], bookmarks: [at(3)], layout: layout))
        let v2 = layout.spans[1].textRange.location
        #expect(controller.backgroundFills.contains { $0.id == a.id })
        #expect(F.renderingAttributes(controller, at: layout.spans[0].textRange.location + 2)[.backgroundColor] == nil)   // no attribute-drawn backgrounds
        let storage = controller.textView.textStorage!
        #expect((storage.attribute(.underlineStyle, at: v2 + 1, effectiveRange: nil) as? Int) == NSUnderlineStyle([.single, .patternDot]).rawValue)
        // Re-applying without the dotted item clears it again.
        show(controller, layout, decorations: F.decorations([a], layout: layout))
        #expect(storage.attribute(.underlineStyle, at: v2 + 1, effectiveRange: nil) == nil)
    }

    /// Two underlines overlapping: removing one keeps the other's underline on the shared words.
    @Test func removingOneOfTwoOverlappingUnderlinesKeepsTheOther() {
        let controller = makeController { _ in }
        let layout = F.layout(verses(count: 3))
        let a = item(1, 0, 20, color: nil, note: true)
        let b = item(1, 10, 30, color: nil, note: true)
        show(controller, layout, decorations: F.decorations([a, b], layout: layout))
        show(controller, layout, decorations: F.decorations([b], layout: layout))
        let storage = controller.textView.textStorage!
        let v1 = layout.spans[0].textRange.location
        #expect(storage.attribute(.underlineStyle, at: v1 + 5, effectiveRange: nil) == nil)
        #expect(storage.attribute(.underlineStyle, at: v1 + 15, effectiveRange: nil) != nil)
        #expect(storage.attribute(.underlineStyle, at: v1 + 25, effectiveRange: nil) != nil)
    }

    @Test func bookmarkGlyphsAndOutlineFollowTheDecorations() {
        let controller = makeController { _ in }
        let layout = F.layout(verses(count: 6))
        let a = item(5, 0, 10, color: yellow)
        var decorations = F.decorations([a], bookmarks: [at(2), at(5)], layout: layout)
        show(controller, layout, decorations: decorations)
        sizeToContent(controller)
        #expect(controller.gutterView.glyphRects.count == 2)
        #expect(controller.gutterView.glyphRects[0].minY < controller.gutterView.glyphRects[1].minY)
        #expect(controller.gutterView.glyphVerses == [at(2), at(5)])
        let labels = (controller.textView.accessibilityChildren() ?? []).compactMap { ($0 as? NSAccessibilityElement)?.accessibilityLabel() }
        #expect(labels.contains("Bookmark, chapter 5 verse 2") && labels.contains("Bookmark, chapter 5 verse 5"))
        #expect(controller.outlineView.segmentRects.isEmpty)
        decorations.outlinedID = a.id
        show(controller, layout, decorations: decorations)
        #expect(controller.outlineView.segmentRects.count >= 1)
        decorations.outlinedID = nil
        show(controller, layout, decorations: decorations)
        #expect(controller.outlineView.segmentRects.isEmpty)
    }

    @Test func selectionChangesAreReportedWithTheHighlightsTheyTouch() {
        var reports: [SelectionReport?] = []
        let controller = makeController { _ in }
        controller.onSelectionChange = { reports.append($0) }
        let layout = F.layout(verses(count: 3))
        let a = item(1, 0, 10, color: yellow)
        show(controller, layout, decorations: F.decorations([a], layout: layout))
        let v1 = layout.spans[0].textRange.location
        controller.textView.setSelectedRange(NSRange(location: v1 + 2, length: 3))
        #expect(reports.last??.selection.quotedText == "rse")
        #expect(reports.last??.highlightIDs == [a.id])
        controller.textView.setSelectedRange(NSRange(location: v1 + 4, length: 0))      // caret inside a
        #expect(reports.last??.highlightIDs == [a.id])
        #expect(reports.last??.selection.startOffset == 0 && reports.last??.selection.endOffset == 10)
        controller.textView.setSelectedRange(layout.spans[1].numberRange)                // a verse number only
        #expect(reports.count >= 3 && reports.last! == nil)
        controller.textView.setSelectedRange(NSRange(location: v1 + 2, length: 1))
        controller.textView.setSelectedRange(layout.sections[0].openingRange)            // the chapter's opening
        #expect(reports.last! == nil)
    }

    /// A drag from inside the chapter's opening (chapter 1's title block, a later chapter's empty
    /// hairline) into its first verse reports only the verse's words.
    @Test(arguments: [1, 5])
    func textInAnOpeningIsNeverPartOfASelectionReport(chapter: Int) {
        let controller = makeController { _ in }
        let layout = F.book(chapter...chapter, counts: [chapter: 3])
        show(controller, layout)
        let opening = layout.section(for: chapter)!.openingRange
        let first = layout.span(for: at(chapter, 1))!
        #expect(opening.length >= 2 && first.textRange.location >= NSMaxRange(opening))
        controller.textView.setSelectedRange(NSRange(location: opening.location + 1, length: first.textRange.location + 5 - opening.location - 1))
        let report = controller.selectionReport()
        #expect(report?.selection.chapter == chapter && report?.selection.verse == 1 && report?.selection.startOffset == 0)
        #expect(report?.selection.quotedText == "Verse")
        #expect((report?.range.location ?? 0) >= NSMaxRange(opening))
    }

    @Test func gutterGlyphsSurviveAWidthChangeAcrossParagraphs() {
        let controller = makeController { _ in }
        let layout = F.layout(verses(count: 40))   // breakAfter every 4 verses: many layout fragments
        show(controller, layout, decorations: F.decorations([], bookmarks: [at(2), at(30)], layout: layout))
        sizeToContent(controller)
        let before = controller.gutterView.glyphRects
        #expect(before.count == 2 && before[1].minY > before[0].minY + 200)
        // A wider column reflows the text; the glyphs must follow the new line positions, not stale ones.
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 1100, height: 300)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()      // the resize settles
        let after = controller.gutterView.glyphRects
        #expect(after.count == 2 && after[1].minY > after[0].minY + 200)
        #expect(after[1].minY < before[1].minY)   // wider lines: verse 30 sits higher than before
    }

    @Test func aCaretInsideAHighlightNormalizesToItsWholeRangeAndADragSnapsToWords() {
        let controller = makeController { _ in }
        let layout = F.layout(verses(count: 3))
        let a = item(1, 0, 10, color: yellow)
        show(controller, layout, decorations: F.decorations([a], layout: layout))
        let v1 = layout.spans[0].textRange.location
        controller.textView.setSelectedRange(NSRange(location: v1 + 3, length: 0))
        #expect(controller.actionRange() == NSRange(location: v1, length: 10))   // the whole highlight
        controller.textView.setSelectedRange(NSRange(location: v1 + 13, length: 0))
        #expect(controller.actionRange() == nil)                                  // a caret outside any highlight
        controller.textView.setSelectedRange(NSRange(location: v1 + 2, length: 4))      // "rse " cut mid-word
        #expect(controller.actionRange() == NSRange(location: v1, length: 6))     // "Verse " (the resolver trims the space)
    }

    @Test func aCaretReportNamesTheInnermostHighlightAndKeepsTheCaret() {
        var reports: [SelectionReport?] = []
        let controller = makeController { _ in }
        controller.onSelectionChange = { reports.append($0) }
        let layout = F.layout(verses(count: 3))
        let outer = item(1, 0, 20, color: yellow)
        let inner = item(1, 6, 10, color: blue)
        show(controller, layout, decorations: F.decorations([outer, inner], layout: layout))
        let v1 = layout.spans[0].textRange.location
        controller.textView.setSelectedRange(NSRange(location: v1 + 8, length: 0))
        #expect(reports.last??.primaryHighlightID == inner.id)
        #expect(Set(reports.last??.highlightIDs ?? []) == [outer.id, inner.id])
        #expect(controller.textView.selectedRange() == NSRange(location: v1 + 8, length: 0))
        // The action range for the menu is the innermost highlight, without changing the selection.
        #expect(controller.actionRange() == NSRange(location: v1 + 6, length: 4))
    }

    @Test func outlineSegmentsHugTheGlyphsOfTheHighlight() {
        let controller = makeController { _ in }
        let layout = F.layout(verses(count: 2))
        let a = item(1, 0, 5, color: yellow)   // "Verse"
        show(controller, layout, decorations: F.decorations([a], outlinedID: a.id, layout: layout))
        sizeToContent(controller)
        let fill = controller.backgroundFills.first { $0.id == a.id }?.rect
        let rect = controller.outlineView.segmentRects.first
        #expect(fill != nil && rect == fill?.insetBy(dx: -2, dy: -2))
        // Expected from the line fragment's own glyph positions and the body font's vertical
        // extent (what TextKit paints the background with), offset by the container inset.
        let textView = controller.textView
        let storage = textView.textContentStorage!, layoutManager = textView.textLayoutManager!
        let start = layout.spans[0].textRange.location
        let location = storage.location(storage.documentRange.location, offsetBy: start)!
        let fragment = layoutManager.textLayoutFragment(for: location)!
        let fragmentStart = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
        let line = fragment.textLineFragments.first { NSLocationInRange(start - fragmentStart, $0.characterRange) }!
        let x0 = line.typographicBounds.minX + line.locationForCharacter(at: start - fragmentStart).x
        let x1 = line.typographicBounds.minX + line.locationForCharacter(at: start + 5 - fragmentStart).x
        let inset = textView.textContainerInset
        let font = ReaderTypography.default.bodyFont
        let baseline = fragment.layoutFragmentFrame.minY + line.typographicBounds.minY + line.glyphOrigin.y + inset.height
        #expect(abs((fill?.minX ?? -1) - (fragment.layoutFragmentFrame.minX + x0 + inset.width)) < 0.5)
        #expect(abs((fill?.maxX ?? -1) - (fragment.layoutFragmentFrame.minX + x1 + inset.width)) < 0.5)
        #expect(abs((fill?.minY ?? -1) - (baseline - font.ascender)) < 0.5)
        #expect(abs((fill?.height ?? -1) - (font.ascender - font.descender)) < 0.5)
        #expect((fill?.height ?? 0) < line.typographicBounds.height)   // tighter than the 1.3× line
    }

    @Test func switchingTextWithUnderlineDecorationsKeepsTheScrollTarget() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.layout(verses(count: 60, translation: "ESV")), target: ScrollTarget(chapter: 5, verse: 29))
        sizeToContent(controller)
        #expect(reported == [at(29)])
        // Highlights made in ESV draw as dashed underlines (storage attributes) once KJV is shown.
        let kjv = F.layout(verses(count: 60, translation: "KJV"))
        let items = (1...20).map { item($0 * 3, 0, 5, translation: "ESV", color: yellow) }
        show(controller, kjv, target: ScrollTarget(chapter: 5, verse: 29), decorations: F.decorations(items, viewing: "KJV", layout: kjv))
        sizeToContent(controller)
        #expect(reported == [at(29), at(29)])
        #expect(controller.scrollView.contentView.bounds.minY > 0)
    }

    /// A new translation arriving without a new target (the layout first) keeps the verse being
    /// read, not the earlier jump's target.
    @Test func newTextWithoutANewTargetStaysOnTheVerseBeingRead() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        let target = ScrollTarget(chapter: 5, verse: 10)
        show(controller, F.layout(verses(count: 60)), target: target)
        let lineHeight = ReaderTypography.default.bodyLineHeight
        F.scroll(controller, toY: controller.scrollView.contentView.bounds.minY + 30 * lineHeight)
        let reading = reported.last!
        #expect(reading.verse > 15)
        show(controller, F.layout(verses(count: 60, translation: "KJV")), target: target)
        #expect(reported.last == reading)
    }

    @Test func collapsingTheSelectionLeavesACaretAtItsStart() {
        var reports: [SelectionReport?] = []
        let controller = makeController { _ in }
        controller.onSelectionChange = { reports.append($0) }
        let layout = F.layout(verses(count: 3))
        show(controller, layout)
        let v1 = layout.spans[0].textRange.location
        controller.textView.setSelectedRange(NSRange(location: v1 + 2, length: 5))
        controller.collapseSelection()
        #expect(controller.textView.selectedRange() == NSRange(location: v1 + 2, length: 0))
        #expect(reports.count == 2 && reports.last! == nil)
    }

    @Test func addingAnUnderlineKeepsTheScrollPosition() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        let layout = F.layout(verses(count: 60))
        let target = ScrollTarget(chapter: 5, verse: 29)
        show(controller, layout, target: target)
        sizeToContent(controller)
        let origin = controller.scrollView.contentView.bounds.minY
        #expect(reported == [at(29)] && origin > 0)
        // A note anchor on a visible verse: a dotted underline, which is a text-storage edit.
        let anchor = item(30, 0, 5, color: nil, note: true)
        show(controller, layout, target: target, decorations: F.decorations([anchor], layout: layout))
        sizeToContent(controller)
        #expect(abs(controller.scrollView.contentView.bounds.minY - origin) < 0.5)
        #expect(reported == [at(29)])
    }

    /// Scrolled to the end of a long chapter, the first visible verse is found by looking at the
    /// visible fragment, not by walking from the top; the answer is the same either way.
    @Test func firstVisibleVerseAtTheEndOfALongChapterIsTheLastVerse() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.layout(verses(count: 400)), target: ScrollTarget(chapter: 5, verse: 1))
        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        F.scroll(controller, toY: maxY)
        #expect(reported.last.map { $0.verse >= 396 } == true)
    }

    /// The progress line's value is the head's: 0 with the head's line in the chapter's opening,
    /// its share of the chapter's text in between, 1 at the page's foot (any chapter's, not only
    /// a book's last); the last value reported is the one shown.
    @Test func progressRunsFromZeroAtTheTopToOneAtTheEnd() {
        var reported: [RunningHeadState] = []
        let controller = makeController { _ in }
        controller.onRunningHeadChange = { reported.append($0) }
        show(controller, F.layout(verses(count: 120)), target: ScrollTarget(chapter: 5, verse: 1))
        #expect(controller.runningHead?.progress == 0)
        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        F.scroll(controller, toY: maxY / 2)
        let band = controller.chapterBand!
        let line = maxY / 2 + ChapterTextController.scrollLeadIn   // the line just under the (absent) head
        let expected = Double((line - band.openingMaxY) / (band.textMaxY - band.openingMaxY))
        #expect(abs((controller.runningHead?.progress ?? 0) - expected) < 0.001)
        #expect(expected > 0.3 && expected < 0.6)
        F.scroll(controller, toY: maxY)
        #expect(controller.runningHead?.progress == 1)
        #expect(reported.last?.progress == 1)
    }

    /// The scroll from where a jump landed, in lines of body text: the jump itself reports nothing,
    /// the reader's scroll is measured from its landing in either direction, and the next jump
    /// starts again from zero.
    @Test func theScrollSinceAJumpIsReportedInBodyLines() {
        var reported: [Double] = []
        let controller = makeController { _ in }
        var targets: [ScrollTarget] = []
        controller.onScrollSinceJump = { reported.append($0); targets.append($1) }
        let typography = ReaderTypography.default
        let layout = F.layout(verses(count: 120))
        let first = ScrollTarget(chapter: 5, verse: 40)
        show(controller, layout, target: first)
        #expect(reported.isEmpty)
        let landed = controller.scrollView.contentView.bounds.minY
        F.scroll(controller, toY: landed + 6 * typography.bodyLineHeight)
        #expect(abs((reported.last ?? 0) - 6) < 0.01)
        F.scroll(controller, toY: landed - 2 * typography.bodyLineHeight)
        #expect(abs((reported.last ?? 0) + 2) < 0.01)
        #expect(targets.allSatisfy { $0 == first })
        reported = []
        targets = []
        let second = ScrollTarget(chapter: 5, verse: 80)
        show(controller, layout, target: second)
        #expect(reported.isEmpty)
        let next = controller.scrollView.contentView.bounds.minY
        F.scroll(controller, toY: next + typography.bodyLineHeight)
        #expect(abs((reported.last ?? 0) - 1) < 0.01)
        #expect(targets == [second])   // each report names the jump it was measured from
    }

    /// Fix round 1 (milestone 8): a jump whose highlight is then scrolled into view (a note looked
    /// up, its highlight off screen after the verse scroll) lands where that second scroll leaves
    /// the page, so the follow-up scroll is not reading on.
    @Test func aJumpLandsAfterTheScrollToItsHighlight() {
        var reported: [Double] = []
        let controller = makeController { _ in }
        controller.onScrollSinceJump = { lines, _ in reported.append(lines) }
        let typography = ReaderTypography.default
        let layout = F.layout(verses(count: 120))
        let far = item(70, 0, 10, color: yellow, note: true)
        var decorations = F.decorations([far], layout: layout)
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 1), decorations: decorations)
        // The jump: to verse 40, with verse 70's highlight outlined in the same update.
        decorations.outlinedID = far.id
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 40), decorations: decorations)
        let landed = controller.scrollView.contentView.bounds.minY
        #expect(reported.allSatisfy { abs($0) < NavigationModel.linesThatKeepAJump }, "the highlight scroll counted: \(reported)")
        F.scroll(controller, toY: landed + 2 * typography.bodyLineHeight)
        #expect(abs((reported.last ?? 0) - 2) < 0.01, "measured from the highlight's scroll: \(reported)")
    }

    /// A chapter shorter than the window has nowhere to scroll, so it has no progress to show.
    @Test func progressIsZeroWhenTheChapterFits() {
        let controller = makeController { _ in }
        show(controller, F.layout(verses(count: 2)), target: ScrollTarget(chapter: 5, verse: 1))
        #expect(controller.runningHead?.progress == 0)
    }

    /// With the links' space kept under the text, the head's line never reaches the chapter's
    /// last line, yet at the page's foot the chapter is read through: progress 1 there, and short
    /// of 1 a point above it.
    @Test func theProgressIsOneAtTheChaptersFoot() {
        var reported: [RunningHeadState] = []
        let controller = makeController { _ in }
        controller.headLineY = 40
        controller.bottomInset = 40
        controller.onRunningHeadChange = { reported.append($0) }
        show(controller, F.book(14...14, counts: [14: 60]), target: ScrollTarget(chapter: 14, verse: 1))
        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        F.scroll(controller, toY: maxY - 1)
        #expect((controller.runningHead?.progress ?? 1) < 1)
        F.scroll(controller, toY: maxY)
        #expect(controller.runningHead == RunningHeadState(chapter: 14, progress: 1, headOpacity: 1))
        #expect(reported.last?.progress == 1)
    }

    // MARK: - One chapter

    /// A landing that can only rest at the page's foot (the chapter's last verse, which cannot
    /// reach the top) needs no hold: the page has one chapter, so the head names it and reads it
    /// through there, before and after a taller window moves the clip, and the position stays in
    /// it. A reflow returns to the first visible verse, as on `main`, still in the chapter.
    @Test func aLandingThatCanOnlyRestAtTheFootKeepsItsChapterThroughAResize() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        controller.headLineY = 40
        controller.bottomInset = 40
        show(controller, F.book(14...14, counts: [14: 60]), target: ScrollTarget(chapter: 14, verse: 60))
        func expectAtTheFoot(_ label: String) {
            let clip = controller.scrollView.contentView.bounds
            #expect(abs(clip.maxY - controller.scrollView.documentView!.frame.height) < 0.5, "\(label)")
            #expect(controller.runningHead == RunningHeadState(chapter: 14, progress: 1, headOpacity: 1), "\(label)")
            #expect(reported.allSatisfy { $0.chapter == 14 } && !reported.isEmpty, "\(label)")
        }
        expectAtTheFoot("landed")
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 700, height: 500)
        controller.scrollView.layoutSubtreeIfNeeded()
        expectAtTheFoot("taller")
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 520, height: 500)
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.flushPendingReflow()
        #expect(controller.runningHead?.chapter == 14 && reported.allSatisfy { $0.chapter == 14 })
    }

    /// A target at verse 1 lands at the page's top. A later chapter has no label and no air
    /// (Matt, 2026-11-13: "the massive gap"): its first line rests right under the head, where
    /// any landed line rests, and the head is shown.
    @Test func aTargetAtVerseOneLandsOnItsChaptersOpening() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        controller.headLineY = 40
        let layout = F.book(4...4)
        show(controller, layout, target: ScrollTarget(chapter: 4, verse: 20))
        show(controller, layout, target: ScrollTarget(chapter: 4, verse: 1))
        let line = controller.lineFrame(forCharacterIndex: layout.section(for: 4)!.openingRange.location)!
        let labelTop = line.minY + controller.textView.textContainerInset.height
        #expect(controller.scrollView.contentView.bounds.minY == 0)
        #expect(abs(labelTop - (controller.headLineY + ChapterTextController.scrollLeadIn)) < 0.5, "right under the head")
        #expect(abs(controller.chapterBand!.openingMinY - labelTop) < 0.5)
        let first = controller.lineFrame(forCharacterIndex: layout.section(for: 4)!.spans[0].fullRange.location)!
        #expect(first.minY - line.minY <= 1.5, "the first verse starts at the opening's hairline")
        #expect(reported.last == at(4, 1))
        #expect(controller.runningHead?.chapter == 4 && controller.runningHead?.headOpacity == 1)
    }

    /// The head's height changing on its own (its text size, a toolbar change) moves a later
    /// chapter's text with it, at once: the inset was set only when the text was replaced
    /// (parked 2026-11-13). The page's height follows, and a page at its top stays there.
    @Test func aLaterChaptersTextFollowsTheHeadsHeight() {
        let controller = makeController { _ in }
        controller.headLineY = 78
        show(controller, F.book(2...2), target: ScrollTarget(chapter: 2, verse: 1))
        #expect(controller.textView.textContainerInset.height == 78 + ChapterTextController.scrollLeadIn)
        controller.headLineY = 96
        #expect(controller.textView.textContainerInset.height == 96 + ChapterTextController.scrollLeadIn)
        let textHeight = controller.textView.textLayoutManager!.usageBoundsForTextContainer.maxY
        #expect(abs(controller.scrollView.documentView!.frame.height
            - ceil(textHeight + controller.textView.textContainerInset.height + ChapterTextController.verticalInset)) < 0.5)
        #expect(controller.scrollView.contentView.bounds.minY == 0)
        // Over chapter 1's title block the head is hidden, and the inset stays the page's.
        show(controller, F.book(1...1), target: ScrollTarget(chapter: 1, verse: 1))
        controller.headLineY = 60
        #expect(controller.textView.textContainerInset.height == ChapterTextController.verticalInset)
    }

    /// Chapter 1's title block keeps its place at the page's top inset, under the hidden head; a
    /// later chapter's text starts under the head it shows: the head's height and a landed
    /// line's lead-in, never less than the page's inset.
    @Test func aLaterChaptersTextStartsUnderTheHead() {
        let controller = makeController { _ in }
        controller.headLineY = 78
        show(controller, F.book(1...1), target: ScrollTarget(chapter: 1, verse: 1))
        #expect(controller.textView.textContainerInset.height == ChapterTextController.verticalInset)
        show(controller, F.book(2...2), target: ScrollTarget(chapter: 2, verse: 1))
        #expect(controller.textView.textContainerInset.height == 78 + ChapterTextController.scrollLeadIn)
        // The foot keeps only the page's own inset under the text.
        let textHeight = controller.textView.textLayoutManager!.usageBoundsForTextContainer.maxY
        #expect(abs(controller.scrollView.documentView!.frame.height
            - ceil(textHeight + controller.textView.textContainerInset.height + ChapterTextController.verticalInset)) < 0.5)
        show(controller, F.book(1...1, translation: "KJV"), target: ScrollTarget(chapter: 1, verse: 1))
        #expect(controller.textView.textContainerInset.height == ChapterTextController.verticalInset)
    }

    /// A target in another chapter waits, reporting nothing, until the document hands over that
    /// chapter's layout.
    @Test func aTargetInAnotherChapterWaitsForItsLayout() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.book(3...3), target: ScrollTarget(chapter: 3, verse: 1))
        reported = []
        let target = ScrollTarget(chapter: 7, verse: 12)
        show(controller, F.book(3...3), target: target)
        #expect(reported.isEmpty)
        show(controller, F.book(7...7), target: target)
        #expect(reported == [at(7, 12)])
    }

    /// A target that arrives while the previous book is still shown (the document rebuilds after
    /// the navigation) lands in the new book once it arrives.
    @Test func aTargetTakenOnThePreviousBookLandsInTheNewOne() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        show(controller, F.book(2...2, book: "MRK"), target: ScrollTarget(chapter: 2, verse: 1))
        let target = ScrollTarget(chapter: 2, verse: 12)
        show(controller, F.book(2...2, book: "MRK"), target: target)
        #expect(reported.last == at(2, 12, book: "MRK"))
        show(controller, F.book(2...2, book: "LUK"), target: target)
        #expect(reported.last == at(2, 12, book: "LUK"))
    }

    /// TextKit 2 drifted on whole-book documents: scrolled upward, lines above the viewport were
    /// laid out again at estimated heights and the page jumped. One chapter is laid out once and
    /// keeps every line. Psalm 119 (176 verses) in a real window, Printed and Lectern: three
    /// passes from the foot to the top in 30-point steps, each drawn, never move the text's end
    /// by more than 2 points; the head names Psalm 119 throughout, and the numeral and a
    /// highlight stay where they were drawn.
    @Test(arguments: [PageStyle.printed, .lectern])
    func oneChapterKeepsEveryLineThroughRepeatedUpwardScrolls(style: PageStyle) throws {
        let verses = try BenchmarkChapter.psalm119()
        let typography = ReaderTypography.styled(ReaderPreferences(style: style))
        let layout = BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 119), verses: verses)],
                                      opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                      typography: typography)
        let decorations = BenchmarkChapter.sixtyHighlights(in: layout.sections[0])
        let controller = ChapterTextController(onReadingPositionChange: { _ in })
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 900, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = controller.scrollView
        controller.scrollView.layoutSubtreeIfNeeded()
        controller.headLineY = RunningHeadView.stripHeight(for: typography)
        controller.bottomInset = ReaderView.footHeight
        controller.update(layout: layout, typography: typography, scrollTarget: ScrollTarget(chapter: 119, verse: 1), decorations: decorations)
        window.displayIfNeeded()
        let layoutManager = try #require(controller.textView.textLayoutManager)
        let end = layoutManager.usageBoundsForTextContainer.maxY
        let fills = controller.backgroundFills
        let numeral = controller.numeralView?.frame
        #expect(fills.count >= 60)
        #expect((numeral != nil) == (style == .lectern))
        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        #expect(maxY > 5000)
        var drift: CGFloat = 0
        var chapters: Set<Int> = []
        for _ in 0..<3 {
            var y = maxY
            while true {
                F.scroll(controller, toY: y)
                window.layoutIfNeeded()
                window.displayIfNeeded()
                CATransaction.flush()
                drift = max(drift, abs(layoutManager.usageBoundsForTextContainer.maxY - end))
                chapters.insert(controller.runningHead?.chapter ?? 0)
                if y <= 0 { break }
                y = max(0, y - 30)
            }
        }
        #expect(drift <= 2, "\(style): the text's end moved \(drift) points")
        #expect(chapters == [119], "\(style)")
        #expect(controller.backgroundFills == fills, "\(style)")
        #expect(controller.numeralView?.frame == numeral, "\(style)")
        #expect(controller.numeralView.map { $0.chapter == 119 } ?? (style != .lectern))
    }

    /// The head's line is the line just under the strip, where a jump lands its line.
    private func scrollHeadLine(_ controller: ChapterTextController, to y: CGFloat) {
        F.scroll(controller, toY: y - controller.headLineY - ChapterTextController.scrollLeadIn)
    }

    /// The title block morphs into the head (spec 4.2): chapter 1 starts with the head hidden and
    /// its label at full alpha, they share the alpha halfway through the fade, and the label is
    /// gone once the head is full. A later chapter has no label to morph (Matt, 2026-11-13): its
    /// head is shown from the top and stays shown.
    @Test func theTitleBlockFadesIntoTheHeadAndALaterChaptersHeadShowsFromTheTop() {
        var states: [RunningHeadState] = []
        let controller = makeController { _ in }
        controller.onRunningHeadChange = { states.append($0) }
        let layout = F.book(1...1)
        show(controller, layout, target: ScrollTarget(chapter: 1, verse: 1))
        #expect(states.last?.headOpacity == 0)
        // The title block's CHAPTER 1 label is drawn at full alpha (no rendering attribute).
        let labelIndex = (0..<layout.sections[0].openingRange.length).map { $0 + layout.sections[0].openingRange.location }
            .first { layout.attributedString.readerRole(at: $0) == .chapterLabel(1) }!
        #expect(F.renderingAttributes(controller, at: labelIndex)[.foregroundColor] == nil)
        // Halfway through the fade the head and the label share the alpha.
        let band = controller.chapterBand!
        scrollHeadLine(controller, to: band.openingMaxY - RunningHead.fadeDistance / 2)
        #expect(abs((states.last?.headOpacity ?? 0) - 0.5) < 0.02)
        let halfway = F.renderingAttributes(controller, at: labelIndex)[.foregroundColor] as? NSColor
        #expect(abs((halfway?.usingColorSpace(.sRGB)?.alphaComponent ?? 0) - 0.5) < 0.02)
        scrollHeadLine(controller, to: band.openingMaxY + 1)
        #expect(states.last?.headOpacity == 1)
        #expect(controller.openingLabelAlpha == 0)
        // Matt, 2026-11-13: a later chapter has no label on the page, so its head names it
        // from the top, fully shown, and stays shown as the page scrolls.
        let two = F.book(2...2)
        show(controller, two, target: ScrollTarget(chapter: 2, verse: 1))
        #expect(states.last?.headOpacity == 1 && states.last?.chapter == 2)
        let opening = two.sections[0].openingRange
        #expect((opening.location..<NSMaxRange(opening)).allSatisfy { two.attributedString.readerRole(at: $0) == .chapterStart(2) },
                "the opening is its empty hairline alone")
        scrollHeadLine(controller, to: controller.chapterBand!.openingMaxY + 200)
        #expect(states.last?.headOpacity == 1 && states.last?.chapter == 2)
    }

    /// Review Focus 1: highlights made before the book scroll, on a chapter's first and last
    /// verses (next to the title block or label, a heading, the text's end), still cover exactly
    /// their words, in each chapter shown alone.
    @Test(arguments: PageStyle.allCases)
    func oldHighlightsOnChapterEdgesStillCoverTheirWords(style: PageStyle) {
        var prefs = ReaderPreferences.default
        prefs.style = style
        let typography = ReaderTypography.styled(prefs)
        let controller = F.makeController(height: 4000)
        let headings: [Int: [Int: [SectionHeading]]] = [2: [1: [SectionHeading(text: "A Heading", level: 1)]], 3: [1: [SectionHeading(text: "Another", level: 1)]]]
        let text = F.verses(count: 6)[0].text as NSString
        let length = text.length
        for chapter in 1...3 {
            let layout = F.book(chapter...chapter, counts: [chapter: 6], headings: headings, typography: typography)
            // The chapter's first verse from its first word; its last verse to its last character.
            let items = [item(chapter, 1, 0, 5, color: yellow), item(chapter, 6, length - 8, length, color: blue)]
            show(controller, layout, typography: typography, target: ScrollTarget(chapter: chapter, verse: 1),
                 decorations: F.decorations(items, layout: layout))
            let string = controller.textView.string as NSString
            for item in items {
                let span = layout.span(for: VerseLocation(book: "MAT", chapter: item.chapter, verse: item.verse))!
                let range = NSRange(location: span.textRange.location + item.startOffset, length: item.endOffset - item.startOffset)
                #expect(string.substring(with: range) == text.substring(with: NSRange(location: item.startOffset, length: item.endOffset - item.startOffset)))
                let fills = controller.backgroundFills.filter { $0.id == item.id }.map(\.rect)
                let words = controller.frameOfFirstSegment(of: range)!
                #expect(fills.count == 1, "\(style) \(item.chapter):\(item.verse)")
                #expect(abs((fills.first?.minX ?? -1) - words.minX) < 0.5 && abs((fills.first?.maxX ?? -1) - words.maxX) < 0.5)
                // The text system's own rect for the same words, so the fill is on them and not on a label.
                let storage = controller.textView.textContentStorage!
                let start = storage.location(storage.documentRange.location, offsetBy: range.location)!
                var system: NSRect?
                controller.textView.textLayoutManager!.enumerateTextSegments(in: NSTextRange(location: start, end: storage.location(start, offsetBy: range.length)!)!,
                                                                            type: .standard, options: []) { _, frame, _, _ in
                    system = frame.offsetBy(dx: controller.textView.textContainerInset.width, dy: controller.textView.textContainerInset.height)
                    return false
                }
                #expect(abs((fills.first?.minX ?? -1) - (system?.minX ?? -2)) < 0.5)
                #expect(system.map { $0.intersects(fills.first!) } == true)
            }
        }
    }

    /// In Study a verse number inside a highlight draws in the style's on-mark ink (a rendering
    /// attribute); outside one it keeps its own.
    @Test func aVerseNumberOnAMarkTakesTheOnMarkInk() throws {
        var prefs = ReaderPreferences.default
        prefs.style = .study
        let typography = ReaderTypography.styled(prefs)
        let onMark = try #require(typography.verseNumberColorOnMark)
        let controller = makeController { _ in }
        let layout = F.layout(verses(count: 6), typography: typography)
        let across = item(2, 5, 10, endVerse: 4, color: yellow)    // covers verses 3 and 4's numbers, not 2's
        show(controller, layout, typography: typography, decorations: F.decorations([across], layout: layout))
        let number = { (verse: Int) in F.renderingAttributes(controller, at: layout.span(for: self.at(verse))!.numberRange.location)[.foregroundColor] as? NSColor }
        #expect(number(3) == onMark && number(4) == onMark)
        #expect(number(2) == nil && number(5) == nil)
        // Removing the highlight gives the numbers their own ink back.
        show(controller, layout, typography: typography, decorations: .none)
        #expect(number(3) == nil)
    }

    // MARK: - Fix round 1

    /// Copy, drag and Services write only the verse text the selection resolves to: a selection
    /// from inside the chapter's opening (chapter 1's label, a later chapter's empty hairline)
    /// across a heading puts no label, hairline joiner, heading or verse number on the pasteboard.
    @Test(arguments: [1, 4])
    func copyingASelectionAcrossAnOpeningWritesOnlyVerseText(chapter: Int) throws {
        let controller = makeController { _ in }
        let headings: [Int: [Int: [SectionHeading]]] = [chapter: [3: [SectionHeading(text: "A Heading", level: 1)]]]
        let layout = F.book(chapter...chapter, counts: [chapter: 4], headings: headings)
        show(controller, layout)
        let from = NSMaxRange(layout.section(for: chapter)!.openingRange) - 2
        let to = layout.span(for: at(chapter, 4))!.textRange.location + 5
        controller.textView.setSelectedRange(NSRange(location: from, length: to - from))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ChapterTextControllerTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        #expect(controller.textView.writeSelection(to: pasteboard, types: [.string, .rtf]))
        let copied = try #require(pasteboard.string(forType: .string))
        #expect(copied == controller.selectionReport()?.selection.quotedText)
        #expect(copied.hasPrefix("Verse 1 of WEB") && copied.hasSuffix("Verse") && copied.contains("Verse 3 of WEB"))
        #expect(!copied.contains("CHAPTER") && !copied.contains("A Heading") && pasteboard.data(forType: .rtf) == nil)
        #expect(!copied.contains("\u{2060}"))
        // Only plain text is ever written.
        #expect(!controller.textView.writeSelection(to: pasteboard, types: [.rtf]))
        // The opening alone copies nothing.
        controller.textView.setSelectedRange(layout.section(for: chapter)!.openingRange)
        #expect(!controller.textView.writeSelection(to: pasteboard, types: [.string]))
    }

    /// Decorations mapped onto another layout (the markup model's layout lags the document's by a
    /// pass) are not applied to the new one; its own, when they come, are.
    @Test func decorationsForAnotherLayoutAreNotApplied() {
        let controller = makeController { _ in }
        let small = F.book(3...3)
        let mark = item(3, 2, 0, 10, color: yellow)
        let anchor = item(3, 3, 0, 10, color: nil, note: true)
        show(controller, small, target: ScrollTarget(chapter: 3, verse: 1), decorations: F.decorations([mark, anchor], layout: small))
        #expect(controller.backgroundFills.contains { $0.id == mark.id })
        // The same chapter with a heading arrived (a retried headings fetch): every offset moves.
        let grown = F.book(3...3, headings: [3: [1: [SectionHeading(text: "A Heading", level: 1)]]])
        #expect(grown.id != small.id && grown.span(for: at(3, 2))!.textRange.location != small.span(for: at(3, 2))!.textRange.location)
        let storage = controller.textView.textStorage!
        show(controller, grown, target: ScrollTarget(chapter: 3, verse: 1), decorations: F.decorations([mark, anchor], layout: small))
        #expect(controller.backgroundFills.isEmpty)
        var underlined = false
        storage.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if value != nil { underlined = true }
        }
        #expect(!underlined)
        show(controller, grown, target: ScrollTarget(chapter: 3, verse: 1), decorations: F.decorations([mark, anchor], layout: grown))
        let words = NSRange(location: grown.span(for: at(3, 2))!.textRange.location, length: 10)
        #expect(controller.backgroundFills.first { $0.id == mark.id }?.rect.minX == controller.frameOfFirstSegment(of: words)?.minX)
        #expect(storage.attribute(.underlineStyle, at: grown.span(for: at(3, 3))!.textRange.location + 2, effectiveRange: nil) != nil)
    }

    /// A window wider than the column only re-centres it: no layout, the marks move with it.
    @Test func wideningPastTheMeasureOnlyRecentres() {
        let controller = F.makeController(width: 1200)
        let layout = F.layout(verses(count: 40))
        let a = item(30, 0, 10, color: yellow)
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 28), decorations: F.decorations([a], bookmarks: [at(30)], layout: layout))
        let count = controller.reflowCount
        let fill = controller.backgroundFills.first { $0.id == a.id }!.rect
        let glyph = controller.gutterView.glyphRects[0]
        let origin = controller.scrollView.contentView.bounds.minY
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 1300, height: 300)
        controller.scrollView.layoutSubtreeIfNeeded()
        #expect(controller.reflowCount == count)
        #expect(controller.textView.textContainer?.size.width == 640)
        #expect(abs(controller.backgroundFills.first { $0.id == a.id }!.rect.minX - (fill.minX + 50)) < 0.5)
        #expect(abs(controller.gutterView.glyphRects[0].minX - (glyph.minX + 50)) < 0.5)
        #expect(controller.scrollView.contentView.bounds.minY == origin)
    }

    private func resize(_ controller: ChapterTextController, to width: CGFloat) {
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: width, height: 300)
        controller.scrollView.layoutSubtreeIfNeeded()
    }

    /// Width changes (an animated resize) keep the column until they settle, then reflow once,
    /// at the last width, back on the verse being read.
    @Test func widthChangesReflowOnceAfterTheySettle() {
        var reported: [VerseLocation] = []
        let controller = makeController { reported.append($0) }
        let layout = F.layout(verses(count: 60))
        show(controller, layout, target: ScrollTarget(chapter: 5, verse: 30))
        let count = controller.reflowCount
        let column = controller.textView.textContainer?.size.width
        for width in [690, 680, 670, 660] as [CGFloat] { resize(controller, to: width) }
        #expect(controller.reflowCount == count)
        #expect(controller.textView.textContainer?.size.width == column)
        controller.flushPendingReflow()
        #expect(controller.reflowCount == count + 1)
        #expect(controller.textView.textContainer?.size.width == controller.scrollView.contentView.bounds.width - 2 * ChapterTextController.horizontalInset)
        #expect(reported.allSatisfy { $0 == at(30) } && !reported.isEmpty)
        let verse = controller.frameOfFirstSegment(of: NSRange(location: layout.span(for: at(30))!.textRange.location, length: 3))!
        #expect(verse.minY - controller.scrollView.contentView.bounds.minY < 3 * ReaderTypography.default.bodyLineHeight)
    }

    /// The first frame of an animated narrowing lays nothing out: the column keeps its width,
    /// re-centred in the narrower view.
    @Test func theFirstFrameOfAnAnimatedNarrowingDoesNotReflow() {
        let controller = makeController { _ in }
        show(controller, F.layout(verses(count: 60)), target: ScrollTarget(chapter: 5, verse: 30))
        let count = controller.reflowCount
        let column = controller.textView.textContainer?.size.width
        resize(controller, to: 680)
        #expect(controller.reflowCount == count)
        #expect(controller.textView.textContainer?.size.width == column)
        #expect(controller.textView.textContainerInset.width == (controller.scrollView.contentView.bounds.width - (column ?? 0)) / 2)
    }

    /// The end of a live resize reflows the column at the final width.
    @Test func theEndOfALiveResizeReflows() {
        let controller = makeController { _ in }
        show(controller, F.layout(verses(count: 60)), target: ScrollTarget(chapter: 5, verse: 30))
        let count = controller.reflowCount
        resize(controller, to: 650)
        controller.textView.viewDidEndLiveResize()
        #expect(controller.reflowCount == count + 1)
        // The clip's width, less a legacy scroller when the system shows one.
        let clip = controller.scrollView.contentView.bounds.width
        #expect(controller.textView.textContainer?.size.width == clip - 2 * ChapterTextController.horizontalInset)
        controller.textView.viewDidEndLiveResize()                                     // nothing waiting
        #expect(controller.reflowCount == count + 1)
    }

    /// Settling also happens on its own, a moment after the last change.
    @Test func aResizeReflowsByItselfOnceItSettles() async throws {
        let controller = makeController { _ in }
        show(controller, F.layout(verses(count: 60)), target: ScrollTarget(chapter: 5, verse: 30))
        let count = controller.reflowCount
        resize(controller, to: 650)
        #expect(controller.reflowCount == count)
        for _ in 0..<100 where controller.reflowCount == count {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(controller.reflowCount == count + 1)
        #expect(controller.textView.textContainer?.size.width == controller.scrollView.contentView.bounds.width - 2 * ChapterTextController.horizontalInset)
    }

    /// A size change arrives as a typography a pass before its layout: the column waits for the
    /// layout instead of laying the old text out at the new measure first.
    @Test func aNewSizeWaitsForItsLayout() {
        let controller = F.makeController(width: 1200)
        let chapter = verses(count: 10)
        show(controller, F.layout(chapter))
        let count = controller.reflowCount
        let large = typo(24, .normal)
        show(controller, F.layout(chapter), typography: large)
        #expect(controller.textView.textContainer?.size.width == 640)
        #expect(controller.reflowCount == count)
        show(controller, F.layout(chapter, typography: large), typography: large)
        #expect(controller.textView.textContainer?.size.width == large.measure)
    }

    /// Review Focus 3, on the real bundle (`.needsRealBible`): John in ESV at
    /// 10:20 and at 10:15, switched to the ERV, which combines 10:14-15. The reader stays on the
    /// same chapter and verse, and the head names chapter 10.
    @Test(.needsRealBible) func switchingToERVKeepsChapterAndVerse() throws {
        let store = try BenchmarkChapter.realStore()
        let ids = try store.translations().map(\.id)
        try #require(ids.contains("ESV") && ids.contains("ERV"), "the bundle has ESV and ERV")
        let document = ReaderDocument(store: store)
        func book(_ translation: String) throws -> BookText {
            BookText(book: "JHN", translationID: translation, chapters: try store.bookChapters("JHN", translationID: translation))
        }
        let typography = ReaderTypography.default
        for verse in [20, 15] {
            var reported: [VerseLocation] = []
            let controller = F.makeController(height: 600) { reported.append($0) }
            document.show(try book("ESV"), target: ChapterLocation(book: "JHN", chapter: 10), typography: typography)
            controller.update(layout: document.layout, typography: typography, scrollTarget: ScrollTarget(chapter: 10, verse: verse), decorations: .none)
            #expect(reported.last == at(10, verse, book: "JHN"))
            // Navigation switches the translation and re-targets the verse being read.
            document.show(try book("ERV"), target: ChapterLocation(book: "JHN", chapter: 10), typography: typography)
            #expect(document.layout?.id.translationID == "ERV")
            controller.update(layout: document.layout, typography: typography, scrollTarget: ScrollTarget(chapter: 10, verse: verse), decorations: .none)
            #expect(reported.last == at(10, verse, book: "JHN"), "verse \(verse): \(reported)")
            #expect(controller.runningHead?.chapter == 10)
            // And the layout arriving before the target (no new target) keeps it too.
            document.show(try book("ESV"), target: ChapterLocation(book: "JHN", chapter: 10), typography: typography)
            controller.update(layout: document.layout, typography: typography, scrollTarget: nil, decorations: .none)
            #expect(reported.last == at(10, verse, book: "JHN"), "verse \(verse): \(reported)")
        }
    }
}
#endif
