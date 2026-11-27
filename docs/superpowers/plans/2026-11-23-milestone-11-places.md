# Milestone 11, Project 4: Places Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task: one fresh implementer and one fresh task reviewer per task, on the model each task's **Run** line names (no Fable anywhere in milestone 11), then one whole-project review on Opus with its report written to a file, one fix wave and one scoped re-review. Steps use checkbox (`- [ ]`) syntax for tracking. The ledger is `.superpowers/sdd/2026-11-23-milestone-11-places/progress.md`.

**Goal:** A place chosen in the list, by a chapter or from "At the same spot" is always seen on the map as a pin bearing its own name, above its neighbours and clear of the phone's sheet; and the Places list reads three ways (Most named, A to Z, By chapter), with the map following a chosen chapter (its places as pins, framed; the rest of the book as dots) and the Mac stepping chapters from the keyboard.

**Architecture:**
- **Data, no schema change.** One new read, `BibleStore.placeChapters(inBook:)`, each place's first verse and verse count in each chapter of a book. `BookPlaces.load` makes it beside the existing per-book read and builds, once per book, the A to Z order, the chapters (each with its places in first-mention order and its own pins) and nothing else.
- **Pure models in `ScriptureUI/Library`, each tested without a view and never with a `Map`:** `PlacesOrder` (the stored order), `PlacesOrderControl` (the measured switch to a menu), `PlacesList` (the list's items in each order, the chosen row, dimming, ↑ ↓), `PlacesChapters` (the chapter rules: heading, follow, ← →, the header line and VoiceOver words), `LibraryPlace.placesChapter` (the chosen chapter, part of the Library's "as it was"), `PlacesSelection` over the pins in effect (with the re-click), `BookPlaces.Pin.title(choosing:)`, and `PlacesMapView`'s static rules (draw order, chapter framing, the sheet's cover, the camera's coalescing).
- **Views.** The Mac's list column becomes `LibraryPlacesList` (hostable without the map) with `PlacesChapterHeading` (shared with the phone); `LibraryOrderPicker` takes a menu form; `LibraryListRow` and `PhoneLibraryRow` take a row with no count, a note and a dimmed ink; `PlacesMapView` reads the pins, dots, framing and chosen place it is given and decides nothing about chapters. The phone's sheet list becomes `PhonePlacesList`; the chosen chapter rides in `PhoneLibraryPageMemory`.

