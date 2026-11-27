import Foundation
#if canImport(AppKit)
import AppKit
public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor
#endif

/// Fonts, colours and spacing used when laying out a chapter.
///
/// Make typographies on the main actor: `styled(_:)` and `default` are `@MainActor` because they
/// create AppKit/UIKit fonts and colors (and register the bundled faces on first use), and doing
/// that concurrently from several threads has crashed the test run. `@unchecked Sendable` covers
/// only handing a finished value elsewhere: its `NSFont`/`NSColor` (and UIKit counterparts) are
/// immutable once made, though the SDK does not mark them `Sendable`.
public struct ReaderTypography: Equatable, @unchecked Sendable {
    public var bodyFont: PlatformFont
    public var verseNumberFont: PlatformFont
    public var verseNumberColor: PlatformColor
    public var textColor: PlatformColor
    public var lineHeightMultiple: CGFloat
    public var paragraphSpacing: CGFloat
    public var verseNumberBaselineOffset: CGFloat
    /// The text column's maximum width: a line of 65 to 75 characters at the body size.
    public var measure: CGFloat
    /// A prose paragraph's first-line indent: 1.5 × the size.
    public var firstLineIndent: CGFloat
    /// Space after an indented prose paragraph (the indent carries the break): 0.3 × the size.
    public var indentedParagraphSpacing: CGFloat
    /// Where every poetry line starts: 1 × the size.
    public var poetryIndent: CGFloat
    /// How much further a wrapped poetry line tucks in: 1.5 × the size, so `headIndent` is
    /// `poetryIndent + poetryHang`.
    public var poetryHang: CGFloat
    /// Air after the last line of a stanza: 0.5 × the size.
    public var stanzaSpacing: CGFloat

    /// The paragraph metrics default to the body font's point size,
    /// the same derivation `styled(_:)` uses.
    public init(
        bodyFont: PlatformFont,
        verseNumberFont: PlatformFont,
        verseNumberColor: PlatformColor,
        textColor: PlatformColor,
        lineHeightMultiple: CGFloat,
        paragraphSpacing: CGFloat,
        verseNumberBaselineOffset: CGFloat,
        measure: CGFloat = 640,
        firstLineIndent: CGFloat? = nil,
        indentedParagraphSpacing: CGFloat? = nil,
        poetryIndent: CGFloat? = nil,
        poetryHang: CGFloat? = nil,
        stanzaSpacing: CGFloat? = nil
    ) {
        let size = bodyFont.pointSize
        self.bodyFont = bodyFont
        self.verseNumberFont = verseNumberFont
        self.verseNumberColor = verseNumberColor
        self.textColor = textColor
        self.lineHeightMultiple = lineHeightMultiple
        self.paragraphSpacing = paragraphSpacing
        self.verseNumberBaselineOffset = verseNumberBaselineOffset
        self.measure = measure
        self.firstLineIndent = firstLineIndent ?? (size * 1.5).rounded()
        self.indentedParagraphSpacing = indentedParagraphSpacing ?? (size * 0.3).rounded()
        self.poetryIndent = poetryIndent ?? size
        self.poetryHang = poetryHang ?? (size * 1.5).rounded()
        self.stanzaSpacing = stanzaSpacing ?? (size * 0.5).rounded()
    }

    // MARK: Page style

