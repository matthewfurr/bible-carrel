import CoreGraphics
import ScriptureData
import Testing
@testable import ScriptureUI
#if os(macOS)
import AppKit
import SwiftUI
#endif

/// Every style 10 pt a character wide and 16 pt tall, so a fold can be worked by hand.
private struct FixedMeasure: FamilyTreeMeasure {
    func size(_ text: String, _ style: FamilyTreeStyle) -> CGSize { CGSize(width: CGFloat(text.count) * 10, height: 16) }
}

/// The Mac's tree as folds and geometry (spec 5.2; Departures 2, 3, 10 and 11).
@Suite struct FamilyTreeLayoutTests {
    private let pat = PersonSummary(id: 1, name: "Pat", label: nil, verseCount: 1)

    private func person(_ id: Int, _ name: String) -> PersonSummary {
        PersonSummary(id: id, name: name, label: nil, verseCount: 1)
    }

    private func tree(_ relatives: [Relative], parentsOfChildren: [Int: [Relative]] = [:]) -> FamilyTree {
        FamilyTree.make(person: pat, relatives: relatives, parentsOfChildren: parentsOfChildren, parentsOfParents: [:])
    }

    private func fold(_ tree: FamilyTree, _ width: CGFloat) -> FamilyFold {
        FamilyTreeFolding.fold(tree, width: width, measure: FixedMeasure())
    }

    /// The person sits off-centre where one side is long, as near the middle as the row allows, with the parents still
    /// over the person: four Abelards end one gap before Pat at 328 (the middle would be 285), the Hanas start one gap
    /// after, and Dad stands over Pat's centre.
    @Test func aLongSideMovesThePersonAndTheParentsFollow() throws {
        let siblings = (0..<4).map { Relative(kind: .sibling, person: person(10 + $0, "Abelard")) }
        let two = (0..<2).map { Relative(kind: .halfSibling, person: person(20 + $0, "Hana")) }
        let laid = FamilyTreeGeometry.make(tree([Relative(kind: .father, person: person(2, "Dad"))] + siblings + two), width: 600, open: [],
                                           rowPitch: 20, measure: FixedMeasure())
        let pat = try #require(laid.slots.first { $0.id == "person" })
        #expect(pat.frame.minX == 328)
        #expect(laid.slots.filter { $0.id.hasPrefix("sibling-") }.map(\.frame.minX) == [0, 82, 164, 246])
        #expect(laid.slots.filter { $0.id.hasPrefix("halfSibling-") }.map(\.frame.minX) == [370, 422])
        #expect(try #require(laid.slots.first { $0.id == "parent-2" }).frame.midX == pat.frame.midX)
    }

    @Test func aSideFoldsOnlyWhenItsNamesDoNotFit() {
        let siblings = (0..<4).map { Relative(kind: .sibling, person: person(10 + $0, "Abelard")) }
        let two = (0..<2).map { Relative(kind: .halfSibling, person: person(20 + $0, "Hana")) }
        // The whole generation against the whole width (the coordinator's fix of 2026-11-24, Judah's brothers): four
        // Abelards (316), a gap, Pat (30), a gap, two Hanas (92) are 462, which fits 600 though the siblings' run is
        // wider than a half; "4 siblings" (100) makes it 246, which fits 450.
        #expect(fold(tree(siblings + two), 600) == FamilyFold())
        let narrow = fold(tree(siblings + two), 450)
        #expect(narrow.siblings && !narrow.halfSiblings)
        // Three Hannelores (294): 664 does not fit 600, and with "4 siblings" 448 does; at 400 "3 half-siblings" (150)
        // folds too, 304.
        let three = (0..<3).map { Relative(kind: .halfSibling, person: person(20 + $0, "Hannelore")) }
        let one = fold(tree(siblings + three), 600)
        #expect(one.siblings && !one.halfSiblings)
        let both = fold(tree(siblings + three), 400)
        #expect(both.siblings && both.halfSiblings)
        #expect(FamilyTreeFolding.chipLabel(.siblings, count: 7) == "7 siblings")
        #expect(FamilyTreeFolding.chipLabel(.siblings, count: 1) == "1 sibling")
        #expect(FamilyTreeFolding.chipLabel(.halfSiblings, count: 2) == "2 half-siblings")
        #expect(FamilyTreeFolding.chipLabel(.halfSiblings, count: 1) == "1 half-sibling")
    }

    /// Matt, 2026-11-24, on Benjamin's page: "What is the logic behind using a chip for 1 sibling instead of just putting
    /// that 1 siblings name...?" A chip never stands for one name, and a run folds only when its chip is narrower than
    /// the run by more than a gap; the half-siblings fold where the siblings cannot.
    @Test func aChipNeverStandsForOneNameOrSavesNothing() {
        // One sibling "Jo" (20) and four half-siblings "Hannelore" (90 each, 396 with gaps): with Pat (30), 20 + 12 + 30 +
        // 12 + 396 = 470. At 300 the sibling stays a name and the half-siblings fold ("4 half-siblings", 150: 224).
        let one = tree([Relative(kind: .sibling, person: person(10, "Jo"))]
                       + (0..<4).map { Relative(kind: .halfSibling, person: person(20 + $0, "Hannelore")) })
        #expect(fold(one, 300) == FamilyFold(siblings: false, halfSiblings: true))
        // Two siblings "Al" and "Bo" (52 with the gap) beside "2 siblings" (100): no room saved, so they stay names.
        let short = tree([Relative(kind: .sibling, person: person(10, "Al")), Relative(kind: .sibling, person: person(11, "Bo"))]
                         + (0..<4).map { Relative(kind: .halfSibling, person: person(20 + $0, "Hannelore")) })
        #expect(fold(short, 300) == FamilyFold(siblings: false, halfSiblings: true))
        // One half-sibling is never a chip, whatever the width: the generation is laid as it can be (or the Mac falls back).
        let lone = tree([Relative(kind: .halfSibling, person: person(20, "Hannelore"))])
        #expect(!fold(lone, 60).halfSiblings)
        // A row of children never ends in "1 more": four "Abcdefghij" (100) are 436; at 420 three and "1 more" (396) would
        // fit, so two and "2 more" (284).
        let children = tree((0..<4).map { Relative(kind: .child, person: person(30 + $0, "Abcdefghij")) })
        #expect(fold(children, 420).childrenShown == 2)
        // Nor the mothers' row in "1 more": four partners "Annabelle" (90) are 396; at 380 three and "1 more" (366) would
        // fit, so two fold.
        let mothers = tree((0..<4).map { Relative(kind: .partner, person: person(40 + $0, "Annabelle")) })
        #expect(fold(mothers, 380).foldedHouseholds == 2)
    }

    @Test func theMothersRowFoldsFromItsEndChildlessFirst() {
        let (anna, beth) = (person(10, "Anna"), person(11, "Beth"))
        let relatives = [Relative(kind: .partner, person: anna), Relative(kind: .partner, person: beth),
                         Relative(kind: .partner, person: person(12, "Cara")), Relative(kind: .partner, person: person(13, "Dora")),
                         Relative(kind: .child, person: person(20, "Bo")), Relative(kind: .child, person: person(21, "Cy"))]
        let family = tree(relatives, parentsOfChildren: [20: [Relative(kind: .mother, person: anna)],
                                                         21: [Relative(kind: .mother, person: beth)]])
        // Four columns of 40 with three gaps of 12 are 196; at 180 Anna, Beth and "2 more" are 164.
        #expect(fold(family, 200).foldedHouseholds == 0)
        #expect(fold(family, 180).foldedHouseholds == 2)
        #expect(FamilyTreeFolding.chipLabel(.households, count: 3) == "3 more")
    }

    @Test func aChildlessPartnerFoldsBeforeAMotherWhoIsNotAPartner() {
        let (anna, magda) = (person(10, "Annabella"), person(12, "Magdalene"))
        let relatives = [Relative(kind: .partner, person: anna), Relative(kind: .partner, person: person(11, "Carolina")),
                         Relative(kind: .child, person: person(20, "Bo")), Relative(kind: .child, person: person(21, "Cy"))]
        let family = tree(relatives, parentsOfChildren: [20: [Relative(kind: .mother, person: anna)],
                                                         21: [Relative(kind: .mother, person: magda)]])
        let named = FamilyTreeFolding.mothers(of: family).named
        #expect(named.map(\.id) == ["partner-10", "partner-11", "parent-12"])
        // Columns of 90, 80 and 90 are 284; at 270 one fold would do, but never "1 more" (Matt, 2026-11-24): the childless
        // Carolina folds first, then Magdalene, the mother who is not a partner, leaving Annabella and "2 more" (162).
        let two = fold(family, 270)
        #expect(two.foldedHouseholds == 2)
        #expect(FamilyTreeFolding.folded(named, count: 1).map(\.id) == ["partner-11"])
        #expect(FamilyTreeFolding.folded(named, count: two.foldedHouseholds).map(\.id) == ["partner-11", "parent-12"])
        let geometry = FamilyTreeGeometry.make(family, width: 270, open: [], rowPitch: 20, measure: FixedMeasure())
        #expect(geometry.slots.compactMap { if case .head(let household) = $0.kind { household.id } else { nil } } == ["partner-10"])
        #expect(geometry.slots.contains { $0.id == "chip-households" })
    }

    @Test func aColumnsChildrenAreNeverCloserThanTheirHeight() {
        let mother = person(10, "Mae")
        let children = (0..<3).map { person(20 + $0, "Kid") }
        let family = tree([Relative(kind: .partner, person: mother)] + children.map { Relative(kind: .child, person: $0) },
                          parentsOfChildren: Dictionary(uniqueKeysWithValues: children.map { ($0.id, [Relative(kind: .mother, person: mother)]) }))
        let geometry = FamilyTreeGeometry.make(family, width: 400, open: [], rowPitch: 10, measure: FixedMeasure())
        let tops = geometry.slots.filter { if case .child = $0.kind { true } else { false } }.map(\.frame.minY)
        #expect(zip(tops, tops.dropFirst()).map { $1 - $0 } == [16, 16])
    }

