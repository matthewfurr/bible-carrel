#if os(iOS)
import SwiftUI

/// The label of a menu over a list (the Notes tab's three, the search tab's scope and order): the
/// current choice and the menu's chevrons in a capsule on `paper.panel`, on `accent.wash` when the
/// choice is not the default. VoiceOver reads the menu's name with the choice as its value.
struct PhoneMenuLabel: View {
    let name: String
    let choice: String
    let isChanged: Bool

    init(_ name: String, choice: String, isChanged: Bool) {
        self.name = name
        self.choice = choice
        self.isChanged = isChanged
    }

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Text(choice)
            Image(systemName: "chevron.up.chevron.down")
                .imageScale(.small)
                .foregroundStyle(Color.inkSecondary)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.inkPrimary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(isChanged ? Color.accentWash : Color.paperPanel, in: Capsule())
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(choice)
    }
}
#endif
