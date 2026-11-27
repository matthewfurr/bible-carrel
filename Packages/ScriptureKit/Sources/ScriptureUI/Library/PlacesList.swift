import ScriptureData

/// The Places list's items in each order (spec 5.2 to 5.4), and which row is the chosen one.
public enum PlacesList {
    /// A place's row: under a chapter in By chapter (a place named in several chapters has a row under each).
    public struct Row: Identifiable, Hashable, Sendable {
        public let place: PlaceSummary
        public let chapter: Int?

        /// "636", or "2-636" under chapter 2.
        public var id: String { chapter.map { "\($0)-\(place.id)" } ?? "\(place.id)" }
    }

    public enum Item: Identifiable, Equatable, Sendable {
        case row(Row)
        /// The foot's "Not on the map" label (Most named and A to Z).
        case notOnMap
        case heading(BookPlaces.Chapter)

        public var id: String {
            switch self {
            case .row(let row): row.id
            case .notOnMap: "not-on-the-map"
            case .heading(let chapter): PlacesList.headingID(chapter.number)
            }
        }
    }

    /// Most named and A to Z: the places on the map, then "Not on the map" and the rest when there are any.
    /// By chapter: each chapter's heading, then its places (those without a point among them).
    public static func items(_ places: BookPlaces, order: PlacesOrder) -> [Item] {
        switch order {
        case .mostNamed: list(places.onMap, places.notOnMap)
        case .alphabetical: list(places.onMapByName, places.notOnMapByName)
        case .byChapter:
            places.chapters.flatMap { chapter in
                [Item.heading(chapter)] + chapter.places.map { .row(Row(place: $0, chapter: chapter.number)) }
            }
        }
    }

    public static func headingID(_ chapter: Int) -> String { "chapter-\(chapter)" }

    public static func rows(_ items: [Item]) -> [Row] {
        items.compactMap { if case .row(let row) = $0 { row } else { nil } }
    }

    /// The row of the place on show, under `chapter` when it has one there, else its first row; nil for none.
    public static func chosenRowID(showing: LibraryEntity?, chapter: Int?, in rows: [Row]) -> String? {
        guard case .place(let id)? = showing else { return nil }
        let matches = rows.filter { $0.place.id == id }
        return (chapter.flatMap { chapter in matches.first { $0.chapter == chapter } } ?? matches.first)?.id
    }

    /// The row ↑ (`-1`) or ↓ (`+1`) moves to from the row `id`, headings skipped (they are not rows), so a step can
    /// cross into another chapter's rows; nil past an end. With no row chosen, a chosen `heading` is where the step
    /// starts (↓ its first row, ↑ the row above it); with neither, ↓ takes the first row and ↑ the last.
    public static func neighbour(of id: String?, step: Int, in rows: [Row], heading: Int? = nil) -> Row? {
        if id == nil, let heading, let first = rows.firstIndex(where: { $0.chapter == heading }) {
            let target = step > 0 ? first : first - 1
            return rows.indices.contains(target) ? rows[target] : nil
        }
        let target = LibraryPeopleView.neighbour(of: id, step: step, in: rows.map(\.id))
        return rows.first { $0.id == target }
    }

    /// A heading is the chosen one (its selected trait) while it names the chapter in effect.
    public static func headingIsChosen(_ number: Int, chapter: Int?) -> Bool { chapter == number }

    /// A heading takes the wash only while no row is the chosen one: only the row clicked is washed.
    public static func headingShowsWash(_ number: Int, chapter: Int?, chosenRow: String?) -> Bool {
        headingIsChosen(number, chapter: chapter) && chosenRow == nil
    }

    /// A row of another chapter while one is chosen.
    public static func isDimmed(_ row: Row, chapter: Int?) -> Bool {
        chapter.map { row.chapter != $0 } ?? false
    }

    private static func list(_ onMap: [PlaceSummary], _ notOnMap: [PlaceSummary]) -> [Item] {
        let foot: [Item] = notOnMap.isEmpty ? [] : [.notOnMap] + notOnMap.map { .row(Row(place: $0, chapter: nil)) }
        return onMap.map { .row(Row(place: $0, chapter: nil)) } + foot
    }
}
