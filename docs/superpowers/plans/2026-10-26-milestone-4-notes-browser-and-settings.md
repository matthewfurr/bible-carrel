# Milestone 4: Notes Browser and Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A separate Notes window listing every note, highlight and bookmark across the Bible (sort, filter, search, navigate, delete), a Settings window with General, Reading and Markup tabs whose changes apply live, and ⌘K palette entries for notes plus "Open Notes Browser" and "Open Settings".

**Architecture:** `MarkupStore` (SwiftData, `ScriptureModel`) gains whole-Bible fetches and a search that combines a `#Predicate` over `body`/`quotedText` with in-memory reference matching. `ScriptureUI` gets value types (`NotesBrowserEntry`, `MarkupTarget`, `ReaderSettings`) with pure, tested filter/sort/search/mapping functions, an `@Observable` `NotesBrowserModel`, and the SwiftUI views. The app target wires a second `Window` scene, the Settings tabs, the View menu item and the palette commands; navigation from the browser or the palette into the reader goes through one `MarkupNavigation.show` so the card lights and the highlight outlines exactly as a card click does.

**Tech Stack:** Swift 6 language mode, SwiftUI, SwiftData, Swift Testing, SF Symbols. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (Markup section, UI section, milestone 4). Brief with scope and verification rules: side-session note `milestone-4-notes-browser-and-settings.md`; UI rules from milestone 3 rounds one to seven in `milestone-3-markup.md` beside it.

## Global Constraints

- Native Swift/SwiftUI, minimum macOS 26, Swift 6 language mode, Swift Testing, SF Symbols only, Apple HIG conventions. GRDB stays the only third-party dependency.
- No SwiftData schema change. Settings live in `UserDefaults` under keys consistent with `showNotelessHighlights`, `finishEditingWithReturn`, `showNotesColumn`, `readingPosition`.
- The Notes browser and Settings must not change reader, column or editor behaviour (milestone 3 round six freeze list). Existing public signatures stay; additions only.
- Chat threads join the browser in milestone 5: `NotesBrowserEntry.Kind` and `NotesBrowserFilter` leave the seam as a comment, no stub UI.
- Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (187 pass on main). Build: README xcodebuild line with `-derivedDataPath Build/DerivedData` inside the worktree.
- Every UI change is verified in the running app (screencapture, System Events tree, CGEvent clicks) before it is reported. Matt's store is never modified; browser tests use the in-memory container.
- Commits as each task completes, ending with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. A note whose highlight was made in a translation not bundled or no longer available: navigating must still open the chapter in the current translation rather than do nothing (Task 7 test `unavailableTranslationFallsBackToTheCurrentOne`).
2. A search query that parses as a reference ("Matt 5", "ps 23:1") must match items by book/chapter/verse, not only by display-string substring (Task 1 test `referenceQueryMatchesByBookChapterAndVerse`).
3. Deleting the browser's selected entry while the same chapter is open in the reader must refresh the column and the decorations (Task 6: `NotesBrowserModel.onChange` reloads `MarkupModel`; test `deletingAnEntryReloadsTheListAndNotifies`).
4. Font size persisted outside 14–24 (hand-edited defaults, older build) must clamp instead of producing an unreadable reader (Task 8 test `fontSizeIsClampedToTheRange`).
5. A stored default translation that is not bundled must fall back to ESV, then to whatever is bundled (already covered by `NavigationModel.init`; Task 8 test `unknownDefaultTranslationFallsBack` pins it through `ReaderSettings`).

---

## File Structure

**ScriptureModel (modify/create)**
- `Sources/ScriptureModel/MarkupStore.swift` (modify): whole-Bible fetches, lookups by uuid, `deleteBookmark`, `search(_:)`.
- `Sources/ScriptureModel/MarkupSearch.swift` (create): `MarkupReferenceText.string(...)` and `MarkupSearch.matchesReference(...)`, pure.
- `Tests/ScriptureModelTests/MarkupSearchTests.swift` (create), `MarkupStoreTests.swift` (modify).

**ScriptureUI (create)**
- `Sources/ScriptureUI/NotesBrowserEntry.swift`: `NotesBrowserEntry`, `NotesBrowserSort`, `NotesBrowserFilter`, `NotesBrowserSection`, `NotesBrowserQuery` (pure filter/sort/group).
- `Sources/ScriptureUI/MarkupTarget.swift`: `MarkupTarget` and `MarkupNavigation.show`.
- `Sources/ScriptureUI/NotesBrowserModel.swift`: loads entries from the store, applies filter/sort/search, deletes, produces palette hits.
- `Sources/ScriptureUI/NotesBrowserView.swift`, `NotesBrowserRow.swift`: the window content.
- `Sources/ScriptureUI/ReaderSettings.swift`: keys, `LineSpacingChoice`, `AppearanceChoice`, `ReaderTypography.make(fontSize:lineSpacing:)`.
- `Sources/ScriptureUI/GeneralSettingsView.swift`, `ReadingSettingsView.swift`.
- Tests: `NotesBrowserQueryTests.swift`, `NotesBrowserModelTests.swift`, `MarkupNavigationTests.swift`, `ReaderSettingsTests.swift`.

**ScriptureUI (modify)**
- `PaletteItem.swift`, `PaletteRanker.swift`: `.note(PaletteNoteHit)` and `.command(PaletteCommand)`.
- `NavigationModel.swift`: `open(_:verse:translationID:)`, `noteSearch`, `showTarget`, `performCommand`.
- `MarkupModel.swift`: `focusWhenLoaded(_:)`.
- `NotesColumnItem.swift`: `MarkupReference.string` forwards to `MarkupReferenceText.string`.

**App (modify)**
- `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`: Notes `Window` scene, View menu item, Settings tabs wiring, palette command handler, default translation from settings.
- `MainWindowView.swift`: toolbar `note.text` button, typography from settings, appearance.
- `SettingsView.swift`: three tabs.
- `README.md`: Notes browser, Settings and shortcuts.

---

