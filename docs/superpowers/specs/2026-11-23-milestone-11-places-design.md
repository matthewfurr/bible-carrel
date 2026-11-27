# Milestone 11, project 4: Places

Written 2026-11-23 from the milestone 11 brainstorm with Matt. Status: **Approved by Matt, 2026-11-23** ("I approve all 5."). Mockup he chose from: `docs/superpowers/specs/milestone-11-mockups/places.html` (section 1, the fix; section 2, option B). The milestone's entry in the main spec and its working handover say where this project sits: fourth of five, after project 3 (People), whose list switch, dictionary paragraph and verse runs this project reuses.

Every decision Matt did not make himself is marked **(call)**. Each can be overturned at his review of this spec or on his first look at the build.

## 1. Intent

Matt's words, 2026-11-22: "Places. Some locations don't show a pin when selected. Also, can there be an option to sort places by alphabetical order or grouping into chapters where they are mentioned?"

Shown the two ways the map could behave when the list is grouped by chapter, he answered "B" (2026-11-23): the map follows the chosen chapter.

Two jobs, then. First, a place chosen in the list must always be seen on the map as itself. Second, the list can be read three ways (most named, A to Z, by chapter), and read by chapter it becomes a way to follow a book's story across the map: "where does this chapter happen?"

## 2. Goals, non-goals, anti-goals

**Goals**

