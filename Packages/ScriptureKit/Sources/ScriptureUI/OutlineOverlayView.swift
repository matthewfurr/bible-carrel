#if os(macOS)
import AppKit

/// Strokes a rounded outline around the line segments of the highlight whose card was clicked.
/// A passive overlay on the text view: flipped like it, never hit-tested.
public final class OutlineOverlayView: NSView {
    /// The background rects of the outlined highlight, already outset by the controller; drawn
    /// exactly as given (`outset` is 0 and stays 0).
    public var segmentRects: [NSRect] = [] {
        didSet { if segmentRects != oldValue { needsDisplay = true } }
    }
    public let outset: CGFloat = 0

    public override var isFlipped: Bool { true }
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func draw(_ dirtyRect: NSRect) {
        guard !segmentRects.isEmpty else { return }
        // The app's own accent, not the system one, so the outline never takes a highlight's hue.
        Palette.accent.platformColor.setStroke()
        for rect in segmentRects {
            // Concentric with the fill: its 2 pt radius plus the 2 pt outset.
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            path.lineWidth = 1.5
            path.stroke()
        }
    }
}
#endif
