#if os(macOS)
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite(.serialized) struct CrossReferenceBenchmarkTests {
    /// Spec 10: both lists for John 3:16 within 20 ms, debug build.
    @Test(.needsRealBible) func bothListsForJohn316AreWithinTwentyMilliseconds() throws {
        let store = try BenchmarkChapter.realStore()
        var lists: CrossReferences?
        let median = ReaderBenchmarkTests.median("crossrefs-JHN-3-16-ESV") {
            lists = try? CrossReferences.load(VerseLocation(book: "JHN", chapter: 3, verse: 16), translationID: "ESV", store: store)
        }
        #expect(lists?.pointsTo.count == 23 && lists?.pointsHere.count == 104 && median < .milliseconds(20))
    }
}
#endif
