import ScriptureData
import SwiftUI

/// The Places list column (spec 5): the order control at the head, then the book's places in that order. Most named
/// and A to Z list the places on the map and, under "Not on the map", the rest; By chapter heads each chapter that
/// names a place with a heading that chooses the chapter. A row chooses its place (and its chapter, By chapter); a
/// heading chooses its chapter and closes the page. While the list holds the keyboard (spec 5.5), Up and Down move
/// between rows, skipping headings and crossing chapters; By chapter, Left and Right step between the chapters'
/// headings as a click does; at an end the key is taken and nothing moves. Esc is the front page's. The chosen
/// chapter lives in `place.placesChapter`; the order, on this device only.
struct LibraryPlacesList: View {
    let places: BookPlaces
    @Binding var place: LibraryPlace
    @Binding var selection: PlacesSelection
    /// A heading was chosen (by a click or ← →), whether or not the chapter changed: the map frames it again.
    let onChooseChapter: () -> Void

    @AppStorage(PlacesOrder.key) private var order: PlacesOrder = .mostNamed
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isFocused: Bool
    @State private var chosenRect: CGRect = .zero

    private nonisolated static let coordinateSpace = "places"

    init(places: BookPlaces, place: Binding<LibraryPlace>, selection: Binding<PlacesSelection>,
         onChooseChapter: @escaping () -> Void = {}) {
        self.places = places
        self._place = place
        self._selection = selection
        self.onChooseChapter = onChooseChapter
    }

    private var effectiveChapter: Int? { PlacesChapters.effective(place.placesChapter, order: order) }

