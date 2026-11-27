# SDD ledger — plan: docs/superpowers/plans/2026-11-23-milestone-11-home-page.md

Spec: docs/superpowers/specs/2026-11-23-milestone-11-home-page-design.md
Workspace: .superpowers/sdd/2026-11-23-milestone-11-home-page/ (briefs, reports, review packages, global-constraints.md, preflight.md, baseline logs)
Session started 2026-11-23, run unattended (the handover's "The unattended run"). Controller: Opus (a controller subagent of the planning session). Implementers and task reviewers: the model each task's Run line names.

## Model change

- Matt, relayed by the planning session during step 0: "No Fable. Opus 5.5 instead of Fable for all projects related to Milestone 11." So the plan's drafting subagent and the whole-project review run on Opus, not Fable. No Fable subagent had been dispatched when the change arrived.

## Baseline (worktree at 22f9825, the code of f33658a)

- Mac Debug build: succeeded (first build in this worktree; it built Build/bible.sqlite at schema 5). Log: baseline-mac-build.log.
- Package suite: 1,509 passed (1,097 in 105 suites, 241 in 27, 52 in 10, 91 in 13, 28 in 6). Log: baseline-package.log.
- iOS ScriptureUITests: 1,028 in 100 suites passed (the iOS Debug build with it). Log: baseline-ios.log.
- Checkers: SwiftLint 87, impeccable-lint 27, asset checker 0 (the handover's baseline). In the files this project touches: FrontPageView.swift 6 SwiftLint (accessibilityHidden at :71, :83, :153; frame off the scale at :70, :82, :151), Library/ContentsPageView.swift 2 (:148 frame, :149 accessibilityHidden); ChapterGridView.swift none; impeccable-lint none in any of them. Files: baseline-swiftlint.txt, baseline-impeccable.txt, baseline-assets.txt.

## Rulings

- Plan drafted on Opus (a6d88780687986b6c), committed a2203a6 with the process rules pointed at milestone 11's worktree (they named milestone 10's). Its 11 departures are built as written, each "(call, unattended)".
- Ruling: global-constraints.md is the plan's Global Constraints copied verbatim — none.
- Ruling: renders go to the session scratchpad, /private/tmp/claude-501/-Users-matt-Code-reading-through-scripture/833408d4-1099-4a4f-9996-0bb2a261fbb6/scratchpad/renders — none.

## Pre-flight

preflight.md (Opus, a2386173e4875e127): ~120 interfaces checked, 3 conflicts, 8 gaps, all ruled in the plan's new "Pre-flight rulings" section before Task 1:

- 1 Ruling: `.pointerStyle` inside `#if os(macOS)` — unavailable on iOS — none.
- 2 Ruling: `GroupLabel.tracking(forSize:)` nonisolated — Swift 6 isolation — none.
- 3 Ruling: `theWidthIsNotSynced` @MainActor — none.
- 4 Ruling: the "This week" band holds 4 across at 1,100 (was 5); accepted (call, unattended); PlanBandTests repinned in Task 3; DESIGN.md and doc comment in Task 5; on Matt's list — if wrong: the band's 140 pt minimum is retuned.
- 5 Ruling: the size-change scroll is a separate onChange that never sets focus — keeps Tab-into-pane — none.
- 6/7 Ruling: the divider is an overlay on the pane's leading edge, no layout width, 8 pt centred, above both siblings — fixes the half-covered hit area and the 1 pt measurement drift — none.
- 8 Ruling: Task 1's pin also checks every ESV and KJV name fits its column at 14, 18, 28 — spec 10's first test — none.
- 9 Ruling: DESIGN.json's Group Label, Chapter Ring and Chapter Cell keys added to Task 5 — none.
- 10 Ruling: an always-shown scroller narrows the narrowest grid; accepted, on Matt's list as unseen (call, unattended) — if wrong: columns read the scroll view's content width.
- 11 Ruling: the drag works from translation, its start recorded on the first change — no 4 pt jump — none.

## Tasks
- Task 1: implementer a35f2b474bd105e1a (Sonnet), BASE f6250e2, HEAD f02ea09, DONE. Measured: the ESV at 18 pt in the 1,100 pt window holds THREE columns of books (widest 145, column 172, pane 316, contents 736), so the Testaments stack at the default size; ESV/KJV: 5 at 14, 4 at 16, 3 at 18-22, 2 at 24-28 (1,100); 3 at 14, 2 at 16-22, 1 at 24+ (820); the four other faces hold 4 at 18; CPDV and WEB one fewer from 14. Table: measurements.md. Recorded first on Matt's list in the spec's As built (unattended: not asked). Suites by its report: package 1,519 (1,107+241+52+91+28), iOS 1,028. Checkers 87/27/0. Process note: code written before the tests; the red was recorded afterwards by moving the files away.
- Task 1: review (Sonnet a51da888395793670): spec ✅, quality Approved (task-1-review.md).
- Task 1: complete (commits f6250e2..f02ea09, review clean)
- Task 1: minor (deferred): the ruling-7 per-name assertion reuses the function that built the column; the SwiftUI-hosted fit test is the independent check but covers three names.
- Task 2: implementer a69c2e5756c3c2d5a (Sonnet), BASE f02ea09, HEAD 7548750, DONE (calls: readerSize last in FrontPageView's init so MainWindowView's trailing closure is labelled; HairlineRule carries no accessibilityHidden). Suites by its report: package 1,520, iOS 1,028, Mac Debug build ok. Benchmark medians 67.7 ms (18), 69.0 ms (28). Checkers 83/27/0 (FrontPageView 4 from 6, ContentsPageView 0 from 2). Controller opened esv-18-light.png: four columns beside the old 260 pt pane, as expected before Task 3.
- Task 2: review (Sonnet a5224e2e4f47e8c1b): spec ✅, quality Approved (task-2-review.md).
- Task 2: complete (commits f02ea09..7548750, review clean)
- Task 2: minor (deferred): the Testament's "39 books" count stays .caption beside a title at 1.15 × the reader size, so it reads small at 28 pt (spec 4.1 keeps it .caption) — for the whole-project review.
- Ruling: the controller's live passes for Tasks 2, 3 and 4 are made as one pass after Task 4, on the worktree's Debug build, each task's checklist in turn — the running Debug app is the main checkout's milestone 10 build and implementers rebuild the worktree's bundle between tasks; one relaunch serves all three — if wrong: a defect that only shows live is found one or two tasks later.
- Task 3: implementer aa09d1099085dea38 (Opus), BASE 7548750, HEAD 148d619, DONE_WITH_CONCERNS (New York and Iowan numerals stay at .title3; calls: .animation(nil, value: columnCount), columns clamped ≥1 in the statics, ← → still wrap rows). Suites by its report: package 1,523 (1,111+241+52+91+28), iOS 1,028, Mac build ok. Benchmark medians 74-79 ms (18), 78-83 (28). Checkers 83/27/0. PlanBandTests repinned (4 at 1,100, 3 at 820).
- Task 3: review (Opus aa411e1eaf27d8339): spec ❌, Needs fixes (task-3-review.md): Important, plan-mandated: PageFace.numeralFont(size:) ignores the size in New York and Iowan.
- Task 3: Ruling: the spec (5.2, numerals at the reader size) wins over the brief's named call; fixed for the pane only, the phone's .grid fallback unchanged — the phone is out of scope — if wrong: none visible.
- Task 3: fix round 1 dispatched (resumed aa09d1099085dea38), FIX_BASE 148d619.
- Task 3: minor (deferred): each frame of a window resize stores the width and re-evaluates the front page (FrontPageView.swift:80); Task 4 may narrow it.
- Task 3: minor (deferred): the open benchmark rose ~10 ms (second layout pass); ~15 ms headroom under load.
- Task 3: minor (deferred): a column-count change while the grid has focus does not call onRevealChapter, so the cursor can slide out of view (ChapterGridView.swift:131-140) — for the whole-project review.
- Task 3: minor (deferred): nothing checks the LazyVGrid places a cell where cursorRect says.
- Live-pass items from the review: a first-frame flash at 28 pt in a small window (461 pt five-across before the width is known, then 328 three-across); the cursor in view after a column-count change.
- Task 3: fix round 1/5 (1 addressed, 0 open — the pane's numerals at the reader size in New York and Iowan via PageFace.paneNumeralFont(size:), phone unchanged; commits 148d619..8b9fd06). Re-review (Sonnet a19c2e974d51f49f8): ADDRESSED, no new breakage (task-3-rereview-1.md). Full suites not re-run after the fix (focused PageFaceTests/ChapterGridTests and iOS PageFaceTests passed; Mac build ok); Task 4 runs both.
- Task 3: complete (commits 7548750..8b9fd06, review clean after 1 round)
- Task 4: implementer (Opus), BASE 8b9fd06, dispatched.
- Task 4: implementer afd283acd396ce2e8 (Opus), BASE 8b9fd06, HEAD 35e13a2, DONE (calls: onGeometryChange not narrowed). Suites by its report: package 1,531 (1,119+241+52+91+28), iOS 1,029 (PageFaceTests' new test runs there too), Mac build ok. Benchmark 76.9/81.1 ms alone, 77.3/84.5 under load. Checkers 83/27/0.
- Task 4: review (Opus a78a4c62ec33ed32f): spec ✅, quality Approved (task-4-review.md).
- Task 4: complete (commits 8b9fd06..35e13a2, review clean)
- Task 4: minor (deferred): a VoiceOver decrement at the narrowest with nothing stored writes 316, ending size-tracking (PaneWidth.swift:268).
- Task 4: minor (deferred): a drag cancelled without an end leaves the drag start set (PaneWidth.swift:252).
- Task 4: minor (deferred): no test pins "never written on open"; every init reads UserDefaults.
- Task 4: concern (deferred): VoiceOver likely reads the divider after the pane's grid (it is the pane's overlay); the 4 pt drag area over the contents covers the inner edge of their scroll bar.
- Task 5: implementer a838026876797b08e (Sonnet), BASE 35e13a2, HEAD b7506b5, DONE. Suites: package 1,531, iOS 1,029. Checkers 83/27/0.
- Task 5: review (Sonnet a88e184c41735a64e): spec ✅, Approved (task-5-review.md). ⚠️ box 1 says "reviewed whole" before the review: amended by the controller after it.
- Task 5: complete (commits 35e13a2..b7506b5, review clean)
- Task 5: minor (deferred, for the fix wave): DESIGN.md:161 sentence fragment; As built calls 8 and 14 have no cost; the Task 2 call (readerSize last in the init) missing; "CPDV and WEB one fewer from 14" wrong at 18, 20, 24, 26; columnCount listed under ContentsPageView.swift (it is ContentsPage.swift:148); "accessibilitySortPriority" named in Matt's text.
- Live pass (Tasks 2-4), on the worktree's Debug build (pid 18437, window 32963, 1,638 pt wide by AeroSpace): idle 4,373 s before launch; ⇧⌘H to the front page: six columns of books at 18 pt in 1,638 pt, nothing truncated, pane at its narrowest with five across, rings in colour, the divider one hairline. Synthetic keys reset the idle counter; skipping the idle check was refused by the permission classifier, so each key waits for 31 s of idle. ⌘= did nothing (the menu's key is ⌘+, Shift-=); Text & Layout (⌘T) is disabled on the front page.
- Live pass, continued: ⌘+ (Shift-=) three times took the size 18 → 21 (defaults read 21): five columns of books, the pane wider with five across, nothing truncated, Zechariah still chosen and in view, focus on it kept (04-plus3.png). ⌘− three times back to 18 (defaults read 18), the page as it was (05-minus3.png). Return moved into the pane with the cursor on 14; ↑ to 9 (a whole row of five), ← to 8 (06-08 captures). No Return in the pane (it would move the reading place in .dev). frontPagePaneWidth absent from .dev's defaults after the pass. The two rules under the band are the band's progress track and the band rule (checked in the fix wave by reading).
- Whole-project review (Opus ae268501213505955, final-review.md): ready with fixes; Critical none; Important 1: a drag or VoiceOver step that changes nothing still stores a width (PaneWidth.swift:39-51); critique 32/40; checkers 83/27/0. Its "Matt reads at 16" inference is wrong: .dev's readerFontSize is 18 (the ring is drawn inside the cell).
- Ruling: the fix wave takes Important 1 and Minors 1, 2, 3, 4 (docs), 7 (check, fix if it shows), and three backlog lines (the caption count, drag/resize cost, grid placement) — the review triaged them fix-now and they are small — if wrong: a little more code in this wave.
- Ruling: Matt's list says ⌘+ and ⌘− instead of ⌘T for watching the names follow; spec sections 1-11 stay as approved — Text & Layout is disabled on the front page — none.
- Fix wave: implementer (Opus), FIX_BASE b7506b5, dispatched (fix-wave-brief.md).
- Fix wave: implementer a7d15079cfdaeb2a2 (Opus), FIX_BASE b7506b5, HEAD 49b92c1 (bedaf80 code, 49b92c1 docs), DONE. Package 1,536, iOS 1,029, Mac build ok, checkers 83/27/0. Item 5: the searched first chapter's ring WAS clipped at 28 pt; the grid's top padded by searchRingWidth. Item 6: the two rules under the band are the plan's progress line and the band rule, both at 22f9825 (pre-existing).
- Fix wave re-review (Opus a336dfaa0130ea406, fix-wave-rereview.md): 12 ADDRESSED, 0 not; no new Critical or Important. The ended-drag order settled by a scratch host test (onEnded stores, the reset comes a frame later, the deferred cancel has nothing to undo).
- Fix wave: minor (to the backlog): a deferred cancel can land on the next drag if the reader lets go and presses again within one frame; tie the cancel to its drag with a counter.
- Fix wave: minor (to the backlog, pre-existing): a double-click whose second click moves 1 pt stores the jitter as a drag instead of resetting.
- Fix wave: minor (fixed by the controller in the finishing docs): As built call 18 calls the reader size the init's last parameter; the pane's defaults come after it.
- Ruling: the two re-review minors go to docs/BACKLOG.md, not a second wave — the handover's unattended rule (one fix wave; only a Critical is fixed after the re-review) — if wrong: a rare snap-back after a very quick second drag until fixed.

## Finish

- Final runs at 49b92c1, one after another, by the controller: package 1,536 (1,124 in 109 suites + 241 + 52 + 91 + 28), iOS ScriptureUITests 1,029 in 100 suites, Mac Debug build succeeded, iOS Debug build (simulator) succeeded. Checkers: SwiftLint 83 (baseline 87), impeccable-lint 27, asset 0.
- Mac Debug app: idle 1,453 s; quit by path; reopened from the worktree's build (pid 28848); the log shows only CloudKit's "Giving up waiting to register for remote notifications" and a BackgroundSystemTasks line, no app error. readerFontSize 18, frontPagePaneWidth absent in .dev.
- The iPhone's Debug app not installed (unattended run); on Matt's list.
- Docs: the spec's As built (review, fix wave, live pass, final counts; call 18 corrected; Matt's list items 11 and the cancelled drag), the main spec's box 1, docs/BACKLOG.md (two re-review minors), the handover's table, tests, checker and builds lines (with the planning session's uncommitted model-change line, committed with it).
- This ledger copied to docs/superpowers/ledgers/milestone-11/2026-11-23-milestone-11-home-page.md. The workspace is kept (the skill's delete step is not taken: the handover keeps ledgers, and later projects may want the renders' notes).
