# Milestone 6: Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Mac app finished for daily use before sync and iOS: Psalm 119 loads, scrolls and takes marks without a stall; the chapter reads like a printed page (indented paragraphs, hanging poetry, small-caps LORD, a thin line showing how far in you are); the home page is one scrolling shelf of every book with a search field over the book list; notes export as Markdown from the File menu and the Notes browser; a new highlight color can never make the text harder to read; the app has an icon; the assistant's prompts are tiles with a sentence each; and the milestone 5 minors that a daily reader would trip over are fixed.

> Superseded: small-caps LORD was dropped in Task 3, because the bundled text has no LORD/Lord distinction.

**Architecture:** No new library targets. `ScriptureData` is unchanged. `ScriptureModel` gains `MarkLightness` (OKLCH clamp for highlight colors), additive fields on `PromptTemplate` (`summary`, `sectionRaw`) and `ChatMessage` (`savedNoteID`, `providerHost`, `finishReason`), a whole-Bible `markedChapters()` query, and a `KeychainAccess` seam under `KeychainStore` (which lives in `ScriptureLLM`). `ScriptureLLM` reworks the shared SSE step type so a provider can yield text and then finish or fail in one event, and reseeds the built-in prompts with titles, summaries and sections. `ScriptureUI` gets the reader's paragraph styles and signposts in `ChapterLayout` and `ChapterTextController`, the progress line and Previous link in `ReaderView`, the `BookshelfView` and `FrontPageSearch` behind the front page, the pure `MarkdownExport` with `NotesExporter` and the AppKit `ExportPanel`, prompt tiles in the chat panel, and the assistant model's Try Again, saved-note memory and finish reasons. The app target gains the File › Export Notes command, an Assistant menu, the shelf's wiring, and the icon.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, TextKit 2, `OSSignposter` and Instruments (`xctrace`), Swift Testing, AppKit `NSSavePanel` with an `NSHostingView` accessory, `NSImage` SVG rendering for the icon PNGs, Icon Composer 1.6 for the layered `.icon`. GRDB stays the only third-party dependency.

**Spec:** `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (Milestones › 6, Verification › Milestone 6, Decisions › Reading and Navigation). Design rules: `PRODUCT.md`, `DESIGN.md`, `CLAUDE.md`. Brainstorm with Matt on 2026-11-01: the rulings below record his choices (icon B, the continuous shelf, export in both places with the layout asked in the save panel, the thin progress line, all four typography changes, tiles with a title and a sentence, the daily-use set of minors).

## Global Constraints

- Minimum macOS 26 / iOS 26, Swift language mode 6, Swift Testing, SF Symbols only. GRDB stays the only third-party dependency; no SVG, Markdown or color library is added.
- **No fixed-point fonts in chrome.** `.font(.system(size:))` only where DESIGN.md names an exception (the reader body and verse numbers, derived from the reader size). Semantic text styles elsewhere; `@ScaledMetric(relativeTo:)` for any size tied to text. New reader metrics (indents, hang, stanza air, the small-caps font) derive from the reader size in `ReaderTypography.scaled`, never from literals at a call site.
- **No inline colors.** Every fill and ink is a `Palette` token (`Color.inkSecondary`, `Palette.accent.platformColor`) or a user highlight's stored hex (data, not a token). New pairings go into `PaletteTests`. Spacing from `AppSpacing`, radii from `AppRadius`.
- **No card by reflex.** The gray-fill-plus-hairline container is banned. A prompt tile is a tonal step (`paper.overlay` on `paper.panel`) with no stroke; selection and hover are the `accent.wash`; rows have rhythm, not boxes.
- **Plum and `sparkles` are only for the assistant.** Verdigris never signals danger; system red does.
- **Deletes are undoable, never confirmed**, except where the README already promises a confirmation (the Notes browser).
- Reader, column, editor, browser, palette and Settings behaviour from milestones 2 to 5 is unchanged except where a task names a change. Existing public signatures stay; additions only. SwiftData changes are additive (optional or defaulted fields) so the store opens without a migration plan.
- Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (339 pass in 47 suites on main at f7a50ff). Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData build`. No test touches the real Keychain or the network. AppKit-touching suites run on the main actor (`@MainActor @Suite`).
- Git: `/usr/bin/git`, one command per call. Commit per task, ending with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Never merge or push.
- Matt's store (`~/Library/Application Support/ReadingThroughScripture/Markup.store`) holds nothing special; verification may add, change and delete its contents.

## Rulings (plan-level decisions the spec leaves open)

1. **Measure first (spec, Milestone 6).** Task 1 adds signposts and a Psalm 119 benchmark and records the numbers before any change; Task 2 fixes only what those numbers show and records the numbers after. The two likely stalls, from reading `ChapterTextController`: `reportFirstVisibleVerse` walks layout fragments from the top of the document on every scroll tick, and `applyBackgrounds` calls `segmentFrames` once per highlight (each a fresh fragment walk with an `ensureLayout` up to its end) plus an O(n²) overlap pass. Both are to be confirmed by the benchmark before they are touched.
2. **Export lives in two places, one exporter (Matt).** File › Export Notes… (⇧⌘E) exports everything; the Notes browser's toolbar Export button exports what the list shows (its filter, search and sort). Both open one `NSSavePanel` whose accessory asks the layout each time (Matt): **One file** (a dated `.md`) or **One file per book** (a dated folder), plus **Include conversations** (on by default). The last choices are remembered in `UserDefaults` (`exportLayout`, `exportIncludesConversations`). Highlights without notes, bookmarks and chapter notes are always included; the file layout is in Task 8.
3. **The Markdown is readable before it is parseable (my call).** One `#` title, `##` per book in canon order, `###` per chapter, each item a blockquote of its quoted text ending in the app's existing citation form (`“text” — Matthew 5:3 (ESV)`), then the note body as written, then an italic line with the color or kind and the date. A bookmark quotes the verse from the current translation. A conversation is a `####` with its turns as `**You:**` and `**Assistant (Claude · claude-opus-5-5):**` paragraphs. No YAML front matter.
4. **The lightness band is the defaults' band (spec, DESIGN.md).** Measured in OKLCH, the five defaults sit at L 0.887 to 0.910 light and 0.400 to 0.401 dark. The band is **light 0.88…0.93, dark 0.37…0.43**. `MarkLightness.conformed(hex:dark:)` clamps L and reduces chroma until the color is inside sRGB, keeping the hue. The clamp lives in `MarkupStore.addColor` and `setColorHex`, so every path (Add Color sheet, Settings wells, a future sync) is covered; the sheet and the wells preview the conformed pair. Colors already in Matt's store that fall outside the band are conformed once at launch (`MarkupContainer.conformColorsIfNeeded`), like the earlier default-color migration. The Settings "Add Color" start value becomes the conformed gray.
   > Superseded: the dark band is now 0.37…0.41, with a nearest-edge clamp.
5. **Icon B, as an Icon Composer document with rendered PNGs underneath (Matt chose B; the format is my call).** The open book with one highlighted line on the right page, verdigris behind it. The SVG layers are committed; a Swift script renders the flat composite into the ten `AppIcon.appiconset` slots so the build has an icon with no GUI step. The layered `.icon` is then made in Icon Composer from those same SVGs (a GUI step, Matt's) and, once it is in the project, Xcode 26 prefers it to the PNG set.
6. **The front page is a shelf (Matt).** The detail pane is one scrolling column of every book's chapter grid in canon order, each grid centred under its book name. Choosing a book in the sidebar scrolls the shelf to it; scrolling the shelf moves the sidebar's selection to the book at the top. The grid stays five across at 56 by 40 (DESIGN.md); a chapter that carries any highlight, note or bookmark shows a 3 pt dot in `ink.tertiary` under its numeral. The sidebar gets a search field (`.searchable`, `placement: .sidebar`, prompt "Search books or a reference") that filters the book list and offers "Go to Romans 8" when the text parses as a reference the translation has; Return opens the first result.
7. **The page reads like a printed page (Matt, all four).** Prose paragraphs indent their first line by 1.5 × the reader size, except the chapter's first paragraph and a paragraph that follows poetry; indented prose keeps 0.3 × size between paragraphs (the indent carries the break; 0.78 × size stays for the two un-indented cases so the chapter's shape is unchanged where there is no indent). Each poetry line is its own paragraph with `firstLineHeadIndent` = 1 × size and `headIndent` = 2.5 × size, so a wrapped line tucks under its first word; a `breakAfter` on a poetry verse adds 0.5 × size of stanza air. "LORD" and "GOD" in capitals are set in small caps through the `kUpperCaseType` / `kUpperCaseSmallCapsSelector` font feature on the letters after the initial, text unchanged. The bundled ESV has "Lord" in title case, so ESV shows none; KJV, WEB and NASB do.
   > Superseded: small caps were dropped in Task 3, because the bundled text has no LORD/Lord distinction.
8. **Progress is a line, not a number (Matt).** A 2 pt `accent` line along the top edge of the text column, as wide as the fraction scrolled, hidden at 0 and when the chapter fits the window. It reports position and nothing else: no animation. The footer gains "Previous: Matthew 4" at the leading edge.
9. **Prompts are tiles with a sentence (Matt).** Each template gains a `summary` (one or two sentences) and a `section`. The panel shows the enabled templates as tonal tiles (title in `.callout` semibold, summary in `.caption` `ink.secondary`, `paper.overlay` at `AppRadius.lg`, hover `accent.wash`) grouped under "Get oriented", "Dig in", "Take it with you" for a chapter, "About the passage" for a selection, and "Your prompts" for the reader's own. Built-ins get new titles and summaries (Task 10); an unedited built-in is renamed in place, an edited one keeps its title and gains only its summary and section.
10. **Minors taken and left (Matt chose the daily-use set).** Taken: Try Again; Copy confirmation; Add as Note once per reply; VoiceOver announces a finished reply; native checkmarks in the History menu; the plus menu says "Matthew 5" like the buttons; Move Up / Move Down for prompts; grouped prompts; whole-reply text selection; a pasted key is saved without Return; a new key never deletes the old one first; a custom endpoint's old replies keep their host; a finished reply keeps its row identity; an OpenAI-compatible stream that ends without `[DONE]` after a finish reason is complete, and a `length` finish that arrives with text keeps the text; the dead line in `AppleFoundationProvider.map`; a reply declined partway is marked; the editor surface style extracted once; an Assistant menu with shortcuts. **Out of scope** (listed so they are not lost): deleting built-in prompts (hiding covers it), the unbundled-translation test's view side, and Settings reading all three Keychain keys at launch (moot once the app is signed with a developer certificate in milestone 7).
11. **The Assistant menu (my call).** A `CommandMenu("Assistant")` between Go and the system View menu: Show Assistant / Show Notes (⇧⌘A, moved from View), New Conversation… (⌃⌘N, always asks "Include where you are?"), Try Again (⌘R, enabled when the last question has no reply), Copy Last Reply (⇧⌘C), Add Last Reply as Note (⇧⌘S), Stop Answering (⌘., moved from View). Prompt tiles get no shortcuts.
12. **Whole-reply selection costs paragraph spacing (my call).** SwiftUI's `Text` selects within one view, so a reply becomes one `Text` whose blocks are joined by a blank line (`NoteMarkdown.document(_:)`). Notes in the column keep their stacked blocks; only the assistant's reply changes.
13. **Keys save as you type (my call).** The key field schedules a save 0.4 s after its last change and flushes when the pane disappears; the Save button goes, "Saved" and Remove stay.
    > Amended (whole-branch review): an emptied field is never autosaved or flushed, so only Remove (or Return on the empty field) deletes a key; pending saves also flush when the app quits.

## Design brief: the shelf, the page and the tiles (impeccable-swift `shape`, from the brainstorm with Matt, 2026-11-01)

