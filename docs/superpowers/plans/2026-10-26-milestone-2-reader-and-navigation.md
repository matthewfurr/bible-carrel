# Milestone 2: Reader and Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS app that opens to the front page (book lists plus chapter grid), reads any chapter in any bundled translation with TextKit 2 rendering, jumps anywhere from a ⌘K palette, and reopens where the reader left off.

**Architecture:** A new `ScriptureUI` library in `Packages/ScriptureKit` holds everything the iOS app will reuse: the reading-position store, navigation history, the verse layout builder (attributed string plus per-verse character ranges), `ReaderView`, `FrontPageView`, `CommandPaletteView`, and an `@Observable` `NavigationModel` that ties them to `BibleStore`. A thin app target in `Apps/Mac` owns the window, toolbar, menus and the bundled `bible.sqlite`. The temporary `ScriptureMacPreview` executable is deleted once the app exists.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit `NSTextView` with TextKit 2 (`NSTextLayoutManager`), `UserDefaults` for local persistence (SwiftData arrives in milestone 3), Swift Testing, Xcode 26.6 (`xcodebuild`), GRDB 7 (unchanged, only dependency).

**Spec:** `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (sections Navigation, Reading, Architecture → UI, Milestones → 2)

## Global Constraints

- Minimum macOS 26 (`MACOSX_DEPLOYMENT_TARGET = 26.0`); the package already declares `.macOS(.v26), .iOS(.v26)`; Swift language mode 6.
- GRDB is the only third-party dependency. No new packages.
- ESV is the default translation (`"ESV"`); the translation pill lists every row of `BibleStore.translations()`.
- SF Symbols only, never emoji. Toolbar symbols: Home `house`, back `chevron.left`, forward `chevron.right`, palette `magnifyingglass`, translation pill `chevron.up.chevron.down`.
- Reading position = `(book, chapter, firstVisibleVerse, translationID)` and is translation-independent except for the translation field: switching translations keeps `(book, chapter, firstVisibleVerse)`.
- Chapter grid: five columns, numbers only, book name as header, Old Testament and New Testament sections always present, Apocrypha section only when `books(in:)` for the active translation contains a `.apocrypha` book.
- Verse numbers render as small superscripts; poetry lines come from `"\n"` in `Verse.text`; a paragraph gap follows a verse with `breakAfter`; a combined verse is labelled `"12-13"` from `Verse.endVerse`.
- `Build/bible.sqlite` is generated, not committed, and is bundled into the app by a run-script build phase that calls `Scripts/build-bible.sh` when the file is missing.
- Every `swift`/`xcodebuild` command sets `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (abbreviated `$XC` below: `export XC=/Applications/Xcode.app/Contents/Developer`). Package tests: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`.
- No Apple Developer team: the app target uses ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`), no entitlements, no sandbox.
- Bundle identifier `com.matthewfurr.ReadingThroughScripture`; product name `ReadingThroughScripture`; `UserDefaults` key `readingPosition`.

## Review Focus

1. Switching to a translation that lacks the current book (WEB Tobit → ESV): the app must land on the front page of the new translation, not crash or show an empty reader. Pinned in Task 7 (`switchingToTranslationWithoutBookGoesHome`).
2. A stored reading position that no longer resolves (unknown translation id, book absent, chapter beyond count): launch shows the front page and the bad position is ignored. Pinned in Task 7 (`invalidStoredPositionFallsBackToFrontPage`).
3. A reference whose chapter is beyond the book (`Rom 99`) or whose verse is absent from the chapter (`Matt 17:21` in ESV, which omits it): no "go to" item for the chapter; a verse jump to an absent verse scrolls to the nearest following verse rather than nowhere. Pinned in Task 6 (`chapterBeyondBookIsNotOffered`) and Task 3 (`spanForMissingVerseReturnsNil`) plus Task 7 (`openingMissingVerseTargetsNextPresentVerse`).
4. Combined verses (`ERV 1 Corinthians 5:12-13`): jumping to verse 13 and selecting inside the span both resolve to the span that starts at 12, so milestone 3 highlights attach to the right verse. Pinned in Task 3 (`combinedVerseSpanCoversEndVerse`).
5. A chapter with no paragraph breaks at all (every ESV chapter, since holybooks ESV has no `breakAfter`): the layout still starts each poetry verse on its own line so Psalm 23 reads as verse lines, and prose chapters flow as one paragraph. Pinned in Task 3 (`poetryVerseStartsOnItsOwnLine`).

---

### Task 1: ScriptureUI target, `ChapterLocation`, and the reading-position store

**Files:**
- Modify: `Packages/ScriptureKit/Package.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureData/Models.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureData/BibleStore.swift:52-63`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReadingPosition.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReadingPositionStore.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/ReadingPositionStoreTests.swift`

**Interfaces:**
- Produces:
  - `Package.swift`: library product and target `ScriptureUI` (depends on `ScriptureData`); test target `ScriptureUITests` (depends on `ScriptureUI`, `BibleImporterCore`, resources `[.copy("Fixtures")]`; the Fixtures folder is created in Task 7, so until then declare the resource only once the folder exists: create an empty `Tests/ScriptureUITests/Fixtures/.gitkeep` now).
  - `public struct ChapterLocation: Hashable, Codable, Sendable { public let book: String; public let chapter: Int; public init(book:chapter:) }` in `ScriptureData/Models.swift`.
  - `BibleStore.chapter(_ location: ChapterLocation, translationID: String) throws -> [Verse]` overload that forwards to the tuple version.
  - `public struct ReadingPosition: Codable, Equatable, Sendable { public var book: String; public var chapter: Int; public var firstVisibleVerse: Int; public var translationID: String; public init(...); public var chapterLocation: ChapterLocation }`.
  - `public final class ReadingPositionStore: Sendable { public init(defaults: UserDefaults = .standard, key: String = "readingPosition"); public func load() -> ReadingPosition?; public func save(_ position: ReadingPosition); public func clear() }` — JSON-encoded under `key`; `load()` returns nil for missing or undecodable data.

- [ ] **Step 1: Add the targets to `Package.swift`**

Add `.library(name: "ScriptureUI", targets: ["ScriptureUI"])`, `.target(name: "ScriptureUI", dependencies: ["ScriptureData"])`, and `.testTarget(name: "ScriptureUITests", dependencies: ["ScriptureUI", "BibleImporterCore"], resources: [.copy("Fixtures")])`. Create `Tests/ScriptureUITests/Fixtures/.gitkeep`.

- [ ] **Step 2: Write the failing test**

```swift
import Foundation
import Testing
@testable import ScriptureUI

