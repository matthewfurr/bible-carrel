# Milestone 10, Project 2: Finding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Search matches every word in any order, word starts, "exact phrases", -exclusions, a scope and a misspelling; ⌘K is bright, useful before a key is pressed, and runs what the menus run; the iPhone's search takes the same search.

**Architecture:** One pure `SearchQuery` in ScriptureData parses what is typed; it alone writes the index's query and matches the reader's own marks.
- The Bible database (schema 3) holds one unstemmed full-text table per translation. Scope is a row-id range; "did you mean" reads the index's own word list.
- `NavigationModel` searches Scripture off the main actor and drops a result no longer wanted. Scope, order, chip, recents and the commands' state live in it, so both apps read one model.
- Commands are a pure list filtered by a `PaletteState`; their keys are read from project 1's `ShortcutCatalog`.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit and UIKit, GRDB with SQLite FTS5, SwiftData, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-16-milestone-10-finding-design.md`. Read it with this plan; section numbers below are the spec's.

Paths: `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `SD` is `Packages/ScriptureKit/Sources/ScriptureData`, `IMP` is `Packages/ScriptureKit/Sources/BibleImporterCore`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `TD` is `Packages/ScriptureKit/Tests/ScriptureDataTests`, `TI` is `Packages/ScriptureKit/Tests/BibleImporterCoreTests`, `MAC` is `Apps/Mac/ReadingThroughScripture`.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-10-study-tools`, on branch `milestone-10-study-tools`. Never push or merge.
- Git: `/usr/bin/git`, one git command per Bash call, no `cd … &&`, loops or shell variables.
- Every commit message ends with the attribution line the implementer's own session gives (pass it as a second `-m`).
- `rtk` shortens command output; use `rtk proxy <command>` when all of it is needed.

**Matt's data**
- Never touch the Release app, `Scripts/install-app.sh`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. Never build or run the Release configuration; read its settings with `-showBuildSettings` only.
- The `.dev` store gets no test notes. In the Mac Debug app and the simulator, never press 1 to 9, 0, N or B on a selection and never choose a colour, Add Note or Bookmark. Those are covered by tests and by Matt's own list.
- In the Mac Debug app never run Clear Recents. A page style, appearance or text size changed to look at something is put back.
- No test touches iCloud, the Keychain, the network or Matt's stores.
- `Scripts/install-phone.sh debug` is run by the controller, never by a task's implementer.

**Commands**
- Package tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (add `--filter <Suite>` for one suite).
- iOS tests: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests` (append `/<Suite>` for one suite).
- Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
- iOS Debug build: the same with `-scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'`.
- The Bible database: `bash Scripts/ensure-bible.sh` rebuilds `Build/bible.sqlite` when `BibleSchema.version` changes. It runs `swift run -c release`, so it counts as a build.
- Run builds and test runs one after another; they share `Build/DerivedData`.
- Quit the Mac Debug app only with `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`, then `open` it. Never `pkill -x`.
- Which suite a test file runs in: a file under `#if os(macOS)` runs in the package suite only, one under `#if os(iOS)` in the iOS suite only, any other `T` file in both. `TD` and `TI` files run in the package suite only.

**Code rules**
- TextKit 2 only; never touch `textView.layoutManager`.
- Swift Testing: `#expect` cannot contain a mutating call; mutate on the line before.
- Deletes stay undoable through the window's `UndoManager`; the reader never asks for confirmation.
- Nothing in the synced store changes: no new records, no new fields, no iCloud schema change. Recents live in `UserDefaults` alone and never in `SyncedPreferences.keys`.
- Fixtures for search tests come from the public-domain translations (WEB, KJV), as the importer's do.

**UI rules (CLAUDE.md, DESIGN.md)**
- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change; use the `/impeccable-swift` skill for the panel and the phone's search screen.
- Palette tokens only (`Color.inkSecondary`, `Palette.accent.platformColor`); every new pairing goes in `PaletteTests`.
- Semantic text styles only; sizes tied to text are `@ScaledMetric`; spacing and radii are `AppSpacing` and `AppRadius` by name.
- No card by reflex, no new shadow, no new material, no `.glassEffect()`. The palette stays the only floating surface and the only shadow besides the loupe's.
- UI copy keeps the app's American spelling ("No Color", "License"), whatever the spec's prose uses.

**Seeing the UI**
- Use the recipes in `docs/superpowers/specs/2026-11-13-milestone-9-handover.md`, "How to see the UI without stalling": the iOS Simulator control tool on the Debug simulator app; on the Mac, `screencapture -x -o -l<id>` of the Debug app's own window, in the background.
- AeroSpace may keep a window out of reach. Do not move Matt's windows; say what could not be seen.
- Pictures go in the session scratchpad. A temporary snapshot test is removed before committing.

