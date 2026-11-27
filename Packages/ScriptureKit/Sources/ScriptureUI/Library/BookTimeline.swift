import ScriptureData

/// A book's timeline: its lives and events in the order of history, grouped into eras (spec 5.2).
public struct BookTimeline: Equatable, Sendable {
    /// A row of the timeline: a life or an event.
    public struct Entry: Equatable, Sendable, Identifiable {
        public enum Kind: Equatable, Sendable { case life(personID: Int?), event }

        public let id: Int, kind: Kind
        /// A life's name without "Lifetime of ".
        public let title: String
        public let year: Int
        public let lengthDays: Double?
        public let passage: Reference?
        /// The outer era's id, one level deep.
        public let era: Int?
        /// An era record shown as a row: a single row with no child in the book, or an inner era.
        public let isEra: Bool

        /// A life ends at its start plus its whole years (departure 5).
        public var endYear: Int? {
            guard case .life = kind, let lengthDays else { return nil }
            return year + Int((lengthDays / 365.25).rounded())
        }

        /// A life: "lived 930 years · to 3074 BC" (dates off "lived 930 years"; nil with no length). An event:
        /// its length from 1.5 days.
        public func detail(showingDates: Bool) -> String? {
            guard let lengthDays else { return nil }
            if case .life = kind {
                let lived = "lived " + LibraryLength.text(days: lengthDays)
                guard showingDates, let endYear else { return lived }
                return "\(lived) · to \(LibraryYear.bare(endYear))"
            }
            return lengthDays >= 1.5 ? LibraryLength.text(days: lengthDays) : nil
        }

        /// What VoiceOver reads (spec 8): "2348 BC, The Great Flood begins, Genesis 7:6" (an event's length last);
        /// "Adam, lived 930 years, to 3074 BC".
        public func spoken(showingDates: Bool) -> String {
            if case .life = kind {
                var parts = [title]
                if let lengthDays { parts.append("lived " + LibraryLength.text(days: lengthDays)) }
                if showingDates, let endYear { parts.append("to " + LibraryYear.bare(endYear)) }
                return parts.joined(separator: ", ")
            }
            var parts: [String] = []
            if showingDates { parts.append(LibraryYear.bare(year)) }
            parts.append(title)
            if let passage { parts.append(passage.displayString) }
            if let length = detail(showingDates: false) { parts.append(length) }
            return parts.joined(separator: ", ")
        }
    }

    /// A group of rows under one header: a record with children that is neither a life nor part of one.
    public struct Era: Equatable, Sendable, Identifiable {
        public let id: Int, title: String, year: Int
        public let lengthDays: Double?
        public let passage: Reference?

        /// "The Great Flood · 2348 BC, one year"; dates off, the title.
        public func header(showingDates: Bool) -> String {
            guard showingDates else { return title }
            return "\(title) · " + datesAndLength
        }

        /// "The Great Flood, 2348 BC, one year"; dates off, the title.
        public func spoken(showingDates: Bool) -> String {
            showingDates ? "\(title), " + datesAndLength : title
        }

        private var datesAndLength: String {
            [LibraryYear.bare(year), lengthDays.map { LibraryLength.text(days: $0) }].compactMap { $0 }.joined(separator: ", ")
        }
    }

    /// In history order: the record's `sortKey`, then its id.
    public let entries: [Entry]
    public let eras: [Int: Era]
    /// The years of every record with a passage in the book, folded ones included.
    public let years: ClosedRange<Int>?

    public var lifeCount: Int { entries.filter { if case .life = $0.kind { true } else { false } }.count }
    public var eventCount: Int { entries.count - lifeCount }

