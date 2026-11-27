# Handover: milestone 11 (all five projects built, Matt's People and About reviews in; none accepted yet; not merged, nothing pushed; Release apps on milestone 10)

Written 2026-11-24, when the last of milestone 11's five projects was built. It replaces the working handover, `2026-11-23-milestone-11-handover.md`, which held the projects' table, the tooling, the rules, the unattended run and the prompt that started each project. That file is removed; its last form is in commit `5c75f92` (`/usr/bin/git show 5c75f92:docs/superpowers/specs/2026-11-23-milestone-11-handover.md`). The per-project specs and plans still name it; they are records and were left as they are.

**In one line:** the five projects were built unattended on 2026-11-23 and 24, each reviewed whole and fixed in one wave; Matt has since reviewed the People page in four rounds and About's timeline once, and every change he asked for is built. He has accepted none of the five. Nothing is merged into `main` or pushed, and of the apps he uses only his Mac Debug app runs any of it.

**What is Matt's to do, in order** (the detail is under "What comes next"):

1. Let the Mac Debug app be brought to the whole milestone once the two branches are joined (it lacks project 5's last task and fix wave, and his About review), and say whether to install the iPhone's Debug app (the phone unlocked, ProtonVPN off). Nothing of milestone 11 is on the phone.
2. Look, in the order under "For Matt, by project", and say of each project whether it is done.
3. Answer the calls he wants otherwise. The likeliest are ranked first, just below; the full list is "Choices still Matt's". None blocks anything.
4. ~~Decide David's page benchmark~~: met, 125 ms against 150 (2026-11-24).
5. Decide about merging into `main` (the planning session asks him), and later pushing, and when the Release apps move.

## The calls he is most likely to overturn

Ranked by how likely, from what he has overturned so far. Each is built and costs little to change; the section named has the detail.

1. **The Notes window and Settings › About keep the system's text sizes, not his reading size.** He overturned exactly this on the home page and the Library pages ("this must not being matching what the user has selected for their reading font size"). Nobody made it a call in project 5; About was left outside the Library's reader-size type on purpose, so its section labels also look unlike the Library's new headings (about-and-notes spec, section 11, "The resume").
2. ~~**In a crowded cluster of pins the chosen place's name is not drawn**~~: fixed on his word, 2026-11-24; the chosen name is drawn over the map above every pin (places spec, "Matt's review, 2026-11-24").
3. **Settings › About departs from the mockup he chose:** an opened line's fill starts under the line, not behind it, so the focus ring and the fill never cross; (about-and-notes spec, section 11, L3; the way back is written there). The column that sat at the left of the Settings window (M5) Matt overturned on 2026-11-24: it is centred, as the other tabs are.
4. **The home page at the default size holds three columns of books, so the Testaments stack** (his mockup showed four beside a narrower pane), and a week's five readings wrap four and one (home-page spec, section 12, "For Matt" 1 and 2).
5. **Genesis's timeline folds three runs of lives, so Abraham's life is behind the third Show,** and two eras' headers are drawn twice (about-and-timeline spec, section 14, calls 1 and 2).
6. **Places' list is 32 pt wider than People's to hold three segments,** so the dividing line moves when he switches between them; and other chapters' rows are dimmed to the faintest ink (places spec, calls 2 and 27).
7. **The selection's tint stays a cool green on Sepia paper** in People and Places, since that colour has no Sepia value (people spec, "For Matt" 4; places spec, call 29).

## Where things are

- **Repo:** `/Users/matt/Code/reading-through-scripture`. Milestone 11 was built on the branch `milestone-11-ui-improvements` (worktree `.claude/worktrees/milestone-11-ui-improvements`), cut from `main` at `f33658a`. Projects 1 to 4 and project 5's first eight tasks were built there; then the coordinator made Matt's four People rounds there (up to `ca102d1`). Project 5 stopped once on an expired sign-in at Task 9 and was resumed on a branch of its own, `milestone-11-about-and-notes` (worktree `.claude/worktrees/milestone-11-about-and-notes`), cut from `ca102d1`; Task 9, the review, the fix wave and this file are there. Meanwhile the coordinator made Matt's About review on the first branch (`12b77bb..ff97952`, after `ca102d1`). **The coordinator brings project 5's branch back into `milestone-11-ui-improvements`;** until then neither branch holds the whole milestone. **Nothing is merged into `main` and nothing is pushed;** merging is Matt's word.
- **Tests,** package and iOS `ScriptureUITests`: at the branch's start 1,509 and 1,028; after project 1, 1,536 and 1,029; project 2, 1,594 and 1,078; project 3, 1,678 and 1,134; project 4, 1,737 and 1,189; after Matt's People rounds (`ca102d1`), 1,835 and 1,261; **after project 5, on its branch, 1,839 and 1,264.** The first branch after Matt's About review ran 1,423 in the main package bundle (beside 241, 52, 96 and 33) with the two People benchmarks failing under load, and iOS 1,271. **The joined tree has not been run;** both suites and both Debug builds are run on it before anything else.
- **The checkers** (from the worktree's root; commands under "Rules"): SwiftLint, impeccable-lint and the asset checker read **87, 27 and 0 at the branch's start and 69, 23 and 0 now.** No project added a finding in a file it touched, but one the spec required (a place's chapter dot is hidden from VoiceOver).
- **The Bible database is at schema version 6** since project 2 (it was 5): each event's length, the event it is part of, a life's person, and two named corrections to the data (Death of Moses without Genesis 34:1; Job of Uz without Genesis 46:13). `Scripts/ensure-bible.sh` rebuilds `Build/bible.sqlite` in each checkout when the version changes; the main checkout's is still at 5 until it is built after the merge.
- **Stored data.** Milestone 11 adds nothing to the synced store and no synced preference. **Three device preferences are new,** each kept on one device and not synced, **approved by Matt on 2026-11-23** ("Yes, all three (Recommended)"): how wide the home page's chapter pane is (the Mac), the order of a book's People list, and the order of its Places list. Nothing else is stored.
- **Matt's decisions** are in the main spec's milestone 11 entry, in each spec's Approaches, and in the people and about-and-timeline specs' "Matt's review, 2026-11-24". The mockups he chose from before the build are in `docs/superpowers/specs/milestone-11-mockups/`. The ones he chose from during his People review (`people-fixes.html`, `section-headings.html`) are in the first worktree's git-ignored `.superpowers/brainstorm/3337-1795511528/content/`, and go with it when it is removed unless copied. Work set aside is in `docs/BACKLOG.md`.
- **Milestone 12** is decided and not started: read-only for a store a newer build has opened (`docs/BACKLOG.md`, first section).

### Which builds are on which code

| What | Code it is on | Note |
|---|---|---|
| Release apps, Mac and iPhone | **milestone 11** (`main` at `c6c7101`) | Updated on 2026-11-26 on Matt's word ("Merge, cleanup milestone folder, update release apps."). First a dated copy of his real notes folder, taken with the Release app not running: `~/Library/Application Support/ReadingThroughScripture copy before milestone 11 (2026-11-26)` (the synced store: 3 notes, 5 highlights, integrity check ok). Then `Scripts/install-app.sh`: the Mac app opened with the same 3 notes and 5 highlights, and sync import and export ended `failure none`. Then `Scripts/install-phone.sh release --go-live`: the install succeeded; nobody has opened the phone's app since. **Never run milestone 10 or older again on either device.** |
| The Mac Debug app | **milestone 11** (`main` at `c6c7101`) | Since 2026-11-26 it runs from the main checkout's `Build/DerivedData/Build/Products/Debug/`, built after the merge; quit by the worktree's path and reopened from this one. The milestone worktree and its branches are removed. The Dock may keep the old path's icon until it is refreshed. |
| The iPhone's Debug app | **all of milestone 11**, the same merge | Installed on Matt's word ("Yes, install it", 2026-11-24) with `Scripts/install-phone.sh debug`, and reinstalled after each review round and after the merge. ProtonVPN was on and the install still succeeded. |
| The simulator's Debug app | **project 5's Task 8** | Its reading place is Psalm 23 (see "Things that cost time": a slip moved it to Psalm 24, put back at once; the place can sync to his Debug apps). |
| The `.dev` store on this Mac | opened by milestone 11's builds | Milestone 11 stores nothing new in it, so a milestone 10 build would strip nothing (by construction, not rehearsed). No build older than milestone 10 is ever run on it. |

### The one rule that outranks the rest

**An older build does not refuse a store a newer build has opened. It opens it and strips the kinds of record it does not know** (milestone 10's handover has the detail). Milestone 11 adds no kind of record, so it adds nothing to strip, but the rule still binds: no build older than milestone 10 is ever run on any of Matt's stores, and the Release apps are never rolled back. Milestone 12 is the guard.

## Read these first

1. `CLAUDE.md`, `PRODUCT.md`, `DESIGN.md` in the repository root. `DESIGN.md` is current through project 5 and Matt's reviews and is the authority on how everything looks and behaves. Use `/impeccable-swift` for any UI work.
2. This file, all of it.
3. The five specs' "As built" sections (table below), above all each one's "For Matt" and "What nobody has seen"; and the people and about-and-timeline specs' "Matt's review, 2026-11-24".
4. `docs/BACKLOG.md`: what was set aside, milestone 12 first.
5. `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`, the main spec. Search "Milestone 11". All five boxes are ticked as built, each "waiting on Matt's look".
6. `README.md`: building and running, the probes, the data file's keys, the older-build rule.
7. `docs/superpowers/process/implementer-rules.md` and `reviewer-rules.md` before dispatching anyone. Both still name the first worktree; point them at the next one.
8. `docs/superpowers/specs/2026-11-19-milestone-10-handover.md`: the older-build rule's detail, the probes, and milestone 10's open choices.
9. The memory files `env-live-pass-traps.md`, `env-standin-store-and-signing.md` and `env-headless-ui-snapshots.md`.

### Where each project's full record is

Each spec ends with an "As built" section: what differs from the spec, every call made on Matt's behalf with what it costs if wrong, what was seen and by whom, what nobody has seen, and his list. Specs are `docs/superpowers/specs/2026-11-23-milestone-11-<name>-design.md`; plans are `docs/superpowers/plans/2026-11-23-milestone-11-<name>.md`. Only project 5's whole-project review is in the repository (`2026-11-24-milestone-11-about-and-notes-final-review.md`); the other four were written in their workspaces and are summed up in each "As built".

| # | Project | `<name>`, and its "As built" | Ledger in `docs/superpowers/ledgers/milestone-11/` |
|---|---|---|---|
| 1 | The home page (Mac) | `home-page`, section 12 | `2026-11-23-milestone-11-home-page` |
| 2 | A book's About page and its timeline | `about-and-timeline`, section 14, then "Matt's review, 2026-11-24" (on the first branch until the join) | `2026-11-23-milestone-11-about-and-timeline` |
| 3 | People and the family tree | `people`, section 15, then "Matt's review, 2026-11-24" and its second, third and fourth rounds | `2026-11-23-milestone-11-people` (the unattended build only; the rounds are in the spec) |
| 4 | Places: the chosen pin, and the list's order | `places`, section 14 (its last paragraph: what Matt's People review changed on a place's page) | `2026-11-23-milestone-11-places` |
| 5 | Settings › About and the Notes window | `about-and-notes`, section 11 | `2026-11-23-milestone-11-about-and-notes` |

**The ledgers** were the git-ignored `progress.md` of each project's workspace, copied into the repository at each project's end; `docs/superpowers/ledgers/milestone-11/README.md` says what was kept. The task briefs, reports and diff packages were not kept; a ledger still names them.

## What milestone 11 contains

Five projects of UI improvements, built in order, each on the one before, then changed by Matt's reviews.

- **1. The home page (Mac).** Book names, Testament titles and group labels at the reader's text size, the columns as wide as the widest name, the Testaments stacking at large sizes. The chapter pane's cells at the text size, and a divider to drag the pane wider (more chapters across), double-clicked back to its narrowest; the width is kept on this Mac.
- **2. A book's About page and its timeline.** The book's name as a title, its facts on one edge (Testament, length, writers, span, the five most named people and places). The timeline in the order of history, lives folded from their births and deaths, three or more lives in a row folded under a Show, eras grouped. On the Mac a to-scale chart over the rail, **pinned at the window's top while the rail scrolls under it, its band following the rows in view** (Matt's review); on the iPhone the rail. Schema 6 carries the lengths and eras.
- **3. People and the family tree.** A person's page in About's form; the dictionary entry's whole first paragraph, then Show more; **its verse references are links** (Matt's fourth round). On the Mac a drawn family tree that never scrolls sideways, names one even gap apart, folded partners opening as a second row, a chip never standing for one name, and **the phone's family line in its place when the window is too narrow.** On the iPhone the line of descent and the household. Most named or A to Z, kept on the device. After Matt's rounds, on the Mac: every Library page at the reader's text size, in the reader's own column, centred, its text selectable; each section opened by a hairline and a heading in the page face; a person's and a place's verses in one **References** section, the book the page was opened from first and open; each chapter line reading "Ch 11".
- **4. Places.** The chosen place's pin takes its name where several places share a spot (the cause confirmed live first, in Acts). Most named, A to Z or By chapter; under By chapter, chapter headings, ← and → stepping chapters on the Mac, and a map that frames the chosen chapter's places with the book's others as dots.
- **5. Settings › About and the Notes window.** About as a colophon: the app's name as a title, three sections, one line per source that opens in place to its notice and licence. The Notes window's notes under day headings (or book headings by passage), each a fuller row: the passage, the marked words on their colour, three lines of the note, the time; a hairline between notes, none beside the selection. The phone's Notes tab takes the day headings.

## What Matt has confirmed

- **2026-11-22.** The brainstorm on Opus ("Stay on Opus"); the checkers installed first ("Both"); the order of the projects ("The order you proposed for projects is fine.").
- **2026-11-23.** The five specs ("I approve all 5."); the three device preferences ("Yes, all three (Recommended)"); "No Fable. Opus 5.5 instead of Fable for all projects related to Milestone 11."; and the unattended run ("Please just use subagents to work through all the specs so I can see the results when I return.").
- **2026-11-24, People, four rounds** on David's, Lot's and Benjamin's pages (his words are in the people spec, "Matt's review, 2026-11-24"):
  1. "Fewer" must look like a button; the ":" run was unclear; too much blank space in a wide window; no text could be selected; the text was not at his 18 pt. He chose partners **B** (no fold while the row fits; a second row when not) and wide window **A** (one column at the reader's width, centred, the tree across the page). Built.
  2. The Family heading at the text column's edge, and headings that look like headings (he chose **C**: a hairline, then the heading); names an even, readable gap apart, not spread to the width; "Grandparents and children are at full size too - OK."; a fall-back to the phone's tree when too narrow; "Ch" before chapter numbers. Built.
  3. "Looks significantly better", then: why a chip for one sibling; and one **References** section, the book he came from first and open, the rest closed. Built; Benjamin's chip came from a build older than the fix already made. He set aside a system sidebar for the People and Places lists (backlog).
  4. "So much better. One last finding.": the dictionary's references were not links. Built.
- **2026-11-24, About's timeline** (on the first branch): the chart should pin at the top so the band and the rail show together. This overturned the call to let it scroll, and answered Luke's chart (it now starts at Luke's own story). Built, not yet seen by him live.
- **2026-11-24, the rest of his look.** Of the home page, About, the Notes window and the phone in general: "I have reviewed all of these and they are good including the phone in general." Settings › About: "that content should be centered on the settings window" (built, 3ad1fd7); the system text sizes kept "as long as it matches the rest of the settings"; Notes' day heading at the passage's size kept "because of the divider lines". Genesis's tall pinned chart: "I love it. It looks great." The repeated era headers: "I'll accept it for now." The crowded cluster: "If you have a fix for it, why are you asking? Fix it." (built: the chosen name drawn over the map, merged from milestone-11-places-fixes). David's benchmark: "If there is something you can speed up, then speed it up." (built: 125 ms against 150, merged from milestone-11-perf). The phone's Places sheet "never goes beyond half of the screen" (built, the same Places branch). A bug: "Sometimes the highlight of the horizontal timeline does not work … after scrolling down and back up and then down again" (fixed, b4f0f94: rows the lazy stack made again reported no frame). Merging: "Not yet." Every project is reviewed and called good; merging into main waits on his word.

## For Matt, by project

In this order. Each spec's "For Matt" has the full list and the reasons; this is the short form.

1. **People** (people spec, section 15, and the rounds). The newest work and the most changed. With the joined build: David in 2 Samuel and Benjamin from Ezra at his size: the tree, the second row of partners, the chips and "Fewer", References, the dictionary's links (a click opens the verse); narrow the window past the tree's fall-back; select and copy text. Then the iPhone's line and household, once installed. Not yet seen by him: the fourth round's links, unless his Mac already had them.
2. **About and the timeline** (about-and-timeline spec, section 14, and his review). The pinned chart on About Matthew and About Genesis: scroll, watch the band, click the chart. Genesis's three folds (Abraham behind the third), the repeated era headers, Settings › Show dates off, and the phone at a large text size.
3. **Places** (places spec, section 14, items 1 to 11). Joshua's Jordan and Acts 2's Nazareth (the chosen name in a cluster); Acts and Joshua By chapter, ← and →; the dots; a click on the chosen gathered pin; Back to the same chapter; the phone's sheet.
4. **The Notes window and Settings › About** (about-and-notes spec, section 11). His own notes by hand: a click, a double-click, a right-click, Return, Delete and ⌘Z, a day's last note deleted; the day headings and the fuller rows; About on the Mac (open the ESV and a typeface's licence) and, once installed, on the phone.
5. **The home page** (home-page spec, section 12). Three columns at his size; ⌘+ and ⌘−; drag the divider, double-click it, quit and reopen; a narrow window.

## Choices still Matt's

One list to answer down. Each is built as written; the named section says what each costs if he says otherwise. None blocks anything. The ranked list above picks the likeliest.

**Project 1, the home page** (spec section 12, "Calls"):

1. Three columns of books at the default size, the Testaments stacked (a measurement, not a choice, but his mockup showed four).
2. The week's band holds four readings across at 1,100 pt, not five (call 1).
3. The pane's chapter numbers at his size, 18 pt where they were 12 (item 5 of "For Matt").
4. A drag released below the narrowest keeps the narrowest as a fixed width, no longer following the text size until a double-click (call 10).
5. A scroll bar set to show always narrows the pane's grid at its narrowest, so five across may become four (call 16). The "39 books" count reads small at large sizes (backlog).

**Project 2, About and the timeline** (spec section 14, "Calls" and "Matt's review"):

6. Two eras' headers drawn twice, in Genesis and Acts (call 1); three folds in Genesis, Abraham behind the third (call 2). Accepted "for now" (2026-11-24).
7. The words: the span ("about 4004 to 1635 BC"), lengths ("2.5 years"), and "(by tradition)" after Psalms' six writers (calls 3, 5, 24).
8. A life's name is a link with no link colour (call 22); most of Genesis's later lives are unlabelled bars (item 4).
9. From his review: only the chart pins and the "Timeline" heading scrolls away; the axis's ends name the span's own years; Genesis's pinned chart is tall, five or six rows show under it (review calls 1, 2 and 7). Genesis's tall chart: "I love it." (2026-11-24).

**Project 3, People** (spec section 15; the rounds replace some of the first calls, as the spec says):

10. A focused verse run is in the text's ink on the tint, not the link colour, for contrast (call 33); grandparents are links in the faintest ink (call 9, kept by round 1).
11. The verse popover opens above the run; a dictionary link's popover opens at the pointer (item 2; round 4).
12. Judah has no partner, two mothers instead (call 1); the eleven children with no mother named never open by themselves (call 3); Lot twice on each daughter's page, Terah twice on Isaac's (call 6); the Family fact's words (call 8).
13. On the phone: folds hide only two or more (call 23); the line is one rail row per person, so Bethuel reads as if above Isaac (call 24).
14. From the rounds: the gap 1.5 times the names' size (round 2); the headings at 21 pt for the mockup's 22; the list columns grow with the type; the tree's names are a click on the text, not a button; dictionary links are not Tab stops; References keeps the books he opened or closed while he stays on the person; a bare reference takes the book named before it only with a cue word (rounds 1 to 4, each "Calls").
15. The selection's tint stays cool green on Sepia (item 4).

**Project 4, Places** (spec section 14, "Calls"):

16. ~~The chosen name in a crowded cluster~~: built, the drawn label (2026-11-24).
17. The list 32 pt wider than People's to hold three segments, or a menu at People's width (call 2).
18. Other chapters' rows in the faintest ink (call 27); the book's other places as dots that look like the map's own towns (call 19).
19. The rest he may want otherwise: dots by point (6), a chapter with no place on the map frames the book (7), the chosen heading again clears only the chapter (8), ← and → with none chosen (9), switching to By chapter chooses none (10), a place's chapter change moves the map (11), the heading's tint only with no row chosen (25), the phone's heading as a band (28).

**Project 5, Settings › About and the Notes window** (spec section 11, "For Matt" 5 and 6):

20. About: the ERV shows no use (Departure 2); the uses' words (3); the phone's About on the page's paper, the Mac's opened line on the panel's (5); the fill under the line, not behind it (L3); About outside the Library's reader-size type (the resume); the opened fill in Dark sinks rather than lifts (M2); the column at the left of the centred window (M5); the licences ragged on the phone (M8).
21. The Notes window: the day headings' words ("Today", "Wednesday, November 18") (9); the rule 4 pt under a group's last note (12); the row's layout (15); the phone's book headings have no count (20); a kept version's words on no colour (R15); the day heading and a row's passage the same size on the Mac (M6).

**Across the milestone:** merging into `main`; pushing; when the Release apps move. Milestone 10's open choices (its handover, "Choices still Matt's") are still open too.

## Not checked by anyone

Gathered by surface; the full lists are in each spec's "As built" and each round's "Not seen". Nobody is recorded as having tried these, Matt included.

- **What came last, by Matt himself.** Project 5's Task 9 and its fix wave, and his About review (the pinned chart, the band under a real scroll, the landing under the chart), are on both Debug apps since the merge (2026-11-24) but were checked only in renders until he looks. The People fourth round's linked references reached both apps before his About review.
- **The Mac, with the pointer.** Every agent look on the Mac was by keys or by render.
  - Home page: the resize cursor, the drag, the double-click, a drag the system cancels, the width after quit and reopen.
  - About: a click on the chart, the band moving, the person and "347 more" links.
  - People: a click on a chip, "Fewer", a run or a name; the grown hit areas; a selection drag and ⌘C; References' rows; a dictionary link's popover.
  - Places: a click on a marker or a row; the re-click on a chosen gathered pin; a heading clicked with a row chosen.
  - The Notes window: a click, a double-click, a right-click, Delete with ⌘Z (no click test could run offscreen); Settings › About by the pointer.
- **The Mac's keyboard and focus.** Tab to About's Show and Hide; Tab line to line in a long book; the Order switch and Show more by key; the Mac's fall-back family line by Tab; References' rows by key; ↑ onto a group's first note with its heading above the view.
- **Window sizes.** A live resize across the tree's fall-back width; an open chip across a resize; the Notes window at 980 and 1,200 pt (rendered only); a window at AeroSpace's size (a changed size is not a regression).
- **A real iPhone.** None of milestone 11 on a device. Seen in the simulator: About Genesis and Acts (the rail and a fold), David's line and household, Acts' Places sheet By chapter, the Notes tab's day headings. Never reached there: the phone's Settings › About; References, "Ch" and the dictionary's links; the phone's About page since the chart was pinned (not even rendered).
- **VoiceOver,** anywhere in the milestone: the divider, the rail's rows, the tree's relation groups, the verse lines, the headings, the Places announcements and hidden dots, About's lines, the Notes rows. Each is built and tested as the model the view applies; a hosted view's elements cannot be read offscreen.
- **Reduce Motion, Increase Contrast and Dark and Sepia live** on most new surfaces; the Places map's dots in Dark and Sepia never (the phone's Sepia render came out as Light).
- **Across devices:** the reading place the simulator slip may have synced; the three device preferences staying on their device (by construction).
- **The Release build.** Nothing in the milestone has been built or run as Release.
- **Speed:** the Notes window with thousands of notes; the cost of a drag or a resize on the home page.

## Known limits

- ~~**David's page benchmark runs over its bound.**~~ Met on 2026-11-24: 125 ms against 150, and 1 Chronicles 137 against 160 (milestone-11-perf: the page and the list rows were rebuilt on every update, and the tree laid twice). The front page stays near 87 ms against 100 alone; under a full suite it can miss (people spec's benchmark record).
- **The chosen place's name in a crowded cluster** is not drawn until the reader zooms.
- **Genesis's pinned chart is tall,** and the rail's first height estimate under it is several times too tall, so the scroller's thumb grows as the page is read (backlog).
- **The Mac's Library pages follow the reader size; the rest of the chrome does not:** the view's header line, the verse popover, the Notes window, Settings › About. The iPhone's Library keeps Dynamic Type.
- **After Return walks the tree, the first key only shows the focus ring.**
- **A Notes window left open across midnight keeps yesterday's "Today"** until it next rebuilds; the delete dialog's Delete has no key equivalent, so Return does not confirm it (pinned).
- **The data's own words stand:** the stored "son of …" labels, Easton's spellings, 99 ambiguous and 7 broken dictionary references left plain.
- Milestone 10's limits still hold (its handover, "Known limits").

## What comes next

1. **Join the branches** (the coordinator): project 5's branch back into `milestone-11-ui-improvements`. Then, one after another on the joined tree: both suites, both Debug builds, the three checkers (expect 69, 23, 0). Record the counts in the main spec's entry.
2. **Bring the Debug apps to it.** The Mac's: quit by path and reopen, after checking the idle time, telling Matt. The phone's: `Scripts/install-phone.sh debug`, on his word (phone unlocked, ProtonVPN off). The simulator's too if it is used.
3. **Matt's look,** in the order under "For Matt, by project". When he accepts a project, record his words in its spec and its main-spec box; record what he overturns as his review rounds were recorded.
4. ~~**Merging into `main`**~~: done on his word, 2026-11-26 (`c6c7101`), not pushed. The review mockups were copied to `docs/superpowers/specs/milestone-11-mockups/review-*.html`; the worktree `milestone-11-ui-improvements` and the branches `milestone-11-ui-improvements`, `milestone-11-about-and-notes`, `milestone-11-places-fixes` and `milestone-11-perf` are removed, all merged.
5. ~~**The Release apps**~~: both updated to milestone 11 on his word, 2026-11-26 (see "Which builds are on which code").
6. **Next, by Matt's word of 2026-11-20:** milestone 12, read-only for a store a newer build has opened (the backlog's first section; it needs a spec, mockups for both apps and a rehearsal). **After that:** `docs/BACKLOG.md`; marked wanted there are online translations, built-in reading plans and Paul's journeys on the map.

