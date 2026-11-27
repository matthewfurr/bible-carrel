import Foundation
import ScriptureData

/// One row of the whole-Bible Notes browser: a note (with or without a highlight anchor), a
/// noteless highlight, a bookmark, or a conversation with the assistant, as a value copy the
/// views can hold.
public struct NotesBrowserEntry: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// `highlightID` is nil for a chapter note.
        case note(noteID: UUID, highlightID: UUID?)
        /// A highlight without a note.
        case highlight(id: UUID)
        case bookmark(id: UUID)
        /// A conversation: `body` is its title, `quotedText` its last turn's first line.
        case thread(id: UUID)
        /// A kept version whose note is gone (spec 4.2): `body` is its text, `modifiedAt` when it was written.
        case keptVersion(id: UUID)
    }

    /// The note's, highlight's, bookmark's or conversation's uuid.
    public let id: UUID
    public let kind: Kind
    /// Book code, e.g. "MAT".
    public let book: String
    /// `BookCatalog` order; an unknown code sorts last.
    public let bookOrder: Int
    public let chapter: Int
    public let verse: Int
    public let endVerse: Int
    public let referenceString: String
    /// Nil for bookmarks, which are translation-independent.
    public let translationID: String?
    /// Nil for a colorless highlight or a bookmark.
    public let color: MarkupColor?
    public let quotedText: String
    /// Empty for noteless highlights and bookmarks.
    public let body: String
    public let modifiedAt: Date
    /// The highlight color's name ("Yellow"), for the export's meta line; nil without a color.
    public let colorName: String?
    /// A note's text and its kept versions: 1 when it has none, and for every other kind.
    public let versionCount: Int

    public init(
        id: UUID, kind: Kind, book: String, bookOrder: Int, chapter: Int, verse: Int, endVerse: Int,
        referenceString: String, translationID: String?, color: MarkupColor?, quotedText: String, body: String, modifiedAt: Date,
        colorName: String? = nil, versionCount: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.book = book
        self.bookOrder = bookOrder
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
        self.referenceString = referenceString
        self.translationID = translationID
        self.color = color
        self.quotedText = quotedText
        self.body = body
        self.modifiedAt = modifiedAt
        self.colorName = colorName
        self.versionCount = versionCount
    }

    /// A note on the whole chapter (no anchor, stored with verse 0).
    public var isChapterNote: Bool {
        if case .note(_, let highlightID) = kind { return highlightID == nil && verse == 0 }
        return false
    }
}

public enum NotesBrowserSort: String, CaseIterable, Sendable {
    case date
    case reference
}

public enum NotesBrowserFilter: String, CaseIterable, Sendable {
    case all
    case notes
    case highlights
    case bookmarks
    case threads
    /// Notes with a kept version, and kept versions whose note is gone.
    case keptVersions
}

/// How far back the notes browser looks, by when an entry was last modified.
public enum NotesBrowserTimeFilter: String, CaseIterable, Sendable {
    case anyTime
    case pastWeek
    case pastMonth
    case pastThreeMonths
    case pastYear

    public var title: String {
        switch self {
        case .anyTime: "Any time"
        case .pastWeek: "Past week"
        case .pastMonth: "Past month"
        case .pastThreeMonths: "Past 3 months"
        case .pastYear: "Past year"
        }
    }

    /// The earliest `modifiedAt` this filter keeps; nil keeps everything.
    public func cutoff(from now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .anyTime: nil
        case .pastWeek: calendar.date(byAdding: .day, value: -7, to: now)
        case .pastMonth: calendar.date(byAdding: .month, value: -1, to: now)
        case .pastThreeMonths: calendar.date(byAdding: .month, value: -3, to: now)
        case .pastYear: calendar.date(byAdding: .year, value: -1, to: now)
        }
    }
}

/// Entries of one book, for the reference-sorted list, or of one day, for the date-sorted list.
public struct NotesBrowserSection: Identifiable, Equatable, Sendable {
    /// The book code, or "day-2026-11-23" for a day.
    public let id: String
    public let title: String
    public let entries: [NotesBrowserEntry]

    public init(id: String, title: String, entries: [NotesBrowserEntry]) {
        self.id = id
        self.title = title
        self.entries = entries
    }
}

