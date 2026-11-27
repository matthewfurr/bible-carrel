import Foundation
import ScriptureData
import ScriptureModel

/// Feeds `MarkdownExport` from the stores: every entry the Notes browser shows, the bookmarked
/// verses' text in the current translation, and each conversation's turns.
@MainActor
public final class NotesExporter {
    private let markup: MarkupStore
    private let bible: BibleStore

    public init(markup: MarkupStore, bible: BibleStore) {
        self.markup = markup
        self.bible = bible
    }

    /// Everything, as the Notes browser builds it before filter, search and sort.
    public func allEntries() throws -> [NotesBrowserEntry] {
        try NotesBrowserLoader.entries(store: markup, query: "")
    }

    public func output(entries: [NotesBrowserEntry], options: MarkdownExport.Options, currentTranslationID: String, now: Date = Date()) throws -> MarkdownExport.Output {
        var chapters: [String: [Verse]] = [:]
        var failure: Error?
        let context = MarkdownExport.Context(
            verseText: { [bible] location, translationID in
                let key = "\(translationID) \(location.book) \(location.chapter)"
                if chapters[key] == nil {
                    do {
                        chapters[key] = try bible.chapter((book: location.book, chapter: location.chapter), translationID: translationID)
                    } catch {
                        failure = failure ?? error
                        chapters[key] = []
                    }
                }
                let text = chapters[key]?.first { verse in
                    verse.id.verse <= location.verse && location.verse <= (verse.endVerse ?? verse.id.verse)
                }?.text
                return text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? text : nil
            },
            thread: { [markup] id in
                do {
                    return try markup.chat.thread(id: id).map(ThreadSnapshot.init)
                } catch {
                    failure = failure ?? error
                    return nil
                }
            },
            currentTranslationID: currentTranslationID,
            exportedAt: now)
        let output = MarkdownExport.render(entries: entries, options: options, context: context)
        if let failure { throw failure }
        return output
    }
}
