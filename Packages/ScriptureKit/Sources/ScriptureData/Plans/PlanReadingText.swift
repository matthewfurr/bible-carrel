import Foundation

public enum PlanReadingText {
    public enum Failure: Error, Equatable, Sendable { case empty, unknownBook(String), unreadable(String) }
    public struct Parsed: Equatable, Sendable { public let passages: [PlanPassage]; public let label: String? }

    /// A book's name, then a chapter, a run of chapters, a verse or verses of one chapter.
    public static func passage(_ text: String) -> Result<PlanPassage, Failure> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let space = trimmed.lastIndex(of: " ") else { return .failure(.unreadable(text)) }
        let name = trimmed[..<space].trimmingCharacters(in: .whitespaces)
        let numbers = trimmed[trimmed.index(after: space)...]
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        guard !name.isEmpty, let shape = shape(of: numbers) else { return .failure(.unreadable(text)) }
        // A book's name is letters after an optional leading number ("1 John"): a figure or a mark
        // after that is a passage spaced out ("Esther 7 - 8", "Psalms 119: 1-16"), not a book's name.
        if name.drop(while: \.isNumber).contains(where: { $0.isNumber || "-–—:,".contains($0) }) {
            return .failure(.unreadable(text))
        }
        guard let reference = ReferenceParser.parse(name, exactBook: true), reference.chapter == nil else { return .failure(.unknownBook(name)) }
        let code = reference.book.id
        switch shape {
        case let .chapters(first, last):
            return .success(PlanPassage(book: code, chapter: first, endChapter: last))
        case let .verses(chapter, first, last):
            return .success(PlanPassage(book: code, chapter: chapter, verse: first, endVerse: last))
        }
    }

    /// One line of the editor: passages separated by ";", then an optional "(label)".
    public static func parse(_ line: String) -> Result<Parsed, Failure> {
        var body = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var label: String?
        if body.hasSuffix(")"), let open = body.lastIndex(of: "(") {
            let inside = body[body.index(after: open)..<body.index(before: body.endIndex)]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            label = inside.isEmpty ? nil : inside
            body = String(body[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let pieces = body.split(separator: ";", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !pieces.isEmpty else { return .failure(.empty) }
        var passages: [PlanPassage] = []
        for piece in pieces {
            switch passage(piece) {
            case let .success(parsed): passages.append(parsed)
            case let .failure(failure): return .failure(failure)
            }
        }
        return .success(Parsed(passages: passages, label: label))
    }

    /// `"Psalms 84; Esther 7-8"`, `"John 11-12 (NT Focus Week)"`.
    public static func line(for reading: PlanReading) -> String {
        let passages = reading.passages.map(\.editString).joined(separator: "; ")
        guard let label = reading.label, !label.isEmpty else { return passages }
        return "\(passages) (\(label))"
    }

    private enum Shape {
        case chapters(Int, Int)
        case verses(chapter: Int, first: Int, last: Int?)
    }

    private static func shape(of text: String) -> Shape? {
        func number(_ part: Substring) -> Int? {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(part), value >= 1 else { return nil }
            return value
        }
        let colon = text.split(separator: ":", omittingEmptySubsequences: false)
        switch colon.count {
        case 1:
            let dash = colon[0].split(separator: "-", omittingEmptySubsequences: false)
            guard dash.count <= 2, let first = number(dash[0]) else { return nil }
            if dash.count == 1 { return .chapters(first, first) }
            guard let last = number(dash[1]), last > first else { return nil }
            return .chapters(first, last)
        case 2:
            guard let chapter = number(colon[0]) else { return nil }
            let dash = colon[1].split(separator: "-", omittingEmptySubsequences: false)
            guard dash.count <= 2, let first = number(dash[0]) else { return nil }
            if dash.count == 1 { return .verses(chapter: chapter, first: first, last: nil) }
            guard let last = number(dash[1]), last > first else { return nil }
            return .verses(chapter: chapter, first: first, last: last)
        default:
            return nil
        }
    }
}
