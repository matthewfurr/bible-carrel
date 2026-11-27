import ScriptureData
import Testing
@testable import ScriptureUI

/// The phone's line and household (spec 5.3): `FamilyLine.rows` on the real data and on trees built in code.
@Suite struct FamilyLineTests {
    private func page(_ id: Int, _ book: String?) throws -> PersonPage {
        try #require(try PersonPage.load(id, inBook: book, store: BenchmarkChapter.realStore()))
    }

    private func person(_ id: Int, _ name: String) -> PersonSummary {
        PersonSummary(id: id, name: name, label: nil, verseCount: 1)
    }

    private let me = PersonSummary(id: 1, name: "Me", label: nil, verseCount: 1)

    private func names(_ people: [PersonSummary]) -> [String] { people.map(\.name) }

    /// A row as a short string, so a whole line compares in one `#expect`.
    private func word(_ row: FamilyLine.Row) -> String {
        switch row {
        case .grandparent(let who): "grandparent \(who.name)"
        case .parent(let who, let relation): "\(relation.rawValue) \(who.name)"
        case .siblings(let people, let more, let half): "\(half ? "half" : "siblings") \(names(people).joined(separator: ",")) +\(more)"
        case .person(let who): "person \(who.name)"
        case .head(let household):
            switch household.head {
            case .partner(let who): "partner \(who.name)"
            case .otherParent(let who, _): "other \(who.name)"
            case .notNamed(let relation): "notNamed \(relation.rawValue)"
            }
        case .moreHeads(let count): "moreHeads \(count)"
        case .children(let people): "children \(names(people).joined(separator: ","))"
        }
    }

    private func words(_ tree: FamilyTree, open: Set<FamilyChip> = []) -> [String] {
        FamilyLine.rows(tree, open: open).map(word)
    }

