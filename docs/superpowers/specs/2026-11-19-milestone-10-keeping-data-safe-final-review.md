# Milestone 10, project 6, keeping data safe: whole-project review

Range `8f114e7..95589f7` (Tasks 1 to 12; Task 13, the documents, is not built yet). Reviewed 2026-11-19 by reading the spec, the plan's head and its two rehearsal sections, the ledger, and every source file the range touches at its head. No suite was run and neither app was launched. Two scratch programs outside the checkout were run: one compiled `NoteVersion.swift` alone to check four sequences against the pure rule (results under I-1, I-4 and M-2), and one asked AppKit for the width of a five- and a six-segment control (I-5).

## Verdict

**Ready with fixes.** Nothing was found wrong in the flows the two rehearsals covered: an edit against an edit in either order, an edit with sight, a delete against an edit in either order, a delete with sight, each choice made once. The rule is sound against what Apple's sync was shown to do, and the journal is written before the save everywhere it matters.

Four things at the seams between tasks should be fixed before Matt's real notes meet this build. Three of them can lose a text; each needs an uncommon sequence, and each is small to close. One makes a needless kept version in an ordinary flow. The fix wave is also the last cheap moment to change the form of a marker's version, because no real store holds one yet.

Counts: **Critical 0, Important 5, Minor 14.**

## Done well

- The journal is the only place a lost text survives, and the code treats it that way: written before the save (`MarkupStore.swift:330`), forgotten only after the kept version's save (`VersionKeeper.swift:54-55`, `NoteSittings.swift:36-37`), restored on an import's rollback (`DataImport.swift:100-103`).
- Every string of a mark, an ancestry and a marker is built and read in one 100-line pure type. The three values are never trusted unless they hang together.
- A kept version is only inserted or deleted. Use This One against Discard, and Use This One on two devices, come out right by construction.
- One rule, `restoreText`, for every way a note comes back (undo, backup, import).
- The import reads the whole store first, changes nothing that is here, and a second run adds nothing. The file reader tells damaged, foreign and newer apart before decoding.
- No inline colour, fixed font size, card, shadow or new shortcut in 3,900 added source lines. Tests use temporary directories, in-memory stores and scratch preference suites; none touches the clipboard, the network or a real store.
- Nothing is stored beyond section 6: three optional values on `Note`, `KeptVersion` with the thirteen named attributes, `DeletionMarker` with three and no text, no synced preference.

## Findings

### Important

**I-1. Sight is by digest alone, so a text put back is taken for one already seen, and is lost.**
`NoteVersion.swift:41-43, 61-72`; `VersionKeeper.swift:92, 97`; `MarkupStore+Versions.swift:52`.

The spec words sight by version (4.3: "was not made from this device's version"). The plan decided "Sight is by digest" and gave its cost as "a needless kept version, never a lost text". That cost is wrong. An ancestry entry is `<device tag><digest>`, but `ancestorDigests` drops the tag, so any text whose digest appears anywhere in the winner's ancestry counts as seen, whoever wrote it and whenever.

Scenario, with the feature's own button. The note reads `N1` (written on the phone); the Mac's lost text `K` is its kept version.
1. Mac: Use This One. The note is `K`, its ancestry names `N1`; `N1` is the kept version. This syncs.
2. Phone, before the next step reaches it: the reader edits `K` to `K2`. Its ancestry names `K` and `N1`.
3. Mac, before `K2` arrives: Use This One on `N1` (a change of mind). The note is `N1`, the kept `N1` is deleted, `K` is kept, the Mac's journal holds `N1`.
4. The phone syncs last. The note is `K2` everywhere. The Mac settles its entry `N1`: `K2`'s ancestry holds `N1`'s digest, so `hasSight` is true and the entry is forgotten.

`N1` is now in no note and no kept version. The scratch check printed `true` for step 4 and `false` for the other sync order (where nothing is lost). The same happens against a delete: the phone's marker for `K2` names `N1`, so the Mac forgets it. And a text typed back exactly as an earlier one ("Yes", "No", "Yes" again while the other device writes "No!") is lost the same way.

Why it matters: it is the project's one goal, broken by Use This One pressed twice. It needs an edit or delete on the other device in the window between the two presses, so it is rare.

