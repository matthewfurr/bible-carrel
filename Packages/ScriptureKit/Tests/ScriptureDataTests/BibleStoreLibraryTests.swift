import Foundation
import Testing
@testable import ScriptureData

@Suite struct BibleStoreLibraryTests {
    private var store: BibleStore { get throws { try BibleStore(databaseURL: try FixtureDatabase.build()) } }
    private func mt(_ chapter: Int, _ verse: Int) -> VerseLocation { VerseLocation(book: "MAT", chapter: chapter, verse: verse) }

    @Test func aBooksPeopleComeMostVersesFirstWithTheirCounts() throws {
        let people = try store.people(inBook: "MAT")
        #expect(people.map(\.id) == [905, 1715, 1938, 1493, 2762, 994, 683, 903, 1971, 1494, 616, 682])
        #expect(people.map(\.verseCount) == [6, 6, 4, 3, 3, 2, 2, 2, 2, 1, 1, 1])
        #expect(try store.people(inBook: "PSA").map(\.id) == [994, 682, 905, 1710] && store.people(inBook: "TOB").isEmpty)
        #expect(try store.person(905)?.verseCount == 7 && store.person(99) == nil)
    }

    @Test func aPersonsFamilyVersesAndABooksWritersReadByTheirIds() throws {
        func family(_ id: Int) throws -> [String] { try store.relatives(of: id).map { "\($0.kind.rawValue) \($0.person.id)" } }
        #expect(try family(1715) == ["father 683", "partner 1938"] && family(682) == ["father 616", "child 1710"] && family(1493).isEmpty)
        #expect(try store.verses(ofPerson: 994) == [VerseLocation(book: "PSA", chapter: 18, verse: 50), mt(1, 1), mt(1, 6)])
        #expect(try store.writers(ofBook: "PSA").map(\.id) == [994, 2762] && store.writers(ofBook: "GEN").isEmpty)
        #expect(try FixtureDatabase.tinyStore([("ERV", 11, nil), ("ERV", 12, 13)]).verseCount(ofBook: "JHN", translationID: "ERV") == 3)
    }

    /// The parents of many people in one read: each id's father before its mother, an id with neither absent.
    @Test func parentsOfManyAreOneRead() throws {
        let parents = try store.parents(of: [1710, 905, 1493])
        #expect(parents.keys.sorted() == [905, 1710])
        #expect(parents[1710]?.map { "\($0.kind.rawValue) \($0.person.id)" } == ["father 682"])
        #expect(parents[905]?.map { "\($0.kind.rawValue) \($0.person.id)" } == ["mother 1938"])
        #expect(try store.parents(of: []).isEmpty)
    }

