#if os(iOS)
import ScriptureData
import SwiftUI

/// Places in a book on the phone (spec 6.3): Apple's map fills the page, and its list is a sheet over
/// it at a quarter and at half the page (where it starts), on `paper.page`, never dismissed by a swipe. It never goes
/// past half, whether it holds the list or a place's page, and a scroll inside it scrolls its content, never the sheet
/// (Matt's review, 2026-11-24: "It should not cover the map."); the map stays live behind it. The sheet is a stack
/// of its own: the list, with the places the data cannot locate under "Not on the map"; a row
/// chooses its place on the map and pushes its page, and a place's passages push inside the sheet
/// too. Its pages are the Library's path after Places, so the place is the Library's trail and a
/// lookup comes back to it. A gathered pin tapped on the map lists its places at the list's head, and tapped again
/// while one of its places is shown returns the sheet to its list with them there. The sheet goes when Places is
/// popped or Library closes. A book that names no place says so.
///
/// The map is kept clear of the sheet: its padding follows the sheet's edge at every height, so its legal label rides
/// above it; a chosen pin under the sheet is moved up into the part left visible, and a chosen chapter is framed into
/// that part, the upper half of the page at the least. The camera judges by the sheet as it settles at a detent, never
/// by a drag's every frame.
struct PhonePlacesScreen: View {
    let book: String
    let places: BookPlaces?
    let navigation: NavigationModel
    let shell: PhoneShellModel
    /// The Library's path, Places among it.
    @Binding var path: [PhoneLibraryPage]

    /// The chosen chapter, kept by the Library's page memory (By chapter only; see `effectiveChapter`).
    @Binding var chapter: Int?
    /// Places has left the Library's path: its chapter is forgotten.
    let onLeave: () -> Void

    @AppStorage(PlacesOrder.key) private var order: PlacesOrder = .mostNamed
    /// A gathered pin chosen on the map, which leaves no place showing; the rest follows the path.
    @State private var selection = PlacesSelection()
    @State private var isListShown = false
    @State private var detent: PresentationDetent = Self.opening
    /// How much of the page the sheet covers, at every height it takes: the map's padding follows it.
    @State private var sheetCover: CGFloat = 0
    /// The sheet's cover as it settled at its detent: the map's camera keeps its pins and chapter clear of it.
    @State private var settledCover: CGFloat = 0

    private var ownPage: PhoneLibraryPage { .topic(book: book, .places) }

    /// The sheet at its tallest: half the page, never more.
    static let tallest: PresentationDetent = .fraction(PlacesSheet.tallestFraction)
    /// A quarter, and half the page (Matt's review, 2026-11-24: no large detent).
    static let detents: Set<PresentationDetent> = [.fraction(0.25), tallest]
    /// Where the sheet opens.
    static let opening: PresentationDetent = tallest
    /// A scroll inside the sheet scrolls the list or the page; only a drag on its grabber moves the sheet.
    static let contentInteraction: PresentationContentInteraction = .scrolls

