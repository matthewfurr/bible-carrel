import ScriptureData
import Testing
@testable import ScriptureUI

/// The chosen chapter: the list's items in three orders, and the chapter kept in the Library's place
/// (spec 5.2 to 5.5), on the fixture's Matthew.
@Suite struct PlacesChaptersTests {
    private var matthew: BookPlaces {
        get throws { try #require(try BookPlaces.load(book: "MAT", store: FixtureStore.make())) }
    }

    @Test func theListInEachOrder() throws {
        let places = try matthew
        let mostNamed = PlacesList.items(places, order: .mostNamed)
        #expect(PlacesList.rows(mostNamed).prefix(6).map(\.id) == ["218", "362", "636", "882", "978", "1263"])
        #expect(mostNamed.map(\.id) == ["218", "362", "636", "882", "978", "1263", "not-on-the-map", "574", "1110"])
        #expect(mostNamed[6] == .notOnMap)

        let alphabetical = PlacesList.items(places, order: .alphabetical)
        #expect(PlacesList.rows(alphabetical).map(\.place.name)
            == ["Bethlehem", "Egypt", "Jerusalem", "Nazareth", "Ramah", "Zion", "Holy place", "South"])
        #expect(alphabetical.count == 9 && alphabetical[6] == .notOnMap)

        let byChapter = PlacesList.items(places, order: .byChapter)
        let headings = byChapter.compactMap { item -> String? in if case .heading = item { item.id } else { nil } }
        #expect(headings == ["chapter-2", "chapter-4", "chapter-5", "chapter-12", "chapter-21", "chapter-24"])
        let rows = PlacesList.rows(byChapter)
        #expect(rows.count == 11 && rows.first?.id == "2-218" && rows.last?.id == "24-574")
        #expect(!byChapter.contains(.notOnMap))
    }

    @Test func theHeaderLineReadsTheChapter() throws {
        let places = try matthew
        let second = try #require(places.chapter(2)), fifth = try #require(places.chapter(5)), twelfth = try #require(places.chapter(12))
        #expect(PlacesChapters.headerLine(second) == "Chapter 2 · 5 places")
        #expect(PlacesChapters.headerLine(fifth) == "Chapter 5 · 1 place")
        #expect(PlacesChapters.headerLine(twelfth) == "Chapter 12 · 1 place, none on the map")
        #expect(PlacesChapters.headingSpoken(second) == "Chapter 2, 5 places")
        #expect(PlacesChapters.announcement(twelfth) == "Chapter 12, 1 place, none on the map")
        #expect(PlacesChapters.rowHint(chapter: 3) == "in chapter 3")
        let loaded = LibraryView.Loaded(places: places)
        #expect(LibraryView.countLabel(.places, loaded, placesChapter: 2) == "Chapter 2 · 5 places")
        #expect(LibraryView.countLabel(.places, loaded, placesChapter: nil) == "8 places · 6 on the map")
        #expect(LibraryView.countLabel(.places, loaded, placesChapter: 3) == "8 places · 6 on the map")
        #expect(PlacesChapters.countLine(places, chapter: 2) == "Chapter 2 · 5 places")
        #expect(PlacesChapters.countLine(places, chapter: nil) == "8 places · 6 on the map")
    }

    /// Ruling 14 and the final review's I4 and Minor 1: what VoiceOver hears on each change of the chapter in effect, on
    /// both apps; when it clears, the book's count in its spoken form, a comma where the line shows a middle dot.
    @Test func theAnnouncementIsTheChapterOrTheBooksSpokenCount() throws {
        let places = try matthew
        #expect(PlacesChapters.announcementText(places, chapter: 2) == "Chapter 2, 5 places")
        #expect(PlacesChapters.announcementText(places, chapter: 12) == "Chapter 12, 1 place, none on the map")
        #expect(PlacesChapters.announcementText(places, chapter: nil) == "8 places, 6 on the map")
        #expect(PlacesChapters.announcementText(places, chapter: 3) == "8 places, 6 on the map")
        #expect(places.countSpoken == "8 places, 6 on the map" && places.countLabel == "8 places · 6 on the map")
    }

