import ScriptureData
import SwiftUI

/// Places in a book (spec 6.3): the list at a scaled 232 pt beside the map; the map
/// and the list choose each other (`PlacesSelection`). The places the data cannot locate sit at
/// the list's foot under "Not on the map". Nothing floats over the map: with a place chosen the
/// map keeps the top (at least a scaled 240 pt and half the height) and the place's page sits
/// under it; a gathered pin chosen shows its places there as rows that choose. With nothing chosen
/// the map has the whole height.
///
/// With no list (the whole Bible, reached by name) the place's page has the width, under its own
/// pin's map at half a degree, or with no map for a place the data cannot locate.
struct LibraryPlacesView: View {
    let places: BookPlaces?
    let page: PlacePage?
    @Binding var place: LibraryPlace
    let navigation: NavigationModel
    let onWalk: (LibraryEntity) -> Void
    let onOpen: (Reference) -> Void

    /// Places' own column, wider than People's 200 so the order control's three segments (210 pt at the least,
    /// measured: `PlacesOrderControl`) fit inside it (216) as they do in People's.
    @ScaledMetric(relativeTo: .body) private var listWidth: CGFloat = 232
    @ScaledMetric(relativeTo: .body) private var mapMinHeight: CGFloat = 240
    @Environment(\.libraryType) private var type
    /// A gathered pin chosen on the map, which leaves no place showing; the rest follows the place.
    @State private var selection = PlacesSelection()
    /// The headings chosen so far: the chapter's heading chosen again with one of its rows chosen keeps the chapter, and
    /// the map still frames it at its full height.
    @State private var chapterChoice = 0
    @AppStorage(PlacesOrder.key) private var order: PlacesOrder = .mostNamed

    /// The gathered pin's rows report no chosen rectangle; they have a space of their own.
    private nonisolated static let gatheredCoordinateSpace = "places-gathered"

    var body: some View {
        HStack(spacing: 0) {
            if let places {
                LibraryPlacesList(places: places, place: $place, selection: $selection, onChooseChapter: { chapterChoice += 1 })
                    .frame(width: type.metric(listWidth))
                HairlineRule(.vertical)
                detail(places)
            } else if let page {
                wholeBible(page)
            }
        }
        // Another book's places: a gathered pin chosen in the last book is forgotten.
        .onChange(of: places?.book.id) { selection = PlacesSelection() }
        // Every change of the chapter in effect is announced, the whole book's count when it clears.
        .onChange(of: effectiveChapter) { _, chapter in
            guard let places else { return }
            AccessibilityNotification.Announcement(PlacesChapters.announcementText(places, chapter: chapter)).post()
        }
    }

    /// The chosen chapter, while the order is By chapter.
    private var effectiveChapter: Int? { PlacesChapters.effective(place.placesChapter, order: order) }

    /// The pins the map draws and the choice runs over: the chapter's, or the book's.
    private func pins(in places: BookPlaces) -> [BookPlaces.Pin] { places.pins(inChapter: effectiveChapter) }

    // MARK: - The choice

    /// The selection as the place showing has it: a place walked to, stepped back to or returned
    /// to from the reader is chosen with its pin; nothing showing keeps a gathered pin's choice.
    private func current(in places: BookPlaces) -> PlacesSelection {
        selection.following(place.showing, in: pins(in: places))
    }

    private func choose(place id: Int, in places: BookPlaces) {
        selection.choose(place: id, in: pins(in: places))
        place.choose(.place(id))
    }

    /// The map's write. One that repeats the pin already chosen (the map echoing a choice made in
    /// the list) changes nothing, so a place chosen inside a gathered pin stays chosen.
    private func choose(pin id: String?, in places: BookPlaces) {
        guard id != current(in: places).pinID else { return }
        selection.choose(pin: id, in: pins(in: places))
        if let id = selection.placeID { place.choose(.place(id)) } else { place.clearTrail() }
    }

    /// A click on the chosen gathered pin, a turn after it: its places are listed again, unless the map
    /// gave the click to another pin meanwhile. The trail clears only when the selection changed.
    private func reopen(pin id: String?, in places: BookPlaces) {
        guard let reopened = current(in: places).reopened(at: id, in: pins(in: places)) else { return }
        selection = reopened
        place.clearTrail()
    }

    // MARK: - The map and what is under it

