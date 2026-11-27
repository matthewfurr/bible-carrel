import Foundation
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct MarkupModelTests {
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

    /// The book reader's load of a window of Matthew 5 alone, with its layout.
    private func loadMatthew5(_ model: MarkupModel) {
        model.load(book: "MAT", chapters: 5...5, chapterInView: matthew5, translationID: "ESV")
        model.setLayout(layout)
    }

    private func makeModel() throws -> (MarkupModel, MarkupStore) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let defaults = UserDefaults(suiteName: "MarkupModelTests-\(UUID().uuidString)")!
        let model = MarkupModel(store: store, defaults: defaults)
        loadMatthew5(model)
        return (model, store)
    }

    private func report(_ model: MarkupModel, verse: Int, _ start: Int, _ end: Int, text: String) -> SelectionReport {
        let span = layout.span(for: VerseLocation(book: "MAT", chapter: 5, verse: verse))!
        let range = NSRange(location: span.textRange.location + start, length: end - start)
        let selection = TextSelection(book: "MAT", chapter: 5, verse: verse, endVerse: verse, startOffset: start, endOffset: end, quotedText: text)
        let decorations = model.bookDecorations
        let ids = decorations.ids(intersecting: range)
        let primary = ids.compactMap { decorations.decoration(id: $0) }
            .filter { $0.range.location <= range.location && NSMaxRange(range) <= NSMaxRange($0.range) }
            .min { $0.range.length < $1.range.length }?.id
        return SelectionReport(selection: selection, range: range, highlightIDs: ids, primaryHighlightID: primary)
    }

    /// The toolbar and ⇧⌘A ask about the selection when there is one (Ruling 1 (c)); a caret
    /// or a new book means there is none.
    @Test func currentSelectionIsTheLastNonEmptySelection() throws {
        let (model, _) = try makeModel()
        let selected = report(model, verse: 1, 0, 7, text: "Blessed")
        model.setSelection(selected)
        #expect(model.currentSelection == selected)
        model.setSelection(report(model, verse: 1, 3, 3, text: ""))
        #expect(model.currentSelection == nil)
        model.setSelection(selected)
        model.load(book: "MRK", chapters: 1...1, chapterInView: ChapterLocation(book: "MRK", chapter: 1), translationID: "ESV")
        #expect(model.currentSelection == nil)
    }

    /// The phone's note sheet acts on a note's highlight as the edit bar would on it selected
    /// (spec 3.1): the model makes that report from its own layout, and knows the note on a
    /// highlight, which a tap opens to read.
    @Test func aHighlightsNoteAndReportComeFromTheModel() throws {
        let (model, _) = try makeModel()
        let selected = report(model, verse: 3, 0, 7, text: "Blessed")
        let id = try #require(model.applyColor(model.colorChips[0].id, to: selected))
        #expect(model.noteID(forHighlight: id) == nil)
        let made = try #require(model.report(forHighlight: id))
        #expect(made.selection.verse == 3 && made.selection.quotedText == "Blessed")
        #expect(made.primaryHighlightID == id && made.highlightIDs == [id])
        model.addNote(to: made)
        let noteID = try #require(model.editingNoteID)
        #expect(model.noteID(forHighlight: id) == noteID)
        #expect(model.report(forHighlight: UUID()) == nil)
    }

    @Test func applyingAColorCreatesAHighlightAndACompactRow() throws {
        let (model, store) = try makeModel()
        let yellow = model.colorChips[0].id
        model.applyColor(yellow, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let stored = try store.highlights(in: matthew5)
        #expect(stored.count == 1 && stored[0].colorID == yellow && stored[0].quotedText == "Blessed")
        #expect(model.items.count == 1 && model.bookDecorations.highlights.count == 1)
        guard case .compactHighlight(let row)? = model.columnItems.first else { Issue.record("expected a compact row"); return }
        #expect(row.referenceString == "Matthew 5:1" && row.quotedText == "Blessed")
    }

    @Test func menuOffersRecolorAndRemoveInsideASingleHighlight() throws {
        let (model, _) = try makeModel()
        let yellow = model.colorChips[0].id
        model.applyColor(yellow, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let inside = report(model, verse: 1, 2, 4, text: "es")
        #expect(inside.highlightIDs.count == 1)
        let items = model.menuItems(for: inside)
        #expect(items[0] == .swatches(model.colorChips, current: yellow))
        #expect(items[1] == .addColor)
        #expect(items[2] == .noColor(isCurrent: false))
        #expect(items[3] == .addNote(existing: false))
        #expect(items[4] == .removeHighlight)
        #expect(items[5] == .bookmark(verse: 1, isSet: false))
        #expect(Array(items[6...]) == [.compareTranslations, .crossReferences, .copy, .copyWithReference, .copyLink, .share, .askAboutPassage])
        model.applyColor(model.colorChips[2].id, to: inside)
        #expect(model.items.count == 1 && model.items[0].color == model.colorChips[2].color)
        model.removeHighlight(in: inside)
        #expect(model.items.isEmpty)
    }

    @Test func copyLinkFollowsCopyWithReferenceAndNamesTheVersesAlone() throws {
        let (model, _) = try makeModel()
        let one = report(model, verse: 2, 0, 3, text: "For")
        let items = model.menuItems(for: one)
        #expect(Array(items.suffix(5)) == [.copy, .copyWithReference, .copyLink, .share, .askAboutPassage])
        let link = model.passageLink(for: one)
        #expect(link.translationID == nil && link.url(scheme: "bible").absoluteString == "bible://mat.5.2")
        #expect(PassageLink(link.url(scheme: "bible-dev"))?.reference == one.selection.reference)      // a copied link round-trips
    }

    @Test func compareAndCrossReferencesFollowTheBookmarkAndComeBeforeCopy() throws {
        let (model, _) = try makeModel()
        let items = model.menuItems(for: report(model, verse: 2, 0, 3, text: "For"))
        let bookmark = try #require(items.firstIndex { if case .bookmark = $0 { true } else { false } })
        #expect(Array(items[(bookmark + 1)...(bookmark + 3)]) == [.compareTranslations, .crossReferences, .copy])
    }

    @Test func menuOutsideAnyHighlightHasNoRemove() throws {
        let (model, _) = try makeModel()
        let items = model.menuItems(for: report(model, verse: 2, 0, 3, text: "For"))
        #expect(items[0] == .swatches(model.colorChips, current: nil))
        #expect(!items.contains(.removeHighlight))
    }

    @Test func addingANoteCreatesAColorlessAnchorAndStartsEditing() throws {
        let (model, store) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let stored = try store.highlights(in: matthew5)
        #expect(stored.count == 1 && stored[0].colorID == nil && stored[0].note != nil)
        #expect(model.editingNoteID == stored[0].note?.uuid)
        #expect(model.bookDecorations.highlights[0].style == .dottedUnderline)
        guard case .note(let card)? = model.columnItems.first else { Issue.record("expected a card"); return }
        #expect(card.highlightID == stored[0].uuid && card.body == "")
    }

    @Test func endingEmptyEditDeletesNoteAndColorlessAnchor() throws {
        let (model, store) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "   \n")
        model.endEditing(noteID: noteID)
        #expect(model.editingNoteID == nil)
        #expect(try store.highlights(in: matthew5).isEmpty)
        #expect(model.columnItems.isEmpty)
    }

    @Test func endingEmptyEditKeepsColoredHighlight() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let highlightID = model.items[0].id
        model.expandCompactRow(highlightID: highlightID)
        model.beginEditingDraft(highlightID: highlightID)
        let noteID = model.editingNoteID!
        model.endEditing(noteID: noteID)
        let stored = try store.highlights(in: matthew5)
        #expect(stored.count == 1 && stored[0].note == nil)
        guard case .compactHighlight? = model.columnItems.first else { Issue.record("expected the compact row back"); return }
    }

    @Test func editingASavedNoteKeepsItAndUpdatesTheCard() throws {
        let (model, _) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "**bold** thought")
        model.endEditing(noteID: noteID)
        guard case .note(let card)? = model.columnItems.first else { Issue.record("expected a card"); return }
        #expect(card.body == "**bold** thought")
        #expect(model.items[0].hasNote)
    }

    @Test func notelessRowsHideWithTheSetting() throws {
        let (model, _) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        model.updateNoteBody(noteID: model.editingNoteID!, body: "kept")
        model.endEditing(noteID: model.editingNoteID!)
        #expect(model.columnItems.count == 2)
        model.showNotelessHighlights = false
        #expect(model.columnItems.count == 1)
        guard case .note? = model.columnItems.first else { Issue.record("expected only the note"); return }
    }

    @Test func selectionLightsCardsAndFocusOutlinesHighlights() throws {
        let (model, _) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let id = model.items[0].id
        model.setSelection(report(model, verse: 1, 2, 4, text: "es"))
        #expect(model.selectedHighlightIDs == [id])
        model.focus(highlightID: id)
        #expect(model.bookDecorations.outlinedID == id)
        model.setSelection(nil)
        #expect(model.selectedHighlightIDs.isEmpty && model.bookDecorations.outlinedID == nil)
    }

    /// A selection that went away with its text (another chapter) is forgotten, but an outline a
    /// jump into the new chapter set first is kept, with its card lit; with no outline the old
    /// selection's highlights are let go too.
    @Test func aDroppedSelectionKeepsAJumpsOutline() throws {
        let (model, _) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let id = model.items[0].id
        model.setSelection(report(model, verse: 1, 0, 7, text: "Blessed"))
        model.focus(highlightID: id)
        model.forgetSelection()
        #expect(model.currentSelection == nil)
        #expect(model.bookDecorations.outlinedID == id && model.selectedHighlightIDs == [id])

        model.setSelection(report(model, verse: 1, 2, 4, text: "es"))
        #expect(model.selectedHighlightIDs == [id] && model.currentSelection != nil)
        model.forgetSelection()
        #expect(model.currentSelection == nil && model.selectedHighlightIDs.isEmpty && model.bookDecorations.outlinedID == nil)
    }

    @Test func bookmarkTogglesAndCopyStringsUseTheSelection() throws {
        let (model, _) = try makeModel()
        let r = report(model, verse: 3, 0, 7, text: "Blessed")
        model.toggleBookmark(for: r)
        #expect(model.bookmarkVerses == [3] && model.bookDecorations.bookmarks == [VerseLocation(book: "MAT", chapter: 5, verse: 3)])
        #expect(model.menuItems(for: r).contains(.bookmark(verse: 3, isSet: true)))
        model.toggleBookmark(for: r)
        #expect(model.bookmarkVerses.isEmpty)
        #expect(model.copyText(for: r) == "Blessed")
        #expect(model.copyWithReference(for: r) == "\u{201C}Blessed\u{201D} \u{2014} Matthew 5:3 (ESV)")
    }

    @Test func chapterNotesAppearInTheBandAndAsCards() throws {
        let (model, store) = try makeModel()
        let note = Note(body: "On the whole chapter", scope: .chapter, book: "MAT", chapter: 5, verse: 1, endVerse: 1, translationID: "ESV", quotedText: "")
        store.context.insert(note)
        try store.context.save()
        model.reload()
        #expect(model.chapterNotes.map(\.body) == ["On the whole chapter"])
        guard case .note(let card)? = model.columnItems.first else { Issue.record("expected a card"); return }
        #expect(card.isChapterNote && card.highlightID == nil)
    }

    @Test func addingAColorFromTheMenuAppliesItAndListsIt() throws {
        let (model, _) = try makeModel()
        model.addColorAndApply(name: "Teal", lightHex: "#A0E0E0", darkHex: "#104040", to: report(model, verse: 1, 0, 7, text: "Blessed"))
        #expect(model.colorChips.map(\.name).last == "Teal")
        // The store holds both picks to the marks' lightness band.
        #expect(model.items[0].color == MarkupColor(
            lightHex: MarkLightness.conformed(hex: "#A0E0E0", dark: false),
            darkHex: MarkLightness.conformed(hex: "#104040", dark: true)))
    }

    @Test func loadingAnotherChapterWhileEditingAnEmptyNoteDeletesIt() throws {
        let (model, store) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        #expect(model.editingNoteID != nil)
        model.load(book: "MAT", chapters: 6...6, chapterInView: ChapterLocation(book: "MAT", chapter: 6), translationID: "ESV")
        #expect(model.editingNoteID == nil)
        #expect(try store.highlights(in: matthew5).isEmpty)
        #expect(try store.notes(in: matthew5).isEmpty)
    }

    /// Nothing to show (a translation that lacks the book): `clear` ends an edit (its empty note
    /// goes, by the delete-when-empty rule), clears the selection and the outline, and empties the
    /// window; the marks themselves stay in the store.
    @Test func clearingTheWindowEndsAnEditAndClearsTheSelection() throws {
        let (model, store) = try makeModel()
        let id = try #require(model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed")))
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        #expect(model.editingNoteID != nil)
        model.setSelection(report(model, verse: 3, 0, 7, text: "Blessed"))
        model.focus(highlightID: id)
        #expect(model.currentSelection != nil && model.outlinedHighlightID == id)

        model.clear(translationID: "XYZ")
        #expect(model.editingNoteID == nil && model.currentSelection == nil)
        #expect(model.outlinedHighlightID == nil && model.selectedHighlightIDs.isEmpty)
        #expect(model.book == nil && model.chapter == nil && model.translationID == "XYZ")
        #expect(model.items.isEmpty && model.columnItems.isEmpty && model.bookDecorations == .none)
        #expect(try store.notes(in: matthew5).isEmpty)
        #expect(try store.highlights(in: matthew5).map(\.uuid) == [id])
    }

    @Test func reloadSweepsEmptyNotesLeftByAQuitButKeepsTheOneBeingEdited() throws {
        // A day and more after the orphans were made, so they are old enough to sweep.
        let (model, store) = try makeModel(now: Date().addingTimeInterval(MarkupModel.emptyNoteSweepAge + 3600))
        // An orphan from a previous run: empty note on a colorless anchor.
        let orphan = try store.addHighlight(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed")
        try store.addNote(to: orphan, body: "")
        // And one on a colored highlight: the highlight survives, the empty note goes.
        let colored = try store.addHighlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: model.colorChips[0].id, quotedText: "Blessed")
        try store.addNote(to: colored, body: " ")
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))   // being edited now, empty, must stay
        model.reload()
        let highlights = try store.highlights(in: matthew5)
        #expect(highlights.map(\.verse) == [2, 3])
        #expect(highlights[1].note == nil && highlights[0].note != nil)
        #expect(model.editingNoteID == highlights[0].note?.uuid)
    }

    @Test func nestedHighlightsActOnTheInnermostOne() throws {
        let (model, _) = try makeModel()
        // Inner first: a selection inside an existing highlight recolors it (Ruling 5), so nesting
        // arises when the larger highlight is made afterwards.
        model.applyColor(model.colorChips[1].id, to: report(model, verse: 1, 8, 11, text: "are"))
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 20, text: "Blessed are the poor"))
        let inner = model.items.first { $0.startOffset == 8 }!
        let insideBoth = report(model, verse: 1, 9, 10, text: "r")
        #expect(insideBoth.highlightIDs.count == 2)
        #expect(model.menuItems(for: insideBoth).contains(.removeHighlight))
        model.applyColor(model.colorChips[2].id, to: insideBoth)
        #expect(model.items.count == 2)
        #expect(model.items.first { $0.id == inner.id }?.color == model.colorChips[2].color)
        model.removeHighlight(in: insideBoth)
        #expect(model.items.map(\.startOffset) == [0])
    }

    @Test func deletingACompactRowRemovesTheHighlight() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        guard case .compactHighlight(let row)? = model.columnItems.first else { Issue.record("expected a compact row"); return }
        model.deleteHighlight(id: row.id)
        #expect(model.columnItems.isEmpty)
        #expect(try store.highlights(in: matthew5).isEmpty)
    }

    @Test func expandingACompactRowShowsADraftCardWithoutCreatingANote() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let highlightID = model.items[0].id
        model.expandCompactRow(highlightID: highlightID)
        #expect(model.expandedHighlightID == highlightID)
        #expect(model.selectedHighlightIDs == [highlightID] && model.outlinedHighlightID == highlightID)
        #expect(model.editingNoteID == nil)
        #expect(try store.notes(in: matthew5).isEmpty)
        guard case .note(let card)? = model.columnItems.first else { Issue.record("expected a draft card"); return }
        #expect(card.highlightID == highlightID && card.body == "" && card.isDraft)
        #expect(model.columnItems.first?.id == highlightID)
        // Clicking into the field creates the note under the same column identity.
        model.beginEditingDraft(highlightID: highlightID)
        #expect(model.expandedHighlightID == nil && model.editingNoteID != nil)
        #expect(model.columnItems.first?.id == highlightID)
        guard case .note(let real)? = model.columnItems.first else { Issue.record("expected a card"); return }
        #expect(real.id == model.editingNoteID && !real.isDraft)
    }

    @Test func focusingAHighlightLightsItsCard() throws {
        let (model, _) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        model.applyColor(model.colorChips[1].id, to: report(model, verse: 2, 0, 3, text: "For"))
        let first = model.items[0].id, second = model.items[1].id
        model.setSelection(report(model, verse: 1, 2, 4, text: "es"))
        #expect(model.selectedHighlightIDs == [first])
        model.focus(highlightID: second)
        #expect(model.selectedHighlightIDs == [second] && model.outlinedHighlightID == second)
    }

    @Test func deletingTheNoteBeingEditedRemovesItAndStopsEditing() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        model.addNote(to: report(model, verse: 1, 2, 4, text: "es"))
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "draft words")
        model.deleteNote(noteID: noteID)
        #expect(model.editingNoteID == nil)
        #expect(try store.notes(in: matthew5).isEmpty)
        #expect(try store.highlights(in: matthew5).count == 1)   // colored, so it stays
    }

    /// An undo manager that records each registration as its own step, as a window's does per event.
    private func undoManager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    private func step(_ manager: UndoManager, _ work: () -> Void) {
        manager.beginUndoGrouping()
        work()
        manager.endUndoGrouping()
    }

    @Test func deletingANoteFromTheColumnIsUndoableAndRedoable() throws {
        let (model, store) = try makeModel()
        let manager = undoManager()
        model.undoManager = manager
        model.addNote(to: report(model, verse: 1, 0, 7, text: "Blessed"))   // colorless anchor
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "poor in spirit")
        model.endEditing(noteID: noteID)

        step(manager) { model.deleteNote(noteID: noteID) }
        #expect(try store.notes(in: matthew5).isEmpty && store.highlights(in: matthew5).isEmpty)
        #expect(manager.canUndo && manager.undoActionName == "Delete Note")

        manager.undo()
        #expect(try store.notes(in: matthew5).map(\.uuid) == [noteID])
        #expect(try store.highlights(in: matthew5).first?.note?.body == "poor in spirit")
        #expect(model.selectedHighlightIDs == Set(model.items.map(\.id)))
        #expect(manager.canRedo)

        manager.redo()
        #expect(try store.notes(in: matthew5).isEmpty)
        manager.undo()
        #expect(try store.notes(in: matthew5).count == 1)
    }

    /// The note sheet's Delete (spec 3.1): the highlight goes with its note, and one undo (a
    /// shake on the phone) brings both back, the note's words with them.
    @Test func theNoteSheetsDeleteIsUndoneWithItsNote() throws {
        let (model, store) = try makeModel()
        let manager = undoManager()
        model.undoManager = manager
        let id = try #require(model.applyColor(model.colorChips[0].id, to: report(model, verse: 3, 0, 7, text: "Blessed")))
        let sheetReport = try #require(model.report(forHighlight: id))
        model.addNote(to: sheetReport)
        let noteID = try #require(model.editingNoteID)
        model.updateNoteBody(noteID: noteID, body: "See Rom 8.")
        model.endEditing(noteID: noteID)

        step(manager) { model.deleteHighlight(id: id) }
        #expect(try store.highlights(in: matthew5).isEmpty && model.noteID(forHighlight: id) == nil)
        manager.undo()
        let restored = try #require(try store.highlight(id: id))
        #expect(restored.note?.body == "See Rom 8.")
        #expect(model.noteID(forHighlight: id) == restored.note?.uuid)
    }

    @Test func deletingAHighlightOrClearingItsColorIsUndoable() throws {
        let (model, store) = try makeModel()
        let manager = undoManager()
        model.undoManager = manager
        let yellow = model.colorChips[0].id
        model.applyColor(yellow, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let id = model.items[0].id

        step(manager) { model.deleteHighlight(id: id) }
        #expect(try store.highlights(in: matthew5).isEmpty && manager.undoActionName == "Delete Highlight")
        manager.undo()
        #expect(try store.highlights(in: matthew5).map(\.colorID) == [yellow])

        // No color on a noteless highlight deletes it; that is undoable too.
        step(manager) { model.setColor(nil, highlightID: id) }
        #expect(try store.highlights(in: matthew5).isEmpty)
        manager.undo()
        #expect(try store.highlights(in: matthew5).map(\.uuid) == [id])
    }

    /// The pen's handles: the highlight keeps its id, color and note and takes the new range;
    /// undo puts the old range back and redo the new one.
    @Test func resizingMovesTheHighlightAndCanBeUndone() throws {
        let (model, store) = try makeModel()
        let manager = undoManager()
        model.undoManager = manager
        let yellow = model.colorChips[0].id
        let id = try #require(model.applyColor(yellow, to: report(model, verse: 1, 0, 7, text: "Blessed")))
        model.addNote(to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let noteID = try #require(model.editingNoteID)
        model.updateNoteBody(noteID: noteID, body: "poor in spirit")
        model.endEditing(noteID: noteID)

        // Across into verse 2: "are the poor. For"
        let start = layout.span(for: VerseLocation(book: "MAT", chapter: 5, verse: 1))!.textRange.location + 8
        let end = layout.span(for: VerseLocation(book: "MAT", chapter: 5, verse: 2))!.textRange.location + 3
        let across = try #require(ReaderTextLogic.report(for: NSRange(location: start, length: end - start), layout: layout,
                                                         decorations: model.bookDecorations))
        step(manager) { model.resizeHighlight(id: id, to: across) }
        var stored = try #require(try store.highlight(id: id))
        #expect((stored.verse, stored.endVerse, stored.startOffset, stored.endOffset) == (1, 2, 8, 3))
        #expect(stored.quotedText == across.selection.quotedText && stored.quotedText != "Blessed")
        #expect(stored.colorID == yellow && stored.note?.uuid == noteID)
        #expect(stored.note?.quotedText == across.selection.quotedText && stored.note?.endVerse == 2)
        #expect(model.items.count == 1 && model.items[0].startOffset == 8 && model.items[0].endVerse == 2)
        #expect(model.outlinedHighlightID == id)

        manager.undo()
        stored = try #require(try store.highlight(id: id))
        #expect((stored.verse, stored.endVerse, stored.startOffset, stored.endOffset) == (1, 1, 0, 7))
        #expect(stored.quotedText == "Blessed" && stored.note?.quotedText == "Blessed")
        #expect(model.items[0].startOffset == 0 && model.items[0].endOffset == 7)

        manager.redo()
        stored = try #require(try store.highlight(id: id))
        #expect((stored.verse, stored.endVerse, stored.startOffset, stored.endOffset) == (1, 2, 8, 3))
        manager.undo()
        #expect(try store.highlight(id: id)?.endOffset == 7)

        // A highlight that is gone resizes nothing and registers no undo.
        step(manager) { model.deleteHighlight(id: id) }
        let undoName = manager.undoActionName
        model.resizeHighlight(id: id, to: across)
        #expect(try store.highlights(in: matthew5).isEmpty && manager.undoActionName == undoName)
    }

    @Test func aFailedSaveLeavesAPlainMessageUntilCleared() throws {
        let (model, _) = try makeModel()
        #expect(model.lastError == nil)
        model.clearError()
        #expect(model.lastError == nil)
        #expect(!MarkupModel.saveFailure.contains("Error") && MarkupModel.saveFailure.hasSuffix("."))
    }

    @Test func aCaretInsideAHighlightOutlinesItInsteadOfSelectingText() throws {
        let (model, _) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let id = model.items[0].id
        model.setSelection(report(model, verse: 1, 3, 3, text: ""))
        #expect(model.selectedHighlightIDs == [id] && model.outlinedHighlightID == id)
        model.setSelection(report(model, verse: 2, 0, 3, text: "For"))   // a drag elsewhere clears it
        #expect(model.outlinedHighlightID == nil)
    }

    @Test func crossTranslationHighlightOffersRemoveNoteAndRecolor() throws {
        let (model, store) = try makeModel()
        // Made in KJV, viewed in ESV: drawn as a dashed underline on the whole verse.
        let kjv = try store.addHighlight(book: "MAT", chapter: 5, verse: 2, endVerse: 2, startOffset: 0, endOffset: 5, translationID: "KJV", colorID: model.colorChips[0].id, quotedText: "And he")
        try store.addNote(to: kjv, body: "from the KJV")
        model.reload()
        let inside = report(model, verse: 2, 4, 10, text: "theirs")
        #expect(inside.primaryHighlightID == kjv.uuid)
        let items = model.menuItems(for: inside)
        #expect(items.contains(.removeHighlight))
        #expect(items.contains(.addNote(existing: true)))
        #expect(items.contains(.noColor(isCurrent: false)))
        #expect(items[0] == .swatches(model.colorChips, current: model.colorChips[0].id))
        model.applyColor(model.colorChips[2].id, to: inside)
        #expect(try store.highlights(in: matthew5).count == 1)
        #expect(try store.highlights(in: matthew5)[0].colorID == model.colorChips[2].id)
        model.removeHighlight(in: inside)
        #expect(try store.highlights(in: matthew5).isEmpty && (try store.notes(in: matthew5).isEmpty))
    }

    @Test func noColorClearsTheColorAndDeletesANotelessHighlight() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let noted = report(model, verse: 1, 2, 4, text: "es")
        model.addNote(to: noted)
        model.updateNoteBody(noteID: model.editingNoteID!, body: "kept")
        model.endEditing(noteID: model.editingNoteID!)
        #expect(model.menuItems(for: noted).contains(.noColor(isCurrent: false)))
        model.clearColor(in: noted)
        #expect(try store.highlights(in: matthew5)[0].colorID == nil)
        #expect(model.menuItems(for: noted).contains(.noColor(isCurrent: true)))
        model.applyColor(model.colorChips[1].id, to: report(model, verse: 3, 0, 7, text: "Blessed"))
        let noteless = model.items.first { $0.verse == 3 }!.id
        model.setColor(nil, highlightID: noteless)
        #expect(model.items.contains { $0.id == noteless } == false)
    }

    @Test func recoloringFromACardChangesThatHighlight() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        let id = model.items[0].id
        model.setColor(model.colorChips[3].id, highlightID: id)
        #expect(try store.highlights(in: matthew5)[0].colorID == model.colorChips[3].id)
        #expect(model.items[0].color == model.colorChips[3].color)
        // The recolored highlight stays selected and outlined, so the change is visible at once.
        #expect(model.outlinedHighlightID == id && model.selectedHighlightIDs == [id])
        #expect(model.bookDecorations.outlinedID == id)
    }

    @Test func aCommittedNoteCanBeEditedAgain() throws {
        let (model, store) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "first")
        model.endEditing(noteID: noteID)
        #expect(model.editingNoteID == nil)
        let highlightID = model.items[0].id
        model.focus(highlightID: highlightID)        // first click selects
        model.beginEditing(noteID: noteID)           // second click into the text edits
        #expect(model.editingNoteID == noteID)
        model.updateNoteBody(noteID: noteID, body: "first, then more")
        model.endEditing(noteID: noteID)
        #expect(try store.notes(in: matthew5)[0].body == "first, then more")
    }

    @Test func applyingAColorReportsTheHighlightItTouched() throws {
        let (model, _) = try makeModel()
        let created = model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        #expect(created == model.items[0].id)
        let recolored = model.applyColor(model.colorChips[1].id, to: report(model, verse: 1, 2, 4, text: "es"))
        #expect(recolored == created && model.items.count == 1)
        model.focus(highlightID: created!)
        #expect(model.outlinedHighlightID == created && model.selectedHighlightIDs == [created!])
    }

    @Test func addingANoteRequestsEditorFocus() throws {
        let (model, _) = try makeModel()
        let before = model.editorFocusRequest
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        #expect(model.editorFocusRequest == before + 1)
        let noteID = model.editingNoteID!
        model.updateNoteBody(noteID: noteID, body: "x")
        model.endEditing(noteID: noteID)
        model.beginEditing(noteID: noteID)
        #expect(model.editorFocusRequest == before + 2)
    }

    // MARK: - Changes made elsewhere

    /// A fixed clock, so a note's age is exact.
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func makeModel(now: Date) throws -> (MarkupModel, MarkupStore) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let defaults = UserDefaults(suiteName: "MarkupModelTests-\(UUID().uuidString)")!
        let model = MarkupModel(store: store, defaults: defaults, now: { now })
        loadMatthew5(model)
        return (model, store)
    }

    /// An empty note on a colored highlight, last changed `age` seconds before `now`.
    private func emptyNote(_ store: MarkupStore, colorID: UUID, age: TimeInterval) throws -> UUID {
        let highlight = try store.addHighlight(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: colorID, quotedText: "Blessed")
        let note = try store.addNote(to: highlight, body: "")
        note.modifiedAt = now.addingTimeInterval(-age)
        try store.context.save()
        return note.uuid
    }

    /// Deletes through a second context on the same container, as an iCloud import does.
    private func deleteHighlightElsewhere(_ id: UUID, in store: MarkupStore) throws {
        let other = ModelContext(store.container)
        let found = try other.fetch(FetchDescriptor<Highlight>(predicate: #Predicate { $0.uuid == id }))
        #expect(found.count == 1)
        for highlight in found { other.delete(highlight) }
        try other.save()
    }

    private func deleteNoteElsewhere(_ id: UUID, in store: MarkupStore) throws {
        let other = ModelContext(store.container)
        let found = try other.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == id }))
        #expect(found.count == 1)
        for note in found { other.delete(note) }
        try other.save()
    }

    @Test func anEmptyNoteYoungerThanADayIsNotSwept() throws {
        let (model, store) = try makeModel(now: now)
        let noteID = try emptyNote(store, colorID: model.colorChips[0].id, age: 2 * 3600)
        model.reload()
        #expect(try store.note(id: noteID) != nil)
        #expect(model.lastError == nil)
    }

    @Test func anEmptyNoteOlderThanADayIsSwept() throws {
        let (model, store) = try makeModel(now: now)
        let noteID = try emptyNote(store, colorID: model.colorChips[0].id, age: 25 * 3600)
        model.reload()
        #expect(try store.note(id: noteID) == nil)
        #expect(try store.highlights(in: matthew5).count == 1)   // colored, so it stays
        #expect(model.lastError == nil)
    }

    @Test func aNoteDeletedElsewhereWhileOpenClosesTheEditor() throws {
        let (model, store) = try makeModel()
        model.applyColor(model.colorChips[0].id, to: report(model, verse: 1, 0, 7, text: "Blessed"))
        model.addNote(to: report(model, verse: 1, 2, 4, text: "es"))
        let noteID = try #require(model.editingNoteID)
        model.updateNoteBody(noteID: noteID, body: "words in progress")
        model.endEditing(noteID: noteID)
        model.beginEditing(noteID: noteID)
        #expect(model.editingNoteID == noteID)
        try deleteNoteElsewhere(noteID, in: store)
        model.reload()
        #expect(model.editingNoteID == nil)
        #expect(!model.columnItems.contains { $0.id == noteID })
        #expect(!model.chapterNotes.contains { $0.id == noteID })
        #expect(model.lastError == nil)
    }

    @Test func actingOnARowDeletedElsewhereDoesNothing() throws {
        let (model, store) = try makeModel()
        let manager = undoManager()
        model.undoManager = manager
        let yellow = model.colorChips[0].id, blue = model.colorChips[2].id
        // A colored highlight on 5:3 that stays throughout; the notes below are made on it.
        model.applyColor(yellow, to: report(model, verse: 3, 0, 8, text: "Blessed "))
        let kept = try #require(model.items.first).id
        var goneIDs: [UUID] = []

        /// A noteless yellow highlight on 5:1, loaded into the model, then deleted elsewhere.
        func goneHighlight() throws -> (id: UUID, inside: SelectionReport) {
            model.reload()
            model.applyColor(yellow, to: report(model, verse: 1, 0, 7, text: "Blessed"))
            let id = try #require(model.items.first { $0.verse == 1 }).id
            let inside = report(model, verse: 1, 2, 4, text: "es")
            #expect(inside.primaryHighlightID == id)
            manager.removeAllActions()
            try deleteHighlightElsewhere(id, in: store)
            goneIDs.append(id)
            return (id, inside)
        }

        /// A note with words in it on the 5:3 highlight, loaded into the model, then deleted elsewhere.
        func goneNote() throws -> UUID {
            model.reload()
            model.addNote(to: report(model, verse: 3, 2, 4, text: "es"))
            let id = try #require(model.editingNoteID)
            model.updateNoteBody(noteID: id, body: "a thought")
            model.endEditing(noteID: id)
            manager.removeAllActions()
            try deleteNoteElsewhere(id, in: store)
            goneIDs.append(id)
            return id
        }

        /// Nothing was written, nothing can be undone, and no error is shown.
        func expectNothingHappened(_ sourceLocation: SourceLocation = #_sourceLocation) throws {
            #expect(model.lastError == nil, sourceLocation: sourceLocation)
            // An empty group still counts for `canUndo`; every undo the model registers is named.
            #expect(manager.undoActionName.isEmpty, sourceLocation: sourceLocation)
            #expect(model.editingNoteID == nil && model.expandedHighlightID == nil, sourceLocation: sourceLocation)
            #expect(try store.allNotes().isEmpty, sourceLocation: sourceLocation)
            #expect(try store.allHighlights().map(\.uuid) == [kept], sourceLocation: sourceLocation)
        }

        // The highlight's entry points, each on a freshly deleted record, before any reload.
        // Each runs inside an undo group, as a window's event does, so a registered undo shows.
        let recolored = try goneHighlight()
        step(manager) { model.setColor(blue, highlightID: recolored.id) }
        try expectNothingHappened()
        let uncolored = try goneHighlight()
        step(manager) { model.setColor(nil, highlightID: uncolored.id) }
        try expectNothingHappened()
        let cleared = try goneHighlight()
        step(manager) { model.clearColor(in: cleared.inside) }
        try expectNothingHappened()
        let removed = try goneHighlight()
        step(manager) { model.removeHighlight(in: removed.inside) }
        try expectNothingHappened()
        let deleted = try goneHighlight()
        step(manager) { model.deleteHighlight(id: deleted.id) }
        try expectNothingHappened()
        let expanded = try goneHighlight()
        step(manager) { model.expandCompactRow(highlightID: expanded.id) }
        try expectNothingHappened()
        let draftedAlone = try goneHighlight()
        step(manager) { model.beginEditingDraft(highlightID: draftedAlone.id) }
        try expectNothingHappened()
        let drafted = try goneHighlight()
        step(manager) {
            model.expandCompactRow(highlightID: drafted.id)
            model.beginEditingDraft(highlightID: drafted.id)
        }
        try expectNothingHappened()

        // The note's.
        let rewritten = try goneNote()
        step(manager) { model.updateNoteBody(noteID: rewritten, body: "rewritten") }
        try expectNothingHappened()
        let ended = try goneNote()
        step(manager) { model.endEditing(noteID: ended) }
        try expectNothingHappened()
        let emptied = try goneNote()
        step(manager) {
            model.updateNoteBody(noteID: emptied, body: "")
            model.endEditing(noteID: emptied)
        }
        try expectNothingHappened()
        let removedNote = try goneNote()
        step(manager) { model.deleteNote(noteID: removedNote) }
        try expectNothingHappened()
        let lookedUp = try goneNote()
        #expect(model.highlightID(forNote: lookedUp) == nil)
        step(manager) { model.beginEditing(noteID: lookedUp) }
        model.reload()
        try expectNothingHappened()

        model.reload()
        #expect(model.items.map(\.id) == [kept])
        #expect(!model.columnItems.contains { goneIDs.contains($0.id) })
        #expect(model.lastError == nil)

        // A swatch or Add Note on text whose highlight went elsewhere acts on the text as it now
        // is: unhighlighted, so a new highlight is made; the deleted one is not brought back.
        let colored = try goneHighlight()
        let made = try #require(model.applyColor(blue, to: colored.inside))
        #expect(made != colored.id && model.lastError == nil)
        #expect(try store.highlight(id: colored.id) == nil && store.highlight(id: made)?.colorID == blue)
        step(manager) { model.deleteHighlight(id: made) }
        let noted = try goneHighlight()
        model.addNote(to: noted.inside)
        let noteID = try #require(model.editingNoteID)
        #expect(try model.lastError == nil && store.highlight(id: noted.id) == nil)
        #expect(try store.note(id: noteID)?.highlight?.uuid != noted.id)
    }

    @Test func aHighlightWhoseColorIsMissingStillShows() throws {
        let (model, store) = try makeModel()
        try store.addHighlight(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: UUID(), quotedText: "Blessed")
        model.reload()
        #expect(model.items.count == 1 && model.items[0].color == nil && model.items[0].startOffset == 0 && model.items[0].endOffset == 7)
        #expect(model.bookDecorations.highlights.map(\.style) == [.dottedUnderline])
        guard case .compactHighlight(let row)? = model.columnItems.first else { Issue.record("expected a compact row"); return }
        #expect(row.color == nil)
        #expect(try store.allHighlights().count == 1)
        #expect(model.lastError == nil)
    }

    @Test func addingANoteAsksForTheNotesColumn() throws {
        let (model, _) = try makeModel()
        var shown = 0
        model.onShowNotesColumn = { shown += 1 }
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        #expect(shown == 1 && model.editingNoteID != nil)
    }

    @Test func onlyAFinishedEditCounts() throws {
        let (model, _) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        model.endEditing(noteID: model.editingNoteID!)       // a blur, or a click elsewhere
        #expect(model.noteFinishCount == 0)
        model.noteFinished()                                 // ⌘Return, Return or Esc
        #expect(model.noteFinishCount == 1)
    }
}

