import Foundation
import ScriptureData

/// One verse's cross-references, in the translation being read: the rows of the Cross-References panel,
/// in its two groups.
public struct CrossReferences: Equatable, Sendable {
    public struct Row: Identifiable, Hashable, Sendable {
        /// One chapter: a link out's target, cut to its first chapter's part when it runs on
        /// (to `chapterEnd`; the single verse without one, or when the chapter ends before it); a link in's source.
        public let reference: Reference
        public let opening: String?
        /// Orders the lists; never shown.
        public let votes: Int

        init(pointingTo link: CrossReference) {
            let target = link.target
            let sameChapter = link.targetEnd.book == target.book && link.targetEnd.chapter == target.chapter
            // A range inside its chapter keeps its end; one that runs on keeps the part in its first chapter.
            let end = sameChapter ? link.targetEnd.verse : link.chapterEnd
            reference = Reference(book: Self.book(target.book), chapter: target.chapter, verse: target.verse,
                                  endVerse: end.flatMap { $0 > target.verse ? $0 : nil })
            opening = Self.line(link.openingText)
            votes = link.votes
        }

        init(pointingHere link: CrossReference) {
            let source = link.source
            reference = Reference(book: Self.book(source.book), chapter: source.chapter, verse: source.verse)
            opening = Self.line(link.openingText)
            votes = link.votes
        }

        public var id: String { "\(reference.displayString) \(votes)" }
        public var canOpen: Bool { opening != nil }

        /// "Psalm 1:1, Blessed is the man…"; the reference alone without words.
        public var accessibilityLabel: String {
            opening.map { "\(reference.displayString), \($0)" } ?? reference.displayString
        }

        /// A `VerseKey` only names books the catalog holds.
        private static func book(_ code: String) -> Book { BookCatalog.book(code: code)! }

        /// The opening text as one line: a poem's lines joined by a space.
        private static func line(_ text: String?) -> String? {
            guard let text else { return nil }
            let line = joined(text)
            return line.isEmpty ? nil : line
        }

        static func joined(_ text: String) -> String {
            text.split(separator: "\n", omittingEmptySubsequences: true).joined(separator: " ")
        }
    }

    public struct Group: Equatable, Sendable {
        /// Every link kept, strongest first.
        public let all: [Row]
        /// The first six of those with at least four votes (OpenBible's own default cut-off).
        public var short: [Row] { Array(all.filter { $0.votes >= Self.minimumVotes }.prefix(Self.shortLimit)) }
        public var count: Int { all.count }
        /// `all` holds more than `short`.
        public var showsShowAll: Bool { all.count > short.count }
        public var showAllTitle: String { "Show all (\(count))" }

        static let minimumVotes = 4, shortLimit = 6
    }

    public static let pointsToTitle = "This verse points to", pointsHereTitle = "Verses that point here"
    public static let emptyLine = "No cross-references for this verse."
    /// The reader's turn in the conversation Ask About These opens, as a prompt's title is.
    public static let askTitle = "Explain these cross-references"
    /// The panel's foot credits the data's source (spec 5.4).
    public static let credit = "Cross-references: OpenBible.info"
    public static let creditLink = URL(string: "https://www.openbible.info/labs/cross-references/")!

    public let verse: VerseLocation
    public let translationID: String
    public let reference: Reference
    public let pointsTo: Group, pointsHere: Group
    /// The verse rows before and after this one in its chapter, in the translation being read; nil at its ends.
    public let previous: VerseLocation?, next: VerseLocation?
    /// The verse in the translation being read, whole, as the reader reports a selection of it; nil when the translation lacks it.
    public let selection: TextSelection?

    /// Ask About These has something to send: the verse's words and a passage in a short list.
    public var canAsk: Bool { selection != nil && !(pointsTo.short.isEmpty && pointsHere.short.isEmpty) }

    /// Neither group has a link.
    public var isEmpty: Bool { pointsTo.all.isEmpty && pointsHere.all.isEmpty }

    public static func load(_ verse: VerseLocation, translationID: String, store: BibleStore) throws -> CrossReferences {
        let out = try store.crossReferences(from: verse, translationID: translationID)
        let into = try store.crossReferences(to: verse, translationID: translationID)
        let rows = try store.chapter((book: verse.book, chapter: verse.chapter), translationID: translationID)
        // A combined row ("12-13") holds each verse in it; its neighbors are the rows around it.
        let before = rows.last { ($0.endVerse ?? $0.id.verse) < verse.verse }
        let after = rows.first { $0.id.verse > verse.verse }
        return CrossReferences(
            verse: verse, translationID: translationID,
            reference: Reference(book: BookCatalog.book(code: verse.book)!, chapter: verse.chapter, verse: verse.verse),
            pointsTo: Group(all: out.map(Row.init(pointingTo:))),
            pointsHere: Group(all: into.map(Row.init(pointingHere:))),
            previous: before?.id, next: after?.id,
            selection: rows.first { $0.id.verse <= verse.verse && ($0.endVerse ?? $0.id.verse) >= verse.verse }.map { row in
                let whole = SelectionResolver.wholeVerseOffsets(first: row.text, last: row.text)
                return TextSelection(book: verse.book, chapter: verse.chapter, verse: row.id.verse, endVerse: row.endVerse ?? row.id.verse,
                                     startOffset: whole.start, endOffset: whole.end, quotedText: Row.joined(row.text))
            })
    }

    // MARK: - Ask About These

    /// The question the assistant is sent: the verse, then the passages of the two short lists with
    /// their words (a row without words is its reference alone), then the request. A group with an
    /// empty short list is left out with its heading.
    public func question(store: BibleStore) throws -> String {
        var blocks = ["Here is \(reference.displayString) (\(translationID)):\n\n\(selection?.quotedText ?? "")"]
        for (title, group) in [(Self.pointsToTitle, pointsTo), (Self.pointsHereTitle, pointsHere)] where !group.short.isEmpty {
            let lines = try group.short.map { row in
                try Self.passageText(row.reference, translationID: translationID, store: store)
                    .map { "\(row.reference.displayString) \u{2014} \($0)" } ?? row.reference.displayString
            }
            blocks.append("\(title):\n\n" + lines.joined(separator: "\n"))
        }
        blocks.append(Self.request(for: reference.displayString))
        return blocks.joined(separator: "\n\n")
    }

    public static func request(for reference: String) -> String {
        "Explain how each of these cross-references relates to \(reference): what the passages share, and what reading them together shows. Keep to what the passages say."
    }

    /// The passage's verses in `translationID`, each with its number, poetry lines joined, the verses
    /// joined by a space; nil when the translation has none of them.
    static func passageText(_ reference: Reference, translationID: String, store: BibleStore) throws -> String? {
        guard let preview = try VersePreview.load(reference, translationID: translationID, store: store) else { return nil }
        return preview.verses.map { verse in
            let number = verse.endVerse.map { "\(verse.id.verse)-\($0)" } ?? "\(verse.id.verse)"
            return "\(number) \(Row.joined(verse.text))"
        }.joined(separator: " ")
    }
}
