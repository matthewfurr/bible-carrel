# Milestone 1: Scaffold and Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Swift package that converts the holybooks JSON into a bundled SQLite Bible, a read API over it with reference parsing and full-text search, and a runnable macOS preview that prints Matthew 5 in ESV.

**Architecture:** One SwiftPM package `ScriptureKit` holds all logic: `BibleImporterCore` (JSON → SQLite), `ScriptureData` (read-only access, canon catalog, reference parser), a `bible-importer` CLI, and a `ScriptureMacPreview` SwiftUI executable used only until the Xcode app target exists in milestone 2. The generated database lives in `Build/` and is never committed.

**Tech Stack:** Swift 6.2, SwiftPM, SwiftUI, GRDB.swift 7 (the only dependency), SQLite FTS5, `swift test` via XCTest.

**Spec:** `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`

## Global Constraints

- Swift tools version 6.2, platforms `.macOS(.v26)` and `.iOS(.v26)`.
- Only third-party dependency: `https://github.com/groue/GRDB.swift` from `7.0.0`.
- Source data pinned to holybooks commit `0dab245f361980d2af3f4075cba3fbe8c4fa31b2`; only the `EN/` tree is used.
- Translations imported: `AMP, ASV, CPDV, ERV, ESV, KJV, NASB, WEB`. `BOOKS` is skipped.
- Test fixtures come only from public-domain translations (WEB, KJV). No ESV, NASB, AMP or ERV text enters git.
- `Build/` and `bible.sqlite` are gitignored. The cache for downloaded source lives at `~/Library/Caches/ReadingThroughScripture/holybooks/<sha>/`.
- Book codes are the holybooks codes (`GEN` … `MAL`, `MAT` … `REV`, Apocrypha `1ES` … `WIS`). Files whose code is not in the canonical catalog (`NAH`, `LKA`) are skipped with a warning, not an error.
- No emoji anywhere in UI; SF Symbols only.
- Xcode is not installed yet. Everything in this milestone builds with the Command Line Tools via `swift build` and `swift test`. No `.xcodeproj` is created here.

## Review Focus

1. A chapter whose verse numbers are not dense (ESV omits Matthew 17:21, Mark 7:16 and others): `chapter()` must return exactly the verses present, in order, and nothing must index by verse number minus one. Pinned in Task 3 and Task 5.
2. A verse entry whose `ID` is not an integer or a chapter whose `ID` has no trailing number: the importer skips it with a warning and continues the book. Pinned in Task 2.
3. A translation missing a book, or a book directory holding a non-canonical code: the import of the remaining books completes and the `translation_book` table reflects what is actually present. Pinned in Task 3.
4. Reference input with mixed case, trailing whitespace, an en dash in a range, or a book that does not exist: the parser normalises or returns nil, never crashes. Pinned in Task 6.
5. A search string containing FTS5 operators or quotes (`"poor in spirit"`, `spirit*`, `a OR b`, a lone `"`): the query is sanitised into a plain phrase and never throws. Pinned in Task 5.

---

### Task 1: Package scaffold and canon catalog

**Files:**
- Create: `Packages/ScriptureKit/Package.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureData/Canon.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureData/BookCatalog.swift`
- Create: `Packages/ScriptureKit/Sources/BibleImporterCore/Placeholder.swift` (empty enum, replaced in Task 2)
- Create: `Packages/ScriptureKit/Tests/ScriptureDataTests/BookCatalogTests.swift`
- Create: `.gitignore` (repo root)

**Interfaces:**
- Produces:
  - `public enum Canon: String, Codable, Sendable, CaseIterable { case oldTestament = "OT", newTestament = "NT", apocrypha = "AP" }`
  - `public struct Book: Identifiable, Hashable, Codable, Sendable { public let id: String; public let canon: Canon; public let order: Int; public let name: String; public let shortName: String; public let aliases: [String] }`
  - `public enum BookCatalog { public static let all: [Book]; public static func book(code: String) -> Book? }` where `all` is in canon order: 39 OT, 27 NT, 18 AP (84 total). `order` is 1-based within the whole list.

- [ ] **Step 1: Write `Package.swift`**

Targets: `ScriptureData` (library), `BibleImporterCore` (library, depends on `ScriptureData` and `GRDB`), `bible-importer` (executable, depends on `BibleImporterCore`), `ScriptureMacPreview` (executable, depends on `ScriptureData`), test targets `ScriptureDataTests` (depends on `ScriptureData`, `BibleImporterCore`) and `BibleImporterCoreTests` (depends on `BibleImporterCore`, resources `Fixtures/`). `ScriptureData` also depends on `GRDB`. Swift language mode 6.

