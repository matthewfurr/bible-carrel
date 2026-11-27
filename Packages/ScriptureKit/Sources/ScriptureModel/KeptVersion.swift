import Foundation
import SwiftData

/// A note's text that lost to another device's edit or delete, kept so nothing is lost. It carries
/// the note's place, so it can be restored as a note when the note itself is gone. Only ever
/// inserted or deleted, never changed.
///
/// CloudKit-ready: every attribute defaulted or optional, nothing unique, no relationship.
@Model
public final class KeptVersion {
    public var uuid: UUID = UUID()
    public var noteID: UUID?
    public var body: String = ""
    public var writtenAt: Date = Date()
    public var deviceKind: String = ""
    public var book: String = ""
    public var chapter: Int = 0
    public var verse: Int = 0
    public var endVerse: Int = 0
    public var translationID: String = ""
    public var quotedText: String = ""
    public var startOffset: Int = 0
    public var endOffset: Int = 0

    public init() {}
}

/// Left by a delete of a note that held text (or was emptied from text): which version was deleted
/// (`NoteVersion.deleted`, each text as its writer's tag and digest), so a device that wrote that
/// text, or one it came from, knows the delete had sight of it. No text.
@Model
public final class DeletionMarker {
    public var noteID: UUID?
    public var version: String = ""
    public var deletedAt: Date = Date()

    public init(noteID: UUID, version: String, deletedAt: Date) {
        self.noteID = noteID
        self.version = version
        self.deletedAt = deletedAt
    }
}

/// A kept version by value, every stored field.
public struct KeptVersionSnapshot: Equatable, Sendable, Identifiable {
    public let uuid: UUID
    public let noteID: UUID?
    public let body: String
    public let writtenAt: Date
    public let deviceKind: String
    public let book: String
    public let chapter: Int
    public let verse: Int
    public let endVerse: Int
    public let translationID: String
    public let quotedText: String
    public let startOffset: Int
    public let endOffset: Int

    public var id: UUID { uuid }

    public init(_ version: KeptVersion) {
        uuid = version.uuid
        noteID = version.noteID
        body = version.body
        writtenAt = version.writtenAt
        deviceKind = version.deviceKind
        book = version.book
        chapter = version.chapter
        verse = version.verse
        endVerse = version.endVerse
        translationID = version.translationID
        quotedText = version.quotedText
        startOffset = version.startOffset
        endOffset = version.endOffset
    }

    func make() -> KeptVersion {
        let version = KeptVersion()
        version.uuid = uuid
        version.noteID = noteID
        version.body = body
        version.writtenAt = writtenAt
        version.deviceKind = deviceKind
        version.book = book
        version.chapter = chapter
        version.verse = verse
        version.endVerse = endVerse
        version.translationID = translationID
        version.quotedText = quotedText
        version.startOffset = startOffset
        version.endOffset = endOffset
        return version
    }
}
