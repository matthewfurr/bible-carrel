# Milestone 8: the iPhone App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Matt's iPhone 17 Pro Max runs the same app as his Mac (reader, highlights, notes, bookmarks, assistant, sync) behind the system Liquid Glass tab bar, with a pen for marking, and with search, a time filter, tappable references and an offline Ask that let him find and use what he wrote during group discussion.

**Architecture:** Everything that can be decided without a screen stays platform-neutral in `ScriptureUI` and is tested with `swift test` on the Mac: the grouped search model, the time filter, reference linking, the offline fallback, the lookup rule, the pen's state, and the text logic lifted out of the Mac's AppKit reader. The phone's views live in `Packages/ScriptureKit/Sources/ScriptureUI/Phone/` behind `#if os(iOS)`, with one UIKit piece (a `UITextView` reader controller mirroring `ChapterTextController`). A thin iOS app target in `Apps/iOS` shares the Mac's bundle identifiers, entitlements pattern and a model-wiring file moved to `Apps/Shared`. Chrome is system components only: `TabView` with a search tab, toolbars, the edit menu, sheets.

**Tech Stack:** Swift 6.2, SwiftUI (iOS 26 `TabView`, `Tab(role: .search)`, `tabBarMinimizeBehavior`, bottom-bar toolbars, sheets with detents), UIKit/TextKit 2 (`UITextView`, `UIEditMenuInteraction`, gesture recognizers), SwiftData with CloudKit, `NSUbiquitousKeyValueStore`, Foundation Models, Swift Testing, `xcodebuild`, `xcrun devicectl`, the iOS Simulator tool. GRDB stays the only third-party dependency.

**Spec:** `docs/superpowers/specs/2026-11-09-milestone-8-ios-design.md` (the design; section numbers below refer to it), mockups in `docs/superpowers/specs/milestone-8-mockups/`, and the original `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`. Design rules: `PRODUCT.md`, `DESIGN.md`, `CLAUDE.md`.

