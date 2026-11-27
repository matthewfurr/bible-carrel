# Milestone 11, Project 1: The Home Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task: one fresh implementer and one fresh task reviewer per task, on the model each task's **Run** line names, then one whole-project review on Opus (no Fable in milestone 11) with its report written to a file, one fix wave and one scoped re-review. Steps use checkbox (`- [ ]`) syntax for tracking. The ledger is `.superpowers/sdd/2026-11-23-milestone-11-home-page/progress.md`.

**Goal:** On the Mac's front page the book names and chapter numerals take the reader's page size, the contents' columns widen to the widest name so nothing truncates, and the chapter pane has a divider the reader drags wider, remembered on this Mac.

**Architecture:**
- Pure sizes in `ScriptureUI`: `ContentsMetrics` (the contents page from the reader size), `ChapterPaneMetrics` (the cell, the narrowest width, the 40% limit, the grid's column count), `BookNameMeasure` (the widest name, measured with Core Text once per face, size and set of names, cached).
- `FrontPageView` takes the reader size from `MainWindowView` (which already observes `readerFontSize`) and the pane's `UserDefaults` by injection; it passes the sizes to `ContentsPageView`, `BookPaneView` and `ChapterGridView`, whose column count is now computed.
- `PaneWidth` holds the one stored value; `PaneDivider` is a custom 1 pt rule with an 8 pt drag area in the existing `HStack`.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Core Text, Swift Testing, macOS 26.

**Spec:** `docs/superpowers/specs/2026-11-23-milestone-11-home-page-design.md` (approved by Matt 2026-11-23). Read it with this plan; section numbers below are the spec's. The mockup is `docs/superpowers/specs/milestone-11-mockups/home-page.html`, option C. Handover: `docs/superpowers/specs/2026-11-23-milestone-11-handover.md`, run unattended ("The unattended run").

Paths: `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `LIB` is `SUI/Library`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `MAC` is `Apps/Mac/ReadingThroughScripture`.

**Built on, read in the code at `22f9825` (the code of `f33658a`).**
- `FrontPageView` (`SUI/FrontPageView.swift`): `@ScaledMetric(relativeTo: .body) paneWidth = 260` (:31); the contents and pane in an `HStack(spacing: 0)` (:56-64); the band's rule `Rectangle().fill(Color.inkRule).frame(height: 1)` (:149-153); the hidden ⌘F and Esc buttons `.frame(width: 0, height: 0).accessibilityHidden(true)` (:70-71, :82-83). Hosted by `MAC/MainWindowView.swift:301`, which has `@AppStorage(ReaderSettings.fontSizeKey) fontSize` (:18). The window's minimum is 820 by 520 (`MainWindowView.swift:119`) and it opens at 1,100 by 760 (`ReadingThroughScriptureApp.swift:260`).
- `ContentsPageView` (`LIB/ContentsPageView.swift`): `@ScaledMetric minimumColumnWidth = 180`, `markDot = 3` (:21-22); names `pageFace.swiftUIFont(.body)` (:187); Testament title `.title3` (:136); the Testament's rule (:146-149); `columnWidth(for:columns:width:)` shares the width, adding `lg − md` when Testaments sit side by side (:76-80).
- `ContentsPage` (`LIB/ContentsPage.swift`): `columnCount(width:minimumColumnWidth:)` (:142), `layout(columns:)` stacks the Testaments under four (:150); `books` is private.
- `ChapterGridView` and `ChapterCell` (`SUI/ChapterGridView.swift`): `columnCount = 5` constant (:32); cells `@ScaledMetric(relativeTo: .callout)` 40 by 32 (:27-28, :184-185); numerals `paneNumeralSize` at `.callout` (:170); the search ring 3 (:186); `cursorRect` and ↑ ↓ use the constant (:84-92, :124-125). `ChapterCell.Size` is `.grid` (the phone's, `Phone/PhoneLibraryScreen.swift:217`, untouched) or `.pane`. `ChapterRingView` (`SUI/ChapterMarks.swift:75`) has `@ScaledMetric(relativeTo: .title3) lineWidth = 1.5`.
- `BookPaneView` (`LIB/BookPaneView.swift`) hosts the grid in a `ScrollView`, padded `sm` each side (:59). Only `FrontPageView` makes one.
- `GroupLabel` (`LIB/GroupLabel.swift`): `.caption2.weight(.semibold)`, upper case, `@ScaledMetric(relativeTo: .caption2) tracking = 1.4`, `ink.verse`; also used by the phone (`PhoneLibraryScreen.swift:74`), which keeps today's style.
- `PageFace.font(size:weight:italic:) -> PlatformFont`, `PageFace.numeralFont(size:)`, `PageFace.baseSize(_:)` (Mac: `.caption2` 10). `ReaderSettings.fontSizeRange` 14...28, `defaultFontSize` 18, `clampedFontSize(_:)`. `BibleStore.books(in:)`. `SyncedPreferences.keys`. Book names come from `BookCatalog`, so a translation's widest name depends only on which books it carries (the Apocrypha's "Bel and the Dragon", "Letter of Jeremiah", "Prayer of Manasseh" are longer than "2 Thessalonians").
- No test covers `ChapterGridView`, `ChapterCell`, `GroupLabel` or `BookPaneView` today. `FrontPageBenchmarkTests` (`T/FrontPageBenchmarkTests.swift`, `#if os(macOS)`, `@MainActor .serialized`, `.needsRealBible`) holds the open under 100 ms at 1,100 by 760.
- **Head counts (ledger):** package 1,509, iOS `ScriptureUITests` 1,028. SwiftLint 87, impeccable-lint 27, asset checker 0. In the touched files: `FrontPageView.swift` 6 SwiftLint (:70, :71, :82, :83, :151, :153), `ContentsPageView.swift` 2 (:148, :149), none elsewhere; impeccable-lint none in any of them.

If a name differs when a task is built, say so before going on.

## Before Task 1 (the controller)

1. Copy this plan's Global Constraints to `.superpowers/sdd/2026-11-23-milestone-11-home-page/global-constraints.md` (the implementer rules name that file).
2. Run the pre-flight scan the handover describes against the code as it is; write `preflight.md` beside the ledger and rule each conflict in this text before Task 1.

## Pre-flight rulings (controller, before Task 1)

`preflight.md` (beside the ledger): about 120 interfaces checked, 3 conflicts and 8 gaps. Each is ruled here and the tasks below are amended to match; where a ruling and a task's text disagree, the ruling wins.

1. **`.pointerStyle` is unavailable on iOS.** Wrap the `.pointerStyle(.columnResize)` modifier in `#if os(macOS)` inside `PaneDivider` (Task 4); the rest of `PaneDivider` compiles on both.
2. **`GroupLabel.tracking(forSize:)` is `nonisolated static`** (a `View`'s statics are main-actor; the codebase's pattern is `FrontPageView.showsBand`) (Task 2).
3. **`PaneWidthTests.theWidthIsNotSynced` is `@MainActor`** (`SyncedPreferences.keys` is main-actor) (Task 4).
4. **The "This week" band holds four readings across at 1,100 pt, not five,** now that the pane's narrowest is 316 pt. Accepted **(call, unattended)**: the spec fixes the pane and says the band keeps its own type; changing its 140 pt minimum is outside scope. Task 3 changes `PlanBandTests` (`T/PlanBandTests.swift:14-18`) from `1100 - 260` to `1100 - ChapterPaneMetrics(readerSize: 18).narrowestWidth`, pinning 4 at 1,100 and 3 at 820, and adds the file to its commit. Task 5 updates `DESIGN.md:380` and `PlanWeekSummary.swift:20`'s doc comment, and puts a line on Matt's list ("five readings in a week now wrap four and one in the default window"). *Cost if wrong:* the band's minimum is retuned later.
5. **The scroll on a change of size never moves focus.** Task 2 uses a separate `.onChange(of: readerSize)` that yields and scrolls the chosen book into view; it does not reuse or re-key the opening `.task` (`ContentsPageView.swift:60-69`), which sets `isFocused`. Task 2's live pass adds: Tab into the pane, ⌘+, the keyboard stays in the grid.
6. **The divider is an overlay on the pane's leading edge and takes no layout width** (answers preflight 6 and 7). The `HStack` stays contents then pane; the pane gets `.overlay(alignment: .leading) { PaneDivider(…) }`, the divider's frame `AppSpacing.xs` wide, offset by −`AppSpacing.xs` / 2 so its 1 pt rule is centred on the pane's leading edge and its drag area reaches 4 pt each side. Drawn as the pane's overlay it is above the contents and the pane, so the whole 8 pt hit-tests. The contents width stays `frontPageWidth − pane`, so Task 1's measurement (`1100 − pane − 2 × lg`) and its pins are right as written. Task 4's review checks the hit area is 8 pt centred.
7. **Task 1's `theDefaultWindowHoldsTheMeasuredColumns` also asserts the spec's first test (spec 10):** for the ESV and the KJV at 14, 18 and 28, every book name's Core Text width + `dotGap` + `markDot` + 2 × `washInset` ≤ `ContentsMetrics.columnWidth(widestName:)` of that translation.
8. **Task 5's DESIGN.json step also updates "Group Label"** (its Mac size from the reader size), **"Chapter Ring"** (its line width scales in the pane) and "Chapter Cell"'s `size` and `typography` keys besides `sizes`.
9. **A scroller that is always shown** (a mouse attached, or "Show scroll bars: Always") narrows the pane's grid by about 15 pt at the narrowest and eats into its `sm` margins. Accepted **(call, unattended)**: the spec fixes the narrowest width; it goes on Matt's list as unseen. *Cost if wrong:* `columns(paneWidth:)` later reads the scroll view's content width.
10. **A drag works from its translation, not the pointer's location,** so the pane does not jump up to 4 pt when the press lands off the rule. Task 4's `PaneWidth.drag(toDividerX:frontPageWidth:)` becomes `mutating func drag(translation: CGFloat, _ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat)`: its first call in a drag records the shown width as the start; the dragged width is `start − translation` (a drag to the left is a negative translation and widens the pane). `endDrag` clears the start. `PaneDivider`'s `onDrag` reports `translation.width`. Task 4's `aDragIsWrittenOnlyWhenItEnds` becomes: empty suite at 18 in 1,100: `drag(translation: -84, …)`: shown 400, nothing written; `endDrag`: 400 written. `drag(translation: -200, …)` then `endDrag`: 440 written. `drag(translation: 300, …)` then `endDrag`: 316 written (Departure 8).

## Departures and open calls

Each is built as written; each that Matt may want otherwise is on his list in the spec's "As built" (Task 5). All are **(call, unattended)**.

1. **The reader size is passed in, not read with `@AppStorage` in `FrontPageView`** (spec 9's "obvious way"). `MainWindowView` already observes `readerFontSize`; it passes `ReaderSettings.clampedFontSize(fontSize)`. Reason: tests and the benchmark inject the size and never touch the real defaults. *Cost if wrong:* none the reader sees.
2. **Cells round to whole points:** 2.9 × and 2.2 × the size, each `.rounded()`. So the narrowest pane is **261 pt at 14, 316 at 18, 461 at 28**, where the spec wrote "about 259, 316, 462". *Cost:* a point or two.
3. **`ContentsPage.columnCount` allows for the Testaments' side-by-side gap** (spec 4.2 says "unchanged"). From four columns up the Testaments are `lg` apart, not `md`, so a width that holds four columns at `md` but not the extra `lg − md` would share out columns 2 pt narrower than the widest name and truncate it (the anti-goal). It now counts one fewer there. *Cost:* at a band of a few points' width, one fewer column.
4. **A translation's widest name includes its Apocrypha,** since every band's columns share one width (`ContentsPageView.columnWidth`). *Cost:* in a translation that carries the Apocrypha the Testaments stack at a smaller size than in the ESV. The measurement (Task 1) says which translations and sizes.
5. **The row's dot gap scales with the size** along with the inset, the vertical padding and the dot (spec 4.1 names the inset, padding and dot). *Cost:* none visible.
6. **The group label is `Font(PlatformFont.systemFont(ofSize:weight: .semibold))`** at its derived size, its tracking 1.4 × size ÷ `.caption2`'s size, recorded in DESIGN.md's Dynamic Type Contract as derived from the reader size (spec 8). `.font(.system(size:))` is what the checkers ban; this is the reader-size exception the spec records, not a way round it.
7. **A shared `HairlineRule`** (new, `SUI/HairlineRule.swift`, its thickness a named constant) draws the band's rule, the Testament's rule and the divider's. A SwiftUI `Shape` is not an accessibility element, so it carries no `accessibilityHidden`. This removes four old findings (FrontPageView :151, :153; ContentsPageView :148, :149). The hidden ⌘F and Esc buttons' four (:70, :71, :82, :83) stay: they are real hidden controls.
8. **A drag released below the narrowest saves the narrowest as a number**, which then no longer follows the size; only the double-click returns the pane to following it (spec 5.1). *Cost:* a reader who drags fully left expects tracking; one double-click gives it.
9. **VoiceOver's adjust saves each step,** clamped like a drag, and reads "N chapters across". *Cost:* none.
10. **The "Numbers Matt may ask to tune" row** lives in milestone 10's handover table (the current one; milestone 11's final handover carries it on). Task 5 edits it there.
11. **The 18 pt measurement (spec 4.2).** Task 1 measures how many columns of books the 1,100 pt window holds at 18 pt with the pane at its narrowest, writes the figure to the ledger and to "As built". If it is **three**, the Testaments stack at the default size in the default window, which Matt has not seen (his mockup showed four with today's 260 pt pane): that goes at the **top** of his list, and the build goes on as specified. Likely three: about 736 pt of columns over a column of about 180.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-11-ui-improvements`, branch `milestone-11-ui-improvements`. Never push or merge.
- Git: `/usr/bin/git -C <worktree>` or from the worktree, one git command per Bash call, no `cd … &&`, loops or shell variables. Every commit message ends with the `Co-Authored-By:` line your own session gives you, as a second `-m`.
- `rtk` shortens command output; use `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time. You do not dispatch subagents.
- **Implementers never launch, quit or send keys to the Mac Debug app or the simulator.** The one live pass per UI task is the controller's.

**Matt's data**
- Never touch the Release apps, `Scripts/install-app.sh`, `/Applications`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item.
- The `.dev` store and its preferences get no test note, plan or setting.
- **No test writes `UserDefaults.standard` or `readerFontSize`.** A test's defaults are `UserDefaults(suiteName: "<Suite>-\(UUID().uuidString)")!`, removed with `removePersistentDomain(forName:)` when it ends; the reader size is a parameter.

**What is stored (spec 6, and nothing beyond it)**
- Exactly one new value: `frontPagePaneWidth` (`PaneWidth.key`), a `Double` in points, in `UserDefaults` on this Mac. Not in `SyncedPreferences.keys`, not in the synced store, no iCloud schema change.
- Written only when a drag ends or VoiceOver adjusts; removed by a double-click on the divider. Never written on open or when the size or window changes.
- The front page reads the reader size and never writes it.

**The spec's numbers (verbatim)**
- Book names: the page face at `readerFontSize` points, regular, `ink.primary`. Testament titles: the page face at 1.15 × the reader size. Group labels: SF Pro semibold, upper case, tracked, `ink.verse`, at 0.58 × the reader size with a floor of `.caption2`'s size. Row padding, the wash inset (`xs` beyond the name) and the marked dot (3 pt) scale by the reader size over 18.
- Column width: the widest book name of the translation at the current size, in the page face, plus the marked dot and its gap and the wash's inset on both sides. Count: as many as fit with `md` between them.
- Cells: the numeral in the page face at the reader size; the cell 2.9 × the reader size wide and 2.2 × high (52 by 40 at 18). Gutters `xs` (8). The ring's line 1.5 pt and the search ring 3 pt at 18, scaled by the reader size over 18.
- Grid columns: as many cells as fit across the pane's inner width (the pane less `sm` each side), never fewer than three.
- The narrowest pane holds five cells across plus the gutters and `sm` each side, but never more than 40% of the window. The pane is at most 40% of the window, which wins.
- The divider: a 1 pt `ink.rule` line, a drag area about 8 pt wide centred on it, the system's left-right resize cursor, no grabber, no animation. Double-click removes the stored width. VoiceOver: an adjustable element, "Chapter pane width", steps of one column. Not a Tab stop.

**UI rules**
- `CLAUDE.md`'s three rules; `PRODUCT.md` and `DESIGN.md` read first; `/impeccable-swift` for every UI change, its command named in each task.
- Palette tokens only; `AppSpacing` and `AppRadius` by name; no card; no new shadow or material. A size derived from the reader size is a `ContentsMetrics` or `ChapterPaneMetrics` value, never a literal in a view.
- No animation on a change of size or during a drag; the reflow is a cut.
- **Checkers, from the worktree root:** `swiftlint lint --config tools/.swiftlint.yml`; `tools/impeccable-lint/.build/release/impeccable-lint Packages/ScriptureKit/Sources/ScriptureUI Apps`; `swift tools/asset-catalog-checker/check.swift Apps/Mac/ReadingThroughScripture/Assets.xcassets`. Baseline 87, 27, 0. No new finding in a touched or new file.

**Speed (spec 7)**
- The widest name is measured once per face, size and set of names (`BookNameMeasure`), never per redraw. No new view per chapter of the Bible; the grid stays a `LazyVGrid`.
- `FrontPageBenchmarkTests` keeps its 100 ms budget at 18 and at 28 pt.

**Tests**
- Swift Testing in `T` (the package's `ScriptureUITests`, which the iOS suite also runs on the simulator). New front-page test files are wrapped in `#if os(macOS)`. A test that hosts an `NSHostingView` or a window is `@MainActor` (AppKit off the main actor crashes parallel runs) and its suite `.serialized`.
- `swift test` cannot load the package's Color Sets; tokens come from `Palette.swift`.
- `.needsRealBible` on any test that opens `BenchmarkChapter.realStore()`.
- Known flake: `ReaderBenchmarkTests.scrollingWhileTheThumbRevealsKeepsTheFrameCost` and other timing benchmarks under full-suite load; rerun alone before treating it as yours.
- Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (add `--filter <Suite>` while iterating). iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`. Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`. One at a time.

**Renders**
- A temporary `@MainActor` test, `T/FrontPageRenderScratch.swift`, hosts `FrontPageView` on the real store (as `FrontPageBenchmarkTests.navigation()` does) in an offscreen `NSHostingView`, and writes PNGs to the session scratchpad the dispatch names. Light and dark by the host's `NSAppearance`; Sepia by `SepiaMode.set(true)` and `.followsSepia()`, reset after. Open every PNG with Read. Delete the file before committing. Each task lists its renders.
- A render cannot show the cursor, a drag, focus rings or VoiceOver; say so.

## Review Focus

The cases the spec implies that a person meets and its own test list does not pin, most likely first; each has its test in the owning task.

1. **A contents width just wide enough for four columns at `md` but not for the Testaments' `lg` gap:** the reader expects three untruncated columns, not four that cut "2 Thessalonians" (Task 1, `columnCountLeavesRoomForTheTestamentsGap`).
2. **A translation that carries the Apocrypha** (the WEB has Tobit): its longer names must set the column width, so "Bel and the Dragon" never truncates (Task 1, `theApocryphaSetsTheWidthWhereATranslationHasIt`).
3. **The first layout pass, before the front page's width is known (0):** the pane must open at its narrowest, not collapse to 0 and flash a three-column grid (Task 1, `anUnknownWidthShowsTheNarrowest`).
4. **VoiceOver's adjust at either limit:** increment at 40% stays at 40% and decrement at the narrowest stays there; neither stores a width outside the limits (Task 4, `adjustingStopsAtBothLimits`).
5. **A one-chapter book (Obadiah) and a 150-chapter book (Psalms) at the new column counts:** ↑ ↓ on Obadiah do nothing; ↓ from Psalms 148 at eight across goes nowhere rather than past the end; the cursor's rectangle at Psalms 150 sits in the last row (Task 3, `theArrowsStopAtTheGridsEdges`).

---

### Task 1: The sizes, and the measurement

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change (no view is touched), so no `/impeccable-swift` command; the review runs the three checkers.

**Files:**
- Create: `LIB/ContentsMetrics.swift`, `LIB/ChapterPaneMetrics.swift`, `LIB/BookNameMeasure.swift`
- Modify: `LIB/ContentsPage.swift` (`bookNames`; `columnCount` with the side-by-side gap)
- Modify: `docs/superpowers/specs/2026-11-23-milestone-11-home-page-design.md` (section 12, "As built": the measurement)
- Test: `T/FrontPageMetricsTests.swift` (new, `#if os(macOS)`); `T/ContentsPageTests.swift` (one assertion)

**Interfaces:**
- Produces:
  - `public struct ContentsMetrics: Equatable, Sendable { public init(readerSize: CGFloat) }` (clamped to `ReaderSettings.fontSizeRange`), with `readerSize`, `scale` (size ÷ 18), `nameSize` (= size), `testamentTitleSize` (1.15 ×), `groupLabelSize` (`max(0.58 × size, PageFace.baseSize(.caption2))`), `rowVerticalPadding` (`xxs` × scale), `washInset` (`xs` × scale), `dotGap` (`xs` × scale), `markDot` (3 × scale), and `func columnWidth(widestName: CGFloat) -> CGFloat` (`ceil(widestName + dotGap + markDot + 2 × washInset)`).
  - `public struct ChapterPaneMetrics: Equatable, Sendable { public init(readerSize: CGFloat) }` (clamped), with `static let fiveAcross = 5`, `static let fewestColumns = 3`, `static let widestShare: CGFloat = 0.4`; `cellWidth` (`(2.9 × size).rounded()`), `cellHeight` (`(2.2 × size).rounded()`), `numeralSize` (= size), `ringLineWidth` (1.5 × size ÷ 18), `searchRingWidth` (3 × size ÷ 18), `columnStep` (`cellWidth + AppSpacing.xs`), `narrowestWidth` (`5 × cellWidth + 4 × xs + 2 × sm`); `func widestWidth(frontPageWidth:) -> CGFloat` (0.4 ×); `func shownWidth(stored: CGFloat?, frontPageWidth: CGFloat) -> CGFloat` (`min(max(stored ?? narrowest, narrowest), 0.4 × frontPageWidth)`, and when `frontPageWidth <= 0`, `max(stored ?? narrowest, narrowest)`); `func columns(paneWidth: CGFloat) -> Int` (`max(3, Int((paneWidth − 2 × sm + xs) / columnStep))`).
  - `public final class BookNameMeasure: Sendable { public static let shared; public init(); public func widest(of names: [String], face: PageFace, size: CGFloat) -> CGFloat; var measurements: Int { get } }`: Core Text (`CTLineCreateWithAttributedString`, `CTLineGetTypographicBounds`) over `face.font(size:)`, `ceil`ed, cached in a `Mutex<[Key: CGFloat]>` keyed by face, size and names; `measurements` counts passes over a name list.
  - `ContentsPage.bookNames: [String]` (a `let`, every book's name in page order, set in `init`).
  - `ContentsPage.columnCount(width:minimumColumnWidth:)`: as today, then one fewer when the count is four or more and `count × w + (count − 1) × md + (lg − md) > width`.

- [ ] **Step 1: Write the failing tests** in `T/FrontPageMetricsTests.swift`, `@Suite struct FrontPageMetricsTests`:
  - `theContentsSizesFollowTheReaderSize`: at 18, `testamentTitleSize` ≈ 20.7, `groupLabelSize` ≈ 10.44, `markDot == 3`, `washInset == 8`; at 28, `groupLabelSize` ≈ 16.24, `scale` ≈ 28/18; at 14, `groupLabelSize == PageFace.baseSize(.caption2)` (the floor); `ContentsMetrics(readerSize: 40).readerSize == 28` (clamped).
  - `thePaneSizesFollowTheReaderSize`: at 18, `cellWidth == 52 && cellHeight == 40 && numeralSize == 18 && ringLineWidth == 1.5 && searchRingWidth == 3` (larger than today's 40 by 32 at 12 pt); `narrowestWidth` is 261, 316, 461 at 14, 18, 28.
  - `theNarrowestNeverPassesFortyPercent`: at 28, `shownWidth(stored: nil, frontPageWidth: 1100) == 440` and `(…, 820) == 328`; at 18, `(…, 1100) == 316`; a stored 400 at 18 in 1,100 shows 400, at 18 in 800 shows 320; a stored 300 at 18 shows 316.
  - `anUnknownWidthShowsTheNarrowest` (Review Focus 3): `shownWidth(stored: nil, frontPageWidth: 0) == narrowestWidth` at 18; a stored 400 with width 0 shows 400.
  - `theGridHoldsFiveAtTheNarrowestAndMoreAsItWidens`: at 18, `columns(paneWidth: 316) == 5`, `(376) == 6`, `(496) == 8`; at 28, `columns(paneWidth: 440) == 4`, `(328) == 3`; at 28, `columns(paneWidth: 100) == 3` (never fewer).
  - `theWidestNameIsMeasuredOncePerFaceSizeAndNames`: a fresh `BookNameMeasure()`; `widest(of: catalogue66, face: .literata, size: 18)` twice gives one `measurements`; at 28 it is larger and counts two; `.sourceSerif` at 18 counts three; every name's own Core Text width ≤ the result.
  - `theApocryphaSetsTheWidthWhereATranslationHasIt` (Review Focus 2): `widest(of: 66 + apocrypha)` > `widest(of: 66)` at 18.
  - `columnCountLeavesRoomForTheTestamentsGap` (Review Focus 1): with `w = 177`, `ContentsPage.columnCount(width: 4 × 177 + 3 × 16, minimumColumnWidth: 177) == 3` and `(width: 4 × 177 + 3 × 16 + 8, …) == 4`.
  - `@MainActor` `aNameSetInSwiftUIFitsItsMeasure`: for "2 Thessalonians", "Song of Solomon", "Bel and the Dragon" at 14, 18 and 28 in Literata, `NSHostingView(rootView: Text(name).font(Font(PageFace.literata.font(size: s))).fixedSize()).fittingSize.width ≤ BookNameMeasure().widest(of: [name], face: .literata, size: s)`. (Its suite is `@MainActor .serialized`; put it in a second suite in the same file.)
  - In `ContentsPageTests.fourColumnsAreTheMockupsAndFewerStackTheTestaments`: `ContentsPage(books: sixtySix, …).bookNames.count == 66 && bookNames.first == "Genesis"`.

- [ ] **Step 2: Run them and see them fail** (`--filter FrontPageMetricsTests`, then `--filter ContentsPageTests`). Expected: compile failure, the types not defined (a compile failure counts as the red).

- [ ] **Step 3: Implement** the three new files and the two `ContentsPage` changes as the Interfaces say. Document each value with the spec section it comes from.

- [ ] **Step 4: Run them and see them pass,** and `ContentsPageTests` whole (its `792 / 180 == 4` pin still holds: 4 × 180 + 48 + 8 = 776).

- [ ] **Step 5: Measure (spec 4.2), with a scratch test** (`.needsRealBible`, not committed): for each translation in `BenchmarkChapter.realStore().translations()`, its `books(in:)` names; at 14, 18, 24 and 28 in Literata: the widest name, `ContentsMetrics.columnWidth`, the pane's `shownWidth(stored: nil, frontPageWidth: 1100)`, and `ContentsPage.columnCount(width: 1100 − pane − 2 × AppSpacing.lg, minimumColumnWidth:)`; also each of the five faces at 18 for the ESV, and the same counts at 820. Write the table to `.superpowers/sdd/2026-11-23-milestone-11-home-page/measurements.md` and to your report. Delete the scratch test.

- [ ] **Step 6: Pin the measured counts.** Add `@Test(.needsRealBible) func theDefaultWindowHoldsTheMeasuredColumns` to `FrontPageMetricsTests`: the ESV's and the KJV's counts at 14, 18 and 28 in a 1,100 pt window with the pane at its narrowest, as measured; and at 28, `page.layout(columns: count)` has the Old and New Testaments in separate bands (the existing stacking rule at a large size). Run it; see it pass.

- [ ] **Step 7: Write the figure into the spec's "As built"** (section 12): a "Measured" paragraph with the column count at 18 in the 1,100 pt window and the table's thresholds (the size at which each of the ESV and the KJV drops from four to three, and to two, at 1,100 and 820). If the ESV's count at 18 is three, start a "For Matt" list there whose first item says, in plain words: at the default text size the default window now holds three columns of books, so the Old Testament fills the width and the New follows below it, which he has not seen (his mockup showed four beside today's narrower pane); the build goes on as the spec says. Tell the controller the figure in your reply's first line.

- [ ] **Step 8: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** then the three checkers.

- [ ] **Step 9: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI/Library/ContentsMetrics.swift Packages/ScriptureKit/Sources/ScriptureUI/Library/ChapterPaneMetrics.swift Packages/ScriptureKit/Sources/ScriptureUI/Library/BookNameMeasure.swift Packages/ScriptureKit/Sources/ScriptureUI/Library/ContentsPage.swift Packages/ScriptureKit/Tests/ScriptureUITests/FrontPageMetricsTests.swift Packages/ScriptureKit/Tests/ScriptureUITests/ContentsPageTests.swift docs/superpowers/specs/2026-11-23-milestone-11-home-page-design.md
/usr/bin/git commit -m "Home page sizes from the reader size: the contents, the pane and the widest book name, measured once" -m "Co-Authored-By: …"
```

---

### Task 2: The contents page at the reader size

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift typeset`. Review: `/impeccable-swift audit` on `ContentsPageView`, `GroupLabel`, `FrontPageView`, plus the three checkers.

**Files:**
- Create: `SUI/HairlineRule.swift`
- Modify: `LIB/ContentsPageView.swift`, `LIB/GroupLabel.swift`, `SUI/FrontPageView.swift` (the `readerSize` parameter, the band's rule), `MAC/MainWindowView.swift:301` (pass the size)
- Test: `T/FrontPageMetricsTests.swift` (the label), `T/FrontPageBenchmarkTests.swift` (18 and 28)

**Interfaces:**
- Consumes: `ContentsMetrics`, `BookNameMeasure.shared.widest(of:face:size:)`, `ContentsPage.bookNames`, `ContentsPage.columnCount` (Task 1).
- Produces:
  - `FrontPageView.init(navigation:marks:plans:onShowWholePlan:onOpenSettings:readerSize: Double = ReaderSettings.defaultFontSize)` (Task 4 adds `paneDefaults`). It keeps `readerSize` as a `let` and passes `CGFloat(readerSize)` down.
  - `ContentsPageView.init(page:markedBooks:readerSize: CGFloat, onChoose:onOpen:)`.
  - `GroupLabel.init(_ title: String, size: CGFloat? = nil)`; `static func tracking(forSize size: CGFloat) -> CGFloat` (1.4 × size ÷ `PageFace.baseSize(.caption2)`). `nil` keeps today's `.caption2` semibold with its scaled 1.4 tracking (the phone).
  - `struct HairlineRule: View { enum Axis { case horizontal, vertical }; static let thickness: CGFloat = 1; init(_ axis: Axis = .horizontal) }`: `Rectangle().fill(Color.inkRule)` framed to `thickness` on its cross axis.

- [ ] **Step 1: Write the failing tests.**
  - In `FrontPageMetricsTests`: `theGroupLabelKeepsItsProportion`: `GroupLabel.tracking(forSize: PageFace.baseSize(.caption2)) == 1.4` and `tracking(forSize: 16.24)` ≈ 2.27.
  - In `FrontPageBenchmarkTests`: make the test `@Test(.needsRealBible, arguments: [18.0, 28.0]) func theFrontPageOpensWithinAHundredMilliseconds(readerSize: Double)`, passing `readerSize:` to `FrontPageView`; the budget stays 100 ms.

- [ ] **Step 2: Run them and see them fail** (`--filter FrontPageMetricsTests`, `--filter FrontPageBenchmarkTests`): compile failure.

- [ ] **Step 3: Implement.**
  - `ContentsPageView`: drop the two `@ScaledMetric`s; `let metrics = ContentsMetrics(readerSize: readerSize)`; the column minimum is `metrics.columnWidth(widestName: BookNameMeasure.shared.widest(of: page.bookNames, face: pageFace, size: metrics.nameSize))`. Book names in `Font(pageFace.font(size: metrics.nameSize))` (the font measured, so the widths agree); the Testament title in `Font(pageFace.font(size: metrics.testamentTitleSize))`; `GroupLabel(group.title, size: metrics.groupLabelSize)`; the row's vertical padding, horizontal inset (and the matching negative leading), dot gap and dot from `metrics`. The Testament's rule becomes `HairlineRule()`. On a change of `readerSize`, scroll the chosen book into view after a `Task.yield()`, as the opening does. No animation.
  - `GroupLabel`: with a size, `Font(PlatformFont.systemFont(ofSize: size, weight: .semibold))` and `kerning(Self.tracking(forSize: size))` (Departure 6); without, as today.
  - `FrontPageView`: the parameter; the band's rule becomes `HairlineRule().padding(.horizontal, AppSpacing.lg)`.
  - `MainWindowView`: `FrontPageView(…, readerSize: ReaderSettings.clampedFontSize(fontSize))`.

- [ ] **Step 4: Run them and see them pass,** the benchmark under 100 ms at both sizes (record both medians).

- [ ] **Step 5: Render** (Global Constraints › Renders): the front page at 1,100 by 760 at 14, 18, 24 and 28 pt, each light, dark and Sepia (twelve), reading John 15 in the ESV; and at 28 in the WEB (the Apocrypha). Check by eye: no name ends in an ellipsis; the Testaments stack where Task 1's table says; the group label keeps its proportion; the chosen book's wash sits `xs` × scale beyond its name. Delete the render file.

- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** then the three checkers: `FrontPageView.swift` 4 (from 6), `ContentsPageView.swift` 0 (from 2), `HairlineRule.swift`, `GroupLabel.swift` and `MainWindowView.swift` none new.

- [ ] **Step 7: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI/HairlineRule.swift Packages/ScriptureKit/Sources/ScriptureUI/Library/ContentsPageView.swift Packages/ScriptureKit/Sources/ScriptureUI/Library/GroupLabel.swift Packages/ScriptureKit/Sources/ScriptureUI/FrontPageView.swift Apps/Mac/ReadingThroughScripture/MainWindowView.swift Packages/ScriptureKit/Tests/ScriptureUITests/FrontPageMetricsTests.swift Packages/ScriptureKit/Tests/ScriptureUITests/FrontPageBenchmarkTests.swift
/usr/bin/git commit -m "The contents page sets its book names at the reader's page size, its columns as wide as the widest name" -m "Co-Authored-By: …"
```

**Controller live pass:** the Debug app on the front page; ⌘+ three times and ⌘− three times (back where it was); capture the window after each step; the names follow, nothing truncates, the chosen book stays in view.

---

### Task 3: The chapter grid at the reader size, its column count computed

**Run:** implementer **Opus**; task reviewer **Opus** (the grid's keys and cursor with a computed column count). `/impeccable-swift layout`. Review: `/impeccable-swift audit` on `ChapterGridView`, `ChapterCell`, `BookPaneView`, plus the three checkers.

**Files:**
- Modify: `SUI/ChapterGridView.swift`, `SUI/ChapterMarks.swift` (`ChapterRingView`'s line width override), `LIB/BookPaneView.swift`, `SUI/FrontPageView.swift` (the pane's width from the metrics and the front page's width)
- Test: `T/ChapterGridTests.swift` (new, `#if os(macOS)`)

**Interfaces:**
- Consumes: `ChapterPaneMetrics` (Task 1); `FrontPageView.readerSize` (Task 2).
- Produces:
  - `enum ChapterGridMove: Sendable { case left, right, up, down }`.
  - `ChapterGridView.init(bookName:chapterCount:currentChapter:marks:ringedChapter:metrics: ChapterPaneMetrics, columnCount: Int, onRevealChapter:focusRequests:onSelect:)`, and three `nonisolated static` functions the view uses: `rowCount(chapters: Int, columns: Int) -> Int`, `cursorRect(chapter: Int, columns: Int, metrics: ChapterPaneMetrics) -> CGRect`, `target(from chapter: Int, moving: ChapterGridMove, columns: Int, chapterCount: Int) -> Int?` (nil when the move leaves the grid).
  - `ChapterCell.Size` becomes `enum Size: Equatable { case grid; case pane(ChapterPaneMetrics) }`; `.pane` sets the numeral with `pageFace.numeralFont(size: metrics.numeralSize)`, the cell `cellWidth` by `cellHeight`, the search ring `searchRingWidth`, the ring `ringLineWidth`. `.grid` is unchanged.
  - `ChapterRingView(marks:cornerRadius:lineWidth: CGFloat? = nil)`: nil keeps the scaled 1.5.
  - `BookPaneView.init(…, paneMetrics: ChapterPaneMetrics, gridColumns: Int, …)`, passed to the grid.
  - `FrontPageView`: `@State private var frontPageWidth: CGFloat = 0`, from `.onGeometryChange(for: CGFloat.self)` on the `HStack`; the pane `.frame(width: paneMetrics.shownWidth(stored: nil, frontPageWidth: frontPageWidth))` (Task 4 puts the stored width in); `gridColumns = paneMetrics.columns(paneWidth: that width)`. The `@ScaledMetric paneWidth` goes.

- [ ] **Step 1: Write the failing tests** in `T/ChapterGridTests.swift`, `@Suite struct ChapterGridTests`:
  - `theCursorsRectangleFollowsTheColumnCount`: at 18, `cursorRect(chapter: 7, columns: 8, …) == CGRect(x: 360, y: 0, width: 52, height: 40)`; `cursorRect(chapter: 15, columns: 8, …).origin == CGPoint(x: 360, y: 48)`; `cursorRect(chapter: 6, columns: 5, …).origin == CGPoint(x: 0, y: 48)`.
  - `theArrowsMoveByTheColumnCount`: `target(from: 3, moving: .down, columns: 8, chapterCount: 50) == 11`; `.up` from 11 is 3; `.right` from 8 is 9; at 5 columns `.down` from 3 is 8.
  - `theArrowsStopAtTheGridsEdges` (Review Focus 5): Obadiah (`chapterCount: 1`, 8 columns): `.up`, `.down`, `.left`, `.right` from 1 are nil; Psalms (150, 8 columns): `.down` from 148 is nil, `.down` from 142 is 150, `.right` from 150 is nil; `rowCount(chapters: 150, columns: 8) == 19` and `cursorRect(chapter: 150, columns: 8, …).origin.y == 18 × 48`; `rowCount(chapters: 1, columns: 8) == 1`.

- [ ] **Step 2: Run them and see them fail** (`--filter ChapterGridTests`): compile failure.

- [ ] **Step 3: Implement** as the Interfaces say. The grid's `GridItem`s, width, height, `cursorRect`, row count and all four arrows use `columnCount` and `metrics`; the arrows call `target(…)` and return `.ignored` on nil, as today. Cells keep `AppRadius.lg`. The grid stays centred. No animation when the column count changes.

- [ ] **Step 4: Run them and see them pass,** then `--filter FrontPageBenchmarkTests` (both sizes, under 100 ms).

- [ ] **Step 5: Render:** Genesis's grid at 28 pt in a 1,100 pt and an 820 pt front page (four and three across, the pane at 40%); Psalms at 18 at the narrowest (five across), a marked chapter's ring and the chapter being read on the wash; light, dark and Sepia for the 1,100 pt one. Check the ring's line and the cell's rounding at 28. Delete the render file.

- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** then the three checkers (no new finding in the four touched files).

- [ ] **Step 7: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI/ChapterGridView.swift Packages/ScriptureKit/Sources/ScriptureUI/ChapterMarks.swift Packages/ScriptureKit/Sources/ScriptureUI/Library/BookPaneView.swift Packages/ScriptureKit/Sources/ScriptureUI/FrontPageView.swift Packages/ScriptureKit/Tests/ScriptureUITests/ChapterGridTests.swift
/usr/bin/git commit -m "The pane's chapters take the reader's page size, as many across as the pane holds" -m "Co-Authored-By: …"
```

**Controller live pass:** Tab into the pane on Psalms; ↓ and → a few times; capture: the ring moves by a whole row of five at the narrowest; Return opens the chapter; ⇧⌘H back.

---

### Task 4: The divider, and the stored width

**Run:** implementer **Opus**; task reviewer **Opus** (drag, cursor, double-click, VoiceOver adjustable). `/impeccable-swift craft`. Review: `/impeccable-swift audit` on `PaneDivider` and `FrontPageView`, plus the three checkers.

**Files:**
- Create: `LIB/PaneWidth.swift`, `LIB/PaneDivider.swift`
- Modify: `SUI/FrontPageView.swift`
- Test: `T/PaneWidthTests.swift` (new, `#if os(macOS)`), `T/FrontPageBenchmarkTests.swift` (pass a suite)

**Interfaces:**
- Consumes: `ChapterPaneMetrics.shownWidth`, `columns(paneWidth:)`, `columnStep`, `narrowestWidth` (Task 1); `HairlineRule(.vertical)` (Task 2); `frontPageWidth` and the pane frame (Task 3).
- Produces:
  - `struct PaneWidth { static let key = "frontPagePaneWidth"; init(defaults: UserDefaults); var stored: CGFloat? { get }; var isDragging: Bool { get }; func shown(_ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat) -> CGFloat; mutating func drag(toDividerX x: CGFloat, frontPageWidth: CGFloat); mutating func endDrag(_ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat); mutating func adjust(byColumns: Int, _ metrics: ChapterPaneMetrics, frontPageWidth: CGFloat); mutating func reset() }`. `init` reads a `Double` under `key` (nil when absent or not positive). `shown` is `metrics.shownWidth(stored: dragged ?? stored, frontPageWidth:)`. `drag` sets the dragged width to `frontPageWidth − x` and writes nothing. `endDrag` stores the shown width and writes it. `adjust` stores `shownWidth(stored: shown + n × columnStep, …)` and writes it. `reset` forgets and removes the key.
  - `struct PaneDivider: View { init(columns: Int, coordinateSpace: String, onDrag: @escaping (CGFloat) -> Void, onEnd: @escaping () -> Void, onReset: @escaping () -> Void, onAdjust: @escaping (Int) -> Void) }`: `HairlineRule(.vertical)` with an `AppSpacing.xs`-wide clear overlay centred on it (`contentShape(Rectangle())`), `.pointerStyle(.columnResize)`, a `DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpace))` reporting `location.x` and its end, a simultaneous double tap for `onReset`; `.accessibilityElement()`, label "Chapter pane width", value "\(columns) chapters across", `.accessibilityAdjustableAction` (+1 increment, −1 decrement); not focusable.
  - `FrontPageView.init(…, readerSize:, paneDefaults: UserDefaults = .standard)`; `@State private var paneWidth: PaneWidth` made from `paneDefaults` in `init`; the `HStack` gains `.coordinateSpace(.named("frontPage"))` and the divider between the contents and the pane.

- [ ] **Step 1: Write the failing tests** in `T/PaneWidthTests.swift`, `@Suite struct PaneWidthTests`, each with its own suite of defaults, removed at the end:
  - `withNothingStoredThePaneFollowsTheNarrowest`: an empty suite; `stored == nil`; shown at 14, 18, 28 in 1,100 is 261, 316, 440.
  - `aStoredWidthIsReadOnOpening`: a suite holding 400.0; shown at 18 in 1,100 is 400.
  - `aStoredWidthBeyondTheLimitsShowsAtThemAndIsKept`: 400 stored; at 28 in 1,100 shown is 440 and at 18 in 800 shown is 320; `defaults.double(forKey: PaneWidth.key) == 400` after both. 300 stored; at 18 shown is 316, still 300 in the defaults.
  - `aDragIsWrittenOnlyWhenItEnds`: empty suite; `drag(toDividerX: 700, frontPageWidth: 1100)`: shown 400, `defaults.object(forKey:) == nil`; `endDrag` at 18: the defaults hold 400. `drag(toDividerX: 500, …)` then `endDrag`: 440 written. `drag(toDividerX: 1000, …)` then `endDrag`: 316 written (Departure 8).
  - `aDoubleClickRemovesTheStoredWidth`: 400 stored; `reset()`; the key is gone, `stored == nil`, shown at 14 is 261.
  - `adjustingStopsAtBothLimits` (Review Focus 4): empty suite at 18 in 1,100; `adjust(byColumns: 1)` writes 376, the next 436, the next two 440 (the cap); `adjust(byColumns: -10)` writes 316.
  - `theWidthIsNotSynced`: `!SyncedPreferences.keys.contains(PaneWidth.key)` and `PaneWidth.key == "frontPagePaneWidth"`.
  - In `FrontPageBenchmarkTests`: pass `paneDefaults:` a suite holding nothing, removed at the end.

- [ ] **Step 2: Run them and see them fail** (`--filter PaneWidthTests`): compile failure.

- [ ] **Step 3: Implement** `PaneWidth`, then `PaneDivider`, then wire `FrontPageView`: the pane's width is `paneWidth.shown(paneMetrics, frontPageWidth:)`; `onDrag` calls `drag`, `onEnd` `endDrag`, `onReset` `reset`, `onAdjust` `adjust`; the grid's columns follow the shown width live during the drag. No animation (a `Transaction` with animations disabled around the drag's updates if any ancestor animates). The divider draws only the 1 pt rule at rest: no grabber, no hover fill. It does not take Esc, Tab or any key.

- [ ] **Step 4: Run them and see them pass,** then `--filter FrontPageBenchmarkTests`.

- [ ] **Step 5: Render:** Psalms chosen at 18 in a 1,100 pt front page with the pane at its narrowest (nothing stored) and at 40% (440 stored in the render's suite), light, dark and Sepia; and 28 pt in 820 with 440 stored (shown at 328, three across). Check the rule is one point of `ink.rule` and nothing else marks the divider. A render cannot show the cursor, the drag or VoiceOver: say so. Delete the render file.

- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** then the three checkers (no new finding in `PaneWidth.swift`, `PaneDivider.swift`, `FrontPageView.swift`).

- [ ] **Step 7: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI/Library/PaneWidth.swift Packages/ScriptureKit/Sources/ScriptureUI/Library/PaneDivider.swift Packages/ScriptureKit/Sources/ScriptureUI/FrontPageView.swift Packages/ScriptureKit/Tests/ScriptureUITests/PaneWidthTests.swift Packages/ScriptureKit/Tests/ScriptureUITests/FrontPageBenchmarkTests.swift
/usr/bin/git commit -m "A divider beside the chapter pane: drag it wider, double-click it back; the width is kept on this Mac" -m "Co-Authored-By: …"
```

**Controller live pass (keys only, so no drag):** relaunch the Debug app under the handover's rules; capture the front page: the divider is one hairline, the pane at its narrowest for Matt's size (nothing stored yet in `.dev`; write nothing there). The drag, the cursor, the double-click, quit-and-reopen and VoiceOver go on Matt's list.

---

### Task 5: The record

**Run:** implementer Sonnet; task reviewer Sonnet. No view changes; the review checks each document against the code as built and runs the three checkers for the final counts.

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, `docs/superpowers/specs/2026-11-23-milestone-11-home-page-design.md` (section 12), `docs/BACKLOG.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (milestone 11's box 1), `docs/superpowers/specs/2026-11-19-milestone-10-handover.md` ("Numbers Matt may ask to tune")

**Interfaces:**
- Consumes: every name above, as built; `.superpowers/sdd/2026-11-23-milestone-11-home-page/measurements.md`; the ledger's calls.

- [ ] **Step 1: DESIGN.md** (spec 8): section 3 Hierarchy, *Chapter numerals*: the pane's numerals in the page face at the reader size, the cell 2.9 by 2.2 × the reader size (the phone's grid unchanged). Section 3, *The Dynamic Type Contract*: add the front page's book names, Testament titles (1.15 ×) and chapter numerals to the exceptions derived from the reader size, and the group label's rule (0.58 ×, floor `.caption2`, SF Pro semibold through the platform font). Section 3, *The Scaled Metric Rule*: remove "the contents page's 180 pt column and the pane's 260 pt width" and say what replaces each (the widest name at the reader size; five cells at the reader size, at most 40%). Section 5, *Front page*: the names at the reader size, the column width from the widest name (the Apocrypha's where the translation has it), the divider (1 pt `ink.rule`, 8 pt drag area, the resize cursor, no grabber, 40%, the double-click, VoiceOver "Chapter pane width", not a Tab stop), the stored width and its key. Section 5, *Chapter grid*: the computed column count (at least five at or above the five-across width, never fewer than three), the cell, ring and search ring from the reader size; "40 by 32, five across in 260 pt" goes.

- [ ] **Step 2: DESIGN.json:** `components` "Contents Page" (`columns`, `testamentTitle`, `groupLabel`, `book`), "Book Pane" (`width`, `grid`), "Chapter Cell" (`sizes`), a new "Pane Divider" component, and `extensions.typographyMeta.chapterNumeral`, matching Step 1. Check it parses (`python3 -m json.tool DESIGN.json > /dev/null`).

- [ ] **Step 3: README.md** (the front page paragraph and its keys): the book names follow the page text size; the divider drags the pane wider (more chapters across), a double-click returns it, the width is kept on this Mac.

- [ ] **Step 4: The spec's "As built"** (section 12), under the "Measured" paragraph Task 1 wrote: what was built, file by file in one line each; every call from this plan's Departures and the ledger, each marked "(call, unattended)" with its reason and cost; the thresholds; the checker counts after the build (SwiftLint, impeccable-lint, asset; total and in the touched files, and the four old findings fixed); the benchmark's medians at 18 and 28; both suites' counts. Then "For Matt": Task 1's first item if it was written, then the spec's section 10 list for him, then what nobody has seen (the cursor, the drag, the double-click, quit and reopen, VoiceOver's adjust, AeroSpace's window size on launch, where a changed window size is not a regression and the stored width is what to check).

- [ ] **Step 5: docs/BACKLOG.md:** a section `## The home page (milestone 11, project 1)` with the spec's two section 11 lines (the divider from the keyboard; the iPhone's Library at the reader size), worded as the spec words them.

- [ ] **Step 6: The main spec's box 1** under milestone 11: `[x]`, "Built 2026-11-23, unattended; reviewed whole; waiting on Matt's look (the drag)", the spec named. **The Numbers table** in milestone 10's handover: replace the row "How wide the Mac's book pane is | `FrontPageView.swift`, `paneWidth` | 260 pt" with "How narrow the Mac's book pane can be, and how wide | `ChapterPaneMetrics.swift`, `fiveAcross`, `widestShare` | five chapters across at the page size; at most 40% of the window"; add "How big a chapter's square in the pane is beside the page size | `ChapterPaneMetrics.swift`, `cellWidth`, `cellHeight` | 2.9 by 2.2 × the page size" and "The fewest chapters across | `ChapterPaneMetrics.swift`, `fewestColumns` | 3".

- [ ] **Step 7: Run the full package suite, then the full iOS `ScriptureUITests`, one after the other;** record both counts (expected above 1,509 and 1,028 by the new tests); then the three checkers, and record the counts in "As built".

- [ ] **Step 8: Commit**

```bash
/usr/bin/git add DESIGN.md DESIGN.json README.md docs/BACKLOG.md docs/superpowers/specs/2026-11-23-milestone-11-home-page-design.md docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md docs/superpowers/specs/2026-11-19-milestone-10-handover.md
/usr/bin/git commit -m "docs: the home page as built: DESIGN, README, the spec's As built, the backlog, the milestone box and the numbers to tune" -m "Co-Authored-By: …"
```

**After Task 5 (the controller):** the whole-project review on Opus (`/impeccable-swift critique` over `FrontPageView`, `ContentsPageView`, `BookPaneView`, `ChapterGridView`, `PaneDivider`), one fix wave, one scoped re-review; then the handover's "Before a project is called done": both Debug builds, the Mac Debug app restarted after the idle check, the handover's table, the ledger copied to `docs/superpowers/ledgers/milestone-11/2026-11-23-milestone-11-home-page.md`, the box's wording amended to what the review found.
