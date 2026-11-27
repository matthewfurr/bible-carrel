#if os(macOS)
import AppKit
import SwiftUI

/// The system popover a presentation is shown in, with the request it shows. Its delegate tells
/// the presentation's `onClose` when the reader closed it, never when `apply` did.
@MainActor final class VersePanelPopover: NSObject, NSPopoverDelegate {
    let popover = NSPopover()
    let requestID: UUID
    /// The verses it hangs from, in the reader's text.
    let range: NSRange
    /// The page's scroll (the clip's top) while it is up: a scroll away from it closes it
    /// (`versePanelPageMoved`).
    var pageY: CGFloat = 0
    /// Cleared before `apply` closes it, so only the reader's close is reported.
    var onClose: (() -> Void)?
    /// On the screen: from a show that put it up until it closes, however it closes.
    private(set) var isUp = false

    init(_ presentation: VersePanelPresentation) {
        requestID = presentation.request.id
        range = presentation.request.range
        onClose = presentation.onClose
        super.init()
        // Sized by its content: 360 pt wide, up to 480 tall (`VersePanelLayout`). The page face and
        // Sepia follow the reader's settings, as at every root hosted in AppKit.
        let host = NSHostingController(rootView: presentation.content.followsPageFace().followsSepia())
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.delegate = self
    }

    /// Shows it through `present` (which says whether it is up). Up, the keyboard rests on the
    /// popover itself; not up, it is closed as the reader's close, so the request clears.
    func show(_ present: (NSPopover) -> Bool) {
        isUp = present(popover)
        if isUp {
            restFocusOnPanel()
        } else {
            closeAsReader()
        }
    }

    /// Called once, when the reader closes it (Esc, a click outside, a show that failed), with the
    /// popover's own window: the controller hands the keyboard back (`versePanelClosedByReader`). A panel
    /// `apply` dismisses or replaces never calls it, so a late close cannot take the keyboard from
    /// whatever is up by then; `apply(nil)` hands it back itself.
    var onDown: ((NSWindow?) -> Void)?
    /// The popover's own window, while it has one: the hand-back lets it be the key window it takes
    /// key status from, however the popover went down.
    private(set) weak var popoverWindow: NSWindow?

    /// The keyboard rests on the popover's hosting view, in the popover's own window, never the
    /// reader's. Inside it, SwiftUI's focus rests on the panel itself (`VersePanelLayout`), which
    /// draws no ring; Tab and Shift-Tab walk the controls; Esc reaches the popover. Done as it is
    /// shown and again once it has appeared, since AppKit may choose its first responder as the
    /// popover's window becomes key.
    private func restFocusOnPanel() {
        guard let view = popover.contentViewController?.view, let window = view.window else { return }
        popoverWindow = window
        window.makeFirstResponder(view)
    }

    func popoverDidShow(_ notification: Notification) {
        restFocusOnPanel()
    }

    /// Esc or a click outside closed it (`behavior` is `.transient`), or a close below has finished.
    func popoverDidClose(_ notification: Notification) {
        wentDown()
        reportClose()
    }

    /// Closes it as the reader's close: `onClose` is told.
    func closeAsReader() {
        popover.close()
        wentDown()
        reportClose()
    }

    /// Closes it without telling `onClose` or `onDown`: `apply` replaced it or took it away.
    func dismiss() {
        onClose = nil
        onDown = nil
        isUp = false
        popover.close()
    }

    private func wentDown() {
        isUp = false
        guard let onDown else { return }
        self.onDown = nil
        onDown(popoverWindow)
    }

    /// Once: it changes SwiftUI state, and a close can come from inside a view update, so on the next turn.
    private func reportClose() {
        guard let onClose else { return }
        self.onClose = nil
        DispatchQueue.main.async { onClose() }
    }
}

extension ChapterTextController {
    /// Shows the popover for a new request, closes it for nil, and leaves one already showing alone.
    /// A request already shown, or already closed by the reader while its `onClose` is on its way,
    /// is not shown again. A show that does not put it up closes it as the reader's close, so the
    /// request clears and the keys stay live. **(call)** The chevrons do not move it: it stays on the selection.
    func apply(_ presentation: VersePanelPresentation?) {
        guard let presentation else {
            guard let panel = versePanel else { return }
            let wasUp = panel.isUp
            let closing = panel.popoverWindow
            panel.dismiss()
            versePanel = nil
            // A row, Open, Ask or the chapter changing took it away: the keyboard comes back by the
            // rule, and the window is made key again from the popover's, still key as it fades.
            if wasUp { versePanelWentDown(from: closing) }
            return
        }
        guard versePanel?.requestID != presentation.request.id, textView.window != nil else { return }
        versePanel?.dismiss()
        let panel = VersePanelPopover(presentation)
        // What holds the reader window's keyboard as it goes up: the reader's own close hands back
        // only while it still does.
        let heldWhenUp = textView.window?.firstResponder
        panel.onDown = { [weak self, weak heldWhenUp] window in self?.versePanelClosedByReader(from: window, heldWhenUp: heldWhenUp) }
        versePanel = panel
        panel.pageY = scrollView.contentView.bounds.minY
        let anchor = versePanelAnchor(for: presentation.request.range)
        panel.show { [presentVersePanel, textView] popover in presentVersePanel(popover, anchor, textView) }
    }

