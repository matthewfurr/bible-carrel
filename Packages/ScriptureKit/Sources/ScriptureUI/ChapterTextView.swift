#if os(macOS)
import AppKit
import ScriptureData
import SwiftUI

/// SwiftUI wrapper around `ChapterTextController`'s TextKit 2 scroll view: one chapter as a page.
struct ChapterTextView: NSViewRepresentable {
    let layout: BookLayout?
    let typography: ReaderTypography
    let scrollTarget: ScrollTarget?
    /// The reading position, as the controller measures it.
    let onReadingPositionChange: (VerseLocation) -> Void
    var markup: ReaderMarkup? = nil
    /// The running head strip's height over the text; 0 until the strip exists.
    var headLineY: CGFloat = 0
    /// The controller's running head (the open chapter, its progress, the head's opacity).
    var onRunningHeadChange: (RunningHeadState) -> Void = { _ in }
    /// The controller's scroll since the last jump, in lines, for `NavigationModel`.
    var onScrollSinceJump: (Double, ScrollTarget) -> Void = { _, _ in }
    /// The chapter's number of chapter notes, by chapter, for the mark on its opening line.
    var chapterNoteCounts: [Int: Int] = [:]
    /// A click on the chapter's note mark, with its chapter.
    var onShowChapterNotes: (Int) -> Void = { _ in }
    /// The whole running head's height: the scroller's track starts below it.
    var scrollerTopInset: CGFloat = 0
    /// Space kept below the chapter's text for the footer links laid over the scroll's foot.
    var bottomInset: CGFloat = 0
    /// How much of `bottomInset` is in view (0 to 1), for the footer links.
    var onFootReveal: (Double) -> Void = { _ in }
    /// Whether the book thumb shows (`ThumbRevealTracker`): the pointer near the right edge, or
    /// a landing a moment ago.
    var onThumbReveal: (Bool) -> Void = { _ in }
    /// Where the thumb's loupe asks for the page behind it; the controller draws it.
    var backdrop: PageBackdrop?
    /// Asks the reader's text to take keyboard focus (`ReaderFocusRule`); a new request each time.
    var focusRequest: ReaderFocusRequest? = nil
    /// The verse panel to show in a popover on its selection's first line; nil closes it.
    var versePanel: VersePanelPresentation? = nil

    func makeCoordinator() -> ChapterTextController {
        ChapterTextController(onReadingPositionChange: onReadingPositionChange)
    }

    /// The reader going away (Home) takes its popover with it.
    /// The reader is leaving, so the keyboard is not handed back to it.
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: ChapterTextController) {
        coordinator.versePanel?.dismiss()
        coordinator.versePanel = nil
    }

    func makeNSView(context: Context) -> NSScrollView {
        // A view made again (Home and back) acts only on a request made after it.
        context.coordinator.appliedFocusRequest = focusRequest
        return context.coordinator.scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator
        controller.onReadingPositionChange = onReadingPositionChange
        // These are also reported from inside this update (a new layout or size), where SwiftUI
        // state must not change, so they land on the next turn of the main queue; the queue is
        // serial, so the values arrive in order.
        let onRunningHeadChange = onRunningHeadChange
        controller.onRunningHeadChange = { state in DispatchQueue.main.async { onRunningHeadChange(state) } }
        let onFootReveal = onFootReveal
        controller.onFootReveal = { reveal in DispatchQueue.main.async { onFootReveal(reveal) } }
        // The same: it can end a lookup, which changes observed state.
        let onScrollSinceJump = onScrollSinceJump
        controller.onScrollSinceJump = { lines, target in DispatchQueue.main.async { onScrollSinceJump(lines, target) } }
        // A scroll the update itself makes (a landing) reports it too, so it lands next turn.
        let onThumbReveal = onThumbReveal
        controller.thumbReveal.onChange = { revealed in DispatchQueue.main.async { onThumbReveal(revealed) } }
        backdrop?.capture = { [weak controller] frame, _ in controller?.pagePicture(under: frame) }
        controller.onSelectionChange = markup?.onSelectionChange ?? { _ in }
        if let provider = markup?.menuProvider {
            controller.menuProvider = { [unowned controller] report in provider(report, controller) }
        } else {
            controller.menuProvider = { _ in nil }
        }
        if let onKey = markup?.onKey {
            controller.onReaderKey = { [unowned controller] action, report in onKey(action, report, controller) }
        } else {
            controller.onReaderKey = { _, _ in false }
        }
        controller.keysAreLive = markup?.keysAreLive ?? { true }
        controller.headLineY = headLineY
        controller.scrollerTopInset = scrollerTopInset
        // Before the text, so a new chapter's layout is sized with it once.
        controller.bottomInset = bottomInset
        controller.onShowChapterNotes = onShowChapterNotes
        controller.update(layout: layout, typography: typography, scrollTarget: scrollTarget, decorations: markup?.decorations ?? .none)
        // After the text: the mark is placed on the layout just applied.
        controller.chapterNoteCounts = chapterNoteCounts
        controller.apply(focusRequest)
        // After the text, so the anchor is measured on the layout just applied.
        controller.apply(versePanel)
    }
}
#endif
