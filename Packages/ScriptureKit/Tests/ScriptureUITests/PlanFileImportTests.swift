import CoreGraphics
import Foundation
import Testing
import ScriptureData
@testable import ScriptureUI

/// Reads PDFs the tests draw, through PDFKit, at the columns and row heights of the church's two layouts.
@Suite struct PlanFileImportTests {
    private typealias Cell = PlanPDFDrawing.Cell

    private func removing<T>(_ url: URL, _ body: (URL) throws -> T) rethrows -> T {
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        return try body(url)
    }

    private func date(_ text: String, y: CGFloat) -> Cell { Cell(text: text, centre: 338, y: y, leading: true) }

    @Test func aDrawnTableWithoutDatesReadsThroughPDFKit() throws {
        var first = PlanPDFDrawing.gen1Header()
        for row in 0..<5 {
            first += PlanPDFDrawing.gen1Row(wk: row == 1 ? "Wk" : row == 2 ? "1" : "", "Psalms", "\(row + 1)", "Genesis", "\(3 * row + 1)-\(3 * row + 3)", y: 640.9 - CGFloat(row) * 18.5)
        }
        let secondTop: CGFloat = 640.9 - 4 * 18.5 - 37
        for row in 0..<4 {
            first += PlanPDFDrawing.gen1Row(wk: row == 1 ? "Wk" : row == 2 ? "2" : "", "", "", "John", "\(row + 1)", y: secondTop - CGFloat(row) * 18.5)
        }
        first.append(Cell(text: "Holidays", centre: 236.5, y: secondTop - 2 * 18.5))
        let second = PlanPDFDrawing.gen1Row("", "", "John", "5", y: 705.5)
        let url = try PlanPDFDrawing.pdf(pages: [first, second])
        let draft = try removing(url) { try PlanFileImport.draft(fromFileAt: $0, today: PlanDay(year: 2026, month: 11, day: 16)!).get() }
        #expect(draft.weeks.map(\.number) == [1, 2] && draft.weeks.map(\.readings.count) == [5, 5] && draft.title == "Drawn Plan" && draft.canSave)
        #expect(draft.weeks[0].readings[0].text == "Psalms 1; Genesis 1-3" && draft.weeks[1].readings.allSatisfy { $0.text.hasSuffix("(Holidays)") })
        #expect(draft.weeks[1].readings[4].text == "John 5 (Holidays)")
    }

