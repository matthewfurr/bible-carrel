import Foundation
import Observation

/// What the page reports as the reader scrolls, for the chrome drawn around it: the running head
/// (the Mac's strip, the phone's bar title) and, on the Mac, how much of the chapter's foot is in
/// view and whether the book thumb's track shows. These change as the page scrolls, so they live
/// here rather than in the reader view's state, and each is observed on its own: the head's
/// opacity, the chapter's progress, the foot's reveal and the thumb's are separate properties,
/// read only by the small views that draw them (`RunningHeadFade`, `RunningHeadProgressLine`, the
/// Mac's foot links and book thumb). A frame that moves the
/// progress line redraws that line alone, never the reader around it (`ReaderView`, the phone's
/// reader screen) nor the head's text. Each property is assigned only when it changes.
/// Platform-neutral, so it is tested on the Mac.
@MainActor @Observable final class ReaderChrome {
    /// The chapter the text last reported the head for; nil until its first report, and again
    /// for another book.
    private(set) var headChapter: Int?
    private(set) var headProgress: Double = 0
    private(set) var headOpacity: Double = 0
    /// How much of the space kept under the chapter's text is in view (0 to 1), for the Mac's
    /// foot links (`ChapterTextController.onFootReveal`).
    private(set) var footReveal: Double = 0
    /// Whether the Mac's book thumb shows its track (`ChapterTextController.onThumbReveal`): a
    /// landing or the pointer at the edge brings it out; a scroll never does.
    private(set) var thumbRevealed = false

    /// The text's report on the running head.
    func report(_ state: RunningHeadState) {
        if headChapter != state.chapter { headChapter = state.chapter }
        if headProgress != state.progress { headProgress = state.progress }
        if headOpacity != state.headOpacity { headOpacity = state.headOpacity }
    }

    /// The page's last report on the head, nil before one; reading it observes all of it.
    var head: RunningHeadState? {
        headChapter.map { RunningHeadState(chapter: $0, progress: headProgress, headOpacity: headOpacity) }
    }

    /// The head's opacity over the open `chapter`: hidden until the text reports on that chapter
    /// (none yet, or a report left from the chapter before), as `RunningHeadTitle` has it.
    /// Observes the reported chapter and the opacity, not the progress.
    func headOpacity(for chapter: Int) -> Double {
        headChapter == chapter ? headOpacity : 0
    }

    /// The open `chapter`'s progress: none until the text reports on it. Observes the reported
    /// chapter and the progress, not the opacity.
    func headProgress(for chapter: Int) -> Double {
        headChapter == chapter ? headProgress : 0
    }

    /// The text's report on its foot.
    func reportFoot(_ reveal: Double) {
        if footReveal != reveal { footReveal = reveal }
    }

    /// The text's report on the book thumb's track.
    func reportThumbReveal(_ revealed: Bool) {
        if thumbRevealed != revealed { thumbRevealed = revealed }
    }

    /// New text (another chapter, translation or size): the old text's foot does not offer the
    /// new one's links; the text reports the new reveal afresh.
    func textChanged() {
        reportFoot(0)
    }

    /// Another book: the head waits for the new text's report rather than naming a chapter of
    /// the old one.
    func bookChanged() {
        headChapter = nil
    }
}