Fix: sight by device and digest, which the stored ancestry already carries.
- `LastText` gains `tag: String?`, on the device only: the journal's own tag for a save made here; for `restoreText` (undo, backup, import) the tag in the note's mark when the three values hang together, else nil. Old entries decode with nil.
- `NoteVersion.hasSight(of:writtenBy:…)`: the same text; or an entry with that digest whose tag is `writtenBy` or `0000`; with `writtenBy` nil, the digest alone, as today.
- A marker's version becomes `<tag><digest>` pairs (the deleted text under its mark's tag, then the ancestry's entries), and `settle` asks whether a pair names this entry's tag and digest. `removeMarkers(of:naming:)` stays by digest alone: it removes more, which is the safe side.
- Callers: `VersionKeeper.swift:71` (the copy's mark), `:92`, `:97`; `DataImport.swift:164` (the file note's mark).

This only narrows sight, so it cannot lose a text. It does not bring a discarded text back: after Use This One and Discard on the Mac, the phone's own entry `N1` still matches the entry tagged with the phone, and is forgotten. (The blunter fix, a Use This One that claims no sight, was traced and rejected for that reason: the common "use mine, discard theirs" would show "2 versions" again whenever the phone was asleep.)

Left over, for the backlog: one device typing back its own earlier text exactly while another edits. Closing it needs the sitting's token in each entry.

**I-2. A write that is not the editor's replaces the journal entry without settling it first.**
`MarkupStore.swift:316-340` (`appendToNote`, `updateNote`); `MarkupStore+Versions.swift:47-85` (`useVersion`, `keepBoth`); reached from `NoteVersionsModel.swift:177-185` and `AssistantModel.swift:907`.

While a note is open in the editor the settle skips it (`VersionKeeper.swift:33`). If another device's text `R` arrives then, the store holds `R` and the reader's draft `D` lives in two places only: the editor's view and the journal. Closing the editor keeps `D` (`endSitting`); typing keeps the draft going. But a choice made in the Notes window (Use This One, Keep Both in the Note) or Add as Note appending to that note builds its text from the store's `R`, and `updateNote` journals the new text over `D` (`:330`). `reloadEditor` then replaces the view's draft. `D` is in neither a note nor a kept version. Task 6's ruling closed the mirror case (the editor writing its old draft over the chosen text) and its test has the journal and the store agreeing, so this was not seen.

