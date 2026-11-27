import Foundation
import ScriptureData
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// What introduces the book when the page opens on its first chapter.
public struct BookOpening: Equatable, Sendable {
    /// The catalog's short name ("John"), used wherever a chapter is named ("John 3", "JOHN 3").
    public let bookName: String
    /// The title block's title and long title.
    public let title: BookTitle

    public init(bookName: String, title: BookTitle) {
        self.bookName = bookName
        self.title = title
    }
}

/// One chapter to lay out: its verses and its section headings keyed by the verse they precede.
public struct BookChapterInput: Equatable, Sendable {
    public let location: ChapterLocation
    public let verses: [Verse]
    public let headings: [Int: [SectionHeading]]

    public init(location: ChapterLocation, verses: [Verse], headings: [Int: [SectionHeading]] = [:]) {
        self.location = location
        self.verses = verses
        self.headings = headings
    }
}

/// One chapter's place in a book layout. `range` runs from the start of the chapter's opening to
/// the start of the next chapter's (the last section ends with the string), so the sections tile
/// the string. `openingRange` holds the opening paragraphs (chapter 1's title block, or a later
/// chapter's hairline: Lectern's, beside whose text its numeral is drawn, and the other styles'
/// empty one) and is never empty: every chapter opens with a line of its own (`BookLayout.build`
/// asserts it). No span intersects it.
public struct BookSection: Equatable, Sendable {
    public let location: ChapterLocation
    public let range: NSRange
    public let openingRange: NSRange
    /// The chapter's verses, in order, with ranges in the book layout's string.
    public let spans: [VerseSpan]

    public init(location: ChapterLocation, range: NSRange, openingRange: NSRange, spans: [VerseSpan]) {
        self.location = location
        self.range = range
        self.openingRange = openingRange
        self.spans = spans
    }
}

/// What a book layout was built from. Two layouts with the same id have the same string.
public struct BookLayoutID: Hashable, Sendable {
    public let book: String
    public let translationID: String
    public let chapters: ClosedRange<Int>
    /// A hash of the typography's layout-changing inputs (`ReaderTypography.layoutHash`): the style,
    /// fonts by name and size, the paragraph metrics and the four options. Colors are left out
    /// because they resolve per appearance at draw time. Stable within a process only.
    public let typography: Int
    /// A fingerprint of what the book's text is set with besides its verses: its opening (name,
    /// title, subtitle) and section headings (`BookLayout.contentFingerprint`). The whole book's,
    /// so every chapter of the book has the same; a headings fetch that succeeds on a retry
    /// changes it. Stable within a process only.
    public let content: Int

    public init(book: String, translationID: String, chapters: ClosedRange<Int>, typography: Int, content: Int = 0) {
        self.book = book
        self.translationID = translationID
        self.chapters = chapters
        self.typography = typography
        self.content = content
    }
}

/// Consecutive chapters of one book as one attributed string (the reader's page holds one): each
/// chapter's opening in its page style (DESIGN.md section 3, Page Styles), then its text as
/// `ChapterLayout` sets it.
/// Ranges are UTF-16 and every span's `textRange` maps 1:1 onto its verse's text, as in a chapter
/// layout. `attributedString` is never mutated after construction.
public struct BookLayout: @unchecked Sendable {
    public let attributedString: NSAttributedString
    /// One per chapter, in chapter order.
    public let sections: [BookSection]
    /// Every section's spans, flattened, in string order.
    public let spans: [VerseSpan]
    public let id: BookLayoutID

    /// The layout's chapters: the reader's page has one.
    public var chapters: ClosedRange<Int> { id.chapters }

    /// The air between two chapters set in one layout (only tests set more than one): above the
    /// second and later chapters' openings, `round(2.4 × size)`. The page's first chapter has
    /// none; the reader's page holds one chapter.
    public static func openingAir(for typography: ReaderTypography) -> CGFloat {
        (2.4 * typography.bodyFont.pointSize).rounded()
    }

