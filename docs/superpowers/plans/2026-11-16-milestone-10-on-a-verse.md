# Milestone 10, Project 3: On a Verse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From a selected verse, one action shows it beside itself in the reader's chosen translations, and one shows the passages it points to and the verses that point to it; the assistant can be asked about either with exactly what is on screen.

**Architecture:** Two pure models in ScriptureUI, `VerseComparison` and `CrossReferences`, hold every rule and are tested against the fixture database; the two panels are thin SwiftUI views over them.
- The Bible database (schema 4) gains one link table keyed by a verse number (book, chapter and verse in one integer), written by the importer from OpenBible.info's file, which a new fetch script pins by digest.
- A panel is asked for through one hook, `MarkupModel.onVersePanel`, which both selection menus and the Mac's C and R keys call. The Mac answers with a system popover anchored on the selection's first line; the iPhone with a sheet.
- The assistant's request carries its list of translations, so the on-device fallback composes the same ones.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit and UIKit with TextKit 2, GRDB with SQLite, SwiftData, Swift Testing, bash, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-16-milestone-10-on-a-verse-design.md`. Read it with this plan; section numbers below are the spec's.

Paths: `SUI` is `Packages/ScriptureKit/Sources/ScriptureUI`, `PH` is `SUI/Phone`, `SD` is `Packages/ScriptureKit/Sources/ScriptureData`, `IMP` is `Packages/ScriptureKit/Sources/BibleImporterCore`, `T` is `Packages/ScriptureKit/Tests/ScriptureUITests`, `TD` is `Packages/ScriptureKit/Tests/ScriptureDataTests`, `TI` is `Packages/ScriptureKit/Tests/BibleImporterCoreTests`, `MAC` is `Apps/Mac/ReadingThroughScripture`.

**Built on.** Project 1 (built): `ReaderKeyAction`, `ReaderKeyStroke`, `Shortcut`, `ShortcutCatalog`, `ReaderKeyCommands.perform`, `ChapterTextController.perform(_:)`, `MarkupMenuItem`, `MarkupContextMenu.make`, `PhoneMarkupMenu.phoneOrder`, `Credit`, `Credits.all`, `AboutView`. Project 2 (its plan, built before this one): `BibleSchema.version == 3`; `TD/Fixtures/EN/NT/JHN/WEB.json` and `KJV.json`; `theBuildScriptsPatternReadsTheSchemaVersion`; `PaletteCommand.all.count == 32`. If one of these differs when this plan is built, say so before going on.

**Checked against the code as built, 2026-11-17 (head `cc13b7f`).** Every name above exists as written. Line pointers and test code below were corrected where the code differs; the full check is `.superpowers/sdd/2026-11-16-milestone-10-on-a-verse/interface-check.md`. What the check changed that is more than a line number:
- The `T` fixtures are small: Matthew 1 to 6 in WEB and KJV at three to five verses a chapter (Matthew 5 is verses 1 to 5; WEB Matthew 3 is verses 1, 3 and "4-5"), Psalms 1 and 2 in both (two verses each), Psalms 118 (29 verses) and 119 in the KJV alone, Tobit 1:1-2 in WEB. Tasks 1, 5 and 9's `T` tests were rewritten to verses the fixture holds. The `TD` fixtures are as the plan says (all of Matthew in WEB, the Psalms in KJV alone, John in both, Tobit in WEB).
- In a file that imports SwiftUI, `Translation` is written `ScriptureData.Translation`.
- `VersePreviewView`'s init is `(preview:openTitle:onOpen:)`.
- `ReaderKeyAction.allCases.count` is 20 today and `Credits.all.count` is 15.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-10-study-tools`, on branch `milestone-10-study-tools`. Never push or merge.
- Git: `/usr/bin/git`, one git command per Bash call, no `cd … &&`, loops or shell variables.
- Every commit message ends with the attribution line the implementer's own session gives (pass it as a second `-m`).
- `rtk` shortens command output; use `rtk proxy <command>` when all of it is needed.

**Matt's data**
- Never touch the Release app, `Scripts/install-app.sh`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. Never build or run the Release configuration; read its settings with `-showBuildSettings` only.
- The `.dev` store gets no test notes. In the Mac Debug app and the simulator, never press 1 to 9, 0, N or B on a selection and never choose a colour, Add Note or Bookmark. Those are covered by tests and by Matt's own list. C and R write nothing and are safe.
- In the Mac Debug app never run Clear Recents. A page style, appearance, text size or compare set changed to look at something is put back.
- No test touches iCloud, the Keychain, the network or Matt's stores. The network is used only by `Scripts/fetch-crossrefs.sh` at build time.
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
- The stored note format and the iCloud schema do not change. One synced preference is added, `compareTranslationIDs`, and nothing else.
- Fixtures use public-domain text (WEB, KJV) and a small hand-made cross-reference file in the real format.

**UI rules (CLAUDE.md, DESIGN.md)**
- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change; use the `/impeccable-swift` skill for the two panels.
- Palette tokens only (`Color.inkSecondary`, `Color.accentWash`, `Color.assistant`); every new pairing goes in `PaletteTests`.
- Semantic text styles only; sizes tied to text are `@ScaledMetric`; spacing and radii are `AppSpacing` and `AppRadius` by name.
- Rows and never cards; no new shadow, no new material, no `.glassEffect()`. A popover is the system's, with no background of its own.
- UI copy keeps the app's American spelling ("No Color", "neighboring"), whatever the spec's prose uses. A reference is written as `Reference.displayString` writes it ("Galatians 5:22-23").

**Seeing the UI**
- Use the recipes in `docs/superpowers/specs/2026-11-13-milestone-9-handover.md`, "How to see the UI without stalling": the iOS Simulator control tool on the Debug simulator app; on the Mac, `screencapture -x -o -l<id>` of the Debug app's own window, in the background.
- AeroSpace may keep a window out of reach. Do not move Matt's windows; say what could not be seen.
- Pictures go in the session scratchpad. A temporary snapshot test is removed before committing.

## Review Focus

1. **A verse whose links all have fewer than four votes** (5,772 of the 29,318 verses with links). Its short list is empty. The reader expects the group's title, count and Show all, never "No cross-references". Task 5, `aGroupUnderFourVotesStillOffersItsLinks`. **(call)**
2. **A compare set that is empty, or names the translation being read or one this build lacks** (it arrives from another device). Only bundled translations show, the one being read shows once, an empty set shows it alone, and a name this build does not know survives a change to the set. Task 1, `theReadingTranslationLeadsThenTheSetInTheListsOrder`; Task 2, `theSetReadsBackAndKeepsWhatThisBuildDoesNotKnow`.
3. **A verse the translation joins to its neighbour** (the ERV has 237, "12-13"). Compared, or as a link's first verse, the joined verse answers for every verse it holds and shows its numbers. Task 1, `aCombinedVerseAnswersForEveryVerseItHolds` and `aCombinedVerseFillsItsRowWithItsNumbers`; Task 5, the last line of `pointsToIsInVoteOrderWithOpeningWords`.
4. **A link whose target holds its own verse** (66 in the data). The verse must not list itself under "Verses that point here". Task 5, `pointsHereFindsRangesThatHoldTheVerseAndNeverTheVerseItself`.
5. **A passage the translation being read lacks, or a verse outside the 66 books.** The row shows its reference with no words and is not a button; a verse of Tobit shows the one empty line and its chevrons still step. Task 5, `theShortListIsSixOfFourVotesOrMore`, `aVerseWithNoLinksSaysSoAndTheChevronsStopAtTheChaptersEnds`.

---

### Task 1: The verses in several translations, and the comparison (spec 4.1, 4.2, 4.4 Copy)

**Files:**
- Create: `SUI/VerseComparison.swift`
- Modify: `SD/BibleStore.swift` (beside `chapter`, `:65-81`), `SUI/NavigationModel.swift` (beside `versePreview`, `:59-63`), `TD/FixtureDatabase.swift` (`tinyStore`)
- Test: create `TD/BibleStoreVersesTests.swift` (package suite) and `T/VerseComparisonTests.swift` (both suites)

**Interfaces:**
- Consumes: nothing.
- Produces:

```swift
// BibleStore: one read. Keyed by translation, in verse order; a translation with none is absent.
public func verses(in location: ChapterLocation, verse: Int, endVerse: Int, translationIDs: [String]) throws -> [String: [Verse]]

public struct VerseComparison: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public let translationID: String
        public let isReading: Bool
        public let verses: [Verse]                       // empty: the translation lacks them
        public var id: String { get }                    // the translation
        public var canOpen: Bool { get }                 // has the verses
        /// Prose, poetry lines joined by a space. Verses carry their numbers ("3 … 4 …", "12-13 …")
        /// when the row holds more than one or a joined one; one plain verse carries none.
        public var text: String { get }
        public var missingLine: String? { get }          // "Not in the ERV."
        public var note: String? { get }                 // `note(translationID:book:)`
        public var accessibilityLabel: String { get }    // "KJV: …", "ESV, reading: …", "ERV: Not in the ERV."
    }
    public let reference: Reference                      // the verses shown: the selection's, five at most
    public let rows: [Row]
    public let cutLine: String?                          // "Showing the first 5 of 8 verses."
    public var countLabel: String { get }                // "5 translations", "1 translation": every row counts
    public var otherTranslationIDs: [String] { get }     // the rows after the first that have the verses: what Ask sends
    /// The verses shown as a selection, its quoted text the first row's words as Copy writes them.
    public var selection: TextSelection { get }
    /// Each row that has the verses as `TextSelection.copyWithReference` writes it, one to a line:
    /// the verses joined by a space, no numbers, no line breaks.
    public var copyText: String { get }
    /// Rows: the translation being read, then each of `compareSet` that is in `translations` and
    /// is not the one being read, in `translations`' order.
    public init(selection: TextSelection, readingTranslationID: String, compareSet: [String],
                translations: [Translation], verses: [String: [Verse]])
    public static func load(selection: TextSelection, readingTranslationID: String, compareSet: [String],
                            translations: [Translation], store: BibleStore) throws -> VerseComparison
    public static func note(translationID: String, book: String) -> String?
}
// NavigationModel, with its own translation, list and store; nil when the read fails
public func verseComparison(for selection: TextSelection, compareSet: [String]) -> VerseComparison?
```

The store's read, over the table `verse` (its unique index is `verse_lookup`): `WHERE translation_id IN (…) AND book_id = ? AND chapter = ? AND verse <= :endVerse AND coalesce(verse_end, verse) >= :verse ORDER BY translation_id, verse`.

The note is "The CPDV numbers the Psalms differently; this may be a neighboring verse.", for `CPDV` in `PSA` only. **(call)** The cut's line counts the selection's verses.

- [ ] **Step 1: Write the failing tests.** In `TD`, `store` is the new suite's own `private var store: BibleStore { get throws { try BibleStore(databaseURL: try FixtureDatabase.build()) } }` (the existing suites have it as a function, `TD/BibleStoreTests.swift:7`). `FixtureDatabase.tinyStore(_ verses:)` writes a database of its own with `BibleSchema.create`, the `meta` version row and the John 3 verse rows given (translation, verse, verse end). Task 5 adds its `links:` parameter, once Task 4 has made the table.

```swift
@Test func oneReadReturnsTheVersesInEachTranslationThatHasThem() throws {
    let john15 = ChapterLocation(book: "JHN", chapter: 15)
    let found = try store.verses(in: john15, verse: 4, endVerse: 5, translationIDs: ["KJV", "WEB", "ESV"])
    #expect(Set(found.keys) == ["KJV", "WEB"])                                   // the fixture has no ESV
    #expect(found["KJV"] == (try store.chapter(john15, translationID: "KJV")).filter { (4...5).contains($0.id.verse) })
    #expect(try store.verses(in: ChapterLocation(book: "MAT", chapter: 5), verse: 3, endVerse: 3, translationIDs: ["KJV", "WEB"]).keys.sorted() == ["WEB"])
    #expect(try store.verses(in: john15, verse: 4, endVerse: 5, translationIDs: []).isEmpty)
}