    @Test func theUnnamedFoldWhenTallerThanTheTallestMotherPlusThree() {
        func family(unnamed: Int) -> FamilyTree {
            let mother = person(10, "Mae")
            let hers = (0..<4).map { person(20 + $0, "M\($0)") }
            let others = (0..<unnamed).map { person(40 + $0, "U\($0)") }
            let relatives = [Relative(kind: .partner, person: mother)] + (hers + others).map { Relative(kind: .child, person: $0) }
            return tree(relatives, parentsOfChildren: Dictionary(uniqueKeysWithValues: hers.map { ($0.id, [Relative(kind: .mother, person: mother)]) }))
        }
        #expect(!fold(family(unnamed: 7), 2_000).notNamed)
        #expect(fold(family(unnamed: 8), 2_000).notNamed)
        #expect(FamilyTreeFolding.chipLabel(.notNamed, count: 8) == "8")
        #expect(FamilyTreeFolding.chipLabel(.notNamed, count: 11) == "11")
    }

    @Test func childrenWithNoMothersRowShowWhatFitsThenAChip() {
        let family = tree((0..<8).map { Relative(kind: .child, person: person(20 + $0, "Abcde")) })
        // All eight are 8 × 50 + 7 × 12 = 484; at 300 three names and "5 more" are 246, four 308.
        #expect(fold(family, 500).childrenShown == nil)
        #expect(fold(family, 300).childrenShown == 3)
        #expect(FamilyTreeFolding.chipLabel(.children, count: 5) == "5 more")
    }

    /// An opened "n more" as Matt chose it (2026-11-24, B): a further row of the tree, each folded mother a column with
    /// her children under her, "Fewer" a chip ending it, the columns side by side one gap apart under the person (Matt,
    /// 2026-11-24: never spread across the width); a row that does not fit continues on the next, whose bar is joined
    /// to the one above down a lane left one gap after the row above's last column.
    @Test func anOpenedNMoreIsARowOfColumnsThatWraps() {
        let (anna, beth) = (person(10, "Anna"), person(11, "Beth"))
        let relatives = [anna, beth, person(12, "Cara"), person(13, "Dora"), person(14, "Edna")].map { Relative(kind: .partner, person: $0) }
            + [Relative(kind: .child, person: person(20, "Bo")), Relative(kind: .child, person: person(21, "Cy"))]
        let family = tree(relatives, parentsOfChildren: [20: [Relative(kind: .mother, person: anna)], 21: [Relative(kind: .mother, person: beth)]])
        // At 180 three fold: Anna, Beth and "3 more" are 164, centred under Pat (90): from 8, so the chip's column is centred at
        // 8 + 40 + 12 + 40 + 12 + 30.
        let laid = FamilyTreeGeometry.make(family, width: 180, open: [.households], rowPitch: 20, measure: FixedMeasure())
        #expect(laid.fold.foldedHouseholds == 3)
        func frame(_ id: String) -> CGRect? { laid.slots.first { $0.id == id }?.frame }
        func same(_ a: CGPoint, _ b: CGPoint) -> Bool { hypot(a.x - b.x, a.y - b.y) < 0.01 }
        func line(_ from: CGPoint, _ to: CGPoint) -> Bool {
            laid.lines.contains { (same($0.from, from) && same($0.to, to)) || (same($0.from, to) && same($0.to, from)) }
        }
        let chipX: CGFloat = 142
        #expect(frame("chip-households") == nil)
        #expect([frame("head-partner-10")?.midX, frame("head-partner-11")?.midX] == [28, 80])
        // The first row's heads are 40...56 and its children 68...84, so the next row is 24 below, at 108, its bar at 100.
        // Cara, Dora, Edna and "Fewer" are 206, wider than 180: the row keeps Cara, Dora and Edna and a lane (a column of no
        // width) at its end, 156 in all, centred under Pat from 12: centres 32, 84, 136 and the lane at 168.
        let heads = ["head-partner-12", "head-partner-13", "head-partner-14"].map(frame)
        #expect(heads.map { $0?.midX } == [32, 84, 136])
        #expect(heads.allSatisfy { $0?.minY == 108 })
        // "Fewer" ends the last row, alone and centred under Pat, 24 under the row above.
        #expect(frame("fewer-households") == CGRect(x: 65, y: 148, width: 50, height: 16))
        // The chip's column joins the first row's bar to the second's; the second's bar spans its rises and the lane, which
        // drops to the third's bar, which spans the lane and "Fewer"'s rise.
        #expect(line(CGPoint(x: chipX, y: 32), CGPoint(x: chipX, y: 100)))
        #expect(line(CGPoint(x: 32, y: 100), CGPoint(x: 168, y: 100)))
        for x: CGFloat in [32, 84, 136] { #expect(line(CGPoint(x: x, y: 100), CGPoint(x: x, y: 108))) }
        #expect(line(CGPoint(x: 168, y: 100), CGPoint(x: 168, y: 140)))
        #expect(line(CGPoint(x: 90, y: 140), CGPoint(x: 168, y: 140)))
        #expect(line(CGPoint(x: 90, y: 140), CGPoint(x: 90, y: 148)))
        #expect(laid.size.height == 164)
        #expect(laid.householdRows == 2)
        // At 220 two fold (Anna, Beth, Cara and "2 more" are 216); Dora, Edna and "Fewer" are 154, so they lie on one row
        // with no lane, centred under Pat (110) from 33.
        let wide = FamilyTreeGeometry.make(family, width: 220, open: [.households], rowPitch: 20, measure: FixedMeasure())
        #expect(wide.fold.foldedHouseholds == 2 && wide.householdRows == 1)
        let row = ["head-partner-13", "head-partner-14", "fewer-households"].compactMap { id in wide.slots.first { $0.id == id }?.frame }
        #expect(row.map(\.midY) == [116, 116, 116] && row.map(\.minX) == [33, 85, 137])
    }

    /// Matt, 2026-11-24 (Lot's page in a wide window): "a comfortable/readable width between names horizontally that is
    /// evenly spread apart". A small family in a wide column is compact: every pair of neighbours one gap apart, the
    /// siblings' run ending a gap before the person and the half-siblings' starting a gap after, the parents a gap apart
    /// and centred over the person, the mothers' columns side by side and centred under the person's drop; the bars
    /// follow the names. Worked at the old gap (12) and at the reader's (27 at 18 pt).
    @Test func aSmallFamilyIsCompactInAWideColumn() {
        let (mae, nan) = (person(30, "Mae"), person(31, "Nan"))
        let relatives = [Relative(kind: .father, person: person(10, "Abe")), Relative(kind: .mother, person: person(11, "Bea")),
                         Relative(kind: .sibling, person: person(20, "Cy")), Relative(kind: .sibling, person: person(21, "Di")),
                         Relative(kind: .halfSibling, person: person(22, "Ed")),
                         Relative(kind: .partner, person: mae), Relative(kind: .partner, person: nan),
                         Relative(kind: .child, person: person(40, "Kidwell")), Relative(kind: .child, person: person(41, "Ola"))]
        let family = tree(relatives, parentsOfChildren: [40: [Relative(kind: .mother, person: mae)], 41: [Relative(kind: .mother, person: nan)]])
        for gap: CGFloat in [12, 27] {
            let laid = FamilyTreeGeometry.make(family, width: 1_000, open: [], rowPitch: 20, gap: gap, measure: FixedMeasure())
            func frame(_ id: String) -> CGRect { laid.slots.first { $0.id == id }?.frame ?? .null }
            func bar(_ low: CGFloat, _ high: CGFloat) -> Bool {
                laid.lines.contains { $0.from.y == $0.to.y && abs(min($0.from.x, $0.to.x) - low) < 0.01 && abs(max($0.from.x, $0.to.x) - high) < 0.01 }
            }
            // Pat (30) at the centre, 485...515; Cy and Di end a gap before, Ed starts a gap after.
            #expect(frame("person").minX == 485, "gap \(gap)")
            #expect(frame("sibling-21").maxX == 485 - gap && frame("sibling-21").minX - frame("sibling-20").maxX == gap, "gap \(gap)")
            #expect(frame("halfSibling-22").minX == 515 + gap, "gap \(gap)")
            // Abe and Bea a gap apart, their pair centred over Pat.
            #expect(frame("parent-11").minX - frame("parent-10").maxX == gap && (frame("parent-10").minX + frame("parent-11").maxX) / 2 == 500, "gap \(gap)")
            // Mae's column (Kidwell, 70) and Nan's (30) a gap apart, the run centred under Pat's drop.
            let (maeX, nanX) = (frame("head-partner-30").midX, frame("head-partner-31").midX)
            #expect((nanX - 15) - (maeX + 35) == gap && ((maeX - 35) + (nanX + 15)) / 2 == 500, "gap \(gap)")
            #expect(frame("child-40").midX == maeX && frame("child-41").midX == nanX, "gap \(gap)")
            // The mothers' bar spans their rises, the generation's solid bar the siblings' rises to the parents' drop.
            #expect(bar(maeX, nanX) && bar(frame("sibling-20").midX, 500), "gap \(gap)")
        }
    }

    /// The gap between the tree's names (Matt, 2026-11-24): one and a half of the tree's `.body` size, to the point.
    @Test func theReadersGapIsOneAndAHalfEms() {
        #expect(FamilyTreeFolding.gap(LibraryType(readerSize: 18)) == 27)
        #expect(FamilyTreeFolding.gap(LibraryType(readerSize: 14)) == 21)
        #expect(FamilyTreeFolding.gap(LibraryType(readerSize: 24)) == 36)
        // The system's `.body` (13 on the Mac): 19.5, to 20.
        #expect(FamilyTreeFolding.gap(.system) == (PageFace.baseSize(.body) * 1.5).rounded())
    }

    /// The last resort (Task 12): names too long for their share of the column are cut to it, the narrower
    /// ones kept whole, and the tree stays inside the column.
    @Test func aNameTooLongForItsShareIsCutToFit() {
        // 30, 100 and 200 with two gaps of 12 in 200: 176 to share; 30 keeps its width, the others 73 each.
        #expect(FamilyTreeFolding.shares([30, 200, 100], within: 200) == [30, 73, 73])
        #expect(FamilyTreeFolding.shares([30, 100], within: 200) == [30, 100])
        let family = tree([Relative(kind: .father, person: person(10, "Bartholomewsson")), Relative(kind: .mother, person: person(11, "Ana"))])
        let laid = FamilyTreeGeometry.make(family, width: 120, open: [], rowPitch: 20, measure: FixedMeasure())
        let father = laid.slots.first { $0.id == "parent-10" }, mother = laid.slots.first { $0.id == "parent-11" }
        // 150 and 30 in 120: the father is cut to 120 - 12 - 30 = 78, the mother kept whole.
        #expect(father?.truncated == true && father?.frame.width == 78)
        #expect(mother?.truncated == false && mother?.frame.width == 30)
        #expect(laid.slots.allSatisfy { $0.frame.minX >= 0 && $0.frame.maxX <= 120 })
        #expect(FamilyTreeGeometry.make(family, width: 400, open: [], rowPitch: 20, measure: FixedMeasure()).slots.allSatisfy { !$0.truncated })
    }

    #if os(macOS)
    private static let rowPitch = AppSpacing.lg

    private func family(_ id: Int, _ book: String) throws -> FamilyTree {
        try #require(try PersonPage.load(id, inBook: book, store: BenchmarkChapter.realStore())).family
    }

    /// The Mac's Library at the reader's default size.
    private static let reader = LibraryType(readerSize: 18)

    /// The tree as the view lays it: with the system's styles by default, or at a reader's type (its fonts, its pitch and
    /// its gap, 1.5 em). The system's styles keep the old gap (`sm`), so the figures worked at it still hold.
    private func geometry(_ tree: FamilyTree, _ width: CGFloat, open: Set<FamilyChip> = [], type: LibraryType = .system) -> FamilyTreeGeometry {
        FamilyTreeGeometry.make(tree, width: width, open: open, rowPitch: type.metric(Self.rowPitch),
                                gap: type.readerSize == nil ? FamilyTreeFolding.gap : FamilyTreeFolding.gap(type), measure: SystemFamilyTreeMeasure(type: type))
    }

    /// The width the tree's names take: from the leading edge of the first to the trailing edge of the last.
    private static func extent(_ geometry: FamilyTreeGeometry) -> CGFloat {
        (geometry.slots.map(\.frame.maxX).max() ?? 0) - (geometry.slots.map(\.frame.minX).min() ?? 0)
    }

    /// The gaps between neighbours on the line of `id`'s slot (slots on the same middle, left to right).
    private static func gaps(beside id: String, in geometry: FamilyTreeGeometry) -> [CGFloat] {
        guard let slot = geometry.slots.first(where: { $0.id == id }) else { return [] }
        let line = geometry.slots.filter { near($0.frame.midY, slot.frame.midY) }.map(\.frame).sorted { $0.minX < $1.minX }
        return zip(line, line.dropFirst()).map { $1.minX - $0.maxX }
    }

    /// Lot's page in Genesis in a wide window (Matt, 2026-11-24: "a small family is spread way apart"): at 1,200 pt his
    /// tree is as wide as at 800 and 1,000, the width of his widest row's names and the gaps between them (the mothers'
    /// row: his daughters, the mothers of Moab and Ben-ammi, then "Mother not named" over the daughters), never the
    /// window's; his generation's names one gap apart, the person centred in the page.
    /// Matt named "the Judah family tree with all his brothers" as a tree that takes the width it needs: in a 1,400 pt
    /// window (the tree about 1,050 pt) at 18 pt his six brothers all show, with no "6 siblings", and Jacob and Leah's
    /// drop stands over him wherever the row puts him.
    @Test(.needsRealBible) func judahsBrothersAllShowInAWideWindow() throws {
        let judah = geometry(try family(1751, "GEN"), 1_050, type: LibraryType(readerSize: 18))
        #expect(!judah.fold.siblings && !judah.fold.halfSiblings)
        #expect(!judah.slots.contains { if case .chip = $0.kind { true } else { false } })
        let person = try #require(judah.slots.first { $0.id == "person" })
        let parents = judah.slots.filter { if case .parent = $0.kind { true } else { false } }
        #expect(parents.count == 2)
        #expect(abs((parents.map(\.frame.midX).min()! + parents.map(\.frame.midX).max()!) / 2 - person.frame.midX) <= 0.5)
    }

    @Test(.needsRealBible) func lotsTreeIsNoWiderThanHisNamesInAWideWindow() throws {
        let lot = try family(1830, "GEN")
        #expect(lot.person.name == "Lot")
        let gap = FamilyTreeFolding.gap(Self.reader), measure = SystemFamilyTreeMeasure(type: Self.reader)
        let wide = geometry(lot, 1_200, type: Self.reader)
        for width: CGFloat in [800, 1_000] {
            let narrower = geometry(lot, width, type: Self.reader)
            #expect(wide.fold == narrower.fold && Self.near(Self.extent(wide), Self.extent(narrower)), "\(Self.extent(wide)) for \(Self.extent(narrower)) at \(width)")
        }
        let columns = lot.households.map { FamilyTreeFolding.columnWidth($0, folded: false, measure: measure) }
        #expect(columns.count == 3 && Self.near(Self.extent(wide), FamilyTreeFolding.run(columns, gap: gap)), "\(Self.extent(wide))")
        let generation = Self.gaps(beside: "person", in: wide)
        #expect(generation.count == 2 && generation.allSatisfy { Self.near($0, gap) }, "\(generation)")
        let person = try #require(wide.slots.first { $0.id == "person" })
        #expect(Self.near(person.frame.midX, 600))
    }

    /// Judah with his brothers and David with his partners grow as wide as their names need: Judah's brothers all show
    /// at 1,200 pt (folded at 800), every one of David's partners from 1,000; each tree wider than at 800, every neighbour
    /// on the person's line one gap apart.
    @Test(.needsRealBible) func aLargeFamilyGrowsAsWideAsItsNamesNeed() throws {
        let gap = FamilyTreeFolding.gap(Self.reader)
        let judah = try family(1751, "GEN")
        let (judahWide, judahNarrower) = (geometry(judah, 1_200, type: Self.reader), geometry(judah, 800, type: Self.reader))
        #expect(!judahWide.fold.siblings && !judahWide.fold.halfSiblings && judahNarrower.fold.siblings)
        #expect(Self.extent(judahWide) > 1_000 && Self.extent(judahNarrower) < Self.extent(judahWide) && Self.extent(judahNarrower) <= 800,
                "\(Self.extent(judahWide)), \(Self.extent(judahNarrower))")
        let david = try family(994, "2SA")
        let (davidWide, davidNarrower) = (geometry(david, 1_000, type: Self.reader), geometry(david, 800, type: Self.reader))
        #expect(davidWide.fold.foldedHouseholds == 0 && geometry(david, 1_200, type: Self.reader).fold.foldedHouseholds == 0)
        #expect(davidNarrower.fold.foldedHouseholds > 0 && Self.extent(davidWide) > Self.extent(davidNarrower) + 100, "\(Self.extent(davidWide))")
        for laid in [judahWide, davidWide] {
            let generation = Self.gaps(beside: "person", in: laid)
            #expect(!generation.isEmpty && generation.allSatisfy { Self.near($0, gap) }, "\(generation)")
        }
    }

