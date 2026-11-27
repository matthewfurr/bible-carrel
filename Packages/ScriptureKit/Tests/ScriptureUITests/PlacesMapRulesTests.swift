import CoreGraphics
import MapKit
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// The map's rules without a map: what it draws and in what order, where its camera goes for a chapter,
/// how fast steps are coalesced into one move, and where a click reopens the chosen pin.
@Suite struct PlacesMapRulesTests {
    private func matthew() throws -> BookPlaces {
        try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make()))
    }

    private func acts() throws -> BookPlaces {
        try #require(try BookPlaces.load(book: "ACT", store: BenchmarkChapter.realStore()))
    }

    /// Departure 16: the chosen pin last, so MapKit draws it and its title above its neighbours.
    @Test func theChosenPinIsDrawnLast() throws {
        let pins = try matthew().pins
        let jerusalem = "31.777,35.235"
        let ordered = PlacesMapView.drawOrder(pins, chosen: jerusalem)
        #expect(ordered.last?.id == jerusalem)
        #expect(ordered.dropLast().map(\.id) == pins.map(\.id).filter { $0 != jerusalem })
        #expect(PlacesMapView.drawOrder(pins, chosen: nil).map(\.id) == pins.map(\.id))
        #expect(PlacesMapView.drawOrder(pins, chosen: "0.000,0.000").map(\.id) == pins.map(\.id))
    }

    /// Matt's review, 2026-11-24 (call 32): MapKit draws every title beneath every balloon, so the chosen pin's name is
    /// the app's drawn label and its own system title is hidden (no doubled name); every other pin's is MapKit's to show
    /// or drop, as before.
    @Test func onlyTheChosenPinsSystemTitleIsHidden() throws {
        let pins = try matthew().pins
        let jerusalem = "31.777,35.235"
        let hidden = pins.filter { PlacesMapView.titleVisibility(of: $0.id, chosen: jerusalem) == .hidden }.map(\.id)
        #expect(hidden == [jerusalem])
        #expect(pins.filter { $0.id != jerusalem }.allSatisfy { PlacesMapView.titleVisibility(of: $0.id, chosen: jerusalem) == .automatic })
        #expect(pins.allSatisfy { PlacesMapView.titleVisibility(of: $0.id, chosen: nil) == .automatic })
    }

    /// Matt's review, 2026-11-24 (call 32): the drawn label is there only while a pin of the map is chosen, at that pin's
    /// point, carrying the pin's title for the chosen place; none with nothing chosen or with a pin the map does not draw.
    @Test func theLabelIsDrawnOnlyForTheChosenPin() throws {
        let pins = try matthew().pins
        let jerusalem = try #require(pins.first { $0.id == "31.777,35.235" })
        let label = try #require(PlacesMapView.chosenLabel(pins, chosen: jerusalem.id, placeID: nil))
        #expect(label.id == jerusalem.id && label.name == jerusalem.title)
        #expect(label.latitude == jerusalem.latitude && label.longitude == jerusalem.longitude)
        #expect(PlacesMapView.chosenLabel(pins, chosen: nil, placeID: nil) == nil)
        #expect(PlacesMapView.chosenLabel(pins, chosen: "0.000,0.000", placeID: nil) == nil)
        #expect(PlacesMapView.chosenLabel([], chosen: jerusalem.id, placeID: nil) == nil)
    }

    /// The two clusters Matt saw fail: Solomon's Portico under Jerusalem's "5" in Acts, and the Jordan in Joshua.
    @Test(.needsRealBible) func theLabelNamesTheChosenPlaceInACrowdedCluster() throws {
        let acts = try acts()
        let portico = try #require(acts.pin(holding: 1109))
        #expect(PlacesMapView.chosenLabel(acts.pins, chosen: portico.id, placeID: 1109)?.name == "Solomon's Portico")
        #expect(PlacesMapView.chosenLabel(acts.pins, chosen: portico.id, placeID: 636)?.name == "Jerusalem")
        let joshua = try #require(try BookPlaces.load(book: "JOS", store: BenchmarkChapter.realStore()))
        let jordanID = try #require(joshua.onMap.first { $0.name == "Jordan" }?.id)
        let jordan = try #require(joshua.pin(holding: jordanID))
        let label = try #require(PlacesMapView.chosenLabel(joshua.pins, chosen: jordan.id, placeID: jordanID))
        #expect(label.name == "Jordan" && label.id == jordan.id)
        #expect(PlacesMapView.drawOrder(joshua.pins, chosen: jordan.id).last?.id == label.id)
    }

    /// Departure 11: a chapter is framed by its own frame, unless the chosen pin is out of it; then the
    /// frame's zoom is kept, centred on the pin.
    @Test(.needsRealBible) func aChapterIsFramedWithTheChosenPinInView() throws {
        let acts = try acts()
        let frame = try #require(acts.frame(inChapter: 1))
        let size = CGSize(width: 700, height: 800)
        let region = PlacesMapView.region(frame)
        let jerusalemID = try #require(acts.onMap.first { $0.name == "Jerusalem" }?.id)
        let jerusalem = try #require(acts.pin(holding: jerusalemID))
        let held = PlacesMapView.framed(frame, size: size, holding: jerusalem, inset: 44)
        #expect(held.center.latitude == region.center.latitude && held.center.longitude == region.center.longitude)
        #expect(held.span.latitudeDelta == region.span.latitudeDelta && held.span.longitudeDelta == region.span.longitudeDelta)
        let rome = try #require(acts.pins.first { abs($0.latitude - 41.900) < 0.001 && abs($0.longitude - 12.483) < 0.001 })
        let centred = PlacesMapView.framed(frame, size: size, holding: rome, inset: 44)
        #expect(centred.center.latitude == rome.latitude && centred.center.longitude == rome.longitude)
        #expect(centred.span.latitudeDelta == frame.latitudeSpan && centred.span.longitudeDelta == frame.longitudeSpan)
        let alone = PlacesMapView.framed(frame, size: size, holding: nil, inset: 44)
        #expect(alone.center.latitude == region.center.latitude && alone.span.latitudeDelta == region.span.latitudeDelta)
    }

    /// Review Focus 4: only the latest of the camera's requests is current, so of several made before the main run loop
    /// turns only the last moves the camera (the stepping itself is the map's: seen live, → four times made one move).
    @Test func onlyTheLatestCameraRequestIsCurrent() {
        var queue = PlacesCameraQueue()
        let first = queue.request()
        let second = queue.request()
        let third = queue.request()
        #expect(!queue.isCurrent(first) && !queue.isCurrent(second) && queue.isCurrent(third))
        let fourth = queue.request()
        #expect(!queue.isCurrent(third) && queue.isCurrent(fourth))
    }

    /// 13.3: a click inside the chosen marker's balloon (above its point, a clearance high and wide) reopens it.
    @Test func aClickOnTheChosenMarkerReopensIt() {
        let pin = CGPoint(x: 200, y: 300)
        #expect(PlacesMapView.isOnChosenMarker(CGPoint(x: 200, y: 280), pinPoint: pin, clearance: 44))
        #expect(PlacesMapView.isOnChosenMarker(CGPoint(x: 215, y: 270), pinPoint: pin, clearance: 44))
        #expect(!PlacesMapView.isOnChosenMarker(CGPoint(x: 200, y: 340), pinPoint: pin, clearance: 44))
        #expect(!PlacesMapView.isOnChosenMarker(CGPoint(x: 230, y: 280), pinPoint: pin, clearance: 44))
    }

    /// Review fix: a map with no `onReopen` keeps its own taps, pans and zooms and runs no added tap
    /// (`.subviews`, not `.none`, which would turn off the map's gestures too); with one, both run.
    @Test func aMapWithoutReopenKeepsItsOwnGesturesAndAddsNone() {
        #expect(PlacesMapView.reopenTapMask(reopening: false) == .subviews)
        #expect(PlacesMapView.reopenTapMask(reopening: true) == .all)
    }

    private func pin(latitude: Double, longitude: Double = 35) -> BookPlaces.Pin {
        BookPlaces.Pin(id: "\(latitude),\(longitude)", latitude: latitude, longitude: longitude, places: [], title: "", mentions: 0)
    }

    /// 13.6, Departure 17: on the phone the part of the map under the sheet is out of view; a pin under the
    /// medium detent is moved to the middle of the part above it, at the same zoom.
    @Test func aPinUnderTheSheetIsOutOfView() throws {
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 32, longitude: 35),
                                        span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        let size = CGSize(width: 400, height: 800)
        let moved = try #require(PlacesMapView.region(region, size: size, holding: pin(latitude: 31.8), inset: 0, bottomCover: 400))
        #expect(abs(moved.center.latitude - 31.55) <= 1e-9)
        #expect(moved.center.longitude == 35)
        #expect(moved.span.latitudeDelta == 1 && moved.span.longitudeDelta == 1)
        #expect(PlacesMapView.region(region, size: size, holding: pin(latitude: 32.25), inset: 0, bottomCover: 400) == nil)
        #expect(PlacesMapView.region(region, size: size, holding: pin(latitude: 31.8), inset: 0, bottomCover: 0) == nil)
    }

    /// 5.5 on the phone: a chapter is framed into the part of the map the sheet leaves visible, its span grown
    /// to fill that part and its centre mid-way down it; with no cover it is the frame itself.
    @Test func aChapterIsFramedAboveTheSheet() {
        let frame = BookPlaces.Frame(latitude: 32, longitude: 35, latitudeSpan: 1, longitudeSpan: 1)
        let size = CGSize(width: 400, height: 800)
        let framed = PlacesMapView.framed(frame, size: size, holding: nil, inset: 0, bottomCover: 400)
        #expect(framed.span.latitudeDelta == 2 && framed.span.longitudeDelta == 1)
        #expect(framed.center.latitude == 31.5 && framed.center.longitude == 35)
        let uncovered = PlacesMapView.framed(frame, size: size, holding: nil, inset: 0, bottomCover: 0)
        let region = PlacesMapView.region(frame)
        #expect(uncovered.center.latitude == region.center.latitude && uncovered.center.longitude == region.center.longitude)
        #expect(uncovered.span.latitudeDelta == region.span.latitudeDelta && uncovered.span.longitudeDelta == region.span.longitudeDelta)
    }

    /// A chapter wider than the part above the sheet: MapKit shows it taller than its latitude asks (Mercator at the
    /// equator: a degree of longitude is a degree of latitude), so its centre is lowered by the latitude shown and the
    /// chapter still sits mid-way down that part. At the large detent (no room for a marker) it is framed as with no sheet.
    @Test func aWideChapterAndTheLargeDetentAreFramedClearOfTheSheet() {
        let size = CGSize(width: 400, height: 800)
        let wide = BookPlaces.Frame(latitude: 0, longitude: 0, latitudeSpan: 0.1, longitudeSpan: 2)
        let framed = PlacesMapView.framed(wide, size: size, holding: nil, inset: 0, bottomCover: 400)
        #expect(framed.span.latitudeDelta == 4 && framed.span.longitudeDelta == 2)
        #expect(framed.center.latitude == -1 && framed.center.longitude == 0)
        let frame = BookPlaces.Frame(latitude: 32, longitude: 35, latitudeSpan: 1, longitudeSpan: 1)
        let covered = PlacesMapView.framed(frame, size: size, holding: nil, inset: 44, bottomCover: 760)
        let region = PlacesMapView.region(frame)
        #expect(covered.center.latitude == region.center.latitude && covered.span.latitudeDelta == region.span.latitudeDelta)
    }

    /// Ruling 10, Departure 17: at the large detent the part above the sheet is shorter than two clearances, so nothing pans.
    @Test func nothingPansWhenTheSheetCoversTheMap() {
        let size = CGSize(width: 400, height: 800)
        #expect(PlacesMapView.canReveal(size: size, bottomCover: 400, inset: 44))
        #expect(!PlacesMapView.canReveal(size: size, bottomCover: 760, inset: 44))
    }

    /// Matt's review, 2026-11-24: the phone's sheet is never taller than half the page, so on every iPhone (the SE's
    /// 667 pt to the Pro Max's 956) and at the largest text the part above it holds a marker clear of both its edges: the
    /// camera always pans a chosen pin above the sheet, and a chapter is framed wholly above the sheet's top.
    @Test func atTheSheetsTallestTheMapAboveItAlwaysHasRoom() {
        let clearance: CGFloat = 44 * 3.2 // the marker clearance at `.accessibility5`, a little over
        let frame = BookPlaces.Frame(latitude: 32, longitude: 35, latitudeSpan: 1, longitudeSpan: 0.5)
        for height in [667.0, 812, 874, 956] as [CGFloat] {
            let size = CGSize(width: 375, height: height)
            let cover = PlacesSheet.tallestCover(of: height)
            #expect(cover <= height / 2)
            #expect(PlacesMapView.canReveal(size: size, bottomCover: cover, inset: clearance))
            let framed = PlacesMapView.framed(frame, size: size, holding: nil, inset: clearance, bottomCover: cover)
            let top = framed.center.latitude + framed.span.latitudeDelta / 2
            let sheetTop = top - framed.span.latitudeDelta * (height - cover) / height
            #expect(frame.latitude + frame.latitudeSpan / 2 <= top + 1e-9)
            #expect(frame.latitude - frame.latitudeSpan / 2 >= sheetTop - 1e-9)
        }
    }

    /// The final review's I3: the map opens at its framing before the phone's sheet has settled, so a chapter kept on
    /// coming back from a lookup is framed again into the part above the sheet once it settles (and only then: never with
    /// no sheet, so never on the Mac); the book's own frame is not, since nothing was chosen. A framing made at the large
    /// detent (no room) is made again once the sheet settles lower, as before.
    @Test func aChapterKeptOnComingBackIsFramedAboveTheSheet() throws {
        let places = try matthew()
        #expect(PlacesMapView.opensWithoutRoom(places.framing(chapter: 4)))
        #expect(!PlacesMapView.opensWithoutRoom(places.framing(chapter: nil)))
        #expect(!PlacesMapView.reframes(changed: false, framedWithoutRoom: true, bottomCover: 0, hasRoom: true))
        #expect(PlacesMapView.reframes(changed: false, framedWithoutRoom: true, bottomCover: 400, hasRoom: true))
        #expect(!PlacesMapView.reframes(changed: false, framedWithoutRoom: true, bottomCover: 760, hasRoom: false))
        #expect(!PlacesMapView.reframes(changed: false, framedWithoutRoom: false, bottomCover: 400, hasRoom: true))
        #expect(PlacesMapView.reframes(changed: true, framedWithoutRoom: false, bottomCover: 0, hasRoom: true))
    }

    /// Departure 6: the chapter's pins and the book's other points as dots draw every point once.
    @Test(.needsRealBible) func theMapIsGivenTheChaptersPinsAndDots() throws {
        let acts = try acts()
        let pins = acts.pins(inChapter: 1), dots = acts.dots(inChapter: 1)
        #expect(pins.count + dots.count == 95)
        #expect(Set(pins.map(\.id) + dots.map(\.id)) == Set(acts.pins.map(\.id)))
    }
}