    /// A popover is up: no reader key acts on the verse behind it. Esc closes it as the reader's
    /// close (its `onClose`, the selection kept); every other key is swallowed. While the popover's
    /// own window holds the keyboard the reader's text sees no key at all. Once it is down (closed
    /// by the reader, or never shown) the keys act again, before `apply(nil)` arrives.
    func swallowsKeyForVersePanel(_ action: ReaderKeyAction) -> Bool {
        guard let versePanel, versePanel.isUp else { return false }
        if action == .clearSelection { versePanel.closeAsReader() }
        return true
    }

    /// The reader closed it (Esc, a click outside, a show that failed). A click outside that moved the
    /// reader window's keyboard off what held it as the panel went up (a row of the notes column) keeps
    /// it, and nothing is handed back: that click already made the window key. Otherwise as `versePanelWentDown`.
    func versePanelClosedByReader(from popoverWindow: NSWindow?, heldWhenUp: NSResponder?) {
        guard textView.window?.firstResponder === heldWhenUp else { return }
        versePanelWentDown(from: popoverWindow)
    }

    /// A popover went down (the reader's close, or `apply(nil)` for a row, Open, Ask or the chapter
    /// changing): the reader's text takes the keyboard back by `ReaderFocusRule`, as for a closed
    /// palette, so it never takes it from a field being typed in (the assistant's composer Ask focuses,
    /// a note's editor, a field a click outside landed in). Settled on the next turn (`requestFocus`).
    /// Then the reader's window is made key again, whatever holds its keyboard (the composer is in the
    /// same window, so it keeps it), but only while no popover is up (`makeReaderWindowKey`, which
    /// asks `takesKey` of AppKit's state).
    func versePanelWentDown(from popoverWindow: NSWindow?) {
        guard versePanel?.isUp != true else { return }
        requestFocus(.versePanelClosed)
        DispatchQueue.main.async { [weak self, weak popoverWindow] in
            guard let self, self.versePanel?.isUp != true, let window = self.textView.window else { return }
            self.makeReaderWindowKey(window, popoverWindow)
        }
    }

    /// AppKit's part of the hand-back: `window` is made key when `takesKey` says so.
    static func makeKeyAfterVersePanel(_ window: NSWindow, closingPopover: NSWindow?) {
        guard takesKey(appIsActive: NSApp.isActive, isVisible: window.isVisible, isKey: window.isKeyWindow,
                       keyWindow: NSApp.keyWindow, closingPopover: closingPopover)
        else { return }
        window.makeKey()
    }

    /// The reader's window takes key status back only while the app is active, it is on screen and
    /// not key already, and no other window holds key status but the closing popover's own.
    static func takesKey(appIsActive: Bool, isVisible: Bool, isKey: Bool, keyWindow: NSWindow?, closingPopover: NSWindow?) -> Bool {
        appIsActive && isVisible && !isKey && (keyWindow == nil || keyWindow === closingPopover)
    }

    /// The page scrolled under an open popover: it closes, as the reader's close, since it hangs from a
    /// line that has moved. A move along the keys' reveal (J, then C before the scroll had landed) is
    /// part of its opening: the popover follows its line instead.
    func versePanelPageMoved(alongTheKeys: Bool) {
        guard let versePanel, versePanel.isUp else { return }
        let y = scrollView.contentView.bounds.minY
        if alongTheKeys {
            versePanel.pageY = y
            // AppKit moves a popover on the screen to a new rect, and throws for one it is not showing.
            if versePanel.popover.isShown { versePanel.popover.positioningRect = versePanelAnchor(for: versePanel.range) }
        } else if abs(y - versePanel.pageY) > 0.5 {
            versePanel.closeAsReader()
        }
    }

    /// The page was laid out again under an open popover (a text size, a page style or a translation;
    /// the column reflowed or recentred for the notes column or a resized window): it closes, as the
    /// reader's close, as it does when the chapter changes.
    func versePanelPageLaidOut() {
        guard let versePanel, versePanel.isUp else { return }
        versePanel.closeAsReader()
    }

    /// The first line of `range`, at the height of its glyphs, held on the visible page under the head.
    func versePanelAnchor(for range: NSRange) -> NSRect {
        Self.versePanelAnchor(firstSegment: frameOfFirstSegment(of: range), visiblePage: visiblePage)
    }

    /// The first segment when it meets the page; above the page, a strip 1 pt tall at the page's top
    /// edge over the segment's x and width; below it, the same at the bottom edge; with no segment,
    /// a 1 pt square at the middle of the top edge. The text view is flipped: the top is `minY`.
    static func versePanelAnchor(firstSegment: NSRect?, visiblePage: NSRect) -> NSRect {
        guard let segment = firstSegment else {
            return NSRect(x: visiblePage.midX, y: visiblePage.minY, width: 1, height: 1)
        }
        if segment.intersects(visiblePage) { return segment }
        let y = segment.maxY <= visiblePage.minY ? visiblePage.minY : visiblePage.maxY - 1
        return NSRect(x: segment.minX, y: y, width: segment.width, height: 1)
    }

    /// AppKit's show: under the selection's first line; AppKit takes another edge when there is no
    /// room and keeps it on the screen. True when it is up.
    static func showVersePanel(_ popover: NSPopover, anchor: NSRect, of view: NSView) -> Bool {
        popover.show(relativeTo: anchor, of: view, preferredEdge: .maxY)
        return popover.isShown
    }
}
#endif
