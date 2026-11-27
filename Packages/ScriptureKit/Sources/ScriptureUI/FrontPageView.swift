import ScriptureData
import SwiftUI

/// The Mac's front page (spec 4.1 to 4.4): one contents page, every book under its Testament and
/// group in columns on `paper.page`, beside the chosen book's pane on `paper.panel` at the trailing
/// side. The contents scroll on their own when they do not fit; the pane never scrolls with them.
/// While a Library view is open (`navigation.libraryPlace`) it takes the contents' place; the
/// pane's icons open and switch it.
///
/// Search is the toolbar's field (⌘F): what is typed dims the books that do not match, chooses
/// the first match and rings a typed reference's chapter; Return opens the reference, else the
/// chosen book. Tab moves between the contents and the pane's grid; Return or Space on the
/// contents moves the keyboard to the grid.
public struct FrontPageView: View {
    let navigation: NavigationModel
    /// Opens Settings › General, where the Library's dates are turned off.
    let onOpenSettings: () -> Void
    /// The plan followed, for the "This week" band over the contents; nil where there are no plans.
    let plans: ReadingPlanModel?
    /// The band's "The whole plan": the plan window.
    let onShowWholePlan: () -> Void
    /// The reader's page text size: the contents' names, titles and labels are set at it.
    let readerSize: Double
    /// The marked chapters by book, grouped once per update rather than once per redraw of the pane.
    private let marksByBook: [String: [Int: ChapterMarks]]

    @State private var page: ContentsPage
    @State private var query = ""
    @State private var isSearchPresented = false
    @FocusState private var isSearchFocused: Bool
    /// Each change moves the keyboard to the pane's grid.
    @State private var gridFocusRequests = 0
    /// The front page's own width, which caps the pane at 40% of it.
    @State private var frontPageWidth: CGFloat = 0
    /// The pane's width as the divider sets it, kept on this Mac.
    @State private var paneWidth: PaneWidth
    /// The reader's Column width setting: the Library pages' column is the reader's measure.
    @AppStorage(ReaderSettings.columnWidthKey) private var columnWidth: ColumnWidthChoice = .normal

    /// The space the divider's drag is measured in: the front page, which does not move as the pane widens.
    private static let coordinateSpace = "frontPage"

    public init(navigation: NavigationModel, marks: [ChapterLocation: ChapterMarks], plans: ReadingPlanModel? = nil,
                onShowWholePlan: @escaping () -> Void = {}, onOpenSettings: @escaping () -> Void,
                readerSize: Double = ReaderSettings.defaultFontSize, paneDefaults: UserDefaults = .standard) {
        self.navigation = navigation
        self.onOpenSettings = onOpenSettings
        self.plans = plans
        self.onShowWholePlan = onShowWholePlan
        self.readerSize = readerSize
        self.marksByBook = Dictionary(grouping: marks, by: \.key.book).mapValues { entries in
            Dictionary(uniqueKeysWithValues: entries.map { ($0.key.chapter, $0.value) })
        }
        self._page = State(initialValue: ContentsPage(books: navigation.books, reading: navigation.location, chosenBookID: navigation.selectedBookID))
        self._paneWidth = State(initialValue: PaneWidth(defaults: paneDefaults))
    }

    /// What the page is built from; a change (a new translation) builds it again.
    private struct Source: Equatable {
        let books: [String]
        let reading: ChapterLocation?
    }

    private var source: Source {
        Source(books: navigation.books.map(\.book.id), reading: navigation.location)
    }

    /// The pane's sizes at the reader's page size.
    private var paneMetrics: ChapterPaneMetrics {
        ChapterPaneMetrics(readerSize: CGFloat(readerSize))
    }

    /// The width the reader chose, else the narrowest for the reader size; never more than 40% of
    /// the front page.
    private var shownPaneWidth: CGFloat {
        paneWidth.shown(paneMetrics, frontPageWidth: frontPageWidth)
    }