- [ ] **Step 2: Write `.gitignore`**

```
.build/
Build/
*.sqlite
*.sqlite-*
.DS_Store
.superpowers/
xcuserdata/
```

- [ ] **Step 3: Write the failing test**

```swift
final class BookCatalogTests: XCTestCase {
    func testCatalogHas84BooksInCanonOrder() {
        XCTAssertEqual(BookCatalog.all.count, 84)
        XCTAssertEqual(BookCatalog.all.filter { $0.canon == .oldTestament }.count, 39)
        XCTAssertEqual(BookCatalog.all.filter { $0.canon == .newTestament }.count, 27)
        XCTAssertEqual(BookCatalog.all.filter { $0.canon == .apocrypha }.count, 18)
        XCTAssertEqual(BookCatalog.all.first?.id, "GEN")
        XCTAssertEqual(BookCatalog.all[38].id, "MAL")
        XCTAssertEqual(BookCatalog.all[39].id, "MAT")
        XCTAssertEqual(BookCatalog.all[65].id, "REV")
        XCTAssertEqual(BookCatalog.all.map(\.order), Array(1...84))
    }
    func testLookupByCode() {
        XCTAssertEqual(BookCatalog.book(code: "NAM")?.name, "Nahum")
        XCTAssertEqual(BookCatalog.book(code: "PHP")?.name, "Philippians")
        XCTAssertEqual(BookCatalog.book(code: "SNG")?.name, "Song of Solomon")
        XCTAssertNil(BookCatalog.book(code: "NAH"))
        XCTAssertNil(BookCatalog.book(code: "LKA"))
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd Packages/ScriptureKit && swift test --filter BookCatalogTests`
Expected: compile error, `BookCatalog` not found.

- [ ] **Step 5: Implement `Canon.swift` and `BookCatalog.swift`**

