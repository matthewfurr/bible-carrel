import Foundation
import ScriptureData

/// Highlights and bookmarks mapped onto a book layout's character ranges, with spans looked up by
/// `VerseLocation`. Pure data: the text controller draws it, the markup model builds it.
public struct BookDecorations: Equatable, Sendable {
    public static let none = BookDecorations(highlights: [], bookmarks: [], outlinedID: nil)

    public var highlights: [RangeDecoration]
    /// Verses with a bookmark, as their span's first verse, in layout order.
    public var bookmarks: [VerseLocation]
    /// The highlight to outline after a card click, if any.
    public var outlinedID: UUID?
    /// The layout the ranges were mapped onto (`build`'s); nil for decorations made by hand. The
    /// text controller ignores decorations mapped onto another layout than the one it shows.
    public var layoutID: BookLayoutID?

    public init(highlights: [RangeDecoration], bookmarks: [VerseLocation], outlinedID: UUID?, layoutID: BookLayoutID? = nil) {
        self.highlights = highlights
        self.bookmarks = bookmarks
        self.outlinedID = outlinedID
        self.layoutID = layoutID
    }

    /// Each highlight maps by the shared rule (`RangeDecoration.decoration(for:start:end:viewingTranslationID:)`).
    /// A highlight or bookmark on a verse (or chapter) the layout does not show is skipped.
    public static func build(
        itemsByChapter: [Int: [MarkupItem]],
        bookmarksByChapter: [Int: [Int]],
        outlinedID: UUID?,
        viewingTranslationID: String,
        layout: BookLayout
    ) -> BookDecorations {
        let book = layout.id.book
        let highlights = itemsByChapter.keys.sorted().flatMap { chapter in
            (itemsByChapter[chapter] ?? []).compactMap { item -> RangeDecoration? in
                guard let start = layout.span(for: VerseLocation(book: book, chapter: item.chapter, verse: item.verse)),
                      let end = layout.span(for: VerseLocation(book: book, chapter: item.chapter, verse: item.endVerse))
                else { return nil }
                return RangeDecoration.decoration(for: item, start: start, end: end, viewingTranslationID: viewingTranslationID)
            }
        }

        var seen = Set<VerseLocation>()
        let bookmarks = bookmarksByChapter.keys.sorted().flatMap { chapter in
            (bookmarksByChapter[chapter] ?? []).compactMap { layout.span(for: VerseLocation(book: book, chapter: chapter, verse: $0))?.location }
        }
        .filter { seen.insert($0).inserted }
        .sorted { ($0.chapter, $0.verse) < ($1.chapter, $1.verse) }
        return BookDecorations(highlights: highlights, bookmarks: bookmarks, outlinedID: outlinedID, layoutID: layout.id)
    }

    /// Decorations touched by a selection; a caret (zero length) counts when it sits inside or at
    /// either end of a decoration.
    public func ids(intersecting range: NSRange) -> [UUID] {
        highlights.ids(intersecting: range)
    }

    public func decoration(id: UUID) -> RangeDecoration? {
        highlights.decoration(id: id)
    }
}
