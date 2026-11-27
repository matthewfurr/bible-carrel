import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

/// Records that share a uuid (two restores, or a record imported on a device it had not reached
/// yet) are read as one; a note's copies whose texts differ leave a kept version before one goes,
/// and nothing else is deleted for sharing an identity (a delete always wins in sync, so two
/// devices each deleting a different copy would lose both).
@MainActor @Suite struct TwinTests {
    private let device: Device
    private var store: MarkupStore { device.store }
    private var context: ModelContext { device.store.context }

    init() throws {
        device = try Device(tag: "aaaa")
    }

    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    /// A chapter note on Genesis 1 with `uuid`, inserted through the context and saved.
    @discardableResult
    private func copy(_ body: String, uuid: UUID, modifiedAt: Date, in device: Device? = nil) throws -> Note {
        let device = device ?? self.device
        let note = Note(body: body, scope: .chapter, book: "GEN", chapter: 1, verse: 0, endVerse: 0, translationID: "WEB", quotedText: "")
        note.uuid = uuid
        note.createdAt = date(1)
        note.modifiedAt = modifiedAt
        device.store.context.insert(note)
        try device.store.context.save()
        return note
    }

    private func count<Record: PersistentModel>(_ type: Record.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<Record>())
    }

    // MARK: Notes

    @Test func copiesOfANoteThatDifferLeaveAKeptVersion() throws {
        let id = UUID()
        try copy("old", uuid: id, modifiedAt: date(10))
        try copy("new", uuid: id, modifiedAt: date(20))

        #expect(try store.settleVersions() == 2)
        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.map(\.body) == ["new"])
        #expect(try device.kept == ["old"])
        let kept = try #require(try device.keptVersions().first)
        #expect(kept.noteID == id)
        #expect(kept.writtenAt == date(10))
        #expect(kept.book == "GEN" && kept.chapter == 1 && kept.verse == 0)

        #expect(try store.settleVersions() == 0)
        #expect(try count(Note.self) == 1)
        #expect(try device.kept == ["old"])
    }

    @Test func twoDevicesChoosingDifferentlyLoseNeitherText() throws {
        let id = UUID()
        let other = try Device(tag: "bbbb", kind: "iPhone")
        // Each device holds both copies, with values that make it read a different one.
        try copy("one", uuid: id, modifiedAt: date(10))
        try copy("two", uuid: id, modifiedAt: date(20))
        try copy("one", uuid: id, modifiedAt: date(30), in: other)
        try copy("two", uuid: id, modifiedAt: date(20), in: other)
        #expect(try store.settleVersions() == 2)
        #expect(try other.store.settleVersions() == 2)
        #expect(try device.text(of: id) == "two")
        #expect(try other.text(of: id) == "one")

        // Both choices in one store: each device's delete wins, and each one's kept version arrives.
        try Arrival.delete(id, from: other, to: device, withMarkers: false)
        try Arrival.versions(from: other, to: device)
        #expect(try count(Note.self) == 0)
        #expect(try store.orphanVersions().map(\.body).sorted() == ["one", "two"])
        #expect(try store.settleVersions() == 0)
        #expect(try store.orphanVersions().map(\.body).sorted() == ["one", "two"])
    }

    @Test func aCopyTheSurvivorWasMadeFromIsNotKept() throws {
        let note = try store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "old", sourceThreadID: nil)
        let before = NoteSnapshot(note)
        try store.updateNote(note, body: "new", now: note.modifiedAt.addingTimeInterval(60))
        // The copy as it stood before the edit, made by a second restore.
        context.insert(before.make())
        try context.save()
        #expect(try count(Note.self) == 2)

        #expect(try store.settleVersions() == 1)
        #expect(try context.fetch(FetchDescriptor<Note>()).map(\.body) == ["new"])
        #expect(try device.kept.isEmpty)
    }

    /// The settle skips a note with a sitting open, and the editor's next save writes every copy:
    /// a copy's text that no journal holds (one from before this build) is kept before it is
    /// written over. A copy holding what the sitting opened on, or its own earlier save, is not.
    @Test func aCopyArrivingUnderAnOpenEditorIsKeptBeforeTheNextSave() throws {
        let id = UUID()
        let note = try copy("base", uuid: id, modifiedAt: date(10))
        let sitting = try #require(try store.beginSitting(noteID: id))
        try store.updateNote(note, body: "draft", sitting: sitting, now: date(20))
        try copy("theirs", uuid: id, modifiedAt: date(15))
        try copy("base", uuid: id, modifiedAt: date(12))
        #expect(try store.settleVersions() == 0)

        try store.updateNote(note, body: "draft2", sitting: sitting, now: date(30))
        #expect(try device.kept == ["theirs"])
        #expect(try context.fetch(FetchDescriptor<Note>()).allSatisfy { $0.body == "draft2" })
        try store.updateNote(note, body: "draft3", sitting: sitting, now: date(40))
        store.endSitting(sitting)
        #expect(try store.settleVersions() == 0)
        #expect(try device.kept == ["theirs"])
        let kept = try #require(try device.keptVersions().first)
        #expect(kept.noteID == id && kept.writtenAt == date(15))
    }

    /// A delete of the note read removes every copy; a copy's differing text that the note was not
    /// made with sight of is kept first, as a version with no note. A blank copy is not.
    @Test func deletingANoteKeepsItsDifferingCopy() throws {
        let id = UUID()
        try copy("theirs", uuid: id, modifiedAt: date(10))
        try copy(" ", uuid: id, modifiedAt: date(5))
        let note = try copy("mine", uuid: id, modifiedAt: date(20))
        try store.deleteNote(note)
        #expect(try count(Note.self) == 0)
        #expect(try store.orphanVersions().map(\.body) == ["theirs"])
        #expect(try store.settleVersions() == 0)
        #expect(try store.orphanVersions().map(\.body) == ["theirs"])
    }

    @Test func copiesThatAreTheSameAreLeftAndReadOnce() throws {
        let id = UUID()
        try copy("same", uuid: id, modifiedAt: date(10))
        try copy("same", uuid: id, modifiedAt: date(20))

        #expect(try store.settleVersions() == 0)
        #expect(try count(Note.self) == 2)
        #expect(try store.allNotes().count == 1)
        #expect(try store.notes(in: ChapterLocation(book: "GEN", chapter: 1)).count == 1)

        let note = try #require(try store.note(id: id))
        try store.updateNote(note, body: "edited")
        let copies = try context.fetch(FetchDescriptor<Note>())
        #expect(copies.count == 2)
        #expect(copies.allSatisfy { $0.body == "edited" })
        #expect(Set(copies.map(\.versionMark)).count == 1)
        #expect(copies.first?.versionMark != nil)

        try store.deleteNote(try #require(try store.note(id: id)))
        #expect(try count(Note.self) == 0)
        #expect(try device.markers().count == 1)
    }

    // MARK: Every kind

    @Test func everyKindIsReadOnce() throws {
        let chapter = ChapterLocation(book: "GEN", chapter: 1)
        func twice<Record: PersistentModel>(_ make: () -> Record) {
            context.insert(make())
            context.insert(make())
        }

        let highlightID = UUID()
        let bare = Highlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 4, translationID: "WEB", colorID: nil, quotedText: "In the")
        bare.uuid = highlightID
        bare.modifiedAt = date(20)
        let anchored = Highlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 4, translationID: "WEB", colorID: nil, quotedText: "In the")
        anchored.uuid = highlightID
        anchored.modifiedAt = date(10)
        context.insert(bare)
        context.insert(anchored)
        let note = Note(body: "a note", scope: .highlight, book: "GEN", chapter: 1, verse: 1, endVerse: 1, translationID: "WEB", quotedText: "In the")
        context.insert(note)
        anchored.note = note

        let bookmarkID = UUID()
        twice {
            let bookmark = Bookmark(book: "GEN", chapter: 1, verse: 2)
            bookmark.uuid = bookmarkID
            return bookmark
        }
        let colorID = UUID()
        twice {
            let color = HighlightColor(name: "Sky", lightHex: "#B8E8FF", darkHex: "#144D6E", sortOrder: 0, isDefault: false)
            color.uuid = colorID
            return color
        }
        let threadID = UUID()
        twice {
            let thread = ChatThread(scope: .chapter, book: "GEN", chapter: 1, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0,
                                    translationID: "WEB", quotedText: "", title: "Creation")
            thread.uuid = threadID
            return thread
        }
        let promptID = UUID()
        twice {
            let prompt = PromptTemplate(title: "Mine", body: "Tell me about {{reference}}", scope: .chapter, sortOrder: 0, isBuiltIn: false, builtInKey: nil)
            prompt.uuid = promptID
            return prompt
        }
        let versionID = UUID(), orphanID = UUID(), goneID = UUID()
        twice {
            let version = KeptVersion()
            version.uuid = versionID
            version.noteID = note.uuid
            version.body = "earlier"
            return version
        }
        twice {
            let version = KeptVersion()
            version.uuid = orphanID
            version.noteID = goneID
            version.body = "gone"
            return version
        }
        try context.save()

        #expect(try count(Highlight.self) == 2)
        #expect(try count(Bookmark.self) == 2)
        #expect(try count(HighlightColor.self) == 2)
        #expect(try count(ChatThread.self) == 2)
        #expect(try count(PromptTemplate.self) == 2)
        #expect(try count(KeptVersion.self) == 4)

        let highlights = try store.allHighlights()
        #expect(highlights.count == 1)
        #expect(highlights.first?.note != nil)
        #expect(try store.highlights(in: chapter).map { $0.note != nil } == [true])
        #expect(try store.highlights(inBook: "GEN", chapters: 1...1).map { $0.note != nil } == [true])
        #expect(try store.highlight(id: highlightID)?.note != nil)

        #expect(try store.allBookmarks().count == 1)
        #expect(try store.bookmarks(in: chapter).count == 1)
        #expect(try store.bookmarks(inBook: "GEN", chapters: 1...1).count == 1)
        #expect(try store.colors().count == 1)
        #expect(try store.chat.allThreads().count == 1)
        #expect(try store.chat.threads(in: chapter).count == 1)
        let prompts = PromptTemplateStore(container: store.container)
        #expect(try prompts.templates().count == 1)
        #expect(try prompts.templates(scope: .chapter).count == 1)

        #expect(try store.keptVersions(forNote: note.uuid).count == 1)
        #expect(try store.keptVersionCounts() == [note.uuid: 1, goneID: 1])
        #expect(try store.orphanVersions().map(\.uuid) == [orphanID])

        let found = try store.search("")
        #expect(found.highlights.count == 1)
        #expect(found.bookmarks.count == 1)
        #expect(try store.search("In the").highlights.map { $0.note != nil } == [true])
    }

    @Test func aNoteSearchFindsTheCopyThatIsRead() throws {
        let id = UUID()
        try copy("an older text", uuid: id, modifiedAt: date(10))
        try copy("a newer text", uuid: id, modifiedAt: date(20))

        #expect(try store.search("text").notes.map(\.body) == ["a newer text"])
        #expect(try store.search("older").notes.isEmpty)
        #expect(try store.note(id: id)?.body == "a newer text")
    }

    @Test func notesTiedOnTheirTimeReadTheGreaterText() throws {
        let id = UUID()
        try copy("apple", uuid: id, modifiedAt: date(10))
        try copy("banana", uuid: id, modifiedAt: date(10))
        #expect(try store.allNotes().map(\.body) == ["banana"])
    }

    // MARK: Twins.firsts

    private struct Item: Equatable {
        let id: UUID
        let rank: Int
    }

    @Test func firstsKeepsOnePerIdentityAtItsOwnPlace() {
        let a = UUID(), b = UUID()
        let items = [Item(id: a, rank: 1), Item(id: b, rank: 5), Item(id: a, rank: 3), Item(id: b, rank: 2)]
        #expect(Twins.firsts(items, id: \.id) == [items[0], items[1]])
        #expect(Twins.firsts(items, id: \.id, prefer: { $0.rank > $1.rank }) == [items[1], items[2]])
        #expect(Twins.firsts([Item](), id: \.id).isEmpty)
    }
}