    /// "24 lives, 41 events", "78 events", "1 life"; nil when empty. Era records and folded births and deaths
    /// are not counted.
    public var countLine: String? {
        let lives = lifeCount, events = eventCount
        let parts = [lives > 0 ? "\(lives) \(lives == 1 ? "life" : "lives")" : nil,
                     events > 0 ? "\(events) \(events == 1 ? "event" : "events")" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// `passages` holds each in-book event's first passage, by event id (spec 5.2).
    public static func make(records: [EventRecord], passages: [Int: Reference]) -> BookTimeline {
        let ordered = records.sorted { ($0.sortKey, $0.id) < ($1.sortKey, $1.id) }
        let byID = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var children: [Int: [EventRecord]] = [:]
        for record in ordered {
            if let parent = record.partOf, parent != record.id, byID[parent] != nil { children[parent, default: []].append(record) }
        }
        func parent(of record: EventRecord) -> EventRecord? { record.partOf.flatMap { byID[$0] } }
        func isLife(_ record: EventRecord) -> Bool { record.title.hasPrefix("Lifetime of ") }
        // A birth or a death of a life folds into it.
        func isFolded(_ record: EventRecord) -> Bool {
            (record.title.hasPrefix("Birth of ") || record.title.hasPrefix("Death of ")) && parent(of: record).map(isLife) == true
        }
        // An era: children anywhere, not a life, not part of a life.
        func isEra(_ record: EventRecord) -> Bool {
            children[record.id] != nil && !isLife(record) && parent(of: record).map(isLife) != true
        }
        // A life's passage is the first of its own and its folded children's in the book.
        func lifePassage(_ life: EventRecord) -> Reference? {
            ([life] + (children[life.id] ?? []).filter(isFolded)).compactMap { passages[$0.id] }
                .enumerated().min { ($0.element.chapter ?? 0, $0.element.verse ?? 0, $0.offset) < ($1.element.chapter ?? 0, $1.element.verse ?? 0, $1.offset) }?.element
        }
        // Whether the record or anything under it shows.
        func shows(_ record: EventRecord, depth: Int = 0) -> Bool {
            if isLife(record) { return lifePassage(record) != nil }
            if passages[record.id] != nil { return true }
            return depth < 32 && (children[record.id] ?? []).contains { !isFolded($0) && shows($0, depth: depth + 1) }
        }
        // The outermost era above a record, flattening eras within eras.
        func outerEra(of record: EventRecord) -> EventRecord? {
            var found: EventRecord?, current = record, steps = 0
            while let up = parent(of: current), steps < 32 {
                if isEra(up) { found = up }
                current = up
                steps += 1
            }
            return found
        }

        var entries: [Entry] = [], eraIDs = Set<Int>()
        for record in ordered where !isFolded(record) {
            let era = outerEra(of: record)
            if isLife(record) {
                guard let passage = lifePassage(record) else { continue }
                entries.append(Entry(id: record.id, kind: .life(personID: record.personID), title: String(record.title.dropFirst("Lifetime of ".count)),
                                     year: record.year, lengthDays: record.durationDays, passage: passage, era: era?.id, isEra: false))
            } else if isEra(record) {
                // A top-level era is a header; an inner one a row beside its children; one with nothing under it in
                // the book but its own passage is a single row.
                let childShows = (children[record.id] ?? []).contains { !isFolded($0) && shows($0) }
                if childShows && era == nil { continue }
                guard childShows || passages[record.id] != nil else { continue }
                entries.append(Entry(id: record.id, kind: .event, title: record.title, year: record.year, lengthDays: record.durationDays,
                                     passage: passages[record.id], era: era?.id, isEra: true))
            } else if let passage = passages[record.id] {
                entries.append(Entry(id: record.id, kind: .event, title: record.title, year: record.year, lengthDays: record.durationDays,
                                     passage: passage, era: era?.id, isEra: false))
            }
        }
        for entry in entries { if let era = entry.era { eraIDs.insert(era) } }
        let eras = Dictionary(uniqueKeysWithValues: eraIDs.compactMap { id in
            byID[id].map { (id, Era(id: id, title: $0.title, year: $0.year, lengthDays: $0.durationDays, passage: passages[id])) }
        })
        let years = ordered.filter { passages[$0.id] != nil }.map(\.year)
        return BookTimeline(entries: entries, eras: eras, years: years.min().flatMap { low in years.max().map { low ... $0 } })
    }

    /// Empty outside the 66 (no events there).
    public static func load(book code: String, translationID: String, store: BibleStore) throws -> BookTimeline {
        guard let book = BookCatalog.book(code: code) else { return BookTimeline(entries: [], eras: [:], years: nil) }
        return make(records: try store.eventRecords(), passages: try passages(of: book, translationID: translationID, store: store))
    }

    /// Each of the book's events' first run in it, by event id. One that runs past its chapter ends at that
    /// chapter's last verse in the translation, and is its first verse alone when the translation lacks the chapter;
    /// the last verses are read once, only when an event needs them.
    static func passages(of book: Book, translationID: String, store: BibleStore) throws -> [Int: Reference] {
        let events = try store.events(inBook: book.id)
        let lastVerses = events.contains { $0.end.chapter != $0.start.chapter }
            ? try store.lastVerses(ofBook: book.id, translationID: translationID) : [:]
        var passages: [Int: Reference] = [:]
        for event in events {
            let (start, end) = (event.start, event.end)
            let last: Int? = end.chapter != start.chapter ? lastVerses[start.chapter] : end.verse
            passages[event.id] = Reference(book: book, chapter: start.chapter, verse: start.verse,
                                           endVerse: last.flatMap { $0 > start.verse ? $0 : nil })
        }
        return passages
    }
}
