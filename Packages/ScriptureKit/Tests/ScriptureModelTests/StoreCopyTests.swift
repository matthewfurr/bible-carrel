import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct StoreCopyTests {
    /// A fresh directory under the temporary directory, one per call.
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "StoreCopyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// An on-disk store holding one of everything (two colors, two prompts, a plan with its first
    /// two readings ticked). Keep the returned
    /// container alive while its context is used.
    private func makeSource(at url: URL? = nil) throws -> (url: URL, container: ModelContainer) {
        let url = try url ?? makeDirectory().appending(path: "Source.store")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = MarkupContainer.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        let context = container.mainContext

        let yellow = HighlightColor(name: "Yellow", lightHex: "#F8E18A", darkHex: "#554704", sortOrder: 0, isDefault: true)
        yellow.builtInKey = "yellow"
        let mine = HighlightColor(name: "Mine", lightHex: "#BCF2BD", darkHex: "#2E522F", sortOrder: 1, isDefault: false)
        context.insert(yellow)
        context.insert(mine)

        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 12,
                                  translationID: "ESV", colorID: yellow.uuid, quotedText: "Blessed are")
        highlight.createdAt = Date(timeIntervalSince1970: 1_000_000)
        highlight.modifiedAt = Date(timeIntervalSince1970: 1_000_100)
        let first = Note(body: "first", scope: .highlight, book: "MAT", chapter: 5, verse: 3, endVerse: 3, translationID: "ESV", quotedText: "Blessed are")
        context.insert(highlight)
        context.insert(first)
        highlight.note = first

        context.insert(Note(body: "shepherd", scope: .chapter, book: "PSA", chapter: 23, verse: 0, endVerse: 0, translationID: "ESV", quotedText: ""))
        context.insert(Bookmark(book: "GEN", chapter: 1, verse: 1, label: "start"))

        let thread = ChatThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0,
                                translationID: "ESV", quotedText: "", title: "The Beatitudes")
        context.insert(thread)
        let question = ChatMessage(role: .user, content: "What is this?", providerID: "", modelName: "", attachedReference: nil)
        question.createdAt = Date(timeIntervalSince1970: 2_000_000)
        let answer = ChatMessage(role: .assistant, content: "A sermon.", providerID: "anthropic", modelName: "claude", attachedReference: nil)
        answer.createdAt = Date(timeIntervalSince1970: 2_000_010)
        context.insert(question)
        context.insert(answer)
        question.thread = thread
        answer.thread = thread

        context.insert(PromptTemplate(title: "Mine", body: "Tell me about {{reference}}", scope: .chapter, sortOrder: 0, isBuiltIn: false, builtInKey: nil))
        context.insert(PromptTemplate(title: "Outline", summary: "The shape", body: "Outline {{reference}}", scope: .chapter, section: .orient,
                                      sortOrder: 1, isBuiltIn: true, builtInKey: "outline"))
        try context.save()

        let plans = PlanStore(container: container), plan = PlanSample.gen1Shaped()
        try plans.save(plan)
        try plans.toggleTick(planID: plan.id, readingID: plan.weeks[0].readings[0].id, now: Date(timeIntervalSince1970: 3_000_000))
        try plans.toggleTick(planID: plan.id, readingID: plan.weeks[0].readings[1].id, now: Date(timeIntervalSince1970: 3_000_010))
        return (url, container)
    }

    private func count<Model: PersistentModel>(_ type: Model.Type, in container: ModelContainer) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<Model>())
    }

    @Test func everythingMissingIsCopiedWithItsIdentity() throws {
        let source = try makeSource()
        let live = try MarkupContainer.make(inMemory: true)
        let summary = try StoreCopy.copyMissing(from: source.url, into: live)
        #expect(summary == { var s = RestoreSummary(); s.colors = 2; s.highlights = 1; s.notes = 2; s.bookmarks = 1; s.conversations = 1; s.prompts = 2; s.plans = 1; s.ticks = 2; return s }())
        let highlight = try #require(try live.mainContext.fetch(FetchDescriptor<Highlight>()).first)
        let original = try #require(try source.container.mainContext.fetch(FetchDescriptor<Highlight>()).first)
        #expect(highlight.uuid == original.uuid)
        #expect(highlight.createdAt == original.createdAt)
        #expect(highlight.note?.body == "first")
        #expect(highlight.note?.highlight === highlight)
        let colors = try live.mainContext.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(colors.map(\.builtInKey) == ["yellow", nil])
        let thread = try #require(try live.mainContext.fetch(FetchDescriptor<ChatThread>()).first)
        #expect(thread.orderedMessages.map(\.role) == [.user, .assistant])
    }

    @Test func aSecondCopyAddsNothing() throws {
        let source = try makeSource()
        let live = try MarkupContainer.make(inMemory: true)
        _ = try StoreCopy.copyMissing(from: source.url, into: live)
        let second = try StoreCopy.copyMissing(from: source.url, into: live)
        #expect(second.total == 0)
        #expect(try count(HighlightColor.self, in: live) == 2)
        #expect(try count(Highlight.self, in: live) == 1)
        #expect(try count(Note.self, in: live) == 2)
        #expect(try count(Bookmark.self, in: live) == 1)
        #expect(try count(ChatThread.self, in: live) == 1)
        #expect(try count(ChatMessage.self, in: live) == 2)
        #expect(try count(PromptTemplate.self, in: live) == 2)
        #expect(try count(PlanRecord.self, in: live) == 1)
        #expect(try count(PlanTick.self, in: live) == 2)
    }

    @Test func anExistingRecordIsNeverChanged() throws {
        let source = try makeSource()
        let original = try #require(try source.container.mainContext.fetch(FetchDescriptor<Note>()).first { $0.body == "first" })
        let live = try MarkupContainer.make(inMemory: true)
        let edited = Note(body: "edited", scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, translationID: "ESV", quotedText: "")
        edited.uuid = original.uuid
        live.mainContext.insert(edited)
        try live.mainContext.save()

        _ = try StoreCopy.copyMissing(from: source.url, into: live)

        let id = original.uuid
        let matches = try live.mainContext.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == id }))
        #expect(matches.count == 1)
        #expect(matches.first?.body == "edited")
    }

    @Test func aBookmarkOnABookmarkedVerseIsSkipped() throws {
        let source = try makeSource()
        let live = try MarkupContainer.make(inMemory: true)
        live.mainContext.insert(Bookmark(book: "GEN", chapter: 1, verse: 1, label: "mine"))
        try live.mainContext.save()

        let summary = try StoreCopy.copyMissing(from: source.url, into: live)

        let bookmarks = try live.mainContext.fetch(FetchDescriptor<Bookmark>())
        #expect(bookmarks.count == 1)
        #expect(bookmarks.first?.label == "mine")
        #expect(summary.bookmarks == 0)
    }

    @Test func aMissingPlanComesBackWithItsTicks() throws {
        let source = try makeSource()
        let plan = PlanSample.gen1Shaped(), ids = plan.weeks[0].readings.prefix(2).map(\.id)
        let live = try MarkupContainer.make(inMemory: true), plans = PlanStore(container: live)

        let summary = try StoreCopy.copyMissing(from: source.url, into: live)
        #expect(summary.plans == 1 && summary.ticks == 2)
        #expect(try plans.plans() == [plan] && plans.tickedReadingIDs(planID: plan.id) == Set(ids))

        let second = try StoreCopy.copyMissing(from: source.url, into: live)
        #expect(second.plans == 0 && second.ticks == 0)

        // The plan live, its first reading ticked anew (another uuid) and its second not: only the second's tick comes back.
        let other = try MarkupContainer.make(inMemory: true), otherPlans = PlanStore(container: other)
        try otherPlans.save(plan)
        try otherPlans.toggleTick(planID: plan.id, readingID: ids[0])
        let third = try StoreCopy.copyMissing(from: source.url, into: other)
        #expect(third.plans == 0 && third.ticks == 1)
        #expect(try otherPlans.tickedReadingIDs(planID: plan.id) == Set(ids) && count(PlanTick.self, in: other) == 2)
        withExtendedLifetime(source.container) {}
    }

    @Test func aMissingNoteReturnsToItsLiveHighlight() throws {
        let source = try makeSource()
        let original = try #require(try source.container.mainContext.fetch(FetchDescriptor<Highlight>()).first)
        let live = try MarkupContainer.make(inMemory: true)
        let existing = HighlightSnapshot(original).make()
        live.mainContext.insert(existing)
        try live.mainContext.save()
        #expect(existing.note == nil)

        let summary = try StoreCopy.copyMissing(from: source.url, into: live)

        #expect(try count(Highlight.self, in: live) == 1)
        #expect(existing.note?.body == "first")
        #expect(existing.note?.uuid == original.note?.uuid)
        #expect(summary.highlights == 0)
        #expect(summary.notes == 2)
    }

    @Test func aMissingKeptVersionComesBackOnce() throws {
        let source = try makeSource()
        let context = source.container.mainContext
        let note = try #require(try context.fetch(FetchDescriptor<Note>()).first { $0.body == "shepherd" })
        note.versionMark = "aaaa00000001.\(NoteVersion.digest("shepherd"))"
        note.versionAncestry = "aaaa00000001:"
        note.deviceKind = "iPhone"
        let kept = KeptVersion()
        kept.noteID = note.uuid
        kept.body = "lost"
        kept.writtenAt = Date(timeIntervalSince1970: 4_000_000)
        kept.deviceKind = "Mac"
        context.insert(kept)
        let twin = KeptVersion()
        twin.noteID = note.uuid
        twin.body = "twin"
        context.insert(twin)
        context.insert(DeletionMarker(noteID: UUID(), version: NoteVersion.digest("gone"), deletedAt: Date()))
        try context.save()

        // The live store already keeps "twin" for that note, under another uuid.
        let live = try MarkupContainer.make(inMemory: true)
        let mine = KeptVersion()
        mine.noteID = note.uuid
        mine.body = " twin\n"
        live.mainContext.insert(mine)
        try live.mainContext.save()

        let summary = try StoreCopy.copyMissing(from: source.url, into: live)
        #expect(summary.keptVersions == 1)
        let versions = try live.mainContext.fetch(FetchDescriptor<KeptVersion>())
        #expect(versions.count == 2)
        let copied = try #require(versions.first { $0.uuid == kept.uuid })
        #expect(KeptVersionSnapshot(copied) == KeptVersionSnapshot(kept))
        #expect(try count(DeletionMarker.self, in: live) == 0)
        let noteID = note.uuid
        let copiedNote = try #require(try live.mainContext.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == noteID })).first)
        #expect(copiedNote.versionMark == note.versionMark)
        #expect(copiedNote.versionAncestry == note.versionAncestry)
        #expect(copiedNote.deviceKind == "iPhone")

        let second = try StoreCopy.copyMissing(from: source.url, into: live)
        #expect(second.keptVersions == 0 && second.total == 0)
        #expect(try count(KeptVersion.self, in: live) == 2)
    }

    /// An on-disk store holding a copy of `note`: a backup taken while the note was there.
    private func backup(of note: Note) throws -> (url: URL, container: ModelContainer) {
        let url = try makeDirectory().appending(path: "Backup.store")
        let schema = MarkupContainer.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        container.mainContext.insert(NoteSnapshot(note).make())
        try container.mainContext.save()
        return (url, container)
    }

    @Test func aRestoredNoteLosesItsStaleMarker() throws {
        let store = MarkupStore(container: try MarkupContainer.make(inMemory: true), journal: LastTextJournal(directory: nil, deviceTag: "aaaa"))
        let note = try store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "A1", sourceThreadID: nil)
        let id = note.uuid
        let saved = try backup(of: note)
        try store.deleteNote(note)
        store.context.insert(DeletionMarker(noteID: id, version: NoteVersion.digest("other"), deletedAt: Date()))
        try store.context.save()
        #expect(store.journal.entry(for: id) == nil)

        let summary = try store.restoreMissing(fromBackup: saved.url)
        #expect(summary.notes == 1)
        #expect(try store.note(id: id)?.body == "A1")
        let markers = try store.context.fetch(FetchDescriptor<DeletionMarker>()).filter { $0.noteID == id }
        #expect(!markers.contains { NoteVersion.marker($0.version, names: "A1") })
        #expect(markers.map(\.version) == [NoteVersion.digest("other")])
        #expect(store.journal.entry(for: id)?.body == "A1")
        withExtendedLifetime(saved.container) {}
    }

    @Test func aNoteAlreadyHereIsNotJournaledByARestore() throws {
        let store = MarkupStore(container: try MarkupContainer.make(inMemory: true), journal: LastTextJournal(directory: nil, deviceTag: "aaaa"))
        let note = Note(body: "B1", scope: .chapter, book: "GEN", chapter: 1, verse: 0, endVerse: 0, translationID: "WEB", quotedText: "")
        store.context.insert(note)
        store.context.insert(DeletionMarker(noteID: note.uuid, version: NoteVersion.digest("B1"), deletedAt: Date()))
        try store.context.save()
        let saved = try backup(of: note)

        let summary = try store.restoreMissing(fromBackup: saved.url)
        #expect(summary.total == 0)
        #expect(store.journal.entry(for: note.uuid) == nil)
        #expect(try store.context.fetch(FetchDescriptor<DeletionMarker>()).count == 1)
        withExtendedLifetime(saved.container) {}
    }

    @Test func aBuiltInPromptAlreadyPresentByKeyIsSkipped() throws {
        let source = try makeSource()
        let live = try MarkupContainer.make(inMemory: true)
        live.mainContext.insert(PromptTemplate(title: "My outline", body: "Mine", scope: .chapter, sortOrder: 0, isBuiltIn: true, builtInKey: "outline"))
        try live.mainContext.save()

        let summary = try StoreCopy.copyMissing(from: source.url, into: live)

        let prompts = try live.mainContext.fetch(FetchDescriptor<PromptTemplate>())
        let outlines = prompts.filter { $0.builtInKey == "outline" }
        #expect(outlines.count == 1)
        #expect(outlines.first?.title == "My outline")
        #expect(prompts.contains { $0.title == "Mine" && !$0.isBuiltIn })
        #expect(summary.prompts == 1)
    }

    @Test func theSourceFileIsLeftExactlyAsItWas() throws {
        let source = try makeSource()
        let before = try Data(contentsOf: source.url)
        let live = try MarkupContainer.make(inMemory: true)

        _ = try StoreCopy.copyMissing(from: source.url, into: live)

        let after = try Data(contentsOf: source.url)
        #expect(before == after)
    }

    @Test func theWalIsCopiedToo() throws {
        let source = try makeSource()
        let wal = URL(filePath: source.url.path + "-wal")
        // The source container is still open, so what it saved sits in the -wal.
        #expect(wal.lastPathComponent == "Source.store-wal")
        #expect(FileManager.default.fileExists(atPath: wal.path))
        let walBefore = try Data(contentsOf: wal)
        #expect(!walBefore.isEmpty)
        let live = try MarkupContainer.make(inMemory: true)

        let summary = try StoreCopy.copyMissing(from: source.url, into: live)

        #expect(summary.total == 12)
        #expect(try count(Highlight.self, in: live) == 1)
        #expect(try count(ChatMessage.self, in: live) == 2)
        #expect(try Data(contentsOf: wal) == walBefore)
        withExtendedLifetime(source.container) {}
    }

    @Test func theOldStoreIsImportedOnce() throws {
        let support = try makeDirectory()
        let location = StoreLocation.resolve(
            sync: SyncConfiguration(containerIdentifier: MarkupContainer.developmentContainerIdentifier, environment: .development),
            applicationSupport: support)
        let legacyURL = try #require(location.legacyStoreURL)
        let source = try makeSource(at: legacyURL)
        let live = try MarkupContainer.make(inMemory: true)

        let first = try LegacyImport.importIfNeeded(location, into: live)
        #expect(first?.total == 12)
        #expect(FileManager.default.fileExists(atPath: location.legacyMarkerURL.path))

        let second = try LegacyImport.importIfNeeded(location, into: live)
        #expect(second == nil)
        #expect(try count(Highlight.self, in: live) == 1)
        withExtendedLifetime(source.container) {}
    }

    @Test func noOldStoreMeansNoMarker() throws {
        let support = try makeDirectory()
        let location = StoreLocation.resolve(
            sync: SyncConfiguration(containerIdentifier: MarkupContainer.developmentContainerIdentifier, environment: .development),
            applicationSupport: support)
        let live = try MarkupContainer.make(inMemory: true)

        let summary = try LegacyImport.importIfNeeded(location, into: live)

        #expect(summary == nil)
        #expect(!FileManager.default.fileExists(atPath: location.legacyMarkerURL.path))
    }
}