    /// The least width (to half a point, in 0...2,000) at which `tree` is laid as a tree at the reader's type.
    private static func threshold(_ tree: FamilyTree, type: LibraryType = reader) -> CGFloat {
        var (low, high): (CGFloat, CGFloat) = (0, 2_000)
        while high - low > 0.5 {
            let middle = ((low + high) / 2 * 2).rounded() / 2
            if FamilyTreeLayoutRule.fitsAsTree(tree, width: middle, type: type) { high = middle } else { low = middle }
        }
        return high
    }

    /// Matt, 2026-11-24: "at a certain point it should just fallback to the same family tree design of the iOS app". Wide,
    /// each is a tree; too narrow for its names at the gap (a name cut, the person stacked under the chips, an opened
    /// "n more" needing a third row), the family line.
    @Test(.needsRealBible) func aTreeTooNarrowForItsNamesFallsBackToTheLine() throws {
        // Each person, a width too narrow for the tree, and the threshold as measured at 18 pt (SF Pro, macOS 26), held to 15 pt.
        let people: [(Int, String, String, CGFloat, CGFloat)] = [
            (994, "2SA", "David", 400, 657), (1751, "GEN", "Judah", 300, 391), (682, "GEN", "Jacob", 240, 286), (903, "RUT", "Jesse", 100, 106),
            (1830, "GEN", "Lot", 400, 543), (1676, "LUK", "John the Baptist", 150, 180),
        ]
        for (id, book, name, narrow, expected) in people {
            let tree = try family(id, book)
            #expect(tree.person.name == name)
            let threshold = Self.threshold(tree)
            #expect(FamilyTreeLayoutRule.fitsAsTree(tree, width: 1_200, type: Self.reader), "\(name) at 1,200")
            #expect(!FamilyTreeLayoutRule.fitsAsTree(tree, width: narrow, type: Self.reader), "\(name) at \(narrow)")
            #expect(FamilyTreeLayoutRule.fitsAsTree(tree, width: threshold, type: Self.reader), "\(name)")
            #expect(!FamilyTreeLayoutRule.fitsAsTree(tree, width: threshold - 0.5, type: Self.reader), "\(name)")
            #expect(abs(threshold - expected) <= 15, "\(name)'s threshold is \(threshold)")
        }
        // Jesse's children fold into "n more" as the siblings do (a tree), and a person with only parents is a tree down to
        // a very narrow page: both fall back only where a name would be cut.
        let john = try family(1676, "LUK")
        #expect(john.siblings.isEmpty && john.households.isEmpty && john.children.isEmpty && john.parents.count == 2)
        let jesse = try family(903, "RUT")
        #expect(!jesse.hasMothersRow && FamilyTreeFolding.fold(jesse, width: 400, gap: FamilyTreeFolding.gap(Self.reader),
                                                                 measure: SystemFamilyTreeMeasure(type: Self.reader)).childrenShown != nil)
        #expect(FamilyTreeLayoutRule.fitsAsTree(jesse, width: 400, type: Self.reader))
    }

    /// The rule lays the tree with the most rows it can need: "n more" and the "not named" chip both open, since the
    /// eleven's join keeps the opened mothers to its leading side. Wherever David's page shows the tree, opening both never
    /// takes a third row nor cuts a name (the review of 2026-11-24: at 600 and 640 pt it did, with the rule at 568).
    @Test(.needsRealBible) func theRuleAllowsForTheElevenOpenToo() throws {
        let david = try family(994, "2SA")
        for width in stride(from: CGFloat(560), through: 1_200, by: 10) where FamilyTreeLayoutRule.fitsAsTree(david, width: width, type: Self.reader) {
            for open: Set<FamilyChip> in [[.households], [.households, .notNamed], [.siblings, .halfSiblings, .households, .notNamed, .children]] {
                let laid = geometry(david, width, open: open, type: Self.reader)
                #expect(laid.householdRows <= 1 && !laid.slots.contains(where: \.truncated), "David at \(width), \(open): \(laid.householdRows) rows")
            }
        }
    }

    /// The parents are laid over the person, and where their own parents hold them off the centre the person moves under
    /// them as far as its row lets it (the review of 2026-11-24: Josiah at 320 pt stood 33 pt off his parents' drop with
    /// room to move). Every real tree, wherever the person could reach the drop.
    @Test(.needsRealBible) func thePersonStandsUnderTheParentsWhereItCan() throws {
        let josiah = try family(1730, "2KI")
        #expect(josiah.person.name == "Josiah" && josiah.siblings.isEmpty && josiah.halfSiblings.isEmpty)
        for width: CGFloat in [320, 360] {
            let laid = geometry(josiah, width, type: Self.reader)
            let person = try #require(laid.slots.first { $0.id == "person" })
            let parents = laid.slots.filter { if case .parent = $0.kind { true } else { false } }.map(\.frame.midX)
            #expect(parents.count == 2 && Self.near((parents.min()! + parents.max()!) / 2, person.frame.midX), "\(parents) over \(person.frame.midX)")
            #expect(!Self.near(person.frame.midX, width / 2), "Josiah is centred at \(width): the case no longer tests the move")
        }
        var off: [String] = []
        for tree in try Self.everyFamily() where !tree.parents.isEmpty {
            for width: CGFloat in [240, 320, 640, 1_040] {
                let laid = geometry(tree, width, type: Self.reader)
                guard !laid.personStacked, let person = laid.slots.first(where: { $0.id == "person" }) else { continue }
                let parents = laid.slots.filter { if case .parent = $0.kind { true } else { false } }.map(\.frame.midX)
                let delta = (parents.min()! + parents.max()!) / 2 - person.frame.midX
                let generation = laid.slots.filter { slot in
                    switch slot.kind {
                    case .person, .sibling, .halfSibling: true
                    case .chip(let chip, _): chip == .siblings || chip == .halfSiblings
                    default: false
                    }
                }
                let low = generation.map(\.frame.minX).min() ?? 0, high = generation.map(\.frame.maxX).max() ?? 0
                let reachable = delta > 0 ? high + delta <= width + 0.5 : low + delta >= -0.5
                if abs(delta) > 0.5, reachable { off.append("\(tree.person.name) (\(tree.person.id)) at \(width): \(delta)") }
            }
        }
        #expect(off.isEmpty, "\(off.count) off their parents: \(off.prefix(20))")
    }

    /// The rule is monotone in width, so a resize crosses it once: from 200 to 1,200 pt, a width that lays a tree lays one
    /// at every wider width.
    @Test(.needsRealBible) func theFallbackIsCrossedOnceAsTheWindowWidens() throws {
        for (id, book) in [(994, "2SA"), (1751, "GEN"), (682, "GEN"), (903, "RUT"), (1830, "GEN"), (1676, "LUK"), (905, "MAT"), (985, "GEN")] {
            let tree = try family(id, book)
            var fits = false
            for width in stride(from: CGFloat(200), through: 1_200, by: 1) {
                let now = FamilyTreeLayoutRule.fitsAsTree(tree, width: width, type: Self.reader)
                #expect(now || !fits, "\(tree.person.name) flips back to the line at \(width)")
                fits = now
            }
            #expect(fits, "\(tree.person.name) is no tree at 1,200")
        }
    }

    private func slot(_ geometry: FamilyTreeGeometry, _ name: String) throws -> FamilyTreeGeometry.Slot {
        try #require(geometry.slots.first { Self.name(of: $0.kind) == name })
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

    private static func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= 0.5 }

    private static func overlapping(_ slots: [FamilyTreeGeometry.Slot]) -> [String] {
        var pairs: [String] = []
        for (index, a) in slots.enumerated() {
            for b in slots[(index + 1)...] {
                let common = a.frame.intersection(b.frame)
                if !common.isNull, common.width > 0.01, common.height > 0.01 { pairs.append("\(a.id) × \(b.id)") }
            }
        }
        return pairs
    }

    /// Review Focus 4: every slot and line inside `0...width`, no two names over each other, at the
    /// test widths, with every chip open at 320 and 472, and at every 10 pt from 200, the tree's floor.
    @Test(.needsRealBible) func theTreeIsNeverWiderThanItsColumn() throws {
        let people = [(994, "2SA", "David"), (682, "GEN", "Jacob"), (903, "RUT", "Jesse"), (1751, "GEN", "Judah"), (905, "MAT", "Jesus Christ")]
        let every: Set<FamilyChip> = [.siblings, .halfSiblings, .households, .notNamed, .children]
        var cases: [(String, FamilyTreeGeometry, CGFloat)] = []
        for (id, book, name) in people {
            let tree = try family(id, book)
            #expect(tree.person.name == name)
            for width in [CGFloat(2_000)] + stride(from: CGFloat(200), through: 480, by: 10) {
                cases.append(("\(name) at \(width)", geometry(tree, width), width))
            }
            for width: CGFloat in [320, 472] { cases.append(("\(name) open at \(width)", geometry(tree, width, open: every), width)) }
            // At the reader's 18 pt and its gap, the widths a Library page gives the tree.
            for width in stride(from: CGFloat(240), through: 1_200, by: 20) {
                cases.append(("\(name) at \(width), 18 pt", geometry(tree, width, type: Self.reader), width))
                cases.append(("\(name) open at \(width), 18 pt", geometry(tree, width, open: every, type: Self.reader), width))
            }
        }
        for (label, tree, width) in cases {
            let outside = tree.slots.filter { $0.frame.minX < 0 || $0.frame.maxX > width }.map(\.id)
            #expect(outside.isEmpty, "\(label): \(outside)")
            let xs = tree.lines.flatMap { [$0.from.x, $0.to.x] }
            #expect((xs.min() ?? 0) >= 0 && (xs.max() ?? 0) <= width, "\(label): a line reaches \(xs.min() ?? 0)...\(xs.max() ?? 0)")
            let overlaps = Self.overlapping(tree.slots)
            #expect(overlaps.isEmpty, "\(label): \(overlaps)")
        }
    }

    /// Every real person with a family, read once for the sweeps below: everyone a book names.
    private static func everyFamily() throws -> [FamilyTree] {
        let store = try BenchmarkChapter.realStore()
        var seen: Set<Int> = []
        let ids = try BookCatalog.all.flatMap { try store.people(inBook: $0.id) }.map(\.id).filter { seen.insert($0).inserted }
        return try ids.compactMap { id in
            guard let person = try store.person(id) else { return nil }
            let relatives = try store.relatives(of: id)
            guard !relatives.isEmpty else { return nil }
            return FamilyTree.make(
                person: PersonSummary(id: person.id, name: person.name, label: person.label, verseCount: person.verseCount),
                relatives: relatives,
                parentsOfChildren: try store.parents(of: relatives.filter { $0.kind == .child }.map(\.person.id)),
                parentsOfParents: try store.parents(of: relatives.filter { $0.kind == .father || $0.kind == .mother }.map(\.person.id)))
        }
    }

    /// Spec 5.2's "never a sideways scroll" for every real tree at the narrow widths (the tree is ~243 pt at
    /// the 820 pt window): each slot's frame and each line's ends inside the column, chips closed and every
    /// chip open. A name too long for its share is cut to fit, the last resort (Task 12).
    @Test(.needsRealBible) func everyRealTreeKeepsToItsColumn() throws {
        let every: Set<FamilyChip> = [.siblings, .halfSiblings, .households, .notNamed, .children]
        let families = try Self.everyFamily()
        #expect(families.count > 2_000)
        var outside: [String] = []
        let passes: [(LibraryType, [CGFloat])] = [(.system, [200, 240, 270, 332]), (Self.reader, [240, 640, 1_200])]
        for tree in families {
            for (type, width) in passes.flatMap({ pass in pass.1.map { (pass.0, $0) } }) {
                for open in [Set<FamilyChip>(), every] {
                    let laid = geometry(tree, width, open: open, type: type)
                    let label = "\(tree.person.name) (\(tree.person.id)) at \(Int(width)) (\(type.readerSize ?? 13) pt)\(open.isEmpty ? "" : ", open")"
                    outside += laid.slots.filter { $0.frame.minX < -0.01 || $0.frame.maxX > width + 0.01 }.map { "\(label): \($0.id)" }
                    let xs = laid.lines.flatMap { [$0.from.x, $0.to.x] }
                    if (xs.min() ?? 0) < -0.01 || (xs.max() ?? 0) > width + 0.01 { outside.append("\(label): a line") }
                }
            }
        }
        #expect(outside.isEmpty, "\(outside.count) outside: \(outside.prefix(40))")
    }

    /// The last resort keeps the whole name where it is not shown: a cut name reads in full to VoiceOver.
    @Test(.needsRealBible) func aNameCutToFitIsReadWhole() throws {
        let families = try Self.everyFamily()
        let measure = SystemFamilyTreeMeasure()
        var cut: [(FamilyTreeGeometry.Slot, [FamilyTreeSpeech.Group])] = []
        for tree in families {
            let laid = geometry(tree, 200)
            guard laid.slots.contains(where: \.truncated) else { continue }
            let groups = FamilyTreeSpeech.groups(tree, geometry: laid)
            for slot in laid.slots where slot.truncated { cut.append((slot, groups)) }
        }
        #expect(!cut.isEmpty)
        for (slot, groups) in cut {
            guard let name = Self.name(of: slot.kind) else { continue }
            let style: FamilyTreeStyle = switch slot.kind {
            case .grandparent: .grandparent
            case .child: .child
            default: .name
            }
            #expect(slot.frame.width < measure.size(name, style).width, "\(slot.id) is cut but as wide as its name")
            let group = groups.first { $0.slots.contains(slot.id) }
            #expect(group?.label.contains(name) == true, "\(slot.id) is not read whole")
        }
    }

    /// The measure at the reader's type (Matt's review, 2026-11-24) sets each style at the font the tree draws it in.
    @Test func theReadersMeasureSetsANameAtTheFontTheTreeDrawsItIn() {
        let type = LibraryType(readerSize: 18)
        let reader = SystemFamilyTreeMeasure(type: type), system = SystemFamilyTreeMeasure()
        #expect(reader.size("David", .name).width == BookNameMeasure.width(of: "David", font: type.platformFont(.body)))
        #expect(reader.size("David", .person).width
            == BookNameMeasure.width(of: "David", font: type.platformFont(.body, weight: .semibold)) + 2 * AppSpacing.xs)
        // Grandparents and children at the reader's reading size, which is `.body`.
        #expect(reader.size("Obed", .grandparent).width == BookNameMeasure.width(of: "Obed", font: type.platformFont(.body)))
        for style: FamilyTreeStyle in [.grandparent, .name, .person, .child, .chip, .notNamedLabel] {
            #expect(reader.size("Bathsheba", style).width > system.size("Bathsheba", style).width, "\(style)")
            #expect(reader.size("Bathsheba", style).height > system.size("Bathsheba", style).height, "\(style)")
        }
    }

    /// A chip is drawn exactly as wide as the measure laid it (Matt, 2026-11-24: an opened run "tight against the page's
    /// right edge"): SwiftUI draws the chevron a point wider or narrower than its `NSImage` at some sizes (the reader's
    /// 14 and 24 pt among them), so a chip at the tree's edge reached past it; the chevron now sits in the measured box.
    @MainActor @Test func aChipIsDrawnAsWideAsItIsMeasured() {
        for type in [LibraryType.system] + stride(from: CGFloat(12), through: 30, by: 1).map({ LibraryType(readerSize: $0) }) {
            let measure = SystemFamilyTreeMeasure(type: type)
            for (label, symbol) in [("11 half-siblings", "chevron.down"), ("Fewer", "chevron.up"), ("2 more", "chevron.down")] {
                let drawn = NSHostingView(rootView: FamilyTreeChipLabel(type: type) { Text(label) } symbol: { Image(systemName: symbol) }
                    .font(type.font(FamilyTreeStyle.chip.text(type).style)).fixedSize()).fittingSize
                #expect(drawn.width == measure.size(label, .chip).width, "\(label) at \(type.readerSize ?? 13) pt: drawn \(drawn.width)")
            }
        }
    }

    /// Benjamin's tree (his eleven half-siblings to the trailing side) at the reader's 14, 18 and 24 pt, from the width
    /// where it is first a tree to a 1,400 pt window's, closed and opened: every name and chip inside the tree's width,
    /// which is the page's less `lg` each side, so nothing comes nearer the page's edge than the text column does.
    @Test(.needsRealBible) func benjaminsOpenedRunsKeepInsideThePagesMargin() throws {
        let tree = try family(463, "EZR")
        #expect(tree.halfSiblings.count == 11)
        var outside: [String] = []
        for size: CGFloat in [14, 18, 24] {
            let type = LibraryType(readerSize: size), measure = SystemFamilyTreeMeasure(type: type), gap = FamilyTreeFolding.gap(type)
            let first = try #require(stride(from: CGFloat(200), through: 1_352, by: 1).first {
                FamilyTreeLayoutRule.fitsAsTree(tree, width: $0, gap: gap, measure: measure)
            })
            for width in stride(from: first, through: 1_352, by: 3) {
                for open: Set<FamilyChip> in [[], [.halfSiblings], [.siblings, .halfSiblings, .households, .notNamed, .children]] {
                    let laid = geometry(tree, width, open: open, type: type)
                    outside += laid.slots.filter { $0.frame.minX < 0 || $0.frame.maxX > width }.map { "\(size) pt at \(width): \($0.id)" }
                }
            }
        }
        #expect(outside.isEmpty, "\(outside.prefix(20))")
    }

    /// One mapping of the tree's styles, read by the measure and the view: names in `.body`, the person semibold, a chip
    /// in `.callout`, "not named" in italic `.caption`, grandparents and children in the reading style.
    @Test func theTreesStylesAreOneMapping() {
        let reader = LibraryType(readerSize: 18)
        for type in [LibraryType.system, reader] {
            #expect(FamilyTreeStyle.name.text(type) == FamilyTreeText(style: .body))
            #expect(FamilyTreeStyle.person.text(type) == FamilyTreeText(style: .body, weight: .semibold))
            #expect(FamilyTreeStyle.chip.text(type) == FamilyTreeText(style: .callout))
            #expect(FamilyTreeStyle.notNamedLabel.text(type) == FamilyTreeText(style: .caption, italic: true))
        }
        #expect(FamilyTreeStyle.grandparent.text(.system) == FamilyTreeText(style: .callout))
        #expect(FamilyTreeStyle.child.text(.system) == FamilyTreeText(style: .callout))
        #expect(FamilyTreeStyle.grandparent.text(reader) == FamilyTreeText(style: .body))
        #expect(FamilyTreeStyle.child.text(reader) == FamilyTreeText(style: .body))
    }

    /// David's page at the reader's 18 pt in a wide window: the tree has the page's width, so no partner folds.
    @Test(.needsRealBible) func davidsPartnersAllShowAtTheReadersTypeInAWideWindow() throws {
        let type = LibraryType(readerSize: 18)
        let laid = FamilyTreeGeometry.make(try family(994, "2SA"), width: 1_000, open: [], rowPitch: type.metric(FamilyTreeView.rowPitch),
                                           measure: SystemFamilyTreeMeasure(type: type))
        #expect(laid.fold.foldedHouseholds == 0)
        #expect(!laid.slots.contains { if case .chip(.households, _) = $0.kind { true } else { false } })
    }

    @Test(.needsRealBible) func thePersonIsCentredAndGrandparentsSitOverTheirParent() throws {
        let david = geometry(try family(994, "2SA"), 472)
        let person = try #require(david.slots.first { $0.kind == .person })
        #expect(Self.near(person.frame.midX, 236))
        #expect(Self.near(try slot(david, "Jesse").frame.midX, 236))
        let jacob = geometry(try family(682, "GEN"), 472)
        let (abraham, sarah) = (try slot(jacob, "Abraham"), try slot(jacob, "Sarah"))
        #expect(Self.near((abraham.frame.midX + sarah.frame.midX) / 2, try slot(jacob, "Isaac").frame.midX))
        #expect(Self.near(try slot(jacob, "Bethuel").frame.midX, try slot(jacob, "Rebekah").frame.midX))
    }

    @Test(.needsRealBible) func childrenStackUnderTheirMother() throws {
        let david = geometry(try family(994, "2SA"), 2_000)
        let bathsheba = try slot(david, "Bathsheba")
        guard case .head(let household) = bathsheba.kind else { Issue.record("Bathsheba is not a head"); return }
        let children = david.slots.filter { if case .child(_, let column) = $0.kind { column == household.id } else { false } }
        #expect(children.compactMap { Self.name(of: $0.kind) } == ["Nathan", "Shobab", "Solomon", "Shammua"])
        #expect(children.allSatisfy { Self.near($0.frame.midX, bathsheba.frame.midX) })
        for (above, below) in zip(children, children.dropFirst()) {
            #expect(Self.near(below.frame.minY - above.frame.minY, Self.rowPitch))
        }
    }

    @Test(.needsRealBible) func everyNameHangsFromALine() throws {
        let laid: [(Int, String, CGFloat, LibraryType)] = [(994, "2SA", 472, .system), (903, "RUT", 472, .system)]
            + [640, 1_052, 1_200].flatMap { width in [(994, "2SA", width, Self.reader), (903, "RUT", width, Self.reader), (1830, "GEN", width, Self.reader)] }
        for (id, book, width, type) in laid {
            let tree = geometry(try family(id, book), width, type: type)
            let top = try #require(tree.slots.min { $0.frame.minY < $1.frame.minY })
            var firstInColumn: Set<String> = []
            let hanging = tree.slots.filter { slot in
                if slot.frame.minY < top.frame.maxY { return false }
                guard case .child(_, let column?) = slot.kind else { return true }
                return firstInColumn.insert(column).inserted
            }
            func endsAtTop(_ line: FamilyTreeGeometry.Line, _ slot: FamilyTreeGeometry.Slot) -> Bool {
                line.from.x == line.to.x && Self.near(line.to.x, slot.frame.midX) && Self.near(max(line.from.y, line.to.y), slot.frame.minY)
            }
            for slot in hanging {
                #expect(tree.lines.contains { endsAtTop($0, slot) }, "\(slot.id) hangs from no line")
            }
            let half = tree.slots.filter {
                switch $0.kind {
                case .halfSibling, .chip(.halfSiblings, _): true
                default: false
                }
            }
            for line in tree.lines {
                let toHalf = half.contains { endsAtTop(line, $0) }
                if toHalf { #expect(line.dashed, "a half-sibling's rise is solid") }
                if line.dashed { #expect(toHalf || line.from.y == line.to.y, "a dashed line from \(line.from) to \(line.to)") }
            }
        }
    }

    @Test(.needsRealBible) func anOpenChipReplacesItsCountWithItsNames() throws {
        let david = geometry(try family(994, "2SA"), 472, open: [.siblings])
        let siblings = david.slots.enumerated().filter { if case .sibling = $0.element.kind { true } else { false } }
        #expect(siblings.compactMap { Self.name(of: $0.element.kind) }
                == ["Abinadab", "Eliab", "Elihu", "Nethaneel", "Ozem", "Raddai", "Shammah"])
        #expect(!david.slots.contains { if case .chip(.siblings, _) = $0.kind { true } else { false } })
        let fewer = try #require(david.slots.firstIndex { $0.kind == .fewer(.siblings) })
        #expect(fewer > (siblings.last?.offset ?? .max))
        #expect(david.slots.allSatisfy { $0.frame.minX >= 0 && $0.frame.maxX <= 472 })
    }

    /// The ids of an open chip's run: its names and "Fewer"; empty when the chip is not open.
    private static func run(_ chip: FamilyChip, in tree: FamilyTree, _ laid: FamilyTreeGeometry) -> [String] {
        guard laid.slots.contains(where: { $0.id == "fewer-\(chip)" }) else { return [] }
        let (named, unnamed) = FamilyTreeFolding.mothers(of: tree)
        let names: [String] = switch chip {
        case .siblings: tree.siblings.map { "sibling-\($0.id)" }
        case .halfSiblings: tree.halfSiblings.map { "halfSibling-\($0.id)" }
        case .households:
            FamilyTreeFolding.folded(named, count: laid.fold.foldedHouseholds).flatMap { ["head-\($0.id)"] + $0.children.map { "child-\($0.id)" } }
        case .notNamed: unnamed?.children.map { "child-\($0.id)" } ?? []
        case .children: tree.children.dropFirst(laid.fold.childrenShown ?? tree.children.count).map { "child-\($0.id)" }
        }
        return names + ["fewer-\(chip)"]
    }

    /// Departure 10 as ruled after Task 9's review: an open run hangs whole from a bar of its own, where its
    /// chip's join ends; its names lie under the bar's span; no line passes through a name (the person's drop
    /// keeps between the siblings' and half-siblings' runs, the eleven's join clear of the "n more" run); and a
    /// line that ends on a name is that name's own rise, at its centre. Lot's daughters and Hammoleketh are
    /// Departure 11's stacked rows with a long sibling's name, under ~268 pt (Task 12). The same at the Mac's reader type
    /// (18 pt, the default) at the widths a Library page gives it (Matt's review, 2026-11-24).
    @Test(.needsRealBible) func anOpenRunHangsWholeFromABarOfItsOwn() throws {
        let every: Set<FamilyChip> = [.siblings, .halfSiblings, .households, .notNamed, .children]
        let passes: [(LibraryType, [CGFloat])] = [
            (.system, stride(from: CGFloat(200), through: 480, by: 10).map { $0 } + [2_000]),
            (LibraryType(readerSize: 18), stride(from: CGFloat(240), through: 1_200, by: 40).map { $0 }),
        ]
        for (id, book) in [(994, "2SA"), (682, "GEN"), (903, "RUT"), (1751, "GEN"), (905, "MAT"), (985, "GEN"), (984, "GEN"), (1364, "1CH")] {
            let tree = try family(id, book)
            for (type, widths) in passes {
                let pitch = type.metric(Self.rowPitch)
                for width in widths {
                    for open in [every, [.siblings], [.halfSiblings], [.households], [.notNamed], [.children]] {
                        let laid = geometry(tree, width, open: open, type: type)
                        let label = "\(tree.person.name) at \(width) (\(type.readerSize ?? 13) pt), \(open)"
                        let bars = laid.lines.filter { Self.near($0.from.y, $0.to.y) }
                        // No line crosses a bar: a vertical meets a bar only where it ends or starts on it.
                        for line in laid.lines where Self.near(line.from.x, line.to.x) {
                            let (upper, lower) = (min(line.from.y, line.to.y), max(line.from.y, line.to.y))
                            let crossing = bars.filter { bar in
                                min(bar.from.x, bar.to.x) + 0.5 < line.from.x && line.from.x < max(bar.from.x, bar.to.x) - 0.5
                                    && upper + 0.5 < bar.from.y && bar.from.y < lower - 0.5
                            }
                            #expect(crossing.isEmpty, "\(label): the line at x \(line.from.x) crosses the bar at y \(crossing.map(\.from.y))")
                        }
                        for line in laid.lines where Self.near(line.from.x, line.to.x) && !Self.near(line.from.y, line.to.y) {
                            let (upper, lower) = (min(line.from.y, line.to.y), max(line.from.y, line.to.y))
                            let crossed = laid.slots.filter { slot in
                                slot.frame.minX < line.from.x && line.from.x < slot.frame.maxX && slot.frame.minY < lower - 0.5 && upper + 0.5 < slot.frame.maxY
                            }
                            #expect(crossed.isEmpty, "\(label): the line at x \(line.from.x) passes through \(crossed.map(\.id))")
                            let onBar = bars.contains { bar in
                                Self.near(bar.from.y, lower) && min(bar.from.x, bar.to.x) - 0.5 <= line.from.x && line.from.x <= max(bar.from.x, bar.to.x) + 0.5
                            }
                            if onBar { continue }
                            let landed = laid.slots.filter { slot in
                                slot.frame.minX - 0.5 <= line.from.x && line.from.x <= slot.frame.maxX + 0.5
                                    && lower - 0.5 <= slot.frame.minY && slot.frame.minY <= lower + AppSpacing.xs
                            }
                            #expect(landed.allSatisfy { Self.near($0.frame.midX, line.from.x) }, "\(label): a line ends at \(lower) on \(landed.map(\.id))")
                        }
                        for chip in open {
                            let ids = Set(Self.run(chip, in: tree, laid))
                            let run = laid.slots.filter { ids.contains($0.id) }
                            guard let top = run.map(\.frame.minY).min() else { continue }
                            #expect(run.count == ids.count, "\(label): \(chip)'s run is missing names")
                            // An opened "n more" is rows of the tree, not a run (Matt's B, 2026-11-24).
                            if chip == .households {
                                let failures = Self.householdRows(tree, laid)
                                #expect(failures.isEmpty, "\(label): \(failures)")
                                continue
                            }
                            let bar = bars.first { bar in
                                bar.from.y < top && top - AppSpacing.xs - pitch <= bar.from.y
                                    && run.allSatisfy { min(bar.from.x, bar.to.x) - 0.5 <= $0.frame.minX && $0.frame.maxX <= max(bar.from.x, bar.to.x) + 0.5 }
                            }
                            #expect(bar != nil, "\(label): \(chip)'s run has no bar over it")
                            // Each line of the run starts at the run's leading edge (no lane is left in these runs).
                            let leading = run.map(\.frame.minX).min() ?? 0
                            var starts: [CGFloat: CGFloat] = [:]
                            for slot in run { starts[slot.frame.midY.rounded()] = min(starts[slot.frame.midY.rounded()] ?? .infinity, slot.frame.minX) }
                            let indented = starts.filter { !Self.near($0.value, leading) }.keys.sorted()
                            #expect(indented.isEmpty, "\(label): \(chip)'s lines at y \(indented) do not start at \(leading)")
                            if let bar {
                                let joined = laid.lines.contains { line in
                                    Self.near(line.from.x, line.to.x) && Self.near(max(line.from.y, line.to.y), bar.from.y)
                                        && min(bar.from.x, bar.to.x) - 0.5 <= line.from.x && line.from.x <= max(bar.from.x, bar.to.x) + 0.5
                                }
                                #expect(joined, "\(label): nothing joins \(chip)'s bar")
                            }
                        }
                    }
                }
            }
        }
    }

    /// Departure 11's stacked rows state the family truly (the final review's Important 1): the person hangs
    /// from the parents' drop, not from the siblings' chip; the siblings' and half-siblings' rises start on the
    /// parents' bar; and the next generation hangs from the person. At every width from 200, chips closed and open.
    @Test(.needsRealBible) func thePersonsRiseMeetsTheParentsDropAtEveryWidth() throws {
        var stacked = 0
        let passes: [(LibraryType, [CGFloat])] = [
            (.system, stride(from: CGFloat(200), through: 480, by: 1).map { $0 }),
            (Self.reader, stride(from: CGFloat(240), through: 1_200, by: 4).map { $0 }),
        ]
        for (id, book) in [(994, "2SA"), (985, "GEN"), (984, "GEN"), (1364, "1CH"), (1751, "GEN"), (905, "MAT"), (1830, "GEN")] {
            let tree = try family(id, book)
            for (type, width) in passes.flatMap({ pass in pass.1.map { (pass.0, $0) } }) {
                for open in [Set<FamilyChip>(), [.siblings, .halfSiblings]] {
                    let laid = geometry(tree, width, open: open, type: type)
                    let label = "\(tree.person.name) at \(width) (\(type.readerSize ?? 13) pt), \(open)"
                    let person = try #require(laid.slots.first { $0.kind == .person })
                    let parents = laid.slots.filter { if case .parent = $0.kind { true } else { false } }
                    guard let lowest = parents.map(\.frame.maxY).max() else { continue }
                    let feed = parents.count == 1
                        ? CGPoint(x: parents[0].frame.midX, y: parents[0].frame.maxY)
                        : CGPoint(x: (parents.map(\.frame.midX).min()! + parents.map(\.frame.midX).max()!) / 2, y: lowest + AppSpacing.xs)
                    func vertical(_ line: FamilyTreeGeometry.Line) -> Bool { Self.near(line.from.x, line.to.x) && !Self.near(line.from.y, line.to.y) }
                    func rise(to slot: FamilyTreeGeometry.Slot) -> FamilyTreeGeometry.Line? {
                        laid.lines.first { vertical($0) && Self.near($0.from.x, slot.frame.midX) && Self.near(max($0.from.y, $0.to.y), slot.frame.minY) }
                    }
                    // The parents' drop: from the feed straight down to the bar the generation hangs from.
                    let drop = laid.lines.first { vertical($0) && Self.near($0.from.x, feed.x) && Self.near(min($0.from.y, $0.to.y), feed.y) }
                    let barY = drop.map { max($0.from.y, $0.to.y) }
                    let personRise = rise(to: person)
                    #expect(drop != nil && personRise != nil, "\(label): no drop or no rise to the person")
                    guard let barY, let personRise else { continue }
                    let top = min(personRise.from.y, personRise.to.y)
                    let onDrop = Self.near(person.frame.midX, feed.x) && (Self.near(top, barY) || Self.near(top, feed.y))
                    let onBar = Self.near(top, barY) && laid.lines.contains { bar in
                        Self.near(bar.from.y, barY) && Self.near(bar.to.y, barY)
                            && min(bar.from.x, bar.to.x) - 0.5 <= min(feed.x, person.frame.midX) && max(feed.x, person.frame.midX) <= max(bar.from.x, bar.to.x) + 0.5
                    }
                    #expect(onDrop || onBar, "\(label): the person's rise starts at \(top), not on the parents' drop (bar at \(barY))")
                    let side = laid.slots.filter {
                        switch $0.kind {
                        case .chip(.siblings, _), .chip(.halfSiblings, _): true
                        default: false
                        }
                    }
                    if side.contains(where: { $0.frame.maxY < person.frame.minY }) { stacked += 1 }
                    for chip in side {
                        let chipRise = rise(to: chip)
                        #expect(chipRise.map { Self.near(min($0.from.y, $0.to.y), barY) } == true, "\(label): \(chip.id) does not hang from the parents' bar")
                    }
                    if tree.hasMothersRow || !tree.children.isEmpty {
                        let feedsOn = laid.lines.contains { vertical($0) && Self.near($0.from.x, person.frame.midX) && Self.near(min($0.from.y, $0.to.y), person.frame.maxY) }
                        #expect(feedsOn, "\(label): the next generation does not hang from the person")
                    }
                }
            }
        }
        #expect(stacked > 0, "no width stacked the person's generation")
    }

    /// An opened "n more" as rows of the tree (Matt's B, 2026-11-24): each folded mother and "Fewer" hang by a rise at
    /// their centre from a bar, a folded mother's children are centred under her and below her, every such bar is
    /// joined to one above it by a vertical, and "Fewer" ends the last row. What fails, by slot; empty when closed.
    private static func householdRows(_ tree: FamilyTree, _ laid: FamilyTreeGeometry) -> [String] {
        guard let fewer = laid.slots.first(where: { $0.id == "fewer-households" })?.frame else { return [] }
        let folded = FamilyTreeFolding.folded(FamilyTreeFolding.mothers(of: tree).named, count: laid.fold.foldedHouseholds)
        let frames = Dictionary(laid.slots.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })
        let bars = laid.lines.filter { near($0.from.y, $0.to.y) }
        let verticals = laid.lines.filter { near($0.from.x, $0.to.x) && !near($0.from.y, $0.to.y) }
        func spans(_ bar: FamilyTreeGeometry.Line, _ x: CGFloat) -> Bool {
            min(bar.from.x, bar.to.x) - 0.5 <= x && x <= max(bar.from.x, bar.to.x) + 0.5
        }
        /// A vertical from above ends at `y` at `x`.
        func joined(at y: CGFloat, _ x: (CGFloat) -> Bool) -> Bool {
            verticals.contains { near(max($0.from.y, $0.to.y), y) && x($0.from.x) }
        }
        var failures: [String] = [], heads: [CGRect] = []
        for id in folded.map({ "head-\($0.id)" }) + ["fewer-households"] {
            guard let frame = frames[id] else {
                failures.append("\(id) is not laid")
                continue
            }
            heads.append(frame)
            guard let rise = verticals.first(where: { near($0.from.x, frame.midX) && near(max($0.from.y, $0.to.y), frame.minY) }) else {
                failures.append("\(id) has no rise")
                continue
            }
            let top = min(rise.from.y, rise.to.y)
            if let bar = bars.first(where: { near($0.from.y, top) && spans($0, frame.midX) }) {
                if !joined(at: top, { spans(bar, $0) }) { failures.append("\(id)'s bar is joined to nothing above") }
            } else if !joined(at: top, { near($0, frame.midX) }) {
                failures.append("\(id) hangs from nothing")
            }
        }
        for household in folded {
            guard let head = frames["head-\(household.id)"] else { continue }
            for child in household.children {
                let frame = frames["child-\(child.id)"]
                if frame.map({ !near($0.midX, head.midX) || $0.minY < head.maxY }) ?? true { failures.append("child-\(child.id) is not under her") }
            }
        }
        let lowest = heads.map(\.midY).max() ?? 0
        if !near(fewer.midY, lowest) || heads.contains(where: { near($0.midY, fewer.midY) && $0.midX > fewer.midX }) {
            failures.append("Fewer does not end the last row")
        }
        return failures
    }

    /// David's opened "4 more" at 472 is a second row of the tree under the first (Matt's B, 2026-11-24): Eglah, Haggith,
    /// Maacah and Michal as heads on one line, each child centred under its mother, "Fewer" on that line after Michal,
    /// their bar joined to the first row's bar at the chip's place by a vertical. At 332 (the narrow page) the row
    /// continues on a third, Bathsheba among them with her children under her; with the eleven open too, the rows keep
    /// to the leading side of the eleven's join and the eleven's run comes under them.
    @Test(.needsRealBible) func anOpenedNMoreIsASecondRowOfTheTree() throws {
        let tree = try family(994, "2SA")
        let closed = geometry(tree, 472), laid = geometry(tree, 472, open: [.households])
        let chip = try #require(closed.slots.first { $0.id == "chip-households" }?.frame)
        let named = ["Eglah", "Haggith", "Maacah", "Michal"]
        let heads = try named.map { try slot(laid, $0) }
        #expect(heads.allSatisfy { if case .head = $0.kind { true } else { false } })
        #expect(heads.allSatisfy { Self.near($0.frame.midY, heads[0].frame.midY) } && heads.map(\.frame.minX) == heads.map(\.frame.minX).sorted())
        // Under the first row: below every slot that is not in the opened row.
        let opened = Set(Self.run(.households, in: tree, laid))
        let firstRow = laid.slots.filter { !opened.contains($0.id) }.map(\.frame.maxY).max() ?? 0
        #expect(heads.allSatisfy { $0.frame.minY >= firstRow + AppSpacing.md })
        for (mother, child) in [("Eglah", "Ithream"), ("Haggith", "Adonijah"), ("Maacah", "Absalom")] {
            let (head, under) = (try slot(laid, mother), try slot(laid, child))
            #expect(Self.near(under.frame.midX, head.frame.midX) && under.frame.minY > head.frame.maxY, "\(child) is not under \(mother)")
        }
        let fewer = try #require(laid.slots.first { $0.id == "fewer-households" }?.frame)
        #expect(Self.near(fewer.midY, heads[3].frame.midY) && fewer.minX > heads[3].frame.maxX)
        // The bar over them, where their rises start, reaching the chip's place, where a vertical joins it to the first row's bar.
        func riseTop(_ frame: CGRect) -> CGFloat? {
            laid.lines.first { Self.near($0.from.x, frame.midX) && Self.near($0.to.x, frame.midX) && Self.near(max($0.from.y, $0.to.y), frame.minY) }
                .map { min($0.from.y, $0.to.y) }
        }
        let barY = try #require(riseTop(heads[0].frame))
        #expect(heads.allSatisfy { riseTop($0.frame) == barY } && riseTop(fewer) == barY && barY < heads[0].frame.minY)
        let bar = laid.lines.first { line in
            Self.near(line.from.y, barY) && Self.near(line.to.y, barY)
                && ([chip.midX, fewer.midX] + heads.map(\.frame.midX)).allSatisfy { min(line.from.x, line.to.x) - 0.5 <= $0 && $0 <= max(line.from.x, line.to.x) + 0.5 }
        }
        #expect(bar != nil, "no bar over the second row")
        let firstBar = try #require(riseTop(try slot(laid, "Bathsheba").frame))
        #expect(laid.lines.contains { line in
            Self.near(line.from.x, chip.midX) && Self.near(line.to.x, chip.midX)
                && Self.near(min(line.from.y, line.to.y), firstBar) && Self.near(max(line.from.y, line.to.y), barY)
        }, "nothing joins the second row's bar to the first's at \(chip.midX)")
        #expect(Self.householdRows(tree, laid).isEmpty, "\(Self.householdRows(tree, laid))")

        let narrow = geometry(tree, 332, open: [.households])
        let foldedHeads = Set(FamilyTreeFolding.folded(FamilyTreeFolding.mothers(of: tree).named, count: narrow.fold.foldedHouseholds).map { "head-\($0.id)" }
            + ["fewer-households"])
        let lines = Set(narrow.slots.filter { foldedHeads.contains($0.id) }.map { $0.frame.midY.rounded() })
        #expect(lines.count >= 2, "at 332 the opened row does not continue on a third")
        #expect(Self.householdRows(tree, narrow).isEmpty, "\(Self.householdRows(tree, narrow))")
        let bathsheba = try slot(narrow, "Bathsheba"), nathan = try slot(narrow, "Nathan")
        #expect(narrow.fold.foldedHouseholds > 4 && Self.near(nathan.frame.midX, bathsheba.frame.midX) && nathan.frame.minY > bathsheba.frame.maxY)

        let both = geometry(tree, 472, open: [.households, .notNamed])
        let label = try #require(both.slots.first { if case .notNamedLabel = $0.kind { true } else { false } }?.frame)
        let rows = both.slots.filter { $0.id.hasPrefix("head-partner") && $0.frame.minY > firstRow } + [try #require(both.slots.first { $0.id == "fewer-households" })]
        #expect(rows.count == 5 && rows.allSatisfy { $0.frame.maxX <= label.midX - FamilyTreeFolding.gap / 2 + 0.5 })
        let eleven = both.slots.filter { if case .child(_, let household) = $0.kind { household == nil || household?.hasPrefix("notNamed") == true } else { false } }
        #expect(!eleven.isEmpty && eleven.allSatisfy { child in rows.allSatisfy { child.frame.minY > $0.frame.maxY } })
        #expect(Self.householdRows(tree, both).isEmpty, "\(Self.householdRows(tree, both))")
    }

    /// The siblings' run keeps to the leading side and the half-siblings' to the trailing side, side by side
    /// under the person's row (Judah).
    @Test(.needsRealBible) func openRunsKeepTheirSides() throws {
        // Judah folds both sides at 472.
        let judah = try family(1751, "GEN")
        let laid = geometry(judah, 472, open: [.siblings, .halfSiblings])
        let person = try #require(laid.slots.first { $0.id == "person" })
        let siblings = laid.slots.filter { Self.run(.siblings, in: judah, laid).contains($0.id) }
        let half = laid.slots.filter { Self.run(.halfSiblings, in: judah, laid).contains($0.id) }
        #expect(siblings.allSatisfy { $0.frame.maxX <= person.frame.midX - FamilyTreeFolding.gap / 2 + 0.5 })
        #expect(half.allSatisfy { $0.frame.minX >= person.frame.midX + FamilyTreeFolding.gap / 2 - 0.5 })
        let names = { (slots: [FamilyTreeGeometry.Slot]) in slots.filter { !$0.id.hasPrefix("fewer") }.map(\.frame.minY).min() }
        #expect(names(siblings) != nil && names(siblings) == names(half))
    }

    /// Spec 5.2's VoiceOver as it ships (the final review's Important 2): one element per relation group, in the
    /// reading's order, each name a named action that walks to that person; a group of one name is a link that
    /// walks; a folded chip a button that opens it; an open run's group offers "Fewer". Every slot is in a group,
    /// which is drawn over its slots, and a grandparent over both parents is read once.
    @Test(.needsRealBible) func theTreeReadsOneElementPerRelation() throws {
        let tree = try family(994, "2SA")
        let david = FamilyTreeGeometry.make(tree, width: 472, open: [], rowPitch: FamilyTreeView.rowPitch, measure: SystemFamilyTreeMeasure())
        let groups = FamilyTreeSpeech.groups(tree, geometry: david)
        func group(_ label: String) throws -> FamilyTreeSpeech.Group { try #require(groups.first { $0.label.hasPrefix(label) }) }
        func walks(_ group: FamilyTreeSpeech.Group) -> [String] {
            group.actions.map { if case .walk(let person) = $0 { person.name } else { "Fewer" } }
        }
        let person = try group("David")
        #expect(person.trait == .text && person.primary == nil && person.actions.isEmpty)
        let obed = try group("Grandparents: Obed")
        #expect(obed.trait == .link && walks(obed) == ["Obed"] && obed.primary == obed.actions.first)
        let bathsheba = try group("Bathsheba, partner. Children: Nathan")
        #expect(bathsheba.trait == .link && walks(bathsheba) == ["Bathsheba", "Nathan", "Shobab", "Solomon", "Shammua"])
        #expect(bathsheba.primary == bathsheba.actions.first)
        let half = try group("Half-siblings: Abigail, Zeruiah")
        #expect(half.trait == .text && half.primary == nil && walks(half) == ["Abigail", "Zeruiah"])
        let chip = try group("7 siblings, folded")
        #expect(chip.trait == .button && chip.primary == .toggle(.siblings) && chip.actions.isEmpty)
        let unnamed = try group("Children, mother not named: 11, folded")
        #expect(unnamed.trait == .button && unnamed.primary == .toggle(.notNamed))
        // Every slot is in one group; a group's frame covers its slots.
        let covered = groups.flatMap(\.slots)
        #expect(Set(covered) == Set(david.slots.map(\.id)) && Set(covered).count == covered.count)
        for group in groups {
            for id in group.slots {
                let frame = try #require(david.slots.first { $0.id == id }).frame
                #expect(group.frame.contains(frame), "\(group.label) does not cover \(id)")
            }
        }
        // An open run reads its names and offers "Fewer".
        let open = FamilyTreeSpeech.groups(tree, geometry: FamilyTreeGeometry.make(tree, width: 472, open: [.siblings], rowPitch: FamilyTreeView.rowPitch,
                                                                                    measure: SystemFamilyTreeMeasure()))
        let siblings = try #require(open.first { $0.label.hasPrefix("Siblings: ") })
        #expect(walks(siblings) == ["Abinadab", "Eliab", "Elihu", "Nethaneel", "Ozem", "Raddai", "Shammah", "Fewer"])
        #expect(siblings.actions.last == .toggle(.siblings) && siblings.slots.contains("fewer-siblings"))

        // The opened "4 more" as rows of columns: each mother read with her children and "Fewer" as an action, each group
        // over her column alone ("Fewer" in the last one's, after Michal), so no two overlap; every slot in one group.
        for width: CGFloat in [472, 332] {
            let laid = FamilyTreeGeometry.make(tree, width: width, open: [.households], rowPitch: FamilyTreeView.rowPitch, measure: SystemFamilyTreeMeasure())
            let read = FamilyTreeSpeech.groups(tree, geometry: laid)
            let eglah = try #require(read.first { $0.label == "Eglah, partner. Children: Ithream" })
            #expect(walks(eglah) == ["Eglah", "Ithream", "Fewer"] && eglah.primary == eglah.actions.first)
            let mothers = read.filter { $0.actions.last == .toggle(.households) }
            #expect(mothers.count == laid.fold.foldedHouseholds && mothers.last?.label == "Michal, partner")
            #expect(mothers.filter { $0.slots.contains("fewer-households") }.map(\.label) == ["Michal, partner"])
            let ids = read.flatMap(\.slots)
            #expect(Set(ids) == Set(laid.slots.map(\.id)) && Set(ids).count == ids.count, "at \(width)")
            for group in read {
                for id in group.slots {
                    let frame = try #require(laid.slots.first { $0.id == id }).frame
                    #expect(group.frame.contains(frame), "at \(width): \(group.label) does not cover \(id)")
                }
            }
            for (index, a) in mothers.enumerated() {
                for b in mothers[(index + 1)...] {
                    let common = a.frame.intersection(b.frame)
                    #expect(common.isNull || common.width < 0.01 || common.height < 0.01, "at \(width): \(a.label) overlaps \(b.label)")
                }
            }
        }

        // Terah sits over both of Isaac's parents (ruling 6) and is read once.
        let isaacID = try #require(try family(682, "GEN").father?.id)
        let isaac = try family(isaacID, "GEN")
        let shared = FamilyTreeGeometry.make(isaac, width: 472, open: [], rowPitch: FamilyTreeView.rowPitch, measure: SystemFamilyTreeMeasure())
        let grandparents = try #require(FamilyTreeSpeech.groups(isaac, geometry: shared).first { $0.label.hasPrefix("Grandparents: ") })
        let names = walks(grandparents)
        #expect(Set(names).count == names.count && grandparents.slots.count > names.count)
    }
    #endif
}

