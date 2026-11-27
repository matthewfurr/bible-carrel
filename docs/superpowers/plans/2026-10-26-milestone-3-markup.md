# Milestone 3: Markup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Mac reader becomes a study notebook: phrase-level highlights in user-defined colors, markdown notes anchored to those highlights, whole-verse bookmarks with a gutter glyph, Copy / Copy with Reference / Share from a context menu, a notes column linked both ways to the text, and a Settings scene for colors, all persisted locally in SwiftData.

**Architecture:** A new `ScriptureModel` library in `Packages/ScriptureKit` holds the SwiftData models (`Highlight`, `Note`, `Bookmark`, `HighlightColor`), the local `ModelContainer` factory (CloudKit container identifier recorded, sync off), and a `MarkupStore` repository with the chapter queries and the delete-when-empty rule. `ScriptureUI` gains pure value types for the reader's side (`TextSelection`, `SelectionResolver`, `MarkupItem`, `ChapterDecorations`), an `@Observable` `MarkupModel` view model that owns the chapter's markup state and every user action, TextKit 2 rendering of highlights as rendering attributes plus a gutter view and an outline overlay inside `ChapterTextController`, the AppKit context menu, the notes column, and the settings pane. The app target creates the container, hosts the notes column and toolbar toggle, and adds the `Settings` scene.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData (local store, `cloudKitDatabase: .none`), AppKit `NSTextView` with TextKit 2 (`NSTextLayoutManager` rendering attributes, `enumerateTextSegments`), `NSMenu` with an `NSHostingView` swatch row, `NSSharingServicePicker`, `NSPasteboard`, `AttributedString(markdown:)`, Swift Testing, Xcode 26.6. GRDB stays the only third-party dependency.

**Spec:** `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (sections Markup, "My calls", Architecture → Data model and UI, Milestones → 3, Verification → Markup)

## Global Constraints

- Minimum macOS 26 / iOS 26; Swift language mode 6; package platforms unchanged.
- GRDB is the only third-party dependency. SwiftData, AppKit, SwiftUI only otherwise.
- SF Symbols only, never emoji. Symbols used: bookmark glyph `bookmark.fill`, add color `plus.circle`, notes column toggle `sidebar.right`, note card edit `pencil`, delete `trash`, done `checkmark`, settings add `plus`, settings remove `minus`, share `square.and.arrow.up`, copy `doc.on.doc`, ask `sparkles`, chapter note band `note.text`.
- CloudKit-compatible models even though sync is off: every stored attribute has a default value or is optional, no `@Attribute(.unique)`, every relationship optional, every model has `uuid: UUID = UUID()`. CloudKit container identifier `iCloud.com.matthewfurr.ReadingThroughScripture` is recorded as a constant; the `ModelConfiguration` uses `cloudKitDatabase: .none`.
- Store file: `~/Library/Application Support/ReadingThroughScripture/Markup.store` (the app is not sandboxed). Tests use `isStoredInMemoryOnly: true`.
- Offsets are UTF-16 (`NSRange` units) within `Verse.text` of the highlight's `translationID`; `VerseSpan.textRange` already maps 1:1 onto `Verse.text` (poetry `"\n"` and the layout's line separator are both one UTF-16 unit).
- A highlight with no color and no note is deleted (`MarkupStore.deleteIfEmpty`). A note whose body is empty after editing ends is deleted, which can cascade into that rule.
- Copy with Reference format, exactly: `“text” — Matthew 5:3 (ESV)` (U+201C, U+201D, space, em dash U+2014, space, reference, space, `(` translation id `)`). A multi-verse selection reads `Matthew 5:3-4`.
- Five default colors seeded once when the color table is empty, in this order: Yellow `#FFE86B`/`#6B5B00`, Green `#B5F0B0`/`#1F5A2A`, Blue `#B9DDFF`/`#1F4C7A`, Pink `#FFC7DE`/`#7A2E55`, Orange `#FFD3A3`/`#7A4A1F` (light hex / dark hex, `isDefault = true`).
- Setting keys in `UserDefaults.standard`: `showNotelessHighlights` (Bool, default true), `showNotesColumn` (Bool, default true). The `UserSettings` SwiftData record arrives in milestone 4 together with the full settings window; milestone 3 uses `@AppStorage` for these two.
- Every `swift`/`xcodebuild` command sets `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (`export XC=/Applications/Xcode.app/Contents/Developer`). Package tests: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`. App build: `DEVELOPER_DIR=$XC xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData build`.
- Git in this worktree: call `/usr/bin/git`, one command per Bash call, no `cd` prefix.
- Commit per task; never merge or push. Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Rulings (plan-level decisions the spec leaves open)

1. **A highlight may span verse boundaries.** The spec anchors a highlight "within a verse" and gives notes a `verseRange` scope with `endLocation`; a selection across verses is common (a sentence that runs over a verse break). `Highlight` stores `verse`, `endVerse`, `startOffset` (in `verse`) and `endOffset` (in `endVerse`); the single-verse case is the spec's model exactly. One selection always produces one highlight and one note anchor, so card ↔ text linking stays one-to-one.
2. **Location fields are stored flat** (`book`, `chapter`, `verse`, `endVerse`) with a computed `location: VerseLocation`, so `#Predicate` can filter by chapter and CloudKit sees plain fields. `VerseLocation` remains the API type.
3. **Quoted text** is built from `Verse.text` slices, never from the attributed string, so verse numbers never leak into copies; verse slices are joined with a single space, and poetry `"\n"` inside a verse is kept.
4. **Overlapping highlights** blend: where two backgrounds meet, the second is blended 50/50 over the first.
5. **Menu rule for an existing highlight:** when the selection (or caret) lies inside exactly one existing highlight, swatches recolor it, "Add Note" opens or creates its note, and "Remove Highlight" (colored highlights only) clears the color, which deletes the highlight when it has no note. Otherwise swatches and Add Note create a new highlight from the selection.
6. **Right-click with no selection** selects the word under the pointer first, so the menu always has a selection to act on.
7. **Outline:** clicking a card scrolls the highlight into view and draws a rounded stroke around its line segments in an overlay view; the outline clears on the next selection change in the text.
8. **Deleting a color** in Settings clears `colorID` on its highlights; those without a note are then deleted. The settings view confirms with the affected count.
9. **Chapter-scoped notes** render in the band under the heading and also as cards at the top of the column (editable there). Nothing in milestone 3 creates them; milestone 5's chapter menu does.
10. **"Copy"** copies the quoted text without verse numbers; the text view's own ⌘C stays as AppKit provides it.

## Review Focus

1. A highlight whose offsets no longer fit the verse (the bundled text was regenerated, or `endOffset` exceeds the verse length): the range must be clamped to the verse text and skipped when empty, never crash `NSRange` arithmetic. Pinned in Task 4 (`offsetsBeyondVerseAreClamped`).
2. A highlight on a verse the current chapter lacks (ESV omits Matthew 17:21; a WEB highlight on it viewed in ESV): no decoration, no crash. Pinned in Task 4 (`highlightOnAbsentVerseIsSkipped`).
3. A selection that starts in a verse number or ends in the separator between verses: the resolved selection must clip to verse text, and a selection that is only whitespace or only a number resolves to nil so the menu offers no highlight. Pinned in Task 3 (`selectionStartingInNumberClipsToText`, `selectionOfOnlySeparatorIsNil`).
4. A combined verse (`ERV 1 Corinthians 5:12-13`, one `Verse` with `endVerse`): a highlight made there must store `verse = 12`, and a highlight stored on verse 13 by another translation must still render on the combined span. Pinned in Task 3 (`selectionInCombinedVerseUsesSpanStart`) and Task 4 (`foreignHighlightOnCombinedVerseUnderlinesTheSpan`).
5. Ending an edit on a brand-new note without typing (the compact row was clicked by accident): the empty note is deleted and the colored highlight survives, while a colorless anchor is deleted with it. Pinned in Task 6 (`endingEmptyEditDeletesNoteAndColorlessAnchor`, `endingEmptyEditKeepsColoredHighlight`).

---

### Task 1: `ScriptureModel` target, SwiftData models, container, default colors

**Files:**
- Modify: `Packages/ScriptureKit/Package.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/Highlight.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/Note.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/Bookmark.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/HighlightColor.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/ColorHex.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/MarkupContainer.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureModelTests/MarkupContainerTests.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureModelTests/ColorHexTests.swift`

