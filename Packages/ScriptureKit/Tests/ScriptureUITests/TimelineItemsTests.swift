import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

@Suite struct TimelineItemsTests {
    private typealias Fixture = TimelineFixture
    private let year = 365.25

    /// Lives with ids 1...n named L1...Ln in one year each, then whatever `extra` adds.
    private func timeline(_ records: [EventRecord]) -> BookTimeline {
        BookTimeline.make(records: records, passages: Fixture.passages(records.map(\.id)))
    }

    private func life(_ id: Int, _ name: String, year: Int = -4000, partOf: Int? = nil) -> EventRecord {
        Fixture.record(id, "Lifetime of \(name)", year: year, length: 900 * 365.25, partOf: partOf, person: id)
    }

    @Test func threeLivesInARowFoldAndTwoDoNot() throws {
        let records = [life(1, "L1"), life(2, "L2"), life(3, "L3"), Fixture.record(4, "The event"), life(5, "L4"), life(6, "L5")]
        let timeline = timeline(records)
        let closed = TimelineItems.items(timeline, openFolds: [], showingDates: true)
        guard case .fold(let fold, let isOpen, _) = closed[0] else { Issue.record("no fold first"); return }
        #expect(fold.line == "3 lives, L1 to L3" && fold.id == 1 && !isOpen)
        #expect(closed.dropFirst().map(\.id) == [.entry(4), .entry(5), .entry(6)])
        let open = TimelineItems.items(timeline, openFolds: [1], showingDates: true)
        guard case .fold(_, let isOpenNow, _) = open[0] else { Issue.record("no fold first"); return }
        #expect(isOpenNow && open.dropFirst().prefix(3).map(\.id) == [.entry(1), .entry(2), .entry(3)])
    }

    @Test func anEraHeadsItsGroupAndReopensAfterAnInterloper() {
        let records = [Fixture.record(1, "Era E", year: -3000), Fixture.record(2, "A", partOf: 1), Fixture.record(3, "B", partOf: 1),
                       Fixture.record(4, "X"), Fixture.record(5, "C", partOf: 1)]
        let items = TimelineItems.items(timeline(records), openFolds: [], showingDates: true)
        #expect(items.map(\.id) == [.era(1, occurrence: 0), .entry(2), .entry(3), .entry(4), .era(1, occurrence: 1), .entry(5)])
    }

    @Test func theYearShowsOnTheFirstRowOfEachYear() {
        let records = [Fixture.record(1, "A", year: -2347), Fixture.record(2, "B", year: -2347), Fixture.record(3, "C", year: -2347),
                       Fixture.record(4, "D", year: -2346)]
        let items = TimelineItems.items(timeline(records), openFolds: [], showingDates: true)
        let labels = items.compactMap { item -> String?? in
            if case .entry(_, let label) = item { return .some(label) }
            return nil
        }
        #expect(labels == ["2348 BC", nil, nil, "2347 BC"])
        let lives = [life(1, "L1", year: -2347), life(2, "L2", year: -2346), life(3, "L3", year: -2345)]
        guard case .fold(_, _, let label) = TimelineItems.items(timeline(lives), openFolds: [], showingDates: true)[0] else {
            Issue.record("no fold"); return
        }
        #expect(label == "2348 BC")
    }

    @Test func datesOffLeavesNoYearAndKeepsLengths() throws {
        let records = [life(1, "Adam", year: -4003), Fixture.record(2, "An event", year: -4002), life(3, "Seth", year: -3900)]
        let items = TimelineItems.items(timeline(records), openFolds: [], showingDates: false)
        for item in items {
            switch item {
            case .entry(_, let label), .fold(_, _, let label): #expect(label == nil)
            case .era: break
            }
        }
        let adam = try #require(timeline(records).entries.first)
        #expect(adam.detail(showingDates: false) == "lived 900 years")
    }

    @Test func aLongGapIsDashed() {
        let far = TimelineItems.items(timeline([Fixture.record(1, "A", year: -4003), Fixture.record(2, "B", year: -2347)]),
                                      openFolds: [], showingDates: true)
        #expect(TimelineItems.dashedBelow(far) == [.entry(1)])
        let near = TimelineItems.items(timeline([Fixture.record(1, "A", year: -2747), Fixture.record(2, "B", year: -2347)]),
                                       openFolds: [], showingDates: true)
        #expect(TimelineItems.dashedBelow(near).isEmpty)
    }

