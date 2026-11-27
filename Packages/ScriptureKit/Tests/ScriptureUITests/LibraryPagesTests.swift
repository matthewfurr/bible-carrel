import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct LibraryPagesTests {
    private var store: BibleStore { get throws { try FixtureStore.make() } }
    private static func partnerID(_ head: FamilyTree.Household.Head) -> Int? {
        if case .partner(let person) = head { person.id } else { nil }
    }

    private func mt(_ chapter: Int, _ verse: Int) -> VerseLocation { VerseLocation(book: "MAT", chapter: chapter, verse: verse) }

    @Test func yearsReadAsTheSpecWritesThem() {
        #expect(LibraryYear.text(-1995) == "about 1996 BC" && LibraryYear.text(30) == "about AD 30" && LibraryYear.text(0) == "about 1 BC" && LibraryYear.text(1) == "about AD 1")
        #expect(LibraryYear.life(birth: -1995, death: -1820) == "about 1996 BC to about 1821 BC")
        #expect(LibraryYear.life(birth: -3, death: nil) == "born about 4 BC" && LibraryYear.life(birth: nil, death: -1055) == "died about 1056 BC")
        #expect(LibraryYear.life(birth: nil, death: nil) == nil && LibraryYear.span([]) == nil && LibraryYear.span([28]) == "about AD 28")
        #expect(LibraryYear.lived(birth: -1084, death: -1014) == "about 1085 to 1015 BC" && LibraryYear.lived(birth: -3, death: 30) == "about 4 BC to AD 30")
        #expect(LibraryYear.lived(birth: -1754, death: nil) == "born about 1755 BC" && LibraryYear.lived(birth: nil, death: -1055) == "died about 1056 BC")
        #expect(LibraryYear.lived(birth: nil, death: nil) == nil)
        #expect(LibraryYear.span([26, -4, -3]) == "about 5 BC to about AD 26")
    }

    @Test func neighbouringVersesJoinIntoOneReference() {
        let references = VerseRuns.references([mt(1, 18), mt(1, 19), mt(1, 20), mt(1, 24), mt(2, 1)]).map(\.displayString)
        #expect(references == ["Matthew 1:18-20", "Matthew 1:24", "Matthew 2:1"])
    }

    @Test func aSharedNameInTheListIsToldApartAndOnlyThere() throws {
        let people = try #require(try BookPeople.load(book: "MAT", store: store))
        #expect(people.title == "People in Matthew" && people.countLabel(.mostNamed) == "12 named · by mentions")
        #expect(people.rows.filter { $0.label != nil }.map { "\($0.person.name), \($0.label!)" }
                == ["Herod, Matthew 2:1", "Jacob, father of Joseph", "Herod, Matthew 14:1", "Jacob, Israel"])   // Joseph has a label but is alone here
        #expect(people.rows[6].accessibilityLabel == "Jacob, father of Joseph, 2 verses" && people.rows[0].accessibilityLabel == "Jesus Christ, 6 verses")
        #expect(try BookPeople.load(book: "TOB", store: store) == nil)
    }

    @Test func aPersonsPageHasFamilyByGenerationAndVersesHereAndElsewhere() throws {
        let david = try #require(try PersonPage.load(994, inBook: "MAT", store: store))
        #expect(david.family.parents.map(\.name) == ["Jesse"] && david.family.children.map(\.name) == ["Solomon"])
        #expect(david.family.households.isEmpty && david.family.siblings.isEmpty)
        #expect(david.here?.references.map(\.displayString) == ["Matthew 1:1", "Matthew 1:6"] && david.here?.count == 2)
        #expect(david.elsewhere.map { "\($0.book.id) \($0.count)" } == ["PSA 1"] && david.opensEveryBook)
        #expect(david.lived(showingDates: true) == "about 1085 to 1015 BC" && david.lived(showingDates: false) == nil && david.hasDate)
        #expect(david.namedLine == "2 verses here, 3 in 2 books")
        let whole = try #require(try PersonPage.load(994, inBook: nil, store: store))
        #expect(whole.here == nil && whole.elsewhere.map(\.book.id) == ["PSA", "MAT"])              // by book, in canon order
        #expect(whole.namedLine == "3 verses in 2 books")
        // One References section: the book opened from first, then the rest in canon order; few references, all open.
        let references = LibraryReferences(here: david.here, elsewhere: david.elsewhere)
        #expect(references.groups.map(\.book.id) == ["MAT", "PSA"] && references.total == 3 && references.opensEveryBook)
        #expect(LibraryReferences(here: whole.here, elsewhere: whole.elsewhere).groups.map(\.book.id) == ["PSA", "MAT"])
        let joseph = try #require(try PersonPage.load(1715, inBook: "MAT", store: store))
        #expect(joseph.family.parents.map(\.id) == [683] && !joseph.hasDate && joseph.alsoCalled == nil)
        #expect(joseph.family.households.count == 1 && Self.partnerID(joseph.family.households[0].head) == 1938)
        let jesus = try #require(try PersonPage.load(905, inBook: "PSA", store: store))
        #expect(jesus.alsoCalled == "Lord, Son" && jesus.lived(showingDates: true) == "about 4 BC to AD 30")
        let mary = try #require(try PersonPage.load(1938, inBook: "MAT", store: store))
        #expect(mary.family.households.count == 2)
        #expect(Self.partnerID(mary.family.households[0].head) == 1715 && mary.family.households[1].head == .notNamed(.father))
        #expect(mary.family.households[1].children.map(\.id) == [905])
        let joseph1710 = try #require(try PersonPage.load(1710, inBook: "MAT", store: store))
        #expect(joseph1710.family.grandparents.map(\.person.id) == [616])
        #expect(try PersonPage.load(1494, inBook: "PSA", store: store)?.here == nil && PersonPage.load(99, inBook: nil, store: store) == nil)
    }

    @Test func aPersonsFactsReadInOrder() throws {
        func facts(_ id: Int, _ book: String, dates: Bool = true) throws -> [String] {
            PersonPageView.facts(try #require(try PersonPage.load(id, inBook: book, store: store)), showingDates: dates).map(\.rawValue)
        }
        #expect(try facts(994, "MAT") == ["Father", "Lived", "Named", "Family"])
        #expect(try facts(994, "MAT", dates: false) == ["Father", "Named", "Family"])
        #expect(try facts(1715, "MAT") == ["Father", "Named", "Family"])
        #expect(try facts(905, "MAT") == ["Mother", "Also called", "Lived", "Named", "Family"])
    }

    @Test func placesGatherAtOneSpotAndTheUnlocatedSitApart() throws {
        let places = try #require(try BookPlaces.load(book: "MAT", store: store))
        #expect(places.countLabel == "8 places · 6 on the map" && places.notOnMap.map(\.name) == ["Holy place", "South"])
        #expect(places.pins.map(\.title) == ["Bethlehem", "Jerusalem", "Egypt", "Nazareth", "Ramah"] && places.pins.map(\.mentions) == [5, 5, 4, 2, 1])
        let jerusalem = try #require(places.pin(holding: 1263))
        #expect(jerusalem.places.map(\.name) == ["Jerusalem", "Zion"] && jerusalem.id == "31.777,35.235" && jerusalem.latitude == 31.777189)
        // The first four pins carry nine tenths of the 17 mentions: the frame is theirs, a fifth of air each side.
        let frame = try #require(places.frame)
        #expect(abs(frame.latitudeSpan - (32.706745 - 26.696361) * 1.4) < 0.001 && abs(frame.latitude - (32.706745 + 26.696361) / 2) < 0.001)
        let one = BookPlaces.frame([places.pins[0]])
        #expect(one?.latitudeSpan == 0.5 && one?.longitudeSpan == 0.5 && one?.latitude == 31.705361 && BookPlaces.frame([]) == nil)
        let psalms = try #require(try BookPlaces.load(book: "PSA", store: store))                   // two places, one spot
        #expect(psalms.pins.count == 1 && psalms.frame?.latitudeSpan == 0.5 && psalms.countLabel == "2 places · 2 on the map")
        let ramah = try #require(try PlacePage.load(978, inBook: "MAT", store: store))
        #expect(ramah.kindLine == "city · approximate" && ramah.isOnMap && ramah.here?.references.map(\.displayString) == ["Matthew 2:18"])
        #expect(LibraryReferences(here: ramah.here, elsewhere: ramah.elsewhere).groups.first?.book.id == "MAT")  // a place's References too
        let holy = try #require(try PlacePage.load(574, inBook: nil, store: store))
        #expect(holy.kindLine == nil && !holy.isOnMap && holy.pin == nil)
        let city = try #require(try PlacePage.load(636, inBook: "MAT", store: store))
        #expect(city.sameSpot.map(\.name) == ["Zion"] && city.alsoCalledLine == "also called Zion, Jebus, Salem, City of God" && city.kindLine == "city")
        #expect(try BookPlaces.load(book: "GEN", store: store)?.pins.isEmpty == true)                // a book that names no place
    }

    @Test func aboutABookGivesItsFactsWritersAndTimeline() throws {
        let about = try #require(try BookAbout.load(book: "MAT", translationID: "WEB", store: store))
        let verses = try store.verseCount(ofBook: "MAT", translationID: "WEB")
        #expect(about.testamentLine == "New Testament, the Gospels and Acts")
        #expect(about.lengthLine == "6 chapters, \(verses.formatted()) verses")
        #expect(about.writers.map(\.name) == ["Matthew"])
        #expect(about.peopleCount == 12 && about.topPeople.count == 5 && about.morePeople == 7)
        #expect(about.placeCount == 8 && about.topPlaces.count == 5 && about.morePlaces == 3)
        #expect(about.topPeople == Array(try store.people(inBook: "MAT").prefix(5)))
        #expect(about.spans(showingDates: true) == "about 5 BC to AD 28" && about.spans(showingDates: false) == nil && about.hasDate)
        let psalms = try #require(try BookAbout.load(book: "PSA", translationID: "KJV", store: store))
        #expect(psalms.timeline.entries.isEmpty && psalms.spans(showingDates: true) == nil && !psalms.hasDate)
        #expect(psalms.writers.map(\.name) == ["David", "Solomon"])
        #expect(try BookAbout.load(book: "TOB", translationID: "WEB", store: store) == nil)
    }

    @Test func aBookWithFewNamesListsThemAllAndOneWithNoneLeavesThemOut() throws {
        let books = try ["GEN", "EXO", "PSA", "MAT", "JHN", "ROM", "REV", "JUD", "PHM"].compactMap {
            try BookAbout.load(book: $0, translationID: "WEB", store: store)
        }
        let few = try #require(books.first { $0.peopleCount <= 5 && $0.peopleCount > 0 })
        #expect(few.morePeople == 0 && few.topPeople.count == few.peopleCount)
        let none = try #require(books.first { $0.peopleCount == 0 })
        #expect(none.topPeople.isEmpty && none.morePeople == 0)
    }

    @Test func theNavigationModelAnswersEachPageOrNilWhenThereIsNothing() throws {
        let defaults = try #require(UserDefaults(suiteName: "LibraryPagesTests-\(UUID().uuidString)"))
        let model = try NavigationModel(store: try store, positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "WEB")
        #expect(model.hasLibraryData(for: "MAT") && model.hasLibraryData(for: "PSA") && !model.hasLibraryData(for: "TOB") && !model.hasLibraryData(for: "XXX"))
        #expect(model.bookPeople("MAT")?.rows.count == 12 && model.bookPeople("TOB") == nil)
        #expect(model.personPage(994, inBook: nil)?.person.name == "David" && model.personPage(99, inBook: nil) == nil)
        #expect(model.bookPlaces("MAT")?.pins.count == 5 && model.placePage(636, inBook: nil)?.place.summary.name == "Jerusalem")
        #expect(model.bookAbout("MAT")?.testamentLine == "New Testament, the Gospels and Acts")
        #expect(model.bookSubtitle("MAT") == "The Gospel According to Matthew" && model.bookSubtitle("XXX") == nil)
    }
}
