#if os(iOS)
import UIKit

/// What the hand feels under the book thumb's press (`PhoneThumbScrub.Haptic`): a firm tap as the
/// hold takes and the thumb is in hand, then a crisp one for each chapter passed, like a detent.
/// Impacts, not the selection tick, which was too faint to feel through a drag (Matt, 2026-11-13).
/// Made as the press begins and dropped when it ends.
@MainActor final class ThumbHaptics {
    /// How hard each chapter's detent taps, of the rigid impact's full strength (a call; tune on
    /// a device).
    static let detentIntensity: CGFloat = 0.8

    /// The least time between two detents. A fast drag through a long book passes chapters far
    /// quicker than this, and the system, asked for taps that fast, stops giving any at all for
    /// a while (Matt, 2026-11-13: "it starts off ok then just stops altogether"). Chapters
    /// passed sooner than this after the last tap go untapped, so the taps keep coming, about
    /// twenty a second at most. A call; tune on a device.
    static let shortestGap: CFTimeInterval = 0.05
    /// The clock the gap is measured on (a test steps its own).
    var clock: () -> CFTimeInterval = { CACurrentMediaTime() }
    private var lastDetent: CFTimeInterval = -.infinity
    /// How many detents have been played (the tests count them).
    private(set) var detentsPlayed = 0

    private let grab = UIImpactFeedbackGenerator(style: .medium)
    private let detent = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        grab.prepare()
        detent.prepare()
    }

    func play(_ haptic: PhoneThumbScrub.Haptic) {
        switch haptic {
        case .grabbed:
            grab.impactOccurred()
        case .chapterPassed:
            let now = clock()
            guard now - lastDetent >= Self.shortestGap else { return }
            lastDetent = now
            detentsPlayed += 1
            detent.impactOccurred(intensity: Self.detentIntensity)
        }
        detent.prepare()
    }
}
#endif
