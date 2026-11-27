import Foundation
import ScriptureData

public struct CrossReferenceLink: Equatable, Sendable {
    public let source: Int, targetStart: Int, targetEnd: Int, votes: Int

    public init(source: Int, targetStart: Int, targetEnd: Int, votes: Int) {
        self.source = source
        self.targetStart = targetStart
        self.targetEnd = targetEnd
        self.votes = votes
    }
}

/// OpenBible.info's `cross_references.txt`: tab-separated `From Verse`, `To Verse` (a verse or a range
/// `A-B`) and `Votes`, names like `Matt.5.3`.
public enum CrossReferenceFile {
    /// OpenBible's book names to book codes: the 66, in canon order.
    static let books: [String: String] = {
        let names = [
            "Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam", "1Kgs", "2Kgs", "1Chr", "2Chr",
            "Ezra", "Neh", "Esth", "Job", "Ps", "Prov", "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan", "Hos", "Joel",
            "Amos", "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal",
            "Matt", "Mark", "Luke", "John", "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph", "Phil", "Col", "1Thess", "2Thess",
            "1Tim", "2Tim", "Titus", "Phlm", "Heb", "Jas", "1Pet", "2Pet", "1John", "2John", "3John", "Jude", "Rev",
        ]
        return Dictionary(uniqueKeysWithValues: zip(names, BookCatalog.all.prefix(names.count).map(\.id)))
    }()

    /// The links of at least one vote, in file order. The header and blank lines are passed over;
    /// `3John.1.15` is 1:14; a line that does not parse (not three columns, a book not among the
    /// 66, no verse, votes not a number, a range ending before it starts) is left out with a warning.
    public static func parse(_ text: String, warnings: inout [ImportWarning]) -> [CrossReferenceLink] {
        var links: [CrossReferenceLink] = []
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("From Verse") || line.hasPrefix("#") { continue }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count == 3,
                  let source = verseKey(columns[0]),
                  let target = range(columns[1]),
                  let votes = Int(columns[2].trimmingCharacters(in: .whitespaces))
            else {
                warnings.append(ImportWarning("Skipped cross-reference line: \(line)"))
                continue
            }
            if votes >= 1 {
                links.append(CrossReferenceLink(source: source, targetStart: target.start, targetEnd: target.end, votes: votes))
            }
        }
        return links
    }

    private static func range(_ text: Substring) -> (start: Int, end: Int)? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            return verseKey(parts[0]).map { ($0, $0) }
        case 2:
            guard let start = verseKey(parts[0]), let end = verseKey(parts[1]), end >= start else { return nil }
            return (start, end)
        default:
            return nil
        }
    }

    /// "Matt.5.3": three parts, a known book, a chapter and verse of at least one.
    private static func verseKey(_ text: Substring) -> Int? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let code = books[String(parts[0])],
              let chapter = Int(parts[1]), var verse = Int(parts[2]), (1...999).contains(chapter), (1...999).contains(verse)
        else { return nil }
        if code == "3JN", chapter == 1, verse == 15 { verse = 14 }   // OpenBible's `3John.1.15` is 1:14
        return VerseKey.key(VerseLocation(book: code, chapter: chapter, verse: verse))
    }
}
