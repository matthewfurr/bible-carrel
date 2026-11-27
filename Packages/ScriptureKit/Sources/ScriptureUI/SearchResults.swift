import Foundation
import ScriptureData

/// One of the reader's marks as a search row: a note, a bare highlight, a bookmark or a
/// conversation. Chosen, it takes the reader to the mark.
public struct SearchMarkHit: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Codable, Sendable {
        case note, highlight, bookmark, thread

        var symbolName: String {
            switch self {
            case .note: "note.text"
            case .highlight: "highlighter"
            case .bookmark: "bookmark.fill"
            case .thread: "sparkles"
            }
        }

        /// As the notes browser names it.
        var displayName: String {
            switch self {
            case .note: "Note"
            case .highlight: "Highlight"
            case .bookmark: "Bookmark"
            case .thread: "Conversation"
            }
        }
    }

    /// The note's, highlight's, bookmark's or conversation's uuid.
    public let id: UUID
    public let kind: Kind
    public let target: MarkupTarget
    public let referenceString: String
    public let quotedText: String
    /// Nil for a colorless highlight, a bookmark or a conversation.
    public let color: MarkupColor?
    /// The body's first line, markdown markers stripped; a conversation's title.
    public let firstLine: String
    public let modifiedAt: Date

    public init(entry: NotesBrowserEntry) {
        id = entry.id
        switch entry.kind {
        // ⌘K is never given a kept version (`NotesBrowserLoader`); it would read as a note.
        case .note, .keptVersion: kind = .note
        case .highlight: kind = .highlight
        case .bookmark: kind = .bookmark
        case .thread: kind = .thread
        }
        target = MarkupTarget(entry: entry)
        referenceString = entry.referenceString
        quotedText = entry.quotedText
        color = entry.color
        firstLine = kind == .thread ? entry.body : Self.firstLine(of: entry.body)
        modifiedAt = entry.modifiedAt
    }

    /// A note body's first line, markdown markers stripped, at most 120 characters.
    public static func firstLine(of body: String) -> String {
        firstLine(of: body, limit: 120)
    }

    /// As `firstLine(of:)`, at most `limit` characters; nil for the whole line.
    static func firstLine(of body: String, limit: Int?) -> String {
        guard let block = NoteMarkdown.blocks(body).first else { return "" }
        let text = (String(block.characters).split(whereSeparator: \.isNewline).first.map(String.init) ?? "")
            .trimmingCharacters(in: .whitespaces)
        return limit.map { String(text.prefix($0)) } ?? text
    }

    public var symbolName: String { kind.symbolName }

    /// What VoiceOver reads first on the mark's row, as the notes browser names it.
    var kindName: String { kind.displayName }
}

/// The groups search results come in, in no particular order (each query kind has its own).
public enum SearchGroupKind: String, CaseIterable, Sendable {
    case goTo, marksInPassage, books, translations, commands, notes, asked, scripture
    /// People and places found by name, for the whole Bible (spec 6.6).
    case people, places
    /// "Did you mean": one row, no header, first when Scripture found nothing.
    case suggestion
    /// What the reader went to lately, with nothing typed.
    case recent
}

/// A chip over the results: one kind of result shown alone. The phone offers `phone`.
public enum SearchChip: String, CaseIterable, Sendable {
    case marks, notes, asked, scripture, passages, people, places, commands

    public var title: String {
        switch self {
        case .marks: "Marks"
        case .notes: "Notes"
        case .asked: "Asked"
        case .scripture: "Scripture"
        case .passages: "Passages"
        case .people: "People"
        case .places: "Places"
        case .commands: "Commands"
        }
    }

    /// The groups the chip shows.
    public var kinds: Set<SearchGroupKind> {
        switch self {
        case .marks: [.marksInPassage]
        case .notes: [.notes]
        case .asked: [.asked]
        case .scripture: [.scripture, .suggestion]
        case .passages: [.goTo, .books]
        case .people: [.people]
        case .places: [.places]
        case .commands: [.commands, .translations]
        }
    }

    public static let phone: [SearchChip] = [.marks, .notes, .asked, .scripture, .people, .places]
}

/// One titled group of search rows.
public struct SearchGroup: Identifiable, Equatable, Sendable {
    public let kind: SearchGroupKind
    public let title: String
    public let items: [PaletteItem]
    /// How many rows matched before the limit; the whole Bible's count for `scripture`.
    public let totalCount: Int

    public var id: SearchGroupKind { kind }
}

/// How many rows each limited group shows: the Mac palette shows a few of each, the phone's
/// search screen more.
public struct SearchLimits: Equatable, Sendable {
    public var books, notes, asked, verses, marksInPassage, commands, people, places: Int

    public static let palette = SearchLimits(
        books: 6, notes: 5, asked: 3, verses: 8, marksInPassage: 12, commands: 6, people: 4, places: 4)
    public static let phone = SearchLimits(
        books: 6, notes: 20, asked: 10, verses: 20, marksInPassage: 50, commands: 0, people: 6, places: 6)
    /// The Mac's palette with a chip chosen: that kind alone, with more rows.
    public static let paletteChip = SearchLimits(
        books: 30, notes: 30, asked: 20, verses: 50, marksInPassage: 50, commands: 60, people: 30, places: 30)
}

/// A query's results, grouped for the palette and the phone's search screen.
public struct SearchResults: Equatable, Sendable {
    public static let empty = SearchResults(groups: [], verseColors: [:])

    /// Only non-empty groups, in display order.
    public let groups: [SearchGroup]
    /// A verse row's `PaletteItem.id` to the color of the reader's mark on that verse.
    public let verseColors: [String: MarkupColor]

    /// The groups' rows in order.
    public var flatItems: [PaletteItem] {
        groups.flatMap(\.items)
    }

    /// Just one group (for a scope picker); nil keeps every group.
    public func only(_ kind: SearchGroupKind?) -> SearchResults {
        guard let kind else { return self }
        return SearchResults(groups: groups.filter { $0.kind == kind }, verseColors: verseColors)
    }

    /// The chips of `offered` that have a group here with a result, in `offered`'s order: a chip
    /// that only "Did you mean" stands for (a count of 0) is not offered.
    public func chips(_ offered: [SearchChip] = SearchChip.allCases) -> [SearchChip] {
        offered.filter { chip in groups.contains { chip.kinds.contains($0.kind) } && count(of: chip) > 0 }
    }

    /// The chip's groups alone; nil, or a chip with no group here, keeps every group.
    public func showing(_ chip: SearchChip?) -> SearchResults {
        guard let chip, groups.contains(where: { chip.kinds.contains($0.kind) }) else { return self }
        return SearchResults(groups: groups.filter { chip.kinds.contains($0.kind) }, verseColors: verseColors)
    }

    /// How many results the chip's groups matched; a suggestion is not one.
    public func count(of chip: SearchChip) -> Int {
        groups.filter { chip.kinds.contains($0.kind) && $0.kind != .suggestion }.map(\.totalCount).reduce(0, +)
    }

    /// Tab: the chip `delta` on from `current` (nil is All) among `chips`, going round through All.
    /// A chip no longer among them steps from nowhere: back to All.
    public static func chip(after current: SearchChip?, by delta: Int, among chips: [SearchChip]) -> SearchChip? {
        let stops: [SearchChip?] = [nil] + chips
        guard let index = stops.firstIndex(of: current) else { return nil }
        let count = stops.count
        return stops[((index + delta) % count + count) % count]
    }
}
