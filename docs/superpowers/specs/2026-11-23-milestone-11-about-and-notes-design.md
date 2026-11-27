# Milestone 11, project 5: Settings › About and the Notes window

Status: **Approved by Matt, 2026-11-23** ("I approve all 5."). Fifth and last of milestone 11's five projects. Built on branch `milestone-11-ui-improvements`, then on `milestone-11-about-and-notes` from `ca102d1` (see As built). Builds after project 4 (Places), and takes from project 2 (the About page of a book) the title-page head and the aligned facts that this project's About echoes.

Mockup Matt chose from: `docs/superpowers/specs/milestone-11-mockups/about-and-notes.html` (About A, Notes 3).

## 1. Intent

Two surfaces that show everything at once with nothing to guide the eye.

- **Settings › About.** Matt: "The About page in the apps settings is again, an ugly list with data just thrown everywhere." Today it is a grouped form of 9 sections and 17 sources, each source four or five lines (its name, what the app uses it for, the holder's notice, the link, the licence), every one open at once.
- **The Notes window.** Matt: "The Notes Browser list. I find it really difficult to determine where one notes ends and another begins." Today a note's lines sit 4 pt apart and the next note starts 20 pt below, with no rule between them; every row has the same type, size and colour as its neighbours; and a note whose first block is a markdown heading previews larger than its own reference line. On the phone a hairline already separates notes; the Mac has none.

## 2. Goals, non-goals, anti-goals

**Goals**

- About reads like the colophon of a printed book: the app's name as a title, then one quiet line per source, the detail of each a click away.
- In the Notes window, the eye finds where one note ends and the next begins without effort, and each note reads as a small passage: where it is, the words marked, what was written.
- The Mac's Notes window and the phone's Notes tab group notes the same way.

**Non-goals**

- Changing what is credited, or the wording of any notice, link or licence. The catalogue (`Credits`) is the record; this project changes how it is shown.
- The Notes window's filter, "How far back", search, export, or its keys and clicks.
- The notes column beside the reader (`NoteRowView`, `CompactHighlightRow`), which already reads as rows in a chapter and is not what Matt named.
- The Notes window's own search taking the new search rules (in the backlog).
- Measuring or speeding up the window with thousands of notes (in the backlog; unchanged by this project, see 5.6).

**Anti-goals**

- A card per note, or a gray box around each source. The answer is rhythm and one hairline, not a container (DESIGN.md, "No card by reflex").
- A credit that is hard to find. Every source stays in the app, named, with its notice and licence one click away.
- "Used by permission" anywhere.
- A row so tall that the window shows two notes. About five on screen in a default window is the floor (the mockup's figure).

## 3. Approaches

**About.** Three were mocked up. (A) A colophon: the app's name set like a title page, one line per source with its licence at the trailing edge, in three sections, each line opening in place to its notice, link and licence text. (B) A short list of sources with a page for each beside it (pushed on the phone), set like the Library's pages: a master and detail inside a Settings tab, which Settings has nowhere else. (C) Today's grouped form, tidied to two lines per source with the rest behind a disclosure: the smallest, but it keeps the system's look rather than the app's. **Matt chose A** (2026-11-23).

**The Notes window.** Three were mocked up. (1) Today's rows with the phone's hairline between notes, nothing else changed. (2) Hairlines, and days as headings when sorted by date, with the row showing the time. (3) 2, with a fuller row: the passage leads a size larger, then the highlighted words in the page's serif on their own colour, then up to three lines of the note in full ink, with more air inside a note than between its lines. **Matt chose 3** (2026-11-23).

## 4. Settings › About

### 4.1 Where

The same view on both apps, as today: the Mac's Settings window, last tab ("About"); the phone's Settings, its last row, pushed. One `AboutView`, one catalogue (`Credits`).

### 4.2 The page

- **No longer a `Form`.** A plain scrolling page with no fill of its own: it sits on the Settings window's own background on the Mac, like its sibling tabs, and on the phone's Settings background where it is pushed. Its column is at most a scaled 520 pt and `lg` (24) inset, as a Library page is. **(call)** The grouped form's white boxes are what read as "data thrown everywhere", and a colophon has no boxes; a fill of its own would set About apart from the other Settings tabs.
- **The head:** the app's name ("Bible Carrel", from the bundle as today) in the page face, Light, at the Library title's size: the font and scaled size of project 2's book title on the About page of a book, which is built before this project, so this project reuses it and defines nothing new. Then the version line ("Version 1.0 (42)") in `.callout` `ink.secondary` beneath it. VoiceOver reads the two as one element, as today.
- **Three sections**, each under a group label (`GroupLabel`: `.caption2` semibold upper case, tracked, `ink.verse`, header trait), `md` (16) above each label:
  1. **Scripture:** the eight translations, in today's order (ESV, NASB, AMP, ERV, ASV, KJV, WEB, CPDV).
  2. **Study data:** Berean Standard Bible (section headings), OpenBible.info (cross-references), Theographic Bible Metadata (people, places, events and dictionary entries).
  3. **Typefaces, icon, videos and software:** Literata, Source Serif 4, 3dicons, BibleProject, bobuk/holybooks, GRDB.swift.

  **(call)** The grouping and the three titles follow the mockup Matt chose; the catalogue's eight `Credit.Section` cases (`Credits.swift:7-9`) collapse to three, or the view maps eight to three (either is the builder's, 9).

### 4.3 A source's line

- **Closed (the default):** one line. A disclosure chevron (`chevron.right`, `.caption`, `ink.tertiary`) at the leading edge; the source's name in `.body` `ink.primary`; after it, where the use is not plain Bible text, the use in `.callout` `ink.secondary` after a middle dot ("King James Version · and its book titles", "OpenBible.info · cross-references", "Literata · reading typeface"); at the trailing edge the catalogue's licence string as it is, in `.callout` `ink.secondary` ("Copyright", "Public domain", "CC BY 4.0", "SIL OFL 1.1", "MIT"; "Public domain since 2023-04-30" and "Linking permitted by its terms" too), with no new catalogue field. **(call)** A Scripture row whose use is "Bible text" shows no use. The wording of the use after the dot is edited in `Credits` itself ("and its book titles", "cross-references", "reading typeface"; the AMP's "the file labelled AMP"), so the catalogue stays the one record and `CreditsTests` changes with it. **(call)** One record, not a second set of strings in the view.
- **Width:** where the row is too narrow for the name, use and licence on one line, the licence moves under the name (`ViewThatFits`); nothing truncates. **(call)** The long licence strings and large Dynamic Type would otherwise squeeze the name.
- **Rows are separated by rhythm:** `xs` (8) vertical padding, no rule between rows, no fill at rest.
- **Open:** a click anywhere on the line (or Space or Return with the keyboard on it) opens it in place; the chevron turns down (`chevron.down`; a cut under Reduce Motion, else `.snappy` on the chevron's rotation and the block's opacity, never on its frame). The opened row sits on `paper.overlay` at radius `md` (6), padded `sm` (12), a tonal step and no stroke, and shows under the line:
  - the holder's notice, in `.callout` `ink.secondary`, selectable (as today);
  - the link, in `.callout` `accent`, shown without "https://" (as today);
  - for a source with a licence file (Literata, Source Serif 4, holybooks, GRDB.swift), a second disclosure, "Licence text", that opens the re-wrapped text in `.caption` `ink.secondary` under it (today's `LicenseText.reflowed`, unchanged); for a source with a licence link (OpenBible.info, Theographic), the licence's name as a link in the accent. **(call)** The licence text is long (the OFL runs to about ninety lines); behind its own disclosure the opened row stays short.
- **Several rows may be open at once;** opening one does not close another. Nothing is remembered: the page opens with every row closed. **(call)**
- **VoiceOver:** each line is one element, a button, labelled with its name, use and licence ("English Standard Version, Copyright"), its value "Collapsed" or "Expanded"; the opened block's notice and link are reachable after it in order; the link is a link.
- **Keyboard (Mac):** with keyboard navigation on (Matt's Mac has it on), Tab reaches each line in turn; Space or Return opens and closes it; the link and the "Licence text" disclosure take Tab stops when open. The system focus ring is drawn on the line's rounded shape (radius `md`), as the verse-panel rows draw theirs.

### 4.4 What stays

- Every source, every notice, every link and every licence text in the catalogue, word for word. `CreditsTests` changes only where 4.2 regroups the sections and 4.3 rewords a use.
- No "Used by permission" (DESIGN.md; the backlog's licensing items).
- The Library's credit line at the foot of People, Places and About is a separate thing and does not change.

## 5. The Notes window (Mac)

### 5.1 Groups

- **Sorted by date** (the default): notes sit under the day they were last changed (`modifiedAt`, the value the date sort already uses), newest day first. The heading reads "Today", "Yesterday", then the weekday and date ("Tuesday 18 November"), with the year added when it is not this year ("Friday 14 November 2025"), written in the reader's region's order as every date in the app is. **(call)** on the wording past Yesterday; the mockup showed "Tuesday 18 November".
- **Sorted by passage:** the book headings it has today (`NotesBrowserQuery.sections`), unchanged in content.
- **A heading** (either kind): its title in `.headline` `ink.primary` at the leading edge, its count in `.callout` `ink.secondary` at the trailing edge, monospaced digits; the header trait; never selected. `md` (16) above a heading, `xxs` (4) below it. The count's word follows the filter: All "items", Notes "notes", Highlights "highlights", Bookmarks "bookmarks", Threads "conversations", Kept versions "kept versions"; singular for one ("1 note"). **(call)** "3 notes" over a bookmark would be wrong.
- **Between groups** the rule that sits between book groups today (0.5 pt, `NotesBrowserView.swift:136`) stays, at 1 pt `ink.rule`, and day groups take it too; none before the first group. **(call)** 1 pt is DESIGN.md's stroke convention, and it matches the hairline between notes (5.3).
- **The keyboard** walks the rows across groups in order, as it does across book groups today (the model's `visibleIDs`); a heading is not a stop.

### 5.2 The row

From top to bottom, inside `sm` (12) horizontal and `sm` (12) vertical padding (DESIGN.md's figure for rows; the code today uses `xs`, 8):

1. **The reference line:** the marker (the 10 pt colour dot with its 0.5 pt `ink.rule` keyline; `note.text` for a chapter note; `bookmark.fill` in the accent for a bookmark; `sparkles` in plum for a conversation; the kept-version symbol), then the reference in `.body` semibold `ink.primary` (one step up from today's `.callout`), the translation tag after it in `.caption2` semibold `ink.secondary`, and at the trailing edge the time in `.caption` `ink.tertiary`, monospaced digits: the time ("8:14 AM", the reader's region's form) under a day heading, and the date as today ("Nov 18, 2026") under a book heading, where the heading does not say when. **(call)** on the date under a book heading.
2. **The marked words** (a highlight's quoted text), when there are any: in the page face's italic at `.callout` (`pageFace.quoteFont()`), `ink.primary`, on the mark's own colour as the phone's rows and ⌘K's mark rows already draw them (DESIGN.md section 5, Search rows), up to two lines. A colourless highlight's words are on no fill, in `ink.secondary`. `xs` (8) above.
3. **The note,** when there is one: rendered as a note's body is (`NoteBodyText`, with its links in the accent), in `.callout` **`ink.primary`** (full ink, where today it is secondary), up to **three lines**. The preview runs on across the note's blocks (paragraphs, list items and headings flowing on, as far as three lines reach), where today it shows the first block only; a heading is set at the row's own size and weight, never larger than the reference. `xs` (8) above.
4. **The versions mark** ("2 versions", "Kept version"), as today, `xs` above.

By kind: a highlight with no note shows lines 1 and 2; a bookmark shows line 1 and its quoted words when the entry has them; a chapter note shows lines 1 and 3; a conversation shows its title in place of the reference (with the reference after it when the title does not begin with it, as today) and its last turn's first line as line 3, in `ink.primary`, two lines, as today (`NotesBrowserRow.swift:44-47`); a kept version shows its passage, its words on their colour, its text and its mark, as today.

### 5.3 Between rows

- **A hairline** (1 pt `ink.rule`, DESIGN.md's stroke convention, inset `sm` from both edges so it lines up with the row's text, not the window's edge) between two notes in one group; none above a group's first or below its last. **(call)** on the inset; the phone's hairline runs from the leading edge (5.5) because a `List` draws it.
- **No other space** between rows: the rows' own `sm` padding sits on each side of the hairline, so a note's parts are `xs` (8) apart and two notes are `sm` + 1 + `sm` apart with a line between. More air inside a note than between its lines, and a rule where it ends.
- **The selection wash** (`accent.wash`, radius `md`) covers the selected row's whole padded area and hides the hairlines on either side of it, so the wash never sits on a line. **(call)**

### 5.4 What stays

Every behaviour in DESIGN.md's Notes browser entry: one keyboard stop, ↑ ↓ Return Delete, a click selects, a double-click opens in the reader, right-click and Control-click select before the menu, Delete confirms and is undoable, the selection moves to the note that took its place, the filter, "How far back", the search field, Export, the kept-version rows under their own filter, VoiceOver's selected trait and its "Note, John 15:4" labels (now with the time or date the row shows).

### 5.5 The phone's Notes tab

- **Sorted by date:** the same day headings as the Mac (`Section` headers in the plain `List`, Headline in primary ink, the count trailing in `.callout` `ink.secondary`, the count's word as 5.1). **Sorted by passage:** the book headings it has today. The day headings are the tab's only change. **(call)**
- **The row** (`PhoneMarkRow`) is shared with the phone's Search tab (`PhoneSearchScreen.swift:339`), so its anatomy does not change in this project: it keeps its date, its secondary-ink note and its two lines. The one change that reaches it is the heading fix (a note whose first block is a heading previews at the row's size), which then applies in Search too; that is harmless, and Search's own rules are untouched. **(call)** A row shared with Search is not redrawn for the Notes tab alone. Its separators stay the system's, tinted `ink.rule`.
- Its swipes, its tap to open and its three menus are unchanged.

### 5.6 Speed

The day grouping is made once per reload in the model (beside the book grouping), never in a row's body. Each row stays its own `View` in the lazy stack (milestone 10's lesson: a row that appears eighty times must be its own view). The window has not been measured with thousands of notes (backlog); this project adds no per-row cost beyond the extra line of quote, and says so in its "As built" with whatever figure the builder takes.

## 6. What is stored

Nothing new. No stored value, preference or synced record changes. The Notes window's sort and filter remain where they are kept today.

## 7. Design changes (DESIGN.md, in the same commit as the build)

- **Section 5, Navigation, "About"** (the `AboutView` entry): rewritten for 4: a plain page, not a grouped form; the head in the page face; three sections under group labels; one line per source opening in place on `paper.overlay`; the licence text behind its own disclosure; VoiceOver and keyboard as 4.3.
- **Section 5, Navigation, "Notes browser"**: day headings under the date sort; the heading's anatomy and count; the time in the row; the hairline between notes and none between groups; the selection wash over the hairlines.
- **Section 5, Components, "Rows"**: the browser row's anatomy (5.2) beside the column's: the reference at `.body` semibold, the quote on its mark colour, the note in `ink.primary` up to three lines across blocks, a heading at row size. Correct the padding line: DESIGN.md:339 says rows have `sm` (12) vertical padding while the browser's code uses `xs` (8); after this project the browser row uses `sm`, and the line says which rows use which. "A hairline `ink.rule` only between browser groups" becomes "a 1 pt `ink.rule` between notes and between groups in the browser; the phone's Notes tab keeps the system's separators tinted `ink.rule`".
- **Section 7, Notes tab:** the day headings, and the heading-size fix in `PhoneMarkRow` (Notes and Search).
- **`DESIGN.json`** in step with the above.

## 8. Constraints

- DESIGN.md throughout: semantic text styles only (no `.font(.system(size:))`), Palette tokens only, `AppSpacing` and `AppRadius` by name, `@ScaledMetric` for anything tied to text (the dot, the marker column, the page's 520 pt column, the chevron's hit area), no card by reflex, no shadow, motion `.snappy` on opacity and rotation and a cut under Reduce Motion.
- Every SwiftUI change goes through `/impeccable-swift`, and its checkers (`tools/`) run on the changed files; the branch's baseline is in the tools commit.
- Light, Dark and Sepia, and Increase Contrast: the quote's ink on every mark fill holds the contrast `PaletteTests` already guarantees for the marks; nothing new to add there.
- A test never writes to the real store, the `.dev` store or the clipboard. The Notes window's renders use a fixture store with made-up notes.
- Both apps share `AboutView` and the notes query; the Mac's window and the phone's tab are drawn by their own views.

## 9. Left to the builder

- Whether `Credit.Section` becomes three cases or the view maps eight to three (4.2).
- The exact chevron, its hit area and how the opened block is laid out, within 4.3.
- How the day grouping is computed and cached (a `NotesBrowserSection` per day beside the book sections, or a second type), within 5.6.
- How the hairline is drawn under a lazy stack (a row's own bottom rule hidden for the group's last row, or a separator view), within 5.3.
- The VoiceOver wording of a day heading ("Today, 2 notes").
- The live window's look at 980, 1,100 and 1,200 pt, which the mockup did not try.

## 10. Verification

Tests first:

- **Credits** (`CreditsTests`, changed with the catalogue): every source of today's catalogue appears once, in one of the three sections, in the stated order; the reworded uses; the use shown after the dot is empty exactly for the Scripture rows whose use is "Bible text"; no string anywhere says "Used by permission" (today's check kept).
- **About's line:** the accessibility label of a closed line reads name, use and licence; opening it exposes the notice and the link; a source with a licence file has the "Licence text" disclosure and one without has none.
- **Day grouping:** a fixture's notes from today, yesterday, three days ago and last year fall under "Today", "Yesterday", the weekday and date, and the date with its year; newest first; counts right; a day boundary at local midnight (two notes a minute either side of it, with distinct times; milestone 10's lesson on records in one millisecond); the passage sort's book sections unchanged.
- **Keyboard order:** ↓ from the last row of one day reaches the first row of the next; with nothing selected ↓ takes the first row and ↑ the last, across groups.
- **The preview:** a note whose first block is `# Heading` previews the heading at the row's font, not `.title3`, in the Mac's row and in `PhoneMarkRow`; on the Mac a note of a short paragraph and a list flows into three lines across both, and the three-line cap holds; the phone's row keeps its two lines.
- **Row by kind:** a highlight without a note, a bookmark, a chapter note, a conversation and a kept version each show the parts 5.2 names, and no other.
- **Renders** (offscreen, removed before commit): the Notes window with a fixture of mixed kinds in light, dark and Sepia, by date and by passage; the selected row with the hairlines hidden; About closed, one source open, one licence text open; About at a large Dynamic Type size; the phone's Notes tab by date.
- **The checkers:** SwiftLint and `impeccable-lint` on the changed files add nothing over the baseline.

Seen by eye before it is called done: one live pass by the controller on the Mac (keys only, under the handover's rules) of the Notes window by date and by passage, and of Settings › About with one source opened by Space.

For Matt:

- [ ] The Notes window: each note reads as its own block; days as headings by date, books by passage; the time in each row.
- [ ] A note that starts with a `#` heading no longer previews larger than its reference.
- [ ] The phone's Notes tab: the same day headings; its rows otherwise as before (and a `#` heading no longer large in Search either).
- [ ] Settings › About on the Mac and the phone: the app's name as a title, three sections, one line per source; open the ESV and a typeface, then its licence text.
- [ ] The Notes window's keys, click, double-click, right-click and Delete with ⌘Z still behave as before.

## 11. As built

Built 2026-11-23 and 2026-11-24, unattended, in nine tasks and this record (the plan `73826a0`, its pre-flight rulings `35f8d63`, the build `35f8d63..99c8ccf`), each task reviewed by a second model and fixed where it found something (one fix round, Task 6's). The run stopped once, at Task 9's dispatch, on an expired sign-in; the coordinator moved it to `.claude/worktrees/milestone-11-about-and-notes`, branch `milestone-11-about-and-notes`, cut from `milestone-11-ui-improvements` at `ca102d1` (Matt's People review, four rounds), so this project is built on top of that review and sits beside `LibraryType` without taking it. No schema, stored value, preference or synced record changed (spec 6). The whole-project review and its fix wave: the paragraph of that name, after "Seen live".

**Built, file by file** (sources under `Packages/ScriptureKit/Sources/ScriptureUI/`, tests under `Packages/ScriptureKit/Tests/ScriptureUITests/`).

- `Credits.swift`: `Credit.Section` is three cases (Scripture, Study data, Typefaces, icon, videos and software), every credit re-sectioned and every use reworded to the line's own words; `Credit.shownUse` is nil exactly for plain "Bible text". `CreditLine.swift` (new): the words and parts of a line (name, use, licence, `spoken`, `value(isOpen:)`, `opened`, `address`), pure.
- `AboutView.swift`: rebuilt as a plain scrolling page (no `Form`): the head (`LibraryPageTitle` and the version line), three `GroupLabel` sections, and `CreditLineView`, one line per source that opens in place; `paper.page` under it on the phone only; an internal `init(info:opened:licenceOpened:)` for renders. `FactList.swift`: the doc comment no longer names About.
- `NoteMarkdown.swift`, `NoteBodyText.swift`: `blocks(_:headingsAtTextSize:)` and a static `preview`, so a note's lines run on across blocks, capped at `previewLines`, with a heading at the row's size.
- `NotesBrowserEntry.swift`, `NotesBrowserModel.swift`: `NotesBrowserQuery.days`, `dayTitle`, `countLabel`, `headingSpoken`; the model takes `calendar:` and `locale:` (defaults `.autoupdatingCurrent` since the fix wave, M4), makes `days` once per rebuild beside `sections`, and `groups` picks one; `visibleIDs` reads `groups`; the time filter's cutoff uses the model's calendar.
- `NotesBrowserRowParts.swift` (new, pure), `NotesBrowserRow.swift`: the fuller row (anatomy as DESIGN.md's Browser row); `NotesBrowserView.swift`: `row(_:)` unchanged, the call gains `parts:`; `list` draws `groups` under headings with the hairlines and the group rule, and `NotesBrowserList.showsRule` (and, since the fix wave, `spaceAboveGroupRule`) lives beside it. `NotesGroupHeading.swift` (new, internal, both apps).
- `Phone/PhoneNotesScreen.swift`: `PhoneNotesGroups` (a `Section` per group; day headings by date), `markRow(for:)`, `notesHeadings(for:)`, `noteBody(for:)` at the row's size.
- Tests: `CreditsTests` (changed), `NotesBrowserFixture` and `NotesBrowserWindowTests` (new), `NotesBrowserQueryTests`, `NotesBrowserModelTests`, `NotesBrowserRowPartsTests` (new), `NoteMarkdownTests` (with `NotePreviewHeightTests`), `PhoneNotesGroupsTests` (new, iOS), `NotesBrowserBenchmarkTests` (new, macOS).
- `DESIGN.md` (About, Credit line, Group heading, Browser row, the Rows' border and padding lines, Notes browser, Notes tab, the Body line), `DESIGN.json` (the same entries; it had not been touched since the About form), `README.md` (the Notes browser paragraph and the Acknowledgements line), `docs/BACKLOG.md`.

**Checked against the code** (the plan's list, each held when built). 18 November 2026 is a Wednesday, and the headings are Foundation's forms ("Wednesday, November 18", with the year "Friday, November 14, 2025"; en_GB "Wednesday 18 November"). The Mac's note was already `ink.primary`; what read secondary was the quote with no note and the phone's note line. Search's headings were already at the row's size, so the heading fix is in `PhoneNotesScreen.noteBody(for:)` and `PhoneMarkRow` is unchanged. The ERV's use was "Bible text (ERV)". `FactList`'s doc comment named About, which never used it. Today's licence disclosure was labelled with the licence's name and its notice was `.caption`; both changed. The catalogue's other licence strings (CC BY-SA 4.0, CC0, BSD 3-Clause) show as they are.

**The numbers.** Head counts at the start: package 1,737 and iOS `ScriptureUITests` 1,189. At the resume's baseline `ca102d1`: package 1,835, iOS 1,261. Final, after the last commit: package 1,836 (1,414 + 241 + 52 + 96 + 33), iOS 1,261, both Debug builds green (the Mac's after Task 9; the iOS scheme builds with the suite). **The benchmark** (spec 5.6; `NotesBrowserBenchmarkTests`, macOS only by R4): `NotesBrowserQuery.days` over 2,000 made-up notes across 400 days, the median of nine, 6.4, 6.5 and 6.6 ms alone in a debug build; the bound is 1.5 times 6.6 rounded up to the next millisecond, **10 ms**. The window with thousands of rows is not measured (the backlog's line stays, with this figure added). The bound's margin (1.5 times the median) is the same as that of the benchmarks that failed under load, so it may join the known timing flakes under full-suite load; rerun it alone. The package run carried three timing-benchmark issues under the Mac's load (it was in use, load average 13 at the time): `FrontPageBenchmarkTests.theFrontPageOpensWithinAHundredMilliseconds` at 28 pt, `LibraryBenchmarkTests.peopleInFirstChroniclesOpensWithItsFirstPersonChosen` and `LibraryBenchmarkTests.davidsPageInSecondSamuelOpens`; the first two passed on rerun together with the rest of both suites, and `davidsPageInSecondSamuelOpens` (project 3's People budget, 150 ms; code this project did not touch) read 153.1 and 159.6 ms alone, up from 141.1 ms at the resume's baseline, which was itself close to the bound. All 1,836 tests ran and none but those timing bounds failed. Matt's People work is the owner of that budget. **The checkers:** SwiftLint 71 → **69**, impeccable-lint 27 → **23**, the asset-catalog checker **0**. SwiftLint's two went in Task 7: the 0.5 pt `Rectangle` between groups and its `accessibilityHidden`, replaced by a `HairlineRule`. impeccable-lint's four went in Task 6: the marker symbols' missing `accessibilityLabel`. Old findings left, none new: SwiftLint's `PhoneNotesScreen.swift:59` (R20; it has moved lines and stayed one) and `NotesBrowserView.swift:62` and `:63` (the hidden ⌘F button), and impeccable-lint's `onTapGesture` in `NotesBrowserView.row(_:)` (Departure 14 leaves it).

**Task 1's click and dialog tests, as they stood** (Departure 23). Kept: `NotesBrowserWindowTests`, four hosted tests on today's code over a made-up in-memory store: ↓ and ↑ walk the rows in both sorts, Return shows the selected row's target, Delete asks before anything goes, and the kept-versions filter lists its two rows and shows the orphan's target. Five green runs in a row before it was committed; later tasks added `downCrossesFromOneDayToTheNext` and `theKeysStillWalkAcrossHeadingsAndRules` to the file and edited nothing in it. **Dropped:** `aClickSelectsAndADoubleClickShows`. Offscreen, the hosting view exposes no row elements (an `AXGroup` with no children, its scroll area too), and a mouse down and up sent through `window.sendEvent` at every 20 pt down the first rows selected nothing, so neither the elements nor SwiftUI's tap gestures answer there. The click, double-click and right-click rest on Departure 14 (`row(_:)`'s modifiers are not in any diff of this project), on `SecondaryClickHookTests`, and on Matt's pointer. **Stopped at the sheet:** the delete test attaches the sheet and pins that Return does not reach the dialog's Delete (the alert's Delete has no key equivalent and no default button cell today), then ends the sheet; "one entry fewer, the selection on the row that took its place, undo restores it" stays with the model's tests (`deletingTheSelectedRowSelectsItsSuccessor`, `deletingAThreadFromTheBrowserIsUndoable` and the rest). If Delete ever becomes the dialog's default button, that test fails by design.

**Calls (call, unattended).** The plan's departures first, each built as written, with its reason and cost if wrong.

1. **`Credit.Section` is three cases,** not a mapping in the view. *Reason:* only `AboutView` and `CreditsTests` read it, and one record stays one record. *Cost:* none.
2. **The ERV shows no use** (its use is "Bible text"), as the mockup drew it; "(ERV)" repeats the tag the reader shows. *Cost:* one string back. On Matt's list.
3. **The uses are the line's own words, lower case after the middle dot** ("the file labelled AMP", "and its book titles", "section headings", "cross-references", "people, places, events and dictionary entries", "reading typeface", "the app icon's artwork", "links to its book overview videos", "the texts' file layout", "reading the Bible database"). *Reason:* one line reads as a phrase. *Cost:* wording. On Matt's list.
4. **About uses no fact list;** its head is `LibraryPageTitle(appName, subtitle: nil)` with the version line under it. *Reason:* spec 4 has none. *Cost:* none.
5. **The phone's About sits on `paper.page`; the Mac's has no fill.** *Reason:* the step from `paper.overlay` (#FAFCFE) to the system's white is invisible. *Cost:* the phone's About is not the grey of its sibling forms. The fallback the plan named was **taken** in Task 9: after the live pass saw the Settings window white in Light, the opened block's fill is `paper.panel` on the Mac (`paper.overlay` stays on the phone); in Dark it is a shade darker than the window (a well, not a lift). On Matt's list.
6. **One text edge on the page:** the head, labels and lines carry `sm` across inside the `lg` column. Amended by Task 9 (L2): a line is padded `xs` down open or closed, where the plan had `xs` closed and `sm` open, so its name no longer drops 4 pt when it opens. *Cost:* none.
7. **A line's anatomy** (chevron in a scaled column, name, use, licence, `ViewThatFits` to the licence under the name, the line as one `versePanelRowAction` element with the value "Collapsed" or "Expanded", the chevron turning by a scoped `animation(_:body:)`, a cut under Reduce Motion, several open, nothing remembered) as written. Amended by Task 9 (L3, below).
8. **About's tests are pure;** no test reads a hosting view's accessibility tree, so VoiceOver on the page is on the list of what nobody has seen.
9. **The day heading's words** are Foundation's ("Today", "Yesterday", else the weekday and date in the reader's locale, the year when it is not this year); a day after today is titled by its date. *Cost:* wording. On Matt's list.
10. **The day sections live beside the book sections** (`days`, `groups`); `sections` stays books only, so `entriesCoverNotesHighlightsAndBookmarksNewestFirst` stands. *Cost:* none.
11. **A heading is `NotesGroupHeading`,** both apps, one VoiceOver element with the header trait, "Today, 2 notes"; the count's word follows the filter. *Cost:* wording.
12. **The rule between groups is a full-width `HairlineRule` directly under a group's last row.** *Reason:* spec 5.3. *Cost:* the selected last row's wash sat on it with no gap, and the rule's width alone tells it from a note's hairline. **Amended by the fix wave (I1):** the rule sits `xxs` under a group's last row (`NotesBrowserList.spaceAboveGroupRule`), so a selected last row's wash stops 4 pt short of it; spec 5.3 ("the wash never sits on a line") binds over the plan here. *Cost now:* 4 pt per group boundary; the default window still shows five notes.
13. **The hairline between notes is its own view,** inset `sm`, hidden beside the selected row, its opacity following the wash (`.snappy`, a cut under Reduce Motion), keeping its point. *Cost:* none.
14. **`NotesBrowserView.row(_:)`'s modifiers are not changed;** every reviewer that saw the file confirmed no line inside it is in any diff.
15. **The row's layout follows the mockup:** the marker leads the reference line, the quote, note and mark start at the text's leading edge under it; `sm` all round, `xs` between lines. *Cost:* none seen. On Matt's list.
16. **The time and the date,** in the model's calendar's zone and locale, Foundation's forms (the narrow no-break space before AM and PM, R1); VoiceOver puts the time last.
17. **The quote by kind,** as the plan lists. Where this differs from spec 5.2, see R15 below.
18. **The preview runs on across blocks and a heading is at the row's size** in the Mac's row (three lines) and the phone's `noteBody(for:)`; every other `NoteBodyText` and `NoteMarkdown` caller keeps `.title3` headings. *Cost:* none.
19. **The marker symbols take `.accessibilityLabel(kindName)`,** clearing impeccable-lint's four.
20. **The phone's book headings are unchanged** (title only, no count). *Reason:* spec 5.5, "the day headings are the tab's only change". *Cost:* by passage the phone has no counts and the Mac has; one `NotesGroupHeading` to add (the backlog has the line). On Matt's list.
21. **The phone's list is renderable:** `PhoneNotesGroups`, `markRow(for:)`; behaviour unchanged.
22. **A window left open across midnight keeps yesterday's "Today"** until the model rebuilds (it becoming key, a filter, a search, a sort, a change). *Cost:* a stale heading until the window is used. Pinned by `theDaysAreMadeFromTheModelsClock`.
23. **The behaviour was pinned before anything changed** (Task 1; above).
24. **The live passes were keys only,** launched with argument-domain values so nothing was written; the click, double-click, right-click, Return and Delete with ⌘Z in the Notes window, with Matt's own notes, are Matt's (below).
25. **Speed:** one pure benchmark (above).

The pre-flight rulings, each **(call, unattended)**, each accepted as the scan proposed:

- **R1** every expected time and spoken label carries Foundation's U+202F before AM and PM; the format is never hand-built. *Cost:* none.
- **R2** the quote is set in `pageFace.quoteFont()`, filled by `Color(markup:)` on the `AttributedString`, as the phone's row sets it. *Cost:* none.
- **R3** each UI task wrote its DESIGN.md entries as it built (Tasks 3, 6, 7, 8, 9); this task added DESIGN.json and the Credit line entry (Task 3 had put the line inside About's), reconciled each against the code as built, and corrected three things: the Body line now names the two `.body` uses (the browser row's passage and About's names), the Browser row says "its translation" (it had "every translation"), and About says it is not a Library page and does not take `LibraryType`. *Cost:* none.
- **R4** the benchmark is macOS only (`ReaderBenchmarkTests.median` exists there). *Cost:* the grouping is not timed on the simulator.
- **R5** Task 9 and its reviewer ran on Opus, since its polish is scoped over `NotesBrowserView.list`. *Cost:* one task at Opus prices.
- **R6** the phone's headings are `PhoneNotesScreen.notesHeadings(for:)`, a static on the non-generic type, as `PhoneNotesGroups<Row>.headings(for:)` cannot infer `Row`. *Cost:* none.
- **R7** the phone's heading fix stays at `noteBody(for:)`, tested there; `PhoneMarkRow` is unchanged and `markRow` is checked by its render. *Cost:* none.
- **R8** the fixture's missing words (every mark "ESV"; `vine`, `orphan`, `johnThree` and `poorInSpirit` quote the words the ruling gives). *Cost:* renders show these made-up words.
- **R9** the floor is checked at the default window, 1,100 by 600: **five notes are in full view** by date, Light (John 15:4, Romans 8:28, Psalm 23:2, John 15:5 with its mark, Genesis 22:8), with Ezra 4's first line cut at the foot; Task 9 re-checked it and tightened nothing. *Cost:* one more PNG.
- **R10** `aboutOpensWithEveryLineClosed` is `@MainActor` (Swift 6). *Cost:* none.
- **R11** `NoteBodyText.preview` is called through `Self`. *Cost:* none.
- **R12** Task 5 did not touch the row; the three-line cap is Task 6's render and the hosted `theMacsPreviewStopsAtThreeLines`. *Cost:* none.
- **R13** `theBookSectionsAreUnchanged` was not written; `sectionsGroupByBookInCanonOrder` and `theDaysAreTheGroupsByDate`'s `.reference` half cover it. *Cost:* none.
- **R14** one calendar per model (the time filter's cutoff takes the model's). *Cost:* none.
- **R15** an orphaned kept version's words sit on **no fill**, in `ink.secondary`, because its entry has no colour and nothing new is stored. *Difference from spec 5.2,* "on their colour". *Cost:* a kept version's words are not highlighted in the browser. On Matt's list.
- **R16** the backlog's "Markdown headings in Notes Browser rows" line is deleted (built); for Matt's third item the wording is "the phone's Notes tab: the same day headings; its rows otherwise as before; a `#` heading at row size there (Search was already plain)".
- **R17** `enum NotesBrowserList` sits in `NotesBrowserView.swift` beside `list`. *Cost:* none.
- **R18** the guards (`noWordSaysUsedByPermission`, `downCrossesFromOneDayToTheNext`, `theKeysStillWalkAcrossHeadingsAndRules`) may pass first; `downCrossesFromOneDayToTheNext` in fact failed first, since it reads `model.groups` and so could not compile. Every other new test failed first (a compile failure counts).
- **R19** the phone's test is a new `PhoneNotesGroupsTests`; "the phone's rows keep two note lines and their date" is checked by render. *Cost:* none.
- **R20** `PhoneNotesScreen.swift:59` is an old SwiftLint finding, listed above. *Cost:* none.
- **R21** Departure 5 as written (above).

And the ledger's own rulings and the build's calls, each **(call, unattended)**:

- **Task 1:** the vine note's body and its kept version's words, the orphan's text, the conversation's turns and times, and "ESV" on the kept versions are the implementer's, as the report says. The fixture removes its `UserDefaults` suite in `deinit`. *Cost:* renders show made-up words.
- **Task 3 / Task 9, L1 to L3** (the controller's live pass of About after Task 3, which found the opened row all but invisible on the white Settings window, the name dropping 4 pt on open, and the focus ring cutting across the fill). L1 and L2 are built as above. **L3 is a call that departs from spec 4.3 and the mockup:** the fill starts *under* the line (`xxs` below it, so the line's ring, on its own radius-`md` shape, and the fill never cross), and the line itself sits on no fill, where the spec has the opened row, line and block, on `paper.overlay`. *Reason:* it keeps `versePanelRowAction` on the line exactly as it was (Tab, Space, Return, the one button element and the inner Tab stops), where a ring round the whole row would need the focusable view to be the whole row (Return on a focused link would bubble to it) or a custom ring (DESIGN.md: "system focus ring. No custom focus color"). *Cost:* if Matt wants the mockup's look, there are two ways back: the fill goes back behind the line and the ring goes round the whole opened row; or the fill goes back behind line and block (as Task 3 had it) with the ring kept on the line and the line's focus shape inset from the fill's edges (a `.contentShape(.focusEffect, …)` inset `xxs`, or the fill padded `xxs` outside the line), so the ring sits inside the fill instead of on its border, with Tab, Space, Return and the one button element untouched. Measured on the live capture, the ring sits about 3 pt outside the line's shape, so today's `xxs` leaves about 1 pt between ring and fill. Two reviewers judged it; the whole-project review checks it. On Matt's list.
- **Task 3:** the opened block is indented to the name's edge (so "Licence text" sits there too); the block fades in and is removed at once on close (a cut, so no frame animates); the chevrons carry "Expand" and "Collapse" labels the line's own label hides. Task 9 gave the fill the same fade as the text.
- **Task 3 (the ledger):** the opened row's faint step in the render was left to the live pass, as the render's host is white and the real Settings window's background is not; the live pass found it faint (L1).
- **Task 6:** `settingMatches` is skipped (no matches in the browser, so the string is plain); `quoteIsFilled` is `quote != nil && color != nil`; the kind-specific text went in a new Rows bullet and the column's line 340 stands (reworded for `sm` in the fix); the tests' helper finds an entry under `.keptVersions` then `.all`. The task reviewer found the passage and the marker column set one step small; one fix round made the passage `.body` semibold and the marker column `relativeTo: .body`, and DESIGN.md followed.
- **Task 7:** the hairline's animation is `.snappy(duration: 0.2)`, the wash's own, so the two move together; it is drawn inline in `list` so nothing outside `list` changes but the R17 enum; `NotesGroupHeading` is internal; the Group heading entry sits under Components › Rows. Its concern, the selected last row's wash meeting the group rule, is Departure 12's, fixed in the fix wave (I1).
- **Task 8:** the by-date headers take the system plain-list header styling around `NotesGroupHeading` with no padding of our own; the render method is `window.layer.render(in:)` (`drawHierarchy` gave blank). The render's header bands look grey because its rows lack `listRowBackground`; the simulator showed `paper.page` and no grey band.
- **Task 9:** `paper.panel` on the Mac for every appearance (one token per platform), though in Dark it is a well rather than a lift; `xxs` between the line and the fill and `xs` after it, so the name-to-fill gap (12) is smaller than the fill-to-next-line gap (16); the benchmark is as the stopped attempt wrote it, its figures re-measured; the Notes window was looked at again at 980, 1,100 and 1,200 pt, by date and passage, in Light, Dark and Sepia, and **nothing changed** (the time stays trailing, nothing truncates at 980). The `Text +` deprecation warning in `AboutView.swift` went with the rebuild.
- **The resume:** Settings › About stays outside `LibraryType` (Dynamic Type, its own scaled 520 pt column, `GroupLabel` labels); Matt's People review set the Library pages' type at the reader's size and their sections as a hairline and a page-face heading, so About's labels and the Library's headings differ in look. *Cost:* two looks for two kinds of page. On Matt's list.
- **The simulator slip:** see "Seen live".
- **About on the phone stands on its renders,** having not been reached in the simulator. *Cost:* only that it was not seen live.
- **The phone render's date under its heading (render only).** `t9-phone-notes-day-light.png` shows "Matthew 5:3, Nov 18, 2026" under "Tuesday, November 17": the render's model uses the fixture's Chicago calendar while `PhoneMarkRow` formats in the simulator's zone. In the app both are the reader's own (`.autoupdatingCurrent` since the fix wave), so they agree. No code changed for it (review M11).

**Seen live, and where.** All by the controller, keys or taps only, nothing written.

- **Mac About, after Task 3** (Debug app relaunched on `72ea768` with `-settingsTab about`, idle 4,122 s; ⌘, Space Tab ⇧Tab Space ⌘W): the head in the page face, three sections, one line per source; the focus ring on the line's rounded shape; Space opens the ESV in place (notice, link) and closes it; Tab reaches the link when open. Found L1 to L3 (above). The page's column sits at the left of the 900 pt Settings window, as a Library page does.
- **Mac Notes window, after Task 7** (relaunched on `8983ddf`; Matt's own 104 items; the window 1,728 pt wide under AeroSpace; ⇧⌘N, ↓ ↓ ↑, then `-notesBrowserSort reference`, ↓ ↓; no Return, no Delete): day headings with counts ("1 item", "100 items"), the time trailing each row, the marked words in the page italic on their colour, three lines of note across blocks with links in the accent, the "2 versions" mark, the hairlines inset and the full-width rule between days; ↓ from nothing took the first row, ↓ crossed into the next day, ↑ came back; the wash over the padded area with no hairline on it; the list scrolled to keep the selection in view. By passage: book headings (Genesis, Psalms, Zechariah "96 items"), the date trailing, ↓ crossing from Genesis into Psalms. Nothing wrong seen.
- **The simulator, after Task 8** (iPhone 18 Pro Max, taps): the Notes tab by date with its headings ("Wednesday, November 18" to "Tuesday, November 10", counts "2 items") in Headline and secondary ink on `paper.page`, no grey band, rows as before with their dates, hairlines tinted; the ⋯ menu opened and dismissed. **A slip:** one tap sent in the screenshot's pixel frame landed at the page's foot and moved the reader from Psalm 23 to Psalm 24, which can sync to Matt's Debug apps; a following tap selected Psalm 24:1 (its menu shown, nothing chosen); the reader was put back by Library › Psalms › 23, as found. Settings › About was not reached there.
- **Not seen live:** anything since Task 8. None of Task 9's About changes (L1's `paper.panel` on the Mac, L2, L3's fill under the line) has been seen in the app: Matt is at the Mac, and this project does not restart his Mac Debug app on this build (the coordinator brings the branch back). Task 9's renders stand for them, and the ring beside the fill and the fill in Dark on the real Settings window are only reasoned.

**The whole-project review and its fix wave.** The review (Opus, 2026-11-24, read-only at `3aeb9d5`; `2026-11-24-milestone-11-about-and-notes-final-review.md`, committed `4831fd3`) found **0 Critical, 1 Important and 11 Minor**, and judged the branch ready to merge with fixes. The fix wave (Opus; `4bdd972` and the record's commit) built, by cause:

- **I1, the selected last row of a group rested on the group rule.** Departure 12 put the full-width rule directly under a group's last row with no space of its own, so a selected last row's wash met a 1 pt line; most of Matt's days hold one note, so this was what selecting most rows by date looked like. Ruled: spec 5.3 binds over Departure 12. The rule sits `xxs` under the last row (`NotesBrowserList.spaceAboveGroupRule`, pinned by `aGroupsLastRowStopsShortOfTheGroupRule`), the next heading's `md` stays, and nothing else in the list changed (`row(_:)`, the focus stop, the keys, `onDeleteCommand` and `scrollTo` are not in the diff; `NotesBrowserWindowTests` pass). Rendered with Romans 8:28 (Today's last of two) and Psalm 23:2 (a one-note day) selected, by date and by passage, in Light and Dark, before and after: the wash now stops 4 pt short of the rule. The 600 pt default window still shows five notes in full (R9). DESIGN.md and DESIGN.json follow; the backlog's clause is gone.
- **M3, a wrapped use left its dot at the end of a line.** The words after the name were " · use" with an ordinary space on both sides of the dot; `CreditLine.afterName` now puts a no-break space after it, so a break falls before the dot and "· section headings" moves as one (pinned by `aWrappedUseKeepsItsDot`; seen in Mac renders at 300 and 320 pt, Berean Standard Bible and Theographic). The backlog line keeps only the link's wrap.
- **M4, the Notes model's calendar and locale were frozen at launch.** Their defaults were `.current`, a snapshot taken when the app built the model; they are `.autoupdatingCurrent`, so after a change of time zone or region the day headings, the row's time and the time filter's cutoff follow at the next rebuild (pinned by `theModelFollowsTheReadersZoneAndRegionAsTheyChange`; every other test keeps its fixed calendar).
- **M9, the window tests' suite comment** now says which four tests were pinned first and never edited, and which two the redesign added.
- **M1, M10, M11** are this record: L3's cost names both ways back; the header names both branches; the benchmark's margin is noted beside its figure; the phone render's date is recorded as render only.
- **M2, M5, M6 and M8** are on Matt's list below, each with its cost; **M7** (the note line's measure) is in the backlog. The deferred minors the review ruled "Defer" stand.

The numbers after the fix wave: package **1,839** (1,417 + 241 + 52 + 96 + 33; three new tests), iOS `ScriptureUITests` **1,264**, the Mac Debug build green (not launched), checkers **69 / 23 / 0** with no new finding in a touched file. Under the Mac's load (load average 8 to 9, Matt at the Mac) the package run carried two timing issues, both in project 3's People code: `peopleInFirstChroniclesOpensWithItsFirstPersonChosen` read 167.1 ms in the run and 157.9 ms alone (bound 160, passes); `davidsPageInSecondSamuelOpens` read 166.8 ms in the run and 158.7 and 151.0 ms alone (bound 150, fails, as ruled at Task 10 and declined by the review). `NotesBrowserBenchmarkTests` read 7.2 ms in the run (bound 10).

**The re-review and the final runs.** The scoped re-review of the fix wave (Opus, `4831fd3..d5ebdad`) found every finding addressed and no new breakage; `row(_:)` and the list's focus stop, keys and scroll untouched, no must-not-change test edited. The final runs at `d5ebdad`, one after another: the Mac Debug build, package **1,839** (1,417 + 241 + 52 + 96 + 33) with the same two timing issues in project 3's People code (alone: 1 Chronicles 156.0 ms, bound 160, passes; David in 2 Samuel 158.9 ms, bound 150, fails; this project changed no file those pages use since `ca102d1`, where David read 141.1 ms alone), iOS `ScriptureUITests` **1,264**, the iOS Debug build; checkers **69 / 23 / 0**. David's bound is Matt's to settle (raise it, or speed the wider tree up); it is in the final handover's known limits. **The Mac Debug app was not restarted on this build** (Matt was at the Mac; the coordinator brings the branch back), and nothing of Task 9 or the fix wave has been seen live.

**For Matt**, in the order to look.

1. Spec 10's five items:
   - [ ] The Notes window: each note reads as its own block; days as headings by date, books by passage; the time in each row.
   - [ ] A note that starts with a `#` heading no longer previews larger than its reference.
   - [ ] The phone's Notes tab: the same day headings; its rows otherwise as before; a `#` heading at row size there (Search was already plain).
   - [ ] Settings › About on the Mac and the phone: the app's name as a title, three sections, one line per source; open the ESV and a typeface, then its licence text.
   - [ ] The Notes window's keys, click, double-click, right-click and Delete with ⌘Z still behave as before.
2. **The Notes window with your own notes, by hand** (Departure 24; nobody drove these): a click selects a row, a double-click opens it in the reader, a right-click selects it before its menu opens, Return shows it, Delete asks and ⌘Z brings it back; deleting a day's last note lands on the next day's first. The click tests could not run offscreen (above).
3. **About on the phone:** it stands on renders only. Install it with `Scripts/install-phone.sh debug` (your word first; the phone unlocked, ProtonVPN off), then Settings › About: the three sections, the ESV open, a typeface's licence text, and the largest text size.
4. **About on the Mac, since Task 9:** the opened block on `paper.panel` (clear in Light and Sepia, a well in Dark), the name not moving when a line opens, and the ring on the line with the fill just under it (L3). For L3 against the mockup's look, the review set `live-p5/a2c.png` (Task 3: the fill behind line and block) beside `renders/project-5/t9-crop-open-light.png` (now).
5. **The calls you may want otherwise:** Departure 2 (the ERV shows no use), 3 (the uses' words), 5 (the phone on `paper.page`, the Mac's block on `paper.panel`), 9 (the day headings' words), 12 (the group rule now `xxs` under a group's last row), 15 (the row's layout), 20 (the phone's book headings have no count); R15 (a kept version's words on no fill); L3 (the fill under the line, not behind it); Settings › About outside `LibraryType` (its labels and the Library pages' headings differ in look).
6. **The whole-project review's points for you** (none is a defect against the spec):
   - **M2, the Mac's opened fill in Dark is a well.** `paper.panel` is #191D22 in Dark, darker than the Settings window, so the opened block sinks while the other tabs' grouped boxes rise. *Cost to change:* a Mac pairing that lifts in Dark (`paper.overlay` in Dark, `paper.panel` in Light) as a named token with a `PaletteTests` line.
   - **M5, About's column hugs the left of a centred Settings window.** The tab bar and title are centred, the 520 pt column sits at the left (as a Library pane's does). *Cost to change:* one word, `alignment: .center` on the outer frame. **Overturned by Matt, 2026-11-24:** "Nope this needs to be aligned to the center just like the rest of the pages in the settings." Changed to `.center`.
   - **M6, the day heading and a row's passage are one size on the Mac.** `.headline` and `.body` are both 13 pt there, the heading bold and the passage semibold, told apart by position, the count and the rule (spec 5.1 and 5.2 set exactly these). *Cost to change:* a step up for the heading, or the `GroupLabel` style; one line and its DESIGN.md entry.
   - **M8, the licences make a ragged column on the phone.** Each About line picks its own layout (`ViewThatFits`), so some keep the licence trailing and their neighbours set it under the name. *Cost to change:* the under-the-name form for every line at a compact width, a size-class branch in the line's heading.

**What nobody has seen.** VoiceOver anywhere (About's lines and their Collapsed and Expanded values, the headings, the rows' labels); the pointer in either window; the Notes window at 980 and 1,200 pt live (rendered only); Increase Contrast (carried by the tokens' own variants); Reduce Motion (cuts by construction); the phone on a device; a window open across midnight; the list with thousands of notes; ↑ onto a group's first row with its heading above the view (Task 7's Minor, in the backlog); the fix wave's changes in the app (I1's gap under a selected last row, the dot on a wrapped About line, the Notes window after a change of time zone).

### Matt's review, 2026-11-24

On the Mac's Settings › About: "that content should be centered on the settings window." The column is now centred in the window (M5 above). Of the other calls he kept two: the Notes window and About stay at the system text sizes, "as long as it matches the rest of the settings" (they use `.body` and `.callout`, as the grouped forms do), and a day heading the size of the passage under it, "because of the divider lines".