@Test func aCombinedVerseAnswersForEveryVerseItHolds() throws {
    let store = try FixtureDatabase.tinyStore([("ERV", 11, nil), ("ERV", 12, 13), ("KJV", 12, nil), ("KJV", 13, nil)])
    let found = try store.verses(in: ChapterLocation(book: "JHN", chapter: 3), verse: 13, endVerse: 13, translationIDs: ["ERV", "KJV"])
    #expect(found["ERV"]?.map(\.id.verse) == [12] && found["ERV"]?.first?.endVerse == 13 && found["KJV"]?.map(\.id.verse) == [13])
}
```

  In `T/VerseComparisonTests.swift` (the fixture has Matthew 5:1-5 and Psalms 1:1-2 in WEB and KJV, and all 29 verses of Psalm 118 in the KJV alone): `compare(_ book, _ chapter, _ verses: ClosedRange<Int>, reading:, set:)` calls `load` with `FixtureStore.make()` and the list `["AMP", "KJV", "NASB", "WEB"]`.

```swift
@Test func theReadingTranslationLeadsThenTheSetInTheListsOrder() throws {
    let c = try compare("MAT", 5, 3...3, reading: "WEB", set: ["WEB", "NASB", "KJV", "XYZ"])
    #expect(c.rows.map(\.translationID) == ["WEB", "KJV", "NASB"])       // the list's order; WEB once; XYZ is not bundled
    #expect(c.rows.map(\.isReading) == [true, false, false] && c.countLabel == "3 translations" && c.cutLine == nil)
    #expect(c.rows[1].text.hasPrefix("Blessed are the poor in spirit: for theirs"))     // one verse: no number
    #expect(c.rows[1].accessibilityLabel.hasPrefix("KJV: Blessed") && c.rows[0].accessibilityLabel.hasPrefix("WEB, reading: "))
    // A translation lacking the verse says so, cannot be opened, and is neither asked about nor copied.
    #expect(c.rows[2].missingLine == "Not in the NASB." && !c.rows[2].canOpen && c.rows[1].canOpen)
    #expect(c.otherTranslationIDs == ["KJV"] && c.copyText.components(separatedBy: "\n").count == 2)
    let alone = try compare("MAT", 5, 3...3, reading: "WEB", set: [])
    #expect(alone.rows.map(\.translationID) == ["WEB"] && alone.countLabel == "1 translation" && alone.otherTranslationIDs.isEmpty)
}

@Test func aRangeShowsEachVerseAndMoreThanFiveIsCutWithItsLine() throws {
    let psalm = try compare("PSA", 1, 1...2, reading: "KJV", set: ["WEB"])
    #expect(psalm.reference.displayString == "Psalm 1:1-2")
    #expect(psalm.rows.allSatisfy { $0.text.hasPrefix("1 ") && $0.text.contains(" 2 ") && !$0.text.contains("\n") })   // poetry runs together
    let c = try compare("PSA", 118, 3...12, reading: "KJV", set: ["WEB"])           // the fixture's one long chapter, in the KJV alone
    #expect(c.reference.displayString == "Psalm 118:3-7" && c.cutLine == "Showing the first 5 of 10 verses.")
    #expect(c.rows[0].verses.map(\.id.verse) == [3, 4, 5, 6, 7] && c.rows[1].missingLine == "Not in the WEB." && c.selection.endVerse == 7)
}

@Test func theCPDVsLineShowsInPsalmsOnlyAndCopyIsEveryRowWithItsReference() throws {
    #expect(VerseComparison.note(translationID: "CPDV", book: "PSA") == "The CPDV numbers the Psalms differently; this may be a neighboring verse.")
    #expect(VerseComparison.note(translationID: "CPDV", book: "JHN") == nil && VerseComparison.note(translationID: "KJV", book: "PSA") == nil)
    let lines = try compare("MAT", 5, 3...4, reading: "WEB", set: ["KJV"]).copyText.components(separatedBy: "\n")
    #expect(lines.count == 2 && lines[0].hasSuffix("\u{201D} \u{2014} Matthew 5:3-4 (WEB)"))
    #expect(lines[1].hasPrefix("\u{201C}Blessed are the poor in spirit: for theirs") && lines[1].hasSuffix("\u{201D} \u{2014} Matthew 5:3-4 (KJV)"))
    #expect(!lines[1].contains("4 Blessed"))                              // no verse numbers on the pasteboard
}

@Test func aCombinedVerseFillsItsRowWithItsNumbers() {
    let john3 = { VerseLocation(book: "JHN", chapter: 3, verse: $0) }
    let c = VerseComparison(selection: TextSelection(book: "JHN", chapter: 3, verse: 13, endVerse: 13, startOffset: 0, endOffset: 0, quotedText: ""),
                            readingTranslationID: "KJV", compareSet: ["ERV"], translations: ["ERV", "KJV"].map { Translation(id: $0, title: $0) },
                            verses: ["KJV": [Verse(id: john3(13), translationID: "KJV", text: "k", breakAfter: false)],
                                     "ERV": [Verse(id: john3(12), translationID: "ERV", endVerse: 13, text: "a\nb", breakAfter: false)]])
    #expect(c.rows.map(\.text) == ["k", "12-13 a b"])
}
```

- [ ] **Step 2: Run.** `--filter BibleStoreVersesTests` and `--filter VerseComparisonTests` FAIL to compile.
- [ ] **Step 3: Implement** the store call, `VerseComparison` and `NavigationModel.verseComparison`.
- [ ] **Step 4: Run.** Both suites pass.
- [ ] **Step 5: Commit.** `/usr/bin/git add` the files, then `/usr/bin/git commit -m "feat: a verse in several translations, and the comparison's rows (on a verse 4)" -m "<the session's attribution line>"`. Every later commit step has this shape.

---

### Task 2: The compare set and its checklist in Settings (spec 4.3)

**Files:**
- Create: `SUI/CompareSet.swift`
- Modify: `SUI/PreferenceSync.swift` (`SyncedPreferences.keys`, `:75-92`), `SUI/GeneralSettingsView.swift` (`:27-41`)
- Test: create `T/CompareSetTests.swift`; modify `T/PreferenceSyncTests.swift` (both suites)

**Interfaces:**
- Consumes: `VerseComparison.load` (Task 1).
- Produces:

```swift
/// One preference, the ids joined by commas, so `@AppStorage` and the key-value store take it as a string.
public enum CompareSet {
    public static let key = "compareTranslationIDs"
    public static let defaultValue = "ESV,NASB,KJV,WEB"
    public static func ids(_ raw: String) -> [String]                    // trimmed, no blanks or repeats, in order
    public static func ids(from defaults: UserDefaults) -> [String]      // `defaultValue` when the key is absent
    public static func toggling(_ id: String, in raw: String) -> String  // removed if there, else added last; the rest stays
}
/// One `Toggle` per translation, titled with its title, on `CompareSet.key` through `@AppStorage`.
/// A `Menu` draws each as a checkmark, a `Form` as a switch.
public struct CompareSetToggles: View { public init(translations: [ScriptureData.Translation]) }
```

A stored empty string is an empty set, not the default. **(call)** The checklist is its own section in Settings › General, "Compare with", directly under Translation on both apps, with the footer "Compare Translations shows these beside the translation you are reading."

- [ ] **Step 1: Write the failing tests.** `defaults` is a suite of its own, emptied; `matthew5v3` is a `TextSelection` of Matthew 5:3.

```swift
@Test func theSetReadsBackAndKeepsWhatThisBuildDoesNotKnow() {
    #expect(CompareSet.key == "compareTranslationIDs" && CompareSet.ids(from: defaults) == ["ESV", "NASB", "KJV", "WEB"])
    #expect(CompareSet.ids("") == [] && CompareSet.ids(" KJV, ,WEB,KJV ") == ["KJV", "WEB"])
    #expect(CompareSet.toggling("ASV", in: "ESV,KJV") == "ESV,KJV,ASV" && CompareSet.toggling("ESV", in: "ESV,KJV") == "KJV")
    #expect(CompareSet.toggling("KJV", in: "KJV") == "")                  // the last one can be unchecked
    #expect(CompareSet.toggling("WEB", in: "NLT,KJV") == "NLT,KJV,WEB")   // NLT, from another build, stays
}

