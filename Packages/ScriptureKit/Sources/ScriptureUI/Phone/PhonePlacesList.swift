#if os(iOS)
import ScriptureData
import SwiftUI

/// The phone's Places sheet, its root list (spec 5, 6.3): the count line (the chosen chapter's header line, else the
/// book's count), the order control under it, the places a gathered pin holds, then the book's places in the order
/// chosen. Most named and A to Z end in "Not on the map"; By chapter heads each chapter with a button that chooses it,
/// on the wash while chosen, and dims the rows of the others. A row keeps no chosen state: a tap pushes its page.
/// The control is segments while its measured width fits the sheet's inside and the text is not an accessibility
/// size, else a menu (`PlacesOrderControl`).
struct PhonePlacesList: View {
    let places: BookPlaces
    let gathered: [PlaceSummary]?
    let chapter: Int?
    @Binding var order: PlacesOrder
    let onChooseRow: (PlacesList.Row) -> Void
    let onChooseHeading: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The sheet's width as laid out; unmeasured, the control is offered everything and the first pass corrects it.
    /// A heading is a touch target of at least 44 pt at the default size, more as the text grows.
    @ScaledMetric(relativeTo: .body) private var headingHeight: CGFloat = 44
    @State private var sheetWidth: CGFloat = .infinity

    init(places: BookPlaces, gathered: [PlaceSummary]?, chapter: Int?, order: Binding<PlacesOrder>,
         onChooseRow: @escaping (PlacesList.Row) -> Void, onChooseHeading: @escaping (Int) -> Void) {
        self.places = places
        self.gathered = gathered
        self.chapter = chapter
        self._order = order
        self.onChooseRow = onChooseRow
        self.onChooseHeading = onChooseHeading
    }

    var body: some View {
        let items = PlacesList.items(places, order: order)
        let shared = LibraryPlacesView.sharedNames(places)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(PlacesChapters.countLine(places, chapter: chapter))
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xs)
                LibraryOrderPicker(selection: $order, orders: PlacesOrder.allCases, title: \.title, asMenu: !isSegmented)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                if let gathered {
                    // One child of the lazy stack, so its rows' ids do not meet the same places' rows below.
                    VStack(alignment: .leading, spacing: 0) {
                        header("\(gathered.count.formatted()) places here")
                        ForEach(gathered) { summary in
                            row(PlacesList.Row(place: summary, chapter: nil), shared: shared, showsCount: true)
                            if summary.id != gathered.last?.id { Divider() }
                        }
                        header(places.title)
                    }
                }
                ForEach(items.indices, id: \.self) { index in
                    item(items[index], next: items.indices.contains(index + 1) ? items[index + 1] : nil,
                         isFirst: index == 0, shared: shared)
                }
                LibraryCreditLine()
                    .padding(AppSpacing.lg)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { sheetWidth = $0 }
    }

    private var isSegmented: Bool {
        PlacesOrderControl.isSegmented(width: sheetWidth - 2 * AppSpacing.lg, dynamicTypeSize: dynamicTypeSize)
    }

    @ViewBuilder private func item(_ item: PlacesList.Item, next: PlacesList.Item?, isFirst: Bool, shared: Set<String>) -> some View {
        switch item {
        case .row(let value):
            row(value, shared: shared, showsCount: order != .byChapter)
            if case .row? = next { Divider() }
        case .notOnMap:
            header("Not on the map")
        case .heading(let value):
            PlacesChapterHeading(
                chapter: value, isChosen: PlacesList.headingIsChosen(value.number, chapter: chapter),
                showsWash: PlacesList.headingShowsWash(value.number, chapter: chapter, chosenRow: nil),
                horizontalPadding: AppSpacing.xs, onChosenRect: nil, coordinateSpace: nil, isFirst: isFirst,
                minimumHeight: headingHeight,
                onChoose: { onChooseHeading(value.number) })
                // The text sits at `lg` as the rows' do; the wash reaches `xs` past it, a rounded band, not edge to edge.
                .padding(.horizontal, AppSpacing.lg - AppSpacing.xs)
        }
    }

    private func row(_ row: PlacesList.Row, shared: Set<String>, showsCount: Bool) -> some View {
        let summary = row.place
        let label = shared.contains(summary.name) ? summary.label : nil
        return PhoneLibraryRow(
            name: summary.name, detail: LibraryPlacesView.detail(kind: summary.kind, label: label),
            count: showsCount ? summary.verseCount : nil,
            note: !showsCount && !summary.isOnMap ? "not on the map" : nil,
            isDimmed: PlacesList.isDimmed(row, chapter: chapter),
            accessibilityLabel: LibraryPlacesView.accessibilityLabel(summary, label: label),
            accessibilityHint: row.chapter.map(PlacesChapters.rowHint(chapter:))) { onChooseRow(row) }
    }

    private func header(_ title: String) -> some View {
        LibrarySectionHeader(title)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxs)
    }
}
#endif
