import ScriptureData

/// Places in a book: the pins of its map and the list beside it.
public struct BookPlaces: Equatable, Sendable {
    /// The places at one point, gathered; it sits at its most-mentioned place's coordinates and takes its name.
    public struct Pin: Identifiable, Equatable, Sendable {
        /// The point.
        public let id: String
        public let latitude: Double, longitude: Double, places: [PlaceSummary], title: String, mentions: Int

        /// The chosen place's name when it is one of this pin's places, else the pin's own title (spec 4.3).
        public func title(choosing placeID: Int?) -> String {
            placeID.flatMap { id in places.first { $0.id == id }?.name } ?? title
        }
    }

    /// The map's centre and how much it shows.
    public struct Frame: Equatable, Sendable {
        public let latitude: Double, longitude: Double, latitudeSpan: Double, longitudeSpan: Double
    }

    /// One chapter that names a place: its places in the order the chapter first names them (the lowest verse
    /// naming each there; ties by the A to Z rule), and the verses naming each there (spec 5.4).
    public struct Chapter: Identifiable, Equatable, Sendable {
        public let number: Int
        public let places: [PlaceSummary]
        /// Place id to the verses naming it in this chapter.
        public let mentions: [Int: Int]
        /// The chapter's places that have a point, gathered by point (each pin's places in the book's list
        /// order), counted over the chapter's verses only.
        public let pins: [Pin]
        public var id: Int { number }
        /// The chapter's places that have a point on the map.
        public var onMapCount: Int { places.filter(\.isOnMap).count }
    }

    public let book: Book, onMap: [PlaceSummary], notOnMap: [PlaceSummary]
    /// A to Z (spec 5.3), sorted once at load: the places on the map, and those not.
    public let onMapByName: [PlaceSummary], notOnMapByName: [PlaceSummary]
    /// Spec 5.4: the chapters that name a place, in order; a chapter naming none is absent.
    public let chapters: [Chapter]
    /// Most mentions first, then title.
    public let pins: [Pin]

    public var title: String { "Places in \(book.name)" }

    /// "8 places · 6 on the map"; "1 place · 1 on the map".
    public var countLabel: String { countWords(separator: " · ") }

    /// The count as VoiceOver hears it: "101 places, 101 on the map".
    public var countSpoken: String { countWords(separator: ", ") }

    private func countWords(separator: String) -> String {
        let count = onMap.count + notOnMap.count
        return "\(count.formatted()) \(count == 1 ? "place" : "places")\(separator)\(onMap.count.formatted()) on the map"
    }

    public var frame: Frame? { Self.frame(pins) }

    /// Philemon: the data names no place in it, on the map or off it.
    public var namesNoPlace: Bool { onMap.isEmpty && notOnMap.isEmpty }

    public func chapter(_ number: Int) -> Chapter? {
        chapters.first { $0.number == number }
    }

    /// A chapter's own pins (nil: the book's; a chapter that names no place: none).
    public func pins(inChapter number: Int?) -> [Pin] {
        guard let number else { return pins }
        return chapter(number)?.pins ?? []
    }

    /// The book's other pins, drawn as dots: every pin whose point holds no pin of the chapter (none for nil).
    public func dots(inChapter number: Int?) -> [Pin] {
        guard let number else { return [] }
        let held = Set(pins(inChapter: number).map(\.id))
        return pins.filter { !held.contains($0.id) }
    }

    /// The book's frame rule over the chapter's pins; the whole book's frame when the chapter has none.
    public func frame(inChapter number: Int?) -> Frame? {
        let chosen = pins(inChapter: number)
        return chosen.isEmpty ? frame : Self.frame(chosen)
    }

    public func framing(chapter number: Int?, choice: Int = 0) -> PlacesFraming {
        PlacesFraming(chapter: number, frame: frame(inChapter: number), choice: choice)
    }

    public func pin(holding placeID: Int) -> Pin? {
        pins.first { $0.places.contains { $0.id == placeID } }
    }

