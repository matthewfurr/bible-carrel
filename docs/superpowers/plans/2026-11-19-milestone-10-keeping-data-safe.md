# Milestone 10, Project 6: Keeping Data Safe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task: one fresh implementer and one fresh reviewer per task, on the model each task's **Run** line names, then one whole-project review on Fable with its report written to a file. Steps use checkbox (`- [ ]`) syntax for tracking. The ledger is `.superpowers/sdd/2026-11-19-milestone-10-keeping-data-safe/progress.md`.

**Goal:** A note whose text was changed on two devices before they synced keeps both texts (one is the note's, the other a kept version the reader settles in one click), a note deleted on one device and edited on another keeps the edited text, and everything the reader has made can be written to one JSON file and read back with nothing lost and nothing doubled.

**Architecture:**
- Pure rules in `ScriptureModel`: `NoteVersion` (a text's digest, a sitting's mark, what a sitting started from, sight) and `LastTextJournal` (on the device only, beside the store: the last text this device wrote for each note).
- Three optional values on `Note` and two new SwiftData models, `KeptVersion` and `DeletionMarker`. `MarkupStore` journals and marks every save of a note's text; after every import `MarkupStore.settleVersions()` turns a text this device lost into a kept version and tidies.
- One observable `NoteVersionsModel` in `ScriptureUI` serves the mark and the versions view on both apps.
- `DataFile` (Codable, format version 1) carries every kind of record; `DataExport` writes it and `DataImport` adds what is missing.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit and UIKit, SwiftData with CloudKit, CryptoKit, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-16-milestone-10-keeping-data-safe-design.md`. Read it with this plan; section numbers below are the spec's. Its section 6 is exactly what Matt approved for iCloud, and this plan stores nothing beyond it. The mockup is `docs/superpowers/specs/milestone-10-mockups/note-kept-versions.html`.

Paths: `SM` is `Packages/ScriptureKit/Sources/ScriptureModel`, `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `PH` is `SUI/Phone`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `TM` is `Packages/ScriptureKit/Tests/ScriptureModelTests`, `MAC` is `Apps/Mac/ReadingThroughScripture`, `IOS` is `Apps/iOS/ReadingThroughScripture`, `SHARED` is `Apps/Shared` (every file in it is in both app targets; a new file needs no project edit).

**Built on, read in the code at `5bda6bd` (2026-11-19).**
- **A note's text is written** only by `MarkupStore.addNote(to:body:sourceThreadID:)`, `addChapterNote(...)`, `appendToNote(_:_:)` and `updateNote(_:body:)`, and **a note is deleted** only by `deleteNote(_:)` and `deleteHighlight(_:)` (`Highlight.note` cascades). `delete(_:)` and `restore(_:)` take a `MarkupDeletion`. A chapter note has `verse == 0` and no highlight.
- **The editors save as the reader types:** `MarkupModel.updateNoteBody(noteID:body:)` on every change of the draft, from `NoteRowView` and `PhoneNoteSheet`. `editingNoteID` becomes a note's id in `beginEditing(noteID:)`, `addNote(to:)`, `beginEditingDraft(highlightID:)` and `loadChapters`' pending edit, and stops being it in `endEditing(noteID:)`, `deleteNote`, `deleteHighlight`, `clearInteraction()` and `reload()` when the note is gone.
- **Sync:** `SyncCoordinator.importFinished()` and `prepareNow()` run `SeedMerge.mergeAll` in a `step`, then `refresh()`. `AppSync.attach(container:models:)` wires `status.onImport` and `BackupsModel` to `importFinished()` and runs the Mac's `SyncProbe` on a `MarkupStore` it makes itself (`SHARED/AppSync.swift:126`). `SyncStatusModel.canRestore` is true with sync off, or once the account is available and an import has finished in this launch.
- **The store:** `MarkupContainer.models` (nine); `StoreLocation.refusesProbes(sync:)`; `SeedMerge.mergeTicks` leaves same-uuid twins alone and `mergeBookmarks` does not; `PlanRecord.weeksData` is `PlanCoding` JSON carrying `"v": 1`.
- **The Markdown export:** the Mac's `ExportPanel` (`includesConversationsKey`) behind File › Export Notes… in `CommandGroup(replacing: .importExport)`; the phone's `PhoneNotesScreen.export()` presents a `UIActivityViewController` and has no conversations switch.
- **The Notes Browser:** `NotesBrowserLoader.entries(store:query:)` is also read by `NotesExporter.allEntries()` and by ⌘K's `markSearch`; the Mac's filter is a segmented `Picker("Show")`, the phone's a `Picker` over `NotesBrowserFilter.allCases`. `NoteRowView`, `NotesBrowserRow` and `PhoneMarkRow` are each already their own `View`. `NoteBodyText` is plain when `\.noteLinks` is nil.
- **⌘K:** `PaletteCommand.all.count == 33`, pinned in `PaletteCommandTests:15` and `NavigationModelTests:1949`. `SyncedPreferences.keys` has twenty and gains none.
- **Head counts:** package 1,356, iOS `ScriptureUITests` 986.

If a name differs when a task is built, say so before going on.

## Rehearsal results

The clash rehearsal (spec 10), run 2026-11-19 by the controller; its record is `.superpowers/sdd/2026-11-19-milestone-10-keeping-data-safe/rehearsal.md`.

**How it was run.** In the rehearsal identity (`com.matthewfurr.ReadingThroughScripture.rehearsal`, its own iCloud container, Development), because a `-storeName` store of the Debug app shares the `.dev` iCloud database. Two stand-in stores, `ClashA.store` and `ClashB.store`. The Debug-only `SyncProbe` gained `-syncProbeOffline YES` (a named store opened with no mirror, so a change stays on the Mac until the next ordinary launch), `quote:GEN.1:<text>` and `|` between probes (`5bda6bd`). A made eight chapter notes (Genesis 1 to 8, body `base`); B imported them. In each round A changed its notes offline, then B about fifteen seconds later; the stores were then synced one at a time in the round's order and launched twice more until neither changed.

| Note | A did, offline, first | B did, offline, later | Synced first | After both synced (both stores the same) |
|---|---|---|---|---|
| Gen 1 | body `A1` | body `B1` | A | body `B1`. `A1` is nowhere. |
| Gen 2 | body `A2` | body `B2` | B | body `A2`. `B2` is nowhere. |
| Gen 3 | body `A3` | quoted words `QB3` | A | body `A3` and quoted words `QB3`, modification time A's |
| Gen 4 | body `A4` | quoted words `QB4` | B | body `A4` and quoted words `QB4`, modification time A's |
| Gen 5 | deleted | body `B5` | A (the delete) | no note. `B5` is nowhere. |
| Gen 6 | deleted | body `B6` | B (the edit) | no note. `B6` is nowhere. |
| Gen 7 | body `A7` | deleted | A (the edit) | no note. `A7` is nowhere. |
| Gen 8 | body `A8` | deleted | B (the delete) | no note. `A8` is nowhere. |

Every export and import ended `failure none`; nothing crashed; no duplicate note was made.

**What Apple's sync does.**
1. **The store that syncs last wins a clash of text, not the one that edited last.** A store with an unsent change of its own keeps it when the other's change arrives, then sends it over the top.
2. **The losing text is destroyed everywhere.** The store that lost is the one that synced first: it sees its own text replaced on its next import. The store that won never sees the losing text. Nothing is reported to the app.
3. **A clash is settled one value at a time, not one record at a time.** A note's values do not travel together.
4. **A delete always wins, in either order.** An edit never brings a deleted note back. The store that edited sees its note vanish on an import, even when its own edit had not been sent yet.
5. **Imports arrive on launch,** and each ends with the app's `import finished`, which is where any check after "changes arrive from iCloud" hangs.

**What it means for section 4.3. The rule stands;** it never depended on which store wins.
- The loser is the only place the losing text can be saved from: its on-device record of the last text it wrote, which must be written to disk before or with the save it describes, never after. The winner keeps nothing, so a clash makes exactly one kept version, on the loser, which then syncs.
- Values merge singly, so the digest in the mark is needed between two new builds too. Every save of a note's text writes the mark with the new digest in the same save; the first save of a sitting also writes what it started from and the kind of device. Never rely on two values of a note having come from one device unless the digest says so.
- A delete beats an edit every time, so 4.2's kept version with no note is the only thing that saves the edited text. The marker and the removal may arrive in different imports: a note that has vanished with no marker yet is kept, and the tidy-up removes that kept version once a marker arrives that names its text.
- **One call the spec does not make: a delete by an older build leaves no marker.** The text this device wrote is kept as a version with no note, to be safe. Its cost: with an older build still in use on one device, a note deleted there comes back as a kept version on a device that wrote its text, and the reader discards it once.

**Not rehearsed:** three stores; an older build on one side; a change arriving by push; the new records themselves, which Task 12 rehearses with the built code. **Left in place:** the two stand-in stores, each holding no note.

## An older build, and this project

- **What it means here.** An older build that opens a store this build has used drops the `KeptVersion` and `DeletionMarker` tables and the three new values on every note in it (project 5's finding; the spec's section 6 says it "cannot" open it, which is wrong). With sync on they return from iCloud when this build next opens the store; what had not been sent does not. The journal is a folder beside the store and survives.
- **An older build on another device** (Matt's phone, until its Debug app is reinstalled) skips the new kinds; its edit arrives as a text under an unchanged mark and its delete with no marker, and both are kept from.
- **The rules.** Never run an older build on a store this build has opened. No implementer launches either app. The Mac Debug app is restarted and the phone's Debug app installed together, at the end, by the controller on Matt's word (Task 13). **The Release apps are not touched** in this project.
- **Not built here:** a build that refuses a store a newer build has used (`docs/BACKLOG.md`); it needs a stored value section 6 does not have.

## Before Task 1 (the controller)

1. Check the handover's table shows projects 1 to 5 finished. The older build is `OLD = 5bda6bd`.
2. **Signing first** (project 5's lesson): build the rehearsal identity at the head, as the reading-plans plan's "The rehearsal identity" says (the Mac Debug build with `PRODUCT_BUNDLE_IDENTIFIER=com.matthewfurr.ReadingThroughScripture.rehearsal CLOUDKIT_CONTAINER=iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal PASSAGE_URL_SCHEME=bible-rehearsal -derivedDataPath <scratchpad>/old-dd -clonedSourcePackagesDirPath Build/DerivedData/SourcePackages`). If Xcode has no account or Apple's licence is out of date, ask Matt now.
3. **A note from before, for Task 12:** with that build, `open -n -g -j <app> --args -storeName ClashA -syncProbe note:GEN.9:before`; wait for an export that ends `failure none`; quit by pid; launch `-storeName ClashB` once, see the note arrive, quit; delete `old-dd`.
4. Copy this plan's Global Constraints to `.superpowers/sdd/2026-11-19-milestone-10-keeping-data-safe/global-constraints.md` (the implementer rules name that file) and start the ledger.
5. Ask Matt the five questions below and write his answers here. Task 1 touches none of them; question 1 must be answered before Task 2.

**Done by the controller, 2026-11-19:** steps 1 to 4 (the rehearsal identity built and signed; `ClashA` and `ClashB` each hold one note, Genesis 9, body `before`, from `5bda6bd`'s code; the scratch build deleted). The pre-flight scan (`preflight.md` in the ledger's folder) found fourteen conflicts, each settled in this text before Task 1 (the ledger has the rulings; Departure 9 came from it). The five questions were put to Matt as the build began, with the ruling that none waits for him: question 1 is the spec's "the version that was deleted" in the form section 6 already approved for a note's marks (a digest, never text).

**For Matt** (each is built as written unless he says otherwise):
1. A deletion marker's "version that was deleted" is stored as short digests: of the deleted text and of the texts it was edited from. No text, and no more values than section 6 lists. Without the second part, a note edited on the phone and then deleted there comes back on the Mac as a kept version of the Mac's older text.
2. Records that share an identity are not deleted by the tidy-up (Departure 1); they are read as one, and a note's copies that differ leave a kept version.
3. Importing a file whose text for a note is one the store's note was edited from counts as "already here" (Departure 6). Otherwise last month's export marks every note edited since.
4. "Kept versions" is offered in the filter only while there is one.
5. Deleting a note that shows "2 versions" leaves the other text under Kept versions until it is discarded or restored.

## Departures from the spec

1. **Sections 4.3, 5.2 and 10: records that share an identity "are made one".** Two copies with one identity are two records in iCloud, and nothing in them tells two devices which to delete; each deleting a different one loses both, since a delete always wins (the backlog's "Twin records from two restores"). Built instead: copies are **read as one**; a note's text is written to and deleted from every copy; and the tidy-up deletes nothing for sharing an identity but a note's copy whose text differs, once that text has been kept, or is blank, or is one the survivor was made with sight of (nothing clashed, so nothing is kept). The bookmark merge gains the guard the tick merge has. The import is kept from making copies (Decided here).
2. **Section 6: an older build "cannot" open the store.** It can, and strips the new kinds.
3. **Section 4.1 writes "Today 8:14 am".** The time is the system's for the reader's region ("Today 8:14 AM" in the US), as every time in the app is.
4. **Section 4.1 has VoiceOver read the mark as a button.** Where VoiceOver reads a note's row as one element (the notes column, the Notes Browser, the phone's Notes tab), the mark is part of the row's label and an action of the row named "2 versions"; in the phone's note sheet it is a button.
5. **The mockup drew the Mac's popover on opaque paper.** It is the system's popover chrome, as every popover in `DESIGN.md` is. The mark is on `paper.overlay`, as 4.1 says.
6. **Section 5.2 keeps the file's text whenever it differs.** A file's text that the store's note was edited from is counted as already here.
7. **Section 5.1 gives the phone's export the "Include conversations" switch.** The phone's Markdown export has none and always includes them; so does its Export All Data. The Mac's panel has the checkbox.
8. **Section 10's rehearsals use stores of the rehearsal identity,** not of the Debug app.
9. **Section 5.2 adds a note that is not here "keeping its identity".** A highlight holds one note. A file's note that is not in the store, on a highlight that already carries another note, becomes a kept version of that note instead, so its text is not lost and the reader settles it (found by the pre-flight scan).

## Decided here

The spec's **(call)** items stand. Section 9's eight items, the rehearsal's call, and what else is open; with what each costs if wrong.

- **The digest:** the first eight bytes of SHA-256 of the text's UTF-8, trimmed of whitespace and newlines at both ends, as sixteen hex characters. Two texts are "the same" when equal after that trim. *Cost:* a collision (1 in 2^64) would keep nothing.
- **A mark** is `<token>.<digest>`; the token is the device's four-character tag and eight random hex characters, new each time editing begins. **What a sitting started from** is one value, `<token>:<entry>,…`: its own token, then an entry (`<device tag><digest>`) for the text the editor opened on and each before it, **one per change of device, at most eight**. *Cost:* a device offline through more than eight changes of device on one note keeps its old text needlessly.
- **Sight is by device and digest** (changed in the fix wave: the whole-project review, I-1, found that sight by digest alone lost a text put back, for instance by Use This One pressed twice while the other device edited, so the cost first written here, "never a lost text", was wrong). A version was made with sight of a text when it is the note's own text, or the entries name its digest under the tag of the device that wrote it, or under `0000`, and the three values hang together (the mark's digest is the text's; the entries carry the mark's token). A journal entry carries its writer's tag (this device's for a save made here; the note's mark's for a text put back by undo, a backup or an import); an entry or marker from before the tag, or a writer unknown, falls back to the digest alone. Values that do not hang together give no sight, so this device's text is kept. *Cost:* a needless kept version now and then; one case is left for the backlog, a device typing back its own earlier text exactly while another edits.
- **The kind of device** is its family, "Mac", "iPhone" or "iPad", never its name; the tag (random, made once per store on a device, kept with the journal, never shown) tells one Mac from another in the entries. *Cost:* a reader with two Macs sees "Mac" on both versions.
- **The on-device record** is one JSON file per note in `LastTexts` (`LastTexts-<name>` for a named store) beside the store, written before the save. An entry is dropped when a change arrives made with sight of it, when it becomes a kept version, and when this device deletes or empties the note; never by age. *Cost:* one small file per note edited here stays.
- **A journal write that fails does not stop the save;** it is logged. A damaged entry is removed.
- **A blank text is never kept or journaled. Deleting a note that never held text leaves no marker; deleting one emptied from text leaves a marker naming what it was emptied from** (changed in the fix wave: the whole-project review, I-4, found that "deleting an empty note leaves no marker" brought a note emptied in the editor back as a kept version on the device that wrote its text).
- **A marker's version** is `<tag><digest>` entries, comma separated: the deleted text under its mark's tag (left out when blank), then the ancestry's entries (changed in the fix wave with sight, I-1; a marker of digests alone, from before, is read by digest). The tidy-up removes a kept version with no note only when the marker's first entry, the text deleted, names it, never for a text it came from (the review's I-3). Markers are not exported, imported or restored from a backup; an undone delete removes the note's markers that name the restored text (changed in Task 3's review: a marker left behind hid a later delete by a device that had never seen that text, and the text was lost).
- **Deleting a note leaves its kept versions,** listed under Kept versions with no note. *Cost:* one more step to discard one.
- **Use This One** labels the note with the device that wrote those words, at the time of the choice. Only Discard is undoable (the spec's).
- **Restore as a Note** gives the note its old identity, on a live highlight with the same verses and offsets and no note, else on a new colourless highlight there. The conversation a note was saved from is not remembered across it.
- **Of a note's copies that differ,** the later `modifiedAt` stays (ties: the greater text); the other is not kept when the survivor was made with sight of it.
- **The symbol** is `square.on.square`. **"Kept versions"** shows in the filter only while a kept version exists, and returns to All when the last is settled; texts with no note list only under it, never under All, in ⌘K or in the Markdown export.
- **In the versions view** a hairline in `ink.rule` separates the versions, as the mockup drew (two texts must not run together); references in a version's text are plain; Use This One is prominent only when there is one kept version.
- **The file:** `DataFile` and its records, keys in Task 9's table. A plan's weeks are the stored `PlanCoding` JSON, embedded, so the plan carries its own `"v"`; one from a newer coding is imported as a record this build lists as unreadable and never writes over. Dates are ISO 8601 with milliseconds, so a conversation's turns keep their order. A file over 256 MB is refused as damaged, unread.
- **The import is kept from running while a sync is importing** by Restore's rule (offered with sync off, or once the account is available and an import has finished in this launch), and it runs in one pass on the main actor with one save. *Cost:* a record just made elsewhere and present in the file is added twice, then read as one.
- **The import's sentence** lists notes first, as the spec's example; with nothing added it begins "Nothing was added." The Mac says it in an alert on the front window; the phone under the rows, as Restore does.
- **⌘K gains Export All Data… and Import Data…** (35 commands). Neither has a key.
- **A probe** (`-versionProbe`, Debug, both apps, refused in the main store) stands in for an editing sitting and each choice (Task 12).
- **Models:** Opus builds Tasks 2 to 7 and 10; Sonnet the rest.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-10-study-tools`, on branch `milestone-10-study-tools`. Never push or merge.
- Git: `/usr/bin/git`, one git command per Bash call, no `cd … &&`, loops or shell variables. Every commit message ends with the `Co-Authored-By:` line your own session gives you, as a second `-m`.
- `rtk` shortens command output; use `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time. You do not dispatch subagents.

**Matt's data**
- Never touch the Release app, `Scripts/install-app.sh`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. Never build or run the Release configuration. (The controller alone, in Task 12, reads the rehearsal identity's own stand-in stores in `Sync/iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal-Development` and, on Matt's word, removes that folder; no implementer does.)
- **The `.dev` store gets no test note. No implementer launches the Mac Debug app, or opens the simulator's Debug app by hand,** with or without `-storeName` (the iOS test command is the only thing that touches the simulator): they are one iCloud database, shared with Matt's phone, and this project's build moves a store forward the first time it opens it. A note, a mark or a versions view on screen is a render in a test.
- No test touches iCloud, the Keychain, the network, the real clipboard, `UserDefaults.standard` or Matt's stores. A store or a journal in a test is in memory or under the temporary directory; preferences are a scratch suite removed when the test ends.
- Fixtures hold made-up notes and public-domain scripture (the WEB or the KJV).

**What is stored (spec 6, and nothing beyond it)**
- `Note` gains exactly `versionMark: String?`, `versionAncestry: String?`, `deviceKind: String?`.
- `KeptVersion`: `uuid`, `noteID: UUID?`, `body`, `writtenAt`, `deviceKind`, `book`, `chapter`, `verse`, `endVerse`, `translationID`, `quotedText`, `startOffset`, `endOffset`. `DeletionMarker`: `noteID: UUID?`, `version`, `deletedAt`; no text. Every attribute is optional or defaulted; nothing is unique; neither has a relationship. No other model, attribute or synced preference is added.
- On the device only: the journal of last texts.

**The version rules**
- Only `NoteVersion` builds or reads a mark, an ancestry or a marker's version.
- Every save of a note's text writes the mark with the new digest in that save, and the ancestry and kind whenever the stored ones are not the sitting's. The journal entry is written before the save.
- Never treat two values of a note as one device's unless `NoteVersion` says they hang together.
- A kept version is only ever inserted or deleted, never changed.
- Nothing is deleted because another record shares its identity, except a note's copy whose text differs, once that text is kept, is blank, or is one the survivor was made with sight of.
- No rule compares two devices' clocks to find a clash.

**Matt is using this Mac**
- You never quit, open or relaunch either app, and never send a keystroke, click or scroll.
- To look at the Mac's UI, render the view offscreen: an `NSHostingView` in a temporary test, written to a PNG in the scratchpad your dispatch names and opened with Read; remove the test before committing. Render inside a container taller than the view, in light, dark and Sepia.
- To look at the phone's UI, host the screen in a `TestWindow` (`window.layer.render(in:)`), on an in-memory store.
- A render cannot show focus, a click, a key, a popover's anchor or chrome, a toolbar, a panel, an alert, a share sheet or an undo. Say in your report what it could not show. If a focus defect survives two blind rounds, stop and report.

**Commands**
- Package tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (`--filter <Suite>` for one).
- iOS tests: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests` (append `/<Suite>` for one).
- Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`; the iOS Debug build is the same with `-scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'`.
- One after another; they share `Build/DerivedData`. **"The full run"** in a task's steps is the package suite, the iOS suite, the Mac Debug build and the iOS Debug build, in that order. If a later step of the task changes code, make the full run again before the commit.
- A file under `#if os(macOS)` runs in the package suite only, one under `#if os(iOS)` in the iOS suite only, any other `T` file in both; `TM` files in the package suite only. A timing benchmark can fail under full-suite load: rerun it alone.

**Code rules**
- The test first; a compile failure is the red.
- Every rule that needs now, a calendar or a locale takes it as a value.
- Swift Testing: `#expect` cannot contain a mutating call. Keep a `ModelContainer` alive as long as its context is used.
- A static func on a SwiftUI `View` is main-actor isolated; mark a pure helper `nonisolated`.
- No `.keyboardShortcut(` is added. `MainWindowView`'s `body` is at the type checker's limit: add nothing to it.
- Every `NSHostingView(rootView: ….followsSepia())` and `NSHostingController(rootView: ….followsSepia())` stays on one line (`SepiaModeTests` reads source lines).
- A list row that appears many times is its own `View` with value inputs.

**UI rules (CLAUDE.md, DESIGN.md)**
- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change; use the `/impeccable-swift` skill.
- Semantic text styles only; a size tied to text is `@ScaledMetric`. Palette tokens only (`Color.inkSecondary`, `Color.paperOverlay`, `Color.accentWash`); never an inline colour, `.opacity()` on `.primary`, `.foregroundStyle(.secondary)` or a system colour. `AppSpacing` and `AppRadius` by name.
- No card: no fill plus hairline round a note, a version or a row. The mark is a tonal step with no stroke, and is not `ChipLabel`.
- **Never an alert, a badge or red for a clash, and never the accent on the mark.** The versions view's one prominent choice is the system's prominent button, as the mockup drew it. Red is the system's, for Delete only; Discard is not red and has no destructive role anywhere.
- No new shadow or material, no `.glassEffect()`. A popover and a sheet are the system's.
- Every control has a label and a help tag; a hit area is at least a scaled 24 pt on the Mac and 44 pt on the phone.
- UI copy is as this plan gives it, in American spelling. No exclamation marks. Reduce Motion makes any motion a cut.

## Review Focus

1. **A text that is empty or differs only in white space** (a note emptied on one device while edited on another; a trailing newline). Nothing blank is kept, such texts are the same text, and the edited text survives. Task 2 `anEmptiedNoteLeavesTheJournal`; Task 3 `theSameTextTwiceKeepsNothing`, `aBlankTextIsNeverKept`.
2. **A file chosen by mistake** (the Markdown export, a PDF, an empty file, a JSON array, hundreds of megabytes). It changes nothing and says which kind of wrong it is. Task 9 `aDamagedAForeignAndANewerFileAreToldApart`; Task 11 `aRefusalSaysWhyAndChangesNothing`.
3. **The journal failing** (an unwritable folder; a damaged entry). Typing is never refused and nothing crashes. Task 1 `aDamagedEntryIsIgnoredAndRemoved`; Task 2 `aJournalThatCannotBeWrittenDoesNotStopTheSave`.
4. **Records that arrive out of step** (a kept version before its note; a marker after the note has gone; a note restored on one device while its kept version waits on another). Nothing is removed for want of its partner. Task 3 `aKeptVersionWhoseNoteArrivesLaterJoinsIt`, `aDeleteThatHadSeenItKeepsNothing`; Task 4 `restoreAsANoteBringsItBackOnItsPassage`.
5. **A delete that is undone** (⌘Z after deleting a note another device has edited; redo). The note returns with its mark, protection resumes, and the marker left behind never hides a text nobody saw. Task 2 `anUndoneDeleteBringsBackTheMarkAndTheJournal`; Task 3 `anUndoneDeleteAgainstAnEditElsewhereStillKeeps`.

---

### Task 1: Marks, sight and the journal (spec 4.3, 6, 9)

**Run:** Sonnet. No UI. Nobody needs to look.

**Files:**
- Create: `SM/NoteVersion.swift`, `SM/LastTextJournal.swift` (with `LastText`, `DeviceKind`)
- Modify: `SM/StoreLocation.swift`
- Test: create `TM/NoteVersionTests.swift`, `TM/LastTextJournalTests.swift`; modify `TM/StoreLocationTests.swift`

**Interfaces:**
- Produces:

```swift
public enum NoteVersion {
    public static let ancestryLimit = 8
    public static let unknownDevice = "0000"
    public static func digest(_ text: String) -> String
    public static func sameText(_ a: String, _ b: String) -> Bool
    public static func isBlank(_ text: String) -> Bool
    public static func newToken(deviceTag: String, random: () -> UInt32 = { .random(in: .min ... .max) }) -> String   // tag, then 8 hex
    public static func mark(token: String, text: String) -> String
    public static func token(ofMark mark: String?) -> String?
    public static func isMarked(text: String, mark: String?) -> Bool                 // the mark's digest is the text's
    /// The ancestry's entries as digests, newest first; none unless `isMarked` and the ancestry's own token is the mark's.
    public static func ancestorDigests(text: String, mark: String?, ancestry: String?) -> [String]
    /// What a sitting with `token` writes, opened on a note holding these three values.
    public static func ancestry(token: String, openedOn text: String, mark: String?, ancestry: String?) -> String
    public static func hasSight(of text: String, noteText: String, mark: String?, ancestry: String?) -> Bool
    /// A marker's version: the deleted text's digest, then `ancestorDigests`, comma separated.
    public static func deleted(text: String, mark: String?, ancestry: String?) -> String
    public static func marker(_ version: String, names text: String) -> Bool
}
public enum DeviceKind { @MainActor public static var current: String { get } }    // "Mac"; on iOS "iPad" for the pad idiom, else "iPhone"
public struct LastText: Codable, Equatable, Sendable {
    public var noteID: UUID, body: String, writtenAt: Date
    public var book: String, chapter: Int, verse: Int, endVerse: Int, translationID: String, quotedText: String, startOffset: Int, endOffset: Int
}
@MainActor public final class LastTextJournal {
    public let deviceTag: String                                        // four lowercase hex characters
    public init(directory: URL?, deviceTag: String? = nil)             // nil directory: in memory
    public func record(_ entry: LastText) throws
    public func entry(for noteID: UUID) -> LastText?
    public func entries() -> [LastText]
    public func forget(_ noteID: UUID)
}
// StoreLocation: public var lastTextsDirectory: URL   // directory/"LastTexts", or "LastTexts-<storeName>" for a named store
```

**The rules.**
- **`ancestry(token:openedOn:mark:ancestry:)`** is `"<token>:"` then entries, comma separated, newest first. The first is for the text opened on: the first four characters of the mark's token when `isMarked`, else `unknownDevice`, then the text's digest; a blank text gives none. Then the note's own entries, when `ancestorDigests` would return them. Then an entry whose tag is the tag of the entry before it is dropped, unless that tag is `unknownDevice`; then the first eight are kept.
- **`hasSight`** is `sameText(text, noteText)`, or `ancestorDigests(...)` contains `digest(text)`.
- **The journal** holds one file per note, `<uuid>.json`, written atomically, and its tag in a file named `device` (made on first use when none is given). A file that cannot be decoded is removed and reads as no entry. `record` throws when it cannot write.

- [ ] **Step 1: Write the failing tests** (`d` is `NoteVersion.digest`). `TM/NoteVersionTests.swift`:
  - `theDigestIsOfTheTrimmedText`: `d("abide") == "072469151f645102"`; `d("  abide\n") == d("abide")`; `d("Abide") != d("abide")`; `sameText("a\n", "a")`; `isBlank(" \n")`.
  - `aMarkIsItsSittingAndItsTextsDigest`: `newToken(deviceTag: "a1b2", random: { 42 }) == "a1b20000002a"`; `mark(token: "a1b20000002a", text: "abide") == "a1b20000002a.072469151f645102"`; `token(ofMark:)` returns the token, and nil for nil and for `"junk"`; `isMarked` is true for "abide " and false for "other" and for a nil mark.
  - `anAncestryNamesWhatASittingOpenedOnOnePerChangeOfDevice`: a new blank note gives `"aaaa00000001:"`. Device `bbbb` opening on `aaaa`'s "one" gives `"bbbb00000002:aaaa\(d("one"))"`; opening on its own "two" gives `"bbbb00000003:bbbb\(d("two")),aaaa\(d("one"))"`; on its own "three", `"bbbb00000004:bbbb\(d("three")),aaaa\(d("one"))"`. A text with no mark gives `"…:0000\(d(text))"`, and two `0000` entries in a row both stay. Nine devices in turn leave eight entries.
  - `sightIsTheSameTextOrAnAncestor`: a note "four" marked by `bbbb00000004` with the last ancestry above: sight of "four", "three" and "one"; none of "never".
  - `valuesThatDoNotHangTogetherGiveNoSight`: a mark for another text: `ancestorDigests` is empty and there is no sight of "one"; an ancestry whose own token is not the mark's: the same.
  - `aMarkerNamesTheDeletedTextAndWhatItCameFrom`: `deleted` for that note is `"\(d("four")),\(d("three")),\(d("one"))"`; it names "four", "three" and "one" and not "never"; a note with no mark gives `d(text)` alone.

  `TM/LastTextJournalTests.swift` (a directory under the temporary directory):
  - `anEntryIsWrittenReadAndForgotten`: `<uuid>.json` exists; a second journal on the directory reads and lists it; a second `record` replaces it; `forget` removes the file.
  - `theDeviceTagIsMadeOnceAndKept`: four characters of `0-9a-f`, the same from a second journal on the directory; a given tag is used; an in-memory journal writes nothing.
  - `aDamagedEntryIsIgnoredAndRemoved`: a file holding `not json` reads as nil, is not listed, and is gone afterwards.
  - `recordingThrowsWhenTheFolderCannotBeWritten`: the directory path is a file.

  `TM/StoreLocationTests.swift`: `theLastTextsSitBesideTheStore` (`directory/LastTexts`; for `ClashA`, `directory/LastTexts-ClashA`).
- [ ] **Step 2: Run.** `--filter NoteVersionTests` FAILS to compile.
- [ ] **Step 3: Build.** `CryptoKit` for the digest; `DeviceKind` reads `UIDevice` under `#if canImport(UIKit)`.
- [ ] **Step 4: Run.** The three suites pass; then the full run.
- [ ] **Step 5: Commit.** `feat: a note's version mark, what a sitting started from, and the on-device record of last texts (keeping data safe 4.3, 6)`

---

### Task 2: The stored values, and a save that marks (spec 4.2 the marker, 4.3, 6; 10 storage)

**Run:** Opus (the synced store's models; every write of a note's text). No UI. Nobody needs to look.

**Files:**
- Create: `SM/KeptVersion.swift` (`KeptVersion`, `DeletionMarker`, `KeptVersionSnapshot`), `SM/NoteSittings.swift` (`NoteSitting`, the store's extension)
- Modify: `SM/Note.swift`, `SM/MarkupContainer.swift`, `SM/MarkupSnapshot.swift` (`NoteSnapshot`), `SM/MarkupStore.swift`
- Test: create `TM/NoteSittingTests.swift`; modify `TM/MarkupContainerTests.swift`, `TM/MarkupRestoreTests.swift`

**Interfaces:**
- Consumes: Task 1.
- Produces:

```swift
// Note gains: public var versionMark: String?, versionAncestry: String?, deviceKind: String?
@Model public final class KeptVersion {
    public var uuid: UUID = UUID()
    public var noteID: UUID?
    public var body: String = ""
    public var writtenAt: Date = Date()
    public var deviceKind: String = ""
    public var book: String = "", chapter: Int = 0, verse: Int = 0, endVerse: Int = 0
    public var translationID: String = "", quotedText: String = "", startOffset: Int = 0, endOffset: Int = 0
    public init()
}
@Model public final class DeletionMarker {
    public var noteID: UUID?
    public var version: String = ""
    public var deletedAt: Date = Date()
    public init(noteID: UUID, version: String, deletedAt: Date)
}
/// A kept version by value, every stored field; `id` is its uuid. `init(_: KeptVersion)`, `func make() -> KeptVersion`.
public struct KeptVersionSnapshot: Equatable, Sendable, Identifiable
public struct NoteSitting: Equatable, Sendable { public let noteID: UUID, token: String, ancestry: String, deviceKind: String }
// MarkupContainer.models: the nine, then KeptVersion.self, DeletionMarker.self.
// NoteSnapshot gains the note's three values; `make()` sets them.
// MarkupStore
public let journal: LastTextJournal
public let deviceKind: String
public internal(set) var openSittings: Set<UUID>   // set from NoteSittings.swift
public init(container: ModelContainer, journal: LastTextJournal? = nil, deviceKind: String = DeviceKind.current)   // nil: an in-memory journal
public func beginSitting(noteID: UUID, deviceKind: String? = nil) throws -> NoteSitting?    // nil when the note is gone; nil kind: this device's
public func endSitting(_ sitting: NoteSitting)
public func updateNote(_ note: Note, body: String, sitting: NoteSitting? = nil, now: Date = Date()) throws
```

**The rules.**
- **`beginSitting`** makes a token from the journal's tag and fixes the ancestry from the note as it stands; the note is in `openSittings` until `endSitting`.
- **`updateNote`,** in order: with no sitting given, one is begun and ended inside the call. A non-blank body is recorded in the journal (the note's place; its highlight's offsets, 0 without one); a blank body forgets the note's entry; a journal failure is logged (`markup` category) and the save goes on. Then `body`, `modifiedAt`, `versionMark`, and `versionAncestry` and `deviceKind` when the stored ones are not the sitting's; one save.
- **`addNote` and `addChapterNote`:** a note made with text is marked as a sitting with nothing before it (`"<token>:"`) and journaled; a note made empty has no mark and no entry. `appendToNote` goes through `updateNote`.
- **`deleteNote` and `deleteHighlight`:** for a note with text, a `DeletionMarker` (its uuid, `NoteVersion.deleted(...)`, now) is inserted **in the same save** as the delete, and the journal forgets the note. An empty note leaves no marker.
- **`restore(_:)`** puts a note back with its three values and journals its text again. The marker stays.

- [ ] **Step 1: Write the failing tests.** `TM/NoteSittingTests.swift` (`@MainActor`; the store has an in-memory journal tagged `aaaa` and kind "Mac"; `base` is a chapter note on Genesis 1 made with "base"):
  - `everySaveWritesTheMarkAndTheFirstWritesWhereItStartedAndTheKind`: the sitting's ancestry is `"\(token):aaaa\(d("base"))"` and the note is in `openSittings`; after each of three saves ("a", "ab", "abc") `versionMark == "\(token).\(d(text))"`, `versionAncestry == sitting.ancestry`, `deviceKind == "Mac"`; the journal's entry is "abc" on `GEN` 1 verse 0; `endSitting` empties `openSittings`.
  - `aSaveWithNoSittingIsASittingOfItsOwn`: two plain `updateNote` calls give two tokens, the second opened on the first's text.
  - `aSaveNamesItsOwnStartAgainWhenAnotherDevicesValuesArrived`: mid-sitting the note's four values are set as another device's and saved; the next `updateNote` in the sitting leaves the sitting's ancestry, mark and "Mac".
  - `aNewNoteWithTextIsMarkedAndAnEmptyOneIsNot`: `addChapterNote(body: "x")` has a mark, `"<token>:"`, the kind and an entry; `addNote(to:body: "")` has none; a note with text on a highlight journals the highlight's two offsets.
  - `anEmptiedNoteLeavesTheJournal`: `updateNote(note, body: " \n")` leaves no entry.
  - `deletingANoteLeavesAMarkerAndForgetsItsText`: one marker with the note's uuid, `version == NoteVersion.deleted(...)` of the note as it stood, `deletedAt == now`; no entry. The same through `deleteHighlight`. An empty note: no marker.
  - `anUndoneDeleteBringsBackTheMarkAndTheJournal`: after `delete(.note(...))` and `restore`, the three values and the entry are back and one marker remains; deleting again makes two.
  - `aJournalThatCannotBeWrittenDoesNotStopTheSave`.

  `TM/MarkupContainerTests.swift`: `theNewKindsObeyTheStoresRules` expects 11, checks `KeptVersion` and `DeletionMarker` as it checks the plan kinds, and that `Note`'s three attributes are optional; `aStoreFromBeforeKeptVersionsOpensAndKeepsItsNotes` (a store made with the first nine models and one note opens through `MarkupContainer.make(at:sync:)`, the note there, and a `KeptVersion` saves and fetches). `TM/MarkupRestoreTests.swift`: an undone note delete and an undone highlight delete bring the three values back.
- [ ] **Step 2: Run.** `--filter NoteSittingTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** `NoteSittingTests`, `MarkupContainerTests`, `MarkupRestoreTests`, `MarkupStoreTests`, `StoreCopyTests` pass; then the full run.
- [ ] **Step 5: Commit.** `feat: a note's three version values, kept versions and deletion markers in the store, and every save of a note's text marked and journaled (keeping data safe 4.3, 6)`

---

### Task 3: Keeping a lost text after an import (spec 4.2, 4.3; 10 clashes, deleted against edited, the tidy-up)

**Run:** Opus (the rule the rehearsal confirmed; it inserts and deletes synced records). No UI. Task 12 is the controller's check with real sync.

**Files:**
- Create: `SM/VersionKeeper.swift`
- Modify: `SM/NoteSittings.swift` (`endSitting`), `SM/SyncCoordinator.swift`, `SHARED/AppSync.swift`, `SHARED/AppModels.swift`
- Test: create `TM/VersionFixtures.swift`, `TM/VersionKeeperTests.swift`; modify `TM/SyncCoordinatorTests.swift`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces:

```swift
public enum VersionKeeper { public static let markerLifetime: TimeInterval = 90 * 86_400 }
extension MarkupStore {
    /// After an import: keeps the texts this device lost, tidies, and returns how many records it inserted or deleted.
    @discardableResult public func settleVersions(now: Date = Date()) throws -> Int
}
// SyncCoordinator: public var onMerged: (@MainActor () throws -> Void)?
// AppSync: let journal: LastTextJournal (on `location.lastTextsDirectory`);  func attach(container: ModelContainer, store: MarkupStore, models: Models)
```

**`settleVersions`, in order, with one save when anything changed:**
1. **Each journal entry whose note is not in `openSittings`.**
   - *Its note is in the store.* With sight of the entry's text (`NoteVersion.hasSight`): the same text, nothing; otherwise the entry is forgotten. Without sight: a `KeptVersion` is inserted (the note's uuid, the entry's text and `writtenAt`, this device's kind, the note's place and its highlight's offsets) and the entry forgotten.
   - *Its note is gone.* If a marker for that note names the entry's text, the entry is forgotten; otherwise a `KeptVersion` is inserted from the entry alone and the entry forgotten.
2. **The tidy-up.** Kept versions of one note with the same text become one (the earliest `writtenAt` survives, ties the lowest uuid; two that share a uuid are both left). One whose text is its note's is deleted. One whose note is gone, and whose text a marker for that note names, is deleted.
3. **Markers** whose `deletedAt` is more than `markerLifetime` before `now` are deleted.

**`endSitting`** takes the note out of `openSittings`, then runs step 1 for that note alone and saves if it kept anything: a text that arrived while the editor was open and was never typed over is found here. A save that fails here is logged (the `markup` category), as a journal failure is, never swallowed silently and never thrown.

**The wiring.** `SyncCoordinator` calls `onMerged` in a `step("keeping versions")` after "merging duplicates" in both `importFinished()` and `prepareNow()`, before `refresh()`. `AppSync` makes the journal in its `init`. `AppModels.make` builds `MarkupStore(container: container, journal: appSync.journal)` and passes it to `attach`, which sets `coordinator.onMerged = { _ = try store.settleVersions() }` and gives that same store to `SyncProbe.runIfAsked(store:)`; the probe now runs only when `!location.refusesProbes(sync: sync)` and otherwise logs `probe refused: never in the main store`.

**The test devices** (`TM/VersionFixtures.swift`). An arrival writes through the context, never through `updateNote`. The store that syncs last wins: its values go to the other and the other's never reach it.

```swift
@MainActor final class Device {
    let store: MarkupStore
    init(tag: String, kind: String = "Mac") throws                       // an in-memory container and journal
    var kept: [String] { get throws }                                    // the kept versions' texts, sorted
    func text(of noteID: UUID) throws -> String?
}
enum NoteValue: CaseIterable { case body, mark, ancestry, kind }
@MainActor enum Arrival {
    /// `to` takes `from`'s copy of the note, the named values only (`body` brings `modifiedAt`); the note is made there if missing.
    static func note(_ id: UUID, from: Device, to: Device, values: Set<NoteValue> = Set(NoteValue.allCases)) throws
    /// The note is deleted in `to`; `from`'s markers for it come too unless `withMarkers` is false.
    static func delete(_ id: UUID, from: Device, to: Device, withMarkers: Bool = true) throws
    /// `to` gains the kept versions and markers `from` has and it lacks, and loses the kept versions whose uuids are in `deleted`.
    static func versions(from: Device, to: Device, deleted: Set<UUID> = []) throws
}
```

- [ ] **Step 1: Write the failing tests.** `TM/VersionKeeperTests.swift` (`@MainActor`; `a`, `b`, `c` are devices tagged `aaaa`, `bbbb`, `cccc`; `shared()` makes a chapter note "base" on Genesis 1 on `a` and sends it whole to the others; an edit is one sitting with one save unless said):
  - `twoEditsWithoutSightKeepTheLosersTextOnceOnBoth` (with either as the winner): `a` writes "A1", `b` "B1"; the winner's note arrives at the loser; the loser's `settleVersions() == 1`, its `kept` is its own text, its note reads the winner's, its entry is forgotten. After `Arrival.versions(from: loser, to: winner)` the winner's settle returns 0 and its `kept` is the same; the loser's next settle returns 0.
  - `aLongRunOfTypingAgainstOneEditKeepsExactlyOne` (either winner): `a` saves twenty times in one sitting, then two more sittings of five; `b` edits once from "base". The loser keeps its last text, once.
  - `anEditMadeWithSightKeepsNothing`: "A1" arrives at `b`, which writes "B2" from it; it arrives at `a`: nothing kept, the entry forgotten.
  - `theSameTextTwiceKeepsNothing`: both write "same"; and "same\n" against "same".
  - `threeDevicesKeepEachLostTextOnce`: all edit, `c` wins; after every exchange and a settle on each, each device's `kept` is `["A1", "B1"]`; another round changes nothing.
  - `aChangeUnderAnUnchangedMarkKeepsThisDevicesText`: `a` wrote "A1"; a body alone arrives (`values: [.body]`): `a.kept == ["A1"]`.
  - `aBodyUnderAnotherSittingsAncestryKeepsThisDevicesText`: `c` wrote "C1" from `a`'s "A1"; `b` wrote "B1" from "base"; `a` receives `b`'s body and mark with `c`'s ancestry: `a.kept == ["A1"]`.
  - `aTextArrivingWhileTheEditorIsOpenIsKeptByTheDeviceThatWroteIt`: `a` has a sitting open with "draft" saved; `b`'s "B1" arrives; `a`'s settle returns 0 and its entry is still "draft"; `a` saves "draft2" in the sitting; it arrives at `b`: `b.kept == ["B1"]`.
  - `closingTheEditorAfterAnArrivalKeepsTheDraft`: the same, but `a` ends the sitting with no further save: `a.kept == ["draft"]`, its note reads "B1".
  - `aBlankTextIsNeverKept`: `a` wrote "A1" then emptied the note; `b`'s edit arrives: nothing kept.
  - `aDeleteThatHadNotSeenTheTextLeavesItWithNoNote`: `a` wrote "A1" unsent; `b` deleted; the delete arrives with its marker: one kept version with the note's uuid, "A1", `GEN`, chapter 1, verse 0; the entry forgotten.
  - `aDeleteThatHadSeenItKeepsNothing`: "A1" reached `b`, which deleted; arriving with its marker, nothing is kept. Arriving without it, "A1" is kept; when the marker then arrives (`Arrival.versions`), the next settle deletes that kept version.
  - `aDeleteWithNoMarkerKeepsTheText`: no marker ever comes: "A1" stays.
  - `anUndoneDeleteAgainstAnEditElsewhereStillKeeps`: `a` deleted and undid; `b` had written "B1" without sight; `a`'s note arrives at `b`: `b.kept == ["B1"]`.
  - `aKeptVersionWhoseNoteArrivesLaterJoinsIt`: a kept version reaches `c` before its note: a settle leaves it; the note arrives with another text: it is still there, once.
  - `sameTextKeptVersionsBecomeOneAndOneEqualToTheNoteGoes`: `writtenAt` 10 and 20, the first survives; equal dates, the lowest uuid; one equal to the note's text is deleted; two sharing a uuid both stay.
  - `markersOlderThanNinetyDaysGo`: 91 days, deleted; 89, kept.
  - `noClockDecidesAClash`: the first test with `b`'s saves dated a year before, and a year after, `a`'s: the same result.

  `TM/SyncCoordinatorTests.swift`: `everyImportSettlesBeforeItRefreshes` (`onMerged` runs once in `prepareNow()` and once per `importFinished()`, before the refresh; one that throws is logged and the refresh still runs).
- [ ] **Step 2: Run.** `--filter VersionKeeperTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** `VersionKeeperTests`, `NoteSittingTests`, `SyncCoordinatorTests` pass; then the full run.
- [ ] **Step 5: Commit.** `feat: a text this device lost to another's edit or delete is kept after the import, and kept versions are tidied (keeping data safe 4.2, 4.3)`

---

### Task 4: The three choices, Restore as a Note, and Restore from a backup (spec 4.1, 4.2, 6; 10 the three choices)

**Run:** Opus (it rewrites a note's text and merges records). No UI. Nobody needs to look.

**Files:**
- Create: `SM/MarkupStore+Versions.swift`
- Modify: `SM/MarkupSnapshot.swift` (`MarkupDeletion`), `SM/MarkupStore.swift` (`delete`, `restore`), `SM/StoreCopy.swift`, `SUI/BackupsModel.swift`, `SUI/MarkupModel.swift` (`MarkupDeletion.highlightID`), any other switch over `MarkupDeletion` the compiler names
- Test: create `TM/KeptVersionChoiceTests.swift`; modify `TM/StoreCopyTests.swift`, `T/BackupsModelTests.swift`

**Interfaces:**
- Consumes: Tasks 1 to 3 (`Device`, `Arrival`).
- Produces:

```swift
// MarkupDeletion gains `case keptVersion(KeptVersionSnapshot)`; its actionName is "Discard Version".
// RestoreSummary gains `keptVersions = 0`, in `total`.
extension MarkupStore {
    public func keptVersions(forNote id: UUID) throws -> [KeptVersionSnapshot]     // newest `writtenAt` first
    public func keptVersionCounts() throws -> [UUID: Int]                          // by `noteID`
    public func orphanVersions() throws -> [KeptVersionSnapshot]                  // those whose note is not in the store
    /// Returns the new kept version of the text it replaced; nil when that text was blank.
    @discardableResult public func useVersion(_ id: UUID, now: Date = Date()) throws -> KeptVersionSnapshot?
    public func keepBoth(_ id: UUID, now: Date = Date()) throws
    /// The note's uuid; nil when a note with that identity is in the store (the text stays its kept version).
    @discardableResult public func restoreAsNote(_ id: UUID, now: Date = Date()) throws -> UUID?
}
```

**The rules.**
- **Use This One:** a sitting is begun on the note with the kept version's kind (this device's when it has none); a `KeptVersion` is inserted for the note's present text (its `modifiedAt` as `writtenAt`, its `deviceKind`, its place), unless blank; the note's text becomes the kept text through `updateNote`; the used kept version is deleted. Nothing is changed in place.
- **Keep Both in the Note:** the note's text becomes its text, a blank line and the kept text (the kept text alone when the note is blank) through `updateNote`; the kept version is deleted.
- **Discard** is `delete(.keptVersion(snapshot))`, which deletes every record with that uuid and returns the snapshot; `restore(.keptVersion(snapshot))` inserts it again when no record has that uuid.
- **Restore as a Note:** a note with the kept version's `noteID` (a new uuid when it has none) and text, marked as a new note is, and journaled. `verse == 0`: a chapter note. Otherwise on a live highlight with the same book, chapter, verses, offsets and translation that has no note; else on a new colourless highlight made there. Then the kept version is deleted.
- **`StoreCopy`:** notes carry their three values; then a kept version whose uuid the live store lacks, and whose note has no live kept version with the same text, is inserted. Markers are not copied. **`BackupsModel.sentence`** gains `(summary.keptVersions, "kept version")` last.

- [ ] **Step 1: Write the failing tests.** `TM/KeptVersionChoiceTests.swift` (`@MainActor`):
  - `useThisOneSwapsAndKeepsTheOther`: a note "N" (kind "iPhone", `modifiedAt` 100) with a kept "K" (kind "Mac"): the note reads "K" with kind "Mac"; its one kept version is "N", `writtenAt` 100, kind "iPhone", with another uuid than the used one; the note's values have sight of "N"; the journal's entry is "K".
  - `useThisOneAgainstADiscardElsewhereLosesNeitherText`: `a` uses it while `b` discards it; after the note and the versions cross (`deleted:` the used uuid) and both settle, both read "K" with `kept == ["N"]`.
  - `twoDevicesUsingTheSameVersionEndWithOne`: both use it; after crossing and settling each has one kept "N".
  - `keepBothJoinsWithABlankLineAndRemovesTheVersion`: "N\n\nK", none kept; a blank note becomes "K".
  - `discardRemovesItAndUndoBringsItBack`: `delete` returns it and leaves none; `restore` brings back the same uuid, text and date; a second `restore` adds nothing; the action name is "Discard Version".
  - `restoreAsANoteBringsItBackOnItsPassage`: a chapter note's version: a chapter note with that uuid and text, no highlight, a mark and an entry, the kept version gone. A highlight note's, its coloured highlight still there with no note: attached to it. Its highlight gone: a highlight with no colour at the same verses and offsets, the note on it. The live highlight carrying another note: a second, colourless highlight. A note with that identity already in the store: nil, and the kept version stays.
  - `countsAndOrphans`: `keptVersionCounts()` gives 2 for a note with two kept versions and has no entry for a note with none; `orphanVersions()` lists only the kept versions whose note is gone.

  `TM/StoreCopyTests.swift`: `aMissingKeptVersionComesBackOnce` (`summary.keptVersions == 1`; a second copy adds none; one with a live one's note and text is skipped; no marker is copied; a copied note keeps its three values). `T/BackupsModelTests.swift`: `"Restored 1 note and 1 kept version."`.
- [ ] **Step 2: Run.** `--filter KeptVersionChoiceTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** The three suites pass; then the full run.
- [ ] **Step 5: Commit.** `feat: Use This One, Keep Both, Discard with its undo, and Restore as a Note; Restore carries kept versions (keeping data safe 4.1, 4.2, 6)`

---

### Task 5: Records that share an identity (spec 4.3, 5.2 the tidy-up; Departure 1)

**Run:** Opus (which record is read, written and deleted when two share a uuid). No UI. Nobody needs to look.

**Files:**
- Create: `SM/Twins.swift`
- Modify: `SM/MarkupStore.swift` (the list reads; `updateNote`, `deleteNote`), `SM/MarkupStore+Versions.swift`, `SM/ChatStore.swift` (`allThreads`, `threads(in:)`), `SM/PromptTemplateStore.swift` (`templates(scope:)`), `SM/SeedMerge.swift` (`mergeBookmarks`), `SM/VersionKeeper.swift`
- Test: create `TM/TwinTests.swift`; modify `TM/SeedMergeTests.swift`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces:

```swift
enum Twins {
    /// One record per uuid, in the order given: of those sharing a uuid, the one `prefer` puts first.
    static func firsts<Record>(_ records: [Record], id: (Record) -> UUID, prefer: (Record, Record) -> Bool = { _, _ in false }) -> [Record]
}
```

**The rules.**
- **Read as one.** `MarkupStore`'s list reads of notes, highlights, bookmarks and colours, its kept-version reads, `ChatStore.allThreads()` and `threads(in:)`, and `PromptTemplateStore.templates(scope:)` each return one record per uuid. Of two notes: the later `modifiedAt`, ties the greater `body`. Of two highlights: one with a note first, then the later `modifiedAt`. Of any other kind: the first fetched.
- **A note is written and deleted as one.** `updateNote` sets the same values on every `Note` with that uuid; `deleteNote` deletes every one, with one marker.
- **A note's copies that differ** (a new first step of `settleVersions`): among `Note` records sharing a uuid whose texts are not the same, the one read stays. For each other, a `KeptVersion` is inserted for its text (its `modifiedAt`, `deviceKind` and place) unless it is blank or the survivor was made with sight of it; then that copy is deleted. Copies with the same text are never deleted.
- **`mergeBookmarks`** leaves a bookmark that shares its uuid with the survivor, as `mergeTicks` does.

- [ ] **Step 1: Write the failing tests.** `TM/TwinTests.swift` (`@MainActor`; twins are inserted through the context with one uuid):
  - `copiesOfANoteThatDifferLeaveAKeptVersion`: "old" (`modifiedAt` 10) and "new" (20): after a settle one `Note` record, "new", and `kept == ["old"]`; a second settle changes nothing.
  - `twoDevicesChoosingDifferentlyLoseNeitherText`: with each device's choice applied to one store (no `Note` left, a kept version for each text), both texts are in `orphanVersions()`.
  - `aCopyTheSurvivorWasMadeFromIsNotKept`: one record left, nothing kept.
  - `copiesThatAreTheSameAreLeftAndReadOnce`: a settle deletes neither; `allNotes().count == 1`; `updateNote` leaves both records with the new text and one mark; `deleteNote` removes both and leaves one marker.
  - `everyKindIsReadOnce`: a twin each of a highlight, a bookmark, a colour, a conversation, a prompt and a kept version: each list read returns one while `fetchCount` is two; the highlight read is the one carrying the note.

  `TM/SeedMergeTests.swift`: `sameIdentityBookmarksSurviveTheMerge` (two with one uuid on one verse: 0 deleted; two with different uuids still become one).
- [ ] **Step 2: Run.** `--filter TwinTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** `TwinTests`, `SeedMergeTests`, `VersionKeeperTests`, `MarkupStoreTests`, `ChatStoreTests`, `PromptTemplateStoreTests` pass; then the full run.
- [ ] **Step 5: Commit.** `feat: records that share an identity are read as one, a note's differing copies leave a kept version, and nothing else is deleted for it (keeping data safe 5.2)`

---

### Task 6: The editors' sittings, the counts and the versions model (spec 4.1, 4.3; 10 the mark's count, the filter)

**Run:** Opus (where editing begins and ends; undo). No view is drawn here. Nobody needs to look.

**Files:**
- Create: `SUI/NoteVersionsModel.swift`
- Modify: `SUI/MarkupModel.swift`, `SUI/NotesColumnItem.swift`, `SUI/NotesBrowserEntry.swift`, `SUI/NotesBrowserLoader.swift`, `SUI/NotesBrowserModel.swift`, `SUI/MarkdownExport.swift`, `SUI/MarkupTarget.swift`, every exhaustive switch over `NotesBrowserEntry.Kind` or `NotesBrowserFilter` the compiler names (`NotesBrowserRow`, `NotesBrowserView`, `PhoneNotesScreen`: give each the plainest answer; Tasks 7 and 8 own their look, and until Task 8 the phone's menu lists the new kind always), `SHARED/AppModels.swift` (a `versions` member), `SHARED/AppSync.swift` (`Models.versions`, `reloadModels`), `MAC/ReadingThroughScriptureApp.swift` and `IOS/ReadingThroughScriptureApp.swift` (the environment, beside `\.noteLinks`)
- Test: create `T/NoteVersionsModelTests.swift`; modify `T/MarkupModelTests.swift`, `T/NotesBrowserModelTests.swift`, `T/NotesBrowserQueryTests.swift`, `T/MarkdownExportTests.swift`

**Interfaces:**
- Consumes: Tasks 2 to 5.
- Produces:

```swift
// NoteCard and NotesBrowserEntry each gain `versionCount: Int = 1` (the init's last parameter).
// NotesBrowserEntry.Kind gains `.keptVersion(id: UUID)` (a text with no note). NotesBrowserFilter gains `.keptVersions`.
// NotesBrowserLoader.entries(store:query:includingKeptVersions: Bool = false)
// NotesBrowserModel: public private(set) var hasKeptVersions: Bool
public struct NoteVersions: Equatable, Sendable {
    public struct Current: Equatable, Sendable { public let body: String; public let deviceKind: String?; public let modifiedAt: Date }
    public let noteID: UUID, book: String, current: Current, kept: [KeptVersionSnapshot]
}
public enum VersionsSubject: Hashable, Sendable { case note(UUID), orphan(UUID) }
public enum VersionChoice: CaseIterable, Sendable {
    case use, keepBoth, discard, restoreAsNote
    public var title: String                                            // "Use This One", "Keep Both in the Note", "Discard", "Restore as a Note"
    public var help: String                                             // below
    public static func offered(hasNote: Bool) -> [VersionChoice]        // [.use, .keepBoth, .discard], or [.restoreAsNote, .discard]
    public static func prominent(hasNote: Bool, keptCount: Int) -> VersionChoice?   // .restoreAsNote with no note; .use when keptCount == 1; else nil
}
public enum VersionText {
    public static let symbolName = "square.on.square"
    public static func mark(count: Int) -> String                       // "2 versions"
    public static let orphanMark = "Kept version"
    public static func title(count: Int) -> String                      // "Two versions of this note" to "Nine …"; above nine, the figure
    public static let subtitle = "It was changed on two devices before they synced. Nothing was lost."
    public static let orphanTitle = "A version with no note"
    public static let orphanSubtitle = "The note was deleted on one device and changed on another before they synced. Nothing was lost."
    public static func name(kept: Bool, deviceKind: String?) -> String  // "This version · iPhone"; "Kept version" with no kind
    public static func time(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String
    public static func spoken(kept: Bool, deviceKind: String?, at date: Date, now: Date, calendar: Calendar, locale: Locale) -> String   // the name and time, comma separated
}
@MainActor @Observable public final class NoteVersionsModel {
    public private(set) var revision: Int
    public private(set) var lastError: String?
    public init(store: MarkupStore, onChange: @escaping @MainActor () -> Void = {})
    public func reload()                                                // bumps `revision`
    public func versions(forNote id: UUID) -> NoteVersions?            // nil when the note has no kept version or is gone; reads `revision`
    public func orphan(id: UUID) -> KeptVersionSnapshot?
    public func perform(_ choice: VersionChoice, on keptID: UUID, undoManager: UndoManager?)
    public func clearError()
}
extension EnvironmentValues { @Entry public var noteVersions: NoteVersionsModel? }
```

**The rules.**
- **A sitting in `MarkupModel`:** one private `NoteSitting?`, begun (`store.beginSitting`) wherever `editingNoteID` becomes a note's id and ended (`store.endSitting`) wherever it stops being it ("Built on" lists both sets of sites); `updateNoteBody` passes it when it is that note's. `reload()` reads `keptVersionCounts()` once and gives each card `1 +` its count. `endEditing` ends the sitting, then reloads the cards, so a text kept as the sitting ends shows at once.
- **A choice's help:** "Make this the note's text. The other becomes the kept version."; "Put this text under the note's text."; "Remove this kept version. Undo brings it back."; "Put this text back as a note on its passage."
- **`time`:** `now`'s day is "Today " and the time; the day before, "Yesterday " and the time; otherwise the abbreviated month and day, a comma and the time, with the year after the day when it is not `now`'s. The time is `Date.FormatStyle(time: .shortened)` in the locale.
- **The browser.** With `includingKeptVersions`, the loader gives each note its count and appends one entry per `orphanVersions()` (its uuid, `.keptVersion`, the place, the quoted words, the text as `body`, `writtenAt` as `modifiedAt`), searched as a note is. Only `NotesBrowserModel` asks for them, so ⌘K and `NotesExporter` never see one, and `MarkdownExport.render` skips one it is given. `.keptVersions` keeps a note whose `versionCount > 1` and every `.keptVersion`; every other filter, `.all` included, drops `.keptVersion`, and `totalCount` does not count them. `hasKeptVersions` is true while either exists; when it turns false with `.keptVersions` in force the filter returns to `.all`. `delete(id:)` on one is `.keptVersion(snapshot)` through the model's own undo. `MarkupTarget(entry:)` for one is its chapter and verse, with no highlight.
- **`perform`:** `.use`, `.keepBoth` and `.restoreAsNote` call the store; `.discard` deletes through `MarkupDeletion.keptVersion` and registers the undo (which restores and registers the redo) in the manager given, named "Discard Version". Each then bumps `revision` and calls `onChange`. A failure sets `lastError` to "That change could not be saved. Try it again."
- **The wiring.** `AppModels` makes one model whose `onChange` reloads the markup model and the notes browser; `AppSync.reloadModels()` calls its `reload()`. The Mac's main window and Notes window and the phone's root view get it in the environment.

- [ ] **Step 1: Write the failing tests.** `T/NoteVersionsModelTests.swift` (`@MainActor`; `en_US`, a Gregorian calendar in UTC, `now` 2026-11-19 12:00 UTC):
  - `theWordsAreTheSpecs`: `mark(count: 2) == "2 versions"`; `title(count:)` for 2, 3 and 12 is "Two versions of this note", "Three versions of this note", "12 versions of this note"; `name` gives "This version · iPhone", "Kept version · Mac", and "Kept version" for a nil or empty kind; `time` gives "Today 8:14 AM" (the 19th, 08:14), "Yesterday 9:40 PM" (the 18th, 21:40), "Nov 12, 9:40 PM" and, for 2025, "Nov 12, 2025, 9:40 PM" (the space before AM and PM is the formatter's own U+202F; the tests write `\u{202F}` there, never a plain space); `offered` and `prominent` as their comments say (`prominent(hasNote: true, keptCount: 2) == nil`).
  - `eachChoiceChangesTheStoreAndTellsTheApp`: each of the four gives Task 4's outcome, one `onChange`, `revision` up by one.
  - `discardIsUndoneAndRedoneThroughTheManagerGiven`: `undoActionName == "Discard Version"`; undo brings it back, redo removes it.
  - `versionsForANoteWithNoneIsNil`.

  `T/MarkupModelTests.swift`: `oneSittingPerEditHoweverManyKeystrokes` (five `updateNoteBody` calls share a token; after `endEditing` and `beginEditing` the next has another, opened on the first's last text); `leavingTheBookEndsTheSitting` (`store.openSittings` is empty); `aCardCountsItsVersions` (2 after a kept version is inserted and the model reloads); `aDraftIsKeptWhenAnotherDevicesTextArrivedMidEdit` (an arrival and a settle during the edit keep nothing; `endEditing` leaves the card with `versionCount == 2`).

  `T/NotesBrowserModelTests.swift`: `theKeptVersionsFilterListsNotesWithOneAndTextsWithNoNote` (a note with a kept version, a plain note and an orphan: under `.keptVersions`, the first and the orphan; under `.all` no orphan and `totalCount` unchanged; the orphan's entry reads "Genesis 1" with its text; once both are settled `hasKeptVersions` is false and `filter == .all`); `deletingATextWithNoNoteDiscardsItUndoably`. `T/NotesBrowserQueryTests.swift`: the filter's three cases. `T/MarkdownExportTests.swift`: `textsWithNoNoteStayOutOfTheMarkdownAndThePalette`.
- [ ] **Step 2: Run.** `--filter NoteVersionsModelTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** The five suites pass; then the full run.
- [ ] **Step 5: Commit.** `feat: one sitting per edit in both editors, a note's version count, the Kept versions filter, and the model behind the versions view (keeping data safe 4.1, 4.3)`

---

### Task 7: The mark and the versions view on the Mac (spec 4.1, 4.2, 7; the mockup)

**Run:** Opus (a popover on a row with its own click contract; undo across a popover). Offscreen renders, which cannot show: the popover's chrome, anchor and arrow in any appearance; that a click on the mark neither selects nor edits its row; Tab reaching the mark and the buttons; ⌘Z after the popover has closed; the popover closing once settled; the toolbar's picker with a sixth segment at 520 pt. The controller looks live in Task 12.

**Files:**
- Create: `SUI/VersionsMark.swift`, `SUI/NoteVersionsView.swift` (`NoteVersionsView`, `VersionBlock`)
- Modify: `SUI/NoteRowView.swift`, `SUI/NotesBrowserRow.swift`, `SUI/NotesBrowserView.swift`
- Test: create `T/NoteVersionsViewTests.swift`

**Interfaces:**
- Consumes: Task 6.
- Produces:

```swift
public struct VersionsMark: View { public init(text: String) }
public struct NoteVersionsView: View {
    public init(subject: VersionsSubject, model: NoteVersionsModel, undoManager: UndoManager?, onSettled: @escaping () -> Void = {})
    struct Block: Equatable, Identifiable { let id: UUID; let keptID: UUID?; let name, time, spoken, body: String; let choices: [VersionChoice]; let prominent: VersionChoice? }
    nonisolated static func blocks(for versions: NoteVersions, now: Date, calendar: Calendar, locale: Locale) -> [Block]   // this version, then the kept, newest first
    nonisolated static func blocks(forOrphan version: KeptVersionSnapshot, now: Date, calendar: Calendar, locale: Locale) -> [Block]   // one block: [.restoreAsNote, .discard], .restoreAsNote prominent
}
struct VersionBlock: View, Equatable
// NoteRowView: nonisolated static func spokenTitle(for card: NoteCard, colorName: String?) -> String   // today's title, and ", 2 versions" when it has them
```

**The mark.** `Image(systemName: VersionText.symbolName)` and the text, `xxs` apart, both `.caption` `ink.secondary`, padded `xs` across and `xxs` down, on `Color.paperOverlay` in a `Capsule`, no stroke. As a button: `.buttonStyle(.plain)`, a scaled 24 pt minimum hit height, the help "Show the versions of this note", its text as its label.

**The versions view.** A `VStack(alignment: .leading, spacing: AppSpacing.sm)`:
- The title (`VersionText.title(count:)` or `orphanTitle`) in `.headline` `ink.primary` with the header trait; `xxs` under it the subtitle in `.caption` `ink.secondary`.
- Each block, a 1 pt `Color.inkRule` line above it. **A block,** `xs` between its parts: the name in `.caption` semibold `ink.secondary` with the time trailing in `.caption` `ink.secondary` (`ViewThatFits`: one line, else the time under the name); the text as `NoteBodyText(_, book:, font: .callout)` with `\.noteLinks` nil; for a kept one, its choices `xs` apart (`ViewThatFits`: a row, else stacked, leading), `.bordered` at the regular control size (24 pt on the Mac; `.small` is 20 pt and under the hit-area rule, found in Task 7's review), the prominent one `.borderedProminent`.
- **VoiceOver:** a block is one element, its label `spoken`, its value its text, with one action per choice named by its title.
- It reads its subject from the model on every draw, and calls `onSettled` when there is nothing left to settle. A choice calls `model.perform(_:on:undoManager:)` with the manager it was given.

**On the rows.**
- **`NoteRowView`:** when `card.versionCount > 1` and the editor is not showing, the mark sits under the body. On macOS it is a button showing a popover on itself: the versions view for `.note(card.id)` in a `ScrollView`, padded `sm`, a `@ScaledMetric(relativeTo: .callout)` 330 pt wide and at most a scaled 420 pt tall, given the row's own `@Environment(\.undoManager)`; `onSettled` closes it. On iOS it is the mark alone. The row's label is `spokenTitle`, and it has an action named by the mark's text that shows the versions.
- **`NotesBrowserRow`:** the same mark, popover and action under the row's lines. A `.keptVersion` entry leads with `square.on.square` in `ink.secondary`, shows its reference, quoted words and first lines as a note does, and its mark reads "Kept version" and shows `.orphan(entry.id)`; its kind for VoiceOver is "Kept version".
- **`NotesBrowserView`:** the picker's sixth segment, `Text("Kept versions")`, is there only while `model.hasKeptVersions || model.filter == .keptVersions`; the help ends "…bookmarks, conversations or kept versions". A row with versions has "Show Versions" in its context menu. The delete dialog's sentence for a `.keptVersion` is "The kept version will be discarded. Edit › Undo brings it back.", and its button is "Discard" with no destructive role The popovers are given `model.undoManager`.

- [ ] **Step 1: Write the failing tests.** `T/NoteVersionsViewTests.swift`: `theBlocksAreThisVersionThenTheKeptNewestFirst` (two kept, dated 10 and 20: three blocks; the first has no `keptID` and no choices; then 20, then 10, each offering `[.use, .keepBoth, .discard]` with no prominent one; with one kept, `.use` is prominent); `aTextWithNoNoteOffersRestoreAndDiscard` (`blocks(forOrphan:)` gives one block offering `[.restoreAsNote, .discard]`, `.restoreAsNote` prominent); `aRowSaysItsVersions` (`spokenTitle` ends ", 2 versions" for a card with 2 and is today's title for 1).
- [ ] **Step 2: Run.** `--filter NoteVersionsViewTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** `NoteVersionsViewTests`, `NotesBrowserModelTests`, `SepiaModeTests` pass; then the full run.
- [ ] **Step 5: See it.** Offscreen, each in light, dark and Sepia, in a container taller than the view: the notes column 300 pt wide with the mockup's two notes (John 15:5 with "2 versions", John 15:9 without), the first lit and unlit; the versions view at its popover width with the mockup's two texts, with three versions, with a text with no note, with a note of forty lines, and at one accessibility text size; a Notes Browser row with the mark, and a "Kept version" row. Open every picture: the mark is quiet and unboxed, never red or the accent; the two texts cannot be confused; the buttons fit or stack; nothing is a card.
- [ ] **Step 6: Commit.** `feat: the versions mark on a note and both versions with their three choices, in the Mac's notes column and Notes window (keeping data safe 4.1, 4.2)`

---

### Task 8: The mark and the versions on the iPhone (spec 4.1, 4.2)

**Run:** Sonnet. `TestWindow` renders, which cannot show: the push inside the note sheet and its way back; a shake undoing a Discard; the sheet's bars; the "What kind" menu open. The controller looks live in Task 12; Matt tries it on his phone in Task 13.

**Files:**
- Create: `PH/PhoneVersionSheet.swift`, `SUI/PhoneNotesKinds.swift` (not under `#if os(iOS)`, so its suite runs in both test runs)
- Modify: `PH/PhoneMarkRow.swift`, `PH/PhoneNotesScreen.swift`, `PH/PhoneNoteSheet.swift`
- Test: create `T/PhoneVersionsTests.swift`

**Interfaces:**
- Consumes: Tasks 6 and 7.
- Produces:

```swift
public enum PhoneNotesKinds {
    public static func offered(hasKeptVersions: Bool, current: NotesBrowserFilter) -> [NotesBrowserFilter]   // the five; `.keptVersions` last only while there is one or it is current
    public static func title(for filter: NotesBrowserFilter) -> String      // as today, and "Kept versions"
    public static func mark(for entry: NotesBrowserEntry) -> String?        // "2 versions"; "Kept version" for a text with no note; nil otherwise
}
#if os(iOS)
public struct PhoneVersionSheet: View { public init(id: UUID, reference: String, model: NoteVersionsModel, undoManager: UndoManager?) }
#endif
```

**The rules.**
- **`PhoneMarkRow`** gains `versions: String? = nil` (its init's last parameter): `VersionsMark(text:)` under the note's lines, and the row's spoken label ends with it.
- **The Notes tab:** the menu lists `PhoneNotesKinds.offered`; each row is given `PhoneNotesKinds.mark(for:)`. A `.keptVersion` row has the symbol `square.on.square`, the kind "Kept version", its reference, quoted words and first lines; a tap presents `PhoneVersionSheet`; its swipe is "Discard" (`trash`, no destructive role), which is `notesBrowser.delete(id:)`.
- **`PhoneVersionSheet`:** a `NavigationStack` on `paper.page`, the reference as its inline title, Done (`checkmark`) in the confirmation slot, the versions view for `.orphan(id)` in a `ScrollView` padded `md`; `.medium` and `.large`; `onSettled` dismisses it.
- **`PhoneNoteSheet`:** while the note is being read and `card.versionCount > 1`, the mark sits under the note's text as a button at least a scaled 44 pt tall. It pushes (`navigationDestination(isPresented:)`) the versions view for `.note(noteID)` with `markup.undoManager`, in a `ScrollView` padded `md`, titled "Versions" inline, on `.containerBackground(Color.paperPage, for: .navigation)`, with `UndoResponder(undoManager: markup.undoManager)` behind it; `onSettled` pops it. Not shown while editing.

- [ ] **Step 1: Write the failing tests.** `T/PhoneVersionsTests.swift`: `keptVersionsIsOfferedOnlyWhileThereIsOne` (five with `false` and `.all`; six, the last `.keptVersions`, with `true` or with `current: .keptVersions`; its title "Kept versions", `.threads` still "Conversations"); `aRowsMarkIsItsCountOrKeptVersion` (nil for a note with one version, "2 versions" for two, "Kept version" for a `.keptVersion`, nil for a bookmark).
- [ ] **Step 2: Run.** `--filter PhoneVersionsTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** The suite passes in both test runs; then the full run.
- [ ] **Step 5: See it** in a `TestWindow` of 402 by 874, each in light, dark and Sepia: the Notes tab with a note that has "2 versions", a plain note and a "Kept version" row; the note sheet reading a note with the mark; the versions page with two versions and with three; `PhoneVersionSheet`; the versions page at one accessibility text size. Open every picture: the mark has room for a thumb in the sheet, the buttons stack where they do not fit, the two texts are plainly two.
- [ ] **Step 6: Commit.** `feat: the versions mark, the versions page in the note sheet and Kept versions in the Notes tab on the iPhone (keeping data safe 4.1, 4.2)`

---

### Task 9: The data file (spec 5.1, 5.3; 9 the types and keys; 10 export)

**Run:** Sonnet. No UI. Nobody needs to look. It needs Tasks 2 to 5, and nothing of Tasks 6 to 8.

**Files:**
- Create: `SM/DataFile.swift` (`DataFile`, its records, `JSONValue`, `DataImportError`), `SM/DataExport.swift`
- Test: create `TM/DataFixtures.swift`, `TM/DataFileTests.swift`, `TM/DataExportTests.swift`

**Interfaces:**
- Produces:

```swift
public enum JSONValue: Codable, Equatable, Sendable { case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue]) }
public enum DataImportError: Error, Equatable { case damaged, foreign, newer(Int) }
public struct DataFile: Codable, Equatable, Sendable {
    public static let formatName = "bible-carrel-data"
    public static let currentVersion = 1
    public static let maximumBytes = 268_435_456
    public var format: String, version: Int, exportedAt: Date, app: String
    public var colors: [Color], highlights: [Highlight], notes: [Note], keptVersions: [KeptVersion], bookmarks: [Bookmark]
    public var prompts: [Prompt], plans: [Plan], ticks: [Tick], conversations: [Conversation]      // nested Codable structs, keys below
    public func encoded() throws -> Data                                 // pretty-printed, sorted keys
    public static func read(_ data: Data, maximumBytes: Int = DataFile.maximumBytes) throws -> DataFile   // throws DataImportError
    public func hasTheSameRecords(as other: DataFile) -> Bool           // everything but `exportedAt` and `app`, each kind by id
}
public enum DataExport {
    @MainActor public static func file(from store: MarkupStore, includesConversations: Bool, app: String, now: Date = Date()) throws -> DataFile
}
```

**The keys** (every `id` is the record's uuid as text; a `?` is left out when nil):

| Key | Each record |
|---|---|
| top level | `format`, `version`, `exportedAt`, `app`, then the nine below |
| `colors` | `id`, `name`, `lightHex`, `darkHex`, `sortOrder`, `isDefault`, `builtInKey?` |
| `highlights` | `id`, `book`, `chapter`, `verse`, `endVerse`, `startOffset`, `endOffset`, `translationID`, `colorID?`, `quotedText`, `createdAt`, `modifiedAt` |
| `notes` | `id`, `body`, `createdAt`, `modifiedAt`, `scope`, `book`, `chapter`, `verse`, `endVerse`, `translationID`, `quotedText`, `highlightID?`, `sourceThreadID?`, `versionMark?`, `versionAncestry?`, `deviceKind?` |
| `keptVersions` | `id`, `noteID?`, `body`, `writtenAt`, `deviceKind`, `book`, `chapter`, `verse`, `endVerse`, `translationID`, `quotedText`, `startOffset`, `endOffset` |
| `bookmarks` | `id`, `book`, `chapter`, `verse`, `createdAt`, `label?` |
| `prompts` | `id`, `title`, `summary`, `body`, `scope`, `section?`, `isEnabled`, `sortOrder`, `isBuiltIn`, `builtInKey?`, `outputKind` |
| `plans` | `id`, `title`, `createdAt`, `modifiedAt`, `weeks` (the stored `PlanCoding` JSON, embedded as it is) |
| `ticks` | `id`, `planID?`, `readingID?`, `tickedAt` |
| `conversations` | `id`, `scope`, `book`, `chapter`, `verse`, `endVerse`, `startOffset`, `endOffset`, `translationID`, `quotedText`, `title`, `createdAt`, `updatedAt`, `messages` |
| a message | `id`, `role`, `content`, `createdAt`, `providerID`, `modelName`, `attachedReference?`, `displayText?`, `providerHost?`, `finishReason?`, `savedNoteID?` |

**The rules.**
- `scope`, `section` and `role` are the stored raw text. Dates are ISO 8601 in UTC with milliseconds; reading accepts a date with or without them.
- **The export** reads through the store's list reads (a twin is written once; ticks, which have no read-as-one list read, are written one per uuid), colours by `sortOrder`, the rest by creation date then uuid, messages oldest first. It holds no deletion marker, key or preference. With `includesConversations` false, `conversations` is empty and nothing else changes. A plan whose stored weeks are not JSON is left out.
- **`read`:** data longer than `maximumBytes`, data that is not a JSON object, a `version` under 1 or a known key of the wrong shape is `.damaged`; an object whose `format` is missing or not `formatName` is `.foreign`; a `version` above `currentVersion` is `.newer(version)`, checked before the records are decoded. A missing kind reads as empty; an unknown key is ignored.

- [ ] **Step 1: Write the failing tests.** `TM/DataFixtures.swift`: `DataSample.fill(_ store: MarkupStore)` puts in one of everything, made up, on WEB text: a default and a custom colour; a coloured highlight with a note saved from a conversation, a chapter note, a noteless highlight; a kept version of the first note and one with no note; a bookmark with a label; a built-in and a custom prompt; `PlanSample.standIn(today:)` on a fixed day with two ticks; a conversation of two turns.

  `TM/DataExportTests.swift` (`@MainActor`):
  - `everyKindIsWrittenUnderItsOwnKey`: the counts are 2, 2, 2, 2, 1, 2, 1, 2, 1 in the table's order; the first note has its `highlightID`, `sourceThreadID` and three version values; the encoded text's top-level keys are exactly the thirteen; `format`, `version == 1` and `app` as given.
  - `markersKeysAndPreferencesAreNotInIt`: with a marker in the store, the text has no `"deletedAt"` and no top-level key beyond the thirteen.
  - `theConversationsSwitchLeavesThemOut`: `conversations` is empty; the note still names its `sourceThreadID`.
  - `aPlanIsWrittenWithItsWeeksAsStored`: `plans[0].weeks` is the stored `weeksData` as `JSONValue`, holding `"v": 1`.
  - `aTwinIsWrittenOnce`: a note, a kept version and a tick each inserted twice with one uuid appear once each in the file.

  `TM/DataFileTests.swift`:
  - `datesAreISO8601TextWithMilliseconds`: `Date(timeIntervalSince1970: 1_700_000_000.5)` is written `"2023-11-14T22:13:20.500Z"`; `"2023-11-14T22:13:20Z"` reads as the whole second.
  - `encodingRoundTrips`: `try DataFile.read(file.encoded()) == file`.
  - `aDamagedAForeignAndANewerFileAreToldApart`: empty data, `not json`, `[1,2]`, a file cut off halfway, a Markdown export's text, and any data read with `maximumBytes: 10` are `.damaged`; `{"hello":1}` and `{"format":"other","version":1}` are `.foreign`; a good file with `"version": 2` is `.newer(2)`; a good file with one kind's key removed reads with that kind empty.
- [ ] **Step 2: Run.** `--filter DataFileTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** The two suites pass; then the full run.
- [ ] **Step 5: Commit.** `feat: everything the reader has made as one JSON file, format version 1 (keeping data safe 5.1, 5.3)`

---

### Task 10: Import (spec 5.2; 10 import, round trip)

**Run:** Opus (it merges a file into the synced store). No UI. Nobody needs to look.

**Files:**
- Create: `SM/DataImport.swift`
- Test: create `TM/DataImportTests.swift`

**Interfaces:**
- Consumes: Task 9; `NoteVersion`; Task 5's reads.
- Produces:

```swift
public struct ImportSummary: Equatable, Sendable {
    public var added = RestoreSummary()          // by kind, kept versions included
    public var versionsKept = 0                  // notes here already, or on a highlight that already has a note, that gained the file's text as a kept version
    public var alreadyHere = 0                   // records of the file neither added nor kept; a conversation counts once
    public init()
}
public enum DataImport {
    /// Adds what the store lacks; never changes or deletes a record. One save; a failure rolls back and throws.
    @MainActor public static func apply(_ file: DataFile, to store: MarkupStore, now: Date = Date()) throws -> ImportSummary
}
```

**The rules, in order.** A record added keeps its identity and every fact the file holds.
1. **Colours.** Here already: its uuid, or for one with a `builtInKey`, a live colour with that key. A file colour that is here under another uuid is remembered, so a file highlight naming it takes the live colour's uuid.
2. **Highlights:** by uuid.
3. **Notes.** *Not here:* added with its three values and `sourceThreadID`, on the highlight its `highlightID` names when that highlight is in the store with no note; when that highlight carries another note, the file's text becomes a kept version of that note instead (counted in `versionsKept`); with no such highlight it stands alone. *Here, the same text:* already here. *Here, another text:* already here when the store's note was made with sight of the file's text, or a kept version of that note already has it; otherwise a `KeptVersion` is inserted (the note's uuid, the file's text, `modifiedAt` and `deviceKind`, the store note's place) and `versionsKept` goes up. A blank text is never kept.
4. **Kept versions:** here already by uuid, or when its note has a live kept version with the same text, or when its text is its live note's.
5. **Bookmarks:** by uuid or by verse. **Plans:** by uuid; added with its weeks as written, whatever their `"v"`. **Ticks:** by uuid or by plan and reading. **Conversations:** by uuid, added with every message. **Prompts:** a built-in by its key, another by uuid.
6. A note the import adds is journaled as this device's text and loses its markers that name that text, as an undone delete and a backup restore do (changed while Task 10 was built: one rule for every way a note comes back); nothing else added is journaled, and nothing here is changed.

- [ ] **Step 1: Write the failing tests.** `TM/DataImportTests.swift` (`@MainActor`; `full` is a store filled by `DataSample.fill`, `file` its export with conversations):
  - `intoAnEmptyStoreEverythingArrives`: `added.total` is the file's record count (a conversation once), nothing kept, none already here; the note is on its highlight with its three values; the turns are in order; the plan reads back with both ticks.
  - `aSecondImportAddsNothing`: `added.total == 0`, `versionsKept == 0`, `alreadyHere` the record count, every table's `fetchCount` unchanged.
  - `exportImportExportHoldsTheSameRecords`: `file.hasTheSameRecords(as:)` the second store's export.
  - `aDifferingNoteBecomesAKeptVersionOnce`: the store's note set to "mine" by a plain context write: after the import it still reads "mine", its one kept version is the file's text with the file's date and kind, `versionsKept == 1`; a second import keeps none.
  - `aTextTheStoresNoteWasEditedFromIsAlreadyHere`: the note edited through a sitting after the export: nothing kept.
  - `aDeletedRecordComesBack`: a note, a highlight, a bookmark, a plan and a conversation deleted, then imported: each is back with its uuid and nothing else was added.
  - `nothingHereIsChangedOrDeleted`: a renamed colour, a relabelled bookmark and a note the file lacks are as they were.
  - `hereAlreadyIsJudgedAsTheStoreMerges`: the store's own seed of the default colour (another uuid, the same key), its own built-in prompt, a bookmark on the file's verse and a tick on the file's reading: none is added, and the file's highlight takes the live colour's uuid.
  - `aHighlightBringsItsColour`; `aNoteWhoseHighlightCarriesAnotherNoteIsKeptAsItsVersion`.
  - `aPlanFromANewerCodingIsAddedUnread`: weeks saying `"v": 2`: a record is added and `PlanStore.plans()` lists it as not readable.
- [ ] **Step 2: Run.** `--filter DataImportTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** `DataImportTests`, `DataExportTests`, `PlanStoreTests` pass; then the full run.
- [ ] **Step 5: Commit.** `feat: a data file read back in: what is missing is added, a differing note keeps the file's text, nothing is changed or deleted (keeping data safe 5.2)`

---

### Task 11: Export and import in the apps (spec 5.1, 5.2, 7)

**Run:** Sonnet. Renders of the phone's Settings section and the Mac panel's accessory, which cannot show: the File menu, the save and open panels, the alert, the share sheet, the phone's file picker, ⌘K's two rows. The controller looks live in Task 12.

**Files:**
- Create: `SUI/DataTransferModel.swift`, `SUI/DataPanels.swift` (`#if os(macOS)`), `SUI/CountList.swift`, `PH/PhoneShareSheet.swift`
- Modify: `SUI/BackupsModel.swift` (`sentence` uses `CountList`), `SUI/PaletteItem.swift`, `SUI/GeneralSettingsView.swift`, `PH/PhoneSettingsScreen.swift`, `PH/PhoneNotesScreen.swift` (its share sheet moves to `PhoneShareSheet`), `SHARED/AppSync.swift` (`dataTransfer`), `MAC/ReadingThroughScriptureApp.swift`, `IOS/ReadingThroughScriptureApp.swift`
- Test: create `T/DataTransferModelTests.swift`; modify `T/PaletteCommandTests.swift`, `T/NavigationModelTests.swift` (`:1949`)

**Interfaces:**
- Consumes: Tasks 9 and 10; `SyncStatusModel.canRestore`; `SyncCoordinator.importFinished()`.
- Produces:

```swift
enum CountList { static func text(_ parts: [(Int, String)]) -> String? }   // "12 notes and 3 highlights"; nil when every count is 0
@MainActor @Observable public final class DataTransferModel {
    public private(set) var resultText: String?
    public var canImport: Bool { get }
    public static let importUnavailableText = "Import is available once iCloud has brought your notes back."
    public init(store: MarkupStore, app: String, onImport: @escaping @MainActor () -> Void, canImport: @escaping @MainActor () -> Bool = { true })
    public static func fileName(on date: Date, calendar: Calendar = .current) -> String      // "Bible Carrel Data 2026-11-16.json"
    public func exportData(includesConversations: Bool, now: Date = Date()) throws -> Data
    public func importData(_ data: Data)                                                      // sets `resultText`
    public static func sentence(for summary: ImportSummary) -> String
    public static func sentence(for error: DataImportError) -> String
}
// PaletteCommand gains `.exportAllData`, `.importData` (after `.exportNotes` in `all`); PaletteState gains `canImportData = true`.
#if os(macOS)
@MainActor public enum DataPanels {
    public static func presentExport(in window: NSWindow?, model: DataTransferModel, defaults: UserDefaults = .standard)
    public static func presentImport(in window: NSWindow?, model: DataTransferModel)
}
#endif
#if os(iOS)
@MainActor enum PhoneShareSheet { static func present(_ url: URL) }
#endif
```

**The words.**
- `sentence(for summary:)`: `"Added "`, the non-zero counts in this order (note, highlight, bookmark, color, conversation, prompt, reading plan, tick, kept version) and a period, or `"Nothing was added."`; then, when above zero, `" 2 notes have another version kept."` (`" 1 note has another version kept."`); then `" 40 were already here."` (`" 1 was already here."`).
- `sentence(for error:)`: `.damaged` "That file is damaged and could not be read. Nothing was changed."; `.foreign` "That file was not made by Bible Carrel. Nothing was changed."; `.newer` "That file was made by a newer version of Bible Carrel. Nothing was changed."
- `app` is the bundle's short version and build, as "1.0 (42)".

**The rules.**
- **`importData`:** while `canImport` is false it sets `importUnavailableText` and does nothing else. Otherwise `DataFile.read` then `DataImport.apply`: a `DataImportError` sets its sentence, any other failure the damaged one, a success the summary's, calling `onImport` once. `AppSync.attach` makes the model with `canImport: { status.canRestore }` and `onImport: { coordinator.importFinished() }`.
- **The Mac's File menu** reads: Export Notes… (⇧⌘E), **Export All Data…**, a divider, **Import Data…** (disabled while `!canImport`). `presentExport`: the save panel named by `fileName(on:)`, allowing `.json`, its accessory one `Toggle("Include conversations")` in `.body` with `md` padding, bound to `ExportPanel.includesConversationsKey` and hosted on one line as `ExportPanel`'s is; a failure shows an alert, "Your data could not be exported." with "Choose another place to save it, or check that the disk has free space." `presentImport`: the open panel allowing `.json`; the file's data goes to `importData`, and `resultText` is shown as an alert on the window with OK. Both do nothing while the window has a sheet, as `ExportPanel.present` does.
- **⌘K:** `.exportAllData` is "Export All Data…", `square.and.arrow.up`, always available; `.importData` is "Import Data…", `square.and.arrow.down`, available while `state.canImportData`; neither has a shortcut. The app fills `canImportData` and runs both in `performCommand`.
- **The phone.** `GeneralSettingsView` gains `data: DataTransferModel? = nil` (last) and, on iOS when it is given, a section after Backups: header "Your Data"; **Export All Data…**, which writes the file under the temporary directory's `Export` folder and calls `PhoneShareSheet.present`, conversations included; **Import Data…** (disabled while `!canImport`), a `.fileImporter` allowing `.json`, the file read inside its security scope; under them `resultText` in `.callout` `ink.secondary`, announced to VoiceOver; the footer "Export All Data writes everything you have made to one file. Import Data adds what is missing from a file and changes nothing else.", followed by `importUnavailableText` while import is unavailable. `PhoneSettingsScreen` gains `data:` after `backups:`. The Mac's Settings does not show the section.

- [ ] **Step 1: Write the failing tests.** `T/DataTransferModelTests.swift` (`@MainActor`):
  - `theSentenceSaysWhatHappenedInOneLine`: 12 notes and 3 highlights added, 2 kept, 40 here: `"Added 12 notes and 3 highlights. 2 notes have another version kept. 40 were already here."`; ones: `"Added 1 note. 1 note has another version kept. 1 was already here."`; nothing: `"Nothing was added."`; nothing added and 57 here: `"Nothing was added. 57 were already here."`
  - `aRefusalSaysWhyAndChangesNothing`: data for each of the three errors gives its sentence, leaves every count and does not call `onImport`; with `canImport` false a good file gives `importUnavailableText` and changes nothing.
  - `anImportTellsTheAppOnce`; `theExportReadsBackAndCarriesTheAppsVersion` (`app == "1.0 (42)"`; none with conversations off); `theFileIsNamedForItsDay`.

  `T/PaletteCommandTests.swift` and `T/NavigationModelTests.swift`: the count is 35; the two commands have the titles and symbols above and no keycaps; `.importData` is unavailable when `canImportData` is false; both are in the front page's available set.
- [ ] **Step 2: Run.** `--filter DataTransferModelTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** `DataTransferModelTests`, `PaletteCommandTests`, `NavigationModelTests`, `ShortcutCatalogTests`, `SepiaModeTests`, `BackupsModelTests` pass; then the full run.
- [ ] **Step 5: See it.** The phone's General page in a `TestWindow` of 402 by 874 (light, dark, Sepia): the section with no result, with the spec's sentence, and with import unavailable; the Mac panel's accessory offscreen. Open every picture: form rows and no card.
- [ ] **Step 6: Commit.** `feat: Export All Data and Import Data in the File menu, ⌘K and the phone's Settings (keeping data safe 5.1, 5.2)`

---

### Task 12: The version probe, and the rehearsal of the built code (spec 10 "rehearsed by the builder")

**Run:** Sonnet writes the probe (Steps 1 to 3). **The controller, not a subagent, runs the rehearsal and the live looks** (Steps 4 to 16), in the rehearsal identity only.

**Files:**
- Create: `SHARED/VersionProbe.swift` (`#if DEBUG`)
- Modify: `SHARED/AppSync.swift` (`onPrepared`); this plan's last section (the controller)

**Interfaces:**
- Consumes: `MarkupStore` (Tasks 2 to 4), `StoreLocation.refusesProbes(sync:)`.
- Produces:

```swift
#if DEBUG
/// `-versionProbe "<verb>:<REF>[:<text>]|…"`, run in order once the coordinator has prepared, after `-syncProbe`, on both apps.
enum VersionProbe {
    static let argument = "versionProbe"
    @MainActor @discardableResult static func runIfAsked(store: MarkupStore, location: StoreLocation, sync: SyncConfiguration?) -> Bool
}
#endif
```

`REF` is a chapter, `GEN.1`; "its note" is the first ESV chapter note there. **The verbs:** `note:GEN.1:<text>` (makes or sets it, as `SyncProbe`'s does, so the phone can); `type:GEN.1:<text>` (one sitting: its note's text becomes each prefix of `<text>` in turn, a save for each); `use:GEN.1` and `keepBoth:GEN.1` (on its note's newest kept version); `discard:GEN.1` (the newest kept version of its note, or with no note there, the newest text with no note in that chapter); `restore:GEN.1` (Restore as a Note on the newest text with no note in that chapter); `seed:GEN.1:<text>` (inserts a kept version of its note, kind "iPhone", written a day ago); `seedOrphan:GEN.1:<text>` (inserts one with a new `noteID` on that chapter); `clear` (deletes every kept version and marker). It refuses the main store (`location.refusesProbes(sync:)`), logging `version probe refused: never in the main store`; otherwise it logs `version probe done: <probe>` or `version probe failed: …` to the `sync` category. It never writes a preference.

- [ ] **Step 1: Write the probe** and its call in `onPrepared` after the sync probe's, with `refreshAll()` when it changed anything. No unit test: it lives in the app targets.
- [ ] **Step 2: Build.** Both Debug builds succeed. Do not launch either app.
- [ ] **Step 3: Commit.** `test: a Debug probe that stands in for an editing sitting and for each choice on a kept version, refused in the main store`

**The rehearsal (the controller).** `S` is the scratchpad; `APP` is the rehearsal identity built at the head to `S/new-dd` (the command in "Before Task 1"); `RD` is `~/Library/Application Support/ReadingThroughScripture/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal-Development/`. **A launch** is `open -n -g -j APP --args -storeName ClashA …` (hidden, never frontmost), ended by `kill <pid>` once `/usr/bin/log show --last 5m --info --predicate 'subsystem == "com.matthewfurr.ReadingThroughScripture" AND category == "sync"'` shows `import finished` and its exports ended `failure none`. **Offline** adds `-syncProbeOffline YES`. **Sync X** is a plain launch of X. **Read** with `sqlite3 -readonly "RD/ClashA.store"` (`.tables` first: `ZNOTE`, `ZKEPTVERSION`, `ZDELETIONMARKER` are expected; `select ZBODY, ZVERSIONMARK, ZVERSIONANCESTRY, ZDEVICEKIND from ZNOTE`) and `ls RD/LastTexts-ClashA`. After a step's own launches, sync each store once more before reading.

- [ ] **Step 4: The store from before.** Sync A, then B. Each still holds Genesis 9's "before" with no mark, and both new tables exist.
- [ ] **Step 5: Setup.** A: `-syncProbe "note:GEN.1:base|note:GEN.2:base|note:GEN.3:base|note:GEN.4:base|note:GEN.5:base"`. Sync B. Both hold six notes, the five with marks.
- [ ] **Step 6: A clash, B syncing last.** A offline `-versionProbe "type:GEN.1:A one"` (read A now: one mark, its ancestry opening on `base`'s digest). B offline `-syncProbe note:GEN.1:B1`. Sync A, B, A, B. On both: Genesis 1 reads `B1`; one kept version, `A one`, kind `Mac`; A's journal has no entry for the note.
- [ ] **Step 7: Settle it.** A `-versionProbe use:GEN.1`: both read `A one` with one kept `B1`. B `-versionProbe keepBoth:GEN.1`: both read `A one`, a blank line, `B1`, with none kept.
- [ ] **Step 8: A clash, A syncing last, then Discard.** A offline `-syncProbe note:GEN.2:A2`; B offline `-syncProbe note:GEN.2:B2`. Sync B, A, B, A. Both read `A2` with one kept `B2`. A `-versionProbe discard:GEN.2`: none kept on both.
- [ ] **Step 9: Sight keeps nothing.** A `-syncProbe note:GEN.3:A3`; sync B; B `-syncProbe note:GEN.3:B3`; sync A. Both read `B3`, none kept, A's entry gone.
- [ ] **Step 10: A delete against an edit, the delete first.** A offline `-syncProbe deleteNote:GEN.4`; B offline `-syncProbe note:GEN.4:B4`. Sync A, B, A, B. No note on either; one kept version with no note, `B4`, on both; one marker. A `-versionProbe restore:GEN.4`: Genesis 4's note is back on both, `B4`, none kept.
- [ ] **Step 11: The edit first.** A offline `-syncProbe note:GEN.5:A5`; B offline `-syncProbe deleteNote:GEN.5`. Sync A, B, A, B. No note; `A5` kept with no note on both. B `-versionProbe discard:GEN.5`: none kept on both.
- [ ] **Step 12: A delete with sight keeps nothing.** A `-syncProbe note:GEN.3:A3b`; sync B; B `-syncProbe deleteNote:GEN.3`; sync A. No note, none kept, A's entry gone.
- [ ] **Step 13: The live looks,** telling Matt first; keys only, and only while the rehearsal app is frontmost and matched by pid (his Debug app has the same name). A plain launch with `-storeName Look -versionProbe "note:GEN.1:Fruit is the result of staying.|seed:GEN.1:Compare Galatians 5:22.|seedOrphan:GEN.2:A text with no note."`, then everything Tasks 7 and 11 say a render cannot show (the popover in light, dark and Sepia; each choice by key; ⌘Z after Discard; the sixth segment; both menu items and both ⌘K rows, importing the file just exported). Then the simulator's rehearsal app, built and installed as the reading-plans plan says and launched with the same arguments: what Task 8 says a render cannot show, and Settings › General's two rows. Record what was seen and what could not be driven.
- [ ] **Step 14: Clean out.** A: `-syncProbe "deleteNote:GEN.1|deleteNote:GEN.2|deleteNote:GEN.4|deleteNote:GEN.9"`; sync B, A. Then A `-versionProbe clear`; sync B; B `-versionProbe clear`; sync A, B. Both hold no note, no kept version and no marker.
- [ ] **Step 15: Clean up, on Matt's word** (the folder is under `~/Library/Application Support/ReadingThroughScripture`; ask him at the project's end, with the Debug apps' restart). Quit everything of the rehearsal identity; delete `RD` and `S/new-dd*`; `defaults delete com.matthewfurr.ReadingThroughScripture.rehearsal`; `xcrun simctl uninstall booted com.matthewfurr.ReadingThroughScripture.rehearsal`. Nothing else under `~/Library/Application Support/ReadingThroughScripture` is touched. The container and the App ID stay on Matt's account.
- [ ] **Step 16: Record every result** under "Rehearsal results, the built code", with anything that did not go as written and what was done about it, and commit: `docs: the built code rehearsed with two stand-in stores: a clash made and settled, a delete against an edit`. **If a step loses a text, stop the project there and tell Matt.**

---

### Task 13: Docs and whole-project verification

**Run:** Sonnet writes the documents and runs the suites (Steps 1 to 8). The controller restarts the Mac Debug app and, on Matt's word, installs the phone's (Step 9), and hands Matt his list (Step 10).

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, the spec (section 11), `docs/BACKLOG.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (`:239`), `docs/superpowers/specs/2026-11-17-milestone-10-handover.md` (the table and a "Project 6's open ends")

**Interfaces:**
- Consumes: every task's report and both "Rehearsal results" sections.
- Produces: the documents in step with the code.

- [ ] **Step 1: `DESIGN.md`.** Section 5, Rows: a new entry, "Versions mark and versions view", from Task 7's own words (the mark, the view, the blocks, the hairline, the choices, a text with no note, VoiceOver, Discard's undo). The Notes browser entry gains the sixth segment and the "Kept version" row; Settings › General the phone's Your Data section; the ⌘K entry's count becomes 35; the File menu's Export All Data… and Import Data…; the inventory gains `square.on.square`. Section 6: a Don't for an alert, a badge, red or the accent on a clash. Section 7: the note sheet's mark and Versions page, the Notes tab's "Kept versions" kind and row, `PhoneVersionSheet` among the sheets, Your Data.
- [ ] **Step 2: `DESIGN.json`.** The same facts where the file holds them; `python3 -I -m json.tool DESIGN.json` prints it without error.
- [ ] **Step 3: `README.md`.** Kept versions; Export All Data and Import Data, with Task 9's table of keys, format version 1 and what the file leaves out; what iCloud now holds and what stays on the device; that an older build must never be run on a store this build has opened; `-versionProbe`, and that both probes refuse the main store.
- [ ] **Step 4: The spec's section 11, As built.** Task by task, with: both rehearsals in short; the nine departures and every decision under "Decided here" with its cost; Matt's answers to the five questions; the known limits (each *Cost* above, and what the tasks' reports add); the new test counts; everything a step could not see or drive, by surface.
- [ ] **Step 5: `docs/BACKLOG.md`.** A "Keeping data safe (project 6)" section: a build that refuses a store a newer build has used, wanted before any Release update, now with two more kinds at stake; before any Release update, check that the Production CloudKit schema has the two new record types and the note's three fields; removing same-identity copies safely; an "Include conversations" switch on the phone; anything a task set aside. "Twin records from two restores" is updated: the bookmark guard is in.
- [ ] **Step 6: The main spec's milestone 10 box** for project 6, with one line, left unticked until Matt has looked; the handover's table row and "Project 6's open ends" (what was built, what was seen and by whom, what nobody has seen, both rehearsals, the rule about older builds, the Release apps untouched).
- [ ] **Step 7: The full run.** All pass and both builds succeed. Record the test counts.
- [ ] **Step 8: Commit.** `docs: keeping data safe as built; DESIGN and README in step`
- [ ] **Step 9 (the controller): the Debug apps, together.** Tell Matt first: restarting the Mac Debug app on this code moves the `.dev` store on this Mac forward again, no older build may be run on it afterwards, and his phone's Debug app should be installed straight after so that both keep and show versions. On his word: `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"` (never `pkill -x`) and `open` it; then `Scripts/install-phone.sh debug` (the phone unlocked, ProtonVPN off). The Release apps are not touched.
- [ ] **Step 10: Hand Matt his list** (spec 10, "For Matt"), with what this session could not check beside each item:
  - With the iPhone in Airplane Mode, edit one note there and on the Mac; turn Airplane Mode off; the note shows "2 versions" on both, and each choice does what it says.
  - Export All Data on the Mac; open the file; import it straight back and see "already here".
  - Delete a note, import the file, and the note is back.

  Then what nobody has seen (from Tasks 7, 8, 11 and 12), and the choices left to him: the nine departures, any of the five questions still open, and whether the Release apps are to be updated.

---

## Rehearsal results, the built code (Task 12)

**Run on 2026-11-19 by the controller,** in the rehearsal identity, with the build of `5268e78` (the head, with the version probe), on the stand-in stores `ClashA` and `ClashB`, which each held one note (Genesis 9, `before`) written by `5bda6bd`, the code from before this project. Every launch was hidden (`open -n -g -j`), ended by process id; stores were read with `sqlite3` read-only. **Every step passed as written and no text was lost.** Every export and import ended `failure none`.

| Step | What was done | What both stores held afterwards |
|---|---|---|
| 4 | The older stores opened by this build and synced | Genesis 9 `before`, with no mark; the note table has the three new values and both new tables exist. This is the proof `aStoreFromBeforeKeptVersionsOpensAndKeepsItsNotes` could not give |
| 5 | A made five notes (`base`); B synced | Six notes, the five each with a mark, its ancestry and the kind `Mac`; A's journal holds the five |
| 6 | A typed `A one` offline in one sitting; B wrote `B1` offline; synced A, B, A, B | Genesis 1 reads `B1`; one kept version, `A one`, kind `Mac`; A's journal no longer holds the note |
| 7 | Use This One on A, synced; then Keep Both on B, synced | After the first: `A one`, with `B1` kept. After the second: `A one`, a blank line, `B1`, and nothing kept |
| 8 | A wrote `A2` and B wrote `B2` offline; synced B, A, B, A; then Discard on A | `A2`, with `B2` kept; after Discard nothing kept |
| 9 | A wrote `A3`; B synced, then wrote `B3`; A synced | `B3`; nothing kept; A's journal entry gone |
| 10 | A deleted Genesis 4's note offline; B wrote `B4` offline; synced A, B, A, B; then Restore as a Note on A | No note, `B4` kept with no note, one marker. After the restore the note is back, `B4`, and nothing is kept |
| 11 | A wrote `A5` offline; B deleted the note offline; synced A, B, A, B; then Discard on B | No note, `A5` kept with no note; after Discard nothing kept |
| 12 | A wrote `A3b`; B synced, then deleted the note; A synced | No note, nothing kept, A's journal entry gone; the marker names `A3b` and the two texts before it |

Steps 10 and 11 were made in one round (their sync order is the same). The loser was in every case the store that synced first, as the first rehearsal found, and it made the kept version itself, which then reached the other store as any record does.

**Step 13, the live look** (21:02, with Matt nineteen minutes from the keyboard; the rehearsal app on a third stand-in store, `Look`; keys only, sent only while that app was frontmost by process id).

- **Seen:** the app opens on the front page and Return, Return opens Genesis 1; the notes column shows the note with its "2 versions" mark; ⌘K with `data` typed lists Export All Data… and Import Data… as its two commands, and Esc closes it; ⇧⌘N opens the Notes window, where the note carries its mark and All counts four items (the text with no note is not among them, as decided).
- **Found:** in the Notes window at about 980 pt wide the filter is not in the toolbar: it has collapsed into the toolbar's overflow (»), so "Kept versions" and the five other segments are behind a click. Whether five segments also collapsed at that width before this project is not known. It went to the whole-project review's fix wave.
- **Not driven,** because each needs a click and no agent sends one: the popover (the accessibility tree offered no element for the mark), each choice, ⌘Z after Discard, Show Versions, the File menu's two items, the panels and alerts, an export and an import. The simulator's rehearsal app was not built or opened (no agent drives the simulator's app by hand). These are on Matt's list.

**Step 14:** every note, kept version and marker the rehearsal made was deleted in all three stand-in stores and the deletes synced; each store reads empty of all three, and each journal is empty. The scratch build is deleted. **Step 15 waits for Matt's word:** the rehearsal identity's folder (`ClashA`, `ClashB` and `Look`, with their journals) and its preferences are still on this Mac.

**Run again after the fix wave** (the same evening, the build of `5e7c0a5`, whose marker names a device with each text): the notes made again, then Steps 6, 7 (Use This One), 10, 11 and 12. All passed as before; the markers read `<device tag><digest>`. And the whole-project review's own losing sequence (I-1), made with the real stores: Use This One on A, synced; B then edited the chosen text offline while A put the other text back offline; A synced first and B last. Both stores then read B's edit as the note, with **both** earlier texts kept, the one put back among them; before the fix it would have been in neither. (A variant where B's edit was made from the very words A put back keeps nothing more, rightly: those words had been seen.) Everything was cleaned out again and the scratch build deleted.

**Not rehearsed with real stores:** three devices; an older build as one side of a clash (tests only); a delete undone and then deleted elsewhere unseen (tests only); a change pushed while the app is running.

## The spec's section 10 list, by task

| Section 10 | Tasks (the tests are named in each) |
|---|---|
| Clashes: two edits in either order; a long run of typing; sight; the same text twice; three devices; an older build's change; a text arriving while the editor is open | Task 3; Task 1 (sight, values that do not hang together); Task 6 (one sitting per edit; the draft kept at the edit's end); Task 12 Steps 6, 8 and 9 |
| Deleted against edited: no sight; Restore as a Note; sight; ninety days | Task 3; Task 2 (the marker); Task 4 (`restoreAsANoteBringsItBackOnItsPassage`); Task 12 Steps 10 to 12 |
| The tidy-up: same-text versions; one equal to the note; shared identities and differing copies; Use This One against Discard | Task 3 (`sameTextKeptVersionsBecomeOneAndOneEqualToTheNoteGoes`); Task 5; Task 4 (`useThisOneAgainstADiscardElsewhereLosesNeitherText`); Departure 1 |
| The three choices | Task 4; Task 6 (`discardIsUndoneAndRedoneThroughTheManagerGiven`); Task 12 Steps 7 and 8 |
| The mark's count; the Kept versions filter | Task 6; Tasks 7 and 8 |
| Export: every kind; keys and preferences not; the conversations switch | Task 9; Departure 7 |
| Import: an empty store; a second import; a differing note; a deleted record; damaged, foreign, newer | Task 10; Task 9 (`read`); Task 11 (the sentences, the gate); Departure 6 |
| Round trip | Task 10 (`exportImportExportHoldsTheSameRecords`) |
| Storage: the store's rules; Restore carries kept versions | Task 2; Task 4 (`aMissingKeptVersionComesBackOnce`); Task 12 Step 4 |
| Rehearsed with two stand-in stores | "Rehearsal results"; Task 12 |
| Seen by eye in light, dark and Sepia | Tasks 7 and 8, Step 5; Task 12 Step 13; Matt's list |