@Suite struct ReadingPositionStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "ReadingPositionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func roundTrips() {
        let store = ReadingPositionStore(defaults: makeDefaults())
        #expect(store.load() == nil)
        let position = ReadingPosition(book: "MAT", chapter: 5, firstVisibleVerse: 17, translationID: "ESV")
        store.save(position)
        #expect(store.load() == position)
        #expect(store.load()?.chapterLocation == ChapterLocation(book: "MAT", chapter: 5))
    }

    @Test func undecodableDataLoadsAsNil() {
        let defaults = makeDefaults()
        defaults.set(Data("junk".utf8), forKey: "readingPosition")
        #expect(ReadingPositionStore(defaults: defaults).load() == nil)
    }

    @Test func clearRemovesPosition() {
        let store = ReadingPositionStore(defaults: makeDefaults())
        store.save(ReadingPosition(book: "GEN", chapter: 1, firstVisibleVerse: 1, translationID: "KJV"))
        store.clear()
        #expect(store.load() == nil)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter ReadingPositionStoreTests`
Expected: compile error, `ReadingPositionStore` not found.

- [ ] **Step 4: Implement `ChapterLocation`, the `chapter(_:translationID:)` overload, `ReadingPosition`, `ReadingPositionStore`**

`ReadingPositionStore` wraps `UserDefaults` with `JSONEncoder`/`JSONDecoder`; it is `Sendable` because `UserDefaults` is thread-safe (mark the property `nonisolated(unsafe)` only if the compiler demands it; prefer `let defaults: UserDefaults` which is already `Sendable`).

- [ ] **Step 5: Run the whole package test suite**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: 32 tests pass (29 existing + 3 new).

- [ ] **Step 6: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: ScriptureUI target with reading position store"
```

---

### Task 2: Navigation history

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NavigationHistory.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/NavigationHistoryTests.swift`

**Interfaces:**
- Produces: `public struct NavigationHistory: Equatable, Sendable { public private(set) var current: ChapterLocation?; public var canGoBack: Bool; public var canGoForward: Bool; public init(); public mutating func go(to location: ChapterLocation); @discardableResult public mutating func goBack() -> ChapterLocation?; @discardableResult public mutating func goForward() -> ChapterLocation? }`. `go(to:)` pushes the previous `current` onto the back stack, clears the forward stack, and is a no-op when `location == current`. Back stack is capped at 50 entries.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import ScriptureData
@testable import ScriptureUI

@Suite struct NavigationHistoryTests {
    let mat5 = ChapterLocation(book: "MAT", chapter: 5)
    let rom8 = ChapterLocation(book: "ROM", chapter: 8)
    let psa23 = ChapterLocation(book: "PSA", chapter: 23)

    @Test func startsEmpty() {
        let history = NavigationHistory()
        #expect(history.current == nil)
        #expect(!history.canGoBack && !history.canGoForward)
    }

    @Test func goBackAndForward() {
        var history = NavigationHistory()
        history.go(to: mat5)
        history.go(to: rom8)
        #expect(history.canGoBack && !history.canGoForward)
        #expect(history.goBack() == mat5)
        #expect(history.current == mat5)
        #expect(history.canGoForward)
        #expect(history.goForward() == rom8)
        #expect(history.goForward() == nil)
    }

    @Test func newNavigationClearsForward() {
        var history = NavigationHistory()
        history.go(to: mat5)
        history.go(to: rom8)
        history.goBack()
        history.go(to: psa23)
        #expect(!history.canGoForward)
        #expect(history.goBack() == mat5)
    }

    @Test func sameLocationIsNotPushed() {
        var history = NavigationHistory()
        history.go(to: mat5)
        history.go(to: mat5)
        #expect(!history.canGoBack)
    }

    @Test func backStackIsCapped() {
        var history = NavigationHistory()
        for chapter in 1...60 { history.go(to: ChapterLocation(book: "PSA", chapter: chapter)) }
        var steps = 0
        while history.goBack() != nil { steps += 1 }
        #expect(steps == 50)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter NavigationHistoryTests`
Expected: compile error, `NavigationHistory` not found.

- [ ] **Step 3: Implement `NavigationHistory`**

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter NavigationHistoryTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: navigation history with back and forward stacks"
```

---

### Task 3: Chapter layout (attributed text plus verse character ranges)

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderTypography.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterLayout.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/ChapterLayoutTests.swift`

**Interfaces:**
- Produces:
  - `#if canImport(AppKit) public typealias PlatformFont = NSFont; public typealias PlatformColor = NSColor #else UIFont / UIColor #endif` in `ReaderTypography.swift`.
  - `public struct ReaderTypography: Sendable { public var bodyFont: PlatformFont; public var verseNumberFont: PlatformFont; public var verseNumberColor: PlatformColor; public var textColor: PlatformColor; public var lineHeightMultiple: CGFloat; public var paragraphSpacing: CGFloat; public var verseNumberBaselineOffset: CGFloat; public static let `default`: ReaderTypography }`. Default: body is the system serif design (`PlatformFont(descriptor: .preferredFontDescriptor(forTextStyle: .body).withDesign(.serif)!, size: 18)`, falling back to `systemFont(ofSize: 18)`), verse number `systemFont(ofSize: 10.5, weight: .medium)` in `secondaryLabelColor`, `textColor = .labelColor`, `lineHeightMultiple = 1.3`, `paragraphSpacing = 14`, `verseNumberBaselineOffset = 7`.
  - `public struct VerseSpan: Equatable, Sendable { public let location: VerseLocation; public let endVerse: Int?; public let label: String; public let numberRange: NSRange; public let textRange: NSRange; public func contains(verse: Int) -> Bool }` — `contains(verse:)` is true for `location.verse...(endVerse ?? location.verse)`.
  - `public struct ChapterLayout: Sendable { public let attributedString: NSAttributedString; public let spans: [VerseSpan]; public static func build(verses: [Verse], typography: ReaderTypography = .default) -> ChapterLayout; public func span(containing characterIndex: Int) -> VerseSpan?; public func span(forVerse verse: Int) -> VerseSpan?; public func offsetWithinVerse(of characterIndex: Int) -> (span: VerseSpan, offset: Int)? }`.
  - `public static let ChapterLayout.lineSeparator = "\u{2028}"`.

Layout rules (`build`):
1. Each verse contributes `label` (`"3"` or `"12-13"`) in verse-number attributes (font, color, baseline offset), then one regular space, then the verse text in body attributes. `numberRange` covers the label only; `textRange` covers exactly the text (so UTF-16 offsets inside `textRange` map 1:1 onto `Verse.text` offsets).
2. Within the text, every `"\n"` becomes `ChapterLayout.lineSeparator` (same UTF-16 length, so offsets are unchanged).
3. Separator before a verse: nothing for the first verse; `"\n"` if the previous verse had `breakAfter`; otherwise `lineSeparator` if this verse or the previous verse contains a line separator (poetry gets its own line); otherwise a single space.
4. The whole string carries one `NSParagraphStyle` with `lineHeightMultiple` and `paragraphSpacing` from typography; `textColor` applies to verse text.
5. `span(containing:)` returns the span whose `numberRange ∪ textRange` (plus the one separator character after the number) contains the index; `offsetWithinVerse` returns `characterIndex - textRange.location` only when the index lies inside `textRange`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
import ScriptureData
@testable import ScriptureUI

@Suite struct ChapterLayoutTests {
    private func verse(_ n: Int, _ text: String, end: Int? = nil, breakAfter: Bool = false) -> Verse {
        Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "WEB", endVerse: end, text: text, breakAfter: breakAfter)
    }

    @Test func proseVersesFlowWithSpacesAndNumbersAreSuperscript() {
        let layout = ChapterLayout.build(verses: [verse(1, "Alpha beta."), verse(2, "Gamma.")])
        #expect(layout.attributedString.string == "1 Alpha beta. 2 Gamma.")
        #expect(layout.spans.count == 2)
        #expect(layout.spans[0].numberRange == NSRange(location: 0, length: 1))
        #expect(layout.spans[0].textRange == NSRange(location: 2, length: 11))
        #expect(layout.spans[1].textRange == NSRange(location: 16, length: 6))
        let numberAttributes = layout.attributedString.attributes(at: 0, effectiveRange: nil)
        #expect((numberAttributes[.baselineOffset] as? CGFloat) == ReaderTypography.default.verseNumberBaselineOffset)
        #expect((numberAttributes[.font] as? PlatformFont)?.pointSize == ReaderTypography.default.verseNumberFont.pointSize)
    }

    @Test func breakAfterInsertsParagraphBreak() {
        let layout = ChapterLayout.build(verses: [verse(1, "One.", breakAfter: true), verse(2, "Two.")])
        #expect(layout.attributedString.string == "1 One.\n2 Two.")
    }

    @Test func poetryVerseStartsOnItsOwnLine() {
        let layout = ChapterLayout.build(verses: [
            verse(1, "Prose."),
            verse(2, "Line one,\nline two."),
            verse(3, "Line three,\nline four."),
            verse(4, "Prose again."),
        ])
        let sep = ChapterLayout.lineSeparator
        #expect(layout.attributedString.string == "1 Prose.\(sep)2 Line one,\(sep)line two.\(sep)3 Line three,\(sep)line four.\(sep)4 Prose again.")
        #expect(layout.spans[1].textRange.length == "Line one,\nline two.".utf16.count)
    }

    @Test func combinedVerseSpanCoversEndVerse() {
        let layout = ChapterLayout.build(verses: [verse(11, "Eleven."), verse(12, "Twelve thirteen.", end: 13), verse(14, "Fourteen.")])
        #expect(layout.spans[1].label == "12-13")
        #expect(layout.span(forVerse: 13) == layout.spans[1])
        #expect(layout.span(forVerse: 12) == layout.spans[1])
        #expect(layout.span(forVerse: 14)?.location.verse == 14)
    }

    @Test func spanForMissingVerseReturnsNil() {
        let layout = ChapterLayout.build(verses: [verse(20, "Twenty."), verse(22, "Twenty-two.")])
        #expect(layout.span(forVerse: 21) == nil)
        #expect(layout.span(forVerse: 22)?.location.verse == 22)
    }

    @Test func characterIndexMapsToVerseAndOffset() {
        let layout = ChapterLayout.build(verses: [verse(1, "Alpha beta."), verse(2, "Gamma.")])
        // "1 Alpha beta. 2 Gamma." — index 8 is the 'b' of "beta", offset 6 within verse 1.
        let hit = layout.offsetWithinVerse(of: 8)
        #expect(hit?.span.location.verse == 1)
        #expect(hit?.offset == 6)
        #expect(layout.span(containing: 14)?.location.verse == 2)   // the "2" label
        #expect(layout.offsetWithinVerse(of: 14) == nil)             // not inside verse text
        #expect(layout.span(containing: 99) == nil)
    }

    @Test func emptyChapterProducesEmptyLayout() {
        let layout = ChapterLayout.build(verses: [])
        #expect(layout.attributedString.length == 0)
        #expect(layout.spans.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter ChapterLayoutTests`
Expected: compile error, `ChapterLayout` not found.

- [ ] **Step 3: Implement `ReaderTypography.swift` and `ChapterLayout.swift`**

`build` appends to an `NSMutableAttributedString` while recording ranges with `string.length` before and after each append. `NSAttributedString` is not `Sendable`; mark `ChapterLayout` as `@unchecked Sendable` with a comment that the string is immutable after construction.

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter ChapterLayoutTests`
Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: chapter layout with per-verse character ranges"
```

---

### Task 4: ReaderView with a TextKit 2 text view

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ScrollTarget.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterTextView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderView.swift`

**Interfaces:**
- Consumes: `ChapterLayout`, `ReaderTypography`, `VerseSpan` from Task 3.
- Produces:
  - `public struct ScrollTarget: Equatable, Sendable { public let verse: Int; public let token: UUID; public init(verse: Int) }` — a fresh `token` per request so jumping to the same verse twice still scrolls.
  - `public struct ReaderView: View { public init(title: String, verses: [Verse], scrollTarget: ScrollTarget?, onFirstVisibleVerseChange: @escaping (Int) -> Void, onHeadingTap: @escaping () -> Void, nextChapterTitle: String?, onNextChapter: @escaping () -> Void) }`. Layout: a `VStack` of the chapter heading as a `Button(title)` (plain style, serif 28pt semibold, `.buttonStyle(.plain)`, help text "Chapter actions arrive in a later milestone") and the text view filling the rest; a bottom bar under the text (inside the scroll content is not possible with `NSTextView`, so place it as a footer `HStack` with a `Button("Next: \(nextChapterTitle)")` using symbol `arrow.right`) shown only when `nextChapterTitle != nil`.
  - `struct ChapterTextView: NSViewRepresentable` (macOS only, `#if os(macOS)`): `init(layout: ChapterLayout, scrollTarget: ScrollTarget?, onFirstVisibleVerseChange: @escaping (Int) -> Void)`. `makeNSView` builds `NSTextContentStorage → NSTextLayoutManager → NSTextContainer → NSTextView(frame:textContainer:)` wrapped in an `NSScrollView`; the view is non-editable, selectable, `textContainerInset = NSSize(width: 48, height: 32)`, `textContainer.widthTracksTextView = true`, `maxSize` unbounded vertically, `drawsBackground = false`, line fragment padding 0, max width 640 via `textContainer.lineFragmentPadding` plus `textContainerInset` adjusted in `layout` (centred column: set `textContainer.size.width = min(640, bounds.width - 96)` and horizontal inset `(bounds.width - containerWidth) / 2`). `updateNSView` replaces `textStorage` content only when `layout.attributedString !== previous` (keep the previous layout in the coordinator), then handles a changed `scrollTarget.token` by calling `textLayoutManager.ensureLayout(for: documentRange)`, finding `textLayoutManager.textLayoutFragment(for: location)` of the span's `numberRange.location`, and scrolling the clip view so the fragment's `layoutFragmentFrame.minY - 16` is at the top. The coordinator observes `NSView.boundsDidChangeNotification` on the clip view (`postsBoundsChangedNotifications = true`) and, on each change, finds the first layout fragment intersecting the visible rect (`textLayoutManager.enumerateTextLayoutFragments(from: nil, options: [.ensuresLayout])` stopping at the first fragment whose `layoutFragmentFrame.maxY > visibleRect.minY`), converts its `rangeInElement.location` to a character index via `textContentStorage.offset(from: documentRange.location, to:)`, looks up `layout.span(containing:)` and reports `span.location.verse` when it differs from the last reported value. Never touch `textView.layoutManager` (that would switch the view to TextKit 1).

- [ ] **Step 1: Implement the three files**

No unit test: the rendering is verified in Task 9 against the running app. Keep `ReaderView` free of AppKit except behind `#if os(macOS)`; on other platforms `ReaderView` can show a `Text(layout.attributedString.string)` placeholder so the package still compiles for iOS later.

- [ ] **Step 2: Build the package**

Run: `DEVELOPER_DIR=$XC swift build --package-path Packages/ScriptureKit`
Expected: `Build complete!` with no warnings from `ScriptureUI`.

- [ ] **Step 3: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: ReaderView with TextKit 2 chapter text view"
```

---

### Task 5: Front page and chapter grid

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterGridView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/FrontPageView.swift`

**Interfaces:**
- Produces:
  - `public struct ChapterGridView: View { public init(bookName: String, chapterCount: Int, currentChapter: Int?, onSelect: @escaping (Int) -> Void) }` — `Text(bookName)` header (serif 28pt semibold), then `LazyVGrid(columns: Array(repeating: GridItem(.fixed(56), spacing: 8), count: 5), alignment: .leading)` of `Button("\(n)")` in `.buttonStyle(.plain)`, 56×44 cells, `font(.system(size: 17, design: .serif))`, `foregroundStyle(.secondary)`, the current chapter in `.primary` with a `Capsule().fill(.quaternary)` background. Grid is left-aligned under the header inside a `ScrollView`.
  - `public struct FrontPageView: View { public init(books: [TranslationBook], selectedBookID: Binding<String?>, currentLocation: ChapterLocation?, onSelectChapter: @escaping (ChapterLocation) -> Void) }` — `HStack(spacing: 0)`: left column (width 240) is a `List(selection: selectedBookID)` with `Section("Old Testament")`, `Section("New Testament")`, and `Section("Apocrypha")` only when a book with `canon == .apocrypha` is present; rows show `book.name` in `.system(size: 15, design: .serif)`. Right pane shows `ChapterGridView` for the selected book (`currentChapter` is `currentLocation?.chapter` when `currentLocation?.book == selectedBookID`), or `ContentUnavailableView("Choose a book", systemImage: "book")` when nothing is selected. When `selectedBookID` is nil on appear, the view sets it to `currentLocation?.book ?? books.first?.book.id`.

- [ ] **Step 1: Implement both files**

- [ ] **Step 2: Build the package**

Run: `DEVELOPER_DIR=$XC swift build --package-path Packages/ScriptureKit`
Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: front page with canon sections and five-across chapter grid"
```

---

### Task 6: Command palette model and view

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/PaletteItem.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/PaletteRanker.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/CommandPaletteView.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/PaletteRankerTests.swift`

**Interfaces:**
- Consumes: `ReferenceParser.parse`, `ReferenceParser.matchBooks(prefix:)`, `Reference`, `TranslationBook`, `Translation`, `Verse` from `ScriptureData`.
- Produces:
  - `public enum PaletteItem: Hashable, Identifiable, Sendable { case reference(Reference); case book(Book); case translation(Translation); case verse(Verse); public var id: String; public var title: String; public var subtitle: String?; public var symbolName: String }`. Titles: reference → `reference.displayString` (subtitle "Go to chapter" or "Go to verse"), book → `book.name` (subtitle `canon.displayName`), translation → `translation.title` (subtitle "Switch translation"), verse → `"\(book.name) \(chapter):\(verse)"` using `BookCatalog.book(code:)` (subtitle: verse text with `"\n"` replaced by space, truncated to 120 characters). Symbols: `arrow.right.circle`, `book`, `character.book.closed`, `text.quote`.
  - `public enum PaletteRanker { public static func rank(query: String, books: [TranslationBook], translations: [Translation], activeTranslationID: String, verses: [Verse], maxBooks: Int = 6, maxVerses: Int = 8) -> [PaletteItem] }`. Order: (1) the parsed reference when its book is in `books` and `chapter` is nil or `1...chapterCount` — a bare book reference (`chapter == nil`) becomes `.book` instead; (2) `matchBooks(prefix: query)` restricted to `books`, minus the item from (1), first `maxBooks`; (3) translations other than `activeTranslationID` whose `id` or `title` contains the trimmed query case-insensitively; (4) the first `maxVerses` verses. Whitespace-only query → `[]`.
  - `public struct CommandPaletteView: View { public init(query: Binding<String>, items: [PaletteItem], onSelect: @escaping (PaletteItem) -> Void, onDismiss: @escaping () -> Void) }` — a 560-wide panel: `TextField("Go to a reference, book, translation, or search text", text: query)` with `magnifyingglass`, `.textFieldStyle(.plain)`, focused on appear via `@FocusState`; below it a `ScrollViewReader` + `ForEach(items)` list of rows (symbol, title, subtitle) with a highlighted selection index; `.onKeyPress(.upArrow)` / `.onKeyPress(.downArrow)` move the selection (clamped), `.onKeyPress(.return)` calls `onSelect(items[selection])`, `.onExitCommand` calls `onDismiss`; clicking a row selects it. Selection resets to 0 whenever `items` change. Background `.regularMaterial`, corner radius 12, shadow.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import ScriptureData
@testable import ScriptureUI

@Suite struct PaletteRankerTests {
    let books: [TranslationBook] = [("PSA", 150), ("MAT", 28), ("JHN", 21), ("ROM", 16), ("JUD", 1), ("JDG", 21)]
        .map { TranslationBook(book: BookCatalog.book(code: $0.0)!, chapterCount: $0.1) }
    let translations = [Translation(id: "ESV", title: "English Standard Version"), Translation(id: "KJV", title: "King James Version")]

    private func rank(_ query: String, verses: [Verse] = []) -> [PaletteItem] {
        PaletteRanker.rank(query: query, books: books, translations: translations, activeTranslationID: "ESV", verses: verses)
    }

    @Test func chapterReferenceComesFirst() {
        let items = rank("Rom 8")
        guard case .reference(let reference)? = items.first else { Issue.record("expected reference"); return }
        #expect(reference.book.id == "ROM")
        #expect(reference.chapter == 8)
        #expect(items.first?.subtitle == "Go to chapter")
    }

    @Test func verseReferenceIsOffered() {
        let items = rank("John 3:16")
        guard case .reference(let reference)? = items.first else { Issue.record("expected reference"); return }
        #expect(reference.verse == 16)
        #expect(items.first?.subtitle == "Go to verse")
    }

    @Test func chapterBeyondBookIsNotOffered() {
        let items = rank("Rom 99")
        #expect(!items.contains { if case .reference = $0 { true } else { false } })
    }

    @Test func bareBookBecomesBookItem() {
        let items = rank("ps")
        #expect(items.first == .book(BookCatalog.book(code: "PSA")!))
        #expect(items.filter { if case .reference = $0 { true } else { false } }.isEmpty)
    }

    @Test func prefixMatchesStayInCanonOrderAndRespectAvailability() {
        let items = rank("jud")
        let bookIDs = items.compactMap { if case .book(let book) = $0 { book.id } else { nil } }
        #expect(bookIDs == ["JDG", "JUD"])    // Judith (JDT) is not in `books`
    }

    @Test func translationsMatchByIDOrTitle() {
        #expect(rank("kjv").contains(.translation(translations[1])))
        #expect(rank("king").contains(.translation(translations[1])))
        #expect(!rank("esv").contains(.translation(translations[0])))   // active translation is excluded
    }

    @Test func versesComeLastAndAreCapped() {
        let verses = (1...12).map {
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: $0), translationID: "ESV", text: "Blessed \($0)", breakAfter: false)
        }
        let items = rank("blessed", verses: verses)
        let verseItems = items.filter { if case .verse = $0 { true } else { false } }
        #expect(verseItems.count == 8)
        #expect(items.last == verseItems.last)
        #expect(verseItems.first?.title == "Matthew 5:1")
    }

    @Test func blankQueryIsEmpty() {
        #expect(rank("   ").isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter PaletteRankerTests`
Expected: compile error, `PaletteRanker` not found.

- [ ] **Step 3: Implement `PaletteItem.swift`, `PaletteRanker.swift`, then `CommandPaletteView.swift`**

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter PaletteRankerTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: command palette ranking and overlay view"
```

---

### Task 7: NavigationModel tying store, position, history and screens together

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NavigationModel.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/EN/NT/MAT/WEB.json` (hand-written: chapters 1–3, verses 1–3 each; chapter 2 verse 2 has poetry `"Line a\nLine b"`, chapter 1 verse 2 has `breakAfter`, chapter 3 omits verse 2)
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/EN/NT/MAT/KJV.json` (same shape, plain text)
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/EN/OT/PSA/WEB.json` (chapters 1–2, two verses each)
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/EN/OT/PSA/KJV.json`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/EN/AP/TOB/WEB.json` (chapter 1, two verses; WEB only)
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/FixtureStore.swift`
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/NavigationModelTests.swift`
- Delete: `Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/.gitkeep`

Fixture JSON shape (from `HolyBookFile`): `{"version": "WEB", "ID": "NT:MAT(WEB)", "name": "Matthew", "text": [{"ID": "NT:MAT.1", "name": "Matthew 1", "text": [{"ID": "1", "text": "..."}, ...]}]}`; an entry with `"text": ""` marks a paragraph break after that verse; consecutive entries with the same `ID` are poetry lines.

**Interfaces:**
- Consumes: `BibleStore`, `ReadingPositionStore`, `NavigationHistory`, `PaletteRanker`, `PaletteItem`, `ScrollTarget`, `ChapterLayout.span(forVerse:)`.
- Produces:
  - `public enum Screen: Equatable, Sendable { case frontPage, reader }`
  - `@MainActor @Observable public final class NavigationModel { public init(store: BibleStore, positionStore: ReadingPositionStore, defaultTranslationID: String = "ESV") throws` (loads translations, books for the active translation, and restores the stored position; throws only when `store.translations()` throws).
    - State: `public private(set) var screen: Screen`, `public private(set) var translationID: String`, `public private(set) var translations: [Translation]`, `public private(set) var books: [TranslationBook]`, `public private(set) var location: ChapterLocation?`, `public private(set) var verses: [Verse]`, `public private(set) var scrollTarget: ScrollTarget?`, `public var selectedBookID: String?` (front page selection), `public var paletteQuery: String`, `public private(set) var paletteItems: [PaletteItem]`, `public var isPaletteShown: Bool`, `public var canGoBack: Bool`, `public var canGoForward: Bool`, `public var chapterTitle: String?` (`"Matthew 5"`), `public var nextChapter: ChapterLocation?`, `public var previousChapter: ChapterLocation?`, `public func title(for location: ChapterLocation) -> String`.
    - Actions: `open(_ location: ChapterLocation, verse: Int? = nil)`, `open(_ reference: Reference)` (no chapter → chapter 1), `goHome()`, `goBack()`, `goForward()`, `goToNextChapter()`, `goToPreviousChapter()`, `setTranslation(_ id: String)`, `reportFirstVisibleVerse(_ verse: Int)`, `updatePalette()` (runs `store.search(paletteQuery, translationID:, limit: 8)` and `PaletteRanker.rank`, catching and ignoring search errors), `select(_ item: PaletteItem)` (reference → `open`, book → `open(ChapterLocation(book:, chapter: 1))`, translation → `setTranslation`, verse → `open(location, verse:)`; then hides the palette and clears the query).
    - Rules: `open` loads verses with `store.chapter`, pushes history, sets `screen = .reader`, sets `scrollTarget` to `ScrollTarget(verse:)` for the requested verse or 1 (when the requested verse is absent, use the first present verse with a number ≥ the request, else the last verse), and saves `ReadingPosition(book, chapter, firstVisibleVerse: that verse, translationID)`. `goHome` sets `screen = .frontPage` and `selectedBookID = location?.book` without touching the stored position. `setTranslation` reloads `books`; if `location` is present in the new translation it reloads `verses` and keeps `scrollTarget` at the stored `firstVisibleVerse`; otherwise it sets `location = nil`, `verses = []`, `screen = .frontPage`; either way it saves the position with the new translation (only when a location exists). `reportFirstVisibleVerse` saves the position when the verse changes. `nextChapter`/`previousChapter` cross book boundaries in `books` order (nil at the ends). Restore at init: if the stored position resolves (translation exists, book present, chapter within count) the model opens it (screen `.reader`, scroll target at `firstVisibleVerse`) without pushing a back entry; otherwise it starts on the front page with the default translation.

- [ ] **Step 1: Write the fixtures and `FixtureStore`**

```swift
import BibleImporterCore
import Foundation
import ScriptureData

enum FixtureStore {
    private static let url: Result<URL, Error> = Result {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("ScriptureUITests-\(UUID().uuidString).sqlite")
        _ = try BibleDatabaseWriter(outputURL: out).importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "fixture")
        return out
    }
    static func make() throws -> BibleStore { try BibleStore(databaseURL: try url.get()) }
}
```

- [ ] **Step 2: Write the failing test**

```swift
import Foundation
import Testing
import ScriptureData
@testable import ScriptureUI

@MainActor @Suite struct NavigationModelTests {
    private func makeDefaults() -> UserDefaults {
        let name = "NavigationModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeModel(defaults: UserDefaults? = nil) throws -> (NavigationModel, ReadingPositionStore) {
        let positionStore = ReadingPositionStore(defaults: defaults ?? makeDefaults())
        let model = try NavigationModel(store: try FixtureStore.make(), positionStore: positionStore, defaultTranslationID: "WEB")
        return (model, positionStore)
    }

    @Test func firstLaunchShowsFrontPage() throws {
        let (model, _) = try makeModel()
        #expect(model.screen == .frontPage)
        #expect(model.translationID == "WEB")
        #expect(model.books.map(\.book.id) == ["PSA", "MAT", "TOB"])
        #expect(model.location == nil)
    }

    @Test func openingAChapterLoadsVersesAndSavesPosition() throws {
        let (model, positionStore) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 2))
        #expect(model.screen == .reader)
        #expect(model.verses.count == 3)
        #expect(model.chapterTitle == "Matthew 2")
        #expect(model.scrollTarget?.verse == 1)
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 2, firstVisibleVerse: 1, translationID: "WEB"))
    }

    @Test func openingAReferenceWithVerseTargetsThatVerse() throws {
        let (model, positionStore) = try makeModel()
        model.open(ReferenceParser.parse("Matt 1:3")!)
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
        #expect(model.scrollTarget?.verse == 3)
        #expect(positionStore.load()?.firstVisibleVerse == 3)
    }

    @Test func openingMissingVerseTargetsNextPresentVerse() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 3), verse: 2)   // chapter 3 omits verse 2
        #expect(model.scrollTarget?.verse == 3)
    }

    @Test func homeKeepsPositionAndSelectsCurrentBook() throws {
        let (model, positionStore) = try makeModel()
        model.open(ChapterLocation(book: "PSA", chapter: 2))
        model.goHome()
        #expect(model.screen == .frontPage)
        #expect(model.selectedBookID == "PSA")
        #expect(positionStore.load()?.chapter == 2)
    }

    @Test func backAndForwardMoveBetweenChapters() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 1))
        model.open(ChapterLocation(book: "PSA", chapter: 1))
        #expect(model.canGoBack)
        model.goBack()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
        #expect(model.verses.first?.id.book == "MAT")
        model.goForward()
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 1))
    }

    @Test func nextAndPreviousChapterCrossBooks() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "PSA", chapter: 2))
        #expect(model.nextChapter == ChapterLocation(book: "MAT", chapter: 1))
        model.goToNextChapter()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
        #expect(model.previousChapter == ChapterLocation(book: "PSA", chapter: 2))
        model.open(ChapterLocation(book: "TOB", chapter: 1))
        #expect(model.nextChapter == nil)
    }

    @Test func switchingTranslationKeepsPlace() throws {
        let (model, positionStore) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 2), verse: 3)
        model.reportFirstVisibleVerse(2)
        model.setTranslation("KJV")
        #expect(model.translationID == "KJV")
        #expect(model.screen == .reader)
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(model.verses.first?.translationID == "KJV")
        #expect(model.scrollTarget?.verse == 2)
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 2, firstVisibleVerse: 2, translationID: "KJV"))
    }

    @Test func switchingToTranslationWithoutBookGoesHome() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "TOB", chapter: 1))
        model.setTranslation("KJV")
        #expect(model.screen == .frontPage)
        #expect(model.location == nil)
        #expect(model.books.map(\.book.id) == ["PSA", "MAT"])
    }

    @Test func reportedVerseIsPersisted() throws {
        let (model, positionStore) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 1))
        model.reportFirstVisibleVerse(3)
        #expect(positionStore.load()?.firstVisibleVerse == 3)
    }

    @Test func relaunchRestoresStoredPosition() throws {
        let defaults = makeDefaults()
        ReadingPositionStore(defaults: defaults).save(ReadingPosition(book: "MAT", chapter: 2, firstVisibleVerse: 3, translationID: "KJV"))
        let (model, _) = try makeModel(defaults: defaults)
        #expect(model.screen == .reader)
        #expect(model.translationID == "KJV")
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(model.scrollTarget?.verse == 3)
        #expect(!model.canGoBack)
    }

    @Test func invalidStoredPositionFallsBackToFrontPage() throws {
        for bad in [
            ReadingPosition(book: "MAT", chapter: 2, firstVisibleVerse: 1, translationID: "NIV"),
            ReadingPosition(book: "TOB", chapter: 1, firstVisibleVerse: 1, translationID: "KJV"),
            ReadingPosition(book: "MAT", chapter: 99, firstVisibleVerse: 1, translationID: "WEB"),
        ] {
            let defaults = makeDefaults()
            ReadingPositionStore(defaults: defaults).save(bad)
            let (model, _) = try makeModel(defaults: defaults)
            #expect(model.screen == .frontPage)
            #expect(model.translationID == "WEB")
        }
    }

    @Test func paletteSearchRanksReferenceAndSelectingOpensIt() throws {
        let (model, _) = try makeModel()
        model.isPaletteShown = true
        model.paletteQuery = "Matt 2:2"
        model.updatePalette()
        guard case .reference? = model.paletteItems.first else { Issue.record("expected reference"); return }
        model.select(model.paletteItems[0])
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(model.scrollTarget?.verse == 2)
        #expect(!model.isPaletteShown)
        #expect(model.paletteQuery.isEmpty)
    }

    @Test func paletteTextSearchFindsVerses() throws {
        let (model, _) = try makeModel()
        model.paletteQuery = "Line b"
        model.updatePalette()
        #expect(model.paletteItems.contains { if case .verse(let v) = $0 { v.id == VerseLocation(book: "MAT", chapter: 2, verse: 2) } else { false } })
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit --filter NavigationModelTests`
Expected: compile error, `NavigationModel` not found.

- [ ] **Step 4: Implement `NavigationModel.swift`**

Keep `BibleStore` errors inside the model: a failed `chapter()` call leaves `verses = []` and logs with `os.Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "navigation")`.

- [ ] **Step 5: Run the whole suite**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: all tests pass (29 + 3 + 5 + 7 + 8 + 14 = 66).

- [ ] **Step 6: Commit**

```bash
git add Packages/ScriptureKit
git commit -m "feat: NavigationModel with position restore, history, translation switching and palette"
```

---

### Task 8: Xcode workspace, macOS app target, bundled database, preview removal

**Files:**
- Create: `ReadingThroughScripture.xcworkspace/contents.xcworkspacedata`
- Create: `Apps/Mac/ReadingThroughScripture.xcodeproj/project.pbxproj`
- Create: `Apps/Mac/ReadingThroughScripture.xcodeproj/xcshareddata/xcschemes/ReadingThroughScripture.xcscheme`
- Create: `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`
- Create: `Apps/Mac/ReadingThroughScripture/MainWindowView.swift`
- Create: `Apps/Mac/ReadingThroughScripture/Assets.xcassets/Contents.json` plus `AppIcon.appiconset/Contents.json` (empty icon set, so Xcode does not warn)
- Modify: `Packages/ScriptureKit/Package.swift` (remove `ScriptureMacPreview` product and target)
- Delete: `Packages/ScriptureKit/Sources/ScriptureMacPreview/` (three files)
- Modify: `README.md` (Layout and Running sections; also fix the "Current plan" link to this plan)
- Modify: `.gitignore` (add `*.xcworkspace/xcuserdata/`, `DerivedData/`)

**Interfaces:**
- Consumes: `NavigationModel`, `ReaderView`, `FrontPageView`, `CommandPaletteView`, `ScrollTarget`, `PaletteItem` from `ScriptureUI`; `BibleStore` from `ScriptureData`.
- Produces: a buildable scheme `ReadingThroughScripture`.

Project file (`objectVersion = 77`, written by hand, no generator): one `PBXNativeTarget` `ReadingThroughScripture` of type `com.apple.product-type.application`; a `PBXFileSystemSynchronizedRootGroup` for the `ReadingThroughScripture` source folder; an `XCLocalSwiftPackageReference` with `relativePath = ../../Packages/ScriptureKit` listed in the project's `packageReferences`, with `XCSwiftPackageProductDependency` entries for `ScriptureUI` and `ScriptureData` in the target's `packageProductDependencies` and `PBXBuildFile` entries in the Frameworks phase; build phases in order Sources, Frameworks, Resources, then a `PBXShellScriptBuildPhase` named "Bundle Bible database" with `alwaysOutOfDate = 1`, no input paths, `outputPaths = ("$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/bible.sqlite")`, and this script:

```bash
set -euo pipefail
ROOT="${SRCROOT}/../.."
DB="${ROOT}/Build/bible.sqlite"
if [ ! -f "${DB}" ]; then
  env -i HOME="${HOME}" PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin" \
    DEVELOPER_DIR="${DEVELOPER_DIR}" bash "${ROOT}/Scripts/build-bible.sh"
fi
DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "${DEST}"
if [ ! -f "${DEST}/bible.sqlite" ] || [ "${DB}" -nt "${DEST}/bible.sqlite" ]; then
  cp "${DB}" "${DEST}/bible.sqlite"
fi
```

Build settings (both configurations): `PRODUCT_NAME = ReadingThroughScripture`, `PRODUCT_BUNDLE_IDENTIFIER = com.matthewfurr.ReadingThroughScripture`, `MACOSX_DEPLOYMENT_TARGET = 26.0`, `SDKROOT = macosx`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_KEY_NSHumanReadableCopyright = ""`, `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.reference`, `ENABLE_USER_SCRIPT_SANDBOXING = NO`, `CODE_SIGN_STYLE = Automatic`, `CODE_SIGN_IDENTITY = "-"`, `DEVELOPMENT_TEAM = ""`, `ENABLE_HARDENED_RUNTIME = NO`, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, `COMBINE_HIDPI_IMAGES = YES`, `CURRENT_PROJECT_VERSION = 1`, `MARKETING_VERSION = 0.2`, `SWIFT_EMIT_LOC_STRINGS = YES`, plus the standard Debug (`ONLY_ACTIVE_ARCH = YES`, `SWIFT_OPTIMIZATION_LEVEL = "-Onone"`, `DEBUG_INFORMATION_FORMAT = dwarf`) and Release (`SWIFT_OPTIMIZATION_LEVEL = "-O"`, `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"`) defaults. Workspace contents: `group:Apps/Mac/ReadingThroughScripture.xcodeproj` and `group:Packages/ScriptureKit`.

`ReadingThroughScriptureApp.swift`: `@main struct ReadingThroughScriptureApp: App` with `@State private var model: NavigationModel?` and `@State private var loadError: String?`; `init` resolves `Bundle.main.url(forResource: "bible", withExtension: "sqlite")`, builds `BibleStore` and `NavigationModel(store:positionStore: ReadingPositionStore())`, capturing any error text. `WindowGroup("Reading Through Scripture")` shows `MainWindowView(model:)` or `ContentUnavailableView("Bible database missing", systemImage: "exclamationmark.triangle", description: Text(error))`; `.defaultSize(width: 1100, height: 760)`. `.commands`: `CommandMenu("Go")` with Home (`⌘⇧H`), Back (`⌘[`), Forward (`⌘]`), Previous Chapter (`⌥⌘←`), Next Chapter (`⌥⌘→`), a divider, Go to Reference… (`⌘K`, toggles `isPaletteShown`); each disabled when the model cannot do it. Also `CommandGroup(replacing: .newItem) {}` so ⌘N does nothing.

`MainWindowView.swift`: `@Bindable var model`; body switches on `model.screen`: `.frontPage` → `FrontPageView(books: model.books, selectedBookID: $model.selectedBookID, currentLocation: model.location, onSelectChapter: { model.open($0) })`; `.reader` → `ReaderView(title: model.chapterTitle ?? "", verses: model.verses, scrollTarget: model.scrollTarget, onFirstVisibleVerseChange: model.reportFirstVisibleVerse, onHeadingTap: {}, nextChapterTitle: model.nextChapter.map(model.title(for:)), onNextChapter: model.goToNextChapter)`. Toolbar (`.toolbar`): navigation group with Home, Back, Forward buttons; principal item `Text(model.chapterTitle ?? "Reading Through Scripture").font(.headline)`; trailing group with the translation `Menu` (label: `Label(model.translationID, systemImage: "chevron.up.chevron.down")` styled as a capsule via `.menuStyle(.button)` + `.buttonStyle(.bordered)` + `.buttonBorderShape(.capsule)`; items are `model.translations` as `Button(translation.title) { model.setTranslation(translation.id) }` with a checkmark on the active one) and the palette button. `.overlay(alignment: .top)` presents `CommandPaletteView(query: $model.paletteQuery, items: model.paletteItems, onSelect: model.select, onDismiss: { model.isPaletteShown = false })` padded 80pt from the top over a dimmed, click-to-dismiss backdrop when `model.isPaletteShown`; `.onChange(of: model.paletteQuery) { model.updatePalette() }`.

- [ ] **Step 1: Write the workspace, project, scheme, asset catalog, and the two app source files**

- [ ] **Step 2: Remove `ScriptureMacPreview`**

Delete the folder and the two `Package.swift` lines; update README's Layout bullet to name `ScriptureUI` and the `Apps/Mac` target, replace the "Current plan" link, and add a "Running the app" section with the `xcodebuild` command from Step 3 and "or open `ReadingThroughScripture.xcworkspace` in Xcode and run the `ReadingThroughScripture` scheme".

- [ ] **Step 3: Build from the command line**

Run:
```bash
DEVELOPER_DIR=$XC xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **` and `Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app/Contents/Resources/bible.sqlite` exists.

- [ ] **Step 4: Verify the missing-database path**

Run: `mv Build/bible.sqlite Build/bible.sqlite.bak` then the Step 3 build again, then `ls -la Build/bible.sqlite` and `rm Build/bible.sqlite.bak`.
Expected: the build regenerates `Build/bible.sqlite` through `Scripts/build-bible.sh` and succeeds. If `swift run` fails inside the Xcode environment, fix the `env -i` line in the script phase rather than the shell script in `Scripts/`.

- [ ] **Step 5: Package tests still pass without the preview target**

Run: `DEVELOPER_DIR=$XC swift test --package-path Packages/ScriptureKit`
Expected: 66 tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A Apps ReadingThroughScripture.xcworkspace Packages/ScriptureKit README.md .gitignore
git commit -m "feat: macOS app target with bundled Bible database; remove ScriptureMacPreview"
```

---

### Task 9: End-to-end verification of the running app

**Files:** none new; fixes land in the files above.

- [ ] **Step 1: Clean stored position and launch**

Run:
```bash
defaults delete com.matthewfurr.ReadingThroughScripture 2>/dev/null; open Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app && sleep 3 && pgrep -x ReadingThroughScripture
```
Expected: a process id; the window shows the front page with Old Testament and New Testament sections and the Genesis chapter grid (five across).

- [ ] **Step 2: Check the reader and poetry visually**

In the app: click Psalms → 23. Expected: heading "Psalms 23" as a button, superscript numbers, verses 2, 3, 5 and 6 on their own lines with their inner line breaks. Then ⌘K, type `Matt 5`, Return: Matthew 5 renders as flowing prose with superscript numbers. Switch the pill to ERV and open `1 Cor 5`: verse "12-13" is labelled as one span. Record what was checked in the final report; take a screenshot with `screencapture -x /tmp/reader.png` if screen-recording permission allows it, otherwise rely on the person's own look.

- [ ] **Step 3: Check ⌘K verse jump and persistence**

In the app: ⌘K, type `John 3:16`, Return. Expected: John 3 opens scrolled so verse 16 is at the top. Quit with ⌘Q, then:
```bash
defaults read com.matthewfurr.ReadingThroughScripture readingPosition | plutil -convert json -o - - 2>/dev/null || defaults read com.matthewfurr.ReadingThroughScripture
```
Expected: the stored JSON holds `"book":"JHN"`, `"chapter":3`, `"firstVisibleVerse":16`. Relaunch with `open …app`: the reader reopens at John 3:16, back is disabled, Home shows the front page with John selected and chapter 3 marked.

- [ ] **Step 4: Fix anything found, re-run the package tests, commit**

```bash
git add -A
git commit -m "fix: reader adjustments from end-to-end check"
```
(Skip the commit if nothing changed.)