`BookCatalog.all` is a literal array. Codes in order:
OT: `GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL`.
NT: `MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV`.
AP: `TOB JDT ESG WIS SIR BAR LJE S3Y SUS BEL 1MA 2MA 1ES MAN PS2 3MA 2ES 4MA`.
`name` is the common English name ("Song of Solomon", "Revelation", "1 Corinthians"); `shortName` is the three-to-five letter form used in references ("Gen", "Song", "Rev", "1 Cor"); `aliases` holds extra accepted spellings for the parser (`["Psalm", "Pss"]` for PSA, `["Song of Songs", "Canticles"]` for SNG, `["Revelations"]` for REV, `["Phil"]` for PHP, `["Philem"]` for PHM, `["Jn"]` for JHN, `["Mk"]` for MRK, `["Lk"]` for LUK, `["Mt"]` for MAT). Apocrypha names: Tobit, Judith, Esther (Greek), Wisdom of Solomon, Sirach, Baruch, Letter of Jeremiah, Prayer of Azariah, Susanna, Bel and the Dragon, 1 Maccabees, 2 Maccabees, 1 Esdras, Prayer of Manasseh, Psalm 151, 3 Maccabees, 2 Esdras, 4 Maccabees.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd Packages/ScriptureKit && swift test --filter BookCatalogTests`
Expected: 2 tests pass.

- [ ] **Step 7: Commit**

```bash
git add .gitignore Packages/ScriptureKit docs/
git commit -m "feat: scaffold ScriptureKit package with canon catalog"
```

---

### Task 2: Holybooks JSON parsing and verse merging

**Files:**
- Create: `Packages/ScriptureKit/Sources/BibleImporterCore/HolyBookFile.swift`
- Create: `Packages/ScriptureKit/Sources/BibleImporterCore/VerseMerger.swift`
- Create: `Packages/ScriptureKit/Sources/BibleImporterCore/ImportWarning.swift`
- Delete: `Packages/ScriptureKit/Sources/BibleImporterCore/Placeholder.swift`
- Create: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/Fixtures/EN/NT/MAT/WEB.json`
- Create: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/Fixtures/EN/OT/PSA/KJV.json`
- Create: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/Fixtures/EN/AP/TOB/WEB.json`
- Create: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/Fixtures/EN/NT/LKA/WEB.json` (a copy of a tiny hand-written file with one chapter, used to prove skipping)
- Create: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/VerseMergerTests.swift`
- Create: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/HolyBookFileTests.swift`

**Interfaces:**
- Produces:
  - `public struct HolyBookFile: Decodable, Sendable { public let version: String; public let ID: String; public let name: String; public let text: [Chapter]; public struct Chapter: Decodable, Sendable { public let ID: String; public let name: String; public let text: [Entry] }; public struct Entry: Decodable, Sendable { public let ID: String; public let text: String } }`
  - `public extension HolyBookFile.Chapter { var number: Int? }` parses the integer after the last `.` in `ID` (`"NT:MAT.5"` → 5).
  - `public struct MergedVerse: Equatable, Sendable { public let number: Int; public let text: String; public let breakAfter: Bool }`
  - `public struct ImportWarning: Error, CustomStringConvertible, Sendable { public let message: String }`
  - `public enum VerseMerger { public static func merge(_ entries: [HolyBookFile.Entry], warnings: inout [ImportWarning]) -> [MergedVerse] }`

- [ ] **Step 1: Download the fixtures from the pinned commit**

```bash
B=https://raw.githubusercontent.com/bobuk/holybooks/0dab245f361980d2af3f4075cba3fbe8c4fa31b2/EN
F=Packages/ScriptureKit/Tests/BibleImporterCoreTests/Fixtures/EN
mkdir -p $F/NT/MAT $F/OT/PSA $F/AP/TOB $F/NT/LKA
curl -sL $B/NT/MAT/WEB.json -o $F/NT/MAT/WEB.json
curl -sL $B/OT/PSA/KJV.json -o $F/OT/PSA/KJV.json
curl -sL $B/AP/TOB/WEB.json -o $F/AP/TOB/WEB.json
```

Then write `$F/NT/LKA/WEB.json` by hand: `{"version":"WEB","ID":"NT:LKA(WEB)","name":"Stray","text":[{"ID":"NT:LKA.1","name":"Stray 1","text":[{"ID":"1","text":"stray"}]}]}`.

- [ ] **Step 2: Write the failing tests**

```swift
final class HolyBookFileTests: XCTestCase {
    func testDecodesMatthewWEB() throws {
        let url = Bundle.module.url(forResource: "WEB", withExtension: "json", subdirectory: "Fixtures/EN/NT/MAT")!
        let file = try JSONDecoder().decode(HolyBookFile.self, from: Data(contentsOf: url))
        XCTAssertEqual(file.version, "WEB")
        XCTAssertEqual(file.text.count, 28)
        XCTAssertEqual(file.text[4].number, 5)
        XCTAssertEqual(file.text[4].text.count, 74)
    }
    func testChapterNumberIsNilWhenMalformed() {
        let chapter = HolyBookFile.Chapter(ID: "NT:MAT.x", name: "", text: [])
        XCTAssertNil(chapter.number)
    }
}