**Execution:** subagent-driven (Matt's choice, 2026-11-09): a fresh implementer and a fresh reviewer per task, then a whole-branch review.

## Before execution starts (Matt)

1. Connect the iPhone by cable, unlock it, tap Trust, and turn on Settings › Privacy & Security › Developer Mode (the phone restarts).
2. The phone is signed in to the same iCloud account as the Mac, with iCloud Drive on, and Passwords & Keychain on so the API key travels.
3. If Task 1 finds that Xcode 26.6 cannot install to iOS 27.0: install Xcode 27 as `/Applications/Xcode.app`, updating macOS if it requires that.

Later, inside the plan: Task 2 and Task 19 need the phone in Matt's hand; Task 22 needs his go-ahead.

## Rulings recorded during execution

Two facts are unknown today. The task that learns each one writes it here, and later tasks read it.

- **Ruling 1 (Task 1): the toolchain.** Xcode 27.2 (27B52) with the iOS 27.2 and macOS 27.2 SDKs, on macOS 26.7.3. The iOS 27.2 simulator runtime is installed, and verification uses "iPhone 18 Pro Max" (the largest listed; there is no iPhone 17 Pro Max simulator); it boots and shuts down cleanly. `devicectl` lists the phone as an iPhone 17 Pro Max (iPhone18,2) (its identifier removed from this file, 2026-11-26), state "connected (no DDI)", with no unsupported-OS error. The ScriptureKit suite under Xcode 27.2 passes 527 tests in 65 suites (milestone 7 under Xcode 26.6 recorded 517 in 65, so 10 more tests, same suite count). The Mac Debug scheme builds and launches under Xcode 27.2.
- **Ruling 2 (Task 2): how one finger paints and scrolls.** **Rule B, hold**, chosen by Matt on his iPhone 17 Pro Max on 2026-11-10. With the pen on, a touch held still for 0.15 s and then dragged paints; a drag that starts moving scrolls. Constants as he tested them: hold 0.15 s; "still" means within 10 pt (the spike's addition, UIKit's default for a long press). As tested, the word under the finger takes the color the moment the hold engages, with a light haptic; a touch shorter than the hold paints nothing; a hold released without a drag leaves that one word painted. Task 12 builds it this way. Matt's words: "B. I like A too, but it was triggered when attempting to swipe from the side too. So I think B is best." Rule A is out for that reason: its sideways drag also painted when he swiped in from the side. He asked for no change to B's numbers and said nothing about handles. The spike's device build must name the phone (`-destination id=<device>`); a `generic/platform=iOS` build got a profile without it. The spike branch and app are deleted.

## Global Constraints

- Minimum macOS 26 / iOS 26.0, Swift language mode 6, Swift Testing, SF Symbols only. The iOS target is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`). No iOS 27 API unless Ruling 1 records Xcode 27, and then only behind `if #available(iOS 27.0, *)`.
- **System glass only.** No `.glassEffect()` anywhere unless the task names it. The tab bar, toolbars, bottom bar, edit menu, sheets and search field are the system's and are not restyled. No glass on rows, tiles or the page.
- **Matt's real data.** Tasks 1 to 21 build and run only Debug: bundle ID `com.matthewfurr.ReadingThroughScripture.dev`, container `iCloud.com.matthewfurr.ReadingThroughScripture.dev`. Nothing opens the Release store, defaults, key-value store or keychain group. "Reset Development Environment" is never used on the Release container. Task 22 is the only task that installs Release, and only on Matt's go-ahead.
- **Same identifiers as the Mac.** The iOS target uses the Mac target's bundle identifiers, team `SFQ7B3J933`, `CLOUDKIT_CONTAINER` and `CLOUDKIT_ENVIRONMENT = Development` values, per configuration.
- `CLAUDE.md` rules: no fixed-point fonts in chrome, no inline colors (tokens in `ScriptureUI/Palette.swift`; spacing and radii from `AppSpacing` and `AppRadius`), no card by reflex, deletes undoable and never confirmed. Plum and `sparkles` are only for the assistant. New color pairings go into `PaletteTests`.
- Voice (`PRODUCT.md`): plain, short, second person, no exclamation marks. Every string the app shows is given verbatim in this plan; use it as written.
- **The Mac does not regress.** Mac behaviour is unchanged except where a task names a change. After any task that touches shared code, the full test suite passes.
- Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (add `--filter <Suite>` for one suite). No test touches the real Keychain, CloudKit, `NSUbiquitousKeyValueStore.default`, the network or anything under `~/Library`. UIKit code is not unit-tested; it is verified in the simulator. Keep a `ModelContainer` alive for as long as its contexts are used. AppKit-touching suites are `@MainActor @Suite`.
- iOS build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -configuration Debug -destination 'platform=iOS Simulator,name=<Ruling 1 device>' -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`. The app is `Build/DerivedData/Build/Products/Debug-iphonesimulator/ReadingThroughScripture.app`. Launch, tap and screenshot it with the iOS Simulator tool.
- Work happens in a worktree on branch `milestone-8-iphone`. In a worktree use `/usr/bin/git`.

## Review Focus

Conditions the design implies and a person will meet, each pinned by a test in the task named.

1. **A time or ratio in an answer is not a verse.** "at 3:30 pm" and "10:45 am" stay plain text even inside a conversation about John. (Task 5)
2. **Quitting mid-lookup, or the other device writing a position mid-lookup, does not move his place.** (Task 7)
3. **A paint that covers nothing paints nothing.** A drag over only a verse number or white space, or a tap, makes no highlight; a drag across two verses makes one highlight. (Tasks 8 and 12)
4. **An entry dated in the future shows under every time filter.** Clocks differ between devices. (Task 3)
5. **A question too long for the on-device model is not answered by it offline.** The unreachable notice stays, and the "Answer with" setting is never changed by a fallback. (Task 6)

---

## Phase 0: toolchain and the throwaway reader

### Task 1: Prove the Mac can reach the phone

**Files:** Modify this plan (Ruling 1).

- [x] **Step 1: Record the baseline.** Run the full test suite on `main`. Write the pass count under Ruling 1.
- [x] **Step 2: Install a simulator runtime.** Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -downloadPlatform iOS`. Then `xcrun simctl list devices available` lists iPhone devices. Pick "iPhone 17 Pro Max" if present, else the largest iPhone listed.
- [x] **Step 3: See the phone.** With the phone connected and unlocked, run `xcrun devicectl list devices`. Expected: Matt's iPhone with state `available (paired)` or `connected`.
- [x] **Step 4: Decide.** If the device row reports an unsupported OS, or Task 2's first device build fails with a device-support error, stop and tell Matt that Xcode 27 is needed (his step 3 above). After he installs it, rerun Step 1 and Step 2 and build the Mac Debug scheme (`README.md` › Running the app). Expected: the same tests pass and the Mac app launches.
- [x] **Step 5: Write Ruling 1** (Xcode and SDK versions, simulator device name, test count) and commit.

```bash
git commit -am "docs: milestone 8 ruling 1, the toolchain"
```

### Task 2: The pen spike (throwaway)

A rough app on branch `spike/ios-reader-pen`. It is not merged, has no tests and is deleted after Ruling 2. Its job is to let Matt feel three ways for one finger to paint and scroll.

**Files:** Create `Spikes/PenSpike/` (its own small Xcode project, bundle ID `com.matthewfurr.ReadingThroughScripture.dev.spike`, depending on the local `ScriptureKit` package). Modify this plan (Ruling 2) on `milestone-8-iphone`.

- [x] **Step 1: Build the page.** One screen: a non-editable `UITextView` showing John 15 from `Build/bible.sqlite` through `ChapterLayout.build(verses:)`, with a pen toggle, five color dots, and a segmented control choosing the rule.
- [x] **Step 2: Implement three rules behind the control.**
  - **A, direction:** with the pen on, a pan whose first 10 pt of travel is within 30° of horizontal paints; any other pan scrolls.
  - **B, hold:** with the pen on, a touch held still for 0.15 s and then dragged paints; a drag that starts moving scrolls.
  - **C, two fingers:** with the pen on, one finger always paints and two fingers scroll.
  - In every rule the painted range grows with the finger across lines, snaps to whole words, and draws as a background in the chosen color.
- [x] **Step 3: Install on the phone.** Build for the device and install with `xcrun devicectl device install app --device <id> <path-to-app>`. This is also the device-support check Task 1 Step 4 refers to.
- [x] **Step 4: Matt tries each rule** on a long chapter: scroll fast, paint a phrase, paint across three lines, paint the last words of a line. Ask which rule he wants and whether its numbers felt right.
- [x] **Step 5: Write Ruling 2** in this plan on `milestone-8-iphone`: the rule's letter, its constants, and anything Matt said about handles or accidental paints. Commit. Delete the spike branch and the spike app from the phone.
- [ ] **If no rule feels reliable to Matt:** stop. Design section 4.3 sends this back to him before Task 12 is built.

---

## Phase A: shared logic, tested on the Mac

These tasks change shared code. Each ends with the full suite passing and the Mac Debug app launching.

### Task 3: The time filter

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserEntry.swift`, `NotesBrowserModel.swift`, `NotesBrowserView.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/NotesBrowserQueryTests.swift`, `NotesBrowserModelTests.swift`

**Interfaces:**
- Produces:
  - `public enum NotesBrowserTimeFilter: String, CaseIterable, Sendable { case anyTime, pastWeek, pastMonth, pastThreeMonths, pastYear }` with `public var title: String` ("Any time", "Past week", "Past month", "Past 3 months", "Past year") and `public func cutoff(from now: Date, calendar: Calendar = .current) -> Date?` (nil for `.anyTime`; otherwise `now` minus 7 days, 1 month, 3 months, 1 year by `calendar.date(byAdding:)`).
  - `NotesBrowserQuery.filter(_ entries: [NotesBrowserEntry], since cutoff: Date?) -> [NotesBrowserEntry]`: keeps entries with `modifiedAt >= cutoff`; nil keeps all.
  - `NotesBrowserModel.timeFilterKey = "notesBrowserTimeFilter"`, `public var timeFilter: NotesBrowserTimeFilter` (stored in `defaults`, default `.anyTime`, setting it re-applies the search), and a new defaulted init parameter `now: @escaping () -> Date = { Date() }`.

- [x] **Step 1: Write the failing tests**

```swift
@Test func cutoffs() {
    let cal = Calendar(identifier: .gregorian)
    let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12))!
    #expect(NotesBrowserTimeFilter.anyTime.cutoff(from: now, calendar: cal) == nil)
    #expect(NotesBrowserTimeFilter.pastWeek.cutoff(from: now, calendar: cal) == cal.date(byAdding: .day, value: -7, to: now))
    #expect(NotesBrowserTimeFilter.pastThreeMonths.cutoff(from: now, calendar: cal) == cal.date(byAdding: .month, value: -3, to: now))
    #expect(NotesBrowserTimeFilter.pastYear.cutoff(from: now, calendar: cal) == cal.date(byAdding: .year, value: -1, to: now))
}
@Test func sinceKeepsTheBoundaryAndTheFuture() {   // Review Focus 4
    // entries dated cutoff - 1 s, cutoff, now, now + 1 day
    #expect(NotesBrowserQuery.filter(entries, since: cutoff).map(\.id) == [atCutoff.id, atNow.id, tomorrow.id])
    #expect(NotesBrowserQuery.filter(entries, since: nil).count == 4)
}
@Test func timeFilterNarrowsEntriesAndIsRemembered() {
    // model with now fixed; one note 3 days old, one 40 days old
    model.timeFilter = .pastWeek
    #expect(model.entries.count == 1)
    #expect(NotesBrowserModel(store: store, defaults: defaults).timeFilter == .pastWeek)
}
@Test @MainActor func timeFilterStaysOnTheDevice() {
    #expect(!SyncedPreferences.keys.contains(NotesBrowserModel.timeFilterKey))
}
```

- [x] **Step 2: Run** `swift test --filter NotesBrowser` and see them fail to compile.
- [x] **Step 3: Implement** the enum, the query function and the model property. `applySearch()` applies the time filter after the kind filter and before sorting.
- [x] **Step 4: Add the Mac control.** In `NotesBrowserView`'s toolbar, beside the existing kind filter, a `Picker` in menu style over `NotesBrowserTimeFilter.allCases` bound to `model.timeFilter`, labelled "How far back" for accessibility.
- [x] **Step 5: Run the full suite**; expect all pass. Build and launch the Mac Debug app; in the notes browser choose "Past week" and confirm older entries leave the list.
- [x] **Step 6: Commit** `feat: a time filter in the notes browser`.

### Task 4: The grouped search model

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/SearchResults.swift`, `SearchRanker.swift`
- Modify: `PaletteItem.swift` (new case), `MarkupItem.swift` (`MarkupColor: Hashable`), `NavigationModel.swift`, `Packages/ScriptureKit/Sources/ScriptureData/BibleStore.swift`
- Test: Create `Tests/ScriptureUITests/SearchRankerTests.swift`; modify `NavigationModelTests.swift`, `Tests/ScriptureDataTests` (the store's search suite)

**Interfaces:**
- Consumes: `NotesBrowserEntry`, `NotesBrowserLoader.entries(store:query:)`, `ReferenceParser`, `PaletteRanker`'s existing rules for references, books, translations and commands.
- Produces:

```swift
public struct SearchMarkHit: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Sendable { case note, highlight, bookmark, thread }
    public let id: UUID
    public let kind: Kind
    public let target: MarkupTarget
    public let referenceString: String
    public let quotedText: String
    public let color: MarkupColor?
    public let firstLine: String        // PaletteNoteHit.firstLine(of:) of the body; a thread's title
    public let modifiedAt: Date
    public init(entry: NotesBrowserEntry)
    public var symbolName: String       // note.text, highlighter, bookmark.fill, sparkles
}
// PaletteItem gains:  case mark(SearchMarkHit)   (id "mark:<uuid>", title = referenceString, subtitle = firstLine)

public enum SearchGroupKind: String, CaseIterable, Sendable {
    case goTo, marksInPassage, books, translations, commands, notes, asked, scripture
}
public struct SearchGroup: Identifiable, Equatable, Sendable {
    public let kind: SearchGroupKind
    public let title: String
    public let items: [PaletteItem]
    public let totalCount: Int          // before the limit
    public var id: SearchGroupKind { kind }
}
public struct SearchLimits: Equatable, Sendable {
    public var books, notes, asked, verses, marksInPassage: Int
    public static let palette = SearchLimits(books: 6, notes: 5, asked: 3, verses: 8, marksInPassage: 12)
    public static let phone = SearchLimits(books: 6, notes: 20, asked: 10, verses: 20, marksInPassage: 50)
}
public struct SearchResults: Equatable, Sendable {
    public static let empty: SearchResults
    public let groups: [SearchGroup]                  // only non-empty groups, in display order
    public let verseColors: [String: MarkupColor]     // PaletteItem.id of a verse row -> the color of his mark on it
    public var flatItems: [PaletteItem]               // groups' items in order
    public func only(_ kind: SearchGroupKind?) -> SearchResults
}
public enum SearchRanker {
    public static func results(
        query: String, books: [TranslationBook], translations: [Translation], activeTranslationID: String,
        verses: [Verse], verseTotal: Int, marks: [NotesBrowserEntry],
        includeCommands: Bool, limits: SearchLimits
    ) -> SearchResults
    /// Whole words that start with a query word, for bolding. Case- and diacritic-insensitive.
    public static func matchRanges(in text: String, query: String) -> [Range<String.Index>]
}
// BibleStore gains:
public func searchCount(_ text: String, translationID: String) throws -> Int
// NavigationModel gains:
public private(set) var paletteResults: SearchResults      // paletteItems stays, equal to paletteResults.flatItems
public var markSearch: (() -> [NotesBrowserEntry])?        // all of the reader's entries, unfiltered
public var searchLimits: SearchLimits = .palette
public var includesCommandsInSearch = true
```

**Rules the ranker implements:**
- A **passage query** is one `ReferenceParser.parse` reads as a reference with a chapter that exists in `books`. Group order: `goTo`, `marksInPassage`, `books`, `translations`, `commands`, `scripture`.
  - `marksInPassage` holds every entry in that book and chapter (and, when the query names a verse or range, only those overlapping it), all four kinds, sorted by verse, then `endVerse`, then `modifiedAt`. Title: "Your marks in \(chapter title)", for example "Your marks in John 15".
- Any other query is a **word query**. Group order: `goTo` (a bare book goes to `books` as today), `books`, `translations`, `commands`, `notes`, `asked`, `scripture`.
  - `notes` holds note entries whose body or quoted text matches and highlight entries whose quoted text matches, newest first. Bookmarks never appear in a word query.
  - `asked` holds thread entries whose title or body matches, newest first.
  - "Matches" means every query word starts some word of the text, folded for case and diacritics.
- Books, translations and commands follow `PaletteRanker.rank`'s existing rules exactly. Commands are omitted when `includeCommands` is false.
- Titles: "Go to", "Books", "Translations", "Commands", "Your notes", "Asked", "Scripture · \(activeTranslationID)".
- `scripture.totalCount` is `verseTotal`. `verseColors` maps a verse row to the color of the first colored entry whose book and chapter match and whose `verse...endVerse` contains it.
- An empty or whitespace query returns `.empty`.
- `NavigationModel.updatePalette()` builds `paletteResults` with `searchLimits`, `includesCommandsInSearch`, `store.search(..., limit: searchLimits.verses)`, `store.searchCount`, and `markSearch?() ?? []`. `select(.mark(hit))` calls `showTarget` as `.note` does today. The old `.note` case, `PaletteNoteHit`, `noteSearch` and `NotesBrowserModel.noteHits` stay until Task 21 removes them; the ranker no longer emits `.note`.

- [x] **Step 1: Write the failing tests** in `SearchRankerTests.swift`, using entries built in the test (two notes, one bare highlight, one bookmark and one thread in John 15; one note in 1 John 2):

```swift
@Test func aWordGroupsNotesAskedThenScripture() {
    let r = rank("abide")
    #expect(r.groups.map(\.kind) == [.notes, .asked, .scripture])
    #expect(r.groups[0].title == "Your notes")
    #expect(r.groups[2].title == "Scripture · KJV")
    #expect(r.groups[2].totalCount == 61)                    // verseTotal passed in
}
@Test func aWordFindsABareHighlightByItsWordsButNeverABookmark()
@Test func notesAreNewestFirstAndLimited()                    // limits.notes = 1 -> items.count == 1, totalCount == 2
@Test func aPassageListsEveryMarkThereInVerseOrder() {
    let r = rank("john 15")
    #expect(r.groups.map(\.kind).prefix(2) == [.goTo, .marksInPassage])
    #expect(r.groups[1].title == "Your marks in John 15")
    #expect(marks(r).map(\.target.verse) == [4, 5, 5, 13, 15])   // note, highlight, bookmark, note, thread
}
@Test func aPassageWithAVerseKeepsOnlyOverlappingMarks()      // "john 15:5" -> the two verse-5 marks
@Test func aMarkedVerseCarriesItsColor()                      // verseColors[verse row id] == the note's color
@Test func commandsCanBeLeftOut()
@Test func booksAndTranslationsKeepTheOldRules()              // "ps" -> Psalms first; "kjv" -> the translation
@Test func emptyAndPunctuationQueriesReturnNothing()          // "", "  ", "\"", "*" -> .empty or no groups, no throw
@Test func matchRangesBoldWholeWordsThatStartWithTheQuery() {
    let text = "Abiding comes before bearing; abide."
    #expect(SearchRanker.matchRanges(in: text, query: "abide").map { String(text[$0]) } == ["abide"])
    #expect(SearchRanker.matchRanges(in: text, query: "abid").map { String(text[$0]) } == ["Abiding", "abide"])
}
```

Add to `NavigationModelTests`: `paletteItems == paletteResults.flatItems` after `updatePalette()`; selecting a `.mark` calls `showTarget` and closes the palette. Add a `searchCount` test beside the store's existing search tests (count equals an unlimited search's count).