**Checked against the code on 2026-11-17, before Task 1** (the plan was written before project 1's last fixes)
- `ShortcutCatalog` (row ids, chords, `groups`), `PassageLink(reference:).url(scheme:)`, `PassageLink.appScheme`, `NavigationModel.openPassageLink`, `ReferenceParser.parse` and today's `PaletteCommand` are as the tasks name them. The row `chaptersAnywhere` is labelled "Chapters, from anywhere".
- `Keycap` is today `private struct Keycap` with `let glyph` (called as `Keycap(glyph:)`) at `ShortcutsSheet.swift:115-128`, inside that file's `#if os(macOS)`; the row that draws it is `:98-108`. Task 8 moves it and gives it the unlabelled initializer.
- `MainWindowView.swift` gained two lines at `:265`: the line numbers after it are corrected in Tasks 6, 7 and 8. `DESIGN.md`, `DESIGN.json` and `README.md` moved too: Task 10's line numbers are corrected.
- `everyMenuShortcutInTheMacAppIsListed` now also fails on any `.keyboardShortcut(` it cannot read. Task 7's shortcuts are written `.keyboardShortcut("+", modifiers: .command)`, the one form it reads; write any twin the same way.
- `ReaderKeyCommands.keysAreLive` already stops every reader key while ⌘K shows; nothing here changes it.

**The handover's rules of 2026-11-17 come before any step below** (`docs/superpowers/specs/2026-11-17-milestone-10-handover.md`, "Rules for every session")
- No implementer quits, opens or relaunches the Mac Debug app, and none sends it a keystroke, click or scroll. Where a step says to drive the Mac app through System Events, the implementer instead renders the view offscreen (an `NSHostingView` in a temporary test, written to a PNG in the session scratchpad, opened with Read, the test removed before committing) and says what that could not show. The controller does the live part afterwards: Task 7 Step 6's keys, Task 8 Step 6's clicks, Tab and Esc, Task 10 Step 8.
- The iPhone simulator may be driven as the steps say.
- Never write to the real clipboard, the `.dev` store or the network from a test.

## Review Focus

1. **A word with an apostrophe** (`peter's`, `don’t`, straight or curly). The index cuts it in two ("peter", "s"), so as a word start it would also find "Peter said". The reader expects the possessive: the pieces side by side, the last one whole. Pinned in Task 1 (`aWordWithAnApostropheIsItsPiecesSideBySideAndWhole`) and Task 2 (`aHyphenJoinsAndAnApostropheFindsThePossessive`). **(call, record in As built)**
2. **A scope that finds nothing, or that the translation switched to lacks.** Limited to Romans, a word not in Romans leaves no Scripture group; the scope menu must stay so the reader can widen it. A scope whose book or Apocrypha the new translation lacks returns to Whole Bible. Pinned in Task 5 (`scriptureIsSearchedInTheScopeAndCounted`, `theScopeReturnsToTheWholeBible`).
3. **A reference or a number typed into search** (`John 3:16`, `144000`). Scripture finds nothing, and a careless "did you mean" would offer nonsense. Nothing is offered for a reference, and a word with a digit is never corrected. Pinned in Task 3 (`nothingIsOfferedForQuotesExclusionsNumbersOrStrangers`) and Task 5 (`aMisspellingOffersARowThatRunsTheSearch`).
4. **A verse pasted whole**, with its punctuation, curly quotes and line breaks, or any text with the index's own syntax in it. It finds the verse and never makes the index throw. Pinned in Task 1 (`onlyLettersDigitsAndTheQuerysOwnMarksReachTheIndex`) and Task 2 (`aPastedVerseFindsItselfAndNoTypedTextThrows`).
5. **Recents that cannot be read or opened**: written by another build, damaged, in a translation no longer in the app, or a mark since deleted. The list reads as empty or leaves the row out, and a recent mark still shows its passage. Pinned in Task 6 (`whatCannotBeReadOrOpenedIsLeftOut`, `choosingARecentDoesWhatItDidTheFirstTime`).

---

### Task 1: The query (spec 4.1)

**Files:**
- Modify: `SD/SearchQuery.swift` (replaced; today's `ftsPhrase(from:)` stays as a static until Task 2 removes it with the old search)
- Test: create `TD/SearchQueryTests.swift` (package suite)

**Interfaces:**
- Consumes: nothing.
- Produces:

```swift
public struct SearchQuery: Hashable, Sendable {
    public struct Term: Hashable, Sendable {
        public let words: [String]      // folded: lower case, no accents, letters and digits only; never empty
        /// A bare word: its last word may start a longer one. False for a quoted phrase, an
        /// excluded term, and a word whose last piece follows an apostrophe.
        public let isWordStart: Bool
        public let isExcluded: Bool
    }
    public struct Token: Hashable, Sendable { public let word: String; public let range: Range<String.Index> }

    public let text: String             // what was typed, trimmed
    public let terms: [Term]
    public init(_ text: String)
    /// The index's MATCH string; nil with no term to find (nothing typed, or exclusions alone).
    public var ftsMatch: String? { get }
    /// No quotation mark and no exclusion was typed, and every term is one word.
    public var allowsSuggestion: Bool { get }
    /// `text` cut as the index cuts it: runs of letters, digits and combining marks, each folded.
    public static func tokens(in text: String) -> [Token]
    /// One of `fields` holds every term to find, and no field holds an excluded term. False with no term to find.
    public func matches(anyOf fields: [String]) -> Bool
    public func matches(_ text: String) -> Bool
    /// The words of `text` the terms to find match, in text order, for bolding.
    public func matchRanges(in text: String) -> [Range<String.Index>]
}
```

**How text is read.**
1. `“ ” „ « »` are `"`; `’ ‘` are `'`.
2. A `"` opens a phrase that runs to the next `"` or to the end; it also ends a bare word it touches.
3. Outside a phrase, white space separates bare words. One or more `-` directly before a bare word or phrase, at the start or after white space, exclude it. A `-` followed by white space is dropped.
4. Each bare word or phrase is cut into `tokens`; one with no token is dropped. Other punctuation inside a bare word (a hyphen, a colon, `*`) only separates its pieces, which stay side by side.
5. A bare word is a word start, unless it is excluded or an apostrophe comes before its last piece.
6. Folding is `folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)`.

**The MATCH string.** A term is its words joined by one space inside double quotes, then ` *` when it is a word start. Terms to find are joined by ` AND `. With exclusions the whole is `(<found>) NOT (<excluded, joined by " OR ">)`. Only letters and digits from the reader ever reach it.

- [ ] **Step 1: Write the failing tests.** `t("living", "water", start: false)` builds a `Term` (`start` true, `excluded` false unless given); `terms("…")` is `SearchQuery("…").terms`, `match("…")` its `ftsMatch`.

```swift
@Test func eachRowOfTheTableParsesToItsTerms() {
    #expect(terms("remain fruit") == [t("remain"), t("fruit")])
    #expect(terms("  ABÍD ") == [t("abid")])                                    // case and accents ignored
    #expect(terms("\"living water\"") == [t("living", "water", start: false)])
    #expect(terms("love -fear") == [t("love"), t("fear", start: false, excluded: true)])
    #expect(terms("love -\"no man\"") == [t("love"), t("no", "man", start: false, excluded: true)])
    #expect(terms("beer-sheba") == [t("beer", "sheba")])                        // joined, not an exclusion
}

@Test func quotesOperatorsAndDashes() {
    #expect(terms("“living water”") == [t("living", "water", start: false)])
    #expect(terms("vine \"living wat") == [t("vine"), t("living", "wat", start: false)])   // left open: runs to the end
    #expect(terms("love OR fear") == [t("love"), t("or"), t("fear")])           // hand-typed operators are words
    #expect(terms("NOT NEAR(a b) spirit* text:lord").map(\.words) == [["not"], ["near", "a"], ["b"], ["spirit"], ["text", "lord"]])
    #expect(terms("- fear") == [t("fear")] && terms("--fear") == [t("fear", start: false, excluded: true)])
    #expect(terms("\"\" \"***\" * : - ()").isEmpty)
    #expect(match("-fear -\"no man\"") == nil && match("   ") == nil)           // exclusions alone find nothing
}

@Test func aWordWithAnApostropheIsItsPiecesSideBySideAndWhole() {
    for typed in ["peter's", "Peter’s"] { #expect(terms(typed) == [t("peter", "s", start: false)]) }
    #expect(terms("peter'") == [t("peter")])                                    // still being typed
}

@Test func theMatchStringIsExactlyThis() {
    #expect(match("remain fruit") == "\"remain\" * AND \"fruit\" *")
    #expect(match("\"living water\"") == "\"living water\"" && match("beer-sheba") == "\"beer sheba\" *")
    #expect(match("love -fear -\"no man\"") == "(\"love\" *) NOT (\"fear\" OR \"no man\")")
    #expect(match("peter's") == "\"peter s\"")
}

@Test func onlyLettersDigitsAndTheQuerysOwnMarksReachTheIndex() {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " \"*()"))
    for typed in ["\"; DROP TABLE verse; --", "a\u{0}b", "'' OR 1=1", "((((", "\"\"\"x", "NEAR/2 y", "col:x", "{a b}",
                  "x\\y", "😀 joy", "“I am the vine,” he said.\nAbide"] {
        let string = match(typed) ?? ""
        #expect(string.unicodeScalars.allSatisfy(allowed.contains), "\(typed) → \(string)")
        #expect(string.filter { $0 == "\"" }.count.isMultiple(of: 2), "\(typed)")
    }
    #expect(terms("e\u{301}t\u{e9}") == [t("ete")])
}

@Test func theMatcherAgreesWithTheGrammar() {
    let text = "Abiding in me, and I in you. He that abideth beareth much fruit; fear not."
    func found(_ typed: String) -> Bool { SearchQuery(typed).matches(text) }
    func bold(_ typed: String) -> [String] { SearchQuery(typed).matchRanges(in: text).map { String(text[$0]) } }
    #expect(found("fruit abid") && !found("bide"))                              // word starts, never inside a word
    #expect(found("\"much fruit\"") && !found("\"fruit much\"") && !found("\"much fru\"") && found("\"in me and\""))
    #expect(!found("abid -fear") && found("abid -fea") && !found("-fear") && !found(""))   // an exclusion is a whole word
    #expect(SearchQuery("love -fear").matches(anyOf: ["Greater love", "no man"]))
    #expect(!SearchQuery("love -fear").matches(anyOf: ["Greater love", "Fear not"]))
    #expect(!SearchQuery("love man").matches(anyOf: ["Greater love", "no man"]))   // one field holds them all
    #expect(bold("abid -fear") == ["Abiding", "abideth"] && bold("\"much fruit\" you") == ["you", "much", "fruit"])
    #expect(SearchQuery("abide frut").allowsSuggestion)
    for typed in ["\"abide\"", "abide -fear", "beer-sheba", "peter's", ""] { #expect(!SearchQuery(typed).allowsSuggestion, "\(typed)") }
}
```

- [ ] **Step 2: Run them.** `swift test … --filter SearchQueryTests` must FAIL to compile (`SearchQuery("…")` undefined).
- [ ] **Step 3: Implement `SearchQuery`.** A token character is a scalar whose general category is a letter, a number, a mark or private use.
- [ ] **Step 4: Run them.** `SearchQueryTests` passes; the whole package suite passes (`BibleStoreTests` still uses the kept `ftsPhrase`).
- [ ] **Step 5: Commit.** `/usr/bin/git add` the two files, then `/usr/bin/git commit -m "feat: the search grammar as one pure query (finding 4.1)" -m "<the session's attribution line>"`. Every later commit step has this shape.

---

### Task 2: Schema 3, the importer and the store's search (spec 4.2, 4.3, 4.5, 4.6)

Two red-green cycles, one commit each: the database with the search that reads it (A), then the real database and the budget (B). The index's shape cannot be judged without its search, so they are one task.

**The index: measured, then chosen.** `sqlite3` 3.51.0 on Matt's Mac, the real text (eight translations, 259,393 verses), warm. "Rows" is the best twenty by rank; "count" is the total.

| Layout | Database | `lord` in ESV: rows + count | `t`, the worst word start |
|---|---|---|---|
| Today: one stemmed table, translation filtered after the join | 69.2 MB (69,177,344 bytes) | 34–39 + 18–21 ms | — |
| A: one unstemmed table, a row-id range per translation | 71.5 MB, and a word table besides | 17–20 + 1–3 ms | 198 + 75 ms |
| A with `prefix='2 3'`, `'1 2 3'` | 105.0, 119.5 MB | 20 + 3 ms | 119 + 34 ms |
| **B: one unstemmed table per translation, no prefix index** | **72.4 MB**, about 72.7 with the heading and title tables | **10–13 + 1 ms** | 68 + 9 ms |
| B with `prefix='1'` | 87.0 MB | 9 + 1 ms | 54 + 1 ms |

- **Chosen: B.** Each translation has a contentless FTS5 table `verse_fts_<ID>` (`unicode61 remove_diacritics 2`, positions kept for phrases) whose row ids are its verses' ids. It meets the 50 ms budget four times over for about 3.5 MB, and a translation fetched later is one more table.
- **No prefix index.** A short word start is slow because its many rows are ranked, which a prefix index does not help, and each index adds 15 MB or more.
- **Scope is a row-id range.** The importer writes verses in translation, then canon, order, so a book, a testament and the Apocrypha are each one unbroken run of ids; `translation_book` records each book's first and last. `lord` in ESV's New Testament takes 3 + 2 ms, in Romans 1 + 1 ms.
- **The word list is the index's own:** `verse_vocab_<ID>`, an `fts5vocab` view of the table (13,309 words in ESV, read in 17 ms). No table is added.

**Files:**
- Create: `SD/SearchScope.swift`; `TD/Fixtures/EN/NT/JHN/WEB.json` and `KJV.json`, copied from `~/Library/Caches/ReadingThroughScripture/holybooks/0dab245f361980d2af3f4075cba3fbe8c4fa31b2/EN/NT/JHN/` (the folder `bash Scripts/fetch-holybooks.sh` prints)
- Modify: `SD/BibleSchema.swift`, `SD/BibleStore.swift` (`:135-160`), `SD/SearchQuery.swift` (drop `ftsPhrase`), `IMP/BibleDatabaseWriter.swift` (`:37-104`), `SUI/NavigationModel.swift` (the two store calls in `updatePalette`, `:495-497`, and no more)
- Test: create `TD/BibleStoreSearchTests.swift`; modify `TD/BibleStoreTests.swift` and `TI/BibleDatabaseWriterTests.swift` (package suite); create `T/SearchBenchmarkTests.swift` (`#if os(macOS)`: package suite)

**Interfaces:**
- Consumes: `SearchQuery.ftsMatch` (Task 1).
- Produces:

```swift
// SD/SearchScope.swift
public enum SearchScope: Hashable, Codable, Sendable {
    case wholeBible, oldTestament, newTestament, apocrypha
    case book(String)                                    // a book code
    public var title: String { get }                     // "Whole Bible", "Old Testament", "New Testament", "Apocrypha", the book's name
    public func contains(_ book: Book) -> Bool
    /// Whole Bible, then each section `books` has a book of, in canon order (Apocrypha only then).
    public static func sections(in books: [TranslationBook]) -> [SearchScope]
}
public enum SearchOrder: String, Codable, Sendable, CaseIterable {
    case bestMatch, bibleOrder
    public var title: String { get }                     // "Best match", "Bible order"
}
public struct SearchPage: Equatable, Sendable {
    public let verses: [Verse]
    public let total: Int                                // every matching verse in the scope
    public static let empty: SearchPage
}

// BibleSchema: `version` is 3
/// "verse_fts_ESV"; nil unless the id is ASCII letters and digits (the name goes into SQL).
public static func searchTable(for translationID: String) -> String?
public static func vocabularyTable(for translationID: String) -> String?   // "verse_vocab_ESV"
/// Creates and fills both for one translation, once its verses are in; throws
/// `BibleSchemaError.invalidTranslationID` for an id `searchTable(for:)` refuses.
public static func createSearchIndex(for translationID: String, in db: Database) throws

// BibleStore, replacing `search(_:translationID:limit:)` and `searchCount`
public func search(_ query: SearchQuery, translationID: String, scope: SearchScope = .wholeBible,
                   order: SearchOrder = .bestMatch, limit: Int) throws -> SearchPage
```

**The schema.** `verse_fts` leaves `BibleSchema.create`. `translation_book` gains `first_verse_id INTEGER NOT NULL` and `last_verse_id INTEGER NOT NULL`. `createSearchIndex` runs, for `ESV`:

```sql
CREATE VIRTUAL TABLE verse_fts_ESV USING fts5(text, content='', tokenize='unicode61 remove_diacritics 2');
INSERT INTO verse_fts_ESV(rowid, text) SELECT id, text FROM verse WHERE translation_id = 'ESV' ORDER BY id;
INSERT INTO verse_fts_ESV(verse_fts_ESV) VALUES('optimize');
CREATE VIRTUAL TABLE verse_vocab_ESV USING fts5vocab('verse_fts_ESV', 'row');
```

**The search.** `.empty` when `ftsMatch` is nil, when `searchTable(for:)` is nil or not in the database, or when the scope has no book in the translation. A scope narrower than the whole Bible is the range from `min(first_verse_id)` to `max(last_verse_id)` over its rows of `translation_book` (joined to `book` for `canon`); the whole Bible has no range clause. Then, in one read:

```sql
SELECT count(*) FROM verse_fts_ESV WHERE verse_fts_ESV MATCH ? [AND rowid BETWEEN ? AND ?];
SELECT v.book_id, v.chapter, v.verse, v.verse_end, v.text, v.break_after
FROM verse_fts_ESV f JOIN verse v ON v.id = f.rowid
WHERE verse_fts_ESV MATCH ? [AND f.rowid BETWEEN ? AND ?]
ORDER BY rank        -- best match; `ORDER BY f.rowid` for Bible order
LIMIT ?;
```

#### Cycle A: the database and its search

- [ ] **Step 1: Add the two John fixtures and write the failing tests.** In `TI/BibleDatabaseWriterTests.swift`, line `:29` reads `verse_fts_WEB`. A second test imports the same fixtures and, inside its own `q.read { db in … }`, expects:

```swift
@Test func eachTranslationHasItsOwnUnstemmedIndexOverUnbrokenRuns() throws {
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse_fts_KJV WHERE verse_fts_KJV MATCH '\"poor in spirit\"'") == 0)   // Matthew is WEB's
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master WHERE name = 'verse_fts'") == 0)
    // The words as written: "bless" and "blessed" are two words.
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM verse_vocab_WEB WHERE term IN ('bless', 'blessed')") == 2)
    // Each book is one unbroken run of ids, recorded, and the runs follow canon order in a translation.
    let runs = try Row.fetchAll(db, sql: """
        SELECT tb.first_verse_id = min(v.id) AND tb.last_verse_id = max(v.id) AND max(v.id) - min(v.id) + 1 = count(*) AS whole, min(v.id) AS first
        FROM translation_book tb JOIN verse v ON v.translation_id = tb.translation_id AND v.book_id = tb.book_id
        JOIN book b ON b.id = tb.book_id GROUP BY tb.translation_id, tb.book_id ORDER BY tb.translation_id, b.sort_order
        """)
    #expect(runs.count == 4 && runs.allSatisfy { $0["whole"] == true })
    #expect(runs.map { $0["first"] as Int } == runs.map { $0["first"] as Int }.sorted())
    for id in ["", "E SV", "x\"; DROP TABLE verse; --", "ÉSV"] { #expect(BibleSchema.searchTable(for: id) == nil, "\(id)") }
}
```

  In `TD/BibleStoreTests.swift`: `translationsAndBooks` expects `["MAT", "JHN", "TOB", "SUS"]`; the four old search tests (`searchFindsPhrase` to `searchQueryPhraseBuilding`) go; `schemaMismatchThrows` (an old database is refused) stays; add:

```swift
/// `Scripts/ensure-bible.sh` reads the version from the source with this pattern, so an old database is rebuilt.
@Test func theBuildScriptsPatternReadsTheSchemaVersion() throws {
    let source = try String(contentsOf: schemaSourceURL, encoding: .utf8)   // `Sources/ScriptureData/BibleSchema.swift`, from `#filePath`
    let match = try #require(source.firstMatch(of: /static let version = ([0-9]+)/))
    #expect(Int(match.1) == BibleSchema.version && BibleSchema.version == 3)
}
```

  In `TD/BibleStoreSearchTests.swift`: `find(_ typed, _ translation = "WEB", _ scope = .wholeBible, order: .bibleOrder, limit: 10_000)` returns the `SearchPage`; `john(_ typed, _ translation)` is its verses in John as `"15:4"`. Every list was read from the real text.

```swift
@Test func everyWordInAnyOrderAndWordStartsLetterForLetter() throws {
    // The spec's three, and 12:24, which has both words too.
    for typed in ["remain fruit", "fruit remain"] { #expect(try john(typed, "WEB") == ["12:24", "15:4", "15:5", "15:16"]) }
    let abid = try find("abid", "KJV", .book("JHN"))
    #expect(abid.total == 12 && abid.verses.contains { $0.text.contains("abide ") } && abid.verses.contains { $0.text.contains("abideth") })
    #expect(try john("abidi", "KJV") == ["5:38"] && john("ABÍD", "KJV").count == 12)   // "abiding", which the stemmed index lost
    let his = try find("his", "KJV", .book("JHN"))
    #expect(his.total > 100 && his.verses.allSatisfy { SearchQuery("his").matches($0.text) })
    #expect(!his.verses.contains { $0.id.chapter == 1 && $0.id.verse == 10 })    // "him" twice, "his" never
}

@Test func aPhraseIsExactAndAnExclusionIsAWholeWord() throws {
    for typed in ["\"living water\"", "“living water”", "\"LIVING water"] { #expect(try john(typed, "WEB") == ["4:10", "4:11", "7:38"]) }
    #expect(try john("\"water living\"", "WEB").isEmpty && john("\"living wat\"", "WEB").isEmpty)
    let kept = try john("jews -fear", "KJV")
    #expect(kept.contains("9:22"))                                              // "they feared the Jews"
    #expect(Set(kept).isDisjoint(with: ["7:13", "19:38", "20:19"]))             // "for fear of the Jews"
    #expect(try find("-fear", "KJV") == .empty)
}

@Test func aHyphenJoinsAndAnApostropheFindsThePossessive() throws {
    #expect(try john("years thirty-eight", "WEB") == ["5:5"])                   // joined, not an exclusion
    for typed in ["peter's", "Peter’s"] { #expect(try john(typed, "KJV") == ["1:40", "6:8"]) }   // never "Peter said"
}

@Test func eachScopeReturnsOnlyItsBooksAndTheCountsMatch() throws {
    func lord(_ scope: SearchScope, _ translation: String = "WEB") throws -> SearchPage { try find("lord", translation, scope) }
    let whole = try lord(.wholeBible), nt = try lord(.newTestament), ap = try lord(.apocrypha)
    #expect(Set(nt.verses.map(\.id.book)) == ["MAT", "JHN"] && Set(ap.verses.map(\.id.book)) == ["TOB", "SUS"])
    #expect(whole.total == nt.total + ap.total && whole.total == whole.verses.count)
    #expect(nt.total == (try lord(.book("MAT")).total) + (try lord(.book("JHN")).total))
    #expect(try lord(.oldTestament) == .empty)                                  // the fixture's WEB has no Old Testament
    #expect(Set(try lord(.oldTestament, "KJV").verses.map(\.id.book)) == ["PSA"])
    #expect(try lord(.book("GEN")) == .empty && lord(.wholeBible, "NIV") == .empty && lord(.wholeBible, "x\" OR 1=1 --") == .empty)
    let three = try store.search(SearchQuery("lord"), translationID: "WEB", limit: 3)
    #expect(three.verses.count == 3 && three.total == whole.total)              // a limit never shortens the count
    #expect(SearchScope.sections(in: try store.books(in: "WEB")) == [.wholeBible, .newTestament, .apocrypha])
    // Bible order is canon order; best match holds the same verses.
    func key(_ verse: VerseLocation) -> [Int] { [BookCatalog.book(code: verse.book)!.order, verse.chapter, verse.verse] }
    let ordered = whole.verses.map(\.id)
    #expect(ordered == ordered.sorted { key($0).lexicographicallyPrecedes(key($1)) })
    #expect(Set(try find("lord", order: .bestMatch).verses.map(\.id)) == Set(ordered))
}

@Test func aPastedVerseFindsItselfAndNoTypedTextThrows() throws {
    let verse = try store.chapter((book: "JHN", chapter: 15), translationID: "WEB")[4]
    #expect(try find(verse.text + "\n").verses.map(\.id) == [verse.id])
    let long = Array(repeating: "the lord said", count: 100).joined(separator: " ")
    for typed in ["\"; DROP TABLE verse; --", "((((", "\"\"\"x", "NEAR/2 y", "a\u{0}b", "*", long] { _ = try find(typed) }
}
```

- [ ] **Step 2: Run.** `--filter BibleDatabaseWriterTests` and `--filter BibleStoreSearchTests` FAIL to compile.
- [ ] **Step 3: Implement.**
  - `importAll` sorts the book files by translation id, then `BookCatalog` order, records each book's first and last inserted id with its `translation_book` row, and calls `createSearchIndex` for each translation in place of the `'rebuild'` at `:93`.
  - `BibleStore.search` as above; `searchCount` and `SearchQuery.ftsPhrase` go.
  - In `NavigationModel.updatePalette` the two store calls become one `store.search(SearchQuery(paletteQuery), translationID: translationID, limit: searchLimits.verses)`, its `verses` and `total` used as before.
- [ ] **Step 4: Run.** The whole package suite passes except the tests marked `.needsRealBible`, which wait for cycle B's rebuild.
- [ ] **Step 5: Commit.** `feat: schema 3: an unstemmed index per translation, searched by word, phrase, exclusion and scope (finding 4.1 to 4.6)`

#### Cycle B: the real database and the budget

- [ ] **Step 6: Write the benchmark** in `T/SearchBenchmarkTests.swift`, a `@MainActor @Suite(.serialized)`.

```swift
/// Spec 4.5: a common word in the whole Bible returns its first rows and its count within 50 ms, debug build.
@Test(.needsRealBible) func aCommonWordInTheWholeBibleIsWithinFiftyMilliseconds() throws {
    let store = try BenchmarkChapter.realStore()
    var page = SearchPage.empty
    let median = ReaderBenchmarkTests.median("search-lord-ESV") {
        page = (try? store.search(SearchQuery("lord"), translationID: "ESV", limit: 20)) ?? .empty
    }
    #expect(page.verses.count == 20 && page.total > 6000 && median < .milliseconds(50))
}
```

- [ ] **Step 7: Rebuild the database.** Note `wc -c Build/bible.sqlite` (69,177,344 before). Run `bash Scripts/ensure-bible.sh`: it rebuilds, since the file says 2 and the source 3.
  - `sqlite3 Build/bible.sqlite "SELECT value FROM meta WHERE key='schema_version'"` prints `3`.
  - `wc -c Build/bible.sqlite` is about 72.7 MB; keep the figure for As built.
  - Run the script again: it exits at once and the file's date does not change.
- [ ] **Step 8: Run.** The whole package suite passes, the `.needsRealBible` tests among them; keep the printed median. Then the iOS suite passes.
- [ ] **Step 9: Commit.** `test: the search budget on the real text (finding 4.5)`

---

### Task 3: Did you mean (spec 4.4)

**Files:**
- Create: `SD/SpellingSuggester.swift`
- Modify: `SD/BibleStore.swift`
- Test: create `TD/SpellingSuggesterTests.swift`; `TD/BibleStoreSearchTests.swift` (package suite)

**Interfaces:**
- Consumes: `SearchQuery` (Task 1); `BibleStore.search`, `BibleSchema.vocabularyTable(for:)` (Task 2).
- Produces:

```swift
public struct WordCount: Hashable, Sendable { public let word: String; public let verses: Int }
public struct SearchSuggestion: Hashable, Sendable { public let query: String; public let verseCount: Int }

public enum SpellingSuggester {
    /// Edits between two folded words: a letter added, dropped or changed, or two neighbours
    /// swapped, each counting one. Nil past `limit`.
    public static func distance(_ a: String, _ b: String, limit: Int) -> Int?
    /// 1 for a word of up to three letters, 2 for four to six, 3 for seven or more.
    public static func allowance(for word: String) -> Int
    /// The listed words within `word`'s allowance: closer first, then in more verses, then by spelling.
    public static func candidates(for word: String, in words: [WordCount], limit: Int = 3) -> [String]
    /// The queries to try in place of `query`, best first.
    public static func queries(for query: SearchQuery, in words: [WordCount], limit: Int = 5) -> [String]
}
extension BibleStore {
    /// The translation's words as its index holds them, each with how many verses have it, sorted
    /// by word; empty for a translation the database lacks. Read once per translation and kept.
    public func words(in translationID: String) throws -> [WordCount]
    /// For a search that found nothing: the first of `queries` that finds a verse in the scope, with its count.
    public func suggestion(for query: SearchQuery, translationID: String, scope: SearchScope = .wholeBible) throws -> SearchSuggestion?
}
```

**`queries`.**
1. Empty unless `query.allowsSuggestion`.
2. A word is known when some listed word starts with it. A word with a digit in it is never corrected.
3. Empty when every word is known, or when an unknown word has a digit or no candidate.
4. Each unknown word takes its candidates; known words stay as typed. The queries are the combinations in order of the sum of the candidates' places (0 the best), then by the earlier word's place, cut to `limit`.

- [ ] **Step 1: Write the failing tests.** `list` is `[("abide", 77), ("abode", 40), ("able", 30), ("fruit", 183), ("fret", 4), ("from", 4330), ("lord", 6694), ("led", 80), ("jerusalem", 600)]` as `WordCount`s, sorted by word; `queries("…")` is `SpellingSuggester.queries(for: SearchQuery("…"), in: list)`.

```swift
@Test func theAllowanceGrowsWithTheWordAndASwapIsOneEdit() {
    #expect(["a", "abc", "abcd", "abcdef", "abcdefg", "jerusalem"].map(SpellingSuggester.allowance) == [1, 1, 2, 2, 3, 3])
    #expect(SpellingSuggester.distance("frut", "fruit", limit: 3) == 1 && SpellingSuggester.distance("teh", "the", limit: 3) == 1)
    #expect(SpellingSuggester.distance("abide", "fruit", limit: 3) == nil)
}

@Test func aMisspellingOffersTheNearestThenTheCommoner() {
    #expect(queries("frut") == ["fruit", "fret", "from"])                       // 1 and 1 (fruit is commoner), then 2
    #expect(queries("lrd") == ["lord", "led"])                                  // three letters: one change only
    #expect(queries("abibe") == ["abide", "abode", "able"] && queries("jerusalm") == ["jerusalem"])
    #expect(queries("abibe frut") == ["abide fruit", "abide fret", "abode fruit", "abide from", "abode fret"])
    #expect(queries("abide frut").first == "abide fruit")                       // a known word stays
}

@Test func nothingIsOfferedForQuotesExclusionsNumbersOrStrangers() {
    for typed in ["\"frut\"", "frut -vine", "abide fruit", "abid", "qqqqzz", "frut 144000", "john 3:16", "frut's", ""] {
        #expect(queries(typed).isEmpty, "\(typed)")
    }
}
```

  In `TD/BibleStoreSearchTests.swift`, with `offered(_ typed, _ scope = .wholeBible)` the store's `suggestion` in WEB:

```swift
@Test func aSuggestionComesFromTheTranslationsOwnWordsAndOnlyWhenItFindsSomething() throws {
    let web = try store.words(in: "WEB"), kjv = try store.words(in: "KJV")
    #expect(web.map(\.word) == web.map(\.word).sorted() && (try store.words(in: "NIV")).isEmpty)
    #expect(kjv.contains { $0.word == "abideth" } && !web.contains { $0.word == "abideth" })
    #expect(web.first { $0.word == "fruit" }?.verses == (try find("\"fruit\"").total))
    #expect(try offered("frut") == SearchSuggestion(query: "fruit", verseCount: try find("fruit").total))
    #expect(try offered("remain frut", .book("JHN")) == SearchSuggestion(query: "remain fruit", verseCount: 4))
    for typed in ["\"frut\"", "frut -vine", "qqqqzz", "frut 144000"] { #expect(try offered(typed) == nil, "\(typed)") }
    #expect(try offered("frut", .oldTestament) == nil)                          // nothing there to find
}
```

- [ ] **Step 2: Run.** `--filter SpellingSuggesterTests` FAILS to compile.
- [ ] **Step 3: Implement.** `words(in:)` is `SELECT term, doc FROM verse_vocab_<ID> ORDER BY term`, kept per translation in a `Mutex`. `suggestion` counts each query with `search(…, limit: 0)`.
- [ ] **Step 4: Run.** The package suite passes.
- [ ] **Step 5: Commit.** `feat: did you mean, from the index's own words (finding 4.4)`

---

### Task 4: The reader's marks take the grammar (spec 4.1)

**Files:**
- Modify: `SUI/SearchRanker.swift` (`:45-61`, `:68-92`, `:154-171`)
- Test: `T/SearchRankerTests.swift` (both suites)

**Interfaces:**
- Consumes: `SearchQuery.matches(anyOf:)`, `matchRanges(in:)` (Task 1).
- Produces: `SearchRanker.matchRanges(in:query:)` and `bolded(_:query:)` keep their signatures and follow `SearchQuery`. A note matches by its body and quoted words, a highlight by its quoted words, a conversation by its title and last line, each through `matches(anyOf:)`; a bookmark never matches by words.

- [ ] **Step 1: Write the failing test.** `ids(.notes, "…")` is `hits(group(.notes, in: rank("…"))).map(\.id)`.

```swift
@Test func marksTakePhrasesAndExclusions() {
    #expect(ids(.notes, "\"greater love\"") == [Self.loveNoteID] && ids(.notes, "\"love greater\"").isEmpty)
    #expect(ids(.notes, "abid") == [Self.letterNoteID, Self.noteID])            // word starts, as before
    #expect(ids(.notes, "abide -fruit") == [Self.letterNoteID])                 // the John 15:4 note says "then fruit"
    #expect(ids(.asked, "\"abide mean\"") == [Self.threadID] && ids(.asked, "abide -remain").isEmpty)
    #expect(ids(.notes, "-abide").isEmpty)
    #expect(ids(.notes, "\"the vine\"") == [Self.highlightID])                  // not the bookmark that quotes it
    let text = "Abide in me, and I in you."
    #expect(SearchRanker.matchRanges(in: text, query: "\"in me\" -you").map { String(text[$0]) } == ["in", "me"])
}
```

- [ ] **Step 2: Run.** `--filter SearchRankerTests`: it FAILS.
- [ ] **Step 3: Implement.** The private `matches`, `foldedWords` and `fold` go; the ranker builds one `SearchQuery` per call.
- [ ] **Step 4: Run.** `SearchRankerTests` passes with every existing test unchanged. `NotesBrowserQueryTests` passes untouched: the Notes window's own field is a different search and is not changed.
- [ ] **Step 5: Commit.** `feat: notes, highlights and conversations are found by phrase and exclusion (finding 4.1)`

---

### Task 5: The model: a search off the main actor, scope, order, chips, the suggestion (spec 4.2 to 4.5, 5.4)

**Files:**
- Modify: `SUI/NavigationModel.swift` (the Palette part `:486-560`, `setTranslation` `:435-470`), `SUI/SearchRanker.swift` (`results`), `SUI/SearchResults.swift`, `SUI/PaletteItem.swift`, `MAC/MainWindowView.swift` (the `.task` `:137-146`), `SUI/Phone/PhoneSearchScreen.swift` (the `.task` `:48-58` and `refresh` `:255-258` only)
- Test: `T/NavigationModelTests.swift`, `T/SearchRankerTests.swift` (both suites)

**Interfaces:**
- Consumes: `BibleStore.search`, `suggestion` (Tasks 2 and 3).
- Produces:

```swift
// SearchResults.swift: SearchGroupKind gains `suggestion` (one row, no header) and `recent` (Task 6).
public enum SearchChip: String, CaseIterable, Sendable {
    case marks, notes, asked, scripture, passages, commands
    public var title: String                 // "Marks", "Notes", "Asked", "Scripture", "Passages", "Commands"
    public var kinds: Set<SearchGroupKind>   // marksInPassage; notes; asked; scripture and suggestion; goTo and books; commands and translations
    public static let phone: [SearchChip]    // the first four
}
extension SearchResults {
    /// The chips of `offered` that have a group here, in `offered`'s order.
    public func chips(_ offered: [SearchChip] = SearchChip.allCases) -> [SearchChip]
    /// The chip's groups alone; nil, or a chip with no group here, keeps every group.
    public func showing(_ chip: SearchChip?) -> SearchResults   // not `only`: `.scripture` is a case of both enums
    public func count(of chip: SearchChip) -> Int
    /// Tab: the chip `delta` on from `current` (nil is All) among `chips`, going round through All.
    public static func chip(after current: SearchChip?, by delta: Int, among chips: [SearchChip]) -> SearchChip?
}
// SearchLimits gains `commands` (6 in `.palette`, 0 in `.phone`) and
public static let paletteChip = SearchLimits(books: 30, notes: 30, asked: 20, verses: 50, marksInPassage: 50, commands: 60)

// PaletteItem
case suggestion(SearchSuggestion)   // id "suggestion:<query>"; title "Did you mean “abide”?"; subtitle "12 verses" or "1 verse"; symbol "magnifyingglass"
// SearchRanker.results gains `suggestion: SearchSuggestion? = nil`: the first group, when Scripture found nothing.

// NavigationModel
public var searchScope: SearchScope
public var searchOrder: SearchOrder
/// The Mac's chosen chip; nil is All. While one is chosen the search uses `SearchLimits.paletteChip`.
public var paletteChip: SearchChip?
/// Scripture is among the results, or the scope is narrower than the whole Bible.
public var showsScopeMenu: Bool { get }
/// Everything a search depends on (query, translation, scope, order, chip, limits), an `Equatable` struct; the views refresh when it changes.
public var paletteSearchKey: PaletteSearchKey { get }
/// Ranks `paletteQuery` now, on the main actor: Return on a query newer than the results, and tests.
public func updatePalette()
/// As `updatePalette`, with Scripture searched off the main actor. A result is dropped when its
/// request is no longer what the model would ask.
public func refreshPalette() async
@concurrent nonisolated static func offMain<T: Sendable>(_ work: @Sendable () throws -> T) async rethrows -> T
/// Scripture for one request (query, translation, scope, order, limit, whether to suggest): the store's
/// search and suggestion through `offMain`. A test replaces it to hold one open.
var scriptureSearch: @Sendable (ScriptureRequest) async -> ScriptureAnswer
// ScriptureRequest: `query: SearchQuery`, `translationID`, `scope`, `order`, `limit`, `suggests: Bool`.
// ScriptureAnswer: `page: SearchPage`, `suggestion: SearchSuggestion?`. Both Equatable and Sendable.
```

**Rules.**
- `paletteItems` is `paletteResults.showing(paletteChip).flatItems`, so Return and the arrows move over what is shown.
- A request suggests when the query allows it and the text is not a reference (`ReferenceParser.parse` is nil). A suggestion is looked for only when the page's total is 0.
- Choosing a `.suggestion` sets `paletteQuery` to its query and ranks again at once; the palette stays open.
- The scope returns to `.wholeBible` when `isPaletteShown` becomes true, when `paletteQuery` becomes empty (**call**: on both apps, one rule for "each time the palette opens" and "when the field is cleared"), and when `setTranslation` leaves it with no book in the new translation.
- The chip returns to nil when the palette opens and when its groups are absent from new results; it is kept while typing (**call**).
- The order is kept until the app quits, as the Notes tab's is (**call**).

- [ ] **Step 1: Write the failing tests.** In `NavigationModelTests`: `search(model, "verse")` sets `paletteQuery` and calls `updatePalette()`; `scripture(model)` is the Scripture group and `verses(model)` its verses. The fixture's WEB has "verse" in Matthew (eight verses), Psalms (four) and Tobit (two), and "tempter" and "Jesus" once each, in Matthew 4.

```swift
@Test func scriptureIsSearchedInTheScopeAndCounted() throws {
    let (model, _) = try makeModel()
    search(model, "verse")
    #expect(scripture(model)?.totalCount == 14)
    model.searchScope = .book("PSA")
    model.searchOrder = .bibleOrder
    model.updatePalette()
    #expect(scripture(model)?.totalCount == 4 && verses(model).map(\.id.verse) == [1, 2, 1, 2])
    // The scope narrows Scripture alone, and its menu stays when it finds nothing.
    model.searchScope = .newTestament
    search(model, "psalm")
    #expect(model.paletteResults.groups.contains { $0.kind == .books } && scripture(model) == nil && model.showsScopeMenu)
    model.searchScope = .wholeBible
    search(model, "matt 2")
    #expect(scripture(model) == nil && !model.showsScopeMenu)
}

@Test func theScopeReturnsToTheWholeBible() throws {
    let (model, _) = try makeModel()
    model.searchScope = .newTestament
    model.isPaletteShown = true
    #expect(model.searchScope == .wholeBible)                                   // each time the palette opens
    model.paletteQuery = "verse"
    model.searchScope = .apocrypha
    model.paletteQuery = "  "
    #expect(model.searchScope == .wholeBible)                                   // the field cleared
    model.searchScope = .apocrypha
    model.setTranslation("KJV")
    #expect(model.searchScope == .wholeBible)                                   // the fixture's KJV has no Apocrypha
    model.searchScope = .book("MAT")
    model.setTranslation("WEB")
    #expect(model.searchScope == .book("MAT"))
}

@Test func aChosenChipShowsItsKindAloneWithMoreRows() throws {
    let (model, _) = try makeModel()
    model.includesCommandsInSearch = false
    search(model, "psalm")
    #expect(model.paletteResults.chips() == [.scripture, .passages])
    model.paletteChip = .passages
    model.updatePalette()
    #expect(model.paletteItems == [.book(BookCatalog.book(code: "PSA")!)])
    model.submitPalette(selectedIndex: 0)                                       // Return takes the shown row
    #expect(model.location == ChapterLocation(book: "PSA", chapter: 1))
    search(model, "verse")
    #expect(model.paletteChip == nil && verses(model).count == SearchLimits.palette.verses)   // no passage among these
    model.paletteChip = .scripture
    model.updatePalette()
    #expect(verses(model).count == 14 && model.paletteItems.count == 14)
}

@Test func aMisspellingOffersARowThatRunsTheSearch() throws {
    let (model, _) = try makeModel()
    model.isPaletteShown = true
    search(model, "jesis")
    let offered = SearchSuggestion(query: "jesus", verseCount: 1)
    #expect(model.paletteItems.first == .suggestion(offered) && scripture(model) == nil)
    #expect(PaletteItem.suggestion(offered).title == "Did you mean “jesus”?" && PaletteItem.suggestion(offered).subtitle == "1 verse")
    model.select(.suggestion(offered))
    #expect(model.isPaletteShown && model.paletteQuery == "jesus" && scripture(model)?.totalCount == 1)
    // Nothing for a reference, a number, quotes, an exclusion or a word with no near neighbour.
    for typed in ["matt 9:99", "jesis 144000", "\"jesis\"", "jesis -forty", "qqqqzz"] {
        search(model, typed)
        #expect(!model.paletteItems.contains { if case .suggestion = $0 { true } else { false } }, "\(typed)")
    }
}

@Test func aNewerKeystrokeAbandonsAnOlderSearchsResult() async throws {
    #expect(await NavigationModel.offMain { !Thread.isMainThread })
    let (model, _) = try makeModel()
    let gate = Gate()     // a small actor here: `wait()` suspends until `open()`; `entered()` returns once `wait()` was called
    let real = model.scriptureSearch
    model.scriptureSearch = { request in
        if request.query.text == "tobit" { await gate.wait() }
        return await real(request)
    }
    model.paletteQuery = "tobit"
    let older = Task { await model.refreshPalette() }
    await gate.entered()
    model.paletteQuery = "psalm"
    await model.refreshPalette()
    let settled = model.paletteResults
    await gate.open()
    await older.value
    #expect(model.paletteResults == settled && verses(model).allSatisfy { $0.id.book == "PSA" })
    model.updatePalette()
    #expect(model.paletteResults == settled)                                    // what the main actor gives
}
```

  In `SearchRankerTests`:

```swift
@Test func chipsAreTheKindsPresentAndTabGoesRoundThem() {
    let words = rank("abide", verses: abideVerses, verseTotal: 61), passage = rank("john 15")
    #expect(words.chips() == [.notes, .asked, .scripture] && words.count(of: .scripture) == 61)
    #expect(passage.chips() == [.marks, .passages] && passage.chips(SearchChip.phone) == [.marks])
    #expect(words.showing(.scripture).groups.map(\.kind) == [.scripture] && words.showing(.passages) == words)
    let chips = words.chips()
    #expect(SearchResults.chip(after: nil, by: 1, among: chips) == .notes && SearchResults.chip(after: nil, by: -1, among: chips) == .scripture)
    #expect(SearchResults.chip(after: .scripture, by: 1, among: chips) == nil)  // round through All
    #expect(SearchResults.chip(after: .commands, by: 1, among: chips) == nil)   // a chip that has gone
}
```

- [ ] **Step 2: Run.** `--filter NavigationModelTests` FAILS to compile.
- [ ] **Step 3: Implement.** Both views' `.task` become `.task(id: model.paletteSearchKey)`, keeping their pause (120 ms on the Mac, 150 ms on the phone) before `await model.refreshPalette()`. The Mac's comment at `:137` now gives the pause's reason (typing settles), not that search is on the main thread.
- [ ] **Step 4: Run.** Both suites pass; every existing `NavigationModelTests` test passes unchanged.
- [ ] **Step 5: Commit.** `feat: Scripture is searched off the main actor, in a scope, with a suggestion (finding 4.2 to 4.5)`

---

### Task 6: Recents (spec 5.2)

**Files:**
- Create: `SUI/Recents.swift`
- Modify: `SUI/NavigationModel.swift` (`init` `:109`, `open` `:209`, `lookUp`'s front-page branch `:274-277`, the chapter steps `:425-433`, `updatePalette`, `select` `:531`, project 1's `openPassageLink`), `SUI/PaletteItem.swift`, `SUI/SearchRanker.swift`, `SUI/MarkupTarget.swift` and `SUI/SearchResults.swift` (`Codable`), `Apps/Shared/AppModels.swift` (`:30-34`), and the four places a reference's Open looks a passage up: `MAC/ReadingThroughScriptureApp.swift:51-57`, `MAC/MainWindowView.swift:429-434`, `SUI/Phone/PhoneRootView.swift:41-45`, `SUI/Phone/PhoneChatScreen.swift:195-199`
- Test: create `T/RecentsTests.swift`; `T/NavigationModelTests.swift`, `T/PreferenceSyncTests.swift` (both suites)

**Interfaces:**
- Consumes: `SearchScope` (Task 2), `SearchMarkHit`, `MarkupTarget`.
- Produces:

```swift
public struct Recent: Codable, Hashable, Identifiable, Sendable {
    public enum Target: Codable, Hashable, Sendable {
        case chapter(ChapterLocation)                                // read: opening it moves the place
        case lookup(ChapterLocation, verse: Int?)                    // looked up: shown with the way back
        case mark(id: UUID, kind: SearchMarkHit.Kind, target: MarkupTarget, reference: String)
        case search(query: String, scope: SearchScope, verseCount: Int)
    }
    public let target: Target
    /// The translation it was read or looked up in; nil for a mark that keeps the one being read, and for a search.
    public let translationID: String?
    public let date: Date
    /// What makes two the same: the chapter; the chapter and verse; the mark's id; the query's terms with its scope.
    public var id: String { get }
    public var title: String { get }        // "John 15", "John 15:5", the mark's reference, the query as typed
    public var symbolName: String { get }   // "book", "text.quote", the mark's own, "magnifyingglass"
    public func subtitle(now: Date = .now, calendar: Calendar = .current) -> String
}

@MainActor public final class RecentsStore {
    public static let key = "recents"
    public static let capacity = 20
    public static let shownCount = 5
    public init(defaults: UserDefaults = .standard)
    public private(set) var items: [Recent]                           // newest first
    public func record(_ target: Recent.Target, translationID: String?, at date: Date = .now)
    public func clear()
    /// The newest five that can be opened now: not the chapter that is open, none in a translation the app lacks.
    public func shown(openChapter: ChapterLocation?, translations: [Translation]) -> [Recent]
}

// PaletteItem: `case recent(Recent)`, id "recent:<id>"; its title, subtitle and symbol are the Recent's.
// SearchRanker: with nothing typed, Recent (its header has no count), then Commands; either may be absent.
public static func emptyState(recents: [Recent], commands: [PaletteCommand], commandTotal: Int) -> SearchResults
// NavigationModel: `init` gains `recents: RecentsStore? = nil`, kept as `public let recents`.
/// Records a passage a reference led to as looked up; called beside the `lookUp` at the four places above.
public func recordLookup(_ location: ChapterLocation, verse: Int?)
```

**The subtitle.** "Read yesterday · ESV", "Looked up Tuesday · KJV"; a mark is "Note", "Highlight", "Bookmark" or "Conversation"; a search is "Search · 12 verses", "Search · 1 verse" or "Search", then " · New Testament" when it had a scope. The day is "today", "yesterday", the weekday's name for two to six days ago, then the month and day ("Nov 9"), in the calendar's locale.

**What is recorded.**

| What happens | Recorded |
|---|---|
| `open(_:verse:)` and `open(_ reference:)`: the front page, the phone's Library, a reference or book row, the book thumb | `.chapter` |
| `openPassageLink`; Open on a reference's verses (`recordLookup`) | `.lookup` (**call**: a link is shown as a lookup, so its row looks it up again) |
| `select` of a verse row | `.search` (the query, scope and Scripture's count), then `.lookup` |
| `select` of a mark row | `.search` when the results have no Go to row, then `.mark` |
| `select` of a recent | the same target again, now |

Nothing else records: Next and Previous (which stop going through the recording `open`), `turn`, Back and Forward, the place restored at launch or adopted from another device, `open(_:verse:translationID:)`, a bare `lookUp` (a mark shown from Notes), and a place the translation lacks.

**Choosing a recent.** A chapter is opened in its translation; a lookup is looked up in its translation; a mark goes to `showTarget` (or is looked up without one); a search sets `paletteQuery`, then `searchScope`, ranks at once and leaves the palette open.

- [ ] **Step 1: Write the failing tests.** In `RecentsTests`: `store` is a `RecentsStore` on a scratch `defaults` suite removed afterwards (as `NavigationModelTests.makeDefaults`); `add(_ target, _ translation, day:)` records on that day after a fixed date; `john(n)` is that chapter; `esv` is that `Translation`; `says(_ target, _ translation, daysAgo:)` is the subtitle of such a `Recent` at noon on Monday 16 November 2026, in a UTC Gregorian calendar with the `en_US` locale.

```swift
@Test func theNewestTwentyAreKeptOncePerTargetAndOutliveTheStore() {
    for chapter in 1...25 { add(.chapter(john(chapter)), "ESV", day: chapter) }
    #expect(store.items.count == 20 && store.items.first?.target == .chapter(john(25)) && store.items.last?.target == .chapter(john(6)))
    add(.chapter(john(10)), "KJV", day: 30)                                     // again: to the front, once, as it is now
    #expect(store.items.count == 20 && store.items.first?.translationID == "KJV")
    // A lookup in the same chapter is its own row; a search is the same whatever its case and spacing.
    add(.lookup(john(10), verse: 4), "KJV", day: 31)
    add(.search(query: "Remain fruit", scope: .wholeBible, verseCount: 4), nil, day: 32)
    add(.search(query: "remain  FRUIT", scope: .wholeBible, verseCount: 5), nil, day: 33)
    #expect(store.items.prefix(3).map(\.title) == ["remain  FRUIT", "John 10:4", "John 10"])
    #expect(RecentsStore(defaults: defaults).items == store.items)
    store.clear()
    #expect(store.items.isEmpty && defaults.object(forKey: RecentsStore.key) == nil)
}

@Test func whatCannotBeReadOrOpenedIsLeftOut() {
    for chapter in 1...7 { add(.chapter(john(chapter)), chapter == 6 ? "NIV" : "ESV", day: chapter) }
    add(.lookup(john(7), verse: 2), "ESV", day: 8)
    // Five, without the chapter that is open or the row in a translation the app no longer has.
    #expect(store.shown(openChapter: john(7), translations: [esv]).map(\.title) == ["John 7:2", "John 5", "John 4", "John 3", "John 2"])
    // A list from another build, or damaged, reads as empty and can be written again.
    for junk in [Data("not a list".utf8) as Any, "a string"] {
        defaults.set(junk, forKey: RecentsStore.key)
        let fresh = RecentsStore(defaults: defaults)
        #expect(fresh.items.isEmpty)
        fresh.record(.chapter(john(1)), translationID: "ESV")
        #expect(RecentsStore(defaults: defaults).items.count == 1)
    }
}

@Test func eachRowSaysWhatItIsAndWhen() {
    #expect(says(.chapter(john(15)), "ESV", daysAgo: 1) == "Read yesterday · ESV")
    #expect(says(.lookup(john(15), verse: 5), "KJV", daysAgo: 6) == "Looked up Tuesday · KJV")
    #expect(says(.chapter(john(15)), "ESV", daysAgo: 0) == "Read today · ESV" && says(.chapter(john(15)), "ESV", daysAgo: 7) == "Read Nov 9 · ESV")
    #expect(says(.search(query: "remain fruit", scope: .wholeBible, verseCount: 12), nil, daysAgo: 0) == "Search · 12 verses")
    #expect(says(.search(query: "x", scope: .newTestament, verseCount: 1), nil, daysAgo: 0) == "Search · 1 verse · New Testament")
    #expect(says(mark(.note), nil, daysAgo: 3) == "Note" && says(mark(.thread), nil, daysAgo: 3) == "Conversation")   // `mark(_:)` builds a `.mark` target
}
```

  In `PreferenceSyncTests`, `recentsStayOnTheDevice`: `#expect(!SyncedPreferences.keys.contains(RecentsStore.key))`, and after a `PreferenceSync` on a `FakeKeyValueCloud` has started, a `record` and `pushPending()` leave `cloud.sets` unchanged.

  In `NavigationModelTests`: `recording()` is `makeModel` with a `RecentsStore` on scratch defaults, returning the model, the position store and the recents; `targets` is `recents.items.map(\.target)`; `recent(_ target, _ translation)` wraps a new `Recent` as a `.recent` row; `matthew(n)`, `matthewOne` and `psalmTwo` exist.

```swift
@Test func goingSomewhereOnPurposeIsRecorded() throws {
    let (model, _, recents) = try recording()
    model.open(matthew(2))
    model.open(Reference(book: BookCatalog.book(code: "PSA")!, chapter: 2, verse: 2))
    model.lookUp(matthewOne, verse: 2)
    model.recordLookup(matthewOne, verse: 2)
    #expect(model.openPassageLink(URL(string: "bible://tob.1.2")!))
    #expect(targets == [.lookup(ChapterLocation(book: "TOB", chapter: 1), verse: 2), .lookup(matthewOne, verse: 2),
                        .chapter(psalmTwo), .chapter(matthew(2))])
    #expect(recents.items.allSatisfy { $0.translationID == "WEB" })
}

@Test func pagingHistoryRestoringAndFailuresAreNotRecorded() throws {
    let (model, positionStore, recents) = try recording()
    model.open(matthewOne)
    model.goToNextChapter()
    model.goToPreviousChapter()
    model.turn(to: matthew(3), atEnd: false)
    model.goBack()
    model.goForward()
    model.lookUp(psalmTwo, verse: nil)                                          // a mark shown from Notes
    model.returnFromLookup()
    model.open(matthew(99))                                                     // not in the translation
    model.open(matthew(2), verse: 1, translationID: "KJV")
    let relaunched = try NavigationModel(store: try FixtureStore.make(), positionStore: positionStore, recents: recents, defaultTranslationID: "WEB")
    positionStore.save(ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 1, translationID: "WEB"))
    relaunched.adoptStoredPosition()
    #expect(relaunched.location == psalmTwo && targets == [.chapter(matthewOne)])
}

@Test func aSearchThatLedSomewhereIsRecordedWithWhatWasOpened() throws {
    let (model, _, recents) = try recording()
    let entry = markEntry()                                                     // "x marks the spot", Matthew 2:2
    let hit = SearchMarkHit(entry: entry)
    model.markSearch = { [entry] }
    search(model, "tempter")
    #expect(recents.items.isEmpty)                                              // typing records nothing
    model.select(try #require(model.paletteItems.first { if case .verse = $0 { true } else { false } }))
    #expect(targets == [.lookup(matthew(4), verse: 3), .search(query: "tempter", scope: .wholeBible, verseCount: 1)])
    search(model, "marks")                                                      // a mark from a word search: the mark, then the search
    model.select(.mark(hit))
    #expect(targets.prefix(2) == [.mark(id: hit.id, kind: .note, target: hit.target, reference: "Matthew 2:2"),
                                  .search(query: "marks", scope: .wholeBible, verseCount: 0)])
    search(model, "matt 2")                                                     // from a passage: the mark alone, moved to the front
    model.select(.mark(hit))
    #expect(recents.items.count == 4)
}

@Test func choosingARecentDoesWhatItDidTheFirstTime() throws {
    let (model, positionStore, recents) = try recording()
    model.open(matthewOne)
    model.isPaletteShown = true
    model.select(recent(.search(query: "verse", scope: .apocrypha, verseCount: 2), nil))
    #expect(model.isPaletteShown && model.paletteQuery == "verse" && model.searchScope == .apocrypha && scripture(model)?.totalCount == 2)
    #expect(recents.items.first?.target == .search(query: "verse", scope: .apocrypha, verseCount: 2))
    model.select(recent(.chapter(psalmTwo), "KJV"))
    #expect(model.location == psalmTwo && model.translationID == "KJV" && model.lookupReturn == nil && !model.isPaletteShown)
    #expect(positionStore.load()?.chapter == 2)
    model.select(recent(.lookup(matthew(4), verse: 3), "KJV"))
    #expect(model.location == matthew(4) && model.scrollTarget?.verse == 3 && model.lookupReturn != nil)
    // A mark that has since been deleted still shows its passage.
    let gone = MarkupTarget(location: matthew(2), verse: 2, translationID: "KJV", highlightID: UUID())
    model.select(recent(.mark(id: UUID(), kind: .note, target: gone, reference: "Matthew 2:2"), nil))
    #expect(model.location == matthew(2) && model.scrollTarget?.verse == 2)
}

@Test func withNothingTypedThePaletteShowsRecentWithoutTheOpenChapter() throws {
    let (model, _, _) = try recording()
    model.includesCommandsInSearch = false
    for location in [matthewOne, matthew(2), psalmTwo] { model.open(location) }
    search(model, "")
    #expect(model.paletteResults.groups.map(\.kind) == [.recent])
    #expect(model.paletteItems.map(\.title) == ["Matthew 2", "Matthew 1"])     // Psalm 2 is open now
}
```

- [ ] **Step 2: Run.** `--filter RecentsTests` FAILS to compile.
- [ ] **Step 3: Implement.** The list is JSON `Data` under `RecentsStore.key`; anything unreadable is an empty list. `AppModels.make` passes `RecentsStore(defaults: .standard)`. With nothing typed `updatePalette` gives `SearchRanker.emptyState` (no commands until Task 7).
- [ ] **Step 4: Run.** Both suites pass; `theSyncedKeysAreExactlyThese` is unchanged.
- [ ] **Step 5: Commit.** `feat: recents, kept on the device (finding 5.2)`

---

### Task 7: Commands, and Larger and Smaller Text (spec 5.2, 5.3)

**Files:**
- Modify: `SUI/PaletteItem.swift` (`PaletteCommand` `:5-30`), `SUI/PaletteRanker.swift` (`:47-58`), `SUI/SearchRanker.swift`, `SUI/ShortcutCatalog.swift` (the View group `:77-84`), `SUI/ReaderSettings.swift`, `SUI/NavigationModel.swift`, `MAC/ReadingThroughScriptureApp.swift` (`wirePalette` `:121-132`, the View menu `:222-229`), `MAC/MainWindowView.swift`
- Test: create `T/PaletteCommandTests.swift`; `T/PaletteRankerTests.swift`, `T/SearchRankerTests.swift`, `T/NavigationModelTests.swift` (both suites)

**Interfaces:**
- Consumes: `ShortcutCatalog.groups`, `PassageLink(reference:).url(scheme:)` and `PassageLink.appScheme` (project 1); `RecentsStore` (Task 6).
- Produces:

```swift
public enum PaletteCommand: Hashable, Sendable {
    case home, back, forward, previousChapter, nextChapter, readFromHere
    case textLayout, showNotesColumn, hideNotesColumn, notesBrowser, showShortcuts, settings
    case pageStyle(PageStyle), appearance(AppearanceChoice), largerText, smallerText
    case switchTranslation, copyChapterLink, exportNotes
    case toggleAssistant, newConversation, tryAgain, copyLastReply, addLastReplyAsNote, stopAnswering
    case clearRecents
    public static let all: [PaletteCommand]         // the table's order; 32 with the four styles and four appearances
    public static let suggested: [PaletteCommand]   // home, notesBrowser, toggleAssistant, textLayout, showShortcuts, switchTranslation
    public var id: String { get }
    public var title: String { get }
    public var symbolName: String { get }
    /// The catalogue row and which of its chords is this command's; nil without a shortcut.
    public var shortcut: (row: String, chord: Int)? { get }
    /// The keycaps to show, read from `ShortcutCatalog`; nil without a shortcut.
    public var keycaps: [String]? { get }
    public func isAvailable(in state: PaletteState) -> Bool
    public func isCurrent(in state: PaletteState) -> Bool     // the page style or appearance in force
}

/// What decides which commands can run now.
public struct PaletteState: Equatable, Sendable {
    // The model fills these.
    public var isReading = false                   // the reader is showing
    public var canGoBack = false, canGoForward = false, hasPreviousChapter = false, hasNextChapter = false
    public var isLookingUp = false, hasRecents = false
    public var otherTranslations = 0
    // The app fills these.
    public var isNotesColumnShown = true
    public var pageStyle = PageStyle.printed
    public var appearance = AppearanceChoice.system
    public var fontSize = ReaderSettings.defaultFontSize
    public var canRetry = false, hasLastReply = false, lastReplyIsSaved = false, isResponding = false
    public init()
}

extension ShortcutCatalog {
    public static func chord(row: String, at index: Int) -> String?
    /// A chord as keycaps: each of ⌃⌥⇧⌘ its own cap, then the key ("-" is shown as "−").
    public static func keycaps(forChord chord: String) -> [String]
}
extension ReaderSettings {
    /// `size` moved `steps` of `fontSizeStep`, held within `fontSizeRange`.
    public static func steppedFontSize(_ size: Double, by steps: Int) -> Double
}
// NavigationModel
public var appPaletteState: (() -> PaletteState)?   // the app's half
public var paletteState: PaletteState { get }       // the app's half with the model's own fields set
public private(set) var isChoosingTranslation: Bool
public private(set) var textLayoutRequests: Int     // the window shows Text & Layout when it changes
public var chapterLink: URL? { get }                // the open chapter's link in `PassageLink.appScheme`
public func escapePalette()                         // Esc: leaves the translations alone, else closes
```

`PaletteRanker.rank` and `SearchRanker.results` take `commands: [PaletteCommand] = []` (those available now) in place of `PaletteCommand.allCases` and `includeCommands`. The Commands group shows `limits.commands` of them and counts them all.

**The commands.** Names are the menus' own. Project 1's verse keys are not here: they act on a selection the palette's field takes the keyboard from. The model runs `home`, `back`, `forward`, the two chapter steps, `readFromHere` (`keepLookup`), `textLayout` (`textLayoutRequests`), `showShortcuts`, `switchTranslation` and `clearRecents`; the rest go to `performCommand`.

| Case | Title | Symbol | Catalogue row, chord | Present when |
|---|---|---|---|---|
| `home` | Home | `house` | `home`, 0 | reading (**call**: it goes nowhere from the front page) |
| `back`, `forward` | Back, Forward | `chevron.left`, `chevron.right` | `backForward`, 0 and 1 | `canGoBack`, `canGoForward` |
| `previousChapter`, `nextChapter` | Previous Chapter, Next Chapter | `arrow.left`, `arrow.right` | `chaptersAnywhere`, 0 and 1 | `hasPreviousChapter`, `hasNextChapter` |
| `readFromHere` | Read From Here | `book` | none | `isLookingUp` |
| `textLayout` | Text & Layout | `textformat.size` | `textLayout`, 0 | reading |
| `showNotesColumn`, `hideNotesColumn` | Show Notes Column, Hide Notes Column | `sidebar.right` | `notesColumn`, 0 | reading, and the column hidden or shown |
| `notesBrowser` | Notes Browser | `note.text` | `notesBrowser`, 0 | always |
| `showShortcuts` | Keyboard Shortcuts | `keyboard` | `keyboardShortcuts`, 0 | always |
| `settings` | Settings | `gearshape` | `settings`, 0 | always |
| `pageStyle(_)` | Page Style: Printed (Lectern, Study, Classic) | `textformat` | none | always |
| `appearance(_)` | Appearance: System (Light, Sepia, Dark) | `circle.lefthalf.filled` | none | always |
| `largerText`, `smallerText` | Larger Text, Smaller Text | `textformat.size.larger`, `textformat.size.smaller` | `textSize`, 0 and 1 | `fontSize` under 28, over 14 |
| `switchTranslation` | Switch Translation… | `character.book.closed` | none | `otherTranslations > 0` |
| `copyChapterLink` | Copy Link to This Chapter | `link` | none | reading |
| `exportNotes` | Export Notes… | `square.and.arrow.up` | `exportNotes`, 0 | always |
| `toggleAssistant` | Ask the Assistant | `sparkles` | `showAssistant`, 0 | reading |
| `newConversation` | New Conversation… | `plus` | `newConversation`, 0 | reading |
| `tryAgain` | Try Again | `arrow.clockwise` | `tryAgain`, 0 | reading and `canRetry` |
| `copyLastReply` | Copy Last Reply | `doc.on.doc` | `copyLastReply`, 0 | `hasLastReply` |
| `addLastReplyAsNote` | Add Last Reply as Note | `note.text.badge.plus` | `addReplyAsNote`, 0 | reading, `hasLastReply`, not saved, not responding |
| `stopAnswering` | Stop Answering | `stop.circle` | `stopAnswering`, 0 | `isResponding` |
| `clearRecents` | Clear Recents | `clock.arrow.circlepath` | none | `hasRecents` |

The catalogue's View group gains one row after Text & Layout: id `textSize`, label "Larger, smaller text", keys `⌘ + −`, spoken "Command plus, Command minus", chords `⌘+` and `⌘-`.

**Switch Translation…** keeps the palette open, clears the query and shows one group, Translations, with every translation but the one being read. Typing, or the first Esc, returns to the whole list; choosing one switches and closes.

- [ ] **Step 1: Write the failing tests.** In `PaletteCommandTests`:

```swift
@Test func everyCommandWithAShortcutShowsTheCataloguesKeys() {
    let rows = Dictionary(uniqueKeysWithValues: ShortcutCatalog.groups.flatMap(\.shortcuts).map { ($0.id, $0) })
    for command in PaletteCommand.all {
        guard let shortcut = command.shortcut else { #expect(command.keycaps == nil, "\(command.id)"); continue }
        guard let row = rows[shortcut.row], row.chords.indices.contains(shortcut.chord) else { Issue.record("\(command.id) names no chord"); continue }
        #expect(command.keycaps == ShortcutCatalog.keycaps(forChord: row.chords[shortcut.chord]), "\(command.id)")
    }
    #expect(PaletteCommand.back.keycaps == ["⌘", "["] && PaletteCommand.nextChapter.keycaps == ["⌥", "⌘", "→"])
    #expect(PaletteCommand.smallerText.keycaps == ["⌘", "−"] && PaletteCommand.toggleAssistant.keycaps == ["⇧", "⌘", "A"])
    #expect(PaletteCommand.all.count == 32 && Set(PaletteCommand.all.map(\.id)).count == 32)
    // The catalogue's new row, and the size's step.
    let row = rows["textSize"]
    #expect(row?.label == "Larger, smaller text" && row?.keys == ["⌘", "+", "−"] && row?.chords == ["⌘+", "⌘-"])
    #expect(ReaderSettings.steppedFontSize(18, by: 1) == 19 && ReaderSettings.steppedFontSize(28, by: 1) == 28 && ReaderSettings.steppedFontSize(14, by: -1) == 14)
}

@Test func aCommandThatCannotRunIsAbsent() {
    var state = PaletteState()                      // the front page: nothing open, nowhere to go back to
    #expect(Set(PaletteCommand.all.filter { $0.isAvailable(in: state) }) == Set(
        [.notesBrowser, .showShortcuts, .settings, .largerText, .smallerText, .exportNotes]
        + PageStyle.allCases.map(PaletteCommand.pageStyle) + AppearanceChoice.allCases.map(PaletteCommand.appearance)))
    state.isReading = true
    let switches: [(PaletteCommand, WritableKeyPath<PaletteState, Bool>)] = [
        (.back, \.canGoBack), (.forward, \.canGoForward), (.previousChapter, \.hasPreviousChapter), (.nextChapter, \.hasNextChapter),
        (.readFromHere, \.isLookingUp), (.clearRecents, \.hasRecents), (.tryAgain, \.canRetry), (.copyLastReply, \.hasLastReply),
        (.addLastReplyAsNote, \.hasLastReply), (.stopAnswering, \.isResponding)]
    for (command, flag) in switches {
        var on = state
        on[keyPath: flag] = true
        #expect(!command.isAvailable(in: state) && command.isAvailable(in: on), "\(command.id)")
    }
    #expect(PaletteCommand.hideNotesColumn.isAvailable(in: state) && !PaletteCommand.showNotesColumn.isAvailable(in: state))
    state.hasLastReply = true
    state.lastReplyIsSaved = true
    state.fontSize = 28
    state.otherTranslations = 1
    #expect(!PaletteCommand.addLastReplyAsNote.isAvailable(in: state) && !PaletteCommand.largerText.isAvailable(in: state))
    #expect(PaletteCommand.smallerText.isAvailable(in: state) && PaletteCommand.switchTranslation.isAvailable(in: state))
    state.pageStyle = .lectern
    #expect(PaletteCommand.pageStyle(.lectern).isCurrent(in: state) && !PaletteCommand.pageStyle(.study).isCurrent(in: state))
}
```

  Existing tests that change with the names:
  - `PaletteRankerTests`: `rank` passes `commands: PaletteCommand.all`. `commandsMatchByTitle` expects `.notesBrowser` ("Notes Browser") and `.settings` ("Settings"). `commandsMatchWordPrefixesNotStrayLetters` keeps its three refusals and expects `rank("brow")` to hold `.notesBrowser`, `rank("page lec")` `.pageStyle(.lectern)` ("Page Style: Lectern") and `rank("sepia")` `.appearance(.sepia)`.
  - `SearchRankerTests`: `commandsCanBeLeftOut` passes `commands: []`.
  - `NavigationModelTests`: `selectingACommandPerformsIt` uses `.settings`; `searchLimitsAndCommandsAreTheModelsToSet` types "keyboard"; the last line of `paletteIncludesMarksFromTheProvider` expects the empty state's `[.commands]`, not `.empty`.

  And in `NavigationModelTests`, with `commands(model)` the Commands group's commands:

```swift
@Test func withNothingTypedTheSuggestedCommandsFollowRecent() throws {
    let (model, _, _) = try recording()
    model.open(matthewOne)
    model.open(matthew(2))
    search(model, "")
    #expect(model.paletteResults.groups.map(\.kind) == [.recent, .commands])
    #expect(commands(model) == [.home, .notesBrowser, .toggleAssistant, .textLayout, .showShortcuts, .switchTranslation])
    model.goHome()                                  // on the front page the ones that cannot run are gone
    model.updatePalette()
    #expect(commands(model) == [.notesBrowser, .showShortcuts, .switchTranslation])
    model.includesCommandsInSearch = false          // the phone offers none
    model.updatePalette()
    #expect(!model.paletteResults.groups.contains { $0.kind == .commands })
}

@Test func theModelRunsItsOwnCommandsAndHandsOnTheRest() throws {
    let (model, _, recents) = try recording()
    var handed: [PaletteCommand] = []
    model.performCommand = { handed.append($0) }
    model.open(matthewOne)
    model.open(matthew(2))
    model.select(.command(.back))
    #expect(model.location == matthewOne && handed.isEmpty)
    model.select(.command(.nextChapter))
    #expect(model.location == matthew(2) && recents.items.count == 2)           // a step is not a recent
    model.select(.command(.showShortcuts))
    model.select(.command(.textLayout))
    #expect(model.isShortcutsShown && model.textLayoutRequests == 1)
    model.select(.command(.pageStyle(.lectern)))
    #expect(handed == [.pageStyle(.lectern)] && !model.isPaletteShown)
    #expect(model.chapterLink == URL(string: "\(PassageLink.appScheme)://mat.2"))
    model.select(.command(.clearRecents))
    #expect(recents.items.isEmpty)
}

@Test func switchTranslationShowsTheTranslationsAloneUntilEscOrTyping() throws {
    let (model, _) = try makeModel()
    model.isPaletteShown = true
    model.select(.command(.switchTranslation))
    #expect(model.isPaletteShown && model.isChoosingTranslation)
    #expect(model.paletteResults.groups.map(\.kind) == [.translations] && model.paletteItems.map(\.title) == ["King James Version"])
    model.escapePalette()                           // the first Esc
    #expect(model.isPaletteShown && !model.isChoosingTranslation && model.paletteResults.groups.first?.kind != .translations)
    model.escapePalette()
    #expect(!model.isPaletteShown)
    model.isPaletteShown = true
    model.select(.command(.switchTranslation))
    model.paletteQuery = "v"                        // typing returns to the whole list too
    #expect(!model.isChoosingTranslation)
    model.select(.command(.switchTranslation))
    model.select(model.paletteItems[0])
    #expect(model.translationID == "KJV" && !model.isPaletteShown)
}
```

- [ ] **Step 2: Run.** `--filter PaletteCommandTests` FAILS to compile.
- [ ] **Step 3: Implement** the commands, the catalogue row and the model's part.
- [ ] **Step 4: Wire the Mac app.**
  - `wirePalette`'s switch runs every app-run command through what its menu item or toolbar button runs today. A page style and an appearance write their raw value to `ReaderSettings.pageStyleKey` and `appearanceKey`; Larger and Smaller Text write `ReaderSettings.steppedFontSize`; Copy Link puts `model.chapterLink` on the pasteboard.
  - `model.appPaletteState` is built from `showNotesColumn`, the three stored settings, and the assistant's `canRetry`, `lastReplyID`, `lastReplySavedNoteID` and `isResponding`.
  - The View menu gains, after Text & Layout: `Button("Larger Text")` with `.keyboardShortcut("+", modifiers: .command)`, disabled at 28, and `Button("Smaller Text")` with `.keyboardShortcut("-", modifiers: .command)`, disabled at 14.
  - `MainWindowView`: `.onChange(of: model.textLayoutRequests)` shows the popover where `TextLayoutMenuButton` would (`:473-479`).
- [ ] **Step 5: Run.** Both suites pass; `everyMenuShortcutInTheMacAppIsListed` finds the two new chords listed.
- [ ] **Step 6: See the keys work.** *The controller's, after this task is reviewed (the handover's rules): the implementer builds the Mac Debug app, confirms the build succeeds, and stops there.* Quit and open it. Read `defaults read com.matthewfurr.ReadingThroughScripture.dev readerFontSize` (unset means 18).
  - Send ⌘+ (Shift held) through System Events: the value is one more. Send ⌘−: it is back.
  - Send ⌘= with no Shift. **If the size does not grow,** give Larger Text a hidden twin with `.keyboardShortcut("=", modifiers: .command)`, add the chord `⌘=` to the `textSize` row and its test, and note it for As built.
  - Leave the size as it was found.
- [ ] **Step 7: Commit.** `feat: every menu command in the palette, with its key; Larger and Smaller Text (finding 5.3)`

---

### Task 8: The Mac panel (spec 5.1, 5.2, 5.4, 5.5)

**Files:**
- Create: `SUI/Keycap.swift` (from `ShortcutsSheet.swift:115-128`), `SUI/PaletteChrome.swift` (the chip row, `ScopeMenu`, the foot, `PaletteKeys`)
- Modify: `SUI/CommandPaletteView.swift`, `SUI/ShortcutsSheet.swift` (`:98-108`), `SUI/PaletteItem.swift`, `MAC/MainWindowView.swift` (`paletteOverlay` `:437-454`), `T/PaletteTests.swift` if a pairing below is not yet held
- Test: `T/PaletteRankerTests.swift` (both suites)

**Interfaces:**
- Consumes: everything Tasks 5 to 7 put on `NavigationModel`.
- Produces:

```swift
/// One key: its glyph on a paper, at least a square, wider for "esc".
struct Keycap: View { init(_ glyph: String, fill: Color = .paperOverlay) }
/// Keycaps `xxs` apart; "–" is plain text between caps.
struct KeycapRow: View { init(_ keys: [String], fill: Color = .paperOverlay) }
extension PaletteItem {
    public var returnVerb: String { get }           // what Return does with the row, for the foot
}
/// The scope's menu, on both apps; `label` draws its capsule.
public struct ScopeMenu<Label: View>: View {
    public init(scope: Binding<SearchScope>, books: [TranslationBook], currentBook: Book?, @ViewBuilder label: () -> Label)
}
public enum PaletteKeys {
    /// Tab steps the chips when there are chips and neither Full Keyboard Access nor VoiceOver is on; otherwise Tab is the system's.
    public static func tabStepsChips(chipCount: Int, fullKeyboardAccess: Bool, voiceOver: Bool) -> Bool
}
// CommandPaletteView's init becomes `public init(model: NavigationModel)`; `selection(after:moving:in:)` stays.
```

- [ ] **Step 1: Write the failing test.** `recent(_:)` wraps a target as a `.recent` row; `mark(_ kind:)` is a `.mark` target in John 15:4; `hit(_ kind:)` is a `SearchMarkHit` of that kind from `SearchRankerTests.entries`; `verse` is any `Verse`.

```swift
@Test func returnsWordFollowsTheRowAndTabIsTheSystemsWhenItMustBe() {
    let john15 = ChapterLocation(book: "JHN", chapter: 15)
    #expect(rank("Rom 8").first?.returnVerb == "Read" && PaletteItem.book(BookCatalog.book(code: "PSA")!).returnVerb == "Read")
    #expect(PaletteItem.verse(verse).returnVerb == "Show verse")
    #expect([.note, .highlight, .bookmark, .thread].map { PaletteItem.mark(hit($0)).returnVerb }
            == ["Show note", "Show highlight", "Show bookmark", "Open conversation"])
    #expect(PaletteItem.translation(translations[1]).returnVerb == "Switch" && PaletteItem.command(.home).returnVerb == "Run")
    #expect(PaletteItem.suggestion(SearchSuggestion(query: "abide", verseCount: 3)).returnVerb == "Search")
    #expect(recent(.search(query: "abide", scope: .wholeBible, verseCount: 3)).returnVerb == "Search")
    #expect(recent(.chapter(john15)).returnVerb == "Read" && recent(.lookup(john15, verse: 4)).returnVerb == "Show verse")
    #expect(recent(mark(.note)).returnVerb == "Show note" && recent(mark(.thread)).returnVerb == "Open conversation")
    #expect(PaletteKeys.tabStepsChips(chipCount: 3, fullKeyboardAccess: false, voiceOver: false))
    #expect(!PaletteKeys.tabStepsChips(chipCount: 3, fullKeyboardAccess: true, voiceOver: false))
    #expect(!PaletteKeys.tabStepsChips(chipCount: 3, fullKeyboardAccess: false, voiceOver: true))
    #expect(!PaletteKeys.tabStepsChips(chipCount: 0, fullKeyboardAccess: false, voiceOver: false))
}
```

- [ ] **Step 2: Run.** `--filter PaletteRankerTests` FAILS to compile.
- [ ] **Step 3: Move the keycap.** `Keycap` and `KeycapRow` go to `SUI/Keycap.swift` with no platform guard; `ShortcutsSheet`'s row uses `KeycapRow(shortcut.keys)` and looks as it did.
- [ ] **Step 4: Build the panel** to spec 5.1, 5.2 and 5.4, tokens only. What the spec leaves open:
  - **Surface:** `Color.paperOverlay` in the `xl` rounded rectangle in place of `.regularMaterial` (`:148`); the stroke and shadow lines stay.
  - **Nothing dims:** in `paletteOverlay` the scrim becomes `Color.clear.contentShape(Rectangle())` with the same tap and `accessibilityHidden`, so a click outside closes the palette and does nothing else.
  - **Field:** the placeholder is "Go to a passage, search, or run a command".
  - **Chip row:** shown with something typed, when `results.chips().count >= 2` or `model.showsScopeMenu`. "All", then each chip's title with `count(of:)` in `ink.secondary` `.monospacedDigit()`. A chip is `.caption` semibold, `sm` by `xxs` inside a `Capsule` on `paperPanel`, the chosen one on `accentWash` with the selected trait, no stroke, `xs` apart.
  - **Scope menu:** at the chip row's trailing end while `model.showsScopeMenu`. Its label is a chip reading the scope's title with `chevron.down`, on `accentWash` when the scope is not Whole Bible. Its items: `SearchScope.sections(in:)`, a divider, "This Book: John" when a book is open, then a "Book" submenu of the translation's books under their canon sections. The scope in force carries the menu's own checkmark.
  - **List:** the lines of `model.paletteResults.showing(model.paletteChip)`, at most 420 pt before it scrolls. A `.suggestion` group has no header; Recent's header has no count.
  - **Rows:** a recent and a suggestion are place rows (symbol, title, subtitle). A command is a place row with, trailing, `checkmark` in `ink.secondary` when `isCurrent`, then `KeycapRow(keycaps, fill: .paperPanel)`. VoiceOver reads the title, then the shortcut by name (the catalogue row's `spoken`, the part for this chord).
  - **Foot:** an `ink.rule` hairline, then one line in `.caption` `ink.secondary`, `md` by `xs`: the `↩` cap and the selected row's `returnVerb`; `↑` `↓` and "Move"; `⇥` and "Narrow" while Tab steps the chips; a spacer; `esc` and "Close" ("Back" while `isChoosingTranslation`, **call**). Caps are `fill: .paperPanel`. With no row there is no Return part. One VoiceOver element.
  - **Keys:** `.onKeyPress(.tab)` steps the chip (`SearchResults.chip(after:by:among:)`, back with Shift) and is handled when `PaletteKeys.tabStepsChips` holds for `NSApplication.shared.isFullKeyboardAccessEnabled` and `NSWorkspace.shared.isVoiceOverEnabled`. Otherwise it is ignored, and the chips are ordinary buttons for both. Esc and the exit command call `model.escapePalette()`. A new chip puts the selection on the first row.
  - **Pairings:** `PaletteTests` already holds `ink.secondary` on `paper.overlay` and `ink.primary` on `paper.panel`. The row dates' `ink.tertiary` now sits on `paper.overlay`: add it at the ratio the suite holds `ink.tertiary` to elsewhere, or give its measured ratio in As built if it holds it to none.
- [ ] **Step 5: Run.** Both suites pass; `SepiaModeTests` passes.
- [ ] **Step 6: See it, in light, dark and Sepia.** *By the handover's rules the implementer builds the Mac Debug app and renders `CommandPaletteView` offscreen on a fixture model for each state below that a render can show (empty, typed, a chip chosen, did you mean, `page`, `back`), in light, dark and Sepia, and opens every picture. The clicks, Tab, Esc and the live window are the controller's and Matt's.* The list, as it would be driven in the live app:
  - ⌘K: Recent and Commands under the field; the window behind is not dimmed and the panel is bright.
  - Type `remain fruit`: the chips, the scope menu, the bold words, the foot's word for the first row.
  - Tab twice: a chip chosen, its kind alone. Choose New Testament in the scope menu: the count changes.
  - Clear and type `frut`: the "Did you mean" row; Return runs it.
  - Type `page`: the styles with the current one checked. Type `back`: its keycaps.
  - Click the page beside the panel: the palette is gone and nothing else happened. ⌘K, Esc: gone.
  - Repeat the first four in Dark and in Sepia: read `defaults read com.matthewfurr.ReadingThroughScripture.dev readerAppearance`, write `dark`, then `sepia`, relaunching for each, then put Matt's value back.
  - Open every picture: no clipped row, the foot on one line, keycaps visible on the panel and on a selected row.
- [ ] **Step 7: Commit.** `feat: the bright palette: recents, commands, chips, scope and a foot (finding 5)`

---

### Task 9: The iPhone's search screen (spec 6)

**Files:**
- Create: `SUI/Phone/PhoneMenuLabel.swift` (the Notes tab's capsule label, moved from `PhoneNotesScreen.swift:150-165`)
- Modify: `SUI/Phone/PhoneSearchScreen.swift`, `SUI/Phone/PhoneNotesScreen.swift` (uses the moved label)
- Test: `T/NavigationModelTests.swift` (both suites)

**Interfaces:**
- Consumes: `NavigationModel` (Tasks 5 to 7), `ScopeMenu` (Task 8), `SearchOrder` (Task 2).
- Produces: `struct PhoneMenuLabel: View { init(_ name: String, choice: String, isChanged: Bool) }`, drawn as the Notes tab draws it.

- [ ] **Step 1: Write the test.**

```swift
/// The phone keeps its query and results while the reader visits one; its empty state is Recent alone.
@Test func thePhonesSearchShowsRecentAndTakesARecentSearchIntoItsField() throws {
    let (phone, _, _) = try recording()
    phone.searchLimits = .phone
    phone.includesCommandsInSearch = false
    search(phone, "tempter")
    phone.select(try #require(phone.paletteItems.first { if case .verse = $0 { true } else { false } }), keepingQuery: true)
    #expect(phone.paletteQuery == "tempter" && phone.location == matthew(4))
    search(phone, "")
    #expect(phone.paletteResults.groups.map(\.kind) == [.recent])
    phone.select(try #require(phone.paletteItems.first { $0.title == "tempter" }), keepingQuery: true)
    #expect(phone.paletteQuery == "tempter" && phone.paletteResults.groups.contains { $0.kind == .scripture })
    search(phone, "jesis")                          // a misspelling's row fills the field the same way
    phone.select(try #require(phone.paletteItems.first), keepingQuery: true)
    #expect(phone.paletteQuery == "jesus")
}
```

- [ ] **Step 2: Run.** The iOS command with `-only-testing:ScriptureUITests/NavigationModelTests`. If Tasks 5 and 6 already make it pass, it stands as the pin for the screen's behaviour; say so and go on.
- [ ] **Step 3: Build the screen.**
  - **Nothing typed:** when the model's empty state has a Recent group, a list section headed "Recent" with a trailing "Clear" (`.caption`, `accent`; `recents.clear()`, then a refresh), its rows `SearchPlaceRow`s. **(call: the phone has no commands, so Clear Recents lives here.)** With no recents, today's sentence stays.
  - **A recent or a suggestion chosen:** `navigation.select(item, keepingQuery: true)`. A search and a suggestion stay on the search tab; a chapter, a lookup and a mark go to the reader as rows do today (a conversation to Ask).
  - **Did you mean:** the `.suggestion` group comes first with no header: one `SearchPlaceRow` with `magnifyingglass`, its title and its count.
  - **The menus:** under the chips, a row of `PhoneMenuLabel` capsules. The scope (`ScopeMenu`) shows while `navigation.showsScopeMenu`, changed when not Whole Bible. Order (a `Picker` over `SearchOrder.allCases`) shows while the Scripture chip is chosen, changed when not Best match. The row also shows above "No matches" when the scope is narrower than the whole Bible, so it can be widened.
  - **The four chips** and Show all stay as they are; Show all and a translation switched here run `refreshPalette()` in a `Task`.
- [ ] **Step 4: Run.** The iOS suite and the package suite pass.
- [ ] **Step 5: See it in the simulator.** Build the iOS Debug app and launch it. With the iOS Simulator control tool, a screenshot at each:
  - Open a chapter from Library, then the search tab: Recent lists it.
  - Type `remain fruit`: verses with both words bold. Choose New Testament in the scope menu: the count changes.
  - Choose the Scripture chip, then Order, Bible order: the list starts at the earliest book.
  - Type `frut`: the "Did you mean" row; tap it: the field reads "fruit".
  - Tap a verse, come back to search, clear the field: Recent lists the search and the verse.
  - Choose no row that writes a note. Say plainly which of these could not be driven.
- [ ] **Step 6: Commit.** `feat: the iPhone's search: the new search, scope, order, did you mean and recents (finding 6)`

---

### Task 10: Docs and whole-project verification

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, `docs/superpowers/specs/2026-11-16-milestone-10-finding-design.md` (section 11), `docs/BACKLOG.md` only if something was set aside

**Interfaces:**
- Consumes: everything above.
- Produces: the documents in step with the code; a branch ready for Matt's list.

- [ ] **Step 1: `DESIGN.md`** (spec 7).
  - Section 2, the No Opacity Tint Rule (`:235`): one exception, the panel's shadow.
  - Section 4, Material Vocabulary (`:288-290`): the Floating panel is solid `paper.overlay`, no material; the Scrim entry goes; a click outside closes. The One Shadow Rule (`:295`) stands.
  - Section 5: the recent, suggestion and command rows (Rows › Search rows, `:326`); the ⌘K palette (`:360`) with its placeholder, empty state, chips and Tab, scope menu, foot, commands and 420 pt; the **chip** and the **keycap** (its two fills) named as components; every new symbol of Tasks 6 and 7 in the SF Symbols inventory.
  - Section 7, iPhone search: Recent, the scope and order menus, the suggestion row.
- [ ] **Step 2: `DESIGN.json`.** The same facts where the file holds them (`floating-panel` and `panel-shadow` at `:326-335`, the palette component at `:605-617`). `python3 -I -m json.tool DESIGN.json` prints it without error.
- [ ] **Step 3: `README.md`.** Keyboard (`:58`): ⌘K goes to a passage, searches or runs a command; ⌘+ and ⌘− change the text size. A short **Search** part: the five forms of 4.1 with the spec's examples, scope, did you mean, and that `love` finds loved but not "loving". The lines that name the palette (`:60`, `:70`, `:94`, `:106`; `:94` and `:106` name commands as "Open Notes Browser" and "Ask the Assistant", which now read as the palette shows them) and the iPhone's Search line (`:184`).
- [ ] **Step 4: The spec's section 11, As built.** What was built, task by task, with:
  - The index: Task 2's table, the database's size before and after as measured, and the benchmark's median.
  - Every **(call)** made here: the apostrophe rule; a link recorded as a lookup; the scope returning when the field is cleared on both apps; the chip kept while typing; the order kept while the app runs; Home absent on the front page; the foot's "Back"; the phone's Clear.
  - What ⌘= did, and the one-letter worst case (about 77 ms off the main actor, in `sqlite3`).
  - The new test counts, and anything a step could not see or drive.
- [ ] **Step 5: `docs/BACKLOG.md`.** Its three lines on this project (word forms, several translations at once, the Notes Browser's own field) stand. Add a line for anything this build set aside.
- [ ] **Step 6: Run everything, one after another.** The package suite; the iOS suite; the Mac Debug build; the iOS Debug build. All pass and both builds succeed. Record the test counts.
- [ ] **Step 7: Look at each new surface once more on the final build** (spec 10), in light, dark and Sepia: the palette empty, typed, with a chip chosen and with did-you-mean; the phone's search empty and typed. Open every picture. Say plainly what was not seen.
- [ ] **Step 8: Leave the Mac Debug app running the final build.** *The controller's, with Step 7's live looks.* `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`, then `open Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`. The controller runs `Scripts/install-phone.sh debug`.
- [ ] **Step 9: Commit.** `/usr/bin/git add` the changed documents, then `docs: finding as built; DESIGN and README in step`.
- [ ] **Step 10: Hand Matt his list** (spec 10, "For Matt"), unchanged, with what this session could not check beside each item.

---

## Where each spec requirement is pinned

Each test is named for the bullet it pins. The ones a name does not make plain, and those pinned by a step and not a test:

| Spec | Pinned by |
|---|---|
| 4.1: the table, operators, quotes, exclusions alone; case and accents | Task 1's parsing tests; Task 2 cycle A against the fixture (`ABÍD`) |
| 4.1: marks gain phrases and exclusions; bookmarks by passage alone | Task 4 `marksTakePhrasesAndExclusions` |
| 4.1 **(call)**: the Notes window's field unchanged | `NotesBrowserQuery` untouched; `NotesBrowserQueryTests` unchanged (Task 4 Step 4) |
| 4.2: the menu's entries, Apocrypha only where it exists, This Book, Book | Task 2 `eachScopeReturnsOnlyItsBooksAndTheCountsMatch` (`sections`); Task 8 Steps 4 and 6 |
| 4.2: limits Scripture alone; **(call)** returns to Whole Bible | Task 5 `scriptureIsSearchedInTheScopeAndCounted`, `theScopeReturnsToTheWholeBible` |
| 4.3: best match first; the count is the scope's; **(call)** the phone's order menu | Task 2 `eachScopeReturnsOnlyItsBooksAndTheCountsMatch`; Task 5 `scriptureIsSearchedInTheScopeAndCounted`; Task 9 Steps 3 and 5 |
| 4.4: the row, its count, Return or a click; nearness; nothing without a find | Task 3's three tests and `aSuggestionComesFromTheTranslationsOwnWordsAndOnlyWhenItFindsSomething`; Task 5 `aMisspellingOffersARowThatRunsTheSearch` |
| 4.5: off the main thread; a newer keystroke abandons | Task 5 `aNewerKeystrokeAbandonsAnOlderSearchsResult` (its first line is `offMain`) |
| 4.5: only the chosen translation and scope are read; the 50 ms budget, recorded | Task 2's table and layout; `eachTranslationHasItsOwnUnstemmedIndexOverUnbrokenRuns`, `aCommonWordInTheWholeBibleIsWithinFiftyMilliseconds`; Task 10 Step 4 |
| 4.6: schema 3 rebuilds an old database; nothing synced changes | Task 2 `theBuildScriptsPatternReadsTheSchemaVersion`, Step 7, the existing `schemaMismatchThrows`; Task 6 `recentsStayOnTheDevice` |
| 5.1: nothing dims, a solid panel, a click outside, Esc; **(call)** 420 pt; the placeholder; the foot | Task 8 Steps 4 and 6; `returnsWordFollowsTheRowAndTabIsTheSystemsWhenItMustBe` |
| 5.2: Recent, five, newest first, the open chapter left out, twenty kept, Clear Recents | Task 6's `RecentsTests`, `withNothingTypedThePaletteShowsRecentWithoutTheOpenChapter`; Task 7 `theModelRunsItsOwnCommandsAndHandsOnTheRest` |
| 5.2 **(call)**: what is and is not recorded | Task 6 `goingSomewhereOnPurposeIsRecorded`, `pagingHistoryRestoringAndFailuresAreNotRecorded`, `aSearchThatLedSomewhereIsRecordedWithWhatWasOpened` |
| 5.2: the six commands; **(call)** the menus' names | Task 7 `withNothingTypedTheSuggestedCommandsFollowRecent`; its table and the `PaletteRankerTests` lines it changes |
| 5.3: every command, its key from the catalogue; **(call)** Larger and Smaller Text | Task 7's table, `everyCommandWithAShortcutShowsTheCataloguesKeys`, Step 6; project 1's `everyMenuShortcutInTheMacAppIsListed` |
| 5.3 **(call)**: the verse keys are not commands | `PaletteCommand` has no such case (`PaletteCommand.all.count == 32`) |
| 5.3 **(call)**: a command that cannot run is absent; Switch Translation… | Task 7 `aCommandThatCannotRunIsAbsent`, `switchTranslationShowsTheTranslationsAloneUntilEscOrTyping` |
| 5.4: chips, Tab and Shift-Tab, more rows, the scope menu's place | Task 5 `chipsAreTheKindsPresentAndTabGoesRoundThem`, `aChosenChipShowsItsKindAloneWithMoreRows`; Task 8's test, Steps 4 and 6 |
| 5.5: what stays | the existing `NavigationModelTests` and `SearchRankerTests`, unchanged but for the lines Task 7 names |
| 6: the phone; **(call)** Recent as its empty state; no commands | Task 9; Task 7 `withNothingTypedTheSuggestedCommandsFollowRecent` |
| 7: design changes; 10: seen by eye | Task 10 Steps 1, 2 and 7; Task 8 Step 6; Task 9 Step 5 |