## Numbers Matt may ask to tune

Describe these to Matt by what they do, never by name. Milestone 10's and milestone 9's tables still hold.

| What it does | Where | Now |
|---|---|---|
| How narrow the home page's chapter pane can be, and how wide | `ChapterPaneMetrics.swift` | five chapters across at the text size; at most 40% of the window |
| How narrow one reading in the week's band can be | `PlanWeekSummary.minimumColumnWidth` | 140 pt (four across at 1,100 pt) |
| How many lives in a row fold under a Show | `TimelineFold.minimumRun` | 3 |
| When a page's facts stack, label over value | `FactList.widestLabelShare` | when the labels take more than 40% of the width |
| Which rows are left off a chart, far from the rest | `TimelineChartModel` (first branch) | at most 5% of rows, beyond a gap of half the span |
| How much of a dictionary entry shows before Show more | `DictionaryEntry.shownLines` | 10 lines |
| How many chapter lines of verses show before "n more chapters" | `VerseLines.shownChapters` | 12 |
| How far apart the tree's names are | `FamilyTreeFolding.namesApart` | 1.5 times the names' size (27 pt at 18) |
| How many names the phone shows before "and n more" | `FamilyLine.shownNames` | 3, folding only two or more |
| How wide the People and Places lists are | `LibraryPeopleView`, `LibraryPlacesView`, `listWidth` | 200 and 232 pt at the system's size, times the text size over 13 |
| When the order switch becomes a menu | `LibraryOrder.swift`, `segmentedWidth` | when the list is narrower than 210 pt on the Mac or 285 on the phone, and always at the phone's accessibility sizes |
| How many lines of a note the Notes window shows | `NotesBrowserRow.swift`, `previewLines` | 3 |
| The space between a group's last note and the rule under it | `NotesBrowserList.spaceAboveGroupRule` | 4 pt |
| How long David's page and 1 Chronicles' People may take to open in the tests | `LibraryBenchmarkTests` | 150 and 160 ms |

