import CoreGraphics
import Foundation
import ScriptureData

/// The Mac's contents page (spec 4.1 to 4.4): the translation's books under their Testaments and
/// groups, the chosen book, what the toolbar's search dims and rings, and how the books fall into
/// columns and the arrows walk them.
public struct ContentsPage: Equatable, Sendable {
    /// A group's books, in canon order.
    public struct Block: Equatable, Sendable {
        public let group: BookGroup
        public let books: [TranslationBook]
    }

    /// One heading of the page: the Old Testament, the New, or the Apocrypha.
    public struct Testament: Identifiable, Equatable, Sendable {
        public let canon: Canon
        public let blocks: [Block]
        public var id: Canon { canon }
        public var title: String { canon.displayName }
        public var countLabel: String {
            let count = blocks.reduce(0) { $0 + $1.books.count }
            return count == 1 ? "1 book" : "\(count) books"
        }
    }

    /// A line of a column: a group's name or a book.
    public enum Row: Hashable, Sendable {
        case group(BookGroup)
        case book(TranslationBook)
    }

    /// A Testament broken into columns.
    public struct Section: Equatable, Sendable {
        public let testament: Testament
        public let columns: [[Row]]
    }

    /// The page in columns: bands from top to bottom, each one or more Testaments side by side.
    public struct Layout: Equatable, Sendable {
        public let bands: [[Section]]

        /// Each column's book ids, left to right, band by band.
        public var columns: [[String]] {
            bands.flatMap { band in band.flatMap { section in section.columns.map(Self.bookIDs) } }
        }

        static func bookIDs(_ column: [Row]) -> [String] {
            column.compactMap { if case .book(let entry) = $0 { entry.book.id } else { nil } }
        }
    }

    /// What opening a book or pressing Return goes to.
    public enum Target: Equatable, Sendable {
        /// The book being read, at the reader's place.
        case resume
        case chapter(ChapterLocation)
        case reference(Reference)
    }

    public enum Move: Sendable { case up, down, left, right }

    public let testaments: [Testament]
    public let reading: ChapterLocation?
    /// Every book's name, in page order: what the column width is measured over.
    public let bookNames: [String]
    public private(set) var chosenBookID: String?
    public private(set) var query: String
    private let books: [TranslationBook]
    /// The search's results for `query`; nil with nothing typed.
    private var results: FrontPageSearchResults?

    /// Chosen: the given book if the translation has it, else the book being read, else the first.
    public init(books: [TranslationBook], reading: ChapterLocation?, chosenBookID: String?) {
        self.books = books
        self.reading = reading
        self.query = ""
        let ids = Set(books.map(\.book.id))
        self.chosenBookID = [chosenBookID, reading?.book].compactMap { $0 }.first(where: ids.contains) ?? books.first?.book.id
        let testaments: [Testament] = Canon.allCases.compactMap { canon in
            let entries = books.filter { $0.book.canon == canon }
            guard !entries.isEmpty else { return nil }
            var blocks: [Block] = []
            for entry in entries {
                let group = BookGroup.group(of: entry.book)
                if let last = blocks.last, last.group == group {
                    blocks[blocks.count - 1] = Block(group: group, books: last.books + [entry])
                } else {
                    blocks.append(Block(group: group, books: [entry]))
                }
            }
            return Testament(canon: canon, blocks: blocks)
        }
        self.testaments = testaments
        self.bookNames = testaments.flatMap { $0.blocks.flatMap { $0.books.map(\.book.name) } }
    }

    public mutating func choose(_ bookID: String) {
        chosenBookID = bookID
    }

    /// Chooses the first match; with none, or nothing typed, the choice stays.
    public mutating func setQuery(_ text: String) {
        query = text
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        results = isEmpty ? nil : FrontPageSearch.results(query: text, books: books)
        if let first = results?.books.first { chosenBookID = first.book.id }
    }

    /// The books that match what is typed; nil with nothing typed.
    public var matches: Set<String>? {
        results.map { Set($0.books.map(\.book.id)) }
    }

    public func isDimmed(_ bookID: String) -> Bool {
        matches.map { !$0.contains(bookID) } ?? false
    }

    public var hasNoMatch: Bool {
        matches?.isEmpty == true
    }

    /// The typed reference's chapter, while its book is the chosen one.
    public var ringedChapter: Int? {
        guard let reference = results?.reference, reference.book.id == chosenBookID else { return nil }
        return reference.chapter
    }

    /// A double-click: the book being read resumes; any other opens at chapter 1.
    public func target(opening bookID: String) -> Target {
        reading?.book == bookID ? .resume : .chapter(ChapterLocation(book: bookID, chapter: 1))
    }

    /// Return in the field: the reference, else the chosen book's target; nil when nothing matches
    /// or nothing is typed.
    public var submitTarget: Target? {
        guard let results else { return nil }
        if let reference = results.reference { return .reference(reference) }
        guard !hasNoMatch, let chosenBookID else { return nil }
        return target(opening: chosenBookID)
    }

    // MARK: Columns

    /// As many columns as fit at `minimumColumnWidth` each with `md` between them; at least one.
    /// From four up, the Testaments sit side by side with `lg` between them instead of `md`
    /// (spec 4.2), so the count is one fewer when that extra gap no longer fits.
    public static func columnCount(width: CGFloat, minimumColumnWidth: CGFloat) -> Int {
        guard minimumColumnWidth > 0 else { return 1 }
        let count = max(1, Int((width + AppSpacing.md) / (minimumColumnWidth + AppSpacing.md)))
        guard count >= 4 else { return count }
        let needed = CGFloat(count) * minimumColumnWidth + CGFloat(count - 1) * AppSpacing.md + (AppSpacing.lg - AppSpacing.md)
        return needed > width ? count - 1 : count
    }

