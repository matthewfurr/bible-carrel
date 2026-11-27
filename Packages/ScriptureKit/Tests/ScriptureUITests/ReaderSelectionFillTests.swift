#if os(macOS)
import AppKit
import ScriptureData
import Testing
@testable import ScriptureUI

/// The Mac reader draws a selection's fill itself, behind the words only: on each line from the
/// first selected glyph to the last, the line's full height, joined to the next line's; never in
/// the blank space after a line's last word, in an indent or across the margins.
@MainActor @Suite struct ReaderSelectionFillTests {
    private typealias F = ControllerFixture

    /// Verse 2 is poetry: four short lines, each its own hanging paragraph.
    private static let poem = "Blessed is the man\nwho walks not in the counsel of the wicked,\nnor stands in the way of sinners,\nnor sits in the seat of scoffers;"

    private static func verses(count: Int = 6) -> [Verse] {
        F.verses(count: count).map { verse in
            verse.id.verse == 2 ? Verse(id: verse.id, translationID: verse.translationID, text: poem, breakAfter: false) : verse
        }
    }

    private let layout: BookLayout
    private let controller: ChapterTextController

    init() {
        layout = F.layout(Self.verses())
        controller = F.makeController(width: 900, height: 700)
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: .none)
    }

    private func span(_ verse: Int, in layout: BookLayout? = nil) throws -> VerseSpan {
        try #require((layout ?? self.layout).span(for: VerseLocation(book: "MAT", chapter: 5, verse: verse)))
    }

    /// The column's right edge, in text-view coordinates.
    private var columnRight: CGFloat {
        controller.textView.textContainerInset.width + (controller.textView.textContainer?.size.width ?? 0)
    }

    @Test func aSelectedPoemIsFilledBehindEachLinesWordsOnly() throws {
        let poem = try span(2)
        controller.selectVerses(poem.textRange, anchor: poem.textRange.location)
        let fills = controller.selectionFills
        let words = controller.segmentFrames(of: poem.textRange)
        try #require(words.count == 4, "four lines")
        try #require(fills.count == 4)
        let left = controller.textView.textContainerInset.width
        for (fill, line) in zip(fills, words) {
            // From the first selected glyph on its line to the last, as the highlights are.
            #expect(abs(fill.minX - line.minX) <= 1 && abs(fill.maxX - line.maxX) <= 1, "\(fill) \(line)")
            // Never the blank space after a short line's last word, nor the indent before its first.
            #expect(fill.maxX < columnRight - 20)
            #expect(fill.minX > left + 1)
            // The line's full height.
            #expect(fill.minY <= line.minY && fill.maxY >= line.maxY)
        }
        // Joined line to line, as the system's fill is: no gap and no overlap.
        for (upper, lower) in zip(fills, fills.dropFirst()) {
            #expect(abs(upper.maxY - lower.minY) < 0.5, "\(upper) \(lower)")
        }
        #expect(controller.fillsView.selectionRects == fills)
    }

    @Test func aSelectionInsideOneLineIsOneRectOverItsSegment() throws {
        let start = try span(3).textRange.location + 6
        let range = NSRange(location: start, length: 7)
        controller.textView.setSelectedRange(range)
        let fills = controller.selectionFills
        let segment = try #require(controller.segmentFrames(of: range).first)
        try #require(fills.count == 1)
        #expect(abs(fills[0].minX - segment.minX) < 0.01 && abs(fills[0].width - segment.width) < 0.01)
        #expect(fills[0].minY <= segment.minY && fills[0].maxY >= segment.maxY)
    }

    @Test func aCaretOrNothingFillsNothing() throws {
        #expect(controller.selectionFills.isEmpty)
        controller.textView.setSelectedRange(NSRange(location: try span(3).textRange.location + 4, length: 0))
        #expect(controller.selectionFills.isEmpty && controller.fillsView.selectionRects.isEmpty)
        let poem = try span(2)
        controller.selectVerses(poem.textRange, anchor: poem.textRange.location)
        controller.collapseSelection()
        #expect(controller.selectionFills.isEmpty && controller.fillsView.selectionRects.isEmpty)
    }

    /// The system's own fill is gone in both its colours, while the text keeps its own colours.
    @Test func theSystemsOwnFillNeverShows() throws {
        let attributes = controller.textView.selectedTextAttributes
        #expect(attributes[.backgroundColor] as? NSColor == NSColor.clear)
        #expect(attributes[.foregroundColor] == nil)

        _ = NSApplication.shared
        let size = NSSize(width: 900, height: 700)
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -4000, y: 0), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        window.contentView = content
        let shown = ChapterTextController(onReadingPositionChange: { _ in })
        shown.scrollView.frame = content.bounds
        content.addSubview(shown.scrollView)
        shown.update(layout: layout, typography: .default, scrollTarget: nil, decorations: .none)
        let poem = try span(2)
        shown.selectVerses(poem.textRange, anchor: poem.textRange.location)
        // A first responder that comes and goes (the system re-shows its fill then) changes nothing.
        window.makeFirstResponder(shown.textView)
        window.displayIfNeeded()
        window.makeFirstResponder(nil)
        window.displayIfNeeded()
        window.makeFirstResponder(shown.textView)
        let fills = shown.selectionFills
        try #require(fills.count == 4)
        let pixels = Self.render(content)
        let selection = Self.hex(HighlightFillView.selectionColor(emphasized: false), in: .aqua)
        let emphasized = Self.hex(HighlightFillView.selectionColor(emphasized: true), in: .aqua)
        func count(in rect: NSRect, of colors: Set<String>) -> Int {
            let window = shown.textView.convert(rect, to: content)
            return pixels.count(in: window, of: colors)
        }
        for fill in fills {
            // Mostly the selection's colour behind the words (the glyphs cover the rest).
            #expect(count(in: fill.insetBy(dx: 1, dy: 1), of: [selection]) > Int(fill.width * fill.height) / 3)
            // None of either selection colour from the last word to the column's edge.
            let beyond = NSRect(x: fill.maxX + 2, y: fill.minY + 1, width: columnRight - fill.maxX + 30, height: fill.height - 2)
            #expect(count(in: beyond, of: [selection, emphasized]) == 0, "\(beyond)")
            // Nor in the margin left of the line.
            let before = NSRect(x: 0, y: fill.minY + 1, width: fill.minX - 2, height: fill.height - 2)
            #expect(count(in: before, of: [selection, emphasized]) == 0, "\(before)")
        }
        withExtendedLifetime(window) {}
    }

    @Test func theFillTakesTheSystemsColours() {
        #expect(HighlightFillView.selectionColor(emphasized: true) == NSColor.selectedTextBackgroundColor)
        #expect(HighlightFillView.selectionColor(emphasized: false) == NSColor.unemphasizedSelectedTextBackgroundColor)
        // Headless, the window is not key: the quieter colour.
        #expect(controller.fillsView.selectionIsEmphasized == false)
    }

    @Test func aSelectionOverAHighlightLeavesItsFillAlone() throws {
        let item = MarkupItem(id: UUID(), chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 12, translationID: "WEB",
                              color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: false)
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: F.decorations([item], layout: layout))
        let backgrounds = controller.backgroundFills
        let painted = controller.fillsView.fills
        try #require(!backgrounds.isEmpty)
        let verse = try span(3)
        controller.selectVerses(verse.textRange, anchor: verse.textRange.location)
        #expect(!controller.selectionFills.isEmpty)
        #expect(controller.backgroundFills == backgrounds && controller.fillsView.fills == painted)
        controller.collapseSelection()
        #expect(controller.fillsView.fills == painted)
    }

    @Test func newTextTakesTheOldFillAway() throws {
        let poem = try span(2)
        controller.selectVerses(poem.textRange, anchor: poem.textRange.location)
        let old = controller.selectionFills
        try #require(!old.isEmpty)
        let other = F.layout(F.verses(chapter: 6, count: 8))
        controller.update(layout: other, typography: .default, scrollTarget: nil, decorations: .none)
        // The new text leaves a caret, and nothing of the old fill.
        #expect(controller.textView.selectedRange().length == 0)
        #expect(controller.selectionFills.isEmpty && controller.fillsView.selectionRects.isEmpty)
        controller.textView.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(controller.selectionFills.isEmpty)
    }

    /// Select All in a long chapter fills only the lines in or near view, and a scroll refills.
    @Test func onlyTheLinesInViewAreFilled() throws {
        // Another chapter, so the text is replaced (a layout's id names its chapters, not its words).
        let long = F.layout(F.verses(chapter: 7, count: 80))
        controller.update(layout: long, typography: .default, scrollTarget: nil, decorations: .none)
        controller.textView.selectAll(nil)
        let visible = controller.scrollView.documentVisibleRect
        let band = visible.insetBy(dx: 0, dy: -ChapterTextController.selectionFillMargin(for: visible))
        let top = controller.selectionFills
        #expect(!top.isEmpty)
        #expect(top.allSatisfy { $0.intersects(band) })
        #expect(top.contains { $0.intersects(visible) })
        // The chapter's last lines in view.
        let length = controller.textView.string.utf16.count
        let lastLine = try #require(controller.segmentFrames(of: NSRange(location: length - 6, length: 5)).last)
        F.scroll(controller, toY: lastLine.minY - 300)
        let foot = controller.scrollView.documentVisibleRect
        #expect(foot.minY > band.maxY, "the page scrolled past the first band")
        let after = controller.selectionFills
        #expect(after.contains { $0.intersects(foot) })
        #expect(!after.contains { $0.intersects(visible) })
        #expect(controller.fillsView.selectionRects == after)
    }

    /// A drag: `NSTextView` tracks it inside `mouseDown` and sets the selection on every move
    /// "still selecting", which posts no selection notification until the mouse-up. The fill must
    /// follow it all the same, growing and shrinking, behind the words. (The real tracking loop,
    /// driven by events posted to an offscreen window, showed those calls; it is not run here,
    /// as afterwards AppKit stops the main run loop and the test runner exits mid-run.)
    @Test func aDragIsFilledWhileTheMouseIsDown() throws {
        var notified = false
        let observer = NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification, object: controller.textView, queue: nil) { _ in
            MainActor.assumeIsolated { notified = true }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        var changes: [[NSRect]] = []
        controller.onSelectionFillChange = { changes.append($0) }
        let start = try span(3).textRange.location + 6
        let left = controller.textView.textContainerInset.width
        func drag(to end: Int) -> [NSRect] {
            controller.textView.setSelectedRanges([NSValue(range: NSRange(location: start, length: end - start))], affinity: .downstream, stillSelecting: true)
            return controller.selectionFills
        }
        let short = drag(to: start + 7)
        let long = drag(to: try span(5).textRange.location + 10)
        let back = drag(to: start + 20)
        #expect(!notified, "no notification while the mouse is down")
        #expect(changes.count == 3)
        #expect(short.count == 1 && long.count > short.count && back.count < long.count)
        // The mouse-up: the same range, no longer still selecting, and the same fill.
        controller.textView.setSelectedRanges([NSValue(range: NSRange(location: start, length: 20))], affinity: .downstream, stillSelecting: false)
        #expect(notified)
        #expect(controller.selectionFills == back)
        for fills in [short, long, back] {
            #expect(fills.allSatisfy { $0.minX >= left - 0.5 && $0.maxX <= columnRight + 0.5 })
        }
    }

    // MARK: - Pixels

    struct Pixels {
        let data: [UInt8]
        let width: Int
        let height: Int

        /// Pixels in `rect` (window coordinates, y up) whose colour is one of `colors`.
        func count(in rect: NSRect, of colors: Set<String>) -> Int {
            let clipped = rect.intersection(NSRect(x: 0, y: 0, width: width, height: height))
            guard !clipped.isEmpty else { return 0 }
            var found = 0
            for y in Int(clipped.minY.rounded(.up))..<Int(clipped.maxY.rounded(.down)) {
                for x in Int(clipped.minX.rounded(.up))..<Int(clipped.maxX.rounded(.down)) {
                    let i = ((height - 1 - y) * width + x) * 4
                    if colors.contains(String(format: "#%02X%02X%02X", data[i], data[i + 1], data[i + 2])) { found += 1 }
                }
            }
            return found
        }
    }

    private static func render(_ view: NSView) -> Pixels {
        view.window?.displayIfNeeded()
        CATransaction.flush()
        let width = Int(view.bounds.width), height = Int(view.bounds.height)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        view.layer!.render(in: context)
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        return Pixels(data: Array(UnsafeBufferPointer(start: bytes, count: width * height * 4)), width: width, height: height)
    }

    private static func hex(_ color: NSColor, in name: NSAppearance.Name) -> String {
        var result = ""
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            let c = color.usingColorSpace(.sRGB)!
            result = String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
        }
        return result
    }
}
#endif
