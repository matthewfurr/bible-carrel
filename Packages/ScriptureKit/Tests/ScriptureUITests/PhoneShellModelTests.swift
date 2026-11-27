import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite final class PhoneShellModelTests {
    private let defaultsName = "PhoneShellModelTests-\(UUID().uuidString)"
    /// The fixture, reading Matthew 1 in the WEB.
    private let navigation: NavigationModel

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        navigation = try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults),
                                         defaultTranslationID: "WEB")
        navigation.open(ChapterLocation(book: "MAT", chapter: 1))
    }

    deinit {
        UserDefaults(suiteName: defaultsName)?.removePersistentDomain(forName: defaultsName)
    }

    private func ref(_ book: String, _ chapter: Int, _ verse: Int) -> Reference {
        Reference(book: BookCatalog.book(code: book)!, chapter: chapter, verse: verse)
    }

    @Test func aPlaceIsItsPagesAndBack() {
        let place = LibraryPlace(book: "MAT", topic: .people, trail: [.person(994), .person(903)])
        #expect(place.pages == [.topic(book: "MAT", .people), .entity(book: "MAT", .person(994)), .entity(book: "MAT", .person(903))])
        #expect(LibraryPlace(pages: place.pages + [.passage(ref("MAT", 1, 6))]) == place && LibraryPlace(pages: []) == nil)
        let byName = LibraryPlace(book: nil, topic: .places, trail: [.place(636)])
        #expect(byName.pages == [.entity(book: nil, .place(636))] && LibraryPlace(pages: byName.pages) == byName)
        #expect(LibraryPlace(pages: [.topic(book: "MAT", .about)]) == LibraryPlace(book: "MAT", topic: .about))
    }

    /// A place's page pushed inside Places' sheet is the same place whether the path the sheet sees
    /// starts at Places or at the place; a passage alone is no place.
    @Test func aPlacesSheetPathIsTheSamePlace() {
        let full: [PhoneLibraryPage] = [.topic(book: "MAT", .places), .entity(book: "MAT", .place(636)), .passage(ref("MAT", 2, 1))]
        #expect(LibraryPlace(pages: Array(full.dropFirst())) == LibraryPlace(pages: full))
        #expect(LibraryPlace(pages: [.passage(ref("MAT", 2, 1))]) == nil)
    }

    /// Spec 6.7: the way back names the Library page and reopens it there.
    @Test func theWayBackReopensTheLibraryOrSearch() throws {
        let shell = PhoneShellModel()
        let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
        shell.showInReader()
        #expect(navigation.lookupBackTitle == "David")
        shell.returnFromLookup(navigation)
        #expect(shell.isLibraryShown && navigation.libraryPlace == david && !navigation.isLookingUp)
        shell.showInReader()
        let byName = LibraryPlace(book: nil, topic: .people, trail: [.person(905)])
        shell.searchPath = byName.pages
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: byName)
        shell.returnFromLookup(navigation)
        #expect(shell.tab == .search && !shell.isLibraryShown && shell.searchPath == byName.pages)
        // From a passage pushed in Search (Open in Read is on the passage's page), the way back comes
        // to the person it was opened from, as the Library's does: the passage is not part of the place.
        let walked = LibraryPlace(book: nil, topic: .people, trail: [.person(905), .person(1715)])
        shell.searchPath = walked.pages + [.passage(ref("MAT", 1, 16))]
        navigation.lookUpFromLibrary(ref("MAT", 1, 16), from: walked)
        shell.showInReader()
        shell.returnFromLookup(navigation)
        #expect(shell.tab == .search && shell.searchPath == walked.pages && navigation.libraryPlace == nil)
        shell.tab = .read
        navigation.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 1)      // any other lookup
        shell.returnFromLookup(navigation)
        #expect(shell.tab == .read && !shell.isLibraryShown && navigation.location?.chapter == 1)
    }

    /// Task 5's review, (a): the model's way back shows its front page, which the phone never reads;
    /// the Library opens on the page from `libraryPlace`, its book open in the list. A page reached by
    /// name lives in Search, so the Library keeps no place of it.
    @Test func theLibraryReopensOnThePageAndNotOnTheFrontPage() {
        let shell = PhoneShellModel()
        let john = LibraryPlace(book: "PSA", topic: .about)
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: john)
        shell.showInReader()
        shell.returnFromLookup(navigation)
        #expect(shell.isLibraryShown && navigation.libraryPlace?.pages == [.topic(book: "PSA", .about)])
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 1))
        let list = LibraryList(navigation: navigation)
        #expect(list.openBookID == "PSA" && list.readingBookID == "MAT")
        shell.showInReader()
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: LibraryPlace(book: nil, topic: .people, trail: [.person(905)]))
        shell.returnFromLookup(navigation)
        #expect(navigation.libraryPlace == nil)
    }

    /// Task 5's review, (b): Open from a Library page while a lookup already shows (the phone's
    /// Library opens over the reader) records the passage's book as the chosen book. The phone
    /// ignores the chosen book: the list opens on the Library page's own book.
    @Test func aLibraryLookupDuringALookupOpensTheLibraryOnItsOwnBook() {
        let shell = PhoneShellModel()
        navigation.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 1)
        let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
        shell.returnFromLookup(navigation)
        #expect(shell.isLibraryShown && navigation.libraryPlace == david && navigation.location?.chapter == 1)
        #expect(navigation.selectedBookID != "PSA")
        let list = LibraryList(navigation: navigation)
        #expect(list.testament == .old && list.openBookID == "PSA")
    }

    /// A Library lookup that ends where it is (Read From Here, or reading on) forgets the Library's
    /// place: the next Library opens on the book being read, not on David.
    @Test func aLibraryLookupEndedWhereItIsForgetsTheLibrarysPlace() {
        let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
        navigation.libraryPlace = david
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
        navigation.keepLookup()
        #expect(navigation.libraryPlace == nil && !navigation.isLookingUp)
        #expect(LibraryList(navigation: navigation).openBookID == "MAT")

        navigation.libraryPlace = david
        navigation.lookUpFromLibrary(ref("MAT", 2, 1), from: david)
        navigation.goToNextChapter()
        #expect(navigation.libraryPlace == nil && !navigation.isLookingUp && navigation.location?.chapter == 3)
        let list = LibraryList(navigation: navigation)
        #expect(list.openBookID == "MAT" && list.testament == .new)
    }

    /// ⌘[ during a Library lookup goes the bar's way: the Library reopens on the page.
    @Test func backDuringALibraryLookupReopensTheLibrary() {
        let shell = PhoneShellModel()
        let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
        shell.showInReader()
        shell.goBack(navigation)
        #expect(shell.isLibraryShown && navigation.libraryPlace == david && navigation.location?.chapter == 1 && !navigation.isLookingUp)
        shell.showInReader()
        navigation.lookUp(ChapterLocation(book: "MAT", chapter: 6), verse: 1)      // any other lookup
        shell.goBack(navigation)
        #expect(!shell.isLibraryShown && shell.tab == .read && navigation.location?.chapter == 1)
    }

    /// Spec 6.7, with nothing being read: Open is a lookup, and the way back reopens the Library on
    /// the page with nothing read again.
    @Test func openWithNothingReadReturnsToTheLibrary() throws {
        let name = "PhoneShellModelTests-empty-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let empty = try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults),
                                        defaultTranslationID: "WEB")
        let shell = PhoneShellModel()
        let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
        empty.libraryPlace = david
        empty.lookUpFromLibrary(ref("MAT", 5, 3), from: david)
        shell.showInReader()
        #expect(empty.location?.chapter == 5 && empty.lookupBackTitle == "David")
        shell.returnFromLookup(empty)
        #expect(shell.isLibraryShown && empty.libraryPlace == david && empty.location == nil && !empty.isLookingUp)
    }

    /// About's timeline keeps each entry's passage, which the page scrolls back to.
    @Test func aboutKeepsEachEntrysPassageToComeBackTo() {
        #expect(navigation.bookAbout("MAT")?.timeline.entries.last?.passage != nil)
    }

    @Test func startsOnTheReaderWithNothingOpen() {
        let shell = PhoneShellModel()
        #expect(shell.tab == .read)
        #expect(!shell.isLibraryShown)
        #expect(!shell.isSettingsShown)
        #expect(shell.noteSheet == nil)
        #expect(!shell.isChapterNotesShown)
        #expect(shell.askSheetThreadID == nil)
        #expect(shell.versePreview == nil)
    }

    @Test @MainActor func showInReaderClosesEverySheet() throws {
        let shell = PhoneShellModel()
        shell.tab = .notes
        shell.isLibraryShown = true
        shell.isSettingsShown = true
        shell.noteSheet = UUID()
        shell.isChapterNotesShown = true
        shell.askSheetThreadID = UUID()
        shell.settingsDestination = .reading
        let john = try #require(BookCatalog.book(code: "JHN"))
        shell.versePreview = VersePreview(
            reference: Reference(book: john, chapter: 15, verse: 4), translationID: "WEB", verses: [])

        shell.showInReader()

        #expect(shell.tab == .read)
        #expect(!shell.isLibraryShown)
        #expect(!shell.isSettingsShown)
        #expect(shell.noteSheet == nil)
        #expect(!shell.isChapterNotesShown)
        #expect(shell.askSheetThreadID == nil)
        #expect(shell.versePreview == nil)
        #expect(shell.settingsDestination == nil)
    }

    /// The reader's menu: More Settings… opens Settings at Reading; Settings opens its list.
    /// A tap on a note's mark opens it to read; Add Note and Edit Note open its editor (spec 3.1).
    @Test @MainActor func aNoteOpensToReadOrToEdit() {
        let shell = PhoneShellModel()
        let note = UUID()
        shell.openNote(note, editing: false)
        #expect(shell.noteSheet == note && !shell.noteSheetStartsEditing)
        shell.openNote(note, editing: true)
        #expect(shell.noteSheet == note && shell.noteSheetStartsEditing)
    }

    @Test @MainActor func moreSettingsOpensReading() {
        let shell = PhoneShellModel()
        shell.openMoreSettings()
        #expect(shell.isSettingsShown && shell.settingsDestination == .reading)

        shell.settingsDismissed()
        #expect(!shell.isSettingsShown && shell.settingsDestination == nil)
        shell.openSettings()
        #expect(shell.isSettingsShown && shell.settingsDestination == nil)
    }

    @Test @MainActor func theDatesNoticeOpensGeneralSettings() {
        let shell = PhoneShellModel()
        shell.openGeneralSettings()
        #expect(shell.isSettingsShown && shell.settingsDestination == .general)
        shell.settingsDismissed()
        #expect(!shell.isSettingsShown && shell.settingsDestination == nil)
    }

    @Test @MainActor func showInReaderForgetsTheSettingsPage() {
        let shell = PhoneShellModel()
        shell.openMoreSettings()
        shell.showInReader()
        #expect(!shell.isSettingsShown && shell.settingsDestination == nil)
    }

    /// The bar title reads the page's reports here, so a scroll redraws it and never the reader
    /// screen. Another book forgets the head: the title waits for the new text's report. The
    /// chapter's links are in the page itself, so the phone reads nothing else here.
    @Test @MainActor func theReaderChromeFollowsTheHeadAndForgetsItForAnotherBook() {
        let chrome = ReaderChrome()
        #expect(chrome.head == nil)
        chrome.report(RunningHeadState(chapter: 21, progress: 1, headOpacity: 1))
        #expect(chrome.head?.chapter == 21)
        #expect(chrome.headOpacity(for: 21) == 1 && chrome.headProgress(for: 21) == 1)
        chrome.bookChanged()
        #expect(chrome.head == nil)
        #expect(chrome.headOpacity(for: 21) == 0 && chrome.headProgress(for: 21) == 0)
    }
}

