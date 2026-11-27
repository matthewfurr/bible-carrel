#if os(macOS)
import Charts
import SwiftUI

/// The book's whole span to scale above its rail (spec 6.5): lives and eras as bars in lanes, the other rows as
/// ticks along the foot, the rows on screen as a wash. A click calls `onPick`. Not focusable and hidden from
/// VoiceOver: the rail beneath carries every row.
struct TimelineChartView: View {
    let model: TimelineChartModel
    let band: ClosedRange<Double>?
    let onPick: (TimelineChartModel.Target) -> Void

    @ScaledMetric(relativeTo: .caption2) private var scaledLaneHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var scaledCharacterWidth: CGFloat = 6
    @ScaledMetric(relativeTo: .caption2) private var scaledBarThickness: CGFloat = 4
    @ScaledMetric(relativeTo: .caption2) private var scaledTickLength: CGFloat = 6
    @Environment(\.libraryType) private var type

    /// The chart's sizes tied to its labels, grown with the Library's type.
    private var laneHeight: CGFloat { type.metric(scaledLaneHeight) }
    private var characterWidth: CGFloat { type.metric(scaledCharacterWidth) }
    private var barThickness: CGFloat { type.metric(scaledBarThickness) }
    private var tickLength: CGFloat { type.metric(scaledTickLength) }

    /// Bars sit a quarter lane below the lane's middle, so their name fits above them inside the lane.
    private let barOffset = 0.25

    init(model: TimelineChartModel, band: ClosedRange<Double>?, onPick: @escaping (TimelineChartModel.Target) -> Void) {
        self.model = model
        self.band = band
        self.onPick = onPick
    }

    private var lanes: Int { max(model.laneCount, 1) }

    private func y(lane: Int) -> Double { Double(lanes - 1 - lane) }

    var body: some View {
        GeometryReader { geometry in
            chart(width: geometry.size.width)
        }
        .frame(height: laneHeight * (CGFloat(lanes) + 1.25))
        .focusable(false)
        // The chart repeats what the rail beneath it reads row by row, so VoiceOver passes it by (departure 11).
        // swiftlint:disable:next accessibility_hidden_on_text
        .accessibilityHidden(true)
    }

    private func chart(width: CGFloat) -> some View {
        let span = model.domain.upperBound - model.domain.lowerBound
        let perUnit = span > 0 ? width / CGFloat(span) : 0
        let marks = TimelineChartModel.axisMarks(domain: model.domain, width: width, characterWidth: characterWidth)
        let values = marks.map(\.value)
        return Chart {
            if let band {
                RectangleMark(xStart: .value("From", band.lowerBound), xEnd: .value("To", band.upperBound),
                              yStart: .value("Bottom", -0.5), yEnd: .value("Top", Double(lanes) - 0.5))
                    .foregroundStyle(Color.accentWash)
            }
            ForEach(Array(model.ticks.enumerated()), id: \.offset) { _, x in
                RuleMark(x: .value("Year", x), yStart: .value("Foot", -0.5), yEnd: .value("Tick", -0.5 + Double(tickLength / laneHeight)))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.inkSecondary)
            }
            ForEach(model.bars) { bar in
                BarMark(xStart: .value("Start", bar.start), xEnd: .value("End", bar.end),
                        y: .value("Lane", y(lane: bar.lane) - barOffset), height: .fixed(barThickness))
                    .foregroundStyle(bar.kind == .life ? Color.inkTertiary : Color.inkSecondary)
                    .annotation(position: .top, alignment: .leading, spacing: 1,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        if fits(bar, perUnit: perUnit) {
                            Text(bar.title).font(type.font(.caption2)).foregroundStyle(Color.inkSecondary).lineLimit(1).fixedSize()
                        }
                    }
            }
        }
        .chartXScale(domain: model.domain)
        .chartYScale(domain: -0.5 ... Double(lanes) - 0.5)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: values) { value in
                // The first and last labels, the domain's own ends, hang inward, so the strip's edges do not clip them.
                let index = value.as(Double.self).flatMap { values.firstIndex(of: $0) }
                AxisValueLabel(anchor: index == 0 ? .topLeading : index == values.count - 1 ? .topTrailing : .top) {
                    if let index {
                        Text(marks[index].label).font(type.font(.caption2)).foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
        .chartPlotStyle { $0.frame(height: laneHeight * CGFloat(lanes)) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { tap in pick(at: tap.location, proxy: proxy, geometry: geometry) })
            }
        }
    }

    /// Whether the bar is wide enough to hold its name.
    private func fits(_ bar: TimelineChartModel.Bar, perUnit: CGFloat) -> Bool {
        CGFloat(bar.end - bar.start) * perUnit >= characterWidth * CGFloat(bar.title.count)
    }

    private func pick(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plot = proxy.plotFrame else { return }
        let origin = geometry[plot].origin
        guard let x = proxy.value(atX: location.x - origin.x, as: Double.self) else { return }
        var lane: Int?
        if let row = proxy.value(atY: location.y - origin.y, as: Double.self) {
            let candidate = lanes - 1 - Int(row.rounded())
            if (0 ..< model.laneCount).contains(candidate) { lane = candidate }
        }
        onPick(model.target(x: x, lane: lane))
    }
}
#endif