- [x] **Step 2: Run** `swift test --filter SearchRanker` and see them fail.
- [x] **Step 3: Implement** `SearchResults.swift`, `SearchRanker.swift`, the `PaletteItem` case (and every `switch` over it), `searchCount`, and the `NavigationModel` additions. `SearchRanker` calls into `PaletteRanker` for the book, translation and command rows; do not copy those rules.
- [x] **Step 4: Wire the Mac.** In `Apps/Mac/.../ReadingThroughScriptureApp.swift` `wirePalette`, set `model.markSearch` to return `try? NotesBrowserLoader.entries(store:query: "")`. The Mac palette view still renders `paletteItems`; a `.mark` row draws through the existing row with its `symbolName`.
- [x] **Step 5: Run the full suite.** Launch the Mac Debug app, press ⌘K, type a word from a note, and confirm the note opens.
- [x] **Step 6: Commit** `feat: a grouped search model shared by the palette and the phone`.

### Task 5: References in answers

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReferenceLinker.swift`, `VersePreview.swift`, `VersePreviewView.swift`
- Modify: `ChatTurnRow.swift`, `ChatPanelView.swift`, `Packages/ScriptureKit/Sources/ScriptureLLM/PromptBuilder.swift`
- Test: Create `Tests/ScriptureUITests/ReferenceLinkerTests.swift`, `VersePreviewTests.swift`; modify the prompt builder's tests

**Interfaces:**
- Produces:

```swift
public enum ReferenceLinker {
    public static let scheme = "scripture"
    public static func references(in text: String, contextBook: Book?, chapterCount: (String) -> Int?)
        -> [(range: Range<String.Index>, reference: Reference)]
    public static func url(for reference: Reference) -> URL          // scripture://JHN/15/4-5, scripture://1JN/2/6
    public static func reference(from url: URL) -> Reference?
    /// Sets `.link` on each reference. Runs that already carry a link or code styling are left alone.
    public static func linked(_ text: AttributedString, contextBook: Book?, chapterCount: (String) -> Int?) -> AttributedString
}
public struct VersePreview: Identifiable, Equatable, Sendable {
    public let reference: Reference
    public let translationID: String
    public let verses: [Verse]
    public var id: String                      // reference.displayString + translationID
    public var title: String { reference.displayString }
    public static func load(_ reference: Reference, translationID: String, store: BibleStore) throws -> VersePreview?   // nil when no verse exists
}
public struct VersePreviewView: View {         // title, translation ID, the verses in the reader's serif, one button
    public init(preview: VersePreview, openTitle: String, onOpen: @escaping () -> Void)
}
```

**Rules:**
- A reference is `<book> <chapter>:<verse>` with an optional `-<verse>` or `–<verse>` range, where `<book>` is anything `ReferenceParser.parse` accepts ("John", "1 John", "Ps", "Song of Solomon"). Find candidates with a regular expression for `C:V`, then try the capitalised words before it from longest to shortest until `ReferenceParser.parse("\(words) \(c):\(v)")` succeeds.
- A bare `C:V` links only when `contextBook` is given, and resolves against it.
- Drop a candidate when the chapter exceeds `chapterCount(book.id)`, when the bare form is followed by optional space and "am", "pm", "a.m." or "p.m." in any case, or when it is directly preceded by a digit or colon.
- A chapter with no verse ("John 15") is not linked.
- `PromptBuilder`'s base instructions gain the sentence: `Cite Scripture as Book Chapter:Verse, for example John 15:4.`
- `ChatTurnRow` renders assistant text through `ReferenceLinker.linked(NoteMarkdown.document(...), contextBook:chapterCount:)`, tinted with `Color.assistant`, and handles the scheme with an `OpenURLAction` that calls a new `onOpenReference: (Reference) -> Void`. `contextBook` is the thread's book, nil for a `general` thread.
- **Mac:** `ChatPanelView` holds `@State var preview: VersePreview?` and shows `VersePreviewView(openTitle: "Open")` in a `.popover` attached to the message row. Open calls `MarkupNavigation`-style lookup (Task 7 changes what that does).

- [x] **Step 1: Write the failing tests**

```swift
@Test func findsFullReferencesAndRanges() {
    let found = refs("the Spirit remains (John 1:32); see 1 John 2:6 and Ps 91:1, also John 15:4-5.")
    #expect(found.map(\.displayString) == ["John 1:32", "1 John 2:6", "Psalm 91:1", "John 15:4–5"])   // as Reference.displayString prints them
}
@Test func aLeadingCapitalisedWordIsNotPartOfTheBook()   // "In John 1:32" -> John 1:32
@Test func bareChapterVerseNeedsAContextBook() {
    #expect(refs("see 5:3", context: nil).isEmpty)
    #expect(refs("see 5:3", context: matthew).map(\.displayString) == ["Matthew 5:3"])
}
@Test func timesAndRatiosAreNotVerses() {                 // Review Focus 1
    #expect(refs("We meet at 3:30 pm or 10:45 a.m.", context: john).isEmpty)
    #expect(refs("version 12:3:4", context: john).isEmpty)
}
@Test func aChapterPastTheBookIsNotLinked()               // "John 40:1" -> none
@Test func aChapterAloneIsNotLinked()                     // "John 15" -> none
@Test func urlRoundTrips()                                // reference(from: url(for: r)) == r, for a verse and a range
@Test func linkedSetsLinksAndLeavesCodeAndExistingLinksAlone()
// VersePreviewTests, on the fixture store:
@Test func loadsARange()                                  // verses.count == 2 for a two-verse range
@Test func aMissingVerseIsNil()
```

Add to the prompt builder's tests: the instructions contain the citation sentence.

- [x] **Step 2: Run** `swift test --filter ReferenceLinker` and see them fail.
- [x] **Step 3: Implement** the three files and the `ChatTurnRow`, `ChatPanelView` and `PromptBuilder` changes.
- [x] **Step 4: Run the full suite.** In the Mac Debug app ask a chapter question, click a reference in the reply, and confirm the popover shows the verse and Open goes to it.
- [x] **Step 5: Commit** `feat: references in assistant replies open the verse`.

### Task 6: Ask falls back to on-device when the cloud is unreachable

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureLLM/LLMRouter.swift`, `ScriptureUI/AssistantModel.swift`, `ScriptureUI/AssistantItems.swift`
- Test: `Tests/ScriptureLLMTests` (the router's suite), `Tests/ScriptureUITests/AssistantModelTests.swift`

**Interfaces:**
- Produces:
  - `LLMRouter.offlineFallback(for request: LLMRequest) -> (any LLMProvider)?`: the on-device provider when it is `.available` and `OnDeviceFit.fits(request)`; otherwise nil.
  - `ProviderLabel.fallbackText(cloudName: String) -> String` returning `"On-device · \(cloudName) unreachable"`, where `cloudName` is the part of the cloud label before " · " ("Claude", "OpenAI", or the host).
- Behaviour in `AssistantModel`: when a reply from a cloud provider fails with `LLMProviderError.transport` **before any `textDelta` has arrived**, build the compact request (the `build(true)` form `route` already uses) and ask `offlineFallback`. If it returns a provider, restart the same reply with it; the message's `providerLabel` is `fallbackText`. If it returns nil, behave as today (`.unreachable`). A transport failure after text has arrived behaves as today. The stored `assistantProvider` preference is never written.

- [x] **Step 1: Write the failing tests** with `FakeProvider`:

```swift
@Test func fallbackIsOnDeviceWhenItFits()                 // router: on-device available, small request -> on-device
@Test func noFallbackWhenTooLongOrUnavailable()           // router: nil in both cases
@Test func anUnreachableCloudIsAnsweredOnDevice() {       // model: cloud fake throws .transport at once; on-device fake answers "ok"
    #expect(model.messages.last?.content == "ok")
    #expect(model.messages.last?.providerLabel == "On-device · Claude unreachable")
    #expect(model.notice == nil)
}
@Test func aTooLongQuestionKeepsTheUnreachableNotice()    // Review Focus 5: notice == .unreachable, no assistant text
@Test func aReplyCutOffMidwayIsNotRestarted()             // cloud fake yields a delta then throws .transport -> today's outcome
@Test func theFallbackNeverChangesThePreference()         // defaults value for AssistantSettings.providerKey unchanged
```

- [x] **Step 2: Run** the two suites and see them fail.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run the full suite.**
- [x] **Step 5: Commit** `feat: Ask answers on-device when the cloud cannot be reached`.

### Task 7: Looking something up does not move his place

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/NavigationModel.swift`, `MarkupTarget.swift` (`MarkupNavigation.show`), `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift` (one menu item)
- Test: `Tests/ScriptureUITests/NavigationModelTests.swift`, `MarkupNavigationTests.swift`

**Interfaces:**
- Produces, on `NavigationModel`:

```swift
public struct ReadingPlace: Equatable, Sendable {
    public let location: ChapterLocation
    public let verse: Int
    public let translationID: String
}
public private(set) var lookupReturn: ReadingPlace?     // non-nil while a looked-up passage is showing
public var lookupReturnTitle: String?                   // title(for: lookupReturn.location), e.g. "John 15"
public func lookUp(_ location: ChapterLocation, verse: Int?, translationID: String? = nil)
public func returnFromLookup()
public func keepLookup()                                // "Read From Here"
```

**Rules:**
- `lookUp` shows the passage through the history like `open`, but does not write the reading position. If no lookup is showing it first records the current place in `lookupReturn`. A second `lookUp` keeps the first return place. With no current location (the front page), `lookUp` behaves exactly as `open`.
- While `lookupReturn` is set: scrolling updates the history but does not write the position; `adoptStoredPosition()` does nothing.
- `returnFromLookup()` shows the return place at its verse and translation, clears `lookupReturn`, and leaves the stored position as it was.
- `keepLookup()` clears `lookupReturn` and writes the current place as the position.
- Reading on keeps the lookup as his place the same way: `open(...)`, `goToNextChapter()` and `goToPreviousChapter()` clear `lookupReturn` and write the position as they do today.
- `goBack()` or `goForward()` that lands on the return place's chapter counts as `returnFromLookup()`. `goHome()` during a lookup returns first, then behaves as today.
- `MarkupNavigation.show` calls `lookUp` in place of `open`. `NavigationModel.select` calls `lookUp` for `.verse` (and `.mark` goes through `showTarget`, which is `show`); `.reference` and `.book` still call `open`.
- **Mac:** the Back toolbar button already returns. Add one menu item, "Read From Here", in the menu that holds Back and Forward, enabled while `lookupReturn != nil`, calling `keepLookup()`.

- [x] **Step 1: Write the failing tests**

```swift
@Test func aLookupShowsThePassageButKeepsTheStoredPlace() {
    model.open(john15); model.reportFirstVisibleVerse(4)
    model.lookUp(firstJohn2, verse: 6)
    #expect(model.location == firstJohn2)
    #expect(positionStore.load()?.chapterLocation == john15)
    #expect(model.lookupReturn == ReadingPlace(location: john15, verse: 4, translationID: "KJV"))
}
@Test func scrollingALookupDoesNotSave()
@Test func returningRestoresChapterVerseAndTranslation()
@Test func aSecondLookupKeepsTheFirstReturnPlace()
@Test func keepingALookupMakesItThePlace()
@Test func theNextChapterLinkKeepsTheLookup()             // goToNextChapter -> lookupReturn nil, position = the new chapter
@Test func goingBackToTheReturnChapterEndsTheLookup()
@Test func aLookupFromTheFrontPageIsAnOpen()
@Test func aRelaunchAfterALookupOpensTheReadingPlace() {  // Review Focus 2: a second model on the same position store
    #expect(relaunched.location == john15)
}
@Test func anotherDevicesPositionIsIgnoredDuringALookup() // Review Focus 2: write a stored position, adoptStoredPosition(), location unchanged
@Test func verseRowsLookUpAndReferenceRowsOpen()          // select(.verse) leaves the position; select(.reference) moves it
```

Update `MarkupNavigationTests` so `show` leaves the stored position alone.

- [x] **Step 2: Run** `swift test --filter Navigation` and see them fail.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run the full suite.** In the Mac Debug app: read John 15, open a note in another chapter from the notes browser, quit, relaunch, and confirm it opens at John 15.
- [x] **Step 5: Update `README.md`** where it describes the reading position, and commit `feat: a lookup keeps your place until you read on`.

---

## Phase B: the iPhone app

### Task 8: Lift the reader's text logic out of AppKit

The phone's reader needs the Mac reader's rules for snapping, hit-testing and reporting a selection. They are private methods on `ChapterTextController` today (around lines 601 to 670).

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderTextLogic.swift`
- Modify: `ChapterTextController.swift` (call the new functions; no behaviour change)
- Test: Create `Tests/ScriptureUITests/ReaderTextLogicTests.swift`

**Interfaces:**
- Produces:

```swift
public enum ReaderTextLogic {
    /// The range grown or shrunk to whole words, excluding verse numbers and separators; nil when it covers no word.
    public static func snapToWords(_ range: NSRange, in layout: ChapterLayout) -> NSRange?
    /// The innermost highlight whose range contains `range` (a caret counts at either end).
    public static func innermostHighlight(containing range: NSRange, in decorations: ChapterDecorations) -> RangeDecoration?
    /// What `ChapterTextController.selectionReport()` returns for this range.
    public static func report(for range: NSRange, layout: ChapterLayout, verses: [Verse], decorations: ChapterDecorations) -> SelectionReport?
}
```

- [x] **Step 1: Write the failing tests** on a fixture chapter:

```swift
@Test func aRangeInsideAWordGrowsToTheWord()
@Test func aRangeAcrossTwoVersesSnapsToOneRangeAndReportsBothVerses()   // Review Focus 3: report.selection.verse != endVerse
@Test func aRangeOverOnlyAVerseNumberOrSpaceIsNil()                     // Review Focus 3
@Test func anEmptyRangeOutsideAnyHighlightReportsNothing()              // Review Focus 3: a tap
@Test func nestedHighlightsResolveToTheInnermost()
@Test func aCaretAtAHighlightsEndStillFindsIt()
```

- [x] **Step 2: Run** `swift test --filter ReaderTextLogic` and see them fail.
- [x] **Step 3: Move the logic.** `ChapterTextController` keeps its methods as one-line calls into `ReaderTextLogic`.
- [x] **Step 4: Run the full suite.** `ChapterTextControllerTests` and `ChapterTextControllerMarkupTests` pass unchanged.
- [x] **Step 5: Commit** `refactor: reader text rules shared by both platforms`.

### Task 9: The iOS target and the tab shell

**Files:**
- Create: `Apps/iOS/ReadingThroughScripture.xcodeproj/project.pbxproj` (and its shared scheme `ReadingThroughScripture-iOS`), `Apps/iOS/ReadingThroughScripture/ReadingThroughScriptureApp.swift`, `Apps/iOS/ReadingThroughScripture.entitlements`
- Create: `Apps/Shared/AppModels.swift`; move `Apps/Mac/ReadingThroughScripture/AppSync.swift` to `Apps/Shared/AppSync.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/Phone/PhoneRootView.swift`, `PhoneShellModel.swift`, `PhoneSeed.swift`
- Modify: `ReadingThroughScripture.xcworkspace/contents.xcworkspacedata`, the Mac project (reference `Apps/Shared`), `Apps/Mac/.../ReadingThroughScriptureApp.swift`, `Packages/ScriptureKit/Sources/ScriptureModel/SyncConfiguration.swift`, `DESIGN.md`, `DESIGN.json`
- Test: `Tests/ScriptureModelTests` (the `SyncConfiguration` suite); create `Tests/ScriptureUITests/PhoneShellModelTests.swift`

**Interfaces:**
- Produces:

```swift
// SyncConfiguration (ScriptureModel)
public static func fromInfoDictionary(_ info: [String: Any]?) -> SyncConfiguration?   // keys "CloudKitContainer", "CloudKitEnvironment"
// current() on iOS returns fromInfoDictionary(Bundle.main.infoDictionary)

// Apps/Shared/AppModels.swift, compiled into both app targets
@MainActor struct AppModels {
    let navigation: NavigationModel; let markup: MarkupModel; let colorSettings: ColorSettingsModel
    let notesBrowser: NotesBrowserModel; let assistant: AssistantModel; let assistantSettings: AssistantSettingsModel
    let templates: PromptTemplateStore; let exporter: NotesExporter
    static func make(appSync: AppSync) throws -> AppModels      // the wiring now inline in the Mac app's startup
}

// ScriptureUI (platform-neutral, so it is tested on the Mac)
public enum PhoneTab: Hashable, Sendable { case read, notes, ask, search }
@MainActor @Observable public final class PhoneShellModel {
    public var tab: PhoneTab = .read
    public var isLibraryShown = false
    public var isSettingsShown = false
    public var noteSheet: UUID?                 // the note being shown
    public var isChapterNotesShown = false
    public var askSheetThreadID: UUID?          // a conversation opened over the page
    public var versePreview: VersePreview?
    public init()
    public func showInReader()                  // tab = .read and every sheet closed
}

// ScriptureUI/Phone (#if os(iOS))
public struct PhoneRootView: View {
    public init(navigation: NavigationModel, markup: MarkupModel, notesBrowser: NotesBrowserModel,
                assistant: AssistantModel, shell: PhoneShellModel, settings: () -> AnyView)
}
```

**What the target is:**
- Model `Apps/iOS/...pbxproj` on the Mac project: `objectVersion = 77`, one file-system-synchronized group, the local package reference, the same "copy `Build/bible.sqlite` into resources" script phase, and `Apps/Shared` as a second synchronized group in both projects.
- Build settings: `SDKROOT = iphoneos`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `TARGETED_DEVICE_FAMILY = 1`, `SWIFT_VERSION = 6.0`, `GENERATE_INFOPLIST_FILE = YES`, `DEVELOPMENT_TEAM = SFQ7B3J933`, the Mac's `PRODUCT_BUNDLE_IDENTIFIER`, `CLOUDKIT_CONTAINER` and `CLOUDKIT_ENVIRONMENT` per configuration, `INFOPLIST_KEY_CFBundleDisplayName = "Scripture"`, `INFOPLIST_KEY_UILaunchScreen_Generation = YES`, `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` listing portrait and both landscapes, and an `Info.plist` fragment (`INFOPLIST_FILE`, merged with the generated keys) adding `CloudKitContainer = $(CLOUDKIT_CONTAINER)`, `CloudKitEnvironment = $(CLOUDKIT_ENVIRONMENT)` and `UIBackgroundModes = [remote-notification]`.
- Entitlements: the Mac file's keys, with `aps-environment` in place of `com.apple.developer.aps-environment`.
- The app icon: reference `Apps/Mac/ReadingThroughScripture/AppIcon.icon` from the iOS target.
- `AppSync` uses `NSApplication` notifications; give it the `UIApplication` equivalents under `#if os(iOS)`. `SyncProbe` stays Mac-only.
- The iOS `App` builds `AppSync` and `AppModels` as the Mac does, shows `PhoneRootView`, and shows the Mac's startup-error sentence on failure.
- `PhoneRootView` is a `TabView(selection:)` with `Tab("Read", systemImage: "book", value: .read)`, `Tab("Notes", systemImage: "note.text", value: .notes)`, `Tab("Ask", systemImage: "sparkles", value: .ask)` and `Tab(value: .search, role: .search)`, with `.tabBarMinimizeBehavior(.onScrollDown)` and the accent as tint. In this task each tab shows its name as a placeholder.
- `PhoneRootView`'s `settings` closure exists because `AppSync` lives in the app target: the app builds the settings content (Task 18's `PhoneSettingsScreen`) and hands it in. Until Task 18 it is an empty view.
- `PhoneSeed`: a Debug-only launch argument `-phoneSeed` that, when the store is empty, inserts a fixed sample: in John 15 a highlight with a note on 15:4, a bare highlight and a bookmark on 15:5, a note on 15:13, and one chapter conversation titled `What does "abide" mean in the Greek?`. Simulator verification in later tasks launches with it.

