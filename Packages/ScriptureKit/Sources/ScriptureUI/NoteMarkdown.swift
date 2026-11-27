import Foundation
import SwiftUI

/// Markdown display for note bodies. Full syntax is parsed, then flattened for `Text`: blocks are
/// separated by newlines, list items get a bullet or number, headings get a larger bold font,
/// inline emphasis and links are kept. Line breaks in the source are kept as line breaks.
/// Unparseable text falls back to itself, plain.
public enum NoteMarkdown {
    /// The body as top-level blocks (paragraphs, lists, headings), each flattened as
    /// `attributed(_:)` does, so a view can stack them with paragraph spacing: a blank line in
    /// the source reads as a paragraph break. With `headingsAtTextSize` a heading's runs carry no
    /// font, so a one-size preview line sets them at its own size and weight.
    public static func blocks(_ body: String, headingsAtTextSize: Bool = false) -> [AttributedString] {
        let source = body.replacingOccurrences(of: "\n", with: "  \n")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        guard let parsed = try? AttributedString(markdown: source, options: options) else { return [AttributedString(body)] }
        var blocks: [AttributedString] = []
        var current = AttributedString()
        var lastTop: Int?
        var lastInner: Int?
        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let top = components.last?.identity
            let inner = components.first?.identity
            if top != lastTop {
                if !current.characters.isEmpty { blocks.append(current) }
                current = AttributedString()
                lastTop = top
                lastInner = nil
            }
            if inner != lastInner {
                if !current.characters.isEmpty { current.append(AttributedString("\n")) }
                if let ordinal = components.lazy.compactMap({ component -> Int? in
                    if case .listItem(let ordinal) = component.kind { return ordinal }
                    return nil
                }).first {
                    let ordered = components.contains { if case .orderedList = $0.kind { return true } else { return false } }
                    current.append(AttributedString(ordered ? "\(ordinal). " : "• "))
                }
                lastInner = inner
            }
            var piece = AttributedString(parsed[run.range])
            piece.presentationIntent = nil
            if !headingsAtTextSize, components.contains(where: { if case .header = $0.kind { return true } else { return false } }) {
                piece.font = .system(.title3, weight: .semibold)
            }
            current.append(piece)
        }
        if !current.characters.isEmpty { blocks.append(current) }
        return blocks
    }

    /// The body as one string for a single selectable `Text`: the blocks of `blocks(_:)` joined
    /// by a blank line, so a drag can select across paragraphs. Headings keep their font.
    public static func document(_ body: String) -> AttributedString {
        var result = AttributedString()
        for (index, block) in blocks(body).enumerated() {
            if index > 0 { result.append(AttributedString("\n\n")) }
            result.append(block)
        }
        return result
    }

    public static func attributed(_ body: String) -> AttributedString {
        // A bare newline is a soft break in Markdown (rendered as a space); notes read better with
        // every newline kept, so each becomes a hard break.
        let source = body.replacingOccurrences(of: "\n", with: "  \n")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        guard let parsed = try? AttributedString(markdown: source, options: options) else { return AttributedString(body) }

        var result = AttributedString()
        var lastBlock: Int?
        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let block = components.first?.identity
            if block != lastBlock {
                if !result.characters.isEmpty { result.append(AttributedString("\n")) }
                if let ordinal = components.lazy.compactMap({ component -> Int? in
                    if case .listItem(let ordinal) = component.kind { return ordinal }
                    return nil
                }).first {
                    let ordered = components.contains { if case .orderedList = $0.kind { return true } else { return false } }
                    result.append(AttributedString(ordered ? "\(ordinal). " : "• "))
                }
                lastBlock = block
            }
            var piece = AttributedString(parsed[run.range])
            piece.presentationIntent = nil
            if components.contains(where: { if case .header = $0.kind { return true } else { return false } }) {
                piece.font = .system(.title3, weight: .semibold)
            }
            result.append(piece)
        }
        return result
    }
}
