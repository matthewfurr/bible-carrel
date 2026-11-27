# Milestone 9: the Reader (page styles, book-long scrolling, headings) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Readers on the Mac and iPhone show a whole book as one continuous, typeset scroll in one of four page styles, with book titles, chapter labels, BSB section headings, a running head and per-chapter progress, and new reading settings including Sepia.

**Architecture:** Headings and titles are imported at build time into `bible.sqlite` (schema 2). A pure `BookLayout` concatenates per-chapter `ChapterLayout`s for a *window* of consecutive chapters, with non-verse paragraphs (title block, chapter labels, section headings) tagged by a `readerRole` attribute and never inside a `VerseSpan`. A shared `ReaderDocument` builds that layout from `NavigationModel.bookText` and grows the window as the reader nears either end; both text controllers render it, and `MarkupModel` maps marks onto it through `BookDecorations`. A pure `RunningHead` turns chapter bands into the chapter in view, its progress and the head's fade.

**Tech Stack:** Swift 6.2, SwiftUI, TextKit 2 (`NSTextView`/`UITextView`), GRDB, Swift Testing, macOS 26 / iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-12-reader-page-styles-and-book-scroll-design.md`, with `DESIGN.md` section 3 (Page Styles) and section 2 (`ink.verse`, the One Saturated Voice Rule) as the visual spec. Mockups in `docs/superpowers/specs/2026-11-12-reader-mockups/`.

## Global Constraints

- Read `PRODUCT.md` and `DESIGN.md` before any SwiftUI change (`CLAUDE.md`). No `.font(.system(size:))` in chrome; the only fixed sizes are those derived from the reader size (reader, verse numbers, the page style's headings). No inline colors: tokens from `Palette.swift`, every new pairing in `PaletteTests`. Spacing and radii from `AppSpacing`/`AppRadius`.
- Never touch `textView.layoutManager` on either platform (it silently switches the view to TextKit 1).
- A verse's `VerseSpan.textRange` maps 1:1 onto `Verse.text`. Headings, labels and title paragraphs are never inside a `textRange` and never part of a `TextSelection`, copy or highlight offset.
- Selection stays within one chapter: a selection is clamped to the chapter of its start.
- Opening a chapter stays within the milestone 6 budget: Psalm 119 in ESV at 18 pt with sixty highlights appears within a second; an end-to-end scroll drops no frames.
- Tests and runs use the Debug build (`.dev` identity) and test stores only. Never touch the Release store or `~/Library/Application Support/ReadingThroughScripture` (memory: real store off limits).
- AppKit/UIKit controller tests run on the main actor (`@MainActor` suites); AppKit tests off the main actor crash parallel runs.
- `swift test` cannot load asset catalogs: colors stay in `Palette.swift`; bundled fonts are plain resources loaded from `Bundle.module`.
- Unit tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter <Suite>` from the repository root. App builds: the two `xcodebuild` commands in `README.md` (Mac scheme `ReadingThroughScripture`, iOS scheme `ReadingThroughScripture-iOS`).
- Commit after each task on a branch `milestone-9-reader` (never on `main`), message ending with the `Co-Authored-By` line from the session.

## Review Focus

1. **A highlight on the first or last verse of a chapter**, made before this milestone, still sits on the same words after the book scroll lands (the label and heading paragraphs around chapter boundaries are where offsets would slip). Test in Task 7 and Task 13.
2. **Growing the window upward while reading** (scrolling up from John 5 into John 4) never moves the text under the reader's eyes. Test in Task 13 (Mac) and checked by hand in Task 15 (phone).
3. **Switching translation mid-book** to one that numbers verses differently (ERV combined verses) keeps the reader at the same verse and the same chapter in the head. Test in Task 13.
4. **Editing a note in the notes column while scrolling** into the next chapter keeps the note open and saved; the column switches only when editing ends. Test in Task 11.
5. **A lookup into another book** stays a lookup however far it scrolls, while one in the same book ends after five lines. Test in Task 9.

---

### Task 1: Headings and book titles in `bible.sqlite` (schema 2)

**Files:**
- Create: `Packages/ScriptureKit/Sources/BibleImporterCore/USFMHeadings.swift`
- Create: `Scripts/fetch-ebible.sh`, `Scripts/ensure-bible.sh`
- Modify: `Packages/ScriptureKit/Sources/ScriptureData/BibleSchema.swift` (version 2, two tables)
- Modify: `Packages/ScriptureKit/Sources/BibleImporterCore/BibleDatabaseWriter.swift`, `Packages/ScriptureKit/Sources/bible-importer/main.swift`, `Scripts/build-bible.sh`
- Modify: the "Bundle Bible database" run-script phase in `Apps/Mac/ReadingThroughScripture.xcodeproj/project.pbxproj` and `Apps/iOS/ReadingThroughScripture.xcodeproj/project.pbxproj`
- Test: `Packages/ScriptureKit/Tests/BibleImporterCoreTests/USFMHeadingsTests.swift`, fixtures `Tests/BibleImporterCoreTests/Fixtures/USFM/73-JHNengbsb.usfm` (first two chapters of John, trimmed) and `44JHNeng-kjv.usfm` (its first 12 lines)

**Interfaces:**
- Produces: `public struct USFMBook { public let bookID: String; public let headings: [USFMHeading]; public let mainTitle: String? }`, `public struct USFMHeading: Equatable { public let chapter: Int; public let verse: Int; public let ordinal: Int; public let level: Int; public let text: String }`, `public enum USFMHeadings { public static func parse(_ usfm: String) -> USFMBook?; public static func titleCased(_ text: String) -> String }`.
- Produces: tables `heading(source TEXT, book_id TEXT, chapter INTEGER, verse INTEGER, ordinal INTEGER, level INTEGER, text TEXT, PRIMARY KEY(source, book_id, chapter, verse, ordinal))` and `book_title(translation_id TEXT, book_id TEXT, title TEXT NOT NULL, subtitle TEXT, PRIMARY KEY(translation_id, book_id))`; `BibleSchema.version = 2`. Sources written: `heading.source = 'bsb'`; `book_title` rows for `translation_id = 'KJV'` only.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func bsbHeadingsAttachToTheNextVerse() throws {
    let book = try #require(USFMHeadings.parse(fixture("73-JHNengbsb.usfm")))
    #expect(book.bookID == "JHN")
    #expect(book.headings.prefix(3) == [
        USFMHeading(chapter: 1, verse: 1, ordinal: 0, level: 1, text: "The Beginning"),
        USFMHeading(chapter: 1, verse: 6, ordinal: 0, level: 1, text: "The Witness of John"),
        USFMHeading(chapter: 1, verse: 14, ordinal: 0, level: 1, text: "The Word Became Flesh"),
    ])
}
@Test func parallelReferencesAndPsalmTitlesAreNotHeadings() throws // \r and \d lines produce no USFMHeading
@Test func aHeadingBeforeAChapterMarkerBelongsToThatChaptersFirstVerse() throws // "\s1 X\n\c 2\n\v 1" → (2, 1)
@Test func kjvMainTitleIsTitleCased() throws {
    let book = try #require(USFMHeadings.parse(fixture("44JHNeng-kjv.usfm")))
    #expect(book.mainTitle.map(USFMHeadings.titleCased) == "The Gospel According to St. John")
    #expect(USFMHeadings.titleCased("THE FIRST BOOK OF MOSES, CALLED GENESIS") == "The First Book of Moses, called Genesis")
    #expect(USFMHeadings.titleCased("Already Mixed Case") == "Already Mixed Case")
}
@Test func writerStoresHeadingsAndTitles() throws // BibleDatabaseWriter with the fixtures: SELECT from heading/book_title returns them; meta schema_version == "2"
```

- [ ] **Step 2: Run them to see them fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter USFMHeadingsTests`
Expected: FAIL, `USFMHeadings` not found.

- [ ] **Step 3: Implement the parser, schema and writer**

`USFMHeadings.parse`: book id from `\id XXX`; track `\c`; `\s1`/`\s2` text (strip any `\w…\w*`, `\f…\f*` and other backslash markers, trim) queued until the next `\v n`, then emitted with that chapter and verse, `ordinal` counting headings queued before the same verse; `\r`, `\d`, `\ms` ignored. `mainTitle` from `\mt1`. `titleCased` applies only to all-caps input: lower-case everything, capitalise each word except `a, an, and, as, called, of, the, to, unto` when not first; keep "St." capitalised.

`BibleDatabaseWriter.importAll(from:translations:sourceCommit:ebible:)` gains `ebible: URL?`, the folder holding `engbsb_usfm/` and `eng-kjv_usfm/`; writes BSB headings for every book file and KJV `book_title(title: <app book name>, subtitle: titleCased(mainTitle))`. `meta` gains `ebible_bsb_sha256` and `ebible_kjv_sha256`.

`Scripts/fetch-ebible.sh` (pattern of `fetch-holybooks.sh`): downloads `https://ebible.org/Scriptures/engbsb_usfm.zip` and `https://ebible.org/Scriptures/eng-kjv_usfm.zip` into `~/Library/Caches/ReadingThroughScripture/ebible/<sha>/`, checks SHA-256 against the pinned `75ca91d5a5c69ca4cbdeabdb03ea1a458db20cf3966abe15d86df086acf7fbc4` (BSB) and `941ef56e3e38a5cd7d72a2ea582559e37e9da5be0b241cf8caf71014650b8133` (KJV), unzips, prints the folder. A mismatch fails with "eBible changed <file>; check it and re-pin the digest in fetch-ebible.sh". `build-bible.sh` passes `--ebible "$(bash fetch-ebible.sh)"`.

