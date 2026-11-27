import Foundation
import ScriptureData

/// One verse, or a short run of them, in the translation being read and the translations the reader
/// compares with: the rows of the Compare Translations panel.
public struct VerseComparison: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public let translationID: String
        public let isReading: Bool
        /// Empty: the translation lacks them.
        public let verses: [Verse]
        let book: String

        public var id: String { translationID }
        public var canOpen: Bool { !verses.isEmpty }
        /// A click on the row looks its verses up in its translation. The row being read is the verse
        /// the reader is on: a click on it only closes the panel.
        public var looksUp: Bool { canOpen && !isReading }

        /// Prose, poetry lines joined by a space. Verses carry their numbers ("3 … 4 …", "12-13 …")
        /// when the row holds more than one or a joined one; one plain verse carries none.
        public var text: String {
            let numbered = verses.count > 1 || verses.contains { $0.endVerse != nil }
            return verses.map { verse in
                let body = Self.joined(verse.text)
                guard numbered else { return body }
                let number = verse.endVerse.map { "\(verse.id.verse)-\($0)" } ?? "\(verse.id.verse)"
                return "\(number) \(body)"
            }.joined(separator: " ")
        }

        public var missingLine: String? { canOpen ? nil : "Not in the \(translationID)." }
        public var note: String? { VerseComparison.note(translationID: translationID, book: book) }

        public var accessibilityLabel: String {
            "\(translationID)\(isReading ? ", reading" : ""): \(missingLine ?? text)"
        }

        /// The verses' words as Copy writes them: joined by a space, no numbers, no line breaks.
        var plainText: String { verses.map { Self.joined($0.text) }.joined(separator: " ") }

        private static func joined(_ text: String) -> String {
            text.split(separator: "\n", omittingEmptySubsequences: true).joined(separator: " ")
        }
    }

    /// Most verses the panel shows.
    static let limit = 5

    /// The verses shown: the selection's, five at most.
    public let reference: Reference
    public let rows: [Row]
    /// "Showing the first 5 of 8 verses."
    public let cutLine: String?
    private let shown: TextSelection
    /// Every verse shown, whichever the translation being read has: the reference, and Copy's.
    private let shownVerses: TextSelection

    public var countLabel: String { rows.count == 1 ? "1 translation" : "\(rows.count) translations" }

    /// The rows after the first that have the verses: what Ask sends.
    public var otherTranslationIDs: [String] { rows.dropFirst().filter(\.canOpen).map(\.translationID) }

    /// Ask About the Differences has something to send: the translation being read has the verses
    /// (else `selection` names no text) and another row has them too.
    public var canAsk: Bool { rows.first?.canOpen == true && !otherTranslationIDs.isEmpty }

    /// The verses shown that the translation being read has, as a whole-verse selection (the first's
    /// start to the last's end, as the reader reports one), its quoted text the first row's words as
    /// Copy writes them. Lacking a verse at either end, it ends at the nearest one it has; lacking
    /// them all, it is the verses shown with no offsets, and `canAsk` is false.
    public var selection: TextSelection { shown }

    /// Each row that has the verses as `TextSelection.copyWithReference` writes it, one to a line:
    /// the verses joined by a space, no numbers, no line breaks, under the reference of the verses shown.
    public var copyText: String {
        rows.filter(\.canOpen).map { row in
            TextSelection(book: shownVerses.book, chapter: shownVerses.chapter, verse: shownVerses.verse, endVerse: shownVerses.endVerse,
                          startOffset: shown.startOffset, endOffset: shown.endOffset, quotedText: row.plainText)
                .copyWithReference(translationID: row.translationID)
        }.joined(separator: "\n")
    }

    /// Rows: the translation being read, then each of `compareSet` that is in `translations` and
    /// is not the one being read, in `translations`' order.
    public init(selection: TextSelection, readingTranslationID: String, compareSet: [String],
                translations: [Translation], verses: [String: [Verse]]) {
        let last = Self.lastShown(selection)
        let total = selection.endVerse - selection.verse + 1
        rows = Self.translationIDs(readingTranslationID, compareSet, translations).map { id in
            let held = (verses[id] ?? []).filter { $0.id.verse <= last && ($0.endVerse ?? $0.id.verse) >= selection.verse }
            return Row(translationID: id, isReading: id == readingTranslationID, verses: held, book: selection.book)
        }
        // **(call)** The cut's line counts the selection's verses.
        cutLine = total > Self.limit ? "Showing the first \(Self.limit) of \(total) verses." : nil
        // Part of a verse counts as the whole verse (spec 4.1): Ask keeps these offsets and a reply saved
        // as a note highlights them, so they span the verses shown, whole, as the reader reports them,
        // and each end is a verse the translation being read has (its rows are in order and within
        // the verses shown, so its first and last are the nearest it has to each end).
        let reading = rows.first?.verses ?? []
        let whole = SelectionResolver.wholeVerseOffsets(first: reading.first?.text ?? "", last: reading.last?.text ?? "")
        shown = TextSelection(book: selection.book, chapter: selection.chapter,
                              verse: reading.first?.id.verse ?? selection.verse, endVerse: reading.last?.id.verse ?? last,
                              startOffset: whole.start, endOffset: whole.end, quotedText: rows.first?.plainText ?? "")
        shownVerses = TextSelection(book: selection.book, chapter: selection.chapter, verse: selection.verse, endVerse: last,
                                    startOffset: selection.startOffset, endOffset: selection.endOffset, quotedText: "")
        reference = shownVerses.reference
    }

    public static func load(selection: TextSelection, readingTranslationID: String, compareSet: [String],
                            translations: [Translation], store: BibleStore) throws -> VerseComparison {
        let found = try store.verses(
            in: selection.chapterLocation, verse: selection.verse, endVerse: lastShown(selection),
            translationIDs: translationIDs(readingTranslationID, compareSet, translations))
        return VerseComparison(selection: selection, readingTranslationID: readingTranslationID, compareSet: compareSet,
                               translations: translations, verses: found)
    }

    public static func note(translationID: String, book: String) -> String? {
        translationID == "CPDV" && book == "PSA"
            ? "The CPDV numbers the Psalms differently; this may be a neighboring verse." : nil
    }

    private static func lastShown(_ selection: TextSelection) -> Int {
        min(selection.endVerse, selection.verse + limit - 1)
    }

    private static func translationIDs(_ reading: String, _ compareSet: [String], _ translations: [Translation]) -> [String] {
        [reading] + CompareSet.ordered(compareSet, in: translations).filter { $0 != reading }
    }
}
