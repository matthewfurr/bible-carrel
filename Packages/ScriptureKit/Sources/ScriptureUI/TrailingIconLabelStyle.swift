import SwiftUI

/// A label's title, then its icon at the trailing edge: the chapter-end "Next: John 16 →" on
/// both apps. The icon is decorative, as it is in the system's title-and-icon style, so VoiceOver
/// reads the title alone.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        // `xs` matches the gap the system's title-and-icon style leaves on the Previous link.
        HStack(spacing: AppSpacing.xs) {
            configuration.title
            configuration.icon
                .accessibilityHidden(true)
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}