**Tech Stack:** Swift 6.2, SwiftUI, MapKit for SwiftUI, GRDB, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-23-milestone-11-places-design.md` (approved 2026-11-23). Section numbers below are the spec's. Mockup: `docs/superpowers/specs/milestone-11-mockups/places.html` (section 1, the fix; section 2, option B, Matt's choice). Handover: `docs/superpowers/specs/2026-11-23-milestone-11-handover.md`, run unattended.

**Step 0 is done (spec 4.2).** The controller confirmed spec 3.1's cause live in the simulator on 2026-11-23: in Acts, choosing Judea or Solomon's Portico selects the gathered "5" pin titled Jerusalem, and the title's start is hidden under a neighbouring marker. Matt was not asked (unattended). This plan builds 4.3 directly; the after-fix live checks are the controller's.

Paths: `PK` is `Packages/ScriptureKit`; `DATA` `PK/Sources/ScriptureData`; `SUI` `PK/Sources/ScriptureUI`; `LIB` `SUI/Library`; `PH` `SUI/Phone`; `TD` `PK/Tests/ScriptureDataTests`; `T` `PK/Tests/ScriptureUITests`. Renders go to `RENDERS` = `/private/tmp/claude-501/-Users-matt-Code-reading-through-scripture/833408d4-1099-4a4f-9996-0bb2a261fbb6/scratchpad/renders/project-4`.

**Built on, read in the code at `7d943b8` (project 3 finished).**
- `BookPlaces` (`LIB/BookPlaces.swift`): `Pin(id: point, latitude, longitude, places, title, mentions)`, title `lead.name` (`:76-77`); `Frame`; `book, onMap, notOnMap, pins` (most mentions first, then title); `title` "Places in Acts"; `countLabel` "101 places · 101 on the map"; `frame` and `static func frame(_ pins:)` (`:40-55`, nine tenths of the mentions, a fifth of air, at least half a degree); `pin(holding:)`; `namesNoPlace`; `load(book:store:)`; `static func pins(of:)` (places in list order, so a pin's first place is its most mentioned). Built only in `load`.
- `PlacesSelection` (`LIB/PlacesSelection.swift`): `placeID`, `pinID`; `choose(place:in:)`, `choose(pin:in:)`, `following(_:in:)`, `gathered(in:)`, all `in places: BookPlaces` (`places.pins`).
- `PlacesMapView` (`LIB/PlacesMapView.swift`): `init(pins:frame:selection:focus:)`; `Marker(pin.title, monogram:)` for a gathered pin; `reveal` with `visibleRegion(_:reportedAt:now:)` and `region(_:size:holding:inset:)`, `markerClearance` a scaled 44; the frame read only in `init` (the view is `.id(book)`). Used by `LibraryPlacesView` (book and whole-Bible), `PhonePlacesScreen`, `PhonePlacePage`.
- `LibraryPlacesView` (`LIB/LibraryPlacesView.swift`): the list (a scaled 200 column, `LazyVStack` of `LibraryListRow`, "Not on the map" at the foot, one `.focusable()` with `onKeyPress` ↑ ↓, `LibraryChosenRowShape` ring), the map at `max(mapMinHeight, half)` when a page or a gathered pin shows, else full height; `choose(pin:)`'s guard against the map's echo (`:70`); `rule` a `Rectangle` (SwiftLint: `:51` hidden, `:39`, `:86`, `:162` frames: **four old findings**); `sharedNames`, `detail(kind:label:)`, `accessibilityLabel(_:label:)`.
- `LibraryView` (`LIB/LibraryView.swift`): `header(_:)` (Contents, the way back, the title, the count), `countLabel(_:_:peopleOrder:)`, `@AppStorage(PeopleOrder.key)`, `LoadCache` (the list read once per book, view and translation).
- `LibraryPlace` (`LIB/LibraryPlace.swift`): `book, topic, trail, openBooks, anchor`; `choose`, `walk(to:)`, `stepBack`, `clearTrail`, `chooseInItsTopic`, `opening(_:)`; `forgetThePage` clears `openBooks` and `anchor`. `NavigationModel.libraryPlace` is not stored across launches; `LibraryReturn(place:chosenBookID:)` is what Back returns to.
- Project 3's pieces: `PeopleOrder` and `LibraryOrderPicker<Order>(selection:orders:title:)` (`LIB/LibraryOrder.swift`; segmented, label hidden, VoiceOver "Order", `.small` on the Mac); `LibraryPeopleView.neighbour(of:step:in:)` and `chosenID(showing:in:)`; `LibraryListRow(id: Int, name:, detail:, count: Int, isChosen:, accessibilityLabel:, coordinateSpace:, onChosenRect:, onChoose:)` (`LIB/LibrarySections.swift:181-229`; `onTapGesture`, the button trait and action, `.id(id)`); `GroupLabel(_:size:)`; `HairlineRule(.horizontal / .vertical)`. A place's page (`PlacePageView`) already shows `DictionaryEntryView` and the verse lines (project 3, spec 10's call is already met).
- The phone: `PhonePlacesScreen` (`PH/PhonePlacesScreen.swift`): the map with `.safeAreaPadding(.bottom, sheetCover)` (`:88`), the sheet at `.fraction(0.25)`, `.medium`, `.large`, `sheetCover` not refreshed at `.large` (`:105`); the list with the count line then rows; a gathered pin's places at the list's head. `PhoneLibraryRow(name:detail:count:accessibilityLabel:onChoose:)`, `PhonePeoplePage`'s control (`lg` sides, `sm` above and below), `PhoneLibraryPageMemory(opening:)` with `openBooks`, `anchor`, `place(for:)` (`PH/PhoneLibraryPages.swift`). `PhoneLibraryScreen` rebuilds the path and memory from `navigation.libraryPlace` when a lookup returns.
- `NotesBrowserView.filterIsSegmented(width:segments:)` (`SUI/NotesBrowserView.swift:249-256`): the measured-width switch to a menu this plan copies.
- Tests: `FixtureStore.make()` (UI) and `FixtureDatabase` (data); `BenchmarkChapter.realStore()`, `.needsRealBible`; `ReaderBenchmarkTests.median(_:runs:prepare:_:)`; `LibraryBenchmarkTests` (hosts at 1,100 by 760; "Places is not hosted: no `Map`"); `PlacesSelectionTests` (fixture Matthew, the camera rule); `LibraryPlaceTests`; `LibraryOrderTests`; `PhoneShellModelTests` (memory); `TestWindow.make(frame:)` (iOS).
- **Head counts:** package 1,678, iOS `ScriptureUITests` 1,134. SwiftLint 74, impeccable-lint 27, asset checker 0. Old findings in files this plan touches: `LibraryPlacesView.swift` 4 (above); none from impeccable-lint in any.

If a name differs when a task is built, say so before going on.

## The data, checked against `Build/bible.sqlite` (schema 6, read-only, 2026-11-23)

- 1,287 places; 26 without coordinates; 511 approximate, all with coordinates (as spec 7).
- **Acts (book 44):** 101 places, all on the map, at 95 points; three shared pins: Jerusalem's (31.777,35.235) Jerusalem 57, Judea 13, Beautiful Gate 2, Solomon's Portico 2, Akeldama 1; Straight Gate and Syria; Rome and Italy. Most named begins Jerusalem (636), Caesarea (266). A to Z begins Achaia, Adramyttium, Adria, Akeldama; the two Antiochs are 69 (label "Pisidia") and 68 ("Syria"). All 28 chapters name a place; 229 place-and-chapter rows; 43 places in more than one chapter; Jerusalem in 22. **Chapter 1** (first verse): Jerusalem 4, Judea 8, Samaria 8, Galilee 11, Mount of Olives 12, Akeldama 19; its verses: Jerusalem 4, the rest 1 each; its pins: Jerusalem's point (Jerusalem, Judea, Akeldama: "3", 6 mentions), Samaria, Galilee, Mount of Olives (31.778,35.247): 4 pins, so 91 dots. Its frame by the book's rule: centre 32.2420, 35.2458; spans 1.3014 by 0.5. **Chapter 2:** 13 places: Jerusalem (5), Asia, Cappadocia, Judea, Mesopotamia, Pontus (9), Cyrene, Egypt, Libya, Pamphylia, Phrygia, Rome (10), Nazareth (22); Jerusalem's pin holds Jerusalem and Judea ("2").
- **Genesis (1):** 119 places, 8 without coordinates (Abel-mizraim 9 and Atad 112 in chapter 50; Eden 354 in 2 and 3; Gihon 472, Havilah 533, Pison 951 in 2; Goiim 485 in 14; Nod 902 in 4), so 9 unlocated rows; 78 located points; 44 of 50 chapters name a place; 39 places in more than one chapter; 233 rows. Chapter 10 names 20, **chapter 14 names 27** (the most). **Chapters 3 (Eden) and 4 (Nod) name one place each and none on the map.** Chapter 2 names 8, 4 on the map. Twins: Havilah (533, 534), Rehoboth (990 to 992), Valley of Shaveh (692, 1216, the same label).
- **Joshua (6):** 434 places at 305 points, 3 without coordinates; 202 places in 76 shared pins; 24 chapters name a place; 686 rows; 130 places in more than one chapter; **chapter 15 names 165**, chapter 19 132.
- **The fixture (Matthew, both fixtures):** places by verses in the book Bethlehem 218 (5), Egypt 362 (4), Jerusalem 636 (4), Nazareth 882 (2), Holy place 574 (1, no coordinates), Ramah 978 (1), South 1110 (1, no point), Zion 1263 (1); Jerusalem and Zion share 31.777,35.235 (title Jerusalem); 5 pins. By chapter: 2 Bethlehem (2:1, 5 verses), Jerusalem (2:1, 2), Egypt (2:13, 4), Ramah (2:18, 1), Nazareth (2:23, 1); 4 Nazareth (4:13), Jerusalem (4:25); 5 Jerusalem (5:35); 12 South (12:42); 21 Zion (21:5); 24 Holy place (24:15): 6 headings, 11 rows. Ramah 979 is named only in 1 Samuel (not in Matthew).
- **Where the spec's words differ** (Departure 23): the Most named sort is now `placesIn` at `BibleStore+Library.swift:269-281`, not `:214-227`; "chapter 10 alone names 20" is true, but chapter 14 names more; the "Chapter 5 · 2 places, none on the map" example is the form, and the data's cases are Genesis 3 and 4 with one place each.

## Before Task 1 (the controller)

1. Copy this plan's Global Constraints to `.superpowers/sdd/2026-11-23-milestone-11-places/global-constraints.md`.
2. Run the pre-flight scan the handover describes against the code as it is; write `preflight.md` beside the ledger and rule each conflict in a "Pre-flight rulings" section of this plan before Task 1.
3. Record the suites' head counts in the ledger (1,678 and 1,134 expected).

## Departures and open calls

Each is built as written. Each is **(call, unattended)**, with its reason and its cost if wrong; each that Matt may want otherwise goes on his list in the spec's "As built" (Task 10).

1. **Step 0 is not repeated** (above). The controller's after-fix checks are spec 4.2's places (Acts: Solomon's Portico, Judea, Akeldama; Joshua, a place in a shared pin; Genesis, Luz). *Cost:* none; the cause is confirmed.
2. **On the Mac the three segments do not fit the default column, so it shows the menu there.** AppKit's `NSSegmentedControl` with "Most named", "A to Z", "By chapter" at `.small` is 210 pt wide (two segments: 134; measured 2026-11-23 by `sizeToFit`); the column's inside is 184 pt (a scaled 200 less `xs` each side). Spec 5.1's own rule ("where three segments do not fit … it becomes a menu … by a measured width threshold") then gives a menu at the default size, not only at large text. Task 4 measures the SwiftUI control itself and pins what it finds; if it fits, the segments show. Nothing widens the column. *Cost:* Matt sees "Most named ⌄" in Places where People has segments; the alternative is one constant (the Places column at a scaled 232 pt).
3. **The phone's control is a menu at any accessibility size, and wherever its measured width passes the sheet's inside** (402 less `lg` each side: 354 pt). *Cost:* one condition.
4. **The read counts each chapter's verses** (`count(*) AS verses` beside spec 7's `MIN(verse % 1000)`), so a chapter's pins are weighed by the chapter's own mentions when the book's frame rule is applied to them (5.5: "counted over the chapter only"); rows with the same first verse come in `place_id` order, and ties are then broken by name in Swift. *Cost:* none.
5. **A chapter's pin keeps the book's order of its places,** so with none of them chosen it is titled with the book's most-mentioned of them (Acts 1: "Jerusalem"); its monogram counts the chapter's places at that point ("3"). *Cost:* none seen.
6. **Dots are by point:** every book pin whose point holds no pin of the chapter is a dot; a point with a chapter pin draws none (Acts 1: 4 pins, 91 dots, not 97). *Cost:* none; two dots at one point would draw as one.
7. **A chapter with no place on the map frames the whole book** (its dots), with no pins; the header reads "Chapter 3 · 1 place, none on the map" (Genesis 3). A chapter with some places off the map reads only its count ("Chapter 2 · 8 places"). *Cost:* wording; one line in `headerLine`.
8. **Choosing the chosen heading again clears the chapter only:** a place on show stays on show (its pin is then the book's), and the camera frames the book. *Cost:* none seen.
9. **← and → with no chapter chosen** choose the first and the last chapter (as ↓ and ↑ with no row chosen take the first and the last). **↑ and ↓ under By chapter always make the row's chapter the chosen one,** including the first step after switching to the order. *Cost:* one branch each.
10. **Switching to By chapter chooses no chapter;** a place on show keeps its page, its wash goes on its row under its first chapter, and the map stays the book's. Choosing another order clears the chapter and keeps the place. The chapter is in effect only under By chapter (`effectiveChapter`). *Cost:* none.
11. **A chapter change by a place** (a row of another chapter, ↑ ↓ across a heading, or the follow rule) reframes the map to the new chapter at half height, the chosen pin held in view (`PlacesMapView.framed`). 5.5 says the camera moves "to the chapter" and that the map keeps half height; it does not say whether a place's chapter change reframes. *Cost:* a camera move a reader may not want; one condition.
12. **The chosen chapter lives in `LibraryPlace.placesChapter`** on the Mac (so `LibraryReturn` keeps it; Back returns to it) and in `PhoneLibraryPageMemory.placesChapters[book]` on the phone (rebuilt from the place when a lookup returns, dropped when Places is popped). A new `LibraryPlace` (another book or view) has none; nothing is stored across launches (spec 5.5, 8).
13. **Headings take clicks as rows do** (`onTapGesture`, the button and header traits, an accessibility action), so the Mac's list stays one Tab stop.
14. **"not on the map" stands where a row's count would** (trailing, `.caption` `ink.secondary`), and a dimmed row dims its name and its detail to `ink.tertiary`. *Cost:* the note's place.
15. **The re-click on a gathered pin** (4.3): MapKit's `Map` reports no click on a marker that is already selected, so `PlacesMapView` reads a tap through `MapReader` (a `SpatialTapGesture` simultaneous with the map's own) and, when it falls on the chosen marker's balloon (`isOnChosenMarker`), calls `onReopen`, which clears the place and shows the pin's places ("5 places here"). Only a pointer click or a tap shows it: on the Mac nobody (the live pass is keys only), on the phone the controller's simulator pass. *Cost if it fails:* the backlog's line stays.
16. **The chosen pin is drawn last** in the map's content (dots first, then the other pins, then the chosen one) so MapKit draws it and its title above its neighbours (4.3, "the builder's"); the controller's live check is the proof.
17. **The phone's cover is judged in the region MapKit reports for the whole map** (as `visibleRegion` assumes today): a pin is in view only above the sheet by a marker's clearance, and is moved to the middle of the part above it at the same zoom; a chapter is framed into that part. The map keeps `.safeAreaPadding(.bottom, sheetCover)` for its legal label. If the simulator shows the pin landing high by half the cover (MapKit already fitting `.region` into the safe area), the offset term goes (one line in each rule). At the large detent the padding follows the sheet (4.3) and nothing pans: the part above the sheet is shorter than two clearances. *Cost:* a fix-wave line.
18. **The camera's moves are coalesced by a generation:** each framing change takes a new generation and starts its move after one turn of the main run loop; a move whose generation is no longer the latest is dropped, so stepping fast goes to the last chapter chosen (spec 11 leaves how to the builder).
19. **The dot** is an `Annotation` (no title, `anchor: .center`) holding a `Circle` a scaled `xxs` across (`@ScaledMetric(relativeTo: .caption)`) in `Color.inkTertiary`, `.allowsHitTesting(false)`, untagged (so not choosable), `.accessibilityHidden(true)`: one SwiftLint `accessibility_hidden_on_text` finding, which spec 6 requires; with `LibraryPlacesView`'s four old findings gone the count goes 74 → 70 (Task 4) → 71 (Task 5) and never passes the head's 74.
20. **VoiceOver:** a heading is one element, "Chapter 1, 6 places", button and header traits, selected while chosen; a row's hint under By chapter is "in chapter 3"; the header line's new text is announced on every change of the chosen chapter, by any route ("Chapter 2, 13 places"; "Chapter 3, 1 place, none on the map").
21. **The header line is its own view,** `LibraryHeaderView`, taken out of `LibraryView.header(_:)` unchanged, so a render can host it alone (a hosted `LibraryView` on Places would make a `Map`).
22. **The speed checks** (spec 7): `joshuasPlacesLoad` (the read and the model, before and after), `joshuaByChapterListOpens` (the list column hosted alone, chapter 15 chosen) and `joshuasChapterFifteenMapContent` (its pins, dots, draw order and framing, pure). The map itself is never measured (no test makes a `Map`). Bounds are 1.5 × the measured median rounded up to 10 ms (project 2's Departure 17), set in Task 9 before the whole-project review.
23. **The spec's figures and line numbers** that differ are listed in "The data, checked". No figure the spec pins in its section 13 is wrong.
24. **The Mac live passes may not reach Places by keys:** the pane's People, Places and About icons are not Tab stops (the backlog's "About has no key route on the Mac"). Where the controller cannot reach a book's Places by keys, the simulator stands in for what it can show and the Mac's keys go on Matt's list. No key route is added here.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-11-ui-improvements`, branch `milestone-11-ui-improvements`. Never push or merge; never commit to `main`.
- Git: `/usr/bin/git -C <worktree>`, one git command per Bash call, no `cd … &&`, loops or shell variables. Every commit message ends with the `Co-Authored-By:` line your session gives you, as a second `-m`.
- `rtk` shortens command output; `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time; implementers dispatch no subagents. Rules: `docs/superpowers/process/implementer-rules.md`, `reviewer-rules.md`.
- **Implementers never launch, quit, relaunch or send keys to the Mac Debug app or the simulator's app.** The live passes are the controller's, under milestone 10's handover rules (keys only, the Debug app frontmost and matched by pid, idle time checked first; in the simulator, answer no notice and change no synced setting).

**Matt's data**
- Never touch the Release apps, `Scripts/install-app.sh`, `/Applications`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. The `.dev` store and its preferences get nothing.
- **No test writes `UserDefaults.standard`.** An order in a test or render is `.defaultAppStorage(suite)` on the hosted view with a `UserDefaults(suiteName: "<Suite>-\(UUID().uuidString)")!` removed at the end (`removePersistentDomain(forName:)`), or a parameter of a pure function.

**What is stored (spec 8)**
- **Places' order, on this device only: `UserDefaults` key `libraryPlacesOrder`, values `"mostNamed"` (the default), `"alphabetical"` and `"byChapter"`,** read and written through `@AppStorage(PlacesOrder.key)`. Its own key, not People's (`libraryPeopleOrder`). Not in `SyncedPreferences.keys`, not in the store, not in the export. Approved by Matt, 2026-11-23 ("Yes, all three (Recommended)").
- Nothing else. The chosen chapter is view and model state (`LibraryPlace.placesChapter`, `PhoneLibraryPageMemory`), part of the Library's "as it was" on Back, never kept across launches. The Bible database stays at schema 6; no import, no digest change.

**The spec's values (verbatim)**
- **The pin (4.3):** a shared pin takes the chosen place's name while one of its places is chosen, whether it was chosen in the list, by a chapter or from "At the same spot"; with none of its places chosen it is titled as today (its most-mentioned place); the count monogram stays. The chosen pin is drawn above its neighbours, so no neighbouring marker hides it or its title. On the phone the chosen pin is kept clear of the sheet: `reveal` treats the part of the map under the sheet as out of view and pans the pin up into the visible part at the same zoom; the map's padding follows the sheet at the large detent too. A gathered pin clicked while one of its places is chosen shows its places ("7 places here"). "At the same spot" stays on the place's page under the map. A place with no coordinates selects nothing on the map and its page says "Not on the map."
- **The control (5.1):** Places takes People's control with a third choice: **Most named**, **A to Z**, **By chapter**. Mac: at the head of the list column, above the rows (`xs` from its top and sides, as People's); phone: at the head of the sheet's list, under the count line ("101 places · 101 on the map"). The system segmented `Picker`; where three segments do not fit it becomes a menu of the same three choices by a measured width threshold, as the Notes window's filter does, not by `ViewThatFits`. VoiceOver: the system's control, labelled "Order".
- **Most named (5.2):** verses naming the place in this book, most first, then name, then id; "Not on the map" at the foot.
- **A to Z (5.3):** by name in the reader's language order (`localizedStandardCompare`), then the data's label for two places of one name (none first), then id; "Not on the map" at the foot.
- **By chapter (5.4):** each chapter that names a place is a heading, "Chapter 1", in the group-label voice (`GroupLabel`: `.caption2` semibold upper case, tracked, `ink.verse`), its place count trailing in `.caption` `ink.secondary` `.monospacedDigit()`; chapters that name no place are left out. Under it the chapter's places in the order the chapter first names them (the lowest verse naming each in that chapter), ties by name; a place named in several chapters is listed under each. A place with no coordinates stays under its chapter with "not on the map" beside its name in `.caption` `ink.secondary`; no "Not on the map" group in this order. Rows look as in the other orders, without the count. Choosing a place chooses that place (its page under the map, its pin chosen); only the row clicked takes the selection wash.
- **The map follows the chapter (5.5):** a heading is a button; a click on it (or ← → on the Mac) makes it the chosen chapter, on `accent.wash` at radius `md` like a chosen row; choosing a chapter by its heading or by ← → closes the place's page and clears the walk's trail, and the map takes the full height, framed to the chapter. Choosing a place under a heading makes that heading's chapter the chosen one and opens the place's page under the map. The map resizes only when a chapter is chosen by its heading or by ← →, as a cut; moving from place to place, across chapters included, keeps the page open and the map at half height. A place on show reached another way ("At the same spot", a walk, Back) that the chosen chapter does not name moves the chosen chapter to the place's first chapter in this book; a place not in this book clears it; either way the wash goes on the place's row under that chapter, scrolled into view. The header line reads "Chapter 1 · 6 places" in place of "101 places · 101 on the map"; a chapter whose places all lack coordinates reads "Chapter 5 · 2 places, none on the map" and the map shows only the dots. The map shows the chapter's places as its pins, gathered by point, counted over the chapter only (Acts 1: Jerusalem's pin holds Jerusalem, Judea and Akeldama: "3"), framed by the book's rule applied to the chapter's pins; every other place of the book is a small dot: a scaled circle of about `xxs` (4 pt) in `ink.tertiary`, no label, not choosable, hidden from VoiceOver, drawn with the map's own content, never as a view over the map. The rows of other chapters stay in the list, their names in `ink.tertiary`; a click on one chooses that place and makes its chapter the chosen one. Choosing the chosen heading again, or another order, returns the map to every pin and the book's frame and the header to its count line.
- **The Mac's keys (5.5):** ↑ ↓ move between place rows only, skipping headings, choosing each place; crossing into the next chapter's rows makes that the chosen chapter and keeps the page open (half height). ← → step to the previous and next chapter's heading and choose it as a click does (the page closes, the map is full height), while the list holds the keyboard; they stop at the first and last chapter. Esc keeps its meaning (back to Contents); it does not first clear a chapter. No existing key changes.
- **The camera (5.5):** moves to the chapter with `.smooth`, as it moves to hold a chosen place, and cuts under Reduce Motion; stepping chapters quickly must not queue a train of moves: it goes to the last chapter chosen. It never moves when nothing was chosen.
- **The phone (5.5):** the sheet's list has the same control, the chosen heading's wash and the other chapters' dimmed rows; its place rows keep no chosen state (a tap pushes the place's page). Tapping a heading chooses the chapter; the map above the sheet frames the chapter within the part the sheet leaves visible; the dots likewise. No arrows: the reader goes Back to the list and taps another heading. The sheet's detents are unchanged and the sheet stays at its detent.
- **VoiceOver (6):** the control is the system's; a heading is a button with the header trait, "Chapter 1, 6 places", with the selected trait while chosen; a row reads as today, and under By chapter its hint names the chapter ("in chapter 3"); a change of chosen chapter announces the header line's new text ("Chapter 2, 13 places"); dots are hidden; the system `Marker` still takes no label.
- **Anti-goals (2):** nothing floats over the map (no card, callout, chip or banner); a chosen place on the map is always findable; By chapter hides no row or chapter; the camera never moves when nothing was chosen.

**UI rules**
- `CLAUDE.md`'s three rules; read `PRODUCT.md` and `DESIGN.md` first; `/impeccable-swift` for every UI change, its command named in each task. Palette tokens only; `AppSpacing`/`AppRadius` by name, `@ScaledMetric` for sizes tied to text; no card, no glass, no shadow; no `.font(.system(size:))`. A rule is `HairlineRule`, not a `Rectangle` with `accessibilityHidden`.
- **Checkers, from the worktree root:** `swiftlint lint --config tools/.swiftlint.yml`; `tools/impeccable-lint/.build/release/impeccable-lint Packages/ScriptureKit/Sources/ScriptureUI Apps`; `swift tools/asset-catalog-checker/check.swift Apps/Mac/ReadingThroughScripture/Assets.xcassets`. Baseline 74, 27, 0. No total ever rises above it; a task adds no finding in a file it touches or creates, except the dot's one `accessibilityHidden` (Departure 19). Expected: 70 after Task 4, 71 from Task 5 on.

**Tests**
- Swift Testing. Pure tests carry no platform guard; a test that hosts a view is `@MainActor`, in a `.serialized` suite, `#if os(macOS)` for `NSHostingView`, `#if os(iOS)` for `TestWindow`. Real-data tests are `.needsRealBible`, in `T/PlacesRealDataTests.swift` (`@Suite struct PlacesRealDataTests`) unless a task says otherwise. Compare mapped ids or strings, never tuples, in `#expect`; no mutating call inside `#expect`.
- **A test never makes a `Map`** (no `PlacesMapView`, `LibraryPlacesView`, `PhonePlacesScreen`, `PhonePlacePage` for a whole-Bible place, or `LibraryView` on Places, hosted or not). The chapter behaviour is in the models; the map view only reads them.
- `swift test` cannot load the package's Color Sets; tokens come from `Palette.swift`. No test writes the clipboard, the `.dev` store or the network.
- Known flake: `ReaderBenchmarkTests.scrollingWhileTheThumbRevealsKeepsTheFrameCost` and other timing benchmarks under full-suite load (the 1 Chronicles People open among them); rerun alone.
- Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (`--filter <Suite>` while iterating). iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`. Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`. One at a time.

