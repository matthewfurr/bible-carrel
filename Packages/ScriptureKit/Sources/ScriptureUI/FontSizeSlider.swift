import SwiftUI

/// A slider's value while it is dragged: kept here, not written, so a drag across the size range
/// re-lays the book out once, when it ends, rather than at every step. A step made without a drag
/// (the keyboard, VoiceOver's adjust) is written at once.
struct SliderDraft: Equatable {
    /// The value under the pointer during a drag; nil otherwise.
    private(set) var value: Double?
    private(set) var isDragging = false

    /// What to show for a stored value of `committed`: the drag's value while there is one.
    func shown(_ committed: Double) -> Double {
        value ?? committed
    }

    /// The slider moved to `newValue`. Returns the value to write now, or nil while dragging.
    mutating func move(to newValue: Double) -> Double? {
        guard isDragging else { return newValue }
        value = newValue
        return nil
    }

    /// A drag began or ended. Returns the value to write when one ended having moved.
    mutating func editingChanged(_ editing: Bool) -> Double? {
        isDragging = editing
        guard !editing else { return nil }
        defer { value = nil }
        return value
    }
}

/// The text-size slider of the Mac's Text & Layout popover and Settings › Reading. `fontSize` is
/// the stored size (`ReaderSettings.fontSizeKey`), written when a drag ends; `draft` holds the
/// size under the pointer, which a value label beside it shows through `SliderDraft.shown`.
struct FontSizeSlider: View {
    @Binding var fontSize: Double
    @Binding var draft: SliderDraft

    var body: some View {
        Slider(
            value: Binding(
                get: { draft.shown(fontSize) },
                set: { if let value = draft.move(to: $0) { fontSize = value } }),
            in: ReaderSettings.fontSizeRange,
            step: ReaderSettings.fontSizeStep,
            onEditingChanged: { editing in
                if let value = draft.editingChanged(editing) { fontSize = value }
            })
            .accessibilityLabel("Size")
            .accessibilityValue("\(Int(ReaderSettings.clampedFontSize(draft.shown(fontSize)))) points")
    }
}
