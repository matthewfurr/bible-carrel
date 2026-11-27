# Milestone 10, Project 1: Verse Basics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tap (iPhone) or a click (Mac) selects a whole verse, single keys on the Mac act on it, a sheet lists every shortcut, `bible://` links open and copy passages, the Notes window's selected row reads clearly, and an About page credits every outside source.

**Architecture:** A selected verse is an ordinary text selection, so nothing new is drawn and every existing action already acts on it.
- The verse rules (which verse a point is on, the next and previous verse, growing by a verse) are pure functions on `BookLayout` beside `ReaderTextLogic`; both text controllers call them.
- One `ShortcutCatalog` in code feeds the Mac reader's key handling and the shortcuts sheet.
- `PassageLink` in ScriptureData parses and formats links; opening one is `NavigationModel.lookUp`.
- `Credits` is one catalogue behind one `AboutView` on both apps.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit and UIKit, TextKit 2, GRDB, SwiftData, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-16-milestone-10-verse-basics-design.md`. Read it with this plan; section numbers below are the spec's.

Paths: `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `SD` is `Packages/ScriptureKit/Sources/ScriptureData`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `TD` is `Packages/ScriptureKit/Tests/ScriptureDataTests`, `MAC` is `Apps/Mac/ReadingThroughScripture`.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-10-study-tools`, on branch `milestone-10-study-tools`. Never push or merge.
- Git: `/usr/bin/git`, one git command per Bash call, no `cd … &&`, loops or shell variables.
- Every commit message ends with the line `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>` (pass it as a second `-m`).
- `rtk` shortens command output; use `rtk proxy <command>` when all of it is needed.

**Matt's data**
- Never touch the Release app, `Scripts/install-app.sh`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. Never build or run the Release configuration; read its settings with `-showBuildSettings` only.
- The `.dev` store gets no test notes. In the Mac Debug app and the simulator, never press 1 to 9, 0, N or B on a selection and never choose a colour, Add Note or Bookmark. Those are covered by tests and by Matt's own list.
- No test touches iCloud, the Keychain, the network or Matt's stores.
- `Scripts/install-phone.sh debug` is run by the controller, never by a task's implementer.

**Commands**
- Package tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (add `--filter <Suite>` for one suite).
- iOS tests: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests` (append `/<Suite>` for one suite).
- Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
- iOS Debug build: the same with `-scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'`.
- Run builds and test runs one after another; they share `Build/DerivedData`.
- Quit the Mac Debug app only with `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`, then `open` it. Never `pkill -x`.
- Which suite a test file runs in: a file under `#if os(macOS)` runs in the package suite only, one under `#if os(iOS)` in the iOS suite only, any other `T` file in both. `TD` files run in the package suite only.

**Code rules**
- TextKit 2 only; never touch `textView.layoutManager`.
- Swift Testing: `#expect` cannot contain a mutating call; mutate on the line before.
- Deletes stay undoable through the window's `UndoManager`; the reader never asks for confirmation.
- Nothing stored changes: no new records, no new fields, no iCloud schema change.

**UI rules (CLAUDE.md, DESIGN.md)**
- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change; use the `/impeccable-swift` skill for the sheet, the Notes row and About.
- Palette tokens only (`Color.inkSecondary`, `Palette.accent.platformColor`); every new pairing goes in `PaletteTests`.
- Semantic text styles only; sizes tied to text are `@ScaledMetric`; spacing and radii are `AppSpacing` and `AppRadius` by name.
- No card by reflex, no new shadow, no new material, no `.glassEffect()`. The shortcuts sheet is the system's sheet.
- UI copy keeps the app's American spelling ("No Color", "License"), whatever the spec's prose uses.

**Seeing the UI**
- Use the recipes in `docs/superpowers/specs/2026-11-13-milestone-9-handover.md`, "How to see the UI without stalling": the iOS Simulator control tool on the Debug simulator app; on the Mac, `screencapture -x -o -l<id>` of the Debug app's own window, in the background.
- AeroSpace may keep a window out of reach. Do not move Matt's windows; say what could not be seen.
- Pictures go in the session scratchpad. A temporary snapshot test is removed before committing.

## Review Focus