### Task 1: Reference text and reference matching (ScriptureModel)

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/MarkupSearch.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/NotesColumnItem.swift` (the internal `MarkupReference.string` body becomes a call to `MarkupReferenceText.string`)
- Test: `Packages/ScriptureKit/Tests/ScriptureModelTests/MarkupSearchTests.swift`

**Interfaces:**
- Produces:
  - `public enum MarkupReferenceText { public static func string(book: String, chapter: Int, verse: Int?, endVerse: Int?) -> String }` — `"Matthew 5:3"`, `"Matthew 5:3-4"`, `"Matthew 5"` when `verse` is nil, `"Psalm 23:1"` (chapter name singular), unknown code echoes the code.
  - `public enum MarkupSearch { public static func matchesReference(_ query: String, book: String, chapter: Int, verse: Int, endVerse: Int) -> Bool }` — true when the lowercased display string contains the lowercased trimmed query, or when `ReferenceParser.parse(query)` yields a reference whose book id matches and whose chapter (if given) equals `chapter` and whose verse (if given) lies in `verse...endVerse` (a parsed range `v-w` matches when it overlaps). Empty query is false.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct MarkupSearchTests {
    @Test func referenceStringsMatchTheColumn() {
        #expect(MarkupReferenceText.string(book: "MAT", chapter: 5, verse: 3, endVerse: 3) == "Matthew 5:3")
        #expect(MarkupReferenceText.string(book: "MAT", chapter: 5, verse: 3, endVerse: 4) == "Matthew 5:3-4")
        #expect(MarkupReferenceText.string(book: "MAT", chapter: 5, verse: nil, endVerse: nil) == "Matthew 5")
        #expect(MarkupReferenceText.string(book: "PSA", chapter: 23, verse: 1, endVerse: 1) == "Psalm 23:1")
        #expect(MarkupReferenceText.string(book: "XYZ", chapter: 1, verse: 1, endVerse: 1) == "XYZ 1:1")
    }
    @Test func substringMatchesTheDisplayString() {
        #expect(MarkupSearch.matchesReference("thew 5:3", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(!MarkupSearch.matchesReference("Mark", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(!MarkupSearch.matchesReference("  ", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
    }
    @Test func referenceQueryMatchesByBookChapterAndVerse() {
        #expect(MarkupSearch.matchesReference("Matt", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(MarkupSearch.matchesReference("matt 5", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(!MarkupSearch.matchesReference("matt 6", book: "MAT", chapter: 5, verse: 3, endVerse: 3))
        #expect(MarkupSearch.matchesReference("Mt 5:4", book: "MAT", chapter: 5, verse: 3, endVerse: 5))
        #expect(!MarkupSearch.matchesReference("Mt 5:9", book: "MAT", chapter: 5, verse: 3, endVerse: 5))
        #expect(MarkupSearch.matchesReference("Mt 5:1-3", book: "MAT", chapter: 5, verse: 3, endVerse: 5))
        #expect(MarkupSearch.matchesReference("ps 23", book: "PSA", chapter: 23, verse: 1, endVerse: 1))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter MarkupSearchTests`
Expected: compile failure, `MarkupReferenceText` not found.

- [ ] **Step 3: Implement `MarkupSearch.swift`** with the two enums above; `MarkupReferenceText.string` reuses `Reference(book:chapter:verse:endVerse:).displayString` with `endVerse` dropped when equal to `verse`, falling back to `Book(id: code, canon: .oldTestament, order: 0, name: code, shortName: code)` for an unknown code. Make `MarkupReference.string` in `NotesColumnItem.swift` return `MarkupReferenceText.string(...)`.

- [ ] **Step 4: Run the whole suite**

Run: the full `swift test` line. Expected: 187 + 3 pass.

- [ ] **Step 5: Commit** — `feat: reference text and reference matching for markup search`

---

### Task 2: Whole-Bible queries and search on `MarkupStore`

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureModel/MarkupStore.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureModelTests/MarkupStoreTests.swift`

**Interfaces:**
- Produces, all `@MainActor` on `MarkupStore`:
  - `public func allHighlights() throws -> [Highlight]`, `public func allNotes() throws -> [Note]`, `public func allBookmarks() throws -> [Bookmark]` — unsorted fetches (callers sort).
  - `public func highlight(id: UUID) throws -> Highlight?`, `public func note(id: UUID) throws -> Note?`, `public func bookmark(id: UUID) throws -> Bookmark?`.
  - `public func deleteBookmark(_ bookmark: Bookmark) throws`.
  - `public struct MarkupSearchResults: Sendable-free value { public var notes: [Note]; public var highlights: [Highlight]; public var bookmarks: [Bookmark] }` (plain struct, no `Sendable`; models are main-actor objects).
  - `public func search(_ query: String) throws -> MarkupSearchResults` — trimmed empty query returns everything. Otherwise: notes = predicate `body.localizedStandardContains(q) || quotedText.localizedStandardContains(q)` unioned (by uuid) with every note whose reference matches via `MarkupSearch.matchesReference`; highlights = predicate on `quotedText` unioned with reference matches, excluding none (a highlight with a matching note is still a highlight hit; the browser dedupes by showing a noted highlight as its note); bookmarks = reference matches only (`verse == endVerse`).

- [ ] **Step 1: Write the failing tests** (append to `MarkupStoreTests`)

```swift
@Test func wholeBibleQueriesSpanChapters() throws {
    let store = try makeStore()
    let yellow = try store.colors()[0].uuid
    _ = try add(store, verse: 3, color: yellow)
    _ = try store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 2, translationID: "KJV", colorID: yellow, quotedText: "In")
    try store.toggleBookmark(at: VerseLocation(book: "JHN", chapter: 3, verse: 16))
    #expect(try store.allHighlights().count == 2)
    #expect(try store.allBookmarks().map(\.book) == ["JHN"])
    let bookmark = try store.allBookmarks()[0]
    #expect(try store.bookmark(id: bookmark.uuid)?.verse == 16)
    try store.deleteBookmark(bookmark)
    #expect(try store.allBookmarks().isEmpty)
}

