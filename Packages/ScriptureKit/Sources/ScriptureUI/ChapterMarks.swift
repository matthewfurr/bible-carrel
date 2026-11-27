import ScriptureModel
import SwiftUI

/// What a chapter's marks say to the front page and the Library: that it has a highlight, note or
/// bookmark, and the colours its highlights have in the reader's colour order. No colours: marked,
/// with none (a bookmark, a chapter note, an uncoloured highlight).
public struct ChapterMarks: Equatable, Sendable {
    public let colors: [MarkupColor]

    public init(colors: [MarkupColor]) {
        self.colors = colors
    }
}

/// The ring round a marked chapter's number (spec 5): one segment per colour, up to six, each in
/// the colour's hue at a lightness that reads as a mark on every surface.
public enum ChapterRing {
    public static let maximumSegments = 6, gap = 0.03, lightLightness = 0.55, darkLightness = 0.68

    /// One arc of the ring, as fractions of its path.
    public struct Segment: Equatable, Sendable {
        public let start: Double, end: Double
        /// Nil: the ring's own ink, `ink.tertiary`.
        public let color: MarkupColor?

        public init(start: Double, end: Double, color: MarkupColor?) {
            self.start = start
            self.end = end
            self.color = color
        }
    }

    /// No colour, or one: the whole ring. Otherwise the first six colours share it equally, each
    /// shortened by half the gap at each end.
    public static func segments(for marks: ChapterMarks) -> [Segment] {
        guard marks.colors.count > 1 else { return [Segment(start: 0, end: 1, color: marks.colors.first)] }
        let shown = marks.colors.prefix(maximumSegments)
        let share = 1 / Double(shown.count)
        return shown.enumerated().map { index, color in
            Segment(start: Double(index) * share + gap / 2, end: Double(index + 1) * share - gap / 2, color: color)
        }
    }

    /// The hex's hue at the ring's lightness, chroma 0.4 reduced until sRGB holds it.
    public static func ringHex(_ hex: String, dark: Bool) -> String {
        guard let seed = OKLCH(hex: hex) else { return dark ? "#808080" : "#6B6B6B" }
        return OKLCH(l: dark ? darkLightness : lightLightness, c: 0.4, hueDegrees: seed.hueDegrees).hexReducingChroma()
    }

    /// Each appearance's hex through `ringHex`.
    public static func color(_ mark: MarkupColor) -> MarkupColor {
        MarkupColor(lightHex: ringHex(mark.lightHex, dark: false), darkHex: ringHex(mark.darkHex, dark: true))
    }
}

/// A rounded rectangle's outline as a path that starts at the top's middle and runs clockwise, so
/// a trimmed segment of it is placed the way `ChapterRing.segments` says.
struct RingShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.midX, y: rect.minY), radius: r)
        path.closeSubpath()
        return path
    }
}

/// The ring itself: the cell's rounded rectangle inset `xxs`, stroked with butt caps, one trim per
/// segment. The Mac's pane gives it a line at the reader's page size.
struct ChapterRingView: View {
    let marks: ChapterMarks
    /// The cell's corner radius; the ring's is that less the inset.
    let cornerRadius: CGFloat
    /// The line's width; nil keeps the scaled 1.5 pt (the phone's Library).
    var lineWidth: CGFloat? = nil
    @ScaledMetric(relativeTo: .title3) private var scaledLineWidth: CGFloat = 1.5

    var body: some View {
        let segments = ChapterRing.segments(for: marks)
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                RingShape(cornerRadius: max(cornerRadius - AppSpacing.xxs, 0))
                    .trim(from: segment.start, to: segment.end)
                    .stroke(stroke(segment), style: StrokeStyle(lineWidth: lineWidth ?? scaledLineWidth, lineCap: .butt))
            }
        }
        .padding(AppSpacing.xxs)
        .accessibilityHidden(true)
    }

    private func stroke(_ segment: ChapterRing.Segment) -> Color {
        segment.color.map { Color(markup: ChapterRing.color($0)) } ?? Color.inkTertiary
    }
}
