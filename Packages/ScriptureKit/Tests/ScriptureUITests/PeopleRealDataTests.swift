import CoreGraphics
import ScriptureData
import Testing
@testable import ScriptureUI

/// The family and the Named and Lived lines on the real data (spec 13's "The data, checked").
@Suite struct PeopleRealDataTests {
    private func page(_ id: Int, _ book: String?) throws -> PersonPage {
        try #require(try PersonPage.load(id, inBook: book, store: BenchmarkChapter.realStore()))
    }

    private func names(_ people: [PersonSummary]) -> [String] { people.map(\.name) }

    private func headName(_ head: FamilyTree.Household.Head) -> String {
        switch head {
        case .partner(let person), .otherParent(let person, _): person.name
        case .notNamed(let relation): "not named \(relation.rawValue)"
        }
    }

    private func headID(_ head: FamilyTree.Household.Head) -> Int? {
        switch head {
        case .partner(let person), .otherParent(let person, _): person.id
        case .notNamed: nil
        }
    }

    /// The relation an other parent's column is headed by; nil for a partner or "not named".
    private func otherParent(_ head: FamilyTree.Household.Head) -> Relation? {
        if case .otherParent(_, let relation) = head { relation } else { nil }
    }

    @Test(.needsRealBible) func davidsTreeHoldsHisGrandparentHouseholdsAndTheEleven() throws {
        let david = try page(994, "2SA")
        let family = david.family
        #expect(names(family.grandparents.map(\.person)) == ["Obed"] && family.grandparents.map(\.parentID) == [family.father?.id].compactMap { $0 })
        #expect(names(family.siblings) == ["Abinadab", "Eliab", "Elihu", "Nethaneel", "Ozem", "Raddai", "Shammah"])
        #expect(names(family.halfSiblings) == ["Abigail", "Zeruiah"])
        #expect(family.households.map { headName($0.head) }
                == ["Abigail", "Abital", "Ahinoam", "Bathsheba", "Eglah", "Haggith", "Maacah", "Michal", "not named mother"])
        #expect(headID(family.households[0].head) == 26)
        let bathsheba = try #require(family.households.first { headName($0.head) == "Bathsheba" })
        #expect(names(bathsheba.children) == ["Nathan", "Shobab", "Solomon", "Shammua"])
        let michal = try #require(family.households.first { headName($0.head) == "Michal" })
        #expect(michal.children.isEmpty)
        #expect(names(try #require(family.households.last).children)
                == ["Eliphalet", "Elpalet", "Elishua", "Tamar", "Eliada", "Ibhar", "Jerimoth", "Japhia", "Elishama", "Nepheg", "Nogah"])
        #expect(family.summary == "8 partners, 21 children")
        #expect(david.namedLine == "226 verses here, 896 in 28 books")
        #expect(david.lived(showingDates: true) == "about 1085 to 1015 BC" && david.lived(showingDates: false) == nil)
    }

    @Test(.needsRealBible) func jacobsTreeHasThreeGrandparentsAndFourMothers() throws {
        let jacob = try page(682, "GEN")
        let family = jacob.family
        #expect(names(family.grandparents.map(\.person)) == ["Abraham", "Sarah", "Bethuel"])
        #expect(family.grandparents.map(\.parentID) == [family.father, family.father, family.mother].compactMap { $0?.id })
        #expect(names(family.father.map { [$0] } ?? []) == ["Isaac"] && names(family.mother.map { [$0] } ?? []) == ["Rebekah"])
        #expect(family.households.map { headName($0.head) } == ["Bilhah", "Leah", "Rachel", "Zilpah"])
        #expect(family.households.map { names($0.children) } == [["Dan", "Naphtali"],
            ["Levi", "Issachar", "Reuben", "Dinah", "Zebulun", "Simeon", "Judah"], ["Benjamin", "Joseph"], ["Gad", "Asher"]])
        #expect(family.children.count == 13)
        #expect(family.summary == "4 partners, 13 children")
    }

    @Test(.needsRealBible) func jesusAndJesseAndJudah() throws {
        let jesus = try page(905, "MAT").family
        #expect(jesus.father?.name == "Joseph" && jesus.mother?.name == "Mary")
        #expect(names(jesus.grandparents.map(\.person)) == ["Jacob", "Heli"] && jesus.grandparents.first?.person.id == 683)
        #expect(jesus.grandparents.map(\.parentID) == [1715, 1938])
        #expect(names(jesus.siblings) == ["James", "Joses", "Jude", "Simon"] && jesus.halfSiblings.isEmpty && jesus.households.isEmpty)
        #expect(jesus.summary == "2 parents, 4 siblings")
        let jesse = try page(903, "RUT").family
        #expect(names(jesse.grandparents.map(\.person)) == ["Boaz", "Ruth"] && names(jesse.children) == ["Abinadab", "Shammah", "Ozem", "Eliab", "Raddai", "David", "Elihu", "Nethaneel"])
        #expect(!jesse.hasMothersRow && jesse.summary == "8 children")
        let judah = try page(1751, "GEN").family
        #expect(judah.households.map { headName($0.head) } == ["Daughter of Shuah", "Tamar"])
        // Both are other parents, not partners (Departure 1): a partner's head fails these.
        #expect(otherParent(judah.households[0].head) == .mother && otherParent(judah.households[1].head) == .mother)
        #expect(headID(judah.households[1].head) == 2821)
        #expect(names(judah.households[0].children) == ["Onan", "Shelah", "Er"] && names(judah.households[1].children) == ["Pharez", "Zerah"])
    }

    @Test(.needsRealBible) func theRealFactsAndSubtitles() throws {
        let jacob = try page(682, "GEN")
        #expect(PersonPageView.facts(jacob, showingDates: true).map(\.rawValue) == ["Father", "Mother", "Lived", "Named", "Family"])
        #expect(jacob.person.label == "Israel" && jacob.namedLine == "187 verses here, 1,009 in 37 books")
        #expect(PersonPageView.facts(try page(3060, "2SA"), showingDates: true).map(\.rawValue) == ["Named"])
        #expect(try page(1751, "GEN").lived(showingDates: true) == "born about 1755 BC")
    }

    @Test(.needsRealBible) func lotsDaughterHasHerSonOnceAndLotOverHisColumn() throws {
        let family = try page(984, "GEN").family
        #expect(names(family.children) == ["Ben-ammi"] && names(family.halfSiblings) == ["Moab"])
        #expect(family.households.map { headName($0.head) } == ["Lot"])
        #expect(otherParent(family.households[0].head) == .father)
    }

    @Test(.needsRealBible) func aPersonWithNoFamilyHasAnEmptyTree() throws {
        #expect(try page(3060, "2SA").family.isEmpty)
    }

    #if os(macOS)
    /// Departures 2 and 3, ruling 27: spec 13's figures where they hold, the rest as measured. Each side
    /// holds (472 - 52) / 2 - 12 = 198: the siblings' run is 391 and folds, the half-siblings' 100 and
    /// stays open. The mothers' row with three folded is 510 and with four 455, so four fold, Eglah
    /// with Haggith, Maacah and Michal (spec 13 had three; three fold from 510 pt).
    @Test(.needsRealBible) func davidsTreeFoldsAtTheDefaultWidth() throws {
        let david = try page(994, "2SA").family
        let folded = FamilyTreeFolding.fold(david, width: 472, measure: SystemFamilyTreeMeasure())
        #expect(folded.siblings && !folded.halfSiblings && folded.notNamed && folded.childrenShown == nil)
        #expect(folded.foldedHouseholds == 4)
        #expect(david.households.filter { headID($0.head) != nil }.suffix(folded.foldedHouseholds).map { headName($0.head) }
                == ["Eglah", "Haggith", "Maacah", "Michal"])
        #expect(FamilyTreeFolding.fold(david, width: 510, measure: SystemFamilyTreeMeasure()).foldedHouseholds == 3)
        let wide = FamilyTreeFolding.fold(david, width: 2_000, measure: SystemFamilyTreeMeasure())
        #expect(!wide.siblings && !wide.halfSiblings && wide.foldedHouseholds == 0 && wide.notNamed)
    }

    @Test(.needsRealBible) func jacobFoldsNothingAtTheDefaultWidth() throws {
        let jacob = try page(682, "GEN").family
        #expect(FamilyTreeFolding.fold(jacob, width: 472, measure: SystemFamilyTreeMeasure()) == FamilyFold())
    }

    private func reading(_ tree: FamilyTree, _ width: CGFloat, open: Set<FamilyChip> = []) -> [String] {
        let geometry = FamilyTreeGeometry.make(tree, width: width, open: open, rowPitch: FamilyTreeView.rowPitch, measure: SystemFamilyTreeMeasure())
        return FamilyTreeSpeech.groups(tree, geometry: geometry).map(\.label)
    }

    /// Spec 5.2's VoiceOver, by relation: the labels of the tree's elements, one per group, which the view applies
    /// as its accessibility children (a hosted view's elements cannot be read under `swift test`). At 472 the fold is Task 8's, as measured (ruling 27): the half-siblings
    /// stay open and four mothers fold (Eglah with Haggith, Maacah and Michal), so the chip reads "4 more".
    @Test(.needsRealBible) func davidsTreeReadsByRelation() throws {
        let david = try page(994, "2SA").family
        #expect(reading(david, 472) == [
            "David", "Grandparents: Obed", "Parents: Jesse", "7 siblings, folded", "Half-siblings: Abigail, Zeruiah",
            "Abigail, partner. Children: Daniel", "Abital, partner. Children: Shephatiah", "Ahinoam, partner. Children: Amnon",
            "Bathsheba, partner. Children: Nathan, Shobab, Solomon, Shammua", "4 more, folded",
            "Children, mother not named: 11, folded"])
        let wide = reading(david, 2_000)
        #expect(wide.contains("Siblings: Abinadab, Eliab, Elihu, Nethaneel, Ozem, Raddai, Shammah"))
        #expect(wide.contains("Eglah, partner. Children: Ithream") && wide.contains("Haggith, partner. Children: Adonijah")
                && wide.contains("Maacah, partner. Children: Absalom") && wide.contains("Michal, partner"))
        #expect(!wide.contains { $0.hasSuffix("more, folded") } && wide.last == "Children, mother not named: 11, folded")
        // An open chip reads its names in its place.
        let open = reading(david, 472, open: [.siblings, .households, .notNamed])
        #expect(open[3] == "Siblings: Abinadab, Eliab, Elihu, Nethaneel, Ozem, Raddai, Shammah")
        #expect(Array(open[9...12]) == ["Eglah, partner. Children: Ithream", "Haggith, partner. Children: Adonijah",
                                        "Maacah, partner. Children: Absalom", "Michal, partner"])
        #expect(open.last == "Children, mother not named: Eliphalet, Elpalet, Elishua, Tamar, Eliada, Ibhar, Jerimoth, Japhia, Elishama, Nepheg, Nogah")
    }

    @Test(.needsRealBible) func judahsAndJessesTreesRead() throws {
        let judah = reading(try page(1751, "GEN").family, 2_000)
        #expect(judah.contains("Daughter of Shuah, mother of Onan, Shelah and Er") && judah.contains("Tamar, mother of Pharez and Zerah"))
        let jesse = reading(try page(903, "RUT").family, 2_000)
        #expect(jesse.last == "Children: Abinadab, Shammah, Ozem, Eliab, Raddai, David, Elihu, Nethaneel")
        #expect(jesse.first == "Jesse" && jesse.contains("Grandparents: Boaz, Ruth"))
        #expect(reading(try page(682, "GEN").family, 472).prefix(3) == ["Jacob", "Grandparents: Abraham, Sarah, Bethuel", "Parents: Isaac, Rebekah"])
    }
    #endif

    @Test(.needsRealBible) func davidsVersesInSecondSamuelAreTwentyThreeLines() throws {
        let here = try page(994, "2SA").here
        let lines = try #require(here?.lines)
        #expect(lines.count == 23 && here?.count == 226)
        #expect(lines[0].chapter == 1 && lines[0].runs.map(VerseLines.runText) == ["1-5", "11", "13-17"])
        #expect(lines[2].chapter == 3 && lines[2].runs.count == 10)
        #expect(lines.reduce(0) { $0 + $1.runs.count } == 116)
        #expect(lines.reduce(0) { $0 + $1.runs.count } == here?.references.count)
    }
}
