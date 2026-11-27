import ScriptureData

/// Orders palette results: a parsed reference, then book name matches, then translations, then
/// commands whose title contains the query, then verse text hits. `SearchRanker` sorts these
/// into its groups beside the reader's marks.
public enum PaletteRanker {
    public static func rank(
        query: String,
        books: [TranslationBook],
        translations: [Translation],
        activeTranslationID: String,
        verses: [Verse],
        commands: [PaletteCommand] = [],
        maxBooks: Int = 6,
        maxVerses: Int = 8
    ) -> [PaletteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var items: [PaletteItem] = []
        var referencedBookID: String?

        if let reference = ReferenceParser.parse(trimmed),
           let available = books.first(where: { $0.book.id == reference.book.id }) {
            if let chapter = reference.chapter {
                if (1...available.chapterCount).contains(chapter) {
                    items.append(.reference(reference))
                    referencedBookID = reference.book.id
                }
            } else {
                items.append(.book(reference.book))
                referencedBookID = reference.book.id
            }
        }

        let availableIDs = Set(books.map(\.book.id))
        let bookMatches = ReferenceParser.matchBooks(prefix: trimmed)
            .filter { availableIDs.contains($0.id) && $0.id != referencedBookID }
            .prefix(maxBooks)
        items.append(contentsOf: bookMatches.map(PaletteItem.book))

        let lowered = trimmed.lowercased()
        items.append(contentsOf: translations
            .filter { $0.id != activeTranslationID }
            .filter { $0.id.lowercased().contains(lowered) || $0.title.lowercased().contains(lowered) }
            .map(PaletteItem.translation))

        // A command matches from two characters on, when each typed word starts a word of its
        // title ("page lec", "brow"); a bare substring would surface both commands on almost any
        // single letter.
        let queryWords = lowered.split(separator: " ")
        if lowered.count >= 2 {
            items.append(contentsOf: commands
                .filter { command in
                    let titleWords = command.title.lowercased().split(separator: " ")
                    return queryWords.allSatisfy { word in titleWords.contains { $0.hasPrefix(word) } }
                }
                .map(PaletteItem.command))
        }

        items.append(contentsOf: verses.prefix(maxVerses).map(PaletteItem.verse))
        return items
    }
}
