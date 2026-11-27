import Foundation
import os
import ScriptureData
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// Where one verse sits in a chapter's attributed string. Ranges are UTF-16 (`NSRange`), and
/// `textRange` maps 1:1 onto `Verse.text`, so `characterIndex - textRange.location` is a
/// highlight offset within the verse.
public struct VerseSpan: Equatable, Sendable {
    public let location: VerseLocation
    public let endVerse: Int?
    /// `"3"` or `"12-13"`.
    public let label: String
    public let numberRange: NSRange
    public let textRange: NSRange

    public init(location: VerseLocation, endVerse: Int?, label: String, numberRange: NSRange, textRange: NSRange) {
        self.location = location
        self.endVerse = endVerse
        self.label = label
        self.numberRange = numberRange
        self.textRange = textRange
    }

    /// True for every verse number this span covers, including a combined verse's end.
    public func contains(verse: Int) -> Bool {
        (location.verse...(endVerse ?? location.verse)).contains(verse)
    }

    /// From the start of the number to the end of the text.
    var fullRange: NSRange {
        NSRange(location: numberRange.location, length: NSMaxRange(textRange) - numberRange.location)
    }
}

/// A chapter rendered as one attributed string with per-verse character ranges.
/// `attributedString` is never mutated after construction.
public struct ChapterLayout: @unchecked Sendable {
    /// The Unicode line separator. No longer emitted (every poetry line is its own paragraph);
    /// kept declared for callers that name it.
    public static let lineSeparator = "\u{2028}"

    /// The shape of one paragraph on the printed page.
    public enum ParagraphKind: Equatable, Sendable {
        /// The chapter's first prose paragraph: no indent.
        case opening
        /// A prose paragraph after a paragraph break: an indented first line, little air after.
        case prose
        /// A prose paragraph after poetry: no indent, like the opening.
        case proseAfterPoetry
        /// One line of poetry, hanging: a wrapped line tucks in under its first word.
        case poetryLine
        /// The last line of a stanza: a poetry line with air after it.
        case poetryLineStanzaEnd
    }

    public let attributedString: NSAttributedString
    public let spans: [VerseSpan]

