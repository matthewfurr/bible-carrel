import Foundation
import ScriptureData

/// What decides which commands can run now.
public struct PaletteState: Equatable, Sendable {
    // The model fills these.
    /// The reader is showing.
    public var isReading = false
    public var canGoBack = false, canGoForward = false, hasPreviousChapter = false, hasNextChapter = false
    public var isLookingUp = false, hasRecents = false
    public var otherTranslations = 0
    // The app fills these.
    public var isNotesColumnShown = true
    public var pageStyle = PageStyle.printed
    public var appearance = AppearanceChoice.system
    public var fontSize = ReaderSettings.defaultFontSize
    public var canRetry = false, hasLastReply = false, lastReplyIsSaved = false, isResponding = false
    /// Import Data can run: iCloud has brought the notes back (`SyncStatusModel.canRestore`).
    public var canImportData = true

    public init() {}
}

/// Everything the palette can do: the menus' own commands, by their names, and a few more.
public enum PaletteCommand: Hashable, Sendable {
    case home, back, forward, previousChapter, nextChapter, readFromHere
    case textLayout, showNotesColumn, hideNotesColumn, notesBrowser, readingPlan, showShortcuts, settings
    case pageStyle(PageStyle), appearance(AppearanceChoice), largerText, smallerText
    case switchTranslation, copyChapterLink, exportNotes, exportAllData, importData
    case toggleAssistant, newConversation, tryAgain, copyLastReply, addLastReplyAsNote, stopAnswering
    case clearRecents

    /// Every command, in the order the palette lists them.
    public static let all: [PaletteCommand] = [
        .home, .back, .forward, .previousChapter, .nextChapter, .readFromHere,
        .textLayout, .showNotesColumn, .hideNotesColumn, .notesBrowser, .readingPlan, .showShortcuts, .settings,
    ] + PageStyle.allCases.map(PaletteCommand.pageStyle) + AppearanceChoice.allCases.map(PaletteCommand.appearance) + [
        .largerText, .smallerText, .switchTranslation, .copyChapterLink, .exportNotes, .exportAllData, .importData,
        .toggleAssistant, .newConversation, .tryAgain, .copyLastReply, .addLastReplyAsNote, .stopAnswering,
        .clearRecents,
    ]

    /// What the palette offers with nothing typed (those that can run now, up to its limit).
    public static let suggested: [PaletteCommand] = [
        .home, .notesBrowser, .toggleAssistant, .textLayout, .showShortcuts, .switchTranslation,
    ]

    public var id: String {
        switch self {
        case .home: "home"
        case .back: "back"
        case .forward: "forward"
        case .previousChapter: "previousChapter"
        case .nextChapter: "nextChapter"
        case .readFromHere: "readFromHere"
        case .textLayout: "textLayout"
        case .showNotesColumn: "showNotesColumn"
        case .hideNotesColumn: "hideNotesColumn"
        case .notesBrowser: "notesBrowser"
        case .readingPlan: "readingPlan"
        case .showShortcuts: "showShortcuts"
        case .settings: "settings"
        case .pageStyle(let style): "pageStyle.\(style.rawValue)"
        case .appearance(let choice): "appearance.\(choice.rawValue)"
        case .largerText: "largerText"
        case .smallerText: "smallerText"
        case .switchTranslation: "switchTranslation"
        case .copyChapterLink: "copyChapterLink"
        case .exportNotes: "exportNotes"
        case .exportAllData: "exportAllData"
        case .importData: "importData"
        case .toggleAssistant: "toggleAssistant"
        case .newConversation: "newConversation"
        case .tryAgain: "tryAgain"
        case .copyLastReply: "copyLastReply"
        case .addLastReplyAsNote: "addLastReplyAsNote"
        case .stopAnswering: "stopAnswering"
        case .clearRecents: "clearRecents"
        }
    }

