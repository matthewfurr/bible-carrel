import Foundation
import Observation
import OSLog
import ScriptureData

public enum Screen: Equatable, Sendable {
    case frontPage
    case reader
}

public struct ReadingPlace: Equatable, Sendable {
    public let location: ChapterLocation
    public let verse: Int
    public let translationID: String
}

/// Everything a palette search depends on: the views search again when it changes.
public struct PaletteSearchKey: Equatable, Sendable {
    public let query: String
    public let translationID: String
    public let scope: SearchScope
    public let order: SearchOrder
    public let chip: SearchChip?
    public let limits: SearchLimits
    /// The translations alone are showing (Switch Translation…).
    public let choosingTranslation: Bool
}

/// What Scripture is asked for one search; `suggests` when a near spelling may be offered. The
/// people and places found by the typed name ride with it, up to their limits.
struct ScriptureRequest: Equatable, Sendable {
    let query: SearchQuery
    let translationID: String
    let scope: SearchScope
    let order: SearchOrder
    let limit: Int
    let suggests: Bool
    var peopleLimit = 0
    var placesLimit = 0
}

/// Scripture's verses for one request and, when they are none, a near spelling that finds some;
/// and the people and places whose names the words start.
struct ScriptureAnswer: Equatable, Sendable {
    let page: SearchPage
    let suggestion: SearchSuggestion?
    var people: NameMatches<PersonSummary> = .none
    var places: NameMatches<PlaceSummary> = .none
}

/// The app's navigation state: which screen, which chapter in which translation, history,
/// the ⌘K palette, and the persisted reading position.
@MainActor @Observable
public final class NavigationModel {
    public private(set) var screen: Screen = .frontPage
    public private(set) var translationID: String
    public private(set) var translations: [Translation] = []
    public private(set) var books: [TranslationBook] = []

    /// How many chapters the translation being read gives `book` (a book code); nil when it lacks it.
    public func chapterCount(ofBook book: String) -> Int? {
        books.first { $0.book.id == book }?.chapterCount
    }

    /// The translation being read's last verse of each of `book`'s chapters (a book code), by chapter; empty when it
    /// lacks the book or the read fails. A dictionary entry's references are linked only where the verse is there.
    /// Read once per translation and book: a person's page asks for the books its entry cites each time it opens.
    public func lastVerses(ofBook book: String) -> [Int: Int] {
        let key = "\(translationID)/\(book)"
        if let known = knownLastVerses[key] { return known }
        let last = (try? store.lastVerses(ofBook: book, translationID: translationID)) ?? [:]
        knownLastVerses[key] = last
        return last
    }

    /// `lastVerses` by "translation/book": at most a few hundred small tables, never stale (a translation's text is fixed).
    @ObservationIgnored private var knownLastVerses: [String: [Int: Int]] = [:]

    /// The verses `reference` names in the translation being read, for a reference tapped in a
    /// note; nil when it has none.
    public func versePreview(_ reference: Reference) -> VersePreview? {
        try? VersePreview.load(reference, translationID: translationID, store: store)
    }

    // The Library's pages, each read from the model's own store (About in the translation being read);
    // nil when the read fails or there is nothing to show.

    /// Whether the Library has a page for `book`: one of the 66.
    public func hasLibraryData(for book: String) -> Bool {
        BookCatalog.book(code: book).map { $0.canon != .apocrypha } ?? false
    }

    /// `store.bookTitle`'s subtitle for `book` in the translation being read.
    public func bookSubtitle(_ book: String) -> String? {
        (try? store.bookTitle(bookID: book, translationID: translationID))?.subtitle
    }

    public func bookPeople(_ book: String) -> BookPeople? {
        try? BookPeople.load(book: book, store: store)
    }

    /// A person's page for the book, or for the whole Bible when `book` is nil.
    public func personPage(_ id: Int, inBook book: String?) -> PersonPage? {
        try? PersonPage.load(id, inBook: book, store: store)
    }

    public func bookPlaces(_ book: String) -> BookPlaces? {
        try? BookPlaces.load(book: book, store: store)
    }

    /// A place's page for the book, or for the whole Bible when `book` is nil.
    public func placePage(_ id: Int, inBook book: String?) -> PlacePage? {
        try? PlacePage.load(id, inBook: book, store: store)
    }

    public func bookAbout(_ book: String) -> BookAbout? {
        try? BookAbout.load(book: book, translationID: translationID, store: store)
    }

    /// What `verse` points to and what points to it, in the translation being read; nil when the read fails.
    public func crossReferences(for verse: VerseLocation) -> CrossReferences? {
        try? CrossReferences.load(verse, translationID: translationID, store: store)
    }

    /// What Ask About These sends for `references`; nil when the read fails.
    public func crossReferenceQuestion(_ references: CrossReferences) -> String? {
        try? references.question(store: store)
    }

