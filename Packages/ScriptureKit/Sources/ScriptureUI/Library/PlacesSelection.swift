import ScriptureData

/// What Places has chosen: a place, its pin, or a gathered pin with no place of its own yet. The list
/// and the map each choose through it, so each follows the other.
public struct PlacesSelection: Equatable, Sendable {
    public private(set) var placeID: Int?
    public private(set) var pinID: String?

    public init() {}

    /// The list (or a gathered pin's own rows): the place and its pin; no pin for one not on the map.
    public mutating func choose(place id: Int, in pins: [BookPlaces.Pin]) {
        placeID = id
        pinID = pins.first { $0.places.contains { $0.id == id } }?.id
    }

    public mutating func choose(place id: Int, in places: BookPlaces) { choose(place: id, in: places.pins) }

    /// The map: a pin of one place chooses that place; a gathered pin chooses none until one of its
    /// places is chosen; nil (a click on the map itself) chooses nothing.
    public mutating func choose(pin id: String?, in pins: [BookPlaces.Pin]) {
        let pin = id.flatMap { id in pins.first { $0.id == id } }
        pinID = pin?.id
        placeID = pin.flatMap { $0.places.count == 1 ? $0.places[0].id : nil }
    }

    public mutating func choose(pin id: String?, in places: BookPlaces) { choose(pin: id, in: places.pins) }

    /// A second click on a gathered pin whose place is chosen: the place is forgotten and the pin kept, so
    /// its places are listed. Nothing else changes (spec 4.3).
    public mutating func reopen(in pins: [BookPlaces.Pin]) {
        guard placeID != nil, let pinID, let pin = pins.first(where: { $0.id == pinID }), pin.places.count > 1 else { return }
        placeID = nil
    }

    /// The re-click, a turn after the tap on the pin `pinID`: the selection with its place forgotten (`reopen`), or nil
    /// when the map has moved on to another pin (or none) meanwhile, or when nothing would change (ruling 9).
    public func reopened(at pinID: String?, in pins: [BookPlaces.Pin]) -> PlacesSelection? {
        guard let pinID, self.pinID == pinID else { return nil }
        var reopened = self
        reopened.reopen(in: pins)
        return reopened == self ? nil : reopened
    }

    /// The selection as the place showing has it: a place walked to, stepped back to or returned to
    /// from the reader is chosen with its pin; nothing showing keeps a gathered pin's choice.
    public func following(_ showing: LibraryEntity?, in places: BookPlaces) -> PlacesSelection {
        following(showing, in: places.pins)
    }

    public func following(_ showing: LibraryEntity?, in pins: [BookPlaces.Pin]) -> PlacesSelection {
        var current = self
        if case .place(let id) = showing {
            if current.placeID != id { current.choose(place: id, in: pins) }
        } else if current.placeID != nil {
            current = PlacesSelection()
        }
        return current
    }

    /// The chosen pin's places, when it holds several and none of them is chosen.
    public func gathered(in pins: [BookPlaces.Pin]) -> [PlaceSummary]? {
        guard placeID == nil, let pinID, let pin = pins.first(where: { $0.id == pinID }), pin.places.count > 1 else { return nil }
        return pin.places
    }

    public func gathered(in places: BookPlaces) -> [PlaceSummary]? { gathered(in: places.pins) }
}