@Test func changingTheSetChangesTheRowsAndIsSaved() throws {
    let store = try FixtureStore.make()
    func rows() throws -> [String] {
        try VerseComparison.load(selection: matthew5v3, readingTranslationID: "WEB", compareSet: CompareSet.ids(from: defaults),
                                 translations: store.translations(), store: store).rows.map(\.translationID)
    }
    #expect(try rows() == ["WEB", "KJV"])
    defaults.set(CompareSet.toggling("KJV", in: CompareSet.defaultValue), forKey: CompareSet.key)
    #expect(defaults.string(forKey: CompareSet.key) == "ESV,NASB,WEB" && (try rows()) == ["WEB"])
}
```

  In `PreferenceSyncTests.theSyncedKeysAreExactlyThese` (`:14-19`), add `"compareTranslationIDs"` to the expected list in its sorted place (after `"assistantProvider"`, before `"compatibleBaseURL"`).

- [ ] **Step 2: Run.** `--filter CompareSetTests` FAILS to compile; `PreferenceSyncTests` fails on the list.
- [ ] **Step 3: Implement** `CompareSet`, `CompareSetToggles`, the key in `SyncedPreferences.keys` and the Settings section.
- [ ] **Step 4: Run.** Both suites pass.
- [ ] **Step 5: Commit.** `feat: the compare set, one synced preference with its checklist in Settings (on a verse 4.3)`

---

### Task 3: The assistant takes the list of translations (spec 4.4)

**Files:**
- Modify: `SUI/StudyPromptComposer.swift` (`:29-41`), `SUI/AssistantModel.swift` (`runPrompt` `:331-341`, `Input` `:406-409`, `compose` `:709-719`, and the two other places that match `.template` by position, `:739` and `:763`)
- Test: `T/StudyPromptComposerTests.swift`, `T/AssistantModelTests.swift` (both suites)

**Interfaces:**
- Consumes: `BibleStore.verses(in:verse:endVerse:translationIDs:)` (Task 1), `CompareSet.ids(from:)` (Task 2).
- Produces:

```swift
// StudyPromptComposer, replacing the `excluding:` form: each of `translationIDs` that has the
// verses, in that order, at most `limit` of them; one store read.
public func otherTranslations(for location: ChapterLocation, verse: Int, endVerse: Int, translationIDs: [String], limit: Int?) throws -> String
// AssistantModel
/// Ask About the Differences: opens the panel on `selection` and sends the Compare translations
/// prompt as the reader has it, edited or hidden, with `translationIDs` as the other translations.
public func compareTranslations(_ selection: TextSelection, translationIDs: [String])
static func otherTranslationIDs(_ ids: [String], reading: String, compact: Bool) -> [String]   // without `reading`; three when compact
```

**How the list travels.** `Input.template` gains `otherTranslationIDs: [String]`, so the whole request and the compact one `submit` composes for the on-device fallback (`:450-451`) read the same list. `runPrompt` fills it from `CompareSet.ids(from: defaults)`, `compareTranslations` from its argument; `compose` passes `Self.otherTranslationIDs(ids, reading: translation, compact: compact)` to the composer with no further limit.

**The prompt Ask sends** is the stored template whose built-in key is `compare-translations`, enabled or not; if the store has none, `BuiltInPrompts.seed(key:)`'s title and body.

- [ ] **Step 1: Write the failing tests.** In `StudyPromptComposerTests`, `otherTranslationsListTheSameVersesUpToTheLimit` (`:24-29`) becomes:

```swift
@Test func otherTranslationsAreTheOnesNamedInTheirOrderUpToTheLimit() throws {
    let composer = StudyPromptComposer(store: try FixtureStore.make())
    func text(_ ids: [String], limit: Int? = nil) throws -> String {
        try composer.otherTranslations(for: ChapterLocation(book: "PSA", chapter: 1), verse: 1, endVerse: 2, translationIDs: ids, limit: limit)
    }
    let all = try text(["WEB", "ESV", "KJV"])
    #expect(all.hasPrefix("WEB\n1 ") && all.contains("\n\nKJV\n1 ") && !all.contains("ESV"))   // not in the fixture: left out
    let one = try text(["ESV", "KJV", "WEB"], limit: 1)
    #expect(one.hasPrefix("KJV\n1 ") && !one.contains("WEB\n") && (try text([])) == "")
}
```

  In `AssistantModelTests`:

```swift
@Test func thePromptFromTheAssistantsListSendsTheCompareSet() async throws {
    let provider = onDevice()
    let h = try make([provider])
    func run() async throws -> String {
        h.model.ask(about: blessed())
        h.model.runPrompt(templateID(h.model, "Compare translations"))
        try await settle(h.model)
        return try #require(provider.requests.last?.messages.last?.content)
    }
    h.defaults.set("NASB,KJV", forKey: CompareSet.key)
    let chosen = try await run()
    h.defaults.set("", forKey: CompareSet.key)
    let none = try await run()
    #expect(chosen.contains("\n\nKJV\n3 Blessed are the poor in spirit: for theirs") && !none.contains("KJV\n3 "))
}

@Test func askAboutTheDifferencesSendsExactlyTheRowsShownAndThreeOnDevice() async throws {
    let provider = onDevice()
    let h = try make([provider])
    h.defaults.set("", forKey: CompareSet.key)                           // the rows travel with the request, not the setting
    // The reader's own wording, hidden: through `h.templates`, the stored compare-translations
    // template's body set to "Only this: {{other_translations}}" and the template disabled.
    h.model.reloadTemplates()
    h.model.compareTranslations(blessed().selection, translationIDs: ["KJV"])
    try await settle(h.model)
    #expect(provider.requests.last?.messages.last?.content.hasPrefix("Only this: KJV\n3 Blessed are the poor in spirit") == true)
    #expect(h.model.messages[0].displayText == "Compare translations" && h.model.isPanelShown && h.model.thread?.scope == .selection)
    let shown = ["ESV", "NASB", "KJV", "WEB", "AMP"]
    #expect(AssistantModel.otherTranslationIDs(shown, reading: "ESV", compact: true) == ["NASB", "KJV", "WEB"])
    #expect(AssistantModel.otherTranslationIDs(shown, reading: "ESV", compact: false) == ["NASB", "KJV", "WEB", "AMP"])
}
```

- [ ] **Step 2: Run.** Both filters FAIL to compile.
- [ ] **Step 3: Implement.** `compareTranslations` starts the pending selection conversation as `ask(about:)` does, then submits the template.
- [ ] **Step 4: Run.** Both suites pass; `compareTranslationsListsAtMostThreeOnDevice` (`:313`) passes unchanged, since the default set holds KJV.
- [ ] **Step 5: Commit.** `feat: the assistant compares the reader's own set, and exactly the rows shown (on a verse 4.4)`

---

### Task 4: The fetch script, the importer and schema 4 (spec 5.4)

Two red-green cycles, one commit each: the table and its importer against the fixture file (A), then the real file and the real database (B).

**The data, measured** (`cross_references.txt`, header `#www.openbible.info CC-BY 2026-09-21`):
- SHA-256 of the text: `d18f0cdee1fd9a0bb289e0c30154485857b396124f68fe0dcc37aaa5982644f8` (8,302,424 bytes). Of OpenBible's `cross-references.zip` as fetched 2026-09-25: `83e9db0a08054ed99848531512729f0190dbbac85416f408f2362b5dc36d421d`.
- 344,799 links; 3,517 have a vote of zero or less, so 341,282 are kept. No source is a range and no pair repeats.
- Kept targets: 253,842 single verses, 86,791 ranges inside a chapter, 631 running into a later chapter of the book (one as far as six on) and 18 into the next book: 649 of the spec's 655.
- Five lines name `3John.1.15`; read as 1:14 they collide with nothing. Every verse named is in the bundled KJV.
- 66 links' targets hold their own source. John 3:16 points to 23 passages (all at four votes or more); 104 verses point to it (73 at four or more).

**The layout: measured, then chosen.** A verse is one integer, `Book.order × 1,000,000 + chapter × 1,000 + verse` (John 3:16 is 43003016). It needs no join to read, sorts in canon order, and makes "a range holds this verse" two comparisons, across chapters and books alike.

| Layout | Added to the 69,177,344-byte database |
|---|---|
| A row-id table and two indexes | 18.5 MB |
| The chosen table with the votes in the target's index | 14.1 MB |
| **`WITHOUT ROWID`, the source leading the key, an index on the target, a partial index on the 649** | **13,430,784 bytes (13.4 MB): 82,608,128 in all** |

```sql
CREATE TABLE cross_reference (
    source INTEGER NOT NULL, target_start INTEGER NOT NULL, target_end INTEGER NOT NULL, votes INTEGER NOT NULL,
    PRIMARY KEY (source, target_start, target_end)
) WITHOUT ROWID;
CREATE INDEX cross_reference_target ON cross_reference(target_start, target_end);
CREATE INDEX cross_reference_spanning ON cross_reference(target_end) WHERE target_end / 1000 > target_start / 1000;
```

**Files:**
- Create: `Scripts/fetch-crossrefs.sh`, `SD/VerseKey.swift`, `IMP/CrossReferenceFile.swift`, `TI/Fixtures/CrossRefs/cross_references.txt`
- Modify: `SD/BibleSchema.swift`, `IMP/BibleDatabaseWriter.swift`, `Packages/ScriptureKit/Sources/bible-importer/main.swift`, `Scripts/build-bible.sh` (`:14-19`)
- Test: create `TI/CrossReferenceFileTests.swift`; modify `TI/BibleDatabaseWriterTests.swift`, `TD/BibleStoreTests.swift` (package suite)

**Interfaces:**
- Consumes: project 2's schema 3 and importer.
- Produces:

```swift
public enum VerseKey {                                           // SD
    public static func key(_ verse: VerseLocation) -> Int?      // nil for a book `BookCatalog` does not know
    public static func location(_ key: Int) -> VerseLocation?   // nil when no book has that order
}
// BibleSchema: `version` is 4; `create` adds the table and its two indexes.
public struct CrossReferenceLink: Equatable, Sendable { public let source: Int, targetStart: Int, targetEnd: Int, votes: Int }
public enum CrossReferenceFile {                                 // IMP
    static let books: [String: String]                           // OpenBible's names to book codes: the 66
    /// The links of at least one vote, in file order. The header and blank lines are passed over;
    /// `3John.1.15` is 1:14; a line that does not parse (not three columns, a book not among the
    /// 66, no verse, votes not a number, a range ending before it starts) is left out with a warning.
    public static func parse(_ text: String, warnings: inout [ImportWarning]) -> [CrossReferenceLink]
}
// BibleDatabaseWriter.importAll gains `crossReferences: URL? = nil`; ImportReport gains `crossReferenceCount`.
```

- `books`, in the file's names and canon order: Gen Exod Lev Num Deut Josh Judg Ruth 1Sam 2Sam 1Kgs 2Kgs 1Chr 2Chr Ezra Neh Esth Job Ps Prov Eccl Song Isa Jer Lam Ezek Dan Hos Joel Amos Obad Jonah Mic Nah Hab Zeph Hag Zech Mal Matt Mark Luke John Acts Rom 1Cor 2Cor Gal Eph Phil Col 1Thess 2Thess 1Tim 2Tim Titus Phlm Heb Jas 1Pet 2Pet 1John 2John 3John Jude Rev.
- With the file, `importAll` inserts the links in one transaction before the `VACUUM`, and writes the meta row `crossrefs_sha256` from `<file>.sha256` beside it ("unknown" without one), as the eBible digests are (read at `:92-99`, written at `:106-109`; the `VACUUM` is `:111-113`). The CLI takes `--crossrefs <file>`.
- **The script**, modelled on `fetch-ebible.sh`: the cache is `~/Library/Caches/ReadingThroughScripture/crossrefs/<the digest's first 12>/`, holding the text, its `.sha256` and `.complete`; it prints that folder and is a no-op when complete. It downloads `https://a.openbible.info/data/cross-references.zip`, unzips it and checks the text's digest: the text is what is imported, and its digest is the same whichever archive carried it.
- **(call)** OpenBible replaces the file a few times a year. On a failed download or another digest the script tries `https://raw.githubusercontent.com/trekhleb/bible-cross-references/master/data/raw/openbible-cross-references.zip`, which keeps the unmodified 2026-09-21 file (spec 3), under the same check. If neither gives the pinned text it stops: "OpenBible changed cross_references.txt; check it and re-pin the digest in fetch-crossrefs.sh".
- `build-bible.sh` runs the script and passes `--crossrefs "<folder>/cross_references.txt"`.

**The fixture file**, tab-separated; Task 5 copies it to the two other test targets. Twenty of its twenty-two links are kept.

