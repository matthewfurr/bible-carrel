# Milestone 10, project 6: keeping data safe

Status: built 2026-11-19 and **accepted by Matt on 2026-11-20** ("Ok. Tested and that all works." of the export and import on the Mac, then "Yes, it's done" when asked whether that called project 6 done, the two-device check included; he did not say which items of section 10 he tried). Approved by Matt, 2026-11-17, including the new values on a note and the two new kinds of record in iCloud (section 6). Last of milestone 10's six projects. Branch `milestone-10-study-tools`. Builds after project 5 (reading plans, which the export includes).

## 1. Intent

Two things from the comparison with michaelshimeles/bible, both about never losing what the reader wrote:

- **A note edited on two devices before they sync.** Today the later change wins and the other text is gone. The main spec lists data loss as an anti-goal. Matt: "Ok. Do it."
- **Export to JSON and import it back,** beside the Markdown export, "so your data can always come out and go back in." Matt: "Implement it."

## 2. Goals, non-goals, anti-goals

**Goals**

- When a note's text was changed in two places, both texts survive, the reader is shown both, and settles it in one click.
- A note edited on one device and deleted on another is not lost either.
- Everything the reader has made can be written to one file and read back, into this store or an empty one, with nothing lost and nothing duplicated.

**Non-goals**

- Merging two texts word by word.
- Kept versions for anything but a note's text. A highlight's colour, a bookmark, a tick and a plan keep "the later change wins"; none holds writing that could be lost.
- A history of every edit. One kept version per clash, not a timeline.
- Encrypting the export, or exporting API keys or preferences.
- Importing another app's format.

**Anti-goals**