**`DESIGN.md`:** add `## 7. iPhone` before any other phone view is written. It states: the tab bar and its three symbols; that the app applies no glass and names every system surface used (tab bar, top toolbar, bottom toolbar in pen mode, edit menu, sheets, search field); sheet detents (note: medium and large; verse: medium; Ask over the page: large); the margin marks (`note.text` and `bookmark.fill` in the accent at caption size, right margin, note above bookmark when a verse has both); the symbols added to the inventory (`books.vertical`, `ellipsis`, `checkmark` for Done, `chevron.left` for the way back); that the type ladder and spacing scale apply unchanged; and the reader's side margins on the phone (`AppSpacing.lg`, in place of the Mac's `xxl`). Mirror the additions in `DESIGN.json`.

- [x] **Step 1: Write the failing tests**

```swift
@Test func readsContainerAndEnvironmentFromInfo() {
    let c = SyncConfiguration.fromInfoDictionary(["CloudKitContainer": "iCloud.x.dev", "CloudKitEnvironment": "development"])
    #expect(c == SyncConfiguration(containerIdentifier: "iCloud.x.dev", environment: .development))
}
@Test func noContainerMeansNoSync()               // nil info, missing key, empty string -> nil
@Test @MainActor func showInReaderClosesEverySheet()
```

