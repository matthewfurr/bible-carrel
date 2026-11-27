import Foundation
import ScriptureData

/// Somewhere the reader lately went: a chapter read, a passage looked up, a mark opened or a
/// search that led somewhere. Shown with nothing typed in search.
public struct Recent: Codable, Hashable, Identifiable, Sendable {
    public enum Target: Codable, Hashable, Sendable {
        /// Read: opening it moves the place.
        case chapter(ChapterLocation)
        /// Looked up: shown with the way back.
        case lookup(ChapterLocation, verse: Int?)
        case mark(id: UUID, kind: SearchMarkHit.Kind, target: MarkupTarget, reference: String)
        case search(query: String, scope: SearchScope, verseCount: Int)
    }

    public let target: Target
    /// The translation it was read or looked up in; nil for a mark that keeps the one being read, and for a search.
    public let translationID: String?
    public let date: Date

    public init(target: Target, translationID: String?, date: Date) {
        self.target = target
        self.translationID = translationID
        self.date = date
    }

    /// What makes two the same: the chapter; the chapter and verse; the mark's id; the query's terms with its scope.
    public var id: String {
        switch target {
        case .chapter(let location): "chapter:\(location.book):\(location.chapter)"
        case .lookup(let location, let verse): "lookup:\(location.book):\(location.chapter):\(verse ?? 0)"
        case .mark(let id, _, _, _): "mark:\(id.uuidString)"
        case .search(let query, let scope, _): "search:\(Self.scopeKey(scope)):\(Self.termsKey(query))"
        }
    }

    /// "John 15", "John 15:5", the mark's reference, the query as typed.
    public var title: String {
        switch target {
        case .chapter(let location): Self.chapterTitle(location)
        case .lookup(let location, let verse): verse.map { "\(Self.chapterTitle(location)):\($0)" } ?? Self.chapterTitle(location)
        case .mark(_, _, _, let reference): reference
        case .search(let query, _, _): query
        }
    }

    public var symbolName: String {
        switch target {
        case .chapter: "book"
        case .lookup: "text.quote"
        case .mark(_, let kind, _, _): kind.symbolName
        case .search: "magnifyingglass"
        }
    }

    /// "Read yesterday · ESV", "Looked up Tuesday · KJV", "Note", "Search · 12 verses · New Testament".
    public func subtitle(now: Date = .now, calendar: Calendar = .current) -> String {
        switch target {
        case .chapter: Self.joined("Read \(day(now: now, calendar: calendar))", translationID)
        case .lookup: Self.joined("Looked up \(day(now: now, calendar: calendar))", translationID)
        case .mark(_, let kind, _, _): kind.displayName
        case .search(_, let scope, let verseCount):
            Self.joined("Search", verseCount > 0 ? (verseCount == 1 ? "1 verse" : "\(verseCount.formatted()) verses") : nil,
                        scope == .wholeBible ? nil : scope.title)
        }
    }

    // MARK: - Private

    private static func joined(_ parts: String?...) -> String {
        parts.compactMap { $0 }.joined(separator: " · ")
    }

    private static func chapterTitle(_ location: ChapterLocation) -> String {
        "\(BookCatalog.book(code: location.book)?.chapterName ?? location.book) \(location.chapter)"
    }

    private static func scopeKey(_ scope: SearchScope) -> String {
        switch scope {
        case .wholeBible: "whole"
        case .oldTestament: "ot"
        case .newTestament: "nt"
        case .apocrypha: "apocrypha"
        case .book(let code): "book-\(code)"
        }
    }

    /// The query read into terms, so spacing and case do not make two searches.
    private static func termsKey(_ query: String) -> String {
        SearchQuery(query).terms
            .map { "\($0.isExcluded ? "-" : "")\($0.words.joined(separator: " "))\($0.isWordStart ? "*" : "")" }
            .joined(separator: "|")
    }

    /// "today", "yesterday", the weekday for two to six days ago, then "Nov 9".
    private func day(now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = calendar.locale ?? .current
            formatter.setLocalizedDateFormatFromTemplate(days <= 6 ? "EEEE" : "MMMd")
            return formatter.string(from: date)
        }
    }
}

/// The reader's recents, newest first, kept in `UserDefaults` as JSON and never synced.
@MainActor public final class RecentsStore {
    public static let key = "recents"
    public static let capacity = 20
    public static let shownCount = 5

    private let defaults: UserDefaults
    /// Newest first, once per `Recent.id`.
    public private(set) var items: [Recent]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A list from another build, or damaged, reads as empty.
        items = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([Recent].self, from: $0) } ?? []
    }

    /// Puts the target at the front as it is now, once.
    public func record(_ target: Recent.Target, translationID: String?, at date: Date = .now) {
        let recent = Recent(target: target, translationID: translationID, date: date)
        items.removeAll { $0.id == recent.id }
        items.insert(recent, at: 0)
        if items.count > Self.capacity { items.removeLast(items.count - Self.capacity) }
        save()
    }

    public func clear() {
        items = []
        defaults.removeObject(forKey: Self.key)
    }

    /// The newest five that can be opened now: not the chapter that is open, none in a translation the app lacks.
    public func shown(openChapter: ChapterLocation?, translations: [Translation]) -> [Recent] {
        let available = Set(translations.map(\.id))
        let rows = items.filter { recent in
            if case .chapter(let location) = recent.target, location == openChapter { return false }
            return recent.translationID.map(available.contains) ?? true
        }
        return Array(rows.prefix(Self.shownCount))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: Self.key) }
    }
}