**Interfaces:**
- Consumes: `VerseLocation`, `ChapterLocation` from `ScriptureData`.
- Produces:
  - `Package.swift`: `.library(name: "ScriptureModel", targets: ["ScriptureModel"])`; `.target(name: "ScriptureModel", dependencies: ["ScriptureData"])`; `.testTarget(name: "ScriptureModelTests", dependencies: ["ScriptureModel"])`; `ScriptureUI` target gains the dependency `"ScriptureModel"`.
  - `@Model public final class Highlight { public var uuid: UUID = UUID(); public var book: String = ""; public var chapter: Int = 0; public var verse: Int = 0; public var endVerse: Int = 0; public var startOffset: Int = 0; public var endOffset: Int = 0; public var translationID: String = ""; public var colorID: UUID?; public var quotedText: String = ""; public var createdAt: Date = Date(); public var modifiedAt: Date = Date(); @Relationship(deleteRule: .cascade, inverse: \Note.highlight) public var note: Note?; public init(book:chapter:verse:endVerse:startOffset:endOffset:translationID:colorID:quotedText:); public var location: VerseLocation; public var endLocation: VerseLocation; public var chapterLocation: ChapterLocation; public var isEmpty: Bool /* colorID == nil && note == nil */ }`
  - `public enum NoteScope: String, Codable, Sendable { case highlight, verseRange, chapter }`
  - `@Model public final class Note { public var uuid: UUID = UUID(); public var body: String = ""; public var createdAt: Date = Date(); public var modifiedAt: Date = Date(); public var scopeRaw: String = NoteScope.highlight.rawValue; public var book: String = ""; public var chapter: Int = 0; public var verse: Int = 0; public var endVerse: Int = 0; public var translationID: String = ""; public var quotedText: String = ""; public var highlight: Highlight?; public init(body:scope:book:chapter:verse:endVerse:translationID:quotedText:); public var scope: NoteScope { get set }; public var location: VerseLocation; public var chapterLocation: ChapterLocation }`
  - `@Model public final class Bookmark { public var uuid: UUID = UUID(); public var book: String = ""; public var chapter: Int = 0; public var verse: Int = 0; public var createdAt: Date = Date(); public var label: String?; public init(book:chapter:verse:label:); public var location: VerseLocation }`
  - `@Model public final class HighlightColor { public var uuid: UUID = UUID(); public var name: String = ""; public var lightHex: String = "#FFE86B"; public var darkHex: String = "#6B5B00"; public var sortOrder: Int = 0; public var isDefault: Bool = false; public init(name:lightHex:darkHex:sortOrder:isDefault:) }`
  - `public enum ColorHex { public static func components(_ hex: String) -> (red: Double, green: Double, blue: Double)?; public static func string(red: Double, green: Double, blue: Double) -> String /* "#RRGGBB" uppercase */ }` — accepts `#RRGGBB` and `RRGGBB`, any case; returns nil otherwise.
  - `public enum MarkupContainer { public static let cloudKitContainerIdentifier = "iCloud.com.matthewfurr.ReadingThroughScripture"; public static let schema: Schema /* Highlight, Note, Bookmark, HighlightColor */; public static func make(inMemory: Bool = false) throws -> ModelContainer; public static let defaultColors: [(name: String, lightHex: String, darkHex: String)]; @MainActor public static func seedDefaultColorsIfNeeded(in context: ModelContext) throws }` — `make(inMemory: false)` uses the Application Support URL from Global Constraints and creates the directory.

- [ ] **Step 1: Add the targets to `Package.swift`** (library product, target, test target, and the `ScriptureUI` dependency).

- [ ] **Step 2: Write the failing tests**

`Tests/ScriptureModelTests/MarkupContainerTests.swift`:

```swift
import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct MarkupContainerTests {
    @Test func inMemoryContainerStoresAndFetchesAHighlightWithItsNote() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed")
        highlight.note = Note(body: "first", scope: .highlight, book: "MAT", chapter: 5, verse: 3, endVerse: 3, translationID: "ESV", quotedText: "Blessed")
        context.insert(highlight)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Highlight>())
        #expect(fetched.count == 1)
        #expect(fetched[0].location == VerseLocation(book: "MAT", chapter: 5, verse: 3))
        #expect(fetched[0].note?.body == "first")
        #expect(fetched[0].note?.highlight === fetched[0])
        #expect(fetched[0].isEmpty == false)
    }

    @Test func deletingAHighlightCascadesToItsNote() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed")
        highlight.note = Note(body: "x", scope: .highlight, book: "MAT", chapter: 5, verse: 3, endVerse: 3, translationID: "ESV", quotedText: "Blessed")
        context.insert(highlight)
        try context.save()
        context.delete(highlight)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Note>()).isEmpty)
    }

    @Test func seedingAddsFiveDefaultColorsOnce() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        try MarkupContainer.seedDefaultColorsIfNeeded(in: context)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: context)
        let colors = try context.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(colors.map(\.name) == ["Yellow", "Green", "Blue", "Pink", "Orange"])
        #expect(colors.map(\.sortOrder) == [0, 1, 2, 3, 4])
        #expect(colors.allSatisfy(\.isDefault))
        #expect(colors[0].lightHex == "#FFE86B" && colors[0].darkHex == "#6B5B00")
    }

    @Test func noteScopeRoundTripsThroughRawValue() {
        let note = Note(body: "", scope: .chapter, book: "MAT", chapter: 5, verse: 1, endVerse: 1, translationID: "ESV", quotedText: "")
        #expect(note.scopeRaw == "chapter")
        note.scope = .verseRange
        #expect(note.scope == .verseRange)
    }
}
```

`Tests/ScriptureModelTests/ColorHexTests.swift`:

```swift
import Testing
@testable import ScriptureModel

@Suite struct ColorHexTests {
    @Test func parsesWithAndWithoutHash() {
        #expect(ColorHex.components("#FFE86B")! == (1.0, 232.0 / 255, 107.0 / 255))
        #expect(ColorHex.components("ffe86b")! == (1.0, 232.0 / 255, 107.0 / 255))
        #expect(ColorHex.components("#FFE") == nil)
        #expect(ColorHex.components("nope") == nil)
    }

    @Test func formatsUppercaseWithHash() {
        #expect(ColorHex.string(red: 1, green: 232.0 / 255, blue: 107.0 / 255) == "#FFE86B")
        #expect(ColorHex.string(red: 0, green: 0, blue: 0) == "#000000")
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter ScriptureModelTests`
Expected: compile failure, `no such module 'ScriptureModel'` or missing types.

- [ ] **Step 4: Implement the four models, `ColorHex`, and `MarkupContainer`** with the signatures above. `location`, `endLocation`, `chapterLocation` are computed from the flat fields. `seedDefaultColorsIfNeeded` counts `HighlightColor` rows and inserts `defaultColors` with `sortOrder` 0…4 when the count is zero, then saves.

- [ ] **Step 5: Run tests to verify they pass**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all previous 88 plus the 6 new tests pass.

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Package.swift Packages/ScriptureKit/Sources/ScriptureModel Packages/ScriptureKit/Tests/ScriptureModelTests docs/superpowers/plans/2026-10-26-milestone-3-markup.md
/usr/bin/git commit -m "feat: ScriptureModel target with SwiftData markup models and default colors"
```

---

### Task 2: `MarkupStore` repository

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/MarkupStore.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureModelTests/MarkupStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 models and `MarkupContainer`.
- Produces: `@MainActor public final class MarkupStore` with `public init(context: ModelContext)` and:
  - `public func highlights(in chapter: ChapterLocation) throws -> [Highlight]` sorted by `verse`, then `startOffset`, then `createdAt`.
  - `public func notes(in chapter: ChapterLocation) throws -> [Note]` sorted by `verse`, then `createdAt`.
  - `public func bookmarks(in chapter: ChapterLocation) throws -> [Bookmark]` sorted by `verse`.
  - `public func bookmark(at location: VerseLocation) throws -> Bookmark?`
  - `public func colors() throws -> [HighlightColor]` sorted by `sortOrder`.
  - `public func color(id: UUID) throws -> HighlightColor?`
  - `@discardableResult public func addHighlight(book: String, chapter: Int, verse: Int, endVerse: Int, startOffset: Int, endOffset: Int, translationID: String, colorID: UUID?, quotedText: String) throws -> Highlight`
  - `public func setColor(_ colorID: UUID?, on highlight: Highlight) throws` — updates `modifiedAt`, then `deleteIfEmpty`.
  - `@discardableResult public func addNote(to highlight: Highlight, body: String) throws -> Note` — scope `.highlight`, copies book/chapter/verse/endVerse/translationID/quotedText from the highlight; throws `MarkupStoreError.highlightAlreadyHasNote` when `highlight.note != nil`.
  - `public func updateNote(_ note: Note, body: String) throws` — sets body and `modifiedAt`.
  - `public func deleteNote(_ note: Note) throws` — removes the note, then `deleteIfEmpty` on its highlight.
  - `public func deleteIfEmpty(_ highlight: Highlight) throws` — deletes when `highlight.isEmpty`.
  - `public func deleteHighlight(_ highlight: Highlight) throws` — unconditional (cascades to the note).
  - `@discardableResult public func toggleBookmark(at location: VerseLocation) throws -> Bool` — returns true when a bookmark now exists.
  - `@discardableResult public func addColor(name: String, lightHex: String, darkHex: String) throws -> HighlightColor` — `sortOrder` = max + 1, `isDefault = false`.
  - `public func renameColor(_ color: HighlightColor, to name: String) throws`
  - `public func setColorHex(_ color: HighlightColor, lightHex: String, darkHex: String) throws`
  - `public func moveColors(fromOffsets: IndexSet, toOffset: Int) throws` — reorders and rewrites `sortOrder` 0…n.
  - `public func highlightCount(usingColor id: UUID) throws -> Int`
  - `public func deleteColor(_ color: HighlightColor) throws` — Ruling 8.
  - `public enum MarkupStoreError: Error, Equatable { case highlightAlreadyHasNote }`
  - Every mutating method ends with `try context.save()`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct MarkupStoreTests {
    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)

    private func makeStore() throws -> MarkupStore {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        return MarkupStore(context: container.mainContext)
    }

    private func add(_ store: MarkupStore, verse: Int, start: Int = 0, end: Int = 5, color: UUID? = nil, translation: String = "ESV") throws -> Highlight {
        try store.addHighlight(book: "MAT", chapter: 5, verse: verse, endVerse: verse, startOffset: start, endOffset: end, translationID: translation, colorID: color, quotedText: "words")
    }

    @Test func highlightsAreScopedToTheChapterAndOrdered() throws {
        let store = try makeStore()
        let yellow = try store.colors()[0].uuid
        _ = try add(store, verse: 7, color: yellow)
        _ = try add(store, verse: 3, start: 10, color: yellow)
        _ = try add(store, verse: 3, start: 2, color: yellow)
        _ = try store.addHighlight(book: "MAT", chapter: 6, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "ESV", colorID: yellow, quotedText: "Be")
        let found = try store.highlights(in: matthew5)
        #expect(found.map { ($0.verse, $0.startOffset) }.map { "\($0.0):\($0.1)" } == ["3:2", "3:10", "7:0"])
    }

    @Test func clearingTheColorOfANotelessHighlightDeletesIt() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3, color: try store.colors()[0].uuid)
        try store.setColor(nil, on: highlight)
        #expect(try store.highlights(in: matthew5).isEmpty)
    }

    @Test func clearingTheColorOfANotedHighlightKeepsIt() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3, color: try store.colors()[0].uuid)
        try store.addNote(to: highlight, body: "keep me")
        try store.setColor(nil, on: highlight)
        let found = try store.highlights(in: matthew5)
        #expect(found.count == 1 && found[0].colorID == nil && found[0].note?.body == "keep me")
    }

    @Test func deletingTheNoteOfAColorlessHighlightDeletesTheHighlight() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3)
        let note = try store.addNote(to: highlight, body: "temporary")
        #expect(note.scope == .highlight && note.quotedText == "words" && note.translationID == "ESV")
        try store.deleteNote(note)
        #expect(try store.highlights(in: matthew5).isEmpty)
        #expect(try store.notes(in: matthew5).isEmpty)
    }

    @Test func deletingTheNoteOfAColoredHighlightKeepsTheHighlight() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3, color: try store.colors()[1].uuid)
        let note = try store.addNote(to: highlight, body: "temporary")
        try store.deleteNote(note)
        #expect(try store.highlights(in: matthew5).count == 1)
    }

    @Test func secondNoteOnAHighlightIsRefused() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3)
        try store.addNote(to: highlight, body: "one")
        #expect(throws: MarkupStoreError.highlightAlreadyHasNote) { try store.addNote(to: highlight, body: "two") }
    }

    @Test func bookmarkToggles() throws {
        let store = try makeStore()
        let location = VerseLocation(book: "MAT", chapter: 5, verse: 9)
        #expect(try store.toggleBookmark(at: location) == true)
        #expect(try store.bookmarks(in: matthew5).map(\.verse) == [9])
        #expect(try store.toggleBookmark(at: location) == false)
        #expect(try store.bookmark(at: location) == nil)
    }

    @Test func colorsCanBeAddedRenamedReorderedAndDeleted() throws {
        let store = try makeStore()
        let teal = try store.addColor(name: "Teal", lightHex: "#A0E0E0", darkHex: "#104040")
        #expect(teal.sortOrder == 5 && teal.isDefault == false)
        try store.renameColor(teal, to: "Sea")
        try store.moveColors(fromOffsets: IndexSet(integer: 5), toOffset: 0)
        #expect(try store.colors().map(\.name) == ["Sea", "Yellow", "Green", "Blue", "Pink", "Orange"])
        #expect(try store.colors().map(\.sortOrder) == [0, 1, 2, 3, 4, 5])
        let noted = try add(store, verse: 1, color: teal.uuid)
        try store.addNote(to: noted, body: "stays")
        _ = try add(store, verse: 2, color: teal.uuid)
        #expect(try store.highlightCount(usingColor: teal.uuid) == 2)
        try store.deleteColor(teal)
        #expect(try store.colors().count == 5)
        let remaining = try store.highlights(in: matthew5)
        #expect(remaining.count == 1 && remaining[0].colorID == nil && remaining[0].note?.body == "stays")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter MarkupStoreTests`
