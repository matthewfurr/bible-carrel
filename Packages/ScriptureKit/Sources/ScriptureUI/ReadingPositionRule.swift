import CoreGraphics
import Foundation
import ScriptureData

/// The book readers' platform-neutral decisions about where the reader is, shared by the Mac's
/// and the phone's text controllers so a fix lands once. Each controller supplies only geometry
/// (line frames, the head's line, whether the page is at its foot).

extension BookLayout {
    /// The index of `chapter`'s section (the layout's chapters are consecutive; scanned if not).
    func sectionIndex(of chapter: Int) -> Int? {
        let index = chapter - chapters.lowerBound
        guard sections.indices.contains(index), sections[index].location.chapter == chapter else {
            return sections.firstIndex { $0.location.chapter == chapter }
        }
        return index
    }

    /// The character a chapter-note mark sits beside on `section`'s opening: its last one that is
    /// not Study's hairline paragraph, so the mark sits by the label rather than on the rule drawn
    /// under it (Lectern's is its opening's hairline, `marksAboveOpeningLine`).
    func openingMarkLineIndex(of section: BookSection) -> Int {
        let opening = section.openingRange
        var index = NSMaxRange(opening) - 1
        while index > opening.location, attributedString.readerRole(at: index) == .rule {
            index -= 1
        }
        return index
    }

    /// True when `section`'s mark line is Lectern's hairline opening, the chapter's text (and its
    /// drop numeral) starting just below it: the chapter-note mark then sits in the air above that
    /// line, at the column's trailing edge, rather than across the text's first line.
    func marksAboveOpeningLine(of section: BookSection) -> Bool {
        switch attributedString.readerRole(at: openingMarkLineIndex(of: section)) {
        case .dropNumeral, .chapterStart: return true
        default: return false
        }
    }
}

extension ChapterBand {
    /// The open chapter's opening and text (the layout's first, and on a page its only, section),
    /// measured from line frames. `lineFrame` gives the frame of the line holding a character, in
    /// text-container coordinates; `inset` is the text's distance from the view's top.
    /// An opening whose line cannot be found starts at the inset.
    static func band(for layout: BookLayout, inset: CGFloat, lineFrame: (Int) -> CGRect?) -> ChapterBand? {
        guard let section = layout.sections.first else { return nil }
        let opening = section.openingRange
        let firstText = section.spans.first?.fullRange.location ?? section.range.location
        let openingTop = lineFrame(opening.location).map { $0.minY + inset } ?? inset
        let openingBottom = lineFrame(NSMaxRange(opening) - 1).map { $0.maxY + inset } ?? openingTop
        let lastText = section.spans.last.map { max($0.fullRange.location, NSMaxRange($0.textRange) - 1) } ?? firstText
        let textBottom = lineFrame(lastText).map { $0.maxY + inset } ?? openingBottom
        return ChapterBand(chapter: section.location.chapter, openingMinY: openingTop, openingMaxY: openingBottom, textMaxY: textBottom)
    }
}

extension RunningHead {
    /// Allowance for a scroll rounded to the screen's pixels, so a jump that lands an opening
    /// exactly on the head's line counts as having reached it. Added to the head's line wherever
    /// it is compared with a band.
    static let headLineTolerance: CGFloat = 0.5
}

/// The reading position the book readers report, from the first visible verse and the last jump:
/// the rule that keeps the reported position, the running head and the window title naming the
/// same verse.
enum ReadingPositionRule {
    /// - Parameters:
    ///   - firstVisible: the verse of the first fully visible line below the head's line.
    ///   - landed: the verse the last jump or restore landed on, while it stands.
    /// - Returns: the position to report, and the landed verse that still stands (nil once the
    ///   reader has moved off it).
    ///
    /// A landed verse inside the first visible span is reported: a combined verse ("14-15")
    /// reports the verse asked for. Anything else is the first visible verse, as on `main`.
    static func resolve(firstVisible: VerseLocation, landed: VerseLocation?,
                        layout: BookLayout) -> (position: VerseLocation, landed: VerseLocation?) {
        guard let verse = landed, verse != firstVisible else { return (firstVisible, landed) }
        if verse.chapter == firstVisible.chapter, layout.span(for: firstVisible)?.contains(verse: verse.verse) == true {
            return (verse, verse)
        }
        return (firstVisible, nil)
    }
}