```
From Verse	To Verse	Votes	#www.openbible.info CC-BY 2026-09-21
Matt.5.3	Ps.1.1	12
Matt.5.3	Matt.6.19-Matt.6.21	9
Matt.5.3	Ps.2.12	7
Matt.5.3	Matt.5.10	6
Matt.5.3	Matt.4.17	5
Matt.5.3	Matt.3.2	4
Matt.5.3	Matt.6.33	4
Matt.5.3	Isa.57.15	3
Matt.5.3	Matt.5.47-Matt.6.4	2
Matt.5.3	Luke.6.20	1
Matt.5.3	Jas.2.5	0
Matt.5.3	Prov.16.19	-3
Matt.5.3	Matt.5.1-Matt.5.4	1
Ps.1.1	Matt.5.3	8
Matt.6.20	Matt.5.3-Matt.5.12	6
Ps.2.12	Matt.5.1-Matt.5.3	5
Matt.4.25	Matt.4.23-Matt.5.3	4
Matt.6.33	Matt.5.1-Matt.5.5	9
Matt.5.4	Matt.5.3	2
3John.1.15	Matt.5.3	2
Ps.1.6	3John.1.15	3
Mal.4.6	Mal.4.5-Matt.1.1	2
```

#### Cycle A: the table and the importer

- [ ] **Step 1: Write the failing tests.** In `TI/CrossReferenceFileTests.swift`, `header` is the fixture's first line with its newline; `links(_:)` parses `header + text` and expects no warning; `link` builds a `CrossReferenceLink`.

```swift
@Test func singleVersesRangesAndThirdJohnLandAsExpected() {
    #expect(links("Matt.5.3\tPs.1.1\t12") == [link(40005003, 19001001, 19001001, 12)])
    #expect(links("Matt.5.3\tMatt.6.19-Matt.6.21\t9") == [link(40005003, 40006019, 40006021, 9)])       // inside a chapter
    #expect(links("Matt.5.3\tMatt.5.47-Matt.6.4\t2") == [link(40005003, 40005047, 40006004, 2)])        // into the next chapter
    #expect(links("Mal.4.6\tMal.4.5-Matt.1.1\t2") == [link(39004006, 39004005, 40001001, 2)])           // into the next book
    #expect(links("3John.1.15\tMatt.5.3\t2\nPs.1.6\t3John.1.15\t3")
            == [link(64001014, 40005003, 40005003, 2), link(19001006, 64001014, 64001014, 3)])
    #expect(VerseKey.location(19119176) == VerseLocation(book: "PSA", chapter: 119, verse: 176) && VerseKey.location(99001001) == nil)
}

@Test func linksUnderOneVoteAndLinesThatDoNotParseAreLeftOut() {
    var warnings: [ImportWarning] = []
    let text = header + "Matt.5.3\tJas.2.5\t0\nMatt.5.3\tProv.16.19\t-3\n\nMatt.5.3\tTob.1.1\t5\nMatt.5\tPs.1.1\t5\n"
        + "Matt.5.3\tPs.1.1\tmany\nMatt.5.3\tPs.1.2-Ps.1.1\t5\r\nMatt.5.3\tLuke.6.20\t1\r\n"
    #expect(CrossReferenceFile.parse(text, warnings: &warnings) == [link(40005003, 42006020, 42006020, 1)])
    #expect(warnings.count == 4)                          // Tobit, no verse, no number, a range backwards; a low vote is no warning
    #expect(CrossReferenceFile.parse("<html>Not Found</html>\n", warnings: &warnings).isEmpty)
    #expect(Set(CrossReferenceFile.books.values) == Set(BookCatalog.all.filter { $0.order <= 66 }.map(\.id)))
}
```

  In `TI/BibleDatabaseWriterTests.swift`, a test that imports the fixtures with the fixture file and reads inside `q.read { db in … }`:

```swift
@Test func theFixtureLinksLandKeyedBothWaysAtSchemaFour() throws {
    #expect(report.crossReferenceCount == 20)
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM cross_reference WHERE votes >= 1") == 20)
    try #expect(Int.fetchOne(db, sql: "SELECT votes FROM cross_reference WHERE source = 40005003 AND target_start = 40005047 AND target_end = 40006004") == 2)
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM cross_reference WHERE 64001014 IN (source, target_end)") == 2)
    try #expect(Int.fetchOne(db, sql: "SELECT count(*) FROM cross_reference WHERE 64001015 IN (source, target_end)") == 0)
    try #expect(Set(String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'cross_reference' AND name NOT LIKE 'sqlite_%'"))
                == ["cross_reference_target", "cross_reference_spanning"])
    try #expect(String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'schema_version'") == "4")
}
```

  `importsFixturesIntoSQLite` (no file given) also expects the table empty. In `TD/BibleStoreTests.swift`, `theBuildScriptsPatternReadsTheSchemaVersion` expects 4; `schemaMismatchThrows` (an older database is refused, so the build script rebuilds it) stays.

- [ ] **Step 2: Run.** `--filter CrossReferenceFileTests` and `--filter BibleDatabaseWriterTests` FAIL to compile.
- [ ] **Step 3: Implement** `VerseKey`, the schema, the parser, the writer's parameter and the CLI's option.
- [ ] **Step 4: Run.** The package suite passes except the `.needsRealBible` tests, which wait for cycle B.
- [ ] **Step 5: Commit.** `feat: schema 4: a table of cross-references, imported from OpenBible's file (on a verse 5.4)`

#### Cycle B: the real file and the real database

- [ ] **Step 6: Write the script and wire `build-bible.sh`.** `bash Scripts/fetch-crossrefs.sh` prints the cache folder, and `shasum -a 256` of the text there is the pinned digest. Run again, it prints the folder at once. Note which address gave the file.
- [ ] **Step 7: Rebuild the database.** Note `wc -c Build/bible.sqlite`, then run `bash Scripts/ensure-bible.sh`: it rebuilds, since the file says 3 and the source 4.
  - `sqlite3 Build/bible.sqlite "SELECT value FROM meta WHERE key IN ('schema_version', 'crossrefs_sha256')"` prints `4` and the pinned digest.
  - `sqlite3 Build/bible.sqlite "SELECT count(*), sum(target_end / 1000 > target_start / 1000) FROM cross_reference"` prints `341282|649`.
  - `wc -c Build/bible.sqlite` is about 13.4 MB more than before; keep both figures for As built.
- [ ] **Step 8: Run.** The whole package suite passes, the `.needsRealBible` tests among them; then the iOS suite.
- [ ] **Step 9: Commit.** `build: fetch the pinned cross-references and build them into the Bible database (on a verse 5.4)`

---

### Task 5: The links of a verse, and the cross-references model (spec 5.1, 5.2)

**The two lookups, measured** with `sqlite3` on a copy of the real database carrying the table, warm, for John 3:16 in the ESV with each row's opening words:

| Lookup | Time |
|---|---|
| Points to (23 rows), by the primary key | 0.1 to 0.3 ms of CPU; the timer reads 0.000 to 0.003 s |
| Points here (104 rows), the two statements below | 0.3 to 1.1 ms of CPU; 0.000 s warm, 0.018 s the first time, cold |
| Points here as one statement, the two conditions under `OR` and a `GROUP BY` | 27 ms: the planner scans the table |
| Points here as `target_start <= ? AND target_end >= ?` alone | 8 ms: every link into the book so far |
| The busiest chapters (Psalm 119:176, Revelation 22:21) | 2 ms or less |

So "points here" is two statements in one read, joined in Swift, never one with `OR`:

```sql
-- A range that starts in the verse's own chapter (`:chapter` is the key of its verse 0).
SELECT source, votes FROM cross_reference WHERE target_start BETWEEN :chapter AND :verse AND target_end >= :verse;
-- A range begun in an earlier chapter or book: only the 649 in the partial index are looked at.
SELECT source, votes FROM cross_reference WHERE target_end / 1000 > target_start / 1000 AND target_end >= :verse AND target_start < :chapter;
```

"Points to" is `WHERE source = :verse`. Both are ordered by votes, highest first, then by the other verse's key. A row's opening words are the text of the verse row holding its first verse in the translation asked for (`verse <= n ORDER BY verse DESC LIMIT 1`, kept when `coalesce(verse_end, verse) >= n`), read in the same `queue.read`.

