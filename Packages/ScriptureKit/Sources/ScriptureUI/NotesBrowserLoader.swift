import Foundation
import ScriptureData
import ScriptureModel

/// Builds the Notes browser's value entries from the markup store: every note, noteless
/// highlight, bookmark and conversation, or those matching a search. Shared by the browser and
/// the Markdown export.
public enum NotesBrowserLoader {
    /// An empty query means everything. Conversations match by title, questions or replies.
    /// `includingKeptVersions` (the Notes browser alone asks for it, so ⌘K and the Markdown export
    /// never see a text with no note) gives each note its count of versions and adds one entry per
    /// kept version whose note is gone, searched as a note is.
    @MainActor
    public static func entries(store: MarkupStore, query: String, includingKeptVersions: Bool = false) throws -> [NotesBrowserEntry] {
        let colors = try store.colors()
        let counts = includingKeptVersions ? try store.keptVersionCounts() : [:]
        let orphans = includingKeptVersions ? try store.orphanVersions().filter { matches($0, query: query) }.map(entry(for:)) : []
        return entries(from: try store.search(query), colors: colors, versionCounts: counts) + orphans
            + (try threads(store: store, matching: query)).map(entry(for:))
    }

    /// A highlight with a note shows once, as its note; a hit on either record yields that entry.
    /// A note's count is 1 more than its kept versions in `versionCounts`.
    static func entries(from results: MarkupSearchResults, colors: [HighlightColor], versionCounts: [UUID: Int] = [:]) -> [NotesBrowserEntry] {
        var result: [NotesBrowserEntry] = []
        var seen: Set<UUID> = []
        func noteEntry(_ note: Note) -> NotesBrowserEntry {
            entry(for: note, colors: colors, versionCount: 1 + versionCounts[note.uuid, default: 0])
        }
        for note in results.notes {
            result.append(noteEntry(note))
            seen.insert(note.uuid)
        }
        for highlight in results.highlights {
            if let note = highlight.note {
                guard !seen.contains(note.uuid) else { continue }
                seen.insert(note.uuid)
                result.append(noteEntry(note))
            } else {
                result.append(entry(for: highlight, colors: colors))
            }
        }
        result.append(contentsOf: results.bookmarks.map(entry(for:)))
        return result
    }

    static func entry(for note: Note, colors: [HighlightColor], versionCount: Int = 1) -> NotesBrowserEntry {
        let highlight = note.highlight
        let isChapter = note.scope == .chapter
        let color = highlightColor(for: highlight?.colorID, in: colors)
        return NotesBrowserEntry(
            id: note.uuid,
            kind: .note(noteID: note.uuid, highlightID: highlight?.uuid),
            book: note.book,
            bookOrder: bookOrder(note.book),
            chapter: note.chapter,
            verse: isChapter ? 0 : note.verse,
            endVerse: isChapter ? 0 : note.endVerse,
            referenceString: MarkupReferenceText.string(book: note.book, chapter: note.chapter, verse: isChapter ? nil : note.verse, endVerse: note.endVerse),
            translationID: note.translationID,
            color: color.map(markupColor),
            quotedText: note.quotedText,
            body: note.body,
            modifiedAt: max(note.modifiedAt, highlight?.modifiedAt ?? .distantPast),
            colorName: color?.name,
            versionCount: versionCount)
    }

    /// A kept version whose note is gone: its place and quoted words, its text as the body, when
    /// it was written as the date.
    static func entry(for version: KeptVersionSnapshot) -> NotesBrowserEntry {
        let isChapter = version.verse == 0
        return NotesBrowserEntry(
            id: version.uuid,
            kind: .keptVersion(id: version.uuid),
            book: version.book,
            bookOrder: bookOrder(version.book),
            chapter: version.chapter,
            verse: version.verse,
            endVerse: isChapter ? 0 : version.endVerse,
            referenceString: MarkupReferenceText.string(book: version.book, chapter: version.chapter, verse: isChapter ? nil : version.verse, endVerse: version.endVerse),
            translationID: version.translationID,
            color: nil,
            quotedText: version.quotedText,
            body: version.body,
            modifiedAt: version.writtenAt)
    }

