import Foundation
import ScriptureData

/// J or ⇧J (`next`), K or ⇧K (`previous`).
public enum VerseStep: Sendable { case next, previous }

/// The verse rules both readers share: which verses a selection touches, which verse a tap is on,
/// and where J, K, ⇧J and ⇧K go. Pure functions of a book layout, free of AppKit and UIKit.
extension ReaderTextLogic {
    /// The verses of one chapter a selection touches. A range: every span whose number or text it
    /// intersects, kept to the first one's chapter. A caret: the one span whose number or text it
    /// is in or at the end of (the span starting at the caret wins over the one ending there).
    public static func verses(touching selection: NSRange, in layout: BookLayout) -> [VerseSpan] {
        guard selection.location != NSNotFound, selection.location >= 0 else { return [] }
        if selection.length == 0 {
            return candidates(at: selection.location, in: layout).first.map { [$0] } ?? []
        }
        let touched = layout.spans.filter {
            NSIntersectionRange(selection, $0.numberRange).length > 0 || NSIntersectionRange(selection, $0.textRange).length > 0
        }
        guard let chapter = touched.first?.location.chapter else { return [] }
        return touched.filter { $0.location.chapter == chapter }
    }

    /// The verse a tap or click that resolved to `index` is on: the span containing `index`, else
    /// the span ending at `index`, the first for which `isOnLines` holds.
    public static func verse(at index: Int, in layout: BookLayout, isOnLines: (VerseSpan) -> Bool) -> VerseSpan? {
        candidates(at: index, in: layout).first(where: isOnLines)
    }

    /// J and K: the text range of the verse after the selection's last verse, or before its first.
    /// With no verse touched (`selection` nil, or a caret in an opening or a heading), the text
    /// range of `firstVisible`. Nil at the chapter's last or first verse.
    public static func verseStep(_ step: VerseStep, from selection: NSRange?, firstVisible: VerseLocation?,
                                 in layout: BookLayout) -> NSRange? {
        let touched = selection.map { verses(touching: $0, in: layout) } ?? []
        guard let first = touched.first, let last = touched.last else {
            return firstVisible.flatMap { layout.span(for: $0) }?.textRange
        }
        guard let spans = layout.section(for: first.location.chapter)?.spans else { return nil }
        switch step {
        case .next:
            guard let index = spans.firstIndex(of: last), spans.indices.contains(index + 1) else { return nil }
            return spans[index + 1].textRange
        case .previous:
            guard let index = spans.firstIndex(of: first), index > 0 else { return nil }
            return spans[index - 1].textRange
        }
    }

    /// ⇧J and ⇧K: the selection with its free end moved one verse, as Shift and an arrow key do in
    /// a list. `anchor` is a character index in the verse that stays selected (nil: the first
    /// touched verse for `next`, the last for `previous`). Returns whole verses, from the first
    /// one's `textRange` start to the last one's end, and the anchor to keep. With no verse
    /// touched it is `verseStep`. Nil when the free end cannot move within the chapter.
    public static func verseExtension(_ step: VerseStep, of selection: NSRange?, anchor: Int?,
                                      firstVisible: VerseLocation?, in layout: BookLayout) -> (range: NSRange, anchor: Int)? {
        let touched = selection.map { verses(touching: $0, in: layout) } ?? []
        guard let first = touched.first, let last = touched.last else {
            return verseStep(step, from: selection, firstVisible: firstVisible, in: layout).map { ($0, $0.location) }
        }
        guard let spans = layout.section(for: first.location.chapter)?.spans,
              let firstIndex = spans.firstIndex(of: first), let lastIndex = spans.firstIndex(of: last) else { return nil }
        let held = anchor.flatMap { index in touched.first { NSLocationInRange(index, $0.fullRange) } }
        let anchorSpan = held ?? (step == .next ? first : last)
        guard let anchorIndex = spans.firstIndex(of: anchorSpan) else { return nil }
        let free = (anchorIndex == firstIndex ? lastIndex : firstIndex) + (step == .next ? 1 : -1)
        guard spans.indices.contains(free) else { return nil }
        let low = spans[min(anchorIndex, free)], high = spans[max(anchorIndex, free)]
        let range = NSRange(location: low.textRange.location, length: NSMaxRange(high.textRange) - low.textRange.location)
        return (range, held == nil ? anchorSpan.textRange.location : anchor ?? anchorSpan.textRange.location)
    }

    /// The spans a point resolved to `index` may be on, best first: the one containing it, then the
    /// one ending at it.
    private static func candidates(at index: Int, in layout: BookLayout) -> [VerseSpan] {
        guard index != NSNotFound, index >= 0 else { return [] }
        var found: [VerseSpan] = []
        if let containing = layout.span(containing: index) { found.append(containing) }
        if index > 0, let ending = layout.span(containing: index - 1), NSMaxRange(ending.textRange) == index,
           ending != found.first {
            found.append(ending)
        }
        return found
    }
}
