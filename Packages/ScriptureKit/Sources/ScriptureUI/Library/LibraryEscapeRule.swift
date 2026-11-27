/// When Esc closes the Mac front page's open Library view, as "‹ Contents" does. It is caught for
/// the whole window (a ⌘K choice leaves the keyboard nowhere inside the front page, where an exit
/// command would never arrive), so it stands aside for what has Esc of its own: the toolbar's
/// search field while it holds the keyboard, and the palette. A popover is a window of its own and
/// closes first. With no view open Esc is not taken, so it can still leave full screen.
public enum LibraryEscapeRule {
    public static func closesView(viewOpen: Bool, searchFieldFocused: Bool, paletteShown: Bool) -> Bool {
        viewOpen && !searchFieldFocused && !paletteShown
    }

    /// What a write through the front page's binding to the open view leaves open: the place written while a view
    /// is open; nothing once it is closed, since a write then can only be the going view's, read from the binding's
    /// stand-in (a closed view stays closed).
    public static func writing(_ written: LibraryPlace, over open: LibraryPlace?) -> LibraryPlace? {
        open == nil ? nil : written
    }
}