@Test func searchHitsBodyQuotedTextAndReference() throws {
    let store = try makeStore()
    let a = try store.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed are the poor")
    try store.addNote(to: a, body: "The **Beatitudes** begin here.")
    let b = try store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 2, translationID: "KJV", colorID: try store.colors()[0].uuid, quotedText: "In the beginning")
    try store.toggleBookmark(at: VerseLocation(book: "JHN", chapter: 3, verse: 16))

    let byBody = try store.search("beatitudes")
    #expect(byBody.notes.map(\.uuid) == [a.note!.uuid] && byBody.highlights.isEmpty && byBody.bookmarks.isEmpty)
    let byQuote = try store.search("BEGINNING")
    #expect(byQuote.highlights.map(\.uuid) == [b.uuid] && byQuote.notes.isEmpty)
    let byReference = try store.search("John 3")
    #expect(byReference.bookmarks.count == 1 && byReference.notes.isEmpty && byReference.highlights.isEmpty)
    let byBookName = try store.search("Matthew 5:3")
    #expect(byBookName.notes.count == 1 && byBookName.highlights.map(\.uuid) == [a.uuid])
    let everything = try store.search("  ")
    #expect(everything.notes.count == 1 && everything.highlights.count == 2 && everything.bookmarks.count == 1)
    #expect(try store.search("zzz").notes.isEmpty)
}
```

- [ ] **Step 2: Run to verify failure** — `--filter MarkupStoreTests`; expected compile failure on `allHighlights`.

- [ ] **Step 3: Implement** the queries in a new `// MARK: - Whole-Bible queries and search` section of `MarkupStore`. `localizedStandardContains` is supported in `#Predicate`; reference matches iterate the `all*` fetch and union by `uuid` preserving fetch order.

- [ ] **Step 4: Run the full suite** — expected all pass (187 + 5).

- [ ] **Step 5: Commit** — `feat: whole-Bible markup queries and search on MarkupStore`

---

### Task 3: `NotesBrowserEntry` and the pure query functions

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserEntry.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/NotesBrowserQueryTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct NotesBrowserEntry: Identifiable, Equatable, Sendable {
      public enum Kind: Equatable, Sendable {
          case note(noteID: UUID, highlightID: UUID?)   // highlightID nil for a chapter note
          case highlight(id: UUID)                        // noteless highlight
          case bookmark(id: UUID)
          // Milestone 5 adds `case thread(id: UUID)`; the browser's row and filter switch on this enum.
      }
      public let id: UUID            // the note's, highlight's or bookmark's uuid
      public let kind: Kind
      public let book: String        // code, e.g. "MAT"
      public let bookOrder: Int      // BookCatalog order, unknown code = Int.max
      public let chapter: Int
      public let verse: Int
      public let endVerse: Int
      public let referenceString: String
      public let translationID: String?   // nil for bookmarks
      public let color: MarkupColor?      // nil = colorless highlight, or bookmark
      public let quotedText: String
      public let body: String             // "" for noteless highlights and bookmarks
      public let modifiedAt: Date
      public init(...)                    // memberwise, public
      public var isChapterNote: Bool      // kind is .note with verse == 0
  }
  public enum NotesBrowserSort: String, CaseIterable, Sendable { case date, reference }
  public enum NotesBrowserFilter: String, CaseIterable, Sendable { case all, notes, highlights, bookmarks }   // milestone 5: threads
  public struct NotesBrowserSection: Identifiable, Equatable, Sendable { public let id: String /* book code */; public let title: String /* book name */; public let entries: [NotesBrowserEntry] }
  public enum NotesBrowserQuery {
      public static func filter(_ entries: [NotesBrowserEntry], by filter: NotesBrowserFilter) -> [NotesBrowserEntry]
      public static func sort(_ entries: [NotesBrowserEntry], by sort: NotesBrowserSort) -> [NotesBrowserEntry]
      public static func sections(_ entries: [NotesBrowserEntry]) -> [NotesBrowserSection]   // by book in canon order; entries already reference-sorted
  }
  ```
- Sort rules: `.date` = `modifiedAt` descending, ties by `referenceString`; `.reference` = `(bookOrder, chapter, verse, endVerse, modifiedAt)` ascending.
- Filter rules: `.notes` keeps `.note`; `.highlights` keeps `.highlight` **and** `.note` with a non-nil `highlightID` (a noted highlight is still a highlight); `.bookmarks` keeps `.bookmark`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct NotesBrowserQueryTests {
    private func entry(_ id: UUID = UUID(), kind: NotesBrowserEntry.Kind, book: String, chapter: Int, verse: Int, modified: TimeInterval) -> NotesBrowserEntry { /* bookOrder from BookCatalog, referenceString from MarkupReferenceText, endVerse = verse */ }
    let noteID = UUID(), hlID = UUID(), bmID = UUID()
    var mat5: NotesBrowserEntry { entry(noteID, kind: .note(noteID: noteID, highlightID: UUID()), book: "MAT", chapter: 5, verse: 3, modified: 100) }
    var gen1: NotesBrowserEntry { entry(hlID, kind: .highlight(id: hlID), book: "GEN", chapter: 1, verse: 1, modified: 300) }
    var jhn3: NotesBrowserEntry { entry(bmID, kind: .bookmark(id: bmID), book: "JHN", chapter: 3, verse: 16, modified: 200) }

    @Test func dateSortIsNewestFirst() {
        #expect(NotesBrowserQuery.sort([mat5, gen1, jhn3], by: .date).map(\.id) == [hlID, bmID, noteID])
    }
    @Test func referenceSortFollowsTheCanon() {
        #expect(NotesBrowserQuery.sort([mat5, jhn3, gen1], by: .reference).map(\.book) == ["GEN", "MAT", "JHN"])
    }
    @Test func filtersKeepTheRightKinds() {
        let all = [mat5, gen1, jhn3]
        #expect(NotesBrowserQuery.filter(all, by: .all).count == 3)
        #expect(NotesBrowserQuery.filter(all, by: .notes).map(\.id) == [noteID])
        #expect(NotesBrowserQuery.filter(all, by: .highlights).map(\.id) == [noteID, hlID])
        #expect(NotesBrowserQuery.filter(all, by: .bookmarks).map(\.id) == [bmID])
    }
    @Test func sectionsGroupByBookInCanonOrder() {
        let sections = NotesBrowserQuery.sections(NotesBrowserQuery.sort([mat5, jhn3, gen1, entry(kind: .bookmark(id: UUID()), book: "GEN", chapter: 2, verse: 1, modified: 1)], by: .reference))
        #expect(sections.map(\.title) == ["Genesis", "Matthew", "John"])
        #expect(sections[0].entries.map(\.chapter) == [1, 2])
    }
}
```

