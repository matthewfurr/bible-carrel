#if os(macOS)
import AppKit
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// Matt, 2026-11-24: the band "tends to" stop following the rows "after scrolling down and back up and then down
/// again". In a hosted window a lazy stack's rows, made again where they were, appear with no new content-space frame;
/// the band must follow them all the same. 120 rows of 44 pt under a 600 pt head and a 200 pt pinned header, in a
/// 760 pt window, wired as the About page wires them (`RailRowFrame`).
@Suite(.serialized) @MainActor struct TimelinePinnedChartHostedTests {
    private static let count = 120, rowHeight: CGFloat = 44, railTop: CGFloat = 800, chart: CGFloat = 200, window: CGFloat = 760

    /// The window's span as the scroll view last reported it.
    @MainActor final class Span { var top: CGFloat = 0 }

    private struct Page: View {
        let geometry: RailGeometry
        let span: Span

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: railTop - chart)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(RailViewport.space)).maxY } action: { geometry.above($0) }
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(1 ... count, id: \.self) { n in
                                Text("Row \(n)").frame(height: rowHeight)
                                    .modifier(RailRowFrame(id: .entry(n), geometry: geometry))
                            }
                        } header: {
                            Color.clear.frame(height: chart)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                    geometry.chartHeight = $0
                                    geometry.update()
                                }
                        }
                    }
                    Color.clear.frame(height: 400)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(RailViewport.space)).minY } action: { geometry.below($0) }
                }
                .coordinateSpace(.named(RailViewport.space))
            }
            .onScrollGeometryChange(for: ClosedRange<CGFloat>.self) { scroll in
                (scroll.visibleRect.minY + scroll.contentInsets.top) ... scroll.visibleRect.maxY
            } action: { _, visible in
                span.top = visible.lowerBound
                geometry.visible(visible, height: window)
            }
        }
    }

    private static func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }

    /// The years of the rows whose middle is under the chart's foot and above the window's, row n's year -2000 + n.
    private static func expected(top: CGFloat) -> ClosedRange<Int>? {
        let foot = max(railTop, top + chart), bottom = top + window
        let shown = (1 ... count).filter { n in
            let middle = railTop + rowHeight * (CGFloat(n) - 0.5)
            return middle > foot && middle < bottom
        }
        guard let low = shown.first, let high = shown.last else { return nil }
        return (-2000 + low) ... (-2000 + high)
    }

    @Test func theBandFollowsTheRowsDownUpAndDownAgain() throws {
        let geometry = RailGeometry(), span = Span()
        geometry.items = (1 ... Self.count).map { TimelineItem.entry(TimelineFixture.record($0, "E\($0)", year: -2000 + $0).asEntry, yearLabel: nil) }
        geometry.domain = TimelineChartModel.x(year: -2000) ... TimelineChartModel.x(year: -1800)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: Self.window), styleMask: [.titled], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: Page(geometry: geometry, span: span).frame(width: 600, height: Self.window))
        host.frame = NSRect(x: 0, y: 0, width: 600, height: Self.window)
        window.contentView = host
        func settle() {
            for _ in 0 ..< 3 {
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
        }
        settle()
        let scroller = try #require(Self.scrollView(in: host))
        func scroll(to y: CGFloat) {
            scroller.contentView.scroll(to: NSPoint(x: 0, y: y))
            scroller.reflectScrolledClipView(scroller.contentView)
            settle()
        }
        let down = Array(stride(from: 400, through: 4000, by: 400)).map { CGFloat($0) }
        for y in down + down.reversed().dropFirst() + down.dropFirst() {
            scroll(to: y)
            #expect(geometry.state.years == Self.expected(top: span.top), "scrolled to \(y)")
        }
        // A fling: a jump far down and back. The lazy stack may place rows a little off their estimate, so the band
        // is held to within a few rows of it, and never to its last span.
        for y: CGFloat in [4400, 900, 3000] {
            let before = geometry.state.years
            scroll(to: y)
            let years = try #require(geometry.state.years), want = try #require(Self.expected(top: span.top))
            #expect(years != before && abs(years.lowerBound - want.lowerBound) <= 6 && abs(years.upperBound - want.upperBound) <= 6,
                    "flung to \(y): \(years) against \(want)")
        }
    }
}
#endif
