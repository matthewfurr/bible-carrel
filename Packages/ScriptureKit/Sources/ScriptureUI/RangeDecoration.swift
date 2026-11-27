import Foundation

public enum DecorationStyle: Equatable, Sendable {
    case background(MarkupColor)
    /// A note anchor without a color.
    case dottedUnderline
    /// A highlight made in another translation: whole verses, since offsets cannot be mapped.
    case dashedUnderline
}

public struct RangeDecoration: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let range: NSRange
    public let style: DecorationStyle

    public init(id: UUID, range: NSRange, style: DecorationStyle) {
        self.id = id
        self.range = range
        self.style = style
    }

    /// The highlight-mapping rule `BookDecorations` applies: a highlight in the viewing
    /// translation covers its exact offsets, clamped to its verses (`start` and `end` render
    /// `item.verse` and `item.endVerse`), with its color or, without one, a dotted underline; one
    /// made in another translation underlines its whole verses, since offsets cannot be mapped.
    /// Nil when the range comes out empty.
    static func decoration(for item: MarkupItem, start: VerseSpan, end: VerseSpan, viewingTranslationID: String) -> RangeDecoration? {
        if item.translationID == viewingTranslationID {
            let from = start.textRange.location + min(max(item.startOffset, 0), start.textRange.length)
            let to = end.textRange.location + min(max(item.endOffset, 0), end.textRange.length)
            guard to > from else { return nil }
            return RangeDecoration(id: item.id, range: NSRange(location: from, length: to - from),
                                   style: item.color.map { .background($0) } ?? .dottedUnderline)
        }
        let to = NSMaxRange(end.textRange)
        guard to > start.textRange.location else { return nil }
        return RangeDecoration(id: item.id, range: NSRange(location: start.textRange.location, length: to - start.textRange.location),
                               style: .dashedUnderline)
    }
}

extension Array where Element == RangeDecoration {
    /// Decorations touched by a selection; a caret (zero length) counts when it sits inside or at
    /// either end of a decoration.
    func ids(intersecting range: NSRange) -> [UUID] {
        filter { decoration in
            if range.length == 0 {
                return range.location >= decoration.range.location && range.location <= NSMaxRange(decoration.range)
            }
            return NSIntersectionRange(range, decoration.range).length > 0
        }.map(\.id)
    }

    func decoration(id: UUID) -> RangeDecoration? {
        first { $0.id == id }
    }
}
