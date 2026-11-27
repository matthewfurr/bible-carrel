import SwiftUI

private struct PageFaceKey: EnvironmentKey {
    static let defaultValue = PageFace.literata
}

extension EnvironmentValues {
    /// The reader's page face (Settings › Reading): quoted phrases, the front page's numerals and
    /// the contents page's book names are set in it, so they look like the page they came from.
    public var pageFace: PageFace {
        get { self[PageFaceKey.self] }
        set { self[PageFaceKey.self] = newValue }
    }
}

extension View {
    /// Puts the reader's page face into this root's environment, following the page style and
    /// font settings. Each scene's root takes it; presentations from it inherit it.
    public func followsPageFace() -> some View {
        modifier(FollowsPageFace())
    }
}

private struct FollowsPageFace: ViewModifier {
    @AppStorage(ReaderSettings.pageStyleKey) private var pageStyle = PageStyle.printed.rawValue
    @AppStorage(ReaderSettings.pageFaceKey) private var pageFace = ""

    func body(content: Content) -> some View {
        content.environment(\.pageFace, PageFace.resolved(styleRaw: pageStyle, faceRaw: pageFace))
    }
}