Expected: compile failure, `cannot find 'MarkupStore'`.

- [ ] **Step 3: Implement `MarkupStore`** per the Interfaces block. Chapter queries use `#Predicate` on `book` and `chapter`; ordering is done in Swift after the fetch (`SortDescriptor` on several keys is fine too).

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all pass (94 + 8).

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureModel/MarkupStore.swift Packages/ScriptureKit/Tests/ScriptureModelTests/MarkupStoreTests.swift
/usr/bin/git commit -m "feat: MarkupStore with chapter queries, delete-when-empty, bookmarks and color management"
```

---

### Task 3: `TextSelection`, `SelectionResolver`, Copy with Reference

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/TextSelection.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/SelectionResolver.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/SelectionResolverTests.swift`

**Interfaces:**
- Consumes: `ChapterLayout`, `VerseSpan` (`textRange`, `numberRange`, `location`, `endVerse`), `Verse`, `Reference.displayString`, `BookCatalog`.
- Produces:
  - `public struct TextSelection: Equatable, Sendable { public let book: String; public let chapter: Int; public let verse: Int; public let endVerse: Int; public let startOffset: Int; public let endOffset: Int; public let quotedText: String; public init(...); public var reference: Reference /* Reference(book:, chapter:, verse:, endVerse: endVerse == verse ? nil : endVerse) */; public var referenceString: String /* reference.displayString */; public func copyWithReference(translationID: String) -> String; public var chapterLocation: ChapterLocation }`
  - `public enum SelectionResolver { public static func resolve(_ range: NSRange, in layout: ChapterLayout, verses: [Verse]) -> TextSelection? }` — clips `range` to the union of verse text ranges: a start inside a number or separator moves to the next verse's text start; an end inside a number or separator moves to the previous verse's text end; trailing/leading whitespace inside verse text is trimmed; nil when nothing remains. `verse` is the start span's `location.verse` (a combined span's first number), `endVerse` is the end span's `location.verse`. `quotedText` follows Ruling 3.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct SelectionResolverTests {
    private func verse(_ n: Int, _ text: String, end: Int? = nil) -> Verse {
        Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "ESV", endVerse: end, text: text, breakAfter: false)
    }
    // "1 Blessed are the poor. 2 For theirs is."  → verse 1 text at 2..<23, verse 2 text at 26..<40
    private var chapter: [Verse] { [verse(1, "Blessed are the poor."), verse(2, "For theirs is.")] }
    private var layout: ChapterLayout { ChapterLayout.build(verses: chapter) }

    @Test func selectionInsideOneVerse() {
        let sel = SelectionResolver.resolve(NSRange(location: 2, length: 7), in: layout, verses: chapter)
        #expect(sel == TextSelection(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, quotedText: "Blessed"))
    }

    @Test func selectionAcrossVersesSkipsTheNumber() {
        let sel = SelectionResolver.resolve(NSRange(location: 14, length: 15), in: layout, verses: chapter)   // "the poor. 2 For"
        #expect(sel?.verse == 1 && sel?.endVerse == 2)
        #expect(sel?.startOffset == 12 && sel?.endOffset == 3)
        #expect(sel?.quotedText == "the poor. For")
    }

    @Test func selectionStartingInNumberClipsToText() {
        let sel = SelectionResolver.resolve(NSRange(location: 23, length: 6), in: layout, verses: chapter)    // "2 For"
        #expect(sel == TextSelection(book: "MAT", chapter: 5, verse: 2, endVerse: 2, startOffset: 0, endOffset: 3, quotedText: "For"))
    }

    @Test func selectionOfOnlySeparatorIsNil() {
        #expect(SelectionResolver.resolve(NSRange(location: 23, length: 3), in: layout, verses: chapter) == nil)   // " 2 "
        #expect(SelectionResolver.resolve(NSRange(location: 0, length: 0), in: layout, verses: chapter) == nil)
    }

    @Test func selectionInCombinedVerseUsesSpanStart() {
        let combined = [verse(11, "Eleven."), verse(12, "Twelve and thirteen.", end: 13)]
        let layout = ChapterLayout.build(verses: combined)
        let start = layout.spans[1].textRange.location
        let sel = SelectionResolver.resolve(NSRange(location: start + 11, length: 8), in: layout, verses: combined)
        #expect(sel?.verse == 12 && sel?.endVerse == 12 && sel?.quotedText == "thirteen")
        #expect(sel?.referenceString == "Matthew 5:12")
    }

    @Test func copyWithReferenceFormat() {
        let one = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, quotedText: "Blessed are the poor in spirit")
        #expect(one.copyWithReference(translationID: "ESV") == "\u{201C}Blessed are the poor in spirit\u{201D} \u{2014} Matthew 5:3 (ESV)")
        let range = TextSelection(book: "PSA", chapter: 23, verse: 1, endVerse: 2, startOffset: 0, endOffset: 4, quotedText: "The LORD is my shepherd")
        #expect(range.copyWithReference(translationID: "KJV") == "\u{201C}The LORD is my shepherd\u{201D} \u{2014} Psalm 23:1-2 (KJV)")
    }

    @Test func poetryLineBreaksSurviveInQuotedText() {
        let poem = [verse(1, "Line one,\nline two.")]
        let layout = ChapterLayout.build(verses: poem)
        let sel = SelectionResolver.resolve(layout.spans[0].textRange, in: layout, verses: poem)
        #expect(sel?.quotedText == "Line one,\nline two.")
    }
}
```

Offsets: `"1 Blessed are the poor. 2 For theirs is."` has verse 1 text at 2..<23 (21 characters) and verse 2 text at 26..<40.

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter SelectionResolverTests`
Expected: compile failure, `cannot find 'SelectionResolver'`.

