import CoreGraphics
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct FactListTests {
    @Test func theFactsStackWhenTheLabelsTakeTooMuch() {
        #expect(!FactList.stacks(labelWidth: 100, gap: 8, width: 520))
        #expect(FactList.stacks(labelWidth: 170, gap: 8, width: 402))
        #expect(!FactList.stacks(labelWidth: 170, gap: 8, width: 0))
        #expect(FactList.widestLabelShare == 0.4)
    }

    private static let genesisNames = ["God", "Jacob", "Abraham", "Joseph", "Isaac"].enumerated().map {
        LibraryNameRun.Name(entity: .person($0.offset + 1), name: $0.element)
    }

    @Test func aRunOfNamesReadsAsOneLine() {
        let five = LibraryNameRun.text(Self.genesisNames, more: 347, tail: nil)
        #expect(String(five.characters) == "God, Jacob, Abraham, Joseph, Isaac and 347 more")
        let two = Array(Self.genesisNames.prefix(2))
        #expect(String(LibraryNameRun.text(two, more: 0, tail: "(by tradition)").characters) == "God and Jacob (by tradition)")
        #expect(String(LibraryNameRun.text([Self.genesisNames[0]], more: 0, tail: "(by tradition)").characters) == "God (by tradition)")
        #expect(LibraryNameRun.spoken(Self.genesisNames, more: 347, tail: nil) == "God, Jacob, Abraham, Joseph, Isaac and 347 more")
        #expect(String(LibraryNameRun.text(Self.genesisNames, more: 0, tail: nil).characters) == "God, Jacob, Abraham, Joseph and Isaac")
    }

    @Test func eachNameAndTheCountCarryALinkAndTheWordsDoNot() throws {
        let text = LibraryNameRun.text(Self.genesisNames, more: 347, tail: "(by tradition)")
        let linked = text.runs.filter { $0.link != nil }.map { String(text[$0.range].characters) }
        #expect(linked == ["God", "Jacob", "Abraham", "Joseph", "Isaac", "347 more"])
        let unlinked = text.runs.filter { $0.link == nil }.map { String(text[$0.range].characters) }.joined()
        #expect(unlinked.contains("and ") && unlinked.contains("(by tradition)"))
    }

    private func about(writers: [PersonSummary] = [], people: Int = 0, places: Int = 0, dated: Bool = true) -> BookAbout {
        let person = PersonSummary(id: 1, name: "God", label: nil, verseCount: 1)
        let place = PlaceSummary(id: 1, name: "Eden", label: nil, kind: nil, latitude: nil, longitude: nil, point: nil,
                                 isApproximate: false, verseCount: 1)
        let records = dated ? [EventRecord(id: 1, title: "Creation", year: -4004, sortKey: 1, durationDays: nil, partOf: nil, personID: nil)] : []
        let passages = dated ? [1: Reference(book: BookCatalog.book(code: "GEN")!, chapter: 1, verse: 1)] : [:]
        return BookAbout(book: BookCatalog.book(code: "GEN")!, subtitle: nil, testamentLine: "Old Testament, the Law",
                         lengthLine: "50 chapters, 1,533 verses", writers: writers,
                         topPeople: Array(repeating: person, count: people), peopleCount: people,
                         topPlaces: Array(repeating: place, count: places), placeCount: places,
                         timeline: BookTimeline.make(records: records, passages: passages))
    }

    @Test func theFactsComeInOrderAndARowWithNoValueGoes() {
        let moses = PersonSummary(id: 2, name: "Moses", label: nil, verseCount: 1)
        let full = about(writers: [moses], people: 1, places: 1)
        #expect(LibraryAboutView.factLabels(full, showingDates: true) == ["Testament", "Length", "Attributed to", "Spans", "People", "Places"])
        #expect(LibraryAboutView.factLabels(full, showingDates: false) == ["Testament", "Length", "Attributed to", "People", "Places"])
        #expect(LibraryAboutView.factLabels(about(people: 1, places: 1), showingDates: false) == ["Testament", "Length", "People", "Places"])
        #expect(LibraryAboutView.factLabels(about(places: 1), showingDates: false) == ["Testament", "Length", "Places"])
    }

    @Test func theLabelColumnFollowsTheRowsNowShown() {
        let measured: [String: CGFloat] = ["Attributed to": 150, "Testament": 90, "Length": 60]
        #expect(FactList.widest(of: measured, in: ["Testament", "Length", "Attributed to"]) == 150)
        #expect(FactList.widest(of: measured, in: ["Testament", "Length"]) == 90)
        #expect(FactList.widest(of: measured, in: []) == 0)
        #expect(FactList.widths(measured, keeping: ["Testament", "Length"]) == ["Testament": 90, "Length": 60])
    }
}
