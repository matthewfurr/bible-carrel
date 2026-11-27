import ScriptureData
import SwiftUI

/// One person's page (spec 4.4): the dates notice when it shows; the head, `LibraryPageTitle` (the name, and
/// the data's label under it) over the fact list (Father, Mother, Also called, Lived, Named, Family); the
/// dictionary's entry; then Family (the Mac's tree, the phone's line), References (`LibraryReferencesSection`), and the
/// credit line. A fact or section with nothing is left out. Scrolls. The text sits in the Library's column (the reader's
/// measure, centred, on the Mac; a scaled 520 pt page on the phone, as before); the Mac's family tree takes the page's
/// whole width, and where the page is too narrow for it (`FamilyTreeLayoutRule`) the Mac shows the phone's family line
/// in the column instead.
///
/// `bookName` is the book the page is for, nil for the whole Bible (References then has no first book). On coming back
/// from a passage opened from it, `anchor`'s book is open and scrolled into view.
public struct PersonPageView: View {
    let page: PersonPage
    let bookName: String?
    let navigation: NavigationModel
    /// The reader's turns of the books under References, and where a change of them goes: a value and a setter, not a
    /// binding, so the Mac's page can be compared (`PersonPagePane`) and is not built again in every update.
    let toggledBooks: Set<String>
    let setToggledBooks: (Set<String>) -> Void
    let anchor: Reference?
    let onWalk: (LibraryEntity) -> Void
    let onShow: ((Reference) -> Void)?
    let onOpen: (Reference) -> Void

    @AppStorage(LibraryDates.showKey) private var showsDates = LibraryDates.defaultShows
    /// The books whose every line is shown, seeded so a come-back's scroll finds its line.
    @State private var allChapters: Set<String>
    @Environment(\.libraryType) private var type
    /// The chips of the Mac's tree and the phone's "and n more" that are open; a new person's page opens with none (Departure 30).
    @State private var openChips: Set<FamilyChip> = []
    #if os(macOS)
    /// Whether the family is laid as the tree at the page's width, worked once per tree, type and width.
    @State private var familyForm = FamilyTreeFitMemo()
    #endif

    public init(page: PersonPage, bookName: String?, navigation: NavigationModel, toggledBooks: Binding<Set<String>>, anchor: Reference?,
                onWalk: @escaping (LibraryEntity) -> Void, onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void) {
        self.init(page: page, bookName: bookName, navigation: navigation, toggledBooks: toggledBooks.wrappedValue,
                  setToggledBooks: { toggledBooks.wrappedValue = $0 }, anchor: anchor, onWalk: onWalk, onShow: onShow, onOpen: onOpen)
    }

    init(page: PersonPage, bookName: String?, navigation: NavigationModel, toggledBooks: Set<String>,
         setToggledBooks: @escaping (Set<String>) -> Void, anchor: Reference?, onWalk: @escaping (LibraryEntity) -> Void,
         onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void) {
        self.page = page
        self.bookName = bookName
        self.navigation = navigation
        self.toggledBooks = toggledBooks
        self.setToggledBooks = setToggledBooks
        self.anchor = anchor
        self.onWalk = onWalk
        self.onShow = onShow
        self.onOpen = onOpen
        self._allChapters = State(initialValue: LibraryVersesAnchor.initialChapters(here: page.here, elsewhere: page.elsewhere, anchor: anchor))
    }

    /// The scroll to a verse line Tab moves to (its proxy set once the page appears).
    @State private var revealLine = LibraryRevealLine()

    public var body: some View {
        #if os(macOS)
        // The page's width, read in the layout pass, so the tree is first laid at its real width (it spans the page).
        GeometryReader { geometry in page(width: geometry.size.width) }
        #else
        page(width: nil)
        #endif
    }

