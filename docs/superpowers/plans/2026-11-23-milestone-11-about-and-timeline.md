# Milestone 11, Project 2: A Book's About Page and Its Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task: one fresh implementer and one fresh task reviewer per task, on the model each task's **Run** line names (no Fable anywhere in milestone 11), then one whole-project review on Opus with its report written to a file, one fix wave and one scoped re-review. Steps use checkbox (`- [ ]`) syntax for tracking. The ledger is `.superpowers/sdd/2026-11-23-milestone-11-about-and-timeline/progress.md`.

**Goal:** About a book reads as an introduction (the name as a title, its facts on one aligned edge, the five most-named people and places) and its events as a timeline in history order, lives folded and eras grouped: a rail on both apps and, on the Mac, a to-scale chart above it whose band follows the scroll; Death of Moses and Job of Uz leave Genesis.

**Architecture:**
- **Data (schema 6).** The importer reads each Theographic event's `duration` (as days), its `partOf` (one link, a life first) and a life's participant, and applies a named list of corrections (`TheographicCorrections`). `BibleStore.eventRecords()` reads every event's record.
- **Pure models in `ScriptureUI/Library`.** `BookTimeline` derives lives, eras and rows from the records and the book's passages (spec 5.2). `TimelineItems` turns it into the rail's flat list (folds, year labels, dashed gaps, the anchor). `TimelineChartModel` packs bars into lanes and maps the band and a click. `BookAbout` carries the facts and the timeline.
- **Reusable views.** `FactList`/`FactRow` (spec 7.1) and `TimelineRail`/`RailRow` (spec 7.2), general, for projects 3 to 5. `LibraryAboutView` composes them; on the Mac a `TimelineChartView` (Swift Charts) sits over the rail.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Charts, GRDB, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-23-milestone-11-about-and-timeline-design.md` (approved 2026-11-23). Section numbers below are the spec's. Mockups: `docs/superpowers/specs/milestone-11-mockups/about-and-timeline.html` (timeline C) and `about-head-v2.html` (the head). Handover: `docs/superpowers/specs/2026-11-23-milestone-11-handover.md`, run unattended.

Paths: `PK` is `Packages/ScriptureKit`; `IMP` `PK/Sources/BibleImporterCore`; `DATA` `PK/Sources/ScriptureData`; `SUI` `PK/Sources/ScriptureUI`; `LIB` `SUI/Library`; `TI` `PK/Tests/BibleImporterCoreTests`; `TD` `PK/Tests/ScriptureDataTests`; `T` `PK/Tests/ScriptureUITests`. Renders go to `RENDERS` = `/private/tmp/claude-501/-Users-matt-Code-reading-through-scripture/833408d4-1099-4a4f-9996-0bb2a261fbb6/scratchpad/renders/project-2`.

**Built on, read in the code at `06b83bd` (project 1 finished).**
- `BibleSchema.version = 5` (`DATA/BibleSchema.swift:5`); `event (id, title, year, sort_key)` and `event_passage (start, event_id, end)` (:84-85). `BibleStore` throws `schemaMismatch` on another version (`DATA/BibleStore.swift:26-29`). `Scripts/ensure-bible.sh` rebuilds `Build/bible.sqlite` when the version in the source changes, through `build-bible.sh` (`swift run -c release … bible-importer`, several minutes) from the pinned caches; nothing is fetched.
- `TheographicTables` (`IMP/TheographicTables.swift`): `Event(id, title, year, sortKey, passages)` (:25-27); `buildEvents` (:279-296) reads `EventFields(eventID, title, sortKey, startDate, verses)` (:427-431); `buildPeople` keeps `idsByRecord` internally and returns `idsByLookup` (:146-170). `BibleDatabaseWriter.importTheographic` inserts events (`IMP/BibleDatabaseWriter.swift:189-200`).
- The Theographic fixture exists in three identical copies: `TI/Fixtures/Theographic`, `TD/Fixtures/Theographic`, `T/Fixtures/Theographic` (6 events, 49 verses, 13 people).
- `BookAbout` (`LIB/BookAbout.swift`): `placeLine`, `lengthLine`, `peopleAndPlacesLine`, `writers`, `events`, `span(showingDates:)`, private `passage(of:in:translationID:store:)`. `LibraryYear` (`LIB/LibraryYear.swift`): `text`, `life`, `span`. `LibraryAboutView` (`LIB/LibraryAboutView.swift`): `@AppStorage(LibraryDates.showKey)`, a scaled 520 pt column, `lg` padding and spacing, `anchoredEvent(in:anchor:)` and `eventScrollID`. Hosted by `LibraryView.content` (`LIB/LibraryView.swift:117-119`; `walk` uses `place.chooseInItsTopic`) and `PhoneLibraryPages` (`SUI/Phone/PhoneLibraryPages.swift:128-131`; `push(.entity(book:…))`).
- `store.people(inBook:)` and `placesNamed(inBook:)` order by verses in the book, then name (NOCASE), then id. `store.writers(ofBook:)`. `navigation.bookSubtitle(_:)` (`SUI/NavigationModel.swift:80`), the pane's subtitle. `PageFace.swiftUIFont(_:weight:italic:)`; `@Environment(\.pageFace)`. `ReferenceRunsText` (`LIB/ReferenceRunsText.swift`) sets `.font(.callout)` and is one accessibility element with an action per reference. `LibrarySectionHeader`, `LibraryDatesNotice`, `LibraryDatesFootnote`, `LibraryCreditLine` (`LIB/LibrarySections.swift`, `LIB/LibraryCredit.swift`). `GroupLabel(_:size:)` (`LIB/GroupLabel.swift`). `HairlineRule` (`SUI/HairlineRule.swift`, project 1). `Color.accentWash`, `inkTertiary`, `inkRule` (`SUI/Palette.swift`); `AppSpacing`, `AppRadius` (`SUI/Metrics.swift`).
- Tests pinning today's shape: `TheographicTablesTests` (`events.map(\.id) == [1, 300, 301, 302, 310, 311]`), `BibleDatabaseWriterTests` (`eventCount == 6`, `event_passage == 8`, `schema_version == "5"` twice), `BibleStoreTests.theBuildScriptsPatternReadsTheSchemaVersion` (`== 5`), `LibraryPagesTests.aboutABookGivesItsFactsWritersAndEventsInOrder` and `:89`, `PhoneShellModelTests:159-163` (`anchoredEvent`), `LibraryBenchmarkTests.aboutGenesisOpens` (`events.count == 116`, 300 ms).
- **Head counts:** package 1,536, iOS `ScriptureUITests` 1,029. SwiftLint 83, impeccable-lint 27, asset checker 0. In files this plan touches: `LibraryView.swift:106` 2 SwiftLint (a `Rectangle` rule with `accessibilityHidden`), `PhoneLibraryPages.swift:345` 2; none in the other touched files; impeccable-lint none in any.

If a name differs when a task is built, say so before going on.

## The data, checked against the pinned cache

Recomputed from `~/Library/Caches/ReadingThroughScripture/theographic/b9a848543695` with both corrections and spec 5.2's rules (scratch scripts in the planning session's scratchpad, `p2data/`):

- 501 events, all with a year and a `duration`: `NNND` 346, `NNNY` 129, `NNM` 22, and one each of `7Y6M`, `3M10D`, `2.5Y`, `1W`, as the spec says. 249 name a `partOf`; only 129 names two (121 Lifetime of Moses, 126 Wilderness Wanderings); none points outside the table. All 27 "Lifetime of" records have exactly one participant (Adam 78 … Job 1639, Moses 2108). Event 129's `verseSort` is `01034001`, 107's and 108's `01046013`.
- **Genesis:** 24 lives, 41 events, last row "Joseph's brothers return to Egypt", Spans about 4004 to 1635 BC (Death of Joseph, folded), 10 chart lanes, 113 events with a passage in the book (116 today, less 107, 108, 129). People 352 ("God, Jacob, Abraham, Joseph, Isaac and 347 more"); places 119 ("Egypt, Canaan, Sodom, Beersheba, Bethel and 114 more").
- **Acts:** 78 events, no lives. **Exodus** and **Galatians:** "Sojourn in Canaan and Egypt" is a single row (Exodus: 1 life, 5 event rows, one Wilderness Wanderings group; Galatians 2 rows).
- **Figures that differ from the spec:** see Departures 1 and 2 (era headers drawn 4 times in Genesis and in Acts; three folds in Genesis, not one).
- The chart's rule (Departure 9) shows it for Genesis, Exodus, Judges, 1 Samuel, 1 and 2 Kings, 2 Chronicles, Ezra, Nehemiah, Esther, Jeremiah, Daniel, the four Gospels and Acts; not for 2 Samuel (1 row), Galatians (2), Ruth or Romans (none).
- 1 Chronicles has three lives and nothing else: Seth, Enos and Cainan, each in the book only through its birth (1 Chronicles 1:1-2), which fold to "3 lives, Seth to Cainan" (Review Focus 1). 2 Samuel's one row sits under a "United Kingdom" header whose own record has no passage there.

## Before Task 1 (the controller)

1. Copy this plan's Global Constraints to `.superpowers/sdd/2026-11-23-milestone-11-about-and-timeline/global-constraints.md`.
2. Run the pre-flight scan the handover describes against the code as it is; write `preflight.md` beside the ledger and rule each conflict in this text before Task 1.
3. Record the suites' head counts in the ledger (1,536 and 1,029 expected).

## Pre-flight rulings (controller, before Task 1)

The scan (`preflight.md` beside the ledger, Opus) checked 65 interfaces: 7 conflicts, 4 gaps, 21 notes. Each is ruled here and binds the task it names over the task's own text below. Numbers are the scan's.

1. **Task 5:** `TimelineItem` and `TimelineFold` are internal (their payloads are); `TimelineItemID`, `RailMarker`, `RailSegment`, `RailRow`, `TimelineRail` stay public.
2. **Task 2:** `Entry` gains `let isEra: Bool` (an era record shown as a single row, or an inner era's record); `Kind` stays `.life`/`.event`; `theSojournIsOneRowInExodusAndGalatians` also checks `isEra`. **Task 6:** an entry with `era == nil && isEra` is an era bar.
3. **Task 5:** a life's name button carries `.focusable(false)`, so Tab goes to the fold's Show/Hide only (spec 8); VoiceOver keeps the person as the row's action.
4. **Task 5:** `dashedBelow` measures a closed fold from its last life's year. Genesis has no real gap over 500 years (largest 480); the render check is "no dash in Genesis", and About Luke or Galatians is rendered on the Mac for the dash. As built says spec 6.4's example does not occur in this data.
5. **Tasks 6 and 7:** every test that reads the real database (Genesis's ids) carries `.needsRealBible`; pure tests stay unmarked.
6. **Task 6:** the chart's click is `.chartGesture { proxy in SpatialTapGesture()… }` (or `.gesture(SpatialTapGesture())` on the overlay), never `.onTapGesture`; the plot frame from `proxy.plotFrame`.
7. **Task 5:** entry rows are one element (`.ignore`, `spoken`, actions); an era row is one element with `Era.spoken`, `.isHeader` and its passage as an action; a fold row's element is its button (label the line, value "collapsed"/"expanded").
8. **Task 4:** `nonisolated static func factLabels(_ about: BookAbout, showingDates: Bool) -> [String]` on `LibraryAboutView` builds the row list the body uses, tested: Genesis's six in order, dates off drops Spans, no writer drops Attributed to, no people drops People.
9. **Task 1:** a test that copies the fixture to a temporary folder, writes one `duration` as "3Q", and expects the import's warning and `durationDays == nil`.
10. **Task 5:** the footnote under the rail shows only when `showsDates && about.hasDate`.
11. **Task 2:** `wordsForYearsAndLengths` also pins `Era.spoken` dates on ("The Great Flood, 2348 BC, one year") and off ("The Great Flood"), and an event's and a life's `spoken(showingDates: false)` with no year.
12. `try store.bookTitle(bookID:translationID:).subtitle` (it is not optional).
13. **Task 1 Step 1:** the benchmark captures the loaded `about` and expects it non-nil beside the time.
14. **Task 1:** each correction's warning names its own verse ("Genesis 34:1", "Genesis 46:13").
15. **Task 1:** a life with no participants is `personID == nil` without a warning; only a non-empty list with none resolvable warns. Expected warnings: `["Dropped a part-of link of event 40: recE00000000999 is not among the events", "Skipped writer moses_2108 of Gen: not among the people"]`.
16. **Task 1:** fixture links are record ids (`recE00000000086`).
17. **Task 2:** the record helper is an internal file-scope `enum TimelineFixture` in `BookTimelineTests.swift`, shared by Tasks 5 to 7.
18. **Task 5:** `anchor` returns `TimelineAnchor: Equatable { entry: Int; fold: Int? }?`.
19. **Tasks 3 and 6:** the interim losses are intended (Task 3 drops `anchoredEvent`, restored by Task 5; Task 6's `onPick` is a no-op until Task 7); Task 3 keeps a minimal anchor (scroll to the entry whose passage matches) if it is small.
20. **Task 7's render** hosts `LibraryView` at `LibraryPlace(book: "GEN", topic: .about)` opened at the Flood's passage so the page's own anchor scrolls there; says if the band does not draw offscreen.
21. **Task 7:** the items and the chart model are computed once per `about`, dates and open folds; the band's visible-rows input lives in a small child view or `@Observable` only the chart reads, so a scroll step does not re-run the page.
22. **Task 6:** ticks from `NumberBins(range:desiredCount:)` passed as `AxisMarks(values:)`, labelled by `axisLabels`.
23. **Task 6:** `static func lanes(_ spans: [ClosedRange<Double>]) -> [Int]`, tested on raw intervals; `init` uses it.
24. **Task 6:** band widths and centres compared within `1e-9`.
25. VoiceOver's year has no "about" (spec 8's literal text); on Matt's list as a call.
26. Lengths round to one place and drop ".0".
27. **Task 2:** `LibraryYear.text` is `"about " + bare(_:)`.
28. **Task 4:** `FactRow` is `@MainActor`; `FactList.stacks` and `widestLabelShare` stay `nonisolated`.
29. A dates-off render may show the notice (it reads the real defaults; a read only). None.
30. **Task 5:** the solid rail segment is `HairlineRule(.vertical)`; the dashed one a `Path` stroked with `StrokeStyle(lineWidth: HairlineRule.thickness, dash: …)` in `Color.inkRule`.
31. **Task 5:** an era's passage anchors to `.era(id, occurrence: 0)`; after opening a fold the scroll waits for the next `onChange(of: openFolds)` (or two yields).
32. SDK and isolation checked; no ruling.

## Departures and open calls

Each is built as written; each that Matt may want otherwise goes on his list in the spec's "As built" (Task 9). All are **(call, unattended)**.

1. **Era headers are drawn four times in Genesis and in Acts, for three eras each.** Spec 6.3's rule (a later child elsewhere in time opens the group again) reopens "Sojourn in Canaan and Egypt" after "Abrahamic Covenant" (1921 BC, which the data does not put in the era) and "Third Missionary Journey" after "Paul's Journey to Rome" (AD 56, likewise). The tests pin both: 3 distinct eras, 4 header occurrences. *Cost if wrong:* a repeated header; the rule is one function (`TimelineItems.items`).
2. **Genesis folds three runs, not one:** Seth to Lamech (8), Arphaxad to Peleg (4) and Nahor to Abraham (3), so Abraham's life is behind a Show. Spec 6.2's rule (three or more lives in a row) gives all three. Spec 13's checklist line "Adam to Lamech folded" contradicts 6.2 (Adam's row is followed by "Cain kills Abel"); 6.2 is built. *Cost:* one constant, `TimelineFold.minimumRun = 3`.
3. **The Spans form is new:** "about 4004 to 1635 BC", "about AD 30 to 57", "about 1921 BC to AD 49", one year "about 1055 BC" (`LibraryYear.spans`). `LibraryYear.text`, `life` and `span` stay for People.
4. **Lengths in words** (`LibraryLength.text(days:)`): under 1.5 days "one day"; a whole number of days under 365, "N days" (`7D` and `1W` both "7 days", "150 days"); other lengths under 365 days, months rounded ("one month", "3 months"; `3M10D` "3 months"); from 365 days, years ("one year", "40 years"), a fraction to one place ("2.5 years", "7.5 years"), in the reader's number format. An event row shows a length only from 1.5 days; an era header always.
5. **A life ends at its start plus its whole years** (Adam −4003 + 930 → "to 3074 BC"), not at its folded death's year. A life's passage is the first passage in the book among the life and its folded births and deaths (1 Chronicles's Seth links to his birth's 1:1).
6. **An era shown as a single row** (Exodus, Galatians) reads as an event row: its start in the year column and its length ("430 years"); on the chart it is an era bar.
7. **The band covers the start years of the rows on screen** (a closed fold: its lives' starts), never a life's whole span, which would swallow the chart. A one-year band is drawn at least 1% of the domain wide.
8. **The chart's click on a folded life's bar scrolls to the fold line** and leaves it closed; coming **back** from a passage opened from a life inside a fold opens that fold and scrolls to the life (the fold is not remembered, so the page was rebuilt closed).
9. **The chart shows** with dates on, at least five rows and at least two distinct years (spec 6.5's "more than one distinct year in at least five rows").
10. **VoiceOver's passage action on a rail row opens the passage** (the phone's `onShow`, the Mac's `onOpen`) rather than the Mac's popover, which is anchored inside `ReferenceRunsText`; a row is one element (spec 8).
11. **The chart is hidden from VoiceOver with `.accessibilityHidden(true)` under `// swiftlint:disable:next accessibility_hidden_on_text`** and a reason (spec 6.5 requires it; the rule's own message exempts views whose content is elsewhere). SwiftLint's count does not rise. *Cost:* the first disable comment in the repository.
12. **The Testament row's words:** the canon's name, a comma, then "the Law", "History", "Poetry and Wisdom", "the Major Prophets", "the Minor Prophets", "the Gospels and Acts", "Paul's Letters", "the General Letters", "Revelation". Writers join as a list ("David and Solomon (by tradition)"). The subtitle is the pane's (`store.bookTitle(bookID:translationID:)?.subtitle`, what `navigation.bookSubtitle` reads), so the two agree.
13. **The dates footnote moves under the timeline** (spec 6.1 puts it there), once per page; the notice stays at the head.
14. **The fact list stacks** label over value when the widest label plus the gap passes 40% of the list's width (`FactList.widestLabelShare = 0.4`).
15. **A life's participant is a column, `event.person_id`**, since every life in the data has exactly one; `event.duration_days REAL` and `event.part_of INTEGER`, all nullable.
16. **Every event record is read on each load** (`eventRecords()`, 501 rows), since "is an era" means "has children anywhere". The benchmark (Task 8) is the check.
17. **The 10% rule is measured, not asserted:** the before and after figures are each the median of three runs of the benchmark alone; the committed bound on the new load benchmark is 1.5 × the before figure, rounded up to 10 ms, so a loaded suite does not flake.
18. **The two old SwiftLint findings in each of `LibraryView.swift` and `PhoneLibraryPages.swift`** (a `Rectangle` rule with `accessibilityHidden`) become `HairlineRule()` while those files are touched: 83 → 79.
19. **The three fixture copies stay identical:** Task 1 changes all three.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-11-ui-improvements`, branch `milestone-11-ui-improvements`. Never push or merge; never commit to `main`.
- Git: `/usr/bin/git -C <worktree>`, one git command per Bash call, no `cd … &&`, loops or shell variables. Every commit message ends with the `Co-Authored-By:` line your session gives you, as a second `-m`.
- `rtk` shortens command output; `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time; implementers dispatch no subagents. Rules: `docs/superpowers/process/implementer-rules.md`, `reviewer-rules.md`.
- **Implementers never launch, quit, relaunch or send keys to the Mac Debug app or the simulator's app.** The live passes are the controller's, under milestone 10's handover rules (keys only, the Debug app frontmost and matched by pid).

