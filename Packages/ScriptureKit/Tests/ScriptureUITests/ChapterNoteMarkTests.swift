import Testing
@testable import ScriptureUI

@MainActor @Suite struct ChapterNoteMarkTests {
    @Test func theCountInsideThePaperStopsAtNine() {
        #expect(ChapterNoteMark.countText(1) == "1")
        #expect(ChapterNoteMark.countText(9) == "9")
        #expect(ChapterNoteMark.countText(10) == "9+")
        #expect(ChapterNoteMark.countText(42) == "9+")
    }

    @Test func voiceOverReadsTheWholeCount() {
        #expect(ChapterNoteMark.label(1) == "1 chapter note")
        #expect(ChapterNoteMark.label(2) == "2 chapter notes")
        #expect(ChapterNoteMark.label(12) == "12 chapter notes")
    }

    /// The book reader puts a mark on every chapter's opening line, so each names its chapter.
    @Test func chapterNoteMarkNamesItsChapter() {
        #expect(ChapterNoteMark.label(2, chapter: "John 3") == "2 chapter notes in John 3")
        #expect(ChapterNoteMark.label(1, chapter: "John 3") == "1 chapter note in John 3")
    }
}
