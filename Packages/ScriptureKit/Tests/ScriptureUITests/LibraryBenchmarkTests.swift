#if os(macOS)
import AppKit
import Foundation
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

@MainActor @Suite(.serialized) struct LibraryBenchmarkTests {
    /// John names 39 people and 30 places and has 36 events; "peter" finds one person.
    @Test(.needsRealBible) func johnsLibraryAndANameSearchReadTheRealData() throws {
        let store = try BenchmarkChapter.realStore()
        #expect(try store.people(inBook: "JHN").count == 39 && store.placesNamed(inBook: "JHN").count == 30 && store.events(inBook: "JHN").count == 36)
        #expect(try store.searchPeople("peter", limit: 4).rows.map(\.name) == ["Simon Peter"])
    }

    /// Siblings and half-siblings, which the fixture has none of (review M9): David for the whole
    /// Bible has 1 parent, 9 households (8 partners and the eleven), 7 siblings, 2 half-siblings and 21 children.
    @Test(.needsRealBible) func davidsFamilyHasItsSiblings() throws {
        let page = try #require(try PersonPage.load(994, inBook: nil, store: BenchmarkChapter.realStore()))
        #expect(page.person.name == "David")
        let family = page.family
        #expect(family.parents.count == 1 && family.households.count == 9 && family.siblings.count == 7)
        #expect(family.halfSiblings.count == 2 && family.children.count == 21)
    }

    /// The whole-Bible page of God (8,587 verses) loads with a median under 50 ms, debug build.
    @Test(.needsRealBible) func theWholeBiblePageOfGodLoadsWithinFiftyMilliseconds() throws {
        let store = try BenchmarkChapter.realStore()
        var page: PersonPage?
        let median = ReaderBenchmarkTests.median("library-person-1324-whole-bible") {
            page = try? PersonPage.load(1324, inBook: nil, store: store)
        }
        #expect(page?.person.verseCount == 8587 && median < .milliseconds(50))
    }

    /// David in 2 Samuel (the largest family) loads with a median under 50 ms, debug build.
    @Test(.needsRealBible) func davidsPageLoads() throws {
        let store = try BenchmarkChapter.realStore()
        var page: PersonPage?
        let median = ReaderBenchmarkTests.median("library-person-994-2sa-load") {
            page = try? PersonPage.load(994, inBook: "2SA", store: store)
        }
        #expect(page != nil && median < .milliseconds(50))
    }

    /// Joshua's Places load (`BookPlaces.load`: 431 on the map), the median of nine, debug build. The read and the
    /// model, before and after project 4 (benchmarks.md). Measured alone, three runs: 13.4, 13.4, 13.3 ms (load
    /// average about 3.5); bound 1.5 x 13.4 rounded up to 10 ms.
    @Test(.needsRealBible) func joshuasPlacesLoad() throws {
        let store = try BenchmarkChapter.realStore()
        var places: BookPlaces?
        let median = ReaderBenchmarkTests.median("library-places-jos-load") {
            places = try? BookPlaces.load(book: "JOS", store: store)
        }
        #expect(places?.onMap.count == 431 && median < .milliseconds(30))
    }

