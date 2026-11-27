import Foundation
import ScriptureModel
import Testing
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
@testable import ScriptureUI

/// Holds the palette to the contrast DESIGN.md promises, in every appearance, so a token edit that
/// breaks readability fails here rather than on the page.
@Suite struct PaletteTests {
    private static func luminance(_ hex: String) -> Double {
        let c = ColorHex.components(hex)!
        func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    static func contrast(_ a: String, _ b: String) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// Every appearance: light, dark, Sepia, and their Increase Contrast variants.
    private static let appearances: [(dark: Bool, high: Bool, sepia: Bool)] = [
        (false, false, false), (true, false, false), (false, true, false), (true, true, false),
        (false, false, true), (false, true, true),
    ]

    private func expect(_ ink: ColorToken, on surface: ColorToken, atLeast minimum: Double, sourceLocation: SourceLocation = #_sourceLocation) {
        for a in Self.appearances {
            let ratio = Self.contrast(ink.hex(dark: a.dark, highContrast: a.high, sepia: a.sepia),
                                      surface.hex(dark: a.dark, highContrast: a.high, sepia: a.sepia))
            #expect(ratio >= minimum, "\(ink.name) on \(surface.name) (dark: \(a.dark), high: \(a.high), sepia: \(a.sepia)) is \(ratio)",
                    sourceLocation: sourceLocation)
        }
    }

    @Test func primaryInkIsAAAOnEveryPaper() {
        for paper in [Palette.paperPage, Palette.paperPanel, Palette.paperOverlay, Palette.accentWash] {
            expect(Palette.inkPrimary, on: paper, atLeast: 7)
        }
    }

    @Test func secondaryInkCarriesSmallTextEverywhereItAppears() {
        for paper in [Palette.paperPage, Palette.paperPanel, Palette.paperOverlay, Palette.accentWash] {
            expect(Palette.inkSecondary, on: paper, atLeast: 4.5)
        }
    }

    @Test func accentAndAssistantReadAsShortTextOnThePage() {
        expect(Palette.accent, on: Palette.paperPage, atLeast: 4.5)
        expect(Palette.assistant, on: Palette.paperPage, atLeast: 4.5)
        expect(Palette.inkPrimary, on: Palette.assistantWash, atLeast: 7)
    }

    /// Inside a reply: the model label in plum and the Copy and Add as Note glyphs in secondary
    /// ink sit on the plum wash; the header's sparkles sits on the panel.
    @Test func theReplyFooterReadsOnThePlumWash() {
        expect(Palette.assistant, on: Palette.assistantWash, atLeast: 4.5)
        expect(Palette.inkSecondary, on: Palette.assistantWash, atLeast: 4.5)
        expect(Palette.assistant, on: Palette.paperPanel, atLeast: 4.5)
        expect(Palette.inkPrimary, on: Palette.paperOverlay, atLeast: 7)
    }

    /// The Notes window's selected row: its accent and plum marks stay visible on the wash.
    @Test func theNotesWindowsSelectedRowKeepsItsMarksVisible() {
        expect(Palette.accent, on: Palette.accentWash, atLeast: 3)
        expect(Palette.assistant, on: Palette.accentWash, atLeast: 3)
    }

    /// Lectern's chapter numeral is accent text on the page, never on a mark (it is the chapter's
    /// opening, outside every verse): held to short text's 4.5:1, though it is set large.
    @Test func lecternsNumeralReadsOnThePage() {
        expect(Palette.accent, on: Palette.paperPage, atLeast: 4.5)
    }

    /// The book thumb's loupe under Reduce Transparency: the accent numeral on an opaque overlay
    /// disc (it is large, but held to short text's 4.5:1 like Lectern's numeral).
    @Test func theLoupesNumeralReadsOnItsOpaqueDisc() {
        expect(Palette.accent, on: Palette.paperOverlay, atLeast: 4.5)
    }

    /// The accent's outline and bookmark glyph are UI marks: 3:1 against the page.
    @Test func accentIsVisibleAsAMark() {
        expect(Palette.accent, on: Palette.paperPage, atLeast: 3)
        expect(Palette.accent, on: Palette.paperPanel, atLeast: 3)
    }

    @Test func verseBronzeCarriesSmallTextOnThePageAndEveryMark() {
        expect(Palette.inkVerse, on: Palette.paperPage, atLeast: 4.5)
        for mark in MarkupContainer.defaultColors { // light/dark hex pairs
            #expect(Self.contrast(Palette.inkVerse.light, mark.lightHex) >= 4.5)
            #expect(Self.contrast(Palette.inkVerse.dark, mark.darkHex) >= 4.5)
        }
    }

    @Test func studyAccentVerseNumbersFallBackOnMarks() {
        expect(Palette.accent, on: Palette.paperPage, atLeast: 4.5)
        // ink.primary is the on-mark fallback (ink.secondary fails 4.5:1 on several marks).
        for mark in MarkupContainer.defaultColors {
            #expect(Self.contrast(Palette.inkPrimary.light, mark.lightHex) >= 4.5, "\(mark.name) light")
            #expect(Self.contrast(Palette.inkPrimary.dark, mark.darkHex) >= 4.5, "\(mark.name) dark")
        }
    }

