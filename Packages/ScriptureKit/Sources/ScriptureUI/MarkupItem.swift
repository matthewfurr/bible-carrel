import Foundation
import ScriptureModel

/// A highlight color's two variants, as stored.
public struct MarkupColor: Hashable, Sendable {
    public let lightHex: String
    public let darkHex: String

    public init(lightHex: String, darkHex: String) {
        self.lightHex = lightHex
        self.darkHex = darkHex
    }
}

/// A highlight as the reader needs it: a value copy of `Highlight` with its color resolved.
public struct MarkupItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// The chapter the highlight is in; `verse` and `endVerse` are verses of it.
    public let chapter: Int
    public let verse: Int
    public let endVerse: Int
    public let startOffset: Int
    public let endOffset: Int
    public let translationID: String
    public let color: MarkupColor?
    public let hasNote: Bool

    public init(id: UUID, chapter: Int, verse: Int, endVerse: Int, startOffset: Int, endOffset: Int, translationID: String, color: MarkupColor?, hasNote: Bool) {
        self.id = id
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.translationID = translationID
        self.color = color
        self.hasNote = hasNote
    }

    /// A missing color (deleted, or never set) behaves as nil.
    @MainActor
    public init(highlight: Highlight, colors: [HighlightColor]) {
        let color = highlight.colorID.flatMap { id in colors.first { $0.uuid == id } }
        self.init(
            id: highlight.uuid,
            chapter: highlight.chapter,
            verse: highlight.verse,
            endVerse: highlight.endVerse,
            startOffset: highlight.startOffset,
            endOffset: highlight.endOffset,
            translationID: highlight.translationID,
            color: color.map { MarkupColor(lightHex: $0.lightHex, darkHex: $0.darkHex) },
            hasNote: highlight.note != nil)
    }
}
