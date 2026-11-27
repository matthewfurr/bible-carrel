import Foundation
import SwiftData
import Testing
@testable import ScriptureModel
@testable import ScriptureUI

@MainActor @Suite struct BackupsModelTests {
    /// A location under a fresh temporary directory, with no store yet.
    private func makeLocation() -> StoreLocation {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "BackupsModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return StoreLocation.resolve(sync: nil, applicationSupport: root)
    }

    /// Noon on the given day in the current calendar, the calendar `backUpIfNeeded` uses by default.
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func theSentenceCountsWhatCameBack() {
        var summary = RestoreSummary()
        #expect(BackupsModel.sentence(for: summary) == "Nothing was missing.")
        summary.notes = 1
        #expect(BackupsModel.sentence(for: summary) == "Restored 1 note.")
        summary.highlights = 2; summary.bookmarks = 1
        #expect(BackupsModel.sentence(for: summary) == "Restored 2 highlights, 1 note and 1 bookmark.")
    }

    @Test func theSentenceNamesEveryKindInOrder() {
        var summary = RestoreSummary()
        summary.colors = 1
        summary.conversations = 2
        summary.prompts = 3
        #expect(BackupsModel.sentence(for: summary) == "Restored 1 color, 2 conversations and 3 prompts.")
    }

    @Test func theSentenceNamesPlansAndTicks() {
        var summary = RestoreSummary()
        summary.plans = 1
        summary.ticks = 2
        #expect(BackupsModel.sentence(for: summary) == "Restored 1 reading plan and 2 ticks.")
    }

    @Test func theSentenceNamesKeptVersionsLast() {
        var summary = RestoreSummary()
        summary.keptVersions = 1
        summary.notes = 1
        #expect(BackupsModel.sentence(for: summary) == "Restored 1 note and 1 kept version.")
    }

    @Test func theLastBackupIsTheNewestFile() throws {
        let location = makeLocation()
        let container = try MarkupContainer.make(at: location, sync: nil)
        let model = BackupsModel(location: location, store: MarkupStore(container: container), onRestore: {})
        model.refresh()
        #expect(model.lastBackup == nil)

        let older = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 8)))
        let newer = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)))
        try FileManager.default.setAttributes([.modificationDate: day(2026, 11, 8)], ofItemAtPath: older.path(percentEncoded: false))
        try FileManager.default.setAttributes([.modificationDate: day(2026, 11, 9)], ofItemAtPath: newer.path(percentEncoded: false))
        model.refresh()
        #expect(model.lastBackup == day(2026, 11, 9))
        #expect(model.backupsDirectory == location.backupsDirectory)
        _ = container
    }

    @Test func restoringBringsBackADeletedNoteAndSaysSo() throws {
        let location = makeLocation()
        let container = try MarkupContainer.make(at: location, sync: nil)
        let store = MarkupStore(container: container)
        let note = try store.addChapterNote(book: "PSA", chapter: 23, translationID: "ESV", body: "shepherd", sourceThreadID: nil)
        let noteID = note.uuid
        let backup = try #require(try StoreBackup.backUpIfNeeded(location))
        try store.deleteNote(note)
        #expect(try container.mainContext.fetch(FetchDescriptor<Note>()).isEmpty)

        var restores = 0
        let model = BackupsModel(location: location, store: store, onRestore: { restores += 1 })
        model.restore(from: backup)

        let notes = try container.mainContext.fetch(FetchDescriptor<Note>())
        #expect(notes.map(\.uuid) == [noteID])
        #expect(notes.first?.body == "shepherd")
        #expect(store.journal.entry(for: noteID)?.body == "shepherd")
        #expect(restores == 1)
        #expect(model.resultText == "Restored 1 note.")
        _ = container
    }

    @Test func restoreIsRefusedUntilItIsSafe() throws {
        let location = makeLocation()
        let container = try MarkupContainer.make(at: location, sync: nil)
        let store = MarkupStore(container: container)
        let note = try store.addChapterNote(book: "PSA", chapter: 23, translationID: "ESV", body: "shepherd", sourceThreadID: nil)
        let backup = try #require(try StoreBackup.backUpIfNeeded(location))
        try store.deleteNote(note)

        var safe = false
        var restores = 0
        let model = BackupsModel(location: location, store: store, onRestore: { restores += 1 }, canRestore: { safe })
        #expect(model.canRestore == false)
        model.restore(from: backup)

        #expect(try container.mainContext.fetch(FetchDescriptor<Note>()).isEmpty)
        #expect(restores == 0)
        #expect(model.resultText == "Restore is available once iCloud has brought your notes back.")
        #expect(BackupsModel.restoreUnavailableText == "Restore is available once iCloud has brought your notes back.")

        safe = true
        #expect(model.canRestore == true)
        model.restore(from: backup)
        #expect(try container.mainContext.fetch(FetchDescriptor<Note>()).count == 1)
        #expect(restores == 1)
        #expect(model.resultText == "Restored 1 note.")
        _ = container
    }

    @Test func anUnreadableFileSaysSo() throws {
        let location = makeLocation()
        let container = try MarkupContainer.make(at: location, sync: nil)
        try FileManager.default.createDirectory(at: location.backupsDirectory, withIntermediateDirectories: true)
        let text = location.backupsDirectory.appending(path: "notes.txt")
        try Data("not a store".utf8).write(to: text)

        var restores = 0
        let model = BackupsModel(location: location, store: MarkupStore(container: container), onRestore: { restores += 1 })
        model.restore(from: text)

        #expect(model.resultText == "That backup could not be read.")
        #expect(restores == 0)
        _ = container
    }
}
