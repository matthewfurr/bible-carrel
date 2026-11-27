import ScriptureData
import SwiftUI

/// The contents half of the Mac's front page while a Library view is open (spec 6.1): a header with
/// "Contents" (Esc does the same), the view's title and a count, and under it People, Places or
/// About for the chosen book. A passage clicked in it shows in a popover; Open goes to the reader as
/// a lookup that comes back to this view.
public struct LibraryView: View {
    let navigation: NavigationModel
    @Binding var place: LibraryPlace
    let onOpenSettings: () -> Void

    /// What the place read last, held across the front page's redraws (each `libraryPlace` write
    /// builds this view again, and a page read is every verse of a person). The book's list and the
    /// page chosen in it are kept apart, so choosing a person or place re-reads only the page.
    @State private var listCache = LoadCache()
    @State private var pageCache = LoadCache()

    public init(navigation: NavigationModel, place: Binding<LibraryPlace>, onOpenSettings: @escaping () -> Void) {
        self.navigation = navigation
        self._place = place
        self.onOpenSettings = onOpenSettings
    }

    /// Reads the store only when the book, view, person or translation is not the one last read.
    /// A reference type, so a rebuilt view keeps it; the first body of a new view reads at once, so
    /// coming Back from the reader draws the page in its first frame.
    @MainActor final class LoadCache {
        private var key: Source?
        private var value = Loaded()
        private(set) var reads = 0

        func loaded(for source: Source, read: () -> Loaded) -> Loaded {
            if key != source {
                value = read()
                key = source
                reads += 1
            }
            return value
        }
    }

    /// What the place reads from the store, kept between redraws.
    struct Loaded: Equatable {
        var people: BookPeople?
        var person: PersonPage?
        var about: BookAbout?
        var places: BookPlaces?
        var placePage: PlacePage?

        /// The book's own view: its people, its places or About.
        @MainActor static func loadList(_ place: LibraryPlace, navigation: NavigationModel) -> Loaded {
            var loaded = Loaded()
            switch place.topic {
            case .people: loaded.people = place.book.flatMap { navigation.bookPeople($0) }
            case .about: loaded.about = place.book.flatMap { navigation.bookAbout($0) }
            case .places: loaded.places = place.book.flatMap { navigation.bookPlaces($0) }
            }
            return loaded
        }

        /// The person's or place's page showing, if any.
        @MainActor static func loadPage(_ place: LibraryPlace, navigation: NavigationModel) -> Loaded {
            var loaded = Loaded()
            switch place.showing {
            case .person(let id)? where place.topic == .people: loaded.person = navigation.personPage(id, inBook: place.book)
            case .place(let id)? where place.topic == .places: loaded.placePage = navigation.placePage(id, inBook: place.book)
            default: break
            }
            return loaded
        }

        /// A list's read with a page's read laid over it.
        func with(page: Loaded) -> Loaded {
            var loaded = self
            loaded.person = page.person
            loaded.placePage = page.placePage
            return loaded
        }
    }

    /// What a reload is for: a change of book, view or person, or of the translation.
    struct Source: Equatable {
        let book: String?
        let topic: LibraryTopic
        let showing: LibraryEntity?
        let translationID: String
    }

    private var source: Source {
        Source(book: place.book, topic: place.topic, showing: place.showing, translationID: navigation.translationID)
    }

    /// The list's key: the book, view and translation, whoever is chosen.
    private var listSource: Source {
        Source(book: place.book, topic: place.topic, showing: nil, translationID: navigation.translationID)
    }

    /// Esc, wherever the keyboard is in the window, is the front page's (`FrontPageView`, `LibraryEscapeRule`).
    public var body: some View {
        let list = listCache.loaded(for: listSource) { Loaded.loadList(place, navigation: navigation) }
        let loaded = list.with(page: pageCache.loaded(for: source) { Loaded.loadPage(place, navigation: navigation) })
        VStack(spacing: 0) {
            LibraryHeaderView(navigation: navigation, place: $place, loaded: loaded)
            HairlineRule()
            content(loaded)
        }
        .environment(\.openLibrarySettings, LibrarySettingsOpener(open: onOpenSettings))
    }