    /// The Library's People and About: reference links and "Show more" are accent text on the page, the
    /// notice's Settings and OK accent text on the overlay; a family name and the dictionary's source
    /// are ink on the panel, the chosen row and the open icon sit on the wash with accent marks.
    @Test func theLibraryPagesReadOnTheirGrounds() {
        expect(Palette.accent, on: Palette.paperPage, atLeast: 4.5)
        expect(Palette.accent, on: Palette.paperOverlay, atLeast: 4.5)
        expect(Palette.inkPrimary, on: Palette.paperOverlay, atLeast: 7)
        expect(Palette.inkPrimary, on: Palette.paperPanel, atLeast: 7)
        expect(Palette.inkSecondary, on: Palette.paperPanel, atLeast: 4.5)
        expect(Palette.inkPrimary, on: Palette.accentWash, atLeast: 7)
        expect(Palette.inkSecondary, on: Palette.accentWash, atLeast: 4.5)
        expect(Palette.accent, on: Palette.accentWash, atLeast: 3)
    }

    /// The phone's plan editor: a week's number and label fields sit on the panel tone, their text in
    /// the system's ink and their prompt ("Label") in `ink.tertiary`, a hint beside a header that names it.
    @Test func thePlanEditorsWeekFieldsReadOnThePanel() {
        expect(Palette.inkPrimary, on: Palette.paperPanel, atLeast: 7)
        expect(Palette.inkTertiary, on: Palette.paperPanel, atLeast: 2.5)
    }

