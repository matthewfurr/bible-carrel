import Foundation
import SwiftData
import Testing
@testable import ScriptureModel

/// Every save of a note's text marks it with its sitting and journals it; a delete leaves a marker.
@MainActor @Suite struct NoteSittingTests {
    private let container: ModelContainer
    private let journal: LastTextJournal
    private let store: MarkupStore
    private let base: Note

    init() throws {
        container = try MarkupContainer.make(inMemory: true)
        journal = LastTextJournal(directory: nil, deviceTag: "aaaa")
        store = MarkupStore(container: container, journal: journal, deviceKind: "Mac")
        base = try store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "base", sourceThreadID: nil)
    }

    private func d(_ text: String) -> String { NoteVersion.digest(text) }

    private func markers() throws -> [DeletionMarker] { try store.context.fetch(FetchDescriptor<DeletionMarker>()) }

    private func highlight(verse: Int, start: Int = 3, end: Int = 11) throws -> Highlight {
        try store.addHighlight(book: "GEN", chapter: 1, verse: verse, endVerse: verse, startOffset: start, endOffset: end,
                               translationID: "WEB", colorID: UUID(), quotedText: "the beginning")
    }

    @Test func everySaveWritesTheMarkAndTheFirstWritesWhereItStartedAndTheKind() throws {
        let sitting = try #require(try store.beginSitting(noteID: base.uuid))
        #expect(sitting.ancestry == "\(sitting.token):aaaa\(d("base"))")
        #expect(sitting.token.hasPrefix("aaaa") && sitting.deviceKind == "Mac" && sitting.noteID == base.uuid)
        #expect(store.openSittings == [base.uuid])
        for text in ["a", "ab", "abc"] {
            try store.updateNote(base, body: text, sitting: sitting)
            #expect(base.versionMark == "\(sitting.token).\(d(text))")
            #expect(base.versionAncestry == sitting.ancestry)
            #expect(base.deviceKind == "Mac")
        }
        let entry = try #require(journal.entry(for: base.uuid))
        #expect(entry.body == "abc" && entry.book == "GEN" && entry.chapter == 1 && entry.verse == 0)
        store.endSitting(sitting)
        #expect(store.openSittings.isEmpty)
    }

    @Test func aSaveWithNoSittingIsASittingOfItsOwn() throws {
        try store.updateNote(base, body: "one")
        let first = try #require(NoteVersion.token(ofMark: base.versionMark))
        try store.updateNote(base, body: "two")
        let second = try #require(NoteVersion.token(ofMark: base.versionMark))
        #expect(first != second)
        #expect(base.versionAncestry == "\(second):aaaa\(d("one"))")
        #expect(store.openSittings.isEmpty)
    }

    @Test func aSaveNamesItsOwnStartAgainWhenAnotherDevicesValuesArrived() throws {
        let sitting = try #require(try store.beginSitting(noteID: base.uuid))
        try store.updateNote(base, body: "mine", sitting: sitting)
        base.body = "theirs"
        base.versionMark = NoteVersion.mark(token: "bbbb12345678", text: "theirs")
        base.versionAncestry = "bbbb12345678:"
        base.deviceKind = "iPhone"
        try store.context.save()

        try store.updateNote(base, body: "mine again", sitting: sitting)
        #expect(base.versionAncestry == sitting.ancestry)
        #expect(base.versionMark == "\(sitting.token).\(d("mine again"))")
        #expect(base.deviceKind == "Mac")
    }

    @Test func aNewNoteWithTextIsMarkedAndAnEmptyOneIsNot() throws {
        let made = try store.addChapterNote(book: "GEN", chapter: 2, translationID: "WEB", body: "x", sourceThreadID: nil)
        let token = try #require(NoteVersion.token(ofMark: made.versionMark))
        #expect(made.versionMark == "\(token).\(d("x"))" && made.versionAncestry == "\(token):" && made.deviceKind == "Mac")
        #expect(journal.entry(for: made.uuid)?.body == "x")

        let empty = try store.addNote(to: try highlight(verse: 1), body: "")
        #expect(empty.versionMark == nil && empty.versionAncestry == nil && empty.deviceKind == nil)
        #expect(journal.entry(for: empty.uuid) == nil)

        let anchored = try store.addNote(to: try highlight(verse: 2, start: 4, end: 17), body: "on it")
        let entry = try #require(journal.entry(for: anchored.uuid))
        #expect(entry.startOffset == 4 && entry.endOffset == 17 && entry.verse == 2)
        #expect(NoteVersion.isMarked(text: "on it", mark: anchored.versionMark))
    }

    @Test func anEmptiedNoteLeavesTheJournal() throws {
        #expect(journal.entry(for: base.uuid) != nil)
        try store.updateNote(base, body: " \n")
        #expect(journal.entry(for: base.uuid) == nil)
    }

    @Test func deletingANoteLeavesAMarkerAndForgetsItsText() throws {
        try store.updateNote(base, body: "edited")
        let version = NoteVersion.deleted(text: base.body, mark: base.versionMark, ancestry: base.versionAncestry)
        let id = base.uuid
        let now = Date(timeIntervalSince1970: 1_000_000)
        try store.deleteNote(base, now: now)
        let found = try markers()
        #expect(found.count == 1)
        #expect(found.first?.noteID == id && found.first?.version == version && found.first?.deletedAt == now)
        #expect(journal.entry(for: id) == nil)

        let anchor = try highlight(verse: 3)
        let note = try store.addNote(to: anchor, body: "on the anchor")
        let noteID = note.uuid
        let anchoredVersion = NoteVersion.deleted(text: note.body, mark: note.versionMark, ancestry: note.versionAncestry)
        try store.deleteHighlight(anchor, now: now)
        let second = try markers().filter { $0.noteID == noteID }
        #expect(second.count == 1 && second.first?.version == anchoredVersion && second.first?.deletedAt == now)
        #expect(journal.entry(for: noteID) == nil)

        let empty = try store.addNote(to: try highlight(verse: 4), body: "")
        try store.deleteNote(empty, now: now)
        #expect(try markers().count == 2)
    }

    /// A sitting passed for another note is ignored: the save is in a sitting of its own on this
    /// note, so it never writes the other note's ancestry.
    @Test func aSittingOfAnotherNoteIsIgnored() throws {
        let other = try store.addChapterNote(book: "GEN", chapter: 2, translationID: "WEB", body: "other", sourceThreadID: nil)
        let wrong = try #require(try store.beginSitting(noteID: other.uuid))
        try store.updateNote(base, body: "edited", sitting: wrong)
        #expect(NoteVersion.token(ofMark: base.versionMark) != wrong.token)
        #expect(base.versionAncestry != wrong.ancestry)
        #expect(NoteVersion.ancestorDigests(text: "edited", mark: base.versionMark, ancestry: base.versionAncestry) == [d("base")])
        #expect(store.openSittings == [other.uuid])
        store.endSitting(wrong)
    }

    @Test func aNewEmptyNoteDeletedLeavesNoMarker() throws {
        let empty = try store.addNote(to: try highlight(verse: 4), body: "")
        try store.deleteNote(empty)
        #expect(try markers().isEmpty)

        // Typed and erased in its first sitting: nothing was there before it.
        let typed = try store.addNote(to: try highlight(verse: 5), body: "")
        let sitting = try #require(try store.beginSitting(noteID: typed.uuid))
        try store.updateNote(typed, body: "x", sitting: sitting)
        try store.updateNote(typed, body: "", sitting: sitting)
        store.endSitting(sitting)
        try store.deleteNote(typed)
        #expect(try markers().isEmpty)
    }

    @Test func anUndoneDeleteBringsBackTheMarkAndTheJournal() throws {
        let anchor = try highlight(verse: 5, start: 2, end: 9)
        let note = try store.addNote(to: anchor, body: "kept")
        try store.updateNote(note, body: "kept and edited")
        let (id, mark, ancestry, kind) = (note.uuid, note.versionMark, note.versionAncestry, note.deviceKind)

        let deletion = try #require(try store.delete(.note(NoteSnapshot(note), anchor: nil)))
        #expect(journal.entry(for: id) == nil)
        try store.restore(deletion)
        let restored = try #require(try store.note(id: id))
        #expect(restored.versionMark == mark && restored.versionAncestry == ancestry && restored.deviceKind == kind)
        let entry = try #require(journal.entry(for: id))
        #expect(entry.body == "kept and edited" && entry.startOffset == 2 && entry.endOffset == 9)
        // The undo cancels the delete, so its marker goes in the restore's save.
        #expect(try markers().isEmpty)

        _ = try store.delete(deletion)
        #expect(try markers().count == 1)
    }

    @Test func aJournalThatCannotBeWrittenDoesNotStopTheSave() throws {
        let blocker = FileManager.default.temporaryDirectory.appending(path: "NoteSittingTests-\(UUID().uuidString)")
        try Data().write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let broken = LastTextJournal(directory: blocker, deviceTag: "aaaa")
        let other = try MarkupContainer.make(inMemory: true)
        let store = MarkupStore(container: other, journal: broken, deviceKind: "Mac")

        let note = try store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "first", sourceThreadID: nil)
        try store.updateNote(note, body: "second")
        #expect(note.body == "second" && NoteVersion.isMarked(text: "second", mark: note.versionMark))
        #expect(!store.context.hasChanges)
        #expect(broken.entry(for: note.uuid) == nil)
        #expect(try store.allNotes().map(\.body) == ["second"])
    }
}