/// Matt, 2026-11-12: "Yes, swipe both directions." The left edge walks Ask → Notes → Plan →
/// Read → Library, the right edge walks back; search is outside the chain.
@Suite struct PhoneEdgeSwipeTests {
    @Test @MainActor func theLeftEdgeWalksTowardTheLibraryAndTheRightTowardAsk() {
        let shell = PhoneShellModel()
        shell.tab = .ask
        #expect(shell.screen == .ask)
        #expect(shell.screen(swipingFrom: .left) == .notes)
        #expect(shell.screen(swipingFrom: .right) == nil)
        shell.tab = .notes
        #expect(shell.screen(swipingFrom: .left) == .plan)
        #expect(shell.screen(swipingFrom: .right) == .ask)
        shell.tab = .plan
        #expect(shell.screen == .plan)
        #expect(shell.screen(swipingFrom: .left) == .read)
        #expect(shell.screen(swipingFrom: .right) == .notes)
        shell.tab = .read
        #expect(shell.screen(swipingFrom: .left) == .library)
        #expect(shell.screen(swipingFrom: .right) == .plan)
        shell.isLibraryShown = true
        #expect(shell.screen == .library)
        #expect(shell.screen(swipingFrom: .left) == nil)
        #expect(shell.screen(swipingFrom: .right) == .read)
    }

