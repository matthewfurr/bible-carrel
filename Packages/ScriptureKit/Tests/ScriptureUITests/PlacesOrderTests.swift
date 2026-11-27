import Foundation
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// Places' three orders and the book's places by chapter (spec 5.2 to 5.4), on the fixture's Matthew.
@Suite struct PlacesOrderTests {
    private var matthew: BookPlaces {
        get throws { try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make())) }
    }

    @MainActor @Test func thePlacesOrderIsKeptOnThisDeviceOnly() {
        #expect(PlacesOrder.key == "libraryPlacesOrder" && PlacesOrder.key != PeopleOrder.key)
        #expect(!SyncedPreferences.keys.contains(PlacesOrder.key))
        #expect(PlacesOrder(rawValue: "byChapter") == .byChapter)
        #expect(PlacesOrder.allCases.map(\.title) == ["Most named", "A to Z", "By chapter"])
    }

    /// Spec 13.7, through the view's own path: `@AppStorage` on a suite, read by a second `UserDefaults` of the
    /// same name (a fresh model); an empty suite gives the default, Most named.
    @Test func theStoredOrderIsReadBackAfterARelaunch() throws {
        let name = "PlacesOrderTests-\(UUID().uuidString)"
        let first = try #require(UserDefaults(suiteName: name))
        first.set(PlacesOrder.byChapter.rawValue, forKey: PlacesOrder.key)
        let second = try #require(UserDefaults(suiteName: name))
        let relaunched = AppStorage(wrappedValue: PlacesOrder.mostNamed, PlacesOrder.key, store: second).wrappedValue
        #expect(relaunched == .byChapter)
        let emptyName = "PlacesOrderTests-\(UUID().uuidString)"
        let empty = try #require(UserDefaults(suiteName: emptyName))
        #expect(empty.object(forKey: PlacesOrder.key) == nil)
        #expect(AppStorage(wrappedValue: PlacesOrder.mostNamed, PlacesOrder.key, store: empty).wrappedValue == .mostNamed)
        first.removePersistentDomain(forName: name)
        empty.removePersistentDomain(forName: emptyName)
    }

    /// The phone's count line is the chapter's header line while a chapter is chosen, else the book's count.
    @Test func thePhonesListShowsTheChapterLine() throws {
        let places = try matthew
        #expect(PlacesChapters.countLine(places, chapter: 12) == "Chapter 12 · 1 place, none on the map")
        #expect(PlacesChapters.countLine(places, chapter: nil) == "8 places · 6 on the map")
    }

    @Test func aToZSortsByNameThenLabelThenIDWithTheUnlocatedAtTheFoot() throws {
        let places = try matthew
        #expect(places.onMapByName.map(\.name) == ["Bethlehem", "Egypt", "Jerusalem", "Nazareth", "Ramah", "Zion"])
        #expect(places.notOnMapByName.map(\.name) == ["Holy place", "South"])
        #expect(places.onMap.map(\.id) == [218, 362, 636, 882, 978, 1263])
    }

    @Test func theChaptersListTheirPlacesInTheOrderFirstNamed() throws {
        let places = try matthew
        #expect(places.chapters.map(\.number) == [2, 4, 5, 12, 21, 24])
        #expect(places.chapter(2)?.places.map(\.name) == ["Bethlehem", "Jerusalem", "Egypt", "Ramah", "Nazareth"])
        #expect(places.chapter(4)?.places.map(\.name) == ["Nazareth", "Jerusalem"])
        #expect(places.chapter(12)?.onMapCount == 0)
        #expect(places.chapter(2)?.mentions[218] == 5)
        #expect(places.chapters.reduce(0) { $0 + $1.places.count } == 11)
        #expect(places.chapter(3) == nil)
    }

    /// A chosen chapter's heading is selected for VoiceOver whether or not a row is chosen; it takes the wash only
    /// while no row is (only the row clicked takes the wash).
    @Test func aChosenHeadingIsSelectedButWashedOnlyWithNoRowChosen() {
        #expect(PlacesList.headingIsChosen(2, chapter: 2))
        #expect(!PlacesList.headingIsChosen(3, chapter: 2) && !PlacesList.headingIsChosen(2, chapter: nil))
        #expect(PlacesList.headingShowsWash(2, chapter: 2, chosenRow: nil))
        #expect(!PlacesList.headingShowsWash(2, chapter: 2, chosenRow: "2-636"))
        #expect(!PlacesList.headingShowsWash(3, chapter: 2, chosenRow: nil))
    }

    @Test func theControlIsAMenuWhereThreeSegmentsDoNotFit() {
        #expect(PlacesOrderControl.isSegmented(width: PlacesOrderControl.segmentedWidth, dynamicTypeSize: .large))
        #expect(!PlacesOrderControl.isSegmented(width: PlacesOrderControl.segmentedWidth - 1, dynamicTypeSize: .large))
        #if os(macOS)
        // Places' column is a scaled 232 pt, so the control's inside is 216 (pre-flight ruling 1).
        #expect(PlacesOrderControl.isSegmented(width: 216, dynamicTypeSize: .large))
        #expect(PlacesOrderControl.isSegmented(width: 216, dynamicTypeSize: .xxxLarge))
        #expect(!PlacesOrderControl.isSegmented(width: 184, dynamicTypeSize: .large))
        #else
        #expect(PlacesOrderControl.isSegmented(width: 354, dynamicTypeSize: .large))
        #expect(PlacesOrderControl.isSegmented(width: 354, dynamicTypeSize: .xxxLarge))
        #expect(!PlacesOrderControl.isSegmented(width: 354, dynamicTypeSize: .accessibility1))
        #endif
    }

    /// The order switch's effect on the chosen chapter, as the list wires it (pre-flight ruling 13).
    @Test func switchingToAnotherOrderClearsTheChapterAndByChapterKeepsIt() {
        #expect(PlacesChapters.afterOrderChange(to: .mostNamed, chosen: 4) == nil)
        #expect(PlacesChapters.afterOrderChange(to: .alphabetical, chosen: 4) == nil)
        #expect(PlacesChapters.afterOrderChange(to: .byChapter, chosen: 4) == 4)
        #expect(PlacesChapters.afterOrderChange(to: .byChapter, chosen: nil) == nil)
    }
}

#if os(macOS)
import AppKit

/// The control's measured width, hosted: its own minimum, not `fittingSize` (pre-flight ruling 1, 3).
@MainActor @Suite(.serialized) struct PlacesOrderControlHostTests {
    @Test func theMeasuredWidthIsTheControlsOwn() {
        let view = LibraryOrderPicker(selection: .constant(PlacesOrder.mostNamed), orders: PlacesOrder.allCases, title: \.title)
        let width = NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: 1, height: 100)).width
        #expect(abs(width - PlacesOrderControl.segmentedWidth) <= 1)
    }
}
#endif
