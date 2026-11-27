import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The Mac's contents page (spec 4.1 to 4.4): the chosen book, a click and a double-click, search
/// dimming and choosing, the columns, and the arrows across them.
@Suite struct ContentsPageTests {
    private let sixtySix = BookCatalog.all.filter { $0.canon != .apocrypha }.map { TranslationBook(book: $0, chapterCount: 28) }
    private let apocrypha = BookCatalog.all.filter { $0.canon == .apocrypha }.map { TranslationBook(book: $0, chapterCount: 28) }

    @Test func thePageOpensOnTheBookBeingReadAndAClickChooses() {
        var page = ContentsPage(books: sixtySix, reading: ChapterLocation(book: "JHN", chapter: 15), chosenBookID: nil)
        #expect(page.chosenBookID == "JHN" && page.testaments.map(\.title) == ["Old Testament", "New Testament"])
        #expect(page.testaments.map(\.countLabel) == ["39 books", "27 books"] && page.testaments[0].blocks.map(\.books.count) == [5, 12, 5, 5, 12])
        page.choose("ROM")
        #expect(page.chosenBookID == "ROM" && page.target(opening: "ROM") == .chapter(ChapterLocation(book: "ROM", chapter: 1)) && page.target(opening: "JHN") == .resume)
        #expect(ContentsPage(books: sixtySix, reading: nil, chosenBookID: "XYZ").chosenBookID == "GEN")
        #expect(ContentsPage(books: sixtySix + apocrypha, reading: nil, chosenBookID: nil).testaments.map(\.title) == ["Old Testament", "New Testament", "Apocrypha"])
    }

    @Test func fourColumnsAreTheMockupsAndFewerStackTheTestaments() {
        let page = ContentsPage(books: sixtySix + apocrypha, reading: nil, chosenBookID: nil)
        func heads(_ section: ContentsPage.Section) -> [[String]] {
            section.columns.map { column in column.compactMap { if case .group(let group) = $0 { group.title } else { nil } } }
        }
        #expect(ContentsPage(books: sixtySix, reading: nil, chosenBookID: nil).bookNames.count == 66 && page.bookNames.first == "Genesis")
        let four = page.layout(columns: 4)
        #expect(four.bands.map { $0.map(\.testament.title) } == [["Old Testament", "New Testament"], ["Apocrypha"]])
        #expect(heads(four.bands[0][0]) == [["Law", "History"], ["Poetry & Wisdom", "Major Prophets", "Minor Prophets"]])
        // `BookGroup.title` (Task 2) writes the apostrophe straight; the plan's test wrote it curly.
        #expect(heads(four.bands[0][1]) == [["Gospels & Acts", "Paul's Letters"], ["General Letters", "Revelation"]])
        #expect(four.bands[1][0].columns.count == 4 && heads(four.bands[1][0]).map(\.count) == [1, 0, 0, 0])   // one group, broken between books
        #expect(page.layout(columns: 5).bands[0].map(\.columns.count) == [3, 2])
        #expect(heads(page.layout(columns: 6).bands[0][0]) == [["Law", "History"], ["Poetry & Wisdom", "Major Prophets"], ["Minor Prophets"]])   // the most even
        #expect(page.layout(columns: 3).bands.map { $0.map(\.columns.count) } == [[3], [3], [3]] && page.layout(columns: 1).bands.count == 3)
        #expect(ContentsPage.columnCount(width: 792, minimumColumnWidth: 180) == 4 && ContentsPage.columnCount(width: 100, minimumColumnWidth: 180) == 1)
    }

    @Test func typingDimsAndChoosesAndAReferenceRingsItsChapter() {
        var page = ContentsPage(books: sixtySix, reading: ChapterLocation(book: "JHN", chapter: 15), chosenBookID: nil)
        page.setQuery("rom 8")
        #expect(page.chosenBookID == "ROM" && page.ringedChapter == 8 && page.isDimmed("GEN") && !page.isDimmed("ROM"))
        #expect(page.submitTarget == .reference(Reference(book: BookCatalog.book(code: "ROM")!, chapter: 8)))
        page.setQuery("1")                                                   // the numbered books, the first of them chosen
        #expect(page.chosenBookID == "1SA" && page.matches?.isSuperset(of: ["1SA", "1KI", "1CO"]) == true && page.ringedChapter == nil)
        #expect(page.submitTarget == .chapter(ChapterLocation(book: "1SA", chapter: 1)))
        page.setQuery("zzz")
        #expect(page.hasNoMatch && page.submitTarget == nil && page.chosenBookID == "1SA" && page.isDimmed("1SA"))
        page.setQuery("")
        #expect(page.matches == nil && !page.isDimmed("GEN") && !page.hasNoMatch && page.chosenBookID == "1SA")
        #expect(page.submitTarget == nil)                                    // Return with nothing typed opens nothing
    }

    @Test func theArrowsWalkDownAColumnAndAcrossColumns() {
        let page = ContentsPage(books: sixtySix, reading: nil, chosenBookID: nil), layout = page.layout(columns: 4)
        func move(_ move: ContentsPage.Move, from id: String) -> String? { page.bookID(moving: move, from: id, in: layout) }
        #expect(move(.down, from: "DEU") == "JOS" && move(.down, from: "EST") == "JOB" && move(.up, from: "JOB") == "EST")
        #expect(move(.right, from: "GEN") == "JOB" && move(.right, from: "JOB") == "MAT" && move(.right, from: "MAT") == "HEB")
        #expect(move(.right, from: "EST") == "NAM" && move(.left, from: "MAL") == "EST")       // the same place down; held to the last book
        #expect(move(.right, from: "HEB") == nil && move(.left, from: "GEN") == nil && move(.up, from: "GEN") == nil && move(.down, from: "REV") == nil)
    }
}
