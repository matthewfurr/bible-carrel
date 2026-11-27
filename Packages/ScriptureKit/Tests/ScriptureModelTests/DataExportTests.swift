import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct DataExportTests {
    private func makeStore() throws -> MarkupStore {
        MarkupStore(container: try MarkupContainer.make(inMemory: true))
    }

    private func export(_ store: MarkupStore, conversations: Bool = true) throws -> DataFile {
        try DataExport.file(from: store, includesConversations: conversations, app: "Bible Carrel 1.0", now: Date(timeIntervalSince1970: 1_700_001_000))
    }

    private func topLevelKeys(_ file: DataFile) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: file.encoded()) as? [String: Any]
        return Set(object?.keys.map { $0 } ?? [])
    }

    @Test func everyKindIsWrittenUnderItsOwnKey() throws {
        let store = try makeStore()
        let ids = try DataSample.fill(store)
        let file = try export(store)
        let counts: [Int] = [
            file.colors.count, file.highlights.count, file.notes.count, file.keptVersions.count, file.bookmarks.count,
            file.prompts.count, file.plans.count, file.ticks.count, file.conversations.count,
        ]
        #expect(counts == [2, 2, 2, 2, 1, 2, 1, 2, 1])
        let first = try #require(file.notes.first { $0.id == ids.firstNote })
        #expect(first.highlightID != nil && first.sourceThreadID == ids.thread)
        #expect(first.versionMark != nil && first.versionAncestry != nil && first.deviceKind != nil)
        #expect(file.conversations[0].messages.map(\.role) == ["user", "assistant"])
        #expect(file.keptVersions.contains { $0.noteID == nil })
        let expectedKeys: Set<String> = ["format", "version", "exportedAt", "app", "colors", "highlights", "notes", "keptVersions",
                                         "bookmarks", "prompts", "plans", "ticks", "conversations"]
        let keys = try topLevelKeys(file)
        #expect(keys == expectedKeys)
        #expect(file.format == "bible-carrel-data" && file.version == 1 && file.app == "Bible Carrel 1.0")
    }

    @Test func markersKeysAndPreferencesAreNotInIt() throws {
        let store = try makeStore()
        try DataSample.fill(store)
        store.context.insert(DeletionMarker(noteID: UUID(), version: "abc.def", deletedAt: Date()))
        try store.context.save()
        let file = try export(store)
        let text = try #require(String(data: file.encoded(), encoding: .utf8))
        #expect(!text.contains("deletedAt") && !text.contains("DeletionMarker"))
        #expect(try topLevelKeys(file).count == 13)
    }

    @Test func theConversationsSwitchLeavesThemOut() throws {
        let store = try makeStore()
        let ids = try DataSample.fill(store)
        let file = try export(store, conversations: false)
        #expect(file.conversations.isEmpty)
        #expect(file.notes.first { $0.id == ids.firstNote }?.sourceThreadID == ids.thread)
        #expect(file.notes.count == 2 && file.highlights.count == 2)
    }

    @Test func aPlanIsWrittenWithItsWeeksAsStored() throws {
        let store = try makeStore()
        try DataSample.fill(store)
        let stored = try #require(try store.context.fetch(FetchDescriptor<PlanRecord>()).first).weeksData
        let file = try export(store)
        #expect(file.plans[0].weeks == (try JSONDecoder().decode(JSONValue.self, from: stored)))
        guard case .object(let weeks) = file.plans[0].weeks else { Issue.record("weeks are not an object"); return }
        #expect(weeks["v"] == .number(1))
    }

    @Test func aTwinIsWrittenOnce() throws {
        let store = try makeStore()
        let context = store.context
        let id = UUID(), planID = UUID(), readingID = UUID()
        for _ in 0..<2 {
            let note = Note(body: "Twin", scope: .chapter, book: "Genesis", chapter: 1, verse: 0, endVerse: 0, translationID: "WEB", quotedText: "")
            note.uuid = id
            context.insert(note)
            let kept = KeptVersion()
            kept.uuid = id
            kept.body = "Twin"
            context.insert(kept)
            let tick = PlanTick(planID: planID, readingID: readingID)
            tick.uuid = id
            context.insert(tick)
        }
        try context.save()
        let file = try export(store)
        #expect(file.notes.map(\.id) == [id] && file.keptVersions.map(\.id) == [id] && file.ticks.map(\.id) == [id])
    }
}
