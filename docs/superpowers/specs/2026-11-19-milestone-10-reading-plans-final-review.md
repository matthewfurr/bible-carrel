# Milestone 10, project 5 (reading plans): the whole-project review

Reviewed 2026-11-19, `f2717f6..e995356` (20 commits, 71 files), by reading. Nothing in the repository was changed but this file. No test was run by me: the counts below are the ledger's (package 1,043 passing with one known issue, the iOS suite passing).

**Verdict: ready with fixes.** One possible trap in the editor, five Important findings, and the fix list at the end (38 items). Nothing beyond the spec's section 7 is stored. Nothing reaches the Release apps, and no plan is made in the `.dev` store, until the older-build rehearsal (Task 4, Steps 4 to 13) has been run: it is still owed.

Paths: `PL` is `Packages/ScriptureKit/Sources/ScriptureData/Plans`, `SM` is `Packages/ScriptureKit/Sources/ScriptureModel`, `UP` is `Packages/ScriptureKit/Sources/ScriptureUI/Plans`, `PH` is `Packages/ScriptureKit/Sources/ScriptureUI/Phone`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `MAC` is `Apps/Mac/ReadingThroughScripture`, `SHARED` is `Apps/Shared`.

## How the diff was read

Six passes. New files were read at their paths (the tree is clean at `e995356`, so they are the diff with line numbers); changed files in the diff's hunks.

1. The values and rules: all of `PL`, and `ReferenceParser`'s hunk.
2. What is stored and synced: `PlanRecord`, `PlanStore`, the hunks of `MarkupContainer`, `SeedMerge`, `StoreCopy`, `BackupsModel`, `PreferenceSync`, `AppSync`, `AppModels`, `PlanProbe`; `StoreBackup.markCount` and `SyncCoordinator`'s call sites outside the diff, for the restore and merge paths.
3. The one model and the Mac: `ReadingPlanModel`, `PlanEditorSession`, `PlanEditorView`, `PlanWindowView`, `PlanWindowState`, `PlanReadingViews`, `PlanWeekSummary`, `PlanWeekText`, `PlanDateViews`, `PlanFileImport`, and the hunks of `MainWindowView`, the Mac app, `FrontPageView`, `ContentsPageView`, `PaletteItem`, `ShortcutCatalog`.
4. The phone: `PhonePlanScreen`, `PhonePlanList`, `PhonePlanMenu`, the hunks of `PhoneRootView`, `PhoneShellModel`, `PhoneEdgeSwipes`.
5. Every test in the diff, against the plan's closing table.
6. The ledger, the twelve reports' "(call)" lines, and five of the renders left in the scratchpad (the plan window, the band, the Mac review with every flag, the Plan tab, the phone's review).

The plan document inside the diff was skipped and read at its path (its head, Before Task 1, Departures, Decided here, Global Constraints, Review Focus, Tasks 12 and 13, and the closing table).

## Strengths

- **Section 7 is kept exactly.** `PlanRecord` is `uuid`, `title`, `createdAt`, `modifiedAt`, `weeksData`; `PlanTick` is `uuid`, `planID`, `readingID`, `tickedAt` (`SM/PlanRecord.swift:6-32`). Every attribute is defaulted or optional, nothing is unique, there is no relationship, and `theNewKindsObeyTheStoresRules` reads that off the schema rather than trusting it. The one new synced key is `followedPlanID` (`PreferenceSyncTests.theSyncedKeysAreExactlyThese`). The schema's model list is now written once (`MarkupContainer.models`) and `AppSync.initializeSchema` uses it, which removes the second copy the plan warned of.
- **A meeting date is a day, everywhere.** `PlanDay` does its arithmetic in UTC and no rule takes an instant (`PL/PlanDay.swift`); `aMeetingDateIsACalendarDayInAnyTimeZone` pins Chicago against Tokyo.
- **Records out of step are handled by construction.** A tick points by id, so one that arrives before its plan is kept and not counted (`ReadingPlan.progress`), the merge never deletes a tick for want of its plan (`SM/SeedMerge.swift:231-242`), and a preference naming an absent plan falls back to the newest without being written over (`UP/ReadingPlanModel.swift:89-94`, `thePlanFollowedIsTheStoredOneElseTheNewest`).
- **A plan from a newer build is never written over.** `PlanStore.save` refuses both an unreadable value and an unreadable stored record (`SM/PlanStore.swift:53-55`), and `PlanDeletion` carries the raw bytes so an undo puts back exactly what was stored (`:16`, `:106`).
- **The PDF reader is honest about what it is.** It refuses from the first page (`UP/PlanFileImport.swift:22-24`), runs off the main actor, and is tested through PDFKit on PDFs the tests draw, with the church's files read only by an opt-in test.
- **The UI rules hold across all the new views.** A sweep of `UP` and `PH/PhonePlan*` for fixed-point fonts, inline colours, `.opacity`, system palette colours, shadows, materials, glass and bare numbers for spacing or radii finds none. Rows are rows: the only fills are the `accent.wash` selection at radius `md` and the phone's panel-tone fields, neither with a hairline.
- **One reading row serves three layouts** (`UP/PlanReadingViews.swift:32-136`) and carries the VoiceOver element of 5.5 once: one element, a button whose action ticks, an action per passage that can be opened.
- **The benchmarks told the truth.** Task 12 wrapped the one failing bound in `withKnownIssue` rather than raising it, and reported the hosted keystroke with no bound rather than a flattering one.

## Issues

### Critical (must fix)