final class VerseMergerTests: XCTestCase {
    private func entries(_ pairs: [(String, String)]) -> [HolyBookFile.Entry] {
        pairs.map { HolyBookFile.Entry(ID: $0.0, text: $0.1) }
    }
    func testMergesPoetryLinesAndBreaks() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([
            ("1", "Seeing the multitudes."), ("2", "He opened his mouth,"), ("2", ""),
            ("3", "Blessed are the poor in spirit,"), ("3", "for theirs is the Kingdom."), ("3", ""),
            ("4", "Blessed are those who mourn,"), ("4", "for they shall be comforted."),
        ]), warnings: &warnings)
        XCTAssertEqual(merged, [
            MergedVerse(number: 1, text: "Seeing the multitudes.", breakAfter: false),
            MergedVerse(number: 2, text: "He opened his mouth,", breakAfter: true),
            MergedVerse(number: 3, text: "Blessed are the poor in spirit,\nfor theirs is the Kingdom.", breakAfter: true),
            MergedVerse(number: 4, text: "Blessed are those who mourn,\nfor they shall be comforted.", breakAfter: false),
        ])
        XCTAssertTrue(warnings.isEmpty)
    }
    func testSkipsNonIntegerIdsWithWarning() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("1", "a"), ("1a", "b"), ("2", "c")]), warnings: &warnings)
        XCTAssertEqual(merged.map(\.number), [1, 2])
        XCTAssertEqual(warnings.count, 1)
    }
    func testVerseWithOnlyEmptyEntriesIsDropped() {
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(entries([("1", "a"), ("2", ""), ("3", "c")]), warnings: &warnings)
        XCTAssertEqual(merged.map(\.number), [1, 3])
        XCTAssertEqual(warnings.count, 1)
    }
    func testMatthew5FixtureYields48Verses() throws {
        let url = Bundle.module.url(forResource: "WEB", withExtension: "json", subdirectory: "Fixtures/EN/NT/MAT")!
        let file = try JSONDecoder().decode(HolyBookFile.self, from: Data(contentsOf: url))
        var warnings: [ImportWarning] = []
        let merged = VerseMerger.merge(file.text[4].text, warnings: &warnings)
        XCTAssertEqual(merged.count, 48)
        XCTAssertEqual(merged.map(\.number), Array(1...48))
        XCTAssertTrue(merged[2].text.contains("\n"))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd Packages/ScriptureKit && swift test --filter BibleImporterCoreTests`
Expected: compile errors for missing types.

- [ ] **Step 4: Implement `HolyBookFile.swift`, `ImportWarning.swift`, `VerseMerger.swift`**

`Chapter` and `Entry` need public memberwise inits so tests can build them. Merge rule: walk entries in order; consecutive entries with the same `ID` form one group; `number = Int(ID)` else append a warning and skip the group; `text` = non-empty entry texts joined with `"\n"`; `breakAfter` = the group's last entry text is empty; a group with no non-empty text appends a warning and is dropped.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Packages/ScriptureKit && swift test --filter BibleImporterCoreTests`
Expected: 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: parse holybooks JSON and merge poetry lines into verses"
```

---

### Task 3: SQLite schema and database writer

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureData/BibleSchema.swift`
- Create: `Packages/ScriptureKit/Sources/BibleImporterCore/BibleDatabaseWriter.swift`
- Create: `Packages/ScriptureKit/Sources/BibleImporterCore/SourceTree.swift`
- Create: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/BibleDatabaseWriterTests.swift`

**Interfaces:**
- Consumes: `HolyBookFile`, `VerseMerger`, `BookCatalog` (Tasks 1 and 2).
- Produces:
  - `public enum BibleSchema { public static let version = 1; public static func create(in db: GRDB.Database) throws }` creating:
    ```sql
    CREATE TABLE translation (id TEXT PRIMARY KEY, title TEXT NOT NULL);
    CREATE TABLE book (id TEXT PRIMARY KEY, canon TEXT NOT NULL, sort_order INTEGER NOT NULL, name TEXT NOT NULL, short_name TEXT NOT NULL);
    CREATE TABLE translation_book (translation_id TEXT NOT NULL REFERENCES translation(id), book_id TEXT NOT NULL REFERENCES book(id), chapter_count INTEGER NOT NULL, PRIMARY KEY (translation_id, book_id));
    CREATE TABLE verse (id INTEGER PRIMARY KEY, translation_id TEXT NOT NULL, book_id TEXT NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL, text TEXT NOT NULL, break_after INTEGER NOT NULL DEFAULT 0);
    CREATE UNIQUE INDEX verse_lookup ON verse(translation_id, book_id, chapter, verse);
    CREATE VIRTUAL TABLE verse_fts USING fts5(text, content='verse', content_rowid='id', tokenize='porter unicode61');
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    ```
  - `public struct SourceTree: Sendable { public init(root: URL); public func bookFiles(translations: Set<String>) throws -> [BookFileRef] }` where `public struct BookFileRef: Sendable { let translationID: String; let bookCode: String; let canonFolder: String; let url: URL }`, walking `root/EN/{OT,NT,AP}/{CODE}/{VERSION}.json`.
  - `public struct ImportReport: Sendable { public var verseCount: Int; public var bookCount: Int; public var warnings: [ImportWarning] }`
  - `public struct BibleDatabaseWriter { public init(outputURL: URL) throws; public func importAll(from tree: SourceTree, translations: [String: String], sourceCommit: String) throws -> ImportReport }` where `translations` maps id → title (from `EN/index.json`).

- [ ] **Step 1: Write the failing tests**

```swift
final class BibleDatabaseWriterTests: XCTestCase {
    func testImportsFixturesIntoSQLite() throws {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        let writer = try BibleDatabaseWriter(outputURL: out)
        let report = try writer.importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "test")
        XCTAssertEqual(report.bookCount, 3)                 // MAT/WEB, PSA/KJV, TOB/WEB; LKA skipped
        XCTAssertEqual(report.warnings.count, 1)            // the LKA skip
        let q = try DatabaseQueue(path: out.path)
        try q.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM translation"), 2)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT chapter_count FROM translation_book WHERE translation_id='KJV' AND book_id='PSA'"), 150)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM verse WHERE translation_id='KJV' AND book_id='PSA' AND chapter=119"), 176)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM verse WHERE translation_id='WEB' AND book_id='MAT' AND chapter=5"), 48)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT canon FROM book WHERE id='TOB'"), "AP")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM verse_fts WHERE verse_fts MATCH '\"poor in spirit\"'"), 1)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key='source_commit'"), "test")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/ScriptureKit && swift test --filter BibleDatabaseWriterTests`