    public var style: PageStyle = .printed
    public var titleFont: PlatformFont = .systemFont(ofSize: 44)
    public var subtitleFont: PlatformFont = .systemFont(ofSize: 16)
    public var chapterLabelFont: PlatformFont = .systemFont(ofSize: 11)
    public var sectionHeadingFont: PlatformFont = .systemFont(ofSize: 17)
    public var titleColor: PlatformColor = Palette.inkPrimary.platformColor
    public var subtitleColor: PlatformColor = Palette.inkSecondary.platformColor
    public var chapterLabelColor: PlatformColor = Palette.inkSecondary.platformColor
    public var sectionHeadingColor: PlatformColor = Palette.inkSecondary.platformColor
    /// Tracking in points: the chapter label's, the title's and the section headings'.
    public var chapterLabelKern: CGFloat = 0
    public var titleKern: CGFloat = 0
    public var subtitleKern: CGFloat = 0
    public var sectionHeadingKern: CGFloat = 0
    public var sectionHeadingAlignment: NSTextAlignment = .left
    /// The verse number's color on a highlight, where the style's own would not hold 4.5:1;
    /// nil keeps `verseNumberColor`.
    public var verseNumberColorOnMark: PlatformColor?
    public var showsVerseNumbers = true
    public var showsSectionHeadings = true
    public var versePerLine = false
    public var justified = false
    /// The Mac's pinned running head, in the style's chapter-label voice (spec 3.2). Not part of
    /// the layout: it is drawn over the text, never in it.
    public var runningHeadFont: PlatformFont = .systemFont(ofSize: 11)
    public var runningHeadColor: PlatformColor = Palette.inkSecondary.platformColor
    /// Tracking in points.
    public var runningHeadKern: CGFloat = 0
    /// Printed and Lectern centre the head over the measure; Study and Classic set it flush with the text.
    public var runningHeadIsCentred = true
    /// The system's headline size when the typography was made: Classic's later chapter labels and
    /// running head. Captured, never read live, so a Dynamic Type change cannot make the same
    /// typography hash differently from the layout it built; the apps make a new typography when
    /// the size category changes.
    public var headlineSize: CGFloat = ReaderTypography.systemHeadlineSize

    @MainActor public static let `default` = ReaderTypography.styled(.default)

    /// One line of body text: the body font's line height times the line-spacing multiple. The
    /// readers measure how far a jump has been scrolled from in these.
    public var bodyLineHeight: CGFloat {
        (bodyFont.ascender - bodyFont.descender + bodyFont.leading) * lineHeightMultiple
    }

    /// Bounds on the measure for sizes outside the settings range; 14 to 24 pt fall inside it.
    public static let measureRange: ClosedRange<CGFloat> = 420...1150

    /// The column's measure at a size: 640 pt at 18, in proportion, times the column width setting, so a
    /// line holds about 70 characters. The Mac's Library pages take it for their text column too.
    public nonisolated static func measure(size: CGFloat, columnWidth: ColumnWidthChoice) -> CGFloat {
        (size * 640 / 18 * columnWidth.multiplier).rounded()
    }

