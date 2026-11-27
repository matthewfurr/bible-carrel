import Foundation

/// A note's stored fields, kept by value so a deleted note can be put back exactly (same uuid,
/// same dates) when the delete is undone.
public struct NoteSnapshot: Equatable, Sendable {
    public let uuid: UUID
    public let body: String
    public let createdAt: Date
    public let modifiedAt: Date
    public let scope: NoteScope
    public let book: String
    public let chapter: Int
    public let verse: Int
    public let endVerse: Int
    public let translationID: String
    public let quotedText: String
    public let versionMark: String?
    public let versionAncestry: String?
    public let deviceKind: String?

    public init(_ note: Note) {
        uuid = note.uuid
        body = note.body
        createdAt = note.createdAt
        modifiedAt = note.modifiedAt
        scope = note.scope
        book = note.book
        chapter = note.chapter
        verse = note.verse
        endVerse = note.endVerse
        translationID = note.translationID
        quotedText = note.quotedText
        versionMark = note.versionMark
        versionAncestry = note.versionAncestry
        deviceKind = note.deviceKind
    }

    func make() -> Note {
        let note = Note(body: body, scope: scope, book: book, chapter: chapter, verse: verse, endVerse: endVerse, translationID: translationID, quotedText: quotedText)
        note.uuid = uuid
        note.createdAt = createdAt
        note.modifiedAt = modifiedAt
        note.versionMark = versionMark
        note.versionAncestry = versionAncestry
        note.deviceKind = deviceKind
        return note
    }
}

/// A highlight's stored fields and its note, by value.
public struct HighlightSnapshot: Equatable, Sendable {
    public let uuid: UUID
    public let book: String
    public let chapter: Int
    public let verse: Int
    public let endVerse: Int
    public let startOffset: Int
    public let endOffset: Int
    public let translationID: String
    public let colorID: UUID?
    public let quotedText: String
    public let createdAt: Date
    public let modifiedAt: Date
    public let note: NoteSnapshot?

    public init(_ highlight: Highlight) {
        uuid = highlight.uuid
        book = highlight.book
        chapter = highlight.chapter
        verse = highlight.verse
        endVerse = highlight.endVerse
        startOffset = highlight.startOffset
        endOffset = highlight.endOffset
        translationID = highlight.translationID
        colorID = highlight.colorID
        quotedText = highlight.quotedText
        createdAt = highlight.createdAt
        modifiedAt = highlight.modifiedAt
        note = highlight.note.map(NoteSnapshot.init)
    }

    func make() -> Highlight {
        let highlight = Highlight(
            book: book, chapter: chapter, verse: verse, endVerse: endVerse,
            startOffset: startOffset, endOffset: endOffset,
            translationID: translationID, colorID: colorID, quotedText: quotedText)
        highlight.uuid = uuid
        highlight.createdAt = createdAt
        highlight.modifiedAt = modifiedAt
        return highlight
    }
}

public struct BookmarkSnapshot: Equatable, Sendable {
    public let uuid: UUID
    public let book: String
    public let chapter: Int
    public let verse: Int
    public let createdAt: Date
    public let label: String?

    public init(_ bookmark: Bookmark) {
        uuid = bookmark.uuid
        book = bookmark.book
        chapter = bookmark.chapter
        verse = bookmark.verse
        createdAt = bookmark.createdAt
        label = bookmark.label
    }
}

/// Something the reader deleted, kept so the delete can be undone and redone.
public enum MarkupDeletion: Equatable, Sendable {
    /// A note, and its anchor as it was before the delete (the anchor goes too when it has no
    /// color). A chapter note has no anchor.
    case note(NoteSnapshot, anchor: HighlightSnapshot?)
    /// A highlight with its note, if it had one.
    case highlight(HighlightSnapshot)
    case bookmark(BookmarkSnapshot)
    /// A conversation with its turns.
    case thread(ThreadSnapshot)
    /// A kept version the reader discarded.
    case keptVersion(KeptVersionSnapshot)

    /// The Edit menu's "Undo …" name.
    public var actionName: String {
        switch self {
        case .note: "Delete Note"
        case .highlight: "Delete Highlight"
        case .bookmark: "Delete Bookmark"
        case .thread: "Delete Conversation"
        case .keptVersion: "Discard Version"
        }
    }
}
