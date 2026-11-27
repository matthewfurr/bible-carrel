import Foundation
import Testing
@testable import ScriptureModel

@MainActor @Suite struct LastTextJournalTests {
    private func scratch() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "LastTextJournalTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func entry(_ id: UUID = UUID(), body: String = "abide") -> LastText {
        LastText(noteID: id, body: body, writtenAt: Date(timeIntervalSince1970: 1_000), book: "John", chapter: 15, verse: 4, endVerse: 4,
                 translationID: "WEB", quotedText: "Abide in me", startOffset: 0, endOffset: 11)
    }

    @Test func anEntryIsWrittenReadAndForgotten() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = LastTextJournal(directory: directory)
        let first = entry()
        try journal.record(first)
        let file = directory.appending(path: "\(first.noteID.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: file.path))
        let second = LastTextJournal(directory: directory)
        #expect(second.entry(for: first.noteID) == first)
        #expect(second.entries() == [first])
        var changed = first
        changed.body = "remain"
        try second.record(changed)
        #expect(journal.entry(for: first.noteID)?.body == "remain")
        #expect(journal.entries().count == 1)
        journal.forget(first.noteID)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(journal.entry(for: first.noteID) == nil)
    }

    @Test func theDeviceTagIsMadeOnceAndKept() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = LastTextJournal(directory: directory)
        #expect(journal.deviceTag.count == 4)
        #expect(journal.deviceTag.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(LastTextJournal(directory: directory).deviceTag == journal.deviceTag)
        #expect(LastTextJournal(directory: directory, deviceTag: "ab12").deviceTag == "ab12")
        let memory = LastTextJournal(directory: nil)
        try memory.record(entry())
        #expect(memory.entries().count == 1)
        #expect(memory.deviceTag.count == 4)
    }

    @Test func aDamagedEntryIsIgnoredAndRemoved() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = LastTextJournal(directory: directory)
        let id = UUID()
        let file = directory.appending(path: "\(id.uuidString).json")
        try Data("not json".utf8).write(to: file)
        #expect(journal.entries().isEmpty)
        try Data("not json".utf8).write(to: file)
        #expect(journal.entry(for: id) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func recordingThrowsWhenTheFolderCannotBeWritten() throws {
        let file = scratch()
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let journal = LastTextJournal(directory: file)
        #expect(throws: (any Error).self) { try journal.record(entry()) }
    }

    @Test func anEntryKeepsTheTagOfItsWriter() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        var tagged = entry()
        tagged.tag = "bbbb"
        try LastTextJournal(directory: directory).record(tagged)
        #expect(LastTextJournal(directory: directory).entry(for: tagged.noteID)?.tag == "bbbb")
    }

    /// An entry written before entries named their writer reads with no tag, and is not removed.
    @Test func anEntryFromBeforeTheTagReadsWithNone() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = LastTextJournal(directory: directory)
        let id = UUID()
        let file = directory.appending(path: "\(id.uuidString).json")
        let old = """
            {"noteID":"\(id.uuidString)","body":"abide","writtenAt":"2026-11-19T10:00:00Z","book":"John","chapter":15,"verse":4,\
            "endVerse":4,"translationID":"WEB","quotedText":"Abide in me","startOffset":0,"endOffset":11}
            """
        try Data(old.utf8).write(to: file)
        let read = try #require(journal.entry(for: id))
        #expect(read.body == "abide" && read.tag == nil)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