    /// Everything that should grow with the body: verse numbers at 0.58 of the size raised by
    /// 0.39 of it, paragraph spacing at 0.78 of it, and a measure proportional to the size (640 at
    /// 18 pt), so the line keeps about 70 characters from 14 to 24 pt. The column is never wider
    /// than the window allows, so the measure is a maximum. The printed page's shapes follow it
    /// too: a 1.5 × size first-line indent with 0.3 × size after an indented paragraph, poetry
    /// lines at 1 × size hanging a further 1.5 × size, and 0.5 × size of air after a stanza.
    /// Ink is the palette's.
    ///
    /// The page style adds the book title, subtitle, chapter label and section headings, each
    /// derived from the size and rounded to the nearest point (DESIGN.md section 3, Page Styles).
    /// `headlineSize` is the system's headline size to build with (the current one by default;
    /// the phone passes its Dynamic Type size's). Main actor only (see the type's comment).
    @MainActor
    public static func styled(_ prefs: ReaderPreferences, headlineSize: CGFloat = ReaderTypography.systemHeadlineSize) -> ReaderTypography {
        let size = CGFloat(ReaderSettings.clampedFontSize(prefs.fontSize))
        let face = prefs.resolvedFace
        func pt(_ factor: CGFloat) -> CGFloat { (size * factor).rounded() }
        func halfPt(_ factor: CGFloat) -> CGFloat { (size * factor * 2).rounded() / 2 }
        func sans(_ pointSize: CGFloat, _ weight: PlatformFont.Weight) -> PlatformFont {
            .systemFont(ofSize: pointSize, weight: weight)
        }

        let secondary = Palette.inkSecondary.platformColor
        let primary = Palette.inkPrimary.platformColor
        let measure = Self.measure(size: size, columnWidth: prefs.columnWidth)

        var body = face.font(size: size)
        var number = sans(halfPt(0.58), .medium)
        var numberColor = secondary
        var numberOnMark: PlatformColor?
        var baselineOffset = (size * 0.39).rounded()

        var title = face.font(size: pt(2.45), weight: .light)
        var titleKern: CGFloat = 0
        var subtitle = face.font(size: pt(0.9), italic: true)
        var subtitleKern: CGFloat = 0
        var label = sans(pt(0.6), .semibold)
        var labelColor = secondary
        var labelKern: CGFloat = 0
        var heading = face.font(size: pt(0.94), italic: true)
        var headingColor = secondary
        var headingKern: CGFloat = 0
        var headingAlignment = NSTextAlignment.left

        switch prefs.style {
        case .printed:
            numberColor = Palette.inkVerse.platformColor
            labelColor = Palette.inkVerse.platformColor
            labelKern = 0.22 * label.pointSize
        case .lectern:
            body = body.withFeatures(numberCase: .oldStyle)
            title = face.font(size: pt(1.65)).withFeatures(smallCaps: true)
            titleKern = 0.16 * title.pointSize
            numberOnMark = primary
            heading = face.font(size: pt(0.94)).withFeatures(smallCaps: true)
            headingKern = 0.08 * heading.pointSize
            headingAlignment = .center
            number = face.font(size: halfPt(0.62)).withFeatures(numberCase: .oldStyle)
            label = face.font(size: pt(0.6), italic: true)
        case .study:
            title = face.font(size: pt(2.1), weight: .semibold)
            labelColor = Palette.inkTertiary.platformColor
            label = face.font(size: pt(2.1), weight: .semibold)
            subtitle = sans(pt(0.6), .semibold)
            subtitleKern = 0.14 * subtitle.pointSize
            heading = sans(pt(0.83), .semibold)
            headingColor = primary
            number = sans(halfPt(0.6), .bold)
            numberColor = Palette.accent.platformColor
            numberOnMark = primary
            baselineOffset = (size * 0.12).rounded()
        case .classic:
            title = face.font(size: pt(1.55), weight: .semibold)
            heading = face.font(size: pt(0.94), weight: .semibold)
            headingColor = primary
            numberOnMark = primary
        }

        var result = ReaderTypography(
            bodyFont: body,
            verseNumberFont: number,
            verseNumberColor: numberColor,
            textColor: primary,
            lineHeightMultiple: prefs.lineSpacing.lineHeightMultiple,
            paragraphSpacing: (size * 0.78).rounded(),
            verseNumberBaselineOffset: baselineOffset,
            measure: min(max(measure, measureRange.lowerBound), measureRange.upperBound),
            firstLineIndent: (size * 1.5).rounded(),
            indentedParagraphSpacing: (size * 0.3).rounded(),
            poetryIndent: size,
            poetryHang: (size * 1.5).rounded(),
            stanzaSpacing: (size * 0.5).rounded())
        result.style = prefs.style
        result.titleFont = title
        result.subtitleFont = subtitle
        result.chapterLabelFont = label
        result.sectionHeadingFont = heading
        result.titleColor = primary
        result.subtitleColor = secondary
        result.subtitleKern = subtitleKern
        result.chapterLabelColor = labelColor
        result.sectionHeadingColor = headingColor
        result.chapterLabelKern = labelKern
        result.titleKern = titleKern
        result.sectionHeadingKern = headingKern
        result.sectionHeadingAlignment = headingAlignment
        result.verseNumberColorOnMark = numberOnMark
        result.showsVerseNumbers = prefs.showsVerseNumbers
        result.showsSectionHeadings = prefs.showsSectionHeadings
        result.versePerLine = prefs.layout == .versePerLine
        result.justified = prefs.justified
        result.headlineSize = headlineSize
        // The running head in each style's label voice: Printed's spaced label, Lectern's small
        // capitals (it has no label in the text), Study's uppercase label, Classic's later-chapter
        // "John 3" at the headline size.
        switch prefs.style {
        case .printed:
            result.runningHeadFont = label
            result.runningHeadColor = labelColor
            result.runningHeadKern = labelKern
            result.runningHeadIsCentred = true
        case .lectern:
            let head = face.font(size: pt(0.94)).withFeatures(smallCaps: true)
            result.runningHeadFont = head
            result.runningHeadColor = secondary
            result.runningHeadKern = 0.16 * head.pointSize
            result.runningHeadIsCentred = true
        case .study:
            result.runningHeadFont = subtitle
            result.runningHeadColor = secondary
            result.runningHeadKern = subtitleKern
            result.runningHeadIsCentred = false
        case .classic:
            result.runningHeadFont = face.font(size: headlineSize, weight: .semibold)
            result.runningHeadColor = primary
            result.runningHeadKern = 0
            result.runningHeadIsCentred = false
        }
        return result
    }

