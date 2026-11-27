#if os(iOS)
import SwiftUI
import Translation
import UIKit

/// The selection menu's Look Up and Translate (`PhoneMarkupMenu`): the system's dictionary and
/// translation for the selected words, as the app's own rows so the menu's list reads in one
/// voice. Each waits for the menu to close, as Share does.
extension PhoneChapterTextController {
    /// The system dictionary for `term`, anchored on the first line of `range` where the sheet is a popover.
    func presentLookUp(_ term: String, for range: NSRange) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let presenter = self.topPresenter() else { return }
            let dictionary = UIReferenceLibraryViewController(term: term)
            if let popover = dictionary.popoverPresentationController {
                popover.sourceView = self.textView
                popover.sourceRect = self.rect(for: range) ?? self.textView.bounds
            }
            presenter.present(dictionary, animated: true)
        }
    }

    /// The system's translation sheet for `text`. SwiftUI alone presents it, so a clear host
    /// carries it and goes away with it.
    func presentTranslation(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let presenter = self.topPresenter() else { return }
            let host = UIHostingController<TranslationHost>(rootView: TranslationHost(text: text, done: {}))
            host.rootView = TranslationHost(text: text) { [weak host] in host?.dismiss(animated: false) }
            host.modalPresentationStyle = .overFullScreen
            host.view.backgroundColor = .clear
            presenter.present(host, animated: false)
        }
    }

    private func topPresenter() -> UIViewController? {
        var responder: UIResponder? = textView
        while let current = responder, !(current is UIViewController) { responder = current.next }
        guard var presenter = responder as? UIViewController else { return nil }
        while let presented = presenter.presentedViewController { presenter = presented }
        return presenter
    }
}

/// Presents the translation sheet as soon as it appears, and calls `done` once the sheet closes.
struct TranslationHost: View {
    let text: String
    let done: () -> Void
    @State private var isPresented = false

    var body: some View {
        Color.clear
            .translationPresentation(isPresented: $isPresented, text: text)
            .onAppear { isPresented = true }
            .onChange(of: isPresented) { _, shown in
                if !shown { done() }
            }
    }
}
#endif
