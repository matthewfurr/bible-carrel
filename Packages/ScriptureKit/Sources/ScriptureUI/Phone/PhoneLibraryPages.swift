import ScriptureData

/// A page pushed inside the phone's Library (or inside Search, for a page reached by name): a book's
/// People, Places or About, a person or place, or a passage opened from one.
public enum PhoneLibraryPage: Hashable, Sendable {
    case topic(book: String, LibraryTopic), entity(book: String?, LibraryEntity), passage(Reference)

    /// The book the page is for; nil for the whole Bible and for a passage.
    var book: String? {
        switch self {
        case .topic(let book, _): book
        case .entity(let book, _): book
        case .passage: nil
        }
    }
}

extension LibraryPlace {
    /// The pages a stack shows for the place: a book's topic page, then a page to each of the trail.
    /// The whole Bible has no topic page.
    public var pages: [PhoneLibraryPage] {
        let topicPage = book.map { [PhoneLibraryPage.topic(book: $0, topic)] } ?? []
        return topicPage + trail.map { .entity(book: book, $0) }
    }

    /// The place a stack's pages show: the book and topic of the first page (a page with no topic
    /// page before it takes its own: People for a person, Places for a place), and the trail of the
    /// people and places after it. A passage is not part of the place; nil for no page.
    public init?(pages: [PhoneLibraryPage]) {
        let entities = pages.compactMap { page -> LibraryEntity? in
            if case .entity(_, let entity) = page { return entity }
            return nil
        }
        switch pages.first(where: { if case .passage = $0 { false } else { true } }) {
        case .topic(let book, let topic):
            self.init(book: book, topic: topic, trail: entities)
        case .entity(let book, let entity):
            let topic: LibraryTopic = switch entity {
            case .person: .people
            case .place: .places
            }
            self.init(book: book, topic: topic, trail: entities)
        case .passage, nil:
            return nil
        }
    }
}

#if os(iOS)
import Observation
import SwiftUI

/// What a stack's pages keep beyond their path: each person's or place's books opened and closed, and the
/// reference last opened from the page a lookup returned to (spec 6.7, "as it was"). The stack's
/// owner makes one from the place it opens on and puts it in the environment.
@MainActor @Observable public final class PhoneLibraryPageMemory {
    var toggledBooks: [PhoneLibraryPage: Set<String>] = [:]
    /// The chapter chosen in each book's Places (By chapter), kept while Places is in the path and across a lookup.
    var placesChapters: [String: Int] = [:]
    /// The page the stack reopened on (a person, a place or About), and the reference opened from it.
    @ObservationIgnored let anchorPage: PhoneLibraryPage?
    @ObservationIgnored let anchor: Reference?

    public init(opening place: LibraryPlace?) {
        let page = place?.pages.last
        anchorPage = page
        anchor = page == nil ? nil : place?.anchor
        if let page, let place { toggledBooks[page] = place.toggledBooks }
        if let book = place?.book, let chapter = place?.placesChapter { placesChapters[book] = chapter }
    }

    /// The chapter chosen in `book`'s Places, written only for a change.
    func placesChapter(_ book: String) -> Binding<Int?> {
        Binding(get: { self.placesChapters[book] },
                set: { chapter in if chapter != self.placesChapters[book] { self.placesChapters[book] = chapter } })
    }

    func toggledBooks(_ page: PhoneLibraryPage) -> Binding<Set<String>> {
        Binding(get: { self.toggledBooks[page] ?? [] }, set: { self.toggledBooks[page] = $0 })
    }

    func anchor(for page: PhoneLibraryPage) -> Reference? {
        page == anchorPage ? anchor : nil
    }

    /// The place a stack's `path` shows, with the books opened and closed on its last person or place.
    func place(for path: [PhoneLibraryPage]) -> LibraryPlace? {
        guard var place = LibraryPlace(pages: path) else { return nil }
        if let last = path.last(where: { if case .entity = $0 { true } else { false } }) {
            place.toggledBooks = toggledBooks[last] ?? []
        }
        place.placesChapter = place.book.flatMap { placesChapters[$0] }
        return place
    }
}

/// One Library page, for Library's stack and for Search's; `path` is the stack it is pushed on.
/// People is plain rows; a person, a place and About are each one scrolling page; Places is the
/// map with its list in a sheet (`PhonePlacesScreen`); a passage is its verses with Open in Read,
/// a lookup that comes back to the page it was opened from. Every page is on `paper.page` with an
/// inline title; the notice about dates heads a page that shows one, and the credit is at the foot.
public struct PhoneLibraryPageView: View {
    let page: PhoneLibraryPage
    let navigation: NavigationModel
    let shell: PhoneShellModel
    @Binding var path: [PhoneLibraryPage]

