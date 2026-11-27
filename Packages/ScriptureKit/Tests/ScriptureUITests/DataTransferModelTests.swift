import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel
@testable import ScriptureUI

@MainActor @Suite struct DataTransferModelTests {
    private func makeStore() throws -> (MarkupStore, ModelContainer) {
        let container = try MarkupContainer.make(inMemory: true)
        return (MarkupStore(container: container), container)
    }

    /// A store with one chapter note, and the bytes of its export.
    private func sourceData() throws -> (Data, ModelContainer) {
        let (store, container) = try makeStore()
        _ = try store.addChapterNote(book: "PSA", chapter: 23, translationID: "WEB", body: "shepherd", sourceThreadID: nil)
        let model = DataTransferModel(store: store, app: "1.0 (42)", onImport: {})
        return (try model.exportData(includesConversations: true), container)
    }

    private func noteCount(_ store: MarkupStore) throws -> Int {
        try store.context.fetchCount(FetchDescriptor<Note>())
    }

    @Test func theSentenceSaysWhatHappenedInOneLine() {
        var summary = ImportSummary()
        summary.added.notes = 12
        summary.added.highlights = 3
        summary.versionsKept = 2
        summary.alreadyHere = 40
        #expect(DataTransferModel.sentence(for: summary)
            == "Added 12 notes and 3 highlights. 2 notes have another version kept. 40 were already here.")

        summary = ImportSummary()
        summary.added.notes = 1
        summary.versionsKept = 1
        summary.alreadyHere = 1
        #expect(DataTransferModel.sentence(for: summary) == "Added 1 note. 1 note has another version kept. 1 was already here.")

