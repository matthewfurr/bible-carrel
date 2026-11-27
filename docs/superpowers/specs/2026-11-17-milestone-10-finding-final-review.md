# Final review: milestone 10, project 2, "finding"

Range `8d80ac5..1bfe234` (code), read on 2026-11-17 beside the docs task (`a02e680`, documents only, not reviewed).
By reading only. No suite, build, app or simulator was run. Three read-only `sqlite3 -readonly` queries were made against `Build/bible.sqlite` to settle the row-id ranges and two word-list facts; nothing was written.

Read in full: the spec, the plan, the ledger, `PRODUCT.md`, the 275 KB diff (in eight passes), `SUI/Phone/PhoneSearchScreen.swift`.
Read in part, where a hunk's context was not enough: `SUI/NavigationModel.swift` (395-505, 826-965), `MAC/MainWindowView.swift` (95-423, 470-488), `MAC/ReadingThroughScriptureApp.swift` (60-344), `SUI/CommandPaletteView.swift` (296-455), `SUI/PageFace.swift` (36-160), `Apps/Shared/AppModels.swift`, `SUI/PreferenceSync.swift` (60-170), `SUI/Phone/PhoneRootView.swift` (50-172), `SUI/Phone/PhoneReaderScreen.swift` (360-390, 478-540), `Scripts/ensure-bible.sh`, the Mac project's "Bundle Bible database" phase, and DESIGN.md's section 5 palette lines (only to cite the group order).

## 1. Verdict

**With fixes.** The search, the index, the recents and the model's staleness rule are sound and well pinned, and nothing here can touch Matt's notes or the synced store by accident of design. Three things should be fixed before he tries it: one path that can exhaust memory on a pasted passage (C1), one state leak that makes Recent vanish from the empty palette (I1), and one ordering consequence of 32 commands that makes Return on an ordinary search word run a command (I2, which needs a ruling first); and the suites, both builds and the post-fix live looks that are still owed must be done.

## 2. Strengths

- **One reading of the query, and it is injection-proof by construction.** `SD/SearchQuery.swift:36-46` builds the MATCH string only from folded tokens it cut itself, inside quotes it writes itself; the reader's text never reaches SQL except as that bound parameter (`SD/BibleStore.swift:171-186`), and the only interpolated names pass `BibleSchema.name` (`SD/BibleSchema.swift:64-78`, ASCII letters and digits). I found no text a reader can type that throws or reaches SQL any other way; a failure inside FTS5 is caught in `NavigationModel.answer` (`SUI/NavigationModel.swift:671-683`) and reads as no matches.
- **The row-id ranges are right in the real database.** Read-only check of `Build/bible.sqlite` at schema 3: all 550 `translation_book` rows have `first_verse_id`/`last_verse_id` equal to their verses' min/max with no gap; in all eight translations OT, NT and (CPDV, WEB) the Apocrypha are each one unbroken run, in that order, 1 to 259,393 with nothing between. A missing translation, a missing table and a scope with no book each return `.empty` (`BibleStore.swift:149-168`), never an error.
- **Staleness is decided by comparing what was asked with what would be asked now** (`NavigationModel.swift:637-647`), not by a counter. It is correct for a changed query, scope, order, translation and limit at once, it makes a cleared field and a chosen row drop the outstanding answer for free, and returning `Bool` is what let the phone's `rankedQuery` defect be fixed properly (`PhoneSearchScreen.swift:378-380`).
- **The reader's keys cannot come back wrong.** `ReaderKeyCommands.keysAreLive` is `!navigation.isPaletteShown && …` (`SUI/ReaderKeyCommands.swift:11-12`), and every close route I could find sets that one flag (a row, `escapePalette`, the click outside, ⌘K, ⌘/, a passage link, every command). There is no second flag to forget.
- **Recents are careful where it matters.** The non-recording path is a real split (`openWithoutRecording`, `NavigationModel.swift:276-296`), so Next, Previous, `turn`, Back, Forward, restore and adopt cannot record by accident; a damaged or foreign list decodes to empty and is rewritten (`SUI/Recents.swift:122-125`); the store takes only a `UserDefaults`, `recents` is not in `SyncedPreferences.keys` (`SUI/PreferenceSync.swift:75-92`), and a test pins both. I walked every caller of `open`, `lookUp`, `turn`, `MarkupNavigation.show` and `openPassageLink` in both apps against the plan's table: they agree (one judgement call, the phone's chapter switcher, is in section 7).
- **The Esc guard** (`SUI/CommandPaletteView.swift:258-266`) solves the two-route problem at the event, so a single press can never go back and close; and the implementer's catch that every row and keycap was casting the panel's shadow (now on the shape alone, `CommandPaletteView.swift:205-214`) is exactly the kind of thing a render exists to find.
- **Commands are a pure list over a value** (`PaletteCommand.isAvailable(in:)`, `SUI/PaletteItem.swift`), their keys read from the catalogue with a test that fails on any row or chord that does not exist. I checked all 32 against the menu item or toolbar button: every app-run command calls the same function its menu item calls, and none is offered in a state where its menu item is disabled (Home, Text & Layout and the notes column are stricter than their menus, which is the recorded call).
- **The build picks the database up.** The script phase is `alwaysOutOfDate`, runs `ensure-bible.sh` (which reads the version from the source) and copies when the built file is newer, in both app projects; a schema-2 file is refused at launch with a plain sentence on both apps (`AppModels.startupMessage`), not a crash.
- **Test hygiene.** Scratch `UserDefaults` suites removed in `deinit` (`NavigationModelTests`, `RecentsTests`), fixed dates and a fixed calendar for the subtitles, an actor `Gate` instead of sleeps, nothing on the real clipboard or network.

