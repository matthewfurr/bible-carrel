import Foundation
import ScriptureData
import ScriptureLLM
import ScriptureModel

/// A fixed sample for checking the phone in the simulator: the Debug launch argument
/// `-phoneSeed YES` fills an empty store with marks in John 15 and one chapter conversation.
///
/// - 15:4 a highlight with a note
/// - 15:5 a bare highlight and a bookmark
/// - 15:13 a note
/// - a chapter conversation, `What does "abide" mean in the Greek?`, with one reply
public enum PhoneSeed {
    public static let argument = "phoneSeed"
    static let book = "JHN"
    static let chapter = 15
    static let threadTitle = "What does \"abide\" mean in the Greek?"
    static let reply = """
        The word is menō: to remain, stay or dwell. John uses it of the Spirit remaining on Jesus \
        (John 1:32), and his letter asks the same of the reader: whoever says he abides in him \
        ought to walk as he walked (1 John 2:6).
        """

    /// Seeds when the argument is set and the store holds no highlight, note, bookmark or
    /// conversation. Returns whether it seeded.
    @MainActor @discardableResult
    public static func runIfAsked(store: MarkupStore, bible: BibleStore, translationID: String, defaults: UserDefaults = .standard) throws -> Bool {
        guard defaults.bool(forKey: argument), try isEmpty(store) else { return false }
        try seed(store: store, bible: bible, translationID: translationID)
        return true
    }

    @MainActor static func isEmpty(_ store: MarkupStore) throws -> Bool {
        try store.allHighlights().isEmpty && store.allNotes().isEmpty
            && store.allBookmarks().isEmpty && store.chat.allThreads().isEmpty
    }

    @MainActor static func seed(store: MarkupStore, bible: BibleStore, translationID: String) throws {
        // The coordinator seeds the colors too; this is a no-op when it already has.
        try MarkupContainer.seedDefaultColorsIfNeeded(in: store.context)
        let colorID = try store.colors().first?.uuid
        let verses = try bible.chapter((book: book, chapter: chapter), translationID: translationID)
        func highlight(_ verse: Int, colorID: UUID?) throws -> Highlight {
            let text = verses.first { $0.id.verse == verse }?.text ?? ""
            return try store.addHighlight(
                book: book, chapter: chapter, verse: verse, endVerse: verse,
                startOffset: 0, endOffset: text.utf16.count,
                translationID: translationID, colorID: colorID, quotedText: text)
        }
        try store.addNote(to: highlight(4, colorID: colorID),
                          body: "The branch does not strain to bear fruit. It stays joined to the vine.")
        _ = try highlight(5, colorID: colorID)
        try store.toggleBookmark(at: VerseLocation(book: book, chapter: chapter, verse: 5))
        try store.addNote(to: highlight(13, colorID: nil),
                          body: "Love measured by what it gives up.")
        let thread = try store.chat.createThread(
            scope: .chapter, book: book, chapter: chapter, verse: 0, endVerse: 0,
            startOffset: 0, endOffset: 0, translationID: translationID, quotedText: "", title: threadTitle)
        try store.chat.append(to: thread, role: .user, content: threadTitle,
                              providerID: "", modelName: "", attachedReference: nil)
        try store.chat.append(to: thread, role: .assistant, content: reply,
                              providerID: LLMProviderID.appleOnDevice.rawValue, modelName: "", attachedReference: nil)
    }
}
