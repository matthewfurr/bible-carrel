# Milestone 11, Project 5: Settings › About and the Notes Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task: one fresh implementer and one fresh task reviewer per task, on the model each task's **Run** line names (no Fable anywhere in milestone 11), then one whole-project review on Opus with its report written to a file, one fix wave and one scoped re-review. Steps use checkbox (`- [ ]`) syntax for tracking. The ledger is `.superpowers/sdd/2026-11-23-milestone-11-about-and-notes/progress.md`.

**Goal:** Settings › About reads as a colophon (the app's name as a title page, three sections, one quiet line per source that opens in place to its notice, link and licence), and the Notes window's notes sit under day headings (by date) or book headings (by passage), each a fuller row (the passage, the marked words on their colour, three lines of the note) with a hairline between notes; the phone's Notes tab takes the same day headings; every key, click and Delete in the Notes window behaves exactly as now.

**Architecture:**
- **About.** `Credits` stays the one record: its eight sections become three and its uses are reworded for the line ("· reading typeface"). A pure `CreditLine` says what a line shows and speaks and what it opens to; `AboutView` becomes a plain scrolling page of `CreditLineView`s under `GroupLabel`s, its head `LibraryPageTitle` (project 3's, from project 2's About head) and the version line.
- **The Notes window.** The model grows day sections beside the book sections (`days`, `groups`) built once per rebuild from its own clock, calendar and locale; `visibleIDs` reads `groups`. A pure `NotesBrowserRowParts` says what a row shows by kind; `NotesBrowserRow` draws it; `NoteBodyText`'s preview runs on across blocks with headings at the row's size (`NoteMarkdown.blocks(_:headingsAtTextSize:)`). `NotesBrowserView.list` draws headings (`NotesGroupHeading`, shared with the phone), the hairline between notes and the rule between groups; `NotesBrowserView.row(_:)`, which holds every gesture, key and action, is not changed.
- **The phone.** `PhoneNotesScreen` takes the day headings through the same model, and its note body takes the heading fix at its source. `PhoneMarkRow` is not changed.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData (in-memory stores in tests), Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-23-milestone-11-about-and-notes-design.md` (approved 2026-11-23). Section numbers below are the spec's. Mockup: `docs/superpowers/specs/milestone-11-mockups/about-and-notes.html` (About A, Notes 3). Handover: `docs/superpowers/specs/2026-11-23-milestone-11-handover.md`, run unattended.

Paths: `PK` is `Packages/ScriptureKit`; `SUI` `PK/Sources/ScriptureUI`; `LIB` `SUI/Library`; `PH` `SUI/Phone`; `T` `PK/Tests/ScriptureUITests`. Renders go to `RENDERS` = `/private/tmp/claude-501/-Users-matt-Code-reading-through-scripture/833408d4-1099-4a4f-9996-0bb2a261fbb6/scratchpad/renders/project-5`.

**Built on, read in the code at `07da1f7` (project 4 finished).**
- `Credits` (`SUI/Credits.swift`): `Credit(id, section, name, use, notice, license, link, licenseFile, translationID, fontFamily, licenseLink)`; `Credit.Section` eight cases (`:7-10`); `Credits.all` 17 entries; `entries(in:)`, `licenseText(for:)`, `bundledFontFamilies()`. Read only by `AboutView`. Licence files: Literata, Source Serif 4, holybooks, GRDB.swift; licence links: OpenBible.info, Theographic.
- `AboutView` (`SUI/AboutView.swift`): a grouped `Form`; head `.headline` name and `.callout` version line, combined for VoiceOver; `appName(info:)`, `versionLine(info:)`; private `CreditRow` (name `.body`, use `.callout`, notice `.caption` selectable, link `.callout` accent without "https://", a `DisclosureGroup` labelled with the licence's name for a file, else the licence as a link or text); `LicenseText.reflowed(_:)`. Used by `Apps/Mac/.../SettingsView.swift:40` (last tab, tag "about", `@AppStorage("settingsTab")`) and `PH/PhoneSettingsScreen.swift:110`. The Settings scene has `.followsSepia()` and `.followsPageFace()`.
- `LibraryPageTitle(_ title:, subtitle:)` (`LIB/LibraryPageTitle.swift`): the page face, `.largeTitle`, `.light`, `ink.primary`, header trait. `GroupLabel(_:)` (`LIB/GroupLabel.swift`). `HairlineRule(.horizontal)` (`SUI/HairlineRule.swift`, 1 pt `ink.rule`). `versePanelRowAction(_:)` (`SUI/VersePanel.swift:68`: tap, Mac Tab stop with the ring on a radius-`md` shape, Return and Space, button trait). `columnRowSurface(isLit:reduceMotion:)` (`SUI/ColumnRowParts.swift:104`). `MarkerGlyph(color:)`. `Color(markup:)`. `PageFace.quoteFont()`, `settingMatches(_:_:italic:)`. `LibraryAboutView`'s column: `@ScaledMetric(relativeTo: .body) maxWidth = 520`.
- `NotesBrowserModel` (`SUI/NotesBrowserModel.swift`): `init(store:defaults:onChange:now:)`; `sort`, `filter`, `timeFilter` (each stored under its key on its `didSet`), `query`, `entries`, `sections` (books, only under `.reference`), `totalCount`, `hasKeptVersions`, `selectedID`, `undoManager`; `rebuild()` (`:93-99`); `visibleIDs` (`:104-106`); `moveSelection(by:)`; `entry(id:)`, `target(for:)`; `delete(id:)` (the selection to the row that took its place, `:156-163`).
- `NotesBrowserQuery` and `NotesBrowserSection(id:title:entries:)` (`SUI/NotesBrowserEntry.swift:119-185`): `filter(_:by:)`, `filter(_:since:)`, `sort(_:by:)` (date: newest first, ties by reference), `sections(_:)`.
- `NotesBrowserView` (`SUI/NotesBrowserView.swift`): `list` (`:129-185`): a `LazyVStack(spacing: xxs)` padded `xs`; by reference, a 0.5 pt `Rectangle` between book groups (`:136-138`) and a `.headline` title padded `sm` sides and `xs` top; by date, `ForEach(model.entries)`; one `.focusable()` stop, `onKeyPress` ↑ ↓ Return, `onDeleteCommand`, scroll to the selection (`.smooth`, a cut under Reduce Motion), focus on appear. `row(_:)` (`:189-224`): `NotesBrowserRow`, `.contentShape`, `onTapGesture` (select and focus), `simultaneousGesture(TapGesture(count: 2))` (show), `SecondaryClickHook` (select), `.contextMenu`, traits, two actions, `.id`. The delete dialog (`:85-98`).
- `NotesBrowserRow` (`SUI/NotesBrowserRow.swift`): one `HStack`: a marker column (`@ScaledMetric(relativeTo: .callout) markerWidth = 14`), then the reference `.callout` semibold, the tag `.caption2` semibold `ink.secondary`, then the first block of the note (`NoteBodyText(…, previewLines: 2)`) or, with no note, the quote (`quoteFont`, `ink.secondary`, one line), the versions mark; the date trailing the whole row; padding `sm` across and `xs` down; one VoiceOver element, "Note, John 15:4" (with ", 2 versions"; a conversation "Conversation, Matthew 5:3, <title>").
- `NoteBodyText` (`SUI/NoteBodyText.swift`): `init(_:book:font:previewLines:onOpenReference:)`; with `previewLines`, the first block only, at `ink.primary`. `NoteMarkdown.blocks(_:)` (`SUI/NoteMarkdown.swift:12-50`) sets a heading's runs to `.system(.title3, weight: .semibold)`.
- The phone: `PhoneNotesScreen` (`PH/PhoneNotesScreen.swift`): a plain `List`; by reference `Section`s with a `.headline` `ink.primary` header; rows `PhoneMarkRow` in a `Button`, separators full width tinted `ink.rule`, swipes; `noteBody(for:)` (`:217-223`) passes `NoteMarkdown.blocks(entry.body).first`. `PhoneMarkRow` (`PH/PhoneMarkRow.swift`) is shared with `PhoneSearchScreen.swift:339`, which passes a plain first line (`SearchResults.firstLine`, `SUI/SearchResults.swift:65-70`).
- Tests: `NotesBrowserModelTests` (its `make()` and `seed(_:)`; in-memory `MarkupContainer`, a `UserDefaults` suite), `NotesBrowserQueryTests` (its `entry(…)` helper), `NotesBrowserFilterStyleTests`, `SecondaryClickHookTests`, `CreditsTests`, `PhoneVersionsTests` (`PhoneVersionsFixture`, iOS; its `keep(_:of:at:in:)` makes a `KeptVersion`), `PlanBenchmarkTests.choosingEachWeekInTurn` (the hosted key-event pattern: `NSEvent.keyEvent` sent with `window.sendEvent`), `TestWindow.make(frame:)` (iOS), `ReaderBenchmarkTests.median(_:runs:prepare:_:)`.
- **Head counts:** package 1,737, iOS `ScriptureUITests` 1,189. SwiftLint 71, impeccable-lint 27, asset checker 0. Old findings in files this plan touches: SwiftLint `NotesBrowserView.swift` 4 (`:62-63` the hidden Find button, `:136`, `:138` the group rule); impeccable-lint `NotesBrowserRow.swift` 4 (the marker symbols `:134`, `:138`, `:142`, `:147`), `NotesBrowserView.swift:190` 1 (the row's `onTapGesture`). `PhoneMarkRow.swift`'s are in a file this plan does not touch.

If a name differs when a task is built, say so before going on.

## Checked against the code (where the spec's figures differ)

1. Spec 5.2 says the note is in full ink "where today it is secondary": `NoteBodyText` already draws `ink.primary` (`NoteBodyText.swift:71`). What reads secondary today is the Mac's quote with no note (`NotesBrowserRow.swift:58`) and the phone's note line (`PhoneMarkRow.swift:79`, unchanged by spec 5.5).
2. Spec 5.5 says the heading fix reaches `PhoneMarkRow` and "then applies in Search too": Search already passes a plain first line with no heading font (`SearchResults.firstLine`), so its headings are at the row's size today. The Notes tab's large heading comes from `PhoneNotesScreen.noteBody(for:)` (`:219`). The fix goes there (Departure 17); `PhoneMarkRow` and Search do not change.
3. Spec 5.1's "Tuesday 18 November": 18 November 2026 is a **Wednesday**. Foundation's forms (checked 2026-11-23 with `Date.FormatStyle` `weekday(.wide).day().month(.wide)`): en_US "Wednesday, November 18", with the year "Friday, November 14, 2025"; en_GB "Wednesday 18 November", with the year "Friday, 14 November 2025" (a comma the spec's example lacks). This Mac is en_US. The tests pin Foundation's forms (Departure 9).
4. Spec 5.2 cites `NotesBrowserRow.swift:44-47` for a conversation's last line; it is `:46-52`. Spec 7 cites `DESIGN.md:339` for the rows' padding line; it is `:340`. Spec 4.2 cites `Credits.swift:7-9`; the cases run `:7-10`.
5. Spec 4.3's licence strings are examples: the catalogue also has "CC BY-SA 4.0" (Theographic), "CC0" (3dicons) and "BSD 3-Clause" (holybooks). All show as they are.
6. Today's licence-file disclosure is labelled with the licence's name ("SIL OFL 1.1"), not "Licence text", and today's notice is `.caption`, not `.callout`. Both change as spec 4.3 says.
7. `FactList`'s doc comment (`LIB/FactList.swift:36`) says Settings › About reuses it; nothing does, and spec 4 has no fact list (Departure 4).
8. The ERV's use is "Bible text (ERV)", which spec 4.3 does not name (Departure 2).

## Before Task 1 (the controller)

1. Copy this plan's Global Constraints to `.superpowers/sdd/2026-11-23-milestone-11-about-and-notes/global-constraints.md`.
2. Run the pre-flight scan the handover describes against the code as it is; write `preflight.md` beside the ledger and rule each conflict in a "Pre-flight rulings" section of this plan before Task 1.
3. Record the suites' head counts in the ledger (1,737 and 1,189 expected) and the checkers' (71, 27, 0).
4. **The controller's live passes** fall after Task 3 (About, Mac and simulator), Task 7 (the Notes window, Mac) and Task 8 (the phone's Notes tab, simulator), and once more after the fix wave; each is written under its task. Implementers never launch, quit or send keys to the Mac Debug app or the simulator.

## Departures and open calls

Each is built as written. Each is **(call, unattended)**, with its reason and its cost if wrong; each Matt may want otherwise goes on his list in the spec's "As built" (Task 10).

1. **`Credit.Section` becomes three cases** (`scripture` "Scripture", `studyData` "Study data", `typefacesAndSoftware` "Typefaces, icon, videos and software"), not a mapping in the view (spec 9 leaves it open). Only `AboutView` and `CreditsTests` read it; one record stays one record. *Cost:* none.
2. **The ERV shows no use:** its use becomes "Bible text", as the mockup drew it ("Easy-to-Read Version", nothing after it); "(ERV)" repeats the tag the reader shows. *Cost:* one string back.
3. **The uses are the line's own words, in `Credits`:** every use not "Bible text" is lower case after the middle dot: AMP "the file labelled AMP", KJV "and its book titles", BSB "section headings", OpenBible.info "cross-references", Theographic "people, places, events and dictionary entries" (spec 4.2's words; the mockup's shorter "people, places, events" is not used), Literata and Source Serif 4 "reading typeface", 3dicons "the app icon's artwork", BibleProject "links to its book overview videos", holybooks "the texts' file layout", GRDB.swift "reading the Bible database". `Credit.shownUse` is nil exactly for "Bible text". *Cost:* wording.
4. **About uses no fact list.** Spec 4 has none; the head is `LibraryPageTitle(appName, subtitle: nil)` (the page face, Light, `.largeTitle`: project 2's title, defining nothing new) with the version line under it in `.callout` `ink.secondary`, `xxs` apart, one VoiceOver element with the header trait. `FactList`'s doc comment loses "and Settings › About". *Cost:* none.
5. **The phone's About sits on `paper.page`; the Mac's has no fill** (spec 4.2's call on the Mac). On the phone a pushed plain page sits on the system's white, where an opened row on `paper.overlay` (#FAFCFE) would show no step; the phone's Library pages already sit on `paper.page`. `#if os(iOS)` `.background(Color.paperPage)`. On the Mac the opened row's step against the Settings window's own background is checked in the Dark render; if it does not show, the fix wave takes `paper.panel` for the opened row on the Mac. *Cost:* the phone's About is not the grey of its sibling forms (it is not a form either).
6. **One text edge on the About page:** the column is inset `lg`; the head, the group labels and the lines all carry `sm` across, so a closed line's text, an opened row's text and the labels share one leading edge (the mockup's negative margin, without one). A line is padded `xs` down when closed and `sm` when open. *Cost:* none seen.
7. **A line** (`CreditLineView`): `chevron.right` (`.caption`, `ink.tertiary`, `xs` before the name, its column a `@ScaledMetric(relativeTo: .caption)` width so the names align open or closed), the name `.body` `ink.primary`, " · " and the use `.callout` `ink.secondary` when there is one, the licence trailing `.callout` `ink.secondary`; `ViewThatFits(in: .horizontal)` between that one line and the same with the licence under the name. The whole line is `versePanelRowAction { toggle }` (so the ring is on the radius-`md` shape, Space and Return toggle, VoiceOver hears a button), one element: label `CreditLine.spoken`, value "Collapsed" or "Expanded". The opened block (notice selectable, the link, then "Licence text" for a file or the licence's name as a link) sits under the line inside the same `paper.overlay` radius-`md` background; the licence text's own line is a second `versePanelRowAction` with its own chevron and value. The chevron turns by `rotationEffect(.degrees(open ? 90 : 0))`, animated `.snappy` and the block's opacity likewise, through the scoped `animation(_:body:)` so no frame animates; a cut under Reduce Motion. Several lines may be open; nothing is remembered. An internal `AboutView(info:opened:licenceOpened:)` (both `Set<String>` of credit ids, default empty) exists for renders only. The chevron symbols carry `.accessibilityLabel` in their chain (impeccable-lint); the line's own label is what VoiceOver reads.
8. **About's tests are pure.** A SwiftUI hosting view's accessibility tree is not read by any test in this repository; `CreditLine` carries the words and parts, and VoiceOver on the page is on Matt's list.
9. **The day heading's words:** "Today", "Yesterday", else Foundation's `weekday(.wide).day().month(.wide)` in the reader's locale, with `.year()` when the day's year is not `now`'s. A day after today (a clock ahead on another device) is titled by its date, at the top as newest. Days are the model's calendar days of `modifiedAt`. *Cost:* wording.
10. **The day sections live beside the book sections:** `NotesBrowserModel.days` (empty under `.reference`), `groups` (`sections` by passage, `days` by date), and `visibleIDs` reads `groups`. `sections` stays books only, so `entriesCoverNotesHighlightsAndBookmarksNewestFirst`'s `sections.isEmpty` stands. The model takes `calendar:` and `locale:` (defaults `.current`) beside its `now:`. *Cost:* none.
11. **A heading** (`NotesGroupHeading(title:count:spoken:)`, both apps): the title `.headline` `ink.primary`, the count trailing `.callout` `ink.secondary` `.monospacedDigit()`; one VoiceOver element, "Today, 2 notes", header trait (spec 9's wording left to the builder). The count's word by the filter (spec 5.1; "item", "note", "highlight", "bookmark", "conversation", "kept version", plural past one). On the Mac: `md` above (`xs` above the first, which with the stack's own `xs` makes 16), `xxs` below, `sm` across.
12. **The rule between groups** is a `HairlineRule` the stack's full width (as today's), directly under a group's last row (whose own `sm` is the space above it); the next heading's `md` follows. It replaces the 0.5 pt `Rectangle` and its `accessibilityHidden` (SwiftLint 71 → 69). *Cost:* width only tells it from a note's hairline.
13. **The hairline between notes** is its own view between two rows of one group (spec 9's choice): `HairlineRule` inset `sm` both sides, shown unless either neighbour is the selected row (`NotesBrowserList.showsRule(above:below:selected:)`), its opacity changing with the wash (`.snappy`, a cut under Reduce Motion). The `LazyVStack`'s spacing goes from `xxs` to 0; the stack keeps its `xs` padding.
14. **`NotesBrowserView.row(_:)`'s modifiers are not changed, byte for byte** (`:197-223`: the content shape, click, double-click, right-click hook, context menu, traits, actions, id); only the `NotesBrowserRow(…)` call above them gains `parts:` (Task 6). Each task reviewer that sees `NotesBrowserView.swift` in the diff confirms it; impeccable-lint's `onTapGesture` finding there stays.
15. **The row's layout follows the mockup:** the marker leads the reference line (its column a scaled 14 pt, now `relativeTo: .body`), and the quote, the note and the mark start at the row's leading text edge under it, as the phone's row does. Line 1 is `HStack(alignment: .firstTextBaseline, spacing: xs)`: marker, title, (a conversation's place), tag, `Spacer(minLength: xs)`, the time or date. Lines are `xs` apart; padding `sm` all round (`sm` down, from `xs`).
16. **The row's time and words:** under a day heading the time (`.dateTime.hour().minute()`, "8:14 AM"), under a book heading the date as today (`.dateTime.month(.abbreviated).day().year()`, "Nov 18, 2026"), both in the model's calendar's time zone and locale. VoiceOver's label puts it last: "Note, John 15:4, 8:14 AM"; "Note, John 15:5, 2 versions, Nov 20, 2026"; "Conversation, Mark 4, Outline: Mark 4, 9:03 PM".
17. **The quote by kind:** a highlight's words (noted or not), a note's anchor words, a bookmark's label, a kept version's words; two lines; on `Color(markup:)` with `ink.primary` when coloured, on nothing in `ink.secondary` when not. A conversation shows no quote; its last turn's line is line 3 (`.callout` `ink.primary`, two lines, plain). A chapter note has none.
18. **The preview across blocks, and headings at the row's size:** `NoteMarkdown.blocks(_ body:, headingsAtTextSize: Bool = false)`: with `true`, a heading's runs carry no font (they take the row's size and weight). `NoteBodyText` with `previewLines` joins those blocks with "\n" into one `Text`, links as each block is linked today, capped at `previewLines` (the Mac's row passes 3). The phone's `noteBody(for:)` takes `blocks(entry.body, headingsAtTextSize: true).first` (its first block and two lines, as today). Every other `NoteBodyText` and `NoteMarkdown` caller (the column's rows, the phone's note sheet, the versions view, the assistant) keeps `.title3` headings. *Cost:* none.
19. **The marker symbols take `.accessibilityLabel(kindName)`** (read nowhere: the row's own label replaces its children), clearing impeccable-lint's four in `NotesBrowserRow.swift` (27 → 23). *Cost:* none.
20. **The phone's book headings are unchanged** (title only, no count): spec 5.5, "The day headings are the tab's only change." Its day headings use `NotesGroupHeading` in the `Section` header. *Cost:* by passage the phone has no counts while the Mac has them; one line to add.
21. **The phone's list becomes renderable:** its `Section`s move into `PhoneNotesGroups<Row: View>(model: NotesBrowserModel, row: (NotesBrowserEntry) -> Row)` in `PhoneNotesScreen.swift`, and the row's label into `static func markRow(for entry: NotesBrowserEntry) -> PhoneMarkRow` (internal), so a render hosts the groups and rows without the screen's models. Behaviour unchanged.
22. **A window left open across midnight** keeps yesterday's "Today" until the model rebuilds (on becoming key, a filter, a search, a sort or a change). *Cost:* a stale heading until the window is used.
23. **The behaviour is pinned before anything changes** (Task 1): hosted tests of the Notes window on a made-up in-memory store pass on today's code and are not edited afterwards. Key events are sent as `PlanBenchmarkTests.choosingEachWeekInTurn` sends them. A click is tried at a row's frame read from the hosting view's accessibility elements; if SwiftUI's tap gestures or its elements do not answer in an offscreen window, the click tests are dropped with the reason in the report, and the click, double-click and right-click rest on Departure 14 and `SecondaryClickHookTests`, with a pointer pass on Matt's list. The delete dialog is driven as far as an offscreen window allows (the sheet's presence; its default button by Return); past that, the model's delete and undo tests stand.
24. **The live passes** (keys only, the handover's Mac rules) are launched with argument-domain values so nothing is written: `-settingsTab about` for About, `-notesBrowserSort reference` for the passage sort. In the Notes window the controller presses ↑ ↓ and Tab only: Return moves the reader (it writes the reading position, a synced preference) and Delete would touch Matt's notes. In the simulator: Settings › About by taps; the Notes tab looked at only, no row tapped (a tap moves the reader, and the simulator's synced settings reach Matt's Debug apps), no swipe. A click, a double-click, a right-click, Return and Delete with ⌘Z in the Notes window, with his own notes, are Matt's.
25. **Speed (spec 5.6):** one pure benchmark of `NotesBrowserQuery.days` over 2,000 made-up entries across 400 days, its bound 1.5 × the measured median rounded up to 1 ms; the window with thousands of rows stays unmeasured (the backlog's line stays).

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-11-ui-improvements`, branch `milestone-11-ui-improvements`. Never push or merge; never commit to `main`.
- Git: `/usr/bin/git -C <worktree>`, one git command per Bash call, no `cd … &&`, loops or shell variables. Every commit message ends with the `Co-Authored-By:` line your session gives you, as a second `-m`.
- `rtk` shortens command output; `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time; implementers dispatch no subagents. Rules: `docs/superpowers/process/implementer-rules.md`, `reviewer-rules.md`.
- **Implementers never launch, quit, relaunch or send keys to the Mac Debug app or the simulator's app.** The live passes are the controller's (Departure 24).

**Matt's data**
- **Matt's notes are off limits for writing:** no note, highlight, bookmark, conversation or kept version is created, edited or deleted in the `.dev` store, a `-storeName` stand-in or the simulator. Every test and render uses an in-memory `MarkupContainer` with made-up notes.
- Never touch the Release apps, `Scripts/install-app.sh`, `/Applications`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. **No test writes `UserDefaults.standard`:** a model in a test takes `UserDefaults(suiteName: "<Suite>-\(UUID().uuidString)")!`, removed at the end. No test writes the clipboard or the network.

**What is stored (spec 6)**
- Nothing new. No stored value, preference or synced record changes. The Notes window's sort, filter and "How far back" keep their keys (`notesBrowserSort`, `notesBrowserFilter`, `notesBrowserTimeFilter`). About remembers nothing.

**The spec's values (verbatim)**
- **About's page (4.2):** "No longer a `Form`. A plain scrolling page with no fill of its own … Its column is at most a scaled 520 pt and `lg` (24) inset, as a Library page is." The head: the app's name in the page face, Light, at the Library title's size; the version line ("Version 1.0 (42)") in `.callout` `ink.secondary` beneath; one VoiceOver element. Three sections under `GroupLabel`, `md` (16) above each label: Scripture (ESV, NASB, AMP, ERV, ASV, KJV, WEB, CPDV); Study data (Berean Standard Bible, OpenBible.info, Theographic Bible Metadata); Typefaces, icon, videos and software (Literata, Source Serif 4, 3dicons, BibleProject, bobuk/holybooks, GRDB.swift).
- **A line (4.3):** closed: `chevron.right` (`.caption`, `ink.tertiary`), the name `.body` `ink.primary`, the use after a middle dot in `.callout` `ink.secondary` where it is not plain Bible text, the catalogue's licence string trailing in `.callout` `ink.secondary`; "where the row is too narrow … the licence moves under the name (`ViewThatFits`); nothing truncates." Rows `xs` (8) vertical padding, no rule, no fill at rest. Open: a click anywhere on the line, or Space or Return; the chevron turns down (a cut under Reduce Motion, else `.snappy` on the chevron's rotation and the block's opacity, never on its frame); the opened row on `paper.overlay` at radius `md` (6), padded `sm` (12), no stroke, showing the notice (`.callout` `ink.secondary`, selectable), the link (`.callout` `accent`, without "https://"), and for a licence file "Licence text" opening `LicenseText.reflowed` in `.caption` `ink.secondary`, or for a licence link the licence's name as a link in the accent. Several open at once; the page opens with every row closed. VoiceOver: one element, a button, "English Standard Version, Copyright", value "Collapsed" or "Expanded"; the notice and link reachable after it; the link is a link. Keyboard: Tab reaches each line; Space or Return opens and closes; the link and "Licence text" take Tab stops when open; the ring on the line's rounded shape (radius `md`).
- **What stays (4.4):** every source, notice, link and licence text word for word; no "Used by permission"; the Library's credit line unchanged.
- **Groups (5.1):** by date, notes under the day of `modifiedAt`, newest day first, "Today", "Yesterday", then the weekday and date, the year added when not this year, in the reader's region's order; by passage, the book headings of `NotesBrowserQuery.sections`. A heading: title `.headline` `ink.primary` leading, count `.callout` `ink.secondary` trailing, monospaced digits, header trait, never selected, `md` above, `xxs` below; the count's word follows the filter (All "items", Notes "notes", Highlights "highlights", Bookmarks "bookmarks", Threads "conversations", Kept versions "kept versions"; singular for one). Between groups a 1 pt `ink.rule`, none before the first. The keyboard walks rows across groups in order; a heading is not a stop.
- **The row (5.2):** `sm` (12) padding across and down. (1) the marker (10 pt dot with its 0.5 pt `ink.rule` keyline; `note.text`; `bookmark.fill` in the accent; `sparkles` in plum; the kept-version symbol), the reference `.body` semibold `ink.primary`, the tag `.caption2` semibold `ink.secondary`, trailing the time (or the date under a book heading) in `.caption` `ink.tertiary`, monospaced digits. (2) the marked words in `pageFace.quoteFont()`, `ink.primary`, on the mark's colour, up to two lines; colourless on no fill in `ink.secondary`; `xs` above. (3) the note via `NoteBodyText`, `.callout` `ink.primary`, up to three lines across blocks, a heading at the row's own size and weight; `xs` above. (4) the versions mark, `xs` above. By kind: a highlight with no note 1 and 2; a bookmark 1 and its quoted words when it has them; a chapter note 1 and 3; a conversation its title in place of the reference (the reference after it unless the title begins with it) and its last turn's first line as 3, `ink.primary`, two lines; a kept version its passage, words on their colour, text and mark.
- **Between rows (5.3):** a 1 pt `ink.rule` hairline inset `sm` from both edges between two notes of a group, none above a group's first or below its last; no other space; the selection wash (`accent.wash`, radius `md`) covers the selected row's padded area and hides the hairlines either side.
- **What stays (5.4):** one keyboard stop, ↑ ↓ Return Delete, a click selects, a double-click opens in the reader, right-click and Control-click select before the menu, Delete confirms and is undoable, the selection moves to the note that took its place, the filter, "How far back", the search field, Export, the kept-version rows under their own filter, VoiceOver's selected trait and "Note, John 15:4" labels (now with the row's time or date).
- **The phone (5.5):** by date, the same day headings as `Section` headers in the plain `List`; by passage, the book headings it has today; `PhoneMarkRow`'s anatomy unchanged; separators the system's, tinted `ink.rule`; swipes, tap and menus unchanged.
- **Speed (5.6):** the day grouping is made once per rebuild in the model, never in a row's body; each row stays its own `View` in the lazy stack.

**Behaviour that must not change, and its tests (each runs green after every task; none is edited)**
- `NotesBrowserModelTests`: `arrowKeysMoveTheSelectionAndStopAtTheEnds`, `arrowKeysFollowTheGroupsWhenSortedByReference`, `fromNoSelectionDownIsFirstAndUpIsLastInBothSorts`, `afterAFilterHidesTheSelectionDownSelectsTheFirstListedRow`, `movingWithNothingToShowSelectsNothing`, `deletingTheSelectedRowSelectsItsSuccessor`, `deletingAnotherRowKeepsTheSelection`, `aFilterThatHidesTheSelectionClearsIt`, `deletingAThreadFromTheBrowserIsUndoable`, `deletingAnEntryReloadsTheListAndNotifies`, `targetForAnEntryCarriesTranslationAndHighlight`, `aRowDeletedElsewhereDisappearsAndItsActionsDoNothing`, `theKeptVersionsFilterListsNotesWithOneAndTextsWithNoNote`, `deletingATextWithNoNoteDiscardsItUndoably`, `theDeleteDialogDiscardsAKeptVersion`, `aDiscardAndItsUndoReachTheVersionsView`, `entriesCoverNotesHighlightsAndBookmarksNewestFirst`, `referenceSortProducesSectionsAndPersists`; `NotesBrowserFilterStyleTests.theFilterIsSegmentedOnlyWhenItFits`; `SecondaryClickHookTests` (three); Task 1's `NotesBrowserWindowTests`.

**UI rules**
- `CLAUDE.md`'s three rules; read `PRODUCT.md` and `DESIGN.md` first; `/impeccable-swift` for every UI change, its command named in each task. Palette tokens only; `AppSpacing`/`AppRadius` by name; `@ScaledMetric` for sizes tied to text (the dot, the marker column, the 520 pt column, the chevron's gap); no card, no glass, no shadow; no `.font(.system(size:))`. A rule is `HairlineRule`.
- **Checkers, from the worktree root:** `swiftlint lint --config tools/.swiftlint.yml`; `tools/impeccable-lint/.build/release/impeccable-lint Packages/ScriptureKit/Sources/ScriptureUI Apps`; `swift tools/asset-catalog-checker/check.swift Apps/Mac/ReadingThroughScripture/Assets.xcassets`. Baseline 71, 27, 0; no total ever rises above it, and a task adds no finding in a file it touches or creates. Expected: SwiftLint 69 from Task 7, impeccable-lint 23 from Task 6.

**Tests**
- Swift Testing. Pure tests carry no platform guard; a test that hosts a view is `@MainActor`, in a `.serialized` suite, `#if os(macOS)` for `NSHostingView`, `#if os(iOS)` for `TestWindow`. Compare mapped ids or strings in `#expect`; no mutating call inside `#expect`.
- **Locale and time in tests:** a fixed `Calendar(identifier: .gregorian)` with `TimeZone(identifier: "America/Chicago")!`, `Locale(identifier: "en_US")` unless a test names en_GB, and `now` = 2026-11-23 09:30 local (a Monday). Never the machine's.
- `swift test` cannot load the package's Color Sets; tokens come from `Palette.swift`.
- Known flake: `ReaderBenchmarkTests.scrollingWhileTheThumbRevealsKeepsTheFrameCost` and other timing benchmarks under full-suite load; rerun alone.
- Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (`--filter <Suite>` while iterating). iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`. Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`. One at a time.

**Renders (every UI task)**
- **Mac:** a temporary `@MainActor` test, `T/AboutNotesRenderScratch.swift` (`#if os(macOS)`), offscreen: `NotesBrowserView` on `NotesBrowserFixture` in an `NSHostingView` at 1,100 by 760 (the window's opening width; the toolbar is not drawn there), `.followsPageFace()`; `AboutView(info:opened:licenceOpened:)` at 560 by 1,600 with a made-up `info` ("Bible Carrel", "1.0", "42"). Light and Dark by the host's `NSAppearance`; Sepia by `SepiaMode.set(true)` and `.followsSepia()`, reset after. PNGs to `RENDERS`.
- **Phone:** a temporary test, `T/PhoneAboutNotesRenderScratch.swift` (`#if os(iOS)`): `TestWindow.make(frame:)` 402 by 1,600, `window.layer.render(in:)` (never `drawHierarchy`), Light and Dark by `overrideUserInterfaceStyle`, Sepia as above, `.environment(\.dynamicTypeSize, .large)` and `.accessibility3`; run with `-only-testing:ScriptureUITests/PhoneAboutNotesRenderScratch`.
- Open every PNG with Read. **Delete both scratch files before committing.** Say what a render cannot show: the toolbar, the pointer, a click, focus and its ring, a key, VoiceOver, motion.

## Review Focus

The cases a person meets that spec 10's list does not pin, most likely first; each has its test in the owning task.

1. **Deleting the last note of a day while it is selected:** the day's heading goes, and the selection lands on the first note of the next day, as it lands on the note that took its place today (Task 4, `deletingADaysLastNoteSelectsTheNextDaysFirst`).
2. **A filter or a search while sorted by date:** the days and their counts follow what is listed, a day with nothing left has no heading, and the count's word follows the filter (Task 4, `theDaysFollowTheFilterAndTheSearch`).
3. **The selection at a group's edge:** with the first or last row of a group selected, no hairline shows beside it and the group rule stays (Task 7, `theHairlinesHideBesideTheSelectionOnly`).
4. **The window used across midnight:** the next rebuild after midnight moves "Today" (Task 4, `theDaysAreMadeFromTheModelsClock`).
5. **A note that is only a heading, or whose heading carries a reference:** it previews at the row's size and keeps its link (Task 5, `aHeadingOnlyNotePreviewsAtRowSizeWithItsLink`).

---

### Task 1: The Notes window's behaviour, pinned on today's code

**Run:** implementer **Opus**; task reviewer **Opus** (the window's focus, keys and selection). Not a UI change; the review runs the three checkers.

**Files:**
- Create: `T/NotesBrowserFixture.swift`, `T/NotesBrowserWindowTests.swift`

**Interfaces:**
- Produces: `@MainActor final class NotesBrowserFixture` (cross-platform) with `let store: MarkupStore`, `let calendar: Calendar`, `let locale: Locale`, `let now: Date`, `let defaults: UserDefaults` (a removed-at-`deinit` suite), the made-up entries' ids by name (`abide`, `romans`, `stillWaters`, `provide`, `ezraChapter`, `poorInSpirit`, `johnThree`, `vine`, `orphan`, `mark4`), and `func model() -> NotesBrowserModel` (`NotesBrowserModel(store:defaults:now:)`; Task 4 adds `calendar:` and `locale:` here). In local time (Chicago), modified at:
  - `abide`: yellow highlight John 15:4 "Abide in me, and I in you." with note "Abiding is not effort but staying put. Compare 1 John 2:28 on confidence at his coming.", 2026-11-23 08:14;
  - `romans`: blue highlight Romans 8:28 "for those who love God all things work together for good" with note "Who are \"those who love God\"? Verse 29 answers: those he foreknew. The promise is to the called.", 07:52;
  - `stillWaters`: green highlight, no note, Psalm 23:2 "He leads me beside still waters.", 2026-11-22 21:03;
  - `vine`: John 15:5 note with one kept version (made as `PhoneVersionsFixture.keep` makes one), 2026-11-20 10:00; `orphan`: a kept version whose note is gone, John 15:9, written 2026-11-20 09:00;
  - `provide`: bookmark Genesis 22:8 labelled "The Lord will provide", 2026-11-18 06:40; `ezraChapter`: chapter note Ezra 4, body "# Discouragement\n\nOpposition as discouragement.\n\n- verse 4\n- verse 5", 06:31; `johnThree`: colourless highlight John 3:16 with note "For God so loved", 00:01;
  - `poorInSpirit`: colourless highlight Matthew 5:3 with note "# Blessed (Luke 6:20)\nThe kingdom is theirs.", 2026-11-17 23:59;
  - `mark4`: a conversation on Mark 4 (chapter scope) titled "Outline: Mark 4", last turn "The parable of the sower comes first.", updated 2025-11-14 21:03.
  Dates are set after creation and saved, as `NotesBrowserModelTests.seed` sets them.

- [ ] **Step 1: Write the tests** in `T/NotesBrowserWindowTests.swift` (`#if os(macOS)`, `@MainActor @Suite(.serialized) struct NotesBrowserWindowTests`): `NotesBrowserView(model:onShow:)` on the fixture's model (sort `.date`), `onShow` appending to a local array, in an `NSHostingView` at 1,100 by 760 in an offscreen `NSWindow` made as `PlanBenchmarkTests`' is, laid out and run 0.2 s; keys by keyCode (↓ 125, ↑ 126, Return 36, Delete 51) through `window.sendEvent`, the run loop turned after each.
  - `downAndUpWalkTheRowsInTheOrderShown`: with nothing selected ↓ selects `visibleIDs[0]`, ↓ `[1]`, ↑ `[0]`; `selectedID = nil`, ↑ selects the last; ↓ at the last keeps it. Then `sort = .reference`, the same walk over the new `visibleIDs`.
  - `returnShowsTheSelectedRowInTheReader`: ↓ ↓ Return: `shown == [model.target(for: visibleIDs[1])]`; with nothing selected Return shows nothing.
  - `deleteAsksBeforeAnythingGoes`: ↓, Delete: `window.attachedSheet != nil`, `model.entries.count` unchanged. Then Return to the sheet: if it reaches the dialog's button, one entry fewer, the selection on the row that took its place, and `model.undoManager?.undo()` restores the count; if not, the test stops at the sheet and the report says so (Departure 23).
  - `aClickSelectsAndADoubleClickShows` (Departure 23): the third row's frame from the hosting view's accessibility elements (its label begins "Highlight, Psalm 23:2"), a left click at its centre selects it and focuses the list (a following ↓ selects the fourth); a double-click shows it. Dropped, with the reason, if it cannot pass on today's code.
  - `keptVersionsListUnderTheirOwnFilter`: `filter = .keptVersions`: `visibleIDs` holds `vine` and `orphan` only; ↓ ↓ Return shows `model.target(for: orphan)` as today's code gives it (pin today's value: nil shows nothing).
- [ ] **Step 2: Run them on today's code and see them pass** (`--filter NotesBrowserWindowTests`), three runs in a row; a flaky one is fixed or dropped with the reason now, never later.
- [ ] **Step 3: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers (71, 27, 0).
- [ ] **Step 4: Commit:** "The Notes window's keys, Return, Delete and clicks pinned on today's code, over a made-up store".

---

### Task 2: The credits in three sections, and what a line shows

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change.

**Files:**
- Modify: `SUI/Credits.swift`
- Create: `SUI/CreditLine.swift`
- Test: `T/CreditsTests.swift`

**Interfaces:**
- Produces:
  - `Credit.Section`: `case scripture = "Scripture", studyData = "Study data", typefacesAndSoftware = "Typefaces, icon, videos and software"` (Departure 1); each credit's `section` set accordingly; the uses as Departures 2 and 3; `public var shownUse: String? { use == "Bible text" ? nil : use }`. The type's doc comment names the three.
  - `struct CreditLine: Equatable { enum Part: Equatable { case notice(String), link(address: String, url: URL), licenceText, licenceLink(name: String, url: URL) }; let credit: Credit; var name: String; var use: String?; var licence: String; var spoken: String; func value(isOpen: Bool) -> String; var opened: [Part]; static func address(_ url: URL) -> String }`. `spoken`: name, use (when there is one) and licence joined by ", ". `opened`: the notice, the link, then `.licenceText` when `Credits.licenseText(for:)` has text, else `.licenceLink` when `licenseLink` is set, else nothing.

- [ ] **Step 1: Write the failing tests** in `CreditsTests`:
  - `theCatalogueIsTheAppendixAndClaimsNoPermission`: its section line becomes `Credit.Section.allCases.map(\.rawValue) == ["Scripture", "Study data", "Typefaces, icon, videos and software"]`; the rest stands.
  - `aboutListsThreeSectionsInOrder`: `entries(in: .scripture).map(\.id) == ["esv", "nasb", "amp", "erv", "asv", "kjv", "web", "cpdv"]`; `.studyData` `["bsb", "openbible", "theographic"]`; `.typefacesAndSoftware` `["literata", "sourceSerif4", "3dicons", "bibleProject", "holybooks", "grdb"]`; the three together are `Credits.all.map(\.id)` (17, each once).
  - `theUseAfterTheDot`: `shownUse` by id as Departures 2 and 3 list; `Credits.all.filter { $0.shownUse == nil }.map(\.id) == ["esv", "nasb", "erv", "asv", "web", "cpdv"]`, all `.scripture`.
  - `aLinesWordsForVoiceOver`: `CreditLine(credit: esv).spoken == "English Standard Version, Copyright"`; KJV "King James Version, and its book titles, Public domain"; Literata "Literata, reading typeface, SIL OFL 1.1"; `value(isOpen: false) == "Collapsed"`, `true` "Expanded".
  - `whatAnOpenedLineShows`: ESV `[.notice(esv.notice), .link(address: "crossway.org/permissions", url: esv.link)]`; Literata ends `.licenceText`; OpenBible.info ends `.licenceLink(name: "CC BY 4.0", url: https://creativecommons.org/licenses/by/4.0/)`; exactly `["literata", "sourceSerif4", "holybooks", "grdb"]` have `.licenceText` and `["openbible", "theographic"]` `.licenceLink`.
  - `noWordSaysUsedByPermission`: no credit's name, use, notice or licence contains "used by permission" (case-insensitive).
- [ ] **Step 2: Run them and see them fail** (`--filter CreditsTests`).
- [ ] **Step 3: Implement.** `AboutView` still compiles (its `ForEach` over `allCases` now draws three sections); no view change here.
- [ ] **Step 4: Run them and see them pass,** `theReadmeAcknowledgesEverySource` among them.
- [ ] **Step 5: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers.
- [ ] **Step 6: Commit:** "About's sources in three sections, their uses worded for one line".

---

### Task 3: Settings › About as a colophon

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (the page, the line, the opened block) then `typeset`. Review: `/impeccable-swift audit` on `AboutView` and `CreditLineView`, plus the three checkers.

**Files:**
- Modify: `SUI/AboutView.swift` (the page and `CreditLineView`; `LicenseText` unchanged), `LIB/FactList.swift` (the doc comment only, Departure 4)
- Test: `T/CreditsTests.swift`

**Interfaces:**
- Consumes: `CreditLine`, `Credit.Section`, `Credit.shownUse` (Task 2); `LibraryPageTitle`, `GroupLabel`, `versePanelRowAction`.
- Produces: `public struct AboutView: View` with `public init(info: [String: Any]? = Bundle.main.infoDictionary)` and the internal `init(info:opened:licenceOpened:)` (Departure 7), which store `let initiallyOpened: Set<String>` and `let initiallyLicenceOpened: Set<String>` as the seeds of the lines' `@State`; `nonisolated static func page() -> [(title: String, lines: [CreditLine])]` (what the body draws, section by section); `appName(info:)` and `versionLine(info:)` unchanged. `private struct CreditLineView: View` (one line and its opened block, Departures 6 and 7).

- [ ] **Step 1: Write the failing tests** in `CreditsTests`: `aboutDrawsThreeSectionsOfLines`: `AboutView.page().map(\.title) == ["Scripture", "Study data", "Typefaces, icon, videos and software"]`, line counts `[8, 3, 6]`, the ids in Task 2's order; `aboutOpensWithEveryLineClosed`: `AboutView(info: nil).initiallyOpened.isEmpty && AboutView(info: nil).initiallyLicenceOpened.isEmpty`. `aboutNamesTheAppAndItsVersion` stands.
- [ ] **Step 2: Run it and see it fail.**
- [ ] **Step 3: Implement** per the spec's values and Departures 4 to 7: a `ScrollView` of a `VStack(alignment: .leading, spacing: 0)`: the head, then each section's `GroupLabel` (`md` above, `xxs` below, `sm` across) and its lines; the column `.frame(maxWidth: maxWidth, alignment: .leading)` (`@ScaledMetric(relativeTo: .body) maxWidth = 520`) then `.frame(maxWidth: .infinity, alignment: .leading)`, padded `lg`; on iOS `.background(Color.paperPage)`.
- [ ] **Step 4: Run it and see it pass.**
- [ ] **Step 5: Render:** the Mac: closed (Light, Dark, Sepia); NASB opened; Literata opened with "Licence text" opened; OpenBible.info opened (its licence link); the phone at `.large` closed and with NASB opened (Light, Dark, Sepia), and at `.accessibility3` closed. Check: the title the size and face of About-of-a-book's; the labels in the group-label voice; one leading edge for head, labels and lines; the licence on the trailing edge, and under the name at `.accessibility3`, nothing truncated; the opened row a visible tonal step with no stroke on both platforms (Departure 5); the notice `.callout`; no "https://". Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (no new finding in `AboutView.swift`).
- [ ] **Step 7: Commit:** "Settings › About as a colophon: the app's name as a title, three sections, one line per source that opens in place".

**Controller live pass:** the Mac Debug app launched with `-settingsTab about`; ⌘, ; Tab to the ESV line (the ring on its rounded shape), Space opens, Space closes; Tab to Literata, Space, Tab past the link to "Licence text", Space; capture each by window id. The simulator: Settings › About, tap NASB and Literata, then "Licence text"; capture.

---

### Task 4: Day groups in the model

**Run:** implementer **Opus**; task reviewer **Opus** (`visibleIDs`, the selection after a delete, the keys' order). Not a UI change.

**Files:**
- Modify: `SUI/NotesBrowserEntry.swift` (`NotesBrowserQuery`), `SUI/NotesBrowserModel.swift`, `T/NotesBrowserFixture.swift` (`calendar:` and `locale:` into `model()`)
- Test: `T/NotesBrowserQueryTests.swift`, `T/NotesBrowserModelTests.swift`, `T/NotesBrowserWindowTests.swift` (one test added, none edited)

**Interfaces:**
- Produces:
  - `NotesBrowserQuery.days(_ entries: [NotesBrowserEntry], now: Date, calendar: Calendar, locale: Locale) -> [NotesBrowserSection]` (entries in date order; one section per calendar day of `modifiedAt`, in their order; id `"day-2026-11-23"` from the day's components; title `dayTitle`).
  - `NotesBrowserQuery.dayTitle(for day: Date, now: Date, calendar: Calendar, locale: Locale) -> String` (Departure 9).
  - `NotesBrowserQuery.countLabel(_ count: Int, filter: NotesBrowserFilter) -> String` ("2 items", "1 note", "3 highlights", "1 bookmark", "2 conversations", "1 kept version").
  - `NotesBrowserQuery.headingSpoken(_ section: NotesBrowserSection, filter: NotesBrowserFilter) -> String` ("Today, 2 notes").
  - `NotesBrowserModel.init(store:defaults:onChange:now:calendar: Calendar = .current, locale: Locale = .current)`; `public private(set) var days: [NotesBrowserSection]` (made in `rebuild()` beside `sections`, empty under `.reference`); `public var groups: [NotesBrowserSection]`; `visibleIDs` = `groups.flatMap(\.entries).map(\.id)`; `public let calendar: Calendar`, `public let locale: Locale` (the row reads them, Task 6).

- [ ] **Step 1: Write the failing tests:**
  - `NotesBrowserQueryTests.daysAreHeadedTodayYesterdayThenTheDate` (the suite's `entry` helper, Chicago, `now` 2026-11-23 09:30): entries at 2026-11-23 08:14 and 07:52, 2026-11-22 21:03, 2026-11-18 06:40, 2026-11-17 23:59, 2025-11-14 21:03: titles `["Today", "Yesterday", "Wednesday, November 18", "Tuesday, November 17", "Friday, November 14, 2025"]`, counts `[2, 1, 1, 1, 1]`, ids begin `"day-2026-11-23"`; en_GB titles of the third and last `"Wednesday 18 November"` and `"Friday, 14 November 2025"`; an entry dated 2026-11-24 10:00 is first, titled `"Tuesday, November 24"`.
  - `aMinuteEitherSideOfMidnightIsTwoDays`: 2026-11-17 23:59 and 2026-11-18 00:01 fall in `"day-2026-11-17"` and `"day-2026-11-18"`; two entries in the same second keep their date-sort order inside one day.
  - `theCountsWordFollowsTheFilter`: `countLabel` for 1 and 2 under each of the six filters (the words of the spec's values); `headingSpoken` "Today, 2 notes" under `.notes`, "Yesterday, 1 item" under `.all`.
  - `theBookSectionsAreUnchanged`: `sectionsGroupByBookInCanonOrder` stands; `days` of a reference-sorted list is never asked for (the model's `days.isEmpty` under `.reference`).
  - `NotesBrowserModelTests.theDaysAreTheGroupsByDate` (fixture): `groups.map(\.title) == ["Today", "Yesterday", "Friday, November 20", "Wednesday, November 18", "Tuesday, November 17", "Friday, November 14, 2025"]`, `visibleIDs == groups.flatMap(\.entries).map(\.id) == entries.map(\.id)`; `sort = .reference`: `groups == sections`, `days.isEmpty`.
  - `theDaysFollowTheFilterAndTheSearch` (Review Focus 2): `filter = .highlights` (noted highlights included): no 2025 group (a conversation), Today's count 2, "Wednesday, November 18"'s count 1 (`johnThree`; the bookmark and the chapter note gone); `filter = .bookmarks`: one group, "Wednesday, November 18"; `filter = .all`, `query = "kingdom"` then `applySearch()`: one group, "Tuesday, November 17".
  - `theDaysAreMadeFromTheModelsClock` (Review Focus 4): a model whose `now` is a mutable box at 2026-11-23 23:58; then 2026-11-24 00:02 and `reload()`: the first group's title goes from "Today" to "Yesterday".
  - `deletingADaysLastNoteSelectsTheNextDaysFirst` (Review Focus 1): select `stillWaters` (Yesterday's only row), `delete(id:)`: no "Yesterday" group; `selectedID == vine` (Friday's first).
  - `NotesBrowserWindowTests.downCrossesFromOneDayToTheNext`: `selectedID = romans` (Today's last), ↓ selects `stillWaters`, ↓ `vine`; ↑ from `stillWaters` selects `romans`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** `days` is built in `rebuild()` only.
- [ ] **Step 4: Run them and see them pass,** and every test in "Behaviour that must not change".
- [ ] **Step 5: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers.
- [ ] **Step 6: Commit:** "The Notes window's notes grouped by day when sorted by date, made once per rebuild from the model's clock".

---

### Task 5: A note's preview runs on across its blocks, headings at the row's size

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift typeset` on `NoteBodyText`'s preview. Review: `/impeccable-swift audit` on `NoteBodyText`, plus the three checkers.

**Files:**
- Modify: `SUI/NoteMarkdown.swift`, `SUI/NoteBodyText.swift`, `PH/PhoneNotesScreen.swift` (`noteBody(for:)` only)
- Test: `T/NoteMarkdownTests.swift` (new unless a suite of that name exists; then there)

**Interfaces:**
- Produces: `NoteMarkdown.blocks(_ body: String, headingsAtTextSize: Bool = false) -> [AttributedString]`; `NoteBodyText.preview(_ text: String, book: Book?, chapterCount: ((String) -> Int?)?) -> AttributedString` (`nonisolated static`: the blocks with `headingsAtTextSize: true`, each linked as `blocks(_:book:chapterCount:)` links them, joined by "\n"); with `previewLines`, `body` draws `Text(preview).font(font).foregroundStyle(Color.inkPrimary).lineLimit(previewLines)` (Departure 18). Without `previewLines`, unchanged.

- [ ] **Step 1: Write the failing tests:**
  - `aHeadingKeepsItsSizeOnlyOutsideAPreview`: `NoteMarkdown.blocks("# Heading\n\nText")[0].runs.first?.swiftUI.font == .system(.title3, weight: .semibold)`; with `headingsAtTextSize: true` every run's `swiftUI.font == nil`; the characters are the same both ways ("Heading").
  - `thePreviewRunsOnAcrossBlocks`: `String(NoteBodyText.preview("A short paragraph.\n\n- one\n- two\n- three", book: nil, chapterCount: nil).characters) == "A short paragraph.\n• one\n• two\n• three"`; of the fixture's `ezraChapter` body `"Discouragement\nOpposition as discouragement.\n• verse 4\n• verse 5"`.
  - `aHeadingOnlyNotePreviewsAtRowSizeWithItsLink` (Review Focus 5): `preview("# Blessed (Luke 6:20)", book: matthew, chapterCount: { _ in 24 })`: no run has a font; one run carries a `ReferenceLinker.scheme` link for Luke 6:20.
  - `#if os(macOS)` `@MainActor` `theMacsPreviewStopsAtThreeLines` (in a `.serialized` suite): `NoteBodyText(body, book: nil, font: .callout, previewLines: 3)` hosted at 400 pt wide for the six-line paragraph-and-list body above plus "- four\n- five": its `fittingSize.height` equals that of `Text("a\nb\nc").font(.callout)` hosted alike (± 1 pt); a two-line body is shorter.
  - `thePhonesNoteLineHasNoHeadingFont` (pure: the same rule `noteBody(for:)` calls): `NoteMarkdown.blocks("# Prayer\n\nFor the city", headingsAtTextSize: true).first` has no font; and `SearchResults`' `firstLine(of: "# Prayer")` stays "Prayer" (the spec's Search case, already plain).
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** `noteBody(for:)` takes `blocks(entry.body, headingsAtTextSize: true).first`.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** the Notes window (today's row, three lines now): `ezraChapter` and `poorInSpirit` with their headings at the row's size, Light. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "A note's preview runs on across its blocks, and a heading in it is set at the row's size, on the Mac and in the phone's Notes tab".

---

### Task 6: The fuller row

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` then `typeset`. Review: `/impeccable-swift audit` on `NotesBrowserRow`, plus the three checkers.

**Files:**
- Create: `SUI/NotesBrowserRowParts.swift`
- Modify: `SUI/NotesBrowserRow.swift`, `SUI/NotesBrowserView.swift` (only `row(_:)`'s call of `NotesBrowserRow`, to pass `parts`; the modifier chain untouched, Departure 14)
- Test: `T/NotesBrowserRowPartsTests.swift` (new)

**Interfaces:**
- Consumes: the model's `sort`, `calendar`, `locale` (Task 4); `NoteBodyText`'s preview (Task 5).
- Produces:
  - `struct NotesBrowserRowParts: Equatable { enum Note: Equatable { case markdown(String), lastTurn(String) }; var title: String; var placeAfterTitle: String?; var translationID: String?; var when: String; var quote: String?; var quoteIsFilled: Bool; var note: Note?; var versions: String?; var spoken: String; static func make(_ entry: NotesBrowserEntry, underDay: Bool, calendar: Calendar, locale: Locale) -> NotesBrowserRowParts }` (Departures 15 to 17; `spoken` per Departure 16; `kindName` and `versionsText` move here from the row).
  - `NotesBrowserRow(entry:parts:isSelected:versionsShown:undoManager:)`: draws `parts` (the marker from `entry.kind` and `entry.color`), `NoteBodyText(…, font: .callout, previewLines: 3)` for `.markdown`, `Text` two lines for `.lastTurn`; the quote `pageFace.settingMatches(AttributedString(quote), .callout, italic: true)` with `backgroundColor = Color(markup:)` when filled; `.accessibilityLabel(parts.spoken)`; the marker symbols per Departure 19. `row(_:)` passes `NotesBrowserRowParts.make(entry, underDay: model.sort == .date, calendar: model.calendar, locale: model.locale)`.

- [ ] **Step 1: Write the failing tests** in `T/NotesBrowserRowPartsTests.swift` (`@MainActor @Suite struct NotesBrowserRowPartsTests`, the fixture, `underDay: true` unless named):
  - `aNotedHighlight`: `abide`: title "John 15:4", tag "ESV" as the fixture sets, `when == "8:14 AM"`, quote "Abide in me, and I in you." filled, note `.markdown(…)`, no versions, spoken "Note, John 15:4, 8:14 AM".
  - `aHighlightWithoutANote`: `stillWaters`: quote filled, `note == nil`, spoken "Highlight, Psalm 23:2, 9:03 PM".
  - `aBookmark`: `provide`: quote "The Lord will provide" not filled, no tag, no note, spoken "Bookmark, Genesis 22:8, 6:40 AM".
  - `aChapterNote`: `ezraChapter`: `quote == nil`, note `.markdown`, spoken "Chapter note, Ezra 4, 6:31 AM".
  - `aColourlessAnchor`: `poorInSpirit`: quote not filled.
  - `aConversation`: `mark4`: title "Outline: Mark 4", `placeAfterTitle` per today's rule (the title begins with neither, so "Mark 4"), `quote == nil`, note `.lastTurn("The parable of the sower comes first.")`, spoken "Conversation, Mark 4, Outline: Mark 4, 9:03 PM".
  - `aNoteWithVersionsAndAKeptVersion`: `vine`: versions "2 versions", spoken "Note, John 15:5, 2 versions, 10:00 AM"; `orphan`: versions "Kept version", note `.markdown`, spoken "Kept version, John 15:9, 9:00 AM".
  - `underABookHeadingTheDate`: `abide` with `underDay: false`: `when == "Nov 23, 2026"`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement** per the spec's values and Departures 15 to 19.
- [ ] **Step 4: Run them and see them pass,** and `NotesBrowserWindowTests` unchanged.
- [ ] **Step 5: Render** the window (the list still as today's, rows new): all kinds, Light, Dark, Sepia. Check: the reference a step above the note; the time on line 1's trailing edge; the quote on its fill in each appearance; three lines of note at most; the conversation's line in full ink. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (impeccable-lint 23).
- [ ] **Step 7: Commit:** "The Notes window's row: the passage leads, then the marked words on their colour, then three lines of the note, and the time".

---

### Task 7: Headings, hairlines and the wash in the Notes window

**Run:** implementer **Opus**; task reviewer **Opus** (the list's focus stop, keys and scroll live in this view). `/impeccable-swift layout` then `polish`. Review: `/impeccable-swift audit` on `NotesBrowserView` and `NotesGroupHeading`, plus the three checkers.

**Files:**
- Create: `SUI/NotesGroupHeading.swift` (shared with the phone)
- Modify: `SUI/NotesBrowserView.swift` (`list` only)
- Test: `T/NotesBrowserRowPartsTests.swift` (the rule's tests), `T/NotesBrowserWindowTests.swift` (one added, none edited)

**Interfaces:**
- Consumes: `groups`, `countLabel`, `headingSpoken` (Task 4); the row (Task 6).
- Produces: `struct NotesGroupHeading: View { init(title: String, count: String, spoken: String) }` (Departure 11; no padding of its own); `enum NotesBrowserList { static func showsRule(above: UUID, below: UUID, selected: UUID?) -> Bool }` (in `NotesBrowserView.swift`). `list`: `ForEach(Array(model.groups.enumerated()), id: \.element.id)`: a `HairlineRule` before every group but the first (Departure 12), the heading padded per Departure 11, then the group's rows with a hairline between each two (Departure 13); `LazyVStack(alignment: .leading, spacing: 0)`; the focus, keys, delete command, scroll and focus-on-appear modifiers unchanged.

- [ ] **Step 1: Write the failing tests:**
  - `theHairlinesHideBesideTheSelectionOnly` (Review Focus 3): `showsRule(above: a, below: b, selected: nil)` true; `selected: a` false; `selected: b` false; `selected: c` true.
  - `NotesBrowserWindowTests.theKeysStillWalkAcrossHeadingsAndRules`: by date and by passage, ↓ from nothing through every row reaches `visibleIDs.last` in `visibleIDs.count` presses, each selecting the next id in order (a heading or a rule is never a stop).
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** The 0.5 pt `Rectangle` and its `accessibilityHidden` go (SwiftLint 69).
- [ ] **Step 4: Run them and see them pass,** and every test in "Behaviour that must not change", `NotesBrowserWindowTests` whole.
- [ ] **Step 5: Render** the window at 1,100 by 760 by date and by passage, Light, Dark, Sepia; `abide` selected (the wash over its padded area, no hairline beside it, the hairline under `romans` back); `stillWaters` selected (a group's only row: the group rules stay). Check: about five notes in the window; `xs` inside a note against `sm` + 1 + `sm` between; headings `md` above and `xxs` below; counts trailing in monospaced digits; the note hairline inset to the row's text, the group rule wider. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (SwiftLint 69, impeccable-lint 23).
- [ ] **Step 7: Commit:** "The Notes window's notes under day or book headings, a hairline between notes and none beside the selection".

**Controller live pass:** the Mac Debug app on this build; ⇧⌘N; ↓ through the first day into the next, ↑ back; capture by window id. Relaunched with `-notesBrowserSort reference`: ↓ across a book heading; capture. No Return, no Delete, no click (Departure 24). Relaunched without the argument at the end.

---

### Task 8: The phone's Notes tab under day headings

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift adapt` (the `Section` header). Review: `/impeccable-swift audit` on `PhoneNotesScreen` and `NotesGroupHeading` on iOS, plus the three checkers.

**Files:**
- Modify: `PH/PhoneNotesScreen.swift`
- Test: `T/PhoneVersionsTests.swift` (the iOS block) or a new `#if os(iOS)` suite in `T/PhoneNotesGroupsTests.swift`

**Interfaces:**
- Consumes: `groups`, `days`, `countLabel`, `headingSpoken` (Task 4); `NotesGroupHeading` (Task 7).
- Produces: `PhoneNotesGroups` and `PhoneNotesScreen.markRow(for:)` (Departure 21), with `static func headings(for model: NotesBrowserModel) -> [(title: String, count: String?)]` on `PhoneNotesGroups` (a book's count nil, Departure 20), which its body reads. By date each day is a `Section` with `NotesGroupHeading`; by passage the book `Section`s as today (Departure 20). Rows, separators, swipes and the tap unchanged.

- [ ] **Step 1: Write the failing test** (`#if os(iOS)`, `@MainActor`): `thePhonesGroupsAreTheModelsGroups`: on the fixture, `PhoneNotesGroups.headings(for: model)` (a static the view reads: `(title, count)?` per group, nil count for a book) by date `["Today" "2 items", "Yesterday" "1 item", …]` and by passage the book titles with nil counts; `markRow(for:)` of `ezraChapter` carries a body with no heading font.
- [ ] **Step 2: Run it and see it fail** (`-only-testing:ScriptureUITests/<Suite>`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and see it pass.**
- [ ] **Step 5: Render** (phone): `List { PhoneNotesGroups(model:) { PhoneNotesScreen.markRow(for: $0) } }.listStyle(.plain)` on the fixture, by date and by passage, Light, Dark, Sepia, `.large` and `.accessibility3`. Check: the day headings' title and count; the book headings as today; the rows as before but `#` headings at the row's size; separators full width. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "The phone's Notes tab takes the Mac's day headings when sorted by date".

**Controller live pass:** the simulator's Notes tab looked at, by date (if its store has notes; no row tapped, no swipe, Departure 24); capture.

---

### Task 9: Speed, and a polish pass

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift polish` over `AboutView`, `CreditLineView`, `NotesBrowserRow`, `NotesGroupHeading`, `NotesBrowserView.list` and `PhoneNotesScreen`. Review: `/impeccable-swift audit`, plus the three checkers.

**Files:**
- Modify: as the polish requires (only files this plan created or changed)
- Test: `T/NotesBrowserBenchmarkTests.swift` (new)

- [ ] **Step 1: Add `NotesBrowserBenchmarkTests.groupingTwoThousandNotesByDay`** (pure): 2,000 made-up entries over 400 days, date-sorted once in `prepare`; the median of `NotesBrowserQuery.days(…)` by `ReaderBenchmarkTests.median`; `#expect(sections.count == 400)` and the bound per Departure 25, set after three runs alone, the figures in its comment and the report.
- [ ] **Step 2: Polish** per the command: the About lines' rhythm and the opened block's spacing; the chevron's alignment to the name's first baseline; the Notes row at the widths spec 9 names (renders at 980, 1,100 and 1,200 pt wide); Increase Contrast where `Palette` has the variants; Reduce Motion (the chevron and the hairline a cut). Fix within the spec; anything outside it goes to the backlog line list for Task 10.
- [ ] **Step 3: Render the whole set** (spec 10): the Notes window by date and by passage, Light, Dark, Sepia, mixed kinds, the selected row; About closed, one source open, one licence text open, the phone at `.accessibility3`; the phone's Notes tab by date. Delete the render files.
- [ ] **Step 4: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (record the totals).
- [ ] **Step 5: Commit:** "Notes grouped by day measured; About's and the Notes window's spacing settled".

---

### Task 10: The record

**Run:** implementer Sonnet; task reviewer Sonnet. No view changes; the review checks each document against the code as built and runs the three checkers for the final counts.

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, `docs/superpowers/specs/2026-11-23-milestone-11-about-and-notes-design.md` (section 11), `docs/BACKLOG.md`

- [ ] **Step 1: DESIGN.md** (spec 7): **Navigation › About** (`:441`): rewritten for spec 4 as built (a plain page; the head `LibraryPageTitle` and the version line; three sections under group labels; one line per source, the use after a middle dot, the licence trailing and under the name when narrow; opening in place on `paper.overlay` radius `md`, padded `sm`; "Licence text" behind its own disclosure; VoiceOver and keyboard; the phone on `paper.page`). **Navigation › Notes browser** (`:444`): day headings by date, the heading and its count, the time in the row, the hairline between notes inset `sm`, the full-width rule between groups, the wash over the hairlines. **Components › Rows** (`:328-340`): the browser row's anatomy (Departures 15 to 18) beside the column's; the padding line (`:340`) says which rows use `sm` (the column's and the browser's) and which `xs` (search); "a hairline `ink.rule` only between browser groups" becomes "a 1 pt `ink.rule` between notes and between groups in the browser; the phone's Notes tab keeps the system's separators tinted `ink.rule`". **Notes tab** (`:538-542`): the day headings; the heading fix in the tab's note line (not in `PhoneMarkRow`, "Checked against the code" 2). New component entries **Group heading** (`NotesGroupHeading`) and **Credit line** (`CreditLineView`). **Fact list** (`:402`): drop "Settings › About" if it is named.
- [ ] **Step 2: DESIGN.json:** the same entries; `python3 -m json.tool DESIGN.json > /dev/null`.
- [ ] **Step 3: README.md:** the Notes browser paragraph (`:152`): day headings by date with the time on each row, book headings by passage; the Acknowledgements line (`:304`): About shows each source as one line, its notice, licence and link a click away.
- [ ] **Step 4: The spec's "As built"** (section 11): what was built, file by file in a line each; every call from this plan's Departures and the pre-flight rulings, each marked "(call, unattended)" with its reason and cost; "Checked against the code"; the benchmark's figure and bound (spec 5.6); the checker counts (71 → 69, 27 → 23, 0, and which old findings went); both suites' counts; Task 1's click and dialog tests as they stood (kept or dropped, and why); what the controller saw live and where. Then **"For Matt"**, in the order to look: spec 10's five items; then the Notes window with his own notes by click, double-click, right-click, Return and Delete with ⌘Z (Departure 24); About on the phone (the install, `Scripts/install-phone.sh debug`, his word, phone unlocked, ProtonVPN off); then the calls he may want otherwise (Departures 2, 3, 5, 9, 12, 15, 20). Then **"What nobody has seen"**: VoiceOver anywhere (About's lines and values, the headings, the rows' labels), the pointer in either window, the Notes window at 980 and 1,200 pt live, Increase Contrast, the phone on a device, a window open across midnight.
- [ ] **Step 5: docs/BACKLOG.md:** delete the line this project builds if one names it; keep "The translations' notices on view" (`:238`), "The Notes Browser's own search field" (`:27`), "The Notes window's keys the system list gave" (`:225`) and "has not been measured with thousands of notes" (`:248`, adding the grouping's figure); add the polish's set-aside items and, if Departure 20 holds, "The phone's book headings in the Notes tab have no count (the Mac's have)".
- [ ] **Step 6: Run the full package suite, then the full iOS `ScriptureUITests`, one after the other;** record both counts (above 1,737 and 1,189); the three checkers, recorded in "As built".
- [ ] **Step 7: Commit:** "docs: Settings › About and the Notes window as built: DESIGN, README, the spec's As built and the backlog".

**After Task 10 (the controller):** the whole-project review on Opus (`/impeccable-swift critique` over `AboutView`, `CreditLineView`, `NotesBrowserRow`, `NotesGroupHeading`, `NotesBrowserView.list` and `PhoneNotesScreen`), one fix wave, one scoped re-review, a last live pass of anything the wave changed (keys only); then the handover's "Before a project is called done": both suites and both Debug builds one after another, the Mac Debug app restarted after the idle check (relaunched without any argument), **the main spec's milestone 11 box 5 ticked** (`docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md:254`), the handover's table, the ledger copied to `docs/superpowers/ledgers/milestone-11/2026-11-23-milestone-11-about-and-notes.md`; then, as the last project, the handover's "When all five are done".

## Pre-flight rulings

Ruled by the controller on 2026-11-23 from the pre-flight scan (`.superpowers/sdd/2026-11-23-milestone-11-about-and-notes/preflight.md`, git-ignored; its tables are in the ledger). Each ruling binds the task it names over that task's own text. All 21 are accepted as the scan proposed them.

Each ruling binds the task it names over that task's own text. Each sides with the spec where the plan departs from it without cause.

1. **R1 (Task 6; C, row 63). The times are Foundation's, U+202F included.**
   - Ruling: every expected time and spoken label in `NotesBrowserRowPartsTests` writes the narrow no-break space Foundation puts before AM and PM in en_US: `"8:14\u{202F}AM"`, `"Note, John 15:4, 8:14\u{202F}AM"`, and so on for 9:03 PM, 6:40 AM, 6:31 AM, 10:00 AM and 9:00 AM. `when` stays `.dateTime.hour().minute()`, never a hand-built string. The pinned date "Nov 23, 2026" is unchanged.
   - Reason: Departure 9 already pins Foundation's forms, and the reader's region form is the spec's (5.2).
   - Cost if wrong: none at run time. Without it, seven tests fail at Step 4, and the implementer may "fix" the format instead.
2. **R2 (Task 6; C2). The quote is set in `quoteFont()`.**
   - Ruling: the marked words are `Text(quote).font(pageFace.quoteFont())`, with `backgroundColor = Color(markup:)` on the `AttributedString` when filled, as `PhoneMarkRow` draws them (`:71-73, 104-107`). `settingMatches` may wrap the string but is not what sets the face.
   - Reason: spec 5.2 names `quoteFont()`, and `settingMatches` sets no font on a plain string.
   - Cost if wrong: none. Otherwise the quote renders in the system font, not the page's italic.
3. **R3 (Tasks 3, 6, 7, 8 and 10; C1). DESIGN.md changes with the build, as spec 7 says.**
   - Task 3 rewrites Navigation › About and the Fact list mention.
   - Task 6 writes Components › Rows: the browser row's anatomy and the padding line `:340`.
   - Task 7 writes Navigation › Notes browser, the Rows hairline sentence and the Group heading entry.
   - Task 8 writes section 7, Notes tab.
   - Task 10 adds DESIGN.json, the Credit line entry if Task 3 did not, and reconciles every entry with the code as built after Task 9.
   - Reason: the spec binds, and the later audits read DESIGN.md.
   - Cost if wrong: a few more DESIGN.md edits, which the Task 10 reviewer checks once.
4. **R4 (Task 9; C4). The benchmark is a macOS test.**
   - Ruling: `NotesBrowserBenchmarkTests` is `#if os(macOS)` and `@MainActor`, like every suite that calls `ReaderBenchmarkTests.median`. It times only `NotesBrowserQuery.days`.
   - Reason: the helper exists only there, and the iOS `ScriptureUITests` build would fail.
   - Cost if wrong: the grouping is not timed on the simulator; the Mac figure is the spec's.
5. **R5 (Task 9; C5). Task 9 runs on Opus.**
   - Ruling: the implementer and the reviewer of Task 9 are on Opus, because its polish is scoped over `NotesBrowserView.list`.
   - Reason: the handover's rule ("Opus for anything that touches the Notes window's focus and keys").
   - Cost if wrong: one task at Opus prices.
6. **R6 (Task 8; P10). `headings(for:)` is not a static on the generic type.**
   - Ruling: it is `@MainActor static func notesHeadings(for model: NotesBrowserModel) -> [(title: String, count: String?)]` on the non-generic `PhoneNotesScreen`. The test calls it there, and `PhoneNotesGroups`' body reads it. Its result is as the plan says.
   - Reason: `PhoneNotesGroups.headings(for:)` cannot infer `Row` and will not compile.
   - Cost if wrong: none.
7. **R7 (Tasks 5 and 8; C6, G2, P13). The phone's fix stays at `noteBody(for:)`, and the tests reach it there.**
   - Departure 18's placement is accepted: Search is already plain, and `PhoneMarkRow` is unchanged.
   - Task 5 makes `noteBody(for:)` internal (`static func`, still in `PhoneNotesScreen`).
   - Task 5 replaces `thePhonesNoteLineHasNoHeadingFont` with an `#if os(iOS)` test in `NoteMarkdownTests`: `PhoneNotesScreen.noteBody(for:)` of an entry built with `NotesBrowserEntry.init`, of kind note and body `"# Prayer\n\nFor the city"`, gives `"Prayer"` and no run with a font. It keeps the `SearchResults.firstLine(of: "# Prayer") == "Prayer"` line as a guard.
   - Task 8 drops "`markRow(for:)` of `ezraChapter` carries a body with no heading font"; `markRow` is checked by its render.
   - Reason: `PhoneMarkRow.note` is private, and the spec's case is the tab's line.
   - Cost if wrong: none.
8. **R8 (Task 1; G3, P2). The fixture's missing words.**
   - Every mark's translation is "ESV".
   - `vine` is a note on a yellow highlight of John 15:5, quoting "I am the vine; you are the branches."
   - `orphan`'s quote is "As the Father has loved me, so have I loved you." (John 15:9).
   - `johnThree`'s quote is "For God so loved the world".
   - `poorInSpirit`'s quote is "Blessed are the poor in spirit".
   - The conversation's translation is "ESV".
   - Task 6's `aColourlessAnchor` asserts the quote is present ("Blessed are the poor in spirit") and not filled.
   - Reason: Task 6 expects tags and quotes "as the fixture sets", and an empty quote makes `aColourlessAnchor` vacuous.
   - Cost if wrong: renders show these made-up words; nothing else.
9. **R9 (Tasks 7 and 9; C3). The floor is checked at the default window.**
   - Ruling: Task 7's render set adds the window at 1,100 by 600 (the scene's `.defaultSize`), by date, Light, and counts the notes in full view. The 760 renders stay for the rest. If fewer than about five show with the fixture's mix, Task 9 tightens within the spec's values (no change to `sm` padding or the line caps). Whatever remains goes in "As built" and on Matt's list.
   - Reason: the spec's floor is "a default window".
   - Cost if wrong: one more PNG.
10. **R10 (Task 3; row 65). `aboutOpensWithEveryLineClosed` is `@MainActor`.**
    - Ruling: the test (and no other in `CreditsTests`) carries `@MainActor`, since `AboutView`'s init is main-actor isolated in Swift 6. It stays: it is cheap, and the reviewer checks that no `@AppStorage`, `@SceneStorage` or `UserDefaults` touches the open state.
    - Reason: it will not compile otherwise.
    - Cost if wrong: none.
11. **R11 (Task 5; row 34). The static `preview` is called through `Self`.**
    - Ruling: `NoteBodyText.preview(_:book:chapterCount:)` keeps its name, and `body` calls it as `Self.preview(text, book: book, chapterCount: links?.chapterCount)`. The `@State preview` (`:47`) is untouched. Task 5's tests read a run's font as `run.font`, as `NoteMarkdownTests.headingsAreLargerAndBold` does (`:26-27`), not `run.swiftUI.font`.
    - Reason: a bare `preview` in `body` is the `VersePreview?` state.
    - Cost if wrong: none.
12. **R12 (Task 5; P12). Task 5's render shows two lines.**
    - Ruling: Task 5 does not touch `NotesBrowserRow`. Its render checks that the preview runs on across blocks and that headings sit at row size within today's two lines. The three-line cap is checked in Task 6's render and in the hosted `theMacsPreviewStopsAtThreeLines`.
    - Reason: Task 5's files exclude the row.
    - Cost if wrong: none.
13. **R13 (Task 4). `theBookSectionsAreUnchanged` is dropped.**
    - Ruling: it is not written. `sectionsGroupByBookInCanonOrder` (existing, unedited) and `theDaysAreTheGroupsByDate`'s `.reference` half (`groups == sections`, `days.isEmpty`) cover it. Task 4's report says so.
    - Reason: it asserts nothing expressible, and its suite cannot reach the model.
    - Cost if wrong: none.
14. **R14 (Task 4; G9). One calendar per model.**
    - Ruling: `rebuild()` passes the model's `calendar` to `timeFilter.cutoff(from:calendar:)`.
    - Reason: the days and the time range then come from one clock and one calendar. The app passes `.current` for both, so nothing changes there.
    - Cost if wrong: none (`timeFilterNarrowsEntriesAndIsRemembered` uses the default calendar either way).
15. **R15 (Tasks 6 and 10; C7). A kept version's words sit on no fill.**
    - Ruling: an orphaned kept version's quote is shown with `quoteIsFilled == false`, in `ink.secondary`, because its entry has no colour. No colour field is added. "As built" records the difference from spec 5.2's "on their colour".
    - Reason: spec 6 says nothing new is stored, and the loader has no colour to give.
    - Cost if wrong: one line in "As built".
16. **R16 (Task 10; G4, G6). The backlog and the wording for Matt.**
    - Ruling: Task 10 deletes BACKLOG `:243` ("Markdown headings in Notes Browser rows show at heading size") and keeps `:27`, `:225`, `:238` and `:248` as planned. For Matt's third item it writes "the phone's Notes tab: the same day headings; its rows otherwise as before; a `#` heading at row size there (Search was already plain)".
    - Reason: CLAUDE.md says an item that is built has its line deleted, and spec 10's Search clause is already true.
    - Cost if wrong: none.
17. **R17 (Task 7). The new enum may go in the view's file.**
    - Ruling: `enum NotesBrowserList` may be added to `NotesBrowserView.swift` beside `list`. "`list` only" means no other part of the view's body, `row(_:)` or the toolbar changes.
    - Reason: the interface puts it there.
    - Cost if wrong: none.
18. **R18 (Tasks 2, 4 and 7). Guard tests may pass at Step 2.**
    - Ruling: `noWordSaysUsedByPermission`, `downCrossesFromOneDayToTheNext` and `theKeysStillWalkAcrossHeadingsAndRules` may pass at "see them fail". Each task's report names which of its new tests failed first and which guard. Every other new test must fail first.
    - Reason: they pin behaviour that already holds.
    - Cost if wrong: none.
19. **R19 (Task 8; G1). Where the phone's test goes, and what the render checks.**
    - Ruling: Task 8's test goes in a new `T/PhoneNotesGroupsTests.swift` (`#if os(iOS)`, `@MainActor @Suite(.serialized)`). `PhoneVersionsTests` is not touched.
    - Ruling: Task 8's render checks that the phone's rows keep two note lines and their date. That is spec 10's "the phone's row keeps its two lines", owned by the render because `PhoneMarkRow` is unchanged and cannot be read by a test.
    - Reason: one undecided file, and one spec item no test can reach.
    - Cost if wrong: none.
20. **R20 (Tasks 5, 8 and 10; G5). The old SwiftLint finding in `PhoneNotesScreen.swift`.**
    - Ruling: `PhoneNotesScreen.swift:59` is an old finding. It may move lines but must stay one. Task 10's "As built" lists it among the old findings left.
    - Reason: the plan's list missed it, and a reviewer might count it as new.
    - Cost if wrong: none.
21. **R21 (Task 3; C8). Departure 5 is accepted as written.**
    - Ruling: the phone's About sits on `paper.page`, the Mac's has no fill, and Matt's list carries it.
    - Reason: the step from `paper.overlay` (#FAFCFE) to the system's white is invisible, which is the plan's stated cause.
    - Cost if wrong: one `.background` line removed.
