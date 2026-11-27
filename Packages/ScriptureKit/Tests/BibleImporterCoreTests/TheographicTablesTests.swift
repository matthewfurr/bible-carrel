import Foundation
import Testing
@testable import BibleImporterCore

@Suite struct TheographicTablesTests {
    let fixture = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/Theographic")

    func byID<T>(_ list: [T]) -> [Int: T] where T: Identifiable, T.ID == Int {
        Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    @Test func yearsNamesTextAndPointsReadAsTheTablesWriteThem() {
        #expect(TheographicTables.year("-1995") == -1995 && TheographicTables.year("0030-05-01") == 30 && TheographicTables.year("57") == 57)
        #expect(TheographicTables.year("") == nil && TheographicTables.year("about 30") == nil)
        #expect(TheographicTables.shownName("Jacob (Israel)") == ("Jacob", "Israel") && TheographicTables.shownName("John the Baptist") == ("John the Baptist", nil))
        #expect(TheographicTables.plainText("A ([Rev. 1:8](/rev#Rev.1.8), [11](/rev#Rev.1.11)).\n\n \n\nB [sic]\nc.") == "A (Rev. 1:8, 11).\n\nB [sic] c.")
        #expect(TheographicTables.searchNames(["Simon Peter", "Simon", "Cephas"]) == " simon peter cephas")
        #expect(TheographicTables.pointKey(latitude: 31.777189, longitude: 35.234978) == "31.777,35.235")
        #expect(TheographicTables.pointKey(latitude: 31.777444, longitude: 35.234935) == "31.777,35.235")      // the seventy and Jerusalem
    }

    @Test func twoOfOneNameAreToldApartEvenWhenTheirLabelsMatch() {
        let labels = TheographicTables.labels([
            (1, "Azariah", nil, "son of Johanan", "1 Chronicles 6:10"), (2, "Azariah", nil, "son of Johanan", "Ezra 7:3"),
            (3, "Azariah", nil, nil, "Nehemiah 3:23"), (4, "Esau", "Edom", nil, "Genesis 25:25"), (5, "Noah", nil, "son of Lamech", "Genesis 5:29")])
        #expect(labels == [1: "son of Johanan, 1 Chronicles 6:10", 2: "son of Johanan, Ezra 7:3", 3: "Nehemiah 3:23", 4: "Edom"])
    }

    @Test func theFixturePeopleLandByTheirOwnIds() throws {
        var warnings: [ImportWarning] = []
        let people = byID(try TheographicTables.load(from: fixture, warnings: &warnings).people)
        #expect(people.count == 13 && people[905]?.name == "Jesus Christ" && people[905]?.label == nil)
        #expect(people[905]?.alsoCalled == ["Lord", "Son"] && people[905]?.birthYear == -3 && people[905]?.deathYear == 30)
        #expect(people[905]?.dictionary == "The proper name of our Lord (Matt. 1:21).\n\nHe was born at Bethlehem.")
        #expect(people[905]?.verses == [19002007, 40001001, 40001016, 40001018, 40002001, 40003013, 40004001])
        #expect(people[905]?.searchNames == " jesus christ lord son" && people[682]?.searchNames == " jacob israel")
        #expect(people[682]?.name == "Jacob" && people[682]?.label == "Israel" && people[682]?.alsoCalled == [])
        #expect(people[683]?.label == "father of Joseph" && people[1715]?.label == "Mary's Husband" && people[1710]?.label == "son of Jacob")
        #expect(people[1493]?.label == "Matthew 2:1" && people[1494]?.label == "Matthew 14:1" && people[994]?.label == nil)
        #expect(warnings.map(\.message) == [
            "Dropped a part-of link of event 40: recE00000000999 is not among the events",
            "Skipped writer moses_2108 of Gen: not among the people",
        ])
    }

    @Test func theFixturePlacesEventsFamiliesAndWriters() throws {
        var warnings: [ImportWarning] = []
        let tables = try TheographicTables.load(from: fixture, warnings: &warnings)
        let places = byID(tables.places), events = byID(tables.events)
        #expect(places.count == 9 && places[637] == nil)                                             // no verse: left out
        #expect(places[636]?.alsoCalled == ["Zion", "Jebus", "Salem", "City of God"] && places[636]?.kind == "city" && places[362]?.kind == "country")
        #expect(places[1263]?.alsoCalled == ["Sion"] && places[1263]?.point == places[636]?.point && places[979]?.kind == nil)
        #expect(places[978]?.isApproximate == true && places[979]?.isApproximate == true && places[882]?.isApproximate == false)
        #expect(places[978]?.label == "Matthew 2:18" && places[979]?.label == "1 Samuel 1:19" && places[636]?.label == nil)
        #expect(places[574]?.latitude == nil && places[1110]?.latitude == nil && places[1110]?.point == nil)   // none; Unlocated
        #expect(tables.events.map(\.id) == [1, 40, 88, 86, 107, 108, 102, 121, 126, 129, 300, 301, 302, 310, 311] && events[1]?.year == -4003 && events[311]?.year == 28)
        #expect(events[1]?.passages == [1_001_031...1_002_002])                                      // one run past the chapter's end
        #expect(events[300]?.passages == [40_001_018...40_001_020, 40_001_024...40_001_024, 42_002_001...42_002_001])
        #expect(tables.relations.count == 14 && tables.relations.filter { $0.personID == 1715 }.map { "\($0.kind) \($0.relativeID)" } == ["father 683", "partner 1938"])
        #expect(tables.writers == [.init(book: "PSA", ordinal: 0, personID: 994), .init(book: "PSA", ordinal: 1, personID: 2762), .init(book: "MAT", ordinal: 0, personID: 1971)])
    }

    @Test func everyLengthTheDataWritesIsRead() {
        #expect(TheographicTables.days("7D") == 7 && TheographicTables.days("930Y") == 930 * 365.25)
        #expect(TheographicTables.days("3M") == 3 * 30.44 && TheographicTables.days("1Y6M") == 365.25 + 6 * 30.44)
        #expect(TheographicTables.days("2M10D") == 2 * 30.44 + 10 && TheographicTables.days("1.5Y") == 1.5 * 365.25)
        #expect(TheographicTables.days("1W") == 7)
        for unread in ["", "Y", "3Q", "about 3Y", "1.2.3Y"] { #expect(TheographicTables.days(unread) == nil) }
    }

    @Test func lengthsPartOfAndALifesPerson() throws {
        var warnings: [ImportWarning] = []
        let events = byID(try TheographicTables.load(from: fixture, warnings: &warnings).events)
        #expect(events[86]?.durationDays == 147 * 365.25 && events[86]?.personID == 682)
        #expect(events[88]?.partOf == 86 && events[102]?.partOf == 86)
        #expect(events[129]?.partOf == 121)                                                          // two links keep the life
        #expect(events[121]?.personID == nil && events[40]?.partOf == nil && events[40]?.durationDays == 150)
        #expect(warnings.map(\.message).contains("Dropped a part-of link of event 40: recE00000000999 is not among the events"))
        #expect(!warnings.contains { $0.message.contains("length") })
    }

    @Test func theNamedCorrectionsApply() throws {
        var warnings: [ImportWarning] = []
        let events = byID(try TheographicTables.load(from: fixture, warnings: &warnings).events)
        #expect(events[129]?.passages == [5_034_001...5_034_001, 5_034_005...5_034_005])
        #expect(events[108]?.passages == [18_042_016...18_042_016])
        #expect(events[107]?.passages == [])
    }

    @Test func aCorrectionNoLongerNeededWarnsAndDoesNothing() {
        var warnings: [ImportWarning] = []
        let verses = [(position: 0, key: 5_034_001)]
        let unchanged = TheographicCorrections.apply(TheographicCorrections.all, toEvent: 129, verses: verses, warnings: &warnings)
        #expect(unchanged.map(\.key) == [5_034_001] && unchanged.map(\.position) == [0])
        #expect(warnings.map(\.message) == ["Correction \"Death of Moses is not in Genesis\" is no longer needed: event 129 has no Genesis 34:1"])
        var quiet: [ImportWarning] = []
        let other = TheographicCorrections.apply(TheographicCorrections.all, toEvent: 1, verses: verses, warnings: &quiet)
        #expect(other.map(\.key) == [5_034_001] && quiet.isEmpty)
    }

    @Test func anUnreadLengthWarnsAndIsNil() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.copyItem(at: fixture, to: folder)
        let file = folder.appendingPathComponent("events.json")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("\"duration\": \"150D\""))
        try text.replacingOccurrences(of: "\"duration\": \"150D\"", with: "\"duration\": \"3Q\"").write(to: file, atomically: true, encoding: .utf8)
        var warnings: [ImportWarning] = []
        let events = byID(try TheographicTables.load(from: folder, warnings: &warnings).events)
        #expect(events[40]?.durationDays == nil)
        #expect(warnings.map(\.message).contains("Event 40 (Water covers the earth): its length \"3Q\" is not read"))
    }
}

extension TheographicTables.Person: Identifiable {}
extension TheographicTables.Place: Identifiable {}
extension TheographicTables.Event: Identifiable {}
