import ScriptureData
import SwiftUI

/// What the band and the reader's popover both hold: the title line, the week's readings in equal columns, the plan's progress.
///
/// "This week" in the page face with the week's title line beside it and "The whole plan" at the
/// trailing end; under it each reading as a tick circle over its passages, one to a line, in
/// columns of at least a scaled 140 pt that wrap to a second row; then the plan's progress line.
/// No fill and no card: the band's hairline (the front page's) or the popover's edge closes it.
public struct PlanWeekSummary: View {
    let model: ReadingPlanModel
    let onShowWholePlan: () -> Void
    /// After a passage is opened (the popover closes on it).
    let onOpenedPassage: () -> Void

    @Environment(\.pageFace) private var pageFace
    @ScaledMetric(relativeTo: .callout) private var minimumColumnWidth: CGFloat = PlanWeekSummary.minimumColumnWidth
    @ScaledMetric(relativeTo: .title3) private var circleHitSize: CGFloat = 24

    /// A reading's column at the default text size: four fit the band at the usual 1100 pt window
    /// (736 pt between its `lg` sides, the chapter pane being at its narrowest, 316 pt); a long
    /// passage wraps inside its column.
    nonisolated static let minimumColumnWidth: CGFloat = 140

    /// The columns the readings' adaptive grid makes in `width`, `md` apart: as many as fit at
    /// `minimum` each, at least one.
    nonisolated static func columnCount(width: CGFloat, minimum: CGFloat) -> Int {
        max(1, Int(((width + AppSpacing.md) / (minimum + AppSpacing.md)).rounded(.down)))
    }

    public init(model: ReadingPlanModel, onShowWholePlan: @escaping () -> Void) {
        self.init(model: model, onShowWholePlan: onShowWholePlan, onOpenedPassage: {})
    }

    init(model: ReadingPlanModel, onShowWholePlan: @escaping () -> Void, onOpenedPassage: @escaping () -> Void) {
        self.model = model
        self.onShowWholePlan = onShowWholePlan
        self.onOpenedPassage = onOpenedPassage
    }

    public var body: some View {
        if let thisWeek = model.thisWeek {
            VStack(alignment: .leading, spacing: 0) {
                header(thisWeek)
                readings(thisWeek.week)
                    .padding(.top, AppSpacing.sm)
                PlanProgressLine(progress: model.progress)
                    .padding(.top, AppSpacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }

    /// One line while it fits; else (the popover, a narrow window) the title line goes under
    /// "This week", whole, rather than breaking inside its date.
    private func header(_ thisWeek: ReadingPlanModel.ThisWeek) -> some View {
        let line = PlanWeekText.titleLine(thisWeek.week, count: thisWeek.count, today: model.today,
                                          locale: model.locale, calendar: model.calendar)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                title
                titleLine(line)
                Spacer(minLength: AppSpacing.md)
                wholePlanLink
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    title
                    Spacer(minLength: AppSpacing.md)
                    wholePlanLink
                }
                titleLine(line)
            }
        }
    }

    private var title: some View {
        Text("This week")
            .font(pageFace.swiftUIFont(.title3))
            .foregroundStyle(Color.inkPrimary)
            .accessibilityAddTraits(.isHeader)
            .fixedSize()
    }

    private func titleLine(_ line: String) -> some View {
        Text(line)
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var wholePlanLink: some View {
        Button(action: onShowWholePlan) {
            Label("The whole plan", systemImage: "chevron.right")
                .labelStyle(.trailingIcon)
        }
        .buttonStyle(.plain)
        .font(.callout.weight(.medium))
        .foregroundStyle(Color.accent)
        .help("Reading Plan (⌥⌘P)")
        .fixedSize()
    }

    private func readings(_ week: PlanWeek) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumColumnWidth), spacing: AppSpacing.md, alignment: .topLeading)],
                  alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(Array(week.readings.enumerated()), id: \.element.id) { offset, reading in
                PlanReadingRow(reading: reading, index: offset, count: week.readings.count, layout: .stacked,
                               hitSize: circleHitSize, model: model, onOpened: onOpenedPassage)
            }
        }
    }
}

/// The summary as the reader's popover: a scaled 360 pt wide, padded `xs`; `onDone` closes it after a passage or the whole plan is opened.
public struct PlanWeekPopover: View {
    let model: ReadingPlanModel
    let onShowWholePlan: () -> Void
    let onDone: () -> Void

    @ScaledMetric(relativeTo: .callout) private var width: CGFloat = 360

    public init(model: ReadingPlanModel, onShowWholePlan: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.model = model
        self.onShowWholePlan = onShowWholePlan
        self.onDone = onDone
    }

    public var body: some View {
        PlanWeekSummary(model: model,
                        onShowWholePlan: {
                            onShowWholePlan()
                            onDone()
                        },
                        onOpenedPassage: onDone)
            .padding(AppSpacing.xs)
            .frame(width: width)
    }
}
