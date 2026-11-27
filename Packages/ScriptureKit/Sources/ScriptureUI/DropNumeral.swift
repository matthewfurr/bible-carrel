import CoreGraphics
import CoreText
import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// Lectern's drop numeral (DESIGN.md section 3, Page Styles): the chapter's number in the page
/// face's lining figures, in the accent, three body lines deep at the head of the chapter's first
/// paragraph, standing in for verse 1's number, with the paragraph's first three lines wrapping to
/// its right. Its figures rise from the first line's capital height to the third line's baseline.
///
/// The numeral is never text. `BookLayout` opens each Lectern chapter with a hairline paragraph
/// (role `.dropNumeral(n)`, a word joiner a point tall, in `openingRange`) and tags the chapter's
/// first paragraphs with a `DropZone`; the text controllers lay the text out in a
/// `DropZoneContainer` through a `DropZoneLayoutDelegate`, which cuts the notch out of the lines
/// beside the numeral, and draw the numeral themselves where `placements` puts it.
public enum DropNumeral {
    /// How many body lines the numeral is deep.
    public static let lines = 3

    /// The notch's height: three body lines.
    public static func depth(for typography: ReaderTypography) -> CGFloat {
        CGFloat(lines) * typography.bodyLineHeight
    }

    /// The air between the numeral's figures and the text beside it: half the size, as the
    /// Lectern mockup's 10 px at 18 px.
    public static func gap(for typography: ReaderTypography) -> CGFloat {
        (0.5 * typography.bodyFont.pointSize).rounded()
    }

    /// The page face (the body font's, without its old-style figures) in proportional lining
    /// figures, sized so a figure's height (the face's capital height) runs from the first line's
    /// capital height to the third line's baseline: two body lines and a capital. Proportional,
    /// because a face's default tabular figures give a "1" the width of an "8".
    public static func font(for typography: ReaderTypography) -> PlatformFont {
        let body = typography.bodyFont
        var attributes = body.fontDescriptor.fontAttributes
        attributes[.featureSettings] = nil
        let reference: CGFloat = 100
        let referenceFace = face(PlatformFontDescriptor(fontAttributes: attributes), size: reference) ?? body
        let capRatio = referenceFace.capHeight / reference
        let target = CGFloat(lines - 1) * typography.bodyLineHeight + body.capHeight
        let size = (target / max(capRatio, 0.1) * 2).rounded() / 2
        attributes[.featureSettings] = [
            [PlatformFontDescriptor.typeKey: kNumberCaseType, PlatformFontDescriptor.selectorKey: kUpperCaseNumbersSelector],
            [PlatformFontDescriptor.typeKey: kNumberSpacingType, PlatformFontDescriptor.selectorKey: kProportionalNumbersSelector],
        ]
        return face(PlatformFontDescriptor(fontAttributes: attributes), size: size) ?? body
    }

    /// The air between neighbouring figures' ink, as a fraction of the numeral's size: the
    /// figures nearly touch, as a set drop numeral's do, and never collide.
    static let figureGap: CGFloat = 0.04

    private static func face(_ descriptor: PlatformFontDescriptor, size: CGFloat) -> PlatformFont? {
        #if canImport(AppKit)
        NSFont(descriptor: descriptor.withSize(size), size: size)
        #else
        UIFont(descriptor: descriptor.withSize(size), size: size)
        #endif
    }

    /// The chapter's number as one line of CoreText, drawn in the context's fill color, tracked
    /// optically: each figure is kerned so the ink gap to the next is `figureGap` of the size,
    /// whatever the figures' side bearings (Iowan's "1" stands in wide ones).
    static func line(_ chapter: Int, font: PlatformFont) -> CTLine {
        let digits = Array("\(chapter)")
        let text = NSMutableAttributedString(string: String(digits), attributes: [
            .font: font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ])
        let target = figureGap * font.pointSize
        var location = 0
        for (index, digit) in digits.enumerated() {
            let length = String(digit).utf16.count
            if index + 1 < digits.count {
                let left = figure(digit, font: font), right = figure(digits[index + 1], font: font)
                let gap = (left.advance - left.ink.maxX) + right.ink.minX
                text.addAttribute(.kern, value: target - gap, range: NSRange(location: location, length: length))
            }
            location += length
        }
        return CTLineCreateWithAttributedString(text)
    }