    /// The final review's Minor 6: a heading's help tag says what a click does; a washed heading's click clears the chapter.
    @Test func aHeadingsHelpSaysWhatAClickDoes() {
        #expect(PlacesChapters.headingHelp(6, clears: false) == "Show chapter 6 on the map")
        #expect(PlacesChapters.headingHelp(6, clears: true) == "Show the whole book on the map")
    }

    /// 13.5: a heading chooses its chapter and closes the page; the chosen heading again, while it shows its wash (no row
    /// chosen), clears it.
    @Test func aHeadingChoosesItsChapterAndClosesThePage() {
        var place = LibraryPlace(book: "MAT", topic: .places, trail: [.place(636), .place(1263)])
        place.toggledBooks = ["MAT"]
        place.chooseChapter(4, rowChosen: true)
        #expect(place.placesChapter == 4 && place.trail.isEmpty && place.toggledBooks.isEmpty)
        place.chooseChapter(4, rowChosen: false)
        #expect(place.placesChapter == nil)
        place.chooseChapter(4, rowChosen: false)
        place.chooseChapter(5, rowChosen: false)
        #expect(place.placesChapter == 5)
        #expect(PlacesChapters.afterHeading(4, chosen: 4, rowChosen: false) == nil)
        #expect(PlacesChapters.afterHeading(4, chosen: 5, rowChosen: false) == 4 && PlacesChapters.afterHeading(4, chosen: nil, rowChosen: false) == 4)
    }

    /// The final review's I2: with a row of the chosen chapter chosen, its heading shows no wash, so a click on it chooses
    /// the chapter as a click on any heading does (the page closes, the map takes the full height, framed); it does not
    /// clear the chapter.
    @Test func theChosenChaptersHeadingWithARowChosenChoosesTheChapter() {
        #expect(PlacesChapters.afterHeading(6, chosen: 6, rowChosen: true) == 6)
        var place = LibraryPlace(book: "MAT", topic: .places)
        place.choosePlace(882, inChapter: 4)
        place.toggledBooks = ["MAT"]
        place.chooseChapter(4, rowChosen: true)
        #expect(place.placesChapter == 4 && place.trail.isEmpty && place.toggledBooks.isEmpty)
    }

    /// Departure 8, pinned (the final review's Minor 4): the chosen heading clicked while it shows its wash clears the
    /// chapter only; whatever is on show stays on show. (A place of the book on show always has its row chosen, so on the
    /// Mac a washed heading has no place of the book on show; the rule keeps the trail all the same.)
    @Test func theWashedHeadingAgainClearsTheChapterAndKeepsThePlace() {
        var place = LibraryPlace(book: "MAT", topic: .places)
        place.choosePlace(882, inChapter: 4)
        place.chooseChapter(4, rowChosen: false)
        #expect(place.placesChapter == nil && place.trail == [.place(882)] && place.showing == .place(882))
    }

    @Test func aRowChoosesItsPlaceAndItsChapter() {
        var place = LibraryPlace(book: "MAT", topic: .places)
        place.choosePlace(882, inChapter: 4)
        #expect(place.placesChapter == 4 && place.trail == [.place(882)])
        place.choosePlace(636, inChapter: nil)
        #expect(place.placesChapter == 4 && place.trail == [.place(636)])
    }

    /// Ruling 19: a step to the place already on show alone keeps its page.
    @Test func aStepToThePlaceShownKeepsThePage() {
        var place = LibraryPlace(book: "MAT", topic: .places)
        place.choosePlace(882, inChapter: 2)
        place.toggledBooks = ["MAT"]
        place.choosePlace(882, inChapter: 4)
        #expect(place.placesChapter == 4 && place.trail == [.place(882)] && place.toggledBooks == ["MAT"])
    }

