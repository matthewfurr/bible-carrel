import CoreGraphics

/// The phone's Places sheet, as tall as it gets (Matt's review, 2026-11-24): never past half the page, so it never
/// covers the map's upper half. The camera's cover is the sheet's height as measured, which is at most this.
enum PlacesSheet {
    static let tallestFraction: CGFloat = 0.5

    /// The most of a page `height` tall the sheet covers.
    static func tallestCover(of height: CGFloat) -> CGFloat { height * tallestFraction }
}
