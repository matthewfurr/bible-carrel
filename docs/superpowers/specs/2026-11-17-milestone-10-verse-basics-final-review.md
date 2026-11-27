# Final whole-branch review: verse basics (milestone 10, project 1)

Range: `89f8a95..98f02e4` on `milestone-10-study-tools`. Reviewed 2026-11-17.

**Ready to merge? With fixes.** Critical 0, Important 5, Minor 9.

How this was done: the diff (`final-review-code.diff`) was read in six passes (the reader on each platform; the catalogue, keys and sheet; links; the Notes window; credits and About; documents), with the HEAD files read around each seam. The spec, the plan's Global Constraints, Review Focus and Interfaces, and the ledger were read in full. Nothing was built, run or launched, so every finding is from reading the code. Findings 2 and 3 are timing races that reading cannot settle; each carries a by-hand check and a small hardening that makes the answer not matter.

Paths below are relative to the worktree root. `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `SD` is `Packages/ScriptureKit/Sources/ScriptureData`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `TD` is `Packages/ScriptureKit/Tests/ScriptureDataTests`, `MAC` is `Apps/Mac/ReadingThroughScripture`. Line numbers are at `98f02e4`.

---

## Strengths

- A selected verse is an ordinary text selection on both platforms, so every existing action (menu, colours, note, bookmark, assistant) works on it and nothing new is drawn. The architecture claim in the plan holds in the code.
- `ShortcutCatalog` really is the key handler's source: `ColumnTextView.keyDown` (`SUI/ChapterTextController.swift:1337`) resolves only through `ShortcutCatalog.readerAction(for:)`. All 18 menu chords in the Mac source are in the catalogue (checked by hand against a grep of every `.keyboardShortcut`).
- `0` cannot delete a note: `ReaderKeyCommands` → `MarkupContextMenu.pickNoColor` → `MarkupModel.clearColor` → `setColor(nil)` → `MarkupStore.setColor` → `deleteIfEmpty`, which deletes only a highlight with no colour and no note; that delete registers an undo.
- Single keys reach the reader only through `keyDown` on the first responder; there is no key equivalent or menu route for them.
- `PassageLink` is safe on hostile input. Traced by hand: non-ASCII digits, integer overflow, invalid percent escapes, empty pieces, a lone dot or dash and very long strings all return nil; no force-unwrap is reachable from a URL. `NavigationModel.openPassageLink` checks the book, the chapter range and the verse before navigating, and can only call `lookUp`.
- The two builds' schemes come from one build setting per configuration (`PASSAGE_URL_SCHEME`), read through the Info.plist; copying uses `PassageLink.appScheme`, which falls back to `bible` when the key is missing or not one of the two.
- All 15 credit notices in `SUI/Credits.swift` match the spec's appendix word for word, with the bracketed remarks left out and no "Used by permission". `Licenses/GRDB-LICENSE.txt` matches the local SwiftPM checkout (`diff -w` clean).
- The iPhone tap's rules are one pure function (`verseForTap`, `SUI/Phone/PhoneChapterTextController.swift`), read here against the highlight tap, the away tap, the pen, the chapter cards, the thumb's zone, margin marks and the text view's own taps, and consistent with spec section 4 in each case.
- The held-key state (`keyRange`, `keyScroll`, `keyScrollDeadline`) is cleared by `replaceText` and by any scroll that is not the keys' own, and the 0.3 s expiry bounds every stale case the task reviews listed.
- New UI uses palette tokens, semantic text styles and `AppSpacing`/`AppRadius`; no card, shadow or material was added; no `textView.layoutManager` access.
- The As built section is candid about what nobody has seen.

---

## Issues

### Critical (Must Fix)

None.

### Important (Should Fix)

#### I1. The model's selection goes stale across a chapter turn, so the assistant asks about a verse that is no longer on screen

- **Where:** `SUI/ChapterTextController.swift:1040-1047` (`selectionDidChange`), `:367-407` (`replaceText`), `:284-344` (`update`); `SUI/MarkupModel.swift:145-153` (`load`), `:408-410` (`setSelection`). Consumers: `MAC/MainWindowView.swift:388`, `MAC/ReadingThroughScriptureApp.swift:140`.
- **What is wrong:** when the text is replaced, the text view's selection changes while `isReplacingText` is true, and `selectionDidChange` returns before calling `onSelectionChange`. Nothing reports the selection after the replacement. On the model's side, `MarkupModel.load` clears `currentSelection` only for a new book or a new translation (`T/MarkupModelTests.swift:902-930` pins exactly that). The page holds one chapter, so turning to another chapter of the same book replaces the text and leaves `markup.currentSelection` holding the previous chapter's verse.
- **Why it matters:** click a verse, press → (or ⌥⌘→, or the foot's link), then press ⇧⌘A, the toolbar's assistant button, or ⌘K › Ask the Assistant: `assistant.openAskingForContext(selection: markup.currentSelection)` starts a conversation about the previous chapter's verse, with nothing selected on screen. Spec 5.1's (call) says "what is selected on screen is what gets asked about", and Esc is offered as the way back to the open conversation, which the reader has no reason to press here. A text-size change (a new layout id, same book and translation) does the same. The mechanism is older than this branch (a dragged selection then ⌥⌘→), but one-click selection and ←/→ make it the everyday path.
- **Uncertainty:** this assumes the selection notification is delivered synchronously during the storage edit. The `isReplacingText` guard in `selectionDidChange` only has a purpose if it is, and `MainActor.assumeIsolated` in the observer agrees.
- **How to fix:** in `ChapterTextController.update`, when `textChanged`, report the selection once the new text is in: `DispatchQueue.main.async { [weak self] in guard let self else { return }; self.onSelectionChange(self.selectionReport()) }` (deferred, because `update` runs inside `updateNSView`, where SwiftUI state must not change; the file's other reports do the same). Do not change `MarkupModel.load`'s rule; the reload-same-chapter case must keep the selection.
- **Test to add** (`T/ReaderKeyTests.swift` or `T/ReaderClickTests.swift`, with `controller.onSelectionChange = { model.setSelection($0) }`): select verse 2, show another chapter's layout (`F.layout(F.verses(chapter: 6, count: 5))`), turn the run loop once, expect `model.currentSelection == nil`.

#### I2. Closing the palette can take the keyboard away from the assistant's composer

- **Where:** `SUI/ChapterTextController+Keys.swift:157-166` (`requestFocus`, the capture at `:163`), `:171-190` (`resolveFocus`, the comparison at `:180`), `:200-202` (`isTyping`). The test: `T/ReaderKeyTests.swift:469-480`.
- **What is wrong:** the "field being left" is remembered and compared by object identity, but every `NSTextField` in a window edits through the window's one shared field editor. The palette's field (`SUI/CommandPaletteView.swift:97`, a SwiftUI `TextField`) and the assistant's composer (`SUI/AssistantComposer.swift:41`, a `TextField` that sets its focus on appear, `:67`) are the same `NSTextView` to this check. The comment at `:181-182` describes the gap; the code does not close it.
- **Why it matters:** ⌘K › Ask the Assistant, or choosing a conversation row in ⌘K, closes the palette and opens the panel in one step. The palette stays in the hierarchy for its 0.15 s fade (`MAC/MainWindowView.swift:116-122`), so the request records the field editor as the field being left. When the notes column is already showing, the composer appears in that same pass and takes focus in the next; the reader's `resolveFocus` then sees "the same field" and takes the keyboard from the composer. The question's letters then run as reader keys on the selected verse: N makes a note, B toggles a bookmark, a digit colours it. This is the spec's second anti-goal.
- **The test gives false assurance:** `finishingANoteOrClosingThePaletteGivesFocusBackFromItsOwnField` (`:475-476`) claims "another field took focus before the request settled (the assistant's composer): it keeps it", but it uses two separate `NSTextView`s, which real text fields are not. It cannot fail for the real case.
- **Uncertainty:** whether SwiftUI applies the composer's focus before or after the reader's deferred `resolveFocus` is a race. With the notes column hidden the composer appears a pass later and wins, so the failure would show only with the column already open.
- **How to fix:** remember the field, not the editor. In `requestFocus`, when the responder is an `NSTextView` with `isFieldEditor == true`, store its `delegate` (the `NSTextField` being edited) in a second weak property (for example `weak var focusFieldBeingLeftOwner: AnyObject?`); in `resolveFocus`, treat the responder as `.fieldBeingLeft` only when it is the same object and, for a field editor, its current `delegate` is that same owner. Update the comment at `:181-182` to say what the code now does.
- **Test to change:** rebuild the second half of `finishingANoteOrClosingThePaletteGivesFocusBackFromItsOwnField` with two `NSTextField`s in the harness window (make the first one first responder so the field editor is up, request `.paletteClosed`, make the second one first responder, resolve, expect the second still holds focus through the field editor).
- **By hand (Matt's list):** with the notes column showing and a verse selected, ⌘K, type "ask", Return, then type a sentence: every letter lands in the composer.

#### I3. Reader keys are live in two moments when the reader believes they are typing elsewhere

Spec section 2 anti-goal: "A bare key that acts while the reader is typing in a note, the search field, the palette or a sheet."

- **(a) Just after ⌘K.** `SUI/CommandPaletteView.swift:151-158`: its own comment says a focus request made on appearance is dropped when the reader's text view holds first responder, so it asks again after 50 ms. Before this branch the reader held first responder only after a click, and early keys went nowhere; now the reader holds it nearly always, and for those ~50 ms the keys are commands. Typing "1 cor 13" briskly after ⌘K would colour the selected verse with colour 1 and leave " cor 13" in the palette; "john" would move the selection with J and, with a verse selected, start a note with N.
- **(b) After N with the notes column hidden.** This path is new in this branch (before it, Add Note with the column hidden made a note nobody could see) and nobody has seen it in the app, because N may not be pressed in the Debug store. `SUI/NoteTextEditor.swift:68-75` focuses the editor one main-queue turn after `updateNSView` through `textView.window?`. If the new inspector's editor is not in the window by then, the call does nothing, the reader keeps the keyboard, and the note's prose runs as reader keys (B toggles a bookmark, digits recolour the note's own highlight, J and K move the selection).
- **Uncertainty:** (a) needs a first character within about 50 ms of the palette appearing; rare per press, but ⌘K-then-type is one habitual motion repeated thousands of times, and the effect is a silent change to the reader's markup. (b) may simply work; it is the one unverified path where failure turns prose into commands.
- **How to fix (one gate closes both):**
  1. In `ReaderKeyCommands.perform` (`SUI/ReaderKeyCommands.swift:10`), before the `switch`: `if navigation.isPaletteShown || markup.editingNoteID != nil { return true }`. This swallows every reader key routed there (colour, 0, N, B, ←, →, ?). For J, K, ⇧J, ⇧K and Esc, which the controller handles itself, add the same condition where the closure is wired (`MAC/MainWindowView.swift:262-264` could set a `readerKeysEnabled`-style flag the controller checks at the top of `perform`, `SUI/ChapterTextController+Keys.swift:34`), or make `ColumnTextView.keyDown` (`SUI/ChapterTextController.swift:1337`) ask the delegate before resolving the stroke. A blur ends a note's edit after 200 ms (`SUI/NoteRowView.swift:192-197`), so the gate never blocks a reader who has clicked back into the text for longer than that.
  2. In `NoteTextView` (`SUI/NoteTextEditor.swift:110`), honour a pending focus request in `viewDidMoveToWindow`, as `ColumnTextView` does at `SUI/ChapterTextController.swift:1330`: keep a `var wantsFocusWhenInWindow = false`, set it in `updateNSView` when the deferred `makeFirstResponder` finds no window, and settle it when the window arrives.
- **Tests to add:** `ReaderKeyCommands.perform(.color(1), …)` changes nothing while `navigation.isPaletteShown` is true and while `markup.editingNoteID` is set; a `NoteTextView` asked for focus before it has a window takes first responder once added to one.
- **By hand (Matt's list):** ⌘K then type a reference at once, with a verse selected; N with the notes column hidden; N with the assistant showing.

#### I4. The Notes window's list takes focus from its search field

- **Where:** `SUI/NotesBrowserView.swift:163` (`.onAppear { listFocused = true }` on the list's scroll view), with `:29-35` (the list is removed whenever `model.entries` is empty) and `:59-66` (the toolbar search, debounced 150 ms).
- **What is wrong:** `onAppear` runs every time the list is inserted, not only when the window opens. A search that goes from no results back to some (a typo, then Backspace) re-inserts the list about 150 ms later and moves keyboard focus out of the search field while the reader is typing in it.
- **Why it matters:** the next letters go to the list and are lost, and the reader must click back into the field. Nothing is deleted: `rebuild()` (`SUI/NotesBrowserModel.swift:92`) has set `selectedID` to nil by then, so Delete in the list finds no row. This is the "no path steals focus from a field being typed in (the Notes window)" seam, introduced by fix round 3's move to one focusable list.
- **How to fix:** focus the list only when nothing is being searched: `.onAppear { if !isSearchPresented && model.query.isEmpty { listFocused = true } }`. (Or move the first focus to the window's own first appearance with a `@State private var didFocusList` flag.) Keep the click's `listFocused = true` at `:174`.
- **By hand (Matt's list):** ⌘F, type something that matches nothing, Backspace until rows return, keep typing: the letters stay in the field.

#### I5. The cut-off shortcut label (already decided; the wording needs care)

- **Where:** `SUI/ShortcutCatalog.swift:73`: "Previous, next chapter, from anywhere" is cut with an ellipsis in its 220 pt column beside four keycaps.
- **How to fix:** not with "The same, from anywhere" (see "Rulings that look wrong"). Use a label that stands on its own and keeps the word "chapter": "Chapters, from anywhere", or "Chapters, anywhere" if the first still truncates at the default size (the label has roughly 120 pt, about 19 characters of `.callout`, beside ⌥ ⌘ ← →). Then:
  - extend `T/ShortcutCatalogTests.swift` `theFilterNarrowsRowsByTheirLabel` to expect both chapter rows for the query "chapter" (`ShortcutCatalog.filtered("chapter")[0].shortcuts.map(\.id) == ["chapters", "chaptersAnywhere"]`);
  - update spec section 13 (Task 5's paragraph, which says it "is to be shortened in the final review's fix wave") and re-render the sheet headlessly to confirm no row is cut.

### Minor (Nice to Have)

- **M1. Key repeat on the data keys.** `SUI/ChapterTextController+Keys.swift:59-61`, `SUI/ChapterTextController.swift:1337-1343`. A held B toggles the bookmark at key-repeat speed, saving to the synced store each time; a held N re-enters `addNote`. Fix: in `ColumnTextView.keyDown`, when `event.isARepeat` and the action is `.color`, `.noColor`, `.note` or `.bookmark`, return without acting (J, K, ⇧J, ⇧K and the arrows keep repeating). Test: a repeat event for "b" leaves `model.bookmarkVerses` as the first press left it.
- **M2. The launch focus path has no test.** `SUI/ChapterTextController.swift:1330-1333` and `SUI/ChapterTextController+Keys.swift:165`. A focus request made before the text view has a window is the only way the keys work when the window opens on a chapter and after Home and back, and it was not recorded as seen in the app. Test (in `T/ReaderKeyTests.swift`): a fresh controller given its first layout while its scroll view is in no window, then added to a window whose first responder is the window or `other`; expect the text view to be first responder without a call to `resolveFocus()`.
- **M3. The menu-chord test has a blind spot.** `T/ShortcutCatalogTests.swift:72`. The pattern matches only `.keyboardShortcut(…, modifiers: …)`. A later `.keyboardShortcut("x")` (⌘ by default) or `KeyboardShortcut(…)` value would slip past the "one source" test. Fix: also count every `.keyboardShortcut(` in the scanned files and fail when one is neither matched by the pattern nor `.defaultAction` or `.cancelAction`.
- **M4. The link fallback matches book-name prefixes.** `SD/PassageLink.swift:45` hands any path that does not start with a book code to `ReferenceParser.parse`, whose `resolveBook` (`SD/ReferenceParser.swift:71-82`) falls back to prefix matches. So `bible://ma` opens Mark, `bible://e` opens Ezra, and "bible:is" typed in a note becomes a link to Isaiah (`SUI/ReferenceLinker.swift:122-132`). Fix: for links, accept the fallback only when the book part is an exact name, short name or alias (a `ReferenceParser.parse(_:exactBook:)` flag, or check `ReferenceParser.matchBooks(prefix:)` against an exact key). Tests: `bible://ma` and `bible:is` are nil; `bible://John%203:16` and `bible://john.3.16` still parse.
- **M5. The sheet's title has no ink token.** `SUI/ShortcutsSheet.swift:26-28`: `Text("Keyboard Shortcuts").font(.headline)` takes the system label colour, not `Color.inkPrimary`, which can differ under Sepia. Add `.foregroundStyle(Color.inkPrimary)`. (Every other text in the sheet, About and the Notes rows has its token.)
- **M6. DESIGN.json lacks the Mac reader's new behaviour.** DESIGN.md gained "A selected verse", "The reader's keys" and the focus rule (section 5, Reader); DESIGN.json has the phone's `verseTap`, the Shortcuts Sheet, Keycap, About and Notes Browser Row, but no entry for the Mac's click, the keys or the focus rule. Add entries that say the same as DESIGN.md.
- **M7. A group's name does not fit two of its rows.** `SUI/ShortcutCatalog.swift:104-105`: "Search the Notes browser" (⌘F) and "Export notes" (⇧⌘E) sit under "Notes Column", though they are the Notes browser's and File's. The spec fixes the five groups, so either leave it or move both rows to View (where "Notes browser" already is). The Notes window's own ↑, ↓, Return and Delete are not listed; they are the same keys as the column's. Matt's call; no code risk.
- **M8. The Notes window is not measured at scale.** `SUI/NotesBrowserView.swift:113-190`: each realised row carries an AppKit view (`SecondaryClickHook`), a context menu, two gestures and two accessibility actions inside a `LazyVStack`; the system list reused its rows. Laziness is intact by reading (nested `ForEach` inside the lazy stack, `scrollTo` by the `ForEach`'s own ids), and `visibleIDs` is O(n) per key press, which is fine for thousands. Nobody has scrolled 5,000 rows. If it drags, replace the per-row overlay with one hook on the scroll view that maps the click's point to a row.
- **M9. Contrast for Matt to weigh.** Accent text on `accent.wash` is 4.33:1 in Light, under 4.5:1 for body-size text; `T/PaletteTests.swift` `theNotesWindowsSelectedRowKeepsItsMarksVisible` guards 3:1. Already recorded in As built ("For Matt to weigh"); it also holds in the notes column, from before this branch.

---

## Triage of the ledger's deferred items

Every line of the ledger containing "minor (deferred)" or "Minors for the final review", by task.

### Fix before merge

| Ledger item | Reason and what to do |
|---|---|
| Task 4: "comment the shared-field-editor identity at +Keys.swift:283"; Task 4 follow-up: "the shared-field-editor comment describes a gap the code does not close" | This is finding I2. Close the gap; do not only reword the comment. |
| Task 4: "a test for a focus request made before the reader has a window" | Finding M2. The only evidence for the launch and Home-and-back focus path. |
| Task 4 follow-up: "the K and Shift-K test iterations may test J's band, not K's" | `T/ReaderKeyTests.swift` `aMoveAlongTheRevealIsTheKeysAndItsArrivalEndsIt`: add `#expect(band.to < band.from, "\(key) scrolls up")` for the K iterations (and `>` for J). One line; it guards a defect that already happened once. |
| Task 6: "no tests for hostile input (non-ASCII digits, overflow, bad escapes, very long strings, empty translation)" | The only untrusted input in the app. I traced these safe; pin them. Add to `TD/PassageLinkTests.swift` `malformedLinksParseToNothing`: `bible://jhn.٣.١٦`, `bible://jhn.99999999999999999999`, `bible://%`, `bible://%00`, `bible://.`, `bible://-`, `bible://jhn.3-5`, a path of 100,000 characters; and `bible://jhn.3.16?translation=` parses with `translationID == nil`. |
| Task 8: "no hostile-text test for the typed-link pattern" | Same cluster. Add to `T/ReferenceLinkerTests.swift`: a 100,000-character run of `bible:` characters, `bible:%`, `bible://` alone and `bible-dev:` at the end of the text each yield no link and return promptly. |
| Task 5: "a long row label wraps to three lines" | Finding I5. |

### Backlog (add a line to `docs/BACKLOG.md`)

| Ledger item | Reason |
|---|---|
| Task 3 and Task 4: "ChapterTextController.swift is over 1,300 lines" (about 1,360) | Under "Small things noticed": move the click and selection code into an extension file, as the keys were. No behaviour at stake. |
| Task 4 follow-up: "the band tests depend on wall-clock gaps and could flake under load" | Under "Small things noticed", beside the existing benchmark flake: inject a clock into `currentKeyScroll` if they ever flake. |
| Task 9: "no sticky section headers, Home/End, Page keys or type-to-select" | Already in BACKLOG ("The Notes window's keys the system list gave"). No change. |
| Task 8: "the phone note sheet's More menu has no Copy Link" | Already in BACKLOG ("Copy Link in the phone's note sheet"). No change. |

### Drop

| Ledger item | Reason |
|---|---|
| Task 1: "dead ?? branch at ReaderVerseLogic.swift:88" (now `:71`) | Harmless: `held != nil` implies `anchor != nil`. Tidy it only if the file is open anyway. |
| Task 1: "five untested doc-promised edges" | The verse logic is exercised through both controllers' tests as well as its own; no edge was named that the keys or the tap reach untested. |
| Task 2: "the settle wiring in the away tap's deferred block has no test" | Needs a simulated gesture to test; `settleRepeatedTap` itself is tested, and the slow second tap is on Matt's device list. |
| Task 2: "verseForTap runs twice on a settle" | A cheap pure function, once per slow second tap. |
| Task 2: "two-finger touch overwrites the recorded state" | A two-finger tap never begins the one-finger verse tap, so the overwritten state is never read wrongly. |
| Task 2: "a possible flicker on the slow-second-tap path" | Recorded in As built; device-only; on Matt's list. |
| Task 3: "a caret at a highlight's edge opens the highlight's menu" | The rule predates this branch and is what the highlight looks like at that point. |
| Task 3: "verseAnchor is cleared on any re-render that resets the selection" | Correct behaviour, recorded as a (call). |
| Task 4: "seed appliedFocusRequest in makeNSView (ChapterTextView.swift:610)" | Already done (`SUI/ChapterTextView.swift`, `makeNSView`). |
| Task 4: "the animated reveal has no test" | `heldKeysStepFromTheVerseTheyLastReached` and the band tests run with motion on. |
| Task 4: "clampedScrollY and isTransientFrame lost private" | The keys' extension lives in another file and needs them. |
| Task 4 follow-up: "a jump landing inside a stale band keeps keyRange" | The band now expires 0.3 s after the key; a kept `keyRange` then equals the selection or is ignored. |
| Task 4 follow-up: "reflow with unchanged clip origin" | The selection is character-based and survives a reflow; stepping from it and revealing the next verse is right either way. |
| Task 4 follow-up: "stale keyRange after a click" | Traced: `keyRange` only matters when it equals the current selection, and any hand scroll clears it; a click that reselects the same verse is on screen by definition. |
| Task 4 follow-up: "reveal can skip a scroll mid-animation" | Bounded by the 0.3 s window; the next key corrects it. |
| Task 4 follow-up: "the band's deadline uses Date() not a monotonic clock; a main-thread stall can make the keys' own frames look like a hand scroll" | Degrades to the pre-fix behaviour for one key; recorded in As built. |
| Task 4 follow-up: "a stale landing if a hand scroll cuts a reveal short within 0.3 s" | Recorded in As built; needs a wheel scroll inside a 0.2 s animation. |
| Task 5: "columns computed three times per body; ForEach keyed by offset; the '–' literal duplicated; no diacritic case in the filter tests" | A static sheet of 30 rows; none can misbehave. |
| Task 6: "url(scheme:) force-unwraps on a caller-supplied scheme (PassageLink.swift:77)" | Every caller passes `appScheme` or a literal; book ids are fixed ASCII; `everyBooksCodeRoundTrips` covers all 66. |
| Task 6: "an empty translationID writes '?translation='" | No caller writes a translation; Copy Link never does. |
| Task 6: "query names not percent-decoded and values not trimmed; a doubled trailing slash is nil" | Malformed links opening nothing is the spec's rule. |
| Task 6: "numbers are not checked against the book" | `openPassageLink` checks them (Task 7). |
| Task 7: "the load-failure ContentUnavailableView lacks handlesExternalEvents" | With no Bible database there is nothing a link could open. |
| Task 7: "max(book.chapterCount, 1) accepts chapter 1 of an empty book" | `lookUp` checks `isAvailable` again. |
| Task 7: "no test for a named translation lacking the chapter, nor that a rejected link leaves the palette and sheet as they were" | The same guard as the tested unnamed case (`aLinkTheAppCannotOpenChangesNothing`), and the guard returns before either flag is touched. |
| Task 8: "the markdown link to a missing chapter is untested; dead entries in the trailing set" | A recorded (call) with one line of code; the extra trailing characters cannot match the pattern and cost nothing. |
| Task 9: "the palette test guards ratios only, not the drawing; Sepia not rendered" | Matt checked the row by hand; Sepia is on his list. |
| Task 9: "the reference-order test restates the code"; "the filter test sets selectedID nil by hand and hard-codes a count" | Weak but harmless tests; the model's behaviour is covered by the neighbouring ones. |
| Task 9: "hitTest itself untested" | Needs a live event; the owner confirmed right-click by hand. |
| Task 9: "a stale doc comment on row(_:)" | Read at HEAD (`SUI/NotesBrowserView.swift:166-167`): accurate enough. |
| Task 10: "rows without a licence file show the licence as a bare last line" | A recorded (call); it reads as intended. |
| Task 10: "isHeading also matches any short all-caps line" | Layout only; the words are tested unchanged. |
| Task 10: "Licenses/ not clean-built on iOS" | The final iOS run (763 tests) passed `CreditsTests`, which reads both files from the bundle. |
| Task 10: "the copyright line and 'All rights reserved.' join on one line" | Display only; the stored file is as received and the row's notice shows both sentences. |

---

## Rulings that look wrong

- **Ledger line 77: relabel the ⌥⌘←/→ row "The same, from anywhere" under "Previous, next chapter".** The label only makes sense beside its neighbour. The sheet's filter matches rows by their label (`ShortcutCatalog.filtered`), so typing "chapter" would no longer find this row and typing "anywhere" would show it without its antecedent; VoiceOver reads each row as one element ("The same, from anywhere: Option Command left arrow…"). Use a label that stands alone and keeps the word, as in finding I5.

No other ruling looks wrong. Sending the slow second tap, the Shift-J reveal and the held keys back as defects was right; so was copying the real holybooks file, and replacing the system list and then the per-row focus. Finding I4 is a slip inside that last rewrite, not a flaw in the ruling. "Linking permitted by its terms" reads correctly without the appendix's remark. Trailers naming the model that wrote each commit are accurate attribution.

---

## Declined to judge

- Bundling four copyrighted translations whole; the 3dicons provenance; the ERV's copyright year: Matt's calls, already in BACKLOG.
- Whether `Licenses/holybooks-LICENSE.txt` is byte-identical to the pinned upstream commit: no network; I relied on the ledger's `cmp` and checked that the file carries the upstream's "hollybooks" spelling and structure.
- Control-click in the Mac reader (Task 3's concern): `clickEnded` does not exclude it, but the path (menu from `menu(for:)`, then mouse-up) predates this branch and could not be verified without the app.
- A link arriving while the Notes window is key, or while the main window is closed; another app claiming `bible://`: system routing, on Matt's list or outside the app by spec 7.3.
- How the tap feels on a real phone (the slow second tap, a tap that stops a flick); VoiceOver and Sepia on the new surfaces; the real Mac Settings window's About tab: these need a device or the running app.
- ↑, ↓, Space and the Page keys with a verse selected: AppKit's behaviour, unchanged by the branch.
- J and K doing nothing at a chapter's end: as the spec says.
- J after colouring a multi-verse selection carries on from the selection's first verse (the caret collapses to its start): the spec's "from that verse" does not settle it.
- The Notes browser's Delete still asking for confirmation: predates the branch, and DESIGN.md says so; CLAUDE.md's rule is about the reader.
- The front page's grid arrows, the palette's arrows and Return, and the Text & Layout popover's move commands not being in the catalogue: read as movement inside a control, not shortcuts.
- Either build reading both schemes (a `bible-dev://` link typed in a note renders as a link in Release): by design; only registration and copying are per build.
- The Add Color sheet being up when a link arrives: the pending colour still lands on the right verse, because the report carries its own book and chapter.
- The phone's note sheet closing (with an edit open) when a link arrives: `showInReader` does this on every other route too.
- "www.Lockman.org" in the NASB and Amplified notices being plain text with a live `lockman.org` link on the next line: it follows the appendix's two columns.
- The pre-existing `ReaderBenchmarkTests` flake.
- The specs and plans for later projects that the branch also carries: not under review.

---

## Recommendations

1. Run one fix wave: I1 to I5, the fix-before-merge tests in the triage table, and M1. Each is small and local; I3's gate is three lines plus the editor's window hook. M2 to M6 can ride the same wave; M7 to M9 are Matt's to decide.
2. Add to Matt's by-hand list in spec section 12 or 13:
   - click a verse, press →, then ⇧⌘A: the open conversation returns, not a new one about the old verse (I1);
   - with the notes column showing and a verse selected: ⌘K, "ask", Return, type a sentence (I2);
   - with a verse selected: ⌘K and type a reference at once, starting with a digit ("1 cor 13") (I3a);
   - N with the notes column hidden, and N with the assistant showing: the keyboard is in the editor (I3b);
   - in the Notes window: ⌘F, a query with no matches, Backspace until rows return, keep typing (I4).
3. Record I1 to I4 and their fixes in the spec's "As built", bring DESIGN.json in step for the Mac reader (M6), and add the two BACKLOG lines from the triage.
4. After the fix wave, re-run the package suite and the iOS `ScriptureUITests`, rebuild both Debug apps, and re-render the shortcuts sheet to confirm no row is cut.

---

## Assessment

**Ready to merge?** With fixes.

**Reasoning:** The spec is met bullet by bullet, every (call) is honoured or its change recorded, and the task-level work is sound. The gaps are at the seams the per-task reviews could not see: automatic reader focus meeting the palette, the composer and the note editor; the model's selection surviving a chapter turn; and one focus slip in the rewritten Notes window.