    @Test func aPlaceShownAnotherWayMovesTheChapter() throws {
        let places = try matthew
        #expect(PlacesChapters.following(showing: .place(1263), chosen: 4, in: places) == 21)
        #expect(PlacesChapters.following(showing: .place(636), chosen: 5, in: places) == 5)
        #expect(PlacesChapters.following(showing: .place(979), chosen: 4, in: places) == nil)
        #expect(PlacesChapters.following(showing: .place(1263), chosen: nil, in: places) == nil)
        #expect(PlacesChapters.following(showing: nil, chosen: 4, in: places) == 4)
        var place = LibraryPlace(book: "MAT", topic: .places)
        place.placesChapter = 4
        place.walk(to: .place(1263))
        let followed = try #require(place.followed(in: places))
        #expect(followed.placesChapter == 21 && followed.trail == place.trail)
    }

    /// Live pass 1: the list wrote its place on every change of the place on show, so the view going on Esc (its place
    /// read as the front page's stand-in, nothing showing) wrote that stand-in back and opened it. Only a change is written.
    @Test func aChapterThatAlreadyFollowsWritesNothing() throws {
        let places = try matthew
        #expect(LibraryPlace(book: nil, topic: .people).followed(in: places) == nil)
        var place = LibraryPlace(book: "MAT", topic: .places)
        place.placesChapter = 4
        #expect(place.followed(in: places) == nil)                  // nothing on show keeps the chapter
        place.choose(.place(636))
        place.placesChapter = 5
        #expect(place.followed(in: places) == nil)                  // chapter 5 names Jerusalem
        place.clearChapter()
        #expect(place.followed(in: places) == nil)                  // no chapter chosen
    }

    @Test func theChosenRowIsOneRow() throws {
        let places = try matthew
        let byChapter = PlacesList.rows(PlacesList.items(places, order: .byChapter))
        #expect(PlacesList.chosenRowID(showing: .place(636), chapter: 5, in: byChapter) == "5-636")
        #expect(PlacesList.chosenRowID(showing: .place(636), chapter: nil, in: byChapter) == "2-636")
        #expect(PlacesList.chosenRowID(showing: .place(636), chapter: 12, in: byChapter) == "2-636")
        #expect(PlacesList.chosenRowID(showing: .place(979), chapter: nil, in: byChapter) == nil)
        #expect(PlacesList.chosenRowID(showing: nil, chapter: 5, in: byChapter) == nil)
        let mostNamed = PlacesList.rows(PlacesList.items(places, order: .mostNamed))
        #expect(PlacesList.chosenRowID(showing: .place(636), chapter: nil, in: mostNamed) == "636")
    }

    /// 13.5: another order clears the chapter (By chapter keeps it), and the place on show keeps its row in that order.
    @Test func anotherOrderClearsTheChapterAndThePlaceKeepsItsRow() throws {
        let places = try matthew
        let cleared = PlacesChapters.afterOrderChange(to: .alphabetical, chosen: 4)
        let rows = PlacesList.rows(PlacesList.items(places, order: .alphabetical))
        #expect(PlacesList.chosenRowID(showing: .place(882), chapter: cleared, in: rows) == "882")
        #expect(PlacesChapters.afterOrderChange(to: .byChapter, chosen: 4) == 4)
        #expect(PlacesChapters.afterOrderChange(to: .alphabetical, chosen: 4) == nil)
        #expect(PlacesChapters.afterOrderChange(to: .mostNamed, chosen: 4) == nil)
        #expect(PlacesChapters.effective(4, order: .byChapter) == 4)
        #expect(PlacesChapters.effective(4, order: .alphabetical) == nil)
        #expect(PlacesChapters.effective(nil, order: .byChapter) == nil)
    }

