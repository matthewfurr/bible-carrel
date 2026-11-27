import SwiftUI

/// The Mac's pinned chart and the rail under it (Matt's review, 2026-11-24): "at some point while scrolling that section
/// should be pinned to the top so it can still be seen and the vertical timeline of events be scrollable underneath it".
/// Everything is in the page's content space (`space`), where a rail row's frame changes only when the rail is laid
/// out again, not as the page scrolls: a scroll moves the visible rect alone, so a scroll step reads the made rows'
/// frames and lays out nothing.
enum RailViewport {
    /// The About page's content space: the scroll view's content, so its origin is the content's.
    static let space = "LibraryAboutPage"

    /// Where the chart's foot is: on the rail's top while the chart sits in the page; `chartHeight` below the window's
    /// top once the rail has reached it (pinned); never below the rail's last row, so the chart leaves with the rail.
    static func chartFoot(railTop: CGFloat, railBottom: CGFloat, visibleTop: CGFloat, chartHeight: CGFloat) -> CGFloat {
        min(max(railTop, visibleTop + chartHeight), railBottom)
    }

    /// Whether the chart is held at the window's top, rows going under it (and the hairline under it shows).
    static func isPinned(railTop: CGFloat, visibleTop: CGFloat, chartHeight: CGFloat) -> Bool {
        visibleTop + chartHeight > railTop + 0.5
    }

    /// The rows whose middle is between the chart's foot and the window's foot: a row more than half under the
    /// chart is not in view.
    static func rowsInView(_ frames: [TimelineItemID: ClosedRange<CGFloat>], from top: CGFloat, to bottom: CGFloat) -> Set<TimelineItemID> {
        guard bottom > top else { return [] }
        var shown = Set<TimelineItemID>()
        for (id, frame) in frames {
            let middle = (frame.lowerBound + frame.upperBound) / 2
            if middle > top && middle < bottom { shown.insert(id) }
        }
        return shown
    }

    /// The earliest and latest year of the rows in view that the chart draws (`TimelineItems.years`: a closed fold by
    /// its lives, an era header by none); nil when none is.
    static func years(inView ids: Set<TimelineItemID>, items: [TimelineItem], domain: ClosedRange<Double>) -> ClosedRange<Int>? {
        let years = TimelineItems.years(visible: ids, items: items).filter { domain.contains(TimelineChartModel.x(year: $0)) }
        guard let low = years.min(), let high = years.max() else { return nil }
        return low ... high
    }
}

/// What the pinned chart draws from the scroll: the years of the rows in view and whether it is pinned. Only the
/// chart reads it, so a change redraws the chart alone, and it changes only when the band's ends or the pin do.
@MainActor @Observable final class PinnedChartState {
    var years: ClosedRange<Int>?
    var isPinned = false
}

/// The rail's geometry in the page's content space, kept as it is laid out and scrolled; not observed (the rows and
/// the scroll write it while laying out). `update` works out what the chart shows and writes `state` on a change.
@MainActor final class RailGeometry {
    let state = PinnedChartState()
    /// The rail's rows, in order, and the chart's domain, as the page last drew them.
    var items: [TimelineItem] = []
    var domain: ClosedRange<Double> = 0 ... 1
    /// The pinned chart's height, its padding included, and the window's.
    var chartHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    /// Each row's frame as it last reported it, kept while the row is not made: a lazy stack reports a row's frame
    /// here only when it changes, and a row made again where it was before reports none (Matt's review, 2026-11-24:
    /// the band froze after scrolling down, up and down again, each row that left and came back having no frame).
    private var rows: [TimelineItemID: ClosedRange<CGFloat>] = [:]
    /// How many copies of each row are made (its appearances less its disappearances): a row's new copy can appear
    /// before its old one disappears. Only a made row's frame is current, so only a made row can be in view.
    private var made: [TimelineItemID: Int] = [:]
    /// The foot of what stands above the chart, and the top of what follows the rail.
    private var aboveFoot: CGFloat?
    private var belowTop: CGFloat?
    /// The window's top (below any inset) and foot, in content space.
    private var visible: ClosedRange<CGFloat>?

    /// A row's height as last laid out, for landing it.
    func height(of id: TimelineItemID) -> CGFloat? {
        rows[id].map { $0.upperBound - $0.lowerBound }
    }

    func row(_ id: TimelineItemID, _ frame: ClosedRange<CGFloat>) {
        rows[id] = frame
        update()
    }

    func appeared(_ id: TimelineItemID) {
        made[id, default: 0] += 1
        update()
    }

    func disappeared(_ id: TimelineItemID) {
        let copies = (made[id] ?? 0) - 1
        made[id] = copies > 0 ? copies : nil
        update()
    }

    func above(_ foot: CGFloat) {
        aboveFoot = foot
        update()
    }

    func below(_ top: CGFloat) {
        belowTop = top
        update()
    }

    func visible(_ frame: ClosedRange<CGFloat>, height: CGFloat) {
        visible = frame
        viewportHeight = height
        update()
    }

    /// The band keeps its last years while no row is in view (the chart pushed up with the rail's last rows, or the
    /// rail not yet reached), so it never blinks out between two rows.
    func update() {
        guard let aboveFoot, let visible else { return }
        let railTop = aboveFoot + chartHeight, railBottom = belowTop ?? .infinity
        let pinned = RailViewport.isPinned(railTop: railTop, visibleTop: visible.lowerBound, chartHeight: chartHeight)
        if pinned != state.isPinned { state.isPinned = pinned }
        let foot = RailViewport.chartFoot(railTop: railTop, railBottom: railBottom, visibleTop: visible.lowerBound, chartHeight: chartHeight)
        let current = Dictionary(uniqueKeysWithValues: made.keys.compactMap { id in rows[id].map { (id, $0) } })
        let shown = RailViewport.rowsInView(current, from: foot, to: visible.upperBound)
        if let years = RailViewport.years(inView: shown, items: items, domain: domain), years != state.years { state.years = years }
    }
}
