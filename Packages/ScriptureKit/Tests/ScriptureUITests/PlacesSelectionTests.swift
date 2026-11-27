import MapKit
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct PlacesSelectionTests {
    @Test func theMapAndTheListChooseEachOther() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        var selection = PlacesSelection()
        selection.choose(place: 218, in: places)                               // Bethlehem, in the list
        #expect(selection.pinID == places.pin(holding: 218)?.id && selection.gathered(in: places) == nil)
        selection.choose(pin: "31.777,35.235", in: places)                     // the gathered pin, on the map
        #expect(selection.placeID == nil && selection.gathered(in: places)?.map(\.name) == ["Jerusalem", "Zion"])
        selection.choose(place: 1263, in: places)                              // Zion, from the pin's places
        #expect(selection.pinID == "31.777,35.235" && selection.placeID == 1263 && selection.gathered(in: places) == nil)
        selection.choose(place: 574, in: places)                               // not on the map
        #expect(selection.placeID == 574 && selection.pinID == nil)
        selection.choose(pin: places.pin(holding: 882)?.id, in: places)        // a pin of one place
        #expect(selection.placeID == 882)
        selection.choose(pin: nil, in: places)                                 // a click on the map itself
        #expect(selection.placeID == nil && selection.pinID == nil)
    }

    /// The selection follows the place showing: one walked or returned to is chosen with its pin;
    /// nothing showing keeps a gathered pin but forgets a place.
    @Test func theSelectionFollowsThePlaceShowing() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        let showingBethlehem = PlacesSelection().following(.place(218), in: places)
        #expect(showingBethlehem.placeID == 218 && showingBethlehem.pinID == places.pin(holding: 218)?.id)
        #expect(showingBethlehem.following(nil, in: places) == PlacesSelection())
        var gathered = PlacesSelection()
        gathered.choose(pin: "31.777,35.235", in: places)
        #expect(gathered.following(nil, in: places) == gathered)
        #expect(gathered.following(.place(1263), in: places).placeID == 1263)
    }

    /// 13.1: a shared pin takes the chosen place's name; with none chosen (or a place not in it) it keeps its own.
    @Test func aChosenPlaceNamesItsSharedPin() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        let pin = try #require(places.pins.first { $0.id == "31.777,35.235" })
        #expect(pin.title(choosing: nil) == "Jerusalem")
        #expect(pin.title(choosing: 1263) == "Zion")
        #expect(pin.title(choosing: 636) == "Jerusalem")
        #expect(pin.title(choosing: 218) == "Jerusalem")
        #expect(pin.places.count == 2)
    }

    @Test func aChaptersPinsCountTheChapterOnly() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        let second = places.pins(inChapter: 2)
        #expect(second.count == 5)
        #expect(second.first { $0.id == "31.777,35.235" }?.places.map(\.id) == [636])
        #expect(second.first { $0.title == "Bethlehem" }?.mentions == 5)
        let twentyFirst = places.pins(inChapter: 21)
        #expect(twentyFirst.map(\.id) == ["31.777,35.235"] && twentyFirst.first?.places.map(\.id) == [1263])
        #expect(twentyFirst.first?.title == "Zion")
        #expect(places.pins(inChapter: 12).isEmpty)
        #expect(places.pins(inChapter: nil) == places.pins)
    }

    @Test func theRestOfTheBookAreDots() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        #expect(places.dots(inChapter: 2).isEmpty)
        #expect(places.dots(inChapter: 4).map(\.title).sorted() == ["Bethlehem", "Egypt", "Ramah"])
        #expect(places.dots(inChapter: 12).count == 5)
        #expect(places.dots(inChapter: nil).isEmpty)
    }

    @Test func aChapterWithNoPinFramesTheBook() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        #expect(places.frame(inChapter: 12) == places.frame)
        let four = try #require(places.frame(inChapter: 4))
        #expect(abs(four.latitude - 32.241967) < 0.001 && abs(four.longitude - 35.268253) < 0.001)
        #expect(abs(four.latitudeSpan - 1.301378) < 0.001 && four.longitudeSpan == 0.5)
        #expect(places.framing(chapter: 4).chapter == 4 && places.framing(chapter: 4).frame == four)
        #expect(places.framing(chapter: nil).chapter == nil && places.framing(chapter: nil).frame == places.frame)
    }

    /// The final review's I2: the chosen chapter's heading clicked with one of its rows chosen keeps the chapter, so a new
    /// choice count makes a new framing and the map frames the chapter again at its full height.
    @Test func theSameChapterChosenAgainIsANewFraming() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        #expect(places.framing(chapter: 4, choice: 1) != places.framing(chapter: 4, choice: 0))
        #expect(places.framing(chapter: 4, choice: 1).frame == places.framing(chapter: 4).frame)
        #expect(places.framing(chapter: 4) == places.framing(chapter: 4, choice: 0))
    }

    /// 13.2: the list, a chapter's rows and "At the same spot" each name the shared pin after the place.
    @Test func everyWayOfChoosingTitlesTheSharedPin() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        let point = "31.777,35.235"
        var fromList = PlacesSelection()
        fromList.choose(place: 1263, in: places.pins)
        var fromChapter = PlacesSelection()
        fromChapter.choose(place: 1263, in: places.pins(inChapter: 21))
        let fromSpot = PlacesSelection().following(.place(1263), in: places.pins)
        for selection in [fromList, fromChapter, fromSpot] {
            #expect(selection.pinID == point)
            #expect(places.pins.first { $0.id == point }?.title(choosing: selection.placeID) == "Zion")
        }
        var inChapterTwo = PlacesSelection()
        inChapterTwo.choose(pin: point, in: places.pins(inChapter: 2))
        #expect(inChapterTwo.placeID == 636)
    }

    /// 13.3: a second click on a gathered pin whose place is chosen lists its places.
    @Test func aSecondClickOnAGatheredPinListsItsPlaces() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        var selection = PlacesSelection()
        selection.choose(place: 1263, in: places.pins)
        selection.reopen(in: places.pins)
        #expect(selection.placeID == nil && selection.pinID == "31.777,35.235")
        #expect(selection.gathered(in: places.pins)?.map(\.name) == ["Jerusalem", "Zion"])
        selection.choose(place: 218, in: places.pins)
        let before = selection
        selection.reopen(in: places.pins)
        #expect(selection == before)
        var empty = PlacesSelection()
        empty.reopen(in: places.pins)
        #expect(empty == PlacesSelection())
    }

    /// Ruling 9 and the final review's I4: the re-click acts a turn after the tap, only while the map still has the pin
    /// tapped and only when the reopen changes the selection; the caller then clears the trail (the Mac) or empties the
    /// sheet's path (the phone).
    @Test func aReClickActsOnlyWhileThePinIsStillChosenAndOnlyOnAChange() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        let point = "31.777,35.235"
        var zion = PlacesSelection()
        zion.choose(place: 1263, in: places.pins)
        let reopened = try #require(zion.reopened(at: point, in: places.pins))
        #expect(reopened.placeID == nil && reopened.pinID == point)
        #expect(reopened.gathered(in: places.pins)?.map(\.name) == ["Jerusalem", "Zion"])
        #expect(zion.reopened(at: places.pin(holding: 218)?.id, in: places.pins) == nil)   // the map gave the click to a neighbour
        #expect(zion.reopened(at: nil, in: places.pins) == nil)
        var bethlehem = PlacesSelection()
        bethlehem.choose(place: 218, in: places.pins)
        #expect(bethlehem.reopened(at: places.pin(holding: 218)?.id, in: places.pins) == nil)   // a pin of one place: no change
        #expect(reopened.reopened(at: point, in: places.pins) == nil)                            // its places already listed
    }

    /// The map's own rule, without a map: the camera moves only for a pin out of view, at the same
    /// zoom. "In view" is judged on the region the map has at its new size (the map shrinks to half
    /// when something is chosen), and a marker's height in from each edge counts as out of view.
    @Test func theCameraMovesOnlyForAPinOutOfViewAndKeepsItsZoom() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
        let size = CGSize(width: 700, height: 800)
        let view = PlacesMapView.region(try #require(places.frame))
        let jerusalem = try #require(places.pin(holding: 636))
        #expect(PlacesMapView.region(view, size: size, holding: jerusalem, inset: 44) == nil)
        let close = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 30, longitude: 31), span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        let moved = try #require(PlacesMapView.region(close, size: size, holding: jerusalem, inset: 44))
        #expect(moved.center.latitude == jerusalem.latitude && moved.center.longitude == jerusalem.longitude && moved.span.latitudeDelta == 1)
        // Jerusalem 0.4 degrees above the centre of a 1-degree region: in view at full height...
        let tall = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: jerusalem.latitude - 0.4, longitude: jerusalem.longitude),
                                      span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        #expect(PlacesMapView.region(tall, size: size, holding: jerusalem, inset: 0) == nil)
        // ...but within a marker's height of the top edge, and out of view once the map is half as tall.
        #expect(PlacesMapView.region(tall, size: size, holding: jerusalem, inset: 100) != nil)
        let half = CGSize(width: 700, height: 400)
        let shrunk = PlacesMapView.visibleRegion(tall, reportedAt: size, now: half)
        #expect(shrunk.span.latitudeDelta == 0.5 && shrunk.span.longitudeDelta == 1 && shrunk.center.latitude == tall.center.latitude)
        #expect(PlacesMapView.region(shrunk, size: half, holding: jerusalem, inset: 0)?.span.latitudeDelta == 0.5)
        #expect(PlacesMapView.visibleRegion(tall, reportedAt: .zero, now: half).span.latitudeDelta == 1)   // nothing reported yet
    }

    /// The list's rows: a label only where two of the book's places share a name; the header's count;
    /// a book that names no place.
    @Test func theListsRowsAndCountReadAsPeoplesDo() throws {
        let store = try FixtureStore.make()
        let places = try #require(try BookPlaces.load(book: "MAT", store: store))
        #expect(LibraryPlacesView.sharedNames(places).isEmpty)
        #expect(LibraryPlacesView.detail(kind: "city", label: "Syria") == "city · Syria" && LibraryPlacesView.detail(kind: nil, label: nil) == nil)
        let ramah = try #require(places.onMap.first { $0.id == 978 })
        #expect(LibraryPlacesView.accessibilityLabel(ramah, label: nil) == "Ramah, city, 1 verse")
        #expect(LibraryView.countLabel(.places, LibraryView.Loaded(places: places)) == "8 places · 6 on the map")
        let genesis = try #require(try BookPlaces.load(book: "GEN", store: store))
        #expect(genesis.namesNoPlace && !places.namesNoPlace)
        #expect(LibraryView.countLabel(.places, LibraryView.Loaded(places: genesis)) == nil && LibraryView.countLabel(.about, LibraryView.Loaded()) == nil)
    }

    /// Two Antiochs in Acts: each row carries the label that tells it apart.
    @Test(.needsRealBible) func aSharedNameCarriesItsLabel() throws {
        let acts = try #require(try BookPlaces.load(book: "ACT", store: BenchmarkChapter.realStore()))
        #expect(LibraryPlacesView.sharedNames(acts).contains("Antioch") && !LibraryPlacesView.sharedNames(acts).contains("Jerusalem"))
    }
}