- [ ] **Step 3: Implement `TextSelection` and `SelectionResolver`**. Resolver algorithm: find the first span whose `textRange` ends after `range.location` (start = max(range.location, textRange.location)); find the last span whose `textRange` starts before `NSMaxRange(range)` (end = min(NSMaxRange(range), NSMaxRange(textRange))); trim whitespace on the clipped ends using the verse text; return nil if start span index > end span index or the clipped length is 0.

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI/TextSelection.swift Packages/ScriptureKit/Sources/ScriptureUI/SelectionResolver.swift Packages/ScriptureKit/Tests/ScriptureUITests/SelectionResolverTests.swift
/usr/bin/git commit -m "feat: resolve text-view selections to verse offsets; Copy with Reference format"
```

---

### Task 4: `MarkupItem` and `ChapterDecorations` (pure range mapping)

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/MarkupItem.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterDecorations.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/ChapterDecorationsTests.swift`

**Interfaces:**
- Consumes: `ChapterLayout.span(forVerse:)`, `VerseSpan.textRange`, `Highlight`/`HighlightColor` from `ScriptureModel` (for the convenience initializer only).
- Produces:
  - `public struct MarkupColor: Equatable, Sendable { public let lightHex: String; public let darkHex: String; public init(lightHex:darkHex:) }`
  - `public struct MarkupItem: Identifiable, Equatable, Sendable { public let id: UUID; public let verse: Int; public let endVerse: Int; public let startOffset: Int; public let endOffset: Int; public let translationID: String; public let color: MarkupColor?; public let hasNote: Bool; public init(...); public init(highlight: Highlight, colors: [HighlightColor]) }` — the convenience init looks the color up by `uuid == highlight.colorID` (a missing color behaves as nil).
  - `public enum DecorationStyle: Equatable, Sendable { case background(MarkupColor); case dottedUnderline; case dashedUnderline }`
  - `public struct RangeDecoration: Identifiable, Equatable, Sendable { public let id: UUID; public let range: NSRange; public let style: DecorationStyle }`
  - `public struct ChapterDecorations: Equatable, Sendable { public static let none = ChapterDecorations(highlights: [], bookmarkVerses: [], outlinedID: nil); public var highlights: [RangeDecoration]; public var bookmarkVerses: [Int]; public var outlinedID: UUID?; public static func build(items: [MarkupItem], bookmarkVerses: [Int], viewingTranslationID: String, layout: ChapterLayout) -> ChapterDecorations; public func ids(intersecting range: NSRange) -> [UUID] /* a zero-length range counts when it falls inside a decoration */ }`
  - Mapping rules: same translation → range from `span(forVerse: verse).textRange.location + startOffset` to `span(forVerse: endVerse).textRange.location + endOffset`, each clamped into its span's `textRange`; style `.background(color)` when `color != nil`, else `.dottedUnderline`. Other translation → union of the whole `textRange`s from `span(forVerse: verse)` to `span(forVerse: endVerse)`, style `.dashedUnderline`. Missing start or end span, or an empty clamped range → no decoration. Bookmark verses are kept only when `span(forVerse:)` exists and are reported as the span's `location.verse`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct ChapterDecorationsTests {
    private func verse(_ n: Int, _ text: String, end: Int? = nil) -> Verse {
        Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "ESV", endVerse: end, text: text, breakAfter: false)
    }
    private let yellow = MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00")
    private var chapter: [Verse] { [verse(1, "Blessed are the poor."), verse(2, "For theirs is."), verse(4, "Blessed mourners.")] }
    private var layout: ChapterLayout { ChapterLayout.build(verses: chapter) }
    private func item(_ v: Int, _ ev: Int? = nil, _ s: Int, _ e: Int, translation: String = "ESV", color: MarkupColor? = nil, note: Bool = false) -> MarkupItem {
        MarkupItem(id: UUID(), verse: v, endVerse: ev ?? v, startOffset: s, endOffset: e, translationID: translation, color: color, hasNote: note)
    }

    @Test func sameTranslationHighlightMapsToExactRange() {
        let d = ChapterDecorations.build(items: [item(1, 12, 15, color: yellow)], bookmarkVerses: [], viewingTranslationID: "ESV", layout: layout)
        #expect(d.highlights.count == 1)
        #expect(d.highlights[0].range == NSRange(location: 14, length: 3))   // "the"
        #expect(d.highlights[0].style == .background(yellow))
    }

    @Test func colorlessHighlightIsDotted() {
        let d = ChapterDecorations.build(items: [item(1, 0, 7)], bookmarkVerses: [], viewingTranslationID: "ESV", layout: layout)
        #expect(d.highlights[0].style == .dottedUnderline)
    }

    @Test func crossVerseHighlightSpansTheNumber() {
        let d = ChapterDecorations.build(items: [item(1, 2, 12, 3, color: yellow)], bookmarkVerses: [], viewingTranslationID: "ESV", layout: layout)
        #expect(d.highlights[0].range == NSRange(location: 14, length: 15))   // "the poor. 2 For"
    }

    @Test func foreignTranslationUnderlinesWholeVerses() {
        let d = ChapterDecorations.build(items: [item(1, 2, 12, 3, translation: "KJV", color: yellow)], bookmarkVerses: [], viewingTranslationID: "ESV", layout: layout)
        #expect(d.highlights[0].range == NSRange(location: 2, length: 38))   // verse 1 text start to verse 2 text end
        #expect(d.highlights[0].style == .dashedUnderline)
    }

    @Test func foreignHighlightOnCombinedVerseUnderlinesTheSpan() {
        let combined = [verse(11, "Eleven."), verse(12, "Twelve and thirteen.", end: 13)]
        let layout = ChapterLayout.build(verses: combined)
        let d = ChapterDecorations.build(items: [item(13, 0, 4, translation: "KJV", color: yellow)], bookmarkVerses: [13], viewingTranslationID: "ERV", layout: layout)
        #expect(d.highlights[0].range == layout.spans[1].textRange)
        #expect(d.bookmarkVerses == [12])
    }

    @Test func offsetsBeyondVerseAreClamped() {
        let d = ChapterDecorations.build(items: [item(2, 4, 99, color: yellow), item(2, 50, 60, color: yellow)], bookmarkVerses: [], viewingTranslationID: "ESV", layout: layout)
        #expect(d.highlights.count == 1)
        #expect(d.highlights[0].range == NSRange(location: 30, length: 10))   // "theirs is." tail of verse 2
    }

    @Test func highlightOnAbsentVerseIsSkipped() {
        let d = ChapterDecorations.build(items: [item(3, 0, 4, color: yellow)], bookmarkVerses: [3, 4], viewingTranslationID: "ESV", layout: layout)
        #expect(d.highlights.isEmpty)
        #expect(d.bookmarkVerses == [4])
    }

    @Test func intersectingIDsIncludeACaretInsideARange() {
        let a = item(1, 0, 7, color: yellow), b = item(1, 4, 11, color: yellow)
        let d = ChapterDecorations.build(items: [a, b], bookmarkVerses: [], viewingTranslationID: "ESV", layout: layout)
        #expect(Set(d.ids(intersecting: NSRange(location: 7, length: 0))) == [a.id, b.id])   // caret between "Blessed" and " are"
        #expect(d.ids(intersecting: NSRange(location: 2, length: 1)) == [a.id])
        #expect(d.ids(intersecting: NSRange(location: 20, length: 2)).isEmpty)
    }
}
```

Note for the caret test: a zero-length range at `location` intersects a decoration when `range.location >= decoration.location && range.location <= NSMaxRange(decoration.range)`; a non-empty range intersects when `NSIntersectionRange` is non-empty.

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter ChapterDecorationsTests`
Expected: compile failure.

- [ ] **Step 3: Implement `MarkupItem.swift` and `ChapterDecorations.swift`** per the Interfaces block.

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI/MarkupItem.swift Packages/ScriptureKit/Sources/ScriptureUI/ChapterDecorations.swift Packages/ScriptureKit/Tests/ScriptureUITests/ChapterDecorationsTests.swift
/usr/bin/git commit -m "feat: map highlights and bookmarks onto chapter layout ranges"
```

---

### Task 5: Rendering in `ChapterTextController`: attributes, gutter, outline, selection reporting

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterTextController.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/MarkupGutterView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/OutlineOverlayView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/MarkupColor+Platform.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterTextView.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderView.swift`
- Modify: `Packages/ScriptureKit/Tests/ScriptureUITests/ChapterTextControllerTests.swift`

