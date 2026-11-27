#if os(iOS)
import CoreGraphics

/// The phone's book thumb under its edge press (spec 4.4), apart from the gesture: the chapter
/// under the finger for each of the press's heights (on the track, wherever it lies in the
/// page), what the hand should feel (the grab, each chapter passed), and where letting go lands.
///
/// The press begins wherever the finger happens to rest on the edge, so the chapter under it then
/// is no choice: a press that never moves off the chapter it began on lands nowhere when it
/// lifts (final review I2). Once it has moved to another chapter it is choosing: letting go opens
/// the chapter under it, the one it began on included (Matt, 2026-11-13: away and back is a
/// choice), and never the chapter being read.
enum PhoneThumbScrub {
    /// A press under way (shared with the Mac's ruler).
    typealias Press = BookThumb.Press

    /// What the hand feels at a step.
    enum Haptic: Equatable {
        /// The hold took: the thumb is in hand.
        case grabbed
        /// The press moved onto another chapter.
        case chapterPassed
    }

    struct Step: Equatable {
        /// The chapter under the press, or nil once it is over.
        let dragging: Int?
        /// The press, while it goes on; nil once it is over.
        let press: Press?
        let haptic: Haptic?
        /// Letting go on a chapter chosen: open it. Nil on the chapter being read, for a press
        /// that never left the chapter it began on, and while the press goes on.
        let landing: Int?
    }

    /// The step `gesture` takes the thumb from `dragging`, for `press`, the press's heights read
    /// on `track` (both in the page's coordinates). A track not yet laid out reads as the chapter
    /// being read, so nothing lands; cancelling hides the thumb and lands nowhere.
    static func step(_ gesture: ThumbGesture, dragging: Int?, press: Press?, thumb: BookThumb, track: CGRect) -> Step {
        func chapter(_ y: CGFloat) -> Int {
            BookThumbView.chapter(forY: y - track.minY, inTrackHeight: track.height, thumb: thumb)
        }
        switch gesture {
        case .began(let y):
            let first = chapter(y)
            return Step(dragging: first, press: Press(start: first), haptic: .grabbed, landing: nil)
        case .moved(let y):
            let next = chapter(y)
            var press = press
            press?.moved(to: next)
            return Step(dragging: next, press: press, haptic: dragging != nil && next != dragging ? .chapterPassed : nil, landing: nil)
        case .ended(let y):
            let last = chapter(y)
            let chose = press?.chooses(releasingOn: last) ?? false
            return Step(dragging: nil, press: nil, haptic: nil, landing: chose && thumb.landing(on: last) != nil ? last : nil)
        case .cancelled:
            return Step(dragging: nil, press: nil, haptic: nil, landing: nil)
        }
    }
}
#endif
