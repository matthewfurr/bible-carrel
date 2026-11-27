import Charts
import Foundation

/// The whole book's span to scale (spec 6.5): lives and eras as bars packed into lanes, the other entries as
/// ticks, on a year axis where 4000 BC is -4000. Pure data; `TimelineChartView` draws it.
public struct TimelineChartModel: Equatable, Sendable {
    public struct Bar: Equatable, Sendable, Identifiable {
        public enum Kind: Equatable, Sendable { case life, era }
        public let id: Int, kind: Kind, title: String, start: Double, end: Double, lane: Int
    }

    public enum Target: Equatable { case bar(Int), row(Int) }

    public static let maximumLanes = 12

    public let bars: [Bar]
    /// The x of every entry drawn as a tick, ascending.
    public let ticks: [Double]
    public let laneCount: Int
    public let domain: ClosedRange<Double>
    /// Every row, by id and x, in the timeline's order.
    private let rows: [Row]

    private struct Row: Equatable, Sendable { let id: Int, x: Double }

    private struct Candidate { let id: Int, kind: Bar.Kind, title: String, start: Double, end: Double }

    public init(_ timeline: BookTimeline) {
        var candidates: [Candidate] = [], ticks: [Double] = []
        let kept = Self.charted(timeline.entries.map { Self.x(year: $0.year) })
        let entries = timeline.entries.filter { kept.contains(Self.x(year: $0.year)) }
        for entry in entries {
            let start = Self.x(year: entry.year)
            if case .life = entry.kind, let endYear = entry.endYear, endYear > entry.year {
                candidates.append(Candidate(id: entry.id, kind: .life, title: entry.title, start: start, end: Self.x(year: endYear)))
            } else if entry.isEra, entry.era == nil, let days = entry.lengthDays, days > 0 {
                candidates.append(Candidate(id: entry.id, kind: .era, title: entry.title, start: start, end: start + days / 365.25))
            } else {
                ticks.append(start)
            }
        }
        for era in timeline.eras.values {
            let start = Self.x(year: era.year)
            if let days = era.lengthDays, days > 0, start + days / 365.25 >= kept.lowerBound, start <= kept.upperBound {
                candidates.append(Candidate(id: era.id, kind: .era, title: era.title, start: start, end: start + days / 365.25))
            }
        }
        candidates.sort { ($0.start, $0.id) < ($1.start, $1.id) }
        var lanes = Self.lanes(candidates.map { $0.start ... $0.end })
        while (lanes.max() ?? -1) + 1 > Self.maximumLanes, let shortest = candidates.indices.min(by: {
            (candidates[$0].end - candidates[$0].start, candidates[$1].id) < (candidates[$1].end - candidates[$1].start, candidates[$0].id)
        }) {
            ticks.append(candidates[shortest].start)
            candidates.remove(at: shortest)
            lanes = Self.lanes(candidates.map { $0.start ... $0.end })
        }
        bars = zip(candidates, lanes).map { Bar(id: $0.id, kind: $0.kind, title: $0.title, start: $0.start, end: $0.end, lane: $1) }
        self.ticks = ticks.sorted()
        laneCount = (lanes.max() ?? -1) + 1
        let xs = candidates.flatMap { [$0.start, $0.end] } + ticks
        domain = (xs.min() ?? 0) ... (xs.max().map { max($0, (xs.min() ?? 0) + 1) } ?? 1)
        rows = entries.map { Row(id: $0.id, x: Self.x(year: $0.year)) }
    }

    /// The rows the chart draws, as the span of their x: all of them, unless a few lie far from the rest (Matt's
    /// review, 2026-11-24: Luke's two genealogy lives, 3,800 years before its other rows, squeezed those into the
    /// chart's last 1%). "Far" is a gap wider than half the whole span; "a few" is at most 5% of the rows, on the
    /// gap's near side, so Matthew's eight birth rows (11%) stay. The rail keeps every row.
    static func charted(_ xs: [Double]) -> ClosedRange<Double> {
        let sorted = xs.sorted()
        guard let low = sorted.first, let high = sorted.last, high > low else { return (sorted.first ?? 0) ... (sorted.first ?? 0) }
        let few = Int((Double(sorted.count) * 0.05).rounded(.down))
        guard few > 0, let gap = sorted.indices.dropLast().max(by: { sorted[$0 + 1] - sorted[$0] < sorted[$1 + 1] - sorted[$1] }),
              sorted[gap + 1] - sorted[gap] > (high - low) / 2 else { return low ... high }
        if gap + 1 <= few { return sorted[gap + 1] ... high }
        if sorted.count - gap - 1 <= few { return low ... sorted[gap] }
        return low ... high
    }