**C1. The editor's fields write through positions into a draft that may be gone: a possible trap at Save, Cancel or Remove, and a typed week number can be lost.** Established by reading; not reproduced, because nobody has driven the editor live.
- `UP/PlanEditorView.swift:25-27`: `Binding(get: { session.draft ?? PlanDraft(title: "") }, set: { session.draft = $0 })`. `:35` and `:179` hand each week and reading to its fields as `ForEach` element bindings, which are positions into that array. `:193` binds the week number with `TextField(value:format:)`, which writes when editing ends, not as it is typed.
- What goes wrong. `session.save()` and `cancel()` set `draft = nil` (`UP/PlanEditorSession.swift:105-116`). A field that commits after that (the number field, as its sheet goes) reads the fallback, a fresh one-week draft with new ids, and writes into it by position. For a week other than the first, or a reading other than the first, that position is past the end of the fallback: an index trap. For the first, the write makes `draft` non-nil again and the sheet reopens on an empty plan under a stale heading. Remove Week and Remove Reading have the same shape for the last rows. Separately, a week number typed and followed by a click on Save is not in the saved plan at all, because the field has not committed; on the phone the number pad has no Return, so tapping Save is the ordinary way out of that field.
- Why it matters. The first thing the owner does is import a plan, correct something and Save. The plan is stored before the trap, so nothing stored is lost, but a crash or a reopened blank editor at Save is the worst first impression this project can make.
- Fix. No positional bindings and no fallback. Give `PlanEditorSession` mutators by id (`setTitle`, `setNumber(_:ofWeek:)`, `setLabel(_:ofWeek:)`, `setText(_:ofReading:)`), each a no-op when `draft` is nil; iterate values (`ForEach(session.draft?.weeks ?? [])`) and bind each field with `Binding(get:set:)` over those mutators. Make the week number a text-bound field (digits only, written as typed), so nothing waits for editing to end. Test: after `save()` and after `cancel()`, each mutator leaves `draft` nil; a number typed is in the saved plan.

### Important (should fix in the wave)

**I1. A failed save closes the editor and throws the draft away.**
- `UP/PlanEditorSession.swift:105-110` calls `model.save(plan)` and then sets `draft = nil` whatever happened. `UP/ReadingPlanModel.swift:140-144` swallows the failure into `lastError` ("That change could not be saved. Try it again.").
- Why it matters. "Try it again" means typing 67 weeks again, or importing and correcting again. The store can refuse: a full disk, or the stored record made unreadable by a newer build's edit that arrived while the editor was open (`PlanStoreError.unreadable`).
- Fix. `ReadingPlanModel.save` returns whether it stored (`@discardableResult`); the session closes only on success and otherwise keeps the draft. Show the failure in the editor itself: on the Mac the "Could not save" alert hangs on the window under the sheet (`UP/PlanWindowView.swift:69-77`). Test with a plan whose stored record is unreadable.

**I2. Two records with one identity: the case the ledger flagged, and a tick-loss path beside it.**
- `SM/StoreCopy.swift:125-136` restores a plan and its ticks with their own uuids, as it must. Two devices that each restore before the other's restore has arrived (the phone has Restore too: `PhoneSettingsScreen` passes `backups`) leave two `PlanRecord`s with one uuid on both.
- The plan. `SM/PlanStore.swift:39-43` lists it twice (two rows with one id in the plans menu and in `ForEach(model.plans)`); `record(id:)` (`:144-148`) fetches one of them in no fixed order, so `save` edits one and leaves the other stale, the two sort equal so which is shown can change between reloads, and `delete` removes one and the plan comes back.
- The ticks. The restored twins share `planID`, `readingID`, `tickedAt` and `uuid`, so `earliestFirst` (`SM/SeedMerge.swift:237`, `:246-248`) cannot order them and each device keeps whichever it fetched first, most likely its own. Each then deletes the other's, both deletions sync, and the tick is gone from both. (The bookmark merge has had the same hole since milestone 7; it is outside this project and listed under Declined to judge.)
- Why it matters. Rare (two restores inside the sync delay), but it is the store diverging between devices and a tick lost by the machinery, which is the spec's second anti-goal in another form. The backup still holds the ticks.
- Fix. Do not try to delete a twin: no rule can make two devices pick the same one of two identical records. Make the store indifferent to them instead. In `PlanStore`: `plans()` and `plan(id:)` collapse records sharing a uuid to one (the latest `modifiedAt`; equal ones are the same); `save` writes every record with that uuid; `delete` removes every one. In `mergeTicks`: delete only duplicates whose uuid differs from the survivor's, and leave same-uuid twins alone (counts are sets, untick and delete-plan already remove every tick of a reading). Tests: two records with one uuid list once, save together, delete together; two same-uuid ticks survive `mergeAll`. Name the leftover twin record as a known limit in As built.

