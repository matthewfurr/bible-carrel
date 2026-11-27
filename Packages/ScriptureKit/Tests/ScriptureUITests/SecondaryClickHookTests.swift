#if os(macOS)
import AppKit
import Testing
@testable import ScriptureUI

/// The Notes window's right-click hook: it speaks only for a secondary mouse-down.
@MainActor @Suite struct SecondaryClickHookTests {
    private func event(_ type: NSEvent.EventType, flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    @Test func aRightMouseDownFiresTheActionOnce() {
        let view = SecondaryClickView()
        var count = 0
        view.onSecondaryClick = { count += 1 }
        view.rightMouseDown(with: event(.rightMouseDown))
        #expect(count == 1)
    }

    @Test func aControlClickFiresItAndAPlainClickDoesNot() {
        let view = SecondaryClickView()
        var count = 0
        view.onSecondaryClick = { count += 1 }
        view.mouseDown(with: event(.leftMouseDown))
        #expect(count == 0)
        view.mouseDown(with: event(.leftMouseDown, flags: .control))
        #expect(count == 1)
    }

    @Test func onlySecondaryDownsAreClaimed() {
        #expect(SecondaryClickView.isSecondaryDown(event(.rightMouseDown)))
        #expect(SecondaryClickView.isSecondaryDown(event(.leftMouseDown, flags: .control)))
        #expect(!SecondaryClickView.isSecondaryDown(event(.leftMouseDown)))
        #expect(!SecondaryClickView.isSecondaryDown(event(.leftMouseUp)))
        #expect(!SecondaryClickView.isSecondaryDown(event(.mouseMoved)))
    }
}
#endif
