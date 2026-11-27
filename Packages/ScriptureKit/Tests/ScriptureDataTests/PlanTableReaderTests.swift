import Foundation
import Testing
@testable import ScriptureData

/// Column centres in points, measured from the two PDFs. Rows are 18.5 pt apart; in the layout without dates a week's last row and the next week's first are 37 pt apart.
private enum Gen1 { static let wk = 138.0, wisdom = 198.5, wisdomChapters = 272.0, other = 364.5, otherChapters = 460.0, merged = 236.5, top = 640.9 }
private enum Gen2 { static let wk = 83.0, wisdom = 126.5, wisdomChapters = 189.5, other = 258.0, otherChapters = 315.5, date = 338.0, top = 643.6 }

/// A cell's words left to right from `start`: 5.5 pt a character, 3 pt between words.
private func words(_ text: String, from start: Double, y: Double) -> [PlanWord] {
    var x = start
    return text.split(separator: " ").map { part in
        let word = PlanWord(String(part), x0: x, x1: x + 5.5 * Double(part.count), y: y)
        x = word.x1 + 3
        return word
    }
}

/// A cell's words left to right about `centre`: 5.5 pt a character, 3 pt between words.
private func cell(_ text: String, centre: Double, y: Double) -> [PlanWord] {
    let parts = text.split(separator: " ")
    guard !parts.isEmpty else { return [] }
    let width = parts.reduce(0) { $0 + 5.5 * Double($1.count) } + 3 * Double(parts.count - 1)
    return words(text, from: centre - width / 2, y: y)
}

private func gen1Header() -> [PlanWord] {
    let y = 663.3
    return [PlanWord("Wk", x0: 131, x1: 145, y: y), PlanWord("Wisdom", x0: 179, x1: 218, y: y), PlanWord("Chp", x0: 262, x1: 282, y: y),
            PlanWord("OT/NT", x0: 350, x1: 379, y: y), PlanWord("Chp", x0: 450, x1: 469, y: y)]
}

private func gen2Header() -> [PlanWord] {
    let y = 665.9
    return [PlanWord("Wk", x0: 76, x1: 91, y: y), PlanWord("Wisdom", x0: 107, x1: 146, y: y), PlanWord("Chp", x0: 180, x1: 199, y: y),
            PlanWord("OT/NT", x0: 243, x1: 273, y: y), PlanWord("Chp", x0: 306, x1: 325, y: y),
            PlanWord("Meeting", x0: 369, x1: 407, y: y), PlanWord("Date", x0: 410, x1: 431, y: y)]
}

private func gen1Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: Double) -> [PlanWord] {
    cell(wk, centre: Gen1.wk, y: y) + cell(wisdom, centre: Gen1.wisdom, y: y) + cell(chapters, centre: Gen1.wisdomChapters, y: y)
        + cell(other, centre: Gen1.other, y: y) + cell(otherChapters, centre: Gen1.otherChapters, y: y)
}

private func gen2Row(wk: String = "", _ wisdom: String, _ chapters: String, _ other: String, _ otherChapters: String, y: Double) -> [PlanWord] {
    cell(wk, centre: Gen2.wk, y: y) + cell(wisdom, centre: Gen2.wisdom, y: y) + cell(chapters, centre: Gen2.wisdomChapters, y: y)
        + cell(other, centre: Gen2.other, y: y) + cell(otherChapters, centre: Gen2.otherChapters, y: y)
}

/// Its first word starts at x 338.
private func gen2Date(_ text: String, y: Double) -> [PlanWord] {
    words(text, from: Gen2.date, y: y)
}

/// A Gen 1 week of five from `y` down: "Wk" on its second row and `number` on its third; its rows are Psalms `psalm` to `psalm + 4`, Psalms n beside Genesis `3n - 2` to `3n` ("1-3" for Psalms 1, "16-18" for Psalms 6).
private func gen1Week(_ number: Int, psalm: Int, y: Double) -> [PlanWord] {
    (0..<5).flatMap { row in
        let n = psalm + row
        return gen1Row(wk: row == 1 ? "Wk" : row == 2 ? "\(number)" : "", "Psalms", "\(n)", "Genesis", "\(3 * n - 2)-\(3 * n)", y: y - Double(row) * 18.5)
    }
}