    /// The selection's verses in the translation being read and each of `compareSet`; nil when the read fails.
    public func verseComparison(for selection: TextSelection, compareSet: [String]) -> VerseComparison? {
        try? VerseComparison.load(selection: selection, readingTranslationID: translationID, compareSet: compareSet,
                                  translations: translations, store: store)
    }
    /// The open chapter: the reader shows one chapter at a time.
    public private(set) var location: ChapterLocation? {
        didSet { updateCanGo() }
    }
    /// The open chapter's verses (`bookText.chapters[location.chapter]`).
    public private(set) var verses: [Verse] = []
    /// The whole book being read, in the translation being read; reloaded only when the book or
    /// the translation changes, not for each chapter opened in it.
    public private(set) var bookText: BookText?
    public private(set) var scrollTarget: ScrollTarget?
    /// The book shown in the front page's chapter grid.
    public var selectedBookID: String?
    /// Cleared (only white space left), the scope returns to the whole Bible and the chip to All,
    /// so the empty state shows Recent as well as Commands.
    public var paletteQuery = "" {
        didSet {
            // Typing returns from the translations to the whole list.
            if isChoosingTranslation, paletteQuery != oldValue { isChoosingTranslation = false }
            if paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                returnToTheWholeBible()
                if paletteChip != nil { paletteChip = nil }
            }
        }
    }
    /// The rows shown, in the order Return and the arrow keys move through: computed, so they are
    /// the chosen chip's the moment it changes, before the refresh ranks with its limits.
    public var paletteItems: [PaletteItem] { paletteResults.showing(paletteChip).flatItems }
    /// The palette's query results, grouped.
    public private(set) var paletteResults: SearchResults = .empty
    /// The Mac's ⌘K panel. Every way it closes (Esc, a click outside, ⌘K, a row chosen, a passage
    /// link) comes through here and leaves it with no words and no results, so it always opens on
    /// Recent and Commands. Each time it opens, the scope returns to the whole Bible and the chip
    /// to All. The phone's search tab never shows it, so nothing here clears the phone's words.
    public var isPaletteShown = false {
        didSet {
            if !isPaletteShown, isChoosingTranslation { isChoosingTranslation = false }
            if !isPaletteShown, oldValue { clearPalette() }
            guard isPaletteShown, !oldValue else { return }
            returnToTheWholeBible()
            if paletteChip != nil { paletteChip = nil }
        }
    }
    /// Where Scripture is searched; the other groups are not narrowed.
    public var searchScope: SearchScope = .wholeBible
    /// The order Scripture's verses come in, kept until the app quits.
    public var searchOrder: SearchOrder = .bestMatch
    /// The Mac's chosen chip; nil is All. While one is chosen the search uses `SearchLimits.paletteChip`.
    public var paletteChip: SearchChip?
    /// Switch Translation… was chosen: the palette shows the translations alone until Esc or typing.
    public private(set) var isChoosingTranslation = false
    /// How many times Text & Layout was asked for by the palette; the window shows it when this changes.
    public private(set) var textLayoutRequests = 0
    /// The keyboard shortcuts sheet (? in the reader, ⌘/).
    public var isShortcutsShown = false
    /// Every one of the reader's notes, highlights, bookmarks and conversations, unfiltered, for
    /// search to match (the app wires the markup store).
    public var markSearch: (() -> [NotesBrowserEntry])?
    /// How many rows each search group shows.
    public var searchLimits: SearchLimits = .palette
    /// Whether search offers the app's commands.
    public var includesCommandsInSearch = true
    /// Shows a note's target in the reader with its highlight focused; without it the chapter just opens.
    public var showTarget: ((MarkupTarget) -> Void)?
    /// Runs a palette command the model does not (the app's windows, settings and assistant).
    public var performCommand: ((PaletteCommand) -> Void)?
    /// The app's half of what decides which commands can run now (the stored settings, the assistant).
    public var appPaletteState: (() -> PaletteState)?
    /// False while the app is in the background, when a position from another device is always taken.
    @ObservationIgnored public var isAppActive = true
    /// The place being read while a looked-up passage is showing (`lookUp`); nil otherwise. While
    /// it is set the stored position is not written (except to carry a translation chosen during a
    /// jump inside its chapter) and a position from another device is not taken until it ends.
    public private(set) var lookupReturn: ReadingPlace? {
        didSet {
            if lookupReturn == nil { lookupSharesThePlaceEntry = false }
            updateCanGo()
        }
    }
    /// Where the reader is in the Library; nil is the contents. Kept here so it outlives the reader
    /// showing, and not stored: a relaunch opens on the contents.
    public var libraryPlace: LibraryPlace?
    /// What a lookup begun in the Library returns to (`lookUpFromLibrary`); nil otherwise. Set with
    /// no `lookupReturn` when nothing was being read: the passage is then not a place being read.
    public private(set) var libraryReturn: LibraryReturn? {
        didSet { updateCanGo() }
    }
    /// The translation being read when a lookup with nothing being read began, put back when it
    /// returns to the Library; one chosen meanwhile (`setTranslation`) replaces it.
    @ObservationIgnored private var libraryLookupTranslationID: String?
    /// True while the lookup showing has no history entry of its own (a jump inside the chapter
    /// being read, or that chapter in another translation): the history's current entry is still
    /// the place's, so Back returns from the lookup and the entry's verse is put back to the
    /// place's before the history moves off it.
    @ObservationIgnored private var lookupSharesThePlaceEntry = false
    /// The stored position when the lookup began. Nothing local writes it during a lookup, so a
    /// stored position that differs from this one on return is where the other device read on to.
    @ObservationIgnored private var storedAtLookupStart: ReadingPosition?
    /// True once the reader has navigated or scrolled in this session; restoring the stored
    /// position at launch and adopting one from another device do not count.
    @ObservationIgnored public private(set) var hasMovedThisSession = false

    private let store: BibleStore
    private let positionStore: ReadingPositionStore
    /// Where the reader went lately, kept on this device; nil records nothing.
    public let recents: RecentsStore?
    /// Not observed: the reader reports the verse at the top on almost every scroll frame, and
    /// each report rewrites the history's current verse. Views read only `canGoBack` and
    /// `canGoForward`, which are stored and change only when the stacks do; observing the history
    /// itself re-evaluated the window and the app's menus once per frame while scrolling.
    @ObservationIgnored private var history = NavigationHistory() {
        didSet { updateCanGo() }
    }
    @ObservationIgnored private var firstVisibleVerse = 1
    /// Whether the reader has reported a top verse since the chapter was shown: its first report
    /// is where the page landed, not a move.
    @ObservationIgnored private var hasReportedSinceShow = false
    /// What `paletteItems` were ranked for.
    @ObservationIgnored private var rankedSearchKey: PaletteSearchKey?
    /// Scripture for one request: the store's search and suggestion through `offMain`. A test
    /// replaces it to hold one open.
    @ObservationIgnored var scriptureSearch: @Sendable (ScriptureRequest) async -> ScriptureAnswer
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "navigation")

    /// `defaultTranslationID` is the user's chosen default (Settings → General); `fallbackTranslationID`
    /// is the app's own (ESV) for when that one is not bundled.
    public init(
        store: BibleStore,
        positionStore: ReadingPositionStore,
        recents: RecentsStore? = nil,
        defaultTranslationID: String = "ESV",
        fallbackTranslationID: String = "ESV"
    ) throws {
        self.store = store
        self.positionStore = positionStore
        self.recents = recents
        scriptureSearch = { request in
            await NavigationModel.offMain { NavigationModel.answer(to: request, from: store) }
        }
        let available = try store.translations()
        translations = available
        // The last chosen translation wins, then the default, then ESV, then whatever is bundled.
        let preferred = [positionStore.loadTranslationID(), defaultTranslationID, fallbackTranslationID].compactMap { $0 }
        translationID = preferred.first { id in available.contains { $0.id == id } } ?? available.first?.id ?? defaultTranslationID
        reloadBooks()
        restoreStoredPosition()
    }

    // MARK: - Derived state

    public private(set) var canGoBack = false
    public private(set) var canGoForward = false

    /// Back also returns from a lookup in the chapter being read, which has no history entry of
    /// its own, and from a Library lookup with nothing being read. Assigned only on a change, so
    /// scroll reports invalidate nothing.
    private func updateCanGo() {
        let back = history.canGoBack || isLookingUpReturnChapter || isLookingUpWithNothingRead
        if canGoBack != back { canGoBack = back }
        if canGoForward != history.canGoForward { canGoForward = history.canGoForward }
    }

    /// A lookup showing the return place's own chapter (a jump inside it, or it in another translation).
    private var isLookingUpReturnChapter: Bool {
        lookupReturn.map { $0.location == location } ?? false
    }

    /// A lookup is showing, with or without a place being read to return to.
    public var isLookingUp: Bool { lookupReturn != nil || libraryReturn != nil }

    /// A lookup begun in the Library with nothing being read: it returns to the Library alone.
    private var isLookingUpWithNothingRead: Bool { libraryReturn != nil && lookupReturn == nil }

    /// The way back's name: the Library page a lookup began on, else the return place's chapter.
    public var lookupBackTitle: String? {
        libraryReturn.map { title(for: $0.place) } ?? lookupReturnTitle
    }

    /// A Library page's name: the person or place showing ("Simon Peter", "Bethany"), else the
    /// book's view ("People in John", "Places in John", "About John").
    public func title(for place: LibraryPlace) -> String {
        switch place.showing {
        case .person(let id): if let name = (try? store.person(id))?.name { return name }
        case .place(let id): if let name = (try? store.place(id))?.summary.name { return name }
        case nil: break
        }
        let book = place.book.map { BookCatalog.book(code: $0)?.name ?? $0 }
        switch place.topic {
        case .people: return book.map { "People in \($0)" } ?? "People"
        case .places: return book.map { "Places in \($0)" } ?? "Places"
        case .about: return book.map { "About \($0)" } ?? "About"
        }
    }

    public var chapterTitle: String? {
        location.map(title(for:))
    }

    /// The return place's chapter, as "John 15".
    public var lookupReturnTitle: String? {
        lookupReturn.map { title(for: $0.location) }
    }

    public func title(for location: ChapterLocation) -> String {
        "\(BookCatalog.book(code: location.book)?.chapterName ?? location.book) \(location.chapter)"
    }

    /// The book thumb for the open chapter: the chapters the translation being read has of its
    /// book, with the open one lit. Nil with no chapter open (or before its book has loaded).
    public var bookThumb: BookThumb? {
        guard let location, let bookText, bookText.book == location.book else { return nil }
        return BookThumb(chapters: bookText.chapters.keys.sorted(), current: location.chapter)
    }

    public var nextChapter: ChapterLocation? {
        guard let location, let index = books.firstIndex(where: { $0.book.id == location.book }) else { return nil }
        if location.chapter < books[index].chapterCount {
            return ChapterLocation(book: location.book, chapter: location.chapter + 1)
        }
        guard books.indices.contains(index + 1) else { return nil }
        return ChapterLocation(book: books[index + 1].book.id, chapter: 1)
    }

    /// The first chapter of the book after the one being read, for the end-of-book link; nil in
    /// the translation's last book.
    public var nextBook: ChapterLocation? {
        nextBookEntry.map { ChapterLocation(book: $0.book.id, chapter: 1) }
    }

    /// The next book's name, as "Acts".
    public var nextBookTitle: String? {
        nextBookEntry?.book.name
    }

    private var nextBookEntry: TranslationBook? {
        guard let location, let index = books.firstIndex(where: { $0.book.id == location.book }),
              books.indices.contains(index + 1)
        else { return nil }
        return books[index + 1]
    }

    /// The last chapter of the book before the one being read, wherever in this book the reader
    /// is; nil in the translation's first book.
    public var previousBookEnd: ChapterLocation? {
        guard let location, let index = books.firstIndex(where: { $0.book.id == location.book }), index > 0 else { return nil }
        return ChapterLocation(book: books[index - 1].book.id, chapter: books[index - 1].chapterCount)
    }

    public var previousChapter: ChapterLocation? {
        guard let location, let index = books.firstIndex(where: { $0.book.id == location.book }) else { return nil }
        if location.chapter > 1 {
            return ChapterLocation(book: location.book, chapter: location.chapter - 1)
        }
        guard index > 0 else { return nil }
        return ChapterLocation(book: books[index - 1].book.id, chapter: books[index - 1].chapterCount)
    }

    // MARK: - Navigation

    /// Opens a chapter the reader chose, and records it as read.
    public func open(_ location: ChapterLocation, verse: Int? = nil) {
        guard openWithoutRecording(location, verse: verse) else { return }
        recents?.record(.chapter(location), translationID: translationID)
    }

    /// `open` for what is not a choice of place (Next, Previous, a lookup from the front page);
    /// false, with nothing changed, for a chapter the translation lacks.
    @discardableResult private func openWithoutRecording(_ location: ChapterLocation, verse: Int?) -> Bool {
        guard isAvailable(location) else {
            logger.warning("Ignoring unavailable location \(location.book) \(location.chapter) in \(self.translationID)")
            return false
        }
        hasMovedThisSession = true
        // Reading on from a lookup makes it the place.
        endLookupHere()
        // A chapter chosen from the grid or a reference starts at its first verse, even when it is
        // the chapter being read; Home alone never moves the stored place.
        go(to: location, verse: verse)
        return true
    }

    /// Turns to a neighbouring chapter as `open` does (a lookup ends, history is pushed), landing at
    /// its first verse, or with its foot at the bottom of the page (`atEnd`, a turn back).
    public func turn(to location: ChapterLocation, atEnd: Bool) {
        guard isAvailable(location) else {
            logger.warning("Ignoring unavailable location \(location.book) \(location.chapter) in \(self.translationID)")
            return
        }
        hasMovedThisSession = true
        endLookupHere()
        history.go(to: location)
        show(location, verse: nil, atEnd: atEnd)
        history.updateCurrentVerse(firstVisibleVerse)
    }

    /// Takes the stored position another device wrote, in its translation and through the history
    /// as a navigation does, unless the reader has moved while the app is active. Ignored during a
    /// lookup (one from the Library with nothing being read too), when its translation is not
    /// bundled, when that translation lacks the chapter (the translation being read is kept), or
    /// when it is already what is shown.
    public func adoptStoredPosition() {
        guard !isLookingUp,
              !isAppActive || !hasMovedThisSession,
              let stored = positionStore.load(),
              stored.translationID != translationID
                || stored.chapterLocation != location
                || stored.firstVisibleVerse != firstVisibleVerse,
              switchTranslation(toStored: stored.translationID, keepingIfLacks: stored.chapterLocation)
        else { return }
        go(to: stored.chapterLocation, verse: stored.firstVisibleVerse)
    }

    /// Opens a chapter in a given translation (a bundled one; others are ignored), for items made
    /// in a translation other than the one being read.
    public func open(_ location: ChapterLocation, verse: Int?, translationID: String?) {
        if let translationID { setTranslation(translationID) }
        openWithoutRecording(location, verse: verse)
    }

    public func open(_ reference: Reference) {
        open(ChapterLocation(book: reference.book.id, chapter: reference.chapter ?? 1), verse: reference.verse)
    }

    // MARK: - Lookups

    /// Shows a passage through the history as `open` does, without moving the place being read:
    /// the stored position stays where it was until the reader reads on from the passage (the
    /// chapter links, a chapter chosen to read) or keeps it (`keepLookup`). The first lookup
    /// remembers the place to return to; a lookup in another translation switches to it without
    /// making it the chosen one. From the front page, with nothing being read, it is an `open`. A
    /// jump inside the chapter being read is a lookup too, with no history entry of its own (Back
    /// returns from it); in the translation being read it also ends once the reader scrolls on
    /// from it (`reportLinesScrolledSinceJump`). During a Library lookup with nothing being read
    /// it shows the passage through the history and still remembers no place.
    public func lookUp(_ location: ChapterLocation, verse: Int?, translationID: String? = nil) {
        if isLookingUpWithNothingRead {
            showWithNothingRead(location, verse: verse, translationID: translationID)
            return
        }
        guard let current = self.location else {
            open(location, verse: verse, translationID: translationID)   // not recorded
            return
        }
        let place = ReadingPlace(location: current, verse: firstVisibleVerse, translationID: self.translationID)
        if let translationID, translationID != self.translationID {
            _ = switchTranslation(toStored: translationID, keepingIfLacks: location)
        }
        guard isAvailable(location) else {
            logger.warning("Ignoring unavailable location \(location.book) \(location.chapter) in \(self.translationID)")
            return
        }
        // `go` pushes no entry for the chapter the history is already on.
        let sharesEntry = (lookupReturn == nil || lookupSharesThePlaceEntry) && history.current == location
        if !sharesEntry { restoreSharedPlaceEntry() }
        lookupSharesThePlaceEntry = sharesEntry
        if lookupReturn == nil {
            storedAtLookupStart = positionStore.load()
            lookupReturn = place
        }
        hasMovedThisSession = true
        go(to: location, verse: verse)
    }

    /// A reference's Open (a cross-reference's passage shown in its panel): the passage as a lookup
    /// in the translation being read, recorded as looked up. A reference without a chapter does nothing.
    public func lookUpPassage(_ reference: Reference) {
        guard let chapter = reference.chapter else { return }
        let location = ChapterLocation(book: reference.book.id, chapter: chapter)
        lookUp(location, verse: reference.verse)
        recordLookup(location, verse: reference.verse)
    }

    /// Open on a passage in the Library: a lookup that returns to `place` and the book chosen on
    /// the front page, recorded as looked up. With a chapter being read it is `lookUp`. With
    /// nothing being read the passage shows through the history but is no place being read:
    /// nothing is stored and no chapter is recorded as read until the reader reads on from it or
    /// keeps it. A passage the translation being read lacks changes nothing.
    public func lookUpFromLibrary(_ reference: Reference, from place: LibraryPlace) {
        let location = ChapterLocation(book: reference.book.id, chapter: reference.chapter ?? 1)
        guard isAvailable(location) else {
            logger.warning("Ignoring unavailable location \(location.book) \(location.chapter) in \(self.translationID)")
            return
        }
        let back = LibraryReturn(place: place, chosenBookID: selectedBookID)
        if self.location != nil, !isLookingUpWithNothingRead {
            lookUp(location, verse: reference.verse)
            libraryReturn = back
        } else {
            if libraryReturn == nil {
                // The history of a reader with nothing open is stale: Back walks this lookup's passages alone.
                libraryLookupTranslationID = translationID
                history = NavigationHistory()
            }
            libraryReturn = back
            showWithNothingRead(location, verse: reference.verse, translationID: nil)
        }
        recordLookup(location, verse: reference.verse)
    }

    /// A passage during a Library lookup with nothing being read: through the history, in
    /// `translationID` when it has the chapter (without choosing it), and never stored.
    private func showWithNothingRead(_ location: ChapterLocation, verse: Int?, translationID: String?) {
        if let translationID, translationID != self.translationID {
            _ = switchTranslation(toStored: translationID, keepingIfLacks: location)
        }
        guard isAvailable(location) else {
            logger.warning("Ignoring unavailable location \(location.book) \(location.chapter) in \(self.translationID)")
            return
        }
        hasMovedThisSession = true
        go(to: location, verse: verse)
    }

    /// Typing in the front page's search field returns a Library view to the contents, where the
    /// search shows; clearing the field leaves the view as it is.
    public func frontPageSearchChanged(to text: String) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { libraryPlace = nil }
    }

    /// A person or place chosen by name: returns from any lookup, then shows the front page on
    /// `place`. The book chosen on the front page is left as it is.
    public func showInLibrary(_ place: LibraryPlace) {
        returnFromLookup()
        libraryPlace = place
        screen = .frontPage
    }

    /// The page being read, at its verse (the reader re-targets it as it appears); nothing with
    /// nothing being read.
    public func returnToReader() {
        guard location != nil else { return }
        screen = .reader
    }

    /// Records a passage a reference led to as looked up; called beside the `lookUp` that showed it.
    /// Nothing is recorded for a chapter the translation being read lacks.
    public func recordLookup(_ location: ChapterLocation, verse: Int?) {
        guard isAvailable(location) else { return }
        recents?.record(.lookup(location, verse: verse), translationID: translationID)
    }

    /// Back to the place being read, at its verse and in its translation; the stored position is
    /// left as it was. When the other device read on while the lookup was showing, back to where
    /// it read on to instead (`returnToWhereReadElsewhere`). A lookup begun in the Library then
    /// shows the Library as it was; with nothing being read it returns there at once.
    public func returnFromLookup() {
        guard let place = lookupReturn else {
            if isLookingUpWithNothingRead { returnToLibraryWithNothingRead() }
            return
        }
        if returnToWhereReadElsewhere() { return }
        _ = switchTranslation(toStored: place.translationID, keepingIfLacks: place.location)
        if isAvailable(place.location) {
            hasMovedThisSession = true
            // Put back the place's verse, which scrolling a jump inside its chapter rewrote.
            restoreSharedPlaceEntry()
            go(to: place.location, verse: place.verse)
        }
        lookupReturn = nil
        returnToLibrary()
    }

    /// The end of a lookup by going back: one begun in the Library puts back its place and the
    /// book chosen on the front page, and shows the front page. A book the translation now lacks
    /// closes the view and a book it has is chosen.
    private func returnToLibrary() {
        guard let back = libraryReturn else { return }
        libraryReturn = nil
        libraryLookupTranslationID = nil
        libraryPlace = back.place
        selectedBookID = back.chosenBookID
        screen = .frontPage
        fitTheLibraryToTheTranslation()
    }

    /// The end of a Library lookup with nothing being read: no chapter open, an empty history and
    /// the translation it began in, then the Library as it was.
    private func returnToLibraryWithNothingRead() {
        location = nil
        verses = []
        bookText = nil
        scrollTarget = nil
        history = NavigationHistory()
        if let id = libraryLookupTranslationID, id != translationID, translations.contains(where: { $0.id == id }) {
            translationID = id
            reloadBooks()
            fitTheScopeToTheTranslation()
        }
        returnToLibrary()
    }

    /// A Library place whose book the translation lacks is closed; a chosen book it lacks gives
    /// way to the book being read, else the translation's first.
    private func fitTheLibraryToTheTranslation() {
        func has(_ book: String?) -> Bool { books.contains { $0.book.id == book } }
        if let place = libraryPlace, let book = place.book, !has(book) { libraryPlace = nil }
        if !has(selectedBookID) {
            selectedBookID = has(location?.book) ? location?.book : books.first?.book.id
        }
    }

    /// Ends a lookup at the stored position, in its translation and through the history, when it
    /// is no longer what was stored as the lookup began (the other device read on) and can be
    /// shown; false otherwise, with nothing changed.
    private func returnToWhereReadElsewhere() -> Bool {
        guard lookupReturn != nil,
              let stored = positionStore.load(), stored != storedAtLookupStart,
              switchTranslation(toStored: stored.translationID, keepingIfLacks: stored.chapterLocation)
        else { return false }
        hasMovedThisSession = true
        restoreSharedPlaceEntry()
        go(to: stored.chapterLocation, verse: stored.firstVisibleVerse)
        lookupReturn = nil
        returnToLibrary()
        return true
    }

    /// Before the history moves off an entry a lookup shares with the place (one with no entry of
    /// its own), puts that entry's verse back to the place's, which scrolling the lookup rewrote,
    /// and stops sharing it: the place stays in the history for Back to return to.
    private func restoreSharedPlaceEntry() {
        guard lookupSharesThePlaceEntry else { return }
        lookupSharesThePlaceEntry = false
        guard let place = lookupReturn, history.current == place.location else { return }
        history.updateCurrentVerse(place.verse)
    }

    /// How far, in lines of body text, the reader scrolls from where a jump inside the chapter
    /// being read landed before that jump becomes the place being read.
    nonisolated public static let linesThatKeepAJump: Double = 5

    /// The reader's report of how far the page has scrolled since the last jump landed, in lines
    /// of body text at the current size, either direction.
    /// While a jump inside the chapter being read (in its translation) is showing, scrolling
    /// `linesThatKeepAJump` or more from where it landed makes it the place, as `keepLookup` does.
    /// Called on every scroll, so it is cheap and changes nothing until then; any other lookup
    /// ignores it. `target` is the scroll target the reader measured from: a report measured from
    /// an earlier landing (one sent before the reader has taken the jump's target) is ignored.
    /// A Library lookup is never ended by scrolling, even into the chapter being read: it ends by
    /// Back, Next or Previous, or Read From Here, and until then the stored verse stays where it was.
    public func reportLinesScrolledSinceJump(_ lines: Double, from target: ScrollTarget) {
        guard libraryReturn == nil else { return }
        guard abs(lines) >= Self.linesThatKeepAJump, target == scrollTarget, let place = lookupReturn,
              place.location == location, place.translationID == translationID
        else { return }
        keepLookup()
    }

    /// Read From Here: the passage being looked at becomes the place being read.
    public func keepLookup() {
        guard isLookingUp else { return }
        endLookupHere()
        if let location { savePosition(location) }
    }

    /// Ends a lookup where it is, keeping a translation it switched to as the chosen one (as
    /// opening an item in its translation does). A Library lookup ends with it: nothing returns
    /// to the Library, and its place is forgotten (the phone's Library would otherwise reopen on a
    /// page nobody is coming back to; the Mac reaches the front page only by Home, which forgets it too).
    /// Scrolling never brings a Library lookup here (`reportLinesScrolledSinceJump`).
    private func endLookupHere() {
        let begunIn = lookupReturn?.translationID ?? libraryLookupTranslationID
        guard isLookingUp else { return }
        if libraryReturn != nil { libraryPlace = nil }
        lookupReturn = nil
        libraryReturn = nil
        libraryLookupTranslationID = nil
        if let begunIn, begunIn != translationID { positionStore.save(translationID: translationID) }
    }

    /// Re-targets the reader at the last visible verse, for a reader view that is recreated
    /// (returning from Home, reopening the window) and would otherwise replay the stale jump target.
    public func resumeReading() {
        guard let location else { return }
        scrollTarget = ScrollTarget(chapter: location.chapter, verse: firstVisibleVerse)
    }

    /// During a lookup, returns to the place being read first; one begun in the Library shows
    /// the Library as it was. Otherwise the contents, with the book being read chosen (4.4).
    public func goHome() {
        let returnsToLibrary = libraryReturn != nil
        returnFromLookup()
        hasMovedThisSession = true
        screen = .frontPage
        guard !returnsToLibrary else { return }
        libraryPlace = nil
        selectedBookID = location?.book ?? selectedBookID
    }

    /// Returns to the previous chapter at the verse read there, skipping chapters the current translation lacks.
    /// A lookup in the chapter being read has no entry of its own: Back returns from it. A Library
    /// lookup with nothing being read steps back through its passages, then returns to the Library.
    public func goBack() {
        if isLookingUpReturnChapter {
            returnFromLookup()
            return
        }
        while let previous = history.goBack() {
            if land(on: previous) { return }
        }
        if isLookingUpWithNothingRead { returnFromLookup() }
    }

    public func goForward() {
        if history.canGoForward { restoreSharedPlaceEntry() }
        while let next = history.goForward() {
            if land(on: next) { return }
        }
    }

    /// Shows the history's current chapter at the verse read there; false when the translation
    /// lacks it. Landing on a lookup's return chapter is returning from it, in the return place's
    /// translation, or going to where the other device read on meanwhile.
    private func land(on location: ChapterLocation) -> Bool {
        let place = lookupReturn.flatMap { $0.location == location ? $0 : nil }
        if place != nil, returnToWhereReadElsewhere() { return true }
        if let place, place.translationID != translationID {
            _ = switchTranslation(toStored: place.translationID, keepingIfLacks: location)
        }
        guard isAvailable(location) else { return false }
        hasMovedThisSession = true
        show(location, verse: history.currentVerse)
        if place != nil {
            lookupReturn = nil
            returnToLibrary()
        }
        return true
    }

    /// Next: within the book, a jump to the next chapter's label (the book is not reloaded); at
    /// its end, the next book's first chapter. Either way it pushes a history entry and reads on
    /// from a lookup, as `open` does.
    public func goToNextChapter() {
        if let nextChapter { openWithoutRecording(nextChapter, verse: nil) }
    }

    /// Previous: within the book, a jump to the previous chapter's label; at its first chapter,
    /// the previous book at its last chapter.
    public func goToPreviousChapter() {
        if let previousChapter { openWithoutRecording(previousChapter, verse: nil) }
    }

    public func setTranslation(_ id: String) {
        guard id != translationID, translations.contains(where: { $0.id == id }) else { return }
        hasMovedThisSession = true
        translationID = id
        positionStore.save(translationID: id)
        reloadBooks()
        fitTheScopeToTheTranslation()
        // A Library lookup with nothing being read keeps the translation chosen during it.
        if libraryLookupTranslationID != nil { libraryLookupTranslationID = id }
        if let location, isAvailable(location) {
            // A jump inside the chapter being read: the place being read takes the translation too,
            // so the jump can still end by scrolling and a relaunch opens in the one chosen.
            if let place = lookupReturn, place.location == location {
                lookupReturn = ReadingPlace(location: place.location, verse: place.verse, translationID: id)
                let moved = ReadingPosition(book: location.book, chapter: location.chapter, firstVisibleVerse: place.verse, translationID: id)
                positionStore.save(moved)
                storedAtLookupStart = moved
            }
            // Keep the place and the current screen: switching from the front page stays on it,
            // with the book chosen there.
            let screen = self.screen, chosenBookID = selectedBookID
            show(location, verse: firstVisibleVerse)
            self.screen = screen
            if screen == .frontPage { selectedBookID = chosenBookID }
        } else {
            // A lookup the new translation lacks ends (one from the Library shows it again); the
            // stored place is still the one being read. With nothing looked up nothing is read.
            let wasLookingUp = isLookingUp, wasNothingRead = isLookingUpWithNothingRead
            lookupReturn = nil
            self.location = nil
            verses = []
            bookText = nil
            scrollTarget = nil
            screen = .frontPage
            if wasNothingRead { history = NavigationHistory() }
            returnToLibrary()
            if !wasLookingUp { positionStore.clear() }
        }
        fitTheLibraryToTheTranslation()
    }

    /// Called by the reader as the user scrolls, with the verse at the top of the page; persists
    /// the place. The reader shows one chapter, so a verse outside the open chapter (a stale
    /// report, from the chapter or book shown before) is ignored.
    public func reportReadingPosition(_ verse: VerseLocation) {
        guard let location, verse.book == location.book, verse.chapter == location.chapter else { return }
        let isFirstReport = !hasReportedSinceShow
        hasReportedSinceShow = true
        guard verse.verse != firstVisibleVerse else { return }
        if !isFirstReport { hasMovedThisSession = true }
        firstVisibleVerse = verse.verse
        history.updateCurrentVerse(verse.verse)
        savePosition(location)
    }

    // MARK: - Palette

    /// Scripture is among the results, or the scope is narrower than the whole Bible (so it can be
    /// widened when it finds nothing).
    public var showsScopeMenu: Bool {
        paletteResults.groups.contains { $0.kind == .scripture } || searchScope != .wholeBible
    }

    /// Everything a search depends on; the views refresh when it changes.
    public var paletteSearchKey: PaletteSearchKey {
        PaletteSearchKey(
            query: paletteQuery, translationID: translationID, scope: searchScope, order: searchOrder,
            chip: paletteChip, limits: activeSearchLimits, choosingTranslation: isChoosingTranslation)
    }

    /// The app's half with the model's own fields set.
    public var paletteState: PaletteState {
        var state = appPaletteState?() ?? PaletteState()
        state.isReading = screen == .reader
        state.canGoBack = canGoBack
        state.canGoForward = canGoForward
        state.hasPreviousChapter = previousChapter != nil
        state.hasNextChapter = nextChapter != nil
        state.isLookingUp = isLookingUp
        state.hasRecents = !(recents?.items.isEmpty ?? true)
        state.otherTranslations = translations.filter { $0.id != translationID }.count
        return state
    }

    /// The commands that can run now, in the palette's order; none where search offers none.
    private var availableCommands: [PaletteCommand] {
        guard includesCommandsInSearch else { return [] }
        let state = paletteState
        return PaletteCommand.all.filter { $0.isAvailable(in: state) }
    }

    /// The link to the open chapter, in this build's scheme (Copy Link to This Chapter).
    public var chapterLink: URL? {
        guard let location, let book = BookCatalog.book(code: location.book) else { return nil }
        return PassageLink(reference: Reference(book: book, chapter: location.chapter, verse: nil))
            .url(scheme: PassageLink.appScheme)
    }

    /// Esc: with the translations showing it returns to the whole list; otherwise it closes the
    /// palette, which empties it.
    public func escapePalette() {
        if isChoosingTranslation {
            isChoosingTranslation = false
            updatePalette()
        } else {
            isPaletteShown = false
        }
    }

    /// Ranks `paletteQuery` now, on the main actor: Return on a query newer than the results, and tests.
    public func updatePalette() {
        var settled = false
        while !settled {
            settled = showPalette(scriptureRequest.map { Self.answer(to: $0, from: store) })
        }
    }

    /// As `updatePalette`, with Scripture searched off the main actor. A result is dropped when its
    /// request is no longer what the model would ask (a newer keystroke, scope, order, chip or
    /// translation, whose own refresh shows it), or when the refresh was cancelled. True when its
    /// answer was shown: the results are then the query's as it is now.
    @discardableResult public func refreshPalette() async -> Bool {
        var settled = false
        while !settled {
            let request = scriptureRequest
            var answer: ScriptureAnswer?
            if let request { answer = await scriptureSearch(request) }
            guard !Task.isCancelled, request == scriptureRequest else { return false }
            settled = showPalette(answer)
        }
        return true
    }

    /// Runs `work` on the global concurrent executor, off the main actor.
    @concurrent nonisolated static func offMain<T: Sendable>(_ work: @Sendable () throws -> T) async rethrows -> T {
        try work()
    }

    /// The rows each group shows: `SearchLimits.paletteChip` while a chip is chosen.
    private var activeSearchLimits: SearchLimits {
        paletteChip == nil ? searchLimits : .paletteChip
    }

    /// What Scripture would be asked for the query now; nil with nothing typed.
    private var scriptureRequest: ScriptureRequest? {
        let trimmed = paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let query = SearchQuery(paletteQuery)
        return ScriptureRequest(
            query: query, translationID: translationID, scope: searchScope, order: searchOrder,
            limit: activeSearchLimits.verses,
            suggests: query.allowsSuggestion && ReferenceParser.parse(trimmed) == nil,
            peopleLimit: activeSearchLimits.people, placesLimit: activeSearchLimits.places)
    }

    /// The store's verses for `request`, and a near spelling when it suggests and nothing was found;
    /// with them, the people and places the typed words name (whatever the scope: they are the whole Bible's).
    nonisolated static func answer(to request: ScriptureRequest, from store: BibleStore) -> ScriptureAnswer {
        var answer = verses(for: request, from: store)
        do {
            answer.people = try store.searchPeople(request.query.text, limit: request.peopleLimit)
            answer.places = try store.searchPlaces(request.query.text, limit: request.placesLimit)
        } catch {
            searchLogger.error("Name search failed: \(error)")
        }
        return answer
    }

    nonisolated private static func verses(for request: ScriptureRequest, from store: BibleStore) -> ScriptureAnswer {
        do {
            let page = try store.search(
                request.query, translationID: request.translationID, scope: request.scope, order: request.order,
                limit: request.limit)
            guard page.total == 0, request.suggests else { return ScriptureAnswer(page: page, suggestion: nil) }
            let suggestion = try store.suggestion(for: request.query, translationID: request.translationID, scope: request.scope)
            return ScriptureAnswer(page: page, suggestion: suggestion)
        } catch {
            searchLogger.error("Search failed: \(error)")
            return ScriptureAnswer(page: .empty, suggestion: nil)
        }
    }

    nonisolated private static let searchLogger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "navigation")

    /// Ranks the query with Scripture's answer. False, with the chip back at All, when the chosen
    /// chip's groups are absent: the query is to be ranked again with the usual limits.
    private func showPalette(_ answer: ScriptureAnswer?) -> Bool {
        let trimmed = paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let available = availableCommands
        let suggested = PaletteCommand.suggested.filter(available.contains)
        let results = isChoosingTranslation
            ? SearchResults(groups: [otherTranslationsGroup], verseColors: [:])
            : trimmed.isEmpty
            ? SearchRanker.emptyState(
                // The open chapter is left out only while the reader shows it; on the front page it is the way back.
                recents: recents?.shown(openChapter: screen == .reader ? location : nil, translations: translations) ?? [],
                commands: Array(suggested.prefix(activeSearchLimits.commands)), commandTotal: suggested.count)
            : SearchRanker.results(
                query: paletteQuery,
                books: books,
                translations: translations,
                activeTranslationID: translationID,
                verses: answer?.page.verses ?? [],
                verseTotal: answer?.page.total ?? 0,
                suggestion: answer?.suggestion,
                marks: markSearch?() ?? [],
                commands: available,
                people: answer?.people ?? .none,
                places: answer?.places ?? .none,
                limits: activeSearchLimits)
        if let chip = paletteChip, !results.chips().contains(chip) {
            paletteChip = nil
            return false
        }
        paletteResults = results
        rankedSearchKey = paletteSearchKey
        return true
    }

    /// Every translation but the one being read, for Switch Translation….
    private var otherTranslationsGroup: SearchGroup {
        let others = translations.filter { $0.id != translationID }.map(PaletteItem.translation)
        return SearchGroup(kind: .translations, title: "Translations", items: others, totalCount: others.count)
    }

    private func returnToTheWholeBible() {
        if searchScope != .wholeBible { searchScope = .wholeBible }
    }

    /// A scope the translation being read has no book of searches nothing: it returns to the whole Bible.
    private func fitTheScopeToTheTranslation() {
        if searchScope != .wholeBible, !books.contains(where: { searchScope.contains($0.book) }) {
            searchScope = .wholeBible
        }
    }

    /// Return in the palette. Results are refreshed with a delay while typing, so when the search
    /// has moved on since the last refresh the typed query is ranked again and its first row is
    /// taken; otherwise the highlighted row is.
    public func submitPalette(selectedIndex: Int) {
        var index = selectedIndex
        if rankedSearchKey != paletteSearchKey {
            updatePalette()
            index = 0
        }
        guard paletteItems.indices.contains(index) else { return }
        select(paletteItems[index])
    }

    /// Acts on a search row and closes the palette. The Mac's palette also clears its query and
    /// results; the phone's search tab passes `keepingQuery` so both are there when he comes back.
    /// A suggestion is searched instead, and the palette stays open.
    public func select(_ item: PaletteItem, keepingQuery: Bool = false) {
        switch item {
        case .reference(let reference):
            open(reference)
        case .book(let book):
            open(ChapterLocation(book: book.id, chapter: 1))
        case .translation(let translation):
            setTranslation(translation.id)
        case .verse(let verse):
            // The search that found the verse, then the passage it led to.
            recordSearch()
            let location = ChapterLocation(book: verse.id.book, chapter: verse.id.chapter)
            lookUp(location, verse: verse.id.verse)
            recordLookup(location, verse: verse.id.verse)
        case .mark(let hit):
            // A mark from a passage query is the passage's own; from a word search, the search led to it.
            if !paletteResults.groups.contains(where: { $0.kind == .goTo }) { recordSearch() }
            showMark(hit.target)
            recents?.record(.mark(id: hit.id, kind: hit.kind, target: hit.target, reference: hit.referenceString), translationID: nil)
        case .command(.switchTranslation):
            // The palette stays open on the translations alone.
            paletteQuery = ""
            isChoosingTranslation = true
            updatePalette()
            return
        case .command(let command):
            run(command)
        case .suggestion(let suggestion):
            // The near spelling is searched at once; the palette stays open on its results.
            paletteQuery = suggestion.query
            updatePalette()
            return
        case .recent(let recent):
            guard choose(recent) else { return }
        case .person(let person):
            // Opened by name, not added to Recent (spec 6.6).
            showInLibrary(LibraryPlace(book: nil, topic: .people, trail: [.person(person.id)]))
        case .place(let place):
            showInLibrary(LibraryPlace(book: nil, topic: .places, trail: [.place(place.id)]))
        }
        isPaletteShown = false
        guard !keepingQuery else { return }
        clearPalette()
    }

    /// No words and no results; emptying the words returns the scope and the chip too.
    private func clearPalette() {
        paletteQuery = ""
        paletteResults = .empty
    }

    /// Runs a command the model can; the rest are the app's.
    private func run(_ command: PaletteCommand) {
        switch command {
        case .home: goHome()
        case .back: goBack()
        case .forward: goForward()
        case .previousChapter: goToPreviousChapter()
        case .nextChapter: goToNextChapter()
        case .readFromHere: keepLookup()
        case .textLayout: textLayoutRequests += 1
        case .showShortcuts: isShortcutsShown = true
        case .clearRecents: recents?.clear()
        default: performCommand?(command)
        }
    }

    /// Records the search that is typed, with its scope and Scripture's count, as one that led somewhere.
    private func recordSearch() {
        let query = paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let count = paletteResults.groups.first { $0.kind == .scripture }?.totalCount ?? 0
        recents?.record(.search(query: query, scope: searchScope, verseCount: count), translationID: nil)
    }

    /// Does again what a recent did the first time, and records it as now. False for a search,
    /// which leaves the palette open on its results.
    private func choose(_ recent: Recent) -> Bool {
        switch recent.target {
        case .chapter(let location):
            if let id = recent.translationID { setTranslation(id) }
            open(location)
        case .lookup(let location, let verse):
            lookUp(location, verse: verse, translationID: recent.translationID)
            recordLookup(location, verse: verse)
        case .mark(let id, let kind, let target, let reference):
            showMark(target)
            recents?.record(.mark(id: id, kind: kind, target: target, reference: reference), translationID: nil)
        case .search(let query, let scope, _):
            // The query first: emptying it returns the scope to the whole Bible.
            paletteQuery = query
            searchScope = scope
            fitTheScopeToTheTranslation()
            updatePalette()
            recordSearch()
            return false
        }
        return true
    }

    /// Hands a mark to the app's `showTarget`; without it the chapter is looked up.
    private func showMark(_ target: MarkupTarget) {
        if let showTarget {
            showTarget(target)
        } else {
            lookUp(target.location, verse: target.verse, translationID: target.translationID)
        }
    }

    // MARK: - Private

    private func isAvailable(_ location: ChapterLocation) -> Bool {
        guard location.chapter >= 1, let entry = books.first(where: { $0.book.id == location.book }) else { return false }
        return location.chapter <= entry.chapterCount
    }

    private func reloadBooks() {
        do {
            books = try store.books(in: translationID)
        } catch {
            logger.error("Could not load books for \(self.translationID): \(error)")
            books = []
        }
    }

    /// Makes an available chapter current in the history and shows it at `verse`.
    private func go(to location: ChapterLocation, verse: Int?) {
        history.go(to: location)
        show(location, verse: verse)
        history.updateCurrentVerse(firstVisibleVerse)
    }

    /// Displays an available chapter without touching history, loading its book when it is not
    /// the one already loaded in this translation.
    private func show(_ location: ChapterLocation, verse: Int?, atEnd: Bool = false) {
        hasReportedSinceShow = false
        loadBook(location.book)
        verses = bookText?.chapters[location.chapter] ?? []
        self.location = location
        selectedBookID = location.book
        screen = .reader
        let target = resolvedVerse(verse)
        firstVisibleVerse = target
        scrollTarget = ScrollTarget(chapter: location.chapter, verse: target, atEnd: atEnd)
        savePosition(location)
    }

    /// Loads a book's text in the translation being read, unless it is the one loaded.
    private func loadBook(_ book: String) {
        guard bookText?.book != book || bookText?.translationID != translationID else { return }
        do {
            bookText = BookText(book: book, translationID: translationID, chapters: try store.bookChapters(book, translationID: translationID))
        } catch {
            logger.error("Could not load \(book) in \(self.translationID): \(error)")
            bookText = nil
        }
    }

    /// The requested verse if present, else the first later verse, else the chapter's last verse.
    private func resolvedVerse(_ requested: Int?) -> Int {
        guard let requested else { return verses.first?.id.verse ?? 1 }
        if let hit = verses.first(where: { ($0.endVerse ?? $0.id.verse) >= requested }) {
            return hit.id.verse
        }
        return verses.last?.id.verse ?? 1
    }

    /// Writes the place being read; a looked-up passage is not one.
    private func savePosition(_ location: ChapterLocation) {
        guard !isLookingUp else { return }
        positionStore.save(ReadingPosition(
            book: location.book,
            chapter: location.chapter,
            firstVisibleVerse: firstVisibleVerse,
            translationID: translationID))
    }

    private func restoreStoredPosition() {
        guard let stored = positionStore.load(),
              switchTranslation(toStored: stored.translationID, keepingIfLacks: stored.chapterLocation)
        else { return }
        history.go(to: stored.chapterLocation, verse: stored.firstVisibleVerse)
        show(stored.chapterLocation, verse: stored.firstVisibleVerse)
    }

    /// Makes a stored position's translation current when it is bundled and has `location`;
    /// otherwise puts back the translation and books being read and returns false. Unlike
    /// `setTranslation`, it neither saves the choice nor counts as a move.
    private func switchTranslation(toStored id: String, keepingIfLacks location: ChapterLocation) -> Bool {
        guard translations.contains(where: { $0.id == id }) else { return false }
        guard id != translationID else { return isAvailable(location) }
        let savedTranslation = translationID
        let savedBooks = books
        translationID = id
        reloadBooks()
        guard isAvailable(location) else {
            translationID = savedTranslation
            books = savedBooks
            return false
        }
        fitTheScopeToTheTranslation()
        return true
    }
}