    #if os(macOS)
    /// What a legacy vertical scroller takes from the page's width (none for overlay scrollers): a page with a
    /// family tree is taller than the window, so the scroller shows and the tree is that much narrower.
    private static var scrollerWidth: CGFloat {
        NSScroller.preferredScrollerStyle == .legacy ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) : 0
    }

    /// The tree's width on a page `width` wide: less its `lg` margins and `scroller` (a legacy scroller's width, which is
    /// always taken, so the width does not change as the scroller comes and goes).
    nonisolated static func treeWidth(page width: CGFloat, scroller: CGFloat) -> CGFloat {
        max(0, width - 2 * AppSpacing.lg - scroller)
    }

    /// The Mac's Family: the tree, or the phone's family line in the text column where the page is too narrow for the
    /// tree. Decided from the page's width (its `GeometryReader`, outside the scroll view, so neither a scroller nor the
    /// switch's own change of height moves it), never from the tree's own: no feedback, so no flicker at the boundary.
    @ViewBuilder private func family(width: CGFloat?) -> some View {
        let treeWidth = width.map { Self.treeWidth(page: $0, scroller: Self.scrollerWidth) }
        if let treeWidth, !familyForm.fitsAsTree(page.family, width: treeWidth, type: type) {
            FamilyLineView(tree: page.family, open: $openChips) { onWalk(.person($0.id)) }
                .libraryColumn()
        } else {
            FamilyTreeView(tree: page.family, open: $openChips, expectedWidth: treeWidth) { onWalk(.person($0.id)) }
        }
    }
    #endif

    private func page(width: CGFloat?) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        LibraryDatesNotice(hasDate: page.hasDate)
                        heading
                        if let entry = page.person.dictionary, !entry.isEmpty {
                            DictionaryEntryView(entry, subject: page.person.name, navigation: navigation, onShow: onShow, onOpen: onOpen)
                        }
                    }
                    .libraryColumn()
                    // The Mac's tree is not in the column: it has the page's width, less its margins, and folds only when
                    // the window is truly too narrow; narrower still, the phone's family line takes its place, in the column.
                    // Its header starts at the text column's edge, as every header does (Matt, 2026-11-24).
                    if !page.family.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            LibraryPageHeading("Family")
                                .libraryColumn()
                            #if os(macOS)
                            family(width: width)
                            #else
                            FamilyLineView(tree: page.family, open: $openChips) { onWalk(.person($0.id)) }
                            #endif
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        #if os(iOS)
                        // The phone's family line is in the column, as it was.
                        .libraryColumn()
                        #endif
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        if references.here != nil || !references.elsewhere.isEmpty {
                            LibraryReferencesSection(references: references, toggledBooks: toggledBooks, onToggle: setToggledBooks, showsAll: allChapters,
                                                     navigation: navigation, onShowAll: { allChapters.insert($0) }, onShow: onShow, onOpen: onOpen)
                        }
                        LibraryCreditLine()
                            .padding(.top, AppSpacing.lg)
                    }
                    .libraryColumn()
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                // A verse line Tab moves to inside its book, brought into view (a cut).
                .environment(\.libraryRevealLine, revealLine)
            }
            .task(id: page.person.id) {
                revealLine.proxy = proxy
                allChapters = LibraryVersesAnchor.initialChapters(here: page.here, elsewhere: page.elsewhere, anchor: anchor)
                if let anchor {
                    // Coming back: the run's book is open (the first book too, where the reader had closed it), the
                    // others as the reader left them.
                    let opened = references.opening(anchor.book.id, in: toggledBooks)
                    if opened != toggledBooks { setToggledBooks(opened) }
                    await Task.yield()
                    proxy.scrollTo(LibraryVersesAnchor.scrollTarget(anchor, in: references.groups), anchor: .top)
                }
            }
        }
    }

    /// The head: the title, the data's label under it, then the facts on one edge.
    private var heading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            LibraryPageTitle(page.person.name, subtitle: page.person.label)
            let facts = Self.facts(page, showingDates: showsDates)
            FactList(facts.map(row))
            if facts.contains(.lived) { LibraryDatesFootnote() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The facts a person shows, in order; a fact with no value is left out.
    enum Fact: String {
        case father = "Father", mother = "Mother", alsoCalled = "Also called", lived = "Lived", named = "Named", family = "Family"
    }

    nonisolated static func facts(_ page: PersonPage, showingDates: Bool) -> [Fact] {
        var facts: [Fact] = []
        if page.family.father != nil { facts.append(.father) }
        if page.family.mother != nil { facts.append(.mother) }
        if page.alsoCalled != nil { facts.append(.alsoCalled) }
        if page.lived(showingDates: showingDates) != nil { facts.append(.lived) }
        if page.namedLine != nil { facts.append(.named) }
        if page.family.summary != nil { facts.append(.family) }
        return facts
    }

    private func plain(_ text: String) -> some View {
        // A plain value can be selected and copied; a value that names a person stays a link.
        Text(text).font(type.font(type.reading)).foregroundStyle(Color.inkPrimary).librarySelectable()
    }

    private func relative(_ label: String, _ person: PersonSummary?) -> FactRow {
        guard let person else { return FactRow(label, spoken: "") { EmptyView() } }
        return FactRow(label, spoken: person.name, actions: [FactRow.Action(person.name) { onWalk(.person(person.id)) }]) {
            LibraryNameRun([LibraryNameRun.Name(entity: .person(person.id), name: person.name)], onWalk: onWalk)
        }
    }

    private func row(_ fact: Fact) -> FactRow {
        let label = fact.rawValue
        switch fact {
        case .father: return relative(label, page.family.father)
        case .mother: return relative(label, page.family.mother)
        case .alsoCalled: let text = page.alsoCalled ?? ""; return FactRow(label, spoken: text) { plain(text) }
        case .lived: let text = page.lived(showingDates: showsDates) ?? ""; return FactRow(label, spoken: text) { plain(text) }
        case .named: let text = page.namedLine ?? ""; return FactRow(label, spoken: text) { plain(text) }
        case .family: let text = page.family.summary ?? ""; return FactRow(label, spoken: text) { plain(text) }
        }
    }

    /// The page's books under References: the book opened from first, open at first.
    private var references: LibraryReferences { LibraryReferences(here: page.here, elsewhere: page.elsewhere) }
}
