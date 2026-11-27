# Milestone 10, Project 4: The Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Mac's front page becomes one contents page with a book pane; marked chapters carry a ring in the reader's colours on both apps; and People, Places and About open for any of the 66 books, by name from search too, with dates that can be turned off.

**Architecture:** The Bible database (schema 5) gains people, places, events, their verses, families and each book's writers, written by the importer from Theographic's tables, which a new fetch script pins by commit and digest.
- Pure models hold every rule and are tested against a hand-made fixture: `ContentsPage` (the contents, its columns, search and keys), `ChapterRing`, `BookPeople`, `PersonPage`, `BookPlaces`, `PlacePage`, `BookAbout`, `LibraryYear`, `LibraryDates`. The views are thin SwiftUI over them, shared between the apps where a page is the same.
- Where the reader is in the Library is one value, `LibraryPlace`, held in `NavigationModel`, so it outlives the reader showing. A passage opened from the Library is a lookup that keeps a `LibraryReturn`; the history stays chapters only.
- Search reads names beside Scripture, off the main actor, and adds two groups and two chips to project 2's palette.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit and UIKit, MapKit, GRDB with SQLite, SwiftData, Swift Testing, bash, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-16-milestone-10-library-design.md`. Read it with this plan; section numbers below are the spec's. The check of its sections 6.6 and 6.7 against the code is `.superpowers/sdd/library-6.6-6.7-check.md`.