    @Environment(PhoneLibraryPageMemory.self) private var sharedMemory: PhoneLibraryPageMemory?
    @State private var ownMemory = PhoneLibraryPageMemory(opening: nil)
    /// What the page read last, so a redraw reads nothing from the store.
    @State private var cache = LibraryView.LoadCache()
    /// A passage page's verses, read once for its reference and translation.
    @State private var passageCache = PassageCache()

    public init(page: PhoneLibraryPage, navigation: NavigationModel, shell: PhoneShellModel, path: Binding<[PhoneLibraryPage]>) {
        self.page = page
        self.navigation = navigation
        self.shell = shell
        self._path = path
    }

    private var memory: PhoneLibraryPageMemory { sharedMemory ?? ownMemory }

    public var body: some View {
        content
            .containerBackground(Color.paperPage, for: .navigation)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.openLibrarySettings, LibrarySettingsOpener(open: shell.openGeneralSettings))
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .topic(let book, .people):
            PhonePeoplePage(people: loaded.people, onChoose: { push(.entity(book: book, .person($0))) })
        case .topic(let book, .places):
            PhonePlacesScreen(book: book, places: loaded.places, navigation: navigation, shell: shell, path: $path,
                              chapter: memory.placesChapter(book), onLeave: { if memory.placesChapters[book] != nil { memory.placesChapters[book] = nil } })
        case .topic(let book, .about):
            if let about = loaded.about {
                LibraryAboutView(about: about, navigation: navigation, onWalk: walk,
                                 onOpenTopic: { push(.topic(book: book, $0)) }, onShow: show, onOpen: openInRead,
                                 anchor: memory.anchor(for: page))
            } else {
                creditAlone
            }
        case .entity(let book, .person):
            if let person = loaded.person {
                PersonPageView(page: person, bookName: bookName(book), navigation: navigation, toggledBooks: memory.toggledBooks(page),
                               anchor: memory.anchor(for: page), onWalk: walk, onShow: show, onOpen: openInRead)
            } else {
                creditAlone
            }
        case .entity(let book, .place):
            if let place = loaded.placePage {
                PhonePlacePage(page: place, bookName: bookName(book), navigation: navigation, toggledBooks: memory.toggledBooks(page),
                               anchor: memory.anchor(for: page), onWalk: walk, onShow: show, onOpen: openInRead)
            } else {
                creditAlone
            }
        case .passage(let reference):
            passage(reference)
        }
    }

    // MARK: - Reading

    /// The page's view of the store, read when the page or the translation changes.
    private var loaded: LibraryView.Loaded {
        let (book, topic, showing): (String?, LibraryTopic, LibraryEntity?) = switch page {
        case .topic(let book, let topic): (book, topic, nil)
        case .entity(let book, .person(let id)): (book, .people, .person(id))
        case .entity(let book, .place(let id)): (book, .places, .place(id))
        case .passage: (nil, .about, nil)
        }
        let source = LibraryView.Source(book: book, topic: topic, showing: showing, translationID: navigation.translationID)
        return cache.loaded(for: source) {
            var loaded = LibraryView.Loaded()
            switch (topic, showing) {
            case (.people, .person(let id)?): loaded.person = navigation.personPage(id, inBook: book)
            case (.places, .place(let id)?): loaded.placePage = navigation.placePage(id, inBook: book)
            case (.people, _): loaded.people = book.flatMap { navigation.bookPeople($0) }
            case (.places, _): loaded.places = book.flatMap { navigation.bookPlaces($0) }
            case (.about, _): loaded.about = book.flatMap { navigation.bookAbout($0) }
            }
            return loaded
        }
    }

    private var title: String {
        switch page {
        case .topic(let book, let topic): navigation.title(for: LibraryPlace(book: book, topic: topic))
        // A person's or place's name from the page read (no store read on a redraw).
        case .entity(_, .person): loaded.person?.person.name ?? ""
        case .entity(_, .place): loaded.placePage?.place.summary.name ?? ""
        case .passage(let reference): reference.displayString
        }
    }

    private func bookName(_ book: String?) -> String? {
        book.flatMap { BookCatalog.book(code: $0)?.name }
    }

    // MARK: - Going on

    private func push(_ next: PhoneLibraryPage) {
        path.append(next)
    }

    /// A family name, a place at the same spot or a writer on About: their page, for this page's book.
    private func walk(_ entity: LibraryEntity) {
        push(.entity(book: page.book, entity))
    }

    /// A reference tapped: its verses, pushed.
    private func show(_ reference: Reference) {
        push(.passage(reference))
    }

    /// Open in Read, on the passage's page at the top of the stack: a lookup that comes back to the
    /// page the passage was opened from (the place made from the path; the passage is not part of it).
    private func openInRead(_ reference: Reference) {
        guard let place = memory.place(for: path) else { return }
        navigation.lookUpFromLibrary(reference, from: place.opening(reference))
        shell.showInReader()
    }

    // MARK: - Pages

    @ViewBuilder private func passage(_ reference: Reference) -> some View {
        let passage = passageCache.passage(reference, navigation: navigation)
        switch passage {
        case .verses(let preview):
            ScrollView {
                VersePreviewView(preview: preview, openTitle: "Open in Read") { openInRead(reference) }
                    .padding(AppSpacing.md)
            }
        case .missing:
            ContentUnavailableView("Not in This Translation", systemImage: "book",
                                   description: Text(passage.missingLine ?? ""))
        }
    }

    /// A page the store has nothing for (a book outside the 66): the credit alone.
    private var creditAlone: some View {
        VStack(alignment: .leading) {
            Spacer()
            LibraryCreditLine()
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A passage page's verses, read when the reference or the translation changes, not on each redraw.
@MainActor final class PassageCache {
    private var key: (Reference, String)?
    private var value: LibraryPassage?

    func passage(_ reference: Reference, navigation: NavigationModel) -> LibraryPassage {
        if let key, let value, key.0 == reference, key.1 == navigation.translationID { return value }
        let passage = LibraryPassage.load(reference, navigation: navigation)
        key = (reference, navigation.translationID)
        value = passage
        return passage
    }
}

/// People in a book on the phone: plain rows, the name in `.body`, what tells a shared name apart
/// in `.caption` `ink.secondary`, the count trailing; a row pushes the person. The credit at the foot.
struct PhonePeoplePage: View {
    let people: BookPeople?
    let onChoose: (Int) -> Void
    /// One choice for People in every book, on this device only.
    @AppStorage(PeopleOrder.key) private var order: PeopleOrder = .mostNamed

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let people {
                    if people.rows.isEmpty {
                        Text("No people are named here.")
                            .font(.callout)
                            .foregroundStyle(Color.inkSecondary)
                            .padding(AppSpacing.lg)
                    }
                    let rows = people.rows(order)
                    if !rows.isEmpty {
                        LibraryOrderPicker(selection: $order, orders: PeopleOrder.allCases, title: \.title)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    ForEach(rows) { row in
                        PhoneLibraryRow(name: row.person.name, detail: row.label, count: row.person.verseCount,
                                        accessibilityLabel: row.accessibilityLabel) { onChoose(row.id) }
                        if row.id != rows.last?.id { Divider() }
                    }
                }
                LibraryCreditLine()
                    .padding(AppSpacing.lg)
            }
        }
    }
}

