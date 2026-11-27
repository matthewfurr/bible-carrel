# Milestone 10, project 1: verse basics

Status: approved by Matt, 2026-11-16. Plan: `docs/superpowers/plans/2026-11-16-milestone-10-verse-basics.md`. First of milestone 10's six projects (the main spec's milestone 10 section lists them). Branch `milestone-10-study-tools`.

## 1. Intent

Make everyday marking quicker without changing how the app works. Matt's words when he chose the phone's behaviour: "I don't want to complicate things, just make day to day use easier." Five pieces, all small:

1. On the iPhone, a tap on a verse selects the whole verse, so a whole-verse highlight no longer needs a press and a drag.
2. On the Mac, a click selects the whole verse, and single keys act on it: highlight, note, bookmark, next and previous verse, next and previous chapter.
3. A sheet on the Mac lists every keyboard shortcut in the app.
4. A passage can be linked from other apps: `bible://jhn.3.16`.
5. The Notes window's selected row is readable, and an About page credits every outside source.

Later projects build on "a selected verse": compare translations and cross-references (project 3) act on it.

## 2. Goals, non-goals, anti-goals

**Goals**

- One tap or one click takes a whole verse. Everything that follows (the menu, the handles, the colours) is exactly what a hand-made selection of that verse gets today.
- Every markup action on the Mac is reachable without the mouse.
- A link written in Craft or Bear opens the passage in Bible Carrel.
- Every outside source is named in the app, with its licence and a link.

**Non-goals**

- No new selection menu, action bar or sheet on the iPhone. Matt turned those down (options B and C of the mockup `phone-verse-tap.html`).
- No customisable shortcuts.
- No `https://route.bible/…` links and no share-as-image.
- No new keys on the iPhone with a hardware keyboard; holding ⌘ there shows the system's own list of the menu commands.
- Compare (C) and cross-references (R) are reserved keys; they do nothing and are not listed until project 3 builds them.
- Nothing stored changes: no new records, no new fields, no iCloud schema change.

**Anti-goals**

- A tap that surprises: selecting a verse when the reader only meant to stop a scroll, close the chapter cards or open a note.
- A bare key that acts while the reader is typing in a note, the search field, the palette or a sheet.
- A credits page that claims a permission the app does not have (see 7.3).

## 3. Approaches

**Selecting a verse.** Three were mocked up for the phone: (A) select the verse as text with today's menu, (B) a wash on the verse and a named-action bar, (C) handles with the bar. Matt chose A: B and C "are a change in what the user would expect". The Mac follows the same idea: a verse picked by a click or by J and K is an ordinary text selection, so nothing new is drawn and every existing action already knows how to act on it.

**A click on the Mac.** Three were offered: select quietly, select and open the menu, or leave clicks alone. Matt chose quietly: a click selects the verse and opens no menu; a drag and a right-click behave as today.

**Where the shortcuts show.** A sheet over the reader or a small window of its own (mockup `mac-shortcuts-sheet.html`). Matt chose the sheet.

**Links, the Notes row and credits** had one sensible way each and went to Matt as proposals he did not change: the link format the other app and route.bible already use; the selection wash `DESIGN.md` already requires; a plain list in Settings.

## 4. iPhone: a tap selects the verse

A tap on a verse's words or its number, with the pen off, selects that verse's text and presents the selection menu at it. The selection is the system's: handles at both ends, the menu `PhoneMarkupMenu` builds for that range. It is the same range a reader gets by dragging across the whole verse: the words and punctuation, without the verse number (`VerseSpan.textRange`).

