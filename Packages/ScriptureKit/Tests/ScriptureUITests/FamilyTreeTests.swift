import ScriptureData
import Testing
@testable import ScriptureUI

/// `FamilyTree.make`, spec 5.1, on relatives built in code.
@Suite struct FamilyTreeTests {
    private func person(_ id: Int, _ name: String) -> PersonSummary {
        PersonSummary(id: id, name: name, label: nil, verseCount: 1)
    }

    private func relative(_ kind: Relation, _ id: Int, _ name: String) -> Relative {
        Relative(kind: kind, person: person(id, name))
    }

    private let me = PersonSummary(id: 1, name: "Me", label: nil, verseCount: 1)

    @Test func childrenSitUnderTheirMotherAndTheRestUnderNotNamed() {
        let (a, b, m) = (person(10, "A"), person(11, "B"), person(12, "M"))
        let (c1, c2, c3) = (person(21, "c1"), person(22, "c2"), person(23, "c3"))
        let relatives = [Relative(kind: .partner, person: a), Relative(kind: .partner, person: b),
                         Relative(kind: .child, person: c1), Relative(kind: .child, person: c2), Relative(kind: .child, person: c3)]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [
            21: [Relative(kind: .mother, person: b)], 23: [Relative(kind: .mother, person: m)]], parentsOfParents: [:])
        #expect(tree.households.map(\.head) == [.partner(b), .partner(a), .otherParent(m, .mother), .notNamed(.mother)])
        #expect(tree.households.map { $0.children.map(\.id) } == [[21], [], [23], [22]])
        #expect(tree.hasMothersRow)
    }

    @Test func withNoPartnerAndNoNamedMotherTheChildrenHangFromThePerson() {
        let relatives = [relative(.child, 21, "c1"), relative(.child, 22, "c2"), relative(.child, 23, "c3")]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [:], parentsOfParents: [:])
        #expect(tree.households.isEmpty && !tree.hasMothersRow)
        #expect(tree.children.map(\.id) == [21, 22, 23])
    }

    @Test func aChildWhoIsAlsoAHalfSiblingShowsOnceAsAChild() {
        let relatives = [relative(.mother, 5, "Mum"), relative(.halfSibling, 5, "Mum"), relative(.halfSibling, 30, "X"),
                         relative(.halfSibling, 31, "Y"), relative(.child, 30, "X")]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [:], parentsOfParents: [:])
        #expect(tree.children.map(\.id) == [30])
        #expect(tree.halfSiblings.map(\.id) == [31])
        #expect(tree.mother?.id == 5 && tree.halfSiblings.map(\.id).contains(5) == false)
    }

    @Test func whenThePersonIsTheMotherTheFatherHeadsTheColumn() {
        let father = person(40, "F")
        let partner = person(41, "P")
        let relatives = [Relative(kind: .partner, person: partner), relative(.child, 51, "k1"), relative(.child, 52, "k2")]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [
            51: [Relative(kind: .father, person: father), relative(.mother, 1, "Me")],
            52: [relative(.mother, 1, "Me")]], parentsOfParents: [:])
        #expect(tree.households.map(\.head) == [.partner(partner), .otherParent(father, .father), .notNamed(.father)])
        #expect(tree.households.map { $0.children.map(\.id) } == [[], [51], [52]])
        let alone = FamilyTree.make(person: me, relatives: [relative(.partner, 41, "P"), relative(.child, 52, "k2")],
                                    parentsOfChildren: [52: [relative(.mother, 1, "Me")]], parentsOfParents: [:])
        #expect(alone.households.map(\.head) == [.partner(person(41, "P")), .notNamed(.father)])
    }

    @Test func grandparentsSitOverTheirOwnParent() {
        let relatives = [relative(.father, 100, "F"), relative(.mother, 200, "M")]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [:], parentsOfParents: [
            100: [relative(.father, 101, "FF"), relative(.mother, 102, "FM")], 200: [relative(.father, 201, "MF")]])
        #expect(tree.grandparents.map(\.person.id) == [101, 102, 201])
        #expect(tree.grandparents.map(\.parentID) == [100, 100, 200])
        #expect(tree.grandparents.map(\.kind) == [.father, .mother, .father])
    }

    @Test func aGrandparentSharedByBothParentsSitsOverEach() {
        let relatives = [relative(.father, 100, "F"), relative(.mother, 200, "M")]
        let tree = FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [:], parentsOfParents: [
            100: [relative(.father, 300, "Terah")], 200: [relative(.father, 300, "Terah")]])
        #expect(tree.grandparents.map(\.person.id) == [300, 300])
        #expect(tree.grandparents.map(\.parentID) == [100, 200])
    }

    @Test func theSummaryCountsTheHouseholdElseTheBirthFamily() {
        func tree(_ relatives: [Relative]) -> FamilyTree {
            FamilyTree.make(person: me, relatives: relatives, parentsOfChildren: [:], parentsOfParents: [:])
        }
        let partners = [relative(.partner, 10, "A"), relative(.partner, 11, "B")]
        let children = [relative(.child, 21, "a"), relative(.child, 22, "b"), relative(.child, 23, "c")]
        #expect(tree(partners + children).summary == "2 partners, 3 children")
        #expect(tree([relative(.partner, 10, "A")]).summary == "1 partner")
        #expect(tree((21...25).map { relative(.child, $0, "c\($0)") }).summary == "5 children")
        #expect(tree([relative(.child, 21, "a")]).summary == "1 child")
        let born = [relative(.father, 1000, "F"), relative(.mother, 2000, "M"), relative(.sibling, 31, "s1"), relative(.sibling, 32, "s2"),
                    relative(.halfSibling, 33, "h1"), relative(.halfSibling, 34, "h2")]
        #expect(tree(born).summary == "2 parents, 4 siblings")
        #expect(tree([relative(.father, 1000, "F")]).summary == "1 parent")
        #expect(tree([relative(.sibling, 31, "s1")]).summary == "1 sibling")
        let empty = tree([])
        #expect(empty.isEmpty && empty.summary == nil)
    }
}