- [ ] **Step 2: Run to verify failure** — `--filter NotesBrowserQueryTests`, compile failure.
- [ ] **Step 3: Implement `NotesBrowserEntry.swift`** as specified.
- [ ] **Step 4: Run the full suite** — all pass.
- [ ] **Step 5: Commit** — `feat: NotesBrowserEntry with filter, sort and book sections`

---

### Task 4: `MarkupTarget` and reader navigation from outside the reader

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/MarkupTarget.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/NavigationModel.swift`, `Packages/ScriptureKit/Sources/ScriptureUI/MarkupModel.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/MarkupNavigationTests.swift`, `NavigationModelTests.swift`

**Interfaces:**
- Produces:
  - `public struct MarkupTarget: Equatable, Sendable { public let location: ChapterLocation; public let verse: Int; public let translationID: String?; public let highlightID: UUID?; public init(...) }` and `public init(entry: NotesBrowserEntry)` (chapter note → verse 1, highlightID nil; bookmark → translationID nil).
  - `NavigationModel.open(_ location: ChapterLocation, verse: Int?, translationID: String?)` — switches translation first when it is bundled and differs (`setTranslation`), then `open(location, verse:)`; an unknown translation is ignored.
  - `MarkupModel.focusWhenLoaded(_ target: MarkupTarget)` — when `chapter == target.location && translationID == (target.translationID ?? translationID)` and the highlight is in `items`, calls `focus(highlightID:)` now; otherwise stores it and `load(...)` consumes it after `reload()` when the loaded chapter matches (a target whose highlight is missing is dropped silently). A target without `highlightID` only clears selection.
  - `public enum MarkupNavigation { @MainActor public static func show(_ target: MarkupTarget, navigation: NavigationModel, markup: MarkupModel) }` — `navigation.open(target.location, verse: target.verse, translationID: target.translationID)` then `markup.focusWhenLoaded(target)`.

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor @Suite struct MarkupNavigationTests {
    // Fixture store has WEB and KJV with PSA, MAT, TOB (see FixtureStore / NavigationModelTests).
    private func make() throws -> (NavigationModel, MarkupModel, MarkupStore) { ... in-memory container, suite-named UserDefaults ... }

    @Test func showOpensTheChapterInTheItemsTranslationAndFocusesTheHighlight() throws {
        let (navigation, markup, store) = try make()
        let highlight = try store.addHighlight(book: "MAT", chapter: 2, verse: 2, endVerse: 2, startOffset: 0, endOffset: 3, translationID: "KJV", colorID: nil, quotedText: "And")
        try store.addNote(to: highlight, body: "x")
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 2, translationID: "KJV", highlightID: highlight.uuid)
        MarkupNavigation.show(target, navigation: navigation, markup: markup)
        #expect(navigation.translationID == "KJV" && navigation.location == ChapterLocation(book: "MAT", chapter: 2) && navigation.scrollTarget?.verse == 2)
        // The window's onChange would call load; simulate it.
        markup.load(chapter: navigation.location, translationID: navigation.translationID, verses: navigation.verses)
        #expect(markup.selectedHighlightIDs == [highlight.uuid] && markup.outlinedHighlightID == highlight.uuid)
    }
    @Test func showInTheOpenChapterFocusesAtOnce() throws { /* load MAT 2 WEB first, highlight in WEB, show → focused without a second load */ }
    @Test func unavailableTranslationFallsBackToTheCurrentOne() throws {
        /* translationID "NIV" (not bundled) → navigation.translationID stays "WEB", chapter opens */
    }
    @Test func bookmarkTargetScrollsWithoutSelecting() throws {
        /* target with highlightID nil → selectedHighlightIDs empty, scrollTarget.verse == 16 */
    }
    @Test func entryInitMapsChapterNotesToVerseOne() { /* MarkupTarget(entry:) with verse 0 → verse 1 */ }
}
```

Add to `NavigationModelTests`: `openWithTranslationSwitchesThenOpens` — `open(MAT 1, verse: 2, translationID: "KJV")` → `translationID == "KJV"`, `location == MAT 1`, `canGoBack` true after a prior open.

- [ ] **Step 2: Run to verify failure** — compile failure on `MarkupTarget`.
- [ ] **Step 3: Implement** the three pieces. In `MarkupModel`, add `private var pendingFocus: MarkupTarget?`, consume at the end of `load(...)` after `reload()`.
- [ ] **Step 4: Run the full suite** — all pass.
- [ ] **Step 5: Commit** — `feat: MarkupTarget and MarkupNavigation.show for navigating the reader to a markup item`

---

