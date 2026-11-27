import CoreGraphics
import ScriptureData
import Testing
@testable import ScriptureUI

/// The chart's model: bars packed into lanes, the year axis, the band and where a click lands (spec 6.5).
@Suite struct TimelineChartTests {
    private typealias Fixture = TimelineFixture
    private let year = 365.25

    private func timeline(years: [Int]) -> BookTimeline {
        let records = years.enumerated().map { Fixture.record($0.offset + 1, "Event \($0.offset)", year: $0.element) }
        return BookTimeline.make(records: records, passages: Fixture.passages(records.map(\.id)))
    }

    @Test func theChartNeedsDatesFiveRowsAndTwoYears() {
        let five = timeline(years: [-100, -90, -80, -70, -60])
        #expect(TimelineChartModel.shows(five, showingDates: true))
        #expect(!TimelineChartModel.shows(five, showingDates: false))
        #expect(!TimelineChartModel.shows(timeline(years: [-100, -90, -80, -70]), showingDates: true))
        #expect(!TimelineChartModel.shows(timeline(years: [-100, -100, -100, -100, -100]), showingDates: true))
    }

    @Test func livesPackIntoTheFirstFreeLane() {
        #expect(TimelineChartModel.lanes([0 ... 10, 5 ... 15, 10 ... 20]) == [0, 1, 0])
        let records = [Fixture.record(1, "Lifetime of A", year: 100, length: 10 * year), Fixture.record(2, "Lifetime of B", year: 105, length: 10 * year),
                       Fixture.record(3, "Lifetime of C", year: 110, length: 10 * year)]
        let model = TimelineChartModel(BookTimeline.make(records: records, passages: Fixture.passages([1, 2, 3])))
        #expect(model.bars.map(\.lane) == [0, 1, 0] && model.laneCount == 2)
    }

    @Test func pastTwelveLanesTheShortestBecomeTicks() {
        let records = (0 ..< 13).map { Fixture.record($0 + 1, "Lifetime of P\($0)", year: 1000 + ($0 == 0 ? 1 : 0), length: Double(100 + $0) * year) }
        let model = TimelineChartModel(BookTimeline.make(records: records, passages: Fixture.passages(records.map(\.id))))
        #expect(model.laneCount == 12 && model.bars.count == 12)
        #expect(!model.bars.contains { $0.id == 1 } && model.ticks.contains(1001))
    }

    @Test func yearsMapSoRoundTicksReadTrue() {
        #expect(TimelineChartModel.x(year: -3999) == -4000 && TimelineChartModel.x(year: 30) == 30)
        let wide: CGFloat = 2000, character: CGFloat = 6
        // The ends carry their era; between them only the first year of an era not yet named does.
        let bc = TimelineChartModel.axisMarks(domain: -4000 ... -3000, width: wide, characterWidth: character).map(\.label)
        #expect(bc.first == "4000 BC" && bc.last == "3000 BC" && bc.count > 3 && !bc.dropFirst().dropLast().contains { $0.contains("BC") })
        let ad = TimelineChartModel.axisMarks(domain: 30 ... 40, width: wide, characterWidth: character).map(\.label)
        #expect(ad.first == "AD 30" && ad.last == "AD 40" && ad.count > 3 && !ad.dropFirst().dropLast().contains { $0.contains("AD") })
        let both = TimelineChartModel.axisMarks(domain: -500 ... 500, width: wide, characterWidth: character).map(\.label)
        #expect(both.first == "500 BC" && both.last == "AD 500")
        #expect(both.dropFirst().dropLast().filter { $0.contains("AD") }.count == 1 && !both.dropFirst().contains { $0.contains("BC") })
    }

    @Test func theAxisNeverPrintsAYearZero() {
        // Matthew's and Luke's chart domains run from before the Common Era into it: NumberBins puts a threshold at 0.
        for domain in [-2000.0 ... 70, -3880 ... 40, -4004 ... 100, -6 ... 30.02] {
            let values = TimelineChartModel.axisValues(domain: domain)
            #expect(!values.isEmpty && !values.contains(0))
            let labels = TimelineChartModel.axisMarks(domain: domain, width: 640, characterWidth: 8).map(\.label)
            #expect(!labels.contains { $0 == "AD 0" || $0 == "0" }, "\(labels)")
        }
    }