    @Test @MainActor func showingAScreenOpensOrClosesLibrary() {
        let shell = PhoneShellModel()
        shell.show(.library)
        #expect(shell.tab == .read && shell.isLibraryShown)
        shell.show(.read)
        #expect(shell.tab == .read && !shell.isLibraryShown)
        shell.show(.ask)
        #expect(shell.tab == .ask && shell.screen == .ask)
        shell.show(.notes)
        #expect(shell.tab == .notes)
        shell.show(.library)
        shell.show(.plan)
        #expect(shell.tab == .plan && shell.screen == .plan && !shell.isLibraryShown)
        #expect(PhoneScreen.allCases == [.library, .read, .plan, .notes, .ask])
    }

    @Test @MainActor func searchIsOutsideTheChain() {
        let shell = PhoneShellModel()
        shell.tab = .search
        #expect(shell.screen == nil)
        #expect(shell.screen(swipingFrom: .left) == nil)
        #expect(shell.screen(swipingFrom: .right) == nil)
    }

    /// Past half the width a release settles; short of it, it springs back; a flick decides
    /// wherever it is let go, either way.
    @Test func aReleaseSettlesPastHalfwayOrOnAFlick() {
        let width: CGFloat = 400
        #expect(EdgeSwipe.settles(travel: 201, speed: 0, width: width))
        #expect(!EdgeSwipe.settles(travel: 199, speed: 0, width: width))
        #expect(EdgeSwipe.settles(travel: 40, speed: 300, width: width))
        #expect(!EdgeSwipe.settles(travel: 360, speed: -300, width: width))
        #expect(!EdgeSwipe.settles(travel: 300, speed: 0, width: 0))
        #expect(EdgeSwipe.clampedTravel(-20, width: width) == 0)
        #expect(EdgeSwipe.clampedTravel(500, width: width) == width)
    }

