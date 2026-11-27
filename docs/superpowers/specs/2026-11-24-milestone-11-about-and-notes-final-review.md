# Milestone 11, project 5: the whole-project review (Settings › About and the Notes window)

Reviewer: Opus, 2026-11-24, read-only on `.claude/worktrees/milestone-11-about-and-notes` (branch `milestone-11-about-and-notes`, head `3aeb9d5`, tree clean). One reviewer, no subagents; the diff was read in passes (the two review packages, then the final source of every changed file, then `07da1f7..HEAD` per file for `NotesBrowserView`, the model, the query, the row, the phone screen, `NoteBodyText`, `NoteMarkdown` and `Credits`). Matt's People commits (`01af3d4..ca102d1`) were looked at only where they touch this project's files (`LibraryPageTitle`, which About's head uses).

Authority: the spec `2026-11-23-milestone-11-about-and-notes-design.md` (with its section 11), mockup `about-and-notes.html` (About A, Notes 3), CLAUDE.md, PRODUCT.md, DESIGN.md, the plan's Departures, Global Constraints and pre-flight rulings, and the ledger `progress.md`.

## Verdict

**Ready to merge: with fixes** (one Important, small). No Critical. The Notes window's behaviour is unchanged where it must be, the spec is met with recorded calls, the UI rules hold, the tests pin real behaviour and the record is accurate in all but a few sentences. The one Important item is a plan-mandated look that breaks spec 5.3's own aim and shows on most of Matt's notes; it is a two-line fix.

Counts: **Critical 0, Important 1, Minor 11.**

## Checks run

- **Checkers** (the plan's commands, from the worktree root, once each): SwiftLint **69**, impeccable-lint **23**, asset-catalog checker **0** (exit 0). Equal to the recorded figures and no higher than the coordinator's ceiling (69/23/0). The findings left in this project's files are the old ones the record names: SwiftLint `NotesBrowserView.swift:62`, `:63` (the hidden ⌘F button) and `PhoneNotesScreen.swift:59` (R20); impeccable-lint `NotesBrowserView.swift:198` (the `onTapGesture` in `row(_:)`, Departure 14). Nothing new in a touched file.
- **Departure 14, `row(_:)` unchanged:** `git diff 07da1f7 HEAD -- NotesBrowserView.swift` touches `row(_:)` only at the `NotesBrowserRow(…)` call (`:198-206`: the call split over lines and `parts:` added). The content shape, the click (`:209-212`), the double-click (`:213`), `SecondaryClickHook` (`:215`), the context menu (`:217-229`), the traits and actions (`:230-232`) and `.id` (`:233`) are byte for byte as at `07da1f7`. The list's focus stop, `onKeyPress` ↑ ↓ Return, `onDeleteCommand`, `scrollTo` and the focus-on-appear rule (`:164-191`) are not in the diff.
- **The keys walk the rows in the order shown:** `visibleIDs` (`NotesBrowserModel.swift:122-124`) is now `groups.flatMap(\.entries)`. By passage `groups == sections`, exactly as before. By date `groups == days`, and `NotesBrowserQuery.days` (`NotesBrowserEntry.swift:188-210`) walks the date-sorted entries once, opening a section when the calendar day changes; because the sort is by `modifiedAt` descending, each day's entries are contiguous, so the flattened days equal `entries` in order (pinned by `theDaysAreTheGroupsByDate`, `visibleIDs == entries.map(\.id)`). Section ids are `day-YYYY-MM-DD`, unique for the same reason, and never collide with a book code.
- **Delete and the row that took its place:** `delete(id:)` (`NotesBrowserModel.swift:154-182`) is unchanged and reads `visibleIDs` before and after, so a day's last note hands the selection to the next day's first (`deletingADaysLastNoteSelectsTheNextDaysFirst`). Undo, the confirm dialog, "Discard" for a kept version and its non-destructive role are not in the diff.
- **`scrollTo` identity:** the inner `ForEach` is keyed by `entry.id` (`NotesBrowserView.swift:148`) as both old `ForEach`es were, and the row keeps `.id(entry.id)`; the live pass saw the list follow the selection across days.
- **Kept versions:** the sixth segment, the rows' parts (`NotesBrowserRowParts.swift:57-58, 77-83`) and the popover subject (`NotesBrowserRow.swift:94-97`) carry today's behaviour; `keptVersionsListUnderTheirOwnFilter` walks them with keys and Return.
- **The preview's reach:** `previewLines` has one caller (`NotesBrowserRow.swift:57`), so the run-on preview and the row-size heading reach no other `NoteBodyText`; `Credit.use`/`shownUse` has one reader (`CreditLine.swift:22`), so the lower-case uses reach no other surface.
- **Renders and captures looked at:** `t9-mac-about-esv-nasb-open-light`, `t9-s-dark`, `t9-crop-open-light`, `t9-notes-day-abide-1100-light`, `t9-phone-notes-day-light`, `t9-phone-about-esv-open-light`; live `a0`, `a2c`, `a4c` (About after Task 3) and `n3s` (the Notes window with Matt's notes), plus a crop of `n3s` at the selected row's foot. The mockup's opened row (`about-and-notes.html:18`, `.crow.open`) was read for L3.
- **Not run:** the test suites (as instructed). No live pass: Matt is at the Mac.

## Critical

None.

## Important

### I1. The selected last row of a group sits on the group rule (plan-mandated)

- **Where:** `NotesBrowserView.swift:137-139` (the `HairlineRule` drawn directly under the previous group's last row, with no space of its own) with `:148-157` (the hairlines hidden beside the selection only). Plan Departure 12; Task 7's deferred minor; the record's Calls 12.
- **What:** spec 5.3 says the selection wash "hides the hairlines on either side of it, so the wash never sits on a line." The plan put the full-width group rule directly under a group's last row and kept it always shown, so when the last row of a group is selected its wash meets the rule with no gap: the wash's rounded foot rests on a 1 pt line. The live capture `live-p5/n3s.png` shows it on Matt's own notes (Zechariah 14:21 selected, the rule flush under the wash), and most of Matt's days hold one note (`n3s`: Friday, Tuesday, Monday, Thursday each "1 item"), so this is what selecting most rows by date looks like, not a corner case. Spec 5.1 keeps the rule and spec 5.3 forbids the wash on a line; the plan resolved the tension against 5.3 without saying so in the spec's terms.
- **Why it matters:** the redesign's purpose is that a note's edges read clearly; a wash welded to a rule reads as a box with a bottom border, which is the "card by reflex" look DESIGN.md bans, on the row the reader is looking at.
- **Fix:** give the group rule its own `xxs` above it (`HairlineRule().padding(.top, AppSpacing.xxs)` at `:138`), so a group's last row ends `sm` inside its wash and the wash stops 4 pt short of the rule; the next heading's `md` stays. Every other measure in the list is unchanged; the R9 floor loses 4 pt per group boundary (re-check `t9-notes-day-default-600-light` still shows five notes). Alternative if Matt prefers: hide the group rule while the group's last row is selected (`NotesBrowserList.showsRule` already has the shape), but that contradicts spec 5.1's "always". Record the change against Departure 12 and drop the "selected last row's wash" clause from the backlog line.

## Minor

### M1. L3 (the opened fill under the line) is defensible, but its recorded cost leaves out the third option

- **Where:** `AboutView.swift:114-135` (the line padded `xs` on no fill; the block's fill `xxs` below it); spec 11 Calls, "Task 3 / Task 9, L1 to L3"; DESIGN.md Credit line.
- **What:** spec 4.3 and mockup A put the whole opened row, line and block, on the fill (`.crow.open { background:var(--panel); margin:2px -10px; padding:8px 10px }`). Task 9 moved the fill under the line so the line's focus ring and the fill never cross. Reading `VersePanelRowAction` (`VersePanel.swift:76-90`) confirms the reason: the ring is drawn on the line's radius-`md` focus shape, which includes the line's `sm` side padding, so with the fill behind both the ring sat on the fill's top edges (live L3). The new look works in the renders: the chevron points down, the block's text starts on the name's edge, and the gap above the fill (8 + 4) is smaller than the gap below it (8 + 8), so the block reads as the line's. Measured on `a0.png` the ring sits about 3 pt outside the line's shape, so `xxs` (4) leaves about 1 pt between ring and fill: "never cross" holds, but only just.
- **The record's cost** says that if Matt wants the mockup's look "the fill goes back behind the line and the ring goes round the whole opened row". That is not the only way back: the fill can go back behind line and block (as Task 3 had it, `a2c.png`, where the ring on the link sat cleanly inside the fill) with the ring kept on the line and the line's focus shape inset from the fill's edges (a `.contentShape(.focusEffect, …)` inset by `xxs`, or the fill padded `xxs` outside the line), so the ring sits inside the fill instead of on its border. Tab, Space, Return and the one-button element are untouched by that.
- **Fix:** none needed before merge. Correct the cost sentence in spec 11 and put both looks in front of Matt side by side (`live-p5/a2c.png` against `renders/project-5/t9-crop-open-light.png`).

### M2. The Mac's opened fill in Dark is a well while the sibling tabs' boxes lift

- **Where:** `AboutView.swift:104-110` (`paper.panel` on the Mac for every appearance).
- **What:** in Light `paper.panel` (#EDF1F4) on the white Settings window is a clear step (L1 fixed). In Dark it is #191D22, darker than the window, so the opened block sinks while the other Settings tabs' grouped boxes rise. The record says so ("a well, not a lift") and it is not seen live.
- **Fix:** on Matt's list as recorded; if he finds it odd, a Mac pairing that lifts in Dark (`paper.overlay` in Dark, `paper.panel` in Light) needs a named token and a `PaletteTests` line, not an inline choice.

### M3. A wrapped use breaks after its middle dot

- **Where:** `AboutView.swift:178` (`Text(" \u{00B7} \(use)")`).
- **What:** on the phone (`t9-phone-about-esv-open-light.png`) "Berean Standard Bible ·" ends one line and "section headings" starts the next; the dot belongs with the use. The backlog already carries it ("About's long lines on the phone").
- **Fix:** a no-break space after the dot (`" \u{00B7}\u{00A0}\(use)"`), so a break falls before the dot and "· section headings" moves as one; delete that half of the backlog line. One character, cheap enough for the fix wave.

### M4. The model's calendar and locale are frozen at launch

- **Where:** `NotesBrowserModel.swift:69` (`calendar: Calendar = .current, locale: Locale = .current`); the one caller, `Apps/Shared/AppModels.swift:57`, takes the defaults once per launch.
- **What:** before this project the row's date was formatted with the current locale and time zone at each draw, and the time filter's cutoff used `.current` at each call. Now the day headings, the row's time and the filter's cutoff use the zone and region of the moment the app started. After a time-zone change (travel) or a region change in System Settings, the Notes window shows times and day boundaries in the old zone until a relaunch, while the rest of the app has moved.
- **Fix:** default to `.autoupdatingCurrent` for both (tests keep passing fixed values). Cheap; fix-wave material.

### M5. The About page hugs the left of a centred Settings window

- **Where:** `AboutView.swift:51-53` (`.frame(maxWidth: maxWidth, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)`).
- **What:** in the Settings window (900 pt under AeroSpace in `a0.png`) the tab bar and title are centred and the 520 pt column sits at the left with the rest blank. Spec 4.2 says "as a Library page is", and a Library page is a pane in a split view, where left alignment reads as a column; a Settings tab is a centred sheet. The record notes the placement without calling it.
- **Fix:** Matt's call. Centring the column (`alignment: .center` on the outer frame) is one word.

### M6. The day heading and a row's passage are the same size on the Mac (spec-mandated)

- **Where:** `NotesGroupHeading.swift:20-22` (`.headline`), `NotesBrowserRow.swift:29-31` (`.body.weight(.semibold)`).
- **What:** on macOS `.headline` and `.body` are both 13 pt; the heading is bold and the passage semibold, so in `t9-notes-day-abide-1100-light.png` "Today" and "John 15:4" read as one level, told apart only by position, the trailing count and the rule. Spec 5.1 and 5.2 set exactly these styles, so this is not a build defect.
- **Fix:** none now; worth one line on Matt's list ("the day headings and the passages are the same size; a step up for the heading, or the GroupLabel style, is the alternative").

### M7. The note line has no measure in a wide window

- **Where:** `NotesBrowserRow.swift:48-70`.
- **What:** in `n3s.png` (1,728 pt) a note's line runs to about 170 characters; at the default 1,100 pt about 140. PRODUCT.md's first principle is the page's measure; the three-line cap limits height, not width. Out of spec scope.
- **Fix:** backlog: cap the quote and note column at a scaled measure (the time stays trailing).

### M8. Each About line picks its own layout, so the licence column is ragged on the phone

- **Where:** `AboutView.swift:144-161` (`ViewThatFits` per line).
- **What:** on the phone (`t9-phone-about-esv-open-light.png`) ESV, ERV, WEB, Literata and 3dicons keep the licence trailing while their neighbours set it under the name, so the eye finds the licence in two places down one section. Spec 4.3 asks for `ViewThatFits` and nothing truncates, so this is a polish point.
- **Fix:** Matt's call; on a compact width the under-the-name form for every line would read as one column.

### M9. The suite comment in `NotesBrowserWindowTests` says "never edited since"

- **Where:** `NotesBrowserWindowTests.swift:11-12`.
- **What:** Task 7 added `downCrossesFromOneDayToTheNext` and `theKeysStillWalkAcrossHeadingsAndRules` to the file. The record says it accurately ("added … and edited nothing in it"); the comment does not.
- **Fix:** "Its first four tests were pinned on the window as it was …; never edited since."

### M10. The record's open ends

- Spec header line 3 still names branch `milestone-11-ui-improvements`; the work is on `milestone-11-about-and-notes` (Task 10 review).
- Spec 11, line 174: "The whole-project review and its fix wave: below." has nothing below yet. Fill it from this review and the fix wave.
- The new `NotesBrowserBenchmarkTests` bound is 1.5 × the median (10 ms against 6.6), the same margin as the benchmarks that failed under load 13 in Task 10's run; expect it to join the known flakes under full-suite load. A sentence in the record beside the other timing benchmarks is enough.

### M11. The phone render's row date disagrees with its heading (render only)

- **Where:** `t9-phone-notes-day-light.png`: "Matthew 5:3, Nov 18, 2026" under "Tuesday, November 17".
- **What:** the render's model uses the fixture's Chicago calendar while `PhoneMarkRow` formats in the simulator's zone. In the app both are `.current`, so they agree (and M4's `.autoupdatingCurrent` keeps them agreeing). Noted so nobody reads the render as a bug; no fix.

## The deferred minors, triaged

None must be fixed before merge except the one raised to Important.

| Ledger item | Status now | Ruling |
|---|---|---|
| Task 1: the Return-at-the-sheet pin is frozen behaviour; four compound `#expect`s | Stands | Keep. The test says it fails by design if Delete becomes the default button; that is the right tripwire. |
| Task 2: `CreditLine.address` untested across the catalogue; a `var` for a `let`; a force-unwrap in a test | Stands | Defer. `address` is exercised by About's renders for every link; low risk. |
| Task 3: the name drops 4 pt on open | Fixed in Task 9 (L2; `AboutView.swift:117-118`) | Closed. |
| Task 3: the chevron code twice; redundant `= []` defaults | Fixed (one `chevron(_:)`, `:164-173`; the internal init has no defaults, `:19`) | Closed. |
| Task 3: doubled parentheses in DESIGN.md's Fact list line | Not found in the current Fact list entry (DESIGN.md:404) | Closed. |
| Task 3: the Light step faint | Fixed in Task 9 (L1, `paper.panel` on the Mac) | Closed; Dark is M2. |
| Task 4: two compound `#expect`s | Stands | Defer. |
| Task 5: a one-element `VStack`/`ForEach` in `NoteBodyText.body` | Stands (`NoteBodyText.swift:78-85`) | Defer; harmless, and the full (non-preview) path needs the stack. |
| Task 6: no test for a thread with an empty last turn, or for a book heading's date in `spoken` | Stands | Defer; `make` handles both by construction (`NotesBrowserRowParts.swift:50, 59`). |
| Task 7: ↑ onto a group's first row can leave its heading above view | Stands (backlog) | Defer; correct to backlog. |
| Task 7: the key-walk guard cannot fail on draw order | Stands | Defer; the keys are real events through the focused list, which is what matters. |
| Task 7: the selected last row's wash sits on the group rule | Stands | **Fix before merge: Important I1.** |
| Task 8: `model.groups` read twice with index pairing; no test of the spoken label | Stands (`PhoneNotesScreen.swift` `PhoneNotesGroups.body`) | Defer; both reads are in one body evaluation, so they cannot disagree. `headingSpoken` is tested in `theCountsWordFollowsTheFilter`. |
| Task 9: L3's grouping rests on the chevron and 4 pt; the `xxs` gap reasoned, not measured | Stands; measured here at about 1 pt clear (M1) | Matt's list, with M1's correction to the cost. |
| Task 10: the call mark once in the header; the spec header's branch; David's benchmark sentence; the review placeholder | Stands | Fix with the record update (M10); David's benchmark is project 3's and stays as ruled. |

## Critique (`/impeccable-swift critique`, run in one pass: no subagents)

Register: product. Scene: the study desk, both hands on the keyboard, daylight and lamp.

- **AboutView / CreditLineView.** Reads as a colophon, not a form: the app's name in the page face, Light, at the title size, a quiet version line, three tracked labels in `ink.verse`, one line per source with its licence at the edge. The rows are separated by rhythm alone and the opened block is a tonal step with no stroke, so nothing is a card. Typography is semantic throughout (`.body`, `.callout`, `.caption`, `GroupLabel`), colours are tokens, spacing is `AppSpacing` by name, the column and chevron column are `@ScaledMetric`. Motion is opacity and rotation only, `.snappy`, cut under Reduce Motion, never a frame. Points: M1 (L3), M2 (Dark well), M3 (the dot), M5 (left in a centred window), M8 (ragged licence column on the phone). AI-slop test: passes; nothing here is a template.
- **NotesBrowserRow.** The fuller row does what Matt asked: the passage leads, the marked words sit on their own colour in the page's italic, the note follows in full ink, and `xs` inside against `sm` + rule + `sm` between makes each note a block (`t9-notes-day-abide-1100-light.png`, `n3s.png`). Kinds differ by their marker and by which lines appear, not by chrome. The time is monospaced, tertiary and trailing. Points: M6 (heading and passage the same size), M7 (no measure).
- **NotesGroupHeading.** Simple and correct: title, trailing count with monospaced digits, one header element with a spoken count. Shared by both apps without platform branches.
- **NotesBrowserView.list.** The list stays one focus stop with the keys on the model; headings and rules are not stops; the hairlines fade with the wash and keep their point so nothing jumps. Point: I1.
- **PhoneNotesScreen.** The day headings drop into the plain `List` as `Section` headers with the same component; rows, swipes and menus untouched. The by-passage headings stay title-only (Departure 20, backlog).
- **States.** Empty, filtered-empty and search-empty states are the window's existing `ContentUnavailableView`s, untouched; a day with nothing left after a filter has no heading (`theDaysFollowTheFilterAndTheSearch`). Full state with 104 real notes and a 100-item day was seen live.

Heuristic scores (0-4): visibility of system status 4; match with the real world 4 (Today, Yesterday, the weekday); user control 4 (nothing changed in keys or undo); consistency 3 (M2, M5, M6); error prevention 4; recognition over recall 4; flexibility 4; aesthetic and minimalist design 3 (I1, M7); help with errors 4 (unchanged); documentation 4.

## Strengths

- **The behaviour was pinned first and held.** Task 1's hosted window tests send real key events through the focused list on today's code and still pass on the new list; `row(_:)` is provably untouched; delete and its successor rule read `visibleIDs` exactly as before. This is the right way to redesign a surface whose keys must not move.
- **One grouping, made once.** `NotesBrowserQuery.days` is a single linear pass over the already-sorted entries (6.5 ms for 2,000 notes in a debug build), kept beside `sections` in `rebuild()`, never in a row's body, and `groups` makes the list, the keys, the delete rule and the phone read one thing.
- **The words are pure and tested.** `CreditLine`, `NotesBrowserRowParts`, `dayTitle`, `countLabel` and `headingSpoken` carry every string a reader or VoiceOver meets, with Foundation's own forms (U+202F, en_GB's order) asserted rather than hand-built, and the midnight, same-second and clock-ahead edges pinned.
- **The heading fix is surgical.** `headingsAtTextSize` is a flag on one parser and has exactly one preview caller on each platform; every other note surface keeps its `.title3` headings.
- **The catalogue stays one record.** Three `Credit.Section` cases and the reworded uses live in `Credits`; the view derives everything, and `noWordSaysUsedByPermission` guards the licensing rule.
- **The UI rules are clean.** No inline colour, no `.font(.system(size:))`, no `.secondary`, no new shadow or material, `HairlineRule` for every rule; the checkers went down (71 → 69, 27 → 23).
- **The record is unusually honest.** Spec 11 names every unattended call with its cost, every thing nobody has seen, and the simulator slip.

## Recommendations

1. Fix I1 and re-render the default 600 pt window and a selected single-note day.
2. In the same wave, the one-character M3 and the two-word M4 (`.autoupdatingCurrent`); delete the matching backlog half for M3.
3. Update spec 11: M1's cost sentence, M9's comment, M10's branch and the review/fix-wave paragraph.
4. Put M1, M2, M5, M6 and M8 on Matt's list beside the existing calls; M7 to the backlog.

## Declined to judge

- **David's page benchmark over 150 ms** (`LibraryBenchmarkTests.davidsPageInSecondSamuelOpens`): project 3's code, untouched here; ruled in the ledger.
- **Matt's People commits** (`01af3d4..ca102d1`): not this project's; only `LibraryPageTitle` (About's head) was checked, and it keeps Dynamic Type under the default `.system` `libraryType`.
- **A conversation whose title ends with its place showing the place twice** ("Summarize this chapter: Genesis 1 · Genesis 1", `n3s.png`): today's rule (`hasPrefix`), which spec 5.2 keeps "as today".
- **The phone's rows showing a full date under "Today"**: spec 5.5 keeps `PhoneMarkRow` unchanged on purpose.
- **VoiceOver, the pointer, Increase Contrast and the phone on a device**: not observable from here; the record lists them as unseen and Matt's list carries them.
- **Per-row `NotesBrowserRowParts.make` (two `Date.FormatStyle`s) on each list re-evaluation**: cost scales with realised rows only, as the old row's own date formatting did; not a regression worth a finding.
