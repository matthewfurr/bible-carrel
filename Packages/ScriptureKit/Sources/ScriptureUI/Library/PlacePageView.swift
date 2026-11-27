import ScriptureData
import SwiftUI

/// One place's page (spec 6.3): the name, its kind (with "approximate" where the data marks it so)
/// and what else it was called, the dictionary's entry, the places at the same spot, then References, as a person's
/// page has them (`LibraryReferencesSection`). A section with nothing is
/// left out. Scrolls, in the Library's text column (the reader's measure, centred, on the Mac; a scaled
/// 520 pt page on the phone, as before). The map is not part of it: Places sets it above.
///
/// `bookName` is the book the page is for, nil for the whole Bible (References then has no first book, and a place the
/// data cannot locate says so). On coming back from a
/// passage opened from it, `anchor`'s book is open and scrolled into view.
public struct PlacePageView: View {
    let page: PlacePage
    let bookName: String?
    let navigation: NavigationModel
    @Binding var toggledBooks: Set<String>
    let anchor: Reference?
    let onWalk: (LibraryEntity) -> Void
    let onShow: ((Reference) -> Void)?
    let onOpen: (Reference) -> Void

    /// The books whose every line is shown, seeded so a come-back's scroll finds its line.
    @State private var allChapters: Set<String>
    @Environment(\.libraryType) private var type

    public init(page: PlacePage, bookName: String?, navigation: NavigationModel, toggledBooks: Binding<Set<String>>, anchor: Reference?,
                onWalk: @escaping (LibraryEntity) -> Void, onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void) {
        self.page = page
        self.bookName = bookName
        self.navigation = navigation
        self._toggledBooks = toggledBooks
        self.anchor = anchor
        self.onWalk = onWalk
        self.onShow = onShow
        self.onOpen = onOpen
        self._allChapters = State(initialValue: LibraryVersesAnchor.initialChapters(here: page.here, elsewhere: page.elsewhere, anchor: anchor))
    }

    /// The page's books under References, as a person's page has them: the book opened from first, open at first.
    private var references: LibraryReferences { LibraryReferences(here: page.here, elsewhere: page.elsewhere) }

    /// The scroll to a verse line Tab moves to (its proxy set once the page appears).
    @State private var revealLine = LibraryRevealLine()

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    heading
                    if let entry = page.place.dictionary, !entry.isEmpty {
                        DictionaryEntryView(entry, subject: page.place.summary.name, navigation: navigation, onShow: onShow, onOpen: onOpen)
                    }
                    if !page.sameSpot.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            LibraryPageHeading("At the same spot")
                            FlowLayout(spacing: AppSpacing.xs, isCentered: false) {
                                ForEach(page.sameSpot) { other in
                                    Button { onWalk(.place(other.id)) } label: {
                                        ChipLabel(isOn: false, font: type.font(.caption, weight: .semibold)) { Text(other.name) }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(other.name)
                                }
                            }
                        }
                    }
                    if references.here != nil || !references.elsewhere.isEmpty {
                        LibraryReferencesSection(references: references, toggledBooks: toggledBooks, onToggle: { toggledBooks = $0 }, showsAll: allChapters,
                                                 navigation: navigation, onShowAll: { allChapters.insert($0) }, onShow: onShow, onOpen: onOpen)
                    }
                    LibraryCreditLine()
                        .padding(.top, AppSpacing.lg)
                }
                .libraryColumn()
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                // A verse line Tab moves to inside its book, brought into view (a cut).
                .environment(\.libraryRevealLine, revealLine)
            }
            .task(id: page.place.summary.id) {
                revealLine.proxy = proxy
                allChapters = LibraryVersesAnchor.initialChapters(here: page.here, elsewhere: page.elsewhere, anchor: anchor)
                if let anchor {
                    // As a person's page: the run's book is open, the others as the reader left them.
                    let opened = references.opening(anchor.book.id, in: toggledBooks)
                    if opened != toggledBooks { toggledBooks = opened }
                    await Task.yield()
                    proxy.scrollTo(LibraryVersesAnchor.scrollTarget(anchor, in: references.groups), anchor: .top)
                }
            }
        }
    }

    /// The name, then its kind and what else it was called.
    private var heading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(page.place.summary.name)
                .font(type.font(.title2, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)
            if let kind = page.kindLine {
                Text(kind).font(type.font(.callout)).foregroundStyle(Color.inkSecondary)
            }
            if let alsoCalled = page.alsoCalledLine {
                Text(alsoCalled).font(type.font(.callout)).foregroundStyle(Color.inkSecondary)
            }
            // In a book the list already sets it under "Not on the map"; the whole Bible's page has no list.
            if bookName == nil, !page.isOnMap {
                Text("Not on the map.").font(type.font(.callout)).foregroundStyle(Color.inkSecondary)
            }
        }
        .librarySelectable()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
