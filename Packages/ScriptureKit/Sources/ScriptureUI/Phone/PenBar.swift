#if os(iOS)
import SwiftUI

/// The bottom toolbar while the pen is on, in place of the tab bar: one button per color in the
/// markup's order, each a filled circle in its color with the pen's color ringed and marked
/// selected, scrolling sideways when they do not fit; then Done, which turns the pen off. A
/// color chosen while a mark is selected recolors it.
struct PenBar: ToolbarContent {
    let pen: PenModel
    let chips: [ColorChip]

    var body: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            PenColorRow(pen: pen, chips: chips)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button { pen.turnOff() } label: {
                Label("Done", systemImage: "checkmark")
            }
        }
    }
}

private struct PenColorRow: View {
    let pen: PenModel
    let chips: [ColorChip]
    /// The circle, scaled with the text size.
    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = AppSpacing.lg
    /// The ring around the pen's color, outside the circle.
    @ScaledMetric(relativeTo: .body) private var ringGap: CGFloat = AppSpacing.xxs

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(chips) { chip in
                    let isCurrent = chip.id == pen.colorID
                    Button {
                        pen.chooseColor(chip.id)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Circle()
                            .fill(Color(markup: chip.color))
                            .overlay(Circle().strokeBorder(Color.inkRule, lineWidth: 1))
                            .frame(width: chipSize, height: chipSize)
                            .padding(ringGap)
                            .overlay {
                                if isCurrent { Circle().strokeBorder(Color.accent, lineWidth: 2) }
                            }
                            .frame(minWidth: PenHandleView.minimumTarget, minHeight: PenHandleView.minimumTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(chip.name)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}
#endif