### Task 5: Palette notes and commands

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/PaletteItem.swift`, `PaletteRanker.swift`, `NavigationModel.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/PaletteRankerTests.swift`, `NavigationModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct PaletteNoteHit: Hashable, Identifiable, Sendable {
      public let id: UUID            // note uuid
      public let target: MarkupTarget
      public let referenceString: String
      public let firstLine: String   // first non-empty line of the body, markdown markers stripped by NoteMarkdown.blocks(...).first's characters, max 120 chars
      public let modifiedAt: Date
  }
  public enum PaletteCommand: String, CaseIterable, Sendable {
      case openNotesBrowser, openSettings
      public var title: String   // "Open Notes Browser", "Open Settings"
      public var symbolName: String   // "note.text", "gearshape"
  }
  // PaletteItem gains: case note(PaletteNoteHit), case command(PaletteCommand)
  // id: "note:<uuid>", "command:<rawValue>"; title: referenceString / command.title; subtitle: firstLine / nil; symbol: "note.text" / command.symbolName
  ```
  - `PaletteRanker.rank(query:books:translations:activeTranslationID:verses:notes: [PaletteNoteHit] = [], maxBooks:maxVerses:maxNotes: Int = 3)` — order: reference, books, translations, **commands whose title contains the query (case-insensitive)**, notes (first `maxNotes`, caller passes them newest first), verses.
  - `NavigationModel`: `public var noteSearch: ((String) -> [PaletteNoteHit])?` (called in `updatePalette` with the trimmed query; nil → no notes), `public var showTarget: ((MarkupTarget) -> Void)?` (used by `select(.note)`; when nil, `open(target.location, verse:, translationID:)`), `public var performCommand: ((PaletteCommand) -> Void)?` (used by `select(.command)`). `select` still dismisses the palette and clears the query for both.

- [ ] **Step 1: Write the failing tests**

```swift
// PaletteRankerTests
@Test func notesRankAfterTranslationsAndBeforeVersesAndAreCapped() {
    let hits = (1...5).map { i in PaletteNoteHit(id: UUID(), target: MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 5), verse: i, translationID: "ESV", highlightID: nil), referenceString: "Matthew 5:\(i)", firstLine: "line \(i)", modifiedAt: Date(timeIntervalSince1970: TimeInterval(i))) }
    let verse = Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: 1), translationID: "ESV", text: "Blessed", breakAfter: false)
    let items = PaletteRanker.rank(query: "blessed", books: books, translations: translations, activeTranslationID: "ESV", verses: [verse], notes: hits)
    let noteItems = items.filter { if case .note = $0 { true } else { false } }
    #expect(noteItems.count == 3 && noteItems.first?.title == "Matthew 5:1" && noteItems.first?.subtitle == "line 1")
    #expect(items.last == .verse(verse))
}
@Test func commandsMatchByTitle() {
    #expect(rank("notes").contains(.command(.openNotesBrowser)))
    #expect(rank("sett").contains(.command(.openSettings)))
    #expect(!rank("rom 8").contains(where: { if case .command = $0 { true } else { false } }))
}
// NavigationModelTests
@Test func selectingANoteHitShowsItsTargetAndClosesThePalette() throws {
    /* model.showTarget records the target; model.isPaletteShown = true; select(.note(hit)) → recorded == hit.target, isPaletteShown false, paletteQuery "" */
}
@Test func selectingACommandPerformsIt() throws { /* performCommand records .openSettings */ }
@Test func paletteIncludesNotesFromTheProvider() throws { /* noteSearch returns one hit for "x"; paletteQuery = "x"; updatePalette(); paletteItems contains .note */ }
```

- [ ] **Step 2: Run to verify failure** — compile failure on `PaletteNoteHit`.
- [ ] **Step 3: Implement**. `PaletteNoteHit.firstLine` is computed by the caller (Task 6) via `static func firstLine(of body: String) -> String` on `PaletteNoteHit`, tested: `"# Heading\n\nbody"` → `"Heading"`, `"**bold** rest"` → `"bold rest"`, `""` → `""`.
- [ ] **Step 4: Run the full suite** — all pass.
- [ ] **Step 5: Commit** — `feat: palette rows for notes and the Open Notes Browser / Open Settings commands`

---

### Task 6: `NotesBrowserModel`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserModel.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/NotesBrowserModelTests.swift`

**Interfaces:**
- Consumes: `MarkupStore.allNotes/allHighlights/allBookmarks/search/deleteNote/deleteHighlight/deleteBookmark/note(id:)/highlight(id:)/bookmark(id:)/colors`, `NotesBrowserQuery`, `MarkupTarget(entry:)`, `PaletteNoteHit`.
- Produces:
  ```swift
  @MainActor @Observable public final class NotesBrowserModel {
      public static let sortKey = "notesBrowserSort"       // UserDefaults, rawValue; default .date
      public static let filterKey = "notesBrowserFilter"   // default .all
      public var sort: NotesBrowserSort { didSet persists + rebuild }
      public var filter: NotesBrowserFilter { didSet persists + rebuild }
      public var query: String                      // bound to the search field; the view debounces and calls applySearch()
      public private(set) var entries: [NotesBrowserEntry]      // filtered, sorted, searched
      public private(set) var sections: [NotesBrowserSection]   // non-empty only when sort == .reference
      public private(set) var totalCount: Int                   // all entries before filter/search
      public var selectedID: UUID?
      public private(set) var lastError: String?
      public init(store: MarkupStore, defaults: UserDefaults = .standard, onChange: @escaping () -> Void = {})
      public func reload()                 // re-fetches everything (call on window appear and after the reader changes markup)
      public func applySearch()            // re-runs store.search(query) and rebuilds
      public func entry(id: UUID) -> NotesBrowserEntry?
      public func target(for id: UUID) -> MarkupTarget?
      public func delete(id: UUID)         // note → deleteNote (anchor goes if empty); highlight → deleteHighlight; bookmark → deleteBookmark; then reload + onChange
      public func noteHits(query: String, limit: Int = 3) -> [PaletteNoteHit]   // notes only, newest first
  }
  ```
