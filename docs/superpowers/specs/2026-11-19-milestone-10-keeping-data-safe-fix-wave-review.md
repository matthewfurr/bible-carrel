# Milestone 10, project 6, keeping data safe: the fix wave's review

Range `f6b694d..5e7c0a5` (five commits), against the whole-project review's seven-item fix list. Reviewed 2026-11-19 by reading the reviewer rules, the whole-project review, the fixer's report, the plan's "Rehearsal results" sections and the whole diff (in three passes). Outside the diff I made three focused checks: `copies(of:)` (`MarkupStore.swift:177-179`), to see whether item 5's `dropFirst()` skips the note passed in (it does: the note is always first); `openSitting` and `endSitting` (`NoteSittings.swift:24-50`), to trace item 1's scenario; and `deleteHighlight` (`MarkupStore.swift:377-381`), to see whether item 5's delete rule has a second path. I ran no test and launched no app.

## Verdict

**Approved.** All seven items are addressed. I found no new Critical or Important problem: no new way to lose a text, and no needless kept version in an ordinary flow. No rule now lives in two places, apart from the small duplication in m-2 below. Counts: **Critical 0, Important 0, Minor 4.**

## The seven items

| # | Finding | Verdict | Evidence | Tests the review named | RED, GREEN, command, output in the report |
|---|---|---|---|---|---|
| 1 | I-1 | **ADDRESSED** | `NoteVersion.swift:62-66` (`writer`), `:74-76` (`hasSight(of:writtenBy:)`), `:81-86` (`deleted`, tag plus digest), `:95-97`, `:112-116` (`Entry.names`), `:126-134` (old bare digests read with a nil tag); `LastTextJournal.swift:33` (`tag: String?`); `MarkupStore.swift:336`, `NoteSittings.swift:59` (this device's tag), `:86-89` (`restoreText` uses the mark's writer); `VersionKeeper.swift:111, 116` (`entry.tag`); `VersionKeeper.swift:86-95` (a copy's writer); `DataImport.swift:164` | All present: `useThisOneTwiceAgainstAnEditElsewhereKeepsTheTextPutBack` (both orders), `…AgainstADeleteElsewhere…`, `theWritersEntryIsForgottenAfterUseThisOneAndDiscard`, `aRestoredNotesTextIsSeenByItsWritersNextEdit`, five `NoteVersionTests` (pairs, `0000` or nil fallback, writer, old marker), two `LastTextJournalTests`. The scenario tests fail without the fix: RED was taken against a shim with the old digest-only body, so they failed on the finding's own assertion. The discard test passes before and after, as a guard | Yes: the shim RED with each failing expectation quoted, the filter command, GREEN, then full counts |
| 2 | I-3 | **ADDRESSED** | `NoteVersion.swift:100-102` (`marker(_:deleted:)`, first entry only); `VersionKeeper.swift:168` | `deletingANoteAfterUseThisOneLeavesTheOtherText` (settles both devices, then undoes on `b`); `aMarkersDeletedTextIsItsFirstEntryOnly`; `aDeleteThatHadSeenItKeepsNothing` still passes, per the report | Yes (shim RED: `device.kept == ["N"]` and the post-undo check) |
| 3 | I-4 | **ADDRESSED** | `NoteVersion.swift:81-86` (a blank text is left out; nil when no entry remains); `NoteSittings.swift:107` | `aNoteEmptiedElsewhereAfterReadingItKeepsNothing` (RED), `aNoteEmptiedElsewhereWhileEditedHereKeepsTheEdit` and `aNewEmptyNoteDeletedLeavesNoMarker` (guards; the second covers text typed and erased in a first sitting), `anEmptiedNoteNamesOnlyWhatItCameFrom` | Yes |
| 4 | I-2 | **ADDRESSED** | `VersionKeeper.swift:100-103` (`settleEntry`, through the one `settle`); called at `MarkupStore+Versions.swift:51, 79` and `MarkupStore.swift:318`, each after the guard and before the text is read | `useThisOneUnderAnOpenEditorKeepsTheDraft`, `keepBothUnderAnOpenEditorKeepsTheDraft`, `anAppendUnderAnOpenEditorKeepsTheDraft`, `MarkupModelTests.aChoiceAfterAnArrivalUnderTheOpenEditorKeepsTheDraft` (through `perform` and `reloadEditor`); guard `aChoiceUnderAnOpenEditorWithNoArrivalKeepsNoMore` | Yes, four RED failures quoted, with the command |
| 5 | M-1 | **ADDRESSED** | `VersionKeeper.swift:86-95` (`keepUnseen`, now shared with `settleCopies` at `:71`); `MarkupStore.swift:339-341` (overwrite), `:357-359` (delete) | `aCopyArrivingUnderAnOpenEditorIsKeptBeforeTheNextSave` (also checks that a third save keeps nothing more), `deletingANoteKeepsItsDifferingCopy` (a blank copy is not kept) | Yes |
| 6 | I-5 | **ADDRESSED** | `NotesBrowserView.swift:42` (`onGeometryChange`), `:254-256`, `:277-281`; `ReadingThroughScriptureApp.swift:369` (1,100 pt); the `DESIGN.md` Notes browser line | `NotesBrowserFilterStyleTests.theFilterIsSegmentedOnlyWhenItFits`, at both counts on each side of each threshold | RED was a compile failure, the only RED a new pure function can have; GREEN; the by-eye renders described, with their path |
| 7 | M-12, M-6, M-7, M-5, spacing, missing test | **ADDRESSED** | `MarkupStore.swift:331` (a sitting of another note is ignored); five `privacy: .public` lines; `VersionText.help(for:)` used at `VersionsMark.swift:50`; `Content`'s `==` and `apply`'s `now:` removed; four `on: ` sites | `aSittingOfAnotherNoteIsIgnored` (RED, three expectations), the help assertions in `theWordsAreTheSpecs`, `endingAnEditOnANoteAnImportDeletedKeepsTheDraftWithNoNote` (passes on the old code, as a missing test of a working path should) | Yes |

## Item 1, traced

Tags: phone `P`, Mac `M`. A mark's tag is its sitting's token prefix, which is the journal's `deviceTag` (`NoteSittings.swift:46`). So the journal's own tag and the tag other devices record for the text always agree.

**The finding's scenario.** Note `N1` (P). The Mac has kept `K`.
1. Mac, Use This One on `K`. The note is `K` with mark `M`; its ancestry is `[P·N1]`. The Mac's journal holds `K/M`, and `N1` is now kept.
2. Phone edits to `K2`. It opens on `K` (marked `M`), so its ancestry is `[M·K, P·N1]` and its journal holds `K2/P`.
3. Mac, Use This One on `N1`. `settleEntry` finds `K/M` equal to the note, so nothing happens. The note becomes `N1` under a new `M` sitting with ancestry `[M·K, P·N1]`. The journal holds `N1/M`, since the save is made here (`MarkupStore.swift:336`), and `K` is kept.
4. **Phone syncs last.** The note is `K2`. The Mac settles `N1/M` against `[M·K, P·N1]`. The only entry with `N1`'s digest carries `P`, which is neither `M` nor `0000`, so there is no sight: **`N1` is kept**. The result is `K2`, with `K` and `N1` kept, as the test asserts.
   **Mac syncs last.** The note is `N1`, every value the Mac's. The phone settles `K2/P`: `K2`'s digest is absent, so `K2` is kept. The Mac's entry equals the note. Result: `N1`, with `K` and `K2` kept. **Nothing is lost in either order.**

**Against a delete.** In step 2 the phone deletes `K`. Its marker is `M·K, P·N1`. In step 4 the delete wins. The Mac settles `N1/M`: `P·N1` does not name `M` as the writer, so `N1` is kept as a version with no note. The tidy-up removes `K`, the marker's first entry: the phone deleted it with sight. `N1` survives on both devices, as the test asserts.

**The old forms.**
- A journal entry with no `tag` decodes as nil through the synthesized optional decoding (`anEntryFromBeforeTheTagReadsWithNone`), and nil falls back to sight by digest alone (`NoteVersion.swift:114`).
- A marker of bare 16-hex digests parses each piece with a nil tag (`:131`). It is read by digest for both `names` and `deleted:` (`aMarkerFromBeforeTheTagIsReadByDigest`, and the bare-digest lines of `aMarkersDeletedTextIsItsFirstEntryOnly`).
- Junk is skipped.

**What is stored.** The diff touches `KeptVersion.swift` only in a comment. `DeletionMarker` keeps its three attributes, and `Note` is unchanged. `LastText.tag` lives in the on-device journal file, not in the store. A marker holds `<tag><digest>` pairs (20 hex characters each) and no text. **No attribute was added and no text was stored.**

## The two things done differently

- **Item 6's thresholds (1,000 pt for five segments, 1,200 for six; default width 1,100).** Accepted. The review asked for thresholds "set by eye" and named its own figures as estimates. The offscreen render showed controls overflowing at those figures, which is the defect this item fixes. At 1,100 a new window shows five segments; with a kept version present it shows the menu. That is the item's aim for the ordinary case: a kept version is rare and transient, and the menu is the sound fallback. Going to 1,200 would only matter in the rare case, and Matt's window manager sets the width anyway. The style depends on the content's width, and the width does not depend on the style, so it cannot oscillate. **Not judged by reading:** the live key-window toolbar (the renders were of a window never ordered in, and dark mode's chrome did not capture).
- **Item 5 keeps from the other records only, not the note record passed in.** Accepted. `copies(of:)` puts the note first (`MarkupStore.swift:178`), so `dropFirst()` skips exactly that record. A text that arrived on that record under the open editor is the loser's to keep from its own journal. Keeping it here too would only make a duplicate for the tidy-up, and would contradict `aTextArrivingWhileTheEditorIsOpenIsKeptByTheDeviceThatWroteIt`. The review's scenario is a distinct copy, and that is covered. The one gap is a writer on an older build, which has no journal. The plan already accepts that cost ("An older build on another device").

## Strengths

- One rule, reused: `settleEntry` calls the one `settle`, and `keepUnseen` replaced `settleCopies`' inline body rather than copying it.
- `writer()` derives from the mark, so the journal's tag and the ancestry's tag cannot disagree for a save made here.
- The guards were kept: the ordinary choice, the discard, and the never-written note each have a test that passed before and after.
- RED was taken against a shim with the old behaviour, so the new tests are shown to fail for the finding's reason and not only at compile.

## Issues

### Critical
None.

### Important
None.

### Minor

- **m-1. The narrowed tidy-up rule (I-3) now leaves a needless version with no note when a removal arrives before its marker and the deleted text was a later edit** (`VersionKeeper.swift:168`). Example: P wrote `X`; the Mac, offline, edited it to `Y` and deleted it, so its marker is `M·Y, P·X`. If P imports the removal first, it keeps `X`. When the marker arrives, its first entry is `Y`, so `X` stays. This is the trade-off the review mandated (it leans on separate arrival being rare). It costs one discard, never a text, and it should be checked in the two-stores-open rehearsal the review already asks for.
- **m-2. Two definitions of "the writer's tag" in one type.** `markTag` (`NoteVersion.swift:120`; the mark labels the text) builds the ancestry's and the marker's entries. `writer` (`:62`) also requires the ancestry's token to match. When the values merge singly so that the mark fits the text but the ancestry does not, other devices record the text under the mark's tag, while `restoreText`, `keepUnseen` and the import fall back to the digest alone. That fallback is the old behaviour, so the I-1 hole reopens only for that coincidence. Fix: make `writer` return `markTag`, or document why the stricter test is wanted.
- **m-3. A failed save after `settleEntry` has kept a draft** (`MarkupStore+Versions.swift:51, 79`). The rollback removes the kept draft, and the journal already holds the write's text (it is written before the save). The fixer reported this as a call; it is the same failed-save edge as the backlogged Task 2 line. Backlog it with that line.
- **m-4. The I-4 tests use an explicit blank save, then a delete** (`VersionKeeperTests` `empty(_:on:)`). The app's own sweep (`MarkupModel.swift:341`) goes through `deleteNote` on the note as last saved, so it is covered by the same rule. No test drives the sweep itself. Coverage only.

## Out of scope

- `deleteHighlight` (`MarkupStore.swift:376-378`) still says the marker is left "when it has text", and it does not apply item 5's keep-before-delete to a note's other copies. Those copies survive as notes, so nothing is lost.
- `DataImportTests` flake (two messages sharing a `Date()`), reported by the fixer, is unrelated: backlog the fixture.
- The review's leftover, one device typing back its own earlier text exactly while another edits, is unchanged and still wants the sitting's token per entry.

## What could not be judged by reading

- The new marker form and sight rule against real synced stores: rehearsal Steps 7 and 10 to 12 should run again in the rehearsal identity with this build, as the review says.
- Whether a marker and its note's removal arrive in different imports (m-1, and I-4's rule).
- The live toolbar at 980, 1,100 and 1,200 pt, both forms, and VoiceOver on the menu form.
- The full-suite counts (1,509 and 1,028) are the fixer's; no suite was re-run here.
