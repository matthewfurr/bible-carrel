import Foundation
import Observation
import OSLog
import ScriptureData
import ScriptureModel

/// The whole-Bible Notes window's state: every note, highlight, bookmark and conversation as value entries,
/// narrowed by the filter and the search, ordered by the sort, grouped by book when sorted by
/// reference and by day when sorted by date. Every mutation goes through `MarkupStore`, reloads,
/// and tells the reader (`onChange`).
@MainActor @Observable
public final class NotesBrowserModel {
    public static let sortKey = "notesBrowserSort"
    public static let filterKey = "notesBrowserFilter"
    public static let timeFilterKey = "notesBrowserTimeFilter"

    public var sort: NotesBrowserSort {
        didSet {
            defaults.set(sort.rawValue, forKey: Self.sortKey)
            rebuild()
        }
    }
    public var filter: NotesBrowserFilter {
        didSet {
            defaults.set(filter.rawValue, forKey: Self.filterKey)
            rebuild()
        }
    }
    /// Stored on this device only (not a synced preference).
    public var timeFilter: NotesBrowserTimeFilter {
        didSet {
            defaults.set(timeFilter.rawValue, forKey: Self.timeFilterKey)
            applySearch()
        }
    }
    /// Bound to the search field; the view debounces and calls `applySearch()`.
    public var query = ""
    /// Filtered, searched and sorted.
    public private(set) var entries: [NotesBrowserEntry] = []
    /// By book, only when sorted by reference.
    public private(set) var sections: [NotesBrowserSection] = []
    /// By the day each entry was last changed, in the model's calendar, only when sorted by date.
    /// Made in `rebuild()`, so a window left open across midnight keeps its "Today" until then.
    public private(set) var days: [NotesBrowserSection] = []
    /// Everything, before filter and search; a kept version with no note is not counted.
    public private(set) var totalCount = 0
    /// True while a note has a kept version or a kept version's note is gone: the Kept versions
    /// filter is offered only then, and the filter returns to All when it turns false.
    public private(set) var hasKeptVersions = false
    public var selectedID: UUID?
    /// A plain sentence for the reader when a delete or a load failed; stays until `clearError()`.
    public private(set) var lastError: String?
    /// The Notes window's undo manager: a confirmed delete can still be undone with ⌘Z.
    public var undoManager: UndoManager?

