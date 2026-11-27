#if os(iOS)
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
import UIKit
@testable import ScriptureUI

@MainActor @Suite struct PhoneMarkupMenuTests {
    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)
    private let clipboard = PassageLinkClipboard(
        link: PassageLink(reference: Reference(book: BookCatalog.book(code: "MAT")!, chapter: 5, verse: 2)), scheme: "bible")

    @Test func thePanelsLeadTheActionsAfterAskAheadOfCopy() throws {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let model = MarkupModel(store: MarkupStore(container: container), defaults: UserDefaults(suiteName: "PhoneMarkupMenuTests-\(UUID().uuidString)")!)
        let verses = [
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: 1), translationID: "ESV", text: "Blessed are the poor.", breakAfter: false),
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: 2), translationID: "ESV", text: "For theirs is.", breakAfter: false),
        ]
        let layout = BookLayout.build(chapters: [BookChapterInput(location: matthew5, verses: verses)],
                                      opening: BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: nil)), typography: .default)
        model.load(book: "MAT", chapters: 5...5, chapterInView: matthew5, translationID: "ESV")
        model.setLayout(layout)
        let span = try #require(layout.span(for: VerseLocation(book: "MAT", chapter: 5, verse: 2)))
        let range = NSRange(location: span.textRange.location, length: 3)
        let selection = TextSelection(book: "MAT", chapter: 5, verse: 2, endVerse: 2, startOffset: 0, endOffset: 3, quotedText: "For")
        let report = SelectionReport(selection: selection, range: range, highlightIDs: [], primaryHighlightID: nil)

        let menu = PhoneMarkupMenu.make(for: report, model: model, penColorID: nil, share: { _ in }, collapse: {}, traits: .current)
        let names = menu.children.compactMap { ($0 as? UIAction)?.subtitle }
        #expect(names == ["Add Note", "Bookmark Verse 2", "Ask About This Passage", "Compare Translations", "Cross-References", "Copy", "Copy with Reference", "Copy Link",
                          "Share…", "Look Up", "Translate"])
        withExtendedLifetime(container) {}
    }

    @Test func thePhonesCopyLinkWritesPlainTextAndRichText() throws {
        // A pasteboard of its own: a test never replaces what the owner has copied.
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        PhoneMarkupMenu.write(clipboard, to: pasteboard)
        #expect(pasteboard.string == "bible://mat.5.2")
        #expect(pasteboard.data(forPasteboardType: "public.rtf") != nil && pasteboard.data(forPasteboardType: "public.html") != nil)
    }
}
#endif