## 3. Issues

### Critical

**C1. "Did you mean" builds every combination of candidates: a pasted passage with many unfamiliar words can exhaust memory.**
`SD/SpellingSuggester.swift:92-100`. Each unknown word takes up to three candidates and the loop at `:95` materialises the full product before sorting and cutting to five: 3^U arrays, each as long as the query. As built records this as a call ("at most 3 to the power of the number of misspelled words, fine for typed queries"). It is not fine for the plan's own Review Focus 4, a pasted passage. Nothing caps the terms: `suggestion(for:)` is reached whenever Scripture finds nothing, the text has no quotation mark, no exclusion, no word with an inner apostrophe, hyphen or colon, and it is not a reference.
Reach: paste several verses copied from another translation with no verse numbers. Checked against the real ESV word list: `thee`, `saith`, `shalt`, `verily`, `maketh`, `leadeth` (and every `-eth` verb) are unknown and each has near neighbours, and the KJV has no quotation marks. John 15:1-8 in KJV pasted while reading ESV has about nine such words (about 20,000 combinations of about 180 integers: slow, survivable). Fifteen is 14 million arrays; twenty is 3.5 billion. The same holds the other way (modern verbs pasted while reading KJV), and for one misspelt word repeated. It runs off the main actor and is not cancellable, so the window stays live while memory climbs until the system kills the app: on the iPhone, quickly. A note being edited in the column at that moment may be lost with it.
Fix: generate the combinations in order of their sum and stop at `limit` (the tested order is kept exactly), and offer nothing when the query has more terms than a misspelling plausibly has (say twelve). Test to add, which today would not return: `queries(for: SearchQuery(Array(repeating: "frut", count: 30).joined(separator: " ")), in: list).count <= 5`.

### Important

