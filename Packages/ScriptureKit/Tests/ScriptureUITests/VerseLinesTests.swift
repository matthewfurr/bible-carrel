import CoreGraphics
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct VerseLinesTests {
    private func ref(_ code: String, _ chapter: Int, _ verse: Int, _ end: Int? = nil) -> Reference {
        Reference(book: BookCatalog.book(code: code)!, chapter: chapter, verse: verse, endVerse: end)
    }

    private func manyLines(_ count: Int) -> [VerseLine] {
        (1...count).map { VerseLine(chapter: $0, runs: [ref("PSA", $0, 1)]) }
    }

    @Test func runsGroupIntoOneLinePerChapter() {
        let book = BookCatalog.book(code: "MAT")!
        let lines = VerseLines.lines([ref("MAT", 1, 18, 20), ref("MAT", 1, 24), ref("MAT", 2, 1)], book: book)
        #expect(lines.map(\.chapter) == [1, 2])
        #expect(lines[0].runs.map(VerseLines.runText) == ["18-20", "24"])
        #expect(lines[1].runs.map(VerseLines.runText) == ["1"])
        #expect(lines[0].runs[0].displayString == "Matthew 1:18-20")
        #expect(lines.map(\.id) == [1, 2])
    }

    @Test func aOneChapterBookHasNoChapterNumber() {
        let book = BookCatalog.book(code: "JUD")!
        let lines = VerseLines.lines([ref("JUD", 1, 9), ref("JUD", 1, 14, 15)], book: book)
        #expect(lines.count == 1 && lines[0].chapter == nil && lines[0].id == 0)
        #expect(lines[0].runs.map(VerseLines.runText) == ["9", "14-15"])
    }

    @Test func twelveLinesShowThenTheRestFold() {
        let lines = manyLines(23)
        let folded = VerseLines.shown(lines, showingAll: false)
        #expect(folded.lines.count == 12 && folded.hidden == 11)
        #expect(VerseLines.moreLine(11) == "11 more chapters" && VerseLines.moreLine(1) == "1 more chapter")
        let all = VerseLines.shown(lines, showingAll: true)
        #expect(all.lines.count == 23 && all.hidden == 0)
        let twelve = VerseLines.shown(manyLines(12), showingAll: false)
        #expect(twelve.lines.count == 12 && twelve.hidden == 0)
    }

    @Test func runsReadInFullWords() {
        #expect(VerseLines.spoken(ref("2SA", 1, 1, 5)) == "2 Samuel 1:1 to 5")
        #expect(VerseLines.spoken(ref("2SA", 1, 11)) == "2 Samuel 1:11")
        #expect(VerseLines.chapterSpoken(3) == "Chapter 3")
    }

    /// Matt, 2026-11-24: "add 'Ch ' before those chapter numbers so it is clear to the user what it is". VoiceOver
    /// still says the word; the column is as wide as the widest label, "Ch 150", so every number ends on one edge.
    @Test func aChapterNumberIsLabelledCh() {
        #expect(VerseLines.chapterLabel(11) == "Ch 11")
        // One unit with one space, right-aligned as a whole in the width of the widest label (the coordinator's fix:
        // "Ch" was held at the column's left edge, which read "Ch   29").
        #expect(VerseLines.widestChapterLabel == "Ch 000")
        #expect(VerseLines.chapterSpoken(11) == "Chapter 11")
    }

    @Test func aComeBackPastTheTwelfthLineShowsThemAll() {
        let lines = manyLines(23)
        #expect(VerseLines.showsAll(lines, anchor: ref("PSA", 13, 1)))
        #expect(!VerseLines.showsAll(lines, anchor: ref("PSA", 3, 1)))
        #expect(!VerseLines.showsAll(lines, anchor: nil))
    }

    /// A book's group of `count` references, every other verse of its first chapter.
    private func group(_ code: String, _ count: Int) -> VerseGroup {
        let book = BookCatalog.book(code: code)!
        let references = (1...count).map { ref(code, 1, 2 * $0) }
        return VerseGroup(book: book, count: count, references: references, lines: VerseLines.lines(references, book: book))
    }

    /// Matt's heading C (2026-11-24) on Matt's one section (2026-11-24: "all ... in one section with the heading
    /// 'References'"): the heading in the page face, the page's whole count beside it in the system face, apart, not
    /// one "References · 945 verses" label; VoiceOver reads them as one.
    @Test func theReferencesHeadingCountsEveryVerseOfThePage() {
        #expect(LibraryReferences.title == "References")
        #expect(LibraryReferences.count(226) == "226 verses")
        #expect(LibraryReferences.count(1) == "1 verse")
        #expect(LibraryReferences.count(1_009) == "1,009 verses")
        let references = LibraryReferences(here: group("EZR", 3), elsewhere: [group("1CH", 2), group("NEH", 4)])
        #expect(references.total == 9)
        #expect(LibraryPageHeading.spoken(LibraryReferences.title, count: LibraryReferences.count(1_009)) == "References, 1,009 verses")
        #expect(LibraryPageHeading.spoken("Family", count: nil) == "Family")
    }

    /// Matt: "The first book listed is the book the user navigated from ... The first book will be expanded by
    /// default"; the others follow in Bible order, collapsed.
    @Test func theBookOpenedFromLeadsOpenAndTheRestFollowInBibleOrderClosed() {
        let many = LibraryReferences(here: group("EZR", 30), elsewhere: [group("1CH", 6), group("NEH", 8)])
        #expect(many.groups.map(\.book.id) == ["EZR", "1CH", "NEH"])
        #expect(!many.opensEveryBook)
        #expect(many.isOpen("EZR", toggled: []))
        #expect(!many.isOpen("1CH", toggled: []) && !many.isOpen("NEH", toggled: []))
    }

    /// With few references every book is open at first, the first among them, as Elsewhere's books were.
    @Test func withFewReferencesEveryBookIsOpenAtFirst() {
        let few = LibraryReferences(here: group("EZR", 3), elsewhere: [group("1CH", 2), group("NEH", 4)])
        #expect(few.opensEveryBook)
        #expect(few.groups.allSatisfy { few.isOpen($0.book.id, toggled: []) })
        #expect(!few.isOpen("NEH", toggled: few.toggling("NEH", in: [])))
    }

    /// A page opened from no book (the whole Bible), or from a book that does not name them: every book in Bible
    /// order, none first.
    @Test func aPageOpenedFromNoBookListsEveryBookInBibleOrder() {
        let whole = LibraryReferences(here: nil, elsewhere: [group("GEN", 30), group("PSA", 20)])
        #expect(whole.groups.map(\.book.id) == ["GEN", "PSA"] && whole.firstBook == nil && whole.total == 50)
        #expect(!whole.isOpen("GEN", toggled: []) && !whole.isOpen("PSA", toggled: []))
        #expect(whole.isOpen("PSA", toggled: whole.toggling("PSA", in: [])))
    }

    /// The reader's own open and closed books are kept against how the page opens, so a first book closed stays
    /// closed while the page stays (nothing has to be seeded, so nothing seeds it open again), and a second click opens it.
    @Test func aFirstBookClosedByTheReaderStaysClosed() {
        let references = LibraryReferences(here: group("EZR", 40), elsewhere: [group("1CH", 6)])
        let closed = references.toggling("EZR", in: [])
        #expect(!closed.isEmpty && !references.isOpen("EZR", toggled: closed))
        let opened = references.toggling("1CH", in: closed)
        #expect(!references.isOpen("EZR", toggled: opened) && references.isOpen("1CH", toggled: opened))
        #expect(references.isOpen("EZR", toggled: references.toggling("EZR", in: closed)))
    }

    /// Coming back from a passage opens the run's book, the first one too where the reader had closed it, and leaves
    /// every other book as the reader left it; a book already open, or not on the page, is left alone.
    @Test func theComeBackOpensTheRunsBookAndLeavesTheOthers() {
        let references = LibraryReferences(here: group("EZR", 30), elsewhere: [group("1CH", 6), group("NEH", 8)])
        let closedFirst = references.toggling("EZR", in: [])
        let back = references.opening("EZR", in: closedFirst)
        #expect(references.isOpen("EZR", toggled: back))
        let toNehemiah = references.opening("NEH", in: closedFirst)
        #expect(references.isOpen("NEH", toggled: toNehemiah) && !references.isOpen("EZR", toggled: toNehemiah))
        #expect(!references.isOpen("1CH", toggled: toNehemiah))
        #expect(references.opening("EZR", in: []) == [])
        #expect(references.opening("GEN", in: closedFirst) == closedFirst)
    }

    /// A book's row reads its name, then its count and whether it is open.
    @Test func aBooksRowReadsItsCountAndWhetherItIsOpen() {
        #expect(LibraryReferencesSection.spokenValue(count: 945, isOpen: true) == "945 verses, expanded")
        #expect(LibraryReferencesSection.spokenValue(count: 1, isOpen: false) == "1 verse, collapsed")
    }

    @Test func aClickAnchorsAtTheRun() {
        let frame = CGRect(x: 40, y: 0, width: 30, height: 16)
        #expect(VerseLineView.anchorRect(2, frames: [2: frame]) == frame)
        #expect(VerseLineView.anchorRect(1, frames: [2: frame]) == nil)
    }

    @Test func arrowsWalkTheRunsAndStopAtTheEnds() {
        var focus = VerseLineFocus()
        focus.enter()
        #expect(focus.index == 0)
        var handled = focus.move(1, count: 3)
        #expect(handled && focus.index == 1)
        handled = focus.move(1, count: 3)
        #expect(handled && focus.index == 2)
        handled = focus.move(1, count: 3)
        #expect(handled && focus.index == 2)
        focus.enter()
        handled = focus.move(-1, count: 3)
        #expect(handled && focus.index == 0)
        var unfocused = VerseLineFocus()
        handled = unfocused.move(1, count: 3)
        #expect(!handled && unfocused.index == nil)
    }

    @Test func returnOpensThePopoverAtTheFocusedRun() {
        let frames = [0: CGRect(x: 0, y: 0, width: 24, height: 16), 1: CGRect(x: 32, y: 0, width: 40, height: 16)]
        #expect(VerseLineView.popoverAnchor(focus: VerseLineFocus(index: 1), frames: frames) == frames[1])
        #expect(VerseLineView.popoverAnchor(focus: VerseLineFocus(), frames: frames) == nil)
    }

    @Test func tabGoesLineToLineThenOnToTheControlsAround() {
        #expect(VerseLineFocus.entryLine(backward: false, count: 12) == 0)
        #expect(VerseLineFocus.entryLine(backward: true, count: 12) == 11)
        #expect(VerseLineFocus.nextLine(from: 0, backward: false, count: 12) == 1)
        #expect(VerseLineFocus.nextLine(from: 11, backward: false, count: 12) == nil)
        #expect(VerseLineFocus.nextLine(from: 3, backward: true, count: 12) == 2)
        #expect(VerseLineFocus.nextLine(from: 0, backward: true, count: 12) == nil)
        #expect(VerseLineFocus.nextLine(from: 0, backward: false, count: 1) == nil)
    }

    @Test func aLineTabbedToIsScrolledIntoViewByItsID() {
        let lines = manyLines(23)
        #expect(VerseLinesView.revealID(bookID: "PSA", lines: lines, at: 19) == LibraryScrollID.line("PSA", 20))
        #expect(VerseLinesView.revealID(bookID: "PSA", lines: lines, at: 23) == nil)
        let jude = VerseLines.lines([ref("JUD", 1, 9)], book: BookCatalog.book(code: "JUD")!)
        #expect(VerseLinesView.revealID(bookID: "JUD", lines: jude, at: 0) == LibraryScrollID.line("JUD", nil))
    }

    @Test func onlyEscOrOpenGiveTheKeyboardBackToTheLine() {
        #expect(VerseLineView.takesFocusBack(after: .escape, openedFromKeyboard: true))
        #expect(VerseLineView.takesFocusBack(after: .open, openedFromKeyboard: true))
        #expect(!VerseLineView.takesFocusBack(after: .elsewhere, openedFromKeyboard: true))
        #expect(!VerseLineView.takesFocusBack(after: .escape, openedFromKeyboard: false))
        #expect(!VerseLineView.takesFocusBack(after: .open, openedFromKeyboard: false))
    }

    @Test(.needsRealBible) func theComeBackOpensTheLinesAndScrollsToTheChapter() throws {
        let david = try #require(try PersonPage.load(994, inBook: "2SA", store: BenchmarkChapter.realStore()))
        let past = ref("2SA", 20, 1)
        #expect(LibraryVersesAnchor.initialChapters(here: david.here, elsewhere: david.elsewhere, anchor: past) == ["2SA"])
        #expect(LibraryVersesAnchor.scrollID(past) == LibraryScrollID.line("2SA", 20))
        #expect(LibraryVersesAnchor.initialChapters(here: david.here, elsewhere: david.elsewhere, anchor: ref("2SA", 3, 1)).isEmpty)
        #expect(LibraryVersesAnchor.initialChapters(here: david.here, elsewhere: david.elsewhere, anchor: nil).isEmpty)
        // 2 Samuel is the first book under References, open at first as "In 2 Samuel" was, the page's 896 verses counted.
        let references = LibraryReferences(here: david.here, elsewhere: david.elsewhere)
        #expect(references.groups.first?.book.id == "2SA" && references.groups.count == 28)
        #expect(references.isOpen("2SA", toggled: []) && references.total == 896)
        #expect(LibraryVersesAnchor.scrollTarget(past, in: references.groups) == LibraryScrollID.line("2SA", 20))
    }

    @Test func aOneChapterBooksLineHasNoChapterInItsScrollID() {
        #expect(LibraryVersesAnchor.scrollID(ref("JUD", 1, 9)) == LibraryScrollID.line("JUD", nil))
    }
}
