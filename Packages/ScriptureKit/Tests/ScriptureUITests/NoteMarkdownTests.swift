import Foundation
import SwiftUI
import ScriptureData
import Testing
#if os(macOS)
import AppKit
import class SwiftUI.NSHostingView
#endif
@testable import ScriptureUI

@Suite struct NoteMarkdownTests {
    @Test func inlineMarkdownRenders() {
        let attributed = NoteMarkdown.attributed("a **bold** and *italic* word")
        #expect(String(attributed.characters) == "a bold and italic word")
        #expect(attributed.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        #expect(attributed.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
    }

    @Test func lineBreaksArePreserved() {
        #expect(String(NoteMarkdown.attributed("one\ntwo").characters) == "one\ntwo")
    }

    @Test func listsBecomeBulletedLines() {
        let attributed = NoteMarkdown.attributed("Points:\n- first\n- second\n\n1. one\n2. two")
        #expect(String(attributed.characters) == "Points:\n• first\n• second\n1. one\n2. two")
    }

    @Test func headingsAreLargerAndBold() {
        let attributed = NoteMarkdown.attributed("# Title\nbody")
        #expect(String(attributed.characters) == "Title\nbody")
        #expect(attributed.runs.first!.font != nil)
        #expect(attributed.runs.last!.font == nil)
    }

    @Test func linksKeepTheirURL() {
        let attributed = NoteMarkdown.attributed("see [ESV](https://esv.org) now")
        #expect(String(attributed.characters) == "see ESV now")
        #expect(attributed.runs.contains { $0.link?.absoluteString == "https://esv.org" })
    }

    @Test func blankLinesSeparateBlocks() {
        let blocks = NoteMarkdown.blocks("First paragraph.\n\nSecond paragraph.")
        #expect(blocks.map { String($0.characters) } == ["First paragraph.", "Second paragraph."])
        let withList = NoteMarkdown.blocks("Points:\n- a\n- b\n\n# Title\nbody")
        #expect(withList.map { String($0.characters) } == ["Points:", "• a\n• b", "Title", "body"])
        #expect(NoteMarkdown.blocks("one\ntwo").map { String($0.characters) } == ["one\ntwo"])
    }

    @Test func documentJoinsBlocksWithABlankLine() {
        let document = NoteMarkdown.document("First.\n\nSecond **bold**.")
        #expect(String(document.characters) == "First.\n\nSecond bold.")
        #expect(document.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    // MARK: - A preview across blocks (milestone 11, project 5)

    @Test func aHeadingKeepsItsSizeOnlyOutsideAPreview() {
        let sized = NoteMarkdown.blocks("# Heading\n\nText")[0]
        #expect(sized.runs.first?.font == .system(.title3, weight: .semibold))
        let plain = NoteMarkdown.blocks("# Heading\n\nText", headingsAtTextSize: true)[0]
        #expect(plain.runs.allSatisfy { $0.font == nil })
        #expect(String(plain.characters) == "Heading")
        #expect(String(sized.characters) == "Heading")
    }

    @Test func thePreviewRunsOnAcrossBlocks() {
        let text = NoteBodyText.preview("A short paragraph.\n\n- one\n- two\n- three", book: nil, chapterCount: nil)
        #expect(String(text.characters) == "A short paragraph.\n• one\n• two\n• three")
        let ezra = NoteBodyText.preview("# Discouragement\n\nOpposition as discouragement.\n\n- verse 4\n- verse 5", book: nil, chapterCount: nil)
        #expect(String(ezra.characters) == "Discouragement\nOpposition as discouragement.\n• verse 4\n• verse 5")
        #expect(ezra.runs.allSatisfy { $0.font == nil })
    }

    @Test func aHeadingOnlyNotePreviewsAtRowSizeWithItsLink() throws {
        let matthew = try #require(BookCatalog.book(code: "MAT"))
        let text = NoteBodyText.preview("# Blessed (Luke 6:20)", book: matthew, chapterCount: { _ in 24 })
        #expect(text.runs.allSatisfy { $0.font == nil })
        let links = text.runs.compactMap { run in run.link.map { (String(text[run.range].characters), $0) } }
        #expect(links.count == 1)
        #expect(links.first?.0 == "Luke 6:20")
        #expect(links.first?.1.scheme == ReferenceLinker.scheme)
        #expect(links.first.flatMap { ReferenceLinker.reference(from: $0.1) }?.displayString == "Luke 6:20")
    }

    @Test func thePhonesNoteLineHasNoHeadingFontRule() {
        let first = NoteMarkdown.blocks("# Prayer\n\nFor the city", headingsAtTextSize: true).first
        #expect(first.map { String($0.characters) } == "Prayer")
        #expect(first?.runs.allSatisfy { $0.font == nil } == true)
        #expect(SearchMarkHit.firstLine(of: "# Prayer") == "Prayer")
    }

    #if os(iOS)
    @MainActor @Test func thePhonesNoteLineHasNoHeadingFont() {
        let entry = NotesBrowserEntry(id: UUID(), kind: .note(noteID: UUID(), highlightID: nil), book: "MAT", bookOrder: 39, chapter: 5, verse: 3,
                                      endVerse: 3, referenceString: "Matthew 5:3", translationID: "ESV", color: nil, quotedText: "",
                                      body: "# Prayer\n\nFor the city", modifiedAt: Date(timeIntervalSince1970: 0))
        let line = PhoneNotesScreen.noteBody(for: entry)
        #expect(line.map { String($0.characters) } == "Prayer")
        #expect(line?.runs.allSatisfy { $0.font == nil } == true)
        #expect(SearchMarkHit.firstLine(of: "# Prayer") == "Prayer")
    }
    #endif
}

#if os(macOS)
@MainActor @Suite(.serialized) struct NotePreviewHeightTests {
    private func height<V: SwiftUI.View>(_ view: V) -> CGFloat {
        let host = NSHostingView(rootView: view.frame(width: 400))
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 400, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    @Test func theMacsPreviewStopsAtThreeLines() {
        let body = "A short paragraph.\n\n- one\n- two\n- three\n- four\n- five"
        let three = height(Text("a\nb\nc").font(.callout))
        #expect(abs(height(NoteBodyText(body, book: nil, font: .callout, previewLines: 3)) - three) <= 1)
        #expect(height(NoteBodyText("One.\n\n- two", book: nil, font: .callout, previewLines: 3)) < three)
    }
}
#endif
