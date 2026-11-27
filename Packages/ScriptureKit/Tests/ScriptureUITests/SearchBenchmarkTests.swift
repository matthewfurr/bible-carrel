#if os(macOS)
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite(.serialized) struct SearchBenchmarkTests {
    /// Spec 4.5: a common word in the whole Bible returns its first rows and its count within 50 ms, debug build.
    @Test(.needsRealBible) func aCommonWordInTheWholeBibleIsWithinFiftyMilliseconds() throws {
        let store = try BenchmarkChapter.realStore()
        var page = SearchPage.empty
        let median = ReaderBenchmarkTests.median("search-lord-ESV") {
            page = (try? store.search(SearchQuery("lord"), translationID: "ESV", limit: 20)) ?? .empty
        }
        #expect(page.verses.count == 20 && page.total > 6000 && median < .milliseconds(50))
    }
}
#endif