/// A row of the phone's People or Places: the name in `.body` `ink.primary`, a second line in
/// `.caption` `ink.secondary` where there is one, the count of verses trailing; `lg` at the sides,
/// `sm` up and down, no fill.
struct PhoneLibraryRow: View {
    let name: String
    let detail: String?
    let count: Int?
    var note: String?
    var isDimmed = false
    let accessibilityLabel: String
    var accessibilityHint: String?
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.body)
                        .foregroundStyle(isDimmed ? Color.inkTertiary : Color.inkPrimary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(isDimmed ? Color.inkTertiary : Color.inkSecondary)
                    }
                }
                Spacer(minLength: AppSpacing.xs)
                if let count {
                    Text(count, format: .number)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                } else if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

/// A place's page on the phone. Inside Places' sheet the map is behind the sheet; for the whole
/// Bible (reached by name) the place's own pin's map sits above the page at a scaled 280 pt (the
/// Mac's takes half the view's height), and a place not on the map has none.
struct PhonePlacePage: View {
    let page: PlacePage
    let bookName: String?
    let navigation: NavigationModel
    @Binding var toggledBooks: Set<String>
    let anchor: Reference?
    let onWalk: (LibraryEntity) -> Void
    let onShow: (Reference) -> Void
    let onOpen: (Reference) -> Void

    @ScaledMetric(relativeTo: .body) private var mapHeight: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            if bookName == nil, let pin = page.pin {
                PlacesMapView(pins: [pin], framing: PlacesFraming(chapter: nil, frame: BookPlaces.frame([pin])),
                              selection: .constant(nil), focus: nil)
                    .frame(height: mapHeight)
                HairlineRule()
            }
            PlacePageView(page: page, bookName: bookName, navigation: navigation, toggledBooks: $toggledBooks, anchor: anchor,
                          onWalk: onWalk, onShow: onShow, onOpen: onOpen)
        }
    }
}
#endif
