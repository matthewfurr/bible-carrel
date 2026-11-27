import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The book's places in each order on the real data (spec 13's "The data, checked").
@Suite struct PlacesRealDataTests {
    private func places(_ book: String) throws -> BookPlaces {
        try #require(try BookPlaces.load(book: book, store: BenchmarkChapter.realStore()))
    }

    private func rows(_ places: BookPlaces) -> Int { places.chapters.reduce(0) { $0 + $1.places.count } }

    /// How many places are named in more than one chapter.
    private func inSeveralChapters(_ places: BookPlaces) -> Int {
        var seen: [Int: Int] = [:]
        for chapter in places.chapters { for place in chapter.places { seen[place.id, default: 0] += 1 } }
        return seen.values.filter { $0 > 1 }.count
    }

    @Test(.needsRealBible) func actsInEachOrder() throws {
        let acts = try places("ACT")
        #expect(acts.onMap.prefix(2).map(\.name) == ["Jerusalem", "Caesarea"])
        #expect(acts.onMapByName.prefix(4).map(\.name) == ["Achaia", "Adramyttium", "Adria", "Akeldama"])
        let names = acts.onMapByName.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(acts.onMapByName.filter { $0.name == "Antioch" }.map(\.id) == [69, 68])
        #expect(acts.chapters.count == 28 && rows(acts) == 229)
        #expect(acts.chapter(1)?.places.map(\.name) == ["Jerusalem", "Judea", "Samaria", "Galilee", "Mount of Olives", "Akeldama"])
        let second = try #require(acts.chapter(2))
        #expect(second.places.count == 13 && second.places.prefix(3).map(\.name) == ["Jerusalem", "Asia", "Cappadocia"])
        #expect(inSeveralChapters(acts) == 43)
        let jerusalem = try #require(acts.onMap.first { $0.name == "Jerusalem" })
        #expect(acts.chapters.filter { $0.mentions[jerusalem.id] != nil }.count == 22)
    }

    @Test(.needsRealBible) func genesisAndJoshuaByChapter() throws {
        let genesis = try places("GEN")
        #expect(genesis.chapters.count == 44 && rows(genesis) == 233)
        let unlocated = [9, 112, 354, 472, 485, 533, 902, 951]
        #expect(genesis.notOnMap.map(\.id).sorted() == unlocated)
        let unlocatedRows = genesis.chapters.reduce(0) { $0 + $1.places.filter { unlocated.contains($0.id) }.count }
        #expect(unlocatedRows == 9)
        #expect(genesis.chapter(3)?.places.map(\.id) == [354] && genesis.chapter(3)?.onMapCount == 0)
        #expect(genesis.chapter(10)?.places.count == 20 && genesis.chapter(14)?.places.count == 27)
        #expect(genesis.onMapByName.filter { $0.name == "Valley of Shaveh" }.map(\.id) == [692, 1216])

        let joshua = try places("JOS")
        #expect(joshua.onMap.count + joshua.notOnMap.count == 434)
        #expect(joshua.chapters.count == 24 && rows(joshua) == 686)
        #expect(joshua.chapter(15)?.places.count == 165)
        #expect(inSeveralChapters(joshua) == 130)
        let shared = joshua.pins.filter { $0.places.count > 1 }
        #expect(shared.count == 76 && shared.reduce(0) { $0 + $1.places.count } == 202)
    }

    @Test(.needsRealBible) func solomonsPorticoNamesJerusalemsPin() throws {
        let acts = try places("ACT")
        let pin = try #require(acts.pin(holding: 1109))
        #expect(pin.places.count == 5)
        #expect(pin.title(choosing: nil) == "Jerusalem")
        #expect(pin.title(choosing: 1109) == "Solomon's Portico")
        #expect(pin.title(choosing: 636) == "Jerusalem")
    }

    @Test(.needsRealBible) func actsFirstChapterPinsAndDots() throws {
        let acts = try places("ACT")
        let pins = acts.pins(inChapter: 1)
        #expect(pins.count == 4)
        let jerusalem = try #require(pins.first { $0.places.contains { $0.id == 636 } })
        #expect(jerusalem.places.map(\.id) == [636, 657, 43] && jerusalem.mentions == 6)
        #expect(acts.dots(inChapter: 1).count == 91)
        let frame = try #require(acts.frame(inChapter: 1))
        #expect(abs(frame.latitude - 32.2420) < 0.001 && abs(frame.longitude - 35.2458) < 0.001)
        #expect(abs(frame.latitudeSpan - 1.3014) < 0.001 && frame.longitudeSpan == 0.5)
        let second = acts.pins(inChapter: 2)
        #expect(second.first { $0.places.contains { $0.id == 636 } }?.places.map(\.id) == [636, 657])
    }

    @Test(.needsRealBible) func genesisThreeIsAllDots() throws {
        let genesis = try places("GEN")
        #expect(genesis.pins(inChapter: 3).isEmpty)
        #expect(genesis.dots(inChapter: 3).count == 78)
        #expect(genesis.frame(inChapter: 3) == genesis.frame)
    }

    /// 13.4: By chapter has a heading for every chapter that names a place, and a row for each place under it.
    @Test(.needsRealBible) func everyChapterThatNamesAPlaceHasAHeading() throws {
        let acts = try places("ACT")
        let actsItems = PlacesList.items(acts, order: .byChapter)
        #expect(actsItems.filter { if case .heading = $0 { true } else { false } }.count == 28)
        let actsRows = PlacesList.rows(actsItems)
        #expect(actsRows.count == 229)
        #expect(actsRows.filter { $0.chapter == 1 }.map(\.id) == ["1-636", "1-657", "1-1022", "1-433", "1-861", "1-43"])
        let genesis = try places("GEN")
        let genesisItems = PlacesList.items(genesis, order: .byChapter)
        #expect(genesisItems.filter { if case .heading = $0 { true } else { false } }.count == 44)
        let genesisIDs = PlacesList.rows(genesisItems).map(\.id)
        #expect(genesisIDs.contains("2-354") && genesisIDs.contains("3-354") && !genesisItems.contains(.notOnMap))
        #expect(PlacesChapters.headerLine(try #require(genesis.chapter(3))) == "Chapter 3 · 1 place, none on the map")
        #expect(PlacesChapters.headerLine(try #require(acts.chapter(1))) == "Chapter 1 · 6 places")
    }
}
