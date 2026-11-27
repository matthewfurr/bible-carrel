#if os(macOS)
import CoreGraphics
import ScriptureData
import Testing
@testable import ScriptureUI

/// The Mac tree's keys (spec 5.2, Departure 12; rulings 4 and 30) on David's tree in 2 Samuel, laid with the
/// system's fonts at the default column (472) and at a width where nothing folds across (2,000).
@Suite struct FamilyTreeKeysTests {
    private func david(_ width: CGFloat, open: Set<FamilyChip> = []) throws -> FamilyTreeGeometry {
        let tree = try #require(try PersonPage.load(994, inBook: "2SA", store: BenchmarkChapter.realStore())).family
        return FamilyTreeGeometry.make(tree, width: width, open: open, rowPitch: FamilyTreeView.rowPitch, measure: SystemFamilyTreeMeasure())
    }

    /// The id of the slot that shows `name` (a person's name; the first such slot).
    private func id(_ name: String, in geometry: FamilyTreeGeometry) throws -> String {
        try #require(geometry.slots.first { Self.name(of: $0.kind) == name }?.id, "no \(name)")
    }

    private func slot(_ id: String, in geometry: FamilyTreeGeometry) throws -> FamilyTreeGeometry.Slot {
        try #require(geometry.slots.first { $0.id == id }, "no \(id)")
    }

    private static func name(of kind: FamilyTreeGeometry.Slot.Kind) -> String? {
        switch kind {
        case .grandparent(let person), .parent(let person, _), .sibling(let person), .halfSibling(let person), .child(let person, _):
            person.name
        case .head(let household):
            switch household.head {
            case .partner(let person), .otherParent(let person, _): person.name
            case .notNamed: nil
            }
        case .person, .notNamedLabel, .chip, .fewer: nil
        }
    }

    private func move(_ name: String, _ key: FamilyTreeKey, in geometry: FamilyTreeGeometry) throws -> String? {
        let to = FamilyTreeKeys.next(from: try id(name, in: geometry), key, in: geometry)
        return geometry.slots.first { $0.id == to }.flatMap { Self.name(of: $0.kind) } ?? to
    }

    @Test(.needsRealBible) func tabEntersOnThePerson() throws {
        for width: CGFloat in [472, 2_000] {
            #expect(FamilyTreeKeys.start(try david(width)) == "person")
        }
    }

    @Test(.needsRealBible) func upAndDownGoToTheNearestGeneration() throws {
        for width: CGFloat in [472, 2_000] {
            let tree = try david(width)
            #expect(FamilyTreeKeys.next(from: "person", .up, in: tree) == (try id("Jesse", in: tree)), "at \(width)")
            #expect(try move("Jesse", .up, in: tree) == "Obed", "at \(width)")
            #expect(try move("Obed", .up, in: tree) == "Obed", "at \(width)")
            #expect(try move("Obed", .down, in: tree) == "Jesse", "at \(width)")

            // ↓ from the person: the mothers' head nearest the person's centre, not a chip on that row.
            let person = try slot("person", in: tree)
            let heads = tree.slots.filter { if case .head = $0.kind { true } else { false } }
            let nearest = try #require(heads.min { abs($0.frame.midX - person.frame.midX) < abs($1.frame.midX - person.frame.midX) })
            #expect(FamilyTreeKeys.next(from: "person", .down, in: tree) == nearest.id, "at \(width)")

            #expect(try move("Bathsheba", .down, in: tree) == "Nathan", "at \(width)")
            #expect(try move("Nathan", .down, in: tree) == "Shobab", "at \(width)")
            #expect(try move("Shobab", .up, in: tree) == "Nathan", "at \(width)")
            #expect(try move("Nathan", .up, in: tree) == "Bathsheba", "at \(width)")
            #expect(try move("Shammua", .down, in: tree) == "Shammua", "at \(width)")
        }
        let narrow = try david(472)
        #expect(try move("Jesse", .down, in: narrow) == "person")
        #expect(FamilyTreeKeys.next(from: "person", .down, in: narrow) == (try id("Bathsheba", in: narrow)))
        let wide = try david(2_000)
        #expect(FamilyTreeKeys.next(from: "person", .down, in: wide) == (try id("Eglah", in: wide)))
    }

