import SwiftUI

/// What sits on a rail row's line: a dot for an event, a ring for a life or a fold, nothing for a header; `accent`
/// is a dot filled in the accent (the person on a family's line); `elbow` has no dot but a 1 pt line from the
/// rail's line to the content's first line (a branch's elbow, Departure 25).
public enum RailMarker: Equatable, Sendable { case dot, ring, none, accent, elbow }

/// The rail's one size tied to text, at the default text size: the height of a row's first line, on whose middle
/// the marker, the line's join and an elbow sit. `RailRow` and `RailElbow` each scale it (`.callout`).
enum RailMetrics {
    static let firstLineAtDefault: CGFloat = 21
}

/// A half of a row's line.
public enum RailSegment: Equatable, Sendable { case none, solid, dashed }

/// A row on a vertical line: a leading label (a year, say) in a right-aligned column, the line with its
/// marker, then the content. The line's upper half is `above` and its lower half `below`, so rows stacked
/// with no gap join into one line. At an accessibility text size the label goes above the content.
/// With `spoken` the whole row is one VoiceOver element reading it (the caller adds its actions and traits
/// to the row); without, the label and the content are read as they are. Nothing here knows of Bibles.
public struct RailRow<Content: View>: View {
    let marker: RailMarker
    let leading: String?
    let above: RailSegment
    let below: RailSegment
    let showsLeadingColumn: Bool
    let spoken: String?
    let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var scaledYearWidth: CGFloat = RailRow.yearWidthAtDefault
    @ScaledMetric(relativeTo: .callout) private var scaledMarkerSize: CGFloat = 7
    @ScaledMetric(relativeTo: .callout) private var scaledMarkerColumn: CGFloat = AppSpacing.md
    @ScaledMetric(relativeTo: .callout) private var scaledFirstLine: CGFloat = RailMetrics.firstLineAtDefault
    @Environment(\.libraryType) private var type

    /// The marker, its column and the first line, grown with the Library's type.
    private var markerSize: CGFloat { type.metric(scaledMarkerSize) }
    private var markerColumn: CGFloat { type.metric(scaledMarkerColumn) }
    private var firstLine: CGFloat { type.metric(scaledFirstLine) }

    public init(marker: RailMarker, leading: String?, above: RailSegment, below: RailSegment, showsLeadingColumn: Bool, spoken: String? = nil,
                @ViewBuilder content: () -> Content) {
        self.marker = marker
        self.leading = leading
        self.above = above
        self.below = below
        self.showsLeadingColumn = showsLeadingColumn
        self.spoken = spoken
        self.content = content()
    }

    /// The year column at the default text size: "4004 BC" with a little room.
    nonisolated static var yearWidthAtDefault: CGFloat { 56 }

    /// The year column's width: scaled with the caption above the default size, never narrower than at it, since
    /// below it the scaled width fell under the label's own ("4004…" at `.xSmall` on the phone).
    nonisolated static func yearWidth(scaled: CGFloat) -> CGFloat { max(scaled, yearWidthAtDefault) }

    private var yearWidth: CGFloat { type.metric(Self.yearWidth(scaled: scaledYearWidth)) }

    /// Whether the label goes above the content at this text size.
    nonisolated static func yearAbove(_ size: DynamicTypeSize) -> Bool { size.isAccessibilitySize }

    private var labelAbove: Bool { Self.yearAbove(dynamicTypeSize) }
    private var leadingWidth: CGFloat { showsLeadingColumn && !labelAbove ? yearWidth + AppSpacing.xs : 0 }

    public var body: some View {
        row.modifier(SpokenRow(spoken: spoken))
    }