    @ViewBuilder private func content(_ loaded: Loaded) -> some View {
        switch place.topic {
        case .people:
            LibraryPeopleView(people: loaded.people, person: loaded.person, place: $place, navigation: navigation,
                              onWalk: walk, onOpen: open)
        case .about:
            if let about = loaded.about {
                LibraryAboutView(about: about, navigation: navigation, onWalk: walk,
                                 onOpenTopic: { place = LibraryPlace(book: place.book, topic: $0) }, onOpen: open,
                                 anchor: place.anchor)
                    // A new book is a new page: its folds, pending scroll and offset do not carry over.
                    .id(place.book)
            } else {
                VStack(alignment: .leading) {
                    Spacer()
                    LibraryCreditLine()
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .places:
            if let places = loaded.places, places.namesNoPlace {
                VStack(spacing: 0) {
                    ContentUnavailableView("No Places", systemImage: "map",
                                           description: Text("No places are named in \(places.book.name)."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    LibraryCreditLine()
                        .padding(AppSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LibraryPlacesView(places: loaded.places, page: loaded.placePage, place: $place, navigation: navigation,
                                  onWalk: walk, onOpen: open)
            }
        }
    }

    /// People's "12 named · by mentions", Places' "8 places · 6 on the map"; About, and a book that
    /// names no place, have none; under a chosen chapter of the book Places reads that chapter's header line.
    nonisolated static func countLabel(_ topic: LibraryTopic, _ loaded: Loaded, peopleOrder: PeopleOrder = .mostNamed,
                                       placesChapter: Int? = nil) -> String? {
        switch topic {
        case .people: loaded.people?.countLabel(peopleOrder)
        case .places: loaded.places.flatMap { $0.namesNoPlace ? nil : PlacesChapters.countLine($0, chapter: placesChapter) }
        case .about: nil
        }
    }

    // MARK: - Actions

    /// A family name walks on from a person; a writer on About opens in the book's People.
    private func walk(_ entity: LibraryEntity) {
        if place.topic == .about { place.chooseInItsTopic(entity) } else { place.walk(to: entity) }
    }

    private func open(_ reference: Reference) {
        navigation.lookUpFromLibrary(reference, from: place.opening(reference))
    }
}

/// The Library's header line (spec 6.1): "Contents", the way back, the view's title and the count. A view of its own
/// so a render can host it alone (a hosted `LibraryView` on Places would make a `Map`).
struct LibraryHeaderView: View {
    let navigation: NavigationModel
    @Binding var place: LibraryPlace
    let loaded: LibraryView.Loaded

    @Environment(\.pageFace) private var pageFace
    /// People's order, on this device only; the header's count reads it, the list sets it.
    @AppStorage(PeopleOrder.key) private var peopleOrder: PeopleOrder = .mostNamed
    @AppStorage(PlacesOrder.key) private var placesOrder: PlacesOrder = .mostNamed

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            Button { navigation.libraryPlace = nil } label: {
                Label("Contents", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.accent)
            .help("Contents (Esc)")
            if place.trail.count > 1 {
                Button { place.stepBack() } label: {
                    Label(titleBeforeTheLast, systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.accent)
                .lineLimit(1)
            }
            Text(title(loaded))
                .font(pageFace.swiftUIFont(.title3))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.xs)
            if let count = LibraryView.countLabel(place.topic, loaded, peopleOrder: peopleOrder,
                                                  placesChapter: PlacesChapters.effective(place.placesChapter, order: placesOrder)) {
                Text(count)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    /// The book's view ("People in John"); for the whole Bible, the person or place showing, from
    /// the page already read rather than the store.
    private func title(_ loaded: LibraryView.Loaded) -> String {
        guard let book = place.book else {
            return loaded.person?.person.name ?? loaded.placePage?.place.summary.name ?? navigation.title(for: place)
        }
        return navigation.title(for: LibraryPlace(book: book, topic: place.topic))
    }

    /// The name of the one the way back goes to.
    private var titleBeforeTheLast: String {
        var before = place
        before.stepBack()
        return navigation.title(for: before)
    }
}