    /// As `MarkupStore.search` matches a note: its text, its quoted words or its reference; a
    /// blank query matches everything.
    private static func matches(_ version: KeptVersionSnapshot, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return version.body.localizedStandardContains(trimmed) || version.quotedText.localizedStandardContains(trimmed)
            || MarkupSearch.matchesReference(trimmed, book: version.book, chapter: version.chapter, verse: version.verse, endVerse: version.endVerse)
    }

    static func entry(for highlight: Highlight, colors: [HighlightColor]) -> NotesBrowserEntry {
        let color = highlightColor(for: highlight.colorID, in: colors)
        return NotesBrowserEntry(
            id: highlight.uuid,
            kind: .highlight(id: highlight.uuid),
            book: highlight.book,
            bookOrder: bookOrder(highlight.book),
            chapter: highlight.chapter,
            verse: highlight.verse,
            endVerse: highlight.endVerse,
            referenceString: MarkupReferenceText.string(book: highlight.book, chapter: highlight.chapter, verse: highlight.verse, endVerse: highlight.endVerse),
            translationID: highlight.translationID,
            color: color.map(markupColor),
            quotedText: highlight.quotedText,
            body: "",
            modifiedAt: highlight.modifiedAt,
            colorName: color?.name)
    }

    static func entry(for bookmark: Bookmark) -> NotesBrowserEntry {
        NotesBrowserEntry(
            id: bookmark.uuid,
            kind: .bookmark(id: bookmark.uuid),
            book: bookmark.book,
            bookOrder: bookOrder(bookmark.book),
            chapter: bookmark.chapter,
            verse: bookmark.verse,
            endVerse: bookmark.verse,
            referenceString: MarkupReferenceText.string(book: bookmark.book, chapter: bookmark.chapter, verse: bookmark.verse, endVerse: bookmark.verse),
            translationID: nil,
            color: nil,
            quotedText: bookmark.label ?? "",
            body: "",
            modifiedAt: bookmark.createdAt)
    }

    /// Every conversation for an empty query; otherwise those whose title, questions or replies
    /// contain it. The passage text a first message carries is not searched, so a conversation
    /// is not found by words of the chapter it was about.
    @MainActor
    static func threads(store: MarkupStore, matching query: String) throws -> [ChatThread] {
        let threads = try store.chat.allThreads()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return threads }
        return threads.filter { thread in
            thread.title.localizedCaseInsensitiveContains(needle)
                || thread.orderedMessages.contains { ($0.role == .assistant ? $0.content : $0.displayText ?? $0.content).localizedCaseInsensitiveContains(needle) }
        }
    }

    static func entry(for thread: ChatThread) -> NotesBrowserEntry {
        let item = ChatThreadItem(thread)
        let isSelection = thread.scope == .selection
        return NotesBrowserEntry(
            id: thread.uuid,
            kind: .thread(id: thread.uuid),
            book: thread.book,
            bookOrder: bookOrder(thread.book),
            chapter: thread.chapter,
            verse: isSelection ? thread.verse : 0,
            endVerse: isSelection ? thread.endVerse : 0,
            referenceString: item.referenceString,
            translationID: thread.translationID,
            color: nil,
            quotedText: item.lastLine,
            body: thread.title,
            modifiedAt: thread.updatedAt)
    }

    private static func bookOrder(_ code: String) -> Int {
        BookCatalog.book(code: code)?.order ?? Int.max
    }

    private static func highlightColor(for id: UUID?, in colors: [HighlightColor]) -> HighlightColor? {
        guard let id else { return nil }
        return colors.first { $0.uuid == id }
    }

    private static func markupColor(_ color: HighlightColor) -> MarkupColor {
        MarkupColor(lightHex: color.lightHex, darkHex: color.darkHex)
    }
}
