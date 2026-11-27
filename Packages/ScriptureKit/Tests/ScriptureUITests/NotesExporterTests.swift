import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite struct NotesExporterTests {
    @Test func theExportQuotesABookmarkInTheCurrentTranslationAndCarriesANote() throws {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let markup = MarkupStore(container: container)
        let bible = try FixtureStore.make()
        try markup.toggleBookmark(at: VerseLocation(book: "MAT", chapter: 1, verse: 1))
        let anchor = try markup.addHighlight(book: "MAT", chapter: 1, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "WEB", colorID: try markup.colors()[0].uuid, quotedText: "Chapter one verse three.")
        _ = try markup.addNote(to: anchor, body: "A note on the third verse.")
        let exporter = NotesExporter(markup: markup, bible: bible)

        let text = try exporter.output(entries: try exporter.allEntries(), options: .init(), currentTranslationID: "WEB").files[0].text

        #expect(text.contains("> “Chapter one verse one.” — Matthew 1:1 (WEB)\n\n_Bookmark · "))
        #expect(text.contains("> “Chapter one verse three.” — Matthew 1:3 (WEB)\n\nA note on the third verse.\n\n_Note · Yellow · "))
        #expect(text.contains("· 2 items_"))
    }
}
