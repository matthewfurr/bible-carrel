import CoreText
import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// The typeface the reader sets the page in. Literata and Source Serif 4 ship in the package
/// (see `Fonts/README.md`); the other three come with the system.
public enum PageFace: String, CaseIterable, Sendable {
    case literata, iowanOldStyle, sourceSerif, newYork, charter

    public var title: String {
        switch self {
        case .literata: "Literata"
        case .iowanOldStyle: "Iowan Old Style"
        case .sourceSerif: "Source Serif 4"
        case .newYork: "New York"
        case .charter: "Charter"
        }
    }

    /// The faces this system can actually set: Charter drops out where it is not installed.
    public static var available: [PageFace] {
        allCases.filter { $0 != .charter || charterIsInstalled }
    }

    private static var charterIsInstalled: Bool {
        PlatformFont(name: "Charter-Roman", size: 18) != nil
    }

    // MARK: Registration

    /// Registers the bundled faces for this process. Idempotent: the work runs once, and a face
    /// that is already registered is not an error worth reporting.
    public static func registerBundledFonts() {
        _ = registration
    }

    private static let registration: Void = {
        guard let folder = Bundle.module.resourceURL?.appendingPathComponent("Fonts") else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension.lowercased() == "ttf" {
            // Fails harmlessly when the face is already registered.
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }()

    // MARK: Fonts

    /// The face at a fixed size. Weights the face does not ship snap to the nearest one it does.
    public func font(size: CGFloat, weight: PlatformFont.Weight = .regular, italic: Bool = false) -> PlatformFont {
        Self.registerBundledFonts()
        if let name = postScriptName(weight: weight, italic: italic),
           let font = PlatformFont(name: name, size: size) {
            return font
        }
        return systemSerif(size: size, weight: weight, italic: italic)
    }

    /// The face at a text style's size, scaling with Dynamic Type.
    public func swiftUIFont(_ style: Font.TextStyle, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        Self.registerBundledFonts()
        if self == .newYork {
            let font = Font.system(style, design: .serif).weight(weight)
            return italic ? font.italic() : font
        }
        guard let name = postScriptName(weight: weight.platformWeight, italic: italic) else {
            return Font.system(style, design: .serif).weight(weight)
        }
        return Font.custom(name, size: Self.baseSize(style), relativeTo: style)
    }

    // MARK: Roles beyond the page

    /// The quoted phrase on a row: italic at `.callout`, in this face.
    public func quoteFont() -> Font {
        swiftUIFont(.callout, italic: true)
    }

    /// The front page's chapter numerals: `.title3`, tabular and lining figures in every face
    /// (Iowan sets old-style figures by default). `size` is the point size, which a view scales
    /// with `@ScaledMetric(relativeTo: .title3)`; New York scales through the text style itself.
    public func numeralFont(size: CGFloat? = nil) -> Font {
        guard let font = numeralCTFont(size: size ?? Self.baseSize(.title3)) else {
            return Font.system(.title3, design: .serif).monospacedDigit()
        }
        return Font(font).monospacedDigit()
    }

    /// The Mac front page pane's chapter numerals at the reader size (spec 5.2): as `numeralFont`,
    /// but where the face cannot set lining figures the system serif keeps `size`, since the
    /// pane's cells are sized from the reader size rather than a text style.
    public func paneNumeralFont(size: CGFloat) -> Font {
        Font(paneNumeralCTFont(size: size)).monospacedDigit()
    }

    /// The font behind `paneNumeralFont(size:)`: this face's lining figures, else the system serif.
    func paneNumeralCTFont(size: CGFloat) -> CTFont {
        numeralCTFont(size: size) ?? systemSerif(size: size, weight: .regular, italic: false) as CTFont
    }

    /// The book's name at the head of the front page's pane: `.title`, semibold.
    public func displayFont() -> Font {
        swiftUIFont(.title, weight: .semibold)
    }

    /// A search row's matched word (`SearchRanker.bolded`): this face's semibold, in Literata the
    /// SemiBold files, which nothing on the page asks for (its semibold titles and headings stay
    /// Medium). Nil for New York, whose matches take the system serif's bold as before.
    public func matchFont(_ style: Font.TextStyle, italic: Bool = false) -> Font? {
        Self.registerBundledFonts()
        guard let name = matchPostScriptName(italic: italic) else { return nil }
        return Font.custom(name, size: Self.baseSize(style), relativeTo: style)
    }

    /// The platform font behind `matchFont`, at a fixed size.
    func matchPlatformFont(size: CGFloat, italic: Bool = false) -> PlatformFont? {
        Self.registerBundledFonts()
        return matchPostScriptName(italic: italic).flatMap { PlatformFont(name: $0, size: size) }
    }

    /// `text` with the runs `SearchRanker.bolded` marked strong set in `matchFont`; the rest keep
    /// the line's own font. Unchanged in New York.
    public func settingMatches(_ text: AttributedString, _ style: Font.TextStyle, italic: Bool = false) -> AttributedString {
        guard let font = matchFont(style, italic: italic) else { return text }
        var result = text
        for run in text.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            result[run.range].font = font
        }
        return result
    }

