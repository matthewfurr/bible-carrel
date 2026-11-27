import ScriptureModel
import SwiftUI

/// The scope's prompts above the composer, before the first message: per section (in
/// `PromptSection` order) a header in plain `Text` (`.caption` semibold in `ink.secondary`, the
/// Label style of DESIGN.md's type ladder) and a grid of tiles: one column at the inspector's
/// default 320 pt, two from about 400 pt. A section with no enabled prompt has no header, because it
/// is not in `prompts` at all.
struct PromptTilesView: View {
    let prompts: [PromptTemplateItem]
    let isDisabled: Bool
    let onRun: (UUID) -> Void

    @ScaledMetric(relativeTo: .callout) private var tileMinWidth: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(sections, id: \.self) { section in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: AppSpacing.xs)],
                        alignment: .leading,
                        spacing: AppSpacing.xs
                    ) {
                        ForEach(prompts.filter { $0.section == section }) { prompt in
                            PromptTile(prompt: prompt, isDisabled: isDisabled) { onRun(prompt.id) }
                        }
                    }
                }
            }
        }
    }

    /// The sections that have at least one prompt, in the order sections are shown.
    private var sections: [PromptSection] {
        let present = Set(prompts.map(\.section))
        return PromptSection.allCases.filter(present.contains)
    }
}

/// One prompt as a tonal tile: its title and the sentence under it on `paper.overlay`, one step
/// up from the panel, with no stroke, shadow or symbol. Hover is the `accent.wash`.
struct PromptTile: View {
    let prompt: PromptTemplateItem
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(prompt.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.inkPrimary)
                if !prompt.summary.isEmpty {
                    Text(prompt.summary)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(3)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(AppSpacing.sm)
            // Fill the column, and the row's height when a neighbour's summary runs longer.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                shape
                    .fill(isHovered && !isDisabled ? Color.accentWash : Color.paperOverlay)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isHovered)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
        .help(prompt.summary.isEmpty ? prompt.title : prompt.summary)
        .accessibilityLabel(prompt.title)
        .accessibilityHint(prompt.summary)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
    }
}