**Matt's data**
- Never touch the Release apps, `Scripts/install-app.sh`, `/Applications`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. The `.dev` store and its preferences get nothing.
- **No test writes `UserDefaults.standard`.** Dates off in a test or render is `.defaultAppStorage(suite)` on the hosted view with a `UserDefaults(suiteName: "<Suite>-\(UUID().uuidString)")!` removed at the end, or `showingDates: false` on a pure function.

**What is stored (spec 10)**
- Nothing new in the synced store, no synced preference, no `UserDefaults` value. The fold's state is `@State`, not remembered.
- `Build/bible.sqlite` moves to schema 6, rebuilt from the pinned caches by `bash Scripts/ensure-bible.sh`; nothing is fetched and no digest changes.

**The spec's values (verbatim)**
- Head: the book's name in the page face, light, at `.largeTitle`; the subtitle in the page face's italic at `.callout`, `ink.secondary`; `md` under it, then the facts.
- Facts, in order, a row with no value left out: Testament; Length ("50 chapters, 1,533 verses"); Attributed to (links, then "(by tradition)" in `ink.secondary`); Spans (dates on only); a gap of `xs`; People; Places ("God, Jacob, Abraham, Joseph, Isaac and 347 more", "347 more" a link opening People with nothing chosen). Fewer than six: all, no "and n more"; none: the row goes. Ties by name.
- Fact list: labels `.caption` semibold, upper case, tracked a scaled 0.7 pt, `ink.secondary`, right-aligned in a column as wide as the longest label; values `.callout` `ink.primary`, wrapping under themselves; `xs` (scaled) between the columns and between rows. VoiceOver: one element a row, "Testament, Old Testament, the Law", links as actions.
- Timeline: header "Timeline" with the count line beside it in `.caption` `ink.secondary` ("24 lives, 41 events"; "78 events"). Mac: the chart, then the rail; phone: the rail.
- Rail: year column at the leading edge, a scaled width, right-aligned, `.caption` `.monospacedDigit()` `ink.secondary`, the year without "about" ("2348 BC", "AD 30") on the first row of each year only; a 1 pt `ink.rule` line through every row, dashed where the next row is more than 500 years on; a 7 pt dot (`ink.secondary`) for an event, a 7 pt ring (1.25 pt, `ink.secondary`, the page's paper inside) for a life, both `@ScaledMetric(relativeTo: .callout)`. Title `.callout` medium `ink.primary`; passage a link in `.caption` `accent` without the book ("7:6"); a length over a day in `.caption` `ink.secondary`. Rows `xxs` apart; an era group `sm` above.
- Life: the name (title less "Lifetime of "), a link to People through the participant, plain without one; "lived 930 years · to 3074 BC" (dates off: "lived 930 years"). Three or more lives in a row fold: "8 lives, Seth to Lamech" in `.callout` `ink.secondary` italic, "Show" in `accent` (and "Hide"), buttons that take Tab.
- Era header: the `GroupLabel` style, "The Great Flood · 2348 BC, one year" (dates off: the title alone); its passage, when it has one, a link after it.
- Chart (Mac): Swift Charts; `BarMark`s for lives (`ink.tertiary`) and eras (`ink.secondary`) packed into lanes, names above the bar's start in `.caption2` `ink.secondary` where they fit; a scaled 20 pt a lane, at most 12 lanes (more fold the shortest into ticks); `RuleMark` ticks for events, `ink.secondary`; the axis in `.caption2` `ink.secondary` ("4000 BC", "3500", …); the band an `accent.wash` rectangle, no stroke; a click scrolls the rail (`.smooth`, a cut under Reduce Motion). Hidden from VoiceOver, takes no focus. The column's width; scrolls with the page.
- Dates off: same order, no year column, no Spans, no chart, no era spans; lengths stay.
- VoiceOver: "2348 BC, The Great Flood begins, Genesis 7:6"; "Adam, lived 930 years, to 3074 BC"; an era header is a header; a fold "8 lives, Seth to Lamech, collapsed", a button.

**UI rules**
- `CLAUDE.md`'s three rules; read `PRODUCT.md` and `DESIGN.md` first; `/impeccable-swift` for every UI change, its command named in each task. Palette tokens only; `AppSpacing`/`AppRadius` by name, `@ScaledMetric` for sizes tied to text; no card, no glass, no shadow; no `.font(.system(size:))`.
- **Checkers, from the worktree root:** `swiftlint lint --config tools/.swiftlint.yml`; `tools/impeccable-lint/.build/release/impeccable-lint Packages/ScriptureKit/Sources/ScriptureUI Apps`; `swift tools/asset-catalog-checker/check.swift Apps/Mac/ReadingThroughScripture/Assets.xcassets`. Baseline 83, 27, 0. No new finding in a touched or new file.

**Speed (spec 11)**
- About Genesis's load and open stay within 10% of the before figures (Task 1 Step 1, Task 8). No per-redraw store read: the page reads once per book and translation (the existing `LibraryView` cache).

**Tests**
- Swift Testing. Pure-data tests carry no platform guard; a test that hosts a view is `@MainActor`, in a `.serialized` suite, `#if os(macOS)` for `NSHostingView`.
- `.needsRealBible` on any test that opens `BenchmarkChapter.realStore()`; after Task 1 these need the rebuilt schema-6 database.
- `swift test` cannot load the package's Color Sets; tokens come from `Palette.swift`. A test never makes a `Map`.
- Known flake: `ReaderBenchmarkTests.scrollingWhileTheThumbRevealsKeepsTheFrameCost` and other timing benchmarks under full-suite load; rerun alone.
- Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (`--filter <Suite>` while iterating). iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`. Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`. One at a time.

**Renders (every UI task)**
- Mac: a temporary `@MainActor` test, `T/AboutRenderScratch.swift` (`#if os(macOS)`), hosts `LibraryView` on the real store at `LibraryPlace(book:, topic: .about)` in an offscreen `NSHostingView` at 1,100 by 760 (as `LibraryBenchmarkTests.host` does) and writes PNGs to `RENDERS`. Light and dark by the host's `NSAppearance`; Sepia by `SepiaMode.set(true)` and `.followsSepia()`, reset after.
- Phone: a temporary test, `T/PhoneAboutRenderScratch.swift` (`#if os(iOS)`), hosts `LibraryAboutView` in a `NavigationStack` in a `TestWindow` at 402 by 874 on the real store, renders `window.layer` with `layer.render(in:)` (never `drawHierarchy`), light and dark by `overrideUserInterfaceStyle`, Sepia as above, sizes by `.environment(\.dynamicTypeSize, …)`; run with `-only-testing:ScriptureUITests/PhoneAboutRenderScratch`.
- Open every PNG with Read. **Delete both files before committing.** A render cannot show the pointer, a click, focus, VoiceOver, the scroll's band or a text size on the Mac; say so.

## Review Focus

The cases a person meets that the spec's own test list does not pin, most likely first; each has its test in the owning task.

1. **A life in the book only through its birth or death** (1 Chronicles: Seth, Enos and Cainan through 1:1-2): the lives show, fold to "3 lives, Seth to Cainan", and each links to its birth's passage (Task 2, `firstChroniclesShowsLivesThroughTheirBirths`; Task 5, `firstChroniclesFoldsItsThreeLives`).
2. **Back from a passage opened from a life inside a fold:** the reader expects to land on that life, not on a closed fold line (Task 5, `comingBackIntoAClosedFoldOpensIt`).
3. **Show dates turned off while About is open:** every year goes, the chart goes, lengths stay, and nothing waits on a band (Task 5, `datesOffLeavesNoYearAndKeepsLengths`; Task 6, `theChartNeedsDatesFiveRowsAndTwoYears`).
4. **A click on the chart beyond the first or last event, or in a lane with no bar there:** the nearest row, never nothing (Task 6, `aClickOffEveryBarPicksTheNearestRow`).
5. **The phone at an accessibility text size:** the facts stack and the rail's year moves above its title rather than taking half the width (Task 4, `theFactsStackWhenTheLabelsTakeTooMuch`; Task 5, `theYearGoesAboveAtAccessibilitySizes`).

---

### Task 1: Schema 6: lengths, part-of, a life's person, and the named corrections

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change; the review runs the three checkers.

**Files:**
- Create: `IMP/TheographicCorrections.swift`
- Modify: `DATA/BibleSchema.swift`, `IMP/TheographicTables.swift`, `IMP/BibleDatabaseWriter.swift`, `DATA/LibraryRecords.swift`, `DATA/BibleStore+Library.swift`
- Modify (fixture, identically in all three): `TI/Fixtures/Theographic/{events,verses}.json`, `TD/Fixtures/Theographic/…`, `T/Fixtures/Theographic/…`
- Test: `TI/TheographicTablesTests.swift`, `TI/BibleDatabaseWriterTests.swift`, `TD/BibleStoreTests.swift`, `TD/BibleStoreLibraryTests.swift`, `T/LibraryBenchmarkTests.swift`, `T/AboutRealDataTests.swift` (new)

**Interfaces:**
- Produces:
  - `BibleSchema.version = 6`; `CREATE TABLE event (id INTEGER PRIMARY KEY, title TEXT NOT NULL, year INTEGER NOT NULL, sort_key REAL NOT NULL, duration_days REAL, part_of INTEGER, person_id INTEGER)`.
  - `TheographicTables.Event` gains `durationDays: Double?, partOf: Int?, personID: Int?`. `static func days(_ duration: String) -> Double?`: the whole string one or more `<number><unit>` (number digits with at most one `.`; units `Y` 365.25, `M` 30.44, `W` 7, `D` 1), summed; anything else nil. `buildPeople` also returns `idsByRecord`.
  - `enum TheographicCorrections { struct Correction: Equatable, Sendable { let name: String; let eventIDs: [Int]; let verse: VerseLocation; let reason: String }; static let all: [Correction]; static func apply(_ corrections: [Correction], toEvent id: Int, verses: [(position: Int, key: Int)], warnings: inout [ImportWarning]) -> [(position: Int, key: Int)] }`. `all` holds two: "Death of Moses is not in Genesis" (`[129]`, GEN 34:1; reason: Theographic gives Deuteronomy 34:1 Genesis's book number, `verseSort` 01034001) and "Job of Uz is not Issachar's son" (`[108, 107]`, GEN 46:13; reason: Genesis 46:13's Job is tied to Job of Uz). `apply` removes the verse from an event it names; when the verse is not there it removes nothing and warns `Correction "<name>" is no longer needed: event <id> has no Genesis 34:1`. `buildEvents` also warns for a named event the data does not have.
  - `buildEvents`: `partOf` record ids map to event ids; the first whose event's title starts "Lifetime of " is kept, else the first; an unknown one warns `Dropped a part-of link of event <id>: <link> is not among the events`. `personID`: for a "Lifetime of" event, the first participant among the people; participants none of whom resolve warn. An unreadable duration warns `Event <id> (<title>): its length "<text>" is not read` and is nil.
  - `public struct EventRecord: Hashable, Identifiable, Sendable { public let id: Int, title: String, year: Int, sortKey: Double, durationDays: Double?, partOf: Int?, personID: Int?; public init(…) }` and `BibleStore.eventRecords() throws -> [EventRecord]` (every event, by `sort_key` then id).

- [ ] **Step 1: The benchmark, before any code change.** Add to `LibraryBenchmarkTests` `@Test(.needsRealBible) func aboutGenesisLoads()`: the median of `BookAbout.load(book: "GEN", translationID: "ESV", store:)` (`ReaderBenchmarkTests.median("library-about-gen-load")`), `#expect(median < .milliseconds(300))` for now. Run `--filter LibraryBenchmarkTests/aboutGenesisLoads` and `--filter LibraryBenchmarkTests/aboutGenesisOpens` three times each, alone, on today's code and schema-5 database. Write the six medians and each test's median of three to `.superpowers/sdd/2026-11-23-milestone-11-about-and-timeline/benchmarks.md` and to the report. Commit the test alone ("The About page's load benchmark, measured before project 2").

- [ ] **Step 2: Extend the fixture** (all three copies identical). `verses.json` gains `recV00000000101` to `108`: Gen.7.24 `01007024`, Gen.25.26 `01025026`, Gen.34.1 `01034001`, Gen.46.13 `01046013`, Gen.49.33 `01049033`, Deut.34.1 `05034001`, Deut.34.5 `05034005`, Job.42.16 `18042016`. `events.json` gains (id, title, startDate, duration, sortKey, partOf, participants, verses):
  - 40 "Water covers the earth", −2347, `150D`, −2346.5, [`recE00000000999`] (not in the table), —, Gen.7.24
  - 86 "Lifetime of Jacob", −1835, `147Y`, −1834.9, —, [`recP00000000682`], Gen.25.26 and Gen.49.33
  - 88 "Birth of Jacob", −1835, `1D`, −1834.95, [86], —, Gen.25.26
  - 102 "Death of Jacob", −1688, `1D`, −1688.5, [86], —, Gen.49.33
  - 107 "Birth of Job", −1719, `1D`, −1718.95, [108], —, Gen.46.13
  - 108 "Lifetime of Job", −1719, `140Y`, −1718.9, —, —, Gen.46.13 and Job.42.16
  - 121 "Lifetime of Moses", −1570, `120Y`, −1569.9, —, —, Deut.34.5
  - 126 "Wilderness Wanderings", −1490, `40Y`, −1489.9, —, —, Deut.34.1
  - 129 "Death of Moses", −1450, `1D`, −1450.5, [121, 126], —, Gen.34.1, Deut.34.1 and Deut.34.5

- [ ] **Step 3: Write the failing tests.**
  - `TheographicTablesTests.everyLengthTheDataWritesIsRead`: `days("7D") == 7`, `days("930Y") == 930 * 365.25`, `days("3M") == 3 * 30.44`, `days("1Y6M") == 365.25 + 6 * 30.44`, `days("2M10D") == 2 * 30.44 + 10`, `days("1.5Y") == 1.5 * 365.25`, `days("1W") == 7`; nil for `""`, `"Y"`, `"3Q"`, `"about 3Y"`, `"1.2.3Y"`.
  - `…lengthsPartOfAndALifesPerson`: `events.map(\.id) == [1, 40, 88, 86, 107, 108, 102, 121, 126, 129, 300, 301, 302, 310, 311]` (and the same list in `theFixturePlacesEventsFamiliesAndWriters`, whose other pins stand; `theFixturePeopleLandByTheirOwnIds`'s exact warnings gain event 40's dropped link); `events[86]?.durationDays == 147 * 365.25 && events[86]?.personID == 682`; `events[88]?.partOf == 86 && events[102]?.partOf == 86`; `events[129]?.partOf == 121` (two links keep the life); `events[121]?.personID == nil` (no participant); `events[40]?.partOf == nil`, and the warnings include the dropped link of event 40 and nothing about a length.
  - `…theNamedCorrectionsApply`: `events[129]?.passages == [5_034_001...5_034_001, 5_034_005...5_034_005]`; `events[108]?.passages == [18_042_016...18_042_016]`; `events[107]?.passages == []`.
  - `…aCorrectionNoLongerNeededWarnsAndDoesNothing`: `apply(TheographicCorrections.all, toEvent: 129, verses: [(0, 5_034_001)], warnings:)` returns the input unchanged and adds exactly one warning naming "Death of Moses is not in Genesis"; `apply(…, toEvent: 1, …)` changes nothing and warns nothing.
  - `BibleDatabaseWriterTests`: rename the two `…AtSchemaFive` tests `…AtSchemaSix`; `eventCount == 15`, `event_passage == 18`, `schema_version == "6"`; `SELECT duration_days, part_of, person_id FROM event WHERE id = 86` is `(147 × 365.25, nil, 682)`, and `part_of` of 129 is 121.
  - `BibleStoreTests`: the pattern test pins `BibleSchema.version == 6`; `aDatabaseAtSchemaFiveIsRefused`: a file stamped `'5'` throws `schemaMismatch(found: 5, expected: 6)` (what makes `ensure-bible.sh` rebuild).
  - `BibleStoreLibraryTests.eventRecordsCarryTheirLengthAndLinks`: `eventRecords().count == 15`, sorted by `sortKey`; the record of 88 has `partOf == 86`; `events(inBook: "GEN")` holds no 107 and no 129, and `events(inBook: "DEU")` holds 129.
  - `T/AboutRealDataTests.swift` (`@Suite struct AboutRealDataTests`, each `.needsRealBible`): `theRealEventsCarryLengthsAndLinks`: `eventRecords().count == 501`; record 4's `personID == 78` and `durationDays == 930 * 365.25`; 129's `partOf == 121`; 108's `personID == 1639`; every "Lifetime of" record has a `personID`. `mosesAndJobOfUzAreOutOfGenesis`: `events(inBook: "GEN")` has 113 events and none of 107, 108, 129; `events(inBook: "DEU")` has 129, `events(inBook: "JOB")` has 108.
  - `LibraryBenchmarkTests.aboutGenesisOpens`: `events.count == 113` (Task 3 changes it again).
- [ ] **Step 4: Run them and see them fail** (`--filter TheographicTablesTests`, `BibleDatabaseWriterTests`, `BibleStoreTests`, `BibleStoreLibraryTests`): compile failures and wrong counts.
- [ ] **Step 5: Implement** as the Interfaces say; each correction's reason in a comment beside it.
- [ ] **Step 6: Run them and see them pass.** Then `bash Scripts/ensure-bible.sh` (it rebuilds at schema 6; several minutes; record any import warnings it prints, which should be none of the corrections') and `--filter AboutRealDataTests` and `--filter LibraryBenchmarkTests`.
- [ ] **Step 7: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** then the three checkers (unchanged: none of these files is scanned).
- [ ] **Step 8: Commit** the schema, importer, store, fixture copies and tests: "Schema 6: each event's length and part-of, a life's person, and two named corrections to Theographic".

---

### Task 2: The timeline model: lives, eras and rows

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change.

**Files:**
- Create: `LIB/BookTimeline.swift`, `LIB/LibraryLength.swift`
- Modify: `LIB/LibraryYear.swift` (`bare`, `spans`), `LIB/BookAbout.swift` (move `passage(of:in:translationID:store:)` to `BookTimeline`, `static`, internal)
- Test: `T/BookTimelineTests.swift` (new), `T/AboutRealDataTests.swift`

**Interfaces:**
- Consumes: `EventRecord`, `eventRecords()`, `events(inBook:)` (Task 1).
- Produces:
  - `public struct BookTimeline: Equatable, Sendable` with `struct Entry: Equatable, Sendable, Identifiable { enum Kind: Equatable, Sendable { case life(personID: Int?), event }; let id: Int, kind: Kind, title: String, year: Int, lengthDays: Double?, passage: Reference?, era: Int? }` (`era` is the outer era's id, one level deep; `title` is a life's name without "Lifetime of ") and `var endYear: Int?` (a life: `year + Int((lengthDays / 365.25).rounded())`); `struct Era: Equatable, Sendable, Identifiable { let id: Int, title: String, year: Int, lengthDays: Double?, passage: Reference? }`; `let entries: [Entry]` (history order: `sortKey`, then id), `let eras: [Int: Era]`, `let years: ClosedRange<Int>?` (every record with a passage in the book, folded ones included); `var lifeCount`, `var eventCount`, `var countLine: String?` ("24 lives, 41 events", "78 events", "1 life", "1 event"; nil when empty).
  - `static func make(records: [EventRecord], passages: [Int: Reference]) -> BookTimeline` (passages: each in-book event's first passage), spec 5.2 exactly: a life is a "Lifetime of" record; its children by `partOf` titled "Birth of …" or "Death of …" fold into it; an era is a record with children (anywhere) that is not a life and not itself part of a life; an era inside an era is an entry of the outer era with its children flattened beside it; an era with no child in the book but its own passage there is one event entry; a life or era shows when it or anything folded into it has a passage in the book; a life's passage is the first of its own and its folded children's in the book.
  - `static func load(book: String, translationID: String, store: BibleStore) throws -> BookTimeline`.
  - `Entry.detail(showingDates: Bool) -> String?` (a life: "lived 930 years · to 3074 BC", dates off "lived 930 years", nil with no length; an event: `LibraryLength.text` from 1.5 days, else nil). `Era.header(showingDates: Bool) -> String` ("The Great Flood · 2348 BC, one year"; dates off the title). `Entry.spoken(showingDates:) -> String` and `Era.spoken(showingDates:)` (spec 8's forms; an event's length last).
  - `LibraryYear.bare(_ year: Int) -> String` ("2348 BC", "AD 30"); `LibraryYear.spans(_ years: ClosedRange<Int>) -> String` (Departure 3). `enum LibraryLength { static func text(days: Double) -> String }` (Departure 4).

- [ ] **Step 1: Write the failing tests** in `T/BookTimelineTests.swift` (`@Suite struct BookTimelineTests`), on records built in code (a helper `record(_ id:, _ title:, year:, length:, partOf:, person:)`, sort keys in id order):
  - `birthsAndDeathsFoldIntoTheirLives`: a Genesis 5 shape (Adam, Seth, Enos lives each with a Birth and a Death child; "Enoch taken up" a child of Enoch's life; all with passages): entries are the lives and "Enoch taken up", no "Birth of" or "Death of" title, `lifeCount == 3 + 1`.
  - `anEventWithChildrenInsideALifeIsARow`: "Joseph Promoted in Egypt" (child of Joseph's life) with its child "7 years of plenty": both entries, `era == nil`.
  - `anEraGroupsItsChildren`: The Great Flood with three children: each child's `era` is its id; the era record is not an entry; `eras[id]?.title == "The Great Flood"`.
  - `anEraWithinAnEraFlattensIntoTheOuter`: Return from Exile ⊃ Construction of the Second Temple ⊃ two children: the inner record and both children are entries with `era` the outer id.
  - `anEraWithOnlyItsOwnPassageIsOneRow`: Sojourn with children outside the book: one `.event` entry titled "Sojourn in Canaan and Egypt", `lengthDays == 430 * 365.25`, no era.
  - `deathOfMosesSitsInMosesLife`: Moses's life and Death of Moses (`partOf` 121) in the book: one life entry, no Death entry; with only the death's passage in the book, the life still shows and its passage is the death's (Review Focus 1's shape).
  - `aLifeLinksToItsParticipant`: `kind == .life(personID: 78)`; with none, `.life(personID: nil)`.
  - `theCountLineCountsLivesAndEventRowsOnly`: an era record and two folded births are not counted; "2 lives, 3 events"; "1 life"; "78 events" for 78 events and no lives; nil when empty.
  - `wordsForYearsAndLengths`: `bare(-2347) == "2348 BC"`, `bare(30) == "AD 30"`; `spans(-4003 ... -1634) == "about 4004 to 1635 BC"`, `spans(30...57) == "about AD 30 to 57"`, `spans(-1920...49) == "about 1921 BC to AD 49"`, `spans(-1054 ... -1054) == "about 1055 BC"`; `LibraryLength.text(days:)` gives "one day" for 1, "7 days" for 7, "150 days" for 150, "3 months" for 91.32 and 101.32, "one month" for 30.44, "one year" for 365.25, "40 years" for 14,610, "2.5 years" for 913.125, "930 years"; Adam's `detail(showingDates: true) == "lived 930 years · to 3074 BC"`, `(false) == "lived 930 years"`; a 1-day event's detail is nil, a 150-day one's "150 days"; the Flood's `header(showingDates: true) == "The Great Flood · 2348 BC, one year"`, `(false) == "The Great Flood"`; `spoken` gives "2348 BC, The Great Flood begins, Genesis 7:6" and "Adam, lived 930 years, to 3074 BC".
  - In `AboutRealDataTests`: `genesisIsTwentyFourLivesAndFortyOneEvents`: `BookTimeline.load(book: "GEN", translationID: "ESV", store:)` has `lifeCount == 24`, `eventCount == 41`, `Set(entries.compactMap(\.era)).count == 3` with titles The Great Flood, Sojourn in Canaan and Egypt, 7 years of famine; entries in non-decreasing `year` order; `entries.last?.title == "Joseph's brothers return to Egypt"`; `years?.upperBound == -1634` and `LibraryYear.spans(years!) == "about 4004 to 1635 BC"`; no entry titled "Lifetime of Job"/"Job", "Death of Moses" or starting "Birth of Seth". `actsIsSeventyEightEventsInThreeJourneys`: 0 lives, 78 events, three distinct eras (First, Second, Third Missionary Journey). `theSojournIsOneRowInExodusAndGalatians`: in each, exactly one entry titled "Sojourn in Canaan and Egypt", `kind == .event`, `era == nil`. `firstChroniclesShowsLivesThroughTheirBirths` (Review Focus 1): 3 lives (Seth, Enos, Cainan), no events, each passage in 1 Chronicles.
- [ ] **Step 2: Run them and see them fail** (`--filter BookTimelineTests`, `--filter AboutRealDataTests`): compile failure.
- [ ] **Step 3: Implement** as the Interfaces say. Document each rule with its spec section.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers (no new finding in the new files).
- [ ] **Step 6: Commit:** "A book's timeline: lives folded, eras grouped, in the order of history".

---

### Task 3: The About facts

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change (the view keeps compiling against the new model with today's layout, Step 3).

**Files:**
- Modify: `LIB/BookAbout.swift`, `LIB/LibraryAboutView.swift` (only what the new model needs to compile; Task 4 rebuilds it)
- Test: `T/LibraryPagesTests.swift`, `T/PhoneShellModelTests.swift:159-163`, `T/AboutRealDataTests.swift`, `T/LibraryBenchmarkTests.swift`

**Interfaces:**
- Consumes: `BookTimeline.load`, `LibraryYear.spans` (Task 2).
- Produces: `public struct BookAbout: Equatable, Sendable { let book: Book, subtitle: String?, testamentLine: String, lengthLine: String, writers: [PersonSummary], topPeople: [PersonSummary], peopleCount: Int, topPlaces: [PlaceSummary], placeCount: Int, timeline: BookTimeline; var morePeople: Int; var morePlaces: Int; var hasDate: Bool; func spans(showingDates: Bool) -> String?; static let mostNamed = 5; static func load(book:translationID:store:) throws -> BookAbout? }`. `topPeople` is all of them when there are five or fewer, else the first five of `people(inBook:)` (the same for places), so no new query (spec 5.4). `testamentLine` and `subtitle` per Departure 12; `lengthLine` "50 chapters, 1,533 verses" (singulars "1 chapter", "1 verse"). `placeLine`, `peopleAndPlacesLine`, `events`, `span` and `LibraryAboutView.anchoredEvent` go.

- [ ] **Step 1: Write the failing tests.**
  - `LibraryPagesTests.aboutABookGivesItsFactsWritersAndTimeline` (replacing `aboutABookGivesItsFactsWritersAndEventsInOrder`), on the fixture: Matthew in WEB: `testamentLine == "New Testament, the Gospels and Acts"`, `lengthLine == "6 chapters, \(verses.formatted()) verses"`, `writers.map(\.name) == ["Matthew"]`, `peopleCount == 12`, `topPeople.count == 5`, `morePeople == 7`, `placeCount == 8`, `topPlaces.count == 5`, `morePlaces == 3`, the order of `topPeople` is `people(inBook: "MAT").prefix(5)`; `spans(showingDates: true) == "about 5 BC to AD 28"`, `(false) == nil`; Psalms in KJV: no timeline entries, `spans == nil`, `!hasDate`, writers David and Solomon; Tobit nil.
  - `aBookWithFewNamesListsThemAllAndOneWithNoneLeavesThemOut`: a fixture book with five or fewer people gives `morePeople == 0`; a book naming none has `topPeople.isEmpty`.
  - `LibraryPagesTests:89`: `model.bookAbout("MAT")?.testamentLine == "New Testament, the Gospels and Acts"`.
  - `PhoneShellModelTests:159-163`: replace the `anchoredEvent` checks with `navigation.bookAbout("MAT")?.timeline.entries.last?.passage != nil` (Task 5 adds the anchor's own tests).
  - `AboutRealDataTests.genesisFactsReadAsTheMockup`: Genesis in ESV: `subtitle == "The First Book of Moses"`, `testamentLine == "Old Testament, the Law"`, `lengthLine == "50 chapters, 1,533 verses"`, writers ["Moses"], `topPeople.map(\.name) == ["God", "Jacob", "Abraham", "Joseph", "Isaac"]`, `morePeople == 347`, `topPlaces.map(\.name) == ["Egypt", "Canaan", "Sodom", "Beersheba", "Bethel"]` (the tie broken by name), `morePlaces == 114`, `spans(showingDates: true) == "about 4004 to 1635 BC"`.
  - `LibraryBenchmarkTests.aboutGenesisOpens`: `#expect(navigation.bookAbout("GEN")?.timeline.lifeCount == 24)`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement** `BookAbout`, and change `LibraryAboutView` only so it compiles and still shows something truthful (the old rows from the new fields, the events loop over `timeline.entries`); Task 4 replaces it.
- [ ] **Step 4: Run them and see them pass,** then `--filter LibraryBenchmarkTests` (both About benchmarks; record the medians, informational).
- [ ] **Step 5: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 6: Commit:** "About a book: its Testament, length, writers, span and the five most named".

---

### Task 4: The fact list, the head and the facts

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (the fact list, a new reusable component) and `typeset` (the head). Review: `/impeccable-swift audit` on `FactList` and `LibraryAboutView`, plus the three checkers.

**Files:**
- Create: `LIB/FactList.swift`, `LIB/LibraryNameRun.swift`
- Modify: `LIB/LibraryAboutView.swift`, `LIB/LibraryView.swift` (`onOpenTopic`; `:106` → `HairlineRule()`), `SUI/Phone/PhoneLibraryPages.swift` (`onOpenTopic`; `:345` → `HairlineRule()`)
- Test: `T/FactListTests.swift` (new)

**Interfaces:**
- Consumes: `BookAbout` (Task 3).
- Produces:
  - `public struct FactRow: Identifiable { public struct Action { public let name: String; public let perform: () -> Void; public init(_:perform:) }; public let id: String; public let label: String, spoken: String, startsGroup: Bool, actions: [Action]; public init<V: View>(_ label: String, spoken: String, startsGroup: Bool = false, actions: [Action] = [], @ViewBuilder value: () -> V) }` (the value held as `AnyView`; a handful of rows).
  - `public struct FactList: View { public init(_ rows: [FactRow]) }`: the label column's width is the widest label's (measured with `onGeometryChange` on each `fixedSize` label, the maximum kept in `@State`); `public nonisolated static let widestLabelShare: CGFloat = 0.4`; `public nonisolated static func stacks(labelWidth: CGFloat, gap: CGFloat, width: CGFloat) -> Bool` (`width > 0 && labelWidth + gap > 0.4 × width`); a row is `.accessibilityElement(children: .ignore)`, labelled "\(label), \(spoken)", with its actions.
  - `struct LibraryNameRun: View { struct Name: Equatable { let entity: LibraryEntity; let name: String }; init(_ names: [Name], more: Int = 0, tail: String? = nil, onWalk: @escaping (LibraryEntity) -> Void, onMore: (() -> Void)? = nil) }` with `nonisolated static func text(_:more:tail:) -> AttributedString` (one run: "God, Jacob, Abraham, Joseph, Isaac and 347 more", names and "347 more" links in `accent`, "and " and the tail in `ink.secondary`; "David and Solomon (by tradition)") and `nonisolated static func spoken(_:more:tail:) -> String`; links in a private scheme, handled by `.environment(\.openURL)` as `ReferenceRunsText` does.
  - `LibraryAboutView.init(about:navigation:onWalk:onOpenTopic: @escaping (LibraryTopic) -> Void, onShow:onOpen:anchor:)`. The Mac passes `{ place = LibraryPlace(book: place.book, topic: $0) }`; the phone `{ push(.topic(…, $0)) }` for the page's book.

- [ ] **Step 1: Write the failing tests** in `T/FactListTests.swift`:
  - `theFactsStackWhenTheLabelsTakeTooMuch` (Review Focus 5): `stacks(labelWidth: 100, gap: 8, width: 520) == false`; `(labelWidth: 170, gap: 8, width: 402) == true`; `(…, width: 0) == false`.
  - `aRunOfNamesReadsAsOneLine`: `String(text(fiveGenesisNames, more: 347, tail: nil).characters) == "God, Jacob, Abraham, Joseph, Isaac and 347 more"`; two names, no more, tail "(by tradition)": "David and Solomon (by tradition)"; one name: "Moses (by tradition)"; `spoken` equals the plain text; each name's run carries a link and "and " none.
- [ ] **Step 2: Run them and see them fail** (`--filter FactListTests`).
- [ ] **Step 3: Implement** `FactList`, `LibraryNameRun`, then rebuild the top of `LibraryAboutView`: the dates notice; the head (`pageFace.swiftUIFont(.largeTitle, weight: .light)`, header trait; the subtitle; `md`); the fact list's rows per Global Constraints (Spans only with dates on; People with `startsGroup: true`); People's and Places' names call `onWalk(.person(id))`/`.place(id)` and "n more" `onOpenTopic(.people)`/`(.places)`. The old `fact`/`value` helpers and `labelWidth` go. Keep the column (scaled 520, `lg`) and the credit line. The events stay a plain list until Task 5. Wire both hosts.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** (Global Constraints › Renders): the top of About Genesis on the Mac, light, dark, Sepia; About Genesis on the phone at the default size and at `.accessibility3` (the labels stacked), light, dark, Sepia; About Romans and About Psalms (no events, two writers) on the Mac light. Check: labels right-aligned on one edge; "(by tradition)" and "and 347 more" secondary with "347 more" in the accent; the gap before People; the title light and larger than the facts. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (SwiftLint 83 → 79 by Departure 18; nothing new in `FactList.swift`, `LibraryNameRun.swift`, `LibraryAboutView.swift`).
- [ ] **Step 7: Commit:** "About's head: the book's name as a title, its facts aligned on one edge, the five most named".

**Controller live pass:** the Debug app on About Genesis (after the controller's restart onto this build, idle checked); capture the window; Tab reaches no fact; a click on "347 more" (Matt's list if keys cannot) is noted unseen.

---

### Task 5: The rail and the timeline on both apps

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (the rail, a new reusable component) then `layout` (the timeline's rhythm). Review: `/impeccable-swift audit` on `TimelineRail`, `RailRow` and `LibraryAboutView`, plus the three checkers.

**Files:**
- Create: `LIB/TimelineRail.swift` (`TimelineRail`, `RailRow`), `LIB/TimelineItems.swift`
- Modify: `LIB/LibraryAboutView.swift`, `LIB/ReferenceRunsText.swift` (a `font` parameter)
- Test: `T/TimelineItemsTests.swift` (new), `T/AboutRealDataTests.swift`

**Interfaces:**
- Consumes: `BookTimeline`, its texts (Task 2); `BookAbout.timeline` (Task 3).
- Produces:
  - `public enum RailMarker: Equatable, Sendable { case dot, ring, none }`; `public enum RailSegment: Equatable, Sendable { case none, solid, dashed }`.
  - `public struct RailRow<Content: View>: View { public init(marker: RailMarker, leading: String?, above: RailSegment, below: RailSegment, showsLeadingColumn: Bool, @ViewBuilder content: () -> Content) }`: the year column (`@ScaledMetric(relativeTo: .caption)`, right-aligned), the marker column with its line (1 pt `ink.rule`, its upper half `above`, lower half `below`, so rows join without a gap), the marker centred on the content's first line; the content. At an accessibility size the leading label goes above the content (`nonisolated static func yearAbove(_ size: DynamicTypeSize) -> Bool`).
  - `public struct TimelineRail<Content: View>: View`: a `VStack(spacing: 0)` of rows with their ids, the shared column metrics; nothing about Bibles in it (project 3 hangs a family's line on it).
  - `public enum TimelineItemID: Hashable, Sendable { case entry(Int), era(Int, occurrence: Int), fold(Int) }`; `public enum TimelineItem: Equatable, Sendable, Identifiable { case era(BookTimeline.Era, occurrence: Int); case entry(BookTimeline.Entry, yearLabel: String?); case fold(TimelineFold, isOpen: Bool, yearLabel: String?) }`; `public struct TimelineFold: Equatable, Sendable { let lives: [BookTimeline.Entry]; var id: Int; var line: String; static let minimumRun = 3 }`.
  - `enum TimelineItems { static let longGap = 500; static func items(_ timeline: BookTimeline, openFolds: Set<Int>, showingDates: Bool) -> [TimelineItem]; static func dashedBelow(_ items: [TimelineItem]) -> Set<TimelineItemID>; static func anchor(_ timeline: BookTimeline, reference: Reference?) -> (entry: Int, fold: Int?)? }`. `items`: an `.era` item where an entry's `era` differs from the entry before (occurrence counting up); runs of `minimumRun` or more consecutive lives with the same `era` become a fold (open: the fold line then its lives); a year label on the first row of each year, rows and folds only, nil with dates off. `dashedBelow`: a row whose next row with a year is more than 500 years later.
  - `ReferenceRunsText.init(_:inBook:font: Font = .callout, navigation:onShow:onOpen:)`.

- [ ] **Step 1: Write the failing tests** in `T/TimelineItemsTests.swift` (a timeline built with Task 2's helper):
  - `threeLivesInARowFoldAndTwoDoNot`: lives L1 L2 L3, an event, L4 L5: one fold of L1-L3 (`line == "3 lives, L1 to L3"`), then the event, L4, L5 as entries; with `openFolds: [L1.id]` the fold item (`isOpen: true`) is followed by the three lives.
  - `anEraHeadsItsGroupAndReopensAfterAnInterloper`: children A, B of era E, then X (no era), then C of E: items `.era(E, 0)`, A, B, X, `.era(E, 1)`, C.
  - `theYearShowsOnTheFirstRowOfEachYear`: three entries in 2348 BC then one in 2347 BC: labels "2348 BC", nil, nil, "2347 BC"; a fold's label is its first life's year.
  - `datesOffLeavesNoYearAndKeepsLengths` (Review Focus 3): with `showingDates: false` every `yearLabel` is nil and a life's `detail(showingDates: false) == "lived 930 years"`.
  - `aLongGapIsDashed`: entries at −4003 and −2347: the first is in `dashedBelow`; entries 400 years apart are not.
  - `comingBackIntoAClosedFoldOpensIt` (Review Focus 2): `anchor(timeline, reference: Enos's passage) == (Enos.id, fold: Seth.id)`; an event's passage gives `(id, nil)`; nil for nil or no match.
  - `theYearGoesAboveAtAccessibilitySizes` (Review Focus 5): `RailRow<EmptyView>.yearAbove(.large) == false`, `(.accessibility1) == true`.
  - `AboutRealDataTests.genesisFoldsThreeRunsAndDrawsFourHeaders` (Departures 1, 2): fold lines "8 lives, Seth to Lamech", "4 lives, Arphaxad to Peleg", "3 lives, Nahor to Abraham"; `.era` items 4, distinct 3; Acts: `.era` items 4, distinct 3. `firstChroniclesFoldsItsThreeLives` (Review Focus 1): one fold, "3 lives, Seth to Cainan".
- [ ] **Step 2: Run them and see them fail** (`--filter TimelineItemsTests`, `--filter AboutRealDataTests`).
- [ ] **Step 3: Implement** `TimelineItems`, `RailRow`, `TimelineRail`, the `font` parameter, then the timeline section of `LibraryAboutView`: `LibrarySectionHeader("Timeline")` with the count line beside it on the first baseline; the rail from `items(…, openFolds: openFolds, showingDates: showsDates)` (`@State openFolds: Set<Int>`); an entry row: the title (a life's name a plain button calling `onWalk(.person(id))`, plain text without a person), the passage `ReferenceRunsText([passage], inBook: about.book, font: .caption, …)`, the detail; an era row: `GroupLabel(era.header(showingDates:))` with `sm` above, marker `.none`, the era's passage after it; a fold row: ring marker, the line in italic secondary and a "Show"/"Hide" `Button` in the accent (`accessibilityLabel` the line, value "collapsed"/"expanded"); markers per Global Constraints; rows `.accessibilityElement(children: .ignore)` with `spoken(showingDates:)`, the passage action (Departure 10) and the person action; each row `.id(item.id)`. The footnote under the rail (Departure 13). On appearing with an anchor: open its fold if any, then `proxy.scrollTo(.entry(id), anchor: .top)` after a `Task.yield()`. No chart yet.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render:** About Genesis and About Acts on the Mac (the whole page, in a 1,100 by 3,000 host so the rail shows), light, dark, Sepia; About Genesis on the phone at the default size and `.accessibility3`, light, dark, Sepia; About 2 Samuel (one row under United Kingdom), About Romans (no timeline), About Genesis with dates off (a suite with `LibraryDates.showKey` false, `.defaultAppStorage`), all light. Check: the line joins row to row with no gap and is dashed from Creation to the Flood; markers sit on the title's first line; years only on the first of a year; the fold line and its Show; the era headers; at `.accessibility3` the year sits above its title. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (nothing new in `TimelineRail.swift`, `TimelineItems.swift`, `LibraryAboutView.swift`, `ReferenceRunsText.swift`).
- [ ] **Step 7: Commit:** "The timeline as a rail: one row per event in the order of history, lives folded, eras grouped".

**Controller live pass:** About Genesis in the Debug app; Tab to the first Show, Space, capture (Seth to Lamech open); Tab to Hide, Space; capture.

---

### Task 6: The chart (Mac)

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (a Swift Charts strip in the page's voice). Review: `/impeccable-swift critique` on `TimelineChartView` beside the rail (the anti-goal: no dashboard), plus the three checkers.

**Files:**
- Create: `LIB/TimelineChartModel.swift`, `LIB/TimelineChartView.swift`
- Modify: `LIB/LibraryAboutView.swift` (the chart over the rail on the Mac, with no band yet)
- Test: `T/TimelineChartTests.swift` (new), `T/AboutRealDataTests.swift`

**Interfaces:**
- Consumes: `BookTimeline` (Task 2), `TimelineItemID` (Task 5).
- Produces:
  - `public struct TimelineChartModel: Equatable, Sendable { struct Bar: Equatable, Sendable, Identifiable { enum Kind { case life, era }; let id: Int, kind: Kind, title: String, start: Double, end: Double, lane: Int }; let bars: [Bar], ticks: [Double], laneCount: Int, domain: ClosedRange<Double>; static let maximumLanes = 12; init(_ timeline: BookTimeline); static func shows(_ timeline: BookTimeline, showingDates: Bool) -> Bool; static func x(year: Int) -> Double; static func axisLabels(_ values: [Double]) -> [String]; static func band(years: [Int], domain: ClosedRange<Double>) -> ClosedRange<Double>?; func target(x: Double, lane: Int?) -> Target; enum Target: Equatable { case bar(Int), row(Int) } }`.
  - Bars: lives from `x(year)` to `x(endYear)`, outer eras and single-row eras from their start for their length; sorted by start then id, each into the first lane whose last bar ends at or before its start; past 12 lanes the shortest bar becomes a tick and the packing repeats. Ticks: the other entries' `x(year)`. `x(year:)` is `year ≤ 0 ? year − 1 : year` (4000 BC is −4000, so Swift Charts' round ticks read true). `axisLabels`: the first value of each era carries it ("4000 BC", then "3500"; "AD 30", then "35"). `band`: min to max of the years' `x`, widened to 1% of the domain when narrower. `target`: a bar in `lane` covering `x` is `.bar(id)`; else `.row` of the entry nearest `x` (ties to the earlier).
  - `struct TimelineChartView: View { init(model: TimelineChartModel, band: ClosedRange<Double>?, onPick: @escaping (TimelineChartModel.Target) -> Void) }` (`#if os(macOS)` where hosted): lanes at a scaled 20 pt (`@ScaledMetric(relativeTo: .caption2)`); the band `RectangleMark` in `Color.accentWash` drawn first; labels by `annotation(position: .top, alignment: .leading)` with `overflowResolution` keeping them inside, shown where the bar is wide enough to hold them; a `chartOverlay` clear layer whose tap reads `proxy.value(atX:)` and the lane from `atY:` and calls `onPick`; `.accessibilityHidden(true)` under the disable comment (Departure 11); not focusable.

- [ ] **Step 1: Write the failing tests** in `T/TimelineChartTests.swift`:
  - `theChartNeedsDatesFiveRowsAndTwoYears` (Review Focus 3): a five-entry timeline over two years shows with dates on, not off; four entries, or five in one year, do not.
  - `livesPackIntoTheFirstFreeLane`: bars [0, 10], [5, 15], [10, 20] take lanes 0, 1, 0; `laneCount == 2`.
  - `pastTwelveLanesTheShortestBecomeTicks`: thirteen overlapping bars give `laneCount == 12` and the shortest's start among `ticks`.
  - `yearsMapSoRoundTicksReadTrue`: `x(year: -3999) == -4000`, `x(year: 30) == 30`; `axisLabels([-4000, -3500, -3000]) == ["4000 BC", "3500", "3000"]`; `axisLabels([30, 35, 40]) == ["AD 30", "35", "40"]`; `axisLabels([-500, 1, 500]) == ["500 BC", "AD 1", "500"]`.
  - `theBandSpansTheVisibleYears`: `band(years: [-2347, -2346], domain: -4004 ... -1500)` is `-2348 ... -2347` widened to 25.04; one year gives a band 25.04 wide centred on it; `[]` is nil.
  - `aClickOnABarPicksItAndElsewhereTheNearestRow` and `aClickOffEveryBarPicksTheNearestRow` (Review Focus 4): in lane 0 over Adam's bar `.bar(4)`; in an empty lane at x of 2348 BC, `.row` of "The Great Flood begins" (38) in Genesis; beyond the domain on either side the first and the last entries.
  - `AboutRealDataTests.genesisNeedsTenLanes`: `TimelineChartModel(genesis).laneCount == 10`, 27 bars; `shows` true for Genesis and Acts, false for 2 Samuel and Galatians.
- [ ] **Step 2: Run them and see them fail** (`--filter TimelineChartTests`).
- [ ] **Step 3: Implement** the model, then the view, then put it over the rail on the Mac when `shows(…)` (an `sm` gap under it), `onPick` a no-op until Task 7, `band: nil`.
- [ ] **Step 4: Run them and see them pass,** and `--filter LibraryBenchmarkTests` (record the medians).
- [ ] **Step 5: Render:** About Genesis and About Acts on the Mac, light, dark, Sepia, the chart and the first rows; About Exodus light; with the band forced to Genesis's Flood years in a scratch call, light and dark, to see the wash under the bars. Check: lives and eras read apart; labels never collide or leave the strip; the axis reads "4000 BC … 2000"; ticks along the foot; no card, no border. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (nothing new; the one `accessibilityHidden` carries its disable comment).
- [ ] **Step 7: Commit:** "On the Mac, the book's whole span to scale over its timeline".

**Controller live pass:** About Genesis and About Acts; capture each; Tab passes from the header's Contents to the first Show without stopping in the chart.

---

### Task 7: The chart's link to the rail's scroll

**Run:** implementer **Opus**; task reviewer **Opus** (the band following the scroll and a click scrolling the rail). `/impeccable-swift craft`. Review: `/impeccable-swift audit` on `LibraryAboutView` and `TimelineChartView`, plus the three checkers.

**Files:**
- Modify: `LIB/LibraryAboutView.swift`, `LIB/TimelineItems.swift`
- Test: `T/TimelineChartTests.swift`

**Interfaces:**
- Consumes: `TimelineChartModel.band`, `target` (Task 6); `TimelineItems.items`, `TimelineItemID` (Task 5).
- Produces: `TimelineItems.scrollTarget(_ target: TimelineChartModel.Target, items: [TimelineItem]) -> TimelineItemID?` (a bar's life inside a closed fold is that fold's id, an open one's its entry; an era bar is its first `.era` occurrence; a single-row era and a `.row` are the entry) and `TimelineItems.years(visible: Set<TimelineItemID>, items: [TimelineItem]) -> [Int]` (entries' years; a closed fold's lives' years; era headers none).

- [ ] **Step 1: Write the failing tests** in `TimelineChartTests`:
  - `aClickScrollsToTheRowOrItsFold`: on Genesis's items with nothing open, `.bar(8)` (Seth) → `.fold(8)`; with fold 8 open → `.entry(8)`; the Flood era's bar → `.era(id, occurrence: 0)`; `.row(38)` → `.entry(38)`.
  - `theVisibleRowsGiveTheBandsYears`: `{.entry(38), .entry(40), .era(flood, 0)}` gives `[-2347, -2347]`; the closed fold 8 gives its eight lives' years.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Make the rail's rows one scroll target layout and read the visible ids (`onScrollTargetVisibilityChange(idType: TimelineItemID.self, threshold:)` on the rail's `scrollTargetLayout()`; if that does not reach the rail's rows inside the page's stack, the rows' frames by `onGeometryChange` in the scroll view's coordinate space), into `@State visible: Set<TimelineItemID>`; the band is `band(years: years(visible:…), domain:)`, nil while the chart is not shown (dates off: nothing is read or kept). `onPick` → `scrollTarget` → `proxy.scrollTo(id, anchor: .top)` in `withAnimation(reduceMotion ? nil : .smooth)`. The band changes with no animation. Nothing here on the phone. No store read on scroll; no new view per scroll frame (the band is one mark).
- [ ] **Step 4: Run them and see them pass,** and `--filter LibraryBenchmarkTests`.
- [ ] **Step 5: Render:** About Genesis on the Mac scrolled to the Flood (a `ScrollPosition` set in the scratch test), light and dark: the band over 2348 BC. Delete the render file. Say that the band's motion and the click are seen only live.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "The chart's band follows the rows on screen; a click on it scrolls the rail there".

**Controller live pass (spec 13):** About Genesis in the Debug app; Page Down three times, capturing after each: the band moves right. A click on the chart goes on Matt's list (keys only).

---

### Task 8: Speed, and a polish pass

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift polish` over `LibraryAboutView`, `FactList`, `TimelineRail`, `TimelineChartView`. Review: `/impeccable-swift audit`, plus the three checkers.

**Files:**
- Modify: as the polish and the benchmark require (only the files above, `BookAbout.swift`, `BookTimeline.swift`, `BibleStore+Library.swift`)
- Test: `T/LibraryBenchmarkTests.swift`

- [ ] **Step 1: Measure after:** `aboutGenesisLoads` and `aboutGenesisOpens` three times each, alone; append to `benchmarks.md`. Each median of three must be at most 1.10 × Task 1's (spec 11). If one is not, find why before any change (time `eventRecords`, `make`, the two lists, the passages' chapter reads, the layout) and fix it within the spec (for example the rail's rows in a `LazyVStack`, or the records read once per store); measure again.
- [ ] **Step 2: Tighten the bound** (Departure 17): `aboutGenesisLoads` expects under 1.5 × Task 1's median, rounded up to 10 ms; `aboutGenesisOpens` keeps 300 ms. Run both.
- [ ] **Step 3: Polish** per the command: spacing on the scale between head, facts, timeline and credit; the count line's baseline; Dynamic Type at `.xSmall` and `.accessibility5` on the phone (render); Reduce Motion (the click's scroll a cut); Increase Contrast (renders with the high-contrast tokens if `Palette` has them). Fix within the spec; list anything outside it for the backlog.
- [ ] **Step 4: Render** the five spec 13 cases once more, Mac and phone as they apply, light, dark, Sepia: About Genesis and About Acts with the chart; About Genesis on the phone at the default size and `.accessibility3`; About 2 Samuel; About Romans; About Genesis with dates off. Delete the render files.
- [ ] **Step 5: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (record the totals).
- [ ] **Step 6: Commit:** "About's page measured against its old load; spacing, sizes and motion settled".

---

### Task 9: The record

**Run:** implementer Sonnet; task reviewer Sonnet. No view changes; the review checks each document against the code as built and runs the three checkers for the final counts.

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, `docs/superpowers/specs/2026-11-23-milestone-11-about-and-timeline-design.md` (section 14), `docs/BACKLOG.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (milestone 11's box 2)

- [ ] **Step 1: DESIGN.md** (spec 12): section 5, Library views, **About** (`DESIGN.md:377` today): replaced by the head, the fact list and the timeline (rail; the Mac's chart, band and click; dates off), with the values in Global Constraints. New component entries **Fact list** (`FactList`, `FactRow`) and **Rail** (`TimelineRail`, `RailRow`, `RailMarker`, `RailSegment`) as reusable pieces, with what projects 3 and 5 will use them for. Section 2 Colors or 4 Elevation: the chart's bars (`ink.tertiary` lives, `ink.secondary` eras), ticks and the band (`accent.wash`, no stroke). Section 7, iPhone, Library: About with the stacked fact list and the rail, no chart. Do's and Don'ts: "Don't draw a chart that is the only way to its information."
- [ ] **Step 2: DESIGN.json:** "Fact List", "Timeline Rail" and "Timeline Chart" components and the Library About entry, matching Step 1; `python3 -m json.tool DESIGN.json > /dev/null`.
- [ ] **Step 3: README.md:** the About paragraph: the facts, the most named, the timeline in history order with lives folded, the Mac's chart and its band; the two corrections to the data.
- [ ] **Step 4: The spec's "As built"** (section 14): what was built, file by file in a line each; schema 6's columns; every call from this plan's Departures and the ledger, each marked "(call, unattended)" with its reason and cost; the data's figures (this plan's "The data, checked") and where they differ from the spec; the benchmark's before and after medians; the checker counts (SwiftLint, impeccable-lint, asset; total and in the touched files; the four old findings fixed); both suites' counts. Then "For Matt": the spec's section 13 list with "Adam to Lamech" corrected to "Seth to Lamech, Arphaxad to Peleg and Nahor to Abraham" (Departure 2, and that Abraham is behind a Show), the repeated era headers (Departure 1), then what nobody has seen (the chart's click and the band's motion, the person and "347 more" links by pointer, VoiceOver on a row and on the fold, the phone on a device).
- [ ] **Step 5: docs/BACKLOG.md:** a section `## About and the timeline (milestone 11, project 2)` with the spec's set-aside work: a timeline on a person's page or for the whole Bible; the places and people taking part in an event (`locations` on 356, `participants` on 486); and the M15 line updated with this project's measured figures.
- [ ] **Step 6: The main spec's box 2** under milestone 11: `[x]`, "Built 2026-11-23, unattended; reviewed whole; waiting on Matt's look (About Genesis and Acts, Mac and phone)", the spec named.
- [ ] **Step 7: Run the full package suite, then the full iOS `ScriptureUITests`, one after the other;** record both counts (above 1,536 and 1,029); the three checkers, recorded in "As built".
- [ ] **Step 8: Commit:** "docs: About and the timeline as built: DESIGN, README, the spec's As built, the backlog and the milestone box".

**After Task 9 (the controller):** the whole-project review on Opus (`/impeccable-swift critique` over `LibraryAboutView`, `FactList`, `TimelineRail`, `TimelineChartView`, and the importer's corrections), one fix wave, one scoped re-review; then the handover's "Before a project is called done": both suites and both Debug builds one after another, the Mac Debug app restarted after the idle check, the handover's table, the ledger copied to `docs/superpowers/ledgers/milestone-11/2026-11-23-milestone-11-about-and-timeline.md`, the box's wording amended to what the review found.