**Renders (every UI task)**
- A render cannot draw map tiles and never makes a `Map`: render the list column, the headings, the header line and the control, not the map.
- **Mac:** a temporary `@MainActor` test, `T/PlacesRenderScratch.swift` (`#if os(macOS)`), offscreen, real store: `LibraryPlacesList` in an `NSHostingView` at the column's width by 1,600, with `.defaultAppStorage(suite)` for the order; `LibraryHeaderView` alone at 900 by 60. Light and Dark by the host's `NSAppearance`; Sepia by `SepiaMode.set(true)` and `.followsSepia()`, reset after. PNGs to `RENDERS`.
- **Phone:** a temporary test, `T/PhonePlacesRenderScratch.swift` (`#if os(iOS)`), `PhonePlacesList` in `TestWindow.make(frame:)` 402 by 1,600 on the real store, `window.layer.render(in:)` (never `drawHierarchy`), Light and Dark by `overrideUserInterfaceStyle`, Sepia as above, `.environment(\.dynamicTypeSize, .large)` and `.accessibility5`; run with `-only-testing:ScriptureUITests/PhonePlacesRenderScratch`.
- Open every PNG with Read. **Delete both scratch files before committing.** Say what a render cannot show: the map, the pointer, a click, focus and its ring, a key, VoiceOver, motion.

## Review Focus

The cases a person meets that spec 13's list does not pin, most likely first; each has its test in the owning task.

1. **Back from a passage opened from a place under a chosen chapter:** the same chapter chosen, its row washed and in view, on both apps (Task 3, `theChapterIsPartOfTheLibrarysAsItWas`; Task 7, `thePhonesMemoryKeepsTheChapterAcrossALookup`).
2. **Switching order with a chapter chosen and a place on show:** the place stays chosen, the chapter clears, exactly one row washed in the new order (Task 3, `anotherOrderClearsTheChapterAndKeepsThePlace`).
3. **A chapter with nothing on the map** (Genesis 3): the header says so, there are no pins, the dots are the book's 78 points, and the camera frames the book rather than nowhere (Task 2, `aChapterWithNoPinFramesTheBook`; real data in `genesisThreeIsAllDots`).
4. **Stepping ← → fast:** one camera move, to the last chapter (Task 5, `stepsInQuickSuccessionMoveTheCameraOnce`).
5. **A place in several chapters reached by "At the same spot":** the chosen chapter moves to its first chapter and only that row is washed (Task 3, `aPlaceShownAnotherWayMovesTheChapter`, `theChosenRowIsOneRow`).

---

### Task 1: The book's places by chapter, and the three orders' data

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change; the review runs the three checkers.

**Files:**
- Modify: `DATA/BibleStore+Library.swift`, `DATA/LibraryRecords.swift`, `LIB/BookPlaces.swift`, `LIB/LibraryOrder.swift`
- Test: `TD/BibleStoreLibraryTests.swift`, `T/PlacesOrderTests.swift` (new), `T/PlacesRealDataTests.swift` (new), `T/LibraryBenchmarkTests.swift`

**Interfaces:**
- Produces:
  - `public struct PlaceChapterMention: Equatable, Sendable { public let placeID: Int, chapter: Int, firstVerse: Int, verseCount: Int }` (`DATA/LibraryRecords.swift`, with a public memberwise init).
  - `BibleStore.placeChapters(inBook book: String) throws -> [PlaceChapterMention]`: one read, `SELECT place_id, verse / 1000 % 1000 AS chapter, MIN(verse % 1000) AS first, count(*) AS verses FROM place_verse WHERE verse BETWEEN ? AND ? GROUP BY place_id, chapter ORDER BY chapter, first, place_id` over `keys(ofBook:)`; `[]` outside the 66 (Departure 4).
  - `public enum PlacesOrder: String, CaseIterable, Sendable { case mostNamed, alphabetical, byChapter; public static let key = "libraryPlacesOrder"; public var title: String }` ("Most named", "A to Z", "By chapter") in `LIB/LibraryOrder.swift`.
  - `BookPlaces.Chapter: Identifiable, Equatable, Sendable { public let number: Int; public let places: [PlaceSummary]; public let mentions: [Int: Int]; public var id: Int { number }; public var onMapCount: Int }` (`places` in first-mention order, ties by `localizedStandardCompare` then id; `mentions` place id → verses in the chapter; `onMapCount` the places with a point).
  - `BookPlaces` gains `public let onMapByName: [PlaceSummary], notOnMapByName: [PlaceSummary]` (spec 5.3, sorted once at load) and `public let chapters: [Chapter]` (chapters naming no place absent), and `public func chapter(_ number: Int) -> Chapter?`. `load` makes the one extra read. Task 2 adds each chapter's pins.

- [ ] **Step 1: The before figure.** Add `LibraryBenchmarkTests.joshuasPlacesLoad`: the median of `BookPlaces.load(book: "JOS", store:)`, `#expect(places?.onMap.count == 431 && median < .milliseconds(50))`. Run it three times alone on today's code; write each median to `.superpowers/sdd/2026-11-23-milestone-11-places/benchmarks.md` and the report. Commit the test alone: "Joshua's Places load, measured before project 4".
- [ ] **Step 2: Write the failing tests.**
  - `TD/BibleStoreLibraryTests.aBooksPlacesByChapterAreOneRead` (fixture): `placeChapters(inBook: "MAT").map { "\($0.placeID):\($0.chapter):\($0.firstVerse):\($0.verseCount)" }` begins `["218:2:1:5", "636:2:1:2", "362:2:13:4", "978:2:18:1", "882:2:23:1", "882:4:13:1", "636:4:25:1", "636:5:35:1"]` and has 11 rows; `placeChapters(inBook: "TOB")` and `(inBook: "XYZ")` are empty.
  - `T/PlacesOrderTests.swift` (`@Suite struct PlacesOrderTests`, fixture Matthew):
    - `thePlacesOrderIsKeptOnThisDeviceOnly`: `PlacesOrder.key == "libraryPlacesOrder"`, `!= PeopleOrder.key`, `!SyncedPreferences.keys.contains(PlacesOrder.key)`; `PlacesOrder(rawValue: "byChapter") == .byChapter`; `allCases.map(\.title) == ["Most named", "A to Z", "By chapter"]`.
    - `theStoredOrderIsReadBackAfterARelaunch` (13.7): a suite `UserDefaults(suiteName: "PlacesOrderTests-\(UUID())")` set to `"byChapter"` under `PlacesOrder.key`; a second `UserDefaults(suiteName:)` of the same name (a fresh model) reads `PlacesOrder(rawValue:) == .byChapter`; an empty suite reads nil, which `@AppStorage(PlacesOrder.key) … = .mostNamed` makes Most named; both suites removed. `SyncedPreferences.keys` is unchanged (its count test stands).
    - `aToZSortsByNameThenLabelThenIDWithTheUnlocatedAtTheFoot`: `onMapByName.map(\.name) == ["Bethlehem", "Egypt", "Jerusalem", "Nazareth", "Ramah", "Zion"]`; `notOnMapByName.map(\.name) == ["Holy place", "South"]`; `onMap.map(\.id) == [218, 362, 636, 882, 978, 1263]` (Most named unchanged).
    - `theChaptersListTheirPlacesInTheOrderFirstNamed`: `chapters.map(\.number) == [2, 4, 5, 12, 21, 24]`; chapter 2's names `["Bethlehem", "Jerusalem", "Egypt", "Ramah", "Nazareth"]` (Bethlehem and Jerusalem both at 2:1, by name); chapter 4's `["Nazareth", "Jerusalem"]`; `chapter(12)?.onMapCount == 0`; `chapter(2)?.mentions[218] == 5`; the sum of the chapters' place counts 11; `chapter(3) == nil`.
  - `PlacesRealDataTests` (the figures of "The data, checked"):
    - `actsInEachOrder`: `onMap.prefix(2).map(\.name) == ["Jerusalem", "Caesarea"]`; `onMapByName.prefix(4).map(\.name) == ["Achaia", "Adramyttium", "Adria", "Akeldama"]`; the Antiochs in A to Z `[69, 68]`; `chapters.count == 28`, rows 229; chapter 1's names `["Jerusalem", "Judea", "Samaria", "Galilee", "Mount of Olives", "Akeldama"]`; chapter 2: 13 places, beginning Jerusalem, Asia, Cappadocia; 43 places in more than one chapter; Jerusalem in 22.
    - `genesisAndJoshuaByChapter`: Genesis 44 chapters, 233 rows, 9 rows of the 8 unlocated ids `[9, 112, 354, 472, 485, 533, 902, 951]` (Eden under 2 and 3), `chapter(3)?.places.map(\.id) == [354]` with `onMapCount == 0`, chapter 10 20 places, chapter 14 27; the twins Valley of Shaveh `[692, 1216]` in A to Z. Joshua: 434 places, 24 chapters, 686 rows, chapter 15 165 places, 130 places in more than one chapter, 76 pins holding more than one place and 202 places in them.