    private func matchPostScriptName(italic: Bool) -> String? {
        switch self {
        case .literata: italic ? "Literata-SemiBoldItalic" : "Literata-SemiBold"
        default: postScriptName(weight: .semibold, italic: italic)
        }
    }

    /// The platform font behind `quoteFont()` at the callout's base size.
    func quotePlatformFont() -> PlatformFont {
        font(size: Self.baseSize(.callout), italic: true)
    }

    /// The numeral font with lining, monospaced figures switched on. Nil where the face cannot
    /// set lining figures, and the caller takes the system serif, whose figures are lining and
    /// monospaced: New York, and Iowan Old Style, whose number-case feature offers old-style
    /// figures only.
    func numeralCTFont(size: CGFloat) -> CTFont? {
        guard self != .newYork else { return nil }
        let base = font(size: size) as CTFont
        let features = CTFontCopyFeatures(base) as? [[String: Any]] ?? []
        let numberCase = features.first { ($0[kCTFontFeatureTypeIdentifierKey as String] as? Int) == kNumberCaseType }
        if let numberCase {
            let selectors = numberCase[kCTFontFeatureTypeSelectorsKey as String] as? [[String: Any]] ?? []
            let offersLining = selectors.contains {
                ($0[kCTFontFeatureSelectorIdentifierKey as String] as? Int) == kUpperCaseNumbersSelector
            }
            if !offersLining { return nil }
        }
        var descriptor = CTFontCopyFontDescriptor(base)
        descriptor = CTFontDescriptorCreateCopyWithFeature(
            descriptor, kNumberCaseType as CFNumber, kUpperCaseNumbersSelector as CFNumber)
        descriptor = CTFontDescriptorCreateCopyWithFeature(
            descriptor, kNumberSpacingType as CFNumber, kMonospacedNumbersSelector as CFNumber)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    /// The face the settings resolve to: the reader's choice, else the style's own.
    static func resolved(styleRaw: String, faceRaw: String) -> PageFace {
        ReaderPreferences(
            style: PageStyle(rawValue: styleRaw) ?? .printed,
            face: PageFace(rawValue: faceRaw)).resolvedFace
    }

    private func postScriptName(weight: PlatformFont.Weight, italic: Bool) -> String? {
        switch self {
        case .literata:
            if italic { return "Literata-Italic" }
            if weight <= .light { return "Literata-Light" }
            if weight <= .regular { return "Literata-Regular" }
            return "Literata-Medium"
        case .sourceSerif:
            if italic { return "SourceSerif4-It" }
            return weight >= .semibold ? "SourceSerif4-Semibold" : "SourceSerif4-Regular"
        case .iowanOldStyle:
            let bold = weight >= .semibold
            return switch (bold, italic) {
            case (false, false): "IowanOldStyle-Roman"
            case (false, true): "IowanOldStyle-Italic"
            case (true, false): "IowanOldStyle-Bold"
            case (true, true): "IowanOldStyle-BoldItalic"
            }
        case .charter:
            let bold = weight >= .semibold
            return switch (bold, italic) {
            case (false, false): "Charter-Roman"
            case (false, true): "Charter-Italic"
            case (true, false): "Charter-Bold"
            case (true, true): "Charter-BoldItalic"
            }
        case .newYork:
            return nil
        }
    }

    private func systemSerif(size: CGFloat, weight: PlatformFont.Weight, italic: Bool) -> PlatformFont {
        let base = PlatformFont.systemFont(ofSize: size, weight: weight)
        guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
        #if canImport(AppKit)
        let descriptor = italic ? serif.withSymbolicTraits(.italic) : serif
        return NSFont(descriptor: descriptor, size: size) ?? base
        #else
        let descriptor = italic ? (serif.withSymbolicTraits(.traitItalic) ?? serif) : serif
        return UIFont(descriptor: descriptor, size: size)
        #endif
    }

    /// The point size a text style has at the default Dynamic Type setting.
    static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        #if canImport(AppKit)
        switch style {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline: 11
        case .footnote: 10
        case .caption, .caption2: 10
        @unknown default: 13
        }
        #else
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
        #endif
    }
}

extension Font.Weight {
    var platformWeight: PlatformFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}
