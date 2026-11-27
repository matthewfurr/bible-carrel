import Foundation
import ScriptureData

/// Groups a query's results for the Mac's ⌘K palette and the phone's search screen.
///
/// A passage query (a reference to a chapter that exists) offers the passage, then every mark the
/// reader has there; any other query is a word query, which finds the reader's notes and
/// conversations by their words. Books, translations and commands are `PaletteRanker`'s rows.
public enum SearchRanker {
    /// `suggestion`, a near spelling the store found, is offered when Scripture found nothing: the
    /// first group when nothing else matched, otherwise the last (the controller's ruling on spec 4.4).
    /// `people` and `places`, the store's by name, come after Commands and before the reader's notes,
    /// so a command typed by name stays first (spec 6.6).
    public static func results(
        query: String, books: [TranslationBook], translations: [Translation], activeTranslationID: String,
        verses: [Verse], verseTotal: Int, suggestion: SearchSuggestion? = nil, marks: [NotesBrowserEntry],
        commands: [PaletteCommand] = [], people: NameMatches<PersonSummary> = .none, places: NameMatches<PlaceSummary> = .none,
        limits: SearchLimits
    ) -> SearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let rows = paletteRows(
            query: trimmed, books: books, translations: translations, activeTranslationID: activeTranslationID, commands: commands,
            maxBooks: limits.books)
        // Ranked again without the cap, only to count the matching books.
        let bookTotal = paletteRows(
            query: trimmed, books: books, translations: translations, activeTranslationID: activeTranslationID, commands: commands,
            maxBooks: .max)
            .books.count

        var groups: [SearchGroup] = []
        func add(_ kind: SearchGroupKind, _ title: String, _ items: [PaletteItem], limit: Int? = nil, total: Int? = nil) {
            let shown = limit.map { Array(items.prefix($0)) } ?? items
            guard !shown.isEmpty else { return }
            groups.append(SearchGroup(kind: kind, title: title, items: shown, totalCount: total ?? items.count))
        }

        func addNames() {
            add(.people, "People", people.rows.map(PaletteItem.person), limit: limits.people, total: people.total)
            add(.places, "Places", places.rows.map(PaletteItem.place), limit: limits.places, total: places.total)
        }

        let shownVerses = Array(verses.prefix(limits.verses))
        let verseItems = shownVerses.map(PaletteItem.verse)
        add(.goTo, "Go to", rows.goTo)
        if case .reference(let reference)? = rows.goTo.first, let chapter = reference.chapter {
            let passageMarks = marks
                .filter { $0.book == reference.book.id && $0.chapter == chapter && overlaps($0, reference) }
                .sorted { ($0.verse, $0.endVerse, $0.modifiedAt) < ($1.verse, $1.endVerse, $1.modifiedAt) }
            add(.marksInPassage, "Your marks in \(reference.book.chapterName) \(chapter)",
                passageMarks.map(markItem), limit: limits.marksInPassage)
            add(.books, "Books", rows.books, total: bookTotal)
            add(.translations, "Translations", rows.translations)
            add(.commands, "Commands", rows.commands, limit: limits.commands)
            addNames()
        } else {
            let search = SearchQuery(trimmed)
            add(.books, "Books", rows.books, total: bookTotal)
            add(.translations, "Translations", rows.translations)
            add(.commands, "Commands", rows.commands, limit: limits.commands)
            addNames()
            let notes = marks.filter { entry in
                switch entry.kind {
                case .note: search.matches(anyOf: [entry.body, entry.quotedText])
                case .highlight: search.matches(anyOf: [entry.quotedText])
                // ⌘K is never given a kept version (`NotesBrowserLoader`).
                case .bookmark, .thread, .keptVersion: false
                }
            }
            add(.notes, "Your notes", NotesBrowserQuery.sort(notes, by: .date).map(markItem), limit: limits.notes)
            let asked = marks.filter { entry in
                guard case .thread = entry.kind else { return false }
                return search.matches(anyOf: [entry.body, entry.quotedText])
            }
            add(.asked, "Asked", NotesBrowserQuery.sort(asked, by: .date).map(markItem), limit: limits.asked)
        }
        add(.scripture, "Scripture · \(activeTranslationID)", verseItems, total: verseTotal)
        // "Did you mean" when Scripture found nothing: alone, it is the first (and only) row; after
        // anything else that matched, it comes last, so a command typed by name stays first.
        if verseItems.isEmpty, let suggestion { add(.suggestion, "", [.suggestion(suggestion)]) }