#if os(macOS)
/// The tree hosted: its names laid by `FamilyTreeNamesLayout` at the geometry's frames, its height the geometry's.
@MainActor @Suite(.serialized) struct FamilyTreeViewTests {
    private func host(_ tree: FamilyTree, width: CGFloat, open: Set<FamilyChip> = []) -> NSHostingView<some View> {
        let host = NSHostingView(rootView: FamilyTreeView(tree: tree, open: .constant(open)) { _ in }.frame(width: width))
        host.frame = NSRect(x: 0, y: 0, width: width, height: 2_000)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // The width is read once laid out; the tree is laid again at it.
        RunLoop.main.run(until: .now + 0.05)
        host.layoutSubtreeIfNeeded()
        return host
    }

    /// Return on a name walks and hands the keyboard to the tree of the page walked to (the final review's
    /// Important 3): only that person's tree takes it, once; any other tree that appears first drops it.
    @Test func aWalkByTheKeysHandsTheFocusToThePageWalkedTo() {
        FamilyTreeWalkFocus.walked(to: 994)
        #expect(FamilyTreeWalkFocus.take(994))
        #expect(!FamilyTreeWalkFocus.take(994))
        FamilyTreeWalkFocus.walked(to: 994)
        #expect(!FamilyTreeWalkFocus.take(903))
        #expect(!FamilyTreeWalkFocus.take(994))
    }

