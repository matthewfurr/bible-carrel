import ScriptureData
import SwiftUI

/// One row of the Notes browser, as `NotesBrowserRowParts` words it: line 1 is the marker, the
/// reference (a conversation's title and place) with its translation, and the time or date
/// trailing; under it the marked words in the page's italic on their colour, then up to three
/// lines of the note (a conversation's last turn in full ink), then the versions mark; on the Mac
/// the mark shows the versions in a popover on itself. Read by VoiceOver as one element.
struct NotesBrowserRow: View {
    @Environment(\.pageFace) private var pageFace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let entry: NotesBrowserEntry
    let parts: NotesBrowserRowParts
    /// The selection, drawn as the accent wash (the notes column's row surface); the system's
    /// solid bar is never used. Text colors do not change.
    let isSelected: Bool
    /// Whether the versions popover shows: the mark sets it, and so does the list's Show Versions.
    @Binding var versionsShown: Bool
    /// The Notes window's, for the popover's choices.
    let undoManager: UndoManager?

    @ScaledMetric(relativeTo: .body) private var markerWidth: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                marker
                    .frame(width: markerWidth)
                Text(parts.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(isThread ? 1 : nil)
                if let place = parts.placeAfterTitle {
                    Text(place)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                }
                if let translationID = parts.translationID {
                    Text(translationID)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer(minLength: AppSpacing.xs)
                Text(parts.when)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.inkTertiary)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if let quote = parts.quote {
                    Text(filledQuote(quote))
                        .font(pageFace.quoteFont())
                        .foregroundStyle(parts.quoteIsFilled ? Color.inkPrimary : Color.inkSecondary)
                        .lineLimit(2)
                }
                switch parts.note {
                case .markdown(let body):
                    NoteBodyText(body, book: BookCatalog.book(code: entry.book), font: .callout, previewLines: 3)
                case .lastTurn(let line):
                    Text(line)
                        .font(.callout)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                case nil:
                    EmptyView()
                }
                if let versions = parts.versions {
                    versionsMark(versions)
                }
            }
            .padding(.leading, markerWidth + AppSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .columnRowSurface(isLit: isSelected, reduceMotion: reduceMotion)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(parts.spoken)
        #if os(macOS)
        .accessibilityActions {
            if let versions = parts.versions {
                Button(versions) { versionsShown = true }
            }
        }
        #endif
    }

    /// The marked words on their colour, line by line as on the page; primary ink keeps its
    /// contrast on every mark fill (`PaletteTests`). Without a colour the words sit on the page.
    private func filledQuote(_ quote: String) -> AttributedString {
        var text = AttributedString(quote)
        if parts.quoteIsFilled, let color = entry.color { text.backgroundColor = Color(markup: color) }
        return text
    }

    private var versionsSubject: VersionsSubject {
        if case .keptVersion(let id) = entry.kind { return .orphan(id) }
        return .note(entry.id)
    }

    @ViewBuilder
    private func versionsMark(_ text: String) -> some View {
        #if os(macOS)
        VersionsMarkButton(text: text, subject: versionsSubject, isShown: $versionsShown, undoManager: undoManager)
        #else
        VersionsMark(text: text)
        #endif
    }

    private var isThread: Bool {
        if case .thread = entry.kind { return true }
        return false
    }

    @ViewBuilder
    private var marker: some View {
        switch entry.kind {
        case .bookmark:
            Image(systemName: "bookmark.fill")
                .font(.caption)
                .foregroundStyle(Color.accent)
                .accessibilityLabel(kindName)
        case .thread:
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(Color.assistant)
                .accessibilityLabel(kindName)
        case .keptVersion:
            Image(systemName: VersionText.symbolName)
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
                .accessibilityLabel(kindName)
        case .note, .highlight:
            if entry.isChapterNote {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityLabel(kindName)
            } else {
                MarkerGlyph(color: entry.color)
                    .accessibilityLabel(kindName)
            }
        }
    }

    private var kindName: String { NotesBrowserRowParts.kindName(entry) }
}