- [ ] **Step 3: Run them and see them fail** (`--filter BibleStoreLibraryTests`, `PlacesOrderTests`, `PlacesRealDataTests`): compile failures.
- [ ] **Step 4: Implement** as the Interfaces say, each rule documented with its spec section.
- [ ] **Step 5: Run them and see them pass,** then `joshuasPlacesLoad` three times alone (after; append to `benchmarks.md`).
- [ ] **Step 6: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers (no new finding).
- [ ] **Step 7: Commit:** "A book's places by chapter, read once, and their A to Z order".

---

### Task 2: A chosen place names its pin; a chapter's pins, dots and frame

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change (`PlacesMapView` gains nothing yet).

**Files:**
- Modify: `LIB/BookPlaces.swift`, `LIB/PlacesSelection.swift`
- Test: `T/PlacesSelectionTests.swift`, `T/PlacesRealDataTests.swift`

**Interfaces:**
- Consumes: `BookPlaces.chapters`, `Chapter.mentions` (Task 1).
- Produces:
  - `BookPlaces.Pin.title(choosing placeID: Int?) -> String`: the chosen place's name when it is one of the pin's places, else `title` (4.3).
  - `Chapter` gains `public let pins: [Pin]`, built at load by `pins(of:)`'s gathering over the chapter's places that have a point, each pin's places in the book's list order (Departure 5), `mentions` the chapter's verses, sorted as the book's pins.
  - `BookPlaces.pins(inChapter number: Int?) -> [Pin]` (nil: the book's `pins`; a chapter not named: `[]`), `dots(inChapter:) -> [Pin]` (the book's pins whose id is not among the chapter's; `[]` for nil; Departure 6), `frame(inChapter:) -> Frame?` (`Self.frame(pins(inChapter:))`, or the book's `frame` when the chapter has no pin; Departure 7).
  - `public struct PlacesFraming: Equatable, Sendable { public let chapter: Int?; public let frame: BookPlaces.Frame? }` and `BookPlaces.framing(chapter: Int?) -> PlacesFraming`.
  - `PlacesSelection`: `choose(place:in:)`, `choose(pin:in:)`, `following(_:in:)` and `gathered(in:)` take `in pins: [BookPlaces.Pin]`; the `in places: BookPlaces` forms stay and pass `places.pins`. New `public mutating func reopen(in pins: [BookPlaces.Pin])`: with a place chosen inside a pin of several places, the place is forgotten and the pin kept (so `gathered` lists its places); otherwise nothing changes (4.3).

- [ ] **Step 1: Write the failing tests** in `PlacesSelectionTests` (fixture Matthew):
  - `aChosenPlaceNamesItsSharedPin` (13.1): the pin at "31.777,35.235": `title(choosing: nil) == "Jerusalem"`, `(choosing: 1263) == "Zion"`, `(choosing: 636) == "Jerusalem"`, `(choosing: 218) == "Jerusalem"`; `places.count == 2` throughout.
  - `aChaptersPinsCountTheChapterOnly`: `pins(inChapter: 2).count == 5`, its pin at Jerusalem's point holds `[636]`, Bethlehem's `mentions == 5`; `pins(inChapter: 21)` is one pin at "31.777,35.235" holding `[1263]` titled "Zion"; `pins(inChapter: 12).isEmpty`; `pins(inChapter: nil) == places.pins`.
  - `theRestOfTheBookAreDots`: `dots(inChapter: 2).isEmpty`; `dots(inChapter: 4).map(\.title).sorted() == ["Bethlehem", "Egypt", "Ramah"]`; `dots(inChapter: 12).count == 5`; `dots(inChapter: nil).isEmpty`.
  - `aChapterWithNoPinFramesTheBook` (Review Focus 3): `frame(inChapter: 12) == places.frame`; `frame(inChapter: 4) == BookPlaces.frame(places.pins(inChapter: 4))`; `framing(chapter: 4) == PlacesFraming(chapter: 4, frame: frame(inChapter: 4))`; `framing(chapter: nil).frame == places.frame`.
  - `everyWayOfChoosingTitlesTheSharedPin` (13.2): from the list, `choose(place: 1263, in: places.pins)`; from a chapter's rows, `choose(place: 1263, in: places.pins(inChapter: 21))`; from "At the same spot", `PlacesSelection().following(.place(1263), in: places.pins)`: each `pinID == "31.777,35.235"`, and that pin's `title(choosing: selection.placeID) == "Zion"`. In chapter 2's pins, `choose(pin: "31.777,35.235", …)` chooses 636 (one place there).
  - `aSecondClickOnAGatheredPinListsItsPlaces` (13.3): after `choose(place: 1263, in: places.pins)`, `reopen(in: places.pins)` leaves `placeID == nil`, `pinID == "31.777,35.235"`, `gathered(in: places.pins)?.map(\.name) == ["Jerusalem", "Zion"]`; after `choose(place: 218, …)` (a pin of one place) `reopen` changes nothing; on `PlacesSelection()` nothing.
  - `PlacesRealDataTests.solomonsPorticoNamesJerusalemsPin` (13.1): Acts's `pin(holding: 1109)`: `places.count == 5`, `title(choosing: nil) == "Jerusalem"`, `(choosing: 1109) == "Solomon's Portico"`, `(choosing: 636) == "Jerusalem"`.
  - `PlacesRealDataTests.actsFirstChapterPinsAndDots` (13.5): `pins(inChapter: 1).count == 4`; the pin holding 636 holds `[636, 657, 43]` with `mentions == 6`; `dots(inChapter: 1).count == 91`; `frame(inChapter: 1)`: latitude 32.2420, longitude 35.2458, `latitudeSpan` 1.3014 (each ± 0.001), `longitudeSpan == 0.5`; chapter 2's Jerusalem pin holds `[636, 657]`.
  - `PlacesRealDataTests.genesisThreeIsAllDots`: `pins(inChapter: 3).isEmpty`, `dots(inChapter: 3).count == 78`, `frame(inChapter: 3) == frame`.
- [ ] **Step 2: Run them and see them fail** (`--filter PlacesSelectionTests`, `PlacesRealDataTests`).
- [ ] **Step 3: Implement.** The existing selection and camera tests stand unchanged.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers.
- [ ] **Step 6: Commit:** "A shared pin takes its chosen place's name; a chapter's own pins, the book's other places as dots".

---

### Task 3: The chosen chapter: the list's items and the Library's "as it was"

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change.

**Files:**
- Create: `LIB/PlacesList.swift`, `LIB/PlacesChapters.swift`
- Modify: `LIB/LibraryPlace.swift`, `LIB/LibraryView.swift` (`countLabel` only)
- Test: `T/PlacesChaptersTests.swift` (new), `T/LibraryPlaceTests.swift`, `T/PlacesRealDataTests.swift`

**Interfaces:**
- Consumes: `BookPlaces.chapters`, `chapter(_:)`, `onMapByName`, `notOnMapByName` (Task 1).
- Produces:
  - `public enum PlacesList { public struct Row: Identifiable, Hashable, Sendable { public let place: PlaceSummary; public let chapter: Int?; public var id: String }; public enum Item: Identifiable, Equatable, Sendable { case row(Row), notOnMap, heading(BookPlaces.Chapter); public var id: String }; public static func items(_ places: BookPlaces, order: PlacesOrder) -> [Item]; public static func rows(_ items: [Item]) -> [Row]; public static func chosenRowID(showing: LibraryEntity?, chapter: Int?, in rows: [Row]) -> String?; public static func isDimmed(_ row: Row, chapter: Int?) -> Bool }`. A row's id is `"636"` with no chapter, `"2-636"` under chapter 2; a heading's `"chapter-2"`; the foot's `"not-on-the-map"`. `items`: Most named and A to Z are the on-map rows, then `.notOnMap` and the rest when there are any (5.2, 5.3); By chapter is each chapter's heading then its rows (5.4). `chosenRowID`: the row of the place on show under `chapter`, else its first row (Departure 10), nil for none. `isDimmed`: a row of another chapter while one is chosen.
  - `public enum PlacesChapters { public static func following(showing: LibraryEntity?, chosen: Int?, in places: BookPlaces) -> Int?; public static func afterHeading(_ number: Int, chosen: Int?) -> Int?; public static func headerLine(_ chapter: BookPlaces.Chapter) -> String; public static func headingSpoken(_ chapter: BookPlaces.Chapter) -> String; public static func announcement(_ chapter: BookPlaces.Chapter) -> String; public static func rowHint(chapter: Int) -> String }`. `following`: nil chosen stays nil; a place the chosen chapter names keeps it; a place in the book moves it to the place's first chapter; a place not in the book clears it; no place on show keeps it (5.5). `afterHeading`: the chosen heading again gives nil, another its number (Departure 8). Words: "Chapter 2 · 5 places", "Chapter 5 · 1 place", "Chapter 12 · 1 place, none on the map"; spoken "Chapter 2, 5 places"; announced "Chapter 12, 1 place, none on the map"; hint "in chapter 3".
  - `LibraryPlace` gains `public var placesChapter: Int? = nil` (kept by `choose`, `walk(to:)`, `stepBack`, `clearTrail`, `opening`; Departure 12) and, in `PlacesChapters.swift`, `extension LibraryPlace { public mutating func chooseChapter(_ number: Int); public mutating func choosePlace(_ id: Int, inChapter chapter: Int?); public mutating func follow(in places: BookPlaces); public mutating func clearChapter() }`. `chooseChapter`: `placesChapter = afterHeading(…)`, and when that chose a chapter, `clearTrail()`. `choosePlace`: a non-nil `chapter` becomes `placesChapter`, then `choose(.place(id))`.
  - `LibraryView.countLabel(_:_:peopleOrder:placesChapter: Int? = nil)`: with a chapter of the book, its `headerLine`.

- [ ] **Step 1: Write the failing tests** in `T/PlacesChaptersTests.swift` (`@Suite struct PlacesChaptersTests`, fixture Matthew):
  - `theListInEachOrder`: Most named rows' ids `["218", "362", "636", "882", "978", "1263"]`, then `.notOnMap`, then `["574", "1110"]`; A to Z's names Bethlehem, Egypt, Jerusalem, Nazareth, Ramah, Zion, then the foot, Holy place, South; By chapter's headings' ids `["chapter-2", "chapter-4", "chapter-5", "chapter-12", "chapter-21", "chapter-24"]`, 11 rows, the first `"2-218"`, the last `"24-574"`, no `.notOnMap`.
  - `theHeaderLineReadsTheChapter`: `headerLine` of 2 "Chapter 2 · 5 places", of 5 "Chapter 5 · 1 place", of 12 "Chapter 12 · 1 place, none on the map"; `headingSpoken` of 2 "Chapter 2, 5 places"; `announcement` of 12 "Chapter 12, 1 place, none on the map"; `rowHint(chapter: 3) == "in chapter 3"`; `LibraryView.countLabel(.places, .init(places: places), placesChapter: 2) == "Chapter 2 · 5 places"`, with nil "8 places · 6 on the map".
  - `aHeadingChoosesItsChapterAndClosesThePage` (13.5): `LibraryPlace(book: "MAT", topic: .places, trail: [.place(636), .place(1263)])` with `openBooks = ["MAT"]`: `chooseChapter(4)` gives `placesChapter == 4`, `trail.isEmpty`, `openBooks.isEmpty`; `chooseChapter(4)` again gives nil; `chooseChapter(4)` then `chooseChapter(5)` gives 5.
  - `aRowChoosesItsPlaceAndItsChapter`: `choosePlace(882, inChapter: 4)` gives chapter 4 and `trail == [.place(882)]`; then `choosePlace(636, inChapter: nil)` keeps 4.
  - `aPlaceShownAnotherWayMovesTheChapter` (Review Focus 5): `following(showing: .place(1263), chosen: 4, …) == 21`; `(.place(636), 5) == 5`; `(.place(979), 4) == nil`; `(.place(1263), nil) == nil`; `(nil, 4) == 4`. Through `LibraryPlace`: chapter 4, `walk(to: .place(1263))`, `follow(in:)` gives 21.
  - `theChosenRowIsOneRow` (Review Focus 5): By chapter rows: `chosenRowID(showing: .place(636), chapter: 5, …) == "5-636"`; chapter nil `"2-636"`; chapter 12 `"2-636"`; `.place(979)` nil; Most named rows: `"636"`.
  - `anotherOrderClearsTheChapterAndKeepsThePlace` (Review Focus 2): chapter 4, showing 882; `clearChapter()` gives nil and still `showing == .place(882)`; `chosenRowID(showing: .place(882), chapter: nil, in: rows(items(…, .alphabetical))) == "882"`.
  - `dimmedRowsAreTheOtherChapters`: `isDimmed` of `"2-636"` with chapter 4 true, of `"4-636"` false, any row with nil false.
  - `LibraryPlaceTests.theChapterIsPartOfTheLibrarysAsItWas` (Review Focus 1): chapter 4 and place 882, then `opening(Reference(MAT 4:13))`: `placesChapter == 4`; `LibraryReturn(place:chosenBookID:).place.placesChapter == 4`; `walk`, `stepBack` and `clearTrail` keep it; `LibraryPlace(book: "MAT", topic: .places).placesChapter == nil`. `clearingTheTrailLeavesTheViewWithNothingChosen` stands unchanged.
  - `PlacesRealDataTests.everyChapterThatNamesAPlaceHasAHeading` (13.4): Acts By chapter has 28 headings and 229 rows, chapter 1's rows `["1-636", "1-657", "1-1022", "1-433", "1-861", "1-43"]`; Genesis 44 headings, rows `"2-354"` and `"3-354"` present, no `.notOnMap`; `headerLine` of Genesis 3 "Chapter 3 · 1 place, none on the map", of Acts 1 "Chapter 1 · 6 places".