**Interfaces:**
- Consumes: Task 3 `SelectionResolver`, `TextSelection`; Task 4 `ChapterDecorations`, `RangeDecoration`, `DecorationStyle`, `MarkupColor`.
- Produces:
  - `extension MarkupColor { public var platformColor: PlatformColor }` — on macOS a dynamic `NSColor(name: nil) { appearance in … }` that picks `darkHex` for `.darkAqua`-matching appearances, else `lightHex`; on iOS `UIColor { traits in … }`.
  - `public struct SelectionReport: Equatable, Sendable { public let selection: TextSelection; public let range: NSRange; public let highlightIDs: [UUID] }` (in `ChapterTextController.swift` under `#if os(macOS)`, or its own file shared with iOS later).
  - `ChapterTextController` gains: `var onSelectionChange: (SelectionReport?) -> Void`; `var menuProvider: (SelectionReport) -> NSMenu?`; `func update(verses:typography:scrollTarget:decorations: ChapterDecorations)` (the old four-argument signature is removed; `decorations` is applied whenever it differs from the last applied value or the text changed); `private(set) var appliedDecorations: ChapterDecorations`; `func selectionReport() -> SelectionReport?`; `func frameOfFirstSegment(of range: NSRange) -> NSRect?` (text-view coordinates, for the share picker); `let gutterView: MarkupGutterView`; `let outlineView: OutlineOverlayView`.
  - Rendering: `applyDecorations()` removes `.backgroundColor`, `.underlineStyle`, `.underlineColor` rendering attributes over `documentRange`, then for each `RangeDecoration` calls `textLayoutManager.addRenderingAttribute`/`setRenderingAttributes` on the `NSTextRange` for `range`: `.background(color)` → `.backgroundColor: color.platformColor`, blended 50/50 (`NSColor.blended(withFraction: 0.5, of:)`) where a background already exists on part of the range; `.dottedUnderline` → `.underlineStyle: NSUnderlineStyle([.single, .patternDot]).rawValue`, `.underlineColor: NSColor.secondaryLabelColor`; `.dashedUnderline` → `.underlineStyle: NSUnderlineStyle([.single, .patternDash]).rawValue`, `.underlineColor: NSColor.tertiaryLabelColor`.
  - Gutter: `MarkupGutterView: NSView` (subview of the text view, `hitTest` returns nil) with `var glyphRects: [NSRect]` drawing `NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: "Bookmark")` tinted `.secondaryLabelColor` at 13 pt; the controller computes one rect per `bookmarkVerses` entry at x = `textContainerInset.width - 26`, y = the verse number's line top (same line-fragment lookup `performPendingScroll` uses), recomputed on `frameDidChangeNotification` and after `applyDecorations`.
  - Outline: `OutlineOverlayView: NSView` (subview, `hitTest` nil) with `var segmentRects: [NSRect]`, stroking each rect inset by -2 with a 1.5 pt `NSColor.controlAccentColor` rounded rect (radius 3). The controller fills it for `decorations.outlinedID` by `enumerateTextSegments(in:type: .standard, options: [.rangeNotRequired])` over the decoration's range, converting frames by the container inset, and calls `textView.scrollRangeToVisible(range)` when the outlined id changes. An unknown id clears the outline.
  - Selection: the controller is the text view's `NSTextViewDelegate`; `textViewDidChangeSelection` (ignored while `isReplacingText`) resolves `textView.selectedRange()` through `SelectionResolver.resolve(_:in:verses:)` and `appliedDecorations.ids(intersecting:)`, then calls `onSelectionChange` with the report or nil (nil when the resolver returns nil; a caret inside a highlight still yields a report with that highlight's id and a zero-length `range`, with `selection` resolved from the containing highlight's range so the menu can act on it).
  - Context menu: `ColumnTextView.menu(for:)` asks its `menuDelegate: ChapterTextController?`; the controller, when the selection is empty, selects the word at `characterIndexForInsertion(at:)` via `selectionRange(forProposedRange:granularity: .selectByWord)`, then returns `menuProvider(report)` or nil.
  - `ChapterTextView` gains `decorations: ChapterDecorations`, `onSelectionChange: (SelectionReport?) -> Void`, and `menuProvider: (SelectionReport, ChapterTextController) -> NSMenu?`; the menu builder receives the controller so share can anchor on `controller.textView` and `frameOfFirstSegment(of: report.range)`.
  - `ReaderView` gains `public struct Markup { public var decorations: ChapterDecorations; public var onSelectionChange: (SelectionReport?) -> Void; public var menuProvider: (SelectionReport, ChapterTextController) -> NSMenu? }` under `#if os(macOS)` and an optional `markup: ReaderView.Markup? = nil` init parameter; the iOS branch ignores it.

- [ ] **Step 1: Write the failing tests** (append to `ChapterTextControllerTests`; the existing `update` calls gain `decorations: .none`)

```swift
    private var yellow: MarkupColor { MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00") }
    private var blue: MarkupColor { MarkupColor(lightHex: "#B9DDFF", darkHex: "#1F4C7A") }

    private func renderingAttributes(_ controller: ChapterTextController, at index: Int) -> [NSAttributedString.Key: Any] {
        let storage = controller.textView.textContentStorage!
        let location = storage.location(storage.documentRange.location, offsetBy: index)!
        return controller.textView.textLayoutManager!.renderingAttributes(at: location)
    }

    @Test func highlightsBecomeRenderingAttributesAndOverlapsBlend() {
        let controller = makeController { _ in }
        let chapter = verses(count: 3)
        let layout = ChapterLayout.build(verses: chapter)
        let a = MarkupItem(id: UUID(), verse: 1, endVerse: 1, startOffset: 0, endOffset: 10, translationID: "WEB", color: yellow, hasNote: false)
        let b = MarkupItem(id: UUID(), verse: 1, endVerse: 1, startOffset: 5, endOffset: 15, translationID: "WEB", color: blue, hasNote: false)
        let c = MarkupItem(id: UUID(), verse: 2, endVerse: 2, startOffset: 0, endOffset: 5, translationID: "WEB", color: nil, hasNote: true)
        let decorations = ChapterDecorations.build(items: [a, b, c], bookmarkVerses: [3], viewingTranslationID: "WEB", layout: layout)
        controller.update(verses: chapter, typography: .default, scrollTarget: nil, decorations: decorations)
        let v1 = layout.spans[0].textRange.location, v2 = layout.spans[1].textRange.location
        let onlyA = renderingAttributes(controller, at: v1 + 2)[.backgroundColor] as? NSColor
        let both = renderingAttributes(controller, at: v1 + 7)[.backgroundColor] as? NSColor
        let onlyB = renderingAttributes(controller, at: v1 + 12)[.backgroundColor] as? NSColor
        #expect(onlyA != nil && onlyB != nil && both != nil)
        #expect(both != onlyA && both != onlyB)
        #expect((renderingAttributes(controller, at: v2 + 1)[.underlineStyle] as? Int) == NSUnderlineStyle([.single, .patternDot]).rawValue)
        #expect(renderingAttributes(controller, at: v2 + 1)[.backgroundColor] == nil)
    }

    @Test func bookmarkGlyphsAndOutlineFollowTheDecorations() {
        let controller = makeController { _ in }
        let chapter = verses(count: 6)
        let layout = ChapterLayout.build(verses: chapter)
        let a = MarkupItem(id: UUID(), verse: 5, endVerse: 5, startOffset: 0, endOffset: 10, translationID: "WEB", color: yellow, hasNote: false)
        var decorations = ChapterDecorations.build(items: [a], bookmarkVerses: [2, 5], viewingTranslationID: "WEB", layout: layout)
        controller.update(verses: chapter, typography: .default, scrollTarget: nil, decorations: decorations)
        sizeToContent(controller)
        #expect(controller.gutterView.glyphRects.count == 2)
        #expect(controller.gutterView.glyphRects[0].minY < controller.gutterView.glyphRects[1].minY)
        #expect(controller.outlineView.segmentRects.isEmpty)
        decorations.outlinedID = a.id
        controller.update(verses: chapter, typography: .default, scrollTarget: nil, decorations: decorations)
        #expect(controller.outlineView.segmentRects.count >= 1)
        decorations.outlinedID = nil
        controller.update(verses: chapter, typography: .default, scrollTarget: nil, decorations: decorations)
        #expect(controller.outlineView.segmentRects.isEmpty)
    }

    @Test func selectionChangesAreReportedWithTheHighlightsTheyTouch() {
        var reports: [SelectionReport?] = []
        let controller = makeController { _ in }
        controller.onSelectionChange = { reports.append($0) }
        let chapter = verses(count: 3)
        let layout = ChapterLayout.build(verses: chapter)
        let a = MarkupItem(id: UUID(), verse: 1, endVerse: 1, startOffset: 0, endOffset: 10, translationID: "WEB", color: yellow, hasNote: false)
        let decorations = ChapterDecorations.build(items: [a], bookmarkVerses: [], viewingTranslationID: "WEB", layout: layout)
        controller.update(verses: chapter, typography: .default, scrollTarget: nil, decorations: decorations)
        let v1 = layout.spans[0].textRange.location
        controller.textView.setSelectedRange(NSRange(location: v1 + 2, length: 3))
        #expect(reports.last??.selection.quotedText == "rse")
        #expect(reports.last??.highlightIDs == [a.id])
        controller.textView.setSelectedRange(NSRange(location: v1 + 4, length: 0))      // caret inside a
        #expect(reports.last??.highlightIDs == [a.id])
        #expect(reports.last??.selection.startOffset == 0 && reports.last??.selection.endOffset == 10)
        controller.textView.setSelectedRange(NSRange(location: 0, length: 1))            // the verse number only
        #expect(reports.last! == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter ChapterTextControllerTests`
Expected: compile failure (`extra argument 'decorations'`, missing `gutterView`).

- [ ] **Step 3: Implement** the controller changes, the two overlay views, `MarkupColor+Platform.swift`, and thread the new parameters through `ChapterTextView` and `ReaderView` (`ReaderView.Markup` defaults to nil; `MainWindowView` compiles unchanged for now). Blending: enumerate `textLayoutManager.enumerateRenderingAttributes(from:reverse:using:)` over the new range, collecting existing background runs, then set the blended color on those sub-ranges and the plain color elsewhere.

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all pass, including the pre-existing five controller tests.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI Packages/ScriptureKit/Tests/ScriptureUITests/ChapterTextControllerTests.swift
/usr/bin/git commit -m "feat: draw highlights, bookmark glyphs and outlines in the TextKit 2 reader; report selections"
```

---

### Task 6: `MarkupModel` view model

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/MarkupModel.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NotesColumnItem.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/MarkupModelTests.swift`

