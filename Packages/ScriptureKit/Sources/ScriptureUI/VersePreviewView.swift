import ScriptureData
import SwiftUI

/// A reference from an assistant's reply, shown where it was clicked: the reference and the
/// translation, the verses in the page's serif with their numbers, and one button that goes to
/// the passage. The Mac shows it in a popover; the iPhone shows it in a sheet.
public struct VersePreviewView: View {
    @Environment(\.pageFace) private var pageFace
    let preview: VersePreview
    let openTitle: String
    let onOpen: () -> Void

    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 320
    @ScaledMetric(relativeTo: .body) private var maxTextHeight: CGFloat = 280

    public init(preview: VersePreview, openTitle: String, onOpen: @escaping () -> Void) {
        self.preview = preview
        self.openTitle = openTitle
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(preview.title)
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(preview.translationID)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
            ScrollView {
                Text(versesText)
                    .foregroundStyle(Color.inkPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: maxTextHeight)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer(minLength: 0)
                Button(openTitle, action: onOpen)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.xs)
        .frame(idealWidth: width)
    }

    /// Each verse's number in the caption style, then its text in the serif; poetry lines kept.
    private var versesText: AttributedString {
        var result = AttributedString()
        for (index, verse) in preview.verses.enumerated() {
            if index > 0 { result.append(AttributedString(verse.text.contains("\n") || preview.verses[index - 1].breakAfter ? "\n" : " ")) }
            var number = AttributedString(verse.endVerse.map { "\(verse.id.verse)-\($0)" } ?? "\(verse.id.verse)")
            number.font = .caption.monospacedDigit()
            number.foregroundColor = Color.inkSecondary
            var text = AttributedString("\u{2009}" + verse.text)
            text.font = pageFace.swiftUIFont(.body)
            result.append(number)
            result.append(text)
        }
        return result
    }
}

#Preview("Verse") {
    VersePreviewView(
        preview: VersePreview(
            reference: Reference(book: BookCatalog.book(code: "JHN")!, chapter: 15, verse: 4, endVerse: 5),
            translationID: "ESV",
            verses: [
                Verse(id: VerseLocation(book: "JHN", chapter: 15, verse: 4), translationID: "ESV",
                      text: "Abide in me, and I in you. As the branch cannot bear fruit by itself, unless it abides in the vine, neither can you, unless you abide in me.", breakAfter: false),
                Verse(id: VerseLocation(book: "JHN", chapter: 15, verse: 5), translationID: "ESV",
                      text: "I am the vine; you are the branches. Whoever abides in me and I in him, he it is that bears much fruit, for apart from me you can do nothing.", breakAfter: false),
            ]),
        openTitle: "Open",
        onOpen: {})
}