- [ ] **Step 2: Run them and see them fail** (`--filter PlacesChaptersTests`, `LibraryPlaceTests`, `PlacesRealDataTests`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers.
- [ ] **Step 6: Commit:** "The chosen chapter: the list's items in three orders, and the chapter kept in the Library's place".

---

### Task 4: The Mac's list in three orders, with chapter headings

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (the heading, the menu form, the row's new forms) then `layout`. Review: `/impeccable-swift audit` on `LibraryPlacesList`, `PlacesChapterHeading`, `LibraryOrderPicker`, `LibraryListRow` and `LibraryHeaderView`, plus the three checkers.

**Files:**
- Create: `LIB/LibraryPlacesList.swift` (the list column), `LIB/PlacesChapterHeading.swift` (shared with the phone)
- Modify: `LIB/LibraryPlacesView.swift` (the list moves out; `rule` → `HairlineRule`; SwiftLint 74 → 70), `LIB/LibraryOrder.swift`, `LIB/LibrarySections.swift` (`LibraryListRow`), `LIB/LibraryView.swift` (`LibraryHeaderView`, the chapter's count), `LIB/LibraryPeopleView.swift` (only if `LibraryListRow`'s call changes)
- Test: `T/PlacesOrderTests.swift`, `T/LibraryBenchmarkTests.swift`

**Interfaces:**
- Consumes: Task 3's `PlacesList`, `PlacesChapters`, `LibraryPlace` methods; Task 2's `pins(inChapter:)`, `PlacesSelection` over pins.
- Produces:
  - `LibraryOrderPicker` gains `asMenu: Bool = false` (`.pickerStyle(.menu)`, same label and choices); People's call is unchanged.
  - `enum PlacesOrderControl { static let segmentedWidth: CGFloat; static func isSegmented(width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool }`: the three segments' measured width per platform (Step 1); on iOS false at any accessibility size (Departure 3); else `width >= segmentedWidth`. Documented as `NotesBrowserView.filterIsSegmented` is, with the measurement.
  - `LibraryListRow<ID: Hashable>`: `id: ID`; `count: Int?` (nil draws none); `note: String? = nil` (trailing, `.caption` `ink.secondary`); `isDimmed: Bool = false` (name and detail `ink.tertiary`); `accessibilityHint: String? = nil`. People's rows draw as before.
  - `struct PlacesChapterHeading: View { init(chapter: BookPlaces.Chapter, isChosen: Bool, horizontalPadding: CGFloat, onChosenRect: ((CGRect) -> Void)?, coordinateSpace: String?, onChoose: @escaping () -> Void) }`: `GroupLabel("Chapter \(n)")` and the count trailing (`.caption` `ink.secondary` `.monospacedDigit()`), on `accent.wash` at `AppRadius.md` (`.continuous`) when chosen, `md` above (none above the first), `xxs` below; one accessibility element: `headingSpoken`, button and header traits, selected while chosen, its action (Departures 13, 20).
  - `struct LibraryPlacesList: View { init(places: BookPlaces, place: Binding<LibraryPlace>, selection: Binding<PlacesSelection>) }` (macOS list column): `@AppStorage(PlacesOrder.key) order`; the control `xs` from the column's top and sides, `asMenu` when `!PlacesOrderControl.isSegmented(width: column − 2 × xs, …)` (width by `onGeometryChange`); `LazyVStack` of `PlacesList.items(places, order:)`: rows as `LibraryListRow` (no count under By chapter, "not on the map" for one without a point there, dimmed per `isDimmed`, hint `rowHint`), the foot's `LibrarySectionHeader("Not on the map")`, headings as `PlacesChapterHeading`; a row chooses by `place.choosePlace(id, inChapter: row.chapter)` and the selection over `pins(inChapter:)`; a heading by `place.chooseChapter(n)` and `selection = PlacesSelection()`; a change of order clears the chapter (`place.clearChapter()`); `.onChange(of: place.showing)` runs `place.follow(in: places)`; the chosen row (or the chosen heading when no row is) scrolls into view; ↑ ↓ through `PlacesList.rows` as today (Task 6 replaces them); `effectiveChapter` is `order == .byChapter ? place.placesChapter : nil`.
  - `LibraryPlacesView` hosts `LibraryPlacesList`, gives the map `places.pins(inChapter: effectiveChapter)` (Task 5 adds the dots and framing), and posts `AccessibilityNotification.Announcement(PlacesChapters.announcement(…))` when the effective chapter changes to one.
  - `struct LibraryHeaderView: View` in `LibraryView.swift`: `header(_:)` taken out unchanged (Departure 21); `LibraryView` reads `@AppStorage(PlacesOrder.key)` and passes `placesChapter` (only under By chapter) to `countLabel`.

- [ ] **Step 1: Measure the control.** A scratch `#if os(macOS)` test hosts `LibraryOrderPicker` with the three titles at `.small` in an `NSHostingView` and reads `fittingSize.width`; an `#if os(iOS)` scratch the same in `TestWindow` at `.large` and `.accessibility1` (`sizeThatFits`). Write the figures to the report and `benchmarks.md`; they set `segmentedWidth` (expected about 210 on the Mac, Departure 2). Delete the scratch.
- [ ] **Step 2: Write the failing tests:**
  - `PlacesOrderTests.theControlIsAMenuWhereThreeSegmentsDoNotFit`: `isSegmented(width: segmentedWidth, dynamicTypeSize: .large)` true, `(width: segmentedWidth - 1, …)` false; on macOS `isSegmented(width: 184, dynamicTypeSize: .large) == (segmentedWidth <= 184)`; on iOS `isSegmented(width: 354, dynamicTypeSize: .large) == (segmentedWidth <= 354)` and `(width: 354, dynamicTypeSize: .accessibility1) == false`.
  - `PlacesOrderTests.theMeasuredWidthIsTheControlsOwn` (`#if os(macOS)`, `@MainActor`): the hosted three-segment picker's `fittingSize.width` is within 1 pt of `segmentedWidth`.
  - `LibraryBenchmarkTests.joshuaByChapterListOpens` (`.needsRealBible`): `LibraryPlacesList` for Joshua hosted alone at the column's width by 760, `.defaultAppStorage(suite)` with `PlacesOrder.key` "byChapter", `navigation.libraryPlace` `LibraryPlace(book: "JOS", topic: .places)` with `placesChapter = 15`; the median of `host` (as the People benchmarks), `#expect(median < .milliseconds(300))` for now (Task 9 sets the bound); the suite removed after.
- [ ] **Step 3: Run them and see them fail.**
- [ ] **Step 4: Implement** as the Interfaces say.
- [ ] **Step 5: Run them and see them pass,** and `--filter LibraryBenchmarkTests` (record the new medians, informational).
- [ ] **Step 6: Render** (Mac): the list column for Acts Most named (Jerusalem chosen), A to Z (the Antiochs), By chapter with no chapter, with chapter 1 chosen and Judea's row chosen (one wash; chapters 2 on dimmed), with chapter 2 chosen and no row (the heading's wash); Genesis By chapter with chapter 3 (Eden, "not on the map"); the header line alone with "Chapter 1 · 6 places" and "Chapter 3 · 1 place, none on the map"; the control at the default column (the menu or the segments, as measured) and at a column of `segmentedWidth + 2 × xs`; Acts By chapter Light, Dark and Sepia. Check: the heading in the group label's voice with its count on the trailing edge; no count on By chapter rows; the dimmed rows lighter than the heading; the wash at radius `md`; nothing moved in People (its list in Light). Delete the render files.
- [ ] **Step 7: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (SwiftLint 70; nothing new in the touched files).
- [ ] **Step 8: Commit:** "Places' list in three orders, Most named, A to Z or By chapter, with chapter headings that choose".

**Controller live pass:** Acts Places in the Debug app if keys reach it (Departure 24): the list's control and headings, capture; ↓ through Acts 1's rows; capture the header line. The order is not switched (it would write the Debug app's preferences): Matt's list.

---

### Task 5: The map follows the chapter; the chosen pin named and on top (Mac)

**Run:** implementer **Opus**; task reviewer **Opus** (the map's camera: chapter framing, coalescing, the pin raised above its neighbours). `/impeccable-swift craft`. Review: `/impeccable-swift audit` on `PlacesMapView` and `LibraryPlacesView`, plus the three checkers.

**Files:**
- Modify: `LIB/PlacesMapView.swift`, `LIB/LibraryPlacesView.swift`, `PH/PhonePlacesScreen.swift` and `PH/PhoneLibraryPages.swift` (the new init only, behaviour unchanged until Task 7)
- Test: `T/PlacesMapRulesTests.swift` (new)

**Interfaces:**
- Consumes: `pins(inChapter:)`, `dots(inChapter:)`, `framing(chapter:)`, `Pin.title(choosing:)`, `PlacesSelection.reopen(in:)` (Task 2); `effectiveChapter` (Task 4).
- Produces:
  - `PlacesMapView.init(pins: [BookPlaces.Pin], dots: [BookPlaces.Pin] = [], framing: PlacesFraming, chosenPlaceID: Int? = nil, selection: Binding<String?>, focus: BookPlaces.Pin?, onReopen: (() -> Void)? = nil)`. Opens at `framing.frame`; a change of `framing` moves the camera to `framed(…)` with `.smooth` (a cut under Reduce Motion) through `PlacesCameraQueue` (Departure 18); `reveal` as today for a change of `focus` inside one framing. Markers titled `pin.title(choosing: chosenPlaceID)`, drawn in `drawOrder`; dots per Departure 19, drawn first. A tap through `MapReader` that `isOnChosenMarker` calls `onReopen` (Departure 15).
  - `nonisolated static func drawOrder(_ pins: [BookPlaces.Pin], chosen pinID: String?) -> [BookPlaces.Pin]` (the chosen last, the rest in order; Departure 16).
  - `nonisolated static func framed(_ frame: BookPlaces.Frame, size: CGSize, holding focus: BookPlaces.Pin?, inset: CGFloat) -> MKCoordinateRegion`: `region(frame)`, or, when `focus` is out of it by `region(_:size:holding:inset:)`, centred on `focus` at the frame's span (Departure 11).
  - `nonisolated static func isOnChosenMarker(_ tap: CGPoint, pinPoint: CGPoint, clearance: CGFloat) -> Bool`: inside the balloon's box, `pinPoint.x ± clearance / 2` across and `pinPoint.y − clearance … pinPoint.y` down.
  - `struct PlacesCameraQueue: Equatable { mutating func request() -> Int; func isCurrent(_ generation: Int) -> Bool }`.
  - `LibraryPlacesView`: the map's `dots`, `framing` (`places.framing(chapter: effectiveChapter)`), `chosenPlaceID` (the selection's), `onReopen` (`selection.reopen(in:)` over the pins in effect and `place.clearTrail()`); `choose(pin:)`'s echo guard stands. The whole-Bible map: `framing: PlacesFraming(chapter: nil, frame: BookPlaces.frame([pin]))`.

- [ ] **Step 1: Write the failing tests** in `T/PlacesMapRulesTests.swift` (`@Suite struct PlacesMapRulesTests`, fixture Matthew unless named):
  - `theChosenPinIsDrawnLast`: `drawOrder(pins, chosen: "31.777,35.235").last?.id == "31.777,35.235"`, the rest in `pins`' order; `chosen: nil` returns `pins`; an unknown id returns `pins`.
  - `aChapterIsFramedWithTheChosenPinInView` (`.needsRealBible`, Acts): `framed(frame(inChapter: 1), size: 700 by 800, holding: Jerusalem's pin, inset: 44)` equals `region(frame(inChapter: 1))` (centre and spans); holding Rome's pin (41.900, 12.483) it is centred on Rome at the frame's spans.
  - `stepsInQuickSuccessionMoveTheCameraOnce` (Review Focus 4): three `request()`s: only the third `isCurrent`; a fourth makes the third stale.
  - `aClickOnTheChosenMarkerReopensIt` (13.3): pin at (200, 300), clearance 44: (200, 280) true; (215, 270) true; (200, 340) false; (230, 280) false.
  - `theMapIsGivenTheChaptersPinsAndDots` (`.needsRealBible`, Acts): `pins(inChapter: 1).count + dots(inChapter: 1).count == 95` (every point once).
- [ ] **Step 2: Run them and see them fail** (`--filter PlacesMapRulesTests`).
- [ ] **Step 3: Implement.** The camera's existing tests (`theCameraMovesOnlyForAPinOutOfViewAndKeepsItsZoom`) stand. No test makes a `Map`.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** the list column with chapter 1 chosen (nothing should have moved). Say that the map, its dots, its camera and the pin's title are seen only live.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (SwiftLint 71, Departure 19).
- [ ] **Step 7: Commit:** "The map follows the chosen chapter: its pins framed, the book's other places as dots; the chosen pin named and drawn on top".

**Controller live pass (spec 13):** in the simulator if the Mac cannot reach Places by keys (Departure 24), and on the Mac if it can: Acts, choose Solomon's Portico, Judea and Akeldama (the pin bears each name, whole, above Jerusalem's neighbours); Joshua, a place in a shared pin; Genesis, Luz. Acts By chapter, a heading chosen: the chapter's pins framed and the dots. Capture each.

---

### Task 6: The Mac's chapter keys

**Run:** implementer **Opus**; task reviewer **Opus** (← → and ↑ ↓ across headings, focus in a list of our own). `/impeccable-swift craft`. Review: `/impeccable-swift audit` on `LibraryPlacesList`, plus the three checkers.

**Files:**
- Modify: `LIB/PlacesList.swift`, `LIB/PlacesChapters.swift`, `LIB/LibraryPlacesList.swift`
- Test: `T/PlacesChaptersTests.swift`

**Interfaces:**
- Consumes: `PlacesList.rows`, `chosenRowID`, `LibraryPlace.choosePlace`, `chooseChapter` (Task 3); `LibraryPlacesList` (Task 4).
- Produces:
  - `PlacesList.neighbour(of id: String?, step: Int, in rows: [Row]) -> Row?` (headings are not rows, so ↑ ↓ skip them; with none, ↓ the first and ↑ the last; nil past an end).
  - `PlacesChapters.step(_ step: Int, from chapter: Int?, in places: BookPlaces) -> Int?` (the previous or next chapter that names a place; nil past an end; from nil, → the first and ← the last, Departure 9) and `static func takesChapterKeys(_ order: PlacesOrder) -> Bool` (only By chapter).
  - In `LibraryPlacesList`: `onKeyPress(.upArrow / .downArrow)`: `neighbour` from the chosen row, `place.choosePlace(row.place.id, inChapter: row.chapter)`, the row into view; at an end the key is handled and nothing moves. `onKeyPress(.leftArrow / .rightArrow)`: `.ignored` unless `takesChapterKeys(order)`; `step`, then `place.chooseChapter(n)` and `selection = PlacesSelection()`, the heading into view (the least scroll, a cut); at an end handled, nothing moves. The focus ring's shape is the chosen row's wash, or the chosen heading's when no row is chosen (`LibraryChosenRowShape`). Esc is untouched (the front page's).