    /// Whether the page opens on the book's title block (it starts at chapter 1). Over the title
    /// block the running head is hidden and fades in as the block scrolls under it; a later
    /// chapter has no label of its own (Matt, 2026-11-13), so the head names it from the top and
    /// its text starts right under the head.
    public var opensWithTitleBlock: Bool { sections.first?.location.chapter == 1 }

    // MARK: Building

    /// Lays out `chapters` (consecutive, ascending, at least one; the reader passes one) as one
    /// page. The book's title block opens chapter 1 only when the page starts there; every other
    /// chapter opens on a hairline with nothing drawn (the running head names it); Lectern's
    /// numeral is drawn beside the text below its hairline (`DropNumeral`, `markDropZone`). A
    /// chapter after the page's first has `round(2.4 × size)` of air above its hairline.
    ///
    /// `content` is the id's `content`: the book-wide fingerprint `ReaderDocument` passes, the same
    /// for every chapter of the book; by default, that of `opening` and these chapters' headings.
    ///
    /// Main actor only, like `ChapterLayout.build`: it makes fonts and attributed strings, which
    /// has crashed when done concurrently. The finished layout is immutable and `Sendable`.
    @MainActor
    public static func build(chapters: [BookChapterInput], opening: BookOpening, typography: ReaderTypography,
                             content: Int? = nil) -> BookLayout {
        precondition(!chapters.isEmpty, "A book layout needs at least one chapter")
        let result = NSMutableAttributedString()
        var sections: [BookSection] = []
        let size = typography.bodyFont.pointSize
        let opensBook = chapters[0].location.chapter == 1
        // Lectern: a chapter whose numeral bears on every paragraph it has hands its follower on
        // to the next chapter's opening.
        var pendingFollower: PendingFollower?

        for (index, input) in chapters.enumerated() {
            let chapter = input.location.chapter
            let sectionStart = result.length
            let isBookOpening = index == 0 && opensBook
            // TextKit 2 drops a paragraph's space before at the start of the text, so the page's
            // first chapter has none.
            let spaceAbove = index == 0 ? 0 : openingAir(for: typography)

            let openingText = isBookOpening
                ? bookOpening(opening, typography: typography)
                : chapterOpening(chapter, bookName: opening.bookName, spaceAbove: spaceAbove, typography: typography)
            result.append(openingText)
            let openingRange = NSRange(location: sectionStart, length: result.length - sectionStart)
            assert(openingRange.length > 0, "Every page style opens a chapter with a line of its own")

            let layout = ChapterLayout.build(verses: input.verses, headings: input.headings, typography: typography)
            let text = NSMutableAttributedString(attributedString: layout.attributedString)
            var spans = layout.spans
            if typography.style == .lectern {
                // The previous chapter's numeral ran past its text: this opening follows it.
                if let follower = pendingFollower {
                    result.addAttribute(.dropZone, value: follower.zone, range: openingRange)
                }
                spans = removeVerseOneNumber(from: text, spans: spans)
                let zone = markDropZone(in: text, spans: spans, chapter: chapter, typography: typography)
                spans = zone.spans
                pendingFollower = zone.pendingFollower
            }

            let textStart = result.length
            result.append(text)
            spans = spans.map { $0.shifted(by: textStart) }
            if index < chapters.count - 1, text.length > 0 {
                // The paragraph separator before the next opening keeps the last paragraph's style.
                result.append(NSAttributedString(string: "\n", attributes: result.attributes(at: result.length - 1, effectiveRange: nil)))
            }

            sections.append(BookSection(
                location: input.location,
                range: NSRange(location: sectionStart, length: result.length - sectionStart),
                openingRange: openingRange,
                spans: spans))
        }

        let first = chapters[0]
        let id = BookLayoutID(
            book: first.location.book,
            translationID: chapters.lazy.flatMap(\.verses).first?.translationID ?? "",
            chapters: first.location.chapter...chapters[chapters.count - 1].location.chapter,
            typography: typography.layoutHash,
            content: content ?? contentFingerprint(opening: opening, headings: chapters.map { ($0.location.chapter, $0.headings) }))
        return BookLayout(
            attributedString: result.copy() as! NSAttributedString,
            sections: sections,
            spans: sections.flatMap(\.spans),
            id: id)
    }

