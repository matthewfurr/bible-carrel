import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct MarkupStoreTests {
    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)

    private func makeStore() throws -> MarkupStore {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        return MarkupStore(container: container)
    }

    private func add(_ store: MarkupStore, verse: Int, start: Int = 0, end: Int = 5, color: UUID? = nil, translation: String = "ESV") throws -> Highlight {
        try store.addHighlight(book: "MAT", chapter: 5, verse: verse, endVerse: verse, startOffset: start, endOffset: end, translationID: translation, colorID: color, quotedText: "words")
    }

    @Test func highlightsAreScopedToTheChapterAndOrdered() throws {
        let store = try makeStore()
        let yellow = try store.colors()[0].uuid
        _ = try add(store, verse: 7, color: yellow)
        _ = try add(store, verse: 3, start: 10, color: yellow)
        _ = try add(store, verse: 3, start: 2, color: yellow)
        _ = try store.addHighlight(book: "MAT", chapter: 6, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "ESV", colorID: yellow, quotedText: "Be")
        let found = try store.highlights(in: matthew5)
        #expect(found.map { "\($0.verse):\($0.startOffset)" } == ["3:2", "3:10", "7:0"])
    }

    @Test func clearingTheColorOfANotelessHighlightDeletesIt() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3, color: try store.colors()[0].uuid)
        try store.setColor(nil, on: highlight)
        #expect(try store.highlights(in: matthew5).isEmpty)
    }

    @Test func clearingTheColorOfANotedHighlightKeepsIt() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3, color: try store.colors()[0].uuid)
        try store.addNote(to: highlight, body: "keep me")
        try store.setColor(nil, on: highlight)
        let found = try store.highlights(in: matthew5)
        #expect(found.count == 1 && found[0].colorID == nil && found[0].note?.body == "keep me")
    }

    @Test func deletingTheNoteOfAColorlessHighlightDeletesTheHighlight() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3)
        let note = try store.addNote(to: highlight, body: "temporary")
        #expect(note.scope == .highlight && note.quotedText == "words" && note.translationID == "ESV")
        try store.deleteNote(note)
        #expect(try store.highlights(in: matthew5).isEmpty)
        #expect(try store.notes(in: matthew5).isEmpty)
    }

    @Test func deletingTheNoteOfAColoredHighlightKeepsTheHighlight() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3, color: try store.colors()[1].uuid)
        let note = try store.addNote(to: highlight, body: "temporary")
        try store.deleteNote(note)
        #expect(try store.highlights(in: matthew5).count == 1)
    }

    @Test func secondNoteOnAHighlightIsRefused() throws {
        let store = try makeStore()
        let highlight = try add(store, verse: 3)
        try store.addNote(to: highlight, body: "one")
        #expect(throws: MarkupStoreError.highlightAlreadyHasNote) { try store.addNote(to: highlight, body: "two") }
    }

    @Test func bookmarkToggles() throws {
        let store = try makeStore()
        let location = VerseLocation(book: "MAT", chapter: 5, verse: 9)
        #expect(try store.toggleBookmark(at: location) == true)
        #expect(try store.bookmarks(in: matthew5).map(\.verse) == [9])
        #expect(try store.toggleBookmark(at: location) == false)
        #expect(try store.bookmark(at: location) == nil)
    }

    @Test func colorsCanBeAddedRenamedReorderedAndDeleted() throws {
        let store = try makeStore()
        let teal = try store.addColor(name: "Teal", lightHex: "#A0E0E0", darkHex: "#104040")
        #expect(teal.sortOrder == 5 && teal.isDefault == false)
        try store.renameColor(teal, to: "Sea")
        try store.moveColors(fromOffsets: IndexSet(integer: 5), toOffset: 0)
        #expect(try store.colors().map(\.name) == ["Sea", "Yellow", "Green", "Blue", "Rose", "Orange"])
        #expect(try store.colors().map(\.sortOrder) == [0, 1, 2, 3, 4, 5])
        let noted = try add(store, verse: 1, color: teal.uuid)
        try store.addNote(to: noted, body: "stays")
        _ = try add(store, verse: 2, color: teal.uuid)
        #expect(try store.highlightCount(usingColor: teal.uuid) == 2)
        try store.deleteColor(teal)
        #expect(try store.colors().count == 5)
        let remaining = try store.highlights(in: matthew5)
        #expect(remaining.count == 1 && remaining[0].colorID == nil && remaining[0].note?.body == "stays")
    }

    @Test func addColorAndSetColorHexConformToTheBand() throws {
        let store = try makeStore()
        let color = try store.addColor(name: "Navy", lightHex: "#1F4C7A", darkHex: "#B9DDFF")
        #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false))
        #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true))
        try store.setColorHex(color, lightHex: "#000000", darkHex: "#FFFFFF")
        #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false))
        #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true))
    }

    @Test func setColorHexConformsBothVariants() throws {
        let store = try makeStore()
        let color = try store.addColor(name: "Teal", lightHex: "#B8E8FF", darkHex: "#144D6E")
        // Picked in Dark Mode: the light well still receives a dark value.
        try store.setColorHex(color, lightHex: "#144D6E", darkHex: "#144D6E")
        #expect(MarkLightness.isInBand(hex: color.lightHex, dark: false))
        #expect(MarkLightness.isInBand(hex: color.darkHex, dark: true))
    }

    @Test func bookScopedQueriesCoverTheWindowInclusiveAndOrdered() throws {
        let store = try makeStore()
        let yellow = try store.colors()[0].uuid
        func highlight(_ book: String, _ chapter: Int, _ verse: Int, start: Int = 0) throws -> Highlight {
            try store.addHighlight(book: book, chapter: chapter, verse: verse, endVerse: verse, startOffset: start, endOffset: start + 3,
                                   translationID: "ESV", colorID: yellow, quotedText: "w")
        }
        _ = try highlight("MAT", 7, 1)
        _ = try highlight("MAT", 5, 9)
        _ = try highlight("MAT", 5, 3, start: 4)
        _ = try highlight("MAT", 5, 3, start: 1)
        _ = try highlight("MAT", 4, 1)      // below the window
        _ = try highlight("MAT", 8, 1)      // above it
        let other = try highlight("LUK", 6, 1)   // another book
        let noted = try highlight("MAT", 6, 2)
        try store.addNote(to: noted, body: "n")
        try store.addNote(to: other, body: "elsewhere")
        _ = try store.addChapterNote(book: "MAT", chapter: 5, translationID: "ESV", body: "c", sourceThreadID: nil)
        _ = try store.addChapterNote(book: "MAT", chapter: 8, translationID: "ESV", body: "out", sourceThreadID: nil)
        for (book, chapter, verse) in [("MAT", 7, 2), ("MAT", 5, 4), ("MAT", 5, 1), ("MAT", 4, 1), ("MAT", 8, 9), ("LUK", 6, 1)] {
            try store.toggleBookmark(at: VerseLocation(book: book, chapter: chapter, verse: verse))
        }

        let highlights = try store.highlights(inBook: "MAT", chapters: 5...7)
        #expect(highlights.map { "\($0.chapter):\($0.verse):\($0.startOffset)" } == ["5:3:1", "5:3:4", "5:9:0", "6:2:0", "7:1:0"])
        let notes = try store.notes(inBook: "MAT", chapters: 5...7)
        #expect(notes.map { "\($0.chapter):\($0.body)" } == ["5:c", "6:n"])
        let bookmarks = try store.bookmarks(inBook: "MAT", chapters: 5...7)
        #expect(bookmarks.map { "\($0.chapter):\($0.verse)" } == ["5:1", "5:4", "7:2"])
        // A one-chapter window is that chapter's query.
        #expect(try store.highlights(inBook: "MAT", chapters: 5...5).map(\.uuid) == store.highlights(in: matthew5).map(\.uuid))
        #expect(try store.bookmarks(inBook: "LUK", chapters: 1...24).map(\.chapter) == [6])
    }

    @Test func wholeBibleQueriesSpanChapters() throws {
        let store = try makeStore()
        let yellow = try store.colors()[0].uuid
        _ = try add(store, verse: 3, color: yellow)
        _ = try store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 2, translationID: "KJV", colorID: yellow, quotedText: "In")
        try store.toggleBookmark(at: VerseLocation(book: "JHN", chapter: 3, verse: 16))
        #expect(try store.allHighlights().count == 2)
        #expect(try store.allBookmarks().map(\.book) == ["JHN"])
        let bookmark = try store.allBookmarks()[0]
        #expect(try store.bookmark(id: bookmark.uuid)?.verse == 16)
        #expect(try store.highlight(id: try store.allHighlights()[0].uuid) != nil)
        try store.deleteBookmark(bookmark)
        #expect(try store.allBookmarks().isEmpty)
    }

    @Test func searchHitsBodyQuotedTextAndReference() throws {
        let store = try makeStore()
        let a = try store.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed are the poor")
        let note = try store.addNote(to: a, body: "The **Beatitudes** begin here.")
        #expect(try store.note(id: note.uuid)?.body == note.body)
        let b = try store.addHighlight(book: "GEN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 2, translationID: "KJV", colorID: try store.colors()[0].uuid, quotedText: "In the beginning")
        try store.toggleBookmark(at: VerseLocation(book: "JHN", chapter: 3, verse: 16))

        let byBody = try store.search("beatitudes")
        #expect(byBody.notes.map(\.uuid) == [note.uuid] && byBody.highlights.isEmpty && byBody.bookmarks.isEmpty)
        let byQuote = try store.search("BEGINNING")
        #expect(byQuote.highlights.map(\.uuid) == [b.uuid] && byQuote.notes.isEmpty)
        let byReference = try store.search("John 3")
        #expect(byReference.bookmarks.count == 1 && byReference.notes.isEmpty && byReference.highlights.isEmpty)
        let byBookName = try store.search("Matthew 5:3")
        #expect(byBookName.notes.count == 1 && byBookName.highlights.map(\.uuid) == [a.uuid])
        let everything = try store.search("  ")
        #expect(everything.notes.count == 1 && everything.highlights.count == 2 && everything.bookmarks.count == 1)
        #expect(try store.search("zzz").notes.isEmpty)
    }

    @Test func chapterColorIDsHasTheMarkedChaptersAndTheColoursOfTheirHighlights() throws {
        let store = try makeStore()
        let colors = try store.colors()
        let (yellow, green) = (colors[0].uuid, colors[1].uuid)
        _ = try store.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "WEB", colorID: yellow, quotedText: "Blessed")
        _ = try store.addHighlight(book: "MAT", chapter: 5, verse: 4, endVerse: 4, startOffset: 0, endOffset: 7, translationID: "KJV", colorID: green, quotedText: "Blessed")
        _ = try store.addHighlight(book: "MAT", chapter: 5, verse: 5, endVerse: 5, startOffset: 0, endOffset: 7, translationID: "WEB", colorID: yellow, quotedText: "Blessed")
        let bare = try store.addHighlight(book: "JHN", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, translationID: "WEB", colorID: nil, quotedText: "In the")
        _ = try store.addNote(to: bare, body: "A note")
        _ = try store.toggleBookmark(at: VerseLocation(book: "TOB", chapter: 1, verse: 1))
        let ids = try store.chapterColorIDs()
        #expect(Set(ids.keys) == (try store.markedChapters()))
        #expect(ids[ChapterLocation(book: "MAT", chapter: 5)] == [yellow, green])
        #expect(ids[ChapterLocation(book: "JHN", chapter: 1)] == [])
        #expect(ids[ChapterLocation(book: "TOB", chapter: 1)] == [])
    }

    @Test func markedChaptersListsEveryChapterWithAMark() throws {
        let store = try makeStore()
        let color = try store.colors()[0]
        _ = try store.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "WEB", colorID: color.uuid, quotedText: "Blessed")
        _ = try store.addChapterNote(book: "PSA", chapter: 23, translationID: "WEB", body: "Shepherd", sourceThreadID: nil)
        _ = try store.toggleBookmark(at: VerseLocation(book: "TOB", chapter: 1, verse: 1))
        #expect(try store.markedChapters() == [ChapterLocation(book: "MAT", chapter: 5), ChapterLocation(book: "PSA", chapter: 23), ChapterLocation(book: "TOB", chapter: 1)])
    }
}

