import Foundation
import ScriptureData
import SwiftData

/// Conversations and their turns on the markup container. Every mutation saves.
@MainActor
public final class ChatStore {
    public let container: ModelContainer
    public let context: ModelContext

    public init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    // MARK: - Queries

    /// The chapter's selection and chapter threads plus the book's threads, newest first; one per
    /// uuid (`Twins`), the first fetched, as `allThreads()`.
    public func threads(in chapter: ChapterLocation) throws -> [ChatThread] {
        let book = chapter.book, number = chapter.chapter, bookScope = ThreadScope.book.rawValue
        let descriptor = FetchDescriptor<ChatThread>(predicate: #Predicate {
            $0.book == book && ($0.chapter == number || $0.scopeRaw == bookScope)
        })
        return Twins.firsts(try context.fetch(descriptor), id: \.uuid).sorted { $0.updatedAt > $1.updatedAt }
    }

    public func allThreads() throws -> [ChatThread] {
        Twins.firsts(try context.fetch(FetchDescriptor<ChatThread>()), id: \.uuid)
    }

    public func thread(id: UUID) throws -> ChatThread? {
        var descriptor = FetchDescriptor<ChatThread>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Mutations

    @discardableResult
    public func createThread(scope: ThreadScope, book: String, chapter: Int, verse: Int, endVerse: Int, startOffset: Int, endOffset: Int, translationID: String, quotedText: String, title: String) throws -> ChatThread {
        let thread = ChatThread(scope: scope, book: book, chapter: chapter, verse: verse, endVerse: endVerse, startOffset: startOffset, endOffset: endOffset, translationID: translationID, quotedText: quotedText, title: title)
        context.insert(thread)
        try context.save()
        return thread
    }

    /// Adds a turn and bumps the thread's `updatedAt`.
    @discardableResult
    public func append(to thread: ChatThread, role: ChatRole, content: String, providerID: String, modelName: String, attachedReference: String?) throws -> ChatMessage {
        try append(to: thread, role: role, content: content, displayText: nil, providerID: providerID, modelName: modelName, attachedReference: attachedReference)
    }

    /// `displayText` is what the panel shows for a reader turn whose `content` carries more.
    @discardableResult
    public func append(to thread: ChatThread, role: ChatRole, content: String, displayText: String?, providerID: String, modelName: String, attachedReference: String?) throws -> ChatMessage {
        try append(to: thread, role: role, content: content, displayText: displayText, providerID: providerID, modelName: modelName,
                   providerHost: nil, attachedReference: attachedReference, finishReason: nil, uuid: nil)
    }

    /// `providerHost` is the compatible endpoint's host, `finishReason` why a reply ended early,
    /// and `uuid`, when given, the record's identity (the panel's row for a reply keeps its id).
    @discardableResult
    public func append(to thread: ChatThread, role: ChatRole, content: String, displayText: String?, providerID: String, modelName: String,
                       providerHost: String?, attachedReference: String?, finishReason: String?, uuid: UUID?) throws -> ChatMessage {
        let message = ChatMessage(role: role, content: content, providerID: providerID, modelName: modelName, attachedReference: attachedReference)
        if let uuid { message.uuid = uuid }
        message.displayText = displayText
        message.providerHost = providerHost
        message.finishReason = finishReason
        context.insert(message)
        message.thread = thread
        thread.updatedAt = Date()
        try context.save()
        return message
    }

    /// The note Add as Note made of the turn; nil forgets it.
    public func setSavedNote(_ noteID: UUID?, on message: ChatMessage) throws {
        message.savedNoteID = noteID
        try context.save()
    }

    public func updateContent(of message: ChatMessage, _ content: String) throws {
        message.content = content
        message.thread?.updatedAt = Date()
        try context.save()
    }

    public func delete(_ message: ChatMessage) throws {
        message.thread?.messages?.removeAll { $0.uuid == message.uuid }
        context.delete(message)
        try context.save()
    }

    public func deleteThread(_ thread: ChatThread) throws {
        context.delete(thread)
        try context.save()
    }

    /// Puts a deleted thread back with its messages, same uuids and dates; a no-op when it exists.
    public func restore(_ snapshot: ThreadSnapshot) throws {
        guard try thread(id: snapshot.uuid) == nil else { return }
        let thread = snapshot.make()
        context.insert(thread)
        for messageSnapshot in snapshot.messages {
            let message = messageSnapshot.make()
            context.insert(message)
            message.thread = thread
        }
        try context.save()
    }
}

/// A turn by value.
public struct MessageSnapshot: Equatable, Sendable {
    public let uuid: UUID
    public let role: ChatRole
    public let content: String
    public let createdAt: Date
    public let providerID: String
    public let modelName: String
    public let attachedReference: String?
    public let displayText: String?
    public let providerHost: String?
    public let finishReason: String?
    public let savedNoteID: UUID?

    public init(_ message: ChatMessage) {
        uuid = message.uuid
        role = message.role
        content = message.content
        createdAt = message.createdAt
        providerID = message.providerID
        modelName = message.modelName
        attachedReference = message.attachedReference
        displayText = message.displayText
        providerHost = message.providerHost
        finishReason = message.finishReason
        savedNoteID = message.savedNoteID
    }

    func make() -> ChatMessage {
        let message = ChatMessage(role: role, content: content, providerID: providerID, modelName: modelName, attachedReference: attachedReference)
        message.uuid = uuid
        message.createdAt = createdAt
        message.displayText = displayText
        message.providerHost = providerHost
        message.finishReason = finishReason
        message.savedNoteID = savedNoteID
        return message
    }
}

/// A thread and its turns by value, so a deleted conversation can be put back exactly.
public struct ThreadSnapshot: Equatable, Sendable {
    public let uuid: UUID
    public let scope: ThreadScope
    public let book: String
    public let chapter: Int
    public let verse: Int
    public let endVerse: Int
    public let startOffset: Int
    public let endOffset: Int
    public let translationID: String
    public let quotedText: String
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messages: [MessageSnapshot]

    public init(_ thread: ChatThread) {
        uuid = thread.uuid
        scope = thread.scope
        book = thread.book
        chapter = thread.chapter
        verse = thread.verse
        endVerse = thread.endVerse
        startOffset = thread.startOffset
        endOffset = thread.endOffset
        translationID = thread.translationID
        quotedText = thread.quotedText
        title = thread.title
        createdAt = thread.createdAt
        updatedAt = thread.updatedAt
        messages = thread.orderedMessages.map(MessageSnapshot.init)
    }

    func make() -> ChatThread {
        let thread = ChatThread(scope: scope, book: book, chapter: chapter, verse: verse, endVerse: endVerse, startOffset: startOffset, endOffset: endOffset, translationID: translationID, quotedText: quotedText, title: title)
        thread.uuid = uuid
        thread.createdAt = createdAt
        thread.updatedAt = updatedAt
        return thread
    }
}