    /// One figure set alone in `font`: its advance and its ink from its origin.
    private static func figure(_ digit: Character, font: PlatformFont) -> (advance: CGFloat, ink: CGRect) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(digit), attributes: [.font: font]))
        return (CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)), CTLineGetBoundsWithOptions(line, .useGlyphPathBounds))
    }

    /// The figures' ink, from the line's origin on its baseline (y up, CoreText's).
    static func ink(of line: CTLine) -> CGRect {
        CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    }

    /// The notch the numeral of `chapter` cuts from the first lines: its figures' width and the
    /// gap, three body lines deep.
    static func notch(_ chapter: Int, typography: ReaderTypography) -> CGSize {
        let ink = ink(of: line(chapter, font: font(for: typography)))
        return CGSize(width: ceil(ink.width + gap(for: typography)), height: depth(for: typography))
    }

    /// Where a chapter's numeral is drawn: `origin` is the line's origin on its baseline and `ink`
    /// the figures' rect, both in text-container coordinates (y down).
    struct Placement: Equatable {
        let chapter: Int
        let origin: CGPoint
        let ink: CGRect
    }

    /// Every Lectern chapter's numeral in `layout`, from the laid-out first line of each chapter's
    /// first paragraph: flush with the column's leading edge, its baseline on the third line's.
    /// Empty for the other styles.
    @MainActor
    static func placements(in layout: BookLayout, typography: ReaderTypography, layoutManager: NSTextLayoutManager,
                           contentStorage: NSTextContentStorage) -> [Placement] {
        guard typography.style == .lectern else { return [] }
        let font = font(for: typography)
        let documentStart = contentStorage.documentRange.location
        return layout.sections.compactMap { section -> Placement? in
            guard let first = section.spans.first,
                  let location = contentStorage.location(documentStart, offsetBy: first.textRange.location),
                  let fragment = layoutManager.textLayoutFragment(for: location),
                  let line = fragment.textLineFragments.first
            else { return nil }
            let frame = fragment.layoutFragmentFrame
            // On the third line's baseline, at the pitch TextKit sets the zone's lines.
            let baseline = frame.minY + line.typographicBounds.minY + line.glyphOrigin.y
                + CGFloat(lines - 1) * line.typographicBounds.height
            let ink = Self.ink(of: Self.line(section.location.chapter, font: font))
            let origin = CGPoint(x: -ink.minX, y: baseline)
            return Placement(chapter: section.location.chapter, origin: origin,
                             ink: CGRect(x: 0, y: baseline - ink.maxY, width: ink.width, height: ink.height))
        }
    }

    /// Draws `chapter`'s numeral with its line's origin at `origin` in a flipped (y down) context,
    /// in `color`.
    static func draw(_ chapter: Int, font: PlatformFont, at origin: CGPoint, color: CGColor, in context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = origin
        context.setFillColor(color)
        CTLineDraw(line(chapter, font: font), context)
        context.restoreGState()
    }

    /// The zero-width strut `BookLayout` sets before each verse number beside the numeral (and in
    /// the follower): a zero-width space, keeping the line break the space before the number
    /// allowed, then a word joiner, holding the strut to the number. Beside the numeral TextKit 2
    /// on macOS takes a line's height from its first character, so a line starting with a small
    /// raised number would come out short; the joiner, in the body font, starts that line instead.
    /// (A word joiner alone would glue the number to the word before it, moving line breaks.)
    /// Neither character is in any span, so copying, highlights and search never see them.
    static let strut = "\u{200B}\u{2060}"

    /// What VoiceOver reads for a chapter's numeral.
    static func accessibilityLabel(_ chapter: Int) -> String {
        "Chapter \(chapter)"
    }
}

// MARK: - The notch

extension NSAttributedString.Key {
    /// A `DropZone` on each paragraph of a Lectern chapter's opening that the numeral bears on.
    static let dropZone = NSAttributedString.Key("DropZone")
}

/// A paragraph's part in a chapter's drop numeral, on all of its characters (`.dropZone`).
final class DropZone: NSObject {
    enum Part: Hashable {
        /// The chapter's first paragraph, beside which the numeral's top sits.
        case first
        /// A later paragraph that can still start beside the numeral (a short first paragraph,
        /// poetry): its lines beside the numeral wrap like the first's.
        case wrap
        /// The paragraph after the zone (a section heading, the next paragraph, the next chapter's
        /// opening): it starts no higher than it would after three full lines, so it never meets
        /// the numeral.
        case follower
    }

