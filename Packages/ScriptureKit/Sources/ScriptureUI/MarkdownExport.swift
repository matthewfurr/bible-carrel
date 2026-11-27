import Foundation
import ScriptureData
import ScriptureModel

/// Renders the reader's notes, highlights, bookmarks and conversations as Markdown: one file, or
/// a folder with a README and one file per book. Pure: the verse text and the conversations come
/// through `Context`, so the stores stay out of it (`NotesExporter` feeds it from them).
public enum MarkdownExport {
    public enum Layout: String, CaseIterable, Sendable {
        case singleFile
        case folderPerBook
    }

    public struct Options: Equatable, Sendable {
        public var layout: Layout
        public var includesConversations: Bool

        public init(layout: Layout = .singleFile, includesConversations: Bool = true) {
            self.layout = layout
            self.includesConversations = includesConversations
        }
    }

    public struct File: Equatable, Sendable {
        /// Within the export: the dated file name, or `README.md` and `<Book name>.md` in the folder.
        public let relativePath: String
        public let text: String

        public init(relativePath: String, text: String) {
            self.relativePath = relativePath
            self.text = text
        }
    }

    public struct Output: Equatable, Sendable {
        /// `Reading Through Scripture Notes 2026-11-01`, with `.md` for a single file; the folder's name otherwise.
        public let name: String
        public let files: [File]

        public init(name: String, files: [File]) {
            self.name = name
            self.files = files
        }
    }

    public struct Context {
        /// A verse's text in a translation, or nil when the translation lacks it.
        public var verseText: (VerseLocation, String) -> String?
        public var thread: (UUID) -> ThreadSnapshot?
        /// Bookmarks quote their verse in this translation.
        public var currentTranslationID: String
        public var exportedAt: Date

        public init(verseText: @escaping (VerseLocation, String) -> String?, thread: @escaping (UUID) -> ThreadSnapshot?, currentTranslationID: String, exportedAt: Date) {
            self.verseText = verseText
            self.thread = thread
            self.currentTranslationID = currentTranslationID
            self.exportedAt = exportedAt
        }
    }

    static let title = "Bible Carrel: Notes"
    static let baseName = "Bible Carrel Notes"

    /// Canon order, then chapter, verse and date, whatever the browser's sort. A kept version with
    /// no note is skipped: it lists only under the Notes browser's Kept versions.
    public static func render(entries: [NotesBrowserEntry], options: Options, context: Context) -> Output {
        let included = entries.filter { !$0.isKeptVersion && (options.includesConversations || !$0.isThread) }
        let books = groups(of: sorted(included), by: \.book)
        let name = "\(baseName) \(isoDate(context.exportedAt))"

        switch options.layout {
        case .singleFile:
            let blocks = ["# \(title)", exportedLine(count: included.count, context: context)]
                + books.flatMap { book in ["## \(bookName(book[0].book))"] + chapterBlocks(book, context: context) }
            let fileName = "\(name).md"
            return Output(name: fileName, files: [File(relativePath: fileName, text: document(blocks))])
        case .folderPerBook:
            let readme = File(relativePath: "README.md", text: document(["# \(title)", exportedLine(count: included.count, context: context)]))
            let bookFiles = books.map { book in
                let name = bookName(book[0].book)
                let blocks = ["# \(name)", exportedLine(count: book.count, context: context)] + chapterBlocks(book, context: context)
                return File(relativePath: "\(name).md", text: document(blocks))
            }
            return Output(name: name, files: [readme] + bookFiles)
        }
    }

    // MARK: - Blocks

    private static func chapterBlocks(_ book: [NotesBrowserEntry], context: Context) -> [String] {
        groups(of: book, by: \.chapter).flatMap { chapter in
            let entry = chapter[0]
            let heading = "### \(MarkupReferenceText.string(book: entry.book, chapter: entry.chapter, verse: nil, endVerse: nil))"
            return [heading] + chapter.flatMap { blocks(for: $0, context: context) }
        }
    }

    private static func blocks(for entry: NotesBrowserEntry, context: Context) -> [String] {
        let date = formatted(entry.modifiedAt)
        switch entry.kind {
        case .note:
            if entry.isChapterNote {
                return ["**Chapter note**", body(entry.body), meta("Note", date: date)]
            }
            return [quote(entry.quotedText, of: entry, translationID: entry.translationID ?? context.currentTranslationID),
                    body(entry.body), meta("Note", color: entry.colorName, date: date)]
        case .highlight:
            return [quote(entry.quotedText, of: entry, translationID: entry.translationID ?? context.currentTranslationID),
                    meta("Highlight", color: entry.colorName, date: date)]
        case .bookmark:
            let translationID = context.currentTranslationID
            let location = VerseLocation(book: entry.book, chapter: entry.chapter, verse: entry.verse)
            let line = context.verseText(location, translationID).map { quote($0, of: entry, translationID: translationID) }
                ?? "> \(entry.referenceString) (text not available in \(translationID))"
            return [line, meta("Bookmark", date: date)]
        case .thread(let id):
            let turns = context.thread(id)?.messages.map(turn) ?? []
            return ["#### \(entry.body)"] + turns + [meta("Conversation", date: date)]
        case .keptVersion:
            return []
        }
    }

