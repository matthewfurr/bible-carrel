#if os(macOS)
import AppKit
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

/// A single click on a verse in the Mac reader selects the whole verse and opens the markup menu
/// for it, every time; with the menu open, a click anywhere else only closes it and deselects,
/// unless it is the second click of a double-click on a word. A drag, a double-click and a click
/// inside a highlight keep the menu's path. The menu sits below the selection, or above it.
@MainActor @Suite struct ReaderClickTests {
    private typealias F = ControllerFixture

    private let verses = F.verses(count: 20)
    private let layout: BookLayout
    private let controller: ChapterTextController
    /// The reports `menuProvider` was given, and the menus shown.
    private let asked = Asked()

    final class Asked {
        var reports: [SelectionReport] = []
        /// Each shown menu's top-left, in text-view coordinates.
        var origins: [NSPoint] = []
        /// How the next menus close, in order; past the end, Esc.
        var endings: [MarkupMenuEnding] = []
        /// Every report the controller sent the model.
        var sent: [SelectionReport?] = []
        var isEmpty: Bool { reports.isEmpty }
        var count: Int { reports.count }
        subscript(index: Int) -> SelectionReport { reports[index] }
    }

    init() {
        layout = F.layout(verses)
        controller = F.makeController()
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: .none)
        F.sizeToContent(controller)
        let asked = asked
        controller.menuProvider = { report in
            asked.reports.append(report)
            return NSMenu()
        }
        // A stand-in: `NSMenu.popUp` would block a test.
        controller.presentMenu = { _, origin, _ in
            asked.origins.append(origin)
            return asked.endings.isEmpty ? .closedWithoutAClick : asked.endings.removeFirst()
        }
        controller.onSelectionChange = { asked.sent.append($0) }
    }

    /// A verse of Matthew 5.
    private func at(_ verse: Int) -> VerseLocation {
        VerseLocation(book: "MAT", chapter: 5, verse: verse)
    }

    /// Where a real click leaves things: the caret at the point, then mouse-up.
    private func click(_ point: NSPoint) {
        let index = controller.textView.characterIndexForInsertion(at: point)
        controller.textView.setSelectedRange(NSRange(location: index, length: 0))
        controller.clickEnded(at: point, clickCount: 1)
    }

    /// The centre of verse `n`'s first five text characters.
    private func words(_ n: Int) throws -> NSPoint {
        let span = try #require(layout.span(for: at(n)))
        let rect = try #require(controller.frameOfFirstSegment(of: NSRange(location: span.textRange.location, length: 5)))
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    /// A highlight on verse 3's first ten characters, shown.
    private func showHighlight() throws -> RangeDecoration {
        let item = MarkupItem(id: UUID(), chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 10, translationID: "WEB",
                              color: MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00"), hasNote: false)
        let decorations = F.decorations([item], layout: layout)
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: decorations)
        return try #require(decorations.highlights.first)
    }

    @Test func aClickSelectsTheVerseAndOpensItsMenuEveryTime() throws {
        click(try words(3))
        let span = try #require(layout.span(for: at(3)))
        #expect(controller.textView.selectedRange() == span.textRange)
        #expect(asked.count == 1 && asked[0].selection.verse == 3)
        #expect(controller.selectionReport()?.selection.verse == 3)
        // Closed with Esc, the verse stays selected; a click on it opens its menu again.
        click(try words(3))
        #expect(controller.textView.selectedRange() == span.textRange)
        #expect(asked.count == 2 && asked[1].selection.verse == 3)
        // On the verse's number too.
        let number = try #require(controller.frameOfFirstSegment(of: span.numberRange))
        #expect(controller.verseSpan(at: NSPoint(x: number.midX, y: number.midY)) == span)
    }

    @Test func anItemChosenLeavesWhatItDid() throws {
        asked.endings = [.chosen]
        click(try words(3))
        #expect(asked.count == 1 && asked.origins.count == 1)
        #expect(controller.textView.selectedRange() == layout.span(for: at(3))?.textRange)
    }

    @Test func closedByAKeyTheSelectionStaysQuietly() throws {
        asked.endings = [.closedWithoutAClick]
        click(try words(3))
        #expect(asked.count == 1)
        #expect(controller.textView.selectedRange() == layout.span(for: at(3))?.textRange)
        #expect(asked.sent.last??.selection.verse == 3)
    }

    @Test func closedByAClickElsewhereOnlyDeselects() throws {
        let elsewhere = try words(5)
        for place in [elsewhere, nil] as [NSPoint?] {
            asked.endings = [.mouseDown(at: place, clickCount: 1)]
            let before = asked.count
            click(try words(3))
            // The click that closed the menu selects nothing and asks for no menu.
            #expect(asked.count == before + 1)
            #expect(controller.textView.selectedRange().length == 0)
            #expect(controller.selectionReport() == nil)
            #expect(asked.sent.last.map { $0 == nil } == true)
        }
        // The next click starts fresh.
        click(elsewhere)
        #expect(controller.textView.selectedRange() == layout.span(for: at(5))?.textRange)
        #expect(asked.reports.last?.selection.verse == 5)
    }

    @Test func aClickAwayFromAHighlightsMenuTakesItsOutlineToo() throws {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let defaults = try #require(UserDefaults(suiteName: "ReaderClickTests-\(UUID().uuidString)"))
        let model = MarkupModel(store: store, defaults: defaults)
        model.load(book: "MAT", chapters: 5...5, chapterInView: ChapterLocation(book: "MAT", chapter: 5), translationID: "WEB")
        model.setLayout(layout)
        controller.onSelectionChange = { model.setSelection($0) }
        let highlight = try showHighlight()
        asked.endings = [.mouseDown(at: try words(7), clickCount: 1)]
        let inside = NSRange(location: highlight.range.location + 2, length: 0)
        controller.textView.setSelectedRange(inside)
        #expect(model.outlinedHighlightID == highlight.id)
        controller.clickEnded(at: try words(3), clickCount: 1)
        #expect(asked.count == 1 && asked[0].primaryHighlightID == highlight.id)
        #expect(model.outlinedHighlightID == nil)
        #expect(model.currentSelection == nil)
        #expect(controller.selectionReport() == nil)
        withExtendedLifetime(container) {}
    }

    @Test func theSecondClickOfADoubleClickSelectsTheWordAndOpensItsMenu() throws {
        let point = try words(5)
        asked.endings = [.mouseDown(at: point, clickCount: 2)]
        click(point)
        let span = try #require(layout.span(for: at(5)))
        let word = controller.textView.selectedRange()
        #expect(word.length > 0 && word.length < span.textRange.length)
        #expect(word.location >= span.textRange.location && NSMaxRange(word) <= NSMaxRange(span.textRange))
        #expect((controller.textView.string as NSString).substring(with: word) == "Verse")
        #expect(asked.count == 2 && asked[1].range == word)
        // A click count of two off the text is a click away.
        asked.endings = [.mouseDown(at: NSPoint(x: 4, y: point.y), clickCount: 2)]
        click(point)
        #expect(controller.textView.selectedRange().length == 0)
        #expect(asked.count == 3)
    }

    @Test func theKeysSelectWithNoMenu() throws {
        #expect(controller.perform(.nextVerse))
        #expect(controller.textView.selectedRange().length > 0)
        #expect(controller.perform(.nextVerse))
        #expect(controller.perform(.extendDown))
        #expect(controller.perform(.previousVerse))
        #expect(asked.isEmpty && asked.origins.isEmpty)
    }

    @Test func withAVerseSelectedAndNoMenuAClickOnAnotherSelectsItWithItsMenu() throws {
        click(try words(3))                                     // closed with Esc
        click(try words(5))
        #expect(controller.textView.selectedRange() == layout.span(for: at(5))?.textRange)
        #expect(asked.count == 2 && asked[1].selection.verse == 5)
        // From the keys' selection too.
        #expect(controller.perform(.nextVerse))
        click(try words(2))
        #expect(controller.textView.selectedRange() == layout.span(for: at(2))?.textRange)
        #expect(asked.count == 3 && asked[2].selection.verse == 2)
    }

    @Test func aClickOffTheTextClearsTheSelection() throws {
        click(try words(3))
        click(NSPoint(x: 4, y: try words(3).y))                    // the margin beside the line
        #expect(controller.textView.selectedRange().length == 0)
        #expect(controller.verseSpan(at: NSPoint(x: 4, y: try words(3).y)) == nil)
        #expect(asked.sent.last.map { $0 == nil } == true)
        // With nothing selected, it does nothing.
        #expect(asked.count == 1)
    }

    @Test func everyPointDownAVersesLinesIsThatVerse() throws {
        var prefs = ReaderPreferences.default
        prefs.lineSpacing = .relaxed
        let typography = ReaderSettings.typography(prefs)
        let relaxed = F.makeController()
        let chapter = F.book(3...3, counts: [3: 12], typography: typography)
        relaxed.update(layout: chapter, typography: typography, scrollTarget: nil, decorations: .none)
        F.sizeToContent(relaxed)
        let verseOne = try #require(chapter.span(for: VerseLocation(book: "MAT", chapter: 3, verse: 1)))
        // Verse 1 opens the chapter, so each of its lines starts at the column's edge.
        let first = try #require(relaxed.frameOfFirstSegment(of: NSRange(location: verseOne.textRange.location, length: 1)))
        let last = try #require(relaxed.frameOfFirstSegment(of: NSRange(location: NSMaxRange(verseOne.textRange) - 1, length: 1)))
        #expect(last.minY > first.maxY, "the verse wraps")
        for y in stride(from: first.minY, through: last.maxY, by: 1) {
            #expect(relaxed.verseSpan(at: NSPoint(x: first.minX + 4, y: y)) == verseOne, "y \(y)")
        }
    }

    @Test func aClickInsideAHighlightAndADragBehaveAsBefore() throws {
        let highlight = try showHighlight()
        controller.textView.setSelectedRange(NSRange(location: highlight.range.location + 2, length: 0))
        controller.clickEnded(at: try words(3), clickCount: 1)
        #expect(controller.textView.selectedRange().length == 0)                     // still the caret
        #expect(asked.count == 1 && asked[0].primaryHighlightID == highlight.id)     // its menu is asked for
        // A drag across part of two words: snapped to the words, and the menu asked for.
        let start = try #require(layout.span(for: at(5))).textRange.location
        controller.textView.setSelectedRange(NSRange(location: start + 1, length: 8))
        controller.clickEnded(at: try words(5), clickCount: 1)
        #expect(asked.count == 2 && controller.textView.selectedRange() == controller.actionRange())
        // A double-click's word.
        controller.textView.setSelectedRange(NSRange(location: start, length: 5))
        controller.clickEnded(at: try words(5), clickCount: 2)
        #expect(asked.count == 3 && controller.textView.selectedRange().length == 5)
    }

    @Test func aClickedVerseIsASelectionEverywhere() throws {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let defaults = try #require(UserDefaults(suiteName: "ReaderClickTests-\(UUID().uuidString)"))
        let model = MarkupModel(store: store, defaults: defaults)
        model.load(book: "MAT", chapters: 5...5, chapterInView: ChapterLocation(book: "MAT", chapter: 5), translationID: "WEB")
        model.setLayout(layout)
        controller.onSelectionChange = { model.setSelection($0) }
        click(try words(2))
        #expect(model.currentSelection?.selection.verse == 2)
        #expect(model.currentSelection?.selection.quotedText == verses[1].text)      // what ⇧⌘A asks about
        withExtendedLifetime(container) {}
    }

    @Test func theClickThatBringsTheWindowForwardSelectsNothing() {
        #expect(controller.textView.acceptsFirstMouse(for: nil) == false)
    }

    @Test func copyLinkWritesPlainTextAndRichText() throws {
        let matthew = Reference(book: BookCatalog.book(code: "MAT")!, chapter: 5, verse: 2)
        let clipboard = PassageLinkClipboard(link: PassageLink(reference: matthew), scheme: "bible")
        // A pasteboard of its own: a test never replaces what the owner has copied.
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ReaderClickTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        MarkupContextMenu.write(clipboard, to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "bible://mat.5.2")
        #expect(pasteboard.data(forType: .rtf) != nil && pasteboard.string(forType: .html)?.contains("Matthew 5:2") == true)
    }

    // MARK: - Where the menu sits

    @Test func theMenuSitsBelowTheSelectionsLastLineWhenThereIsRoom() {
        let visible = NSRect(x: 0, y: 0, width: 700, height: 300)
        let gap = ChapterTextController.menuGap
        // One line.
        let one = [NSRect(x: 100, y: 50, width: 200, height: 20)]
        #expect(ChapterTextController.menuOrigin(for: one, in: visible, menuSize: NSSize(width: 240, height: 120), click: nil) == NSPoint(x: 100, y: 70 + gap))
        // Many lines: below the last, at the selection's left edge.
        let many = [NSRect(x: 150, y: 40, width: 300, height: 20), NSRect(x: 50, y: 60, width: 400, height: 20),
                    NSRect(x: 50, y: 80, width: 120, height: 20)]
        #expect(ChapterTextController.menuOrigin(for: many, in: visible, menuSize: NSSize(width: 240, height: 120), click: nil) == NSPoint(x: 50, y: 100 + gap))
        // Lines out of view are not counted: below the last one in view.
        let running = many + [NSRect(x: 50, y: 400, width: 100, height: 20)]
        #expect(ChapterTextController.menuOrigin(for: running, in: visible, menuSize: NSSize(width: 240, height: 120), click: nil) == NSPoint(x: 50, y: 100 + gap))
    }

    @Test func theMenuSitsAboveTheSelectionsFirstLineWhenThereIsNoRoomBelow() {
        let visible = NSRect(x: 0, y: 0, width: 700, height: 300)
        let gap = ChapterTextController.menuGap
        let one = [NSRect(x: 100, y: 220, width: 200, height: 20)]
        #expect(ChapterTextController.menuOrigin(for: one, in: visible, menuSize: NSSize(width: 240, height: 120), click: nil) == NSPoint(x: 100, y: 220 - gap - 120))
        let many = [NSRect(x: 150, y: 180, width: 300, height: 20), NSRect(x: 50, y: 200, width: 400, height: 20),
                    NSRect(x: 50, y: 220, width: 120, height: 20)]
        #expect(ChapterTextController.menuOrigin(for: many, in: visible, menuSize: NSSize(width: 240, height: 120), click: nil) == NSPoint(x: 50, y: 180 - gap - 120))
        // Room on neither side: below the last line in view.
        let tall = [NSRect(x: 60, y: 100, width: 300, height: 20), NSRect(x: 50, y: 120, width: 300, height: 20)]
        #expect(ChapterTextController.menuOrigin(for: tall, in: visible, menuSize: NSSize(width: 240, height: 200), click: nil) == NSPoint(x: 50, y: 140 + gap))
        // A visible area that starts lower (under the running head) has less room above.
        let under = NSRect(x: 0, y: 120, width: 700, height: 180)
        #expect(ChapterTextController.menuOrigin(for: one, in: under, menuSize: NSSize(width: 240, height: 120), click: nil) == NSPoint(x: 100, y: 240 + gap))
    }

    @Test func aClickedVersesMenuDoesNotCoverItsWords() throws {
        click(try words(3))
        let span = try #require(layout.span(for: at(3)))
        let lines = controller.segmentFrames(of: span.textRange)
        let origin = try #require(asked.origins.first)
        let bottom = try #require(lines.map(\.maxY).max())
        #expect(origin.y >= bottom)
        #expect(origin.x == lines.map(\.minX).min())
    }

    /// A selection taller than the page has room on neither side, where AppKit would fit the menu
    /// to the screen, possibly under the pointer: it opens beside the click instead, and never
    /// with the click's point inside it.
    @Test func theMenuNeverOpensUnderTheClick() {
        let visible = NSRect(x: 0, y: 0, width: 700, height: 300)
        let size = NSSize(width: 240, height: 200)
        let gap = ChapterTextController.menuGap
        let tall = stride(from: -60, through: 380, by: 20).map { NSRect(x: 50, y: CGFloat($0), width: 500, height: 20) }
        let middle = NSPoint(x: 300, y: 150)
        let beside = ChapterTextController.menuOrigin(for: tall, in: visible, menuSize: size, click: middle)
        #expect(!NSRect(origin: beside, size: size).contains(middle))
        #expect(beside.x == middle.x + gap)
        #expect(beside.y >= visible.minY && beside.y + size.height <= visible.maxY)
        // Near the right edge: to its left.
        let right = NSPoint(x: 600, y: 150)
        let left = ChapterTextController.menuOrigin(for: tall, in: visible, menuSize: size, click: right)
        #expect(!NSRect(origin: left, size: size).contains(right))
        #expect(left.x + size.width == right.x - gap)
        // A place below the selection that would hold the click (a click in the line's leading
        // below the glyphs) moves aside too.
        let one = [NSRect(x: 100, y: 50, width: 200, height: 20)]
        let low = NSPoint(x: 150, y: 80)
        let moved = ChapterTextController.menuOrigin(for: one, in: visible, menuSize: NSSize(width: 240, height: 120), click: low)
        #expect(!NSRect(origin: moved, size: NSSize(width: 240, height: 120)).contains(low))
        // A click on the line itself keeps the place below.
        let on = NSPoint(x: 150, y: 60)
        #expect(ChapterTextController.menuOrigin(for: one, in: visible, menuSize: NSSize(width: 240, height: 120), click: on) == NSPoint(x: 100, y: 70 + gap))
    }

    // MARK: - After a click away

    @Test func aClickAwayLeavesNothingOfTheOldSelection() throws {
        asked.endings = [.mouseDown(at: try words(7), clickCount: 1)]
        click(try words(3))
        // Told once, with nothing, after the verse.
        let verse = try #require(asked.sent.lastIndex { $0?.selection.verse == 3 })
        let after = asked.sent[(verse + 1)...]
        #expect(after.count == 1 && after.first.map { $0 == nil } == true, "\(after.count)")
        // No caret in the old verse, so no anchor: J starts from the page, a Shift-click is a plain click.
        let old = try #require(layout.span(for: at(3)))
        #expect(!NSLocationInRange(controller.textView.selectedRange().location, old.fullRange))
        #expect(controller.shiftClickExtends == false)
        // The next selection gives Shift-click its anchor back.
        click(try words(5))
        #expect(controller.shiftClickExtends)
    }

    @Test func aShiftClickAfterAClickAwayIsAPlainClick() throws {
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [.shift, .option],
                                                    timestamp: 12, windowNumber: 0, context: nil, eventNumber: 3, clickCount: 1, pressure: 1))
        let plain = ColumnTextView.withoutShift(event)
        #expect(!plain.modifierFlags.contains(.shift) && plain.modifierFlags.contains(.option))
        #expect(plain.type == .leftMouseDown && plain.locationInWindow == event.locationInWindow)
        #expect(plain.timestamp == event.timestamp && plain.clickCount == 1)
    }

    // MARK: - How the menu closed, from what AppKit reports

    private typealias Close = ChapterTextController.MenuCloseState

    /// The menu opened at 100 for a click at (300, 150).
    private func close(chosen: Bool = false, event: Close.Event? = nil, buttons: Int = 0, pointer: NSPoint? = nil, now: TimeInterval = 100.2) -> MarkupMenuEnding {
        ChapterTextController.menuEnding(Close(chosen: chosen, event: event, buttonsDown: buttons, pointer: pointer,
                                               opened: 100, now: now, click: NSPoint(x: 300, y: 150)))
    }

    private func event(_ type: NSEvent.EventType, at time: TimeInterval = 100.1, count: Int = 1, point: NSPoint? = NSPoint(x: 40, y: 60)) -> Close.Event {
        Close.Event(type: type, time: time, clickCount: count, point: point)
    }

    @Test func aChoiceIsAChoice() {
        #expect(close(chosen: true) == .chosen)                                              // clicked, Return, or a swatch
        #expect(close(chosen: true, event: event(.leftMouseUp)) == .chosen)
        #expect(close(chosen: true, event: event(.keyDown, count: 0)) == .chosen)
    }

    @Test func escIsNotAClick() {
        #expect(close(event: event(.keyDown, count: 0)) == .closedWithoutAClick)
        // The opening click's own mouse-up, still current, is from before the menu.
        #expect(close(event: event(.leftMouseUp, at: 99.9)) == .closedWithoutAClick)
        #expect(close(event: event(.leftMouseDown, at: 99.8)) == .closedWithoutAClick)
        // Focus lost (⌘-Tab): no click, no button.
        #expect(close() == .closedWithoutAClick)
        #expect(close(event: event(.appKitDefined, count: 0)) == .closedWithoutAClick)
    }

    @Test func aClickElsewhereIsAClickAwayWhetherItsDownOrItsUpIsCurrent() {
        let point = NSPoint(x: 40, y: 60)
        #expect(close(event: event(.leftMouseDown)) == .mouseDown(at: point, clickCount: 1))
        #expect(close(event: event(.leftMouseUp)) == .mouseDown(at: point, clickCount: 1))
        #expect(close(event: event(.leftMouseUp, at: 100)) == .mouseDown(at: point, clickCount: 1))     // at the opening
        // Another window or app: no point.
        #expect(close(event: event(.leftMouseDown, point: nil)) == .mouseDown(at: nil, clickCount: 1))
        #expect(close(event: event(.leftMouseUp, point: nil)) == .mouseDown(at: nil, clickCount: 1))
        // Right and other buttons, down or up, count once.
        for type in [NSEvent.EventType.rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp] {
            #expect(close(event: event(type, count: 2)) == .mouseDown(at: point, clickCount: 1), "\(type)")
        }
    }

    @Test func theSecondClickOfADoubleClickKeepsItsCount() {
        let point = NSPoint(x: 40, y: 60)
        #expect(close(event: event(.leftMouseDown, count: 2)) == .mouseDown(at: point, clickCount: 2))
        #expect(close(event: event(.leftMouseUp, count: 2)) == .mouseDown(at: point, clickCount: 2))
    }

    @Test func aButtonStillDownIsTheClickAtThePointer() {
        let near = NSPoint(x: 302, y: 151)
        // Quick and near the opening click, the left button alone: the double-click's second click.
        #expect(close(buttons: 1, pointer: near) == .mouseDown(at: near, clickCount: 2))
        // Late, far, or another button: a click away.
        #expect(close(buttons: 1, pointer: near, now: 100 + NSEvent.doubleClickInterval + 0.1) == .mouseDown(at: near, clickCount: 1))
        #expect(close(buttons: 1, pointer: NSPoint(x: 340, y: 150)) == .mouseDown(at: NSPoint(x: 340, y: 150), clickCount: 1))
        #expect(close(buttons: 2, pointer: near) == .mouseDown(at: near, clickCount: 1))
        // Not over the reader's window: no point.
        #expect(close(buttons: 1, pointer: nil) == .mouseDown(at: nil, clickCount: 1))
        // A key event current and a button held: still the click.
        #expect(close(event: event(.keyDown, count: 0), buttons: 1, pointer: near) == .mouseDown(at: near, clickCount: 2))
    }
}
#endif