- Entry building: a highlight **with** a note becomes one `.note` entry (the note's uuid, `highlightID` set, color from the highlight, `modifiedAt` = max(note.modifiedAt, highlight.modifiedAt)); a highlight without a note becomes `.highlight`; chapter notes (`scope == .chapter`) become `.note` with `highlightID` nil and `verse == 0`; bookmarks become `.bookmark` with `translationID` nil, `modifiedAt` = `createdAt`.
- Search results from the store are mapped the same way; a highlight hit whose note did not hit still shows as its note entry.

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor @Suite struct NotesBrowserModelTests {
    private func make() throws -> (NotesBrowserModel, MarkupStore, UserDefaults) { in-memory container + seeded colors + suite defaults }

    @Test func entriesCoverNotesHighlightsAndBookmarksNewestFirst() throws {
        /* noted highlight (MAT 5:3), noteless highlight (GEN 1:1, later), bookmark (JHN 3:16, latest)
           → entries.count == 3; kinds == [.bookmark, .highlight, .note]; totalCount == 3; sections.isEmpty */
    }
    @Test func referenceSortProducesSectionsAndPersists() throws {
        /* model.sort = .reference → sections titles ["Genesis", "Matthew", "John"]; defaults.string(forKey: sortKey) == "reference";
           a second model on the same defaults starts with sort == .reference */
    }
    @Test func filterNarrowsAndPersists() throws { /* .bookmarks → one entry; defaults filterKey == "bookmarks" */ }
    @Test func searchMatchesBodyQuoteAndReference() throws {
        /* query "beatitudes" → the note entry; "beginning" → the highlight entry; "john 3" → the bookmark; "" → all */
    }
    @Test func deletingAnEntryReloadsTheListAndNotifies() throws {
        /* onChange counter; delete(note entry) → store.allHighlights() lost the colorless anchor; entries.count 2; counter == 1;
           delete(bookmark) → store.allBookmarks().isEmpty */
    }
    @Test func targetForAnEntryCarriesTranslationAndHighlight() throws {
        /* note entry → target.translationID "ESV", highlightID == highlight uuid, verse 3; bookmark → translationID nil, highlightID nil */
    }
    @Test func noteHitsAreNotesOnlyNewestFirstAndCapped() throws { /* four notes matching "x", limit 3 → 3 hits, first is the newest, firstLine from body */ }
}
```

- [ ] **Step 2: Run to verify failure** — compile failure.
- [ ] **Step 3: Implement `NotesBrowserModel.swift`** with an `attempt { }` helper like `MarkupModel`'s and an `OSLog` logger (`category: "notes-browser"`).
- [ ] **Step 4: Run the full suite** — all pass.
- [ ] **Step 5: Commit** — `feat: NotesBrowserModel over the whole-Bible store queries`

---

### Task 7: Notes browser views and the Notes window

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserView.swift`, `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserRow.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`, `Apps/Mac/ReadingThroughScripture/MainWindowView.swift`

**Interfaces:**
- Consumes: `NotesBrowserModel`, `MarkupNavigation.show`, `NoteMarkdown.blocks`, `Color(markup:)`.
- Produces:
  - `public struct NotesBrowserView: View { public init(model: NotesBrowserModel, onShow: @escaping (MarkupTarget) -> Void) }`
  - `struct NotesBrowserRow: View { init(entry: NotesBrowserEntry) }` (internal).
  - App: `Window("Notes", id: "notes-browser")` scene (`.defaultSize(width: 720, height: 560)`), `WindowGroup` gains `id: "main"`; View menu `CommandGroup(after: .toolbar)` gains `Button("Notes Browser") { openWindow(id: "notes-browser") }.keyboardShortcut("n", modifiers: [.command, .shift])` beside the existing notes-column item; `MainWindowView` toolbar gains `Button { openWindow(id: "notes-browser") } label: { Label("Notes Browser", systemImage: "note.text") }.help("Notes Browser (⇧⌘N)")` after the `sidebar.right` button.
  - `ReadingThroughScriptureApp` owns `@State private var notesBrowser: NotesBrowserModel?`, created with `onChange: { markupModel.reload() }`; `MarkupModel` changes made in the reader are picked up because the view calls `model.reload()` on appear and on `NSApplication.didBecomeActiveNotification`-free simpler rule: `.onChange(of: markupChangeToken)` is **not** added (freeze); instead the Notes window reloads on `onAppear` and whenever it becomes key (`.onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification))` filtered to its own window via `@Environment(\.controlActiveState)` change to `.key`).
  - Showing an item: `onShow` = `{ target in MarkupNavigation.show(target, navigation: model, markup: markup); bring the main window forward }`. The main window is found as `NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main-") == true }` and `makeKeyAndOrderFront(nil)`; when none exists `openWindow(id: "main")`. The Notes window stays open.

**View rules (from the brief and milestone 3):**
- Toolbar: `Picker("Sort", selection: $model.sort)` as a menu with `arrow.up.arrow.down` label (`Date`, `Reference`); `Picker("Show", selection: $model.filter)` segmented (`All`, `Notes`, `Highlights`, `Bookmarks`); `.searchable(text: $model.query, isPresented: $isSearchPresented, placement: .toolbar, prompt: "Search notes")`; a `Button("Find") { isSearchPresented = true }.keyboardShortcut("f").hidden()` gives ⌘F.
- Debounce: `.task(id: model.query) { try? await Task.sleep(for: .milliseconds(150)); guard !Task.isCancelled else { return }; model.applySearch() }`.
- Header pinned above the list: `HStack { Text("Notes").font(.headline); Spacer(); Text("\(model.entries.count)") caption secondary }` padded 14/10 and a `Divider()`, as the column does.
- Body: `List(selection: $model.selectedID)`; when `model.sort == .reference`, `ForEach(model.sections) { Section(section.title) { rows } }`, else flat rows; `.contextMenu(forSelectionType: UUID.self) { ids in Button("Show in Reader") ; Divider(); Button("Delete…", role: .destructive) } primaryAction: { ids in show(first) }`; `.onKeyPress(.return)` shows the selection; `.onDeleteCommand { pendingDelete = selected entry }`.
- Empty state: `ContentUnavailableView("No notes yet", systemImage: "note.text", description: Text(query.isEmpty ? "Highlights, notes and bookmarks you make in the reader appear here." : "No results for “\(query)”."))` filling the space below the header. When `model.totalCount > 0` and the filter/search hides everything, title is "No matches".
- Delete confirmation: `confirmationDialog("Delete \(entry.referenceString)?", presenting: pendingDelete)` with `Button("Delete", role: .destructive)` and a message per kind: note → "The note and its highlight are deleted." when the highlight is colorless, else "The note is deleted; the highlight keeps its color."; highlight → "The highlight is deleted."; bookmark → "The bookmark is deleted."
- Row: `HStack(alignment: .top, spacing: 10)`: marker 14 pt wide (`Circle` filled with `Color(markup:)` for a colored entry; `Image(systemName: "underline")` secondary for colorless highlights/notes; `Image(systemName: "bookmark.fill")` secondary for bookmarks; `Image(systemName: "note.text")` for chapter notes); `VStack(alignment: .leading, spacing: 2)`: first line `Text(referenceString).font(.callout.weight(.medium))` + translation tag `Text(translationID).font(.caption2).padding(.horizontal, 5).padding(.vertical, 1).background(.quaternary, in: Capsule())` when present; second: the note's `NoteMarkdown.blocks(body).first` as `Text` `.lineLimit(2)` or, for noteless items, `Text(quotedText).italic().foregroundStyle(.secondary).lineLimit(1)` (bookmarks show nothing when `quotedText` is empty); trailing `Text(modifiedAt, format: .dateTime.month(.abbreviated).day().year()).font(.caption).foregroundStyle(.tertiary)`. Row has `.padding(.vertical, 3)`.

- [ ] **Step 1: Build the views and wire the window, menu item and toolbar button** as specified (no unit tests for SwiftUI views; the model is covered by Task 6).
- [ ] **Step 2: Build the app**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify live** (quit Matt's running app, launch `Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app` from the worktree): toolbar `note.text` opens the Notes window; ⇧⌘N and the View menu item open the same window (one window); the palette lists "Open Notes Browser"; rows show reference, tag, marker, body/quote, date; sort menu switches to book sections; filter narrows; typing in the search field narrows after a pause; double-click on a row navigates the main window and lights the card with the outline (screenshot); Return does the same; Delete key shows the confirmation (cancel it: Matt's store must not change); empty state renders when the search has no hits. Record screenshots in the scratchpad.
- [ ] **Step 4: Commit** — `feat: Notes browser window with sort, filter, search, navigation and delete`

---

### Task 8: `ReaderSettings` and the typography mapping

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderSettings.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/ReaderSettingsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum LineSpacingChoice: String, CaseIterable, Sendable {
      case compact, normal, relaxed
      public var lineHeightMultiple: CGFloat   // 1.15, 1.3, 1.5
      public var title: String                 // "Compact", "Normal", "Relaxed"
  }
  public enum AppearanceChoice: String, CaseIterable, Sendable {
      case system, light, dark
      public var colorScheme: ColorScheme?     // nil, .light, .dark
      public var title: String                 // "System", "Light", "Dark"
  }
  public enum ReaderSettings {
      public static let defaultTranslationKey = "defaultTranslationID"   // String, default "ESV"
      public static let fontSizeKey = "readerFontSize"                   // Double, default 18
      public static let lineSpacingKey = "readerLineSpacing"             // LineSpacingChoice rawValue, default normal
      public static let appearanceKey = "readerAppearance"               // AppearanceChoice rawValue, default system
      public static let fontSizeRange: ClosedRange<Double> = 14...24
      public static let defaultFontSize: Double = 18
      public static let defaultTranslationID = "ESV"
      public static func clampedFontSize(_ value: Double) -> Double
      public static func defaultTranslationID(from defaults: UserDefaults) -> String   // stored or "ESV"
      public static func typography(fontSize: Double, lineSpacing: LineSpacingChoice) -> ReaderTypography
          // ReaderTypography.default with bodyFont = serifFont(size: clamped), lineHeightMultiple from the choice; everything else unchanged
  }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct ReaderSettingsTests {
    @Test func defaultsReproduceTheCurrentTypography() {
        #expect(ReaderSettings.typography(fontSize: 18, lineSpacing: .normal) == .default)
    }
    @Test func fontSizeIsClampedToTheRange() {
        #expect(ReaderSettings.clampedFontSize(9) == 14 && ReaderSettings.clampedFontSize(40) == 24 && ReaderSettings.clampedFontSize(20) == 20)
        #expect(ReaderSettings.typography(fontSize: 40, lineSpacing: .normal).bodyFont.pointSize == 24)
    }
    @Test func lineSpacingMapsOntoTheMultiple() {
        #expect(LineSpacingChoice.compact.lineHeightMultiple == 1.15 && LineSpacingChoice.normal.lineHeightMultiple == 1.3 && LineSpacingChoice.relaxed.lineHeightMultiple == 1.5)
        #expect(ReaderSettings.typography(fontSize: 18, lineSpacing: .relaxed).lineHeightMultiple == 1.5)
    }
    @Test func appearanceMapsOntoColorScheme() {
        #expect(AppearanceChoice.system.colorScheme == nil && AppearanceChoice.light.colorScheme == .light && AppearanceChoice.dark.colorScheme == .dark)
    }
    @Test func unknownDefaultTranslationFallsBack() throws {
        let defaults = UserDefaults(suiteName: "ReaderSettingsTests-\(UUID())")!
        #expect(ReaderSettings.defaultTranslationID(from: defaults) == "ESV")
        defaults.set("NIV", forKey: ReaderSettings.defaultTranslationKey)
        // NavigationModel ignores an unbundled default and takes the first bundled translation.
        let model = try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: ReaderSettings.defaultTranslationID(from: defaults))
        #expect(model.translationID == "WEB")
    }
}
```

- [ ] **Step 2: Run to verify failure** — compile failure.
- [ ] **Step 3: Implement `ReaderSettings.swift`.**
- [ ] **Step 4: Run the full suite** — all pass.
- [ ] **Step 5: Commit** — `feat: ReaderSettings keys and typography mapping`

---

### Task 9: Settings tabs General and Reading, applied live

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/GeneralSettingsView.swift`, `Packages/ScriptureKit/Sources/ScriptureUI/ReadingSettingsView.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/SettingsView.swift`, `MainWindowView.swift`, `ReadingThroughScriptureApp.swift`, `README.md`

