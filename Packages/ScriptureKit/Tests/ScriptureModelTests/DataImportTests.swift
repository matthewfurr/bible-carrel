import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct DataImportTests {
    private func makeStore() throws -> MarkupStore {
        MarkupStore(container: try MarkupContainer.make(inMemory: true))
    }

    private func export(_ store: MarkupStore) throws -> DataFile {
        try DataExport.file(from: store, includesConversations: true, app: "Bible Carrel 1.0", now: Date(timeIntervalSince1970: 1_700_001_000))
    }

    /// A store filled by `DataSample.fill`, its ids and its export with conversations.
    private func full() throws -> (store: MarkupStore, ids: DataSample.Ids, file: DataFile) {
        let store = try makeStore()
        let ids = try DataSample.fill(store)
        return (store, ids, try export(store))
    }

    /// Every record of the file; a conversation counts once.
    private func recordCount(_ file: DataFile) -> Int {
        file.colors.count + file.highlights.count + file.notes.count + file.keptVersions.count + file.bookmarks.count
            + file.prompts.count + file.plans.count + file.ticks.count + file.conversations.count
    }

    /// Every table's `fetchCount`.
    private func tableCounts(_ store: MarkupStore) throws -> [Int] {
        let context = store.context
        return [
            try context.fetchCount(FetchDescriptor<HighlightColor>()), try context.fetchCount(FetchDescriptor<Highlight>()),
            try context.fetchCount(FetchDescriptor<Note>()), try context.fetchCount(FetchDescriptor<KeptVersion>()),
            try context.fetchCount(FetchDescriptor<Bookmark>()), try context.fetchCount(FetchDescriptor<PromptTemplate>()),
            try context.fetchCount(FetchDescriptor<PlanRecord>()), try context.fetchCount(FetchDescriptor<PlanTick>()),
            try context.fetchCount(FetchDescriptor<ChatThread>()), try context.fetchCount(FetchDescriptor<ChatMessage>()),
            try context.fetchCount(FetchDescriptor<DeletionMarker>()),
        ]
    }

    private func keptTexts(_ store: MarkupStore, note id: UUID) throws -> [String] {
        try store.keptVersions(forNote: id).map(\.body)
    }

    @Test func intoAnEmptyStoreEverythingArrives() throws {
        let (_, ids, file) = try full()
        let store = try makeStore()
        let summary = try DataImport.apply(file, to: store)
        #expect(recordCount(file) == 15)
        #expect(summary.added.total == recordCount(file))
        #expect(summary.versionsKept == 0 && summary.alreadyHere == 0)

        let filed = try #require(file.notes.first { $0.id == ids.firstNote })
        let note = try #require(try store.note(id: ids.firstNote))
        #expect(note.highlight?.uuid == filed.highlightID)
        #expect(note.body == filed.body && note.sourceThreadID == ids.thread)
        #expect(note.versionMark == filed.versionMark && note.versionAncestry == filed.versionAncestry && note.deviceKind == filed.deviceKind)

        let thread = try #require(try store.chat.thread(id: ids.thread))
        #expect(thread.orderedMessages.map(\.content) == ["What does bara mean?", "It means to create."])

        let plans = PlanStore(container: store.container)
        let plan = try #require(try plans.plan(id: ids.plan))
        #expect(plan.isReadable && !plan.weeks.isEmpty)
        #expect(try plans.tickedReadingIDs(planID: ids.plan) == [plan.weeks[0].readings[0].id, plan.weeks[0].readings[1].id])
    }

    @Test func aSecondImportAddsNothing() throws {
        let (_, _, file) = try full()
        let store = try makeStore()
        _ = try DataImport.apply(file, to: store)
        let before = try tableCounts(store)
        let summary = try DataImport.apply(file, to: store)
        #expect(summary.added.total == 0 && summary.versionsKept == 0)
        #expect(summary.alreadyHere == recordCount(file))
        #expect(try tableCounts(store) == before)
    }

    @Test func exportImportExportHoldsTheSameRecords() throws {
        let (_, _, file) = try full()
        let store = try makeStore()
        _ = try DataImport.apply(file, to: store)
        #expect(file.hasTheSameRecords(as: try export(store)))
    }

    @Test func aDifferingNoteBecomesAKeptVersionOnce() throws {
        let (store, ids, file) = try full()
        let filed = try #require(file.notes.first { $0.id == ids.firstNote })
        try #require(try store.note(id: ids.firstNote)).body = "mine"
        try store.context.save()

        let summary = try DataImport.apply(file, to: store)
        #expect(summary.versionsKept == 1 && summary.added.total == 0)
        #expect(summary.alreadyHere == recordCount(file) - 1)
        #expect(try store.note(id: ids.firstNote)?.body == "mine")
        let kept = try store.keptVersions(forNote: ids.firstNote).filter { $0.body == filed.body }
        #expect(kept.count == 1)
        #expect(kept.first?.writtenAt == filed.modifiedAt && kept.first?.deviceKind == filed.deviceKind)
        #expect(kept.first?.verse == 1 && kept.first?.endOffset == 57)

        let again = try DataImport.apply(file, to: store)
        #expect(again.versionsKept == 0 && again.added.total == 0)
        #expect(try keptTexts(store, note: ids.firstNote).filter { $0 == filed.body }.count == 1)
    }

    @Test func aTextTheStoresNoteWasEditedFromIsAlreadyHere() throws {
        let (store, ids, file) = try full()
        let note = try #require(try store.note(id: ids.firstNote))
        try store.updateNote(note, body: "God made it all, and it was good.")
        let before = try keptTexts(store, note: ids.firstNote)

        let summary = try DataImport.apply(file, to: store)
        #expect(summary.versionsKept == 0 && summary.added.total == 0)
        #expect(try keptTexts(store, note: ids.firstNote) == before)
        #expect(try store.note(id: ids.firstNote)?.body == "God made it all, and it was good.")
    }

    @Test func aDeletedRecordComesBack() throws {
        let (store, ids, file) = try full()
        let note = try #require(try store.note(id: ids.firstNote))
        let anchorID = try #require(note.highlight?.uuid)
        try store.deleteNote(note)
        let psalm = try #require(try store.allHighlights().first { $0.book == "Psalms" })
        let psalmID = psalm.uuid
        try store.deleteHighlight(psalm)
        let bookmark = try #require(try store.allBookmarks().first)
        let bookmarkID = bookmark.uuid
        try store.deleteBookmark(bookmark)
        try PlanStore(container: store.container).delete(planID: ids.plan)
        try store.chat.deleteThread(try #require(try store.chat.thread(id: ids.thread)))
        #expect(try store.context.fetchCount(FetchDescriptor<DeletionMarker>()) == 1)
        let before = try tableCounts(store)

        let summary = try DataImport.apply(file, to: store)
        var expected = RestoreSummary()
        expected.notes = 1; expected.highlights = 1; expected.bookmarks = 1; expected.plans = 1; expected.ticks = 2; expected.conversations = 1
        #expect(summary.added == expected && summary.versionsKept == 0)
        #expect(summary.alreadyHere == recordCount(file) - expected.total)

        #expect(try store.note(id: ids.firstNote)?.highlight?.uuid == anchorID)
        #expect(try store.highlight(id: psalmID) != nil)
        #expect(try store.bookmark(id: bookmarkID) != nil)
        #expect(try PlanStore(container: store.container).plan(id: ids.plan) != nil)
        #expect(try store.chat.thread(id: ids.thread)?.orderedMessages.count == 2)
        // The note is back as an undone delete is: journaled, and its marker naming the text is gone.
        #expect(store.journal.entry(for: ids.firstNote)?.body == "God made it all.")
        #expect(try store.context.fetchCount(FetchDescriptor<DeletionMarker>()) == 0)

        let after = try tableCounts(store)
        #expect(after[0] == before[0] && after[3] == before[3] && after[5] == before[5])
        #expect(after[1] == before[1] + 1 && after[2] == before[2] + 1 && after[4] == before[4] + 1)
        #expect(after[6] == before[6] + 1 && after[7] == before[7] + 2 && after[8] == before[8] + 1 && after[9] == before[9] + 2)
    }

    @Test func nothingHereIsChangedOrDeleted() throws {
        let (store, _, file) = try full()
        let marigold = try #require(try store.colors().first { $0.name == "Marigold" })
        try store.renameColor(marigold, to: "Gold")
        try #require(try store.allBookmarks().first).label = "The Lord is my shepherd"
        let extra = try store.addChapterNote(book: "John", chapter: 1, translationID: "WEB", body: "The Word.", sourceThreadID: nil)
        try store.context.save()
        let before = try tableCounts(store)

        let summary = try DataImport.apply(file, to: store)
        #expect(summary.added.total == 0 && summary.versionsKept == 0)
        #expect(try store.color(id: marigold.uuid)?.name == "Gold")
        #expect(try store.allBookmarks().first?.label == "The Lord is my shepherd")
        #expect(try store.note(id: extra.uuid)?.body == "The Word.")
        #expect(try tableCounts(store) == before)
    }

    @Test func hereAlreadyIsJudgedAsTheStoreMerges() throws {
        let (_, ids, file) = try full()
        let store = try makeStore()
        let context = store.context
        try MarkupContainer.seedDefaultColorsIfNeeded(in: context)
        let seededYellow = try #require(try store.colors().first { $0.builtInKey == "yellow" })
        let fileYellow = try #require(file.colors.first { $0.builtInKey == "yellow" })
        #expect(seededYellow.uuid != fileYellow.id)
        try PromptTemplateStore(container: store.container).seedIfNeeded([
            PromptSeed(key: "summary", title: "Summarize", summary: "A short summary", body: "Summarize {{reference}}.",
                       scope: .chapter, section: .orient, legacyTitle: "Summarize"),
        ])
        _ = try store.toggleBookmark(at: VerseLocation(book: "Psalms", chapter: 23, verse: 1))
        let firstTick = try #require(file.ticks.first)
        let ownTick = PlanTick(planID: try #require(firstTick.planID), readingID: try #require(firstTick.readingID))
        context.insert(ownTick)
        try context.save()

        let summary = try DataImport.apply(file, to: store)
        #expect(summary.added.colors == 1 && summary.added.prompts == 1 && summary.added.bookmarks == 0 && summary.added.ticks == 1)
        #expect(summary.alreadyHere == 4)
        #expect(try store.colors().filter { $0.builtInKey == "yellow" }.map(\.uuid) == [seededYellow.uuid])
        let genesis = try #require(try store.note(id: ids.firstNote)?.highlight)
        #expect(genesis.colorID == seededYellow.uuid)
        #expect(try store.allBookmarks().count == 1)
        #expect(try PlanStore(container: store.container).tickedReadingIDs(planID: ids.plan).count == 2)
    }

    @Test func aHighlightBringsItsColour() throws {
        let (_, _, whole) = try full()
        let psalm = try #require(whole.highlights.first { $0.book == "Psalms" })
        var file = DataFile(exportedAt: whole.exportedAt, app: whole.app)
        file.highlights = [psalm]
        file.colors = whole.colors.filter { $0.id == psalm.colorID }
        let store = try makeStore()

        let summary = try DataImport.apply(file, to: store)
        #expect(summary.added.colors == 1 && summary.added.highlights == 1)
        let colorID = try #require(try store.highlight(id: psalm.id)?.colorID)
        #expect(colorID == psalm.colorID)
        #expect(try store.color(id: colorID)?.name == "Marigold")
    }

    @Test func aNoteWhoseHighlightCarriesAnotherNoteIsKeptAsItsVersion() throws {
        let (store, ids, file) = try full()
        let filed = try #require(file.notes.first { $0.id == ids.firstNote })
        let note = try #require(try store.note(id: ids.firstNote))
        let anchor = try #require(note.highlight)
        try store.deleteNote(note)
        let other = try store.addNote(to: anchor, body: "Another note.")

        let summary = try DataImport.apply(file, to: store)
        #expect(summary.versionsKept == 1 && summary.added.total == 0)
        #expect(try store.note(id: ids.firstNote) == nil)
        #expect(anchor.note?.uuid == other.uuid && anchor.note?.body == "Another note.")
        let kept = try store.keptVersions(forNote: other.uuid)
        #expect(kept.map(\.body) == [filed.body])
        #expect(kept.first?.writtenAt == filed.modifiedAt && kept.first?.deviceKind == filed.deviceKind && kept.first?.endOffset == 57)

        let again = try DataImport.apply(file, to: store)
        #expect(again.versionsKept == 0 && again.added.total == 0)
        #expect(try store.keptVersions(forNote: other.uuid).count == 1)
    }

    @Test func aPlanFromANewerCodingIsAddedUnread() throws {
        let (_, ids, whole) = try full()
        var file = DataFile(exportedAt: whole.exportedAt, app: whole.app)
        var plan = try #require(whole.plans.first)
        guard case .object(var weeks) = plan.weeks else { Issue.record("weeks are not an object"); return }
        weeks["v"] = .number(2)
        plan.weeks = .object(weeks)
        file.plans = [plan]
        let store = try makeStore()

        let summary = try DataImport.apply(file, to: store)
        #expect(summary.added.plans == 1)
        #expect(try store.context.fetchCount(FetchDescriptor<PlanRecord>()) == 1)
        let listed = try PlanStore(container: store.container).plans()
        #expect(listed.map(\.id) == [ids.plan] && listed.first?.isReadable == false)
    }
}
