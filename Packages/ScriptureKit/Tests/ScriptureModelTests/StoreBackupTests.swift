import Foundation
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct StoreBackupTests {
    /// A location under a fresh temporary directory, with no store yet.
    private func makeLocation() -> StoreLocation {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "StoreBackupTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return StoreLocation.resolve(sync: nil, applicationSupport: root)
    }

    /// An open store at a fresh location holding one bookmark and one highlight with a note. Keep
    /// the returned container alive for the whole test.
    private func makeStore() throws -> (location: StoreLocation, container: ModelContainer) {
        let location = makeLocation()
        let container = try MarkupContainer.make(at: location, sync: nil)
        let context = container.mainContext
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 12,
                                  translationID: "ESV", colorID: UUID(), quotedText: "Blessed are")
        let note = Note(body: "first", scope: .highlight, book: "MAT", chapter: 5, verse: 3, endVerse: 3,
                        translationID: "ESV", quotedText: "Blessed are")
        context.insert(highlight)
        context.insert(note)
        highlight.note = note
        context.insert(Bookmark(book: "GEN", chapter: 1, verse: 1, label: "start"))
        try context.save()
        return (location, container)
    }

    /// Noon on the given day in the current calendar, the calendar `backUpIfNeeded` uses by default.
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func aBackupTakenWhileTheStoreIsOpenHoldsTheSameRecords() throws {
        let (location, container) = try makeStore()
        let url = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)))
        #expect(url.lastPathComponent == "2026-11-09.store")
        #expect(!FileManager.default.fileExists(atPath: url.path + "-wal"))
        let live = try MarkupContainer.make(inMemory: true)
        let summary = try StoreCopy.copyMissing(from: url, into: live)
        #expect(summary.bookmarks == 1 && summary.highlights == 1 && summary.notes == 1)
        _ = container
    }

    @Test func thereIsOneBackupADay() throws {
        let (location, container) = try makeStore()
        let first = try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9))
        #expect(first?.lastPathComponent == "2026-11-09.store")
        #expect(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)) == nil)
        let next = try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 10))
        #expect(next?.lastPathComponent == "2026-11-10.store")
        #expect(try StoreBackup.backups(in: location).map(\.day) == ["2026-11-10", "2026-11-09"])
        _ = container
    }

    @Test func onlyTheNewestSevenAreKept() throws {
        let (location, container) = try makeStore()
        try FileManager.default.createDirectory(at: location.backupsDirectory, withIntermediateDirectories: true)
        let keep = location.backupsDirectory.appending(path: "Keep me.store")
        try Data("mine".utf8).write(to: keep)
        for date in 1...9 {
            try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, date))
        }
        #expect(try StoreBackup.backups(in: location).map(\.day) == [
            "2026-11-09", "2026-11-08", "2026-11-07", "2026-11-06", "2026-11-05", "2026-11-04", "2026-11-03",
        ])
        #expect(FileManager.default.fileExists(atPath: keep.path))
        _ = container
    }

    @Test func noStoreNoBackup() throws {
        let location = makeLocation()
        #expect(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)) == nil)
        #expect(!FileManager.default.fileExists(atPath: location.backupsDirectory.path))
        #expect(try StoreBackup.backups(in: location).isEmpty)
    }

    @Test func anEmptiedStoreDoesNotReplaceAGoodBackup() throws {
        let (location, container) = try makeStore()
        let first = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 8)))
        let context = container.mainContext
        try context.delete(model: Highlight.self)
        try context.delete(model: Note.self)
        try context.delete(model: Bookmark.self)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Highlight>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 0)

        #expect(try StoreBackup.takeBackup(location, now: day(2026, 11, 9)) == .skippedEmptyStore)
        #expect(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)) == nil)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(try StoreBackup.backups(in: location).map(\.day) == ["2026-11-08"])
        _ = container
    }

    @Test func anEmptyStoreWithNoBackupsStillBacksUp() throws {
        let location = makeLocation()
        let container = try MarkupContainer.make(at: location, sync: nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Highlight>()) == 0)
        let url = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)))
        #expect(url.lastPathComponent == "2026-11-09.store")
        _ = container
    }

    @Test func anEmptyBackupOfTodayIsReplacedOnceTheStoreHasRecords() throws {
        let location = makeLocation()
        let container = try MarkupContainer.make(at: location, sync: nil)
        let first = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)))
        #expect(StoreBackup.markCount(at: first, immutable: true) == 0)

        let context = container.mainContext
        context.insert(Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 12,
                                 translationID: "ESV", colorID: UUID(), quotedText: "Blessed are"))
        context.insert(Note(body: "first", scope: .verseRange, book: "MAT", chapter: 5, verse: 3, endVerse: 3,
                            translationID: "ESV", quotedText: "Blessed are"))
        try context.save()

        let second = try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9))
        #expect(second == first)
        #expect(StoreBackup.markCount(at: first, immutable: true) == 2)
        #expect(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)) == nil)
        #expect(try StoreBackup.backups(in: location).map(\.day) == ["2026-11-09"])
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: location.backupsDirectory.path)
        #expect(leftovers == ["2026-11-09.store"])
        _ = container
    }

    @Test func aBackupOfTodayWithRecordsIsNotReplaced() throws {
        let (location, container) = try makeStore()
        let first = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)))
        #expect(StoreBackup.markCount(at: first, immutable: true) == 2)

        let context = container.mainContext
        context.insert(Highlight(book: "JHN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 5,
                                 translationID: "ESV", colorID: UUID(), quotedText: "In the"))
        try context.save()

        #expect(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)) == nil)
        #expect(StoreBackup.markCount(at: first, immutable: true) == 2)
        _ = container
    }

    @Test func backupsAreListedNewestFirst() throws {
        let (location, container) = try makeStore()
        for date in [day(2026, 11, 8), day(2025, 12, 31), day(2026, 11, 10), day(2026, 1, 2)] {
            try StoreBackup.backUpIfNeeded(location, now: date)
        }
        let backups = try StoreBackup.backups(in: location)
        #expect(backups.map(\.day) == ["2026-11-10", "2026-11-08", "2026-01-02", "2025-12-31"])
        #expect(backups.map(\.url.lastPathComponent) == backups.map { "\($0.day).store" })
        _ = container
    }
}