- **Register and scene.** Product. One reader at a desk, mouse and keyboard, a 13 to 27 inch Mac in daylight or under a lamp; the shelf is where a session starts, the page is where it stays. Feel: settled, exact, hushed (PRODUCT.md).
- **The shelf (`BookshelfView`).** Detail pane of the front page on `paper.page`. A `ScrollView` with a `LazyVStack` of one block per book, `AppSpacing.xxl` apart, each block centred: the book name in Display (`.title` serif semibold, `ink.primary`), then the five-across grid (cells 56 by 40 at radius `lg`, `xs` gutters, numerals `.title3` serif monospaced digits, current chapter on `accent.wash` in `ink.primary`, others `ink.secondary`), a 3 pt `ink.tertiary` dot under a marked chapter. `scrollTargetLayout` with `scrollPosition(id:anchor: .top)` so the top book is known; a sidebar choice scrolls with `.smooth` (a cut under Reduce Motion). The sidebar keeps `.listStyle(.sidebar)` with its canon sections and gains the search field at its top; while a query is typed the list shows only the matching books and, first, a "Go to Romans 8" row with `arrow.right` when the text is a reference the translation has. Keyboard: Tab reaches the grid, arrows move between cells, Return opens.
- **The page (`ReaderView`).** Unchanged chrome. The 2 pt progress line sits on the column's top edge inside the `xl` top inset, left-aligned to the measure, `accent`, no animation, `accessibilityValue` "60 percent". The footer is one row across the measure: "Previous: Matthew 4" (`arrow.left`) leading, "Next: Matthew 6" (`arrow.right`) trailing, both `.callout` `ink.secondary` plain buttons.
- **The tiles (`PromptTilesView`).** Where the prompt list sat, above the composer: section headers as Label (`.caption` semibold, `ink.secondary`), then a `LazyVGrid` of adaptive columns at a `@ScaledMetric` minimum of 180 pt (one column in a narrow panel, two at the inspector's wider widths), tiles `AppSpacing.xs` apart. A tile is a `.plain` button: `VStack(alignment: .leading, spacing: AppSpacing.xxs)` of the title (`.callout.weight(.semibold)`, `ink.primary`) and the summary (`.caption`, `ink.secondary`, up to three lines), `AppSpacing.sm` padding, `paper.overlay` fill at `AppRadius.lg`, `accent.wash` on hover (`.snappy(duration: 0.2)` on the fill, a cut under Reduce Motion), `.help` with the summary, disabled while a reply streams. No stroke, no glyph, no shadow.
- **States.** Shelf: no books (unreachable; the translation always has books), a query with no match (`ContentUnavailableView.search(text:)` in the sidebar's list area). Page: a chapter that fits (no line), top (no line), partway, end (full width). Tiles: no enabled templates (nothing), streaming (tiles disabled), a section with no enabled templates (header hidden).
- **Anti-goals.** A sidebar that jumps while the reader scrolls the shelf by hand (selection follows the top book, the shelf never scrolls back on its own); a progress line that animates, glows or shows a number; prompt tiles with a border, an icon, or a third line of text; any of this at the expense of chapter open time.

## Review Focus

1. A chapter whose first verse is poetry (Psalm 1, Psalm 119): the opening has no first-line indent and the first poetry line hangs correctly (Task 3 test `aChapterOpeningInPoetryHasNoIndent`).
2. A highlight that spans a poetry line break or a paragraph break: its offsets still map onto `Verse.text` one to one and its fills are drawn per line (Task 3 test `offsetsAcrossLineAndParagraphBreaksStillMap`, Task 2's existing controller suites).
3. An export whose bookmark sits in a chapter the current translation lacks (a bookmark in Tobit while reading ESV): the line reads "(text not available in ESV)" instead of throwing (Task 8 test `aBookmarkWithoutAVerseSaysSo`).
4. A sidebar search for a reference past the book's end ("Jude 3", "Psalm 151" in a translation without it): no "Go to" row, and the book itself is still listed (Task 6 test `aReferencePastTheBookEndOffersNoGoTo`).
5. A color saved from the picker while the app is in Dark Mode: both stored variants are conformed, so the light variant is never left out of band (Task 5 test `setColorHexConformsBothVariants`).

---

## File Structure

**ScriptureModel (modify/create, `Packages/ScriptureKit/Sources/ScriptureModel/`)**
- `MarkLightness.swift` (create): OKLab/OKLCH conversion, the two bands, `lightness(ofHex:)`, `conformed(hex:dark:)`, `isInBand(hex:dark:)`.
- `MarkupStore.swift` (modify): `addColor`/`setColorHex` conform through `MarkLightness`; `markedChapters()`.
- `MarkupContainer.swift` (modify): `conformColorsIfNeeded(in:)`.
- `PromptTemplate.swift` (modify): `PromptSection`; `PromptSeed.summary`, `.section`, `.legacyTitle`; `PromptTemplate.summary`, `.sectionRaw`.
- `PromptTemplateStore.swift` (modify): `add(title:summary:body:scope:)`, `update(_:title:summary:body:)`, `migrateBuiltInsIfNeeded(from:)`, `move(_:by:)`.
- `ChatMessage.swift` (modify): `savedNoteID`, `providerHost`, `finishReason`.
- `ChatStore.swift` (modify): `append(... providerHost:finishReason:uuid:)`, `setSavedNote(_:on:)`; `MessageSnapshot` carries the three new fields.
- Tests: `MarkLightnessTests` (create), additions to `MarkupStoreTests`, `MarkupContainerTests`, `PromptTemplateStoreTests`, `ChatStoreTests`.

**ScriptureLLM (modify, `Packages/ScriptureKit/Sources/ScriptureLLM/`)**
- `HTTPStreaming.swift`: `Step` enum; `stream(request:session:parse:)` takes `(SSEEvent) throws -> Step`.
- `OpenAICompatibleProvider.swift`, `AnthropicProvider.swift`: adopt `Step`; stop and length handling.
- `AppleFoundationProvider.swift`: the dead line.
- `SecretStore.swift`: `KeychainAccess` protocol, `SecurityKeychain`, `KeychainStore(access:)`, update-in-place.
- `BuiltInPrompts.swift`: new titles, summaries, sections, `legacyTitles`.
- Tests: additions to `OpenAICompatibleProviderTests`, `AnthropicProviderTests`, `SecretStoreTests` (+ `FakeKeychain` helper), `BuiltInPromptsTests` (create).

**ScriptureUI (create/modify, `Packages/ScriptureKit/Sources/ScriptureUI/`)**
- `ReaderSignposts.swift` (create): the `OSSignposter` and interval names.
- `ReaderTypography.swift` (modify): `firstLineIndent`, `indentedParagraphSpacing`, `poetryIndent`, `poetryHang`, `stanzaSpacing`, `smallCapsFont`.
- `ChapterLayout.swift` (modify): paragraph kinds and styles, poetry lines as paragraphs, `smallCapsRanges(in:)`.
- `ChapterTextController.swift` (modify): signposts, the measured fixes, `progress` and `onProgressChange`.
- `ChapterTextView.swift`, `ReaderView.swift` (modify): progress line, Previous link.
- `ReadingProgressLine.swift` (create).
- `FrontPageSearch.swift` (create): pure filtering and the reference row.
- `BookshelfView.swift` (create); `FrontPageView.swift` (modify): search, shelf, marked chapters; `ChapterGridView.swift` (modify): centred, dot, arrow keys.
- `MarkdownExport.swift` (create): options, output, rendering. `NotesExporter.swift` (create): entries plus verse text and threads from the stores. `NotesBrowserLoader.swift` (create): entry building extracted from `NotesBrowserModel`. `ExportPanel.swift` (create, macOS): the save panel with its accessory.
- `NotesBrowserEntry.swift` (modify): `colorName`. `NotesBrowserModel.swift` (modify): uses the loader. `NotesBrowserView.swift` (modify): Export button.
- `AssistantItems.swift` (modify): `PromptTemplateItem.summary`, `.section`; `ChatMessageItem.savedNoteID`, `.finishReason`; `ProviderLabel.text(providerID:modelName:host:)`.
- `PromptTilesView.swift` (create); `ChatPanelView.swift` (modify): tiles, History picker, plus-menu copy; `ChatTurnRow.swift` (modify): Copied, Show Note, finish reason, one `Text`; `NoteMarkdown.swift` (modify): `document(_:)`.
- `AssistantModel.swift` (modify): retry, saved notes, finish reasons, host, row identity, announcement, `lastReplyID`.
- `AssistantSettings.swift`, `AssistantSettingsView.swift` (modify): autosave.
- `PromptTemplatesSettingsView.swift` (modify): summary field, sections, Move Up/Down, `editorSurface()`.
- `ColumnRowParts.swift` (modify): `editorSurface()`; `AssistantComposer.swift`, `NoteRowView.swift` (modify): use it.
- Tests: `ReaderBenchmarkTests` (create, with `Fixtures/Benchmarks/PSA-119-KJV.json`), additions to `ChapterLayoutTests`, `ChapterTextControllerTests`, `PaletteTests`, `FrontPageSearchTests` (create), `MarkdownExportTests` (create), `NotesExporterTests` (create), `AssistantModelTests`, `AssistantSettingsTests`, `NoteMarkdownTests`.

**App (modify, `Apps/Mac/ReadingThroughScripture/`)**
- `ReadingThroughScriptureApp.swift`: Export Notes command, the Assistant menu, `NotesExporter`, `conformColorsIfNeeded`, `migrateBuiltInsIfNeeded`.
- `MainWindowView.swift`: shelf wiring, marked chapters, Previous link, reference search.
- `Assets.xcassets/AppIcon.appiconset/` (PNGs and `Contents.json`), `Icon/` (SVG layers), `AppIcon.icon` (Icon Composer, Matt's step).
- `Scripts/render-icon.swift` (create).
- `README.md`, `DESIGN.md`, the spec's Verification section, this plan's verification table.

---

### Task 1: Signposts and the Psalm 119 benchmark (measure before)

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderSignposts.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterLayout.swift:50` (`build`), `Packages/ScriptureKit/Sources/ScriptureUI/ChapterTextController.swift:185` (`replaceText`), `:214` (`sizeToLayout`), `:237` (`columnWidthDidChange`), `:289` (`reportFirstVisibleVerse`), `:452` (`applyBackgrounds`)
- Create: `Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/Benchmarks/PSA-119-KJV.json`, `Packages/ScriptureKit/Tests/ScriptureUITests/ReaderBenchmarkTests.swift`
- Modify: this plan's "Milestone 6 verification" table (the Before column)

**Interfaces:**
- Produces: `enum ReaderSignposts { static let signposter: OSSignposter; static let layoutBuild: StaticString = "ChapterLayout.build"; static let replaceText = "replaceText"; static let sizeToLayout = "sizeToLayout"; static let applyBackgrounds = "applyBackgrounds"; static let reportFirstVisibleVerse = "reportFirstVisibleVerse"; static let columnWidthDidChange = "columnWidthDidChange" }` (subsystem `com.matthewfurr.ReadingThroughScripture`, category `reader`).
- Produces: `enum BenchmarkChapter { static func psalm119() throws -> [Verse] }` (test helper) decoding the fixture, whose shape is one holybooks chapter object `{"ID":"OT:PSA.119","name":"Psalm 119","text":[{"ID":"1","text":"…"}, …]}` run through `VerseMerger.merge` so poetry lines and `breakAfter` are as the app sees them.
- Produces: `ChapterTextController.makeForBenchmark(width: CGFloat, height: CGFloat) -> ChapterTextController` is **not** added; the test uses the pattern in `ChapterTextControllerTests.makeController`.

- [ ] **Step 1: Make the fixture.** The KJV source is in the build cache from `Scripts/build-bible.sh`: `ls ~/Library/Caches/ReadingThroughScripture/` and find `EN/OT/PSA/KJV.json` under it (run the script first if the cache is empty). Extract chapter 119 with `python3 -I` (load the book file, pick the element of `text` whose `ID` is `"OT:PSA.119"`, write it as the fixture). The fixture lives outside the `EN/` tree so `SourceTree` never imports it. Expected: `python3 -I -c "import json; d=json.load(open('Packages/ScriptureKit/Tests/ScriptureUITests/Fixtures/Benchmarks/PSA-119-KJV.json')); print(len(d['text']))"` prints `176`.

- [ ] **Step 2: Write the failing benchmark test**

```swift
#if os(macOS)
import AppKit
import BibleImporterCore
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// Psalm 119 (176 poetry verses) is the spec's long-chapter benchmark. Ceilings are generous
/// debug-build numbers that hold on main; Task 2 tightens them to twice its measured result.
@MainActor @Suite(.serialized) struct ReaderBenchmarkTests {
    private func controller(width: CGFloat = 900, height: CGFloat = 700) -> ChapterTextController {
        let controller = ChapterTextController(onFirstVisibleVerseChange: { _ in })
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        controller.scrollView.layoutSubtreeIfNeeded()
        return controller
    }

    /// Sixty highlights of a few words each, spread through the chapter, ten of them overlapping.
    private func decorations(for layout: ChapterLayout) -> ChapterDecorations {
        var highlights: [RangeDecoration] = []
        for (index, span) in layout.spans.enumerated() where index % 3 == 0 {
            let length = min(18, span.textRange.length)
            highlights.append(RangeDecoration(id: UUID(), range: NSRange(location: span.textRange.location, length: length), style: .background(MarkupColor(lightHex: "#F8E18A", darkHex: "#554704"))))
            if index % 18 == 0 {
                highlights.append(RangeDecoration(id: UUID(), range: NSRange(location: span.textRange.location + 6, length: length), style: .background(MarkupColor(lightHex: "#B8E8FF", darkHex: "#144D6E"))))
            }
        }
        return ChapterDecorations(highlights: highlights, bookmarkVerses: [8, 105, 176], outlinedID: nil)
    }

    private func measure(_ label: String, _ work: () -> Void) -> Duration {
        let clock = ContinuousClock()
        let elapsed = clock.measure(work)
        print("benchmark \(label) \(elapsed.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 1))))")
        return elapsed
    }

    @Test func psalm119LoadsWithSixtyHighlights() throws {
        let verses = try BenchmarkChapter.psalm119()
        let layout = ChapterLayout.build(verses: verses)
        let controller = controller()
        let elapsed = measure("load", { controller.update(verses: verses, typography: .default, scrollTarget: ScrollTarget(verse: 1), decorations: decorations(for: layout)) })
        #expect(elapsed < .seconds(1.5))
        #expect(controller.backgroundFills.count >= 60)
    }

    @Test func aHundredScrollTicksReportTheVerse() throws {
        let verses = try BenchmarkChapter.psalm119()
        let layout = ChapterLayout.build(verses: verses)
        var reported: [Int] = []
        let controller = controller()
        controller.onFirstVisibleVerseChange = { reported.append($0) }
        controller.update(verses: verses, typography: .default, scrollTarget: ScrollTarget(verse: 1), decorations: decorations(for: layout))
        let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
        let elapsed = measure("scroll×100", {
            for tick in 1...100 {
                controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY * CGFloat(tick) / 100))
                controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
            }
        })
        #expect(elapsed < .seconds(1.0))
        #expect(reported.last == 176 || reported.last == 175)
    }

    @Test func recolouringOneHighlightIsCheap() throws {
        let verses = try BenchmarkChapter.psalm119()
        let layout = ChapterLayout.build(verses: verses)
        var decorations = decorations(for: layout)
        let controller = controller()
        controller.update(verses: verses, typography: .default, scrollTarget: ScrollTarget(verse: 1), decorations: decorations)
        decorations.outlinedID = decorations.highlights[30].id
        let elapsed = measure("decoration change", { controller.update(verses: verses, typography: .default, scrollTarget: nil, decorations: decorations) })
        #expect(elapsed < .seconds(0.5))
    }
}
#endif
```

`BenchmarkChapter` (same file or `BenchmarkChapter.swift` beside `FixtureStore.swift`): decode `{ID, name, text: [HolyBookFile.Entry]}` from `Bundle.module.url(forResource: "PSA-119-KJV", withExtension: "json", subdirectory: "Fixtures/Benchmarks")`, run `VerseMerger.merge(entries, warnings: &warnings)`, map to `Verse(id: VerseLocation(book: "PSA", chapter: 119, verse: $0.number), translationID: "KJV", endVerse: $0.endNumber, text: $0.text, breakAfter: $0.breakAfter)`. `HolyBookFile.Entry` is public in `BibleImporterCore`; the test target already depends on it.

- [ ] **Step 3: Run to verify failure** — `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter ReaderBenchmarkTests`; expected: fails to compile on `BenchmarkChapter`.

- [ ] **Step 4: Add `BenchmarkChapter` and `ReaderSignposts`**, then wrap each named region in `signposter.beginInterval(name)` / `endInterval` (the `ChapterLayout.build` static, and the five controller methods at the lines above). Signposts cost nothing when no one records; keep them in release builds.

- [ ] **Step 5: Run the benchmark three times** and write the median of each printed `benchmark …` line into the Before column of "Milestone 6 verification" below. Expected: all three tests pass under the generous ceilings (if one fails on main, raise that ceiling to the measured value plus half and note it in the table; the point of this task is the number, not the gate).

- [ ] **Step 6: Record an Instruments trace of the real app on Psalm 119.** Build the app, set the reading position so it opens there (`defaults write com.matthewfurr.ReadingThroughScripture readingPosition -string '…'` is not stable; instead open Psalm 119 in the app once by hand or with System Events, quit, then record): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xctrace record --template 'Time Profiler' --time-limit 25s --output /private/tmp/claude-501/-Users-matt-Code-reading-through-scripture/1d1f84ea-e27d-4efb-9108-3e0462ad593b/scratchpad/psalm119-before.trace --launch -- Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`, and while it runs scroll Psalm 119 end to end twice and resize the window once (System Events, per the memory on UI verification). Export the heaviest symbols: `xcrun xctrace export --input <trace> --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > before.xml` and list the top ten `ChapterTextController` and `ChapterLayout` symbols by weight into the table's notes. Expected: a trace file exists and the top symbols are named in the table.

- [ ] **Step 7: Run the whole suite** — expected 339 + 3 pass.

- [ ] **Step 8: Commit** — `perf: reader signposts and the Psalm 119 benchmark (before)`.

---

### Task 2: Fix what the numbers show (measure after)

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterTextController.swift` (`reportFirstVisibleVerse` :289-313, `segmentFrames` :347-390, `applyBackgrounds` :452-475, `columnWidthDidChange` :237-245, `ColumnTextView.setFrameSize` :621-627)
- Modify: `Packages/ScriptureKit/Tests/ScriptureUITests/ReaderBenchmarkTests.swift` (ceilings), `ChapterTextControllerTests.swift` (one new test)
- Modify: this plan's verification table (the After column)

**Interfaces:**
- Consumes: the Before numbers and the trace's top symbols from Task 1.
- Produces: no public change. Private: `segmentFrames(of ranges: [NSRange]) -> [[NSRect]]` (one fragment walk for every range), `fragmentNearest(y: CGFloat) -> NSTextLayoutFragment?`.

- [ ] **Step 1: Write the failing behaviour test** (in `ChapterTextControllerTests`)

```swift
/// Scrolled to the end of a long chapter, the first visible verse is found by looking at the
/// visible fragment, not by walking from the top; the answer is the same either way.
@Test func firstVisibleVerseAtTheEndOfALongChapterIsTheLastVerse() {
    var reported: [Int] = []
    let controller = makeController { reported.append($0) }
    controller.update(verses: verses(count: 400), typography: .default, scrollTarget: ScrollTarget(verse: 1), decorations: .none)
    let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
    controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
    controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
    #expect(reported.last.map { $0 >= 396 } == true)
}
```

- [ ] **Step 2: Run to verify it passes already** (it is a regression guard for the change that follows) — `--filter ChapterTextControllerTests/firstVisibleVerseAtTheEndOfALongChapterIsTheLastVerse`; expected PASS.

- [ ] **Step 3: Apply the fixes the trace and benchmark justify**, in this order, re-running the benchmark after each and keeping only those that move a number:
  1. `reportFirstVisibleVerse`: start `enumerateTextLayoutFragments(from:)` at `textLayoutManager.textLayoutFragment(for: CGPoint(x: 0, y: max(0, visibleTop)))?.rangeInElement.location` instead of `nil`; keep the `.ensuresLayout` option.
  2. `applyBackgrounds`: compute every highlight's rects in one walk (`segmentFrames(of: [NSRange])`), skip the per-range `ensureLayout(for: upTo)` when `contentHeight > 0` (the document is already laid out by `sizeToLayout`), and find overlaps by sorting ranges by location and sweeping, so pairs that cannot intersect are never compared.
  3. `columnWidthDidChange` during a live resize: if the trace shows it above ten percent of the resize's samples, defer `sizeToLayout` and `refreshOverlays` to `viewDidEndLiveResize` in `ColumnTextView` (the text view keeps drawing with the old layout meanwhile; the pending verse scroll still runs at the end).
  4. `segmentFrames` font lookup: read the body font once from `appliedTypography` rather than `textStorage.attribute(.font, at:)` per call.

- [ ] **Step 4: Tighten the benchmark ceilings** to twice the median After number of each test (rounded up to 50 ms), so a regression fails the suite without flaking a slower machine.

- [ ] **Step 5: Run the whole suite** (expected all pass, 339 + 4) and the Instruments recording from Task 1 Step 6 again as `psalm119-after.trace`; write the After numbers and the new top symbols into the table.

- [ ] **Step 6: Commit** — `perf: first visible verse from the visible fragment; highlight fills in one pass (after)`.

---

### Task 3: The printed page: indents, hanging poetry, stanza air, small caps

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ReaderTypography.swift`, `Packages/ScriptureKit/Sources/ScriptureUI/ChapterLayout.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterTextController.swift:392` (`isWhitespace` keeps `0x0A`; `0x2028` stays for safety)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/ChapterLayoutTests.swift`, `ReaderSettingsTests.swift`

**Interfaces:**
- Produces on `ReaderTypography`: `public var firstLineIndent: CGFloat` (size × 1.5, rounded), `public var indentedParagraphSpacing: CGFloat` (size × 0.3, rounded), `public var poetryIndent: CGFloat` (size × 1.0), `public var poetryHang: CGFloat` (size × 1.5, rounded; `headIndent` for poetry is `poetryIndent + poetryHang`), `public var stanzaSpacing: CGFloat` (size × 0.5, rounded), `public var smallCapsFont: PlatformFont` (the body font's descriptor with `[.featureSettings: [[.typeIdentifier: kUpperCaseType, .selectorIdentifier: kUpperCaseSmallCapsSelector]]]`). All set in `scaled(size:lineHeightMultiple:)`; the memberwise `init` gains them with defaults derived from the body font's point size so existing call sites compile.
- Produces on `ChapterLayout`: `public enum ParagraphKind: Equatable, Sendable { case opening, prose, proseAfterPoetry, poetryLine, poetryLineStanzaEnd }`; `public static func paragraphStyle(for kind: ParagraphKind, typography: ReaderTypography) -> NSParagraphStyle`; `public static func smallCapsRanges(in text: String) -> [NSRange]` (UTF-16 ranges of the letters after the initial of a whole-word `LORD` or `GOD`, also before `'S` / `’S`); `public static let lineSeparator` stays declared but is no longer emitted.
- Layout rules in `build`: a poetry verse (text contains `\n`) is emitted as one paragraph per line, separated by `"\n"`; the first line carries the number, the rest start with no number. Separators between verses: `" "` prose→prose; `"\n"` when `previous.breakAfter`, when either side is poetry, or at a stanza end. Paragraph kinds: the chapter's first paragraph is `.opening`; a prose paragraph after a `breakAfter` is `.prose` unless the previous verse was poetry, then `.proseAfterPoetry`; poetry lines are `.poetryLine`, and the last line of a poetry verse with `breakAfter` is `.poetryLineStanzaEnd`. The number's attributes carry the same paragraph style as its verse. Small caps: for each verse, `smallCapsRanges(in: verse.text)` offset by its `textStart` get `.font: typography.smallCapsFont`.
- `textRange` still maps one to one onto `Verse.text` (every `\n` in the source stays one UTF-16 unit), so `offsetWithinVerse` and every highlight offset are unchanged.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func proseParagraphsIndentExceptTheFirstAndAfterPoetry() {
    let t = ReaderTypography.default
    let layout = ChapterLayout.build(verses: [
        verse(1, "Opening prose.", breakAfter: true),
        verse(2, "Second paragraph.", breakAfter: true),
        verse(3, "Line one,\nline two.", breakAfter: true),
        verse(4, "After poetry."),
    ], typography: t)
    func style(atVerse n: Int) -> NSParagraphStyle {
        layout.attributedString.attribute(.paragraphStyle, at: layout.span(forVerse: n)!.textRange.location, effectiveRange: nil) as! NSParagraphStyle
    }
    #expect(style(atVerse: 1).firstLineHeadIndent == 0)
    #expect(style(atVerse: 1).paragraphSpacing == t.paragraphSpacing)
    #expect(style(atVerse: 2).firstLineHeadIndent == t.firstLineIndent)
    #expect(style(atVerse: 2).paragraphSpacing == t.indentedParagraphSpacing)
    #expect(style(atVerse: 4).firstLineHeadIndent == 0)
}

@Test func poetryLinesAreHangingParagraphs() {
    let t = ReaderTypography.default
    let layout = ChapterLayout.build(verses: [verse(1, "Line one,\nline two."), verse(2, "Line three,\nline four.", breakAfter: true), verse(3, "Prose.")], typography: t)
    #expect(layout.attributedString.string == "1 Line one,\nline two.\n2 Line three,\nline four.\n3 Prose.")
    let first = layout.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
    #expect(first.firstLineHeadIndent == t.poetryIndent)
    #expect(first.headIndent == t.poetryIndent + t.poetryHang)
    #expect(first.paragraphSpacing == 0)
    let secondLine = layout.attributedString.attribute(.paragraphStyle, at: "1 Line one,\n".utf16.count, effectiveRange: nil) as! NSParagraphStyle
    #expect(secondLine.firstLineHeadIndent == t.poetryIndent)
    let stanzaEnd = layout.attributedString.attribute(.paragraphStyle, at: "1 Line one,\nline two.\n2 Line three,\n".utf16.count, effectiveRange: nil) as! NSParagraphStyle
    #expect(stanzaEnd.paragraphSpacing == t.stanzaSpacing)
}

@Test func aChapterOpeningInPoetryHasNoIndent() {
    let t = ReaderTypography.default
    let layout = ChapterLayout.build(verses: [verse(1, "Blessed is the man\nwho walks not.")], typography: t)
    let style = layout.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
    #expect(style.firstLineHeadIndent == t.poetryIndent)
    #expect(style.headIndent == t.poetryIndent + t.poetryHang)
}

@Test func offsetsAcrossLineAndParagraphBreaksStillMap() {
    let verses = [verse(1, "Line one,\nline two.", breakAfter: true), verse(2, "Prose after.")]
    let layout = ChapterLayout.build(verses: verses)
    for (span, verse) in zip(layout.spans, verses) {
        #expect(span.textRange.length == verse.text.utf16.count)
        #expect((layout.attributedString.string as NSString).substring(with: span.textRange) == verse.text)
    }
    #expect(layout.offsetWithinVerse(of: layout.spans[0].textRange.location + 12)?.offset == 12)
}

@Test func smallCapsRangesCoverLordAndGod() {
    #expect(ChapterLayout.smallCapsRanges(in: "The LORD is my shepherd") == [NSRange(location: 5, length: 3)])
    #expect(ChapterLayout.smallCapsRanges(in: "the LORD'S house and GOD’s word") == [NSRange(location: 5, length: 3), NSRange(location: 22, length: 2)])
    #expect(ChapterLayout.smallCapsRanges(in: "The Lord is my shepherd; LORDLY men; GODS") == [])
    let layout = ChapterLayout.build(verses: [verse(1, "The LORD reigns.")])
    let font = layout.attributedString.attribute(.font, at: layout.spans[0].textRange.location + 5, effectiveRange: nil) as! PlatformFont
    #expect(font == ReaderTypography.default.smallCapsFont)
}
```

Also update `poetryVerseStartsOnItsOwnLine` to expect `"\n"` separators, and add to `ReaderSettingsTests`: `metricsScaleWithTheSize` asserting at 18 pt `firstLineIndent == 27`, `indentedParagraphSpacing == 5`, `poetryIndent == 18`, `poetryHang == 27`, `stanzaSpacing == 9`, and at 24 pt `firstLineIndent == 36`.

- [ ] **Step 2: Run to verify failure** — `--filter ChapterLayoutTests`; expected: compile failures on the new members.

- [ ] **Step 3: Implement** the typography members, `paragraphStyle(for:typography:)`, `smallCapsRanges(in:)` (an `NSRegularExpression` `(?<=\bL)ORD(?=\b|['’])|(?<=\bG)OD(?=\b|['’])` over the UTF-16 string; `\b` must not match inside `LORDLY` or `GODS`), and the `build` rules above. Keep `lineHeightMultiple` on every style.

- [ ] **Step 4: Run the layout, controller and markup suites** — `--filter 'ChapterLayoutTests|ChapterTextControllerTests|ChapterTextControllerMarkupTests|MarkupModelTests|ReaderSettingsTests'`; expected all pass (poetry fills now land per line; a controller test that asserted a U+2028 string is updated to `\n`).

- [ ] **Step 5: Build and look.** Open Psalm 119 (hanging lines, stanza air every eight verses in KJV and ESV), Matthew 5 in ESV (indented paragraphs, none at the opening), Psalm 23 in KJV (small-caps LORD) and in ESV (no small caps; the text has "Lord"). Screenshot each in light and dark into the scratchpad.

- [ ] **Step 6: Commit** — `feat: indented prose, hanging poetry with stanza air, small-caps LORD`.

---

### Task 4: The progress line and the Previous link

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChapterTextController.swift` (`clipBoundsDidChange` :262, `performPendingScroll` :276, `sizeToLayout` :214), `ChapterTextView.swift`, `ReaderView.swift`
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ReadingProgressLine.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/MainWindowView.swift:127-147`, `DESIGN.md` (symbols: `arrow.left`; components: `progress-line`)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/ChapterTextControllerTests.swift`

**Interfaces:**
- Produces on `ChapterTextController`: `public private(set) var progress: Double` (0 when the content fits or the clip sits at the top, else `clip.minY / (document.height - clip.height)` clamped to 0…1), `var onProgressChange: (Double) -> Void = { _ in }` called whenever the value changes by at least 0.005 or reaches 0 or 1.
- Produces: `struct ReadingProgressLine: View { let fraction: Double; let measure: CGFloat }`: a `Rectangle` in `Color.accent`, height 2, width `measure × fraction`, leading-aligned in a frame of `measure`, `opacity(fraction > 0 ? 1 : 0)`, `.animation(nil)`, `accessibilityLabel("Chapter progress")`, `accessibilityValue("\(Int(fraction * 100)) percent")`.
- Produces on `ReaderView.init`: `previousChapterTitle: String? = nil`, `onPreviousChapter: @escaping () -> Void = {}`; on `ChapterTextView`: `var onProgressChange: (Double) -> Void = { _ in }`.
- Footer: an `HStack` across the measure with the Previous button (`Label("Previous: \(title)", systemImage: "arrow.left")`, `.help("Previous Chapter (⌥⌘←)")`) leading and the existing Next trailing.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func progressRunsFromZeroAtTheTopToOneAtTheEnd() {
    var reported: [Double] = []
    let controller = makeController { _ in }
    controller.onProgressChange = { reported.append($0) }
    controller.update(verses: verses(count: 120), typography: .default, scrollTarget: ScrollTarget(verse: 1), decorations: .none)
    #expect(controller.progress == 0)
    let maxY = controller.scrollView.documentView!.frame.height - controller.scrollView.contentView.bounds.height
    controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY / 2))
    controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
    #expect(abs(controller.progress - 0.5) < 0.02)
    controller.scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
    controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
    #expect(controller.progress == 1)
    #expect(reported.last == 1)
}

