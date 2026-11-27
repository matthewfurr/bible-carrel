#if os(iOS)
import SwiftUI
import UIKit

/// The system share sheet for one file, over whatever the window shows on top, as a share button would.
@MainActor enum PhoneShareSheet {
    static func present(_ url: URL) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }
}
#endif
