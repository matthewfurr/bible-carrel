import ScriptureData
import SwiftUI

/// The circle that ticks a reading: `circle` in `ink.secondary`, `checkmark.circle.fill` in the accent.
public struct TickCircle: View {
    let isTicked: Bool
    let hitSize: CGFloat
    let action: () -> Void

    public init(isTicked: Bool, hitSize: CGFloat, action: @escaping () -> Void) {
        self.isTicked = isTicked
        self.hitSize = hitSize
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isTicked ? Color.accent : Color.inkSecondary)
                .frame(width: hitSize, height: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isTicked ? "Mark as not read" : "Mark as read")
        .accessibilityLabel(isTicked ? "Mark as not read" : "Mark as read")
    }
}

/// One reading: its circle, its passages as buttons (one to a line, or on one line joined by " · "),
/// its label quietly after them.
public struct PlanReadingRow: View {
    public enum Layout: Sendable { case stacked, inline }

    let reading: PlanReading
    let index: Int
    let count: Int
    let layout: Layout
    let hitSize: CGFloat
    /// The least height of each passage's button: the phone's thumb target (its `hitSize`); none on the Mac.
    let passageHeight: CGFloat
    let model: ReadingPlanModel
    /// After a passage is opened from the row (the reader's popover closes).
    let onOpened: () -> Void

    public init(reading: PlanReading, index: Int, count: Int, layout: Layout, hitSize: CGFloat, passageHeight: CGFloat = 0,
                model: ReadingPlanModel, onOpened: @escaping () -> Void = {}) {
        self.reading = reading
        self.index = index
        self.count = count
        self.layout = layout
        self.hitSize = hitSize
        self.passageHeight = passageHeight
        self.model = model
        self.onOpened = onOpened
    }

    public var body: some View {
        let isTicked = model.isTicked(reading)
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            TickCircle(isTicked: isTicked, hitSize: hitSize) { model.toggle(reading) }
            switch layout {
            case .stacked: stacked(isTicked: isTicked)
            case .inline: inline(isTicked: isTicked)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PlanWeekText.spoken(reading, index: index, count: count, isTicked: isTicked))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.toggle(reading) }
        .accessibilityActions {
            ForEach(Array(reading.passages.enumerated()), id: \.offset) { _, passage in
                if model.canOpen(passage) {
                    Button("Open \(passage.displayString)") { open(passage) }
                }
            }
        }
    }

    /// One line joined by " · " while it fits; where it does not (the largest sizes, a narrow
    /// window) the passages go one to a line. One set of views either way.
    private func inline(isTicked: Bool) -> some View {
        PassageLineLayout {
            ForEach(Array(reading.passages.enumerated()), id: \.offset) { offset, passage in
                if offset > 0 {
                    Text("·").font(.callout).foregroundStyle(Color.inkTertiary)
                        .accessibilityHidden(true)
                        .layoutValue(key: PassageLineLayout.Separator.self, value: true)
                }
                passageButton(passage, isTicked: isTicked)
            }
            if let label = reading.label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .layoutValue(key: PassageLineLayout.Trailing.self, value: true)
            }
        }
    }

    /// One to a line, `xxs` apart; touching where each is a thumb's height (the phone).
    private func stacked(isTicked: Bool) -> some View {
        VStack(alignment: .leading, spacing: passageHeight > 0 ? 0 : AppSpacing.xxs) {
            ForEach(Array(reading.passages.enumerated()), id: \.offset) { _, passage in
                passageButton(passage, isTicked: isTicked)
            }
            if let label = reading.label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private func open(_ passage: PlanPassage) {
        model.open(passage)
        onOpened()
    }

    /// The accent opens the passage; tertiary once ticked (it still opens). A passage the
    /// translation being read lacks is text in `ink.tertiary`, not a button, and its help says why.
    @ViewBuilder
    private func passageButton(_ passage: PlanPassage, isTicked: Bool) -> some View {
        if model.canOpen(passage) {
            Button { open(passage) } label: {
                Text(passage.displayString)
                    .frame(minHeight: passageHeight, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(isTicked ? Color.inkTertiary : Color.accent)
            .help("Open \(passage.displayString)")
        } else {
            Text(passage.displayString)
                .font(.callout)
                .foregroundStyle(Color.inkTertiary)
                .frame(minHeight: passageHeight, alignment: .leading)
                .help(model.unavailableHelp)
        }
    }
}

/// The plan's progress: 2 pt of the accent over an `ink.rule` track of the same height. It never animates.
public struct PlanProgressLine: View {
    let progress: PlanProgress

    public init(progress: PlanProgress) {
        self.progress = progress
    }

    public var body: some View {
        Rectangle()
            .fill(Color.inkRule)
            .frame(height: 2)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.accent)
                        .frame(width: proxy.size.width * min(max(progress.fraction, 0), 1))
                }
            }
            .transaction { $0.animation = nil }
            .accessibilityElement()
            .accessibilityLabel("Plan progress")
            .accessibilityValue("\(progress.read) of \(progress.total) readings")
    }
}

