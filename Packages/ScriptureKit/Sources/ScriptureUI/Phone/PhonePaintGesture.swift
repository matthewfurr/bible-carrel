#if os(iOS)
import UIKit

/// The pen's paint gesture, Ruling 2's rule B as the owner tested it: a touch held still for
/// `holdDuration` (within `stillTolerance`) and then dragged paints; a drag that starts moving
/// fails it, and the scroll view's pan, which waits for it to fail, scrolls. It begins when the
/// hold engages (the word under the finger paints then, with a light haptic) and reports every
/// movement after that, so the stroke follows the finger; a touch shorter than the hold fails it.
final class PhonePaintGesture: UILongPressGestureRecognizer {
    static let holdDuration: TimeInterval = 0.15
    /// "Still": UIKit's own default for a long press.
    static let stillTolerance: CGFloat = 10

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        minimumPressDuration = Self.holdDuration
        allowableMovement = Self.stillTolerance
        numberOfTouchesRequired = 1
    }
}

/// One of the two handles at the ends of the selected mark: an accent stem the height of the
/// line with a knob above it (the start) or below it (the end), on a touch target at least
/// `minimumTarget` square. Its press begins on touch-down, so it wins over the scroll.
final class PenHandleView: UIView {
    enum End { case start, end }

    /// The smallest touch target (HIG).
    static let minimumTarget: CGFloat = 44
    static let stemWidth: CGFloat = 2
    static let knobDiameter: CGFloat = AppSpacing.sm

    let end: End
    let press = UILongPressGestureRecognizer()
    private let stem = UIView()
    private let knob = UIView()

    init(end: End) {
        self.end = end
        super.init(frame: .zero)
        isHidden = true
        isAccessibilityElement = false
        press.minimumPressDuration = 0
        press.allowableMovement = .greatestFiniteMagnitude
        addGestureRecognizer(press)
        for view in [stem, knob] {
            view.isUserInteractionEnabled = false
            view.backgroundColor = Palette.accent.platformColor
            addSubview(view)
        }
        knob.layer.cornerRadius = Self.knobDiameter / 2
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Stands the handle at `x` on `line` (both in the superview's coordinates).
    func place(atX x: CGFloat, on line: CGRect) {
        let stemHeight = line.height
        let height = max(Self.minimumTarget, stemHeight + 2 * Self.knobDiameter)
        let width = Self.minimumTarget
        frame = CGRect(x: x - width / 2, y: line.midY - height / 2, width: width, height: height)
        let stemTop = (height - stemHeight) / 2
        stem.frame = CGRect(x: (width - Self.stemWidth) / 2, y: stemTop, width: Self.stemWidth, height: stemHeight)
        let knobY = end == .start ? stemTop - Self.knobDiameter + 1 : stemTop + stemHeight - 1
        knob.frame = CGRect(x: (width - Self.knobDiameter) / 2, y: knobY, width: Self.knobDiameter, height: Self.knobDiameter)
    }
}
#endif
