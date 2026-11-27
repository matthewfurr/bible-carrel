import ScriptureData

/// Verses written as references, neighbours joined: "John 1:29-34".
public enum VerseRuns {
    /// `verses` in canon order as references, each unbroken run of one chapter's verses one reference.
    public static func references(_ verses: [VerseLocation]) -> [Reference] {
        var result: [Reference] = []
        var run: (book: Book, chapter: Int, first: Int, last: Int)?
        func close() {
            guard let run else { return }
            result.append(Reference(book: run.book, chapter: run.chapter, verse: run.first,
                                    endVerse: run.last > run.first ? run.last : nil))
        }
        for verse in verses {
            guard let book = BookCatalog.book(code: verse.book) else { continue }
            if let current = run, current.book == book, current.chapter == verse.chapter, current.last + 1 == verse.verse {
                run?.last = verse.verse
            } else {
                close()
                run = (book, verse.chapter, verse.verse, verse.verse)
            }
        }
        close()
        return result
    }
}

/// One chapter's runs of a book's verses, the chapter's line (`chapter` is nil in a one-chapter book).
public struct VerseLine: Equatable, Sendable, Identifiable {
    public let chapter: Int?
    public let runs: [Reference]
    /// The chapter; 0 for a one-chapter book.
    public var id: Int { chapter ?? 0 }
}

/// A book's references as one line per chapter, and how the lines are written, spoken and folded.
public enum VerseLines {
    /// A book with more chapters' lines than this shows the first this many, then "n more chapters".
    public static let shownChapters = 12
    /// Books of one chapter (Departure 31): their runs are one line with no number.
    static let oneChapterBooks: Set<String> = ["OBA", "PHM", "2JN", "3JN", "JUD"]

    /// `references` (canon order, each a run) grouped by chapter, in order.
    static func lines(_ references: [Reference], book: Book) -> [VerseLine] {
        let single = oneChapterBooks.contains(book.id)
        var lines: [VerseLine] = []
        var runs: [Reference] = []
        var current: Int?
        func close() {
            guard let current, !runs.isEmpty else { return }
            lines.append(VerseLine(chapter: single ? nil : current, runs: runs))
        }
        for reference in references {
            let chapter = reference.chapter ?? 0
            if chapter != current {
                close()
                runs = []
                current = chapter
            }
            runs.append(reference)
        }
        close()
        return lines
    }

    /// The verses alone: "1-5", "11".
    static func runText(_ reference: Reference) -> String {
        guard let verse = reference.verse else { return "" }
        guard let end = reference.endVerse else { return "\(verse)" }
        return "\(verse)-\(end)"
    }

    /// The run as VoiceOver reads it: "2 Samuel 1:1 to 5".
    static func spoken(_ reference: Reference) -> String {
        reference.displayString.replacingOccurrences(of: "-", with: " to ")
    }

    static func chapterSpoken(_ chapter: Int) -> String { "Chapter \(chapter)" }
    /// A line's chapter as it is written (Matt, 2026-11-24): "Ch 11", one unit, right-aligned as a whole in a column
    /// as wide as `widestChapterLabel`, so every number ends on one edge.
    static func chapterLabel(_ chapter: Int) -> String { "Ch \(chapter)" }
    /// The widest label a line can carry (Psalms' 150), in tabular figures: the column's width.
    static let widestChapterLabel = "Ch 000"

    /// The first `shownChapters` lines unless `showingAll`, and how many are left out.
    static func shown(_ lines: [VerseLine], showingAll: Bool) -> (lines: [VerseLine], hidden: Int) {
        guard !showingAll, lines.count > shownChapters else { return (lines, 0) }
        return (Array(lines.prefix(shownChapters)), lines.count - shownChapters)
    }

    static func moreLine(_ hidden: Int) -> String { hidden == 1 ? "1 more chapter" : "\(hidden) more chapters" }

    /// True when `anchor`'s chapter is a line past the twelfth, so coming back to it opens the rest (Departure 14).
    static func showsAll(_ lines: [VerseLine], anchor: Reference?) -> Bool {
        guard let chapter = anchor?.chapter, let index = lines.firstIndex(where: { $0.chapter == chapter }) else { return false }
        return index >= shownChapters
    }
}

/// One book's verses that name a person or a place.
public struct VerseGroup: Identifiable, Equatable, Sendable {
    public let book: Book, count: Int, references: [Reference]
    /// `references` as one line per chapter, built once at load.
    public let lines: [VerseLine]
    public var id: String { book.id }

    /// The groups of `verses` (canon order), one for each book, in canon order.
    static func groups(_ verses: [VerseLocation]) -> [VerseGroup] {
        var groups: [VerseGroup] = []
        var start = 0
        while start < verses.count {
            let code = verses[start].book
            var end = start
            while end < verses.count, verses[end].book == code { end += 1 }
            if let book = BookCatalog.book(code: code) {
                let run = Array(verses[start..<end])
                let references = VerseRuns.references(run)
                groups.append(VerseGroup(book: book, count: run.count, references: references,
                                         lines: VerseLines.lines(references, book: book)))
            }
            start = end
        }
        return groups
    }

    /// The page's own book first, apart; every other book after it, in canon order.
    static func split(_ verses: [VerseLocation], inBook book: String?) -> (here: VerseGroup?, elsewhere: [VerseGroup]) {
        let all = groups(verses)
        guard let book else { return (nil, all) }
        return (all.first { $0.book.id == book }, all.filter { $0.book.id != book })
    }
}
