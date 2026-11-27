import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

/// Undoable deletes: what `MarkupStore.delete(_:)` removes, `restore(_:)` puts back exactly, and a
/// second delete (redo) removes it again.
@MainActor @Suite struct MarkupRestoreTests {
    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)

    private func makeStore() throws -> MarkupStore {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        return MarkupStore(container: container)
    }

    private func add(_ store: MarkupStore, verse: Int, color: UUID? = nil) throws -> Highlight {
        try store.addHighlight(book: "MAT", chapter: 5, verse: verse, endVerse: verse, startOffset: 2, endOffset: 9, translationID: "ESV", colorID: color, quotedText: "blessed")
    }

    @Test func aNoteDeletedWithItsColorlessAnchorComesBackWithIt() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3)
        let note = try store.addNote(to: highlight, body: "poor in spirit")
        let (noteID, highlightID, created) = (note.uuid, highlight.uuid, note.createdAt)

        let deletion = try #require(try store.delete(.note(NoteSnapshot(note), anchor: nil)))
        #expect(try store.highlights(in: matthew5).isEmpty && store.notes(in: matthew5).isEmpty)

        try store.restore(deletion)
        let restored = try #require(try store.highlights(in: matthew5).first)
        #expect(restored.uuid == highlightID && restored.startOffset == 2 && restored.endOffset == 9 && restored.colorID == nil)
        #expect(restored.note?.uuid == noteID && restored.note?.body == "poor in spirit" && restored.note?.createdAt == created)

        // Redo deletes it again; a second restore is again exact.
        let again = try #require(try store.delete(deletion))
        #expect(try store.notes(in: matthew5).isEmpty)
        try store.restore(again)
        #expect(try store.notes(in: matthew5).map(\.uuid) == [noteID])
    }

    @Test func aNoteDeletedFromAColoredHighlightReattachesToIt() throws {
        let store = try makeStore()
        let yellow = try store.colors()[0].uuid
        let highlight = try add(store, verse: 3, color: yellow)
        let note = try store.addNote(to: highlight, body: "meek")
        let deletion = try #require(try store.delete(.note(NoteSnapshot(note), anchor: nil)))
        #expect(try store.highlights(in: matthew5).count == 1)
        try store.restore(deletion)
        let found = try store.highlights(in: matthew5)
        #expect(found.count == 1 && found[0].note?.body == "meek" && found[0].colorID == yellow)
    }

    @Test func aHighlightComesBackWithItsNote() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 4, color: try store.colors()[2].uuid)
        try store.addNote(to: highlight, body: "mourn")
        let deletion = try #require(try store.delete(.highlight(HighlightSnapshot(highlight))))
        #expect(try store.highlights(in: matthew5).isEmpty && store.notes(in: matthew5).isEmpty)
        try store.restore(deletion)
        let found = try store.highlights(in: matthew5)
        #expect(found.count == 1 && found[0].note?.body == "mourn")
    }

    @Test func aChapterNoteAndABookmarkComeBack() throws {
        let store = try makeStore()
        let chapterNote = Note(body: "Sermon on the Mount", scope: .chapter, book: "MAT", chapter: 5, verse: 1, endVerse: 1, translationID: "ESV", quotedText: "")
        store.context.insert(chapterNote)
        try store.toggleBookmark(at: VerseLocation(book: "MAT", chapter: 5, verse: 9))
        try store.context.save()
        let bookmark = try #require(try store.bookmarks(in: matthew5).first)

        let noteDeletion = try #require(try store.delete(.note(NoteSnapshot(chapterNote), anchor: nil)))
        let bookmarkDeletion = try #require(try store.delete(.bookmark(BookmarkSnapshot(bookmark))))
        #expect(try store.notes(in: matthew5).isEmpty && store.bookmarks(in: matthew5).isEmpty)
        try store.restore(noteDeletion)
        try store.restore(bookmarkDeletion)
        #expect(try store.notes(in: matthew5).map(\.body) == ["Sermon on the Mount"])
        #expect(try store.bookmarks(in: matthew5).map(\.verse) == [9])
    }

    /// Keeping data safe 6: a note put back by an undo carries its mark, where its sitting started and its kind.
    @Test func anUndoneDeleteBringsBackANotesThreeValues() throws {
        let store = MarkupStore(container: try MarkupContainer.make(inMemory: true), journal: LastTextJournal(directory: nil, deviceTag: "aaaa"), deviceKind: "iPhone")
        let yellow = UUID()
        let first = try store.addNote(to: try add(store, verse: 6, color: yellow), body: "hunger")
        try store.updateNote(first, body: "hunger and thirst")
        let second = try store.addNote(to: try add(store, verse: 7, color: yellow), body: "merciful")
        let values = { (note: Note) in [note.versionMark, note.versionAncestry, note.deviceKind] }
        let (firstValues, secondValues) = (values(first), values(second))
        #expect(firstValues.allSatisfy { $0 != nil } && secondValues.allSatisfy { $0 != nil })
        let (firstID, secondID) = (first.uuid, second.uuid)

        let noteDeletion = try #require(try store.delete(.note(NoteSnapshot(first), anchor: nil)))
        let anchor = try #require(try store.highlights(in: matthew5).first { $0.verse == 7 })
        let highlightDeletion = try #require(try store.delete(.highlight(HighlightSnapshot(anchor))))
        try store.restore(noteDeletion)
        try store.restore(highlightDeletion)
        #expect(values(try #require(try store.note(id: firstID))) == firstValues)
        #expect(values(try #require(try store.note(id: secondID))) == secondValues)
    }

    @Test func restoringTwiceOrDeletingWhatIsGoneChangesNothing() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 5, color: try store.colors()[0].uuid)
        let deletion = try #require(try store.delete(.highlight(HighlightSnapshot(highlight))))
        try store.restore(deletion)
        try store.restore(deletion)
        #expect(try store.highlights(in: matthew5).count == 1)
        _ = try store.delete(deletion)
        #expect(try store.delete(deletion) == nil)
    }
}