    /// A book's places by chapter in one read: each place's verses counted per chapter, chapters in order, a
    /// chapter's places by their first verse then id; nothing outside the 66.
    @Test func aBooksPlacesByChapterAreOneRead() throws {
        let rows = try store.placeChapters(inBook: "MAT")
        #expect(rows.count == 11)
        #expect(rows.prefix(8).map { "\($0.placeID):\($0.chapter):\($0.firstVerse):\($0.verseCount)" }
                == ["218:2:1:5", "636:2:1:2", "362:2:13:4", "978:2:18:1", "882:2:23:1", "882:4:13:1", "636:4:25:1", "636:5:35:1"])
        #expect(try store.placeChapters(inBook: "TOB").isEmpty && store.placeChapters(inBook: "XYZ").isEmpty)
    }

    @Test func placesAndEventsReadForABook() throws {
        let places = try store.placesNamed(inBook: "MAT")
        #expect(places.map(\.id) == [218, 362, 636, 882, 574, 978, 1110, 1263] && places.map(\.verseCount) == [5, 4, 4, 2, 1, 1, 1, 1])
        #expect(try store.places(sharingPointWith: 636, inBook: "MAT").map(\.id) == [1263] && store.places(sharingPointWith: 218, inBook: nil).isEmpty)
        #expect(try store.places(sharingPointWith: 574, inBook: nil).isEmpty)                    // no point: shares none
        let events = try store.events(inBook: "MAT")
        #expect(events.map(\.id) == [300, 301, 302, 310, 311] && events.map(\.year) == [-4, -3, -3, 26, 28])
        #expect(events[0].start == mt(1, 18) && events[0].end == mt(1, 20))                      // its first passage in the book
        #expect(try store.events(inBook: "GEN").first?.end == VerseLocation(book: "GEN", chapter: 2, verse: 2) && store.events(inBook: "PSA").isEmpty)
    }

    @Test func eventRecordsCarryTheirLengthAndLinks() throws {
        let records = try store.eventRecords()
        #expect(records.count == 15 && records.map(\.sortKey) == records.map(\.sortKey).sorted())
        let jacobsBirth = try #require(records.first { $0.id == 88 })
        #expect(jacobsBirth.partOf == 86 && jacobsBirth.durationDays == 1 && jacobsBirth.personID == nil)
        let jacob = try #require(records.first { $0.id == 86 })
        #expect(jacob.durationDays == 147 * 365.25 && jacob.personID == 682 && jacob.year == -1835)
        let genesis = try store.events(inBook: "GEN").map(\.id)
        #expect(!genesis.contains(107) && !genesis.contains(108) && !genesis.contains(129))
        #expect(try store.events(inBook: "DEU").map(\.id) == [121, 126, 129])
    }

    /// The last verse of each chapter in one read: a joined verse ends at its last ("12-13" is 13).
    @Test func aChaptersLastVerseIsItsLastRowsEnd() throws {
        let tiny = try FixtureDatabase.tinyStore([("ERV", 11, nil), ("ERV", 12, 13), ("KJV", 15, nil), ("KJV", 16, nil)])
        #expect(try tiny.lastVerses(ofBook: "JHN", translationID: "ERV") == [3: 13])
        #expect(try tiny.lastVerses(ofBook: "JHN", translationID: "KJV") == [3: 16])
        #expect(try tiny.lastVerses(ofBook: "MAT", translationID: "ERV").isEmpty && tiny.lastVerses(ofBook: "JHN", translationID: "WEB").isEmpty)
    }

    @Test func namesAreFoundByTheStartOfAWordAndNothingElse() throws {
        #expect(try store.searchPeople("jac", limit: 4).rows.map(\.id) == [682, 683] && store.searchPeople("isr", limit: 4).rows.map(\.id) == [682])
        #expect(try store.searchPeople("LORD", limit: 4).rows.map(\.id) == [905] && store.searchPeople("jesus chr", limit: 4).rows.map(\.id) == [905])
        let joseph = try store.searchPeople("jos", limit: 1)
        #expect(joseph.rows.map(\.id) == [1715] && joseph.total == 2)
        #expect(try store.searchPeople("sus", limit: 4).total == 0)                              // not from inside a word
        for nothing in ["j", "%", "_", "  ", "'", "%%", "__", "_%"] { #expect(try store.searchPeople(nothing, limit: 4) == .none) }
        #expect(try store.searchPlaces("sal", limit: 4).rows.map(\.id) == [636] && store.searchPlaces("sion", limit: 4).rows.map(\.id) == [1263])
        #expect(try store.searchPlaces("ram", limit: 4).rows.map(\.label) == ["Matthew 2:18", "1 Samuel 1:19"])
    }

    @Test func aPersonsAndAPlacesRecordsCarryTheirOwnFields() throws {
        let jesus = try #require(try store.person(905))
        #expect(jesus.name == "Jesus Christ" && jesus.alsoCalled == ["Lord", "Son"] && jesus.birthYear == -3 && jesus.deathYear == 30)
        #expect(jesus.dictionary?.hasPrefix("The proper name of our Lord") == true)
        let jerusalem = try #require(try store.place(636))
        #expect(jerusalem.summary.kind == "city" && jerusalem.alsoCalled == ["Zion", "Jebus", "Salem", "City of God"] && jerusalem.summary.point == "31.777,35.235")
        #expect(try store.place(99) == nil && store.place(574)?.summary.latitude == nil)
        #expect(try store.verses(ofPlace: 978) == [mt(2, 18)])
    }
}
