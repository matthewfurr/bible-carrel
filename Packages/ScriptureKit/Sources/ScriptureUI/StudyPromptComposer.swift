import ScriptureData

/// The text a study prompt is filled with, read from the bundled Bible: the chapter as numbered
/// lines, the chapter before it, and the same verses in the other translations.
public struct StudyPromptComposer: Sendable {
    private let store: BibleStore

    public init(store: BibleStore) {
        self.store = store
    }

    /// "1 text\n2 text" with "12-13" for a combined verse; poetry newlines kept.
    public static func chapterText(_ verses: [Verse]) -> String {
        verses.map(line).joined(separator: "\n")
    }

    /// Verse lines for the first and last five verses with a "…" line between, or the whole text
    /// when ten or fewer (the spec's rule for Catch me up on the on-device model).
    public static func abridged(_ verses: [Verse]) -> String {
        guard verses.count > 10 else { return chapterText(verses) }
        return (verses.prefix(5).map(line) + ["…"] + verses.suffix(5).map(line)).joined(separator: "\n")
    }

    private static func line(_ verse: Verse) -> String {
        let number = verse.endVerse.map { "\(verse.id.verse)-\($0)" } ?? "\(verse.id.verse)"
        return "\(number) \(verse.text)"
    }

    /// The verses in `verse...endVerse` of each of `translationIDs` that has them, in that order, at
    /// most `limit` of them, as "KJV\n3 …\n\nWEB\n3 …"; "" when none. One store read.
    public func otherTranslations(for location: ChapterLocation, verse: Int, endVerse: Int, translationIDs: [String], limit: Int?) throws -> String {
        let found = try store.verses(in: location, verse: verse, endVerse: endVerse, translationIDs: translationIDs)
        var sections: [String] = []
        for id in translationIDs {
            if let limit, sections.count >= limit { break }
            guard let verses = found[id], !verses.isEmpty else { continue }
            sections.append(id + "\n" + Self.chapterText(verses))
        }
        return sections.joined(separator: "\n\n")
    }

    /// The chapter before `location` in `translationID`, or nil at the start of the book (the
    /// previous book is not crossed) or when the translation lacks it.
    public func previousChapter(of location: ChapterLocation, translationID: String) throws -> [Verse]? {
        guard location.chapter > 1 else { return nil }
        let verses = try store.chapter(ChapterLocation(book: location.book, chapter: location.chapter - 1), translationID: translationID)
        return verses.isEmpty ? nil : verses
    }
}