    private let store: MarkupStore
    private let defaults: UserDefaults
    private let onChange: () -> Void
    private let now: () -> Date
    /// The days', the time filter's and the row's calendar; the app's follows the reader's time
    /// zone as it changes (`.autoupdatingCurrent`), so a trip moves the days at the next rebuild.
    public let calendar: Calendar
    /// The day headings' and the row's locale; the app's follows the reader's region as it changes.
    public let locale: Locale
    /// The entries matching the current search (or everything), before filter and sort.
    private var searched: [NotesBrowserEntry] = []
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "notes-browser")

    public init(store: MarkupStore, defaults: UserDefaults = .standard, onChange: @escaping () -> Void = {}, now: @escaping () -> Date = { Date() },
                calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.store = store
        self.defaults = defaults
        self.onChange = onChange
        self.now = now
        self.calendar = calendar
        self.locale = locale
        timeFilter = defaults.string(forKey: Self.timeFilterKey).flatMap(NotesBrowserTimeFilter.init(rawValue:)) ?? .anyTime
        sort = defaults.string(forKey: Self.sortKey).flatMap(NotesBrowserSort.init(rawValue:)) ?? .date
        filter = defaults.string(forKey: Self.filterKey).flatMap(NotesBrowserFilter.init(rawValue:)) ?? .all
        reload()
    }

    // MARK: - Loading

    /// Re-fetches everything; call when the window appears and after the reader changes markup.
    public func reload() {
        attempt {
            totalCount = try store.allNotes().count + store.allHighlights().filter { $0.note == nil }.count + store.allBookmarks().count
                + store.chat.allThreads().count
            hasKeptVersions = try !store.keptVersionCounts().isEmpty || !store.orphanVersions().isEmpty
        }
        // Its didSet rebuilds the list, which `applySearch` does again.
        if !hasKeptVersions, filter == .keptVersions { filter = .all }
        applySearch()
    }

    /// Re-runs the store search for `query` and rebuilds the list.
    public func applySearch() {
        attempt {
            searched = try NotesBrowserLoader.entries(store: store, query: query, includingKeptVersions: true)
        }
        rebuild()
    }

    private func rebuild() {
        let now = now()
        let kept = NotesBrowserQuery.filter(NotesBrowserQuery.filter(searched, by: filter), since: timeFilter.cutoff(from: now, calendar: calendar))
        let sorted = NotesBrowserQuery.sort(kept, by: sort)
        entries = sorted
        sections = sort == .reference ? NotesBrowserQuery.sections(sorted) : []
        days = sort == .date ? NotesBrowserQuery.days(sorted, now: now, calendar: calendar, locale: locale) : []
        if let selectedID, !sorted.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
    }

    // MARK: - Selection

    /// The groups the list shows: the books when sorted by reference, the days when sorted by date.
    public var groups: [NotesBrowserSection] {
        sort == .reference ? sections : days
    }

    /// The ids in the order the list shows them, group by group.
    public var visibleIDs: [UUID] {
        groups.flatMap(\.entries).map(\.id)
    }

    /// ↓ (`+1`) or ↑ (`-1`): selects the neighbouring row, stopping at either end; with nothing
    /// selected, the first row going down and the last going up. Returns the new selection.
    @discardableResult
    public func moveSelection(by step: Int) -> UUID? {
        let ids = visibleIDs
        guard !ids.isEmpty else { return nil }
        let target: Int
        if let selectedID, let index = ids.firstIndex(of: selectedID) {
            target = min(max(index + step, 0), ids.count - 1)
        } else {
            target = step >= 0 ? 0 : ids.count - 1
        }
        selectedID = ids[target]
        return selectedID
    }

    // MARK: - Lookups

    public func entry(id: UUID) -> NotesBrowserEntry? {
        searched.first { $0.id == id }
    }

    public func target(for id: UUID) -> MarkupTarget? {
        entry(id: id).map(MarkupTarget.init(entry:))
    }

    // MARK: - Mutation

    /// A note goes with its anchor when nothing else keeps it; a highlight goes with its note.
    /// Undoable through `undoManager`.
    public func delete(id: UUID) {
        guard let entry = entry(id: id) else { return }
        var deletion: MarkupDeletion?
        attempt(failure: Self.deleteFailure) {
            switch entry.kind {
            case .note(let noteID, _):
                if let note = try store.note(id: noteID) { deletion = .note(NoteSnapshot(note), anchor: nil) }
            case .highlight(let highlightID):
                if let highlight = try store.highlight(id: highlightID) { deletion = .highlight(HighlightSnapshot(highlight)) }
            case .bookmark(let bookmarkID):
                if let bookmark = try store.bookmark(id: bookmarkID) { deletion = .bookmark(BookmarkSnapshot(bookmark)) }
            case .thread(let threadID):
                if let thread = try store.chat.thread(id: threadID) { deletion = .thread(ThreadSnapshot(thread)) }
            case .keptVersion(let keptID):
                if let version = try store.orphanVersions().first(where: { $0.uuid == keptID }) { deletion = .keptVersion(version) }
            }
        }
        guard let deletion else { return }
        let before = visibleIDs
        let wasSelected = selectedID == id
        deleteUndoably(deletion)
        // The selection goes to the row that took the deleted row's place, else the last row.
        if wasSelected, selectedID == nil, let index = before.firstIndex(of: id) {
            let after = visibleIDs
            selectedID = after.isEmpty ? nil : after[min(index, after.count - 1)]
        }
    }

    public func clearError() {
        lastError = nil
    }

    private func deleteUndoably(_ deletion: MarkupDeletion) {
        var captured: MarkupDeletion?
        attempt(failure: Self.deleteFailure) { captured = try store.delete(deletion) }
        if let captured, let undoManager {
            undoManager.registerUndo(withTarget: self) { model in
                model.attempt(failure: Self.deleteFailure) { try model.store.restore(captured) }
                model.reload()
                model.onChange()
                model.undoManager?.registerUndo(withTarget: model) { model in model.deleteUndoably(captured) }
                model.undoManager?.setActionName(captured.actionName)
            }
            undoManager.setActionName(captured.actionName)
        }
        reload()
        onChange()
    }

    static let loadFailure = "Your notes could not be read. Quit and reopen the app to try again."
    static let deleteFailure = "That item could not be deleted. Try it again. If it keeps failing, quit and reopen the app."

    private func attempt(failure: String = loadFailure, _ work: () throws -> Void) {
        do {
            try work()
        } catch {
            lastError = failure
            logger.error("Notes browser operation failed: \(error)")
        }
    }
}