    /// The citation `MarkupModel.copyWithReference` copies, as a blockquote (every line quoted).
    private static func quote(_ text: String, of entry: NotesBrowserEntry, translationID: String) -> String {
        let selection = TextSelection(book: entry.book, chapter: entry.chapter, verse: entry.verse, endVerse: entry.endVerse, startOffset: 0, endOffset: 0, quotedText: text)
        return selection.copyWithReference(translationID: translationID)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? ">" : "> \($0)" }
            .joined(separator: "\n")
    }

    private static func turn(_ message: MessageSnapshot) -> String {
        switch message.role {
        case .user:
            return spoken(by: "You", body(message.displayText ?? message.content))
        case .assistant:
            let label = ProviderLabel.text(providerID: message.providerID, modelName: message.modelName, host: message.providerHost)
            // A reply that ended early says why, in the panel's footer words.
            let reason = message.finishReason.flatMap(ChatFinishReason.init(rawValue:))?.footerText
            let detail = [label.isEmpty ? nil : label, reason].compactMap { $0 }.joined(separator: ", ")
            return spoken(by: detail.isEmpty ? "Assistant" : "Assistant (\(detail))", body(message.content))
        }
    }

    /// The speaker's label, then the text inline; a text that opens with a Markdown block (a heading,
    /// a list, a quote, a code fence) starts after a blank line instead, so the block still parses.
    private static func spoken(by speaker: String, _ text: String) -> String {
        opensWithBlock(text) ? "**\(speaker):**\n\n\(text)" : "**\(speaker):** \(text)"
    }

    /// `#` to `######`, `-` `*` `+`, or `1.` `1)` followed by a space (or the line's end); a code fence; `>`.
    private static func opensWithBlock(_ text: String) -> Bool {
        let line = text.prefix { $0 != "\n" }
        func endsMarker(_ length: Int) -> Bool {
            let next = line.dropFirst(length).first
            return next == nil || next == " " || next == "\t"
        }
        if line.hasPrefix(">") || line.hasPrefix("```") || line.hasPrefix("~~~") { return true }
        let hashes = line.prefix { $0 == "#" }.count
        if hashes > 0 { return hashes <= 6 && endsMarker(hashes) }
        if let first = line.first, "-*+".contains(first) { return endsMarker(1) }
        let digits = line.prefix { $0.isASCII && $0.isNumber }.count
        if digits > 0, digits <= 9, let mark = line.dropFirst(digits).first, mark == "." || mark == ")" {
            return endsMarker(digits + 1)
        }
        return false
    }

    private static func meta(_ kind: String, color: String? = nil, date: String) -> String {
        "_\(([kind, color, date] as [String?]).compactMap { $0 }.joined(separator: " · "))_"
    }

    private static func exportedLine(count: Int, context: Context) -> String {
        "_Exported \(formatted(context.exportedAt)) · \(count) \(count == 1 ? "item" : "items")_"
    }

    /// As written, without the blank lines a body may end with.
    private static func body(_ text: String) -> String {
        text.trimmingCharacters(in: .newlines)
    }

    /// One blank line between blocks; an empty block (a note with no body yet) is left out.
    private static func document(_ blocks: [String]) -> String {
        blocks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n\n") + "\n"
    }

    // MARK: - Ordering

    private static func sorted(_ entries: [NotesBrowserEntry]) -> [NotesBrowserEntry] {
        entries.sorted {
            ($0.bookOrder, $0.book, $0.chapter, $0.verse, $0.modifiedAt, $0.id.uuidString)
                < ($1.bookOrder, $1.book, $1.chapter, $1.verse, $1.modifiedAt, $1.id.uuidString)
        }
    }

    /// Runs of consecutive entries sharing a key, in order.
    private static func groups<Key: Equatable>(of entries: [NotesBrowserEntry], by key: (NotesBrowserEntry) -> Key) -> [[NotesBrowserEntry]] {
        var groups: [[NotesBrowserEntry]] = []
        for entry in entries {
            if let last = groups.last?.first, key(last) == key(entry) {
                groups[groups.count - 1].append(entry)
            } else {
                groups.append([entry])
            }
        }
        return groups
    }

    // MARK: - Names and dates

    private static func bookName(_ code: String) -> String {
        BookCatalog.book(code: code)?.name ?? code
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted))
    }

    /// `2026-11-01`, in the reader's time zone.
    private static func isoDate(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }
}

private extension NotesBrowserEntry {
    var isThread: Bool {
        if case .thread = kind { return true }
        return false
    }

    var isKeptVersion: Bool {
        if case .keptVersion = kind { return true }
        return false
    }
}
