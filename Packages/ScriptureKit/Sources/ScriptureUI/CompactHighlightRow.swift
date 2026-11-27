import SwiftUI

/// A highlight without a note, as one quiet row: marker, reference, and one line of the phrase in
/// the page's serif. The first click selects it (the reader outlines and scrolls to the phrase);
/// a click on it once selected, or Return, starts a note on it. Delete is undoable.
public struct CompactHighlightRow: View {
    @Environment(\.pageFace) private var pageFace
    let row: CompactRow
    let isLit: Bool
    let colorChips: [ColorChip]
    let onSelect: () -> Void
    let onAddNote: () -> Void
    let onDelete: () -> Void
    let onRecolor: (UUID?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .callout) private var horizontalInset: CGFloat = AppSpacing.sm
    @ScaledMetric(relativeTo: .callout) private var verticalInset: CGFloat = AppSpacing.xs

    public init(
        row: CompactRow,
        isLit: Bool,
        colorChips: [ColorChip] = [],
        onSelect: @escaping () -> Void,
        onAddNote: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRecolor: @escaping (UUID?) -> Void = { _ in }
    ) {
        self.row = row
        self.isLit = isLit
        self.colorChips = colorChips
        self.onSelect = onSelect
        self.onAddNote = onAddNote
        self.onDelete = onDelete
        self.onRecolor = onRecolor
    }

    private var colorName: String {
        row.colorID.flatMap { id in colorChips.first { $0.id == id }?.name } ?? "No color"
    }

    public var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            ColorDotButton(color: row.color, colorID: row.colorID, chips: colorChips, onRecolor: onRecolor)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(row.referenceString)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                Text(row.quotedText)
                    .font(pageFace.swiftUIFont(.callout))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppSpacing.xxs)
            if isLit {
                RowSymbolButton(title: "Delete Highlight", symbol: "trash", role: .destructive, action: onDelete)
            }
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .columnRowSurface(isLit: isLit, reduceMotion: reduceMotion)
        .contentShape(Rectangle())
        .onTapGesture { isLit ? onAddNote() : onSelect() }
        .contextMenu {
            Button("Add Note") { onAddNote() }
            Divider()
            Button("Delete Highlight", role: .destructive) { onDelete() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Highlight, \(row.referenceString), \(colorName)")
        .accessibilityValue(row.quotedText)
        .accessibilityAddTraits(isLit ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { isLit ? onAddNote() : onSelect() }
        .accessibilityAction(named: "Add Note") { onAddNote() }
        .accessibilityAction(named: "Delete Highlight") { onDelete() }
        .colorActions(chips: colorChips, current: row.colorID, onRecolor: onRecolor)
    }
}
