# Final review: milestone 10, project 3, "on a verse"

Range `cc13b7f..d4d23f9` (15 commits, code), read on 2026-11-18 beside the documents task (not reviewed).
By reading only. No suite, build, app or simulator was run, and no test. Four read-only `sqlite3 -readonly` queries were made against `Build/bible.sqlite` (the link counts, the ERV's combined rows, row-id collisions, the longest targets); nothing was written. One read-only `git show` of the popover file as it stood at `574086a`, to weigh what live pass 2 saw.

Read in full: the spec (sections 1 to 10), the ledger, `PRODUCT.md`, `CLAUDE.md`, the plan's Global Constraints, Review Focus and pinning table, and the 325 KB diff in nine passes (its tail, the plan's own correction from line 4749, at its head only).
Read in part, where a hunk's context was not enough: `SUI/ChapterTextController+Keys.swift` (168-235), `SUI/AssistantModel.swift` (386-730, 880-1000), `SUI/NavigationModel.swift` (345-400), `PH/PhoneReaderScreen.swift` (296-410), `SUI/VersePreviewView.swift` and `SUI/ReaderFocusRule.swift` (whole), `SUI/PreferenceSync.swift` (96-200), `SUI/SelectionResolver.swift` (28-70), `SUI/ChapterLayout.swift` (150-195), `SUI/BookDecorations.swift` (25-50), `SUI/ColumnRowParts.swift` (69-91), `SUI/SepiaMode.swift` (100-119), `Scripts/fetch-ebible.sh` and `Scripts/ensure-bible.sh` (whole), and DESIGN.md's lines on Quote, Label and Popovers (268-269, 290).

## 1. Verdict

**With fixes.** The two models, the link table, the importer and the assistant's new input are sound and well pinned, and nothing here writes to the notes store, adds a synced record, or uses the network outside the fetch script. One thing should be fixed before Matt tries it: on the Mac, the hand-back after a row, Open, Ask or a chapter change is weaker by construction than the hand-back after Esc, and it is the route nobody has driven (I1). After that the live looks still owed by spec 10 must be made; section 7 lists them in order.

Counts: 0 Critical, 1 Important, 14 Minor.

## 2. Strengths

What to leave alone.

- **The rules live in two plain models.** `VerseComparison` and `CrossReferences` hold the order, the cut, the short list and the labels; the panels only draw them. The model tests assert exact orders and counts against a fixture that was counted by hand, so a wrong sort or an off-by-one fails by name.
- **The verse key.** One integer per verse (`VerseKey.swift:5-15`) makes "a range holds this verse" two comparisons. "Points here" is two bounded statements joined in Swift, with a partial index over the 649 links that leave their chapter (`BibleStore.swift`, `crossReferences(to:)`; `BibleSchema.swift`, `cross_reference_spanning`). I walked both statements against a range that starts in the chapter, one begun in an earlier chapter, and one begun in an earlier book (the 18): each is found once, the verse's own link is dropped, and one row is kept per source. 9.6 ms for John 3:16 against a 20 ms limit.
- **The digest is on the text, not the zip.** That is why a mirror can serve the pinned file when OpenBible's own address has moved on. `.complete` is written last, so a half-finished run is fetched again.
- **The popover's request id.** `onClose` clears only its own request (`MainWindowView.swift:253`), `dismiss()` strips both callbacks before closing (`ChapterTextController+VersePanel.swift:76-81`), and a request already shown or already closed is not shown again (`:114`). I traced a C pressed between Esc and its late `onClose`, and a replaced panel's late `popoverDidClose`: both come out right. The `presentVersePanel` seam lets the state machine be tested without the screen.
- **R7 and its test.** The comparison's selection is the verses shown, whole, in offsets the reader itself would report, and `askAboutTheDifferencesFromPartOfAVerseSavesTheReplyOnTheWholeVersesShown` follows it through Ask into the saved note's highlight. The stored verse text is laid out verbatim (`ChapterLayout.swift:180-188`), so the offsets agree for poetry too.
- **`Input.composed` is small.** It reuses `submit`, `route` and the fallback. Its content is the same in the whole and the compact form, so Try Again, a rebuilt request from the stored turn, and the on-device fallback all send the same question; too long for on-device, it says so. The reader's turn and a saved note's "Q:" both read the title. Nothing is stored as a prompt.
- **The compare set as one string.** An id this build lacks is ignored for rows and kept through a toggle; the default is the same constant in Settings, the panel and the assistant; `theSyncedKeysAreExactlyThese` holds the list of synced keys to exactly one more.
- **The phone's queued Ask.** It is set just before the sheet is told to go, run from the sheet's `onDismiss`, and cleared by `showInReader()`. A Done, a swipe down, a row and Open in Read all find nothing queued.
- **The UI rules are kept.** Palette tokens only, semantic text styles, `AppSpacing` and `AppRadius` by name, scaled metrics for 360 and 480, no card, no shadow, no material. The one fill is the wash on the row being read, which the spec asks for.
- **The owner's data.** No file under `ScriptureModel` changed. `SyncedPreferences.keys` gained `compareTranslationIDs` and nothing else. Recents, which Open writes, are local `UserDefaults` and never synced (`Recents.swift:112`). No `URLSession` was added; the only new addresses are two links the reader clicks. The tests use temporary databases and uniquely named defaults.