// MARK: - Passage links

extension NavigationModel {
    /// Opens a passage link as a lookup, in the link's translation when the app has it. False,
    /// with nothing changed, for a link that cannot be read or a chapter the translation that
    /// would show it lacks. Closes the palette and the shortcuts sheet when it opens.
    @discardableResult public func openPassageLink(_ url: URL) -> Bool {
        guard let link = PassageLink(url) else { return false }
        let linked = link.translationID.flatMap { id in
            translations.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }?.id
        }
        let translation = linked ?? translationID
        let reference = link.reference
        let location = ChapterLocation(book: reference.book.id, chapter: reference.chapter ?? 1)
        guard let book = (try? store.books(in: translation))?.first(where: { $0.book.id == location.book }),
              (1...max(book.chapterCount, 1)).contains(location.chapter) else { return false }
        // A verse past the chapter's end opens the chapter at its start, not at its last verse.
        var verse = reference.verse
        if let requested = verse {
            let last = (try? store.chapter(location, translationID: translation))?.last.map { $0.endVerse ?? $0.id.verse }
            if requested > (last ?? 0) { verse = nil }
        }
        isPaletteShown = false
        isShortcutsShown = false
        lookUp(location, verse: verse, translationID: linked)
        recordLookup(location, verse: verse)
        return true
    }
}