- [x] **Step 2: Run** them and see them fail.
- [x] **Step 3: Implement** `fromInfoDictionary`, `PhoneShellModel`, then extract `AppModels` and move `AppSync`. Build and launch the **Mac** Debug app and run the full suite before going on.
- [x] **Step 4: Create the iOS project, scheme, entitlements and app file; add the project to the workspace; write `PhoneRootView` and `PhoneSeed`; write the `DESIGN.md` section.**
- [x] **Step 5: Build for the simulator** with the Global Constraints command. Fix whatever in `ScriptureUI` does not compile for iOS by putting Mac-only views behind `#if os(macOS)`; do not change their behaviour.
- [x] **Step 6: Verify in the simulator.** Launch with `-phoneSeed`. Screenshot: a glass tab bar with Read, Notes, Ask and a separate search button; tapping each shows its placeholder; tapping search turns the bar into a search field.
- [x] **Step 7: Run the full suite, launch the Mac Debug app once more, commit** `feat: the iOS target and its tab bar`.

### Task 10: The reader on the phone

**Files:**
- Create: `ScriptureUI/MarginMarks.swift` (neutral); `ScriptureUI/Phone/PhoneChapterTextController.swift`, `PhoneChapterTextView.swift`, `PhoneReaderScreen.swift`
- Modify: `PhoneRootView.swift`
- Test: Create `Tests/ScriptureUITests/MarginMarksTests.swift`

**Interfaces:**
- Produces:

```swift
public struct MarginMark: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case note(noteID: UUID, highlightID: UUID?), bookmark }
    public let id: String                  // "note:<uuid>" or "bookmark:<verse>"
    public let kind: Kind
    public let verse: Int
    public let characterIndex: Int         // where in the layout the mark's line is found
    public static func build(columnItems: [NotesColumnItem], items: [MarkupItem], bookmarkVerses: [Int],
                             layout: ChapterLayout) -> [MarginMark]
}
// #if os(iOS)
@MainActor public final class PhoneChapterTextController: NSObject, UITextViewDelegate {
    public let textView: UITextView
    var onFirstVisibleVerseChange: (Int) -> Void
    var onSelectionChange: (SelectionReport?) -> Void
    var onMarginMarkTap: (MarginMark) -> Void
    private(set) var layout: ChapterLayout?
    func update(verses: [Verse], typography: ReaderTypography, scrollTarget: ScrollTarget?,
                decorations: ChapterDecorations, marginMarks: [MarginMark], header: UIView?, footer: UIView?)
    func rect(for range: NSRange) -> CGRect?          // first line's rect in the text view, for menus and handles
}
struct PhoneChapterTextView: UIViewRepresentable     // makes and updates the controller, as ChapterTextView does on the Mac
public struct PhoneReaderScreen: View
```

**Rules:**
- A note mark sits on the line where its highlight starts; a chapter note has no margin mark. A bookmark mark sits on its verse's first line. Marks are sorted by `characterIndex`, a note before a bookmark on the same line.
- The text view is not editable, is selectable, and is itself the scroll view the tab bar follows. Text comes from `ChapterLayout.build`; highlights draw as in `ChapterDecorations` (background color, dotted and dashed underlines, the outlined one); side insets are `AppSpacing.lg`.
- The chapter heading scrolls with the text at the top; the "Next: John 16" and "Previous: John 14" links scroll with it at the bottom and call `goToNextChapter()` and `goToPreviousChapter()`. There is no sideways swipe between chapters.
- The top verse is reported through `navigation.reportFirstVisibleVerse`, and `scrollTarget` is honoured, exactly as on the Mac.
- `PhoneReaderScreen` is a `NavigationStack` whose toolbar has: leading, a `books.vertical` button labelled "Library" (or, while `navigation.lookupReturn != nil`, a `chevron.left` button titled with `lookupReturnTitle` that calls `returnFromLookup()`); principal, the chapter title with the translation ID in caption; trailing, a `highlighter` button labelled "Highlighter" and an `ellipsis` menu. In this task the pen button does nothing and the menu is empty.
- It loads markup as the Mac window does: `markup.load(chapter:translationID:verses:)` when the location or verses change, and `assistant.setLocation(...)`.

- [x] **Step 1: Write the failing tests** for `MarginMark.build`:

```swift
@Test func aNoteMarksTheLineItsHighlightStartsOn()
@Test func aBookmarkMarksItsVersesFirstLine()
@Test func aNoteComesBeforeABookmarkOnTheSameLine()
@Test func aChapterNoteHasNoMarginMark()
```

- [x] **Step 2: Run** them and see them fail; implement `MarginMarks.swift`; see them pass.
- [x] **Step 3: Write the controller, the representable and the screen.** Make the Read tab show `PhoneReaderScreen`.
- [x] **Step 4: Verify in the simulator** with `-phoneSeed`, at John 15: the page reads as on the Mac in the serif; 15:4 and 15:5 show their highlight colors; a note mark and a bookmark mark sit in the right margin; scrolling shrinks the tab bar; the link at the end opens John 16; relaunching returns to the verse that was at the top. Screenshot light and dark.
- [x] **Step 5: Commit** `feat: the reader on the phone`.

### Task 11: Selecting text and the markup menu

**Files:**
- Create: `ScriptureUI/Phone/PhoneMarkupMenu.swift`
- Modify: `PhoneChapterTextController.swift`, `PhoneReaderScreen.swift`

**Interfaces:**
- Consumes: `MarkupModel.menuItems(for:) -> [MarkupMenuItem]` and the `MarkupModel` actions the Mac's `MarkupContextMenu` calls; `ReaderTextLogic`.
- Produces: `enum PhoneMarkupMenu { @MainActor static func make(for report: SelectionReport, model: MarkupModel, share: @escaping (String) -> Void) -> UIMenu }`.

**Rules:**
- Press-and-hold selection is the system's. When the selection changes, snap it with `ReaderTextLogic.snapToWords` and report it through `markup.setSelection`.
- The edit menu (`textView(_:editMenuForTextIn:suggestedActions:)`) is `PhoneMarkupMenu.make`, built from the same `menuItems(for:)` the Mac uses, in the same order with the same titles: the color swatches as an inline group of small tinted circles, then Add Note or Edit Note, Remove Highlight, Bookmark, Copy, Copy with Reference, Share, Ask About This Passage. The system's own suggested actions are dropped except Look Up and Translate.
- A tap inside a highlight selects that highlight's range (`ReaderTextLogic.innermostHighlight`), outlines it through `markup.outlinedHighlightID`, and presents the same menu at it with `UIEditMenuInteraction`.
- Applying a color plays `.sensoryFeedback(.selection)`. Share presents the system share sheet with `markup.shareText(for:)`. Ask calls `markup.onAskAboutPassage`, which Task 16 connects.
- `markup.undoManager` is the scene's undo manager, so a removed highlight comes back with shake or a three-finger swipe.

