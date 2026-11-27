import Testing
@testable import ScriptureData

@Suite struct SpellingSuggesterTests {
    let list: [WordCount] = [("abide", 77), ("abode", 40), ("able", 30), ("fruit", 183), ("fret", 4), ("from", 4330),
                             ("lord", 6694), ("led", 80), ("jerusalem", 600)].map { WordCount(word: $0.0, verses: $0.1) }

    func queries(_ typed: String) -> [String] { SpellingSuggester.queries(for: SearchQuery(typed), in: list) }

    @Test func theAllowanceGrowsWithTheWordAndASwapIsOneEdit() {
        #expect(["a", "abc", "abcd", "abcdef", "abcdefg", "jerusalem"].map(SpellingSuggester.allowance) == [1, 1, 2, 2, 3, 3])
        #expect(SpellingSuggester.distance("frut", "fruit", limit: 3) == 1 && SpellingSuggester.distance("teh", "the", limit: 3) == 1)
        #expect(SpellingSuggester.distance("abide", "fruit", limit: 3) == nil)
    }

    @Test func aMisspellingOffersTheNearestThenTheCommoner() {
        #expect(queries("frut") == ["fruit", "fret", "from"])                       // 1 and 1 (fruit is commoner), then 2
        #expect(queries("lrd") == ["lord", "led"])                                  // three letters: one change only
        #expect(queries("abibe") == ["abide", "abode", "able"] && queries("jerusalm") == ["jerusalem"])
        #expect(queries("abibe frut") == ["abide fruit", "abide fret", "abode fruit", "abide from", "abode fret"])
        #expect(queries("abide frut").first == "abide fruit")                       // a known word stays
    }

    @Test func nothingIsOfferedForQuotesExclusionsNumbersOrStrangers() {
        for typed in ["\"frut\"", "frut -vine", "abide fruit", "abid", "qqqqzz", "frut 144000", "john 3:16", "frut's", ""] {
            #expect(queries(typed).isEmpty, "\(typed)")
        }
    }

    /// A misspelling is a short query; a pasted passage is not, and is offered nothing.
    @Test func aQueryOfMoreThanTwelveTermsIsOfferedNothing() {
        let twelve = Array(repeating: "frut", count: SpellingSuggester.maximumTerms)
        let offered = queries(twelve.joined(separator: " "))
        #expect(offered.count == 5 && offered.first == Array(repeating: "fruit", count: 12).joined(separator: " "))
        #expect(queries((twelve + ["frut"]).joined(separator: " ")).isEmpty)
    }

    /// Thirty repeats of one misspelt word: 3^30 combinations before the bound, nothing now.
    @Test func aPastedPassageIsOfferedNothing() {
        #expect(queries(Array(repeating: "frut", count: 30).joined(separator: " ")).isEmpty)
    }

    /// The cheapest choices come in the order of the whole product sorted by sum, then by the earlier
    /// word's place, and no more of them than asked for are ever made.
    @Test func theCheapestChoicesComeInOrderAndStopAtTheLimit() {
        let counts = [3, 1, 2, 3]
        var product: [[Int]] = [[]]
        for count in counts { product = product.flatMap { places in (0..<count).map { places + [$0] } } }
        product.sort {
            let (x, y) = ($0.reduce(0, +), $1.reduce(0, +))
            return x != y ? x < y : $0.lexicographicallyPrecedes($1)
        }
        #expect(SpellingSuggester.cheapestPlaces(counts: counts, limit: 100) == product)
        #expect(SpellingSuggester.cheapestPlaces(counts: counts, limit: 7) == Array(product.prefix(7)))
        let twelve = SpellingSuggester.cheapestPlaces(counts: Array(repeating: 3, count: 12), limit: 5)
        #expect(twelve.count == 5 && twelve.first == Array(repeating: 0, count: 12))
        #expect(SpellingSuggester.cheapestPlaces(counts: [3, 3], limit: 0).isEmpty)
    }
}
