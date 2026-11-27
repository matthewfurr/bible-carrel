# One Chapter at a Time, Book Thumb and Carry-Through Drawer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Return the reader to one chapter at a time, with the footer links at each chapter's end. Add a book thumb with a Liquid Glass loupe on both devices, and the iPhone's carry-through drawer, a deck of pages.

**Architecture:** The book window is narrowed to exactly one chapter:
- `ReaderDocument` always builds a one-chapter `BookLayout`.
- The code that grew, slid or anchored a multi-chapter window is deleted.
- Milestone 9's page styles, running head, Lectern numeral, landing and markup stay.

The two gestures sit on top of that:
- The thumb and drawer logic are pure, unit-tested types in `ScriptureUI`.
- The gestures are UIKit/AppKit recognizers in the controllers that report to SwiftUI overlays.
- The loupe is a SwiftUI view: a glass rim around a Metal `layerEffect`.

**Tech Stack:** Swift 6.2, SwiftUI with Liquid Glass (`glassEffect`, `GlassEffectContainer`), TextKit 2, UIKit and AppKit gesture recognizers, a Metal shader through `ShaderLibrary`, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-12-single-chapter-reader-and-quick-hops-design.md`. It supersedes the book-long scroll of `docs/superpowers/specs/2026-11-12-reader-page-styles-and-book-scroll-design.md`.

Below, `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI` and `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`.

## Global Constraints

**UI rules (CLAUDE.md, PRODUCT.md, DESIGN.md)**
- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change. Use the `/impeccable-swift` skill for UI work.
- No fixed-point fonts in chrome. `.font(.system(size:))` is allowed only where DESIGN.md names an exception. Sizes tied to text use `@ScaledMetric`.
- No inline colors. Use `Palette` / `Color.ink*` / `Palette.accent.platformColor`, and add every new color pairing to `PaletteTests`.
- Spacing and radii come from `AppSpacing` and `AppRadius` (`Metrics.swift`).
- No card by reflex: a deck page is a quiet sheet with its numeral, not a gray fill with a hairline and a shadow.

**Code rules**
- TextKit 2 only on this branch: never touch `textView.layoutManager`.
- Deletes remain undoable. Nothing in this work asks for confirmation.

**Values from the spec**
- **Drawer thresholds** (spec 4.3; tune on a device, keep them as named constants):
  - It opens on a pull of `80` points past the stopped edge.
  - It opens on arrival at an edge faster than `2500` points per second.
- **Drawer landing** (spec 3.2):
  - Forward: at the chosen chapter's start.
  - Back one chapter after a pull at the top: at the previous chapter's end.
  - Back one chapter chosen after a fast scroll: at its start.
  - Back more than one chapter: at the start.
- **Thumb landing:** at the chosen chapter's start. Letting go on the current chapter does nothing.
- **History** (spec 4.2): a drawer turn pushes an entry, as Next and Previous do. A thumb jump pushes an entry, as choosing a chapter in the Library does.
- **Book ends:** the drawer and the thumb never cross books. The footer links and ⌥⌘← / ⌥⌘→ do.
- **No headings on the thumb:** the loupe shows the chapter number only.
- **Accessibility:**
  - Reduce Motion: no overshoot or spring; things fade in place.
  - Reduce Transparency: opaque materials, and the loupe's number is not bent.
- **Device scope:** the drawer is iPhone only. The thumb and loupe are on the iPhone and the Mac.

**Process**
- Use `/usr/bin/git`, one git command per Bash call, with no `cd &&`, loops or variables in git calls.
- Commit on `milestone-9-reader` only. Never push or merge.
- Build Debug only, never `Scripts/install-app.sh` or the Release store. Install with `Scripts/install-phone.sh debug` and by building the Mac Debug scheme.
- **Test commands:**
  - Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit`
  - iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`
  - Both app builds, as in README.md.

## Review Focus

1. **A firm, ordinary scroll that comes to rest at the chapter's end never opens the drawer.** Only a pull past the stopped edge, or an arrival above the speed threshold, opens it. Pinned in Task 10 (`aScrollThatStopsAtTheEndDoesNotOpenTheDrawer`).
2. **At the book's first or last chapter there is nothing to carry through to.** Pulling there opens no drawer and the thumb's range ends at the book's ends. Pinned in Task 9 (`aDeckAtTheBooksEndHasNoPages`) and Task 5 (`theThumbCoversExactlyTheBooksChapters`).
3. **A translation that lacks a chapter** (Next and Previous already skip those): the deck and the thumb skip it too, never landing on a missing chapter. Pinned in Task 5 (`theThumbSkipsChaptersTheTranslationLacks`) and Task 9 (`theDeckSkipsChaptersTheTranslationLacks`).
4. **The highlighter pen is on, or a margin mark is under the finger, near the right edge.**
   - A long press in the edge zone opens the thumb and never paints.
   - A tap on a mark still acts on the mark.
   - A paint stroke that starts in the text and drags to the edge never opens the thumb.
   - Pinned in Task 7 (`theEdgeLongPressOpensTheThumbNotThePen`, `aTapOnAMarginMarkStillActsOnTheMark`).
5. **A drawer turn or a thumb jump during a lookup behaves as Next or choosing a chapter.** It ends the lookup and pushes history; it never strands the reader in lookup mode. Pinned in Task 8 (`aTurnDuringALookupEndsItAndPushesHistory`).

---

## Part 1: One chapter at a time

### Task 1: `ReaderDocument` shows exactly one chapter

**Files:**
- Modify: `SUI/ReaderDocument.swift`
- Delete: `SUI/BookWindow.swift`
- Modify: `Apps/Shared/AppModels.swift:80-82`
- Modify: `SUI/ReadingPositionRule.swift`. Delete `BookLayout.isExtension(from:to:)`, `BookLayout.continues(from:to:)` and `paragraphCounts()`.
- Test: `T/ReaderDocumentTests.swift`. Delete `T/BookWindowTests.swift`.

**Interfaces:**
- Produces:
  - `ReaderDocument.init(store: BibleStore)`, the only initialiser.
  - `ReaderDocument.show(_ book: BookText, target: ChapterLocation, typography: ReaderTypography)`, which always builds `target.chapter...target.chapter`.
  - `ReaderDocument.window: ClosedRange<Int>?`, now a single chapter.
- Removed: `ReaderDocument.extend(_:)`, `includesBookEnd`, `BookEdge`, `BookWindow`, `BookWindow.Budget`.

- [ ] **Step 1: Write the failing tests.** In `ReaderDocumentTests`, replace the window and budget tests with:

```swift
@Test func showingAChapterBuildsThatChapterAlone() throws {
    let document = ReaderDocument(store: try Fixtures.store())
    document.show(try Fixtures.john(), target: ChapterLocation(book: "JHN", chapter: 3), typography: .default)
    #expect(document.window == 3...3)
    #expect(document.layout?.chapters == 3...3)
    #expect(document.layout?.sections.count == 1)
}

