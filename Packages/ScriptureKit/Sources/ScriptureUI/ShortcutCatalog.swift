import Foundation

/// What a single key does in the Mac reader while its text has keyboard focus.
public enum ReaderKeyAction: Hashable, Sendable, CaseIterable {
    case nextVerse, previousVerse, extendDown, extendUp
    case color(Int)                       // 1...9
    case noColor, note, bookmark
    case compareTranslations, crossReferences
    case previousChapter, nextChapter
    case clearSelection, showShortcuts

    /// The thirteen plain cases and `color(1)` to `color(9)`.
    public static var allCases: [ReaderKeyAction] {
        [.nextVerse, .previousVerse, .extendDown, .extendUp]
            + (1...9).map(ReaderKeyAction.color)
            + [.noColor, .note, .bookmark, .compareTranslations, .crossReferences, .previousChapter, .nextChapter, .clearSelection, .showShortcuts]
    }
}

/// A bare key: letters lower-cased, `shift` saying whether Shift was held; digits, "?" and the
/// named keys always with `shift` false.
public struct ReaderKeyStroke: Hashable, Sendable {
    public enum Key: Hashable, Sendable { case character(Character), leftArrow, rightArrow, escape }
    public let key: Key
    public let shift: Bool

    public init(_ key: Key, shift: Bool = false) {
        self.key = key
        self.shift = shift
    }
}

/// One row of the shortcuts list: what it does, its keys as keycaps and by name, and the chords
/// it stands for. A row of the reader's single keys also maps each stroke to its action.
public struct Shortcut: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    /// The keycaps as shown; "–" is plain text between caps.
    public let keys: [String]
    /// The keys by name, for VoiceOver.
    public let spoken: String
    /// Each chord in one form, modifiers in the order ⌃⌥⇧⌘.
    public let chords: [String]
    public let readerKeys: [ReaderKeyStroke: ReaderKeyAction]

    init(_ id: String, _ label: String, keys: [String], spoken: String, chords: [String],
         readerKeys: [ReaderKeyStroke: ReaderKeyAction] = [:]) {
        self.id = id
        self.label = label
        self.keys = keys
        self.spoken = spoken
        self.chords = chords
        self.readerKeys = readerKeys
    }
}

public struct ShortcutGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let shortcuts: [Shortcut]
}

