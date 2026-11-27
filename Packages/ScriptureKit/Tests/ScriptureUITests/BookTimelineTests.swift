import ScriptureData
import Testing
@testable import ScriptureUI

/// Event records and passages built in code, shared by the timeline's tests.
enum TimelineFixture {
    static let genesis = BookCatalog.book(code: "GEN")!

    /// Sort keys follow ids.
    static func record(_ id: Int, _ title: String, year: Int = -4000, length: Double? = nil, partOf: Int? = nil, person: Int? = nil) -> EventRecord {
        EventRecord(id: id, title: title, year: year, sortKey: Double(id), durationDays: length, partOf: partOf, personID: person)
    }

    static func passage(_ chapter: Int, _ verse: Int, in book: Book = genesis) -> Reference {
        Reference(book: book, chapter: chapter, verse: verse)
    }

    /// A passage for each id, at chapter 1 and the id's verse.
    static func passages(_ ids: [Int], in book: Book = genesis) -> [Int: Reference] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, passage(1, $0, in: book)) })
    }
}

@Suite struct BookTimelineTests {
    private typealias Fixture = TimelineFixture
    private let year = 365.25

    @Test func birthsAndDeathsFoldIntoTheirLives() {
        var records: [EventRecord] = []
        for (index, name) in ["Adam", "Seth", "Enos"].enumerated() {
            let life = 10 + index * 3
            records += [Fixture.record(life, "Lifetime of \(name)", length: 900 * year, person: index + 1),
                        Fixture.record(life + 1, "Birth of \(name)", partOf: life), Fixture.record(life + 2, "Death of \(name)", partOf: life)]
        }
        records += [Fixture.record(30, "Lifetime of Enoch", partOf: nil), Fixture.record(31, "Enoch taken up", partOf: 30)]
        let timeline = BookTimeline.make(records: records, passages: Fixture.passages(records.map(\.id)))
        #expect(timeline.entries.map(\.title) == ["Adam", "Seth", "Enos", "Enoch", "Enoch taken up"])
        #expect(timeline.lifeCount == 4 && timeline.eventCount == 1 && timeline.eras.isEmpty)
    }

    @Test func anEventWithChildrenInsideALifeIsARow() {
        let records = [Fixture.record(1, "Lifetime of Joseph"), Fixture.record(2, "Joseph Promoted in Egypt", partOf: 1),
                       Fixture.record(3, "7 years of plenty", partOf: 2)]
        let timeline = BookTimeline.make(records: records, passages: Fixture.passages([1, 2, 3]))
        #expect(timeline.entries.map(\.title) == ["Joseph", "Joseph Promoted in Egypt", "7 years of plenty"])
        #expect(timeline.entries.allSatisfy { $0.era == nil && !$0.isEra } && timeline.eras.isEmpty)
    }

    @Test func anEraGroupsItsChildren() {
        let records = [Fixture.record(1, "The Great Flood", year: -2347, length: year), Fixture.record(2, "Flood begins", partOf: 1),
                       Fixture.record(3, "Ark rests", partOf: 1), Fixture.record(4, "Dry land", partOf: 1)]
        let timeline = BookTimeline.make(records: records, passages: Fixture.passages([1, 2, 3, 4]))
        #expect(timeline.entries.map(\.title) == ["Flood begins", "Ark rests", "Dry land"])
        #expect(timeline.entries.allSatisfy { $0.era == 1 && !$0.isEra } && timeline.eras[1]?.title == "The Great Flood")
        #expect(timeline.eras[1]?.passage == Fixture.passage(1, 1))
    }

    @Test func anEraWithinAnEraFlattensIntoTheOuter() {
        let records = [Fixture.record(1, "Return from Exile"), Fixture.record(2, "Construction of the Second Temple", partOf: 1),
                       Fixture.record(3, "Foundation laid", partOf: 2), Fixture.record(4, "Temple finished", partOf: 2)]
        let timeline = BookTimeline.make(records: records, passages: Fixture.passages([1, 2, 3, 4]))
        #expect(timeline.entries.map(\.title) == ["Construction of the Second Temple", "Foundation laid", "Temple finished"])
        #expect(timeline.entries.allSatisfy { $0.era == 1 } && timeline.entries.first?.isEra == true && Array(timeline.eras.keys) == [1])
    }

    @Test func anEraWithOnlyItsOwnPassageIsOneRow() {
        let records = [Fixture.record(1, "Sojourn in Canaan and Egypt", length: 430 * year), Fixture.record(2, "Abraham arrives", partOf: 1)]
        let timeline = BookTimeline.make(records: records, passages: [1: Fixture.passage(12, 40)])
        let entry = timeline.entries.first
        #expect(timeline.entries.count == 1 && entry?.kind == .event && entry?.isEra == true && entry?.era == nil)
        #expect(entry?.title == "Sojourn in Canaan and Egypt" && entry?.lengthDays == 430 * year && timeline.eras.isEmpty)
    }

    @Test func deathOfMosesSitsInMosesLife() {
        let records = [Fixture.record(1, "Lifetime of Moses", person: 9), Fixture.record(2, "Death of Moses", partOf: 1)]
        let both = BookTimeline.make(records: records, passages: Fixture.passages([1, 2]))
        #expect(both.entries.map(\.title) == ["Moses"] && both.lifeCount == 1)
        let deathOnly = BookTimeline.make(records: records, passages: [2: Fixture.passage(34, 5)])
        #expect(deathOnly.entries.map(\.title) == ["Moses"] && deathOnly.entries.first?.passage == Fixture.passage(34, 5))
    }