/// A reading's passages on one line, `xxs` apart (the label `xs` after them), on their first
/// baselines; when the line is wider than the space, one to a line with the separators left
/// out. `ViewThatFits` did the same by building the reading twice.
struct PassageLineLayout: Layout {
    /// The " · " between two passages: drawn only on one line.
    struct Separator: LayoutValueKey { static let defaultValue = false }
    /// The label after the passages.
    struct Trailing: LayoutValueKey { static let defaultValue = false }

    private struct Line {
        let fits: Bool
        let sizes: [CGSize]
        let size: CGSize
    }

    private func line(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Line {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        var width: CGFloat = 0
        for index in subviews.indices {
            if index > 0 { width += subviews[index][Trailing.self] ? AppSpacing.xs : AppSpacing.xxs }
            width += ideal[index].width
        }
        if proposal.width.map({ width <= $0 }) ?? true {
            let ascent = subviews.map { $0.dimensions(in: .unspecified)[.firstTextBaseline] }.max() ?? 0
            let height = subviews.indices.map { index in
                ascent - subviews[index].dimensions(in: .unspecified)[.firstTextBaseline] + ideal[index].height
            }.max() ?? 0
            return Line(fits: true, sizes: ideal, size: CGSize(width: width, height: height))
        }
        let column = ProposedViewSize(width: proposal.width, height: nil)
        let sizes = subviews.map { $0[Separator.self] ? .zero : $0.sizeThatFits(column) }
        let shown = subviews.indices.filter { !subviews[$0][Separator.self] }
        let height = shown.map { sizes[$0].height }.reduce(0, +) + AppSpacing.xxs * CGFloat(max(shown.count - 1, 0))
        return Line(fits: false, sizes: sizes, size: CGSize(width: shown.map { sizes[$0].width }.max() ?? 0, height: height))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        line(proposal, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let line = line(ProposedViewSize(width: bounds.width, height: bounds.height), subviews)
        if line.fits {
            let ascent = subviews.map { $0.dimensions(in: .unspecified)[.firstTextBaseline] }.max() ?? 0
            var x = bounds.minX
            for index in subviews.indices {
                if index > 0 { x += subviews[index][Trailing.self] ? AppSpacing.xs : AppSpacing.xxs }
                let baseline = subviews[index].dimensions(in: .unspecified)[.firstTextBaseline]
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + ascent - baseline), proposal: .unspecified)
                x += line.sizes[index].width
            }
        } else {
            var y = bounds.minY
            for index in subviews.indices {
                if subviews[index][Separator.self] {
                    subviews[index].place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: .zero)
                    continue
                }
                subviews[index].place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: nil))
                y += line.sizes[index].height + AppSpacing.xxs
            }
        }
    }

    /// The first line's baseline, so the circle beside it sits on it.
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard guide == .firstTextBaseline, let first = subviews.first else { return nil }
        let line = line(ProposedViewSize(width: bounds.width, height: bounds.height), subviews)
        if line.fits {
            return bounds.minY + (subviews.map { $0.dimensions(in: .unspecified)[.firstTextBaseline] }.max() ?? 0)
        }
        return bounds.minY + first.dimensions(in: ProposedViewSize(width: bounds.width, height: nil))[.firstTextBaseline]
    }
}
