import ScriptureData

/// Where a rail row sits, for scrolling to it and for its line: an entry's id, an era header's id with
/// the count of its headers before it, a fold's id (its first life's).
public enum TimelineItemID: Hashable, Sendable {
    case entry(Int), era(Int, occurrence: Int), fold(Int)
}

/// Three or more lives in a row, in one era, drawn as one line until opened (spec 6.2).
struct TimelineFold: Equatable, Sendable {
    static let minimumRun = 3

    let lives: [BookTimeline.Entry]

    /// The first life's id.
    var id: Int { lives[0].id }

    /// "8 lives, Seth to Lamech".
    var line: String { "\(lives.count) lives, \(lives[0].title) to \(lives[lives.count - 1].title)" }
}

/// What the rail draws, in order. `yearLabel` is the year on the first row of each year, nil with dates off.
enum TimelineItem: Equatable, Sendable, Identifiable {
    case era(BookTimeline.Era, occurrence: Int)
    case entry(BookTimeline.Entry, yearLabel: String?)
    case fold(TimelineFold, isOpen: Bool, yearLabel: String?)

    var id: TimelineItemID {
        switch self {
        case .era(let era, let occurrence): .era(era.id, occurrence: occurrence)
        case .entry(let entry, _): .entry(entry.id)
        case .fold(let fold, _, _): .fold(fold.id)
        }
    }
}

/// Where to scroll on coming back to a passage: the entry (or, with `isEra`, the era whose id `entry` holds),
/// and the fold to open first when it is inside one.
struct TimelineAnchor: Equatable {
    let entry: Int
    let fold: Int?
    var isEra = false

    var scrollID: TimelineItemID { isEra ? .era(entry, occurrence: 0) : .entry(entry) }
}

enum TimelineItems {
    /// A gap of more than this many years is drawn dashed.
    static let longGap = 500

    static func items(_ timeline: BookTimeline, openFolds: Set<Int>, showingDates: Bool) -> [TimelineItem] {
        var result: [TimelineItem] = []
        var occurrences: [Int: Int] = [:]
        var currentEra: Int?
        var lastYear: Int?
        let entries = timeline.entries

        func label(_ year: Int) -> String? {
            defer { lastYear = year }
            return showingDates && year != lastYear ? LibraryYear.bare(year) : nil
        }
        func isLife(_ entry: BookTimeline.Entry) -> Bool {
            if case .life = entry.kind { true } else { false }
        }

        var index = 0
        while index < entries.count {
            let entry = entries[index]
            if entry.era != currentEra {
                currentEra = entry.era
                if let id = entry.era, let era = timeline.eras[id] {
                    let occurrence = occurrences[id, default: 0]
                    occurrences[id] = occurrence + 1
                    result.append(.era(era, occurrence: occurrence))
                }
            }
            var end = index + 1
            if isLife(entry) {
                while end < entries.count, entries[end].era == entry.era, isLife(entries[end]) { end += 1 }
            }
            guard end - index >= TimelineFold.minimumRun else {
                result.append(.entry(entry, yearLabel: label(entry.year)))
                index += 1
                continue
            }
            let fold = TimelineFold(lives: Array(entries[index..<end]))
            let open = openFolds.contains(fold.id)
            result.append(.fold(fold, isOpen: open, yearLabel: label(entry.year)))
            if open {
                for life in fold.lives { result.append(.entry(life, yearLabel: label(life.year))) }
            } else {
                lastYear = fold.lives[fold.lives.count - 1].year
            }
            index = end
        }
        return result
    }

    /// The items whose line below runs to a row more than `longGap` years on: the row itself and any era header
    /// between. A closed fold counts from its last life's year.
    static func dashedBelow(_ items: [TimelineItem]) -> Set<TimelineItemID> {
        var dashed = Set<TimelineItemID>()
        var previous: (index: Int, end: Int)?
        for (index, item) in items.enumerated() {
            let years: (start: Int, end: Int)
            switch item {
            case .era: continue
            case .entry(let entry, _): years = (entry.year, entry.year)
            case .fold(let fold, let isOpen, _):
                years = (fold.lives[0].year, isOpen ? fold.lives[0].year : fold.lives[fold.lives.count - 1].year)
            }
            if let previous, years.start - previous.end > longGap {
                for between in previous.index..<index { dashed.insert(items[between].id) }
            }
            previous = (index, years.end)
        }
        return dashed
    }

    /// The row whose passage was opened, and the closed fold it sits in; an era's own passage anchors to the era.
    static func anchor(_ timeline: BookTimeline, reference: Reference?) -> TimelineAnchor? {
        guard let reference else { return nil }
        if let entry = timeline.entries.first(where: { $0.passage == reference }) {
            let folded = items(timeline, openFolds: [], showingDates: false).lazy.compactMap { item -> Int? in
                guard case .fold(let fold, _, _) = item, fold.lives.contains(where: { $0.id == entry.id }) else { return nil }
                return fold.id
            }.first
            return TimelineAnchor(entry: entry.id, fold: folded)
        }
        if let era = timeline.eras.values.first(where: { $0.passage == reference }) {
            return TimelineAnchor(entry: era.id, fold: nil, isEra: true)
        }
        return nil
    }

    /// The rail row a click on the chart scrolls to (departure 8): an era's bar is its first header; a life or a
    /// row is its entry, or the closed fold it sits in. Nil when no row shows it.
    static func scrollTarget(_ target: TimelineChartModel.Target, items: [TimelineItem]) -> TimelineItemID? {
        let id: Int
        switch target {
        case .bar(let bar):
            if items.contains(where: { $0.id == .era(bar, occurrence: 0) }) { return .era(bar, occurrence: 0) }
            id = bar
        case .row(let row): id = row
        }
        for item in items {
            switch item {
            case .entry(let entry, _) where entry.id == id: return item.id
            case .fold(let fold, false, _) where fold.lives.contains(where: { $0.id == id }): return item.id
            default: continue
            }
        }
        return nil
    }

    /// The start years of the rows on screen, in the rail's order (departure 7): an entry's year, a closed fold's
    /// lives' years, an open fold's first life's year (its line sits there); an era header has none.
    static func years(visible: Set<TimelineItemID>, items: [TimelineItem]) -> [Int] {
        guard !visible.isEmpty else { return [] }
        return items.filter { visible.contains($0.id) }.flatMap { item -> [Int] in
            switch item {
            case .era: []
            case .entry(let entry, _): [entry.year]
            case .fold(let fold, let isOpen, _): isOpen ? [fold.lives[0].year] : fold.lives.map(\.year)
            }
        }
    }
}
