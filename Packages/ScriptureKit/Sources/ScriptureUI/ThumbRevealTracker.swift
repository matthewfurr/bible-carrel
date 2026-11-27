#if os(macOS)
import AppKit

/// When the Mac's book thumb shows (spec 4.4; Matt, 2026-11-13), decided in AppKit: the track
/// comes out when the pointer is within `BookThumbView.revealEdge` of the reader's right edge,
/// and when the reader lands on a chapter (a turn, a jump, the app opening), and goes `linger`
/// after the pointer has left the edge or the landing. Scrolling the page never brings it out.
///
/// It owns an `NSTrackingArea` on the reader's scroll view (`.mouseMoved`,
/// `.mouseEnteredAndExited`, `.activeInKeyWindow`, `.inVisibleRect`), so the pointer is followed
/// over the AppKit text and the SwiftUI thumb above it alike. `ChapterTextController` tells it
/// of each landing.
final class ThumbRevealTracker: NSResponder {
    /// Whether the track shows, reported when it changes.
    var onChange: (Bool) -> Void = { _ in }
    /// How long the track stays once nothing wants it, before it fades (`BookThumbView.fadeOut`);
    /// the tests shorten it. A call; Matt found one second too short.
    var linger: TimeInterval = 2.5

    private(set) var isRevealed = false
    private(set) var isPointerNearEdge = false
    private weak var view: NSView?
    /// The one timer that hides the track, made once and moved on: each landing or leaving of
    /// the edge only pushes its fire date back.
    private(set) var hide: Timer?

    /// Follows the pointer over `view`, whose trailing edge is the reader's right edge.
    func attach(to view: NSView) {
        self.view = view
        view.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) { follow(event) }
    override func mouseEntered(with event: NSEvent) { follow(event) }
    override func mouseExited(with event: NSEvent) { pointer(nearEdge: false) }

    /// The reader landed on a chapter: the track shows where in the book that is, and stays
    /// `linger` (longer while the pointer is at the edge).
    func landed() {
        reveal(true)
        if !isPointerNearEdge { scheduleHide() }
    }

    private func follow(_ event: NSEvent) {
        guard let view else { return }
        let x = view.convert(event.locationInWindow, from: nil).x
        pointer(nearEdge: BookThumbView.isNearEdge(x: x, width: view.bounds.width))
    }

    private func pointer(nearEdge near: Bool) {
        guard near != isPointerNearEdge else { return }
        isPointerNearEdge = near
        if near {
            // Held off while the pointer stays; the next leave sets it again.
            hide?.fireDate = .distantFuture
            reveal(true)
        } else {
            scheduleHide()
        }
    }

    /// A run-loop timer (in the common modes, so it also fires during a live scroll's tracking),
    /// `linger` from now. It repeats, so it stays valid between uses: each later one moves its
    /// fire date rather than making another; each time it fires it hides the track and sets
    /// itself to wait again.
    private func scheduleHide() {
        if let hide, hide.isValid {
            hide.fireDate = Date(timeIntervalSinceNow: linger)
            return
        }
        let timer = Timer(timeInterval: linger, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hide?.fireDate = .distantFuture
                guard !self.isPointerNearEdge else { return }
                self.reveal(false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hide = timer
    }

    isolated deinit {
        hide?.invalidate()
    }

    private func reveal(_ revealed: Bool) {
        guard revealed != isRevealed else { return }
        isRevealed = revealed
        onChange(revealed)
    }
}
#endif