    /// A fingerprint of `opening` and `headings` (chapter, then verse, then each heading's level and
    /// text): their count and every text, in order.
    public static func contentFingerprint(opening: BookOpening, headings: [(chapter: Int, byVerse: [Int: [SectionHeading]])]) -> Int {
        var hasher = Hasher()
        hasher.combine(opening.bookName)
        hasher.combine(opening.title.title)
        hasher.combine(opening.title.subtitle)
        var count = 0
        for (chapter, byVerse) in headings.sorted(by: { $0.chapter < $1.chapter }) {
            for (verse, list) in byVerse.sorted(by: { $0.key < $1.key }) {
                for heading in list {
                    hasher.combine(chapter)
                    hasher.combine(verse)
                    hasher.combine(heading.level)
                    hasher.combine(heading.text)
                    count += 1
                }
            }
        }
        hasher.combine(count)
        return hasher.finalize()
    }

    // MARK: Queries

    public func section(for chapter: Int) -> BookSection? {
        // Chapters are consecutive, so the index is the offset from the first; scan if they are not.
        guard let first = sections.first else { return nil }
        let index = chapter - first.location.chapter
        if sections.indices.contains(index), sections[index].location.chapter == chapter { return sections[index] }
        return sections.first { $0.location.chapter == chapter }
    }

    /// The section covering `index`; the end of the string counts as the last section's.
    public func section(containing index: Int) -> BookSection? {
        let next = Self.firstIndex(in: sections) { $0.range.location > index }
        guard next > 0 else { return nil }
        let section = sections[next - 1]
        if NSLocationInRange(index, section.range) { return section }
        return next == sections.count && index == NSMaxRange(section.range) ? section : nil
    }

    /// The span that renders `location`, including a combined verse's second number.
    public func span(for location: VerseLocation) -> VerseSpan? {
        guard let section = section(for: location.chapter), section.location.book == location.book else { return nil }
        return section.spans.first { $0.contains(verse: location.verse) }
    }

    /// The span whose number or text covers `index` (a binary search).
    public func span(containing index: Int) -> VerseSpan? {
        let next = Self.firstIndex(in: spans) { $0.fullRange.location > index }
        guard next > 0 else { return nil }
        let span = spans[next - 1]
        return NSLocationInRange(index, span.fullRange) ? span : nil
    }

    /// The verse to record as "first visible" when a line starting at `lineStart` is the topmost
    /// fully visible line, always within the line's own chapter: that section's first verse label
    /// at or after the line, else its verse containing the line, else its last verse. A line in an
    /// opening or a section heading resolves to the verse that follows it (a line in a chapter's
    /// opening is that chapter's first verse); the wrapped tail of a chapter's last verse, or the
    /// line ending the chapter, stays that last verse rather than naming the next chapter.
    public func firstVisibleVerse(fromLineStart lineStart: Int) -> VerseLocation? {
        guard let section = section(containing: lineStart) else { return nil }
        let spans = section.spans
        let next = Self.firstIndex(in: spans) { $0.numberRange.location >= lineStart }
        if next < spans.count { return spans[next].location }
        return (spans.last { NSLocationInRange(lineStart, $0.fullRange) } ?? spans.last)?.location
    }

    /// The verse and UTF-16 offset within its text, or nil when the index is not inside verse text.
    public func offsetWithinVerse(of index: Int) -> (span: VerseSpan, offset: Int)? {
        let next = Self.firstIndex(in: spans) { $0.textRange.location > index }
        guard next > 0 else { return nil }
        let span = spans[next - 1]
        guard NSLocationInRange(index, span.textRange) else { return nil }
        return (span, index - span.textRange.location)
    }

