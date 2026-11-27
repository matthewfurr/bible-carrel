import SwiftUI

/// A Library page's title: the name in the page face, light, over its subtitle in the face's italic
/// (Departure 21). About's head, taken out unchanged; a person's page sets its name and the data's label
/// the same way. The subtitle is the data's own, nothing where there is none.
struct LibraryPageTitle: View {
    let title: String
    let subtitle: String?
    @Environment(\.pageFace) private var pageFace
    @Environment(\.libraryType) private var type

    init(_ title: String, subtitle: String?) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(type.pageFont(pageFace, .largeTitle, weight: .light))
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(type.pageFont(pageFace, .callout, italic: true))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        // The name and subtitle can be selected and copied (Matt's review, 2026-11-24).
        .librarySelectable()
    }
}