1. **A tap or click in the leading between two lines of one verse** (worst at Relaxed line spacing). The reader expects the verse; hit rects taken from the painted glyph rects leave a dead band between lines. The verse's lines are tested at their full line height. Pinned in Task 2 (`everyPointDownAVersesLinesIsThatVerse`) and Task 3 (`everyPointDownAVersesLinesIsThatVerse`).
2. **A selection or caret left off screen, then J or K.** The reader clicked verse 3 an hour ago, scrolled to verse 40 and presses J: they expect verse 40, not a jump back. A selection with no part on screen counts as nothing selected. Pinned in Task 4 (`jFromASelectionScrolledOutOfViewStartsAtTheFirstVerseOnScreen`). **(call, record in the spec's As built)**
3. **A link the URL parser mangles**: `bible://John%203:16` (":16" reads as a port), `BIBLE://JHN.3.16`, a trailing slash, a fragment, and a link at the end of a sentence in a note. Each opens its passage. Pinned in Task 6 (`linksTheSystemsParserWouldMangleStillParse`) and Task 8 (`aLinkAtTheEndOfASentenceLeavesTheFullStopOut`).
4. **Reader keys with Caps Lock on, from the numeric keypad, or with ⌘, ⌥ or ⌃ held.** J still moves with Caps Lock on; a keypad 1 colours; ⌘1 and ⌥J are not reader keys. Pinned in Task 4 (`capsLockAndTheKeypadStillReachTheReaderKeys`, `modifiedKeysAreNotReaderKeys`).
5. **A link arriving while something covers the page** (phone: a sheet or Library; Mac: the palette or the shortcuts sheet). The passage shows, not hidden under it. Pinned in Task 7 (`aLinkClosesThePaletteAndTheShortcutsSheet`, and the simulator step that opens a link over Settings).

---

### Task 1: Shared verse logic

**Files:**
- Create: `SUI/ReaderVerseLogic.swift` (an `extension ReaderTextLogic`)
- Test: create `T/ReaderVerseLogicTests.swift` (no platform guard: both suites)

**Interfaces:**
- Consumes: `BookLayout.span(for:)`, `BookLayout.section(for:)`, `VerseSpan.textRange`, `VerseSpan.fullRange` (`SUI/BookLayout.swift:217-246`, `SUI/ChapterLayout.swift:13-38`).
- Produces:

```swift
/// J or ⇧J (`next`), K or ⇧K (`previous`).
public enum VerseStep: Sendable { case next, previous }

extension ReaderTextLogic {
    /// The verses of one chapter a selection touches. A range: every span whose number or text it
    /// intersects, kept to the first one's chapter. A caret: the one span whose number or text it
    /// is in or at the end of (the span starting at the caret wins over the one ending there).
    public static func verses(touching selection: NSRange, in layout: BookLayout) -> [VerseSpan]

    /// The verse a tap or click that resolved to `index` is on: the span containing `index`, else
    /// the span ending at `index`, the first for which `isOnLines` holds.
    public static func verse(at index: Int, in layout: BookLayout, isOnLines: (VerseSpan) -> Bool) -> VerseSpan?

    /// J and K: the text range of the verse after the selection's last verse, or before its first.
    /// With no verse touched (`selection` nil, or a caret in an opening or a heading), the text
    /// range of `firstVisible`. Nil at the chapter's last or first verse.
    public static func verseStep(_ step: VerseStep, from selection: NSRange?, firstVisible: VerseLocation?,
                                 in layout: BookLayout) -> NSRange?

    /// ⇧J and ⇧K: the selection with its free end moved one verse, as Shift and an arrow key do in
    /// a list. `anchor` is a character index in the verse that stays selected (nil: the first
    /// touched verse for `next`, the last for `previous`). Returns whole verses, from the first
    /// one's `textRange` start to the last one's end, and the anchor to keep. With no verse
    /// touched it is `verseStep`. Nil when the free end cannot move within the chapter.
    public static func verseExtension(_ step: VerseStep, of selection: NSRange?, anchor: Int?,
                                      firstVisible: VerseLocation?, in layout: BookLayout) -> (range: NSRange, anchor: Int)?
}
```

- [ ] **Step 1: Write the failing tests.** Fixture: `Self.book(…)` builds Psalm 3 with five one-sentence verses as `ReaderTextLogicTests.book(_:)` does, in a given typography, or with verses 2 and 3 combined; `layout` is the plain one. `t(n)` is verse n's `textRange`; `joined(a, b)` runs from `t(a).location` to `NSMaxRange(t(b))`; `psa(n)` is `VerseLocation(book: "PSA", chapter: 3, verse: n)`.

```swift
@Test func aCaretFindsItsVerseByItsNumberItsWordsAndItsEnd() {
    let span = layout.spans[1]
    for index in [span.numberRange.location, span.textRange.location + 2, NSMaxRange(span.textRange)] {
        #expect(ReaderTextLogic.verses(touching: NSRange(location: index, length: 0), in: layout) == [span])
    }
    #expect(ReaderTextLogic.verses(touching: NSRange(location: 0, length: 0), in: layout).isEmpty)   // the opening
    #expect(ReaderTextLogic.verses(touching: NSRange(location: NSNotFound, length: 0), in: layout).isEmpty)
}

@Test func aVerseIsFoundOnlyOnItsLines() {
    let span = layout.spans[2]
    #expect(ReaderTextLogic.verse(at: span.textRange.location + 1, in: layout) { _ in true } == span)
    #expect(ReaderTextLogic.verse(at: NSMaxRange(span.textRange), in: layout) { $0 == span } == span)   // its last letter's far half
    #expect(ReaderTextLogic.verse(at: span.textRange.location + 1, in: layout) { _ in false } == nil)
    #expect(ReaderTextLogic.verse(at: 0, in: layout) { _ in true } == nil)
}

@Test func jAndKStepFromTheSelectionsLastAndFirstVerse() {
    #expect(ReaderTextLogic.verseStep(.next, from: t(2), firstVisible: psa(1), in: layout) == t(3))
    #expect(ReaderTextLogic.verseStep(.previous, from: t(2), firstVisible: psa(1), in: layout) == t(1))
    #expect(ReaderTextLogic.verseStep(.next, from: joined(2, 3), firstVisible: nil, in: layout) == t(4))
    #expect(ReaderTextLogic.verseStep(.previous, from: joined(2, 3), firstVisible: nil, in: layout) == t(1))
    // A caret in verse 2 (after a colour collapsed the selection) carries on from verse 2.
    #expect(ReaderTextLogic.verseStep(.next, from: NSRange(location: t(2).location, length: 0), firstVisible: psa(5), in: layout) == t(3))
    // A partial selection steps by whole verses.
    #expect(ReaderTextLogic.verseStep(.next, from: NSRange(location: t(2).location + 1, length: 3), firstVisible: nil, in: layout) == t(3))
}

@Test func withNothingSelectedBothStartAtTheFirstVerseOnScreen() {
    for step in [VerseStep.next, .previous] {
        #expect(ReaderTextLogic.verseStep(step, from: nil, firstVisible: psa(4), in: layout) == t(4))
        #expect(ReaderTextLogic.verseStep(step, from: NSRange(location: 0, length: 0), firstVisible: psa(4), in: layout) == t(4))
        #expect(ReaderTextLogic.verseStep(step, from: nil, firstVisible: nil, in: layout) == nil)
    }
}

@Test func nothingHappensAtTheChaptersEnds() {
    #expect(ReaderTextLogic.verseStep(.next, from: t(5), firstVisible: psa(1), in: layout) == nil)
    #expect(ReaderTextLogic.verseStep(.previous, from: t(1), firstVisible: psa(1), in: layout) == nil)
    #expect(ReaderTextLogic.verseExtension(.next, of: t(5), anchor: nil, firstVisible: nil, in: layout) == nil)
}

@Test func shiftGrowsAndShrinksFromTheAnchorLikeAList() {
    let down = ReaderTextLogic.verseExtension(.next, of: t(2), anchor: nil, firstVisible: nil, in: layout)
    #expect(down?.range == joined(2, 3) && down?.anchor == t(2).location)
    let further = ReaderTextLogic.verseExtension(.next, of: joined(2, 3), anchor: t(2).location, firstVisible: nil, in: layout)
    #expect(further?.range == joined(2, 4))
    let back = ReaderTextLogic.verseExtension(.previous, of: joined(2, 4), anchor: t(2).location, firstVisible: nil, in: layout)
    #expect(back?.range == joined(2, 3))
    let toAnchor = ReaderTextLogic.verseExtension(.previous, of: joined(2, 3), anchor: t(2).location, firstVisible: nil, in: layout)
    #expect(toAnchor?.range == t(2))
    let above = ReaderTextLogic.verseExtension(.previous, of: t(2), anchor: t(2).location, firstVisible: nil, in: layout)
    #expect(above?.range == joined(1, 2) && above?.anchor == t(2).location)
    // With nothing selected it selects the first verse on screen, as J does.
    #expect(ReaderTextLogic.verseExtension(.next, of: nil, anchor: nil, firstVisible: psa(3), in: layout)?.range == t(3))
}

@Test func aCombinedVerseIsOneStep() {
    // Verse 2 is "2-3" (`Verse.endVerse == 3`), then verse 4.
    let combined = Self.book(combiningTwoAndThree: true)
    let spans = combined.spans
    #expect(ReaderTextLogic.verseStep(.next, from: spans[0].textRange, firstVisible: nil, in: combined) == spans[1].textRange)
    #expect(ReaderTextLogic.verseStep(.next, from: spans[1].textRange, firstVisible: nil, in: combined) == spans[2].textRange)
    #expect(ReaderTextLogic.verseStep(.next, from: nil, firstVisible: VerseLocation(book: "PSA", chapter: 3, verse: 3), in: combined) == spans[1].textRange)
}

@Test func aVerseWithoutItsNumberIsStillFound() {
    // Lectern removes verse 1's number (`BookLayout.removeVerseOneNumber`).
    var prefs = ReaderPreferences.default
    prefs.style = .lectern
    let lectern = Self.book(typography: ReaderSettings.typography(prefs))
    let first = lectern.spans[0]
    #expect(ReaderTextLogic.verses(touching: NSRange(location: first.textRange.location, length: 0), in: lectern) == [first])
    #expect(ReaderTextLogic.verseStep(.previous, from: lectern.spans[1].textRange, firstVisible: nil, in: lectern) == first.textRange)
}
```

- [ ] **Step 2: Run them.** `swift test … --filter ReaderVerseLogicTests` must FAIL to compile: `VerseStep` and the four functions are undefined.
- [ ] **Step 3: Implement the four functions in `SUI/ReaderVerseLogic.swift`.** The free end in `verseExtension`: the anchor's span is the touched span whose `fullRange` holds `anchor`; the free end is the last touched span when the anchor's is the first (or the only one), else the first; it moves one span in the step's direction within `layout.section(for:)` of the anchor's chapter.
- [ ] **Step 4: Run them.** `--filter ReaderVerseLogicTests` passes, then the whole package suite passes.
- [ ] **Step 5: Commit.** `/usr/bin/git add` the two files, then `/usr/bin/git commit -m "feat: the verse rules both readers share (verse basics 1)" -m "Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>"`. Every later commit step has this shape.

---

### Task 2: iPhone, a tap selects the verse (spec 4)

**Files:**
- Modify: `SUI/Phone/PhoneChapterTextController.swift` (recognisers `:180-190` and `:334-354`; `highlight(at:)`, the tap handlers and `openHighlight` `:1290-1348`; the gesture delegate `:1371-1433`; `ownGestures` `:1497`)
- Test: `T/PhoneChapterTextControllerTests.swift` (iOS suite only)

**Decision: a new recogniser, `verseTap`, not the away-tap path.** Two reasons from the delegate code:
- The away tap "runs alongside everything" (`:1410-1414`), so the text view's own single tap would run with it and clear the selection just made. That is why `highlightTap` makes the text view's taps wait for it to fail (`:1416-1433`); `verseTap` takes the same rule.
- `verseTap` begins only where a verse tap applies (`gestureRecognizerShouldBegin`, `:1371-1379`). Everywhere else (margins, headings, the cards open, the pen on, a scroll being stopped) no existing path changes.

**Interfaces:**
- Consumes: `ReaderTextLogic.verse(at:in:isOnLines:)` (Task 1).
- Produces (all on `PhoneChapterTextController`, internal):

```swift
/// What a touch looked like as it came down; the verse tap's rules read it at touch-up.
struct VerseTapTouch: Equatable {
    var tapCount = 1            // UITouch.tapCount: 2 for the second tap of a double tap
    var pageWasMoving = false   // textView.isDragging || textView.isDecelerating
    var cardsWereOpen = false   // openSwitcherEdge != nil
}

var isVoiceOverRunning: () -> Bool = { UIAccessibility.isVoiceOverRunning }
var verseTapRecognizer: UITapGestureRecognizer { get }
/// How many times the edit menu has been presented at a selection (a highlight's or a verse's).
private(set) var menuPresentations = 0

/// Whether `point` (text-view coordinates) is on one of the verse's laid-out lines: horizontally
/// within the verse's painted segment on that line (`segmentFrames` of its `fullRange`: number and
/// words, trailing white space left out), vertically within that line fragment's whole
/// typographic height (`lineFrame(forCharacterIndex:)`), both outset by `outlineMargin`.
func isOnLines(_ span: VerseSpan, at point: CGPoint) -> Bool

/// The page's state for a touch coming down now; the delegate's `shouldReceive` records it.
func verseTapTouch(tapCount: Int) -> VerseTapTouch

/// The verse a tap at `point` selects, or nil when it is not a verse tap.
func verseForTap(at point: CGPoint, touch: VerseTapTouch) -> VerseSpan?

/// The recogniser's action: selects the verse's `textRange`, reports it and presents the menu.
func verseTapped(at point: CGPoint, touch: VerseTapTouch)
```

`verseForTap` returns nil when any of these holds, checked in this order: no layout; the pen is on; `isVoiceOverRunning()`; `touch.tapCount != 1`; `touch.pageWasMoving`; `touch.cardsWereOpen`; `!awayTapMayAct` (the thumb claimed the touch); `isInThumbZone(point)`; `highlight(at: point) != nil`. Otherwise it is `ReaderTextLogic.verse(at:in:isOnLines:)` for the index `textView.closestPosition(to:)` gives.

- [ ] **Step 1: Write the failing tests.** Add to `PhoneChapterTextControllerTests`. Helpers:
  - `page` is `F.Harness(width: 390, height: 700)` showing `layout`, `F.book(3...3, counts: [3: 12])`.
  - `span(n)` is `layout.span(for: at(3, n))`; `words(n)` is the centre of `page.controller.rect(for:)` of verse n's first three text characters; `endOfFirstLine(n)` is a point on its first line past the highlight.
  - `tap(point)` calls `page.controller.verseTapped(at: point, touch: VerseTapTouch())`; `hit(point, touch)` is `page.controller.verseForTap(at:touch:)`, the touch a plain `VerseTapTouch()` unless given.
  - `relaxed` is a second page's controller showing the chapter in Relaxed line spacing (`prefs.lineSpacing = .relaxed`, `ReaderSettings.typography(prefs)`), and `verseOne` its first span.

```swift
@Test func aTapOnAVerseSelectsItsTextAndPresentsTheMenu() throws {
    var reports: [SelectionReport?] = []
    page.controller.onSelectionChange = { reports.append($0) }
    tap(try words(4))
    let span = try #require(span(4))
    #expect(page.textView.selectedRange == span.textRange)          // the words, not the number
    #expect(reports.last??.selection.verse == 4 && reports.last??.selection.endVerse == 4)
    #expect(reports.last??.selection.startOffset == 0 && reports.last??.selection.endOffset == span.textRange.length)
    #expect(page.controller.menuPresentations == 1)
    let number = try #require(page.controller.rect(for: span.numberRange))
    #expect(hit(CGPoint(x: number.midX, y: number.midY)) == span)   // its number too
}

@Test func aTappedVersesMenuIsTheHandSelectionsMenu() throws {
    var asked: [SelectionReport] = []
    page.controller.menuProvider = { asked.append($0); return UIMenu(children: []) }
    tap(try words(4))
    _ = page.controller.textView(page.textView, editMenuForTextIn: page.textView.selectedRange, suggestedActions: [])
    page.textView.selectedRange = NSRange(location: 0, length: 0)
    page.textView.selectedRange = try #require(span(4)).textRange            // by hand
    _ = page.controller.textView(page.textView, editMenuForTextIn: page.textView.selectedRange, suggestedActions: [])
    #expect(asked.count == 2 && asked[0] == asked[1])
}

@Test func aTapOnAnotherVerseMovesTheSelectionAndTheSameVerseShowsTheMenuAgain() throws {
    tap(try words(4))
    tap(try words(6))
    tap(try words(6))
    #expect(page.textView.selectedRange == span(6)?.textRange && page.controller.menuPresentations == 3)
}

@Test func aTapOffTheTextIsNotAVerseTap() throws {
    // Chapter 1 with a heading before verse 3: the margin beside a line, the title block, the heading, below the last line.
    for point in try offTextPoints() { #expect(hit(point) == nil, "\(point)") }
}

@Test func everyPointDownAVersesLinesIsThatVerse() throws {
    // Verse 1 opens the chapter, so each of its lines starts at the column's edge.
    let first = try #require(relaxed.rect(for: NSRange(location: verseOne.textRange.location, length: 1)))
    let last = try #require(relaxed.rect(for: NSRange(location: NSMaxRange(verseOne.textRange) - 1, length: 1)))
    #expect(last.minY > first.maxY, "the verse wraps")
    for y in stride(from: first.minY, through: last.maxY, by: 1) {
        #expect(relaxed.verseForTap(at: CGPoint(x: first.minX + 4, y: y), touch: VerseTapTouch()) == verseOne, "y \(y)")
    }
}

@Test func aTapOnAHighlightIsNotAVerseTap() throws {
    // A highlight on verse 4's first nine characters; the rest of the verse is still a verse tap.
    #expect(hit(try words(4)) == nil)
    #expect(hit(try endOfFirstLine(4)) == span(4))
}

@Test func theRulesThatMakeATapNotAVerseTap() throws {
    let point = try words(4)
    #expect(hit(point, VerseTapTouch(tapCount: 2)) == nil)            // a double tap's second
    #expect(hit(point, VerseTapTouch(pageWasMoving: true)) == nil)    // it stopped a scroll
    #expect(hit(point, VerseTapTouch(cardsWereOpen: true)) == nil)    // it closes the cards
    page.controller.isVoiceOverRunning = { true }
    #expect(hit(point) == nil)
    page.controller.isVoiceOverRunning = { false }
    page.controller.setPen(isOn: true, color: .systemYellow, selectedID: nil)
    #expect(hit(point) == nil)
    page.controller.setPen(isOn: false, color: .systemYellow, selectedID: nil)
    #expect(hit(try line(page, layout: layout, verse: 4, x: page.textView.bounds.width - 10)) == nil)   // the thumb's zone
    #expect(hit(point) == span(4))
}

@Test func aTapWhileTheCardsAreOpenSelectsNothing() throws {
    // `SwitcherPage(atEnd: true)` pulled open, as `theCardsStayUntilThePageIsTapped` does.
    let touch = s.controller.verseTapTouch(tapCount: 1)             // as the touch comes down
    #expect(s.controller.openSwitcherEdge == .bottom && touch.cardsWereOpen && !touch.pageWasMoving)
    s.controller.closeSwitcher(animated: false)                     // the away tap, at touch-up
    s.controller.verseTapped(at: try wordsOnScreen(), touch: touch)
    #expect(s.text.selectedRange.length == 0 && s.controller.menuPresentations == 0)
    #expect(!s.controller.verseTapTouch(tapCount: 1).cardsWereOpen)
}

@Test func theVerseTapActsAtOnceAndLeavesTheDoubleTapToTheSystem() throws {
    let tap = page.controller.verseTapRecognizer
    let own = page.controller.ownGestures
    #expect(tap.numberOfTapsRequired == 1 && own.contains { $0 === tap })
    for other in page.textView.gestureRecognizers ?? [] where !own.contains(where: { $0 === other }) {
        // It waits for nothing, so a single tap never waits to see whether a second follows.
        #expect(!page.controller.gestureRecognizer(tap, shouldRequireFailureOf: other))
        // The text view's single taps wait for it; its double tap does not.
        let single = (other as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
        #expect(page.controller.gestureRecognizer(tap, shouldBeRequiredToFailBy: other) == single)
    }
}

@Test func aMarginMarkIsNotAVerseTap() throws {
    // As `aTapOnAMarginMarkStillActsOnTheMark`: the mark is the view hit at its centre.
    #expect(page.textView.hitTest(centre, with: nil) === bookmark && hit(centre) == nil)
}
```

- [ ] **Step 2: Run them.** iOS command with `-only-testing:ScriptureUITests/PhoneChapterTextControllerTests`; they FAIL to compile (`VerseTapTouch`, `verseForTap`, `verseTapped`, `menuPresentations` undefined).
- [ ] **Step 3: Implement.**
  - Add `private let verseTap = UITapGestureRecognizer()` beside `highlightTap`, wired like it in `init`, and add it to `ownGestures`.
  - `gestureRecognizer(_:shouldReceive:)`: for `verseTap`, refuse a touch whose view is a `PenHandleView` or a `UIControl` (the margin marks, the chapter-note mark); otherwise store `verseTapTouch(tapCount: touch.tapCount)` for the action to read. The touch's state is taken as it comes down because the away tap closes the cards at touch-up, in no fixed order with this tap.
  - `gestureRecognizerShouldBegin`: `verseTap` begins only when `verseForTap(at:touch:)` is not nil.
  - `shouldBeRequiredToFailBy`: for `verseTap`, true for another `UITapGestureRecognizer` on the text view with `numberOfTapsRequired == 1` that is not one of `ownGestures`.
  - `verseTapped`: as `openHighlight` (`:1340-1348`) but for `span.textRange` and without `onHighlightTap`. Move the presentation into one `presentMenu(for range: NSRange)` that both use and that counts `menuPresentations`.
  - If presenting in the suite's scene-less window traps, guard only the `presentEditMenu` call on `textView.window?.windowScene != nil`; the count stays outside the guard.
- [ ] **Step 4: Run the suite.** `PhoneChapterTextControllerTests` passes; then the whole iOS suite and the package suite pass.
- [ ] **Step 5: See it in the simulator.** Build the iOS Debug app, launch it, and with the iOS Simulator control tool:
  - Tap a verse: screenshot shows the whole verse selected with handles and the edit menu. Open the picture and check it.
  - Tap another verse; tap a margin; press and hold a word (a word is selected, as before).
  - Tap twice quickly on one word: the selection narrows to that word. **If it stays the whole verse,** the system's single and double tap are one recogniser, which the verse tap made wait. Then the verse tap takes the second tap itself: with `touch.tapCount == 2` on a verse's lines it selects `ReaderTextLogic.snapToWords` of the character under the point and presents the menu. Change `theRulesThatMakeATapNotAVerseTap` and `theVerseTapActsAtOnceAndLeavesTheDoubleTapToTheSystem` to match, and record it for the spec's As built.
  - Choose nothing from the menu that writes. Say plainly which of these could not be driven.
- [ ] **Step 6: Commit.** `feat: a tap selects the verse on the iPhone (verse basics 4)`

---

### Task 3: Mac, a click selects the verse (spec 5.1)

**Files:**
- Modify: `SUI/ChapterTextController.swift` (`mouseSelectionEnded` `:1067-1074`, `ColumnTextView.mouseDown` `:1258-1262`)
- Test: create `T/ReaderClickTests.swift` (`#if os(macOS)`: package suite only)

**How a click is told from a drag:** `NSTextView.mouseDown` returns on mouse-up, so when `mouseSelectionEnded` runs the selection already says which it was. A click count of 1 that left a zero-length selection outside every highlight is a plain click. A drag, a shift-click or a double-click left a range, and a caret inside a highlight is today's highlight click; all of those keep today's path.

**Interfaces:**
- Consumes: `ReaderTextLogic.verse(at:in:isOnLines:)` (Task 1).
- Produces (on `ChapterTextController`, internal):

```swift
/// As the phone's: horizontally the verse's painted segment on a line, vertically that line
/// fragment's whole height, outset by `outlineMargin`; `point` in text-view coordinates.
func isOnLines(_ span: VerseSpan, at point: NSPoint) -> Bool
/// The verse whose lines `point` is on (`characterIndexForInsertion(at:)`, then Task 1's rule).
func verseSpan(at point: NSPoint) -> VerseSpan?
/// The character index in the verse that ⇧J and ⇧K keep selected; nil once the selection changes by other means.
private(set) var verseAnchor: Int?
/// Selects whole verses and remembers the anchor. Task 4's keys use it too.
func selectVerses(_ range: NSRange, anchor: Int)
/// Mouse-up, replacing `mouseSelectionEnded(with:)`: `point` in text-view coordinates.
func clickEnded(at point: NSPoint, clickCount: Int)
```

- [ ] **Step 1: Write the failing tests.** Helpers:
  - `controller` is `ControllerFixture`'s (`T/ChapterTextControllerTests.swift:9-81`) showing `layout`, 20 `verses` of Matthew 5, with `sizeToContent` after `show`.
  - `asked` collects the reports `controller.menuProvider` is given. The provider returns nil, since `NSMenu.popUp` would block a test.
  - `click(point)` sets the caret where a real click leaves it (`setSelectedRange` of `characterIndexForInsertion(at:)`, length 0) and calls `clickEnded(at: point, clickCount: 1)`.
  - `words(n)` is the centre of `frameOfFirstSegment(of:)` for verse n's first five text characters.
  - `relaxed` and `verseOne` are as in Task 2: a controller showing the chapter in Relaxed line spacing, and its first span.
  - `highlight` is a `RangeDecoration` on verse 3's first ten characters; `model` is a `MarkupModel` made as `MarkupModelTests.makeModel()` does, with `controller.onSelectionChange = { model.setSelection($0) }`.

```swift
@Test func aClickSelectsTheVerseAndOpensNoMenu() throws {
    click(try words(3))
    let span = try #require(layout.span(for: at(3)))
    #expect(controller.textView.selectedRange() == span.textRange)
    #expect(asked.isEmpty)
    #expect(controller.selectionReport()?.selection.verse == 3)
    // On the verse's number too.
    let number = try #require(controller.frameOfFirstSegment(of: span.numberRange))
    #expect(controller.verseSpan(at: NSPoint(x: number.midX, y: number.midY)) == span)
}

@Test func aClickOnAnotherVerseMovesItAndOnTheSameVerseKeepsIt() throws {
    click(try words(3))
    click(try words(5))
    #expect(controller.textView.selectedRange() == layout.span(for: at(5))?.textRange)
    click(try words(5))
    #expect(controller.textView.selectedRange() == layout.span(for: at(5))?.textRange)
}

@Test func aClickOffTheTextClearsTheSelection() throws {
    click(try words(3))
    click(NSPoint(x: 4, y: try words(3).y))                    // the margin beside the line
    #expect(controller.textView.selectedRange().length == 0)
    #expect(controller.verseSpan(at: NSPoint(x: 4, y: try words(3).y)) == nil)
}

@Test func everyPointDownAVersesLinesIsThatVerse() throws {
    // Task 2's test of the same name, with `frameOfFirstSegment(of:)` for the first and last characters' rects.
    for y in stride(from: first.minY, through: last.maxY, by: 1) {
        #expect(relaxed.verseSpan(at: NSPoint(x: first.minX + 4, y: y)) == verseOne, "y \(y)")
    }
}

@Test func aClickInsideAHighlightAndADragBehaveAsBefore() throws {
    // A highlight on verse 3's first ten characters.
    controller.textView.setSelectedRange(NSRange(location: highlight.range.location + 2, length: 0))
    controller.clickEnded(at: try words(3), clickCount: 1)
    #expect(controller.textView.selectedRange().length == 0)                     // still the caret
    #expect(asked.count == 1 && asked[0].primaryHighlightID == highlight.id)     // its menu is asked for
    // A drag across part of two words: snapped to the words, and the menu asked for.
    let start = layout.span(for: at(5))!.textRange.location
    controller.textView.setSelectedRange(NSRange(location: start + 1, length: 8))
    controller.clickEnded(at: try words(5), clickCount: 1)
    #expect(asked.count == 2 && controller.textView.selectedRange() == controller.actionRange())
    // A double-click's word.
    controller.textView.setSelectedRange(NSRange(location: start, length: 5))
    controller.clickEnded(at: try words(5), clickCount: 2)
    #expect(asked.count == 3 && controller.textView.selectedRange().length == 5)
}

@Test func aClickedVerseIsASelectionEverywhere() throws {
    // `controller.onSelectionChange = { model.setSelection($0) }` on a `MarkupModel` made as `MarkupModelTests.makeModel()` does.
    click(try words(2))
    #expect(model.currentSelection?.selection.verse == 2)
    #expect(model.currentSelection?.selection.quotedText == verses[1].text)      // what ⇧⌘A asks about
}

@Test func theClickThatBringsTheWindowForwardSelectsNothing() {
    #expect(controller.textView.acceptsFirstMouse(for: nil) == false)
}
```

- [ ] **Step 2: Run them.** `swift test … --filter ReaderClickTests` FAILS to compile (`clickEnded`, `verseSpan` undefined).
- [ ] **Step 3: Implement.** `mouseDown` passes `convert(event.locationInWindow, from: nil)` and `event.clickCount` to `clickEnded`. In `clickEnded`, the plain-click case calls `selectVerses(span.textRange, anchor: span.textRange.location)` when `verseSpan(at:)` finds a verse and returns without asking for a menu; every other case runs the body `mouseSelectionEnded` has today. `selectionDidChange` clears `verseAnchor` when the new range is not the one `selectVerses` just set. Do not override `acceptsFirstMouse`.
- [ ] **Step 4: Run them.** `ReaderClickTests` passes; the package suite passes (`ChapterTextControllerTests` and `ChapterTextControllerMarkupTests` unchanged).
- [ ] **Step 5: Commit.** `feat: a click selects the verse on the Mac (verse basics 5.1)`

---

### Task 4: The shortcuts catalogue and the Mac reader's keys (spec 5.2)

Three red-green cycles, one commit each: the catalogue (A), the keys (B), focus and N's column (C).

**Files:**
- Create: `SUI/ShortcutCatalog.swift`, `SUI/ReaderFocusRule.swift` (both platform-neutral); `SUI/ChapterTextController+Keys.swift`, `SUI/ReaderKeyCommands.swift` (both `#if os(macOS)`)
- Modify: `SUI/ChapterTextController.swift` (`update` `:263-319`, `ColumnTextView` `:1103-1263`), `SUI/ChapterTextView.swift`, `SUI/ReaderView.swift` (`ReaderMarkup` `:9-30`, `init` `:88-121`, the `ChapterTextView(` call `:274-289`), `SUI/MarkupContextMenu.swift`, `SUI/MarkupModel.swift` (`addNote` `:488-503`), `SUI/NoteRowView.swift` (`editorField` `:171-204`), `SUI/NotesColumnView.swift` (`itemView` `:92-121`), `SUI/NavigationModel.swift` (beside `isPaletteShown` `:53`), `MAC/MainWindowView.swift`
- Test: create `T/ShortcutCatalogTests.swift` and `T/ReaderFocusRuleTests.swift` (both suites), `T/ReaderKeyTests.swift` (`#if os(macOS)`); modify `T/MarkupModelTests.swift` (both suites)

**Interfaces:**
- Consumes: Task 1's `verseStep` and `verseExtension`; Task 3's `selectVerses` and `verseAnchor`.
- Produces:

```swift
// SUI/ShortcutCatalog.swift
public enum ReaderKeyAction: Hashable, Sendable, CaseIterable {
    case nextVerse, previousVerse, extendDown, extendUp
    case color(Int)                       // 1...9
    case noColor, note, bookmark
    case previousChapter, nextChapter
    case clearSelection, showShortcuts
    public static var allCases: [ReaderKeyAction] { get }   // the eleven plain cases and color(1)...color(9)
}

/// A bare key: letters lower-cased, `shift` saying whether Shift was held; digits, "?" and the
/// named keys always with `shift` false.
public struct ReaderKeyStroke: Hashable, Sendable {
    public enum Key: Hashable, Sendable { case character(Character), leftArrow, rightArrow, escape }
    public let key: Key
    public let shift: Bool
    public init(_ key: Key, shift: Bool = false)
}

public struct Shortcut: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let keys: [String]        // the keycaps as shown; "–" is plain text between caps
    public let spoken: String        // the keys by name, for VoiceOver
    public let chords: [String]      // each chord in one form, modifiers in the order ⌃⌥⇧⌘
    public let readerKeys: [ReaderKeyStroke: ReaderKeyAction]
}
public struct ShortcutGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let shortcuts: [Shortcut]
}
public enum ShortcutCatalog {
    public static let groups: [ShortcutGroup]
    public static func readerAction(for stroke: ReaderKeyStroke) -> ReaderKeyAction?
}

// SUI/ReaderFocusRule.swift
public enum ReaderFocusRule {
    public enum Reason: Sendable, CaseIterable { case chapterOpened, noteEditFinished, paletteClosed, shortcutsClosed }
    /// What holds keyboard focus in the reader's window when a request is settled.
    public enum Holder: Sendable, CaseIterable {
        case reader          // the reader's text already
        case fieldBeingLeft  // the field that had focus when the request was made (the note's editor, the palette's field)
        case typing          // any other field being typed in
        case other           // the window, a row, a button
    }
    public static func takes(for reason: Reason, from holder: Holder) -> Bool
}
public struct ReaderFocusRequest: Equatable, Sendable {
    public let reason: ReaderFocusRule.Reason
    public let serial: Int
    public init(reason: ReaderFocusRule.Reason, serial: Int)
}

// macOS only
extension ReaderKeyStroke { init?(event: NSEvent) }
extension ChapterTextController {
    var onReaderKey: (ReaderKeyAction, SelectionReport?) -> Bool   // stored; default `{ _, _ in false }`
    func perform(_ action: ReaderKeyAction) -> Bool                // false leaves the event to `NSTextView`
    func requestFocus(_ reason: ReaderFocusRule.Reason)
    func resolveFocus()                                            // settles a waiting request now (tests)
    func apply(_ request: ReaderFocusRequest?)
}
@MainActor public enum ReaderKeyCommands {
    public static func perform(_ action: ReaderKeyAction, report: SelectionReport?, markup: MarkupModel,
                               navigation: NavigationModel, controller: ChapterTextController) -> Bool
}
// MarkupContextMenu gains, used by its own items and by ReaderKeyCommands:
static func pickColor(_ id: UUID, report: SelectionReport, model: MarkupModel, controller: ChapterTextController)
static func pickNoColor(report: SelectionReport, model: MarkupModel, controller: ChapterTextController)
static func addNote(report: SelectionReport, model: MarkupModel, controller: ChapterTextController)

// MarkupModel
public var onShowNotesColumn: (() -> Void)?        // `addNote(to:)` calls it once the note exists
public private(set) var noteFinishCount: Int       // ⌘Return, Return or Esc in a note, never a blur
public func noteFinished()
// NavigationModel
public var isShortcutsShown: Bool                  // Task 5 presents it
// ReaderMarkup (macOS) gains `onKey: (ReaderKeyAction, SelectionReport?, ChapterTextController) -> Bool`, default `{ _, _, _ in false }`;
// ReaderView and ChapterTextView gain `focusRequest: ReaderFocusRequest? = nil`.
```

**The catalogue's rows.** Labels are the menus' own names where a menu has the command. Compare (C) and cross-references (R) have no row.

| Group | Label | Keys shown | Spoken | Chords | Reader keys |
|---|---|---|---|---|---|
| Go | Go to anything | ⌘ K | Command K | ⌘K | |
| Go | Back, forward | ⌘ [ ] | Command left bracket, Command right bracket | ⌘[ ⌘] | |
| Go | Previous, next chapter | ← → | Left arrow, Right arrow | ← → | ← `previousChapter`, → `nextChapter` |
| Go | Previous, next chapter, from anywhere | ⌥ ⌘ ← → | Option Command left arrow, Option Command right arrow | ⌥⌘← ⌥⌘→ | |
| Go | Home | ⇧ ⌘ H | Shift Command H | ⇧⌘H | |
| View | Text & Layout | ⌘ T | Command T | ⌘T | |
| View | Notes column | ⌥ ⌘ N | Option Command N | ⌥⌘N | |
| View | Notes browser | ⇧ ⌘ N | Shift Command N | ⇧⌘N | |
| View | Settings | ⌘ , | Command comma | ⌘, | |
| View | Keyboard shortcuts | ⌘ / ? | Command slash, or question mark | ⌘/ ? | ? `showShortcuts` |
| Verses | Next, previous verse | J K | J, K | J K | j `nextVerse`, k `previousVerse` |
| Verses | Extend by a verse | ⇧ J K | Shift J, Shift K | ⇧J ⇧K | ⇧j `extendDown`, ⇧k `extendUp` |
| Verses | Highlight in a color | 1 – 9 | 1 to 9 | 1 2 3 4 5 6 7 8 9 | "1"…"9" `color(1)`…`color(9)` |
| Verses | No color | 0 | 0 | 0 | "0" `noColor` |
| Verses | Add or edit note | N | N | N | n `note` |
| Verses | Bookmark | B | B | B | b `bookmark` |
| Verses | Copy | ⌘ C | Command C | ⌘C | |
| Verses | Clear selection | esc | Escape | esc | escape `clearSelection` |
| Notes Column | Move between notes | ↑ ↓ | Up arrow, Down arrow | ↑ ↓ | |
| Notes Column | Edit, finish | ↩ ⌘ ↩ | Return, Command Return | ↩ ⌘↩ | |
| Notes Column | Delete, undo | ⌫ ⌘ Z | Delete, Command Z | ⌫ ⌘Z | |
| Notes Column | Search the Notes browser | ⌘ F | Command F | ⌘F | |
| Notes Column | Export notes | ⇧ ⌘ E | Shift Command E | ⇧⌘E | |
| Assistant | Show assistant | ⇧ ⌘ A | Shift Command A | ⇧⌘A | |
| Assistant | New conversation | ⌃ ⌘ N | Control Command N | ⌃⌘N | |
| Assistant | Try again | ⌘ R | Command R | ⌘R | |
| Assistant | Copy last reply | ⇧ ⌘ C | Shift Command C | ⇧⌘C | |
| Assistant | Add last reply as note | ⇧ ⌘ S | Shift Command S | ⇧⌘S | |
| Assistant | Stop answering | ⌘ . | Command period | ⌘. | |

Group ids: `go`, `view`, `verses`, `notesColumn`, `assistant`.

#### Cycle A: the catalogue

- [ ] **Step 1: Write the failing tests** in `T/ShortcutCatalogTests.swift`.

```swift
@Test func theGroupsAreTheFiveInOrder() {
    #expect(ShortcutCatalog.groups.map(\.title) == ["Go", "View", "Verses", "Notes Column", "Assistant"])
}

@Test func everyReaderKeyActionIsListedAndNoKeyTwice() {
    let pairs = ShortcutCatalog.groups.flatMap(\.shortcuts).flatMap { Array($0.readerKeys) }
    #expect(Set(pairs.map(\.value)) == Set(ReaderKeyAction.allCases))
    #expect(Set(pairs.map(\.key)).count == pairs.count)
    #expect(ReaderKeyAction.allCases.count == 20)
    let chords = ShortcutCatalog.groups.flatMap(\.shortcuts).flatMap(\.chords)
    #expect(Set(chords).count == chords.count)
}

@Test func theReadersKeysResolveThroughTheCatalogue() {
    func action(_ key: ReaderKeyStroke.Key, shift: Bool = false) -> ReaderKeyAction? {
        ShortcutCatalog.readerAction(for: ReaderKeyStroke(key, shift: shift))
    }
    #expect(action(.character("j")) == .nextVerse && action(.character("k"), shift: true) == .extendUp)
    #expect(action(.character("7")) == .color(7) && action(.character("0")) == .noColor)
    #expect(action(.leftArrow) == .previousChapter && action(.escape) == .clearSelection)
    #expect(action(.character("?")) == .showShortcuts)
    // Reserved for project 3: unhandled and unlisted.
    #expect(action(.character("c")) == nil && action(.character("r")) == nil)
    // Left to AppKit as today: a shifted arrow, and Space (as ↑, ↓ and the Page keys, which make no stroke).
    #expect(action(.leftArrow, shift: true) == nil && action(.character(" ")) == nil)
}

#if os(macOS)
/// Section 6: every shortcut in the app is in a group, the menus' existing ones included.
@Test func everyMenuShortcutInTheMacAppIsListed() throws {
    let listed = Set(ShortcutCatalog.groups.flatMap(\.shortcuts).flatMap(\.chords))
    let found = try Self.menuChordsInSource()
    #expect(found.count >= 15)
    for chord in found { #expect(listed.contains(chord), "\(chord) is in a menu but not in the catalogue") }
}
#endif
```

`menuChordsInSource()` walks `Apps/Mac` and `Sources/ScriptureUI` (not its `Phone` folder) as `SepiaModeTests.everyAppKitHostedSwiftUIRootFollowsSepia` walks them, for `.keyboardShortcut("x", modifiers: …)` and `.keyboardShortcut(.leftArrow, modifiers: …)`. `.defaultAction` and `.cancelAction` are not chords. Each becomes a chord string: modifiers in the order ⌃⌥⇧⌘, the key upper-cased, the arrows as ← and →.

- [ ] **Step 2: Run.** `--filter ShortcutCatalogTests` FAILS to compile.
- [ ] **Step 3: Implement `SUI/ShortcutCatalog.swift`** from the table. `readerAction(for:)` reads a dictionary built once from every row's `readerKeys` with `Dictionary(_:uniquingKeysWith:)`, so a duplicate fails the test, not the launch.
- [ ] **Step 4: Run.** `ShortcutCatalogTests` passes in the package suite and (without the scan) the iOS suite.
- [ ] **Step 5: Commit.** `feat: one catalogue of the app's shortcuts (verse basics 6)`

#### Cycle B: the keys

- [ ] **Step 6: Write the failing tests** in `T/ReaderKeyTests.swift`. The harness holds:
  - `model`, a `MarkupModel` on an in-memory container with the five default colours (as `MarkupModelTests.makeModel()`), its `undoManager` set as `deletingAHighlightOrClearingItsColorIsUndoable` sets one.
  - `navigation`, a `NavigationModel` on `FixtureStore`, open at Matthew 2.
  - `controller`, showing Matthew 5: the three short verses of `MarkupModelTests`, or sixty of `F.verses` where a test says so. `t(n)` is verse n's `textRange`.
  - The wiring: `controller.onSelectionChange = { model.setSelection($0) }`, `controller.onReaderKey = { ReaderKeyCommands.perform($0, report: $1, markup: model, navigation: navigation, controller: controller) }`, `controller.reducesMotion = { true }`.
  - `key("J", flags: .shift)` builds an `NSEvent.keyEvent(with: .keyDown, …)`. `press("j")`, `press("J", shift: true)` and `press(keyCode: 124)` hand one to `controller.textView.keyDown(with:)`, then give the controller `model.bookDecorations` again through `update`.
  - `select(n)` is `controller.selectVerses(t(n), anchor: t(n).location)`. `selected` is the verses of `controller.selectionReport()` as a closed range, nil for none.
  - For the focus tests, `window` is an `NSWindow` (`isReleasedWhenClosed = false`) holding the reader, two editable `NSTextView`s (`field`, `secondField`) and `other`, a plain `NSView` that accepts first responder.

```swift
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
    select(2)
    show(target: ScrollTarget(chapter: 5, verse: 40))
    press("j")
    #expect(selected == 40...40)
}

@Test func aVerseBelowTheFoldIsScrolledWhollyIntoView() throws {
    // Sixty verses in the 300 pt window: step until the selection has left the first screen.
    for _ in 0..<12 { press("j") }
    let range = controller.textView.selectedRange()
    let top = try #require(controller.frameOfFirstSegment(of: NSRange(location: range.location, length: 1)))
    let foot = try #require(controller.frameOfFirstSegment(of: NSRange(location: NSMaxRange(range) - 1, length: 1)))
    let visible = controller.scrollView.documentVisibleRect
    #expect(top.minY >= visible.minY + controller.headLineY && foot.maxY <= visible.maxY)
}

@Test func keysTypedInAnotherFieldNeverReachTheReader() throws {
    select(2)
    window.makeFirstResponder(field)
    window.sendEvent(try key("1"))
    #expect(model.items.isEmpty && field.string == "1")
}
```

- [ ] **Step 7: Run.** `--filter ReaderKeyTests` FAILS to compile.
- [ ] **Step 8: Implement the keys.**
  - `ReaderKeyStroke.init?(event:)`: nil when ⌘, ⌥ or ⌃ is held. Key codes 53, 123 and 124 are `.escape`, `.leftArrow` and `.rightArrow`, with `shift` as held. Otherwise the first character of `charactersIgnoringModifiers`: a letter is lower-cased with `shift` as held; anything else keeps `shift` false.
  - `ColumnTextView.keyDown(with:)`: the stroke, then `ShortcutCatalog.readerAction(for:)`, then `columnDelegate?.perform(_:)`; anything that is not all three goes to `super`. Nothing else in the app handles these keys, so they act only while this view is first responder.
  - `perform(_:)` on the controller:
    - `nextVerse`, `previousVerse`: `ReaderTextLogic.verseStep`, then `selectVerses` and reveal. Returns true even when there is nowhere to go.
    - `extendDown`, `extendUp`: `ReaderTextLogic.verseExtension` with `verseAnchor`, then the same.
    - The selection handed to both is nil when its range is a caret outside every verse, or when no rect of it intersects the visible page under the head (Review Focus 2). `firstVisible` is the last reading position reported.
    - `clearSelection`: `collapseSelection()` and true when the range has length; false otherwise.
    - `color`, `noColor`, `note`, `bookmark`: with `reportForAction()` nil, true and nothing; else `onReaderKey(action, report)`.
    - `previousChapter`, `nextChapter`, `showShortcuts`: `onReaderKey(action, nil)`.
  - Reveal: when the verses' rects are not wholly between the head's line and the visible bottom, scroll the least that shows them: their top to `outlineMargin + scrollLeadIn` under the head's line when they are above it or taller than the page, else their bottom to `outlineMargin` above the visible bottom. Animated; a cut when `reducesMotion()`.
  - `ReaderKeyCommands.perform`:
    - `color(n)`: `MarkupContextMenu.pickColor` with `markup.colorChips[n - 1]`; nothing past the last chip.
    - `noColor`: `pickNoColor` only when `markup.menuItems(for:)` offers `.noColor`.
    - `note`: `MarkupContextMenu.addNote`. `bookmark`: `markup.toggleBookmark(for:)`.
    - The chapters: `navigation.goToPreviousChapter()` and `goToNextChapter()`.
    - `showShortcuts`: `navigation.isShortcutsShown.toggle()`.
    - Every listed case returns true; the verse cases, which never arrive here, return false.
  - `MarkupContextMenu`: move the bodies of the swatch's `onPick` and `onNoColor` and of the Add Note action into the three statics, and call them from the menu, so a key and its menu item cannot differ.
  - If the keys live in the new extension file, the members it reads (`lastReportedPosition`, `reportForAction()`, `segmentFrames(of:)`, `scroll(toY:)`) lose `private`.
- [ ] **Step 9: Run.** `ReaderKeyTests` passes; the package suite passes.
- [ ] **Step 10: Commit.** `feat: single keys act on the selected verse (verse basics 5.2)`

#### Cycle C: focus, and N's column

- [ ] **Step 11: Write the failing tests.** In `T/ReaderFocusRuleTests.swift`:

```swift
@Test func theReaderTakesFocusOnlyWhereTheSpecSays() {
    typealias R = ReaderFocusRule
    for reason in R.Reason.allCases {
        #expect(R.takes(for: reason, from: .reader) == false)      // it has it already
        #expect(R.takes(for: reason, from: .other) == true)
        #expect(R.takes(for: reason, from: .typing) == false)      // never from a field being typed in
    }
    #expect(R.takes(for: .noteEditFinished, from: .fieldBeingLeft))
    #expect(R.takes(for: .paletteClosed, from: .fieldBeingLeft))
    #expect(!R.takes(for: .chapterOpened, from: .fieldBeingLeft))
    #expect(!R.takes(for: .shortcutsClosed, from: .fieldBeingLeft))
}
```

In `T/ReaderKeyTests.swift`, with the harness's `window`. `focus(from: responder) { change }` makes `responder` first responder, runs the change, calls `controller.resolveFocus()` and returns the window's first responder.

```swift
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
    // Another field took focus before the request settled (the assistant's composer): it keeps it.
    var held = focus(from: field) { controller.requestFocus(.paletteClosed); window.makeFirstResponder(secondField) }
    #expect(held === secondField)
    // Closing the shortcuts sheet leaves a note being typed.
    held = focus(from: field) { controller.requestFocus(.shortcutsClosed) }
    #expect(held === field)
}
```

In `T/MarkupModelTests.swift`:

```swift
@Test func addingANoteAsksForTheNotesColumn() throws {
    let (model, _) = try makeModel()
    var shown = 0
    model.onShowNotesColumn = { shown += 1 }
    model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
    #expect(shown == 1 && model.editingNoteID != nil)
}

@Test func onlyAFinishedEditCounts() throws {
    let (model, _) = try makeModel()
    model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
    model.endEditing(noteID: model.editingNoteID!)       // a blur, or a click elsewhere
    #expect(model.noteFinishCount == 0)
    model.noteFinished()                                 // ⌘Return, Return or Esc
    #expect(model.noteFinishCount == 1)
}
```

- [ ] **Step 12: Run.** `--filter ReaderFocusRuleTests`, `ReaderKeyTests` and `MarkupModelTests` FAIL to compile.
- [ ] **Step 13: Implement focus.**
  - `requestFocus(_:)` keeps one waiting request; `noteEditFinished` and `paletteClosed` are not replaced by the other two. It remembers the window's first responder when that is a field being typed in, and settles on the next turn of the main queue, or from `ColumnTextView.viewDidMoveToWindow` when the text view has no window yet.
  - `resolveFocus()` takes focus when `ReaderFocusRule.takes` says so. The holder is `reader` for the reader's own text view, `fieldBeingLeft` for the remembered responder, `typing` for any other `NSText` with `isEditable` (a text view, or a field's editor), `other` for the rest.
  - `update(layout:…)` requests `.chapterOpened` when the new layout's book or chapters differ from the old layout's (the first layout included), never for a decoration, a typography or a translation alone.
  - `apply(_:)` requests the reason when the request differs from the last one applied; `ChapterTextView.updateNSView` calls it.
