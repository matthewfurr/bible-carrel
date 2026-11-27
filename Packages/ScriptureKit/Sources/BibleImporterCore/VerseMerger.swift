import Foundation

/// A verse after its source entries have been merged.
public struct MergedVerse: Equatable, Sendable {
    public let number: Int
    /// Set when the source combines several verses under one ID such as `"12-13"`.
    public let endNumber: Int?
    /// Lines joined with `"\n"`; multi-line verses are poetry.
    public let text: String
    /// True when the source marks a paragraph break after this verse.
    public let breakAfter: Bool

    public init(number: Int, endNumber: Int? = nil, text: String, breakAfter: Bool) {
        self.number = number
        self.endNumber = endNumber
        self.text = text
        self.breakAfter = breakAfter
    }
}

public enum VerseMerger {
    /// Groups consecutive entries that share an `ID` into one verse each.
    /// IDs are an integer or an ascending range `"A-B"`; anything else, and groups with no text, are skipped with a warning.
    public static func merge(_ entries: [HolyBookFile.Entry], warnings: inout [ImportWarning]) -> [MergedVerse] {
        var result: [MergedVerse] = []
        var index = 0
        while index < entries.count {
            let id = entries[index].ID
            var group: [HolyBookFile.Entry] = []
            while index < entries.count, entries[index].ID == id {
                group.append(entries[index])
                index += 1
            }
            guard let (number, endNumber) = parseID(id) else {
                warnings.append(ImportWarning("Skipped verse with unrecognised ID \"\(id)\""))
                continue
            }
            let trimmed = group.map { Self.cleanLines($0.text) }
            let lines = trimmed.filter { !$0.isEmpty }
            guard !lines.isEmpty else {
                // An omitted verse (present only as an empty marker) still marks a paragraph break.
                warnings.append(ImportWarning("Skipped verse \(number) with no text"))
                if let last = result.popLast() {
                    result.append(MergedVerse(number: last.number, endNumber: last.endNumber, text: last.text, breakAfter: true))
                }
                continue
            }
            result.append(MergedVerse(
                number: number,
                endNumber: endNumber,
                text: lines.joined(separator: "\n"),
                breakAfter: trimmed.last?.isEmpty == true
            ))
        }
        return result
    }

    /// Trims every line of an entry and drops blank lines, so verse text never carries
    /// stray whitespace next to a line break (highlight offsets depend on exact text).
    static func cleanLines(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// `"12"` → (12, nil); `"12-13"` → (12, 13); anything else, or a non-ascending range → nil.
    static func parseID(_ id: String) -> (Int, Int?)? {
        if let single = Int(id) { return (single, nil) }
        let parts = id.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]), end > start else { return nil }
        return (start, end)
    }
}
