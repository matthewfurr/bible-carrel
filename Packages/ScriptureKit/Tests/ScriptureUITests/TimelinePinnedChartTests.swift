import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// Matt's review, 2026-11-24: the Mac's chart pins at the top of the page while the rail scrolls under it, and its
/// band spans the rows in view under it, earliest to latest, in both directions. Geometry is in the page's content
/// space: the rail's rows keep their frames there as they are laid out, and only the visible rect moves with a scroll.
@Suite struct TimelinePinnedChartTests {
    private typealias Fixture = TimelineFixture

    /// Rows 1 to 20, 50 pt each, from the rail's top at 800; row n's year is -2000 + 10 n.
    private let rows: [TimelineItemID: ClosedRange<CGFloat>] = Dictionary(uniqueKeysWithValues: (1 ... 20).map { n in
        (TimelineItemID.entry(n), CGFloat(800 + 50 * (n - 1)) ... CGFloat(800 + 50 * n))
    })
    private let items = (1 ... 20).map { TimelineItem.entry(Fixture.record($0, "E\($0)", year: -2000 + 10 * $0).asEntry, yearLabel: nil) }
    private let railTop: CGFloat = 800, railBottom: CGFloat = 1800, chartHeight: CGFloat = 200

    private func foot(_ visibleTop: CGFloat) -> CGFloat {
        RailViewport.chartFoot(railTop: railTop, railBottom: railBottom, visibleTop: visibleTop, chartHeight: chartHeight)
    }

    @Test func theChartPinsWhenItReachesTheTopAndLeavesWithTheRail() {
        // At the page's top the chart sits in the page, its foot on the rail's top: not pinned.
        #expect(foot(0) == 800 && !RailViewport.isPinned(railTop: railTop, visibleTop: 0, chartHeight: chartHeight))
        // Exactly at the top: still in place.
        #expect(foot(600) == 800 && !RailViewport.isPinned(railTop: railTop, visibleTop: 600, chartHeight: chartHeight))
        // Past it the chart stays at the top and the rows go under it.
        #expect(foot(1000) == 1200 && RailViewport.isPinned(railTop: railTop, visibleTop: 1000, chartHeight: chartHeight))
        // At the rail's end the chart is pushed up with it, never below the rail's last row.
        #expect(foot(1700) == 1800)
    }

    @Test func theRowsInViewAreTheOnesUnderThePinnedChart() {
        // The page's top in a 700 pt window: the chart's foot at 800 and the window's at 700, so no row yet.
        #expect(RailViewport.rowsInView(rows, from: foot(0), to: 700).isEmpty)
        // Scrolled 400: rows from 800 to 1100 show, 1 to 6 (row 6, 1050 to 1100, is whole; row 7's middle is out).
        #expect(RailViewport.rowsInView(rows, from: foot(400), to: 1100) == Set((1 ... 6).map { TimelineItemID.entry($0) }))
        // Scrolled 1000 with the chart pinned: rows under the chart (800 to 1200) are hidden, 9 to 20 are not,
        // and a row half under the chart counts by its middle.
        #expect(RailViewport.rowsInView(rows, from: foot(1000), to: 1700) == Set((9 ... 18).map { TimelineItemID.entry($0) }))
        #expect(RailViewport.rowsInView(rows, from: 1210, to: 1700).contains(.entry(9)) == true)
        #expect(RailViewport.rowsInView(rows, from: 1230, to: 1700).contains(.entry(9)) == false)
    }

    /// The band is not a band that starts at the first row and grows: it spans the earliest and latest rows in view,
    /// and moves back when the page scrolls back.
    @Test func theBandFollowsTheRowsInViewBothWays() throws {
        let domain = TimelineChartModel.x(year: -1990) ... TimelineChartModel.x(year: -1800)
        func years(_ visibleTop: CGFloat) -> ClosedRange<Int>? {
            RailViewport.years(inView: RailViewport.rowsInView(rows, from: foot(visibleTop), to: visibleTop + 700), items: items, domain: domain)
        }
        #expect(years(0) == nil)
        #expect(years(400) == -1990 ... -1940)
        #expect(years(1000) == -1910 ... -1820)
        #expect(years(1100) == -1890 ... -1800)
        #expect(years(1000) == -1910 ... -1820)
        #expect(years(400) == -1990 ... -1940)
    }