- [ ] **Step 14: Implement N's column and the wiring.**
  - `MarkupModel.addNote(to:)` calls `onShowNotesColumn?()` where it calls `showInColumn`.
  - `NoteRowView` gains `onFinish: () -> Void = {}`, called after `onEndEdit()` in the editor's `onFinish:` path only (`:198-201`); `NotesColumnView` passes `{ model.noteFinished() }`.
  - `MAC/MainWindowView.swift`. Its `body` chain is at the type checker's limit: put new modifiers on `page` (`:209-212`) or in a `ViewModifier`, never on `body`.
    - `@State private var readerFocus: ReaderFocusRequest?`, bumped by one helper `requestReaderFocus(_:)`.
    - `.onChange(of: model.isPaletteShown)` requests `.paletteClosed` when it turns false; the same for `model.isShortcutsShown` and `.shortcutsClosed`; `.onChange(of: markup.noteFinishCount)` requests `.noteEditFinished`.
    - `ReaderView(…, focusRequest: readerFocus)`, and `ReaderMarkup(…, onKey:)` calling `ReaderKeyCommands.perform` with `markup` and `model`.
    - In `wireAssistant()` (`:390-404`): `markup.onShowNotesColumn` does what `showChapterNotes` does to the column (`:373-377`): the assistant's panel is hidden if shown, and `showNotesColumn = true`. The context menu's Add Note now gets the same.
