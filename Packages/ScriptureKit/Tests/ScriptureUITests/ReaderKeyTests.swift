#if os(macOS)
import AppKit
import ScriptureData
import ScriptureModel
import SwiftData
import SwiftUI
import Testing
@testable import ScriptureUI

/// The Mac reader's single keys: J and K walk the chapter's verses, ⇧J and ⇧K grow and shrink the
/// selection, the numbers, 0, N and B act on it as the context menu does, the arrows turn
/// chapters, Esc clears and ? asks for the shortcuts. They act only while the reader's text has
/// keyboard focus.
@MainActor @Suite final class ReaderKeyTests {
    private typealias F = ControllerFixture
    /// The reader's, not SwiftUI's (imported for the verse panel's content).
    private typealias ScrollTarget = ScriptureUI.ScrollTarget

    private let container: ModelContainer
    private let model: MarkupModel
    private let undoManager = UndoManager()
    private let navigation: NavigationModel
    private let controller: ChapterTextController
    private var layout: BookLayout
    private var defaultsNames: [String] = []
    private var madeWindow: NSWindow?
    private let field = NSTextView(frame: NSRect(x: 0, y: 320, width: 200, height: 40))
    private let secondField = NSTextView(frame: NSRect(x: 220, y: 320, width: 200, height: 40))
    private let other = ResponderView(frame: NSRect(x: 440, y: 320, width: 40, height: 40))
    /// Two real text fields: both edit through the window's one shared field editor, as the
    /// palette's field and the assistant's composer do.
    private let textField = NSTextField(frame: NSRect(x: 0, y: 360, width: 200, height: 24))
    private let secondTextField = NSTextField(frame: NSRect(x: 220, y: 360, width: 200, height: 24))

    /// A plain view that takes keyboard focus: the window, a row, a button.
    final class ResponderView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    private static let matthew5 = ChapterLocation(book: "MAT", chapter: 5)

