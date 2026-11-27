# Milestone 10, Project 5: Reading Plans Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task: one fresh implementer and one fresh reviewer per task, on the model each task's **Run** line names, then one whole-project review on Fable with its report written to a file. Steps use checkbox (`- [ ]`) syntax for tracking. The ledger is `.superpowers/sdd/2026-11-19-milestone-10-reading-plans/progress.md`.

**Goal:** The church's reading plan comes in from its PDF (or is typed), is checked on a review screen and kept as one synced record with one small synced record per tick; this week's readings then show over the Mac's front page, behind a button in the reader's toolbar, in a plan window, and on a Plan tab on the iPhone.

**Architecture:**
- Pure values and rules in `ScriptureData/Plans`, tested with no store and no clock: `ReadingPlan` (weeks, readings, passages), `PlanDay` (a meeting date is a calendar day, never an instant), `PlanSchedule` (this week, moving a date, anchoring), `PlanReadingText` (a reading as a line of text), `PlanDraft` (what the review and the editor edit), `PlanText`, `PlanYears`, `PlanReview` (the flags), `PlanTableReader` (words with positions to weeks), `PlanCoding` (the stored form, version 1).
- Two new SwiftData models in the synced store, `PlanRecord` and `PlanTick`, behind `PlanStore`; duplicate ticks merge after every import as duplicate bookmarks do; Restore brings back missing plans and ticks.
- One observable `ReadingPlanModel` in `ScriptureUI/Plans` feeds every surface and is reloaded by `AppSync` after each import, each change of the synced "which plan is followed" preference, and each new day. The views are thin SwiftUI over it, shared between the apps where a piece is the same.
- PDFKit is used only in `ScriptureUI` (`PlanFileImport`), off the main actor.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit and UIKit, PDFKit, SwiftData with CloudKit, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-16-milestone-10-reading-plans-design.md`. Read it with this plan; section numbers below are the spec's. Its section 7 is exactly what Matt approved for iCloud, and this plan stores nothing beyond it. The mockup is `docs/superpowers/specs/milestone-10-mockups/reading-plan-where.html`; the proved PDF reader is `docs/superpowers/specs/2026-11-16-reading-plan-spike/parse.swift`.

Paths: `SD` is `Packages/ScriptureKit/Sources/ScriptureData`, `PL` is `SD/Plans` (new), `SM` is `Packages/ScriptureKit/Sources/ScriptureModel`, `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `UP` is `SUI/Plans` (new), `PH` is `SUI/Phone`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `TD` is `Packages/ScriptureKit/Tests/ScriptureDataTests`, `TM` is `Packages/ScriptureKit/Tests/ScriptureModelTests`, `MAC` is `Apps/Mac/ReadingThroughScripture`, `IOS` is `Apps/iOS/ReadingThroughScripture`, `SHARED` is `Apps/Shared` (every file in it is in both app targets; a new file needs no project edit).

