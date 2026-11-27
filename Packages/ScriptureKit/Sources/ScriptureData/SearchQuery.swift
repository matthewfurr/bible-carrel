import Foundation

/// What the reader typed into search, read once into terms. The same reading drives the index's MATCH
/// string (`ftsMatch`) and the matching and bolding of the reader's own notes (`matches`, `matchRanges`),
/// so the two can never disagree about what a query means.
public struct SearchQuery: Hashable, Sendable {
    public struct Term: Hashable, Sendable {
        /// Folded: lower case, no accents, letters and digits only; never empty.
        public let words: [String]
        /// A bare word: its last word may start a longer one. False for a quoted phrase, an
        /// excluded term, and a word whose last piece follows an apostrophe.
        public let isWordStart: Bool
        public let isExcluded: Bool
    }

    public struct Token: Hashable, Sendable {
        public let word: String
        public let range: Range<String.Index>
    }

    /// What was typed, trimmed.
    public let text: String
    public let terms: [Term]

    public init(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = trimmed
        self.terms = Self.parse(trimmed)
    }

    // MARK: Index

    /// The index's MATCH string; nil with no term to find (nothing typed, or exclusions alone).
    public var ftsMatch: String? {
        let found = terms.filter { !$0.isExcluded }.map(Self.matchString)
        guard !found.isEmpty else { return nil }
        let wanted = found.joined(separator: " AND ")
        let excluded = terms.filter(\.isExcluded).map(Self.matchString)
        guard !excluded.isEmpty else { return wanted }
        return "(\(wanted)) NOT (\(excluded.joined(separator: " OR ")))"
    }

    private static func matchString(_ term: Term) -> String {
        "\"\(term.words.joined(separator: " "))\"" + (term.isWordStart ? " *" : "")
    }

    /// No quotation mark and no exclusion was typed, and every term is one word.
    public var allowsSuggestion: Bool {
        !terms.isEmpty
            && !Self.normalized(text).unicodeScalars.contains("\"")
            && terms.allSatisfy { !$0.isExcluded && $0.words.count == 1 }
    }

    // MARK: Tokens

    /// `text` cut as the index cuts it: runs of letters, digits and combining marks, each folded.
    public static func tokens(in text: String) -> [Token] {
        var tokens: [Token] = []
        let scalars = text.unicodeScalars
        var start: String.Index?
        func close(at end: String.Index) {
            guard let from = start else { return }
            start = nil
            let word = String(scalars[from..<end]).folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            if !word.isEmpty { tokens.append(Token(word: word, range: from..<end)) }
        }
        var index = scalars.startIndex
        while index < scalars.endIndex {
            if isTokenScalar(scalars[index]) {
                if start == nil { start = index }
            } else {
                close(at: index)
            }
            index = scalars.index(after: index)
        }
        close(at: scalars.endIndex)
        return tokens
    }

    private static func isTokenScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber,
             .nonspacingMark, .spacingMark, .enclosingMark,
             .privateUse:
            true
        default:
            false
        }
    }

    // MARK: Matching

    /// One of `fields` holds every term to find, and no field holds an excluded term. False with no term to find.
    public func matches(anyOf fields: [String]) -> Bool {
        let found = terms.filter { !$0.isExcluded }
        guard !found.isEmpty else { return false }
        let excluded = terms.filter(\.isExcluded)
        let tokenized = fields.map { Self.tokens(in: $0).map(\.word) }
        if tokenized.contains(where: { words in excluded.contains { !Self.positions(of: $0, in: words).isEmpty } }) {
            return false
        }
        return tokenized.contains { words in found.allSatisfy { !Self.positions(of: $0, in: words).isEmpty } }
    }

    public func matches(_ text: String) -> Bool { matches(anyOf: [text]) }

    /// The words of `text` the terms to find match, in text order, for bolding.
    public func matchRanges(in text: String) -> [Range<String.Index>] {
        let tokens = Self.tokens(in: text)
        let words = tokens.map(\.word)
        var hit = Set<Int>()
        for term in terms where !term.isExcluded {
            for position in Self.positions(of: term, in: words) {
                hit.formUnion(position..<(position + term.words.count))
            }
        }
        return hit.sorted().map { tokens[$0].range }
    }

    /// Where `term` starts in `words`: its words side by side, the last one only a start when `isWordStart`.
    private static func positions(of term: Term, in words: [String]) -> [Int] {
        let count = term.words.count
        guard count <= words.count else { return [] }
        return (0...(words.count - count)).filter { start in
            for offset in 0..<count {
                let word = words[start + offset], wanted = term.words[offset]
                let isLast = offset == count - 1
                if isLast && term.isWordStart ? !word.hasPrefix(wanted) : word != wanted { return false }
            }
            return true
        }
    }

    // MARK: Reading

    private static func normalized(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            switch scalar {
            case "\u{201C}", "\u{201D}", "\u{201E}", "\u{00AB}", "\u{00BB}": "\""
            case "\u{2019}", "\u{2018}": "'"
            default: scalar
            }
        }))
    }

    private static func parse(_ text: String) -> [Term] {
        let scalars = Array(normalized(text).unicodeScalars)
        var terms: [Term] = []
        var index = 0
        func isSpace(_ scalar: Unicode.Scalar) -> Bool { scalar.properties.isWhitespace }
        while index < scalars.count {
            if isSpace(scalars[index]) { index += 1; continue }
            var dashes = 0
            while index < scalars.count, scalars[index] == "-" { dashes += 1; index += 1 }
            if dashes > 0, index == scalars.count || isSpace(scalars[index]) { continue }
            let excluded = dashes > 0
            var piece = String.UnicodeScalarView()
            let isPhrase = index < scalars.count && scalars[index] == "\""
            if isPhrase {
                index += 1
                while index < scalars.count, scalars[index] != "\"" { piece.append(scalars[index]); index += 1 }
                if index < scalars.count { index += 1 }
            } else {
                while index < scalars.count, !isSpace(scalars[index]), scalars[index] != "\"" {
                    piece.append(scalars[index]); index += 1
                }
            }
            let word = String(piece)
            let tokens = tokens(in: word)
            guard !tokens.isEmpty else { continue }
            var isStart = !isPhrase && !excluded
            if isStart, tokens.count > 1 {
                let gap = word.unicodeScalars[tokens[tokens.count - 2].range.upperBound..<tokens[tokens.count - 1].range.lowerBound]
                if gap.contains("'") { isStart = false }
            }
            terms.append(Term(words: tokens.map(\.word), isWordStart: isStart, isExcluded: excluded))
        }
        return terms
    }
}
