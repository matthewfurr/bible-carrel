import CoreText
import SwiftUI
import Testing

@testable import ScriptureUI

#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

@MainActor
@Suite struct PageFaceTests {
    private func isItalic(_ font: PlatformFont) -> Bool {
        #if canImport(AppKit)
        font.fontDescriptor.symbolicTraits.contains(.italic)
        #else
        font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        #endif
    }

    @Test func bundledFacesResolveToTheirFamilies() {
        PageFace.registerBundledFonts()
        #expect(PageFace.literata.font(size: 18).familyName == "Literata")
        #expect(PageFace.sourceSerif.font(size: 18, weight: .semibold).familyName == "Source Serif 4")
        #expect(PageFace.literata.font(size: 44, weight: .light).fontName.contains("Light"))
        #expect(isItalic(PageFace.literata.font(size: 18, italic: true)))
        #expect(isItalic(PageFace.sourceSerif.font(size: 18, italic: true)))
        // Each shipped file resolves by its own PostScript name, never the system fallback.
        #expect(PageFace.literata.font(size: 18, italic: true).fontName == "Literata-Italic")
        #expect(PageFace.literata.font(size: 18, weight: .medium).fontName == "Literata-Medium")
        #expect(PageFace.literata.font(size: 18).fontName == "Literata-Regular")
        #expect(PageFace.sourceSerif.font(size: 18).fontName == "SourceSerif4-Regular")
        #expect(PageFace.sourceSerif.font(size: 18, weight: .semibold).fontName == "SourceSerif4-Semibold")
        #expect(PageFace.sourceSerif.font(size: 18, italic: true).fontName == "SourceSerif4-It")
    }

    /// A search row sets a matched word in the face's semibold; the page's own semibold asks (the
    /// titles, headings, running head and shelf) keep Literata Medium, as before the SemiBold files.
    @Test func matchedWordsTakeTheSemiboldWhileThePageKeepsMedium() {
        PageFace.registerBundledFonts()
        #expect(PageFace.literata.matchPlatformFont(size: 18)?.fontName == "Literata-SemiBold")
        #expect(PageFace.literata.matchPlatformFont(size: 18, italic: true)?.fontName == "Literata-SemiBoldItalic")
        #expect(PageFace.literata.font(size: 18, weight: .semibold).fontName == "Literata-Medium")
        #expect(PageFace.literata.font(size: 18, weight: .bold).fontName == "Literata-Medium")
        #expect(PageFace.literata.font(size: 18, weight: .semibold, italic: true).fontName == "Literata-Italic")
        #expect(PageFace.sourceSerif.matchPlatformFont(size: 18)?.fontName == "SourceSerif4-Semibold")
        #expect(PageFace.sourceSerif.matchPlatformFont(size: 18, italic: true)?.fontName == "SourceSerif4-It")  // no semibold italic is bundled
        #expect(PageFace.iowanOldStyle.matchPlatformFont(size: 18)?.fontName == "IowanOldStyle-Bold")
        #expect(PageFace.iowanOldStyle.matchPlatformFont(size: 18, italic: true)?.fontName == "IowanOldStyle-BoldItalic")
        #expect(PageFace.newYork.matchPlatformFont(size: 18) == nil)                     // the system's bold, as before
    }

    @Test func matchesAreSetInTheMatchFaceAndTheRestIsLeftToTheLine() {
        let text = SearchRanker.bolded("Abide in me, and I in you.", query: "abide")
        let set = PageFace.literata.settingMatches(text, .callout)
        let fonted = set.runs.filter { $0.font != nil }.map { String(set[$0.range].characters) }
        #expect(fonted == ["Abide"])
        #expect(set.runs.allSatisfy { ($0.font != nil) == ($0.inlinePresentationIntent == .stronglyEmphasized) })
        #expect(PageFace.newYork.settingMatches(text, .callout) == text)
        #expect(String(set.characters) == String(text.characters))
    }

    @Test func systemFacesResolve() {
        #expect(PageFace.iowanOldStyle.font(size: 18).familyName == "Iowan Old Style")
    }

    @Test func registeringTwiceIsHarmless() {
        PageFace.registerBundledFonts()
        PageFace.registerBundledFonts()
    }