**Built on, read in the code at `f2717f6` (2026-11-19; the code is `b5d51dc`'s, the commits since are documents).**
- The store: `MarkupContainer.schema` (seven models: `Highlight`, `Note`, `Bookmark`, `HighlightColor`, `ChatThread`, `ChatMessage`, `PromptTemplate`; the same list is written a second time in `AppSync.initializeSchema`, `SHARED/AppSync.swift:289-292`); `MarkupContainer.make(inMemory:)` and `make(at:sync:)`; no versioned schema and no migration plan (a change is additive and the store moves forward when a build with the new models opens it); `MarkupStore` (owns the container; `delete(_:)`/`restore(_:)` over `MarkupDeletion`); `ChatStore` and `PromptTemplateStore` as second stores on the same container; `SeedMerge.mergeAll(in:seeds:)`, run by `SyncCoordinator.prepareNow()` and `importFinished()`, with `mergeDuplicateBookmarks` (the earliest `createdAt` survives, ties the lowest uuid); `StoreCopy.copyMissing(from:into:)` and `RestoreSummary`; `BackupsModel.sentence(for:)`; `StoreBackup` (a file copy, so it carries any model).
- Sync: `AppSync` (`Models`, `attach`, `reloadModels()`, `startPreferences()` and its `onExternalChange`); `StoreLocation.resolve(sync:storeName:)` and the `-storeName` launch argument; `SyncProbe` (`MAC/SyncProbe.swift`, Debug, `-syncProbe bookmark:GEN.1.1`); `PhoneSeed` (`-phoneSeed YES`); `SyncedPreferences.keys` (19 keys, each named in `PreferenceSyncTests.theSyncedKeysAreExactlyThese`); `PreferenceSync.merge()` offers up any key the defaults have and the cloud lacks.
- Navigation: `NavigationModel.open(_:verse:)` is the reading move (it ends a lookup, goes through the history, stores the place and records a recent); `lookUp` is not; `books: [TranslationBook]` (the translation being read, with `chapterCount`); `translationID`; `chapterCount(ofBook:)`.
- References: `ReferenceParser.parse(_:exactBook:)` (a book alone parses; "Esther 7-8" does not); `BookCatalog.all`, `book(code:)`, `Book.name` ("Psalms", "Song of Solomon"; "Song" is its short name); `Reference.displayString` writes "Psalm 84" and cannot hold a run of chapters.
- The Mac: `FrontPageView(navigation:marks:onOpenSettings:)` with `left` (the contents, or `LibraryView` while `navigation.libraryPlace` is set) and `pane`; `MainWindowView` (its `body` chain is at the type checker's limit: add modifiers to `page` or a new helper, never to `body`; the toolbar is `toolbarContent`, `:348-407`); `ReadingThroughScriptureApp` (`Window("Notes", id: notesWindowID)`, the View menu's `CommandGroup(after: .toolbar)`, `wirePalette`'s `performCommand` switch, `showMainWindow()`); `NotesBrowserView` and `NotesBrowserModel` (own rows in a lazy stack, one focus stop, `confirmationDialog` before a delete, undo through the window's `UndoManager`).
- ⌘K and keys: `PaletteCommand` (`all.count == 32`, pinned in `PaletteCommandTests` and `NavigationModelTests:1949`; every property is an exhaustive switch); `ShortcutCatalog.groups`; `ShortcutCatalogTests.everyMenuShortcutInTheMacAppIsListed` reads `.keyboardShortcut("x", modifiers: …)` in `SUI` (not `Phone`) and `Apps/Mac`.
- The phone: `PhoneTab` (read, notes, ask, search), `PhoneScreen` (library, read, notes, ask, by raw value), `PhoneShellModel.screen`, `screen(swipingFrom:)`, `show(_:)`, `showInReader()`; `PhoneRootView`'s `TabView`; `PhoneEdgeSwipes` (generic over the chain; it never begins inside a pushed screen); `PhoneEdgeSwipesTests` hosts its own three-tab shell; `UndoResponder` (`PH/PhoneNotesScreen.swift:285`).
- Tests: `FixtureStore.make()` (PSA 1, 2, 118, 119; MAT 1 to 6; TOB 1; WEB and KJV); scratch `UserDefaults` suites as `NavigationModelTests` makes them; `ReaderBenchmarkTests.median(_:runs:prepare:_:)`; `TestWindow.make(frame:)`. Head counts: package 1,258 (1,002 in the main bundle), iOS `ScriptureUITests` 934.

If a name differs when a task is built, say so before going on.

## The PDFs, measured

The spike script was run once against both PDFs on 2026-11-19 (output in the drafting session's scratchpad, never in the repository). Both are 612 by 792 pt pages.

| | Gen 1 (`Gen 1_ RTS Reading Plan.pdf`, 12 pages) | Gen 2 (`Gen 2_ RTS Reading Plan.pdf`, 13 pages) |
|---|---|---|
| Weeks | 67, every one of five readings | 86: 77 of four readings and the last nine (78 to 86) of three |
| Readings | 335 | 335 |
| Dates | none | one per week; "Feb 29" is week 68's |
| Rows with no Wisdom passage | 40: 15 "Holidays", 25 "NT Focus Week" (32 of them take the label from a merged cell printed once in the week) | 40: 25 "NT Focus" (printed on each row), 15 blank |
| Warnings, unplaced fragments, week-number breaks | none | none |
| Header (page 1) | y 663.3: Wk 131–145, Wisdom 179–218, Chp 262–282, OT/NT 350–379, Chp 450–469 | y 665.9: Wk 76–91, Wisdom 107–146, Chp 180–199, OT/NT 243–273, Chp 306–325, Meeting 369–407, Date 410–431 |

- **Week 63 of Gen 1** (page 11), as the spec's section 11 lists it: Psalms 71 · Esther 1–3, Psalms 73 · Esther 4–6, Psalms 84 · Esther 7–8, Psalms 90 · Esther 9–10, Psalms 92 · Ezra 1–3.
- **Geometry.** Every cell is centred in its column. Rows are 18.5 pt apart. In Gen 1 a week's last row and the next week's first are 37 pt apart (the tinted gap). In Gen 2 there is no gap: the week's date sits on a row of its own after its readings, its words starting at x 338 ("Sept 15 / Leader Dinner", "Nov 17 - OFF", "Feb 29"). The Wk column holds the word "Wk" on a week's second row and its number on the third. A page's first row is at y 705.5 (page 1's at about 641, under the header).
- **Merged cells** (Gen 1): "NT Focus Week" and "Holidays" are printed once, on the week's middle row, centred across both Wisdom columns (x 201–272); the other rows' Wisdom cells are blank. Week 23 has one and crosses a page break (four rows on page 4, the fifth on page 5).
- **Wrapped names** (Gen 2): "Lamentation" is printed 13.2 pt above a row whose Wisdom cell is "s"; "1" and "2" are printed 13.3 pt above "Thessalonians" in the OT/NT column, and the rows there are not 18.5 pt apart.
- **Other forms seen:** "Song" for Song of Solomon; "119:1-16" (and overlapping runs, "119:64-80" after "119:49-64", kept as printed); "18-19"; "2,3 John, Jude" with chapter "1"; "Sept" and "Sep" both.
- **The years, and what the spec assumes.** The spec's section 6.1 says Gen 2 read on 16 November 2026 "gives a start of 15 September 2025, and Feb 29 falls in 2027 and is flagged". Two things were found:
  1. The rule as written does not choose: on that day both 2025 and 2026 put today inside the plan's two-year span. This plan breaks the tie toward the earlier year, which gives the spec's result.
  2. The PDF's own dates say 2026. Starting 15 September 2026 all 86 dates are Tuesdays, a week apart, and 29 February 2028 exists (a Tuesday). Starting in 2025 they are Mondays until 22 February 2027, then "Feb 29" does not exist and the eighteen dates after it are Sundays. So the flag Matt's list expects ("see Feb 29 flagged") comes from reading the plan a year early. **Built as the spec says; the question is Matt's** (Before Task 1). The review's sentence for the flag points at the fix ("or change the year the plan starts").
- **Not measured here:** how long the reader takes (the spec says about a second on the Mac; Task 5 times both files, Task 12 the phone's read of a drawn PDF).

## Before Task 1 (the controller)

1. **Ask Matt the three questions** at the end of this section and write his answers here.
2. **The older build.** "An older build" is the code at `f2717f6` (project 4's). Write the head's SHA here before Task 1 commits anything, if it is no longer `f2717f6`: `OLD = f2717f6`.
3. **Only if Matt chooses Procedure B (below):** before any implementer builds, copy the Debug app as it stands, which is project 4's build: `ditto Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app <scratchpad>/OldBuild/ReadingThroughScripture.app`.

**What was found about a stand-in store.** `-storeName Second` opens a second file beside the Debug app's own, in `~/Library/Application Support/ReadingThroughScripture/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development/`, and `MarkupContainer.make(at:sync:)` mirrors it to the private database of the container in the build's signature. So a stand-in store of the Debug build is a second local file on **the same iCloud database** as the `.dev` store: a plan made in it is uploaded there, and is then imported by the Mac's `.dev` store and by the Debug app on Matt's phone as soon as each runs a build that knows plans (the phone's present build, which is older, receives the records and is expected to skip them, which is the very thing being tested). A stand-in instance also shares the Debug app's preferences and its iCloud key-value store. Milestone 7 could rehearse this way because the phone's app did not exist yet. It cannot be done now without breaking "Put no test plan in the .dev store".

**Procedure A, the safest, and this plan's default: a rehearsal identity.** The Debug configuration built with three settings given on the command line, and nothing changed in the repository (see "The rehearsal identity"): bundle id `com.matthewfurr.ReadingThroughScripture.rehearsal`, container `iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal`. It shares nothing with the `.dev` or Release apps: its own iCloud database, key-value store, preferences, keychain group and store folder. The same identity is where the controller makes every live pass that needs a plan on screen. **Its cost, which needs Matt's word:** Xcode's automatic signing registers a new App ID and a new iCloud container on his developer account, and a CloudKit container can never be deleted. It will sit there empty.

**Procedure B, if Matt would rather not have a third container:** the rehearsal runs in named stores of the `.dev` container, contained as Task 4 says. What it costs: for about half an hour a plan record, two ticks and one bookmark on Genesis 1:1 are in the `.dev` iCloud database. The Mac's `.dev` store does not take them if the Debug app stays quit until they are deleted. The phone's Debug app, if opened in that half hour, shows the bookmark until it is deleted, and receives the plan records it does not know. And the controller then has no store in which to show a plan in a live window, so no live pass with a plan is made: every task's "only a live window can show" list goes to Matt's list.

**Questions for Matt:**
1. The rehearsal identity (Procedure A: one more iCloud container on your account, for ever, empty), or Procedure B (a stand-in plan in the `.dev` iCloud database for about half an hour, and no live passes by the controller)?
2. Gen 2's year: keep the spec's reading (starts 15 September 2025; "Feb 29" flagged; the reader changes the year in the review), or have the app prefer the year in which the dates fall a week apart on one weekday (starts 15 September 2026; nothing flagged)? Built as the spec says unless you say otherwise; the change is one function (Task 2) and the tests that expect 2025 (Task 2's years test, Task 5's check of the real Gen 2 file).
3. Dates are written as the system writes them for your region ("Tue, Nov 17" in the US), not day first as the spec's examples are ("Tue 17 Nov"). Say if you want the spec's order fixed whatever the region.

**Matt's answers.** Asked on 2026-11-19, as the build began. `OLD = f2717f6` (the head when the plan was committed). Until he answered, the build went on with no rehearsal identity, the spec's year and region-ordered dates (Tasks 1 to 6).

**Answered 2026-11-19, after Task 5:**
1. **"Rehearsal build (Recommended)".** Procedure A: the `.rehearsal` bundle id and iCloud container, which stay on his developer account for good. The rehearsal and the controller's live passes use it.
2. **"Prefer dates a week apart".** The import chooses the first year in which every date exists and all fall on one weekday; among several such years, or when none is, the spec's rule decides (the earliest year that puts today inside the plan, else the nearest). Gen 2 then starts 15 September 2026 and nothing is flagged. This overturns the spec's 6.1 result ("a start of 15 September 2025, and Feb 29 … is flagged") and the last item of its section 11 list; "Decided here"'s "Two years fit" line and Task 2's and Task 5's expectations of 2025 are superseded by the change made after Task 6.
3. **"Your region's order".** Departure 2 stands.

## The rehearsal identity

For the controller alone, and only on Matt's word (Before Task 1). `S` is the controller's scratchpad; `ID` stands for the three settings `PRODUCT_BUNDLE_IDENTIFIER=com.matthewfurr.ReadingThroughScripture.rehearsal CLOUDKIT_CONTAINER=iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal PASSAGE_URL_SCHEME=bible-rehearsal`.

- **Build** (the Mac; never while an implementer is building): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath S/new-dd -clonedSourcePackagesDirPath Build/DerivedData/SourcePackages -allowProvisioningUpdates ID build`. The app is `S/new-dd/Build/Products/Debug/ReadingThroughScripture.app`. `Build/DerivedData` is not touched.
- **Check the signature once:** `codesign -d --entitlements - <app>` names the rehearsal container and `Development`; the first launch's `sync` log line reads `store …/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal-Development/…`. A container Xcode has just made is refused for a few minutes (milestone 7's finding F2: CKError 5 on the first launch): wait five minutes and launch again.
- **Not tried before:** a bundle id given on the command line also reaches the package's resource bundles. If the build or the launch fails for that reason, build with `CLOUDKIT_CONTAINER=…rehearsal` alone. The app then keeps the `.dev` bundle id: its notes database is still its own, but it shares the Debug app's preferences and key-value store, so in that form it is used for Task 4 only (the probes write no preference), never for a live pass, and the Mac Debug app is quit while it runs. Record which form was used.
- **Its store folder** is `RD = ~/Library/Application Support/ReadingThroughScripture/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal-Development/`. It is the rehearsal's alone. Nothing else under `~/Library/Application Support/ReadingThroughScripture` is ever touched, and never the folder `…/Sync/iCloud.com.matthewfurr.ReadingThroughScripture-Development/`, which holds Matt's real notes.
- **A live pass:** build as above; `open -n <app> --args -planProbe large` once (an 86-week plan in the identity's own store, this week its week 53, ticks through week 51 and part of 52 and 53), afterwards `open -n <app>`; find its process id and send keys only while it is frontmost and matched by pid (Matt's Debug app has the same name); quit it with `pkill -f "S/new-dd/Build/Products/Debug/ReadingThroughScripture.app"`, never `pkill -x`. In this identity the controller may tick, follow, import, edit and delete freely.
- **The simulator, for the Plan tab:** the same with `-scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath S/new-dd-ios`, then `xcrun simctl install booted S/new-dd-ios/Build/Products/Debug-iphonesimulator/ReadingThroughScripture.app` and `xcrun simctl launch booted com.matthewfurr.ReadingThroughScripture.rehearsal -planProbe large`. It is a second app beside the simulator's Debug app, which is left alone.
- **Clean up** (Task 13): quit it; delete `RD` and `S/new-dd*`; `defaults delete com.matthewfurr.ReadingThroughScripture.rehearsal`; `xcrun simctl uninstall booted com.matthewfurr.ReadingThroughScripture.rehearsal`. The iCloud container and the App ID stay on Matt's account.

## Departures from the spec

1. **Section 7 has the builder confirm with "a stand-in second store".** As the code stands that store is on the `.dev` iCloud database, so the confirmation is made in a rehearsal identity instead, or contained in `.dev` on Matt's word (Before Task 1; Task 4).
2. **Sections 5.1 and 5.2 write dates day first ("Tue 17 Nov", "Tuesday 17 November").** The app writes them as the system does for the reader's region, as every other date in the app is written (`SyncStatusModel`): "Tue, Nov 17" and "Tuesday, November 17" in the US.
3. **Section 5.1 says "meets today" on the day.** The mockup Matt saw kept the date ("meets today, Mon 16 Nov"); so does this.
4. **Section 6.2 gives the title "RTS Gen 1" from the file's name.** No rule gives that from "Gen 1_ RTS Reading Plan.pdf". The title is the file's name without its extension, underscores as spaces and runs of spaces as one: "Gen 1 RTS Reading Plan". It can be edited.
5. **Section 6.2 says "reorder by dragging".** Readings are dragged within their week. Weeks are not dragged: a week's place is its number and its date, and both can be edited.
6. **Section 8 puts the tick circle "in the accent".** The ticked circle (`checkmark.circle.fill`) is in the accent; the empty one (`circle`) is `ink.secondary`, as the mockup drew it grey: an accent ring on every unread reading would be the loudest thing on the front page.
7. **Section 11 says the two real PDFs are read "outside the test suite".** It is a test file that is skipped unless an environment variable names the folder holding the PDFs (Task 5), so the check can be run again and the PDFs are never copied.
8. **The mockup's hairlines between a week's readings in the plan window** are not drawn: `DESIGN.md` separates rows by rhythm. (Its "Your notes this week" line the spec itself drops.)

## Decided here

The spec's **(call)** items stand as written unless a departure names them. Section 10's five items, and what else the spec leaves open:

- **The table reader's thresholds** start from the spike's: a character joins the word before it within 2 pt; words within 2.5 pt of height are one line; a gap of more than 28 pt ends a Gen 1 week; a wrapped fragment joins the nearest reading row within 17 pt. **A header that wraps:** the header is the first line of page 1 holding "Wisdom", with any line within 14 pt of it; without "Wk", "Wisdom", "OT/NT" and two "Chp" the file is not a plan. These read both real files with no warning, so they are the starting values, and Task 5 may move them.
- **The encoded form of a plan's weeks** is JSON with short keys and `"v": 1` (`PlanCoding`, Task 1): small (Gen 2's shape is under 100 KB), readable in a backup, and a later version is recognised. A plan stored by a version this build does not know is listed by its title, shown as unreadable in one line, and never written over.
- **The editor's layout on the iPhone** is the Mac's list in a full sheet, one section per week: one editor to keep right.
- **A week row on the iPhone opens in place,** one at a time, as a book does in the Library. Nothing is pushed, so the Plan tab's left edge always belongs to the edge swipes.
- **How the window and the band hear of a change from the other device:** `AppSync` already reloads every model 300 ms after an import; the plan model joins that list, and is also reloaded when the followed-plan preference arrives and told when the day changes or the app comes forward.
- **A meeting date is a calendar day** (`PlanDay`: year, month, day), not an instant, so two devices in different time zones agree which day a week meets.
- **A week with no date among dated ones** (Gen 2's week 68 until it is set) is passed over when finding this week. The anchor question is asked only of a plan in which no week has a date.
- **Setting a date that was unset moves nothing else;** moving a date moves every later dated week by the same number of days.
- **Which plan is followed:** the plan named by the synced preference `followedPlanID`; if it names none of the kept plans (it has not arrived yet, or that plan was deleted elsewhere), the newest plan, without writing the preference. Choosing a plan in the menu follows it, and so does saving a new one. There is no "none": the band goes when the last plan is deleted.
- **The year a plan starts in** (changed on Matt's answer, 2026-11-19, commit `d49c0ee`): the first year in which every date exists and all fall on one weekday; among several such years, or when none is, the earliest year that puts today inside the plan's span, else the nearest. Gen 2 starts 15 September 2026 and nothing is flagged. `PlanYears.firstYear(for:today:)` is the only place a year is chosen.
- **A passage is written** as the spec and the church's table write it: the book's full name and an en dash ("Psalms 84", "Esther 7–8", "Psalms 119:1–16"). The editor's text uses a hyphen. `Reference.displayString` is not used: it cannot hold a run of chapters and writes "Psalm 84".
- **A reading's label in text** is a trailing "(…)": `John 11-12 (NT Focus Week)`.
- **What blocks Save:** a line that cannot be read and a book the app does not know. A chapter the book lacks, a date that does not exist or is out of order, and a week out of sequence are flagged and do not block: chapter counts are the translation being read's, and another translation may have the chapter.
- **A passage the translation being read lacks** (Tobit in the ESV) is dimmed and says "Not in the ESV." as its help; it is never a button that does nothing.
- **Ticks without a home** (their reading was removed on another device, or their plan deleted) are never counted and never deleted on import: an import can deliver a tick before its plan, and deleting it then would lose a tick.
- **The store's code is `PlanStore`,** a second store on the same container as `ChatStore` is, with its own `delete` and `restore`; `MarkupStore` and `MarkupDeletion` are not widened. The undo is registered by the plan model in the window's `UndoManager`.
- **Delete Plan…** is in the plans menu, under the plans.
- **The reader's toolbar button** is in the toolbar on both screens while a plan is followed and not finished, and dimmed on the front page, where the band is, as Text & Layout is dimmed there.
- **The band is not shown over a Library view:** People, Places and About each have a header of their own, and the band would take the map's height.
- **Pasted text** (6.3) comes in through the system's Paste button in the editor of a new plan; no test reads the real clipboard.
- **⌥⌘P is free.** `~/.config/aerospace/aerospace.toml` binds `alt-` and `alt-shift-` chords only (no `alt-p`, and nothing with `cmd`), and no menu of the app uses it.
- **Change Meeting Date… on the iPhone** in the `ellipsis` menu is this week's; another week's is in that row's context menu.
- **The real PDFs are read by an opt-in test** (Departure 7); **the stand-in plan and the large plan are made by a Debug-only probe** (`-planProbe`, Task 4) that refuses the main store of the `.dev` and the real containers.
- **Model for each task and who must look** are on each task's **Run** line. Opus builds Tasks 3, 5, 7, 8, 9 and 10.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-10-study-tools`, on branch `milestone-10-study-tools`. Never push or merge.
- Git: `/usr/bin/git`, one git command per Bash call, no `cd … &&`, loops or shell variables.
- Every commit message ends with the `Co-Authored-By:` attribution line your own session gives you (the model that wrote the commit), passed as a second `-m`.
- `rtk` shortens command output; use `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time. You do not dispatch subagents.

**Matt's data, and the church's**
- The two PDFs in `~/Downloads` are the church's. They are never committed, never copied into the repository or a report, and never used as a fixture. Tests draw their own PDFs and use made-up plans (`PlanSample`).
- Never touch the Release app, `Scripts/install-app.sh`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. Never build or run the Release configuration.
- **The `.dev` store gets no plan.** No implementer creates, imports, ticks, follows, edits or deletes a plan, or changes any synced setting, in the Mac Debug app, in the simulator's Debug app, or in any `-storeName` store: they are all one iCloud database, shared with the Debug app on Matt's phone, and the simulator's Debug app shares the Debug iCloud key-value store too. In the simulator's Debug app you may switch tabs, scroll and take screenshots; you never open the plan editor there and never tap Import…, New Plan, Save, a tick circle or a plan in the menu. A plan on screen is a render in a test.
- No test touches iCloud, the Keychain, the network, the real clipboard, `UserDefaults.standard` or Matt's stores. A store in a test is in memory or under the temporary directory; preferences in a test are a scratch suite removed when the test ends.
- `Scripts/install-phone.sh debug` and every launch of the Mac app are the controller's, never an implementer's.

**What is stored (spec 7, and nothing beyond it)**
- Two new models in the synced store: `PlanRecord` (`uuid`, `title`, `createdAt`, `modifiedAt`, `weeksData`) and `PlanTick` (`uuid`, `planID`, `readingID`, `tickedAt`). Every attribute is optional or has a default; nothing is unique; neither has a relationship. One new synced preference, `followedPlanID` (the plan's uuid as a string). No other model, attribute or synced key is added, and no stored note, highlight or bookmark changes.
- The store moves forward only. [Corrected 2026-11-19 by the rehearsal: an older build does not refuse a store the new build has used; it opens it and strips the plans and ticks from it (see "Rehearsal results"). The rule: never run an older build on a store the new build has used.]

**Matt is using this Mac (this comes before any step of a task)**
- You never quit, open or relaunch the Mac Debug app, and never send it a keystroke, click or scroll. Never move his windows. AeroSpace owns `alt-tab`, `alt-h/j/k/l`, `alt-1` to `alt-9` and `ctrl-left`/`ctrl-right`.
- Where a step looks at the Mac's UI, render the view offscreen: an `NSHostingView` in a temporary test, written to a PNG in the scratchpad your dispatch names and opened with Read; remove the test before committing. Render the view inside a container taller than it (a render sized to its content cannot show a list that fails to hug its rows), in light, dark and Sepia where the step says.
- Where a step looks at the phone's UI, host the screen in a `TestWindow` (`window.layer.render(in:)`; `drawHierarchy` is blank there and system glass does not draw), on an in-memory store.
- A headless render cannot show focus, the focus ring, a click, a key, a popover's anchor, a toolbar, a file panel, a drag, the tab bar's glass or a swipe. Say in your report what the render could not show. The controller makes one live pass after each UI task.
- If a focus or ring defect survives two blind rounds, stop and report; the controller reads the focus code and looks live before a third. `focusEffectDisabled` on an ancestor switches off every ring inside it. Esc on the front page is a hidden cancel-action button (`LibraryEscapeRule`): a new key handler does not take Esc.

**Commands**
- Package tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (add `--filter <Suite>` for one suite).
- iOS tests: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests` (append `/<Suite>` for one suite).
- Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
- iOS Debug build: the same with `-scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'`.
- Run builds and test runs one after another; they share `Build/DerivedData`.
- Which suite a test file runs in: a file under `#if os(macOS)` runs in the package suite only, one under `#if os(iOS)` in the iOS suite only, any other `T` file in both. `TD` and `TM` files run in the package suite only.
- Timing benchmarks can fail under full-suite load and pass alone; rerun one alone before treating it as yours.

**Code rules**
- A meeting date is a `PlanDay`. Never store, compare or add to an instant to find a week. Every rule that needs today, a calendar or a locale takes it as a value; no test reads the real clock, the current locale or the current time zone.
- Swift Testing: `#expect` cannot contain a mutating call; mutate on the line before. Keep a `ModelContainer` alive for as long as its context is used.
- A static func on a SwiftUI `View` is main-actor isolated; mark a pure helper `nonisolated`. SwiftUI's menus ignore a checkmark in a `Button`'s label; use a `Picker`.
- In a file that imports SwiftUI, `Translation` is written `ScriptureData.Translation`.
- A new `.keyboardShortcut(` must be one `ShortcutCatalogTests` can read and its chord must be in the catalogue; a chord is listed once. No shortcut is added beyond ⌥⌘P.
- Every `NSHostingController(rootView: ….followsSepia())` stays on one line (`SepiaModeTests` reads source lines).
- TextKit 2 only; never touch `textView.layoutManager`.

**UI rules (CLAUDE.md, DESIGN.md)**
- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change; use the `/impeccable-swift` skill for the band, the plan window, the editor and the Plan tab.
- No fixed-point fonts in chrome: semantic text styles only; a size tied to text is `@ScaledMetric`.
- No inline colours: palette tokens only (`Color.inkSecondary`, `Color.accentWash`), never `Color(red:green:blue:)`, `.opacity()` on `.primary`, `.foregroundStyle(.secondary)` or a system colour. A pairing `PaletteTests` does not already hold is added to it. Spacing and radii are `AppSpacing` and `AppRadius` by name.
- No card by reflex: a reading and a week are rows with rhythm; selection is the `accent.wash` tint at radius `md`, never a fill plus a hairline. No stat tiles, no badges, no counts in the Dock, and no colour for a week that was missed (spec 2, anti-goals).
- No new shadow, no new material, no `.glassEffect()`. A popover and a sheet are the system's.
- References are the app's voice: passages, week numbers, dates and counts are SF Pro. Only "This week" and a week's title take the page face, as a Testament's title does (`pageFace.swiftUIFont`).
- The accent marks what can be opened and what is ticked. Red is the system's, for Delete only. Plum is the assistant's and is not used.
- Every control has a label and a help tag; a tick circle's hit area is at least a scaled 24 pt on the Mac and 44 pt on the phone.
- UI copy is as this plan gives it, in the app's American spelling. No exclamation marks, no coaching.
- No motion that does not report a state change; Reduce Motion makes each a cut.

## Review Focus

1. **A passage the translation being read lacks** (a typed plan names Tobit while the ESV is read; a chapter past the book's end). Its button is dimmed and says why; it never does nothing silently, and it never traps. Task 6, `aPassageTheTranslationLacksIsNotOffered`.
2. **A PDF that is not a plan, is long, or has no text** (a 300-page book; a scan). It is refused from its first page with the spec's sentence, within a second, and the window is never frozen while a real plan is read. Task 5, `aLongPDFThatIsNotAPlanIsRefusedFromItsFirstPage`; Task 9, `aFileThatIsNotAPlanSaysSoAndOffersNewPlan`.
3. **A plan stored by a newer build, or one whose stored weeks cannot be read.** It is listed by its title, shown as unreadable, and never written over or dropped. Task 1, `thePlansWeeksRoundTripAndANewerVersionIsNotRead`; Task 3, `aPlanFromANewerVersionIsListedAndNeverWrittenOver`.
4. **Records that arrive out of step:** a tick whose reading was removed elsewhere, a tick before its plan, a followed-plan preference naming a plan that has not arrived or was deleted. Counts never exceed a week's readings, nothing is deleted, the newest plan shows and the preference is not overwritten. Task 1, `countsAreOfThePlansOwnReadings`; Task 6, `thePlanFollowedIsTheStoredOneElseTheNewest`.
5. **The day changing under an open app, and a second device in another time zone.** At midnight after the meeting the band, the button, the window and the tab move to the next week with no relaunch; a week's date is the same day everywhere. Task 6, `thisWeekAndTheButtonFollowTheDay`; Task 1, `aMeetingDateIsACalendarDayInAnyTimeZone`.

---

### Task 1: The plan's values and rules (spec 4, 4.1, 4.2; 10 the encoded form; 11 the model, parsing)

**Run:** Sonnet. No UI. Nobody needs to look.

**Files:**
- Create: `PL/PlanDay.swift`, `PL/ReadingPlan.swift`, `PL/PlanReadingText.swift`, `PL/PlanSchedule.swift`, `PL/PlanCoding.swift`, `PL/PlanSample.swift`
- Test: create `TD/ReadingPlanTests.swift` (package suite)

**Interfaces:**
- Consumes: `ReferenceParser.parse(_:exactBook:)`, `BookCatalog.book(code:)`, `Book.name`, `ChapterLocation`.
- Produces:

```swift
/// A calendar day. A meeting date is never an instant.
public struct PlanDay: Hashable, Comparable, Sendable {
    public let year: Int, month: Int, day: Int
    public init?(year: Int, month: Int, day: Int)                    // nil for a day that does not exist (29 Feb 2027)
    public init(_ date: Date, calendar: Calendar)                    // the day `date` falls on in `calendar`
    public init?(iso: String)                                        // "2026-11-17"
    public var iso: String { get }
    public func adding(days: Int) -> PlanDay
    public func days(until other: PlanDay) -> Int
    public func date(in calendar: Calendar) -> Date                  // that day's start in `calendar`
}
public struct PlanPassage: Hashable, Sendable {
    public let book: String                                          // a `BookCatalog` code
    public let chapter: Int, endChapter: Int                         // equal for one chapter, and for verses of one chapter
    public let verse: Int?, endVerse: Int?                           // verses of `chapter`; nil for whole chapters
    public init(book: String, chapter: Int, endChapter: Int? = nil, verse: Int? = nil, endVerse: Int? = nil)
    public var startLocation: ChapterLocation { get }
    public var displayString: String { get }                         // "Esther 7–8", "Psalms 84", "Psalms 119:1–16"
    public var spokenString: String { get }                          // "Esther 7 to 8", "Psalms 119, verses 1 to 16"
    public var editString: String { get }                            // "Esther 7-8", "Psalms 119:1-16"
}
public struct PlanReading: Identifiable, Hashable, Sendable {
    public let id: UUID                                              // its own identity: a tick follows it
    public var label: String?                                        // "NT Focus", "NT Focus Week", "Holidays"
    public var passages: [PlanPassage]
    public init(id: UUID, label: String?, passages: [PlanPassage])
}
public struct PlanWeek: Hashable, Sendable {
    public var number: Int
    public var day: PlanDay?                                         // the meeting date
    public var label: String?                                        // "Leader Dinner", "OFF"
    public var readings: [PlanReading]
    public init(number: Int, day: PlanDay?, label: String?, readings: [PlanReading])
}
public struct ReadingPlan: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var createdAt: Date, modifiedAt: Date
    public var weeks: [PlanWeek]
    public var isReadable: Bool                                      // false: stored by a version this build cannot read; `weeks` is empty
    public init(id: UUID, title: String, createdAt: Date, modifiedAt: Date, weeks: [PlanWeek], isReadable: Bool = true)
    public var readingIDs: Set<UUID> { get }
    public func progress(ticked: Set<UUID>) -> PlanProgress                       // of every reading
    public func progress(ofWeek index: Int, ticked: Set<UUID>) -> PlanProgress
}
public struct PlanProgress: Equatable, Sendable {
    public let read: Int, total: Int
    public init(read: Int, total: Int)
    public var fraction: Double { get }                              // 0 when total is 0
    public var label: String? { get }                                // "done", "3 of 5", nil with nothing read
}
public enum PlanReadingText {
    public enum Failure: Error, Equatable, Sendable { case empty, unknownBook(String), unreadable(String) }
    public struct Parsed: Equatable, Sendable { public let passages: [PlanPassage]; public let label: String? }
    public static func passage(_ text: String) -> Result<PlanPassage, Failure>
    /// One line of the editor: passages separated by ";", then an optional "(label)".
    public static func parse(_ line: String) -> Result<Parsed, Failure>
    public static func line(for reading: PlanReading) -> String      // "Psalms 84; Esther 7-8", "John 11-12 (NT Focus Week)"
}
public enum PlanSchedule {
    public enum Now: Equatable, Sendable { case week(index: Int), finished, undated }
    public static func now(_ weeks: [PlanWeek], today: PlanDay) -> Now
    public static func settingDay(_ day: PlanDay, ofWeek index: Int, in weeks: [PlanWeek]) -> [PlanWeek]
    public static func anchored(_ weeks: [PlanWeek], week index: Int, on day: PlanDay) -> [PlanWeek]
}
public enum PlanCoding {
    public static let version = 1
    public static func encode(_ weeks: [PlanWeek]) throws -> Data
    public static func decode(_ data: Data) -> [PlanWeek]?           // nil for a newer version or data that cannot be read; [] for empty data
}
/// Made-up plans in the church's shapes, for tests, renders and the Debug probe. No real plan is in the app.
public enum PlanSample {
    public static let standInID: UUID, largeID: UUID, gen1ID: UUID   // 5D000000-0000-4000-8000-000000000001, …0002, …0003
    public static func gen1Shaped() -> ReadingPlan
    public static func gen2Shaped(today: PlanDay, thisWeek: Int = 53) -> ReadingPlan
    public static func standIn(today: PlanDay) -> ReadingPlan
}
```

**The rules.**
- **A passage in text** is a book's name, then a chapter ("84"), a run of chapters ("7-8", the second greater than the first), a verse of one chapter ("3:16") or verses of one chapter ("119:1-16", the second greater). A hyphen, an en dash and an em dash are the same. The name is everything before the last space and is resolved by `ReferenceParser.parse(name, exactBook: true)?.book`: any accepted name or short form, never a guess from a prefix. What follows it is checked first: if it is not one of the four forms the text is `.unreadable(text)`; if it is and the name is no book, `.unknownBook(name)`. A name with no number is unreadable.
- **A line** is passages separated by ";", then optionally a label in parentheses at the end. A blank line is `.empty`. The first passage that fails is the line's failure.
- **Display** uses `Book.name` and an en dash; **spoken** writes "7 to 8" and ", verses 1 to 16"; **edit** uses a hyphen.
- **This week** is the first week with a date that is today or later. With dates and none of them today or later the plan is `.finished`. A week with no date is passed over. With no date on any week it is `.undated`.
- **`settingDay`:** when the week had a date, every later week that has a date moves by the same number of days; when it had none, nothing else moves.
- **`anchored`:** week `index` meets on `day` and every week gets a date seven days from its neighbour, by its place in the list, earlier weeks backwards.
- **Progress** counts only ticks whose reading the plan has. A week's label is "done" when all of its readings are read (and it has one), "3 of 5" when some are, nil when none.
- **The stored form** is JSON with sorted keys: `{"v":1,"weeks":[…]}`; a week is `n` (number), `d` (the day as "2026-11-17", left out when nil), `l` (label, left out when nil) and `r` (readings); a reading is `id` (the uuid's string), `l` (left out when nil) and `p` (passages); a passage is `b`, `c`, `e` (left out when it equals `c`), `v` and `w` (the end verse; both left out when nil). A `v` other than 1 is not read.
- **The samples.** Their dates are `Date(timeIntervalSince1970: 0)` and every reading's id is fixed by its week and row, so two calls are equal. The i-th reading of a plan (from 0) is Psalms `i % 150 + 1` with Genesis `3 * (i % 16) + 1` to `3 * (i % 16) + 3`.
  - `gen1Shaped`: id `gen1ID`, "RTS Gen 1 (sample)", 67 weeks of five, no dates.
  - `gen2Shaped`: id `largeID`, "RTS Gen 2 (sample)", 86 weeks, four readings in weeks 1 to 77 and three in 78 to 86; week `thisWeek` meets on `today` and the rest seven days apart; "Leader Dinner" on weeks 1, 8 and 14, "Meet in Homes" on 5, "OFF" on 10, 11, 15 and 16; every reading of week 55 is labelled "NT Focus" and has its Genesis passage alone.
  - `standIn`: id `standInID`, "Stand-in plan", week 1 the day after `today` ("Psalms 1; Genesis 1-3", "Psalms 2; Genesis 4-6"), week 2 seven days later ("John 1-2 (NT Focus)", "2 John 1; 3 John 1; Jude 1").

- [ ] **Step 1: Write the failing tests** in `TD/ReadingPlanTests.swift`:

```swift
private func day(_ y: Int, _ m: Int, _ d: Int) -> PlanDay { PlanDay(year: y, month: m, day: d)! }
private func passage(_ text: String) -> PlanPassage { try! PlanReadingText.passage(text).get() }
private func weeks(_ days: [PlanDay?]) -> [PlanWeek] {
    days.enumerated().map { PlanWeek(number: $0.offset + 1, day: $0.element, label: nil, readings: []) }
}

@Test func aPassageReadsEachFormTheSpecNames() {
    #expect(passage("Psalms 84") == PlanPassage(book: "PSA", chapter: 84))
    #expect(passage("Esther 7-8") == PlanPassage(book: "EST", chapter: 7, endChapter: 8))
    #expect(passage("psalm 119:1–16") == PlanPassage(book: "PSA", chapter: 119, verse: 1, endVerse: 16))     // any accepted name; an en dash
    #expect(passage("Song 1").book == "SNG" && passage("1 Sam 25-27").book == "1SA" && passage("Jn 3:16").verse == 16)
    #expect(passage("Esther 7-8").displayString == "Esther 7–8" && passage("Ps 84").displayString == "Psalms 84")
    #expect(passage("Psalms 119:1-16").displayString == "Psalms 119:1–16" && passage("Song 1").displayString == "Song of Solomon 1")
    #expect(passage("Esther 7-8").spokenString == "Esther 7 to 8" && passage("Psalms 119:1-16").spokenString == "Psalms 119, verses 1 to 16")
    #expect(passage("Esther 7–8").editString == "Esther 7-8" && passage("Esther 7-8").startLocation == ChapterLocation(book: "EST", chapter: 7))
}

@Test func whatCannotBeReadSaysWhy() {
    #expect(PlanReadingText.passage("Hezekiah 3") == .failure(.unknownBook("Hezekiah")))
    #expect(PlanReadingText.passage("ma 3") == .failure(.unknownBook("ma")))                 // never a guess from a prefix
    for text in ["Esther", "Esther 8-7", "Esther 0", "Esther 7-8:3", "Psalms 119:16-1", "7-8", "Esther seven"] {
        #expect(PlanReadingText.passage(text) == .failure(.unreadable(text)), "\(text)")
    }
    #expect(PlanReadingText.parse("   ") == .failure(.empty))
    #expect(PlanReadingText.parse("Psalms 84; Hezekiah 3") == .failure(.unknownBook("Hezekiah")))
}

@Test func aLineIsAReadingOfOneOrMorePassagesWithItsLabel() throws {
    let two = try PlanReadingText.parse("Psalms 84; Esther 7-8").get()
    #expect(two.passages.map(\.displayString) == ["Psalms 84", "Esther 7–8"] && two.label == nil)
    let focus = try PlanReadingText.parse("John 11-12 (NT Focus Week)").get()
    #expect(focus.passages == [passage("John 11-12")] && focus.label == "NT Focus Week")
    #expect(try PlanReadingText.parse("2 John 1; 3 John 1; Jude 1").get().passages.map(\.book) == ["2JN", "3JN", "JUD"])
    #expect(PlanReadingText.line(for: PlanReading(id: UUID(), label: "Holidays", passages: [passage("Isaiah 7-9")])) == "Isaiah 7-9 (Holidays)")
    #expect(PlanReadingText.line(for: PlanReading(id: UUID(), label: nil, passages: two.passages)) == "Psalms 84; Esther 7-8")
}

@Test func thisWeekIsTheFirstWhoseMeetingIsTodayOrLater() {
    let plan = weeks([day(2026, 11, 10), day(2026, 11, 17), day(2026, 11, 24)])
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 1)) == .week(index: 0))       // before the first week it is week 1
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 11)) == .week(index: 1))
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 17)) == .week(index: 1))      // on the meeting day
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 18)) == .week(index: 2))      // the day after
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 25)) == .finished)
    #expect(PlanSchedule.now(weeks([nil, nil]), today: day(2026, 11, 1)) == .undated)
    #expect(PlanSchedule.now(weeks([day(2026, 11, 10), nil, day(2026, 11, 24)]), today: day(2026, 11, 11)) == .week(index: 2))
}

@Test func movingADateMovesTheLaterWeeksAndAnchoringFillsEveryDate() {
    let plan = weeks([day(2026, 11, 10), day(2026, 11, 17), nil, day(2026, 12, 1)])
    #expect(PlanSchedule.settingDay(day(2026, 11, 24), ofWeek: 1, in: plan).map(\.day) == [day(2026, 11, 10), day(2026, 11, 24), nil, day(2026, 12, 8)])
    #expect(PlanSchedule.settingDay(day(2026, 11, 20), ofWeek: 2, in: plan).map(\.day) == [day(2026, 11, 10), day(2026, 11, 17), day(2026, 11, 20), day(2026, 12, 1)])
    let anchored = PlanSchedule.anchored(PlanSample.gen1Shaped().weeks, week: 62, on: day(2026, 11, 17))   // week 63 meets Tuesday 17 November
    #expect(anchored[62].day == day(2026, 11, 17) && anchored[63].day == day(2026, 11, 24))
    #expect(anchored[0].day == day(2025, 9, 9) && anchored[66].day == day(2026, 12, 15))
    #expect(PlanSchedule.now(anchored, today: day(2026, 11, 17)) == .week(index: 62) && PlanSchedule.now(anchored, today: day(2026, 11, 18)) == .week(index: 63))
}

@Test func aMeetingDateIsACalendarDayInAnyTimeZone() {
    #expect(PlanDay(year: 2027, month: 2, day: 29) == nil && PlanDay(year: 2028, month: 2, day: 29) != nil && PlanDay(year: 2026, month: 13, day: 1) == nil)
    #expect(day(2026, 12, 29).adding(days: 7) == day(2027, 1, 5) && day(2026, 11, 17).days(until: day(2026, 11, 24)) == 7 && day(2026, 11, 17) < day(2026, 11, 18))
    #expect(day(2026, 11, 17).iso == "2026-11-17" && PlanDay(iso: "2026-11-17") == day(2026, 11, 17) && PlanDay(iso: "2027-02-29") == nil)
    var tokyo = Calendar(identifier: .gregorian), chicago = Calendar(identifier: .gregorian)
    tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    chicago.timeZone = TimeZone(identifier: "America/Chicago")!
    let evening = day(2026, 11, 17).date(in: chicago).addingTimeInterval(20 * 3600)       // 8 pm on the 17th in Chicago
    #expect(PlanDay(evening, calendar: chicago) == day(2026, 11, 17) && PlanDay(evening, calendar: tokyo) == day(2026, 11, 18))
}

@Test func countsAreOfThePlansOwnReadings() {
    let plan = PlanSample.gen1Shaped(), first = plan.weeks[0].readings.map(\.id)
    let ticked = Set(first.prefix(3)).union([UUID()])                                      // one tick for a reading the plan does not have
    #expect(plan.progress(ticked: ticked) == PlanProgress(read: 3, total: 335) && plan.progress(ticked: []).fraction == 0)
    #expect(plan.progress(ofWeek: 0, ticked: ticked).label == "3 of 5" && plan.progress(ofWeek: 1, ticked: ticked).label == nil)
    #expect(plan.progress(ofWeek: 0, ticked: Set(first)).label == "done" && plan.readingIDs.count == 335)
}

@Test func theSamplesAreTheChurchsShapes() {
    let one = PlanSample.gen1Shaped(), two = PlanSample.gen2Shaped(today: day(2026, 11, 16))
    #expect(one.weeks.count == 67 && one.weeks.allSatisfy { $0.readings.count == 5 && $0.day == nil } && one == PlanSample.gen1Shaped())
    #expect(two.weeks.count == 86 && two.weeks.prefix(77).allSatisfy { $0.readings.count == 4 } && two.weeks.suffix(9).allSatisfy { $0.readings.count == 3 })
    #expect(two.readingIDs.count == 335 && two.weeks[52].day == day(2026, 11, 16) && two.weeks[53].day == day(2026, 11, 23))
    #expect(two.weeks[0].label == "Leader Dinner" && two.weeks[9].label == "OFF" && two.weeks[1].label == nil)
    #expect(two.weeks[54].readings.allSatisfy { $0.label == "NT Focus" && $0.passages.count == 1 })
    let standIn = PlanSample.standIn(today: day(2026, 11, 16))
    #expect(standIn.id == PlanSample.standInID && standIn.weeks.map(\.day) == [day(2026, 11, 17), day(2026, 11, 24)])
    #expect(standIn.weeks.map(\.readings.count) == [2, 2] && standIn.weeks[1].readings[1].passages.count == 3)
}

@Test func thePlansWeeksRoundTripAndANewerVersionIsNotRead() throws {
    let weeks = PlanSample.gen2Shaped(today: day(2026, 11, 16)).weeks
    let data = try PlanCoding.encode(weeks)
    #expect(PlanCoding.decode(data) == weeks && data.count < 100_000)
    #expect(String(decoding: data.prefix(18), as: UTF8.self) == #"{"v":1,"weeks":[{""#)
    #expect(PlanCoding.decode(Data(#"{"v":2,"weeks":[]}"#.utf8)) == nil && PlanCoding.decode(Data("junk".utf8)) == nil && PlanCoding.decode(Data()) == [])
}
```

- [ ] **Step 2: Run.** `--filter ReadingPlanTests` FAILS to compile (the types do not exist).
- [ ] **Step 3: Build** the six files.
- [ ] **Step 4: Run.** `--filter ReadingPlanTests` passes, then the whole package suite and the iOS suite.
- [ ] **Step 5: Commit.** `feat: a reading plan's weeks, readings and passages, this week, and the stored form (reading plans 4, 4.1)`

---

### Task 2: The draft, the text form, years and the review's flags (spec 4.1 a date that does not exist; 6.1 years; 6.2; 6.3; 11)

**Run:** Sonnet. No UI. Nobody needs to look.

**Files:**
- Create: `PL/PlanDraft.swift`, `PL/PlanText.swift`, `PL/PlanYears.swift`, `PL/PlanReview.swift`
- Test: create `TD/PlanDraftTests.swift` (package suite)

**Interfaces:**
- Consumes (Task 1): `ReadingPlan`, `PlanWeek`, `PlanReading`, `PlanPassage`, `PlanDay`, `PlanReadingText`, `PlanSchedule.settingDay`, `PlanSample`.
- Produces:

```swift
public enum PlanYears {
    public struct MonthDay: Hashable, Sendable { public let month: Int, day: Int; public init(month: Int, day: Int) }
    public struct Placed: Equatable, Sendable {
        public let days: [PlanDay?]                    // nil for no date given, and for a day that does not exist in its year
        public let years: [Int?]                       // the year each given date falls in
    }
    /// "Sept 15", "Sep 15", "Feb 29", "15 Nov": a month by its first three letters and a day that month can have.
    public static func monthDay(_ text: String) -> MonthDay?
    /// Years counted on from `firstYear`, one more each time a date is earlier in the year than the date before it.
    public static func place(_ dates: [MonthDay?], firstYear: Int) -> Placed
    /// The first year that puts `today` inside the plan's span (the earlier, when two do); when none does, the one that brings the span nearest to today.
    public static func firstYear(for dates: [MonthDay?], today: PlanDay) -> Int
}
/// What the review and the editor edit. A reading is its line of text until the plan is saved.
public struct PlanDraft: Equatable, Sendable {
    public struct Reading: Identifiable, Equatable, Sendable { public let id: UUID; public var text: String }
    public struct Week: Identifiable, Equatable, Sendable {
        public let id: UUID                            // the editor's own; not stored
        public var number: Int
        public var day: PlanDay?
        public var label: String                       // "" for none
        public var readings: [Reading]
        public var monthDay: PlanYears.MonthDay?       // the file's own month and day, until the date is set or moved by hand
    }
    public var planID: UUID?                           // nil for a new plan
    public var createdAt: Date?
    public var title: String
    public var weeks: [Week]
    public var firstYear: Int?                         // set when a file gave dates without a year

    public init(title: String)                         // New Plan: week 1, no date, one empty reading
    public init(plan: ReadingPlan)                     // Edit Plan…: every reading keeps its id
    public var canSave: Bool { get }
    public func plan(now: Date) -> ReadingPlan?        // nil unless `canSave`
    public mutating func addWeek()
    public mutating func removeWeek(_ id: UUID)
    public mutating func addReading(toWeek id: UUID)
    public mutating func removeReading(_ id: UUID)
    public mutating func moveReadings(inWeek id: UUID, fromOffsets: IndexSet, toOffset: Int)
    public mutating func setDay(_ day: PlanDay?, ofWeek id: UUID)
    public mutating func setFirstYear(_ year: Int)
    public mutating func append(text: String, today: PlanDay)      // pasted text
}
public enum PlanText {
    /// A text file or pasted text in the editor's own form (spec 6.3).
    public static func draft(from text: String, title: String, today: PlanDay) -> PlanDraft
    public static func text(for plan: ReadingPlan) -> String
}
public struct PlanFlag: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case unknownBook, unreadable, missingChapter, noSuchDate, dateOutOfOrder, numberOutOfSequence }
    public let kind: Kind
    public let weekID: UUID
    public let readingID: UUID?                        // the line it marks, for the three kinds a line can have
    public let sentence: String
    public var id: String { get }
}
public enum PlanReview {
    /// `chapterCounts`: each book's chapters in the translation being read; a book it lacks is not flagged.
    public static func flags(_ draft: PlanDraft, chapterCounts: [String: Int]) -> [PlanFlag]
}
```

**The rules.**
- **Years.** `place` counts on from `firstYear`: a date earlier in the year than the given date before it is in the next year (a date that does not exist still counts as the date before). The plan's span is from its first day that exists to its last. `firstYear(for:today:)` tries each year from five before today's to one after: the earliest whose span holds today; when none does, the one whose span is fewest days from today (the earlier on a tie); with no date at all, today's year. **If Matt answers question 2 with the weekday** (Before Task 1), only this function changes: among the years whose span holds today, the one with no missing date and the most dates seven days after the date before, then the earlier; `yearsAreCountedOnFromTheFirstDate` then expects 2026 for the eleven dates, and Task 5's `gen2IsEightySixWeeksWithFeb29Flagged` a start of 15 September 2026 with nothing flagged.
- **`canSave`:** the title is not blank, there is a week, and every reading line that is not blank reads (`PlanReadingText.parse` succeeds). **`plan(now:)`:** the id is `planID` or a new one; `createdAt` is kept or is `now`; `modifiedAt` is `now`; blank lines are left out; a reading keeps its draft id; a label of "" is nil.
- **`addWeek`:** after the last, numbered one more (1 with none), dated seven days after it when it has a date, with one empty reading. **`addReading`:** one empty line at the week's end.
- **`setDay`:** `PlanSchedule.settingDay`'s rule over the draft's weeks. The week whose date is set and every week that moved with it lose their `monthDay`. Setting nil clears the date and moves nothing.
- **`setFirstYear`:** `firstYear` is set and every week that still has a `monthDay` is placed again by `PlanYears.place` (a day that does not exist becomes nil). Weeks without one stay.
- **The text form.** A line starting "Week" or "Wk" (any case) and a number starts a week; after the number may come a date, then a label. A date is "2026-11-17", taken as written, or a month and day ("Nov 24", "24 Nov"), kept as the week's `monthDay` and placed by `PlanYears` with `firstYear(for:today:)` over the month-and-day dates. A label is whatever follows, less a leading "/", "-" or "·". Every other line that is not blank is a reading of the week above it; lines before any week line are week 1's. `text(for:)` writes `Week 63 2026-11-17 Leader Dinner`, then the week's lines, with one blank line between weeks.
- **`append(text:)`** reads the text as above and adds its weeks after the last; a draft that is one week with one blank line and no date is replaced by them.
- **Flags,** in week order, a week's own before its lines'. The sentences, exactly:
  - a week numbered other than one more than the week before: `Week 14: numbered 14 after 12.`
  - a date not after the dated week before it: `Week 12: its date is not after week 11’s.`
  - a `monthDay` with no day: `Week 68: Feb 29 is not a date in 2027. Set the date, or change the year the plan starts.` (the month as its first three letters, the year from `PlanYears.place`)
  - a line whose book is not known: `Week 12: “Hezekiah 3” names a book Bible Carrel does not know.` (the whole line)
  - a line that cannot be read: `Week 12: “Psalms eighty” cannot be read.`
  - a passage past its book's end: `Week 12: Esther has no chapter 11.` (the last chapter asked for)

- [ ] **Step 1: Write the failing tests** in `TD/PlanDraftTests.swift` (`day` as in Task 1's tests):

```swift
@Test func yearsAreCountedOnFromTheFirstDate() {
    let dates = ["Sept 15", "Dec 29", "Jan 5", "May 25", "Aug 3", "Dec 28", "Jan 4", "Feb 22", "Feb 29", "Mar 7", "Aug 29"].map(PlanYears.monthDay)
    #expect(dates[0] == PlanYears.MonthDay(month: 9, day: 15) && PlanYears.monthDay("Sep 7") == PlanYears.MonthDay(month: 9, day: 7))
    #expect(PlanYears.monthDay("15 Nov") == PlanYears.MonthDay(month: 11, day: 15) && PlanYears.monthDay("Leader Dinner") == nil && PlanYears.monthDay("Feb 30") == nil)
    #expect(PlanYears.firstYear(for: dates, today: day(2026, 11, 16)) == 2025)                  // spec 6.1; 2026 fits too, and the earlier is taken
    let placed = PlanYears.place(dates, firstYear: 2025)
    #expect(placed.days[0] == day(2025, 9, 15) && placed.days[2] == day(2026, 1, 5) && placed.days[4] == day(2026, 8, 3) && placed.days[6] == day(2027, 1, 4))
    #expect(placed.days[8] == nil && placed.years[8] == 2027 && placed.days[9] == day(2027, 3, 7))   // 29 February 2027 does not exist
    #expect(PlanYears.place(dates, firstYear: 2026).days[8] == day(2028, 2, 29))                 // another first year moves the rest
    let short = ["Sept 15", "Sept 22"].map(PlanYears.monthDay)
    #expect(PlanYears.firstYear(for: short, today: day(2026, 11, 16)) == 2026 && PlanYears.firstYear(for: short, today: day(2026, 6, 1)) == 2026)   // none fits: the nearest
    #expect(PlanYears.firstYear(for: short, today: day(2026, 1, 10)) == 2025 && PlanYears.firstYear(for: [nil, nil], today: day(2026, 11, 16)) == 2026)
}

@Test func textIsReadInTheEditorsOwnForm() {
    let text = """
    Week 12 2026-11-17 Leader Dinner
    Psalms 84; Esther 7-8
    John 11-12 (NT Focus)

    wk 13 Nov 24 - OFF
    Psalms 90; Esther 9-10
    Hezekiah 3
    """
    let draft = PlanText.draft(from: text, title: "Typed", today: day(2026, 11, 16))
    #expect(draft.title == "Typed" && draft.planID == nil && draft.weeks.map(\.number) == [12, 13])
    #expect(draft.weeks[0].day == day(2026, 11, 17) && draft.weeks[0].label == "Leader Dinner" && draft.weeks[0].monthDay == nil)
    #expect(draft.weeks[1].day == day(2026, 11, 24) && draft.weeks[1].label == "OFF" && draft.weeks[1].monthDay == PlanYears.MonthDay(month: 11, day: 24))
    #expect(draft.weeks[0].readings.map(\.text) == ["Psalms 84; Esther 7-8", "John 11-12 (NT Focus)"] && draft.weeks[1].readings.count == 2)
    #expect(!draft.canSave)                                                                      // "Hezekiah 3"
    #expect(PlanText.draft(from: "Psalms 1\nPsalms 2", title: "T", today: day(2026, 11, 16)).weeks.map(\.number) == [1])
    let plan = PlanSample.gen2Shaped(today: day(2026, 11, 16))
    let again = PlanText.draft(from: PlanText.text(for: plan), title: plan.title, today: day(2026, 11, 16)).plan(now: plan.modifiedAt)
    #expect(again?.weeks.map(\.number) == plan.weeks.map(\.number) && again?.weeks.map(\.day) == plan.weeks.map(\.day) && again?.weeks.map(\.label) == plan.weeks.map(\.label))
    #expect(again?.weeks.map { $0.readings.map(\.passages) } == plan.weeks.map { $0.readings.map(\.passages) })
    #expect(again?.weeks[54].readings.map(\.label) == plan.weeks[54].readings.map(\.label))
}

@Test func theReviewFlagsEachKindAndSaveIsOffWithAnUnreadableLine() {
    var draft = PlanDraft(title: "Typed")
    #expect(draft.weeks.count == 1 && draft.weeks[0].number == 1 && draft.weeks[0].readings.map(\.text) == [""] && draft.canSave)
    let week = draft.weeks[0].id
    draft.weeks[0].readings[0].text = "Psalms 84; Esther 7-8"
    #expect(draft.canSave && PlanReview.flags(draft, chapterCounts: ["PSA": 150, "EST": 10]).isEmpty)
    for line in ["Hezekiah 3", "Psalms eighty", "Esther 9-11", "Tobit 1"] {
        draft.addReading(toWeek: week)
        draft.weeks[0].readings[draft.weeks[0].readings.count - 1].text = line
    }
    draft.weeks[0].day = day(2026, 11, 17)
    draft.addWeek()
    #expect(draft.weeks[1].number == 2 && draft.weeks[1].day == day(2026, 11, 24) && draft.weeks[1].readings.map(\.text) == [""])
    draft.weeks[1].number = 4
    draft.weeks[1].day = day(2026, 11, 10)
    let flags = PlanReview.flags(draft, chapterCounts: ["PSA": 150, "EST": 10])                  // no count for Tobit: not flagged
    #expect(flags.map(\.kind) == [.unknownBook, .unreadable, .missingChapter, .numberOutOfSequence, .dateOutOfOrder])
    #expect(flags.map(\.sentence) == [
        "Week 1: “Hezekiah 3” names a book Bible Carrel does not know.",
        "Week 1: “Psalms eighty” cannot be read.",
        "Week 1: Esther has no chapter 11.",
        "Week 4: numbered 4 after 1.",
        "Week 4: its date is not after week 1’s.",
    ])
    #expect(flags[0].readingID == draft.weeks[0].readings[1].id && flags[3].readingID == nil && flags[3].weekID == draft.weeks[1].id)
    let saving = Date(timeIntervalSince1970: 10)
    #expect(!draft.canSave && draft.plan(now: saving) == nil)
    draft.removeReading(draft.weeks[0].readings[2].id)
    draft.removeReading(draft.weeks[0].readings[1].id)
    #expect(draft.canSave)                                                                       // a missing chapter and the dates do not block Save
    #expect(draft.plan(now: saving)?.weeks.map(\.readings.count) == [3, 0])                      // the blank line is left out
    draft.title = "  "
    #expect(!draft.canSave)
}

@Test func editingKeepsEachReadingsIdentity() throws {
    let plan = PlanSample.gen1Shaped(), ids = plan.weeks[0].readings.map(\.id)
    var draft = PlanDraft(plan: plan)
    #expect(draft.planID == plan.id && draft.firstYear == nil && draft.weeks[0].readings.map(\.id) == ids)
    draft.moveReadings(inWeek: draft.weeks[0].id, fromOffsets: IndexSet(integer: 0), toOffset: 5)     // the first reading to the end
    draft.weeks[0].readings[4].text = "Psalms 150"                                                  // its passages changed
    draft.weeks[0].number = 9                                                                       // renumbered
    draft.removeReading(ids[2])
    let saved = try #require(draft.plan(now: Date(timeIntervalSince1970: 10)))
    #expect(saved.id == plan.id && saved.createdAt == plan.createdAt && saved.modifiedAt == Date(timeIntervalSince1970: 10))
    #expect(saved.weeks[0].readings.map(\.id) == [ids[1], ids[3], ids[4], ids[0]] && saved.weeks[0].number == 9)
    #expect(saved.weeks[0].readings[3].passages == [PlanPassage(book: "PSA", chapter: 150)])
    #expect(saved.readingIDs.count == 334 && !saved.readingIDs.contains(ids[2]))
}

@Test func aNewFirstYearPlacesTheFilesDatesAgainAndAHandSetDateStays() {
    var draft = PlanText.draft(from: "Week 1 Feb 22\nPsalms 1\nWeek 2 Feb 29\nPsalms 2\nWeek 3 Mar 7\nPsalms 3", title: "T", today: day(2027, 2, 1))
    #expect(draft.firstYear == 2027 && draft.weeks.map(\.day) == [day(2027, 2, 22), nil, day(2027, 3, 7)])
    #expect(PlanReview.flags(draft, chapterCounts: [:]).map(\.sentence) == ["Week 2: Feb 29 is not a date in 2027. Set the date, or change the year the plan starts."])
    draft.setFirstYear(2028)
    #expect(draft.weeks.map(\.day) == [day(2028, 2, 22), day(2028, 2, 29), day(2028, 3, 7)] && PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
    draft.setFirstYear(2027)
    draft.setDay(day(2027, 3, 1), ofWeek: draft.weeks[1].id)                  // it had no date: nothing else moves
    #expect(draft.weeks.map(\.day) == [day(2027, 2, 22), day(2027, 3, 1), day(2027, 3, 7)] && PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
    draft.setDay(day(2027, 3, 8), ofWeek: draft.weeks[1].id)                  // moved: the later week follows
    #expect(draft.weeks[2].day == day(2027, 3, 14))
    draft.setFirstYear(2028)                                                  // weeks set or moved by hand are not placed again
    #expect(draft.weeks.map(\.day) == [day(2028, 2, 22), day(2027, 3, 8), day(2027, 3, 14)])
}

@Test func pastedTextReplacesAnEmptyDraftAndIsAddedToAnyOther() {
    var draft = PlanDraft(title: "New")
    draft.append(text: "Week 5\nPsalms 1\nWeek 6\nPsalms 2", today: day(2026, 11, 16))
    #expect(draft.weeks.map(\.number) == [5, 6] && draft.title == "New")
    draft.append(text: "Psalms 3", today: day(2026, 11, 16))
    #expect(draft.weeks.map(\.number) == [5, 6, 1] && draft.weeks[2].readings.map(\.text) == ["Psalms 3"])
}
```

- [ ] **Step 2: Run.** `--filter PlanDraftTests` FAILS to compile.
- [ ] **Step 3: Build** the four files.
- [ ] **Step 4: Run.** `--filter PlanDraftTests` passes, then both suites.
- [ ] **Step 5: Commit.** `feat: a plan's draft, its text form, years counted on from the first date, and the review's flags (reading plans 6.1-6.3)`

---

### Task 3: The store (spec 4.2 ticks, 6.4, 7; 11 storage)

**Run:** Opus (the synced store's models, the merge after an import, Restore). No UI. Nobody needs to look; Task 4 is the controller's check of what this task cannot test.

**Files:**
- Create: `SM/PlanRecord.swift` (both models), `SM/PlanStore.swift`
- Modify: `SM/MarkupContainer.swift` (`:12`), `SM/SeedMerge.swift` (`mergeAll`, `:129-133`), `SM/StoreCopy.swift` (`RestoreSummary`, `insertMissing`), `SUI/BackupsModel.swift` (`sentence(for:)`, `:76-88`), `SHARED/AppSync.swift` (`:289-292`)
- Test: create `TM/PlanStoreTests.swift`; modify `TM/MarkupContainerTests.swift`, `TM/StoreCopyTests.swift`, `T/BackupsModelTests.swift`

**Interfaces:**
- Consumes (Task 1): `ReadingPlan`, `PlanCoding`, `PlanSample`.
- Produces:

```swift
@Model public final class PlanRecord {
    public var uuid: UUID = UUID()
    public var title: String = ""
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()
    public var weeksData: Data = Data()                              // `PlanCoding`
    public init()
}
@Model public final class PlanTick {
    public var uuid: UUID = UUID()
    public var planID: UUID?
    public var readingID: UUID?
    public var tickedAt: Date = Date()
    public init(planID: UUID, readingID: UUID, tickedAt: Date = Date())
}
// MarkupContainer: `public static let models: [any PersistentModel.Type]` (the seven and these two); `schema` is `Schema(models)`.
public struct TickSnapshot: Equatable, Sendable { public let uuid: UUID, readingID: UUID, tickedAt: Date }
/// A deleted plan with its ticks, kept so the delete can be undone.
public struct PlanDeletion: Equatable, Sendable {
    public let plan: ReadingPlan
    public let ticks: [TickSnapshot]
    public static let actionName = "Delete Plan"
}
public enum PlanStoreError: Error, Equatable { case unreadable }
@MainActor public final class PlanStore {
    public let container: ModelContainer
    public init(container: ModelContainer)
    public func plans() throws -> [ReadingPlan]                      // by `createdAt`, then uuid
    public func plan(id: UUID) throws -> ReadingPlan?
    public func save(_ plan: ReadingPlan) throws
    public func tickedReadingIDs(planID: UUID) throws -> Set<UUID>
    @discardableResult public func toggleTick(planID: UUID, readingID: UUID, now: Date = Date()) throws -> Bool
    @discardableResult public func delete(planID: UUID) throws -> PlanDeletion?
    public func restore(_ deletion: PlanDeletion) throws
}
// SeedMerge
@MainActor @discardableResult public static func mergeDuplicateTicks(in context: ModelContext) throws -> Int
// RestoreSummary gains `plans = 0, ticks = 0`, both in `total`.
```

**The rules.**
- **`plans()`** makes a `ReadingPlan` of each record; a record whose `weeksData` `PlanCoding.decode` cannot read gives one with `isReadable` false and no weeks.
- **`save`** inserts a record for a plan with a new id, or sets `title`, `modifiedAt` and `weeksData` on the stored one (never a second record for one id), then deletes every tick of that plan whose reading the plan no longer has. It throws `.unreadable`, changing nothing, for a plan that is not readable or whose stored record is not.
- **`toggleTick`** returns whether the reading is now ticked. Unticking deletes every tick the reading has in that plan; ticking inserts one. It never makes a second tick for a ticked reading.
- **`delete`** removes the record and every tick of the plan and returns what it removed; nil when the plan is gone. **`restore`** puts the plan back with its id and dates when it is absent, and each tick (by its own uuid) whose reading has no tick; a second call changes nothing.
- **`mergeDuplicateTicks`:** ticks with one `planID` and `readingID` become one; the earliest `tickedAt` survives (ties: the lowest `uuid.uuidString`); a tick with no plan or no reading is left alone; no tick is ever deleted because its plan or its reading is not in the store. It returns the number deleted, saves once when that is above zero, and joins `mergeAll`.
- **`StoreCopy`:** after the bookmarks, a plan whose `uuid` the live store lacks is inserted with every stored field; then a tick whose `uuid` is absent and whose plan and reading have no live tick. Nothing live is changed.
- **`BackupsModel.sentence`** gains `(summary.plans, "reading plan")` and `(summary.ticks, "tick")` after prompts: "Restored 1 reading plan and 2 ticks."
- **`AppSync.initializeSchema`** takes `MarkupContainer.models` in place of its own list.

- [ ] **Step 1: Write the failing tests.** `TM/PlanStoreTests.swift` (`@MainActor @Suite`; `makeStore()` is `PlanStore(container: try MarkupContainer.make(inMemory: true))`; `plan` is `PlanSample.gen1Shaped()`; `count(_:)` is the context's `fetchCount`):

```swift
@Test func aPlanIsOneRecordAndComesBackAsItWas() throws {
    let store = try makeStore()
    try store.save(plan)
    #expect(try store.plans() == [plan] && store.plan(id: plan.id) == plan && store.plan(id: UUID()) == nil)
    var edited = plan
    edited.title = "RTS Gen 1"
    edited.modifiedAt = Date(timeIntervalSince1970: 50)
    try store.save(edited)
    #expect(try store.plans() == [edited] && count(PlanRecord.self, in: store) == 1)             // replaced, never a second record
}

@Test func tickingIsOneRecordAndUntickingRemovesIt() throws {
    let store = try makeStore(), reading = plan.weeks[0].readings[0].id
    try store.save(plan)
    #expect(try store.toggleTick(planID: plan.id, readingID: reading, now: Date(timeIntervalSince1970: 5)))
    #expect(try store.tickedReadingIDs(planID: plan.id) == [reading] && count(PlanTick.self, in: store) == 1)
    #expect(try store.toggleTick(planID: plan.id, readingID: reading) == false)
    #expect(try store.tickedReadingIDs(planID: plan.id).isEmpty && count(PlanTick.self, in: store) == 0)
}

/// Spec 7: two devices ticked one reading before they synced.
@Test func twoTicksForOneReadingMergeToTheEarlier() throws {
    let store = try makeStore(), context = store.container.mainContext
    try store.save(plan)
    let reading = plan.weeks[0].readings[0].id, other = plan.weeks[0].readings[1].id
    let late = PlanTick(planID: plan.id, readingID: reading, tickedAt: Date(timeIntervalSince1970: 200))
    let early = PlanTick(planID: plan.id, readingID: reading, tickedAt: Date(timeIntervalSince1970: 100))
    let stray = PlanTick(planID: UUID(), readingID: UUID(), tickedAt: Date(timeIntervalSince1970: 1))   // its plan has not arrived
    for tick in [late, early, stray, PlanTick(planID: plan.id, readingID: other, tickedAt: Date(timeIntervalSince1970: 300))] { context.insert(tick) }
    try context.save()
    #expect(try SeedMerge.mergeDuplicateTicks(in: context) == 1)
    let left = try context.fetch(FetchDescriptor<PlanTick>())
    #expect(left.count == 3 && left.first { $0.readingID == reading }?.uuid == early.uuid && left.contains { $0.uuid == stray.uuid })
    #expect(try SeedMerge.mergeAll(in: context, seeds: []) == 0)                                 // a second run changes nothing
    #expect(try store.tickedReadingIDs(planID: plan.id) == [reading, other])
}

@Test func savingAnEditDropsOnlyTheTicksOfReadingsRemoved() throws {
    let store = try makeStore(), ids = plan.weeks[0].readings.map(\.id)
    try store.save(plan)
    try store.toggleTick(planID: plan.id, readingID: ids[0])
    try store.toggleTick(planID: plan.id, readingID: ids[1])
    var edited = plan
    edited.weeks[0].readings.remove(at: 1)
    edited.weeks[0].readings.reverse()
    edited.weeks[0].number = 9
    try store.save(edited)
    #expect(try store.tickedReadingIDs(planID: plan.id) == [ids[0]] && count(PlanTick.self, in: store) == 1)
}

@Test func deletingAPlanTakesItsTicksAndRestoreBringsBothBack() throws {
    let store = try makeStore(), ids = plan.weeks[0].readings.map(\.id)
    try store.save(plan)
    try store.toggleTick(planID: plan.id, readingID: ids[0], now: Date(timeIntervalSince1970: 5))
    try store.toggleTick(planID: plan.id, readingID: ids[1], now: Date(timeIntervalSince1970: 6))
    let deletion = try #require(try store.delete(planID: plan.id))
    #expect(try store.plans().isEmpty && count(PlanTick.self, in: store) == 0 && deletion.plan == plan && deletion.ticks.count == 2)
    try store.restore(deletion)
    try store.restore(deletion)                                                                  // again: nothing doubles
    #expect(try store.plans() == [plan] && store.tickedReadingIDs(planID: plan.id) == [ids[0], ids[1]] && count(PlanTick.self, in: store) == 2)
    #expect(try Set(store.container.mainContext.fetch(FetchDescriptor<PlanTick>()).map(\.uuid)) == Set(deletion.ticks.map(\.uuid)))
    #expect(try store.delete(planID: UUID()) == nil)
}

@Test func aPlanFromANewerVersionIsListedAndNeverWrittenOver() throws {
    let store = try makeStore(), context = store.container.mainContext
    let newer = Data(#"{"v":2,"weeks":[]}"#.utf8), record = PlanRecord()
    record.title = "From a newer build"
    record.weeksData = newer
    context.insert(record)
    try context.save()
    let listed = try #require(try store.plans().first)
    #expect(listed.title == "From a newer build" && !listed.isReadable && listed.weeks.isEmpty && listed.id == record.uuid)
    #expect(throws: PlanStoreError.unreadable) { try store.save(listed) }
    #expect(record.weeksData == newer && record.title == "From a newer build")
}
```

  In `TM/MarkupContainerTests.swift`:

```swift
/// Spec 7: every value optional or defaulted, nothing unique, no relationship.
@Test func theNewKindsObeyTheStoresRules() {
    #expect(MarkupContainer.models.count == 9 && MarkupContainer.schema.entities.count == 9)
    let entities = MarkupContainer.schema.entities.filter { ["PlanRecord", "PlanTick"].contains($0.name) }
    #expect(entities.count == 2)
    for entity in entities {
        #expect(entity.uniquenessConstraints.isEmpty && entity.relationships.isEmpty)
        for attribute in entity.attributes {
            #expect(!attribute.isUnique && (attribute.isOptional || attribute.defaultValue != nil), "\(entity.name).\(attribute.name)")
        }
    }
}

/// Spec 7: adding the two kinds is a change the store makes by itself the first time the new build opens it.
@Test func aStoreFromBeforePlansOpensAndKeepsItsMarks() throws {
    let support = FileManager.default.temporaryDirectory.appending(path: "MarkupContainerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: support) }
    let location = StoreLocation.resolve(sync: nil, storeName: "Old", applicationSupport: support)
    try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
    do {
        let seven = Schema([Highlight.self, Note.self, Bookmark.self, HighlightColor.self, ChatThread.self, ChatMessage.self, PromptTemplate.self])
        let old = try ModelContainer(for: seven, configurations: [ModelConfiguration(schema: seven, url: location.storeURL, cloudKitDatabase: .none)])
        old.mainContext.insert(Bookmark(book: "GEN", chapter: 1, verse: 1))
        try old.mainContext.save()
    }
    let container = try MarkupContainer.make(at: location, sync: nil)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()) == 1)
    let store = PlanStore(container: container)
    try store.save(PlanSample.gen1Shaped())
    #expect(try store.plans().count == 1)
}
```

  In `TM/StoreCopyTests.swift`: `makeSource` also saves `PlanSample.gen1Shaped()` through a `PlanStore` and ticks its first two readings. A new test, `aMissingPlanComesBackWithItsTicks`: copying into an empty store gives `summary.plans == 1 && summary.ticks == 2`, the live plan equal to the sample and both readings ticked; a second copy gives `plans == 0 && ticks == 0`; with the plan live and its first reading unticked then ticked again (a new tick with another uuid), a copy gives `ticks == 1` (the second reading's alone, as a bookmark on a bookmarked verse is skipped). Existing assertions that count a summary's total take the three new records. In `T/BackupsModelTests.swift`: a summary of one plan and two ticks reads "Restored 1 reading plan and 2 ticks.".

- [ ] **Step 2: Run.** `--filter PlanStoreTests` FAILS to compile.
- [ ] **Step 3: Build.** If `Schema.Entity` or `Schema.Attribute` name a property otherwise than the rules test writes it, use the SDK's name and say so.
- [ ] **Step 4: Run.** The package suite and the iOS suite pass; both Debug builds succeed (do not launch either app).
- [ ] **Step 5: Name the tables.** With `sqlite3 -readonly` list the tables of a store the on-disk test leaves in the temporary directory (keep it for this step, then remove it) and write the two new tables' names in your report; they are expected to be `ZPLANRECORD` and `ZPLANTICK`, and Task 4 counts them.
- [ ] **Step 6: Commit.** `feat: plans and ticks in the synced store: one record a plan, one a tick, merged, restored and undoable (reading plans 7)`

---

### Task 4: The plan probe and the stand-in rehearsal (spec 7, "an older build on another device")

**Run:** Sonnet writes the probe (Steps 1 to 3). **The controller, not a subagent, runs the rehearsal** (Steps 4 to 13), on Matt's answer to question 1 (Before Task 1), and stops the build if Step 8 fails. No UI.

**Files:**
- Create: `SHARED/PlanProbe.swift` (`#if DEBUG`)
- Modify: `SHARED/AppSync.swift` (`attach`, the `onPrepared` closure, `:109-117`), this plan ("Rehearsal results", by the controller)

**Interfaces:**
- Consumes: `PlanStore` (Task 3); `PlanSample.standIn(today:)`, `gen2Shaped(today:)`, `standInID`, `largeID` (Task 1); `StoreLocation`, `SyncConfiguration`, `MarkupContainer.developmentContainerIdentifier`, `cloudKitContainerIdentifier`.
- Produces:

```swift
#if DEBUG
/// A Debug-only hook: `-planProbe make | large | clear`, run once the coordinator has prepared, on both apps.
enum PlanProbe {
    static let argument = "planProbe"
    @MainActor static func runIfAsked(container: ModelContainer, location: StoreLocation, sync: SyncConfiguration?)
}
#endif
```

- `make` saves `PlanSample.standIn(today:)` (today by `Calendar.current`) and ticks its first two readings, unless a plan with that id is there. `large` saves `PlanSample.gen2Shaped(today:)` retitled "Probe: 86 weeks" and ticks every reading of weeks 1 to 51, three of week 52's and two of week 53's. `clear` deletes the plans with those two ids, with their ticks, and nothing else.
- **It refuses the main store of the two containers Matt reads from:** when `location.storeName == StoreLocation.defaultStoreName` and the container is `MarkupContainer.developmentContainerIdentifier` or `cloudKitContainerIdentifier`, it does nothing but log `plan probe refused: never in the main store`. In a named store, in another container's store and with sync off it runs.
- It never writes a preference. It logs `plan probe done: <form>` to the `sync` category (subsystem `com.matthewfurr.ReadingThroughScripture`), or `plan probe failed: …`.
- In `attach`, `onPrepared` calls it under `#if DEBUG` on both platforms, then `refreshAll()`; the Mac's `SyncProbe` call stays as it is.

- [ ] **Step 1: Write the probe** and the call. There is no unit test: it lives in the app targets, and its samples are pinned by Task 1.
- [ ] **Step 2: Build.** Both Debug builds succeed. Do not launch either app; do not pass the argument to anything.
- [ ] **Step 3: Commit.** `test: a Debug probe that makes and clears a stand-in plan, refused in the main store`

**The rehearsal (the controller).** `S` is the controller's scratchpad. Procedure A is written out; Procedure B's differences follow it. NEW is this branch's code after Step 3; OLD is `f2717f6`. `STORES` is the folder the stores are in (`RD` of "The rehearsal identity" for A). Counting is `sqlite3 -readonly "STORES/<name>.store" "select count(*) from ZPLANRECORD; select count(*) from ZPLANTICK; select count(*) from ZBOOKMARK;"` (the table names from Task 3's report). The log is `log show --last 10m --info --predicate 'subsystem == "com.matthewfurr.ReadingThroughScripture"'`; an export or import has finished when its line reads `ended …, failure none`. Quit an instance by its own path with `pkill -f "<path to its .app>"`.

- [ ] **Step 4: Build NEW** as "The rehearsal identity" says, to `S/new-dd`, and check its signature.
- [ ] **Step 5: Build OLD.** `/usr/bin/git worktree add --detach S/old-src f2717f6`; `mkdir -p S/old-src/Build`; `cp Build/bible.sqlite S/old-src/Build/bible.sqlite` (the same schema 5, so its build does not rebuild the Bible). Then the same build command with `-workspace S/old-src/ReadingThroughScripture.xcworkspace -derivedDataPath S/old-dd`. Launch it once with `--args -storeName Warm`, see `prepared` in the log with no failure (wait and relaunch if the new container is still refused), quit.
- [ ] **Step 6: NEW makes the records.** `open -n S/new-dd/…/ReadingThroughScripture.app --args -storeName PlanNew -planProbe make`. Expected: `plan probe done: make`; an export that ends with no failure; `PlanNew` counts 1, 2, 0. Quit.
- [ ] **Step 7: OLD imports past them, then exports a change of its own.** `open -n S/old-dd/…/ReadingThroughScripture.app --args -storeName PlanOld`. Expected: `prepared`; the process is still running after two minutes; no new report for it in `~/Library/Logs/DiagnosticReports`; `sqlite3 … ".tables"` on `PlanOld.store` has no `ZPLANRECORD`. Save what Core Data said: `log show --last 10m --predicate 'process == "ReadingThroughScripture" AND subsystem == "com.apple.coredata"'`, the lines naming `PlanRecord` or `PlanTick`. Quit. Launch OLD again with `--args -storeName PlanOld -syncProbe bookmark:GEN.1.1`; `probe done`; an export that ends with no failure. Quit.
- [ ] **Step 8: The records are still there.** `open -n S/new-dd/… --args -storeName PlanCheck` (a fresh store). Expected once its imports end: counts 1, 2, 1, and `select ZTITLE, length(ZWEEKSDATA) from ZPLANRECORD` equal to `PlanNew`'s. **That is the confirmation Matt asked for.** If the plan or a tick is missing or changed: **stop the project here** and tell Matt; the storage has to change before anything is built on it.
- [ ] **Step 9: A device that ran the older build, then updates.** `open -n S/new-dd/… --args -storeName PlanOld` (NEW opens OLD's store; it moves forward). Expected within ten minutes: counts 1, 2, 1. Record how long. If they do not come: quit, launch once more, wait ten minutes. If they still do not come, record it as a finding for Matt and the handover ("a device that met plans while on the older build does not get them by updating: update every device before the first plan is made"), and go on.
- [ ] **Step 10: No going back.** `open -n S/old-dd/… --args -storeName PlanNew` (OLD on a store NEW has opened). Expected: the window says the notes could not be opened and the `startup` log has `Startup failed`. Quit. Then NEW on `PlanNew` again: counts still 1, 2 and, once imported, 1. Record what OLD did, whatever it was.
- [ ] **Step 11: Take everything out of iCloud.** NEW with `--args -storeName PlanNew -planProbe clear`, wait for the export, quit; NEW with `--args -storeName PlanOld -syncProbe bookmark:GEN.1.1` (`PlanOld` is the store that made the bookmark, so this toggles it off; its bookmark count is 0 afterwards), wait for the export, quit. Then a fresh store, `--args -storeName PlanGone`: after its imports, counts 0, 0, 0. Quit.
- [ ] **Step 12: Clean up.** In `STORES`, delete `Warm.store*`, `PlanNew.store*`, `PlanOld.store*`, `PlanCheck.store*`, `PlanGone.store*`, their `.…_SUPPORT` and `…_ckAssets` folders and `Backups-Warm`, `Backups-Plan*`; nothing else. `/usr/bin/git worktree remove --force S/old-src`; delete `S/old-dd`. Keep `S/new-dd` for the live passes.
- [ ] **Step 13: Record every result** under "Rehearsal results" at the end of this plan (which procedure, each step's counts and times, Core Data's lines from Step 7, what Steps 9 and 10 showed), and commit: `docs: the stand-in rehearsal recorded: an older build leaves plans and ticks alone`.

**Procedure B (only on Matt's word).** OLD is `S/OldBuild/ReadingThroughScripture.app` (copied before Task 1) and NEW is `Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`; nothing is built and no worktree is made. `STORES` is `…/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development/`, where **`Markup.store`, `Backups/` and everything not named in Step 12 are never touched**. Before Step 6: tell Matt, quit the Mac Debug app (`pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"` after copying is done; it is NEW's own path, so NEW is launched only with `-storeName`), `xcrun simctl terminate booted com.matthewfurr.ReadingThroughScripture.dev`, and ask him to leave the phone's Debug app closed until Step 11's check passes. **NEW is never launched without `-storeName` until Step 11 has shown 0, 0, 0**: that is what keeps the stand-in plan out of the `.dev` store on this Mac. Do Steps 6 to 12 without pause. Then reopen the Debug app and tell Matt it is back. Record in Step 13 that the records were in the `.dev` iCloud database, and from when to when.

---

### Task 5: Reading the PDF's table (spec 6.1; 11 the PDF reader, the two real PDFs)

**Run:** Opus (the table reader). No UI. Nobody needs to look; the controller reads Step 6's figures.

**Files:**
- Create: `PL/PlanTableReader.swift`, `PL/PlanImport.swift`, `UP/PlanFileImport.swift`
- Test: create `TD/PlanTableReaderTests.swift` (package suite), `T/PlanPDFDrawing.swift` and `T/PlanFileImportTests.swift` (both suites), `T/RealPlanPDFTests.swift` (`#if os(macOS)`, skipped unless asked for)

**Interfaces:**
- Consumes: `PlanDraft`, `PlanYears`, `PlanText.draft`, `PlanReview` (Task 2); `PlanReadingText`, `PlanDay` (Task 1).
- Produces:

```swift
// PL
public struct PlanWord: Equatable, Sendable {
    public let text: String
    public let x0: Double, x1: Double, y: Double                     // PDF points; y grows upward
    public init(_ text: String, x0: Double, x1: Double, y: Double)
}
public struct PlanTable: Equatable, Sendable {
    public struct Row: Equatable, Sendable { public var wisdomBook: String, wisdomChapters: String, otherBook: String, otherChapters: String }
    public struct Week: Equatable, Sendable { public var number: Int?; public var dateText: String; public var rows: [Row] }
    public let hasDates: Bool
    public let weeks: [Week]
}
public enum PlanTableReader {
    public enum Failure: Error, Equatable, Sendable { case noText, noHeader }
    public static func hasHeader(_ firstPage: [PlanWord]) -> Bool
    public static func table(pages: [[PlanWord]]) throws(Failure) -> PlanTable
}
public enum PlanImport {
    public static func title(forFileNamed name: String) -> String    // "Gen 1_ RTS Reading Plan.pdf" is "Gen 1 RTS Reading Plan"
    public static func draft(from table: PlanTable, title: String, today: PlanDay) -> PlanDraft
}
// UP (the only file that imports PDFKit)
public enum PlanFileImport {
    public enum Failure: Error, Equatable, Sendable { case notAPlan, unreadableFile }
    public static let notAPlanMessage = "This PDF isn’t laid out like a plan Bible Carrel can read. You can type the plan in instead."
    public static let unreadableMessage = "That file could not be read."
    /// A PDF by its table, any other file as text in the editor's form. Safe off the main actor.
    public nonisolated static func draft(fromFileAt url: URL, today: PlanDay) -> Result<PlanDraft, Failure>
}
```

**The table reader** is the spike's method (`docs/superpowers/specs/2026-11-16-reading-plan-spike/parse.swift`, sections 1 to 5), with its numbers as starting values:
- **Words** (`PlanFileImport`): for each character of `page.string` that is not white space, `page.selection(for: NSRange(location: i, length: 1))?.bounds(for: page)`; a character joins the word before it when its bottom is within 2 pt of the word's, it starts no more than 2 pt after the word ends and not before the word starts.
- **Lines:** words whose `y` differ by under 2.5 pt, left to right; lines top to bottom.
- **The header** is the first line of page 1 holding the word "Wisdom", together with any line within 14 pt of it. It must give "Wk", "Wisdom", "OT/NT" and a "Chp" to the right of each of the last two; "Meeting" makes it a table with dates. Without them, `.noHeader`; with no word on any page, `.noText`. On page 1 nothing at or above the header's line is a row.
- **Columns,** from the header: left of midway between Wk's right edge and Wisdom's left is the week column; a word in the Wisdom columns is a chapter when it is numeric (`^\d+([:\-–,]\d+)*$`) and its centre is right of midway between Wisdom's centre and the first Chp's, else part of the book; the Wisdom columns end midway between the first Chp's centre and OT/NT's left; the OT/NT book ends 8 pt left of the second Chp; in a table with dates, a word starting more than 8 pt right of the second Chp's right edge is the date cell's.
- **A wrapped fragment** is a line with no chapter in either chapter column that is not a date row. It joins the nearest reading row within 17 pt, before that row's text when it is printed above it and after when below; a fragment of one or two lower-case letters joins with no space ("Lamentation" and "s").
- **Weeks:** without dates, a gap of more than 28 pt between lines ends a week, and so does a new page once the week has five rows; with dates, the date row ends the week, and a date row that opens a page belongs to the week before it. The week's number is the whole number in the week column on any of its rows.
- **`PlanFileImport.draft`** reads page 1's words first and returns `.notAPlan` at once when `hasHeader` is false, before any other page is read. A PDF that will not open, and a text file that is not UTF-8, are `.unreadableFile`. It holds the URL's security scope (`startAccessingSecurityScopedResource`) for the read.

**From the table to a draft** (`PlanImport`): the week's number is the table's, or one more than the week before. A row is one reading line:
- its Wisdom cell with a chapter is a passage ("Psalms 84"; "Song 1" reads as it stands); with text and no chapter it is the reading's label; blank, nothing. A week in which exactly one label appears gives it to that week's rows whose Wisdom cell is blank (the merged cell).
- its OT/NT cell is a passage; a book cell with commas is several, each with the row's chapters, and a part that is a number alone takes the next part's name ("2,3 John, Jude" with "1" is `2 John 1; 3 John 1; Jude 1`).
- the line is the Wisdom passage, then the others, joined by "; ", then " (label)"; en dashes become hyphens.
- the date cell is split at its first " / " or " - ": the first part is read by `PlanYears.monthDay` and kept as the week's `monthDay`, the rest is the label; a first part that is no date makes the whole cell the label. Then `firstYear` is `PlanYears.firstYear(for:today:)` and the days are `PlanYears.place`'s. A table without dates leaves `firstYear` nil.

- [ ] **Step 1: Write the failing tests for the reader,** `TD/PlanTableReaderTests.swift`, on words placed by hand at the columns the church's PDFs use:

```swift
/// Column centres in points, measured from the two PDFs. Rows are 18.5 pt apart; in the layout without dates a week's last row and the next week's first are 37 pt apart.
private enum Gen1 { static let wk = 138.0, wisdom = 198.5, wisdomChapters = 272.0, other = 364.5, otherChapters = 460.0, merged = 236.5, top = 640.9 }
private enum Gen2 { static let wk = 83.0, wisdom = 126.5, wisdomChapters = 189.5, other = 258.0, otherChapters = 315.5, date = 338.0, top = 643.6 }
/// A cell's words left to right about `centre`: 5.5 pt a character, 3 pt between words.
private func cell(_ text: String, centre: Double, y: Double) -> [PlanWord]
private func gen1Header() -> [PlanWord]          // y 663.3: Wk 131–145, Wisdom 179–218, Chp 262–282, OT/NT 350–379, Chp 450–469
private func gen2Header() -> [PlanWord]          // y 665.9: Wk 76–91, Wisdom 107–146, Chp 180–199, OT/NT 243–273, Chp 306–325, Meeting 369–407, Date 410–431
private func gen1Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: Double) -> [PlanWord]
private func gen2Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: Double) -> [PlanWord]
private func gen2Date(_ text: String, y: Double) -> [PlanWord]                                   // its first word starts at x 338
/// A Gen 1 week of five from `y` down: "Wk" on its second row and `number` on its third; its rows are Psalms `psalm` to `psalm + 4`, Psalms n beside Genesis `3n - 2` to `3n` ("1-3" for Psalms 1, "16-18" for Psalms 6).
private func gen1Week(_ number: Int, psalm: Int, y: Double) -> [PlanWord]
private let today = PlanDay(year: 2026, month: 11, day: 16)!

@Test func weeksOfFiveReadInOrderAcrossTheGap() throws {
    let table = try PlanTableReader.table(pages: [gen1Header() + gen1Week(1, psalm: 1, y: Gen1.top) + gen1Week(2, psalm: 6, y: Gen1.top - 4 * 18.5 - 37)])
    #expect(!table.hasDates && table.weeks.map(\.number) == [1, 2] && table.weeks.map(\.rows.count) == [5, 5])
    #expect(table.weeks[0].rows[0] == PlanTable.Row(wisdomBook: "Psalms", wisdomChapters: "1", otherBook: "Genesis", otherChapters: "1-3"))
    let draft = PlanImport.draft(from: table, title: "T", today: today)
    #expect(draft.weeks[1].readings[0].text == "Psalms 6; Genesis 16-18" && draft.firstYear == nil && draft.weeks.allSatisfy { $0.day == nil } && draft.canSave)
}

@Test func aWeekRunsAcrossAPageBreak() throws {
    let first = gen1Header() + (0..<4).flatMap { gen1Row(wk: $0 == 1 ? "Wk" : $0 == 2 ? "17" : "", "Psalms", "\(82 + $0)", "Luke", "4-6", y: 132.8 - Double($0) * 18.5) }
    let second = gen1Row("Psalms", "86", "Luke", "16-18", y: 705.5) + gen1Week(18, psalm: 87, y: 668.6)     // the fifth row tops the next page; 37 pt on, week 18
    let table = try PlanTableReader.table(pages: [first, second])
    #expect(table.weeks.map(\.number) == [17, 18] && table.weeks.map(\.rows.count) == [5, 5] && table.weeks[0].rows[4].wisdomChapters == "86")
}

@Test func aMergedLabelIsPrintedOnceAndGivenToItsWeek() throws {
    var words = gen1Header()
    for (index, chapters) in ["11-12", "13-14", "15-16", "17-18", "19-21"].enumerated() {
        words += gen1Row(wk: index == 1 ? "Wk" : index == 2 ? "23" : "", "", "", "John", chapters, y: Gen1.top - Double(index) * 18.5)
    }
    words += cell("NT Focus Week", centre: Gen1.merged, y: Gen1.top - 2 * 18.5)                    // across both Wisdom columns, on the middle row
    let table = try PlanTableReader.table(pages: [words])
    #expect(table.weeks[0].rows.map(\.wisdomBook) == ["", "", "NT Focus Week", "", ""] && table.weeks[0].rows.allSatisfy { $0.wisdomChapters.isEmpty })
    let draft = PlanImport.draft(from: table, title: "T", today: today)
    #expect(draft.weeks[0].number == 23 && draft.weeks[0].readings.map(\.text) == ["John 11-12 (NT Focus Week)", "John 13-14 (NT Focus Week)",
        "John 15-16 (NT Focus Week)", "John 17-18 (NT Focus Week)", "John 19-21 (NT Focus Week)"])
}

@Test func aDateRowEndsAWeekAndWeeksDifferInLength() throws {
    var page = gen2Header(), y = Gen2.top
    func add(_ words: [PlanWord]) { page += words; y -= 18.5 }
    for row in 0..<4 { add(gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "1" : "", "Psalms", "\(row + 1)", "Genesis", "1-3", y: y)) }
    add(gen2Date("Sept 15 / Leader Dinner", y: y))
    for row in 0..<4 { add(gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "2" : "", "Psalms", "\(row + 5)", "Genesis", "4-6", y: y)) }
    add(gen2Date("Nov 17 - OFF", y: y))
    for row in 0..<3 { add(gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "3" : "", "", "", "Revelation", "1-3", y: y)) }
    let second = gen2Date("Feb 29", y: 705.5)                                                     // a date row that opens a page is the week before's
        + (0..<3).flatMap { gen2Row(wk: $0 == 1 ? "Wk" : $0 == 2 ? "4" : "", "NT Focus", "", "Revelation", "4-6", y: 687.0 - Double($0) * 18.5) }
        + gen2Date("Mar 7", y: 687.0 - 3 * 18.5)
    let table = try PlanTableReader.table(pages: [page, second])
    #expect(table.hasDates && table.weeks.map(\.number) == [1, 2, 3, 4] && table.weeks.map(\.rows.count) == [4, 4, 3, 3])
    #expect(table.weeks.map(\.dateText) == ["Sept 15 / Leader Dinner", "Nov 17 - OFF", "Feb 29", "Mar 7"])
    let draft = PlanImport.draft(from: table, title: "T", today: today)
    #expect(draft.firstYear == 2026 && draft.weeks.map(\.label) == ["Leader Dinner", "OFF", "", ""])
    #expect(draft.weeks.map(\.day) == [PlanDay(year: 2026, month: 9, day: 15), PlanDay(year: 2026, month: 11, day: 17), nil, PlanDay(year: 2027, month: 3, day: 7)])
    #expect(draft.weeks[2].readings.map(\.text) == ["Revelation 1-3", "Revelation 1-3", "Revelation 1-3"] && draft.weeks[3].readings[0].text == "Revelation 4-6 (NT Focus)")
    #expect(PlanReview.flags(draft, chapterCounts: [:]).map(\.kind) == [.noSuchDate])
}

@Test func aWrappedNameJoinsItsRowAndTheOddCellsRead() throws {
    // As the PDF prints a wrapped name: its first part on the row's usual line, the row itself 13.2 or 13.3 pt lower, and the row before 18.5 pt above the part.
    let top = Gen2.top
    var page = gen2Header()
    page += cell("Lamentation", centre: Gen2.wisdom, y: top - 18.5) + gen2Row(wk: "Wk", "s", "1", "Ezekiel", "22-24", y: top - 31.7)
    page += cell("1", centre: Gen2.other, y: top - 50.2) + gen2Row(wk: "9", "Job", "2", "Thessalonians", "1-3", y: top - 63.5)
    page += gen2Row("Song", "1", "Amos", "4-6", y: top - 82) + gen2Row("Psalms", "119:1-16", "2,3 John, Jude", "1", y: top - 100.5)
    page += gen2Date("Jan 4", y: top - 119)
    page += gen2Row("Proverbs", "18-19", "Obadiah", "1", y: top - 137.5) + gen2Row("", "", "Philemon", "1", y: top - 156) + gen2Date("Jan 11", y: top - 174.5)
    let draft = PlanImport.draft(from: try PlanTableReader.table(pages: [page]), title: "T", today: today)
    #expect(draft.weeks.map(\.number) == [9, 10])
    #expect(draft.weeks[0].readings.map(\.text) == ["Lamentations 1; Ezekiel 22-24", "Job 2; 1 Thessalonians 1-3", "Song 1; Amos 4-6", "Psalms 119:1-16; 2 John 1; 3 John 1; Jude 1"])
    #expect(draft.weeks[1].readings.map(\.text) == ["Proverbs 18-19; Obadiah 1", "Philemon 1"] && draft.canSave)
    #expect(try PlanReadingText.parse(draft.weeks[0].readings[2].text).get().passages[0].book == "SNG")
}

@Test func aPageWithoutTheHeaderIsNotATable() {
    #expect(throws: PlanTableReader.Failure.noHeader) { try PlanTableReader.table(pages: [gen1Week(1, psalm: 1, y: Gen1.top)]) }
    #expect(throws: PlanTableReader.Failure.noText) { try PlanTableReader.table(pages: [[], []]) }
    #expect(PlanTableReader.hasHeader(gen1Header()) && PlanTableReader.hasHeader(gen2Header()) && !PlanTableReader.hasHeader(cell("Wisdom Literature", centre: 300, y: 700)))
    #expect(PlanImport.title(forFileNamed: "Gen 1_ RTS Reading Plan.pdf") == "Gen 1 RTS Reading Plan" && PlanImport.title(forFileNamed: "plan.txt") == "plan")
}
```

- [ ] **Step 2: Write the failing tests through PDFKit,** `T/PlanFileImportTests.swift`, on PDFs the tests draw. `T/PlanPDFDrawing.swift`:

```swift
/// Draws pages of table cells with Core Graphics and Core Text (Helvetica 11, 612 by 792 pt) into a PDF in the temporary directory. The caller removes it.
enum PlanPDFDrawing {
    struct Cell { let text: String; let centre: CGFloat; let y: CGFloat; var leading = false }     // `leading`: `centre` is the text's left edge (a date)
    static func pdf(named name: String = "Drawn Plan.pdf", pages: [[Cell]]) throws -> URL
    static func gen1Header() -> [Cell]
    static func gen2Header() -> [Cell]
    static func gen1Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: CGFloat) -> [Cell]
    static func gen2Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: CGFloat) -> [Cell]
}
```

  The tests (the same columns and row heights as Step 1's):
  - `aDrawnTableWithoutDatesReadsThroughPDFKit`: the header, a week of five, a 37 pt gap, then a second week whose first four rows end page 1 and whose fifth tops page 2, with "Holidays" drawn once across the Wisdom columns of week 2. `PlanFileImport.draft(fromFileAt:today:)` succeeds with two weeks of five, week 2's five lines ending "(Holidays)", `canSave` true and the title "Drawn Plan".
  - `aDrawnTableWithDatesReadsThemAndFlagsFeb29`: the layout with dates; weeks dated "Feb 22", "Feb 29" and "Mar 7", the second of three rows; a wrapped "Lamentation" over "s". With today 1 February 2027: `firstYear == 2027`, the days are 22 February 2027, nil and 7 March 2027, the one flag's sentence is "Week 2: Feb 29 is not a date in 2027. Set the date, or change the year the plan starts.", and a line reads "Lamentations 1; Ezekiel 22-24".
  - `aPDFWithoutTheHeaderOrWithoutTextIsRefused`: a page of prose, and a page with a filled rectangle and no text, each give `.failure(.notAPlan)`.
  - `aLongPDFThatIsNotAPlanIsRefusedFromItsFirstPage` (Review Focus 2): 300 pages of one line each give `.failure(.notAPlan)` in under a second (`ContinuousClock().measure`).
  - `aTextFileIsReadByTheEditorsForm`: a `.txt` holding "Week 12 2026-11-17\nPsalms 84; Esther 7-8" gives one week numbered 12 on that day, titled by its file's name; a file of the bytes `0xFF 0xFE 0xFD` gives `.failure(.unreadableFile)`; a path with no file gives `.failure(.unreadableFile)`.

- [ ] **Step 3: Write the check against the two real PDFs,** `T/RealPlanPDFTests.swift`, which never runs unless `RTS_PLAN_PDFS` names their folder:

```swift
#if os(macOS)
/// Spec 11: run once by the builder against the church's PDFs. They are never in the repository; this reads them where they are.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RTS_PLAN_PDFS"] != nil)) struct RealPlanPDFTests {
    private let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["RTS_PLAN_PDFS"] ?? "", isDirectory: true)
    private let today = PlanDay(year: 2026, month: 11, day: 16)!

    @Test func gen1IsSixtySevenWeeksOfFive() throws {
        let draft = try PlanFileImport.draft(fromFileAt: folder.appending(path: "Gen 1_ RTS Reading Plan.pdf"), today: today).get()
        #expect(draft.weeks.map(\.number) == Array(1...67) && draft.weeks.allSatisfy { $0.readings.count == 5 && $0.day == nil })
        #expect(draft.canSave && draft.firstYear == nil && PlanReview.flags(draft, chapterCounts: [:]).isEmpty && draft.title == "Gen 1 RTS Reading Plan")
        #expect(draft.weeks[62].readings.map(\.text) == ["Psalms 71; Esther 1-3", "Psalms 73; Esther 4-6", "Psalms 84; Esther 7-8", "Psalms 90; Esther 9-10", "Psalms 92; Ezra 1-3"])
        let lines = draft.weeks.flatMap(\.readings).map(\.text)
        #expect(lines.count { $0.hasSuffix("(Holidays)") } == 15 && lines.count { $0.hasSuffix("(NT Focus Week)") } == 25)
    }

    @Test func gen2IsEightySixWeeksWithFeb29Flagged() throws {
        var draft = try PlanFileImport.draft(fromFileAt: folder.appending(path: "Gen 2_ RTS Reading Plan.pdf"), today: today).get()
        #expect(draft.weeks.map(\.number) == Array(1...86) && draft.weeks.prefix(77).allSatisfy { $0.readings.count == 4 } && draft.weeks.suffix(9).allSatisfy { $0.readings.count == 3 })
        #expect(draft.canSave && draft.firstYear == 2025 && draft.weeks[0].day == PlanDay(year: 2025, month: 9, day: 15) && draft.weeks[67].day == nil)
        #expect(draft.weeks[0].label == "Leader Dinner" && draft.weeks[4].label == "Meet in Homes" && draft.weeks[9].label == "OFF")
        #expect(PlanReview.flags(draft, chapterCounts: [:]).map(\.sentence) == ["Week 68: Feb 29 is not a date in 2027. Set the date, or change the year the plan starts."])
        let lines = draft.weeks.flatMap(\.readings).map(\.text)
        #expect(lines.count == 335 && lines.count { $0.hasSuffix("(NT Focus)") } == 25 && lines.count { !$0.contains(";") && !$0.contains("(") } == 15)
        draft.setFirstYear(2026)
        #expect(draft.weeks[67].day == PlanDay(year: 2028, month: 2, day: 29) && PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
    }
}
#endif
```

- [ ] **Step 4: Run.** `--filter PlanTableReaderTests` and `--filter PlanFileImportTests` FAIL to compile.
- [ ] **Step 5: Build** the three files and the drawing helper. If PDFKit does not give back the words of a PDF the helper drew, fix the drawing (the font, how text is shown), not the reader's thresholds.
- [ ] **Step 6: Run.** Both suites pass (the drawn-PDF tests in the iOS suite too, which is the only proof that PDFKit reads the same on the phone). Then, once: `RTS_PLAN_PDFS="$HOME/Downloads" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter RealPlanPDFTests`. Both tests pass; write in your report the counts and how long each file took. If macOS asks for access to Downloads, answer nothing, copy nothing, and report: the controller runs it. If a threshold had to move to read the real files, say which and why.
- [ ] **Step 7: Commit.** `feat: the church's plan read from its PDF by where each word sits; a text file by the editor's form (reading plans 6.1, 6.3)`

---

### Task 6: The plan model and its wiring (spec 4.1, 4.2, 5.1 the button's rule, 5.4, 5.5 the words, 7 which plan is followed; 10 hearing of a change)

**Run:** Sonnet. No view is built here. Nobody needs to look.

**Files:**
- Create: `UP/ReadingPlanModel.swift`, `UP/PlanWeekText.swift`
- Modify: `SUI/PreferenceSync.swift` (`SyncedPreferences.keys`, `:75-95`, and its doc comment), `SHARED/AppModels.swift`, `SHARED/AppSync.swift` (`Models` `:36-41`, `reloadModels` `:236-245`, `startPreferences` `:175-202`), `MAC/ReadingThroughScriptureApp.swift` (a `plans` state beside `notesBrowser`)
- Test: create `T/ReadingPlanModelTests.swift` (both suites); modify `T/PreferenceSyncTests.swift` (`:14-19`)

**Interfaces:**
- Consumes: `PlanStore`, `PlanDeletion` (Task 3); `ReadingPlan`, `PlanSchedule`, `PlanProgress`, `PlanDay`, `PlanPassage`, `PlanSample` (Task 1); `NavigationModel.open(_:verse:)`, `books`, `translationID`.
- Produces:

```swift
@MainActor @Observable public final class ReadingPlanModel {
    public static let followedPlanKey = "followedPlanID"
    public struct ThisWeek: Equatable, Sendable { public let index: Int; public let week: PlanWeek; public let count: Int }

    public private(set) var plans: [ReadingPlan]
    public private(set) var followed: ReadingPlan?                   // the plan the preference names, else the newest; nil with none
    public private(set) var ticked: Set<UUID>                        // the followed plan's ticked readings
    public private(set) var today: PlanDay
    public private(set) var lastError: String?
    public var undoManager: UndoManager?
    /// After a passage is opened: the main window comes forward on the Mac, the Read tab on the phone.
    public var onOpenPassage: ((PlanPassage) -> Void)?

    public init(store: PlanStore, navigation: NavigationModel, defaults: UserDefaults = .standard,
                calendar: Calendar = .current, now: @escaping () -> Date = Date.init)
    public func reload()                                             // after an import, a preference from another device, or a change made here
    public func refreshToday()                                       // the day changed, or the app came forward
    public var now: PlanSchedule.Now? { get }                        // nil with no plan followed, or an unreadable one
    public var thisWeek: ThisWeek? { get }
    public var showsWeek: Bool { get }                               // followed, dated and not finished: the band and the reader's button
    public var needsAnchor: Bool { get }
    public var isFinished: Bool { get }
    public var progress: PlanProgress { get }
    public func progress(ofWeek index: Int) -> PlanProgress
    public func isTicked(_ reading: PlanReading) -> Bool
    public func toggle(_ reading: PlanReading)
    public func follow(_ planID: UUID)                               // writes the preference
    public func save(_ plan: ReadingPlan)                            // a plan with a new id is followed
    public func setDay(_ day: PlanDay, ofWeek index: Int)            // Change Meeting Date…
    public func anchor(week index: Int, on day: PlanDay)
    public func delete(_ planID: UUID)                               // undoable
    public func canOpen(_ passage: PlanPassage) -> Bool
    public func open(_ passage: PlanPassage)
    public var chapterCounts: [String: Int] { get }                  // the translation being read's, for the review
    public var unavailableHelp: String { get }                       // "Not in the ESV."
    public func clearError()
}
public enum PlanWeekText {
    public static func titleLine(_ week: PlanWeek, count: Int, today: PlanDay, locale: Locale, calendar: Calendar) -> String
    public static func detailLine(_ week: PlanWeek, progress: PlanProgress, locale: Locale, calendar: Calendar) -> String
    public static func sidebarLine(_ week: PlanWeek, progress: PlanProgress, locale: Locale, calendar: Calendar) -> String
    public static func spokenWeek(_ week: PlanWeek, progress: PlanProgress, locale: Locale, calendar: Calendar) -> String
    public static func spoken(_ reading: PlanReading, index: Int, count: Int, isTicked: Bool) -> String
    public static let finishedLine = "You have finished this plan."
    public static let unreadableLine = "This plan was made by a newer version of Bible Carrel."
}
```

**The rules.**
- **Followed:** the plan whose id `defaults` holds under `followedPlanKey`; when that names none of the plans, the one with the latest `createdAt` (ties: the lowest uuid), and the preference is left as it is. `follow` and a `save` of a plan with a new id write the preference.
- **`open`** is the reading move: when `canOpen`, `navigation.open(passage.startLocation, verse: passage.verse)`, then `onOpenPassage`. Otherwise nothing. `canOpen` is true when the translation being read has the passage's book and its first chapter.
- **`toggle`, `save`, `setDay`, `anchor`, `delete`** write through the store and then `reload()`. A failure sets `lastError` to "That change could not be saved. Try it again." and changes nothing shown.
- **`delete`** registers an undo named `PlanDeletion.actionName` that restores, and a redo that deletes again, as `NotesBrowserModel.deleteUndoably` does.
- **`refreshToday`** sets `today` from `now()` and `calendar`. The model also calls it when `.NSCalendarDayChanged` is posted.
- **The words** (dates through `Date.FormatStyle(locale:calendar:timeZone:)` with the calendar's own time zone):
  - `titleLine`: "Week 63 of 67 · meets Tue, Nov 17"; on the day, "Week 63 of 67 · meets today, Tue, Nov 17"; with a label, " · OFF" after it; with no date, "Week 63 of 67". The first number is the week's own number, the second the number of weeks.
  - `detailLine`: "Meets Tuesday, November 17 · 2 of 5 read", then " · Leader Dinner"; with no date, "2 of 5 read".
  - `sidebarLine`: "Nov 17 · done", "Nov 17 · 3 of 5", "Nov 17"; with no date, "3 of 5" or "".
  - `spokenWeek`: "Week 63, Tuesday, November 17, 3 of 5 read".
  - `spoken(reading)`: "Reading 3 of 5, Psalms 84, Esther 7 to 8, not read"; "read" when ticked; a label after the passages ("Reading 1 of 5, John 11 to 12, NT Focus Week, not read").
- **Wiring:** `AppModels` makes `ReadingPlanModel(store: PlanStore(container: container), navigation: navigation)` and holds it as `plans`; `AppSync.Models` gains `plans`, `reloadModels()` reloads it, the non-position branch of `onExternalChange` reloads it, and the existing did-become-active observer calls `refreshToday()`. `SyncedPreferences.keys` gains `ReadingPlanModel.followedPlanKey` (twenty keys).

- [ ] **Step 1: Write the failing tests** in `T/ReadingPlanModelTests.swift`. The suite is `@MainActor @Suite final class` with scratch defaults as `NavigationModelTests` makes and removes them; `navigation` reads `FixtureStore.make()` in WEB (books PSA, MAT, TOB); the calendar is Gregorian in UTC; `clock` is a box whose date the test sets; `make()` returns the model, its store, the navigation model with its `ReadingPositionStore`, and the defaults. `day` as in Task 1's tests. `small` is a plan of three weeks dated 10, 17 and 24 November 2026, each with the readings "Psalms 2:1-6; Matthew 5-6" and "Genesis 1" (ids fixed), `createdAt` 1.

```swift
@Test func thePlanFollowedIsTheStoredOneElseTheNewest() throws {
    let (model, store, _, _, defaults) = try make(today: day(2026, 11, 16))
    #expect(model.followed == nil && !model.showsWeek && model.now == nil && model.progress == PlanProgress(read: 0, total: 0))
    var older = PlanSample.gen1Shaped()
    older.createdAt = Date(timeIntervalSince1970: 0)
    try store.save(older)
    try store.save(small)
    model.reload()
    #expect(model.plans.count == 2 && model.followed?.id == small.id && defaults.string(forKey: "followedPlanID") == nil)   // the newest, and nothing written
    model.follow(older.id)
    #expect(model.followed?.id == older.id && defaults.string(forKey: "followedPlanID") == older.id.uuidString)
    let missing = UUID().uuidString
    defaults.set(missing, forKey: "followedPlanID")                                              // a plan that has not arrived, or was deleted elsewhere
    model.reload()
    #expect(model.followed?.id == small.id && defaults.string(forKey: "followedPlanID") == missing)
}

@Test func thisWeekAndTheButtonFollowTheDay() throws {
    let (model, _, _, _, _) = try make(today: day(2026, 11, 16))
    model.save(small)
    #expect(model.followed?.id == small.id && model.thisWeek?.index == 1 && model.thisWeek?.count == 3 && model.showsWeek && !model.needsAnchor && !model.isFinished)
    clock.date = day(2026, 11, 18).date(in: calendar)                                            // the day after the meeting, with no relaunch
    model.refreshToday()
    #expect(model.thisWeek?.index == 2 && model.today == day(2026, 11, 18))
    clock.date = day(2026, 11, 25).date(in: calendar)
    model.refreshToday()
    #expect(model.isFinished && !model.showsWeek && model.thisWeek == nil)
    model.save(PlanSample.gen1Shaped())                                                          // a plan with no dates, now followed
    #expect(model.followed?.id == PlanSample.gen1ID && model.needsAnchor && !model.showsWeek)
    model.anchor(week: 62, on: day(2026, 11, 26))
    #expect(!model.needsAnchor && model.showsWeek && model.thisWeek?.week.number == 63 && model.thisWeek?.count == 67)
    model.setDay(day(2026, 12, 10), ofWeek: 62)                                                  // a break: later weeks follow
    #expect(model.followed?.weeks[63].day == day(2026, 12, 17) && model.followed?.weeks[61].day == day(2026, 11, 19))
}

@Test func tickingCountsAndSurvivesAReload() throws {
    let (model, store, navigation, _, defaults) = try make(today: day(2026, 11, 16))
    model.save(small)
    let reading = small.weeks[1].readings[0]
    model.toggle(reading)
    #expect(model.isTicked(reading) && model.progress(ofWeek: 1).label == "1 of 2" && model.progress == PlanProgress(read: 1, total: 6))
    let other = ReadingPlanModel(store: store, navigation: navigation, defaults: defaults, calendar: calendar, now: { self.clock.date })
    #expect(other.isTicked(reading))                                                             // what another device ticked, once imported and reloaded
    other.toggle(reading)
    model.reload()
    #expect(!model.isTicked(reading) && model.progress(ofWeek: 1).label == nil)
}

/// Spec 5.4 and 11: opening a passage is reading, not a lookup.
@Test func openingAPassageIsAReadingMoveNotALookup() throws {
    let (model, _, navigation, positions, _) = try make(today: day(2026, 11, 16))
    var opened: [PlanPassage] = []
    model.onOpenPassage = { opened.append($0) }
    navigation.open(ChapterLocation(book: "MAT", chapter: 1))
    navigation.lookUp(ChapterLocation(book: "PSA", chapter: 1), verse: 2)
    #expect(navigation.isLookingUp)
    let psalm = PlanPassage(book: "PSA", chapter: 2, verse: 1, endVerse: 6)
    model.open(psalm)
    #expect(!navigation.isLookingUp && navigation.location == ChapterLocation(book: "PSA", chapter: 2) && navigation.scrollTarget?.verse == 1)
    #expect(positions.load()?.chapterLocation == ChapterLocation(book: "PSA", chapter: 2) && opened == [psalm])
    model.open(PlanPassage(book: "MAT", chapter: 5, endChapter: 6))
    #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 5) && navigation.screen == .reader)
}

/// Review Focus 1.
@Test func aPassageTheTranslationLacksIsNotOffered() throws {
    let (model, _, navigation, _, _) = try make(today: day(2026, 11, 16))
    var opened = 0
    model.onOpenPassage = { _ in opened += 1 }
    navigation.open(ChapterLocation(book: "MAT", chapter: 1))
    let genesis = PlanPassage(book: "GEN", chapter: 1), past = PlanPassage(book: "MAT", chapter: 28)
    #expect(!model.canOpen(genesis) && !model.canOpen(past) && model.canOpen(PlanPassage(book: "MAT", chapter: 5, endChapter: 28)))
    model.open(genesis)
    model.open(past)
    #expect(opened == 0 && navigation.location == ChapterLocation(book: "MAT", chapter: 1) && model.unavailableHelp == "Not in the WEB.")
    #expect(model.chapterCounts["MAT"] == navigation.chapterCount(ofBook: "MAT") && model.chapterCounts["GEN"] == nil)
}

@Test func deletingAPlanIsUndoable() throws {
    let (model, store, _, _, _) = try make(today: day(2026, 11, 16))
    let undo = UndoManager()
    model.undoManager = undo
    model.save(small)
    model.toggle(small.weeks[0].readings[0])
    model.delete(small.id)
    #expect(model.plans.isEmpty && model.followed == nil && undo.undoActionName == "Delete Plan")
    undo.undo()
    #expect(model.followed?.id == small.id && model.isTicked(small.weeks[0].readings[0]))
    undo.redo()
    #expect(try store.plans().isEmpty && model.plans.isEmpty)
}

@Test func theLinesReadAsTheBandAndTheWindowShowThem() {
    let us = Locale(identifier: "en_US")
    let week = PlanWeek(number: 63, day: day(2026, 11, 17), label: nil, readings: small.weeks[0].readings)
    #expect(PlanWeekText.titleLine(week, count: 67, today: day(2026, 11, 16), locale: us, calendar: calendar) == "Week 63 of 67 · meets Tue, Nov 17")
    #expect(PlanWeekText.titleLine(week, count: 67, today: day(2026, 11, 17), locale: us, calendar: calendar) == "Week 63 of 67 · meets today, Tue, Nov 17")
    var off = week
    off.label = "OFF"
    #expect(PlanWeekText.titleLine(off, count: 86, today: day(2026, 11, 16), locale: us, calendar: calendar) == "Week 63 of 86 · meets Tue, Nov 17 · OFF")
    #expect(PlanWeekText.detailLine(off, progress: PlanProgress(read: 2, total: 5), locale: us, calendar: calendar) == "Meets Tuesday, November 17 · 2 of 5 read · OFF")
    #expect(PlanWeekText.sidebarLine(week, progress: PlanProgress(read: 5, total: 5), locale: us, calendar: calendar) == "Nov 17 · done")
    #expect(PlanWeekText.sidebarLine(week, progress: PlanProgress(read: 3, total: 5), locale: us, calendar: calendar) == "Nov 17 · 3 of 5")
    #expect(PlanWeekText.sidebarLine(week, progress: PlanProgress(read: 0, total: 5), locale: us, calendar: calendar) == "Nov 17")
    #expect(PlanWeekText.spokenWeek(week, progress: PlanProgress(read: 3, total: 5), locale: us, calendar: calendar) == "Week 63, Tuesday, November 17, 3 of 5 read")
    var undated = week
    undated.day = nil
    #expect(PlanWeekText.titleLine(undated, count: 67, today: day(2026, 11, 16), locale: us, calendar: calendar) == "Week 63 of 67")
    #expect(PlanWeekText.sidebarLine(undated, progress: PlanProgress(read: 0, total: 5), locale: us, calendar: calendar) == "")
    let esther = PlanReading(id: UUID(), label: nil, passages: [PlanPassage(book: "PSA", chapter: 84), PlanPassage(book: "EST", chapter: 7, endChapter: 8)])
    #expect(PlanWeekText.spoken(esther, index: 2, count: 5, isTicked: false) == "Reading 3 of 5, Psalms 84, Esther 7 to 8, not read")
    let focus = PlanReading(id: UUID(), label: "NT Focus Week", passages: [PlanPassage(book: "JHN", chapter: 11, endChapter: 12)])
    #expect(PlanWeekText.spoken(focus, index: 0, count: 5, isTicked: true) == "Reading 1 of 5, John 11 to 12, NT Focus Week, read")
}
```

  In `T/PreferenceSyncTests.swift`, `theSyncedKeysAreExactlyThese` gains `"followedPlanID"` (twenty keys).

- [ ] **Step 2: Run.** `--filter ReadingPlanModelTests` FAILS to compile.
- [ ] **Step 3: Build** the model, the words and the wiring.
- [ ] **Step 4: Run.** Both suites pass; both Debug builds succeed (do not launch either app).
- [ ] **Step 5: Commit.** `feat: the plan model: which plan is followed, this week, ticks, a passage opened as reading; reloaded with every import (reading plans 4.1, 4.2, 5.4)`

---

### Task 7: The Mac's plan window (spec 5.2, 5.4, 5.5, 6.4, 4.1 the anchor and a changed date; the ⌘K command and ⌥⌘P)

**Run:** Opus (a list that holds the keyboard, a new window, undo). Headless renders, which cannot show: the sidebar taking the keyboard as the window opens; ↑ and ↓; Tab into the readings; Space or a click on a circle; a click on a passage bringing the main window forward; ⌥⌘P from each window; "Reading Plan" in ⌘K; the menu's checkmark; Delete Plan… and ⌘Z; the date popover. One live pass by the controller afterwards, in the rehearsal identity, keys only (the largest plan, `-planProbe large`): ⌥⌘P, the arrows, Tab, Space on a circle, Return on a passage, ⌘K "reading", Delete Plan… then ⌘Z.

**Files:**
- Create: `UP/PlanReadingViews.swift`, `UP/PlanWindowState.swift`, `UP/PlanWindowView.swift`, `UP/PlanDateViews.swift`
- Modify: `SUI/PaletteItem.swift` (`PaletteCommand`: the case, `all`, and each switch), `SUI/ShortcutCatalog.swift` (the View group), `MAC/ReadingThroughScriptureApp.swift` (the window, the View menu's item, `performCommand`, `plans.onOpenPassage`)
- Test: create `T/PlanWindowStateTests.swift` (both suites), `T/PlanBenchmarkTests.swift` (`#if os(macOS)` for this task's test); modify `T/PaletteCommandTests.swift` (`:15`), `T/NavigationModelTests.swift` (`:1949`)

**Interfaces:**
- Consumes: `ReadingPlanModel`, `PlanWeekText` (Task 6); `PlanSample` (Task 1); `Color` tokens, `AppSpacing`, `AppRadius`, `pageFace.swiftUIFont(_:)`.
- Produces:

```swift
public struct PlanWindowState: Equatable, Sendable {
    public private(set) var chosenWeek: Int?                         // an index into the followed plan's weeks
    public init()
    /// This week; the last week of a finished plan; the first of a plan with no dates; nil with no plan or an unreadable one.
    public mutating func open(on plan: ReadingPlan?, now: PlanSchedule.Now?)
    public mutating func choose(_ index: Int)
    public mutating func move(by step: Int, count: Int)              // held at both ends
}
/// The circle that ticks a reading: `circle` in `ink.secondary`, `checkmark.circle.fill` in the accent.
public struct TickCircle: View { public init(isTicked: Bool, hitSize: CGFloat, action: @escaping () -> Void) }
/// One reading: its circle, its passages as buttons (one to a line, or on one line joined by " · "), its label quietly after them.
public struct PlanReadingRow: View {
    public enum Layout: Sendable { case stacked, inline }
    public init(reading: PlanReading, index: Int, count: Int, layout: Layout, hitSize: CGFloat, model: ReadingPlanModel)
}
/// The plan's progress: 2 pt of the accent over an `ink.rule` track of the same height. It never animates.
public struct PlanProgressLine: View { public init(progress: PlanProgress) }
public struct PlanWindowView: View { public init(model: ReadingPlanModel) }
public struct ChangeMeetingDateView: View {
    public init(week: PlanWeek, calendar: Calendar, onChange: @escaping (PlanDay) -> Void, onCancel: @escaping () -> Void)
}
public struct PlanAnchorView: View { public init(weeks: [PlanWeek], calendar: Calendar, onSet: @escaping (_ week: Int, _ day: PlanDay) -> Void) }
// PaletteCommand gains `.readingPlan` after `.notesBrowser`: id "readingPlan", title "Reading Plan", symbol "calendar", shortcut ("readingPlan", 0), always available.
// ShortcutCatalog's View group gains, after "notesBrowser": Shortcut("readingPlan", "Reading plan", keys: ["⌥", "⌘", "P"], spoken: "Option Command P", chords: ["⌥⌘P"])
// ReadingThroughScriptureApp: `static let planWindowID = "reading-plan"`.
```

**The window.** `Window("Reading Plan", id: Self.planWindowID)` after the Notes window, default size 780 by 560, its root `PlanWindowView(model: plans).followsSepia().followsPageFace()`. The View menu gains `Button("Reading Plan") { openWindow(id: Self.planWindowID) }.keyboardShortcut("p", modifiers: [.command, .option])` after Notes Browser; `performCommand` opens the same window for `.readingPlan`; `plans.onOpenPassage` is `showMainWindow()`.

**The view.**
- Minimum 560 by 360; `.navigationSubtitle` is the followed plan's title; the model's `undoManager` is the window's; it reloads as it appears and when the window becomes key (as `NotesBrowserView.swift:67-73`); `lastError` shows in an alert, "Could not save".
- **Sidebar** on `paper.panel`, a scaled 230 pt (`@ScaledMetric(relativeTo: .body)`), with a `Divider` after it: the weeks in a lazy stack in a scroll view, one row each, `xs` of padding all round, `xxs` apart: "Week 63" in `.callout` `ink.primary`, and trailing `PlanWeekText.sidebarLine` in `.caption` `ink.secondary` with monospaced digits. The chosen week is on `accent.wash` at radius `md`. A week that is past with nothing ticked looks like any other. The list is one focus stop with its focus effect off, as the Notes browser's is (`NotesBrowserView.swift:138-167`): ↑ and ↓ move the chosen week, a click chooses, and it scrolls the chosen week into view (a cut under Reduce Motion). It opens on `PlanWindowState.open`'s week and takes the keyboard as it appears. VoiceOver: a row is a button reading `spokenWeek`, with the selected trait.
- **Detail** on `paper.page`, `lg` of padding, scrolling: "Week 63" in `pageFace.swiftUIFont(.title2)` `ink.primary` (the header trait); under it `detailLine` in `.callout` `ink.secondary`; then the readings as `PlanReadingRow(layout: .inline)`, `sm` of padding above and below each, no rule between them. Above the title, in `.callout` `ink.secondary`: `finishedLine` for a finished plan.
- **A reading row:** the circle, then the passages. A passage is a plain button in `.callout`, the accent; `ink.tertiary` when its reading is ticked (it still opens) or when it cannot be opened (disabled, its help `unavailableHelp`). Inline, passages are joined by " · " in `ink.tertiary`. The label follows in `.caption` `ink.secondary`. The circle's symbol is at `.title3`'s size, its hit area `hitSize` square, its help "Mark as read" or "Mark as not read". VoiceOver: the row is one element, a button labelled `PlanWeekText.spoken`, whose action ticks it, with one action per passage that can be opened, named "Open Psalms 84".
- **No dates yet** (`needsAnchor`): in the detail, above the readings, `PlanAnchorView`: "Which week is your group on?" with a pop-up of the weeks ("Week 1" to the last), "When does it next meet?" with a date picker (today), and **Set Dates** (`.borderedProminent`). It calls `model.anchor`, and the window then chooses this week.
- **Toolbar:** a menu labelled with the followed plan's title holding a `Picker` of the plans (inline; choosing one follows it) and, under a divider, **Delete Plan…** (destructive); and **Change Meeting Date…** (`calendar`), on the chosen week, which shows `ChangeMeetingDateView` in a popover: "Week 63 meets" with a date picker, "Later weeks move by the same number of days." in `.caption` `ink.secondary`, Cancel (`.cancelAction`) and Change (`.defaultAction`). It is dimmed with no week chosen.
- **Delete Plan…** asks in a `confirmationDialog`: "Delete “RTS Gen 1”?", "The plan and what you have ticked in it will be deleted. Edit › Undo brings it back.", **Delete** (destructive). Then `model.delete`.
- **With no plan:** `ContentUnavailableView("No reading plan", systemImage: "calendar", description: Text("Import your group's plan, or type one in."))`, in `ink.secondary`, with no sidebar. (Task 9 adds its two buttons and the toolbar's Import…, New Plan and Edit Plan….) **An unreadable plan:** the detail is `unreadableLine` alone, and the menu still offers the plans and Delete Plan….

- [ ] **Step 1: Write the failing tests.** `T/PlanWindowStateTests.swift`:

```swift
@Test func theWindowOpensOnThisWeek() {
    let today = PlanDay(year: 2026, month: 11, day: 16)!
    let plan = PlanSample.gen2Shaped(today: today)
    var state = PlanWindowState()
    state.open(on: plan, now: PlanSchedule.now(plan.weeks, today: today))
    #expect(state.chosenWeek == 52)
    state.move(by: 1, count: 86)
    state.move(by: -3, count: 86)
    #expect(state.chosenWeek == 50)
    state.choose(85)
    state.move(by: 1, count: 86)
    #expect(state.chosenWeek == 85)                                                              // held at the end
    state.open(on: plan, now: .finished)
    #expect(state.chosenWeek == 85)
    state.open(on: PlanSample.gen1Shaped(), now: .undated)
    #expect(state.chosenWeek == 0)
    state.open(on: nil, now: nil)
    #expect(state.chosenWeek == nil)
    var unreadable = plan
    unreadable.isReadable = false
    unreadable.weeks = []
    state.open(on: unreadable, now: nil)
    #expect(state.chosenWeek == nil)
}
```

  In `T/PaletteCommandTests.swift` the count is 33, and: `#expect(PaletteCommand.readingPlan.title == "Reading Plan" && PaletteCommand.readingPlan.symbolName == "calendar" && PaletteCommand.readingPlan.keycaps == ["⌥", "⌘", "P"] && PaletteCommand.readingPlan.isAvailable(in: PaletteState()))`. `NavigationModelTests:1949` expects 33. `ShortcutCatalogTests.everyMenuShortcutInTheMacAppIsListed` already fails on a menu chord the catalogue lacks.
  In `T/PlanBenchmarkTests.swift` (`#if os(macOS)`, `@MainActor @Suite(.serialized)`; the model on an in-memory store holding `PlanSample.gen2Shaped(today:)` with week 53 this week and 200 readings ticked, the navigation model on `FixtureStore`, an `NSWindow` that is never shown):

```swift
/// The largest plan the church has: 86 weeks in the sidebar.
@Test func thePlanWindowOpensOnEightySixWeeks() {
    let median = ReaderBenchmarkTests.median("plan-window-open") {
        let host = NSHostingView(rootView: PlanWindowView(model: model).frame(width: 780, height: 560))
        host.frame = NSRect(x: 0, y: 0, width: 780, height: 560)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
    }
    #expect(median < .milliseconds(150))
}
```

- [ ] **Step 2: Run.** `--filter PlanWindowStateTests` FAILS to compile; `--filter PaletteCommandTests` fails on the count.
- [ ] **Step 3: Build** the views, the window, the command and the catalogue's row.
- [ ] **Step 4: Run.** Both suites pass; the benchmark's median is under 150 ms run alone (if it is not, make the sidebar cheaper; do not raise the bound); both Debug builds succeed (do not launch either app).
- [ ] **Step 5: See it.** Render `PlanWindowView` at 780 by 560 inside a container 800 pt tall, each in light, dark and Sepia: the 86-week sample on week 53 with weeks before it done, one "3 of 4" and two ticked this week; the 67-week sample anchored so week 63 is this week, with a ticked reading; a week with a label, and week 55 (the "NT Focus" label after one passage); the 67-week sample with no dates (the anchor form); a finished plan; no plan; an unreadable plan; a passage the translation lacks; and the first at the largest standard text size and one accessibility size. Render `ChangeMeetingDateView` alone. Open every picture: the sidebar's rows hug, the chosen week is in view and on the wash, no date or count is clipped, nothing is boxed, a ticked reading's passages are tertiary. Say what could not be seen.
- [ ] **Step 6: Commit.** `feat: the plan window: every week down the side, the chosen week's readings, the plans menu, a changed date and an undoable delete (reading plans 5.2, 6.4)`

---

### Task 8: The Mac's band and the reader's button (spec 5.1, 5.4)

**Run:** Opus (the front page's keyboard order). Headless renders, which cannot show: Tab's order with the band present; the contents still taking the keyboard as the page opens and after ⇧⌘H; Space or a click on a circle; a click on a passage; "The whole plan" opening the window; the toolbar button, its popover's place, and the popover closing on a passage or Esc. One live pass by the controller afterwards, in the rehearsal identity, keys only: ⇧⌘H, Tab and Shift-Tab through the band, the contents and the pane, Space on a circle, Return on a passage, then in the reader the button by its help tag (the controller asks Matt to click it if no key reaches it).

**Files:**
- Create: `UP/PlanWeekSummary.swift`
- Modify: `SUI/FrontPageView.swift` (`init` `:29-36`, `left` `:110-130`), `MAC/MainWindowView.swift` (a `plans` property; the front page's init `:293-296`; the toolbar `:360-406`), `MAC/ReadingThroughScriptureApp.swift` (`MainWindowView`'s init, `:207`)
- Test: create `T/PlanBandTests.swift` (both suites); modify `T/FrontPageBenchmarkTests.swift`

**Interfaces:**
- Consumes: `ReadingPlanModel` (`showsWeek`, `thisWeek`, `progress`), `PlanWeekText.titleLine` (Task 6); `PlanReadingRow`, `PlanProgressLine` (Task 7); `ReadingThroughScriptureApp.planWindowID` (Task 7).
- Produces:

```swift
/// What the band and the reader's popover both hold: the title line, the week's readings in equal columns, the plan's progress.
public struct PlanWeekSummary: View {
    public init(model: ReadingPlanModel, onShowWholePlan: @escaping () -> Void)
}
/// The summary as the reader's popover: a scaled 360 pt wide, padded `xs`; `onDone` closes it after a passage or the whole plan is opened.
public struct PlanWeekPopover: View {
    public init(model: ReadingPlanModel, onShowWholePlan: @escaping () -> Void, onDone: @escaping () -> Void)
}
// FrontPageView
public init(navigation: NavigationModel, marks: [ChapterLocation: ChapterMarks], plans: ReadingPlanModel? = nil,
            onShowWholePlan: @escaping () -> Void = {}, onOpenSettings: @escaping () -> Void)
public nonisolated static func showsBand(showsWeek: Bool, libraryViewOpen: Bool) -> Bool
```

**The summary.**
- One line: "This week" in `pageFace.swiftUIFont(.title3)` `ink.primary` (the header trait); beside it on the same baseline `PlanWeekText.titleLine` in `.callout` `ink.secondary`; at the trailing end "The whole plan" with `chevron.right` after it (`TrailingIconLabelStyle`), a plain button in `.callout` medium, the accent, its help "Reading Plan (⌥⌘P)".
- `sm` under it, the readings as `PlanReadingRow(layout: .stacked)` in a grid of equal columns, each at least a scaled 150 pt (`@ScaledMetric(relativeTo: .callout)`), `md` apart, wrapping to a second row when they do not fit (`GridItem(.adaptive(minimum:), alignment: .topLeading)`), `sm` between rows. The circle's hit area is a scaled 24 pt.
- `sm` under them, `PlanProgressLine(progress: model.progress)` across the full width. VoiceOver reads it as "Plan progress", its value "112 of 335 readings".

**The band** is in `FrontPageView.left`, over the contents and only over the contents: when `showsBand(showsWeek: plans?.showsWeek == true, libraryViewOpen: navigation.libraryPlace != nil)`, a column of the summary (`lg` at the sides, `md` above, `sm` below), a 1 pt `ink.rule` line inset `lg` at each side, then `ContentsPageView` as it is. No fill and no card. The band's buttons come before the contents in the Tab order; the contents remain one Tab stop, still take the keyboard as the page opens, and keep their own Return, Space and arrows. Nothing here takes Esc.

**The reader's button** is in `MainWindowView.toolbarContent`'s primary group, before Text & Layout, only while `plans.showsWeek`: `Label("This Week", systemImage: "calendar")`, help "This week's readings", dimmed off the reader (`model.screen != .reader`), with `.popover(isPresented:arrowEdge: .bottom) { PlanWeekPopover(…) }` as Text & Layout's is presented (`:395`). "The whole plan" and the band's link both `openWindow(id: ReadingThroughScriptureApp.planWindowID)`. Keep the new state and modifiers out of `body`'s chain.

- [ ] **Step 1: Write the failing tests.** `T/PlanBandTests.swift`:

```swift
@Test func theBandShowsOverTheContentsWhileAPlanIsFollowedAndNotFinished() {
    #expect(FrontPageView.showsBand(showsWeek: true, libraryViewOpen: false))
    #expect(!FrontPageView.showsBand(showsWeek: true, libraryViewOpen: true))          // People, Places and About have a header of their own
    #expect(!FrontPageView.showsBand(showsWeek: false, libraryViewOpen: false))        // no plan, no dates yet, or finished
}
```

  In `T/FrontPageBenchmarkTests.swift`, `theFrontPageOpensWithinAHundredMilliseconds` hosts the front page with a `plans` model following the 67-week sample anchored on week 63 (five readings of two passages), so the 100 ms bound now covers the band.

- [ ] **Step 2: Run.** `--filter PlanBandTests` FAILS to compile.
- [ ] **Step 3: Build** the summary, the band and the button.
- [ ] **Step 4: Run.** Both suites pass; the front page's benchmark is under 100 ms run alone, and you write its new median beside the old 57 ms in your report (if it is over, stop and report the figure; the bound is the Library spec's); both Debug builds succeed (do not launch either app).
- [ ] **Step 5: See it.** Render the front page at 1100 by 760 and at 820 by 520, each inside a container 200 pt taller, in light, dark and Sepia: the 86-week sample (four readings, two ticked) reading John 15 in the ESV; the 67-week sample on week 63 (five readings: one row at 1100, two rows at 820); a week with a label; a reading of three passages; on the meeting day ("meets today"); with a Library view open (no band); with no plan, a plan with no dates and a finished plan (no band, the page as project 4 left it); and the first at the largest standard text size and one accessibility size. Render `PlanWeekPopover` alone at its own width, in light and dark. Open every picture: the contents start under the hairline and keep their columns, no passage is clipped or wrapped mid-name, the progress line's track shows, the link sits at the trailing edge. Say what could not be seen.
- [ ] **Step 6: Commit.** `feat: this week over the Mac's contents, and behind a button in the reader's toolbar (reading plans 5.1)`

---

### Task 9: The review, which is also the editor, and bringing a file in (spec 6.1 Import…, 6.2, 6.3; 5.2's toolbar)

**Run:** Opus (text fields in a list that reorders; a file read off the main actor). Headless renders, which cannot show: typing in a line and its mark clearing; Return and Tab between lines; a dragged reading; the date picker; the file panel and a dropped file; the progress while a file is read; Save dimmed and then lit; Esc cancelling; a "To check" line scrolling to its week; ⌘Z in a field. One live pass by the controller afterwards, in the rehearsal identity: New Plan by keys, a line typed wrong then right, Save; Edit Plan…; and Import… on a text file the controller writes in its scratchpad. Matt imports his own PDF in Task 13.

**Files:**
- Create: `UP/PlanEditorSession.swift`, `UP/PlanEditorView.swift`
- Modify: `UP/PlanWindowView.swift` (the toolbar's three items, the empty state's two buttons, the sheet, the file importer, the drop, the failure's alert)
- Test: create `T/PlanEditorSessionTests.swift` (both suites); modify `T/PlanBenchmarkTests.swift`

**Interfaces:**
- Consumes: `PlanDraft`, `PlanReview`, `PlanFlag` (Task 2); `PlanFileImport` (Task 5); `ReadingPlanModel` (`save`, `followed`, `chapterCounts`, `today`) (Task 6).
- Produces:

```swift
@MainActor @Observable public final class PlanEditorSession {
    public enum Phase: Equatable, Sendable { case idle, reading(fileName: String), editing, failed(message: String, offersNewPlan: Bool) }
    public typealias Reader = @Sendable (URL, PlanDay) -> Result<PlanDraft, PlanFileImport.Failure>
    public private(set) var phase: Phase
    public var draft: PlanDraft?                                     // the editor shows while this is set
    public private(set) var heading: String                          // "Check the Plan", "New Plan", "Edit Plan"
    public init(model: ReadingPlanModel, read: @escaping Reader = PlanFileImport.draft(fromFileAt:today:))
    public func newPlan()
    public func editFollowedPlan()
    public func importFile(at url: URL) async                        // the read runs off the main actor
    public var flags: [PlanFlag] { get }
    public func flag(forReading id: UUID) -> PlanFlag?
    public var canSave: Bool { get }
    public func save()                                               // nothing unless `canSave`
    public func cancel()
    public func paste(_ text: String)
    public func dismissFailure()
}
/// The review and the editor, on both apps: the title, what to check, and every week as lines of text.
public struct PlanEditorView: View { public init(session: PlanEditorSession) }
```

**The session.** `newPlan` sets a `PlanDraft(title: "")` and "New Plan". `editFollowedPlan` sets `PlanDraft(plan:)` of the followed plan and "Edit Plan" (nothing for an unreadable plan). `importFile` sets `.reading`, runs `read` in a detached task, then on success sets the draft, `.editing` and "Check the Plan"; on `.notAPlan`, `.failed(PlanFileImport.notAPlanMessage, offersNewPlan: true)`; on `.unreadableFile`, `.failed(PlanFileImport.unreadableMessage, offersNewPlan: false)`. `flags` is `PlanReview.flags(draft, chapterCounts: model.chapterCounts)`, worked out again only when the draft changes. `save` hands `draft.plan(now:)` to `model.save` and clears the draft; nothing is stored before it. `cancel` clears the draft and stores nothing. `paste` is `draft.append(text:today:)`.

**The editor** is a sheet: on the Mac over the plan window, at least 620 by 520; on the iPhone a full sheet in a `NavigationStack` (Task 11 presents it). It is one `List` (`.plain`, on `paper.page`), so 86 weeks are laid out lazily:
- **Head:** the heading (the sheet's title); the title's field, prompt "Plan title", in `.title3`; when `draft.firstYear` is set, a row "Starts in" with a stepper showing the year, which calls `setFirstYear` (every date that came from the file follows).
- **To check,** when there are flags: a header in the Label style ("To check", then the count), then one plain button a flag: `exclamationmark.triangle` in `ink.secondary` and the flag's sentence in `.callout` `ink.primary`. Choosing it scrolls to its week. Never red: red is for Delete.
- **A week** is a section. Its header row: "Week" and the number in a field a scaled 44 pt wide; the date as a compact date picker, or **Set Date** when it has none, with a **Clear** in the picker's context menu; the label's field, prompt "Label". Its rows are the readings, one text field each, in `.body`, prompt "Psalms 84; Esther 7-8". A line with a flag has the flag's sentence under it in `.caption` `ink.secondary` after `exclamationmark.triangle`. Rows move within their week by dragging (`.onMove`), and each has a remove button (`minus.circle`, `ink.secondary`, "Remove Reading"; on the iPhone a swipe too). The section ends with **Add Reading** and, in a menu, **Remove Week**.
- **Foot:** **Add Week**; for a new plan the system's Paste button (`PasteButton(payloadType: String.self)`), which calls `paste`; **Cancel** (`.cancelAction`) and **Save**, dimmed while `!canSave`. Save is not the default action: Return in a line moves to the next line, adding one at a week's end.
- VoiceOver: a week's header reads "Week 63, Tuesday, November 17"; a line with a flag reads the flag after its text.

**In the plan window:** the toolbar gains **Import…** (`square.and.arrow.down`), **New Plan** (`plus`) and **Edit Plan…** (`pencil`, dimmed with no readable plan); the empty state gains **Import…** and **New Plan**. Import… is `.fileImporter(allowedContentTypes: [.pdf, .plainText])`; a PDF or text file dropped on the window is imported too (`.dropDestination(for: URL.self)`). While `.reading`, the window shows `ProgressView("Reading the plan…")` over its content. A failure is an alert with the message, **OK**, and, when offered, **New Plan**.

- [ ] **Step 1: Write the failing tests** in `T/PlanEditorSessionTests.swift` (`make()` returns a model built as `ReadingPlanModelTests` builds one, today 16 November 2026, and its store; `small` is that suite's three-week plan, made again here; `reader(_:)` wraps a fixed result as a `Reader`):

```swift
@Test func anImportOpensTheReviewAndNothingIsSavedUntilAccepted() async throws {
    let (model, store) = try make()
    let draft = PlanText.draft(from: "Week 1\nPsalms 2; Matthew 5-6\nWeek 2\nMatthew 1", title: "Drawn Plan", today: model.today)
    let session = PlanEditorSession(model: model, read: reader(.success(draft)))
    await session.importFile(at: URL(fileURLWithPath: "/tmp/Drawn Plan.pdf"))
    #expect(session.phase == .editing && session.heading == "Check the Plan" && session.draft == draft && session.canSave && session.flags.isEmpty)
    #expect(try store.plans().isEmpty)
    session.save()
    #expect(try store.plans().count == 1 && model.followed?.title == "Drawn Plan" && session.draft == nil && session.phase == .idle)
}

/// Review Focus 2.
@Test func aFileThatIsNotAPlanSaysSoAndOffersNewPlan() async throws {
    let (model, store) = try make()
    let refused = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
    await refused.importFile(at: URL(fileURLWithPath: "/tmp/book.pdf"))
    #expect(refused.phase == .failed(message: "This PDF isn’t laid out like a plan Bible Carrel can read. You can type the plan in instead.", offersNewPlan: true))
    #expect(refused.draft == nil)
    refused.dismissFailure()
    refused.newPlan()
    #expect(refused.phase == .editing && refused.heading == "New Plan" && refused.draft?.weeks.count == 1 && !refused.canSave)   // no title yet
    let unreadable = PlanEditorSession(model: model, read: reader(.failure(.unreadableFile)))
    await unreadable.importFile(at: URL(fileURLWithPath: "/tmp/x.txt"))
    #expect(unreadable.phase == .failed(message: "That file could not be read.", offersNewPlan: false))
    #expect(try store.plans().isEmpty)
}

@Test func saveIsOffWhileALineCannotBeReadAndCancelSavesNothing() throws {
    let (model, store) = try make()
    let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
    session.newPlan()
    session.draft?.title = "Mine"
    session.draft?.weeks[0].readings[0].text = "Hezekiah 3"
    let line = try #require(session.draft?.weeks[0].readings[0].id)
    #expect(!session.canSave && session.flag(forReading: line)?.kind == .unknownBook && session.flags.count == 1)
    session.save()
    #expect(try store.plans().isEmpty && session.draft != nil)
    session.draft?.weeks[0].readings[0].text = "Matthew 5-6"
    #expect(session.canSave && session.flag(forReading: line) == nil)
    session.cancel()
    #expect(try store.plans().isEmpty && session.draft == nil && session.phase == .idle)
}

/// Spec 6.2: a tick stays with its reading through reordering, renumbering and changes to its passages, and goes only with its reading.
@Test func editingAPlanInUseKeepsItsTicks() throws {
    let (model, _) = try make()
    model.save(small)                                                // three weeks of two readings, as in ReadingPlanModelTests
    let first = small.weeks[0].readings[0], second = small.weeks[0].readings[1]
    model.toggle(first)
    model.toggle(second)
    let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
    session.editFollowedPlan()
    #expect(session.heading == "Edit Plan" && session.draft?.planID == small.id)
    let week = try #require(session.draft?.weeks[0].id)
    session.draft?.moveReadings(inWeek: week, fromOffsets: IndexSet(integer: 0), toOffset: 2)
    session.draft?.weeks[0].readings[1].text = "Matthew 1"           // the first reading, now second, with other passages
    session.draft?.weeks[0].number = 7
    session.draft?.removeReading(second.id)
    session.save()
    #expect(model.plans.count == 1 && model.followed?.weeks[0].number == 7 && model.followed?.weeks[0].readings.map(\.id) == [first.id])
    #expect(model.ticked == [first.id])
}

@Test func pastedTextAddsItsWeeks() throws {
    let (model, _) = try make()
    let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
    session.newPlan()
    session.paste("Week 5\nPsalms 2\nWeek 6\nMatthew 1")
    #expect(session.draft?.weeks.map(\.number) == [5, 6])
}
```

  In `T/PlanBenchmarkTests.swift`: `theReviewsFlagsOnEightySixWeeks` (`PlanReview.flags` on the 86-week sample's draft with one line made unreadable: median under 20 ms; both suites), and, on the Mac, `theReviewOpensOnEightySixWeeks` (`PlanEditorView` hosted at 680 by 640 with that draft: median under 300 ms).

- [ ] **Step 2: Run.** `--filter PlanEditorSessionTests` FAILS to compile.
- [ ] **Step 3: Build** the session, the editor and the window's wiring. If the Mac's `List` flashes its selection behind a row, or a field loses the keyboard when a row moves, and one fix does not cure it, stop and report: the controller and Matt choose between the list and a plain lazy stack with Move Up and Move Down.
- [ ] **Step 4: Run.** Both suites pass, the two benchmarks alone under their bounds; both Debug builds succeed (do not launch either app).
- [ ] **Step 5: See it.** Render `PlanEditorView` at 680 by 640 inside a container 800 pt tall, each in light, dark and Sepia: the review of the 86-week sample as text with its dates as months and days, so "Starts in" shows, one week's date missing ("Feb 29") and one line unreadable (two lines under "To check"); a new plan; an edit of the 67-week sample with no dates (Set Date on each week); and the first at the largest standard text size and one accessibility size. Open every picture: a flagged line's sentence sits under it, nothing is red, the week headers do not wrap at the default size, Save is dimmed where a line is unreadable. Say what could not be seen.
- [ ] **Step 6: Commit.** `feat: the review that is also the editor; Import…, New Plan and Edit Plan… in the plan window (reading plans 6.1-6.3)`

---

### Task 10: The iPhone's Plan tab and the edge swipes (spec 5.3, 5.4, 5.5)

**Run:** Opus (the swipe chain; a list that opens scrolled to this week). `TestWindow` renders, which cannot show: the tab bar's glass with four tabs and search; the bar minimising; a swipe's pictures through Plan; where the scroll lands; a thumb on a 44 pt circle; Read coming forward. In the simulator's Debug app, at the default text size, you may only look: the tab bar's order, the Plan tab's empty state, and the swipes Read to Plan to Notes and back by `touch_path`. One look by the controller afterwards in the rehearsal identity's simulator app (`-planProbe large`). Matt tries it on his phone in Task 13.

**Files:**
- Create: `PH/PhonePlanList.swift`, `PH/PhonePlanScreen.swift`
- Modify: `PH/PhoneShellModel.swift` (`PhoneTab`, `PhoneScreen`, `screen`, `show`, the doc comments), `PH/PhoneRootView.swift` (the init, the tab between Read and Notes, `plans.onOpenPassage`), `PH/PhoneEdgeSwipes.swift` (its comments name the chain), `IOS/ReadingThroughScriptureApp.swift`
- Test: create `T/PhonePlanListTests.swift` (both suites); modify `T/PhoneShellModelTests.swift` (`PhoneEdgeSwipeTests`, `:254-293`), `T/PhoneEdgeSwipesTests.swift` (its hosted shell, `:13-36`, and the tab indexes it expects), `T/PlanBenchmarkTests.swift`

**Interfaces:**
- Consumes: `ReadingPlanModel`, `PlanWeekText` (Task 6); `PlanReadingRow`, `PlanProgressLine`, `ChangeMeetingDateView`, `PlanAnchorView` (Task 7); `UndoResponder`.
- Produces:

```swift
// PhoneTab gains `plan`; PhoneScreen is `library, read, plan, notes, ask` (its raw values in that order).
// PhoneRootView.init gains `plans: ReadingPlanModel` after `notesBrowser`.
/// The Plan tab's rows, in order.
public struct PhonePlanList: Equatable, Sendable {
    public enum Row: Hashable, Sendable { case finished, anchor, week(Int), thisWeek, reading(week: Int, id: UUID), next }
    public let rows: [Row]
    public let scrollTarget: Row?                                    // `.thisWeek`; nil when there is none
    public init(plan: ReadingPlan, now: PlanSchedule.Now, openWeek: Int?)
}
#if os(iOS)
public struct PhonePlanScreen: View { public init(plans: ReadingPlanModel, shell: PhoneShellModel) }
#endif
```

**The rows.** With a week that is this week: every earlier week as `.week`, then `.thisWeek`, this week's readings, `.next` (when a week follows), then every later week as `.week`. A week whose index is `openWeek` (never this week) is followed by its readings. A finished plan is `.finished`, then every week. A plan with no dates is `.anchor`, then every week.

**The screen.** A `NavigationStack` holding one plain `List` on `paper.page`, its title the plan's (inline), in a `ScrollViewReader`; each time the tab shows it scrolls `scrollTarget` to the top without animation.
- **`.thisWeek`:** "This week" in `pageFace.swiftUIFont(.title2)` `ink.primary` (the header trait), `PlanWeekText.titleLine` under it in `.subheadline` `ink.secondary`, then `PlanProgressLine`.
- **A reading:** `PlanReadingRow(layout: .stacked, hitSize: 44)` with `hitSize` a scaled metric; each passage button is at least that tall.
- **`.next`:** "Next" in the Label style (`.caption` semibold `ink.secondary`, the header trait).
- **A week:** a button, "Week 54" in `.body` `ink.primary` with `sidebarLine` trailing in `.callout` `ink.secondary`; a tap opens it in place, another closes it, and opening one closes the other. VoiceOver reads `spokenWeek`, its value "Expanded" or "Collapsed". Its context menu has **Change Meeting Date…**.
- **`.finished`** is `finishedLine` in `.callout` `ink.secondary`; **`.anchor`** is `PlanAnchorView`.
- Row separators are `ink.rule`, full width, as the Notes tab's.
- **The `ellipsis` menu** (top bar, trailing): a `Picker` of the plans (inline); **Change Meeting Date…** (this week's, while there is one), which shows `ChangeMeetingDateView` in a sheet at `.medium`; **Delete Plan…**, which asks as the Mac does and can be undone by a shake (`UndoResponder`, as the Notes tab). Task 11 adds Import…, New Plan and Edit Plan….
- **With no plan:** `ContentUnavailableView("No reading plan", systemImage: "calendar", description: Text("Import your group's plan, or type one in."))`. **An unreadable plan:** `unreadableLine`.
- **A passage opened** is `plans.open`; `plans.onOpenPassage` is `shell.showInReader()`.

**The tab** is `Tab("Plan", systemImage: "calendar", value: PhoneTab.plan)` between Read and Notes. **The chain** becomes Ask, Notes, Plan, Read, Library: `shell.screen` and `show(_:)` take the new case, and nothing else in `PhoneEdgeSwipes` changes.

- [ ] **Step 1: Write the failing tests.** `T/PhonePlanListTests.swift`:

```swift
@Test func thisWeekIsAtTheHeadWithTheWeeksBeforeAboveAndAfterBelow() {
    let today = PlanDay(year: 2026, month: 11, day: 16)!
    let plan = PlanSample.gen2Shaped(today: today)
    func readings(_ week: Int) -> [PhonePlanList.Row] { plan.weeks[week].readings.map { PhonePlanList.Row.reading(week: week, id: $0.id) } }
    let list = PhonePlanList(plan: plan, now: .week(index: 52), openWeek: nil)
    #expect(list.rows.count == 52 + 1 + 4 + 1 + 33 && list.rows[51] == .week(51) && list.rows[52] == .thisWeek)
    #expect(Array(list.rows[53...56]) == readings(52) && list.rows[57] == .next && list.rows[58] == .week(53))
    #expect(list.scrollTarget == .thisWeek && !list.rows.contains(.week(52)))
    let open = PhonePlanList(plan: plan, now: .week(index: 52), openWeek: 85)
    #expect(Array(open.rows.suffix(4)) == [.week(85)] + readings(85))
    let last = PhonePlanList(plan: plan, now: .week(index: 85), openWeek: nil)
    #expect(!last.rows.contains(.next) && Array(last.rows.suffix(3)) == readings(85))
    let finished = PhonePlanList(plan: plan, now: .finished, openWeek: nil)
    #expect(finished.rows.first == .finished && finished.rows.count == 87 && finished.scrollTarget == nil)
    let undated = PhonePlanList(plan: PlanSample.gen1Shaped(), now: .undated, openWeek: 0)
    #expect(undated.rows.first == .anchor && undated.rows[1] == .week(0) && undated.rows.count == 1 + 67 + 5)
}
```

  In `T/PhoneShellModelTests.swift`, `theLeftEdgeWalksTowardTheLibraryAndTheRightTowardAsk` becomes: from Ask the left edge leads to Notes; from Notes, left to Plan and right to Ask; from Plan, left to Read and right to Notes; from Read, left to Library and right to Plan; from Library, right to Read. `showingAScreenOpensOrClosesLibrary` gains `shell.show(.plan)` giving `tab == .plan && screen == .plan && !isLibraryShown`. `#expect(PhoneScreen.allCases == [.library, .read, .plan, .notes, .ask])`. In `T/PhoneEdgeSwipesTests.swift` the hosted shell gains `Tab("Plan", systemImage: "calendar", value: PhoneTab.plan) { Text("Plan") }` between Read and Notes, and each test's expected tab and `selectedIndex` follows the new order (Notes is 2, Ask is 3; a swipe in from Read's right edge arrives on Plan).
  In `T/PlanBenchmarkTests.swift`, under `#if os(iOS)`: `thePlanTabLaysOutEightySixWeeks` (`PhonePlanScreen` hosted in a `TestWindow` of 402 by 874 on the 86-week sample, week 53 this week: median under 250 ms).

- [ ] **Step 2: Run.** `--filter PhonePlanListTests` FAILS to compile.
- [ ] **Step 3: Build** the list, the screen, the tab and the chain.
- [ ] **Step 4: Run.** The iOS suite and the package suite pass; the benchmark alone is under its bound; both Debug builds succeed.
- [ ] **Step 5: See it** in a `TestWindow` of 402 by 874, each in light, dark and Sepia: the 86-week sample on week 53 with two readings ticked; the 67-week sample anchored on week 63 (five readings); a later week opened; a week with a label and the "NT Focus" week; a finished plan; a plan with no dates (the anchor); no plan; an unreadable plan; and the first at one accessibility text size. Open every picture: this week is at the top, each circle and passage has room for a thumb, a date and its count fit beside "Week 54", nothing is boxed.
- [ ] **Step 6: Look in the simulator's Debug app,** at the default text size, touching nothing that stores: the tab bar reads Read, Plan, Notes, Ask with the search button; the Plan tab says "No reading plan"; a swipe in from Read's right edge shows Plan, another Notes, and the left edge walks back. Take a screenshot of each. Say plainly what could not be driven.
- [ ] **Step 7: Commit.** `feat: a Plan tab on the iPhone, this week at its head, between Read and Notes in the bar and the edge swipes (reading plans 5.3)`

---

### Task 11: The iPhone's editor, import and menu (spec 5.3's menu, 6.1 and 6.2 on the phone)

**Run:** Sonnet. `TestWindow` renders, which cannot show: the software keyboard over the last lines; the system's file picker; a row dragged; the Paste button's permission. No implementer opens the editor in the simulator's Debug app. One look by the controller in the rehearsal identity's simulator app: New Plan, a line typed, Save; Edit Plan…. Matt imports on his phone in Task 13 if he wishes.

**Files:**
- Create: `PH/PhonePlanMenu.swift`
- Modify: `PH/PhonePlanScreen.swift` (the menu's items, the empty state's two buttons, the editor's sheet, the file importer, the progress, the failure's alert), `UP/PlanEditorView.swift` (the phone's bar and keyboards)
- Test: create `T/PhonePlanMenuTests.swift` (both suites)

**Interfaces:**
- Consumes: `PlanEditorSession`, `PlanEditorView` (Task 9); `PhonePlanScreen` (Task 10).
- Produces:

```swift
/// What the Plan tab's `ellipsis` menu offers, in order.
public enum PhonePlanMenu {
    public enum Item: Hashable, Sendable { case plans, importFile, newPlan, editPlan, changeMeetingDate, deletePlan }
    public static func items(planCount: Int, followedIsReadable: Bool, hasThisWeek: Bool) -> [Item]
    public static func title(_ item: Item) -> String                 // "Import…", "New Plan", "Edit Plan…", "Change Meeting Date…", "Delete Plan…"
}
```

- **The menu:** the plans (when there is one), Import…, New Plan, Edit Plan… (a readable plan), Change Meeting Date… (while there is a this week), Delete Plan… (a plan). The empty state gains **Import…** and **New Plan**.
- **The editor** is `PlanEditorView` in a sheet at `.large` only, on `paper.page`, in its own `NavigationStack`: the heading as the inline title, **Cancel** leading, **Save** (`checkmark`) in the confirmation slot, dimmed while it cannot save. The week's number takes the number pad; a reading's field has autocapitalisation and autocorrection off and "Next" as its Return. The list keeps the line being typed above the keyboard. Swiping the sheet down is Cancel, and asks nothing: nothing was stored.
- **Import…** is the system's file picker for PDFs and text (`.fileImporter`); while the file is read the tab shows `ProgressView("Reading the plan…")`; a failure is the same alert as the Mac's, with **New Plan** when offered.

- [ ] **Step 1: Write the failing tests** in `T/PhonePlanMenuTests.swift`:

```swift
@Test func theMenuOffersWhatCanBeDoneNow() {
    #expect(PhonePlanMenu.items(planCount: 0, followedIsReadable: false, hasThisWeek: false) == [.importFile, .newPlan])
    #expect(PhonePlanMenu.items(planCount: 2, followedIsReadable: true, hasThisWeek: true) == [.plans, .importFile, .newPlan, .editPlan, .changeMeetingDate, .deletePlan])
    #expect(PhonePlanMenu.items(planCount: 1, followedIsReadable: true, hasThisWeek: false) == [.plans, .importFile, .newPlan, .editPlan, .deletePlan])   // no dates yet, or finished
    #expect(PhonePlanMenu.items(planCount: 1, followedIsReadable: false, hasThisWeek: false) == [.plans, .importFile, .newPlan, .deletePlan])
    #expect(PhonePlanMenu.title(.importFile) == "Import…" && PhonePlanMenu.title(.changeMeetingDate) == "Change Meeting Date…" && PhonePlanMenu.title(.deletePlan) == "Delete Plan…")
}
```

- [ ] **Step 2: Run.** `--filter PhonePlanMenuTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** Both suites pass; both Debug builds succeed.
- [ ] **Step 5: See it** in a `TestWindow` of 402 by 874, in light, dark and Sepia: the review of the 86-week sample with two lines under "To check"; a new plan; an edit of the 67-week sample; and the first at one accessibility text size. Open every picture: a week's number, date and label fit its header (on two lines at the large size, never clipped), a flagged line's sentence wraps under it, the bar's Save is dimmed where a line is unreadable.
- [ ] **Step 6: Commit.** `feat: the plan's editor, Import… and New Plan on the iPhone (reading plans 5.3, 6.2)`

---

### Task 12: The largest plans, measured (the lesson of project 4; spec 11 "seen by eye")

**Run:** Sonnet. This comes before the whole-project review, so that nothing is first measured after it. Headless only. The controller reads the figures and decides anything over its bound.

**Files:**
- Modify: `T/PlanBenchmarkTests.swift`; whichever view a figure condemns
- Test: the same file (the macOS tests in the package suite, the iOS test in the iOS suite)

**Interfaces:**
- Consumes: every view and model above; `PlanSample.gen1Shaped()`, `gen2Shaped(today:)`; `ReaderBenchmarkTests.median`.
- Produces: the figures, in your report, each beside its bound.

The two largest cases are the 86 weeks of Gen 2's shape (the longest list) and the 335 readings of Gen 1's shape in weeks of five (the fullest week, the most ticks). Benchmarks from Tasks 7, 8, 9 and 10 exist: the plan window's open (150 ms), the front page with the band (100 ms), the review's flags (20 ms) and its open (300 ms), the Plan tab's layout (250 ms).

- [ ] **Step 1: Add what is missing,** each a median of nine on an in-memory store:
  - `tickingAReadingWithEveryOtherTicked`: the 67-week sample with 334 of its 335 readings ticked; `model.toggle` of the last, with the store's write and the reload. Under 16 ms.
  - `reloadingAfterAnImport`: both samples in the store and 335 ticks on each; `model.reload()`. Under 20 ms.
  - `thePlansWeeksDecode`: `PlanCoding.decode` of the 86-week sample's encoded weeks. Under 5 ms. Print the encoded size in bytes.
  - `choosingEachWeekInTurn` (Mac): the plan window hosted on the 67-week sample anchored on week 63; choose each of its 67 weeks and lay out. Under 16 ms a week (the median of the 67).
  - `theBandWithAFullWeek` (Mac): `PlanWeekSummary` alone at 820 pt wide on a week of five readings of three passages each. Under 30 ms.
  - `thePlanTabOpensOnWeekSixtyThree` (iOS): `PhonePlanScreen` in a `TestWindow` on the 67-week sample anchored on week 63, laid out and scrolled to this week. Under 250 ms.
  - `aDrawnPlanOfEightySixWeeksIsRead` (both suites): `PlanFileImport.draft` of a PDF the test draws with 86 weeks of four and their dates over 13 pages. Under 3 s; print the time on each platform.
- [ ] **Step 2: Run each benchmark alone, three times** (`--filter PlanBenchmarkTests`; `-only-testing:ScriptureUITests/PlanBenchmarkTests`), and write the middle median of each beside its bound.
- [ ] **Step 3: Anything over its bound** is fixed in the view or model that owns it (make a list lazy, work a value out once, narrow what observes) and measured again. A bound is not raised; if one cannot be met, stop and report the figure and what was tried.
- [ ] **Step 4: Render the three surfaces at their largest:** the plan window on week 86 of 86, the sidebar scrolled to its end; the band at 820 pt wide on a week of five readings of three passages; the Plan tab at an accessibility text size on week 63 of 67. Open each: the chosen week is in view, the band's second row is whole, no reading is cut off.
- [ ] **Step 5: Run both suites,** then commit. `test: the largest plans measured: 86 weeks and 335 readings in the window, the band, the review and the Plan tab`

---

### Task 13: Docs and whole-project verification

**Run:** Sonnet writes the documents and runs the suites (Steps 1 to 8). The controller makes the last live pass, cleans up the rehearsal identity, restarts the Mac Debug app and, on Matt's word, installs the phone's (Steps 9 to 11). Matt imports his Gen 1 PDF himself and checks week 63.

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, `docs/superpowers/specs/2026-11-16-milestone-10-reading-plans-design.md` (section 12), `docs/BACKLOG.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (the milestone 10 box, `:238`), `docs/superpowers/specs/2026-11-17-milestone-10-handover.md` (the table and a "Project 5's open ends")

**Interfaces:**
- Consumes: everything above, each task's report, and this plan's "Rehearsal results".
- Produces: the documents in step with the code; a branch ready for Matt's list.

- [ ] **Step 1: `DESIGN.md`.** Section 5: a new entry for the reading plan (the band over the contents and when it shows, the reader's button and its popover, the plan window's sidebar and detail, the tick circle and the reading row, the plan's progress line and how it differs from the chapter's, the review and its "To check" lines, the anchor and the changed date); the Front page entry says the band sits over the contents; the Toolbar entry gains `calendar`; the ⌘K entry's count becomes 33 with Reading Plan; the shortcuts sheet's View group gains its row; the inventory gains `calendar`, `circle`, `checkmark.circle.fill`, `square.and.arrow.down`, `minus.circle` and `exclamationmark.triangle` (`:412`). Section 6: a Don't for colouring a missed week or badging a count. Section 7: the tab bar's four tabs with Plan between Read and Notes (`:470`), the edge swipes' chain Ask, Notes, Plan, Read, Library (`:479`), the Plan tab's rows, the sheets (the editor at `.large`, the date at `.medium`), and `calendar` among the symbols added (`:510`).
- [ ] **Step 2: `DESIGN.json`.** The same facts where the file holds them. `python3 -I -m json.tool DESIGN.json` prints it without error.
- [ ] **Step 3: `README.md`.** Reading plans (importing a PDF or text, the review, the band, the window, the Plan tab, ticks); the keyboard (⌥⌘P); what iCloud now holds (plans and ticks) and that the store moves forward only; the Debug `-planProbe` and that it refuses the main store.
- [ ] **Step 4: The spec's section 12, As built.** Task by task, with:
  - "The PDFs, measured" in short, the counts Task 5 read from both files and how long each took, and the finding about Gen 2's year with Matt's answer.
  - The rehearsal: which procedure, each step's result, how long an updated device took to receive plans, what the older build did on a store the new build had opened, and what was left in iCloud (nothing; under Procedure A an empty container).
  - The eight departures and every decision under "Decided here", each with what it costs if wrong.
  - Task 12's figures beside their bounds, and the encoded size of a plan.
  - The known limits: the reader is built for this church's two layouts; a verse past a chapter's end is not flagged; a reading moves to another week only by retyping; a plan edited on two devices at once ends as the later edit; a plan-only store's backup is skipped when nothing is highlighted and an older backup has marks (`StoreBackup.markCount`); the iPad is not built.
  - The new test counts, and everything a step could not see or drive, by surface.
- [ ] **Step 5: `docs/BACKLOG.md`,** under "Reading and translations": built-in plans stay (wanted); dragging whole weeks; plans' own rows in ⌘K; "Your notes this week"; a neutral way to stop following every plan; the PDF reader for another church's layout; the year chosen by the dates' weekday, if Matt did not ask for it; and anything a task set aside.
- [ ] **Step 6: The main spec's milestone 10 box** for project 5, with one line, left unticked until Matt has looked; the handover's table row and "Project 5's open ends": what was built, what was seen and by whom, what nobody has seen, the rehearsal's result, and "For project 6, which reads this code" (the store's nine models; `PlanRecord`, `PlanTick` and `PlanCoding` version 1; `PlanStore`; `followedPlanID`, the twentieth synced key; `PlanText` as a plan's text form; `PlanProbe`; the rehearsal identity and how it is built; that the `.dev` store on this Mac has moved forward).
- [ ] **Step 7: Run everything, one after another.** The package suite; the iOS suite; the Mac Debug build; the iOS Debug build. All pass and both builds succeed. Record the test counts.
- [ ] **Step 8: Commit.** `docs: reading plans as built; DESIGN and README in step`
- [ ] **Step 9 (the controller): the last live pass, then clean up.** In the rehearsal identity, keys only: the band, the reader's button, the plan window, Import… of a text file, an edit, a delete and its undo; the Plan tab in the simulator's rehearsal app. Then clean up as "The rehearsal identity" says, and write in the handover that the empty container stays on Matt's account.
- [ ] **Step 10 (the controller): the Debug apps.** Tell Matt first: restarting the Mac Debug app on this code moves the `.dev` store on this Mac forward, and project 4's build must never be run on it afterwards (the rehearsal showed an older build does not refuse such a store; it strips the plans from it). Then `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"` (never `pkill -x`) and `open` it; it must show no plan. On Matt's word, `Scripts/install-phone.sh debug` (the phone unlocked, ProtonVPN off), so that both Debug apps know plans before he makes one. The Release apps are not touched: they are updated together, later, on his word.
- [ ] **Step 11: Hand Matt his list** (spec 11, "For Matt"), unchanged, with what this session could not check beside each item, and first: import the Gen 1 PDF yourself and check week 63; say week 63 meets Tuesday 17 November; tick on one device and see it on the other; the band, the plan window and the review on the Mac and the Plan tab and the review on the phone, in light, dark and Sepia. Then the choices left to him: the eight departures, Gen 2's year, the dimmed ticked passages (`ink.tertiary`, under 4.5:1 by the spec's own choice), and where Delete Plan… lives.

---

## Rehearsal results (Task 4)

**The rehearsal was run on 2026-11-19, by the controller, as Procedure A, after three earlier tries that failed.** Those tries (once sandboxed, once not, and once more after the documents were written) reported "No Accounts: Add a new account in Accounts settings": Xcode had no developer account signed in that `xcodebuild` could use, so the `.rehearsal` build could not be signed. A fourth try, after Matt signed in to Xcode, was refused again ("PLA Update available ... agree to the latest Program License Agreement in your developer account"); Matt agreed to Apple's updated licence, and the build was then made. In the order it happened, below. Written by the controller in place of Task 13's note that it had not been run.

- **The procedure used.** Procedure A, the rehearsal identity, as "The rehearsal identity" and Task 4's Steps 4 to 12 say. Matt's word: "I signed in to Xcode, run the rehearsal. Everything else looks good." NEW is this branch's code at `a9e4efe`; OLD is `f2717f6` (project 4's), in the same identity. In the controller's shell `log` is a zsh builtin; `/usr/bin/log` was used.
- **Step 4, NEW built.** To `new-dd`, with the bundle id given on the command line (the full form; the package's resource bundles built). Signature: application identifier `SFQ7B3J933.com.matthewfurr.ReadingThroughScripture.rehearsal`; iCloud container `iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal`, environment Development; its own key-value store and keychain group.
- **Step 5, OLD built** to `old-dd` from a detached worktree at `f2717f6` (with a copy of `Build/bible.sqlite`). First launch on `-storeName Warm` at 15:27: setup failed with a CloudKit error (the container just made is refused at first, as milestone 7's F2 found), the first import timed out. After five minutes, at 15:33: setup, import and export all ended with failure none; prepared. The container works.
- **Step 6, NEW makes the records** (15:34, `-storeName PlanNew -planProbe make`): prepared; "plan probe done: make"; exports ended with failure none; `PlanNew` counts 1 plan, 2 ticks, 0 bookmarks; the plan record "Stand-in plan", 464 bytes of weeks. Quit about 75 seconds after the probe.
- **Step 7, OLD imports past them** (15:35 to 15:38, `-storeName PlanOld`): setup and import ended with failure none; prepared; still running after two minutes and seventeen seconds; no crash report; `PlanOld.store` has neither plan table; bookmarks 0. **Core Data's lines,** three times: "Skipping unknown updated record" for recordType `CD_PlanTick` (twice) and `CD_PlanRecord` (once). Then OLD launched again with `-syncProbe bookmark:GEN.1.1` (15:38): "probe done: bookmark:GEN.1.1"; exports ended with failure none; `PlanOld` holds 1 bookmark.
- **Step 8, the records are still there** (15:39, NEW on a fresh store `PlanCheck`): 1 plan, 2 ticks, 1 bookmark within 5 seconds; its plan record "Stand-in plan", 464 bytes, the same as `PlanNew`'s. **That is the confirmation Matt asked for:** the plan and both ticks were still in iCloud, unchanged, after the older build had imported past them and exported a change of its own.
- **Step 9, a device that ran the older build, then updates** (15:39, NEW on OLD's own store `PlanOld`): 1 plan, 2 ticks, 1 bookmark within 5 seconds; "Stand-in plan", 464 bytes.
- **Step 10, no going back: not as this plan and the spec expected** (15:39 to 15:41). OLD opened `PlanNew`, a store NEW had used, **without refusing it**: setup, prepared, import finished. Core Data migrated the store down: "Migration: CloudKit tables detected. Adding migration statements for removed table: ZPLANTICK" and the same for `ZPLANRECORD`. Both plan tables were dropped from `PlanNew.store`, so the plan and its ticks were gone from that store. One export ended with Cocoa error 134301 (the history token expired); the next three ended with failure none. No crash report. **iCloud was not changed:** a second fresh store on NEW (`PlanCheckTwo`, 15:41) reached 1, 2, 1 within 5 seconds. NEW then reopened `PlanNew` (15:41): the tables were made again and the 1 plan, 2 ticks and the bookmark came back from iCloud within 5 seconds, "Stand-in plan", 464 bytes.
- **The finding, and what it costs.** An older build does not refuse a store the new build has used; it strips the plans and ticks from that store. With sync on they return from iCloud when the new build next opens it. What would not come back: anything not yet sent to iCloud at that moment, and, with sync off, everything but what a backup holds. So the sentence in this plan's constraints and in the spec's section 7, that an older build "cannot open that store", is wrong. The rule in its place: **never run an older build on a store the new build has used.**
- **Step 11, everything taken out of iCloud** (15:41 to 15:44): NEW on `PlanNew` with `-planProbe clear`: "plan probe done: clear", exports ended with failure none, `PlanNew` 0, 0, 1. NEW on `PlanOld` with the sync probe toggled the bookmark off ("probe done", exports ended with failure none): `PlanOld` 0, 0, 0. A fresh store `PlanGone`, a minute after launch with its import finished: 0, 0, 0. Nothing of the stand-in records is left in iCloud.
- **Step 12, cleaned up.** The rehearsal's own store folder (`.../Sync/iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal-Development`, six stand-in stores with their backups and support folders, nothing else) deleted whole; the `.dev` and real store folders beside it were not touched (listed after). The rehearsal's preferences deleted; `old-dd`, `new-dd` and the copy of project 4's Debug app deleted; the `old-src` worktree removed.
- **What stays on Matt's account, for good** (as he approved): the App ID `com.matthewfurr.ReadingThroughScripture.rehearsal` and the iCloud container `iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal` (Development), now empty of plans and bookmarks (the app's seed records, if any were exported, remain).
- **What was seen instead of a live pass.** No controller live pass was made in the rehearsal identity: Matt had looked himself in the Debug apps ("Everything else looks good") and is at the Mac; the review's ordered live list stays in the handover for anything he has not tried.
- **The gates.** The gate on a plan in the `.dev` store is met: both Debug apps are on this code. The gate on the Release apps was the rehearsal, which has passed, with the finding above as its condition: the Release apps are updated together, and no older build is ever run again on a store the new one has opened. The Release apps are untouched and wait for Matt's word.

## Where each spec requirement is pinned

| Spec | Pinned by |
|---|---|
| 4: a plan, a week, a reading, a passage; weeks of different lengths; a reading's own identity | Task 1 `aPassageReadsEachFormTheSpecNames`, `aLineIsAReadingOfOneOrMorePassagesWithItsLabel`, `theSamplesAreTheChurchsShapes` |
| 4 **(call)**: several plans, one followed | Task 6 `thePlanFollowedIsTheStoredOneElseTheNewest`; Task 7's menu |
| 4.1: this week, before the first, after the last | Task 1 `thisWeekIsTheFirstWhoseMeetingIsTodayOrLater`; Task 6 `thisWeekAndTheButtonFollowTheDay` |
| 4.1 **(call)**: a changed date moves the later weeks; a label | Task 1 `movingADateMovesTheLaterWeeksAndAnchoringFillsEveryDate`; Task 6 (`setDay`); Tasks 7 and 10 (Change Meeting Date…) |
| 4.1: anchoring a plan without dates | Task 1 (the same test, week 63 on 17 November); Task 6 (`anchor`); `PlanAnchorView` in Tasks 7 and 10 |
| 4.1: a date that does not exist is flagged | Task 2 `yearsAreCountedOnFromTheFirstDate`, `aNewFirstYearPlacesTheFilesDatesAgainAndAHandSetDateStays`; Task 5 `aDrawnTableWithDatesReadsThemAndFlagsFeb29` |
| 4.2: tick and untick; counts; the progress line | Task 3 `tickingIsOneRecordAndUntickingRemovesIt`; Task 1 `countsAreOfThePlansOwnReadings`; Task 6 `tickingCountsAndSurvivesAReload`; `PlanProgressLine` (Task 7) |
| 4.2: ticks from two devices both kept; one reading ticked twice is one tick | Task 3 `twoTicksForOneReadingMergeToTheEarlier`; the fix wave's `sameUUIDTicksSurviveTheMerge` (twins from a restore are left alone). Two devices each keeping their own: by the model's shape (a tick is a record of its own) only; Task 4's crossing of the records was **not run**, so it is owed |
| 5.1: the reader's button **(call)**, only while followed and not finished | Task 6 `thisWeekAndTheButtonFollowTheDay` (`showsWeek`); Task 8 (the button and its popover by render); **no live pass was made**: the button, its popover's anchor and its closing are owed to Matt |
| 5.1: the band, its line, columns, progress, hairline; none without a plan | Task 8 `theBandShowsOverTheContentsWhileAPlanIsFollowedAndNotFinished`, Step 5; Task 6 `theLinesReadAsTheBandAndTheWindowShowThem`; Departures 2, 3 and 6 |
| 5.2: the window, sidebar, detail, toolbar, empty state; ⌥⌘P **(call)**; ⌘K | Task 7 `theWindowOpensOnThisWeek`, the `PaletteCommandTests` lines, `everyMenuShortcutInTheMacAppIsListed`, Step 5; Task 9 (Import…, New Plan, Edit Plan…) |
| 5.3: the Plan tab **(call: the symbol)**, this week at the head, weeks above and below, the menu, the empty state | Task 10 `thisWeekIsAtTheHeadWithTheWeeksBeforeAboveAndAfterBelow`, Steps 5 and 6; Task 11 `theMenuOffersWhatCanBeDoneNow` |
| 5.3: the edge swipes' chain | Task 10's `PhoneShellModelTests` and `PhoneEdgeSwipesTests` lines; `DESIGN.md` and `DESIGN.json` (section 7) say Ask, Notes, Plan, Read, Library (Task 13, Steps 1 and 2) |
| 5.4: a passage opened is reading, at its first chapter or verse; Read comes forward | Task 6 `openingAPassageIsAReadingMoveNotALookup`; Tasks 7 and 10 (`onOpenPassage`) |
| 5.5: VoiceOver's reading and week | Task 6 `theLinesReadAsTheBandAndTheWindowShowThem` (`spoken`, `spokenWeek`); Tasks 7 and 10 (the rows' elements and actions) |
| 6.1: the table from where each word sits; what the two plans have | Task 5's six reader tests and two drawn-PDF tests; "The PDFs, measured" |
| 6.1: 67 by 5; 86 with 77 of four and nine of three | Task 5 Step 6 (`RealPlanPDFTests`); "The PDFs, measured" |
| 6.1: a PDF without the header or with no text | Task 5 `aPageWithoutTheHeaderIsNotATable`, `aPDFWithoutTheHeaderOrWithoutTextIsRefused`, `aLongPDFThatIsNotAPlanIsRefusedFromItsFirstPage`; Task 9 `aFileThatIsNotAPlanSaysSoAndOffersNewPlan` |
| 6.1 **(call)**: years from the first date; the first year can be changed. Overturned by Matt's answer (2026-11-19): the year whose dates all exist and fall on one weekday is preferred | Task 2 `aYearThatKeepsTheDatesOnOneWeekdayIsPreferred` (the rule Matt chose; two expectations added in the fix wave so that its "several keep" and "none keeps" cases discriminate), `yearsAreCountedOnFromTheFirstDate`, `aNewFirstYearPlacesTheFilesDatesAgainAndAHandSetDateStays`; Task 5 `aDrawnTableWithDatesAWeekApartIsPlacedInTheYearThatKeepsTheirWeekday`; `RealPlanPDFTests.gen2IsEightySixWeeksStartingSeptember2026WithNothingFlagged` (Gen 2 starts 15 September 2026, nothing flagged; 2025 still flags Feb 29); Task 9 ("Starts in"); "The PDFs, measured" (the tie, and what the dates say) |
| 6.2: nothing saved until accepted; the title; to check; lines of text; add, remove, reorder | Task 9 `anImportOpensTheReviewAndNothingIsSavedUntilAccepted`, `saveIsOffWhileALineCannotBeReadAndCancelSavesNothing`; Task 2 `theReviewFlagsEachKindAndSaveIsOffWithAnUnreadableLine`; Departures 4 and 5 |
| 6.2 **(call)**: an edit keeps its ticks | Task 2 `editingKeepsEachReadingsIdentity`; Task 3 `savingAnEditDropsOnlyTheTicksOfReadingsRemoved`; Task 9 `editingAPlanInUseKeepsItsTicks` |
| 6.3: a text file and pasted text | Task 2 `textIsReadInTheEditorsOwnForm`, `pastedTextReplacesAnEmptyDraftAndIsAddedToAnyOther`; Task 5 `aTextFileIsReadByTheEditorsForm`; Task 9 `pastedTextAddsItsWeeks` |
| 6.4: Delete Plan asks, and can be undone with its ticks | Task 3 `deletingAPlanTakesItsTicksAndRestoreBringsBothBack`; Task 6 `deletingAPlanIsUndoable`; Tasks 7 and 10 (the dialog) |
| 7: a plan as one record; a tick as one; the followed plan a preference | Task 3 `aPlanIsOneRecordAndComesBackAsItWas`; Task 6's `PreferenceSyncTests` line; Global Constraints |
| 7: the store's rules; forward only | Task 3 `theNewKindsObeyTheStoresRules`, `aStoreFromBeforePlansOpensAndKeepsItsMarks` (a local store). What an older build does on a store the new build has opened, on the mirrored store: Task 4 Step 10, run: it does not refuse the store and strips the plans and ticks from it; they come back from iCloud when the new build reopens it. Never run an older build on a store the new build has used ("Rehearsal results") |
| 7: backup and Restore | Task 3's `StoreCopyTests` and `BackupsModelTests` lines (`StoreBackup` copies the file) |
| 7: an older build on another device leaves them alone | **Confirmed by the rehearsal** (Task 4 Steps 6 to 9, 2026-11-19): the older build skipped the unknown records ("Skipping unknown updated record"), and the plan and both ticks were still in iCloud, unchanged, afterwards ("Rehearsal results"). The Release apps are updated together, and no older build is run again on a store the new one has opened |
| 8: the design documents | `DESIGN.md` (Reading plan, the Toolbar, ⌘K, the shortcuts sheet, the inventory, the Don't, the iPhone's tab bar, edge swipes, Plan tab, sheets and symbols) and `DESIGN.json` (Task 13, Steps 1 and 2) |
| 9: nothing else stored; no test near iCloud or the `.dev` store; the PDFs never committed **(call)** | Global Constraints; Task 5 (drawn PDFs; the opt-in check); Task 4 (the probe's refusal) |
| 10: the five things left to the builder | "Decided here"; Task 5 (thresholds), Task 1 (`PlanCoding`), Tasks 9 to 11 (the phone's editor and rows), Task 6 (the reload) |
| 11: the model, parsing, the PDF reader, flags, ticks, years, the button, storage, the reading move | the rows above |
| 11: run once against the two real PDFs, the counts recorded | "The PDFs, measured" (the spike, 2026-11-19); Task 5 Step 6 (the app's own reader) |
| 11: seen by eye, in light, dark and Sepia | Tasks 7 to 11, each Step 5, and Task 12 Step 4: **offscreen and test-window renders only** (a render cannot show focus, a key, a toolbar, a popover's anchor, a file panel, a drag, the tab bar's glass or a swipe). The only live looks were an implementer's look-only screenshots of the simulator's Debug app (Task 10). **No controller live pass was made.** The whole live look is Matt's, in the order of the whole-project review's list ("What nobody has seen") |
| The largest case, measured before the first review | Tasks 7 to 10's benchmarks; Task 12 (two figures over their bounds); the fix wave brought both under (a hosted keystroke in the 86-week editor about 120 ms to 9 ms against 33; choosing a week 25 ms to 8.4 ms against 16) |
| The whole-project review's findings (C1, I1 to I4, M1 to M7) | The fix wave (`9671435`, `423a4a8`, `f719e5a`, `a9e4efe`): `theFieldsWriteByIdAndNothingOnceTheEditorCloses`, `aSaveTheStoreRefusesKeepsTheDraftAndSaysSo`, `removesAndMovesAreUndoneInTheSheetsManager`, `recordsSharingAUUIDAreOnePlan`, `sameUUIDTicksSurviveTheMerge`, `theDayAndTheTimeZoneChangingMoveToday`, `theWindowFollowsTheDayFromThisWeek`; I5 (the rehearsal) is the gate above, not a fix |
