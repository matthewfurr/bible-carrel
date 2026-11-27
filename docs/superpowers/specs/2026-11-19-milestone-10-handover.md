# Handover: milestone 10 (all six projects accepted; merged into main, not pushed; Release apps on milestone 10)

Written 2026-11-19, when the last of milestone 10's six projects was built. It replaces the working handover, `2026-11-17-milestone-10-handover.md`, which grew a section per project and held the prompt that started each session. That file is removed; its last form is in commit `d8f234b` (`/usr/bin/git show d8f234b:docs/superpowers/specs/2026-11-17-milestone-10-handover.md`). The per-project specs and plans still name it; they are records and were left as they are.

**In one line:** all six projects are built, accepted by Matt and merged into `main` (not pushed). On 2026-11-20, on his word, both Release apps were updated to milestone 10, so every app he uses (Release and Debug, Mac and iPhone) is on this code.

**What is Matt's to do, in order** (the detail is under "What comes next"):

1. Nothing more on project 6 itself: **he accepted it on 2026-11-20.** Both Debug apps were brought to its code on his word ("Yes, both"). Of Export All Data and Import Data on the Mac he said "Ok. Tested and that all works."; asked whether that called project 6 done, the two-device "2 versions" check included, he answered "Yes, it's done". He did not say which of his three checks he ran, so if anything in project 6's "not checked by anyone" list is ever reported wrong, start there.
2. ~~Say when the rehearsal folder may be removed.~~ Done: removed on his word, 2026-11-20.
3. Answer what he wishes of "Choices still Matt's". None blocks anything.
4. ~~Decide about merging.~~ Done: merged into `main` on 2026-11-20, on his word. The worktree and the branch were removed on his word the same day, after the six ledgers were copied into the repository. Pushing is still his.
5. ~~Decide when the Release apps move.~~ Done: both updated to milestone 10 on his word, 2026-11-20 ("Update the release apps").

## Where things are

- **Repo:** `/Users/matt/Code/reading-through-scripture`. Milestone 10 was built in the worktree `.claude/worktrees/milestone-10-study-tools` on the branch `milestone-10-study-tools`, cut from `main` at `89f8a95`; both were removed on 2026-11-20 after the merge, on Matt's word.
- **Merged into `main` on 2026-11-20** (a merge commit, no fast-forward; `main` had not moved from `89f8a95`, so the merged tree is the branch's tree exactly, the one both suites passed on). In the main checkout itself, after the merge: the Mac Debug build succeeded (it rebuilt that checkout's Bible database at schema 5), the package suite passed 1,509 and the iOS suite 1,028. **Nothing has been pushed.** The worktree and the branch are kept: the worktree holds the git-ignored ledgers under `.superpowers/sdd/`, and removing it deletes them. Matt's uncommitted app-icon change on `main` (`AppIcon.icon/icon.json` and one new image) was not touched by the merge and is still uncommitted.
- **Tests:** package 1,509 (1,097 in 105 suites in the main bundle, beside 241, 52, 91 and 28); iOS `ScriptureUITests` 1,028 in 100 suites; both Debug builds succeed. The Task 13 implementer ran all four one after another at `af73ff7`, and the controller ran both suites again itself at `d8f234b` (the same code; the commits between are documents): 1,509 and 1,028, all passing.
- **The Bible database is at schema version 5** (`Build/bible.sqlite`: 341,282 cross-reference links, 3,067 people, 1,287 places, 501 events). `Scripts/ensure-bible.sh` rebuilds it when the version in `BibleSchema.swift` changes, from the caches of `Scripts/fetch-crossrefs.sh` and `Scripts/fetch-theographic.sh` (pinned by digest, outside the repository).
- **The synced store has eleven models:** the seven it had, a reading plan and a tick from project 5, a kept version and a deletion marker from project 6. A note also gained three optional values. The list is written once, in `MarkupContainer.models`. **The synced preferences are twenty. ⌘K has 35 commands.**
- **Matt's decisions this milestone** are in the main spec's milestone 10 entry, in each project's spec, and in the memory file `project-milestone-10-scope.md`. Work set aside is in `docs/BACKLOG.md`. The mockups he chose from are in `docs/superpowers/specs/milestone-10-mockups/`.

### Which builds are on which code

