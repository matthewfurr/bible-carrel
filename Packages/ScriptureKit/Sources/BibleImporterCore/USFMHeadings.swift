import Foundation

/// A section heading (`\s1`, `\s2`) and the verse it introduces.
public struct USFMHeading: Equatable, Sendable {
    public let chapter: Int
    public let verse: Int
    /// Position among the headings queued before the same verse.
    public let ordinal: Int
    public let level: Int
    public let text: String

    public init(chapter: Int, verse: Int, ordinal: Int, level: Int, text: String) {
        self.chapter = chapter
        self.verse = verse
        self.ordinal = ordinal
        self.level = level
        self.text = text
    }
}

public struct USFMBook: Sendable {
    public let bookID: String
    public let headings: [USFMHeading]
    public let mainTitle: String?
}

/// Reads the section headings and main title out of an eBible USFM book file.
public enum USFMHeadings {
    public static func parse(_ usfm: String) -> USFMBook? {
        var bookID: String?
        var mainTitle: String?
        var chapter = 0
        var queued: [(level: Int, text: String)] = []
        var headings: [USFMHeading] = []

        for rawLine in usfm.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("\\") else { continue }
            let marker = line.dropFirst().prefix { $0.isLetter || $0.isNumber }
            let rest = line.dropFirst(marker.count + 1).trimmingCharacters(in: .whitespaces)

            switch marker {
            case "id":
                bookID = rest.split(separator: " ").first.map(String.init)
            case "c":
                chapter = Int(rest.prefix { $0.isNumber }) ?? chapter
            case "mt1":
                let text = plainText(rest)
                if mainTitle == nil, !text.isEmpty { mainTitle = text }
            case "s1", "s2":
                let text = plainText(rest)
                if !text.isEmpty { queued.append((marker == "s1" ? 1 : 2, text)) }
            default:
                // `\r`, `\d`, `\ms` and the rest are not headings; a verse may start on any line.
                if let verse = firstVerse(in: line), !queued.isEmpty {
                    for (ordinal, item) in queued.enumerated() {
                        headings.append(USFMHeading(chapter: chapter, verse: verse, ordinal: ordinal, level: item.level, text: item.text))
                    }
                    queued.removeAll()
                }
            }
        }
        guard let bookID else { return nil }
        return USFMBook(bookID: bookID, headings: headings, mainTitle: mainTitle)
    }

    /// Title-cases all-caps input ("THE GOSPEL" → "The Gospel"); mixed-case input is returned unchanged.
    public static func titleCased(_ text: String) -> String {
        guard text == text.uppercased(), text != text.lowercased() else { return text }
        let small: Set<String> = ["a", "an", "and", "as", "called", "of", "the", "to", "unto"]
        return text.lowercased().split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, word in
                let word = String(word)
                if index > 0, small.contains(word) { return word }
                return word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func firstVerse(in line: String) -> Int? {
        guard let match = line.firstMatch(of: /\\v\s+(\d+)/) else { return nil }
        return Int(match.1)
    }

    /// Drops `\w` word wrappers (keeping the word), footnotes and any other marker.
    private static func plainText(_ text: String) -> String {
        var result = text
        result.replace(/\\f\s.*?\\f\*/, with: "")
        result.replace(/\\w\s+([^|\\]*)(?:\|[^\\]*)?\\w\*/) { String($0.1) }
        result.replace(/\\[A-Za-z0-9]+\*?/, with: "")
        return result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
