# Final review: milestone 10, project 4, the Library

Range `733a74f..da751d5` (17 commits, ten building tasks), read on 2026-11-19. Task 11 (the documents and the live passes) has not run and is not reviewed.
By reading only. No suite, build, app, simulator or test was run. Five read-only `sqlite3 -readonly` queries were made against `Build/bible.sqlite` (dictionary entries that mention a year, the largest books by people, places and events, the family links by kind, people and places that still read alike, David's family); nothing was written. One read-only `git log -S` to date the deprecated tint line.

Read in full: the spec (sections 1 to 11), the plan's top through Review Focus and its pinning table, the ledger, `CLAUDE.md`, `PRODUCT.md`, the reviewer rules, the on-a-verse final review, and the 586 KB diff in seven passes:

1. The Mac app's two files, the importer, the schema, the store's reads, the groups (diff lines 1 to 1371).
2. The reference row, the deleted shelf, the chapter grid and cell, the rings, the credits, the front page, Settings (1372 to 2469).
3. The Library's models, the contents page and pane, dates, dictionary, family, About, credit, passage, People, `LibraryPlace` (2470 to 3993).
4. Places, the shared sections, `LibraryView`, years, the person's and place's pages, the map, the selection, the reference runs (3994 to 5477).
5. `NavigationModel`, the palette's items, the phone's edge swipes (5478 to 6391).
6. The phone's pages, Library, Places, reader, root, search and shell; the synced keys; the ranker (6392 to 7885).
7. The tests, README, scripts and the plan's one line (7886 to 12921). The three identical sets of Theographic fixture JSON by their stat alone.

Read in part outside the diff, each for a named risk: `NavigationModel.swift` 376-495, 640-710 and 1120-1180 (what ends a lookup, what `show` writes); `SearchQuery.swift` 10-100 (whether `%` or `_` can reach the name search); `FrontPageSearch.swift` (whether a typed reference's book is always listed); `ChapterGridView.swift` 100-150; `CommandPaletteView.swift`'s row switch and `SearchResults.chips()` (whether the Mac's palette draws the two new kinds); `DESIGN.md` 259-308 and 402-483. Greps over the new views for inline colours, fixed fonts, shadows, materials, literal spacing and `layoutManager` (none found), and for every caller of Home, Back and the lookup's return.

Paths: `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `LIB` is `SUI/Library`, `PH` is `SUI/Phone`, `SD` is `Packages/ScriptureKit/Sources/ScriptureData`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`.

## 1. Verdict

**Done with fixes.** The pieces fit. The Library's place is one value in the navigation model and every view, on both apps, reads and writes it the same way; the lookup that returns to it is traced right through Back, Home, reading on, Read From Here, a translation change, the other device reading on, and nothing being read. Nothing writes to the notes store, exactly two synced preferences were added, and the network is used only by the fetch script and Apple's map.

Three things should be fixed before Matt tries it:

- The way back to a person disappears if the passage opened is in the chapter being read and the page is scrolled five lines (I1). It is the commonest case of the project's headline flow.
- The Mac's People and Places lists are built whole, row by row, and built again on every choice. Nobody measured them on the big books: 1 Chronicles names 1,327 people, Joshua 434 places (I2).
- "Off, no year appears anywhere in the app" is not true of the dictionary's own words: 142 entries mention a year (I3). Matt has not been told.

After the fix wave the live looks owed by spec 11 must still be made. On the Mac nobody, agent or owner, has yet seen Open and Back to the same person, a name typed into ⌘K, or the map's camera after its fix. Section 10 lists them in order.

Counts: 0 Critical, 3 Important, 18 Minor.

## 2. Strengths

What to leave alone.

- **One place, held once.** `LibraryPlace` (book, view, the trail of people or places, the open books, the reference last opened) lives in `NavigationModel` and outlives the reader showing. The Mac binds it straight into `LibraryView`; the phone turns it into a stack's pages and back (`LibraryPlace.pages`, `init?(pages:)`), and the round trip is tested for a book's page, a page reached by name, and a page inside Places' sheet. A passage is never part of the place, on either app, so the way back always lands on the person.
- **The lookup's ends are all accounted for.** I walked `lookUpFromLibrary` through each: Back inside the chapter being read, Back through a chain of passages, Home, Next, Read From Here, a second Open, a translation that lacks the passage, the other device reading on, and nothing being read. Each ends in the right place and none stores a position it should not (`savePosition` and `adoptStoredPosition` both ask `isLookingUp`). The one that is wrong is by an older rule reaching further than it should (I1).
- **Nothing being read.** The passage shows through a history emptied for it, nothing is stored, the translation it began in is put back, and Back returns to the Library with no chapter open. Tested from the model and from the phone's shell.
- **The read cache.** `LibraryView.LoadCache` reads the store once for a book, view, person and translation, in the first body, so coming Back draws the page in its first frame. Its key holds everything the read depends on; I found no way for it to go stale. The phone's pages reuse it.
- **Dates.** Every year on a person, an event and a book's span goes through one argument, `showingDates`; the notice and the footnote ask one rule (`LibraryDates.showsNotice`) and can never show together; a page's `hasDate` is exactly "this page would show a year", so a year is never shown without one of them. Turning the setting off answers the notice. The two keys are in the synced list and the list's test names all eighteen.
- **Names, never as keys.** Every table, read, place, palette row and phone page carries the data's integer id. The name search cannot be handed a wildcard: the typed words are cut to letters and digits before they reach `LIKE` (`SearchQuery.tokens`), so `%` and `_` yield no word at all.
- **The contents page's model.** The columns, the breaks, the arrows, the dimming and the chosen match are one pure struct with exact tests against the mockup's four columns. 783 ms to 57 ms.
- **The rings.** The colour rule holds 3:1 on three surfaces in every appearance for the defaults and 24 hues; a deleted colour counts as none; seven colours show six.
- **The fetch script learned from project 3.** Each table is hashed before it is moved into the cache, the cache is hashed again on a hit, `curl` has a time limit and a size cap, and an import that yields no person fails.
- **The UI rules are kept.** Palette tokens only, semantic text styles, `AppSpacing` and `AppRadius` by name, scaled metrics for every width tied to text, no card, no shadow, no material, nothing floating over the map, the system's `Marker` and popover untouched. The one fill is the notice's `paper.overlay` row, which the spec asks for.
- **The owner's data.** No file under `ScriptureModel` changed but one read (`chapterColorIDs`). No test touches iCloud, the clipboard or the network; the benchmarks read `Build/bible.sqlite` read-only; no test makes a `Map`.

## 3. Issues

### Critical

None.

### Important

**I1. Open a verse that is in the chapter being read, scroll five lines, and the way back to the person is gone.**
`SUI/NavigationModel.swift:658-663` (`reportLinesScrolledSinceJump`), into `:676-684` (`endLookupHere`).

What Matt sees: reading John 1, he opens People in John, chooses John the Baptist, clicks "1:29-34" and Opens it. The reader jumps to verse 29. He scrolls down to read the passage. Back no longer returns to John the Baptist: on the Mac ⌘[ goes to whatever chapter was read before, and Home shows the contents with no view open; on the phone the bar's "‹ John the Baptist" turns back into the Library button, and Library opens on the list.

Why: a jump inside the chapter being read has always ended once the page is scrolled five lines from where it landed, on the reasoning that scrolling on in your own chapter is reading. A Library lookup into that chapter is the same kind of jump, so the same rule ends it, and ending it forgets the Library's place by design. No other chapter is affected: the rule asks that the passage's chapter is the one being read.

Why it matters: spec 6.7 names how a Library lookup ends (Next, Previous, Read From Here), and Matt's own sentence is that coming back should take him to the same person. The book that opens chosen is the book being read, so the verses a reader clicks first are often in the chapter he is in. No test covers it; `readingOnOrReadFromHereEndsALibraryLookup` covers only Next and Read From Here.

Fix: in `reportLinesScrolledSinceJump`, do nothing while `libraryReturn != nil`. The cost, to tell Matt: after such an Open the stored reading verse stays where it was until he goes Back, reads on with Next, or chooses Read From Here.
Test, in `T/NavigationModelTests.swift`: reading Matthew 1, `lookUpFromLibrary` to Matthew 1:6 from David's page, report 40 lines scrolled from the current scroll target; expect `isLookingUp`, the Library's place unchanged, then `goBack()` shows the front page on David.

**I2. The Mac's People and Places lists are built whole and built again on every choice, and were never measured on a large book.**
`LIB/LibraryPeopleView.swift:58-79`, `LIB/LibraryPlacesView.swift:171-204`, `LIB/LibraryView.swift:50-63`.

What Matt may see: People in 1 Chronicles slow to open, and a pause on each click or arrow press in its list. The same in Places for Joshua.

Why: each list is a plain `VStack` in a scroll view, one view per row with its tap, its accessibility and its closures. 1 Chronicles names 1,327 people; Nehemiah 458; Genesis 352; Joshua names 434 places (305 pins). Every choice writes the Library's place, which redraws the list from the top, and the read behind it fetches the whole book's list again because the cache's key includes the person chosen. Opening a person then writes the place a second time a moment later (the open books are seeded in a task), so each choice is two full passes.

What was measured: John's 39 people, and the largest single person pages (90 to 146 ms in a debug build). The list for a large book was not. The shelf this project replaced built about 1,190 cells at once and took 783 ms; 1,327 rows is the same shape. Reading cannot say whether it is 80 ms or 500 ms, only that nobody looked. The phone's lists are lazy and are not affected.

Fix, in this order:
1. Measure first. Add two cases to `T/LibraryBenchmarkTests.swift`, hosted offscreen as `FrontPageBenchmarkTests` hosts the front page (`NSHostingView`, never shown, the real store): (a) `LibraryView` on People in 1 Chronicles with its first person chosen, the time to lay out; (b) the same view, then the next person chosen, the time to lay out again. Add (c) About for Genesis (116 events). Record all three figures in the report and the spec's As built. Do not host Places: a test must not make a `Map`.
2. If (a) is over 150 ms or (b) over 100 ms: make the two Mac lists' stacks `LazyVStack` (the rows already carry their ids, and the arrow keys only ever scroll to a neighbour), and read the book's list separately from the chosen person's page so a choice re-reads only the page (two keys in `LoadCache`, or two caches). Measure again and record both.
3. If both are under, keep the benchmarks and change nothing.

**I3. With dates off, a dictionary entry can still show a year.**
`LIB/DictionaryEntryView.swift:21-24`, `SUI/GeneralSettingsView.swift:50-56`; spec 6.5, "Off, no year appears anywhere in the app."

What Matt sees: Show dates off, Solomon's page still reads "He was probably born about B.C. 1035" in the entry from Easton's. 81 people's entries and 61 places' mention "B.C." or "A.D." (counted in the built database).

The entry is a quotation with its source named under it, so the anti-goal (a date with no word on whose dating it is) holds. The spec's flat sentence does not, and nothing in the ledger or the plan says so. No code can strip years out of prose safely.

Fix: say what the setting covers, and tell Matt. Add one sentence to the Library section's footer in Settings: "A dictionary entry may still mention a year in its own words." Record it in the spec's As built among the known limits. If Matt would rather hide the dictionary's entry while dates are off, that is a two-line change in `PersonPageView` and `PlacePageView`; it is his to choose.

### Minor

**M1. Return in the empty search field opens the chosen book.** `SUI/FrontPageView.swift:154-157`, `LIB/ContentsPage.swift:131-135`. ⌘F then Return, with nothing typed, opens the pane's book at chapter 1 (or resumes the one being read). For another book that moves the reading place and adds a Recent. The old front page did nothing here. Spec 4.3's "Return opens the chosen book" sits under "While something is typed". Fix: `submitTarget` is nil with nothing typed. Test: one line in `typingDimsAndChoosesAndAReferenceRingsItsChapter` after `setQuery("")`. A call; one line to undo.

**M2. A verse on a person's page cannot be reached from the keyboard on the Mac.** `LIB/ReferenceRunsText.swift:82-108`. The run of references is one text of links (the ruling that cut a page's build from 500 ms to 146 ms); links in a text take no Tab stop. The People list, the family's names and the Elsewhere rows can be walked by keyboard; the verses need the pointer. VoiceOver has each reference as a named action. `PRODUCT.md` asks that everything be reachable from the keyboard. Backlog, with Matt's word on how (arrows through the run, or a key that opens the first).

**M3. ⌘[ on a Library page is the reader's Back, not the Library's.** `SUI/NavigationModel.swift:708-718`. With a view open and no lookup showing, ⌘[ leaves the Library for the chapter before the one being read. After coming Back from a passage by the bar or Home, ⌘[ opens that passage again as a plain read, which moves the reading place. The Library's own way back is its header ("‹ Contents", "‹ the person before") and Esc. Older than this project, but a reader walking a family will reach for ⌘[. For Matt: should ⌘[ step back through the people while a view is open?

**M4. On coming back, the list is not scrolled to the chosen row.** `LIB/LibraryPeopleView.swift:58-79`, `LIB/LibraryPlacesView.swift:201-204`. The person's page returns; in a long list the row on the wash may be out of sight. Fix: in each list, a `.task` that scrolls to the chosen row once the rows are laid out (`anchor: .center`).

**M5. The notice's Settings and OK are one line of text tall and `md` apart.** `LIB/DatesNotice.swift:19-27` and `:45-51`. On the phone that is under the 44 pt a finger needs, on two buttons that do different things; the footnote, Show more and a writer's name are the same height. Fix for the notice's two buttons and the footnote: a content shape with a minimum height (44 pt on iOS, 24 pt on the Mac, as `DESIGN.md` asks of symbol buttons).

**M6. A page's title is read from the store on each redraw.** `LIB/LibraryView.swift:171-181` into `SUI/NavigationModel.swift:300-311`: the header of a page reached by name, and the name on the way back to the person before. The phone's bar does the same during a Library lookup (`PH/PhoneReaderScreen.swift:615`). One row by its key each time; small. Fix in `LibraryView.title`: use the page already read (`loaded.person`, `loaded.placePage`). The rest to the backlog.

**M7. Esc on the contents page, with no view open, is taken and does nothing.** `SUI/FrontPageView.swift:84-86`. It would no longer leave full screen while the keyboard is in the contents. Fix when next touched: attach the handler only while a view is open. For the live look.

**M8. A reference pasted whole ("ps 119") can ring a chapter that is out of sight.** `SUI/ChapterGridView.swift:116-119`. Typed letter by letter the book is chosen at "ps" and the ring's cell is scrolled to as the number arrives. Pasted, the pane's grid is made with the ring already set and the scroll never runs. Fix: `initial: true` on that `onChange`.

**M9. Siblings and half-siblings have no test.** They are 5,148 of the 8,924 family links and the whole middle generation; the fixture holds none. The importer joins two half-sibling lists into one kind and `PersonPage` joins two kinds into `siblings`. Fix: one assertion on the real store in `T/LibraryBenchmarkTests.swift` (`needsRealBible`): David (994) for the whole Bible has 1 parent, 8 partners, 9 siblings and 21 children.

**M10. A few people and places still read alike.** Azariah (381, 382), Elnathan (1178, 1179, 1180) and Jozabad (1737, 1738) share a name and their only label; Tower (1177, 1179) and Valley of Shaveh (692, 1216) among places. Each has one to four verses. A limit of the data; record it in As built.

**M11. Blocks written twice.** `seedOpenBooks`, the scroll back to the opened book and "few references opens every book" are the same lines in `LIB/PersonPageView.swift:67-73, 100-106` and `LIB/PlacePageView.swift:37-39, 75-81, 108-114`; the "No Places" page in `LIB/LibraryView.swift:106-114` and `PH/PhonePlacesScreen.swift:37-45`; the store reads in `LIB/LibraryView.swift:50-63` and `PH/PhoneLibraryPages.swift:156-175`; the map's and list's choosing in `LibraryPlacesView` and `PhonePlacesScreen`. None is long. Backlog.

**M12. Leftovers of the shelf and sidebar.** Comments only: `SUI/FrontPageSearch.swift:4` ("sidebar search"), `SUI/PageFace.swift:95` and `SUI/PageFaceEnvironment.swift:9` ("the shelf"), `SUI/Fonts/README.md:10`, `SUI/FrontPageView.swift:70`, and `PH/PhoneLibraryPages.swift` on the whole-Bible map ("as the Mac's does", which is a different height). `MarkupStore.markedChapters()` now has only test callers. `Tests/ScriptureDataTests/FixtureDatabase.swift:19` is mis-indented. `DESIGN.md` still describes the sidebar, the shelf, three placeholder icons and four phone chips; that is Task 11's.

**M13. About's first row is labelled "Place".** `LIB/LibraryAboutView.swift:37`. It holds the Testament and group ("New Testament · Gospels & Acts") two rows above "People and places", in a Library with a Places view. One word for Matt to choose.

**M14. A page reached by name shows the name twice on the Mac.** The header's title and the page's own heading, `LIB/LibraryView.swift:142` and `LIB/PersonPageView.swift:80`. For the eye.

**M15. About reads more than it shows.** `LIB/BookAbout.swift:24-38`: every person and place of the book to count them, every book of the translation for one chapter count, and a whole chapter for each event that runs past its chapter (nine in Genesis). I2's benchmark (c) will say whether it matters.

**M16. The `preferredControlTintColor` warning is not this project's.** `PH/PhoneLibraryScreen.swift:186` came in with `0740b2f` on 2026-11-13; this diff only moved it down the file. The ledger's "from Task 9" is wrong. Backlog.

**M17. The family's middle row mixes partners, the person and siblings.** `LIB/FamilyView.swift:24-27`. David's wraps over three lines with Abigail in it twice, wife and sister; VoiceOver says which, the eye cannot. Labels and event titles keep the data's capitals ("Mary's Husband" beside "son of Matthan"). Both are in the ledger for Matt's look; nothing was decided.

**M18. The name search's "finds nothing" test tries single characters only.** `Tests/ScriptureDataTests/BibleStoreLibraryTests.swift:42`. By reading, no punctuation of any length can become a pattern. Add "%%", "__" and "_%" to the list so the test says so.

## 4. The rulings

| | Ruling | Mine |
|---|---|---|
| R1 | The build went ahead on the plan's readings and departures without waiting for Matt | Same. Each is one view or one layout to redo. He has still not answered; they are in section 10. |
| P1-P5, P10-P13 | Stale wording, call sites, a mutator for the trail, the label's padding, bookkeeping | Same. All landed. |
| P6 | Under a heading that names the book, a reference is written without it ("1:18-19") | Same. VoiceOver hears it in full. |
| P7 | The importer's release build is allowed | Same. |
| P8, P9 | Straight apostrophes; "Open in Read" on the phone | Same. Both are the app's existing copy. |
| P14 | The shared sections are views of their own | Same, and done, but for the three blocks in M11. |
| P15 | A writer on About opens in the book's People | Same. Tested. |
| Task 1 | "Also called" is kept as a JSON list | Same. |
| Task 2 | The page models are read on the main actor | Same for a page: 6.8 ms for the largest person. The ruling's evidence is the read, not the view built from it, and no list was measured (I2). Not wrong; not finished. |
| Task 3 | In Settings' About the credit is an entry like the others; the seven links are in the line at each view's foot | Same, as project 3's credit was ruled. |
| Task 5 | Changing the translation on the front page keeps the book chosen there | Same. Matt has not been told. |
| Task 6 | The pane's header stays put and only the grid scrolls | Same. Spec 6.1 needs the open view's icon in sight. |
| Task 7 | Typing in the toolbar's field closes a Library view; built in Task 7's fix round | Same. |
| Task 7 | A run of references is one linked text, its popover at the pointer | Same on the cost. Its price was not written down: the verses cannot be reached by keyboard (M2). Say so to Matt. |
| Task 7 | Round 4 went to the same implementer | Same. Two lines. |
| Task 8 | The gathered pin stays the system's marker; VoiceOver hears its count on the rows | Same. Matt was told. |

I say none is wrong. Two were under-told: the Task 2 ruling stopped at the read, and the linked-text ruling did not name the keyboard.

Not a ruling, but it belongs here: an implementer answered the dates notice in the simulator, the answer went to the Debug apps' iCloud key-value store, and it removed the key again with a launch argument it did not commit (I checked: none is in the tree). The handover's line that the simulator is not signed in to iCloud is wrong for that store. A synced setting changed in the simulator reaches Matt's Debug Mac. The handover should say so before project 5.

## 5. The deferred and parked lines, sorted

**Fix before done**

- Task 5: no test for Home during a Library lookup with nothing being read, nor for a second Open with nothing being read. Both read right; add them with I1's test.
- Task 3: the notice's and footnote's small hit areas. M5.
- Task 6: the ringed chapter's reveal skipped when the grid is made with it. M8.
- Task 6: Return in the field with nothing typed. M1.
- Task 2: the mis-indented `theographic:` line. M12.
- Task 10: the stale comment in `PhoneLibraryPages.swift`. M12.

**Backlog**

- Task 1: no tests of the importer's warning paths. Keep with re-pinning Theographic.
- Task 3: `DatesNotice` and `DatesFootnote` write to `UserDefaults.standard` with no seam; no test that the notice and footnote never show together. The rule itself is tested.
- Task 4: a near-grey custom highlight gets a vivid ring. Raise with Matt.
- Task 4: `ChapterRing.color` works the hex out per segment on every redraw; the ring's width scales by `.title3` in the pane. Look if the Psalms grid ever drags.
- Task 4: `chapterColorIDs` repeats `markedChapters()`'s walk; remove the older one with its test. No test of where the ring's path starts.
- Task 5: `fitTheLibraryToTheTranslation` runs twice in one branch; the "is this chapter available" guard and its warning are now in five places.
- Task 6: `isDimmed` builds a set per book per redraw. No tests for a one-Testament or Apocrypha-only translation, or `target(opening:)` with nothing being read. `scrollTo` with no anchor (see the live look for Tobit).
- Task 7: the first frame of a person's page draws its books closed, then opens them. The Contents and step-back buttons repeat their style. The cache test does not vary the translation. `ReferenceRunPopoverTests` checks the arrow's rectangle, not the wiring. A range partly missing from the translation shows what it has and does not say so.
- Task 7: God with Psalms open, 146 ms in a debug build; Release unmeasured.
- Task 7: Esc taken on the contents. M7.
- Task 8: a gathered pin clicked while one of its places is chosen does nothing ("At the same spot" is the way to its neighbours). The camera animates on every tick of a window resize and is set twice on opening.
- Task 8, parked: VoiceOver reads a gathered pin without its count. A custom annotation changes the pin's look; Matt's word.
- Task 9: the phone sheet's map padding is not refreshed at the large detent.
- Task 10: one `do` wraps both name searches; the name read runs when another chip is chosen; no test of the push in `PhoneSearchScreen.choose` or of the memory's reset.
- Task 10: the `preferredControlTintColor` warning. M16.

**Drop**

- Task 1: `joined(_:)` and Task 2: `names(_:)` with `try?`. A list of strings cannot fail to encode, and the column is written by the same importer.
- Task 1: the dictionary's `.key` naming; the duplicate-id winner differing between people and places (the data has none, and a duplicate warns).
- Task 2: `BookAbout` loading every book for one count, by itself. Folded into M15.
- Task 2: `places(sharingPointWith:inBook:)` in a book. Settled: the whole-Bible page passes no book, and `theWholeBiblesPlaceHasEveryPlaceAtItsSpot` holds it.
- Task 2: the list's tiebreak is plain `<`.
- Task 3: the long doc comment line.
- Task 4: the two comment and test nits.
- Task 6: `ChapterGridView`'s `isTabStop` and `Spacer` fallback. Already gone; `.grid` is the phone's size and is in use.
- Task 7: "with an anchor set the other books stay closed". The open books travel with the place, so they come back as they were left.
- Task 7: a link opened by the keyboard anchors at the pointer. Links cannot be opened by the keyboard (M2).
- Task 8: "in view" judged on the pin's centre. Fixed in its round.
- Task 9: `PhoneLibraryPageMemory` made on every init; its anchor on a bare People or Places page. Cheap, and About uses the anchor.
- Task 9: the iOS test count's destination not quoted. Task 11 runs the suite again.

**For Matt, not code**

- Task 4: the colourless ring is `ink.tertiary`, 2.56:1 to 2.95:1, under the coloured rings' 3:1, as the dot was.
- Task 5: a translation change on the front page keeps the chosen book.
- Task 7: the family's middle row and the data's capitals. M17.
- Task 9: the notice's answer that reached, and was removed from, the Debug apps' iCloud store. If he had answered it himself before then, it shows once more.

## 6. The five Review Focus items

| | Item | Code | Test | Holds |
|---|---|---|---|---|
| 1 | A verse the translation lacks says so and offers no Open | `LIB/LibraryPassage.swift:10-18, 28-40` (the missing case has no button); `PH/PhoneLibraryPages.swift` (`passage`, "Not in This Translation"); `SUI/NavigationModel.swift:497-502` (Open on a missing chapter changes nothing) | `aReferenceTheTranslationLacksSaysSoAndOffersNoOpen`, `openFromTheLibraryIsRecordedAndAMissingPassageDoesNothing` | Yes. The views' branch is read, not run. |
| 2 | The Library's place going stale on a translation change | `SUI/NavigationModel.swift:613-619`, called from `setTranslation` and `returnToLibrary` | `aTranslationWithoutTheLibrarysBookClosesItsView`, `quittingOrChangingTranslationLeavesNoStaleLibrary` | Yes, in a lookup and on the front page. |
| 3 | One letter, punctuation, `%` or `_` finds nobody | `SD/BibleStore+Library.swift:193-197`; `SD/SearchQuery.swift:57-91` | `namesAreFoundByTheStartOfAWordAndNothingElse` | Yes for every input, by reading; the test tries single characters (M18). |
| 4 | A deleted colour is a ring with no colour; more than six shows six | `SUI/MarkupModel.swift:747-757`; `SUI/ChapterMarks.swift:35-42` | `aDeletedColourCountsAsNoColour`, `oneColourIsAWholeRingAndSeveralShareItEqually` | Yes. |
| 5 | No place, one place, no event | `LIB/BookPlaces.swift:32, 40-55`; `LIB/LibraryView.swift:105-114`; `LIB/BookAbout.swift:16-21`; `LIB/LibraryAboutView.swift:52, 61` | `placesGatherAtOneSpotAndTheUnlocatedSitApart`, `aboutABookGivesItsFactsWritersAndEventsInOrder`, `theListsRowsAndCountReadAsPeoplesDo` | Yes. |

## 7. What spec 11 has pinned and what it has not

**Pinned by name, through the rule the sentence is about**

- Groups: `everyBookIsInExactlyOneGroupInCanonOrder`.
- The contents model, every item: the four `ContentsPageTests`.
- Rings for one, two and seven colours, colourless marks, the contrast: `ChapterRingTests`, `aChaptersRingHoldsThreeToOneOnEverySurface`, `aDeletedColourCountsAsNoColour`.
- The importer, ids as keys, schema 5, an older database: `theFixtureLibraryLandsAtSchemaFive`, `theFixturePeopleLandByTheirOwnIds`, `theBuildScriptsPatternReadsTheSchemaVersion`, `schemaMismatchThrows`.
- People, places and events in order with counts; a shared name; a place with no coordinates; gathered places: `BibleStoreLibraryTests`, `LibraryPagesTests`.
- Dates on by default, off removing every model year, the notice once, synced: `LibraryDatesTests`, the two `PreferenceSyncTests`, the `showingDates: false` lines.
- Open is a lookup; Back to the same book, view and person, with something and with nothing being read; reading on; quitting: eight tests in `NavigationModelTests`, eight in `PhoneShellModelTests`.
- Search by name, "also called", a place, shared names, the whole-Bible page by book: `aNameTypedFindsItsPersonAndChoosingThemOpensTheirPage`, `peopleAndPlacesAreTwoGroupsAfterCommandsWithTheirChips`, `aPersonsPageHasFamilyByGenerationAndVersesHereAndElsewhere`.
- Years: `yearsReadAsTheSpecWritesThem`, `yearsNamesTextAndPointsReadAsTheTablesWriteThem`.
- The benchmark: `theFrontPageOpensWithinAHundredMilliseconds`.

**Pinned in part**

- "Family generations": parents, partners and children. Not siblings or half-siblings (M9).
- "A reference clicked shows its passage with the view unchanged": that loading a passage changes nothing in the model. The popover and the phone's push are read, not run.
- "Off removes every year": every year the app writes. Not the dictionary's own (I3).
- "Back returns to the same person": by Back, Home and the phone's bar. Not after a scroll in the chapter being read (I1).

**Pinned by nothing**

- The Mac's views: which place each control writes, the list's arrows, Esc, the header's way back, the popover at the pointer.
- The phone's stack: that a push or a pop writes the place, that Places' sheet shows and leaves, the push inside Search.
- The notice and footnote never together; the notice's two buttons.
- The map: the camera, the selection binding, the pins.
- A large book's list (I2).

## 8. Fix before done

One wave, in this order. Each item stands alone.

1. **A Library lookup does not end by scrolling (I1).** In `SUI/NavigationModel.swift`, `reportLinesScrolledSinceJump` returns at once while `libraryReturn != nil`; say so in its doc comment and in `endLookupHere`'s. In `T/NavigationModelTests.swift` add: (a) the test in I1; (b) with nothing being read, `lookUpFromLibrary`, then `goHome()`: the front page on the same place, no chapter open, nothing stored; (c) with nothing being read, `lookUpFromLibrary` twice from two places, then `goBack()` until the Library shows: it is the second place.
2. **Measure the large lists, and make them lazy if they are slow (I2).** As I2's three steps. Record the figures whatever they are.
3. **Say what Show dates covers (I3).** In `SUI/GeneralSettingsView.swift:55`, add to the Library footer: "A dictionary entry may still mention a year in its own words." Nothing else changes.
4. **Small fixes, one commit.**
   - M1: `ContentsPage.submitTarget` is nil with nothing typed; one test line.
   - M8: `ChapterGridView.swift:116`, `initial: true`.
   - M5: the notice's two buttons and the footnote get a content shape at least 44 pt tall on iOS and 24 pt on the Mac.
   - M4: each Mac list scrolls to its chosen row in a `.task` once laid out.
   - M6: `LibraryView.title` uses the page already read for a page reached by name.
   - M9: the assertion on David's family on the real store.
   - M18: "%%", "__" and "_%" in the name search's list.
   - M12: the six stale comments and the one indentation.
5. **For Task 11's documents, carried from this review.** As built must say: I1's cost (the stored verse waits); the three benchmark figures; I3 as a known limit; M10's names; the colourless ring; what "as it was" does not keep (the scroll, the map's zoom, the search field's text); that a plain Home, Close on the phone, and a relaunch all forget the Library's place; that the handover's line on the simulator and iCloud was wrong.

## 9. Backlog

For `docs/BACKLOG.md`, under "The Library and study data".

- A keyboard way to a verse on a Library page (M2).
- ⌘[ while a Library view is open: the reader's history, or the people walked (M3). Matt's word first.
- Esc on the contents page is taken with no view open (M7).
- VoiceOver on a gathered pin: its count needs a custom annotation.
- A neutral ring for a near-grey custom highlight.
- The family's middle row: tell partners from siblings by eye; the data's capitals in labels and event titles (M17).
- People and places that still read alike: Azariah, Elnathan, Jozabad, Tower, Valley of Shaveh (M10).
- A range partly missing from the translation shows what it has without saying so.
- The first frame of a person's page: books closed, then opened.
- About reads every person and place to count them (M15).
- Blocks written twice across the person's and place's pages and the two apps (M11); the five copies of the "is this chapter available" guard.
- `MarkupStore.markedChapters()` is used only by tests.
- `preferredControlTintColor` is deprecated (`PhoneLibraryScreen.swift:186`, from milestone 9).
- Tests owed: the importer's warning paths; the notice and footnote never together; the phone's push and pop writing the place; a one-Testament translation on the contents page.
- Release-build figures for the largest person page.
- The handover: a synced setting changed in the simulator reaches the Debug Mac through iCloud's key-value store.

## 10. What I declined to judge, and what a live look should try

**Declined, because only a window, a device or Matt can say:**

- Whether a click on a book or a list row gives that list the keyboard. Live pass 2 found the arrows dead until Tab after the app came back to the front. By the code a click chooses and nothing asks for focus; whether SwiftUI gives a focusable container the keyboard on a click inside it is not something reading settles.
- ⇧⌘H on the front page with another book chosen. Live pass 2 saw the choice stay on Matthew. By the code it goes to the book being read (`goHome` writes it and the page follows). The likeliest reading is that Matthew had become the book being read while Matt used the app between the passes.
- The map: whether MapKit keeps its centre and zoom when the map halves (the camera rule assumes it; if SwiftUI re-fits the region instead, choosing a place near the edge recentres the map though it was in view), 305 pins in Joshua, no connection.
- The popover's arrow at the pointer, on a wrapped line and near the window's edge.
- Whether the scroll back to the opened book or event lands after one layout pass.
- Settings opening from the notice while the phone's Library is up; Places' sheet at its three detents; the software keyboard on the way back to Search.
- VoiceOver anywhere; dark and Sepia on the phone's new pages; Increase Contrast on the rings; any accessibility text size on the Mac.
- The dictionary's entry in `ink.primary` where `DESIGN.md`'s Quote is `ink.secondary`; the label "Place" (M13); the name shown twice (M14).

**Decided for Matt and not yet told, or told and not answered:**

- The four departures and two readings in the plan (the ring a rounded rectangle; the place's page under the map, not over it; the pane's smaller cells; Easton not fetched; from Search the phone's way back returns to Search; what "as it was" keeps).
- A reference under its book's heading drops the book's name. "Open in Read" on the phone. The pane's header does not scroll.
- A translation change on the front page keeps the chosen book.
- The phone's way back lands on the person, not on the passage's page.
- Closing the phone's Library, a plain Home on the Mac, and a relaunch forget the Library's page.
- A person or place opened by name takes the Mac to the front page and is not added to Recent.
- The verses on a page need the pointer (M2). Dates off does not reach the dictionary (I3).

**The live look, in order, on the build after the fix wave.** Mac first.

1. People in the book being read: choose a person, click a verse in the chapter being read, Open, scroll a screen, press ⌘[. The same person, the list's row in view. Then the same with Home. (I1, M4.)
2. The same from a verse in another chapter; then Open, Next Chapter, ⌘[: the reader's own history.
3. People in 1 Chronicles: how long it takes to open; hold the Down arrow. Places in Joshua. About Genesis. (I2.)
4. Click a book on the contents page, press an arrow at once. Click a row in People, press Down at once. Tab and Shift-Tab round the contents, the pane, the list.
5. ⌘K "david", Return: "‹ Contents  David", the pane keeping its book. Walk to a parent, the header's way back, Esc. ⌘K "jerusalem": the map on its pin, "At the same spot". ⌘K "light": the command first.
6. Places in Acts: a pin, the gathered pin at Jerusalem and its rows, a row far from view (does the camera move once and stop), a click on the empty map, a window resize with a place chosen. Then with the network off.
7. About John: a writer's name opens him in People; an event's passage, Open, Back to the same event in view.
8. The notice on a dated person: OK, then the footnote in its place; Settings from the footnote. Dates off: Abraham's page, About's When and years gone; Solomon's dictionary entry still has its year. (I3.)
9. A reference where the line wraps, and one at the page's edge: where the popover's arrow points. A verse the CPDV lacks in Psalms: the line and no Open.
10. ⌘F, "rom 8", Return. ⌘F, nothing typed, Return: nothing. Paste "ps 119": the ring in view. "zzz". Type with a view open: back to the contents. (M1, M8.)
11. ⇧⌘H with another book chosen, and with a view open. Esc on the contents in full screen. (M7.)
12. WEB, reading Tobit: the page opens with Tobit in view. Double-click a book; double-click the one being read.
13. The contents page at a large text size, in dark and in Sepia; the rings there and at Increase Contrast.
14. ⌘[ with a person's page open and no passage opened. (M3.)

Then the iPhone, on a real phone.

15. Library, a book, People, a person, a family name, a verse, Open in Read, scroll, the bar's way back: Library on the same person. (I1.)
16. Places: the sheet at a quarter, medium and large; a row; a place's verse; Open in Read; back. Close Library with the sheet up.
17. About, the notice: OK and Settings with a thumb. (M5.) Settings opens over the Library.
18. Search "peter": the page pushed, a verse, Open in Read, the way back to Search with the software keyboard. The back swipe on that page. Show all.
19. With nothing being read (a fresh install or the simulator): Library, a person, Open in Read, back.
20. Rings in the Library's chapters; the group headers; dark and Sepia; the largest text size on About.
