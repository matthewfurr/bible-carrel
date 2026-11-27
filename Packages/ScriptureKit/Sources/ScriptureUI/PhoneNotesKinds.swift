import Foundation

/// The phone's "What kind" menu and the mark on its rows (spec 4.1, 4.2): the kinds on offer, the
/// phone's words for them, and what a row says about its versions. Not under `#if os(iOS)`, so its
/// suite runs in both test runs.
public enum PhoneNotesKinds {
    /// The five kinds, then "Kept versions" last, only while something has a kept version or it is
    /// the kind in force (so the menu can show, and leave, what it is on).
    public static func offered(hasKeptVersions: Bool, current: NotesBrowserFilter) -> [NotesBrowserFilter] {
        let five = NotesBrowserFilter.allCases.filter { $0 != .keptVersions }
        return hasKeptVersions || current == .keptVersions ? five + [.keptVersions] : five
    }

    /// The phone's words for the kinds (the design's, not the Mac picker's).
    public static func title(for filter: NotesBrowserFilter) -> String {
        switch filter {
        case .all: "Everything"
        case .notes: "Notes"
        case .highlights: "Highlights"
        case .bookmarks: "Bookmarks"
        case .threads: "Conversations"
        case .keptVersions: "Kept versions"
        }
    }

    /// "2 versions" on a note with kept versions, "Kept version" on a text with no note; else none.
    public static func mark(for entry: NotesBrowserEntry) -> String? {
        switch entry.kind {
        case .note: entry.versionCount > 1 ? VersionText.mark(count: entry.versionCount) : nil
        case .keptVersion: VersionText.orphanMark
        case .highlight, .bookmark, .thread: nil
        }
    }
}
