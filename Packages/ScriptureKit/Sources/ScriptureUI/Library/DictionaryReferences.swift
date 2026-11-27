import ScriptureData

/// The verse references in an entry of Easton's Bible Dictionary (Matt, 2026-11-24: "none of them are linked"), each a
/// range of the entry's characters and the passage it opens. Found once per entry and translation; never stored.
///
/// A citation is a book as Easton writes it ("Gen.", "1 Chr.", "Judge.", "Ge"; a book's name, short name or alias, as
/// ⌘K takes it, exactly) and a chapter, then a chain: ";" keeps the book ("Jer. 37:13; 38:7"), "," the chapter ("Num.
/// 1:36, 37"); a hyphen or an en dash makes a range ("31-39"). A chapter alone ("Gen. 35") opens the chapter; a range
/// of chapters ("1 Kings 16-22") its first; a range into the next chapter ("8:33-9:6") runs to its chapter's end; a
/// one-chapter book's number is a verse ("Jude 9"). "Comp.", "See" and "cf." are not part of the reference.
///
/// A bare "(20:2)" takes its book from just before it: a prophet's or writer's name with "(" or ", " after it, where
/// the words before the name make it the book's ("called by Jeremiah (20:2)", "the time of Ezekiel (25:9)", "the
/// prophet Isaiah, 19:13"), else the book of the citation before it, unless another book's name stands in the prose
/// between (a "John" between two citations of Matthew). A bare reference in the prose needs a word that leads into
/// it ("recorded in 17:7-13", "ch. 1:5", "Remeth (q.v.), 19:21"). Anything unsure stays plain: a book that is not the Bible's ("Ant." is Josephus), a verse the translation
/// lacks, a bare reference with no book, or one whose chain has a verse its book lacks (the book was a guess).
/// "Heb. goral" is Hebrew, not Hebrews: a book needs a number after it. A number with no book before it (a year, "26
/// miles") is never a reference.
enum DictionaryReferences {
    /// A linked reference: `range` counts the entry's characters.
    struct Link: Equatable, Sendable {
        let range: Range<Int>
        let reference: Reference
    }

    /// Why a reference stays plain.
    enum Plain: Equatable, Sendable {
        /// Its book is not one of the Bible's ("Ant. 8:13").
        case notABook
        /// The translation has no such chapter or verse.
        case notInTheTranslation
        /// A bare "(5:3)" whose book cannot be told with confidence.
        case ambiguous
    }

    struct Unlinked: Equatable, Sendable {
        let range: Range<Int>
        let why: Plain
    }

    struct Scan: Equatable, Sendable {
        var links: [Link] = []
        var unlinked: [Unlinked] = []
    }

    /// The entry's references. `lastVerses` gives a book's last verse of each chapter in the translation being read
    /// (`BibleStore.lastVerses`); it is asked once for each book the entry names.
    /// `subject` is the entry's person or place ("Zechariah"): an entry named for a book speaks of that book, so a
    /// bare reference there takes no other book from the citation before it ("eight visions (1:7-6:8)" after a citation
    /// of Ezra is Zechariah's).
    static func scan(_ entry: String, subject: String? = nil, lastVerses: (Book) -> [Int: Int]) -> Scan {
        withoutActuallyEscaping(lastVerses) { lastVerses in
            var scanner = EntryScanner(entry, subject: subject, lastVerses: lastVerses)
            scanner.run()
            return scanner.scan
        }
    }

    // MARK: - Books

    /// Easton's spellings that are no book's name, short name or alias ("Judge. 20:6", "Exek. 1:1", "2 King 25:1").
    fileprivate static let eastonsSpellings: [String: String] = ["Judge": "JDG", "Exek": "EZK", "2 King": "2KI", "1 King": "1KI"]

    /// A book's name in the prose, and the books it may be: "Samuel" is either of two.
    fileprivate static let proseNames: [String: Set<String>] = {
        var names: [String: Set<String>] = [:]
        for book in BookCatalog.all where book.canon != .apocrypha {
            let words = book.name.split(separator: " ")
            let word = String(words.count == 2 && words[0].allSatisfy(\.isNumber) ? words[1] : words[0])
            guard words.count <= 2 else { continue }
            names[word, default: []].insert(book.id)
        }
        names["Psalm"] = ["PSA"]
        return names
    }()