    /// Matt, 2026-11-24: "Sometimes the highlight of the horizontal timeline does not work. This error tends to show
    /// up after scrolling down and back up and then down again." A lazy stack's row reports its content-space frame
    /// once; when it leaves and is made again its frame there is the same, so it appears with no new frame. The band
    /// must follow it all the same, down, up, down and in a fling, with rows coming and going in any order.
    @MainActor @Test func theBandFollowsRowsMadeAgainWithNoNewFrame() {
        let geometry = RailGeometry()
        geometry.items = items
        geometry.domain = TimelineChartModel.x(year: -1990) ... TimelineChartModel.x(year: -1800)
        geometry.chartHeight = chartHeight
        geometry.above(railTop - chartHeight)
        geometry.below(railBottom)
        func scroll(_ top: CGFloat) { geometry.visible(top ... top + 700, height: 700) }
        func make(_ ns: [Int]) {
            for n in ns {
                geometry.row(.entry(n), rows[.entry(n)]!)
                geometry.appeared(.entry(n))
            }
        }
        func leave(_ ns: [Int]) { for n in ns { geometry.disappeared(.entry(n)) } }
        func comeBack(_ ns: [Int]) { for n in ns { geometry.appeared(.entry(n)) } }
        // Down: each row made once, as the lazy stack makes them, in no order; the rows above the window leave.
        make([3, 1, 6, 2, 5, 4, 7, 8, 10, 9, 13, 11, 12, 14, 18, 15, 17, 16, 20, 19])
        leave([2, 8, 1, 6, 3, 7, 5, 4])
        scroll(1100)
        #expect(geometry.state.years == -1890 ... -1800)
        // Up: the rows above come back with no new frame, and the rows below leave.
        comeBack([8, 4, 1, 7, 2, 5, 3, 6])
        leave([20, 14, 19, 16, 13, 18, 17, 15])
        scroll(400)
        #expect(geometry.state.years == -1990 ... -1940)
        // Down again: the same, the other way.
        comeBack([16, 19, 13, 20, 14, 15, 18, 17])
        leave([1, 5, 2, 4, 3, 6, 8, 7])
        scroll(1000)
        #expect(geometry.state.years == -1910 ... -1820)
        // A row made again before its old copy has gone is still made.
        comeBack([12])
        leave([12])
        scroll(1000)
        #expect(geometry.state.years == -1910 ... -1820)
        // A fling: rows 17 to 20 have left and the window moves before anything else is made; a row not made counts
        // for nothing even where its last frame lies in view, and the band follows the rows that are.
        leave([20, 18, 17, 19])
        scroll(1100)
        #expect(geometry.state.years == -1890 ... -1840)
        comeBack([19, 18, 20, 17])
        scroll(1100)
        #expect(geometry.state.years == -1890 ... -1800)
        // A disappearance with no appearance before it never hides a row once it is made again.
        leave([1, 1])
        comeBack([1, 2, 3, 4, 5, 6])
        scroll(400)
        #expect(geometry.state.years == -1990 ... -1940)
    }

    /// A closed fold counts by its lives' years; a row off the chart's domain (Luke's genealogy) counts for nothing.
    @Test func aFoldCountsByItsLivesAndARowOffTheChartByNothing() {
        let lives = (1 ... 3).map { Fixture.record($0, "Lifetime of L\($0)", year: -2000 + 100 * $0, length: 50 * 365.25, person: $0) }
        let records = lives + [Fixture.record(4, "After", year: -1500)]
        let timeline = BookTimeline.make(records: records, passages: Fixture.passages(records.map(\.id)))
        let items = TimelineItems.items(timeline, openFolds: [], showingDates: true)
        let wide = TimelineChartModel.x(year: -2000) ... TimelineChartModel.x(year: -1400)
        #expect(RailViewport.years(inView: [.fold(1)], items: items, domain: wide) == -1900 ... -1700)
        let narrow = TimelineChartModel.x(year: -1600) ... TimelineChartModel.x(year: -1400)
        #expect(RailViewport.years(inView: [.fold(1)], items: items, domain: narrow) == nil)
        #expect(RailViewport.years(inView: [.fold(1), .entry(4)], items: items, domain: narrow) == -1500 ... -1500)
    }

    /// A click on the chart lands its row below the pinned chart, not under it: landed when the row's top is the
    /// chart's height down the window; a made row elsewhere is placed there by its mark; the phone (no chart) as before.
    @Test func aScrollLandsTheRowBelowThePinnedChart() {
        let target = TimelineItemID.entry(4)
        #expect(RailLanding.step(target: target, items: items, tops: [target: 200.4], inset: 200) == .landed)
        #expect(RailLanding.step(target: target, items: items, tops: [target: 0], inset: 200) == .belowChart(target))
        #expect(RailLanding.step(target: target, items: items, tops: [target: 0.3], inset: 0) == .landed)
        #expect(RailLanding.step(target: target, items: items, tops: [target: 40], inset: 0) == .scroll(target, .top))
        // Not made yet: the rows between are made first, as before.
        #expect(RailLanding.step(target: target, items: items, tops: [.entry(1): 0, .entry(2): 50], inset: 200) == .scroll(.entry(2), .top))
        // The first scroll to a row not yet made aims it near the chart's foot, so the correction after is small.
        #expect(RailLanding.anchor(inset: 0, viewport: 700) == .top)
        #expect(RailLanding.anchor(inset: 210, viewport: 700) == UnitPoint(x: 0, y: 0.3))
        #expect(RailLanding.anchor(inset: 900, viewport: 700) == .top)
    }

    /// The chart's click goes to the row it names whatever the page's scroll: the target does not depend on the rows
    /// in view (the rail is lazy; a row far from the screen is still a target).
    @Test(.needsRealBible) func aClickOnMatthewsChartGoesToItsRow() throws {
        let matthew = try BookTimeline.load(book: "MAT", translationID: "ESV", store: BenchmarkChapter.realStore())
        let model = TimelineChartModel(matthew)
        let items = TimelineItems.items(matthew, openFolds: [], showingDates: true)
        let first = try #require(matthew.entries.first)
        #expect(TimelineItems.scrollTarget(model.target(x: model.domain.lowerBound, lane: nil), items: items) == .entry(first.id))
        // Past the end: the first row of the last year (ties go to the earlier row).
        let lastYear = try #require(matthew.entries.last?.year)
        let firstOfLastYear = try #require(matthew.entries.first { $0.year == lastYear })
        #expect(TimelineItems.scrollTarget(model.target(x: model.domain.upperBound + 1, lane: nil), items: items) == .entry(firstOfLastYear.id))
    }
}
