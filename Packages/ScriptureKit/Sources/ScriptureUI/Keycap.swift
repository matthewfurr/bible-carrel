import SwiftUI

/// One key: its glyph on a paper, at least a square, wider for "esc". The shortcuts sheet draws it
/// on `paper.overlay`; the palette, which is itself that paper, on `paper.panel`.
struct Keycap: View {
    let glyph: String
    let fill: Color
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 20

    init(_ glyph: String, fill: Color = .paperOverlay) {
        self.glyph = glyph
        self.fill = fill
    }

    var body: some View {
        Text(glyph)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, AppSpacing.xxs)
            .frame(minWidth: side, minHeight: side)
            .background(fill, in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
    }
}

/// Keycaps `xxs` apart; "–" is plain text between caps ("1 – 9").
struct KeycapRow: View {
    let keys: [String]
    let fill: Color

    init(_ keys: [String], fill: Color = .paperOverlay) {
        self.keys = keys
        self.fill = fill
    }

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                if key == "–" {
                    Text(key)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                } else {
                    Keycap(key, fill: fill)
                }
            }
        }
    }
}
