import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct MarginMarksTests {
    private func verse(_ n: Int, _ text: String) -> Verse {
        Verse(id: VerseLocation(book: "JHN", chapter: 15, verse: n), translationID: "ESV", endVerse: nil, text: text, breakAfter: false)
    }
    private let yellow = MarkupColor(lightHex: "#FFE86B", darkHex: "#6B5B00")
    // "1 I am the true vine. 2 Every branch in me. 3 Already you are clean.", after John 15's label.
    private var chapter: [Verse] {
        [verse(1, "I am the true vine."), verse(2, "Every branch in me."), verse(3, "Already you are clean.")]
    }
    private var layout: BookLayout {
        BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "JHN", chapter: 15), verses: chapter)],
                         opening: BookOpening(bookName: "John", title: BookTitle(title: "John", subtitle: nil)), typography: .default)
    }

    private func item(_ verse: Int, _ start: Int, _ end: Int, id: UUID = UUID(), note: Bool = true) -> MarkupItem {
        MarkupItem(id: id, chapter: 15, verse: verse, endVerse: verse, startOffset: start, endOffset: end, translationID: "ESV", color: yellow, hasNote: note)
    }

    private func note(id: UUID = UUID(), highlightID: UUID?, chapter: Bool = false, draft: Bool = false) -> NoteCard {
        NoteCard(id: id, highlightID: highlightID, referenceString: chapter ? "John 15" : "John 15:2", quotedText: "",
                 body: draft ? "" : "A note.", modifiedAt: Date(timeIntervalSince1970: 0), color: chapter ? nil : yellow,
                 isChapterNote: chapter, isDraft: draft)
    }

    private func marks(notes: [NoteCard] = [], items: [MarkupItem] = [], bookmarks: [Int] = []) -> [MarginMark] {
        MarginMark.build(notesByChapter: [15: notes], itemsByChapter: [15: items], bookmarksByChapter: [15: bookmarks], layout: layout)
    }

    @Test func aNoteMarksTheLineItsHighlightStartsOn() {
        let highlight = item(2, 6, 12)   // "branch"
        let noteID = UUID()
        let marks = marks(notes: [note(id: noteID, highlightID: highlight.id)], items: [highlight])
        #expect(marks.count == 1)
        #expect(marks[0].id == "note:\(noteID.uuidString)")
        #expect(marks[0].kind == .note(noteID: noteID, highlightID: highlight.id))
        #expect(marks[0].verse == VerseLocation(book: "JHN", chapter: 15, verse: 2))
        #expect(marks[0].characterIndex == layout.spans[1].textRange.location + 6)
    }

    @Test func aBookmarkMarksItsVersesFirstLine() {
        #expect(marks(bookmarks: [3]) == [MarginMark(id: "bookmark:15:3", kind: .bookmark, verse: VerseLocation(book: "JHN", chapter: 15, verse: 3), characterIndex: layout.spans[2].textRange.location)])
        // A bookmark on a verse the chapter lacks has no mark.
        #expect(marks(bookmarks: [9]).isEmpty)
    }

    @Test func aNoteComesBeforeABookmarkOnTheSameLine() {
        let highlight = item(2, 0, 5)    // "Every", where verse 2's text starts
        let noteID = UUID()
        let marks = marks(notes: [note(id: noteID, highlightID: highlight.id)], items: [highlight], bookmarks: [3, 2])
        #expect(marks.map(\.id) == ["note:\(noteID.uuidString)", "bookmark:15:2", "bookmark:15:3"])
        #expect(marks[0].characterIndex == marks[1].characterIndex)
        #expect(marks.map(\.characterIndex) == marks.map(\.characterIndex).sorted())
    }

    @Test func aChapterNoteOrADraftHasNoMarginMark() {
        let highlight = item(1, 0, 1, note: false)
        #expect(marks(notes: [note(highlightID: nil, chapter: true), note(highlightID: highlight.id, draft: true)], items: [highlight]).isEmpty)
    }

    // MARK: Book layout

    private func card(id: UUID = UUID(), highlightID: UUID?, chapterNote: Bool = false) -> NoteCard {
        NoteCard(id: id, highlightID: highlightID, referenceString: "John", quotedText: "", body: "A note.",
                 modifiedAt: Date(timeIntervalSince1970: 0), color: chapterNote ? nil : yellow, isChapterNote: chapterNote)
    }

    private func johnItem(_ chapter: Int, _ verse: Int, _ start: Int, id: UUID = UUID()) -> MarkupItem {
        MarkupItem(id: id, chapter: chapter, verse: verse, endVerse: verse, startOffset: start, endOffset: start + 5,
                   translationID: "ESV", color: yellow, hasNote: true)
    }

    /// A bookmark's mark names its chapter and verse, at the verse's first character.
    @Test func aBookmarksMarkNamesItsChapterAndVerse() {
        let book = JohnFixture.layout(3...3)
        let marks = MarginMark.build(notesByChapter: [:], itemsByChapter: [:], bookmarksByChapter: [3: [3, 16]], layout: book)
        #expect(marks.map(\.id) == ["bookmark:3:3", "bookmark:3:16"])
        #expect(marks.map(\.verse) == [3, 16].map { VerseLocation(book: "JHN", chapter: 3, verse: $0) })
        #expect(marks.map(\.characterIndex) == [3, 16].map { book.span(for: VerseLocation(book: "JHN", chapter: 3, verse: $0))!.textRange.location })
    }

    @Test func aNoteInTheOpenChapterMarksItsHighlightsLine() {
        let book = JohnFixture.layout(3...3)
        let first = johnItem(3, 4, 6), second = johnItem(3, 16, 0)
        let firstNote = card(highlightID: first.id), secondNote = card(highlightID: second.id)
        let marks = MarginMark.build(
            notesByChapter: [3: [firstNote, secondNote, card(highlightID: nil, chapterNote: true)]],
            itemsByChapter: [3: [first, second]], bookmarksByChapter: [3: [16, 99]], layout: book)
        let sixteen = book.span(for: VerseLocation(book: "JHN", chapter: 3, verse: 16))!
        #expect(marks.map(\.id) == ["note:\(firstNote.id.uuidString)", "note:\(secondNote.id.uuidString)", "bookmark:3:16"])
        #expect(marks[0].characterIndex == book.span(for: VerseLocation(book: "JHN", chapter: 3, verse: 4))!.textRange.location + 6)
        #expect(marks[1].kind == .note(noteID: secondNote.id, highlightID: second.id))
        #expect(marks[1].verse == VerseLocation(book: "JHN", chapter: 3, verse: 16) && marks[1].characterIndex == sixteen.textRange.location)
        // A note before a bookmark on the same line; a chapter the layout does not show has no marks.
        #expect(marks[2].characterIndex == marks[1].characterIndex)
        let other = johnItem(2, 1, 0)
        #expect(MarginMark.build(notesByChapter: [2: [card(highlightID: other.id)]], itemsByChapter: [2: [other]],
                                 bookmarksByChapter: [2: [1]], layout: book).isEmpty)
    }
}