- [x] **Step 1: Implement** the menu and the delegate methods.
- [x] **Step 2: Verify in the simulator:** hold on a word in 15:7, drag the handle across "ask what ye will", pick a color: the phrase is highlighted and whole words only. Tap the highlight: the menu shows Remove Highlight. Remove it, then undo: it returns. Bookmark a verse: the margin mark appears. Copy with Reference puts `“…” — John 15:7 (KJV)` on the pasteboard.
- [x] **Step 3: Commit** `feat: selecting and marking text on the phone`.

### Task 12: The pen

Read **Ruling 2** first. If it is not recorded, stop.

**Files:**
- Create: `ScriptureUI/PenModel.swift` (neutral); `ScriptureUI/Phone/PenBar.swift`, `PhonePaintGesture.swift`
- Modify: `ScriptureUI/MarkupModel.swift`, `ScriptureModel/MarkupStore.swift`, `PhoneChapterTextController.swift`, `PhoneReaderScreen.swift`
- Test: Create `Tests/ScriptureUITests/PenModelTests.swift`; modify `MarkupModelTests.swift`

**Interfaces:**
- Produces:

```swift
// MarkupModel gains (undoable, like setColor):
public func resizeHighlight(id: UUID, to report: SelectionReport)
// MarkupStore gains:
public func updateRange(highlightID: UUID, selection: TextSelection) throws

@MainActor @Observable public final class PenModel {
    public static let colorKey = "penColorID"          // per device, not synced
    public private(set) var isOn = false
    public private(set) var colorID: UUID?             // the ringed color; the first chip when nothing is stored
    public private(set) var selectedHighlightID: UUID?
    public init(markup: MarkupModel, defaults: UserDefaults = .standard)
    public func turnOn()
    public func turnOff()                               // also clears the selection and the outline
    public func paint(_ report: SelectionReport?) -> UUID?    // nil report paints nothing
    public func select(highlightID: UUID?)
    public func chooseColor(_ id: UUID)                 // sets the pen color; recolors the selected mark
    public func resizeSelected(to report: SelectionReport?)
}
```

**Rules:**
- The pen button toggles `PenModel`. On: the button is tinted with the accent; the reader hides the tab bar (`.toolbarVisibility(.hidden, for: .tabBar)`) and shows a bottom toolbar (`placement: .bottomBar`): one button per `markup.colorChips` in order, each a filled circle in its color with the ringed one marked selected, in a horizontal scroll when they do not fit, then a spacer and a `checkmark` button labelled "Done". No add-color button.
- With the pen on, text selection by press-and-hold is off and `PhonePaintGesture` is on. It implements the rule and constants of Ruling 2, converts the touched span to a range, and on end calls `pen.paint(ReaderTextLogic.report(for: ReaderTextLogic.snapToWords(range)...))`. While the finger moves, the growing range is drawn in the pen's color.
- A painted or tapped mark is selected: outlined through `markup.outlinedHighlightID`, with a start and an end handle (accent, each at least a 44 pt target) that drag to resize through `resizeSelected`, and the edit menu presented under it with exactly: "Add Note" or "Edit Note", "Bookmark" or "Remove Bookmark", "Ask", "Delete". Delete calls `markup.deleteHighlight(id:)` and is undoable.
- Tapping a color while a mark is selected recolors it and becomes the pen color. Tapping elsewhere on the page deselects.
- The pen stays on across the chapter-end links and turns off when Library opens or the Read tab is left.
- VoiceOver: with VoiceOver running, the pen button is hidden; Task 11's path reaches every action.

- [x] **Step 1: Write the failing tests**

```swift
@Test func paintingAppliesThePenColorAndSelectsTheMark()
@Test func paintingNothingMakesNoHighlight() {             // Review Focus 3
    #expect(pen.paint(nil) == nil)
    #expect(markup.items.isEmpty)
}
@Test func choosingAColorRecolorsTheSelectedMarkAndIsRemembered()   // a new PenModel on the same defaults has the color
@Test func thePenStartsOnTheFirstColor()
@Test func turningOffClearsSelectionAndOutline()
@Test func resizingMovesTheHighlightAndCanBeUndone()       // MarkupModelTests: offsets and quotedText change; undo restores
@Test @MainActor func thePenColorStaysOnTheDevice()        // not in SyncedPreferences.keys
```

- [x] **Step 2: Run** them and see them fail; implement `updateRange`, `resizeHighlight` and `PenModel`; see them pass.
- [x] **Step 3: Build `PenBar`, `PhonePaintGesture`, the handles and the under-mark menu.**
- [x] **Step 4: Verify in the simulator:** pen on swaps the tab bar for the colors; a drag paints whole words in the ringed color; the menu appears under the mark; another color recolors it; a handle drag resizes it; Delete then undo restores it; Done brings the tab bar back; scrolling still works under Ruling 2's rule.
- [x] **Step 5: Run the full suite and commit** `feat: the pen`.

### Task 13: Notes over the page

**Files:**
- Create: `ScriptureUI/Phone/PhoneNoteTextEditor.swift`, `PhoneNoteSheet.swift`, `PhoneChapterNotesSheet.swift`
- Modify: `PhoneReaderScreen.swift`, `PhoneMarkupMenu.swift` (Add Note and Edit Note open the sheet)

**Rules:**
- `PhoneNoteTextEditor` is a `UIViewRepresentable` over `UITextView` giving the phone what `NoteTextEditor` gives the Mac: the body as markdown source, `MarkdownFormatting`'s bold, italic and list commands on a keyboard toolbar (`bold`, `italic`, `list.bullet`), and text in the tokens `DESIGN.md` names for the note editor.
- `PhoneNoteSheet(noteID:)` shows the reference, the quoted words on their highlight color, and the editor. It uses `markup.beginEditing(noteID:)`, `updateNoteBody` and `endEditing` as the Mac's column does, with detents medium and large and a trailing "Done". A swipe down saves; nothing is ever discarded.
- A note mark in the margin, Add Note, Edit Note and the pen's note action all set `shell.noteSheet`. Add Note uses `markup.addNote(to:)` first, as on the Mac.
- This task adds the first item to the reader's `ellipsis` menu, "Notes in This Chapter", which sets `shell.isChapterNotesShown`. Task 14 adds the rest.
- `PhoneChapterNotesSheet` lists `markup.columnItems` and `markup.chapterNotes` in the Mac column's rows (`NoteRowView`, `CompactHighlightRow`); tapping one scrolls the page to it and opens its note. Its empty state is the Mac column's.

- [x] **Step 1: Implement.**
- [x] **Step 2: Verify in the simulator:** tap the note mark at 15:4: the sheet rises to half height with the note; drag it up, type, apply bold, swipe down; reopen and the text is there. Add a note to a new selection. Open "Notes in This Chapter" from the menu and jump to a note.
- [x] **Step 3: Commit** `feat: notes in a sheet over the page`.

### Task 14: Library and the reader's menu

**Files:**
- Create: `ScriptureUI/Phone/PhoneLibraryScreen.swift`
- Modify: `PhoneReaderScreen.swift`

