import Foundation
import ScriptureData

/// The reader's rules for a selection in a book layout's text, free of AppKit and UIKit so the
/// Mac's text view and the phone's (and its pen) apply the same ones.
public enum ReaderTextLogic {
    /// The range grown or shrunk to whole words, excluding verse numbers and separators; nil when it covers no word.
    ///
    /// A word is a run of letters, digits and apostrophes (`'` and `’`) inside a verse's text, so
    /// "LORD's" stays whole. Each end grows outward to the edge of the word it touches; an end in a
    /// verse number, a separator, white space or punctuation moves inward to the nearest word in
    /// the range. Punctuation attached to the first or last word (no white space between) then
    /// stays when the range covered it ("him." keeps its full stop, an opening quotation mark
    /// covered at the start stays) and is not added when the range stopped before it; white space
    /// and verse numbers at the ends are always trimmed. A range across verses
    /// stays one range from the first word's start to the last word's end, the verse number
    /// between them inside it. An empty range covers no word, and neither does one whose location
    /// is `NSNotFound` or outside the text; one running past the end is cut there. Snapping never
    /// crosses an opening: the range is cut at the end of the verse text of the chapter its first
    /// word is in, so a drag from one chapter into the next keeps to the first (as
    /// `SelectionResolver` does).
    ///
    /// The phone uses this. The Mac does not: `ChapterTextController` snaps with AppKit's own word
    /// selection (`selectionRange(forProposedRange:granularity: .selectByWord)`), which keeps some
    /// punctuation and snaps a drag over only a verse number to that number. Milestone 8 leaves the
    /// Mac's behaviour unchanged, so do not route the Mac through this without deciding to change it.
    public static func snapToWords(_ range: NSRange, in layout: BookLayout) -> NSRange? {
        snapToWords(range, in: layout.attributedString.string as NSString,
                    inVerseText: { layout.offsetWithinVerse(of: $0) != nil }) { start, end in
            guard let chapter = layout.offsetWithinVerse(of: start)?.span.location.chapter,
                  let last = layout.section(for: chapter)?.spans.last
            else { return end }
            return min(end, NSMaxRange(last.textRange))
        }
    }

    /// `snapToWords` over `text`, where `inVerseText` says which indexes are verse text and
    /// `limit` cuts the range's end once its first word (at the given index) is known.
    private static func snapToWords(_ range: NSRange, in text: NSString, inVerseText: (Int) -> Bool,
                                    limit: (_ firstWord: Int, _ end: Int) -> Int) -> NSRange? {
        // UIKit's text APIs return NSNotFound on failure, and `NSMaxRange` of that overflows: check
        // the location first, then cut the length at the end of the text without adding past it.
        guard range.length > 0, range.location != NSNotFound, range.location >= 0, range.location < text.length else { return nil }
        let rawEnd = range.length >= text.length - range.location ? text.length : range.location + range.length
        func isWord(_ index: Int) -> Bool { inVerseText(index) && isWordCharacter(text.character(at: index)) }

        guard var start = (range.location..<rawEnd).first(where: isWord) else { return nil }
        let end = limit(start, rawEnd)
        guard let last = (start..<end).last(where: isWord) else { return nil }
        var stop = last + 1
        while start > 0, isWord(start - 1) { start -= 1 }
        while stop < text.length, isWord(stop) { stop += 1 }
        // Covered punctuation touching the words stays: only within the raw range, so a word grown
        // outward past an end never gains the mark beyond it.
        func isPunctuation(_ index: Int) -> Bool { inVerseText(index) && isAttachedPunctuation(text.character(at: index)) }
        while start > range.location, isPunctuation(start - 1) { start -= 1 }
        while stop < end, isPunctuation(stop) { stop += 1 }
        return NSRange(location: start, length: stop - start)
    }

    /// The innermost highlight whose range contains `range` (a caret counts at either end).
    public static func innermostHighlight(containing range: NSRange, in decorations: BookDecorations) -> RangeDecoration? {
        innermostHighlight(containing: range, in: decorations.highlights)
    }

    private static func innermostHighlight(containing range: NSRange, in highlights: [RangeDecoration]) -> RangeDecoration? {
        highlights.ids(intersecting: range)
            .compactMap { highlights.decoration(id: $0) }
            .filter { $0.range.location <= range.location && NSMaxRange(range) <= NSMaxRange($0.range) }
            .min { $0.range.length < $1.range.length }
    }

    /// What the text controllers' selection reports are: the range resolved to verses, or nil
    /// when it covers no verse text. A caret inside a highlight reports the innermost containing
    /// highlight's range as the selection (and names it as primary); a caret elsewhere reports
    /// nothing. The selection is the chapter's its range starts in, and a drag past that chapter
    /// is cut at its last verse's text: the report's `range` and `highlightIDs` cover only the
    /// chapter the selection resolved to, so a highlight in the next chapter is not lit by a drag
    /// that stopped short of it in the selection.
    public static func report(for range: NSRange, layout: BookLayout, decorations: BookDecorations) -> SelectionReport? {
        guard range.length > 0 else {
            return report(for: range, highlights: decorations.highlights) { SelectionResolver.resolve($0, in: layout) }
        }
        guard let selection = SelectionResolver.resolve(range, in: layout),
              let spans = layout.section(for: selection.chapter)?.spans, let first = spans.first, let last = spans.last
        else { return nil }
        let extent = NSRange(location: first.fullRange.location, length: NSMaxRange(last.textRange) - first.fullRange.location)
        let clamped = NSIntersectionRange(range, extent)
        return SelectionReport(selection: selection, range: clamped, highlightIDs: decorations.highlights.ids(intersecting: clamped),
                               primaryHighlightID: innermostHighlight(containing: clamped, in: decorations.highlights)?.id)
    }

    private static func report(for range: NSRange, highlights: [RangeDecoration], resolve: (NSRange) -> TextSelection?) -> SelectionReport? {
        let ids = highlights.ids(intersecting: range)
        let primary = innermostHighlight(containing: range, in: highlights)
        if range.length == 0 {
            guard let primary, let selection = resolve(primary.range) else { return nil }
            return SelectionReport(selection: selection, range: range, highlightIDs: ids, primaryHighlightID: primary.id)
        }
        guard let selection = resolve(range) else { return nil }
        return SelectionReport(selection: selection, range: range, highlightIDs: ids, primaryHighlightID: primary?.id)
    }

    /// True for a UTF-16 unit that can be part of a word: a letter, digit or apostrophe.
    /// Surrogate halves count as letters.
    private static func isWordCharacter(_ unit: unichar) -> Bool {
        if unit == 0x27 || unit == 0x2019 { return true }
        guard let scalar = Unicode.Scalar(unit) else { return true }
        return CharacterSet.alphanumerics.contains(scalar)
    }

    /// True for a UTF-16 unit that is neither part of a word nor white space: a mark that can sit
    /// against a word.
    private static func isAttachedPunctuation(_ unit: unichar) -> Bool {
        guard !isWordCharacter(unit), let scalar = Unicode.Scalar(unit) else { return false }
        return !CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