## How to see the UI without stalling

Milestone 10's section holds whole; these are milestone 11's additions. Look before you report, and know what each way of looking cannot show. None of these prompts for anything.

- **An offscreen render** (a temporary test that hosts the view and writes a PNG to the session scratchpad; remove it before committing).
  - iPhone: render `window.layer` with `layer.render(in:)` in a `TestWindow`; `drawHierarchy` is blank. A scene-less render shows Sepia as Light, and a plain list's headers look grey without each row's background.
  - **A render's host is white; the real Settings window is not.** About's opened fill looked right in a render and was all but invisible live. Judge a faint fill live, or against the window's own colour.
  - A hosted view exposes **no accessibility elements** offscreen, and a click sent to an offscreen window selects nothing. Test the model the view applies; leave VoiceOver and clicks to a live look, and say so.
  - A pinned or lazy page can be rendered by stepping its scroll (300 pt at a time) in an `NSHostingView`.
- **One live pass by the controller** per UI task, keys only, under the rules for Matt's Mac below.
  - Launch with argument values (`-libraryPlacesOrder byChapter`, `-settingsTab about`, `-notesBrowserSort reference`) so nothing is written to his preferences.
  - **The pane's People, Places and About icons are Tab stops:** ⌘F a book, Tab to the icon, Space. Project 2 believed otherwise and did not reach About; project 4 found the route.
  - **While Matt is reviewing he is at the Mac all day:** no live pass and no restart. Render, and list what only he can see.
