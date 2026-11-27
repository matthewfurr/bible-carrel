import Foundation
import GRDB

public struct WordCount: Hashable, Sendable {
    public let word: String
    public let verses: Int

    public init(word: String, verses: Int) {
        self.word = word
        self.verses = verses
    }
}

public struct SearchSuggestion: Hashable, Sendable {
    public let query: String
    public let verseCount: Int

    public init(query: String, verseCount: Int) {
        self.query = query
        self.verseCount = verseCount
    }
}

/// "Did you mean": the words a translation's own index holds that sit a few edits from a word that
/// found nothing. Pure; the store supplies the words.
public enum SpellingSuggester {
    /// Edits between two folded words: a letter added, dropped or changed, or two neighbours
    /// swapped, each counting one. Nil past `limit`.
    public static func distance(_ a: String, _ b: String, limit: Int) -> Int? {
        let a = Array(a), b = Array(b)
        guard abs(a.count - b.count) <= limit else { return nil }
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) <= limit ? max(a.count, b.count) : nil }
        var twoBack: [Int] = []
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var row = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                var best = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    best = min(best, twoBack[j - 2] + 1)
                }
                row[j] = best
            }
            twoBack = previous
            previous = row
        }
        return previous[b.count] <= limit ? previous[b.count] : nil
    }

    /// 1 for a word of up to three letters, 2 for four to six, 3 for seven or more.
    public static func allowance(for word: String) -> Int {
        switch word.count {
        case ...3: 1
        case 4...6: 2
        default: 3
        }
    }

    /// The listed words within `word`'s allowance: closer first, then in more verses, then by spelling.
    public static func candidates(for word: String, in words: [WordCount], limit: Int = 3) -> [String] {
        let allowed = allowance(for: word)
        var near: [(word: String, distance: Int, verses: Int)] = []
        for entry in words {
            guard let d = distance(word, entry.word, limit: allowed) else { continue }
            near.append((entry.word, d, entry.verses))
        }
        near.sort {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.verses != $1.verses { return $0.verses > $1.verses }
            return $0.word < $1.word
        }
        return near.prefix(limit).map(\.word)
    }

    /// The queries to try in place of `query`, best first; none past `maximumTerms` terms.
    public static func queries(for query: SearchQuery, in words: [WordCount], limit: Int = 5) -> [String] {
        guard query.allowsSuggestion, query.terms.count <= maximumTerms else { return [] }
        var options: [[String]] = []
        var anyUnknown = false
        for term in query.terms {
            let word = term.words[0]
            if words.contains(where: { $0.word.hasPrefix(word) }) {
                options.append([word])
                continue
            }
            guard !word.unicodeScalars.contains(where: { ("0"..."9").contains($0) }) else { return [] }
            let found = candidates(for: word, in: words)
            guard !found.isEmpty else { return [] }
            anyUnknown = true
            options.append(found)
        }
        guard anyUnknown else { return [] }
        return cheapestPlaces(counts: options.map(\.count), limit: limit).map { places in
            places.enumerated().map { options[$0.offset][$0.element] }.joined(separator: " ")
        }
    }

    /// The most terms a query may have and still be offered something: a misspelling is a short
    /// query, a pasted passage is not.
    public static let maximumTerms = 12

    /// The first `limit` choices of one place per word (word `i` has `counts[i]` places), in order of
    /// the places' sum, then by the earlier word's place. Made in that order and stopped at `limit`,
    /// so no more than `limit` are ever held: every place tried can still reach the sum being filled.
    static func cheapestPlaces(counts: [Int], limit: Int) -> [[Int]] {
        guard limit > 0, !counts.isEmpty, counts.allSatisfy({ $0 > 0 }) else { return [] }
        // The most the words from each one on can add.
        var mostFrom = Array(repeating: 0, count: counts.count + 1)
        for word in counts.indices.reversed() { mostFrom[word] = mostFrom[word + 1] + counts[word] - 1 }
        var found: [[Int]] = []
        var places: [Int] = []
        func fill(_ word: Int, _ remaining: Int) {
            guard word < counts.count else { found.append(places); return }
            let lowest = max(0, remaining - mostFrom[word + 1])
            let highest = min(remaining, counts[word] - 1)
            for place in lowest...highest where found.count < limit {
                places.append(place)
                fill(word + 1, remaining - place)
                places.removeLast()
            }
        }
        for sum in 0...mostFrom[0] where found.count < limit { fill(0, sum) }
        return found
    }
}

extension BibleStore {
    /// The translation's words as its index holds them, each with how many verses have it, sorted
    /// by word; empty for a translation the database lacks. Read once per translation and kept.
    public func words(in translationID: String) throws -> [WordCount] {
        if let kept = keptWords.withLock({ $0[translationID] }) { return kept }
        let read = try readWords(in: translationID)
        keptWords.withLock { $0[translationID] = read }
        return read
    }

    /// For a search that found nothing: the first of `queries` that finds a verse in the scope, with its count.
    public func suggestion(for query: SearchQuery, translationID: String,
                           scope: SearchScope = .wholeBible) throws -> SearchSuggestion? {
        guard query.allowsSuggestion else { return nil }
        for typed in SpellingSuggester.queries(for: query, in: try words(in: translationID)) {
            let page = try search(SearchQuery(typed), translationID: translationID, scope: scope, limit: 0)
            if page.total > 0 { return SearchSuggestion(query: typed, verseCount: page.total) }
        }
        return nil
    }
}