`Scripts/ensure-bible.sh`: rebuilds when `Build/bible.sqlite` is missing **or** `sqlite3 Build/bible.sqlite "SELECT value FROM meta WHERE key='schema_version'"` is not `2`. Both Xcode run-script phases call it instead of their inline `if [ ! -f ]` test (keep their copy step and input/output paths).

- [ ] **Step 4: Run the tests and rebuild the database**

Run: the Step 2 command, then `bash Scripts/build-bible.sh`, then `sqlite3 Build/bible.sqlite "SELECT count(*) FROM heading; SELECT subtitle FROM book_title WHERE book_id='JHN'"`
Expected: PASS; about 3,097 headings; `The Gospel According to St. John`.

- [ ] **Step 5: Commit** (`feat: import BSB headings and KJV book titles into bible.sqlite`)

---

### Task 2: Reading headings, titles and whole books from `BibleStore`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureData/BookTitles.swift`, `Packages/ScriptureKit/Sources/ScriptureData/Headings.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureData/BibleStore.swift`, `Tests/ScriptureDataTests/FixtureDatabase.swift` (fixture DB gets a few heading rows and a KJV title)
- Test: `Packages/ScriptureKit/Tests/ScriptureDataTests/BibleStoreHeadingsTests.swift`

**Interfaces:**
- Consumes: Task 1 tables.
- Produces:
  - `public struct SectionHeading: Hashable, Sendable { public let text: String; public let level: Int }`
  - `public struct BookTitle: Hashable, Sendable { public let title: String; public let subtitle: String? }`
  - `public enum BookTitles { public static func app(for bookID: String) -> BookTitle? }` — 66 entries, English; title = the catalog's book name; subtitle the plain traditional long title (Genesis: "The First Book of Moses"; Matthew: "The Gospel According to Matthew"; Romans: "The Letter of Paul to the Romans"; Psalms: nil). Matt reviews the wording.
  - `BibleStore.bookChapters(_ bookID: String, translationID: String) throws -> [Int: [Verse]]` (one query, ordered)
  - `BibleStore.headings(bookID: String, translationID: String) throws -> [VerseLocation: [SectionHeading]]`
  - `BibleStore.bookTitle(bookID: String, translationID: String) throws -> BookTitle` (KJV row when present, else `BookTitles.app`, else the bare name)

- [ ] **Step 1: Write the failing tests**

```swift
@Test func bookChaptersReturnsEveryChapterInOrder() throws // fixture JHN: keys 1...n, verses sorted
@Test func headingsAttachToTheNextVerseTheTranslationHas() throws {
    // fixture heading at JHN 1:2 in a translation whose chapter lacks verse 2 → attaches to 1:3
    #expect(try store.headings(bookID: "JHN", translationID: "TST")[VerseLocation(book: "JHN", chapter: 1, verse: 3)]?.first?.text == "Fixture Heading")
}
@Test func aHeadingPastTheChaptersLastVerseIsDropped() throws
@Test func theCPDVGetsNoBorrowedHeadings() throws { #expect(try store.headings(bookID: "JHN", translationID: "CPDV").isEmpty) }
@Test func kjvTakesItsOwnSubtitleOthersTheAppTable() throws {
    #expect(try store.bookTitle(bookID: "JHN", translationID: "KJV") == BookTitle(title: "John", subtitle: "The Gospel According to St. John"))
    #expect(try store.bookTitle(bookID: "JHN", translationID: "ESV") == BookTitle(title: "John", subtitle: "The Gospel According to John"))
}
@Test func everyCanonBookHasAnAppTitle() { for book in BookCatalog.all where book.canon != "AP" { #expect(BookTitles.app(for: book.id) != nil) } }
```

- [ ] **Step 2: Run them to see them fail** — `--filter BibleStoreHeadingsTests`, FAIL (missing API).
- [ ] **Step 3: Implement** the three store methods and the two types. Alignment: for each `(chapter, verse)` heading, the translation's first verse in that chapter with `verse >= heading.verse` (a combined verse counts if its range contains it); none → drop. `translationID == "CPDV"` → `[:]` (`BibleStore.headingFreeTranslations: Set<String> = ["CPDV"]`).
- [ ] **Step 4: Run them to see them pass** — PASS, and `--filter ScriptureDataTests` still passes.
- [ ] **Step 5: Commit** (`feat: BibleStore reads whole books, headings and book titles`)

---

### Task 3: The verse bronze token

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/Palette.swift` (`Palette.inkVerse`, `Color.inkVerse`)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/PaletteTests.swift`

**Interfaces:** Produces `Palette.inkVerse: ColorToken` named `ink.verse`, light `#7A5320`, dark `#DDB683` (no high-contrast variants), and `extension Color { static var inkVerse: Color }`.

- [ ] **Step 1: Failing test**

```swift
@Test func verseBronzeCarriesSmallTextOnThePageAndEveryMark() {
    expect(Palette.inkVerse, on: Palette.paperPage, atLeast: 4.5)
    for mark in MarkupContainer.defaultColors { // light/dark hex pairs
        #expect(Self.contrast(Palette.inkVerse.light, mark.lightHex) >= 4.5)
        #expect(Self.contrast(Palette.inkVerse.dark, mark.darkHex) >= 4.5)
    }
}
@Test func studyAccentVerseNumbersFallBackOnMarks() {
    expect(Palette.accent, on: Palette.paperPage, atLeast: 4.5)
    for mark in MarkupContainer.defaultColors { #expect(Self.contrast(Palette.inkSecondary.light, mark.lightHex) >= 4.2) } // ink.secondary is the on-mark fallback; 4.22 on Orange is today's floor for secondary
}
```
Use whatever `MarkupContainer` exposes for the seeded defaults (read it; add a `defaultColorHexes` accessor if it is private).

- [ ] **Step 2–4:** run `--filter PaletteTests` (FAIL), add the token, run (PASS).
- [ ] **Step 5: Commit** (`feat: ink.verse token`)

---

### Task 4: Bundled faces and `PageFace`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/Fonts/` with `Literata-Light.ttf`, `Literata-Regular.ttf`, `Literata-Italic.ttf`, `Literata-Medium.ttf`, `SourceSerif4-Regular.ttf`, `SourceSerif4-Italic.ttf`, `SourceSerif4-Semibold.ttf`, `OFL-Literata.txt`, `OFL-SourceSerif4.txt` (static instances from the families' official releases on github.com/googlefonts/literata and github.com/adobe-fonts/source-serif; record the release tags in `Fonts/README.md`)
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/PageFace.swift`
- Modify: `Packages/ScriptureKit/Package.swift` (`ScriptureUI` target `resources: [.copy("Fonts")]`), both app entry points (call `PageFace.registerBundledFonts()` at launch), `README.md` (an acknowledgements line naming both fonts and the OFL)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/PageFaceTests.swift`

