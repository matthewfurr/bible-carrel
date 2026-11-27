import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct FrontPageSearchTests {
    private func books() throws -> [TranslationBook] {
        let name = "FrontPageSearchTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return try NavigationModel(store: FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "WEB").books
    }

    @Test func anEmptyQueryListsEveryBook() throws {
        let results = FrontPageSearch.results(query: "  ", books: try books())
        #expect(results.reference == nil)
        #expect(results.books.map(\.book.id) == ["PSA", "MAT", "TOB"])
    }

    @Test func aPrefixFiltersBooks() throws {
        #expect(FrontPageSearch.results(query: "ma", books: try books()).books.map(\.book.id) == ["MAT"])
    }

    @Test func aReferenceOffersGoToAndKeepsItsBookFirst() throws {
        let results = FrontPageSearch.results(query: "Ps 2", books: try books())
        #expect(results.reference?.displayString == "Psalm 2")
        #expect(results.books.first?.book.id == "PSA")
    }

    @Test func aReferencePastTheBookEndOffersNoGoTo() throws {
        let results = FrontPageSearch.results(query: "Matt 99", books: try books())
        #expect(results.reference == nil)
        #expect(results.books.map(\.book.id) == ["MAT"])
    }

    @Test func aHalfTypedReferenceStillListsItsBook() throws {
        let results = FrontPageSearch.results(query: "Matt 5:", books: try books())
        #expect(results.reference == nil)
        #expect(results.books.map(\.book.id) == ["MAT"])
    }

    @Test func aParsedBookThatAlsoMatchesIsListedOnce() throws {
        #expect(FrontPageSearch.results(query: "Matt", books: try books()).books.map(\.book.id) == ["MAT"])
    }
}