**Interfaces:**
- Consumes: `ReaderSettings`, `LineSpacingChoice`, `AppearanceChoice`, `NavigationModel.translations`, `NavigationModel.resumeReading()`.
- Produces:
  - `public struct GeneralSettingsView: View { public init(translations: [Translation]) }` — `Form` (`.formStyle(.grouped)`): Section "Translation": `Picker("Default translation", selection: @AppStorage(ReaderSettings.defaultTranslationKey))` over `translations` (`Text(title).tag(id)`), footer "Used on first launch; the toolbar pill changes the translation you are reading in."; Section "Notes": `Toggle("Show notes column", isOn: @AppStorage("showNotesColumn"))`.
  - `public struct ReadingSettingsView: View { public init() }` — Section "Text": `Slider(value: fontSize, in: ReaderSettings.fontSizeRange, step: 1)` labelled "Font size" with a trailing `Text("\(Int(fontSize)) pt")` monospaced-digit; `Picker("Line spacing", selection: lineSpacing)` segmented over `LineSpacingChoice.allCases`; Section "Appearance": `Picker("Appearance", selection: appearance)` segmented over `AppearanceChoice.allCases`. Storage via `@AppStorage` with the `ReaderSettings` keys and defaults (raw-value enums conform to `RawRepresentable` so `@AppStorage` stores them directly).
  - `SettingsView(colors:translations:)`: `TabView` with `GeneralSettingsView` (`Label("General", systemImage: "gearshape")`), `ReadingSettingsView` (`Label("Reading", systemImage: "textformat.size")`), `HighlightColorsSettingsView` (`Label("Markup", systemImage: "highlighter")`), frame 480×440 as today.
  - `MainWindowView`: `@AppStorage` for font size, line spacing, appearance; `ReaderView(..., typography: ReaderSettings.typography(fontSize:lineSpacing:))`; `.preferredColorScheme(appearance.colorScheme)` on `content`; `.onChange(of: typography) { model.resumeReading() }` so a typography change keeps the reader at its first visible verse (the controller re-lays the text out and would otherwise report from the top).
  - `ReadingThroughScriptureApp.init`: `NavigationModel(store:positionStore:defaultTranslationID: ReaderSettings.defaultTranslationID(from: .standard))`; the Notes window content also gets `.preferredColorScheme`.
  - `README.md`: a "Notes browser" paragraph, a "Settings" paragraph (tabs and keys), ⇧⌘N in the keyboard line, "Current plan" link to this plan.

