#if os(iOS)
import SwiftUI
import UIKit

/// The phone's note editor, as `NoteTextEditor` is the Mac's: a plain `UITextView` holding the
/// body as markdown source, in the note editor's tokens (`.body` text in primary ink, the accent
/// caret, `xs` inner padding; the caller draws `editorSurface()` around it), with
/// `MarkdownFormatting`'s bold, italic and list commands on a toolbar above the keyboard.
struct PhoneNoteTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// Takes the keyboard, with the insertion point at the end, once it is on screen.
    let focusOnAppear: Bool

    /// The markdown commands the phone offers, in toolbar order.
    static let styles: [MarkdownStyle] = [.bold, .italic, .bulletedList]

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PhoneNoteTextView {
        let textView = PhoneNoteTextView()
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = Palette.inkPrimary.platformColor
        textView.tintColor = Palette.accent.platformColor
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: AppSpacing.xs, left: AppSpacing.xs, bottom: AppSpacing.xs, right: AppSpacing.xs)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.accessibilityLabel = "Note"
        textView.text = text
        textView.delegate = context.coordinator
        textView.inputAccessoryView = context.coordinator.makeToolbar(for: textView)
        textView.focusesOnWindow = focusOnAppear
        return textView
    }

    func updateUIView(_ textView: PhoneNoteTextView, context: Context) {
        context.coordinator.parent = self
        // Never while a composition (marked text) is under way, or it would be cut short.
        if textView.text != text, textView.markedTextRange == nil {
            textView.text = text
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PhoneNoteTextEditor

        init(parent: PhoneNoteTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        /// The system toolbar over the keyboard: one symbol button per command, in secondary ink.
        func makeToolbar(for textView: UITextView) -> UIToolbar {
            let toolbar = UIToolbar()
            let buttons = PhoneNoteTextEditor.styles.map { style in
                UIBarButtonItem(primaryAction: UIAction(title: style.title, image: UIImage(systemName: style.symbolName)) { [weak self, weak textView] _ in
                    guard let self, let textView else { return }
                    self.apply(style, in: textView)
                })
            }
            toolbar.items = buttons + [.flexibleSpace()]
            toolbar.tintColor = Palette.inkSecondary.platformColor
            toolbar.sizeToFit()
            return toolbar
        }

        /// Replaces the text through `UITextInput`, so the change is one undoable edit, and puts
        /// the selection where `MarkdownFormatting` says.
        private func apply(_ style: MarkdownStyle, in textView: UITextView) {
            let result = MarkdownFormatting.apply(style, to: textView.text, selection: textView.selectedRange)
            if let whole = textView.textRange(from: textView.beginningOfDocument, to: textView.endOfDocument) {
                textView.replace(whole, withText: result.text)
            }
            textView.selectedRange = result.selection
            parent.text = textView.text
        }
    }
}

/// Becomes first responder when it reaches a window, if asked: the sheet is presented before the
/// editor is on screen.
final class PhoneNoteTextView: UITextView {
    var focusesOnWindow = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard focusesOnWindow, window != nil else { return }
        focusesOnWindow = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.becomeFirstResponder()
            self.selectedRange = NSRange(location: (self.text as NSString).length, length: 0)
        }
    }
}
#endif