    /// Prose names that are words before they are books ("the judges", "numbers"): never a bare reference's book.
    fileprivate static let notResolving: Set<String> = ["Numbers", "Judges"]

    /// The word before a name that makes a bare reference after the name the book's ("by Jeremiah (20:2)"); "of" and
    /// "the" only after the words in `headsOf` and `headsThe` ("the words of Malachi", "the Epistle to the Romans").
    fileprivate static let cues: Set<String> = ["by", "prophet", "prophets", "to", "in", "that", "which", "hence", "afterwards",
                                                "while", "and"]
    fileprivate static let headsOf: Set<String> = ["time", "days", "prophecies", "prophecy", "words", "book", "epistle"]
    fileprivate static let headsThe: Set<String> = ["to", "by"]

    /// Words before a reference that are not part of it.
    fileprivate static let prefixes = ["Comp. ", "comp. ", "See ", "see ", "Cf. ", "cf. "]
}

/// One pass over an entry's characters, left to right, keeping the last book cited for the bare references after it.
private struct EntryScanner {
    let text: [Character]
    let lastVerses: (Book) -> [Int: Int]
    var scan = DictionaryReferences.Scan()
    private var known: [String: [Int: Int]] = [:]
    /// Each spelling's book, worked once per entry: David's cites "1 Sam." over a hundred times.
    private let resolved = Spellings()

    private final class Spellings {
        private var books: [String: Book?] = [:]

        func book(_ written: String) -> Book? {
            if let book = books[written] { return book }
            let book = DictionaryReferences.eastonsSpellings[written].flatMap(BookCatalog.book(code:))
                ?? ReferenceParser.parse("\(written) 1", exactBook: true)?.book
            books[written] = book
            return book
        }
    }
    /// The book of the last citation, nil when none or when it was not the Bible's; where that citation ended.
    private var lastBook: Book?
    private var lastEnd = 0
    /// The book the entry is named for ("Zechariah", "John the Apostle"), if any.
    private let subjectBook: Book?
    /// Each book name in the prose, by where it starts.
    private let mentions: [(range: Range<Int>, books: Set<String>)]

    init(_ entry: String, subject: String?, lastVerses: @escaping (Book) -> [Int: Int]) {
        let text = Array(entry)
        self.text = text
        self.lastVerses = lastVerses
        // One byte per character: from the scalars where each character is one (Easton's text), else character by character.
        let scalars = entry.unicodeScalars
        let bytes = scalars.count == text.count ? scalars.map(Self.byte) : text.map(Self.byte)
        self.bytes = bytes
        let word = subject?.split(separator: " ").first.map(String.init)
        subjectBook = word.flatMap { word in BookCatalog.all.first { $0.canon != .apocrypha && $0.name == word } }
        var mentions: [(range: Range<Int>, books: Set<String>)] = []
        var index = 0
        while index < bytes.count {
            guard Self.isUpper(bytes[index]), index == 0 || !Self.isLetter(bytes[index - 1]) else { index += 1; continue }
            var end = index + 1
            while end < bytes.count, Self.isLetter(bytes[end]) { end += 1 }
            if let books = DictionaryReferences.proseNames[String(decoding: bytes[index..<end], as: UTF8.self)] { mentions.append((index..<end, books)) }
            index = end
        }
        self.mentions = mentions
    }

    // MARK: Characters as bytes

    /// Each character as one byte, so the pass never asks a `Character` for its Unicode properties (David's entry,
    /// 18,900 characters, took 13 ms in a debug build that way): itself when ASCII, "-" for an en dash, `letter` for
    /// any other letter ("é"), `other` for anything else ("’", "“").
    private let bytes: [UInt8]
    private static let letter: UInt8 = 0x81, other: UInt8 = 0x80

    private static func byte(_ scalar: Unicode.Scalar) -> UInt8 {
        if scalar.isASCII { return UInt8(scalar.value) }
        if scalar == "\u{2013}" { return UInt8(ascii: "-") }
        return scalar.properties.isAlphabetic ? letter : other
    }

    private static func byte(_ character: Character) -> UInt8 {
        character.unicodeScalars.count == 1 ? byte(character.unicodeScalars.first ?? " ") : character.isLetter ? letter : other
    }

