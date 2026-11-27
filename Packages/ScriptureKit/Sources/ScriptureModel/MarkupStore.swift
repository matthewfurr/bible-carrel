import Foundation
import OSLog
import ScriptureData
import SwiftData

public enum MarkupStoreError: Error, Equatable {
    case highlightAlreadyHasNote
}

/// What `MarkupStore.search` found, per record kind.
public struct MarkupSearchResults {
    public var notes: [Note]
    public var highlights: [Highlight]
    public var bookmarks: [Bookmark]

    public init(notes: [Note], highlights: [Highlight], bookmarks: [Bookmark]) {
        self.notes = notes
        self.highlights = highlights
        self.bookmarks = bookmarks
    }
}

/// Chapter-scoped queries and every mutation of user markup. Owns the rules the models do not:
/// a highlight with no color and no note is deleted, a highlight carries at most one note,
/// deleting a color strips it from its highlights. Every mutation saves.
///
/// Owns the `ModelContainer`: a `ModelContext` does not retain its container, and fetching with a
/// predicate on a context whose container was released traps inside SwiftData.
@MainActor
public final class MarkupStore {
    public let container: ModelContainer
    public let context: ModelContext
    /// Conversations on the same container, so a thread delete is undoable like any other.
    public let chat: ChatStore
    /// This device's last text of each note it wrote, recorded before each save of a note's text.
    public let journal: LastTextJournal
    /// The kind of device a sitting here is on, unless the sitting names another.
    public let deviceKind: String
    /// The notes with a sitting begun and not yet ended.
    public internal(set) var openSittings: Set<UUID> = []
    let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "markup")

    /// With no journal, an in-memory one.
    public init(container: ModelContainer, journal: LastTextJournal? = nil, deviceKind: String = DeviceKind.current) {
        self.container = container
        self.context = container.mainContext
        self.chat = ChatStore(container: container)
        self.journal = journal ?? LastTextJournal(directory: nil)
        self.deviceKind = deviceKind
    }

    // MARK: - Queries
    //
    // Every list read returns one record per uuid (`Twins`): of two notes the later `modifiedAt`,
    // of two highlights one with a note, of any other kind the first fetched.

    /// Highlights of one chapter, by verse, then start offset, then creation time.
    public func highlights(in chapter: ChapterLocation) throws -> [Highlight] {
        let book = chapter.book, number = chapter.chapter
        let descriptor = FetchDescriptor<Highlight>(predicate: #Predicate { $0.book == book && $0.chapter == number })
        return Twins.highlights(try context.fetch(descriptor)).sorted {
            ($0.verse, $0.startOffset, $0.createdAt) < ($1.verse, $1.startOffset, $1.createdAt)
        }
    }

    /// Notes of one chapter, by verse then creation time.
    public func notes(in chapter: ChapterLocation) throws -> [Note] {
        let book = chapter.book, number = chapter.chapter
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.book == book && $0.chapter == number })
        return Twins.notes(try context.fetch(descriptor)).sorted { ($0.verse, $0.createdAt) < ($1.verse, $1.createdAt) }
    }

    public func bookmarks(in chapter: ChapterLocation) throws -> [Bookmark] {
        let book = chapter.book, number = chapter.chapter
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.book == book && $0.chapter == number })
        return Twins.firsts(try context.fetch(descriptor), id: \.uuid).sorted { $0.verse < $1.verse }
    }

    // A range of a book's chapters in one fetch each (the reader's reload, of the open chapter;
    // the range is one chapter): the per-chapter queries' order within each chapter, chapters
    // ascending. Both bounds are inclusive.

    /// Highlights of `chapters` of `book`, by chapter, then as `highlights(in:)` orders them.
    public func highlights(inBook book: String, chapters: ClosedRange<Int>) throws -> [Highlight] {
        let low = chapters.lowerBound, high = chapters.upperBound
        let descriptor = FetchDescriptor<Highlight>(predicate: #Predicate { $0.book == book && $0.chapter >= low && $0.chapter <= high })
        return Twins.highlights(try context.fetch(descriptor)).sorted {
            ($0.chapter, $0.verse, $0.startOffset, $0.createdAt) < ($1.chapter, $1.verse, $1.startOffset, $1.createdAt)
        }
    }

    /// Notes of `chapters` of `book`, by chapter, then as `notes(in:)` orders them.
    public func notes(inBook book: String, chapters: ClosedRange<Int>) throws -> [Note] {
        let low = chapters.lowerBound, high = chapters.upperBound
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.book == book && $0.chapter >= low && $0.chapter <= high })
        return Twins.notes(try context.fetch(descriptor)).sorted { ($0.chapter, $0.verse, $0.createdAt) < ($1.chapter, $1.verse, $1.createdAt) }
    }

    /// Bookmarks of `chapters` of `book`, by chapter, then verse.
    public func bookmarks(inBook book: String, chapters: ClosedRange<Int>) throws -> [Bookmark] {
        let low = chapters.lowerBound, high = chapters.upperBound
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.book == book && $0.chapter >= low && $0.chapter <= high })
        return Twins.firsts(try context.fetch(descriptor), id: \.uuid).sorted { ($0.chapter, $0.verse) < ($1.chapter, $1.verse) }
    }

    public func bookmark(at location: VerseLocation) throws -> Bookmark? {
        let book = location.book, chapter = location.chapter, verse = location.verse
        var descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.book == book && $0.chapter == chapter && $0.verse == verse })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func colors() throws -> [HighlightColor] {
        Twins.firsts(try context.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)])), id: \.uuid)
    }

    public func color(id: UUID) throws -> HighlightColor? {
        var descriptor = FetchDescriptor<HighlightColor>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Whole-Bible queries and search

    /// Every highlight, in no particular order; callers sort.
    public func allHighlights() throws -> [Highlight] {
        Twins.highlights(try context.fetch(FetchDescriptor<Highlight>()))
    }

    public func allNotes() throws -> [Note] {
        Twins.notes(try context.fetch(FetchDescriptor<Note>()))
    }

    public func allBookmarks() throws -> [Bookmark] {
        Twins.firsts(try context.fetch(FetchDescriptor<Bookmark>()), id: \.uuid)
    }

    /// Every chapter carrying at least one highlight, note or bookmark. Conversations do not count.
    public func markedChapters() throws -> Set<ChapterLocation> {
        var chapters = Set<ChapterLocation>()
        for highlight in try allHighlights() { chapters.insert(highlight.chapterLocation) }
        for note in try allNotes() { chapters.insert(note.chapterLocation) }
        for bookmark in try allBookmarks() { chapters.insert(ChapterLocation(book: bookmark.book, chapter: bookmark.chapter)) }
        return chapters
    }

    /// Every chapter with a highlight, note or bookmark (the keys of `markedChapters()`), and the
    /// ids of the colours its highlights have: maybe none (a bookmark, a note, an uncoloured highlight).
    public func chapterColorIDs() throws -> [ChapterLocation: Set<UUID>] {
        var chapters = [ChapterLocation: Set<UUID>]()
        for highlight in try allHighlights() {
            chapters[highlight.chapterLocation, default: []].formUnion(highlight.colorID.map { [$0] } ?? [])
        }
        var bare = Set<ChapterLocation>()
        for note in try allNotes() { bare.insert(note.chapterLocation) }
        for bookmark in try allBookmarks() { bare.insert(ChapterLocation(book: bookmark.book, chapter: bookmark.chapter)) }
        for location in bare where chapters[location] == nil { chapters[location] = [] }
        return chapters
    }

    /// The copy the list reads return, when records share the uuid.
    public func highlight(id: UUID) throws -> Highlight? {
        Twins.highlights(try context.fetch(FetchDescriptor<Highlight>(predicate: #Predicate { $0.uuid == id }))).first
    }

    /// The copy the list reads return, when records share the uuid.
    public func note(id: UUID) throws -> Note? {
        Twins.notes(try noteRecords(id)).first
    }

    /// Every record with the uuid: a copy can share it.
    func noteRecords(_ id: UUID) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == id }))
    }

    /// `note` and every other record with its uuid.
    private func copies(of note: Note) throws -> [Note] {
        [note] + (try noteRecords(note.uuid)).filter { $0.persistentModelID != note.persistentModelID }
    }

    public func bookmark(id: UUID) throws -> Bookmark? {
        var descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func deleteBookmark(_ bookmark: Bookmark) throws {
        context.delete(bookmark)
        try context.save()
    }

    /// Notes match on body, quoted text or reference; highlights on quoted text or reference;
    /// bookmarks on reference. A blank query returns everything. Reference matching runs in
    /// memory over the user's own records (`MarkupSearch.matchesReference`). A text match counts
    /// only on the copy the list reads return.
    public func search(_ query: String) throws -> MarkupSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return MarkupSearchResults(notes: try allNotes(), highlights: try allHighlights(), bookmarks: try allBookmarks())
        }
        let noteHits = try context.fetch(FetchDescriptor<Note>(predicate: #Predicate {
            $0.body.localizedStandardContains(trimmed) || $0.quotedText.localizedStandardContains(trimmed)
        }))
        let highlightHits = try context.fetch(FetchDescriptor<Highlight>(predicate: #Predicate {
            $0.quotedText.localizedStandardContains(trimmed)
        }))
        let readNotes = try allNotes(), readHighlights = try allHighlights()
        let notes = union(read(noteHits, of: readNotes), readNotes.filter {
            MarkupSearch.matchesReference(trimmed, book: $0.book, chapter: $0.chapter, verse: $0.verse, endVerse: $0.endVerse)
        })
        let highlights = union(read(highlightHits, of: readHighlights), readHighlights.filter {
            MarkupSearch.matchesReference(trimmed, book: $0.book, chapter: $0.chapter, verse: $0.verse, endVerse: $0.endVerse)
        })
        let bookmarks = try allBookmarks().filter {
            MarkupSearch.matchesReference(trimmed, book: $0.book, chapter: $0.chapter, verse: $0.verse, endVerse: $0.verse)
        }
        return MarkupSearchResults(notes: notes, highlights: highlights, bookmarks: bookmarks)
    }

    /// The hits that are among the copies a list read returned.
    private func read<T: PersistentModel>(_ hits: [T], of listed: [T]) -> [T] {
        let ids = Set(listed.map(\.persistentModelID))
        return hits.filter { ids.contains($0.persistentModelID) }
    }

    private func union<T: PersistentModel>(_ first: [T], _ second: [T]) -> [T] {
        var seen = Set(first.map(\.persistentModelID))
        var result = first
        for item in second where !seen.contains(item.persistentModelID) {
            seen.insert(item.persistentModelID)
            result.append(item)
        }
        return result
    }

    // MARK: - Highlights and notes

    @discardableResult
    public func addHighlight(
        book: String, chapter: Int, verse: Int, endVerse: Int,
        startOffset: Int, endOffset: Int,
        translationID: String, colorID: UUID?, quotedText: String
    ) throws -> Highlight {
        let highlight = Highlight(
            book: book, chapter: chapter, verse: verse, endVerse: endVerse,
            startOffset: startOffset, endOffset: endOffset,
            translationID: translationID, colorID: colorID, quotedText: quotedText)
        context.insert(highlight)
        try context.save()
        return highlight
    }

    /// Recolors (or uncolors) a highlight; an uncolored highlight without a note is deleted.
    public func setColor(_ colorID: UUID?, on highlight: Highlight) throws {
        highlight.colorID = colorID
        highlight.modifiedAt = Date()
        try deleteIfEmpty(highlight)
        try context.save()
    }

    /// Moves an existing highlight onto new verses, offsets and quoted text, keeping its uuid,
    /// color and note; the note's verses and quote follow it. Nothing when it is gone.
    /// `updateRange(highlightID:selection:)` (in ScriptureUI, where `TextSelection` lives) calls this.
    public func updateRange(highlightID: UUID, verse: Int, endVerse: Int, startOffset: Int, endOffset: Int,
                            quotedText: String) throws {
        guard let highlight = try highlight(id: highlightID) else { return }
        highlight.verse = verse
        highlight.endVerse = endVerse
        highlight.startOffset = startOffset
        highlight.endOffset = endOffset
        highlight.quotedText = quotedText
        highlight.modifiedAt = Date()
        if let note = highlight.note {
            note.verse = verse
            note.endVerse = endVerse
            note.quotedText = quotedText
        }
        try context.save()
    }

    @discardableResult
    public func addNote(to highlight: Highlight, body: String) throws -> Note {
        try addNote(to: highlight, body: body, sourceThreadID: nil)
    }

    /// `sourceThreadID` names the conversation a reply was saved from (Add as Note).
    @discardableResult
    public func addNote(to highlight: Highlight, body: String, sourceThreadID: UUID?) throws -> Note {
        guard highlight.note == nil else { throw MarkupStoreError.highlightAlreadyHasNote }
        let note = Note(
            body: body, scope: .highlight,
            book: highlight.book, chapter: highlight.chapter, verse: highlight.verse, endVerse: highlight.endVerse,
            translationID: highlight.translationID, quotedText: highlight.quotedText)
        note.sourceThreadID = sourceThreadID
        let now = Date()
        markNew(note, on: highlight, now: now)
        context.insert(note)
        highlight.note = note
        highlight.modifiedAt = now
        try context.save()
        return note
    }

    /// A note on the whole chapter (verse 0, no anchor), shown in the band under the heading.
    @discardableResult
    public func addChapterNote(book: String, chapter: Int, translationID: String, body: String, sourceThreadID: UUID?) throws -> Note {
        let note = Note(body: body, scope: .chapter, book: book, chapter: chapter, verse: 0, endVerse: 0, translationID: translationID, quotedText: "")
        note.sourceThreadID = sourceThreadID
        markNew(note, on: nil, now: Date())
        context.insert(note)
        try context.save()
        return note
    }

    /// Adds a paragraph to the end of a note; a blank note just takes the addition. A draft of the
    /// note's open editor that another device's text replaced is kept first (`settleEntry`).
    public func appendToNote(_ note: Note, _ addition: String) throws {
        try settleEntry(beforeWriting: note)
        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? addition : note.body + "\n\n" + addition
        try updateNote(note, body: body)
    }

    /// Saves the note's text in `sitting`, or in a sitting of its own begun and ended here. The
    /// journal entry is written first; then the text, its mark, and where the sitting started and
    /// its kind when the stored ones are not the sitting's, in one save, on every record with the
    /// note's uuid. A copy's differing text is kept first, in the same save (`keepUnseen`), unless
    /// it is this sitting's own earlier save or one the sitting opened on: the settle skips a note
    /// with a sitting open, and no journal may hold that text.
    public func updateNote(_ note: Note, body: String, sitting: NoteSitting? = nil, now: Date = Date()) throws {
        // A sitting of another note is never this note's: the save takes a sitting of its own.
        let given = sitting?.noteID == note.uuid ? sitting : nil
        // A sitting of its own leaves `openSittings` as it found it: an editor's open sitting on the note stays open.
        let endsHere = given == nil && !openSittings.contains(note.uuid)
        let sitting = given ?? openSitting(on: note)
        defer { if endsHere { endSitting(sitting) } }
        journalText(of: note, body: body, on: note.highlight, writtenAt: now, writer: journal.deviceTag)
        let mark = NoteVersion.mark(token: sitting.token, text: body)
        let records = try copies(of: note)
        for copy in records.dropFirst() where NoteVersion.token(ofMark: copy.versionMark) != sitting.token {
            _ = keepUnseen(copy, under: body, mark: mark, ancestry: sitting.ancestry)
        }
        for copy in records {
            copy.body = body
            copy.modifiedAt = now
            copy.versionMark = mark
            if copy.versionAncestry != sitting.ancestry { copy.versionAncestry = sitting.ancestry }
            if copy.deviceKind != sitting.deviceKind { copy.deviceKind = sitting.deviceKind }
        }
        try context.save()
    }

    /// Removes the note, every record with its uuid; an anchor goes too when nothing else keeps it.
    /// A note with text leaves one `DeletionMarker` in the same save, and a copy's differing text
    /// the note was not made with sight of is kept first, as a version with no note (`keepUnseen`).
    public func deleteNote(_ note: Note, now: Date = Date()) throws {
        let copies = try copies(of: note)
        for copy in copies.dropFirst() {
            _ = keepUnseen(copy, under: note.body, mark: note.versionMark, ancestry: note.versionAncestry)
        }
        markDeletion(of: note, now: now)
        for copy in copies {
            let highlight = copy.highlight
            highlight?.note = nil
            context.delete(copy)
            if let highlight { try deleteIfEmpty(highlight) }
        }
        try context.save()
    }

    public func deleteIfEmpty(_ highlight: Highlight) throws {
        guard highlight.isEmpty else { return }
        context.delete(highlight)
        try context.save()
    }

    /// Its note goes with it, leaving a `DeletionMarker` in the same save when it has text.
    public func deleteHighlight(_ highlight: Highlight, now: Date = Date()) throws {
        if let note = highlight.note { markDeletion(of: note, now: now) }
        context.delete(highlight)
        try context.save()
    }

    // MARK: - Undoable deletes

    /// Deletes what `deletion` describes, by uuid, and returns the deletion as it stood (for the
    /// undo). Nil when the record is already gone. A note's anchor is captured before the delete,
    /// so an undo can bring back a colorless anchor that went with its note.
    @discardableResult
    public func delete(_ deletion: MarkupDeletion) throws -> MarkupDeletion? {
        switch deletion {
        case .note(let snapshot, _):
            guard let note = try note(id: snapshot.uuid) else { return nil }
            let captured = MarkupDeletion.note(NoteSnapshot(note), anchor: note.highlight.map(HighlightSnapshot.init))
            try deleteNote(note)
            return captured
        case .highlight(let snapshot):
            guard let highlight = try highlight(id: snapshot.uuid) else { return nil }
            let captured = MarkupDeletion.highlight(HighlightSnapshot(highlight))
            try deleteHighlight(highlight)
            return captured
        case .bookmark(let snapshot):
            guard let bookmark = try bookmark(id: snapshot.uuid) else { return nil }
            let captured = MarkupDeletion.bookmark(BookmarkSnapshot(bookmark))
            try deleteBookmark(bookmark)
            return captured
        case .thread(let snapshot):
            guard let thread = try chat.thread(id: snapshot.uuid) else { return nil }
            let captured = MarkupDeletion.thread(ThreadSnapshot(thread))
            try chat.deleteThread(thread)
            return captured
        case .keptVersion(let snapshot):
            let copies = try keptVersionRecords(snapshot.uuid)
            guard let first = copies.first else { return nil }
            let captured = MarkupDeletion.keptVersion(KeptVersionSnapshot(first))
            for copy in copies { context.delete(copy) }
            try context.save()
            return captured
        }
    }

    /// Puts back what a delete removed, with the same uuids and dates (a kept version only when no
    /// record has its uuid), a note with its three version
    /// values and its text journaled again. The undo cancels the delete, so the note's markers that
    /// name the restored text go in the restore's save; a marker of that note naming another text
    /// stays. Restoring onto an anchor
    /// that still exists attaches the note to it; anything already present is left as it is.
    public func restore(_ deletion: MarkupDeletion) throws {
        switch deletion {
        case .note(let snapshot, let anchor):
            guard try note(id: snapshot.uuid) == nil else { return }
            if let anchor {
                if let existing = try highlight(id: anchor.uuid) {
                    guard existing.note == nil else { return }
                    let note = snapshot.make()
                    context.insert(note)
                    existing.note = note
                    try restoreText(of: note, on: existing)
                } else {
                    let highlight = anchor.make()
                    context.insert(highlight)
                    let note = snapshot.make()
                    context.insert(note)
                    highlight.note = note
                    try restoreText(of: note, on: highlight)
                }
            } else {
                let note = snapshot.make()
                context.insert(note)
                try restoreText(of: note, on: nil)
            }
        case .highlight(let snapshot):
            guard try highlight(id: snapshot.uuid) == nil else { return }
            let highlight = snapshot.make()
            context.insert(highlight)
            if let noteSnapshot = snapshot.note, try note(id: noteSnapshot.uuid) == nil {
                let note = noteSnapshot.make()
                context.insert(note)
                highlight.note = note
                try restoreText(of: note, on: highlight)
            }
        case .bookmark(let snapshot):
            let location = VerseLocation(book: snapshot.book, chapter: snapshot.chapter, verse: snapshot.verse)
            guard try bookmark(id: snapshot.uuid) == nil, try bookmark(at: location) == nil else { return }
            let bookmark = Bookmark(book: snapshot.book, chapter: snapshot.chapter, verse: snapshot.verse, label: snapshot.label)
            bookmark.uuid = snapshot.uuid
            bookmark.createdAt = snapshot.createdAt
            context.insert(bookmark)
        case .thread(let snapshot):
            try chat.restore(snapshot)
        case .keptVersion(let snapshot):
            guard try keptVersionRecords(snapshot.uuid).isEmpty else { return }
            context.insert(snapshot.make())
        }
        try context.save()
    }

    // MARK: - Bookmarks

    /// Returns true when a bookmark now exists at the location.
    @discardableResult
    public func toggleBookmark(at location: VerseLocation) throws -> Bool {
        if let existing = try bookmark(at: location) {
            context.delete(existing)
            try context.save()
            return false
        }
        context.insert(Bookmark(book: location.book, chapter: location.chapter, verse: location.verse))
        try context.save()
        return true
    }

    // MARK: - Colors

    /// Both variants are held to the marks' lightness band (`MarkLightness.conformed`), so the
    /// stored hex can differ from the one passed in.
    @discardableResult
    public func addColor(name: String, lightHex: String, darkHex: String) throws -> HighlightColor {
        let next = (try colors().map(\.sortOrder).max() ?? -1) + 1
        let color = HighlightColor(
            name: name,
            lightHex: MarkLightness.conformed(hex: lightHex, dark: false),
            darkHex: MarkLightness.conformed(hex: darkHex, dark: true),
            sortOrder: next,
            isDefault: false)
        context.insert(color)
        try context.save()
        return color
    }

    public func renameColor(_ color: HighlightColor, to name: String) throws {
        color.name = name
        try context.save()
    }

    /// Conforms both variants to the band, as `addColor` does.
    public func setColorHex(_ color: HighlightColor, lightHex: String, darkHex: String) throws {
        color.lightHex = MarkLightness.conformed(hex: lightHex, dark: false)
        color.darkHex = MarkLightness.conformed(hex: darkHex, dark: true)
        try context.save()
    }

    public func moveColors(fromOffsets: IndexSet, toOffset: Int) throws {
        let ordered = Self.moving(try colors(), fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, color) in ordered.enumerated() { color.sortOrder = index }
        try context.save()
    }

    /// SwiftUI's `move(fromOffsets:toOffset:)` semantics (`toOffset` indexes the array before removal).
    static func moving<T>(_ array: [T], fromOffsets: IndexSet, toOffset: Int) -> [T] {
        let moved = fromOffsets.map { array[$0] }
        var remaining = array.enumerated().filter { !fromOffsets.contains($0.offset) }.map(\.element)
        let removedBefore = fromOffsets.filter { $0 < toOffset }.count
        remaining.insert(contentsOf: moved, at: min(max(toOffset - removedBefore, 0), remaining.count))
        return remaining
    }

    /// Rewrites `sortOrder` to match `ids`; colors not listed keep their relative order after them.
    public func setColorOrder(_ ids: [UUID]) throws {
        let current = try colors()
        let listed = ids.compactMap { id in current.first { $0.uuid == id } }
        let rest = current.filter { color in !ids.contains(color.uuid) }
        for (index, color) in (listed + rest).enumerated() { color.sortOrder = index }
        try context.save()
    }

    public func highlightCount(usingColor id: UUID) throws -> Int {
        try context.fetchCount(FetchDescriptor<Highlight>(predicate: #Predicate { $0.colorID == id }))
    }

    /// Removes the color; its highlights lose the color and, without a note, are deleted.
    public func deleteColor(_ color: HighlightColor) throws {
        let id = color.uuid
        let users = try context.fetch(FetchDescriptor<Highlight>(predicate: #Predicate { $0.colorID == id }))
        for highlight in users {
            highlight.colorID = nil
            highlight.modifiedAt = Date()
            if highlight.isEmpty { context.delete(highlight) }
        }
        context.delete(color)
        try context.save()
        try moveColors(fromOffsets: [], toOffset: 0)
    }
}