@Test func progressIsZeroWhenTheChapterFits() {
    let controller = makeController { _ in }
    controller.update(verses: verses(count: 2), typography: .default, scrollTarget: ScrollTarget(verse: 1), decorations: .none)
    #expect(controller.progress == 0)
}
```

- [ ] **Step 2: Run to verify failure** — `--filter ChapterTextControllerTests/progress`; expected: `progress` undefined.

- [ ] **Step 3: Implement** `progress` and `onProgressChange` (computed in `clipBoundsDidChange`, after `performPendingScroll`, and in `sizeToLayout`), thread it through `ChapterTextView` into a `@State private var progress` in `ReaderView`, place `ReadingProgressLine` as an `overlay(alignment: .top)` on `chapterText` padded `.horizontal, AppSpacing.xxl` so it aligns with the column, and add the Previous button. Wire `previousChapterTitle: model.previousChapter.map(model.title(for:))` and `onPreviousChapter: { model.goToPreviousChapter() }` in `MainWindowView`. Add `arrow.left` to DESIGN.md's navigation symbols and a `progress-line` component (height 2, `accent`, no animation).

- [ ] **Step 4: Run the suite** — expected all pass.

- [ ] **Step 5: Build and look.** Scroll Matthew 5: the line grows from nothing to the full measure; Reduce Motion on, same; a chapter that fits the window (Psalm 117 at 14 pt in a tall window) shows no line. Previous and Next both work from the footer.

- [ ] **Step 6: Commit** — `feat: a thin progress line over the column; Previous beside Next in the footer`.

---

### Task 5: Highlight colors held to the lightness band

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureModel/MarkLightness.swift`, `Packages/ScriptureKit/Tests/ScriptureModelTests/MarkLightnessTests.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureModel/MarkupStore.swift` (`addColor`, `setColorHex`), `MarkupContainer.swift` (`conformColorsIfNeeded`), `Packages/ScriptureKit/Sources/ScriptureUI/ColorSettingsModel.swift:275-277`, `AddColorSheet.swift`, `HighlightColorsSettingsView.swift` (`ColorRowView.save` :568), `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift:34`, `DESIGN.md` (Marks paragraph: the band is now enforced)
- Test: `Packages/ScriptureKit/Tests/ScriptureModelTests/MarkupStoreTests.swift`, `MarkupContainerTests.swift`, `Packages/ScriptureKit/Tests/ScriptureUITests/PaletteTests.swift`

