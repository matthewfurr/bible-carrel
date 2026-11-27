import CoreText
import Foundation

/// What a dictionary entry shows before "Show more": its first paragraph, cut at a sentence end
/// when that paragraph runs past `shownLines` lines.
enum DictionaryEntry {
    static let shownLines = 10

    struct Shown: Equatable {
        let text: String
        let endsInEllipsis: Bool
        let hidesMore: Bool
    }

    /// The entry's paragraphs: split on blank lines, the empty ones dropped.
    static func paragraphs(_ entry: String) -> [String] {
        entry.components(separatedBy: "\n")
            .reduce(into: [[String]]()) { groups, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    if groups.last?.isEmpty == false { groups.append([]) }
                } else if groups.isEmpty || groups.last == nil {
                    groups.append([line])
                } else {
                    groups[groups.count - 1].append(line)
                }
            }
            .map { $0.joined(separator: "\n") }
            .filter { !$0.isEmpty }
    }

    /// What shows before the width is known: the first paragraph whole, "Show more" where there are others.
    static func unmeasured(_ entry: String) -> Shown {
        let all = paragraphs(entry)
        return Shown(text: all.first ?? "", endsInEllipsis: false, hidesMore: all.count > 1)
    }

    /// The first paragraph whole when `fits`; else its longest prefix of whole sentences that fits
    /// (Departure 32); else its first sentence, to be truncated by the view.
    static func shown(_ entry: String, fits: (String) -> Bool) -> Shown {
        let all = paragraphs(entry)
        guard let first = all.first else { return Shown(text: "", endsInEllipsis: false, hidesMore: false) }
        let hasMore = all.count > 1
        if fits(first) { return Shown(text: first, endsInEllipsis: false, hidesMore: hasMore) }
        var ends: [String.Index] = []
        first.enumerateSubstrings(in: first.startIndex..., options: .bySentences) { _, range, _, _ in
            ends.append(range.upperBound)
        }
        func prefix(_ index: Int) -> String {
            String(first[..<ends[index]]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !ends.isEmpty, fits(prefix(0)) else {
            let sentence = ends.isEmpty ? first : prefix(0)
            return Shown(text: sentence, endsInEllipsis: true, hidesMore: true)
        }
        var low = 0, high = ends.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if fits(prefix(mid)) { low = mid } else { high = mid - 1 }
        }
        return Shown(text: prefix(low), endsInEllipsis: false, hidesMore: true)
    }

    /// The lines `text` takes in `font` at `width`, laid out by Core Text.
    static func lineCount(_ text: String, font: PlatformFont, width: CGFloat) -> Int {
        guard !text.isEmpty, width > 0 else { return 0 }
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 100_000), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
        return CFArrayGetCount(CTFrameGetLines(frame))
    }
}