- A place chosen in the list, or on the map, is always visible on the map as a pin bearing its own name, above any neighbouring pin, on the Mac and on the phone.
- The Places list has three orders: **Most named** (today's), **A to Z** and **By chapter**, on both apps, with the same control People has after project 3.
- Under By chapter, choosing a chapter shows that chapter's places as the map's pins, framed to them, with the rest of the book's places as small dots. The Mac steps chapters from the keyboard.
- The phone's sheet carries the same control and the same chapter behaviour.

**Non-goals** (each goes to `docs/BACKLOG.md` or is already there, section 12)

- Paul's journeys and other routes (already in the backlog, wanted).
- A list of every place in the Bible (already in the backlog).
- Changing how pins gather: places at the same point (rounded to 0.001°) are still one pin, and pins still neither merge nor split as the map zooms.
- Drawing approximate places differently on the map (511 places are approximate; the page already says "approximate"). **(call)**
- A custom map annotation in place of the system `Marker` (the backlog's "VoiceOver on a gathered pin" stays where it is).
- The map tiles' modern labels.

**Anti-goals** (a failure even if it works)

- Anything floating over the map: no card, callout, chip or banner on it. DESIGN's rule ("Nothing floats in this system but the ⌘K panel") holds; the chapter's name and count go in the view's header line, and a place's page stays under the map.
- A chosen place that is "on the map" but cannot be found on it.
- A chapter mode that hides rows or chapters: the list keeps the whole book, so the reader never wonders where the rest went.
- A camera that moves when nothing was chosen.

## 3. Approaches

### 3.1 The missing pin (a fix, one proposal)

The likely cause, read from the code and the data (not yet seen live): places the data puts at the same point share one pin, and that pin is titled with its most-mentioned place (`BookPlaces.swift:76-77`, `title: lead.name`). Choosing one of the other places selects the shared pin (`PlacesSelection.swift:12-15`), so the reader sees a selected pin with another place's name and a count. In Acts, Judea, Solomon's Portico, the Beautiful Gate and Akeldama all sit on Jerusalem's point, and choosing Solomon's Portico shows a pin that says "Jerusalem". Joshua is the worst book: 202 of its 434 places are in shared pins.

Three ways were weighed:

1. **The shared pin takes the chosen place's name** while one of its places is chosen. One pin per point stays true; nothing is drawn twice. **Chosen.**
2. Split the chosen place out as a pin of its own at the same point. Rejected: two pins at one point, one hidden under the other, which is the same fault in a new shape.
3. Ungather every place at the chosen point. Rejected: Jerusalem's point holds about seventy places across the Bible.

Matt was shown proposal 1 with the mockup and asked to name a place he had seen fail; he chose option B for the list without answering that. The hypothesis is strong but unconfirmed, so it is the first thing the build checks (4.2).

### 3.2 The map under By chapter

- **A. The map stays the whole book.** Only the list changes. Small.
- **B. The map follows the chapter.** Choosing a chapter shows its places as pins, framed, the rest as dots; the keyboard steps chapters. Medium.

Matt chose **B** (2026-11-23).

## 4. The missing pin

### 4.1 What the reading found

The other candidates, ranked below the shared pin:

- **Not on the map.** 26 places have no coordinates (Eden, Gihon, Pison, Havilah, Nod and others; Genesis has 8). Choosing one selects nothing on the map, by design; the place's page says "Not on the map." This stays as it is. **(call)**
- **Overlapping neighbours.** 2,163 pairs of different points lie within 0.02° of each other (Jerusalem, the Kidron, the Gihon and En-rogel are a few hundred metres apart), so one marker can sit on another.
- **The phone's sheet.** `reveal` judges whether a pin is in view against the whole map, but the sheet covers its lower part (`PhonePlacesScreen.swift:88`, `.safeAreaPadding(.bottom, sheetCover)`), so a chosen pin can be "in view" under the sheet.

### 4.2 First, confirm it live

The plan's first task, before any change:

1. **Ask Matt again** which place he saw choose without a pin, and on which device. He was asked on 2026-11-23 and did not answer; if he does not remember, go on.
2. **One live pass by the controller** on the Mac Debug app, under the handover's rules for Matt's Mac (idle time, keys only, pid): Acts, choose Solomon's Portico, Judea and Akeldama; Joshua, any place in a shared pin; Genesis, Luz (Bethel's point). And in the simulator: the same in Acts with the sheet at its medium detent.
3. **If what is seen matches 3.1** (a selected pin bearing another place's name), build 4.3. **If it shows another cause** (a place with coordinates and no marker at all, say), the controller stops and reports to Matt, with what was seen, before building the fix. The rest of this project (section 5) does not wait on it.

### 4.3 The fix

- **A shared pin takes the chosen place's name** while one of its places is chosen, whether it was chosen in the list, by a chapter (5.5) or from "At the same spot". With none of its places chosen, it is titled as today (its most-mentioned place). The count monogram stays. **(call)**
- **The chosen pin is drawn above its neighbours**, so no neighbouring marker hides it or its title. How (the order of the map's content, or what MapKit offers for a selected marker) is the builder's; it is checked live (4.2's places, after the fix).
- **On the phone, the chosen pin is kept clear of the sheet.** `reveal` treats the part of the map under the sheet as out of view, so a chosen pin under the sheet is panned up into the visible part. It still pans at the same zoom, as today. While there, the map's padding follows the sheet at the large detent too (the backlog's "does not refresh the map's padding at the large detent"). **(call)**
- **A gathered pin clicked while one of its places is chosen** shows its places ("7 places here"), as a click on it does with nothing chosen. Today the click does nothing (the backlog's "Places on the Mac"); it is the same code. **(call)**
- **"At the same spot"** stays where it is, on the place's page under the map, listing the other places at that point; it is how the reader moves between them. No new section. **(call)** (The mockup drew it under the map; that is where the page already is.)

## 5. Ordering the list

### 5.1 The control

Project 3 gives People's list a two-way switch, **Most named** and **A to Z**, at the head of the list. Places takes the same control with a third choice, **By chapter**. On the Mac it sits at the head of the list column, above the rows; on the phone, at the head of the sheet's list, under the count line ("101 places · 101 on the map"). It is the system segmented `Picker`; where three segments do not fit (the Mac's column at large text, the phone at accessibility sizes) it becomes a menu of the same three choices **by a measured width threshold, as the Notes window's filter does** (`NotesBrowserView.swift:249-280`), not by `ViewThatFits`. **(call: one way of switching to a menu in the app, already proven there.)**

### 5.2 Most named

Today's order: verses naming the place in this book, most first, then name, then id (`BibleStore+Library.swift:214-227`). "Not on the map" stays at the foot.

### 5.3 A to Z

By name in the reader's language order (`localizedStandardCompare`, so case and accents do not split the list), then by the data's label for two places of one name, then by id. "Not on the map" stays at the foot, as in Most named, so that the rows above it are all the map's. **(call)**

### 5.4 By chapter

- Each chapter that names a place is a **heading**, "Chapter 1", in the group-label voice (`GroupLabel`: `.caption2` semibold upper case, tracked, `ink.verse`), with its place count trailing in `.caption` `ink.secondary`, `.monospacedDigit()`. Chapters that name no place are left out.
- Under it, the chapter's places **in the order the chapter first names them** (the lowest verse naming each in that chapter), ties by name. A place named in several chapters is listed under each: in Acts, 43 of the 101 places are, and the list has 229 rows for them; Joshua has 686.
- A place with no coordinates stays under its chapter (the story is the point here), with "not on the map" beside its name in `.caption` `ink.secondary`. There is no "Not on the map" group in this order. **(call)**
- Rows look as they do in the other orders, without the count (the count is the book's, and here a row stands for one chapter's mention). **(call)**
- **Choosing a place** chooses that place: its page opens under the map and its pin is chosen, as in any order. Only the row clicked takes the selection wash, not the place's rows under other chapters. **(call)**

### 5.5 The map follows the chapter

This is option B.

- **Choosing a chapter.** A heading is a button: a click on it (or ← and → on the Mac, below) makes it the **chosen chapter**, on `accent.wash` at radius `md` like a chosen row. **Choosing a chapter by its heading, or by ← and →, closes the place's page and clears the walk's trail; the map takes the full height, framed to the chapter.** **(call: a chapter chosen as a whole is about the chapter, not the place last shown; full height gives the chapter's pins the room.)** Choosing a place under a heading also makes that heading's chapter the chosen one, and opens the place's page under the map as any choice of a place does.
- **When the map resizes.** Only when a chapter is chosen by its heading or by ← and →, and then as a cut, not an animation. Moving from place to place, across chapters included, keeps the place's page open and the map at half height. **(call: a map that grows and shrinks with every arrow press would be motion that reports nothing.)**
- **A shown place not named in the chosen chapter.** When the place on show is reached another way ("At the same spot", a walk from another page, or Back) and the chosen chapter does not name it, the chosen chapter moves to **the place's first chapter in this book**. When the place is not in this book at all (a whole-Bible page), the chosen chapter clears and the map shows the whole book. Either way the wash goes on the place's row under that chapter, scrolled into view. **(call: the list and the map must never disagree about which chapter is shown.)**
- **The header line** of the view, while a chapter is chosen, reads "Chapter 1 · 6 places" in place of "101 places · 101 on the map". A chapter whose places all lack coordinates reads "Chapter 5 · 2 places, none on the map", and the map shows only the dots. **(call)**
- **The map** shows the chosen chapter's places as its pins: gathered by point as always, counted over the chapter only (so in Acts 1 Jerusalem's pin holds Jerusalem, Judea and Akeldama: "3"). It frames them by the rule it uses for a book (`BookPlaces.swift:40-55`), applied to the chapter's pins. Every other place of the book is a **small dot**: a scaled circle of about `xxs` (4 pt) in `ink.tertiary`, no label, not choosable, hidden from VoiceOver. **(call: the dot's size and colour)** A dot is drawn with the map's own content (an `Annotation` or a map circle), never as a view over the map.
- **The rows of other chapters** stay in the list, their names in `ink.tertiary`, as the front page dims books that do not match a search; a click on one chooses that place and makes its chapter the chosen one. **(call)**
- **Back to the whole book.** Choosing the chosen heading again, or choosing another order, returns the map to every pin and the book's frame, and the header to its count line.
- **The keyboard, on the Mac.** ↑ and ↓ move between **place rows only, skipping headings**, choosing each place as today; crossing into the next chapter's rows makes that the chosen chapter and keeps the place's page open (the map stays at half height). **(call: ↑ and ↓ stay "the next place", as they are in the other orders.)** **← and → step to the previous and next chapter's heading** and choose it as a click on it does (the page closes, the map is full height), while the list holds the keyboard; they stop at the first and last chapter. **(call: ← and → do nothing in the list today, and AeroSpace does not take them.)** Esc keeps its meaning (back to Contents); it does not first clear a chapter. **(call: no existing key changes.)**
- **The camera** moves to the chapter with `.smooth`, as it moves to hold a chosen place in view, and cuts under Reduce Motion. Stepping chapters quickly must not queue a train of moves: the camera goes to the last chapter chosen. **(call)**
- **The phone.** The sheet's list has the same control, the chosen heading's wash and the other chapters' dimmed rows. Its place rows keep no chosen state (a tap pushes the place's page, as today). **(call: the phone's list rows have never had a chosen state.)** Tapping a heading chooses the chapter; the map above the sheet frames the chapter within the part of the map the sheet leaves visible (as 4.3); the dots likewise. **To step chapters the reader goes Back to the list and taps another heading; there are no arrows.** **(call: no new control on the phone.)** The sheet's detents are unchanged, and the sheet stays at the detent it was at.
- **Remembering.** The chosen chapter is part of the Library's "as it was" when the reader comes back from a passage (Back returns to the same chapter), as the chosen place is today. It is not kept across launches. **(call)**

## 6. VoiceOver

- The control is the system's and reads as one.
- A heading is a button with the header trait: "Chapter 1, 6 places", with the selected trait while it is the chosen chapter.
- A row under a heading reads as a row does today; in By chapter its hint names the chapter ("in chapter 3"). **(call)**
- When the chosen chapter changes, the header line's new text is announced ("Chapter 2, 13 places"). **(call)**
- Dots are hidden. The system `Marker` still takes no label (backlog).

## 7. The data

No change to the Bible database (schema version 5 or whatever project 2 leaves it at).

- **Source:** `place_verse(verse, place_id)`, one row per mention, `verse` = book × 1,000,000 + chapter × 1,000 + verse, indexed on `(place_id, verse)`; `place` has the coordinates, `point` (the 0.001° key), `approximate` and `verse_count`.
- **New read:** a book's places by chapter, with each place's first verse in each chapter:
  `SELECT place_id, verse / 1000 % 1000 AS chapter, MIN(verse % 1000) AS first FROM place_verse WHERE verse BETWEEN :book * 1000000 AND :book * 1000000 + 999999 GROUP BY place_id, chapter ORDER BY chapter, first`
  joined to the places the view already loads. A method on `BibleStore`, with the existing per-book read beside it.
- **Figures** (measured 2026-11-22 and 2026-11-23 on `Build/bible.sqlite`):
  - 1,287 places; 26 have no coordinates; 511 are approximate, all with coordinates; none at 0,0 or out of range.
  - Acts: 101 places, all on the map; every one of its 28 chapters names a place; 43 places are named in more than one chapter; 229 place-and-chapter rows; one place is named in 22 chapters. Its Jerusalem pin gathers Jerusalem (57 verses), Judea (13), the Beautiful Gate (2), Solomon's Portico (2) and Akeldama (1). Chapter 1, in first-mention order: Jerusalem, Judea, Samaria, Galilee, Mount of Olives, Akeldama (6). Chapter 2 names 13.
  - Genesis: 119 places, 8 without coordinates; 44 of its 50 chapters name a place; 39 places in more than one chapter; 233 rows; chapter 10 alone names 20.
  - Joshua: 434 places, 202 of them in 76 shared pins; 686 rows.
- **Speed:** the read is one indexed scan of one book's mentions (686 rows at most). Measure Joshua By chapter, list and map together, before the first review, and pin a benchmark to it.

## 8. What is stored

- **One device preference, new:** the Places list's order (Most named, A to Z or By chapter), in `UserDefaults` on each device, not synced, default Most named. It is **its own value, not People's** **(call)**: People has no By chapter, and a reader who groups places by chapter may still want people by mentions. **Approved by Matt, 2026-11-23** ("Yes, all three (Recommended)", asked for the pane width, People's order and Places' order together).
- Nothing in the synced store, and no synced preference.

## 9. Design changes (DESIGN.md, in step with the build)

- **Library views › Places:** the list's order control (three choices; a menu where they do not fit); A to Z and By chapter as above; under By chapter the chapter headings, the header line's "Chapter 1 · 6 places", the map's chapter pins and the book's other places as `ink.tertiary` dots, other chapters' rows dimmed, ← and → between chapters, Back keeping the chapter.
- **Library views › Places, the pin:** a gathered pin is titled with its chosen place while one of them is chosen, and the chosen pin is drawn above its neighbours.
- **iPhone › Library › Places:** the sheet's control and chapter behaviour; the chosen pin kept clear of the sheet.
- **Motion:** "The Places map's camera" gains the move per chapter (still `.smooth`, a cut under Reduce Motion).
- **Don't:** the existing "Don't float a card, a callout or a sheet over the map" stays as written; add that a chapter's dots are map content, not views over it.

## 10. Constraints

- `CLAUDE.md`, `PRODUCT.md`, `DESIGN.md`, and the handover's "Rules that bind every session here". `/impeccable-swift` for every UI change.
- Palette tokens only, `AppSpacing` and `AppRadius` by name, `@ScaledMetric` for any size tied to text, no `.font(.system(size:))`.
- **A test never makes a `Map`** (handover, "Things that cost time"). The chapter behaviour lives in a model the tests drive (as `PlacesSelection` does today); the map view only reads it.
- Builds before project 3's switch exist will not compile against this spec: **project 3 must be merged into the branch first.** Project 3 sets the dictionary entry's first-paragraph rule and the verse runs written one line per chapter; if it has not already applied them to a place's page, this project does. **(call)**
- The Mac live pass follows the handover's rules for Matt's Mac. The simulator: answer no notice and change no synced setting there.

## 11. Left to the builder

- How the chosen pin is raised above its neighbours (4.3), as long as a live look confirms it.
- The dot's exact drawing (an `Annotation` with a small circle or a `MapCircle`), within 5.5's look.
- How the camera's moves are coalesced when chapters are stepped quickly.
- The menu form's threshold for the control (5.1).
- Where the chapter grouping is computed (the store or the view model), so long as it is tested without a `Map`.
- The name of the stored preference's key.

## 12. Backlog

Lines this project adds to `docs/BACKLOG.md` (in the commit that adds this spec):

- Under "The Library and study data": **Approximate places drawn differently on the map.** 511 places have a position the data marks Rough or only related to a known place; the map draws them like precise ones and only the page says "approximate". Milestone 11 project 4 non-goal.

Lines it changes when it is built:

- **"Places on the Mac"**: remove "Clicking a gathered pin while one of its places is chosen does nothing ("At the same spot" is the way back to its siblings);" (4.3). The rest of the line stays (the camera on a window resize, Acts's 101 overlapping pins, the tiles' modern labels).
- **"The phone's Places sheet"**: remove "does not refresh the map's padding at the large detent;" (4.3). "The quarter detent is unseen" stays unless the build's live look sees it.

Unchanged: "Paul's journeys and other routes on the map", "A list to browse of every person or every place", "VoiceOver on a gathered pin", "The map's zoom and the Library's scroll offset kept on coming back".

## 13. Verification

**Automated** (the package suite and the iOS suite, both passing):

1. The pin's title: with no place chosen, a gathered pin is titled with its most-mentioned place; with Solomon's Portico chosen in Acts, the Jerusalem pin is titled "Solomon's Portico" and still counts 5; choosing Jerusalem again titles it "Jerusalem".
2. Choosing a place in a gathered pin from the list, from a chapter heading's rows and from "At the same spot" all select the shared pin and title it with that place.
3. A gathered pin clicked while one of its places is chosen lists its places.
4. The orders, on the real Bible (tests that need `Build/bible.sqlite`, as today's do): Acts Most named begins Jerusalem, Caesarea; A to Z is alphabetical with twins kept apart by label; By chapter has 28 headings, chapter 1 lists Jerusalem, Judea, Samaria, Galilee, Mount of Olives, Akeldama, chapter 2 has 13 places, and the list has 229 place rows; Genesis By chapter has 44 headings and keeps its 8 unlocated places under their chapters.
5. The chapter model: choosing a heading sets the chosen chapter, the header text, the chapter's pins (Acts 1: Jerusalem's pin counting 3) and the dots (every other place of the book), closes the place's page and clears the trail; choosing it again, or another order, clears it; ← and → do the same as a heading and stop at the ends; ↑ and ↓ skip headings, and crossing into the next chapter's rows moves the chosen chapter with the page kept open; a place shown from "At the same spot" or Back that the chosen chapter does not name moves the chapter to its first chapter in the book, and a place outside the book clears it.
6. The phone's `reveal` treats the sheet's cover as out of view: a pin under the medium detent is panned into the visible part.
7. The stored order: set, relaunched (a fresh model), read back; default Most named; not in the synced keys (the synced-preferences count test still passes unchanged).
8. A benchmark of Joshua By chapter (the largest), list and pins.

**Live, by the controller** (one pass, keys only on the Mac, after 4.2's first pass): Acts By chapter, ← and → through the first five chapters, the camera and the dots; Solomon's Portico chosen shows its name on the pin; Joshua, a place in a shared pin. In the simulator: Acts By chapter with the sheet at medium, a heading tapped, the chapter framed above the sheet.

**For Matt** (his list when it is built): the place he saw fail, if he names one; Acts and Joshua By chapter on both devices, stepping chapters; Back from a passage returns to the same chapter; the switch's three choices at large text; VoiceOver on a heading; Dark and Sepia on the dots.

## 14. As built

Built 2026-11-23, unattended, in nine tasks, two live fixes and this record on `milestone-11-ui-improvements` (the plan `ba6bdd2`, its pre-flight rulings `545bf39`, the build `545bf39..ccae3c6`), each task reviewed by a second model and fixed where it found something. The whole-project review (Opus) and Matt's look come after this section was written; the controller amends it, and the milestone box, to what the review finds. The record's counts are this task's runs; the controller's final runs follow the whole-project review and may update them.

**Built, file by file** (sources under `Packages/ScriptureKit/Sources/`, tests under `Packages/ScriptureKit/Tests/`; no schema change, the Bible database stays at 6).

- `ScriptureData/BibleStore+Library.swift`, `LibraryRecords.swift`: `placeChapters(inBook:)`, one read of every (place, chapter) with the chapter's first verse and verse count; `PlaceChapterMention`.
- `ScriptureUI/Library/LibraryOrder.swift`: `PlacesOrder` (Most named, A to Z, By chapter; key `libraryPlacesOrder`), `PlacesOrderControl` (the measured threshold: 210 on the Mac, 285 on the phone, never segments at an accessibility size), `LibraryOrderPicker(asMenu:)`, `LibraryNameOrder.precedes`, the one comparator shared by People's and Places' A to Z (ruling 8b).
- `BookPlaces.swift`: `Chapter` (places, pins), `onMapByName`, `notOnMapByName`, `pins(inChapter:)`, `dots(inChapter:)` (by point), `frame(inChapter:)`, `framing(chapter:)`, `PlacesFraming`, `Pin.title(choosing:)`. `PlacesSelection.swift`: choosing over the pins in effect, `following`, `gathered`, `reopen`.
- `PlacesList.swift` (new): the list's rows and headings in each order, dimming, the chosen row, `neighbour` (built on People's, now generic: ruling 8a). `PlacesChapters.swift` (new): the chapter rules (following, headings, header line, spoken forms, announcement, `countLine`, `effective`, `afterOrderChange`, `step`, `takesChapterKeys`) and `LibraryPlace`'s `chooseChapter`, `choosePlace`, `followed(in:)` and `clearChapter`. `LibraryPlace.swift` (`placesChapter` itself), `LibraryView.swift`: the chapter kept with the place (so Back returns to it), the header's count.
- `LibraryPlacesList.swift` (new): the Mac's list only: control at the head, headings, rows, keys (↑ ↓ ← →), scroll to the chosen row; the statics both apps use (`sharedNames`, `detail`, `accessibilityLabel`) stayed in `LibraryPlacesView.swift` (pre-flight ruling 15). `PlacesChapterHeading.swift` (new): the heading. `LibraryPlacesView.swift`: the scaled 232 pt column, the map and selection over the chapter's pins, the announcement. `LibraryHeaderView` (in `LibraryView.swift`, no file of its own): the header line taken out of `LibraryView.header(_:)` unchanged. `LibraryListRow` gained a count that can be absent, a note, dimming and a hint; `LibraryPeopleView.neighbour` is generic.
- `PlacesMapView.swift`: the chapter's pins and dots, the framing and the camera's moves (coalesced by a generation, `.smooth`, a cut under Reduce Motion), the chosen pin titled, drawn last and its title forced visible, the others' hidden while it is chosen (the fix wave), the re-click through `MapReader` (`reopenTapMask`: the map's own gestures stay), `region`, `framed` and `canReveal` with a `bottomCover` for the phone.
- `Phone/PhonePlacesList.swift` (new), `PhonePlacesScreen.swift`, `PhoneLibraryPages.swift`, `PhoneLibraryRow`: the sheet's count line, control, headings and dimmed rows, the chapter in `PhoneLibraryPageMemory.placesChapters` (kept across a lookup, dropped when Places is popped), the cover followed at every detent and settled once a turn after a detent change.
- Live fix (`8b3ab6c`, `0d2b4e9`): `LibraryEscapeRule.writing(_:over:)` in `FrontPageView`'s setter and `followed(in:) -> LibraryPlace?` in place of a mutating `follow`; `PlacesMapView.titleVisibility`.
- Tests: `PlacesOrderTests` (with `PlacesOrderControlHostTests`, the measured control), `PlacesChaptersTests`, `PlacesSelectionTests`, `PlacesMapRulesTests`, `PlacesRealDataTests` (the real database, `.needsRealBible`), `LibraryViewRulesTests`, `PhoneLibraryRulesTests`, `BibleStoreLibraryTests` (`placeChapters`) and `LibraryBenchmarkTests`.

**The data, checked** (against `Build/bible.sqlite`, schema 6; pinned by `PlacesRealDataTests` where a test is named). Acts: 28 chapter headings, 229 place rows; chapter 1 lists Jerusalem, Judea, Samaria, Galilee, Mount of Olives, Akeldama; chapter 2 has 13 places; Acts 1 has 4 pins (Jerusalem's "3") and 91 dots; Acts's largest chapter is 27 (20 places). Genesis: 44 headings, 233 rows, its 8 unlocated places under their chapters; chapters 3 and 4 name one place each and neither is on the map; its Rehoboths sort 992, 990, 991 in A to Z (their labels are verse references); the two Valleys of Shaveh share Jerusalem's point. Joshua: 24 headings, 686 rows; its 3 unlocated places make 6 rows (Judah, 1280, has 15 verses in chapter 15). Task 1's real-data pin counts: 76 shared pins holding 202 places. Chapter 4's frame in Acts is centred 32.241967, 35.268253 and spans 1.301378 by 0.5 (Jerusalem 31.777189, 35.234978; Nazareth 32.706745, 35.301528). **Where this differs from the spec:** Genesis 14 names 27 places, more than chapter 10's 20; the all-off-map chapters are Genesis 3 and 4; Acts 1 shows 91 dots by point, not 97; the sort's line numbers moved. No figure spec 13 pins is wrong (28 headings, 229 rows, 44 headings, 8 unlocated, chapter 2's 13).

**The control, measured** (Task 4, the SwiftUI `Picker` `.segmented`, label hidden, three titles). Mac, `.small`: 210 pt at the least (`sizeThatFits` at a 1 pt proposal), 249 pt ideally (`fittingSize`); People's two 134 and 166. In People's 184 pt inside the three overhang by 13 pt each side, so Places' list column is a scaled **232 pt** (inside 216, 6 pt of slack; pre-flight ruling 1 replacing Departure 2: the plan had the Mac show a menu at the default size). iPhone (iOS 27.2 simulator): 285 pt at `.large`, `.xLarge`, `.xxxLarge` and `.accessibility1` alike, since the control's text does not scale; the sheet's inside is 354 pt, so the phone shows segments from `.large` up to the largest non-accessibility size and a menu from the accessibility sizes.

**Calls (call, unattended).** Matt was away, so none was asked; each is built as written and may be changed. First the plan's departures (numbers as in the plan), each with its cost if wrong.

1. **Step 0 was not repeated live on the Mac:** the simulator pass confirmed the cause on the data's own case (Acts, a pin titled with its most-mentioned place); Joshua and Genesis's Luz were left to the after-fix pass. *Cost:* none; the cause matched spec 3.1.
2. **The Mac shows the three segments, not a menu** (replaces the plan's Departure 2, pre-flight ruling 1): Places' list column is a scaled 232 pt, 32 pt wider than People's. *Reason:* the spec's rule lists the menu only for large text and accessibility sizes. *Cost:* the hairline moves when the reader switches between People and Places and the map is 32 pt narrower; one constant back to 200 and a menu shows.
3. **The phone's control is a menu at any accessibility size and wherever its measured width passes the sheet's inside** (354 pt). *Cost:* one condition.
4. **The read counts each chapter's verses** (`count(*) AS verses` beside `MIN(verse % 1000)`), so a chapter's pins are weighed by that chapter's mentions; ties are broken by name in Swift. *Cost:* none.
5. **A chapter's pin keeps the book's order of its places,** so with none chosen it is titled with the book's most-mentioned of them (Acts 1: "Jerusalem") and its monogram counts the chapter's places ("3"). *Cost:* none seen.
6. **Dots are by point:** every book pin whose point holds no pin of the chapter is a dot, so a point with a chapter pin draws none (Acts 1: 4 pins, 91 dots). *Cost:* none; two dots at one point draw as one.
7. **A chapter with no place on the map frames the whole book** (its dots), with no pins; the header reads "Chapter 3 · 1 place, none on the map" (Genesis 3); a chapter with some places off the map reads only its count. *Cost:* wording.
8. **Choosing the chosen heading again, while it shows its wash, clears the chapter only:** whatever is on show stays, and the camera frames the book. "Again" means the washed heading: with a row of the chapter chosen its heading shows no wash (call 25), and a click on it chooses the chapter as a click on any heading does (the page closes, the map takes the full height and is framed again; the fix wave, review I2). A place of the book on show always has its row chosen, so on the Mac a washed heading never has one on show; the rule keeps the trail all the same (`theWashedHeadingAgainClearsTheChapterAndKeepsThePlace`). On the phone rows keep no chosen state, so a chosen heading always shows its wash. *Cost:* none seen.
9. **← and → with no chapter chosen** take the first and the last chapter; **↑ and ↓ under By chapter always make the row's chapter the chosen one,** the first step after switching to the order included. *Cost:* one branch each.
10. **Switching to By chapter chooses no chapter;** a place on show keeps its page, its wash goes on its row under its first chapter and the map stays the book's; another order clears the chapter and keeps the place; the chapter is in effect only under By chapter. *Cost:* none.
11. **A chapter change by a place** (a row of another chapter, ↑ ↓ across a heading, or the follow rule) reframes the map to the new chapter at half height with the chosen pin held in view. Spec 5.5 does not say whether a place's chapter change reframes. *Cost:* a camera move a reader may not want; one condition.
12. **The chosen chapter lives in `LibraryPlace.placesChapter` on the Mac** (so Back returns to it) **and in `PhoneLibraryPageMemory.placesChapters[book]` on the phone;** nothing is kept across launches. *Cost:* none.
13. **Headings take clicks as rows do** (`onTapGesture`, button and header traits, an accessibility action), so the Mac's list stays one Tab stop.
14. **"not on the map" stands where a row's count would** (trailing, `.caption` `ink.secondary`); a dimmed row dims its name and detail to `ink.tertiary`. *Cost:* the note's place.
15. **The re-click on a gathered pin** is read through `MapReader` (a simultaneous `SpatialTapGesture`) when it falls on the chosen marker's balloon, and acts a turn later only while the map's selection is still that pin and only clears the trail if `reopen` changed the selection (pre-flight ruling 9). **Not confirmed:** in the simulator MapKit gave the taps on a chosen "3" and "2" to an overlapping neighbour, whose page opened and stayed open (the guard holds); the Mac pointer click was never made. *Cost if it fails:* the backlog's line stands.
16. **The chosen pin is drawn last** in the map's content so MapKit draws it above its neighbours. Seen to hold on the Mac in Acts (Solomon's Portico, Jerusalem, Judea) with the page staying open (pre-flight ruling 12: no nil echo). It did not lift the title in dense clusters (see For Matt, 1).
17. **The phone's cover is judged in the region MapKit reports for the whole map:** a pin is in view only above the sheet by a marker's clearance and is moved to the middle of that part at the same zoom; a chapter is framed into that part. Seen in the simulator: nothing high by half the cover, nothing under the sheet. *Cost:* a fix-wave line.
18. **The camera's moves are coalesced by a generation:** each starts after one turn of the main run loop and a move whose generation is no longer the latest is dropped. Seen on the Mac: → four times fast made one move.
19. **The dot** is an untitled `Annotation` (`anchor: .center`) holding a `Circle` a scaled `xxs` across (`@ScaledMetric`, relative to `.caption`) in `ink.tertiary`, not choosable, hidden from VoiceOver: one SwiftLint `accessibility_hidden_on_text` finding, which spec 6 requires. On the Mac at a chapter's zoom the dots read like the map's own unlabelled town dots. *Cost:* a size and colour Matt may want changed.
20. **VoiceOver:** a heading is one element, "Chapter 1, 6 places", button and header traits, selected while chosen; a row's hint under By chapter is "in chapter 3"; the header line's new text is announced on every change of the chosen chapter by any route, and the book's count when it clears, in its spoken form, "101 places, 101 on the map" (ruling 14; until the fix wave it was the line as shown, with its middle dot). Never heard.
21. **The header line is its own view,** `LibraryHeaderView`, so a render can host it alone (a hosted `LibraryView` on Places would make a `Map`).
22. **The speed checks:** `joshuasPlacesLoad`, `joshuaByChapterListOpens` (the list column hosted alone) and `joshuasChapterFifteenMapContent`; bounds are 1.5 times the largest of three runs' medians rounded up to 10 ms (Task 9). The map itself is never measured.
23. **The spec's figures that differ** are in "The data, checked".
24. **The Mac live pass did reach Places by keys.** The plan's premise (the pane's icons are not Tab stops, pre-flight ruling 5) was wrong: Tab from the contents reached the Places icon and Space opened it. DESIGN's About "Keyboard" line and the backlog's "About has no key route on the Mac" line were wrong and are corrected or gone. *Cost:* none.

The build's own calls, each **(call, unattended)**, from the ledger's rulings and the task reports:

25. **The chapter heading's wash shows only while no row is chosen;** its selected trait stays (`PlacesList.headingIsChosen` and `headingShowsWash`). *Reason:* spec 5.4, "only the row clicked takes the selection wash"; the review's Important 1 was the trait following the wash, fixed. *Cost:* the heading of a chapter with a chosen row shows no wash, so a click on it chooses the chapter rather than clearing it (call 8).
26. **↑ and ↓ start from a chosen heading** when no row is chosen: ↓ takes the chapter's first row and ↑ the row above the heading (Task 6). *Reason:* otherwise ↓ after → jumps to the list's first row. *Cost:* one branch.
27. **Dimmed rows are `ink.tertiary`** (spec 5.5), and DESIGN's Tertiary line was given the exception, as the front page's search dimming has it (the Task 4 review's Important 2, kept as built). *Cost:* rows dimmer than 4.5:1 that are still choosable.
28. **The phone's heading is an inset band, at least a scaled 44 pt high:** `xs` inside and `lg - xs` outside so its text sits at `lg` like the rows (Task 7), the height in Task 9. *Cost:* a band where the Mac has a wash on the column.
29. **Mac Sepia: the chosen heading's wash reads teal** (`accent.wash` has no Sepia value, as People's); Task 9 left it for Matt's eye. **The phone's Sepia never rendered** (the scene-less render came out identical to Light).
30. **A step to the same place under another chapter keeps the page and its open verses** (ruling 19), and `LibraryPlace` joins its chapter into its equality (ruling 26).
31. **Esc from Places:** a write once the view is closed opens nothing (`LibraryEscapeRule`), the list writes its chapter only for a change. The cause was new in this project (Task 4's `follow`, a mutating call that always wrote), found by the first live pass and fixed at the root and guarded for an older path (the map's teardown nil with a gathered pin chosen).
32. **The chosen pin's title is forced visible** (`.annotationTitles(.visible)`, the chosen marker only; the others keep MapKit's automatic titles). Forcing it visible did **not** lift the title in Joshua's Jordan or Acts 2's Nazareth. The fix wave's review I1 tried hiding every other marker's title while a pin is chosen; it was checked live (Joshua, Jordan chosen) and **reverted**: the other titles vanished but Jordan's own was still not drawn, because MapKit draws titles beneath every balloon, and hiding every other name while a place is chosen is behaviour the spec never asked for. **The chosen title in a dense cluster remains a known limit** by ruling: the chosen pin is found by its size and place on top, not its name, until the reader zooms. What is left is a plain-text label of the chosen name drawn as map content (not built: a label readable on the tiles needs a halo or a backing, DESIGN bans shadows and spec 2 bans a chip or callout) or zooming on a choice (against "at the same zoom"). *Cost:* in a dense cluster the chosen pin's name is not drawn until the reader zooms (backlog; first on Matt's list).
33. **Every camera move goes through the one queue and waits a turn,** the focus's included, so a chapter change and a place change in one update make one move. **The framed move sets the region it commands** so a following resize is judged against where the camera is going.
34. **The phone's map is given a settled cover,** written when the sheet opens and a turn after each detent change, while the padding follows every height tick (ruling 10); `framed` fits by the latitude MapKit will show; where there is no room above the sheet (the large detent) a chapter is framed as if there were none and framed again when the sheet settles lower. A chapter the map opens at (kept on coming back from a lookup) is framed again above the sheet once the sheet first settles (the fix wave, review I3; before it, the chapter opened with its lower half under the sheet). *Cost:* the book's first frame on opening is still partly under the medium sheet (nothing was chosen).
35. **The re-click gesture stays attached with a mask** (`.all` with a reopen, `.subviews` without) so the whole-Bible maps and the phone before Task 7 keep the map's own gestures (the review's Important 1).
36. **The order menu is tinted the accent** (it was system blue at the accessibility sizes). **A gathered pin's rows on the phone** go through the row choice with no chapter, so the chapter does not change.
37. **Task 7 wrote its code before its tests,** and its count-line test could not be red (the helper already existed from Task 3).

**How the build was run** (process, each a call, unattended). The head counts (package 1,678, iOS 1,134) were project 3's final runs, not re-run, since only docs changed after. Of the 28 pre-flight rulings, 1, 5, 9, 12, 14 and 19 are recorded above (calls 2, 24, 15, 16, 20 and 30); 8 and 13 are in the file list; the rest were interface notes taken as the plan's items. The controller's live passes were batched: one on the Mac after Task 6 and one in the simulator after Task 8, each launched with `-libraryPlacesOrder byChapter` so Matt's preferences were not written. Fix rounds: Task 4 one, Task 5 one, Task 9 one and one live fix; Tasks 1, 2, 3, 6, 7 and 8 none. A harness stop in Task 4's round was resumed on the coordinator's word.

**Checkers** (from the worktree root; baseline 74, 27, 0). SwiftLint **71** (the four old findings in `LibraryPlacesView.swift` are fixed, 74 to 70 at Task 4, and the dot's one `accessibility_hidden_on_text` is the plus one, 71 from Task 5); impeccable-lint **27** (unchanged); asset checker **0** (exit 0). In the new and touched files none, but the dot's.

**Benchmarks** (`LibraryBenchmarkTests`, each alone, the median of nine runs, debug build; Task 9's figures are three runs each at a load average of 3.4 to 3.6).

| | Before | After | Bound |
|---|---|---|---|
| Joshua's Places load (read and model) | 4.9 to 5.0 ms (Task 1) | 9.7 ms (Task 1, lighter load); 13.3 to 13.4 ms (Task 9) | 30 ms |
| Joshua By chapter, list column open (232 by 760, chapter 15) | new | 27.4 and 34.8 ms (Task 4); 30.0 to 32.6 ms (Task 9) | 50 ms |
| Joshua chapter 15's map content (pins, dots, draw order, framing, items) | new | 0.4 ms | 10 ms |
| About Genesis, open (unchanged) | | 46.3 ms | 300 ms |

The load doubled with the extra read, the chapters model and two name sorts, and is nowhere near its bound. The Task 9 review found its commit had changed `aboutGenesisOpens`' bound from 300 to 50 by mistake; restored (`ccae3c6`). The list-open bound has no slack under full-suite load (backlog).

**Suites** (this task's runs on the commit this record sits on, code `ccae3c6`; the controller's final runs follow the whole-project review): package **1,730** passed (1,308 + 241 + 52 + 96 + 33; one timing benchmark, `peopleInFirstChroniclesOpensWithItsFirstPersonChosen`, failed once under the full run's load and passed alone); iOS `ScriptureUITests` **1,182** passed. The Mac Debug build succeeded at each task's last run (the build was not re-run for this docs-only task). Per task, package 1,686, 1,695, 1,706, 1,711, 1,717, 1,721, 1,724 (live fix), 1,725, 1,729, 1,730; iOS 1,140, 1,149, (Task 3 not quoted), 1,163, 1,169, 1,173, 1,176, 1,178, 1,182, 1,182. The 1 Chronicles People benchmark and other timing benchmarks failed once under full-suite load in several tasks (Tasks 4, 6 and 8, and this run) and passed alone; Task 2's first full run showed one unidentified issue that a clean rerun did not repeat (watched, not chased).

**Seen live** (the controller; keys only on the Mac, taps only in the simulator; no setting or order touched; Matt's preferences not written).

- *Mac* (Debug app at `82177a7`, launched with `-libraryPlacesOrder byChapter`, idle time checked first): ⇧⌘H, ⌘F "Acts", Tab to the pane's Places icon, Space. "Places in Acts" with the three segments in the 232 pt column. → chose Chapter 1 (heading washed, header "Chapter 1 · 6 places", the map full height framed to Samaria, Galilee and the "3" at Jerusalem); → four times fast made one move to Chapter 5 · 2 places; ↓ chose Solomon's Portico (the page open, the map at half height, the "2" selected and titled "Solomon's Portico" whole and on top: pre-flight ruling 12 holds); ↓ Jerusalem titled "Jerusalem"; ↓ across the heading to Antioch, "Chapter 6 · 5 places", the page kept, the map reframed at half height with the book's other places as small grey dots; ← to Chapter 5's heading (the page closed, full height); ← stopped at Chapter 1; ↓ ↓ Judea, the "3" titled "Judea" on top.
- Found there and fixed (`8b3ab6c`, `0d2b4e9`): Esc from Places reopened an empty People view; and in Joshua the chosen Jordan's title was not drawn in the dense cluster. After the fix, Joshua › Places, ↓ Jordan, Esc went to Contents; Jordan's title was still not drawn (known limit).
- *Simulator* (iPhone 18 Pro Max, iOS 27.2, the Debug app at `6492c68`, launched with the argument): Acts › Places at the medium detent, "101 places · 101 on the map", the three segments. Chapter 1's heading: the washed band, "Chapter 1 · 6 places", the chapter framed into the part above the sheet and centred in it; Judea's row: the "3" titled "Judea", large and on top, no camera move; Back kept Chapter 1; Chapter 2's heading: "Chapter 2 · 13 places" framed above the sheet with the dots plainly in Greece and Asia Minor; the sheet dragged to large and back: the pin stayed in view above the sheet. Also seen: Nazareth chosen, its title "Na…reth" partly under the "2" balloon.
- *Mac, after the fix wave* (Debug app at `ed83717`, no argument, so Most named; idle time checked first): Joshua › Places by Tab and Space, ↓ Jordan: the fix wave's I1 hid every other title and Jordan's own was still not drawn, so I1 was reverted (`fc4a187`); Esc went to Contents.
- *Final runs* (one after another, on `5e69355`, the code of this record): package **1,737** passed (1,315 + 241 + 52 + 96 + 33), iOS `ScriptureUITests` **1,189** passed, the Mac and iOS Debug builds succeeded; checkers 71 / 27 / 0. The Mac Debug app was restarted on this build (no argument) at the end.
- *Renders* (offscreen, real store; they cannot show the map, the pointer, a click, focus or its ring, a key, VoiceOver or motion): the Mac's list in all three orders, Acts and Genesis, Light, Dark and Sepia; the header line; the control at 232, 226, 225 and 200 pt; the phone's list in all three orders at `.large` and `.accessibility5`, Light and Dark (the phone's Sepia render came out identical to Light). The controller opened an Acts By chapter render of each.

**Reviews.** Task 4: two Importants (the heading's selected trait tied to its wash, fixed; dimmed rows in `ink.tertiary` against DESIGN's Tertiary line, kept as ruled, call 27) and five Minors; Task 5: one (the added tap's mask disabled the map's own gestures where there was no reopen, fixed, call 35) and two Minors; Task 9: one Critical (the About Genesis bound changed by mistake, restored) and three Minors; Tasks 1, 2, 3, 6, 7 and 8 and the live fix were approved with Minors only (4, 3, 5, 3, 4 and 2). Each fix was re-reviewed clean.

**Final review and fix wave.** The whole-project review (Opus, read-only, `7d943b8..c2f1c3a`; the workspace's `final-review.md`) found 0 Critical, 4 Important and 9 Minor findings and seven errors in this section; its critique scored 30/40 and its checkers 71/27/0. The fix wave (from `ce90456`, one commit to a finding) made: **I1**, every other marker's title hidden while a pin is chosen, tried live and reverted (it did not draw the chosen title; the limit stands, the plain-text label not built, by ruling); **I2**, the chosen chapter's heading clears it only while it shows its wash, and with a row of the chapter chosen a click chooses the chapter, closing the page and framing it again at full height (`PlacesChapters.afterHeading(_:chosen:rowChosen:)`, and `PlacesFraming.choice`, a count of headings chosen, so the same chapter chosen again is a new framing), with **Minor 4**'s test of Departure 8; **I3**, a chapter the phone's map opens at is framed above the sheet once the sheet first settles, never on the Mac and never for the book's own frame (`PlacesMapView.opensWithoutRoom`, `reframes`); **I4**, the re-click guard and the announcement are tested helpers both apps share (`PlacesSelection.reopened(at:in:)`, `PlacesChapters.announcementText`), with **Minor 1**'s spoken count (`BookPlaces.countSpoken`, "101 places, 101 on the map"); **Minor 2**, the Mac's focus ring reset when nothing is washed; **Minor 3**, two tests tightened and renamed; **Minor 6**, the heading's help tag ("Show chapter 6 on the map", washed "Show the whole book on the map", `headingHelp`); **Minor 7**, the list benchmark checks it measured By chapter; **Minor 8**, an `assert` in `chapters(of:_:_:)`; **Minor 5** a backlog line (with the Order control's missing help tag); **Minor 9** accepted (every iPhone's sheet is wider than the control); this section's seven errors corrected. After it: package **1,737** passed (1,315 + 241 + 33 + 52 + 96; the 1 Chronicles People benchmark failed once under the full run's load and passed alone at 156.7 ms), iOS `ScriptureUITests` **1,189**, the Mac Debug build succeeded, checkers 71/27/0. Not yet seen live: I2's click on the Mac, I3 on coming back from a lookup on the phone.

**Minors set aside** for the whole-project review (the backlog's "Places by chapter" section has the ones that outlive it): a silent `compactMap` drop in `chapters(of:_:)`, `onMapCount` computed, no label tie-break in the fixture A to Z, two `removePersistentDomain` calls (Task 1); the `title(choosing:)` test compared to the pin's default title, the long `chapters` signature (Task 2); `isDimmed` true for a chapter-less row while a chapter is chosen (unreachable), no end-to-end test of the follow rule, `afterOrderChange` repeating `effective` (Task 3); the order-change wiring tested only through its pure rule and the heading's trait wiring with no hosted test (Task 4); the one-turn queue merging only same-turn changes, so ← → in separate turns rely on MapKit retargeting (seen working, Task 5); `sheetWidth` starting at `.infinity` and `lg - xs` arithmetic (Task 7); the review's others in each task's review file.

**For Matt**, in the order to look. The first four are the calls he is most likely to overturn.

1. **The chosen pin's title in a dense cluster** (call 32). Open Joshua, Places, and choose Jordan; open Acts, Places, and choose Nazareth under chapter 2's "2". The chosen title is not drawn there: MapKit draws titles beneath every balloon, and hiding the other pins' titles (the fix wave's I1) was tried live and reverted, as it did not help. Would you like a plain-text label carrying the chosen name, drawn as map content? It is not built because a label readable on the tiles needs a halo or a backing (DESIGN bans shadows; spec 2 bans a chip or callout). Or is a title you must zoom for acceptable?
2. **Places' list column is 32 pt wider than People's, to hold three segments** (call 2; the control measures 210 pt at the least, the column's inside 216). The hairline moves when you switch topic and the map is 32 pt narrower. The alternative, a column of 200 and a menu "Most named ⌄", is one constant.
3. **Other chapters' rows are dimmed in `ink.tertiary`** (call 27), as the front page's search dims books; they are still choosable. Is that too faint to read as rows?
4. **The book's other places read like the map's own town dots** (call 19), and **a click on an already-chosen gathered pin was never confirmed** (call 15; in the simulator a neighbour took the taps). Look at Acts 2 and Genesis By chapter on the Mac: do the dots look like part of the map or like noise? Click the "5" with Solomon's Portico chosen.

Then the list to look through, on the Mac and the iPhone:

5. **Acts and Joshua By chapter on both devices, stepping chapters:** ← and → on the Mac; the headings on the phone. The first ↓ from a chosen heading goes to its first row (call 26).
6. **Back from a passage returns to the same chapter,** on both.
7. **The switch's three choices at large text** (the Mac shows the segments at the default size; the phone shows a menu from the accessibility sizes; at `.xxxLarge` the phone still shows segments).
8. **VoiceOver on a heading** ("Chapter 1, 6 places", header and button, selected while chosen), the announcement on a change, and whether the hidden dots are still a VoiceOver element.
9. **Dark and Sepia on the dots,** and the Mac's Sepia wash reading teal on the chosen heading (call 29).
10. **Solomon's Portico's pin named,** and a click on the chosen gathered pin (see 4).
11. **The phone install** (`Scripts/install-phone.sh debug`, his word, the phone unlocked, ProtonVPN off): the sheet's control under the count line, a heading tapped, a pin chosen under the sheet.

Then the calls he may want otherwise: 6 (dots by point), 7 (a chapter with no place on the map frames the book), 8 (the chosen heading again clears only the chapter), 9 (← → with none chosen), 10 (switching to By chapter chooses no chapter), 11 (a place's chapter change reframes the map), 25 (a heading's wash only with no row chosen) and 28 (the phone's heading band).

**What nobody has seen.**

- The fix wave's two behaviours, until the controller's live check: a click on the chosen chapter's heading with a row chosen (the Mac), and a chapter kept on coming back from a lookup framed above the sheet (the phone).
- A pointer click on a marker (the Mac) or a row; the re-click on a chosen gathered pin, on either device (call 15).
- The map's tiles, pins, dots and camera on the Mac were seen by the controller in Light only; the Mac's Dark and Sepia are list renders, never the map's dots.
- Genesis's Luz, and a Joshua place that shares a pin (Jordan stands alone).
- → at the last chapter, ↓ across a heading where the chosen pin goes from several places to one (Acts 1's Jerusalem "3" to a lone Jerusalem), and an open verse list kept on a step to the same place under another chapter (call 30).
- The camera's coalescing under fast keys beyond the one burst seen (→ four times); the camera under Reduce Motion.
- VoiceOver anywhere: the headings, the announcement, the hidden dots (call 20).
- Pans and a marker tap on a whole-Bible map and on the phone's map after the reopen mask (call 35).
- On the phone: a wide chapter, a heading at the large detent, the quarter detent, Reduce Motion, Sepia, and the whole screen on a device (the simulator only).

**After Matt's review of the People page (2026-11-24).** A place's page shares the person's sections, so it changed with them (the people spec's "Matt's review, 2026-11-24" has the detail): its text at the reader's size and in the reader's own column, centred (the map still spans the detail pane above it); its name, kind lines and dictionary entry selectable on the Mac; its section headings Matt's C (a hairline, then the heading in the page face; "At the same spot" among them); "Ch 11" on its verse lines; and "In Acts" and "Elsewhere" one section headed **References**, the book the page was opened from first and open, the rest in Bible order and closed.

**Matt's review, 2026-11-24.** Two changes, both built on Matt's word, neither a choice for him (branch `milestone-11-places-fixes`, from `3ad1fd7`, in the `milestone-11-about-and-notes` worktree).

1. **The phone's sheet never goes past half the screen.** Matt: "on the phone when looking at places I would prefer the sheet that comes up from the bottom never goes beyond half of the screen. I don't want it to extend up and cover up the map. Not when scrolling through places and not when looking at the contents of a page about that place. It should not cover the map." The sheet's detents are now a quarter and half the page (`.fraction(0.25)` and `.fraction(0.5)`, where it opens; `.large` is gone), the same whether it holds the list or a place's page, and a scroll inside it scrolls its content, never the sheet (`.presentationContentInteraction(.scrolls)`; only the grabber moves it). `PlacesSheet.tallestFraction` (0.5) is the one number; `PhonePlacesScreen.detents`, `tallest`, `opening` and `contentInteraction` are read by the tests. The camera still takes the sheet's cover as measured when it settles, so a chosen pin is panned into, and a chapter framed into, the part above the sheet, which is now the upper half of the page at the least; the "no room above the sheet" branch (the large detent) can no longer arise from a detent and stays only for the map's first frame before the sheet settles. Tests: `PhonePlacesSheetTests` (the detents, none `.large`, the scroll) and `PlacesMapRulesTests.atTheSheetsTallestTheMapAboveItAlwaysHasRoom` (on every iPhone height from the SE's 667 to the Pro Max's 956, at the largest text's marker clearance, the part above a half sheet has room and a framed chapter lies wholly above the sheet's top). Supersedes call 34's large-detent framing and DESIGN's "at the large detent the padding follows the sheet and nothing pans".
2. **The chosen place's name is drawn above every marker** (call 32, Mac and iPhone). Matt: "If you have a fix for it, why are you asking? Fix it." The chosen place's name is the app's own label, `PlacesMapLabel`: SF Pro `.caption` semibold `ink.primary` on a plate of `paper.page` at radius `sm` (`xs` across, `xxs` high, both scaled), its top `xxs` under the pin's point and centred on it, where MapKit puts a title; no stroke, no shadow. The chosen marker's own title is hidden (`titleVisibility` is now `.hidden` for the chosen pin, `.automatic` for the rest), so the name is drawn once. Only the chosen pin has a label (`PlacesMapView.chosenLabel`: none with nothing chosen or a pin the map does not draw; a gathered pin's label is its chosen place's name). The label and a chapter's dots share one modifier, `mapDecoration()` (no tap, hidden from VoiceOver), so VoiceOver hears the chosen place once, from its marker.
   - **First tried as map content** (an untitled `Annotation` after every marker, anchored at the point's top): in the simulator, Joshua with Jordan chosen, the label was drawn beneath its southern neighbours' balloons, as MapKit's own title was. **Built instead as a view over the map**, placed by the map's own projection (`MapReader`'s `convert`) and placed again on every frame of a camera move (`onMapCameraChange(frequency: .continuous)` writes the region to `PlacesMapCamera`, an observable only the label's view reads, so the map's own content is not rebuilt on each frame); clipped to the map. It is the one thing laid over the map, and DESIGN's "Don't float … over the map" now names it.
   - Tests: `onlyTheChosenPinsSystemTitleIsHidden` (replacing `onlyTheChosenPinsTitleIsAlwaysShown`), `theLabelIsDrawnOnlyForTheChosenPin`, and on the real data `theLabelNamesTheChosenPlaceInACrowdedCluster` (Acts: Jerusalem's "5" labelled "Solomon's Portico" with it chosen and "Jerusalem" with Jerusalem; Joshua: the Jordan's pin labelled "Jordan" and drawn last).

**Seen** (the simulator, iPhone 18 Pro Max, iOS 27.2, this branch's Debug app, taps only, no setting, note or order changed; the reading place stayed Psalm 23; renders in the session's scratchpad): Joshua › Places opens with the sheet's top at the middle of the screen; Jordan chosen: its page in the half sheet, and "Jordan" on its plate under the chosen balloon, above the dense cluster where no title was drawn before; a scroll in the page scrolled the page and the sheet stayed at half; a drag on the grabber went down to the quarter and, dragged hard up, stopped at half; Acts › Places, Jerusalem chosen: "Jerusalem" under the "5"; then Solomon's Portico from "At the same spot": "Solomon's Portico" under the same "5", the label moving with the map as the sheet's padding moved it. Offscreen renders: the plate in Light, Dark and Sepia (the Mac, `isSepia` set: the plate warms with the page); the list and Solomon's Portico's page at `.xxxLarge` and `.accessibility3` in a frame of half the Pro Max's height: both read and scroll (the order control is the menu at the accessibility size, as before).

**Not seen:** the Mac (Matt is at it; no live pass and no restart: the label's code is the one view both apps share, so the Mac's look is the simulator's, at the Mac's map sizes); Dark and Sepia on the live map (the simulator's appearance was not changed); VoiceOver on the chosen marker with its title hidden (the marker is expected still to read its name, as MapKit's accessibility label comes from the annotation's title, not its visibility; never heard); the label during a fast pan or the camera's `.smooth` move frame by frame (seen only at rest after moves); landscape on the phone (backlog); Nazareth under Acts 2's "2" (the same rule; not visited).

**Checkers** SwiftLint **69**, impeccable-lint **23**, asset checker **0** (unchanged; no new finding: the dot's `accessibility_hidden_on_text` is now the shared modifier's, one finding as before). **Suites** (one after another, on the code of this record): package **1,852** (1,430 + 241 + 52 + 96 + 33; run before `PlacesSheet` moved to a file of its own, no code changed by the move), every Places and phone test passing; three timing benchmarks that never build a map or the sheet failed at a load average of 7 to 13 and again alone at that load (the front page at reader size 28, 101.1 ms against 100; People in 1 Chronicles; David's page, 184 ms against 150, the overrun the handover already names); iOS `ScriptureUITests` **1,279**, every Places and phone-sheet test passing, two Plan benchmarks failing under the same load and passing alone; the Mac and iOS Debug builds succeeded. The Mac Debug app was neither rebuilt in place nor restarted; the simulator's Debug app is now this branch's build (it was project 5's Task 8).

**For Matt:** on the phone, Places in Joshua and Acts: the sheet stops at half when dragged up and while scrolling the list or a place's page; Jordan and Solomon's Portico named on the map. On the Mac, the same two names, and whether the plate reads well on the muted tiles in Dark and Sepia.