**Interfaces:**
- Produces: `public enum PageFace: String, CaseIterable, Sendable { case literata, iowanOldStyle, sourceSerif, newYork, charter }` with `var title: String` ("Literata", "Iowan Old Style", "Source Serif 4", "New York", "Charter"), `func font(size: CGFloat, weight: PlatformFont.Weight = .regular, italic: Bool = false) -> PlatformFont`, `func swiftUIFont(_ style: Font.TextStyle, weight: Font.Weight = .regular, italic: Bool = false) -> Font` (`Font.custom(_:size:relativeTo:)`; New York through `.system(style, design: .serif)`), `static var available: [PageFace]` (drops `charter` when the system lacks it), `static func registerBundledFonts()` (idempotent, `CTFontManagerRegisterFontsForURL` over `Bundle.module`'s `Fonts`; `font(size:)` calls it on first use, so tests and previews never see a fallback face).
- `ReaderTypography.default` becomes Printed at 18 pt from Task 5 on, so every existing layout test runs in Literata.

- [ ] **Step 1: Failing tests**

```swift
@Test func bundledFacesResolveToTheirFamilies() {
    PageFace.registerBundledFonts()
    #expect(PageFace.literata.font(size: 18).familyName == "Literata")
    #expect(PageFace.sourceSerif.font(size: 18, weight: .semibold).familyName == "Source Serif 4")
    #expect(PageFace.literata.font(size: 44, weight: .light).fontName.contains("Light"))
    #expect(PageFace.literata.font(size: 18, italic: true).fontDescriptor.symbolicTraits.contains(.italic))
}
@Test func systemFacesResolve() { #expect(PageFace.iowanOldStyle.font(size: 18).familyName == "Iowan Old Style") }
@Test func registeringTwiceIsHarmless() { PageFace.registerBundledFonts(); PageFace.registerBundledFonts() }
```

- [ ] **Step 2–4:** `--filter PageFaceTests` FAIL → implement → PASS. Check Charter on an iOS 26 simulator once (`UIFont(name: "Charter-Roman", size: 18) != nil`); if absent, `available` omits it on iOS.
- [ ] **Step 5: Commit** (`feat: bundle Literata and Source Serif 4; PageFace`)

---

### Task 5: Page styles, reader preferences and typography

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/PageStyle.swift`, `ReaderPreferences.swift`
- Modify: `ReaderTypography.swift`, `ReaderSettings.swift`, `PreferenceSync.swift` (`SyncedPreferences.keys`), `Apps/Mac/ReadingThroughScripture/MainWindowView.swift:44` and `Sources/ScriptureUI/Phone/PhoneReaderScreen.swift:43-99` (build typography from `ReaderPreferences`)
- Test: `Tests/ScriptureUITests/PageStyleTests.swift`, `ReaderSettingsTests.swift`, `PreferenceSyncTests.swift`

**Interfaces:**
- Produces:
  - `public enum PageStyle: String, CaseIterable, Sendable { case printed, lectern, study, classic }` with `title`, `defaultFace: PageFace` (literata, iowanOldStyle, sourceSerif, newYork), `func runningHead(bookName: String, chapter: Int) -> String` (printed `"JOHN · CHAPTER 3"`, lectern `"John · 3"` drawn in small caps, study `"JOHN 3"`, classic `"John 3"`).
  - `public enum ColumnWidthChoice: String, CaseIterable, Sendable { case narrow, normal, wide; var multiplier: CGFloat }` (0.85, 1, 1.15); `public enum VerseLayoutChoice: String, CaseIterable, Sendable { case paragraphs, versePerLine }`.
  - `public struct ReaderPreferences: Equatable, Sendable { var style: PageStyle; var face: PageFace?; var fontSize: Double; var lineSpacing: LineSpacingChoice; var columnWidth: ColumnWidthChoice; var layout: VerseLayoutChoice; var showsVerseNumbers: Bool; var showsSectionHeadings: Bool; var justified: Bool; static let `default`; static func load(from: UserDefaults) -> ReaderPreferences; var resolvedFace: PageFace }`.
  - `ReaderSettings` keys: `pageStyleKey = "readerPageStyle"`, `pageFaceKey = "readerPageFace"` (empty string = the style's), `columnWidthKey = "readerColumnWidth"`, `verseLayoutKey = "readerVerseLayout"`, `showsVerseNumbersKey = "readerShowsVerseNumbers"`, `showsSectionHeadingsKey = "readerShowsSectionHeadings"`, `justifiedKey = "readerJustified"`; `fontSizeRange = 14...28`; `ReaderSettings.typography(_ prefs: ReaderPreferences) -> ReaderTypography` replaces `typography(fontSize:lineSpacing:)`.
  - `ReaderTypography` gains `style: PageStyle`, `titleFont`, `subtitleFont`, `chapterLabelFont`, `sectionHeadingFont: PlatformFont`, `titleColor`, `subtitleColor`, `chapterLabelColor`, `sectionHeadingColor: PlatformColor`, `chapterLabelKern: CGFloat` (points), `sectionHeadingAlignment: NSTextAlignment`, `verseNumberColorOnMark: PlatformColor?`, `showsVerseNumbers`, `showsSectionHeadings`, `versePerLine`, `justified: Bool`; `ReaderTypography.styled(_ prefs: ReaderPreferences) -> ReaderTypography` replaces `scaled(size:lineHeightMultiple:)` (keep `scaled` as a thin wrapper for Classic defaults only if tests need it; otherwise remove). `measureRange` becomes `420...1150`; measure = `size × 640/18 × columnWidth.multiplier`, clamped.
  - `SyncedPreferences.keys` adds `pageStyleKey`, `pageFaceKey`, `verseLayoutKey`, `showsVerseNumbersKey`, `showsSectionHeadingsKey`, `justifiedKey` (not size, spacing, column width or appearance).

- [ ] **Step 1: Failing tests**

```swift
@Test func printedAt18MatchesDesign() {
    let t = ReaderTypography.styled(.default)
    #expect(t.style == .printed && t.bodyFont.familyName == "Literata" && t.bodyFont.pointSize == 18)
    #expect(t.titleFont.pointSize == 44 && t.titleFont.fontName.contains("Light"))   // 2.45 × 18, rounded
    #expect(t.subtitleFont.pointSize == 16)                                          // 0.9 × 18, rounded
    #expect(t.chapterLabelFont.pointSize == 11 && abs(t.chapterLabelKern - 0.22 * 11) < 0.01)
    #expect(t.sectionHeadingFont.pointSize == 17)                                    // 0.94 × 18, rounded
    #expect(t.verseNumberFont.pointSize == 10.5)
    #expect(t.verseNumberColor == Palette.inkVerse.platformColor && t.chapterLabelColor == Palette.inkVerse.platformColor)
    #expect(t.verseNumberColorOnMark == nil)
}
@Test func studyUsesAccentNumbersWithASecondaryFallbackOnMarks() {
    var p = ReaderPreferences.default; p.style = .study
    let t = ReaderTypography.styled(p)
    #expect(t.verseNumberColor == Palette.accent.platformColor && t.verseNumberColorOnMark == Palette.inkSecondary.platformColor)
    #expect(t.sectionHeadingFont.familyName != t.bodyFont.familyName)                // SF Pro semibold at 0.83 ×
}
@Test func lecternAndClassicFaces() // lectern body Iowan, numbers Iowan in ink.secondary at 0.62 ×; classic New York, numbers ink.secondary
@Test func aFaceOverrideKeepsTheStylesArrangement() { var p = ReaderPreferences.default; p.face = .charter; let t = ReaderTypography.styled(p); #expect(t.style == .printed && t.chapterLabelColor == Palette.inkVerse.platformColor) }
@Test func columnWidthScalesTheMeasure() // narrow/normal/wide at 18 → 544/640/736
@Test func sizeRangeReaches28() { #expect(ReaderSettings.clampedFontSize(30) == 28) }
@Test func preferencesLoadFromDefaultsWithFallbacks() // unknown raw values fall back to .default's
@Test func tastePreferencesSyncAndDeviceOnesDoNot() // SyncedPreferences.keys contains pageStyleKey…justifiedKey, not fontSizeKey/lineSpacingKey/columnWidthKey/appearanceKey
```

- [ ] **Step 2–4:** `--filter "PageStyleTests|ReaderSettingsTests|PreferenceSyncTests"` FAIL → implement (values from `DESIGN.md` section 3, Page Styles, each derived from the reader size) → PASS; both apps build.
- [ ] **Step 5: Commit** (`feat: page styles, reader preferences, styled typography`)

---

### Task 6: `ChapterLayout` learns headings and the new options

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterLayout.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderRole.swift`
- Test: `Tests/ScriptureUITests/ChapterLayoutTests.swift`

**Interfaces:**
- Produces: `public enum ReaderRole: Hashable, Sendable { case title, subtitle, ornament, chapterLabel(Int), sectionHeading, dropNumeral(Int), rule }` and `extension NSAttributedString.Key { static let readerRole }` (value is a `ReaderRoleBox` NSObject wrapper). `ChapterLayout.build(verses: [Verse], headings: [Int: [SectionHeading]] = [:], typography: ReaderTypography = .default) -> ChapterLayout`.
- Rules: with `typography.showsSectionHeadings`, each heading for verse *n* is its own paragraph (role `.sectionHeading`, `sectionHeadingFont/Color/Alignment`, `paragraphSpacingBefore = size` except the chapter's first paragraph, `paragraphSpacing = round(0.45 × size)`) inserted before verse *n*; the verse after a heading starts as `.opening`. `!showsVerseNumbers` → empty `numberRange` (location at the text start, length 0) and no number glyphs. `versePerLine` → every verse starts a paragraph, kind `.opening` (no indent), poetry unchanged. `justified` → prose paragraphs `.justified` with `hyphenationFactor = 0.9`; poetry stays natural.

- [ ] **Step 1: Failing tests** (keep every existing test; they use the defaults)

```swift
@Test func aHeadingIsItsOwnParagraphOutsideEverySpan() {
    let l = ChapterLayout.build(verses: john1(1...8), headings: [6: [SectionHeading(text: "The Witness of John", level: 1)]], typography: .styled(.default))
    let s = l.attributedString.string as NSString
    let h = s.range(of: "The Witness of John")
    #expect(h.location != NSNotFound && !l.spans.contains { NSIntersectionRange($0.fullRange, h).length > 0 })
    #expect(s.substring(with: l.span(forVerse: 6)!.textRange) == john1(6...6)[0].text)
}
@Test func headingsHiddenLeaveTheOldText() // showsSectionHeadings = false → identical string to build(verses:) without headings
@Test func versesWithoutNumbersKeepTheirOffsets() // every textRange substring == verse text; no digits before verse 2
@Test func versePerLineBreaksEveryVerse() // a "\n" precedes every verse's numberRange but the first
@Test func justifiedProseHyphenates() // paragraph style alignment .justified, hyphenationFactor > 0 for a prose verse; poetry .natural
```

- [ ] **Step 2–4:** `--filter ChapterLayoutTests` FAIL → implement → PASS.
- [ ] **Step 5: Commit** (`feat: chapter layout with section headings, verse-per-line, hidden numbers, justification`)

---

### Task 7: `BookLayout`, `BookDecorations`, `RunningHead` and `BookWindow`

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/BookLayout.swift`, `BookDecorations.swift` (replaces `ChapterDecorations.swift`; move `DecorationStyle` and `RangeDecoration` into it), `RunningHead.swift`, `BookWindow.swift`
- Modify: `MarkupItem.swift` (add `public let chapter: Int`, set from `Highlight.chapter`), every `MarkupItem(...)` call site
- Test: `Tests/ScriptureUITests/BookLayoutTests.swift`, `BookDecorationsTests.swift` (port `ChapterDecorationsTests`), `RunningHeadTests.swift`, `BookWindowTests.swift`

**Interfaces:**
- Produces:
  - `public struct BookOpening: Equatable, Sendable { public let bookName: String; public let title: BookTitle }`
  - `public struct BookChapterInput: Equatable, Sendable { public let location: ChapterLocation; public let verses: [Verse]; public let headings: [Int: [SectionHeading]] }`
  - `public struct BookSection: Equatable, Sendable { public let location: ChapterLocation; public let range: NSRange; public let openingRange: NSRange; public let spans: [VerseSpan] }`
  - `public struct BookLayout: @unchecked Sendable { let attributedString: NSAttributedString; let sections: [BookSection]; let spans: [VerseSpan]; let id: BookLayoutID; static func build(chapters: [BookChapterInput], opening: BookOpening, typography: ReaderTypography) -> BookLayout; func section(for chapter: Int) -> BookSection?; func section(containing index: Int) -> BookSection?; func span(for: VerseLocation) -> VerseSpan?; func span(containing index: Int) -> VerseSpan? /* binary search */; func firstVisibleVerse(fromLineStart: Int) -> VerseLocation? /* a line inside an opening resolves to that chapter's first verse */; func offsetWithinVerse(of: Int) -> (span: VerseSpan, offset: Int)?; var chapters: ClosedRange<Int> }`
  - `public struct BookLayoutID: Hashable, Sendable { public let book: String; public let translationID: String; public let chapters: ClosedRange<Int>; public let typography: Int /* hash of ReaderTypography */ }`
  - `public struct BookDecorations: Equatable, Sendable { static let none; var highlights: [RangeDecoration]; var bookmarks: [VerseLocation]; var outlinedID: UUID?; static func build(itemsByChapter: [Int: [MarkupItem]], bookmarksByChapter: [Int: [Int]], outlinedID: UUID?, viewingTranslationID: String, layout: BookLayout) -> BookDecorations }` (the existing per-chapter rules, spans looked up by `VerseLocation`).
  - `public struct ChapterBand: Equatable, Sendable { public let chapter: Int; public let openingMinY: CGFloat; public let openingMaxY: CGFloat; public let textMaxY: CGFloat }`; `public struct RunningHeadState: Equatable, Sendable { public let chapter: Int; public let progress: Double; public let headOpacity: Double }`; `public enum RunningHead { public static let fadeDistance: CGFloat = 60; public static func state(bands: [ChapterBand], headLineY: CGFloat, bookOpensInWindow: Bool, atDocumentEnd: Bool) -> RunningHeadState? }`. Chapter in view: the last band whose `openingMinY <= headLineY`, else the first. Progress: `(headLineY − openingMaxY) / (textMaxY − openingMaxY)` clamped 0…1, forced to 1 when `atDocumentEnd` and it is the last band. `headOpacity`: 1 unless `bookOpensInWindow` and the first band is chapter 1, then `clamp((headLineY − (openingMaxY − fadeDistance)) / fadeDistance)`.
  - `public enum BookWindow { public static var verseBudget: Int; public static let edgeDistanceInScreens: CGFloat = 1.5; public static func initial(around chapter: Int, verseCounts: [Int: Int]) -> ClosedRange<Int>; public static func extended(_ window: ClosedRange<Int>, toward edge: BookEdge, chapterCount: Int) -> ClosedRange<Int>? }`, `public enum BookEdge: Sendable { case top, bottom }`. `initial` adds whole chapters alternately below then above the target until the window holds `verseBudget` verses or the book. `verseBudget` starts at `Int.max` (whole book); Task 8 sets it.
- Opening paragraphs per style (from `DESIGN.md` Page Styles): chapter 1's opening, only when the window starts at chapter 1, is Printed title + subtitle + `CHAPTER 1`; Lectern small-caps name + italic subtitle + ornament (`· · ·` in `ink.rule`), then a `.dropNumeral(1)` marker on the first paragraph with verse 1's number suppressed; Study uppercase subtitle label + `John 1` (chapter number in `ink.tertiary`) + a `.rule` paragraph; Classic `John 1` in Display + italic subtitle. Later chapters: Printed `CHAPTER n`; Lectern `.dropNumeral(n)` only; Study `JOHN n` label; Classic `John n` at `.headline` size of the page face. Spacing above a later chapter's opening `round(2.4 × size)`, below `round(1.2 × size)`.

- [ ] **Step 1: Failing tests**

```swift
@Test func everyVerseOfEveryChapterKeepsItsText() { // John 1–3 fixture; for each span: substring(textRange) == its verse text
}
@Test func openingsAreOutsideSpansAndTagged() { // CHAPTER 2 label has role .chapterLabel(2); no span intersects any section.openingRange }
@Test func theTitleBlockAppearsOnlyWhenTheWindowStartsAtChapterOne() // build(chapters: 2...3) contains no "The Gospel According to John"
@Test func spansAreFoundByChapterAndVerse() { #expect(layout.span(for: VerseLocation(book: "JHN", chapter: 2, verse: 3))!.location.chapter == 2) }
@Test func aLineStartInsideAnOpeningIsThatChaptersFirstVerse()
@Test func firstAndLastVerseHighlightsLandOnTheirWords() { // Review Focus 1
    // items on JHN 1:51 (last) and 2:1 (first) with offsets 4…12; BookDecorations ranges' substrings == the words
}
@Test func bookmarksCarryTheirChapter() // bookmarksByChapter [2: [1]] → [VerseLocation(JHN,2,1)]
@Test func headIsInvisibleAtTheBookTopAndFullAtTheLabel() // bands; headLineY far above label → 0; at openingMaxY → 1
@Test func headNamesTheChapterWhoseOpeningReachedTheLine()
@Test func progressRestartsPerChapterAndEndsAtOne() // 0 at a label, 0.5 midway, 1 when atDocumentEnd
@Test func windowGrowsAroundTheTargetToTheBudget() { BookWindow.verseBudget = 100; #expect(BookWindow.initial(around: 3, verseCounts: [1: 51, 2: 25, 3: 36, 4: 54]) == 2...4) }
@Test func windowStopsAtTheBooksEnds() // extended(1...2, toward: .top, chapterCount: 21) == nil
```

- [ ] **Step 2–4:** `--filter "BookLayoutTests|BookDecorationsTests|RunningHeadTests|BookWindowTests"` FAIL → implement → PASS. Delete `ChapterDecorationsTests` once ported. The rest of the package will not compile until Tasks 11 and 13; do this task's work so the four new suites build (temporarily keep `ChapterDecorations` as a typealias to `BookDecorations` only if needed to compile, and remove it in Task 11).
- [ ] **Step 5: Commit** (`feat: book layout, decorations, running head and window policy`)

---

### Task 8: Measure, and set the window budget

**Files:**
- Modify: `Tests/ScriptureUITests/ReaderBenchmarkTests.swift`, `BenchmarkChapter.swift`
- Modify: `BookWindow.swift` (the measured `verseBudget`)

**Interfaces:** Consumes `BibleStore.bookChapters` (Task 2), `BookLayout.build` (Task 7). Produces the constant `BookWindow.verseBudget`.

- [ ] **Step 1: Write the benchmarks** (skip when `Build/bible.sqlite` is missing, as `ChapterTextControllerMarkupTests` does)

```swift
@Test func psalmsBookLayoutBuildAndFullTextKitLayout() // build BookLayout for all of Psalms (ESV, 18 pt, Printed); lay it out fully in an NSTextView of width 640 the way ChapterTextController.sizeToLayout does; print "benchmark psalms-build" and "benchmark psalms-layout" ms
@Test func genesisAndJohnLikewise()
```

- [ ] **Step 2: Run in Release-like conditions and record**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Packages/ScriptureKit --filter ReaderBenchmarkTests`
Expected: the printed medians. Record them in this plan under "Measured" below.

- [ ] **Step 3: Set the budget.** If Psalms builds and lays out in ≤ 250 ms release, `verseBudget = Int.max` (whole book always). Otherwise `verseBudget` = the verse count that lays out in 150 ms (linear from the Psalms figure), rounded down to a multiple of 50, minimum 300. Add `@Test func aWindowAtTheBudgetLoadsWithinTheChapterCeiling()` asserting build + layout of a `verseBudget` window of Psalms stays under 100 ms debug (the existing ceiling convention).
- [ ] **Step 4: Run** `--filter ReaderBenchmarkTests` — PASS.
- [ ] **Step 5: Commit** (`perf: measure whole-book layout and set the reader's window budget`)

Measured (ESV, Printed 18 pt, 640 wide, median of 5 runs each, `swift test -c release`; build + full TextKit 2 layout): Psalms 2461 verses 29.8 + 203.6 = 233.4 ms; Genesis 1533 verses 18.2 + 67.1 = 85.3 ms; John 878 verses 10.2 + 32.9 = 43.1 ms. Debug medians: Psalms 42.2 + 210.3 = 252.5 ms, Genesis 22.6 + 66.9, John 11.6 + 34.1. Psalms is under 250 ms release, so `verseBudget = Int.max` (whole book always); the budget-window ceiling test applies only to the other branch and was not added.

---

### Task 9: `NavigationModel` reads a book at a time

**Files:**
- Modify: `Sources/ScriptureUI/NavigationModel.swift`, `NavigationHistory.swift`, `ScrollTarget.swift`, `Sources/ScriptureData/Models.swift` (`BookText`)
- Test: `Tests/ScriptureUITests/NavigationModelTests.swift`, `NavigationHistoryTests.swift`

**Interfaces:**
- Produces:
  - `public struct BookText: Sendable { public let book: String; public let translationID: String; public let chapters: [Int: [Verse]] }` with `Equatable` by `book` and `translationID` only (the text for a pair never changes).
  - `ScrollTarget(chapter: Int, verse: Int)` replaces `ScrollTarget(verse:)`; `public let chapter: Int`.
  - `NavigationModel.bookText: BookText?` (reloaded only when the book or translation changes); `location` and `verses` are the chapter in view (`verses = bookText.chapters[location.chapter]`).
  - `NavigationModel.reportReadingPosition(_ verse: VerseLocation)` replaces `reportFirstVisibleVerse(_:)`: a new chapter in the same book updates `location`, `verses`, `firstVisibleVerse`, `history.updateCurrentLocation(_:verse:)` and the stored position — no reload, no history push.
  - `NavigationHistory.updateCurrentLocation(_ location: ChapterLocation, verse: Int)`.
  - `goToNextChapter()` / `goToPreviousChapter()`: within the book, a history push and `scrollTarget = ScrollTarget(chapter: n ± 1, verse: 1)` with `bookText` unchanged; at either end, `open` the neighbouring book's first (next) or last (previous) chapter, as today.
  - `NavigationModel.nextBook: ChapterLocation?` (chapter 1 of the next book, nil at Revelation) and `nextBookTitle: String?`.
  - `reportLinesScrolledSinceJump` ends a lookup when `place.location.book == location.book && place.translationID == translationID` (was: same chapter).

- [ ] **Step 1: Failing tests** (port the existing ones that call `reportFirstVisibleVerse`/`ScrollTarget(verse:)`)

```swift
@Test func openingAChapterLoadsItsBook() { model.open(JHN3); #expect(model.bookText?.book == "JHN" && model.verses == model.bookText?.chapters[3]) }
@Test func scrollingIntoTheNextChapterMovesThePlaceWithoutHistory() {
    model.open(JHN3); model.reportReadingPosition(VerseLocation(book: "JHN", chapter: 4, verse: 2))
    #expect(model.location == JHN4 && positionStore.load()?.chapter == 4 && !model.canGoBack)
}
@Test func nextWithinTheBookScrollsAndPushesHistory() { model.open(JHN3); model.goToNextChapter(); #expect(model.scrollTarget?.chapter == 4 && model.canGoBack) }
@Test func nextAtTheEndOfABookOpensTheNext() // JHN 21 → ACT 1
@Test func backAfterScrollingThroughThreeChaptersReturnsBeforeTheBook() // open MAT 5, open JHN 1, scroll-report 2,3,4 → goBack → MAT 5
@Test func backAfterNextThreeTimesStepsAChapterAtATime()
@Test func aLookupInTheSameBookEndsAfterFiveLines() // reading JHN 3, lookUp JHN 6:2, report 5 lines → lookupReturn == nil
@Test func aLookupIntoAnotherBookStaysALookup() { // Review Focus 5
    // reading JHN 3, lookUp ROM 8:1, report 40 lines → lookupReturn != nil; keepLookup() ends it
}
@Test func switchingTranslationKeepsChapterAndVerse() // ESV JHN 4:7 → ERV; scrollTarget == (4, 7) and location == JHN4
```

- [ ] **Step 2–4:** `--filter "NavigationModelTests|NavigationHistoryTests"` FAIL → implement → PASS.
- [ ] **Step 5: Commit** (`feat: navigation reads a book at a time and follows the chapter in view`)

---

### Task 10: `ReaderDocument`

**Files:**
- Create: `Sources/ScriptureUI/ReaderDocument.swift`
- Test: `Tests/ScriptureUITests/ReaderDocumentTests.swift`

**Interfaces:**
- Consumes: `BookText` (Task 9), `BibleStore.headings/bookTitle` (Task 2), `BookLayout`, `BookWindow` (Task 7), `ReaderTypography` (Task 5).
- Produces: `@MainActor @Observable public final class ReaderDocument { public init(store: BibleStore); public private(set) var layout: BookLayout?; public private(set) var window: ClosedRange<Int>?; public func show(_ book: BookText, target: ChapterLocation, typography: ReaderTypography); public func extend(_ edge: BookEdge) -> Bool; public var includesBookEnd: Bool }`. `show` rebuilds only when the book, translation or typography changed, or the target lies outside the window (then the window is re-centred with `BookWindow.initial`). Headings and the title are fetched once per book and translation.

- [ ] **Step 1: Failing tests**

```swift
@Test func showingAChapterInsideTheWindowDoesNotRebuild() // layout.id identical after show(target: another chapter in the window)
@Test func showingOutsideTheWindowRecentres()
@Test func extendingAddsOneChapterAndKeepsTheRest() // window 3...5 → extend(.top) → 2...5, sections for 3…5 have the same text
@Test func extendingPastTheEndFails() // window ending at the last chapter → extend(.bottom) == false, includesBookEnd
@Test func typographyChangeRebuildsTheSameWindow()
```

- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5: Commit** (`feat: ReaderDocument builds and grows the book window`)

---

### Task 11: Markup on a book window

**Files:**
- Modify: `Sources/ScriptureUI/MarkupModel.swift`, `SelectionResolver.swift`, `ReaderTextLogic.swift`, `MarginMarks.swift`, `MarkupGutterView.swift`, `MarkupContextMenu.swift:70-72`, `Phone/PhoneMarkupMenu.swift:125-126`, `MarkupTarget.swift` (`MarkupNavigation`)
- Delete: the `ChapterDecorations` typealias if Task 7 left one
- Test: `MarkupModelTests`, `SelectionResolverTests`, `ReaderTextLogicTests`, `MarginMarksTests`, `MarkupNavigationTests`, `PenModelTests`

**Interfaces:**
- Consumes: `BookLayout`, `BookDecorations` (Task 7).
- Produces:
  - `MarkupModel.load(book: String, chapters: ClosedRange<Int>, chapterInView: ChapterLocation, translationID: String)` replaces `load(chapter:translationID:verses:)`; loads per chapter through the existing `MarkupStore.highlights(in:)`, `notes(in:)`, `bookmarks(in:)`; exposes `itemsByChapter: [Int: [MarkupItem]]`, `bookmarksByChapter: [Int: [Int]]`, `notesByChapter: [Int: [NoteCard]]`. `items`, `bookmarkVerses`, `columnItems`, `chapterNotes` remain and describe `chapter` (the chapter in view).
  - `MarkupModel.setLayout(_ layout: BookLayout?)`; `decorations: BookDecorations` builds from it.
  - `MarkupModel.setChapterInView(_ location: ChapterLocation)`: rebuilds the column for that chapter; while `editingNoteID != nil` it is remembered and applied when `endEditing` runs. Never clears the selection, outline or an edit (only `load` does, and only when the book or translation changes).
  - `matchesLoadedChapter` → the target's book is loaded and its chapter is in the window.
  - Bookmark checks use `bookmarksByChapter[report.selection.chapter]`.
  - `SelectionResolver.resolve(_ range: NSRange, in layout: BookLayout) -> TextSelection?` (verse text read from the layout's string; book and chapter from the section of `range.location`; the range clamped to that section's spans). `ReaderTextLogic.report(for:layout:decorations:)` and `snapToWords(_:in:)` take `BookLayout`; snapping never crosses an opening.
  - `MarginMark.verse: VerseLocation`, ids `"bookmark:<chapter>:<verse>"`/`"note:<uuid>"`; `MarginMark.build(notesByChapter:itemsByChapter:bookmarksByChapter:layout:)`. `MarkupGutterView.glyphVerses: [VerseLocation]`, label "Bookmark, chapter C verse V".

- [ ] **Step 1: Failing tests** (port the existing ones to `BookLayout`; add)

```swift
@Test func aSelectionAcrossAChapterLabelClampsToItsFirstChapter() // range from JHN 1:50 into 2:2 → TextSelection chapter 1, endVerse 51
@Test func scrollingIntoAnotherChapterWhileEditingKeepsTheNote() { // Review Focus 4
    model.beginEditing(noteID: n); model.setChapterInView(JHN2)
    #expect(model.editingNoteID == n && model.chapter == JHN1); model.endEditing(noteID: n); #expect(model.chapter == JHN2)
}
@Test func bookmarkMenuChecksTheSelectionsChapter() // bookmark at 2:1 only; a selection in 1:1 offers "Bookmark", in 2:1 "Remove Bookmark"
@Test func marginMarksInTwoChaptersHaveDistinctIDs()
@Test func showingANoteInAnotherChapterOfTheLoadedWindowFocusesItWithoutReload()
```

- [ ] **Step 2–4:** run the listed suites → FAIL → implement → PASS.
- [ ] **Step 5: Commit** (`feat: markup across a window of chapters`)

---

### Task 12: The assistant follows the chapter in view

**Files:**
- Modify: `Sources/ScriptureUI/AssistantModel.swift` (`setLocation`, `createThread`), `Apps/Mac/ReadingThroughScripture/MainWindowView.swift:87-90`, `Sources/ScriptureUI/Phone/PhoneReaderScreen.swift:90-96`
- Test: `Tests/ScriptureUITests/AssistantModelTests.swift`

**Interfaces:** `setLocation(_ chapter: ChapterLocation?, translationID: String, verses: [Verse], byScrolling: Bool = false)`. With `byScrolling`, an open chapter-scoped conversation stays open on the chapter it was started in (no close), and new chapter prompts and Ask About This Chapter use the new chapter. `createThread` for a selection stores the selection's own chapter.

- [ ] **Step 1: Failing tests**

```swift
@Test func scrollingKeepsAnOpenChapterConversation() // open JHN 3 thread; setLocation(JHN4, byScrolling: true) → thread still open, scope chapter 3
@Test func askAboutChapterAfterScrollingUsesTheNewChapter() // compose uses JHN 4's text
@Test func aSelectionThreadIsSavedOnItsOwnChapter()
```

- [ ] **Step 2–4:** `--filter AssistantModelTests` FAIL → implement → PASS.
- [ ] **Step 5: Commit** (`feat: the assistant follows the chapter in view without dropping a conversation`)

---

### Task 13: The Mac text controller renders a book window

**Files:**
- Modify: `Sources/ScriptureUI/ChapterTextController.swift`, `ChapterTextView.swift`
- Test: `Tests/ScriptureUITests/ChapterTextControllerTests.swift`, `ChapterTextControllerMarkupTests.swift`, `ReaderBenchmarkTests.swift`

The class keeps its name (tests and call sites are many); its doc comment says it shows a window of a book's chapters.

**Interfaces:**
- Consumes: `BookLayout`, `BookDecorations`, `RunningHead`, `BookWindow`, `ScrollTarget(chapter:verse:)`.
- Produces: `update(layout: BookLayout?, scrollTarget: ScrollTarget?, decorations: BookDecorations)`; callbacks `onReadingPositionChange: (VerseLocation) -> Void` (replaces `onFirstVisibleVerseChange`), `onRunningHeadChange: (RunningHeadState) -> Void` (replaces `onProgressChange`), `onNeedsChapters: (BookEdge) -> Void`, `onScrollSinceJump` unchanged; `headLineY: CGFloat` (the running head strip's height, set by the view; 0 means the clip's top).
- Behavior:
  - Text replaced only when `layout.id` changes. When the new id has the same book, translation and typography and its chapters are a superset of the old (a window extension), keep the reading position: remember the first visible verse and its offset from the clip top, replace, size, and restore that offset exactly (no scroll animation).
  - `onNeedsChapters(.top/.bottom)` fires when the clip is within `BookWindow.edgeDistanceInScreens` clip heights of the document's top or bottom and the window can grow that way (once per layout id).
  - Scrolling to a target with chapter > window or < window is the document's job (it re-centres); the controller scrolls to `layout.span(for:)`, a target at verse 1 scrolls to that section's `openingRange` top.
  - Chapter bands from each section's opening and text line fragments; `RunningHead.state` on every scroll; the book opening's chapter label alpha set as a rendering attribute to `1 − headOpacity`.
  - Selection reports through `ReaderTextLogic.report(for:layout:decorations:)`; text in an opening is never part of a selection report.
  - Decorations applied only for sections that intersect the laid-out viewport ± one screen.
  - In Study, a verse number inside a highlight's range draws in `typography.verseNumberColorOnMark` (rendering attribute).

- [ ] **Step 1: Failing tests** (port the ~40 existing tests to `update(layout:…)` and `VerseLocation` reports; add)

```swift
@Test func extendingTheWindowUpwardKeepsTheTextStill() { // Review Focus 2
    // load John 3…5, scroll so 3:16 is 120 pt below the clip top, update with John 2…5 → 3:16 still 120 ± 0.5 pt below
}
@Test func scrollingToTheTopAsksForEarlierChapters() // onNeedsChapters(.top) once
@Test func theHeadNamesTheChapterUnderItsLine() // scroll so chapter 4's label passes headLineY → last state.chapter == 4, progress ≈ 0
@Test func theBookOpeningFadesIntoTheHead() // at top: headOpacity 0; after scrolling the CHAPTER 1 label to the line: 1
@Test func switchingToERVKeepsChapterAndVerse() // Review Focus 3, real data; skip without Build/bible.sqlite
@Test func oldHighlightsOnChapterEdgesStillCoverTheirWords() // Review Focus 1, through the controller's background fills
```
Port the benchmarks: Psalm 119 *inside* a Psalms window at the budget, sixty highlights, under the existing 100 ms ceiling.

- [ ] **Step 2–4:** `--filter "ChapterTextController|ReaderBenchmarkTests"` FAIL → implement → PASS.
- [ ] **Step 5: Commit** (`feat: the Mac reader scrolls a window of the book`)

---

### Task 14: The Mac reader view: running head, chapter marks, end of book, Text & Layout

**Files:**
- Modify: `Sources/ScriptureUI/ReaderView.swift`, `ChapterNoteMark.swift` (chapter-aware label), `ReadingProgressLine.swift`
- Create: `Sources/ScriptureUI/RunningHeadView.swift`, `Sources/ScriptureUI/TextLayoutPopover.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/MainWindowView.swift` (wire `ReaderDocument`, markup `setLayout`/`setChapterInView`, assistant `byScrolling`, window title from the chapter in view, the toolbar `textformat.size` button with ⌘T opening the popover), the Go menu's commands if they live in the app (Previous/Next Chapter call the new jumps)
- Test: `Tests/ScriptureUITests/ChapterNoteMarkTests.swift`; the rest is verified by running the app

**Interfaces:**
- `ReaderView(document: ReaderDocument, …)` takes the document instead of `title`/`verses`; it owns the running-head strip (height `AppSpacing.xl` + the label's line height, on `paper.page`, the text scrolls beneath it with a 14 pt `paper.page` → clear fade like the mockup), `ReadingProgressLine` under the strip fed by `RunningHeadState.progress`, and the strip's opacity from `headOpacity`. The strip's text is `typography.style.runningHead(bookName:chapter:)` in the chapter-label voice; a click goes to the chapter grid; its context menu offers Ask About This Chapter; a `ChapterNoteMark` for the chapter in view at its trailing end.
- Each chapter's opening line carries a `ChapterNoteMark` at its trailing end when that chapter has chapter notes: an overlay subview of the text view positioned from `section.openingRange`'s last line fragment, like the gutter glyphs (count from `markup.notesByChapter`, chapter notes only).
- Footer: only while the chapter in view is the book's last and the window includes it — "Next: Acts" with `arrow.right`, trailing, as today's footer link; nothing at the top of a book.
- VoiceOver: the running head strip is a header element ("John, chapter 3"); in the text view, section headings and chapter openings are reachable through a "Headings" custom rotor (`NSAccessibilityCustomRotor` over the `readerRole` ranges), and the gutter and chapter-note marks keep their labels.
- `TextLayoutPopover`: the mockup's controls (four style tiles each "Aa" in its face, Font menu with "The style's font" first, Size slider 14–28 with A/A, Line spacing, Column width, Layout segmented, three toggles, Appearance System/Light/Sepia/Dark), all `@AppStorage` on Task 5's keys. System controls in semantic styles.

- [ ] **Step 1: Failing test** — `@Test func chapterNoteMarkNamesItsChapter() { #expect(ChapterNoteMark.label(2, chapter: "John 3") == "2 chapter notes in John 3") }`
- [ ] **Step 2–4:** FAIL → implement → PASS; build the Mac app.
- [ ] **Step 5: Run the Mac app** (Debug) and check: John 1 in Printed as the mockup; scroll into John 2 (head, line, window title, notes column follow); John 21's footer offers Acts; ⌘T opens Text & Layout and every control changes the page at once; ⌥⌘→ jumps to the next chapter label.
- [ ] **Step 6: Commit** (`feat: Mac running head, per-chapter marks, end-of-book link and Text & Layout`)

---

### Task 15: The iPhone text controller renders a book window

**Files:**
- Modify: `Sources/ScriptureUI/Phone/PhoneChapterTextController.swift`, `PhoneChapterTextView.swift`
- Create: `Tests/ScriptureUITests/PhoneChapterTextControllerTests.swift` (iOS-only, `#if os(iOS)`; run on the simulator through `xcodebuild test` with the iOS scheme)

**Interfaces:** the same contract as Task 13: `update(layout: BookLayout?, scrollTarget: ScrollTarget?, decorations: BookDecorations, marginMarks: [MarginMark], footer: UIView?)` (the header accessory goes; openings are in the text), `onReadingPositionChange`, `onRunningHeadChange`, `onNeedsChapters`, `headLineY` = the navigation bar's bottom in the text view's coordinates. Chapter-note marks at each chapter's opening as buttons placed like margin marks. The pen's `isPaintable` excludes every opening range. `ReaderPageView.accessibilityElements` orders text, marks, footer; section headings and chapter openings are reachable through a "Headings" `UIAccessibilityCustomRotor` over the `readerRole` ranges, and the bar title reads as "John, chapter 3".

- [ ] **Step 1: Failing tests** — the four behaviors from Task 13's list that have UIKit equivalents: `extendingTheWindowUpwardKeepsTheTextStill`, `theHeadNamesTheChapterUnderItsLine`, `paintingNeverStartsInAnOpening`, `marginMarksAppearInEveryLoadedChapter`.
- [ ] **Step 2–4:** run with `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -only-testing:ScriptureUITests/PhoneChapterTextControllerTests` (add the package test target to the iOS scheme's test action if it is not there) → FAIL → implement → PASS.
- [ ] **Step 5: Commit** (`feat: the iPhone reader scrolls a window of the book`)

---

### Task 16: The iPhone reader screen: bar title as running head, trimmed menu

**Files:**
- Modify: `Sources/ScriptureUI/Phone/PhoneReaderScreen.swift` (heading/footer accessories, `ChapterKey`, `PhoneChapterTitle`, the `ellipsis` menu), `PhoneShellModel.swift`, `PhoneSettingsScreen.swift`
- Test: `Tests/ScriptureUITests/PhoneShellModelTests.swift`

**Interfaces:**
- `PhoneChapterTitle(title: String, translation: String, progress: Double, opacity: Double)`: `title = typography.style.runningHead(...)` for the chapter in view (Printed: "JOHN · CHAPTER 3" in the label voice; the translation beneath as now); `opacity = headOpacity`, so it is hidden while John 1's title block is on screen and appears as it scrolls under the bar; the progress line restarts per chapter. No second strip.
- The `ellipsis` menu: Page Style (picker submenu), Text Size (Smaller/Larger, as now), Line Spacing (picker submenu), Appearance (System/Light/Sepia/Dark picker submenu), More Settings… — then the existing translation, Notes in This Chapter and Settings items.
- `PhoneShellModel.settingsDestination: SettingsDestination?` (`enum SettingsDestination { case reading }`); More Settings… sets it and `isSettingsShown`; `PhoneSettingsScreen` pushes Reading when set.
- Footer accessory: "Next: Acts →" only while the window includes the book's last chapter.

- [ ] **Step 1: Failing test** — `@Test func moreSettingsOpensReading() { shell.openMoreSettings(); #expect(shell.isSettingsShown && shell.settingsDestination == .reading) }`
- [ ] **Step 2–4:** FAIL → implement → PASS; build the iOS app.
- [ ] **Step 5: Run on the simulator** (`-phoneSeed YES`): John opens, the bar title appears as the title block scrolls away, changes at CHAPTER 2, the line restarts; the menu has exactly the five reading items before the others; More Settings… opens Reading.
- [ ] **Step 6: Commit** (`feat: iPhone running head in the bar and a trimmed reader menu`)

---

### Task 17: Settings › Reading on both apps

**Files:**
- Modify: `Sources/ScriptureUI/ReadingSettingsView.swift`
- Test: `Tests/ScriptureUITests/ReaderSettingsTests.swift`

**Interfaces:** sections Page (style picker with the four tiles; Font menu), Text (Size 14–28, Line spacing, Column width — Mac only), Layout (Paragraphs / Verse per line, Verse numbers, Section headings with the footer "Headings from the Berean Standard Bible.", Justify text), Appearance (System/Light/Sepia/Dark). Same `@AppStorage` keys as Task 5 and the popover.

- [ ] **Step 1: Failing test** — `@Test func sectionHeadingsFooterNamesTheSource() { #expect(ReadingSettingsView.headingsFooter == "Headings from the Berean Standard Bible.") }`
- [ ] **Step 2–4:** FAIL → implement → PASS; both apps build; each control changes the open reader at once.
- [ ] **Step 5: Commit** (`feat: Settings › Reading with page style, font, layout and visibility`)

---

### Task 18: Sepia

**Files:**
- Modify: `Sources/ScriptureUI/Palette.swift` (`ColorToken.sepia`, resolution), `ReaderSettings.swift` (`AppearanceChoice.sepia`), `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift:137`, `Apps/iOS/ReadingThroughScripture/ReadingThroughScriptureApp.swift`
- Test: `Tests/ScriptureUITests/PaletteTests.swift`, `ReaderSettingsTests.swift`

**Interfaces:**
- `ColorToken.init(_:light:dark:lightHighContrast:darkHighContrast:sepia:)` with `sepia: String?`; `hex(dark:highContrast:sepia:)` returns the sepia value when `sepia && !dark` (ink tokens with `highContrast` use their light high-contrast value; papers keep sepia). Sepia values: `paper.page #F4ECDD`, `paper.panel #ECE2CF`, `paper.overlay #F9F3E8`, `ink.primary #2B2219`, `ink.secondary #6A5B49`, `ink.tertiary #9A8B78`, `ink.rule #DCCFB8` (adjust only as far as Step 1's tests demand, and update `DESIGN.md` section 2 with the final values).
- `public enum SepiaMode { @MainActor public static func set(_ on: Bool) }`: on macOS a lock-protected static that the `NSColor` provider reads for the light appearance, then reassigns `NSApp.appearance` (aqua) to force every window to redraw; on iOS a custom `UITraitDefinition` (`SepiaTrait`, Bool) set on every window scene's `traitOverrides`, read by the `UIColor` provider.
- `AppearanceChoice.sepia`: colorScheme `.light`, `nsAppearance` aqua, and calls `SepiaMode.set(true)`; every other choice `SepiaMode.set(false)`.

- [ ] **Step 1: Failing tests** — extend `PaletteTests.appearances` with sepia (and sepia + high contrast) so every existing pairing runs in Sepia; add `@Test func marksStayReadableOnSepia()` (primary ink on every default mark's light hex ≥ 10:1 and `ink.verse` ≥ 4.5:1 on sepia page).
- [ ] **Step 2–4:** `--filter "PaletteTests|ReaderSettingsTests"` FAIL → implement → PASS; run both apps in Sepia (page, panels, notes column, Settings all warm; system controls light).
- [ ] **Step 5: Commit** (`feat: Sepia appearance`)

---

### Task 19: The page face beyond the page

**Files:**
- Modify: every SwiftUI view that sets the Quote style (`Font.system(.callout, design: .serif)` italic) or the front page's chapter numerals (`ChapterGridView.swift:168`, `Phone/PhoneLibraryScreen.swift`), and Display uses noted in `DESIGN.md` (`Font.system(.title, design: .serif)`) for the shelf's book names
- Create: `Sources/ScriptureUI/PageFaceEnvironment.swift` (`EnvironmentValues.pageFace`, set at both app roots from `ReaderPreferences.resolvedFace`)
- Test: `Tests/ScriptureUITests/PageFaceTests.swift`

**Interfaces:** `PageFace.quoteFont() -> Font` (`swiftUIFont(.callout, italic: true)`), `PageFace.numeralFont() -> Font` (`.title3`, `.monospacedDigit()`, lining figures), `PageFace.displayFont() -> Font` (`.title`, semibold). Find every call site with `rg 'design: \.serif'` and replace it.

- [ ] **Step 1: Failing test** — `@Test func quoteFontFollowsTheFace()` (the resolved `PlatformFont` behind `PageFace.literata.quoteFont()` is Literata Italic; New York's is the system serif).
- [ ] **Step 2–4:** FAIL → implement → PASS; `rg 'design: \.serif' Packages Apps` finds only `PageFace.swift`.
- [ ] **Step 5: Commit** (`feat: quoted words, numerals and book names follow the page face`)

---

### Task 20: Lectern's drop numeral

**Files:**
- Modify: `ChapterTextController.swift`, `Phone/PhoneChapterTextController.swift`, `BookLayout.swift` (drop-numeral geometry helper)
- Create: `Sources/ScriptureUI/DropNumeral.swift`
- Test: `Tests/ScriptureUITests/BookLayoutTests.swift`, `ChapterTextControllerTests.swift`

**Interfaces:** `public enum DropNumeral { public static func size(for typography: ReaderTypography) -> CGSize /* three body lines tall, lining figures, accent */ ; public static func exclusionRect(firstLineOrigin: CGPoint, numeralSize: CGSize, gap: CGFloat) -> CGRect }`. Each controller, after laying out, sets `textContainer.exclusionPaths` to one rect per `.dropNumeral(n)` paragraph in the window (top-down, re-laying out once), and draws the numeral in an overlay view (Mac: beside the gutter overlay; phone: a non-interactive label) in `Palette.accent`.

- [ ] **Step 1: Failing tests** — `@Test func lecternChapterTextWrapsAroundTheNumeral()` (the first three line fragments of John 3 start right of the numeral's rect; the fourth at the column edge); `@Test func aHighlightOnVerseOneSurvivesTheNumeral()`; `@Test func resizingKeepsTheNumeralOnItsParagraph()`.
- [ ] **Step 2–4:** FAIL → implement → PASS. If exclusion paths cannot be made reliable within this task (wrong wraps after resize or window extension), use the spec's fallback instead: a centred numeral paragraph above the chapter's text (`.dropNumeral` becomes an opening paragraph in `BookLayout`), and record the decision under "Decisions" below.
- [ ] **Step 5: Commit** (`feat: Lectern drop numeral`)

---

### Task 21: Documentation and the verification run

**Files:**
- Modify: `DESIGN.md` (Reader component: running head strip, per-chapter note marks, end-of-book footer; Text & Layout popover under Components; toolbar inventory adds `textformat.size`; remove "not yet built" from Page Styles; Sepia values; DESIGN.json `colorMeta` for any value that moved), `README.md` (the reader section: one scroll per book, the running head, Previous/Next as jumps, settings, the BSB headings note, eBible fetch in the build), `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (milestone 9 entry with the measured numbers)

- [ ] **Step 1:** Update the three documents.
- [ ] **Step 2: Full test run** — `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` → all pass; both app builds succeed.
- [ ] **Step 3: Run the spec's verification list** (spec section 6, items 1–9) on the Mac and the iPhone simulator, Debug build, and record each result (pass, or what was seen) in the main spec's milestone 9 entry. Item 4 uses Instruments' Animation Hitches template on a Release build of the `.dev` identity.
- [ ] **Step 4: Commit** (`docs: milestone 9 recorded`)

---

## Decisions

_(Executors record here any decision a task's fallback or measurement forced, with the date.)_

- **Superseded (2026-11-12): the reader shows one chapter at a time.** The book-long scroll drifted on the Mac (TextKit 2 laid out again, from estimated heights, what had scrolled above the screen, so the text landed far from where the head, the numerals and the page height expected it), and one chapter keeps its layout. What this plan built only to hold a book in one scroll is superseded by `docs/superpowers/plans/2026-11-12-single-chapter-and-quick-hops.md` and its spec, `docs/superpowers/specs/2026-11-12-single-chapter-reader-and-quick-hops-design.md`:
  - **Tasks 7 to 16, the book-window parts:** `BookWindow` and its budget, growing and sliding the window, asking for chapters near its edges, the extension anchor that kept the text still, the running head's hand-over between chapters, the end-of-book link, and markup and the assistant following the chapter in view as the reader scrolled into the next. `BookLayout`, `BookDecorations`, `RunningHead`, the page styles, the bar title, the menus and the markup stay, for one chapter.
  - **Task 20, the book-wide parts:** the numeral's placement across a book of chapters and its views near the viewport; one chapter has one numeral.
  - **Review Focus items 1, 2, 4 and 5:** chapter boundaries inside one scroll, growing the window upward, editing while scrolling into the next chapter, and a lookup that scrolls far. Item 3 (switching translation keeps the verse) still holds.
  - **The whole-Psalms budgets** (load, reflow, scroll, Lectern against Printed): replaced by Psalm 119 alone.
  - Each chapter now ends with its Previous and Next links, as on `main`. The carry-through drawer (the iPhone, pulling past a chapter's end or top) and the book thumb (both apps), planned there, give back the quick movement the long scroll was for.

- **2026-11-12, Task 20: Lectern opens each chapter on a centred numeral, the spec's fallback, not a drop numeral with exclusion paths.** Exclusion paths in the TextKit 2 text container could not be made reliable, measured on the Mac before anything was built on them:
  - **Wrong line heights.** Once the container has any exclusion path (or is any non-rectangular container, a subclass answering `lineFragmentRect(forProposedRect:…)` itself included), TextKit 2 sets every line that begins with a raised verse number short, wherever it is in the book, not only beside the numeral: 24.6 pt instead of 32.5 at 18 pt (Lectern, Normal spacing), 28.5 instead of 32.5 with the paragraph's minimum and maximum line height fixed. The returned line rect's height is ignored. Every rect placed from those lines lands on the wrong line after it, and the page's rhythm breaks throughout the book.
  - **Cost.** Re-laying out whole Psalms (ESV, Lectern, 18 pt) with its 150 exclusion rects took 568–571 ms, against 147 ms for the same re-layout without them and 188–195 ms for the first layout; a container subclass doing the rect lookup itself still took 436 ms. With the first layout, every open, width reflow and typography change on the Mac would have cost about 0.8 s before the scroll, against the 1 s budget, and the phone's window the same in proportion.
  - **What ships.** `BookLayout` gives each Lectern chapter an opening paragraph (role `.dropNumeral(n)`, in `openingRange`, outside every span): the number in the page face's lining figures (`DropNumeral.font`), in `accent`, centred on a line exactly three body lines tall (`DropNumeral.lineHeight`, the face sized so its ascender and descender fill it), with later chapters' 2.4 × size of air above it and none below. Verse 1's number still gives way to it. TextKit draws it like any opening line, so highlights, selection, copy (R8), the pen, the reading-position rules and the chapter-note mark (now on the numeral's line, at the column's trailing edge) need nothing of their own. Lectern whole Psalms now builds in 55 ms and loads at Psalm 119 in 200 ms, reflows in 170 ms (Printed: 49, 220, 185 ms). DESIGN.md's Lectern entry says so.
  - **Found on the way:** on UIKit `withFeatures` named its feature keys with UIKit's crossed old names (`typeIdentifier` is UIKit's *selector* key), so on the iPhone Lectern had neither small capitals nor old-style figures. The keys are now `.type` and `.selector` there.
- **2026-11-12, after Task 21: Lectern's drop numeral ships after all; the centred numeral above is superseded (ruling R16 superseded).** The short lines and the cost both came from the whole container being non-rectangular. `DropZoneContainer` is non-rectangular only while one of a chapter's first paragraphs lays out: a `DropZoneLayoutDelegate` hands TextKit a `DropZoneFragment` for every paragraph, and its `leadingPadding` getter (which TextKit reads as each fragment's layout begins, before it asks the container whether it is a simple rectangle) tells the container which zone is laying out. Outside a zone the container answers `exclusionPaths.isEmpty`, never `super`, because `NSTextContainer` answers false for any subclass that overrides `lineFragmentRect`, which would set the whole book on the slow path. Found on the way: the rects TextKit proposes are in the laying-out fragment's own coordinates, and its frame is unset until it has laid out, so each zone paragraph takes its place below the notch from the chapter's first zone fragment and the fragment above it, read as they are now.
  - **What ships.** Each Lectern chapter opens on a hairline paragraph (a word joiner a point tall, role `.dropNumeral(n)`, the later chapters' 2.4 × size of air above it) that keeps the opening the bands, the running head, jumps to verse 1, the headings rotor and the chapter-note mark use. The first paragraph (after any section heading) and the next ones, up to three, are the zone: lines whose top is beside the numeral step right of a notch the numeral's figures wide plus half the size, three body lines deep; poetry keeps its indent and hang inside it. The paragraph after the zone (a heading, the next paragraph, the next chapter's opening) is held no higher than after three full lines. Zone paragraphs do not hyphenate, and each verse number in them gets a zero-width space and a word joiner before it in the body font, outside every span (a word joiner alone glues the number to the word before it and moves the breaks); beside the numeral TextKit takes a line's height from its first character, and the joiner keeps every line at the body's pitch. The numeral is drawn, not text: in the page face's lining figures in the accent, flush with the column's edge, its figures from the first line's capital height to the third line's baseline, by an overlay on the Mac and a view per chapter on the iPhone, each a VoiceOver element reading "Chapter N". The chapter-note mark sits in the air above the hairline at the column's trailing edge.
  - **Cost** (whole Psalms, ESV, 18 pt, debug, the Mac): Lectern builds in 68 ms, loads at Psalm 119 with sixty highlights in 253 ms, reflows to a 600 pt window in 214 ms and scrolls end to end in 45 ms; Printed 49, 230, 198 and 43 ms (`lecternWholePsalmsStaysWithinTheBudgets`).
- **2026-11-12, Matt's first look at the drop numeral.** (1) Psalm 119's numeral showed over Psalm 108's first lines. The geometry was right (a test through a load at 119, a reflow, a size change and jumps to 108 and 120 finds every numeral in its own notch); the overlay was not: one layer-backed view as tall as the book (200,154 pt for Psalms) that redrew only when its numerals changed, so the window showed stale pixels as the page scrolled. Each numeral is now a small view of its own on the Mac, as on the iPhone. (2) Too wide: the figures are now proportional (Iowan's default figures are tabular, a "1" as wide as an "8") and tracked optically to a 0.04 em gap between neighbours' ink; at 18 pt "11" goes from 94.5 to 72.7 pt, "119" from 160.7 to 124.3, "150" from 164.3 to 140.9 ("1" stays 34.2), and the notch follows. Found on the way: a whole-Psalms text view outlives its controller in the tests, and `resizingAWholePsalmsWindowDoesNotReflowEveryFrame` runs about seven times slower after any whole-Psalms load in the same process (335 ms at 3c019ce too); left for a later fix.
- **2026-11-12, two more.** (1) Psalm 109's first notched line (a one-line prose verse, no indent) started 18 points left of the poetry lines beside it: TextKit sets each paragraph's indent inside the line rect the container returns, so the notch added to the indent. Beside the numeral the container now takes the paragraph's first-line indent back out (`DropZone.firstLineIndent`, `headIndent`): every line starts at the notch's edge, a wrapped poetry line keeps only its hang. (2) `resizingAWholePsalmsWindowDoesNotReflowEveryFrame` failed after other tests because the scroll view had come to show a legacy scroller (15–17 points): an animated narrowing then made the text view narrower than its waiting column, and a text view narrower than its text container cost TextKit a whole-book layout per frame (150 ms in Psalms) — a real cost for a reader with a mouse attached. While a reflow waits, `ColumnTextView` now keeps its frame at least as wide as the column (overflow clipped) and reads the width it was given from its superview; the benchmark runs with overlay and legacy scrollers, and the resize tests take their widths from the clip, not a fixed number.