- [ ] **Step 1: Implement** the two views, the tabs, the live application and the README.
- [ ] **Step 2: Build the app** — `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Verify live**: ⌘, shows three tabs with the right symbols; General lists the eight translations with ESV selected and the notes-column toggle mirrors ⌥⌘N (toggle, observe the column, toggle back); Reading: drag the slider (screenshot the reader at 22 pt, then restore 18), switch Relaxed then Normal (line spacing changes), Appearance Dark then System (window appearance changes). Check `defaults read com.matthewfurr.ReadingThroughScripture` ends with every key at its starting value (`readerFontSize` 18 or absent, etc.); remove any key this session added so Matt's settings are exactly as found.
- [ ] **Step 4: Commit** — `feat: Settings General and Reading tabs applied live to the reader`

---

### Task 10: Palette wiring in the app and the Notes browser toolbar

**Files:**
- Modify: `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`

**Interfaces:**
- Consumes: `NavigationModel.noteSearch/showTarget/performCommand`, `NotesBrowserModel.noteHits`, `MarkupNavigation.show`, `openWindow`, `openSettings` (`@Environment(\.openSettings)`).

- [ ] **Step 1: Wire** in the `WindowGroup` content's `.onAppear` (or a `task` once): `model.noteSearch = { notesBrowser.noteHits(query: $0) }`, `model.showTarget = { MarkupNavigation.show($0, navigation: model, markup: markup) }`, `model.performCommand = { switch $0 { case .openNotesBrowser: openWindow(id: "notes-browser"); case .openSettings: openSettings() } }`.
- [ ] **Step 2: Build** — succeeds.
- [ ] **Step 3: Verify live**: ⌘K, type a word from one of Matt's notes: the note row appears with its reference and first line; Return navigates and lights the card; ⌘K "open notes" → Return opens the Notes window; ⌘K "settings" → Return opens Settings. Restore navigation (Back) afterwards.
- [ ] **Step 4: Commit** — `feat: palette note hits and commands wired in the app`

---

### Task 11: Whole-branch review and freeze check

- [ ] **Step 1: Run the full suite** and record the count.
- [ ] **Step 2: Request a fresh whole-branch review** (superpowers:requesting-code-review) of `main..HEAD`; fix Critical and Important findings with a failing test first where a test applies; commit each fix.
- [ ] **Step 3: Freeze check in the running app**: click inside a highlight (outline + menu, no blue selection), click a card (editor opens, caret at end), Settings > Markup rename field takes one click, drag reorders colors (then restore), notes column pinned header and empty state, chapter load lands on the stored verse after a translation switch. Screenshots in the scratchpad.
- [ ] **Step 4: Restore** Matt's navigation (Back/Forward to the chapter and translation found at launch) and settings; relaunch from the worktree bundle; leave it running.
- [ ] **Step 5: Hand-over note** in the shared notes folder (`milestone-4-notes-browser.md`): commits, test count, bundle path, freeze statement per item, rulings, deferred minors, hand-check list (≤10 items). Do not merge or push.

## Self-review notes

- Spec coverage: browser (A) → Tasks 2–7; settings (B) → Tasks 8–9; palette (C) → Tasks 5, 10; store tests → Tasks 1–2; typography mapping tests → Task 8; palette ranking of notes → Task 5. Chat-thread seam → Task 3 comments. No schema change anywhere.
- Types: `MarkupTarget(location:verse:translationID:highlightID:)` is used identically in Tasks 4, 5, 6, 7; `NotesBrowserEntry.Kind` cases match between Tasks 3 and 6; `PaletteNoteHit` fields match between Tasks 5 and 6.
- Review Focus items each have a named test in Tasks 1, 4, 6, 8.
