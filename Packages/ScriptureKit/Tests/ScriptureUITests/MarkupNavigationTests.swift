import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

/// Navigating the reader to a markup item from outside it (Notes browser, palette).
/// The fixture store has WEB and KJV with PSA, MAT (chapter 2 has verses 1-3) and TOB.
@MainActor @Suite final class MarkupNavigationTests {
    /// The scratch defaults suites this test made; each is removed before use and again when the
    /// test ends, so none is left in ~/Library/Preferences.
    private var defaultsNames: [String] = []

    deinit {
        for name in defaultsNames { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
    }

    private func makeDefaults() -> UserDefaults {
        let name = "MarkupNavigationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaultsNames.append(name)
        return defaults
    }

    private func make(defaults: UserDefaults? = nil) throws -> (NavigationModel, MarkupModel, MarkupStore) {
        let defaults = defaults ?? makeDefaults()
        let navigation = try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "WEB")
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let markup = MarkupModel(store: store, defaults: defaults)
        return (navigation, markup, store)
    }

    /// The reader's markup for the open chapter, loaded as the book reader loads it (no chapter
    /// clears it).
    private func loadReader(_ navigation: NavigationModel, _ markup: MarkupModel) {
        guard let location = navigation.location else {
            markup.clear(translationID: navigation.translationID)
            return
        }
        markup.load(book: location.book, chapters: location.chapter...location.chapter, chapterInView: location,
                    translationID: navigation.translationID)
    }