    /// A person with `partners` partners, each with one child.
    private func partnered(_ partners: Int, siblings: Int = 0) -> FamilyTree {
        var relatives: [Relative] = []
        var parents: [Int: [Relative]] = [:]
        for index in 0..<partners {
            let partner = person(100 + index, "P\(index)"), child = person(200 + index, "c\(index)")
            relatives += [Relative(kind: .partner, person: partner), Relative(kind: .child, person: child)]
            parents[child.id] = [Relative(kind: .mother, person: partner)]
        }
        for index in 0..<siblings { relatives.append(Relative(kind: .sibling, person: person(300 + index, "S\(index)"))) }
        return FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: parents, parentsOfParents: [:])
    }

    @Test(.needsRealBible) func davidsLineAndHousehold() throws {
        let tree = try page(994, "2SA").family
        let rows = words(tree)
        #expect(rows.prefix(5) == ["grandparent Obed", "father Jesse", "siblings Abinadab,Eliab,Elihu +4", "half Abigail,Zeruiah +0", "person David"])
        let heads = rows.filter { $0.hasPrefix("partner") || $0.hasPrefix("moreHeads") || $0.hasPrefix("notNamed") }
        #expect(heads == ["partner Abigail", "partner Abital", "partner Ahinoam", "moreHeads 5", "notNamed mother"])
        #expect(FamilyLine.moreHeads(5) == "and 5 more partners")
        let open = FamilyLine.rows(tree, open: [.siblings, .households])
        let siblings = open.compactMap { row -> [PersonSummary]? in
            if case .siblings(let people, 0, false) = row { people } else { nil }
        }
        #expect(names(siblings.first ?? []) == ["Abinadab", "Eliab", "Elihu", "Nethaneel", "Ozem", "Raddai", "Shammah"])
        let partners = open.map(word).filter { $0.hasPrefix("partner") }
        #expect(partners.count == 8 && !open.map(word).contains { $0.hasPrefix("moreHeads") })
    }

    @Test(.needsRealBible) func jacobsFourPartnersAllShow() throws {
        let rows = words(try page(682, "GEN").family)
        #expect(rows.prefix(7) == ["grandparent Abraham", "grandparent Sarah", "grandparent Bethuel", "father Isaac", "mother Rebekah",
                                   "siblings Esau +0", "person Jacob"])
        #expect(rows.filter { $0.hasPrefix("partner") } == ["partner Bilhah", "partner Leah", "partner Rachel", "partner Zilpah"])
        #expect(!rows.contains { $0.hasPrefix("moreHeads") })
    }

    @Test(.needsRealBible) func jessesChildrenFollowHimWithNoLabel() throws {
        let rows = FamilyLine.rows(try page(903, "RUT").family, open: [])
        let last = rows.suffix(2).map(word)
        #expect(last.first == "person Jesse")
        if case .children(let people) = rows.last { #expect(people.count == 8) } else { Issue.record("no children row last") }
    }

    @Test func theWordsAreTheDatasOwn() {
        #expect(FamilyLine.namesText("Siblings", ["Abinadab", "Eliab", "Elihu"], more: 4) == "Siblings: Abinadab, Eliab, Elihu and 4 more")
        #expect(FamilyLine.namesText("Half-siblings", ["Abigail", "Zeruiah"], more: 0) == "Half-siblings: Abigail and Zeruiah")
        #expect(FamilyLine.namesText("Siblings", ["Esau"], more: 0) == "Siblings: Esau")
        #expect(FamilyLine.moreHeads(5) == "and 5 more partners")
        #expect(FamilyLine.shownNames == 3)
        // Exactly four of a kind all show: a fold hides two or more (Departure 23).
        let four = partnered(4, siblings: 4)
        let rows = words(four)
        #expect(rows.contains("siblings S0,S1,S2,S3 +0"))
        #expect(rows.filter { $0.hasPrefix("partner") }.count == 4 && !rows.contains { $0.hasPrefix("moreHeads") })
        let five = words(partnered(5, siblings: 5))
        #expect(five.contains("siblings S0,S1,S2 +2") && five.contains("moreHeads 2"))
        // The words the app composes never say what the data does not know.
        let composed = ([FamilyLine.moreHeads(5), FamilyLine.namesText("Siblings", ["A", "B"], more: 4), FamilyLine.notNamed(.mother),
                         FamilyLine.notNamed(.father)] + Relation.allCases.map(FamilyLine.relationWord)).joined(separator: " ")
        let wordsIn = Set(composed.lowercased().split { !$0.isLetter }.map(String.init))
        for banned in ["son", "daughter", "brother", "sister", "grandfather"] { #expect(!wordsIn.contains(banned)) }
        #expect(FamilyLine.notNamed(.mother) == "Mother not named" && FamilyLine.notNamed(.father) == "Father not named")
    }

    @Test func aGrandparentTwoParentsShareShowsOnce() {
        let terah = person(50, "Terah")
        let relatives = [Relative(kind: .father, person: person(2, "F")), Relative(kind: .mother, person: person(3, "M"))]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [:], parentsOfParents: [
            2: [Relative(kind: .father, person: terah)], 3: [Relative(kind: .father, person: terah)]])
        #expect(words(tree) == ["grandparent Terah", "father F", "mother M", "person Me"])
    }

    @Test func theTrunkJoinsTheLineAndStopsAtTheLastElbow() {
        let tree = partnered(2)
        let rows = FamilyLine.rows(tree, open: [])
        #expect(rows.map(word) == ["person Me", "partner P0", "children c0", "partner P1", "children c1"])
        let trunk = FamilyLine.trunks(rows)
        #expect(trunk == [.init(above: false, below: true), .init(above: true, below: true), .init(above: true, below: true),
                          .init(above: true, below: false), .init(above: false, below: false)])
    }

    @Test func theLineAboveThePersonHasNoGap() {
        let relatives = [Relative(kind: .father, person: person(2, "F")), Relative(kind: .sibling, person: person(4, "S"))]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [:], parentsOfParents: [
            2: [Relative(kind: .father, person: person(9, "G"))]])
        let rows = FamilyLine.rows(tree, open: [])
        #expect(rows.map(word) == ["grandparent G", "father F", "siblings S +0", "person Me"])
        #expect(FamilyLine.trunks(rows) == [.init(above: false, below: true), .init(above: true, below: true),
                                            .init(above: true, below: true), .init(above: true, below: false)])
    }

    @Test func childrenWithNoHouseholdFollowThePersonOnNoTrunk() {
        let tree = FamilyTree.make(person: me, relatives: [Relative(kind: .child, person: person(21, "k1")), Relative(kind: .child, person: person(22, "k2"))],
                                   parentsOfChildren: [:], parentsOfParents: [:])
        let rows = FamilyLine.rows(tree, open: [])
        #expect(rows.map(word) == ["person Me", "children k1,k2"])
        #expect(FamilyLine.trunks(rows) == [.init(above: false, below: false), .init(above: false, below: false)])
    }

    /// The Mac lays a run as units that wrap between names (Matt, 2026-11-24: the phone's design where the tree does not
    /// fit), each name and "n more" a button of its own: the words and separators trail the unit before, and the units
    /// joined read as the phone's text.
    @Test func aRunIsCutIntoAUnitPerNameForTheMac() {
        typealias Cut = FamilyLine.Cut
        let (abinadab, eliab, elihu) = (person(10, "Abinadab"), person(11, "Eliab"), person(12, "Elihu"))
        let siblings = FamilyLine.pieces(label: "Siblings", names: [abinadab, eliab, elihu], more: 4)
        #expect(FamilyLine.cuts(siblings) == [Cut(unit: .word("Siblings:"), trailing: " "), Cut(unit: .name(abinadab), trailing: ", "),
                                              Cut(unit: .name(eliab), trailing: ", "), Cut(unit: .name(elihu), trailing: " "),
                                              Cut(unit: .word("and"), trailing: " "), Cut(unit: .more("4 more"), trailing: "")])
        let two = FamilyLine.pieces(label: nil, names: [abinadab, eliab], more: 0)
        #expect(FamilyLine.cuts(two) == [Cut(unit: .name(abinadab), trailing: " "), Cut(unit: .word("and"), trailing: " "), Cut(unit: .name(eliab), trailing: "")])
        for pieces in [siblings, two, FamilyLine.pieces(label: "Half-siblings", names: [elihu], more: 0), FamilyLine.pieces(label: nil, names: [], more: 3)] {
            let joined = FamilyLine.cuts(pieces).map { cut in
                switch cut.unit {
                case .word(let text), .more(let text): text + cut.trailing
                case .name(let person): person.name + cut.trailing
                }
            }.joined()
            #expect(joined == FamilyLine.text(pieces))
        }
    }

    @Test func eachRowHasItsOwnIdAndItsSpeech() {
        let rows = FamilyLine.rows(partnered(2, siblings: 1), open: [])
        #expect(Set(rows.map(\.id)).count == rows.count)
        #expect(FamilyLine.spoken(.grandparent(person(5, "Obed"))) == "Obed, grandparent")
        #expect(FamilyLine.spoken(.parent(person(6, "Jesse"), .father)) == "Jesse, father")
        #expect(FamilyLine.spoken(.moreHeads(5)) == "and 5 more partners")
    }
}