    /// The menus' own names.
    public var title: String {
        switch self {
        case .home: "Home"
        case .back: "Back"
        case .forward: "Forward"
        case .previousChapter: "Previous Chapter"
        case .nextChapter: "Next Chapter"
        case .readFromHere: "Read From Here"
        case .textLayout: "Text & Layout"
        case .showNotesColumn: "Show Notes Column"
        case .hideNotesColumn: "Hide Notes Column"
        case .notesBrowser: "Notes Browser"
        case .readingPlan: "Reading Plan"
        case .showShortcuts: "Keyboard Shortcuts"
        case .settings: "Settings"
        case .pageStyle(let style): "Page Style: \(style.title)"
        case .appearance(let choice): "Appearance: \(choice.title)"
        case .largerText: "Larger Text"
        case .smallerText: "Smaller Text"
        case .switchTranslation: "Switch Translation…"
        case .copyChapterLink: "Copy Link to This Chapter"
        case .exportNotes: "Export Notes…"
        case .exportAllData: "Export All Data…"
        case .importData: "Import Data…"
        case .toggleAssistant: "Ask the Assistant"
        case .newConversation: "New Conversation…"
        case .tryAgain: "Try Again"
        case .copyLastReply: "Copy Last Reply"
        case .addLastReplyAsNote: "Add Last Reply as Note"
        case .stopAnswering: "Stop Answering"
        case .clearRecents: "Clear Recents"
        }
    }

    public var symbolName: String {
        switch self {
        case .home: "house"
        case .back: "chevron.left"
        case .forward: "chevron.right"
        case .previousChapter: "arrow.left"
        case .nextChapter: "arrow.right"
        case .readFromHere: "book"
        case .textLayout: "textformat.size"
        case .showNotesColumn, .hideNotesColumn: "sidebar.right"
        case .notesBrowser: "note.text"
        case .readingPlan: "calendar"
        case .showShortcuts: "keyboard"
        case .settings: "gearshape"
        case .pageStyle: "textformat"
        case .appearance: "circle.lefthalf.filled"
        case .largerText: "textformat.size.larger"
        case .smallerText: "textformat.size.smaller"
        case .switchTranslation: "character.book.closed"
        case .copyChapterLink: "link"
        case .exportNotes: "square.and.arrow.up"
        case .exportAllData: "square.and.arrow.up"
        case .importData: "square.and.arrow.down"
        case .toggleAssistant: "sparkles"
        case .newConversation: "plus"
        case .tryAgain: "arrow.clockwise"
        case .copyLastReply: "doc.on.doc"
        case .addLastReplyAsNote: "note.text.badge.plus"
        case .stopAnswering: "stop.circle"
        case .clearRecents: "clock.arrow.circlepath"
        }
    }

    /// The catalogue row and which of its chords is this command's; nil without a shortcut.
    public var shortcut: (row: String, chord: Int)? {
        switch self {
        case .home: ("home", 0)
        case .back: ("backForward", 0)
        case .forward: ("backForward", 1)
        case .previousChapter: ("chaptersAnywhere", 0)
        case .nextChapter: ("chaptersAnywhere", 1)
        case .textLayout: ("textLayout", 0)
        case .showNotesColumn, .hideNotesColumn: ("notesColumn", 0)
        case .notesBrowser: ("notesBrowser", 0)
        case .readingPlan: ("readingPlan", 0)
        case .showShortcuts: ("keyboardShortcuts", 0)
        case .settings: ("settings", 0)
        case .largerText: ("textSize", 0)
        case .smallerText: ("textSize", 1)
        case .exportNotes: ("exportNotes", 0)
        case .toggleAssistant: ("showAssistant", 0)
        case .newConversation: ("newConversation", 0)
        case .tryAgain: ("tryAgain", 0)
        case .copyLastReply: ("copyLastReply", 0)
        case .addLastReplyAsNote: ("addReplyAsNote", 0)
        case .stopAnswering: ("stopAnswering", 0)
        case .readFromHere, .pageStyle, .appearance, .switchTranslation, .copyChapterLink, .clearRecents, .exportAllData, .importData: nil
        }
    }

