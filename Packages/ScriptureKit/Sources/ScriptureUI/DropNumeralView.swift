import CoreGraphics
#if os(macOS)
import AppKit

/// One of Lectern's drop numerals (`DropNumeral`) on the Mac: a small view over the text view,
/// just the figures' size, in the accent as its appearance resolves it (Sepia included). Flipped
/// like the text view and never hit-tested, so the text under it selects as ever; an
/// accessibility element ("Chapter 3") the text view lists among its children.
///
/// One view per numeral, never one overlay the height of the book: a layer-backed view 200,000
/// points tall (whole Psalms) keeps backing only for the part it last drew, and as the page
/// scrolled the window showed those stale pixels elsewhere (Psalm 119's numeral over Psalm 108).
final class DropNumeralView: NSView {
    let chapter: Int
    private(set) var font: NSFont?
    /// The line's origin on its baseline and the figures' rect, in the text view's coordinates.
    private(set) var origin: CGPoint = .zero
    private(set) var ink: CGRect = .zero
    /// The figures' ink is drawn with this much room on every side.
    private static let margin: CGFloat = 2

    init(chapter: Int) {
        self.chapter = chapter
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Places the numeral at `placement` (text-container coordinates) in a text view whose
    /// container sits `inset` in from its top-left.
    func place(_ placement: DropNumeral.Placement, font: NSFont, inset: NSSize) {
        let ink = placement.ink.offsetBy(dx: inset.width, dy: inset.height)
        let origin = CGPoint(x: placement.origin.x + inset.width, y: placement.origin.y + inset.height)
        let frame = ink.insetBy(dx: -Self.margin, dy: -Self.margin).integral
        if self.frame != frame { self.frame = frame }
        if font != self.font || origin != self.origin || ink != self.ink {
            self.font = font
            self.origin = origin
            self.ink = ink
            needsDisplay = true
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let font, let context = NSGraphicsContext.current?.cgContext else { return }
        var color = Palette.accent.platformColor.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { color = Palette.accent.platformColor.cgColor }
        DropNumeral.draw(chapter, font: font, at: CGPoint(x: origin.x - frame.minX, y: origin.y - frame.minY), color: color, in: context)
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityLabel() -> String? { DropNumeral.accessibilityLabel(chapter) }
}
#endif

#if os(iOS)
import UIKit

/// One of Lectern's drop numerals (`DropNumeral`) on the phone, laid over the text view where the
/// numeral's notch is, in the accent as its traits resolve it (Sepia included). It takes no touch,
/// so the text under it selects as ever, and is an accessibility element ("Chapter 3").
final class DropNumeralView: UIView {
    let chapter: Int
    private var font: UIFont?
    /// The line's origin on its baseline, in this view's coordinates.
    private var origin: CGPoint = .zero
    /// The figures' ink is drawn with this much room on every side.
    private static let margin: CGFloat = 2

    init(chapter: Int) {
        self.chapter = chapter
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityLabel = DropNumeral.accessibilityLabel(chapter)
        accessibilityTraits = .staticText
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self, SepiaTrait.self]) { (view: DropNumeralView, _) in
            view.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Places the numeral at `placement` (text-container coordinates) in a text view whose
    /// container sits `inset` in from its top-left.
    func place(_ placement: DropNumeral.Placement, font: UIFont, inset: UIEdgeInsets) {
        let ink = placement.ink.offsetBy(dx: inset.left, dy: inset.top).insetBy(dx: -Self.margin, dy: -Self.margin).integral
        let origin = CGPoint(x: placement.origin.x + inset.left - ink.minX, y: placement.origin.y + inset.top - ink.minY)
        if frame != ink { frame = ink }
        if font != self.font || origin != self.origin {
            self.font = font
            self.origin = origin
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let font, let context = UIGraphicsGetCurrentContext() else { return }
        let color = Palette.accent.platformColor.resolvedColor(with: traitCollection).cgColor
        DropNumeral.draw(chapter, font: font, at: origin, color: color, in: context)
    }
}
#endif