**Interfaces:**
- Produces: `public enum MarkLightness { public static let lightBand: ClosedRange<Double> = 0.88...0.93; public static let darkBand: ClosedRange<Double> = 0.37...0.43; public static func lightness(ofHex hex: String) -> Double? (OKLab L); public static func isInBand(hex: String, dark: Bool) -> Bool; public static func conformed(hex: String, dark: Bool) -> String (clamps L into the band, keeps hue, reduces chroma in steps of 0.005 until all three sRGB components are within 0…1, returns uppercase #RRGGBB; an unparseable hex returns the band's gray: the conformed `#D0D0D0` light, `#505050` dark) }`. Internals: `struct OKLab { l, a, b }` with `init(srgbHex:)` and `func srgbHex() -> String?` (nil when out of gamut), the standard OKLab matrices.
- Produces on `MarkupStore`: `addColor(name:lightHex:darkHex:)` and `setColorHex(_:lightHex:darkHex:)` store `MarkLightness.conformed` values (signatures unchanged).
- Produces on `MarkupContainer`: `@MainActor public static func conformColorsIfNeeded(in context: ModelContext) throws -> Int` (the count changed; every `HighlightColor` whose light or dark hex is out of band is rewritten in place).
- Produces on `ColorSettingsModel`: `newColorLightHex = MarkLightness.conformed(hex: "#D0D0D0", dark: false)`, `newColorDarkHex = MarkLightness.conformed(hex: "#505050", dark: true)`.
- UI: `AddColorSheet` shows, under the two pickers, a row "Kept light enough for the text to stay readable." in `.caption` `ink.secondary` with two `MarkerGlyph`-style circles previewing the conformed light and dark hex; `onAdd` passes the conformed pair. `ColorRowView.save()` passes the raw hex (the store conforms) and, when the row's stored hex comes back different, resets its `light`/`dark` state to the stored values (the existing `onChange(of: row)` path).

- [ ] **Step 1: Write the failing tests**

```swift
// MarkLightnessTests
@Test func defaultsAreAlreadyInsideTheBand() {
    for color in MarkupContainer.defaultColors {
        #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false), color.name)
        #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true), color.name)
        #expect(MarkLightness.conformed(hex: color.lightHex, dark: false) == color.lightHex, color.name)
        #expect(MarkLightness.conformed(hex: color.darkHex, dark: true) == color.darkHex, color.name)
    }
}

@Test func aDarkPickOnTheLightSideIsLifted() {
    let lifted = MarkLightness.conformed(hex: "#1F4C7A", dark: false)
    #expect(MarkLightness.isInBand(hex: lifted, dark: false))
    #expect(MarkLightness.lightness(ofHex: lifted)! >= 0.88)
}

@Test func conformingIsIdempotent() {
    for hex in ["#FF0000", "#00FF00", "#0000FF", "#FFFFFF", "#000000", "#7E517A"] {
        for dark in [false, true] {
            let once = MarkLightness.conformed(hex: hex, dark: dark)
            #expect(MarkLightness.conformed(hex: once, dark: dark) == once, "\(hex) dark=\(dark)")
        }
    }
}

@Test func garbageBecomesTheBandGray() {
    #expect(MarkLightness.conformed(hex: "nope", dark: false) == MarkLightness.conformed(hex: "#D0D0D0", dark: false))
}

// PaletteTests
/// Any hue, conformed into the band, keeps primary ink readable: the guarantee DESIGN.md makes
/// for the defaults now covers the reader's own colors.
@Test func anyHueConformedKeepsPrimaryInkReadable() {
    for hue in stride(from: 0, to: 360, by: 15) {
        let seed = Self.hex(oklchL: 0.6, chroma: 0.12, hueDegrees: Double(hue))   // helper: OKLCH → sRGB hex, clamped
        let light = MarkLightness.conformed(hex: seed, dark: false)
        let dark = MarkLightness.conformed(hex: seed, dark: true)
        #expect(Self.contrast(Palette.inkPrimary.light, light) >= 10, "hue \(hue) light \(light)")
        #expect(Self.contrast(Palette.inkPrimary.dark, dark) >= 6.5, "hue \(hue) dark \(dark)")
    }
}

// MarkupStoreTests
@Test func addColorAndSetColorHexConformToTheBand() throws {
    let store = try makeStore()   // the suite's existing in-memory helper
    let color = try store.addColor(name: "Navy", lightHex: "#1F4C7A", darkHex: "#B9DDFF")
    #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false))
    #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true))
    try store.setColorHex(color, lightHex: "#000000", darkHex: "#FFFFFF")
    #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false))
    #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true))
}

@Test func setColorHexConformsBothVariants() throws {
    let store = try makeStore()
    let color = try store.addColor(name: "Teal", lightHex: "#B8E8FF", darkHex: "#144D6E")
    // Picked in Dark Mode: the light well still receives a dark value.
    try store.setColorHex(color, lightHex: "#144D6E", darkHex: "#144D6E")
    #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false))
    #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true))
}

// MarkupContainerTests
@Test func launchConformsStoredColorsOutsideTheBandOnce() throws {
    let container = try MarkupContainer.make(inMemory: true)
    let context = container.mainContext
    context.insert(HighlightColor(name: "Old", lightHex: "#1F4C7A", darkHex: "#FFFFFF", sortOrder: 9, isDefault: false))
    try context.save()
    #expect(try MarkupContainer.conformColorsIfNeeded(in: context) == 1)
    #expect(try MarkupContainer.conformColorsIfNeeded(in: context) == 0)
    let old = try context.fetch(FetchDescriptor<HighlightColor>()).first { $0.name == "Old" }!
    #expect(MarkLightness.isInBand(hex: old.lightHex, dark: false))
    #expect(MarkLightness.isInBand(hex: old.darkHex, dark: true))
}
```

The `hex(oklchL:chroma:hueDegrees:)` test helper lives in `PaletteTests` (or a shared `OKLCHFixtures.swift` in the UI test target) and uses `MarkLightness`'s public conversion if exposed, else its own copy of the matrices.

- [ ] **Step 2: Run to verify failure** — `--filter 'MarkLightnessTests|PaletteTests|MarkupStoreTests|MarkupContainerTests'`; expected: `MarkLightness` undefined.