    /// Matt's review, 2026-11-24: Matthew's axis read only "AD 10, 20, 30", so the band's start at the BC end read as
    /// nothing. Both ends are named in full, at the domain's own years, and a round year too near an end is left out.
    @Test func theAxisNamesBothEnds() throws {
        let matthew = TimelineChartModel.axisMarks(domain: -6 ... 30.021902806297057, width: 640, characterWidth: 8)
        #expect(matthew.map(\.label) == ["6 BC", "AD 10", "20", "AD 30"])
        #expect(matthew.first?.value == -6 && matthew.last?.value == 30.021902806297057)
        let genesis = TimelineChartModel.axisMarks(domain: -4004 ... -1491, width: 640, characterWidth: 8)
        #expect(genesis.map(\.label) == ["4004 BC", "3500", "3000", "2500", "2000", "1491 BC"])
        let acts = TimelineChartModel.axisMarks(domain: 30 ... 57, width: 640, characterWidth: 8)
        #expect(acts.first?.label == "AD 30" && acts.last?.label == "AD 57" && !acts.map(\.label).contains("55"))
        // A narrow chart keeps its two ends.
        let narrow = TimelineChartModel.axisMarks(domain: -6 ... 30, width: 90, characterWidth: 8)
        #expect(narrow.map(\.label) == ["6 BC", "AD 30"])
    }

    /// No two labels touch: each is laid as the chart lays it (the first hangs right of its year, the last left of
    /// its year, the rest centred on theirs), at least two characters apart, at the widths a chart is shown at.
    @Test func theAxisLabelsNeverCrowd() {
        let domains: [ClosedRange<Double>] = [-6 ... 30.02, -4004 ... -1491, 30 ... 57, 26 ... 30.02, -1534 ... -1101, -975 ... -440, -536 ... -440]
        for domain in domains {
            for width in stride(from: 120.0, through: 1200, by: 40) {
                let marks = TimelineChartModel.axisMarks(domain: domain, width: CGFloat(width), characterWidth: 8)
                #expect(marks.count >= 2)
                let spans = marks.enumerated().map { index, mark -> ClosedRange<CGFloat> in
                    let x = CGFloat((mark.value - domain.lowerBound) / (domain.upperBound - domain.lowerBound)) * CGFloat(width)
                    let labelWidth = CGFloat(mark.label.count) * 8
                    if index == 0 { return x ... x + labelWidth }
                    if index == marks.count - 1 { return x - labelWidth ... x }
                    return x - labelWidth / 2 ... x + labelWidth / 2
                }
                for (left, right) in zip(spans, spans.dropFirst()) where marks.count > 2 || width >= 160 {
                    #expect(right.lowerBound - left.upperBound >= 16, "\(domain) at \(width): \(marks.map(\.label))")
                }
            }
        }
    }

    /// A few rows far from the rest (Luke's two genealogy lives, Seth and Cainan, 3,800 years before its other
    /// rows) are left off the chart, which would otherwise squeeze every other row into its last 1%; the rail
    /// keeps them. A cluster that is more than a few (Matthew's eight birth rows, 30 years before the ministry) stays.
    @Test func aFewRowsFarFromTheRestAreLeftOffTheChart() {
        let far = [-3874, -3679] + Array(repeating: -6, count: 10) + Array(26 ... 30) + Array(repeating: 30, count: 30)
        let model = TimelineChartModel(timeline(years: far))
        #expect(model.domain.lowerBound == TimelineChartModel.x(year: -6))
        #expect(!model.ticks.contains(TimelineChartModel.x(year: -3874)))
        #expect(model.target(x: -4000, lane: nil) == .row(3))
        let matthew = Array(repeating: -5, count: 8) + Array(repeating: 28, count: 63)
        #expect(TimelineChartModel(timeline(years: matthew)).domain.lowerBound == TimelineChartModel.x(year: -5))
        // The band leaves a row off the chart out.
        #expect(TimelineChartModel.band(years: [-3874, -6, 0], domain: model.domain).map { $0.lowerBound >= model.domain.lowerBound } == true)
        #expect(TimelineChartModel.band(years: [-3874], domain: model.domain) == nil)
    }

    @Test(.needsRealBible) func lukesChartStartsAtItsOwnStory() throws {
        let store = try BenchmarkChapter.realStore()
        let luke = TimelineChartModel(try BookTimeline.load(book: "LUK", translationID: "ESV", store: store))
        #expect(luke.domain.lowerBound == -6 && !luke.bars.contains { $0.title == "Seth" || $0.title == "Cainan" })
        let matthew = TimelineChartModel(try BookTimeline.load(book: "MAT", translationID: "ESV", store: store))
        #expect(matthew.domain.lowerBound == -6)
        let genesis = TimelineChartModel(try BookTimeline.load(book: "GEN", translationID: "ESV", store: store))
        #expect(genesis.domain == -4004 ... -1491 && genesis.bars.count == 27 && genesis.laneCount == 10)
        let exodus = TimelineChartModel(try BookTimeline.load(book: "EXO", translationID: "ESV", store: store))
        #expect(exodus.domain.lowerBound == -1921)
        let acts = TimelineChartModel(try BookTimeline.load(book: "ACT", translationID: "ESV", store: store))
        #expect(acts.domain == 30 ... 57)
    }