    public var body: some View {
        HStack(spacing: 0) {
            left
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.paperPage)
            pane
                .frame(width: shownPaneWidth)
                .frame(maxHeight: .infinity)
                .background(Color.paperPanel)
                // Over the pane's leading edge, taking no width of its own: the rule is centred on
                // the edge and the drag area reaches `xs / 2` into the contents and into the pane.
                .overlay(alignment: .leading) {
                    divider.offset(x: -AppSpacing.xs / 2)
                }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { frontPageWidth = $0 }
        .background {
            // ⌘F puts the keyboard in the toolbar's search field.
            Button("Find") { isSearchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            #if os(macOS)
            // Esc leaves a Library view for the contents wherever the keyboard is in the window,
            // even nowhere (after a ⌘K choice); the toolbar's field and the palette keep their own
            // Esc, and a popover, a window of its own, takes it first (`LibraryEscapeRule`).
            Button("Contents") { navigation.libraryPlace = nil }
                .keyboardShortcut(.cancelAction)
                .disabled(!LibraryEscapeRule.closesView(
                    viewOpen: navigation.libraryPlace != nil, searchFieldFocused: isSearchFocused,
                    paletteShown: navigation.isPaletteShown))
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            #endif
        }
        .searchable(text: $query, isPresented: $isSearchPresented, placement: .toolbar, prompt: "Books or a reference")
        .searchFocused($isSearchFocused)
        .onSubmit(of: .search) { submit() }
        // In case the toolbar's field keeps its Return from `onSubmit(of: .search)`, as the old
        // front page's search field did on macOS 26; `submit` acts once, since the first opens the reader.
        .onKeyPress(.return) {
            guard isSearchFocused else { return .ignored }
            submit()
            return .handled
        }
        .onChange(of: query) { _, text in
            navigation.frontPageSearchChanged(to: text)
            page.setQuery(text)
            if navigation.libraryPlace == nil { navigation.selectedBookID = page.chosenBookID }
        }
        .onChange(of: navigation.selectedBookID) { _, id in
            if let id, id != page.chosenBookID { page.choose(id) }
        }
        .onChange(of: source) { _, _ in
            var rebuilt = ContentsPage(books: navigation.books, reading: navigation.location, chosenBookID: navigation.selectedBookID)
            rebuilt.setQuery(query)
            page = rebuilt
            if navigation.selectedBookID != page.chosenBookID { navigation.selectedBookID = page.chosenBookID }
        }
        // The page opens with the book being read chosen (or the one chosen before).
        .onAppear {
            if navigation.selectedBookID != page.chosenBookID { navigation.selectedBookID = page.chosenBookID }
        }
    }

    /// The "This week" band shows over the contents while a plan is followed, dated and not
    /// finished; never over a Library view, whose header is its own.
    public nonisolated static func showsBand(showsWeek: Bool, libraryViewOpen: Bool) -> Bool {
        showsWeek && !libraryViewOpen
    }

    /// The contents, or the Library view that has taken their place.
    @ViewBuilder private var left: some View {
        if navigation.libraryPlace != nil {
            LibraryView(
                navigation: navigation,
                place: Binding(
                    get: { navigation.libraryPlace ?? LibraryPlace(book: nil, topic: .people) },
                    // A write once the view is closed (Esc) is the going view's: it reopens nothing.
                    set: { written in
                        if let open = LibraryEscapeRule.writing(written, over: navigation.libraryPlace) {
                            navigation.libraryPlace = open
                        }
                    }),
                onOpenSettings: onOpenSettings)
                // The Library pages at the reader's text size, in the reader's column.
                .environment(\.libraryType, LibraryType(readerSize: CGFloat(readerSize), columnWidth: columnWidth))
        } else {
            VStack(spacing: 0) {
                if let plans, Self.showsBand(showsWeek: plans.showsWeek, libraryViewOpen: navigation.libraryPlace != nil) {
                    band(plans)
                }
                contents
            }
        }
    }

    /// The week over the contents: no fill and no card, closed by a hairline inset `lg` at each
    /// side. Its buttons come before the contents in the Tab order; nothing here takes Esc.
    private func band(_ plans: ReadingPlanModel) -> some View {
        VStack(spacing: 0) {
            PlanWeekSummary(model: plans, onShowWholePlan: onShowWholePlan)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
            HairlineRule()
                .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var contents: some View {
        ContentsPageView(
            page: page,
            markedBooks: Set(marksByBook.keys),
            readerSize: CGFloat(readerSize),
            onChoose: choose,
            onOpen: { open(page.target(opening: $0)) })
            // Return or Space on the contents moves the keyboard to the pane's grid.
            .onKeyPress(keys: [.return, .space]) { _ in
                gridFocusRequests += 1
                return .handled
            }
    }

    /// The pane's divider. The pane follows the drag as a cut, with no animation.
    private var divider: some View {
        PaneDivider(
            columns: paneMetrics.columns(paneWidth: shownPaneWidth),
            coordinateSpace: Self.coordinateSpace,
            onDrag: { translation in
                withoutAnimation { paneWidth.drag(translation: translation, paneMetrics, frontPageWidth: frontPageWidth) }
            },
            onEnd: { withoutAnimation { paneWidth.endDrag(paneMetrics, frontPageWidth: frontPageWidth) } },
            onCancel: { withoutAnimation { paneWidth.cancelDrag() } },
            onReset: { withoutAnimation { paneWidth.reset() } },
            onAdjust: { columns in
                withoutAnimation { paneWidth.adjust(byColumns: columns, paneMetrics, frontPageWidth: frontPageWidth) }
            })
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    @ViewBuilder private var pane: some View {
        if page.hasNoMatch {
            ContentUnavailableView.search(text: query)
        } else if let id = page.chosenBookID, let book = navigation.books.first(where: { $0.book.id == id }) {
            BookPaneView(
                navigation: navigation,
                book: book,
                marks: marksByBook[id] ?? [:],
                ringedChapter: page.ringedChapter,
                paneMetrics: paneMetrics,
                gridColumns: paneMetrics.columns(paneWidth: shownPaneWidth),
                availableTopics: navigation.hasLibraryData(for: id) ? [.people, .places, .about] : [],
                activeTopic: navigation.libraryPlace.flatMap { $0.book == id ? $0.topic : nil },
                onOpenTopic: { openTopic($0, of: id) },
                focusRequests: gridFocusRequests)
        }
    }

    /// An icon opens that view of the book; the open one's icon leaves it as it is.
    private func openTopic(_ topic: LibraryTopic, of bookID: String) {
        guard navigation.libraryPlace?.book != bookID || navigation.libraryPlace?.topic != topic else { return }
        navigation.libraryPlace = LibraryPlace(book: bookID, topic: topic)
    }

    private func choose(_ bookID: String) {
        page.choose(bookID)
        navigation.selectedBookID = bookID
    }

    /// Return in the field: the reference, else the chosen book; nothing when nothing matches.
    private func submit() {
        guard navigation.screen == .frontPage, let target = page.submitTarget else { return }
        open(target)
    }

    private func open(_ target: ContentsPage.Target) {
        switch target {
        case .resume: navigation.returnToReader()
        case .chapter(let location): navigation.open(location)
        case .reference(let reference): navigation.open(reference)
        }
    }
}
