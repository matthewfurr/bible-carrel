import SwiftUI

/// A group's heading in the Notes window and the phone's Notes tab: the day or the book in
/// `.headline` `ink.primary`, its count trailing in `.callout` `ink.secondary` with monospaced
/// digits. One VoiceOver element with the header trait ("Today, 2 notes"); never a stop, never
/// selected. It has no padding of its own: each list sets its own space around it.
struct NotesGroupHeading: View {
    let title: String
    let count: String
    let spoken: String

    init(title: String, count: String, spoken: String) {
        self.title = title
        self.count = count
        self.spoken = spoken
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Spacer(minLength: AppSpacing.xs)
            Text(count)
                .font(.callout.monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isHeader)
    }
}