    /// 13.5: ↑ and ↓ walk the rows across chapters, headings skipped; with none chosen ↓ takes the first and ↑ the
    /// last; past an end, nothing.
    @Test func upAndDownSkipHeadingsAndMoveTheChapter() throws {
        let places = try matthew
        let rows = PlacesList.rows(PlacesList.items(places, order: .byChapter))
        #expect(PlacesList.neighbour(of: "2-882", step: 1, in: rows)?.id == "4-882")
        #expect(PlacesList.neighbour(of: "4-636", step: -1, in: rows)?.id == "4-882")
        #expect(PlacesList.neighbour(of: "24-574", step: 1, in: rows) == nil)
        #expect(PlacesList.neighbour(of: nil, step: 1, in: rows)?.id == "2-218")
        #expect(PlacesList.neighbour(of: nil, step: -1, in: rows)?.id == "24-574")

        var place = LibraryPlace(book: "MAT", topic: .places)
        place.choosePlace(882, inChapter: 2)
        let down = try #require(PlacesList.neighbour(of: "2-882", step: 1, in: rows))
        place.choosePlace(down.place.id, inChapter: down.chapter)
        #expect(place.placesChapter == 4 && place.trail == [.place(882)])
    }

    /// With a chapter's heading chosen and no row: ↓ takes the heading's first row, ↑ the row above the heading.
    @Test func upAndDownFromAChosenHeadingStartAtTheHeading() throws {
        let rows = PlacesList.rows(PlacesList.items(try matthew, order: .byChapter))
        #expect(PlacesList.neighbour(of: nil, step: 1, in: rows, heading: 4)?.id == "4-882")
        #expect(PlacesList.neighbour(of: nil, step: -1, in: rows, heading: 4)?.id == "2-882")
        #expect(PlacesList.neighbour(of: nil, step: -1, in: rows, heading: 2) == nil)
        #expect(PlacesList.neighbour(of: "4-636", step: -1, in: rows, heading: 4)?.id == "4-882")
    }

    /// 13.5: ← and → step the chapters that name a place, stopping at the ends; from none, → the first and ← the
    /// last (Departure 9).
    @Test func leftAndRightStepChaptersAndStopAtTheEnds() throws {
        let places = try matthew
        #expect(PlacesChapters.step(1, from: 2, in: places) == 4)
        #expect(PlacesChapters.step(-1, from: 4, in: places) == 2)
        #expect(PlacesChapters.step(1, from: 24, in: places) == nil)
        #expect(PlacesChapters.step(-1, from: 2, in: places) == nil)
        #expect(PlacesChapters.step(1, from: nil, in: places) == 2)
        #expect(PlacesChapters.step(-1, from: nil, in: places) == 24)

        var place = LibraryPlace(book: "MAT", topic: .places)
        place.choosePlace(636, inChapter: 2)
        let next = try #require(PlacesChapters.step(1, from: place.placesChapter, in: places))
        place.chooseChapter(next, rowChosen: true)
        #expect(place.placesChapter == 4 && place.trail.isEmpty)
    }

    @Test func onlyByChapterTakesLeftAndRight() {
        #expect(PlacesChapters.takesChapterKeys(.byChapter))
        #expect(!PlacesChapters.takesChapterKeys(.mostNamed))
        #expect(!PlacesChapters.takesChapterKeys(.alphabetical))
    }

    @Test func dimmedRowsAreTheOtherChapters() throws {
        let byChapter = PlacesList.rows(PlacesList.items(try matthew, order: .byChapter))
        let second = try #require(byChapter.first { $0.id == "2-636" }), fourth = try #require(byChapter.first { $0.id == "4-636" })
        #expect(PlacesList.isDimmed(second, chapter: 4) && !PlacesList.isDimmed(fourth, chapter: 4))
        #expect(!PlacesList.isDimmed(second, chapter: nil) && !PlacesList.isDimmed(fourth, chapter: nil))
    }
}