    @Test func increaseContrastNeverLowersContrast() {
        for token in [Palette.inkSecondary, Palette.inkTertiary, Palette.accent, Palette.assistant] {
            for (dark, sepia) in [(false, false), (true, false), (false, true)] {
                let page = Palette.paperPage.hex(dark: dark, sepia: sepia)
                #expect(Self.contrast(token.hex(dark: dark, highContrast: true, sepia: sepia), page)
                    >= Self.contrast(token.hex(dark: dark, sepia: sepia), page), "\(token.name) sepia: \(sepia)")
            }
        }
        // High contrast lifts tertiary into readable text.
        expect(Palette.inkTertiary, on: Palette.paperPage, atLeast: 2.5)
        // The palette's row dates sit on its solid overlay, held as on the page.
        expect(Palette.inkTertiary, on: Palette.paperOverlay, atLeast: 2.5)
        #expect(Self.contrast(Palette.inkTertiary.hex(dark: false, highContrast: true), Palette.paperPage.hex(dark: false)) >= 4.5)
    }

    /// A marked phrase stays as readable as an unmarked one (PRODUCT.md › Accessibility).
    @Test func primaryInkStaysReadableOnEveryDefaultHighlight() {
        for mark in MarkupContainer.defaultColors {
            #expect(Self.contrast(Palette.inkPrimary.light, mark.lightHex) >= 11, "\(mark.name) light")
            #expect(Self.contrast(Palette.inkPrimary.dark, mark.darkHex) >= 7, "\(mark.name) dark")
            // Sepia keeps the marks' light values under its warmer ink.
            #expect(Self.contrast(Palette.inkPrimary.hex(dark: false, sepia: true), mark.lightHex) >= 11, "\(mark.name) sepia")
        }
    }

    /// Sepia keeps the marks at their light values: on the warm page they stay as readable as on
    /// the slate one, and the bronze verse numbers hold on the page and on every mark.
    @Test func marksStayReadableOnSepia() {
        let ink = Palette.inkPrimary.hex(dark: false, sepia: true)
        let page = Palette.paperPage.hex(dark: false, sepia: true)
        for mark in MarkupContainer.defaultColors {
            #expect(Self.contrast(ink, mark.lightHex) >= 10, "\(mark.name) on sepia")
            #expect(Self.contrast(Palette.inkVerse.hex(dark: false, sepia: true), mark.lightHex) >= 4.5, "verse on \(mark.name)")
        }
        #expect(Self.contrast(Palette.inkVerse.hex(dark: false, sepia: true), page) >= 4.5)
    }

    /// Sepia changes only the paper and ink; the verse bronze, the accent, the assistant and the
    /// washes keep their light values, and dark mode ignores it.
    @Test func sepiaChangesOnlyPaperAndInk() {
        let sepia: Set = ["paper.page", "paper.panel", "paper.overlay", "ink.primary", "ink.secondary", "ink.tertiary", "ink.rule"]
        for token in Palette.all {
            #expect((token.hex(dark: false, sepia: true) != token.light) == sepia.contains(token.name), "\(token.name)")
            #expect(token.hex(dark: true, sepia: true) == token.dark, "\(token.name)")
            #expect(token.hex(dark: true, highContrast: true, sepia: true) == token.hex(dark: true, highContrast: true), "\(token.name)")
        }
        // Increase Contrast in Sepia: inks with a high-contrast value take it; the papers stay warm.
        #expect(Palette.inkSecondary.hex(dark: false, highContrast: true, sepia: true) == Palette.inkSecondary.lightHighContrast)
        #expect(Palette.inkPrimary.hex(dark: false, highContrast: true, sepia: true) == Palette.inkPrimary.sepia)
        #expect(Palette.paperPage.hex(dark: false, highContrast: true, sepia: true) == Palette.paperPage.sepia)
    }

    /// The marks share one lightness, so none is louder than another: their contrast against ink
    /// spans a narrow band.
    @Test func defaultHighlightsShareOneLightness() {
        let light = MarkupContainer.defaultColors.map { Self.contrast(Palette.inkPrimary.light, $0.lightHex) }
        let dark = MarkupContainer.defaultColors.map { Self.contrast(Palette.inkPrimary.dark, $0.darkHex) }
        #expect(light.max()! - light.min()! < 1.5)
        #expect(dark.max()! - dark.min()! < 1)
    }

    /// An OKLCH color as sRGB hex, chroma reduced until it fits (the way `MarkLightness.conformed` does).
    static func hex(oklchL l: Double, chroma: Double, hueDegrees: Double) -> String {
        OKLCH(l: l, c: chroma, hueDegrees: hueDegrees).hexReducingChroma()
    }

    /// Any hue, conformed into the band, keeps primary ink readable: the guarantee DESIGN.md makes
    /// for the defaults now covers the reader's own colors.
    @Test func anyHueConformedKeepsPrimaryInkReadable() {
        for hue in stride(from: 0, to: 360, by: 15) {
            let seed = Self.hex(oklchL: 0.6, chroma: 0.12, hueDegrees: Double(hue))
            let light = MarkLightness.conformed(hex: seed, dark: false)
            let dark = MarkLightness.conformed(hex: seed, dark: true)
            #expect(Self.contrast(Palette.inkPrimary.light, light) >= 10, "hue \(hue) light \(light)")
            #expect(Self.contrast(Palette.inkPrimary.hex(dark: false, sepia: true), light) >= 10, "hue \(hue) sepia \(light)")
            #expect(Self.contrast(Palette.inkPrimary.dark, dark) >= 6.5, "hue \(hue) dark \(dark)")
        }
    }

    /// Spec 5: a ring reads as a mark on the page, the panel and the wash, for the defaults and for any hue the band allows.
    @Test func aChaptersRingHoldsThreeToOneOnEverySurface() {
        var seeds = MarkupContainer.defaultColors.map { MarkupColor(lightHex: $0.lightHex, darkHex: $0.darkHex) }
        for hue in stride(from: 0, to: 360, by: 15) {
            let seed = Self.hex(oklchL: 0.6, chroma: 0.12, hueDegrees: Double(hue))
            seeds.append(MarkupColor(lightHex: MarkLightness.conformed(hex: seed, dark: false), darkHex: MarkLightness.conformed(hex: seed, dark: true)))
        }
        for seed in seeds {
            let ring = ChapterRing.color(seed)
            for paper in [Palette.paperPage, Palette.paperPanel, Palette.accentWash] {
                for a in Self.appearances {
                    let ratio = Self.contrast(a.dark ? ring.darkHex : ring.lightHex, paper.hex(dark: a.dark, highContrast: a.high, sepia: a.sepia))
                    #expect(ratio >= 3, "\(seed.lightHex) on \(paper.name) (dark: \(a.dark), high: \(a.high), sepia: \(a.sepia)) is \(ratio)")
                }
            }
        }
        #expect(abs((OKLCH(hex: ChapterRing.ringHex("#F8E18A", dark: false))?.l ?? 0) - 0.55) < 0.01)
        for paper in [Palette.paperPage, Palette.paperPanel, Palette.accentWash] { expect(Palette.inkTertiary, on: paper, atLeast: 2.5) }
    }

    @Test func tokensAreNamedOnceAndParse() {
        #expect(Set(Palette.all.map(\.name)).count == Palette.all.count)
        for token in Palette.all {
            for a in Self.appearances {
                #expect(ColorHex.components(token.hex(dark: a.dark, highContrast: a.high, sepia: a.sepia)) != nil, "\(token.name)")
            }
        }
    }

    #if canImport(AppKit)
    /// On the main actor: resolving an AppKit color under an appearance is main-thread work, and
    /// doing it beside the AppKit-driving suites from another thread crashes the test process.
    @MainActor @Test func platformColorResolvesPerAppearance() {
        let color = Palette.accent.platformColor
        func hex(in name: NSAppearance.Name) -> String {
            var result = ""
            NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                let c = color.usingColorSpace(.sRGB)!
                result = ColorHex.string(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent)
            }
            return result
        }
        // The high-contrast appearances exist only when the system applies them, so they are
        // covered through `hex(dark:highContrast:)` above. This machine's setting decides which
        // pair the plain appearances resolve to.
        let high = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        #expect(hex(in: .aqua) == Palette.accent.hex(dark: false, highContrast: high))
        #expect(hex(in: .darkAqua) == Palette.accent.hex(dark: true, highContrast: high))
        #expect(Palette.accent.platformColor == Palette.accent.platformColor)
    }
    #endif
}
