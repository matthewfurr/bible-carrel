import Foundation
import Observation
import os
import ScriptureData

/// The book reader's shared layout: builds the one-chapter `BookLayout` for the chapter shown, so
/// both platforms' text controllers render the same layout. Headings and the title are fetched
/// once per book and translation; a failed headings fetch is retried on a later `show`, at most
/// once per `headingsRetryInterval`, and the chapter is rebuilt only when a retry succeeds.
@MainActor @Observable
public final class ReaderDocument {
    public private(set) var layout: BookLayout?
    /// The chapter shown, as a one-chapter range (the layout's `chapters`).
    public private(set) var window: ClosedRange<Int>?

    @ObservationIgnored private let store: BibleStore
    @ObservationIgnored private var book: BookText?
    @ObservationIgnored private var typography: ReaderTypography?
    @ObservationIgnored private var headings: [Int: [Int: [SectionHeading]]] = [:]
    @ObservationIgnored private var opening: BookOpening?
    /// The book-wide fingerprint of `opening` and `headings` (`BookLayoutID.content`).
    @ObservationIgnored private var content = 0
    /// When the last headings fetch failed, nil once one succeeds: a later `show` of the book
    /// retries no sooner than `headingsRetryInterval` after it, instead of caching the gap.
    @ObservationIgnored private var headingsFailedAt: ContinuousClock.Instant?
    /// The least time between two headings fetches for a book whose fetch failed.
    @ObservationIgnored var headingsRetryInterval: Duration = .seconds(30)
    /// The section headings of a book in a translation (the store's, replaced in tests).
    @ObservationIgnored var fetchHeadings: (_ book: String, _ translationID: String) throws -> [VerseLocation: [SectionHeading]]
    /// The clock the retry is timed by (replaced in tests).
    @ObservationIgnored var now: () -> ContinuousClock.Instant = { ContinuousClock.now }
    @ObservationIgnored private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "reader")

    public init(store: BibleStore) {
        self.store = store
        fetchHeadings = { try store.headings(bookID: $0, translationID: $1) }
    }

    /// Shows `target`'s chapter alone (a target the book lacks is clamped into it). The layout is
    /// rebuilt only when the book, translation, chapter or typography changed, or a headings fetch
    /// that had failed succeeds on its retry.
    public func show(_ book: BookText, target: ChapterLocation, typography: ReaderTypography) {
        let sameBook = self.book.map { $0.book == book.book && $0.translationID == book.translationID } ?? false
        if !sameBook { loadExtras(for: book) }
        // A retry that succeeds changes the headings (and so the layout's id); one that fails
        // changes nothing and is not tried again for a while.
        let retryHeadings = sameBook && headingsFailedAt.map { now() - $0 >= headingsRetryInterval } == true && loadHeadings(for: book)
        self.book = book

        guard let first = book.chapters.keys.min(), let last = book.chapters.keys.max() else {
            window = nil
            layout = nil
            self.typography = typography
            return
        }

        let typographyChanged = self.typography?.layoutHash != typography.layoutHash
        self.typography = typography
        let chapter = min(max(target.chapter, first), last)
        let newWindow = chapter...chapter
        let chapterChanged = newWindow != window
        window = newWindow
        if !sameBook || retryHeadings || typographyChanged || chapterChanged || layout == nil {
            rebuild()
        }
    }

    // MARK: Private

    /// The opening verses of `chapter` of the book being shown, for the chapter switcher's card
    /// (`ChapterSwitcher.openingVerses`); none when the book has no such chapter.
    public func openingVerses(ofChapter chapter: Int) -> [ChapterSwitcher.Verse] {
        ChapterSwitcher.openingVerses(of: book?.chapters[chapter]?.map { .init(number: $0.id.verse, text: $0.text) } ?? [])
    }

    /// The opening verses of a chapter of another book, in `translationID`, for the switcher's
    /// card that opens a neighbouring book; none when the store has no such chapter.
    public func openingVerses(of location: ChapterLocation, translationID: String) -> [ChapterSwitcher.Verse] {
        let verses = (try? store.chapter(location, translationID: translationID)) ?? []
        return ChapterSwitcher.openingVerses(of: verses.map { .init(number: $0.id.verse, text: $0.text) })
    }

    private func inputs(_ book: BookText, chapters: ClosedRange<Int>) -> [BookChapterInput] {
        // A chapter the book lacks (a gap in its numbering) has no input, and so no layout.
        chapters.compactMap { chapter -> BookChapterInput? in
            guard let verses = book.chapters[chapter] else { return nil }
            return BookChapterInput(location: ChapterLocation(book: book.book, chapter: chapter),
                                    verses: verses, headings: headings[chapter] ?? [:])
        }
    }

    private func loadExtras(for book: BookText) {
        headings = [:]
        _ = loadHeadings(for: book)
        let name = BookCatalog.book(code: book.book)?.name ?? book.book
        let title: BookTitle
        do {
            title = try store.bookTitle(bookID: book.book, translationID: book.translationID)
        } catch {
            logger.error("Could not load the title of \(book.book) in \(book.translationID): \(error)")
            title = BookTitle(title: name, subtitle: nil)
        }
        opening = BookOpening(bookName: name, title: title)
        updateContent()
    }

    /// Fetches `book`'s headings. True when they were fetched (and replace the ones held); false,
    /// with the time noted for the retry, when the fetch failed.
    private func loadHeadings(for book: BookText) -> Bool {
        do {
            let all = try fetchHeadings(book.book, book.translationID)
            var grouped: [Int: [Int: [SectionHeading]]] = [:]
            for (location, list) in all {
                grouped[location.chapter, default: [:]][location.verse] = list
            }
            headings = grouped
            headingsFailedAt = nil
            updateContent()
            return true
        } catch {
            headingsFailedAt = now()
            logger.error("Could not load headings for \(book.book) in \(book.translationID): \(error)")
            return false
        }
    }

    private func updateContent() {
        guard let opening else { return }
        content = BookLayout.contentFingerprint(opening: opening, headings: headings.map { ($0.key, $0.value) })
    }

    private func rebuild() {
        guard let window, let book, let typography, let opening else { return }
        let inputs = inputs(book, chapters: window)
        guard !inputs.isEmpty else { layout = nil; return }
        layout = BookLayout.build(chapters: inputs, opening: opening, typography: typography, content: content)
    }
}