    /// The page decides from its own width, less its margins and a legacy scroller's width whether or not the scroller
    /// shows (so neither the scroller nor the switch's change of height moves it), and the memo answers as the rule does,
    /// working each width once.
    @Test(.needsRealBible) func thePageDecidesFromItsOwnWidth() throws {
        #expect(PersonPageView.treeWidth(page: 1_100, scroller: 0) == 1_052 && PersonPageView.treeWidth(page: 1_100, scroller: 15) == 1_037)
        #expect(PersonPageView.treeWidth(page: 30, scroller: 15) == 0)
        let reader = LibraryType(readerSize: 18), memo = FamilyTreeFitMemo()
        for (id, book) in [(994, "2SA"), (1830, "GEN")] {
            let tree = try #require(try PersonPage.load(id, inBook: book, store: BenchmarkChapter.realStore())).family
            for width: CGFloat in [300, 500, 656.5, 657, 700, 1_052] {
                let fits = FamilyTreeLayoutRule.fitsAsTree(tree, width: width, type: reader)
                #expect(memo.fitsAsTree(tree, width: width, type: reader) == fits && memo.fitsAsTree(tree, width: width, type: reader) == fits)
            }
        }
    }

    /// The tree is laid at the page's expected width unless its own reading is narrower by half a point or more: a reading
    /// on whole points just under a fractional page width (774 against 774.08) does not lay the tree again, and is not
    /// kept, so it does not draw the tree again either. With no expected width the reading, else the first width.
    @Test func theTreeIsLaidOnceAtThePagesWidth() {
        #expect(FamilyTreeView.laidWidth(expected: 774.077, read: 774, first: 640) == 774.077)
        #expect(FamilyTreeView.laidWidth(expected: 774.077, read: 790, first: 640) == 774.077)
        #expect(FamilyTreeView.laidWidth(expected: 774.077, read: nil, first: 640) == 774.077)
        #expect(FamilyTreeView.laidWidth(expected: 774.077, read: 759, first: 640) == 759)
        #expect(FamilyTreeView.laidWidth(expected: nil, read: 759, first: 640) == 759 && FamilyTreeView.laidWidth(expected: nil, read: nil, first: 640) == 640)
        #expect(FamilyTreeView.reading(774, expected: 774.077) == nil && FamilyTreeView.reading(759, expected: 774.077) == 759)
    }