    /// The first index whose element satisfies `isAfter`, which must be false then true along the
    /// array; `elements.count` when none does.
    private static func firstIndex<T>(in elements: [T], where isAfter: (T) -> Bool) -> Int {
        var low = 0, high = elements.count
        while low < high {
            let mid = (low + high) / 2
            if isAfter(elements[mid]) { high = mid } else { low = mid + 1 }
        }
        return low
    }
}

// MARK: Openings

private extension BookLayout {
    /// One opening paragraph's look.
    struct Line {
        var text: String
        var font: PlatformFont
        var color: PlatformColor
        var kern: CGFloat = 0
        var role: ReaderRole
    }

    /// A paragraph of `runs` (sharing one paragraph style), ended by its own `"\n"`, every
    /// character tagged with its run's role. `fixedLineHeight` sets every line exactly that tall.
    static func paragraph(_ runs: [Line], alignment: NSTextAlignment, lineHeight: CGFloat, before: CGFloat, after: CGFloat,
                          fixedLineHeight: CGFloat? = nil) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineHeightMultiple = lineHeight
        if let fixedLineHeight {
            style.minimumLineHeight = fixedLineHeight
            style.maximumLineHeight = fixedLineHeight
        }
        style.paragraphSpacingBefore = before
        style.paragraphSpacing = after
        let paragraphStyle = style.copy() as! NSParagraphStyle
        let result = NSMutableAttributedString()
        for (index, run) in runs.enumerated() {
            let isLast = index == runs.count - 1
            result.append(NSAttributedString(string: isLast ? run.text + "\n" : run.text, attributes: [
                .font: run.font,
                .foregroundColor: run.color,
                .kern: run.kern,
                .paragraphStyle: paragraphStyle,
                .readerRole: ReaderRoleBox(run.role),
            ]))
        }
        return result
    }

    /// Chapter 1's opening at the top of its page: the book's title block in the style.
    static func bookOpening(_ opening: BookOpening, typography t: ReaderTypography) -> NSAttributedString {
        let size = t.bodyFont.pointSize
        func pt(_ factor: CGFloat) -> CGFloat { (size * factor).rounded() }
        let below = pt(1.2)
        let subtitle = opening.title.subtitle
        let result = NSMutableAttributedString()

        let title = Line(text: opening.title.title, font: t.titleFont, color: t.titleColor, kern: t.titleKern, role: .title)
        let label = chapterLabel(1, bookName: opening.bookName, typography: t)

        switch t.style {
        case .printed:
            result.append(paragraph([title], alignment: .center, lineHeight: 1.1, before: 0, after: subtitle == nil ? 0 : pt(0.45)))
            if let subtitle {
                result.append(paragraph([Line(text: subtitle, font: t.subtitleFont, color: t.subtitleColor, kern: t.subtitleKern, role: .subtitle)],
                                        alignment: .center, lineHeight: 1.2, before: 0, after: 0))
            }
            result.append(paragraph(label, alignment: .center, lineHeight: 1.2, before: pt(1.2), after: below))

        case .lectern:
            result.append(paragraph([title], alignment: .center, lineHeight: 1.1, before: 0, after: subtitle == nil ? 0 : pt(0.22)))
            if let subtitle {
                result.append(paragraph([Line(text: subtitle, font: t.subtitleFont, color: t.subtitleColor, kern: t.subtitleKern, role: .subtitle)],
                                        alignment: .center, lineHeight: 1.2, before: 0, after: 0))
            }
            let ornament = Line(text: "· · ·", font: resized(t.bodyFont, to: pt(0.67)), color: Palette.inkRule.platformColor, role: .ornament)
            result.append(paragraph([ornament], alignment: .center, lineHeight: 1.2, before: pt(0.9), after: pt(1.0)))
            result.append(numeral(1, before: 0, typography: t))

        case .study:
            if let subtitle {
                result.append(paragraph([Line(text: subtitle.uppercased(), font: t.subtitleFont, color: t.subtitleColor, kern: t.subtitleKern, role: .subtitle)],
                                        alignment: .natural, lineHeight: 1.2, before: 0, after: pt(0.33)))
            }
            result.append(paragraph(label, alignment: .natural, lineHeight: 1.1, before: 0, after: 0))
            // A hairline paragraph: the text controller draws the rule across the measure.
            let rule = Line(text: "\u{00A0}", font: resized(t.bodyFont, to: 1), color: Palette.inkRule.platformColor, role: .rule)
            result.append(paragraph([rule], alignment: .natural, lineHeight: 1, before: pt(1.0), after: pt(1.1)))

        case .classic:
            result.append(paragraph(label, alignment: .natural, lineHeight: 1.1, before: 0, after: subtitle == nil ? below : pt(0.22)))
            if let subtitle {
                result.append(paragraph([Line(text: subtitle, font: t.subtitleFont, color: t.subtitleColor, kern: t.subtitleKern, role: .subtitle)],
                                        alignment: .natural, lineHeight: 1.2, before: 0, after: below))
            }
        }
        return result
    }

    /// A later chapter's opening (on its own page, or after another chapter in the layout): a
    /// hairline with nothing drawn. The page carries no chapter label (Matt, 2026-11-13): the
    /// running head names the chapter. Lectern's hairline is the one its numeral is drawn below.
    static func chapterOpening(_ chapter: Int, bookName: String, spaceAbove: CGFloat, typography t: ReaderTypography) -> NSAttributedString {
        switch t.style {
        case .lectern:
            return numeral(chapter, before: spaceAbove, typography: t)
        case .printed, .study, .classic:
            let line = Line(text: "\u{2060}", font: resized(t.bodyFont, to: 1), color: t.chapterLabelColor, role: .chapterStart(chapter))
            return paragraph([line], alignment: .natural, lineHeight: 1, before: spaceAbove, after: 0, fixedLineHeight: 1)
        }
    }

    /// The label that names chapter 1 in the title block: "CHAPTER 1" in Printed, "John 1" in
    /// Study (the number in the label's tertiary ink) and Classic (Display). Lectern has none.
    static func chapterLabel(_ chapter: Int, bookName: String, typography t: ReaderTypography) -> [Line] {
        switch t.style {
        case .printed:
            return [Line(text: "CHAPTER \(chapter)", font: t.chapterLabelFont, color: t.chapterLabelColor, kern: t.chapterLabelKern, role: .chapterLabel(chapter))]
        case .lectern:
            return []
        case .study:
            return [
                Line(text: bookName + " ", font: t.titleFont, color: t.titleColor, kern: t.titleKern, role: .chapterLabel(chapter)),
                Line(text: "\(chapter)", font: t.chapterLabelFont, color: t.chapterLabelColor, role: .chapterLabel(chapter)),
            ]
        case .classic:
            return [Line(text: "\(bookName) \(chapter)", font: t.titleFont, color: t.titleColor, kern: t.titleKern, role: .chapterLabel(chapter))]
        }
    }

    /// Lectern's chapter opening: a hairline paragraph (a word joiner a point tall, role
    /// `.dropNumeral(chapter)`) with `before` of air above it (the label's air, as other styles'
    /// later chapters have). The numeral itself is drawn beside the chapter's first paragraph
    /// (`DropNumeral`); this line gives the chapter an opening of its own, so the bands, the
    /// running head, jumps to verse 1, the headings rotor and the chapter-note mark find it.
    static func numeral(_ chapter: Int, before: CGFloat, typography t: ReaderTypography) -> NSAttributedString {
        let line = Line(text: "\u{2060}", font: resized(t.bodyFont, to: 1), color: Palette.accent.platformColor, role: .dropNumeral(chapter))
        return paragraph([line], alignment: .natural, lineHeight: 1, before: before, after: 0, fixedLineHeight: 1)
    }

    /// A chapter's numeral whose zone took every paragraph of its text: the next chapter's opening
    /// is its follower.
    struct PendingFollower {
        let chapter: Int
        let notch: CGSize
        /// The chapter's last paragraph's spacing after.
        let spacingAfter: CGFloat

        var zone: DropZone {
            DropZone(chapter: chapter, part: .follower, notch: notch, spacingBelow: spacingAfter)
        }
    }

    /// Lectern: tags the paragraphs `chapter`'s numeral bears on (`DropZone`): its first paragraph
    /// (the one verse 1's text opens) and the next, up to `DropNumeral.lines` in all, which a
    /// short first paragraph or poetry can bring up beside the numeral, stopping at a section
    /// heading; then the paragraph after them, the follower. Each zone and follower paragraph sets
    /// a `DropNumeral.strut` before its verse numbers (the spans are shifted, their text
    /// unchanged) and does not hyphenate, as no paragraph outside does. When the zone takes the
    /// chapter's last paragraph, the next chapter's opening is the follower (`pendingFollower`).
    static func markDropZone(in text: NSMutableAttributedString, spans: [VerseSpan], chapter: Int,
                             typography t: ReaderTypography) -> (spans: [VerseSpan], pendingFollower: PendingFollower?) {
        guard let first = spans.first, text.length > 0 else { return (spans, nil) }
        let notch = DropNumeral.notch(chapter, typography: t)
        let string = text.string as NSString
        var paragraphs: [NSRange] = []
        var location = 0
        while location < string.length {
            let range = string.paragraphRange(for: NSRange(location: location, length: 0))
            paragraphs.append(range)
            location = NSMaxRange(range)
        }
        guard let start = paragraphs.firstIndex(where: { NSLocationInRange(first.textRange.location, $0) }) else { return (spans, nil) }
        var zone: [Int] = []
        var index = start
        while index < paragraphs.count, zone.count < DropNumeral.lines,
              text.readerRole(at: paragraphs[index].location) != .sectionHeading {
            zone.append(index)
            index += 1
        }
        let follower = index < paragraphs.count ? index : nil

        func style(at index: Int) -> NSParagraphStyle? {
            text.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
        }
        var marks: [(range: NSRange, zone: DropZone)] = zone.map { index in
            let paragraph = style(at: paragraphs[index].location)
            return (paragraphs[index], DropZone(chapter: chapter, part: index == start ? .first : .wrap, notch: notch,
                                                firstLineIndent: paragraph?.firstLineHeadIndent ?? 0, headIndent: paragraph?.headIndent ?? 0))
        }
        if let follower {
            let spacing = style(at: paragraphs[follower - 1].location)?.paragraphSpacing ?? 0
            marks.append((paragraphs[follower], DropZone(chapter: chapter, part: .follower, notch: notch, spacingBelow: spacing)))
        }
        let pending = follower == nil ? zone.last.map { last in
            PendingFollower(chapter: chapter, notch: notch, spacingAfter: style(at: paragraphs[last].location)?.paragraphSpacing ?? 0)
        } : nil

        // A strut before each verse number in those paragraphs, the last first so ranges hold.
        let strutted = spans.indices.filter { index in
            let number = spans[index].numberRange
            return number.length > 0 && marks.contains { NSLocationInRange(number.location, $0.range) }
        }
        let strutLength = (DropNumeral.strut as NSString).length
        for index in strutted.reversed() {
            let number = spans[index].numberRange
            var attributes = text.attributes(at: number.location, effectiveRange: nil)
            attributes[.font] = t.bodyFont
            attributes[.baselineOffset] = nil
            text.insert(NSAttributedString(string: DropNumeral.strut, attributes: attributes), at: number.location)
        }
        var shifted = spans
        var inserted = 0
        var next = 0
        for index in spans.indices {
            while next < strutted.count, strutted[next] <= index {
                inserted += strutLength
                next += 1
            }
            shifted[index] = spans[index].shifted(by: inserted)
        }
        for mark in marks {
            let before = strutted.filter { spans[$0].numberRange.location < mark.range.location }.count * strutLength
            let within = strutted.filter { NSLocationInRange(spans[$0].numberRange.location, mark.range) }.count * strutLength
            let range = NSRange(location: mark.range.location + before, length: mark.range.length + within)
            text.addAttribute(.dropZone, value: mark.zone, range: range)
            text.enumerateAttribute(.paragraphStyle, in: range) { value, run, _ in
                guard let style = value as? NSParagraphStyle, style.hyphenationFactor != 0 else { return }
                let unhyphenated = style.mutableCopy() as! NSMutableParagraphStyle
                unhyphenated.hyphenationFactor = 0
                text.addAttribute(.paragraphStyle, value: unhyphenated.copy(), range: run)
            }
        }
        return (shifted, pending)
    }

    /// Lectern: verse 1's number gives way to the chapter's drop numeral. Returns the
    /// spans with the number removed (verse 1's `numberRange` empty at its text's start).
    static func removeVerseOneNumber(from text: NSMutableAttributedString, spans: [VerseSpan]) -> [VerseSpan] {
        guard let first = spans.first, first.numberRange.length > 0 else { return spans }
        let removed = NSRange(location: first.numberRange.location, length: first.textRange.location - first.numberRange.location)
        text.deleteCharacters(in: removed)
        return spans.enumerated().map { index, span in
            guard index == 0 else { return span.shifted(by: -removed.length) }
            return VerseSpan(
                location: span.location, endVerse: span.endVerse, label: span.label,
                numberRange: NSRange(location: removed.location, length: 0),
                textRange: NSRange(location: span.textRange.location - removed.length, length: span.textRange.length))
        }
    }

    static func resized(_ font: PlatformFont, to size: CGFloat) -> PlatformFont {
        #if canImport(AppKit)
        NSFont(descriptor: font.fontDescriptor.withSize(size), size: size) ?? font
        #else
        UIFont(descriptor: font.fontDescriptor.withSize(size), size: size)
        #endif
    }
}

