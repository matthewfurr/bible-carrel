import Foundation
import Observation

/// The phone's pen: whether it is on, the color it paints with (remembered per device, never
/// synced) and the mark it last painted or the reader tapped, which carries the handles and the
/// menu. Platform-neutral, so it is tested on the Mac; the gesture that paints is the phone's.
@MainActor @Observable public final class PenModel {
    public static let colorKey = "penColorID"          // per device, not synced

    public private(set) var isOn = false
    /// The ringed color; the first chip when nothing is stored or the stored color is gone.
    public private(set) var colorID: UUID? {
        get {
            let chips = markup.colorChips
            if let storedColorID, chips.contains(where: { $0.id == storedColorID }) { return storedColorID }
            return chips.first?.id
        }
        set {
            storedColorID = newValue
            defaults.set(newValue?.uuidString, forKey: Self.colorKey)
        }
    }
    public private(set) var selectedHighlightID: UUID?

    private let markup: MarkupModel
    private let defaults: UserDefaults
    private var storedColorID: UUID?

    public init(markup: MarkupModel, defaults: UserDefaults = .standard) {
        self.markup = markup
        self.defaults = defaults
        storedColorID = defaults.string(forKey: Self.colorKey).flatMap(UUID.init(uuidString:))
    }

    public func turnOn() {
        isOn = true
    }

    /// Also clears the selection and the outline.
    public func turnOff() {
        isOn = false
        select(highlightID: nil)
    }

    /// Paints the report's words in the pen's color and selects the mark; nil paints nothing.
    public func paint(_ report: SelectionReport?) -> UUID? {
        guard let report, let colorID, let id = markup.applyColor(colorID, to: report) else { return nil }
        select(highlightID: id)
        return id
    }

    /// Selects (outlines) a mark, or with nil clears the selection and the outline.
    public func select(highlightID: UUID?) {
        selectedHighlightID = highlightID
        if let highlightID {
            markup.focus(highlightID: highlightID)
        } else {
            markup.setSelection(nil)
        }
    }

    /// Sets the pen color; recolors the selected mark.
    public func chooseColor(_ id: UUID) {
        colorID = id
        if let selectedHighlightID {
            markup.setColor(id, highlightID: selectedHighlightID)
        }
    }

    /// Moves the selected mark onto the report's words; nil, or nothing selected, does nothing.
    public func resizeSelected(to report: SelectionReport?) {
        guard let report, let selectedHighlightID else { return }
        markup.resizeHighlight(id: selectedHighlightID, to: report)
    }
}
