import CoreGraphics

/// The chapter pane's sizes, from the reader's page text size (spec 5.2 and 5.3): the cell, the
/// numeral, the rings, how many cells fit across, and the pane's narrowest and widest widths.
public struct ChapterPaneMetrics: Equatable, Sendable {
    public static let fiveAcross = 5
    public static let fewestColumns = 3
    /// The pane is never wider than this share of the front page.
    public static let widestShare: CGFloat = 0.4

    /// The reader size, held within `ReaderSettings.fontSizeRange`.
    public let readerSize: CGFloat

    public init(readerSize: CGFloat) {
        self.readerSize = CGFloat(ReaderSettings.clampedFontSize(Double(readerSize)))
    }

    private var scale: CGFloat { readerSize / CGFloat(ReaderSettings.defaultFontSize) }

    /// 52 by 40 at 18.
    public var cellWidth: CGFloat { (2.9 * readerSize).rounded() }
    public var cellHeight: CGFloat { (2.2 * readerSize).rounded() }
    public var numeralSize: CGFloat { readerSize }
    public var ringLineWidth: CGFloat { 1.5 * scale }
    public var searchRingWidth: CGFloat { 3 * scale }
    /// One cell and its gutter.
    public var columnStep: CGFloat { cellWidth + AppSpacing.xs }

    /// Five cells across, with the gutters and `sm` each side.
    public var narrowestWidth: CGFloat {
        CGFloat(Self.fiveAcross) * cellWidth + CGFloat(Self.fiveAcross - 1) * AppSpacing.xs + 2 * AppSpacing.sm
    }

    public func widestWidth(frontPageWidth: CGFloat) -> CGFloat {
        Self.widestShare * frontPageWidth
    }

    /// The stored width held between the narrowest and 40% of the front page, the 40% winning;
    /// with the page's width not yet known (zero), only the narrowest holds.
    public func shownWidth(stored: CGFloat?, frontPageWidth: CGFloat) -> CGFloat {
        let wanted = max(stored ?? narrowestWidth, narrowestWidth)
        return frontPageWidth <= 0 ? wanted : min(wanted, widestWidth(frontPageWidth: frontPageWidth))
    }

    /// As many cells as fit across the pane's inner width; never fewer than three.
    public func columns(paneWidth: CGFloat) -> Int {
        max(Self.fewestColumns, Int((paneWidth - 2 * AppSpacing.sm + AppSpacing.xs) / columnStep))
    }
}
