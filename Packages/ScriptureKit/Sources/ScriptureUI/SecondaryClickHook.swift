#if os(macOS)
import AppKit
import SwiftUI

/// Calls `action` when a secondary click (right-click or Control-click) begins on the view it
/// covers, then lets the event go on so the SwiftUI context menu still opens. It takes no other
/// event: left clicks, scrolling and hover pass through to the content beneath.
struct SecondaryClickHook: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> SecondaryClickView {
        let view = SecondaryClickView()
        view.onSecondaryClick = action
        return view
    }

    func updateNSView(_ view: SecondaryClickView, context: Context) {
        view.onSecondaryClick = action
    }
}

final class SecondaryClickView: NSView {
    var onSecondaryClick: (() -> Void)?

    /// Only a secondary mouse-down is ours; everything else reaches the SwiftUI content.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent, Self.isSecondaryDown(event) else { return nil }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        onSecondaryClick?()
        super.rightMouseDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { onSecondaryClick?() }
        super.mouseDown(with: event)
    }

    static func isSecondaryDown(_ event: NSEvent) -> Bool {
        switch event.type {
        case .rightMouseDown: true
        case .leftMouseDown: event.modifierFlags.contains(.control)
        default: false
        }
    }
}
#endif