    /// The box of the pins that carry nine tenths of the mentions (most-mentioned first), with a fifth of air
    /// on each side and never less than half a degree each way; nil for no pins.
    public static func frame(_ pins: [Pin]) -> Frame? {
        guard !pins.isEmpty else { return nil }
        let ordered = pins.sorted { $0.mentions != $1.mentions ? $0.mentions > $1.mentions : $0.title < $1.title }
        let total = ordered.reduce(0) { $0 + $1.mentions }
        var carried = 0
        var kept: [Pin] = []
        for pin in ordered {
            kept.append(pin)
            carried += pin.mentions
            if carried * 10 >= total * 9 { break }
        }
        let latitudes = kept.map(\.latitude), longitudes = kept.map(\.longitude)
        let (south, north) = (latitudes.min()!, latitudes.max()!), (west, east) = (longitudes.min()!, longitudes.max()!)
        return Frame(latitude: (south + north) / 2, longitude: (west + east) / 2,
                     latitudeSpan: max((north - south) * 1.4, 0.5), longitudeSpan: max((east - west) * 1.4, 0.5))
    }

    /// nil outside the 66.
    public static func load(book code: String, store: BibleStore) throws -> BookPlaces? {
        guard let book = BookCatalog.book(code: code), book.canon != .apocrypha else { return nil }
        let places = try store.placesNamed(inBook: code)
        let onMap = places.filter(\.isOnMap)
        let notOnMap = places.filter { !$0.isOnMap }
        let byChapter = try chapters(of: onMap, places, store.placeChapters(inBook: code))
        return BookPlaces(book: book, onMap: onMap, notOnMap: notOnMap, onMapByName: onMap.sorted(by: nameOrder),
                          notOnMapByName: notOnMap.sorted(by: nameOrder), chapters: byChapter,
                          pins: pins(of: onMap))
    }

    private static func nameOrder(_ a: PlaceSummary, _ b: PlaceSummary) -> Bool {
        LibraryNameOrder.precedes((a.name, a.label, a.id), (b.name, b.label, b.id))
    }

    /// The read's rows (chapter, first verse, place id) made into chapters, each in first-mention order with
    /// ties broken by the A to Z rule.
    private static func chapters(of onMap: [PlaceSummary], _ places: [PlaceSummary], _ rows: [PlaceChapterMention]) -> [Chapter] {
        let byID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: rows, by: \.chapter)
        return grouped.keys.sorted().map { number in
            let mentions = grouped[number] ?? []
            let ordered = mentions.compactMap { row in byID[row.placeID].map { (place: $0, first: row.firstVerse) } }
                .sorted { $0.first != $1.first ? $0.first < $1.first : nameOrder($0.place, $1.place) }
            // Every mention's place is one of the book's (one read gives both), so none is dropped from the list
            // while `mentions` still counts it.
            assert(ordered.count == mentions.count, "chapter \(number) names a place the book does not list")
            let verses = Dictionary(uniqueKeysWithValues: mentions.map { ($0.placeID, $0.verseCount) })
            // The book's list order, so a chapter's pin is titled as the book's is (Departure 5).
            let named = onMap.filter { verses[$0.id] != nil }
            return Chapter(number: number, places: ordered.map(\.place), mentions: verses,
                           pins: pins(of: named) { verses[$0.id] ?? 0 })
        }
    }

    /// The places gathered by point (each already in list order), the pins most mentions first.
    static func pins(of onMap: [PlaceSummary], mentions: (PlaceSummary) -> Int = \.verseCount) -> [Pin] {
        var order: [String] = []
        var byPoint: [String: [PlaceSummary]] = [:]
        for place in onMap {
            guard let point = place.point else { continue }
            if byPoint[point] == nil { order.append(point) }
            byPoint[point, default: []].append(place)
        }
        return order.compactMap { point -> Pin? in
            guard let places = byPoint[point], let lead = places.first, let latitude = lead.latitude, let longitude = lead.longitude else { return nil }
            return Pin(id: point, latitude: latitude, longitude: longitude, places: places, title: lead.name,
                       mentions: places.reduce(0) { $0 + mentions($1) })
        }
        .sorted { $0.mentions != $1.mentions ? $0.mentions > $1.mentions : $0.title < $1.title }
    }
}

/// What the map shows for a chosen chapter (nil: the book): the chapter and the frame to move to, and the count of
/// headings chosen, so the chapter chosen again by its heading (the Mac, with one of its rows chosen) is a new framing.
public struct PlacesFraming: Equatable, Sendable {
    public let chapter: Int?
    public let frame: BookPlaces.Frame?
    public var choice = 0
}

extension PlaceSummary {
    /// Has a point on the map (a coordinate pair and its point id).
    var isOnMap: Bool { latitude != nil && longitude != nil && point != nil }
}
