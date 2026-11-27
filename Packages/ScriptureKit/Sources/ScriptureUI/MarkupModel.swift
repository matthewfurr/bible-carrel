import Foundation
import Observation
import OSLog
import ScriptureData
import ScriptureModel

/// The markup of the loaded chapters of a book (the open chapter: the reader shows one at a time)
/// and every action the reader and notes column take on it. The loaded highlights, notes and
/// bookmarks are kept by chapter; the column (`items`, `columnItems`, `chapterNotes`,
/// `bookmarkVerses`) describes `chapter`, the open chapter.
/// Holds value copies for the views and the SwiftData objects privately; every mutation goes
/// through `MarkupStore` and reloads.
@MainActor @Observable
public final class MarkupModel {
    public static let showNotelessHighlightsKey = "showNotelessHighlights"
    /// How long an empty highlight note is left alone before `reload()` sweeps it: one being
    /// typed on another device can arrive here empty, and must not be deleted under the writer.
    public static let emptyNoteSweepAge: TimeInterval = 86_400

    /// The open chapter, which the column describes.
    public private(set) var chapter: ChapterLocation?
    public private(set) var translationID: String = ""
    /// The loaded book and its loaded chapters; nil before a load (or after a load of no chapter).
    public private(set) var book: String?
    public private(set) var chapters: ClosedRange<Int>?
    /// The loaded highlights, by chapter; every loaded chapter has an entry.
    public private(set) var itemsByChapter: [Int: [MarkupItem]] = [:]
    /// The loaded bookmarked verses, by chapter; every loaded chapter has an entry.
    public private(set) var bookmarksByChapter: [Int: [Int]] = [:]
    /// The open chapter's highlights.
    public var items: [MarkupItem] { chapter.flatMap { itemsByChapter[$0.chapter] } ?? [] }
    /// The open chapter's bookmarked verses.
    public var bookmarkVerses: [Int] { chapter.flatMap { bookmarksByChapter[$0.chapter] } ?? [] }
    public private(set) var colorChips: [ColorChip] = []
    public private(set) var columnItems: [NotesColumnItem] = []
    /// The open chapter's chapter notes.
    public var chapterNotes: [NoteCard] { chapter.flatMap { chapterNotesByChapter[$0.chapter] } ?? [] }
    /// The loaded notes, by chapter: each chapter's chapter notes, then its highlights' notes in
    /// highlight order (the column's order).
    public var notesByChapter: [Int: [NoteCard]] {
        var notes = chapterNotesByChapter
        for (chapter, rows) in rowsByChapter {
            notes[chapter, default: []] += rows.compactMap(\.note)
        }
        return notes
    }
    public private(set) var selectedHighlightIDs: Set<UUID> = []
    public var outlinedHighlightID: UUID?
    /// The note open in the editor. A sitting (spec 4.3) begins whenever this becomes a note's id
    /// and ends whenever it stops being it, so every save of one edit names the version the editor
    /// opened with, and the store's settle, which skips a note with a sitting open, reaches it again.
    public var editingNoteID: UUID? {
        didSet { if editingNoteID != oldValue { moveSitting() } }
    }
    /// A compact row shown as a draft card (empty editor, no note yet).
    public private(set) var expandedHighlightID: UUID?
    /// Bumped whenever editing starts, so the note editor takes keyboard focus with the insertion
    /// point at the end of the body.
    public private(set) var editorFocusRequest = 0
    /// Bumped when a choice or an append changed the text of the note open in the editor
    /// (`reloadEditor(noteID:)`): the editor then reloads its draft from the note's card.
    public private(set) var editorReloadRequest = 0
    public var isAddColorSheetShown = false
    /// The selection "Add Color…" was chosen for; the sheet applies the new color to it.
    public var pendingColorReport: SelectionReport?
    /// The selection while text is selected (a caret is none), for the toolbar's and ⇧⌘A's
    /// "ask about what is selected".
    public private(set) var currentSelection: SelectionReport?
    /// Set by the app when the study assistant is available; the context menu's Ask About This
    /// Passage calls it.
    public var onAskAboutPassage: ((SelectionReport) -> Void)?
    /// Set by the app: Compare Translations and Cross-References (the menus, C and R) ask for
    /// their panel with the selection. While nil the two menu items are disabled and C and R do nothing.
    public var onVersePanel: ((VersePanelKind, SelectionReport) -> Void)?
    /// Set by the app: `addNote(to:)` calls it once the note exists, so the notes column (with
    /// the note's editor) shows.
    public var onShowNotesColumn: (() -> Void)?
    /// Set by the app: called once an edit's sitting has ended, whose settle may have kept the
    /// draft as a version; the versions model reloads, so an open versions view shows it.
    @ObservationIgnored public var onSittingEnd: (() -> Void)?
    /// Bumped when the reader finishes a note's edit (⌘Return, Return or Esc in the editor), never
    /// for a blur: the reader's text takes the keyboard back.
    public private(set) var noteFinishCount = 0
    /// A plain sentence for the reader when a change could not be saved or a chapter's markup
    /// could not be read; the technical detail goes to the log. Stays set until `clearError()`.
    public private(set) var lastError: String?
    /// The window's undo manager. Deletes register an undo here, so ⌘Z puts a deleted note,
    /// highlight or bookmark back exactly.
    public var undoManager: UndoManager?
    /// Mirrors `UserDefaults` under `showNotelessHighlightsKey` (default true).
    public var showNotelessHighlights: Bool {
        didSet {
            defaults.set(showNotelessHighlights, forKey: Self.showNotelessHighlightsKey)
            rebuildColumn()
        }
    }

