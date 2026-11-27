import SwiftUI

/// One row of a `FactList`: a label, its value and what VoiceOver says of it. The value is a view held
/// type-erased (a handful of rows); `actions` are the value's links, reached as named actions. The row's
/// id is its label, so labels must be unique within a list.
@MainActor public struct FactRow: Identifiable {
    public struct Action {
        public let name: String
        public let perform: () -> Void

        public init(_ name: String, perform: @escaping () -> Void) {
            self.name = name
            self.perform = perform
        }
    }

    public let id: String
    public let label: String, spoken: String, startsGroup: Bool, actions: [Action]
    let value: AnyView

    /// `spoken` is the value as VoiceOver reads it ("Testament, Old Testament, the Law"); `startsGroup`
    /// leaves a gap of `xs` above the row.
    public init<V: View>(_ label: String, spoken: String, startsGroup: Bool = false, actions: [Action] = [],
                         @ViewBuilder value: () -> V) {
        id = label
        self.label = label
        self.spoken = spoken
        self.startsGroup = startsGroup
        self.actions = actions
        self.value = AnyView(value())
    }
}

/// Facts as rows of a label and a value: the labels small, upper case and right-aligned on one edge in a
/// column as wide as the longest, the values beside them wrapping under themselves. When the longest
/// label would take more than 40% of the width (an accessibility text size on a phone) each label sits
/// over its value. A row is one element for VoiceOver. Reused by a person's page.
public struct FactList: View {
    let rows: [FactRow]

    /// Each label's natural width, by row; the column takes the largest.
    @State private var labelWidths: [String: CGFloat] = [:]
    @State private var width: CGFloat = 0
    @ScaledMetric(relativeTo: .callout) private var scaledGap: CGFloat = AppSpacing.xs
    @ScaledMetric(relativeTo: .caption) private var scaledTracking: CGFloat = 0.7
    @Environment(\.libraryType) private var type

    /// The gap and the labels' tracking, grown with the Library's type.
    private var gap: CGFloat { type.metric(scaledGap) }
    private var tracking: CGFloat { type.metric(scaledTracking) }

    public init(_ rows: [FactRow]) {
        self.rows = rows
    }

    /// The most of the list's width the label column may take before the labels stack.
    public nonisolated static let widestLabelShare: CGFloat = 0.4

    /// Whether the labels go over their values: the column and the gap past `widestLabelShare` of `width`.
    public nonisolated static func stacks(labelWidth: CGFloat, gap: CGFloat, width: CGFloat) -> Bool {
        width > 0 && labelWidth + gap > widestLabelShare * width
    }

    /// The widest measured label among the rows now shown; a label that has gone does not count.
    nonisolated static func widest(of widths: [String: CGFloat], in ids: [String]) -> CGFloat {
        ids.compactMap { widths[$0] }.max() ?? 0
    }

    /// The measurements of the rows that are still shown.
    nonisolated static func widths(_ widths: [String: CGFloat], keeping ids: [String]) -> [String: CGFloat] {
        widths.filter { ids.contains($0.key) }
    }

    private var widest: CGFloat { Self.widest(of: labelWidths, in: rows.map(\.id)) }

    public var body: some View {
        let stacked = Self.stacks(labelWidth: widest, gap: gap, width: width)
        VStack(alignment: .leading, spacing: gap) {
            ForEach(rows) { row in
                rowView(row, stacked: stacked)
                    .padding(.top, row.startsGroup ? gap : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: rows.map(\.id)) { _, ids in labelWidths = Self.widths(labelWidths, keeping: ids) }
    }

    private func rowView(_ row: FactRow, stacked: Bool) -> some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: gap))
        return layout {
            label(row, stacked: stacked)
            row.value
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.label), \(row.spoken)")
        .accessibilityActions {
            ForEach(Array(row.actions.enumerated()), id: \.offset) { _, action in
                Button(action.name, action: action.perform)
            }
        }
    }

    /// Measured at its natural width, then set in the column's width, right-aligned.
    private func label(_ row: FactRow, stacked: Bool) -> some View {
        Text(row.label)
            .font(type.font(.caption, weight: .semibold))
            .textCase(.uppercase)
            .kerning(tracking)
            .foregroundStyle(Color.inkSecondary)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { labelWidths[row.id] = $0 }
            .frame(width: stacked || widest == 0 ? nil : widest, alignment: stacked ? .leading : .trailing)
    }
}