    /// Three weeks of 4, 3 and 4 rows whose dates are drawn as given.
    private func drawnDatedDraft(_ dates: [String], today: PlanDay) throws -> PlanDraft {
        let top: CGFloat = 643.6
        var page = PlanPDFDrawing.gen2Header()
        page += PlanPDFDrawing.gen2Row("Psalms", "1", "Genesis", "1-3", y: top)
        page.append(Cell(text: "Lamentation", centre: 126.5, y: top - 18.5))
        page += PlanPDFDrawing.gen2Row(wk: "Wk", "s", "1", "Ezekiel", "22-24", y: top - 31.7)
        page += PlanPDFDrawing.gen2Row(wk: "1", "Psalms", "2", "Genesis", "4-6", y: top - 50.2)
        page += PlanPDFDrawing.gen2Row("Psalms", "3", "Genesis", "7-9", y: top - 68.7)
        page.append(date(dates[0], y: top - 87.2))
        var y = top - 105.7
        for (week, rows, dateText) in [(2, 3, dates[1]), (3, 4, dates[2])] {
            for row in 0..<rows {
                page += PlanPDFDrawing.gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "\(week)" : "", "Proverbs", "\(week * 4 + row)", "Exodus", "\(week * 4 + row)", y: y)
                y -= 18.5
            }
            page.append(date(dateText, y: y))
            y -= 18.5
        }
        let url = try PlanPDFDrawing.pdf(pages: [page])
        return try removing(url) { try PlanFileImport.draft(fromFileAt: $0, today: today).get() }
    }

    @Test func aDrawnTableWithDatesReadsThemAndFlagsFeb29() throws {
        // Feb 22, Feb 29 and Mar 8 keep no single weekday in any year, so the year nearest today is taken.
        let draft = try drawnDatedDraft(["Feb 22", "Feb 29", "Mar 8"], today: PlanDay(year: 2027, month: 2, day: 1)!)
        #expect(draft.weeks.map(\.number) == [1, 2, 3] && draft.weeks.map(\.readings.count) == [4, 3, 4] && draft.firstYear == 2027)
        #expect(draft.weeks.map(\.day) == [PlanDay(year: 2027, month: 2, day: 22), nil, PlanDay(year: 2027, month: 3, day: 8)])
        #expect(PlanReview.flags(draft, chapterCounts: [:]).map(\.sentence) == ["Week 2: Feb 29 is not a date in 2027. Set the date, or change the year the plan starts."])
        #expect(draft.weeks[0].readings.map(\.text).contains("Lamentations 1; Ezekiel 22-24") && draft.canSave)
    }

    @Test func aDrawnTableWithDatesAWeekApartIsPlacedInTheYearThatKeepsTheirWeekday() throws {
        // Only 2024 and 2028 keep every date on one Tuesday (a Feb 29 exists); 2028 is the nearer to today.
        let draft = try drawnDatedDraft(["Feb 22", "Feb 29", "Mar 7"], today: PlanDay(year: 2027, month: 2, day: 1)!)
        #expect(draft.firstYear == 2028 && draft.weeks.map(\.day) == [PlanDay(year: 2028, month: 2, day: 22), PlanDay(year: 2028, month: 2, day: 29), PlanDay(year: 2028, month: 3, day: 7)])
        #expect(PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
    }

    @Test func aPDFWithoutTheHeaderOrWithoutTextIsRefused() throws {
        let prose = ["In the beginning was a page of prose.", "It names Wisdom and a Chp or two,", "but it is no table of weeks."]
            .enumerated().map { Cell(text: $1, centre: 72, y: 700 - CGFloat($0) * 14, leading: true) }
        let proseURL = try PlanPDFDrawing.pdf(named: "Prose.pdf", pages: [prose])
        #expect(removing(proseURL) { PlanFileImport.draft(fromFileAt: $0, today: PlanDay(year: 2026, month: 11, day: 16)!) } == .failure(.notAPlan))

        let directory = FileManager.default.temporaryDirectory.appending(path: "PlanFileImportTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scanURL = directory.appending(path: "Scan.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(scanURL as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.setFillColor(gray: 0.4, alpha: 1)
        context.fill(CGRect(x: 72, y: 72, width: 468, height: 648))
        context.endPDFPage()
        context.closePDF()
        #expect(removing(scanURL) { PlanFileImport.draft(fromFileAt: $0, today: PlanDay(year: 2026, month: 11, day: 16)!) } == .failure(.notAPlan))
    }

    @Test func aLongPDFThatIsNotAPlanIsRefusedFromItsFirstPage() throws {
        let pages = (1...300).map { [Cell(text: "Chapter \($0). The story goes on, a line to a page.", centre: 72, y: 700, leading: true)] }
        let url = try PlanPDFDrawing.pdf(named: "Long Book.pdf", pages: pages)
        var result: Result<PlanDraft, PlanFileImport.Failure>?
        let elapsed = removing(url) { url in
            ContinuousClock().measure { result = PlanFileImport.draft(fromFileAt: url, today: PlanDay(year: 2026, month: 11, day: 16)!) }
        }
        #expect(result == .failure(.notAPlan) && elapsed < .seconds(1))
    }

    @Test func aTextFileIsReadByTheEditorsForm() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PlanFileImportTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let today = PlanDay(year: 2026, month: 11, day: 16)!

        let text = directory.appending(path: "Typed_ Plan.txt")
        try Data("Week 12 2026-11-17\nPsalms 84; Esther 7-8".utf8).write(to: text)
        let draft = try PlanFileImport.draft(fromFileAt: text, today: today).get()
        #expect(draft.weeks.count == 1 && draft.weeks[0].number == 12 && draft.weeks[0].day == PlanDay(year: 2026, month: 11, day: 17))
        #expect(draft.weeks[0].readings.map(\.text) == ["Psalms 84; Esther 7-8"] && draft.title == "Typed Plan")

        let bytes = directory.appending(path: "Bytes.txt")
        try Data([0xFF, 0xFE, 0xFD]).write(to: bytes)
        #expect(PlanFileImport.draft(fromFileAt: bytes, today: today) == .failure(.unreadableFile))
        #expect(PlanFileImport.draft(fromFileAt: directory.appending(path: "Missing.pdf"), today: today) == .failure(.unreadableFile))
    }
}