    var body: some View {
        let items = PlacesList.items(places, order: order)
        let rows = PlacesList.rows(items)
        let chosenRow = PlacesList.chosenRowID(showing: place.showing, chapter: effectiveChapter, in: rows)
        let shared = LibraryPlacesView.sharedNames(places)
        let firstID = items.first?.id
        // The column's width is what it is offered (a GeometryReader's), not what the control asks for.
        return GeometryReader { column in
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    LibraryOrderPicker(selection: $order, orders: PlacesOrder.allCases, title: \.title,
                                       asMenu: !isSegmented(columnWidth: column.size.width))
                        .padding(AppSpacing.xs)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(items) { item in
                                view(item, firstID: firstID, chosenRow: chosenRow, shared: shared)
                            }
                        }
                        .padding(AppSpacing.xs)
                        .coordinateSpace(.named(Self.coordinateSpace))
                        #if os(macOS)
                        .contentShape(.focusEffect, LibraryChosenRowShape(rect: chosenRect))
                        #endif
                        .focusable()
                        .focused($isFocused)
                        .accessibilityElement(children: .contain)
                        .onKeyPress(.upArrow) { move(-1, in: rows, from: chosenRow) }
                        .onKeyPress(.downArrow) { move(1, in: rows, from: chosenRow) }
                        .onKeyPress(.leftArrow) { stepChapter(-1, rowChosen: chosenRow != nil) }
                        .onKeyPress(.rightArrow) { stepChapter(1, rowChosen: chosenRow != nil) }
                    }
                }
                // The chosen row (or, with none, the chosen heading) in view when it changes, by a click or a key:
                // the least scroll, a cut. With neither, no wash is drawn, so the focus ring leaves its last rectangle.
                .onChange(of: scrollTarget(chosenRow)) { _, id in
                    if let id { proxy.scrollTo(id) } else { chosenRect = .zero }
                }
                // Coming back to a place (from the reader, by Home): its row in view once laid out.
                .task {
                    await Task.yield()
                    if let id = scrollTarget(chosenRow) { proxy.scrollTo(id, anchor: .center) }
                }
                // A place shown another way (a walk, Back, the map) that the chosen chapter does not name moves the chapter.
                // Only a change is written: a mutating call through the binding writes even an unchanged place, and the
                // view going on Esc reads the place as none on show.
                .onChange(of: place.showing) {
                    if let followed = place.followed(in: places) { place = followed }
                }
                // Another order clears the chapter; the chosen place stays chosen and is brought into view.
                .onChange(of: order) {
                    let chapter = PlacesChapters.afterOrderChange(to: order, chosen: place.placesChapter)
                    if chapter != place.placesChapter { place.placesChapter = chapter }
                    Task {
                        await Task.yield()
                        let rows = PlacesList.rows(PlacesList.items(places, order: order))
                        let id = PlacesList.chosenRowID(showing: place.showing, chapter: effectiveChapter, in: rows)
                        if let id { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
    }

    private func isSegmented(columnWidth: CGFloat) -> Bool {
        PlacesOrderControl.isSegmented(width: columnWidth - 2 * AppSpacing.xs, dynamicTypeSize: dynamicTypeSize)
    }

    private func scrollTarget(_ chosenRow: String?) -> String? {
        chosenRow ?? effectiveChapter.map(PlacesList.headingID)
    }

    // MARK: - Items

    @ViewBuilder private func view(_ item: PlacesList.Item, firstID: String?, chosenRow: String?, shared: Set<String>) -> some View {
        switch item {
        case .row(let row):
            self.row(row, chosen: chosenRow == row.id, shared: shared)
        case .notOnMap:
            LibrarySectionHeader("Not on the map")
                .padding(.horizontal, AppSpacing.xs)
                .padding(.top, item.id == firstID ? 0 : AppSpacing.md)
                .padding(.bottom, AppSpacing.xxs)
        case .heading(let chapter):
            PlacesChapterHeading(
                chapter: chapter, isChosen: PlacesList.headingIsChosen(chapter.number, chapter: effectiveChapter),
                showsWash: PlacesList.headingShowsWash(chapter.number, chapter: effectiveChapter, chosenRow: chosenRow), horizontalPadding: AppSpacing.xs,
                onChosenRect: { chosenRect = $0 }, coordinateSpace: Self.coordinateSpace, isFirst: item.id == firstID,
                onChoose: { choose(chapter: chapter.number, rowChosen: chosenRow != nil) })
                .id(item.id)
        }
    }

    private func row(_ row: PlacesList.Row, chosen: Bool, shared: Set<String>) -> some View {
        let summary = row.place
        let byChapter = order == .byChapter
        let label = shared.contains(summary.name) ? summary.label : nil
        return LibraryListRow(
            id: row.id, name: summary.name, detail: LibraryPlacesView.detail(kind: summary.kind, label: label),
            count: byChapter ? nil : summary.verseCount, note: byChapter && !summary.isOnMap ? "not on the map" : nil,
            isDimmed: PlacesList.isDimmed(row, chapter: effectiveChapter), isChosen: chosen,
            accessibilityLabel: LibraryPlacesView.accessibilityLabel(summary, label: label),
            accessibilityHint: row.chapter.map(PlacesChapters.rowHint(chapter:)), coordinateSpace: Self.coordinateSpace,
            onChosenRect: { chosenRect = $0 }, onChoose: { choose(row) })
    }

    // MARK: - The choice

    /// A row: its place, and its chapter when it has one; the selection is over the chapter's pins now in effect.
    private func choose(_ row: PlacesList.Row) {
        place.choosePlace(row.place.id, inChapter: row.chapter)
        selection.choose(place: row.place.id, in: places.pins(inChapter: order == .byChapter ? row.chapter : nil))
    }

    /// A heading: the chapter is chosen (or, the chosen one again while it shows its wash, cleared) and no gathered pin
    /// is kept.
    private func choose(chapter number: Int, rowChosen: Bool) {
        place.chooseChapter(number, rowChosen: rowChosen)
        selection = PlacesSelection()
        onChooseChapter()
    }

    /// Up and Down through the rows as listed, headings skipped: each row's place is chosen, and its chapter (so a
    /// step across a heading moves the chapter and keeps the page). From a chosen heading with no row chosen the
    /// step starts at the heading. The row comes into view by `scrollTarget`'s change.
    private func move(_ step: Int, in rows: [PlacesList.Row], from chosenRow: String?) -> KeyPress.Result {
        guard isFocused, !rows.isEmpty else { return .ignored }
        guard let row = PlacesList.neighbour(of: chosenRow, step: step, in: rows, heading: effectiveChapter) else { return .handled }
        choose(row)
        return .handled
    }

    /// Left and Right, By chapter only: the previous or next chapter's heading is chosen as a click on it is (the
    /// page closes, the map takes the full height); with none chosen, Right takes the first and Left the last.
    /// The heading comes into view by `scrollTarget`'s change.
    private func stepChapter(_ step: Int, rowChosen: Bool) -> KeyPress.Result {
        guard isFocused, PlacesChapters.takesChapterKeys(order) else { return .ignored }
        guard let chapter = PlacesChapters.step(step, from: effectiveChapter, in: places) else { return .handled }
        choose(chapter: chapter, rowChosen: rowChosen)
        return .handled
    }
}