## 3. Issues

### Critical

None.

### Important

**I1. On the Mac, after a row, Open, Ask or a chapter change takes the popover away, nothing reliably makes the reader's window key again.**
`SUI/ChapterTextController+VersePanel.swift:103-112` and `:139-149`.

- When the reader closes the popover (Esc, a click outside), `popoverDidClose` hands back with the popover's own window, and one turn later the guard at `:145` passes because no window is key, so the reader's window is made key. Live passes 3 to 5 saw this work.
- When the app takes it away, `apply(nil)` calls `versePanelWentDown(from: nil)` (`:110`). The guard then needs `NSApp.keyWindow == nil` one turn after `popover.close()`. If the popover's window is still key while it fades, the guard fails and `makeKey` never runs.
- After Ask the guard fails in any case: `:144` also requires the text view to be first responder, and by then the assistant's composer has it. The composer is in the same window, so making that window key takes nothing from it.
- Why I do not trust AppKit to do it alone: at `574086a` nothing touched the reader window's first responder, the popover's window held key, and live pass 2 still saw "selection grey, J and R dead" after it closed. That is the reader's window not regaining key on its own in this app.

How to reach it: select a verse, press C, click the KJV row (or Tab twice and press Space), then press J at once. Press R, click a row, press Return on Open, then press J. Press C, click Ask About the Differences, then type at once. Press R, then choose the Go menu's next chapter, then press J. If the selection is grey or the letters go nowhere, this is it.

Reading cannot settle whether it fails; it can only say the two routes are not the same and the weaker one is unseen. It is also every pointer action the panels have.

Fix: keep the popover's window readable on `VersePanelPopover`, pass it from `apply(nil)`, and drop the first-responder condition from the `makeKey` guard (keep the others: no popover up, the app active, the window on screen, no other window key but the closing popover's).
Test: give the controller a seam for "make the reader's window key" as `presentVersePanel` is one, and in `theReaderHasTheKeyboardWhileAndAfterAVersePanel` expect one call after `apply(nil)` with the text view first responder and one with a field first responder; expect none while another panel is up.

### Minor

**M1. A click outside that lands on a row of the notes column loses that row the keyboard.** `ChapterTextController+VersePanel.swift:139-141`, `ReaderFocusRule.swift:19-25`. The click closes the popover and selects the note; a moment later the late close asks for focus and the rule takes it from anything that is not a field. Reach: C, click a note in the column, press the down arrow. Fix with I1: on the reader's own close, skip `requestFocus` when the reader window's first responder is no longer what it was when the panel went up. Test: a `goesDown` case whose holder changed while the panel was up keeps it.

**M2. The row being read is a button.** `VerseComparison.swift:15`, `CompareTranslationsPanel.swift:40`, `MainWindowView.swift:265`, `PhoneReaderScreen.swift:268-270`. Clicking it starts a lookup of the verse you are on, in the translation you are in: the panel closes, the page jumps to the verse, and a Back appears that returns to the same chapter. Reach: C, click the first row. The spec's sentence does not exclude it; I would make that row close the panel and nothing more. Test: `rows[0].canOpen` false for the reading row, or a model flag the view reads.

**M3. The prompt run from the assistant's list sends the set in its stored order, and with an empty set sends a comparison with nothing in it.** `AssistantModel.swift:336`. The panel orders by the translation list; this path sends `CompareSet.ids` as stored (the order boxes were ticked in), so with five or more in the set the on-device three differ between the two ways in, and a cloud provider sees a different order from the panel. With every box off, "Compare translations" goes out with an empty `{{other_translations}}` and says nothing to the reader. Reach: Settings, General, Compare with: all off; select a verse; Ask About This Passage; Compare translations. Fix: order the ids through the same function the panel uses; with none, say so or fall back to the default four. Test: extend `thePromptFromTheAssistantsListSendsTheCompareSet` with a set stored out of list order.