// MARK: - The open chapter

/// The reader's markup for the one chapter it shows (John 3, alone in its layout), loaded through
/// `follow` as the reader wires it.
extension MarkupModelTests {
    private static let john2 = ChapterLocation(book: "JHN", chapter: 2)
    private static let john3 = ChapterLocation(book: "JHN", chapter: 3)
    @MainActor private static let john2Layout = JohnFixture.layout(2...2)
    @MainActor private static let johnLayout = JohnFixture.layout(3...3)

    private func makeBookModel() throws -> (MarkupModel, MarkupStore) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let defaults = UserDefaults(suiteName: "MarkupModelTests-\(UUID().uuidString)")!
        let model = MarkupModel(store: store, defaults: defaults)
        model.follow(Self.john3, in: Self.johnLayout)
        return (model, store)
    }

    /// What the book reader reports for John 3:`verse`'s characters `start..<end`.
    private func bookReport(_ model: MarkupModel, _ verse: Int, _ start: Int, _ end: Int) throws -> SelectionReport {
        let span = try #require(Self.johnLayout.span(for: VerseLocation(book: "JHN", chapter: 3, verse: verse)))
        let range = NSRange(location: span.textRange.location + start, length: end - start)
        return try #require(ReaderTextLogic.report(for: range, layout: Self.johnLayout, decorations: model.bookDecorations))
    }

    @discardableResult
    private func addJohnHighlight(_ store: MarkupStore, _ chapter: Int, _ verse: Int, colorID: UUID?) throws -> Highlight {
        try store.addHighlight(book: "JHN", chapter: chapter, verse: verse, endVerse: verse, startOffset: 0, endOffset: 5,
                               translationID: "ESV", colorID: colorID, quotedText: "Verse")
    }

    /// Spec 4.2: the notes column follows the open chapter. `follow` loads the chapter the
    /// document's layout shows; a chapter navigation has opened but the document has not built yet
    /// leaves the column on the page's chapter until the new layout arrives.
    @Test func followingLoadsTheOpenChapter() throws {
        let (model, store) = try makeBookModel()
        let yellow = model.colorChips[0].id
        let three = try addJohnHighlight(store, 3, 16, colorID: yellow)
        let two = try addJohnHighlight(store, 2, 1, colorID: yellow)
        let cana = try store.addChapterNote(book: "JHN", chapter: 2, translationID: "ESV", body: "Cana", sourceThreadID: nil)
        model.reload()
        #expect(model.book == "JHN" && model.chapters == 3...3 && model.chapter == Self.john3)
        #expect(model.items.map(\.id) == [three.uuid] && model.columnItems.map(\.id) == [three.uuid])

        model.follow(Self.john2, in: Self.johnLayout)
        #expect(model.chapter == Self.john3 && model.columnItems.map(\.id) == [three.uuid])

        model.follow(Self.john2, in: Self.john2Layout)
        #expect(model.chapters == 2...2 && model.chapter == Self.john2)
        #expect(model.items.map(\.id) == [two.uuid] && model.chapterNotes.map(\.id) == [cana.uuid])
        #expect(model.columnItems.map(\.id) == [cana.uuid, two.uuid])
        #expect(model.bookDecorations.highlights.map(\.id) == [two.uuid] && model.itemsByChapter[3] == nil)
    }

    /// Task 13 fix round 2: reading ESV John 3, switching to a translation that lacks John (no
    /// chapter: the markup is cleared, the document keeps its John layout) and back. Following the
    /// chapter again reloads it: the highlight is drawn again and the column lists it.
    @Test func aChapterClearedForNoTranslationReturnsWithItsMarkup() throws {
        let (model, store) = try makeBookModel()
        let highlight = try addJohnHighlight(store, 3, 2, colorID: model.colorChips[0].id)
        model.reload()
        model.follow(Self.john3, in: Self.johnLayout)        // held: nothing reloads
        #expect(model.chapter == Self.john3 && model.bookDecorations.highlights.map(\.id) == [highlight.uuid])

        model.clear(translationID: "XYZ")
        #expect(model.book == nil && model.bookDecorations == .none)

        model.follow(Self.john3, in: Self.johnLayout)
        #expect(model.book == "JHN" && model.chapters == 3...3 && model.chapter == Self.john3 && model.translationID == "ESV")
        #expect(model.bookDecorations.highlights.map(\.id) == [highlight.uuid])
        #expect(model.items.map(\.id) == [highlight.uuid])
        #expect(model.columnItems.map(\.id) == [highlight.uuid])
    }

    /// A chapter the layout does not show (a navigation the document has not caught up with)
    /// loads nothing for the old layout.
    @Test func followingAChapterOutsideTheLayoutLoadsNothing() throws {
        let (model, _) = try makeBookModel()
        model.clear(translationID: "XYZ")
        model.follow(ChapterLocation(book: "MAT", chapter: 1), in: Self.johnLayout)
        #expect(model.book == nil)
        model.follow(ChapterLocation(book: "JHN", chapter: 9), in: Self.johnLayout)
        #expect(model.book == nil)
        model.follow(nil, in: Self.johnLayout)                // the layout changed with no chapter: its own
        #expect(model.book == "JHN" && model.chapter == Self.john3)
    }

    /// Ruling R10: a draft card (an expanded compact row) belongs to its chapter. Following the
    /// same chapter again keeps it open; opening another chapter closes it.
    @Test func aDraftCardClosesWhenAnotherChapterOpens() throws {
        let (model, store) = try makeBookModel()
        let highlight = try addJohnHighlight(store, 3, 4, colorID: model.colorChips[0].id)
        model.reload()
        model.expandCompactRow(highlightID: highlight.uuid)
        model.follow(Self.john3, in: Self.johnLayout)
        #expect(model.expandedHighlightID == highlight.uuid)
        model.follow(Self.john2, in: Self.john2Layout)
        #expect(model.chapter == Self.john2 && model.expandedHighlightID == nil)
        #expect(try store.notes(in: Self.john3).isEmpty)
    }

    /// Reloading the chapter shown keeps the edit, the selection and the outline; only a new
    /// translation or book clears them.
    @Test func reloadingTheSameChapterKeepsTheEditAndANewTranslationEndsIt() throws {
        let (model, store) = try makeBookModel()
        let highlight = try addJohnHighlight(store, 3, 4, colorID: model.colorChips[0].id)
        model.reload()
        model.addNote(to: try bookReport(model, 2, 0, 5))
        let n = try #require(model.editingNoteID)
        model.updateNoteBody(noteID: n, body: "Kept")
        let selected = try bookReport(model, 4, 0, 3)
        model.setSelection(selected)
        model.focus(highlightID: highlight.uuid)

        model.load(book: "JHN", chapters: 3...3, chapterInView: Self.john3, translationID: "ESV")
        #expect(model.editingNoteID == n && model.chapter == Self.john3)
        #expect(model.currentSelection == selected && model.outlinedHighlightID == highlight.uuid)
        #expect(!model.bookDecorations.highlights.isEmpty)

        model.load(book: "JHN", chapters: 3...3, chapterInView: Self.john3, translationID: "KJV")
        #expect(model.editingNoteID == nil && model.chapter == Self.john3)
        #expect(model.currentSelection == nil && model.selectedHighlightIDs.isEmpty && model.outlinedHighlightID == nil)
        // The layout was the old translation's.
        #expect(model.bookDecorations == .none)
        #expect(try store.note(id: n)?.body == "Kept")

        model.setSelection(selected)
        model.load(book: "MAT", chapters: 1...1, chapterInView: ChapterLocation(book: "MAT", chapter: 1), translationID: "KJV")
        #expect(model.currentSelection == nil && model.itemsByChapter.values.allSatisfy(\.isEmpty))
    }

    @Test func aTargetIsLoadedWhenItsChapterIsShown() throws {
        let (model, _) = try makeBookModel()
        #expect(model.isLoaded(MarkupTarget(location: Self.john3, verse: 1, translationID: nil, highlightID: nil)))
        #expect(model.isLoaded(MarkupTarget(location: Self.john3, verse: 1, translationID: "ESV", highlightID: nil)))
        #expect(!model.isLoaded(MarkupTarget(location: Self.john2, verse: 1, translationID: nil, highlightID: nil)))
        #expect(!model.isLoaded(MarkupTarget(location: Self.john3, verse: 1, translationID: "KJV", highlightID: nil)))
        #expect(!model.isLoaded(MarkupTarget(location: ChapterLocation(book: "MAT", chapter: 3), verse: 1, translationID: nil, highlightID: nil)))
    }

    /// Review Focus 4: the colour was deleted after the highlight was made (or never synced).
    @Test func aDeletedColourCountsAsNoColour() throws {
        let (model, store) = try makeModel()
        let colors = try store.colors()
        let (first, third) = (colors[0], colors[2])
        _ = try store.addHighlight(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: third.uuid, quotedText: "Blessed")
        _ = try store.addHighlight(book: "MAT", chapter: 5, verse: 2, endVerse: 2, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: first.uuid, quotedText: "For")
        _ = try store.addHighlight(book: "PSA", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 7, translationID: "WEB", colorID: UUID(), quotedText: "Blessed")
        _ = try store.toggleBookmark(at: VerseLocation(book: "MAT", chapter: 6, verse: 1))
        let marks = model.chapterMarks()
        #expect(marks[ChapterLocation(book: "MAT", chapter: 5)]?.colors == [
            MarkupColor(lightHex: first.lightHex, darkHex: first.darkHex), MarkupColor(lightHex: third.lightHex, darkHex: third.darkHex)])
        #expect(marks[ChapterLocation(book: "PSA", chapter: 1)]?.colors == [] && marks[ChapterLocation(book: "MAT", chapter: 6)]?.colors == [])
        #expect(marks[ChapterLocation(book: "MAT", chapter: 1)] == nil)
    }
}

