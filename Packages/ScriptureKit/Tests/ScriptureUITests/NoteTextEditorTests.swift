#if os(macOS)
import AppKit
import Testing
@testable import ScriptureUI

/// The note editor's focus: a request made before the editor is in a window (N with the notes
/// column hidden, the inspector's editor not yet added) lands once it is in one.
@MainActor @Suite struct NoteTextEditorTests {
    @Test func aFocusRequestMadeBeforeTheEditorHasAWindowLandsWhenItHasOne() {
        let editor = NoteTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 64))
        editor.isEditable = true
        editor.string = "kept"
        editor.takeFocus()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        window.contentView = content
        content.addSubview(editor)
        #expect(window.firstResponder === editor)
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))   // the caret at the end
        // Once settled, a later move between windows takes nothing.
        window.makeFirstResponder(nil)
        editor.removeFromSuperview()
        content.addSubview(editor)
        #expect(window.firstResponder !== editor)
    }

    @Test func aFocusRequestInAWindowLandsAtOnce() {
        let editor = NoteTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 64))
        editor.isEditable = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        window.contentView?.addSubview(editor)
        editor.takeFocus()
        #expect(window.firstResponder === editor)
    }
}
#endif
