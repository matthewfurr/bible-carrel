# Handover: the single-chapter reader, book thumb and carry-through drawer

> **Superseded** by `2026-11-13-milestone-9-handover.md`. This file describes the build before Matt's device rounds; the drawer, the chapter labels and the loupe it describes have all been replaced.

Written 2026-11-13 at the end of the session that built this work. Matt is handing his own findings from the devices, about 25 of them, to a new session. They come with the prompt that points here. This file is the context those findings need.

## Where things are

- **Repo:** `/Users/matt/Code/reading-through-scripture`. Native macOS and iOS Bible reader: Swift 6.2, SwiftUI, UIKit/AppKit, TextKit 2, GRDB, SwiftData + CloudKit, Swift Testing. Platforms: macOS 26 and iOS 26.
- **Work happens in the worktree** `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-9-reader`, on branch `milestone-9-reader`.
  - The branch is NOT merged into `main`. Merging is Matt's call.
  - Work in this worktree on this branch. Don't create another worktree.
- **Branch head when this was written:** `8f918b8`. This work is the 30 commits from `5d01405` (its plan) to `8f918b8`. Everything before `5d01405` is earlier milestone 9 work: page styles, the Lectern drop numeral, the running head, Sepia, settings.
- **Both Debug apps are installed from `8f918b8`:**
  - the Mac Debug app, built into `Build/DerivedData` and running
  - the iPhone `.dev` app on Matt's phone
- **Test results at `8f918b8`:**
  - package tests: 930 pass (724 ScriptureUI, 111, 52, 26, 17)
  - iOS `ScriptureUITests`: 673 pass
  - both Debug app builds succeed

## Read these first

1. `CLAUDE.md`, `PRODUCT.md`, `DESIGN.md` in the worktree root. They hold the UI rules and the design system; DESIGN.md now documents the thumb, loupe and drawer.
2. **The design this work implements, approved by Matt:** `docs/superpowers/specs/2026-11-12-single-chapter-reader-and-quick-hops-design.md`. Lines marked **(call)** are choices Claude made that Matt had not confirmed. His device findings may overturn any of them.
3. **The plan:** `docs/superpowers/plans/2026-11-12-single-chapter-and-quick-hops.md`. It has 12 tasks, plus an added Task 7b (scroll cost).
4. **The earlier milestone 9 spec it supersedes in part:** `docs/superpowers/specs/2026-11-12-reader-page-styles-and-book-scroll-design.md`. Its sections 3.3 and 4.3, the book-long scroll, are superseded.
5. `README.md`: how to build, run and install.

## Why the reader is one chapter at a time

Milestone 9 first put a whole book in one scroll. On the Mac the text drifted:
- TextKit 2 throws away the layout of paragraphs above the screen as the reader scrolls up, and lays them out again from estimated heights.
- So text landed thousands of points away from the running head and the Lectern drop numerals, which work from stored positions (Psalm 69 drawn under "Psalms · 73").
- Repairing it costs about 140 ms per layout and recurs every couple of scroll steps.
- One chapter keeps its layout: Psalm 119 alone was tested through repeated upward scrolls.

Matt rejected TextKit 1 because of the cost of a rewrite, and chose to go back to single chapters, with two gestures for moving 2–5 chapters.

## What was built

- **One chapter at a time** on both devices.
  - `ReaderDocument` builds exactly one chapter.
  - The book-window machinery was deleted: `BookWindow`, the budgets, edge requests, extension anchors and the hold machinery.
  - Every chapter ends with Previous/Next links (`ChapterEndLinks`). They are side by side, or stacked when narrow, and the foot reserves their measured height.
  - Every chapter opens below the running head. The head fades in as the opening scrolls under it.
- **Book thumb** (`BookThumb`, `BookThumbView`), on both devices.
  - It is a track at the right edge with one tick per chapter, the current chapter lit.
  - Dragging shows a Liquid Glass loupe with the chapter number only (`LoupeView`, `LoupeRenderer`). Core Image draws the bend and the colour fringe, because the Metal Toolchain is not installed; it would be a 700 MB download needing Matt's OK.
  - Lenses are drawn off the main actor and warmed when the thumb is grabbed.
  - **Mac:** `ThumbRevealTracker` (an `NSTrackingArea`) shows the track when the pointer is within 40 pt of the edge, and on any scroll. It hides 1 s later.
  - **iPhone:** a long press (0.3 s) in the right 28 pt opens the thumb. The system scroll indicator is hidden. A press that never moves cancels when lifted.
  - A thumb jump pushes history.
- **Scroll cost.** Per-frame head state lives in an `@Observable ReaderChrome`, so scrolling redraws only the head and the progress line.
  - Tests gate it by counting redraws: `ReaderView.bodyEvaluations` and `PhoneReaderScreen`'s counter are 0 during a scroll.
  - The Mac reader still costs about 0.35–0.4 ms per frame more than the bare text controller. That is SwiftUI re-laying out its host because TextKit 2 adds and removes views, and only a private API removes it. Parked.