    /// The three short verses of `MarkupModelTests`.
    private static var shortVerses: [Verse] {
        [(1, "Blessed are the poor."), (2, "For theirs is."), (3, "Blessed mourners.")].map { n, text in
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "ESV", text: text, breakAfter: false)
        }
    }

    init() throws {
        container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        // Scratch defaults suites, removed when the test ends.
        let name = "ReaderKeyTests-\(UUID().uuidString)"
        defaultsNames = [name, name + "-markup"]
        let markupDefaults = try #require(UserDefaults(suiteName: name + "-markup"))
        let model = MarkupModel(store: MarkupStore(container: container), defaults: markupDefaults)
        undoManager.groupsByEvent = false
        model.undoManager = undoManager
        self.model = model

        let defaults = try #require(UserDefaults(suiteName: name))
        let navigation = try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "WEB")
        navigation.open(ChapterLocation(book: "MAT", chapter: 2))
        self.navigation = navigation

        layout = F.layout(Self.shortVerses)
        let controller = F.makeController()
        controller.reducesMotion = { true }
        controller.onSelectionChange = { model.setSelection($0) }
        controller.onReaderKey = { [unowned controller] action, report in
            ReaderKeyCommands.perform(action, report: report, markup: model, navigation: navigation, controller: controller)
        }
        // As `MainWindowView` wires it: no reader key while ⌘K shows or a note is being edited.
        controller.keysAreLive = { ReaderKeyCommands.keysAreLive(markup: model, navigation: navigation) }
        self.controller = controller
        use(layout, translation: "ESV")
    }

    isolated deinit {
        madeWindow?.close()
        for name in defaultsNames { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
    }

    /// Shows `layout` (Matthew 5) in the controller, with the markup loaded for it.
    private func use(_ layout: BookLayout, translation: String) {
        self.layout = layout
        model.load(book: "MAT", chapters: 5...5, chapterInView: Self.matthew5, translationID: translation)
        model.setLayout(layout)
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: model.bookDecorations)
        F.sizeToContent(controller)
    }

    /// Sixty of `F.verses` in place of the three short ones.
    private func useSixty() {
        use(F.layout(F.verses(count: 60)), translation: "WEB")
    }

    /// Verse n's `textRange`.
    private func t(_ n: Int) -> NSRange {
        layout.span(for: VerseLocation(book: "MAT", chapter: 5, verse: n))!.textRange
    }

    private func select(_ n: Int) {
        controller.selectVerses(t(n), anchor: t(n).location)
    }

    /// The selected verses, or nil for none.
    private var selected: ClosedRange<Int>? {
        controller.selectionReport().map { $0.selection.verse...$0.selection.endVerse }
    }

    /// The reader in a window with two fields being typed in and a plain view that takes focus.
    private var window: NSWindow {
        if let madeWindow { return madeWindow }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 400))
        window.contentView = content
        for view in [controller.scrollView, field, secondField, other, textField, secondTextField] as [NSView] { content.addSubview(view) }
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 700, height: 300)
        madeWindow = window
        return window
    }

    private func key(_ characters: String, flags: NSEvent.ModifierFlags = [], keyCode: UInt16 = 0, isARepeat: Bool = false) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                      windowNumber: madeWindow?.windowNumber ?? 0, context: nil, characters: characters,
                                      charactersIgnoringModifiers: characters, isARepeat: isARepeat, keyCode: keyCode))
    }

    private func press(_ characters: String, shift: Bool = false) {
        send(try? key(characters, flags: shift ? .shift : []))
    }

    /// Escape (53), ← (123) or → (124).
    private func press(keyCode: UInt16, isARepeat: Bool = false) {
        let characters: [UInt16: Int] = [53: 0x1B, 123: NSLeftArrowFunctionKey, 124: NSRightArrowFunctionKey]
        let character = String(Character(Unicode.Scalar(UInt32(characters[keyCode] ?? 0))!))
        send(try? key(character, keyCode: keyCode, isARepeat: isARepeat))
    }

    /// One key to the reader's text view, as one undo step, then the markup's new decorations.
    private func send(_ event: NSEvent?) {
        guard let event else {
            Issue.record("no key event")
            return
        }
        undoManager.beginUndoGrouping()
        controller.textView.keyDown(with: event)
        undoManager.endUndoGrouping()
        controller.update(layout: layout, typography: .default, scrollTarget: nil, decorations: model.bookDecorations)
    }

    /// The same layout again, with a scroll target or new decorations, or another layout.
    private func show(_ newLayout: BookLayout? = nil, target: ScrollTarget? = nil, decorations: BookDecorations? = nil) {
        if let newLayout { layout = newLayout }
        controller.update(layout: layout, typography: .default, scrollTarget: target, decorations: decorations ?? model.bookDecorations)
    }

    @Test func jAndKWalkTheChapter() {
        press("j"); #expect(selected == 1...1)            // nothing selected: the first verse on screen
        press("j"); #expect(selected == 2...2)
        press("k"); #expect(selected == 1...1)
        press("k"); #expect(selected == 1...1)            // at the first verse, nothing
        select(3); press("j"); #expect(selected == 3...3) // at the last verse, nothing
    }

    @Test func shiftJAndShiftKGrowAndShrink() {
        select(1)
        press("J", shift: true); #expect(selected == 1...2)
        press("J", shift: true); #expect(selected == 1...3)
        press("K", shift: true); #expect(selected == 1...2)
    }

    @Test func aNumberKeyHighlightsLikeItsSwatchAndTheSelectionCollapses() throws {
        select(2)
        press("1")
        let item = try #require(model.items.first)
        #expect(model.items.count == 1 && item.color == model.colorChips[0].color)
        #expect(item.verse == 2 && item.startOffset == 0 && item.endOffset == t(2).length)
        #expect(controller.textView.selectedRange().length == 0 && model.outlinedHighlightID == item.id)
        press("j"); #expect(selected == 3...3)            // carries on from that verse
        // Inside the highlight (a caret), another number recolours it.
        controller.textView.setSelectedRange(NSRange(location: t(2).location + 1, length: 0))
        press("2")
        #expect(model.items.count == 1 && model.items[0].color == model.colorChips[1].color)
        // A number past the last of the five colours does nothing.
        select(3); press("9")
        #expect(model.items.count == 1 && selected == 3...3)
    }

    @Test func zeroTakesTheColourOffAndNeverTheNote() throws {
        select(1); press("1")
        select(1); press("n")
        let noteID = try #require(model.editingNoteID)
        model.updateNoteBody(noteID: noteID, body: "kept")
        model.endEditing(noteID: noteID)
        press("0")                                        // the caret is inside the highlight
        #expect(model.items.count == 1 && model.items[0].color == nil && model.items[0].hasNote)
        select(3); press("2")
        press("0")
        #expect(model.items.allSatisfy { $0.verse != 3 }) // a noteless one is removed
        undoManager.undo()
        #expect(model.items.contains { $0.verse == 3 })   // and comes back
        select(2); press("0")
        #expect(model.items.count == 2)                   // outside any highlight, nothing
    }

    @Test func nStartsTheNoteAndBTogglesTheBookmark() {
        var shown = 0
        model.onShowNotesColumn = { shown += 1 }
        for key in ["1", "0", "n", "b"] { press(key) }    // with nothing selected, nothing
        #expect(model.items.isEmpty && model.editingNoteID == nil && model.bookmarkVerses.isEmpty && shown == 0)
        select(2); press("b"); #expect(model.bookmarkVerses == [2])
        select(2); press("b"); #expect(model.bookmarkVerses.isEmpty)
        select(2); press("n")
        #expect(model.editingNoteID != nil && shown == 1)
    }

    @Test func theArrowsTurnChaptersAcrossBooks() {
        press(keyCode: 124); #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 3))
        press(keyCode: 123); press(keyCode: 123)
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 1))
        press(keyCode: 123); #expect(navigation.location?.book == "PSA")
    }

    @Test func escapeClearsTheSelectionAndTheQuestionMarkAsksForTheShortcuts() {
        select(2)
        press(keyCode: 53)
        #expect(controller.textView.selectedRange().length == 0 && model.currentSelection == nil)
        #expect(controller.perform(.clearSelection) == false)   // nothing to clear: the key is left to AppKit
        press("?")
        #expect(navigation.isShortcutsShown)
    }

    @Test func capsLockAndTheKeypadStillReachTheReaderKeys() throws {
        #expect(ReaderKeyStroke(event: try key("J", flags: .capsLock)) == ReaderKeyStroke(.character("j")))
        #expect(ReaderKeyStroke(event: try key("J", flags: .shift)) == ReaderKeyStroke(.character("j"), shift: true))
        #expect(ReaderKeyStroke(event: try key("1", flags: .numericPad)) == ReaderKeyStroke(.character("1")))
        #expect(ReaderKeyStroke(event: try key("?", flags: .shift)) == ReaderKeyStroke(.character("?")))
    }

    @Test func modifiedKeysAreNotReaderKeys() throws {
        for flags in [NSEvent.ModifierFlags.command, .option, .control] {
            #expect(ReaderKeyStroke(event: try key("1", flags: flags)) == nil)
            #expect(ReaderKeyStroke(event: try key("j", flags: flags)) == nil)
        }
    }

    @Test func jFromASelectionScrolledOutOfViewStartsAtTheFirstVerseOnScreen() {
        // Sixty verses; verse 2 selected, then the page jumps to verse 40.
        useSixty()
        select(2)
        show(target: ScrollTarget(chapter: 5, verse: 40))
        press("j")
        #expect(selected == 40...40)
    }

    @Test func aVerseBelowTheFoldIsScrolledWhollyIntoView() throws {
        // Sixty verses in the 300 pt window: step until the selection has left the first screen.
        useSixty()
        for _ in 0..<12 { press("j") }
        let range = controller.textView.selectedRange()
        let top = try #require(controller.frameOfFirstSegment(of: NSRange(location: range.location, length: 1)))
        let foot = try #require(controller.frameOfFirstSegment(of: NSRange(location: NSMaxRange(range) - 1, length: 1)))
        let visible = controller.scrollView.documentVisibleRect
        #expect(top.minY >= visible.minY + controller.headLineY && foot.maxY <= visible.maxY)
    }

    /// Whether verse n's text is wholly on the visible page under the head.
    private func isWhollyVisible(_ n: Int) throws -> Bool {
        let range = t(n)
        let top = try #require(controller.frameOfFirstSegment(of: NSRange(location: range.location, length: 1)))
        let foot = try #require(controller.frameOfFirstSegment(of: NSRange(location: NSMaxRange(range) - 1, length: 1)))
        let visible = controller.scrollView.documentVisibleRect
        return top.minY >= visible.minY + controller.headLineY && foot.maxY <= visible.maxY
    }

    @Test func shiftJAndShiftKRevealTheVerseThatMoved() throws {
        // Sixty verses in the 300 pt window: a selection grown well past the page's height.
        useSixty()
        select(1)
        for _ in 0..<14 { press("J", shift: true) }
        #expect(selected == 1...15)
        #expect(try isWhollyVisible(15))                  // the verse just added, not the selection's top
        #expect(try !isWhollyVisible(1))
        press("K", shift: true)                           // shrinks: verse 14 is now the free end
        let fourteenShows = try isWhollyVisible(14)
        #expect(selected == 1...14 && fourteenShows)
        // Growing upwards from verse 40, after a jump away.
        select(40)
        show(target: ScrollTarget(chapter: 5, verse: 40))
        for _ in 0..<14 { press("K", shift: true) }
        #expect(selected == 26...40)
        let (topShows, anchorShows) = (try isWhollyVisible(26), try isWhollyVisible(40))
        #expect(topShows && !anchorShows)
        press("J", shift: true)                           // shrinks from the top: verse 27 is the free end
        let twentySevenShows = try isWhollyVisible(27)
        #expect(selected == 27...40 && twentySevenShows)
    }

    /// A held key: many steps with the animated scroll, no run-loop turn between them, so the
    /// clip has not yet reached any of the scrolls the keys asked for.
    @Test func heldKeysStepFromTheVerseTheyLastReached() {
        useSixty()
        controller.reducesMotion = { false }
        for _ in 0..<30 { #expect(controller.perform(.nextVerse)) }
        #expect(selected == 30...30)
        for _ in 0..<40 { #expect(controller.perform(.nextVerse)) }
        #expect(selected == 60...60)                      // stops at the last verse
        for _ in 0..<25 { #expect(controller.perform(.previousVerse)) }
        #expect(selected == 35...35)
        // J and ⇧J mixed.
        for _ in 0..<5 {
            #expect(controller.perform(.nextVerse))
            #expect(controller.perform(.extendDown))
        }
        #expect(selected == 44...45)
    }

    @Test func aScrollThatIsNotTheKeysStillLetsJStartOnScreen() {
        // The keys reach verse 2; the reader then scrolls away by hand (the wheel, the scroller).
        useSixty()
        press("j"); press("j")
        #expect(selected == 2...2)
        let top = controller.frameOfFirstSegment(of: t(40))?.minY ?? 0
        F.scroll(controller, toY: top - ChapterTextController.scrollLeadIn)
        press("j")
        #expect(selected.map { $0.lowerBound >= 39 } == true)
    }

    // MARK: - The keys' own scroll and the reader's (`noteClipMoved`, through real clip moves)

    /// Moves the clip as the wheel or the scroller would, then lets its notification arrive. A
    /// zero-length animation of the clip's origin replaces any the keys' reveal has in flight, as
    /// a hand scroll does, so the reveal never moves the clip again.
    private func scrollByHand(toY y: CGFloat) {
        let clip = controller.scrollView.contentView
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            clip.animator().setBoundsOrigin(NSPoint(x: clip.bounds.minX, y: y))
        }
        controller.scrollView.reflectScrolledClipView(clip)
        turnRunLoop(0.01)
    }

    private func turnRunLoop(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Presses `key` until the keys start a scroll of their own; its band.
    private func pressUntilTheKeysScroll(_ key: String, shift: Bool = false) throws -> (from: CGFloat, to: CGFloat) {
        for _ in 0..<40 {
            let before = controller.scrollView.contentView.bounds.minY
            press(key, shift: shift)
            if let band = controller.keyScroll { return band }
            let after = controller.scrollView.contentView.bounds.minY
            if abs(after - before) >= 0.5 { return (before, after) }   // a cut, already arrived
        }
        return try #require(controller.keyScroll)
    }

    @Test func aRevealThatArrivesEndsAndTheNextHandScrollIsTheReaders() throws {
        useSixty()                                        // Reduce Motion: the reveal is a cut, it arrives at once
        _ = try pressUntilTheKeysScroll("j")
        turnRunLoop(0.01)
        #expect(controller.keyScroll == nil && controller.keyRange != nil)
        let y = controller.scrollView.contentView.bounds.minY
        scrollByHand(toY: y - 3)                          // a nudge back the way the reveal came
        #expect(controller.keyRange == nil)
    }

    @Test func aMoveAlongTheRevealIsTheKeysAndItsArrivalEndsIt() throws {
        useSixty()
        controller.reducesMotion = { false }
        for (key, shift) in [("j", false), ("k", false), ("J", true), ("K", true)] {
            if key.lowercased() == "k" {                  // K and ⇧K scroll up: start low on the page
                controller.textView.setSelectedRange(NSRange(location: 0, length: 0))
                show(target: ScrollTarget(chapter: 5, verse: 40))
                turnRunLoop(0.01)
                press("j")
            } else {
                controller.textView.setSelectedRange(NSRange(location: 0, length: 0))
                show(target: ScrollTarget(chapter: 5, verse: 1))
                turnRunLoop(0.01)
            }
            let band = try pressUntilTheKeysScroll(key, shift: shift)
            if key.lowercased() == "k" {
                #expect(band.to < band.from, "\(key) scrolls up")
            } else {
                #expect(band.to > band.from, "\(key) scrolls down")
            }
            scrollByHand(toY: (band.from + band.to) / 2)  // a frame of the animation
            #expect(controller.keyScroll != nil && controller.keyRange != nil, "\(key) mid-band")
            scrollByHand(toY: band.to)                    // the last frame
            #expect(controller.keyScroll == nil && controller.keyRange != nil, "\(key) arrived")
        }
    }

    @Test func aRevealCutShortStopsFilteringOnceItsTimeIsUp() throws {
        useSixty()
        controller.reducesMotion = { false }
        let band = try pressUntilTheKeysScroll("j")
        let middle = (band.from + band.to) / 2
        scrollByHand(toY: middle)                         // a hand scroll stops it in the middle
        turnRunLoop(ChapterTextController.keyScrollLifetime + 0.1)
        #expect(abs(controller.scrollView.contentView.bounds.minY - middle) < 0.5)   // it never arrived
        #expect(controller.currentKeyScroll() == nil && controller.keyRange != nil)
        scrollByHand(toY: band.from + (band.to - band.from) / 4)   // later, inside the old band
        #expect(controller.keyRange == nil)
    }

    @Test func aNewLayoutForgetsTheKeysRange() {
        useSixty()
        press("j")
        #expect(controller.keyRange != nil)
        show(F.layout(F.verses(chapter: 6, count: 60)))
        #expect(controller.keyRange == nil)
    }

    @Test func aRevealIsMeasuredFromWhereThePageIsGoing() throws {
        // A reveal of the keys still in flight, 400 pt down (as after a long J), with verse 5
        // selected near the top of the page as it stands now: K's verse 4 is on screen here but
        // above where the page is going, so it must be scrolled to, or the earlier animation
        // would carry the page past it.
        useSixty()
        select(5)
        controller.keyRange = t(5)
        controller.keyScroll = (from: 0, to: 400)
        controller.keyScrollDeadline = Date().addingTimeInterval(10)
        press("k")
        #expect(selected == 4...4)
        let top = try #require(controller.frameOfFirstSegment(of: NSRange(location: t(4).location, length: 1)))
        let landing = controller.currentKeyScroll()?.to ?? controller.scrollView.contentView.bounds.minY
        #expect(top.minY >= landing + controller.headLineY)
    }

    @Test func theFreeEndIsTheVerseAwayFromTheAnchor() {
        useSixty()
        let three = NSRange(location: t(3).location, length: NSMaxRange(t(5)) - t(3).location)
        #expect(ChapterTextController.freeEnd(of: three, anchor: t(3).location, in: layout) == t(5))
        #expect(ChapterTextController.freeEnd(of: three, anchor: t(5).location + 2, in: layout) == t(3))
        #expect(ChapterTextController.freeEnd(of: t(4), anchor: t(4).location, in: layout) == t(4))
    }

    @Test func keysTypedInAnotherFieldNeverReachTheReader() throws {
        select(2)
        window.makeFirstResponder(field)
        window.sendEvent(try key("1"))
        #expect(model.items.isEmpty && field.string == "1")
    }

    // MARK: - Focus

    /// Makes `responder` first responder, runs the change, settles the reader's focus request and
    /// returns the window's first responder.
    private func focus(from responder: NSResponder, _ change: () -> Void) -> NSResponder? {
        window.makeFirstResponder(responder)
        change()
        controller.resolveFocus()
        return window.firstResponder
    }

    @Test func aChapterOpeningGivesTheReaderFocusButNeverFromAFieldBeingTypedIn() {
        var held = focus(from: other) { show(F.layout(F.verses(chapter: 6, count: 5))) }
        #expect(held === controller.textView)
        held = focus(from: field) { show(F.layout(F.verses(chapter: 7, count: 5))) }
        #expect(held === field)
        // The same chapter in another translation is no opening.
        held = focus(from: other) { show(F.layout(F.verses(chapter: 7, count: 5, translation: "KJV"))) }
        #expect(held === other)
    }

    @Test func selectingAHighlightFromTheColumnNeverTakesFocus() {
        // What ↑ and ↓ among the notes column's rows do to the reader: a new outline, nothing else.
        select(1); press("1")
        var decorations = model.bookDecorations
        decorations.outlinedID = model.items[0].id
        let held = focus(from: other) { show(decorations: decorations) }
        #expect(held === other)
    }

    @Test func finishingANoteOrClosingThePaletteGivesFocusBackFromItsOwnField() {
        for reason in [ReaderFocusRule.Reason.noteEditFinished, .paletteClosed] {
            let held = focus(from: field) { controller.requestFocus(reason) }     // the field is the one being left
            #expect(held === controller.textView, "\(reason)")
        }
        // The palette's field is a text field: the window's field editor is what holds focus.
        var held = focus(from: textField) { controller.requestFocus(.paletteClosed) }
        #expect(held === controller.textView)
        // Another text field took focus before the request settled (the assistant's composer):
        // the same field editor, now editing the other field, and it keeps it.
        held = focus(from: textField) { controller.requestFocus(.paletteClosed); window.makeFirstResponder(secondTextField) }
        #expect(held != nil && held === secondTextField.currentEditor())
        // Closing the shortcuts sheet leaves a note being typed.
        held = focus(from: field) { controller.requestFocus(.shortcutsClosed) }
        #expect(held === field)
    }

    @Test func aChapterOpenedBeforeTheReaderHasAWindowTakesFocusOnceItHasOne() {
        // At launch, and after Home and back: the first layout arrives before the view is in a window.
        for startsOnAView in [false, true] {
            let fresh = F.makeController()
            fresh.update(layout: F.layout(F.verses(chapter: 6, count: 5)), typography: .default, scrollTarget: nil, decorations: .none)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            let content = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 400))
            window.contentView = content
            let plain = ResponderView(frame: NSRect(x: 440, y: 320, width: 40, height: 40))
            content.addSubview(plain)
            window.makeFirstResponder(startsOnAView ? plain : nil)
            content.addSubview(fresh.scrollView)
            #expect(window.firstResponder === fresh.textView, "first responder was \(startsOnAView ? "a view" : "the window")")
        }
    }

    // MARK: - While ⌘K shows or a note is being edited

    @Test func noReaderKeyActsWhileThePaletteShowsOrANoteIsBeingEdited() {
        select(2)
        navigation.isPaletteShown = true
        #expect(ReaderKeyCommands.perform(.color(1), report: controller.selectionReport(), markup: model, navigation: navigation, controller: controller))
        #expect(model.items.isEmpty)
        for key in ["1", "0", "n", "b", "j", "J", "?"] { press(key, shift: key == "J") }
        press(keyCode: 124)
        #expect(model.items.isEmpty && model.editingNoteID == nil && model.bookmarkVerses.isEmpty)
        #expect(selected == 2...2 && !navigation.isShortcutsShown)
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 2))
        // Swallowed, not left to AppKit (which would beep): Esc with a selection keeps it.
        #expect(controller.perform(.clearSelection))
        #expect(selected == 2...2)
        navigation.isPaletteShown = false

        model.editingNoteID = UUID()
        #expect(ReaderKeyCommands.perform(.color(1), report: controller.selectionReport(), markup: model, navigation: navigation, controller: controller))
        #expect(model.items.isEmpty)
        press("j"); press("1")
        #expect(selected == 2...2 && model.items.isEmpty)
        model.editingNoteID = nil
        press("j")
        #expect(selected == 3...3)                        // the keys come back
    }

    @Test func aHeldKeyColoursMarksAndBookmarksOnceButStillSteps() throws {
        select(2); press("b")
        #expect(model.bookmarkVerses == [2])
        for characters in ["b", "1", "0", "n"] {
            select(2)
            send(try key(characters, isARepeat: true))
        }
        #expect(model.bookmarkVerses == [2] && model.items.isEmpty && model.editingNoteID == nil)
        select(1)
        send(try key("j", isARepeat: true)); #expect(selected == 2...2)
        send(try key("k", isARepeat: true)); #expect(selected == 1...1)
        send(try key("J", flags: .shift, isARepeat: true)); #expect(selected == 1...2)
        press(keyCode: 124)
        press(keyCode: 124, isARepeat: true)
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 4))   // the arrows repeat
    }

    @Test func cAndROpenTheirPanelsWithASelectionAndDoNothingWithoutOne() throws {
        var asked: [VersePanelKind] = []
        model.onVersePanel = { kind, _ in asked.append(kind) }
        press("c")
        press("r")
        #expect(asked.isEmpty)                                               // nothing selected
        press("j")
        press("c")
        press("r")
        #expect(asked == [.compare, .crossReferences] && controller.textView.selectedRange().length > 0)   // the selection stays
        let titles = MarkupContextMenu.make(for: try #require(controller.reportForAction()), model: model, controller: controller).items.map(\.title)
        let bookmark = try #require(titles.firstIndex { $0.hasPrefix("Bookmark Verse") })
        #expect(Array(titles[(bookmark + 1)...(bookmark + 4)]) == ["Compare Translations", "Cross-References", "", "Copy"])
    }

    @Test func aHeldCOrROpensItsPanelOnce() throws {
        var asked: [VersePanelKind] = []
        model.onVersePanel = { kind, _ in asked.append(kind) }
        select(2)
        press("c")
        send(try key("c", isARepeat: true))
        send(try key("r", isARepeat: true))
        #expect(asked == [.compare])
        press("r")
        #expect(asked == [.compare, .crossReferences])
    }

    // MARK: - The verse panel's popover

    @Test func theVersePanelAnchorsOnTheSelectionsFirstLineHeldOnThePage() throws {
        let page = NSRect(x: 0, y: 200, width: 600, height: 400)
        let line = NSRect(x: 80, y: 260, width: 300, height: 22)
        func anchor(_ segment: NSRect?) -> NSRect { ChapterTextController.versePanelAnchor(firstSegment: segment, visiblePage: page) }
        #expect(anchor(line) == line)
        #expect(anchor(line.offsetBy(dx: 0, dy: -200)) == NSRect(x: 80, y: 200, width: 300, height: 1))    // scrolled off the top
        #expect(anchor(line.offsetBy(dx: 0, dy: 500)) == NSRect(x: 80, y: 599, width: 300, height: 1))     // off the bottom
        #expect(anchor(nil) == NSRect(x: 300, y: 200, width: 1, height: 1))
        press("j")                                                           // a verse selected in the suite's window
        let range = controller.textView.selectedRange()
        #expect(controller.versePanelAnchor(for: range) == (try #require(controller.frameOfFirstSegment(of: range))))
    }

    /// The popover for a request, in the suite's window: a transient system popover of the panel, no
    /// larger than the panel's limits, left alone by the same request, replaced by a new one without the
    /// first's `onClose`, and taken away by nil. While it is up no reader key acts on the verse behind it;
    /// Esc, or AppKit's close (a click outside), closes it as the reader's close, which alone calls `onClose`.
    /// The suite's window is never put on the screen, so AppKit cannot show the popover here: the
    /// controller's `presentVersePanel` seam says it is up without the screen, and once with a show that
    /// failed. Whether it is on the screen, and where, is the live pass's to see.
    @Test func theVersePanelShowsForARequestAndClosesForNil() async throws {
        _ = window
        var shows: [NSRect] = []
        controller.presentVersePanel = { _, anchor, view in
            shows.append(anchor)
            return view === self.controller.textView
        }
        press("j")
        let report = try #require(controller.reportForAction())
        var closes: [String] = []
        func presentation(_ request: VersePanelRequest, _ name: String) -> VersePanelPresentation {
            VersePanelPresentation(request: request, content: AnyView(CompareTranslationsPanel(
                selection: request.selection, navigation: navigation, onOpen: { _ in }, onAsk: nil)), onClose: { closes.append(name) })
        }
        let first = VersePanelRequest(kind: .compare, report: report)
        controller.apply(presentation(first, "first"))
        let panel = try #require(controller.versePanel)
        #expect(panel.requestID == first.id && panel.popover.behavior == .transient && panel.popover.delegate === panel)
        let size = try #require(panel.popover.contentViewController?.view.fittingSize)
        #expect(size.width > 300 && size.width <= 360.5 && size.height > 0 && size.height <= 480.5)
        #expect(panel.isUp && shows == [controller.versePanelAnchor(for: report.range)])
        controller.apply(presentation(first, "again"))
        #expect(controller.versePanel === panel && shows.count == 1)           // the same request: left alone
        // While it is up: a colour, N, B, J, C and the arrows do nothing to the verse behind it.
        for key in ["1", "b", "n", "j", "c"] { press(key) }
        press(keyCode: 124)
        #expect(model.items.isEmpty && model.bookmarkVerses.isEmpty && selected == 1...1 && navigation.location == ChapterLocation(book: "MAT", chapter: 2))
        let second = VersePanelRequest(kind: .crossReferences, report: report)
        controller.apply(presentation(second, "second"))
        let replacing = try #require(controller.versePanel)
        #expect(replacing !== panel && replacing.requestID == second.id)
        controller.apply(nil as VersePanelPresentation?)
        #expect(controller.versePanel == nil)
        await mainQueueTurn()
        #expect(closes.isEmpty)                                              // neither was the reader's close
        // Esc, as the reader closes it: `onClose`, once, and the selection stays; the keys act again at
        // once, before the view's `apply(nil)` arrives.
        controller.apply(presentation(VersePanelRequest(kind: .compare, report: report), "third"))
        press(keyCode: 53)
        #expect(selected == 1...1 && controller.versePanel?.isUp == false)
        press("j")
        await mainQueueTurn()
        #expect(closes == ["third"] && selected == 2...2)
        // AppKit's own close (Esc in the popover, a click outside) does the same.
        controller.apply(presentation(VersePanelRequest(kind: .crossReferences, report: report), "fourth"))
        let shown = try #require(controller.versePanel)
        shown.popoverDidClose(Notification(name: NSPopover.didCloseNotification, object: shown.popover))
        await mainQueueTurn()
        #expect(closes == ["third", "fourth"])
        // A show that did not put it up: closed as the reader's close, so the request clears, and no key is dead.
        controller.presentVersePanel = { _, _, _ in false }
        controller.apply(presentation(VersePanelRequest(kind: .compare, report: report), "fifth"))
        #expect(controller.versePanel?.isUp == false)
        press("k")
        await mainQueueTurn()
        #expect(closes == ["third", "fourth", "fifth"] && selected == 1...1)
    }

    /// The reader keeps the keyboard: presenting a panel never moves the reader window's first responder
    /// off the text view (the popover's keyboard is in its own window). However it goes down
    /// (`apply(nil)` for a row, Open, Ask or the chapter changing; Esc; AppKit's close; a show that
    /// failed) the text view takes the keyboard back by `ReaderFocusRule`, on the next turn, from a
    /// view that is not a field, and the reader's keys act; a field being typed in (the composer Ask
    /// focuses, a note's editor) keeps it. Then the reader's window is made key again, whatever holds
    /// its keyboard (the composer Ask focused is in the same window), but never while another panel is
    /// up. After the reader's own close, a click outside that moved the window's keyboard (a row of
    /// the notes column) keeps it, and nothing is handed back.
    @Test func theReaderHasTheKeyboardWhileAndAfterAVersePanel() async throws {
        let window = self.window
        controller.presentVersePanel = { _, _, _ in true }
        var keyed = 0
        controller.makeReaderWindowKey = { made, _ in
            #expect(made === window)
            keyed += 1
        }
        press("j")
        let report = try #require(controller.reportForAction())
        func present() {
            controller.apply(VersePanelPresentation(request: VersePanelRequest(kind: .compare, report: report),
                                                    content: AnyView(Text("Panel")), onClose: {}))
        }
        window.makeFirstResponder(controller.textView)
        present()
        await mainQueueTurn()
        #expect(window.firstResponder === controller.textView)              // presenting leaves the reader's window alone
        #expect(keyed == 0)
        controller.apply(nil as VersePanelPresentation?)
        await mainQueueTurn()
        keyed = 0
        /// `heldWhenUp` holds the window's keyboard as the panel goes up; `heldAtClose`, if given, takes
        /// it while the panel is up (a field Ask focused, a click outside on a notes row).
        func goesDown(_ route: String, heldWhenUp: NSResponder, heldAtClose: NSResponder? = nil, keeps: Bool, keys: Bool,
                      _ close: () -> Void) async {
            window.makeFirstResponder(heldWhenUp)
            present()
            if let heldAtClose { window.makeFirstResponder(heldAtClose) }
            let holder = heldAtClose ?? heldWhenUp
            keyed = 0
            close()
            await mainQueueTurn()
            await mainQueueTurn()
            #expect(window.firstResponder === (keeps ? holder : controller.textView), "\(route)")
            #expect(keyed == (keys ? 1 : 0), "\(route): the window made key \(keyed) times")
            controller.apply(nil as VersePanelPresentation?)
            await mainQueueTurn()
            await mainQueueTurn()
        }
        let appKitClose = {
            let panel = self.controller.versePanel!
            panel.popoverDidClose(Notification(name: NSPopover.didCloseNotification, object: panel.popover))
        }
        let takenAway = { self.controller.apply(nil as VersePanelPresentation?) }
        await goesDown("apply(nil)", heldWhenUp: other, keeps: false, keys: true, takenAway)
        await goesDown("apply(nil), the reader's text", heldWhenUp: controller.textView, keeps: false, keys: true, takenAway)
        await goesDown("Esc", heldWhenUp: other, keeps: false, keys: true) { press(keyCode: 53) }
        await goesDown("AppKit's close", heldWhenUp: other, keeps: false, keys: true, appKitClose)
        await goesDown("apply(nil), a field typing", heldWhenUp: controller.textView, heldAtClose: field, keeps: true, keys: true, takenAway)
        await goesDown("AppKit's close, a field typing", heldWhenUp: field, keeps: true, keys: true, appKitClose)
        await goesDown("AppKit's close, a click on a row", heldWhenUp: controller.textView, heldAtClose: other, keeps: true, keys: false, appKitClose)
        // Taken away and another panel up before the turn: the window is not made key under it.
        window.makeFirstResponder(controller.textView)
        present()
        keyed = 0
        controller.apply(nil as VersePanelPresentation?)
        present()
        await mainQueueTurn()
        await mainQueueTurn()
        #expect(keyed == 0 && controller.versePanel?.isUp == true)
        controller.apply(nil as VersePanelPresentation?)
        await mainQueueTurn()
        await mainQueueTurn()
        // A show that failed goes down as it is presented.
        controller.presentVersePanel = { _, _, _ in false }
        window.makeFirstResponder(other)
        present()
        await mainQueueTurn()
        #expect(window.firstResponder === controller.textView && controller.versePanel?.isUp == false)
        // The keys act at once: J moves the selection, R asks for its panel.
        var asked: [VersePanelKind] = []
        model.onVersePanel = { kind, _ in asked.append(kind) }
        controller.apply(nil as VersePanelPresentation?)
        press("j")
        press("r")
        #expect(selected == 2...2 && asked == [.crossReferences])
    }

    /// The popover hangs from its verses' first line, so it closes, as the reader's close, when the page
    /// moves under it (a scroll) or is laid out again (a text size or page style, the notes column, the
    /// window resized). Opening it moves nothing, and the keys' reveal still running from before it
    /// opened (J, then C at once) carries it along with the line. The popover's own content (a passage
    /// shown in place) is not the reader's layout and never reaches these paths.
    @Test func aVersePanelClosesWhenItsPageMovesOrIsLaidOutAgain() async throws {
        _ = window
        useSixty()
        controller.presentVersePanel = { _, _, _ in true }
        select(10)
        let report = try #require(controller.reportForAction())
        var closes: [String] = []
        func present(_ name: String) {
            controller.apply(VersePanelPresentation(request: VersePanelRequest(kind: .compare, report: report),
                                                    content: AnyView(Text("Panel")), onClose: { closes.append(name) }))
        }
        func goesAway() async {
            await mainQueueTurn()
            controller.apply(nil as VersePanelPresentation?)
            await mainQueueTurn()
        }
        var isUp: Bool { controller.versePanel?.isUp == true }
        present("scrolled")
        await mainQueueTurn()
        #expect(isUp)                                                         // opening moves nothing
        let y = controller.scrollView.contentView.bounds.minY
        controller.keyScroll = (from: y, to: y + 120)                         // J's reveal, begun before it opened
        controller.keyScrollDeadline = Date().addingTimeInterval(10)
        scrollByHand(toY: y + 60)
        scrollByHand(toY: y + 120)
        #expect(isUp)                                                         // the live pass sees it follow its line
        scrollByHand(toY: y + 200)                                            // the reader's own scroll
        #expect(!isUp)
        await goesAway()
        #expect(closes == ["scrolled"])
        // A larger text size: the page is laid out again.
        present("text size")
        var preferences = ReaderPreferences.default
        preferences.fontSize += 4
        let larger = ReaderTypography.styled(preferences)
        controller.update(layout: F.layout(F.verses(count: 60), typography: larger), typography: larger, scrollTarget: nil, decorations: .none)
        #expect(!isUp)
        await goesAway()
        // The column narrower (the notes column opening, the window resized): reflowed.
        present("narrower")
        controller.scrollView.setFrameSize(NSSize(width: 420, height: 300))
        (controller.textView as? ColumnTextView)?.flushPendingReflow()
        #expect(!isUp)
        await goesAway()
        // Wider than the measure, twice: the second only recentres the column, which moves the line.
        controller.scrollView.setFrameSize(NSSize(width: 1100, height: 300))
        (controller.textView as? ColumnTextView)?.flushPendingReflow()
        present("recentred")
        controller.scrollView.setFrameSize(NSSize(width: 1300, height: 300))
        (controller.textView as? ColumnTextView)?.flushPendingReflow()
        #expect(!isUp)
        await goesAway()
        #expect(closes == ["scrolled", "text size", "narrower", "recentred"])
    }

    /// AppKit's part of the hand-back: the reader's window takes key status only while the app is
    /// active, the window is on screen and not key, and the key window is none or the closing popover's.
    @Test func theReadersWindowTakesKeyOnlyFromNoneOrTheClosingPopover() {
        let popover = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
        let another = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
        defer { popover.close(); another.close() }
        popover.isReleasedWhenClosed = false
        another.isReleasedWhenClosed = false
        func takes(active: Bool = true, visible: Bool = true, key: Bool = false, keyWindow: NSWindow?, closing: NSWindow? = nil) -> Bool {
            ChapterTextController.takesKey(appIsActive: active, isVisible: visible, isKey: key, keyWindow: keyWindow, closingPopover: closing)
        }
        #expect(takes(keyWindow: nil) && takes(keyWindow: popover, closing: popover))
        #expect(!takes(keyWindow: another, closing: popover) && !takes(keyWindow: popover))
        #expect(!takes(active: false, keyWindow: nil) && !takes(visible: false, keyWindow: nil) && !takes(key: true, keyWindow: nil))
    }

    /// C then R without closing: the second request replaces the first, and the first panel's late
    /// close (AppKit posts it after its animation) neither hands the keyboard back nor touches the second.
    @Test func aReplacedPanelsLateCloseLeavesTheNewOneAlone() async throws {
        let window = self.window
        controller.presentVersePanel = { _, _, _ in true }
        press("j")
        let report = try #require(controller.reportForAction())
        var closes: [String] = []
        func present(_ kind: VersePanelKind) {
            controller.apply(VersePanelPresentation(request: VersePanelRequest(kind: kind, report: report),
                                                    content: AnyView(Text("Panel")), onClose: { closes.append(kind.rawValue) }))
        }
        present(.compare)
        let first = try #require(controller.versePanel)
        present(.crossReferences)
        let second = try #require(controller.versePanel)
        window.makeFirstResponder(other)                                        // the keyboard is not the reader's while R's panel is up
        first.popoverDidClose(Notification(name: NSPopover.didCloseNotification, object: first.popover))
        await mainQueueTurn()
        #expect(second !== first && controller.versePanel === second && second.isUp)
        #expect(window.firstResponder === other && closes.isEmpty)
    }

    // MARK: - The model's selection

    /// The assistant asks about `model.currentSelection`: after a chapter turn it must not be a
    /// verse of the chapter turned from.
    @Test func anotherChapterLeavesTheModelNoSelection() async {
        select(2)
        #expect(model.currentSelection != nil)
        show(F.layout(F.verses(chapter: 6, count: 5)))
        await mainQueueTurn()
        #expect(model.currentSelection == nil)
    }

    /// Waits for what is already queued on the main queue (the controller's reports made inside
    /// an update) to run. A run-loop turn cannot: the test itself is running on the main queue.
    private func mainQueueTurn() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }
}
#endif