/// Every keyboard shortcut in the app, in the groups the shortcuts sheet shows: the menus' own
/// chords and the reader's single keys, which `readerAction(for:)` resolves. Labels are the
/// menus' own names where a menu has the command.
public enum ShortcutCatalog {
    public static let groups: [ShortcutGroup] = [
        ShortcutGroup(id: "go", title: "Go", shortcuts: [
            Shortcut("goToAnything", "Go to anything", keys: ["⌘", "K"], spoken: "Command K", chords: ["⌘K"]),
            Shortcut("backForward", "Back, forward", keys: ["⌘", "[", "]"],
                     spoken: "Command left bracket, Command right bracket", chords: ["⌘[", "⌘]"]),
            Shortcut("chapters", "Previous, next chapter", keys: ["←", "→"], spoken: "Left arrow, Right arrow", chords: ["←", "→"],
                     readerKeys: [ReaderKeyStroke(.leftArrow): .previousChapter, ReaderKeyStroke(.rightArrow): .nextChapter]),
            Shortcut("chaptersAnywhere", "Chapters, from anywhere", keys: ["⌥", "⌘", "←", "→"],
                     spoken: "Option Command left arrow, Option Command right arrow", chords: ["⌥⌘←", "⌥⌘→"]),
            Shortcut("home", "Home", keys: ["⇧", "⌘", "H"], spoken: "Shift Command H", chords: ["⇧⌘H"]),
        ]),
        ShortcutGroup(id: "view", title: "View", shortcuts: [
            Shortcut("textLayout", "Text & Layout", keys: ["⌘", "T"], spoken: "Command T", chords: ["⌘T"]),
            Shortcut("textSize", "Larger, smaller text", keys: ["⌘", "+", "−"], spoken: "Command plus, Command minus",
                     chords: ["⌘+", "⌘-"]),
            Shortcut("notesColumn", "Notes column", keys: ["⌥", "⌘", "N"], spoken: "Option Command N", chords: ["⌥⌘N"]),
            Shortcut("notesBrowser", "Notes browser", keys: ["⇧", "⌘", "N"], spoken: "Shift Command N", chords: ["⇧⌘N"]),
            Shortcut("readingPlan", "Reading plan", keys: ["⌥", "⌘", "P"], spoken: "Option Command P", chords: ["⌥⌘P"]),
            Shortcut("settings", "Settings", keys: ["⌘", ","], spoken: "Command comma", chords: ["⌘,"]),
            Shortcut("keyboardShortcuts", "Keyboard shortcuts", keys: ["⌘", "/", "?"], spoken: "Command slash, or question mark",
                     chords: ["⌘/", "?"], readerKeys: [ReaderKeyStroke(.character("?")): .showShortcuts]),
        ]),
        ShortcutGroup(id: "verses", title: "Verses", shortcuts: [
            Shortcut("nextPreviousVerse", "Next, previous verse", keys: ["J", "K"], spoken: "J, K", chords: ["J", "K"],
                     readerKeys: [ReaderKeyStroke(.character("j")): .nextVerse, ReaderKeyStroke(.character("k")): .previousVerse]),
            Shortcut("extendVerse", "Extend by a verse", keys: ["⇧", "J", "K"], spoken: "Shift J, Shift K", chords: ["⇧J", "⇧K"],
                     readerKeys: [ReaderKeyStroke(.character("j"), shift: true): .extendDown,
                                  ReaderKeyStroke(.character("k"), shift: true): .extendUp]),
            Shortcut("highlight", "Highlight in a color", keys: ["1", "–", "9"], spoken: "1 to 9", chords: (1...9).map(String.init),
                     readerKeys: Dictionary(uniqueKeysWithValues: (1...9).map { (ReaderKeyStroke(.character(Character(String($0)))), .color($0)) })),
            Shortcut("noColor", "No color", keys: ["0"], spoken: "0", chords: ["0"],
                     readerKeys: [ReaderKeyStroke(.character("0")): .noColor]),
            Shortcut("note", "Add or edit note", keys: ["N"], spoken: "N", chords: ["N"],
                     readerKeys: [ReaderKeyStroke(.character("n")): .note]),
            Shortcut("bookmark", "Bookmark", keys: ["B"], spoken: "B", chords: ["B"],
                     readerKeys: [ReaderKeyStroke(.character("b")): .bookmark]),
            Shortcut("compareTranslations", "Compare translations", keys: ["C"], spoken: "C", chords: ["C"],
                     readerKeys: [ReaderKeyStroke(.character("c")): .compareTranslations]),
            Shortcut("crossReferences", "Cross-references", keys: ["R"], spoken: "R", chords: ["R"],
                     readerKeys: [ReaderKeyStroke(.character("r")): .crossReferences]),
            Shortcut("copy", "Copy", keys: ["⌘", "C"], spoken: "Command C", chords: ["⌘C"]),
            Shortcut("clearSelection", "Clear selection", keys: ["esc"], spoken: "Escape", chords: ["esc"],
                     readerKeys: [ReaderKeyStroke(.escape): .clearSelection]),
        ]),
        ShortcutGroup(id: "notesColumn", title: "Notes Column", shortcuts: [
            Shortcut("moveBetweenNotes", "Move between notes", keys: ["↑", "↓"], spoken: "Up arrow, Down arrow", chords: ["↑", "↓"]),
            Shortcut("editFinish", "Edit, finish", keys: ["↩", "⌘", "↩"], spoken: "Return, Command Return", chords: ["↩", "⌘↩"]),
            Shortcut("deleteUndo", "Delete, undo", keys: ["⌫", "⌘", "Z"], spoken: "Delete, Command Z", chords: ["⌫", "⌘Z"]),
            Shortcut("searchNotes", "Search the front page or Notes", keys: ["⌘", "F"], spoken: "Command F", chords: ["⌘F"]),
            Shortcut("exportNotes", "Export notes", keys: ["⇧", "⌘", "E"], spoken: "Shift Command E", chords: ["⇧⌘E"]),
        ]),
        ShortcutGroup(id: "assistant", title: "Assistant", shortcuts: [
            Shortcut("showAssistant", "Show assistant", keys: ["⇧", "⌘", "A"], spoken: "Shift Command A", chords: ["⇧⌘A"]),
            Shortcut("newConversation", "New conversation", keys: ["⌃", "⌘", "N"], spoken: "Control Command N", chords: ["⌃⌘N"]),
            Shortcut("tryAgain", "Try again", keys: ["⌘", "R"], spoken: "Command R", chords: ["⌘R"]),
            Shortcut("copyLastReply", "Copy last reply", keys: ["⇧", "⌘", "C"], spoken: "Shift Command C", chords: ["⇧⌘C"]),
            Shortcut("addReplyAsNote", "Add last reply as note", keys: ["⇧", "⌘", "S"], spoken: "Shift Command S", chords: ["⇧⌘S"]),
            Shortcut("stopAnswering", "Stop answering", keys: ["⌘", "."], spoken: "Command period", chords: ["⌘."]),
        ]),
    ]

