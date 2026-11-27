import Foundation
import ScriptureData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct ChatStoreTests {
    private func make() throws -> ChatStore {
        ChatStore(container: try MarkupContainer.make(inMemory: true))
    }

    @Test func threadsInAChapterIncludeTheBooksThreadsNewestFirst() throws {
        let store = try make()
        let chapter = try store.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Key themes: Matthew 5")
        let book = try store.createThread(scope: .book, book: "MAT", chapter: 0, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Matthew")
        _ = try store.createThread(scope: .chapter, book: "MAT", chapter: 6, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Outline: Matthew 6")
        let selection = try store.createThread(scope: .selection, book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", quotedText: "Blessed", title: "Matthew 5:3")
        chapter.updatedAt = Date(timeIntervalSince1970: 100)
        book.updatedAt = Date(timeIntervalSince1970: 300)
        selection.updatedAt = Date(timeIntervalSince1970: 200)
        try store.context.save()
        #expect(try store.threads(in: ChapterLocation(book: "MAT", chapter: 5)).map(\.title) == ["Matthew", "Matthew 5:3", "Key themes: Matthew 5"])
        #expect(try store.allThreads().count == 4)
    }

    @Test func appendingKeepsOrderAndBumpsUpdatedAt() throws {
        let store = try make()
        let thread = try store.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "t")
        thread.updatedAt = .distantPast
        let q = try store.append(to: thread, role: .user, content: "Who?", providerID: "", modelName: "", attachedReference: nil)
        let a = try store.append(to: thread, role: .assistant, content: "Matt", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
        try store.updateContent(of: a, "Matthew.")
        #expect(thread.orderedMessages.map(\.content) == ["Who?", "Matthew."])
        #expect(thread.orderedMessages.map(\.role) == [.user, .assistant])
        #expect(thread.updatedAt > Date(timeIntervalSinceNow: -5))
        try store.delete(q)
        #expect(thread.orderedMessages.map(\.uuid) == [a.uuid])
    }

    /// A template run keeps the filled prompt (what the model saw) and shows the template's title;
    /// a general thread is filed under the chapter it was opened from.
    @Test func displayTextAndGeneralScopeSurviveDeleteAndRestore() throws {
        let store = try make()
        let thread = try store.createThread(scope: .general, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Why pray?")
        try store.append(to: thread, role: .user, content: "Here is Matthew 5 (ESV): …", displayText: "Overall summary", providerID: "", modelName: "", attachedReference: nil)
        let plain = try store.append(to: thread, role: .assistant, content: "A reply", providerID: "anthropic", modelName: "m", attachedReference: nil)
        #expect(plain.displayText == nil)
        #expect(try store.threads(in: ChapterLocation(book: "MAT", chapter: 5)).map(\.scope) == [.general])
        let snapshot = ThreadSnapshot(thread)
        try store.deleteThread(thread)
        try store.restore(snapshot)
        let restored = try #require(try store.thread(id: snapshot.uuid))
        #expect(restored.scope == .general && restored.orderedMessages.map(\.displayText) == ["Overall summary", nil])
    }

    @Test func aDeletedThreadIsRestoredWithItsMessages() throws {
        let store = try make()
        let thread = try store.createThread(scope: .selection, book: "MAT", chapter: 5, verse: 3, endVerse: 4, startOffset: 2, endOffset: 9, translationID: "KJV", quotedText: "poor", title: "Matthew 5:3-4")
        try store.append(to: thread, role: .user, content: "q", providerID: "", modelName: "", attachedReference: "Matthew 6")
        let snapshot = ThreadSnapshot(thread)
        try store.deleteThread(thread)
        #expect(try store.allThreads().isEmpty)
        try store.restore(snapshot)
        let back = try store.thread(id: snapshot.uuid)
        #expect(back?.title == "Matthew 5:3-4" && back?.endOffset == 9 && back?.translationID == "KJV")
        #expect(back?.orderedMessages.map(\.attachedReference) == ["Matthew 6"])
        try store.restore(snapshot)
        #expect(try store.allThreads().count == 1)
    }

    @Test func appendKeepsAGivenUUIDAndTheNewFields() throws {
        let store = try make()
        let thread = try store.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "T")
        let id = UUID()
        let message = try store.append(to: thread, role: .assistant, content: "A", displayText: nil, providerID: "openAICompatible", modelName: "m", providerHost: "h", attachedReference: nil, finishReason: "cutShort", uuid: id)
        #expect(message.uuid == id && message.providerHost == "h" && message.finishReason == "cutShort")
        try store.setSavedNote(id, on: message)
        let snapshot = ThreadSnapshot(thread)
        try store.deleteThread(thread)
        try store.restore(snapshot)
        #expect(try store.thread(id: thread.uuid)!.orderedMessages[0].savedNoteID == id)
    }
}
