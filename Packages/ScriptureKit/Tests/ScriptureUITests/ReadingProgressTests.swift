import Foundation
import Testing
@testable import ScriptureUI

/// The progress line's rule, shared by the Mac's and the phone's readers.
@Suite struct ReadingProgressTests {
    private let top = ReadingProgress.topThreshold(verticalInset: 32, scrollLeadIn: 8)

    @Test func theTopIsTheInsetLessTheLeadIn() {
        #expect(top == 24)
    }

    @Test func zeroAtTheTopAndWithinTheThreshold() {
        #expect(ReadingProgress.fraction(offset: 0, scrollable: 1000, topThreshold: top) == 0)
        #expect(ReadingProgress.fraction(offset: 24, scrollable: 1000, topThreshold: top) == 0)
        #expect(ReadingProgress.fraction(offset: 25, scrollable: 1000, topThreshold: top) == 0.025)
    }

    @Test func theShareOfTheScrollableDistanceInBetween() {
        #expect(ReadingProgress.fraction(offset: 500, scrollable: 1000, topThreshold: top) == 0.5)
        #expect(ReadingProgress.fraction(offset: 1000, scrollable: 1000, topThreshold: top) == 1)
    }

    @Test func anOverscrollReadsAsTheNearestEnd() {
        #expect(ReadingProgress.fraction(offset: 1080, scrollable: 1000, topThreshold: top) == 1)
        #expect(ReadingProgress.fraction(offset: -60, scrollable: 1000, topThreshold: top) == 0)
    }

    @Test func zeroWhenTheChapterFits() {
        #expect(ReadingProgress.fraction(offset: 30, scrollable: 0, topThreshold: top) == 0)
        #expect(ReadingProgress.fraction(offset: 30, scrollable: -200, topThreshold: top) == 0)
    }

    @Test func reportsAHalfPercentStepAndAlwaysTheEnds() {
        #expect(!ReadingProgress.shouldReport(0.5, after: 0.5))
        #expect(!ReadingProgress.shouldReport(0.503, after: 0.5))
        #expect(ReadingProgress.shouldReport(0.505, after: 0.5))
        #expect(ReadingProgress.shouldReport(1, after: 0.998))
        #expect(ReadingProgress.shouldReport(0, after: 0.002))
    }
}
