#if os(iOS)
import SwiftUI

/// One mark on the phone, as the Notes tab and search list it: an optional symbol and the
/// reference, the date on the trailing edge, the quoted words in the page's serif on their
/// highlight color, then up to two lines of the note. A row with rhythm: no card, no fill.
///
/// VoiceOver reads the row as one element; `kind(_:)` puts the mark's kind first ("Bookmark",
/// "Highlight"), as the Mac's notes browser row does, since the symbol is hidden and a colored
/// mark has none.
struct PhoneMarkRow: View {
    @Environment(\.pageFace) private var pageFace
    private let symbolName: String?
    private let reference: String
    private let date: Date?
    /// The quoted words, possibly with search matches marked; the row adds the mark's fill.
    private let quote: AttributedString
    private let color: MarkupColor?
    private let note: AttributedString?
    private var kindName: String?
    /// "2 versions" on a note with kept versions, "Kept version" on a text with no note (spec 4.1, 4.2).
    private let versions: String?

    init(symbolName: String?, reference: String, date: Date?, quotedText: String, color: MarkupColor?, body: AttributedString?,
         versions: String? = nil) {
        self.init(symbolName: symbolName, reference: reference, date: date,
                  quote: AttributedString(quotedText), color: color, body: body, versions: versions)
    }

    /// Search's row: the quoted words with the query's matches already marked
    /// (`SearchRanker.bolded`), so the matched word is bold and underlined in the quote as in the
    /// note; the row sets the quote's matches in the face's semibold italic.
    init(symbolName: String?, reference: String, date: Date?, quote: AttributedString, color: MarkupColor?, body: AttributedString?,
         versions: String? = nil) {
        self.versions = versions
        self.symbolName = symbolName
        self.reference = reference
        self.date = date
        self.quote = quote
        self.color = color
        self.note = body
    }

    /// The mark's kind, read before the rest of the row.
    func kind(_ name: String) -> PhoneMarkRow {
        var row = self
        row.kindName = name
        return row
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.caption)
                        .foregroundStyle(symbolColor(symbolName))
                        .accessibilityHidden(true)
                }
                Text(reference)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkPrimary)
                Spacer(minLength: AppSpacing.xs)
                if let date {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            if !quote.characters.isEmpty {
                Text(filledQuote)
                    .font(pageFace.quoteFont())
                    .foregroundStyle(color == nil ? Color.inkSecondary : Color.inkPrimary)
                    .lineLimit(2)
            }
            if let note, !note.characters.isEmpty {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
            }
            // Quiet and not a button: a tap on the row opens it, and the versions are one tap further.
            if let versions {
                VersionsMark(text: versions)
                    .padding(.top, AppSpacing.xxs)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel { label in
            if let kindName { Text(kindName) }
            label
            // The row's kind already says "Kept version"; its mark would say it twice.
            if let versions, versions != kindName { Text(versions) }
        }
    }

    /// The quoted words on their mark's fill, line by line as on the page; primary ink keeps its
    /// contrast on every mark fill (`PaletteTests`), matched or not, and a match's underline is in
    /// that ink. Without a color the words sit on the page.
    private var filledQuote: AttributedString {
        var text = pageFace.settingMatches(quote, .callout, italic: true)
        if let color { text.backgroundColor = Color(markup: color) }
        return text
    }

    /// The bookmark in the accent and the conversation in plum, as everywhere else; the rest in
    /// secondary ink.
    private func symbolColor(_ name: String) -> Color {
        switch name {
        case "bookmark.fill": Color.accent
        case "sparkles": Color.assistant
        default: Color.inkSecondary
        }
    }
}
#endif
