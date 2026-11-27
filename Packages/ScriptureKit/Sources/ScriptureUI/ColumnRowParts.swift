import SwiftUI

/// A highlight's marker: its color as a small dot with a hairline keyline, or the underline glyph
/// for a note anchored without a color.
struct MarkerGlyph: View {
    let color: MarkupColor?

    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 10

    var body: some View {
        if let color {
            Circle()
                .fill(Color(markup: color))
                .overlay(Circle().strokeBorder(Color.inkRule, lineWidth: 0.5))
                .frame(width: size, height: size)
        } else {
            Image(systemName: "underline")
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
        }
    }
}

/// The marker as a button that opens the swatch popover, with a 24 pt hit area.
struct ColorDotButton: View {
    let color: MarkupColor?
    let colorID: UUID?
    let chips: [ColorChip]
    let onRecolor: (UUID?) -> Void

    @State private var isPopoverShown = false
    @ScaledMetric(relativeTo: .caption) private var hitSize: CGFloat = 24

    private var colorName: String? {
        colorID.flatMap { id in chips.first { $0.id == id }?.name }
    }

    var body: some View {
        Button {
            isPopoverShown = true
        } label: {
            MarkerGlyph(color: color)
                .frame(width: hitSize, height: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(colorName.map { "\($0). Click to change the color." } ?? "No color. Click to add one.")
        .accessibilityLabel("Change Color")
        .accessibilityValue(colorName ?? "No color")
        .popover(isPresented: $isPopoverShown, arrowEdge: .bottom) {
            SwatchRowView(
                chips: chips,
                current: colorID,
                onPick: { id in
                    isPopoverShown = false
                    onRecolor(id)
                },
                onNoColor: {
                    isPopoverShown = false
                    onRecolor(nil)
                },
                noColorIsCurrent: colorID == nil,
                onAdd: { isPopoverShown = false })
        }
    }
}

/// A small symbol button in a row (Done, Delete): plain, secondary ink, 24 pt hit area, labelled.
struct RowSymbolButton: View {
    let title: String
    let symbol: String
    var role: ButtonRole? = nil
    /// Secondary ink unless the button is the surface's one call to action (the composer's Send).
    var tint: Color = .inkSecondary
    let action: () -> Void

    @ScaledMetric(relativeTo: .caption) private var hitSize: CGFloat = 24

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: symbol)
                .font(.callout)
                .frame(minWidth: hitSize, minHeight: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .help(title)
        .accessibilityLabel(title)
    }
}

extension View {
    /// The note editor's field (DESIGN.md › Inputs): `paper.overlay` at the medium radius with a
    /// 1 pt `ink.rule` stroke. Shared by the note editor, the assistant's composer and a prompt's
    /// text in Settings; the caller sets the inner padding.
    func editorSurface() -> some View {
        background(Color.paperOverlay, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous).strokeBorder(Color.inkRule, lineWidth: 1))
    }

    /// A column row's surface: nothing at rest, the accent wash when its highlight is selected.
    /// Rows are separated by rhythm, never by a border.
    func columnRowSurface(isLit: Bool, reduceMotion: Bool) -> some View {
        background(
            isLit ? Color.accentWash : Color.clear,
            in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isLit)
    }

    /// One "Color …" action per swatch, so VoiceOver can recolor a row without the popover.
    func colorActions(chips: [ColorChip], current: UUID?, onRecolor: @escaping (UUID?) -> Void) -> some View {
        accessibilityActions {
            ForEach(chips.filter { $0.id != current }) { chip in
                Button("Color \(chip.name)") { onRecolor(chip.id) }
            }
            if current != nil {
                Button("No Color") { onRecolor(nil) }
            }
        }
    }
}
