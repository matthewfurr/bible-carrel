import SwiftUI

/// The divider at the chapter pane's leading edge (spec 5.1): one `ink.rule` hairline and an
/// `xs`-wide area centred on it that takes the drag, with the system's left-right resize pointer.
/// No grabber and no hover fill. A double-click returns the pane to its narrowest. VoiceOver
/// hears an adjustable element that steps one column; it is not a Tab stop and takes no key.
struct PaneDivider: View {
    let columns: Int
    let coordinateSpace: String
    /// The drag's horizontal translation in the named space, which does not move with the pane.
    let onDrag: (CGFloat) -> Void
    let onEnd: () -> Void
    /// A drag that stops without ending (the system cancelled it): the pane goes back.
    let onCancel: () -> Void
    let onReset: () -> Void
    /// +1 for a column more across, −1 for one fewer.
    let onAdjust: (Int) -> Void

    /// True while a drag is under way; SwiftUI resets it when the drag ends or is cancelled.
    @GestureState private var isDragging = false

    init(columns: Int, coordinateSpace: String, onDrag: @escaping (CGFloat) -> Void, onEnd: @escaping () -> Void,
         onCancel: @escaping () -> Void, onReset: @escaping () -> Void, onAdjust: @escaping (Int) -> Void) {
        self.columns = columns
        self.coordinateSpace = coordinateSpace
        self.onDrag = onDrag
        self.onEnd = onEnd
        self.onCancel = onCancel
        self.onReset = onReset
        self.onAdjust = onAdjust
    }

    var body: some View {
        HairlineRule(.vertical)
            .frame(width: AppSpacing.xs)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            #if os(macOS)
            .pointerStyle(.columnResize)
            #endif
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpace))
                    .updating($isDragging) { _, dragging, _ in dragging = true }
                    .onChanged { onDrag($0.translation.width) }
                    .onEnded { _ in onEnd() })
            // The reset comes for an ended drag too, so the cancel waits a turn: by then an ended
            // drag has stored its width and left nothing to cancel.
            .onChange(of: isDragging) { _, dragging in
                if !dragging { Task { @MainActor in onCancel() } }
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded { onReset() })
            .focusable(false)
            .accessibilityElement()
            .accessibilityLabel("Chapter pane width")
            .accessibilityValue("\(columns) chapters across")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onAdjust(1)
                case .decrement: onAdjust(-1)
                @unknown default: break
                }
            }
    }
}