**I3. A keystroke in the 86-week editor, about 104 ms: what dominates and what to do.**
- The model's part (17.5 ms) is whole-draft work done twice per key. `UP/PlanEditorSession.swift:17-19` runs `draftChanged()` on every write; `:95` builds `model.chapterCounts` (a new dictionary) and runs `PlanReview.flags` over every line; `:98` runs `draft.canSave`, which parses every line a second time (`PL/PlanDraft.swift:67-72`). That is about 670 parses to learn about one changed line.
- The view's part (about 85 ms) is that one observed property carries everything. Every field reads and writes `session.draft` through the binding at `UP/PlanEditorView.swift:25-27`, so each key re-runs the whole `body`: the `ForEach` over 86 week bindings (`:35`), and for each week `weekHeader` (`:191-237`), which is a function, not a view, so its fields, its date control and its VoiceOver label (a date formatted per week, `:206`) are rebuilt for all 86 whether on screen or not. The benchmark types into week 41, which is off screen, so the 85 ms is entirely this, none of it the row typed in.
- A cost the benchmark does not show. On the Mac the window behind the sheet is redrawn on each key as well: `UP/PlanWindowView.swift:260-263` (`isBusy`) reads `session.draft` in the window's body and toolbar.
- The measurement itself is a worst case nobody will meet: the fixture Bible lacks most chapters, so the draft carries 325 flags, and the test alternates a line between flagged and not, so the "To check" list changes on every key (`T/PlanBenchmarkTests.swift:90-102`, `:225-244`).
- Fix, in this order, measuring after each.
  1. The session: keep each line's parse by its text (a dictionary, cleared when the editor closes), so a key parses one line; work `canSave` out from the flags (no `.unreadable` or `.unknownBook`, a title, a week) instead of a second pass; read `chapterCounts` once when the editor opens. Expect the model's part under 2 ms.
  2. The view: C1's change (values and id-keyed mutators) plus the week header, the reading row and the week foot as their own `View` structs with value inputs and `Equatable`, used with `.equatable()`, so a key re-runs one row's body and the header's label is only built for weeks on screen. This also brings the file under its 461 lines.
  3. The window behind: a stored `isEditing` on the session, set only when the editor opens and closes; `isBusy` and both sheets' `isPresented` read that, not `draft`.
  4. Re-measure with chapter counts that flag nothing (pass the 66 books' real counts to the session), typing in a week on screen and in one off screen. Pin a bound of 33 ms on the hosted figure. If it is still over, the last lever is for the focused line to hold its own text and hand it to the session on a short delay and before Save; do not reach for that first.

**I4. Choosing a week, 25 ms against 16: what dominates and what to do.**
- The choice is `@State` on the window's root (`UP/PlanWindowView.swift:16`), and the sidebar, the detail and the toolbar are functions of that root, so one arrow key re-runs all of `body` (`:39-88`): the toolbar's five items and the plans picker (`:266-309`), the alert, the dialog, the import wiring, every sidebar row on screen with two formatted dates and a progress count each (`:177-206`), and the detail. Task 12 found 21.9 of the 25 ms in that one update and showed the animated scroll is not it.
- In the detail the five rows are keyed by reading id (`:244`), so each choice destroys five rows (fifteen buttons with their help tags and accessibility actions) and builds five new ones, where it could change their text in place.
- Fix, measuring after each; stop under 16 ms and remove the `withKnownIssue` wrapper (`T/PlanBenchmarkTests.swift:286-288`).
  1. Take the choice out of the root: hold `PlanWindowState` in a small `@Observable` object, and make the sidebar, the detail and the Change Meeting Date button their own views that read it. The root's body, and so the toolbar and the wiring, no longer runs on a choice.
  2. A `PlanSidebarRow` view, `Equatable` over its week, its progress, whether it is chosen and the locale, so only the two rows whose state changed are redrawn and only they format dates.
  3. Key the detail's rows by position (`id: \.offset`): the row holds no state of its own, so this is safe, and five rows are updated rather than rebuilt.
- The same cause is behind the tick at 22.6 to 25.7 ms with the window observing (pinned at 40). `toggle` reloads and decodes every plan and reassigns `plans`, `followed` and `ticked` (`UP/ReadingPlanModel.swift:128-131`, `:66-77`). Have a tick refetch only the ticks, and have `reload()` assign each property only when it differs. Then lower that pin toward 16.

**I5. The spec's older-build confirmation has not been made.** Section 7: "the builder confirms it with a stand-in second store before anything reaches Matt's Release apps." Task 4's Steps 4 to 13 are blocked on Xcode's account; the plan's "Rehearsal results" is still its placeholder, and three rows of its closing table cite steps that were never run. This is not a defect in the code and the fix subagent cannot close it. It is a gate: no Release build, and no plan made in the `.dev` store while the phone's Debug app is still project 4's, until the rehearsal has run or both Debug apps are on this code. It heads the live list below.

### Minor

Each is marked fix (in the wave), backlog, or owner's.

- **M1 (fix). Remove Week and Remove Reading cannot be undone and ask nothing** (`UP/PlanEditorView.swift:289`, `:329`). The ledger left this for this review. Ruling: fix. The draft is a value, so undo is a snapshot: the session keeps the draft before each remove and each move and registers its return in the sheet's own `UndoManager` (⌘Z on the Mac, a shake on the phone). With that, drop the editor's hand-over of the sheet's manager to the plan model (`:64-68`): nothing in the editor registers through the model, and the hand-back can leave the model with no manager until the window is key again.
- **M2 (fix). A failure from the band or the popover is never shown in the main window.** `MAC/MainWindowView.swift:138` alerts for `markup.lastError` only; `plans.lastError` waits, and appears as "Could not save" the next time the plan window opens. Show it from `PlanWindowWiring`.
- **M3 (fix). The plan window does not follow the day.** Review Focus 5 has the window move at midnight; `UP/PlanWindowView.swift:65-68` reopens only on another plan or fewer weeks. When `model.now` changes and the chosen week was the old this week, reopen. The same on the phone, with M-phone below.
- **M4 (fix). A readable plan with no weeks says "This plan was made by a newer version of Bible Carrel."** (`UP/PlanWindowView.swift:109-123`, `PH/PhonePlanScreen.swift:102-110`). An empty record decodes as no weeks (`PL/PlanCoding.swift:52`). Give it its own line ("This plan has no weeks yet.") and leave Edit Plan… on.
- **M5 (fix). Today is read in the time zone the app launched in.** `UP/ReadingPlanModel.swift:44-45` defaults to `Calendar.current`, a snapshot. Default to `.autoupdatingCurrent` and call `refreshToday()` on `NSSystemTimeZoneDidChange` too.
- **M6 (fix). The anchor form starts on Week 1** whichever week is chosen (`UP/PlanDateViews.swift:85`). Start it on the chosen week (the Mac) and leave Week 1 on the phone. The owner is on week 63 of 67.
- **M7 (fix). "Later weeks move by the same number of days."** is shown for a week that has no date, where nothing else moves (`UP/PlanDateViews.swift:46`). Say it only when the week has a date.
- **M8 (owner's). Ticked passages are `ink.tertiary`,** which `DESIGN.md:197` reserves for text "never the only channel" and "never for text a reader must read". The spec's 5.1 asks for it and the plan already puts the choice to Matt; it stays his.
- **M9 (owner's). The band closes with two rules:** the progress line on its `ink.rule` track, then the hairline, a few points apart (`FrontPageView.swift:143-153`; seen in `task-8/02-gen1-w63-1100-light-140.png`, where with nothing ticked they read as a double rule). Both are the spec's. For the live look.
- **M10 (owner's). "Restored 1 reading plan and 2 ticks."** (`BackupsModel.sentence`). "Tick" is the spec's word and appears nowhere else in the app's copy, which says "Mark as read".
- **M11 (backlog). A stored passage is not checked on decode** (`PL/PlanCoding.swift:66-68`: a chapter below 1, an end before its start). Only a malformed record has one, and `canOpen` already refuses it.
- **M12 (backlog). An empty text file opens an editor with no weeks and says nothing;** a text file that is not a plan opens a review of unreadable lines (`UP/PlanFileImport.swift:17-20`). The review catches both.
- **M13 (backlog, and name it). A save from an editor left open while another device's edit arrived replaces that edit whole** and deletes the ticks of readings it added (`SM/PlanStore.swift:71-74`). This is the spec's "the later change winning", but As built should say it in those words. Later: compare the stored `modifiedAt` with the draft's and say so before saving.
- **M14 (for Task 13). Matt's list is now wrong in one line.** Task 13 Step 11 hands him spec 11's list "unchanged", and its last item is "Import the Gen 2 PDF and see Feb 29 flagged". On his own answer nothing is flagged. Rewrite it: "Import the Gen 2 PDF: it starts 15 September 2026 with nothing to check; stepping Starts in to 2025 flags Feb 29."
- **M15 (for Task 13). The plan's closing table is stale in eight rows** (below, under the spec line by line).

## The cross-task seams

- **One model, six readers.** Sound in shape: every surface reads `ReadingPlanModel` and none keeps a copy of the plan. Its weakness is breadth of invalidation, not correctness: one tick reassigns three observed properties and every surface redraws (I4). Indexes held by views (`chosenWeek`, `openWeek`, the date sheet's week) are each range-checked where used (`PlanWindowView.swift:225`, `:331-334`; `PhonePlanScreen.swift:261`; `PhonePlanList.swift:32`), so a reload that shortens the plan cannot trap them.
- **The undo manager's hand-over.** Weak, adopted by the window that becomes key, released only by its own window (`ReadingPlanModel.swift:205-213`, `PlanUndoWindowTests`). By reading it is right for the one undoable act there is (Delete Plan): the window that deletes is key, and the window that undoes is key and has adopted before the undo runs, so the redo registers in the same manager. Two soft spots: the editor's adoption (M1), and `restoreUndoably` and `deleteAgain` registering the opposite action when their own write failed (deferred, fix). Closing the plan window drops its manager and so the undo; the spec asks only for undo "from the plan window".
- **The shared reading row.** One view, three layouts, one accessibility element. The inline layout's `PassageLineLayout` is used only by the plan window. The phone gets its 44 pt targets through `passageHeight`. An unavailable passage is `.disabled` on top of `ink.tertiary`, so it draws lighter than the token (deferred, fix).
- **The editor's draft binding on both platforms.** One file, so C1 is on both, and worse on the phone, where the number pad has no Return.
- **A reload while an editor or a popover is open.** The popover and the band read the model and simply update. The editor keeps its draft, which is right, and then saves over what arrived (M13). The date popover and sheet hold a day in `@State` from when they opened and apply it to the week index, which is range-checked. If the reload makes `showsWeek` false while the reader's popover is open, the button goes and `isPlanWeekShown` stays true, so the popover returns by itself when a week next shows (`MainWindowView.swift:397-399`, `:423-430`; deferred, fix).
- **The day changing under an open app.** `NSCalendarDayChanged` and `didBecomeActive` both reach `refreshToday()` (`ReadingPlanModel.swift:53-55`, `AppSync.swift:194`), and the band, the button, the popover and the Plan tab's rows follow because they read `thisWeek`. The plan window's chosen week does not (M3), the phone does not scroll to the new this week, no test posts the notification (deferred, fix), and a changed time zone is not seen (M5).

## What is stored and synced

| Question | Finding |
|---|---|
| Anything beyond section 7? | No. Two models with exactly the spec's attributes, one synced key. `PlanDeletion.weeksData` and `monthDay` live in memory only. `-planProbe` reads a launch argument and writes no preference. |
| The store's rules | Kept, and pinned by `theNewKindsObeyTheStoresRules`. |
| Records out of step | Handled: see Strengths. Pinned by `countsAreOfThePlansOwnReadings`, `twoTicksForOneReadingMergeToTheEarlier` (its stray tick), `thePlanFollowedIsTheStoredOneElseTheNewest`. |
| A plan from a newer version | Handled: listed, shown unreadable, never written over, restored and undone byte for byte. Pinned by `aPlanFromANewerVersionIsListedAndNeverWrittenOver`; the save over an unreadable record of the same id and the delete-and-restore of one are not tested (deferred, fix). |
| Two devices editing | The later edit wins, whole (the spec accepts it). Known limit: M13. |
| Two devices restoring | Not handled: I2. |
| Two devices ticking | Different readings are two records and both stay. One reading ticked on both merges to the earlier, deterministically, because the uuids differ. Twins from a restore are the exception (I2). |
| An older build's store | Handled on a local store (`aStoreFromBeforePlansOpensAndKeepsItsMarks`). On the mirrored store it rests on the rehearsal (I5). |
| An older build on another device | Unverified: I5. |
| Backup and Restore | Handled (`aMissingPlanComesBackWithItsTicks`). Known limit, already in Task 13's list: `StoreBackup.markCount` counts highlights and notes only, so a store holding plans and no marks is "empty" to the daily backup. |

## The spec, line by line

"Test" means a test I read and found to assert the thing. "Render" means a picture exists and, where I say so, I opened it. "Reading" means the code does it and nothing checks it.

| Spec | Standing |
|---|---|
| 4 a plan, a week, a reading, a passage; own identity | Test: `aPassageReadsEachFormTheSpecNames`, `aLineIsAReadingOfOneOrMorePassagesWithItsLabel`, `theSamplesAreTheChurchsShapes`, `editingKeepsEachReadingsIdentity`. |
| 4 several plans, one followed | Test: `thePlanFollowedIsTheStoredOneElseTheNewest`. The menu's checkmark: unverified (live). |
| 4.1 this week; before the first; finished | Test: `thisWeekIsTheFirstWhoseMeetingIsTodayOrLater`, `thisWeekAndTheButtonFollowTheDay`. The window and tab "say so in one line": reading, and renders `06-finished-*`. |
| 4.1 a changed date moves later weeks; a label | Test: `movingADateMovesTheLaterWeeksAndAnchoringFillsEveryDate`, `thisWeekAndTheButtonFollowTheDay` (`setDay`). The popover and sheet: render; unverified live. |
| 4.1 anchoring | Test: the same two. "On first following it, the app asks": reading (`needsAnchor` shows the form), render `05-gen1-undated-*`. |
| 4.1 a date that does not exist is flagged | Test: `aNewFirstYearPlacesTheFilesDatesAgainAndAHandSetDateStays`, `aDrawnTableWithDatesReadsThemAndFlagsFeb29`. |
| 4.2 tick, untick, nothing ticks itself | Test: `tickingIsOneRecordAndUntickingRemovesIt`, `tickingCountsAndSurvivesAReload`. |
| 4.2 counts; the progress line | Test for the counts (`countsAreOfThePlansOwnReadings`). The line: render only. |
| 4.2 ticks sync; two devices | Test for the merge. Two devices each keeping theirs: by the model's shape only; the crossing was Task 4's and was not run. Unverified. |
| 5.1 the reader's button and popover | `showsWeek`: test. The button's condition (`MainWindowView.swift:397`) and help tag: reading. The popover: render in light and dark, none in Sepia. Anchor, closing: unverified (live). |
| 5.1 the band | When it shows: test of a pure function (`PlanBandTests`), not of the view. Columns: `fiveReadingsSitInOneRowAtTheUsualWindowWidth` pins the arithmetic, not the grid. Title line: test (`theLinesReadAsTheBandAndTheWindowShowThem`). Layout, hairline, no fill: render (opened). |
| 5.2 the window: three ways in | `PaletteCommandTests`, the catalogue row and `everyMenuShortcutInTheMacAppIsListed`. That ⌥⌘P and ⌘K really open it: unverified (live). |
| 5.2 sidebar, detail, toolbar, empty state | `theWindowOpensOnThisWeek` (the state), the lines by test; the rest render (opened: `07-window-gen1-light`). Toolbar: never seen, a render cannot show one. |
| 5.3 the tab, its rows, the menu, the empty state | Test: `thisWeekIsAtTheHeadWithTheWeeksBeforeAboveAndAfterBelow`, `theMenuOffersWhatCanBeDoneNow`. 44 pt targets: reading (`hitSize`). Opens scrolled to this week: render and a benchmark; unverified live. |
| 5.3 edge swipes; `DESIGN.md` section 7 | Test: `PhoneShellModelTests`, `PhoneEdgeSwipesTests`. `DESIGN.md:479` still has the old chain: Task 13, not done. |
| 5.4 opening a passage is reading | Test: `openingAPassageIsAReadingMoveNotALookup`. The main window or the Read tab coming forward: reading (`wirePlans` on both apps). |
| 5.5 VoiceOver | The words: test. The element, its action and the passages' actions: reading. Never heard. |
| 6.1 Import… by picker and by drop | Reading. Unverified (live): a render cannot show a file panel or a drop. |
| 6.1 the table from positions; what the two plans have | Test: six in `PlanTableReaderTests`, four drawn PDFs through PDFKit. A date with a label is pinned from words, not from a drawn PDF. The real files: `RealPlanPDFTests`, opt-in, run twice by report; run once more at the close. |
| 6.1 not a plan; no text | Test: `aPageWithoutTheHeaderIsNotATable`, `aPDFWithoutTheHeaderOrWithoutTextIsRefused`, `aLongPDFThatIsNotAPlanIsRefusedFromItsFirstPage`, `aFileThatIsNotAPlanSaysSoAndOffersNewPlan`. New Plan from that alert really opening the sheet: unverified (live). |
| 6.1 years | Overturned by Matt's answer and built as he chose. Test: `aYearThatKeepsTheDatesOnOneWeekdayIsPreferred`, `yearsAreCountedOnFromTheFirstDate`, `aDrawnTableWithDatesAWeekApartIsPlacedInTheYearThatKeepsTheirWeekday`. "Starts in": render (opened). |
| 6.2 nothing saved until accepted; title; to check; lines; Save off | Test: `anImportOpensTheReviewAndNothingIsSavedUntilAccepted`, `saveIsOffWhileALineCannotBeReadAndCancelSavesNothing`, `theReviewFlagsEachKindAndSaveIsOffWithAnUnreadableLine`. A click going to the week: unverified (live). |
| 6.2 add, remove, reorder by dragging | The draft's moves: test. The drag itself: unverified (live), and on the phone it may be out of reach, since a long press on a line begins text selection. |
| 6.2 an edit keeps its ticks | Test: `editingKeepsEachReadingsIdentity`, `savingAnEditDropsOnlyTheTicksOfReadingsRemoved`, `editingAPlanInUseKeepsItsTicks`. |
| 6.3 text and pasted text | Test: `textIsReadInTheEditorsOwnForm`, `aTextFileIsReadByTheEditorsForm`, `pastedTextReplacesAnEmptyDraftAndIsAddedToAnyOther`, `pastedTextAddsItsWeeks`. The Paste button: never seen. |
| 6.4 Delete Plan asks, undoes, with its ticks | Test: `deletingAPlanTakesItsTicksAndRestoreBringsBothBack`, `deletingAPlanIsUndoable`. The dialog and Edit › Undo in the window: unverified (live). |
| 7 | See the table above. The handover's note that the store moves forward: Task 13. |
| 8 the design documents | Not done: Task 13. |
| 9 constraints | No test touches `UserDefaults.standard`, iCloud or the church's files (read). The probe's refusal, which is what keeps a test plan out of `.dev`, has no test (deferred, fix). Project 1's section 10 was not re-audited. |
| 11 each test named | All present, as above. |
| 11 the real PDFs | By report (Task 5 and the year change). |
| 11 seen by eye, light, dark and Sepia | Renders exist for the window, the band, the Mac's review, the Plan tab and the phone's review in all three; the popover in two. Nothing has been seen live. |

**The plan's closing table, checked.** Every test it names exists and asserts what the row says. Eight rows are not true as written: "4.2 two devices" and "7 an older build" and "7 forward only" cite Task 4's steps, which were not run; "5.1 the button" and "11 seen by eye" cite live passes, which were not made; "6.1 years" still describes the tie the spec's rule left and does not name `aYearThatKeepsTheDatesOnOneWeekdayIsPreferred`, the test of the rule Matt chose; "8" and "5.3 edge swipes" cite Task 13, which has not run. Task 13 should correct the table as it writes As built.

## The ledger: rulings judged

- R1, R2, P1 to P13: sound; I would have ruled the same.
- **P14** (build on past Task 4's gate): sound for the build. I would have added its consequence in the same line: until the rehearsal runs, the work may be reviewed and fixed but not accepted in `.dev` with an older phone build beside it (I5).
- **Task 4** (compare the store's name without case): right.
- **Task 8** (the column minimum from 150 to 140): right, and the render bears it out.
- **Task 10** (keep every 44 pt target and open the gap between readings to twice the gap inside one): it cures the grouping, at the cost that this week's five readings now fill the phone's screen (about 640 pt; seen in `task-10/02-gen1-anchored-week63-fix1-light.png`). I would have ruled otherwise: put a reading's passages on one line where they fit ("Psalms 71 · Esther 1–3", the row's own inline layout, each still 44 pt high), which halves the height with no target made smaller and falls back to one a line at large sizes. Not for the fix wave: show Matt the tab first and let him say.
- **Task 12** (the bounds stay; the wrapper lasts only until the wave): right. Add a bound for the hosted keystroke once it is fixed (I3), and stop measuring the editor on a draft with 325 flags.

## The ledger: every deferred line, triaged

Lines already closed by a later task are marked closed.

| Line | Triage | Why |
|---|---|---|
| T1 chapter-run and verse-run branches repeat a block | drop | Two four-line branches; folding them hides the two shapes. |
| T1 `PlanSample` uses `try!` | drop | Constant input, covered by `theSamplesAreTheChurchsShapes`. |
| T1 two progress functions repeat a count | drop | Two lines. |
| T1 `PlanDay` takes a year above 9999 | drop | The stepper is ±10 years and the stored form refuses it. |
| T1 "Esther 7 -" as an unknown book | closed | Task 9 made it unreadable, with a test. |
| T1 no tests for empty, "()" and a bad stored day | fix | One test; a bad day must make the plan unreadable, not drop a week (Review Focus 3). |
| T2 pasted dated weeks placed from their own year | backlog | Pasting dated text into a dated draft; the review shows the dates. |
| T2 `PlanFlag.id` repeats | closed | Task 9, `eachFlagOfALineHasItsOwnID`. |
| T2 `PlanDraft.day` is a public var | fix | `public internal(set)`; the editor already uses `setDay` everywhere (checked: `PlanEditorView.swift:244`, `:251`, `:255`). |
| T2 a label that is a month and day reads as the date | drop | That is the form: a date, then a label. |
| T2 `plan(now:)` trims the title and labels | drop | Harmless and wanted. |
| T3 no test saves over an unreadable stored record | fix | The guard that keeps a newer plan from being written over. |
| T3 no test deletes and restores an unreadable plan | fix | The reason `weeksData` is kept. |
| T3 a tick with no `readingID` is not restored | drop | Only a malformed record. |
| T3 `StoreCopy.copy(PlanTick)` makes two throwaway uuids | drop | Cosmetic. |
| T3 no merge for two `PlanRecord`s with one uuid | fix | I2. |
| T3 a doc comment's wrap | drop | Cosmetic. |
| T4 `refreshAll()` on every Debug launch, twice on the Mac | fix | One line (refresh only when a probe ran); Debug should start as Release does. |
| T4 `make` saves then ticks, not atomically | drop | A Debug probe. |
| T4 no test of `refuses` | fix | Move the pure rule beside `StoreLocation` and give it three cases: it guards the owner's hard rule. |
| T4 exact-case store names elsewhere (pre-existing) | backlog | A Debug launch argument; not this project's. |
| T5 the date-placing step is written twice | backlog | Three lines, and the two differ on purpose. |
| T5 a date row with no readings makes an empty week | backlog | Neither real file; the review shows it. Name it in As built. |
| T5 a wrapped fragment's date words are dropped | backlog | The same. |
| T5 the scan test draws its page inline | drop | The helper draws text only. |
| T6 no test posts the day-changed notification | fix | The wiring of Review Focus 5. |
| T6 undo and redo register after a failed write | fix | Register only when the write succeeded. |
| T6 `follow` does not check the plan exists | drop | The fallback already covers a missing plan. |
| T6 `save` reloads twice; `isNew` from stale plans | drop | Once per save, about 10 ms; a stale `isNew` only follows a plan that exists. |
| T6 every tick decodes every plan | fix | I4. |
| T6 no test for the tie-break or an unreadable followed plan | fix | One test: an unreadable followed plan shows no week and `setDay` and `anchor` do nothing. |
| T6 a run-on doc comment; `spokenWeek`'s label untested | drop | Cosmetic. |
| Year rule: the "several keep" and "none keeps" cases do not discriminate | fix | One expectation each, with dates where the pool decides; it is the rule the owner chose. |
| T7 `DayPicker` does not set the locale | fix | One line; today the Mac's popover and anchor rely on the system's. |
| T7 the date views' `today` falls back to the real clock | fix | `PlanAnchorView`'s is still optional (`PlanDateViews.swift:89-95`); make it required. |
| T7 an unavailable passage draws lighter than `ink.tertiary` | fix | Draw it as text in the token with its help, not as a disabled button. |
| T7 a comment says "no command is added" | fix | `T/NavigationModelTests.swift:1949`. |
| T7 ⌘K opens a blank window after a startup failure | drop | As the Notes window; the failure has its own screen. |
| T7 the model keeps a closed window's manager | closed | Task 8. |
| T7 the window-open benchmark's margin | closed | 90 ms against 150 now. |
| T8 `controlActiveState` read at the main window's top | fix | Read it inside `PlanWindowWiring`; today every change of key window re-runs the main window's body. |
| T8 no manager adopted while the store opens | drop | The window's content does not exist until `plans` does. |
| T8 the week popover can reopen by itself | fix | Clear `isPlanWeekShown` when `showsWeek` goes false. |
| T8 a redundant condition in `FrontPageView` | drop | It is the tested rule, called where one argument is constant. |
| T8 a labelled title line can clip in the popover at large text | backlog | Fits at the default size; let the fallback line wrap when it is next touched. |
| T8 the front-page benchmark's plan is on WEB | drop | The bound is met with room. |
| T8 the band at larger text sizes not seen | live list | |
| T9 the mark under a line repeats "Week N:" | fix | Seen in the render; give `PlanFlag` a bare sentence for the line. |
| T9 the draft binding's fallback | fix | C1. |
| T9 To check sets focus straight after scrolling | fix | Defer a turn, as `focusLastLine` does. |
| T9 a `.fileImporter` failure is dropped (and T11, the phone) | fix | Show "That file could not be read." on both. |
| T9 removes in the draft cannot be undone | fix | M1. |
| T9 the reading field has no help tag | fix | The rule is every control. |
| T9 a force unwrap in `PlanEditorSession.swift:97` | drop | Filtered on the line before; it goes with I3's rewrite anyway. |
| T9 flags not recomputed when the translation changes | backlog | Advisory flags under a modal sheet. |
| T9 "Week 1 meets <date>" is an unasked extra | drop | It is asked: 6.1, "the review shows the first date with its year". |
| T9 `PlanEditorView.swift` is long | fix | Falls out of I3. |
| T9 the date field's text at its right edge | live list | Fix in `DayPicker` only if it shows live. |
| T10 the warm-up builds Notes, not Plan | fix | Warm Plan as well: its appearance only reloads and adopts a manager it is then given again. If a live look shows no stall, leave it. |
| T10 another plan chosen does not scroll to its this week | fix | With M3. |
| T10 the phone's Cancel and Change lose their key actions | fix | One modifier each. |
| T10 `DESIGN.md:479` | Task 13 | |
| T10 no test for `PhonePlanList`'s fallback or an earlier open week | fix | Two expectations. |
| T11 the security scope is started twice | fix | `PlanFileImport.draft` holds it itself; remove the outer pair and its comment. |
| T11 the placeholder on `paper.panel` is not in `PaletteTests` | fix | The rule for any new pairing. |
| T11 the number pad has no Done | fix | Goes with C1's text-bound field; add `scrollDismissesKeyboard`. |
| T11 a throwaway session per rebuild | drop | A small object. |
| T11 one test only | drop | The menu's rule is the one test; the rest is the shared editor's. |
| T11 two weeks' date chips differ in form and place | live list | Seen again in `task-11/01-review-86-light.png`; fix if it shows live. |
| T12 the two figures over | fix | I3, I4. |
| T12 the last sidebar row cut at week 86 | live list | |
| Every "⚠️ live-only" line | live list | Below. |

## What nobody has seen: the live look, in order

Before anything: sign in to Xcode (Settings, Accounts), build the rehearsal identity, and **run Task 4's Steps 4 to 13**. Until then no plan goes into `.dev`. Everything below is in the rehearsal identity (`-planProbe large`), after the fix wave.

**The Mac's editor (the highest risk; C1 and I3 live here)**
1. Import… a text file: the review opens; change a week's number and click Save without leaving the field. The number is saved; nothing reopens; nothing crashes.
2. The same with Cancel, with Remove Week on the last week while a field in it has the keyboard, and with Remove Reading on a line with the keyboard in it and in a later line.
3. Type in a line of an 86-week draft: no hitch per key.
4. A To check line for a far week: it scrolls there and the line takes the keyboard.
5. Drag a reading within its week: no flash, the field keeps the keyboard.
6. A PDF that is not a plan: the alert, and New Plan from it opens the sheet (if it does not, three toolbar items stay dimmed).
7. A PDF dropped on the window; the Paste button in a new plan; the Starts in stepper; the date field's text against its right edge.

**The Mac's plan window**
8. ⌥⌘P, View › Reading Plan and ⌘K each open it, on this week, in the middle of the sidebar, the sidebar holding the keyboard.
9. ↑ and ↓ through the weeks, held down: smooth; a beep at either end; with week 86 this week, the last row whole.
10. Tab reaches the passages; Space on a circle; Return on a passage brings the main window forward at that chapter.
11. The plans menu's checkmark; Change Meeting Date…'s popover and its anchor; Set Dates and Change in the accent.
12. Delete Plan…, the dialog, then Edit › Undo and Redo. Again straight after closing the editor. Again after clicking the main window and coming back.

**The Mac's main window**
13. The band: five readings in one row at the usual width, wrapping at 820 pt; the two rules at its foot (M9); a tick; a passage opened; The whole plan.
14. Tab order with the band; the contents holding the keyboard as the page opens and after ⇧⌘H; closing a Library view from the pane's icon.
15. The reader's button: dimmed on the front page; its popover's anchor; closing on a passage, on The whole plan and on Esc; a tick there showing in the open plan window. The popover in Sepia, which no render shows.
16. Light, dark and Sepia across all of it; the band at a larger text size.

**The phone (the simulator's rehearsal app, then the device)**
17. The bar: Read, Plan, Notes, Ask and search. The Plan tab opens with this week at its head, and again each time it is shown. Whether five readings at 640 pt is too tall (the Task 10 ruling).
18. The edge swipes Read, Plan, Notes; whether the first swipe into a large plan stalls.
19. A circle ticks under a thumb; a passage goes to the Read tab.
20. A week opens in place; its context menu; the ellipsis menu, its plan picker, Change Meeting Date… and its sheet's bar buttons.
21. Delete Plan…, then a shake.
22. The editor's sheet: Sepia and dark behind it; Save dimmed in the bar; the keyboard over the last line; a week number typed on the number pad and then Save (C1); the two date chips' form and place; swiping a line away; whether a reading can be dragged at all; swiping the sheet down.
23. The anchor form inside the list: its picker, its date and Set Dates each answering their own tap.
24. The accessibility text sizes; VoiceOver on a reading (its action and its passages' actions) and on a week row.

**Across devices and time**
25. A tick on the Mac shows on the phone and the other way; a plan made on one arrives and is followed on the other.
26. The day after a meeting, with the app left open overnight: the band, the button, the window and the tab have moved on.

## Declined to judge

- The iPad: not built, and the spec does not ask for it.
- Whether Apple's sync leaves unknown record types alone on an older build: it cannot be judged by reading; it is the rehearsal's question (I5).
- The bookmark merge's same-uuid twins (the hole I2 describes, in milestone 7's code): outside this diff. Worth the same two-line guard when I2 is fixed; the owner's call.
- `StoreBackup.markCount` counting only highlights and notes: pre-existing, and already in Task 13's known limits.
- The exact-case store names in `AppSync` and `StoreLocation`: pre-existing, Debug only.
- The table reader's thresholds against any layout but the church's two: the spec says it is built for these.
- Project 1's section 10, which the spec's section 9 imports: not re-audited here.
- The plan document's own prose, and the design documents Task 13 has yet to write.
- Whether the tests pass: not run by me; the ledger's last counts are taken as reported.

## Recommendations

- Pin a figure before trusting it: the two editor benchmarks measured a draft with 325 flags that no reader will have. A benchmark's fixture should be the real case, with the worst case beside it and labelled.
- A view that is a function of its parent redraws with its parent. Both figures over their bounds come from rows written as functions on a large view with one piece of state. In this codebase a row that appears eighty times should be its own `View`.
- One live pass is worth more than another round of renders: the two riskiest things here (a late field commit, and the undo hand-over) are things a render cannot show and a reviewer can only suspect.

## Assessment

**Ready to merge: with fixes.** The storage is exactly what was approved and is defended at each edge the plan named; the faults are in the editor's plumbing (C1, I1, I3), in one restore case (I2) and in two figures (I3, I4), all with a known cause and a small fix. Nothing here needs a second wave. The rehearsal (I5) and the live look stand between this branch and the Release apps, not between it and the fix wave.

## The fix list, in order, for the one fix subagent

The editor first, since four findings share its files; then the window; then the store; then the small ones by file.

1. **C1.** Id-keyed mutators on `PlanEditorSession`, no-ops with no draft; no element bindings and no fallback draft in `PlanEditorView`; the week number a text-bound field written as typed. Tests as C1 says.
2. **I1.** `ReadingPlanModel.save` returns whether it stored; the session closes only on success; the failure shown in the editor.
3. **I3, the session.** Parses kept by text; `canSave` from the flags; `chapterCounts` read once.
4. **I3, the view.** Week header, reading row and week foot as `Equatable` views; the file split.
5. **I3, the window behind.** A stored `isEditing`; `isBusy` and both sheets read it.
6. **I3, the measure.** Benchmarks on a draft that flags nothing, a visible week and a hidden one; pin 33 ms hosted.
7. **M1.** Undo for Remove Week, Remove Reading and a move, in the sheet's own manager; drop the editor's hand-over to the model.
8. The mark under a line without "Week N:" (a bare sentence on `PlanFlag`).
9. To check: focus a turn after the scroll.
10. A help tag on the reading field.
11. A `.fileImporter` failure shown, on both apps.
12. The phone: remove the second security scope; `scrollDismissesKeyboard` in the editor.
13. `PaletteTests`: the placeholder on `paper.panel`.
14. **I4, the window.** The choice in an observable object; sidebar, detail and the date button as views; `PlanSidebarRow` `Equatable`; the detail's rows keyed by position; remove `withKnownIssue`.
15. **I4, the tick.** `toggle` refetches ticks only; `reload()` assigns only what changed; lower the 40 ms pin.
16. **I2, plans.** `PlanStore` treats records with one uuid as one plan in `plans()`, `plan(id:)`, `save` and `delete`. Tests.
17. **I2, ticks.** `mergeTicks` leaves same-uuid twins. Test.
18. Tests: save over an unreadable stored record; delete and restore an unreadable plan; empty, "()" and a bad stored day.
19. `restoreUndoably` and `deleteAgain` register only after a write that succeeded.
20. Tests: the day-changed notification moves `today`; an unreadable followed plan; the tie-break.
21. **M5.** `.autoupdatingCurrent`, and `refreshToday()` on a time zone change.
22. **M2.** The plan model's error shown in the main window.
23. The week popover: clear `isPlanWeekShown` when `showsWeek` goes false.
24. `controlActiveState` read inside `PlanWindowWiring`.
25. **M3.** The plan window reopens on the new this week when the day changes and the old one was chosen.
26. **M4.** A readable plan with no weeks gets its own line.
27. **M6, M7.** The anchor form starts on the chosen week; the caption only for a week with a date.
28. An unavailable passage as text in `ink.tertiary` with its help.
29. `DayPicker` takes the locale; `PlanAnchorView`'s `today` required.
30. `PlanDraft.Week.day` `public internal(set)`.
31. The phone: scroll to this week when another plan is followed and when the day changes.
32. The phone: warm the Plan tab as well as Notes.
33. The phone: `.cancelAction` and `.defaultAction` kept with `actionsInBar`.
34. Tests: `PhonePlanList`'s out-of-range fallback and an earlier open week.
35. The year rule's two cases made to discriminate.
36. Debug: refresh after a probe only when one ran; `refuses` moved beside `StoreLocation` and tested.
37. The comment at `T/NavigationModelTests.swift:1949`.
38. For Task 13, with the fixes: Matt's list item 6 rewritten (M14); the closing table's eight rows corrected (M15); As built names the leftover twin record (I2), the stale-draft save (M13), the empty week and dropped date words of the reader (Task 5), and that the rehearsal is owed (I5).