**Interfaces:**
- Consumes: `MarkupStore`, `MarkupContainer` (Tasks 1–2); `TextSelection`, `SelectionReport` (Tasks 3, 5); `MarkupItem`, `ChapterDecorations` (Task 4); `ChapterLayout`.
- Produces:
  - `public enum NotesColumnItem: Identifiable, Equatable { case note(NoteCard); case compactHighlight(CompactRow); public var id: UUID }`
  - `public struct NoteCard: Identifiable, Equatable { public let id: UUID /* note uuid */; public let highlightID: UUID?; public let referenceString: String; public let quotedText: String; public let body: String; public let modifiedAt: Date; public let color: MarkupColor?; public let isChapterNote: Bool }`
  - `public struct CompactRow: Identifiable, Equatable { public let id: UUID /* highlight uuid */; public let referenceString: String; public let quotedText: String; public let color: MarkupColor? }`
  - `public struct ColorChip: Identifiable, Equatable, Sendable { public let id: UUID; public let name: String; public let color: MarkupColor }`
  - `public enum MarkupMenuItem: Equatable { case swatches([ColorChip], current: UUID?); case addColor; case addNote(existing: Bool); case removeHighlight; case bookmark(verse: Int, isSet: Bool); case copy; case copyWithReference; case share; case askAboutPassage }`
  - `@MainActor @Observable public final class MarkupModel`:
    - `public init(store: MarkupStore, defaults: UserDefaults = .standard)`
    - state: `public private(set) var chapter: ChapterLocation?`, `translationID: String`, `items: [MarkupItem]`, `bookmarkVerses: [Int]`, `colorChips: [ColorChip]`, `columnItems: [NotesColumnItem]`, `chapterNotes: [NoteCard]`, `public private(set) var selectedHighlightIDs: Set<UUID>`, `public var outlinedHighlightID: UUID?`, `public var editingNoteID: UUID?`, `public var isAddColorSheetShown: Bool`, `public var showNotelessHighlights: Bool` (read from and written to `defaults` under `showNotelessHighlights`, default true; changing it rebuilds `columnItems`), `public private(set) var lastError: String?`, `public var decorations: ChapterDecorations` (computed: `ChapterDecorations.build(items:bookmarkVerses:viewingTranslationID:layout:)` using a `layout` built lazily from the loaded verses with `.default` typography; typography does not change ranges).
    - `public func load(chapter: ChapterLocation?, translationID: String, verses: [Verse])` — reloads items, bookmarks, colors, column items; clears selection/outline/editing.
    - `public func reload()` — re-queries the store for the current chapter.
    - `public func setSelection(_ report: SelectionReport?)` — stores the report, sets `selectedHighlightIDs = Set(report?.highlightIDs ?? [])`, clears `outlinedHighlightID`.
    - `public func menuItems(for report: SelectionReport) -> [MarkupMenuItem]` — order: `.swatches(colorChips, current: single?.colorID)`, `.addColor`, `.addNote(existing: single?.hasNote ?? false)`, `.removeHighlight` (only when `single` exists and has a color), `.bookmark(verse: report.selection.verse, isSet:)`, `.copy`, `.copyWithReference`, `.share`, `.askAboutPassage`; `single` = the one highlight in `report.highlightIDs` whose range contains `report.range` when exactly one does (Ruling 5).
    - actions, each taking the report returned by the text view: `applyColor(_ colorID: UUID, to report: SelectionReport)`, `addColorAndApply(name: String, lightHex: String, darkHex: String, to report: SelectionReport)`, `addNote(to report: SelectionReport)` (creates the note with empty body and sets `editingNoteID`), `removeHighlight(in report: SelectionReport)`, `toggleBookmark(for report: SelectionReport)`, `copyText(for report: SelectionReport) -> String` (quoted text), `copyWithReference(for report: SelectionReport) -> String`, `shareText(for report: SelectionReport) -> String` (same as copy with reference).
    - column actions: `beginEditing(noteID: UUID)`, `expandCompactRow(highlightID: UUID)` (creates the empty note, sets `editingNoteID`), `updateNoteBody(noteID: UUID, body: String)` (saves on each change, debouncing is the view's job), `endEditing(noteID: UUID)` (trims; deletes the note when empty and the highlight when then empty; clears `editingNoteID`), `deleteNote(noteID: UUID)`, `deleteHighlight(id: UUID)`, `focus(highlightID: UUID)` (sets `outlinedHighlightID`), `highlightID(forNote noteID: UUID) -> UUID?`.
    - `columnItems` rules: chapter notes first (as `.note` with `isChapterNote: true`), then every highlight in store order: `.note` when it has a note, else `.compactHighlight` only when `showNotelessHighlights`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite struct MarkupModelTests {
    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)
    private func verse(_ n: Int, _ text: String) -> Verse {
        Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "ESV", text: text, breakAfter: false)
    }
    private var chapter: [Verse] { [verse(1, "Blessed are the poor."), verse(2, "For theirs is."), verse(3, "Blessed mourners.")] }

    private func makeModel() throws -> (MarkupModel, MarkupStore) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(context: container.mainContext)
        let defaults = UserDefaults(suiteName: "MarkupModelTests-\(UUID().uuidString)")!
        let model = MarkupModel(store: store, defaults: defaults)
        model.load(chapter: matthew5, translationID: "ESV", verses: chapter)
        return (model, store)
    }

    private func report(_ model: MarkupModel, verse: Int, _ start: Int, _ end: Int, text: String) -> SelectionReport {
        let layout = ChapterLayout.build(verses: chapter)
        let span = layout.span(forVerse: verse)!
        let range = NSRange(location: span.textRange.location + start, length: end - start)
        let selection = TextSelection(book: "MAT", chapter: 5, verse: verse, endVerse: verse, startOffset: start, endOffset: end, quotedText: text)
        return SelectionReport(selection: selection, range: range, highlightIDs: model.decorations.ids(intersecting: range))
    }

    @Test func applyingAColorCreatesAHighlightAndACompactRow() throws {
        let (model, store) = try makeModel()
        let yellow = model.colorChips[0].id
        model.applyColor(yellow, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let stored = try store.highlights(in: matthew5)
        #expect(stored.count == 1 && stored[0].colorID == yellow && stored[0].quotedText == "Blessed")
        #expect(model.items.count == 1 && model.decorations.highlights.count == 1)
        guard case .compactHighlight(let row)? = model.columnItems.first else { Issue.record("expected a compact row"); return }
        #expect(row.referenceString == "Matthew 5:1" && row.quotedText == "Blessed")
    }

    @Test func menuOffersRecolorAndRemoveInsideASingleHighlight() throws {
        let (model, _) = try makeModel()
        let yellow = model.colorChips[0].id
        model.applyColor(yellow, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let inside = report(model, verse: 1, 2, 4, text: "es")
        #expect(inside.highlightIDs.count == 1)
        let items = model.menuItems(for: inside)
        #expect(items[0] == .swatches(model.colorChips, current: yellow))
        #expect(items[1] == .addColor)
        #expect(items[2] == .addNote(existing: false))
        #expect(items[3] == .removeHighlight)
        #expect(items[4] == .bookmark(verse: 1, isSet: false))
        #expect(Array(items[5...]) == [.copy, .copyWithReference, .share, .askAboutPassage])
        model.applyColor(model.colorChips[2].id, to: inside)
        #expect(model.items.count == 1 && model.items[0].color == model.colorChips[2].color)
        model.removeHighlight(in: inside)
        #expect(model.items.isEmpty)
    }

    @Test func menuOutsideAnyHighlightHasNoRemove() throws {
        let (model, _) = try makeModel()
        let items = model.menuItems(for: report(model, verse: 2, 0, 3, text: "For"))
        #expect(items[0] == .swatches(model.colorChips, current: nil))
        #expect(!items.contains(.removeHighlight))
    }

    @Test func addingANoteCreatesAColorlessAnchorAndStartsEditing() throws {
        let (model, store) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let stored = try store.highlights(in: matthew5)
        #expect(stored.count == 1 && stored[0].colorID == nil && stored[0].note != nil)
        #expect(model.editingNoteID == stored[0].note?.uuid)
        #expect(model.decorations.highlights[0].style == .dottedUnderline)
        guard case .note(let card)? = model.columnItems.first else { Issue.record("expected a card"); return }
        #expect(card.highlightID == stored[0].uuid && card.body == "")
    }

    @Test func endingEmptyEditDeletesNoteAndColorlessAnchor() throws {
        let (model, store) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "   \n")
        model.endEditing(noteID: noteID)
        #expect(model.editingNoteID == nil)
        #expect(try store.highlights(in: matthew5).isEmpty)
        #expect(model.columnItems.isEmpty)
    }

    @Test func endingEmptyEditKeepsColoredHighlight() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let highlightID = model.items[0].id
        model.expandCompactRow(highlightID: highlightID)
        let noteID = model.editingNoteID!
        model.endEditing(noteID: noteID)
        let stored = try store.highlights(in: matthew5)
        #expect(stored.count == 1 && stored[0].note == nil)
        guard case .compactHighlight? = model.columnItems.first else { Issue.record("expected the compact row back"); return }
    }

    @Test func editingASavedNoteKeepsItAndUpdatesTheCard() throws {
        let (model, _) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "**bold** thought")
        model.endEditing(noteID: noteID)
        guard case .note(let card)? = model.columnItems.first else { Issue.record("expected a card"); return }
        #expect(card.body == "**bold** thought")
        #expect(model.items[0].hasNote)
    }

    @Test func notelessRowsHideWithTheSetting() throws {
        let (model, _) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        model.updateNoteBody(noteID: model.editingNoteID!, body: "kept")
        model.endEditing(noteID: model.editingNoteID!)
        #expect(model.columnItems.count == 2)
        model.showNotelessHighlights = false
        #expect(model.columnItems.count == 1)
        guard case .note? = model.columnItems.first else { Issue.record("expected only the note"); return }
    }

    @Test func selectionLightsCardsAndFocusOutlinesHighlights() throws {
        let (model, _) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let id = model.items[0].id
        model.setSelection(report(model, verse: 1, 2, 4, text: "es"))
        #expect(model.selectedHighlightIDs == [id])
        model.focus(highlightID: id)
        #expect(model.decorations.outlinedID == id)
        model.setSelection(nil)
        #expect(model.selectedHighlightIDs.isEmpty && model.decorations.outlinedID == nil)
    }

    @Test func bookmarkTogglesAndCopyStringsUseTheSelection() throws {
        let (model, _) = try makeModel()
        let r = report(model, verse: 3, 0, 7, text: "Blessed")
        model.toggleBookmark(for: r)
        #expect(model.bookmarkVerses == [3] && model.decorations.bookmarkVerses == [3])
        #expect(model.menuItems(for: r).contains(.bookmark(verse: 3, isSet: true)))
        model.toggleBookmark(for: r)
        #expect(model.bookmarkVerses.isEmpty)
        #expect(model.copyText(for: r) == "Blessed")
        #expect(model.copyWithReference(for: r) == "\u{201C}Blessed\u{201D} \u{2014} Matthew 5:3 (ESV)")
    }

    @Test func chapterNotesAppearInTheBandAndAsCards() throws {
        let (model, store) = try makeModel()
        let note = Note(body: "On the whole chapter", scope: .chapter, book: "MAT", chapter: 5, verse: 1, endVerse: 1, translationID: "ESV", quotedText: "")
        store.context.insert(note)
        try store.context.save()
        model.reload()
        #expect(model.chapterNotes.map(\.body) == ["On the whole chapter"])
        guard case .note(let card)? = model.columnItems.first else { Issue.record("expected a card"); return }
        #expect(card.isChapterNote && card.highlightID == nil)
    }

    @Test func addingAColorFromTheMenuAppliesItAndListsIt() throws {
        let (model, _) = try makeModel()
        model.addColorAndApply(name: "Teal", lightHex: "#A0E0E0", darkHex: "#104040", to: report(model, verse: 1, 0, 7, text: "Blessed"))
        #expect(model.colorChips.map(\.name).last == "Teal")
        #expect(model.items[0].color == MarkupColor(lightHex: "#A0E0E0", darkHex: "#104040"))
    }
}
```

`MarkupStore` exposes `public let context: ModelContext` for the chapter-note test.

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter MarkupModelTests`
Expected: compile failure, `cannot find 'MarkupModel'`.

