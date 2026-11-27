import Foundation
import ScriptureData

/// Finds Scripture references in an assistant's reply ("John 15:4", "1 John 2:6", "Ps 91:1",
/// "John 15:4–5", and a bare "5:3" when the conversation is about a book) and makes each a
/// `scripture://` link that the panel answers by showing the verse.
///
/// A candidate is any `chapter:verse`, with an optional `-verse` or `–verse` range. The book is
/// the longest run of words before it that `ReferenceParser` accepts, starting with a capital or
/// a number, so "In John 1:32" finds John. Times and ratios are not verses: a candidate preceded
/// by a digit or a colon, followed by a digit or by a colon and a digit ("12:3:4"), or (bare)
/// followed by am or pm is dropped, as is a chapter past the book's last. A colon that introduces
/// a quotation ("John 3:16: For God") keeps the link. In a reply a chapter alone ("John 15") is
/// never linked.
///
/// Notes link more (spec 3.2; Matt, 2026-11-12: "anyone can type in a reference that should be
/// clickable"): a book's name in any case ("gen 1:1", "GEN 1:1"), though a lower-case word of one
/// or two letters is a word, not a book ("this is 5:3" is not Isaiah); a bare "5:3" in the note's
/// own book; and a chapter alone behind a capital ("Romans 8", "ROM 8"), never behind a lower-case
/// word, so "mark 2 items" stays prose. Links are found when the note is shown, never stored.
public enum ReferenceLinker {
    public static let scheme = "scripture"

    /// Which text is being linked: an assistant's reply, or a note someone typed.
    public enum Rules: Sendable {
        case reply, note
    }

    /// How many words before a `chapter:verse` can name its book ("Song of Solomon" is three).
    private static let maxBookWords = 4