Expected: compile error, `BibleDatabaseWriter` not found.

- [ ] **Step 3: Implement `BibleSchema.swift`, `SourceTree.swift`, `BibleDatabaseWriter.swift`**

Writer opens a `DatabaseQueue` at `outputURL` (deleting any existing file first), creates the schema, inserts all `BookCatalog.all` rows, then for each `BookFileRef` whose code is in the catalog decodes the file, merges verses chapter by chapter, inserts verse rows inside one transaction per book, records `translation_book.chapter_count` as the number of chapters with at least one verse, and skips unknown codes with a warning. After all books: `INSERT INTO verse_fts(verse_fts) VALUES('rebuild')`, write `meta` rows `schema_version`, `source_commit`, `built_at` (ISO 8601), then `VACUUM`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/ScriptureKit && swift test --filter BibleDatabaseWriterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: write bible.sqlite with FTS5 index from holybooks source"
```

---

### Task 4: Importer CLI and build scripts

**Files:**
- Create: `Packages/ScriptureKit/Sources/bible-importer/main.swift`
- Create: `Scripts/fetch-holybooks.sh`
- Create: `Scripts/build-bible.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: `BibleDatabaseWriter`, `SourceTree`, `ImportReport` (Task 3).
- Produces: `Build/bible.sqlite` on disk; `Scripts/build-bible.sh` is the one command every later milestone calls.

- [ ] **Step 1: Write `main.swift`**

Usage: `bible-importer --source <dir containing EN/> --output <path> --commit <sha>`. Reads `EN/index.json` for titles (`{"versions":[{"ID":"ESV","title":"English Standard Version"}]}`), imports the eight translations from Global Constraints, prints the report (`verses: N, books: N, warnings: N`) and each warning to stderr, exits 1 on a thrown error. Parse `CommandLine.arguments` by hand; no argument-parser dependency.

- [ ] **Step 2: Write `Scripts/fetch-holybooks.sh`**

Downloads `https://github.com/bobuk/holybooks/archive/0dab245f361980d2af3f4075cba3fbe8c4fa31b2.tar.gz` into `~/Library/Caches/ReadingThroughScripture/holybooks/`, extracts only `*/EN/*` into `.../holybooks/0dab245f361980d2af3f4075cba3fbe8c4fa31b2/`, and is a no-op when that directory already holds `EN/index.json`. Prints the directory path on stdout. `set -euo pipefail`.

- [ ] **Step 3: Write `Scripts/build-bible.sh`**

Runs fetch, then `swift run -c release --package-path Packages/ScriptureKit bible-importer --source "$SRC" --output Build/bible.sqlite --commit 0dab245f…`. Creates `Build/`. Prints the output path and file size.

- [ ] **Step 4: Run the real build**

Run: `bash Scripts/build-bible.sh`
Expected: completes in under two minutes; stderr lists warnings only for `NAH` and `LKA`; `Build/bible.sqlite` exists.

- [ ] **Step 5: Verify row counts**

Run:
```bash
sqlite3 Build/bible.sqlite "SELECT translation_id, count(*) FROM verse GROUP BY 1; SELECT count(*) FROM translation_book WHERE translation_id='ESV'; SELECT text FROM verse WHERE translation_id='ESV' AND book_id='JHN' AND chapter=3 AND verse=16;"
```
Expected: eight translation rows each between 30,000 and 32,000 verses (WEB and CPDV higher with Apocrypha); ESV has 66 books; John 3:16 prints.

- [ ] **Step 6: Write `README.md`**

Short: what the project is, prerequisites (Xcode 26, Apple Intelligence), `bash Scripts/build-bible.sh`, `swift test`, link to the spec and plan, a one-line note that the bundled database is generated and not committed.

- [ ] **Step 7: Commit**

```bash
git add Packages/ScriptureKit Scripts README.md
git commit -m "feat: bible-importer CLI and build scripts for bible.sqlite"
```

---