// MARK: - Sittings and versions

/// One sitting per edit in the editors, a card's count of versions, and a note changed under its
/// open editor (keeping data safe 4.1, 4.3).
extension MarkupModelTests {
    private func token(of noteID: UUID, in store: MarkupStore) throws -> String {
        try #require(NoteVersion.token(ofMark: try store.note(id: noteID)?.versionMark))
    }

    private func card(_ noteID: UUID, in model: MarkupModel) -> NoteCard? {
        for case .note(let card) in model.columnItems where card.id == noteID { return card }
        return nil
    }

    @discardableResult
    private func keep(_ body: String, of noteID: UUID, in store: MarkupStore) throws -> UUID {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = body
        version.writtenAt = Date(timeIntervalSince1970: 50)
        version.deviceKind = "Mac"
        version.book = "MAT"
        version.chapter = 5
        version.verse = 2
        version.endVerse = 2
        version.translationID = "ESV"
        store.context.insert(version)
        try store.context.save()
        return version.uuid
    }

    /// A noted highlight on Matthew 5:2 whose editor is open, its text typed as `text`.
    private func editing(_ model: MarkupModel, text: String) throws -> UUID {
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let noteID = try #require(model.editingNoteID)
        model.updateNoteBody(noteID: noteID, body: text)
        return noteID
    }

