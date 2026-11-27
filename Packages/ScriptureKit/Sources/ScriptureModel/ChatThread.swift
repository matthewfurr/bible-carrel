import Foundation
import ScriptureData
import SwiftData

/// What a conversation is about: a selection, a chapter, a whole book (which follows the
/// reader from chapter to chapter), or nothing in particular ("No context", filed under the
/// chapter it was opened from so history finds it).
public enum ThreadScope: String, Codable, Sendable {
    case selection
    case chapter
    case book
    case general
}

/// One conversation with the assistant. Location fields are flat so `#Predicate` can filter by
/// chapter and CloudKit sees plain fields. A book or general thread keeps the chapter it was
/// opened from (a book thread is found from every chapter of its book); a selection thread
/// carries its verse range and offsets like a highlight does.
@Model
public final class ChatThread {
    public var uuid: UUID = UUID()
    public var scopeRaw: String = ThreadScope.chapter.rawValue
    public var book: String = ""
    public var chapter: Int = 0
    public var verse: Int = 0
    public var endVerse: Int = 0
    public var startOffset: Int = 0
    public var endOffset: Int = 0
    public var translationID: String = ""
    public var quotedText: String = ""
    public var title: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
    public var messages: [ChatMessage]? = []

    public init(scope: ThreadScope, book: String, chapter: Int, verse: Int, endVerse: Int, startOffset: Int, endOffset: Int, translationID: String, quotedText: String, title: String) {
        self.scopeRaw = scope.rawValue
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.translationID = translationID
        self.quotedText = quotedText
        self.title = title
    }

    public var scope: ThreadScope {
        get { ThreadScope(rawValue: scopeRaw) ?? .chapter }
        set { scopeRaw = newValue.rawValue }
    }

    public var chapterLocation: ChapterLocation { ChapterLocation(book: book, chapter: chapter) }

    /// Oldest first.
    public var orderedMessages: [ChatMessage] {
        (messages ?? []).sorted { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) }
    }
}