### Task 5: `BibleStore` read API

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureData/Models.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureData/BibleStore.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureData/SearchQuery.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureDataTests/BibleStoreTests.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureDataTests/FixtureDatabase.swift`

**Interfaces:**
- Consumes: `BibleDatabaseWriter` (test-only, to build a fixture database from the Task 2 fixtures), `BookCatalog`.
- Produces:
  - `public struct Translation: Identifiable, Hashable, Sendable { public let id: String; public let title: String }`
  - `public struct VerseLocation: Hashable, Codable, Sendable { public let book: String; public let chapter: Int; public let verse: Int }`
  - `public struct Verse: Identifiable, Hashable, Sendable { public var id: VerseLocation; public let translationID: String; public let text: String; public let breakAfter: Bool }`
  - `public struct TranslationBook: Hashable, Sendable { public let book: Book; public let chapterCount: Int }`
  - `public final class BibleStore: Sendable { public init(databaseURL: URL) throws; public func translations() throws -> [Translation]; public func books(in translationID: String) throws -> [TranslationBook]; public func chapter(_ location: (book: String, chapter: Int), translationID: String) throws -> [Verse]; public func search(_ text: String, translationID: String, limit: Int) throws -> [Verse] }`
  - `public enum SearchQuery { public static func ftsPhrase(from raw: String) -> String? }` returning `nil` for input that is empty after trimming, otherwise the trimmed text with internal `"` removed, wrapped in double quotes (a phrase query), so operators are never interpreted.
  - `public enum BibleStoreError: Error { case databaseMissing(URL) }`

- [ ] **Step 1: Write `FixtureDatabase.swift`**

A test helper: `static func build() throws -> URL` that imports `BibleImporterCoreTests` fixtures? Test targets cannot share resources, so instead copy the same three fixture files plus the stray one into `Tests/ScriptureDataTests/Fixtures/` (same paths) and declare them as resources for `ScriptureDataTests`. `build()` runs `BibleDatabaseWriter` into a temp file once per process (cache in a static).

- [ ] **Step 2: Write the failing tests**

```swift
final class BibleStoreTests: XCTestCase {
    func testTranslationsAndBooks() throws {
        let store = try BibleStore(databaseURL: try FixtureDatabase.build())
        XCTAssertEqual(try store.translations().map(\.id), ["KJV", "WEB"])
        let web = try store.books(in: "WEB")
        XCTAssertEqual(web.map(\.book.id), ["MAT", "TOB"])      // canon order
        XCTAssertEqual(web.first?.chapterCount, 28)
    }
    func testChapterReturnsVersesInOrderWithPoetry() throws {
        let store = try BibleStore(databaseURL: try FixtureDatabase.build())
        let verses = try store.chapter((book: "MAT", chapter: 5), translationID: "WEB")
        XCTAssertEqual(verses.count, 48)
        XCTAssertEqual(verses[2].id, VerseLocation(book: "MAT", chapter: 5, verse: 3))
        XCTAssertTrue(verses[2].text.contains("\n"))
        XCTAssertTrue(verses[1].breakAfter)
    }
    func testChapterWithGapsIsNotPadded() throws {
        // KJV Psalm 119 has 176 dense verses; prove ordering is by verse column, not index
        let store = try BibleStore(databaseURL: try FixtureDatabase.build())
        let verses = try store.chapter((book: "PSA", chapter: 119), translationID: "KJV")
        XCTAssertEqual(verses.map(\.id.verse), Array(1...176))
    }
    func testMissingChapterReturnsEmpty() throws {
        let store = try BibleStore(databaseURL: try FixtureDatabase.build())
        XCTAssertEqual(try store.chapter((book: "MAT", chapter: 99), translationID: "WEB"), [])
    }
    func testSearchFindsPhrase() throws {
        let store = try BibleStore(databaseURL: try FixtureDatabase.build())
        let hits = try store.search("poor in spirit", translationID: "WEB", limit: 10)
        XCTAssertEqual(hits.first?.id, VerseLocation(book: "MAT", chapter: 5, verse: 3))
    }
    func testSearchSanitisesOperators() throws {
        let store = try BibleStore(databaseURL: try FixtureDatabase.build())
        XCTAssertNoThrow(try store.search("spirit* OR \"", translationID: "WEB", limit: 5))
        XCTAssertNoThrow(try store.search("\"", translationID: "WEB", limit: 5))
        XCTAssertEqual(try store.search("   ", translationID: "WEB", limit: 5), [])
    }
    func testMissingDatabaseThrows() {
        XCTAssertThrowsError(try BibleStore(databaseURL: URL(fileURLWithPath: "/nonexistent.sqlite")))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd Packages/ScriptureKit && swift test --filter BibleStoreTests`