    private func detail(_ places: BookPlaces) -> some View {
        let current = current(in: places)
        let gathered = current.gathered(in: pins(in: places))
        let hasChoice = page != nil || gathered != nil
        return GeometryReader { geometry in
            VStack(spacing: 0) {
                if !places.pins.isEmpty {
                    map(places, current: current)
                        .frame(height: hasChoice ? max(mapMinHeight, geometry.size.height / 2) : nil)
                    HairlineRule()
                }
                if let page {
                    pageView(page)
                } else if let gathered {
                    gatheredRows(gathered, in: places)
                } else if places.pins.isEmpty {
                    hint
                } else {
                    // Nothing chosen: the map has the height but the credit's line.
                    LibraryCreditLine()
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The chapter's pins framed, the book's other points as dots, or the book's pins and frame.
    private func map(_ places: BookPlaces, current: PlacesSelection) -> some View {
        let pins = pins(in: places)
        return PlacesMapView(
            pins: pins, dots: places.dots(inChapter: effectiveChapter), framing: places.framing(chapter: effectiveChapter, choice: chapterChoice),
            chosenPlaceID: current.placeID,
            selection: Binding(get: { current.pinID }, set: { choose(pin: $0, in: places) }),
            focus: current.pinID.flatMap { id in pins.first { $0.id == id } },
            onReopen: { [pinID = current.pinID] in reopen(pin: pinID, in: places) })
            .id(places.book.id)
    }

    private func pageView(_ page: PlacePage) -> some View {
        PlacePageView(
            page: page, bookName: place.book.flatMap { BookCatalog.book(code: $0)?.name }, navigation: navigation,
            toggledBooks: $place.toggledBooks, anchor: place.anchor, onWalk: onWalk, onOpen: onOpen)
            .id(page.place.summary.id)
    }

    /// "2 places here", then the pin's places as the list's rows, lined up with a place's page: in its column, the
    /// rows' own padding hanging outside it.
    private func gatheredRows(_ gathered: [PlaceSummary], in places: BookPlaces) -> some View {
        let shared = Self.sharedNames(places)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LibrarySectionHeader("\(gathered.count.formatted()) places here")
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.xs)
                ForEach(gathered) { summary in
                    row(summary, sharedNames: shared, isChosen: false, coordinateSpace: Self.gatheredCoordinateSpace) {
                        choose(place: summary.id, in: places)
                    }
                }
            }
            .libraryColumn(outset: AppSpacing.xs)
            .padding(.horizontal, AppSpacing.lg - AppSpacing.xs)
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A book whose places none of which the data can locate: no map, the page has the height.
    private var hint: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choose a place.")
                .font(type.font(.callout))
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: AppSpacing.lg)
            LibraryCreditLine()
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The whole Bible's page: its own pin's map above it, or no map for a place not on it.
    private func wholeBible(_ page: PlacePage) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let pin = page.pin {
                    PlacesMapView(pins: [pin], framing: PlacesFraming(chapter: nil, frame: BookPlaces.frame([pin])),
                                  selection: .constant(nil), focus: nil)
                        .frame(height: max(mapMinHeight, geometry.size.height / 2))
                        .id(page.place.summary.id)
                    HairlineRule()
                }
                pageView(page)
            }
        }
    }

    // MARK: - Rows

    /// A row of a gathered pin's list under the map, chosen by none (the place showing has its page).
    private func row(_ summary: PlaceSummary, sharedNames: Set<String>, isChosen: Bool, coordinateSpace: String,
                     onChoose: @escaping () -> Void) -> some View {
        let label = sharedNames.contains(summary.name) ? summary.label : nil
        return LibraryListRow(
            id: summary.id, name: summary.name, detail: Self.detail(kind: summary.kind, label: label), count: summary.verseCount,
            isChosen: isChosen, accessibilityLabel: Self.accessibilityLabel(summary, label: label), coordinateSpace: coordinateSpace,
            onChosenRect: { _ in }, onChoose: onChoose)
    }

    /// The names two or more of the book's places share: as in People, only those rows carry the
    /// data's label that tells them apart.
    nonisolated static func sharedNames(_ places: BookPlaces) -> Set<String> {
        var uses: [String: Int] = [:]
        for summary in places.onMap + places.notOnMap { uses[summary.name, default: 0] += 1 }
        return Set(uses.filter { $0.value > 1 }.keys)
    }

    /// A row's second line: its kind and, for a shared name, what tells it apart ("city · Syria").
    nonisolated static func detail(kind: String?, label: String?) -> String? {
        let parts = [kind, label].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Antioch, city, Syria, 14 verses".
    nonisolated static func accessibilityLabel(_ summary: PlaceSummary, label: String?) -> String {
        let count = summary.verseCount == 1 ? "1 verse" : "\(summary.verseCount.formatted()) verses"
        return [summary.name, summary.kind, label, count].compactMap { $0 }.joined(separator: ", ")
    }
}