- **Carry-through drawer, iPhone only.**
  - The pure logic is in `SUI/CarryThrough.swift`: `CarryThrough` constants, `CarryThroughDeck`, `CarryThroughState`, the reducer, `CarryThroughEvent`/`Input`/`Effect`. It has no platform guard, so `swift test` covers it.
  - `PhoneChapterTextController` reports pulls and arrivals through `CarryThroughTracker`.
  - `Phone/CarryThroughDrawer.swift` holds the view, with the model in `CarryThroughDrawerModel`.
  - **What opens it:**
    - pulling 80 pt past the end or the top, from a page at rest there;
    - arriving at an end faster than 2,500 pt/s.
  - **The deck:**
    - it starts on the next chapter, and each 56 pt more of pull is one more page;
    - easing back under 80 pt cancels;
    - it never crosses books;
    - the glass overshoots, up to 12% taller and 4% narrower, then settles;
    - each page lift is a separate spring.
  - **Landing rules (Matt):**
    - forward: at the chosen chapter's start;
    - back by one after a pull at the top: at the previous chapter's end, meaning the previous chapter the translation HAS;
    - chosen after a fast arrival: at its start;
    - back by more than one: at its start.
  - **After a fast arrival** the drawer stays open until a page is tapped, it is swiped away, or the page is touched. Touching the page closes it, and that touch still scrolls or acts.
  - A drawer turn uses `NavigationModel.turn(to:atEnd:)` and pushes history.

## Known issues and parked items, before Matt's findings

- **The thumb's back-to-start case (iPhone).**
  - **The bug:** a press that moves off its starting chapter and comes back to it does nothing when lifted. It should land there, unless that chapter is the one being read.
  - **The fix:** in `Phone/PhoneThumbScrub.swift`, land when `hasLeftStart && last != current` (track a flag set on the first `.moved` to another chapter), instead of `last != start`.
  - **The test to update:** `aPressThatNeverLeavesItsChapterLandsNowhere` asserts the wrong behaviour for the away-and-back case.
- **Uncompiled intermediate commits.** `643ffea`, `1332928`, `4283c6c` and `ac800e9` were never compiled on their own, only the final tree. This only matters for bisecting.
- **An untested path.** The away tap's `shouldReceive` path that closes an arrival drawer has no test of its own. The drag path is tested.
- **Numbers to tune on the devices:**
  - pull threshold 80 pt
  - arrival speed 2,500 pt/s
  - page travel 56 pt
  - thumb edge zone 28 pt
  - thumb hold 0.3 s
  - drawer spring stiffness 260, damping 18
  - stretch 0.12 and narrowing 0.04
  - the loupe's bend 0.3 and fringe 1.5 pt
- **Not seen by eye.** By Matt's standing rule, no screenshots were taken and nothing was checked by eye. Every look-and-feel item is unverified: glass, springs, loupe, haptics, landscape, Reduce Motion, Reduce Transparency, VoiceOver, the Mac thumb with overlay scrollers.
- **Smaller parked items:**
  - Lectern with sixty highlights scrolls at about 1.1 ms per frame on the Mac.
  - The Mac thumb track flashes for 1 s after landings and resizes.
  - A click on the Mac track lands at once (`minimumDistance: 0`).
  - One haptic per drag event, not per chapter passed.
  - The drawer's page sheets have a 1 pt stroke, named as an exception in DESIGN.md.
  - Stale multi-chapter wording remains in `MarkupTarget.swift:55-71`, `MarkupModel.loadWindow` and `PhoneReaderScreen.swift:73,731`.
  - Nothing tests that Ask About This Chapter follows a chapter change.
  - `PhoneReaderScreenTests` need `.needsRealBible`, which means `Build/bible.sqlite` must exist.

## Rules that bind every session here

- **Git:**
  - Use `/usr/bin/git` with one git command per Bash call: no `cd … &&`, loops or shell variables in git calls. A worktree guard refuses compound commands.
  - Commit on `milestone-9-reader` only. Never push or merge without Matt's say.
  - End commit messages with the attribution line the harness gives.
- **Matt's real data:**
  - Never touch his Release app, `Scripts/install-app.sh`, or `~/Library/Application Support/ReadingThroughScripture` (his real store) or its keychain item.
  - Debug (`.dev`) is fully separate and safe.
- **Screen Recording:** never block on a Screen Recording prompt. Verify with tests, real-window test harnesses, `os_log` probes read with `log show`, and Accessibility queries. Say plainly which visual checks were skipped.
- **Mac Debug app:**
  - Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
  - Quit it: `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`. Never use `pkill -x`, which also quits his Release app.
  - Then `open` the Debug app.
- **iPhone:**
  - Install: `Scripts/install-phone.sh debug`. The phone must be unlocked and ProtonVPN off; "tunnel connection failed" means the VPN.
  - Never toggle the VPN yourself.
  - The simulator is "iPhone 18 Pro Max".
- **Tests:**
  - Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit`
  - iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`
  - Run builds one after another; they share `DerivedData`.
- **TextKit 2 only:** never touch `textView.layoutManager`. Real-window `NSWindow`s in tests need `isReleasedWhenClosed = false`.
- **UI rules (CLAUDE.md):**
  - No fixed-point fonts in chrome; use `@ScaledMetric`.
  - No inline colours; Palette tokens only, with new pairings added to `PaletteTests`.
  - `AppSpacing`/`AppRadius` for spacing and corners.
  - No card by reflex.
  - Deletes are undoable, never confirmed.
  - `.glassEffect()` only in the loupe and the drawer.
- **Working with Matt:**
  - He wants decisive, concise answers.
  - Show mockups before building anything visual; he usually picks the fuller option.
  - Don't stall: never end a turn with work undone or waiting on something that isn't his decision.
  - He is frustrated by lost nights: one stalled on screen-recording permission, one where the work was never started. Start work promptly and keep him informed in one line per step.

## Suggested way to work through Matt's findings

1. Read his list. Sort it into bugs, look-and-feel tuning, and design changes. For any finding that contradicts the approved design, check with Matt before building.
2. Bugs and tuning can go straight into a short plan. Design changes go through a quick design pass with mockups.
3. For each fix: a failing test first where the behaviour is testable, then the fix, then the package tests, the iOS tests and both builds. Reinstall both Debug apps when a batch is done.
4. Include the back-to-start thumb fix above unless Matt's list already covers it.