- [ ] **Step 15: Run.** The three suites pass; the whole package suite and the iOS suite pass.
- [ ] **Step 16: See it in the Debug app, without writing anything.** Build the Mac Debug app, quit and open it. Through System Events, with no click in the window first:
  - Type `j` three times and capture the window: a verse is selected, the third from the first on screen.
  - Hold Shift and type `j`: two verses. Press Escape: none.
  - Press → then ←: the chapter turns and comes back.
  - Do not type a digit, `n` or `b`. If AeroSpace keeps the window out of reach, say so; the tests stand.
- [ ] **Step 17: Commit.** `feat: the reader takes the keyboard, and N shows the notes column (verse basics 5.2)`

---

### Task 5: The shortcuts sheet and its three ways in (spec 6)

**Files:**
- Create: `SUI/ShortcutsSheet.swift`
- Modify: `SUI/ShortcutCatalog.swift`, `SUI/PaletteItem.swift` (`PaletteCommand` `:5-27`), `MAC/ReadingThroughScriptureApp.swift` (`togglePalette` `:91-103`, `wirePalette` `:107-117`, `.commands` `:170-243`), `MAC/MainWindowView.swift` (the `.sheet` at `:190`)
- Test: `T/ShortcutCatalogTests.swift` and `T/PaletteRankerTests.swift` (both suites)