    let chapter: Int
    let part: Part
    /// The notch, from the column's leading edge: the numeral's width and gap, three lines deep.
    let notch: CGSize
    /// A follower's air below the notch: the previous paragraph's spacing after, as though that
    /// paragraph ended there. (TextKit adds the follower's own spacing before below the line rect
    /// the container returns.)
    let spacingBelow: CGFloat
    /// The paragraph's own first-line and wrapped-line indents (`NSParagraphStyle`'s
    /// `firstLineHeadIndent` and `headIndent`). Beside the numeral every paragraph's first line
    /// starts at the notch's edge, whatever its indent, and a wrapped line keeps only its hang
    /// past it, so all the lines there share one edge.
    let firstLineIndent: CGFloat
    let headIndent: CGFloat

    init(chapter: Int, part: Part, notch: CGSize, spacingBelow: CGFloat = 0, firstLineIndent: CGFloat = 0, headIndent: CGFloat = 0) {
        self.chapter = chapter
        self.part = part
        self.notch = notch
        self.spacingBelow = spacingBelow
        self.firstLineIndent = firstLineIndent
        self.headIndent = headIndent
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? DropZone else { return false }
        return other.chapter == chapter && other.part == part && other.notch == notch && other.spacingBelow == spacingBelow
            && other.firstLineIndent == firstLineIndent && other.headIndent == headIndent
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(chapter)
        hasher.combine(part)
        return hasher.finalize()
    }
}

/// The text container of a book scroll. It is a plain rectangle except while a `DropZone`
/// paragraph lays out: then it is non-rectangular (TextKit 2 asks each paragraph's container
/// afresh) and cuts the numeral's notch from the lines beside it, or holds a follower below it.
///
/// TextKit 2 reads a layout fragment's `leadingPadding` at the start of the fragment's layout,
/// before it asks the container whether it is a simple rectangle (measured on macOS 26 and
/// iOS 27); `DropZoneFragment` tells the container which zone is laying out there. Outside a
/// zone the container is a simple rectangle, as a plain `NSTextContainer` is, so every other page
/// and every other paragraph lays out as before.
///
/// The rects TextKit proposes are in the laying-out fragment's own coordinates (its first line at
/// 0, whatever its spacing before), and that fragment's frame is not set until it has laid out.
/// So each zone paragraph learns how far below the notch's top it starts from the fragments above
/// it, which have laid out: the chapter's first zone fragment (the notch's top, and the line pitch
/// beside it) and the fragment just before it (where this one starts). Both are read as they are
/// now, never cached, so a paragraph laid out again alone still finds its place.
final class DropZoneContainer: NSTextContainer {
    /// The zone paragraph laying out now.
    private struct Current {
        let zone: DropZone
        /// The body line's pitch beside the numeral; nil until the first paragraph's first line.
        var pitch: CGFloat?
        /// How far below the notch's top this fragment starts (its spacing before aside).
        let offset: CGFloat
        /// Where this fragment's text starts and ends in the document: a rect proposed at its
        /// start is its first line; one at or past its end is TextKit's look at the next
        /// paragraph's start, and is left alone.
        let start: Int
        let end: Int
        /// The first rect's top: the fragment's own top, in whatever coordinates TextKit proposes.
        var base: CGFloat?
    }

    private var current: Current?
    /// Each chapter's first zone fragment, for its later paragraphs' notch.
    private let firsts = NSMapTable<NSNumber, DropZoneFragment>.strongToWeakObjects()

    /// Called by a fragment as its layout begins.
    fileprivate func begin(_ fragment: DropZoneFragment) {
        current = nil
        guard let zone = fragment.zone, let manager = fragment.textLayoutManager, let content = manager.textContentManager else { return }
        let start = content.offset(from: content.documentRange.location, to: fragment.rangeInElement.location)
        let end = content.offset(from: content.documentRange.location, to: fragment.rangeInElement.endLocation)
        let key = NSNumber(value: zone.chapter)
        if zone.part == .first {
            firsts.setObject(fragment, forKey: key)
            current = Current(zone: zone, pitch: nil, offset: 0, start: start, end: end)
            return
        }
        // A later paragraph whose chapter's first has not laid out (it always does, top down) is
        // left as it is.
        guard let first = firsts.object(forKey: key), first !== fragment, first.state == .layoutAvailable,
              let line = first.textLineFragments.first,
              let previous = Self.fragment(before: fragment, in: manager), previous.state == .layoutAvailable
        else { return }
        let top = first.layoutFragmentFrame.minY + line.typographicBounds.minY
        current = Current(zone: zone, pitch: line.typographicBounds.height, offset: previous.layoutFragmentFrame.maxY - top,
                          start: start, end: end)
    }