    // Plain comparisons: a range's `contains` is not specialised in a debug build and cost most of the pass.
    private static func isUpper(_ byte: UInt8) -> Bool { byte >= 65 && byte <= 90 }
    private static func isLower(_ byte: UInt8) -> Bool { byte >= 97 && byte <= 122 }
    private static func isDigit(_ byte: UInt8) -> Bool { byte >= 48 && byte <= 57 }
    private static func isLetter(_ byte: UInt8) -> Bool { isUpper(byte) || isLower(byte) || byte == letter }

    private var count: Int { bytes.count }

    /// The byte at `index`; 0 outside the text.
    private func byte(_ index: Int) -> UInt8 {
        index >= 0 && index < count ? bytes[index] : 0
    }

    private func at(_ index: Int, _ character: Unicode.Scalar) -> Bool {
        byte(index) == UInt8(character.value)
    }

    private func isUpper(_ index: Int) -> Bool { Self.isUpper(byte(index)) }
    private func isLower(_ index: Int) -> Bool { Self.isLower(byte(index)) }
    private func isLetter(_ index: Int) -> Bool { Self.isLetter(byte(index)) }

    private func isDigit(_ index: Int) -> Bool {
        Self.isDigit(byte(index))
    }

    /// Whether `string` (ASCII) is at `index`.
    private func matches(_ string: String, at index: Int) -> Bool {
        let utf8 = string.utf8
        guard index >= 0, index + utf8.count <= count else { return false }
        return zip(bytes[index...], utf8).allSatisfy { $0 == $1 }
    }

    // MARK: The pass

    mutating func run() {
        var index = 0
        while index < count {
            // Only a capital or a digit starts a book or a number.
            let first = bytes[index]
            guard Self.isUpper(first) || Self.isDigit(first) else {
                index += 1
                continue
            }
            if index == 0 || !(isLetter(index - 1) || isDigit(index - 1)), let form = bookForm(at: index) {
                if let book = form.book {
                    let end = chain(book, from: form.numberStart, linkStart: index, chapterAlone: form.allowsChapterAlone, bare: false).end
                    if end > form.numberStart {
                        (lastBook, lastEnd) = (book, end)
                        index = end
                        continue
                    }
                } else if !DictionaryReferences.prefixes.contains(where: { $0.hasPrefix(form.word) }),
                          let piece = piece(at: form.numberStart), piece.verse != nil {
                    // "Ant. 8:13": a book that is not the Bible's; a bare reference after it cannot take the book before it.
                    scan.unlinked.append(.init(range: form.numberStart..<piece.end, why: .notABook))
                    (lastBook, lastEnd) = (nil, piece.end)
                    index = piece.end
                    continue
                }
            }
            if isDigit(index), !isDigit(index - 1), index == 0 || !at(index - 1, ":"), let piece = piece(at: index), piece.verse != nil {
                if let book = bareBook(at: index) {
                    let found = chain(book, from: index, linkStart: index, chapterAlone: false, bare: true)
                    // A guessed book is not the book before the next bare reference.
                    (lastBook, lastEnd) = (found.guessed ? nil : book, found.end)
                    index = max(found.end, piece.end)
                } else {
                    scan.unlinked.append(.init(range: index..<piece.end, why: .ambiguous))
                    index = piece.end
                }
                continue
            }
            index += 1
        }
    }

    // MARK: Books

    struct BookForm {
        /// The book's word as written, without its number or period ("Chr", "Ant").
        let word: String
        let book: Book?
        let numberStart: Int
        let allowsChapterAlone: Bool
    }

