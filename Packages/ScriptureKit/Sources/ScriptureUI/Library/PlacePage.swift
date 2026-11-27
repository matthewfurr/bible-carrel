import ScriptureData

/// One place's page: where it is and the verses that name it.
public struct PlacePage: Equatable, Sendable {
    public let place: PlaceRecord, sameSpot: [PlaceSummary], here: VerseGroup?, elsewhere: [VerseGroup]

    /// "city · approximate", "approximate", "city"; nil with neither.
    public var kindLine: String? {
        let parts = [place.summary.kind, place.summary.isApproximate ? "approximate" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public var alsoCalledLine: String? {
        place.alsoCalled.isEmpty ? nil : "also called " + place.alsoCalled.joined(separator: ", ")
    }

    public var isOnMap: Bool { pin != nil }

    /// Itself alone, for the whole-Bible page's map; nil when the data cannot locate it.
    public var pin: BookPlaces.Pin? {
        let summary = place.summary
        guard let latitude = summary.latitude, let longitude = summary.longitude, let point = summary.point else { return nil }
        return BookPlaces.Pin(id: point, latitude: latitude, longitude: longitude, places: [summary], title: summary.name,
                              mentions: summary.verseCount)
    }

    /// nil when there is no such place.
    public static func load(_ id: Int, inBook book: String?, store: BibleStore) throws -> PlacePage? {
        guard let place = try store.place(id) else { return nil }
        let verses = VerseGroup.split(try store.verses(ofPlace: id), inBook: book)
        return PlacePage(place: place, sameSpot: try store.places(sharingPointWith: id, inBook: book),
                         here: verses.here, elsewhere: verses.elsewhere)
    }
}