    /// The laid-out fragment just above `fragment`, found without laying anything out.
    private static func fragment(before fragment: NSTextLayoutFragment, in manager: NSTextLayoutManager) -> NSTextLayoutFragment? {
        var previous: NSTextLayoutFragment?
        let start = fragment.rangeInElement.location
        manager.enumerateTextLayoutFragments(from: start, options: [.reverse]) { candidate in
            guard candidate.rangeInElement.location.compare(start) == .orderedAscending else { return true }
            previous = candidate
            return false
        }
        return previous
    }

    /// Not `super`'s answer outside a zone: `NSTextContainer` answers false for any subclass that
    /// overrides `lineFragmentRect(forProposedRect:…)`, which would send every paragraph down
    /// TextKit's non-rectangular path and change how it sets their lines.
    override var isSimpleRectangularTextContainer: Bool {
        current == nil && exclusionPaths.isEmpty
    }

    override func lineFragmentRect(forProposedRect proposedRect: CGRect, at characterIndex: Int, writingDirection baseWritingDirection: NSWritingDirection,
                                   remaining remainingRect: UnsafeMutablePointer<CGRect>?) -> CGRect {
        var rect = super.lineFragmentRect(forProposedRect: proposedRect, at: characterIndex, writingDirection: baseWritingDirection,
                                          remaining: remainingRect)
        guard var layout = current, characterIndex < layout.end, !rect.isEmpty else { return rect }
        if layout.base == nil {
            layout.base = proposedRect.minY
            // The chapter's first line: its height is the pitch beside the numeral.
            if layout.pitch == nil {
                layout.pitch = proposedRect.height > 1 ? proposedRect.height : layout.zone.notch.height / CGFloat(DropNumeral.lines)
            }
            current = layout
        }
        guard let base = layout.base, let pitch = layout.pitch else { return rect }
        // This line's top below the notch's top, and the notch's depth.
        let y = layout.offset + proposedRect.minY - base
        let depth = CGFloat(DropNumeral.lines) * pitch
        switch layout.zone.part {
        case .first, .wrap:
            // A line whose top is beside the numeral steps right of it, to the notch's edge.
            // TextKit sets the paragraph's indent inside the rect returned (the rects proposed
            // start at 0), so the shift takes the first line's indent back out, and a wrapped
            // line keeps only its hang past the first line's start.
            guard y < depth - 0.5 else { return rect }
            let zone = layout.zone
            let indent = characterIndex == layout.start ? zone.firstLineIndent : min(zone.headIndent, zone.firstLineIndent)
            let shift = min(max(0, zone.notch.width - indent), max(0, rect.width - 1))
            rect.origin.x += shift
            rect.size.width -= shift
        case .follower:
            // No higher than after a paragraph ending at the numeral's foot.
            let lowest = depth + layout.zone.spacingBelow
            if y < lowest - 0.5 { rect.origin.y += lowest - y }
        }
        return rect
    }
}

/// Every paragraph's layout fragment in a Lectern book scroll: it tells the `DropZoneContainer`
/// when its layout begins, with its zone (nil outside one), and otherwise lays out as TextKit's own.
final class DropZoneFragment: NSTextLayoutFragment {
    let zone: DropZone?
    private weak var container: DropZoneContainer?

    init(textElement: NSTextElement, range: NSTextRange?, zone: DropZone?, container: DropZoneContainer?) {
        self.zone = zone
        self.container = container
        super.init(textElement: textElement, range: range)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var leadingPadding: CGFloat {
        container?.begin(self)
        return super.leadingPadding
    }
}

/// Hands TextKit a `DropZoneFragment` for every paragraph, carrying the paragraph's `DropZone`.
/// Set as the layout manager's delegate only while a Lectern layout is shown.
final class DropZoneLayoutDelegate: NSObject, NSTextLayoutManagerDelegate {
    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: any NSTextLocation,
                           in textElement: NSTextElement) -> NSTextLayoutFragment {
        var zone: DropZone?
        if let paragraph = textElement as? NSTextParagraph, paragraph.attributedString.length > 0 {
            zone = paragraph.attributedString.attribute(.dropZone, at: 0, effectiveRange: nil) as? DropZone
        }
        return DropZoneFragment(textElement: textElement, range: textElement.elementRange, zone: zone,
                                container: textLayoutManager.textContainer as? DropZoneContainer)
    }
}