    /// A book as Easton writes it at `index`, then spaces and a number: "1 Chr. 8", "Jer. 37", "Ge 10", "Ant. 8".
    /// `book` is nil for a word that is no book's. A word of two letters with no period ("Ge") needs a verse after
    /// it; a chapter alone needs a period, a book's number or the book's whole name ("Gen. 35", "Acts 26").
    private func bookForm(at index: Int) -> BookForm? {
        var cursor = index
        var numbered = false
        if byte(cursor) >= 49 && byte(cursor) <= 51, !isDigit(cursor + 1) {
            cursor += 1
            if cursor < count, at(cursor, " ") { cursor += 1 }
            numbered = true
        }
        guard cursor < count, isUpper(cursor) else { return nil }
        let wordStart = cursor
        cursor += 1
        while cursor < count, isLower(cursor) { cursor += 1 }
        let wordEnd = cursor
        guard wordEnd - wordStart >= 2 else { return nil }
        let dotted = cursor < count && at(cursor, ".")
        if dotted { cursor += 1 }
        guard cursor < count, at(cursor, " ") else { return nil }
        while cursor < count, at(cursor, " ") { cursor += 1 }
        guard isDigit(cursor) else { return nil }

        let written = String(text[index..<wordEnd])
        let word = String(text[wordStart..<wordEnd])
        let book = resolved.book(written)
        guard let book else { return BookForm(word: word, book: nil, numberStart: cursor, allowsChapterAlone: false) }
        if !dotted, !numbered, wordEnd - wordStart <= 2 {
            // "Ge 10:10", never "Is 5" or "He 12".
            guard piece(at: cursor)?.verse != nil else { return nil }
        }
        return BookForm(word: word, book: book, numberStart: cursor, allowsChapterAlone: dotted || numbered || written == book.name)
    }

    private mutating func chapters(of book: Book) -> [Int: Int] {
        if let last = known[book.id] { return last }
        let last = lastVerses(book)
        known[book.id] = last
        return last
    }

    // MARK: Pieces

    /// "37:13", "1:24-26", "8:33-9:6", "35", "16-22" (the second number a chapter's or a verse's, as the chain reads it).
    struct Piece {
        var end: Int
        var first: Int
        var verse: Int?
        var through: Int?
        /// A range's last chapter, when it runs into another ("8:33-9:6").
        var throughChapter: Int?
    }

    /// A number of at most three digits at `index`; a fourth digit makes it a year.
    private func number(at index: Int) -> (value: Int, end: Int)? {
        guard isDigit(index), !isDigit(index - 1) else { return nil }
        var end = index
        while isDigit(end) { end += 1 }
        guard end - index <= 3 else { return nil }
        let value = bytes[index..<end].reduce(0) { $0 * 10 + Int($1 - 48) }
        guard value >= 1 else { return nil }
        return (value, end)
    }

    private func isDash(_ index: Int) -> Bool {
        at(index, "-")
    }

    private func piece(at index: Int) -> Piece? {
        guard let first = number(at: index) else { return nil }
        var piece = Piece(end: first.end, first: first.value)
        if first.end < count, at(first.end, ":") {
            // "Jer. 43: 8-13", Easton's space after the colon, too.
            let verseStart = first.end + 1 < count && at(first.end + 1, " ") ? first.end + 2 : first.end + 1
            guard let verse = number(at: verseStart) else { return nil }
            piece.verse = verse.value
            piece.end = verse.end
            if isDash(verse.end), let through = number(at: verse.end + 1) {
                if through.end < count, at(through.end, ":"), let last = number(at: through.end + 1) {
                    piece.throughChapter = through.value
                    piece.through = last.value
                    piece.end = last.end
                } else {
                    piece.through = through.value
                    piece.end = through.end
                }
            }
        } else if isDash(first.end), let through = number(at: first.end + 1), !(through.end < count && at(through.end, ":")) {
            piece.through = through.value
            piece.end = through.end
        }
        if piece.end < count, isLetter(piece.end) || at(piece.end, ":") { return nil }
        return piece
    }

    /// A number standing for a verse or chapter alone ends at a citation's punctuation or " and" before another:
    /// "37;", "9)", "Neh. 8 and 12:26", never "2 miles".
    private func endsCleanly(_ index: Int) -> Bool {
        index >= count || ")];,.\n".utf8.contains(byte(index))
            || (matches(" and ", at: index) && isDigit(index + 5))
    }

    // MARK: Chains

