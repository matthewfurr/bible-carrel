import Foundation
import ScriptureData

/// Maps a text-view selection onto verse text: clips away verse numbers and the separators
/// between verses, trims whitespace at both ends, and builds the quoted text from `Verse.text`
/// slices (joined with a single space across verses) so numbers never leak into copies.
public enum SelectionResolver {
    /// The selection within one chapter of a book layout: the chapter is the one whose verse
    /// text the selection starts in (or, starting in an opening or between verses, the next verse
    /// text after it), and the range is clamped to that chapter's verses, so a selection never
    /// runs across an opening. Verse text is read from the layout's string, which holds each
    /// verse's text unchanged at its span's `textRange`.
    public static func resolve(_ range: NSRange, in layout: BookLayout) -> TextSelection? {
        guard range.location != NSNotFound, range.location >= 0 else { return nil }
        // The first span whose text ends after the selection starts names the chapter.
        var low = 0, high = layout.spans.count
        while low < high {
            let mid = (low + high) / 2
            if NSMaxRange(layout.spans[mid].textRange) > range.location { high = mid } else { low = mid + 1 }
        }
        guard low < layout.spans.count, let section = layout.section(for: layout.spans[low].location.chapter) else { return nil }
        let string = layout.attributedString.string as NSString
        return resolve(range, spans: section.spans, book: section.location.book, chapter: section.location.chapter) { span in
            string.substring(with: span.textRange) as NSString
        }
    }

    private static func resolve(_ range: NSRange, spans: [VerseSpan], book: String, chapter: Int,
                                text verseText: (VerseSpan) -> NSString) -> TextSelection? {
        guard !spans.isEmpty else { return nil }
        let end = NSMaxRange(range)
        // The first span whose text ends after the selection starts, and the last whose text starts before it ends.
        guard let startIndex = spans.firstIndex(where: { NSMaxRange($0.textRange) > range.location }),
              let endIndex = spans.lastIndex(where: { $0.textRange.location < end }),
              startIndex <= endIndex
        else { return nil }

        var startOffset = max(range.location, spans[startIndex].textRange.location) - spans[startIndex].textRange.location
        var endOffset = min(end, NSMaxRange(spans[endIndex].textRange)) - spans[endIndex].textRange.location
        var first = startIndex, last = endIndex

        // Trim whitespace at the ends, moving to the neighbouring verse when a whole slice goes.
        while first <= last {
            let text = verseText(spans[first])
            let sliceEnd = first == last ? endOffset : text.length
            startOffset = skippingWhitespace(in: text, from: startOffset, to: sliceEnd)
            if startOffset < sliceEnd { break }
            first += 1
            startOffset = 0
        }
        guard first <= last else { return nil }
        while last >= first {
            let text = verseText(spans[last])
            let sliceStart = last == first ? startOffset : 0
            endOffset = trailingNonWhitespaceEnd(in: text, from: sliceStart, to: endOffset)
            if endOffset > sliceStart { break }
            last -= 1
            endOffset = last >= first ? verseText(spans[last]).length : 0
        }
        guard first <= last, !(first == last && startOffset >= endOffset) else { return nil }

        var pieces: [String] = []
        for index in first...last {
            let text = verseText(spans[index])
            let from = index == first ? startOffset : 0
            let to = index == last ? endOffset : text.length
            pieces.append(text.substring(with: NSRange(location: from, length: to - from)))
        }

        return TextSelection(
            book: book,
            chapter: chapter,
            verse: spans[first].location.verse,
            endVerse: spans[last].location.verse,
            startOffset: startOffset,
            endOffset: endOffset,
            quotedText: pieces.joined(separator: " "))
    }

    /// The offsets a selection of whole verses resolves to, from the first verse's `first` text to
    /// the last's `last`: whitespace trimmed at both ends, as a J or ⇧J selection of them reports.
    static func wholeVerseOffsets(first: String, last: String) -> (start: Int, end: Int) {
        let first = first as NSString, last = last as NSString
        return (skippingWhitespace(in: first, from: 0, to: first.length),
                trailingNonWhitespaceEnd(in: last, from: 0, to: last.length))
    }

    private static func skippingWhitespace(in text: NSString, from: Int, to: Int) -> Int {
        var index = from
        while index < to, isWhitespace(text.character(at: index)) { index += 1 }
        return index
    }

    private static func trailingNonWhitespaceEnd(in text: NSString, from: Int, to: Int) -> Int {
        var index = to
        while index > from, isWhitespace(text.character(at: index - 1)) { index -= 1 }
        return index
    }

    private static func isWhitespace(_ unit: unichar) -> Bool {
        unit == 0x20 || unit == 0x0A || unit == 0x2028 || unit == 0x09
    }
}