    /// From four columns up the Old and New Testaments share a band, the Old taking the odd one;
    /// under four each has the full width. The Apocrypha is always a band of its own. A Testament
    /// never has more columns than it has groups (or books, when it is one group).
    public func layout(columns: Int) -> Layout {
        let count = max(1, columns)
        let testaments = self.testaments.filter { $0.canon != .apocrypha }
        var bands: [[Section]] = []
        if count >= 4, testaments.count == 2 {
            bands.append([Self.section(testaments[0], columns: (count + 1) / 2), Self.section(testaments[1], columns: count / 2)])
        } else {
            bands += testaments.map { [Self.section($0, columns: count)] }
        }
        if let apocrypha = self.testaments.first(where: { $0.canon == .apocrypha }) {
            bands.append([Self.section(apocrypha, columns: count)])
        }
        return Layout(bands: bands)
    }

    /// The Testament's rows in units a column may not break inside: each group whole, or, when it
    /// is one group, its name with its first book and then each book alone. The breaks make the
    /// tallest column shortest; among those the most even (the least sum of squared heights);
    /// among those the earliest.
    private static func section(_ testament: Testament, columns: Int) -> Section {
        var units: [[Row]]
        if testament.blocks.count == 1, let block = testament.blocks.first {
            units = block.books.map { [.book($0)] }
            units[0].insert(.group(block.group), at: 0)
        } else {
            units = testament.blocks.map { block in [.group(block.group)] + block.books.map { .book($0) } }
        }
        let parts = min(columns, units.count)
        let breaks = bestBreaks(heights: units.map(\.count), parts: parts)
        let bounds = [0] + breaks + [units.count]
        let columns = (0..<parts).map { index in Array(units[bounds[index]..<bounds[index + 1]].joined()) }
        return Section(testament: testament, columns: columns)
    }

    /// The indexes where columns 2 to `parts` begin, by two passes over the suffixes: the least
    /// tallest column, then the least sum of squares with no column taller than that; the breaks
    /// are then read from the front, each the earliest that keeps the best.
    private static func bestBreaks(heights: [Int], parts: Int) -> [Int] {
        let count = heights.count
        guard parts > 1, parts <= count else { return [] }
        let none = Int.max / 4
        var prefix = [0]
        for height in heights { prefix.append(prefix[prefix.count - 1] + height) }
        func height(_ start: Int, _ end: Int) -> Int { prefix[end] - prefix[start] }
        /// The ends a part starting at `start` may have, leaving one unit for each of `rest` parts.
        func ends(from start: Int, leaving rest: Int) -> ClosedRange<Int>? {
            start + 1 <= count - rest ? (start + 1)...(count - rest) : nil
        }

        // tallest[k][i]: the least tallest column splitting units i... into k columns.
        var tallest = Array(repeating: Array(repeating: none, count: count + 1), count: parts + 1)
        for start in 0..<count { tallest[1][start] = height(start, count) }
        for k in 2...parts {
            for start in 0..<count {
                guard let range = ends(from: start, leaving: k - 1) else { continue }
                tallest[k][start] = range.map { max(height(start, $0), tallest[k - 1][$0]) }.min() ?? none
            }
        }
        let limit = tallest[parts][0]

        // squares[k][i]: the least sum of squared heights, no column over `limit`.
        var squares = Array(repeating: Array(repeating: none, count: count + 1), count: parts + 1)
        for start in 0..<count where height(start, count) <= limit {
            squares[1][start] = height(start, count) * height(start, count)
        }
        func cost(_ k: Int, _ start: Int, _ end: Int) -> Int {
            let part = height(start, end)
            guard part <= limit, squares[k - 1][end] < none else { return none }
            return part * part + squares[k - 1][end]
        }
        for k in 2...parts {
            for start in 0..<count {
                guard let range = ends(from: start, leaving: k - 1) else { continue }
                squares[k][start] = range.map { cost(k, start, $0) }.min() ?? none
            }
        }

        var breaks: [Int] = []
        var start = 0
        for k in stride(from: parts, to: 1, by: -1) {
            guard let range = ends(from: start, leaving: k - 1),
                  let end = range.first(where: { cost(k, start, $0) == squares[k][start] }) else { return [] }
            breaks.append(end)
            start = end
        }
        return breaks
    }

    // MARK: Arrows

    /// Down and Up walk a column's books and pass to the next or the previous column at its end;
    /// Left and Right go to the neighbouring column of the same band at the same book's place,
    /// held to that column's last book. Nil at an edge.
    public func bookID(moving move: Move, from bookID: String, in layout: Layout) -> String? {
        let bands = layout.bands.map { band in band.flatMap { $0.columns.map(Layout.bookIDs) }.filter { !$0.isEmpty } }
        let columns = bands.flatMap { $0 }
        guard let columnIndex = columns.firstIndex(where: { $0.contains(bookID) }),
              let place = columns[columnIndex].firstIndex(of: bookID) else { return nil }
        let column = columns[columnIndex]
        switch move {
        case .down:
            if place + 1 < column.count { return column[place + 1] }
            return columnIndex + 1 < columns.count ? columns[columnIndex + 1].first : nil
        case .up:
            if place > 0 { return column[place - 1] }
            return columnIndex > 0 ? columns[columnIndex - 1].last : nil
        case .left, .right:
            var start = 0
            for band in bands {
                if columnIndex < start + band.count {
                    let neighbour = columnIndex - start + (move == .right ? 1 : -1)
                    guard band.indices.contains(neighbour) else { return nil }
                    let next = band[neighbour]
                    return next[min(place, next.count - 1)]
                }
                start += band.count
            }
            return nil
        }
    }
}
