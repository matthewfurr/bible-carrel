import Foundation
import ScriptureData

/// A mark in the reader's right margin on the phone, which has no notes column: one per note on a
/// highlight, on the line where the highlight starts, and one per bookmark, on its verse's first
/// line. A chapter note has none. Platform-neutral data; the phone's text controller places it.
public struct MarginMark: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case note(noteID: UUID, highlightID: UUID?), bookmark }
    /// `"note:<uuid>"` or `"bookmark:<chapter>:<verse>"`, unique across the chapter shown.
    public let id: String
    public let kind: Kind
    /// The verse the mark is on (its span's first verse).
    public let verse: VerseLocation
    /// Where in the layout the mark's line is found.
    public let characterIndex: Int

    /// Every mark in the chapter shown, sorted by `characterIndex`, a note before a bookmark at the
    /// same index. The dictionaries are the markup model's, keyed by chapter; a chapter the layout
    /// does not show has no marks, nor do a chapter note, a draft card, a note whose highlight is
    /// not in `itemsByChapter` or not in the layout, and a bookmark on a verse the layout lacks.
    public static func build(notesByChapter: [Int: [NoteCard]], itemsByChapter: [Int: [MarkupItem]],
                             bookmarksByChapter: [Int: [Int]], layout: BookLayout) -> [MarginMark] {
        let book = layout.id.book
        var marks: [MarginMark] = []
        for chapter in notesByChapter.keys.sorted() {
            marks += noteMarks(cards: notesByChapter[chapter] ?? [], items: itemsByChapter[chapter] ?? []) { item in
                layout.span(for: VerseLocation(book: book, chapter: item.chapter, verse: item.verse))
            }
        }
        let bookmarkSpans = bookmarksByChapter.keys.sorted().flatMap { chapter in
            (bookmarksByChapter[chapter] ?? []).compactMap { layout.span(for: VerseLocation(book: book, chapter: chapter, verse: $0)) }
        }
        return sorted(marks + bookmarkMarks(bookmarkSpans))
    }

    private static func noteMarks(cards: [NoteCard], items: [MarkupItem], span: (MarkupItem) -> VerseSpan?) -> [MarginMark] {
        cards.compactMap { card in
            guard !card.isChapterNote, !card.isDraft, let highlightID = card.highlightID,
                  let item = items.first(where: { $0.id == highlightID }),
                  let span = span(item)
            else { return nil }
            let offset = min(max(item.startOffset, 0), span.textRange.length)
            return MarginMark(id: "note:\(card.id.uuidString)", kind: .note(noteID: card.id, highlightID: highlightID),
                              verse: span.location, characterIndex: span.textRange.location + offset)
        }
    }

    /// One mark per span, however many of its verses are bookmarked.
    private static func bookmarkMarks(_ spans: [VerseSpan]) -> [MarginMark] {
        var seen = Set<VerseLocation>()
        return spans.compactMap { span in
            guard seen.insert(span.location).inserted else { return nil }
            return MarginMark(id: "bookmark:\(span.location.chapter):\(span.location.verse)", kind: .bookmark,
                              verse: span.location, characterIndex: span.textRange.location)
        }
    }

    private static func sorted(_ marks: [MarginMark]) -> [MarginMark] {
        marks.enumerated().sorted { a, b in
            if a.element.characterIndex != b.element.characterIndex { return a.element.characterIndex < b.element.characterIndex }
            if a.element.isNote != b.element.isNote { return a.element.isNote }
            return a.offset < b.offset
        }.map(\.element)
    }

    var isNote: Bool {
        if case .note = kind { true } else { false }
    }
}