    /// The phone's family line on the Mac (where the tree does not fit) lays at the Library's type: taller at the reader's
    /// 18 pt than with the system's styles, one row a person or run.
    @Test(.needsRealBible) func theFamilyLineLaysOnTheMacAtTheReadersType() throws {
        let tree = try #require(try PersonPage.load(994, inBook: "2SA", store: BenchmarkChapter.realStore())).family
        let width: CGFloat = 400
        func height(_ type: LibraryType) -> CGFloat {
            let host = NSHostingView(rootView: FamilyLineView(tree: tree, open: .constant([])) { _ in }.environment(\.libraryType, type).frame(width: width))
            host.frame = NSRect(x: 0, y: 0, width: width, height: 2_000)
            host.layoutSubtreeIfNeeded()
            return host.fittingSize.height
        }
        let rows = FamilyLine.rows(tree, open: [])
        let (reader, system) = (height(LibraryType(readerSize: 18)), height(.system))
        #expect(reader > system && reader > CGFloat(rows.count) * 18, "\(reader) for \(system), \(rows.count) rows")
    }

    @Test(.needsRealBible) func theHostedTreeIsAsTallAsItsGeometry() throws {
        let tree = try #require(try PersonPage.load(994, inBook: "2SA", store: BenchmarkChapter.realStore())).family
        for (width, open) in [(CGFloat(472), Set<FamilyChip>()), (332, []), (472, [.siblings, .households, .notNamed])] {
            // The view's gap at the system's styles (1.5 em, 20 pt).
            let geometry = FamilyTreeGeometry.make(tree, width: width, open: open, rowPitch: FamilyTreeView.rowPitch, gap: FamilyTreeFolding.gap(.system),
                                                   measure: SystemFamilyTreeMeasure())
            let height = host(tree, width: width, open: open).fittingSize.height
            #expect(abs(height - geometry.size.height) < 0.5, "at \(width), \(open): \(height) for \(geometry.size.height)")
        }
    }
}
#endif