Fix: one store helper, called at the top of `useVersion`, `keepBoth` and `appendToNote` (any save with no editor's sitting): if the journal holds an entry for the note, run `settle` on it and insert what it keeps, for the same save. In the ordinary case the entry is the note's text and nothing happens.

**I-3. The tidy-up removes a kept version after Use This One and a delete, against what was decided.**
`VersionKeeper.swift:148-149`; `NoteSittings.swift:104`.

"Decided here" and question 5 for Matt say deleting a note that shows "2 versions" leaves the other text under Kept versions. That holds only if Use This One was never pressed. After it, the note's ancestry names the swapped-out text, the delete's marker names it too, and the tidy-up's third rule ("its note is gone and a marker names its text") deletes that kept version at the next import or launch, on whichever device runs first. If the reader then undoes the delete, the note returns without it.

The third rule exists for one case: a note that vanished an import before its marker arrived. That orphan's text is almost always the deleted text itself.

Fix: the rule removes an orphan only when the marker's first entry, the deleted text, names it; never for an ancestor. One comparison in `NoteVersion`, one line in `untidy`.

**I-4. A note emptied in the editor comes back as a "Kept version" on the device that wrote it.**
`NoteSittings.swift:101-106`; `MarkupModel.swift` `endEditing` and the empty-note sweep.

Emptying a note's text deletes it (the long-standing rule). `markDeletion` returns before leaving a marker when the text is blank. The other device, which wrote the text, sees its note vanish with no marker and keeps the text as a version with no note, which then syncs back. The reader cleared the note having read it, so nothing clashed: the spec's third anti-goal. The decision ("deleting an empty note leaves no marker") had the never-written note in mind.

The scratch check confirmed a marker built from the emptied note would name the text it was emptied from, because the editor's sitting opened on it.

Fix: leave the marker whenever the note's ancestry has an entry, blank or not. A text another device wrote meanwhile is not in that ancestry and is still kept (Review Focus 1 holds).

**I-5. The Notes window's filter falls into the toolbar's overflow at the window's default width.** See "The live look's finding" below; the fix is item 6.

### Minor

- **M-1. A note's copies are overwritten or deleted before the settle has kept the differing one** (`MarkupStore.swift:332-338, 345-352`; the ledger's Task 5 line). `settleCopies` skips a note with a sitting open (`VersionKeeper.swift:69`), and the editor's next keystroke writes every copy. On a new device, a file imported while iCloud is still arriving, then an edit of a note whose iCloud copy lands under the open editor: that copy's text is replaced, and if it was written before this build no journal anywhere holds it. Fix now: before `updateNote` or `deleteNote` touches a note that has copies, each copy whose text is not blank, not the new text, not this sitting's own earlier save and not what the sitting opened on is kept first (share the helper with `settleCopies`).
- **M-2. Departure 6 holds for one sitting only.** An ancestry keeps one entry per change of device, so after two sittings on one device the text from before them is no longer named (`NoteVersion.swift:55`; the scratch check: seen after one sitting, not after two). Importing last month's file then marks every note edited twice since on one device. This is what spec 5.2 literally says, so it is not a defect, but question 3 for Matt overstates what was built. **Do not fix it by lengthening the ancestry:** more entries widen I-1's hole. Tell Matt; backlog a "discard the versions this import kept".
- **M-3. Every import reads every journal file and makes one fetch per entry, after fetching every note, on the main actor** (`VersionKeeper.swift:26-33, 67, 90, 144`). The journal starts empty and grows by one file per note edited here, never by age, so this is slow to bite. Backlog, first in line: reuse the one fetch of all notes as a lookup.
- **M-4. One rule in several places.** `isKeptVersion` three times (`NotesBrowserView.swift:223`, `PhoneNotesScreen`, `MarkdownExport.swift:233`); the mark's words twice (`NotesBrowserRow` `versionsText`, `PhoneNotesKinds.mark`); a kept version's thirteen fields copied by hand in four places (`VersionKeeper.keep`, `keptVersion(of:)`, `DataImport.swift:181-194`, `VersionProbe`); `endOpenEdit` and `notesColumnDidHide` with one body. Backlog.
- **M-5. Dead code:** `Content`'s hand-written `==` (`NoteVersionsView.swift:75-77`); `DataImport.apply`'s unused `now:` (`:28`); `VersionText.mark(count: 1)`.
- **M-6. Five log lines print `<private>`** because the error is interpolated bare: `GeneralSettingsView.swift:156`, `DataPanels.swift:33`, `NoteVersionsModel.swift:160, 171, 243`.
- **M-7.** The mark's help on a row whose note is gone still says "Show the versions of this note" (`VersionsMark.swift:50`).
- **M-8.** `NoteVersionsModel.orphan(id:)` fetches every note and every kept version on each draw of one popover (`MarkupStore+Versions.swift:31-37`). Backlog with `MarkupStore.keptVersion(id:)`.
- **M-9. Promised and not yet built, all Task 13's:** spec 7 (`DESIGN.md`, `DESIGN.json`), 5.3's "documented form" of the file, section 11, and the plan's rule 6 wording. The ruling to write them after the fix wave is right, but nobody on Fable will have read them.
- **M-10. The probes refuse the main store file, not the `.dev` database.** `refusesProbes` is false for any `-storeName` store, and such a store of the Debug app shares the `.dev` iCloud database (Departure 8's own reason). Release cannot reach a probe; "no test note in `.dev`" rests on habit. Backlog: refuse the `.dev` and real containers whatever the store's name.
- **M-11. The journal outlives its store.** A store reset by hand, or emptied by an account change, turns every entry into a kept version with no note (the ledger's Task 3 line). For Matt.
- **M-12.** `updateNote` trusts that a sitting passed in is the note's (`MarkupStore.swift:328`); a wrong one would write another note's ancestry. One guard.
- **M-13.** `settleCopies` unhooks a deleted copy's anchor and never applies the empty-highlight rule (`VersionKeeper.swift:78`). Backlog.
- **M-14.** `MarkupModel.swift` is 912 lines; the sitting code is a natural extension file. Backlog.

No main-actor hazard was found beyond M-3 and the export and import themselves, which run on the main actor in one pass (the ledger's Task 11 line): fine at today's sizes, backlog with a measurement.

## The whole against the spec's sections 4, 5 and 10

Built: every outcome in 4.1 and 4.2 on both apps, 4.3's rule with the plan's named departures, 5.1 and 5.2 on both apps, the format version, and every test group in 10. Built twice: nothing of substance (M-4). Not built: M-9. Departed without being listed: I-3 (a decision the code breaks) and M-2 (a departure narrower than described).

## The live look's finding

**Why.** `NotesBrowserView.swift:244-283` puts four controls in one `ToolbarItemGroup(placement: .primaryAction)` and adds a toolbar search field (`:62`). Nothing tells AppKit which matters more, so when the row does not fit, AppKit moves items into the overflow menu, and the segmented control is by far the widest. The window's default width, 980 pt (`ReadingThroughScriptureApp.swift:368`), was set on 2026-10-26 (`8a91d2f`) for four segments and no time menu. Since then the toolbar gained Threads (10-30), the "How far back" menu (11-10) and now Kept versions, and the width never moved.

**Would five have collapsed?** Probably not, but with little to spare, and reading cannot settle it. AppKit gives the control 356 pt with five labels and 463 pt with six when segments fit their labels (465 and 642 if SwiftUI makes them equal). The rest of the row needs roughly 560 pt (window buttons, title and count, the time menu, Sort, Export, a search field at its narrowest, the gaps). That puts five at about 915 of 980 and six at about 1,025. If SwiftUI makes segments equal, five was already over. The one-minute test: open the same window on a store with no kept version, which shows five.

**The smallest sound fix.** The filter's style follows the window's width: segmented when there is room for its segments, a menu when there is not, as "How far back" beside it and the phone's "What kind" already are. A pure `NotesBrowserView.filterIsSegmented(width:segments:)` with a test, fed by `onGeometryChange` on the content; thresholds near 960 pt for five and 1,060 pt for six, set by eye. Raise the default width to 1,100 so a new window shows the segments. Widening alone is not sound, because Matt's window manager sets the width; a shorter label breaks the spec's wording; a `.principal` placement depends on AppKit behaviour nobody can check in a test.

## Triage of the ledger's deferred minors

| Task | Deferred line | Call | Reason |
|---|---|---|---|
| 1 | Journal dates drop fractions of a second | Drop | Nothing compares them; the kept version shows minutes |
| 1 | Unwritable folder gives a new tag each launch, silently | Backlog | Protection is off in that state; one log line at start |
| 1 | Three missing journal tests | Backlog | Behaviour is right by reading |
| 2 | `updateNote` does not check `sitting.noteID` | Fix now | M-12; one guard on a rule that decides sight |
| 2 | `openSittings` holds ids, so two sittings end together | Drop | One editor model exists; choices already guard with `wasOpen` |
| 2 | Journal forgets before the delete's save; `markNew` journals before the insert's | Backlog | Needs a failed save; the second errs on the safe side |
| 2 | No test for a plain save under an open sitting; log not asserted; old-store test's name | Backlog | The rehearsal's Step 4 gave the real proof |
| 3 | `settleVersions`' count overstates | Drop | Only "more than nothing" is used |
| 3 | Probe refusal logged only when asked | Drop | Better than the brief |
| 3 | A marker fetch per `endSitting`; a fetch per entry and per group on every import | Backlog | M-3; measure on a real journal first |
| 3 | Two editors on one note lose protection when either ends | Drop | Same as Task 2's line |
| 3 | Rollback unchecked; `endSitting` on a failed save and on a vanished note untested | Fix now (the vanished-note test) | A real path: the editor open when a delete arrives |
| 3 | The journal outlives an emptied store | Backlog, for Matt | M-11 |
| 3 | `on:existing` spacing; a doc comment's wrapping | Fix now | Four call sites, no risk |
| 3 | `restoreText` removes any device's marker naming the text | Drop | Traced: the note is back, so no marker naming its text should stand |
| 4 | No test for a choice under an open sitting | Fix now | I-2's tests are this |
| 4 | A failed save in Restore as a Note may keep the text twice | Drop | The tidy-up makes them one |
| 4 | No test for a nil `noteID`; a short comment line | Drop | `restoreAsANoteWithNoNoteIDMakesANewOne` covers the path |
| 4 | No blank-body restore test; the backup built from a snapshot | Backlog | Low value |
| 5 | Before a settle, `deleteNote` and `updateNote` drop a differing copy's text | Fix now | M-1; the journal does not always hold it |
| 5 | A twin prompt or colour moved down reverts | Backlog | Needs twins of a kind that rarely has them |
| 5 | Of two twin highlights with notes, the later may carry the unread copy | Backlog | Same |
| 5 | An anchor left empty by a deleted copy | Backlog | M-13 |
| 5 | `settleCopies` fetches every note; three tests missing | Backlog | With M-3 |
| 5 | The pristine-survivor fold picks by fetch order | Backlog | It changes a value, deletes nothing |
| 6 | `onNoteChange` after a throw; reloads after a no-op; a redo after a throw | Backlog | Harmless reloads |
| 6 | The UI model's raw fetch of a kept version | Backlog | M-8 |
| 6 | The browser fetches counts and orphans twice | Backlog | With M-3 |
| 6 | Add as Note test never ends the edit; no test for a count of 1; file growth | Drop | The first is covered by I-2's tests |
| 7 | Help text on a row whose note is gone | Fix now | M-7; one string |
| 7 | Two fetches per draw; a fetch error closes with a log line | Backlog | M-8 |
| 7 | `Content`'s unused `==`; `mark(count: 1)`; wiring untested | Fix now (the `==`), drop the rest | M-5 |
| 7 | Shown-flag reset untested; 6 pt of slack | Drop | For the live look |
| 8 | Pop-path test never pushes; swipe's role and spoken label untested; an uncommented guard | Backlog | The device look covers them |
| 8 | Report gaps; a test's one-gap assumption; sheet guard; Mac stack by render | Drop | No behaviour at stake |
| 9 | `read` parses twice; `exportedAt` and `app` required; public `Codable`; twin tests; a plan with unreadable weeks left out silently | Backlog (log the left-out plan), drop the rest | Only a corrupt plan is skipped, but it should say so |
| 10 | Rollback untested; placeholder uuids; tick by uuid; message uuids; twin highlight; one test imports once; `now:` unused | Fix now (`now:`), backlog the rollback test, drop the rest | M-5 |
| 11 | Export and import on the main actor | Backlog | Measure on a large store first |
| 11 | Same sentence twice is not announced again; test gaps; `canImportData` default | Backlog | Accessibility polish |
| 11 | Wiring untested; a refused file closes an open editor; the log's privacy | Fix now (the log) | M-6 |
| 12 | The probe's four minors | Drop | Debug only |

## Rulings

None of the ledger's `Ruling:` lines should be overturned. Each was weighed; three notes:

- **Task 10** (an imported note is journaled as this device's): keep. It has one more cost than recorded: with both devices on this build, a note this device imported and another device then edits in two sittings before this one syncs leaves a kept version to discard once. I-1's fix makes the entry's tag honest and does not change that.
- **Task 3 and Task 4** (a restored note loses its markers naming its text): keep; traced through undo, backup and import against a second device's delete, and no text is lost.
- **The last ruling** (review before Task 13): keep, with M-9.

Two lines of the plan's "Decided here" should be amended, as I-1 and I-4 say: "Sight is by digest" (and its stated cost), and "deleting an empty note leaves no marker".

## What could not be judged by reading

- **A change pushed while the app is running** (the rehearsals synced on launch). Whether the main context has merged an import by the time `importFinished` runs the settle. If it lags, that pass sees no change and the next import or launch settles it; nothing is lost. The controller, in the rehearsal identity: both stores open at once.
- **Whether a marker and its note's removal ever arrive in different imports.** I-3's narrowed rule and I-4 both lean on it being rare. The same two-stores-open rehearsal shows it.
- **The toolbar's real widths, and which item AppKit moves first.** Matt or the controller, by eye, with five and with six segments.
- **Everything on the ledger's three live-look lists:** the popover and its choices, ⌘Z through both undo managers, the File menu's two items and the dimming of Import Data…, the panels, the alert begun from the open panel's completion, the phone's share sheet and `.fileImporter` inside the grouped form, VoiceOver, the choices' tint on a device. Matt.
- **`NotesColumnView.onDisappear`** firing when the inspector hides or the assistant takes it. Matt, live.
- **The fix wave changes the marker's form and the sight rule,** so rehearsal Steps 7 and 10 to 12 should be run again with the fixed build before Matt's list.

## Fix list

One wave, in this order. Items 1 to 3 touch the marker and must land together, before any real store holds one.

1. **Sight by device and digest (I-1).** Cause: `ancestorDigests` drops the tag, so a text put back is taken for one seen. Files: `NoteVersion.swift`, `LastTextJournal.swift` (`LastText.tag`), `NoteSittings.swift` (`journalText`, `restoreText`, `markDeletion`), `VersionKeeper.swift:71, 92, 97`, `DataImport.swift:164`. Tests: `useThisOneTwiceAgainstAnEditElsewhereKeepsTheTextPutBack` (both sync orders) and `…AgainstADeleteElsewhere` in `KeptVersionChoiceTests`; `theWritersEntryIsForgottenAfterUseThisOneAndDiscard` (nothing comes back); `aRestoredNotesTextIsSeenByItsWritersNextEdit`; `NoteVersionTests` for the pairs and the nil-tag fallback. Amend "Decided here".
2. **The tidy-up's third rule names the deleted text only (I-3).** Cause: an ancestor named by the marker deletes a kept version the reader was promised. Files: `NoteVersion.swift`, `VersionKeeper.swift:148`. Tests: `deletingANoteAfterUseThisOneLeavesTheOtherText` (settle on both devices, then undo the delete); the second half of `aDeleteThatHadSeenItKeepsNothing` still passes.
3. **An emptied note's delete leaves its marker (I-4).** Cause: `markDeletion` returns on a blank text. File: `NoteSittings.swift:101-106`. Tests: `aNoteEmptiedElsewhereAfterReadingItKeepsNothing`; `aNoteEmptiedElsewhereWhileEditedHereKeepsTheEdit`; `aNewEmptyNoteDeletedLeavesNoMarker`. Amend "Decided here".
4. **Settle the journal entry before a write that is not the editor's (I-2).** Cause: `updateNote` journals over a draft the store no longer holds. Files: `MarkupStore.swift:316-340`, `MarkupStore+Versions.swift:47-85`. Tests: with a sitting open, a save in it, then another device's text arrived: `useThisOne…`, `keepBoth…` and `anAppend…UnderAnOpenEditorKeepsTheDraft` in `KeptVersionChoiceTests`; one in `MarkupModelTests` through `NoteVersionsModel.perform` with a real editor.
5. **Keep a differing copy before it is overwritten or deleted (M-1).** Cause: the settle skips a note with a sitting open and the next save writes every copy. Files: `MarkupStore.swift:325-354`, `VersionKeeper.swift:64-84` (the shared helper). Tests in `TwinTests`: `aCopyArrivingUnderAnOpenEditorIsKeptBeforeTheNextSave`; `deletingANoteKeepsItsDifferingCopy`.
6. **The Notes window's filter follows the window's width (I-5).** Cause: six segments beside three controls and a search field in a 980 pt window. Files: `NotesBrowserView.swift:244-283`, `ReadingThroughScriptureApp.swift:368`, a line in `DESIGN.md` (Task 13). Test: `filterIsSegmented(width:segments:)` at both counts either side of each threshold; then by eye at 980, 1,100 and half a screen.
7. **The cheap tail, one commit.** The sitting guard in `updateNote` (M-12, a test that a mismatched sitting is ignored); `privacy: .public` on five log lines (M-6); the orphan mark's help (M-7); the unused `==` and `now:` (M-5); the `on:` spacing; and the missing test `endingAnEditOnANoteAnImportDeletedKeepsTheDraftWithNoNote`.

Then both suites and both builds, rehearsal Steps 7 and 10 to 12 again in the rehearsal identity, and Task 13.