| What | Code it is on | Note |
|---|---|---|
| Release apps, Mac and iPhone | **milestone 10** (`main` at `ee61cc3`) | Updated on 2026-11-20 on Matt's word ("Update the release apps"). First a dated copy of his real notes folder, taken with the Release app not running: `~/Library/Application Support/ReadingThroughScripture copy before milestone 10 (2026-11-20)` (3 notes, 5 highlights, integrity check ok). Then `Scripts/install-app.sh`: the Mac app opened with his notes all present, the four new tables added, and sync set-up, import and export ended `failure none`, no error logged. Then `Scripts/install-phone.sh release --go-live`: the install succeeded; nobody has opened the phone's app since. **Never run milestone 9 again on either device**: it would strip the new kinds. The same day, on Matt's word, `Scripts/install-app.sh` was changed to install the Mac app as `/Applications/Bible Carrel.app` (the Dock showed the old file name) and the app reinstalled; it opened with no error logged |
| Debug apps, Mac and iPhone | **project 6** (the head, `77d37e9`) | Moved there on 2026-11-20 on Matt's word ("Yes, both"). The Mac's: a fresh Debug build, quit by path and reopened; it opened at his reading place (Ezra 4) with no error logged, and its sync set-up, import and export ended `failure none`. The phone's: `Scripts/install-phone.sh debug` straight after; the install succeeded. Nobody has opened the phone's app since |
| The `.dev` store on this Mac | opened by project 6's code | **No build from project 5 or before may ever be run on it again** (it would strip kept versions, markers and the notes' version values, as well as plans) |
| The Mac Debug app's bundle on disk | project 6 | Since the worktree was removed (2026-11-20) it runs from the main checkout's `Build/DerivedData/Build/Products/Debug/`, built at the merge; quit by the old path and reopened from this one the same day. The Dock may keep the old path's icon until it is refreshed |
| The simulator's Debug app | a build from the middle of project 5 | Holds no plan |

**The rehearsal identity** is a separate app identity made for sync rehearsals (`com.matthewfurr.ReadingThroughScripture.rehearsal`, with its own iCloud container). Its App ID and container stay on Matt's developer account for good, as he approved. **Its folder on this Mac and its preferences were removed on his word on 2026-11-20**; a rehearsal makes fresh stand-in stores in seconds (the memory file `env-standin-store-and-signing.md` has the recipe).

### The one rule that outranks the rest

**An older build does not refuse a store a newer build has opened. It opens it and strips out the kinds of record it does not know:** plans and ticks from project 5; kept versions, deletion markers and a note's three version values from project 6. With sync on they come back from iCloud when the newer build next opens the store. What had not yet been sent does not, and with sync off nothing does but what a backup holds. Both specs first said an older build "cannot" open such a store; project 5's rehearsal showed otherwise. Across devices an older build is safe: it skips records it does not know and they stay in iCloud.

So:

- **No older build is ever run on a store a newer one has opened.** That already binds the `.dev` store on this Mac.
- **The Release apps are updated only on Matt's word, and never rolled back.** Both on the same day is tidier, not required: across devices an older build is safe.
- **Nothing has to come first** (settled 2026-11-20). The store check is milestone 12's, read-only by Matt's choice and needing no new stored value if a rehearsal bears that out; only builds that carry it are protected, so it cannot guard the milestone 9 to 10 update. The Production schema check matters only if the app ever moves from the Development environment, which both builds use today (`docs/BACKLOG.md`, "Before the app is given to anyone else").

## Read these first

1. `CLAUDE.md`, `PRODUCT.md`, `DESIGN.md` in the repository root. `DESIGN.md` is current through project 6 and is the authority on how everything looks and behaves.
2. This file, all of it.
3. `docs/superpowers/specs/2026-11-16-milestone-10-keeping-data-safe-design.md`, sections 10 ("For Matt") and 11 ("As built"): the project Matt has not seen.
4. `docs/BACKLOG.md`: what was set aside, and the two items that come before any Release update.
5. `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`, the main spec. Search "Milestone 10". All six boxes are ticked (the sixth on 2026-11-20).
6. `README.md`: building and running, the probes, the data file's keys, the older-build rule.
7. `docs/superpowers/process/implementer-rules.md` and `reviewer-rules.md`, before dispatching anyone.
8. The memory files `env-live-pass-traps.md`, `env-standin-store-and-signing.md` and `env-headless-ui-snapshots.md`.

### Where each project's full record is

Each spec ends with an "As built" section: what differs from the spec, every ruling made on Matt's behalf with what it costs if wrong, what was seen and by whom, what nobody has seen, and his own list. Specs are `docs/superpowers/specs/2026-11-16-milestone-10-<name>-design.md`; each plan is `docs/superpowers/plans/<date>-milestone-10-<name>.md`; each whole-project review is `docs/superpowers/specs/<date>-milestone-10-<name>-final-review.md`.