**Files:**
- Create: `SD/CrossReference.swift`, `SUI/CrossReferences.swift`; `TD/Fixtures/CrossRefs/cross_references.txt` and `T/Fixtures/CrossRefs/cross_references.txt` (Task 4's file, copied: each test target bundles its own)
- Modify: `SD/BibleStore.swift`, `SUI/NavigationModel.swift`, `TD/FixtureDatabase.swift` (`:13-16`) and `T/FixtureStore.swift` (`:14-17`) (both pass `crossReferences:`)
- Test: create `TD/BibleStoreCrossReferenceTests.swift` (package suite), `T/CrossReferencesTests.swift` (both suites), `T/CrossReferenceBenchmarkTests.swift` (`#if os(macOS)`: package suite)

**Interfaces:**
- Consumes: `VerseKey`, the table, `importAll(… crossReferences:)` (Task 4).
- Produces:

```swift
public struct CrossReference: Hashable, Sendable {             // SD
    public let source: VerseLocation
    public let target: VerseLocation, targetEnd: VerseLocation // the same verse for a single one
    public let votes: Int
    /// The row's own verse in the translation asked for: the target's first verse for a link
    /// out, the source for a link in. Nil when the translation lacks it.
    public let openingText: String?
    /// For a target that runs past its first chapter: that chapter's last verse in the
    /// translation asked for (nil when it lacks the chapter). Nil for every other link.
    public let chapterEnd: Int?
    public init(source: VerseLocation, target: VerseLocation, targetEnd: VerseLocation, votes: Int, openingText: String?, chapterEnd: Int?)
}
// BibleStore
public func crossReferences(from verse: VerseLocation, translationID: String) throws -> [CrossReference]
public func crossReferences(to verse: VerseLocation, translationID: String) throws -> [CrossReference]   // never the verse itself

public struct CrossReferences: Equatable, Sendable {           // SUI
    public struct Row: Identifiable, Hashable, Sendable {
        /// One chapter: a link out's target, cut to its first chapter's part when it runs on
        /// (to `chapterEnd`; the single verse without one, or when the chapter ends before it); a link in's source.
        public let reference: Reference
        init(pointingTo link: CrossReference)        // a link out: its target, cut as above
        init(pointingHere link: CrossReference)      // a link in: its source
        public let opening: String?                  // the opening text as one line
        public let votes: Int                        // orders the lists; never shown
        public var id: String { get }                // the reference and the votes
        public var canOpen: Bool { get }             // has opening words
        public var accessibilityLabel: String { get }   // "Psalm 1:1, Blessed is the man…"; the reference alone without words
    }
    public struct Group: Equatable, Sendable {
        public let all: [Row]                        // every link kept, strongest first
        public var short: [Row] { get }              // the first six of those with at least four votes
        public var count: Int { get }
        public var showsShowAll: Bool { get }        // `all` holds more than `short`
        public var showAllTitle: String { get }      // "Show all (11)"
    }
    public static let pointsToTitle = "This verse points to", pointsHereTitle = "Verses that point here"
    public static let emptyLine = "No cross-references for this verse."
    public let verse: VerseLocation
    public let translationID: String
    public let reference: Reference
    public let pointsTo: Group, pointsHere: Group
    /// The verse rows before and after this one in its chapter, in the translation being read; nil at its ends.
    public let previous: VerseLocation?, next: VerseLocation?
    public var isEmpty: Bool { get }                 // neither group has a link
    public static func load(_ verse: VerseLocation, translationID: String, store: BibleStore) throws -> CrossReferences
}
// NavigationModel; nil when the read fails
public func crossReferences(for verse: VerseLocation) -> CrossReferences?
```

- [ ] **Step 1: Copy the fixture file, pass it in the two fixture builders, and write the failing tests.** `FixtureDatabase.tinyStore` gains `links: [(Int, Int, Int, Int)] = []` (source, target start, target end, votes), written to `cross_reference`. In `TD` (all of Matthew in WEB, the Psalms in KJV alone, John in both); `store` is the suite's own throwing property as in Task 1; `mt`, `ps` and `at("ISA", 57, 15)` build `VerseLocation`s.

```swift
@Test func pointsToIsInVoteOrderWithOpeningWords() throws {
    let to = try store.crossReferences(from: mt(5, 3), translationID: "WEB")
    #expect(to.map(\.votes) == [12, 9, 7, 6, 5, 4, 4, 3, 2, 1, 1])
    #expect(to.map(\.target) == [ps(1, 1), mt(6, 19), ps(2, 12), mt(5, 10), mt(4, 17), mt(3, 2), mt(6, 33),
                                 at("ISA", 57, 15), mt(5, 47), mt(5, 1), at("LUK", 6, 20)])      // a tie goes in canon order
    #expect(to[1].targetEnd == mt(6, 21) && to[1].chapterEnd == nil)
    #expect(to[8].targetEnd == mt(6, 4) && to[8].chapterEnd == 48)                               // runs into chapter 6
    #expect(to[3].openingText == (try store.chapter((book: "MAT", chapter: 5), translationID: "WEB"))[9].text)
    #expect(to[0].openingText == nil && to[7].openingText == nil)                                // no Psalms or Isaiah in this WEB
    let joined = try FixtureDatabase.tinyStore([("ERV", 12, 13)], links: [(43003001, 43003013, 43003013, 5)])
    #expect(try joined.crossReferences(from: VerseLocation(book: "JHN", chapter: 3, verse: 1), translationID: "ERV").first?.openingText != nil)
}

@Test func pointsHereFindsRangesThatHoldTheVerseAndNeverTheVerseItself() throws {
    let here = try store.crossReferences(to: mt(5, 3), translationID: "WEB")
    #expect(here.map(\.source) == [mt(6, 33), ps(1, 1), mt(6, 20), ps(2, 12), mt(4, 25), mt(5, 4), at("3JN", 1, 14)])
    #expect(here.map(\.votes) == [9, 8, 6, 5, 4, 2, 2])                  // Matthew 5:3's own 5:1-4 is not among them
    #expect(try store.crossReferences(to: mt(1, 1), translationID: "WEB").map(\.source) == [at("MAL", 4, 6)])   // begun in another book
    #expect(try store.crossReferences(to: mt(5, 1), translationID: "WEB").map(\.source) == [mt(6, 33), ps(2, 12), mt(4, 25), mt(5, 3)])
    #expect(try store.crossReferences(to: mt(5, 20), translationID: "WEB").isEmpty)
    #expect(try store.crossReferences(from: at("TOB", 1, 1), translationID: "WEB").isEmpty)
}
```

  In `T/CrossReferencesTests.swift` (this fixture's Matthew 5 is verses 1 to 5, its Psalms 1 and 2 two verses each, in WEB and KJV; it has Tobit 1:1-2 in WEB); `load(_:)` reads in WEB; `names(_:)` maps rows to `reference.displayString`.

```swift
@Test func theShortListIsSixOfFourVotesOrMore() throws {
    let x = try load(mt(5, 3))
    #expect(names(x.pointsTo.short) == ["Psalm 1:1", "Matthew 6:19-21", "Psalm 2:12", "Matthew 5:10", "Matthew 4:17", "Matthew 3:2"])
    #expect(x.pointsTo.count == 11 && x.pointsTo.showAllTitle == "Show all (11)")
    // This fixture's Matthew 5 ends at verse 5, before the target's first verse: the single verse.
    #expect(names(Array(x.pointsTo.all.suffix(5))) == ["Matthew 6:33", "Isaiah 57:15", "Matthew 5:47", "Matthew 5:1-4", "Luke 6:20"])
    let runsOn = CrossReference(source: mt(5, 3), target: mt(5, 47), targetEnd: mt(6, 4), votes: 2, openingText: "x", chapterEnd: 48)
    #expect(CrossReferences.Row(pointingTo: runsOn).reference.displayString == "Matthew 5:47-48")    // cut to its first chapter's part
    #expect(names(x.pointsHere.short) == ["Matthew 6:33", "Psalm 1:1", "Matthew 6:20", "Psalm 2:12", "Matthew 4:25"])
    #expect(x.pointsHere.count == 7 && names(x.pointsHere.all).last == "3 John 1:14")
    let first = x.pointsTo.short[0], isaiah = x.pointsTo.all[7]
    #expect(first.canOpen && first.opening?.contains("\n") == false && first.accessibilityLabel == "Psalm 1:1, \(first.opening ?? "")")
    #expect(isaiah.opening == nil && !isaiah.canOpen && isaiah.accessibilityLabel == "Isaiah 57:15")
}

@Test func aGroupUnderFourVotesStillOffersItsLinks() throws {
    let x = try load(mt(5, 4))
    #expect(x.pointsTo.short.isEmpty && x.pointsTo.count == 1 && x.pointsTo.showsShowAll && !x.isEmpty)
    #expect(names(x.pointsHere.all) == ["Matthew 6:33", "Matthew 6:20", "Matthew 5:3"] && x.pointsHere.short.count == 2)
    #expect(try !load(mt(6, 20)).pointsTo.showsShowAll)                  // one link at six votes: nothing more to show
}

@Test func aVerseWithNoLinksSaysSoAndTheChevronsStopAtTheChaptersEnds() throws {
    #expect(try load(mt(5, 20)).isEmpty && CrossReferences.emptyLine == "No cross-references for this verse.")
    let three = try load(mt(5, 3))
    #expect(three.previous == mt(5, 2) && three.next == mt(5, 4))
    #expect(try load(mt(5, 1)).previous == nil && load(mt(5, 5)).next == nil)     // this fixture's Matthew 5 is verses 1 to 5
    let tobit = try load(VerseLocation(book: "TOB", chapter: 1, verse: 1))   // the data covers the 66 books
    #expect(tobit.isEmpty && tobit.previous == nil && tobit.next != nil)
}
```

  In `T/CrossReferenceBenchmarkTests.swift`, a `@MainActor @Suite(.serialized)`:

```swift
/// Spec 10: both lists for John 3:16 within 20 ms, debug build.
@Test(.needsRealBible) func bothListsForJohn316AreWithinTwentyMilliseconds() throws {
    let store = try BenchmarkChapter.realStore()
    var lists: CrossReferences?
    let median = ReaderBenchmarkTests.median("crossrefs-JHN-3-16-ESV") {
        lists = try? CrossReferences.load(VerseLocation(book: "JHN", chapter: 3, verse: 16), translationID: "ESV", store: store)
    }
    #expect(lists?.pointsTo.count == 23 && lists?.pointsHere.count == 104 && median < .milliseconds(20))
}
```

- [ ] **Step 2: Run.** The three filters FAIL to compile.
- [ ] **Step 3: Implement** the two store calls as measured, `CrossReferences` and `NavigationModel.crossReferences(for:)`.
- [ ] **Step 4: Run.** Both suites pass. Keep the benchmark's printed median for As built.
- [ ] **Step 5: Commit.** `feat: what a verse points to and what points to it, strongest first (on a verse 5.1, 5.2)`

---

### Task 6: The two menu items and the C and R keys (spec 4.1, 5.1, 6)

**Files:**
- Create: `SUI/VersePanel.swift`
- Modify: `SUI/NotesColumnItem.swift` (`MarkupMenuItem`, `:81-96`), `SUI/MarkupModel.swift` (`:63`, `menuItems` `:448-461`), `SUI/MarkupContextMenu.swift`, `PH/PhoneMarkupMenu.swift` (`make`, `phoneOrder` `:115-130`), `SUI/ShortcutCatalog.swift` (`:4-17`, the `bookmark` row `:99-100`), `SUI/ChapterTextController+Keys.swift` (`actsOnMarkup` `:31-36`, `perform` `:71-73`), `SUI/ReaderKeyCommands.swift` (`perform` `:18-45`; its switch has no default)
- Test: create `T/VersePanelTests.swift`; modify `T/MarkupModelTests.swift`, `T/ShortcutCatalogTests.swift` (both suites), `T/ReaderKeyTests.swift` (package suite), `T/PhoneMarkupMenuTests.swift` (iOS suite)

**Interfaces:**
- Consumes: project 1's key handling and menus.
- Produces:

```swift
public enum VersePanelKind: String, Sendable {
    case compare, crossReferences
    public var title: String { get }         // "Compare Translations", "Cross-References"
    public var symbolName: String { get }    // "rectangle.split.2x1", "arrow.triangle.branch"
}
/// One asking for a panel: which, the verses selected, and the characters they were (the Mac's anchor).
public struct VersePanelRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: VersePanelKind
    public let selection: TextSelection
    public let range: NSRange
    public init(kind: VersePanelKind, report: SelectionReport)
    public var verse: VerseLocation { get }  // the selection's first verse
}
// MarkupMenuItem gains `case compareTranslations` and `case crossReferences`.
// MarkupModel: the app sets it. While nil the two items are disabled and C and R do nothing.
public var onVersePanel: ((VersePanelKind, SelectionReport) -> Void)?
// ReaderKeyAction gains `case compareTranslations, crossReferences`, listed in `allCases` after `.bookmark`.
```

- `menuItems(for:)` puts the two after `.bookmark` and before `.copy`: on the Mac they close the first group, above Copy's separator.
- `phoneOrder` ranks them after `.copyWithReference` and before `.copyLink`: first behind the chevron, the bar's six symbols as they were.
- Neither menu collapses the selection: the Mac's popover hangs from it.
- The catalogue's Verses group gains two rows after `bookmark`: `compareTranslations`, "Compare translations", key and chord `C`; `crossReferences`, "Cross-references", key and chord `R`; each spoken as its letter, with its reader key (`c`, `r`, no Shift).
- In `ChapterTextController.perform` the two join `.color, .noColor, .note, .bookmark` (`:71`): without a selection nothing happens. `ReaderKeyCommands.perform` calls `markup.onVersePanel?`.
- A held C or R acts once: each repeat would ask for a new panel. `keyDown` drops repeats for the actions in `ReaderKeyAction.actsOnMarkup` (`SUI/ChapterTextController.swift:1715`); the two join that rule, and `ReaderKeyTests` pins it beside the existing held-key test.
- Neither is a palette command: `PaletteCommand` is untouched.

- [ ] **Step 1: Write the failing tests.** In `T/VersePanelTests.swift`:

```swift
@Test func theTwoPanelsAreNamedAndTheirSymbolsAreInTheSystemSet() {
    #expect(VersePanelKind.compare.title == "Compare Translations" && VersePanelKind.crossReferences.title == "Cross-References")
    #expect(VersePanelKind.compare.symbolName == "rectangle.split.2x1" && VersePanelKind.crossReferences.symbolName == "arrow.triangle.branch")
    for kind in [VersePanelKind.compare, .crossReferences] {
        #if os(macOS)
        #expect(NSImage(systemSymbolName: kind.symbolName, accessibilityDescription: nil) != nil, "\(kind.symbolName)")
        #else
        #expect(UIImage(systemName: kind.symbolName) != nil, "\(kind.symbolName)")
        #endif
    }
}
```

  In `MarkupModelTests`, built as `copyLinkFollowsCopyWithReferenceAndNamesTheVersesAlone` (`:110`) builds its own. The existing `menuOffersRecolorAndRemoveInsideASingleHighlight` (`:104`) expects `items[6...]` to begin with `.copy`; it now begins `[.compareTranslations, .crossReferences, .copy, …]`.

```swift
@Test func compareAndCrossReferencesFollowTheBookmarkAndComeBeforeCopy() throws {
    let (model, _) = try makeModel()
    let items = model.menuItems(for: report(model, verse: 2, 0, 3, text: "For"))
    let bookmark = try #require(items.firstIndex { if case .bookmark = $0 { true } else { false } })
    #expect(Array(items[(bookmark + 1)...(bookmark + 3)]) == [.compareTranslations, .crossReferences, .copy])
}
```

  In `ShortcutCatalogTests`, `everyReaderKeyActionIsListedAndNoKeyTwice` expects 22 cases (20 today, `:16`), and the "Reserved for project 3" line (`:53-54`) becomes:

```swift
#expect(action(.character("c")) == .compareTranslations && action(.character("r")) == .crossReferences)
#expect(action(.character("c"), shift: true) == nil && action(.character("r"), shift: true) == nil)
let verses = ShortcutCatalog.groups.first { $0.id == "verses" }?.shortcuts ?? []
#expect(verses.map(\.id).contains(["bookmark", "compareTranslations", "crossReferences", "copy"]))
#expect(verses.first { $0.id == "crossReferences" }?.accessibilityLabel == "Cross-references: R")
```

  In `ReaderKeyTests`, with the suite's own `model` (its `MarkupModel`, `:17`), `controller` and `press`:

```swift
@Test func cAndROpenTheirPanelsWithASelectionAndDoNothingWithoutOne() throws {
    var asked: [VersePanelKind] = []
    model.onVersePanel = { kind, _ in asked.append(kind) }
    press("c")
    press("r")
    #expect(asked.isEmpty)                                               // nothing selected
    press("j")
    press("c")
    press("r")
    #expect(asked == [.compare, .crossReferences] && controller.textView.selectedRange().length > 0)   // the selection stays
    let titles = MarkupContextMenu.make(for: try #require(controller.reportForAction()), model: model, controller: controller).items.map(\.title)
    let bookmark = try #require(titles.firstIndex { $0.hasPrefix("Bookmark Verse") })
    #expect(Array(titles[(bookmark + 1)...(bookmark + 4)]) == ["Compare Translations", "Cross-References", "", "Copy"])
}
```

  In `PhoneMarkupMenuTests.copyLinkSitsAfterCopyWithReferenceBehindTheChevron` (`:33-34`), "Compare Translations" and "Cross-References" stand between "Copy with Reference" and "Copy Link".

- [ ] **Step 2: Run.** The package suite's four filters FAIL to compile; the iOS `PhoneMarkupMenuTests` fails on the names.
- [ ] **Step 3: Implement.** Both menus build the two items from `VersePanelKind`'s title and symbol.
- [ ] **Step 4: Run.** Both suites pass; `PaletteCommandTests` still counts 32.
- [ ] **Step 5: Commit.** `feat: Compare Translations and Cross-References in both menus, and C and R (on a verse 6)`

---

### Task 7: The two panels, and the Mac's popover (spec 4.2, 5.2, 7)

**Files:**
- Create: `SUI/CompareTranslationsPanel.swift`, `SUI/CrossReferencesPanel.swift`, `SUI/ChapterTextController+VersePanel.swift` (`#if os(macOS)`)
- Modify: `SUI/ReaderView.swift` (a `versePanel` parameter, handed on: init `:100-136`, `ChapterTextView(` `:288-304`), `SUI/ChapterTextView.swift` (`:36`, `:85`), `MAC/MainWindowView.swift` (the `chapterKey` change `:157-167`, `ReaderView(` `:251-278`, `wireAssistant` `:421-442`)
- Test: `T/ReaderKeyTests.swift` (package suite), `T/NavigationModelTests.swift` (both suites)

**Interfaces:**
- Consumes: `NavigationModel.verseComparison` (Task 1); `CompareSet`, `CompareSetToggles` (Task 2); `AssistantModel.compareTranslations` (Task 3); `NavigationModel.crossReferences(for:)` (Task 5); `VersePanelRequest`, `onVersePanel` (Task 6); the existing `VersePreviewView`, `NavigationModel.versePreview(_:)` and `lookUp`.
- Produces:

```swift
/// The comparison of `selection`, read again when the compare set or the translation changes.
public struct CompareTranslationsPanel: View {
    public init(selection: TextSelection, navigation: NavigationModel,
                onOpen: @escaping (VerseComparison.Row) -> Void, onAsk: ((VerseComparison) -> Void)?)
}
/// The links of `verse`, which the chevrons move. `showsPassageInPlace` swaps the list for the
/// passage (the Mac's popover); without it `onShowPassage` is called (the phone pushes it).
public struct CrossReferencesPanel: View {
    public init(verse: VerseLocation, navigation: NavigationModel, showsPassageInPlace: Bool,
                onShowPassage: @escaping (Reference) -> Void = { _ in },
                onOpen: @escaping (Reference) -> Void, onAsk: ((CrossReferences) -> Void)?)
}
#if os(macOS)
public struct VersePanelPresentation {
    public let request: VersePanelRequest
    public let content: AnyView
    public let onClose: () -> Void
}
extension ChapterTextController {
    /// Shows the popover for a new request, closes it for nil, and leaves one already showing alone.
    func apply(_ presentation: VersePanelPresentation?)
    func versePanelAnchor(for range: NSRange) -> NSRect
    static func versePanelAnchor(firstSegment: NSRect?, visiblePage: NSRect) -> NSRect
}
#endif
```

**Anchoring.** The anchor is `frameOfFirstSegment(of:)` (`SUI/ChapterTextController.swift:910`, public): the first line of the selection in text-view coordinates, at the height of its glyphs, the rect a highlight is painted with. It is a few points shorter than the selection's own fill, which the Mac now paints from `selectionFills` (`:63`) at the full line height; the menu's Share already anchors on it (`MarkupContextMenu.swift:84`). `visiblePage` is the visible rect under the running head, as `keySelection()` builds it (`ChapterTextController+Keys.swift:97-98`). The static function gives:
- the first segment, when it meets the page;
- above the page, a strip 1 pt tall at the page's top edge over the segment's own x and width; below it, the same at the bottom edge;
- with no segment, a 1 pt square at the middle of the top edge.

The popover is an `NSPopover` with `behavior = .transient` (Esc or a click outside closes it). Its content is an `NSHostingController` of `content.followsSepia()`, sized by its content; `everyAppKitHostedSwiftUIRootFollowsSepia` reads source lines, so `NSHostingController(rootView: ….followsSepia())` stays on one line. It is shown `relativeTo:` the anchor `of: textView`, `preferredEdge: .maxY`: under the line, and AppKit takes another edge and keeps it on the screen when there is no room. Its delegate calls `onClose`. `ChapterTextView` applies the presentation in `updateNSView` as it applies `focusRequest`. **(call)** The chevrons do not move the popover.

**The panels** follow spec 4.2, 5.2 and 7 for every type style, token and string. What the spec leaves open:
- **Size:** 360 pt wide as a `@ScaledMetric` on the Mac; the rows in a `ScrollView` that grows to a scaled 480 pt. The phone's sheet gives no width.
- **Headers:** the reference in `.headline` with the header trait. Compare's count and its `cutLine` are `.caption` `ink.secondary`. The chevrons are `chevron.up` and `chevron.down`, plain buttons, disabled at the chapter's ends.
- **A compare row:** a plain button; "reading" follows the id in `.caption` `ink.secondary`; the wash is at radius `md`. A missing row is its line in `.callout` and is not a button. The verse is `pageFace.swiftUIFont(.callout)`.
- **A group:** title and count as the Label style with the header trait; then the short list; then `showAllTitle` as a plain button in `accent`, which swaps in `all`. A group with no link is left out; with neither, `emptyLine` in `.callout` `ink.secondary`.
- **A reference row** that cannot open is not a button. Both rows take their model's `accessibilityLabel`.
- **A passage in place (Mac):** the list gives way to "Cross-References" with `chevron.left`, then `VersePreviewView(preview:openTitle: "Open", onOpen:)`.
- **Feet:** Compare has "Ask About the Differences" (`sparkles`, `Color.assistant`; absent without `onAsk`, disabled when `otherTranslationIDs` is empty), "Copy" (`doc.on.doc`) and, trailing, `Menu("Translations…")` of `CompareSetToggles`. Cross-references' foot is Task 9's.
- **Pairing:** `ink.secondary` on `accent.wash` at 4.5:1 is already held (`T/PaletteTests.swift:46-50`), as are `accent` and `assistant` on the wash at 3:1 (`:68-71`); `PaletteTests` needs no change unless a panel pairs something else.

**The Mac's wiring** (`MainWindowView`): a `@State` `VersePanelRequest?`, set by `markup.onVersePanel` in `wireAssistant` and handed to `ReaderView` as a `VersePanelPresentation` whose `onClose` clears it. Each of these also clears it:
- a compare row: `model.lookUp(selection.chapterLocation, verse: selection.verse, translationID: row.translationID)`;
- Open on a passage: `model.lookUp(…, verse: reference.verse)`;
- Ask About the Differences: `assistant.compareTranslations(comparison.selection, translationIDs: comparison.otherTranslationIDs)`;
- the `chapterKey` change (`:157-167`): its range belongs to the page that was.

- [ ] **Step 1: Write the failing tests.** In `ReaderKeyTests`:

```swift
@Test func theVersePanelAnchorsOnTheSelectionsFirstLineHeldOnThePage() throws {
    let page = NSRect(x: 0, y: 200, width: 600, height: 400)
    let line = NSRect(x: 80, y: 260, width: 300, height: 22)
    func anchor(_ segment: NSRect?) -> NSRect { ChapterTextController.versePanelAnchor(firstSegment: segment, visiblePage: page) }
    #expect(anchor(line) == line)
    #expect(anchor(line.offsetBy(dx: 0, dy: -200)) == NSRect(x: 80, y: 200, width: 300, height: 1))    // scrolled off the top
    #expect(anchor(line.offsetBy(dx: 0, dy: 500)) == NSRect(x: 80, y: 599, width: 300, height: 1))     // off the bottom
    #expect(anchor(nil) == NSRect(x: 300, y: 200, width: 1, height: 1))
    press("j")                                                           // a verse selected in the suite's window
    let range = controller.textView.selectedRange()
    #expect(controller.versePanelAnchor(for: range) == (try #require(controller.frameOfFirstSegment(of: range))))
}
```

  In `NavigationModelTests`, each test makes its own model (`makeModel()` `:23`, `readingMatthewOne()` `:801`, the file's `matthewOne` `:797`). Set this one up the same way, reading Matthew 5 in WEB; `returningRestoresChapterVerseAndTranslation` (`:860`) already pins most of it.

```swift
/// Spec 10: the lookup from a row keeps the reader's place.
@Test func aRowsLookupKeepsThePlaceAndBackReturnsToIt() throws {
    let matthewFive = ChapterLocation(book: "MAT", chapter: 5)
    let (model, positionStore) = try makeModel()
    // … open Matthew 5 in WEB as the suite's other tests open a chapter …
    let stored = positionStore.load()
    model.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 2)                       // Open on a passage
    #expect(model.location?.chapter == 6 && model.lookupReturn?.location == matthewFive)
    model.lookUp(matthewFive, verse: 3, translationID: "KJV")                              // a compare row
    #expect(model.translationID == "KJV" && model.lookupReturn?.translationID == "WEB" && positionStore.load() == stored)
    model.returnFromLookup()
    #expect(model.location == matthewFive && model.translationID == "WEB" && model.lookupReturn == nil && positionStore.load() == stored)
}
```

- [ ] **Step 2: Run.** `--filter ReaderKeyTests` FAILS to compile. If the lookup test already passes, it stands as the pin; say so.
- [ ] **Step 3: Build** the two panels, the popover and the wiring.
- [ ] **Step 4: Run.** Both suites pass; `SepiaModeTests.everyAppKitHostedSwiftUIRootFollowsSepia` passes with the new hosting controller.
- [ ] **Step 5: See it.** Build the Mac Debug app, quit and open it on John 3. Through System Events, capturing the window each time:
  - Click verse 16, press C: the popover hangs under the verse's first line, the row being read on the wash. If it hangs over the line, the edge is `.minY`; change it and say so.
  - Translations…: uncheck one and the row goes; check it again.
  - Esc: gone. C again, then a click on the page beside it: gone, and nothing else happened.
  - ⇧J to verses 14 to 21, then C: five verses and the line that says so.
  - R on verse 16: two groups with counts, six rows each, Show all. Click a row: its verses, back, Open. Open shows the passage; Back returns to John 3:16.
  - The chevrons walk to 17 and back, and on to a verse with no link, which shows the one line.
  - C on a long verse low in the window (Esther 8:9): the popover scrolls inside itself and stays on the screen.
  - C and R on John 3:16 again in Dark and in Sepia: read `defaults read com.matthewfurr.ReadingThroughScripture.dev readerAppearance`, write `dark`, then `sepia`, relaunching for each. Then put Matt's value and his compare set back.
  - Open every picture: no clipped row, the foot on one line, the wash visible.
- [ ] **Step 6: Commit.** `feat: the two panels, in a popover on the selection's first line (on a verse 4.2, 5.2, 7)`

---

### Task 8: The iPhone's sheets (spec 7)

**Files:**
- Create: `PH/PhoneVersePanelSheet.swift`
- Modify: `PH/PhoneShellModel.swift` (`:45`, `showInReader` `:105-114`), `PH/PhoneReaderScreen.swift` (the sheets `:256-288`, `Covering` `:303-319`, the hook beside `:290`)
- Test: `T/PhoneShellModelTests.swift` (both suites)

**Interfaces:**
- Consumes: the two panels (Task 7); `VersePanelRequest`, `onVersePanel` (Task 6); `AssistantModel.compareTranslations` (Task 3).
- Produces:

```swift
// PhoneShellModel
public var versePanel: VersePanelRequest?
/// The panel's Ask, kept while its sheet closes and run once it has gone.
public var queuedVersePanelAsk: (@MainActor () -> Void)?
#if os(iOS)
public struct PhoneVersePanelSheet: View {
    public init(request: VersePanelRequest, navigation: NavigationModel,
                onOpen: @escaping (ChapterLocation, Int?, String?) -> Void,   // chapter, verse, translation: a lookup
                onAsk: @escaping (@escaping @MainActor () -> Void) -> Void)   // queues the ask and closes the sheet
}
#endif
```

- The sheet is a `NavigationStack` over `[Reference]`, built as `PhoneNoteSheet` is (`PH/PhoneNoteSheet.swift:47-59`, `:208-224`): `paper.page` as its container background, the reference as an inline title, `.presentationDetents([.medium, .large])`, Done (`checkmark`) in the confirmation slot. A tapped reference pushes `VersePreviewView(preview:openTitle: "Open in Read", onOpen:)`.
- `PhoneReaderScreen` sets `markup.onVersePanel` to fill `shell.versePanel` and presents `.sheet(item:)`. `Covering` gains the panel.
- A row, or Open in Read, clears `shell.versePanel` and calls `navigation.lookUp`.
- Ask puts its action in `queuedVersePanelAsk` and closes the sheet; the sheet's `onDismiss` runs it and shows the Ask sheet, as a note sheet's Ask does (`askOverPage`, `showQueuedAsk`, `:337-360`).

- [ ] **Step 1: Write the failing test.** In `PhoneShellModelTests`, where each test makes its own shell (`:8`) and `PhoneShellModel` is `@MainActor`; `request` is a `VersePanelRequest` for Matthew 5:3, built in the test from a `SelectionReport`:

```swift
@Test @MainActor func goingBackToThePageClosesAVersePanelToo() {
    let shell = PhoneShellModel()
    shell.versePanel = request
    shell.queuedVersePanelAsk = {}
    shell.showInReader()
    #expect(shell.versePanel == nil && shell.queuedVersePanelAsk == nil && shell.tab == .read)
}
```

- [ ] **Step 2: Run.** `--filter PhoneShellModelTests` FAILS to compile.
- [ ] **Step 3: Build** the sheet and the wiring.
- [ ] **Step 4: Run.** The iOS suite and the package suite pass.
- [ ] **Step 5: See it in the simulator.** Build the iOS Debug app and launch it on John 3. With the iOS Simulator control tool, a screenshot at each:
  - Tap verse 16 and open the chevron's list: the two items lead it, after the bar's six symbols.
  - Compare Translations: the sheet at half height with its title and Done; drag it full. Translations…: uncheck and check one. Tap a row: the sheet closes and the verse shows in that translation; go back.
  - Cross-References: the groups, Show all, the chevrons. Tap a row: its verses pushed inside the sheet, Back, Open in Read.
  - A verse with no link; a long verse. Each sheet once in Dark and once in Sepia, put back afterwards.
  - Say plainly which of these could not be driven.
- [ ] **Step 6: Commit.** `feat: the two panels as sheets on the iPhone (on a verse 7)`

---

### Task 9: Ask About These, and the credit (spec 5.3, 5.4 Credit)

**Files:**
- Modify: `SUI/CrossReferences.swift`, `SUI/NavigationModel.swift`, `SUI/AssistantModel.swift` (`Input` `:406-409`, `compose` `:708-731`, and `createThread`'s switch over the input `:758-767`, which needs the new case), `SUI/CrossReferencesPanel.swift`, `MAC/MainWindowView.swift`, `PH/PhoneReaderScreen.swift`, `SUI/Credits.swift` (`:6-24`, an entry after `bsb` `:85-91`), `SUI/AboutView.swift` (where a credit's license is drawn as text, `:88-91`), `README.md` (Acknowledgements `:226-235`)
- Test: `T/AssistantModelTests.swift`, `T/CrossReferencesTests.swift`, `T/CreditsTests.swift` (both suites)

**Interfaces:**
- Consumes: `CrossReferences` (Task 5), the panels' `onAsk` (Tasks 7 and 8).
- Produces:

```swift
// CrossReferences
public static let askTitle = "Explain these cross-references"
public static let credit = "Cross-references: OpenBible.info"
public static let creditLink = URL(string: "https://www.openbible.info/labs/cross-references/")!
public var selection: TextSelection? { get }        // the verse in the translation being read; nil when it lacks it
public var canAsk: Bool { get }                     // has a selection and a row in either short list
public func question(store: BibleStore) throws -> String
public static func request(for reference: String) -> String
// NavigationModel; nil when the read fails
public func crossReferenceQuestion(_ references: CrossReferences) -> String?
// AssistantModel: opens the panel on `selection` and sends `content` as it is; the reader's turn
// reads `title`. Nothing is stored as a prompt.
public func ask(about selection: TextSelection, sending content: String, shownAs title: String)
// Credit gains `public var licenseLink: URL? = nil`, declared last; `Credit.Section` gains
// `crossReferences = "Cross-references"` after `headings`.
```

**The question.** A group with an empty short list is left out with its heading. A passage's text is its verses in the translation being read, each with its number, poetry lines joined, the verses joined by a space; a row without words is its reference alone.

```
Here is {reference} ({translation}):

{the verse's text}

This verse points to:

{reference} — {text}
{reference} — {text}

Verses that point here:

{reference} — {text}

Explain how each of these cross-references relates to {reference}: what the passages share, and what reading them together shows. Keep to what the passages say.
```

`Input` gains `case composed(title: String, content: String)`: `compose` sends the content as it is and shows the title. The usual routing applies.

**The credit.**
- In the panel's foot: "Ask About These" (`sparkles`, `Color.assistant`, disabled unless `canAsk`), then `credit` in `.caption` `ink.secondary` as a `Link` to `creditLink`.
- In `Credits.all` after `bsb`: id `openbible`, section `.crossReferences`, name "OpenBible.info", use "Cross-references", license "CC BY 4.0", link `openbible.info/labs/cross-references`, `licenseLink` `https://creativecommons.org/licenses/by/4.0/`, and the notice in the test below.
- About shows a credit's license as a link when it has a `licenseLink`. README's Acknowledgements gains the line, which `theReadmeAcknowledgesEverySource` requires.

- [ ] **Step 1: Write the failing tests.** In `AssistantModelTests`:

```swift
@Test func askAboutTheseComposesTheVerseAndTheShortListsAndStoresNoPrompt() async throws {
    let cloud = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5", deltas: ["ok"])
    let h = try make([cloud])
    let x = try CrossReferences.load(VerseLocation(book: "MAT", chapter: 5, verse: 3), translationID: "WEB", store: h.bible)
    let stored = try h.templates.templates().count
    h.model.ask(about: try #require(x.selection), sending: try x.question(store: h.bible), shownAs: CrossReferences.askTitle)
    try await settle(h.model)
    let content = try #require(cloud.requests.last?.messages.last?.content)
    // This fixture has the words of Psalm 1:1 alone among these passages: every other row is its reference alone.
    #expect(content.hasPrefix("Here is Matthew 5:3 (WEB):\n\n") && content.contains("\n\nThis verse points to:\n\nPsalm 1:1 \u{2014} 1 "))
    #expect(content.contains("\nMatthew 6:19-21\n") && content.contains("\nMatthew 3:2\n\nVerses that point here:\n\nMatthew 6:33\nPsalm 1:1 \u{2014} 1 "))
    #expect(content.contains("\nMatthew 4:25\n\nExplain how each"))
    #expect(!content.contains("Isaiah 57:15") && !content.contains("Luke 6:20") && !content.contains("3 John"))   // the short lists alone
    #expect(content.hasSuffix(CrossReferences.request(for: "Matthew 5:3")))
    #expect(h.model.messages[0].displayText == "Explain these cross-references" && h.model.thread?.scope == .selection && h.model.isPanelShown)
    #expect(try h.templates.templates().count == stored)
}

@Test func aQuestionTooLongForOnDeviceSaysSo() throws {
    let h = try make([onDevice()])
    h.model.ask(about: blessed().selection, sending: String(repeating: "word ", count: 20_000), shownAs: CrossReferences.askTitle)
    #expect(h.model.notice == .tooLongForOnDevice && h.model.messages.isEmpty)
}
```

  In `CrossReferencesTests`:

```swift
@Test func askNeedsAVerseAndAShortList() throws {
    #expect(try load(mt(5, 3)).canAsk && !load(mt(5, 20)).canAsk)
    let four = try load(mt(5, 4))                                        // nothing out at four votes; two in
    #expect(four.canAsk && !(try four.question(store: FixtureStore.make())).contains("This verse points to:"))
    #expect(CrossReferences.credit == "Cross-references: OpenBible.info" && CrossReferences.creditLink.host() == "www.openbible.info")
}
```

  In `CrossReferencesTests`, a passage of several verses carries each verse's number (the `AssistantModelTests` fixture rows are single verses or have no words): the question for Psalm 1:1's own links, or a direct call to whatever composes one passage's text, shows "1 … 2 …" for Psalm 1:1-2 in WEB. In `CreditsTests.theCatalogueIsTheAppendixAndClaimsNoPermission` (`:33-34`): 16 entries (15 today), "Cross-references" third of the seven sections, and

```swift
let openbible = try #require(Credits.all.first { $0.id == "openbible" })
#expect(openbible.notice == "Cross-references from OpenBible.info, CC BY 4.0, drawn chiefly from the Treasury of Scripture Knowledge. Changes: re-keyed to this app's verse table; links with no votes left out.")
#expect(openbible.link.absoluteString == "https://openbible.info/labs/cross-references" && openbible.licenseLink?.host() == "creativecommons.org")
```

- [ ] **Step 2: Run.** The three filters FAIL to compile.
- [ ] **Step 3: Implement.** On the Mac, Ask About These calls `assistant.ask(about:sending:shownAs:)` with `model.crossReferenceQuestion(_:)` and clears the popover; on the phone it goes through `queuedVersePanelAsk`.
- [ ] **Step 4: Run.** Both suites pass.
- [ ] **Step 5: See it.** In the Mac Debug app, R on John 3:16, then Ask About These: the popover closes, the assistant opens, and the reader's turn reads "Explain these cross-references". The credit in the foot opens OpenBible's page. About lists OpenBible.info under Cross-references with both links. The same Ask from the simulator's sheet.
- [ ] **Step 6: Commit.** `feat: Ask About These, and the credit to OpenBible.info (on a verse 5.3, 5.4)`

---

### Task 10: Docs and whole-project verification

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md`, the spec (section 11), `docs/BACKLOG.md` only if something was set aside

**Interfaces:**
- Consumes: everything above.
- Produces: the documents in step with the code; a branch ready for Matt's list.

- [ ] **Step 1: `DESIGN.md`.** Section 4, Popovers (`:290`): the verse panels, padded `sm`, on the selection's first line. Section 5: the translation row and the reference row among Rows (`:310-333`); the two panels with their headers, groups and feet; the two new symbols, monochrome, and `chevron.up` and `chevron.down` in the inventory (`:374`). Section 7 (the sheets `:433-434`, the selection menu `:442-444`): the two sheets and where their items sit behind the chevron. Line `:442` says seven symbols fit before the chevron; check it against `PhoneMarkupMenu` and correct whichever is stale.
- [ ] **Step 2: `DESIGN.json`.** The same facts where the file holds them. `python3 -I -m json.tool DESIGN.json` prints it without error.
- [ ] **Step 3: `README.md`.** Keyboard: C and R. A short part on the two panels and the compare set. Building: `Scripts/fetch-crossrefs.sh`, its cache and its digest.
- [ ] **Step 4: The spec's section 11, As built.** What was built, task by task, with:
  - Task 4's figures and table, the address that gave the file, the database's size before and after, and the benchmark's median beside Task 5's table.
  - Every **(call)** made here: 649 kept links leave their chapter, 18 of them their book; the text's digest and the second address; the set stored as one string; the cut's line; the Settings section; a group under four votes; the popover staying put while the chevrons step; the question's wording; the hyphen in a reference.
  - Which edge the popover took, the new test counts, and anything a step could not see or drive.
- [ ] **Step 5: `docs/BACKLOG.md`.** A line for anything this build set aside.
- [ ] **Step 6: Run everything, one after another.** The package suite; the iOS suite; the Mac Debug build; the iOS Debug build. All pass and both builds succeed. Record the test counts.
- [ ] **Step 7: Look at each new surface once more on the final build** (spec 10), in light, dark and Sepia: both panels on the Mac and on the iPhone, with a long verse and with a verse that has no links. Open every picture. Say plainly what was not seen.
- [ ] **Step 8: Leave the Mac Debug app running the final build** (`pkill -f` as above, then `open`). The controller runs `Scripts/install-phone.sh debug`.
- [ ] **Step 9: Commit.** `docs: on a verse as built; DESIGN and README in step`
- [ ] **Step 10: Hand Matt his list** (spec 10, "For Matt"), unchanged, with what this session could not check beside each item.

---

## Where each spec requirement is pinned

Each test is named for the bullet it pins. The ones a name does not make plain, and those pinned by a step and not a test:

| Spec | Pinned by |
|---|---|
| 4.1: the menu item and C; a verse or a run; **(call)** five verses | Task 6's tests; Task 1 `aRangeShowsEachVerseAndMoreThanFiveIsCutWithItsLine` |
| 4.2: header, rows and their order, "reading", prose; a translation lacking the verse, not clickable | Task 1 `theReadingTranslationLeadsThenTheSetInTheListsOrder`; Task 7 Steps 3 and 5 |
| 4.2 **(call)**: the CPDV's line; 4.4: Copy | Task 1 `theCPDVsLineShowsInPsalmsOnlyAndCopyIsEveryRowWithItsReference` |
| 4.2: a row's click is a lookup and closes the panel; 10: it keeps the place | Task 7 `aRowsLookupKeepsThePlaceAndBackReturnsToIt`, Step 5; Task 8 Step 5 |
| 4.3: the checklist in both places, the four, the one being read always shown | Task 2's two tests and Step 3; Task 1's first test |
| 4.3: one preference that travels | Task 2's `theSyncedKeysAreExactlyThese`; the suite's tests run over every key |
| 4.4: Ask sends the prompt as the reader has it and the rows shown; three on-device | Task 3 `askAboutTheDifferencesSendsExactlyTheRowsShownAndThreeOnDevice` |
| 4.4 **(call)**: the prompt from the assistant's list sends the set | Task 3 `thePromptFromTheAssistantsListSendsTheCompareSet` |
| 5.1: the menu item and R; **(call)** one verse, the chevrons | Task 6's tests; Task 5 `aVerseWithNoLinksSaysSoAndTheChevronsStopAtTheChaptersEnds` |
| 5.2: the two groups, counts, vote order, a range that holds the verse | Task 5's two store tests |
| 5.2 **(call)**: six of four votes, Show all; a row's reference and words; votes not shown | Task 5 `theShortListIsSixOfFourVotesOrMore`, `aGroupUnderFourVotesStillOffersItsLinks`; no view reads a vote |
| 5.2: a row shows the passage inside the panel, with a way back and Open | Task 7 Steps 3 and 5; Task 8 Step 5 |
| 5.2 **(call)**: a target running on is its first chapter's part | Task 5 `pointsToIsInVoteOrderWithOpeningWords` (`chapterEnd`), `theShortListIs…` ("Matthew 5:47-48") |
| 5.2 **(call)**: the CPDV's Psalms shown anyway | no rule to pin: the model treats the CPDV as any translation |
| 5.2: a verse with no links; the foot | Task 5's third model test; Task 9 `askNeedsAVerseAndAShortList`, Step 5 |
| 5.3 **(call)**: the composed question, its title, nothing stored; routing | Task 9's two `AssistantModelTests` |
| 5.4: the source, digest and cache; the size | Task 4's figures, Steps 6 and 7 |
| 5.4: the table both ways, schema 4, an older database rebuilt | Task 4 `theFixtureLinksLandKeyedBothWaysAtSchemaFour`, `theBuildScriptsPatternReadsTheSchemaVersion`, the existing `schemaMismatchThrows`, Step 7 |
| 5.4 **(call)**: one vote or more; `3John.1.15`; a target the translation lacks | Task 4's two parser tests; Task 5 (Isaiah's row) |
| 5.4: the credit in the foot and in About | Task 9's `CreditsTests` lines and Step 5; the existing `theReadmeAcknowledgesEverySource` |
| 6: both menus; **(call)** the symbols; C and R listed, not palette commands | Task 6's five tests; project 2's count of 32 |
| 7: the Mac's popover | Task 7 `theVersePanelAnchorsOnTheSelectionsFirstLineHeldOnThePage`, Steps 3 to 5; `everyAppKitHostedSwiftUIRootFollowsSepia` |
| 7: the iPhone's sheet | Task 8's test, Steps 3 and 5 |
| 7: VoiceOver; tokens and rows | the two models' `accessibilityLabel` tests; Task 7 Step 3 and its pairing |
| 8 | Global Constraints; Task 2; Task 4's fixture and script |
| 9 | Task 4 (columns, keys), Task 5 (ranges), Task 7 (the anchor), Task 3 (the list), Task 9 (the wording), Task 2 (the checklist) |
| 10: C and R do nothing without a selection; the benchmark; seen by eye | Task 6 `cAndROpenTheirPanels…`; Task 5's benchmark; Tasks 7 to 10's seeing steps |