    @Test @MainActor func goingBackToThePageClosesAVersePanelToo() {
        let selection = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, quotedText: "Blessed")
        let report = SelectionReport(selection: selection, range: NSRange(location: 0, length: 7), highlightIDs: [])
        let shell = PhoneShellModel()
        shell.versePanel = VersePanelRequest(kind: .compare, report: report)
        shell.queuedVersePanelAsk = {}
        shell.showInReader()
        #expect(shell.versePanel == nil)
        #expect(shell.queuedVersePanelAsk == nil)
        #expect(shell.tab == .read)
    }

    /// The selection menu's Compare Translations or Cross-References: the sheet for the new request, and
    /// an Ask still queued from an earlier sheet is dropped, so the next Done cannot send it.
    @Test @MainActor func aNewVersePanelDropsAQueuedAsk() {
        let selection = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, quotedText: "Blessed")
        let report = SelectionReport(selection: selection, range: NSRange(location: 0, length: 7), highlightIDs: [])
        let shell = PhoneShellModel()
        shell.queuedVersePanelAsk = {}
        let request = VersePanelRequest(kind: .crossReferences, report: report)
        shell.showVersePanel(request)
        #expect(shell.versePanel == request && shell.queuedVersePanelAsk == nil)
    }
}

#if os(iOS)
/// The phone Library's own rules: which pages its stack shows, which books have views, when hiding
/// it forgets the page, and what a stack reopened on a page brings back.
@MainActor @Suite final class PhoneLibraryRulesTests {
    private let defaultsName = "PhoneLibraryRulesTests-\(UUID().uuidString)"
    private let navigation: NavigationModel

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        navigation = try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults),
                                         defaultTranslationID: "WEB")
        navigation.open(ChapterLocation(book: "MAT", chapter: 1))
    }

    deinit {
        UserDefaults(suiteName: defaultsName)?.removePersistentDomain(forName: defaultsName)
    }

    private func ref(_ book: String, _ chapter: Int, _ verse: Int) -> Reference {
        Reference(book: BookCatalog.book(code: book)!, chapter: chapter, verse: verse)
    }

    /// Close, a chapter or a swipe forgets the page; a lookup opened from the page keeps it.
    @Test func hidingTheLibraryForgetsThePageUnlessALookupLeftIt() {
        let david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
        navigation.libraryPlace = david
        #expect(!PhoneLibraryLayer.isLeftForALookup(navigation))
        navigation.lookUpFromLibrary(ref("MAT", 5, 3), from: david.opening(ref("PSA", 18, 50)))
        #expect(PhoneLibraryLayer.isLeftForALookup(navigation))
        navigation.libraryPlace = LibraryPlace(book: "PSA", topic: .people, trail: [.person(903)])
        #expect(!PhoneLibraryLayer.isLeftForALookup(navigation))
    }

    /// Library's stack shows the path as far as Places; the sheet's pages are Places' own.
    @Test func theStackStopsAtPlaces() {
        let people: [PhoneLibraryPage] = [.topic(book: "MAT", .people), .entity(book: "MAT", .person(994)), .passage(ref("MAT", 1, 6))]
        #expect(PhoneLibraryScreen.stackPages(of: people) == people)
        let places: [PhoneLibraryPage] = [.topic(book: "MAT", .places), .entity(book: "MAT", .place(636)), .passage(ref("MAT", 2, 1))]
        #expect(PhoneLibraryScreen.stackPages(of: places) == [.topic(book: "MAT", .places)])
        #expect(PhoneLibraryScreen.stackPages(of: []) == [])
    }

    @Test func theApocryphaHasNoViews() throws {
        #expect(PhoneLibraryScreen.topics(of: try #require(BookCatalog.book(code: "TOB"))).isEmpty)
        #expect(PhoneLibraryScreen.topics(of: try #require(BookCatalog.book(code: "JHN"))) == [.people, .places, .about])
    }

    /// A stack reopened on a person, a place or About brings back the reference opened from it,
    /// and the person's books opened and closed; any other page has no anchor.
    @Test func aReopenedPageBringsBackItsAnchorAndOpenBooks() {
        var david = LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)])
        david.toggledBooks = ["1SA"]
        let opened = david.opening(ref("PSA", 18, 50))
        let memory = PhoneLibraryPageMemory(opening: opened)
        let page = PhoneLibraryPage.entity(book: "PSA", .person(994))
        #expect(memory.anchor(for: page) == ref("PSA", 18, 50) && memory.anchor(for: .topic(book: "PSA", .people)) == nil)
        #expect(memory.place(for: opened.pages)?.toggledBooks == ["1SA"])
        let about = PhoneLibraryPageMemory(opening: LibraryPlace(book: "MAT", topic: .about).opening(ref("MAT", 2, 1)))
        #expect(about.anchor(for: .topic(book: "MAT", .about)) == ref("MAT", 2, 1))
        #expect(PhoneLibraryPageMemory(opening: nil).anchor(for: page) == nil)
    }

    /// Review Focus 1: a lookup's return keeps the chosen chapter (Departure 12): the memory takes it from the place
    /// it opens on and writes it back for the path's book.
    @Test func thePhonesMemoryKeepsTheChapterAcrossALookup() {
        var place = LibraryPlace(book: "MAT", topic: .places, trail: [.place(882)])
        place.placesChapter = 4
        let memory = PhoneLibraryPageMemory(opening: place.opening(ref("MAT", 4, 13)))
        #expect(memory.placesChapters["MAT"] == 4)
        #expect(memory.place(for: place.pages)?.placesChapter == 4)
        #expect(PhoneLibraryPageMemory(opening: nil).placesChapters.isEmpty)
        #expect(memory.place(for: LibraryPlace(book: "ACT", topic: .places).pages)?.placesChapter == nil)
        #expect(PhoneLibraryPageMemory(opening: LibraryPlace(book: "ACT", topic: .places)).placesChapters["ACT"] == nil)
    }
}
#endif