- [ ] **Step 1: Write the failing tests** in `PlacesChaptersTests` (fixture Matthew, By chapter rows):
  - `upAndDownSkipHeadingsAndMoveTheChapter` (13.5): `neighbour(of: "2-882", step: 1, …)?.id == "4-882"`; `(of: "4-636", step: -1)?.id == "4-882"`; `(of: "24-574", step: 1) == nil`; `(of: nil, step: 1)?.id == "2-218"`; `(of: nil, step: -1)?.id == "24-574"`. Through `LibraryPlace`: chapter 2 showing 882, the ↓ row chosen: `placesChapter == 4`, `trail == [.place(882)]` (the page stays).
  - `leftAndRightStepChaptersAndStopAtTheEnds` (13.5): `step(1, from: 2) == 4`, `step(-1, from: 4) == 2`, `step(1, from: 24) == nil`, `step(-1, from: 2) == nil`, `step(1, from: nil) == 2`, `step(-1, from: nil) == 24`. Through `LibraryPlace`: chapter 2 showing 636, → gives chapter 4 and an empty trail.
  - `onlyByChapterTakesLeftAndRight`: `takesChapterKeys(.byChapter)` true, `.mostNamed` and `.alphabetical` false.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** the list column, Acts By chapter with chapter 3 chosen (nothing should have moved). Say that focus, the ring and the keys are seen only live.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "On the Mac, left and right step Places' chapters; up and down walk the places across them".