        #expect(DataTransferModel.sentence(for: ImportSummary()) == "Nothing was added.")
        summary = ImportSummary()
        summary.alreadyHere = 57
        #expect(DataTransferModel.sentence(for: summary) == "Nothing was added. 57 were already here.")
    }

    @Test func theSentenceNamesKindsInOrderAndKeptVersionsOnlyOnceCounted() {
        var summary = ImportSummary()
        summary.added.keptVersions = 1
        summary.added.ticks = 2
        summary.added.bookmarks = 1
        summary.added.notes = 1
        #expect(DataTransferModel.sentence(for: summary) == "Added 1 note, 1 bookmark, 2 ticks and 1 kept version.")
    }

    @Test func aRefusalSaysWhyAndChangesNothing() throws {
        let (store, container) = try makeStore()
        var imports = 0
        let model = DataTransferModel(store: store, app: "1.0 (42)", onImport: { imports += 1 })
        model.importData(Data("not json".utf8))
        #expect(model.resultText == "That file is damaged and could not be read. Nothing was changed.")
        model.importData(Data(#"{"format":"something-else","version":1}"#.utf8))
        #expect(model.resultText == "That file was not made by Bible Carrel. Nothing was changed.")
        model.importData(Data(#"{"format":"bible-carrel-data","version":99}"#.utf8))
        #expect(model.resultText == "That file was made by a newer version of Bible Carrel. Nothing was changed.")
        #expect(try noteCount(store) == 0 && imports == 0)

        let (good, source) = try sourceData()
        let waiting = DataTransferModel(store: store, app: "1.0 (42)", onImport: { imports += 1 }, canImport: { false })
        #expect(!waiting.canImport)
        waiting.importData(good)
        #expect(waiting.resultText == DataTransferModel.importUnavailableText)
        #expect(try noteCount(store) == 0 && imports == 0)
        _ = (container, source)
    }

    @Test func anImportTellsTheAppOnce() throws {
        let (good, source) = try sourceData()
        let (store, container) = try makeStore()
        var imports = 0
        let model = DataTransferModel(store: store, app: "1.0 (42)", onImport: { imports += 1 })
        model.importData(good)
        #expect(try imports == 1 && noteCount(store) == 1)
        #expect(model.resultText?.hasPrefix("Added ") == true && model.resultText?.contains("1 note") == true)
        model.importData(good)
        #expect(try imports == 2 && noteCount(store) == 1)
        #expect(model.resultText == "Nothing was added. 1 was already here.")
        _ = (container, source)
    }

    /// A real `MarkupModel` with a note open in its editor and a body typed into it, as the app
    /// builds `DataTransferModel` (`prepare` is the model's own `endOpenEdit`).
    private func editing(_ store: MarkupStore, onImport: @escaping @MainActor () -> Void = {}) throws -> (DataTransferModel, MarkupModel, UUID, UserDefaults, String) {
        let suite = "DataTransferModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let markup = MarkupModel(store: store, defaults: defaults)
        let note = try store.addChapterNote(book: "PSA", chapter: 23, translationID: "WEB", body: "start", sourceThreadID: nil)
        markup.load(book: "PSA", chapters: 23...23, chapterInView: ChapterLocation(book: "PSA", chapter: 23), translationID: "WEB")
        markup.beginEditing(noteID: note.uuid)
        markup.updateNoteBody(noteID: note.uuid, body: "typed while the import began")
        #expect(markup.editingNoteID == note.uuid && store.openSittings.contains(note.uuid))
        let model = DataTransferModel(store: store, app: "1.0 (42)", onImport: onImport, prepare: { markup.endOpenEdit() })
        return (model, markup, note.uuid, defaults, suite)
    }

    @Test func anImportStartedWhileANoteIsOpenLosesNothingTyped() throws {
        let (good, source) = try sourceData()
        let (store, container) = try makeStore()
        let (model, markup, noteID, defaults, suite) = try editing(store)
        defer { defaults.removePersistentDomain(forName: suite) }
        model.importData(good)
        #expect(model.resultText?.hasPrefix("Added ") == true)
        #expect(markup.editingNoteID == nil && store.openSittings.isEmpty)
        let body = try store.note(id: noteID)?.body
        #expect(body == "typed while the import began", "\(body ?? "nil")")
        #expect(!store.context.hasChanges)
        _ = (container, source)
    }

    @Test func aRefusedFileStillLeavesTheTypedNoteInTheStoreAndTheEditorClosed() throws {
        let (store, container) = try makeStore()
        var imports = 0
        let (model, markup, noteID, defaults, suite) = try editing(store, onImport: { imports += 1 })
        defer { defaults.removePersistentDomain(forName: suite) }
        let before = try noteCount(store)
        model.importData(Data("not json".utf8))
        #expect(model.resultText == DataTransferModel.sentence(for: .damaged) && imports == 0)
        #expect(markup.editingNoteID == nil && store.openSittings.isEmpty)
        let body = try store.note(id: noteID)?.body
        #expect(body == "typed while the import began", "\(body ?? "nil")")
        #expect(try noteCount(store) == before && !store.context.hasChanges)
        _ = container
    }

    @Test func aRefusedImportKeepsWhatWasPending() throws {
        let (store, container) = try makeStore()
        let model = DataTransferModel(store: store, app: "1.0 (42)", onImport: {})
        store.context.insert(Bookmark(book: "JHN", chapter: 3, verse: 16))
        model.importData(Data("not json".utf8))
        #expect(try store.context.fetchCount(FetchDescriptor<Bookmark>()) == 1)
        _ = container
    }

    @Test func theExportReadsBackAndCarriesTheAppsVersion() throws {
        let (store, container) = try makeStore()
        _ = try store.addChapterNote(book: "PSA", chapter: 23, translationID: "WEB", body: "shepherd", sourceThreadID: nil)
        let model = DataTransferModel(store: store, app: "1.0 (42)", onImport: {})
        let data = try model.exportData(includesConversations: true, now: Date(timeIntervalSince1970: 1_700_001_000))
        let file = try DataFile.read(data)
        #expect(file.app == "1.0 (42)" && file.notes.count == 1 && file.notes[0].body == "shepherd")
        let without = try DataFile.read(try model.exportData(includesConversations: false))
        #expect(without.conversations.isEmpty)
        _ = container
    }

    @Test func theFileIsNamedForItsDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12))!
        #expect(DataTransferModel.fileName(on: date, calendar: calendar) == "Bible Carrel Data 2026-11-16.json")
    }
}