**Rules:**
- The Library button presents `PhoneLibraryScreen` as a full-screen cover: the Mac's `BookshelfView` and `ChapterGridView` in a `NavigationStack` with a "Close" button. Choosing a chapter calls `navigation.open` (reading, so it moves his place), turns the pen off, and dismisses.
- The `ellipsis` menu, top to bottom: a "Translation" submenu (a picker over `navigation.translations`, calling `setTranslation`), a "Text Size" control group (`textformat.size.smaller`, `textformat.size.larger`, stepping the reader's size setting through the range `ReaderSettings` allows), "Notes in This Chapter", "Read From Here" (shown only while `navigation.lookupReturn != nil`, calling `keepLookup()`), and "Settings".

- [x] **Step 1: Implement.**
- [x] **Step 2: Verify in the simulator:** Library opens the shelf; Psalms › 23 opens Psalm 23 and a relaunch returns there; the translation changes the text; text size steps and holds after relaunch.
- [x] **Step 3: Commit** `feat: Library and the reader's menu`.

### Task 15: The Notes tab

**Files:**
- Create: `ScriptureUI/Phone/PhoneMarkRow.swift`, `PhoneNotesScreen.swift`
- Modify: `PhoneRootView.swift`

**Interfaces:**
- Produces: `struct PhoneMarkRow: View { init(symbolName: String?, reference: String, date: Date?, quotedText: String, color: MarkupColor?, body: AttributedString?) }`, used here and by Task 17.

**Rules:**
- A `NavigationStack` titled "Notes" over a `List` of `notesBrowser.entries` (by `sections` when sorted by reference), plain style on `paper.page`.
- Above the list, three menus in a row: `timeFilter` ("How far back"), `filter` ("What kind"), `sort` ("Order"), each showing its current choice. A choice other than the default is drawn on `accent.wash`.
- `PhoneMarkRow`: the reference in headline weight at subheadline size, the date trailing in caption `ink.tertiary`, the quoted words in the serif italic on their highlight color (the mark fill tokens, so ink keeps 4.5:1), then up to two lines of the note in `ink.secondary`. No card, no fill; a hairline between rows.
- A row tap: for a note, highlight or bookmark, `MarkupNavigation.show(target, ...)` and `shell.showInReader()`; for a conversation, `assistant.open(threadID:)` and `shell.tab = .ask`.
- Swipe to delete calls `notesBrowser.delete(id:)`, undoable, no confirmation.
- A trailing `ellipsis` menu offers "Export Notes", which shares the markdown the Mac's exporter writes (`NotesExporter` and `MarkdownExport`) through the system share sheet, for the entries currently listed.
- The list reloads when the tab appears and when sync reloads the models.
- Empty states, one line each: with no marks at all, the Mac browser's sentence; with filters hiding everything, "Nothing in this range."

- [x] **Step 1: Implement.**
- [x] **Step 2: Verify in the simulator** with `-phoneSeed`: the four marks and the conversation are listed newest first with their colors; "Past week" keeps them and a kind filter narrows them; "Bible order" groups by book; after reading on to John 16, a tap on the 15:4 note opens John 15 at that verse and the reader's leading button reads "John 16" as the way back; swipe deletes and shake restores.
- [x] **Step 3: Commit** `feat: the Notes tab`.

### Task 16: The Ask tab

**Files:**
- Create: `ScriptureUI/Phone/PhoneAskScreen.swift`, `PhoneChatScreen.swift`
- Modify: `ScriptureUI/AssistantModel.swift`, `PhoneRootView.swift`, `PhoneReaderScreen.swift`
- Test: `Tests/ScriptureUITests/AssistantModelTests.swift`

**Interfaces:**
- Produces, on `AssistantModel`: `public private(set) var allThreads: [ChatThreadItem]` (every conversation, newest first, refreshed wherever `history` is) and `public func startNew(scope: ThreadScope)` (a new conversation with that scope pending, without showing the Mac's panel or its "Include where you are?" question).

**Rules:**
- `PhoneAskScreen`, a `NavigationStack` titled "Ask":
  - A tag reading "About \(assistant.chapterTitle)" with an `xmark` to remove it. With the tag, a new question is a `.chapter` conversation; without it, `.general`. The tag returns each time the tab is opened from a different chapter.
  - "Start with a prompt": `PromptTilesView` with `assistant.prompts`, shown only while the tag is on.
  - "Earlier conversations": `assistant.allThreads` as plain rows (the `sparkles` symbol in `ink.secondary`, the title, the reference and the date), swipe to delete through `deleteThread(id:)`.
  - The composer (`AssistantComposer`) sits above the tab bar in a `safeAreaInset`, focused when the tab appears with no conversation open.
- Sending a question or tapping a tile or a row pushes `PhoneChatScreen`: the conversation as `ChatTurnRow`s with the Mac's Copy and Add as Note, the model label, the notice row with Try Again, and the composer.
- A reference tapped in a reply sets `shell.versePreview`; the root shows `VersePreviewView(openTitle: "Open in Read")` as a sheet at the medium detent. Open in Read calls `navigation.lookUp(...)` and `shell.showInReader()`.
- `markup.onAskAboutPassage` (Ask in the selection menu and the pen menu) calls `assistant.ask(about:)` and presents `PhoneChatScreen` as a sheet over the page at the large detent. The conversation is in `allThreads` afterwards.

- [x] **Step 1: Write the failing tests**

```swift
@Test func allThreadsListsEveryChapterNewestFirst()       // threads in John 15 and Psalm 23, location set to John 15 -> both
@Test func startNewGeneralSendsNoPassage()                // after startNew(scope: .general) and send(), the request's text has no chapter text
@Test func startNewChapterUsesTheCurrentChapter()
```

- [x] **Step 2: Run** them, implement the model additions, see them pass.
- [x] **Step 3: Build the two screens and the wiring.**
- [x] **Step 4: Verify in the simulator:** the Ask tab opens with the keyboard up and the tag "About John 15"; tiles and the seeded conversation show as two different shapes; remove the tag, ask a question, and an answer streams if the simulator has the on-device model (if it does not, the unavailable notice shows here and streaming is checked on the phone in Task 19); in the seeded conversation, a reference in a reply opens the verse sheet and Open in Read shows the chapter with the way back. `PhoneSeed`'s conversation therefore includes one assistant reply containing "John 1:32" and "1 John 2:6". From the reader, select text and choose Ask: the conversation rises over the page.
- [x] **Step 5: Run the full suite and commit** `feat: the Ask tab`.

### Task 17: Search

**Files:**
- Create: `ScriptureUI/Phone/PhoneSearchScreen.swift`
- Modify: `PhoneRootView.swift`, `Apps/Shared/AppModels.swift` (iOS sets `navigation.searchLimits = .phone`, `includesCommandsInSearch = false`, and `markSearch`)

**Rules:**
- `.searchable(text: $navigation.paletteQuery, prompt: "Search")` on the `TabView`; the search tab's content is `PhoneSearchScreen`. Typing calls `updatePalette()` after a 150 ms pause.
- Before any text: one line in `ink.secondary`, "Search a reference like John 3:16, a book like Psalms, or a word in the text or your notes."
- With results: a row of chips, "All" then one per group present among "Marks" (`marksInPassage`), "Notes", "Asked", "Scripture", each with its `totalCount`; the chosen chip narrows with `results.only(_:)`.
- Each group has a header (its symbol, title and count) and its rows:
  - `goTo`, `books`, `translations`: the item's symbol, title and subtitle; the first `goTo` row sits on `accent.wash`.
  - `.mark`: `PhoneMarkRow` with the hit's symbol, the quoted words on their color, and the first line with `SearchRanker.matchRanges` in bold.
  - `.verse`: the reference, a dot in `verseColors[item.id]` when present, and the verse text in the serif with matches in bold.
  - A group cut by its limit ends with "Show all \(totalCount)", which selects that group's chip and raises that limit.
- A tap calls `navigation.select(item)`. Then: a conversation opens in the Ask tab; a translation stays in search; everything else calls `shell.showInReader()`. A `.reference` or `.book` moves his place; a mark or verse is a lookup (Task 7).
- No matches: the Mac palette's sentence, "No matches for “\(query)”".

- [x] **Step 1: Implement.**
- [x] **Step 2: Verify in the simulator** with `-phoneSeed`: "abide" shows Your notes (the 15:4 note with its color and "Abide" bold), Asked, then Scripture with a dot on John 15:4; "john 15" shows Go to, then "Your marks in John 15" in verse order; "ps" leads with Psalms; a mark opens the reader with the way back; `"` alone shows no results and no error. Screenshot both result layouts beside `search-and-ask-v2.html`.
- [x] **Step 3: Commit** `feat: search on the phone`.

### Task 18: Settings, backups, sharing, the keyboard

**Files:**
- Create: `ScriptureUI/Phone/PhoneSettingsScreen.swift`
- Modify: the settings views in `ScriptureUI` that do not yet compile or lay out for iOS, `Apps/iOS/.../ReadingThroughScriptureApp.swift`, `Apps/Shared/AppSync.swift`, `PhoneRootView.swift`

**Rules:**
- "Settings" in the reader's menu presents `PhoneSettingsScreen`, a `NavigationStack` with a `Form` reusing the existing views as sections or pushed pages: General (`GeneralSettingsView`, with the iCloud status row and the backup rows from `SyncSettingsSections`), Reading (`ReadingSettingsView`), Highlight Colors (`HighlightColorsSettingsView`), Prompts (`PromptTemplatesSettingsView`), Assistant (`AssistantSettingsView`). "Show in Finder" is absent on iOS; Restore stays.
- The daily backup runs on the phone as on the Mac (`AppSync.backUpIfNeeded()` when the scene becomes active).
- A hidden button with `.keyboardShortcut("k", modifiers: .command)` sets `shell.tab = .search`. ⌘[ and ⌘] call `goBack()` and `goForward()` in the reader.
- The share sheets from Tasks 11 and 15 are confirmed here on a device-sized simulator.

- [x] **Step 1: Implement.**
- [x] **Step 2: Verify in the simulator:** every settings page opens and scrolls; adding a highlight color makes it appear in the pen bar; with a hardware keyboard attached to the simulator, ⌘K opens search; a backup file exists under the app's Application Support `Backups` directory after launch.
- [x] **Step 3: Run the full suite, launch the Mac Debug app, commit** `feat: settings, backups and shortcuts on the phone`.

### Task 19: On Matt's phone, with sync

**Files:** Create `Scripts/install-phone.sh`; modify this plan (results), `README.md`.

- [x] **Step 1: Write `Scripts/install-phone.sh`.** It takes `debug` or `release`, builds the `ReadingThroughScripture-iOS` scheme for `generic/platform=iOS` with `-allowProvisioningUpdates -allowProvisioningDeviceRegistration`, and installs with `xcrun devicectl device install app`. With `release` it refuses to run unless `--go-live` is also given.
  - Result: the script builds with `-destination id=<device>` for the one paired iPhone (or an identifier given as the last argument) rather than `generic/platform=iOS`, because a generic build was given a provisioning profile without the phone. `release` refuses to run without `--go-live`.
- [x] **Step 2: Install Debug on the phone** and launch it. Expected: it opens; Settings › General shows the iCloud line as on the Mac's Debug build.
  - Result (2026-11-10, the owner's iPhone 17 Pro Max on iOS 27.0, beside the Mac's Debug build): Debug installed and launched. It opened to the chapter the Mac's Debug build was reading.
- [x] **Step 3: Run the Mac Debug build beside it** and check, with both apps open, recording each result here:
  - [x] A highlight made on the Mac appears on the phone within a minute, and one made on the phone appears on the Mac.
    - Result: passed.
  - [x] Reading on in a new chapter on one device, then bringing the other to the front, moves it to that chapter.
    - Result: passed. The reading place followed.
  - [x] A lookup on the phone (a Notes row in another chapter) does not move the Mac.
    - Result: passed for a reference into another chapter. A reference into the chapter already being read moved the saved verse (see the changes below).
  - [x] Changing the default translation on one arrives on the other.
    - Result: passed. The default translation arrived.
  - [x] The API key entered in the Mac's Debug build is present on the phone (Assistant settings shows the provider as configured) once iCloud Keychain has synced.
    - Result: passed. The API key was present on the phone.
- [x] **Step 4: Ask offline.** With "Answer with" set to Claude and the phone in Airplane Mode, ask a general question. Expected: an answer labelled "On-device · Claude unreachable".
  - Result: passed. With "Answer with" set to Claude and the phone in Airplane Mode, a general question was answered on-device and labelled so.
- [x] **Step 5: Matt uses it** for a chapter: read, pen, note, bookmark, search, ask. Record what he reports and fix what is a defect against the design.
  - Result: the owner used it and reported seven findings, and his lookup check raised two more points. What was done about each is listed below.
- [x] **Step 6: Commit** `feat: installing on the phone; cross-device checks recorded`.
  - Result: committed.

#### What Matt found, and what changed

1. A highlight on the first line of an indented paragraph (KJV Mark 1:18) was drawn shifted left by that line's indent on both apps. Both text controllers had left out the line's own offset. Fixed in both.
2. Punctuation at the end of a verse could not be selected. The phone's word snap trimmed it. Punctuation the selection covers now stays.
3. With the pen off, the selection menu led with a row of swatches and the actions were hard to reach. He chose one color chip at the start of the menu that opens the list of colors, with the actions beside it. The pen keeps its bottom color bar and stays on after a stroke, and a painted mark's menu has the same chip.
4. A system "Ask Siri" item appeared in the selection menu on iOS 27.0. Three guards in the text view did not remove it. A recording made on his phone showed why: the system adds the item after the app has returned its menu, it is in none of the hooks the app has, and the iOS 27.2 SDK has no public API for it. It stays. He accepted that, provided it sits last and displaces none of his actions (see the second round below).
5. He could not see around his finger. The system magnifier now shows while painting and while dragging the pen's handles.
6. The phone had no reading progress line. It now shows under the chapter title in the top bar, from the Mac's computation.
7. A chapter note was shown in full above verse 1 on the Mac. He chose a paper mark with the count inside it on the chapter heading's line, at the far right, on both apps. It opens the notes column on the Mac and "Notes in This Chapter" on the phone. The Mac's band is removed.
8. Lookups: a jump inside the chapter being read now shows the way back and keeps his place until he scrolls five lines from where it landed. Lookups into another chapter are unchanged. This replaces the earlier behaviour, where such a jump counted as reading.
9. References inside his own notes stay plain text. Only assistant replies have links. This was his decision, and it confirms the design's non-goal.

Not yet seen on a device: VoiceOver in the reader (the rotor's Select and Select All, the names of the menu's symbols, moving to an off-screen margin mark), ⌘K with a hardware keyboard, and the Restore menu.

#### His second round, and the whole-branch review

He tried the second build (2026-11-10) and asked for three more changes.

1. The selection menu shows its actions as symbols so more of them fit. The bar holds seven before its chevron and iOS 27 takes the last, so the app has six. On the phone the order is the color chip, note, Delete inside a highlight, bookmark, Ask, Copy, Copy with Reference, Share. A plain selection loses only Share to the chevron. Inside a highlight, Copy with Reference and Share go behind it. Each action keeps its name for VoiceOver and for the list behind the chevron.
2. The next-chapter link reads "Next: Zechariah 3 →", with the arrow after its text, on both apps.
3. Library on the phone is a list of books under an Old Testament and New Testament control. A book opens its chapters in place, one book at a time, and the book being read is open on arrival. A one-chapter book is marked on its row and opens directly. The Mac's shelf is unchanged.

The whole-branch review found nothing critical. Its fixes:

1. Opening a chapter note from "Notes in This Chapter" no longer scrolls the page or saves a new place. A row with a highlight is a jump with the way back.
2. A reference followed by a colon is a link, unless a digit follows the colon.
3. Search on the phone keeps the query when a result is opened. Marked verses are found from an index by chapter. "Show all" on Scripture stops at 500 verses and says so.
4. Returning from a lookup goes to where he last read on either device. Nothing moves while the lookup is showing.
5. A fresh install's Read tab says "Open Library to choose a chapter."
6. Tests added or changed on this branch clean up their scratch preferences. A helper for every suite is a later task.

Parked for a later task: VoiceOver marking in the reader, which has not been seen working on a device; search finding a conversation by words in the middle of it; one shared geometry for the two text controllers.

### Task 20: Accessibility, appearance and the docs

- [x] **Step 1: VoiceOver** in the simulator's Accessibility Inspector: every toolbar button, tab, row and margin mark has a label; a margin mark reads "Note, verse 4" or "Bookmark, verse 5"; marking is reachable without the pen.
- [x] **Step 2: Dynamic Type** at the largest accessibility size: no clipped chrome on Read, Notes, Ask, Search and Settings; the three Notes menus wrap or scroll.
- [x] **Step 3: Dark Mode and Increase Contrast** screenshots of the five screens; highlight fills keep primary ink at 4.5:1 (`PaletteTests` covers any new pairing).
- [x] **Step 4: Reduce Motion:** no custom animation remains.
- [x] **Step 5: Landscape:** each screen is usable.
- [x] **Step 6: `README.md`:** an "iPhone" section (building, the simulator, `Scripts/install-phone.sh`, the pen, the tabs, search, what stays per-device). Update `PRODUCT.md`'s Users line and the original spec's milestone 8 entry to say iPhone only, iPad later. Confirm `DESIGN.md` section 7 matches what was built.
- [x] **Step 7: Run the full suite and commit** `docs: the iPhone app`.

---

## Phase C: the Mac's palette

### Task 21: Grouped results in ⌘K

**Files:**
- Modify: `ScriptureUI/CommandPaletteView.swift`, `PaletteItem.swift`, `NavigationModel.swift`, `NotesBrowserModel.swift`; `Apps/Mac/ReadingThroughScripture/MainWindowView.swift` and `ReadingThroughScriptureApp.swift`; `DESIGN.md`
- Test: `Tests/ScriptureUITests/PaletteRankerTests.swift`, `NavigationModelTests.swift`, `NotesBrowserModelTests.swift`

**Rules:**
- `CommandPaletteView` takes `results: SearchResults` in place of `items`. It draws each group's header (`.caption` semibold in `ink.secondary`, the count trailing) and its rows. Selection, hover, the arrow keys and Return work over `results.flatItems` exactly as they do over `items` today, skipping headers.
- A `.mark` row: its symbol, the reference in semibold, the quoted words in the serif on their highlight color, the date trailing, and the first line beneath with matches bold. A `.verse` row: the reference, the dot from `verseColors`, the text beneath with matches bold. Other rows are unchanged.
- The field's placeholder becomes "Reference, book, translation, text, or your notes".
- Remove what Task 4 left in place: `PaletteItem.note`, `PaletteNoteHit`, `NavigationModel.noteSearch`, `NotesBrowserModel.noteHits`, and their tests. `PaletteNoteHit.firstLine(of:)` moves to `SearchMarkHit`.
- `DESIGN.md`: rewrite the ⌘K palette line and the Rows section to describe groups, the mark row and the verse dot.

- [x] **Step 1: Update the tests** for the removals and add: arrow-key selection crosses a group boundary; Return on a stale query re-ranks and takes the first row of the first group.
- [x] **Step 2: Implement.**
- [x] **Step 3: Verify on the Mac Debug build** beside the Mac panel in `search-and-ask-v2.html`: "abide" and a passage query, keyboard only.
- [x] **Step 4: Run the full suite and commit** `feat: grouped results and note colors in the palette`.

### Task 22: Go-live (only on Matt's word)

- [x] **Step 1: Ask Matt** whether to install the Release builds. Do nothing in this task without a yes.
  - Result (2026-11-11): Matt said to go live.
- [x] **Step 2: Mac first.** Run `Scripts/install-app.sh`. Launch. Expected: his notes are there, today's backup is taken, the new palette and time filter work.
  - Result (2026-11-11): `Scripts/install-app.sh` built the Release configuration from this branch at c44f99b and installed it in `/Applications`. It was the branch's first Release build and it succeeded. Before the install, the store's `Backups/` held 9 and 10 November. On launch the app took the day's backup, `2026-11-11.store`, 564 KB, the same size as the day before. Matt confirmed his notes were there and that the new palette and the time filter worked.
- [x] **Step 3: The phone.** Run `Scripts/install-phone.sh release --go-live`. Launch. Expected: after the first import his highlights, notes and conversations appear, and the app opens where the Mac is reading.
  - Result (2026-11-11): `Scripts/install-phone.sh release --go-live`, with the phone named because an Apple Watch was also listed as paired, built Release and installed it on the iPhone, signed with the team's development identity and the Release bundle ID. Matt opened it and his highlights, notes and conversations arrived.
- [x] **Step 4: Repeat Task 19 Step 3's first two checks** between the two Release builds and record them here.
  - Result (2026-11-11): between the two Release builds a highlight synced both ways and the reading place followed. Matt confirmed both.
- [x] **Step 5: Record go-live** in this plan and in `README.md`, and commit.
  - Result (2026-11-11): recorded here and in `README.md`.

After go-live the Debug build is still on the phone beside the Release one, with the same name and icon. The branch had not been merged to `main` when this was written. Not yet seen on a device: VoiceOver in the reader, ⌘K with a hardware keyboard, and the Restore menu on the phone.

---

## Self-review

- **Spec coverage.** 4.1 tab bar: Task 9. 4.2 Read, margin marks, chapter-end links, ⋯ menu: Tasks 10, 13, 14. 4.3 pen: Tasks 2, 12. 4.4 selection, Ask from a selection: Tasks 11, 16. 4.5 Notes tab and time filter: Tasks 3, 15. 4.6 Ask tab: Task 16. 4.7 references: Tasks 5, 16. 4.8 search: Tasks 4, 17. 4.9 settings, backups, share, keyboard: Tasks 11, 15, 18. 5.1 Mac palette: Tasks 4, 21. 5.2 Mac time filter: Task 3. 5.3: Task 5. 5.4 offline fallback: Task 6. 5.5 lookup rule: Task 7. Section 6 order and Debug-only: Phases and Global Constraints. Section 7 cross-device checks: Task 19. Section 8 risks 1 and 2: Task 1; risk 4: Task 2; risk 5: Tasks 8 and 10; risk 6: Tasks 9 and 17. Section 9 `DESIGN.md` iOS section and `SyncConfiguration` on iOS: Task 9. Section 10: Tasks 19, 20, 22.
- **Not planned, by the design:** iPad, Production, App Store, linking references inside notes, the milestone 7 minors backlog.
- **Order against the design.** Matt asked for the phone first. Phase A comes before the phone's screens because they are built on it, and each Phase A task also switches the feature on for the Mac because that is where it can be tested before an iOS target exists. Only the Mac palette's new look (Task 21) waits until after the phone.