Paths: `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `LIB` is `SUI/Library` (new), `PH` is `SUI/Phone`, `SD` is `Packages/ScriptureKit/Sources/ScriptureData`, `SM` is `Packages/ScriptureKit/Sources/ScriptureModel`, `IMP` is `Packages/ScriptureKit/Sources/BibleImporterCore`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `TD` is `Packages/ScriptureKit/Tests/ScriptureDataTests`, `TM` is `Packages/ScriptureKit/Tests/ScriptureModelTests`, `TI` is `Packages/ScriptureKit/Tests/BibleImporterCoreTests`, `MAC` is `Apps/Mac/ReadingThroughScripture`.

**Built on, read in the code at `07c8a2b` (2026-11-18).** `BibleSchema.version == 4`; `VerseKey`; `CrossReferenceFile.books` (OSIS names to book codes, the same names Theographic uses); `BibleDatabaseWriter.importAll(from:translations:sourceCommit:ebible:crossReferences:)`; `NavigationModel` (`lookUp`, `lookupReturn`, `returnFromLookup`, `goBack`, `goHome`, `keepLookup`, `endLookupHere`, `selectedBookID`, `versePreview`, `answer(to:from:)`, `select`); `NavigationHistory`; `FrontPageView`, `FrontPageSearch`, `BookshelfView`, `ChapterGridView`, `ChapterCell`, `BookReferenceRow`; `LibraryList`, `PhoneLibraryScreen`, `PhoneShellModel`, `PhoneRootView`, `PhoneSearchScreen`; `SearchRanker`, `SearchResults`, `SearchChip`, `SearchLimits`, `PaletteItem`; `SyncedPreferences.keys` (17 keys); `Credits.all.count == 16`; `PaletteCommand.all.count == 32`; `ReaderKeyAction.allCases.count == 22`; `OKLCH`, `MarkLightness`; `VersePreviewView(preview:openTitle:onOpen:)`; `ReferenceLinker.url(for:)`. The `T` fixtures hold Psalms 1, 2, 118 and 119, Matthew 1 to 6 and Tobit 1 (books `PSA`, `MAT`, `TOB`; WEB and KJV); the `TD` fixtures hold all of Matthew in WEB, the Psalms in KJV, John in both and Tobit in WEB. In a file that imports SwiftUI, `Translation` is written `ScriptureData.Translation`. If a name differs when a task is built, say so before going on.

## The data, measured

`robertrouse/theographic-bible-metadata`, CC BY-SA 4.0, commit `b9a84854369502d10cdc7086e58e2794dbfd6722`. Each table in `json/` is an array of `{"id": "rec…", "createdTime": "…", "fields": {…}}`; a link from one table to another is a list of record ids. The five tables fetched (48,530,462 bytes in all):

| File | SHA-256 | Records | Fields kept |
|---|---|---|---|
| `books.json` | `a3ed9fc30b0d12c01f5259a8e8e793e3afdfa63ae2d51ad18bb82d5e630878a9` | 66 | `osisName`, `writers` (a list of `personLookup` strings, not record ids) |
| `people.json` | `031d5f7f662bba093fb712243d17182925289eaf420e2490ba606bf71600448a` | 3,067 | `personID`, `personLookup`, `name`, `displayTitle`, `surname`, `alsoCalled`, `gender`, `birthYear`, `deathYear`, `father`, `mother`, `partners`, `siblings`, `halfSiblingsSameFather`, `halfSiblingsSameMother`, `children`, `verses`, `dictText` |
| `places.json` | `577b654f3f2c5867b7502aec647c039c53f8a0477971a2d913be04a873fcad7c` | 1,297 | `placeID`, `placeLookup`, `displayTitle`, `kjvName`, `esvName`, `aliases`, `featureType`, `featureSubType`, `latitude`, `longitude`, `precision`, `verses`, `dictText` |
| `events.json` | `cfff452550897d4ec3bc622179d680a3463146aec5ba5bf46359f1b1d6bd0e31` | 501 | `eventID`, `title`, `startDate`, `sortKey`, `verses` |
| `verses.json` | `db9fe10c996720d5b9c1dcd02caf1c4b3c1ebf17810e98af59be794e0038c58d` | 31,102 | `osisRef` ("Gen.1.1"; 3 John ends at 1:14), `verseID` ("01001001", for order) |

What the tables hold, against the spec's claims:
- **Ids.** `personID`, `placeID` and `eventID` are integers, each unique, and the number at the end of the lookup ("abraham_58" is 58). They are the keys. 459 values of `name` belong to more than one person (1,712 people), as the spec says.
- **Names.** `name` is the first name only: Peter is "Simon" (`displayTitle` "Simon Peter"), Pilate "Pontius", the patriarch Jacob "Israel" (`displayTitle` "Jacob (Israel)", 1,009 verses; a second "Jacob", Joseph's father, has 2). The shown name is `displayTitle` without a trailing "(…)"; 89 titles have one. By shown name, 457 are shared, by 1,697 people. What tells those apart: the title's own "(…)" for 85, a parent for 837, a child for 216, a partner for 6, and nothing but their verses for 553. The field `Disambiguation (temp)` is free text of every kind and is not used.
- **Also called.** 352 people have `alsoCalled`, comma-separated with no spaces. For Jesus and for God it is a machine-gathered list of titles ("Lord,Son,Lamb,…,Light,…,King,…", some twice in other capitals).
- **Years.** `birthYear` on 71 people, `deathYear` on 61, both on 46, either on 86; strings like "-1995" and "30". The count has a year zero: Adam's "-4003" is Ussher's 4004 BC. An event's `startDate` is "-4003", "9", "0030" or "0030-05-01"; no event is in year 0. `minYear` and `maxYear` (first and last mention) are on everyone and are not imported.
- **Family.** `father` and `mother` hold at most one; 8,924 links in all; David has 21 children and 8 partners.
- **Verses.** 28,269 person-to-verse links, 7,537 place-to-verse links, 18,659 event-to-verse links. An event's verses make 713 unbroken runs once split at book ends; 96 of those cross a chapter; 95 events have verses in more than one book. 27 of the 66 books have no event (Leviticus, Ruth, Psalms to Song of Solomon, Lamentations, every letter but Galatians and Hebrews, Revelation).
- **Easton.** Each of 1,814 people and 966 places is linked to exactly one item of Easton's, and `people.json` and `places.json` carry that item's text in their own `dictText` (a list of one string, identical to `easton.json`'s for every one). The text has markdown links, `[Matt. 1:21](/matt#Matt.1.21)`, and blank-line paragraph breaks (219 of them have more than one paragraph).
- **Writers.** Every book has one or more (77 in all): Moses for Job, Paul for Hebrews, six for Psalms.
- **Places.** 1,287 have a verse (ten have none and are left out). `precision` is "Rough" (348), "Related-Surrounding" (112), "Related-Within" (57), "Unlocated" (22), "Center" (2), "Precise" (2) or absent. 25 have no coordinates; one "Unlocated" place has some. So 26 are not on the map and 511 are approximate. `featureType` is City, Region, Mountain, Water, Valley, Landmark, Island or Path on 743; `featureSubType` (River, Gate, Country, Spring, Well, Garden, Cave, Tower) on 67.
- **Jerusalem.** Seventy places share one point, 31.777444, 35.234935. Jerusalem's own record is not there: it is 28 m away at 31.777189, 35.234978, with six others. Rounded to three decimal places (about 110 m) both are one point with 74 places that have a verse.
- **Checked on real books.** John names 39 people and 30 places and has 36 events; Acts 124 people and 101 places. Seven books name no place (Proverbs, 2 Thessalonians, Philemon, James, 1 to 3 John).
- **The front page today:** not measured here, since measuring needs a build. Task 6, Step 1 measures it and writes the figure on this line and in As built. **Today: 783 ms. Target: 100 ms.** (Task 6, Step 1, 2026-11-18: the sidebar and the shelf hosted at 1100 by 760 in a debug build, the median of nine opens; three runs alone gave 788.9, 783.1 and 782.9 ms.)

## Departures from the spec

Every bullet of 6.6 and 6.7 is built as written; the findings file has the two readings Matt is told of before the build (from search on the iPhone the way back returns to Search, where that page lives; "as it was" keeps the book, the view, the person or place, the open books and the opened reference, not the scroll offset or the map's zoom). The departures are elsewhere:

1. **Section 7 lists Easton among the tables fetched.** `easton.json` (6.2 MB) is not fetched: the two tables that are carry every linked entry's text themselves. Easton stays in the credit.
2. **Section 4.2 asks for a 260 pt pane with the shelf's grid.** The shelf's cells are 56 pt and five of them are 312 pt wide. The pane's cells are 40 by 32 with numerals at the page face's `.callout` size (the mockup drew 38 by 30); the iPhone's cells stay 56 by 40.
3. **Section 5 puts the dark ring at about L 0.65.** At 0.65 some hues fall to 2.98:1 on the Increase Contrast wash. The dark ring is at 0.68 (3.35:1 at worst); the light ring is at 0.55 as written (3.2:1 at worst).
4. **The mockups drew the ring as a circle and the place as a card over the map.** A circle inside a cell cannot clear a three-figure chapter (Psalm 119), so the ring is a rounded rectangle inset in the cell. Nothing floats over the map (it would need a surface and a shadow `DESIGN.md` does not have): the place's page sits under the map.

## Decided here

The spec's **(call)** items stand as written: the dot after a marked book; click chooses and double-click opens; search dims and never moves a book; the iPhone's group headers; rings in place of dots; what tells apart a shared name; the data's limits shown as they are; gathered pins that do not merge or split; "Traditionally attributed to"; no dictionary entry in About; the notice's wording and inline form. Section 10's items, and what else the spec leaves open:

- **The tables' shape and the fields kept:** the nine tables in Task 1, keyed by the data's integer ids and by `VerseKey`. Integer keys keep the link tables to a few hundred kilobytes and need no join to read a verse.
- **Columns:** as many as fit at a scaled 180 pt each (four in the default window); from four up the two Testaments sit side by side sharing them, the Old taking the odd one; under four each Testament has the full width; the Apocrypha is always a band of its own below. Within a Testament a column breaks only before a group; a group's name counts as one row and a book as one. The breaks chosen make the tallest column shortest; among those, the most even (the least sum of the heights squared); among those, the earliest. That gives the mockup's four columns exactly. The Apocrypha, one group, breaks between books.
- **The ring:** OKLab L 0.55 light, 0.68 dark, chroma as high as sRGB holds at that hue; segments are trimmed strokes of one rounded rectangle with butt caps, 0.03 of the path between them, the first starting at the top's middle.
- **Pins:** gathered by coordinates rounded to three decimal places; a pin sits at its most-mentioned place's coordinates and takes that place's name. **Framing:** the box of the pins that carry nine tenths of the book's located mentions, most-mentioned first, with a fifth of air on each side; never less than half a degree, which is also what one pin gets. A far place (Tarshish, India) is on the map but may start out of view.
- **The phone's layouts:** People is plain rows; a person, a place and About are each one scrolling page; Places is the map with its list in a sheet at the medium detent whose rows push the place's page inside the sheet. `DESIGN.md` section 7's sheets and rows are the precedent.
- **Two of one name with no parent recorded:** a child ("father of Joseph"), else a partner ("wife of Lamech"), else the first verse that names them ("1 Chronicles 9:12"). If two still read the same, each adds its first verse.
- **The Library's place in the navigation model:** `LibraryPlace` and `LibraryReturn`, Task 5. The history is not widened: a lookup already knows how to return, and one more thing to return to is a smaller change than a second kind of history entry.
- **Kinds:** `featureSubType` where the data has one, else `featureType`, in lower case ("river", "city"). **Approximate:** `precision` Rough, Related-Surrounding or Related-Within. **Not on the map:** no coordinates, or Unlocated.
- **Also called:** as given, less the name itself and repeats that differ only in capitals.
- **Verses:** neighbouring verses of a chapter are written as one reference ("John 1:29-34"). On a whole-Bible page every book's verses show when there are 40 references or fewer, else each book is a row to open.
- **An event's passage** in a book is its first unbroken run there; one that runs past its chapter is written as the part in its first chapter, as a cross-reference is. **Order:** the data's `sortKey`.
- **Search:** a person matches on the shown name, `name`, `surname` and "also called"; a place on its title, `kjvName`, `esvName` and `aliases`; from two characters, each typed word starting a word. People and Places come after Commands and before the reader's notes, so a command typed by name is still first and Return still runs it (Matt's answer in project 2). A person or place opened by name is not added to Recent.
- **⌘F** on the front page uses the catalogue's existing ⌘F row, relabelled "Search the front page or Notes", since a chord may be listed once.
- **A book with no events** shows no When and no Events; **a book with no place** shows "No places are named in Philemon."; typing in the toolbar's field while a Library view is open returns to the contents.
- **Model for each task and who must look** are on each task's **Run** line. Sonnet builds the ordinary tasks; Opus builds Tasks 5, 6, 8, 9 and 10.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-10-study-tools`, on branch `milestone-10-study-tools`. Never push or merge.
- Git: `/usr/bin/git`, one git command per Bash call, no `cd … &&`, loops or shell variables.
- Every commit message ends with the `Co-Authored-By:` attribution line your own session gives you (the model that wrote the commit), passed as a second `-m`.
- `rtk` shortens command output; use `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time. You do not dispatch subagents.

**Matt's data**
- Never touch the Release app, `Scripts/install-app.sh`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. Never build or run the Release configuration; read its settings with `-showBuildSettings` only.
- The `.dev` store gets no test notes. In the simulator never press 1 to 9, 0, N or B on a selection and never choose a colour, Add Note or Bookmark.
- A page style, appearance, text size, translation or the dates setting changed in the simulator to look at something is put back.
- No test touches iCloud, the Keychain, the network, the real clipboard or Matt's stores. The network is used only by the fetch scripts at build time and by Apple's map at run time. A test never makes a `Map` load tiles: test the models, not the map view.
- `Scripts/install-phone.sh debug` is run by the controller, never by a task's implementer.

**Matt is using this Mac (this comes before any step of a task)**
- You never quit, open or relaunch the Mac Debug app, and never send it a keystroke, click or scroll. Never move his windows. AeroSpace owns `alt-tab`, `alt-h/j/k/l`, `alt-1` to `alt-9` and `ctrl-left`/`ctrl-right`; ⌃Tab is the palette's.
- Where a step looks at the Mac's UI, render the view offscreen: an `NSHostingView` in a temporary test, written to a PNG in the scratchpad your dispatch names and opened with Read; remove the test before committing. Render inside a container taller than the content (a render sized to its content cannot show a list that fails to hug its rows). Where a view shows verse text or a mark, render poetry (Psalm 1) as well as prose.
- A headless render cannot show focus, the focus ring, a click, a double-click, a popover's anchor, a key, the toolbar's search field, or map tiles. Say in your report what the render could not show. The controller makes the live pass after your task, keys only, with the Debug app frontmost.
- The iPhone simulator ("iPhone 18 Pro Max") may be driven with the iOS Simulator control tool as a step says, at the default text size only. Never drive the simulator's app by hand at an accessibility text size or through the selection menu: for those, render the screen in a `TestWindow` (`window.layer.render(in:)`; `drawHierarchy` is blank there and system glass does not draw).
- If a focus or ring defect survives two blind rounds, stop and report; the controller reads the focus code and looks live before a third. `focusEffectDisabled` on an ancestor switches off every ring inside it.

**Commands**
- Package tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (add `--filter <Suite>` for one suite).
- iOS tests: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests` (append `/<Suite>` for one suite).
- Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
- iOS Debug build: the same with `-scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'`.
- The Bible database: `bash Scripts/ensure-bible.sh` rebuilds `Build/bible.sqlite` when `BibleSchema.version` changes. It runs `swift run -c release`, so it counts as a build.
- Run builds and test runs one after another; they share `Build/DerivedData`.
- Which suite a test file runs in: a file under `#if os(macOS)` runs in the package suite only, one under `#if os(iOS)` in the iOS suite only, any other `T` file in both. `TD`, `TM` and `TI` files run in the package suite only.
- The timing benchmarks in `ReaderBenchmarkTests` have each failed once under full-suite load and passed alone; rerun one alone before treating it as yours. The same goes for this project's.

**Code rules**
- TextKit 2 only; never touch `textView.layoutManager`.
- Swift Testing: `#expect` cannot contain a mutating call; mutate on the line before.
- A static func on a SwiftUI `View` is main-actor isolated; mark a pure helper `nonisolated`. SwiftUI's menus ignore a checkmark in a `Button`'s label; use a `Picker`.
- Deletes stay undoable through the window's `UndoManager`; the reader never asks for confirmation.
- The stored note format and the iCloud schema do not change. Two synced preferences are added, `showDates` and `datesNoticeAnswered`, and nothing else. Reading which colours a chapter holds is a read of the store; nothing is written.
- People and places are kept and passed by the data's ids, never by name.
- Fixtures use public-domain text (WEB, KJV) and the hand-made slice of Theographic's tables in Task 1, in their real shape.
- A new `.keyboardShortcut(` must be one `ShortcutCatalogTests` can read and its chord must be in the catalogue; a chord is listed once.
- Every `NSHostingController(rootView: ….followsSepia())` stays on one line (`SepiaModeTests` reads source lines).

**UI rules (CLAUDE.md, DESIGN.md)**
- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change; use the `/impeccable-swift` skill for the contents page, the Library's pages and the map.
- No fixed-point fonts in chrome: semantic text styles only; a size tied to text is `@ScaledMetric`.
- No inline colours: palette tokens only (`Color.inkSecondary`, `Color.accentWash`, `Palette.accent.platformColor`), never `Color(red:green:blue:)`, `.opacity()` on `.primary`, `.foregroundStyle(.secondary)` or a system colour. Every new pairing goes in `PaletteTests`. Spacing and radii are `AppSpacing` and `AppRadius` by name.
- No card by reflex: rows with rhythm, selection as the `accent.wash` tint at radius `md`, never a fill plus a hairline. No stat tiles, no card grids: a list is rows and the map is the system's map.
- No new shadow, no new material, no `.glassEffect()`. A popover is the system's, with no background of its own. A pushed page on the phone takes `.containerBackground(Color.paperPage, for: .navigation)`, never clear.
- Scripture speaks in the page face (book names on the contents page, verse text, the dictionary's entry in the Quote serif); the app speaks in SF Pro (group names, counts, names of people and places, labels).
- Colour never carries meaning alone: a marked chapter or book says "Marked" to VoiceOver.
- A date is never shown without its line saying whose dating it is; with the setting off no year appears anywhere.
- UI copy keeps the app's American spelling, whatever the spec's prose uses. A reference is written as `Reference.displayString` writes it.
- No motion that does not report a state change; Reduce Motion makes each a cut.

**Seeing the UI**
- Recipes: `docs/superpowers/specs/2026-11-13-milestone-9-handover.md`, "How to see the UI without stalling". None of them prompts; never block on a Screen Recording prompt.
- Pictures go in the scratchpad your dispatch names. A temporary snapshot test is removed before committing.
- Matt looks at the contents page, the map and a person's page in the live apps before the project is called done (Task 11).

## Review Focus

1. **A verse the translation being read lacks** (the CPDV's Psalms, a verse the ESV leaves out, a book the fixture has no text for). A clicked reference must say so and offer no Open; it must never do nothing. Task 7, `aReferenceTheTranslationLacksSaysSoAndOffersNoOpen`.
2. **The Library's place going stale**: the translation changed, during a lookup or on the front page, to one that lacks the Library's book. The view closes and a book the translation has is chosen; nothing traps. Task 5, `aTranslationWithoutTheLibrarysBookClosesItsView`.
3. **A name typed as one letter, as punctuation, or with `%` or `_`.** No row; never every person. Task 2, `namesAreFoundByTheStartOfAWordAndNothingElse`.
4. **A chapter whose highlight colour was deleted, or with more than six colours.** The first is a ring without a colour, never a gap or a trap; the second is the first six. Task 4, `aDeletedColourCountsAsNoColour` and `oneColourIsAWholeRingAndSeveralShareItEqually`.
5. **A book with no place, one place, or no event** (Philemon; Ecclesiastes; Psalms). The map frames one pin at half a degree; no place shows its one line; About leaves out When and Events and shows no notice. Task 2, `placesGatherAtOneSpotAndTheUnlocatedSitApart` and `aboutABookGivesItsFactsWritersAndEventsInOrder`.

---

### Task 1: The fetch script, the importer and schema 5 (spec 7; 11 Importer)

**Run:** Sonnet. No UI. Nobody needs to look; the controller reads Step 7's figures.

Two red-green cycles, one commit each: the tables and the importer against the fixture (A), then the real tables and the real database (B).

**Files:**
- Create: `Scripts/fetch-theographic.sh`, `IMP/TheographicTables.swift`, `TI/Fixtures/Theographic/` (`books.json`, `people.json`, `places.json`, `events.json`, `verses.json`, `commit`)
- Modify: `SD/BibleSchema.swift`, `IMP/BibleDatabaseWriter.swift`, `Packages/ScriptureKit/Sources/bible-importer/main.swift`, `Scripts/build-bible.sh`
- Test: create `TI/TheographicTablesTests.swift`; modify `TI/BibleDatabaseWriterTests.swift`, `TD/BibleStoreTests.swift` (package suite)

**Interfaces:**
- Consumes: `VerseKey`, `CrossReferenceFile.books`, `SearchQuery.tokens(in:)`, `Reference.displayString`, `ImportWarning`.
- Produces:

```swift
// BibleSchema: `version` is 5; `create` adds the tables below.
public enum TheographicTables {                                   // IMP
    public struct Person: Equatable, Sendable {
        public let id: Int, name: String, label: String?, alsoCalled: [String]
        public let birthYear: Int?, deathYear: Int?, searchNames: String, dictionary: String?
        public let verses: [Int]                                   // verse keys, ascending
    }
    public struct Relation: Equatable, Sendable { public let personID: Int, kind: String, ordinal: Int, relativeID: Int }
    public struct Place: Equatable, Sendable {
        public let id: Int, name: String, label: String?, alsoCalled: [String], kind: String?
        public let latitude: Double?, longitude: Double?, point: String?, isApproximate: Bool
        public let searchNames: String, dictionary: String?, verses: [Int]
    }
    public struct Event: Equatable, Sendable { public let id: Int, title: String, year: Int, sortKey: Double, passages: [ClosedRange<Int>] }
    public struct Writer: Equatable, Sendable { public let book: String, ordinal: Int, personID: Int }
    public struct Tables: Equatable, Sendable { public let people: [Person], relations: [Relation], places: [Place], events: [Event], writers: [Writer] }

    /// Reads the five tables in `folder`. A record that cannot be used is left out with a warning.
    public static func load(from folder: URL, warnings: inout [ImportWarning]) throws -> Tables
    static func year(_ text: String) -> Int?                                           // the leading whole number, signed
    static func shownName(_ displayTitle: String) -> (name: String, label: String?)    // a trailing "(…)" is the label
    static func plainText(_ markdown: String) -> String
    static func searchNames(_ names: [String]) -> String
    static func pointKey(latitude: Double, longitude: Double) -> String
    /// What tells apart those who share a shown name. `own` is the title's "(…)"; `relation` the first of parent, child, partner.
    static func labels(_ people: [(id: Int, name: String, own: String?, relation: String?, firstVerse: String)]) -> [Int: String]
}
// BibleDatabaseWriter.importAll gains `theographic: URL? = nil` (the folder); ImportReport gains `personCount`,
// `placeCount`, `eventCount`; ImportFailure gains `.noPeople(URL)`, thrown when the folder yields no person.
```

```sql
CREATE TABLE person (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL, label TEXT, also_called TEXT NOT NULL,
    birth_year INTEGER, death_year INTEGER, verse_count INTEGER NOT NULL, search_names TEXT NOT NULL, dictionary TEXT
);
CREATE TABLE person_verse (verse INTEGER NOT NULL, person_id INTEGER NOT NULL, PRIMARY KEY (verse, person_id)) WITHOUT ROWID;
CREATE INDEX person_verse_person ON person_verse(person_id, verse);
CREATE TABLE person_relation (
    person_id INTEGER NOT NULL, kind TEXT NOT NULL, ordinal INTEGER NOT NULL, relative_id INTEGER NOT NULL,
    PRIMARY KEY (person_id, kind, ordinal)
) WITHOUT ROWID;
CREATE TABLE place (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL, label TEXT, also_called TEXT NOT NULL, kind TEXT,
    latitude REAL, longitude REAL, point TEXT, approximate INTEGER NOT NULL,
    verse_count INTEGER NOT NULL, search_names TEXT NOT NULL, dictionary TEXT
);
CREATE INDEX place_point ON place(point);
CREATE TABLE place_verse (verse INTEGER NOT NULL, place_id INTEGER NOT NULL, PRIMARY KEY (verse, place_id)) WITHOUT ROWID;
CREATE INDEX place_verse_place ON place_verse(place_id, verse);
CREATE TABLE event (id INTEGER PRIMARY KEY, title TEXT NOT NULL, year INTEGER NOT NULL, sort_key REAL NOT NULL);
CREATE TABLE event_passage (start INTEGER NOT NULL, event_id INTEGER NOT NULL, end INTEGER NOT NULL, PRIMARY KEY (start, event_id)) WITHOUT ROWID;
CREATE TABLE book_writer (book_id TEXT NOT NULL, ordinal INTEGER NOT NULL, person_id INTEGER NOT NULL, PRIMARY KEY (book_id, ordinal)) WITHOUT ROWID;
```

**The importer's rules.**
- **Verses.** A record id maps to its `osisRef`, and that to a `VerseKey` through `CrossReferenceFile.books`. A link to a verse outside the table is dropped with a warning.
- **A person.** `id` is `personID`. `name` and the title's own label come from `shownName(displayTitle)`. `alsoCalled` is the field split on commas, trimmed, less any entry equal to the shown name or to `name` whatever its capitals, less later repeats that differ only in capitals. Years are `year(_:)`. `dictionary` is `plainText(dictText[0])`. `searchNames` is `searchNames([shown name, name, surname] + the alsoCalled field's entries as given)`.
- **`plainText`:** each `[label](target)` becomes `label`; the text is split on blank lines, each paragraph trimmed and its inner line breaks made spaces, empty ones dropped, joined by `"\n\n"`.
- **`searchNames`:** every `SearchQuery.tokens(in:)` word of every name, each once, in order, each led by a space (`" jacob israel"`).
- **A person's relation** (for `labels`): "son of X" or "daughter of X" by `gender`, X the father's shown name, else the mother's; else "father of X" or "mother of X" for the first child; else "husband of X" or "wife of X" for the first partner. `firstVerse` is the lowest verse key as `Reference.displayString` writes it.
- **`labels`:** a person with `own` keeps it. Among the others, only those whose shown name is shared get one: `relation`, else `firstVerse`. Then, among people of one shown name, a label more than one of them carries gains `", " + firstVerse`.
- **Relations.** Kinds `father`, `mother`, `partner`, `sibling`, `halfSibling` (same father, then same mother), `child`; `ordinal` is the place in the data's list.
- **Order.** `people` and `places` are in id order; `relations` by person id, then the kinds in the order just given, then `ordinal`; `events` by `sortKey`, then id.
- **A place.** `id` is `placeID`; one with no verse is left out. `name` and its own label come from `shownName(displayTitle)`; a place whose shown name is shared and has no label of its own takes its first verse. `alsoCalled` is `kjvName`, `esvName` and the comma-separated `aliases`, trimmed, less the name and repeats. `kind` is `featureSubType`, else `featureType`, in lower case. Coordinates are nil without both or when `precision` is "Unlocated"; `point` is `pointKey` of them (`String(format: "%.3f,%.3f")`). `isApproximate` is `precision` in Rough, Related-Surrounding, Related-Within. `searchNames` is of the title's shown name, `kjvName`, `esvName` and the aliases.
- **An event.** `id` is `eventID`, `year` is `year(startDate)` (an event without one is left out with a warning). `passages`: its verses in the table's order (`verseID`), cut into runs. Two verses are neighbours when they are next to each other in the table and are either in one chapter with verse numbers one apart, or in one book with the second being verse 1 of the next chapter. A run never crosses a book.
- **Writers.** Each `writers` entry is a `personLookup`; one that names nobody in the people table is left out with the warning "Skipped writer <lookup> of <osisName>: not among the people". Ordered by the book's canon order, then the list's.
- **The writer** inserts everything in one transaction before the `VACUUM`, with `verse_count` the number of the record's verses, and writes the meta row `theographic_commit` from the folder's `commit` file ("unknown" without one). The CLI takes `--theographic <folder>` and prints the three counts.
- **The script,** modelled on `fetch-crossrefs.sh`: `COMMIT=b9a84854369502d10cdc7086e58e2794dbfd6722`; the five files and their digests from "The data, measured"; each from `https://raw.githubusercontent.com/robertrouse/theographic-bible-metadata/${COMMIT}/json/<file>`, read through `head -c 134217728` into a temporary file and checked before it is moved. The cache is `~/Library/Caches/ReadingThroughScripture/theographic/<the commit's first 12>/` holding the five files, `commit` and `.complete`; it prints that folder, and is a no-op when complete with every digest right. A wrong digest stops it: "Theographic's <file> is not the pinned one; check it and re-pin fetch-theographic.sh". `build-bible.sh` runs it and passes `--theographic`.

**The fixture.** Hand-made, in the real shape (`[{"id": "rec…", "createdTime": "2020-01-01T00:00:00.000Z", "fields": {…}}]`; links are lists of record ids; a field with nothing is absent). `commit` holds `fixture`. Tasks 2 and 10 read it through the test stores.

`verses.json`: one record per verse named below, with `osisRef` and `verseID` ("40001001"): Matt 1:1, 1:2, 1:5, 1:6, 1:7, 1:15, 1:16, 1:18, 1:19, 1:20, 1:24, 2:1, 2:2, 2:3, 2:5, 2:6, 2:7, 2:8, 2:11, 2:13, 2:14, 2:15, 2:16, 2:18, 2:19, 2:23, 3:13, 4:1, 4:13, 4:25, 5:35, 6:29, 9:9, 10:3, 12:42, 14:1, 21:5, 24:15; Ps 2:6, 2:7, 18:50, 105:10, 105:17, 122:2; Gen 1:31, 2:1, 2:2; Luke 2:1; 1 Sam 1:19 (49 records).

`people.json` (13). `gender` is "Male" but for Mary.

| `personLookup` | `name` | `displayTitle` | other fields | `verses` |
|---|---|---|---|---|
| `jesus_905` | Jesus | Jesus Christ | `surname` Christ; `alsoCalled` "Lord,Son,JESUS,LORD"; `birthYear` "-3"; `deathYear` "30"; `mother` Mary; `dictText` `["The proper name of our Lord ([Matt. 1:21](/matt#Matt.1.21)).\n\nHe was born at\nBethlehem."]` | Ps 2:7; Matt 1:1, 1:16, 1:18, 2:1, 3:13, 4:1 |
| `israel_682` | Israel | Jacob (Israel) | `alsoCalled` "Israel"; `birthYear` "-1835"; `deathYear` "-1688"; `father` Isaac; `children` Joseph 1710 | Ps 105:10; Matt 1:2 |
| `jacob_683` | Jacob | Jacob | `children` Joseph 1715 | Matt 1:15, 1:16 |
| `joseph_1715` | Joseph | Joseph (Mary's Husband) | `father` Jacob 683; `partners` Mary | Matt 1:16, 1:18, 1:19, 1:20, 1:24, 2:13 |
| `joseph_1710` | Joseph | Joseph (son of Jacob) | `father` Israel 682 | Ps 105:17 |
| `mary_1938` | Mary | Mary (Mother of Jesus) | Female; `alsoCalled` "mother"; `partners` Joseph 1715; `children` Jesus | Matt 1:16, 1:18, 1:20, 2:11 |
| `david_994` | David | David | `birthYear` "-1084"; `deathYear` "-1014"; `father` Jesse; `children` Solomon | Ps 18:50; Matt 1:1, 1:6 |
| `solomon_2762` | Solomon | Solomon | `father` David | Matt 1:6, 1:7, 6:29 |
| `jesse_903` | Jesse | Jesse | `children` David | Matt 1:5, 1:6 |
| `isaac_616` | Isaac | Isaac | `children` Israel 682 | Matt 1:2 |
| `herod_1493` | Herod | Herod | | Matt 2:1, 2:3, 2:7 |
| `herod_1494` | Herod | Herod | | Matt 14:1 |
| `matthew_1971` | Matthew | Matthew | | Matt 9:9, 10:3 |

`places.json` (10).

| `placeLookup` | `displayTitle` | other fields | `verses` |
|---|---|---|---|
| `jerusalem_636` | Jerusalem | City; 31.777189, 35.234978; `precision` Precise; `aliases` "Zion, Jebus, Salem, City of God"; `dictText` `["Called also Salem ([Ps. 76:2](/ps#Ps.76.2))."]` | Ps 122:2; Matt 2:1, 2:3, 4:25, 5:35 |
| `zion_1263` | Zion | Mountain; 31.777444, 35.234935; Precise; `kjvName` Sion; `esvName` Zion | Ps 2:6; Matt 21:5 |
| `bethlehem_218` | Bethlehem | City; 31.705361, 35.210266 | Matt 2:1, 2:5, 2:6, 2:8, 2:16 |
| `egypt_362` | Egypt | Region, `featureSubType` Country; 26.696361, 30.246486 | Matt 2:13, 2:14, 2:15, 2:19 |
| `nazareth_882` | Nazareth | City; 32.706745, 35.301528 | Matt 2:23, 4:13 |
| `ramah_978` | Ramah | City; 31.896, 35.201; Rough | Matt 2:18 |
| `ramah_979` | Ramah | 32.936, 35.367; Related-Surrounding | 1 Sam 1:19 |
| `holy_place_574` | Holy place | no coordinates | Matt 24:15 |
| `south_1110` | South | 30.3, 34.2; Unlocated | Matt 12:42 |
| `jerusalems_637` | Jerusalem's | 31.777189, 35.234978; no `verses` | |

`events.json` (6): 1 "Creation of all things", `startDate` "-4003", `sortKey` -4002.99, Gen 1:31, 2:1, 2:2 · 300 "Birth of Jesus", "-4", -3.5, Matt 1:18, 1:19, 1:20, 1:24 and Luke 2:1 · 301 "Visit of the Magi", "-3", -2.9, Matt 2:1, 2:2, 2:3 · 302 "Escape to Egypt", "-3", -2.8, Matt 2:13, 2:14, 2:15 · 310 "Jesus Is Baptized", "26", 26.4, Matt 3:13 · 311 "Sermon on the Mount", "0028-06-01", 28.4, Matt 5:35.

`books.json` (3): Gen with `writers` `["moses_2108"]`, Ps with `["david_994", "solomon_2762"]`, Matt with `["matthew_1971"]`.

#### Cycle A: the tables and the importer

- [ ] **Step 1: Write the failing tests.** In `TI/TheographicTablesTests.swift`, `tables` loads the fixture folder and `byID` keys a list by `id`:

```swift
@Test func yearsNamesTextAndPointsReadAsTheTablesWriteThem() {
    #expect(TheographicTables.year("-1995") == -1995 && TheographicTables.year("0030-05-01") == 30 && TheographicTables.year("57") == 57)
    #expect(TheographicTables.year("") == nil && TheographicTables.year("about 30") == nil)
    #expect(TheographicTables.shownName("Jacob (Israel)") == ("Jacob", "Israel") && TheographicTables.shownName("John the Baptist") == ("John the Baptist", nil))
    #expect(TheographicTables.plainText("A ([Rev. 1:8](/rev#Rev.1.8), [11](/rev#Rev.1.11)).\n\n \n\nB [sic]\nc.") == "A (Rev. 1:8, 11).\n\nB [sic] c.")
    #expect(TheographicTables.searchNames(["Simon Peter", "Simon", "Cephas"]) == " simon peter cephas")
    #expect(TheographicTables.pointKey(latitude: 31.777189, longitude: 35.234978) == "31.777,35.235")
    #expect(TheographicTables.pointKey(latitude: 31.777444, longitude: 35.234935) == "31.777,35.235")      // the seventy and Jerusalem
}

@Test func twoOfOneNameAreToldApartEvenWhenTheirLabelsMatch() {
    let labels = TheographicTables.labels([
        (1, "Azariah", nil, "son of Johanan", "1 Chronicles 6:10"), (2, "Azariah", nil, "son of Johanan", "Ezra 7:3"),
        (3, "Azariah", nil, nil, "Nehemiah 3:23"), (4, "Esau", "Edom", nil, "Genesis 25:25"), (5, "Noah", nil, "son of Lamech", "Genesis 5:29")])
    #expect(labels == [1: "son of Johanan, 1 Chronicles 6:10", 2: "son of Johanan, Ezra 7:3", 3: "Nehemiah 3:23", 4: "Edom"])
}

@Test func theFixturePeopleLandByTheirOwnIds() throws {
    var warnings: [ImportWarning] = []
    let people = byID(try TheographicTables.load(from: fixture, warnings: &warnings).people)
    #expect(people.count == 13 && people[905]?.name == "Jesus Christ" && people[905]?.label == nil)
    #expect(people[905]?.alsoCalled == ["Lord", "Son"] && people[905]?.birthYear == -3 && people[905]?.deathYear == 30)
    #expect(people[905]?.dictionary == "The proper name of our Lord (Matt. 1:21).\n\nHe was born at Bethlehem.")
    #expect(people[905]?.verses == [19002007, 40001001, 40001016, 40001018, 40002001, 40003013, 40004001])
    #expect(people[905]?.searchNames == " jesus christ lord son" && people[682]?.searchNames == " jacob israel")
    #expect(people[682]?.name == "Jacob" && people[682]?.label == "Israel" && people[682]?.alsoCalled == [])
    #expect(people[683]?.label == "father of Joseph" && people[1715]?.label == "Mary's Husband" && people[1710]?.label == "son of Jacob")
    #expect(people[1493]?.label == "Matthew 2:1" && people[1494]?.label == "Matthew 14:1" && people[994]?.label == nil)
    #expect(warnings.map(\.message) == ["Skipped writer moses_2108 of Gen: not among the people"])
}

@Test func theFixturePlacesEventsFamiliesAndWriters() throws {
    var warnings: [ImportWarning] = []
    let tables = try TheographicTables.load(from: fixture, warnings: &warnings)
    let places = byID(tables.places), events = byID(tables.events)
    #expect(places.count == 9 && places[637] == nil)                                             // no verse: left out
    #expect(places[636]?.alsoCalled == ["Zion", "Jebus", "Salem", "City of God"] && places[636]?.kind == "city" && places[362]?.kind == "country")
    #expect(places[1263]?.alsoCalled == ["Sion"] && places[1263]?.point == places[636]?.point && places[979]?.kind == nil)
    #expect(places[978]?.isApproximate == true && places[979]?.isApproximate == true && places[882]?.isApproximate == false)
    #expect(places[978]?.label == "Matthew 2:18" && places[979]?.label == "1 Samuel 1:19" && places[636]?.label == nil)
    #expect(places[574]?.latitude == nil && places[1110]?.latitude == nil && places[1110]?.point == nil)   // none; Unlocated
    #expect(tables.events.map(\.id) == [1, 300, 301, 302, 310, 311] && events[1]?.year == -4003 && events[311]?.year == 28)
    #expect(events[1]?.passages == [1_001_031...1_002_002])                                      // one run past the chapter's end
    #expect(events[300]?.passages == [40_001_018...40_001_020, 40_001_024...40_001_024, 42_002_001...42_002_001])
    #expect(tables.relations.count == 14 && tables.relations.filter { $0.personID == 1715 }.map { "\($0.kind) \($0.relativeID)" } == ["father 683", "partner 1938"])
    #expect(tables.writers == [.init(book: "PSA", ordinal: 0, personID: 994), .init(book: "PSA", ordinal: 1, personID: 2762), .init(book: "MAT", ordinal: 0, personID: 1971)])
}
```

  In `TI/BibleDatabaseWriterTests.swift`, a test that imports the fixtures with the Theographic folder and reads inside `q.read { db in … }`:

```swift
@Test func theFixtureLibraryLandsAtSchemaFive() throws {
    #expect(report.personCount == 13 && report.placeCount == 9 && report.eventCount == 6)
    func count(_ table: String) throws -> Int? { try Int.fetchOne(db, sql: "SELECT count(*) FROM \(table)") }
    try #expect(count("person_verse") == 37 && count("place_verse") == 22 && count("event_passage") == 8)
    try #expect(count("person_relation") == 14 && count("book_writer") == 3)
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM person WHERE name = 'Jacob'") == 2)          // ids, not names, are the keys
    try #expect(Int.fetchOne(db, sql: "SELECT verse_count FROM person WHERE id = 905") == 7)
    try #expect(String.fetchOne(db, sql: "SELECT point FROM place WHERE id = 1263") == "31.777,35.235")
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM place WHERE latitude IS NULL") == 2)
    try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'schema_version'") == "5")
    try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'theographic_commit'") == "fixture")
}
```

  `importsFixturesIntoSQLite` (no folder given) also expects `person` empty. A folder whose `people.json` is `[]` throws `.noPeople`. In `TD/BibleStoreTests.swift`, `theBuildScriptsPatternReadsTheSchemaVersion` expects 5; `schemaMismatchThrows` (an older database is refused, so the build script rebuilds it) stays.

- [ ] **Step 2: Run.** `--filter TheographicTablesTests` and `--filter BibleDatabaseWriterTests` FAIL to compile.
- [ ] **Step 3: Implement** the schema, `TheographicTables`, the writer's parameter and the CLI's option.
- [ ] **Step 4: Run.** The package suite passes except the `.needsRealBible` tests, which wait for cycle B.
- [ ] **Step 5: Commit.** `/usr/bin/git add` the files, then `/usr/bin/git commit -m "feat: schema 5: people, places, events and families, imported from Theographic's tables (library 7)" -m "<the session's attribution line>"`. Every later commit step has this shape.

#### Cycle B: the real tables and the real database

- [ ] **Step 6: Write the script and wire `build-bible.sh`.** `bash Scripts/fetch-theographic.sh` prints the cache folder; `shasum -a 256` of each file there is its pinned digest. Run again, it prints the folder at once.
- [ ] **Step 7: Rebuild the database.** Note `wc -c Build/bible.sqlite`, then run `bash Scripts/ensure-bible.sh`: it rebuilds, since the file says 4 and the source 5. Then:
  - `sqlite3 Build/bible.sqlite "SELECT value FROM meta WHERE key IN ('schema_version', 'theographic_commit')"` prints `5` and the commit.
  - `sqlite3 Build/bible.sqlite "SELECT (SELECT count(*) FROM person), (SELECT count(*) FROM place), (SELECT count(*) FROM event), (SELECT count(*) FROM person_verse), (SELECT count(*) FROM place_verse), (SELECT count(*) FROM event_passage), (SELECT count(*) FROM person_relation), (SELECT count(*) FROM book_writer)"` prints `3067|1287|501|28269|7537|713|8924|77`.
  - `sqlite3 Build/bible.sqlite "SELECT count(*) FROM place WHERE point = '31.777,35.235'"` prints `74`; `"SELECT name, label FROM person WHERE id IN (682, 2745)"` prints `Jacob|Israel` and `Simon Peter|`.
  - `wc -c Build/bible.sqlite`: the spec expects 1 to 3 MB more. Keep both figures, and the importer's warning count, for As built. A count that differs from these is a finding: stop and report it.
- [ ] **Step 8: Run.** The whole package suite passes, the `.needsRealBible` tests among them; then the iOS suite.
- [ ] **Step 9: Commit.** `build: fetch the pinned Theographic tables and build them into the Bible database (library 7)`

---

### Task 2: Groups, the store's reads and the page models (spec 4.1 groups, 6.2 to 6.5, 6.6 search's read; 11)

**Run:** Sonnet. No UI. Nobody needs to look.

**Files:**
- Create: `SD/BookGroup.swift`, `SD/LibraryRecords.swift`, `SD/BibleStore+Library.swift`, `LIB/LibraryYear.swift`, `LIB/VerseRuns.swift`, `LIB/BookPeople.swift`, `LIB/PersonPage.swift`, `LIB/BookPlaces.swift`, `LIB/PlacePage.swift`, `LIB/BookAbout.swift`; copy `TI/Fixtures/Theographic` to `TD/Fixtures/Theographic` and `T/Fixtures/Theographic`
- Modify: `TD/FixtureDatabase.swift` and `T/FixtureStore.swift` (both pass `theographic:`), `SUI/NavigationModel.swift` (beside `versePreview`, `:59-79`)
- Test: create `TD/BookGroupTests.swift`, `TD/BibleStoreLibraryTests.swift` (package suite), `T/LibraryPagesTests.swift` (both suites)

**Interfaces:**
- Consumes: Task 1's tables.
- Produces:

```swift
public enum BookGroup: String, CaseIterable, Sendable {             // SD
    case law, history, poetryAndWisdom, majorProphets, minorProphets, gospelsAndActs, paulsLetters, generalLetters, revelation, apocrypha
    public var title: String    // "Law", "History", "Poetry & Wisdom", "Major Prophets", "Minor Prophets", "Gospels & Acts", "Paul’s Letters", "General Letters", "Revelation", "Apocrypha"
    public var canon: Canon
    public static func group(of book: Book) -> BookGroup            // spec 4.1's ranges; any Apocrypha book is `.apocrypha`
}
public struct PersonSummary: Hashable, Identifiable, Sendable { public let id: Int, name: String, label: String?, verseCount: Int }
public struct PersonRecord: Equatable, Sendable {
    public let id: Int, name: String, label: String?, alsoCalled: [String], birthYear: Int?, deathYear: Int?, verseCount: Int, dictionary: String?
}
public enum Relation: String, CaseIterable, Sendable { case father, mother, partner, sibling, halfSibling, child }
public struct Relative: Hashable, Sendable { public let kind: Relation, person: PersonSummary }
public struct PlaceSummary: Hashable, Identifiable, Sendable {
    public let id: Int, name: String, label: String?, kind: String?
    public let latitude: Double?, longitude: Double?, point: String?, isApproximate: Bool, verseCount: Int
}
public struct PlaceRecord: Equatable, Sendable { public let summary: PlaceSummary, alsoCalled: [String], dictionary: String? }
public struct BookEvent: Hashable, Identifiable, Sendable { public let id: Int, title: String, year: Int, start: VerseLocation, end: VerseLocation }
public struct NameMatches<Row: Equatable & Sendable>: Equatable, Sendable {
    public let rows: [Row], total: Int
    public static var none: NameMatches { get }
}
extension BibleStore {
    // In a book: `verseCount` counts the book's verses. Most verses first, then name, then id. Empty outside the 66.
    public func people(inBook book: String) throws -> [PersonSummary]
    public func placesNamed(inBook book: String) throws -> [PlaceSummary]
    public func events(inBook book: String) throws -> [BookEvent]       // each with its first passage in the book; by sort_key, then id
    public func writers(ofBook book: String) throws -> [PersonSummary]  // whole-Bible counts, as every call below
    public func person(_ id: Int) throws -> PersonRecord?
    public func relatives(of id: Int) throws -> [Relative]              // `Relation.allCases` order, then the data's
    public func place(_ id: Int) throws -> PlaceRecord?
    public func places(sharingPointWith id: Int, inBook book: String?) throws -> [PlaceSummary]   // the others at its point
    public func verses(ofPerson id: Int) throws -> [VerseLocation]      // canon order
    public func verses(ofPlace id: Int) throws -> [VerseLocation]
    public func verseCount(ofBook book: String, translationID: String) throws -> Int   // a joined verse counts every verse it holds
    public func searchPeople(_ text: String, limit: Int) throws -> NameMatches<PersonSummary>
    public func searchPlaces(_ text: String, limit: Int) throws -> NameMatches<PlaceSummary>
}

public enum LibraryYear {                                            // LIB, as everything below
    public static func text(_ year: Int) -> String
    public static func life(birth: Int?, death: Int?) -> String?
    public static func span(_ years: [Int]) -> String?
}
public enum VerseRuns { public static func references(_ verses: [VerseLocation]) -> [Reference] }
public struct VerseGroup: Identifiable, Equatable, Sendable { public let book: Book, count: Int, references: [Reference]; public var id: String { get } }

public struct BookPeople: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public let person: PersonSummary
        public let label: String?                                    // only when another row has its name
        public var id: Int { get }
        public var accessibilityLabel: String { get }                // "Jacob, father of Joseph, 2 verses"
    }
    public let book: Book, rows: [Row]
    public var title: String { get }                                 // "People in John"
    public var countLabel: String { get }                            // "39 named · by mentions"
    public static func load(book: String, store: BibleStore) throws -> BookPeople?      // nil outside the 66
}
public struct PersonPage: Equatable, Sendable {
    public let person: PersonRecord
    public let parents: [PersonSummary], partners: [PersonSummary], siblings: [PersonSummary], children: [PersonSummary]
    public let here: VerseGroup?                                     // the book's own verses; nil for the whole Bible, or when it has none
    public let elsewhere: [VerseGroup]                               // every other book in canon order; the whole Bible: every book
    public var alsoCalledLine: String? { get }                       // "also called Cephas, Simeon"
    public var hasDate: Bool { get }
    public func life(showingDates: Bool) -> String?
    public static let opensEveryBookUpTo = 40                        // references on the page
    public var opensEveryBook: Bool { get }
    public static func load(_ id: Int, inBook book: String?, store: BibleStore) throws -> PersonPage?
}
public struct BookPlaces: Equatable, Sendable {
    public struct Pin: Identifiable, Equatable, Sendable {
        public let id: String                                        // the point
        public let latitude: Double, longitude: Double, places: [PlaceSummary], title: String, mentions: Int
    }
    public struct Frame: Equatable, Sendable { public let latitude: Double, longitude: Double, latitudeSpan: Double, longitudeSpan: Double }
    public let book: Book, onMap: [PlaceSummary], notOnMap: [PlaceSummary], pins: [Pin]   // pins: most mentions first, then title
    public var title: String { get }                                 // "Places in Matthew"
    public var countLabel: String { get }                            // "8 places · 6 on the map"; "1 place · 1 on the map"
    public var frame: Frame? { get }
    public func pin(holding placeID: Int) -> Pin?
    public static func frame(_ pins: [Pin]) -> Frame?
    public static func load(book: String, store: BibleStore) throws -> BookPlaces?
}
public struct PlacePage: Equatable, Sendable {
    public let place: PlaceRecord, sameSpot: [PlaceSummary], here: VerseGroup?, elsewhere: [VerseGroup]
    public var kindLine: String? { get }                             // "city · approximate", "approximate", "city"
    public var alsoCalledLine: String? { get }
    public var isOnMap: Bool { get }
    public var pin: BookPlaces.Pin? { get }                          // itself alone, for the whole-Bible page's map
    public static func load(_ id: Int, inBook book: String?, store: BibleStore) throws -> PlacePage?
}
public struct BookAbout: Equatable, Sendable {
    public struct Event: Identifiable, Equatable, Sendable {
        public let id: Int, title: String, year: Int, passage: Reference
        public func yearText(showingDates: Bool) -> String?
    }
    public let book: Book, placeLine: String, lengthLine: String, peopleAndPlacesLine: String
    public let writers: [PersonSummary], events: [Event]
    public var hasDate: Bool { get }
    public func span(showingDates: Bool) -> String?
    public static func load(book: String, translationID: String, store: BibleStore) throws -> BookAbout?
}
// NavigationModel, each with its own store and translation; nil when the read fails or there is nothing
public func hasLibraryData(for book: String) -> Bool                 // one of the 66
public func bookSubtitle(_ book: String) -> String?                  // `store.bookTitle`'s subtitle
public func bookPeople(_ book: String) -> BookPeople?
public func personPage(_ id: Int, inBook book: String?) -> PersonPage?
public func bookPlaces(_ book: String) -> BookPlaces?
public func placePage(_ id: Int, inBook book: String?) -> PlacePage?
public func bookAbout(_ book: String) -> BookAbout?
```

**Rules.**
- **In a book** is `verse BETWEEN order × 1,000,000 AND order × 1,000,000 + 999,999`.
- **Search:** the typed text's `SearchQuery.tokens(in:)` words; fewer than two characters in all finds nothing; each word must satisfy `search_names LIKE '% ' || word || '%'`; most verses first, then name, then id; `total` counts every match.
- **`LibraryYear.text`:** a year above 0 is "about AD n"; otherwise "about (1 − n) BC". `life`: "A to B", "born A", "died B". `span`: the least to the greatest, one year as its text.
- **`BookPeople.Row.label`** is the person's label only when another row of the list has the same name.
- **A person's page.** Siblings are `sibling` then `halfSibling`. With dates off `life` is nil. `hasDate` is whether it has either year. `opensEveryBook` is whether the page's references number `opensEveryBookUpTo` or fewer.
- **Pins and the frame** are as "Decided here" has them: a span under half a degree becomes half a degree, each way.
- **About.** `placeLine` is "New Testament · Gospels & Acts". `lengthLine` is "21 chapters · 879 verses" in the translation given, numbers through `formatted()`. `peopleAndPlacesLine` is "39 people · 30 places", each word singular for one. An event's `passage` is its first run in the book; a run past its chapter is written to that chapter's last verse in the translation, and as its first verse alone when the translation lacks the chapter. `span` is over the events' years.

- [ ] **Step 1: Write the failing tests.** `TD/BookGroupTests.swift`:

```swift
@Test func everyBookIsInExactlyOneGroupInCanonOrder() {
    let sixtySix = BookCatalog.all.filter { $0.canon != .apocrypha }
    #expect(sixtySix.count == 66 && sixtySix.allSatisfy { BookGroup.group(of: $0) != .apocrypha && BookGroup.group(of: $0).canon == $0.canon })
    var seen: [BookGroup] = []
    for book in sixtySix where seen.last != BookGroup.group(of: book) { seen.append(BookGroup.group(of: book)) }
    #expect(seen == Array(BookGroup.allCases.dropLast()))                       // each group is one unbroken run
    #expect(sixtySix.count { BookGroup.group(of: $0) == .history } == 12 && sixtySix.count { BookGroup.group(of: $0) == .paulsLetters } == 13)
    #expect(BookGroup.group(of: BookCatalog.book(code: "ACT")!) == .gospelsAndActs && BookGroup.group(of: BookCatalog.book(code: "HEB")!) == .generalLetters)
    #expect(BookCatalog.all.filter { $0.canon == .apocrypha }.allSatisfy { BookGroup.group(of: $0) == .apocrypha })
    #expect(BookGroup.paulsLetters.title == "Paul’s Letters" && BookGroup.poetryAndWisdom.title == "Poetry & Wisdom")
}
```

  `TD/BibleStoreLibraryTests.swift` (`store` as `BibleStoreVersesTests` has it; `mt(_:_:)` makes a Matthew `VerseLocation`):

```swift
@Test func aBooksPeopleComeMostVersesFirstWithTheirCounts() throws {
    let people = try store.people(inBook: "MAT")
    #expect(people.map(\.id) == [905, 1715, 1938, 1493, 2762, 994, 683, 903, 1971, 1494, 616, 682])
    #expect(people.map(\.verseCount) == [6, 6, 4, 3, 3, 2, 2, 2, 2, 1, 1, 1])
    #expect(try store.people(inBook: "PSA").map(\.id) == [994, 682, 905, 1710] && store.people(inBook: "TOB").isEmpty)
    #expect(try store.person(905)?.verseCount == 7 && store.person(99) == nil)
}

@Test func aPersonsFamilyVersesAndABooksWritersReadByTheirIds() throws {
    func family(_ id: Int) throws -> [String] { try store.relatives(of: id).map { "\($0.kind.rawValue) \($0.person.id)" } }
    #expect(try family(1715) == ["father 683", "partner 1938"] && family(682) == ["father 616", "child 1710"] && family(1493).isEmpty)
    #expect(try store.verses(ofPerson: 994) == [VerseLocation(book: "PSA", chapter: 18, verse: 50), mt(1, 1), mt(1, 6)])
    #expect(try store.writers(ofBook: "PSA").map(\.id) == [994, 2762] && store.writers(ofBook: "GEN").isEmpty)
    #expect(try FixtureDatabase.tinyStore([("ERV", 11, nil), ("ERV", 12, 13)]).verseCount(ofBook: "JHN", translationID: "ERV") == 3)
}

@Test func placesAndEventsReadForABook() throws {
    let places = try store.placesNamed(inBook: "MAT")
    #expect(places.map(\.id) == [218, 362, 636, 882, 574, 978, 1110, 1263] && places.map(\.verseCount) == [5, 4, 4, 2, 1, 1, 1, 1])
    #expect(try store.places(sharingPointWith: 636, inBook: "MAT").map(\.id) == [1263] && store.places(sharingPointWith: 218, inBook: nil).isEmpty)
    #expect(try store.places(sharingPointWith: 574, inBook: nil).isEmpty)                    // no point: shares none
    let events = try store.events(inBook: "MAT")
    #expect(events.map(\.id) == [300, 301, 302, 310, 311] && events.map(\.year) == [-4, -3, -3, 26, 28])
    #expect(events[0].start == mt(1, 18) && events[0].end == mt(1, 20))                      // its first passage in the book
    #expect(try store.events(inBook: "GEN").first?.end == VerseLocation(book: "GEN", chapter: 2, verse: 2) && store.events(inBook: "PSA").isEmpty)
}

@Test func namesAreFoundByTheStartOfAWordAndNothingElse() throws {
    #expect(try store.searchPeople("jac", limit: 4).rows.map(\.id) == [682, 683] && store.searchPeople("isr", limit: 4).rows.map(\.id) == [682])
    #expect(try store.searchPeople("LORD", limit: 4).rows.map(\.id) == [905] && store.searchPeople("jesus chr", limit: 4).rows.map(\.id) == [905])
    let joseph = try store.searchPeople("jos", limit: 1)
    #expect(joseph.rows.map(\.id) == [1715] && joseph.total == 2)
    #expect(try store.searchPeople("sus", limit: 4).total == 0)                              // not from inside a word
    for nothing in ["j", "%", "_", "  ", "'"] { #expect(try store.searchPeople(nothing, limit: 4) == .none) }
    #expect(try store.searchPlaces("sal", limit: 4).rows.map(\.id) == [636] && store.searchPlaces("sion", limit: 4).rows.map(\.id) == [1263])
    #expect(try store.searchPlaces("ram", limit: 4).rows.map(\.label) == ["Matthew 2:18", "1 Samuel 1:19"])
}
```

  `T/LibraryPagesTests.swift` (`store` is `FixtureStore.make()`):

```swift
@Test func yearsReadAsTheSpecWritesThem() {
    #expect(LibraryYear.text(-1995) == "about 1996 BC" && LibraryYear.text(30) == "about AD 30" && LibraryYear.text(0) == "about 1 BC" && LibraryYear.text(1) == "about AD 1")
    #expect(LibraryYear.life(birth: -1995, death: -1820) == "about 1996 BC to about 1821 BC")
    #expect(LibraryYear.life(birth: -3, death: nil) == "born about 4 BC" && LibraryYear.life(birth: nil, death: -1055) == "died about 1056 BC")
    #expect(LibraryYear.life(birth: nil, death: nil) == nil && LibraryYear.span([]) == nil && LibraryYear.span([28]) == "about AD 28")
    #expect(LibraryYear.span([26, -4, -3]) == "about 5 BC to about AD 26")
}

@Test func neighbouringVersesJoinIntoOneReference() {
    let references = VerseRuns.references([mt(1, 18), mt(1, 19), mt(1, 20), mt(1, 24), mt(2, 1)]).map(\.displayString)
    #expect(references == ["Matthew 1:18-20", "Matthew 1:24", "Matthew 2:1"])
}

@Test func aSharedNameInTheListIsToldApartAndOnlyThere() throws {
    let people = try #require(try BookPeople.load(book: "MAT", store: store))
    #expect(people.title == "People in Matthew" && people.countLabel == "12 named · by mentions")
    #expect(people.rows.filter { $0.label != nil }.map { "\($0.person.name), \($0.label!)" }
            == ["Herod, Matthew 2:1", "Jacob, father of Joseph", "Herod, Matthew 14:1", "Jacob, Israel"])   // Joseph has a label but is alone here
    #expect(people.rows[6].accessibilityLabel == "Jacob, father of Joseph, 2 verses" && people.rows[0].accessibilityLabel == "Jesus Christ, 6 verses")
    #expect(try BookPeople.load(book: "TOB", store: store) == nil)
}

@Test func aPersonsPageHasFamilyByGenerationAndVersesHereAndElsewhere() throws {
    let david = try #require(try PersonPage.load(994, inBook: "MAT", store: store))
    #expect(david.parents.map(\.name) == ["Jesse"] && david.children.map(\.name) == ["Solomon"] && david.partners.isEmpty && david.siblings.isEmpty)
    #expect(david.here?.references.map(\.displayString) == ["Matthew 1:1", "Matthew 1:6"] && david.here?.count == 2)
    #expect(david.elsewhere.map { "\($0.book.id) \($0.count)" } == ["PSA 1"] && david.opensEveryBook)
    #expect(david.life(showingDates: true) == "about 1085 BC to about 1015 BC" && david.life(showingDates: false) == nil && david.hasDate)
    let whole = try #require(try PersonPage.load(994, inBook: nil, store: store))
    #expect(whole.here == nil && whole.elsewhere.map(\.book.id) == ["PSA", "MAT"])              // by book, in canon order
    let joseph = try #require(try PersonPage.load(1715, inBook: "MAT", store: store))
    #expect(joseph.parents.map(\.id) == [683] && joseph.partners.map(\.id) == [1938] && !joseph.hasDate && joseph.alsoCalledLine == nil)
    let jesus = try #require(try PersonPage.load(905, inBook: "PSA", store: store))
    #expect(jesus.alsoCalledLine == "also called Lord, Son" && jesus.life(showingDates: true) == "about 4 BC to about AD 30")
    #expect(try PersonPage.load(1494, inBook: "PSA", store: store)?.here == nil && PersonPage.load(99, inBook: nil, store: store) == nil)
}

@Test func placesGatherAtOneSpotAndTheUnlocatedSitApart() throws {
    let places = try #require(try BookPlaces.load(book: "MAT", store: store))
    #expect(places.countLabel == "8 places · 6 on the map" && places.notOnMap.map(\.name) == ["Holy place", "South"])
    #expect(places.pins.map(\.title) == ["Bethlehem", "Jerusalem", "Egypt", "Nazareth", "Ramah"] && places.pins.map(\.mentions) == [5, 5, 4, 2, 1])
    let jerusalem = try #require(places.pin(holding: 1263))
    #expect(jerusalem.places.map(\.name) == ["Jerusalem", "Zion"] && jerusalem.id == "31.777,35.235" && jerusalem.latitude == 31.777189)
    // The first four pins carry nine tenths of the 17 mentions: the frame is theirs, a fifth of air each side.
    let frame = try #require(places.frame)
    #expect(abs(frame.latitudeSpan - (32.706745 - 26.696361) * 1.4) < 0.001 && abs(frame.latitude - (32.706745 + 26.696361) / 2) < 0.001)
    let one = BookPlaces.frame([places.pins[0]])
    #expect(one?.latitudeSpan == 0.5 && one?.longitudeSpan == 0.5 && one?.latitude == 31.705361 && BookPlaces.frame([]) == nil)
    let psalms = try #require(try BookPlaces.load(book: "PSA", store: store))                   // two places, one spot
    #expect(psalms.pins.count == 1 && psalms.frame?.latitudeSpan == 0.5 && psalms.countLabel == "2 places · 2 on the map")
    let ramah = try #require(try PlacePage.load(978, inBook: "MAT", store: store))
    #expect(ramah.kindLine == "city · approximate" && ramah.isOnMap && ramah.here?.references.map(\.displayString) == ["Matthew 2:18"])
    let holy = try #require(try PlacePage.load(574, inBook: nil, store: store))
    #expect(holy.kindLine == nil && !holy.isOnMap && holy.pin == nil)
    let city = try #require(try PlacePage.load(636, inBook: "MAT", store: store))
    #expect(city.sameSpot.map(\.name) == ["Zion"] && city.alsoCalledLine == "also called Zion, Jebus, Salem, City of God" && city.kindLine == "city")
    #expect(try BookPlaces.load(book: "GEN", store: store)?.pins.isEmpty == true)                // a book that names no place
}

@Test func aboutABookGivesItsFactsWritersAndEventsInOrder() throws {
    let about = try #require(try BookAbout.load(book: "MAT", translationID: "WEB", store: store))
    #expect(about.placeLine == "New Testament · Gospels & Acts" && about.peopleAndPlacesLine == "12 people · 8 places")
    #expect(about.lengthLine == "6 chapters · \(try store.verseCount(ofBook: "MAT", translationID: "WEB")) verses")
    #expect(about.writers.map(\.name) == ["Matthew"] && about.events.map(\.id) == [300, 301, 302, 310, 311])
    #expect(about.events[0].passage.displayString == "Matthew 1:18-20" && about.events[4].yearText(showingDates: true) == "about AD 28")
    #expect(about.span(showingDates: true) == "about 5 BC to about AD 28" && about.hasDate)
    #expect(about.span(showingDates: false) == nil && about.events.allSatisfy { $0.yearText(showingDates: false) == nil })   // off removes every year
    let psalms = try #require(try BookAbout.load(book: "PSA", translationID: "KJV", store: store))
    #expect(psalms.events.isEmpty && psalms.span(showingDates: true) == nil && !psalms.hasDate && psalms.writers.map(\.name) == ["David", "Solomon"])
    #expect(try BookAbout.load(book: "TOB", translationID: "WEB", store: store) == nil)
}
```

  In `T/CrossReferenceBenchmarkTests.swift`'s shape, a new `T/LibraryBenchmarkTests.swift` (`#if os(macOS)`, `.needsRealBible`): John names 39 people and 30 places and has 36 events; `searchPeople("peter", limit: 4).rows.map(\.name) == ["Simon Peter"]`; the whole-Bible page of person 1324 (God, 8,587 verses) loads with a median under 50 ms (`ReaderBenchmarkTests.median`).

- [ ] **Step 2: Run.** The four filters FAIL to compile.
- [ ] **Step 3: Implement** the group, the records, the store's reads, the models and the navigation model's accessors.
- [ ] **Step 4: Run.** Both suites pass. Record the benchmark's median for As built.
- [ ] **Step 5: Commit.** `feat: the Library's reads and page models: people, places, events, years (library 6.2-6.5)`

---

### Task 3: Dates, the notice and the credit (spec 6.5, 7 Credit)

**Run:** Sonnet. A headless render of the notice and the credit line, light, dark and Sepia. The controller looks at Settings › General live once (keys only).

**Files:**
- Create: `LIB/LibraryDates.swift`, `LIB/DatesNotice.swift`, `LIB/LibraryCredit.swift`
- Modify: `SUI/PreferenceSync.swift` (`SyncedPreferences.keys`, `:75-93`, and its comment), `SUI/GeneralSettingsView.swift`, `SUI/Credits.swift`, `SUI/AboutView.swift` only if a new section needs it, `PH/PhoneShellModel.swift` (`SettingsDestination`, `:22-25`), `PH/PhoneSettingsScreen.swift` (`Page.init`, `:28-33`), `README.md` (Acknowledgements)
- Test: create `T/LibraryDatesTests.swift`; modify `T/PreferenceSyncTests.swift`, `T/CreditsTests.swift` (both suites)

**Interfaces:**
- Consumes: nothing.
- Produces:

```swift
public enum LibraryDates {
    public static let showKey = "showDates"                          // absent: on
    public static let noticeAnsweredKey = "datesNoticeAnswered"
    public static let notice = "Dates follow a traditional chronology (Ussher’s, as worked out by Floyd Nolen Jones), which puts Creation at 4004 BC. You can turn dates off in Settings."
    public static let footnote = "Dates follow a traditional chronology."
    public static func shows(_ defaults: UserDefaults) -> Bool
    public static func showsNotice(_ defaults: UserDefaults, viewHasDate: Bool) -> Bool      // on, unanswered, and the view has a date
    public static func answer(_ defaults: UserDefaults)
    public static func setShows(_ on: Bool, in defaults: UserDefaults)                       // off also answers the notice
}
/// The notice at the head of a view that shows a date for the first time, and afterwards the one line under the dates.
public struct DatesNotice: View { public init(onOpenSettings: @escaping () -> Void) }       // Settings and OK both answer it
public struct DatesFootnote: View { public init(onOpenSettings: @escaping () -> Void) }
public enum LibraryCredit {
    public static let text = "People, places and events from Theographic Bible Metadata by Robert Rouse (viz.bible), CC BY-SA 4.0, changed: converted to this app's tables. It includes data from STEPBible (CC BY 4.0), OpenBible.info (CC BY 4.0) and Easton's Bible Dictionary (1897)."
    public static var linked: AttributedString { get }               // `text` with its links
}
public struct LibraryCreditLine: View { public init() }              // `.caption`, `ink.secondary`, links in the accent
// SettingsDestination gains `.general`; PhoneShellModel gains `openGeneralSettings()`.
// Credit.Section gains `library = "People, places and events"` after `crossReferences`.
```

- **The setting** is its own section in Settings › General on both apps, after "Compare with": header "Library", `Toggle("Show dates", …)` through `LibraryDates.setShows`, footer "Years for people and events follow a traditional chronology (Ussher’s, as worked out by Floyd Nolen Jones), which puts Creation at 4004 BC."
- **The notice** is a row on `paper.overlay` at radius `md`, `sm` padding, no stroke: the text in `.callout` `ink.primary`, then **Settings** and **OK** as plain buttons in `accent`, `.callout` semibold. Not an alert. **The footnote** is the line in `.caption` `ink.secondary` as a plain button.
- **The links:** "Theographic Bible Metadata" to `https://github.com/robertrouse/theographic-bible-metadata`, "viz.bible" to `https://viz.bible`, "CC BY-SA 4.0" to `https://creativecommons.org/licenses/by-sa/4.0/`, "STEPBible" to `https://github.com/STEPBible/STEPBible-Data`, "OpenBible.info" to `https://www.openbible.info/geo/`, each "CC BY 4.0" to `https://creativecommons.org/licenses/by/4.0/`.
- **In `Credits.all`** after `openbible`: id `theographic`, section `.library`, name "Theographic Bible Metadata", use "People, places, events and dictionary entries", notice `LibraryCredit.text`, license "CC BY-SA 4.0", link `github.com/robertrouse/theographic-bible-metadata`, `licenseLink` the CC BY-SA page. README's Acknowledgements gains its line (`theReadmeAcknowledgesEverySource` requires it).
- **Pairings:** `accent` and `ink.primary` on `paper.overlay` are held already (`T/PaletteTests.swift:64`, `:82`); add `ink.secondary` on `paper.overlay` at 4.5:1 only if the notice uses it.

- [ ] **Step 1: Write the failing tests.** `defaults` is a scratch suite, emptied, as `CompareSetTests` makes one.

```swift
@Test func datesAreOnUntilTurnedOffAndTheNoticeShowsOnce() {
    #expect(LibraryDates.shows(defaults) && LibraryDates.showsNotice(defaults, viewHasDate: true) && !LibraryDates.showsNotice(defaults, viewHasDate: false))
    LibraryDates.answer(defaults)
    #expect(LibraryDates.shows(defaults) && !LibraryDates.showsNotice(defaults, viewHasDate: true) && defaults.bool(forKey: "datesNoticeAnswered"))
}

@Test func turningDatesOffAnswersTheNoticeAndTurningThemOnDoesNotAskAgain() {
    LibraryDates.setShows(false, in: defaults)
    #expect(!LibraryDates.shows(defaults) && defaults.bool(forKey: "datesNoticeAnswered") && !LibraryDates.showsNotice(defaults, viewHasDate: true))
    LibraryDates.setShows(true, in: defaults)
    #expect(LibraryDates.shows(defaults) && !LibraryDates.showsNotice(defaults, viewHasDate: true))
    #expect(LibraryDates.notice.hasSuffix("You can turn dates off in Settings.") && LibraryDates.footnote == "Dates follow a traditional chronology.")
}
```

  In `PreferenceSyncTests.theSyncedKeysAreExactlyThese` (`:14-19`) add `"datesNoticeAnswered"` (after `"compatibleModel"`) and `"showDates"` (after `"readingPosition.translationID"`), and a test in the suite's own style: a cloud holding `["showDates": false, "datesNoticeAnswered": true]` leaves a new device with dates off and no notice after `start()`. In `CreditsTests.theCatalogueIsTheAppendixAndClaimsNoPermission` (`:33-35`): 17 entries, "People, places and events" fourth of the eight sections, and

```swift
let theographic = try #require(Credits.all.first { $0.id == "theographic" })
#expect(theographic.notice == LibraryCredit.text && theographic.notice.hasPrefix("People, places and events from Theographic Bible Metadata by Robert Rouse (viz.bible), CC BY-SA 4.0, changed:"))
#expect(theographic.licenseLink?.absoluteString == "https://creativecommons.org/licenses/by-sa/4.0/" && String(LibraryCredit.linked.characters) == LibraryCredit.text)
#expect(LibraryCredit.linked.runs.compactMap(\.link).count == 7)
```

- [ ] **Step 2: Run.** `--filter LibraryDatesTests` FAILS to compile; the other two fail on their lists.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Both suites pass.
- [ ] **Step 5: See it.** Render `DatesNotice`, `DatesFootnote` and `LibraryCreditLine` at 420 pt wide inside a taller container, in light, dark and Sepia and at the largest standard text size; open each picture: the buttons do not clip and the credit wraps as a paragraph. Render the General settings form once. Say what could not be seen (the toggle live, the links' clicks).
- [ ] **Step 6: Commit.** `feat: dates as a setting with its one-time notice, and the credit to Theographic (library 6.5, 7)`

---

### Task 4: Chapter rings on both apps, and the iPhone's group headers (spec 5, 4.5)

**Run:** Sonnet. Headless renders on both platforms. The controller looks at the rings live on the Mac's shelf and in the simulator; Matt looks at them in Task 11.

**Files:**
- Create: `SUI/ChapterMarks.swift` (`ChapterMarks`, `ChapterRing`, the ring's view), `LIB/GroupLabel.swift` (`public struct GroupLabel: View { public init(_ title: String) }`)
- Modify: `SM/MarkupStore.swift` (beside `markedChapters`, `:124-131`), `SUI/MarkupModel.swift` (beside `markedChapters`, `:744-753`), `SUI/ChapterGridView.swift` (`ChapterCell`, `:172-215`, and the grid's `markedChapters`), `SUI/BookshelfView.swift` and `MAC/MainWindowView.swift` (`:33`, `:197-199`) and `SUI/FrontPageView.swift` (they pass the marks on), `SUI/LibraryList.swift`, `PH/PhoneLibraryScreen.swift` (the list's sections, `MarkedChapters` `:150-157`, `LibraryChapterGrid`)
- Test: create `T/ChapterRingTests.swift`; modify `TM/MarkupStoreTests.swift`, `T/MarkupModelTests.swift`, `T/PaletteTests.swift`, `T/LibraryListTests.swift`

**Interfaces:**
- Consumes: `BookGroup` (Task 2), `OKLCH` and `MarkLightness` (`SM/MarkLightness.swift`).
- Produces:

```swift
// MarkupStore: every chapter with a highlight, note or bookmark, and the ids of the colours its highlights have (maybe none).
public func chapterColorIDs() throws -> [ChapterLocation: Set<UUID>]
public struct ChapterMarks: Equatable, Sendable {
    public let colors: [MarkupColor]                                 // in the reader's colour order; empty: marked, with no colour
    public init(colors: [MarkupColor])
}
// MarkupModel: a colour id the store no longer has counts as no colour; a failed read is logged and empty.
public func chapterMarks() -> [ChapterLocation: ChapterMarks]
public enum ChapterRing {
    public static let maximumSegments = 6, gap = 0.03, lightLightness = 0.55, darkLightness = 0.68
    public struct Segment: Equatable, Sendable {
        public let start: Double, end: Double                        // fractions of the ring's path
        public let color: MarkupColor?                               // nil: `ink.tertiary`
    }
    public static func segments(for marks: ChapterMarks) -> [Segment]
    public static func ringHex(_ hex: String, dark: Bool) -> String  // the hex's hue at the ring's lightness, chroma 0.4 reduced until sRGB holds it
    public static func color(_ mark: MarkupColor) -> MarkupColor     // each appearance's hex through `ringHex`
}
// ChapterCell: `marks: ChapterMarks?` replaces `isMarked`; `size: ChapterCell.Size` (`.grid` 56 by 40 at `.title3`,
// the default; `.pane` 40 by 32 with numerals at `PageFace.baseSize(.callout)`, used from Task 6).
// ChapterGridView and LibraryChapterGrid take `marks: [Int: ChapterMarks]` in place of `markedChapters`.
// LibraryList
public struct Section: Equatable, Sendable { public let group: BookGroup, books: [TranslationBook] }
public var shownSections: [Section] { get }                          // the chosen testament's groups, in order, the empty left out
```

- **Segments.** No colour, or one: one segment, 0 to 1. Otherwise the first `maximumSegments` colours share the path equally, each shortened by half the gap at each end.
- **The ring** replaces the dot: the cell's own rounded rectangle inset `xxs` (4), stroked at a scaled 1.5 pt (`@ScaledMetric(relativeTo: .title3)`) with butt caps, each segment a `trim` of it; the chapter being read keeps its wash under it. A segment's colour is `ChapterRing.color(_:)` drawn as marks are (`Color(markup:)`), so Sepia keeps the light value. VoiceOver's "Marked" is unchanged.
- **The colourless ring** is the dot's ink. It measures 2.56:1 to 2.89:1 on the light and Sepia surfaces and 2.95:1 on the dark wash: below the coloured ring's 3:1, as the dot was. `PaletteTests` holds it at 2.5:1; say so in As built for Matt.
- **The iPhone's headers** (4.5): inside each Testament's list, the group's title before its books, in the chapter label's voice: `.caption2` semibold, upper case, `Color.inkVerse`, kerned by a scaled 1.4 pt (`@ScaledMetric(relativeTo: .caption2)`), `lg` side padding, `md` over and `xxs` under, with the header trait. The Apocrypha's header follows the Old Testament's groups. The label is `GroupLabel` in `LIB/GroupLabel.swift`, so Task 6 draws the same one.

- [ ] **Step 1: Write the failing tests.** `T/ChapterRingTests.swift` (`yellow`, `green` and `seven` are `MarkupColor`s; `marks(_:)` wraps them):

```swift
@Test func oneColourIsAWholeRingAndSeveralShareItEqually() {
    #expect(ChapterRing.segments(for: marks([yellow])) == [.init(start: 0, end: 1, color: yellow)])
    #expect(ChapterRing.segments(for: marks([])) == [.init(start: 0, end: 1, color: nil)])            // a bookmark, a chapter note
    let two = ChapterRing.segments(for: marks([yellow, green]))
    #expect(two.map(\.color) == [yellow, green] && abs(two[0].start - 0.015) < 1e-9 && abs(two[0].end - 0.485) < 1e-9 && abs(two[1].end - 0.985) < 1e-9)
    #expect(ChapterRing.segments(for: marks(seven)).map(\.color) == Array(seven.prefix(6)))
}
```

  In `TM/MarkupStoreTests.swift`, beside `markedChaptersListsEveryChapterWithAMark` (`:188`): `chapterColorIDs()` has the same keys as `markedChapters()`; a chapter with a yellow and a green highlight in two translations has both ids; a chapter with only a bookmark, or only a colourless highlight with a note, has an empty set. In `T/MarkupModelTests.swift`:

```swift
/// Review Focus 4: the colour was deleted after the highlight was made.
@Test func aDeletedColourCountsAsNoColour() throws {
    // … a model whose store has Matthew 5 highlighted in the third and then the first colour, Psalm 1 in a colour
    // that is then deleted, and a bookmark in Matthew 6 …
    let marks = model.chapterMarks()
    #expect(marks[ChapterLocation(book: "MAT", chapter: 5)]?.colors == [first, third])                 // the reader's order, not the order made
    #expect(marks[ChapterLocation(book: "PSA", chapter: 1)]?.colors == [] && marks[ChapterLocation(book: "MAT", chapter: 6)]?.colors == [])
    #expect(marks[ChapterLocation(book: "MAT", chapter: 1)] == nil)
}
```

  In `T/PaletteTests.swift`:

```swift
/// Spec 5: a ring reads as a mark on the page, the panel and the wash, for the defaults and for any hue the band allows.
@Test func aChaptersRingHoldsThreeToOneOnEverySurface() {
    var seeds = MarkupContainer.defaultColors.map { MarkupColor(lightHex: $0.lightHex, darkHex: $0.darkHex) }
    for hue in stride(from: 0, to: 360, by: 15) {
        let seed = Self.hex(oklchL: 0.6, chroma: 0.12, hueDegrees: Double(hue))
        seeds.append(MarkupColor(lightHex: MarkLightness.conformed(hex: seed, dark: false), darkHex: MarkLightness.conformed(hex: seed, dark: true)))
    }
    for seed in seeds {
        let ring = ChapterRing.color(seed)
        for paper in [Palette.paperPage, Palette.paperPanel, Palette.accentWash] {
            for a in Self.appearances {
                let ratio = Self.contrast(a.dark ? ring.darkHex : ring.lightHex, paper.hex(dark: a.dark, highContrast: a.high, sepia: a.sepia))
                #expect(ratio >= 3, "\(seed.lightHex) on \(paper.name) (dark: \(a.dark), high: \(a.high), sepia: \(a.sepia)) is \(ratio)")
            }
        }
    }
    #expect(abs((OKLCH(hex: ChapterRing.ringHex("#F8E18A", dark: false))?.l ?? 0) - 0.55) < 0.01)
    for paper in [Palette.paperPage, Palette.paperPanel, Palette.accentWash] { expect(Palette.inkTertiary, on: paper, atLeast: 2.5) }
}
```

  In `T/LibraryListTests.swift`: with the 66 books and one Apocrypha book, the Old Testament's `shownSections` are Law, History, Poetry & Wisdom, Major Prophets, Minor Prophets, Apocrypha, and the New Testament's are its four; every shown book is in exactly one section, in the translation's order.

- [ ] **Step 2: Run.** The filters FAIL to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Both suites pass.
- [ ] **Step 5: See it.** Render a grid of ten cells inside a taller container, on `paper.page`, `paper.panel`, and with the chapter being read on the wash: one colour, two, three, seven, none, and chapter 119 with a ring; in light, dark and Sepia, and at a large text size. On iOS, render the Library list in a `TestWindow` with a book open and the group headers showing. Open every picture: the ring clears a three-figure numeral, the gaps read as gaps, the wash shows under a ring. Say what was not seen (Increase Contrast, a live window).
- [ ] **Step 6: Commit.** `feat: a ring in the reader's colours round a marked chapter, and group headers in the iPhone's Library (library 5, 4.5)`

---

### Task 5: The navigation model holds the Library's place (spec 6.7, 6.6's opening; 10's last item)

**Run:** Opus (the navigation model's lookups and history). No UI. Nobody looks; every rule is a test.

**Files:**
- Create: `LIB/LibraryPlace.swift`
- Modify: `SUI/NavigationModel.swift` (the lookups `:149-165`, `:362-535`; `setTranslation` `:550-586`; `savePosition` `:947-954`; `paletteState` `:618-629`), `MAC/ReadingThroughScriptureApp.swift` (`:250-251`), `PH/PhoneReaderScreen.swift` (`:607-617`, `:706-707`)
- Test: create `T/LibraryPlaceTests.swift`; modify `T/NavigationModelTests.swift` (both suites)

**Interfaces:**
- Consumes: `NavigationModel.personPage` and `placePage` (Task 2), for a page's name.
- Produces:

```swift
public enum LibraryTopic: String, Hashable, Sendable, CaseIterable { case people, places, about }
public enum LibraryEntity: Hashable, Sendable { case person(Int), place(Int) }
/// Where the reader is in the Library: a book's People, Places or About (or the whole Bible's, reached by name),
/// and the people or places walked to from there.
public struct LibraryPlace: Hashable, Sendable {
    public var book: String?                                         // nil: the whole Bible
    public var topic: LibraryTopic
    public private(set) var trail: [LibraryEntity]                   // the last is the one showing
    public var openBooks: Set<String>                                // the books whose verses are open on the page showing
    public private(set) var anchor: Reference?                       // the reference last opened from it
    public init(book: String?, topic: LibraryTopic, trail: [LibraryEntity] = [])
    public var showing: LibraryEntity? { get }
    public mutating func choose(_ entity: LibraryEntity)             // the list's choice: the trail is that one alone
    public mutating func walk(to entity: LibraryEntity)              // a family name, a place at the same spot: one more
    public mutating func stepBack()                                  // the header's way back to the one before
    public func opening(_ reference: Reference) -> LibraryPlace      // with the anchor set
}
public struct LibraryReturn: Equatable, Sendable { public let place: LibraryPlace, chosenBookID: String? }
// NavigationModel
public var libraryPlace: LibraryPlace?                               // nil: the contents
public private(set) var libraryReturn: LibraryReturn?
public var isLookingUp: Bool { get }                                 // a lookup is showing, with or without a place to return to
public var lookupBackTitle: String? { get }                          // the Library page's name, else `lookupReturnTitle`
public func title(for place: LibraryPlace) -> String                 // "Simon Peter", "Bethany", "People in John", "Places in John", "About John"
public func lookUpFromLibrary(_ reference: Reference, from place: LibraryPlace)
public func showInLibrary(_ place: LibraryPlace)                     // a person or place by name: the front page on it
public func returnToReader()                                         // the page being read, at its verse; nothing with nothing being read
```

**The rules.** `choose`, `walk` and `stepBack` clear `openBooks` and `anchor`.
- **`lookUpFromLibrary`** keeps `LibraryReturn(place:, chosenBookID: selectedBookID)` and records the lookup in Recents (`recordLookup`). With a chapter being read it is then `lookUp`. With nothing being read it shows the passage through the history without setting `lookupReturn` and without recording a chapter as read.
- **While `libraryReturn` is set with no `lookupReturn`** (nothing was being read): the stored position is not written, by scrolling or anything else; a position from the other device is not taken; `canGoBack` is true; a further `lookUp` shows its passage through the history and still sets no `lookupReturn`.
- **Returning.** Wherever a lookup ends by going back (`returnFromLookup`, `returnToWhereReadElsewhere`, `land(on:)` reaching the return chapter), a `libraryReturn` then puts back `libraryPlace` and `selectedBookID`, shows the front page and is cleared. With no `lookupReturn`, `goBack` steps back through the history while it can and otherwise returns to the Library; `returnFromLookup` returns at once; either leaves no chapter open, no verses, no book text, and an empty history.
- **Ending where it is.** `endLookupHere` (a chosen chapter, Next, Previous) and `keepLookup` clear `libraryReturn`; `keepLookup` works with no `lookupReturn` and saves the place.
- **Home.** During a lookup `goHome` returns from it, which for one begun in the Library shows the Library as it was. Otherwise it clears `libraryPlace` and chooses the book being read (4.4).
- **`showInLibrary`** returns from any lookup, then sets `libraryPlace` and shows the front page; `selectedBookID` is left as it is.
- **`setTranslation`.** A `libraryPlace` whose book the new translation lacks is cleared. A lookup with no `lookupReturn` that the new translation lacks ends with `libraryReturn` cleared and the stored position left alone.
- **Quitting** needs nothing: neither value is stored.
- `isLookingUp` replaces `lookupReturn != nil` in `paletteState`, the Go menu's Read From Here and the phone's bar (its title becomes `lookupBackTitle`; reopening the Library is Task 9's).

- [ ] **Step 1: Write the failing tests.** In `T/LibraryPlaceTests.swift`:

```swift
@Test func thePlaceWalksAndStepsBackAndForgetsThePagesOwnState() {
    var place = LibraryPlace(book: "MAT", topic: .people)
    place.choose(.person(994))
    place.openBooks = ["PSA"]
    place = place.opening(Reference(book: BookCatalog.book(code: "PSA")!, chapter: 18, verse: 50))
    #expect(place.showing == .person(994) && place.anchor?.displayString == "Psalm 18:50")
    place.walk(to: .person(903))
    #expect(place.trail == [.person(994), .person(903)] && place.openBooks.isEmpty && place.anchor == nil)
    place.stepBack()
    #expect(place.trail == [.person(994)])
    place.choose(.person(905))
    #expect(place.trail == [.person(905)])
}
```

  In `T/NavigationModelTests.swift`, with `makeModel()` (`:23`) and `readingMatthewOne()` (`:801`); `ref(_:_:_:)` makes a `Reference`, `david` is `LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])`:

```swift
/// Spec 6.7: Back returns to the same book, view and person.
@Test func openFromTheLibraryReturnsToTheSamePerson() throws {
    let (model, positionStore) = try readingMatthewOne()
    model.goHome()
    model.selectedBookID = "PSA"
    model.libraryPlace = david
    let stored = positionStore.load(), opened = david.opening(ref("MAT", 5, 3))
    model.lookUpFromLibrary(ref("MAT", 5, 3), from: opened)
    #expect(model.screen == .reader && model.location == ChapterLocation(book: "MAT", chapter: 5) && model.isLookingUp)
    #expect(model.lookupBackTitle == "David" && model.canGoBack && positionStore.load() == stored)
    model.goBack()
    #expect(model.screen == .frontPage && model.libraryPlace == opened && model.selectedBookID == "PSA" && !model.isLookingUp)
    #expect(model.location == ChapterLocation(book: "MAT", chapter: 1) && positionStore.load() == stored)
    model.lookUpFromLibrary(ref("MAT", 5, 3), from: opened)
    model.goHome()                                                       // Home on the Mac does the same
    #expect(model.screen == .frontPage && model.libraryPlace == opened && model.selectedBookID == "PSA" && model.libraryReturn == nil)
}

/// Spec 6.7: with nothing being read, Open is still a lookup and leaves no reading place.
@Test func withNothingBeingReadOpenIsALookupThatLeavesNoPlace() throws {
    let (model, positionStore) = try makeModel()
    let about = LibraryPlace(book: "MAT", topic: .about)
    model.selectedBookID = "MAT"
    model.libraryPlace = about
    model.lookUpFromLibrary(ref("MAT", 2, 1), from: about)
    #expect(model.screen == .reader && model.location?.chapter == 2 && model.isLookingUp && model.lookupReturn == nil && model.canGoBack)
    #expect(model.lookupBackTitle == "About Matthew")
    model.reportReadingPosition(VerseLocation(book: "MAT", chapter: 2, verse: 2))
    model.reportReadingPosition(VerseLocation(book: "MAT", chapter: 2, verse: 3))
    #expect(positionStore.load() == nil)                                 // scrolling writes nothing
    model.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 1)     // a second passage, from the first
    #expect(model.lookupReturn == nil && model.isLookingUp)
    model.goBack()
    #expect(model.screen == .reader && model.location?.chapter == 2 && model.isLookingUp)
    model.goBack()
    #expect(model.screen == .frontPage && model.libraryPlace == about && model.location == nil && model.verses.isEmpty)
    #expect(!model.canGoBack && !model.canGoForward && !model.isLookingUp && positionStore.load() == nil)
}

@Test func readingOnOrReadFromHereEndsALibraryLookup() throws {
    let (model, positionStore) = try readingMatthewOne()
    model.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
    model.goToNextChapter()                                              // reading on makes it the place
    #expect(!model.isLookingUp && model.libraryReturn == nil && positionStore.load()?.chapter == 6)
    model.goBack()                                                       // the reader's own history
    #expect(model.screen == .reader && model.location?.chapter == 5)
    let (empty, emptyStore) = try makeModel()
    empty.lookUpFromLibrary(ref("MAT", 2, 1), from: LibraryPlace(book: "MAT", topic: .about))
    empty.keepLookup()                                                   // Read From Here, with nothing being read
    #expect(!empty.isLookingUp && emptyStore.load()?.chapter == 2)
    empty.goHome()
    #expect(empty.libraryPlace == nil && empty.selectedBookID == "MAT")  // a plain Home is the contents
}

/// Spec 6.7: quitting reopens at the reading place. Review Focus 2: the Library's book gone from the translation.
@Test func quittingOrChangingTranslationLeavesNoStaleLibrary() throws {
    let defaults = makeDefaults()
    let (model, _) = try readingMatthewOne(defaults: defaults)
    model.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
    let (relaunched, _) = try makeModel(defaults: defaults)
    #expect(relaunched.location == ChapterLocation(book: "MAT", chapter: 1) && relaunched.libraryPlace == nil && !relaunched.isLookingUp)
    let (front, _) = try makeModel()
    front.selectedBookID = "TOB"
    front.libraryPlace = LibraryPlace(book: "TOB", topic: .about)
    front.setTranslation("KJV")                                          // the fixture's KJV has no Tobit
    #expect(front.libraryPlace == nil && front.selectedBookID == "PSA")
}

@Test func aTranslationWithoutTheLibrarysBookClosesItsView() throws {
    let (model, positionStore) = try makeModel()
    let tobit = LibraryPlace(book: "TOB", topic: .about)
    model.lookUpFromLibrary(ref("TOB", 1, 1), from: tobit)               // nothing being read; WEB alone has Tobit
    model.setTranslation("KJV")
    #expect(!model.isLookingUp && model.libraryReturn == nil && model.location == nil && model.screen == .frontPage && positionStore.load() == nil)
}

/// Spec 6.6: a person chosen by name shows on the front page, the pane keeping its book.
@Test func aPersonByNameShowsOnTheFrontPage() throws {
    let (model, positionStore) = try readingMatthewOne()
    let stored = positionStore.load()
    model.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 2)
    let byName = LibraryPlace(book: nil, topic: .people, trail: [.person(905)])
    model.showInLibrary(byName)
    #expect(model.screen == .frontPage && model.libraryPlace == byName && model.selectedBookID == "MAT" && !model.isLookingUp)
    #expect(model.title(for: byName) == "Jesus Christ" && positionStore.load() == stored)
    model.returnToReader()
    #expect(model.screen == .reader && model.location == ChapterLocation(book: "MAT", chapter: 1))
}
```

  Also: a position written by the other device during a lookup with nothing being read is not taken by `adoptStoredPosition()` until it ends (the suite's other-device tests show how one is written); `returningRestoresChapterVerseAndTranslation` (`:860`) and `aLookupFromTheFrontPageIsAnOpen` (`:949`) pass unchanged, since only the Library's Open changes.

- [ ] **Step 2: Run.** `--filter LibraryPlaceTests` and `--filter NavigationModelTests` FAIL to compile.
- [ ] **Step 3: Implement** the place and the model's rules, and move the three call sites to `isLookingUp`.
- [ ] **Step 4: Run.** Both suites pass, every earlier lookup test among them; both Debug builds succeed.
- [ ] **Step 5: Commit.** `feat: the Library's place in the navigation model, and a lookup that returns to it (library 6.7)`

---

### Task 6: The Mac's contents page and book pane (spec 4.1 to 4.4; 11's benchmark)

**Run:** Opus (focus and keyboard). Headless renders, which cannot show the focus ring, Tab's order, a click, a double-click, the toolbar's field or ⌘F. One live pass by the controller afterwards, keys only: Tab between the contents and the pane, the arrows, Return, ⌘F then "rom 8" then Return, ⇧⌘H. Matt looks at the page in Task 11 (clicks, the double-click, scrolling at a large text size).

**Files:**
- Create: `LIB/ContentsPage.swift`, `LIB/ContentsPageView.swift`, `LIB/BookPaneView.swift`
- Modify: `SUI/FrontPageView.swift` (rewritten), `SUI/ChapterGridView.swift`, `SUI/ShortcutCatalog.swift` (the `searchNotes` row's label), `MAC/MainWindowView.swift` (`:33`, `:196-199`, `:292-299`). `FrontPageSearch` stays as it is.
- Delete: `SUI/BookshelfView.swift`
- Test: create `T/ContentsPageTests.swift` (both suites), `T/FrontPageBenchmarkTests.swift` (`#if os(macOS)`); modify `T/ShortcutCatalogTests.swift` where it pins the row's label

**Interfaces:**
- Consumes: `BookGroup`, `NavigationModel.bookSubtitle` (Task 2); `ChapterMarks`, `ChapterCell.Size.pane`, `GroupLabel` (Task 4); `libraryPlace`, `returnToReader()` (Task 5); `FrontPageSearch.results(query:books:)`.
- Produces:

```swift
public struct ContentsPage: Equatable, Sendable {
    public struct Block: Equatable, Sendable { public let group: BookGroup, books: [TranslationBook] }
    public struct Testament: Identifiable, Equatable, Sendable {
        public let canon: Canon, blocks: [Block]
        public var id: Canon { get }
        public var title: String { get }                             // "Old Testament"
        public var countLabel: String { get }                        // "39 books"
    }
    public enum Row: Hashable, Sendable { case group(BookGroup), book(TranslationBook) }
    public struct Section: Equatable, Sendable { public let testament: Testament, columns: [[Row]] }
    public struct Layout: Equatable, Sendable {
        public let bands: [[Section]]                                // a band is Testaments side by side
        public var columns: [[String]] { get }                       // each column's book ids, left to right, band by band
    }
    public enum Target: Equatable, Sendable { case resume, chapter(ChapterLocation), reference(Reference) }
    public enum Move: Sendable { case up, down, left, right }

    public let testaments: [Testament]
    public let reading: ChapterLocation?
    public private(set) var chosenBookID: String?
    public private(set) var query: String
    /// Chosen: the given book if the translation has it, else the book being read, else the first.
    public init(books: [TranslationBook], reading: ChapterLocation?, chosenBookID: String?)
    public mutating func choose(_ bookID: String)
    public mutating func setQuery(_ text: String)                    // chooses the first match; with none, or nothing typed, the choice stays
    public var matches: Set<String>? { get }                         // nil with nothing typed
    public func isDimmed(_ bookID: String) -> Bool
    public var hasNoMatch: Bool { get }
    public var ringedChapter: Int? { get }                           // the typed reference's chapter, while its book is the chosen one
    public func target(opening bookID: String) -> Target             // a double-click: the book being read resumes; any other opens at chapter 1
    public var submitTarget: Target? { get }                         // Return in the field: the reference, else the chosen book's target
    public static func columnCount(width: CGFloat, minimumColumnWidth: CGFloat) -> Int
    public func layout(columns: Int) -> Layout
    public func bookID(moving move: Move, from bookID: String, in layout: Layout) -> String?
}
public struct ContentsPageView: View {
    public init(page: ContentsPage, markedBooks: Set<String>, onChoose: @escaping (String) -> Void, onOpen: @escaping (String) -> Void)
}
public struct BookPaneView: View {
    public init(navigation: NavigationModel, book: TranslationBook, marks: [Int: ChapterMarks], ringedChapter: Int?)
}
// FrontPageView
public init(navigation: NavigationModel, marks: [ChapterLocation: ChapterMarks])
// ChapterGridView gains `subtitle: String?`, `ringedChapter: Int?` (its cursor starts there) and `cellSize: ChapterCell.Size`.
```

**The model's rules.** Matches are `FrontPageSearch.results`' books. The layout is as "Decided here" has it; a Testament never gets more columns than it has groups (or books, when it is one group). Down and Up walk a column's books and pass to the next or the previous column at its end; Left and Right go to the neighbouring column of the same band at the same book's place, held to that column's last book; at an edge, nil.

**The views.**
- **The page** is the contents (all the width left, on `paper.page`) beside the pane, a scaled 260 pt (`@ScaledMetric(relativeTo: .body)`) on `paper.panel`. The contents scroll on their own when they do not fit; the pane never scrolls with them.
- **The contents:** `lg` padding; bands `xl` apart; Testaments in a band `lg` apart; columns `md` apart, counted from the measured width at a scaled 180 pt each. A Testament's title in `pageFace.swiftUIFont(.title3)` `ink.primary`, its count trailing in `.caption` `ink.secondary`, over a 1 pt `ink.rule` line. A group is `GroupLabel`, `sm` above it except at a column's head. A book is its name in `pageFace.swiftUIFont(.body)`, `ink.primary`, or `ink.tertiary` when dimmed, with `xxs` down and `xs` across; the chosen one on `accent.wash` at radius `md`; a marked one followed by a scaled 3 pt `ink.tertiary` dot.
- **Clicks:** a tap chooses; a double tap, added as a simultaneous gesture so the first click still chooses at once, opens.
- **Keys:** the contents are one Tab stop and the pane's grid another. In the contents the chosen book carries the focus ring (the focus effect's shape is its rounded rectangle, as `ChapterGridView.swift:124` does for a cell); the arrows choose; Return or Space moves focus to the grid. ⇧⌘H and the toolbar's Home are `goHome`, unchanged.
- **VoiceOver:** a Testament's title and a group's name are headers; a book is a button with the selected trait when chosen and the value "Marked" when it is.
- **The pane:** `md` padding at the top, `sm` at the sides; the name in Display; `bookSubtitle` in the page face's italic at `.callout`, `ink.secondary`; `BookReferenceRow`; the grid, five across in `.pane` cells, in its own scroll view. With no match, `ContentUnavailableView.search(text:)` in the pane's place.
- **Search:** `.searchable(text:isPresented:placement: .toolbar, prompt: "Books or a reference")` on the front page, with ⌘F as `NotesBrowserView.swift:52-59` does it. Typed text goes to `setQuery`, the chosen book to `navigation.selectedBookID`, and `navigation.libraryPlace` to nil. Return is `.onSubmit(of: .search)`; if that does not fire for a toolbar field (it did not for the sidebar's), take Return by a key press while the field has focus, as the old page did. The catalogue's row becomes "Search the front page or Notes".
- **Opening:** `.resume` is `navigation.returnToReader()`, `.chapter` is `navigation.open(_:)`, `.reference` is `navigation.open(_:)` on the reference. A chapter's cell opens it as before.
- `MainWindowView` reads `markup.chapterMarks()` each time the front page shows and hands it over.

**The benchmark** (`@MainActor @Suite(.serialized)`, `.needsRealBible`): the navigation model on the real store reading John 15 in the ESV, on the front page; forty marked chapters across ten books; an `NSWindow` that is never shown.

```swift
/// Spec 11: the front page opens within 100 ms on Matt's Mac in a debug build.
@Test(.needsRealBible) func theFrontPageOpensWithinAHundredMilliseconds() throws {
    let median = ReaderBenchmarkTests.median("front-page-open") {
        let host = NSHostingView(rootView: FrontPageView(navigation: navigation, marks: marks).frame(width: 1100, height: 760))
        host.frame = NSRect(x: 0, y: 0, width: 1100, height: 760)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
    }
    #expect(median < .milliseconds(100))
}
```

- [ ] **Step 1: Measure today's page.** Write the benchmark against the front page as it is now (its present init, with the marks as a set), run it alone three times (`--filter FrontPageBenchmarkTests`) and write the middle median on the "Today" line of "The data, measured" in this plan. Do not commit this form of the test.
- [ ] **Step 2: Write the failing tests.** `T/ContentsPageTests.swift`: `sixtySix` is every non-Apocrypha `BookCatalog` book as a `TranslationBook` of 28 chapters; `apocrypha` the Apocrypha's books likewise.

```swift
@Test func thePageOpensOnTheBookBeingReadAndAClickChooses() {
    var page = ContentsPage(books: sixtySix, reading: ChapterLocation(book: "JHN", chapter: 15), chosenBookID: nil)
    #expect(page.chosenBookID == "JHN" && page.testaments.map(\.title) == ["Old Testament", "New Testament"])
    #expect(page.testaments.map(\.countLabel) == ["39 books", "27 books"] && page.testaments[0].blocks.map(\.books.count) == [5, 12, 5, 5, 12])
    page.choose("ROM")
    #expect(page.chosenBookID == "ROM" && page.target(opening: "ROM") == .chapter(ChapterLocation(book: "ROM", chapter: 1)) && page.target(opening: "JHN") == .resume)
    #expect(ContentsPage(books: sixtySix, reading: nil, chosenBookID: "XYZ").chosenBookID == "GEN")
    #expect(ContentsPage(books: sixtySix + apocrypha, reading: nil, chosenBookID: nil).testaments.map(\.title) == ["Old Testament", "New Testament", "Apocrypha"])
}

@Test func fourColumnsAreTheMockupsAndFewerStackTheTestaments() {
    let page = ContentsPage(books: sixtySix + apocrypha, reading: nil, chosenBookID: nil)
    func heads(_ section: ContentsPage.Section) -> [[String]] {
        section.columns.map { column in column.compactMap { if case .group(let group) = $0 { group.title } else { nil } } }
    }
    let four = page.layout(columns: 4)
    #expect(four.bands.map { $0.map(\.testament.title) } == [["Old Testament", "New Testament"], ["Apocrypha"]])
    #expect(heads(four.bands[0][0]) == [["Law", "History"], ["Poetry & Wisdom", "Major Prophets", "Minor Prophets"]])
    #expect(heads(four.bands[0][1]) == [["Gospels & Acts", "Paul’s Letters"], ["General Letters", "Revelation"]])
    #expect(four.bands[1][0].columns.count == 4 && heads(four.bands[1][0]).map(\.count) == [1, 0, 0, 0])   // one group, broken between books
    #expect(page.layout(columns: 5).bands[0].map(\.columns.count) == [3, 2])
    #expect(heads(page.layout(columns: 6).bands[0][0]) == [["Law", "History"], ["Poetry & Wisdom", "Major Prophets"], ["Minor Prophets"]])   // the most even
    #expect(page.layout(columns: 3).bands.map { $0.map(\.columns.count) } == [[3], [3], [3]] && page.layout(columns: 1).bands.count == 3)
    #expect(ContentsPage.columnCount(width: 792, minimumColumnWidth: 180) == 4 && ContentsPage.columnCount(width: 100, minimumColumnWidth: 180) == 1)
}

@Test func typingDimsAndChoosesAndAReferenceRingsItsChapter() {
    var page = ContentsPage(books: sixtySix, reading: ChapterLocation(book: "JHN", chapter: 15), chosenBookID: nil)
    page.setQuery("rom 8")
    #expect(page.chosenBookID == "ROM" && page.ringedChapter == 8 && page.isDimmed("GEN") && !page.isDimmed("ROM"))
    #expect(page.submitTarget == .reference(Reference(book: BookCatalog.book(code: "ROM")!, chapter: 8)))
    page.setQuery("1")                                                   // the numbered books, the first of them chosen
    #expect(page.chosenBookID == "1SA" && page.matches?.isSuperset(of: ["1SA", "1KI", "1CO"]) == true && page.ringedChapter == nil)
    #expect(page.submitTarget == .chapter(ChapterLocation(book: "1SA", chapter: 1)))
    page.setQuery("zzz")
    #expect(page.hasNoMatch && page.submitTarget == nil && page.chosenBookID == "1SA" && page.isDimmed("1SA"))
    page.setQuery("")
    #expect(page.matches == nil && !page.isDimmed("GEN") && !page.hasNoMatch && page.chosenBookID == "1SA")
}

@Test func theArrowsWalkDownAColumnAndAcrossColumns() {
    let page = ContentsPage(books: sixtySix, reading: nil, chosenBookID: nil), layout = page.layout(columns: 4)
    func move(_ move: ContentsPage.Move, from id: String) -> String? { page.bookID(moving: move, from: id, in: layout) }
    #expect(move(.down, from: "DEU") == "JOS" && move(.down, from: "EST") == "JOB" && move(.up, from: "JOB") == "EST")
    #expect(move(.right, from: "GEN") == "JOB" && move(.right, from: "JOB") == "MAT" && move(.right, from: "MAT") == "HEB")
    #expect(move(.right, from: "EST") == "NAM" && move(.left, from: "MAL") == "EST")       // the same place down; held to the last book
    #expect(move(.right, from: "HEB") == nil && move(.left, from: "GEN") == nil && move(.up, from: "GEN") == nil && move(.down, from: "REV") == nil)
}
```

- [ ] **Step 3: Run.** `--filter ContentsPageTests` FAILS to compile.
- [ ] **Step 4: Build** the model, the two views and the new front page; delete the shelf; write the benchmark in its final form.
- [ ] **Step 5: Run.** Both suites pass; the benchmark's median is under 100 ms run alone. If it is not, stop and report with the figure: the budget is the spec's, not a number to raise. Both Debug builds succeed.
- [ ] **Step 6: See it.** Render the front page at 1100 by 760, and at 820 by 520, inside a taller container: reading John 15 in the ESV with marks on a dozen books; with the Apocrypha (WEB); with "rom 8" typed; with "zzz" typed; Psalms chosen (150 cells in the pane); in light, dark and Sepia; at the largest standard text size and one accessibility size. Open every picture: four columns at the default size and fewer at the large one, no name clipped or wrapped, the wash and the dot visible, the pane's grid inside its 260 pt. Say what could not be seen.
- [ ] **Step 7: Commit.** `feat: the Mac's front page is one contents page with a book pane (library 4.1-4.4)`

---

### Task 7: People and About on the Mac (spec 6.1, 6.2, 6.4, 6.5 in place, 7's foot)

**Run:** Sonnet. Headless renders, which cannot show a reference's click, the popover's anchor, Open, or Esc. One live pass by the controller afterwards (Tab to an icon, Space, the arrows in the list, Esc). Matt looks at a person's page in Task 11: the popover, Open, Back.

**Files:**
- Create: `LIB/LibraryView.swift`, `LIB/LibraryPeopleView.swift`, `LIB/PersonPageView.swift`, `LIB/FamilyView.swift`, `LIB/ReferenceRunsText.swift`, `LIB/LibraryPassage.swift`, `LIB/DictionaryEntryView.swift`, `LIB/LibraryAboutView.swift`
- Modify: `SUI/FrontPageView.swift`, `SUI/BookReferenceRow.swift`, `LIB/BookPaneView.swift`, `MAC/MainWindowView.swift` (`:292-299`: the notice's Settings opens Settings › General, as `:366-369` does)
- Test: create `T/LibraryPassageTests.swift` (both suites)

**Interfaces:**
- Consumes: the page models (Task 2); `DatesNotice`, `DatesFootnote`, `LibraryDates`, `LibraryCreditLine` (Task 3); `LibraryPlace`, `lookUpFromLibrary`, `title(for:)` (Task 5); `VersePreviewView`, `ReferenceLinker.url(for:)` and `reference(from:)`.
- Produces:

```swift
public enum LibraryPassage: Equatable, Sendable {
    case verses(VersePreview), missing(Reference)
    public static func load(_ reference: Reference, navigation: NavigationModel) -> LibraryPassage
    public var missingLine: String? { get }                          // "John 1:1 is not in the translation being read."
}
/// References as one run of links with a middle dot between them. Without `onShow`, a click shows the passage in
/// a popover where it was clicked, with Open (the Mac); with it, the click is handed over (the phone pushes).
public struct ReferenceRunsText: View {
    public init(_ references: [Reference], inBook book: Book?, navigation: NavigationModel,
                onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void)
    nonisolated static func text(_ references: [Reference], inBook book: Book?) -> AttributedString
}
public struct DictionaryEntryView: View { public init(_ text: String) }
public struct FamilyView: View { public init(page: PersonPage, onWalk: @escaping (PersonSummary) -> Void) }
public struct PersonPageView: View {
    public init(page: PersonPage, bookName: String?, navigation: NavigationModel, openBooks: Binding<Set<String>>, anchor: Reference?,
                onWalk: @escaping (LibraryEntity) -> Void, onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void)
}
public struct LibraryAboutView: View {
    public init(about: BookAbout, navigation: NavigationModel, onWalk: @escaping (LibraryEntity) -> Void,
                onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void)
}
/// The contents half of the Mac's front page while a Library view is open.
public struct LibraryView: View { public init(navigation: NavigationModel, place: Binding<LibraryPlace>, onOpenSettings: @escaping () -> Void) }
// BookReferenceRow gains `availableTopics: Set<LibraryTopic>`, `activeTopic: LibraryTopic?`, `onOpenTopic: (LibraryTopic) -> Void`.
// FrontPageView's init gains `onOpenSettings: @escaping () -> Void`.
```

- **The icons.** For one of the 66 the pane passes `[.people, .about]` (Task 8 adds `.places`): outline and symbol in the accent, a button that sets `navigation.libraryPlace = LibraryPlace(book:, topic:)`; the open view's icon sits on `accent.wash`. One that is not available keeps today's quiet drawing and VoiceOver reads "People, not available for this book".
- **The header:** "Contents" with `chevron.left`, a plain button in `accent` at `.callout` semibold, which sets the place to nil; Esc does the same (`onExitCommand`, as the palette). When the trail is longer than one, a second plain button with `chevron.left` and the name of the one before (`stepBack`). Then the title in `pageFace.swiftUIFont(.title3)`: `title(for:)` of the book's topic ("People in John"), or for the whole Bible the name. The count trails in `.caption` `ink.secondary`. A 1 pt `ink.rule` line under.
- **People:** the list a scaled 200 pt wide: a row is the name in `.callout` `ink.primary`, its label under it in `.caption` `ink.secondary`, its count trailing in `.caption.monospacedDigit()` `ink.secondary`; the chosen row on `accent.wash` at radius `md`, chosen only while the person showing is in the list; Up and Down move it. A 1 pt `ink.rule` line, then the person's page; with nobody chosen, "Choose a person." in `.callout` `ink.secondary`.
- **A person's page:** `lg` padding, at most a scaled 520 pt wide, scrolling. The name in `.title2` semibold with the header trait; the label and `alsoCalledLine` in `.callout` `ink.secondary`; `life(showingDates:)` in `.callout` with `DatesFootnote` under it; `DictionaryEntryView`; then sections, each headed in the Label style (`.caption` semibold `ink.secondary`, header trait): "Family"; "In John" (`here`, its references without the book's name); "Elsewhere", or "Verses" for the whole Bible: each book a row of its name and count that opens to its references, all open at first when `opensEveryBook`. A section with nothing is left out. On coming back, `anchor`'s book is open and scrolled into view.
- **The dictionary's entry:** the Quote serif (`pageFace.quoteFont()`), three lines, then "Show more" as a plain button in `accent`; under it "Easton’s Bible Dictionary, 1897" in `.caption` `ink.secondary`.
- **Family:** three rows, centred: the parents; the partners, the person (on `accent.wash`, not a button) and the siblings; the children. A name is a plain button drawn as the Chip is (`ChipLabel`, on `paper.panel`); a row wraps through a small `FlowLayout` with `xs` gaps; a 1 pt `ink.rule` line, `sm` tall, joins a generation to the next; an empty generation is left out with its line. VoiceOver reads "Jesse, parent", "Solomon, child", "Mary, partner", "Eliab, sibling".
- **A reference clicked:** `LibraryPassage.load`. Verses show in the system's popover as `VersePreviewView(preview:openTitle: "Open")`; a missing one shows `missingLine` in `.callout` with no button. Open closes the popover and calls `navigation.lookUpFromLibrary(reference, from: place.opening(reference))`. Nothing else changes while the popover is up. VoiceOver reaches each reference as a named action, as `NoteBodyText` does.
- **About:** rows of a label and its value: "Place" (`placeLine`), "Length", "Traditionally attributed to" (each writer a plain button in `accent` that opens that person in the book's People), "People and places"; "When" with `span` and `DatesFootnote`; "Events", each a row of its title in `.callout`, its passage as a link, and its year in `.caption` `ink.secondary`. A book with no events has neither When nor Events.
- **The notice** heads the view when `LibraryDates.showsNotice(_:viewHasDate:)`; **the credit** is `LibraryCreditLine` at the foot of every view, `lg` above it.

- [ ] **Step 1: Write the failing tests.** The model reads the fixture in WEB, which has no John.

```swift
/// Review Focus 1.
@Test func aReferenceTheTranslationLacksSaysSoAndOffersNoOpen() throws {
    let before = model.libraryPlace
    let there = LibraryPassage.load(ref("MAT", 5, 3), navigation: model), missing = LibraryPassage.load(ref("JHN", 1, 1), navigation: model)
    guard case .verses(let preview) = there else { Issue.record("no verses"); return }
    #expect(preview.verses.map(\.id.verse) == [3] && there.missingLine == nil)
    #expect(missing == .missing(ref("JHN", 1, 1)) && missing.missingLine == "John 1:1 is not in the translation being read.")
    #expect(model.libraryPlace == before && model.screen == .frontPage && !model.isLookingUp)      // showing a passage changes nothing
}

@Test func referencesInTheirOwnBookDropItsName() {
    let references = VerseRuns.references([mt(1, 18), mt(1, 19), mt(2, 1)])
    #expect(String(ReferenceRunsText.text(references, inBook: BookCatalog.book(code: "MAT")).characters) == "1:18-19 · 2:1")
    #expect(String(ReferenceRunsText.text(references, inBook: nil).characters) == "Matthew 1:18-19 · Matthew 2:1")
    #expect(ReferenceRunsText.text(references, inBook: nil).runs.compactMap(\.link).count == 2)
}
```

- [ ] **Step 2: Run.** `--filter LibraryPassageTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** Both suites pass; both Debug builds succeed.
- [ ] **Step 5: See it.** Render, each inside a taller container, in light, dark and Sepia and once at a large text size: People in Matthew with the second Jacob chosen; David's page with the notice at its head, and again answered; the page of someone walked to who is not in the book; About Matthew; About Psalms; all of these with dates off (no year anywhere). Render the popover's content alone for Matthew 5:3 and for Psalm 1:1-2 (poetry), and the missing line. Open every picture: no row clipped, the family's rows wrap, the wash shows on the chosen row and the open icon. Say what could not be seen.
- [ ] **Step 6: Commit.** `feat: People and About for a book on the Mac, with a family to walk (library 6.1, 6.2, 6.4)`

---

### Task 8: Places on the Mac (spec 6.3)

**Run:** Opus (MapKit's selection). Headless renders show the list and the page but no tiles and no markers' taps. One live pass by the controller (the list's arrows move the map). Matt looks at the map in Task 11.

**Files:**
- Create: `LIB/PlacesSelection.swift`, `LIB/PlacesMapView.swift`, `LIB/LibraryPlacesView.swift`, `LIB/PlacePageView.swift`
- Modify: `LIB/LibraryView.swift`, `LIB/BookPaneView.swift` (`.places` joins the available topics)
- Test: create `T/PlacesSelectionTests.swift` (both suites)

**Interfaces:**
- Consumes: `BookPlaces`, `PlacePage` (Task 2); Task 7's views.
- Produces:

```swift
public struct PlacesSelection: Equatable, Sendable {
    public private(set) var placeID: Int?
    public private(set) var pinID: String?
    public init()
    public mutating func choose(place id: Int, in places: BookPlaces)      // the list: its pin too; no pin for one not on the map
    public mutating func choose(pin id: String?, in places: BookPlaces)    // the map: a pin of one place chooses it; a gathered pin chooses no place
    public func gathered(in places: BookPlaces) -> [PlaceSummary]?         // the chosen pin's places, when it holds several and none is chosen
}
/// Apple's map in the muted standard style: one marker to a pin, in the accent; a gathered pin shows its count.
public struct PlacesMapView: View {
    public init(pins: [BookPlaces.Pin], frame: BookPlaces.Frame?, selection: Binding<String?>, focus: BookPlaces.Pin?)
}
public struct PlacePageView: View {
    public init(page: PlacePage, bookName: String?, navigation: NavigationModel, openBooks: Binding<Set<String>>, anchor: Reference?,
                onWalk: @escaping (LibraryEntity) -> Void, onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void)
}
public struct LibraryPlacesView: View { public init(navigation: NavigationModel, place: Binding<LibraryPlace>) }
```

- **The map:** `Map(position:selection:)` with a `Marker` to each pin tagged with its id and tinted `Color.accent`, a gathered pin's with its count as the monogram; `.mapStyle(.standard(emphasis: .muted))`. It opens at `frame`. Pins never cluster. When `focus` changes to a pin outside the region in view (kept from `onMapCameraChange`), the camera moves to hold it at the same zoom; a cut under Reduce Motion. A marker's label for VoiceOver is "Jerusalem, 2 places".
- **A book's Places:** the list as People's (a row's second line is its kind and label), those not on the map under a Label-style header "Not on the map". Beside it the map on top, at least a scaled 240 pt and half the height, with the chosen place's page beneath; for a gathered pin, "2 places here" and its places as rows that choose. With nothing chosen the map has the whole height. The header's count is `countLabel`. A book that names no place: `ContentUnavailableView("No Places", systemImage: "map", description: Text("No places are named in Philemon."))`.
- **A place's page:** the name in `.title2` semibold; `kindLine` and `alsoCalledLine` in `.callout` `ink.secondary`; the dictionary's entry; "At the same spot" (each a chip that walks to it); "In Matthew"; "Elsewhere" or "Verses", as a person's.
- **For the whole Bible:** no list; the map with `page.pin` at half a degree above the page; for a place not on the map, no map and the line "Not on the map." in `.callout` `ink.secondary`.
- A choice in the list or on the map writes `place.choose(.place(id))` or clears the trail. Without a connection the tiles are blank and the pins and the list still work; nothing is built for it.

- [ ] **Step 1: Write the failing test.**

```swift
@Test func theMapAndTheListChooseEachOther() throws {
    let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
    var selection = PlacesSelection()
    selection.choose(place: 218, in: places)                               // Bethlehem, in the list
    #expect(selection.pinID == places.pin(holding: 218)?.id && selection.gathered(in: places) == nil)
    selection.choose(pin: "31.777,35.235", in: places)                     // the gathered pin, on the map
    #expect(selection.placeID == nil && selection.gathered(in: places)?.map(\.name) == ["Jerusalem", "Zion"])
    selection.choose(place: 1263, in: places)                              // Zion, from the pin's places
    #expect(selection.pinID == "31.777,35.235" && selection.placeID == 1263 && selection.gathered(in: places) == nil)
    selection.choose(place: 574, in: places)                               // not on the map
    #expect(selection.placeID == 574 && selection.pinID == nil)
    selection.choose(pin: places.pin(holding: 882)?.id, in: places)        // a pin of one place
    #expect(selection.placeID == 882)
    selection.choose(pin: nil, in: places)                                 // a click on the map itself
    #expect(selection.placeID == nil && selection.pinID == nil)
}
```

- [ ] **Step 2: Run.** `--filter PlacesSelectionTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** Both suites pass; both Debug builds succeed.
- [ ] **Step 5: See it.** Render Places in Matthew (the fixture) with Bethlehem chosen, with the gathered pin chosen, and with "Holy place" chosen; a whole-Bible page for Jerusalem; a book with no place; light, dark and Sepia. The map's area will be blank or untiled in a render: say so, and name what only a live window shows (the framing, the markers, the camera's move, a tap on a marker).
- [ ] **Step 6: Commit.** `feat: Places for a book on the Mac: Apple's map with gathered pins and its list (library 6.3)`

---

### Task 9: People, Places and About on the iPhone, and the way back (spec 6.1 iPhone, 6.7 iPhone)

**Run:** Opus (navigation, a sheet over a map, the edge swipes). The simulator at the default text size, and `TestWindow` renders at a large one. One look by the controller in the simulator; Matt tries it on his phone in Task 11. A render cannot show the system's back swipe inside Library, the sheet's detents, or Library sliding with a page pushed.

**Files:**
- Create: `PH/PhoneLibraryPages.swift`, `PH/PhonePlacesScreen.swift`
- Modify: `PH/PhoneLibraryScreen.swift`, `PH/PhoneEdgeSwipes.swift` (`PhoneLibraryLayer`, `:26-38`), `PH/PhoneShellModel.swift`, `PH/PhoneReaderScreen.swift` (`:607-617`), `SUI/LibraryList.swift`
- Test: `T/PhoneShellModelTests.swift`, `T/LibraryListTests.swift` (both suites)

**Interfaces:**
- Consumes: Tasks 7 and 8's page views (with `onShow`), `PlacesMapView`, `PlacesSelection`; `LibraryPlace`, `libraryReturn`, `lookupBackTitle`, `lookUpFromLibrary` (Task 5).
- Produces:

```swift
public enum PhoneLibraryPage: Hashable, Sendable {
    case topic(book: String, LibraryTopic), entity(book: String?, LibraryEntity), passage(Reference)
}
extension LibraryPlace {
    public var pages: [PhoneLibraryPage] { get }                     // a book's topic page, then a page to each of the trail; the whole Bible has no topic page
    public init?(pages: [PhoneLibraryPage])                          // a passage is not part of the place; nil for no page
}
// PhoneShellModel
public var searchPath: [PhoneLibraryPage] = []                       // Task 10 fills it
/// The bar's way back from a lookup. One begun in the Library reopens it there: Library on its page, or Search for a page reached by name.
public func returnFromLookup(_ navigation: NavigationModel)
// LibraryList.init gains `opening: String? = nil`: the book to open in place of the one being read.
#if os(iOS)
/// One Library page, for Library's stack and for Search's; `path` is the stack it is pushed on.
public struct PhoneLibraryPageView: View {
    public init(page: PhoneLibraryPage, navigation: NavigationModel, shell: PhoneShellModel, path: Binding<[PhoneLibraryPage]>)
}
#endif
```

- **Library's stack** takes a path that starts as `navigation.libraryPlace?.pages ?? []`; each change writes `LibraryPlace(pages:)` back to `navigation.libraryPlace`. The list opens on the place's book when it has one. Closing Library by Close, a chosen chapter or a swipe sets `navigation.libraryPlace` to nil; a lookup's Open leaves it.
- **The icons** push `.topic(book:, …)` for one of the 66.
- **The pages:** People is plain rows (the name in `.body`, the label in `.caption` `ink.secondary`, the count trailing; `lg` at the sides, `sm` up and down, a `Divider` between) under the inline title "People in John"; a row pushes the person. A person is `PersonPageView` with `onShow` pushing `.passage` and `onWalk` pushing the next. About is `LibraryAboutView`. A passage is `VersePreviewView(preview:openTitle: "Open in Read")`, or the missing line, as `PhoneNoteSheet.swift:208-224` pushes one. Every page takes `.containerBackground(Color.paperPage, for: .navigation)` and an inline title, the notice at its head (its Settings is `shell.openGeneralSettings()`) and the credit at its foot.
- **Open in Read** is `navigation.lookUpFromLibrary(reference, from: place.opening(reference))`, the place made from the path, then `shell.showInReader()`.
- **Places** (`PhonePlacesScreen`): the map fills the page. Its list is a sheet over it at `.fraction(0.25)`, `.medium` and `.large`, starting at `.medium`, on `paper.page`, not dismissable, with the map still live behind it up to `.medium`. The sheet is a stack of its own: the list ("Not on the map" as a header); a row chooses the place on the map and pushes its page; a gathered pin tapped on the map shows its places. A place's page and its passages are pushed inside the sheet, and its trail is the place's. The sheet goes when its page is popped or Library closes.
- **If the sheet will not behave** (it outlives its page, covers the bar's back button, or fights Library's slide), stop and report. The fallback is the controller's to choose with Matt: the map at a scaled 280 pt above the list in one scrolling page.
- **The bar's leading button** during a lookup reads `navigation.lookupBackTitle` on one line, truncated at its end, and calls `shell.returnFromLookup(navigation)`: it notes the return's place, calls `navigation.returnFromLookup()`, then shows Library for a place with a book, the Search tab for the whole Bible, and nothing more otherwise.

- [ ] **Step 1: Write the failing tests.** In `PhoneShellModelTests` (`navigation` reads the fixture and is reading Matthew 1):

```swift
@Test func aPlaceIsItsPagesAndBack() {
    let place = LibraryPlace(book: "MAT", topic: .people, trail: [.person(994), .person(903)])
    #expect(place.pages == [.topic(book: "MAT", .people), .entity(book: "MAT", .person(994)), .entity(book: "MAT", .person(903))])
    #expect(LibraryPlace(pages: place.pages + [.passage(ref("MAT", 1, 6))]) == place && LibraryPlace(pages: []) == nil)
    let byName = LibraryPlace(book: nil, topic: .places, trail: [.place(636)])
    #expect(byName.pages == [.entity(book: nil, .place(636))] && LibraryPlace(pages: byName.pages) == byName)
    #expect(LibraryPlace(pages: [.topic(book: "MAT", .about)]) == LibraryPlace(book: "MAT", topic: .about))
}

/// Spec 6.7: the way back names the Library page and reopens it there.
@Test @MainActor func theWayBackReopensTheLibraryOrSearch() throws {
    let shell = PhoneShellModel()
    let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
    navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
    shell.showInReader()
    #expect(navigation.lookupBackTitle == "David")
    shell.returnFromLookup(navigation)
    #expect(shell.isLibraryShown && navigation.libraryPlace == david && !navigation.isLookingUp)
    shell.showInReader()
    let byName = LibraryPlace(book: nil, topic: .people, trail: [.person(905)])
    shell.searchPath = byName.pages
    navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: byName)
    shell.returnFromLookup(navigation)
    #expect(shell.tab == .search && !shell.isLibraryShown && shell.searchPath == byName.pages)
    shell.tab = .read
    navigation.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 1)      // any other lookup
    shell.returnFromLookup(navigation)
    #expect(shell.tab == .read && !shell.isLibraryShown && navigation.location?.chapter == 1)
}
```

  In `LibraryListTests`: reading Matthew, `LibraryList(books:current:opening: "PSA")` shows the Old Testament with Psalms open and Matthew still the reading book.

- [ ] **Step 2: Run.** `--filter PhoneShellModelTests` FAILS to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** The iOS suite and the package suite pass; both Debug builds succeed.
- [ ] **Step 5: See it in the simulator,** at the default text size, a screenshot at each:
  - Library, John, People: the list; a person; a name in the family; the system's back button and the back swipe return a page.
  - A verse: its page; Open in Read. The bar's leading button names the person. Tap it: Library is open on that person.
  - Places in Acts: the map with the sheet at half height; a row; a gathered pin; a place's page; back out of Places and the sheet is gone.
  - About John with its events; the dates notice once; OK; open another person with dates: no notice.
  - Close Library on a People page and open it again: it opens on the list.
  - Put the dates setting and the notice's answer back as they were. Say plainly which of these could not be driven.
- [ ] **Step 6: See the large sizes** in a `TestWindow`, never by hand: People, a person with a family, About, at an accessibility text size. Open every picture.
- [ ] **Step 7: Commit.** `feat: People, Places and About on the iPhone, and a way back that reopens the Library (library 6.1, 6.7)`

---

### Task 10: People and Places by name, from search (spec 6.6)

**Run:** Opus (the palette's rows and keys, the search tab's stack). A headless render of the panel inside a taller container; the simulator for the search tab, which is the one thing the 6.6 check could not settle. One live pass by the controller on the Mac, keys only: ⌘K, "david", Return; "jerusalem"; "light" (the command is first); Tab to the People chip. Matt tries both in Task 11.

**Files:**
- Modify: `SUI/SearchResults.swift`, `SUI/PaletteItem.swift`, `SUI/SearchRanker.swift`, `SUI/NavigationModel.swift` (`ScriptureRequest` and `ScriptureAnswer` `:30-43`, `scriptureRequest` `:691-699`, `answer` `:702-714`, `showPalette` `:720-749`, `select` `:784-822`), `LIB/LibraryView.swift` (the whole Bible's pages), `PH/PhoneSearchScreen.swift` (`chipKinds` `:21-23`, `showAll` `:309-326`, `symbolName` `:360-372`, `choose` `:386-390`), `PH/PhoneRootView.swift` (`:87-97`), `PH/PhoneLibraryPages.swift`
- Test: `T/SearchRankerTests.swift`, `T/NavigationModelTests.swift` (both suites)

**Interfaces:**
- Consumes: `searchPeople`, `searchPlaces`, `NameMatches` (Task 2); `showInLibrary` (Task 5); `PhoneLibraryPageView`, `searchPath` (Task 9).
- Produces:

```swift
// SearchGroupKind gains `people`, `places`. SearchChip gains `people` ("People") and `places` ("Places"), after
// `passages`, each showing its own group; `SearchChip.phone` gains both.
// SearchLimits gains `people`, `places`: 4 and 4 in `.palette`, 6 and 6 in `.phone`, 30 and 30 in `.paletteChip`.
// PaletteItem gains `.person(PersonSummary)` and `.place(PlaceSummary)`.
// SearchRanker.results gains `people: NameMatches<PersonSummary> = .none, places: NameMatches<PlaceSummary> = .none`.
// ScriptureRequest gains `peopleLimit`, `placesLimit`; ScriptureAnswer gains `people`, `places` (both `.none` by default).
```

- **A row.** A person: id "person:994"; the title is the name; the subtitle is the label, then "35 verses" ("1 verse"), joined by " · "; symbol `person`. A place: id "place:636"; the subtitle is its kind, its label and its verses; symbol `mappin`. Return's verb is "Open". Neither shows the reader when chosen on the phone. The label shows whenever the record has one, which is whenever the name is shared.
- **The groups** are titled "People" and "Places", placed after Commands and before the reader's notes, in a passage query and in a word query alike; `totalCount` is the store's total. The phone's header symbols are `person.2` and `map`.
- **The read** rides with Scripture's: `answer(to:from:)` also asks `searchPeople` and `searchPlaces` with the request's limits.
- **Choosing** (the Mac): `showInLibrary(LibraryPlace(book: nil, topic: .people, trail: [.person(id)]))`, or `.places` and `.place(id)`; the palette closes as for any row. `LibraryView` shows the page alone for a place with no book: the name as its title, no list, "Contents" as its way back.
- **The phone:** the search tab's stack takes `shell.searchPath`; a person or place row appends `.entity(book: nil, …)` and `navigation.select` is not called for it; the page is `PhoneLibraryPageView`, its family and same-spot names pushing further whole-Bible pages, its Open in Read as Task 9's. A place's page there has the map at a scaled 280 pt above it. Show all lifts `people` or `places` to the group's total.
- **If the pushed page will not behave** in the search tab (the field covers its title, or on the way back the keyboard rises over it), stop and report. The fallback is the controller's to choose with Matt: the page as a `.large` sheet over Search.

- [ ] **Step 1: Write the failing tests.** In `SearchRankerTests` (`books` as the suite has them):

```swift
@Test func peopleAndPlacesAreTwoGroupsAfterCommandsWithTheirChips() {
    let david = PersonSummary(id: 994, name: "David", label: nil, verseCount: 896)
    let joseph = PersonSummary(id: 1715, name: "Joseph", label: "Mary's Husband", verseCount: 15)
    let ramah = PlaceSummary(id: 978, name: "Ramah", label: "Matthew 2:18", kind: "city", latitude: 31.896, longitude: 35.201,
                             point: "31.896,35.201", isApproximate: true, verseCount: 1)
    let results = SearchRanker.results(
        query: "light", books: books, translations: [], activeTranslationID: "WEB", verses: [], verseTotal: 0, marks: [],
        commands: [lightAppearance], people: NameMatches(rows: [david, joseph], total: 9), places: NameMatches(rows: [ramah], total: 1), limits: .palette)
    #expect(results.groups.map(\.kind) == [.commands, .people, .places])                    // a command typed by name stays first
    #expect(results.groups[1].title == "People" && results.groups[1].totalCount == 9 && results.chips().contains(.people) && results.count(of: .places) == 1)
    #expect(results.showing(.people).flatItems == [.person(david), .person(joseph)])
    #expect(PaletteItem.person(joseph).subtitle == "Mary's Husband · 15 verses" && PaletteItem.person(david).subtitle == "896 verses")
    #expect(PaletteItem.place(ramah).subtitle == "city · Matthew 2:18 · 1 verse" && PaletteItem.place(ramah).returnVerb == "Open")
    #expect(PaletteItem.person(david).id == "person:994" && !PaletteItem.person(david).showsReaderWhenChosen)
    #expect(SearchLimits.palette.people == 4 && SearchLimits.palette.places == 4 && SearchLimits.paletteChip.people == 30 && SearchChip.phone.contains(.places))
}
```

  (`lightAppearance` is the Light appearance's `PaletteCommand`.) In `NavigationModelTests`:

```swift
/// Spec 6.6: a name, or an "also called", finds its person, and choosing them opens their page for the whole Bible.
@Test func aNameTypedFindsItsPersonAndChoosingThemOpensTheirPage() throws {
    let (model, _) = try readingMatthewOne()
    model.isPaletteShown = true
    model.paletteQuery = "isr"                                           // the patriarch's other name
    model.updatePalette()
    let people = try #require(model.paletteResults.groups.first { $0.kind == .people })
    #expect(people.items == [.person(PersonSummary(id: 682, name: "Jacob", label: "Israel", verseCount: 2))])
    model.select(people.items[0])
    #expect(model.screen == .frontPage && model.libraryPlace == LibraryPlace(book: nil, topic: .people, trail: [.person(682)]) && !model.isPaletteShown)
    model.isPaletteShown = true
    model.paletteQuery = "jac"                                           // a shared name, each told apart
    model.updatePalette()
    #expect(model.paletteResults.groups.first { $0.kind == .people }?.items.compactMap(\.subtitle) == ["Israel · 2 verses", "father of Joseph · 2 verses"])
    model.paletteQuery = "sal"                                           // a place, by an alias
    model.updatePalette()
    let places = try #require(model.paletteResults.groups.first { $0.kind == .places })
    #expect(places.items.map(\.id) == ["place:636"] && places.items[0].subtitle == "city · 5 verses")
    model.select(places.items[0])
    #expect(model.libraryPlace == LibraryPlace(book: nil, topic: .places, trail: [.place(636)]))
    #expect(PaletteCommand.all.count == 32)                              // no command is added
}
```

- [ ] **Step 2: Run.** The two filters FAIL to compile.
- [ ] **Step 3: Build.**
- [ ] **Step 4: Run.** Both suites pass, every earlier search test among them (a test that builds a `ScriptureAnswer` or a `SearchLimits` by hand takes the new fields); both Debug builds succeed.
- [ ] **Step 5: See it.** Render the panel inside a taller container with "jo" typed against the real database (Books, then People with four rows and its count, then Places), with the People chip chosen, and in dark and Sepia: the list hugs its rows and the foot reads "↩ Open". In the simulator, at the default text size: search "david"; the People group and its chip; tap David: his page is pushed; note where the field is; walk to Jesse; tap a verse; Open in Read; the bar's leading button names Jesse; tap it: Search shows with Jesse's page still there and the keyboard down. Search "jerusalem": the place's page with its map. Say plainly what happened at each, and stop if the push misbehaves.
- [ ] **Step 6: Commit.** `feat: people and places by name in ⌘K and the iPhone's search (library 6.6)`

---

### Task 11: Docs and whole-project verification

**Run:** Sonnet writes the documents and runs the suites. The controller makes the live passes, restarts the Mac Debug app and installs the phone's. Matt looks at the contents page, the map and a person's page in both apps before the project is called done.

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, `docs/superpowers/specs/2026-11-16-milestone-10-library-design.md` (section 12), `docs/BACKLOG.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (the milestone 10 box, `:237`), `docs/superpowers/specs/2026-11-17-milestone-10-handover.md` (the table and a "Project 4's open ends")

**Interfaces:**
- Consumes: everything above, and each task's report.
- Produces: the documents in step with the code; a branch ready for Matt's list.

- [ ] **Step 1: `DESIGN.md`.** Section 2: the ring's colour rule (the hue at L 0.55 light and 0.68 dark, 3:1 on the page, the panel and the wash; the colourless ring is `ink.tertiary`), and in The One Saturated Voice Rule the Library's cells as the marks' second home. Section 3: the Chapter numerals entry (the pane's size). Section 5: Front page rewritten as the contents page and the pane (`:347`), Chapter grid with rings in place of the dot (`:350`), the Library reference icons with three now available (`:377`), new entries for People, Places, About, the family's generations, the dates notice and footnote, the group label, and the credit line; ⌘K's two new groups (`:372`); Motion loses "Shelf to a chosen book" (`:397`); the inventory gains `person` and `mappin` (`:383`). Section 6: a Don't for a card over the map. Section 7: Library's group headers and pushed pages (`:446`), the Places sheet among the sheets (`:445`), Search's two chips.
- [ ] **Step 2: `DESIGN.json`.** The same facts where the file holds them. `python3 -I -m json.tool DESIGN.json` prints it without error.
- [ ] **Step 3: `README.md`.** The Library (the contents page, People, Places, About, dates); the keyboard (the contents' arrows, ⌘F, Esc); Building: `Scripts/fetch-theographic.sh`, its cache, its commit and digests; the Acknowledgements line, if Task 3 has not left it right.
- [ ] **Step 4: The spec's section 12, As built.** Task by task, with:
  - Task 1's figures (the counts, the database's size before and after, the warnings), and "The data, measured" in short, with what the data contradicts: the seventy are 28 m from Jerusalem's own record; one Easton item to each record, carried in the tables fetched.
  - The front page's two figures, today's and the new one, beside the 100 ms target; Task 2's benchmark.
  - The four departures, and every decision under "Decided here", each with what it costs if wrong.
  - The 6.6 and 6.7 check: its two readings, the three behaviours that follow from a chapters-only history, and how the search tab's push and the Places sheet behaved in the simulator.
  - The known limits: the data's "also called" lists, explicit mentions only, Israel the nation tagged to Jacob, 27 books with no event, the CPDV's Psalms, the colourless ring under 3:1, what is not kept on coming back.
  - The new test counts, and anything a step could not see or drive.
- [ ] **Step 5: `docs/BACKLOG.md`,** under "The Library and study data": Paul's journeys and routes stay (wanted); **share-alike:** before the app is ever given to anyone else, the converted tables must be offered under CC BY-SA 4.0, beside the licensing item (`grep -n -i "licens\|release" docs/BACKLOG.md`; add the item if the list has none); Easton's own references as links; a person or place in Recent; the map's zoom and the scroll offset kept on coming back; re-pinning Theographic to a later commit; and anything a task set aside.
- [ ] **Step 6: The main spec's milestone 10 box** for project 4, ticked with one line; the handover's table row and "Project 4's open ends" (what was built, what was seen by whom, what nobody has seen, "For project 5, which reads this code").
- [ ] **Step 7: Run everything, one after another.** The package suite; the iOS suite; the Mac Debug build; the iOS Debug build. All pass and both builds succeed. Record the test counts.
- [ ] **Step 8: Commit.** `docs: the Library as built; DESIGN and README in step`
- [ ] **Step 9 (the controller): the live passes.** Restart the Mac Debug app (`pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`, then `open` it; never `pkill -x`) and tell Matt. Keys only, with the Debug app frontmost: the contents page, a book's People and About, Places, ⌘K by name, Back from a passage. Then, on Matt's word, `Scripts/install-phone.sh debug` (the phone unlocked, ProtonVPN off).
- [ ] **Step 10: Hand Matt his list** (spec 11, "For Matt"), unchanged, with what this session could not check beside each item, and first the three he must see: the contents page (at the default and a large text size; light, dark and Sepia), the map, and a person's page with its popover, Open and Back.

---

## Where each spec requirement is pinned

| Spec | Pinned by |
|---|---|
| 4.1: two halves, groups, the Apocrypha third; columns | Task 2 `everyBookIsInExactlyOneGroupInCanonOrder`; Task 6 `thePageOpensOnTheBookBeingReadAndAClickChooses`, `fourColumnsAreTheMockupsAndFewerStackTheTestaments` |
| 4.1 **(call)**: the dot, "Marked"; click chooses, double-click opens | Task 6 `…AClickChooses` (`target(opening:)`), Steps 4 and 6; the live pass and Matt (the double-click) |
| 4.2: the pane | Task 6 Step 6; Departure 2 |
| 4.3 **(call)**: the toolbar's field, dimming, the ringed chapter, Return, no match | Task 6 `typingDimsAndChoosesAndAReferenceRingsItsChapter`; the live pass (⌘F, Return) |
| 4.4: Tab, the arrows, Return; ⇧⌘H; VoiceOver | Task 6 `theArrowsWalkDownAColumnAndAcrossColumns`; Task 5 `readingOnOrReadFromHereEndsALibraryLookup` (a plain Home); the live pass |
| 4.5 **(call)**: the iPhone's group headers | Task 4's `LibraryListTests` lines, Step 5 |
| 5: segments, six at most, colourless, 1.5 pt, every translation's marks, "Marked" | Task 4 `oneColourIsAWholeRingAndSeveralShareItEqually`, `aDeletedColourCountsAsNoColour`, the `MarkupStoreTests` lines |
| 5: the ring's colour at 3:1 | Task 4 `aChaptersRingHoldsThreeToOneOnEverySurface`; Departure 3 |
| 6: three icons available for the 66; the Apocrypha's words | Task 7's icons rule, Step 5; Task 2 `hasLibraryData` |
| 6.1: where they open; a reference shows the passage with the view unchanged | Task 7 `aReferenceTheTranslationLacksSaysSoAndOffersNoOpen`, Step 5; Task 9 Step 5 |
| 6.2: the list, counts, a shared name **(call)** | Task 2 `aBooksPeopleComeMostVersesFirstWithTheirCounts`, `aSharedNameInTheListIsToldApartAndOnlyThere`; Task 1 `twoOfOneNameAreToldApartEvenWhenTheirLabelsMatch` |
| 6.2: a person, family, In John, Elsewhere; the way back to the previous person | Task 2 `aPersonsPageHasFamilyByGenerationAndVersesHereAndElsewhere`; Task 5 `thePlaceWalksAndStepsBackAndForgetsThePagesOwnState` |
| 6.2 **(call)**: the data's limits shown as they are | no rule to pin; As built |
| 6.3: pins, gathered **(call)**, the list, Not on the map, a place, approximate | Task 2 `placesGatherAtOneSpotAndTheUnlocatedSitApart`, `placesAndEventsReadForABook`; Task 8 `theMapAndTheListChooseEachOther`; Matt (the map) |
| 6.4: facts, writers **(call)**, When, events; no dictionary entry **(call)** | Task 2 `aboutABookGivesItsFactsWritersAndEventsInOrder` |
| 6.5: the setting, on by default, synced; off removes every year; the notice once; the footnote | Task 3's two tests and the `PreferenceSyncTests` lines; Task 2's `showingDates: false` lines |
| 6.5: a year's wording; birth and death only | Task 2 `yearsReadAsTheSpecWritesThem`; Task 1 `yearsNamesTextAndPointsReadAsTheTablesWriteThem` (no `minYear` is read) |
| 6.6: two groups, names and "also called", the rows, four in ⌘K, chips | Task 2 `namesAreFoundByTheStartOfAWordAndNothingElse`; Task 10's two tests |
| 6.6: the whole-Bible page; where it opens on each app | Task 2 (`inBook: nil`); Task 5 `aPersonByNameShowsOnTheFrontPage`; Task 10 Step 5 |
| 6.7: Back and Home return to the same book, view and person or place | Task 5 `openFromTheLibraryReturnsToTheSamePerson` |
| 6.7: the iPhone's way back | Task 9 `theWayBackReopensTheLibraryOrSearch`, Step 5 |
| 6.7: reading on ends it; nothing being read; quitting | Task 5 `readingOnOrReadFromHereEndsALibraryLookup`, `withNothingBeingReadOpenIsALookupThatLeavesNoPlace`, `quittingOrChangingTranslationLeavesNoStaleLibrary` |
| 7: source, pinned commit, digests, cache; schema 5, an older database rebuilt | Task 1 Steps 6 and 7, `theFixtureLibraryLandsAtSchemaFive`, `theBuildScriptsPatternReadsTheSchemaVersion`, the existing `schemaMismatchThrows` |
| 7: ids as keys; KJV numbering; size | Task 1 `theFixturePeopleLandByTheirOwnIds`, `theFixtureLibraryLandsAtSchemaFive`; Step 7 |
| 7: the credit in About and at each view's foot; share-alike | Task 3's `CreditsTests` lines; Tasks 7 to 9's foot; Task 11 Step 5 |
| 8: the design documents | Task 11 Steps 1 and 2 |
| 9: no stored note or iCloud change; two synced keys | Task 3 `theSyncedKeysAreExactlyThese`; Global Constraints |
| 11: the benchmark | Task 6 Steps 1 and 5 |