    /// The citation from `start` as far as its chain runs, each piece linked or left plain; returns where it ended,
    /// `start` when nothing there was a reference. A bare chain with a verse its book lacks is plain throughout: `guessed`.
    private mutating func chain(_ book: Book, from start: Int, linkStart: Int, chapterAlone: Bool, bare: Bool) -> (end: Int, guessed: Bool) {
        let chapters = chapters(of: book)
        let oneChapter = chapters.count == 1 && chapters[1] != nil
        var found: [(range: Range<Int>, reference: Reference?)] = []
        var index = start
        var rangeStart = linkStart
        var chapter: Int?
        var afterComma = false
        var end = start
        while let piece = piece(at: index) {
            var reference: Reference?
            if let verse = piece.verse {
                chapter = piece.first
                reference = Self.reference(book, chapter: piece.first, verse: verse, through: piece.through,
                                           throughChapter: piece.throughChapter, chapters: chapters)
            } else {
                guard endsCleanly(piece.end) else { break }
                if oneChapter {
                    // "Jude 9".
                    chapter = 1
                    reference = Self.reference(book, chapter: 1, verse: piece.first, through: piece.through, throughChapter: nil, chapters: chapters)
                } else if afterComma, let current = chapter {
                    reference = Self.reference(book, chapter: current, verse: piece.first, through: piece.through, throughChapter: nil, chapters: chapters)
                } else {
                    guard chapterAlone || !found.isEmpty else { break }
                    if chapter != nil {
                        // "Ex. 6:20; comp. 16": a chapter or a verse, so neither.
                        scan.unlinked.append(.init(range: rangeStart..<piece.end, why: .ambiguous))
                        break
                    }
                    reference = chapters[piece.first] == nil ? nil : Reference(book: book, chapter: piece.first)
                }
            }
            found.append((rangeStart..<piece.end, reference))
            end = piece.end
            guard let next = continuation(after: piece.end) else { break }
            afterComma = next.comma
            index = next.index
            rangeStart = next.index
        }
        guard !found.isEmpty else { return (start, false) }
        let guessed = bare && found.contains { $0.reference == nil }
        for piece in found {
            if let reference = piece.reference, !guessed {
                scan.links.append(.init(range: piece.range, reference: reference))
            } else {
                scan.unlinked.append(.init(range: piece.range, why: guessed ? .ambiguous : .notInTheTranslation))
            }
        }
        return (end, guessed)
    }

    /// Where a chain goes on after `index`: ", 37", "; 38:7", "; comp. 6:2", " and 15:7"; nil at a new book (the pass
    /// starts it again) or anything else.
    private func continuation(after index: Int) -> (index: Int, comma: Bool)? {
        guard index < count else { return nil }
        var cursor = index
        let comma: Bool
        if at(cursor, ",") || at(cursor, ";") {
            comma = at(cursor, ",")
            cursor += 1
            // "Josh. 9;17" is Easton's slip for 9:17: a chapter alone follows a semicolon only after a space.
            if !comma, isDigit(cursor), piece(at: cursor)?.verse == nil { return nil }
            while cursor < count, at(cursor, " ") { cursor += 1 }
            if !comma, let after = prefix(at: cursor) { cursor = after }
        } else if matches(" and ", at: cursor) {
            comma = false
            cursor += 5
            guard piece(at: cursor)?.verse != nil else { return nil }
        } else {
            return nil
        }
        guard isDigit(cursor), bookForm(at: cursor) == nil else { return nil }
        return (cursor, comma)
    }

    /// Past "Comp. " or "See " at `index`.
    private func prefix(at index: Int) -> Int? {
        DictionaryReferences.prefixes.first { matches($0, at: index) }.map { index + $0.count }
    }

    private static func reference(_ book: Book, chapter: Int, verse: Int, through: Int?, throughChapter: Int?,
                                  chapters: [Int: Int]) -> Reference? {
        guard let last = chapters[chapter], verse <= last else { return nil }
        var end = throughChapter.map { $0 > chapter ? last : verse } ?? through.map { min($0, last) }
        if let through = end, through <= verse { end = nil }
        return Reference(book: book, chapter: chapter, verse: verse, endVerse: end)
    }

    // MARK: Bare references

    /// The book of a bare "C:V" at `index`, nil when it cannot be told:
    /// - right after "(" (or "(comp. "): the book named just before the "(" (`named(before:)`), else the book before;
    /// - right after a book's name and a comma ("the prophet Isaiah, 19:13"): that book, on the same cue;
    /// - in the prose after "in", "at", "of", "and", "like", "ch." or "(q.v.)" ("recorded in 17:7-13"): the book before.
    /// Anywhere else ("13. Comp. 13:8") it is not told.
    private func bareBook(at index: Int) -> Book? {
        var cursor = previous(index)
        guard cursor >= 0 else { return nil }
        if !at(cursor, "("), let prefix = prefix(endingAt: cursor), previous(prefix) >= 0, at(previous(prefix), "(") {
            cursor = previous(prefix)
        }
        if at(cursor, "(") { return named(before: cursor) ?? bookBefore(cursor) }
        if at(cursor, ","), let book = named(before: cursor) { return book }
        return isProseCue(at: cursor) ? bookBefore(cursor) : nil
    }