| # | Project | `<name>`, and its "As built" | Ledger in `docs/superpowers/ledgers/milestone-10/` |
|---|---|---|---|
| 1 | Verse basics | `verse-basics`, section 13 | `2026-11-16-milestone-10-verse-basics` |
| 2 | Finding (search, ⌘K) | `finding`, section 11 | `2026-11-16-milestone-10-finding` |
| 3 | On a verse | `on-a-verse`, section 11 | `2026-11-16-milestone-10-on-a-verse` |
| 4 | The Library | `library`, section 12 | `2026-11-18-milestone-10-library` |
| 5 | Reading plans | `reading-plans`, section 12; its plan ends with "Rehearsal results" | `2026-11-19-milestone-10-reading-plans` |
| 6 | Keeping data safe | `keeping-data-safe`, section 11; its plan has two "Rehearsal results"; a second review, `…-fix-wave-review.md` | `2026-11-19-milestone-10-keeping-data-safe` |

**The ledgers** were the git-ignored `progress.md` of each project's workspace. On 2026-11-20, before the worktree was removed, each was copied into the repository as `docs/superpowers/ledgers/milestone-10/<name above>.md` (the README there says what was kept and why). The task briefs, task reports and diff packages beside them were not kept; a ledger still names them.

## What milestone 10 contains

Six projects, built in order, each on the one before.

