import Foundation

/// What one row of the Notes window says, as words: the passage (a conversation's title and
/// place), the time or date, the marked words, the note's line, the versions mark and what
/// VoiceOver reads. Pure, so the row's text is pinned without drawing it.
struct NotesBrowserRowParts: Equatable {
    enum Note: Equatable {
        /// A note's body, shown as rendered markdown.
        case markdown(String)
        /// A conversation's last turn's first line, plain.
        case lastTurn(String)
    }

    /// The reference, or a conversation's title.
    var title: String
    /// A conversation's place, unless its title began with it.
    var placeAfterTitle: String?
    var translationID: String?
    /// The time under a day's heading, the date under a book's.
    var when: String
    /// A highlight's words, a note's anchor words, a bookmark's label, a kept version's words.
    var quote: String?
    /// Whether the quote sits on its mark's colour.
    var quoteIsFilled: Bool
    var note: Note?
    /// "2 versions" on a note with kept versions, "Kept version" on a text with no note.
    var versions: String?
    /// "Note, John 15:4, 8:14 AM": the kind, the passage, the title and versions where there are
    /// any, and the time or date last.
    var spoken: String

    static func make(_ entry: NotesBrowserEntry, underDay: Bool, calendar: Calendar, locale: Locale) -> NotesBrowserRowParts {
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        style = underDay ? style.hour().minute() : style.month(.abbreviated).day().year()
        let when = entry.modifiedAt.formatted(style)

        let isThread: Bool
        if case .thread = entry.kind { isThread = true } else { isThread = false }
        let kind = kindName(entry)
        let versions = versionsText(entry)

        var title = entry.referenceString
        var place: String?
        var quote: String? = entry.quotedText.isEmpty ? nil : entry.quotedText
        var note: Note?
        var spokenParts = [kind, entry.referenceString]
        if isThread {
            title = entry.body
            if !entry.body.hasPrefix(entry.referenceString) { place = entry.referenceString }
            note = entry.quotedText.isEmpty ? nil : .lastTurn(entry.quotedText)
            quote = nil
            spokenParts.append(entry.body)
        } else {
            note = entry.body.isEmpty ? nil : .markdown(entry.body)
            if entry.isChapterNote { quote = nil }
        }
        // The kind already says "Kept version"; its mark would say it twice.
        if let versions, versions != kind { spokenParts.append(versions) }
        spokenParts.append(when)

        return NotesBrowserRowParts(
            title: title, placeAfterTitle: place, translationID: entry.translationID, when: when,
            quote: quote, quoteIsFilled: quote != nil && entry.color != nil, note: note, versions: versions,
            spoken: spokenParts.joined(separator: ", "))
    }

    static func kindName(_ entry: NotesBrowserEntry) -> String {
        switch entry.kind {
        case .bookmark: "Bookmark"
        case .highlight: "Highlight"
        case .note: entry.isChapterNote ? "Chapter note" : "Note"
        case .thread: "Conversation"
        case .keptVersion: VersionText.orphanMark
        }
    }

    static func versionsText(_ entry: NotesBrowserEntry) -> String? {
        switch entry.kind {
        case .note: entry.versionCount > 1 ? VersionText.mark(count: entry.versionCount) : nil
        case .keptVersion: VersionText.orphanMark
        case .highlight, .bookmark, .thread: nil
        }
    }
}