    @Test func aClosedFoldIsMeasuredFromItsLastLife() {
        let records = [life(1, "L1", year: -4000), life(2, "L2", year: -3000), life(3, "L3", year: -2000), Fixture.record(4, "E", year: -1700)]
        let items = TimelineItems.items(timeline(records), openFolds: [], showingDates: true)
        #expect(TimelineItems.dashedBelow(items).isEmpty)
    }

    @Test func comingBackIntoAClosedFoldOpensIt() {
        let records = [life(1, "Seth"), life(2, "Enos"), life(3, "Cainan"), Fixture.record(4, "Event")]
        let timeline = timeline(records)
        #expect(TimelineItems.anchor(timeline, reference: Fixture.passage(1, 2)) == TimelineAnchor(entry: 2, fold: 1))
        #expect(TimelineItems.anchor(timeline, reference: Fixture.passage(1, 4)) == TimelineAnchor(entry: 4, fold: nil))
        #expect(TimelineItems.anchor(timeline, reference: nil) == nil)
        #expect(TimelineItems.anchor(timeline, reference: Fixture.passage(9, 9)) == nil)
    }

    @Test func theYearGoesAboveAtAccessibilitySizes() {
        #expect(RailRow<EmptyView>.yearAbove(.large) == false)
        #expect(RailRow<EmptyView>.yearAbove(.accessibility1) == true)
    }

    /// A scroll to a row on the lazy rail is settled from the tops of the rows made: landed within a point of the top;
    /// the target again when it is made elsewhere; when it is not made, the made row nearest it to the edge facing it,
    /// so the rows between come on screen.
    @Test func aScrollToARailRowSettlesFromTheRowsMade() {
        let items = (1...8).map { TimelineItem.entry(Fixture.record($0, "E\($0)").asEntry, yearLabel: nil) }
        let target = TimelineItemID.entry(4)
        #expect(RailLanding.step(target: target, items: items, tops: [target: 0.4]) == .landed)
        #expect(RailLanding.step(target: target, items: items, tops: [target: -2.5]) == .scroll(target, .top))
        // Past it: rows 6 to 8 made, so row 6 goes to the bottom edge and the rows above it are made.
        #expect(RailLanding.step(target: target, items: items, tops: [.entry(6): -40, .entry(7): 10, .entry(8): 60]) == .scroll(.entry(6), .bottom))
        // Short of it: rows 1 and 2 made, so row 2 goes to the top.
        #expect(RailLanding.step(target: target, items: items, tops: [.entry(1): 0, .entry(2): 50]) == .scroll(.entry(2), .top))
        #expect(RailLanding.step(target: target, items: items, tops: [:]) == .scroll(target, .top))
        #expect(RailLanding.step(target: .entry(99), items: items, tops: [:]) == .landed)
    }

    /// The correction waits out an animated scroll (the chart's click, `.smooth`, half a second) without depending on its
    /// completion, starts at once after a cut (Reduce Motion, the come-back), and gives way when the reader scrolls.
    @Test func aScrollSettlesOnAClockAndGivesWayToTheReader() {
        #expect(RailLanding.settleDelay(animated: false) == .zero)
        #expect(RailLanding.settleDelay(animated: true) >= .milliseconds(500) && RailLanding.settleDelay(animated: true) < .seconds(1))
        #expect(RailLanding.readerScrolls(.interacting) && RailLanding.readerScrolls(.tracking) && RailLanding.readerScrolls(.decelerating))
        #expect(!RailLanding.readerScrolls(.animating) && !RailLanding.readerScrolls(.idle))
    }

    /// Below the default text size the year column keeps its default width, so "4004 BC" is not cut short; above
    /// it the column grows with the caption.
    @Test func theYearColumnIsNeverNarrowerThanAtTheDefaultSize() {
        #expect(RailRow<EmptyView>.yearWidth(scaled: 46) == RailRow<EmptyView>.yearWidthAtDefault)
        #expect(RailRow<EmptyView>.yearWidth(scaled: 70) == 70)
    }
}

extension EventRecord {
    /// The record as a plain event row.
    var asEntry: BookTimeline.Entry {
        BookTimeline.Entry(id: id, kind: .event, title: title, year: year, lengthDays: durationDays,
                           passage: nil, era: nil, isEra: false)
    }
}
