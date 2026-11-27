import CoreGraphics

/// When an edge swipe between the phone's screens settles on the next screen and when it springs
/// back (spec 4.1), apart from the gesture. Platform-neutral, so it is tested on the Mac.
///
/// `travel` is how far the finger has come in from its edge and `speed` how fast it is moving
/// inward at release, both positive toward the next screen.
enum EdgeSwipe {
    /// Past half the screen's width a release settles on the next screen, as the system back swipe does.
    static let settleFraction: CGFloat = 0.5
    /// A flick inward this fast settles on the next screen wherever it is let go.
    static let flickSpeed: CGFloat = 300
    /// Under Reduce Motion nothing follows the finger: the screens change as a cut once it has
    /// come this far in.
    static let cutTravel: CGFloat = 60
    /// How far the screen underneath moves for each point the one on top moves: it drifts in from
    /// a third of the way across, as under the system back swipe.
    static let underneathDrift: CGFloat = 0.3

    /// Whether letting go settles on the next screen.
    static func settles(travel: CGFloat, speed: CGFloat, width: CGFloat) -> Bool {
        guard width > 0 else { return false }
        if speed >= flickSpeed { return true }
        if speed <= -flickSpeed { return false }
        return travel / width >= settleFraction
    }

    /// The finger's travel held to the screen: never back past its edge, never past the far side.
    static func clampedTravel(_ travel: CGFloat, width: CGFloat) -> CGFloat {
        min(max(travel, 0), max(width, 0))
    }
}
