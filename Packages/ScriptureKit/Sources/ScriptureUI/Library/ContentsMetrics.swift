import CoreGraphics

/// The front page's contents sizes, all from the reader's page text size (spec 4.2). Everything
/// that was a fixed point value in the contents page follows the size over 18 (the default).
public struct ContentsMetrics: Equatable, Sendable {
    /// The reader size, held within `ReaderSettings.fontSizeRange`.
    public let readerSize: CGFloat

    public init(readerSize: CGFloat) {
        self.readerSize = CGFloat(ReaderSettings.clampedFontSize(Double(readerSize)))
    }

    /// The size over 18: what the spacing values grow by.
    public var scale: CGFloat { readerSize / CGFloat(ReaderSettings.defaultFontSize) }
    /// Book names: the page face at the reader size.
    public var nameSize: CGFloat { readerSize }
    /// Testament titles: 1.15 times the reader size.
    public var testamentTitleSize: CGFloat { readerSize * 1.15 }
    /// Group labels: 0.58 times the reader size, never under `.caption2`'s size.
    public var groupLabelSize: CGFloat { max(0.58 * readerSize, PageFace.baseSize(.caption2)) }
    public var rowVerticalPadding: CGFloat { AppSpacing.xxs * scale }
    /// The selection wash's inset beyond the name, each side.
    public var washInset: CGFloat { AppSpacing.xs * scale }
    /// The gap between a name and its marked dot.
    public var dotGap: CGFloat { AppSpacing.xs * scale }
    public var markDot: CGFloat { 3 * scale }

    /// The column: the widest name, the dot and its gap, and the wash's inset on both sides.
    public func columnWidth(widestName: CGFloat) -> CGFloat {
        (widestName + dotGap + markDot + 2 * washInset).rounded(.up)
    }
}
