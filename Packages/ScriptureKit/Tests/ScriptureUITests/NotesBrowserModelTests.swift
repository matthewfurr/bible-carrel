import Foundation
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct NotesBrowserModelTests {
    private func make(onChange: @escaping () -> Void = {}) throws -> (NotesBrowserModel, MarkupStore, UserDefaults) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let name = "NotesBrowserModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (NotesBrowserModel(store: store, defaults: defaults, onChange: onChange), store, defaults)
    }

    /// A noted colorless highlight (MAT 5:3), then a noteless yellow highlight (GEN 1:1), then a bookmark (JHN 3:16).
    @discardableResult
    private func seed(_ store: MarkupStore) throws -> (note: Note, highlight: Highlight, bookmark: Bookmark) {
        let anchor = try store.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed are the poor")
        let note = try store.addNote(to: anchor, body: "The **Beatitudes** begin here.\nSecond line.")
        note.modifiedAt = Date(timeIntervalSince1970: 100)
        anchor.modifiedAt = Date(timeIntervalSince1970: 100)
        let highlight = try store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 2, translationID: "KJV", colorID: try store.colors()[0].uuid, quotedText: "In the beginning")
        highlight.modifiedAt = Date(timeIntervalSince1970: 200)
        try store.toggleBookmark(at: VerseLocation(book: "JHN", chapter: 3, verse: 16))
        let bookmark = try store.allBookmarks()[0]
        bookmark.createdAt = Date(timeIntervalSince1970: 300)
        try store.context.save()
        return (note, highlight, bookmark)
    }

    private func kinds(_ model: NotesBrowserModel) -> [String] {
        model.entries.map {
            switch $0.kind {
            case .note: "note"
            case .highlight: "highlight"
            case .bookmark: "bookmark"
            case .thread: "thread"
            case .keptVersion: "keptVersion"
            }
        }
    }

    @Test func timeFilterNarrowsEntriesAndIsRemembered() throws {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let name = "NotesBrowserModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let recent = try store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 2, translationID: "KJV", colorID: try store.colors()[0].uuid, quotedText: "In the beginning")
        recent.modifiedAt = now.addingTimeInterval(-3 * 86_400)
        let old = try store.addHighlight(book: "GEN", chapter: 1, verse: 3, endVerse: 3, startOffset: 0, endOffset: 2, translationID: "KJV", colorID: try store.colors()[0].uuid, quotedText: "Let there be light")
        old.modifiedAt = now.addingTimeInterval(-40 * 86_400)
        try store.context.save()
        let model = NotesBrowserModel(store: store, defaults: defaults, now: { now })
        #expect(model.timeFilter == .anyTime)
        #expect(model.entries.count == 2)
        model.timeFilter = .pastWeek
        #expect(model.entries.map(\.id) == [recent.uuid])
        model.timeFilter = .pastThreeMonths
        #expect(model.entries.count == 2)
        model.timeFilter = .pastWeek
        #expect(NotesBrowserModel(store: store, defaults: defaults, now: { now }).timeFilter == .pastWeek)
        #expect(NotesBrowserModel(store: store, defaults: defaults, now: { now }).entries.count == 1)
    }

    /// ↓ and ↑ walk the rows in the order shown, stop at the ends, and start at an end with nothing selected.
    @Test func arrowKeysMoveTheSelectionAndStopAtTheEnds() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        model.selectedID = nil
        let ids = model.visibleIDs
        #expect(ids == model.entries.map(\.id) && ids.count == 3)
        #expect(model.moveSelection(by: 1) == ids[0])
        #expect(model.moveSelection(by: 1) == ids[1])
        #expect(model.moveSelection(by: 1) == ids[2])
        #expect(model.moveSelection(by: 1) == ids[2])
        #expect(model.moveSelection(by: -1) == ids[1])
        model.selectedID = nil
        #expect(model.moveSelection(by: -1) == ids[2])
    }

    /// Sorted by reference the rows run through the book groups, so ↓ crosses a group's end.
    @Test func arrowKeysFollowTheGroupsWhenSortedByReference() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        model.sort = .reference
        let ids = model.visibleIDs
        #expect(ids == model.sections.flatMap(\.entries).map(\.id) && ids.count == 3)
        model.selectedID = ids[0]
        #expect(model.moveSelection(by: 1) == ids[1])
        #expect(model.moveSelection(by: 1) == ids[2])
    }

    /// Deleting the selected row hands the selection to the row that took its place, else the last.
    @Test func deletingTheSelectedRowSelectsItsSuccessor() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        let ids = model.visibleIDs
        model.selectedID = ids[1]
        model.delete(id: ids[1])
        #expect(model.visibleIDs == [ids[0], ids[2]])
        #expect(model.selectedID == ids[2])
        model.delete(id: ids[2])
        #expect(model.selectedID == ids[0])
        model.delete(id: ids[0])
        #expect(model.selectedID == nil)
    }

    @Test func deletingAnotherRowKeepsTheSelection() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        let ids = model.visibleIDs
        model.selectedID = ids[0]
        model.delete(id: ids[2])
        #expect(model.selectedID == ids[0])
    }

    /// A filter that no longer lists the selected item clears the selection; the keys then start from an end.
    @Test func aFilterThatHidesTheSelectionClearsIt() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        let bookmark = try #require(model.entries.first { if case .bookmark = $0.kind { true } else { false } })
        model.selectedID = bookmark.id
        model.filter = .notes
        #expect(model.selectedID == nil)
        #expect(model.moveSelection(by: 1) == model.visibleIDs.first)
    }

    /// With nothing selected the keys still work, in either sort: down starts at the first row, up at the last.
    @Test func fromNoSelectionDownIsFirstAndUpIsLastInBothSorts() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        for sort in [NotesBrowserSort.date, .reference] {
            model.sort = sort
            model.selectedID = nil
            #expect(model.moveSelection(by: 1) == model.visibleIDs.first)
            model.selectedID = nil
            #expect(model.moveSelection(by: -1) == model.visibleIDs.last)
        }
    }

    /// After a filter hides the selected row, down selects the first listed row.
    @Test func afterAFilterHidesTheSelectionDownSelectsTheFirstListedRow() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        model.selectedID = model.visibleIDs.last
        model.filter = .bookmarks
        #expect(model.selectedID == nil || model.visibleIDs.contains(model.selectedID!))
        model.selectedID = nil
        #expect(model.moveSelection(by: 1) == model.visibleIDs.first && model.visibleIDs.count == 1)
    }

    @Test func movingWithNothingToShowSelectsNothing() throws {
        let (model, _, _) = try make()
        #expect(model.moveSelection(by: 1) == nil && model.selectedID == nil)
    }

    @Test func timeFilterStaysOnTheDevice() {
        #expect(!SyncedPreferences.keys.contains(NotesBrowserModel.timeFilterKey))
    }

    @Test func threadsAppearWithTitleLastLineAndTarget() throws {
        let (model, store, _) = try make()
        let thread = try store.chat.createThread(scope: .selection, book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "KJV", quotedText: "Blessed", title: "Matthew 5:3 · Blessed")
        try store.chat.append(to: thread, role: .user, content: "Why?", providerID: "", modelName: "", attachedReference: nil)
        try store.chat.append(to: thread, role: .assistant, content: "**Because** it is.\nMore.", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
        model.reload()
        #expect(model.totalCount == 1)
        let entry = model.entries[0]
        #expect(entry.kind == .thread(id: thread.uuid) && entry.body == "Matthew 5:3 · Blessed" && entry.quotedText == "Because it is." && entry.translationID == "KJV")
        #expect(entry.referenceString == "Matthew 5:3" && entry.verse == 3 && entry.color == nil)
        let target = model.target(for: entry.id)
        #expect(target?.threadID == thread.uuid && target?.verse == 3 && target?.highlightID == nil && target?.translationID == "KJV")
        model.filter = .notes
        #expect(model.entries.isEmpty)
        model.filter = .threads
        #expect(model.entries.count == 1)
    }

    /// The row's two-line limit truncates with an ellipsis; the entry must not cut the line first.
    @Test func aThreadsLastLineIsNotCutShort() throws {
        let (model, store, _) = try make()
        let thread = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "KJV", quotedText: "", title: "Outline: Matthew 5")
        let reply = String(repeating: "Blessed are the poor in spirit. ", count: 8)
        try store.chat.append(to: thread, role: .assistant, content: reply, providerID: "appleOnDevice", modelName: "m", attachedReference: nil)
        model.reload()
        #expect(model.entries[0].quotedText == reply.trimmingCharacters(in: .whitespaces))
    }

    @Test func searchFindsThreadsByTitleOrReply() throws {
        let (model, store, _) = try make()
        let thread = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "KJV", quotedText: "", title: "Outline: Matthew 5")
        try store.chat.append(to: thread, role: .user, content: "Here is Matthew 5 (KJV): Blessed are the meek", displayText: "Outline", providerID: "", modelName: "", attachedReference: nil)
        try store.chat.append(to: thread, role: .assistant, content: "1. The Beatitudes", providerID: "appleOnDevice", modelName: "m", attachedReference: nil)
        model.query = "beatitudes"
        model.applySearch()
        #expect(model.entries.map(\.id) == [thread.uuid])
        model.query = "outline"
        model.applySearch()
        #expect(model.entries.map(\.id) == [thread.uuid])
        model.query = "meek"
        model.applySearch()
        #expect(model.entries.isEmpty)
    }

    @Test func deletingAThreadFromTheBrowserIsUndoable() throws {
        let (model, store, _) = try make()
        let undo = UndoManager()
        model.undoManager = undo
        let thread = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "KJV", quotedText: "", title: "Outline: Matthew 5")
        model.reload()
        model.delete(id: thread.uuid)
        #expect(try model.entries.isEmpty && store.chat.allThreads().isEmpty)
        undo.undo()
        #expect(model.entries.count == 1)
    }

    @Test func entriesCoverNotesHighlightsAndBookmarksNewestFirst() throws {
        let (model, store, _) = try make()
        let seeded = try seed(store)
        model.reload()
        #expect(kinds(model) == ["bookmark", "highlight", "note"])
        #expect(model.totalCount == 3 && model.sections.isEmpty)
        let noteEntry = model.entries[2]
        #expect(noteEntry.id == seeded.note.uuid)
        #expect(noteEntry.kind == .note(noteID: seeded.note.uuid, highlightID: seeded.note.highlight?.uuid))
        #expect(noteEntry.referenceString == "Matthew 5:3" && noteEntry.translationID == "ESV" && noteEntry.color == nil)
        #expect(noteEntry.body == seeded.note.body && noteEntry.quotedText == "Blessed are the poor")
        let highlightEntry = model.entries[1]
        #expect(highlightEntry.kind == .highlight(id: seeded.highlight.uuid) && highlightEntry.color?.lightHex == "#F8E18A")
        #expect(highlightEntry.colorName == "Yellow" && noteEntry.colorName == nil)
        let bookmarkEntry = model.entries[0]
        #expect(bookmarkEntry.kind == .bookmark(id: seeded.bookmark.uuid) && bookmarkEntry.translationID == nil && bookmarkEntry.referenceString == "John 3:16")
    }

    @Test func referenceSortProducesSectionsAndPersists() throws {
        let (model, store, defaults) = try make()
        try seed(store)
        model.reload()
        model.sort = .reference
        #expect(model.sections.map(\.title) == ["Genesis", "Matthew", "John"])
        #expect(model.entries.map(\.book) == ["GEN", "MAT", "JHN"])
        #expect(defaults.string(forKey: NotesBrowserModel.sortKey) == "reference")
        let again = NotesBrowserModel(store: store, defaults: defaults)
        #expect(again.sort == .reference)
    }

    @Test func filterNarrowsAndPersists() throws {
        let (model, store, defaults) = try make()
        try seed(store)
        model.reload()
        model.filter = .bookmarks
        #expect(kinds(model) == ["bookmark"] && model.totalCount == 3)
        #expect(defaults.string(forKey: NotesBrowserModel.filterKey) == "bookmarks")
        model.filter = .highlights
        #expect(kinds(model) == ["highlight", "note"])
    }

    @Test func searchMatchesBodyQuoteAndReference() throws {
        let (model, store, _) = try make()
        try seed(store)
        model.reload()
        model.query = "beatitudes"
        model.applySearch()
        #expect(kinds(model) == ["note"])
        model.query = "beginning"
        model.applySearch()
        #expect(kinds(model) == ["highlight"])
        model.query = "john 3"
        model.applySearch()
        #expect(kinds(model) == ["bookmark"])
        model.query = ""
        model.applySearch()
        #expect(model.entries.count == 3)
    }

    @Test func deletingAnEntryReloadsTheListAndNotifies() throws {
        var changes = 0
        let (model, store, _) = try make { changes += 1 }
        let seeded = try seed(store)
        model.reload()
        model.delete(id: seeded.note.uuid)
        #expect(try store.allHighlights().count == 1)   // the colorless anchor went with its note
        #expect(model.entries.count == 2 && changes == 1)
        model.delete(id: seeded.bookmark.uuid)
        #expect(try store.allBookmarks().isEmpty && model.entries.count == 1 && changes == 2)
        model.delete(id: seeded.highlight.uuid)
        #expect(try store.allHighlights().isEmpty && model.entries.isEmpty && changes == 3)
    }

    @Test func targetForAnEntryCarriesTranslationAndHighlight() throws {
        let (model, store, _) = try make()
        let seeded = try seed(store)
        model.reload()
        let noteTarget = model.target(for: seeded.note.uuid)
        #expect(noteTarget == MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 5), verse: 3, translationID: "ESV", highlightID: seeded.note.highlight?.uuid))
        #expect(model.target(for: seeded.bookmark.uuid) == MarkupTarget(location: ChapterLocation(book: "JHN", chapter: 3), verse: 16, translationID: nil, highlightID: nil))
        #expect(model.target(for: UUID()) == nil)
        #expect(model.entry(id: seeded.highlight.uuid)?.referenceString == "Genesis 1:1")
    }

    /// Deletes through a second context on the same container, as an iCloud import does.
    @Test func aRowDeletedElsewhereDisappearsAndItsActionsDoNothing() throws {
        var changes = 0
        let (model, store, _) = try make(onChange: { changes += 1 })
        let undo = UndoManager()
        model.undoManager = undo
        let seeded = try seed(store)
        let noteID = seeded.note.uuid, highlightID = seeded.highlight.uuid, bookmarkID = seeded.bookmark.uuid
        let threadID = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "KJV", quotedText: "", title: "Outline: Matthew 5").uuid
        model.reload()
        #expect(model.entries.count == 4)

        let other = ModelContext(store.container)
        for note in try other.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == noteID })) { other.delete(note) }
        for highlight in try other.fetch(FetchDescriptor<Highlight>(predicate: #Predicate { $0.uuid == highlightID })) { other.delete(highlight) }
        for bookmark in try other.fetch(FetchDescriptor<Bookmark>(predicate: #Predicate { $0.uuid == bookmarkID })) { other.delete(bookmark) }
        for thread in try other.fetch(FetchDescriptor<ChatThread>(predicate: #Predicate { $0.uuid == threadID })) { other.delete(thread) }
        try other.save()

        // Before any reload: the rows are still listed, and acting on them does nothing.
        for id in [noteID, highlightID, bookmarkID, threadID] {
            #expect(model.target(for: id) != nil)
            model.delete(id: id)
        }
        #expect(model.lastError == nil)
        #expect(!undo.canUndo)
        #expect(changes == 0)

        model.reload()
        let ids = Set(model.entries.map(\.id))
        #expect(ids.isDisjoint(with: [noteID, highlightID, bookmarkID, threadID]))
        #expect(model.target(for: noteID) == nil && model.target(for: threadID) == nil)
        #expect(model.lastError == nil)
    }

    // MARK: - Kept versions

    @discardableResult
    private func keep(_ body: String, of noteID: UUID, book: String = "GEN", chapter: Int = 1, verse: Int = 0, in store: MarkupStore) throws -> UUID {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = body
        version.writtenAt = Date(timeIntervalSince1970: 400)
        version.deviceKind = "Mac"
        version.book = book
        version.chapter = chapter
        version.verse = verse
        version.endVerse = verse
        version.translationID = "WEB"
        store.context.insert(version)
        try store.context.save()
        return version.uuid
    }

    @Test func theKeptVersionsFilterListsNotesWithOneAndTextsWithNoNote() throws {
        let (model, store, _) = try make()
        let seeded = try seed(store)
        try store.addChapterNote(book: "MAT", chapter: 6, translationID: "ESV", body: "A plain note", sourceThreadID: nil)
        model.reload()
        #expect(!model.hasKeptVersions)
        let total = model.totalCount
        let onNote = try keep("Another text", of: seeded.note.uuid, book: "MAT", chapter: 5, verse: 3, in: store)
        let orphan = try keep("Lost words", of: UUID(), in: store)
        model.reload()
        #expect(model.hasKeptVersions)

        #expect(model.filter == .all)
        #expect(!kinds(model).contains("keptVersion"))
        #expect(model.totalCount == total)

        model.filter = .keptVersions
        #expect(Set(model.entries.map(\.id)) == [seeded.note.uuid, orphan])
        #expect(model.entries.first { $0.id == seeded.note.uuid }?.versionCount == 2)
        let entry = try #require(model.entry(id: orphan))
        #expect(entry.kind == .keptVersion(id: orphan))
        #expect(entry.referenceString == "Genesis 1" && entry.body == "Lost words")
        #expect(entry.modifiedAt == Date(timeIntervalSince1970: 400))

        // Searched as a note is: by its text and by its reference.
        model.query = "lost"
        model.applySearch()
        #expect(model.entries.map(\.id) == [orphan])
        model.query = "Genesis 1"
        model.applySearch()
        #expect(model.entries.map(\.id).contains(orphan))
        model.query = ""
        model.applySearch()

        try store.keepBoth(onNote)
        try store.delete(.keptVersion(try #require(try store.orphanVersions().first)))
        model.reload()
        #expect(!model.hasKeptVersions)
        #expect(model.filter == .all)
    }

    @Test func deletingATextWithNoNoteDiscardsItUndoably() throws {
        var changes = 0
        let (model, store, _) = try make { changes += 1 }
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.undoManager = undo
        let orphan = try keep("Lost words", of: UUID(), in: store)
        model.reload()
        model.filter = .keptVersions

        undo.beginUndoGrouping()
        model.delete(id: orphan)
        undo.endUndoGrouping()
        #expect(try store.orphanVersions().isEmpty)
        #expect(changes == 1)
        #expect(undo.canUndo && undo.undoActionName == "Discard Version")
        #expect(!model.hasKeptVersions && model.filter == .all)

        undo.undo()
        #expect(try store.orphanVersions().map(\.uuid) == [orphan])
        #expect(model.hasKeptVersions)
        undo.redo()
        #expect(try store.orphanVersions().isEmpty)
    }

    @Test func theDeleteDialogDiscardsAKeptVersion() throws {
        let (model, store, _) = try make()
        let seeded = try seed(store)
        let orphan = try keep("Lost words", of: UUID(), book: "JHN", chapter: 15, verse: 9, in: store)
        model.reload()
        model.filter = .keptVersions
        #expect(NotesBrowserView.deleteTitle(for: try #require(model.entry(id: orphan))) == "Discard the kept version of John 15:9?")
        #expect(NotesBrowserView.deleteTitle(for: try #require(model.entry(id: seeded.note.uuid))) == "Delete Matthew 5:3?")
    }

    /// The app's `onChange` reloads the versions model (`AppModels`): the discard, its undo and its
    /// redo each reach it, so an open versions view never shows a text that went or misses one that came back.
    @Test func aDiscardAndItsUndoReachTheVersionsView() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let store = MarkupStore(container: container)
        let versions = NoteVersionsModel(store: store)
        let name = "NotesBrowserModelTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = NotesBrowserModel(store: store, defaults: defaults) { versions.reload() }
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.undoManager = undo
        let orphan = try keep("Lost words", of: UUID(), in: store)
        model.reload()
        model.filter = .keptVersions
        #expect(versions.orphan(id: orphan)?.body == "Lost words")

        var revision = versions.revision
        undo.beginUndoGrouping()
        model.delete(id: orphan)
        undo.endUndoGrouping()
        #expect(versions.revision > revision)
        #expect(versions.orphan(id: orphan) == nil)

        revision = versions.revision
        undo.undo()
        #expect(versions.revision > revision)
        #expect(versions.orphan(id: orphan)?.body == "Lost words")

        revision = versions.revision
        undo.redo()
        #expect(versions.revision > revision)
        #expect(versions.orphan(id: orphan) == nil)
    }

    // MARK: - Day groups (NotesBrowserFixture)

    @Test func theDaysAreTheGroupsByDate() throws {
        let fixture = try NotesBrowserFixture()
        let model = fixture.model()
        #expect(model.sort == .date)
        #expect(model.groups.map(\.title) == ["Today", "Yesterday", "Friday, November 20", "Wednesday, November 18", "Tuesday, November 17",
                                              "Friday, November 14, 2025"])
        #expect(model.groups.map(\.entries.count) == [2, 1, 1, 3, 1, 1])
        #expect(model.groups == model.days && model.sections.isEmpty)
        #expect(model.visibleIDs == model.groups.flatMap(\.entries).map(\.id))
        #expect(model.visibleIDs == model.entries.map(\.id))

        model.sort = .reference
        #expect(!model.sections.isEmpty && model.groups == model.sections)
        #expect(model.days.isEmpty)
        #expect(model.visibleIDs == model.sections.flatMap(\.entries).map(\.id))
    }

    /// The days and their counts follow what is listed; a day with nothing left has no heading.
    @Test func theDaysFollowTheFilterAndTheSearch() throws {
        let fixture = try NotesBrowserFixture()
        let model = fixture.model()

        // Noted highlights are highlights; the conversation, the bookmark and the chapter note go.
        model.filter = .highlights
        #expect(!model.groups.map(\.title).contains("Friday, November 14, 2025"))
        #expect(model.groups.first?.title == "Today")
        #expect(model.groups.first?.entries.map(\.id) == [fixture.abide, fixture.romans])
        let wednesday = try #require(model.groups.first { $0.title == "Wednesday, November 18" })
        #expect(wednesday.entries.map(\.id) == [fixture.johnThree])

        model.filter = .bookmarks
        #expect(model.groups.map(\.title) == ["Wednesday, November 18"])
        #expect(model.groups.flatMap(\.entries).map(\.id) == [fixture.provide])

        model.filter = .all
        model.query = "kingdom"
        model.applySearch()
        #expect(model.groups.map(\.title) == ["Tuesday, November 17"])
        #expect(model.groups.flatMap(\.entries).map(\.id) == [fixture.poorInSpirit])
    }

    /// A box for a clock the test moves.
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    /// The window used across midnight: the next rebuild moves "Today", and nothing before it does.
    @Test func theDaysAreMadeFromTheModelsClock() throws {
        let fixture = try NotesBrowserFixture()
        let clock = Clock(try #require(fixture.calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 23, minute: 58))))
        let model = NotesBrowserModel(store: fixture.store, defaults: fixture.defaults, now: { clock.now }, calendar: fixture.calendar, locale: fixture.locale)
        #expect(model.groups.first?.title == "Today")
        #expect(model.groups.first?.entries.map(\.id) == [fixture.abide, fixture.romans])

        clock.now = try #require(fixture.calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 0, minute: 2)))
        #expect(model.groups.first?.title == "Today")
        model.reload()
        #expect(model.groups.prefix(2).map(\.title) == ["Yesterday", "Sunday, November 22"])
        #expect(model.groups.first?.entries.map(\.id) == [fixture.abide, fixture.romans])
    }

    /// Left to the app, the model's calendar and locale follow the reader's time zone and region as
    /// they change (travel, System Settings), not as they were at launch.
    @Test func theModelFollowsTheReadersZoneAndRegionAsTheyChange() throws {
        let fixture = try NotesBrowserFixture()
        let model = NotesBrowserModel(store: fixture.store, defaults: fixture.defaults)
        #expect(model.calendar == .autoupdatingCurrent)
        #expect(model.locale == .autoupdatingCurrent)
    }

    /// Deleting a day's only row while it is selected: its heading goes, and the next day's first row is selected.
    @Test func deletingADaysLastNoteSelectsTheNextDaysFirst() throws {
        let fixture = try NotesBrowserFixture()
        let model = fixture.model()
        #expect(model.groups.first { $0.title == "Yesterday" }?.entries.map(\.id) == [fixture.stillWaters])
        #expect(model.groups.first { $0.title == "Friday, November 20" }?.entries.first?.id == fixture.vine)

        model.selectedID = fixture.stillWaters
        model.delete(id: fixture.stillWaters)
        #expect(!model.groups.map(\.title).contains("Yesterday"))
        #expect(model.groups.map(\.title).prefix(2) == ["Today", "Friday, November 20"])
        #expect(model.selectedID == fixture.vine)
    }
}

/// The Notes window's filter is segmented only while the window has room for its segments, and a
/// menu of the same choices otherwise (the whole-project review, I-5).
@Suite struct NotesBrowserFilterStyleTests {
    @Test(arguments: [
        (5, 600.0, false), (5, 980.0, false), (5, 999.0, false), (5, 1_000.0, true), (5, 1_100.0, true),
        (6, 1_000.0, false), (6, 1_100.0, false), (6, 1_199.0, false), (6, 1_200.0, true), (6, 1_400.0, true),
    ])
    func theFilterIsSegmentedOnlyWhenItFits(segments: Int, width: Double, segmented: Bool) {
        #expect(NotesBrowserView.filterIsSegmented(width: width, segments: segments) == segmented)
    }
}