**Controller live pass (spec 13), if keys reach Acts Places on the Mac:** By chapter is already the order only if Matt's Debug app has it (never switch it); then Tab to the list, → five times (capture each: the heading's wash, the header line, the map framed, the dots), ↓ twice (the page opens, half height, the next chapter's rows), ←, Esc (Contents). Otherwise Matt's list.

---

### Task 7: The phone's sheet in three orders and by chapter

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` then `layout`. Review: `/impeccable-swift audit` on `PhonePlacesList`, `PhoneLibraryRow` and `PlacesChapterHeading`, plus the three checkers.

**Files:**
- Create: `PH/PhonePlacesList.swift` (the sheet's root list, taken out of `PhonePlacesScreen`)
- Modify: `PH/PhonePlacesScreen.swift`, `PH/PhoneLibraryPages.swift` (`PhoneLibraryRow`, `PhoneLibraryPageMemory`, `PhoneLibraryPageView`'s Places case)
- Test: `T/PhoneShellModelTests.swift`, `T/PlacesOrderTests.swift`

**Interfaces:**
- Consumes: Tasks 1 to 5 (`PlacesList`, `PlacesChapters`, `PlacesOrderControl`, `PlacesChapterHeading`, `PlacesMapView`'s init).
- Produces:
  - `PhoneLibraryPageMemory.placesChapters: [String: Int]` (by book): `init(opening:)` takes `place.placesChapter` for its book; `place(for:)` writes it back for the path's book (so a lookup's `LibraryReturn` keeps it, Departure 12).
  - `PhoneLibraryRow` gains `count: Int?`, `note: String? = nil`, `isDimmed: Bool = false`, `accessibilityHint: String? = nil`, as `LibraryListRow` (Task 4).
  - `struct PhonePlacesList: View { init(places: BookPlaces, gathered: [PlaceSummary]?, chapter: Int?, order: Binding<PlacesOrder>, onChooseRow: @escaping (PlacesList.Row) -> Void, onChooseHeading: @escaping (Int) -> Void) }`: the count line (`headerLine` while a chapter is chosen, else `countLabel`), then the control (`lg` sides, `sm` above and below, `asMenu` per `PlacesOrderControl` at the sheet's inside width and the dynamic type size), then the gathered pin's places as today, then `PlacesList.items`: rows as `PhoneLibraryRow` with no chosen state, headings as `PlacesChapterHeading` at `lg`, the credit line.
  - `PhonePlacesScreen`: `@AppStorage(PlacesOrder.key)`; the chapter from the memory (`chapter: Binding<Int?>` handed down by `PhoneLibraryPageView`), in effect only under By chapter; a heading tap sets `afterHeading` and resets the selection (the sheet's path is already empty there); a row tap sets its chapter and pushes the place's page; the follow rule on a change of the place on show; a change of order clears it; Places' entry removed from the memory when Places leaves the path; the announcement as on the Mac; the map given the chapter's pins, dots, framing and chosen place (Task 5's init; the cover is Task 8's).

- [ ] **Step 1: Write the failing tests:**
  - `PhoneShellModelTests.thePhonesMemoryKeepsTheChapterAcrossALookup` (`#if os(iOS)`, Review Focus 1): `var place = LibraryPlace(book: "MAT", topic: .places, trail: [.place(882)]); place.placesChapter = 4`; `PhoneLibraryPageMemory(opening: place.opening(ref("MAT", 4, 13)))`: `placesChapters["MAT"] == 4`; `place(for: place.pages)?.placesChapter == 4`; a memory opened on `nil` has none; a `LibraryPlace(book: "ACT", topic: .places)` path reads none.
  - `PlacesOrderTests.thePhonesListShowsTheChapterLine`: `PhonePlacesList.countLine(places, chapter: 12) == "Chapter 12 · 1 place, none on the map"`, `(chapter: nil) == "8 places · 6 on the map"` (a `nonisolated static` helper the view uses).
- [ ] **Step 2: Run them and see them fail** (`-only-testing:ScriptureUITests/PhoneShellModelTests`, `--filter PlacesOrderTests`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** (phone): `PhonePlacesList` for Acts Most named, A to Z, By chapter with no chapter and with chapter 1 chosen (the heading's wash, chapter 2 onward dimmed), Genesis By chapter (chapter 3's "not on the map"), at `.large` and `.accessibility5` (the menu); Acts By chapter Light, Dark and Sepia. Check: the control under the count line; the headings at `lg`; rows with no wash; Dynamic Type reflows. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "The phone's Places sheet in three orders, by chapter with the map following, the chapter kept on coming back".

**Controller live pass:** in the simulator, Acts › Places, the sheet at medium: screenshot; the control's By chapter is not tapped (it would write the simulator's preferences, which sync nothing but are left as found; Matt's list) unless the simulator's order is already By chapter; tap a heading; screenshot (the chapter framed above the sheet); tap a row (pushed); Back.

---

### Task 8: The phone's map clear of the sheet

**Run:** implementer **Opus**; task reviewer **Opus** (the phone's reveal under the sheet, the chapter framed above it). `/impeccable-swift craft`. Review: `/impeccable-swift audit` on `PlacesMapView` and `PhonePlacesScreen`, plus the three checkers.

**Files:**
- Modify: `LIB/PlacesMapView.swift`, `PH/PhonePlacesScreen.swift`
- Test: `T/PlacesMapRulesTests.swift`, `T/PlacesSelectionTests.swift`

**Interfaces:**
- Consumes: Task 5's map and rules; Task 7's screen.
- Produces:
  - `PlacesMapView.init` gains `bottomCover: CGFloat = 0`; `region(_:size:holding:inset:)` gains `bottomCover: CGFloat = 0`: in view only between `inset` from the top and `bottomCover + inset` from the bottom; moved to the middle of the uncovered part at the same span (centre latitude `pin.latitude − span × bottomCover / (2 × height)`, Departure 17). `framed(…)` gains `bottomCover: CGFloat = 0`: the frame's latitude span grown by `height / (height − bottomCover)` and its centre lowered so the frame's centre sits mid-way down the uncovered part. `nonisolated static func canReveal(size: CGSize, bottomCover: CGFloat, inset: CGFloat) -> Bool` (`size.height − bottomCover > 2 × inset`). The Mac passes 0 and is unchanged.
  - `PhonePlacesScreen`: `sheetCover` follows the sheet at every detent (4.3; the large detent included); the map is given `bottomCover: sheetCover` and keeps `.safeAreaPadding(.bottom, sheetCover)`; `reveal` runs on a change of the cover too, only when `canReveal`; a gathered pin's re-tap (`onReopen`) returns the sheet to its list with the pin's places at its head.

- [ ] **Step 1: Write the failing tests:**
  - `PlacesMapRulesTests.aPinUnderTheSheetIsOutOfView` (13.6): a region at (32, 35), spans 1 by 1, size 400 by 800, cover 400, inset 0: a pin at latitude 31.8 is moved, the new centre latitude 31.55 (± 1e-9), spans unchanged; a pin at 32.25 is in view (nil); with cover 0 the pin at 31.8 is in view (nil).
  - `PlacesMapRulesTests.aChapterIsFramedAboveTheSheet`: `framed(Frame(32, 35, 1, 1), size: 400 by 800, holding: nil, inset: 0, bottomCover: 400)` has latitude span 2, longitude span 1, centre latitude 31.5; with cover 0 it equals `region(frame)`.
  - `PlacesMapRulesTests.nothingPansWhenTheSheetCoversTheMap`: `canReveal(size: 400 by 800, bottomCover: 400, inset: 44)` true; `(bottomCover: 760)` false.
  - `PlacesSelectionTests.theCameraMovesOnlyForAPinOutOfViewAndKeepsItsZoom` stands unchanged (the default cover).
- [ ] **Step 2: Run them and see them fail** (`--filter PlacesMapRulesTests`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 6: Commit:** "On the phone, a chosen pin is kept clear of the sheet, and a chapter is framed above it, at every detent".

**Controller live pass (spec 13):** in the simulator, Acts › Places, the sheet at medium: tap Solomon's Portico's row, Back to the list (the pin above the sheet, titled "Solomon's Portico"); a heading (the chapter framed above the sheet); the sheet to large and back (the map's padding follows; nothing jumps); a tap on the chosen gathered pin (its places at the list's head). If the pin lands high by half the cover, Departure 17's offset term goes in the fix wave.

---

### Task 9: Speed, and a polish pass

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift polish` over `LibraryPlacesList`, `PlacesChapterHeading`, `LibraryOrderPicker`'s menu form, `LibraryHeaderView`, `PhonePlacesList` and the dots. Review: `/impeccable-swift audit`, plus the three checkers.

**Files:**
- Modify: as the polish and the benchmarks require (only the files this plan created or changed)
- Test: `T/LibraryBenchmarkTests.swift`

- [ ] **Step 1: Add `joshuasChapterFifteenMapContent`** (pure, `.needsRealBible`): the median of building `pins(inChapter: 15)`, `dots(inChapter: 15)`, `drawOrder` and `framing(chapter: 15)` for Joshua, and `PlacesList.items(…, .byChapter)`.
- [ ] **Step 2: Measure:** `joshuasPlacesLoad`, `joshuaByChapterListOpens` and `joshuasChapterFifteenMapContent` three times each, alone; append to `benchmarks.md`. If a figure is out of proportion to the work (a list open well over the 1 Chronicles People open's 160 ms, a load over 50 ms), find why before any change (the read, the chapters' build, `items` per body, the headings) and fix it within the spec (a memo per order, a lazy stack); measure again.
- [ ] **Step 3: Set the bounds** (Departure 22): each `< 1.5 × median`, rounded up to 10 ms, and the measured figures in each test's comment. Run them.
- [ ] **Step 4: Polish** per the command: the heading's rhythm against the rows (`md` above, `xxs` under), the dimmed rows' contrast in Light, Dark and Sepia (`ink.tertiary` names stay readable as the front page's dimmed books), the menu form's alignment with the column's top, hit areas (a heading's whole row; the phone's headings at least a scaled 44 pt), Reduce Motion (the camera a cut), Increase Contrast where `Palette` has the variants. Fix within the spec; list anything outside it for the backlog.
- [ ] **Step 5: Render the whole set** (Global Constraints › Renders): the Mac's Acts in three orders, By chapter with chapters 1 and 2 chosen, Genesis chapter 3, Joshua chapter 15; the header line both ways; the phone's Acts in three orders and chapter 1 at `.large` and `.accessibility5`; Light, Dark and Sepia on both. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (record the totals).
- [ ] **Step 7: Commit:** "Places by chapter measured on Joshua; spacing, contrast and motion settled".

---

### Task 10: The record

**Run:** implementer Sonnet; task reviewer Sonnet. No view changes; the review checks each document against the code as built and runs the three checkers for the final counts.

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md` (its Places paragraph), `docs/superpowers/specs/2026-11-23-milestone-11-places-design.md` (section 14), `docs/BACKLOG.md`

- [ ] **Step 1: DESIGN.md** (spec 9): **Library views › Places** (`DESIGN.md:385`): the Order control's three choices and its menu form (Departure 2's measure), A to Z and By chapter as built, the chapter headings, the header line's "Chapter 1 · 6 places", the chapter's pins and the book's other places as `ink.tertiary` dots, other chapters' rows dimmed, ← → between chapters and ↑ ↓ across them, Back keeping the chapter; **the pin**: a gathered pin titled with its chosen place while one is chosen, the chosen pin drawn above its neighbours, the re-click listing a pin's places. **Order control** (`:398`): Places' three segments, its own key `libraryPlacesOrder`, the menu where they do not fit. **iPhone › Library › Places** (`:520` and the sheet's line): the sheet's control under the count line, its headings and dimmed rows, the chosen pin and the chapter kept clear of the sheet at every detent. **Motion** (`:462`): the camera's move per chapter (`.smooth`, a cut under Reduce Motion, the last chapter chosen only). **Don't** (`:494`): the line stays as written; add "A chapter's dots are the map's own content, never views over it." New component entries **Chapter heading** (`PlacesChapterHeading`) and **Places list** (`LibraryPlacesList`, `PhonePlacesList`).
- [ ] **Step 2: DESIGN.json:** the same entries (the Places view, the Order Control, the phone's Places sheet, the camera's motion, the new components); `python3 -m json.tool DESIGN.json > /dev/null`.
- [ ] **Step 3: README.md** (`:112`): the Places paragraph: the three orders, By chapter with the map following the chosen chapter, the arrows on the Mac, the chosen place's name on its pin.
- [ ] **Step 4: The spec's "As built"** (section 14): what was built, file by file in a line each; every call from this plan's Departures and the ledger's rulings, each marked "(call, unattended)" with its reason and cost; "The data, checked" and where it differs from the spec (Departure 23); the control's measured widths; the benchmarks' before and after medians and their bounds; the checker counts (74 → 71, the four old findings fixed, the dot's one); both suites' counts; what the controller saw live and where. Then **"For Matt"**, in the order to look: Acts and Joshua By chapter on both devices, stepping chapters (← → on the Mac; headings on the phone); Back from a passage returns to the same chapter; the switch's three choices at large text (and that the Mac shows a menu at the default size, Departure 2, first); VoiceOver on a heading; Dark and Sepia on the dots; Solomon's Portico's pin named, and a click on the chosen gathered pin; the phone install (`Scripts/install-phone.sh debug`, his word, phone unlocked, ProtonVPN off). Then the calls he may want otherwise (Departures 2, 6, 7, 8, 9, 10, 11). Then **"What nobody has seen"**: the map's tiles, dots and camera on the Mac if keys could not reach Places (Departure 24); a pointer click on a marker or a row; the camera's coalescing under fast keys; VoiceOver anywhere (the headings, the announcement, the hidden dots); Reduce Motion on the camera; the phone on a device.
- [ ] **Step 5: docs/BACKLOG.md** (spec 12): in **"Places on the Mac"** delete "Clicking a gathered pin while one of its places is chosen does nothing ("At the same spot" is the way back to its siblings);" and keep the rest; in **"The phone's Places sheet"** delete "does not refresh the map's padding at the large detent;" and keep "the quarter detent is unseen" unless the live pass saw it. If Departure 15's re-click could not be confirmed, leave a line saying so. Add any item the polish set aside, and a line for the Mac's Places having no key route if Departure 24 held (beside About's).
- [ ] **Step 6: Run the full package suite, then the full iOS `ScriptureUITests`, one after the other;** record both counts (above 1,678 and 1,134); the three checkers, recorded in "As built".
- [ ] **Step 7: Commit:** "docs: Places as built: DESIGN, README, the spec's As built and the backlog".

**After Task 10 (the controller):** the whole-project review on Opus (`/impeccable-swift critique` over `LibraryPlacesList`, `PlacesChapterHeading`, `PlacesMapView`, `PhonePlacesList`, `LibraryOrderPicker` and `LibraryHeaderView`), one fix wave, one scoped re-review; then the handover's "Before a project is called done": both suites and both Debug builds one after another, the Mac Debug app restarted after the idle check, **the main spec's milestone 11 box 4 ticked by the controller** (`docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`), the handover's table, the ledger copied to `docs/superpowers/ledgers/milestone-11/2026-11-23-milestone-11-places.md`.

## Pre-flight rulings

The pre-flight scan (2026-11-23, Opus, against the code at `ba6bdd2`) found 5 conflicts, 9 gaps and 14 notes. Each is ruled as the scan proposed (its reason and cost are beside it); each binds the task it names over that task's own text below. Ruling 1 replaces Departure 2: Places' list column is a scaled 232 pt so the three segments show.

### Conflicts

1. **Departure 2: the Mac would show a menu where the spec means segments, and the threshold is measured the wrong way** (Departure 2; Task 4 Step 1, `PlacesOrderControl.segmentedWidth`, `theMeasuredWidthIsTheControlsOwn`; spec 2 "with the same control People has", spec 5.1 "where three segments do not fit (the Mac's column at large text, the phone at accessibility sizes) it becomes a menu"). Measured with the SwiftUI control itself (`Picker` `.segmented`, `.labelsHidden()`, `.controlSize(.small)`, the three titles): it lays out at **210 pt at the least** (`NSHostingController.sizeThatFits(in: 1 by 100)`, segments sized to their labels) and **249 pt ideally** (`fittingSize`, equal segments); in a 184 pt frame it stays 210 and overhangs the column by 13 pt each side. People's two are 134 / 166, so People fits today. So Departure 2's fact is right (three do not fit 184), but Step 1 reads `fittingSize`, which gives 249, not the "about 210" it expects; with 249 the threshold would also refuse a column that the control does fit.
   Options against spec 5.1's words:
   - **A. Menu at the default column (the plan).** Cost: Places shows "Most named ⌄" where People shows segments; the spec lists only large text and accessibility sizes as menu cases, so this reads the spec's rule against its own example. Nothing else changes.
   - **B. Places' column at a scaled 232 pt** (the control's inside 216 ≥ 210, 6 pt of slack). Cost: the list column is 32 pt wider than People's (the hairline moves when switching topic), the map 32 pt narrower, DESIGN's "a scaled 200 pt column" for Places changes in Task 10. The spec fixes no column width; DESIGN follows the build (spec 9).
   - C. Full column with no side padding: 200 < 210, does not fit. D. `.controlSize(.mini)` (174 fits): not People's control, 9 pt text. E. Widen People too: reopens project 3. All rejected.
   *Ruling:* **B.** `LibraryPlacesView`'s list column is a scaled 232 (its own constant, documented with the measure); `segmentedWidth` is the control's **minimum** width, 210 on the Mac (measured as `sizeThatFits` at a 1 pt proposal), and `theMeasuredWidthIsTheControlsOwn` pins that minimum within 1 pt, not `fittingSize`; the menu rule stays for any narrower case; Task 4's test asserts `isSegmented(width: 216, dynamicTypeSize: .large) == true` on the Mac; Task 10 records 232, the measures (210 / 249) and the call; Matt's list item becomes "Places' column is 32 pt wider than People's, to hold three segments". *Cost if wrong:* one constant back to 200, and the menu shows (A).

2. **The phone's count line is an iOS-only type tested from an unguarded suite, and the same rule twice** (Task 7 `PlacesOrderTests.thePhonesListShowsTheChapterLine`, `PhonePlacesList.countLine`; Task 3 `LibraryView.countLabel(…placesChapter:)`; Global Constraints › Tests "Pure tests carry no platform guard"). `PH/` files are `#if os(iOS)`, so the package suite on macOS would not compile; and "the chapter's `headerLine` when a chapter of the book is chosen, else `countLabel`" would be written once for each app. *Ruling:* `PlacesChapters.countLine(_ places: BookPlaces, chapter: Int?) -> String` (Task 3), used by `LibraryView.countLabel` and `PhonePlacesList`; Task 7's test calls `PlacesChapters.countLine` and needs no guard. *Cost if wrong:* the package suite stops compiling at Task 7, or a duplicated-logic Important.

3. **A hosted test in a pure suite** (Task 4 `theMeasuredWidthIsTheControlsOwn` in `PlacesOrderTests`; Global Constraints: a hosting test is `@MainActor` in a `.serialized` suite, `#if os(macOS)` for `NSHostingView`). *Ruling:* it goes in its own `@MainActor @Suite(.serialized) struct PlacesOrderControlHostTests` under `#if os(macOS)` in `T/PlacesOrderTests.swift`; the iOS figure stays a scratch measure (Step 1). *Cost if wrong:* AppKit work off the main actor in a parallel suite (the memory's crash).

4. **`joshuaByChapterListOpens` cannot use "the median of `host`"** (Task 4 Step 2). `LibraryBenchmarkTests.host(_:in:settled:)` (`LibraryBenchmarkTests.swift:66-80`) hosts a `LibraryView`, which on Places makes a `Map` (forbidden), and it takes a `NavigationModel`, not a list. *Ruling:* add a second private helper in the suite that hosts `LibraryPlacesList` alone in an `NSHostingView` at the column's width by 760, with `.defaultAppStorage(suite)` ("byChapter"), a `place` binding over a local `LibraryPlace(book: "JOS", topic: .places)` with `placesChapter = 15` and a selection binding, `settled` as the existing helper; the suite removed after. *Cost if wrong:* a test that makes a `Map`, or one that does not compile.

5. **Departure 24's premise is not what the code says** (Departure 24; the live passes of Tasks 4, 5, 6; DESIGN.md's About "Keyboard" line; BACKLOG:182). The pane's People, Places and About icons are plain `Button`s with no `.focusable(false)` anywhere above them, the same kind as "The whole plan", which project 2's pass saw take Tab; this Mac has `AppleKeyboardUIMode` 2 (keyboard navigation on); project 3's later pass wrote "the cycle runs toolbar, header, the notice, the right pane's icons and grid, then the page". Project 2's pass said the icons were never a stop. The code says they should be Tab stops; the two passes disagree. *Ruling:* the controller tries the key route first: Tab from the contents toward the pane, confirming the focused element through Accessibility on the Debug app's pid (not by eye), and Space on the Places icon; only if that fails does Departure 24's fallback (the simulator, Matt's list) apply. Task 10 writes DESIGN's About keyboard line and BACKLOG:182 to match what the pass saw (if the icons take Tab, both lines are wrong and come out). *Cost if wrong:* one Tab cycle tried; or, unruled, a Mac live pass skipped that could have been made.

### Gaps

6. **The views are not told to choose over the pins in effect** (Task 4 `LibraryPlacesView`, Task 5, Task 7 `PhonePlacesScreen`; Task 2 adds the `in pins:` forms). `LibraryPlacesView.current(in:)`, `choose(pin:)` (and its echo guard), `gathered(in:)` and the focus lookup (`:58-73, 79, 109`), and the phone's (`PhonePlacesScreen.swift:61-87, 117`) all run over `places.pins`. Under a chapter, a click on Jerusalem's pin in Acts 5 (Jerusalem alone there) would gather the book's five places instead of choosing Jerusalem. *Ruling:* every `PlacesSelection` call and the focus lookup in both views use `places.pins(inChapter: effective)`; the pin ids are the points, so a selection carries across. *Cost if wrong:* the map and its chapter disagree on every gathered point.

7. **`effectiveChapter` has four readers and one definition** (Task 4: defined in `LibraryPlacesList`, which owns `@AppStorage(PlacesOrder.key)`; read by `LibraryView`'s count, `LibraryPlacesView`'s map and announcement in Tasks 4-5, and the phone in Task 7). *Ruling:* `PlacesChapters.effective(_ chapter: Int?, order: PlacesOrder) -> Int?` (Task 3), each view reading the order with its own `@AppStorage(PlacesOrder.key)`. *Cost if wrong:* the header and the map follow a chapter the list has hidden, or the rule written three times.

8. **Two pieces of logic the plan mandates twice** (plan-mandated, Important by the rubric). (a) Task 6's `PlacesList.neighbour(of:step:in:)` is `LibraryPeopleView.neighbour` (`LibraryPeopleView.swift:31-34`) over another id type. (b) Spec 5.3's A to Z (name by `localizedStandardCompare`, label none first, id) is `BookPeople.nameOrder` (`BookPeople.swift:44-56`) over another type. *Ruling:* (a) People's `neighbour` becomes generic over `ID: Equatable` (its tests stand) and `PlacesList.neighbour` returns the row whose id it gives; (b) one comparator over `(name, label, id)` (e.g. `LibraryNameOrder.precedes`) in `LIB`, used by `BookPeople` and `BookPlaces`. *Cost if wrong:* two Importants in review and a fix wave spent on them.

9. **The re-click can close a neighbour's page** (Departure 15; Task 5 `onReopen` "`selection.reopen(in:)` … and `place.clearTrail()`"). The tap fires on every click; a click inside the chosen marker's box that MapKit gives to an overlapping neighbour (2,163 pairs lie within 0.02°) selects the neighbour and then clears the trail, closing its page; the order of the two events is MapKit's. *Ruling:* `onReopen` acts a run-loop turn after the tap, only while the map's selection is still the chosen pin and a place of several is chosen; `clearTrail` (the phone: `sheetPath = []`) only when `reopen` changed the selection. Departure 15 is otherwise consistent with `PlacesMapView` today: no `MapReader` exists, MapKit writes nothing when a selected marker is clicked again, and `MapReader` with a simultaneous `SpatialTapGesture` and `proxy.convert(_:to: .local)` fits the current `Map(position:selection:)`. *Cost if wrong:* a click on a neighbouring pin opens nothing.

10. **The phone's reveal would chase the sheet's edge during a drag** (Task 8 "`reveal` runs on a change of the cover too"). The cover is written on every height tick of the sheet's `GeometryReader` (`PhonePlacesScreen.swift:103-106`), so a drag from medium to large would start a `.smooth` move per frame. *Ruling:* the padding follows every tick; `reveal` runs on a change of the detent once settled (`onChange(of: detent)`) and on a change of focus, and only when `canReveal`. *Cost if wrong:* a jittering camera on every sheet drag.

11. **Spec 13's live By chapter pass is unreachable as written** (Tasks 4, 6, 7 live passes: "the order is not switched", Matt's list; spec 13 "Live, by the controller": Acts By chapter, ← and → through five chapters; the simulator's heading). *Ruling:* the controller launches the Mac Debug app, and the simulator's app with `simctl launch`, with the arguments `-libraryPlacesOrder byChapter`: the argument domain is read by `@AppStorage` and written nowhere, so the Debug app's and the simulator's preferences stay as found; the control is never touched; the app is relaunched without the argument at the end (the handover's restart). *Cost if wrong:* nobody sees By chapter live before Matt, or a preference written to Matt's Debug app.

12. **The chosen pin's new title and draw order could close the page it was chosen for** (Departure 16; Task 5 markers titled `pin.title(choosing:)` and drawn in `drawOrder`). If MapKit rebuilds a selected `Marker` whose title or place in the content changes, it deselects it and writes nil, and `choose(pin: nil)` clears the trail (`LibraryPlacesView.swift:69-73`; the phone's `:74-78`). *Ruling:* the `ForEach` keeps `pin.id` as its identity (only the title and the order change); the controller's first check after Task 5 is "choose Solomon's Portico in the list: the page stays open, the pin selected and titled"; if MapKit does echo nil, the map's nil write is ignored when it comes in the same update as a list choice (a flag set by the list's choice and cleared a turn later), recorded as a fix. *Cost if wrong:* the project's central fix ships closing every page it names.

13. **Two of spec 13's items are pinned only in part** (13.4 "A to Z is alphabetical"; 13.5 "another order … clears it"). *Ruling:* `actsInEachOrder` also checks that the whole `onMapByName` equals its names sorted by `localizedStandardCompare` (as `LibraryOrderTests.swift:15-16` does); the order switch's effect is a pure rule, `PlacesChapters.afterOrderChange(to:chosen:) -> Int?` (nil unless By chapter and unchanged), used by both views' `onChange(of: order)` and tested. *Cost if wrong:* a list "in A to Z" sorted by byte order passes; the switch's clear is seen only live.

14. **When the chapter clears, VoiceOver hears nothing** (Task 4 "posts the announcement when the effective chapter changes to one"; Departure 20 "on every change … by any route"; spec 6 "When the chosen chapter changes, the header line's new text is announced"). *Ruling:* announce on every change of the effective chapter, the count line when it clears ("101 places, 101 on the map"), on both apps. *Cost if wrong:* a silent return to the whole book.

### Notes

15. **The phone uses `LibraryPlacesView`'s statics** (`sharedNames`, `detail`, `accessibilityLabel`; `PhonePlacesScreen.swift:116, 155, 157`). If Task 4's "(macOS list column)" file is `#if os(macOS)`, they stay in `LibraryPlacesView` (or move to `PlacesList`), compiled on both. *Cost:* the iOS build breaks at Task 4.

16. **`SyncedPreferences.keys` is `@MainActor`** (Task 1 `thePlacesOrderIsKeptOnThisDeviceOnly`). *Ruling:* `@MainActor @Test`, as `LibraryOrderTests.swift:34`. *Cost:* a Swift 6 isolation error.

17. **The "relaunch" test tests `UserDefaults`** (Task 1 `theStoredOrderIsReadBackAfterARelaunch`; spec 13.7). *Ruling:* read through the view's own path: `AppStorage(wrappedValue: PlacesOrder.mostNamed, PlacesOrder.key, store: suite).wrappedValue` on the set suite (`.byChapter`, from a second `UserDefaults` of the same name) and on an empty one (`.mostNamed`); one `removePersistentDomain(forName:)`. *Cost:* a reviewer's "asserts the framework" finding.

18. **Assertions that restate the code** (Task 2 `frame(inChapter: 4) == BookPlaces.frame(places.pins(inChapter: 4))` and `framing(chapter: 4) == PlacesFraming(chapter: 4, frame: frame(inChapter: 4))`; Task 4 `isSegmented(width: 184…) == (segmentedWidth <= 184)`). *Ruling:* pin figures: chapter 4's frame is centre 32.241967, 35.268253, spans 1.301378 by 0.5 (± 0.001; Jerusalem 31.777189, 35.234978 and Nazareth 32.706745, 35.301528); `framing(chapter: 4).chapter == 4` with that frame; the Mac's `isSegmented(width: 216…) == true` (ruling 1). *Cost:* minor findings.

19. **A step to the same place under another chapter folds its page** (Task 3 `choosePlace`, Task 6 ↓ from "2-882" to "4-882"). `LibraryPlace.choose` resets `openBooks` and the anchor even when the place is the one showing. *Ruling:* `choosePlace` sets the chapter and calls `choose` only when the trail is not already that place alone. The tests stand. *Cost:* the open verses close on a step that "keeps the page".

20. **The phone's two models of the region** (Departure 17; Task 8). `PlacesMapView` measures the `Map`'s own frame inside the outer `.safeAreaPadding`, and reads MapKit's reported region; the plan assumes both are the whole map. If the simulator shows MapKit already fitting `.region` into the safe area, the cover term goes from **both** rules (the in-view test and the centring), not only the offset, and the screen passes `bottomCover: 0` while keeping the padding; 13.6's test stays as the rule's pin. *Cost:* a pin placed high by half the cover, or panned when in view.

21. **Departure 15 on the phone** is consistent: the sheet lets taps through up to medium (`presentationBackgroundInteraction(.enabled(upThrough: .medium))`); `onReopen` empties the sheet's path, as Task 8 says.

22. **The phone's threshold at non-accessibility sizes above `.large`** (Departure 3; Task 4 Step 1 measures `.large` and `.accessibility1`). If the segments' text grows from `.xLarge` to `.xxxLarge`, one constant at `.large` is too small; measure `.xxxLarge` too and say whether the control's text scales; if it does, `segmentedWidth` is per size. *Cost:* three clipped segments at xxxLarge.

23. **The memory test's suite** (Task 7 `PhoneShellModelTests.thePhonesMemoryKeepsTheChapterAcrossALookup`). The memory tests and `ref(_:_:_:)` live in `PhoneLibraryRulesTests`, the `#if os(iOS)` block of `PhoneShellModelTests.swift:337-400`. *Ruling:* add it there. *Cost:* none.

24. **An untitled `Annotation` may still be a VoiceOver element** even with its circle hidden (Departure 19; spec 6 "Dots are hidden"). Not testable without a `Map`; on Matt's VoiceOver list.

25. **Lint in the new views.** `PlacesChapterHeading`'s `.onTapGesture` needs `.accessibilityLabel` in its chain (impeccable-lint `accessibility_label`); `RoundedRectangle(…, style: .continuous)`; the dot's size a `@ScaledMetric`, never a literal `.frame`; with `.accessibilityElement(children: .ignore)` the heading adds `.isHeader` itself (`GroupLabel`'s trait is on a child). *Cost:* 27 → 28 or 71 → 72.

26. **`LibraryPlace` is `Hashable`**, so `placesChapter` joins its equality: a chapter choice now writes `navigation.libraryPlace` through the Mac's binding. `LibraryView`'s caches key on book, topic, showing and translation (`LibraryView.swift:85-99`), so nothing is re-read. No action.

27. **Figures for As built, none in a test:** Acts's largest chapter is 27 (20 places); Genesis's Rehoboths sort 992, 990, 991 in A to Z (their labels are verse references); the two Valleys of Shaveh share Jerusalem's point in Genesis; Joshua's 3 unlocated places make 6 rows (Judah 1280 has 15 verses in chapter 15).

28. **Checkers at head:** SwiftLint 74, impeccable-lint 27, asset checker 0 (exit 0), as the plan says. The suites were not run.

Counts: 42 interfaces checked (36 match, 1 differs, 4 partly, 1 not checked); 5 conflicts (1-5), 9 gaps (6-14), 14 notes (15-28).