    /// The keycaps to show, read from `ShortcutCatalog`; nil without a shortcut.
    public var keycaps: [String]? {
        guard let shortcut, let chord = ShortcutCatalog.chord(row: shortcut.row, at: shortcut.chord) else { return nil }
        return ShortcutCatalog.keycaps(forChord: chord)
    }

    /// The shortcut by name for VoiceOver: the catalogue row's `spoken`, the part for this chord
    /// ("Command right bracket" for Forward); nil without a shortcut.
    public var spokenShortcut: String? {
        guard let shortcut,
              let row = ShortcutCatalog.groups.flatMap(\.shortcuts).first(where: { $0.id == shortcut.row }) else { return nil }
        let parts = row.spoken.components(separatedBy: ", ")
        guard parts.count == row.chords.count, parts.indices.contains(shortcut.chord) else { return row.spoken }
        let part = parts[shortcut.chord]
        return part.hasPrefix("or ") ? String(part.dropFirst(3)) : part
    }

    /// Whether the command can run now; one that cannot is left out of the palette.
    public func isAvailable(in state: PaletteState) -> Bool {
        switch self {
        case .home, .textLayout, .copyChapterLink, .toggleAssistant, .newConversation: state.isReading
        case .back: state.canGoBack
        case .forward: state.canGoForward
        case .previousChapter: state.hasPreviousChapter
        case .nextChapter: state.hasNextChapter
        case .readFromHere: state.isLookingUp
        case .showNotesColumn: state.isReading && !state.isNotesColumnShown
        case .hideNotesColumn: state.isReading && state.isNotesColumnShown
        case .notesBrowser, .readingPlan, .showShortcuts, .settings, .pageStyle, .appearance, .exportNotes, .exportAllData: true
        case .importData: state.canImportData
        case .largerText: state.fontSize < ReaderSettings.fontSizeRange.upperBound
        case .smallerText: state.fontSize > ReaderSettings.fontSizeRange.lowerBound
        case .switchTranslation: state.otherTranslations > 0
        case .tryAgain: state.isReading && state.canRetry
        case .copyLastReply: state.hasLastReply
        case .addLastReplyAsNote: state.isReading && state.hasLastReply && !state.lastReplyIsSaved && !state.isResponding
        case .stopAnswering: state.isResponding
        case .clearRecents: state.hasRecents
        }
    }

    /// True for the page style or appearance in force.
    public func isCurrent(in state: PaletteState) -> Bool {
        switch self {
        case .pageStyle(let style): state.pageStyle == style
        case .appearance(let choice): state.appearance == choice
        default: false
        }
    }
}

/// One row of the ⌘K palette.
public enum PaletteItem: Hashable, Identifiable, Sendable {
    case reference(Reference)
    case book(Book)
    case translation(Translation)
    case verse(Verse)
    /// One of the reader's marks: a note, highlight, bookmark or conversation.
    case mark(SearchMarkHit)
    case command(PaletteCommand)
    /// "Did you mean": a near spelling that finds verses; chosen, it is searched.
    case suggestion(SearchSuggestion)
    /// Somewhere the reader went lately, shown with nothing typed.
    case recent(Recent)
    /// A person or a place found by name: chosen, their page for the whole Bible (spec 6.6).
    case person(PersonSummary)
    case place(PlaceSummary)

    public var id: String {
        switch self {
        case .reference(let reference): "reference:\(reference.displayString)"
        case .book(let book): "book:\(book.id)"
        case .translation(let translation): "translation:\(translation.id)"
        case .verse(let verse): "verse:\(verse.translationID):\(verse.id.book):\(verse.id.chapter):\(verse.id.verse)"
        case .mark(let hit): "mark:\(hit.id.uuidString)"
        case .command(let command): "command:\(command.id)"
        case .suggestion(let suggestion): "suggestion:\(suggestion.query)"
        case .recent(let recent): "recent:\(recent.id)"
        case .person(let person): "person:\(person.id)"
        case .place(let place): "place:\(place.id)"
        }
    }