Expected: compile errors for missing types.

- [ ] **Step 4: Implement `Models.swift`, `SearchQuery.swift`, `BibleStore.swift`**

`BibleStore` opens a read-only `DatabaseQueue` (`Configuration.readonly = true`), throwing `databaseMissing` when the file does not exist. `chapter` orders by `verse`. `search` joins `verse_fts` to `verse` on rowid, orders by `bm25(verse_fts)`, filters by `translation_id`, applies `limit`. `books(in:)` joins `translation_book` to `book` ordered by `sort_order`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Packages/ScriptureKit && swift test --filter BibleStoreTests`
Expected: 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: BibleStore read API with chapter lookup and FTS search"
```

---

### Task 6: Reference parser

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureData/Reference.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureData/ReferenceParser.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureDataTests/ReferenceParserTests.swift`

**Interfaces:**
- Consumes: `BookCatalog`, `Book.aliases`.
- Produces:
  - `public struct Reference: Hashable, Sendable { public let book: Book; public let chapter: Int?; public let verse: Int?; public let endVerse: Int? }`
  - `public enum ReferenceParser { public static func parse(_ input: String) -> Reference?; public static func matchBooks(prefix: String) -> [Book] }`
  - `public extension Reference { var displayString: String }` → `"Matthew 5:3-7"`, `"Psalm 23"`, `"John"`.

- [ ] **Step 1: Write the failing tests**

```swift
final class ReferenceParserTests: XCTestCase {
    func testParsesCommonForms() {
        XCTAssertEqual(ReferenceParser.parse("Rom 8")?.book.id, "ROM")
        XCTAssertEqual(ReferenceParser.parse("Rom 8")?.chapter, 8)
        XCTAssertNil(ReferenceParser.parse("Rom 8")?.verse)
        let j = ReferenceParser.parse("John 3:16")
        XCTAssertEqual(j?.book.id, "JHN"); XCTAssertEqual(j?.chapter, 3); XCTAssertEqual(j?.verse, 16)
        let c = ReferenceParser.parse("1 Cor 13:4-7")
        XCTAssertEqual(c?.book.id, "1CO"); XCTAssertEqual(c?.verse, 4); XCTAssertEqual(c?.endVerse, 7)
        XCTAssertEqual(ReferenceParser.parse("1cor13")?.chapter, 13)
        XCTAssertEqual(ReferenceParser.parse("Song of Songs 2:1")?.book.id, "SNG")
        XCTAssertEqual(ReferenceParser.parse("ps 23")?.book.id, "PSA")
    }
    func testNormalisesCaseWhitespaceAndDashes() {
        XCTAssertEqual(ReferenceParser.parse("  MATT 5:3–7  ")?.endVerse, 7)   // en dash
        XCTAssertEqual(ReferenceParser.parse("matt.5.3")?.verse, 3)
    }
    func testBookOnly() {
        let r = ReferenceParser.parse("Genesis")
        XCTAssertEqual(r?.book.id, "GEN"); XCTAssertNil(r?.chapter)
    }
    func testRejectsUnknownAndNonsense() {
        XCTAssertNil(ReferenceParser.parse("Hezekiah 3:1"))
        XCTAssertNil(ReferenceParser.parse(""))
        XCTAssertNil(ReferenceParser.parse("3:16"))
        XCTAssertNil(ReferenceParser.parse("John 0:1"))
        XCTAssertNil(ReferenceParser.parse("John 3:16-2"))
    }
    func testPrefixMatchingInCanonOrder() {
        XCTAssertEqual(ReferenceParser.matchBooks(prefix: "J").map(\.id), ["JOS", "JDG", "JOB", "JER", "JOL", "JON", "JHN", "JAS", "JUD", "JDT"])
        XCTAssertEqual(ReferenceParser.matchBooks(prefix: "Jud").map(\.id), ["JDG", "JUD", "JDT"])
        XCTAssertEqual(ReferenceParser.matchBooks(prefix: "Zzz"), [])
    }
    func testDisplayString() {
        XCTAssertEqual(ReferenceParser.parse("1 Cor 13:4-7")?.displayString, "1 Corinthians 13:4-7")
        XCTAssertEqual(ReferenceParser.parse("ps 23")?.displayString, "Psalms 23")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Packages/ScriptureKit && swift test --filter ReferenceParserTests`
Expected: compile errors.

- [ ] **Step 3: Implement `Reference.swift` and `ReferenceParser.swift`**

Normalise: trim, lowercase, replace `–` and `—` with `-`, replace `.` between digits with `:`, collapse whitespace. Split the leading book token: an optional leading digit (`1`, `2`, `3`) plus letters, allowing the digit to be glued (`1cor`). Match the book against `name`, `shortName` and `aliases` (lowercased, punctuation stripped): exact match wins, else unique prefix match, else among prefix matches the one with the shortest `name` (so `"Jud"` resolves to Jude), ties broken by canon order. Then parse `chapter[:verse[-endVerse]]`; reject chapter or verse `< 1`, or `endVerse < verse`. `matchBooks(prefix:)` returns exact matches first, then prefix matches on `name`, `shortName` or an alias, in canon order, de-duplicated.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Packages/ScriptureKit && swift test --filter ReferenceParserTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: reference parser for Book chapter:verse-range input"
```

---

### Task 7: macOS preview executable showing Matthew 5 in ESV

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureMacPreview/main.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureMacPreview/ChapterTextView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureMacPreview/DatabaseLocator.swift`

**Interfaces:**
- Consumes: `BibleStore`, `Verse`, `ReferenceParser` (Tasks 5 and 6).
- Produces: `swift run ScriptureMacPreview [reference]` opens a window rendering the chapter; `swift run ScriptureMacPreview --print [reference]` writes the chapter to stdout and exits. Default reference `Matthew 5`, translation `ESV`, database `Build/bible.sqlite` relative to the repo root, overridable with `SCRIPTURE_DB` env var.

- [ ] **Step 1: Write `DatabaseLocator.swift`**

`enum DatabaseLocator { static func url() -> URL }`: `SCRIPTURE_DB` if set, else walk up from the current directory until a `Build/bible.sqlite` is found, else `Build/bible.sqlite` relative to cwd.

- [ ] **Step 2: Write `main.swift`**

Top-level code in `main.swift` (no `@main` attribute; `struct PreviewApp: App` is declared in the same file and invoked with `PreviewApp.main()`): parse arguments; on `--print` load the store, call `chapter`, print `"\(verse.id.verse) \(verse.text)"` per verse plus a blank line when `breakAfter`, exit. Otherwise call `NSApplication.shared.setActivationPolicy(.regular)`, and run `PreviewApp.main()` with a `WindowGroup` containing `ChapterTextView` fed by a `@State` load. On `BibleStoreError.databaseMissing`, print `Run Scripts/build-bible.sh first (looked at <path>)` to stderr and exit 2.

- [ ] **Step 3: Write `ChapterTextView.swift`**

`struct ChapterTextView: View { let title: String; let verses: [Verse] }`. Serif title at 28pt, body `Text` concatenation per verse: superscript-styled verse number (`.font(.caption).baselineOffset(6)`) then text with `\n` preserved, extra spacing where `breakAfter`. Max width 600, padding 48. No controls.

- [ ] **Step 4: Verify the print path**

Run: `swift run --package-path Packages/ScriptureKit ScriptureMacPreview --print "Matt 5"`
Expected: 48 lines starting `1 Seeing the crowds` … (ESV wording), blank lines after verses that end a paragraph.

- [ ] **Step 5: Verify the window**

Run: `swift run --package-path Packages/ScriptureKit ScriptureMacPreview` in the background and confirm a window titled "Matthew 5 · ESV" appears with the chapter text. Then quit it.

- [ ] **Step 6: Verify the missing-database message**

Run: `SCRIPTURE_DB=/tmp/none.sqlite swift run --package-path Packages/ScriptureKit ScriptureMacPreview --print`
Expected: exit code 2 and the `Run Scripts/build-bible.sh first` message on stderr.

- [ ] **Step 7: Run the whole suite**

Run: `cd Packages/ScriptureKit && swift test`
Expected: all tests pass (2 + 6 + 1 + 7 + 6 = 22).

- [ ] **Step 8: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: macOS preview executable rendering a chapter from bible.sqlite"
```

---

## Self-review notes

- Spec coverage for milestone 1: workspace and Xcode app target are deferred to milestone 2 because Xcode is not installed; everything else in the milestone (importer as a build step, generated and bundled database, `ScriptureData` with reference parsing and FTS, importer tests for verse merge, poetry and canon order, a window printing Matthew 5 in ESV) has a task.
- The `translation_book.chapter_count` derivation (chapters with at least one verse) is a decision, not an inference; it matters for the chapter grid in milestone 2.
- `Verse.id` is a `VerseLocation` so milestone 3 highlights can reference it directly.
