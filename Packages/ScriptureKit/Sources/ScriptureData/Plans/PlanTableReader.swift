import Foundation

/// One word on a PDF page and where it sits.
public struct PlanWord: Equatable, Sendable {
    public let text: String
    public let x0: Double, x1: Double, y: Double                     // PDF points; y grows upward

    public init(_ text: String, x0: Double, x1: Double, y: Double) {
        self.text = text
        self.x0 = x0
        self.x1 = x1
        self.y = y
    }

    var centre: Double { (x0 + x1) / 2 }
}

/// The church's table as it is printed: its cells' text, row by row, week by week.
public struct PlanTable: Equatable, Sendable {
    public struct Row: Equatable, Sendable { public var wisdomBook: String, wisdomChapters: String, otherBook: String, otherChapters: String }
    public struct Week: Equatable, Sendable { public var number: Int?; public var dateText: String; public var rows: [Row] }
    public let hasDates: Bool
    public let weeks: [Week]
}

/// Rebuilds a plan's table from where each word sits on the page (spec 6.1; the spike's method).
public enum PlanTableReader {
    public enum Failure: Error, Equatable, Sendable { case noText, noHeader }

    /// Words whose heights differ by less than this are one line.
    static let lineTolerance = 2.5
    /// Lines this near the header's line are the header's too (a header that wraps).
    static let headerReach = 14.0
    /// Without dates, a larger gap between lines ends a week.
    static let weekGap = 28.0
    /// Without dates, a week this long ends at a new page.
    static let rowsInAWeek = 5
    /// A wrapped fragment joins the nearest reading row nearer than this.
    static let fragmentReach = 17.0

    public static func hasHeader(_ firstPage: [PlanWord]) -> Bool {
        Header(lines(firstPage)) != nil
    }

    public static func table(pages: [[PlanWord]]) throws(Failure) -> PlanTable {
        guard pages.contains(where: { !$0.isEmpty }) else { throw .noText }
        let pageLines = pages.map(lines)
        guard let header = Header(pageLines[0]) else { throw .noHeader }

        var items: [Item] = []
        for (index, lines) in pageLines.enumerated() {
            let rows = lines.filter { index > 0 || $0.y < header.bottom - 1 }.map(header.row)
            items += self.items(onPage: rows)
        }
        return PlanTable(hasDates: header.hasDates, weeks: weeks(from: items, hasDates: header.hasDates))
    }

    // MARK: Lines

    private struct Line { var y: Double; var words: [PlanWord] }

    /// Left to right; lines top to bottom.
    private static func lines(_ words: [PlanWord]) -> [Line] {
        var lines: [Line] = []
        for word in words.sorted(by: { $0.y > $1.y }) {
            if let last = lines.last, abs(last.y - word.y) < lineTolerance {
                lines[lines.count - 1].words.append(word)
            } else {
                lines.append(Line(y: word.y, words: [word]))
            }
        }
        for index in lines.indices { lines[index].words.sort { $0.x0 < $1.x0 } }
        return lines
    }

    // MARK: Columns

    private struct Header {
        let bottom: Double
        let hasDates: Bool
        let weekEnd: Double, wisdomChapterStart: Double, wisdomEnd: Double, otherChapterStart: Double, dateStart: Double

        init?(_ lines: [Line]) {
            guard let main = lines.firstIndex(where: { $0.words.contains { $0.text == "Wisdom" } }) else { return nil }
            let parts = lines.filter { abs($0.y - lines[main].y) <= PlanTableReader.headerReach }
            let words = parts.flatMap(\.words)
            func first(_ text: String) -> PlanWord? { words.filter { $0.text == text }.min { $0.x0 < $1.x0 } }
            guard let wk = first("Wk"), let wisdom = first("Wisdom"), let other = first("OT/NT") else { return nil }
            let chapters = words.filter { $0.text == "Chp" }.sorted { $0.x0 < $1.x0 }
            guard let wisdomChapter = chapters.first(where: { $0.x0 > wisdom.x1 && $0.x1 <= other.x0 }),
                  let otherChapter = chapters.first(where: { $0.x0 > other.x1 }) else { return nil }
            bottom = parts.map(\.y).min() ?? lines[main].y
            hasDates = words.contains { $0.text == "Meeting" }
            weekEnd = (wk.x1 + wisdom.x0) / 2
            wisdomChapterStart = (wisdom.centre + wisdomChapter.centre) / 2
            wisdomEnd = (wisdomChapter.centre + other.x0) / 2
            otherChapterStart = otherChapter.x0 - 8
            dateStart = hasDates ? otherChapter.x1 + 8 : .infinity
        }

