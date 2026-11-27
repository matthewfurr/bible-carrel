import Foundation
import Observation

/// The iPhone app's tabs, in the bar's order: Read, Plan, Notes, Ask. Search is the tab bar's
/// separate search button.
public enum PhoneTab: Hashable, Sendable {
    case read, plan, notes, ask, search
}

/// The phone's screens in the order the edge swipes walk them (Matt, 2026-11-12; Plan joined
/// between Read and Notes in milestone 10): a swipe in from the left edge moves one screen left,
/// Ask → Notes → Plan → Read → Library, and one from the right edge moves back. Search sits
/// outside the chain.
public enum PhoneScreen: Int, CaseIterable, Sendable {
    case library, read, plan, notes, ask
}

/// The screen edge a swipe comes in from.
public enum SwipeEdge: Sendable {
    case left, right
}

/// A page of Settings to open at, rather than its list.
public enum SettingsDestination: Hashable, Sendable {
    /// Settings › Reading: the reader's More Settings….
    case reading
    /// Settings › General: where the Library's dates setting is.
    case general
}

/// Which tab the phone shows and which sheet is over it. Platform-neutral, so it is tested on the Mac.
@MainActor @Observable public final class PhoneShellModel {
    public var tab: PhoneTab = .read
    public var isLibraryShown = false
    public var isSettingsShown = false
    /// The page Settings opens at while it is shown; nil opens its list.
    public var settingsDestination: SettingsDestination?
    /// Open Settings in the Ask sheet over the page: Settings follows once that sheet has gone,
    /// since the root cannot present over it.
    var isSettingsQueued = false
    /// The note being shown.
    public var noteSheet: UUID?
    /// Whether the note sheet opens in its editor: Add Note and Edit Note do; a tap on a note's
    /// mark opens it to read (spec 3.1).
    public var noteSheetStartsEditing = false
    public var isChapterNotesShown = false
    /// A conversation opened over the page.
    public var askSheetThreadID: UUID?
    public var versePreview: VersePreview?
    /// The verse panel (Compare Translations or Cross-References) shown over the page in a sheet.
    public var versePanel: VersePanelRequest?
    /// The panel's Ask, kept while its sheet closes and run once it has gone.
    public var queuedVersePanelAsk: (@MainActor () -> Void)?
    /// The pages pushed inside Search: a person or place opened by name, and what was walked to from it.
    public var searchPath: [PhoneLibraryPage] = []

    public init() {}

    /// The bar's way back from a lookup. One begun in the Library reopens it there: Library on its
    /// page, or Search for a page reached by name (that page lives in Search's stack, `searchPath`,
    /// so the Library keeps no place of it). Any other lookup returns to the page it began on.
    /// The model's own way back shows its front page, which the phone never reads.
    public func returnFromLookup(_ navigation: NavigationModel) {
        let place = navigation.libraryReturn?.place
        navigation.returnFromLookup()
        if let place { reopen(place, navigation) }
    }

    /// ⌘[ with a hardware keyboard: Back through the passages a lookup opened; when it returns from
    /// one begun in the Library, the Library (or Search) reopens on its page, as the bar's button does.
    public func goBack(_ navigation: NavigationModel) {
        let place = navigation.libraryReturn?.place
        navigation.goBack()
        guard let place, navigation.libraryReturn == nil, navigation.libraryPlace != nil else { return }
        reopen(place, navigation)
    }

    /// Shows where a Library lookup has returned to: Library on its page, or Search for a page
    /// reached by name. In Search, as in the Library, the passage Open in Read was on is not part of
    /// the place: the way back comes to the person or place it was opened from.
    private func reopen(_ place: LibraryPlace, _ navigation: NavigationModel) {
        if place.book != nil {
            show(.library)
        } else {
            navigation.libraryPlace = nil
            isLibraryShown = false
            while case .passage? = searchPath.last { searchPath.removeLast() }
            tab = .search
        }
    }

    /// Settings, at its list.
    public func openSettings() {
        settingsDestination = nil
        isSettingsShown = true
    }

    /// The reader menu's More Settings…: Settings, at Reading.
    public func openMoreSettings() {
        settingsDestination = .reading
        isSettingsShown = true
    }

    /// The Library's notice and footnote: Settings, at General.
    public func openGeneralSettings() {
        settingsDestination = .general
        isSettingsShown = true
    }

    /// Settings has gone (Done or a swipe): the next opening starts from its list.
    public func settingsDismissed() {
        isSettingsShown = false
        settingsDestination = nil
    }

    /// The screen in the edge swipes' chain the phone shows, or nil on search.
    public var screen: PhoneScreen? {
        if isLibraryShown { return .library }
        switch tab {
        case .read: return .read
        case .plan: return .plan
        case .notes: return .notes
        case .ask: return .ask
        case .search: return nil
        }
    }

    /// The screen a swipe in from `edge` leads to: the one to the left for the left edge, to the
    /// right for the right edge; nil at either end of the chain and on search.
    public func screen(swipingFrom edge: SwipeEdge) -> PhoneScreen? {
        guard let screen else { return nil }
        return PhoneScreen(rawValue: screen.rawValue + (edge == .left ? -1 : 1))
    }

    /// Shows the note over the page: to read (a tap on its highlight, mark or row), or in its
    /// editor (Add Note, Edit Note).
    public func openNote(_ noteID: UUID, editing: Bool) {
        noteSheetStartsEditing = editing
        noteSheet = noteID
    }

    /// Shows `screen`: Library over the Read tab, or a tab with Library closed.
    public func show(_ screen: PhoneScreen) {
        switch screen {
        case .library:
            tab = .read
            isLibraryShown = true
        case .read:
            isLibraryShown = false
            tab = .read
        case .plan:
            isLibraryShown = false
            tab = .plan
        case .notes:
            isLibraryShown = false
            tab = .notes
        case .ask:
            isLibraryShown = false
            tab = .ask
        }
    }

    /// The selection menu's Compare Translations or Cross-References: the sheet for `request`. An Ask
    /// still queued from an earlier sheet is dropped, so a dismissal it missed cannot send it later.
    public func showVersePanel(_ request: VersePanelRequest) {
        queuedVersePanelAsk = nil
        versePanel = request
    }

    /// Back to the page: the Read tab, with every sheet closed.
    public func showInReader() {
        tab = .read
        isLibraryShown = false
        isSettingsShown = false
        settingsDestination = nil
        noteSheet = nil
        isChapterNotesShown = false
        askSheetThreadID = nil
        versePreview = nil
        versePanel = nil
        queuedVersePanelAsk = nil
    }
}