private let today = PlanDay(year: 2026, month: 11, day: 16)!

@Test func weeksOfFiveReadInOrderAcrossTheGap() throws {
    let table = try PlanTableReader.table(pages: [gen1Header() + gen1Week(1, psalm: 1, y: Gen1.top) + gen1Week(2, psalm: 6, y: Gen1.top - 4 * 18.5 - 37)])
    #expect(!table.hasDates && table.weeks.map(\.number) == [1, 2] && table.weeks.map(\.rows.count) == [5, 5])
    #expect(table.weeks[0].rows[0] == PlanTable.Row(wisdomBook: "Psalms", wisdomChapters: "1", otherBook: "Genesis", otherChapters: "1-3"))
    let draft = PlanImport.draft(from: table, title: "T", today: today)
    #expect(draft.weeks[1].readings[0].text == "Psalms 6; Genesis 16-18" && draft.firstYear == nil && draft.weeks.allSatisfy { $0.day == nil } && draft.canSave)
}

@Test func aWeekRunsAcrossAPageBreak() throws {
    let first = gen1Header() + (0..<4).flatMap { gen1Row(wk: $0 == 1 ? "Wk" : $0 == 2 ? "17" : "", "Psalms", "\(82 + $0)", "Luke", "4-6", y: 132.8 - Double($0) * 18.5) }
    let second = gen1Row("Psalms", "86", "Luke", "16-18", y: 705.5) + gen1Week(18, psalm: 87, y: 668.6)     // the fifth row tops the next page; 37 pt on, week 18
    let table = try PlanTableReader.table(pages: [first, second])
    #expect(table.weeks.map(\.number) == [17, 18] && table.weeks.map(\.rows.count) == [5, 5] && table.weeks[0].rows[4].wisdomChapters == "86")
}

@Test func aMergedLabelIsPrintedOnceAndGivenToItsWeek() throws {
    var words = gen1Header()
    for (index, chapters) in ["11-12", "13-14", "15-16", "17-18", "19-21"].enumerated() {
        words += gen1Row(wk: index == 1 ? "Wk" : index == 2 ? "23" : "", "", "", "John", chapters, y: Gen1.top - Double(index) * 18.5)
    }
    words += cell("NT Focus Week", centre: Gen1.merged, y: Gen1.top - 2 * 18.5)                    // across both Wisdom columns, on the middle row
    let table = try PlanTableReader.table(pages: [words])
    #expect(table.weeks[0].rows.map(\.wisdomBook) == ["", "", "NT Focus Week", "", ""] && table.weeks[0].rows.allSatisfy { $0.wisdomChapters.isEmpty })
    let draft = PlanImport.draft(from: table, title: "T", today: today)
    #expect(draft.weeks[0].number == 23 && draft.weeks[0].readings.map(\.text) == ["John 11-12 (NT Focus Week)", "John 13-14 (NT Focus Week)",
        "John 15-16 (NT Focus Week)", "John 17-18 (NT Focus Week)", "John 19-21 (NT Focus Week)"])
}