    private let store: MarkupStore
    private let defaults: UserDefaults
    /// The clock the empty-note sweep measures age against.
    private let now: () -> Date
    /// A focus request for a chapter that is not loaded yet (Notes browser, palette); `load` consumes it.
    private var pendingFocus: MarkupTarget?
    /// The note to open in the editor once `pendingFocus` is applied (the assistant's Show Note).
    private var pendingEditNoteID: UUID?
    /// The book reader's layout, for `bookDecorations`.
    private var bookLayout: BookLayout?
    /// The loaded highlights as they stood at the last reload, by chapter, as values: with sync
    /// a record can be deleted elsewhere at any moment, and reading a stored object whose record
    /// is gone traps, so nothing here holds one between reloads. Actions fetch theirs by uuid.
    private var rowsByChapter: [Int: [HighlightRow]] = [:]
    /// The loaded chapter notes, by chapter.
    private var chapterNotesByChapter: [Int: [NoteCard]] = [:]
    /// Each note's count of kept versions as the last reload read it; a note with none has no entry.
    private var keptCounts: [UUID: Int] = [:]
    /// The editor's sitting, on `editingNoteID`'s note.
    @ObservationIgnored private var sitting: NoteSitting?
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "markup")

    public init(store: MarkupStore, defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.defaults = defaults
        self.now = now
        showNotelessHighlights = Self.storedShowNoteless(defaults)
    }

    private static func storedShowNoteless(_ defaults: UserDefaults) -> Bool {
        defaults.object(forKey: showNotelessHighlightsKey) == nil ? true : defaults.bool(forKey: showNotelessHighlightsKey)
    }

    // MARK: - Derived

    /// The loaded highlights and bookmarks mapped onto the book layout (`setLayout`), plus the
    /// outlined highlight: the book reader's decorations. None without a layout of the loaded book.
    public var bookDecorations: BookDecorations {
        guard let bookLayout, bookLayout.id.book == book else { return .none }
        return BookDecorations.build(itemsByChapter: itemsByChapter, bookmarksByChapter: bookmarksByChapter,
                                     outlinedID: outlinedHighlightID, viewingTranslationID: translationID, layout: bookLayout)
    }

    // MARK: - Loading

    /// Nothing to show (the translation lacks the chapter being read): the markup empties. An
    /// edit ends (the delete-when-empty rule, since the editor goes with the text) and the
    /// selection, the outline and the layout clear; `follow` loads the chapter again once there is
    /// one to show.
    public func clear(translationID: String) {
        if let editing = editingNoteID { endEditing(noteID: editing) }
        bookLayout = nil
        clearInteraction()
        book = nil
        chapters = nil
        chapter = nil
        self.translationID = translationID
        reload()
    }

    /// The book reader's load: the markup of `chapters` of `book` (the reader's layout: the open
    /// chapter), the column on `chapterInView`. A new book or translation ends an edit and clears
    /// the selection, the outline and the layout (`setLayout` sets the new one); the same book with
    /// other chapters keeps them, and an edit continues unless its chapter is no longer loaded.
    /// While a note is being edited the column stays on its chapter.
    public func load(book: String, chapters: ClosedRange<Int>, chapterInView: ChapterLocation, translationID: String) {
        if book != self.book || translationID != self.translationID {
            if let editing = editingNoteID { endEditing(noteID: editing) }
            bookLayout = nil
            clearInteraction()
        } else if let editing = editingNoteID, let noteChapter = loadedChapter(ofNote: editing), !chapters.contains(noteChapter) {
            endEditing(noteID: editing)
        }
        loadChapters(book: book, chapters: chapters, chapterInView: chapterInView, translationID: translationID)
    }

    /// The book reader's layout of the loaded chapter, for `bookDecorations`; nil when there is none yet.
    public func setLayout(_ layout: BookLayout?) {
        bookLayout = layout
    }

    /// The book reader's wiring in one place: the markup of the open chapter, `location`, mapped
    /// onto `layout` (the document's, which shows that one chapter). It loads the chapter and hands
    /// over the layout when the model does not hold exactly that layout's: a new chapter, book,
    /// translation or typography, or after `clear(translationID:)` emptied it while the document
    /// kept its layout. Otherwise the column stays on it. A location the layout does not show (a
    /// navigation the document has not caught up with) changes nothing: the column stays on the
    /// page's chapter until the layout's own change loads the new one. Without a location, the
    /// layout's chapter is the open one.
    public func follow(_ location: ChapterLocation?, in layout: BookLayout?) {
        guard let layout else {
            setLayout(nil)
            if let location { setChapterInView(location) }
            return
        }
        let open = location ?? ChapterLocation(book: layout.id.book, chapter: layout.chapters.lowerBound)
        guard open.book == layout.id.book, layout.chapters.contains(open.chapter) else { return }
        let holdsLayout = bookLayout?.id == layout.id && book == layout.id.book && chapters == layout.chapters
            && translationID == layout.id.translationID
        if holdsLayout {
            // The phone's Notes in This Chapter puts the column back on the open chapter this way.
            setChapterInView(open)
            return
        }
        load(book: layout.id.book, chapters: layout.chapters, chapterInView: open, translationID: layout.id.translationID)
        setLayout(layout)
    }

    /// The column shows `location`, a loaded chapter (the open one, or a chapter-note mark's).
    /// The selection, the outline and an edit stay; a draft card closes (Ruling R10). While a note
    /// is being edited the column stays on the note's chapter. A chapter of another book (a stale
    /// report) is ignored.
    public func setChapterInView(_ location: ChapterLocation) {
        guard location.book == book, editingNoteID == nil else { return }
        moveColumn(to: location)
    }

    /// A chapter-note mark of `chapter` was tapped (the one on the opening line): the column, and
    /// Notes in This Chapter on the phone, shows that loaded chapter, under `setChapterInView`'s
    /// rules (during an edit the column keeps the note). A chapter not loaded is ignored.
    public func showChapterNotes(chapter: Int) {
        guard let book, chapters?.contains(chapter) == true else { return }
        setChapterInView(ChapterLocation(book: book, chapter: chapter))
    }

    /// The column shows `location`. A draft card (an expanded compact row) belongs to the chapter
    /// the column showed: it closes, so it does not reopen when the reader comes back.
    private func moveColumn(to location: ChapterLocation) {
        guard location != chapter else { return }
        chapter = location
        expandedHighlightID = nil
        rebuildColumn()
    }

    private func loadChapters(book: String, chapters: ClosedRange<Int>, chapterInView: ChapterLocation, translationID: String) {
        self.book = book
        self.chapters = chapters
        self.translationID = translationID
        // An edit that goes on keeps the column on its note's chapter, which is still loaded.
        // Before the reload: a draft card of the chapter the column leaves closes (Ruling R10).
        if editingNoteID == nil { moveColumn(to: chapterInView) }
        reload()
        if let pending = pendingFocus, matchesLoadedChapter(pending) {
            pendingFocus = nil
            applyFocus(pending)
            if let noteID = pendingEditNoteID {
                pendingEditNoteID = nil
                beginEditing(noteID: noteID)
            }
        }
    }

    /// What leaving the text clears: the selection, the outline, an edit and a draft card.
    private func clearInteraction() {
        selectedHighlightIDs = []
        outlinedHighlightID = nil
        editingNoteID = nil
        expandedHighlightID = nil
        currentSelection = nil
    }

    /// The column shows loaded `chapter`, at once (an edit is starting there).
    private func showInColumn(chapter: Int) {
        guard let book, chapters?.contains(chapter) == true else { return }
        let location = ChapterLocation(book: book, chapter: chapter)
        guard location != self.chapter else { return }
        self.chapter = location
        rebuildColumn()
    }

    /// Selects and outlines the target's highlight as a card click does, now when its chapter is
    /// loaded, otherwise once `load` brings that chapter in; the column shows the
    /// target's chapter. A target without a highlight (bookmark, chapter note) clears the
    /// selection. A highlight no longer present is dropped.
    public func focusWhenLoaded(_ target: MarkupTarget) {
        pendingEditNoteID = nil
        if matchesLoadedChapter(target) {
            pendingFocus = nil
            applyFocus(target)
        } else {
            pendingFocus = target
        }
    }

    /// As `focusWhenLoaded`, and the note then opens in the editor: the assistant's Show Note for
    /// a note in a chapter (or translation) other than the ones loaded, whose `load` would
    /// otherwise clear an edit begun before it.
    public func editWhenLoaded(noteID: UUID, target: MarkupTarget) {
        focusWhenLoaded(target)
        if matchesLoadedChapter(target) {
            beginEditing(noteID: noteID)
        } else {
            pendingEditNoteID = noteID
        }
    }

    /// Whether the target's book is the one loaded, its chapter is loaded, and its
    /// translation (or the current one) is the one loaded.
    public func isLoaded(_ target: MarkupTarget) -> Bool {
        matchesLoadedChapter(target)
    }

    private func matchesLoadedChapter(_ target: MarkupTarget) -> Bool {
        target.location.book == book && chapters?.contains(target.location.chapter) == true
            && (target.translationID ?? translationID) == translationID
    }

    private func applyFocus(_ target: MarkupTarget) {
        setChapterInView(target.location)
        if let id = target.highlightID, isLoaded(highlightID: id) {
            focus(highlightID: id)
        } else {
            selectedHighlightIDs = []
            outlinedHighlightID = nil
        }
    }

    /// Re-queries the store for the loaded chapters (one fetch each of highlights, notes and bookmarks);
    /// also picks up a settings change, sweeps empty notes left behind by a quit mid-edit once
    /// they are a day old (the one being edited here is kept, and a younger one may be a note
    /// someone is still typing on another device), and closes the editor when its note was
    /// deleted elsewhere.
    public func reload() {
        let stored = Self.storedShowNoteless(defaults)
        if stored != showNotelessHighlights { showNotelessHighlights = stored }
        guard let book, let chapters else {
            rowsByChapter = [:]; chapterNotesByChapter = [:]; itemsByChapter = [:]; bookmarksByChapter = [:]
            colorChips = []; columnItems = []
            return
        }
        attempt(failure: Self.loadFailure) {
            let current = now()
            if let editing = editingNoteID, try store.note(id: editing) == nil { editingNoteID = nil }
            keptCounts = try store.keptVersionCounts()
            let colors = try store.colors()
            colorChips = colors.map { ColorChip(id: $0.uuid, name: $0.name, color: MarkupColor(lightHex: $0.lightHex, darkHex: $0.darkHex)) }
            // One fetch of each kind for the loaded chapters, grouped by chapter.
            var notes = try store.notes(inBook: book, chapters: chapters)
            let swept = notes.filter { note in
                note.uuid != editingNoteID && note.scope == .highlight && note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && current.timeIntervalSince(note.modifiedAt) > Self.emptyNoteSweepAge
            }
            if !swept.isEmpty {
                for note in swept { try store.deleteNote(note) }
                notes = try store.notes(inBook: book, chapters: chapters)
            }
            // Every loaded chapter has an entry, empty or not.
            let empty = Dictionary(uniqueKeysWithValues: chapters.map { ($0, [Int]()) })
            var items = empty.mapValues { _ in [MarkupItem]() }, rows = empty.mapValues { _ in [HighlightRow]() }
            var chapterNotes = empty.mapValues { _ in [NoteCard]() }, bookmarks = empty
            for highlight in try store.highlights(inBook: book, chapters: chapters) {
                items[highlight.chapter, default: []].append(MarkupItem(highlight: highlight, colors: colors))
                rows[highlight.chapter, default: []].append(HighlightRow(
                    id: highlight.uuid,
                    referenceString: MarkupReference.string(book: highlight.book, chapter: highlight.chapter, verse: highlight.verse, endVerse: highlight.endVerse),
                    quotedText: highlight.quotedText,
                    modifiedAt: highlight.modifiedAt,
                    colorID: highlight.colorID,
                    note: highlight.note.map(card(for:))))
            }
            for note in notes where note.scope == .chapter {
                chapterNotes[note.chapter, default: []].append(card(for: note))
            }
            for bookmark in try store.bookmarks(inBook: book, chapters: chapters) {
                bookmarks[bookmark.chapter, default: []].append(bookmark.verse)
            }
            itemsByChapter = items
            bookmarksByChapter = bookmarks
            rowsByChapter = rows
            chapterNotesByChapter = chapterNotes
        }
        if let expanded = expandedHighlightID, !isLoaded(highlightID: expanded) { expandedHighlightID = nil }
        rebuildColumn()
    }

    private func rebuildColumn() {
        var column: [NotesColumnItem] = chapterNotes.map { .note($0) }
        for row in chapter.flatMap({ rowsByChapter[$0.chapter] }) ?? [] {
            if let note = row.note {
                column.append(.note(note))
            } else if row.id == expandedHighlightID {
                column.append(.note(NoteCard(
                    id: row.id,
                    highlightID: row.id,
                    referenceString: row.referenceString,
                    quotedText: row.quotedText,
                    body: "",
                    modifiedAt: row.modifiedAt,
                    color: markupColor(for: row.colorID),
                    colorID: row.colorID,
                    isChapterNote: false,
                    isDraft: true)))
            } else if showNotelessHighlights {
                column.append(.compactHighlight(CompactRow(
                    id: row.id,
                    referenceString: row.referenceString,
                    quotedText: row.quotedText,
                    color: markupColor(for: row.colorID),
                    colorID: row.colorID)))
            }
        }
        columnItems = column
    }

    /// Only for an object fetched just now (in `reload`, or by an action that fetched it).
    private func card(for note: Note) -> NoteCard {
        let isChapter = note.scope == .chapter
        return NoteCard(
            id: note.uuid,
            highlightID: note.highlight?.uuid,
            referenceString: MarkupReference.string(book: note.book, chapter: note.chapter, verse: isChapter ? nil : note.verse, endVerse: note.endVerse),
            quotedText: note.quotedText,
            body: note.body,
            modifiedAt: note.modifiedAt,
            color: markupColor(for: note.highlight?.colorID),
            colorID: note.highlight?.colorID,
            isChapterNote: isChapter,
            versionCount: 1 + keptCounts[note.uuid, default: 0])
    }

    /// A missing color (deleted, or not yet synced) is none: the highlight draws uncolored.
    private func markupColor(for id: UUID?) -> MarkupColor? {
        guard let id else { return nil }
        return colorChips.first { $0.id == id }?.color
    }

    // MARK: - Selection

    /// A caret inside a highlight outlines that highlight (no text-selection color hides its own
    /// color); a drag or a caret elsewhere clears the outline.
    public func setSelection(_ report: SelectionReport?) {
        currentSelection = report.flatMap { $0.range.length > 0 ? $0 : nil }
        selectedHighlightIDs = Set(report?.highlightIDs ?? [])
        let caretOutline = report.flatMap { $0.range.length == 0 ? $0.primaryHighlightID : nil }
        if outlinedHighlightID != caretOutline { outlinedHighlightID = caretOutline }
        // A click in the text away from a draft card closes the draft.
        if let expanded = expandedHighlightID, !selectedHighlightIDs.contains(expanded) {
            expandedHighlightID = nil
            rebuildColumn()
        }
    }

    /// The highlight the selection lies inside (Ruling 5), including one made in another
    /// translation (drawn on the whole verse); when several contain it (overlapping or nested
    /// highlights), the innermost, which is the one the reader is pointing at.
    private func singleHighlight(for report: SelectionReport) -> HighlightRow? {
        if let primary = report.primaryHighlightID, let row = loadedRow(id: primary) {
            return row
        }
        // The decorations the report's range was measured against.
        let decorations = bookDecorations.highlights
        let containing = report.highlightIDs.compactMap { id -> RangeDecoration? in
            guard let decoration = decorations.decoration(id: id),
                  decoration.range.location <= report.range.location, NSMaxRange(report.range) <= NSMaxRange(decoration.range)
            else { return nil }
            return decoration
        }
        guard let innermost = containing.min(by: { $0.range.length < $1.range.length }) else { return nil }
        return loadedRow(id: innermost.id)
    }

    /// The highlight under the selection as the store has it now: nil when there is none, or
    /// when it was deleted (here or on another device) since the last reload.
    private func storedHighlight(for report: SelectionReport) throws -> Highlight? {
        guard let single = singleHighlight(for: report) else { return nil }
        return try store.highlight(id: single.id)
    }

    /// Inside a highlight the menu always offers recoloring (swatches and No color), its note,
    /// and Remove Highlight; outside, swatches and Add Note create a new one.
    public func menuItems(for report: SelectionReport) -> [MarkupMenuItem] {
        let single = singleHighlight(for: report)
        var items: [MarkupMenuItem] = [
            .swatches(colorChips, current: single?.colorID),
            .addColor,
        ]
        if let single { items.append(.noColor(isCurrent: single.colorID == nil)) }
        items.append(.addNote(existing: single?.note != nil))
        if single != nil { items.append(.removeHighlight) }
        let bookmarked = bookmarksByChapter[report.selection.chapter]?.contains(report.selection.verse) ?? false
        items.append(.bookmark(verse: report.selection.verse, isSet: bookmarked))
        items.append(contentsOf: [.compareTranslations, .crossReferences, .copy, .copyWithReference, .copyLink, .share, .askAboutPassage])
        return items
    }

    // MARK: - Menu actions

    /// Colors the highlight under the selection, or creates one; returns the highlight touched.
    /// A highlight deleted elsewhere since the last reload is not there to color, so the text,
    /// now unhighlighted, gets a new one.
    @discardableResult
    public func applyColor(_ colorID: UUID, to report: SelectionReport) -> UUID? {
        var touched: UUID?
        attempt {
            if let single = try storedHighlight(for: report) {
                try store.setColor(colorID, on: single)
                touched = single.uuid
            } else {
                touched = try addHighlight(from: report, colorID: colorID).uuid
            }
        }
        reload()
        return touched
    }

    @discardableResult
    public func addColorAndApply(name: String, lightHex: String, darkHex: String, to report: SelectionReport) -> UUID? {
        var id: UUID?
        attempt { id = try store.addColor(name: name, lightHex: lightHex, darkHex: darkHex).uuid }
        guard let id else { reload(); return nil }
        return applyColor(id, to: report)
    }

    /// Opens the note of the highlight under the selection, creating it (and a colorless anchor
    /// when there is no highlight, or it was deleted elsewhere) as needed, then starts editing it;
    /// the column shows the selection's chapter.
    public func addNote(to report: SelectionReport) {
        var noteID: UUID?
        attempt {
            if let single = try storedHighlight(for: report) {
                noteID = try (single.note ?? store.addNote(to: single, body: "")).uuid
            } else {
                let highlight = try addHighlight(from: report, colorID: nil)
                noteID = try store.addNote(to: highlight, body: "").uuid
            }
        }
        if noteID != nil {
            showInColumn(chapter: report.selection.chapter)
            onShowNotesColumn?()
        }
        // Before the reload, whose sweep of empty notes spares the one being edited.
        editingNoteID = noteID
        editorFocusRequest += 1
        reload()
    }

    /// Deletes the highlight under the selection, note included (a row's delete removes a note
    /// alone). Undoable.
    public func removeHighlight(in report: SelectionReport) {
        guard let single = singleHighlight(for: report) else { return }
        deleteHighlight(id: single.id)
    }

    /// "No color": underline only; a noteless highlight is then deleted (delete-when-empty).
    public func clearColor(in report: SelectionReport) {
        guard let single = singleHighlight(for: report) else { return }
        setColor(nil, highlightID: single.id)
    }

    /// Recolor (or uncolor) one highlight, from a row's color dot; it stays selected and
    /// outlined so the change is visible at once. Uncoloring a highlight without a note deletes
    /// it, and that delete is undoable.
    public func setColor(_ colorID: UUID?, highlightID: UUID) {
        guard isLoaded(highlightID: highlightID), let highlight = storedHighlight(id: highlightID) else { return }
        let before = HighlightSnapshot(highlight)
        attempt { try store.setColor(colorID, on: highlight) }
        if colorID == nil, before.note == nil, (try? store.highlight(id: highlightID)) == nil {
            registerUndo(restoring: .highlight(before))
        }
        reload()
        if isLoaded(highlightID: highlightID) { focus(highlightID: highlightID) }
    }

    /// Moves a loaded highlight, in this translation, onto the report's words (the pen's
    /// handles); its color and note stay, and it stays selected and outlined. Undoable: the undo
    /// puts the old range back, and its redo the new one.
    public func resizeHighlight(id: UUID, to report: SelectionReport) {
        guard isLoaded(highlightID: id), let highlight = storedHighlight(id: id),
              highlight.translationID == translationID
        else { return }
        let before = TextSelection(book: highlight.book, chapter: highlight.chapter, verse: highlight.verse, endVerse: highlight.endVerse,
                                   startOffset: highlight.startOffset, endOffset: highlight.endOffset, quotedText: highlight.quotedText)
        guard before != report.selection else { return }
        moveHighlight(id: id, from: before, to: report.selection)
    }

    /// Writes `selection` onto the highlight and registers the move back to `previous`.
    private func moveHighlight(id: UUID, from previous: TextSelection, to selection: TextSelection) {
        var moved = false
        attempt {
            try store.updateRange(highlightID: id, selection: selection)
            moved = true
        }
        reload()
        if isLoaded(highlightID: id) { focus(highlightID: id) }
        guard moved, let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            // By uuid, so it works from another chapter too; a highlight deleted since stays gone.
            guard model.storedHighlight(id: id) != nil else { return }
            model.moveHighlight(id: id, from: selection, to: previous)
        }
        undoManager.setActionName(Self.resizeActionName)
    }

    static let resizeActionName = "Resize Highlight"

    public func toggleBookmark(for report: SelectionReport) {
        attempt { try store.toggleBookmark(at: VerseLocation(book: report.selection.book, chapter: report.selection.chapter, verse: report.selection.verse)) }
        reload()
    }

    public func copyText(for report: SelectionReport) -> String {
        report.selection.quotedText
    }

    public func copyWithReference(for report: SelectionReport) -> String {
        report.selection.copyWithReference(translationID: translationID)
    }

    /// The link to the selection's verses, with no translation: it names a passage, not an edition.
    public func passageLink(for report: SelectionReport) -> PassageLink {
        PassageLink(reference: report.selection.reference)
    }

    public func shareText(for report: SelectionReport) -> String {
        copyWithReference(for: report)
    }

    // MARK: - Column actions

    /// Opens a loaded note in the editor; the column shows the note's chapter.
    public func beginEditing(noteID: UUID) {
        if let chapter = loadedChapter(ofNote: noteID) { showInColumn(chapter: chapter) }
        editingNoteID = noteID
        editorFocusRequest += 1
    }

    /// A click on a compact row: focuses the highlight and shows it as a draft card whose editor
    /// is empty. No note exists until `beginEditingDraft` (a click into the field).
    public func expandCompactRow(highlightID: UUID) {
        guard isLoaded(highlightID: highlightID), storedHighlight(id: highlightID) != nil else { return }
        expandedHighlightID = highlightID
        focus(highlightID: highlightID)
        rebuildColumn()
    }

    /// The reader clicked into a draft card's field: create the note and start editing it.
    /// When the highlight was deleted elsewhere meanwhile, the draft just closes.
    public func beginEditingDraft(highlightID: UUID) {
        guard isLoaded(highlightID: highlightID), let highlight = storedHighlight(id: highlightID) else {
            if expandedHighlightID == highlightID {
                expandedHighlightID = nil
                rebuildColumn()
            }
            return
        }
        var noteID: UUID?
        attempt { noteID = try (highlight.note ?? store.addNote(to: highlight, body: "")).uuid }
        expandedHighlightID = nil
        editingNoteID = noteID
        editorFocusRequest += 1
        reload()
    }

    /// Every keystroke's save; in the editor's sitting when it is this note's.
    public func updateNoteBody(noteID: UUID, body: String) {
        guard let note = storedNote(id: noteID) else { return }
        attempt { try store.updateNote(note, body: body, sitting: sitting?.noteID == noteID ? sitting : nil) }
        let card = card(for: note)
        for (chapter, notes) in chapterNotesByChapter {
            if let index = notes.firstIndex(where: { $0.id == noteID }) { chapterNotesByChapter[chapter]?[index] = card }
        }
        for (chapter, rows) in rowsByChapter {
            if let index = rows.firstIndex(where: { $0.note?.id == noteID }) { rowsByChapter[chapter]?[index].note = card }
        }
        rebuildColumn()
    }

    /// The editor's own finish (⌘Return, Return or Esc), after `endEditing`.
    public func noteFinished() {
        noteFinishCount += 1
    }

    /// Ends editing; an empty note is deleted, and with it a colorless anchor. The sitting ends
    /// first, then the cards reload, so a draft kept as it ends shows its count at once.
    public func endEditing(noteID: UUID) {
        if editingNoteID == noteID { editingNoteID = nil }
        guard let note = storedNote(id: noteID) else { return }
        if note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attempt { try store.deleteNote(note) }
        }
        reload()
    }

    /// Ends the edit open in any editor, as Done would: its sitting closes and the text is in the
    /// store, so nothing is waiting when something else (an import) saves or rolls the store back.
    public func endOpenEdit() {
        if let editing = editingNoteID { endEditing(noteID: editing) }
    }

    /// The notes column went away (hidden, or the assistant took the inspector): the edit open in
    /// it ends as Done would, so its sitting cannot stay open with no editor to end it. Never a
    /// row's disappearance: the rows come and go as the column scrolls.
    public func notesColumnDidHide() {
        if let editing = editingNoteID { endEditing(noteID: editing) }
    }

    /// Deletes a note (and a colorless anchor with it). Undoable: ⌘Z puts both back.
    public func deleteNote(noteID: UUID) {
        if editingNoteID == noteID { editingNoteID = nil }
        guard let note = storedNote(id: noteID) else { return }
        deleteUndoably(.note(NoteSnapshot(note), anchor: nil))
    }

    /// Deletes a highlight with its note. Undoable.
    public func deleteHighlight(id: UUID) {
        guard isLoaded(highlightID: id), let highlight = storedHighlight(id: id) else { return }
        if editingNoteID == highlight.note?.uuid { editingNoteID = nil }
        deleteUndoably(.highlight(HighlightSnapshot(highlight)))
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: - Sittings

    /// A choice (Use This One, Keep Both in the Note) or an append (Add as Note) changed the text
    /// of the note open in the editor: the editor's sitting ends, the cards reload, a new sitting
    /// begins on the note's text and the editor reloads its draft from it (`editorReloadRequest`),
    /// so its next save cannot write the old draft over that text. Nothing for any other note.
    public func reloadEditor(noteID: UUID) {
        guard editingNoteID == noteID else { return }
        endSitting()
        reload()
        // The reload closes the editor when the note is gone.
        guard editingNoteID == noteID else { return }
        beginSitting(noteID: noteID)
        editorReloadRequest += 1
    }

    /// `editingNoteID` changed: the sitting on the note it left ends, and one begins on its new note.
    private func moveSitting() {
        if sitting != nil, sitting?.noteID != editingNoteID { endSitting() }
        if let noteID = editingNoteID, sitting == nil { beginSitting(noteID: noteID) }
    }

    private func beginSitting(noteID: UUID) {
        attempt { sitting = try store.beginSitting(noteID: noteID) }
    }

    private func endSitting() {
        guard let sitting else { return }
        self.sitting = nil
        store.endSitting(sitting)
        onSittingEnd?()
    }

    // MARK: - Undo

    /// Deletes through the store, which captures the record as it was, and registers the undo.
    private func deleteUndoably(_ deletion: MarkupDeletion) {
        var captured: MarkupDeletion?
        attempt { captured = try store.delete(deletion) }
        if let captured { registerUndo(restoring: captured) }
        reload()
    }

    /// The undo puts the record back and lights it; its redo deletes it again, which registers
    /// the next undo, so ⌘Z and ⇧⌘Z can alternate indefinitely.
    private func registerUndo(restoring deletion: MarkupDeletion) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            model.attempt { try model.store.restore(deletion) }
            model.reload()
            if let id = deletion.highlightID, model.isLoaded(highlightID: id) {
                model.focus(highlightID: id)
            }
            model.undoManager?.registerUndo(withTarget: model) { model in
                model.deleteUndoably(deletion)
            }
            model.undoManager?.setActionName(deletion.actionName)
        }
        undoManager.setActionName(deletion.actionName)
    }

    /// The reader's selection went away with its text (another chapter, translation or book took
    /// its place): what it selected is forgotten. An outline stays, with its lit card, since a
    /// jump to a highlight in the new chapter may have set it first; with none, the old
    /// selection's highlights are let go.
    public func forgetSelection() {
        currentSelection = nil
        if outlinedHighlightID == nil, !selectedHighlightIDs.isEmpty { selectedHighlightIDs = [] }
    }

    /// Lights the highlight's card, outlines the highlight, and the text view scrolls to it.
    public func focus(highlightID: UUID) {
        selectedHighlightIDs = [highlightID]
        outlinedHighlightID = highlightID
    }

    /// The note on a loaded highlight; nil when it has none.
    public func noteID(forHighlight highlightID: UUID) -> UUID? {
        rowsByChapter.values.lazy.flatMap { $0 }.first { $0.id == highlightID }?.note?.id
    }

    /// What the selection menu would act on for a loaded highlight, as if it were selected: its
    /// range in the reader's layout. The note sheet's actions (spec 3.1) use it. Nil when the
    /// highlight or the layout is not loaded.
    public func report(forHighlight highlightID: UUID) -> SelectionReport? {
        guard let layout = bookLayout, let decoration = bookDecorations.decoration(id: highlightID) else { return nil }
        return ReaderTextLogic.report(for: decoration.range, layout: layout, decorations: bookDecorations)
    }

    /// The highlight a loaded note is on; nil for a chapter note, a note not loaded, or one that
    /// is gone.
    public func highlightID(forNote noteID: UUID) -> UUID? {
        guard let id = rowsByChapter.values.lazy.flatMap({ $0 }).first(where: { $0.note?.id == noteID })?.id, (try? store.note(id: noteID)) != nil else { return nil }
        return id
    }

    /// Every chapter with a highlight, note or bookmark and the colours of its highlights in the
    /// reader's colour order, for the chapter rings. A colour the store no longer has counts as
    /// no colour; a failed read goes to the log and shows no rings.
    public func chapterMarks() -> [ChapterLocation: ChapterMarks] {
        do {
            let colors = try store.colors()
            return try store.chapterColorIDs().mapValues { ids in
                ChapterMarks(colors: colors.filter { ids.contains($0.uuid) }.map { MarkupColor(lightHex: $0.lightHex, darkHex: $0.darkHex) })
            }
        } catch {
            logger.error("Could not read marked chapters: \(error)")
            return [:]
        }
    }

    // MARK: - Private

    /// The highlight's row, when it is loaded.
    private func loadedRow(id: UUID) -> HighlightRow? {
        for rows in rowsByChapter.values {
            if let row = rows.first(where: { $0.id == id }) { return row }
        }
        return nil
    }

    /// Whether the highlight is loaded.
    public func isLoaded(highlightID: UUID) -> Bool {
        loadedRow(id: highlightID) != nil
    }

    /// The loaded chapter a note (on a highlight, or of a chapter) belongs to.
    private func loadedChapter(ofNote noteID: UUID) -> Int? {
        if let (chapter, _) = chapterNotesByChapter.first(where: { $0.value.contains { $0.id == noteID } }) { return chapter }
        return rowsByChapter.first { $0.value.contains { $0.note?.id == noteID } }?.key
    }

    /// The highlight as the store has it now; nil when it is gone (deleted here or elsewhere).
    private func storedHighlight(id: UUID) -> Highlight? {
        var found: Highlight?
        attempt { found = try store.highlight(id: id) }
        return found
    }

    /// The note as the store has it now, when it is a loaded one; nil when it is gone.
    private func storedNote(id: UUID) -> Note? {
        guard loadedChapter(ofNote: id) != nil else { return nil }
        var found: Note?
        attempt { found = try store.note(id: id) }
        return found
    }

    @discardableResult
    private func addHighlight(from report: SelectionReport, colorID: UUID?) throws -> Highlight {
        let s = report.selection
        return try store.addHighlight(
            book: s.book, chapter: s.chapter, verse: s.verse, endVerse: s.endVerse,
            startOffset: s.startOffset, endOffset: s.endOffset,
            translationID: translationID, colorID: colorID, quotedText: s.quotedText)
    }

    static let saveFailure = "Your last change could not be saved. Try it again. If it keeps failing, quit and reopen the app."
    static let loadFailure = "The notes and highlights for this chapter could not be read. Quit and reopen the app to try again."

    /// Runs `work`; a failure leaves `failure` for the reader (until `clearError()`, so a later
    /// success cannot hide it) and the error itself in the log.
    private func attempt(failure: String = saveFailure, _ work: () throws -> Void) {
        do {
            try work()
        } catch {
            lastError = failure
            logger.error("Markup operation failed: \(error)")
        }
    }
}

/// A loaded highlight, and its note's card, as values (`MarkupModel.rowsByChapter`).
private struct HighlightRow {
    let id: UUID
    let referenceString: String
    let quotedText: String
    let modifiedAt: Date
    let colorID: UUID?
    var note: NoteCard?
}

extension MarkupStore {
    /// Moves an existing highlight onto the selection's verses, offsets and quoted text. Here
    /// rather than in ScriptureModel because `TextSelection` belongs to ScriptureUI.
    public func updateRange(highlightID: UUID, selection: TextSelection) throws {
        try updateRange(highlightID: highlightID, verse: selection.verse, endVerse: selection.endVerse,
                        startOffset: selection.startOffset, endOffset: selection.endOffset, quotedText: selection.quotedText)
    }
}

extension MarkupDeletion {
    /// The highlight to light after an undo brings this back.
    var highlightID: UUID? {
        switch self {
        case .note(_, let anchor): anchor?.uuid
        case .highlight(let snapshot): snapshot.uuid
        case .bookmark, .thread, .keptVersion: nil
        }
    }
}
