import Foundation
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

/// The words of the versions view and the model the mark and the view read (spec 4.1, 4.2).
@MainActor @Suite struct NoteVersionsModelTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
    private var now: Date { date(2026, 11, 19, 12, 0) }

    private func makeStore() throws -> MarkupStore {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        return MarkupStore(container: container, deviceKind: "iPhone")
    }

    /// A chapter note "N" on Genesis 1 with a kept "K" from a Mac.
    private func noteWithKept(_ store: MarkupStore, note text: String = "N") throws -> (note: UUID, kept: UUID) {
        let note = try store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: text, sourceThreadID: nil)
        let kept = keep("K", of: note.uuid, in: store)
        try store.context.save()
        return (note.uuid, kept)
    }

    @discardableResult
    private func keep(_ body: String, of noteID: UUID?, in store: MarkupStore) -> UUID {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = body
        version.writtenAt = Date(timeIntervalSince1970: 50)
        version.deviceKind = "Mac"
        version.book = "GEN"
        version.chapter = 1
        version.translationID = "WEB"
        store.context.insert(version)
        return version.uuid
    }

    private func undoManager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    @Test func theWordsAreTheSpecs() {
        #expect(VersionText.mark(count: 2) == "2 versions")
        #expect(VersionText.title(count: 2) == "Two versions of this note")
        #expect(VersionText.title(count: 3) == "Three versions of this note")
        #expect(VersionText.title(count: 12) == "12 versions of this note")
        #expect(VersionText.name(kept: false, deviceKind: "iPhone") == "This version · iPhone")
        #expect(VersionText.name(kept: true, deviceKind: "Mac") == "Kept version · Mac")
        #expect(VersionText.name(kept: true, deviceKind: nil) == "Kept version")
        #expect(VersionText.name(kept: true, deviceKind: "") == "Kept version")

        func time(_ date: Date) -> String { VersionText.time(date, now: now, calendar: calendar, locale: locale) }
        #expect(time(date(2026, 11, 19, 8, 14)) == "Today 8:14\u{202F}AM")
        #expect(time(date(2026, 11, 18, 21, 40)) == "Yesterday 9:40\u{202F}PM")
        #expect(time(date(2026, 11, 12, 21, 40)) == "Nov 12, 9:40\u{202F}PM")
        #expect(time(date(2025, 11, 12, 21, 40)) == "Nov 12, 2025, 9:40\u{202F}PM")
        #expect(VersionText.spoken(kept: true, deviceKind: "Mac", at: date(2026, 11, 18, 21, 40), now: now, calendar: calendar, locale: locale)
            == "Kept version · Mac, Yesterday 9:40\u{202F}PM")

        #expect(VersionChoice.offered(hasNote: true) == [.use, .keepBoth, .discard])
        #expect(VersionChoice.offered(hasNote: false) == [.restoreAsNote, .discard])
        #expect(VersionChoice.prominent(hasNote: false, keptCount: 1) == .restoreAsNote)
        #expect(VersionChoice.prominent(hasNote: true, keptCount: 1) == .use)
        #expect(VersionChoice.prominent(hasNote: true, keptCount: 2) == nil)
        #expect(VersionChoice.allCases.map(\.title) == ["Use This One", "Keep Both in the Note", "Discard", "Restore as a Note"])
        #expect(VersionChoice.allCases.map(\.help) == [
            "Make this the note's text. The other becomes the kept version.",
            "Put this text under the note's text.",
            "Remove this kept version. Undo brings it back.",
            "Put this text back as a note on its passage.",
        ])
        #expect(VersionText.symbolName == "square.on.square")
        #expect(VersionText.orphanMark == "Kept version")
        #expect(VersionText.subtitle == "It was changed on two devices before they synced. Nothing was lost.")
        #expect(VersionText.orphanTitle == "A version with no note")
        #expect(VersionText.orphanSubtitle == "The note was deleted on one device and changed on another before they synced. Nothing was lost.")
        #expect(VersionText.help(for: .note(UUID())) == "Show the versions of this note")
        #expect(VersionText.help(for: .orphan(UUID())) == "Show the kept version")
    }

    @Test func theVersionsOfANoteAreItsTextThenItsKeptOnes() throws {
        let store = try makeStore()
        let (noteID, keptID) = try noteWithKept(store)
        let model = NoteVersionsModel(store: store)
        let versions = try #require(model.versions(forNote: noteID))
        #expect(versions.noteID == noteID && versions.book == "GEN")
        #expect(versions.current.body == "N" && versions.current.deviceKind == "iPhone")
        #expect(versions.kept.map(\.uuid) == [keptID])
    }

    @Test func eachChoiceChangesTheStoreAndTellsTheApp() throws {
        for choice in VersionChoice.allCases {
            let store = try makeStore()
            var changes = 0
            var changed: [UUID] = []
            let model = NoteVersionsModel(store: store, onChange: { changes += 1 }, onNoteChange: { changed.append($0) })
            let noteID: UUID, keptID: UUID
            if choice == .restoreAsNote {
                noteID = UUID()
                keptID = keep("K", of: noteID, in: store)
                try store.context.save()
                #expect(model.orphan(id: keptID)?.body == "K")
            } else {
                (noteID, keptID) = try noteWithKept(store)
            }
            let revision = model.revision
            model.perform(choice, on: keptID, undoManager: nil)

            #expect(changes == 1, "\(choice)")
            #expect(model.revision == revision + 1, "\(choice)")
            #expect(model.lastError == nil, "\(choice)")
            let note = try store.note(id: noteID)
            switch choice {
            case .use:
                #expect(note?.body == "K")
                #expect(try store.keptVersions(forNote: noteID).map(\.body) == ["N"])
                #expect(changed == [noteID])
            case .keepBoth:
                #expect(note?.body == "N\n\nK")
                #expect(try store.keptVersions(forNote: noteID).isEmpty)
                #expect(model.versions(forNote: noteID) == nil)
                #expect(changed == [noteID])
            case .discard:
                #expect(note?.body == "N")
                #expect(try store.keptVersions(forNote: noteID).isEmpty)
                #expect(changed.isEmpty)
            case .restoreAsNote:
                #expect(note?.body == "K" && note?.scope == .chapter)
                #expect(try store.orphanVersions().isEmpty)
                #expect(model.orphan(id: keptID) == nil)
                #expect(changed.isEmpty)
            }
        }
    }

    @Test func discardIsUndoneAndRedoneThroughTheManagerGiven() throws {
        let store = try makeStore()
        let (noteID, keptID) = try noteWithKept(store)
        var changes = 0
        let model = NoteVersionsModel(store: store, onChange: { changes += 1 })
        let undo = undoManager()
        undo.beginUndoGrouping()
        model.perform(.discard, on: keptID, undoManager: undo)
        undo.endUndoGrouping()
        #expect(try store.keptVersions(forNote: noteID).isEmpty)
        #expect(undo.canUndo && undo.undoActionName == "Discard Version")

        let revision = model.revision
        undo.undo()
        #expect(try store.keptVersions(forNote: noteID).map(\.uuid) == [keptID])
        #expect(model.versions(forNote: noteID)?.kept.map(\.body) == ["K"])
        #expect(model.revision == revision + 1 && changes == 2)
        #expect(undo.canRedo && undo.redoActionName == "Discard Version")

        undo.redo()
        #expect(try store.keptVersions(forNote: noteID).isEmpty)
        #expect(undo.canUndo && changes == 3)
    }

    @Test func versionsForANoteWithNoneIsNil() throws {
        let store = try makeStore()
        let note = try store.addChapterNote(book: "GEN", chapter: 1, translationID: "WEB", body: "N", sourceThreadID: nil)
        let model = NoteVersionsModel(store: store)
        #expect(model.versions(forNote: note.uuid) == nil)
        #expect(model.versions(forNote: UUID()) == nil)
        #expect(model.orphan(id: UUID()) == nil)
    }

    @Test func reloadBumpsTheRevision() throws {
        let model = NoteVersionsModel(store: try makeStore())
        let revision = model.revision
        model.reload()
        #expect(model.revision == revision + 1)
    }
}
