import Foundation
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

@MainActor @Suite final class PenModelTests {
    /// The scratch defaults suites this test made; each is removed before use and again when the
    /// test ends, so none is left in ~/Library/Preferences.
    private var defaultsNames: [String] = []

    deinit {
        for name in defaultsNames { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
    }

    private let matthew5 = ChapterLocation(book: "MAT", chapter: 5)
    private func verse(_ n: Int, _ text: String) -> Verse {
        Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: n), translationID: "ESV", text: text, breakAfter: false)
    }
    private var chapter: [Verse] { [verse(1, "Blessed are the poor."), verse(2, "For theirs is."), verse(3, "Blessed mourners.")] }
    /// Matthew 5 alone in a book layout, after its label.
    private var layout: BookLayout {
        BookLayout.build(chapters: [BookChapterInput(location: matthew5, verses: chapter)],
                         opening: BookOpening(bookName: "Matthew", title: BookTitle(title: "Matthew", subtitle: nil)), typography: .default)
    }

    /// The markup model on an in-memory store with the default colors, its store (which owns the
    /// container, so it is kept alive with the model) and a scratch defaults suite.
    private func makeMarkup() throws -> (MarkupModel, MarkupStore, UserDefaults) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let name = "PenModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaultsNames.append(name)
        let markup = MarkupModel(store: store, defaults: defaults)
        markup.load(book: "MAT", chapters: 5...5, chapterInView: matthew5, translationID: "ESV")
        markup.setLayout(layout)
        return (markup, store, defaults)
    }

    /// What the reader reports for verse `verse`'s characters `start..<end`, as the text view does.
    private func report(_ markup: MarkupModel, verse: Int, _ start: Int, _ end: Int, text: String) -> SelectionReport {
        let span = layout.span(for: VerseLocation(book: "MAT", chapter: 5, verse: verse))!
        let range = NSRange(location: span.textRange.location + start, length: end - start)
        return ReaderTextLogic.report(for: range, layout: layout, decorations: markup.bookDecorations)!
    }

    @Test func paintingAppliesThePenColorAndSelectsTheMark() throws {
        let (markup, store, defaults) = try makeMarkup()
        let pen = PenModel(markup: markup, defaults: defaults)
        pen.turnOn()
        let id = try #require(pen.paint(report(markup, verse: 1, 0, 7, text: "Blessed")))
        let stored = try store.highlights(in: matthew5)
        #expect(stored.map(\.uuid) == [id])
        #expect(stored.first?.colorID == markup.colorChips[0].id && stored.first?.quotedText == "Blessed")
        #expect(pen.selectedHighlightID == id)
        #expect(markup.outlinedHighlightID == id)
    }

    /// Review Focus 3: a paint that covers nothing (a tap, or a drag over only a verse number or
    /// white space, which the snap turns into no range and so no report) paints nothing.
    @Test func paintingNothingMakesNoHighlight() throws {
        let (markup, store, defaults) = try makeMarkup()
        let pen = PenModel(markup: markup, defaults: defaults)
        pen.turnOn()
        #expect(pen.paint(nil) == nil)
        #expect(markup.items.isEmpty)
        #expect(try store.highlights(in: matthew5).isEmpty)
        #expect(pen.selectedHighlightID == nil && markup.outlinedHighlightID == nil)
    }

    @Test func choosingAColorRecolorsTheSelectedMarkAndIsRemembered() throws {
        let (markup, store, defaults) = try makeMarkup()
        let pen = PenModel(markup: markup, defaults: defaults)
        pen.turnOn()
        let id = try #require(pen.paint(report(markup, verse: 1, 0, 7, text: "Blessed")))
        let third = markup.colorChips[2].id

        pen.chooseColor(third)
        #expect(pen.colorID == third)
        #expect(try store.highlight(id: id)?.colorID == third)
        #expect(pen.selectedHighlightID == id && markup.outlinedHighlightID == id)

        // With nothing selected a color only becomes the pen's.
        pen.select(highlightID: nil)
        pen.chooseColor(markup.colorChips[1].id)
        #expect(try store.highlight(id: id)?.colorID == third)
        #expect(pen.colorID == markup.colorChips[1].id)

        let again = PenModel(markup: markup, defaults: defaults)
        #expect(again.colorID == markup.colorChips[1].id)
    }

    @Test func thePenStartsOnTheFirstColor() throws {
        let (markup, _, defaults) = try makeMarkup()
        let pen = PenModel(markup: markup, defaults: defaults)
        #expect(!pen.isOn)
        #expect(pen.colorID == markup.colorChips[0].id)
        #expect(pen.selectedHighlightID == nil)

        // A stored color that no longer exists falls back to the first chip.
        defaults.set(UUID().uuidString, forKey: PenModel.colorKey)
        #expect(PenModel(markup: markup, defaults: defaults).colorID == markup.colorChips[0].id)
    }

    @Test func turningOffClearsSelectionAndOutline() throws {
        let (markup, _, defaults) = try makeMarkup()
        let pen = PenModel(markup: markup, defaults: defaults)
        pen.turnOn()
        #expect(pen.isOn)
        let id = try #require(pen.paint(report(markup, verse: 1, 0, 7, text: "Blessed")))
        #expect(pen.selectedHighlightID == id)

        pen.turnOff()
        #expect(!pen.isOn)
        #expect(pen.selectedHighlightID == nil)
        #expect(markup.outlinedHighlightID == nil)
        #expect(markup.items.map(\.id) == [id])
    }

    @Test func selectingAndResizingTheSelectedMark() throws {
        let (markup, store, defaults) = try makeMarkup()
        let pen = PenModel(markup: markup, defaults: defaults)
        pen.turnOn()
        let id = try #require(pen.paint(report(markup, verse: 1, 0, 7, text: "Blessed")))
        pen.select(highlightID: nil)
        #expect(pen.selectedHighlightID == nil && markup.outlinedHighlightID == nil)

        // Nothing selected: a resize does nothing.
        pen.resizeSelected(to: report(markup, verse: 1, 0, 11, text: "Blessed are"))
        #expect(try store.highlight(id: id)?.endOffset == 7)

        pen.select(highlightID: id)
        #expect(pen.selectedHighlightID == id && markup.outlinedHighlightID == id)
        pen.resizeSelected(to: report(markup, verse: 1, 0, 11, text: "Blessed are"))
        #expect(try store.highlight(id: id)?.endOffset == 11)
        #expect(try store.highlight(id: id)?.quotedText == "Blessed are")
        #expect(pen.selectedHighlightID == id && markup.outlinedHighlightID == id)
        pen.resizeSelected(to: nil)
        #expect(try store.highlight(id: id)?.endOffset == 11)
    }

    @Test @MainActor func thePenColorStaysOnTheDevice() {
        #expect(!SyncedPreferences.keys.contains(PenModel.colorKey))
        #expect(PenModel.colorKey == "penColorID")
    }
}