@Test func aDateRowEndsAWeekAndWeeksDifferInLength() throws {
    var page = gen2Header(), y = Gen2.top
    func add(_ words: [PlanWord]) { page += words; y -= 18.5 }
    for row in 0..<4 { add(gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "1" : "", "Psalms", "\(row + 1)", "Genesis", "1-3", y: y)) }
    add(gen2Date("Sept 15 / Leader Dinner", y: y))
    for row in 0..<4 { add(gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "2" : "", "Psalms", "\(row + 5)", "Genesis", "4-6", y: y)) }
    add(gen2Date("Nov 17 - OFF", y: y))
    for row in 0..<3 { add(gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "3" : "", "", "", "Revelation", "1-3", y: y)) }
    let second = gen2Date("Feb 29", y: 705.5)                                                     // a date row that opens a page is the week before's
        + (0..<3).flatMap { gen2Row(wk: $0 == 1 ? "Wk" : $0 == 2 ? "4" : "", "NT Focus", "", "Revelation", "4-6", y: 687.0 - Double($0) * 18.5) }
        + gen2Date("Mar 7", y: 687.0 - 3 * 18.5)
    let table = try PlanTableReader.table(pages: [page, second])
    #expect(table.hasDates && table.weeks.map(\.number) == [1, 2, 3, 4] && table.weeks.map(\.rows.count) == [4, 4, 3, 3])
    #expect(table.weeks.map(\.dateText) == ["Sept 15 / Leader Dinner", "Nov 17 - OFF", "Feb 29", "Mar 7"])
    let draft = PlanImport.draft(from: table, title: "T", today: today)
    #expect(draft.firstYear == 2026 && draft.weeks.map(\.label) == ["Leader Dinner", "OFF", "", ""])
    #expect(draft.weeks.map(\.day) == [PlanDay(year: 2026, month: 9, day: 15), PlanDay(year: 2026, month: 11, day: 17), nil, PlanDay(year: 2027, month: 3, day: 7)])
    #expect(draft.weeks[2].readings.map(\.text) == ["Revelation 1-3", "Revelation 1-3", "Revelation 1-3"] && draft.weeks[3].readings[0].text == "Revelation 4-6 (NT Focus)")
    #expect(PlanReview.flags(draft, chapterCounts: [:]).map(\.kind) == [.noSuchDate])
}

@Test func aWrappedNameJoinsItsRowAndTheOddCellsRead() throws {
    // As the PDF prints a wrapped name: its first part on the row's usual line, the row itself 13.2 or 13.3 pt lower, and the row before 18.5 pt above the part.
    let top = Gen2.top
    var page = gen2Header()
    page += cell("Lamentation", centre: Gen2.wisdom, y: top - 18.5) + gen2Row(wk: "Wk", "s", "1", "Ezekiel", "22-24", y: top - 31.7)
    page += cell("1", centre: Gen2.other, y: top - 50.2) + gen2Row(wk: "9", "Job", "2", "Thessalonians", "1-3", y: top - 63.5)
    page += gen2Row("Song", "1", "Amos", "4-6", y: top - 82) + gen2Row("Psalms", "119:1-16", "2,3 John, Jude", "1", y: top - 100.5)
    page += gen2Date("Jan 4", y: top - 119)
    page += gen2Row("Proverbs", "18-19", "Obadiah", "1", y: top - 137.5) + gen2Row("", "", "Philemon", "1", y: top - 156) + gen2Date("Jan 11", y: top - 174.5)
    let draft = PlanImport.draft(from: try PlanTableReader.table(pages: [page]), title: "T", today: today)
    #expect(draft.weeks.map(\.number) == [9, 10])
    #expect(draft.weeks[0].readings.map(\.text) == ["Lamentations 1; Ezekiel 22-24", "Job 2; 1 Thessalonians 1-3", "Song 1; Amos 4-6", "Psalms 119:1-16; 2 John 1; 3 John 1; Jude 1"])
    #expect(draft.weeks[1].readings.map(\.text) == ["Proverbs 18-19; Obadiah 1", "Philemon 1"] && draft.canSave)
    #expect(try PlanReadingText.parse(draft.weeks[0].readings[2].text).get().passages[0].book == "SNG")
}

@Test func aPageWithoutTheHeaderIsNotATable() {
    #expect(throws: PlanTableReader.Failure.noHeader) { try PlanTableReader.table(pages: [gen1Week(1, psalm: 1, y: Gen1.top)]) }
    #expect(throws: PlanTableReader.Failure.noText) { try PlanTableReader.table(pages: [[], []]) }
    #expect(PlanTableReader.hasHeader(gen1Header()) && PlanTableReader.hasHeader(gen2Header()) && !PlanTableReader.hasHeader(cell("Wisdom Literature", centre: 300, y: 700)))
    #expect(PlanImport.title(forFileNamed: "Gen 1_ RTS Reading Plan.pdf") == "Gen 1 RTS Reading Plan" && PlanImport.title(forFileNamed: "plan.txt") == "plan")
}