        return SearchResults(groups: groups, verseColors: verseColors(shownVerses, marks: marks))
    }

    /// With nothing typed: what the reader went to lately, then the commands; either may be absent.
    public static func emptyState(recents: [Recent], commands: [PaletteCommand], commandTotal: Int) -> SearchResults {
        var groups: [SearchGroup] = []
        if !recents.isEmpty {
            groups.append(SearchGroup(kind: .recent, title: "Recent", items: recents.map(PaletteItem.recent), totalCount: recents.count))
        }
        if !commands.isEmpty {
            groups.append(SearchGroup(kind: .commands, title: "Commands", items: commands.map(PaletteItem.command), totalCount: commandTotal))
        }
        return SearchResults(groups: groups, verseColors: [:])
    }

    /// The words the query's terms to find match, for bolding: whole words, once each, in text
    /// order, as `SearchQuery` finds them.
    public static func matchRanges(in text: String, query: String) -> [Range<String.Index>] {
        SearchQuery(query).matchRanges(in: text)
    }

    /// `text` with its `matchRanges` set bold and underlined, for a search row's quote, note line or
    /// verse. A presentation intent and a single underline, never a color: the underline takes the
    /// text's own ink, so a quote keeps its mark's fill and contrast. The value compares equal from
    /// one evaluation to the next. (A page-face line sets its matches in the face's semibold with
    /// `PageFace.settingMatches`.)
    public static func bolded(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        for range in matchRanges(in: text, query: query) {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else { continue }
            attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            attributed[lower..<upper].underlineStyle = .single
        }
        return attributed
    }

    // MARK: - Private

    private struct PaletteRows {
        var goTo: [PaletteItem] = []
        var books: [PaletteItem] = []
        var translations: [PaletteItem] = []
        var commands: [PaletteItem] = []
    }

    /// `PaletteRanker`'s reference, book, translation and command rows, sorted into their groups.
    private static func paletteRows(
        query: String, books: [TranslationBook], translations: [Translation], activeTranslationID: String,
        commands: [PaletteCommand], maxBooks: Int
    ) -> PaletteRows {
        var rows = PaletteRows()
        let ranked = PaletteRanker.rank(
            query: query, books: books, translations: translations, activeTranslationID: activeTranslationID,
            verses: [], commands: commands, maxBooks: maxBooks)
        for item in ranked {
            switch item {
            case .reference: rows.goTo.append(item)
            case .book: rows.books.append(item)
            case .translation: rows.translations.append(item)
            case .command: rows.commands.append(item)
            case .verse, .mark, .suggestion, .recent, .person, .place: break
            }
        }
        return rows
    }

    private static func markItem(_ entry: NotesBrowserEntry) -> PaletteItem {
        .mark(SearchMarkHit(entry: entry))
    }

    /// Without a verse every mark in the chapter overlaps; with one (or a range), a chapter note
    /// or chapter conversation (verse 0) does not.
    private static func overlaps(_ entry: NotesBrowserEntry, _ reference: Reference) -> Bool {
        guard let verse = reference.verse else { return true }
        let end = reference.endVerse ?? verse
        return entry.verse <= end && entry.endVerse >= verse
    }

    /// Each verse row's color: that of the first colored mark in its chapter that spans it. The
    /// colored marks are indexed by chapter once, so the cost is about verses plus marks.
    private static func verseColors(_ verses: [Verse], marks: [NotesBrowserEntry]) -> [String: MarkupColor] {
        guard !verses.isEmpty else { return [:] }
        var byChapter: [ChapterLocation: [NotesBrowserEntry]] = [:]
        for entry in marks where entry.color != nil {
            byChapter[ChapterLocation(book: entry.book, chapter: entry.chapter), default: []].append(entry)
        }
        var colors: [String: MarkupColor] = [:]
        for verse in verses {
            let inChapter = byChapter[ChapterLocation(book: verse.id.book, chapter: verse.id.chapter)] ?? []
            let mark = inChapter.first { entry in
                (entry.verse...max(entry.verse, entry.endVerse)).contains(verse.id.verse)
            }
            if let color = mark?.color { colors[PaletteItem.verse(verse).id] = color }
        }
        return colors
    }

    /// True when every query word starts some word of `text`; never for a query without words.
    private static func matches(_ queryWords: [String], _ text: String) -> Bool {
        guard !queryWords.isEmpty else { return false }
        let textWords = foldedWords(in: text)
        return queryWords.allSatisfy { word in textWords.contains { $0.hasPrefix(word) } }
    }

    private static func foldedWords(in text: String) -> [String] {
        var words: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, _, _, _ in
            if let word { words.append(fold(word)) }
        }
        return words
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