**Interfaces:**
- Consumes: `ShortcutCatalog.groups`, `NavigationModel.isShortcutsShown` (Task 4).
- Produces:

```swift
extension Shortcut {
    /// "Next, previous verse: J, K"; "Go to anything: Command K".
    public var accessibilityLabel: String { get }
}
extension ShortcutCatalog {
    /// The groups with only the rows whose label contains `query` (case and diacritics ignored,
    /// white space trimmed); a group left with no row is dropped. An empty query is every group.
    public static func filtered(_ query: String) -> [ShortcutGroup]
    /// The sheet's three columns: Go and View; Verses; Notes Column and Assistant. A column left
    /// with no group is dropped.
    public static func columns(_ groups: [ShortcutGroup]) -> [[ShortcutGroup]]
}
public struct ShortcutsSheet: View {
    public init(onDone: @escaping () -> Void)
}
// PaletteCommand gains `case showShortcuts`: title "Keyboard Shortcuts", symbol "keyboard".
```

- [ ] **Step 1: Write the failing tests.**

```swift
// ShortcutCatalogTests
@Test func aRowSpeaksItsLabelThenItsKeysByName() {
    let rows = ShortcutCatalog.groups.flatMap(\.shortcuts)
    #expect(rows.first { $0.id == "verses" }?.accessibilityLabel == "Next, previous verse: J, K")
    #expect(rows.first { $0.id == "goToAnything" }?.accessibilityLabel == "Go to anything: Command K")
}

@Test func theFilterNarrowsRowsByTheirLabel() {
    let verse = ShortcutCatalog.filtered("  VERSE ")
    #expect(verse.map(\.title) == ["Verses"])
    #expect(verse[0].shortcuts.map(\.label) == ["Next, previous verse", "Extend by a verse"])
    #expect(ShortcutCatalog.filtered("") == ShortcutCatalog.groups)
    #expect(ShortcutCatalog.filtered("zebra").isEmpty)
    #expect(ShortcutCatalog.filtered("chapter").map(\.title) == ["Go"])
}

@Test func theGroupsFallIntoThreeColumns() {
    #expect(ShortcutCatalog.columns(ShortcutCatalog.groups).map { $0.map(\.id) }
            == [["go", "view"], ["verses"], ["notesColumn", "assistant"]])
    #expect(ShortcutCatalog.columns(ShortcutCatalog.filtered("verse")).map { $0.map(\.id) } == [["verses"]])
}

// PaletteRankerTests
@Test func theShortcutsSheetIsACommand() {
    #expect(rank("keyb").contains(.command(.showShortcuts)))
    #expect(rank("short").contains(.command(.showShortcuts)))
    #expect(PaletteItem.command(.showShortcuts).title == "Keyboard Shortcuts" && PaletteItem.command(.showShortcuts).symbolName == "keyboard")
}
```

- [ ] **Step 2: Run.** Both filters FAIL to compile.
- [ ] **Step 3: Implement the catalogue's three members and the command.** The app's `wirePalette` switch gains `case .showShortcuts: model.isShortcutsShown = true`.
- [ ] **Step 4: Build `ShortcutsSheet`** to spec 6's Layout, Look and VoiceOver bullets, tokens only. What the spec leaves open:
  - The filter is a `TextField` with the prompt "Filter", focused by `@FocusState` as the sheet opens.
  - The columns are `ShortcutCatalog.columns(ShortcutCatalog.filtered(query))`, each a `@ScaledMetric(relativeTo: .callout)` 220 wide; a row's keycaps sit at its trailing end.
  - A keycap is at least a `@ScaledMetric(relativeTo: .caption)` 20 pt square, wider for "esc". "–" is plain text in `ink.secondary`, not a cap.
  - No match: one line, `No shortcut matches “\(query)”.`, in `.callout` `ink.secondary`.
  - The foot's line is `.caption` `ink.secondary`; Done is `.keyboardShortcut(.defaultAction)`; Esc is `.onExitCommand(perform: onDone)`.
  - It is presented by SwiftUI's `.sheet`, as `AddColorSheet` is, so it takes the window's Sepia and page face from the environment. Hosted any other way (`NSHostingView`, `NSHostingController`) it must take `.followsSepia()`; `SepiaModeTests` scans for that.
- [ ] **Step 5: Wire the ways in.**
  - `MainWindowView`: `.sheet(isPresented: $model.isShortcutsShown) { ShortcutsSheet { model.isShortcutsShown = false } }`, on `page`, not `body`.
  - The app: `CommandGroup(replacing: .help) { Button("Keyboard Shortcuts") { toggleShortcuts() }.keyboardShortcut("/", modifiers: .command).disabled(model == nil) }`.
  - `toggleShortcuts()`: when the sheet is shown, hide it and stop. Otherwise close the palette, bring the main window forward with `showMainWindow()` unless it is key (as `togglePalette` does from Notes or Settings), and show the sheet.
  - `?` in the reader already toggles `isShortcutsShown` (Task 4).
- [ ] **Step 6: Run.** `ShortcutCatalogTests` (now with ⌘/ in the source), `PaletteRankerTests`, then both whole suites.
- [ ] **Step 7: See it, light and dark.** Build the Mac Debug app, quit and open it. Through System Events:
  - Send ⌘/ and capture the window: the sheet with three columns and its filter focused.
  - Type `verse` and capture: only the Verses rows. Type `zebra`: the one line naming it.
  - Press Escape: the sheet is gone. Send ⌘/ twice: it opens and closes.
  - With the Notes window key (⇧⌘N), send ⌘/: the main window comes forward with the sheet on it.
  - Repeat the first capture in Dark: read `defaults read com.matthewfurr.ReadingThroughScripture.dev readerAppearance`, write `dark`, relaunch, capture, then put Matt's value back.
  - Open each picture; check the keycaps, the spacing and that nothing is clipped.
- [ ] **Step 8: Commit.** `feat: the shortcuts sheet, from ⌘/, ? and ⌘K (verse basics 6)`

---

### Task 6: `PassageLink` (spec 7.1)

**Files:**
- Create: `SD/PassageLink.swift`
- Test: create `TD/PassageLinkTests.swift` (package suite only)

**Interfaces:**
- Consumes: `BookCatalog.book(code:)`, `ReferenceParser.parse`, `Reference`.
- Produces:

```swift
public struct PassageLink: Hashable, Sendable {
    public static let releaseScheme = "bible"
    public static let debugScheme = "bible-dev"
    public static let schemes: Set<String> = [releaseScheme, debugScheme]
    /// The Info.plist key that names the build's scheme.
    public static let infoKey = "PassageURLScheme"

    public let reference: Reference
    /// As the link wrote it, upper-cased; the app decides whether it has that translation.
    public let translationID: String?

    public init(reference: Reference, translationID: String? = nil)
    /// Nil for anything that is not a passage link in either scheme.
    public init?(_ url: URL)
    public init?(string: String)
    /// `bible://jhn.3.16-18`, `bible://rom.8`, `bible://jhn`, `…?translation=KJV`.
    public func url(scheme: String) -> URL

    /// The scheme an Info.plist names, when it is one of `schemes`; otherwise `releaseScheme`.
    public static func scheme(inInfo info: [String: Any]?) -> String
    public static var appScheme: String { get }      // `scheme(inInfo: Bundle.main.infoDictionary)`
}
```

**How a link is read.** From its text (`url.absoluteString`), never from `URL.host`: a host is lower-cased, and ":16" in `bible://John%203:16` reads as a port.
1. The text before the first ":" is the scheme; lower-cased it must be in `schemes`.
2. Drop a leading "//". Cut at the first "#". Split at the first "?" into path and query. Drop a trailing "/". Percent-decode the path; empty is nil.
3. If the path's first dot-separated piece, upper-cased, is a book code, the path is the dotted form `book[.chapter[.verse[-end]]]`, and anything else in that form is nil:
   - Chapter and verse are whole numbers of 1 or more.
   - `end` as a number is the end verse and must be greater than the verse.
   - `end` as `book.chapter.verse` must itself be whole and known. In the same book and chapter it is the end verse (greater than the verse); in another chapter or book the link is its first verse alone.
   - A book alone has no chapter (`Reference(book:)`).
4. Otherwise the decoded path goes to `ReferenceParser.parse`.
5. The query: the first of `translation`, then `v` (names in any case), with a value that is not empty, upper-cased. Every other item is ignored.

- [ ] **Step 1: Write the failing tests.** `ref("JHN", 3, 16, 18)` builds a `Reference` from `BookCatalog`; `link(_:)` is `PassageLink(string:)`.

```swift
@Test func theSpecsExamplesParse() {
    #expect(link("bible://jhn.3.16")?.reference == ref("JHN", 3, 16))
    #expect(link("bible://jhn.3.16-18")?.reference == ref("JHN", 3, 16, 18))
    #expect(link("bible://rom.8")?.reference == ref("ROM", 8))
    #expect(link("bible://jhn")?.reference == Reference(book: BookCatalog.book(code: "JHN")!))
    let kjv = link("bible://1co.13.4-7?translation=KJV")
    #expect(kjv?.reference == ref("1CO", 13, 4, 7) && kjv?.translationID == "KJV")
    #expect(link("bible://jhn.3.16")?.translationID == nil)
}

@Test func theOtherAcceptedFormsParse() {
    #expect(link("bible://jhn.3.16-jhn.3.18")?.reference == ref("JHN", 3, 16, 18))     // the long range
    #expect(link("bible://jhn.3.16-jhn.4.2")?.reference == ref("JHN", 3, 16))          // into another chapter: its first verse
    #expect(link("bible:jhn.3.16")?.reference == ref("JHN", 3, 16))
    #expect(link("bible-dev://jhn.3.16")?.reference == ref("JHN", 3, 16))
    #expect(link("bible://john.3.16")?.reference == ref("JHN", 3, 16))                 // a path the parser reads
    #expect(link("bible://jhn.3.16?v=esv")?.translationID == "ESV")                    // route.bible's own
    #expect(link("bible://jhn.3.16?TRANSLATION=kjv&utm=x")?.translationID == "KJV")
    #expect(link("bible://jhn.3.16?utm=x")?.translationID == nil)
}

@Test func linksTheSystemsParserWouldMangleStillParse() {
    #expect(link("bible://John%203:16")?.reference == ref("JHN", 3, 16))
    if let url = URL(string: "bible://John%203:16") { #expect(PassageLink(url)?.reference == ref("JHN", 3, 16)) }
    #expect(link("BIBLE://JHN.3.16")?.reference == ref("JHN", 3, 16))
    #expect(link("bible://jhn.3.16/")?.reference == ref("JHN", 3, 16))
    #expect(link("bible://jhn.3.16#top")?.reference == ref("JHN", 3, 16))
    #expect(link("bible://1CO.13.4")?.reference == ref("1CO", 13, 4))
}

@Test func malformedLinksParseToNothing() {
    for text in ["bible://", "bible:", "bible://xyz.1.1", "bible://jhn.0", "bible://jhn.3.0", "bible://jhn.x",
                 "bible://jhn.3.16.2", "bible://jhn.3.18-16", "bible://jhn.3.16-16", "bible://jhn.3.16-",
                 "bible://jhn.3.16-act", "bible://jhn.3.16-jhn.3.x", "https://route.bible/jhn.3.16",
                 "scripture://JHN/3/16", "jhn.3.16", ""] {
        #expect(link(text) == nil, "\(text)")
    }
}

@Test func aLinkFormatsAndRoundTrips() {
    #expect(PassageLink(reference: ref("JHN", 3, 16, 18)).url(scheme: "bible").absoluteString == "bible://jhn.3.16-18")
    #expect(PassageLink(reference: ref("ROM", 8)).url(scheme: "bible-dev").absoluteString == "bible-dev://rom.8")
    #expect(PassageLink(reference: Reference(book: BookCatalog.book(code: "JHN")!)).url(scheme: "bible").absoluteString == "bible://jhn")
    #expect(PassageLink(reference: ref("1CO", 13, 4, 7), translationID: "KJV").url(scheme: "bible").absoluteString
            == "bible://1co.13.4-7?translation=KJV")
    for reference in [ref("JHN", 3, 16, 18), ref("PSA", 119, 105), ref("ROM", 8)] {
        #expect(PassageLink(PassageLink(reference: reference).url(scheme: "bible"))?.reference == reference)
    }
}

@Test func everyBooksCodeRoundTrips() {
    for book in BookCatalog.all {
        let reference = Reference(book: book, chapter: 1, verse: 1)
        let url = PassageLink(reference: reference).url(scheme: "bible")
        #expect(url.absoluteString == "bible://\(book.id.lowercased()).1.1")
        #expect(PassageLink(url)?.reference == reference, "\(book.id)")
    }
}

@Test func theBuildsSchemeComesFromItsInfoPlist() {
    #expect(PassageLink.scheme(inInfo: ["PassageURLScheme": "bible-dev"]) == "bible-dev")
    #expect(PassageLink.scheme(inInfo: ["PassageURLScheme": "bible"]) == "bible")
    for info in [nil, [:], ["PassageURLScheme": ""], ["PassageURLScheme": "$(PASSAGE_URL_SCHEME)"], ["PassageURLScheme": "https"]] as [[String: Any]?] {
        #expect(PassageLink.scheme(inInfo: info) == "bible")
    }
}
```

