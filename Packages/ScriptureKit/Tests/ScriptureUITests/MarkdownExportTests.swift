import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite struct MarkdownExportTests {
    private let day = Date(timeIntervalSince1970: 1_793_574_000)   // 1 November 2026
    private func note(_ body: String, verse: Int = 3, color: String? = "Yellow") -> NotesBrowserEntry {
        NotesBrowserEntry(id: UUID(), kind: .note(noteID: UUID(), highlightID: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: verse, endVerse: verse,
                          referenceString: "Matthew 5:\(verse)", translationID: "ESV", color: color.map { _ in MarkupColor(lightHex: "#F8E18A", darkHex: "#554704") },
                          quotedText: "Blessed are the poor in spirit", body: body, modifiedAt: day, colorName: color)
    }
    private var context: MarkdownExport.Context {
        .init(verseText: { location, _ in location.verse == 7 ? "Blessed are the merciful." : nil }, thread: { _ in nil }, currentTranslationID: "ESV", exportedAt: day)
    }

    @Test func aNoteRendersQuoteCitationBodyAndMeta() {
        let output = MarkdownExport.render(entries: [note("The body.")], options: .init(), context: context)
        #expect(output.files.count == 1)
        #expect(output.files[0].text.contains("## Matthew\n\n### Matthew 5\n\n> “Blessed are the poor in spirit” — Matthew 5:3 (ESV)\n\nThe body.\n\n_Note · Yellow · "))
        #expect(output.name.hasSuffix(".md"))
    }

    @Test func entriesGroupByBookThenChapterInCanonOrder() {
        let psalm = NotesBrowserEntry(id: UUID(), kind: .bookmark(id: UUID()), book: "PSA", bookOrder: 19, chapter: 23, verse: 1, endVerse: 1, referenceString: "Psalm 23:1", translationID: nil, color: nil, quotedText: "", body: "", modifiedAt: day)
        let text = MarkdownExport.render(entries: [note("Later"), psalm], options: .init(), context: context).files[0].text
        #expect(text.range(of: "## Psalms")!.lowerBound < text.range(of: "## Matthew")!.lowerBound)
    }

    @Test func aBookmarkQuotesTheVerseAndSaysWhenItCannot() {
        func bookmark(_ verse: Int) -> NotesBrowserEntry { NotesBrowserEntry(id: UUID(), kind: .bookmark(id: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: verse, endVerse: verse, referenceString: "Matthew 5:\(verse)", translationID: nil, color: nil, quotedText: "", body: "", modifiedAt: day) }
        let text = MarkdownExport.render(entries: [bookmark(7), bookmark(8)], options: .init(), context: context).files[0].text
        #expect(text.contains("> “Blessed are the merciful.” — Matthew 5:7 (ESV)\n\n_Bookmark · "))
        #expect(text.contains("> Matthew 5:8 (text not available in ESV)"))
    }

    @Test func conversationsFollowTheOptionAndTheCount() {
        let thread = NotesBrowserEntry(id: UUID(), kind: .thread(id: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: 0, endVerse: 0, referenceString: "Matthew 5", translationID: "ESV", color: nil, quotedText: "", body: "Overall summary: Matthew 5", modifiedAt: day)
        let with = MarkdownExport.render(entries: [note("A"), thread], options: .init(includesConversations: true), context: context).files[0].text
        let without = MarkdownExport.render(entries: [note("A"), thread], options: .init(includesConversations: false), context: context).files[0].text
        #expect(with.contains("#### Overall summary: Matthew 5") && with.contains("· 2 items_"))
        #expect(!without.contains("####") && without.contains("· 1 item_"))
    }

    /// The whole single-file document, character for character: chapter-level items (verse 0) lead their chapter.
    @Test func theWholeDocumentReadsExactly() throws {
        let store = MarkupStore(container: try MarkupContainer.make(inMemory: true))
        let chat = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Overall summary: Matthew 5")
        try store.chat.append(to: chat, role: .user, content: "Here is Matthew 5 (ESV): …", displayText: "Overall summary", providerID: "", modelName: "", attachedReference: nil)
        try store.chat.append(to: chat, role: .assistant, content: "The reply, as written.", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
        let snapshot = ThreadSnapshot(chat)
        let thread = NotesBrowserEntry(id: chat.uuid, kind: .thread(id: chat.uuid), book: "MAT", bookOrder: 40, chapter: 5, verse: 0, endVerse: 0, referenceString: "Matthew 5", translationID: "ESV", color: nil, quotedText: "", body: "Overall summary: Matthew 5", modifiedAt: day.addingTimeInterval(1))
        let chapterNote = NotesBrowserEntry(id: UUID(), kind: .note(noteID: UUID(), highlightID: nil), book: "MAT", bookOrder: 40, chapter: 5, verse: 0, endVerse: 0, referenceString: "Matthew 5", translationID: "ESV", color: nil, quotedText: "", body: "The body.\n", modifiedAt: day)
        let highlight = NotesBrowserEntry(id: UUID(), kind: .highlight(id: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: 9, endVerse: 9, referenceString: "Matthew 5:9", translationID: "ESV", color: nil, quotedText: "Blessed are the peacemakers", body: "", modifiedAt: day)
        let bookmark = NotesBrowserEntry(id: UUID(), kind: .bookmark(id: UUID()), book: "MAT", bookOrder: 40, chapter: 5, verse: 7, endVerse: 7, referenceString: "Matthew 5:7", translationID: nil, color: nil, quotedText: "", body: "", modifiedAt: day)
        var context = context
        context.thread = { $0 == chat.uuid ? snapshot : nil }
        let date = day.formatted(Date.FormatStyle(date: .long, time: .omitted))

        let output = MarkdownExport.render(entries: [highlight, thread, note("The note body, exactly as written."), bookmark, chapterNote], options: .init(), context: context)

        #expect(output.files[0].text == """
            # Bible Carrel: Notes

            _Exported \(date) · 5 items_

            ## Matthew

            ### Matthew 5

            **Chapter note**

            The body.

            _Note · \(date)_

            #### Overall summary: Matthew 5

            **You:** Overall summary

            **Assistant (Claude · claude-opus-5-5):** The reply, as written.

            _Conversation · \(date)_

            > “Blessed are the poor in spirit” — Matthew 5:3 (ESV)

            The note body, exactly as written.

            _Note · Yellow · \(date)_

            > “Blessed are the merciful.” — Matthew 5:7 (ESV)

            _Bookmark · \(date)_

            > “Blessed are the peacemakers” — Matthew 5:9 (ESV)

            _Highlight · \(date)_

            """)
        #expect(output.name == output.files[0].relativePath && output.name.hasPrefix("Bible Carrel Notes 20"))
    }

    /// A reply that opens with a Markdown block keeps it: the label ends its own line, then a blank line.
    @Test func aReplyThatOpensWithAHeadingKeepsItsStructure() throws {
        let store = MarkupStore(container: try MarkupContainer.make(inMemory: true))
        let chat = try store.chat.createThread(scope: .chapter, book: "MAT", chapter: 5, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0, translationID: "ESV", quotedText: "", title: "Overall summary: Matthew 5")
        try store.chat.append(to: chat, role: .user, content: "What is the shape of it?", providerID: "", modelName: "", attachedReference: nil)
        try store.chat.append(to: chat, role: .assistant, content: "## The Beatitudes\n\nNine blessings.", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
        try store.chat.append(to: chat, role: .assistant, content: "A plain reply.", providerID: "anthropic", modelName: "claude-opus-5-5", attachedReference: nil)
        // Replies that ended early say why, in the panel's footer words.
        for (content, reason) in [("Half a reply", "stopped"), ("Long and", "cutShort"), ("Partly", "declined"), ("Dropped", "failed"), ("Odd", "unknown")] {
            try store.chat.append(to: chat, role: .assistant, content: content, displayText: nil, providerID: "anthropic", modelName: "claude-opus-5-5",
                                  providerHost: nil, attachedReference: nil, finishReason: reason, uuid: nil)
        }
        try store.chat.append(to: chat, role: .assistant, content: "No label", displayText: nil, providerID: "", modelName: "",
                              providerHost: nil, attachedReference: nil, finishReason: "stopped", uuid: nil)
        let snapshot = ThreadSnapshot(chat)
        let thread = NotesBrowserEntry(id: chat.uuid, kind: .thread(id: chat.uuid), book: "MAT", bookOrder: 40, chapter: 5, verse: 0, endVerse: 0, referenceString: "Matthew 5", translationID: "ESV", color: nil, quotedText: "", body: "Overall summary: Matthew 5", modifiedAt: day)
        var context = context
        context.thread = { $0 == chat.uuid ? snapshot : nil }

        let text = MarkdownExport.render(entries: [thread], options: .init(), context: context).files[0].text

        #expect(text.contains("**Assistant (Claude · claude-opus-5-5):**\n\n## The Beatitudes\n\nNine blessings."))
        #expect(text.contains("**Assistant (Claude · claude-opus-5-5):** A plain reply."))
        #expect(text.contains("**You:** What is the shape of it?"))
        #expect(text.contains("**Assistant (Claude · claude-opus-5-5, Stopped):** Half a reply"))
        #expect(text.contains("**Assistant (Claude · claude-opus-5-5, Cut short):** Long and"))
        #expect(text.contains("**Assistant (Claude · claude-opus-5-5, Declined partway):** Partly"))
        #expect(text.contains("**Assistant (Claude · claude-opus-5-5, Ended early):** Dropped"))
        #expect(text.contains("**Assistant (Claude · claude-opus-5-5):** Odd"))
        #expect(text.contains("**Assistant (Stopped):** No label"))
    }

    @Test func folderLayoutWritesOneFilePerBookPlusAReadme() {
        let psalm = NotesBrowserEntry(id: UUID(), kind: .highlight(id: UUID()), book: "PSA", bookOrder: 19, chapter: 23, verse: 1, endVerse: 1, referenceString: "Psalm 23:1", translationID: "ESV", color: nil, quotedText: "The Lord", body: "", modifiedAt: day)
        let output = MarkdownExport.render(entries: [note("A"), psalm], options: .init(layout: .folderPerBook), context: context)
        #expect(output.files.map(\.relativePath) == ["README.md", "Psalms.md", "Matthew.md"])
        #expect(output.files[1].text.hasPrefix("# Psalms\n"))
        #expect(!output.name.hasSuffix(".md"))
    }

    /// A kept version whose note is gone lists only under the Notes Browser's Kept versions: the
    /// Markdown skips one it is given, and the loader the palette and the export read gives none.
    @Test func textsWithNoNoteStayOutOfTheMarkdownAndThePalette() throws {
        let id = UUID()
        let orphan = NotesBrowserEntry(id: id, kind: .keptVersion(id: id), book: "MAT", bookOrder: 40, chapter: 5, verse: 3, endVerse: 3,
                                       referenceString: "Matthew 5:3", translationID: "ESV", color: nil, quotedText: "Blessed are the poor in spirit",
                                       body: "Lost words", modifiedAt: day)
        let text = MarkdownExport.render(entries: [note("A"), orphan], options: .init(), context: context).files[0].text
        #expect(!text.contains("Lost words"))
        #expect(text.contains("· 1 item_"))

        let container = try MarkupContainer.make(inMemory: true)
        let store = MarkupStore(container: container)
        try store.addChapterNote(book: "MAT", chapter: 5, translationID: "ESV", body: "A note", sourceThreadID: nil)
        let version = KeptVersion()
        version.noteID = UUID()
        version.body = "Lost words"
        version.book = "MAT"
        version.chapter = 5
        store.context.insert(version)
        try store.context.save()
        let palette = try NotesBrowserLoader.entries(store: store, query: "")
        #expect(palette.map(\.body) == ["A note"])
        #expect(try NotesBrowserLoader.entries(store: store, query: "Lost").isEmpty)
        let browser = try NotesBrowserLoader.entries(store: store, query: "", includingKeptVersions: true)
        #expect(browser.map(\.body).sorted() == ["A note", "Lost words"])
    }
}