/// Pure filtering, sorting and grouping of browser entries.
public enum NotesBrowserQuery {
    /// `.highlights` keeps noted highlights too: a note on a highlight is still a highlight. A
    /// kept version with no note lists under `.keptVersions` alone, never under `.all`.
    public static func filter(_ entries: [NotesBrowserEntry], by filter: NotesBrowserFilter) -> [NotesBrowserEntry] {
        entries.filter { entry in
            switch (filter, entry.kind) {
            case (.keptVersions, .keptVersion): true
            case (.keptVersions, .note): entry.versionCount > 1
            case (_, .keptVersion): false
            case (.all, _): true
            case (.notes, .note): true
            case (.highlights, .highlight): true
            case (.highlights, .note(_, let highlightID)): highlightID != nil
            case (.bookmarks, .bookmark): true
            case (.threads, .thread): true
            default: false
            }
        }
    }

    /// Keeps entries modified at or after `cutoff` (the future included); nil keeps everything.
    public static func filter(_ entries: [NotesBrowserEntry], since cutoff: Date?) -> [NotesBrowserEntry] {
        guard let cutoff else { return entries }
        return entries.filter { $0.modifiedAt >= cutoff }
    }

    /// `.date`: newest first, ties by reference. `.reference`: canon order, then chapter, verse, end verse, date.
    public static func sort(_ entries: [NotesBrowserEntry], by sort: NotesBrowserSort) -> [NotesBrowserEntry] {
        switch sort {
        case .date:
            entries.sorted {
                $0.modifiedAt != $1.modifiedAt ? $0.modifiedAt > $1.modifiedAt : $0.referenceString < $1.referenceString
            }
        case .reference:
            entries.sorted {
                ($0.bookOrder, $0.chapter, $0.verse, $0.endVerse, $0.modifiedAt) < ($1.bookOrder, $1.chapter, $1.verse, $1.endVerse, $1.modifiedAt)
            }
        }
    }

    /// Groups reference-sorted entries by book, keeping their order.
    public static func sections(_ entries: [NotesBrowserEntry]) -> [NotesBrowserSection] {
        var sections: [NotesBrowserSection] = []
        for entry in entries {
            if let last = sections.last, last.id == entry.book {
                sections[sections.count - 1] = NotesBrowserSection(id: last.id, title: last.title, entries: last.entries + [entry])
            } else {
                sections.append(NotesBrowserSection(id: entry.book, title: BookCatalog.book(code: entry.book)?.name ?? entry.book, entries: [entry]))
            }
        }
        return sections
    }

    /// Groups date-sorted entries by the calendar day of `modifiedAt`, keeping their order: one
    /// section per day, newest first, headed by `dayTitle`.
    public static func days(_ entries: [NotesBrowserEntry], now: Date, calendar: Calendar, locale: Locale) -> [NotesBrowserSection] {
        var days: [NotesBrowserSection] = []
        var day: (year: Int, month: Int, day: Int)?
        var members: [NotesBrowserEntry] = []
        func closeDay() {
            guard let day, let first = members.first else { return }
            days.append(NotesBrowserSection(id: String(format: "day-%04d-%02d-%02d", day.year, day.month, day.day),
                                            title: dayTitle(for: first.modifiedAt, now: now, calendar: calendar, locale: locale),
                                            entries: members))
        }
        for entry in entries {
            let components = calendar.dateComponents([.year, .month, .day], from: entry.modifiedAt)
            let entryDay = (year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
            if let day, day == entryDay {
                members.append(entry)
            } else {
                closeDay()
                day = entryDay
                members = [entry]
            }
        }
        closeDay()
        return days
    }

    /// "Today", "Yesterday", else the weekday and date in the reader's locale ("Wednesday,
    /// November 18"), with the year when it is not `now`'s. A day after today is titled by its date.
    public static func dayTitle(for day: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) { return "Yesterday" }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).day().month(.wide)
        if calendar.component(.year, from: day) != calendar.component(.year, from: now) { style = style.year() }
        return day.formatted(style)
    }

    /// "1 note", "2 notes": the count with the word the filter lists.
    public static func countLabel(_ count: Int, filter: NotesBrowserFilter) -> String {
        let word = switch filter {
        case .all: "item"
        case .notes: "note"
        case .highlights: "highlight"
        case .bookmarks: "bookmark"
        case .threads: "conversation"
        case .keptVersions: "kept version"
        }
        return "\(count) \(word)\(count == 1 ? "" : "s")"
    }

    /// What VoiceOver hears for a heading: "Today, 2 notes".
    public static func headingSpoken(_ section: NotesBrowserSection, filter: NotesBrowserFilter) -> String {
        "\(section.title), \(countLabel(section.entries.count, filter: filter))"
    }
}
