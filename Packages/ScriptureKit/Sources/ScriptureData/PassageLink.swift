import Foundation

/// A link to a Bible passage such as `bible://jhn.3.16-18`, read and written in either build's scheme.
public struct PassageLink: Hashable, Sendable {
    public static let releaseScheme = "bible"
    public static let debugScheme = "bible-dev"
    public static let schemes: Set<String> = [releaseScheme, debugScheme]
    /// The Info.plist key that names the build's scheme.
    public static let infoKey = "PassageURLScheme"

    public let reference: Reference
    /// As the link wrote it, upper-cased; the app decides whether it has that translation.
    public let translationID: String?

    public init(reference: Reference, translationID: String? = nil) {
        self.reference = reference
        self.translationID = translationID
    }

    /// Nil for anything that is not a passage link in either scheme.
    public init?(_ url: URL) {
        self.init(string: url.absoluteString)
    }

    /// Reads the link's text directly: `URL.host` would lower-case the book and read ":16" as a port.
    public init?(string text: String) {
        guard let colon = text.firstIndex(of: ":"),
              Self.schemes.contains(text[..<colon].lowercased()) else { return nil }
        var rest = Substring(text[text.index(after: colon)...])
        if rest.hasPrefix("//") { rest = rest.dropFirst(2) }
        if let hash = rest.firstIndex(of: "#") { rest = rest[..<hash] }
        var query = Substring()
        if let mark = rest.firstIndex(of: "?") {
            query = rest[rest.index(after: mark)...]
            rest = rest[..<mark]
        }
        if rest.hasSuffix("/") { rest = rest.dropLast() }
        guard let path = String(rest).removingPercentEncoding, !path.isEmpty else { return nil }

        let parsed: Reference?
        if let first = path.split(separator: ".", omittingEmptySubsequences: false).first,
           BookCatalog.book(code: first.uppercased()) != nil {
            parsed = Self.dottedReference(path)
        } else {
            // Written by hand ("bible://John%203:16"): the book named exactly, never guessed from
            // a prefix; and a name of one or two letters with no chapter is a word ("bible:is").
            parsed = ReferenceParser.parse(path, exactBook: true)
            if parsed?.chapter == nil, path.filter({ $0.isLetter || $0.isNumber }).count <= 2 { return nil }
        }
        guard let parsed else { return nil }
        self.init(reference: parsed, translationID: Self.translation(inQuery: query))
    }

    /// `bible://jhn.3.16-18`, `bible://rom.8`, `bible://jhn`, `…?translation=KJV`.
    public func url(scheme: String) -> URL {
        var text = "\(scheme)://\(reference.book.id.lowercased())"
        if let chapter = reference.chapter {
            text += ".\(chapter)"
            if let verse = reference.verse {
                text += ".\(verse)"
                if let end = reference.endVerse { text += "-\(end)" }
            }
        }
        if let translationID,
           let encoded = translationID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
            text += "?translation=\(encoded)"
        }
        return URL(string: text)!
    }

    /// The scheme an Info.plist names, when it is one of `schemes`; otherwise `releaseScheme`.
    public static func scheme(inInfo info: [String: Any]?) -> String {
        if let named = info?[infoKey] as? String, schemes.contains(named) { return named }
        return releaseScheme
    }

    public static var appScheme: String { scheme(inInfo: Bundle.main.infoDictionary) }

    // MARK: Reading

    /// `book[.chapter[.verse[-end]]]`, where `end` is a verse number or `book.chapter.verse`.
    private static func dottedReference(_ path: String) -> Reference? {
        let sides = path.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: false)
        guard sides.count <= 2 else { return nil }
        let head = sides[0].split(separator: ".", omittingEmptySubsequences: false)
        guard head.count <= 3,
              let book = BookCatalog.book(code: head[0].uppercased()) else { return nil }
        var numbers: [Int] = []
        for piece in head.dropFirst() {
            guard let number = wholeNumber(piece) else { return nil }
            numbers.append(number)
        }
        let chapter = numbers.first
        let verse = numbers.count > 1 ? numbers[1] : nil
        guard sides.count == 2 else { return Reference(book: book, chapter: chapter, verse: verse) }
        guard let chapter, let verse else { return nil }

        let tail = sides[1]
        if let end = wholeNumber(tail) {
            return end > verse ? Reference(book: book, chapter: chapter, verse: verse, endVerse: end) : nil
        }
        let pieces = tail.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3,
              let endBook = BookCatalog.book(code: pieces[0].uppercased()),
              let endChapter = wholeNumber(pieces[1]),
              let end = wholeNumber(pieces[2]) else { return nil }
        guard endBook == book, endChapter == chapter else {
            return Reference(book: book, chapter: chapter, verse: verse)
        }
        return end > verse ? Reference(book: book, chapter: chapter, verse: verse, endVerse: end) : nil
    }

    private static func wholeNumber(_ piece: Substring) -> Int? {
        guard !piece.isEmpty, piece.allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = Int(piece), number >= 1 else { return nil }
        return number
    }

    /// The first of `translation`, then `v`, with a value that is not empty, upper-cased.
    private static func translation(inQuery query: Substring) -> String? {
        var values: [String: String] = [:]
        for item in query.split(separator: "&") {
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2, let value = String(pair[1]).removingPercentEncoding, !value.isEmpty else { continue }
            let name = pair[0].lowercased()
            if values[name] == nil { values[name] = value }
        }
        return (values["translation"] ?? values["v"])?.uppercased()
    }
}