    private var row: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            if showsLeadingColumn && !labelAbove { label.frame(width: yearWidth, alignment: .trailing) }
            Spacer(minLength: 0).frame(width: markerColumn)
            if labelAbove, let leading {
                VStack(alignment: .leading, spacing: 0) {
                    labelText(leading)
                    content
                }
            } else {
                content
            }
        }
        .padding(.vertical, AppSpacing.xxs / 2)
        .background(alignment: .topLeading) { line.padding(.leading, leadingWidth) }
    }

    @ViewBuilder private var label: some View {
        if let leading { labelText(leading) } else { Spacer(minLength: 0) }
    }

    private func labelText(_ text: String) -> some View {
        Text(text)
            .font(type.font(.caption))
            .monospacedDigit()
            .foregroundStyle(Color.inkSecondary)
            .lineLimit(1)
    }

    /// The line meets at the marker's middle, not the row's: in a row of several lines (an accessibility size) a
    /// line split at the row's middle left the first row's marker floating above where its line began.
    private var line: some View {
        let markerMiddle = AppSpacing.xxs / 2 + firstLine / 2
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                segment(above).frame(height: markerMiddle)
                segment(below)
            }
            markerView.padding(.top, markerMiddle - markerSize / 2)
            elbow.padding(.top, markerMiddle - HairlineRule.thickness / 2)
        }
        .frame(width: markerColumn)
    }

    /// From the line's middle toward the content: the column's other half and the gap beside it, stopping `xxs` short of the text.
    @ViewBuilder private var elbow: some View {
        if marker == .elbow {
            let width = markerColumn / 2 + AppSpacing.xs - AppSpacing.xxs
            HairlineRule(.horizontal).frame(width: width).offset(x: width / 2)
        }
    }

    @ViewBuilder private func segment(_ segment: RailSegment) -> some View {
        switch segment {
        case .none: Color.clear
        case .solid: HairlineRule(.vertical)
        case .dashed: DashedRule().stroke(Color.inkRule, style: StrokeStyle(lineWidth: HairlineRule.thickness, dash: [3, 3]))
                .frame(width: HairlineRule.thickness)
        }
    }

    @ViewBuilder private var markerView: some View {
        switch marker {
        case .none, .elbow: EmptyView()
        case .accent: Circle().fill(Color.accent).frame(width: markerSize, height: markerSize)
        case .dot: Circle().fill(Color.inkSecondary).frame(width: markerSize, height: markerSize)
        case .ring:
            Circle().fill(Color.paperPage)
                .overlay(Circle().strokeBorder(Color.inkSecondary, lineWidth: 1.25))
                .frame(width: markerSize, height: markerSize)
        }
    }
}

/// The short └ before a run on a branch: a line down from the row's top to the first line's middle, then across a
/// scaled `sm`. Set first in the run's row (top-aligned, `xxs` before the text), it hangs the run from the name above it.
public struct RailElbow: View {
    @ScaledMetric(relativeTo: .callout) private var scaledWidth: CGFloat = AppSpacing.sm
    @ScaledMetric(relativeTo: .callout) private var scaledFirstLine: CGFloat = RailMetrics.firstLineAtDefault
    @Environment(\.libraryType) private var type

    public init() {}

    private var width: CGFloat { type.metric(scaledWidth) }

    /// The elbow's height: the row's top padding and half the first line.
    private var height: CGFloat { AppSpacing.xxs / 2 + type.metric(scaledFirstLine) / 2 }

    public var body: some View {
        ElbowShape()
            .stroke(Color.inkRule, lineWidth: HairlineRule.thickness)
            .frame(width: width, height: height)
            .offset(y: -AppSpacing.xxs / 2)
    }
}

/// A line down the left edge to the bottom, then right along it.
private struct ElbowShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + HairlineRule.thickness / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + HairlineRule.thickness / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
    }
}

/// One VoiceOver element reading `spoken` in place of what the row holds; nothing when there is none.
private struct SpokenRow: ViewModifier {
    let spoken: String?

    func body(content: Content) -> some View {
        if let spoken {
            content.accessibilityElement(children: .ignore).accessibilityLabel(spoken)
        } else {
            content
        }
    }
}

/// A vertical line down the middle of its frame, to be stroked.
private struct DashedRule: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

/// Rows stacked with no gap, so their lines join; each row carries its own spacing. Lazy: a row is made as it
/// nears the screen, since a book's hundred-odd rows made at once took most of its page's open (Genesis 190 ms of 220,
/// debug). A row's `.id` still scrolls to it and reports it on screen.
public struct TimelineRail<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) { content }
    }
}
