import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct LibraryOrderTests {
    private var matthew: BookPeople {
        get throws { try #require(try BookPeople.load(book: "MAT", store: FixtureStore.make())) }
    }

    @Test func aToZSortsByNameThenLabelThenID() throws {
        let people = try matthew
        let sorted = people.rows(.alphabetical)
        let names = sorted.map(\.person.name)
        let expected = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        #expect(names == expected && sorted.count == 12)
        let herods = sorted.filter { $0.person.name == "Herod" }.map { $0.person.label ?? "" }
        #expect(herods == ["Matthew 2:1", "Matthew 14:1"])
        let jacobs = sorted.filter { $0.person.name == "Jacob" }.map { $0.person.label ?? "" }
        #expect(jacobs == ["father of Joseph", "Israel"])
        #expect(people.rows(.mostNamed) == people.rows && people.rowsByName == sorted)
        #expect(people.countLabel(.alphabetical) == "12 named · by name" && people.countLabel(.mostNamed) == "12 named · by mentions")
    }

    @Test func upAndDownFollowTheOrderShown() {
        #expect(LibraryPeopleView.neighbour(of: 7, step: 1, in: [3, 7, 5]) == 5)
        #expect(LibraryPeopleView.neighbour(of: nil, step: 1, in: [3, 7, 5]) == 3)
        #expect(LibraryPeopleView.neighbour(of: nil, step: -1, in: [3, 7, 5]) == 5)
        #expect(LibraryPeopleView.neighbour(of: 5, step: 1, in: [3, 7, 5]) == nil)
        #expect(LibraryPeopleView.neighbour(of: 3, step: -1, in: [3, 7, 5]) == nil)
        #expect(LibraryPeopleView.neighbour(of: nil, step: 1, in: [Int]()) == nil)
    }

    @MainActor @Test func theOrderIsKeptOnThisDeviceOnly() {
        #expect(PeopleOrder.key == "libraryPeopleOrder")
        #expect(!SyncedPreferences.keys.contains(PeopleOrder.key))
        #expect(PeopleOrder(rawValue: "alphabetical") == .alphabetical && PeopleOrder(rawValue: "mostNamed") == .mostNamed)
        #expect(PeopleOrder.allCases.map(\.title) == ["Most named", "A to Z"])
    }

    @Test func theChosenPersonStaysChosenInBothOrders() throws {
        let people = try matthew
        let first = try #require(people.rows.first).id
        for order in PeopleOrder.allCases {
            let rows = people.rows(order)
            #expect(LibraryPeopleView.chosenID(showing: .person(first), in: rows) == first)
            #expect(LibraryPeopleView.chosenID(showing: .person(-1), in: rows) == nil)
            #expect(LibraryPeopleView.chosenID(showing: .place(first), in: rows) == nil)
            #expect(LibraryPeopleView.chosenID(showing: nil, in: rows) == nil)
        }
    }
}