    @Test func aLifeLinksToItsParticipant() {
        let records = [Fixture.record(1, "Lifetime of Adam", person: 78), Fixture.record(2, "Lifetime of Cainan")]
        let timeline = BookTimeline.make(records: records, passages: Fixture.passages([1, 2]))
        #expect(timeline.entries.map(\.kind) == [.life(personID: 78), .life(personID: nil)])
    }

    @Test func theCountLineCountsLivesAndEventRowsOnly() {
        let records = [Fixture.record(1, "Lifetime of A"), Fixture.record(2, "Birth of A", partOf: 1), Fixture.record(3, "Death of A", partOf: 1),
                       Fixture.record(4, "Lifetime of B"), Fixture.record(5, "Era"), Fixture.record(6, "E1", partOf: 5),
                       Fixture.record(7, "E2", partOf: 5), Fixture.record(8, "E3")]
        let timeline = BookTimeline.make(records: records, passages: Fixture.passages(records.map(\.id)))
        #expect(timeline.countLine == "2 lives, 3 events")
        #expect(BookTimeline.make(records: records, passages: Fixture.passages([1])).countLine == "1 life")
        #expect(BookTimeline.make(records: [Fixture.record(8, "E3")], passages: Fixture.passages([8])).countLine == "1 event")
        let many = (1 ... 78).map { Fixture.record($0, "Event \($0)") }
        #expect(BookTimeline.make(records: many, passages: Fixture.passages(many.map(\.id))).countLine == "78 events")
        #expect(BookTimeline.make(records: records, passages: [:]).countLine == nil)
    }

    @Test func yearsCoverEveryRecordWithAPassageFoldedOnesIncluded() {
        let records = [Fixture.record(1, "Lifetime of A", year: -4003), Fixture.record(2, "Death of A", year: -3073, partOf: 1)]
        #expect(BookTimeline.make(records: records, passages: [2: Fixture.passage(5, 5)]).years == -3073 ... -3073)
        #expect(BookTimeline.make(records: records, passages: Fixture.passages([1, 2])).years == -4003 ... -3073)
        #expect(BookTimeline.make(records: records, passages: [:]).years == nil)
    }

    @Test func wordsForYearsAndLengths() {
        #expect(LibraryYear.bare(-2347) == "2348 BC" && LibraryYear.bare(30) == "AD 30" && LibraryYear.text(30) == "about AD 30")
        #expect(LibraryYear.spans(-4003 ... -1634) == "about 4004 to 1635 BC" && LibraryYear.spans(30 ... 57) == "about AD 30 to 57")
        #expect(LibraryYear.spans(-1920 ... 49) == "about 1921 BC to AD 49" && LibraryYear.spans(-1054 ... -1054) == "about 1055 BC")
        let texts: [(Double, String)] = [(1, "one day"), (7, "7 days"), (150, "150 days"), (91.32, "3 months"), (101.32, "3 months"),
                                         (30.44, "one month"), (365.25, "one year"), (14610, "40 years"), (913.125, "2.5 years"),
                                         (930 * year, "930 years"), (0.5, "one day"), (3.25, "3 days")]
        for (days, text) in texts { #expect(LibraryLength.text(days: days) == text, "\(days)") }
    }

    @Test func rowsReadTheirDetailHeaderAndSpokenForms() {
        let records = [Fixture.record(1, "Lifetime of Adam", year: -4003, length: 930 * year), Fixture.record(2, "The Great Flood", year: -2347, length: year),
                       Fixture.record(3, "The Great Flood begins", year: -2347, length: 1, partOf: 2),
                       Fixture.record(4, "The waters prevail", year: -2347, length: 150, partOf: 2), Fixture.record(5, "Lifetime of Nobody")]
        var passages = Fixture.passages([1, 2, 3, 4, 5])
        passages[3] = Fixture.passage(7, 6)
        let timeline = BookTimeline.make(records: records, passages: passages)
        let byTitle = Dictionary(uniqueKeysWithValues: timeline.entries.map { ($0.title, $0) })
        let adam = byTitle["Adam"]!, begins = byTitle["The Great Flood begins"]!, prevail = byTitle["The waters prevail"]!
        #expect(adam.endYear == -3073 && byTitle["Nobody"]?.endYear == nil)
        #expect(adam.detail(showingDates: true) == "lived 930 years · to 3074 BC" && adam.detail(showingDates: false) == "lived 930 years")
        #expect(byTitle["Nobody"]?.detail(showingDates: true) == nil && begins.detail(showingDates: true) == nil)
        #expect(prevail.detail(showingDates: false) == "150 days" && begins.endYear == nil)
        let flood = timeline.eras[2]!
        #expect(flood.header(showingDates: true) == "The Great Flood · 2348 BC, one year" && flood.header(showingDates: false) == "The Great Flood")
        #expect(begins.spoken(showingDates: true) == "2348 BC, The Great Flood begins, Genesis 7:6")
        #expect(begins.spoken(showingDates: false) == "The Great Flood begins, Genesis 7:6")
        #expect(prevail.spoken(showingDates: true) == "2348 BC, The waters prevail, Genesis 1:4, 150 days")
        #expect(adam.spoken(showingDates: true) == "Adam, lived 930 years, to 3074 BC" && adam.spoken(showingDates: false) == "Adam, lived 930 years")
        #expect(flood.spoken(showingDates: true) == "The Great Flood, 2348 BC, one year" && flood.spoken(showingDates: false) == "The Great Flood")
    }
}