- [ ] **Step 2: Run.** `swift test … --filter PassageLinkTests` FAILS to compile.
- [ ] **Step 3: Implement `SD/PassageLink.swift`** by the five rules above.
- [ ] **Step 4: Run.** `PassageLinkTests` passes; the package suite passes.
- [ ] **Step 5: Commit.** `feat: bible:// passage links, read and written (verse basics 7.1)`

---

### Task 7: The URL scheme on both apps, and opening a link (spec 7.2)

**Files:**
- Create: `Apps/Mac/Info.plist`
- Modify: `Apps/Mac/ReadingThroughScripture.xcodeproj/project.pbxproj` (the target's Debug and Release settings, `:246-310`), `Apps/iOS/ReadingThroughScripture.xcodeproj/project.pbxproj` (the same two, `:259-317`), `Apps/iOS/Info.plist`, `SUI/NavigationModel.swift`, `MAC/ReadingThroughScriptureApp.swift` (the `WindowGroup`, `:147-169`), `SUI/Phone/PhoneRootView.swift` (`body`, `:51-67`)
- Test: `T/NavigationModelTests.swift` (both suites)

**Interfaces:**
- Consumes: `PassageLink` (Task 6), `NavigationModel.lookUp(_:verse:translationID:)` (`:271-294`), `PhoneShellModel.showInReader()`.
- Produces:

```swift
extension NavigationModel {
    /// Opens a passage link as a lookup, in the link's translation when the app has it. False,
    /// with nothing changed, for a link that cannot be read or a chapter the translation that
    /// would show it lacks. Closes the palette and the shortcuts sheet when it opens.
    @discardableResult public func openPassageLink(_ url: URL) -> Bool
}
```

- Build setting `PASSAGE_URL_SCHEME`: `bible-dev` in each target's Debug settings, `bible` in each target's Release settings, in both projects.
- Both Info.plists carry `PassageURLScheme` = `$(PASSAGE_URL_SCHEME)` and one `CFBundleURLTypes` entry: `CFBundleURLName` `$(PRODUCT_BUNDLE_IDENTIFIER).passage`, `CFBundleURLSchemes` `[$(PASSAGE_URL_SCHEME)]`; the Mac's entry also has `CFBundleTypeRole` `Viewer`.

- [ ] **Step 1: Write the failing tests** in `NavigationModelTests`, with its `readingMatthewOne()`, `psalmTwo` and `matthewOne`.

```swift
@Test func aLinkOpensAsALookupAndBackReturns() throws {
    let (model, positionStore) = try readingMatthewOne()
    #expect(model.openPassageLink(URL(string: "bible://psa.2.2")!))
    #expect(model.location == psalmTwo && model.scrollTarget?.verse == 2 && model.screen == .reader)
    #expect(model.lookupReturn?.location == matthewOne && positionStore.load() == readingPlace)
    model.goBack()
    #expect(model.location == matthewOne)
}

@Test func aLinkWithATranslationLooksUpInIt() throws {
    let (model, _) = try readingMatthewOne()
    #expect(model.openPassageLink(URL(string: "bible://psa.2.2?translation=kjv")!))
    #expect(model.translationID == "KJV" && model.lookupReturn?.translationID == "WEB")
    // One the app lacks is ignored.
    let (other, _) = try readingMatthewOne()
    #expect(other.openPassageLink(URL(string: "bible-dev://psa.2.2?translation=NIV")!))
    #expect(other.translationID == "WEB" && other.location == psalmTwo)
}

@Test func aLinkTheAppCannotOpenChangesNothing() throws {
    let (model, _) = try readingMatthewOne()
    for text in ["bible://xyz.1.1", "bible://rev.1.1", "bible://psa.200", "https://route.bible/psa.2"] {
        #expect(!model.openPassageLink(URL(string: text)!), "\(text)")
        #expect(model.location == matthewOne && model.lookupReturn == nil && model.translationID == "WEB")
    }
}

@Test func aBookAloneOpensItsFirstChapterAndAVersePastTheEndOpensTheChapter() throws {
    let (model, _) = try readingMatthewOne()
    #expect(model.openPassageLink(URL(string: "bible://psa")!))
    #expect(model.location == ChapterLocation(book: "PSA", chapter: 1))
    #expect(model.openPassageLink(URL(string: "bible://psa.2.99")!))
    #expect(model.location == psalmTwo && model.scrollTarget == ScrollTarget(chapter: 2, verse: 1))
}

@Test func aLinkClosesThePaletteAndTheShortcutsSheet() throws {
    let (model, _) = try readingMatthewOne()
    model.isPaletteShown = true
    model.isShortcutsShown = true
    #expect(model.openPassageLink(URL(string: "bible://psa.2.2")!))
    #expect(!model.isPaletteShown && !model.isShortcutsShown)
}
```

- [ ] **Step 2: Run.** `--filter NavigationModelTests` FAILS to compile.
- [ ] **Step 3: Implement `openPassageLink`.**
  - The translation is the bundled one whose id matches the link's, case ignored; with none, the one being read.
  - The chapter (the link's, or 1) must exist in that translation's books (`store.books(in:)`); otherwise return false before anything changes.
  - A verse past the chapter's last verse in that translation is dropped, so the chapter opens at its start. **(call, record in As built: `resolvedVerse` would land on its last verse.)**
  - Then close the palette and the sheet and call `lookUp`.
- [ ] **Step 4: Run.** `NavigationModelTests` passes in both suites.
- [ ] **Step 5: Commit.** `feat: a passage link opens as a lookup (verse basics 7.2)`
- [ ] **Step 6: Record the Mac app as it is built now.** Build the Mac Debug app, then keep the output of each of these for Step 9 (`APP` is `Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`):
  - `defaults read "$PWD/APP/Contents/Info" CFBundleName` (expect `Bible Carrel`), and the same for `CFBundleDisplayName`, `CFBundleIdentifier` (`com.matthewfurr.ReadingThroughScripture.dev`) and `CFBundleExecutable` (`ReadingThroughScripture`).
  - `codesign --verify --deep --strict --verbose=2 APP` (expect "valid on disk" and "satisfies its Designated Requirement").
  - `codesign -d --entitlements - APP` (keep the iCloud container lines).
- [ ] **Step 7: Add the build setting and the plists.**
  - `PASSAGE_URL_SCHEME` in the four target configurations.
  - `Apps/Mac/Info.plist` with only the two keys above. It sits beside `ReadingThroughScripture.entitlements`, outside the synchronized `ReadingThroughScripture` folder, so Xcode never copies it as a resource. Add `INFOPLIST_FILE = Info.plist;` to the Mac target's two configurations and keep `GENERATE_INFOPLIST_FILE = YES`.
  - The same two keys in `Apps/iOS/Info.plist`, beside `CloudKitContainer`.
  - Put no `CFBundleName`, display name or identifier in either file: milestone 9 found that only `PRODUCT_NAME` names the app, and a script edit of the built plist broke the signature.
- [ ] **Step 8: Answer the link in each app.**
  - Mac: on `MainWindowView(…)` inside the `WindowGroup`, `.onOpenURL { model.openPassageLink($0) }` and `.handlesExternalEvents(preferring: ["*"], allowing: ["*"])`, so an incoming link goes to the open main window and SwiftUI makes no second one.
  - iPhone: on `PhoneRootView`'s `body`, `.onOpenURL { if navigation.openPassageLink($0) { shell.showInReader() } }`. The models are built in the app's `init`, so a cold launch finds the store ready.
- [ ] **Step 9: Check the Mac app is still itself.** Build the Mac Debug app again and run Step 6's commands.
  - The four `defaults read` values are identical to Step 6's.
  - `codesign --verify` passes, and the entitlements still name the same iCloud container.
  - `defaults read "$PWD/APP/Contents/Info" PassageURLScheme` prints `bible-dev`; `defaults read "$PWD/APP/Contents/Info" CFBundleURLTypes` shows `bible-dev`.
  - Release, without building it: `xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Release -showBuildSettings` contains `PASSAGE_URL_SCHEME = bible` and `INFOPLIST_FILE = Info.plist`; the same for `-scheme ReadingThroughScripture-iOS`.
  - If the name, the identifier or the signature changed, stop and report; do not patch the built plist.
- [ ] **Step 10: Open a link on the Mac.** Quit and open the Debug app (opening it registers the scheme). Run `open "bible-dev://jhn.3.16"`.
  - Capture the window: John 3 at verse 16. Send ⌘[ and capture: the place before.
  - Count the app's large windows with the `CGWindowListCopyWindowInfo` script before and after two more `open` calls: the count does not grow.
  - **If a second main window appears,** replace the two modifiers with an `NSApplicationDelegateAdaptor` whose `application(_:open:)` calls `openPassageLink` and brings the main window forward, and repeat this step.
  - Run `open "bible-dev://nonsense"`: the app comes forward and the page does not change.
  - Quit the app and run `open "bible-dev://rom.8"`: it launches on Romans 8 (a cold launch).
- [ ] **Step 11: Open a link on the iPhone.** Build the iOS Debug app and check `plutil -p Build/DerivedData/Build/Products/Debug-iphonesimulator/ReadingThroughScripture.app/Info.plist` shows `PassageURLScheme` `bible-dev`, the URL type, and `CloudKitContainer` as before.
  - Launch it, then `xcrun simctl openurl booted "bible-dev://jhn.3.16"` (tap Open if the simulator asks). Screenshot: John 3 at verse 16.
  - Open Settings in the app, run the command again with `rom.8`, and screenshot: Settings is gone and Romans 8 shows (Review Focus 5).
  - Terminate the app and run the command once more: it launches on the passage.
- [ ] **Step 12: Run both suites, then commit.** `feat: both apps answer passage links, bible-dev:// in Debug (verse basics 7.2)`

---

### Task 8: Copy Link, and links in notes (spec 7.2)

**Files:**
- Create: `SUI/PassageLinkClipboard.swift` (platform-neutral)
- Modify: `SUI/NotesColumnItem.swift` (`MarkupMenuItem` `:83-96`), `SUI/MarkupModel.swift` (`menuItems` `:442-455`, beside `copyWithReference` `:574-576`), `SUI/MarkupContextMenu.swift` (`:83-86`, `write` `:118-122`), `SUI/Phone/PhoneMarkupMenu.swift` (`make` `:72-75`, `phoneOrder` `:100-114`), `SUI/ReferenceLinker.swift` (`linked` `:118-132`)
- Test: create `T/PassageLinkClipboardTests.swift` (both suites) and `T/PhoneMarkupMenuTests.swift` (`#if os(iOS)`); modify `T/MarkupModelTests.swift`, `T/ReferenceLinkerTests.swift` (both suites) and `T/ReaderClickTests.swift` (macOS)

**Interfaces:**
- Consumes: `PassageLink` (Task 6).
- Produces:

```swift
// MarkupMenuItem gains `case copyLink`, after `.copyWithReference` in `MarkupModel.menuItems(for:)`.
extension MarkupModel {
    /// The link to the selection's verses, with no translation: it names a passage, not an edition.
    public func passageLink(for report: SelectionReport) -> PassageLink
}

/// What Copy Link puts on the pasteboard.
public struct PassageLinkClipboard: Equatable, Sendable {
    public let url: URL
    /// The URL as text: what a plain-text paste gives.
    public let plain: String
    /// The reference with an en dash in a range ("John 3:16–18"): what a rich-text paste shows.
    public let title: String
    /// `<a href="…">title</a>`, the title escaped.
    public let html: String
    public init(link: PassageLink, scheme: String)
    /// The title carrying the link, as RTF.
    public func rtf() -> Data?
}

// MarkupContextMenu (macOS): static func write(_ clipboard: PassageLinkClipboard, to pasteboard: NSPasteboard = .general)
//   declares `.string` (plain), `.rtf` and `.html`.
// PhoneMarkupMenu (iOS):     static func write(_ clipboard: PassageLinkClipboard, to pasteboard: UIPasteboard = .general)
//   one item: `public.utf8-plain-text`, `public.rtf`, `public.html`.
// PhoneMarkupMenu.phoneOrder becomes internal; `.copyLink` ranks after `.copyWithReference` and before `.share`.

extension ReferenceLinker {
    /// The bare passage links typed in `text` ("bible://jhn.3.16", "bible-dev:rom.8"), each
    /// without the sentence punctuation that follows it (. , ; : ! ? and a closing bracket or quotation mark).
    static func passageLinks(in text: String) -> [(range: Range<String.Index>, reference: Reference)]
}
```

Both menus title the item "Copy Link" with the symbol `link`, and copy with `PassageLink.appScheme`.

- [ ] **Step 1: Write the failing tests.** In the two pasteboard tests `clipboard` is `PassageLinkClipboard(link: PassageLink(reference: Matthew 5:2), scheme: "bible")`.

```swift
// MarkupModelTests
@Test func copyLinkFollowsCopyWithReferenceAndNamesTheVersesAlone() throws {
    let (model, _) = try makeModel()
    let one = report(model, verse: 2, 0, 3, text: "For")
    let items = model.menuItems(for: one)
    #expect(Array(items.suffix(5)) == [.copy, .copyWithReference, .copyLink, .share, .askAboutPassage])
    let link = model.passageLink(for: one)
    #expect(link.translationID == nil && link.url(scheme: "bible").absoluteString == "bible://mat.5.2")
    #expect(PassageLink(link.url(scheme: "bible-dev"))?.reference == one.selection.reference)      // a copied link round-trips
}
```

Also change `menuOffersRecolorAndRemoveInsideASingleHighlight` (`:103`) to expect `[.copy, .copyWithReference, .copyLink, .share, .askAboutPassage]`.

```swift
// PassageLinkClipboardTests
@Test func theClipboardCarriesTheURLAndTheTitledLink() throws {
    let john = Reference(book: BookCatalog.book(code: "JHN")!, chapter: 3, verse: 16, endVerse: 18)
    let clipboard = PassageLinkClipboard(link: PassageLink(reference: john), scheme: "bible-dev")
    #expect(clipboard.plain == "bible-dev://jhn.3.16-18" && clipboard.url.absoluteString == clipboard.plain)
    #expect(clipboard.title == "John 3:16\u{2013}18")
    #expect(clipboard.html == "<a href=\"bible-dev://jhn.3.16-18\">John 3:16\u{2013}18</a>")
    let rtf = String(decoding: try #require(clipboard.rtf()), as: UTF8.self)
    #expect(rtf.contains("HYPERLINK \"bible-dev://jhn.3.16-18\""))
    let one = PassageLinkClipboard(link: PassageLink(reference: Reference(book: john.book, chapter: 3, verse: 16)), scheme: "bible")
    #expect(one.title == "John 3:16" && one.plain == "bible://jhn.3.16")
}

// ReaderClickTests (macOS)
@Test func copyLinkWritesPlainTextAndRichText() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    MarkupContextMenu.write(clipboard, to: pasteboard)
    #expect(pasteboard.string(forType: .string) == "bible://mat.5.2")
    #expect(pasteboard.data(forType: .rtf) != nil && pasteboard.string(forType: .html)?.contains("Matthew 5:2") == true)
}

// PhoneMarkupMenuTests (iOS)
@Test func copyLinkSitsAfterCopyWithReferenceBehindTheChevron() throws {
    // A `MarkupModel` on an in-memory container, Matthew 5 loaded, a selection in verse 2 outside any highlight.
    let menu = PhoneMarkupMenu.make(for: report, model: model, penColorID: nil, share: { _ in }, collapse: {}, traits: .current)
    let names = menu.children.compactMap { ($0 as? UIAction)?.subtitle }
    #expect(names == ["Add Note", "Bookmark Verse 2", "Ask About This Passage", "Copy", "Copy with Reference", "Copy Link",
                      "Share…", "Look Up", "Translate"])
}

@Test func thePhonesCopyLinkWritesPlainTextAndRichText() throws {
    let pasteboard = UIPasteboard.withUniqueName()
    defer { UIPasteboard.remove(withName: pasteboard.name) }
    PhoneMarkupMenu.write(clipboard, to: pasteboard)
    #expect(pasteboard.string == "bible://mat.5.2")
    #expect(pasteboard.data(forPasteboardType: "public.rtf") != nil && pasteboard.data(forPasteboardType: "public.html") != nil)
}

// ReferenceLinkerTests
@Test func aPassageLinkInANoteIsALinkLikeAnyReference() throws {
    let blocks = NoteBodyText.blocks("See bible://jhn.3.16-18 and [this](bible-dev://rom.8).", book: nil,
                                     chapterCount: { Self.noteCounts[$0] })
    try #require(blocks.count == 1)
    #expect(ChatTurnRow.linkedReferences(in: blocks[0]).map(\.displayString) == ["John 3:16-18", "Romans 8"])
    // One to a chapter the book lacks stays text, as "Romans 17" does.
    let lacking = NoteBodyText.blocks("bible://rom.17", book: nil, chapterCount: { Self.noteCounts[$0] })
    #expect(ChatTurnRow.linkedReferences(in: lacking[0]).isEmpty)
}

@Test func aLinkAtTheEndOfASentenceLeavesTheFullStopOut() {
    let text = "Read bible://jhn.3.16. Then (bible-dev://rom.8), and bible:psa.23!"
    #expect(ReferenceLinker.passageLinks(in: text).map { String(text[$0.range]) } == ["bible://jhn.3.16", "bible-dev://rom.8", "bible:psa.23"])
    #expect(ReferenceLinker.passageLinks(in: "the bible: a library").isEmpty)
}
```

Add `JHN` and `ROM` to `ReferenceLinkerTests.noteCounts` if they are missing. A reply keeps its rules: add `#expect(refs("see bible://jhn.3.16").isEmpty)` to `repliesKeepTheirRules`.

- [ ] **Step 2: Run.** `--filter MarkupModelTests`, `PassageLinkClipboardTests`, `ReferenceLinkerTests`, `ReaderClickTests` and the iOS `PhoneMarkupMenuTests` FAIL to compile.
- [ ] **Step 3: Implement.**
  - `PassageLinkClipboard`: `rtf()` is an `NSAttributedString` of the title with `.link` set to the URL, written as `.rtf`.
  - Both menus gain the Copy Link item, each writing through its `write(_:to:)`.
  - `ReferenceLinker.linked`, for the note rules only and before its own pass: a run whose `.link` is a passage link is given `url(for:)` of its reference; each of `passageLinks(in:)` is linked the same way; one whose chapter is past `chapterCount` is left as text. Every such link is then a `scripture://` link, so the popover, Open, the phone's note sheet and VoiceOver's actions treat it as any other reference, and `NoteBodyText` does not change.
- [ ] **Step 4: Run.** The five suites pass; both whole suites pass.
- [ ] **Step 5: Commit.** `feat: Copy Link, and passage links in notes (verse basics 7.2)`

---

### Task 9: The Notes window's selected row (spec 8)

**Files:**
- Modify: `SUI/NotesBrowserView.swift` (`list`, `:118-146`), `SUI/NotesBrowserRow.swift`
- Test: `T/PaletteTests.swift` (both suites)

**Interfaces:**
- Consumes: `Color.accentWash`, `AppRadius.md`.
- Produces: `NotesBrowserRow(entry:isSelected:)`.

- [ ] **Step 1: Write the failing test.** The selected row puts the bookmark glyph and a note's links (`accent`) and a conversation's `sparkles` (`assistant`) on the wash; `ink.primary` and `ink.secondary` on it are held already.

```swift
/// The Notes window's selected row: its accent and plum marks stay visible on the wash.
@Test func theNotesWindowsSelectedRowKeepsItsMarksVisible() {
    expect(Palette.accent, on: Palette.accentWash, atLeast: 3)
    expect(Palette.assistant, on: Palette.accentWash, atLeast: 3)
}
```

- [ ] **Step 2: Run.** `--filter PaletteTests`. It is expected to pass at once (the pairings are new to the test, not to the palette). If an appearance fails, report it with its ratio; do not change a token.
- [ ] **Step 3: Draw the selection as the wash.** Keep `List(selection:)`, so ↑, ↓, Return, the double-click (`primaryAction`), Delete, the context menu and VoiceOver's selected trait stay the system's. Each row takes `.listRowBackground` of a `RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)` filled with `Color.accentWash` when `model.selectedID == entry.id` and `Color.clear` otherwise, in both `ForEach`es. Text colours do not change.
- [ ] **Step 4: See it.** Two pictures at least, and Sepia if time allows:
  - Not key: a temporary macOS test hosts `NotesBrowserView` (a model on an in-memory `MarkupStore` with three items, `selectedID` set) in an `NSWindow`, writes `contentView.bitmapImageRepForCachingDisplay` to a PNG in the scratchpad, in light and dark. Open them. Remove the test.
  - Key: in the Debug app, ⇧⌘N then ↓ through System Events, and capture the Notes window. If AeroSpace keeps it out of reach, say so.
  - The selected row must show the verdigris wash with rounded ends, its text in the same inks as its neighbours, and no blue or grey system bar behind or around it.
- [ ] **Step 5: Only if the system's selection still draws.** Replace the `List` with the notes column's own kind of list (`ScrollView`, `LazyVStack`, `columnRowSurface(isLit:reduceMotion:)`, `@FocusState`, `.onKeyPress` for ↑, ↓ and Return, `.onDeleteCommand`, a `.contextMenu` per row, `.onTapGesture(count: 2)`, section headers in `.headline`, and `.accessibilityAddTraits(.isSelected)` on the selected row), as `NotesColumnView.rows` does (`SUI/NotesColumnView.swift:56-88`). Record which way it was built for the spec's As built, and repeat Step 4.
- [ ] **Step 6: Run both suites, then commit.** `fix: the Notes window's selected row is the accent wash (verse basics 8)`

---

### Task 10: The credits catalogue and About (spec 9)

**Files:**
- Create: `SUI/Credits.swift`, `SUI/AboutView.swift` (both platform-neutral), `SUI/Licenses/GRDB-LICENSE.txt`, `SUI/Licenses/holybooks-LICENSE.txt`
- Modify: `Packages/ScriptureKit/Package.swift` (ScriptureUI's `resources`), `MAC/SettingsView.swift`, `SUI/Phone/PhoneSettingsScreen.swift`, `README.md` (Acknowledgements, `:204-206`)
- Test: create `T/CreditsTests.swift` (both suites; the README scan `#if os(macOS)`)

**Interfaces:**
- Produces:

```swift
public struct Credit: Identifiable, Hashable, Sendable {
    public enum Section: String, CaseIterable, Sendable {
        case scripture = "Scripture", headings = "Headings and titles", typefaces = "Typefaces"
        case icon = "Icon", videos = "Videos", software = "Software"
    }
    public let id: String
    public let section: Section
    public let name: String
    public let use: String
    public let notice: String
    public let license: String
    public let link: URL
    /// The licence's text among the module's resources ("Fonts/OFL-Literata.txt"), when About shows it.
    public let licenseFile: String?
    public let translationID: String?
    /// The bundled font files' prefix ("Literata", "SourceSerif4").
    public let fontFamily: String?
}
public enum Credits {
    public static let all: [Credit]
    public static func entries(in section: Credit.Section) -> [Credit]
    public static func licenseText(for credit: Credit) -> String?
    /// The prefixes of the `.ttf` files in ScriptureUI's own `Fonts` folder (a test's `Bundle.module` is the test target's).
    public static func bundledFontFamilies() -> Set<String>
}
public struct AboutView: View {
    public init(info: [String: Any]? = Bundle.main.infoDictionary)
    /// `CFBundleDisplayName`, else `CFBundleName`, else "Bible Carrel".
    static func appName(info: [String: Any]?) -> String
    /// "Version 0.2 (1)": `CFBundleShortVersionString` and `CFBundleVersion`.
    static func versionLine(info: [String: Any]?) -> String
}
```

**The catalogue's data**, the spec appendix's fifteen rows in its order. `name`, `use`, `license` and `link` are the appendix's Source, Used for, Licence and Link; `notice` is its Line without the outer quotation marks and without the bracketed remarks, which are notes to us and are not shown. Each `link` is the appendix's with `https://` before it.

```swift
// id, section, translationID / fontFamily / licenseFile where there is one
("esv", .scripture, "ESV")
    name: "English Standard Version", use: "Bible text", license: "Copyright", link: "crossway.org/permissions"
    notice: "ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway, a publishing ministry of Good News Publishers. All rights reserved. \"ESV\" and \"English Standard Version\" are registered trademarks of Crossway."
("nasb", .scripture, "NASB")
    name: "New American Standard Bible (1995)", use: "Bible text", license: "Copyright", link: "lockman.org"
    notice: "New American Standard Bible®, Copyright © 1960, 1971, 1977, 1995 by The Lockman Foundation. All rights reserved. www.Lockman.org"
("amp", .scripture, "AMP")
    name: "Amplified Bible, Classic Edition", use: "Bible text (the file labelled AMP)", license: "Copyright", link: "lockman.org"
    notice: "Amplified® Bible Classic (AMPC), Copyright © 1954, 1958, 1962, 1964, 1965, 1987 by The Lockman Foundation. www.Lockman.org"
("erv", .scripture, "ERV")
    name: "Easy-to-Read Version", use: "Bible text (ERV)", license: "Copyright", link: "bibleleague.org/license-agreement"
    notice: "HOLY BIBLE: EASY-TO-READ VERSION © Bible League International."
("asv", .scripture, "ASV")
    name: "American Standard Version (1901)", use: "Bible text", license: "Public domain", link: "ebible.org/eng-asv"
    notice: "Public domain."
("kjv", .scripture, "KJV")
    name: "King James Version", use: "Bible text, its book titles", license: "Public domain", link: "ebible.org/eng-kjv"
    notice: "Public domain (Crown rights apply in the United Kingdom). Titles from the text \"courtesy of the Crosswire Bible Society and eBible.org\"."
("web", .scripture, "WEB")
    name: "World English Bible", use: "Bible text", license: "Public domain", link: "ebible.org/eng-web"
    notice: "Public domain. \"World English Bible\" is a trademark of eBible.org."
("cpdv", .scripture, "CPDV")
    name: "Catholic Public Domain Version", use: "Bible text", license: "Public domain", link: "sacredbible.org"
    notice: "Original Edition. Ronald L. Conte Jr., translator and editor. Public domain."
("bsb", .headings)
    name: "Berean Standard Bible", use: "Section headings", license: "Public domain since 2023-04-30", link: "berean.bible/terms.htm"
    notice: "The Holy Bible, Berean Standard Bible, BSB is produced in cooperation with Bible Hub, Discovery Bible, OpenBible.com, and the Berean Bible Translation Committee. This text of God's Word has been dedicated to the public domain."
("holybooks", .software, licenseFile: "Licenses/holybooks-LICENSE.txt")
    name: "bobuk/holybooks", use: "The texts' file layout", license: "BSD 3-Clause", link: "github.com/bobuk/holybooks"
    notice: "Copyright (c) 2016, Grigory Bakunov. All rights reserved."
("literata", .typefaces, fontFamily: "Literata", licenseFile: "Fonts/OFL-Literata.txt")
    name: "Literata", use: "Reading typeface", license: "SIL OFL 1.1", link: "github.com/googlefonts/literata"
    notice: "Copyright 2017 The Literata Project Authors (https://github.com/googlefonts/literata)"
("sourceSerif4", .typefaces, fontFamily: "SourceSerif4", licenseFile: "Fonts/OFL-SourceSerif4.txt")
    name: "Source Serif 4", use: "Reading typeface", license: "SIL OFL 1.1", link: "github.com/adobe-fonts/source-serif"
    notice: "Copyright 2014 - 2023 Adobe (http://www.adobe.com/), with Reserved Font Name ‘Source’. All Rights Reserved. Source is a trademark of Adobe in the United States and/or other countries."
("3dicons", .icon)
    name: "3dicons", use: "The app icon's artwork", license: "CC0", link: "3dicons.co"
    notice: "Icon artwork from 3dicons by Vijay Verma."
("bibleProject", .videos)
    name: "BibleProject", use: "Links to its book overview videos", license: "Linking permitted on those conditions", link: "bibleproject.com/terms"
    notice: "Videos by BibleProject, at bibleproject.com."
("grdb", .software, licenseFile: "Licenses/GRDB-LICENSE.txt")
    name: "GRDB.swift", use: "Reading the Bible database", license: "MIT", link: "github.com/groue/GRDB.swift"
    notice: "Copyright (C) 2015-2025 Gwendal Roué"
```

Two placements are this plan's and go in As built: bobuk/holybooks sits under Software, since its licence text is shown as GRDB's is; and the King James Version's titles, with eBible.org, are credited on its own row under Scripture, so Headings and titles holds the Berean Standard Bible alone.

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func everyBundledTranslationHasACredit() {
    // The importer's list (`Sources/bible-importer/main.swift:6`), which a test cannot import.
    for id in ["AMP", "ASV", "CPDV", "ERV", "ESV", "KJV", "NASB", "WEB"] {
        #expect(Credits.all.contains { $0.translationID == id && $0.section == .scripture }, "\(id)")
    }
}

@Test(.needsRealBible) func everyTranslationInTheBuiltDatabaseHasACredit() throws {
    for id in try BenchmarkChapter.realStore().translations().map(\.id) {
        #expect(Credits.all.contains { $0.translationID == id }, "\(id)")
    }
}

@Test func everyBundledFontHasACreditWithItsLicenceText() throws {
    let families = Credits.bundledFontFamilies()
    #expect(families == ["Literata", "SourceSerif4"])
    for family in families {
        let credit = try #require(Credits.all.first { $0.fontFamily == family })
        #expect(Credits.licenseText(for: credit)?.contains("SIL OPEN FONT LICENSE") == true)
    }
}

@Test func theCatalogueIsTheAppendixAndClaimsNoPermission() throws {
    #expect(Credits.all.count == 15 && Set(Credits.all.map(\.id)).count == 15)
    #expect(Credit.Section.allCases.map(\.rawValue) == ["Scripture", "Headings and titles", "Typefaces", "Icon", "Videos", "Software"])
    #expect(Credit.Section.allCases.allSatisfy { !Credits.entries(in: $0).isEmpty })
    #expect(Credits.entries(in: .scripture).map(\.name).contains("Amplified Bible, Classic Edition"))
    #expect(Credits.all.allSatisfy { $0.link.scheme == "https" && !$0.notice.isEmpty })
    #expect(!Credits.all.contains { $0.notice.localizedCaseInsensitiveContains("used by permission") })
    #expect(!Credits.all.contains { $0.notice.contains("Matt") })          // no author line, no remarks to ourselves
    for credit in Credits.all where credit.licenseFile != nil {
        #expect((Credits.licenseText(for: credit) ?? "").count > 200, "\(credit.id)")
    }
    let grdb = try #require(Credits.all.first { $0.id == "grdb" })
    #expect(Credits.licenseText(for: grdb)?.contains("Permission is hereby granted, free of charge") == true)
    let holybooks = try #require(Credits.all.first { $0.id == "holybooks" })
    #expect(Credits.licenseText(for: holybooks)?.contains("Grigory Bakunov") == true)
}

@Test func aboutNamesTheAppAndItsVersion() {
    let info: [String: Any] = ["CFBundleDisplayName": "Bible Carrel", "CFBundleName": "X", "CFBundleShortVersionString": "0.2", "CFBundleVersion": "1"]
    #expect(AboutView.appName(info: info) == "Bible Carrel" && AboutView.versionLine(info: info) == "Version 0.2 (1)")
    #expect(AboutView.appName(info: nil) == "Bible Carrel")
}

#if os(macOS)
@Test func theReadmeAcknowledgesEverySource() throws {
    // README.md at the repository root, from `#filePath` as `SepiaModeTests` finds the sources.
    let acknowledgements = try Self.readmeSection("## Acknowledgements")
    for credit in Credits.all { #expect(acknowledgements.contains(credit.name), "\(credit.name)") }
    #expect(!acknowledgements.localizedCaseInsensitiveContains("used by permission"))
}
#endif
```

- [ ] **Step 2: Run.** `--filter CreditsTests` FAILS to compile.
- [ ] **Step 3: Add the licence texts and the catalogue.**
  - `GRDB-LICENSE.txt` is `Packages/ScriptureKit/.build/checkouts/GRDB.swift/LICENSE`, copied whole (there after any `swift test`).
  - `holybooks-LICENSE.txt` is the `LICENSE` file of github.com/bobuk/holybooks at the pinned commit `0dab245f361980d2af3f4075cba3fbe8c4fa31b2` (`Scripts/fetch-holybooks.sh`), copied whole. If its wording is not the BSD 3-Clause text with the copyright line above, keep the file's wording and report the difference.
  - `Package.swift`: ScriptureUI's resources become `[.copy("Fonts"), .copy("Kernels"), .copy("Licenses")]`.
  - `Credits.licenseText` reads `Bundle.module.resourceURL` plus the path (the handover: `url(forResource:withExtension:subdirectory:)` returned nil for a copied folder).
- [ ] **Step 4: Build `AboutView`** to spec 9's bullets (a grouped `Form`, the row's four lines in the spec's styles), one view for both apps. What the spec leaves open:
  - The head is the app's name in `.headline` `ink.primary` over the version line in `.callout` `ink.secondary`.
  - One `Section` per `Credit.Section`, titled with its raw value, in order; a row's lines are leading-aligned, `AppSpacing.xxs` apart.
  - The link is a `Link` shown as the address without `https://`, in `.callout` and the accent. The notice is selectable.
  - A licence text opens in place: a `DisclosureGroup` titled with `license`, the text in `.caption` `ink.secondary`, selectable.
- [ ] **Step 5: Put it in both Settings.**
  - `MAC/SettingsView.swift`: a last tab, `AboutView().tabItem { Label("About", systemImage: "info.circle") }.tag("about")`.
  - `SUI/Phone/PhoneSettingsScreen.swift`: `Page.about`, a last `link("About", systemImage: "info.circle", to: .about)`, its title "About" and its content `AboutView()`.
- [ ] **Step 6: Bring the README's Acknowledgements in line**: one sentence per section naming every source by its `name`, the copyright holders named as holders with nothing said of permission, the licence texts' places in the repository, and that Settings › About shows the same in the app.
- [ ] **Step 7: Run.** `CreditsTests` passes in both suites; both whole suites pass.
- [ ] **Step 8: See it.** Mac: build, quit and open the Debug app, `defaults write com.matthewfurr.ReadingThroughScripture.dev settingsTab about`, send ⌘, and capture the Settings window, light and dark; put `settingsTab` back after. iPhone: build and launch in the simulator, open Settings › About from the reader's menu, screenshot the top and a scrolled part. Check every section is there, nothing is clipped at the widths shown, and a disclosed licence text reads.
- [ ] **Step 9: Commit.** `feat: About credits every outside source (verse basics 9)`

---

### Task 11: Docs and whole-project verification

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, `docs/superpowers/specs/2026-11-16-milestone-10-verse-basics-design.md` (section 13)

**Interfaces:**
- Consumes: everything above.
- Produces: the documents in step with the code; a branch ready for Matt's list.

- [ ] **Step 1: `DESIGN.md`.**
  - Section 5, Reader: a click selects the verse quietly; the keys, pointing at the sheet for the list; the focus rule in two sentences.
  - Section 5, new entries: the **Shortcuts sheet** with its **keycap** component (the values Task 5 built) and **About** (the row's four lines and the disclosed licence).
  - Section 5, Notes browser: the selected row is `accent.wash` at radius `md`, key or not, text unchanged.
  - Section 5, SF Symbols inventory: add `keyboard`; `link` is also Copy Link, `info.circle` also About.
  - Section 7, Selection menu: a tap on a verse selects it and shows this menu; Copy Link sits after Copy with Reference, behind the chevron at the default size. Settings gains About.
- [ ] **Step 2: `DESIGN.json`.** The same facts where the file holds them (`components`, `extensions.sfSymbols`, `extensions.iphone`). `python3 -I -m json.tool DESIGN.json` must print it without error.
- [ ] **Step 3: `README.md`.**
  - Running the app, Keyboard (`:58`): the click, the reader's keys, and ⌘/ for the sheet that lists them all.
  - Markup: Copy Link. A short **Links** part: the format with the spec's examples, that both apps answer them, that Debug builds answer and copy `bible-dev://`, and that a link in a note is a link.
  - Settings: About. iPhone: a tap selects the verse; Settings › About.
- [ ] **Step 4: The spec's section 13, As built.** What was built, task by task, and every **(call)** made on the way, among them:
  - Whether the system's double tap narrowed the selection or Task 2's fallback was needed.
  - A verse's lines are hit at their full line height (Review Focus 1); a selection with no part on screen is nothing selected (Review Focus 2).
  - A verse past the chapter's end in a link opens the chapter at its start.
  - How the Notes window dropped the system selection.
  - The two placements in the credits, and that the appendix's bracketed remarks are not shown.
  - The shortcuts' labels follow the menus' names; UI copy keeps American spelling.
  - For Matt to weigh: accent link text on `accent.wash` measures about 4.3:1 in Light, in a selected Notes row as in the notes column today.
  - The new test counts, and anything a step could not see or drive.
- [ ] **Step 5: Run everything, one after another.** The package suite; the iOS suite; the Mac Debug build; the iOS Debug build. All pass and both builds succeed. Record the test counts.
- [ ] **Step 6: Look at each new surface once more on the final build** (spec 12): the phone's selected verse with its menu in the simulator; on the Mac the selected verse, the shortcuts sheet, the Notes window's selected row and About, in light and dark. Open every picture. Say plainly what was not seen.
- [ ] **Step 7: Leave the Mac Debug app running the final build.** `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`, then `open Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`. The controller runs `Scripts/install-phone.sh debug`.
- [ ] **Step 8: Commit.** `/usr/bin/git add DESIGN.md DESIGN.json README.md docs/superpowers/specs/2026-11-16-milestone-10-verse-basics-design.md`, then `docs: verse basics as built; DESIGN and README in step`.
- [ ] **Step 9: Hand Matt his list** (spec 12, "For Matt on his devices"), unchanged, with what this session could not check beside each item.

---

## Where each spec requirement is pinned

Each test is named for the bullet it pins. The ones a name does not make plain, and those pinned by a step and not a test:

| Spec | Pinned by |
|---|---|
| 4: handles, word snapping, press and hold | unchanged system behaviour and `textViewDidChangeSelection`; Task 2 Step 5; Matt's list |
| 4: the cards, the double tap, a stopped scroll, the pen, the thumb, VoiceOver | Task 2 `theRulesThatMakeATapNotAVerseTap`, `aTapWhileTheCardsAreOpenSelectsNothing`, `aMarginMarkIsNotAVerseTap` |
| 4: acts at once | Task 2 `theVerseTapActsAtOnceAndLeavesTheDoubleTapToTheSystem` |
| 5.1: a selection everywhere | Task 3 `aClickedVerseIsASelectionEverywhere`; Task 4 `escapeClearsTheSelectionAndTheQuestionMarkAsksForTheShortcuts` |
| 5.1: a right-click | unchanged (`menu(for:)`, `SUI/ChapterTextController.swift:1053-1065`) |
| 5.2: only with reader focus; Focus | Task 4 `keysTypedInAnotherFieldNeverReachTheReader` and cycle C |
| 5.2: ↑, ↓, Space and Page keys | no catalogue entry, so they reach `super.keyDown` (cycle A's uniqueness test lists every reader key) |
| 6: ways in, closing, the look | Task 5 Steps 5 and 7; `theShortcutsSheetIsACommand` |
| 6: every shortcut, one source | Task 4 cycle A |
| 7.2: cold launch, the app coming forward, no second window | Task 7 Steps 10 and 11 |
| 7.2: two schemes; name, identifier and signature | Task 6 `theBuildsSchemeComesFromItsInfoPlist`; Task 7 Steps 6 and 9 |
| 8: keyboard, double-click, Delete, context menu, selected trait | kept by `List(selection:)`; Task 9 Steps 4 and 5; Matt's list |
| 12: seen by eye | the seeing steps of Tasks 2, 4, 5, 7, 9 and 10; Task 11 Step 6 |
