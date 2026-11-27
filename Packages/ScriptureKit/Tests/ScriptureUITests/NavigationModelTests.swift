import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite final class NavigationModelTests {
    /// The scratch defaults suites this test made; each is removed before use and again when the
    /// test ends, so none is left in ~/Library/Preferences.
    private var defaultsNames: [String] = []

    deinit {
        for name in defaultsNames { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
    }

    private func makeDefaults() -> UserDefaults {
        let name = "NavigationModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaultsNames.append(name)
        return defaults
    }

    private func makeModel(defaults: UserDefaults? = nil) throws -> (NavigationModel, ReadingPositionStore) {
        let positionStore = ReadingPositionStore(defaults: defaults ?? makeDefaults())
        let model = try NavigationModel(store: try FixtureStore.make(), positionStore: positionStore, defaultTranslationID: "WEB")
        return (model, positionStore)
    }

    /// The reader reporting `verse` of the chapter in view at the top of the page.
    private func reportTopVerse(_ verse: Int, of model: NavigationModel) {
        guard let location = model.location else { Issue.record("no chapter in view"); return }
        model.reportReadingPosition(VerseLocation(book: location.book, chapter: location.chapter, verse: verse))
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

    /// The reader reports the top verse on almost every scroll frame; a view that reads the
    /// navigation state (the toolbar's Back and Forward, the Go menu) must not be invalidated by it.
    @Test func reportingTheTopVerseInvalidatesNoObservedState() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 1))
        model.open(ChapterLocation(book: "MAT", chapter: 2))
        final class Flag: @unchecked Sendable { var changed = false }
        let flag = Flag()
        withObservationTracking {
            _ = (model.canGoBack, model.canGoForward, model.screen, model.location, model.verses.count,
                 model.scrollTarget, model.previousChapter, model.nextChapter, model.chapterTitle)
        } onChange: {
            flag.changed = true
        }
        reportTopVerse(2, of: model)
        reportTopVerse(3, of: model)
        #expect(!flag.changed)
        #expect(model.canGoBack && !model.canGoForward)
        model.goBack()
        #expect(flag.changed && model.canGoForward)
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
        model.goForward()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2) && model.scrollTarget?.verse == 3)
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

    @Test func chapterTitleUsesSingularPsalm() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "PSA", chapter: 2))
        #expect(model.chapterTitle == "Psalm 2")
        #expect(model.title(for: ChapterLocation(book: "MAT", chapter: 1)) == "Matthew 1")
        #expect(model.books.first?.book.name == "Psalms")    // the front page keeps the book's plural name
    }

    @Test func homeKeepsPositionAndSelectsCurrentBook() throws {
        let (model, positionStore) = try makeModel()
        model.open(ChapterLocation(book: "PSA", chapter: 2))
        model.goHome()
        #expect(model.screen == .frontPage)
        #expect(model.selectedBookID == "PSA")
        #expect(positionStore.load()?.chapter == 2)
    }

    @Test func choosingTheCurrentChapterFromHomeStartsAtVerseOne() throws {
        let (model, positionStore) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 2))
        reportTopVerse(3, of: model)
        model.goHome()
        #expect(positionStore.load()?.firstVisibleVerse == 3)   // Home itself keeps the place
        model.open(ChapterLocation(book: "MAT", chapter: 2))   // a grid click is a fresh start
        #expect(model.screen == .reader)
        #expect(model.scrollTarget?.verse == 1)
        #expect(positionStore.load()?.firstVisibleVerse == 1)
    }

    @Test func submittingBeforeResultsRefreshUsesTheTypedQuery() throws {
        let (model, _) = try makeModel()
        model.isPaletteShown = true
        model.paletteQuery = "matt 1"
        model.updatePalette()
        model.paletteQuery = "matt 2:3"   // typed faster than the debounced refresh
        model.submitPalette(selectedIndex: 0)
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(model.scrollTarget?.verse == 3)
        #expect(!model.isPaletteShown)
    }

    @Test func submittingATranslationQuerySwitchesTranslation() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 1))
        model.isPaletteShown = true
        model.paletteQuery = "kj"
        model.updatePalette()
        model.paletteQuery = "kjv"
        model.submitPalette(selectedIndex: 0)
        #expect(model.translationID == "KJV")
        #expect(model.verses.first?.translationID == "KJV")
    }

    @Test func submittingWithFreshResultsHonoursTheSelectedRow() throws {
        let (model, _) = try makeModel()
        model.isPaletteShown = true
        model.paletteQuery = "verse"
        model.updatePalette()
        try #require(model.paletteItems.count >= 2)
        let second = model.paletteItems[1]
        model.submitPalette(selectedIndex: 1)
        if case .verse(let verse) = second {
            #expect(model.location == ChapterLocation(book: verse.id.book, chapter: verse.id.chapter))
            #expect(model.scrollTarget?.verse == verse.id.verse)
        } else {
            Issue.record("expected a verse row, got \(second)")
        }
    }

    @Test func resumeReadingTargetsLastVisibleVerse() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 2))
        let opened = model.scrollTarget
        reportTopVerse(3, of: model)
        model.resumeReading()   // a recreated reader view must not replay the stale verse-1 target
        #expect(model.scrollTarget?.verse == 3)
        #expect(model.scrollTarget != opened)
    }

    @Test func switchingTranslationOnFrontPageStaysThere() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 2))
        model.goHome()
        model.setTranslation("KJV")
        #expect(model.screen == .frontPage)
        #expect(model.translationID == "KJV")
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(model.verses.first?.translationID == "KJV")
    }

    @Test func switchingToTranslationWithoutBookSelectsFirstBook() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "TOB", chapter: 1))
        model.setTranslation("KJV")
        #expect(model.selectedBookID == "PSA")
    }

    @Test func translationChoicePersistsWithoutAChapter() throws {
        let defaults = makeDefaults()
        let (first, _) = try makeModel(defaults: defaults)
        first.setTranslation("KJV")
        let (relaunched, _) = try makeModel(defaults: defaults)
        #expect(relaunched.screen == .frontPage)
        #expect(relaunched.translationID == "KJV")
    }

    @Test func switchingAwayFromAbsentBookKeepsTranslationOnRelaunch() throws {
        let defaults = makeDefaults()
        let (first, _) = try makeModel(defaults: defaults)
        first.open(ChapterLocation(book: "TOB", chapter: 1))
        first.setTranslation("KJV")
        let (relaunched, _) = try makeModel(defaults: defaults)
        #expect(relaunched.screen == .frontPage)
        #expect(relaunched.translationID == "KJV")
    }

    @Test func backSkipsChaptersAbsentInCurrentTranslation() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "PSA", chapter: 1))
        model.open(ChapterLocation(book: "TOB", chapter: 1))
        model.open(ChapterLocation(book: "MAT", chapter: 1))
        model.setTranslation("KJV")   // Tobit is not in KJV
        model.goBack()
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 1))
        #expect(model.verses.first?.translationID == "KJV")
    }

    @Test func backReturnsToTheVerseReadThere() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 1))
        reportTopVerse(3, of: model)
        model.open(ChapterLocation(book: "PSA", chapter: 1))
        model.goBack()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
        #expect(model.scrollTarget?.verse == 3)
        model.goForward()
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 1))
        #expect(model.scrollTarget?.verse == 1)
    }

    @Test func openingCombinedVerseTargetsItsSpanStart() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 3), verse: 5)   // chapter 3 combines verses 4-5
        #expect(model.scrollTarget?.verse == 4)
        #expect(model.verses.last?.endVerse == 5)
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

    /// The book thumb covers the chapters the translation has of the open book, with the open
    /// chapter lit: KJV's Psalms in the fixtures are 1, 2, 118 and 119; a one-chapter book has
    /// no thumb; another translation's chapters follow the switch.
    @Test func theBookThumbHasTheTranslationsChaptersOfTheOpenBook() throws {
        let (model, _) = try makeModel()
        #expect(model.bookThumb == nil)
        model.setTranslation("KJV")
        model.open(ChapterLocation(book: "PSA", chapter: 2))
        #expect(model.bookThumb == BookThumb(chapters: [1, 2, 118, 119], current: 2))
        model.setTranslation("WEB")
        #expect(model.bookThumb == BookThumb(chapters: [1, 2], current: 2))
        model.open(ChapterLocation(book: "TOB", chapter: 1))
        #expect(model.bookThumb?.isShown == false)
    }

    /// Letting go on another chapter opens it as choosing a chapter does: at its start, through
    /// the history, so Back returns to the chapter the drag began on.
    @Test func aThumbLandingOpensTheChapterThroughTheHistory() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 2))
        reportTopVerse(3, of: model)
        let thumb = try #require(model.bookThumb)
        let landing = try #require(thumb.landing(on: 5))
        model.open(ChapterLocation(book: "MAT", chapter: landing.chapter), verse: landing.verse)
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 5))
        #expect(model.scrollTarget?.verse == 1)
        model.goBack()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(model.scrollTarget?.verse == 3)
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
        reportTopVerse(2, of: model)
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
        reportTopVerse(3, of: model)
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

    @Test func openWithTranslationSwitchesThenOpens() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "PSA", chapter: 2))
        model.open(ChapterLocation(book: "MAT", chapter: 1), verse: 2, translationID: "KJV")
        #expect(model.translationID == "KJV")
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
        #expect(model.scrollTarget?.verse == 2)
        #expect(model.canGoBack)
        model.open(ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: "NIV")
        #expect(model.translationID == "KJV" && model.location == ChapterLocation(book: "MAT", chapter: 2))
    }

    @Test func selectingACommandPerformsIt() throws {
        let (model, _) = try makeModel()
        var performed: PaletteCommand?
        model.performCommand = { performed = $0 }
        model.isPaletteShown = true
        model.select(.command(.settings))
        #expect(performed == .settings && !model.isPaletteShown)
    }

    private func markEntry() -> NotesBrowserEntry {
        NotesBrowserEntry(
            id: UUID(), kind: .note(noteID: UUID(), highlightID: nil), book: "MAT", bookOrder: 40, chapter: 2, verse: 2, endVerse: 2,
            referenceString: "Matthew 2:2", translationID: "KJV", color: nil, quotedText: "", body: "x marks the spot", modifiedAt: Date())
    }

    @Test func paletteIncludesMarksFromTheProvider() throws {
        let (model, _) = try makeModel()
        let entry = markEntry()
        var calls = 0
        model.markSearch = { calls += 1; return [entry] }
        model.paletteQuery = " marks "
        model.updatePalette()
        #expect(model.paletteItems.contains(.mark(SearchMarkHit(entry: entry))))
        #expect(model.paletteResults.groups.contains { $0.kind == .notes })
        #expect(calls == 1)
        model.paletteQuery = "   "
        model.updatePalette()
        #expect(model.paletteResults.groups.map(\.kind) == [.commands])
    }

    @Test func paletteItemsAreTheGroupedResultsInOrder() throws {
        let (model, _) = try makeModel()
        model.markSearch = { [self.markEntry()] }
        model.paletteQuery = "line"
        model.updatePalette()
        #expect(!model.paletteItems.isEmpty)
        #expect(model.paletteItems == model.paletteResults.flatItems)
        let scripture = try #require(model.paletteResults.groups.last)
        #expect(scripture.kind == .scripture && scripture.title == "Scripture · WEB")
        #expect(scripture.items.count <= model.searchLimits.verses)
        model.paletteQuery = "matt 2"
        model.updatePalette()
        #expect(model.paletteItems == model.paletteResults.flatItems)
        #expect(model.paletteResults.groups.map(\.kind).prefix(2) == [.goTo, .marksInPassage])
    }

    @Test func searchLimitsAndCommandsAreTheModelsToSet() throws {
        let (model, _) = try makeModel()
        #expect(model.searchLimits == .palette && model.includesCommandsInSearch)
        model.paletteQuery = "keyboard"
        model.updatePalette()
        #expect(model.paletteResults.groups.contains { $0.kind == .commands })
        model.includesCommandsInSearch = false
        model.updatePalette()
        #expect(!model.paletteResults.groups.contains { $0.kind == .commands })
    }

    @Test func selectingAMarkShowsItsTargetAndClosesThePalette() throws {
        let (model, _) = try makeModel()
        var shown: MarkupTarget?
        model.showTarget = { shown = $0 }
        let hit = SearchMarkHit(entry: markEntry())
        model.isPaletteShown = true
        model.paletteQuery = "marks"
        model.updatePalette()
        model.select(.mark(hit))
        #expect(shown == hit.target)
        #expect(!model.isPaletteShown && model.paletteQuery.isEmpty && model.paletteItems.isEmpty)
        #expect(model.paletteResults == .empty)
    }

    /// The Mac's palette closes on a choice and starts empty next time; the phone's search tab keeps
    /// the query and its results for when he comes back to it.
    @Test func theCallerDecidesWhetherAChoiceKeepsTheQuery() throws {
        let (mac, _) = try makeModel()
        mac.isPaletteShown = true
        mac.paletteQuery = "Line b"
        mac.updatePalette()
        let macRow = try #require(mac.paletteItems.first { if case .verse = $0 { true } else { false } })
        mac.select(macRow)
        #expect(mac.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(!mac.isPaletteShown && mac.paletteQuery.isEmpty && mac.paletteItems.isEmpty && mac.paletteResults == .empty)

        let (phone, _) = try makeModel()
        phone.searchLimits = .phone
        phone.paletteQuery = "Line b"
        phone.updatePalette()
        let results = phone.paletteResults
        let items = phone.paletteItems
        let phoneRow = try #require(items.first { if case .verse = $0 { true } else { false } })
        phone.select(phoneRow, keepingQuery: true)
        #expect(phone.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(phone.paletteQuery == "Line b" && phone.paletteResults == results && phone.paletteItems == items)
        #expect(!phone.isPaletteShown)
    }

    @Test func selectingAMarkWithoutAHandlerLooksUpItsChapter() throws {
        let (model, _) = try makeModel()
        model.select(.mark(SearchMarkHit(entry: markEntry())))
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2) && model.translationID == "KJV" && model.scrollTarget?.verse == 2)
    }

    /// The arrow keys move over the grouped rows as one list: ↓ from a group's last row lands on
    /// the next group's first row (a header is not a row), ↑ comes back, and the ends hold.
    @Test func arrowKeySelectionCrossesAGroupBoundary() throws {
        let (model, _) = try makeModel()
        let entry = markEntry()
        var shown: MarkupTarget?
        model.showTarget = { shown = $0 }
        model.markSearch = { [entry] }
        model.isPaletteShown = true
        model.paletteQuery = "matt 2"
        model.updatePalette()
        let results = model.paletteResults
        try #require(results.groups.count >= 2)
        #expect(results.groups.map(\.kind).prefix(2) == [.goTo, .marksInPassage])
        let lastOfFirst = results.groups[0].items.count - 1
        let crossed = CommandPaletteView.selection(after: lastOfFirst, moving: 1, in: results)
        #expect(crossed == lastOfFirst + 1)
        #expect(results.flatItems[crossed] == results.groups[1].items.first)
        #expect(CommandPaletteView.selection(after: crossed, moving: -1, in: results) == lastOfFirst)
        #expect(CommandPaletteView.selection(after: 0, moving: -1, in: results) == 0)
        let last = results.flatItems.count - 1
        #expect(CommandPaletteView.selection(after: last, moving: 1, in: results) == last)
        #expect(CommandPaletteView.selection(after: 0, moving: 1, in: .empty) == 0)
        // Return on the crossed row takes that row: the mark, not the Go to row above it.
        model.submitPalette(selectedIndex: crossed)
        #expect(shown == SearchMarkHit(entry: entry).target)
        #expect(!model.isPaletteShown)
    }

    /// Return before the debounced refresh: the typed query is ranked again and the first row of
    /// its first group is taken, whatever row was highlighted in the old results.
    @Test func returnOnAStaleQueryTakesTheFirstRowOfTheFirstGroup() throws {
        let (model, _) = try makeModel()
        var shown: MarkupTarget?
        model.showTarget = { shown = $0 }
        model.markSearch = { [self.markEntry()] }
        model.isPaletteShown = true
        model.paletteQuery = "verse"
        model.updatePalette()
        try #require(model.paletteItems.count >= 2)
        model.paletteQuery = "matt 2"   // typed past the refresh; its second row would be the mark
        model.submitPalette(selectedIndex: 1)
        #expect(shown == nil)
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2) && model.scrollTarget?.verse == 1)
        #expect(!model.isPaletteShown && model.paletteItems.isEmpty)
    }

    // MARK: - Scripture's scope, order, chips and suggestion (finding 4.2 to 4.5, 5.4)

    private func search(_ model: NavigationModel, _ typed: String) {
        model.paletteQuery = typed
        model.updatePalette()
    }

    private func scripture(_ model: NavigationModel) -> SearchGroup? {
        model.paletteResults.groups.first { $0.kind == .scripture }
    }

    private func verses(_ model: NavigationModel) -> [Verse] {
        (scripture(model)?.items ?? []).compactMap { if case .verse(let verse) = $0 { verse } else { nil } }
    }

    /// Holds a search open: `wait()` suspends until `open()`; `entered()` returns once `wait()` was called.
    private actor Gate {
        private var isOpen = false
        private var hasEntered = false
        private var waiting: [CheckedContinuation<Void, Never>] = []
        private var entering: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            hasEntered = true
            entering.forEach { $0.resume() }
            entering = []
            guard !isOpen else { return }
            await withCheckedContinuation { waiting.append($0) }
        }

        func entered() async {
            guard !hasEntered else { return }
            await withCheckedContinuation { entering.append($0) }
        }

        func open() {
            isOpen = true
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

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

    /// The arrows and Return move over what is shown the moment a chip changes, before the keyed
    /// refresh ranks the query again with the chip's limits.
    @Test func theRowsMovedOverAreTheShownOnesTheMomentAChipChanges() throws {
        let (model, _) = try makeModel()
        model.includesCommandsInSearch = false
        search(model, "psalm")
        #expect(model.paletteResults.chips() == [.scripture, .passages])
        model.paletteChip = .passages
        #expect(model.paletteItems == [.book(BookCatalog.book(code: "PSA")!)])
        model.paletteChip = .scripture
        #expect(model.paletteItems == model.paletteResults.showing(.scripture).flatItems && !model.paletteItems.isEmpty)
        model.paletteChip = nil
        #expect(model.paletteItems == model.paletteResults.flatItems)
    }

    /// A command typed by name, a word the fixture's WEB lacks but has a near spelling for ("page",
    /// near "are"): the command leads, the suggestion comes last, and Return runs the command.
    @Test func aCommandTypedByNameRunsOnReturnThoughANearSpellingIsOffered() throws {
        let (model, _) = try makeModel()
        model.open(ChapterLocation(book: "MAT", chapter: 1))
        var ran: [PaletteCommand] = []
        model.performCommand = { ran.append($0) }
        model.isPaletteShown = true
        search(model, "page")
        #expect(model.paletteItems.first == .command(.pageStyle(.printed)))
        guard case .suggestion? = model.paletteItems.last else { Issue.record("expected the suggestion last"); return }
        #expect(model.paletteResults.groups.last?.kind == .suggestion && !model.paletteResults.chips().contains(.scripture))
        model.submitPalette(selectedIndex: 0)
        #expect(ran == [.pageStyle(.printed)] && !model.isPaletteShown)
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
        let gate = Gate()
        let real = model.scriptureSearch
        model.scriptureSearch = { request in
            if request.query.text == "tobit" { await gate.wait() }
            return await real(request)
        }
        model.paletteQuery = "tobit"
        let older = Task { await model.refreshPalette() }
        await gate.entered()
        model.paletteQuery = "psalm"
        let newerApplied = await model.refreshPalette()
        #expect(newerApplied)
        let settled = model.paletteResults
        await gate.open()
        let olderApplied = await older.value
        #expect(!olderApplied)                                                      // dropped, and says so
        #expect(model.paletteResults == settled && verses(model).allSatisfy { $0.id.book == "PSA" })
        model.updatePalette()
        #expect(model.paletteResults == settled)                                    // what the main actor gives
    }

    // MARK: - A position arriving from another device

    /// Launches at Matthew 1 (restored, not a move) and then has another device write Psalm 2:2.
    private func launchAtMatthewOne() throws -> (NavigationModel, ReadingPositionStore) {
        let defaults = makeDefaults()
        ReadingPositionStore(defaults: defaults).save(ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 1, translationID: "WEB"))
        return try makeModel(defaults: defaults)
    }

    private let arriving = ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 2, translationID: "WEB")

    @Test func aStoredPositionArrivingBeforeTheReaderMovesIsAdopted() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        reportTopVerse(2, of: model)   // the reader's first report in a chapter is not a move
        #expect(!model.hasMovedThisSession)
        positionStore.save(arriving)
        model.adoptStoredPosition()
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 2))
        #expect(model.scrollTarget?.verse == 2)
        #expect(!model.hasMovedThisSession)
    }

    @Test func aStoredPositionArrivingWhileReadingIsIgnored() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        model.goToNextChapter()
        #expect(model.hasMovedThisSession)
        positionStore.save(arriving)
        model.adoptStoredPosition()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2))
    }

    @Test func scrollingAfterTheFirstReportIsAMove() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        reportTopVerse(1, of: model)
        reportTopVerse(3, of: model)
        #expect(model.hasMovedThisSession)
        positionStore.save(arriving)
        model.adoptStoredPosition()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
    }

    @Test func aStoredPositionArrivingWhileInactiveIsAdopted() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        model.goToNextChapter()
        model.isAppActive = false
        positionStore.save(arriving)
        model.adoptStoredPosition()
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 2))
        #expect(model.scrollTarget?.verse == 2)
    }

    @Test func adoptingKeepsBackWorking() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        positionStore.save(arriving)
        model.adoptStoredPosition()
        #expect(model.canGoBack)
        model.goBack()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
    }

    @Test func aStoredPositionBringsItsTranslation() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        #expect(model.translationID == "WEB")
        positionStore.save(ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 2, translationID: "KJV"))
        model.adoptStoredPosition()
        #expect(model.translationID == "KJV")
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 2))
        #expect(model.verses.first?.translationID == "KJV")
        #expect(model.scrollTarget?.verse == 2)
        #expect(!model.hasMovedThisSession)
    }

    @Test func aStoredPositionInATranslationThatIsNotBundledIsIgnored() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        positionStore.save(ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 1, translationID: "NIV"))
        model.adoptStoredPosition()
        #expect(model.translationID == "WEB")
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
    }

    @Test func aStoredChapterItsTranslationLacksIsIgnored() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        positionStore.save(ReadingPosition(book: "TOB", chapter: 1, firstVisibleVerse: 1, translationID: "KJV"))   // no Tobit in KJV
        model.adoptStoredPosition()
        #expect(model.translationID == "WEB")
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
        #expect(model.books.map(\.book.id) == ["PSA", "MAT", "TOB"])   // the translation's books are put back
        positionStore.save(ReadingPosition(book: "MAT", chapter: 99, firstVisibleVerse: 1, translationID: "WEB"))
        model.adoptStoredPosition()
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 1))
    }

    @Test func adoptingDoesNotResaveADifferentPosition() throws {
        let defaults = makeDefaults()
        ReadingPositionStore(defaults: defaults).save(ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 1, translationID: "WEB"))
        let (model, positionStore) = try makeModel(defaults: defaults)
        positionStore.save(ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 2, translationID: "KJV"))
        let stored = defaults.data(forKey: "readingPosition")
        model.adoptStoredPosition()
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 2))
        #expect(defaults.data(forKey: "readingPosition") == stored)
    }

    // MARK: - Looking something up does not move the place

    private let matthewOne = ChapterLocation(book: "MAT", chapter: 1)
    private let psalmTwo = ChapterLocation(book: "PSA", chapter: 2)

    /// Reading Matthew 1 at verse 3 in WEB, the stored place.
    private func readingMatthewOne(defaults: UserDefaults? = nil) throws -> (NavigationModel, ReadingPositionStore) {
        let (model, positionStore) = try makeModel(defaults: defaults)
        model.open(matthewOne)
        reportTopVerse(3, of: model)
        return (model, positionStore)
    }

    private let readingPlace = ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 3, translationID: "WEB")

    @Test func aLookupShowsThePassageButKeepsTheStoredPlace() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2)
        #expect(model.location == psalmTwo && model.screen == .reader && model.scrollTarget?.verse == 2)
        #expect(positionStore.load() == readingPlace)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(model.lookupReturnTitle == "Matthew 1")
        #expect(model.canGoBack)
    }

    @Test func aTurnPushesHistory() throws {
        let (model, _) = try readingMatthewOne()
        model.turn(to: psalmTwo, atEnd: true)
        #expect(model.location == psalmTwo)
        #expect(model.scrollTarget?.atEnd == true && model.scrollTarget?.chapter == 2)
        model.goBack()
        #expect(model.location == matthewOne)
        model.turn(to: psalmTwo, atEnd: false)
        #expect(model.scrollTarget?.atEnd == false && model.scrollTarget?.verse == 1)
    }

    @Test func aTurnDuringALookupEndsItAndPushesHistory() throws {
        let (model, _) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2)
        #expect(model.lookupReturn != nil)
        let matthewTwo = ChapterLocation(book: "MAT", chapter: 2)
        model.turn(to: matthewTwo, atEnd: false)
        #expect(model.lookupReturn == nil)
        #expect(model.location == matthewTwo)
        model.goBack()
        #expect(model.location == psalmTwo)
    }

    @Test func targetsDifferingOnlyInAtEndAreNotEqual() {
        let a = ScrollTarget(chapter: 2, verse: 1)
        #expect(a != ScrollTarget(chapter: 2, verse: 1, atEnd: true))
        #expect(ScrollTarget(chapter: 2, verse: 1, atEnd: true).atEnd)
    }

    @Test func scrollingALookupDoesNotSave() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 1)
        reportTopVerse(1, of: model)
        reportTopVerse(2, of: model)
        #expect(positionStore.load() == readingPlace)
        model.goBack()
        model.goForward()   // the history still remembers the verse read in the lookup
        #expect(model.location == psalmTwo && model.scrollTarget?.verse == 2)
    }

    @Test func returningRestoresChapterVerseAndTranslation() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
        #expect(model.translationID == "KJV" && model.verses.first?.translationID == "KJV")
        reportTopVerse(1, of: model)
        model.returnFromLookup()
        #expect(model.lookupReturn == nil && model.lookupReturnTitle == nil)
        #expect(model.location == matthewOne && model.scrollTarget?.verse == 3)
        #expect(model.translationID == "WEB" && model.verses.first?.translationID == "WEB")
        #expect(positionStore.load() == readingPlace)
        #expect(positionStore.loadTranslationID() != "KJV")   // the lookup's translation was not chosen
    }

    /// Spec 10: the lookup from a row keeps the reader's place.
    @Test func aRowsLookupKeepsThePlaceAndBackReturnsToIt() throws {
        let matthewFive = ChapterLocation(book: "MAT", chapter: 5)
        let (model, positionStore) = try makeModel()
        model.open(matthewFive)
        reportTopVerse(1, of: model)
        let stored = positionStore.load()
        model.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 2)                       // Open on a passage
        #expect(model.location?.chapter == 6 && model.lookupReturn?.location == matthewFive)
        model.lookUp(matthewFive, verse: 3, translationID: "KJV")                              // a compare row
        #expect(model.translationID == "KJV" && model.lookupReturn?.translationID == "WEB" && positionStore.load() == stored)
        model.returnFromLookup()
        #expect(model.location == matthewFive && model.translationID == "WEB" && model.lookupReturn == nil && positionStore.load() == stored)
    }

    @Test func aSecondLookupKeepsTheFirstReturnPlace() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2)
        model.lookUp(ChapterLocation(book: "MAT", chapter: 3), verse: 4, translationID: "KJV")
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(positionStore.load() == readingPlace)
        model.returnFromLookup()
        #expect(model.location == matthewOne && model.translationID == "WEB" && model.scrollTarget?.verse == 3)
    }

    @Test func keepingALookupMakesItThePlace() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
        model.keepLookup()
        #expect(model.lookupReturn == nil)
        #expect(model.location == psalmTwo)
        #expect(positionStore.load() == ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 2, translationID: "KJV"))
        #expect(positionStore.loadTranslationID() == "KJV")
        reportTopVerse(1, of: model)
        #expect(positionStore.load()?.firstVisibleVerse == 1)   // scrolling saves again
    }

    @Test func theNextChapterLinkKeepsTheLookup() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(ChapterLocation(book: "PSA", chapter: 1), verse: 2)
        model.goToNextChapter()
        #expect(model.lookupReturn == nil && model.location == psalmTwo)
        #expect(positionStore.load() == ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 1, translationID: "WEB"))
        model.lookUp(ChapterLocation(book: "MAT", chapter: 3), verse: 1)
        model.goToPreviousChapter()
        #expect(model.lookupReturn == nil)
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 2, firstVisibleVerse: 1, translationID: "WEB"))
        model.lookUp(matthewOne, verse: 2)
        model.open(ChapterLocation(book: "MAT", chapter: 3))   // a chapter chosen in the Library
        #expect(model.lookupReturn == nil)
        #expect(positionStore.load()?.chapterLocation == ChapterLocation(book: "MAT", chapter: 3))
    }

    @Test func goingBackToTheReturnChapterEndsTheLookup() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
        model.lookUp(ChapterLocation(book: "PSA", chapter: 1), verse: 1)
        model.goBack()
        #expect(model.location == psalmTwo && model.lookupReturn != nil)   // still looking
        model.goBack()
        #expect(model.lookupReturn == nil)
        #expect(model.location == matthewOne && model.translationID == "WEB" && model.scrollTarget?.verse == 3)
        #expect(positionStore.load() == readingPlace)
        model.goForward()   // forward out of the reading place is browsing the history, as today
        #expect(model.location == psalmTwo && model.lookupReturn == nil)
    }

    @Test func homeDuringALookupReturnsFirst() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
        model.goHome()
        #expect(model.screen == .frontPage && model.lookupReturn == nil)
        #expect(model.location == matthewOne && model.translationID == "WEB" && model.selectedBookID == "MAT")
        #expect(positionStore.load() == readingPlace)
    }

    @Test func aLookupFromTheFrontPageIsAnOpen() throws {
        let (model, positionStore) = try makeModel()
        #expect(model.location == nil)
        model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
        #expect(model.lookupReturn == nil)
        #expect(model.location == psalmTwo && model.translationID == "KJV")
        #expect(positionStore.load() == ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 2, translationID: "KJV"))
    }

    /// Task 19 (C2) replaces the earlier ruling that this was an `open`: a jump inside the chapter
    /// being read keeps the place, with a way back, until the reader reads on from it.
    @Test func aLookupInTheChapterBeingReadIsALookup() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 2)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(model.scrollTarget?.verse == 2 && positionStore.load() == readingPlace)
        model.lookUp(matthewOne, verse: 1, translationID: "WEB")   // a second jump keeps the first return place
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(model.scrollTarget?.verse == 1 && positionStore.load() == readingPlace)
        model.returnFromLookup()
        model.lookUp(matthewOne, verse: 1, translationID: "KJV")   // another translation is a lookup too
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        model.returnFromLookup()
        model.lookUp(psalmTwo, verse: 1)
        model.lookUp(psalmTwo, verse: 2)   // a lookup already showing is unchanged
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(positionStore.load() == readingPlace)
    }

    /// A note made in another translation in the chapter being read is a lookup; with no history
    /// entry of its own, Back returns from it to the place's verse and translation.
    @Test func backReturnsFromALookupInTheChapterBeingRead() throws {
        let (model, positionStore) = try readingMatthewOne()
        #expect(!model.canGoBack)   // nothing earlier in the history
        model.lookUp(matthewOne, verse: 1, translationID: "KJV")
        #expect(model.lookupReturn != nil && model.translationID == "KJV")
        #expect(model.canGoBack)
        reportTopVerse(1, of: model)
        reportTopVerse(2, of: model)   // scrolling the lookup rewrites the history's verse
        model.goBack()
        #expect(model.lookupReturn == nil)
        #expect(model.location == matthewOne && model.translationID == "WEB" && model.verses.first?.translationID == "WEB")
        #expect(model.scrollTarget?.verse == 3)
        #expect(positionStore.load() == readingPlace)
        #expect(!model.canGoBack)
        reportTopVerse(3, of: model)
        model.goForward()   // nothing to go forward to: the lookup was not a history entry
        #expect(model.location == matthewOne && model.translationID == "WEB")
    }

    /// A same-chapter lookup naming a translation it cannot show in shows in the one being read,
    /// and is a lookup like any other jump inside the chapter (Task 19, C2).
    @Test func aLookupInTheChapterBeingReadInAnUnavailableTranslationShowsInTheOneBeingRead() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 2, translationID: "NIV")   // not bundled
        #expect(model.translationID == "WEB" && model.scrollTarget?.verse == 2)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(positionStore.load() == readingPlace)
        let tobit = ChapterLocation(book: "TOB", chapter: 1)
        model.open(tobit)
        model.lookUp(tobit, verse: 2, translationID: "KJV")   // KJV lacks Tobit
        #expect(model.translationID == "WEB" && model.location == tobit)
        #expect(model.lookupReturn == ReadingPlace(location: tobit, verse: 1, translationID: "WEB"))
    }

    // MARK: - A jump inside the chapter being read keeps the place until the reader reads on

    @Test func aJumpInsideTheChapterKeepsTheStoredVerseAndShowsTheWayBack() throws {
        let (model, positionStore) = try readingMatthewOne()
        #expect(!model.canGoBack)
        model.lookUp(matthewOne, verse: 2)
        #expect(model.location == matthewOne && model.scrollTarget?.verse == 2)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(model.lookupReturnTitle == "Matthew 1")
        #expect(model.canGoBack)
        #expect(positionStore.load() == readingPlace)
    }

    @Test func scrollingUnderFiveLinesFromTheJumpChangesNothing() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 2)
        reportTopVerse(2, of: model)
        model.reportLinesScrolledSinceJump(4, from: model.scrollTarget!)
        reportTopVerse(1, of: model)
        model.reportLinesScrolledSinceJump(-4.9, from: model.scrollTarget!)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(model.canGoBack)
        #expect(positionStore.load() == readingPlace)
    }

    @Test(arguments: [NavigationModel.linesThatKeepAJump, -NavigationModel.linesThatKeepAJump, 40])
    func scrollingFiveLinesFromTheJumpMakesItThePlace(lines: Double) throws {
        #expect(NavigationModel.linesThatKeepAJump == 5)
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 2)
        reportTopVerse(1, of: model)
        model.reportLinesScrolledSinceJump(lines, from: model.scrollTarget!)
        #expect(model.lookupReturn == nil && !model.canGoBack)
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 1, translationID: "WEB"))
        reportTopVerse(2, of: model)   // and scrolling saves again
        #expect(positionStore.load()?.firstVisibleVerse == 2)
    }

    /// Only the chapter-end links, Read From Here, `open` and the rest of Task 7's rules end a
    /// lookup into another chapter, or into this chapter in another translation.
    @Test func noScrollKeepsALookupIntoAnotherChapter() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2)
        reportTopVerse(1, of: model)
        model.reportLinesScrolledSinceJump(5, from: model.scrollTarget!)
        model.reportLinesScrolledSinceJump(-500, from: model.scrollTarget!)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(positionStore.load() == readingPlace)
        model.returnFromLookup()
        model.lookUp(matthewOne, verse: 1, translationID: "KJV")
        model.reportLinesScrolledSinceJump(500, from: model.scrollTarget!)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(model.translationID == "KJV" && positionStore.load() == readingPlace)
    }

    @Test func returningFromAJumpInsideTheChapterRestoresTheVerse() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 1)
        reportTopVerse(1, of: model)
        model.reportLinesScrolledSinceJump(2, from: model.scrollTarget!)
        model.returnFromLookup()
        #expect(model.lookupReturn == nil && model.location == matthewOne && model.scrollTarget?.verse == 3)
        #expect(positionStore.load() == readingPlace)
        model.lookUp(matthewOne, verse: 2)
        model.goBack()   // Back, the Mac's way back, does the same
        #expect(model.lookupReturn == nil && model.location == matthewOne && model.scrollTarget?.verse == 3)
        #expect(positionStore.load() == readingPlace && !model.canGoBack)
    }

    /// Fix round 1: a report measured from the reader's previous landing (the chapter's open, read
    /// well past five lines) arriving after the jump does not end it; one from the jump does.
    @Test func aDistanceMeasuredFromAnEarlierLandingDoesNotKeepAJump() throws {
        let (model, positionStore) = try makeModel()
        model.open(matthewOne)
        let opened = try #require(model.scrollTarget)
        reportTopVerse(3, of: model)   // read on well into the chapter
        model.lookUp(matthewOne, verse: 1)
        let jump = try #require(model.scrollTarget)
        #expect(jump != opened)
        model.reportLinesScrolledSinceJump(-12, from: opened)   // still measured from the open
        model.reportLinesScrolledSinceJump(40, from: opened)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(positionStore.load() == readingPlace)
        model.reportLinesScrolledSinceJump(5, from: jump)
        #expect(model.lookupReturn == nil)
    }

    /// Task 7's Review Focus 2 for a jump inside the chapter: the other device writing a position
    /// mid-jump does not move the place or end the jump.
    @Test func anotherDevicesPositionIsIgnoredDuringAJumpInsideTheChapter() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 2)
        model.reportLinesScrolledSinceJump(2, from: model.scrollTarget!)
        model.isAppActive = false
        positionStore.save(ReadingPosition(book: "MAT", chapter: 3, firstVisibleVerse: 3, translationID: "KJV"))
        model.adoptStoredPosition()
        #expect(model.location == matthewOne && model.translationID == "WEB" && model.scrollTarget?.verse == 2)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
    }

    @Test func aRelaunchAfterAJumpInsideTheChapterScrolledUnderFiveLinesOpensAtThePlace() throws {
        let defaults = makeDefaults()
        let (model, _) = try readingMatthewOne(defaults: defaults)
        model.lookUp(matthewOne, verse: 1)
        reportTopVerse(1, of: model)
        model.reportLinesScrolledSinceJump(2, from: model.scrollTarget!)
        let (relaunched, _) = try makeModel(defaults: defaults)
        #expect(relaunched.location == matthewOne && relaunched.translationID == "WEB")
        #expect(relaunched.scrollTarget?.verse == 3)
        #expect(relaunched.lookupReturn == nil)
    }

    /// Review Focus 2: quitting mid-lookup reopens at the place being read, not the lookup.
    @Test func aRelaunchAfterALookupOpensTheReadingPlace() throws {
        let defaults = makeDefaults()
        let (model, _) = try readingMatthewOne(defaults: defaults)
        model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
        reportTopVerse(1, of: model)
        let (relaunched, _) = try makeModel(defaults: defaults)
        #expect(relaunched.location == matthewOne)
        #expect(relaunched.translationID == "WEB")
        #expect(relaunched.scrollTarget?.verse == 3)
        #expect(relaunched.lookupReturn == nil)
    }

    /// Review Focus 2: the other device writing a position mid-lookup does not move the place.
    /// The app is in the background here, when a position from another device is otherwise
    /// always taken.
    @Test func anotherDevicesPositionIsIgnoredDuringALookup() throws {
        let (model, positionStore) = try launchAtMatthewOne()
        model.lookUp(psalmTwo, verse: 2)
        model.isAppActive = false
        positionStore.save(ReadingPosition(book: "MAT", chapter: 3, firstVisibleVerse: 3, translationID: "KJV"))
        model.adoptStoredPosition()
        #expect(model.location == psalmTwo && model.translationID == "WEB")
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 1, translationID: "WEB"))
    }

    // MARK: - Returning after the other device read on (final review, Important 1)

    /// Where the other device read on to while a lookup was showing here.
    private let readOnElsewhere = ReadingPosition(book: "MAT", chapter: 3, firstVisibleVerse: 3, translationID: "KJV")
    private let matthewThree = ChapterLocation(book: "MAT", chapter: 3)

    /// The screen does not move while the lookup is showing; returning goes to where he read on,
    /// in its translation, and leaves that place stored.
    @Test func returningFromALookupGoesToWhereTheOtherDeviceReadOn() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2)
        model.isAppActive = false
        positionStore.save(readOnElsewhere)
        model.adoptStoredPosition()
        #expect(model.location == psalmTwo && model.translationID == "WEB" && model.scrollTarget?.verse == 2)
        model.isAppActive = true
        model.returnFromLookup()
        #expect(model.lookupReturn == nil)
        #expect(model.location == matthewThree && model.scrollTarget?.verse == 3)
        #expect(model.translationID == "KJV" && model.verses.first?.translationID == "KJV")
        #expect(positionStore.load() == readOnElsewhere)
        reportTopVerse(3, of: model)
        #expect(positionStore.load() == readOnElsewhere)
    }

    /// The same for a jump inside the chapter, returned from by the way back and by Back.
    @Test func returningFromAJumpInsideTheChapterGoesToWhereTheOtherDeviceReadOn() throws {
        for useBack in [false, true] {
            let (model, positionStore) = try readingMatthewOne()
            model.lookUp(matthewOne, verse: 2)
            positionStore.save(readOnElsewhere)
            model.adoptStoredPosition()
            #expect(model.location == matthewOne && model.translationID == "WEB" && model.scrollTarget?.verse == 2)
            if useBack { model.goBack() } else { model.returnFromLookup() }
            #expect(model.lookupReturn == nil)
            #expect(model.location == matthewThree && model.scrollTarget?.verse == 3)
            #expect(model.translationID == "KJV" && model.verses.first?.translationID == "KJV")
            #expect(positionStore.load() == readOnElsewhere)
        }
    }

    /// Back through the history onto the return chapter is returning, so it goes there too.
    @Test func goingBackToTheReturnChapterGoesToWhereTheOtherDeviceReadOn() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 2)
        positionStore.save(readOnElsewhere)
        model.goBack()
        #expect(model.lookupReturn == nil)
        #expect(model.location == matthewThree && model.scrollTarget?.verse == 3 && model.translationID == "KJV")
        #expect(positionStore.load() == readOnElsewhere)
    }

    /// With nothing written elsewhere, each way of returning restores the remembered chapter,
    /// verse and translation, as before.
    @Test func returningWithNothingWrittenElsewhereRestoresTheRememberedPlace() throws {
        let place = ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB")
        for way in 0..<3 {
            let (model, positionStore) = try readingMatthewOne()
            switch way {
            case 0:
                model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
                model.returnFromLookup()
            case 1:
                model.lookUp(matthewOne, verse: 1, translationID: "KJV")
                model.returnFromLookup()
            default:
                model.lookUp(psalmTwo, verse: 2, translationID: "KJV")
                model.goBack()
            }
            #expect(model.lookupReturn == nil)
            #expect(ReadingPlace(location: try #require(model.location), verse: try #require(model.scrollTarget?.verse), translationID: model.translationID) == place)
            #expect(positionStore.load() == readingPlace)
        }
    }

    /// Final review (Minor): a translation chosen during a jump inside the chapter being read moves
    /// the return place with it, so scrolling five lines still ends the jump and a relaunch opens
    /// in the translation chosen.
    @Test func choosingATranslationDuringAJumpInsideTheChapterCarriesTheReturnPlace() throws {
        let defaults = makeDefaults()
        let (model, positionStore) = try readingMatthewOne(defaults: defaults)
        model.lookUp(matthewOne, verse: 2)
        model.setTranslation("KJV")
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "KJV"))
        #expect(model.location == matthewOne && model.translationID == "KJV")
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 3, translationID: "KJV"))
        let (relaunched, _) = try makeModel(defaults: defaults)
        #expect(relaunched.location == matthewOne && relaunched.translationID == "KJV" && relaunched.scrollTarget?.verse == 3)
        reportTopVerse(1, of: model)
        model.reportLinesScrolledSinceJump(NavigationModel.linesThatKeepAJump, from: model.scrollTarget!)
        #expect(model.lookupReturn == nil)
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 1, translationID: "KJV"))

        let (returning, _) = try readingMatthewOne()
        returning.lookUp(matthewOne, verse: 2)
        returning.setTranslation("KJV")
        returning.returnFromLookup()
        #expect(returning.location == matthewOne && returning.translationID == "KJV" && returning.scrollTarget?.verse == 3)
    }

    /// Return on a typed reference takes the Go to row, which reads on.
    @Test func aTypedReferenceWithAVerseOpensAndMovesThePlace() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.markSearch = { [self.markEntry()] }   // a mark in Matthew 2:2 ranks under the Go to row
        model.isPaletteShown = true
        model.paletteQuery = "Matt 2:2"
        model.updatePalette()
        model.submitPalette(selectedIndex: 0)
        #expect(model.lookupReturn == nil && model.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 2, firstVisibleVerse: 2, translationID: "WEB"))
    }

    @Test func verseRowsLookUpAndReferenceRowsOpen() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.paletteQuery = "Line b"
        model.updatePalette()
        let verseRow = try #require(model.paletteItems.first { if case .verse = $0 { true } else { false } })
        model.select(verseRow)
        #expect(model.location == ChapterLocation(book: "MAT", chapter: 2) && model.lookupReturn != nil)
        #expect(positionStore.load() == readingPlace)
        model.select(.reference(ReferenceParser.parse("Matt 3:3")!))
        #expect(model.lookupReturn == nil)
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 3, firstVisibleVerse: 3, translationID: "WEB"))
        model.select(verseRow)
        let psalms = try #require(model.books.first { $0.book.id == "PSA" }?.book)
        model.select(.book(psalms))
        #expect(model.lookupReturn == nil)
        #expect(positionStore.load()?.chapterLocation == ChapterLocation(book: "PSA", chapter: 1))
    }

    @Test func unbundledDefaultFallsBackToTheFallbackBeforeTheFirstBundled() throws {
        // The fixture bundles KJV and WEB; KJV sorts first, so a wrong chain would land there.
        let model = try NavigationModel(
            store: try FixtureStore.make(),
            positionStore: ReadingPositionStore(defaults: makeDefaults()),
            defaultTranslationID: "NIV",
            fallbackTranslationID: "WEB")
        #expect(model.translationID == "WEB")
        let unbundledFallback = try NavigationModel(
            store: try FixtureStore.make(),
            positionStore: ReadingPositionStore(defaults: makeDefaults()),
            defaultTranslationID: "NIV",
            fallbackTranslationID: "ASV")
        #expect(unbundledFallback.translationID == "KJV")
    }

    // MARK: - One chapter at a time, its book loaded once (milestone 9)

    private func at(_ chapter: Int, _ verse: Int, in book: String = "MAT") -> VerseLocation {
        VerseLocation(book: book, chapter: chapter, verse: verse)
    }

    private func matthew(_ chapter: Int) -> ChapterLocation {
        ChapterLocation(book: "MAT", chapter: chapter)
    }

    @Test func openingAChapterLoadsItsBook() throws {
        let (model, _) = try makeModel()
        model.open(matthew(2))
        let book = try #require(model.bookText)
        #expect(book.book == "MAT" && book.translationID == "WEB")
        #expect(book.chapters.keys.sorted() == Array(1...6))
        #expect(model.verses == book.chapters[2])
        #expect(model.scrollTarget?.chapter == 2 && model.scrollTarget?.verse == 1)
    }

    /// `BookText`'s equality is the pair it was loaded for: the text for a pair never changes.
    @Test func bookTextsAreEqualByBookAndTranslation() {
        let verse = Verse(id: at(1, 1), translationID: "WEB", text: "x", breakAfter: false)
        let full = BookText(book: "MAT", translationID: "WEB", chapters: [1: [verse]])
        #expect(full == BookText(book: "MAT", translationID: "WEB", chapters: [:]))
        #expect(full != BookText(book: "MAT", translationID: "KJV", chapters: [1: [verse]]))
        #expect(full != BookText(book: "PSA", translationID: "WEB", chapters: [1: [verse]]))
    }

    @Test func aReportFromAnotherBookOrAMissingChapterIsIgnored() throws {
        let (model, positionStore) = try makeModel()
        model.open(matthew(2))
        model.reportReadingPosition(at(1, 2, in: "PSA"))   // a stale report from the book before
        model.reportReadingPosition(at(9, 1))
        #expect(model.location == matthew(2) && positionStore.load()?.chapterLocation == matthew(2))
    }

    /// Spec 4.2: the reader shows one chapter, so a verse of another (a stale report from the
    /// chapter shown before) moves nothing: not the chapter, its verses, the stored position or
    /// the history's entry.
    @Test func reportingAVerseInAnotherChapterIsIgnored() throws {
        let (model, positionStore) = try makeModel()
        model.open(psalmTwo)
        model.open(matthew(4))
        let verses = model.verses
        let target = model.scrollTarget
        model.reportReadingPosition(at(4, 2))
        model.reportReadingPosition(at(5, 1))
        #expect(model.location == matthew(4) && model.verses == verses && model.chapterTitle == "Matthew 4")
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 4, firstVisibleVerse: 2, translationID: "WEB"))
        #expect(model.scrollTarget == target && model.canGoBack && !model.canGoForward)
        model.goBack()
        #expect(model.location == psalmTwo && !model.canGoBack)
        model.goForward()   // the entry still holds chapter 4 at the verse read there
        #expect(model.location == matthew(4) && model.scrollTarget?.chapter == 4 && model.scrollTarget?.verse == 2)
    }

    @Test func nextWithinTheBookPushesHistory() throws {
        let (model, positionStore) = try makeModel()
        model.open(matthew(2))
        let book = try #require(model.bookText)
        model.goToNextChapter()
        #expect(model.scrollTarget?.chapter == 3 && model.scrollTarget?.verse == 1)
        #expect(model.location == matthew(3) && model.verses == book.chapters[3])
        #expect(model.bookText == book && model.canGoBack)
        #expect(positionStore.load()?.chapterLocation == matthew(3))
        model.goToPreviousChapter()
        #expect(model.scrollTarget?.chapter == 2 && model.scrollTarget?.verse == 1)
        #expect(model.location == matthew(2) && model.verses == book.chapters[2])
    }

    @Test func nextAtTheEndOfABookOpensTheNext() throws {
        let (model, _) = try makeModel()
        model.open(matthew(6))
        model.goToNextChapter()
        #expect(model.location == ChapterLocation(book: "TOB", chapter: 1))
        #expect(model.bookText?.book == "TOB" && model.verses == model.bookText?.chapters[1])
        #expect(model.scrollTarget?.chapter == 1 && model.scrollTarget?.verse == 1)
        model.goToPreviousChapter()   // previous at a book's first chapter: the book before, at its last
        #expect(model.location == matthew(6) && model.bookText?.book == "MAT")
        #expect(model.scrollTarget?.chapter == 6 && model.scrollTarget?.verse == 1)
        model.goBack()
        #expect(model.location == ChapterLocation(book: "TOB", chapter: 1))
    }

    @Test func theNextBookIsTheFirstChapterOfTheBookAfter() throws {
        let (model, _) = try makeModel()
        #expect(model.nextBook == nil && model.nextBookTitle == nil)
        model.open(ChapterLocation(book: "PSA", chapter: 1))
        #expect(model.nextBook == matthew(1) && model.nextBookTitle == "Matthew")
        model.open(matthew(2))
        #expect(model.nextBook == ChapterLocation(book: "TOB", chapter: 1) && model.nextBookTitle == "Tobit")
        model.goToNextChapter()
        #expect(model.nextBook == ChapterLocation(book: "TOB", chapter: 1))
        model.open(ChapterLocation(book: "TOB", chapter: 1))
        #expect(model.nextBook == nil && model.nextBookTitle == nil)   // the last book
    }

    @Test func backAfterNextThreeTimesStepsAChapterAtATime() throws {
        let (model, _) = try makeModel()
        model.open(matthew(1))
        model.goToNextChapter()
        model.goToNextChapter()
        model.reportReadingPosition(at(3, 3))
        model.goToNextChapter()
        #expect(model.location == matthew(4))
        model.goBack()
        #expect(model.location == matthew(3) && model.scrollTarget?.chapter == 3 && model.scrollTarget?.verse == 3)
        model.goBack()
        #expect(model.location == matthew(2) && model.scrollTarget?.chapter == 2)
        model.goBack()
        #expect(model.location == matthew(1) && !model.canGoBack)
    }

    /// Spec 4.2: lookups behave as on `main`. A jump inside the chapter being read becomes the
    /// place after five lines of scroll; a lookup into another chapter of the same book stays a
    /// lookup however far he scrolls.
    @Test(arguments: [NavigationModel.linesThatKeepAJump, -NavigationModel.linesThatKeepAJump])
    func aLookupInTheChapterEndsAfterFiveLines(lines: Double) throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 2)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        model.reportReadingPosition(at(1, 2))
        model.reportLinesScrolledSinceJump(lines * 0.98, from: model.scrollTarget!)
        #expect(model.lookupReturn != nil && positionStore.load() == readingPlace)
        model.reportLinesScrolledSinceJump(lines, from: model.scrollTarget!)
        #expect(model.lookupReturn == nil && !model.canGoBack)
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 2, translationID: "WEB"))

        let (other, otherStore) = try readingMatthewOne()
        other.lookUp(matthew(4), verse: 2)
        other.reportReadingPosition(at(4, 2))
        other.reportLinesScrolledSinceJump(lines * 8, from: other.scrollTarget!)
        #expect(other.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(otherStore.load() == readingPlace)
        other.goBack()
        #expect(other.location == matthewOne && other.scrollTarget?.verse == 3 && other.lookupReturn == nil)
    }

    /// Review Focus 5: a lookup into another book, or into this book in another translation, stays
    /// a lookup however far he scrolls, until Read From Here, Next or Previous.
    @Test func aLookupIntoAnotherBookStaysALookup() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(psalmTwo, verse: 1)
        model.reportReadingPosition(at(2, 2, in: "PSA"))
        model.reportLinesScrolledSinceJump(40, from: model.scrollTarget!)
        model.reportLinesScrolledSinceJump(-40, from: model.scrollTarget!)
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(positionStore.load() == readingPlace)
        model.keepLookup()
        #expect(model.lookupReturn == nil)
        #expect(positionStore.load() == ReadingPosition(book: "PSA", chapter: 2, firstVisibleVerse: 2, translationID: "WEB"))

        let (other, otherStore) = try readingMatthewOne()
        other.lookUp(matthew(4), verse: 1, translationID: "KJV")
        other.reportLinesScrolledSinceJump(40, from: other.scrollTarget!)
        #expect(other.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(otherStore.load() == readingPlace)
        other.goToNextChapter()
        #expect(other.lookupReturn == nil && otherStore.load() == ReadingPosition(book: "MAT", chapter: 5, firstVisibleVerse: 1, translationID: "KJV"))
    }

    /// Fix round 1 (a): Forward out of a lookup that shares the place's entry leaves the place in
    /// the back stack; Back then returns to it and keeps the chapter Forward went to.
    @Test func forwardOutOfAJumpInsideTheChapterKeepsThePlaceAndForward() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.open(psalmTwo)
        model.goBack()
        #expect(model.location == matthewOne && model.scrollTarget?.verse == 3)
        model.lookUp(matthewOne, verse: 2)
        reportTopVerse(2, of: model)
        model.goForward()
        #expect(model.location == psalmTwo && model.lookupReturn != nil)
        #expect(model.canGoBack && !model.canGoForward)
        model.goBack()
        #expect(model.location == matthewOne && model.scrollTarget?.verse == 3 && model.lookupReturn == nil)
        #expect(!model.canGoBack && model.canGoForward)
        #expect(positionStore.load() == readingPlace)
        model.goForward()
        #expect(model.location == psalmTwo && !model.canGoForward)
    }

    /// Fix round 1 (b): a lookup that pushes an entry, made from a jump inside the chapter that
    /// shared the place's entry and was scrolled, pushes the place at its own verse, not the
    /// verse the jump scrolled to.
    @Test func aLookupFromAJumpInsideTheChapterPushesThePlace() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 3)
        model.reportReadingPosition(at(1, 3))
        model.reportReadingPosition(at(1, 1))
        model.lookUp(psalmTwo, verse: 1)
        #expect(model.canGoBack && !model.canGoForward)
        model.goBack()
        #expect(model.location == matthewOne && model.scrollTarget?.verse == 3 && model.lookupReturn == nil)
        #expect(!model.canGoBack && model.canGoForward)
        #expect(positionStore.load() == readingPlace)
    }

    /// Fix round 1: returning to where the other device read on, from a scrolled jump inside the
    /// chapter, leaves the place at its own verse behind it in the history.
    @Test func returningToWhereReadElsewhereFromAJumpInsideTheChapterLeavesThePlaceBehind() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthewOne, verse: 3)
        model.reportReadingPosition(at(1, 3))
        model.reportReadingPosition(at(1, 1))
        positionStore.save(readOnElsewhere)
        model.returnFromLookup()
        #expect(model.location == matthewThree && model.translationID == "KJV" && model.lookupReturn == nil)
        model.goBack()
        #expect(model.location == matthewOne && model.scrollTarget?.verse == 3)
        #expect(!model.canGoBack && model.canGoForward)
    }

    @Test func switchingTranslationKeepsChapterAndVerse() throws {
        let (model, positionStore) = try makeModel()
        model.open(matthew(4))
        model.reportReadingPosition(at(4, 1))
        model.reportReadingPosition(at(4, 3))
        model.setTranslation("KJV")
        #expect(model.location == matthew(4) && model.scrollTarget?.chapter == 4 && model.scrollTarget?.verse == 3)
        #expect(model.bookText?.book == "MAT" && model.bookText?.translationID == "KJV")
        #expect(model.verses == model.bookText?.chapters[4] && model.verses.first?.translationID == "KJV")
        #expect(positionStore.load() == ReadingPosition(book: "MAT", chapter: 4, firstVisibleVerse: 3, translationID: "KJV"))
        model.setTranslation("WEB")
        model.open(ChapterLocation(book: "TOB", chapter: 1))
        #expect(model.bookText?.book == "TOB")
        model.setTranslation("KJV")   // KJV has no Tobit
        #expect(model.bookText == nil && model.verses.isEmpty && model.location == nil)
    }

    /// As on `main`, a translation chosen during a lookup into another chapter leaves the place
    /// being read in its own translation: only a jump inside the chapter carries it.
    @Test func choosingATranslationDuringALookupIntoAnotherChapterLeavesThePlace() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUp(matthew(4), verse: 2)
        model.setTranslation("KJV")
        #expect(model.lookupReturn == ReadingPlace(location: matthewOne, verse: 3, translationID: "WEB"))
        #expect(positionStore.load() == readingPlace)
        model.returnFromLookup()
        #expect(model.location == matthewOne && model.translationID == "WEB" && model.scrollTarget?.verse == 3)
    }

    // MARK: - Passage links

    @Test func aLinkOpensAsALookupAndBackReturns() throws {
        let (model, positionStore) = try readingMatthewOne()
        #expect(model.openPassageLink(URL(string: "bible://psa.2.2")!))
        #expect(model.location == psalmTwo && model.scrollTarget?.verse == 2 && model.screen == .reader)
        #expect(model.lookupReturn?.location == matthewOne && positionStore.load() == readingPlace)
        model.goBack()
        #expect(model.location == matthewOne)
    }

    @Test func aLinkWithATranslationLooksUpInIt() throws {
        let (model, _) = try readingMatthewOne()
        #expect(model.openPassageLink(URL(string: "bible://psa.2.2?translation=kjv")!))
        #expect(model.translationID == "KJV" && model.lookupReturn?.translationID == "WEB")
        // One the app lacks is ignored.
        let (other, _) = try readingMatthewOne()
        #expect(other.openPassageLink(URL(string: "bible-dev://psa.2.2?translation=NIV")!))
        #expect(other.translationID == "WEB" && other.location == psalmTwo)
    }

    @Test func aLinkTheAppCannotOpenChangesNothing() throws {
        let (model, _) = try readingMatthewOne()
        for text in ["bible://xyz.1.1", "bible://rev.1.1", "bible://psa.200", "https://route.bible/psa.2"] {
            #expect(!model.openPassageLink(URL(string: text)!), "\(text)")
            #expect(model.location == matthewOne && model.lookupReturn == nil && model.translationID == "WEB")
        }
    }

    @Test func aBookAloneOpensItsFirstChapterAndAVersePastTheEndOpensTheChapter() throws {
        let (model, _) = try readingMatthewOne()
        #expect(model.openPassageLink(URL(string: "bible://psa")!))
        #expect(model.location == ChapterLocation(book: "PSA", chapter: 1))
        #expect(model.openPassageLink(URL(string: "bible://psa.2.99")!))
        #expect(model.location == psalmTwo && model.scrollTarget?.chapter == 2 && model.scrollTarget?.verse == 1)
    }

    @Test func aLinkClosesThePaletteAndTheShortcutsSheet() throws {
        let (model, _) = try readingMatthewOne()
        model.isPaletteShown = true
        model.isShortcutsShown = true
        #expect(model.openPassageLink(URL(string: "bible://psa.2.2")!))
        #expect(!model.isPaletteShown && !model.isShortcutsShown)
    }

    @Test func resumeReadingTargetsTheOpenChapter() throws {
        let (model, _) = try makeModel()
        model.open(matthew(2))
        model.reportReadingPosition(at(2, 3))
        model.resumeReading()
        #expect(model.scrollTarget?.chapter == 2 && model.scrollTarget?.verse == 3)
    }

    // MARK: - Recents

    private var recordingRecents: RecentsStore?

    private func recording() throws -> (NavigationModel, ReadingPositionStore, RecentsStore) {
        let positionStore = ReadingPositionStore(defaults: makeDefaults())
        let recents = RecentsStore(defaults: makeDefaults())
        recordingRecents = recents
        let model = try NavigationModel(
            store: try FixtureStore.make(), positionStore: positionStore, recents: recents, defaultTranslationID: "WEB")
        return (model, positionStore, recents)
    }

    private var targets: [Recent.Target] { recordingRecents?.items.map(\.target) ?? [] }

    private func recent(_ target: Recent.Target, _ translation: String?) -> PaletteItem {
        .recent(Recent(target: target, translationID: translation, date: .now))
    }

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

    /// Spec 5.2: Open on a cross-reference's passage is a lookup and is recorded, as a reference in a note's is;
    /// a compare row's lookup (the reader's own verse in another translation) records nothing.
    @Test func openingACrossReferencesPassageIsALookupAndIsRecorded() throws {
        let (model, positionStore, _) = try recording()
        model.open(matthew(5))
        reportTopVerse(1, of: model)
        let stored = positionStore.load()
        model.lookUpPassage(Reference(book: BookCatalog.book(code: "MAT")!, chapter: 6, verse: 2, endVerse: 3))
        #expect(model.location == matthew(6) && model.scrollTarget?.verse == 2 && model.lookupReturn?.location == matthew(5))
        #expect(positionStore.load() == stored)
        model.lookUp(matthew(5), verse: 3, translationID: "KJV")
        #expect(targets == [.lookup(matthew(6), verse: 2), .chapter(matthew(5))])
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

    @Test func aRecentSearchInAScopeTheTranslationLacksSearchesTheWholeBible() throws {
        let (model, _, recents) = try recording()
        model.setTranslation("KJV")                                                 // the fixture's KJV has no Apocrypha
        model.open(matthewOne)
        model.isPaletteShown = true
        model.select(recent(.search(query: "verse", scope: .apocrypha, verseCount: 2), nil))
        let count = try #require(scripture(model)?.totalCount)
        #expect(model.searchScope == .wholeBible && count > 0)
        #expect(recents.items.first?.target == .search(query: "verse", scope: .wholeBible, verseCount: count))
    }

    @Test func aLookupInATranslationThatLacksTheScopeSearchesTheWholeBible() throws {
        let (model, _) = try makeModel()
        model.open(matthewOne)
        model.searchScope = .book("TOB")
        model.lookUp(matthew(2), verse: 1, translationID: "KJV")
        #expect(model.translationID == "KJV" && model.searchScope == .wholeBible)
    }

    @Test func withNothingTypedThePaletteShowsRecentWithoutTheOpenChapter() throws {
        let (model, _, _) = try recording()
        model.includesCommandsInSearch = false
        for location in [matthewOne, matthew(2), psalmTwo] { model.open(location) }
        search(model, "")
        #expect(model.paletteResults.groups.map(\.kind) == [.recent])
        #expect(model.paletteItems.map(\.title) == ["Matthew 2", "Matthew 1"])     // Psalm 2 is open now
    }

    @Test func onTheFrontPageRecentKeepsTheChapterLastRead() throws {
        let (model, _, _) = try recording()
        model.includesCommandsInSearch = false
        for location in [matthewOne, psalmTwo] { model.open(location) }
        model.goHome()
        search(model, "")
        #expect(model.paletteItems.map(\.title) == ["Psalm 2", "Matthew 1"])
    }

    // MARK: - Commands (finding 5.2, 5.3)

    private func commands(_ model: NavigationModel) -> [PaletteCommand] {
        (model.paletteResults.groups.first { $0.kind == .commands }?.items ?? []).compactMap {
            if case .command(let command) = $0 { command } else { nil }
        }
    }

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

    /// The groups the palette shows now, after the chosen chip.
    private func shownKinds(_ model: NavigationModel) -> [SearchGroupKind] {
        model.paletteResults.showing(model.paletteChip).groups.map(\.kind)
    }

    @Test func emptyingTheFieldReturnsTheChipToAllAndRecentShows() throws {
        let (model, _, _) = try recording()
        model.open(matthewOne)
        model.open(matthew(2))
        model.isPaletteShown = true
        search(model, "page")
        model.paletteChip = .commands
        model.updatePalette()
        #expect(shownKinds(model) == [.commands])
        search(model, "")
        #expect(model.paletteChip == nil && shownKinds(model) == [.recent, .commands])
    }

    @Test func escFromSwitchTranslationWithAChipChosenShowsTheWholeEmptyState() throws {
        let (model, _, _) = try recording()
        model.open(matthewOne)
        model.open(matthew(2))
        model.isPaletteShown = true
        search(model, "sw")
        model.paletteChip = .commands
        model.updatePalette()
        model.select(.command(.switchTranslation))
        model.escapePalette()
        #expect(model.isPaletteShown && model.paletteChip == nil && shownKinds(model) == [.recent, .commands])
    }

    /// The Mac's palette is empty whenever it closes, so ⌘K always opens on Recent and Commands.
    private func expectClosedEmpty(_ model: NavigationModel, _ route: String) {
        #expect(!model.isPaletteShown, "\(route)")
        #expect(model.paletteQuery.isEmpty && model.paletteResults == .empty && model.paletteItems.isEmpty, "\(route)")
        #expect(model.searchScope == .wholeBible && model.paletteChip == nil, "\(route)")
        model.isPaletteShown = true
        model.updatePalette()                           // the window's refresh on opening
        #expect(shownKinds(model) == [.recent, .commands], "\(route): reopened")
    }

    /// Opens the palette on words that find a verse, narrowed to the New Testament with a chip chosen.
    private func openOnWords(_ model: NavigationModel) {
        model.isPaletteShown = true
        search(model, "tempter")
        model.searchScope = .newTestament
        model.paletteChip = .scripture
        model.updatePalette()
    }

    @Test func everyWayTheMacsPaletteClosesLeavesItEmpty() throws {
        let (model, _, _) = try recording()
        model.open(matthewOne)
        model.open(matthew(2))
        openOnWords(model)
        #expect(model.paletteQuery == "tempter" && scripture(model) != nil)
        model.escapePalette()                                        // Esc
        expectClosedEmpty(model, "Esc")
        openOnWords(model)
        model.isPaletteShown = false                                 // a click on the page outside, ⌘K, ⌘/
        expectClosedEmpty(model, "set from outside")
        openOnWords(model)
        #expect(model.openPassageLink(URL(string: "bible://mat.2")!)) // a passage link
        expectClosedEmpty(model, "a passage link")
    }

    @Test func switchTranslationsFirstEscStillOnlyGoesBack() throws {
        let (model, _) = try makeModel()
        model.isPaletteShown = true
        search(model, "sw")
        model.select(.command(.switchTranslation))
        model.escapePalette()
        #expect(model.isPaletteShown && !model.isChoosingTranslation)
        model.escapePalette()
        #expect(!model.isPaletteShown && model.paletteQuery.isEmpty && model.paletteResults == .empty)
    }

    /// The phone's search tab never shows the Mac's palette, so nothing closes it: its words stay.
    @Test func thePhonesSearchKeepsItsWordsWhateverTheMacsPaletteDoes() throws {
        let (phone, _, _) = try recording()
        phone.searchLimits = .phone
        phone.includesCommandsInSearch = false
        search(phone, "tempter")
        let results = phone.paletteResults
        phone.select(try #require(phone.paletteItems.first { if case .verse = $0 { true } else { false } }), keepingQuery: true)
        #expect(phone.paletteQuery == "tempter" && phone.paletteResults == results)
        #expect(phone.openPassageLink(URL(string: "bible://mat.2")!))
        #expect(phone.paletteQuery == "tempter" && phone.paletteResults == results)
    }

    /// Which rows take the phone's search to the reader: a conversation, found or recent, opens in Ask instead.
    @Test func aPhoneSearchRowShowsTheReaderUnlessItStaysOnSearchOrOpensAsk() throws {
        let (phone, _, _) = try recording()
        search(phone, "tempter")
        let verse = try #require(phone.paletteItems.first { if case .verse = $0 { true } else { false } })
        let note = SearchMarkHit(entry: markEntry())
        let thread = SearchMarkHit(entry: NotesBrowserEntry(
            id: UUID(), kind: .thread(id: UUID()), book: "MAT", bookOrder: 40, chapter: 2, verse: 2, endVerse: 2,
            referenceString: "Matthew 2", translationID: "WEB", color: nil, quotedText: "", body: "Outline", modifiedAt: Date()))
        func markRecent(_ hit: SearchMarkHit) -> PaletteItem {
            recent(.mark(id: hit.id, kind: hit.kind, target: hit.target, reference: hit.referenceString), "WEB")
        }
        #expect(verse.showsReaderWhenChosen)
        #expect(PaletteItem.mark(note).showsReaderWhenChosen)
        #expect(!PaletteItem.mark(thread).showsReaderWhenChosen)
        #expect(recent(.chapter(matthew(2)), "WEB").showsReaderWhenChosen)
        #expect(recent(.lookup(matthew(4), verse: 3), "WEB").showsReaderWhenChosen)
        #expect(markRecent(note).showsReaderWhenChosen)
        #expect(!markRecent(thread).showsReaderWhenChosen)
        #expect(!recent(.search(query: "tempter", scope: .wholeBible, verseCount: 2), nil).showsReaderWhenChosen)
        #expect(!PaletteItem.suggestion(SearchSuggestion(query: "jesus", verseCount: 3)).showsReaderWhenChosen)
    }

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

    // MARK: - The Library's place (spec 6.6, 6.7)

    private func ref(_ book: String, _ chapter: Int, _ verse: Int) -> Reference {
        Reference(book: BookCatalog.book(code: book)!, chapter: chapter, verse: verse)
    }

    private let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])

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
        #expect(PaletteCommand.all.count == 35)                              // the 33 before Export All Data and Import Data (PaletteCommandTests)
    }

    /// A person or place opened by name is not added to Recent; the chip lifts the limit; a lookup
    /// showing returns first, as Home would.
    @Test func aNameOpenedIsNotRecordedAndAChipShowsMore() throws {
        let (model, _, recents) = try recording()
        model.open(matthewOne)
        model.lookUp(psalmTwo, verse: 2)
        let recentsBefore = recents.items.map(\.target)
        model.isPaletteShown = true
        model.paletteQuery = "jo"
        model.updatePalette()
        let people = try #require(model.paletteResults.groups.first { $0.kind == .people })
        #expect(people.items.count == min(people.totalCount, SearchLimits.palette.people) && people.totalCount == 2)
        model.paletteChip = .people
        model.updatePalette()
        #expect(model.paletteResults.groups.map(\.kind) == [.people])
        model.select(people.items[0])
        #expect(recents.items.map(\.target) == recentsBefore && !model.isLookingUp && model.location == matthewOne)
        #expect(model.paletteQuery.isEmpty && model.screen == .frontPage)
    }

    /// On the whole Bible "At the same spot" is every place at the point, whichever books name them; in a
    /// book, only the book's. (The fixture's Jerusalem and Zion share Psalms and Matthew, so Romans,
    /// which names neither, is the book that tells the two forms apart.)
    @Test func theWholeBiblesPlaceHasEveryPlaceAtItsSpot() throws {
        let (model, _) = try readingMatthewOne()
        let whole = try #require(model.placePage(636, inBook: nil))
        #expect(whole.sameSpot.map(\.id) == [1263] && whole.here == nil && whole.elsewhere.map(\.id) == ["PSA", "MAT"])
        #expect(try #require(model.placePage(636, inBook: "ROM")).sameSpot.isEmpty)
        #expect(try #require(model.placePage(636, inBook: "MAT")).sameSpot.map(\.id) == [1263])
    }

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

    /// The way back with nothing being read returns at once, wherever the history stands.
    @Test func withNothingBeingReadTheWayBackReturnsAtOnce() throws {
        let (model, positionStore) = try makeModel()
        let about = LibraryPlace(book: "MAT", topic: .about)
        model.lookUpFromLibrary(ref("MAT", 2, 1), from: about)
        model.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 1, translationID: "KJV")
        #expect(model.translationID == "KJV" && model.isLookingUp && model.lookupReturn == nil)
        model.returnFromLookup()
        #expect(model.screen == .frontPage && model.libraryPlace == about && model.location == nil && model.bookText == nil)
        #expect(!model.canGoBack && !model.canGoForward && model.translationID == "WEB" && positionStore.load() == nil)
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

    /// Review I1: a Library lookup into the chapter being read is not ended by scrolling; Back still
    /// returns to the person.
    @Test func scrollingALibraryLookupInTheChapterBeingReadKeepsTheWayBack() throws {
        let (model, positionStore) = try readingMatthewOne()
        let stored = positionStore.load()
        model.lookUpFromLibrary(ref("MAT", 1, 6), from: david)
        model.reportLinesScrolledSinceJump(40, from: model.scrollTarget!)
        #expect(model.isLookingUp && model.libraryReturn?.place == david && positionStore.load() == stored)
        model.goBack()
        #expect(model.screen == .frontPage && model.libraryPlace == david && !model.isLookingUp)
    }

    /// With nothing being read, Home during a Library lookup shows the Library as it was and opens nothing.
    @Test func withNothingBeingReadHomeDuringALibraryLookupReturnsToTheLibrary() throws {
        let (model, positionStore) = try makeModel()
        let about = LibraryPlace(book: "MAT", topic: .about)
        model.lookUpFromLibrary(ref("MAT", 2, 1), from: about)
        model.goHome()
        #expect(model.screen == .frontPage && model.libraryPlace == about && model.location == nil && !model.isLookingUp)
        #expect(positionStore.load() == nil)
    }

    /// With nothing being read, a second Open from another page is the one the way back returns to.
    @Test func withNothingBeingReadASecondOpenReturnsToItsOwnPage() throws {
        let (model, positionStore) = try makeModel()
        let about = LibraryPlace(book: "MAT", topic: .about)
        let people = LibraryPlace(book: "MAT", topic: .people)
        model.lookUpFromLibrary(ref("MAT", 2, 1), from: about)
        model.lookUpFromLibrary(ref("MAT", 5, 3), from: people)
        model.goBack()
        #expect(model.screen == .reader && model.location == matthew(2) && model.isLookingUp)
        model.goBack()
        #expect(model.screen == .frontPage && model.libraryPlace == people && model.location == nil && positionStore.load() == nil)
    }

    /// Live finding L3: Home on the front page chooses the book being read, with a Library view open
    /// or not (spec 4.1).
    @Test func homeOnTheFrontPageChoosesTheBookBeingReadWithOrWithoutAView() throws {
        let (model, _) = try readingMatthewOne()
        model.goHome()
        model.selectedBookID = "PSA"                                         // another book chosen, no view open
        model.goHome()
        #expect(model.screen == .frontPage && model.selectedBookID == "MAT" && model.libraryPlace == nil)
        model.selectedBookID = "PSA"
        model.libraryPlace = david                                           // and with a view open
        model.goHome()
        #expect(model.screen == .frontPage && model.selectedBookID == "MAT" && model.libraryPlace == nil)
    }

    /// Opening from the Library is recorded as a lookup; a passage the translation lacks changes nothing.
    @Test func openFromTheLibraryIsRecordedAndAMissingPassageDoesNothing() throws {
        let (model, positionStore, _) = try recording()
        model.lookUpFromLibrary(ref("MAT", 2, 1), from: LibraryPlace(book: "MAT", topic: .about))
        #expect(targets == [.lookup(matthew(2), verse: 1)])
        model.returnFromLookup()
        model.setTranslation("KJV")
        model.lookUpFromLibrary(ref("TOB", 1, 1), from: LibraryPlace(book: "TOB", topic: .about))
        #expect(model.screen == .frontPage && !model.isLookingUp && model.libraryReturn == nil && model.location == nil)
        #expect(targets == [.lookup(matthew(2), verse: 1)] && positionStore.load() == nil)
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

    /// Review Focus 2: the view closes and a book the translation has is chosen, during a lookup and on the front page.
    @Test func aTranslationWithoutTheLibrarysBookClosesItsView() throws {
        let (model, positionStore) = try makeModel()
        let tobit = LibraryPlace(book: "TOB", topic: .about)
        model.lookUpFromLibrary(ref("TOB", 1, 1), from: tobit)               // nothing being read; WEB alone has Tobit
        model.setTranslation("KJV")
        #expect(!model.isLookingUp && model.libraryReturn == nil && model.location == nil && model.screen == .frontPage && positionStore.load() == nil)
        #expect(model.libraryPlace == nil && model.selectedBookID == "PSA")
        let (reading, _) = try readingMatthewOne()
        reading.goHome()
        reading.selectedBookID = "TOB"
        reading.libraryPlace = tobit
        reading.setTranslation("KJV")
        #expect(reading.libraryPlace == nil && reading.selectedBookID == "MAT" && reading.screen == .frontPage)
    }

    /// Changing the translation on the front page keeps the book chosen there and its Library view.
    @Test func aTranslationChangeOnTheFrontPageKeepsTheChosenBook() throws {
        let (model, _) = try readingMatthewOne()
        model.goHome()
        model.selectedBookID = "PSA"
        model.libraryPlace = david
        model.setTranslation("KJV")
        #expect(model.screen == .frontPage && model.selectedBookID == "PSA" && model.libraryPlace == david)
        #expect(model.location == matthewOne)
    }

    /// A position the other device writes during a lookup with nothing being read waits until it ends.
    @Test func anotherDevicesPositionWaitsForALibraryLookupToEnd() throws {
        let (model, positionStore) = try makeModel()
        let about = LibraryPlace(book: "MAT", topic: .about)
        model.lookUpFromLibrary(ref("MAT", 2, 1), from: about)
        model.isAppActive = false
        positionStore.save(readOnElsewhere)
        model.adoptStoredPosition()
        #expect(model.location == matthew(2) && model.translationID == "WEB" && model.isLookingUp)
        model.goBack()
        #expect(model.screen == .frontPage && model.libraryPlace == about && model.location == nil)
        model.adoptStoredPosition()
        #expect(model.location == matthewThree && model.translationID == "KJV" && positionStore.load() == readOnElsewhere)
    }

    /// The other device read on during a Library lookup with a chapter being read: back to the Library all the same.
    @Test func returningToTheLibraryAfterTheOtherDeviceReadOn() throws {
        let (model, positionStore) = try readingMatthewOne()
        model.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
        positionStore.save(readOnElsewhere)
        model.returnFromLookup()
        #expect(model.screen == .frontPage && model.libraryPlace == david && model.location == matthewThree && !model.isLookingUp)
        #expect(model.translationID == "KJV" && model.selectedBookID == "MAT")
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
        let (empty, _) = try makeModel()
        empty.returnToReader()                                               // nothing being read: nothing
        #expect(empty.screen == .frontPage && empty.location == nil)
    }

    @Test func aPlaceIsTitledByWhatItShows() throws {
        let (model, _) = try makeModel()
        #expect(model.title(for: LibraryPlace(book: "MAT", topic: .places, trail: [.place(636)])) == "Jerusalem")
        #expect(model.title(for: LibraryPlace(book: "MAT", topic: .places)) == "Places in Matthew")
        #expect(model.title(for: LibraryPlace(book: "PSA", topic: .people)) == "People in Psalms")
        #expect(model.title(for: LibraryPlace(book: "MAT", topic: .about)) == "About Matthew")
        #expect(model.title(for: LibraryPlace(book: "MAT", topic: .people, trail: [.person(99)])) == "People in Matthew")
    }
}