- [ ] **Step 3: Implement** `MarkLightness` (OKLab per Björn Ottosson's reference matrices; `conformed` = parse → OKLab → polar → clamp L to the band → step chroma down until `srgbHex()` is non-nil → hex), the store clamp, the container migration, the app's call (after `migrateDefaultColorsIfNeeded`), the sheet preview and copy, and the Settings start values. Update DESIGN.md's Marks paragraph: the band is enforced by the store from this milestone.

- [ ] **Step 4: Run the suite** — expected all pass.

- [ ] **Step 5: Build and look.** Add a color from the selection menu picking a deep navy: the swatch applied is a pale blue and the text stays dark on it in light mode; switch to dark, the mark is a deep blue with light text. In Settings › Markup, set a well to black: it lands at the band's gray.

- [ ] **Step 6: Commit** — `feat: highlight colors held to the defaults' lightness band, in the sheet, the wells and the store`.

---

### Task 6: Marked chapters and the sidebar search (pure parts)

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureModel/MarkupStore.swift` (after `allBookmarks` :93)
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/FrontPageSearch.swift`, `Packages/ScriptureKit/Tests/ScriptureUITests/FrontPageSearchTests.swift`
- Test: `Packages/ScriptureKit/Tests/ScriptureModelTests/MarkupStoreTests.swift`

**Interfaces:**
- Produces on `MarkupStore`: `public func markedChapters() throws -> Set<ChapterLocation>` (every chapter with at least one highlight, note or bookmark; conversations do not count).
- Produces: `public struct FrontPageSearchResults: Equatable, Sendable { public let reference: Reference?; public let books: [TranslationBook] }` and `public enum FrontPageSearch { public static func results(query: String, books: [TranslationBook]) -> FrontPageSearchResults }`: an empty or whitespace query returns `(nil, books)`; otherwise `reference` is `ReferenceParser.parse(trimmed)` when the book is in `books` and the chapter (if any) is within its `chapterCount`, and `books` is `ReferenceParser.matchBooks(prefix:)` filtered to the translation's books, in canon order, with the referenced book first when present.

- [ ] **Step 1: Write the failing tests**

```swift
// MarkupStoreTests
@Test func markedChaptersListsEveryChapterWithAMark() throws {
    let store = try makeStore()
    let color = try store.colors()[0]
    _ = try store.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "WEB", colorID: color.uuid, quotedText: "Blessed")
    _ = try store.addChapterNote(book: "PSA", chapter: 23, translationID: "WEB", body: "Shepherd", sourceThreadID: nil)
    _ = try store.toggleBookmark(at: VerseLocation(book: "TOB", chapter: 1, verse: 1))
    #expect(try store.markedChapters() == [ChapterLocation(book: "MAT", chapter: 5), ChapterLocation(book: "PSA", chapter: 23), ChapterLocation(book: "TOB", chapter: 1)])
}

// FrontPageSearchTests
@MainActor @Suite struct FrontPageSearchTests {
    private func books() throws -> [TranslationBook] { try NavigationModel(store: FixtureStore.make(), positionStore: ReadingPositionStore(defaults: UserDefaults(suiteName: "FrontPageSearchTests")!), defaultTranslationID: "WEB").books }

    @Test func anEmptyQueryListsEveryBook() throws {
        let results = FrontPageSearch.results(query: "  ", books: try books())
        #expect(results.reference == nil)
        #expect(results.books.map(\.book.id) == ["PSA", "MAT", "TOB"])
    }

    @Test func aPrefixFiltersBooks() throws {
        #expect(FrontPageSearch.results(query: "ma", books: try books()).books.map(\.book.id) == ["MAT"])
    }

    @Test func aReferenceOffersGoToAndKeepsItsBookFirst() throws {
        let results = FrontPageSearch.results(query: "Ps 2", books: try books())
        #expect(results.reference?.displayString == "Psalm 2")
        #expect(results.books.first?.book.id == "PSA")
    }

    @Test func aReferencePastTheBookEndOffersNoGoTo() throws {
        let results = FrontPageSearch.results(query: "Matt 99", books: try books())
        #expect(results.reference == nil)
        #expect(results.books.map(\.book.id) == ["MAT"])
    }
}
```

- [ ] **Step 2: Run to verify failure** — `--filter 'FrontPageSearchTests|MarkupStoreTests/markedChapters'`; expected: undefined symbols.

- [ ] **Step 3: Implement** both. `markedChapters` fetches the three tables once each and unions their `(book, chapter)` pairs.

- [ ] **Step 4: Run the suite** — expected all pass.

- [ ] **Step 5: Commit** — `feat: markedChapters query and the front page search logic`.

---

### Task 7: The shelf, the sidebar search and the marked dots (views)

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/BookshelfView.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/FrontPageView.swift`, `ChapterGridView.swift`, `Apps/Mac/ReadingThroughScripture/MainWindowView.swift:118-125`, `DESIGN.md` (Navigation › Front page; components `chapter-cell` gain the marked dot; copy for the search prompt), `README.md` (Keyboard and front page paragraphs)

**Interfaces:**
- Consumes: `FrontPageSearch.results(query:books:)`, `MarkupStore.markedChapters()` through a new `MarkupModel.markedChapters() -> Set<ChapterLocation>` (a wrapper that logs and returns `[]` on error).
- Produces: `public struct BookshelfView: View { init(books: [TranslationBook], selectedBookID: Binding<String?>, currentLocation: ChapterLocation?, markedChapters: Set<ChapterLocation>, onSelectChapter: @escaping (ChapterLocation) -> Void) }`. Inside: `ScrollViewReader` → `ScrollView` → `LazyVStack(spacing: AppSpacing.xxl)` of `ChapterGridView` per book, each `.id(book.id)`, `.scrollTargetLayout()`, `.scrollPosition(id: $topBookID, anchor: .top)`, `.padding(.vertical, AppSpacing.xxl)`. `onChange(of: selectedBookID)`: when it differs from `topBookID`, set `isScrollingProgrammatically = true` and `proxy.scrollTo(id, anchor: .top)` inside `withAnimation(reduceMotion ? nil : .smooth)`; `onChange(of: topBookID)`: if `!isScrollingProgrammatically`, `selectedBookID = topBookID`; the flag clears when `topBookID` becomes the requested id. On appear, scroll without animation to `selectedBookID`.
- Produces on `ChapterGridView.init`: `markedChapters: Set<Int> = []`, and `alignment` becomes centred (`VStack(alignment: .center)`, `LazyVGrid(alignment: .center)`, the book name `.multilineTextAlignment(.center)`); a marked cell draws `Circle().fill(Color.inkTertiary).frame(width: dotSize, height: dotSize)` (`@ScaledMetric(relativeTo: .title3) dotSize = 3`) at the bottom inside the cell, `accessibilityValue` "Has notes" (joined with "Where you left off" when both). Keyboard: cells are `.focusable()` with `@FocusState<Int?>`; `onKeyPress(.leftArrow / .rightArrow / .upArrow / .downArrow)` move by 1 or 5 within `1...chapterCount`; `.return` runs `onSelect`.
- Produces on `FrontPageView.init`: `markedChapters: Set<ChapterLocation>`, `onOpenReference: @escaping (Reference) -> Void`. The sidebar list is `.searchable(text: $query, placement: .sidebar, prompt: "Search books or a reference")`, shows `FrontPageSearch.results(query:books:)`: a first row `Label("Go to \(reference.displayString)", systemImage: "arrow.right")` tagged `"go-to"` when `reference != nil`, then the matching books in their canon sections; `.onSubmit(of: .search)` opens the reference when present, else selects the first matching book; an empty result shows `ContentUnavailableView.search(text: query)`. The detail is `BookshelfView`.
- `MainWindowView` passes `markedChapters` from a `@State` refreshed in `.onChange(of: model.screen, initial: true)` when it becomes `.frontPage`, and `onOpenReference: { model.open($0) }`.

- [ ] **Step 1: Build the shelf and the search as specified.** No new unit tests: the logic is in Task 6; the views are checked in the app (Step 3) and by the suite still passing.

- [ ] **Step 2: Run the suite** — expected all pass.

- [ ] **Step 3: Build and verify in the app** (System Events, screenshots to the scratchpad): the front page opens scrolled to the current book with its chapter on the wash; clicking Numbers in the sidebar scrolls the shelf to Numbers; scrolling the shelf by hand to Deuteronomy moves the sidebar selection to Deuteronomy and the shelf does not jump back; typing "rom 8" in the sidebar field shows "Go to Romans 8" then Romans; Return opens Romans 8; typing "zz" shows the search empty state; a chapter with a note shows the dot; Tab into a grid, arrows move the focus ring, Return opens. Reduce Motion on: the sidebar click lands without animation. Dark Mode screenshot of the shelf.

- [ ] **Step 4: Documentation.** DESIGN.md: Front page becomes "a `NavigationSplitView` whose sidebar carries a search field and whose detail is the shelf: every book's grid in one column, centred"; `chapter-cell` notes the 3 pt `ink.tertiary` dot. README: the front page paragraph (search, Go to, shelf, dots) and Keyboard (arrows in the grid).

- [ ] **Step 5: Commit** — `feat: the shelf: every book's grid in one column, a sidebar search, dots on marked chapters`.

---

### Task 8: Markdown export (pure)

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserLoader.swift`, `MarkdownExport.swift`, `NotesExporter.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserEntry.swift` (`colorName: String?`, defaulted), `NotesBrowserModel.swift:163-272` (the private entry builders move to the loader)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/MarkdownExportTests.swift`, `NotesExporterTests.swift`, existing `NotesBrowserModelTests` (unchanged, must pass)

**Interfaces:**
- Produces: `public enum NotesBrowserLoader { @MainActor public static func entries(store: MarkupStore, query: String) throws -> [NotesBrowserEntry] }` (empty query means everything; threads matched as `NotesBrowserModel.threads(matching:)` does today). `NotesBrowserModel.applySearch` calls it.
- Produces: 
  ```swift
  public enum MarkdownExport {
      public enum Layout: String, CaseIterable, Sendable { case singleFile, folderPerBook }
      public struct Options: Equatable, Sendable { public var layout: Layout; public var includesConversations: Bool; public init(layout: Layout = .singleFile, includesConversations: Bool = true) }
      public struct File: Equatable, Sendable { public let relativePath: String; public let text: String }
      public struct Output: Equatable, Sendable { public let name: String; public let files: [File] }   // name: "Reading Through Scripture Notes 2026-11-01" (+ ".md" for a single file)
      public struct Context { public var verseText: (VerseLocation, String) -> String?; public var thread: (UUID) -> ThreadSnapshot?; public var currentTranslationID: String; public var exportedAt: Date }
      public static func render(entries: [NotesBrowserEntry], options: Options, context: Context) -> Output
  }
  ```
  Entries are grouped by `bookOrder` then `chapter` then `verse` then `modifiedAt` regardless of the browser's sort. Exact text (one blank line between blocks; dates via `Date.FormatStyle(date: .long, time: .omitted)` in the current locale):
  ```
  # Reading Through Scripture: Notes

  _Exported 1 November 2026 · 42 items_

  ## Matthew

  ### Matthew 5

  > “Blessed are the poor in spirit” — Matthew 5:3 (ESV)

  The note body, exactly as written.

  _Note · Yellow · 30 October 2026_

  > “Blessed are the peacemakers” — Matthew 5:9 (ESV)

  _Highlight · Rose · 30 October 2026_

  > “Blessed are the merciful, for they shall receive mercy.” — Matthew 5:7 (ESV)

  _Bookmark · 30 October 2026_

  **Chapter note**

  The body.

  _Note · 30 October 2026_

  #### Overall summary: Matthew 5

  **You:** Overall summary

  **Assistant (Claude · claude-opus-5-5):** The reply, as written.

  _Conversation · 30 October 2026_
  ```
  A noteless highlight without a color reads `_Highlight · 30 October 2026_`. A bookmark whose verse the current translation lacks reads `> Matthew 5:7 (text not available in ESV)`. A conversation turn's model label is `ProviderLabel.text(...)`; a reader turn uses `displayText ?? content`. `folderPerBook` writes `<Book name>.md` per book (each beginning at `# <Book name>` with the same chapter sections and the exported line under it) and a `README.md` with the title and item count; `singleFile` writes one file whose `relativePath` is the dated name. The item count counts entries rendered.
- Produces: `@MainActor public final class NotesExporter { public init(markup: MarkupStore, bible: BibleStore); public func allEntries() throws -> [NotesBrowserEntry]; public func output(entries: [NotesBrowserEntry], options: MarkdownExport.Options, currentTranslationID: String, now: Date = Date()) throws -> MarkdownExport.Output }` (builds the `Context` from `bible.chapter(_:translationID:)` and `markup.chat.thread(id:)` → `ThreadSnapshot`).

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor @Suite struct MarkdownExportTests {
    private let day = Date(timeIntervalSince1970: 1_793_574_000)   // 1 November 2026
    private func note(_ body: String, verse: Int = 3, color: String? = "Yellow") -> NotesBrowserEntry {
        NotesBrowserEntry(id: UUID(), kind: .note(noteID: UUID(), highlightID: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: verse, endVerse: verse,
                          referenceString: "Matthew 5:\(verse)", translationID: "ESV", color: color.map { _ in MarkupColor(lightHex: "#F8E18A", darkHex: "#554704") },
                          quotedText: "Blessed are the poor in spirit", body: body, modifiedAt: day, colorName: color)
    }
    private var context: MarkdownExport.Context {
        .init(verseText: { location, _ in location.verse == 7 ? "Blessed are the merciful." : nil }, thread: { _ in nil }, currentTranslationID: "ESV", exportedAt: day)
    }

    @Test func aNoteRendersQuoteCitationBodyAndMeta() {
        let output = MarkdownExport.render(entries: [note("The body.")], options: .init(), context: context)
        #expect(output.files.count == 1)
        #expect(output.files[0].text.contains("## Matthew\n\n### Matthew 5\n\n> “Blessed are the poor in spirit” — Matthew 5:3 (ESV)\n\nThe body.\n\n_Note · Yellow · "))
        #expect(output.name.hasSuffix(".md"))
    }

    @Test func entriesGroupByBookThenChapterInCanonOrder() {
        let psalm = NotesBrowserEntry(id: UUID(), kind: .bookmark(id: UUID()), book: "PSA", bookOrder: 19, chapter: 23, verse: 1, endVerse: 1, referenceString: "Psalm 23:1", translationID: nil, color: nil, quotedText: "", body: "", modifiedAt: day)
        let text = MarkdownExport.render(entries: [note("Later"), psalm], options: .init(), context: context).files[0].text
        #expect(text.range(of: "## Psalms")!.lowerBound < text.range(of: "## Matthew")!.lowerBound)
    }

    @Test func aBookmarkQuotesTheVerseAndSaysWhenItCannot() {
        func bookmark(_ verse: Int) -> NotesBrowserEntry { NotesBrowserEntry(id: UUID(), kind: .bookmark(id: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: verse, endVerse: verse, referenceString: "Matthew 5:\(verse)", translationID: nil, color: nil, quotedText: "", body: "", modifiedAt: day) }
        let text = MarkdownExport.render(entries: [bookmark(7), bookmark(8)], options: .init(), context: context).files[0].text
        #expect(text.contains("> “Blessed are the merciful.” — Matthew 5:7 (ESV)\n\n_Bookmark · "))
        #expect(text.contains("> Matthew 5:8 (text not available in ESV)"))
    }

    @Test func conversationsFollowTheOptionAndTheCount() {
        let thread = NotesBrowserEntry(id: UUID(), kind: .thread(id: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: 0, endVerse: 0, referenceString: "Matthew 5", translationID: "ESV", color: nil, quotedText: "", body: "Overall summary: Matthew 5", modifiedAt: day)
        let with = MarkdownExport.render(entries: [note("A"), thread], options: .init(includesConversations: true), context: context).files[0].text
        let without = MarkdownExport.render(entries: [note("A"), thread], options: .init(includesConversations: false), context: context).files[0].text
        #expect(with.contains("#### Overall summary: Matthew 5") && with.contains("· 2 items_"))
        #expect(!without.contains("####") && without.contains("· 1 item_"))
    }

    @Test func folderLayoutWritesOneFilePerBookPlusAReadme() {
        let psalm = NotesBrowserEntry(id: UUID(), kind: .highlight(id: UUID()), book: "PSA", bookOrder: 19, chapter: 23, verse: 1, endVerse: 1, referenceString: "Psalm 23:1", translationID: "ESV", color: nil, quotedText: "The Lord", body: "", modifiedAt: day)
        let output = MarkdownExport.render(entries: [note("A"), psalm], options: .init(layout: .folderPerBook), context: context)
        #expect(output.files.map(\.relativePath) == ["README.md", "Psalms.md", "Matthew.md"])
        #expect(output.files[1].text.hasPrefix("# Psalms\n"))
        #expect(!output.name.hasSuffix(".md"))
    }
}
```

`NotesExporterTests`: build a `MarkupStore` on an in-memory container (as `MarkupStoreTests` does) and `FixtureStore.make()`; add a bookmark at `MAT 1:1` and a note; assert `output(entries: try exporter.allEntries(), options: .init(), currentTranslationID: "WEB").files[0].text` contains the WEB text of Matthew 1:1 from the fixture and the note body. Add one `NotesBrowserModelTests` assertion that `entries` carry `colorName` for a colored highlight.

- [ ] **Step 2: Run to verify failure** — `--filter 'MarkdownExportTests|NotesExporterTests'`; expected: undefined symbols.

- [ ] **Step 3: Implement.** Move the builders out of `NotesBrowserModel` into `NotesBrowserLoader` (behaviour identical; `colorName` filled from the colors list), write `MarkdownExport.render` and `NotesExporter`. Citation form reuses the exact string `MarkupModel.copyWithReference` produces (`“text” — Reference (ID)`).

- [ ] **Step 4: Run the suite** — expected all pass, including `NotesBrowserModelTests` and `NotesBrowserQueryTests` unchanged.

- [ ] **Step 5: Commit** — `feat: Markdown export of notes, highlights, bookmarks and conversations`.

---

### Task 9: Export from the File menu and the Notes browser

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/ExportPanel.swift` (`#if os(macOS)`)
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/NotesBrowserView.swift` (toolbar, init), `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift` (exporter, command, Notes window), `README.md` (Notes browser and a new "Exporting notes" paragraph), `DESIGN.md` (symbol `square.and.arrow.up`)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/ExportPanelTests.swift` (the defaults round trip only)

**Interfaces:**
- Produces: `@MainActor public enum ExportPanel { public static let layoutKey = "exportLayout"; public static let includesConversationsKey = "exportIncludesConversations"; public static func options(from defaults: UserDefaults) -> MarkdownExport.Options; public static func remember(_ options: MarkdownExport.Options, in defaults: UserDefaults); public static func present(in window: NSWindow?, defaults: UserDefaults = .standard, render: @escaping (MarkdownExport.Options) throws -> MarkdownExport.Output) }`. `present` builds an `NSSavePanel` (`canCreateDirectories = true`, `isExtensionHidden = false`, `nameFieldStringValue` from a first `render(options)` call's `name`) with an `NSHostingView` accessory holding a `Picker("Layout")` (One file / One file per book) and a `Toggle("Include conversations")`; changing the layout updates `nameFieldStringValue` and `allowedContentTypes` (`[.plainText]` for a file, `[]` for a folder). On OK: `folderPerBook` creates the directory at the chosen URL and writes each file inside; `singleFile` writes the one file. Errors show an `NSAlert` with "The notes could not be exported." and the detail in the log. Then `remember`.
- Produces on `NotesBrowserView.init`: `onExport: @escaping ([NotesBrowserEntry]) -> Void`; a toolbar `Button { onExport(model.entries) } label: { Label("Export", systemImage: "square.and.arrow.up") }` with `.help("Export these notes as Markdown…")`, disabled when `model.entries.isEmpty`.
- App: a `NotesExporter` built in `init` from `markupStore` and the `BibleStore`; `CommandGroup(replacing: .importExport) { Button("Export Notes…") { … }.keyboardShortcut("e", modifiers: [.command, .shift]) }` presenting `ExportPanel` over the key window with `exporter.allEntries()`; the Notes window's `onExport` presents it with the given entries. Both pass `currentTranslationID: model.translationID`.

- [ ] **Step 1: Write the failing test**

```swift
@MainActor @Suite struct ExportPanelTests {
    @Test func optionsRoundTripThroughDefaults() {
        let defaults = UserDefaults(suiteName: "ExportPanelTests-\(UUID().uuidString)")!
        #expect(ExportPanel.options(from: defaults) == MarkdownExport.Options(layout: .singleFile, includesConversations: true))
        ExportPanel.remember(MarkdownExport.Options(layout: .folderPerBook, includesConversations: false), in: defaults)
        #expect(ExportPanel.options(from: defaults) == MarkdownExport.Options(layout: .folderPerBook, includesConversations: false))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `--filter ExportPanelTests`; expected: undefined.

- [ ] **Step 3: Implement** the panel, the toolbar button, the command and the wiring; add `square.and.arrow.up` to DESIGN.md's inventory under navigation; README: "Exporting notes" (File › Export Notes… ⇧⌘E for everything, the browser's Export for what it shows, the two layouts, the conversations toggle, the citation form).

- [ ] **Step 4: Run the suite** — expected all pass.

- [ ] **Step 5: Build and verify in the app.** ⇧⌘E: the panel shows the dated name, Layout and Include conversations; export one file to the scratchpad and open it in a text editor: title, a book, a chapter, a blockquote with the citation, the body, the meta line. Switch to One file per book: the name loses `.md`, exporting makes a folder with `README.md` and one file per book. In the Notes window, filter to Bookmarks and Export: only bookmarks appear in the file. Cancel leaves no file.

- [ ] **Step 6: Commit** — `feat: Export Notes from the File menu and the Notes browser, layout chosen in the save panel`.

---

### Task 10: Prompt templates: summaries, sections, new wording, Settings

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureModel/PromptTemplate.swift`, `PromptTemplateStore.swift`, `Packages/ScriptureKit/Sources/ScriptureLLM/BuiltInPrompts.swift`, `Packages/ScriptureKit/Sources/ScriptureUI/AssistantItems.swift` (`PromptTemplateItem`), `AssistantModel.swift:108-120` (`prompts`, `reloadTemplates`), `PromptTemplatesSettingsView.swift`, `ColumnRowParts.swift` (`editorSurface()`), `AssistantComposer.swift`, `NoteRowView.swift`, `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift:42` (migration call), `README.md` (Settings › Prompts)
- Test: `Packages/ScriptureKit/Tests/ScriptureModelTests/PromptTemplateStoreTests.swift`, `Packages/ScriptureKit/Tests/ScriptureLLMTests/BuiltInPromptsTests.swift` (create)

**Interfaces:**
- Produces: `public enum PromptSection: String, Codable, CaseIterable, Sendable { case orient, study, reflect, passage, custom; public var title: String }` with titles "Get oriented", "Dig in", "Take it with you", "About the passage", "Your prompts"; `PromptSeed.init(key:title:summary:body:scope:section:legacyTitle:)` (`legacyTitle` is the milestone 5 title, used by the migration); `PromptTemplate.summary: String = ""`, `sectionRaw: String?`, `var section: PromptSection` (nil → `.custom`); `PromptTemplate.init(title:summary:body:scope:section:sortOrder:isBuiltIn:builtInKey:)` with the old initialiser kept.
- Produces on `PromptTemplateStore`: `add(title:summary:body:scope:) -> PromptTemplate` (section `.custom`; the old `add(title:body:scope:)` forwards with an empty summary), `update(_:title:summary:body:)` (old `update(_:title:body:)` forwards keeping the summary), `restoreBuiltIn` restores summary and section too, `move(_ template: PromptTemplate, by offset: Int) throws` (±1 within its scope), and `@discardableResult migrateBuiltInsIfNeeded(from seeds: [PromptSeed]) throws -> Int`: for every built-in whose seed is found, (a) if `title == seed.legacyTitle && body == seed.body` then `title = seed.title`; (b) if `summary.isEmpty` then `summary = seed.summary`; (c) if `sectionRaw == nil` then `section = seed.section`; returns how many records changed; idempotent.
- Produces on `PromptTemplateItem`: `summary: String`, `section: PromptSection` (init gains both); `AssistantModel.prompts` orders enabled templates by section (`PromptSection.allCases` order) then `sortOrder`.
- Produces: `extension View { func editorSurface() -> some View }` in `ColumnRowParts.swift` (`paper.overlay` fill at `AppRadius.md`, 1 pt `ink.rule` stroke, continuous), used by the composer field, the prompt body `TextEditor` and the note editor's host in `NoteRowView` (the three places the style is repeated today; `ChatTurnRow`'s bubble is not an editor and keeps its own fill).
- Settings › Prompts: within Chapter prompts the rows are grouped under the three section titles (Label style), Selection prompts under one; the expanded area shows `TextField("Summary", text:)` (placeholder "One or two sentences shown under the title") above the body; the row's context menu offers "Move Up" and "Move Down" (disabled at the ends) calling `store.move(_:by:)`; `isEdited` also compares the summary; Restore puts back title, summary and body.
- The fourteen seeds (key: title / summary; bodies unchanged):
  - `catch-me-up` (orient): **Catch me up** / "Where the story or argument stands as this chapter opens, in a few sentences."
  - `context` (orient): **Set the scene** / "Where this chapter sits in the book, what came before, the historical setting and who first read it."
  - `overall-summary` (orient): **Summarize this chapter** / "Two or three short paragraphs on what happens or is argued, and why it matters in the book."
  - `outline` (orient): **Outline this chapter** / "A numbered list of its sections, each with a verse range and a short heading."
  - `key-themes` (study): **Name the key themes** / "Three to five themes, each in a sentence or two, with the verses that carry them."
  - `cross-references` (study): **Find cross-references** / "Passages elsewhere that this chapter quotes, echoes or is read alongside, with a few words on each connection."
  - `people-and-places` (study): **Identify people and places** / "Who and where is named here, with a sentence on each and where else they appear."
  - `hard-verses` (study): **Explain the hard verses** / "The verses most often puzzled over, with the main readings careful interpreters hold."
  - `word-study` (study): **Study the key words** / "Two or three words worth a closer look: the Hebrew or Greek behind them, their range of meaning and how they are used."
  - `reflection-questions` (reflect): **Write reflection questions** / "Five questions for a reader studying alone that send you back to the text and into your own life."
  - `memory-verse` (reflect): **Suggest a memory verse** / "One verse from this chapter to carry with you, quoted exactly, with a sentence on why."
  - `explain-this` (passage): **Explain this passage** / "What it says, what it means in its context, and what a careful reader should notice."
  - `define-words` (passage): **Define the words** / "The words that carry the meaning or might be unfamiliar, with the Hebrew or Greek behind them where it helps."
  - `compare-translations` (passage): **Compare translations** / "The same verses in the other bundled translations, with the differences that change the sense and what lies behind them."
  - `legacyTitle` for each is its milestone 5 title (`"Context"`, `"Overall summary"`, …; for the four whose title is unchanged, the same string).
- Panel order: seeds in the order above within each section (orient: catch-me-up, context, overall-summary, outline; study: key-themes, cross-references, people-and-places, hard-verses, word-study; reflect: reflection-questions, memory-verse). The migration does not renumber `sortOrder`; the section grouping gives the order.

- [ ] **Step 1: Write the failing tests**

```swift
// BuiltInPromptsTests (ScriptureLLMTests)
@Suite struct BuiltInPromptsTests {
    @Test func everyBuiltInHasAShortTitleAndASentenceOrTwo() {
        for seed in BuiltInPrompts.all {
            #expect(seed.title.split(separator: " ").count <= 5, seed.key)
            #expect(seed.summary.hasSuffix("."), seed.key)
            #expect(seed.summary.count <= 160, seed.key)
            #expect(seed.summary.components(separatedBy: ". ").count <= 2, seed.key)
            #expect(!seed.legacyTitle.isEmpty, seed.key)
        }
    }

    @Test func sectionsMatchScopes() {
        for seed in BuiltInPrompts.all {
            #expect((seed.scope == .selection) == (seed.section == .passage), seed.key)
            #expect(seed.section != .custom, seed.key)
        }
    }
}

// PromptTemplateStoreTests
@Test func migrationRenamesUneditedBuiltInsAndFillsSummaries() throws {
    let store = try make()
    let old = PromptSeed(key: "overall-summary", title: "Overall summary", summary: "", body: "B", scope: .chapter, section: .custom, legacyTitle: "Overall summary")
    try store.seedIfNeeded([old])
    let new = PromptSeed(key: "overall-summary", title: "Summarize this chapter", summary: "Two or three paragraphs.", body: "B", scope: .chapter, section: .orient, legacyTitle: "Overall summary")
    #expect(try store.migrateBuiltInsIfNeeded(from: [new]) == 1)
    let template = try store.templates()[0]
    #expect(template.title == "Summarize this chapter")
    #expect(template.summary == "Two or three paragraphs.")
    #expect(template.section == .orient)
    #expect(try store.migrateBuiltInsIfNeeded(from: [new]) == 0)
}

@Test func anEditedBuiltInKeepsItsTitleButGainsSummaryAndSection() throws {
    let store = try make()
    let old = PromptSeed(key: "context", title: "Context", summary: "", body: "B", scope: .chapter, section: .custom, legacyTitle: "Context")
    try store.seedIfNeeded([old])
    try store.update(try store.templates()[0], title: "My context", body: "B")
    let new = PromptSeed(key: "context", title: "Set the scene", summary: "Where it sits.", body: "B", scope: .chapter, section: .orient, legacyTitle: "Context")
    _ = try store.migrateBuiltInsIfNeeded(from: [new])
    let template = try store.templates()[0]
    #expect(template.title == "My context")
    #expect(template.summary == "Where it sits.")
    #expect(template.section == .orient)
}

@Test func moveByOneStaysInsideTheScope() throws {
    let store = try make()
    let a = try store.add(title: "A", summary: "", body: "", scope: .chapter)
    let b = try store.add(title: "B", summary: "", body: "", scope: .chapter)
    let s = try store.add(title: "S", summary: "", body: "", scope: .selection)
    try store.move(b, by: -1)
    #expect(try store.templates(scope: .chapter).map(\.title) == ["B", "A"])
    try store.move(s, by: -1)
    #expect(try store.templates(scope: .selection).map(\.title) == ["S"])
    _ = a
}
```

- [ ] **Step 2: Run to verify failure** — `--filter 'BuiltInPromptsTests|PromptTemplateStoreTests'`; expected: compile failures on the new members.

- [ ] **Step 3: Implement** the model fields, the store methods, the seeds, the item, the model's ordering, `editorSurface()` and its three adoptions, the Settings pane changes, and the app's `try templates.migrateBuiltInsIfNeeded(from: BuiltInPrompts.all)` right after `seedIfNeeded`. README: Settings › Prompts gains the summary field, the sections and Move Up / Move Down.

- [ ] **Step 4: Run the suite** — expected all pass (the `AssistantModelTests` that name a template title, such as `"Overall summary"`, are updated to the new titles).

- [ ] **Step 5: Commit** — `feat: prompt summaries and sections; built-ins reworded; Move Up/Down; one editor surface`.

---

### Task 11: Prompt tiles in the panel

**Files:**
- Create: `Packages/ScriptureKit/Sources/ScriptureUI/PromptTilesView.swift`
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChatPanelView.swift:159-200` (`opening`, `promptList`), `DESIGN.md` (component `prompt-tile`; Navigation › Assistant panel paragraph; symbol inventory note that `text.quote` now appears only on the Settings tab)

**Interfaces:**
- Consumes: `PromptTemplateItem.summary`, `.section`; `AssistantModel.prompts`, `runPrompt(_:)`, `isResponding`.
- Produces: `struct PromptTilesView: View { let prompts: [PromptTemplateItem]; let isDisabled: Bool; let onRun: (UUID) -> Void }` rendering, per section present in `prompts` (in `PromptSection.allCases` order), a header `Text(section.title).font(.caption.weight(.semibold)).foregroundStyle(Color.inkSecondary)` and a `LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: AppSpacing.xs)], spacing: AppSpacing.xs)` of `PromptTile`s; `@ScaledMetric(relativeTo: .callout) tileMinWidth = 180`.
- Produces: `struct PromptTile: View { let prompt: PromptTemplateItem; let isDisabled: Bool; let action: () -> Void }` as the design brief specifies (title `.callout.weight(.semibold)` `ink.primary`; summary `.caption` `ink.secondary` `lineLimit(3)`, hidden when empty; `AppSpacing.sm` padding; `paper.overlay` → `accent.wash` on hover at `AppRadius.lg` continuous; `.snappy(duration: 0.2)` on the fill, none under Reduce Motion; `.buttonStyle(.plain)`, `.help(summary)`, `accessibilityLabel(title)`, `accessibilityHint(summary)`; `.frame(maxWidth: .infinity, alignment: .leading)` so tiles fill their column).
- `ChatPanelView.opening` shows the quote (if any) then `PromptTilesView` in place of `promptList`; `promptRowPadding` goes.

- [ ] **Step 1: Build the tiles as specified** (no unit test; the data is tested in Task 10).

- [ ] **Step 2: Run the suite** — expected all pass.

- [ ] **Step 3: Build and verify in the app.** Right-click a heading, Ask About This Chapter: three sections of tiles, two columns at the inspector's default width, one column at 260 pt; hover lifts a tile to the wash; a click sends it and the tiles go; select a phrase, Ask About This Passage: "About the passage" with three tiles; add a prompt in Settings: it appears under "Your prompts"; hide every chapter prompt: no tiles, no headers. Dark Mode screenshot. AX3 text size: tiles wrap to one column and summaries clip at three lines with the full text in the help tag.

- [ ] **Step 4: DESIGN.md.** Add `prompt-tile` to the frontmatter components (`backgroundColor: {colors.paper-overlay}`, `textColor: {colors.ink-primary}`, `typography: {typography.body}`, `rounded: {rounded.lg}`, `padding: "12 12"`) and to Components › Navigation › Assistant panel ("the scope's prompts as tonal tiles, title and a sentence, in sections, hover `accent.wash`").

- [ ] **Step 5: Commit** — `feat: prompts as tiles with a title and a sentence, in sections`.

---

### Task 12: Assistant model minors: Try Again, one note per reply, finish reasons, host, identity, VoiceOver

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureModel/ChatMessage.swift`, `ChatStore.swift` (`append`, `MessageSnapshot`, `restore`), `Packages/ScriptureKit/Sources/ScriptureUI/AssistantItems.swift` (`ChatMessageItem`, `ProviderLabel`), `AssistantModel.swift` (`submit` :263, `stream` :319, `finishResponse` :344, `addAsNote` :474, `label` :618)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/AssistantModelTests.swift`, `Packages/ScriptureKit/Tests/ScriptureModelTests/ChatStoreTests.swift`

**Interfaces:**
- Produces on `ChatMessage`: `savedNoteID: UUID?`, `providerHost: String?`, `finishReason: String?` (`"declined"`, `"cutShort"`, `"stopped"`, nil for a complete reply).
- Produces on `ChatStore`: `append(to:role:content:displayText:providerID:modelName:providerHost:attachedReference:finishReason:uuid:) -> ChatMessage` (the two existing overloads forward with nils; `uuid` when given becomes the record's `uuid`), `setSavedNote(_ noteID: UUID?, on message: ChatMessage) throws`; `MessageSnapshot` carries and restores the three fields.
- Produces on `ChatMessageItem`: `savedNoteID: UUID?`, `finishReason: ChatFinishReason?` where `public enum ChatFinishReason: String, Sendable { case declined, cutShort, stopped; public var footerText: String }` ("Declined partway", "Cut short", "Stopped"); the init gains both with defaults.
- Produces on `ProviderLabel`: `text(providerID:modelName:host: String?)` (host wins over the Settings base URL for `.openAICompatible`; the old signature forwards with `host: nil`).
- Produces on `AssistantModel`: `public var canRetry: Bool` (true when `notice != nil` after a failed send, or the last message is a reader turn with no assistant turn after it, and `!isResponding`), `public func retry()` (re-submits the stored last submission: it keeps `lastSubmission: (request: LLMRequest, provider: any LLMProvider, routed: RoutingPreference)` from `submit`, appends a fresh streaming item and calls `stream`; when routing must run again because the provider changed, it re-routes the same request), `public func savedNoteID(for messageID: UUID) -> UUID?` (nil when the note no longer exists in the store), `public func showSavedNote(messageID: UUID)` (calls `onNoteSaved` with it), `public var lastReplyID: UUID?` (the newest complete assistant message), `public func copyLastReply() -> String?`, `public func addLastReplyAsNote()`.
- Behaviour in `finishResponse`: the saved record keeps the streaming item's `id` (`uuid:`), records `providerHost` (`provider.baseURL.host()` for a compatible provider, via a new `LLMProvider` requirement `var hostName: String? { get }` defaulted nil in an extension and set by `OpenAICompatibleProvider`), and `finishReason` from the failure (`.declined` → "declined", `.cutShort` → "cutShort", `CancellationError` → "stopped"); after a non-empty reply posts `AccessibilityNotification.Announcement("The assistant has finished answering.").post()` (macOS 14+ API, `#if canImport(AppKit)`). A failure that left no text keeps the reader's turn in the thread as now; `notice` is set as now.
- `addAsNote` calls `setSavedNote(noteID, on:)` and updates the item; a second click on a saved reply is a no-op (the view shows "Show Note" instead, Task 14).

- [ ] **Step 1: Write the failing tests** (names and assertions; use the suite's existing `makeModel` and `FakeProvider` helpers)

```swift
@Test func aFailedQuestionStaysAndTryAgainResends() async throws {
    let provider = onDevice([], failure: .transport("down"))
    let h = try make([provider])
    h.model.askAboutChapter(); h.model.draft = "Why?"; h.model.send()
    try await settle(h.model)
    #expect(h.model.notice == .unreachable)
    #expect(h.model.messages.map(\.role) == [.user])
    #expect(h.model.canRetry)
    provider.deltas = ["Because."]; provider.failure = nil
    h.model.retry()
    try await settle(h.model)
    #expect(h.model.notice == nil)
    #expect(h.model.messages.map(\.role) == [.user, .assistant])
    #expect(h.model.messages.last?.content == "Because.")
    #expect(provider.requests.count == 2)
}

@Test func theReplyKeepsItsRowIdentityWhenSaved() async throws {
    let h = try make([onDevice(["Peace."])])
    h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
    let streamingID = h.model.messages.last!.id
    try await settle(h.model)
    #expect(h.model.messages.last?.id == streamingID)
    #expect(try h.markup.chat.thread(id: h.model.thread!.id)!.orderedMessages.last?.uuid == streamingID)
}

@Test func addAsNoteIsRecordedOnTheMessageAndForgottenWhenTheNoteGoes() async throws {
    let h = try make([onDevice(["Peace."])])
    h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
    try await settle(h.model)
    let reply = h.model.messages.last!.id
    h.model.addAsNote(messageID: reply)
    let noteID = try #require(h.model.savedNoteID(for: reply))
    try h.markup.deleteNote(try #require(try h.markup.note(id: noteID)))
    #expect(h.model.savedNoteID(for: reply) == nil)
}

@Test func aCompatibleReplyRemembersItsHost() async throws {
    let provider = FakeProvider(id: .openAICompatible, modelName: "fake-model", deltas: ["Hi"])
    provider.hostName = "lmstudio.local"
    let h = try make([provider])
    h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
    try await settle(h.model)
    #expect(h.model.messages.last?.providerLabel == "lmstudio.local · fake-model")
    h.defaults.set("http://elsewhere:1234/v1", forKey: AssistantSettings.compatibleBaseURLKey)
    h.model.open(threadID: h.model.thread!.id)
    #expect(h.model.messages.last?.providerLabel == "lmstudio.local · fake-model")
}

@Test func aDeclinedPartialReplyIsMarked() async throws {
    let h = try make([onDevice(["Half an answer"], failure: .declined(""))])
    h.model.askAboutChapter(); h.model.draft = "Q"; h.model.send()
    try await settle(h.model)
    #expect(h.model.messages.last?.content == "Half an answer")
    #expect(h.model.messages.last?.finishReason == .declined)
    #expect(h.model.notice == .declined)
}

// ChatStoreTests
@Test func appendKeepsAGivenUUIDAndTheNewFields() throws {
    let store = try make()
    let thread = try store.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "T")
    let id = UUID()
    let message = try store.append(to: thread, role: .assistant, content: "A", displayText: nil, providerID: "openAICompatible", modelName: "m", providerHost: "h", attachedReference: nil, finishReason: "cutShort", uuid: id)
    #expect(message.uuid == id && message.providerHost == "h" && message.finishReason == "cutShort")
    try store.setSavedNote(id, on: message)
    let snapshot = ThreadSnapshot(thread)
    try store.deleteThread(thread)
    try store.restore(snapshot)
    #expect(try store.thread(id: thread.uuid)!.orderedMessages[0].savedNoteID == id)
}
```

`FakeProvider` (both copies) gains `var hostName: String?`; its `deltas` and `failure` are already mutable between sends, which is what the retry test uses.

- [ ] **Step 2: Run to verify failure** — `--filter 'AssistantModelTests|ChatStoreTests'`; expected: compile failures.

- [ ] **Step 3: Implement** as in the Interfaces block.

- [ ] **Step 4: Run the suite** — expected all pass.

- [ ] **Step 5: Commit** — `fix: Try Again, one note per reply, finish reasons, a remembered host, stable reply rows, a VoiceOver announcement`.

---

### Task 13: Provider and key minors

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureLLM/HTTPStreaming.swift`, `OpenAICompatibleProvider.swift:50-70`, `AnthropicProvider.swift` (its parse closure), `AppleFoundationProvider.swift:87`, `SecretStore.swift:46-103`, `LLMProvider.swift` (`hostName`), `Packages/ScriptureKit/Sources/ScriptureUI/AssistantSettings.swift` (`AssistantSettingsModel`), `AssistantSettingsView.swift:72-88`
- Test: `Packages/ScriptureKit/Tests/ScriptureLLMTests/OpenAICompatibleProviderTests.swift`, `AnthropicProviderTests.swift`, `SecretStoreTests.swift` (+ `FakeKeychain.swift`), `Packages/ScriptureKit/Tests/ScriptureUITests/AssistantSettingsTests.swift`

**Interfaces:**
- Produces in `HTTPStreaming`: `enum Step { case events([LLMEvent]); case finished([LLMEvent]); case failed([LLMEvent], LLMProviderError) }`; `stream(request:session:parse: @escaping @Sendable (SSEEvent) throws -> Step)`: `.events` yields and continues; `.finished` yields then completes; `.failed` yields then finishes with the error. At EOF with no `.finished`: if the parser saw a terminal condition (`sawFinish` set by the provider through `.finished`), complete; otherwise `transport(truncatedMessage)` as now.
- OpenAI-compatible parse: `[DONE]` → `.finished([])`; `finish_reason == "stop"` → `.finished(text delta if any)`; `finish_reason == "length"` → `.failed(text delta if any, .cutShort)`; `"content_filter"` → `.failed(text delta if any, .declined(""))`; otherwise `.events`. A stream that ends after a `"stop"` without `[DONE]` is therefore complete.
- Anthropic parse: `message_stop` → `.finished([])`; `message_delta` with `stop_reason == "max_tokens"` → `.failed([], .cutShort)`; `"refusal"` → `.failed([], .declined(""))`; otherwise `.events`.
- `AppleFoundationProvider.map`: `case .guardrailViolation: .declined("")` (the dead ternary goes).
- Produces in `SecretStore.swift`: `public protocol KeychainAccess: Sendable { func copyMatching(_ query: CFDictionary) -> (OSStatus, CFTypeRef?); func add(_ attributes: CFDictionary) -> OSStatus; func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus; func delete(_ query: CFDictionary) -> OSStatus }`, `public struct SecurityKeychain: KeychainAccess` (the four `SecItem*` calls), `KeychainStore.init(service: String = service, access: any KeychainAccess = SecurityKeychain())`. `setSecret`: nil → `delete`; present → `update(query, [kSecValueData: data])`, and only on `errSecItemNotFound` → `add` (with the synchronizable retry as now). The old key is never deleted before the new one is written.
- Produces on `AssistantSettingsModel`: `public func keyFieldChanged(_ id: LLMProviderID)` (cancels and reschedules a save `Task` for 0.4 s), `public func flushPendingSaves()` (saves every scheduled key now). View: `.onChange(of: model.anthropicKey) { model.keyFieldChanged(.anthropic) }` (and the other two), `.onDisappear { model.flushPendingSaves() }`, `.onSubmit` keeps saving at once; the Save button is removed; "Saved" and Remove stay.

- [ ] **Step 1: Write the failing tests**

```swift
// OpenAICompatibleProviderTests (inside `CloudProviderTests`, using the suite's `ok(_:)`, `collect(_:_:)` and `request`)
@Test func aStopWithoutDoneIsComplete() async throws {
    ok(["data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"])
    let provider = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
    let events = try await collect(provider, request)
    #expect(events == [.textDelta("Hi"), .done(nil)])
}

@Test func aLengthFinishWithTextKeepsTheTextThenReportsCutShort() async throws {
    ok(["data: {\"choices\":[{\"delta\":{\"content\":\"Half\"},\"finish_reason\":\"length\"}]}\n\ndata: [DONE]\n\n"])
    let provider = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
    var received: [LLMEvent] = []
    var thrown: (any Error)?
    do { for try await event in provider.stream(request) { received.append(event) } } catch { thrown = error }
    #expect(received == [.textDelta("Half")])
    #expect(thrown as? LLMProviderError == .cutShort)
}

// SecretStoreTests
@Test func savingANewKeyNeverLeavesTheOldOneGone() throws {
    let keychain = FakeKeychain()
    let store = KeychainStore(service: "test", access: keychain)
    try store.setSecret("old", for: .anthropic)
    keychain.failNextWrite = errSecIO
    #expect(throws: SecretStoreError.self) { try store.setSecret("new", for: .anthropic) }
    #expect(try store.secret(for: .anthropic) == "old")
    try store.setSecret("new", for: .anthropic)
    #expect(try store.secret(for: .anthropic) == "new")
    #expect(keychain.adds == 1)   // the second save updated in place
}

// AssistantSettingsTests
@Test func aPastedKeyIsSavedWithoutReturn() async throws {
    let secrets = InMemorySecretStore()
    let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
    model.anthropicKey = "sk-pasted"
    model.keyFieldChanged(.anthropic)
    model.flushPendingSaves()
    #expect(try secrets.secret(for: .anthropic) == "sk-pasted")
    #expect(model.hasAnthropicKey)
}
```

`FakeKeychain`: a dictionary keyed by account, `failNextWrite: OSStatus?`, counters `adds`, `updates`.

- [ ] **Step 2: Run to verify failure** — `--filter 'OpenAICompatibleProviderTests|AnthropicProviderTests|SecretStoreTests|AssistantSettingsTests'`; expected: compile failures and the two stream tests failing.

- [ ] **Step 3: Implement** the `Step` type and both providers' parse closures, the dead line, the `KeychainAccess` seam and update-in-place, and the autosave.

- [ ] **Step 4: Run the suite** — expected all pass (the existing `truncatedStreamThrowsAfterTheDeltasReceived` still holds: no finish reason, EOF → unreachable).

- [ ] **Step 5: Commit** — `fix: streams that end after a finish reason; length keeps its text; keys update in place and save as typed`.

---

### Task 14: Panel and menu minors

**Files:**
- Modify: `Packages/ScriptureKit/Sources/ScriptureUI/ChatTurnRow.swift`, `ChatPanelView.swift:96-150` (menus), `NoteMarkdown.swift`, `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift:160-192` (commands), `README.md` (Study assistant: shortcuts, Copy, Add as Note, Try Again), `DESIGN.md` (symbols: `checkmark` on a copied reply, `note.text` for Show Note)
- Test: `Packages/ScriptureKit/Tests/ScriptureUITests/NoteMarkdownTests.swift`

**Interfaces:**
- Produces: `NoteMarkdown.document(_ body: String) -> AttributedString` (the blocks of `blocks(_:)` joined with `"\n\n"`; headings keep their font).
- `ChatTurnRow`: the reply is one `Text(NoteMarkdown.document(message.content))` with `.textSelection(.enabled)`; init gains `savedNoteID: UUID?`, `onShowNote: () -> Void`; the footer shows, after the provider label, `finishReason?.footerText` in `.caption` `ink.secondary`; Copy swaps its symbol to `checkmark` with the label "Copied" for 1.5 s (`@State copiedAt: Date?`, a `Task.sleep`), posts `AccessibilityNotification.Announcement("Copied")`; when `savedNoteID != nil` the second button is `RowSymbolButton(title: "Show Note", symbol: "note.text", action: onShowNote)` instead of Add as Note.
- `ChatPanelView`: the History menu lists threads through `Picker("Conversations", selection: Binding(get: { model.thread?.id }, set: { if let id = $0 { model.open(threadID: id) } }))` with `.pickerStyle(.inline)` so the menu's own checkmark column is used; each row's label stays title plus date. The plus menu's items read `chapterTitle`, `bookTitle`, "No context" (no "About").
- App: the `Assistant` menu per Ruling 11, using `assistant.canRetry`, `retry()`, `copyLastReply()` (to `NSPasteboard`), `addLastReplyAsNote()`, `openAskingForContext(selection: nil)`; the View menu keeps the Notes column and Notes browser items only.

- [ ] **Step 1: Write the failing test**

```swift
@Test func documentJoinsBlocksWithABlankLine() {
    let document = NoteMarkdown.document("First.\n\nSecond **bold**.")
    #expect(String(document.characters) == "First.\n\nSecond bold.")
    #expect(document.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
}
```

- [ ] **Step 2: Run to verify failure** — `--filter NoteMarkdownTests`; expected: `document` undefined.

- [ ] **Step 3: Implement** everything in the Interfaces block. README: the Assistant menu and its shortcuts; "Copy shows a checkmark for a moment; Add as Note becomes Show Note once a reply is saved; Try Again (⌘R) resends a question that got no answer". DESIGN.md symbol inventory: `checkmark` (Copied), `note.text` (Show Note), `arrow.left`, `square.and.arrow.up` (if not already added).

- [ ] **Step 4: Run the suite** — expected all pass.

- [ ] **Step 5: Build and verify in the app.** Copy a reply: the glyph becomes a checkmark and returns; select across two paragraphs of a reply with one drag; Add as Note, then the button reads Show Note and clicking it lights the note; the History menu shows the open conversation with the system checkmark; the plus menu reads "Matthew 5", "Matthew", "No context"; with Wi-Fi off and a cloud provider chosen, ask: the notice shows and ⌘R resends once the network is back; ⇧⌘C puts the last reply on the pasteboard; VoiceOver on, a reply finishing is announced.

- [ ] **Step 6: Commit** — `fix: Copied, Show Note, whole-reply selection, native History checkmarks, an Assistant menu`.

---

### Task 15: The app icon

**Files:**
- Create: `Apps/Mac/ReadingThroughScripture/Icon/background.svg`, `pages.svg`, `lines.svg`, `highlight.svg`, `AppIcon-flat.svg`, `Scripts/render-icon.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/Assets.xcassets/AppIcon.appiconset/Contents.json` (+ ten PNGs), `README.md` (a line under Building), `DESIGN.md` (Accent paragraph: the icon exists; an "App icon" note under Components)
- Matt's step: `Apps/Mac/ReadingThroughScripture/AppIcon.icon` from Icon Composer

**Interfaces:**
- The artwork is mockup B from the brainstorm: a 1024-point canvas; background verdigris (`#247966`, the `accent` light value; a vertical gradient from `#2E8C77` to `#1E6957` is allowed on the icon alone, DESIGN.md's gradient ban is for the interface); two page shapes in `paper.page` (`#F5F7F9`) meeting at a spine (`#1A5A4A` at 50 percent); four text lines per page as rounded rects in `#C9D1D8`; on the right page the second line is `ink.primary` (`#192028`) over a `mark.yellow` (`#F8E18A`) highlight bar. The layer files hold exactly those groups; `AppIcon-flat.svg` is the composite with the macOS squircle mask applied (so the PNGs have transparent corners).
- `Scripts/render-icon.swift` (run as `swift Scripts/render-icon.swift`): loads `AppIcon-flat.svg` with `NSImage(contentsOf:)`, draws it into bitmaps of 16, 32, 64, 128, 256, 512 and 1024 pixels (`NSBitmapImageRep` at 1x; the 2x slots reuse the next size up), writes `icon_16x16.png`, `icon_16x16@2x.png`, … `icon_512x512@2x.png` into the appiconset, and rewrites `Contents.json` with the `filename` keys. Deterministic; running it twice changes nothing.

- [ ] **Step 1: Write the SVGs** from the mockup geometry (`.superpowers/brainstorm/*/content/icon-and-home.html`, option B; paths may be copied), one layer per file plus the composite.

- [ ] **Step 2: Write and run the render script.** Expected: `ls Apps/Mac/ReadingThroughScripture/Assets.xcassets/AppIcon.appiconset/*.png | wc -l` prints `10`; `sips -g pixelWidth …/icon_512x512@2x.png` prints `1024`; the corners are transparent (`sips -g hasAlpha` yes).

- [ ] **Step 3: Build the app** and check `Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app/Contents/Resources/AppIcon.icns` exists; launch it and screenshot the Dock (scratchpad). Expected: the open book with the highlighted line, legible at Dock size.

- [ ] **Step 4: Matt's step (documented, not automated).** Open Icon Composer, New, import `background.svg` as the background fill and `pages.svg`, `lines.svg`, `highlight.svg` as layers (in that order), check the Light, Dark, Tinted and Clear previews, save as `Apps/Mac/ReadingThroughScripture/AppIcon.icon`, drag it into the Xcode project beside `Assets.xcassets` (target membership on). `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` already matches, and Xcode 26 prefers the `.icon`. The executor then rebuilds and confirms the Dock icon took the glass variant. If Matt defers this, the PNG set ships and the step stays open in this plan.

- [ ] **Step 5: Documentation.** README under Building: "The icon is rendered from `Apps/Mac/ReadingThroughScripture/Icon/AppIcon-flat.svg` by `swift Scripts/render-icon.swift`; the layered `AppIcon.icon` is made in Icon Composer from the same layers." DESIGN.md: the Accent paragraph's "the app icon" is now true; a short "App icon" note (verdigris field, paper pages, one marked line in mark yellow; the one place the accent may carry a gradient).

- [ ] **Step 6: Commit** — `feat: app icon: the open book with one marked line, rendered from SVG layers`.

---

### Task 16: Documentation, verification and the whole-branch review

**Files:**
- Modify: `README.md` (every section touched above, reviewed as a whole), `DESIGN.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (Verification › Milestone 6 is already there; tick what was run), this plan (checkboxes, the verification table)

- [x] **Step 1: README pass.** Read it top to bottom against the app: front page and shelf, search, keyboard (arrows in the grid, ⇧⌘E, the Assistant menu's shortcuts), reading (indents, poetry and stanza air; the progress line, Previous), markup (the lightness band), Notes browser (Export), exporting notes, study assistant (tiles, Try Again, Show Note, Copied), Settings (summary field, sections, Move Up/Down, keys saving as typed, `exportLayout` and `exportIncludesConversations` keys), the icon. "Current plan" already points here.

- [x] **Step 2: Run the spec's Milestone 6 verification** (copied under "Milestone 6 verification" below) in the built app, driving it through System Events and capturing `screencapture` images into the scratchpad; tick each line here and in the spec. Fill the verification table's After column from Task 2 if not already done.

- [x] **Step 3: Critique pass** (`/impeccable-swift critique` on the shelf, the page, the tiles, the export panel and the Settings › Prompts pane): no inline colors, no fixed-point fonts, every symbol button labelled, no stroke on a tile, the progress line unanimated, Dynamic Type at AX3 on the shelf and the tiles, Dark Mode screenshots of each. Fix what it finds. AX3 not run: `.dynamicTypeSize` has no effect on macOS 26.

- [ ] **Step 4: Whole-branch review** with the superpowers code-review flow, then the full suite and the app build one last time.

- [x] **Step 5: Commit** — `docs: README and DESIGN for milestone 6; verification recorded`.

---

## Milestone 6 verification

These steps are also in the spec's Verification section. Tick them in both places when run.

- [ ] **Performance (partial).** Open Psalm 119 in ESV at 18 pt with at least sixty highlights in the chapter (make them with the benchmark's spread if the store has fewer): the chapter appears within a second of choosing it; scrolling end to end with the trackpad drops no frames in Instruments' Animation Hitches template; applying a highlight and outlining one from the column each land within a frame; a live window resize keeps the reading verse. Record the before and after numbers in the table below.
  Result (Task 16, a copy of the store with 69 Psalm 119 ESV highlights): the chapter was on screen 0.9 s after Return in ⌘K. The first Animation Hitches trace of a synthetic fast scroll (60 px every 8 ms) found 34 hitches, about 125 ms each (3.5 s in all): every top-verse report rewrote `NavigationModel`'s observed history, so the window and the app's menus re-evaluated and re-laid out the 69-row notes column once per frame. Fixed in Task 16 (history and top verse unobserved, `canGoBack`/`canGoForward` stored); after it the same scroll had 11 hitches, ten of one 120 Hz frame (8.3 ms) and one of 20.8 ms, 112 ms in all, and main-thread time for the scroll fell from 2,055 ms to 864 ms (SwiftUI graph updates 1,325 ms to 77 ms). Outlining from the column and applying a new color both drew at once (the benchmark's decoration change is 1.3 ms). Partial: 11 one-frame hitches remain in an end-to-end scroll of Psalm 119; live resize not run (the tiling window manager reverts it).
- [x] **Typography.** What the bundled data can show: Matthew 5 WEB: the first paragraph has no indent, the Beatitudes hang as poetry with a half line of air after each verse (WEB marks stanzas), the paragraph after them (verse 11) has no indent, and later paragraphs do. Psalm 119 ESV: every poetry line hangs under its first word; ESV has no paragraph or stanza markers, so it shows hanging poetry only (no indents, no stanza air, and Matthew 5 ESV is one paragraph). Psalm 119 KJV: one paragraph per verse, each indented after the first. No small caps: they were dropped in Task 3 because the bundled text has "Lord" in title case in every translation, so there is no LORD/Lord distinction to show. Font size 14 and 24: indents and hang scale with the size.
  Result (Task 16): all as written, at 14, 18 and 24 pt; Psalm 119 ESV hangs, KJV indents each verse after the first, Matthew 5 WEB indents verses 13, 17 and 21 with verse 11 flush.
- [x] **Progress.** The line grows from nothing at the top of Matthew 5 to the full measure at its end; Psalm 117 in a tall window shows no line; Reduce Motion changes nothing. Previous and Next both work from the footer.
  Result (Task 16): no line at the top, part way at verse 11, the full measure at verse 48; none on Psalm 117; Next opened Matthew 6 and Previous Matthew 5. Reduce Motion was not toggled (a system setting); the line has no animation of its own and strips inherited ones (`.transaction { $0.animation = nil }`), so there is nothing for it to change.
- [x] **Shelf and search.** Home opens scrolled to the current book; a sidebar click scrolls the shelf; a hand scroll moves the sidebar selection and the shelf stays put; "rom 8" offers Go to Romans 8 and Return opens it; "zz" shows the empty state; chapters with marks show the dot; arrows move in the grid and Return opens.
  Result (Task 16): all pass (Psalms, Isaiah, Jeremiah, Romans 8, the dots on Psalm 119 and Matthew 5); Tab into Psalms now scrolls to the cursor cell (117) with its ring.
- [x] **Export.** ⇧⌘E exports one dated file with a title, books, chapters, citations, bodies and meta lines; the folder layout writes `README.md` and a file per book; the Notes window exports only what it shows; the conversations toggle removes the `####` sections; a bookmark in a chapter the current translation lacks reads "(text not available in …)".
  Result (Task 16): all pass; the Tobit 1:3 bookmark reads "(text not available in ESV)".
- [x] **Lightness band.** Adding a navy from the selection menu yields a pale blue mark with dark, readable text in light mode and a deep blue mark with light text in dark mode; setting a Settings well to black lands on the band's gray; `PaletteTests` holds any hue at 10:1 light and 6.5:1 dark.
  Result (Task 16): `#1F4C7A` was stored as `#BDDBFD` / `#1F4C7A`; black in a well became `#D8D8D8`; `PaletteTests` pass.
- [x] **Icon.** The Dock shows the open book with its marked line at every size; after Matt's Icon Composer step, the tinted and clear variants render.
  Result (Task 16): the Dock and the 16 px PNG show the book and its marked line. Tinted and clear: not run, they wait for Matt's Icon Composer step.
- [x] **Prompts.** The chapter tiles appear in three sections with a title and a sentence each, one column at the default inspector width, two from about 400 pt; a selection shows "About the passage"; a user prompt appears under "Your prompts"; Settings › Prompts shows the sections, the summary field, Move Up / Move Down, and Restore puts back the new title and summary.
  Result (Task 16): all pass; Move Up is disabled on a section's first row.
- [x] **Minors.** Try Again (⌘R) after an unreachable provider; Copied checkmark; Show Note after Add as Note; one drag selects across a reply's paragraphs; the History menu's native checkmark; the plus menu's copy; a key pasted then Settings closed at once is saved; a key replaced while the Keychain refuses the write keeps the old key; a custom endpoint's URL change leaves old replies labelled with their host; an LM Studio stream ending without `[DONE]` is complete; VoiceOver announces a finished reply.
  Result (Task 16, on-device model and a local fake server, no cloud provider): Try Again after `127.0.0.1:9` refused, with the panel hidden and Settings back on Automatic, showed the panel and the on-device model answered; Copied, Show Note, the drag (after a first click into the reply), the History checkmark, the plus menu, a pasted key saved at once, the host kept after the URL changed and the stream without `[DONE]` all pass. Not run: a refused Keychain write (needs a Keychain that refuses; `SecretStoreTests.savingANewKeyNeverLeavesTheOldOneGone` covers it) and the VoiceOver announcement (needs VoiceOver on, a system setting).

| Measurement (Psalm 119 KJV, 176 verses, 60 highlights, debug build) | Before (Task 1) | After (Task 2) |
| --- | --- | --- |
| `ReaderBenchmarkTests` load (median of 3) | 20.3 ms (19.4, 20.7, 20.3) | 14.7 ms (median of 7: 13.6, 14.7, 14.8, 14.7, 13.2, 14.5, 15.3); ceiling 100 ms |
| `ReaderBenchmarkTests` 100 scroll ticks (median of 3) | 10.1 ms (9.9, 10.4, 10.1) | 4.3 ms (median of 7: 4.2, 4.5, 4.3, 4.2, 4.2, 4.5, 4.5); ceiling 100 ms |
| `ReaderBenchmarkTests` decoration change (median of 3) | 7.8 ms (7.5, 7.8, 8.4) | 1.3 ms (median of 7: 1.3, 1.4, 1.3, 1.2, 1.2, 1.3, 1.3); ceiling 100 ms |
| Instruments Time Profiler: top `ChapterTextController` / `ChapterLayout` symbols while scrolling end to end twice and resizing once | `reportFirstVisibleVerse` 59 ms (via `clipBoundsDidChange`), `sizeToLayout` 18 ms, `update` 14 ms, `replaceText` 12 ms, `columnWidthDidChange` 8 ms; see notes | `reportFirstVisibleVerse` 40 ms (via `clipBoundsDidChange`; 29 ms of it is the model callback, the fragment walk fell from 29 ms to 4 ms), `sizeToLayout` 17 ms, `update` 15 ms, `replaceText` 13 ms, `columnWidthDidChange` 8 ms; see notes |
| App: time from choosing Psalm 119 on the shelf to the first frame of text (signpost `replaceText` + `sizeToLayout`) | `replaceText` 13.3 ms, of which `sizeToLayout` 10.8 ms and `ChapterLayout.build` 1.6 ms (opened at launch from the saved position, not from the shelf) | `replaceText` 12.4 ms, of which `sizeToLayout` 10.0 ms and `ChapterLayout.build` 1.7 ms (same method) |

Before notes (Task 1, 2026-11-01, M-series Mac, debug builds). The benchmark runs headless (no window, no drawing), so its numbers are layout and geometry only. The trace (`xctrace record --template 'Time Profiler' --instrument os_signpost --time-limit 32s --launch`, 32 s instead of 25 s to fit the drive) opened Psalm 119 KJV from a set reading position with no highlights in the store, scrolled it down, up, down, up with pixel scroll-wheel events and resized the window once. Top ten `ChapterTextController` / `ChapterLayout` symbols by inclusive weight (1 ms samples): the three `ChapterTextController.init` bounds-observer closures 59 ms each (the notification path into `clipBoundsDidChange`), `reportFirstVisibleVerse()` 59 ms, `clipBoundsDidChange()` 59 ms, `sizeToLayout()` 18 ms, `update(verses:typography:scrollTarget:decorations:)` 14 ms, `replaceText(verses:typography:decorations:)` 12 ms, `columnWidthDidChange()` 8 ms, closure in `reportFirstVisibleVerse()` (the fragment enumeration) 6 ms; no `ChapterLayout` symbol reached a sample outside `replaceText`. Signpost intervals: `reportFirstVisibleVerse` ×206, 85.4 ms total, median 0.41 ms, max 0.88 ms; `sizeToLayout` ×10, 18.1 ms total, max 10.8 ms; `columnWidthDidChange` ×4, 7.6 ms total, max 6.1 ms; `applyBackgrounds` ×9, 0.1 ms; `ChapterLayout.build` ×2, 1.6 ms each. The main thread's heaviest app-binary symbols outside the reader were `MainWindowView.body` 197 ms (of which `MainWindowView.typography` 84 ms, `ReaderTypography.scaled` 42 ms) and `ReaderView.body` 48 ms; the rest of the 8.5 s main-thread weight is AppKit, SwiftUI and TextKit drawing.

After notes (Task 2, 2026-11-01, same Mac and method; trace `psalm119-after.trace`). The benchmark medians are of seven runs, with the three reviewer minors folded in first (the load test's decorations are built outside the timed closure). Rerun in the same session, the Before code measured 20.8, 10.2 and 7.9 ms, so the machine was a little slower than in Task 1. Kept: the first visible verse walk starts at the fragment under the top edge (scroll 10.2 to 4.3 ms); every highlight's rects come from one fragment walk with no per-range `ensureLayout` once the view is sized, and overlaps are found by a sweep (load 19.0 to 13.3 ms, decoration change 7.3 to 1.2 ms at the time); `MainWindowView.body` builds `typography` once per evaluation instead of twice (`MainWindowView.typography` 84 to 62 ms). Dropped: deferring the reflow to the end of a live resize (`columnWidthDidChange` was 5 % of the resize's main-thread samples, under the 10 % bar) and reading the body font from the typography (no number moved, and it would change the rect height of a highlight starting on a verse number). Ceilings are max(100 ms, twice the median rounded up to 50 ms), so 100 ms each. Top `ChapterTextController` / `ChapterLayout` symbols by inclusive weight: the bounds-observer closures, `reportFirstVisibleVerse()` and `clipBoundsDidChange()` 40 ms each, `sizeToLayout()` 17 ms, `update(…)` 15 ms, `replaceText(…)` 13 ms, `columnWidthDidChange()` 8 ms, `ChapterLayout.build` 3 ms. Signpost intervals: `reportFirstVisibleVerse` ×213, 73.0 ms total, median 0.35 ms, max 0.56 ms; `sizeToLayout` ×9, 16.7 ms, max 10.0 ms; `columnWidthDidChange` ×4, 7.1 ms, max 5.8 ms; `applyBackgrounds` ×9, 0.3 ms; `ChapterLayout.build` ×2, 1.7 ms each. Outside the reader, `MainWindowView.body` 183 ms (`typography` 62 ms, half of it the two `@AppStorage` reads) and `ReaderView.body` 41 ms. The body most likely re-runs as scroll reports change model state it reads (not confirmed in the trace); narrowing that is a view split, not a small fix.

## Self-review notes

- Spec coverage (Milestone 6): performance pass with measured before and after (Tasks 1, 2, table); export notes as Markdown (Tasks 8, 9); new highlight colors held to the band in the Add Color sheet and the Settings wells, backed by `PaletteTests` (Task 5); the app icon filling the `AppIcon` slots (Task 15); "finished for daily use" minors (Tasks 10 to 14, Ruling 10). Matt's additions from the brainstorm: typography (Task 3), progress line and Previous (Task 4), home page shelf and search (Tasks 6, 7), prompt tiles and wording (Tasks 10, 11).
- Type consistency: `MarkLightness` (ScriptureModel) is used by `MarkupStore`, `MarkupContainer`, `ColorSettingsModel`, `AddColorSheet` and `PaletteTests`; `PromptSection` (ScriptureModel) by `PromptSeed`, `PromptTemplate`, `PromptTemplateItem`, `PromptTilesView` and Settings; `MarkdownExport.Options` by `ExportPanel`, `NotesExporter` and the app; `HTTPStreaming.Step` by both cloud providers; `ChatFinishReason` (ScriptureUI) maps the `ChatMessage.finishReason` strings written in `AssistantModel`; `ProviderLabel.text(providerID:modelName:host:)` is what `AssistantModel.label` and `MarkdownExport` call.
- Review Focus tests: 1 → Task 3, 2 → Task 3 (and Task 2's suites), 3 → Task 8, 4 → Task 6, 5 → Task 5.
- Open after this plan: the Icon Composer step (Task 15 Step 4) needs Matt at the GUI; the ceilings in `ReaderBenchmarkTests` are machine-relative and may need loosening on a slower Mac.