- A handle dragged in takes part of the verse; dragged out, more verses. Word snapping applies as today.
- Press and hold still selects a word, as today.
- A tap on another verse selects that verse instead. *(Overturned by Matt on 2026-11-17 after using it: with anything selected, a tap elsewhere only deselects. See section 13, "Matt's first look".)* A tap on the verse already selected selects it again and shows the menu again. **(call)**
- A tap off the text (a margin, the air between paragraphs, a heading, the title block, the chapter's foot) clears the selection, as today.
- A tap on an existing highlight keeps today's behaviour: its note opens if it has one, otherwise the highlight is selected with its menu. **(call)**
- A tap on plain text while the chapter cards are open closes the cards and selects nothing. **(call)** A tap on a highlight then still closes the cards and opens the highlight, as today.
- A double tap: the first tap selects the verse, and the system's second tap narrows it to the word, as a double-click does on the Mac. **(call)**
- A tap that stops a moving scroll selects nothing. **(call)**
- With the pen on, taps do what they do today.
- A touch in the book thumb's edge zone or on a margin mark is not a verse tap.
- A single tap acts at once; it never waits to see whether a second tap follows.
- With VoiceOver running nothing changes: VoiceOver's own gestures select and act as today. **(call)**

The tap must be on the verse's laid-out lines (within the same small margin `highlight(at:)` allows), not merely nearest to them, so a tap in white space never selects.

## 5. Mac: a click and the keys

### 5.1 A click

A single click on a verse's words or number, outside any highlight, selects that verse's text. No menu opens. The selection looks like any other. *(Overturned by Matt on 2026-11-17 after using it: a click opens the menu every time, and with the menu open a click elsewhere only deselects. The bullets below that say otherwise are superseded. See section 13, "Matt's first look".)*

- A click on another verse moves the selection. A click on the selected verse leaves it selected. **(call)**
- A click off the text or Esc clears it.
- A click inside a highlight keeps today's behaviour: the highlight is outlined and its menu opens.
- A drag still snaps to words and opens the menu on mouse-up. A right-click still opens the menu. A double-click still selects a word and opens the menu.
- The click that brings the window forward selects nothing (AppKit's default; keep it).

**A selected verse is a selection everywhere. (call)** The assistant's button and ⇧⌘A already open on the selection when there is one, and that now includes a verse picked by a click or by J and K: what is selected on screen is what gets asked about. Esc clears it first for a reader who wants the open conversation back. Telling a clicked selection from a dragged one would make two selections that look the same behave differently.

### 5.2 The keys

They act only while the reader's text has keyboard focus. A note being edited, the sidebar search, the palette, a sheet, the Notes window and Settings never see them.

**Focus. (call)** Today nothing gives the reader's text keyboard focus but a click. For the keys to work from the keyboard alone, the reader's text takes focus when the main window opens on a chapter, when a chapter opens, when a note's edit finishes (⌘Return, Return or Esc), and when the palette or the shortcuts sheet closes. It does not take focus from the notes column's rows while the reader is moving among them with ↑ and ↓, nor from any field being typed in.

| Key | Action |
|---|---|
| J, K | Select the next, the previous verse. With nothing selected, start at the first verse on screen. From a selection or a caret, move from its last (J) or first (K) verse. At the chapter's last or first verse, nothing. The verse is scrolled into view if it is not wholly there (a cut under Reduce Motion). |
| ⇧J, ⇧K | Grow or shrink the selection by a verse, as Shift with the arrow keys does in a list. |
| 1 to 9 | Highlight the selection in the reader's nth colour, in Settings order; inside a highlight, recolour it. A number past the last colour does nothing. Same result as choosing that swatch in the menu. |
| 0 | Take the colour off the highlight the selection is in: the menu's No Color. A highlight with a note keeps the note on a dotted underline; one without is removed. Undoable. **(call: Matt was shown "Remove the highlight"; No Color never deletes a note with one key.)** |
| N | Add or edit the note on the selection: the menu's Add Note or Edit Note. The notes column is shown if it was hidden, and takes the inspector back from the assistant, so the editor is on screen with the keyboard in it. The menu's own Add Note gains the same fix: today, with the column hidden, it makes a note nobody can see. **(call)** |
| B | Bookmark or un-bookmark the selection's verse: the menu's Bookmark. |
| ←, → | Previous, next chapter, crossing books as the foot's links do. The same as ⌥⌘← and ⌥⌘→, which stay. |
| Esc | Clear the selection, when there is one. |
| ⌘/ | Show or hide the shortcuts sheet. Also `?`. |

With nothing selected, the number keys, N and B do nothing. ↑, ↓, Space and Page keys scroll as today.

After a colour is applied the selection collapses as it does from the menu, so the new colour shows; J and K carry on from that verse.

## 6. Mac: the shortcuts sheet

A system sheet on the main window, opened by ⌘/, `?` in the reader, Help › Keyboard Shortcuts, and a "Keyboard Shortcuts" command in ⌘K. From the Notes window or Settings, ⌘/ brings the main window forward first, as ⌘K does.

- **Layout:** the title "Keyboard Shortcuts" with a filter field beside it; three columns of groups; a foot with "Press ⌘/ any time to see this." and Done.
- **Groups:** Go, View, Verses, Notes Column, Assistant. Every shortcut in the app is in one of them, including the menus' existing ones. Where two keys are a pair they share a row ("Next, previous verse": J K).
- **Filter:** focused when the sheet opens; typing narrows the rows by their label. No match shows one line naming what was typed.
- **Closing:** Done (the default button), Esc, or ⌘/ again.
- **One source:** the rows come from one catalogue in code, and the reader's key handling reads its keys from the same catalogue, so the sheet cannot list a key that does something else.
- **Look** (tokens only): the sheet on `paper.panel`; title in Headline; group names in the Label style (`.caption` semibold, `ink.secondary`, header trait); row labels in `.callout` `ink.primary`; each key a keycap: `paper.overlay` fill at radius `sm`, no stroke, the glyph in `.caption` medium `ink.primary`, sized with `@ScaledMetric`. Keycaps are text glyphs (⌘ ⇧ ⌥ ⌃ ↩ ⌫ esc), not symbols. Rows `xs` apart, columns `lg` apart, `lg` padding.
- **VoiceOver:** a row is one element, its label then its keys spoken by name ("Next, previous verse: J, K"; "Go to anything: Command K").

## 7. Passage links

### 7.1 The format

`bible://<book>[.<chapter>[.<verse>[-<verse>]]][?translation=<ID>]`

- The `bible://` scheme is the one michaelshimeles/bible uses; its path (`jhn.3.16`) is route.bible's. route.bible itself documents only `https://route.bible/jhn.3.16` and no `bible://` form (checked 2026-11-16), so this is a shared convention, not a standard.
- `<book>` is the app's own three-character book code in lower case (`gen`, `jhn`, `1co`, `psa`); the 66 codes are the same ones route.bible lists. Any case is accepted.
- Examples: `bible://jhn.3.16`, `bible://jhn.3.16-18`, `bible://rom.8`, `bible://jhn` (John 1), `bible://1co.13.4-7?translation=KJV`.
- Also accepted: the long range `jhn.3.16-jhn.3.18`; a range that runs into another chapter (it opens at its first verse); `bible:jhn.3.16`; and a path `ReferenceParser` can read once decoded (`bible://John%203:16`).
- `translation` names one of the app's translations, in any case. One the app lacks is ignored. `v` is read the same way, since route.bible's own URLs use `?v=ESV`. Any other query item is ignored.
- A link the app cannot read, or a chapter the translation lacks, opens nothing; the app still comes forward. A verse past the chapter's end opens the chapter.

### 7.2 Opening and copying

- Both apps answer links, the Mac and the iPhone, each with its build's scheme (below).
- Opening a link is a lookup (`NavigationModel.lookUp`): the passage shows, the reader's place is kept, and Back returns to it. With `translation` it is a lookup in that translation. On a cold launch it runs once the store is ready.
- **Copy Link** joins the selection menu on both apps, after Copy with Reference (on the iPhone it sits behind the chevron). It copies the link to the selection's verses, with no translation, so the link names a passage and not an edition. **(call)** Pasted as plain text it is the URL; pasted into an editor that takes rich text it is the reference ("John 3:16–18") carrying the link.
- A `bible://` link typed or pasted into a note is a link in the rendered note and behaves like any other reference there.
- **Two builds, two schemes:** Release answers `bible://`. Debug answers and copies `bible-dev://`, so a link in Matt's own notes never opens the Debug copy. **(call)** The scheme comes from one build setting read through the Info.plist. The Mac target gains an Info.plist for the URL type; milestone 9 found that Info.plist edits can break the name or the signature, so the built app's name, bundle ID and signature are checked after.

### 7.3 Outside the app

Nothing is registered with route.bible and nothing is fetched from it. Another app on the same device may also claim `bible://`; which one the system then opens is the system's choice, and the app does nothing about it.

## 8. The Notes window's selected row

Today the list draws the system's solid selection behind rows whose text stays in the app's own dark inks, so a selected note is hard to read. The selected row takes `accent.wash` at radius `md` instead, with every text colour unchanged, whether the window is key or not, as the notes column's rows do. ↑, ↓, Return, double-click, Delete and the context menu keep working, and VoiceOver still hears the selected trait. `PaletteTests` already holds `ink.secondary` on `accent.wash`.

## 9. About

A new last tab in the Mac's Settings, About (`info.circle`), and a last row "About" in the iPhone's Settings list, sharing one view.

- At the top the app's name and version.
- Then grouped form sections, rows and never cards: **Scripture** (each bundled translation: its name, its copyright or public-domain line, a link), **Headings and titles** (the Berean Standard Bible, the KJV's titles, eBible.org), **Typefaces** (Literata, Source Serif 4; each opens its licence text, which already ships beside the fonts), **Icon** (3dicons.co), **Videos** (BibleProject: the app links to their site), **Software** (GRDB, with its licence text).
- A row is the source's name in `.body` `ink.primary`, what the app uses it for in `.callout` `ink.secondary`, the notice the holder asks for in `.caption` `ink.secondary`, and a link in the accent.
- The entries come from one catalogue in code. A test fails if a bundled translation or a bundled font has no entry.
- Matt takes no credit here: no author line.
- Each later project adds its sources (cross-references, people and places) to the same catalogue.
- The README's Acknowledgements section is brought in line.

The line for each source is in the appendix, gathered from each holder's own page on 2026-11-16.

**What the page does not do.** Four bundled texts are under copyright: the ESV, the NASB (the 1995 text), the Amplified Bible (the bundled file is the Classic Edition of 1987) and the ERV (the Easy-to-Read Version, not the public-domain English Revised Version). Their holders' standing permissions cover quotations of 500 or 1,000 verses, never a whole Bible, and each holder's suggested notice ends "Used by permission". The app has no such permission, so About states who holds the copyright and links to them, and does not say "Used by permission". **(call)** Bundling them whole stays what it was, Matt's call for personal use, and stays the open "App Store and licensing" item.

**Names.** About names each text exactly ("Amplified Bible, Classic Edition", "Easy-to-Read Version", "New American Standard Bible (1995)"). The translation picker keeps the short names it has.

## 10. Constraints

- TextKit 2 only; never touch `textView.layoutManager`.
- `DESIGN.md` governs: tokens only, semantic text styles, `AppSpacing` and `AppRadius`, no card by reflex, no new shadow or material. The sheet is the system's sheet.
- Deletes stay undoable through the window's `UndoManager`.
- No test touches iCloud, the Keychain, the network or Matt's stores.
- The `.dev` store gets no test notes.

## 11. Left to the builder

- How the phone's tap recognizer is ordered against the text view's own taps, the highlight tap and the away tap.
- How a click is told from a drag on the Mac, given that `mouseDown` already tracks the whole drag before `mouseSelectionEnded` runs.
- Whether the keys are handled in `ColumnTextView.keyDown` or elsewhere, so long as section 5.2's focus rule holds.
- How the Notes window drops the system selection (a row background, or its own list as the notes column has).
- How the pasteboard carries the link's two forms on each platform.
- How SwiftUI is kept from opening a second window for an incoming link on the Mac.

## 12. Verification

Tests first, in the package suite and the iOS `ScriptureUITests`:

- Phone: a tap at a point in verse N selects exactly that verse's text range and reports it; the menu's items equal those for the same range selected by hand; a tap on a highlight, with the pen on, with the cards open, during deceleration, in the margin and in the thumb's zone each does what section 4 says.
- Mac: a click selects the verse and opens no menu; a click in a highlight and a drag behave as before; each key in 5.2 does its action and none acts without reader focus; J at the last verse and K at the first do nothing; 0 keeps a note.
- Catalogue: every key the reader handles is in the shortcuts catalogue and no two entries share a key in one focus.
- Links: each example in 7.1 parses to its reference; malformed links parse to nothing; a copied link round-trips; every book's code round-trips.
- About: every bundled translation and font has an entry.
- Palette: any new pairing holds its ratio.

Seen by eye before it is called done (the handover's snapshot recipes): the phone's selected verse with its menu, in the simulator; the Mac's selected verse, the shortcuts sheet, the Notes window's selected row and About, in light and dark.

For Matt on his devices:

- [ ] iPhone: tap a verse, colour it; drag a handle for part of a verse; press and hold for a word; tap a highlight with a note; tap while the cards are open.
- [ ] Mac: click a verse and press 1; press N, type, finish with ⌘Return, then J, B and 0 without touching the mouse; walk a chapter with J and K; ← and → turn chapters; ⌘/ shows the sheet and its filter narrows it; with a verse selected ⇧⌘A asks about it, and after Esc it reopens the conversation.
- [ ] Paste a copied link into Craft or Bear and click it, on the Mac and on the iPhone: the app opens the passage, and Back returns. (The Debug builds answer `bible-dev://`.)
- [ ] The Notes window's selected row reads clearly in light, dark and Sepia.
- [ ] Settings › About on both apps: every credit present and every link opens.
- [ ] Added by the final review (Mac; each is a fix nobody has watched in the app):
  - Click a verse, press →, then ⇧⌘A: the open conversation returns, not a new one about the previous chapter's verse.
  - With the notes column showing and a verse selected: ⌘K, type "ask", Return, then type a sentence. Every letter lands in the assistant's question box.
  - With a verse selected: ⌘K and type "1 cor 13" at once. The verse is not coloured. (The first character may be lost if it is typed within about a twentieth of a second.)
  - N with the notes column hidden, and N with the assistant showing: the keyboard is in the note's editor.
  - Hold B on a selected verse: the bookmark is set once, not flickered.
  - In the Notes window: ⌘F, type something that matches nothing, Backspace until rows return, keep typing. The letters stay in the field.
  - Control-click a verse in the reader: its menu opens as before.
  - The selection's fill (build `6820403`): click a verse of Psalm 1 and a long prose verse; drag across several verses and past the window's edge so it scrolls; ⌘A; bring another app forward and come back. The fill stays behind the words, and no full-width fill shows at any moment.
  - The same on the iPhone (build `d454185`, once the Debug app is installed): with a verse selected, switch the page style to Lectern and back (the same words stay selected). Also: tap a verse of Psalm 1 and a long prose verse; drag a handle across verses and watch the loupe; select a long passage and scroll; with a verse selected, change chapter by the cards, the thumb and the foot's link (nothing should be selected in the new chapter); look once in dark and in Sepia.

- [ ] After Matt's first look (build `aba8470`), Mac:
  - Click a verse: it is selected and the menu opens below its last line (or above its first), clear of its words. Choose nothing.
  - With the menu open, click another verse: the menu closes and nothing is selected. Click that verse again: it is selected with its menu. *If the first verse stays selected instead, the app read the click as Esc; say so.*
  - Double-click a word: the word is selected with its menu. *If instead only the menu closes, or the verse stays selected, the second click was not seen as a double-click; say so.*
  - Click a verse, press Esc, press J: the menu closes, the verse stays selected, and J moves on quietly.
  - Click a verse in a short window where the verse fills the page: the menu opens beside the pointer, not under it.
  - Drag across several verses: the fill follows the drag as it goes.
  - After a click away, Shift-click a verse: it is a plain click, not an extension from the old verse.
  - Deep in a long chapter, click a verse and then click away: the page does not jump.
  - Click a verse and click a colour swatch's row between the swatches: nothing is cleared that should not be.
- [ ] After Matt's first look, iPhone: tap a verse, then tap another (nothing selected), then tap it again (selected, menu above or below it); with a verse selected tap a note mark in the margin (only deselects); tap a verse near the top, near the bottom, and one longer than the screen; turn the phone sideways with a long verse selected.

## 13. As built

Built 2026-11-16 and 2026-11-17 on `milestone-10-study-tools` in eleven tasks, each reviewed (commits `91afaca` to `80a1aa2`, then the documents; Task 11's own review found small errors in the documents, corrected in a second commit), then reviewed whole and fixed in one wave (below, after Task 10). What differs from the sections above, and every **(call)** made on the way, task by task. `DESIGN.md`, `DESIGN.json` and `README.md` were brought in step in Task 11 and again in the fix wave.

**Process rulings.** The plan was executed task by task, a fresh implementer and a fresh reviewer for each, without asking Matt to choose a method (a process call; it costs nothing to undo). Commit trailers name the model that wrote the commit, so the attribution stays accurate. Task 10's BibleProject credit says "Linking permitted by its terms" (a ruling, see Task 10). Rulings on defects found along the way are under their tasks (the slow second tap, Shift-J and Shift-K, the held keys, the holybooks licence, the Notes window).

**Task 1: the verse rules both readers share** (`ReaderTextLogic.verse(at:in:isOnLines:)`, `verseStep`, `verseExtension`). **(call)** A verse's lines are hit at their full line height, not only the glyphs' height (review focus 1). **(call)** A selection with no part on screen is nothing selected (review focus 2), so J and K start from the first verse on screen.

**Task 2: the iPhone tap** (section 4). The system's double tap did narrow the selection to a word, so the fallback the brief kept in reserve (the verse tap taking the second tap itself) was not needed. A second tap that the system does not take as a double tap (a slow second tap that `UITouch.tapCount` still counts as the second) left nothing selected at first, against section 4's "a tap on the verse already selected selects it again"; `settleRepeatedTap` now leaves the verse selected with its menu. **(call)** The tap's own presentation asks the menu provider first, so a tapped verse's menu is asked for three times, all equal. **(call)** `highlightTap`'s rule that every other single tap on the text view waits for it was left alone; it now includes `verseTap`, and the two never both begin. Known and accepted: one run-loop turn of "no selection" before a settled verse is restored; the settle wiring in the away tap's deferred block has no test of its own; a two-finger touch overwrites the recorded tap state.

**Task 3: the click on the Mac** (section 5.1). **(call)** A plain click that finds no verse (a margin, a heading) falls through to the old behaviour, which does nothing for a caret outside a highlight. **(call)** `verseAnchor` is cleared on any re-render that resets the selection. **(call)** `isOnLines` is the AppKit counterpart of the phone's rule, using `characterIndexForInsertion`. Seen by hand in the Mac Debug app: a click selects with no menu, a click on the selected verse keeps it, and the click that activates the window selects nothing.

**Task 4: the keys and the focus rule** (section 5.2). **(call)** N shows the notes column through `onShowNotesColumn`, and the menu's Add Note gained the same call. **(call)** For a caret, "on the visible page" is judged by the caret's line frame. **(call)** The head's line for a reveal is `clip.minY + headLineY`; "taller than the page" means aligning the bottom would push the top under the head. Two defects were found and fixed after the first commits: Shift-J and Shift-K revealed the selection's top, not the verse that moved (they now reveal the free end); and a held J or K stepped backwards at key-repeat speed because the live visible rect was read mid-reveal. The keys now step from the range they last reached, and a scroll the reader makes by hand is told from the keys' own for 0.3 s after a key, by timestamp, so a deadline that never arrives cannot make later scrolls look like the keys'. Seen in the app: 60 presses of J at 0.05 s landed on Psalm 119:60, 130 more stopped at 176, and 100 K landed on 76. Known and accepted: the deadline is read when the notification is processed and uses `Date()`, so a main-thread stall can make the keys' own frames look like a hand scroll (it degrades to the old behaviour); a hand scroll that cuts a reveal short inside 0.3 s can leave a stale landing; the animated reveal has no test. Focus returning after the palette or the sheet closes was seen in the app.

**Task 5: the shortcuts sheet** (section 6). **(call)** The columns area has a minimum width (three columns and their gaps) and a minimum height (`@ScaledMetric` 340), so the sheet does not shrink while the filter narrows. **(call)** The file is wrapped in `#if os(macOS)` (`.onExitCommand` is not on iOS). **(call)** The palette command only sets `isShortcutsShown`; the palette closes itself. **(call)** The no-match line trims the typed text. **(call)** The shortcuts' labels follow the menus' names ("Back, forward", "Notes browser"), and UI copy keeps American spelling ("No color", "Highlight in a color"). **(call)** The sheet takes no `.followsSepia()` of its own; `.sheet` passes the environment on. A long label ("Previous, next chapter, from anywhere") ran to a second line and was cut with an ellipsis in its 220 pt column at the default size; the fix wave relabelled it "Chapters, from anywhere", which sits on two whole lines beside its four keycaps (seen in a headless render, light and dark). Typing "chapter" in the filter finds both chapter rows. Known and accepted: the columns are computed three times per body; rows are keyed by offset.

**Task 6: passage links, read and written** (section 7.1, `PassageLink`). **(call)** Number pieces are ASCII digits only and at least 1; more than one "-" in the path is unreadable; `jhn.3.16-jhn.3.16` is unreadable, like the short form; the translation id is percent-encoded when written and query values are decoded when read; the first non-empty value of a repeated name wins; items without a value are skipped. The fix wave added tests for hostile input (digits that are not ASCII, overflow, bad escapes, a 100,000-character path, an empty translation), all of which read as nothing. Known and accepted: `url(scheme:)` force-unwraps a caller-supplied scheme; numbers are not checked against the book (the call site copes).

**Task 7: both apps answer links** (section 7.2). **(call)** A verse past the chapter's end in a link opens the chapter at its start (a `ScrollTarget`'s token is a fresh UUID, so the test compares chapter and verse, not the value). **(call)** `PASSAGE_URL_SCHEME` is a build setting read through the Info.plist (`bible` in Release, `bible-dev` in Debug); the Mac target gained an Info.plist, and the built app's name, bundle ID, executable, signature and iCloud entitlement were checked unchanged. **(call)** `openPassageLink` lives in an extension of `NavigationModel` in the same file, to reach its private store, and a `max(chapterCount, 1)` guard keeps the range valid. Checked by the controller on the Mac Debug app: a link opens its passage, no second window appears, a nonsense link changes nothing, and a cold launch lands on the passage. Not tried: a link while the Notes window is key; ⌘[ after a link on the Mac (covered by a test and the simulator). On the iPhone, a link opened while Settings is showing closes Settings and shows the passage with "John 3" as its way back (seen in the simulator in Task 11: `xcrun simctl openurl booted "bible-dev://jhn.3.16"` with Settings' About page and a disclosed licence open). Known and accepted: the load-failure `ContentUnavailableView` does not handle external events; no test that a rejected link leaves the palette and sheet as they were.

**Task 8: Copy Link and links in notes** (section 7.2). **(call)** A markdown link to a chapter the book lacks has its link removed and is shown as text. **(call)** The typed-link pattern accepts letters, digits and `. - _ % = & ? # /` after the scheme, and trims trailing punctuation. **(call)** The phone's note sheet has its own More menu with its own Copy items and no Copy Link; not in the brief, so set aside (BACKLOG).

**Task 9: the Notes window's selected row** (section 8). Not a system `List` with a row background. That was built first, and Matt saw the system's dark selection flash before the wash; the window now draws its own rows in a scroll view with a lazy stack, as the notes column does. The selected row is `accent.wash` at radius `md`, inset as the notes column's rows are, with every ink unchanged. The list is one keyboard focus stop whose up, down, Return and Delete act on the selected note (with nothing selected, down takes the first and up the last; the selection logic is in `NotesBrowserModel`). A click selects at once and a double-click opens the note. A right-click or Control-click selects the row before its menu opens, by an AppKit hook (`SecondaryClickHook.swift`) that answers hit tests only for those clicks. After a delete the selection goes to the note that took its place. It took three fix rounds: the first replaced the list; the second made the click act at once (it had waited out the double-click interval) and tied the focus to the selection; the third replaced per-row focus with one focusable list, after the focus-to-selection sync stepped the selection back under key repeat and left the keys dead with no focused row. Matt checked the final build by hand on 2026-11-17: click, arrow keys and right-click all good. Not rebuilt from the system list: sticky section headers, Home and End, the Page keys and type-to-select (BACKLOG). Known and accepted: a filter or search that hides the selected row clears the selection; the hook's `hitTest` has no test of its own; the palette test guards ratios, not the drawing.

**Task 10: About and its credits** (section 9). **(call)** The credits place two sources by what they are: bobuk/holybooks sits under Software, with its licence text shown as GRDB's is, and the King James Version's titles, with eBible.org, are credited on the KJV's own row under Scripture, so "Headings and titles" holds only the Berean Standard Bible. The appendix's bracketed remarks are not shown, so the BibleProject row's licence reads "Linking permitted by its terms" (the appendix's "on those conditions" would dangle without them). **(call)** The licence shown for holybooks is the project's own file, copied byte for byte from the pinned commit (the first build used a recreated BSD text, found in review and replaced; "hollybooks", with two l's, is in the upstream file). **(call)** Licence texts are re-wrapped for display with line breaks only changed (`LicenseText.reflowed`: headings, rules and list items keep their own lines); the stored files are as received, and a test compares the words. **(call)** A row with no licence file shows its licence name as a plain last line; the version line falls back to "Version 1.2", "Build 3" or "Version unknown" when keys are missing. For Matt to weigh: accent link text on `accent.wash` computes to 4.33:1 in Light (`#247966` on `#D1F0E6`) and 6.92:1 in Dark (`#73C3AE` on `#0A3028`), in a selected Notes row as in the notes column today; `PaletteTests` guards 3:1 for that pairing, not 4.5:1. Known and accepted: `isHeading` also matches any short all-caps line (layout only); the copyright line and "All rights reserved." of the holybooks licence join on one line when re-wrapped; `Licenses/` was not clean-built on iOS (an incremental run once missed the copy and passed on rerun).

**The final review and its fix wave** (2026-11-17, commits `4050353` to `f487178`). The whole project was reviewed once by reading (`2026-11-17-milestone-10-verse-basics-final-review.md`: nothing Critical, five Important, nine Minor), fixed in one wave and re-reviewed once. What changed:

- *The assistant asked about a verse no longer on screen.* The selection the app remembers was not cleared when a chapter's text was replaced, so click a verse, →, ⇧⌘A asked about the previous chapter's verse. The reader now reports its selection once the new text is in.
- *Closing ⌘K could take the keyboard from the assistant's question box.* Every text field in a window types through one shared editor, and the reader compared that editor, not the field. It now remembers the field itself.
- *The reader's keys were live while the reader was typing elsewhere*, against section 2's anti-goal: for a moment after ⌘K opened, and after N when the note's editor was not yet in the window. **(call)** Every reader key (J, K, ⇧J, ⇧K and Esc included) now does nothing while ⌘K is showing or a note is being edited, and the key is swallowed. What it costs: a first character typed within about 50 ms of ⌘K is lost rather than typed into the palette. The note's editor also keeps a request for the keyboard made before it has a window and takes it when the window arrives.
- *The Notes window's list took the keyboard from its search field* when a search went from no results back to some. The list now takes the keyboard on appearing only when nothing is being searched.
- *The cut-off label*, as under Task 5. This replaces the ledger's earlier choice ("The same, from anywhere"), which typing "chapter" would not have found.
- *Held keys.* A held 1 to 9, 0, N or B acts once; J, K, ⇧J, ⇧K and the arrows still repeat. A held B had toggled the bookmark at key-repeat speed, saving each time.
- *A link names its book exactly.* **(call)** Section 7.1 accepts "a path `ReferenceParser` can read", and the parser guesses a book from the start of its name, so `bible://ma` opened Mark and "bible:is" typed in a note became a link to Isaiah. A link's book is now a book code or an exact name, short name or alias; the palette still guesses. **(call)** "Is" is Isaiah's own alias, so one more rule was needed: a link whose book is not a code, has one or two letters and names no chapter is not a link. What these cost: `bible://joh.3` opens nothing, and so does a two-letter alias alone (`bible://Jn`, `bible://Ps`, `bible://Mt`); `bible://jn.3.16`, `bible://is.53`, `bible://Romans` and `bible://John%203:16` still open.
- *Smaller.* The sheet's title takes `ink.primary`. The test that every menu chord is in the catalogue now fails on a shortcut written in a form it cannot read. New tests: a chapter opened before the reader has a window takes the keyboard once it has one; K's reveal runs upward; hostile text around a typed link makes no link. `DESIGN.json` gained the Mac reader's click, keys and focus rule.

**(call)** Left as they were: "Search the Notes browser" and "Export notes" stay under "Notes Column" (section 6 fixes the five groups; Matt may move them or rename the group); accent text on the wash stays at 4.33:1 in Light, for Matt to weigh. To `docs/BACKLOG.md`: the Mac reader's 1,360-line controller file, the key-scroll tests' reliance on wall-clock gaps, and the Notes window never having been measured with thousands of notes. The review's "Drop" list was accepted whole; each item is named there with its reason. Licence spelling: prose says "licence"; code names, file names, keys, UI copy and a licence's own name keep "license".

**The selection's fill, found by Matt** (2026-11-17, commit `6820403`). On the restarted Mac Debug app Matt clicked Psalm 1:1 and the selection's fill ran across the blank space to the right of each line's words, to the column's edge: "not acceptable". The cause: the Mac reader had never drawn its own selection, so the fill was the system's, which runs to the column's edges on every line whose line break is selected. Sections 5.1 and `DESIGN.md` chose "a verse is selected as ordinary text, so nothing new is drawn", which made that shape what every click shows; no review caught it, because the headless renders came from prose. The reader now fills a selection itself, behind its words only: on each line from the first selected glyph to the last, the line's full height, from the same per-line segments the stored highlights use. It holds for every selection (a click, the keys, a drag, Select All), fills only what is on screen, and is still an ordinary selection underneath. **(call)** The colour stays the system's selection colour, strong in the key window and quiet otherwise; Matt objected to the shape. **(call)** The system's own fill is hidden by drawing its selection view transparent, and that view is found by its private name (`_NSTextSelectionView`), because the two public ways failed (a clear selection background is ignored when the window is not key; hiding the view is undone by the system). What it costs: if a later macOS renames that view the full-width fill returns, visibly and harmlessly, and a pixel test fails by name. Reviewed once on its own and approved. Known and accepted: a selection of spaces alone shows no fill; the strong colour in a truly key window, the fill during a drag that scrolls, and a change of the system's highlight colour were not seen by anyone but Matt. **The iPhone had the same shape** (seen in the simulator: a tapped Psalm 1:3 filled to the column's right edge), and Matt asked for it to be fixed the same day (commits `cd96c81`, `f87fe47` and `d454185`; reviewed, then two fix rounds, each re-reviewed). The phone's reader now gives the system's selection display its own highlight view, which cuts each of the system's line rects to that line's words, from the same per-line segments the highlights use. This is public API only (`UITextSelectionDisplayInteraction`); the handles, the loupe, the menu and VoiceOver are the system's as before, and the colour is the tint at the system's selection strength. Its review found the phone's twin of the Mac's stale selection: the phone never cleared a selection when its text was replaced, so a selected verse could carry into another chapter reached by the switcher, a foot link, the thumb or a jump. **(call)** The phone now clears the selection, closes its menu and reports none when the new text differs from the old (another chapter, book or translation), and keeps it when the same text is laid out again (a text-size change). A page style that moves the chapter's text (Lectern, and any style on a book's first chapter, whose title block differs) moves the selection to the same words by verse and offset, as highlights move. The report goes out one turn after the screen's update, read at that moment, and forgets the selection without clearing an outline a jump has just set (`MarkupModel.forgetSelection`, used by the phone only). What it costs: switching translation with a verse selected loses the selection; a selection moved by a style change has no edit menu until it is tapped again. Seen in the simulator: a tapped Psalm 1:3, a wrapped prose verse, a dragged handle and a held word each fill to their words, and John 4 opens with nothing selected after John 3:36 was selected. Not seen by anyone: dark and Sepia, the loupe during a drag, a long selection scrolling, the chapter cards or the thumb with a verse selected, and any of it on a real phone.

**Matt's first look** (2026-11-17, on both Debug apps at `d454185`; commits `8fb93b8` to `aba8470`). Four things, each fixed the same day, reviewed, and fixed again where the review found more.

- *A tap or click away only deselects (both apps).* Matt: "if we have the selection menu pulled up on one and I tap somewhere, I don't want it to immediately highlight the next one." This overturns section 4's "a tap on another verse selects that verse instead" and section 5.1's "a click on another verse moves the selection". On the iPhone, while anything is selected, a tap outside it clears the selection, closes its menu and does nothing else, wherever it lands: another verse, a highlight, a margin mark, the chapter-note mark. The next tap acts as a tap does with nothing selected. **(call)** The rule is keyed on something being selected, not on the menu showing, since the menu hides and returns by itself during a scroll. A tap on the selected verse keeps it. On the Mac, with the menu open, a click anywhere else closes it and clears the selection, the anchor included; that click selects nothing.
- *The Mac's click opens the menu every time.* Asked what a plain click on a verse should do on the Mac, Matt chose the menu on every click over the quiet click of section 5.1 and over a floating bar that would need a mockup. He was told the cost: click a verse then press 1 no longer works, because the Mac's menu holds the keyboard while it is open. J, K, ⇧J and ⇧K still select quietly, and 1 to 9, 0, N and B act on that. **(call)** Esc closes the menu and keeps the selection, so click, Esc, 1 still works; a second Esc clears it. **(call)** With something selected and no menu open (after Esc, J or K), a click on another verse selects it and opens its menu directly. **(call)** The Mac's menu is modal, so the second click of a double-click arrives while the first click's menu is open; the reader treats a closing click with a click count of two as the double-click it is, selecting the word and opening its menu. What these cost if wrong: how the menu closed is read from what AppKit reports when the menu returns (a mouse-down or mouse-up stamped after it opened), which nothing but a live click can confirm; if AppKit reports neither, a click away reads as Esc (the verse stays selected) and a double-click selects the verse, not the word, and the floating bar becomes the fix. A triple-click reads as a click away.
- *Where the menu sits (both apps).* Matt, of the iPhone: "It should be consistently directly above or directly below. It should not be right in the middle of all the words." The cause on the iPhone: the reader's own menu (a tapped verse, a slow second tap, an opened highlight) was given the first selected line only, with the side left to the system, which could put it under that line across the rest of the verse. It is now given the selection's whole on-screen bounds and a side: above the first line when there is room under the bar, else below the last. The Mac's menu had the same fault (it opened under the selection's first line) and now opens below the selection's last visible line, else above its first. **(call)** Where neither has room, or the menu would open under the pointer, the Mac's menu opens beside the click, so a double-click's second click can never choose an item by accident. Known and accepted: the iPhone's room for the menu is one measured figure, not the menu's real height; in landscape a selection taller than the page may still get the menu over it; the system's own menu (a held word, dragged handles) and the reader's are placed by different code and agree in every picture taken; in a Mac window too narrow for the menu beside the click, AppKit may still move it over the pointer.
- *The Mac's drag showed nothing until the mouse was released.* A regression from the reader's own fill (`6820403`): during a drag the system sets the selection without posting the notice the fill was listening for, and its own fill was hidden. The reader now refills on every change of the selection while the mouse is down.

Seen in the simulator: the menu above or below the selection, clear of its words, for a tapped verse of poetry, a long prose verse, a verse just under the bar, one near the bottom, dragged handles and a held word; a tap on another verse with one selected leaves nothing selected and the next tap selects it; with John 15:7 selected a tap on 15:13's note mark only clears the selection. Not seen by anyone but Matt: every Mac item here (a menu cannot be rendered or clicked headlessly), a selection taller than the screen on the phone, and the phone in landscape.

Known and accepted after the wave: the keys stay dead for as long as a note's edit is open (a click back into the text ends it after 200 ms); the remembered selection is reported after every replacement of the text, a text-size change included; the Notes window's search-field fix has no test (SwiftUI focus), only the by-hand check.

**Tests.** Package suite `swift test --package-path Packages/ScriptureKit`: 817 tests in 65 suites passed (the other products' runs of 111, 52, 33 and 17 tests passed too). iOS `ScriptureUITests`: 763 tests in 62 suites passed. The Mac Debug and iOS Debug builds succeeded. The CoreData "database is corrupted" lines in both logs come from a test that feeds a corrupt store on purpose. One timing benchmark (`ReaderBenchmarkTests.scrollingWhileTheThumbRevealsKeepsTheFrameCost`) failed once under full-suite load in Task 1 and passed alone; it did not fail in the final runs. After the fix wave, on `f487178`, run by the implementer and again by the controller: the package suite's 824 tests in 66 suites passed (and 111, 52, 34 and 17 in the other products); iOS `ScriptureUITests`, 764 tests in 62 suites, passed; both Debug builds succeeded; the Mac Debug app was restarted on that build. After the selection's fill, on `6820403`: the package suite's 832 tests in 67 suites passed in the controller's run (in the implementer's run one timing benchmark, `scrollingTheWholeReaderCostsAboutWhatItsTextDoes`, failed once under full-suite load and passed alone); iOS `ScriptureUITests`, 764, passed; both Debug builds succeeded; the Mac Debug app was restarted on it. After the phone's fill and its two fix rounds, on `d454185`, in the controller's run: the package suite's 833 tests in 67 suites passed (and 111, 52, 34 and 17); iOS `ScriptureUITests`, 778 tests in 63 suites, passed; both Debug builds succeeded; the Mac Debug app was restarted on it. The iPhone's Debug app was installed from `d454185` the same day, on Matt's word; nothing was tried on the phone by anyone but him. After Matt's first look, on `aba8470`, in the controller's run: the package suite's 851 tests in 67 suites passed (and 111, 52, 34 and 17); iOS `ScriptureUITests`, 797 tests in 64 suites, passed; both Debug builds succeeded; the Mac Debug app was restarted and the iPhone's Debug app reinstalled from it. Matt used both and said, the same day, "This is good to go now"; he did not say which items of section 12 he tried.

**Seen by eye, and how.**
- iPhone simulator (iPhone 18 Pro Max, Debug build, in Sepia): a tapped verse selected whole with its handles and menu (John 3:26), and Copy Link behind the chevron; Settings with About last; About with the holybooks licence disclosed and re-wrapped; a passage link opened while Settings was showing, which closed Settings and showed John 3:16. Nothing that writes was chosen.
- Mac, by headless render only (an offscreen `NSHostingView` written to PNG, light and dark; restarting the Mac Debug app is the controller's step, and the real Settings window and the sheet in the real window were not driven, so the Mac's new surfaces were seen as headless renders only): the shortcuts sheet, the About view, the Notes window's rows with the first selected, and a licence disclosure (rendered as a copy of the row's expanded disclosure, because the row's own state is private). Matt checked the Notes window by hand in the real app.

**Not checked.** For Matt's list; nobody has seen these:
- Every fix in the final review's wave, in the running app: they were tested and read, not watched. Section 12's last item lists what to try. Two of them (the keyboard after ⌘K › Ask the Assistant, and the first letters typed after ⌘K or N) are matters of timing that reading could not settle.
- Control-click on a verse in the Mac reader (the final review could not judge it without the app).
- A passage link arriving while the Notes window is in front, or while the main window is closed.
- Copy Link pasted into another app, on either platform.
- The shortcuts sheet opened from ⌘K, and ⌘/ pressed while ⌘K is open.
- Focus returning to the reader after a note is finished: built and tested at the rule level, but not watched in the app (it cannot be tried in the Debug store).
- A slow second tap in the middle of a long selected verse, on a real phone.
- A tap that stops a moving scroll, on a real phone.
- VoiceOver on every new surface.
- Sepia on the Mac's new surfaces.
- The real Mac Settings window's About tab, and the phone's About in dark and at large Dynamic Type.

## Appendix: the credit lines

Read on each holder's own page or licence file on 2026-11-16 unless marked. "Line" is what About shows; a holder's own wording is in quotation marks.

| Source | Used for | Line | Licence | Link |
|---|---|---|---|---|
| English Standard Version | Bible text | ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway, a publishing ministry of Good News Publishers. All rights reserved. "ESV" and "English Standard Version" are registered trademarks of Crossway. | Copyright | crossway.org/permissions |
| New American Standard Bible (1995) | Bible text | New American Standard Bible®, Copyright © 1960, 1971, 1977, 1995 by The Lockman Foundation. All rights reserved. www.Lockman.org (a live link, as Lockman asks of apps) | Copyright | lockman.org |
| Amplified Bible, Classic Edition | Bible text (the file labelled AMP) | Amplified® Bible Classic (AMPC), Copyright © 1954, 1958, 1962, 1964, 1965, 1987 by The Lockman Foundation. www.Lockman.org (a live link) | Copyright | lockman.org |
| Easy-to-Read Version | Bible text (ERV) | HOLY BIBLE: EASY-TO-READ VERSION © Bible League International. (Year not verified: the holder's page says 2014, eBible's copy of the earlier text 2006.) | Copyright | bibleleague.org/license-agreement |
| American Standard Version (1901) | Bible text | Public domain. | Public domain | ebible.org/eng-asv |
| King James Version | Bible text, its book titles | Public domain (Crown rights apply in the United Kingdom). Titles from the text "courtesy of the Crosswire Bible Society and eBible.org". | Public domain | ebible.org/eng-kjv |
| World English Bible | Bible text | Public domain. "World English Bible" is a trademark of eBible.org. | Public domain | ebible.org/eng-web |
| Catholic Public Domain Version | Bible text | Original Edition. Ronald L. Conte Jr., translator and editor. Public domain. | Public domain | sacredbible.org |
| Berean Standard Bible | Section headings | "The Holy Bible, Berean Standard Bible, BSB is produced in cooperation with Bible Hub, Discovery Bible, OpenBible.com, and the Berean Bible Translation Committee. This text of God's Word has been dedicated to the public domain." | Public domain since 2023-04-30 | berean.bible/terms.htm |
| bobuk/holybooks | The texts' file layout | "Copyright (c) 2016, Grigory Bakunov. All rights reserved." with the BSD conditions and disclaimer, shown in full | BSD 3-Clause | github.com/bobuk/holybooks |
| Literata | Reading typeface | "Copyright 2017 The Literata Project Authors (https://github.com/googlefonts/literata)", with the licence text | SIL OFL 1.1 | github.com/googlefonts/literata |
| Source Serif 4 | Reading typeface | "Copyright 2014 - 2023 Adobe (http://www.adobe.com/), with Reserved Font Name ‘Source’. All Rights Reserved. Source is a trademark of Adobe in the United States and/or other countries.", with the licence text | SIL OFL 1.1 | github.com/adobe-fonts/source-serif |
| 3dicons | The app icon's artwork | Icon artwork from 3dicons by Vijay Verma. (No credit is required; Matt asked for it. The free library is CC0; no licence statement was found for its online editor's exports, so how the icon was made there is Matt's to confirm.) | CC0 | 3dicons.co |
| BibleProject | Links to its book overview videos | Videos by BibleProject, at bibleproject.com. (Their terms ask for a notice naming BibleProject as author and owner with a link to the site; the name is one word, no "the". No logo is used.) | Linking permitted on those conditions | bibleproject.com/terms |
| GRDB.swift | Reading the Bible database | "Copyright (C) 2015-2025 Gwendal Roué", with the MIT permission notice | MIT | github.com/groue/GRDB.swift |

Ready for later projects: OpenBible.info cross-references (CC BY 4.0: credit, a licence link, a note of changes); Theographic Bible Metadata by Robert Rouse (CC BY-SA 4.0: the same, its listed sources credited, and the app's converted tables shared under the same licence); Easton's Bible Dictionary, M. G. Easton, 1897 (public domain).
