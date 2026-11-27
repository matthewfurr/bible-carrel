import Foundation
import Testing
@testable import ScriptureData

@Suite struct SearchQueryTests {
    private func t(_ words: String..., start: Bool = true, excluded: Bool = false) -> SearchQuery.Term {
        SearchQuery.Term(words: words, isWordStart: start, isExcluded: excluded)
    }
    private func terms(_ typed: String) -> [SearchQuery.Term] { SearchQuery(typed).terms }
    private func match(_ typed: String) -> String? { SearchQuery(typed).ftsMatch }

    @Test func eachRowOfTheTableParsesToItsTerms() {
        #expect(terms("remain fruit") == [t("remain"), t("fruit")])
        #expect(terms("  ABÍD ") == [t("abid")])                                    // case and accents ignored
        #expect(terms("\"living water\"") == [t("living", "water", start: false)])
        #expect(terms("love -fear") == [t("love"), t("fear", start: false, excluded: true)])
        #expect(terms("love -\"no man\"") == [t("love"), t("no", "man", start: false, excluded: true)])
        #expect(terms("beer-sheba") == [t("beer", "sheba")])                        // joined, not an exclusion
    }

    @Test func quotesOperatorsAndDashes() {
        #expect(terms("“living water”") == [t("living", "water", start: false)])
        #expect(terms("vine \"living wat") == [t("vine"), t("living", "wat", start: false)])   // left open: runs to the end
        #expect(terms("love OR fear") == [t("love"), t("or"), t("fear")])           // hand-typed operators are words
        #expect(terms("NOT NEAR(a b) spirit* text:lord").map(\.words) == [["not"], ["near", "a"], ["b"], ["spirit"], ["text", "lord"]])
        #expect(terms("- fear") == [t("fear")] && terms("--fear") == [t("fear", start: false, excluded: true)])
        #expect(terms("\"\" \"***\" * : - ()").isEmpty)
        #expect(match("-fear -\"no man\"") == nil && match("   ") == nil)           // exclusions alone find nothing
    }

    @Test func aWordWithAnApostropheIsItsPiecesSideBySideAndWhole() {
        for typed in ["peter's", "Peter’s"] { #expect(terms(typed) == [t("peter", "s", start: false)]) }
        #expect(terms("peter'") == [t("peter")])                                    // still being typed
    }

    @Test func theMatchStringIsExactlyThis() {
        #expect(match("remain fruit") == "\"remain\" * AND \"fruit\" *")
        #expect(match("\"living water\"") == "\"living water\"" && match("beer-sheba") == "\"beer sheba\" *")
        #expect(match("love -fear -\"no man\"") == "(\"love\" *) NOT (\"fear\" OR \"no man\")")
        #expect(match("peter's") == "\"peter s\"")
    }

    @Test func onlyLettersDigitsAndTheQuerysOwnMarksReachTheIndex() {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " \"*()"))
        for typed in ["\"; DROP TABLE verse; --", "a\u{0}b", "'' OR 1=1", "((((", "\"\"\"x", "NEAR/2 y", "col:x", "{a b}",
                      "x\\y", "😀 joy", "“I am the vine,” he said.\nAbide"] {
            let string = match(typed) ?? ""
            #expect(string.unicodeScalars.allSatisfy(allowed.contains), "\(typed) → \(string)")
            #expect(string.filter { $0 == "\"" }.count.isMultiple(of: 2), "\(typed)")
        }
        #expect(terms("e\u{301}t\u{e9}") == [t("ete")])
    }

    @Test func theMatcherAgreesWithTheGrammar() {
        let text = "Abiding in me, and I in you. He that abideth beareth much fruit; fear not."
        func found(_ typed: String) -> Bool { SearchQuery(typed).matches(text) }
        func bold(_ typed: String) -> [String] { SearchQuery(typed).matchRanges(in: text).map { String(text[$0]) } }
        #expect(found("fruit abid") && !found("bide"))                              // word starts, never inside a word
        #expect(found("\"much fruit\"") && !found("\"fruit much\"") && !found("\"much fru\"") && found("\"in me and\""))
        #expect(!found("abid -fear") && found("abid -fea") && !found("-fear") && !found(""))   // an exclusion is a whole word
        #expect(SearchQuery("love -fear").matches(anyOf: ["Greater love", "no man"]))
        #expect(!SearchQuery("love -fear").matches(anyOf: ["Greater love", "Fear not"]))
        #expect(!SearchQuery("love man").matches(anyOf: ["Greater love", "no man"]))   // one field holds them all
        #expect(bold("abid -fear") == ["Abiding", "abideth"] && bold("\"much fruit\" you") == ["you", "much", "fruit"])
        #expect(SearchQuery("abide frut").allowsSuggestion)
        for typed in ["\"abide\"", "abide -fear", "beer-sheba", "peter's", ""] { #expect(!SearchQuery(typed).allowsSuggestion, "\(typed)") }
    }
}
