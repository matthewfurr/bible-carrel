#if os(iOS)
import UIKit
#endif

/// Where the suites run: the package is tested on the Mac (`swift test`) and on the iPhone
/// simulator (the iOS scheme's test action). A test whose assertion holds only on the Mac (the
/// Mac's wording, `NSColor` palette colors that compare equal where UIKit's dynamic colors do not)
/// is enabled with `.enabled(if: TestPlatform.isMac, …)`.
enum TestPlatform {
    static let isMac: Bool = {
        #if os(macOS)
        true
        #else
        false
        #endif
    }()
}

#if os(iOS)
/// Makes a scene-less window for a test. `UIWindow(frame:)` is deprecated in iOS 26 in favor of
/// `init(windowScene:)`, but the suites run with no window scene. The call sits in a deprecated
/// witness reached through a protocol that is not deprecated, so the warning stays out of the
/// test output.
@MainActor enum TestWindow {
    static func make(frame: CGRect) -> UIWindow {
        (SceneLessWindowMaker() as any WindowMaking).make(frame: frame)
    }
}

@MainActor private protocol WindowMaking {
    func make(frame: CGRect) -> UIWindow
}

private struct SceneLessWindowMaker: WindowMaking {
    @available(iOS, deprecated: 26.0, message: "Tests only: a window with no scene")
    func make(frame: CGRect) -> UIWindow { UIWindow(frame: frame) }
}
#endif
