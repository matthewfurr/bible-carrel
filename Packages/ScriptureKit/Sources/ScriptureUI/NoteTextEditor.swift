#if os(macOS)
import AppKit
import SwiftUI

/// The note editor: a plain `NSTextView` so a click into it is an ordinary text click (first
/// responder and caret at the click point in one), Return keys follow `NoteEditingKeys`, and
/// focus requests from the model land with the insertion point at the end. The host is sized to
/// the text (at least three lines) so the text always starts at the top.
struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    /// Bumped by the model when editing starts; -1 means never focus on its own (draft cards).
    let focusRequest: Int
    let finishWithReturn: Bool
    let onFocusChange: (Bool) -> Void
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NoteTextView {
        let textView = NoteTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = NSFont.preferredFont(forTextStyle: .callout)
        textView.textColor = Palette.inkPrimary.platformColor
        textView.insertionPointColor = Palette.accent.platformColor
        textView.textContainerInset = NSSize(width: 4, height: 4)
        // The representable sizes the view; the text view itself never resizes.
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 2
        textView.delegate = context.coordinator
        textView.string = text
        textView.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.parent.onFocusChange(focused)
        }
        textView.onCancel = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onFinish()
        }
        textView.onReturn = { [weak coordinator = context.coordinator, weak textView] command, shift in
            guard let coordinator, let textView else { return }
            switch NoteEditingKeys.action(command: command, shift: shift, finishWithReturn: coordinator.parent.finishWithReturn) {
            case .finish:
                coordinator.parent.onFinish()
            case .newline:
                textView.insertText("\n", replacementRange: textView.selectedRange())
            }
        }
        return textView
    }

    func updateNSView(_ textView: NoteTextView, context: Context) {
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
        }
        let length = (textView.string as NSString).length
        if textView.selectedRange() != selection, NSMaxRange(selection) <= length {
            textView.setSelectedRange(selection)
        }
        if focusRequest >= 0, context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            // Next turn: the model raises the request before the editor appears, and the editor
            // may be in no window even then (N with the notes column hidden); it then takes focus
            // when it gets one.
            DispatchQueue.main.async { textView.takeFocus() }
        }
    }

    /// The height of the text at the proposed width, at least `NoteTextView.minimumHeight`.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView textView: NoteTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? max(textView.frame.width, 200)
        if abs(textView.frame.width - width) > 0.5 {
            textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
        }
        return CGSize(width: width, height: textView.contentHeight)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor
        var lastFocusRequest = -1

        init(parent: NoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NoteTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NoteTextView else { return }
            parent.selection = textView.selectedRange()
        }
    }
}

/// Reports focus changes, routes every Return key (plain, Shift, ⌘) to `onReturn` before
/// AppKit's key bindings or menu equivalents see it, and measures its own text height.
final class NoteTextView: NSTextView {
    static let minimumHeight: CGFloat = 64

    var onFocusChange: ((Bool) -> Void)?
    /// (command, shift)
    var onReturn: ((Bool, Bool) -> Void)?
    /// Escape: the note is already saved as typed, so Escape simply finishes editing.
    var onCancel: (() -> Void)?

    /// A focus request made before the view had a window (the inspector's editor not yet added),
    /// settled once it has one.
    private var wantsFocusWhenInWindow = false

    /// Takes keyboard focus with the caret at the end, now or once the view is in a window.
    func takeFocus() {
        guard let window else {
            wantsFocusWhenInWindow = true
            return
        }
        wantsFocusWhenInWindow = false
        window.makeFirstResponder(self)
        setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, wantsFocusWhenInWindow { takeFocus() }
    }

    override func cancelOperation(_ sender: Any?) {
        if let onCancel { onCancel() } else { super.cancelOperation(sender) }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChange?(false) }
        return accepted
    }

    /// ⌘Return arrives as a key equivalent, not a key-down; take it here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if NoteEditingKeys.isReturn(keyCode: event.keyCode), event.modifierFlags.contains(.command), let onReturn {
            onReturn(true, event.modifierFlags.contains(.shift))
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if NoteEditingKeys.isReturn(keyCode: event.keyCode), let onReturn {
            onReturn(event.modifierFlags.contains(.command), event.modifierFlags.contains(.shift))
            return
        }
        super.keyDown(with: event)
    }

    /// The laid-out height of the text at the current width, plus insets.
    var contentHeight: CGFloat {
        guard let layoutManager = textLayoutManager else { return Self.minimumHeight }
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        let height = layoutManager.usageBoundsForTextContainer.maxY + 2 * textContainerInset.height
        return max(Self.minimumHeight, ceil(height))
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: contentHeight)
    }
}
#endif