- An alert, a badge or red for a clash. It is a quiet mark.
- An import that deletes or overwrites.
- A kept version made when nothing clashed (the same text arriving twice, or one device editing after it had the other's change).

## 3. Approaches

**Finding a clash.** The app does not see iCloud resolve a conflict; by the time a change arrives, the text it replaced is gone. Three ways to keep it: (1) each device remembers the last text it wrote for each note, and every edit records which version it was made from, so that after a sync a device can tell "this replaced my text without having seen it"; (2) keep every past version of every note as its own record; (3) read the store's change history after each sync. Chosen: (1), which is how the other app does it. (2) grows without limit and syncs it all; (3) depends on internals of Apple's sync the app has never used.

**Showing it.** Matt approved the mockup (`note-kept-versions.html`): a "2 versions" mark on the note, both versions side by side, and three choices.

**The export's shape.** One JSON file holding every kind of record with its identity, so an import can tell "already here" from "new". The Markdown export stays as the readable one.

## 4. A note changed in two places

### 4.1 What the reader sees

- The note shows the version iCloud kept, with a mark beneath it: a small symbol and "2 versions" (or "3 versions") in `.caption` `ink.secondary` on `paper.overlay`. Never an alert, never red, never the accent.
- A click on the mark shows the versions: on the Mac a popover on the note, on the iPhone a page pushed in the note sheet. At the head, "Two versions of this note" and "It was changed on two devices before they synced. Nothing was lost."
- Each version is shown rendered, as a note reads, under a label naming it and its device and time: "This version · iPhone · Today 8:14 am", "Kept version · Mac · Yesterday 9:40 pm".
- Under a kept version, three buttons:
  - **Use This One** makes the kept text the note's text; the text it replaces becomes the kept version, so choosing never throws anything away.
  - **Keep Both in the Note** puts the kept text under the current text in the one note, with a blank line between, and the kept version is gone.
  - **Discard** removes the kept version. It can be undone (⌘Z; shake on the phone).
- The mark shows wherever the note does: the notes column, the Notes Browser, the iPhone's Notes tab and note sheet. The Notes Browser's filter and the phone's "what kind" menu gain **Kept versions**, listing only notes that have one.
- VoiceOver reads the mark as "2 versions", a button; each version is an element with its label, and the three buttons are its actions.

### 4.2 A note deleted in one place and edited in another

If a note is deleted on one device without that device having seen this device's latest text, the text is kept as a version with no note. It appears under Kept versions with its reference and quoted words, and offers **Restore as a Note** (the note comes back on its passage, on a dotted underline if its highlight is gone) and **Discard**.

A delete made with sight of the latest text is an ordinary delete everywhere: nothing is kept. To tell the two apart, a delete leaves a small synced marker saying which version of the note it deleted (6); without it, every note deleted on one device would come back as a kept version on any other device that had ever edited it.

### 4.3 When a version is kept

The outcomes in 4.1 and 4.2 are what is promised. The rule below is how they are reached; it is rehearsed with two stand-in stores before it is built on (10), and the builder may change the mechanism where the rehearsal shows Apple's sync behaves otherwise, so long as the outcomes hold.

- **A version is a sitting, not a keystroke.** The editors save as the reader types, so a note's version mark changes once each time editing begins, not on every save. The mark carries a short digest of the text it labels.
- **Every sitting records what it started from:** the version the editor opened with, not whatever the note holds when a save lands. The note also carries the last few versions before that, one per change of device, so a long run of edits on one device still counts as sight of the other device's version.
- **Each device remembers,** on the device only, the last text it wrote for each note it has edited.
- **After changes arrive from iCloud,** for each note this device has edited: if the note's text is no longer this device's, and the version now there was not made from this device's version (directly or through the versions it lists), the two were written without sight of each other. This device's text becomes a kept version, unless the two texts are the same. This device then forgets its own record of that text, so it is kept once.
- A change that was made from this device's version replaces it quietly, as today.
- **A change from an older build** leaves the version mark untouched, so the mark no longer matches the text's digest. That is read as an unmarked change, and if it replaced this device's text, that text is kept, to be safe. **(call)**
- **If another device's text arrives while a note is open in the editor here,** the editor keeps the reader's draft; the save still names the version the editor opened with, so the other device recognises the clash and keeps its own text.
- **Kept versions are only ever made and removed, never rewritten.** Use This One makes a new kept version of the text it replaces and removes the one it used, so a Discard on another device at the same moment cannot lose a text.
- **After each arrival from iCloud the kept versions are tidied,** as duplicate bookmarks are today: two for one note with the same text become one, and one whose text equals the note's is removed. That also covers three devices, and one file imported on two.
- A kept version syncs, so every device shows the same mark, and settling it on one settles it on all.

## 5. Export and import

### 5.1 Export

- **Mac:** File › Export All Data… beside Export Notes…. **iPhone:** Settings › General › Export All Data…, through the share sheet.
- One file, `Bible Carrel Data 2026-11-16.json`, readable as text.
- It holds: highlight colours; highlights with their exact place and quoted words; notes, with any kept versions; bookmarks; the reader's prompts; reading plans and their ticks; and conversations with their messages, unless "Include conversations" is turned off as in the Markdown export.
- It does not hold API keys, preferences, the reading place or the Bible text.
- The file names its format and version, when it was written and by which app version.

### 5.2 Import

- **Mac:** File › Import Data…. **iPhone:** Settings › General › Import Data…, from the file picker.
- The whole file is read and checked before anything changes. A file that is damaged, not this app's, or from a newer format than the app knows changes nothing and says why in one sentence.
- **What is not here is added,** each record keeping its identity, so importing the same file twice adds nothing the second time. "Here already" is judged the way the store already judges it when it merges: a note, highlight or conversation by its identity; a default colour or built-in prompt by its built-in name; a bookmark by its verse; a tick by its reading.
- **A record that is in iCloud but has not reached this device yet** would be added twice. After every arrival from iCloud, records of any kind that share an identity are made one; where two copies of a note differ, one stays and the other's text becomes a kept version. This tidy-up is new and applies to every kind.
- **What is here already is left alone,** with one exception: a note whose text in the file differs from the store's gets the file's text as a kept version (4.1), so neither text is lost.
- **Nothing is deleted.** A record deleted here and present in the file comes back.
- A highlight whose colour is not in the store brings its colour with it.
- When it finishes it says what happened in one line, as Restore does: "Added 12 notes and 3 highlights. 2 notes have another version kept. 40 were already here."
- What was added then syncs like anything else.
- An import is not undone as a whole; it only adds, and anything it adds can be deleted in the usual way.

### 5.3 The file

A stable, documented form: each kind under its own key, each record with its identity and the same facts the store holds, dates as ISO 8601 text. The format has a version number; this build writes version 1 and reads version 1.

## 6. What is stored

**This changes what iCloud holds, and needs Matt's approval of this spec.**

- **A note gains three optional values:** a mark for the version it is now (with a digest of its text), the marks of the version that sitting started from and the few before it, and the kind of device that wrote it. Notes written before this build have none and behave as today until next edited.
- **A new kind of record, a kept version:** its identity, the note it belongs to, the text, when it was written, the kind of device, and enough about the note's passage (book, chapter, verses, translation, quoted words, where in the verse) to restore it when the note itself is gone.
- **A second new kind of record, a deletion marker:** the note it was, the version that was deleted, and when. It holds no text. Markers older than ninety days are removed.
- **On the device only,** not in iCloud: the last text this device wrote for each note it has edited, kept beside the store.
- Both follow the store's rules: every value optional or defaulted, nothing unique.
- **The store moves forward only,** as with project 5: once this build has opened it, an older build must never open it. (This sentence first said an older build "cannot"; that is wrong, and section 11 says what is true: it opens the store and strips the newer kinds and values.)
- **An older build on another device** ignores the new values and the new kind; its own edits are handled by 4.3's rule for unmarked changes.
- The daily backup already copies everything; Restore learns the new kind.

## 7. Design changes

`DESIGN.md` and `DESIGN.json`: the versions mark and the versions view (section 5, Rows; section 7, the note sheet), "Kept versions" in the Notes Browser's filter and the phone's menu, the two menu items and the Settings rows for export and import, and the symbol used for the mark in the inventory. Tokens only; the mark is a tonal step, not a card.

## 8. Constraints

- Everything in project 1's section 10.
- No test touches iCloud or Matt's stores. Two devices are stood in for by two stores, as milestone 7's rehearsal did (`-storeName Second`), and by tests that hand the model "a change arrived" directly.
- The `.dev` store gets no test notes: clashes are rehearsed in named stand-in stores only.
- Test fixtures for the export hold made-up notes and public-domain text.

## 9. Left to the builder

- The form of the version marks and the digest, and how many earlier ones a note carries.
- Whatever the rehearsal (10) shows must change in 4.3's mechanism.
- The new types that carry each kind of record into the file; today's snapshot of a note drops the conversation it came from, and colours, prompts and plans have none.
- Where the on-device record of this device's last texts is kept, and when an entry is dropped.
- How "the kind of device" is told when a reader has two Macs.
- The JSON's exact keys.
- How the import is kept from running while a sync is importing.
- The symbol for the mark.

## 10. Verification

**First, before the rule is built on: a rehearsal.** Two stand-in stores on the Mac, as milestone 7 used, each editing one note offline, synced in each order; then a delete against an edit in each order. What Apple's sync does to the losing device's text, and what each store can see afterwards, is written into the plan, and 4.3's mechanism is confirmed or changed there.

Tests first:

- Clashes: two stores edit one note without sight of each other, and after both sync in either order, one text is the note's and the other is a kept version, once, on both; one device typing for a long time (many saves in one sitting, and several sittings) against one edit on the other still keeps exactly one; an edit made after seeing the other's change keeps nothing; the same text twice keeps nothing; three devices keep each lost text once; a change from an older build under an unchanged mark keeps this device's text; a text arriving while the editor is open is kept by the device that wrote it.
- Deleted against edited: a delete that had not seen the latest text leaves it as a version with no note, and Restore as a Note brings it back on its passage; a delete that had seen it keeps nothing; markers older than ninety days go.
- The tidy-up: same-text kept versions become one; one equal to the note's text goes; records sharing an identity become one, and differing copies of a note leave a kept version; Use This One on one device against Discard on another loses neither text.
- The three choices: Use This One swaps and keeps the other; Keep Both joins and removes the version; Discard removes it and undo brings it back.
- The mark's count; the Kept versions filter.
- Export: every kind is written; keys and preferences are not; the conversations switch.
- Import: into an empty store everything arrives; a second import adds nothing; a differing note becomes a kept version; a deleted record comes back; a damaged file, a foreign file and a newer format change nothing.
- Round trip: export, import into an empty store, export again, and the two files hold the same records.
- Storage: the new values and kind obey the store's rules; Restore carries kept versions.

Rehearsed by the builder with two stand-in stores on the Mac, and the results recorded in the plan: a clash made and settled; a delete against an edit.

Seen by eye before it is called done: the mark and the versions view on the Mac and the iPhone, in light, dark and Sepia.

For Matt:

- [ ] With the iPhone in Airplane Mode, edit one note there and on the Mac; turn Airplane Mode off; the note shows "2 versions" on both, and each choice does what it says.
- [ ] Export All Data on the Mac; open the file; import it straight back and see "already here".
- [ ] Delete a note, import the file, and the note is back.

## 11. As built

Built on 2026-11-19 on `milestone-10-study-tools`, after this spec, a plan (`9a0219f`, amended after its pre-flight scan in `f4f9ef6`) of thirteen tasks and a clash rehearsal that was run before the rule was built on. Twelve building tasks (`2d2367a` to `5268e78`), each reviewed, then the controller's rehearsal of the built code, then a whole-project review (`f6b694d`: Critical 0, Important 5, Minor 14), one fix wave of seven items in five commits (`3692927` to `5e7c0a5`), a scoped re-review (`98813a0`: all seven addressed, no new Critical or Important finding, four minors), the rehearsal again on the fixed build (`771f52f`) and this task, the documents (Task 13). Nothing has been pushed or merged.

**Not yet seen by Matt, and not accepted.** The milestone 10 box for this project in the main spec is unticked until he has looked. The controller made one live pass (2026-11-19, 21:02, the rehearsal identity's app on a third stand-in store, keys only, while Matt was away from the keyboard), and it saw only what needs no click; everything else a person must do is on his list (below). **Neither Debug app has been restarted or installed on this code,** so the `.dev` store on this Mac and the phone's Debug app are still on project 5's code; the Release apps are untouched. The rehearsal identity's folder, with its three stand-in stores (`ClashA`, `ClashB`, `Look`, each empty of notes, kept versions and markers, with their journals) and its preferences, is still on this Mac until Matt says to remove it.

**Tests at `771f52f`, the code head** (the commits since are documents and one test fixture), run by Task 13 on 2026-11-19, one after another: the package suite **1,509** tests, all passing (1,097 in 105 suites in the main bundle, beside 241, 52, 91 and 28); the iOS `ScriptureUITests` **1,028 in 100 suites**, `** TEST SUCCEEDED **`; the Mac Debug build and the iOS Debug build both `** BUILD SUCCEEDED **`. The project began at 1,356 and 986, so it added 153 and 42. The CoreData "file is not a database" lines in both suites come from the store-copy test that is meant to fail. **The `DataImportTests` flake is fixed (test code only):** it failed about one run in three when run alone because its fixture wrote two chat messages in one millisecond, so their order was undefined; the fixture now gives them times a second apart, and the suite, run alone five times, passed five times (11 tests each).

### Where the code differs from the sections above

The plan's nine departures, each with what it costs if Matt says otherwise. **He has answered none of the plan's five questions (below) and none of the departures.** Each is built as written.

1. **Sections 4.3, 5.2 and 10 say records that share an identity "are made one".** Two copies with one identity are two records in iCloud, and nothing in them tells two devices which to delete; each deleting a different one loses both, because a delete always wins (the backlog's "Twin records from two restores"). Built instead: copies are **read as one**, a note's text is written to and deleted from every copy, and the tidy-up deletes nothing for sharing an identity except a note's copy whose text differs, once that text is kept, is blank, or is one the survivor was made with sight of. The bookmark merge gained the guard the tick merge has; the colour and prompt merges leave a twin with the survivor's own uuid. *If wrong:* a tidy-up that deletes twins is added later (it needs a rule for which device deletes which); nothing stored changes. Two twin highlights each carrying a note, and a twin prompt or colour moved down, can read as if they reverted: backlog.
2. **Section 6 says an older build "cannot" open the store.** It can, and it strips the new kinds and the three new values (project 5's finding; this project's rehearsal did not repeat it, but its Step 4 showed the other direction: this build opens a store from before the project and keeps its notes). With sync on they return from iCloud when this build next opens the store; what had not been sent does not. The journal is a folder beside the store and survives. The rule stands as for project 5: never run an older build on a store this build has opened; the Release apps are untouched and are updated together, only on Matt's word. *If wrong:* nothing; this is a fact, not a choice. A build that refuses a newer store is on the backlog.
3. **Section 4.1 writes "Today 8:14 am".** The time is the system's for the reader's region ("Today 8:14 AM" in the US), as every time in the app is. *If wrong:* one formatter.
4. **Section 4.1 has VoiceOver read the mark as a button.** Where VoiceOver reads a note's row as one element (the notes column, the Notes window, the phone's Notes tab), the mark is part of the row's label and an action of the row named "2 versions"; in the phone's note sheet it is a button. *If wrong:* one accessibility modifier per row.
5. **The mockup drew the Mac's popover on opaque paper.** It is the system's popover chrome, as every popover in `DESIGN.md` is; the mark is on `paper.overlay`, as 4.1 says. *If wrong:* a custom popover, which `DESIGN.md` bans.
6. **Section 5.2 keeps the file's text whenever it differs.** A file's text that the store's note was edited from is counted as already here. Otherwise last month's export would mark every note edited since. **It holds for one sitting only** (the whole-project review's M-2): an ancestry keeps one entry per change of device, so a note edited twice on one device since the export gets the file's old text as a kept version on import, which the reader discards once. This is what section 5.2 literally says, so it is not a defect; but question 3 for Matt overstates what was built. Do not lengthen the ancestry to cure it: more entries widen the hole the fix wave closed in sight. *If wrong:* the backlog's "discard the versions this import kept", or a longer ancestry with the risk named.
7. **Section 5.1 gives the phone's export the "Include conversations" switch.** It does not: the phone's Markdown export has none and always includes them, and so does its Export All Data. The Mac's panel has the checkbox. *If wrong:* a switch on the phone (backlog).
8. **Section 10's rehearsals use stores of the rehearsal identity,** not of the Debug app, because a `-storeName` store of the Debug app shares the `.dev` iCloud database with Matt's phone. *If wrong:* nothing; it is how the rehearsals were run.
9. **Section 5.2 adds a note that is not here "keeping its identity".** A highlight holds one note. A file's note that is not in the store, on a highlight that already carries another note, becomes a kept version of that note instead, so its text is not lost and the reader settles it (found by the pre-flight scan). *If wrong:* such a note is added standing alone instead (one more record on the highlight, which the model does not allow, so it would need a rule).

**The five questions put to Matt as the build began, unanswered; each is built as written** (the controller ruled that none waits for him):

1. A deletion marker's "version that was deleted" is stored as short digests, never text: of the deleted text and of the texts it was edited from. After the fix wave each is `<device tag><digest>`, the deleted text first. Without the second part, a note edited on the phone and then deleted there comes back on the Mac as a kept version of the Mac's older text. *If he says otherwise:* the marker's form changes before any Release build exists; Debug data only.
2. Records that share an identity are not deleted by the tidy-up (Departure 1). *If otherwise:* as Departure 1.
3. Importing a file whose text for a note is one the store's note was edited from counts as "already here" (Departure 6, with its one-sitting limit). *If otherwise:* as Departure 6.
4. "Kept versions" is offered in the filter only while there is one. *If otherwise:* the segment is always there and the menu and the toolbar are always one entry wider.
5. Deleting a note that shows "2 versions" leaves the other text under Kept versions until it is discarded or restored. *If otherwise:* the note's delete takes its kept versions with it, and an undo of the delete must bring them back.

### Decided here

The spec's **(call)** items stand. What the plan decided where the spec left the choice to the builder, as amended by the fix wave, each with what it costs if wrong:

- **The digest** is the first eight bytes of SHA-256 of the text's UTF-8, trimmed of whitespace and newlines at both ends, as sixteen hex characters; two texts are "the same" when equal after that trim. *Cost:* a collision (1 in 2^64) would keep nothing.
- **A mark** is `<token>.<digest>`; the token is the device's four-character tag and eight random hex characters, new each time editing begins. **What a sitting started from** is one value, `<token>:<entry>,…`: its own token, then an entry (`<device tag><digest>`) for the text the editor opened on and each before it, one per change of device, at most eight. *Cost:* a device offline through more than eight changes of device on one note keeps its old text needlessly.
- **Sight is by device and digest** (changed in the fix wave; the whole-project review's I-1 found that sight by digest alone lost a text put back, for instance by Use This One pressed twice while the other device edited). A version was made with sight of a text when it is the note's own text, or the entries name its digest under the tag of the device that wrote it (or under `0000`), and the three values hang together. A journal entry carries its writer's tag; an entry or marker from before the tag falls back to the digest alone. Values that do not hang together give no sight, so this device's text is kept. *Cost:* a needless kept version now and then; **one case is left for the backlog,** a device typing back its own earlier text exactly while another edits (closing it needs the sitting's token in each entry). The first wording of this cost ("never a lost text") was wrong.
- **The kind of device** is its family, "Mac", "iPhone" or "iPad", never its name; the tag (random, made once per store on a device, kept with the journal, never shown) tells one Mac from another in the entries. *Cost:* a reader with two Macs sees "Mac" on both versions.
- **The on-device record** is one JSON file per note in `LastTexts` (`LastTexts-<name>` for a named store) beside the store, written before the save. An entry is dropped when a change arrives made with sight of it, when it becomes a kept version, and when this device deletes or empties the note; never by age. *Cost:* one small file per note edited here stays; the journal outlives its store (an account change or a store reset by hand turns every entry into a kept version with no note: for Matt).
- **A journal write that fails does not stop the save;** it is logged; a damaged entry is removed. *Cost:* that one text is not protected.
- **A blank text is never kept or journaled. Deleting a note that never held text leaves no marker; deleting one emptied from text leaves a marker naming what it was emptied from** (changed in the fix wave, I-4: "deleting an empty note leaves no marker" brought a note emptied in the editor back as a kept version on the device that wrote its text).
- **A marker's version** is `<tag><digest>` entries, comma separated: the deleted text under its mark's tag, then the ancestry's entries. The tidy-up removes a kept version with no note only when the marker's **first** entry, the text deleted, names it, never for a text it came from (I-3). *Cost:* a removal that arrives before its marker, where the deleted text was a later edit, leaves one needless kept version with no note (the re-review's m-1; never a lost text). Markers are not exported, imported or restored from a backup; they go after ninety days; an undone delete removes the note's markers that name the restored text.
- **Deleting a note leaves its kept versions,** listed under Kept versions with no note. *Cost:* one more step to discard one (question 5).
- **Use This One** labels the note with the device that wrote those words, at the time of the choice. Only Discard is undoable (the spec's). *Cost:* none.
- **Restore as a Note** gives the note its old identity, on a live highlight with the same verses and offsets and no note, else on a new colourless highlight there. The conversation a note was saved from is not remembered across it.
- **Of a note's copies that differ,** the later `modifiedAt` stays (ties: the greater text); the other is not kept when the survivor was made with sight of it, and is kept before a save writes over it or a delete removes it.
- **The symbol** is `square.on.square`. **"Kept versions"** shows in the filter only while a kept version exists, and returns to All when the last is settled; texts with no note list only under it, never under All, in ⌘K or in the Markdown export.
- **In the versions view** a hairline in `ink.rule` separates the versions, as the mockup drew; references in a version's text are plain; Use This One is prominent only when there is one kept version.
- **The popover is 380 pt wide** (content 356 pt) with its three choices in one row at the regular control size (24 pt); the mockup Matt chose drew a row, and a stack was the fallback. The brief said 330 pt. *If wrong:* the popover is 50 pt narrower and the choices stack.
- **The Notes window's filter is a segmented control from 1,000 pt (five segments) or 1,200 pt (six) and a menu of the same choices below that, and the window opens 1,100 pt wide** (the fix wave, from offscreen renders; the live look found the filter in the toolbar's overflow at about 980 pt). So at the 1,100 pt default a store with a kept version shows the filter as a menu until the window is widened. *If wrong:* one width and one threshold; Matt's window manager sets the width anyway. The thresholds are by render, not by eye on the live toolbar.
- **The file:** `DataFile` and its records, keys in the README's table. A plan's weeks are the stored plan JSON, embedded, so the plan carries its own `"v"`; one from a newer coding is imported as a record this build lists as unreadable and never writes over. Dates are ISO 8601 with milliseconds, so a conversation's turns keep their order. A file over 256 MB is refused as damaged, unread.
- **The import is kept from running while a sync is importing** by Restore's rule, and it runs in one pass on the main actor with one save. *Cost:* a record just made elsewhere and present in the file is added twice, then read as one; a very large store stalls the window for a moment (backlog: measure first).
- **The import's sentence** lists notes first, as the spec's example; with nothing added it begins "Nothing was added." The Mac says it in an alert on the front window; the phone under the rows, as Restore does.
- **An imported note is journaled as this device's text** and loses its markers naming it, as an undone delete and a backup restore do (Task 10's ruling; the plan's rule 6 for Task 10 was changed to say so). *Cost:* with an older build still in use, or with both devices on this build and another device then editing it in two sittings before this one syncs, a note this device imported leaves a kept version to discard once. For Matt.
- **⌘K gains Export All Data… and Import Data…** (35 commands); neither has a key.
- **A probe** (`-versionProbe`, Debug, both apps, refused in the main store) stands in for an editing sitting and each choice. It does not refuse a `-storeName` store, which shares the `.dev` database (the backlog has a refusal for the `.dev` and real containers whatever the store's name).

### Rulings made on Matt's behalf

Named as the ledger names them, each with what it costs if wrong. The whole-project review weighed each and overturned none.

- **Question 1 is built as written and does not wait for Matt;** questions 2 to 5 and the departures are put to him at the end. *If wrong:* as each is.
- **The pre-flight table (45 rows, 14 findings) was made by a subagent (Opus) and ruled on by the controller** to keep the controller's context for the build. *If wrong:* a conflict surfaces in a task review instead.
- **Pre-flight rulings** (all settled in the plan before Task 1): `openSittings` is `internal(set)` (none); a note's differing copy is deleted when its text is kept, blank or seen (the spec's third anti-goal forbids a kept version when nothing clashed; *if wrong:* a blank or seen copy lingers as a twin); time strings in tests use U+202F (none); a failed save in `endSitting` is logged, not thrown (a kept version not made that once; the next import makes it); "never the accent" binds the mark only, and the prominent choice is the system's prominent button as the mockup drew it (*if wrong:* one button style); the Notes window's dialog for a kept version says "Discard" with no destructive role (none); Departure 9; the export writes ticks one per uuid; `blocks(forOrphan:)` added; `PhoneNotesKinds` outside `#if os(iOS)` so its suite runs in both; `countsAndOrphans` and `aTwinIsWrittenOnce` given outcomes; `endEditing` ends the sitting then reloads; the rehearsal folder's clean-up waits for Matt's word; `DESIGN.md` gains the File menu's two items.
- **Task 3:** `restore(_:)` deletes the restored note's markers that name the restored text; the plan's "an undone delete leaves its marker to age out" was changed because the reviewer's sequence lost a text. *If wrong:* a delete made with sight on another device just before an undo here could leave a kept version to discard once.
- **Task 4:** a restore from a backup journals each note it brings back and removes its markers naming its text, as an undone delete does. *If wrong:* a restored note deleted elsewhere with sight leaves a kept version to discard once.
- **Task 5:** both the colour and prompt merges leave a duplicate that shares the survivor's uuid, as the tick merge does. *If wrong:* a twin default colour or built-in prompt stays as two records read as one.
- **Task 6 (carried from Task 4):** when a choice or an append changes a note whose editor is open here, the model ends the editor's sitting, reloads its draft from the note and begins a new one. *If wrong:* the reader's cursor jumps once in an open editor. **And (from Task 6's review) the edit ends where the notes column goes away,** never in a lazy row's `onDisappear`. *If wrong:* an edit ends when the column hides, which it should anyway.
- **Task 7:** the choices are the regular control size, the plan's line changed because the hit-area rule outranks the task's styling (*if wrong:* the popover is a few points taller than the mockup); a kept version's dialog is titled "Discard the kept version of …?" (one string); the popover's shown flag is reset when the row stops showing a mark; the popover is 380 pt wide (above).
- **Task 8:** hit areas are floored at 44 pt (`max(44, scaled)`) with a measuring test; the kept-version sheet is not presented without its model. The choices' system-blue in the render is the render's (`TestWindow` has no accent asset); in the app they take the sheet's accent, so their labels are verdigris on the phone and plain ink on the Mac: for Matt's eye on the device.
- **Task 10:** a note the import adds is journaled as this device's (above).
- **Task 11:** the end-the-open-edit step is one `MarkupModel` method the app and the test both call; a failed pending save says "Your data could not be saved, so nothing was imported."; the phone's export failure is logged. *If wrong:* none.
- **The whole-project review's:** the fix list was taken whole, in order (every Important finding is a real path to a lost text, a needless kept version or a hidden control); sight is by device and digest, a marker's version and a journal entry carrying the tag (*if wrong:* the marker's form changes again before any Release build exists); the Notes window's filter follows the window's width, the default 1,100 pt (above); and the documents were written after the fix wave, so they describe the final code and are not written twice (*if wrong:* the documents got no Fable review; the controller reads them).

### What was built

- **Task 1: marks, sight and the journal** (4.3, 6; `2d2367a`). `NoteVersion` (the digest, a mark, what a sitting started from, sight) and `LastTextJournal` (one file per note beside the store, the device tag, `refusesProbes`).
- **Task 2: the stored values** (4.2 the marker, 4.3, 6; `087a81b`). `Note` gains `versionMark`, `versionAncestry`, `deviceKind`; `KeptVersion` and `DeletionMarker` join `MarkupContainer.models`; every save of a note's text is marked and journaled before the save.
- **Task 3: keeping a lost text after an import** (4.2, 4.3; `3807d11`, fix `3990db9`). `MarkupStore.settleVersions()` after every import (and a restore): a text this device lost becomes a kept version; a deleted note's unseen text becomes a kept version with no note; the tidy-up (same-text versions become one, one equal to the note goes, markers over ninety days go).
- **Task 4: the three choices, Restore as a Note and Restore from a backup** (4.1, 4.2, 6; `10aa3ec`, fix `62dcfe1`). Use This One, Keep Both, Discard with its undo; a missing kept version comes back once from a backup.
- **Task 5: records that share an identity** (5.2, Departure 1; `519d554`, fix `579097c`).
- **Task 6: the editors' sittings, the counts and the versions model** (4.1, 4.3; `9db0cf8`). One sitting per edit in both editors; the note's version count; the Kept versions filter; `NoteVersionsModel`.
- **Task 7: the mark and the versions view on the Mac** (`bb97a2c`, fixes `ae39d91`, `ba0a447`).
- **Task 8: the mark and the versions on the iPhone** (`09f97e8`, fix `a0273bd`).
- **Task 9: the data file** (5.1, 5.3; `3546ff1`). `DataFile`, `DataExport`, format version 1.
- **Task 10: import** (5.2; `a5a78c6`). What is missing is added, a differing note keeps the file's text as a kept version, nothing is changed or deleted; a second import adds nothing; export, import, export holds the same records.
- **Task 11: export and import in the apps** (5.1, 5.2, 7; `37b243e`, fix `4fa499f`). File › Export All Data… and Import Data…, ⌘K's two commands, the phone's Your Data section.
- **Task 12: the version probe and the rehearsal** (`5268e78`; the rehearsal `95589f7`).
- **Task 13: the documents,** `DESIGN.md`, `DESIGN.json`, the README, this section, the backlog, the handover and the main spec's box.
- **The fix wave** (`3692927` to `5e7c0a5`): sight by device and digest, the marker's form, the tidy-up's third rule narrowed to the deleted text and an emptied note's delete leaving its marker (I-1, I-3, I-4, together in one commit); a choice or an append keeps a draft the store no longer holds before it writes (I-2); a note's differing copy is kept before a save writes over it or a delete removes it (M-1); the Notes window's filter and the window's width (I-5); and a cheap tail (a sitting of another note is ignored, five log lines are public, the orphan mark's own help, the unused `==` and `now:`, the `on:` spacing, and a test for an edit ended on a note an import deleted).

### The rehearsals

**The clash rehearsal (before the plan)** was run by the controller in the rehearsal identity on two stand-in stores (the plan's "Rehearsal results" has the table). **What Apple's sync does:** the store that syncs last wins a clash of text, not the one that edited last; the losing text is destroyed everywhere; a clash is settled one value at a time, so a note's values do not travel together; a delete always wins, in either order; imports arrive on launch. So 4.3's rule stands, but the loser's own record of its last text is the only place the lost text can be saved from; the digest must be in the mark; and 4.2's kept version with no note is the only thing that saves an edit against a delete.

**The built code rehearsed (Task 12, `5268e78`)** on `ClashA` and `ClashB`, each holding one note written by `5bda6bd`, the code from before the project: every step passed as written and no text was lost. Step 4: both older stores opened by this build, the note kept with no mark, the three new values and both new tables present (the real proof the old-store test could not give). Steps 6 to 12: an edit against an edit, an edit with sight, Use This One then Keep Both, Discard, a delete against an edit in each order and Restore as a Note, a delete with sight, each ending as the spec says. The loser was in every case the store that synced first, and it made the kept version itself.

**The rehearsal again on the fixed build (`5e7c0a5`):** Steps 6, 7 (use), 10, 11 and 12 passed, and the review's I-1 sequence on real stores keeps the text put back (both stores: the edit as the note, both earlier texts kept). Everything it made was removed and its scratch build deleted.

**Not rehearsed with real stores:** three devices; an older build as one side of a clash (tests only); a delete undone and then deleted elsewhere unseen (tests only); a change pushed while the app is running; whether a marker and its note's removal ever arrive in different imports (the re-review's m-1 and I-4's rule lean on it being rare; the two-stores-open rehearsal would show it).

### Known limits

- **Every kept version is a text this device wrote and another device's edit or delete replaced;** an older build on another device leaves a text under an unchanged mark and a delete with no marker, and both are kept from, at the cost of one discard.
- **One case of a lost text is left:** one device typing back its own earlier text exactly while another edits (above).
- **A needless kept version now and then:** more than eight changes of device offline on one note; a removal before its marker where the deleted text was a later edit; a note this device imported and another device then edits in two sittings; two Macs both read as "Mac".
- **The journal outlives its store:** a store reset by hand or emptied by an account change turns every entry into a kept version with no note.
- **Twin prompts, colours and highlights:** a twin moved down can read as reverted; of two twin highlights each carrying a note the later `modifiedAt` wins and may carry the unread copy; an anchor left empty by a deleted copy outlives the note and counts in the chapter rings.
- **A failed save** after a kept draft was inserted, or before a delete's journal forgetting, can leave the journal and the store out of step once; the next import settles it.
- **Export and import run on the main actor** in one pass; every import reads every journal file and fetches every note (backlog, measure first).
- **The probes refuse the main store file, not the `.dev` database,** so a `-storeName` store of the Debug app can reach the phone's Debug app; "no test note in `.dev`" rests on habit and the rehearsal identity.
- **The Notes window filter's thresholds** come from renders of a window never ordered in, not from the live toolbar.

### Seen, by whom, and what nobody has seen

**Seen live by an agent: the controller's one pass** (rehearsal identity, keys only): the app opens on the front page and Return, Return opens Genesis 1; the notes column shows the note with its "2 versions" mark; ⌘K with `data` typed lists Export All Data… and Import Data… as its two commands and Esc closes it; ⇧⌘N opens the Notes window, where the note carries its mark and All counts four items (a text with no note is not among them, as decided). It found the filter in the toolbar's overflow at about 980 pt, which the fix wave answered. **Seen by renders:** each task's implementer and the controller looked at temporary offscreen renders (Tasks 7, 8, 11 and the fix wave's filter at 760, 980, 1,100 and 1,200 pt, five and six segments, light and dark), listed in each report. **Seen by Matt: nothing yet.**

**What nobody has seen, by surface** (a render cannot show focus, a click, a key, a popover's anchor or chrome, a toolbar, a panel, an alert, a share sheet or an undo):

- *The Mac's notes column and Notes window.* The popover's chrome, anchor and arrow in any appearance (dark's `ink.rule` between blocks is faint on overlay paper in the render); whether the prominent button takes the verdigris in the real popover; a click on the mark neither selecting nor editing its row, and a double-click in the Notes window not opening the reader; Tab reaching the mark and the buttons; ⌘Z after the popover closes, through both undo managers (the column's and the window's); the popover closing after each of the four choices; Show Versions in the context menu; VoiceOver's default action on a row that now holds a button; the accessibility text sizes (a render could not set them); `NotesColumnView.onDisappear` firing when the inspector hides or the assistant takes it (a sitting left open makes the settle skip that note until the next edit or relaunch; no text is lost); the toolbar at 980, 1,100 and 1,200 pt in both forms, which item AppKit moves first, and VoiceOver on the menu form.
- *File menu and panels.* The File menu's two items and whether Import Data… is dimmed at launch with sync on and enables after the first import; the save and open panels with the accessory; the alerts, one of them begun from the open panel's completion; an export and an import end to end; VoiceOver's announcement of the result.
- *The iPhone.* The push and pop inside the real note sheet and its Done; `PhoneVersionSheet` as a presented sheet; the swipe's Discard and a shake undoing it; the What kind menu open; VoiceOver; Dynamic Type of the mark button and the rows' hit areas at the largest sizes; the bordered choices' colour on a device; the share sheet and the file picker, and whether `.fileImporter` on a section inside the grouped form presents; Your Data in the real Settings stack with Backups above it. The simulator's rehearsal app was never built or opened.
- *Across devices and time.* The two-device clash through the real apps (iPhone in Airplane Mode and the Mac), on his list; three devices; a change pushed while the app is running; the new marker form and sight rule on his real notes.

### For Matt

His list is section 10's (unticked, each to be seen by him), with what this session could not check beside each item:

- [ ] With the iPhone in Airplane Mode, edit one note there and on the Mac; turn Airplane Mode off; the note shows "2 versions" on both, and each choice does what it says. *(Not seen: the popover, each choice, ⌘Z after Discard, the phone's push and pop.)*
- [ ] Export All Data on the Mac; open the file; import it straight back and see "already here". *(Not seen: the File menu, the panels, the alert.)*
- [ ] Delete a note, import the file, and the note is back. *(Not seen: as above.)*

**His choices:** the nine departures; the five questions (none answered); the popover's width (380 pt against the brief's 330); the filter's thresholds (1,000 and 1,200 pt) against a 1,100 pt default, which shows a menu while a kept version exists; an imported note being journaled as this device's; the journal outliving an emptied store; and whether the Release apps are to be updated (together, never a rollback).