**I1. A chosen Commands chip survives an emptied field, and Recent disappears from the empty palette.**
`NavigationModel.swift:710-713` clears the chip only when its kinds are absent from the new results; `:77-83` (the query's `didSet`) resets the scope but not the chip. The empty state has a Commands group (`SearchRanker.swift:73-81`), `SearchChip.commands` covers it, so the chip is kept, `paletteItems` (`:86`) and the view's `results` show the Commands group alone, and the chip row is hidden with nothing typed (`CommandPaletteView.swift:52-54`), so nothing on screen says why and Tab cannot undo it. Two routes: type `page`, Tab to Commands, delete the text; or type `sw`, choose the Commands chip, run Switch Translation…, press Esc. Either way ⌘K "with nothing typed" shows six commands and no Recent until it is closed and reopened. Matt's list has "Tab through the chips", and Commands is the last stop.
The plan's rule ("the chip returns to nil when the palette opens and when its groups are absent") is itself what is wrong: it did not foresee an empty state that has a group. Fix: in `paletteQuery`'s `didSet`, when the trimmed text is empty, also `if paletteChip != nil { paletteChip = nil }`. Tests: the two routes above (the second is the ledger's untested "Switch Translation… run with a chip chosen").

**I2. A one-word search that is also a word of a command's title puts the command first, and Return runs it.**
`SearchRanker.swift:49-67` orders a word query Books, Translations, Commands, Your notes, Asked, Scripture (as DESIGN.md has had it since there were four commands); `PaletteRanker.swift:52-58` matches a command when each typed word starts any word of its title; the selection starts on the first row (`CommandPaletteView.swift:227`) and Return takes it (`:136`). With 32 commands the titles now hold many Bible words. Typed alone, then Return: `light` switches the appearance to Light; `dark` (on the way to "darkness") to Dark; `study` sets the Study page style, which is a synced preference (`PreferenceSync.swift:79`) and so follows him to the phone; `hide` hides the notes column; `home` and `back` navigate; `clear` empties the recents; `add`, when the assistant has an unsaved reply, writes a note; `this`, `to` or `link` replace the clipboard. The foot does say "↩ Run", so it is not silent, but the first goal of the spec is that a reader finds a verse from its words, and here the palette closes, the query is cleared and something else has happened. Two-word searches are safe (both words must start words of one title).
This is the old order meeting Task 7's commands; no task could see it. It needs a ruling because spec 5.5 keeps the order. Recommended: in a word query, when Scripture or the reader's own marks matched, the Commands group goes after Scripture (commands stay first when nothing else matched, as for `page` or `export`, and one Tab away otherwise). A narrower alternative: a one-word query matches a command only by the first word of its title. Either is a few lines in `SearchRanker.results` or `PaletteRanker.rank` plus the tests and one sentence of DESIGN.md.

**I3. On the Mac the matched words are not bold in verse and quote text (live finding L5).**
`CommandPaletteView.swift:446-447` and `:390-391` put the bold intent on `Font.custom("Literata-Regular")`; the package ships Literata Light, Regular, Medium and Italic only (`SUI/PageFace.swift:138-142`), so in Printed, the default, nothing changes weight. Spec 5.5 keeps "the bolded matches" and the first thing on Matt's list is `remain fruit`, where the bold words are how he sees why a verse matched; with word starts and any-order matching they matter more than they did. It predates this project and As built hands it to Matt, which is the right owner, but it should be told to him as the first thing he will notice, not found by him. My recommendation: bundle Literata SemiBold and SemiBold Italic and map `weight >= .semibold` to them (Medium against Regular will not read at `.callout`); a stopgap in code alone cannot fix the italic quote.

**I4. The scope menu cannot be reached from the keyboard on the Mac (the cost of the Tab ruling).**
`CommandPaletteView.swift:236-243` now handles every Tab unless VoiceOver is on, so first responder never leaves the field; nothing else opens or changes the scope. PRODUCT.md principle 4 is "Everything reachable from the keyboard", the palette is the keyboard's own surface, and "Limit a search to the New Testament, then to one book" is item 3 of Matt's list. The ruling was right in what it gave (section 6) and incomplete in what it took. Not for the fix wave unless the controller wants it: it needs a key chosen. Cheapest path I see: a second key in the same handler (for example ⌥⇥) that steps `searchScope` through `SearchScope.sections(in:)` and This Book, with a foot hint while the scope menu shows; a pure `next` function makes it testable. A single book would still need the pointer.

### Minor

**M1. Two ways to hold a scope the translation lacks.** `NavigationModel.swift:824-828`: a recent search sets its stored scope without the check `setTranslation` makes (`:524`), so "Apocrypha" or "Tobit" chosen while reading ESV searches nothing, shows No matches under an "Apocrypha" capsule that the menu does not list, and is recorded again with its count gone. On the phone, a lookup that switches translation (`switchTranslation(toStored:)`, `:922`) leaves the search tab's scope behind the same way. This is the plan's Review Focus 2 with a hole in it. Fix: one `private func scopeFits()` used in all three places; fall back to `.wholeBible`.

**M2. The query survives Esc and a click outside; the scope and the chip do not.** `escapePalette` (`:616-623`) and the overlay's tap close without clearing `paletteQuery` (as before this project), while opening resets scope and chip (`:90-97`). So ⌘K after an Esc shows the old words, widened to the whole Bible at All, not Recent; and that reopening search runs on the main actor (`MainWindowView.swift:145-147`, the ledger's Task 5 minor). Either clear the query on every close or keep all three; Matt's to choose.

**M3. On the front page, Recent leaves out the chapter last read.** `NavigationModel.swift:697` passes `location`, which `goHome` keeps (`:462-467`). After Home, the one place he most likely wants is the one row missing. `openChapter: screen == .reader ? location : nil`.

**M4. Right after a search, the top of Recent is the verse on screen and the search just run.** `Recents.swift:143-150` leaves out only a `.chapter` equal to the open one; a `.lookup` in the chapter that is showing is listed first. Consider leaving out a lookup whose chapter is open while it is the lookup showing.

**M5. "Ask the Assistant" hides the assistant when it is showing.** `ReadingThroughScriptureApp.swift:178-185` toggles; the row's title is fixed (`PaletteItem.swift`, `.toggleAssistant`). The toolbar's help and the menu change their words with the state; the palette's row, now one of the six suggested, does not. Older than this project, more visible now. Needs one field in `PaletteState` and a second title, or leave the row out while the panel shows.

**M6. "Did you mean" outranks the reader's own notes.** `SearchRanker.swift:37`. A word that is in his notes and not in the Bible gets a suggestion first: `sermon` is not in ESV and `hermon` is one letter away, so Return on `sermon` searches Hermon instead of opening the first note. The spec says "at the top", so this is to spec; I would put the row after the reader's own marks when any matched, or not offer it then.

**M7. One serial database queue.** `BibleStore.swift:23` is a `DatabaseQueue`, so a chapter load, a book load or a passage link's check on the main actor waits for an off-main search in progress (tens of milliseconds; longer behind a one-letter word, the phone's 500-verse Show all, or C1's five count queries). Typing itself never reads the database, so spec 4.5 holds. A read-only `DatabasePool` would remove it. Backlog.

**M8. Arrow presses made straight after Tab are undone.** `CommandPaletteView.swift:227`: the chip's refresh (120 ms, then the search) changes the results and the selection returns to the first row. The ledger says "within about 120 ms"; it is 120 ms plus the search, and Tab then ↓ is what a keyboard reader does. Keep the selection on the same row id when it is still present, or skip the pause when only the chip changed.

**M9. A row clicked from results older than the text records the newer text.** `NavigationModel.swift:803-808` reads `paletteQuery` and the shown count; a verse clicked within the debounce of more typing records the new words with the old count. Return re-ranks first, so only the pointer does this. Record from the ranked key's query instead.

**M10. Tests.**
- Now tautologies, since `paletteItems` is computed from `paletteResults`: both `paletteItems == paletteResults.flatItems` lines of `paletteItemsAreTheGroupedResultsInOrder`, and the second and third expectations of `theRowsMovedOverAreTheShownOnesTheMomentAChipChanges` (the ledger named one).
- `returnsWordFollowsTheRowAndTabIsTheSystemsWhenItMustBe` now asserts that Keyboard navigation does not make Tab the system's; the name says the opposite, and `tabStepsChips` ignores a parameter.
- `theBuildScriptsPatternReadsTheSchemaVersion` checks a Swift regex, not the script's `sed`, and pins `== 3`, so it must be edited at the next schema and still proves nothing about the script. The by-hand run in the ledger is what actually pins "rebuilds an old database".
- `recentsStayOnTheDevice` writes to a scratch domain that `PreferenceSyncTests` never removes (that suite's helper clears before use only, unlike the other two suites).
- `aNewerKeystrokeAbandonsAnOlderSearchsResult` hangs, rather than fails, if the held request never arrives.
- The benchmark is wall-clock by nature (six times under budget; it can still fail on a busy machine).
- Nothing tests: Tab, Esc or the list's height (view code); the phone screen's task logic; I1's two routes; M1; C1's many-word case; staleness for scope, chip or translation (I walked those by reading, section 4).

**M11. The Mac shows "All" and "Scripture n" chips when Scripture is the only kind**, because the scope menu forces the row (`CommandPaletteView.swift:52-54`). They differ only in how many rows show. Harmless; the row could carry the scope menu alone then.

## 4. The walked sequences

State is `NavigationModel`'s. "Key" is `paletteSearchKey`; "ranked" is `rankedSearchKey`.

**1. Open ⌘K, type, Tab to a chip, change scope, choose a verse, reopen.**
- Open: `isPaletteShown` true; its `didSet` sets scope Whole Bible, chip nil. The window's `onChange` runs `updatePalette()`: results are the empty state (Recent, Commands), ranked == key.
- Type `remain fruit`: key changes per keystroke; 120 ms after the last one `refreshPalette` asks (query, ESV, whole, best match, limit 8, suggests) off the main actor and shows it. Results: Scripture. The chip row shows because the scope menu does.
- Tab: chip `.scripture`; `paletteItems` is at once the shown rows; key changes (chip, limits); the refresh brings up to 50 rows and the selection returns to the first (M8).
- Scope New Testament from the menu: `searchScope` set; the field is refocused; refresh; the count changes; the chip stays.
- Return on a verse: `submitPalette` finds ranked == key, `select(.verse)`: records `.search("remain fruit", NT, count)`, looks the verse up (the place being read is kept as `lookupReturn`), records `.lookup`. Then `isPaletteShown` false, query "", which resets the scope, results empty. The chip is left at `.scripture` until the next open. The reader is asked to take the keyboard.
- Reopen: scope whole, chip nil, empty state. Recent's first two rows are the verse on screen and the search (M4).
- Nothing goes wrong. One thing only a live window settles: `select` resets the scope in the same turn as the close, which fires the panel's `onChange(of: searchScope)` and its `isFieldFocused = true` while the panel fades. By reading it is a no-op (the field still has focus then) and the reader gets the keyboard; if J or → is dead after this exact sequence, that is where to look.

**2. Switch Translation… with a chip chosen and a scope narrowed.**
- Before: query `sw`, scope NT, chip `.commands`.
- `select(.command(.switchTranslation))`: query "" (scope back to whole by the `didSet`), `isChoosingTranslation` true, `updatePalette()`: results are the Translations group alone; the chip is kept because `.commands` covers translations; ranked == key. The palette stays open; the foot says "esc Back"; Tab does nothing.
- Choose a translation: `setTranslation`, close, all clear. Correct.
- Esc instead: `isChoosingTranslation` false, `updatePalette()`: empty state, **chip still `.commands`, so Recent is hidden** (I1). A second Esc closes.
- With chip `.scripture` instead, the first `showPalette` clears the chip and ranks again: correct.

**3. A recent search whose scope the current translation lacks.**
- `choose(.search("verse", .apocrypha, 2))` while reading ESV: query set, scope `.apocrypha`, `updatePalette()`: the store finds no book in the scope and returns empty; no suggestion (every word is known). Results hold whatever else matched, with no Scripture; `showsScopeMenu` is true because the scope is narrowed, so the capsule reads "Apocrypha" and its menu has no such entry. `recordSearch()` records it again with a count of 0, so the row loses "· 2 verses". The palette stays open. Wrong at the scope (M1).

**4. A suggestion chosen while a search is still out.**
- Results show "Did you mean fruit?" for `frut`; the reader changes the scope (a refresh R2 goes out) and presses Return.
- `submitPalette`: ranked != key, so `updatePalette()` ranks `frut` at the new scope on the main actor and takes row 0. If that is the suggestion: query `fruit`, `updatePalette()` again, palette open, ranked == key.
- R2 returns: its request (`frut`) is not what would be asked now (`fruit`): dropped, and its task was cancelled besides. The keyed task for the new key waits 120 ms and searches `fruit` once more; the results are equal, so the selection does not move. Correct; one search more than needed.

**5. The field cleared while a search is out.**
- Query "": scope whole (and, today, the chip kept: I1 if it was Commands). The outstanding refresh is cancelled and its request no longer matches nil: dropped.
- For 120 ms the old rows stay under the empty field (the chips hide at once); then `refreshPalette` with no request shows the empty state without touching the database. Return inside that window re-ranks first and takes the empty state's first row. Correct.

**6. The palette closed while a search is out, and reopened at once.**
- Esc: `isPaletteShown` false; the query is kept (M2); the key is unchanged, so the refresh is not cancelled and its answer is applied to the closed palette. Harmless.
- Reopen: scope whole, chip nil; if either changed, the key changes and an answer still out is dropped; `updatePalette()` searches the kept query on the main actor (twice if a chip had to be cleared), then the keyed task repeats it off the main actor. Correct results; the old words are showing, not Recent, and one search ran on the main actor.

Also walked, all correct: a row chosen from the phone while a refresh is out; Show all and a scope change on the phone (limits kept because `rankedQuery` is unchanged); Clear on the phone; a translation switched from the toolbar with the palette open; a passage link arriving with the palette open (closes it, records a lookup).

## 5. Triage of the ledger

**Deferred minors**

| Item | Call | Reason |
|---|---|---|
| T1: `-` after a closing quote excludes the next term | Drop | What a reader typing `"living water"-fear` means. |
| T1: private-use scalars are token characters | Drop | It matches the index: `unicode61` treats them as token characters too. |
| T1: untested corners of `matches`, `matchRanges`, `allowsSuggestion` | Backlog | Tests only. |
| T1: `parse` is dense | Drop | It is 35 lines and read once. |
| T2: the scope query's join does nothing | Backlog | Tidy with the next item. |
| T2: `f.rowid` made by `replacingOccurrences` | Backlog | Works; fragile to a rename. |
| T2: garbled comment about "fifth" | Backlog | No effect on the reader. |
| T2: `createSearchIndex` doc note | Drop | One caller. |
| T3: `words(in:)` may read twice | Drop | Same answer, by design. |
| T3: known-word check scans the list | Backlog | Off the main actor; fold into C1's rewrite if convenient. |
| T3: digit check is ASCII only | Drop | The text is English. |
| T4: `matchRanges` doc comment | Drop | |
| T4: `marksTakePhrasesAndExclusions` never seen red | Drop | Its phrase and exclusion lines could not pass on the old matcher. |
| T5: `paletteItems` stored | Drop | Closed in Task 8 (computed). |
| T5: clearing an absent chip searches twice | Backlog | Costs one extra 120 ms on that keystroke. |
| T5: reopening with a query, and a suggestion, search on the main actor | Backlog | Goes away for reopening if M2 is ruled "clear on close". |
| T5: staleness tested for a query only | Backlog | Walked by reading here; tests would be better. |
| T6: `termsKey` same for every no-term query | Drop | Unreachable: such a search has no row to open. |
| T6: `select` blanks the results after closing | Backlog | Both apps refresh on showing. |
| T6: three untested recents cases | Backlog | Tests only. |
| T6: `choose(.chapter)` switches translation before `open` | Backlog | As `open(_:verse:translationID:)` always did. |
| T7: Export Notes… and Notes Browser always offered | Drop | Their models exist whenever the palette does. |
| T7: `paletteState` is a snapshot | Backlog | Stale for one keystroke. |
| T7: untested: state merge, `escapePalette` and the key, Switch Translation… with a chip | **Fix now** (the third) | It is I1. The other two: backlog. |
| T8: foot reads the settings unobserved | Drop | |
| T8: "Scripture 0" chip | Backlog | Shows only when another kind also matched a misspelling; Matt is unlikely to meet it on his list. One line when someone is in `SearchResults.chips`. |
| T8: `spokenShortcut` two-chord test | Backlog | |
| T8: a line restating a definition | Backlog | With M10's others. |
| T8: selection reset after a chip change | Backlog | See M8: wider than recorded; tell Matt before "Tab through the chips". |
| T8: 420 pt for one frame | Backlog | For the live look. |
| T8: nothing guards the height or the Esc guard by test | Backlog | View code; a live look is the guard. |
| T8: `tabStepsChips` ignores a parameter | Backlog | And rename the test (M10). |
| T8: scope menu has no keyboard path | **Raised to I4** | PRODUCT.md principle 4. |
| T9: Clear is under 44 pt and reads "Clear" | Backlog | Cheap, but the header's height needs an eye; give it `accessibilityLabel("Clear Recents")` with whatever else touches the file. |
| T9: `rankedQuery` lags after a suggestion or recent search | Backlog | 150 ms of late bolding. |
| T9: indentation in `PhoneNotesScreen` | Drop | |
| T9: Clear is semibold | Drop | It takes the header's weight; consistent. |
| T9: Show all and a translation switch search twice | Backlog | |
| T9: separator above the lone "Did you mean" row | Backlog | For Matt's eye. |

**⚠️ items**

| Item | Call | Reason |
|---|---|---|
| T2: eight tables, the size, the second `ensure-bible` run, `runs.count == 4` | Drop | Settled by the controller; I re-checked the real database (550 of 550 ranges whole). |
| T3, T4: test results rest on the implementers' runs | **Fix now** | The controller's own full run settles them. |
| T5: how the suggestion group looks | Drop | No header on either app, by the code; the phone's separator is above. |
| T6: the Mac refreshes on open; the phone on showing; the untested Mac call sites | Drop | Read: `MainWindowView.swift:145-147`, `PhoneSearchScreen.swift:48-55`, and all four `recordLookup` sites. |
| T7: a page style and an appearance repaint; Text & Layout shows once the palette has closed; Export Notes… attaches its panel; Copy Link's three types | **Fix now** (drive them) | Text & Layout and Export are the two with a real timing risk: each opens something in the same turn the palette closes and the reader asks for the keyboard. |
| T8 (5): a toolbar click does not close the palette | Backlog | Confirmed by reading: the clear layer covers the window's content, not its toolbar, as the scrim did. Tell Matt. |
| T8: live checks owed after the fix round | **Fix now** (drive them) | Nobody has seen the palette since `1492d25`. |
| T9: the Notes tab's label is a faithful move | **Fix now** (look) | One screenshot. |
| T9: `PhoneMenuLabel`'s label is a `String` | Drop | English only. |
| T9: large Dynamic Type; "No matches" with the scope row; a recent conversation | Matt's list | Not drivable without making a conversation. |
| T9: the fix round's report has no fix section | **Fix now** | The full runs. |

**Live findings**

| Item | Call | Reason |
|---|---|---|
| L3: the list held 420 pt | **Fix now** (verify) | Fixed in code by measurement (`CommandPaletteView.swift:172-177`); unseen. Look for a short list growing in two steps: the lazy stack estimates rows it has not built. |
| L4: Tab under Keyboard navigation | **Fix now** (verify) | Ruled and coded; unseen. Whether `onKeyPress` gets Tab before the field editor is exactly what reading cannot tell. |
| L5: no bold in Literata | I3 | Matt's to rule; tell him first. |
| Not driven: click outside, scope menu, a chip chosen, did you mean, Switch Translation… and its Esc | **Fix now** (drive them) | All are on the plan's own Step 6 list. |

**Fix before Matt tries it**, in the order one fixer should take them:

1. **C1**: bound `SpellingSuggester.queries` (sum-ordered generation, a term cap) with the many-word test.
2. **I1**: clear the chip when the field empties; tests for both routes.
3. **M1** and **M3**, while in the same file: the scope fallback in `choose(.search)` (and after `switchTranslation(toStored:)`), and `openChapter` only while the reader shows. Three small edits with a test each.
4. **I2**, after the controller rules on the order (or asks Matt): Commands below Scripture in a word query when Scripture or his marks matched; update `SearchRankerTests` and DESIGN.md's sentence.
5. Run the package suite, the iOS suite and both Debug builds. None has been run in full since the Task 8 and Task 9 fix rounds, and the Mac was not built at Task 9.
6. Relaunch the Mac Debug app once and work the "controller" list in section 7.

Not in the wave, to be told to Matt before he starts: **I3** (bold), **I4** (scope by keyboard), **M2** (the query on close).

## 6. Rulings

1. **The handover's rules override the plan's live steps; implementers render offscreen, the controller relaunches once.** Same. Its cost was real once (L3: a render that hugs its content cannot show a list that does not) and is still open: nothing after `1492d25` has been seen by anyone. Tell Matt the palette he opens may be the first live look at three fixes.
2. **Task 9's test may pass at once and stand as a pin.** Same. The cost is that the phone screen's own logic (its task, its `choose`) has no test of its own; I read it whole and found it right.
3. **Task 10 is a docs task before the final review; the runs and looks come after the fix wave.** Same. The cost is that As built's test counts, and its "fine for typed queries" call (C1), need amending after this review.
4. **The controller did not read DESIGN.md in full.** Same, with the reviewers as the backstop; nothing I found turns on a DESIGN rule the controller ruled against. I did not read it in full either (it was being edited); I judged looks against CLAUDE.md's three rules, PRODUCT.md and the spec, and found no fixed-point font, inline colour, card or second shadow in the new code.
5. **Task 2's Apocrypha line expects Tobit alone, with a word only Susanna has.** Same. It costs nothing; the test is stricter than the plan's.
6. **Implementers build into the shared DerivedData under Matt's running Debug app.** Same, given one Mac. The cost worth saying plainly: the bundle phase `cp`s `bible.sqlite` over the file the running app has open, in place, so between the schema-3 build and the relaunch that app could have read a half-written database. It held no real notes and has been relaunched since; nothing later replaced the database.
7. **Tab steps the chips unless VoiceOver is on.** Same outcome, for the reason given: the spec, the foot and Matt's own list all need Tab on the one Mac that matters. What it costs is larger than "a minor that follows the ruling": it removes the only keyboard path to a control his list tells him to use (I4), against PRODUCT.md's fourth principle, and it takes standard Tab traversal from anyone who relies on Keyboard navigation. I would pay that back with a key for the scope rather than leave it as a known gap.

## 7. Declined to judge

**Set aside as outside the plan or spec**

- DESIGN.md, DESIGN.json, README.md and the spec's As built: another agent's, by instruction. (One fact for whoever amends As built: its "fine for typed queries" is C1.)
- The phone's chapter switcher lands with `turn` and is not recorded, though it can jump many chapters; the Mac's book thumb, which does the same job, is. The plan's table says `turn` never records. Matt's to say whether a card chosen in the switcher is "on purpose".
- A translation's title matches by substring anywhere (`PaletteRanker.swift:43-46`), so `world`, `king`, `new` or `in` put a translation row above Scripture. Older than this project and unchanged; the same family as I2, and a ruling on I2 should probably cover it.
- After Switch Translation…, typing leaves the translations for the whole list (to spec), so `king` then Return opens 1 Kings, not the King James Version.
- Stemming is gone by design (`love` does not find "loving"); `OR` typed by hand is the word start `or`, to spec.
- The Notes window's own search field: unchanged, by the spec's call.
- Two pre-existing focus details: the 50 ms deferred focus in the panel's `onAppear` can fire into a panel already closing; the query field's text is not selected on reopen.
- `ß` and similar full case foldings differ between Foundation's folding and the index's; not in English text.
- The Release build, `install-app.sh` and the real store: untouched by this range and not mine to try.

**Only a live window, a phone or Matt's eye can settle**

For the controller, at the final relaunch of the Mac Debug app (keys only while it is frontmost; nothing that writes a note; put back what is changed):

- ⌘K with six commands, then with a few verses: no blank paper above the foot; no jump from tall to short on opening or while typing; a long list stops at 420 pt and follows the arrows.
- Tab with nothing typed, and in Switch Translation…: the field still types and Esc still acts. Tab and Shift-Tab step the chips; the foot says "⇥ Narrow".
- Switch Translation…: one Esc goes back, a second closes, two quick ones do both.
- A click on the page beside the panel closes it and does nothing else; a click on a toolbar button (expected: it acts and the palette stays).
- The scope menu: open it, its checkmark, the Book submenu; open it and dismiss it with Esc, then type (does the field still have the keyboard?).
- Sequence 1's end: narrow the scope, Return on a verse, then press J or → without clicking.
- Text & Layout from the palette: the popover shows and stays once the palette has gone. Export Notes… from the palette: the save panel attaches to the main window; Cancel it.
- A page style and an appearance from the palette repaint at once (put both back; the page style syncs in a Release build).
- Copy Link to This Chapter, pasted into a plain and a rich field.
- "Did you mean" in the live window, Return on it; then the same in Dark and Sepia.

For Matt:

- Whether the matched words must be bold in Printed on the Mac, and how (I3).
- Whether a search word that is also a command should lead with the command (I2), and whether a translation's title should match inside a word.
- Whether ⌘K should reopen with the last words in it (M2).
- Tab then ↓ at speed: does the selection jump back to the top (M8)?
- How a one-letter search feels on the phone; the 50 ms budget was measured on the Mac only.
- On the phone: "No matches" with the scope row; the menus at a large text size; a recent conversation chosen from Recent (it should open in Ask and stay); the thin separator above "Did you mean"; the size of Clear.
- VoiceOver on the palette (chips as buttons, the foot as one element, a command's shortcut read by name) and on the phone's search.
- The shadow and the bright panel over his real window, in daylight and under the lamp.