    /// The last non-space before `index`; -1 at the start.
    private func previous(_ index: Int) -> Int {
        var cursor = index - 1
        while cursor >= 0, at(cursor, " ") { cursor -= 1 }
        return cursor
    }

    /// Where "Comp. " or "See " starts when it ends at `index` (its period or last letter).
    private func prefix(endingAt index: Int) -> Int? {
        DictionaryReferences.prefixes.lazy.compactMap { prefix -> Int? in
            let start = index + 2 - prefix.count
            return start >= 0 && matches(prefix, at: start) ? start : nil
        }.first
    }

    /// The book whose name ends just before `end` (spaces between), where the words before the name make it the
    /// book's (`isCue`): "by Jeremiah", "the time of Ezekiel", "the Acts of the Apostles". "John" is the Gospel;
    /// "Samuel" no book of its own; "Numbers" and "Judges" are words first.
    private func named(before end: Int) -> Book? {
        let acts = "Acts of the Apostles"
        if matches(acts, at: previous(end) + 1 - acts.utf8.count) { return BookCatalog.book(code: "ACT") }
        guard let named = mentions.last(where: { $0.range.upperBound <= end }),
              (named.range.upperBound..<end).allSatisfy({ at($0, " ") }) else { return nil }
        let word = String(text[named.range])
        guard !DictionaryReferences.notResolving.contains(word), isCue(before: named.range.lowerBound) else { return nil }
        return BookCatalog.all.first { $0.name == word || (word == "Psalm" && $0.id == "PSA") }
    }

    /// The last cited book, unless another book is named in the prose between its citation and `end`, or the entry
    /// is named for another book.
    private func bookBefore(_ end: Int) -> Book? {
        guard let lastBook, subjectBook.map({ $0 == lastBook }) ?? true else { return nil }
        let between = mentions.filter { $0.range.lowerBound >= lastEnd && $0.range.upperBound <= end }
        return between.allSatisfy { $0.books.contains(lastBook.id) } ? lastBook : nil
    }

    /// Whether the text ending at `index` leads into a bare reference in the prose: "in", "at", "of", "and",
    /// "like", "ch.", "chap.", "(q.v.)" or "(q.v.),".
    private func isProseCue(at index: Int) -> Bool {
        var cursor = index
        if at(cursor, ",") { cursor = previous(cursor) }
        guard cursor >= 0 else { return false }
        if at(cursor, ")") { return cursor >= 4 && matches("q.v.", at: cursor - 4) }
        var dotted = false
        if at(cursor, ".") { (dotted, cursor) = (true, cursor - 1) }
        var start = cursor
        while start >= 0, isLetter(start) { start -= 1 }
        guard start < cursor, start < 0 || !isLetter(start) else { return false }
        let word = String(text[(start + 1)...cursor]).lowercased()
        return dotted ? ["ch", "chap"].contains(word) : ["in", "at", "of", "and", "like"].contains(word)
    }

    /// Whether the words before a name at `index` make it a book's ("by", "the time of"), or it opens a sentence or clause.
    private func isCue(before index: Int) -> Bool {
        var cursor = index - 1
        while cursor >= 0, at(cursor, " ") { cursor -= 1 }
        guard cursor >= 0, !at(cursor, "\n"), !".,;:".utf8.contains(byte(cursor)) else { return true }
        func word(endingAt end: Int) -> (word: String, start: Int)? {
            var start = end
            while start >= 0, isLetter(start) { start -= 1 }
            guard start < end else { return nil }
            return (String(text[(start + 1)...end]).lowercased(), start)
        }
        guard let before = word(endingAt: cursor) else { return false }
        if DictionaryReferences.cues.contains(before.word) { return true }
        guard before.word == "of" || before.word == "the" else { return false }
        var earlier = before.start
        while earlier >= 0, at(earlier, " ") { earlier -= 1 }
        guard let head = word(endingAt: earlier)?.word else { return false }
        return before.word == "of" ? DictionaryReferences.headsOf.contains(head) : DictionaryReferences.headsThe.contains(head)
    }
}
