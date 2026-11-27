import Foundation

/// Counts as one phrase: `12 notes and 3 highlights`, `2 highlights, 1 note and 1 bookmark`.
enum CountList {
    /// The non-zero counts in the order given, each with its noun in the plural unless it is 1;
    /// nil when every count is 0.
    static func text(_ parts: [(Int, String)]) -> String? {
        let phrases = parts.filter { $0.0 > 0 }.map { count, noun in "\(count) \(noun)\(count == 1 ? "" : "s")" }
        guard let last = phrases.last else { return nil }
        return phrases.count == 1 ? last : phrases.dropLast().joined(separator: ", ") + " and " + last
    }
}