    @Test(.needsRealBible) func leftAndRightStayOnTheLine() throws {
        let wide = try david(2_000)
        #expect(FamilyTreeKeys.next(from: "person", .left, in: wide) == (try id("Shammah", in: wide)))
        #expect(FamilyTreeKeys.next(from: "person", .right, in: wide) == "halfSibling-27")
        #expect(FamilyTreeKeys.next(from: "halfSibling-27", .left, in: wide) == "person")
        #expect(try move("Eliab", .left, in: wide) == "Abinadab")
        #expect(try move("Abinadab", .left, in: wide) == "Abinadab")
        let firstHead = try #require(wide.slots.first { if case .head = $0.kind { true } else { false } })
        #expect(FamilyTreeKeys.next(from: firstHead.id, .left, in: wide) == firstHead.id)
        // Michal ends the named mothers; "Mother not named" beside her is a label, not a stop.
        #expect(try move("Michal", .right, in: wide) == "Michal")
        #expect(try move("Nathan", .right, in: wide) == "Ithream")

        let narrow = try david(472)
        #expect(FamilyTreeKeys.next(from: "person", .left, in: narrow) == "chip-siblings")
        #expect(FamilyTreeKeys.next(from: "person", .right, in: narrow) == "halfSibling-27")
        #expect(FamilyTreeKeys.next(from: "chip-siblings", .left, in: narrow) == "chip-siblings")
        #expect(FamilyTreeKeys.next(from: "halfSibling-3055", .right, in: narrow) == "halfSibling-3055")
    }