    /// The Places list column for Joshua, By chapter with chapter 15 chosen, hosted alone (no `Map`): the time to lay
    /// out. The bound is Task 9's to set.
    @Test(.needsRealBible) func joshuaByChapterListOpens() throws {
        let store = try BenchmarkChapter.realStore()
        let places = try #require(try BookPlaces.load(book: "JOS", store: store))
        let name = "LibraryBenchmarkTests-\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: name))
        suite.set(PlacesOrder.byChapter.rawValue, forKey: PlacesOrder.key)
        var place = LibraryPlace(book: "JOS", topic: .places)
        place.placesChapter = 15
        var selection = PlacesSelection()
        let list = LibraryPlacesList(
            places: places, place: Binding(get: { place }, set: { place = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }))
            .defaultAppStorage(suite)
            .frame(width: 232, height: 760)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 232, height: 760), styleMask: [.titled], backing: .buffered, defer: true)
        let median = ReaderBenchmarkTests.median("library-places-jos-by-chapter-list") {
            let host = NSHostingView(rootView: list)
            host.frame = NSRect(x: 0, y: 0, width: 232, height: 760)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            RunLoop.main.run(until: .now)
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        // What was measured is By chapter: the order the hosted list reads through its `AppStorage` from the suite.
        let measured = AppStorage(wrappedValue: PlacesOrder.mostNamed, PlacesOrder.key, store: suite).wrappedValue
        suite.removePersistentDomain(forName: name)
        #expect(measured == .byChapter && place.placesChapter == 15)
        #expect(median < .milliseconds(50))
    }

    /// What the map is given for Joshua 15 (the chapter's pins, the dots, the draw order, the framing) and the
    /// By chapter list's items: pure, the median of nine, debug build. The map itself is never measured. Measured alone,
    /// three runs: 0.4, 0.4, 0.4 ms; bound 10 ms (the rounding's floor).
    @Test(.needsRealBible) func joshuasChapterFifteenMapContent() throws {
        let store = try BenchmarkChapter.realStore()
        let places = try #require(try BookPlaces.load(book: "JOS", store: store))
        var pins: [BookPlaces.Pin] = []
        var dots: [BookPlaces.Pin] = []
        var drawn: [BookPlaces.Pin] = []
        var framing: PlacesFraming?
        var items: [PlacesList.Item] = []
        let median = ReaderBenchmarkTests.median("library-places-jos-15-map-content") {
            pins = places.pins(inChapter: 15)
            dots = places.dots(inChapter: 15)
            drawn = PlacesMapView.drawOrder(pins, chosen: pins.first?.id)
            framing = places.framing(chapter: 15)
            items = PlacesList.items(places, order: .byChapter)
        }
        #expect(!pins.isEmpty && !drawn.isEmpty && framing != nil && !items.isEmpty && !dots.isEmpty)
        #expect(median < .milliseconds(10))
    }

    // MARK: - The Mac's large lists, hosted offscreen (review I2); Places is not hosted: no `Map`

    private static let size = NSRect(x: 0, y: 0, width: 1100, height: 760)

    private static func navigation() throws -> NavigationModel {
        let defaults = UserDefaults(suiteName: "LibraryBenchmarkTests-\(UUID().uuidString)")!
        let model = try NavigationModel(store: BenchmarkChapter.realStore(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "ESV")
        model.open(ChapterLocation(book: "1CH", chapter: 1))
        model.goHome()
        return model
    }

    /// A Library view hosted in a window that is never shown, on `navigation.libraryPlace`. `settled` spins the
    /// run loop once and lays out again, so what the first pass changes (the family tree reads its column's
    /// width as it is laid, ruling 20) is laid and drawn inside the time.
    private static func host(_ navigation: NavigationModel, in window: NSWindow, settled: Bool = false) -> NSHostingView<some View> {
        let view = LibraryView(
            navigation: navigation,
            place: Binding(get: { navigation.libraryPlace ?? LibraryPlace(book: nil, topic: .people) },
                           set: { navigation.libraryPlace = $0 }),
            onOpenSettings: {})
            // As the Mac's front page sets it (Matt's review, 2026-11-24): the reader's default 18 pt.
            .environment(\.libraryType, LibraryType(readerSize: CGFloat(ReaderSettings.defaultFontSize)))
            .frame(width: size.width, height: size.height)
        let host = NSHostingView(rootView: view)
        host.frame = size
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        if settled {
            RunLoop.main.run(until: .now)
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        return host
    }

    private static func window() -> NSWindow {
        NSWindow(contentRect: size, styleMask: [.titled], backing: .buffered, defer: true)
    }

    private static func person(_ id: Int) -> LibraryPlace {
        LibraryPlace(book: "1CH", topic: .people, trail: [.person(id)])
    }

    /// People in 1 Chronicles (1,327 people) with its first person chosen: the time to lay out.
    @Test(.needsRealBible) func peopleInFirstChroniclesOpensWithItsFirstPersonChosen() throws {
        let navigation = try Self.navigation()
        let rows = try #require(navigation.bookPeople("1CH")).rows
        #expect(rows.count == 1327)
        navigation.libraryPlace = Self.person(rows[0].id)
        let window = Self.window()
        let median = ReaderBenchmarkTests.median("library-people-1ch-open") {
            _ = Self.host(navigation, in: window)
        }
        // Milestone 10's 150 ms, raised to 160 for this test only (Task 7's ruling): spec 7's system segmented
        // Picker costs ~9 ms per hosted view and the order's @AppStorage ~2 ms (136-139 ms before, 145-156 after).
        #expect(median < .milliseconds(160))
    }

    /// The same view, then the next person chosen: the time to lay out again.
    @Test(.needsRealBible) func choosingTheNextPersonInFirstChroniclesLaysOutAgain() throws {
        let navigation = try Self.navigation()
        let rows = try #require(navigation.bookPeople("1CH")).rows
        navigation.libraryPlace = Self.person(rows[0].id)
        let window = Self.window()
        let host = Self.host(navigation, in: window)
        let median = ReaderBenchmarkTests.median("library-people-1ch-next", prepare: {
            navigation.libraryPlace = Self.person(rows[0].id)
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }) {
            navigation.libraryPlace = Self.person(rows[1].id)
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        // 100 ms is the target. This measured 92 to 95 ms, so it would flake under load;
        // the controller set the bound at 150 ms.
        #expect(median < .milliseconds(150))
    }

    /// About Genesis's data load (`BookAbout.load`), the median of nine: 6.7 ms before project 2, 6.6 ms after
    /// (alone, debug). The bound is 1.5 times the before figure, rounded to 10 ms (departure 17), so a loaded
    /// suite does not flake; spec 11's 10% is measured alone, not asserted.
    @Test(.needsRealBible) func aboutGenesisLoads() throws {
        let store = try BenchmarkChapter.realStore()
        var about: BookAbout?
        let median = ReaderBenchmarkTests.median("library-about-gen-load") {
            about = try? BookAbout.load(book: "GEN", translationID: "ESV", store: store)
        }
        #expect(about != nil && median < .milliseconds(10))
    }

    /// About Genesis (113 events): the time to lay out, the load included. 134.7 ms before project 2, 46.8 ms
    /// after (the rail's rows lazy). 300 ms holds it near the 137 to 197 ms measured when the lists were made lazy.
    @Test(.needsRealBible) func aboutGenesisOpens() throws {
        let navigation = try Self.navigation()
        navigation.libraryPlace = LibraryPlace(book: "GEN", topic: .about)
        #expect(navigation.bookAbout("GEN")?.timeline.lifeCount == 24)
        let window = Self.window()
        let median = ReaderBenchmarkTests.median("library-about-gen-open") {
            _ = Self.host(navigation, in: window)
        }
        #expect(median < .milliseconds(300))
    }

    /// David's page in 2 Samuel (the largest family), hosted: the time to lay out, the load included, the tree
    /// settled at its column's width. 122.6 ms before project 3; the bound is milestone 10's People budget (Departure 26).
    @Test(.needsRealBible) func davidsPageInSecondSamuelOpens() throws {
        let navigation = try Self.navigation()
        navigation.libraryPlace = LibraryPlace(book: "2SA", topic: .people, trail: [.person(994)])
        let window = Self.window()
        let median = ReaderBenchmarkTests.median("library-person-994-2sa-open") {
            _ = Self.host(navigation, in: window, settled: true)
        }
        #expect(median < .milliseconds(150))
    }

    /// God's whole-Bible page (the most verses) with Psalms open, hosted: the time to lay out, settled. 143.3 ms
    /// before project 3; the bound is milestone 10's People budget (Departure 26).
    @Test(.needsRealBible) func godsWholeBiblePageOpensWithPsalmsOpen() throws {
        let navigation = try Self.navigation()
        var place = LibraryPlace(book: nil, topic: .people, trail: [.person(1324)])
        place.toggledBooks = ["PSA"]
        navigation.libraryPlace = place
        let window = Self.window()
        let median = ReaderBenchmarkTests.median("library-person-1324-whole-psalms-open") {
            _ = Self.host(navigation, in: window, settled: true)
        }
        #expect(median < .milliseconds(150))
    }
}
#endif