extension VerseSpan {
    func shifted(by delta: Int) -> VerseSpan {
        VerseSpan(
            location: location, endVerse: endVerse, label: label,
            numberRange: NSRange(location: numberRange.location + delta, length: numberRange.length),
            textRange: NSRange(location: textRange.location + delta, length: textRange.length))
    }
}

extension ReaderTypography {
    /// A hash of everything here that changes a book layout's string: the style, every font by
    /// name and size, the paragraph metrics, the kerns, the heading alignment and the four
    /// options. Not the headline size: only the running head, which is not on the page, is set at
    /// it now that later chapters have no label (2026-11-13). Colors are left out (they resolve per appearance), as is
    /// the measure (the container's width, not the string). Stable within a process.
    public var layoutHash: Int {
        var hasher = Hasher()
        hasher.combine(style.rawValue)
        for font in [bodyFont, verseNumberFont, titleFont, subtitleFont, chapterLabelFont, sectionHeadingFont] {
            hasher.combine(font.fontName)
            hasher.combine(font.pointSize)
        }
        for metric in [lineHeightMultiple, paragraphSpacing, verseNumberBaselineOffset, firstLineIndent,
                       indentedParagraphSpacing, poetryIndent, poetryHang, stanzaSpacing,
                       chapterLabelKern, titleKern, subtitleKern, sectionHeadingKern] {
            hasher.combine(metric)
        }
        hasher.combine(sectionHeadingAlignment.rawValue)
        hasher.combine(showsVerseNumbers)
        hasher.combine(showsSectionHeadings)
        hasher.combine(versePerLine)
        hasher.combine(justified)
        return hasher.finalize()
    }
}