- [ ] **Step 3: Implement `NotesColumnItem.swift` and `MarkupModel.swift`** per the Interfaces block. Every store call is wrapped: on error set `lastError = String(describing: error)` and log through `Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "markup")`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI/MarkupModel.swift Packages/ScriptureKit/Sources/ScriptureUI/NotesColumnItem.swift Packages/ScriptureKit/Sources/ScriptureModel/MarkupStore.swift Packages/ScriptureKit/Tests/ScriptureUITests/MarkupModelTests.swift
/usr/bin/git commit -m "feat: MarkupModel view model for highlights, notes, bookmarks and the notes column"
```

---

### Task 7: Context menu, swatch row, add-color sheet, share and pasteboard; app wiring

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/MarkupContextMenu.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/SwatchRowView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/AddColorSheet.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/MainWindowView.swift`
- Modify: `Apps/Mac/ReadingThroughScripture.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `MarkupModel.menuItems(for:)` and actions (Task 6); `ChapterTextController.textView`, `frameOfFirstSegment(of:)` (Task 5); `ReaderView.Markup` (Task 5); `MarkupContainer.make`, `seedDefaultColorsIfNeeded`, `MarkupStore` (Tasks 1–2).
- Produces:
  - `@MainActor public enum MarkupContextMenu { public static func make(for report: SelectionReport, model: MarkupModel, controller: ChapterTextController) -> NSMenu }` — one `NSMenuItem` per `MarkupMenuItem`: `.swatches` → an item whose `view` is an `NSHostingView(rootView: SwatchRowView(chips:current:onPick:onAdd:))` (height 36; picking calls `model.applyColor` and `menu.cancelTracking()`); `.addColor` → "Add Color…" with image `plus.circle`, sets `model.pendingColorReport = report` and `model.isAddColorSheetShown = true`; `.addNote(existing:)` → "Add Note" / "Edit Note"; `.removeHighlight` → "Remove Highlight"; `.bookmark(verse:isSet:)` → "Bookmark Verse N" / "Remove Bookmark from Verse N" (image `bookmark` / `bookmark.slash`); `.copy` → "Copy" writes `model.copyText(for:)` to `NSPasteboard.general` as `.string`; `.copyWithReference` → "Copy with Reference"; `.share` → "Share…" shows `NSSharingServicePicker(items: [model.shareText(for:)])` relative to `controller.frameOfFirstSegment(of: report.range) ?? controller.textView.bounds` of `controller.textView`, `preferredEdge: .minY`; `.askAboutPassage` → "Ask About This Passage" disabled, image `sparkles`. A separator after the swatch row and before Copy.
  - `MarkupModel` gains `public var pendingColorReport: SelectionReport?` (Task 6's file; set by the menu, consumed by the sheet).
  - `public struct SwatchRowView: View { init(chips: [ColorChip], current: UUID?, onPick: (UUID) -> Void, onAdd: () -> Void) }` — a horizontal row of 22 pt circles filled with `Color(nsColor: chip.color.platformColor)`, a `checkmark` overlay on `current`, help text = chip name, then a `plus.circle` button.
  - `public struct AddColorSheet: View { init(onAdd: (String, String, String) -> Void, onCancel: () -> Void) }` — `TextField("Name")`, `ColorPicker("Light")` and `ColorPicker("Dark")` (both default to the picked light color until the dark one is touched), Cancel and Add (disabled while the name is blank); hex strings via `ColorHex.string`.
  - `ReadingThroughScriptureApp`: creates `MarkupContainer.make()` → seeds colors → `MarkupStore` → `@State private var markup: MarkupModel?` next to `model`; a container failure shows in the same `ContentUnavailableView` path.
  - `MainWindowView` takes `markup: MarkupModel`, passes `ReaderView(markup: .init(decorations: markup.decorations, onSelectionChange: { markup.setSelection($0) }, menuProvider: { MarkupContextMenu.make(for: $0, model: markup, controller: $1) }))`, calls `markup.load(chapter: model.location, translationID: model.translationID, verses: model.verses)` from `.onChange(of:)` on `model.location`, `model.translationID` and `model.verses` (initial value too), and presents `AddColorSheet` with `.sheet(isPresented: $markup.isAddColorSheetShown)` whose `onAdd` calls `markup.addColorAndApply(..., to: markup.pendingColorReport!)` when a report is pending.
  - `project.pbxproj`: add `XCSwiftPackageProductDependency` `1A0000000000000000000018 /* ScriptureModel */` (`productName = ScriptureModel`), a `PBXBuildFile` `1A0000000000000000000019 /* ScriptureModel in Frameworks */` referencing it, list it in the Frameworks phase `files` and in `packageProductDependencies`.

- [ ] **Step 1: Implement the three ScriptureUI files, the model's `pendingColorReport`, and the app wiring** as specified. No unit test covers AppKit menus; the test is the build plus the manual check in Task 10.

- [ ] **Step 2: Build the package and the app**

Run: `DEVELOPER_DIR=$XC swift build --package-path Packages/ScriptureKit` then the app build command from Global Constraints.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Run the package tests**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI Apps/Mac
/usr/bin/git commit -m "feat: selection context menu with swatches, notes, bookmarks, copy and share; app creates the markup store"
```

---

### Task 8: Notes column, chapter note band, toolbar and View-menu toggle

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NotesColumnView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NoteCardView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/CompactHighlightRow.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterNoteBandView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NoteMarkdown.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/NoteMarkdownTests.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderView.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/MainWindowView.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`

**Interfaces:**
- Consumes: `MarkupModel` state and column actions (Task 6).
- Produces:
  - `public enum NoteMarkdown { public static func attributed(_ body: String) -> AttributedString }` — `AttributedString(markdown:options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))`, falling back to `AttributedString(body)` when parsing throws.
  - `public struct NotesColumnView: View { public init(model: MarkupModel) }` — width 320, a header "Notes" with the chapter title, a `ScrollView` of `columnItems`: `.note` → `NoteCardView`, `.compactHighlight` → `CompactHighlightRow`; an empty state `ContentUnavailableView("No notes yet", systemImage: "note.text", description: Text("Select text and right-click to highlight or add a note."))`.
  - `NoteCardView(card: NoteCard, isLit: Bool, isEditing: Bool, onTap:, onBeginEdit:, onBodyChange:, onEndEdit:, onDelete:)` — reference line in `.caption` with a swatch dot when `card.color != nil`, quoted text (`.secondary`, italic, 2 lines), body via `Text(NoteMarkdown.attributed(card.body))` or a `TextEditor` (min height 80) when editing, with `@FocusState` focused on appear so the cursor is placed; buttons `pencil` / `checkmark` (toggles editing, `onEndEdit` on checkmark and on focus loss) and `trash`; `isLit` draws a 1.5 pt `Color.accentColor` rounded border and a faint accent background; tap on the card body calls `onTap` (→ `model.focus(highlightID:)`).
  - `CompactHighlightRow(row: CompactRow, isLit: Bool, onTap:, onExpand:)` — one line: swatch dot (or a dotted-underline glyph `underline` when colorless), reference in `.caption`, quoted text truncated; tap → `onTap` (focus), the `plus.bubble` button or double-click → `onExpand` (→ `model.expandCompactRow`).
  - `ChapterNoteBandView(notes: [NoteCard])` — renders nothing when empty; otherwise a soft band (`.quaternary` background, 8 pt radius) with `note.text` and each note's markdown, placed by `ReaderView` under the heading; `ReaderView` gains `chapterNotes: [NoteCard] = []`.
  - `MainWindowView`: `@AppStorage("showNotesColumn") private var showNotesColumn = true`; reader screen body becomes `HStack(spacing: 0) { reader; if showNotesColumn { Divider(); NotesColumnView(model: markup) } }`; toolbar gains `Button { showNotesColumn.toggle() } label: { Label("Notes", systemImage: "sidebar.right") }.help("Toggle Notes Column (⌥⌘N)")` in `.primaryAction` after the search button.
  - `ReadingThroughScriptureApp`: `CommandMenu("View") { Button("Toggle Notes Column") { … }.keyboardShortcut("n", modifiers: [.command, .option]) }` toggling the same `UserDefaults` key through `@AppStorage` in the App struct.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ScriptureUI

@Suite struct NoteMarkdownTests {
    @Test func inlineMarkdownRenders() {
        let attributed = NoteMarkdown.attributed("a **bold** word")
        #expect(String(attributed.characters) == "a bold word")
        let bold = attributed.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        #expect(bold != nil)
    }

    @Test func lineBreaksArePreserved() {
        #expect(String(NoteMarkdown.attributed("one\ntwo").characters) == "one\ntwo")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter NoteMarkdownTests`
