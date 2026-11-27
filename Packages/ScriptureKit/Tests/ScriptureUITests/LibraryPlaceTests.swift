import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct LibraryPlaceTests {
    @Test func thePlaceWalksAndStepsBackAndForgetsThePagesOwnState() {
        var place = LibraryPlace(book: "MAT", topic: .people)
        place.choose(.person(994))
        place.toggledBooks = ["PSA"]
        place = place.opening(Reference(book: BookCatalog.book(code: "PSA")!, chapter: 18, verse: 50))
        #expect(place.showing == .person(994) && place.anchor?.displayString == "Psalm 18:50")
        place.walk(to: .person(903))
        #expect(place.trail == [.person(994), .person(903)] && place.toggledBooks.isEmpty && place.anchor == nil)
        place.stepBack()
        #expect(place.trail == [.person(994)])
        place.choose(.person(905))
        #expect(place.trail == [.person(905)])
    }

    /// Task 8: a choice in Places' list or map that leaves nothing chosen empties the trail.
    @Test func clearingTheTrailLeavesTheViewWithNothingChosen() {
        var place = LibraryPlace(book: "MAT", topic: .places, trail: [.place(636), .place(574)])
        place.toggledBooks = ["MAT"]
        place = place.opening(Reference(book: BookCatalog.book(code: "MAT")!, chapter: 2, verse: 1))
        place.clearTrail()
        #expect(place == LibraryPlace(book: "MAT", topic: .places) && place.showing == nil)
    }

    /// Task 7: a traditional writer on About opens that person in the book's People.
    @Test func aPersonFromAnotherTopicOpensInTheBooksPeople() {
        var about = LibraryPlace(book: "PSA", topic: .about)
        about.toggledBooks = ["PSA"]
        about.chooseInItsTopic(.person(994))
        #expect(about == LibraryPlace(book: "PSA", topic: .people, trail: [.person(994)]))
        var place = LibraryPlace(book: "MAT", topic: .people, trail: [.person(905)])
        place.chooseInItsTopic(.place(636))
        #expect(place == LibraryPlace(book: "MAT", topic: .places, trail: [.place(636)]))
    }

    @Test func steppingBackFromTheFirstLeavesNoneChosen() {
        var place = LibraryPlace(book: nil, topic: .people, trail: [.person(905)])
        place.stepBack()
        #expect(place.trail.isEmpty && place.showing == nil)
        place.stepBack()
        #expect(place.trail.isEmpty)
    }

    /// Project 4: the chosen chapter is part of the Library's "as it was".
    @Test func theChapterIsPartOfTheLibrarysAsItWas() {
        var place = LibraryPlace(book: "MAT", topic: .places)
        place.placesChapter = 4
        place.choose(.place(882))
        let opened = place.opening(Reference(book: BookCatalog.book(code: "MAT")!, chapter: 4, verse: 13))
        #expect(opened.placesChapter == 4)
        #expect(LibraryReturn(place: opened, chosenBookID: "MAT").place.placesChapter == 4)
        place.walk(to: .place(636))
        #expect(place.placesChapter == 4)
        place.stepBack()
        #expect(place.placesChapter == 4)
        place.clearTrail()
        #expect(place.placesChapter == 4)
        #expect(LibraryPlace(book: "MAT", topic: .places).placesChapter == nil)
    }
}
