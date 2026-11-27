import SwiftUI

extension Color {
    public init(markup: MarkupColor) {
        #if canImport(AppKit)
        self.init(nsColor: markup.platformColor)
        #else
        self.init(uiColor: markup.platformColor)
        #endif
    }
}

/// A row of color circles with a check on the current one, an optional "No color" circle
/// (underline only) and a `plus.circle` to add a color. Used in the selection menu and in the
/// color popover of a card.
public struct SwatchRowView: View {
    let chips: [ColorChip]
    let current: UUID?
    let onPick: (UUID) -> Void
    /// Shown when set: clears the color of the highlight being edited.
    let onNoColor: (() -> Void)?
    let noColorIsCurrent: Bool
    let onAdd: () -> Void

    /// 24 pt: the smallest hit area DESIGN.md allows, scaled with the text size.
    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 24

    public init(
        chips: [ColorChip],
        current: UUID?,
        onPick: @escaping (UUID) -> Void,
        onNoColor: (() -> Void)? = nil,
        noColorIsCurrent: Bool = false,
        onAdd: @escaping () -> Void
    ) {
        self.chips = chips
        self.current = current
        self.onPick = onPick
        self.onNoColor = onNoColor
        self.noColorIsCurrent = noColorIsCurrent
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(chips) { chip in
                Button { onPick(chip.id) } label: {
                    ZStack {
                        Circle()
                            .fill(Color(markup: chip.color))
                        Circle()
                            .strokeBorder(Color.inkRule, lineWidth: 1)
                        if chip.id == current {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.inkPrimary)
                        }
                    }
                    .frame(width: chipSize, height: chipSize)
                }
                .buttonStyle(.plain)
                .help(chip.name)
                .accessibilityLabel(chip.name)
                .accessibilityAddTraits(chip.id == current ? .isSelected : [])
            }
            if let onNoColor {
                Button(action: onNoColor) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.inkSecondary, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        Image(systemName: noColorIsCurrent ? "checkmark" : "underline")
                            .font(.caption.weight(noColorIsCurrent ? .bold : .regular))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .frame(width: chipSize, height: chipSize)
                }
                .buttonStyle(.plain)
                .help("No Color (underline only)")
                .accessibilityLabel("No Color")
                .accessibilityAddTraits(noColorIsCurrent ? .isSelected : [])
            }
            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: chipSize, height: chipSize)
            }
            .buttonStyle(.plain)
            .help("Add Color…")
            .accessibilityLabel("Add Color")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }
}