- **1. Verse basics.** A tap (iPhone) or click (Mac) selects the whole verse and shows its menu; a tap or click away only deselects. The Mac reader has single keys (J and K walk verses, 1 to 9 colour, N a note, B a bookmark) and a sheet of every shortcut (⌘/). Passage links (`bible://`; `bible-dev://` in Debug) and Copy Link. The Notes window's quiet selected row. About, with every credit.
- **2. Finding.** Search over the text on the device, with phrases, scope, order and "Did you mean". A new ⌘K: commands, chips to narrow, Recent, ⌃Tab to step the scope. Matched words are semibold and underlined. The phone's search follows the same rules.
- **3. On a verse.** Compare Translations and Cross-References, two separate panels: a popover on the Mac, a sheet on the phone, C and R from the keyboard. Cross-references come from OpenBible.info. Each panel can hand its verses to the assistant.
- **4. The Library.** The Mac's front page is a contents page with a pane of the chosen book's chapters. Rings round the chapters the reader has marked. People, Places (with a map) and About for each book, from Theographic's data. Years are a setting, with a one-time notice. A person or place opens by name from search, and Back from a passage returns to the same person.
- **5. Reading plans.** A plan of weeks and readings with a meeting date. The church's PDF is read into a review that is also the editor. On the Mac, this week is a band over the contents and sits behind a toolbar button in the reader, and there is a plan window (⌥⌘P). On the iPhone, a Plan tab between Read and Notes. Ticks sync.
- **6. Keeping data safe.** A note changed on two devices before they synced keeps both texts: the note shows the winner and a quiet "2 versions" mark that opens the versions (Use This One, Keep Both in the Note, Discard). A note deleted on one device and edited on another leaves the edited text as a kept version with no note (Restore as a Note). Everything the reader has made can be written to one JSON file and read back; an import adds what is missing and changes nothing (File › Export All Data… and Import Data…; Your Data in the phone's Settings).

## What Matt has confirmed

He accepted projects 1 to 5 in the words below. **In no case did he say which items of his list he tried,** so each spec's "not seen by anyone" list stands. If something in one is later reported wrong, start there.

- **Project 1 (2026-11-17).** After using both Debug apps he overturned two lines of the spec (a tap or click away only deselects; the Mac's click opens the menu every time) and found two defects, all fixed that day. Of the final build: "This is good to go now." Earlier he checked the Notes window by hand: click, arrow keys and right-click.
- **Project 2 (2026-11-17).** On the Mac: "All checked on Mac". After the phone's install: "Checked and all good." He answered its four open choices: commands stay above Scripture and notes; matched words semibold and underlined on both apps; ⌃Tab for the scope; ⌘K clears when it closes.
- **Project 3 (2026-11-18).** He asked for one change, the phone's bar order, and of that build said "Looks good." Asked whether that also called the project done, the Mac popover included: "Yes, it's done". He did not say he drove the popover with the pointer.
- **Project 4 (2026-11-19).** After the phone's install ("Yes, install"), asked whether it was done: "Yes, it's done". He answered none of its open choices.
- **Project 5 (2026-11-19).** He approved the rehearsal identity, chose the year rule for the church's dated plan (it starts 15 September 2026, nothing flagged) and dates in his region's order, and had both Debug apps moved to its code ("Yes, both"). After using them: "Everything else looks good". Once the older-build rehearsal had passed: "Yes, it's done".

**Project 6: accepted on 2026-11-20** ("Yes, it's done", after "Ok. Tested and that all works." of the export and import on the Mac; he did not say which checks he ran, and nothing below was named by him). When it was built no one had seen it. It is built, reviewed whole (0 Critical, 5 Important, 14 Minor), fixed in one wave, re-reviewed (all addressed, nothing new of weight), and rehearsed twice with two real synced stand-in stores, before the fixes and after. No text was lost in any clash or delete. The controller made one live pass, keys only: it saw the "2 versions" mark in the notes column and the Notes window, and ⌘K's two new commands. **Nothing in project 6 that needs a click has been seen live by anyone,** and neither Debug app is on its code.

## Choices still Matt's

One list to answer down. Each is built as written; the named section says what each costs if he says otherwise. None blocks anything.

**Projects 1 to 5** (he accepted each without answering these):

1. **Project 1** (spec section 13). Link text in the accent on a selected row's tint is 4.33:1 in Light: keep, or strengthen. Two rows of the shortcuts sheet ("Search the Notes browser", "Export notes") sit under "Notes Column": leave, move, or rename the group.
2. **Project 2.** Nothing open.
3. **Project 3** (spec section 11). The Mac popover is the system's translucent chrome where the mockup was opaque paper, and it stays on the selected verse while the chevrons step to another. Whether C and R should switch or close an open panel. Ask About These is dimmed, with no word why, when every link is weak. Smaller: the sheets' titles, the short credit at the foot, roman and italic in the rows. Two leftovers in the simulator's Debug store are his to delete or keep: a cut-off conversation on Esther 8:9 and a note "R" on Psalm 23:2.
4. **Project 4** (spec section 12, "For Matt"). The four departures (Easton's own file not fetched; the pane's smaller cells; the dark ring a little lighter; the ring a rounded rectangle and a place's page under the map). How a verse on a Library page is reached from the keyboard on the Mac, and what ⌘[ does with a view open. Dates off not reaching the dictionary entries. Looks: Acts's 101 overlapping pins, David's family in one wrapped row, a name shown twice, a page's column at the left of a wide window. A dozen smaller ones are listed there. And whether he had answered the dates notice himself before an implementer's slip removed the answer; if so, it shows once more.
5. **Project 5** (spec section 12, "For Matt"). The eight departures; most likely to matter are the empty circle in grey with the ticked one in the accent, and no hairlines between a week's readings. Ticked passages in the faintest ink. The band's two closing rules: keep both, or drop one. The word "tick" in "Restored 1 reading plan and 2 ticks." On the phone, passages one to a line (about 640 pt for a week of five) or on one line where they fit. Where Delete Plan… lives.

**Project 6** (spec section 11). **The nine departures:**

6. Records that share an identity are read as one and not deleted (the spec said "made one").
7. The spec's "an older build cannot open the store" is corrected to the rule above. A fact, not a choice.
8. Times are written as his region writes them ("Today 8:14 AM").
9. VoiceOver reads the mark as part of its row and as an action of the row; in the phone's note sheet it is a button.
10. The Mac popover is the system's chrome, not the mockup's opaque paper.
11. An import counts a file's text as already here when the note was edited from it. This holds for one sitting only: a note edited twice on one device since the export gets the old text as a kept version, to discard once.
12. The phone's export always includes conversations; only the Mac has the checkbox.
13. The rehearsals ran in the rehearsal identity, not in stores of the Debug app. How it was done, not a choice.
14. A file's note for a highlight that already has another note becomes a kept version of that note.

**The plan's five questions, none answered:**

15. A deletion marker stores short digests of the deleted text and the texts it was edited from, never the text.
16. The tidy-up does not delete records that share an identity (as 6).
17. An import counts a text the note was edited from as already here (as 11).
18. "Kept versions" is offered in the filter only while there is one.
19. Deleting a note that shows "2 versions" leaves the other text under Kept versions until it is discarded or restored.

**And:**

20. **The versions popover is 380 pt wide.** The brief said 330, at which the three choices stack.
21. **The Notes window's filter** is a row of buttons when the window is at least 1,000 pt wide (five choices) or 1,200 (six), and a menu below that. The window opens at 1,100, so a store with a kept version shows the menu until the window is widened. The thresholds come from renders, not the live toolbar.
22. **An imported note is journaled as this device's own text.** The cost, in a rare sequence: one kept version to discard once.
23. **The journal outlives its store:** a store reset by hand or emptied by an account change turns every entry into a kept version with no note.

**Across the milestone:** pushing. The store check is settled: read-only, in milestone 12 (the backlog's first section).

## Not checked by anyone

Gathered by surface; the full lists are in each spec's "As built". Nobody is recorded as having tried these. Matt may have, since he accepted projects 1 to 5 without saying.

- **The Mac, with the pointer.** Almost every agent look on the Mac was by keys or by render.
  - Project 1: whether a click away with the menu open deselects, and whether a double-click selects the word. Both rest on what AppKit reports when a modal menu closes; if either fails, the fix is a floating bar and needs a mockup.
  - Projects 2 to 4: a click outside ⌘K or a popover, a row's click, Open, the scope and Translations… menus, either Ask, a click or double-click on a book, a person's page with Open and Back, the map's camera.
  - Project 5: the whole editor, the plan window, the band and the reader's button. **No controller live pass was made at all.** The spec's "For Matt" has a 30-step live look in order, the editor first.
  - Project 6: the versions popover and each choice, ⌘Z after Discard, the File menu, the panels, the alerts, an export and an import end to end.
- **The Mac's keyboard and focus.** The contents page taking the keyboard back when the app returns to the front (one unproven attempt). Focus and Return through the plan editor's rows, and whose undo its sheet uses. Tab reaching the versions mark.
- **A real iPhone.** No agent has seen any of the milestone on a device. Parts of projects 1 to 5 were seen in the simulator; project 6 was never built for it.
- **Across devices.** A tick or a plan crossing between Matt's own devices; the two-device clash through the real apps (his first check on project 6); three devices; a change pushed while the app is running; a plan left open overnight.
- **VoiceOver, large text on the Mac, Reduce Motion and Increase Contrast** on every new surface; Dark and Sepia in a live window on most.
- **The Release build.** Nothing in the milestone has been built or run as Release.
- **Still open from milestone 9:** the Mac's verse popover from a reference in a note, on a click.

## Known limits

- **The older-build rule.** Nothing in the code enforces it yet.
- **One case of a lost text is left** in project 6: one device typing back its own earlier text exactly while another device edits. Backlog.
- **A needless kept version now and then,** discarded once: after more than eight changes of device offline on one note; a note imported here and then edited elsewhere in two sittings; with an older build on the other device.
- **The probes refuse the main store file, not the `.dev` iCloud database.** A named stand-in store of the Debug app still syncs to Matt's phone.
- **A plan-only store's daily backup is skipped** while the newest backup has marks; the backup counts highlights and notes only.
- **A plan saved from an editor left open** replaces whole an edit that arrived from another device meanwhile.
- **The PDF reader is built for this church's two layouts** and refuses others, which can be typed in.
- **On the Mac a verse on a Library page needs the pointer.**
- **The cross-references are pinned to a file only a GitHub mirror still serves;** OpenBible's own address serves a newer one, so an uncached build depends on the mirror. Backlog: re-pin.
- **Timing benchmarks can fail under full-suite load** and pass alone. Rerun one alone before treating it as real.
- **Plan files' checkboxes were never ticked.** The specs' "As built" sections are the record.

## What comes next

1. **Matt's look at project 6: done.** He accepted it on 2026-11-20 ("Yes, it's done"). The steps below are kept as the record of what the look was to be; he did not say which of the three checks he ran.
   - **Done on 2026-11-20, on his word ("Yes, both"):** both Debug apps are on this code (the Mac's restarted, then the phone's installed). No build from project 5 or before may be run on the `.dev` store on this Mac again.
   - **Then his three checks** (the spec's section 10, "For Matt"; section 11 puts beside each what nobody could check):
     1. With the iPhone in Airplane Mode, edit one note there and on the Mac; turn Airplane Mode off; the note shows "2 versions" on both, and each choice does what it says.
     2. Export All Data on the Mac; open the file; import it straight back and see "already here".
     3. Delete a note, import the file, and the note is back.
   - When he accepts it, tick box 6 in the main spec and record his words.
2. **The rehearsal folder: removed** on his word, 2026-11-20. The App ID and the iCloud container stay on his account.
3. **Merged, on his word (2026-11-20);** the worktree and branch removed the same day, the ledgers copied in first. Pushing waits for his word.
4. **The Release apps: updated to milestone 10** on his word, 2026-11-20 (see the table under "Which builds are on which code"). Never a rollback.
5. **Next, by Matt's word of 2026-11-20:** milestone 11 is UI improvements (his to describe); milestone 12 is the read-only mode for a store a newer build has opened (the backlog's first section). **After that:** `docs/BACKLOG.md`. Marked wanted there: online translations (parked in `2026-11-12-online-translations-handover.md`; it needs a brainstorm with Matt before any design), built-in reading plans, and Paul's journeys on the map. Its last sections hold what must be settled before the app is given to anyone else.

## Numbers Matt may ask to tune

Describe these to Matt by what they do, never by name. Milestone 9's table (the chapter cards, the loupe, the swipes) still holds and is in `2026-11-13-milestone-9-handover.md`.

| What it does | Where | Now |
|---|---|---|
| How wide the versions popover is | `VersionsMark.swift`, `width` | 380 pt |
| The window width at which the Notes window's filter becomes buttons, not a menu | `NotesBrowserView.swift` | 1,000 pt for five choices, 1,200 for six |
| How wide the Notes window opens | `ReadingThroughScriptureApp.swift` | 1,100 pt |
| How long a record of a deleted note is kept, to catch an edit made elsewhere | `VersionKeeper.markerLifetime` | 90 days |
| How many changes of device a note remembers | `NoteVersion.ancestryLimit` | 8 |
| How strong a cross-reference must be to show before Show all, and how many show | `CrossReferences.swift`, `minimumVotes`, `shortLimit` | 4 votes, 6 rows |
| How long after a reader key a scroll still counts as the key's own | `ChapterTextController+Keys.swift`, `keyScrollLifetime` | 0.3 s |
| How narrow the Mac's book pane can be, and how wide | `ChapterPaneMetrics.swift`, `fiveAcross`, `widestShare` | five chapters across at the page size; at most 40% of the window |
| How big a chapter's square in the pane is beside the page size | `ChapterPaneMetrics.swift`, `cellWidth`, `cellHeight` | 2.9 by 2.2 × the page size |
| The fewest chapters across | `ChapterPaneMetrics.swift`, `fewestColumns` | 3 |

## How to see the UI without stalling

Matt was sent broken visuals in milestone 9 by sessions that never looked, and in this milestone several defects reached him or the live window past renders and reviews. Look before you report, and know what each way of looking cannot show. None of these prompts for anything.

- **An offscreen render** (a temporary test that hosts the view and writes a PNG to the session scratchpad; remove the test before committing).
  - iPhone: host the view in a `TestWindow` and render `window.layer` with `layer.render(in:)`. `drawHierarchy` returns blank there, system glass does not draw, and a system button in the bar blanks the picture.
  - Mac: an offscreen hosting view written to PNG.
  - **A render cannot show** focus or its ring, a key, a click, a popover's anchor or chrome, a toolbar, a panel, an alert, undo, map tiles, or a text size on the Mac. It has no accent asset, so a tinted button draws system blue.
  - A render sized to its content cannot show a list that does not hug its rows. Render the panel inside a taller container.
  - **Render poetry as well as prose** (Psalm 1) for anything that shows a selection or a highlight. The full-width fill Matt found was invisible in prose.
- **One live pass by the controller is worth more than another round of renders.** Budget one per UI task.
  - Keys only, and only under the rules for Matt's Mac below.
  - Find the Debug app's window id with a small `swift` script over `CGWindowListCopyWindowInfo`, filtered by its pid (the large window, not the 33 pt menu-bar strips). Run `screencapture -x -o -l<id> out.png` in the background and kill it after a few seconds.
  - ⌘K selects the row under a resting pointer. Capture the window and check which row is selected before pressing Return.
  - AeroSpace may keep a window off the current workspace. Do not move Matt's windows to reach it.
- **A subagent cannot converge on focus blind.** The Mac popover took four blind rounds. Read the focus code yourself, or make a live pass, before a third.
- **The simulator** ("iPhone 18 Pro Max", the iOS Simulator control tool): launch the Debug app, wait about 8 s, then look.
  - The tool's touches never begin a screen-edge pan; plain pans work.
  - Never drive the selection menu at the accessibility text sizes: a late tap and a typed key wrote a note there, and a sideways swipe ran an Ask.
  - Answer no notice and change no synced setting there (see "Rules").
- **Probes and stand-in stores** are launched hidden and read through `/usr/bin/log show` and `sqlite3 -readonly`, not by looking.
- **Ask Matt to look** when a behaviour shows only in a live window (a flash on a click, a right-click, a drag). He answers quickly.
- The memory files `env-headless-ui-snapshots.md` and `env-live-pass-traps.md` have the recipes.

## Things that cost time

**How the work is run**

- **A claim about what Apple's frameworks do is a guess until rehearsed.** Two specs said an older build cannot open a newer store; it can, and strips it.
- **What Apple's sync does with a clash** (rehearsed): the store that syncs last wins, not the one that edited last. The losing text is destroyed everywhere and nothing reports it. Values merge one at a time, not a record at a time. A delete always wins. A change from another store on the same Mac arrives only on launch.
- **Check signing before a plan that needs a new identity.** A new App ID or container needs Xcode signed in to Matt's account and Apple's current licence agreement accepted; only he can do either. Ask at the start, not at the gate. A container just made is refused for about five minutes.
- **A pre-flight scan of a plan before its first task** found fourteen conflicts in each of the last two projects, each ruled before any code.
- **One fix wave, in the review's own order,** every item named by its cause, then one scoped re-review. No second wave.
- **The test first.** A worker that writes the code before the test loses the red run; a compile failure counts as the red.
- **Pin a benchmark's fixture to the real case,** with the worst case beside it and labelled. Measure the largest real case before the first review: 1 Chronicles' people took 950 ms until the list was made lazy.

**SwiftUI, AppKit and UIKit**

- **A row that appears eighty times must be its own `View`.** Rows written as functions on one large view cost about 120 ms a keystroke until they were.
- **`focusEffectDisabled` on an ancestor switches off every focus ring inside it.**
- **The Mac's menu is modal and holds the keyboard.** The second click of a double-click arrives while the first click's menu is open. A key typed while a popover holds the keyboard goes to the popover.
- **The window takes ⌃Tab as a focus-moving key before SwiftUI sees it.** A small view catches it as a key equivalent.
- **Every text field in a window types through one shared editor.** Remember the field, not the editor.
- **The system's selection fill runs to the column's edge** on the Mac. The reader draws its own and hides the system's by a private view name; a pixel test fails by name if that ever changes.
- **Esc on the Mac's front page belongs to a hidden cancel button.** A new full-window key handler should not take Esc.
- **`MainWindowView`'s body is at the type checker's limit.** **A test never makes a `Map`.**
- Still true from milestone 9: a toolbar's principal slot is not centred; `.overlay { }` swallows alignment guides (use `.position`); a static func on a `View` traps off the main actor unless `nonisolated`; SwiftUI's menus ignore a checkmark in a `Button`'s label (use a `Picker`); a pan's `translation(in:)` reads zero as a slow drag begins; the system drops haptic impacts fired under 0.05 s apart. Its Core Image and Info.plist notes are in milestone 9's handover.

**Tests and tools**

- **Three counts are pinned by tests** and change with the code: every menu chord is in the shortcuts catalogue (a `.keyboardShortcut(` the test cannot read fails it); ⌘K's command count, in two tests; the synced preferences, by name.
- **Two records written in the same millisecond have no order.** Give a fixture's records distinct times.
- **The "file is not a database" lines in both test logs** come from a test that feeds a corrupt store on purpose.
- **Swift Testing's `#expect` cannot contain a mutating call.**
- **`log` is a zsh builtin here;** use `/usr/bin/log`. A Bash command may not begin with `sleep`.
- **`rtk` shortens or mangles command output,** `find` and `grep` included. Use `rtk proxy <command>` when you need all of it.

## Rules that bind every session here

- **Git.** Use `/usr/bin/git`, one git command per Bash call, with no `cd … &&`, loops or shell variables; in a worktree a guard refuses compound commands. Work on a branch, never on `main`. End commit messages with the attribution line the harness gives.
- **Never, without Matt's word:** push, merge, `Scripts/install-app.sh`, `Scripts/install-phone.sh release --go-live`, anything under `/Applications` or `~/Library/Application Support/ReadingThroughScripture` (his real store, its keychain item, and the rehearsal folder too).
- **Stored data.**
  - The older-build rule at the top of this file.
  - Matt approved exactly what each spec's "What is stored" section says. A new stored value needs his approval first.
  - The Debug (`.dev`) apps are separate from Release, but they sync to an iCloud database his Mac's and phone's Debug apps share. Create no test note, plan or setting in them.
  - **A `-storeName` store of the Debug app is not isolated:** it shares the `.dev` iCloud database and preferences. Rehearsals use the rehearsal identity; the reading-plans plan's "The rehearsal identity" has the build recipe.
  - **A synced setting changed in the simulator, or a notice answered there, reaches his Debug apps.** Do neither.
  - A test never writes to the real clipboard, the `.dev` store or the network. Outside data is fetched only by a build script with a pinned digest, or by the controller into the scratchpad.
- **The probes** (Debug builds only; launch arguments; the README has their verbs).
  - `-syncProbe` makes one change to a bookmark or a chapter note.
  - `-syncProbeOffline YES` opens a named stand-in store without its link to iCloud, so a change stays on this Mac until the next ordinary launch. It is refused in the default store.
  - `-planProbe make | large | clear` saves or removes a stand-in plan.
  - `-versionProbe` stands in for an editing sitting and for each choice on a kept version.
  - **The three that write refuse the main store** (the store named `Markup`, in any capitals, and the default store with sync off). **None refuses a `-storeName` store of the Debug app,** which still reaches `.dev`. Use them in the rehearsal identity.
  - Launch them hidden, `open -n -g -j <app> --args …`, and end them by pid.
- **Matt's Mac. He is usually using it.**
  - **AeroSpace owns the Option chords** (`alt-tab`, `alt-h/j/k/l`, `alt-1` to `alt-9`) and `ctrl-left`/`ctrl-right`. They never reach an app. Never propose or send one; read `~/.config/aerospace/aerospace.toml` before proposing any key. Keyboard navigation is on, so Tab moves focus unless the app takes it.
  - **Send keys only while the app under test is frontmost, matched by pid, never by name.** The Release app has the same process name. The Debug app's pid: `pgrep -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app/Contents/MacOS"`. A click or scroll only with the point inside its window (every live pass so far was keys only). Never move his windows.
  - **Check idle time first:** `ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000)}'` gives seconds since his last input. At 0 he is at the keyboard: do not relaunch or send keys; ask or wait.
  - Subagents never quit or relaunch the Mac Debug app. The controller does, and tells Matt. Never block on a Screen Recording prompt.
- **Models.** The top model is for brainstorming with Matt, specs, plans and whole-project reviews only. Implementers and task reviewers run on Sonnet, or Opus for the hard tasks (TextKit, gestures, focus, sync). Always pass `model` when dispatching.
- **One project per session.** Matt's usage ran out twice when one session carried everything. Keep the controller's context small: hand subagents files, not pasted text, and have them write reports to files. One implementer in the worktree at a time, since builds share `Build/DerivedData`.
- **Before a project is called done:** both test suites and both Debug builds, one after another; the Mac Debug app restarted and the phone's installed (ask Matt first); `DESIGN.md`, `DESIGN.json`, `README.md`, the spec's "As built" and `docs/BACKLOG.md` in step; the main spec's box; a list for Matt of what to try, with what nobody has seen.
- **Mac Debug app:**
  - Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
  - Quit: `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`. Never `pkill -x`, which also quits his Release app. Then `open` the Debug app.
- **iPhone:** `Scripts/install-phone.sh debug`. The phone must be unlocked and ProtonVPN off. Never toggle the VPN.
- **Tests:**
  - Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit`
  - iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`
  - Run builds one after another. Some tests need `Build/bible.sqlite`.
  - The church's two real PDFs are Matt's and stay out of the repository (`~/Downloads`). The check on them is opt-in: `RTS_PLAN_PDFS=… --filter RealPlanPDFTests`.
- **TextKit 2 only:** never touch `textView.layoutManager`.
- **UI rules (CLAUDE.md, DESIGN.md):** no fixed-point fonts in chrome; Palette tokens only; `AppSpacing` and `AppRadius`; no card by reflex; deletes are undoable and never ask; popovers are the system's; the app applies `.glassEffect()` nowhere.

## Working with Matt

- **Do what he literally asked.** Do not substitute a reading of your own for his words.
- **Say plainly what you did not check.** He tests on real devices and finds whatever was guessed at.
- **Record his words exactly, and what he did not say.** "Looks good" has meant one change and not the project; ask which. He accepts a project without saying what he tried, so the unseen lists stay.
- **Plain words, not code names.** Describe a value by what it does to what he sees.
- **Mockups before a visual choice.** He picks; he usually picks the fuller option.
- **He overturns a spec after using the thing.** Two lines of project 1 fell on his first look. Get it in front of him early.
- **Tell him before a step that cannot be undone** (a store moved forward, an identity made on his account), and wait for his word.
- **Decisive and short.** One line per step while working.
- **Never stall.** Do not end a turn waiting on something that is not his decision.
