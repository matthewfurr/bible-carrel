import CoreGraphics
import ScriptureData

/// An arrow key in the Mac's tree.
enum FamilyTreeKey: Sendable { case left, right, up, down }

/// The Mac tree's keyboard (spec 5.2, Departure 12) worked on one `FamilyTreeGeometry`, by slot id. Every
/// slot is a stop but the "Mother not named" label. Tab enters on the person; ← and → go to the nearest
/// stop on the same line; ↑ and ↓ to the nearest stop wholly above or below: the nearest line first, then
/// the least distance between centres, a tie to the leading side. At an edge a move keeps the focus where
/// it is (ruling 4), so no move lands on nothing.
enum FamilyTreeKeys {
    /// What Return or Space does on a stop.
    enum Activation: Equatable {
        case walk(PersonSummary), toggle(FamilyChip), nothing
    }

    /// Where Tab enters the tree: the person.
    static func start(_ geometry: FamilyTreeGeometry) -> String {
        geometry.slots.first { $0.kind == .person }?.id ?? stops(geometry).first?.id ?? "person"
    }

    /// The stop an arrow moves to from `id` (from where `id` falls back to, if it has gone); `id`'s own at an edge.
    static func next(from id: String, _ key: FamilyTreeKey, in geometry: FamilyTreeGeometry) -> String {
        let stops = stops(geometry)
        let id = fallback(for: id, in: geometry)
        guard let from = stops.first(where: { $0.id == id })?.frame else { return id }
        let others = stops.filter { $0.id != id }
        let found: FamilyTreeGeometry.Slot? = switch key {
        case .left, .right:
            others
                .filter { onOneLine($0.frame, from) && (key == .left ? $0.frame.midX < from.midX : $0.frame.midX > from.midX) }
                .min { abs($0.frame.midX - from.midX) < abs($1.frame.midX - from.midX) }
        case .up, .down:
            nearest(to: from, among: others.filter { key == .up ? $0.frame.maxY <= from.minY + slack : $0.frame.minY >= from.maxY - slack },
                    gap: { key == .up ? from.minY - $0.maxY : $0.minY - from.maxY })
        }
        return found?.id ?? id
    }

    /// Where the focus goes when its stop has gone with a fold (a resize, a chip): the stop itself while
    /// it is there; else the chip that took it (a chip that opened hands it to its "Fewer"); else the person.
    static func fallback(for id: String, in geometry: FamilyTreeGeometry) -> String {
        let ids = Set(stops(geometry).map(\.id))
        if ids.contains(id) { return id }
        let kind = id.prefix(while: { $0 != "-" })
        let chips: [FamilyChip] = switch kind {
        case "sibling": [.siblings]
        case "halfSibling": [.halfSiblings]
        case "head": [.households]
        // A child goes with its folded mother, or into the children's "n more" (a tree has one or the
        // other); the unnamed mother's children fold only by their own "Fewer".
        case "child": [.households, .children, .notNamed]
        case "fewer": FamilyChip.all.filter { id == "fewer-\($0)" }
        default: []
        }
        if let chip = chips.lazy.map({ "chip-\($0)" }).first(where: ids.contains) { return chip }
        if id.hasPrefix("chip-"), case let fewer = "fewer-" + id.dropFirst("chip-".count), ids.contains(fewer) { return fewer }
        return start(geometry)
    }

    /// Return walks to a name and opens or closes a chip ("Fewer" too); Space only opens or closes. Return
    /// on the person does nothing (Departure 12).
    static func activation(of slot: FamilyTreeGeometry.Slot, space: Bool) -> Activation {
        switch slot.kind {
        case .chip(let chip, _), .fewer(let chip): return .toggle(chip)
        case .person, .notNamedLabel: return .nothing
        case .grandparent(let person), .parent(let person, _), .sibling(let person), .halfSibling(let person), .child(let person, _):
            return space ? .nothing : .walk(person)
        case .head(let household):
            switch household.head {
            case .partner(let person), .otherParent(let person, _): return space ? .nothing : .walk(person)
            case .notNamed: return .nothing
            }
        }
    }

    /// How far two frames may overlap and still be one above the other: half a point, for rounding.
    private static let slack: CGFloat = 0.5

    private static func stops(_ geometry: FamilyTreeGeometry) -> [FamilyTreeGeometry.Slot] {
        geometry.slots.filter { if case .notNamedLabel = $0.kind { false } else { true } }
    }

    /// Two frames are on one line when either's middle is within the other's height: a name and a chip of
    /// one row are, though the chip is taller; a name and the next under it in a column are not.
    private static func onOneLine(_ a: CGRect, _ b: CGRect) -> Bool {
        (a.minY...a.maxY).contains(b.midY) || (b.minY...b.maxY).contains(a.midY)
    }

    /// The nearest line of `candidates` (by `gap`), and on it the stop whose centre is nearest `from`'s, a
    /// tie to the leading side. A row's chip is taller than its names, so the line, not the gap, decides.
    private static func nearest(to from: CGRect, among candidates: [FamilyTreeGeometry.Slot], gap: (CGRect) -> CGFloat) -> FamilyTreeGeometry.Slot? {
        guard let closest = candidates.min(by: { gap($0.frame) < gap($1.frame) }) else { return nil }
        let centre = CGPoint(x: from.midX, y: from.midY)
        func distance(_ slot: FamilyTreeGeometry.Slot) -> CGFloat { hypot(slot.frame.midX - centre.x, slot.frame.midY - centre.y) }
        return candidates
            .filter { onOneLine($0.frame, closest.frame) }
            .min { distance($0) != distance($1) ? distance($0) < distance($1) : $0.frame.midX < $1.frame.midX }
    }
}

private extension FamilyChip {
    static let all: [FamilyChip] = [.siblings, .halfSiblings, .households, .notNamed, .children]
}