    var body: some View {
        if let places, !places.namesNoPlace {
            map(places)
                .onAppear { isListShown = true }
                .onDisappear {
                    isListShown = false
                    if !path.contains(ownPage) { onLeave() }
                }
                .onChange(of: shell.isLibraryShown) { _, shown in if !shown { isListShown = false } }
                .sheet(isPresented: $isListShown) { sheet(places) }
                // A turn after the detent changes, the sheet's height is the detent's own.
                .onChange(of: detent) { DispatchQueue.main.async { settleCover() } }
                // A place shown another way (a lookup's return, a walk) that the chosen chapter does not name moves it.
                // Only a change is written.
                .onChange(of: LibraryPlace(pages: sheetPath.wrappedValue)?.showing) { _, showing in
                    let followed = PlacesChapters.following(showing: showing, chosen: chapter, in: places)
                    if followed != chapter { chapter = followed }
                }
                // Another order clears the chapter.
                .onChange(of: order) {
                    let cleared = PlacesChapters.afterOrderChange(to: order, chosen: chapter)
                    if cleared != chapter { chapter = cleared }
                }
                // Every change of the chapter in effect is announced, the book's count when it clears.
                .onChange(of: effectiveChapter) { _, chosen in
                    AccessibilityNotification.Announcement(PlacesChapters.announcementText(places, chapter: chosen)).post()
                }
        } else {
            VStack(spacing: 0) {
                ContentUnavailableView("No Places", systemImage: "map",
                                       description: Text("No places are named in \(BookCatalog.book(code: book)?.name ?? book)."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                LibraryCreditLine()
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - The sheet's path

    /// The pages pushed inside the sheet: those after Places in the Library's path.
    private var sheetPath: Binding<[PhoneLibraryPage]> {
        Binding(
            get: { path.firstIndex(of: ownPage).map { Array(path[($0 + 1)...]) } ?? [] },
            set: { pages in
                guard let index = path.firstIndex(of: ownPage) else { return }
                path = Array(path[...index]) + pages
            })
    }

    /// The chosen chapter, while the order is By chapter.
    private var effectiveChapter: Int? { PlacesChapters.effective(chapter, order: order) }

    /// The pins the map draws and every choice runs over: the chapter's, or the book's.
    private func pins(in places: BookPlaces) -> [BookPlaces.Pin] { places.pins(inChapter: effectiveChapter) }

    private func current(in places: BookPlaces) -> PlacesSelection {
        selection.following(LibraryPlace(pages: sheetPath.wrappedValue)?.showing, in: pins(in: places))
    }

    /// A row of the list or of a gathered pin: its chapter (By chapter) is chosen, the place on the map, and its page.
    private func choose(row: PlacesList.Row, in places: BookPlaces) {
        let rowChapter = order == .byChapter ? row.chapter : nil
        if let rowChapter, rowChapter != chapter { chapter = rowChapter }
        selection.choose(place: row.place.id, in: places.pins(inChapter: rowChapter))
        sheetPath.wrappedValue = [.entity(book: book, .place(row.place.id))]
    }

    /// A heading: the chapter is chosen (the chosen one again clears it: the phone's rows keep no chosen state, so its
    /// heading always shows its wash) and no gathered pin is kept; the sheet is at its list, so its path is already empty.
    private func choose(chapter number: Int) {
        chapter = PlacesChapters.afterHeading(number, chosen: chapter, rowChosen: false)
        selection = PlacesSelection()
    }

    /// The map's write. A pin of one place pushes its page; a gathered pin, or the map itself, returns
    /// the sheet to its list (the gathered pin's places at its head). One that repeats the pin already
    /// chosen (the map echoing a row) changes nothing.
    private func choose(pin id: String?, in places: BookPlaces) {
        guard id != current(in: places).pinID else { return }
        selection.choose(pin: id, in: pins(in: places))
        sheetPath.wrappedValue = selection.placeID.map { [.entity(book: book, .place($0))] } ?? []
    }

    /// A tap on the chosen gathered pin, a turn after it: its places are listed again unless the map gave the tap to
    /// another pin meanwhile; the sheet's path empties only when the selection changed.
    private func reopen(pin id: String?, in places: BookPlaces) {
        guard let reopened = current(in: places).reopened(at: id, in: pins(in: places)) else { return }
        selection = reopened
        sheetPath.wrappedValue = []
    }

    // MARK: - The map

    /// The camera's cover takes the sheet's height now; only a change is written.
    private func settleCover() {
        if settledCover != sheetCover { settledCover = sheetCover }
    }

    private func map(_ places: BookPlaces) -> some View {
        let current = current(in: places)
        let pins = pins(in: places)
        return PlacesMapView(
            pins: pins, dots: places.dots(inChapter: effectiveChapter), framing: places.framing(chapter: effectiveChapter),
            chosenPlaceID: current.placeID,
            selection: Binding(get: { current.pinID }, set: { choose(pin: $0, in: places) }),
            focus: current.pinID.flatMap { id in pins.first { $0.id == id } },
            onReopen: { [pinID = current.pinID] in reopen(pin: pinID, in: places) },
            bottomCover: settledCover)
            .safeAreaPadding(.bottom, sheetCover)
    }

    // MARK: - The list

    private func sheet(_ places: BookPlaces) -> some View {
        GeometryReader { outer in
            NavigationStack(path: sheetPath) {
                PhonePlacesList(
                    places: places, gathered: current(in: places).gathered(in: pins(in: places)), chapter: effectiveChapter,
                    order: $order, onChooseRow: { choose(row: $0, in: places) }, onChooseHeading: { choose(chapter: $0) })
                    .containerBackground(Color.paperPage, for: .navigation)
                    .toolbarVisibility(.hidden, for: .navigationBar)
                    .navigationDestination(for: PhoneLibraryPage.self) { page in
                        PhoneLibraryPageView(page: page, navigation: navigation, shell: shell, path: sheetPath)
                    }
            }
            .onChange(of: outer.size.height, initial: true) { _, height in
                // The sheet's height is the page it covers, at every tick of a drag; the camera's cover is taken once,
                // as the sheet first opens at its detent, and then a turn after each change of detent.
                if height != sheetCover { sheetCover = height }
                if settledCover == 0 { settleCover() }
            }
        }
        .presentationDetents(Self.detents, selection: $detent)
        .presentationContentInteraction(Self.contentInteraction)
        .presentationBackgroundInteraction(.enabled(upThrough: Self.tallest))
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        .tint(Color.accent)
    }
}
#endif