    @Test func showOpensTheChapterInTheItemsTranslationAndFocusesTheHighlight() throws {
        let (navigation, markup, store) = try make()
        let highlight = try store.addHighlight(book: "MAT", chapter: 2, verse: 2, endVerse: 2, startOffset: 0, endOffset: 3, translationID: "KJV", colorID: nil, quotedText: "And")
        try store.addNote(to: highlight, body: "x")
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 2, translationID: "KJV", highlightID: highlight.uuid)
        MarkupNavigation.show(target, navigation: navigation, markup: markup)
        #expect(navigation.translationID == "KJV")
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 2))
        #expect(navigation.scrollTarget?.verse == 2)
        #expect(markup.selectedHighlightIDs.isEmpty)   // not loaded yet
        loadReader(navigation, markup)
        #expect(markup.selectedHighlightIDs == [highlight.uuid])
        #expect(markup.outlinedHighlightID == highlight.uuid)
    }

    /// Showing an item is a lookup: the passage shows with a way back, and the place being read
    /// stays the stored position.
    @Test func showLeavesTheStoredPositionAlone() throws {
        let defaults = makeDefaults()
        let (navigation, markup, _) = try make(defaults: defaults)
        navigation.open(ChapterLocation(book: "MAT", chapter: 1))
        navigation.reportReadingPosition(VerseLocation(book: "MAT", chapter: 1, verse: 3))
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 2, translationID: "KJV", highlightID: nil)
        MarkupNavigation.show(target, navigation: navigation, markup: markup)
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 2) && navigation.translationID == "KJV")
        #expect(ReadingPositionStore(defaults: defaults).load() == ReadingPosition(book: "MAT", chapter: 1, firstVisibleVerse: 3, translationID: "WEB"))
        #expect(navigation.lookupReturn == ReadingPlace(location: ChapterLocation(book: "MAT", chapter: 1), verse: 3, translationID: "WEB"))
    }

    @Test func showInTheOpenChapterFocusesAtOnce() throws {
        let (navigation, markup, store) = try make()
        navigation.open(ChapterLocation(book: "MAT", chapter: 2))
        loadReader(navigation, markup)
        let highlight = try store.addHighlight(book: "MAT", chapter: 2, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "WEB", colorID: nil, quotedText: "Now")
        try store.addNote(to: highlight, body: "x")
        markup.reload()
        MarkupNavigation.show(MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: "WEB", highlightID: highlight.uuid), navigation: navigation, markup: markup)
        #expect(markup.selectedHighlightIDs == [highlight.uuid] && markup.outlinedHighlightID == highlight.uuid)
        #expect(navigation.translationID == "WEB" && navigation.scrollTarget?.verse == 1)
    }

    /// Show Note from the assistant for a note in another chapter: the editor opens once that
    /// chapter loads, not on the chapter being left (whose load would clear it).
    @Test func editWhenLoadedOpensTheNoteOnceItsChapterLoads() throws {
        let (navigation, markup, store) = try make()
        navigation.open(ChapterLocation(book: "MAT", chapter: 1))
        loadReader(navigation, markup)
        let note = try store.addChapterNote(book: "MAT", chapter: 2, translationID: "WEB", body: "x", sourceThreadID: nil)
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: "WEB", highlightID: nil)
        #expect(!markup.isLoaded(target))
        MarkupNavigation.show(target, navigation: navigation, markup: markup)
        markup.editWhenLoaded(noteID: note.uuid, target: target)
        #expect(markup.editingNoteID == nil)
        loadReader(navigation, markup)
        #expect(markup.isLoaded(target) && markup.editingNoteID == note.uuid)
    }

    /// A later Show supersedes a pending edit.
    @Test func aLaterShowDropsAPendingEdit() throws {
        let (navigation, markup, store) = try make()
        let note = try store.addChapterNote(book: "MAT", chapter: 2, translationID: "WEB", body: "x", sourceThreadID: nil)
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: "WEB", highlightID: nil)
        markup.editWhenLoaded(noteID: note.uuid, target: target)
        MarkupNavigation.show(target, navigation: navigation, markup: markup)
        loadReader(navigation, markup)
        #expect(markup.editingNoteID == nil)
    }

    /// The assistant's Show Note for a note in the chapter on screen: it opens at once, its highlight lit.
    @Test func openSavedNoteInTheLoadedChapterEditsAtOnce() throws {
        let (navigation, markup, store) = try make()
        navigation.open(ChapterLocation(book: "MAT", chapter: 2))
        loadReader(navigation, markup)
        let highlight = try store.addHighlight(book: "MAT", chapter: 2, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "WEB", colorID: nil, quotedText: "Now")
        let note = try store.addNote(to: highlight, body: "x")
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: "WEB", highlightID: highlight.uuid)
        MarkupNavigation.openSavedNote(note.uuid, at: target, navigation: navigation, markup: markup)
        #expect(markup.editingNoteID == note.uuid && markup.selectedHighlightIDs == [highlight.uuid])
        #expect(navigation.lookupReturn == nil)
    }

    /// For a note elsewhere, in a translation the app does not bundle: the chapter is looked up in
    /// the current translation and the note opens once it loads.
    @Test func openSavedNoteElsewhereEditsOnceItsChapterLoads() throws {
        let (navigation, markup, store) = try make()
        navigation.open(ChapterLocation(book: "MAT", chapter: 1))
        loadReader(navigation, markup)
        let note = try store.addChapterNote(book: "MAT", chapter: 2, translationID: "NIV", body: "x", sourceThreadID: nil)
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: "NIV", highlightID: nil)
        MarkupNavigation.openSavedNote(note.uuid, at: target, navigation: navigation, markup: markup)
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 2) && navigation.translationID == "WEB")
        #expect(navigation.lookupReturn?.location == ChapterLocation(book: "MAT", chapter: 1))
        #expect(markup.editingNoteID == nil)
        loadReader(navigation, markup)
        #expect(markup.editingNoteID == note.uuid)
    }

    @Test func unavailableTranslationFallsBackToTheCurrentOne() throws {
        let (navigation, markup, _) = try make()
        MarkupNavigation.show(MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 3, translationID: "NIV", highlightID: nil), navigation: navigation, markup: markup)
        #expect(navigation.translationID == "WEB")
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 2) && navigation.scrollTarget?.verse == 3)
    }

    @Test func bookmarkTargetScrollsWithoutSelecting() throws {
        let (navigation, markup, store) = try make()
        let highlight = try store.addHighlight(book: "MAT", chapter: 2, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "WEB", colorID: try store.colors()[0].uuid, quotedText: "Now")
        navigation.open(ChapterLocation(book: "MAT", chapter: 2))
        loadReader(navigation, markup)
        markup.focus(highlightID: highlight.uuid)
        MarkupNavigation.show(MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 3, translationID: nil, highlightID: nil), navigation: navigation, markup: markup)
        loadReader(navigation, markup)
        #expect(markup.selectedHighlightIDs.isEmpty && markup.outlinedHighlightID == nil)
        #expect(navigation.scrollTarget?.verse == 3)
    }

    @Test func aMissingHighlightIsDroppedOnLoad() throws {
        let (navigation, markup, _) = try make()
        MarkupNavigation.show(MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: nil, highlightID: UUID()), navigation: navigation, markup: markup)
        loadReader(navigation, markup)
        #expect(markup.selectedHighlightIDs.isEmpty)
    }

    @Test func entryInitMapsChapterNotesToVerseOneAndBookmarksToNoTranslation() {
        let noteID = UUID()
        let chapterNote = NotesBrowserEntry(
            id: noteID, kind: .note(noteID: noteID, highlightID: nil), book: "MAT", bookOrder: 40, chapter: 5, verse: 0, endVerse: 0,
            referenceString: "Matthew 5", translationID: "ESV", color: nil, quotedText: "", body: "x", modifiedAt: Date())
        let target = MarkupTarget(entry: chapterNote)
        #expect(target == MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 5), verse: 1, translationID: "ESV", highlightID: nil))
        let bookmarkID = UUID()
        let bookmark = NotesBrowserEntry(
            id: bookmarkID, kind: .bookmark(id: bookmarkID), book: "JHN", bookOrder: 43, chapter: 3, verse: 16, endVerse: 16,
            referenceString: "John 3:16", translationID: nil, color: nil, quotedText: "", body: "", modifiedAt: Date())
        #expect(MarkupTarget(entry: bookmark) == MarkupTarget(location: ChapterLocation(book: "JHN", chapter: 3), verse: 16, translationID: nil, highlightID: nil))
        let highlightID = UUID()
        let noted = NotesBrowserEntry(
            id: noteID, kind: .note(noteID: noteID, highlightID: highlightID), book: "MAT", bookOrder: 40, chapter: 5, verse: 3, endVerse: 4,
            referenceString: "Matthew 5:3-4", translationID: "KJV", color: nil, quotedText: "q", body: "x", modifiedAt: Date())
        #expect(MarkupTarget(entry: noted).highlightID == highlightID && MarkupTarget(entry: noted).verse == 3)
        let keptID = UUID()
        let kept = NotesBrowserEntry(
            id: keptID, kind: .keptVersion(id: keptID), book: "MAT", bookOrder: 40, chapter: 5, verse: 3, endVerse: 4,
            referenceString: "Matthew 5:3-4", translationID: "KJV", color: nil, quotedText: "q", body: "x", modifiedAt: Date())
        #expect(MarkupTarget(entry: kept) == MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 5), verse: 3, translationID: "KJV", highlightID: nil))
    }

    /// Add as Note appends to a note whose editor is open: the editor's sitting ends, its draft is
    /// reloaded from the note, and a new sitting begins, so its next save keeps the appended reply.
    @Test func addAsNoteIntoTheNoteOpenInTheEditorReloadsItsDraft() throws {
        let (navigation, markup, store) = try make()
        navigation.open(ChapterLocation(book: "MAT", chapter: 2))
        loadReader(navigation, markup)
        let highlight = try store.addHighlight(book: "MAT", chapter: 2, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "WEB", colorID: nil, quotedText: "Now")
        let note = try store.addNote(to: highlight, body: "Mine")
        markup.reload()
        markup.beginEditing(noteID: note.uuid)
        markup.updateNoteBody(noteID: note.uuid, body: "Mine, typed")
        let token = NoteVersion.token(ofMark: note.versionMark)
        let request = markup.editorReloadRequest

        try store.appendToNote(note, "The reply")
        let target = MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 2), verse: 1, translationID: "WEB", highlightID: highlight.uuid)
        MarkupNavigation.openSavedNote(note.uuid, at: target, navigation: navigation, markup: markup)
        #expect(markup.editingNoteID == note.uuid)
        #expect(markup.editorReloadRequest == request + 1)
        markup.updateNoteBody(noteID: note.uuid, body: "Mine, typed\n\nThe reply, read")
        #expect(NoteVersion.token(ofMark: note.versionMark) != token)
        #expect(NoteVersion.ancestorDigests(text: note.body, mark: note.versionMark, ancestry: note.versionAncestry).first
            == NoteVersion.digest("Mine, typed\n\nThe reply"))
    }
}
