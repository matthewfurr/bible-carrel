#if os(iOS)
import ScriptureData
import Testing
import UIKit
@testable import ScriptureUI

/// The phone reader's selection is filled behind its words only: on each line from the first
/// selected glyph to the last, the line's full height (the system's own line rects, trimmed);
/// never in the blank space after a line's last word, in an indent or across the margins. The
/// handles, the loupe and the menu stay the system's.
@MainActor @Suite struct PhoneSelectionFillTests {
    private typealias F = PhoneControllerFixture

    /// Verse 2 is poetry: four short lines, each its own hanging paragraph.
    private static let poem = "Blessed is the man\nwho walks not in the counsel of the wicked,\nnor stands in the way of sinners,\nnor sits in the seat of scoffers;"

    /// Chapter 5 with its poem; without one, the fixture's prose throughout.
    private static func layout(chapter: Int = 5, poetry: Bool = true, count: Int = 6, typography: ReaderTypography = .default) -> BookLayout {
        let verses = F.verses(chapter: chapter, count: count).map { verse in
            poetry && verse.id.verse == 2 ? Verse(id: verse.id, translationID: verse.translationID, text: poem, breakAfter: false) : verse
        }
        return BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "MAT", chapter: chapter), verses: verses)],
                                opening: F.opening, typography: typography)
    }

    /// What the controller last told the screen about the selection (nil: none), and how often.
    @MainActor final class Reports {
        var all: [SelectionReport?] = []
        /// How often the controller said the selection went away with its text.
        var dropped = 0
    }

    private let layout = Self.layout()
    /// The iPhone 18 Pro Max's width, where each of the poem's lines fits on one line.
    private let page = F.Harness(width: 440, height: 900) { _ in }

    private let reports = Reports()

    init() {
        let reports = reports
        page.controller.onSelectionChange = { reports.all.append($0) }
        page.controller.onSelectionDropped = { reports.dropped += 1 }
        page.show(layout)
        page.textView.becomeFirstResponder()
    }

    private func span(_ verse: Int, in layout: BookLayout? = nil) throws -> VerseSpan {
        try #require((layout ?? self.layout).span(for: VerseLocation(book: "MAT", chapter: 5, verse: verse)))
    }

    private var display: UITextSelectionDisplayInteraction? {
        page.textView.interactions.lazy.compactMap { $0 as? UITextSelectionDisplayInteraction }.first
    }

    /// Selects `range` and lets the system's selection display catch up, as it does on the next
    /// pass of the run loop.
    private func select(_ range: NSRange) {
        page.textView.selectedRange = range
        settle()
    }

    /// Lets the main queue turn, so the controller's deferred reports arrive (a synchronous
    /// test's body holds the main queue, where spinning the run loop does not run them).
    private func nextTurn() async {
        for _ in 0..<3 {
            await Task.yield()
            Self.runMainLoopBriefly()
        }
        settle()
    }

    private static func runMainLoopBriefly() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
    }

    private func settle() {
        display?.setNeedsSelectionUpdate()
        display?.layoutManagedSubviews()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    /// The column's right edge, in text-view coordinates.
    private var columnRight: CGFloat {
        page.textView.textContainerInset.left + page.textView.textContainer.size.width
    }

    @Test func theReadersOwnViewDrawsTheSelectionsFill() throws {
        let display = try #require(display)
        #expect(display.highlightView === page.controller.selectionHighlightView)
        select(try span(2).textRange)
        // The system gives it the selection's colour, as it gave its own view.
        #expect(page.controller.selectionHighlightView.tintColor.cgColor.alpha < 1)
    }

    @Test func aSelectedPoemIsFilledBehindEachLinesWordsOnly() throws {
        let poem = try span(2)
        select(poem.textRange)
        let fills = page.controller.selectionFills
        let words = page.controller.segmentFrames(of: [poem.textRange])[0]
        try #require(words.count == 4, "four lines")
        try #require(fills.count == 4, "\(fills)")
        let left = page.textView.textContainerInset.left
        for (fill, line) in zip(fills, words) {
            // From the first selected glyph on its line to the last, as the highlights are.
            #expect(fill.minX >= line.minX - 1 && fill.maxX <= line.maxX + 1, "\(fill) \(line)")
            #expect(abs(fill.minX - line.minX) <= 1 && abs(fill.maxX - line.maxX) <= 1, "\(fill) \(line)")
            // Never the indent before a line's first word, nor past the column.
            #expect(fill.minX > left + 1)
            #expect(fill.maxX <= columnRight)
            // The line's full height (a descender may overhang the line by a fraction).
            #expect(fill.minY <= line.minY && fill.maxY >= line.maxY - 0.5, "\(fill) \(line)")
        }
        // The short lines stop well short of the column's edge: no blank space after their last word.
        #expect(fills[0].maxX < columnRight - 100 && fills[2].maxX < columnRight - 20, "\(fills) \(columnRight)")
        // Joined line to line, as the system's fill is: no gap and no overlap.
        for (upper, lower) in zip(fills, fills.dropFirst()) {
            #expect(abs(upper.maxY - lower.minY) < 0.5, "\(upper) \(lower)")
        }
        // What the view paints is that fill, in its own coordinates.
        let view = page.controller.selectionHighlightView
        #expect(view.paintedRects.map { view.convert($0, to: page.textView) }.elementsEqual(fills) { $0.equalTo($1) })
    }

    /// A long prose verse wraps: no line's fill reaches the column's right edge beyond its last
    /// glyph, and none of them reaches past it at all.
    @Test func aWrappedVerseStopsAtEachLinesLastGlyph() throws {
        let verse = try span(4)
        select(verse.textRange)
        let fills = page.controller.selectionFills
        let words = page.controller.segmentFrames(of: [verse.textRange])[0]
        try #require(words.count >= 2 && fills.count == words.count, "\(fills) \(words)")
        for (fill, line) in zip(fills, words) {
            #expect(fill.maxX <= line.maxX + 1 && fill.minX >= line.minX - 1, "\(fill) \(line)")
            #expect(fill.maxX <= columnRight)
        }
    }

    @Test func aSelectionInsideOneLineIsOneRectOverItsSegment() throws {
        select(NSRange(location: try span(3).textRange.location + 6, length: 7))
        // As the reader snapped it to whole words.
        let range = page.textView.selectedRange
        let fills = page.controller.selectionFills
        let segment = try #require(page.controller.segmentFrames(of: [range])[0].first)
        try #require(fills.count == 1, "\(fills)")
        #expect(abs(fills[0].minX - segment.minX) < 0.5 && abs(fills[0].width - segment.width) < 0.5, "\(fills[0]) \(segment)")
        #expect(fills[0].minY <= segment.minY && fills[0].maxY >= segment.maxY - 0.5, "\(fills[0]) \(segment)")
    }

    @Test func noSelectionFillsNothing() throws {
        settle()
        #expect(page.controller.selectionFills.isEmpty)
        select(try span(2).textRange)
        #expect(!page.controller.selectionFills.isEmpty)
        page.controller.collapseSelection()
        settle()
        #expect(page.controller.selectionFills.isEmpty)
        // The system hides its highlight view on collapse; the fill follows that as well as the range.
        let view = page.controller.selectionHighlightView
        #expect(view.isHidden)
    }

    /// Hidden by the system is no fill, whatever the range still says: the view's own guard, not
    /// only the range's.
    @Test func aHiddenHighlightViewFillsNothing() throws {
        select(try span(2).textRange)
        let view = page.controller.selectionHighlightView
        #expect(!page.controller.selectionFills.isEmpty && !view.paintedRects.isEmpty)
        view.isHidden = true
        #expect(page.textView.selectedRange.length > 0)
        #expect(page.controller.selectionFills.isEmpty && view.paintedRects.isEmpty)
        view.isHidden = false
        #expect(!page.controller.selectionFills.isEmpty)
    }

    /// The handles are the system's, where it puts them: the start handle's stem at the first
    /// selected glyph, the end handle's at the last.
    @Test func theHandlesStayAtTheSelectionsEnds() throws {
        let poem = try span(2)
        select(poem.textRange)
        let words = page.controller.segmentFrames(of: [poem.textRange])[0]
        let first = try #require(words.first)
        let last = try #require(words.last)
        let handles = try #require(display?.handleViews)
        try #require(handles.count == 2)
        let start = handles[0].convert(handles[0].bounds, to: page.textView)
        let end = handles[1].convert(handles[1].bounds, to: page.textView)
        #expect(!handles[0].isHidden && !handles[1].isHidden)
        #expect(abs(start.minX - first.minX) <= 1.5, "\(start) \(first)")
        #expect(abs(end.minX + 1 - last.maxX) <= 1.5, "\(end) \(last)")
        // And on their lines.
        #expect(start.minY <= first.minY && start.maxY >= first.maxY)
        #expect(end.minY <= last.minY && end.maxY >= last.maxY)
    }

    /// Another chapter's text: the selection does not carry into it. Nothing is selected there,
    /// nothing is filled, and the screen is told the selection went away, on the next turn of the
    /// main queue (the replacement runs inside a SwiftUI update, where the model must not change).
    /// The new chapter longer than the old selection's offsets, and shorter than its start (where
    /// UIKit clamps the range to nothing as the text is swapped).
    @Test(arguments: [6, 1])
    func anotherChapterLeavesNoOldFill(verses: Int) async throws {
        let old = try span(5).textRange
        select(old)
        #expect(!page.controller.selectionFills.isEmpty)
        reports.all.removeAll()
        let next = Self.layout(chapter: 6, poetry: false, count: verses)
        if verses == 1 { try #require(next.attributedString.length < old.location, "\(next.attributedString.length)") }
        page.show(next)
        // Not yet: the screen hears of it only once this update is over.
        #expect(reports.dropped == 0 && reports.all.isEmpty)
        await nextTurn()
        #expect(page.textView.selectedRange.length == 0, "\(page.textView.selectedRange)")
        #expect(page.controller.selectionFills.isEmpty)
        #expect(page.controller.selectionHighlightView.paintedRects.isEmpty)
        #expect(reports.dropped == 1 && reports.all.isEmpty, "\(reports.dropped) \(reports.all)")
    }

    /// A selection made in the new chapter before the deferred word arrives is what is reported
    /// then, never a stale "gone".
    @Test func aSelectionMadeBeforeTheDeferredReportIsWhatItReports() async throws {
        select(try span(2).textRange)
        reports.all.removeAll()
        let next = Self.layout(chapter: 6, poetry: false)
        page.show(next)
        let range = try #require(next.span(for: VerseLocation(book: "MAT", chapter: 6, verse: 3))).textRange
        page.textView.selectedRange = range
        await nextTurn()
        #expect(reports.dropped == 0)
        #expect(reports.all.last??.range == range, "\(reports.all)")
    }

    /// A page-style change is the same chapter, but not always the same string: Lectern sets the
    /// opening and the first verse's number otherwise, which moves every verse's offsets. The
    /// selection stays on the same words in every style, and where its range moved the screen is
    /// told the new one (on the next turn of the main queue), never that it went away.
    @Test func aPageStyleChangeKeepsTheSelection() async throws {
        let printed = Self.layout().attributedString.string
        let lectern = ReaderTypography.styled(ReaderPreferences(style: .lectern))
        // The premise: Lectern's string differs, so this is not the same-text path.
        #expect(Self.layout(typography: lectern).attributedString.string != printed)
        select(try span(3).textRange)
        var shown = page.textView.attributedText.string
        for style in PageStyle.allCases + [.printed] {
            reports.all.removeAll()
            let typography = ReaderTypography.styled(ReaderPreferences(style: style))
            let styled = Self.layout(typography: typography)
            let moved = styled.attributedString.string != shown
            shown = styled.attributedString.string
            page.show(styled, typography: typography)
            await nextTurn()
            let verse3 = try #require(styled.span(for: VerseLocation(book: "MAT", chapter: 5, verse: 3))).textRange
            #expect(page.textView.selectedRange == verse3, "\(style) \(page.textView.selectedRange) \(verse3)")
            #expect(!page.controller.selectionFills.isEmpty, "\(style)")
            #expect(reports.dropped == 0, "\(style)")
            if moved {
                #expect(reports.all.count == 1 && reports.all.last??.range == verse3 && reports.all.last??.selection.verse == 3,
                        "\(style) \(reports.all)")
            } else {
                #expect(reports.all.isEmpty, "\(style) \(reports.all)")
            }
        }
    }

    /// The same chapter shown again in another typography (a text-size change) keeps the selection
    /// it had, on the same words, and its fill; the screen is told nothing new.
    @Test func theSameChapterReflowedKeepsItsSelection() async throws {
        let range = try span(3).textRange
        select(range)
        reports.all.removeAll()
        var prefs = ReaderPreferences.default
        prefs.fontSize += 4
        let larger = ReaderTypography.styled(prefs)
        page.show(Self.layout(typography: larger), typography: larger)
        await nextTurn()
        #expect(page.textView.selectedRange == range)
        #expect(!page.controller.selectionFills.isEmpty)
        #expect(reports.all.isEmpty && reports.dropped == 0, "\(reports.all)")
    }

    /// A handle drag on a whole chapter's selection: the system gives rects for the lines in or
    /// near view only, and the fill walks only the layout fragments under them, so a change costs
    /// what one screen does. Psalm 119 (176 verses) all selected, on the iPhone 18 Pro Max's page;
    /// the median refill of nine is printed in ms.
    @Test func aWholeChaptersSelectionIsFilledOnlyWhereItShows() throws {
        let verses = try BenchmarkChapter.psalm119()
        let layout = BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 119), verses: verses)],
                                      opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                      typography: .default)
        let page = F.Harness(width: 440, height: 956) { _ in }
        page.show(layout, target: ScrollTarget(chapter: 119, verse: 1))
        page.textView.becomeFirstResponder()
        let spans = layout.sections[0].spans
        let first = try #require(spans.first).textRange.location
        page.textView.selectedRange = NSRange(location: first, length: NSMaxRange(try #require(spans.last).textRange) - first)
        let display = try #require(page.textView.interactions.lazy.compactMap { $0 as? UITextSelectionDisplayInteraction }.first)
        display.setNeedsSelectionUpdate()
        display.layoutManagedSubviews()
        let view = page.controller.selectionHighlightView
        let shown = view.selectionRects
        let fills = page.controller.selectionFills
        #expect(!fills.isEmpty && fills.count <= shown.count && fills.count < 100, "\(fills.count) of \(shown.count)")
        let clock = ContinuousClock()
        var times: [Duration] = []
        for _ in 0..<9 {
            times.append(clock.measure { view.selectionRects = shown })
        }
        let median = times.sorted()[4]
        print("benchmark phone-selection-fill psalm-119-all \(Double(median.components.attoseconds) / 1e15) ms")
        #expect(median < .milliseconds(4))
    }

    /// The trim itself: each system line rect keeps its height and takes its words' extent; a
    /// line with no words (a stanza's blank line) is not filled.
    @Test func trimmingKeepsEachLinesHeightAndTakesItsWordsExtent() {
        let lines = [CGRect(x: 100, y: 0, width: 276, height: 36), CGRect(x: 24, y: 36, width: 352, height: 34),
                     CGRect(x: 24, y: 70, width: 352, height: 20)]
        let words = [CGRect(x: 100, y: 8, width: 120, height: 22), CGRect(x: 40, y: 42, width: 90, height: 22)]
        let trimmed = PhoneChapterTextController.trim(lines, to: words)
        #expect(trimmed == [CGRect(x: 100, y: 0, width: 120, height: 36), CGRect(x: 40, y: 36, width: 90, height: 34)])
    }
}
#endif