    /// Whether choosing this row on the phone takes the reader to the page. A translation is
    /// switched in place, a suggestion or a recent search stays on the search tab, and a
    /// conversation (found or recent) opens in Ask. A person or place is pushed inside Search.
    public var showsReaderWhenChosen: Bool {
        switch self {
        case .translation, .suggestion, .person, .place: false
        case .mark(let hit): hit.kind != .thread
        case .recent(let recent):
            switch recent.target {
            case .search: false
            case .mark(_, let kind, _, _): kind != .thread
            case .chapter, .lookup: true
            }
        case .reference, .book, .verse, .command: true
        }
    }

    public var title: String {
        switch self {
        case .reference(let reference): reference.displayString
        case .book(let book): book.name
        case .translation(let translation): translation.title
        case .verse(let verse):
            "\(BookCatalog.book(code: verse.id.book)?.chapterName ?? verse.id.book) \(verse.id.chapter):\(verse.id.verse)"
        case .mark(let hit): hit.referenceString
        case .command(let command): command.title
        case .suggestion(let suggestion): "Did you mean “\(suggestion.query)”?"
        case .recent(let recent): recent.title
        case .person(let person): person.name
        case .place(let place): place.name
        }
    }

    public var subtitle: String? {
        switch self {
        case .reference(let reference): reference.verse == nil ? "Go to chapter" : "Go to verse"
        case .book(let book): book.canon.displayName
        case .translation: "Switch translation"
        case .verse(let verse):
            String(verse.text.replacingOccurrences(of: "\n", with: " ").prefix(120))
        case .mark(let hit): hit.firstLine.isEmpty ? nil : hit.firstLine
        case .command: nil
        case .suggestion(let suggestion):
            suggestion.verseCount == 1 ? "1 verse" : "\(suggestion.verseCount.formatted()) verses"
        case .recent(let recent): recent.subtitle()
        // What tells a shared name apart (the record has a label only then), then the verses.
        case .person(let person): Self.joined([person.label, Self.verses(person.verseCount)])
        case .place(let place): Self.joined([place.kind, place.label, Self.verses(place.verseCount)])
        }
    }

    public var symbolName: String {
        switch self {
        case .reference: "arrow.right.circle"
        case .book: "book"
        case .translation: "character.book.closed"
        case .verse: "text.quote"
        case .mark(let hit): hit.symbolName
        case .command(let command): command.symbolName
        case .suggestion: "magnifyingglass"
        case .recent(let recent): recent.symbolName
        case .person: "person"
        case .place: "mappin"
        }
    }

    private static func verses(_ count: Int) -> String {
        count == 1 ? "1 verse" : "\(count.formatted()) verses"
    }

    private static func joined(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.joined(separator: " · ")
    }
}

extension PaletteItem {
    /// What Return does with the row, for the palette's foot. Read moves the reader's place.
    public var returnVerb: String {
        switch self {
        case .reference, .book: "Read"
        case .verse: "Show verse"
        case .mark(let hit): Self.verb(showing: hit.kind)
        case .translation: "Switch"
        case .command: "Run"
        case .suggestion: "Search"
        case .person, .place: "Open"
        case .recent(let recent):
            switch recent.target {
            case .chapter: "Read"
            case .lookup: "Show verse"
            case .mark(_, let kind, _, _): Self.verb(showing: kind)
            case .search: "Search"
            }
        }
    }

    private static func verb(showing kind: SearchMarkHit.Kind) -> String {
        kind == .thread ? "Open conversation" : "Show \(kind.displayName.lowercased())"
    }
}
