import SwiftUI

/// A group's name over its books (the iPhone's Library, the Mac's contents page), in the chapter
/// label's voice: small, upper case, spaced, in the verse ink. It carries no padding; each caller
/// pads it for its own surface. With a `size` (the Mac's contents, from the reader size) it is set
/// at that size, its tracking in the same proportion; without, at `.caption2`.
public struct GroupLabel: View {
    private let title: String
    private let size: CGFloat?
    @ScaledMetric(relativeTo: .caption2) private var tracking: CGFloat = 1.4

    public init(_ title: String, size: CGFloat? = nil) {
        self.title = title
        self.size = size
    }

    /// The tracking at a size: 1.4 at `.caption2`'s base size, in proportion above it.
    public nonisolated static func tracking(forSize size: CGFloat) -> CGFloat {
        1.4 * size / PageFace.baseSize(.caption2)
    }

    public var body: some View {
        Text(title)
            .font(font)
            .textCase(.uppercase)
            .kerning(size.map(Self.tracking(forSize:)) ?? tracking)
            .foregroundStyle(Color.inkVerse)
            .accessibilityAddTraits(.isHeader)
    }

    private var font: Font {
        guard let size else { return .caption2.weight(.semibold) }
        return Font(PlatformFont.systemFont(ofSize: size, weight: .semibold) as CTFont)
    }
}