    /// The opened "4 more" is a second row of the tree (Matt's B, 2026-11-24), and the keys walk it as any row: ↓ from the
    /// first row's lowest name reaches it, ← → go along it to "Fewer", ↓ and ↑ go between a mother and her child, and
    /// Space on "4 more" hands the focus to its "Fewer", Space there back to the chip.
    @Test(.needsRealBible) func theKeysWalkTheOpenedSecondRow() throws {
        let closed = try david(472), open = try david(472, open: [.households])
        let second = try ["Eglah", "Haggith", "Maacah", "Michal"].map { try slot(try id($0, in: open), in: open) }
        let shammua = try slot(try id("Shammua", in: open), in: open)
        let nearest = try #require((second + [try slot("fewer-households", in: open)]).min {
            abs($0.frame.midX - shammua.frame.midX) < abs($1.frame.midX - shammua.frame.midX)
        })
        #expect(FamilyTreeKeys.next(from: shammua.id, .down, in: open) == nearest.id)
        #expect(try move("Eglah", .up, in: open) == "Shammua")
        #expect(try move("Eglah", .right, in: open) == "Haggith")
        #expect(try move("Haggith", .right, in: open) == "Maacah")
        #expect(try move("Maacah", .right, in: open) == "Michal")
        #expect(try move("Michal", .right, in: open) == "fewer-households")
        #expect(FamilyTreeKeys.next(from: "fewer-households", .right, in: open) == "fewer-households")
        #expect(FamilyTreeKeys.next(from: "fewer-households", .left, in: open) == second[3].id)
        #expect(try move("Haggith", .left, in: open) == "Eglah")
        #expect(try move("Eglah", .down, in: open) == "Ithream")
        #expect(try move("Ithream", .up, in: open) == "Eglah")
        #expect(try move("Ithream", .right, in: open) == "Adonijah")
        // Space on the chip opens it; the focus goes to its "Fewer", and back to the chip when Space there closes it.
        #expect(FamilyTreeKeys.activation(of: try slot("chip-households", in: closed), space: true) == .toggle(.households))
        #expect(FamilyTreeKeys.fallback(for: "chip-households", in: open) == "fewer-households")
        #expect(FamilyTreeKeys.activation(of: try slot("fewer-households", in: open), space: true) == .toggle(.households))
        #expect(FamilyTreeKeys.fallback(for: "fewer-households", in: closed) == "chip-households")
        // Return on a name of the second row walks to her.
        guard case .head(let household) = second[0].kind, case .partner(let eglah) = household.head else {
            Issue.record("Eglah is not a partner's head")
            return
        }
        #expect(FamilyTreeKeys.activation(of: second[0], space: false) == .walk(eglah))
    }

    /// Every move from every stop lands on a stop of the same tree (ruling 4): never on nothing, never on the
    /// "Mother not named" label; at an edge the move keeps the focus where it is.
    @Test(.needsRealBible) func everyMoveLandsOnAStop() throws {
        let every: Set<FamilyChip> = [.siblings, .halfSiblings, .households, .notNamed, .children]
        for (width, open) in [(CGFloat(472), Set<FamilyChip>()), (2_000, []), (472, every), (332, every)] {
            let tree = try david(width, open: open)
            let stops = Set(tree.slots.filter { if case .notNamedLabel = $0.kind { false } else { true } }.map(\.id))
            #expect(stops.contains(FamilyTreeKeys.start(tree)))
            for from in stops {
                for key in [FamilyTreeKey.left, .right, .up, .down] {
                    let to = FamilyTreeKeys.next(from: from, key, in: tree)
                    #expect(stops.contains(to), "at \(width) open \(open.count): \(from) \(key) → \(to)")
                }
            }
        }
    }

    @Test(.needsRealBible) func aStopThatFoldsAwayFallsBackToItsChip() throws {
        let narrow = try david(472)
        #expect(FamilyTreeKeys.fallback(for: "sibling-44", in: narrow) == "chip-siblings")
        #expect(FamilyTreeKeys.fallback(for: "head-partner-2073", in: narrow) == "chip-households")
        #expect(FamilyTreeKeys.fallback(for: "child-59", in: narrow) == "chip-households")
        #expect(FamilyTreeKeys.fallback(for: "fewer-siblings", in: narrow) == "chip-siblings")
        // A stop still there keeps the focus; one with no chip to take it falls back to the person.
        #expect(FamilyTreeKeys.fallback(for: "halfSibling-27", in: narrow) == "halfSibling-27")
        #expect(FamilyTreeKeys.fallback(for: "parent-1", in: narrow) == "person")
        // A chip that opens hands the focus to its "Fewer", so Space folds it again.
        let open = try david(472, open: [.siblings])
        #expect(FamilyTreeKeys.fallback(for: "chip-siblings", in: open) == "fewer-siblings")
        #expect(FamilyTreeKeys.fallback(for: "sibling-44", in: open) == "sibling-44")
        // A move from a stop that has gone starts from where it fell back to.
        #expect(FamilyTreeKeys.next(from: "sibling-44", .right, in: narrow) == "person")
    }

    /// The page scrolls the focused stop into view by its scroll id (review Important 1): the stop the focus
    /// settles on, so after Space on "11" it is the band's "Fewer" at the tree's foot; none with no focus.
    @Test(.needsRealBible) func theFocusedStopIsScrolledIntoView() throws {
        let narrow = try david(472)
        #expect(FamilyTreeView.revealID(focused: "person", in: narrow) == LibraryScrollID.tree("person"))
        #expect(FamilyTreeView.revealID(focused: "child-2547", in: narrow) == "tree-child-2547")
        #expect(FamilyTreeView.revealID(focused: "sibling-44", in: narrow) == "tree-chip-siblings")
        let open = try david(472, open: [.notNamed])
        #expect(FamilyTreeView.revealID(focused: "chip-notNamed", in: open) == "tree-fewer-notNamed")
        #expect(FamilyTreeView.revealID(focused: nil, in: open) == nil)
        // Each stop has a scroll id of its own.
        let every = try david(332, open: [.siblings, .halfSiblings, .households, .notNamed, .children])
        let ids = every.slots.map { LibraryScrollID.tree($0.id) }
        #expect(Set(ids).count == ids.count)
    }

    /// Return walks to a name and opens or closes a chip; Space opens or closes a chip and does nothing on
    /// a name; Return on the person does nothing (Departure 12).
    @Test(.needsRealBible) func returnWalksAndSpaceOpensAFold() throws {
        let narrow = try david(472)
        let nathan = try slot(try id("Nathan", in: narrow), in: narrow)
        guard case .child(let person, _) = nathan.kind else { Issue.record("Nathan is not a child"); return }
        #expect(FamilyTreeKeys.activation(of: nathan, space: false) == .walk(person))
        #expect(FamilyTreeKeys.activation(of: nathan, space: true) == .nothing)
        let bathsheba = try slot(try id("Bathsheba", in: narrow), in: narrow)
        guard case .head(let household) = bathsheba.kind, case .partner(let partner) = household.head else {
            Issue.record("Bathsheba is not a partner's head")
            return
        }
        #expect(FamilyTreeKeys.activation(of: bathsheba, space: false) == .walk(partner))
        let chip = try slot("chip-siblings", in: narrow)
        #expect(FamilyTreeKeys.activation(of: chip, space: false) == .toggle(.siblings))
        #expect(FamilyTreeKeys.activation(of: chip, space: true) == .toggle(.siblings))
        let fewer = try slot("fewer-siblings", in: try david(472, open: [.siblings]))
        #expect(FamilyTreeKeys.activation(of: fewer, space: true) == .toggle(.siblings))
        #expect(FamilyTreeKeys.activation(of: fewer, space: false) == .toggle(.siblings))
        let david = try slot("person", in: narrow)
        #expect(FamilyTreeKeys.activation(of: david, space: false) == .nothing)
        #expect(FamilyTreeKeys.activation(of: david, space: true) == .nothing)
    }
}
#endif