    @Test func baseSizesMatchTheSystemTextStyles() {
        let styles: [(Font.TextStyle, PlatformFont.TextStyle)] = [
            (.largeTitle, .largeTitle), (.title, .title1), (.title2, .title2), (.title3, .title3),
            (.headline, .headline), (.subheadline, .subheadline), (.body, .body),
            (.callout, .callout), (.footnote, .footnote), (.caption, .caption1), (.caption2, .caption2),
        ]
        for (swiftUI, platform) in styles {
            #if canImport(AppKit)
            let system = NSFont.preferredFont(forTextStyle: platform).pointSize
            #else
            let system = UIFont.preferredFont(
                forTextStyle: platform,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
            #endif
            #expect(PageFace.baseSize(swiftUI) == system, "\(swiftUI)")
        }
    }

    @Test func titlesAndAvailability() {
        #expect(PageFace.sourceSerif.title == "Source Serif 4")
        #expect(PageFace.available.contains(.literata))
        #expect(PageFace.available.contains(.newYork))
    }

    @Test func quoteFontFollowsTheFace() {
        PageFace.registerBundledFonts()
        #expect(PageFace.literata.quotePlatformFont().fontName == "Literata-Italic")
        #expect(isItalic(PageFace.literata.quotePlatformFont()))
        #expect(PageFace.sourceSerif.quotePlatformFont().fontName == "SourceSerif4-It")
        let newYork = PageFace.newYork.quotePlatformFont()
        #expect(newYork.fontName.contains("NewYork"))
        #expect(isItalic(newYork))
    }

    @Test func numeralsAreLiningWhereTheFaceCanSetThem() {
        PageFace.registerBundledFonts()
        for face in [PageFace.literata, .sourceSerif] {
            guard let font = face.numeralCTFont(size: 15) else {
                Issue.record("\(face) has no numeral font")
                continue
            }
            let settings = CTFontDescriptorCopyAttribute(CTFontCopyFontDescriptor(font), kCTFontFeatureSettingsAttribute) as? [[String: Any]]
            let lining = settings?.contains {
                ($0[kCTFontFeatureTypeIdentifierKey as String] as? Int) == kNumberCaseType
                    && ($0[kCTFontFeatureSelectorIdentifierKey as String] as? Int) == kUpperCaseNumbersSelector
            }
            #expect(lining == true)
        }
        // Iowan Old Style offers old-style figures only, so its numerals take the system serif's lining ones.
        #expect(PageFace.iowanOldStyle.numeralCTFont(size: 15) == nil)
        #expect(PageFace.newYork.numeralCTFont(size: 15) == nil)
    }

    /// The front page's pane sets its numerals at the reader size in every face (spec 5.2): New York
    /// and Iowan Old Style take the system serif at that size, not `.title3`.
    @Test func thePanesNumeralsTakeTheReaderSizeInEveryFace() {
        PageFace.registerBundledFonts()
        for face in PageFace.available {
            #expect(CTFontGetSize(face.paneNumeralCTFont(size: 28)) == 28, "\(face)")
        }
        for face in [PageFace.newYork, .iowanOldStyle] {
            let family = CTFontCopyFamilyName(face.paneNumeralCTFont(size: 28)) as String
            let systemSerif = CTFontCopyFamilyName(PageFace.newYork.font(size: 28) as CTFont) as String
            #expect(family == systemSerif, "\(face)")
            // The phone's grid is unchanged: its fallback stays `.title3`, which follows Dynamic Type.
            #expect(face.numeralFont(size: 28) == Font.system(.title3, design: .serif).monospacedDigit(), "\(face)")
        }
    }

    @Test func rootsResolveTheFaceFromTheSettings() {
        #expect(PageFace.resolved(styleRaw: "printed", faceRaw: "") == .literata)
        #expect(PageFace.resolved(styleRaw: "lectern", faceRaw: "") == .iowanOldStyle)
        #expect(PageFace.resolved(styleRaw: "printed", faceRaw: "newYork") == .newYork)
        #expect(PageFace.resolved(styleRaw: "nonsense", faceRaw: "nonsense") == .literata)
    }
}