Expected: compile failure.

- [ ] **Step 3: Implement `NoteMarkdown`, the four views, the `ReaderView` band slot, and the window/app changes.**

- [ ] **Step 4: Run tests and build the app**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit` then the app build.
Expected: all tests pass; `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI Packages/ScriptureKit/Tests/ScriptureUITests/NoteMarkdownTests.swift Apps/Mac
/usr/bin/git commit -m "feat: notes column with cards and compact rows, chapter note band, column toggle"
```

---

### Task 9: Settings scene: highlight colors and the noteless-highlights toggle

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/HighlightColorsSettingsView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ColorSettingsModel.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/ColorSettingsModelTests.swift`
- Create: `Apps/Mac/ReadingThroughScripture/SettingsView.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`

**Interfaces:**
- Consumes: `MarkupStore` color methods (Task 2); `MarkupModel.reload()` and `showNotelessHighlights` (Task 6); `ColorHex` (Task 1).
- Produces:
  - `public struct ColorRow: Identifiable, Equatable { public let id: UUID; public var name: String; public var lightHex: String; public var darkHex: String; public let isDefault: Bool; public let highlightCount: Int }`
  - `@MainActor @Observable public final class ColorSettingsModel { public init(store: MarkupStore, onChange: @escaping () -> Void); public private(set) var rows: [ColorRow]; public func reload(); public func add(); /* "New Color", light #D0D0D0, dark #505050 */ public func rename(id: UUID, to: String); public func setHex(id: UUID, lightHex: String, darkHex: String); public func move(fromOffsets: IndexSet, toOffset: Int); public func delete(id: UUID) }` — every mutation reloads `rows` and calls `onChange` (the app passes `markup.reload`).
  - `public struct HighlightColorsSettingsView: View { public init(model: ColorSettingsModel) }` — `Form` with a `List(selection:)` of rows: swatch, editable name `TextField`, two `ColorPicker`s (light, dark), `.onMove`; below the list `+` (`plus`) and `−` (`minus`) buttons; delete asks `confirmationDialog("Delete \(name)?", …)` with message "N highlights use this color. They keep their notes but lose the color." when `highlightCount > 0`; a `Toggle("Show highlights without notes in the column", isOn:)` bound to `@AppStorage("showNotelessHighlights")`.
  - `SettingsView` (app): `TabView { HighlightColorsSettingsView(model:).tabItem { Label("Markup", systemImage: "highlighter") } }` sized 480×420.
  - `ReadingThroughScriptureApp`: `Settings { SettingsView(colors: colorSettings) }` where `colorSettings = ColorSettingsModel(store:onChange:)` is created with the markup model; `MarkupModel.showNotelessHighlights` reads `defaults` each time `columnItems` is rebuilt, and the window observes the key with `@AppStorage` and calls `markup.reload()` on change so the column refreshes when Settings flips it.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ColorSettingsModelTests {
    private func makeModel() throws -> (ColorSettingsModel, MarkupStore, () -> Int) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(context: container.mainContext)
        var changes = 0
        let model = ColorSettingsModel(store: store) { changes += 1 }
        return (model, store, { changes })
    }

    @Test func rowsListDefaultsInOrderWithUsageCounts() throws {
        let (model, store, _) = try makeModel()
        let yellow = model.rows[0].id
        try store.addHighlight(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "ESV", colorID: yellow, quotedText: "Ble")
        model.reload()
        #expect(model.rows.map(\.name) == ["Yellow", "Green", "Blue", "Pink", "Orange"])
        #expect(model.rows[0].highlightCount == 1 && model.rows[1].highlightCount == 0)
    }

    @Test func addRenameMoveDeleteNotifyTheReader() throws {
        let (model, _, changes) = try makeModel()
        model.add()
        #expect(model.rows.last?.name == "New Color" && model.rows.count == 6)
        let id = model.rows.last!.id
        model.rename(id: id, to: "Teal")
        model.setHex(id: id, lightHex: "#A0E0E0", darkHex: "#104040")
        model.move(fromOffsets: IndexSet(integer: 5), toOffset: 0)
        #expect(model.rows.first?.name == "Teal" && model.rows.first?.lightHex == "#A0E0E0")
        model.delete(id: id)
        #expect(model.rows.count == 5)
        #expect(changes() == 5)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter ColorSettingsModelTests`
Expected: compile failure.

- [ ] **Step 3: Implement `ColorSettingsModel`, `HighlightColorsSettingsView`, `SettingsView`, and the `Settings` scene.**

- [ ] **Step 4: Run tests and build the app**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit` then the app build.
Expected: all tests pass; `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add Packages/ScriptureKit/Sources/ScriptureUI Packages/ScriptureKit/Tests/ScriptureUITests/ColorSettingsModelTests.swift Apps/Mac
/usr/bin/git commit -m "feat: Settings scene with highlight color editor and noteless-highlights toggle"
```

---

### Task 10: End-to-end verification, README, hand-over note

**Files:**
- Modify: `README.md` (keyboard line gains ⌥⌘N; a "Markup" paragraph: right-click a selection; data lives in `~/Library/Application Support/ReadingThroughScripture/Markup.store`; "Current plan" link → milestone 3)
- Create (outside the repo): `/Users/matt/Library/Application Support/Claude/side-session-notes/local_05d645b7-369b-4cb6-b9d2-04273c3d42e9/milestone-3-markup.md`

- [ ] **Step 1: Build and launch the app** from `Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app` (`open -n`), with a fresh store (move any existing `Markup.store*` aside first, note that in the hand-over).

- [ ] **Step 2: Verify against the spec's Markup checklist** and record each result with a screenshot via `screencapture -x` where a human must judge: (a) Matthew 5, select a phrase, right-click, pick Yellow → background drawn on the exact range; a compact row appears; (b) Add Note on another phrase → dotted underline, card with editor and cursor, type, click elsewhere → card shows markdown; (c) quit (`⌘Q`) and relaunch → both persist; (d) Settings (⌘,) → toggle "Show highlights without notes" → compact row hides and returns; (e) Copy with Reference → `pbpaste` prints `“…” — Matthew 5:N (ESV)`; (f) Share… → the picker appears; (g) Bookmark Verse N → `bookmark.fill` in the gutter; (h) switch to KJV → the ESV highlight shows as a dashed underline on the whole verse; (i) click a card → the text scrolls and the outline appears; select inside a highlight → its card lights; (j) ⌥⌘N and the toolbar button hide and show the column.
  Without a human at the keyboard, drive what can be driven without AppleScript (relaunch persistence through the store file, `defaults` for the two keys) and list the rest as "to confirm by hand" in the hand-over.

- [ ] **Step 3: Update `README.md`** and commit.

```bash
/usr/bin/git add README.md
/usr/bin/git commit -m "docs: milestone 3 markup notes in README"
```

- [ ] **Step 4: Write the hand-over note** (branch, commits, what was verified and how, what was not, rulings taken during execution, review outcome).

---

## Self-review notes

- Spec coverage: models + CloudKit rules (T1), delete-when-empty (T2), context menu order with swatches and "+" (T7), exact-range background, overlaps, dotted and dashed underlines, gutter glyph (T4–T5), notes column with compact rows, setting, expand-to-edit with cursor, card ↔ text linking both ways (T6, T8), chapter note band (T8), markdown display with plain editor (T8), Copy / Copy with Reference / Share (T3, T7), settings colors add/rename/reorder/delete and toggle (T9), persistence across relaunch (T1, T10), Ask placeholder (T7).
- Not in milestone 3 by the spec: Notes browser (M4), chat (M5), chapter-note creation (M5), sync (M6), iOS (M7).
- Names used consistently: `MarkupStore`, `MarkupModel`, `MarkupItem`, `ChapterDecorations`, `RangeDecoration`, `SelectionReport`, `TextSelection`, `SelectionResolver`, `NotesColumnItem`, `NoteCard`, `CompactRow`, `ColorChip`, `MarkupMenuItem`, `ColorSettingsModel`, `ColorRow`.