- **The simulator:** a tap is in the device's points, not the screenshot's pixels. One tap sent in pixels landed at the page's foot and moved the reader from Psalm 23 to Psalm 24, a reading place that can sync to his Debug apps; put back at once by Library › Psalms › 23. Check the frame before every tap, and never tap near the reader's foot.
- The memory files `env-headless-ui-snapshots.md` and `env-live-pass-traps.md` have the recipes.

## Things that cost time

Milestone 10's list still holds (its handover, "Things that cost time"). Milestone 11 added these.

**How the work is run**

- **Matt overturns unattended calls within hours of seeing them,** and asks for the reason behind a rule ("What is the logic behind using a chip for 1 sibling"). Answer with the rule in plain words, then fix the rule, not the case. Put the build in front of him early; four rounds came in one day.
- **He expects the Mac to follow his reading size everywhere,** and a wide window not to leave blank space. Ask of any new Mac surface whether it follows the reader size.
- **A plan's premise is a guess until checked:** the pane's icons were Tab stops after all; David folded four partners, not three; the spec named "Adam to Lamech" where its own rule gave three folds. Measure first, then build the rule; say where the spec differed.
- **A change meant for the Mac reaches the phone through shared views.** His "the phone unchanged" was broken twice in one round (the page's width, selectable text), and only the review caught it. Check the phone after any Mac change in the shared package.
- **An expired sign-in or a harness stop ends a run** mid-task; a run resumes from its ledger, on a new branch if the old one has moved on.
- **A benchmark read under Matt's load** (load average 8 to 13 while he works) is not a regression. Compare against the commit before, built in a copy, alternating runs at the same load.

**SwiftUI, AppKit and MapKit**

- **A focusable view per line costs about 0.4 ms;** one focusable view per group that walks its own lines on Tab is cheaper. **The system's segmented control costs about 9 ms to make** in a debug build, and a stored preference about 2 more. **A plain button per tree name cost about 15 ms** on David's page: a tap on the text with a VoiceOver action does the same.
- **Build VoiceOver's grouped elements only while an assistive technology is on;** built for every open they cost 8 ms.
- **MapKit draws every title beneath every pin's balloon.** Forcing a title visible and drawing the chosen pin last put its balloon on top, not its name; hiding the other names did not help. In the simulator a tap on overlapping pins goes to a neighbour.
- **A setter that always writes reopened a closed view** (Esc from Places opened an empty People): write only on a change.
- **A lazy stack lands on a row not yet made by estimate;** read the rows made so far and correct, a few times. A lazy rail inside a lazy page made the page's height swing and its end render blank.
- **SwiftUI drew a chip's chevron a point wider than its image** at some sizes: draw in the measured box. **Core Text and SwiftUI can break a line a word apart.**
- **A calendar or locale taken as `.current` is frozen at launch;** use `.autoupdatingCurrent`. Foundation puts a narrow no-break space before AM and PM; never build a time format by hand.

**Tests and tools**

- **The checkers,** installed and committed on 2026-11-22 on Matt's word ("Both"): SwiftLint (Homebrew 0.65.1, `tools/.swiftlint.yml`, fitted to this repository) and impeccable-swift's own `tools/impeccable-lint` and `tools/asset-catalog-checker`, copied from `seansmithworks/impeccable-swift` at `ce30d92`. **87, 27 and 0 at the branch's start, 69, 23 and 0 now.** A project adds none in a file it touches and says in its "As built" which old ones it fixed.
- Milestone 10's notes hold: three counts pinned by tests, no order in a millisecond, the corrupt-store log lines, no mutating call in `#expect`, `/usr/bin/log`, no Bash command starting with `sleep`, and `rtk` mangling output (`rtk proxy`).

## Rules that bind every session here

- **Git.** Use `/usr/bin/git`, one git command per Bash call, with no `cd … &&`, loops or shell variables; in a worktree a guard refuses compound commands. Work on a branch, never on `main`. End commit messages with the attribution line the harness gives.
- **Never, without Matt's word:** push, merge, `Scripts/install-app.sh`, `Scripts/install-phone.sh release --go-live`, anything under `/Applications` or `~/Library/Application Support/ReadingThroughScripture` (his real store and its keychain item).
- **Stored data.**
  - The older-build rule at the top of this file.
  - Matt approved exactly what each spec's "What is stored" says; in milestone 11, the three device preferences and nothing else. A new stored value needs his approval first.
  - The Debug (`.dev`) apps sync to an iCloud database his Mac's and phone's Debug apps share. Create no test note, plan or setting in them, and move no reading place.
  - **A `-storeName` store of the Debug app is not isolated;** rehearsals use the rehearsal identity (milestone 10's handover).
  - **A synced setting changed in the simulator, a notice answered there, or the reader moved there, reaches his Debug apps.** Do none.
  - A test never writes to the real clipboard, the `.dev` store or the network.
- **The probes** are as milestone 10's handover lists them; milestone 11 added none.
- **Matt's Mac. He is usually using it.**
  - **AeroSpace owns the Option chords** (`alt-tab`, `alt-h/j/k/l`, `alt-1` to `alt-9`) and `ctrl-left`/`ctrl-right`. Never propose or send one; read `~/.config/aerospace/aerospace.toml` before proposing any key. Keyboard navigation is on.
  - **Send keys only while the Debug app is frontmost, matched by pid, never by name.** Its pid: `pgrep -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app/Contents/MacOS"` (two worktrees may each have one; match the path). Never move his windows.
  - **Check idle time first:** `ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000)}'`. At 0 he is at the keyboard: do not relaunch or send keys.
  - Subagents never quit or relaunch the Mac Debug app; the controller does, and tells Matt. Never block on a Screen Recording prompt.
- **Models.** Milestone 11 used no Fable, on Matt's word: Opus for plans and whole-project reviews; Sonnet for implementers and task reviewers, or Opus for focus, gestures, TextKit, sync and layout. For milestone 12, ask him; his standing rule is Fable for brainstorming, specs and plans only. Always pass `model` when dispatching.
- **One project per session.** Keep the controller's context small: hand subagents files, not pasted text, and have them write reports to files. One implementer in a worktree at a time, since builds share `Build/DerivedData`.
- **Every UI change goes through `/impeccable-swift`,** each UI task's review runs `audit` or `critique` with the three checkers, and the whole-project review runs `critique`. A pre-flight scan of the plan against the code comes before Task 1.
- **Before a project is called done:** both suites and both Debug builds, one after another; the three checkers; the Mac Debug app restarted (tell Matt) and the phone's installed (ask him); `DESIGN.md`, `DESIGN.json`, `README.md`, the spec's "As built" and `docs/BACKLOG.md` in step; the main spec's box; the ledger copied to `docs/superpowers/ledgers/<milestone>/`; a list for Matt with what nobody has seen.
- **Mac Debug app:**
  - Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
  - Quit: `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`, never `pkill -x`, which also quits his Release app. Then `open` the Debug app.
- **iPhone:** `Scripts/install-phone.sh debug`. The phone must be unlocked and ProtonVPN off. Never toggle the VPN.
- **Tests:**
  - Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit`
  - iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`
  - Run builds one after another. Some tests need `Build/bible.sqlite` and carry `.needsRealBible`.
- **Checkers,** from the worktree's root:
  - `swiftlint lint --config tools/.swiftlint.yml`
  - `tools/impeccable-lint/.build/release/impeccable-lint Packages/ScriptureKit/Sources/ScriptureUI Apps` (build it first if `.build` is missing: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release --package-path tools/impeccable-lint`, about three minutes)
  - `swift tools/asset-catalog-checker/check.swift Apps/Mac/ReadingThroughScripture/Assets.xcassets`
- **TextKit 2 only:** never touch `textView.layoutManager`.
- **UI rules (CLAUDE.md, DESIGN.md):** no fixed-point fonts in chrome (the Library's reader-size type is DESIGN.md's named exception); Palette tokens only; `AppSpacing` and `AppRadius`; no card by reflex; deletes are undoable and never ask; popovers are the system's; the app applies `.glassEffect()` nowhere.

## Working with Matt

- **Do what he literally asked.** Do not substitute a reading of your own for his words.
- **Say plainly what you did not check.** He tests on real devices and finds whatever was guessed at.
- **Record his words exactly, and what he did not say.** "Looks significantly better" came with two more findings; ask whether a project is done.
- **Plain words, not code names.** Describe a value by what it does to what he sees.
- **Mockups before a visual choice.** He picks, usually the fuller option, and quickly (B, A and C in one day).
- **He overturns a spec after using the thing,** and explains why. When he asks why something is so, give the rule, then offer to change it.
- **Tell him before a step that cannot be undone,** and wait for his word.
- **Decisive and short.** One line per step while working.
- **Never stall.** Do not end a turn waiting on something that is not his decision.