**M4. Read in the ERV, a combined verse answers only for its first number.** `CrossReferences.swift:97-107`, `VerseComparison.swift:85-87, 110`. Cross-References on "12-13" loads the links of 12; the chevrons step over 13; 2,455 links whose source is a second or later verse of a combined row cannot be reached in that translation. Compare from the ERV shows the ERV's two verses beside the others' one. The header names the single verse over the row's text (a deferred minor). The selection it hands Ask (verse 12 to 13) resolves to the one span, so a saved note is sound. Reach: ERV, Genesis 4:3, R; then C. Fix: load and compare over the row's whole extent. Test: `tinyStore` with an ERV "12-13" and links from both verses.

**M5. When the translation being read lacks a verse at the end of the five, Ask sends the others cut to its verses, not the rows shown.** `VerseComparison.swift:99-100` into `AssistantModel.swift:749`. The selection ends at the nearest verse the reading translation has (right, for the note), and the other translations are then read over that shorter range. Rare: the ESV's omitted verses at the edge of a cut. Fix: carry the shown range beside the selection. Test: beside `itsSelectionEndsAtVersesTheReadingTranslationHas`.

**M6. Try Again on another provider rebuilds from the stored turn, so "three on-device" is not held there.** `AssistantModel.swift:418, 432`. The first send composes the fallback with three; a retry after Settings changed, and the fallback a retry arms, reuse the stored content with every row. This shape is older than the project. Backlog.

**M7. A failed read looks like an empty one.** `NavigationModel.swift` (`crossReferences(for:)`, `try?`) into `CrossReferencesPanel.swift:110`: a read that throws shows "No cross-references for this verse." And Ask does nothing, silently, when the question cannot be read (`MainWindowView.swift:281`, `PhoneReaderScreen.swift:284`). Not reachable with a sound database. Backlog: log the error and show the reader's one-line error as the other reads do.

**M8. The Mac panel measures three heights into state, so its first frame has an empty middle.** `VersePanel.swift:152, 170-173`. The reviewer's watch list has it as "appearing then growing". `VersePreviewView.swift:33-42` already holds a scroll to a scaled limit with `frame(maxHeight:)` and `fixedSize(vertical:)` and no measuring. Try that if the live look shows a flash.

**M9. A reader key typed while the popover holds the keyboard goes to the popover, not to `swallowsKeyForVersePanel`.** `ChapterTextController+VersePanel.swift:126-130` covers only the reader's own window. So J may beep, and R does not turn Compare into Cross-References; the test named "C then R without closing" pins a replacement the keyboard cannot make. Reach: C, then R. For Matt: whether C and R should switch or close an open panel.

**M10. The popover does not follow its text.** `ChapterTextController+VersePanel.swift:114` returns early for a request already shown, and nothing updates the positioning rect. A text size change from the menu, the notes column opening, or a scroll under the popover leaves it hanging where the line was. Reach: C, then the View menu's larger text. Fix if it looks wrong: close it on a new layout, as on a new chapter.

**M11. The fetch script unzips before it checks, and leans on a branch.** `Scripts/fetch-crossrefs.sh:10, 29, 33, 37, 15`. See "The fetch script and the importer" below. Fix: read the one member with `unzip -p` to a file and hash that; name the mirror by commit, not `master`; give `curl` a time limit; re-hash on a cache hit.

**M12. The importer never says how many links it wrote, and an import that yields none succeeds.** `bible-importer/main.swift:60`, `BibleDatabaseWriter.swift:125-135`. After a re-pin to a file in a new shape, every line would warn, the table would be empty, and the build would pass; the app would show "No cross-references" everywhere. Fix: print the count, and fail when a file was given and nothing was kept. Test: `importAll` with a file of unparseable lines throws.

**M13. A queued Ask is not cleared when a new panel is asked for.** `PhoneReaderScreen.swift:276-290, 324, 385-389`. I found no route that leaves one behind today. If a dismissal were ever missed, the next Done would send it. One line in `onVersePanel` rules it out.

**M14. Ask is dimmed with no word why.** `VerseComparison.swift:63` (an empty set), `CrossReferences.swift:87` (both short lists empty). Up to 5,772 of the 29,318 verses with links have every link under four votes: the reader can Show all and read them, and Ask About These stays dim. By spec 5.3 ("the two short lists"). For Matt: send the first six of what is listed when the short lists are empty.

