import CoreGraphics
import Foundation

/// Where a chapter sits vertically in the laid-out page, in the text view's coordinates: its
/// opening from `openingMinY` to `openingMaxY`, its text ending at `textMaxY`.
public struct ChapterBand: Equatable, Sendable {
    public let chapter: Int
    public let openingMinY: CGFloat
    public let openingMaxY: CGFloat
    public let textMaxY: CGFloat

    public init(chapter: Int, openingMinY: CGFloat, openingMaxY: CGFloat, textMaxY: CGFloat) {
        self.chapter = chapter
        self.openingMinY = openingMinY
        self.openingMaxY = openingMaxY
        self.textMaxY = textMaxY
    }
}

/// What the running head shows: the open chapter, how far through it the reader is (0 at its
/// opening, 1 at its end) and the head's own opacity.
public struct RunningHeadState: Equatable, Sendable {
    public let chapter: Int
    public let progress: Double
    public let headOpacity: Double

    public init(chapter: Int, progress: Double, headOpacity: Double) {
        self.chapter = chapter
        self.progress = progress
        self.headOpacity = headOpacity
    }
}

/// The running head's rules, in pure geometry. `headLineY` is the y of the head's line in the
/// same coordinates as the band.
public enum RunningHead {
    /// How far above the book opening's end the head starts fading in.
    public static let fadeDistance: CGFloat = 60
    /// The least scroll the fade takes when the title block is too short for `fadeDistance`.
    public static let minimumFade: CGFloat = 24

    /// The head for the open chapter's `band`. Its progress runs from the band's opening's end to
    /// its text's end, and is 1 at the page's foot (`atFoot`: the page scrolls and is scrolled to
    /// its end), where the chapter is read through though its last line never reaches the line.
    ///
    /// A page that opens on the book's title block (`opensWithTitle`, chapter 1) hides the head
    /// over it: there it fades in over the `fadeDistance` before the block's end reaches the
    /// line, so the block morphs into the head. A later chapter has no label on the page (Matt,
    /// 2026-11-13), so its head is fully opaque from the top.
    ///
    /// `topHeadLineY` is the head's line with the page scrolled to its top. The head is always
    /// hidden there: an opening too short for the whole `fadeDistance` (Classic's title block, a
    /// label) fades it in over the scroll that remains before its end, and one ending above that
    /// line (Lectern's hairline) over `minimumFade`. Under Reduce Motion the fade is a cut.
    public static func state(band: ChapterBand, headLineY: CGFloat, atFoot: Bool = false,
                             reducesMotion: Bool = false, topHeadLineY: CGFloat? = nil,
                             opensWithTitle: Bool = true) -> RunningHeadState {
        let progress: Double
        let length = band.textMaxY - band.openingMaxY
        if atFoot {
            progress = 1
        } else if length > 0 {
            progress = Double(clamp((headLineY - band.openingMaxY) / length))
        } else {
            progress = headLineY >= band.textMaxY ? 1 : 0
        }

        guard opensWithTitle else { return RunningHeadState(chapter: band.chapter, progress: progress, headOpacity: 1) }
        var fadeEnd = band.openingMaxY
        var fadeStart = fadeEnd - fadeDistance
        if let top = topHeadLineY {
            fadeEnd = max(fadeEnd, top + minimumFade)
            fadeStart = max(fadeEnd - fadeDistance, top)
        }
        let opacity = Double(clamp((headLineY - fadeStart) / (fadeEnd - fadeStart)))
        return RunningHeadState(chapter: band.chapter, progress: progress, headOpacity: cut(opacity, reducesMotion: reducesMotion))
    }

    /// Under Reduce Motion the title block's hand-over to the head is a cut (spec 3.2): the head
    /// (and, as `1 − opacity`, the opening's label) is hidden or shown, switching halfway through
    /// the fade's distance.
    public static func cut(_ opacity: Double, reducesMotion: Bool) -> Double {
        guard reducesMotion else { return opacity }
        return opacity >= 0.5 ? 1 : 0
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
