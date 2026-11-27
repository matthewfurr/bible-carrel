import SwiftUI

/// The progress line's rule, shared by the Mac's and the phone's readers so both show the same
/// value for the same place: the distance scrolled as a share of the distance the page can
/// scroll, clamped (an elastic overscroll reads as the nearest end), and 0 within `topThreshold`
/// of the top or when the chapter fits, so a chapter opened at its start shows no line.
enum ReadingProgress {
    /// The smallest change worth reporting: half a percent, under a pixel of line at any measure,
    /// so scrolling does not redraw the line for nothing.
    static let step: Double = 0.005

    /// Where a scroll to a chapter's first verse rests: the inset above the text less the lead-in
    /// kept above a target verse. Within it the reader is at the top.
    static func topThreshold(verticalInset: CGFloat, scrollLeadIn: CGFloat) -> CGFloat {
        verticalInset - scrollLeadIn
    }

    /// `offset` is how far the page has scrolled from its top, `scrollable` how far it can.
    static func fraction(offset: CGFloat, scrollable: CGFloat, topThreshold: CGFloat) -> Double {
        guard scrollable > 0, offset > topThreshold else { return 0 }
        return min(max(Double(offset / scrollable), 0), 1)
    }

    /// Whether `value` should be reported after `last`: it moved at least `step`, or it reached
    /// an end, so the line always lands exactly on 0 and 1.
    static func shouldReport(_ value: Double, after last: Double) -> Bool {
        guard value != last else { return false }
        return value == 0 || value == 1 || abs(value - last) >= step
    }
}

/// How far through the chapter the reader is: a thin accent line across the text column's
/// measure, growing from the leading edge. On the Mac it sits directly under the running head
/// and restarts for each chapter (`RunningHeadState.progress`); on the phone it sits under the
/// navigation bar. It reports state and nothing else, so it never animates: the width is bound
/// straight to the scroll position, and Reduce Motion changes nothing because nothing moves.
/// Hidden at 0, which is also its value when a chapter starts or fits.
struct ReadingProgressLine: View {
    /// The line's thickness: enough to read at a glance, thin enough to stay chrome.
    static let height: CGFloat = 2

    let fraction: Double
    /// The column's measure; the line spans it at 1, and narrows with the column when the
    /// window is too narrow for the full measure.
    let measure: CGFloat

    var body: some View {
        LeadingShare(fraction: fraction)
            .fill(Color.accent)
            .frame(maxWidth: measure)
            .frame(height: Self.height)
            .opacity(fraction > 0 ? 1 : 0)
            // No animation, inherited or otherwise: the line is where the reader is.
            .transaction { $0.animation = nil }
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Chapter progress")
            .accessibilityValue("\(Int(fraction * 100)) percent")
            .accessibilityHidden(fraction == 0)
    }
}

/// The progress line at the progress the page reports for the open `chapter` (`ReaderChrome`),
/// on both apps. Only this view reads the progress, so a scroll that moves the line re-evaluates
/// the line alone.
struct RunningHeadProgressLine: View {
    let chrome: ReaderChrome
    let chapter: Int
    let measure: CGFloat

    var body: some View {
        ReadingProgressLine(fraction: chrome.headProgress(for: chapter), measure: measure)
    }
}

/// The leading `fraction` of its rect. Drawn as a shape rather than a fixed width so the line
/// follows the column's actual width at every window size; `fraction` is deliberately not
/// animatable data, so nothing interpolates it.
private struct LeadingShare: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * min(max(fraction, 0), 1), height: rect.height))
    }
}
