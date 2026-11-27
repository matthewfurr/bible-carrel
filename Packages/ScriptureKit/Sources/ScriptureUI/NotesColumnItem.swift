import Foundation
import ScriptureData
import ScriptureModel

/// A note as the column shows it.
public struct NoteCard: Identifiable, Equatable {
    /// The note's uuid.
    public let id: UUID
    public let highlightID: UUID?
    public let referenceString: String
    public let quotedText: String
    public let body: String
    public let modifiedAt: Date
    public let color: MarkupColor?
    public let colorID: UUID?
    public let isChapterNote: Bool
    /// An expanded compact row: the card shows an empty editor, but no note exists until the
    /// reader clicks into it. Its `id` is the highlight's uuid.
    public let isDraft: Bool
    /// The note's text and its kept versions: 1 when it has none (spec 4.1's "2 versions").
    public let versionCount: Int

    public init(id: UUID, highlightID: UUID?, referenceString: String, quotedText: String, body: String, modifiedAt: Date, color: MarkupColor?, colorID: UUID? = nil, isChapterNote: Bool, isDraft: Bool = false, versionCount: Int = 1) {
        self.id = id
        self.highlightID = highlightID
        self.referenceString = referenceString
        self.quotedText = quotedText
        self.body = body
        self.modifiedAt = modifiedAt
        self.color = color
        self.colorID = colorID
        self.isChapterNote = isChapterNote
        self.isDraft = isDraft
        self.versionCount = versionCount
    }
}

/// A highlight without a note: one compact line in the column.
public struct CompactRow: Identifiable, Equatable {
    /// The highlight's uuid.
    public let id: UUID
    public let referenceString: String
    public let quotedText: String
    public let color: MarkupColor?
    public let colorID: UUID?

    public init(id: UUID, referenceString: String, quotedText: String, color: MarkupColor?, colorID: UUID? = nil) {
        self.id = id
        self.referenceString = referenceString
        self.quotedText = quotedText
        self.color = color
        self.colorID = colorID
    }
}

public enum NotesColumnItem: Identifiable, Equatable {
    case note(NoteCard)
    case compactHighlight(CompactRow)

    /// Keyed by the highlight where there is one, so a compact row, its draft card and the note
    /// that replaces the draft keep one SwiftUI identity (and the editor keeps focus).
    public var id: UUID {
        switch self {
        case .note(let card): card.highlightID ?? card.id
        case .compactHighlight(let row): row.id
        }
    }
}

/// A color as the swatch row shows it.
public struct ColorChip: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let color: MarkupColor

    public init(id: UUID, name: String, color: MarkupColor) {
        self.id = id
        self.name = name
        self.color = color
    }
}

/// The selection context menu, as data; the AppKit layer turns it into an `NSMenu`.
public enum MarkupMenuItem: Equatable {
    case swatches([ColorChip], current: UUID?)
    case addColor
    /// Inside a highlight: clear its color (underline only; a noteless one is then deleted).
    case noColor(isCurrent: Bool)
    case addNote(existing: Bool)
    case removeHighlight
    case bookmark(verse: Int, isSet: Bool)
    /// Each asks `MarkupModel.onVersePanel` for its panel; disabled until the app sets it.
    case compareTranslations
    case crossReferences
    case copy
    case copyWithReference
    case copyLink
    case share
    /// Opens the study assistant on the selection; disabled until the app sets
    /// `MarkupModel.onAskAboutPassage`.
    case askAboutPassage
}

enum MarkupReference {
    /// `"Matthew 5:3"`, `"Matthew 5:3-4"`, or `"Matthew 5"` when `verse` is nil.
    static func string(book: String, chapter: Int, verse: Int?, endVerse: Int?) -> String {
        MarkupReferenceText.string(book: book, chapter: chapter, verse: verse, endVerse: endVerse)
    }
}