    /// Every row's reader keys in one map. Built with `uniquingKeysWith`, so a key listed twice
    /// fails the catalogue's test rather than the launch.
    private static let readerActions: [ReaderKeyStroke: ReaderKeyAction] = Dictionary(
        groups.flatMap(\.shortcuts).flatMap { Array($0.readerKeys) }, uniquingKeysWith: { first, _ in first })

    /// The chord at `index` of the row `row`; nil for a row or chord there is not.
    public static func chord(row: String, at index: Int) -> String? {
        guard let chords = groups.flatMap(\.shortcuts).first(where: { $0.id == row })?.chords, chords.indices.contains(index)
        else { return nil }
        return chords[index]
    }

    /// A chord as keycaps: each of ⌃⌥⇧⌘ its own cap, then the key ("-" is shown as "−").
    public static func keycaps(forChord chord: String) -> [String] {
        let modifiers = "⌃⌥⇧⌘"
        let caps = chord.prefix { modifiers.contains($0) }.map(String.init)
        let key = String(chord.dropFirst(caps.count))
        return caps + (key.isEmpty ? [] : [key == "-" ? "−" : key])
    }

    /// The reader's action for a bare key, or nil when the key is not one of the reader's.
    public static func readerAction(for stroke: ReaderKeyStroke) -> ReaderKeyAction? {
        readerActions[stroke]
    }

    /// The groups with only the rows whose label contains `query` (case and diacritics ignored,
    /// white space trimmed); a group left with no row is dropped. An empty query is every group.
    public static func filtered(_ query: String) -> [ShortcutGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return groups }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return groups.compactMap { group in
            let rows = group.shortcuts.filter { $0.label.range(of: needle, options: options) != nil }
            return rows.isEmpty ? nil : ShortcutGroup(id: group.id, title: group.title, shortcuts: rows)
        }
    }

    /// The sheet's three columns: Go and View; Verses; Notes Column and Assistant. A column left
    /// with no group is dropped.
    public static func columns(_ groups: [ShortcutGroup]) -> [[ShortcutGroup]] {
        let layout = [["go", "view"], ["verses"], ["notesColumn", "assistant"]]
        return layout.map { ids in groups.filter { ids.contains($0.id) } }.filter { !$0.isEmpty }
    }
}

extension Shortcut {
    /// "Next, previous verse: J, K"; "Go to anything: Command K".
    public var accessibilityLabel: String { "\(label): \(spoken)" }
}