## 4. The rulings

| | Ruling | Mine |
|---|---|---|
| R1 | `links:` added to `tinyStore` in Task 5 | Same. No cost. |
| R2 | No implementer drives the Mac app; the controller makes one live pass a task | Same, given the handover. Its cost was four blind rounds, and it still stands in I1: the list "not seen by anyone" holds every pointer action. I would have had the controller's pass after round 4 include one row click before calling the task done. |
| R3 | Documents to one implementer, the rest to the controller | Same. |
| R4 | Tests rewritten to the small fixture; two direct tests added | Same on not growing the shared fixture. I would also have added a `tinyStore` to the `T` target. The cost of not: the cut to a first chapter is pinned through `Row(pointingTo:)` and the store's `chapterEnd` separately and never through `load`, and "three on-device" is pinned by a static helper alone. Small; see section 6. |
| R5 | A held C or R acts once | Same. |
| R6 | A chapter that ends before the target's first verse shows that one verse | Same. A backwards reference is worse than a short one. |
| R7 | The comparison's selection is the verses shown, whole | Same. It is what spec 4.1 says, and the test follows it into the note. Cost as recorded, plus one more: a smaller highlight the reader already had inside the verse is not reused; a new colourless one is laid over it. |
| R8 | The compared verse is roman | Same. The spec asks for `ink.primary`, which is already not DESIGN's Quote (`ink.secondary`, italic), so "Quote serif" there means the page's face. The reference row's one line in the Quote style is spec 5.2 to the word. |
| R9 | Open on a passage records a recent; a compare row does not | Same. |
| R10 | Round 4 went back to the same implementer | Same. The rounds failed for want of sight, not skill, and round 4 landed. |
| R11 | The sheet's title is the panel's name | Same for Cross-References, where the chevrons would stale a reference. For Compare I would have ruled the same for one rule over two; the reference is one line below. Matt's to overturn at no cost. |
| R12 | The short credit in the foot, the full notice in About | Same. Spec 5.2 gives the foot's words. CC BY 4.0 allows attribution "in any reasonable manner" for the medium; an About page with the source, the licence link and the changes, and the source named and linked on the panel, is that. |

## 5. The deferred minors, sorted

**Fix before Matt tries it**

- Task 7: `apply(nil)` passes no popover window to the hand-back. It is I1: the route is unseen and the evidence from pass 2 points at it.
- Task 7: the notes column's rows are not fields, so the reader takes focus from them. It is M1, the same function as I1; fix them together.

**Backlog**

- Task 1: no test of `Row.note` on a CPDV row in Psalms, nor of a missing row's `accessibilityLabel`.
- Task 4: `find … | head -n 1` under `pipefail`. Goes away with M11's `unzip -p`.
- Task 4: no test of the `crossrefs_sha256` meta value, nor of `VerseKey.key` directly.
- Task 4: a plain INSERT fails a re-pin without naming the link. Keep with the re-pin line already in the backlog.
- Task 4: `.complete` trusted without re-checking the digest; `rm -rf` of the cache folder could race a second build. With M11.
- Task 5: `Row.id` is unique in today's data but not by construction. I checked the built table: no two links from one source share a start and votes where one runs past its chapter. Keep with the re-pin.
- Task 5: the opening-text reads prepare a statement per link. The busiest verse has about 100 links out and 143 in; the budget holds.
- Task 5: a joined verse is tested only as a link out's first verse. With M4.
- Task 7: `verseComparison` runs on every body evaluation (and `crossReferences(for:)` does too, about 9 ms on the Mac; look once on the phone).
- Task 7: the Cross-References header is inset on the leading edge only. For the eye.
- Task 8: `translationID == nil` standing for "a cross-reference's passage". Make it a named case.
- Task 8: `shell.versePanel = nil` on every `chapterKey` change. It also closes a sheet when the other device reads on; that is acceptable, so no change unless it is seen to misfire.
- Task 8: no test of the phone screen's wiring; the pushed passage has no title.
- Task 9: the foot truncates the credit at accessibility sizes. The credit is the attribution, so let the foot wrap (`ViewThatFits`) when this is next touched.
- Task 9: a combined row's heading names one verse over two verses' text. With M4.
- Task 9: no test of Try Again or the fallback for `.composed`; a failed question read is silent. I walked both paths by reading (section 2); a test is still worth having. The silence is M7.
- Task 9: the doc comment at `AssistantModelTests.swift:416-419` sits above the wrong test. Move it with the next commit that touches the file.