@MainActor @Suite struct MarkupStoreAssistantTests {
    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)

    private func makeStore() throws -> MarkupStore {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        return MarkupStore(container: container)
    }

    private func add(_ store: MarkupStore, verse: Int) throws -> Highlight {
        try store.addHighlight(book: "MAT", chapter: 5, verse: verse, endVerse: verse, startOffset: 0, endOffset: 5, translationID: "ESV", colorID: nil, quotedText: "words")
    }

    @Test func chapterNotesAndAppendsCarryTheThread() throws {
        let store = try makeStore()
        let thread = UUID()
        let note = try store.addChapterNote(book: "MAT", chapter: 5, translationID: "ESV", body: "**Q:** why?\n\nBecause.", sourceThreadID: thread)
        #expect(note.scope == .chapter && note.verse == 0 && note.sourceThreadID == thread && note.quotedText == "")
        #expect(try store.notes(in: matthew5).map(\.uuid) == [note.uuid])
        let highlight = try add(store, verse: 3)
        let existing = try store.addNote(to: highlight, body: "mine", sourceThreadID: nil)
        try store.appendToNote(existing, "**Q:** q\n\na")
        #expect(existing.body == "mine\n\n**Q:** q\n\na")
        let blank = try store.addNote(to: try add(store, verse: 4), body: "  ", sourceThreadID: nil)
        try store.appendToNote(blank, "x")
        #expect(blank.body == "x")
    }

    @Test func threadDeletionIsUndoableThroughTheMarkupStore() throws {
        let store = try makeStore()
        let thread = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "t")
        let captured = try store.delete(.thread(ThreadSnapshot(thread)))
        #expect(try store.chat.allThreads().isEmpty)
        #expect(captured?.actionName == "Delete Conversation")
        try store.restore(try #require(captured))
        #expect(try store.chat.allThreads().map(\.title) == ["t"])
    }
}