    @Test func oneSittingPerEditHoweverManyKeystrokes() throws {
        let (model, store) = try makeModel()
        model.addNote(to: report(model, verse: 2, 0, 3, text: "For"))
        let noteID = try #require(model.editingNoteID)
        var tokens: Set<String> = []
        for text in ["o", "on", "one", "one t", "one two"] {
            model.updateNoteBody(noteID: noteID, body: text)
            tokens.insert(try token(of: noteID, in: store))
        }
        #expect(tokens.count == 1)
        #expect(store.openSittings == [noteID])

        model.endEditing(noteID: noteID)
        #expect(store.openSittings.isEmpty)
        model.beginEditing(noteID: noteID)
        #expect(store.openSittings == [noteID])
        model.updateNoteBody(noteID: noteID, body: "one two three")
        let next = try token(of: noteID, in: store)
        #expect(!tokens.contains(next))
        let note = try #require(try store.note(id: noteID))
        #expect(NoteVersion.ancestorDigests(text: note.body, mark: note.versionMark, ancestry: note.versionAncestry).first
            == NoteVersion.digest("one two"))
    }

    @Test func leavingTheBookEndsTheSitting() throws {
        let (model, store) = try makeModel()
        _ = try editing(model, text: "words")
        #expect(!store.openSittings.isEmpty)
        model.load(book: "MRK", chapters: 1...1, chapterInView: ChapterLocation(book: "MRK", chapter: 1), translationID: "ESV")
        #expect(model.editingNoteID == nil)
        #expect(store.openSittings.isEmpty)
    }

    /// The store's settle skips a note with a sitting open, so every way an edit ends ends its sitting.
    @Test func everyWayAnEditEndsEndsItsSitting() throws {
        let ends: [(MarkupModel, MarkupStore, UUID) throws -> Void] = [
            { model, _, noteID in model.deleteNote(noteID: noteID) },
            { model, _, noteID in model.deleteHighlight(id: try #require(model.highlightID(forNote: noteID))) },
            { model, _, _ in model.clear(translationID: "ESV") },
            // The notes column was hidden, or the assistant took the inspector.
            { model, _, _ in model.notesColumnDidHide() },
            { model, _, _ in model.load(book: "MAT", chapters: 5...5, chapterInView: ChapterLocation(book: "MAT", chapter: 5), translationID: "KJV") },
            { model, store, noteID in
                // Deleted on another device: the reload closes the editor.
                let other = ModelContext(store.container)
                for note in try other.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == noteID })) { other.delete(note) }
                try other.save()
                model.reload()
            },
        ]
        for end in ends {
            let (model, store) = try makeModel()
            let noteID = try editing(model, text: "words")
            #expect(store.openSittings == [noteID])
            try end(model, store, noteID)
            #expect(model.editingNoteID == nil)
            #expect(store.openSittings.isEmpty)
        }
    }

    @Test func aCardCountsItsVersions() throws {
        let (model, store) = try makeModel()
        let noteID = try editing(model, text: "N")
        model.endEditing(noteID: noteID)
        #expect(card(noteID, in: model)?.versionCount == 1)
        try keep("K", of: noteID, in: store)
        model.reload()
        #expect(card(noteID, in: model)?.versionCount == 2)
        // A keystroke's card keeps the count.
        model.beginEditing(noteID: noteID)
        model.updateNoteBody(noteID: noteID, body: "N2")
        #expect(card(noteID, in: model)?.versionCount == 2)
    }

    @Test func aDraftIsKeptWhenAnotherDevicesTextArrivedMidEdit() throws {
        let (model, store) = try makeModel()
        let noteID = try editing(model, text: "draft")
        // Another device's text arrives, through the context: this device's journal never hears of it.
        let note = try #require(try store.note(id: noteID))
        note.body = "B1"
        note.versionMark = NoteVersion.mark(token: "bbbb00000001", text: "B1")
        note.versionAncestry = nil
        try store.context.save()
        #expect(try store.settleVersions() == 0)
        model.reload()
        #expect(model.editingNoteID == noteID)
        #expect(try store.keptVersions(forNote: noteID).isEmpty)

        // The app is told once the sitting has ended, with the draft kept, so an open versions view shows it.
        var keptWhenTold: [[String]] = []
        model.onSittingEnd = { keptWhenTold.append((try? store.keptVersions(forNote: noteID).map(\.body)) ?? []) }
        model.endEditing(noteID: noteID)
        #expect(try store.keptVersions(forNote: noteID).map(\.body) == ["draft"])
        #expect(keptWhenTold == [["draft"]])
        #expect(card(noteID, in: model)?.body == "B1")
        #expect(card(noteID, in: model)?.versionCount == 2)
    }

    /// A note with a sitting open is skipped when lost texts are kept, so the column going away
    /// must end its edit: otherwise the draft would wait, unkept, for an edit that never ends.
    @Test func hidingTheColumnEndsItsEditAndKeepsTheDraft() throws {
        let (model, store) = try makeModel()
        let noteID = try editing(model, text: "draft")
        let note = try #require(try store.note(id: noteID))
        note.body = "B1"
        note.versionMark = NoteVersion.mark(token: "bbbb00000001", text: "B1")
        note.versionAncestry = nil
        try store.context.save()
        var told = 0
        model.onSittingEnd = { told += 1 }

        model.notesColumnDidHide()
        #expect(model.editingNoteID == nil)
        #expect(store.openSittings.isEmpty)
        #expect(told == 1)
        #expect(try store.keptVersions(forNote: noteID).map(\.body) == ["draft"])
        // With nothing being edited it does nothing.
        model.notesColumnDidHide()
        #expect(told == 1)
    }

    /// Without the reload, the editor's next save would write its old draft over the chosen text,
    /// which would then be in neither the note nor a kept version.
    @Test func aChoiceUnderTheOpenEditorReloadsItsDraftInANewSitting() throws {
        for choice in [VersionChoice.use, .keepBoth] {
            let (model, store) = try makeModel()
            let noteID = try editing(model, text: "N")
            let keptID = try keep("K", of: noteID, in: store)
            model.reload()
            let versions = NoteVersionsModel(store: store, onChange: { model.reload() }, onNoteChange: { model.reloadEditor(noteID: $0) })
            let before = try token(of: noteID, in: store)
            let request = model.editorReloadRequest

            versions.perform(choice, on: keptID, undoManager: nil)
            let chosen = choice == .use ? "K" : "N\n\nK"
            #expect(model.editingNoteID == noteID)
            #expect(model.editorReloadRequest == request + 1)
            #expect(card(noteID, in: model)?.body == chosen)
            #expect(store.openSittings == [noteID])

            // The editor's next keystroke, on the reloaded draft, is a new sitting opened on the chosen text.
            model.updateNoteBody(noteID: noteID, body: chosen + " more")
            let note = try #require(try store.note(id: noteID))
            #expect(try token(of: noteID, in: store) != before)
            #expect(NoteVersion.ancestorDigests(text: note.body, mark: note.versionMark, ancestry: note.versionAncestry).first
                == NoteVersion.digest(chosen))
            model.endEditing(noteID: noteID)
            #expect(try store.keptVersions(forNote: noteID).map(\.body) == (choice == .use ? ["N"] : []))
        }
    }

    /// Another device's text arrived under the open editor: the store holds it, the draft lives in
    /// the editor and the journal. A choice in the versions view keeps the draft before it writes.
    @Test func aChoiceAfterAnArrivalUnderTheOpenEditorKeepsTheDraft() throws {
        for choice in [VersionChoice.use, .keepBoth] {
            let (model, store) = try makeModel()
            let noteID = try editing(model, text: "draft")
            let note = try #require(try store.note(id: noteID))
            note.body = "B1"
            note.versionMark = NoteVersion.mark(token: "bbbb00000001", text: "B1")
            note.versionAncestry = nil
            try store.context.save()
            #expect(try store.settleVersions() == 0)
            let keptID = try keep("K", of: noteID, in: store)
            model.reload()
            let versions = NoteVersionsModel(store: store, onChange: { model.reload() }, onNoteChange: { model.reloadEditor(noteID: $0) })

            versions.perform(choice, on: keptID, undoManager: nil)
            model.endEditing(noteID: noteID)
            let kept = try store.keptVersions(forNote: noteID).map(\.body).sorted()
            #expect(kept == (choice == .use ? ["B1", "draft"] : ["draft"]), "\(choice)")
            #expect(try store.note(id: noteID)?.body == (choice == .use ? "K" : "B1\n\nK"))
        }
    }

    @Test func reloadingAnotherNotesEditorDoesNothing() throws {
        let (model, store) = try makeModel()
        let noteID = try editing(model, text: "N")
        let before = try token(of: noteID, in: store)
        let request = model.editorReloadRequest
        model.reloadEditor(noteID: UUID())
        model.updateNoteBody(noteID: noteID, body: "N2")
        #expect(model.editorReloadRequest == request)
        #expect(try token(of: noteID, in: store) == before)
    }
}