    @Test func theBandSpansTheVisibleYears() throws {
        let domain = -4004.0 ... -1500
        let band = try #require(TimelineChartModel.band(years: [-2347, -2346], domain: domain))
        #expect(abs((band.lowerBound + band.upperBound) / 2 - -2347.5) < 1e-9)
        #expect(abs((band.upperBound - band.lowerBound) - 25.04) < 1e-9)
        let one = try #require(TimelineChartModel.band(years: [-2347], domain: domain))
        #expect(abs((one.upperBound - one.lowerBound) - 25.04) < 1e-9 && abs((one.lowerBound + one.upperBound) / 2 - -2348) < 1e-9)
        #expect(TimelineChartModel.band(years: [], domain: domain) == nil)
    }

    @Test func aClickOffEveryBarPicksTheNearestRow() {
        let records = [Fixture.record(1, "Lifetime of A", year: 0, length: 10 * year), Fixture.record(2, "Early", year: 100),
                       Fixture.record(3, "Late", year: 200)]
        let model = TimelineChartModel(BookTimeline.make(records: records, passages: Fixture.passages([1, 2, 3])))
        #expect(model.target(x: 5, lane: 0) == .bar(1))
        #expect(model.target(x: 5, lane: 1) == .row(1))
        #expect(model.target(x: 140, lane: 0) == .row(2) && model.target(x: 160, lane: nil) == .row(3))
        #expect(model.target(x: -500, lane: nil) == .row(1) && model.target(x: 900, lane: 0) == .row(3))
    }

    @Test(.needsRealBible) func aClickOnAdamPicksHimAndElsewhereTheNearestRow() throws {
        let timeline = try BookTimeline.load(book: "GEN", translationID: "ESV", store: BenchmarkChapter.realStore())
        let model = TimelineChartModel(timeline)
        let adam = try #require(model.bars.first { $0.id == 4 })
        #expect(model.target(x: adam.start + 1, lane: adam.lane) == .bar(4))
        let flood = TimelineChartModel.x(year: -2347)
        // A lane with no bar over the Flood's year.
        let emptyLane = try #require((0 ..< model.laneCount).first { lane in
            !model.bars.contains { $0.lane == lane && $0.start <= flood && flood <= $0.end }
        })
        #expect(model.target(x: flood, lane: emptyLane) == .row(38))
        #expect(model.target(x: -9000, lane: nil) == .row(timeline.entries.first?.id ?? -1))
        #expect(model.target(x: 9000, lane: nil) == .row(timeline.entries.last?.id ?? -1))
    }

    // MARK: The link to the rail's scroll (Task 7)

    @Test(.needsRealBible) func aClickScrollsToTheRowOrItsFold() throws {
        let genesis = try BookTimeline.load(book: "GEN", translationID: "ESV", store: BenchmarkChapter.realStore())
        let closed = TimelineItems.items(genesis, openFolds: [], showingDates: true)
        #expect(TimelineItems.scrollTarget(.bar(8), items: closed) == .fold(8))
        let open = TimelineItems.items(genesis, openFolds: [8], showingDates: true)
        #expect(TimelineItems.scrollTarget(.bar(8), items: open) == .entry(8))
        #expect(TimelineItems.scrollTarget(.bar(39), items: closed) == .era(39, occurrence: 0))
        #expect(TimelineItems.scrollTarget(.row(38), items: closed) == .entry(38))
    }

    @Test(.needsRealBible) func theVisibleRowsGiveTheBandsYears() throws {
        let genesis = try BookTimeline.load(book: "GEN", translationID: "ESV", store: BenchmarkChapter.realStore())
        let items = TimelineItems.items(genesis, openFolds: [], showingDates: true)
        #expect(TimelineItems.years(visible: [.entry(38), .entry(40), .era(39, occurrence: 0)], items: items) == [-2347, -2347])
        let fold = try #require(items.lazy.compactMap { item -> TimelineFold? in
            if case .fold(let fold, _, _) = item, fold.id == 8 { fold } else { nil }
        }.first)
        #expect(fold.lives.count == 8)
        #expect(TimelineItems.years(visible: [.fold(8)], items: items) == fold.lives.map(\.year))
    }
}