        func row(_ line: Line) -> RawRow {
            var row = RawRow(y: line.y)
            func add(_ cell: inout String, _ text: String) { cell = cell.isEmpty ? text : cell + " " + text }
            for word in line.words {
                if word.x0 > dateStart { add(&row.date, word.text) }
                else if word.centre < weekEnd { row.week.append(word.text) }
                else if word.centre < wisdomEnd {
                    if PlanTableReader.isChapters(word.text) && word.centre > wisdomChapterStart { add(&row.cells.wisdomChapters, word.text) }
                    else { add(&row.cells.wisdomBook, word.text) }
                }
                else if word.centre < otherChapterStart { add(&row.cells.otherBook, word.text) }
                else { add(&row.cells.otherChapters, word.text) }
            }
            return row
        }
    }

    private static func isChapters(_ text: String) -> Bool {
        text.range(of: #"^\d+([:\-–,]\d+)*$"#, options: .regularExpression) != nil
    }

    // MARK: Rows

    private struct RawRow {
        var y: Double
        var week: [String] = []
        var cells = PlanTable.Row(wisdomBook: "", wisdomChapters: "", otherBook: "", otherChapters: "")
        var date = ""

        var hasChapter: Bool { !cells.wisdomChapters.isEmpty || !cells.otherChapters.isEmpty }
        var isDate: Bool { !date.isEmpty && !hasChapter && cells.wisdomBook.isEmpty && cells.otherBook.isEmpty }
        var isFragment: Bool { !hasChapter && !isDate }
    }

    private struct Item { var row: RawRow; var gapBefore: Bool; var opensPage: Bool }

    /// The page's rows with each wrapped fragment joined to its reading row.
    private static func items(onPage rows: [RawRow]) -> [Item] {
        var rows = rows
        let gaps = rows.indices.map { $0 > 0 && rows[$0 - 1].y - rows[$0].y > weekGap }
        for fragment in rows where fragment.isFragment {
            var nearest: Int?
            var distance = fragmentReach
            for (other, row) in rows.enumerated() where row.hasChapter && abs(row.y - fragment.y) < distance {
                nearest = other
                distance = abs(row.y - fragment.y)
            }
            guard let target = nearest else { continue }
            let above = fragment.y > rows[target].y
            func merge(_ row: String, _ part: String) -> String { above ? joinWrapped(part, row) : joinWrapped(row, part) }
            rows[target].cells.wisdomBook = merge(rows[target].cells.wisdomBook, fragment.cells.wisdomBook)
            rows[target].cells.otherBook = merge(rows[target].cells.otherBook, fragment.cells.otherBook)
            rows[target].week = above ? fragment.week + rows[target].week : rows[target].week + fragment.week
        }
        var items: [Item] = []
        var gapPending = false
        for (index, row) in rows.enumerated() {
            gapPending = gapPending || gaps[index]
            guard !row.isFragment else { continue }
            items.append(Item(row: row, gapBefore: gapPending, opensPage: items.isEmpty))
            gapPending = false
        }
        return items
    }

    /// A part of one or two lower-case letters joins with no space ("Lamentation" and "s").
    private static func joinWrapped(_ first: String, _ second: String) -> String {
        if first.isEmpty { return second }
        if second.isEmpty { return first }
        if second.count <= 2, second.allSatisfy(\.isLowercase) { return first + second }
        return first + " " + second
    }

    // MARK: Weeks

    private static func weeks(from items: [Item], hasDates: Bool) -> [PlanTable.Week] {
        var weeks: [PlanTable.Week] = []
        var current = PlanTable.Week(number: nil, dateText: "", rows: [])
        func close() {
            if !current.rows.isEmpty || !current.dateText.isEmpty { weeks.append(current) }
            current = PlanTable.Week(number: nil, dateText: "", rows: [])
        }
        for item in items {
            if !hasDates, item.gapBefore || (item.opensPage && current.rows.count >= rowsInAWeek) { close() }
            if item.row.isDate {
                if current.rows.isEmpty, item.opensPage, let last = weeks.indices.last, weeks[last].dateText.isEmpty {
                    weeks[last].dateText = item.row.date
                } else {
                    current.dateText = item.row.date
                    close()
                }
                continue
            }
            current.rows.append(item.row.cells)
            if current.number == nil, let number = item.row.week.first(where: { $0.allSatisfy { $0.isASCII && $0.isNumber } }).flatMap({ Int($0) }) {
                current.number = number
            }
        }
        close()
        return weeks
    }
}