@Test func showingAnotherChapterRebuildsWithOnlyThatChapter() throws {
    let document = ReaderDocument(store: try Fixtures.store())
    let john = try Fixtures.john()
    document.show(john, target: ChapterLocation(book: "JHN", chapter: 3), typography: .default)
    document.show(john, target: ChapterLocation(book: "JHN", chapter: 4), typography: .default)
    #expect(document.layout?.chapters == 4...4)
}

@Test func chapterOneOpensWithTheTitleBlockAndLaterChaptersWithTheirLabel() throws {
    let document = ReaderDocument(store: try Fixtures.store())
    let john = try Fixtures.john()
    func opening(_ chapter: Int) throws -> String {
        document.show(john, target: ChapterLocation(book: "JHN", chapter: chapter), typography: .default)
        let layout = try #require(document.layout)
        return (layout.attributedString.string as NSString).substring(with: layout.sections[0].openingRange)
    }
    #expect(try opening(1).contains("John"))
    #expect(try !opening(3).contains("John"))
}
```

Use the fixture helpers that `ReaderDocumentTests` already uses for the store and John; keep their names.

- [ ] **Step 2: Run them.** `swift test --package-path Packages/ScriptureKit --filter ReaderDocumentTests` must FAIL. The window is wider than one chapter, and `extend` still exists.
- [ ] **Step 3: Implement.**
  - In `show`, the window is `target.chapter...target.chapter`. Rebuild when the book, the chapter, the headings or the typography changed.
  - Delete `budget`, `paragraphs`, `counts`, `paragraphCounts`, `extend`, `includesBookEnd` and `BookWindow.swift`.
  - Update both `AppModels` constructions to `ReaderDocument(store:)`.
  - Fix every compile error that follows by deleting the caller's use. Those callers are reworked in Tasks 3 and 4: pass `false` or remove the argument there for now.
  - Keep `typographyChangeRebuildsTheSameWindow`, renamed `typographyChangeRebuildsTheSameChapter`.
- [ ] **Step 4: Run the package tests.** The new tests pass. Delete or rewrite every test that fails only because it assumes a multi-chapter window: `BookWindowTests`, and the ReaderDocument, ReadingPositionRule and BookLayout tests listed in the spec survey. Keep a test if its behaviour still holds for one chapter.
- [ ] **Step 5: Commit.** `refactor: the reader document shows one chapter`

### Task 2: Navigation, markup and the running head for one chapter

**Files:**
- Modify: `SUI/NavigationModel.swift` (`reportReadingPosition` L441-458, the lookup doc at L69)
- Modify: `SUI/MarkupModel.swift` (`follow(_:in:)` L163)
- Modify: `SUI/RunningHead.swift`, `SUI/RunningHeadView.swift`, `SUI/RunningHeadTitle.swift`, `SUI/ReadingPositionRule.swift` (`ReadingPositionRule.resolve`)
- Test: `T/NavigationModelTests.swift`, `T/MarkupModelTests.swift`, `T/MarkupNavigationTests.swift`, `T/MarginMarksTests.swift`, `T/RunningHeadTests.swift`, `T/ReadingPositionRuleTests.swift`

**Interfaces:**
- Consumes: Task 1's one-chapter `ReaderDocument`.
- Produces:
  - `NavigationModel.reportReadingPosition(_ verse: VerseLocation)` ignores a verse outside the open chapter. Inside the chapter it updates the verse only, as on `main`.
  - `RunningHead.state(band: ChapterBand, headLineY:, opensBook: Bool, reducesMotion:, topHeadLineY:)` takes one band. It returns `RunningHeadState { chapter, progress, headOpacity }`; `textOpacity` and `textRise` are deleted.

- [ ] **Step 1: Write the failing tests.**
  - `reportingAVerseInAnotherChapterIsIgnored`: open John 3, report John 4:1, expect `location.chapter == 3` and no history change.
  - `theHeadNamesTheOpenChapterAndItsProgress`: one band; the head is hidden at the top of chapter 1, full otherwise; progress 0 to 1 through the band.
  - `aLookupInTheChapterEndsAfterFiveLines`: keep the `main` behaviour, five lines within one chapter.
- [ ] **Step 2: Run them.** They FAIL to compile (the new `RunningHead.state` signature) or fail on the chapter-change path.
- [ ] **Step 3: Implement.**
  - Remove the chapter-change branch of `reportReadingPosition` and `history.updateCurrentLocation` (delete it if it has no other caller).
  - Reduce `RunningHead` to one band, deleting `handOffFade`, the hand-over and `endChapter`.
  - Delete `RunningHeadView`'s `textOpacity` and `textRise`, and its `.clipped()` if nothing else needs it.
  - `RunningHeadTitle` reads the open chapter.
  - `ReadingPositionRule.resolve` drops the "air above a label names the chapter before" and end-chapter rules.
  - `MarkupModel.follow` loads the open chapter.
- [ ] **Step 4: Run the package tests.** Pass. Delete the cross-chapter tests listed for these files in the survey (for example `scrollingIntoTheNextChapterMovesThePlaceWithoutHistory`, `crossingAChapterLabelDoesNotEndALookup`, `theHeadHandsOverToTheNextChaptersOpening`, `aBookWindowLoadsEachChaptersMarkup`).
- [ ] **Step 5: Commit.** `refactor: navigation, markup and the head follow the open chapter`

### Task 3: The Mac reader shows one chapter, with the chapter's footer links

**Files:**
- Modify: `SUI/ChapterTextController.swift`, `SUI/ChapterTextController+Chrome.swift`, `SUI/ChapterTextView.swift`, `SUI/ReaderView.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/MainWindowView.swift` (the `ReaderView(...)` call)
- Test: `T/ChapterTextControllerTests.swift`, `T/ReaderChromeTests.swift`, `T/DropNumeralTests.swift`, `T/ReaderBenchmarkTests.swift`

**Interfaces:**
- Consumes: Tasks 1-2.
- Produces:
  - `struct ChapterEndLinks: View { let previousTitle: String?; let nextTitle: String?; let onPrevious: () -> Void; let onNext: () -> Void }` in `SUI/ReaderView.swift`. It replaces `BookEndLink`; the phone reuses it in Task 4. Labels: `Label("Previous: \(title)", systemImage: "arrow.left").labelStyle(.titleAndIcon)` and `Label("Next: \(title)", systemImage: "arrow.right").labelStyle(.trailingIcon)`.
  - `ReaderView.init(...)` gains `previousChapterTitle: String?`, `onPreviousChapter`, `nextChapterTitle: String?`, `onNextChapter`. These replace `nextBookTitle` and `onNextBook`.
  - `NavigationModel.nextChapter` and `previousChapter` already cross books, so the titles name the next book at a book's end.

- [ ] **Step 1: Write the failing tests.**
  - In `ReaderChromeTests`:
    - `theChapterLinksShowAsTheChaptersFootComesIntoView`: the reveal rule from `theBookEndLinkShowsAsItsSpaceComesIntoView`, now for every chapter.
    - `theFootReservesTheLinksHeightInEveryChapter`
  - In `ChapterTextControllerTests`:
    - `oneChapterKeepsEveryLineThroughRepeatedUpwardScrolls`: Psalm 119 (`BenchmarkChapter.psalm119()`), Printed and Lectern, in a real `NSWindow` (`isReleasedWhenClosed = false`). Three passes from the bottom to the top in 30-point steps, each followed by `layoutIfNeeded`, `displayIfNeeded` and `CATransaction.flush()`. Assert that `usageBoundsForTextContainer.maxY` never moves by more than 2 points, and that the running head's chapter stays 119.
- [ ] **Step 2: Run them.** FAIL. The links exist only at the book's end, and `ChapterEndLinks` is undefined.
- [ ] **Step 3: Implement.**
  - **Delete from the controller:**
    - `onNeedsChapters`, `requestChaptersNearEdges`, `requestedEdges`
    - `Anchor`, `captureAnchor` and `restore` (the extension path in `update`)
    - `includesBookEnd`, `isAtBookEnd` and `endChapter`
    - the book-wide numeral bookkeeping: `numeralPlacements` and `placeNumeralsNearViewport`. One chapter has one numeral, placed in `refreshDropNumerals`.
  - **Keep and generalise** the bottom reserved space and its reveal (`bottomInset`, `onBookEndReveal` renamed `onFootReveal`, `updateBookEndReveal` renamed `updateFootReveal`) so the links show at every chapter's foot.
  - **Decide by the tests whether the hold machinery is still needed** (`heldChapter`, `heldClipY`, `heldClipSize`). It still matters if a short chapter's landing can only rest at the end. Delete it if no single-chapter test needs it.
  - **Bands:** `chapterBands` becomes the one band for the head.
  - **Delete `ChapterTextView`'s** `includesBookEnd` and `onNeedsChapters`.
  - **`ReaderView`:**
    - Shows `ChapterEndLinks` in the footer overlay. Each link sits in the reserved foot space, styled as `BookEndLink` was on the Mac (`.body.weight(.medium)`, `Color.accent`).
    - `.help("Previous Chapter (⌥⌘←)")` and `.help("Next Chapter (⌥⌘→)")`.
    - `MainWindowView` passes `model.previousChapter.map(model.title(for:))` and the next-chapter equivalent, with `goToPreviousChapter` / `goToNextChapter`.
  - **Tests:**
    - Update the DropNumeral tests to one chapter. Delete `everyPsalmsNumeralStaysInItsOwnNotchThroughReflowAndSizeChanges`, or rewrite it for Psalms 108 and 119 loaded one at a time.
    - Rewrite the whole-Psalms benchmarks as Psalm 119 benchmarks: load within 1 second, a scroll frame at a median under 1 ms in the real-window form of `scrollingLecternCostsAboutWhatPrintedDoesPerFrame`.
    - Delete the window tests listed in the survey (for example `extendingTheWindowUpwardKeepsTheTextStill`, `scrollingToTheTopAsksForEarlierChapters`).
- [ ] **Step 4: Run the package tests and the Mac app build.** Pass and BUILD SUCCEEDED.
- [ ] **Step 5: Commit.** `refactor: the Mac reader shows one chapter with its footer links`

### Task 4: The iPhone reader shows one chapter, with the chapter's footer links

**Files:**
- Modify: `SUI/Phone/PhoneChapterTextController.swift`, `SUI/Phone/PhoneChapterTextController+Chrome.swift`, `SUI/Phone/PhoneChapterTextView.swift`, `SUI/Phone/PhoneReaderScreen.swift`, `SUI/Phone/PhoneReaderChrome.swift`
- Test: `T/PhoneChapterTextControllerTests.swift`, `T/PhoneShellModelTests.swift`, `T/PenModelTests.swift`
- Docs: `DESIGN.md`, `README.md`, the milestone 9 plan

**Interfaces:**
- Consumes: Tasks 1-3 (`ChapterEndLinks`).
- Produces: `PhoneChapterTextController.update(layout:typography:scrollTarget:decorations:marginMarks:footer:)`, unchanged in shape. The footer is now `ChapterEndLinks` on every chapter, inside the text view's foot, as on `main`. On a narrow width it is a `ViewThatFits` of an HStack, then a VStack.

- [ ] **Step 1: Write the failing tests.**
  - `everyChapterEndsWithItsLinks`
  - `oneChapterKeepsEveryLineThroughRepeatedUpwardScrolls`: the phone form of Task 3's test, Psalm 119 in the simulator.
- [ ] **Step 2: Run them.** `xcodebuild test … -only-testing:ScriptureUITests/PhoneChapterTextControllerTests` FAILS.
- [ ] **Step 3: Implement.**
  - **Delete from the phone controller and wrapper**, mirroring Task 3:
    - `onNeedsChapters`, `requestChaptersNearEdges(atRest:)`
    - the `scrollViewDidEndDecelerating` and `scrollViewDidEndDragging` bodies that only slid the window
    - `Anchor`, `captureAnchor`, `restore`, `BookLayout.continues`
    - `includesBookEnd`, `isAtBookEnd`, `endChapter`
    - `PhoneReaderChrome.bookEndReveal`, `bookEndOpacity`, `isBookEndLive`
  - **The footer:**
    - The footer view is `ChapterEndLinks` with `navigation.previousChapter` and `navigation.nextChapter`. The style follows `main`'s phone footer (`.callout`, `Color.inkSecondary`).
    - Keep `bottom = verticalInset + footerHeight` in `applyGeometry`.
  - **Tests:** delete the window tests listed in the survey (for example `oneSlideOfThePhonesWindowEndToEnd`, `thePageAsksForChaptersEarlyOnlyAtRest`, `readingOnSlidesThePhonesWindowAndKeepsTheTextStill`).
  - **Docs:**
    - **DESIGN.md:** replace "one scroll per book", the end-of-book link and the running head's hand-over with one chapter and its footer links.
    - **README.md:** update the reader lines.
    - **Milestone 9 plan:** add a "Superseded" note under its Decisions naming Tasks 7-16 and 20's book-window parts, Review Focus items 1, 2, 4 and 5, and the whole-Psalms budgets, with a pointer to this plan and the spec.
- [ ] **Step 4: Run the iOS tests, the package tests and both app builds.** All pass.
- [ ] **Step 5: Commit.** `refactor: the iPhone reader shows one chapter with its footer links`

## Part 2: The book thumb and loupe

### Task 5: The thumb's logic and the loupe

**Files:**
- Create:
  - `SUI/BookThumb.swift` (the logic)
  - `SUI/LoupeView.swift`
  - `SUI/LoupeRenderer.swift` (the Core Image lens)
- Package.swift is unchanged: the loupe uses Core Image, not Metal (ruling, 2026-11-13: this Mac has no Metal Toolchain, and installing it needs Matt).
- Test: `T/BookThumbTests.swift`, `T/LoupeTests.swift`

**Interfaces:**
- Produces:

```swift
public struct BookThumb: Equatable, Sendable {
    public let chapters: [Int]          // the chapters this translation has, ascending
    public let current: Int
    public init(chapters: [Int], current: Int)
    public var isShown: Bool                         // chapters.count > 1
    public func chapter(atFraction fraction: Double) -> Int   // 0 = top of the track, 1 = bottom; clamps
    public func fraction(of chapter: Int) -> Double  // the tick's position
    public func landing(on chapter: Int) -> ScrollTarget?    // nil when chapter == current
}
struct LoupeView: View { let number: Int; let typography: ReaderTypography }  // the glass lens; numerals only; the reader's style and chosen face
```

`chapter(atFraction:)` divides the track into `chapters.count` equal bands and returns the chapter whose band holds the fraction. `fraction(of:)` returns that band's centre. `landing(on:)` returns `ScrollTarget(chapter: chapter, verse: 1)`.

- [ ] **Step 1: Write the failing tests** in `BookThumbTests`:

```swift
@Test func theThumbCoversExactlyTheBooksChapters() {
    let thumb = BookThumb(chapters: Array(1...150), current: 73)
    #expect(thumb.chapter(atFraction: 0) == 1)
    #expect(thumb.chapter(atFraction: 1) == 150)
    #expect(thumb.chapter(atFraction: -0.2) == 1 && thumb.chapter(atFraction: 1.4) == 150)
    #expect(thumb.chapter(atFraction: thumb.fraction(of: 73)) == 73)
}
@Test func theThumbSkipsChaptersTheTranslationLacks() {
    let thumb = BookThumb(chapters: [1, 2, 4, 5], current: 2)
    #expect(!(0...100).map { thumb.chapter(atFraction: Double($0) / 100) }.contains(3))
}
@Test func lettingGoOnTheCurrentChapterDoesNothing() {
    let thumb = BookThumb(chapters: Array(1...21), current: 3)
    #expect(thumb.landing(on: 3) == nil)
    #expect(thumb.landing(on: 5).map { ($0.chapter, $0.verse) } == (5, 1))
}
@Test func aOneChapterBookHasNoThumb() { #expect(!BookThumb(chapters: [1], current: 1).isShown) }
```

`ScrollTarget` has a token, so compare its fields rather than the value.

- [ ] **Step 2: Run them.** FAIL: `BookThumb` is undefined.
- [ ] **Step 3: Implement `BookThumb`.** Then `LoupeView`:
  - **The rim:** `Circle()` with `.glassEffect(.clear, in: Circle())`.
  - **The number** in the reader's numeral face, from its `ReaderTypography` (`DropNumeral.font(for:)` for Lectern, the style's chapter-label face otherwise, in the face the reader chose), in `Palette.accent`, sized with `@ScaledMetric(relativeTo: .title)`. The base is `.title`'s size: modest, per Matt.
  - **The bend:** `LoupeRenderer` (Core Image) renders the numeral with `ImageRenderer` at the display scale, applies `CIFilter.bumpDistortion()` centred at the disc's radius (a gentle barrel magnification), and splits the red and blue channels by up to 1.5 points at the rim, falling to 0 at the centre (`CIColorMatrix` copies scaled about the centre, recombined with `CIMaximumCompositing`). One shared `CIContext`; cached per number, face, size, appearance and scale.
  - **Reduce Transparency:** `@Environment(\.accessibilityReduceTransparency)` drops the lens and the glass and draws the plain number on an opaque `Palette` disc.
  - **Fallback:** if the lens cannot be rendered, the view draws the plain number in the glass. The tests check the lens's size at the display scale and that the cache returns the same image for the same key.
  - **Previews:** add an `#Preview` with three numbers on each page style.
- [ ] **Step 4: Run the package tests, both app builds and the iOS tests.** Pass and BUILD SUCCEEDED.
- [ ] **Step 5: Commit.** `feat: the book thumb's logic and the glass loupe`

### Task 6: The Mac book thumb

**Files:**
- Create: `SUI/BookThumbView.swift`, shared by both devices: the track, its ticks, the lit current tick, and the loupe placement.
- Modify: `SUI/ReaderView.swift` (a trailing overlay), `Apps/Mac/ReadingThroughScripture/MainWindowView.swift` (pass the chapters and the open action)
- Test: `T/BookThumbTests.swift` (the view's model only), plus a manual check

**Interfaces:**
- Consumes: Task 5 `BookThumb`, `LoupeView`.
- Produces: `struct BookThumbView: View { let thumb: BookThumb; let style: PageStyle; @Binding var dragging: Int?; let onLand: (Int) -> Void }`.
  - It draws a 2-point track with a tick per chapter (`Color.inkTertiary` or the nearest existing ink token) and the current tick in `Palette.accent`.
  - While dragging, it shows `LoupeView(number: dragging, typography: typography)` (the reader's typography) 12 points to the track's left, centred on the finger or pointer.
  - On the Mac it is placed inside the vertical scroller: the overlay's trailing padding is `NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle)`. It sits at the reader's right edge, so beside the notes column when that is open.

- [ ] **Step 1: Write the failing test.** `theDragMapsTheTrackToChapters`: a pure helper `BookThumbView.chapter(forY:inTrackHeight:thumb:)` returns `thumb.chapter(atFraction: y / height)`.
- [ ] **Step 2: Run it.** It FAILS.
- [ ] **Step 3: Implement.**
  - **Visibility (spec 4.4):** the track fades in when the pointer is within 40 points of the reader's right edge (`onContinuousHover`) or while the scroller is in use, and fades out 1 second later.
  - **The drag:** a `DragGesture(minimumDistance: 0)` on the track sets `dragging`.
  - **Haptic:** each chapter change performs `NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)`.
  - **Release:** calls `onLand(chapter)` when `thumb.landing(on:)` is non-nil. `MainWindowView` maps that to `model.open(ChapterLocation(book:, chapter:))`, which pushes history.
  - **Accessibility:** `.accessibilityElement()`, `.accessibilityLabel("Chapter \(n) of \(count)")`, `.accessibilityAdjustableAction` (up and down move a pending chapter), and `.accessibilityAction { onLand(pending) }`.
  - **One-chapter books:** hidden when `!thumb.isShown`.
  - **Motion:** the loupe springs in with `.spring(response: 0.35, dampingFraction: 0.7)`, or a fade under Reduce Motion.
- [ ] **Step 4: Run the package tests and the Mac build. Then check by hand in the Mac Debug app:**
  - Psalms: drag from 73 to 76, then land.
  - Jude: no thumb.
  - The notes column open.
  - Reduce Motion.
  - VoiceOver adjust.
- [ ] **Step 5: Commit.** `feat: the Mac book thumb`

### Task 7: The iPhone book thumb

**Files:**
- Modify:
  - `SUI/Phone/PhoneChapterTextController.swift`: `showsVerticalScrollIndicator = false`, the edge long press, `gestureRecognizerShouldBegin` / `shouldReceive`
  - `SUI/Phone/PhoneChapterTextView.swift`, `SUI/Phone/PhoneReaderScreen.swift`: the overlay
- Test: `T/PhoneChapterTextControllerTests.swift`

**Interfaces:**
- Consumes: Tasks 5-6 (`BookThumbView`).
- Produces:
  - `PhoneChapterTextController.onThumb: (ThumbGesture) -> Void`, with `enum ThumbGesture: Equatable { case began(y: CGFloat), moved(y: CGFloat), ended(y: CGFloat), cancelled }`. The y is in the reader page's coordinates.
  - `static let thumbEdgeZone: CGFloat = 28` (call), measured from the text view's right edge.
  - `static let thumbHold: TimeInterval = 0.3`.

- [ ] **Step 1: Write the failing tests.**
  - `theEdgeLongPressOpensTheThumbNotThePen`: with the pen on, a long press at `x = width - 10` reports `.began` and the paint gesture does not begin.
  - `aTapOnAMarginMarkStillActsOnTheMark`: a mark at the right edge still receives its tap.
  - `aPressInsideTheTextNeverOpensTheThumb`: a long press at the column's centre reports nothing.
  - `theSystemScrollIndicatorIsHidden`
- [ ] **Step 2: Run them.** `xcodebuild test … -only-testing:ScriptureUITests/PhoneChapterTextControllerTests` FAILS.
- [ ] **Step 3: Implement.**
  - **The recogniser:** a `UILongPressGestureRecognizer(minimumPressDuration: thumbHold)` on the text view. `shouldReceive` accepts only touches with `x >= bounds.width - thumbEdgeZone`.
  - **Against the pen:** `paintGesture` requires the thumb recogniser to fail when the touch starts in the zone; `gestureRecognizerShouldBegin` returns false for paint in the zone. A paint stroke that began in the text is never claimed.
  - **Against the marks:** taps on margin marks are unaffected, because the recogniser only begins after the hold.
  - **The overlay:** `PhoneReaderScreen` shows `BookThumbView` on `.began` and moves its `dragging` chapter on `.moved`. On `.ended` it lands through `navigation.open(...)`; on `.cancelled` it hides.
  - **Haptic:** each chapter change gives `UISelectionFeedbackGenerator().selectionChanged()`.
  - **Accessibility:** the VoiceOver adjustable element from Task 6 is present on the phone as an accessibility element at the trailing edge.
- [ ] **Step 4: Run the iOS tests and the iOS build, then check in the simulator:**
  - Psalms: drag from 73 to 76.
  - The pen on.
  - A bookmark at the edge.
  - Reduce Transparency.
- [ ] **Step 5: Commit.** `feat: the iPhone book thumb`

## Part 3: The carry-through drawer (iPhone)

### Task 8: Landing at a chapter's end

**Files:**
- Modify:
  - `SUI/ScrollTarget.swift`
  - `SUI/NavigationModel.swift`
  - `SUI/Phone/PhoneChapterTextController.swift` (`performPendingScroll`)
  - `SUI/ChapterTextController.swift` (the same, so both stay alike)
- Test: `T/NavigationModelTests.swift`, `T/PhoneChapterTextControllerTests.swift`

**Interfaces:**
- Produces:
  - `ScrollTarget.init(chapter: Int, verse: Int, atEnd: Bool = false)` and `public let atEnd: Bool`.
  - `NavigationModel.turn(to location: ChapterLocation, atEnd: Bool)`: it ends a lookup, pushes history as `open` does, and sets `scrollTarget = ScrollTarget(chapter:, verse: 1, atEnd:)`.
  - A target with `atEnd` lands with the chapter's foot at the bottom: the content offset is `maxOffsetY`, or `maxY` on the Mac.

- [ ] **Step 1: Write the failing tests.**
  - `turningBackToTheEndLandsAtTheFoot`: the phone controller is given `ScrollTarget(chapter: 2, verse: 1, atEnd: true)` and its offset equals `maxOffsetY`.
  - `aTurnPushesHistory`: Back after `turn(to:atEnd:)` returns.
  - `aTurnDuringALookupEndsItAndPushesHistory`: lookup John 15, `turn(to: John 16)`, expect no lookup and Back to John 15.
- [ ] **Step 2: Run them.** FAIL.
- [ ] **Step 3: Implement.** Use `turn` in place of `open` for the drawer only.
- [ ] **Step 4: Run the package tests and the iOS tests.** Pass.
- [ ] **Step 5: Commit.** `feat: a turn can land at a chapter's end`

### Task 9: The drawer's deck and landing rules

**Files:**
- Create: `SUI/Phone/CarryThrough.swift`
- Test: `T/CarryThroughTests.swift`

**Interfaces:**
- Produces:

```swift
enum CarryThrough {
    static let pullThreshold: CGFloat = 80        // points past the stopped edge
    static let arrivalSpeed: CGFloat = 2500       // points per second
    static let pageTravel: CGFloat = 56           // pull per page once open (call; tune on device)
    enum Edge: Equatable { case top, bottom }
    enum Opening: Equatable { case pull, arrival }
}
struct CarryThroughDeck: Equatable {
    let edge: CarryThrough.Edge
    let opening: CarryThrough.Opening
    let chapters: [Int]                 // the chapters this translation has
    let current: Int
    private(set) var front: Int
    init?(edge:, opening:, chapters:, current:)   // nil when there is no chapter that way
    var pages: [Int]                    // front first, then the next three that way (fewer near the book's end)
    mutating func flip(by pages: Int)   // toward the edge's direction; negative flips back; stops at the book's end and at `current`
    var isHome: Bool                    // front == current: letting go cancels
    func landing(on chapter: Int) -> (chapter: Int, atEnd: Bool)?   // nil when chapter == current
}
```

`landing` follows the spec exactly:
- A chapter after `current` lands at its start.
- `chapter == current - 1` with `opening == .pull` lands at its end.
- Every other earlier chapter lands at its start, including `current - 1` with `opening == .arrival`.

- [ ] **Step 1: Write the failing tests** in `T/CarryThroughTests.swift`:
  - `aDeckFromTheFootStartsOnTheNextChapter`: deck(bottom, pull, 1...150, current 73) has front 74 and pages [74, 75, 76, 77].
  - `aDeckFromTheTopStartsOnThePreviousChapter`: front 72, pages [72, 71, 70, 69].
  - `aDeckAtTheBooksEndHasNoPages`: `CarryThroughDeck(edge: .bottom, …, current: 150) == nil` and `(edge: .top, …, current: 1) == nil`.
  - `theDeckSkipsChaptersTheTranslationLacks`: chapters [1, 2, 4, 5], current 2, bottom: front 4.
  - `flippingBackToTheCurrentChapterIsHome`: flip(by: -1) from front 74 gives front 73 and `isHome`. Flipping further back stays at 73.
  - `theLandingRules`:
    - forward to 75: (75, false)
    - back to 72 after a pull: (72, true)
    - back to 72 after an arrival: (72, false)
    - back to 70 after a pull: (70, false)
    - landing on 73: nil
- [ ] **Step 2: Run them.** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the package tests.** Pass.
- [ ] **Step 5: Commit.** `feat: the carry-through deck and its landing rules`

### Task 10: The phone controller reports pulls and fast arrivals

**Files:**
- Modify: `SUI/Phone/PhoneChapterTextController.swift`
- Test: `T/PhoneChapterTextControllerTests.swift`

**Interfaces:**
- Consumes: Task 9's `CarryThrough` constants.
- Produces: `PhoneChapterTextController.onCarryThrough: (CarryThroughEvent) -> Void`, with:

```swift
enum CarryThroughEvent: Equatable {
    case pulled(edge: CarryThrough.Edge, distance: CGFloat, speed: CGFloat)   // finger down, past the threshold; distance past the stopped edge
    case released(edge: CarryThrough.Edge)                                     // finger up while pulled
    case arrived(edge: CarryThrough.Edge, speed: CGFloat)                      // decelerating into the edge above arrivalSpeed
}
```

- [ ] **Step 1: Write the failing tests.** Drive `scrollViewDidScroll`, `scrollViewWillBeginDragging` and `scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)` directly with set offsets.
  - `aScrollThatStopsAtTheEndDoesNotOpenTheDrawer`: decelerate to `maxOffsetY` at 1,500 pt/s. No event.
  - `pullingPastTheStoppedEndReportsAPull`: at rest at `maxOffsetY`, drag to `maxOffsetY + 100`. `.pulled(edge: .bottom, distance: 100, …)`.
  - `aPullUnderTheThresholdReportsNothing`: `+ 60`. No event.
  - `arrivingFastReportsAnArrival`: decelerate into `maxOffsetY` at 3,000 pt/s. `.arrived(edge: .bottom, speed: ≥ 2500)`.
  - `pullingDownAtTheTopReportsTheTopEdge`: at `minOffsetY`, drag to `minOffsetY - 100`. `.pulled(edge: .top, …)`.
- [ ] **Step 2: Run them.** FAIL.
- [ ] **Step 3: Implement.**
  - **Speed:** track it from `scrollViewWillEndDragging`'s velocity, scaled to points per second (UIKit's velocity is points per millisecond). During deceleration, track it from offset deltas over `CACurrentMediaTime()`.
  - **"Stopped at the edge":** set when dragging begins with the offset within 1 point of `maxOffsetY` (or `minOffsetY`), or when deceleration ends there.
  - **Pulls:** report them only from that state, and only past `pullThreshold`.
  - **Arrivals:** report one when the offset first reaches the edge during deceleration with speed above `arrivalSpeed`.
  - **Not while busy:** nothing is reported while a selection drag, the pen or the thumb is active.
- [ ] **Step 4: Run the iOS tests.** Pass.
- [ ] **Step 5: Commit.** `feat: the phone reader reports carry-through pulls and arrivals`

### Task 11: The drawer

**Files:**
- Create: `SUI/Phone/CarryThroughDrawer.swift`
- Modify: `SUI/Phone/PhoneReaderScreen.swift`, `SUI/Phone/PhoneChapterTextView.swift` (pass `onCarryThrough`)
- Test: `T/CarryThroughTests.swift` (the screen's state reducer), plus a device check

**Interfaces:**
- Consumes: Tasks 8-10.
- Produces:
  - `struct CarryThroughDrawer: View { let deck: CarryThroughDeck; let entranceSpeed: CGFloat; let style: PageStyle; let onChoose: (Int) -> Void; let onDismiss: () -> Void }`.
  - `struct CarryThroughState` (the reducer), with `mutating func handle(_ event: CarryThroughEvent, chapters: [Int], current: Int) -> CarryThroughEffect?` and `enum CarryThroughEffect: Equatable { case land(chapter: Int, atEnd: Bool), close }`.
  - A pull opens the deck, flips it by `floor((distance - pullThreshold) / pageTravel)` and lands on release, unless it is home.
  - An arrival opens the deck and waits.

- [ ] **Step 1: Write the failing reducer tests.**
  - `aPullOpensFlipsAndLandsOnRelease`: pulled 80, then 200 (front 75), then released. `.land(75, false)`.
  - `aPullBackToHomeClosesOnRelease`
  - `anArrivalOpensAndWaits`: arrived(bottom, 3000) leaves the drawer open with front 74 and no effect. A later `chooseTapped(76)` gives `.land(76, false)`. `tappedElsewhere` and `swipedAway` give `.close`.
  - `anArrivalAtTheTopChoosingThePreviousLandsAtItsStart`: `.land(72, false)`.
- [ ] **Step 2: Run them.** FAIL.
- [ ] **Step 3: Implement the drawer and wire it.**
  - **Glass:** a `GlassEffectContainer` holding the drawer's rounded shape with `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppRadius.xl))`, inset by the system margins from the reading column's edges. Its height is about one and a half deck pages.
  - **Entrance:** it slides in from its edge with `.interpolatingSpring(mass: 1, stiffness: 260, damping: 18, initialVelocity: entranceSpeed / 1000)` (call; tune on a device). During the overshoot it stretches up to 12% taller and 4% narrower, anchored at its edge, and settles to 1.
  - **Pages:** quiet sheets in `Color.paperPage` with the numeral in the style's numeral face. They are stacked with a small vertical offset and scale step.
  - **Flipping:** the front page lifts away vertically (up from the foot drawer, down from the top one) with `.spring(response: 0.28, dampingFraction: 0.8)`. Each flip gives `UISelectionFeedbackGenerator().selectionChanged()`. At high flip rates the spring shortens so every number is shown for at least 120 ms.
  - **Reduce Motion:** the drawer fades in at its spot and pages cross-fade.
  - **Reduce Transparency:** the drawer is an opaque `Palette` surface.
  - **After an arrival:**
    - A clear full-screen layer under the drawer takes a tap anywhere else as `tappedElsewhere`.
    - A drag on the drawer flips the deck.
    - A tap on a page gives `chooseTapped`.
    - A swipe toward the drawer's edge gives `swipedAway`.
    - The drawer never closes on its own.
  - **Effects:** `.land` calls `navigation.turn(to:atEnd:)`; `.close` hides the drawer with the reverse spring.
  - **Closing on change:** the drawer closes on rotation, on a size change, and when another screen or sheet appears.
- [ ] **Step 4: Run the iOS tests and both app builds. Then check on the device:**
  - Pulling from 73 to 74 and on to 76.
  - Pulling down at the top of 73 lands at the end of 72.
  - A fast flick into the end, then tapping 75.
  - A tap elsewhere dismisses.
  - Reduce Motion and Reduce Transparency.
- [ ] **Step 5: Commit.** `feat: the carry-through drawer`

### Task 12: Documentation, verification and install

**Files:**
- Modify: `DESIGN.md` (the book thumb and loupe, the drawer, the tokens they use), `README.md` (reader navigation)

- [ ] **Step 1:** Update DESIGN.md and README.md to describe what shipped. Name the constants (`CarryThrough.pullThreshold`, `arrivalSpeed`, `pageTravel`, `thumbEdgeZone`) and say they were tuned on a device.
- [ ] **Step 2: Run everything.** The package tests, the iOS tests, both Debug app builds and the Psalm 119 benchmarks. All pass.
- [ ] **Step 3: Install.** Build and relaunch the Mac Debug app. Run `Scripts/install-phone.sh debug`, with the phone unlocked and ProtonVPN off.
- [ ] **Step 4: Commit.** `docs: one chapter at a time, the book thumb and the carry-through drawer`