    public static func references(in text: String, contextBook: Book?, rules: Rules = .reply, chapterCount: (String) -> Int?)
        -> [(range: Range<String.Index>, reference: Reference)] {
        var found: [(range: Range<String.Index>, reference: Reference)] = []
        for match in text.matches(of: /(\d+):(\d+)(?:[\-\u{2013}](\d+))?/) {
            let numbers = match.range
            if let before = text[..<numbers.lowerBound].last, before.isNumber || before == ":" { continue }
            let following = text[numbers.upperBound...].prefix(2)
            if let after = following.first, after.isNumber { continue }
            if following.first == ":", following.dropFirst().first?.isNumber == true { continue }
            guard let chapter = Int(match.output.1), let verse = Int(match.output.2) else { continue }

            var resolved: (range: Range<String.Index>, reference: Reference)?
            for start in bookStarts(before: numbers.lowerBound, in: text, rules: rules) {
                if let reference = ReferenceParser.parse("\(text[start..<numbers.lowerBound])\(text[numbers])"),
                   reference.verse != nil {
                    resolved = (start..<numbers.upperBound, reference)
                    break
                }
            }
            if resolved == nil, let contextBook, !isClockTime(after: numbers.upperBound, in: text) {
                let endVerse = match.output.3.flatMap { Int($0) }
                guard chapter >= 1, verse >= 1, endVerse.map({ $0 > verse }) ?? true else { continue }
                resolved = (numbers, Reference(book: contextBook, chapter: chapter, verse: verse, endVerse: endVerse))
            }
            guard let resolved, let resolvedChapter = resolved.reference.chapter else { continue }
            if let count = chapterCount(resolved.reference.book.id), resolvedChapter > count { continue }
            found.append(resolved)
        }
        if rules == .note { found += chapters(in: text, excluding: found.map(\.range), chapterCount: chapterCount) }
        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// A chapter alone behind a capitalised book ("Romans 8", "ROM 8"): a number standing on its
    /// own (not a verse, a range, a decimal or part of a larger number), not inside a reference
    /// already found.
    private static func chapters(in text: String, excluding taken: [Range<String.Index>], chapterCount: (String) -> Int?)
        -> [(range: Range<String.Index>, reference: Reference)] {
        var found: [(range: Range<String.Index>, reference: Reference)] = []
        for match in text.matches(of: /\d+/) {
            let number = match.range
            guard !taken.contains(where: { $0.overlaps(number) }) else { continue }
            if let before = text[..<number.lowerBound].last, before.isNumber || before == ":" { continue }
            let following = text[number.upperBound...].prefix(2)
            if let after = following.first {
                if after.isNumber || after == ":" { continue }
                if [".", "-", "\u{2013}", ","].contains(after), following.dropFirst().first?.isNumber == true { continue }
            }
            guard let chapter = Int(match.output), chapter >= 1 else { continue }
            for start in bookStarts(before: number.lowerBound, in: text, rules: .reply) {
                guard let reference = ReferenceParser.parse("\(text[start..<number.lowerBound])\(chapter)"),
                      reference.chapter == chapter, reference.verse == nil else { continue }
                if let count = chapterCount(reference.book.id), chapter > count { break }
                found.append((start..<number.upperBound, reference))
                break
            }
        }
        return found
    }

    /// `scripture://JHN/15/4-5`, `scripture://1JN/2/6`.
    public static func url(for reference: Reference) -> URL {
        var path = "/\(reference.chapter ?? 1)"
        if let verse = reference.verse {
            path += "/\(verse)"
            if let endVerse = reference.endVerse { path += "-\(endVerse)" }
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = reference.book.id
        components.path = path
        return components.url!
    }

    public static func reference(from url: URL) -> Reference? {
        guard url.scheme?.lowercased() == scheme, let code = url.host(), let book = BookCatalog.book(code: code.uppercased()) else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard (1...2).contains(parts.count), let chapter = Int(parts[0]), chapter >= 1 else { return nil }
        // A chapter alone (a note's "Romans 8").
        guard parts.count == 2 else { return Reference(book: book, chapter: chapter) }
        let verses = parts[1].split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(verses.count), let verse = Int(verses[0]), verse >= 1 else { return nil }
        guard verses.count == 2 else { return Reference(book: book, chapter: chapter, verse: verse) }
        guard let endVerse = Int(verses[1]), endVerse > verse else { return nil }
        return Reference(book: book, chapter: chapter, verse: verse, endVerse: endVerse)
    }

    /// The bare passage links typed in `text` ("bible://jhn.3.16", "bible-dev:rom.8"), each
    /// without the sentence punctuation that follows it (. , ; : ! ? and a closing bracket or quotation mark).
    static func passageLinks(in text: String) -> [(range: Range<String.Index>, reference: Reference)] {
        let trailing: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "\"", "'", "\u{201D}", "\u{2019}", "\u{00BB}"]
        var found: [(range: Range<String.Index>, reference: Reference)] = []
        for match in text.matches(of: /\b(?:bible-dev|bible):[A-Za-z0-9.\-_%=&?#\/]+/.ignoresCase()) {
            var end = match.range.upperBound
            while end > match.range.lowerBound, trailing.contains(text[text.index(before: end)]) { end = text.index(before: end) }
            let range = match.range.lowerBound..<end
            if let link = PassageLink(string: String(text[range])) { found.append((range, link.reference)) }
        }
        return found
    }

    /// Sets `.link` on each reference. Runs that already carry a link or code styling are left alone.
    ///
    /// In a note a passage link ("bible://jhn.3.16", typed or written as a markdown link) is a
    /// reference like any other, linked the same way, so it opens the popover or the passage; one
    /// to a chapter its book lacks is left as text.
    public static func linked(_ text: AttributedString, contextBook: Book?, rules: Rules = .reply, chapterCount: (String) -> Int?) -> AttributedString {
        let plain = String(text.characters)
        var result = text
        if rules == .note {
            func exists(_ reference: Reference) -> Bool {
                guard let chapter = reference.chapter, let count = chapterCount(reference.book.id) else { return true }
                return chapter <= count
            }
            // A markdown link to a passage: swap its URL for the app's own.
            for run in text.runs {
                guard let url = run.link, let passage = PassageLink(url) else { continue }
                result[run.range].link = exists(passage.reference) ? Self.url(for: passage.reference) : nil
            }
            for found in passageLinks(in: plain) where exists(found.reference) {
                let range = attributedRange(of: found.range, in: plain, result)
                let taken = result[range].runs.contains { $0.link != nil || $0.inlinePresentationIntent?.contains(.code) == true }
                if !taken { result[range].link = url(for: found.reference) }
            }
        }
        for found in references(in: plain, contextBook: contextBook, rules: rules, chapterCount: chapterCount) {
            let range = attributedRange(of: found.range, in: plain, result)
            let taken = result[range].runs.contains { run in
                run.link != nil || run.inlinePresentationIntent?.contains(.code) == true
            }
            if !taken { result[range].link = url(for: found.reference) }
        }
        return result
    }

    // MARK: - Helpers

    /// `range` of `plain` as the same characters of `text`.
    private static func attributedRange(of range: Range<String.Index>, in plain: String, _ text: AttributedString) -> Range<AttributedString.Index> {
        let lower = text.characters.index(text.startIndex, offsetBy: plain.distance(from: plain.startIndex, to: range.lowerBound))
        let upper = text.characters.index(lower, offsetBy: plain.distance(from: range.lowerBound, to: range.upperBound))
        return lower..<upper
    }

    /// Where a book name could begin before `end`, longest first: each word start among the
    /// `maxBookWords` words directly before it (separated by spaces), where that word begins
    /// with a capital letter or is a number ("1 John"); in a note, also a lower-case word of three
    /// letters or more ("gen").
    private static func bookStarts(before end: String.Index, in text: String, rules: Rules) -> [String.Index] {
        var starts: [String.Index] = []
        var cursor = end
        for _ in 0..<maxBookWords {
            // One or more spaces, then a word of letters or digits, optionally ending in a period ("Ps.").
            var index = cursor
            guard index > text.startIndex, text[text.index(before: index)] == " " else { break }
            while index > text.startIndex, text[text.index(before: index)] == " " { index = text.index(before: index) }
            var wordEnd = index
            if wordEnd > text.startIndex, text[text.index(before: wordEnd)] == "." { wordEnd = text.index(before: wordEnd) }
            var wordStart = wordEnd
            while wordStart > text.startIndex, text[text.index(before: wordStart)].isLetter || text[text.index(before: wordStart)].isNumber {
                wordStart = text.index(before: wordStart)
            }
            guard wordStart < wordEnd else { break }
            let first = text[wordStart]
            let word = text[wordStart..<wordEnd]
            if first.isUppercase || word.allSatisfy(\.isNumber) || (rules == .note && word.count >= 3) { starts.append(wordStart) }
            cursor = wordStart
        }
        return starts.reversed()
    }

    /// "3:30 pm", "10:45 a.m.": am or pm, in any case, after optional space.
    private static func isClockTime(after end: String.Index, in text: String) -> Bool {
        let rest = text[end...].drop { $0 == " " }.lowercased()
        if rest.hasPrefix("a.m.") || rest.hasPrefix("p.m.") { return true }
        guard rest.hasPrefix("am") || rest.hasPrefix("pm") else { return false }
        return !(rest.dropFirst(2).first?.isLetter ?? false)
    }
}
