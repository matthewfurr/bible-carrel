#if os(iOS)
import UIKit

/// The reader's selection fill, in place of the system's (`UITextSelectionDisplayInteraction`'s
/// `highlightView`). The system still owns the selection and lays this view out: it sizes and
/// places the view, gives it the selection's colour as its tint, hands it one rect per selected
/// line (`selectionRects`, which the handles and the loupe are placed from too, and which are
/// kept as given) and hides it when the selection collapses. The system's rects run on to the
/// column's edges on every line whose break is selected; this view paints each one trimmed to
/// its line's words (`fill`, the controller's), in the system's colour, square cornered and as
/// one shape, so the lines join as the system's fill does.
final class ReaderSelectionHighlightView: UIView, UITextSelectionHighlightView {
    /// The trimmed fill for the system's line rects, both in this view's coordinates.
    var fill: ([CGRect]) -> [CGRect] = { $0 }

    var selectionRects: [UITextSelectionRect] = [] {
        didSet { refresh() }
    }

    /// The system hides the view when the selection collapses and shows it for a ranged one.
    override var isHidden: Bool {
        didSet { if isHidden != oldValue { refresh() } }
    }

    /// What is painted, in this view's coordinates.
    private(set) var paintedRects: [CGRect] = []

    private let shape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(shape)
        updateColor()
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (view: Self, _) in
            view.updateColor()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Paints the fill again from the system's current rects (a new selection, or a reflow).
    func refresh() {
        let rects = fill(selectionRects.map(\.rect).filter { !$0.isEmpty })
        guard rects != paintedRects else { return }
        paintedRects = rects
        let path = CGMutablePath()
        for rect in rects { path.addRect(rect) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = path
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.frame = bounds
        CATransaction.commit()
    }

    /// The system sets the selection's colour as this view's tint (and again when the appearance
    /// changes).
    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateColor()
    }

    private func updateColor() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.fillColor = tintColor.resolvedColor(with: traitCollection).cgColor
        CATransaction.commit()
    }
}
#endif