**Drop**

- Task 1: the private `shown` behind the public `selection`.
- Task 1: Copy's selections carry offsets beside another quoted text. `copyWithReference` reads only the quoted text and the reference (`TextSelection.swift:38-40`), and R7 settled Ask.
- Task 2: re-wrap the doc comment in `PreferenceSync.swift`.
- Task 3: `compareTranslations` returns silently with neither a stored prompt nor a seed. It cannot happen for a built-in key.
- Task 3: the test calls `ask(about:)` twice on one model. `startPending` closes the first.
- Task 4: `.whitespaces` trimming includes tabs. A line that loses a column that way is skipped with a warning.
- Task 5: `load` force-unwraps the book of the verse it is handed. The verse comes from the reader's own page.
- Task 6: wrap `phoneOrder`'s comment; no `keysAreLive`-off case for C and R.
- Task 7: rows are `xs` apart plus their own padding. The padding is what the focus ring and the wash need.
- Task 7: `VersePanel.swift` imports SwiftUI; `VersePanelPresentation` is on both platforms.
- Task 9: the stray blank line in `CrossReferencesPanel.swift`.

## 6. What section 10 of the spec has pinned and what it has not

**Pinned by name, through the path the sentence is about**

- Compare, rows and order, a translation lacking the verse: `theReadingTranslationLeadsThenTheSetInTheListsOrder`.
- A range, and the cut to five with its line: `aRangeShowsEachVerseAndMoreThanFiveIsCutWithItsLine`.
- The prompt from the assistant's list sends the set: `thePromptFromTheAssistantsListSendsTheCompareSet` (to an on-device provider's request).
- Ask keeps the verses shown and a saved note highlights them: `askAboutTheDifferencesFromPartOfAVerseSavesTheReplyOnTheWholeVersesShown`.
- The importer: `singleVersesRangesAndThirdJohnLandAsExpected`, `linksUnderOneVoteAndLinesThatDoNotParseAreLeftOut`, `theFixtureLinksLandKeyedBothWaysAtSchemaFour`.
- "Points to" and "points here" in vote order, a range that holds the verse, never the verse itself: the two tests in `BibleStoreCrossReferenceTests`.
- The short list, a group under four votes, a verse with none, the ends of a chapter, Tobit: the first three tests in `CrossReferencesTests`.
- Ask About These composes the verse and the short lists and stores no prompt; too long on-device says so: the two in `AssistantModelTests`.
- Both menus: `compareAndCrossReferencesFollowTheBookmarkAndComeBeforeCopy`, the phone's names in `PhoneMarkupMenuTests`, the Mac's titles in `cAndROpenTheirPanelsWithASelectionAndDoNothingWithoutOne`.
- C and R with and without a selection, held once, in the catalogue: `ReaderKeyTests` and `ShortcutCatalogTests`.
- One synced key: `theSyncedKeysAreExactlyThese`.
- The benchmark: `bothListsForJohn316AreWithinTwentyMilliseconds` (the real database, the Mac suite only).

**Pinned only by a direct call, where the spec's sentence is about the whole path**

- "Changing the set changes the rows and is saved": the test writes the defaults itself with `CompareSet.toggling`. The toggle's binding through `@AppStorage` (`CompareSet.swift:47-56`) is unrun.
- "Three on-device": `AssistantModel.otherTranslationIDs` is called directly. No request with more than three in its list reaches an on-device provider, because the fixture holds two translations.
- "Ask sends exactly the rows shown": the first test hands the model `["KJV"]` by hand; only the second goes from a comparison.
- Copy: `copyText` is pinned; the pasteboard write is the view's.
- The CPDV's line: the static `note(translationID:book:)`, not a row.
- "A row lacking the verse is not clickable": `canOpen` is pinned; the view's branch on it is read, not run.
- "A cross-chapter target shown as its first chapter's part": `Row(pointingTo:)` on a hand-made link, and the store's `chapterEnd == 48` in another suite. Through `load` the fixture reaches only R6's single-verse branch.
- "The lookup from a row keeps the reader's place": `lookUp` and `lookUpPassage` are called on the model. The panels' own `onOpen` closures are not.
- "Show all lists the rest": the model's `all`, `short` and `showsShowAll`. The view's expanded set is unrun.
- "An older database is rebuilt": the pattern test and `schemaMismatchThrows`; the script was run once by the controller.

**Pinned by nothing**