    /// The paragraph style for `kind`. Every kind keeps the typography's line height; the two
    /// un-indented prose kinds keep the full paragraph spacing, indented prose a little.
    public static func paragraphStyle(for kind: ParagraphKind, typography: ReaderTypography) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = typography.lineHeightMultiple
        if typography.justified, kind != .poetryLine, kind != .poetryLineStanzaEnd {
            style.alignment = .justified
            style.hyphenationFactor = 0.9
        }
        switch kind {
        case .opening, .proseAfterPoetry:
            style.paragraphSpacing = typography.paragraphSpacing
        case .prose:
            style.firstLineHeadIndent = typography.firstLineIndent
            style.paragraphSpacing = typography.indentedParagraphSpacing
        case .poetryLine, .poetryLineStanzaEnd:
            style.firstLineHeadIndent = typography.poetryIndent
            style.headIndent = typography.poetryIndent + typography.poetryHang
            style.paragraphSpacing = kind == .poetryLineStanzaEnd ? typography.stanzaSpacing : 0
        }
        return style.copy() as! NSParagraphStyle
    }

    /// Lays the chapter out as a printed page, with section `headings` (keyed by the verse they
    /// precede) as paragraphs of their own. Prose verses flow into paragraphs that a
    /// `breakAfter` ends; every poetry line is its own hanging paragraph, the first carrying the
    /// verse number. Only separators between verses are added, so each verse's `textRange` is its
    /// text unchanged, every `\n` still one UTF-16 unit.
    ///
    /// Main actor only: it makes AppKit/UIKit fonts and attributed strings, and building
    /// concurrently has crashed. The finished layout is immutable and may be handed elsewhere.
    @MainActor
    public static func build(verses: [Verse], headings: [Int: [SectionHeading]] = [:], typography: ReaderTypography = .default) -> ChapterLayout {
        let signpost = ReaderSignposts.signposter.beginInterval(ReaderSignposts.layoutBuild)
        defer { ReaderSignposts.signposter.endInterval(ReaderSignposts.layoutBuild, signpost) }
        let result = NSMutableAttributedString()
        var spans: [VerseSpan] = []

        // One style per kind, shared by every run of that kind.
        func attributes(_ style: NSParagraphStyle) -> (body: [NSAttributedString.Key: Any], number: [NSAttributedString.Key: Any]) {
            ([
                .font: typography.bodyFont,
                .foregroundColor: typography.textColor,
                .paragraphStyle: style,
            ], [
                .font: typography.verseNumberFont,
                .foregroundColor: typography.verseNumberColor,
                .baselineOffset: typography.verseNumberBaselineOffset,
                .paragraphStyle: style,
            ])
        }
        let kinds: [ParagraphKind] = [.opening, .prose, .proseAfterPoetry, .poetryLine, .poetryLineStanzaEnd]
        let styled = kinds.map { attributes(paragraphStyle(for: $0, typography: typography)) }
        func body(_ kind: ParagraphKind) -> [NSAttributedString.Key: Any] { styled[kinds.firstIndex(of: kind)!].body }
        func number(_ kind: ParagraphKind) -> [NSAttributedString.Key: Any] { styled[kinds.firstIndex(of: kind)!].number }

        func headingStyle(first: Bool) -> NSParagraphStyle {
            let size = typography.bodyFont.pointSize
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = typography.lineHeightMultiple
            style.alignment = typography.sectionHeadingAlignment
            style.paragraphSpacingBefore = first ? 0 : size
            style.paragraphSpacing = (0.45 * size).rounded()
            return style.copy() as! NSParagraphStyle
        }
        let firstHeadingStyle = headingStyle(first: true)
        let laterHeadingStyle = headingStyle(first: false)

        var previous: Verse?
        // The paragraph the next character joins; a separator continues or ends it.
        var current: ParagraphKind = .opening
        for verse in verses {
            let isPoetry = verse.text.contains("\n")
            let verseHeadings = typography.showsSectionHeadings ? (headings[verse.id.verse] ?? []) : []
            if let previous {
                let previousIsPoetry = previous.text.contains("\n")
                let breaks = previous.breakAfter || isPoetry || previousIsPoetry
                    || typography.versePerLine || !verseHeadings.isEmpty
                result.append(NSAttributedString(string: breaks ? "\n" : " ", attributes: body(current)))
                if isPoetry {
                    current = .poetryLine
                } else if typography.versePerLine {
                    current = .opening
                } else if breaks {
                    current = previousIsPoetry ? .proseAfterPoetry : .prose
                }
            } else {
                current = isPoetry ? .poetryLine : .opening
            }

            // Each heading is its own paragraph outside every span; the verse after it opens.
            for heading in verseHeadings {
                result.append(NSAttributedString(string: heading.text + "\n", attributes: [
                    .font: typography.sectionHeadingFont,
                    .foregroundColor: typography.sectionHeadingColor,
                    .kern: typography.sectionHeadingKern,
                    .paragraphStyle: result.length == 0 ? firstHeadingStyle : laterHeadingStyle,
                    .readerRole: ReaderRoleBox(.sectionHeading),
                ]))
                current = isPoetry ? .poetryLine : .opening
            }

            let label = verse.endVerse.map { "\(verse.id.verse)-\($0)" } ?? "\(verse.id.verse)"
            let numberStart = result.length
            if typography.showsVerseNumbers {
                result.append(NSAttributedString(string: label, attributes: number(current)))
            }
            let numberRange = NSRange(location: numberStart, length: result.length - numberStart)

            if typography.showsVerseNumbers {
                result.append(NSAttributedString(string: " ", attributes: body(current)))
            }

            let textStart = result.length
            if isPoetry {
                // One paragraph per line, each ended by its own "\n"; the last line of a stanza
                // takes the air.
                let lines = verse.text.components(separatedBy: "\n")
                for (index, line) in lines.enumerated() {
                    let isLast = index == lines.count - 1
                    current = isLast && verse.breakAfter ? .poetryLineStanzaEnd : .poetryLine
                    result.append(NSAttributedString(string: isLast ? line : line + "\n", attributes: body(current)))
                }
            } else {
                result.append(NSAttributedString(string: verse.text, attributes: body(current)))
            }
            let textRange = NSRange(location: textStart, length: result.length - textStart)

            spans.append(VerseSpan(location: verse.id, endVerse: verse.endVerse, label: label, numberRange: numberRange, textRange: textRange))
            previous = verse
        }

        // An immutable copy, so nothing can edit the string after the spans were computed.
        return ChapterLayout(attributedString: result.copy() as! NSAttributedString, spans: spans)
    }

    /// The span whose number or text covers `characterIndex`.
    public func span(containing characterIndex: Int) -> VerseSpan? {
        spans.first { NSLocationInRange(characterIndex, $0.fullRange) }
    }

    /// The span that renders `verse`, including a combined verse's second number.
    public func span(forVerse verse: Int) -> VerseSpan? {
        spans.first { $0.contains(verse: verse) }
    }

    /// The verse to record as "first visible" when a line starting at `lineStart` is the topmost fully
    /// visible line: the first verse label at or after that index, else the verse containing it.
    /// Scrolling that verse's line to the top reports the same verse again, so a relaunch never drifts.
    public func firstVisibleVerse(fromLineStart lineStart: Int) -> Int? {
        if let next = spans.first(where: { $0.numberRange.location >= lineStart }) {
            return next.location.verse
        }
        return span(containing: lineStart)?.location.verse ?? spans.last?.location.verse
    }

    /// The verse and UTF-16 offset within its text, or nil when the index is not inside verse text.
    public func offsetWithinVerse(of characterIndex: Int) -> (span: VerseSpan, offset: Int)? {
        guard let span = spans.first(where: { NSLocationInRange(characterIndex, $0.textRange) }) else { return nil }
        return (span, characterIndex - span.textRange.location)
    }
}