    /// The chart shows with dates on, at least five rows and at least two distinct years (departure 9).
    public static func shows(_ timeline: BookTimeline, showingDates: Bool) -> Bool {
        showingDates && timeline.entries.count >= 5 && Set(timeline.entries.map(\.year)).count >= 2
    }

    /// The axis position of a year: the era's year before the Common Era has no year zero.
    public static func x(year: Int) -> Double { Double(year <= 0 ? year - 1 : year) }

    /// Each span's lane, in the order given: the first lane whose last span ends at or before its start. Spans are
    /// taken by start (ties in the order given).
    static func lanes(_ spans: [ClosedRange<Double>]) -> [Int] {
        var ends: [Double] = [], result = Array(repeating: 0, count: spans.count)
        for index in spans.indices.sorted(by: { (spans[$0].lowerBound, $0) < (spans[$1].lowerBound, $1) }) {
            let lane = ends.firstIndex { $0 <= spans[index].lowerBound } ?? ends.count
            if lane == ends.count { ends.append(spans[index].upperBound) } else { ends[lane] = spans[index].upperBound }
            result[index] = lane
        }
        return result
    }

    /// The axis's tick years: round numbers inside `domain`, never 0, which is no year (1 BC is followed by AD 1).
    public static func axisValues(domain: ClosedRange<Double>) -> [Double] {
        NumberBins(range: domain, desiredCount: 6).thresholds.filter { domain.contains($0) && $0 != 0 }
    }

    /// A label on the axis: its x and its words.
    public struct AxisMark: Equatable, Sendable {
        public let value: Double
        public let label: String
    }

    /// The axis's labels for a chart `width` points wide (Matt's review, 2026-11-24: Matthew's read only "AD 10, 20,
    /// 30", so its BC end read as nothing). Both ends are named, at the domain's own years and with their era ("6 BC",
    /// "AD 30"; "4004 BC", "1491 BC"); between them the round years `axisValues` gives, the first of an era not yet
    /// named carrying it ("AD 10"), each kept only where it clears its neighbours by two characters. The first label
    /// hangs right of its year and the last left of its year, as the chart draws them; `characterWidth` is a
    /// caption digit's width, near enough for years.
    public static func axisMarks(domain: ClosedRange<Double>, width: CGFloat, characterWidth: CGFloat) -> [AxisMark] {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0, width > 0 else { return [] }
        func position(_ value: Double) -> CGFloat { CGFloat((value - domain.lowerBound) / span) * width }
        func labelWidth(_ label: String) -> CGFloat { CGFloat(label.count) * characterWidth }
        func year(_ value: Double) -> Int { Int(value.rounded()) }
        func words(_ value: Double, named: Bool) -> String {
            let number = year(value)
            if number < 0 { return named ? "\(-number) BC" : "\(-number)" }
            return named ? "AD \(number)" : "\(number)"
        }
        let gap = characterWidth * 2
        let first = AxisMark(value: domain.lowerBound, label: words(domain.lowerBound, named: true))
        let last = AxisMark(value: domain.upperBound, label: words(domain.upperBound, named: true))
        let lastLeft = width - labelWidth(last.label)
        var marks = [first], right = labelWidth(first.label), named: Set<Bool> = [year(first.value) < 0]
        for value in axisValues(domain: domain) where year(value) != year(first.value) && year(value) != year(last.value) {
            let isBC = year(value) < 0
            let label = words(value, named: !named.contains(isBC))
            let half = labelWidth(label) / 2, x = position(value)
            guard x - half >= right + gap, x + half <= lastLeft - gap else { continue }
            marks.append(AxisMark(value: value, label: label))
            named.insert(isBC)
            right = x + half
        }
        if lastLeft >= right + gap || marks.count == 1 { marks.append(last) }
        return marks
    }

    /// The years' span on the axis, at least 1% of the domain wide (centred), nil with no years (departure 7). A
    /// year off the chart (a row `charted` leaves out) counts for nothing.
    public static func band(years: [Int], domain: ClosedRange<Double>) -> ClosedRange<Double>? {
        let xs = years.map { x(year: $0) }.filter { domain.contains($0) }
        guard let low = xs.min(), let high = xs.max() else { return nil }
        let least = (domain.upperBound - domain.lowerBound) * 0.01
        guard high - low < least else { return low ... high }
        let middle = (low + high) / 2
        return (middle - least / 2) ... (middle + least / 2)
    }

    /// A bar in `lane` covering `x`, else the row nearest `x` (ties to the earlier).
    public func target(x: Double, lane: Int?) -> Target {
        if let lane, let bar = bars.first(where: { $0.lane == lane && $0.start <= x && x <= $0.end }) { return .bar(bar.id) }
        var best: Row?
        for row in rows where best.map({ abs(row.x - x) < abs($0.x - x) }) ?? true { best = row }
        return .row(best?.id ?? -1)
    }
}