- The compact request the fallback is armed with (`AssistantModel.swift:482-483`) for a comparison: that it carries three.
- `MainWindowView.versePanelContent` and the phone's sheet wiring: which selection and which ids each Ask passes, the recents split, the queued Ask. By reading they are right.
- Anything AppKit does: that the popover shows, where, which window is key afterwards (I1), a click outside.
- The chevrons' labels and disabled state, the empty line on screen, VoiceOver on a real device.
- "Seen by eye" in light, dark and Sepia with a long verse and a verse with no links: owed, see section 7.

## 7. What I declined to judge, and what a live look should try, in order

**The fetch script and the importer.** What is trusted: only a text whose SHA-256 is the pinned one reaches the importer, from either address, over HTTPS. So a changed or hostile text is rejected, and the importer's own tolerance (warnings for bad lines, numbers held to 1 to 999, the 66 names) matters only at a re-pin. What is not covered: the zip is unpacked before anything is checked, so a hostile archive meets `unzip` first (it refuses `..` paths and the script hashes only a plain file, so the exposure is `unzip` itself and a full disk); the second address is another person's `master`, so a fresh machine's build depends on a branch that can move; `curl` has no time limit; and a cache marked `.complete` is used without being hashed again, while the importer stamps the pinned digest into `meta` from the side file. A half-finished run leaves no `.complete` and is fetched again. Matt's own cache is complete today. This is M11 and M12; none of it can reach his notes.

**What I would expect to go wrong next with the popover**, by route:

1. Taken away by the app (a row, Open, Ask, a chapter change): the window not key afterwards. I1.
2. A click outside: the click also lands. On the page it collapses the selection; on a note it selects the note and then loses the keyboard (M1). On the toolbar it opens what was clicked.
3. Keys while it is up: they go to the popover's window. J may beep; R does not switch panels (M9). Esc with a passage shown closes the whole popover, not just the passage.
4. The text moving under it: it stays where it hung (M10).
5. Another app, or an AeroSpace workspace switch: a transient popover should close; the hand-back is guarded by `NSApp.isActive`, so nothing should be stolen. Not seen.
6. Home: the popover is dismissed without a hand-back, which is right; `versePanelRequest` is cleared on the screen change.
7. A late close from a replaced panel, and a request shown twice: handled, and tested.

**Declined:** contrast of the ink tokens and the plum on the system popover's own translucent background (no palette pairing can cover a system material; in Sepia the inks are meant for sepia paper); whether the translucent popover or an opaque one reads better (Matt's, per the ledger); VoiceOver; the feel of a row tap on the phone, which has no pressed state; what a real provider answers.

**The live look, in order.** Mac first, on the final build.

1. John 3:16, C, click the KJV row, press J at once. Then Back. (I1, and the lookup.)
2. C, Tab, Tab, Space, then J.
3. R, click a row, Return on Open, then J. Then Back, and look for the passage in Recents.
4. C, Ask About the Differences, type at once. Then R, Ask About These, type at once. Read the reader's turn and the conversation's title.
5. R, then Next Chapter chosen from the Go menu with the pointer, then J.
6. C, click a note in the notes column, press the down arrow. (M1.)
7. C, click the page. Does the selection survive, and where does the click land?
8. C, then R. C, then J. Listen for a beep. (M9.)
9. C, click the first row, the one being read. (M2.)
10. C, Translations…: untick all (one row, Ask dim), tick them back. Does the popover resize cleanly? Does the set reach the phone?
11. C, then Larger Text (⌘+); scroll the page under an open popover. (M10.)
12. C, then switch to another app and back; then an AeroSpace workspace and back.
13. Proverbs 3:9, R, Show all, open Numbers 7:2-89 (88 verses, the longest target). Acts 24:25, R, Show all (96 links out). Does it scroll inside 480 pt?
14. 1 Chronicles 1:21, R (no link names it as a source or as a single target; a range may still hold it). Genesis 1:1, R.
15. Shift-Tab from the first control; Tab past the last.
16. Copy, paste into TextEdit.
17. All of 1 and 13 again in Dark and in Sepia. Look at the plum Ask and the grey labels on the popover's background.
18. Watch the first frame of each popover for an empty middle. (M8.)

Then the iPhone.

19. Both sheets on a verse with no links and on a long verse (Esther 8:9), at medium and large.
20. Ask from each sheet: the sheet goes, the conversation comes up over the page, once.
21. The reading row in Compare. (M2.)
22. The foot of Cross-References at the largest text size.
23. If the ERV matters: Genesis 4:3 in the ERV, R and C. (M4.)