    /// The system's headline size now, at the app's current content size category.
    public static var systemHeadlineSize: CGFloat {
        PlatformFont.preferredFont(forTextStyle: .headline).pointSize
    }

    #if canImport(UIKit)
    /// The headline size at `category`: the phone's typography is rebuilt with it when the
    /// reader's Dynamic Type size changes.
    public static func headlineSize(for category: UIContentSizeCategory) -> CGFloat {
        UIFont.preferredFont(forTextStyle: .headline, compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
    }
    #endif

    /// The system serif design (New York), falling back to the system font.
    public static func serifFont(size: CGFloat) -> PlatformFont {
        #if canImport(AppKit)
        let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif)
        return descriptor.flatMap { NSFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size)
        #else
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.serif)
        return descriptor.map { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size)
        #endif
    }
}

// MARK: OpenType features

enum NumberCase {
    case oldStyle
    /// Lining (upper-case) figures, for a face whose figures are otherwise old-style.
    case lining
}

extension PlatformFont {
    /// The same face with small capitals (lowercase to small caps) and/or old-style or lining
    /// figures. A face that lacks the feature is returned as it was.
    func withFeatures(smallCaps: Bool = false, numberCase: NumberCase? = nil) -> PlatformFont {
        var settings: [[PlatformFontDescriptor.FeatureKey: Int]] = []
        if smallCaps {
            settings.append([PlatformFontDescriptor.typeKey: kLowerCaseType, PlatformFontDescriptor.selectorKey: kLowerCaseSmallCapsSelector])
        }
        switch numberCase {
        case .oldStyle:
            settings.append([PlatformFontDescriptor.typeKey: kNumberCaseType, PlatformFontDescriptor.selectorKey: kLowerCaseNumbersSelector])
        case .lining:
            settings.append([PlatformFontDescriptor.typeKey: kNumberCaseType, PlatformFontDescriptor.selectorKey: kUpperCaseNumbersSelector])
        case nil:
            break
        }
        guard !settings.isEmpty else { return self }
        let descriptor = fontDescriptor.addingAttributes([.featureSettings: settings])
        #if canImport(AppKit)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
        #else
        return UIFont(descriptor: descriptor, size: pointSize)
        #endif
    }
}

#if canImport(AppKit)
typealias PlatformFontDescriptor = NSFontDescriptor
#else
typealias PlatformFontDescriptor = UIFontDescriptor
#endif

extension PlatformFontDescriptor {
    /// The feature type key: AppKit's `typeIdentifier`, UIKit's `type`. (UIKit's older Swift names
    /// are crossed: its `typeIdentifier` is the selector key and `featureIdentifier` the type key,
    /// so a setting made with them names no feature and the font drops it.)
    static var typeKey: FeatureKey {
        #if canImport(AppKit)
        .typeIdentifier
        #else
        .type
        #endif
    }

    /// The feature selector key: AppKit's `selectorIdentifier`, UIKit's `selector`.
    static var selectorKey: FeatureKey {
        #if canImport(AppKit)
        .selectorIdentifier
        #else
        .selector
        #endif
    }
}
