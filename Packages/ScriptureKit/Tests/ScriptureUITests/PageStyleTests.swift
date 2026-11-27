import CoreText
import Foundation
import Testing
@testable import ScriptureUI

/// The Printed defaults at a size and line spacing, for the tests that predate page styles.
@MainActor func typo(_ size: Double, _ spacing: LineSpacingChoice) -> ReaderTypography {
    var prefs = ReaderPreferences.default
    prefs.fontSize = size
    prefs.lineSpacing = spacing
    return ReaderTypography.styled(prefs)
}

@MainActor @Suite struct PageStyleTests {
    @Test(.enabled(if: TestPlatform.isMac, "UIKit's dynamic palette colors never compare equal"))
    func printedAt18MatchesDesign() {
        let t = ReaderTypography.styled(.default)
        #expect(t.style == .printed && t.bodyFont.familyName == "Literata" && t.bodyFont.pointSize == 18)
        #expect(t.titleFont.pointSize == 44 && t.titleFont.fontName.contains("Light"))
        #expect(t.subtitleFont.pointSize == 16)
        #expect(t.chapterLabelFont.pointSize == 11 && abs(t.chapterLabelKern - 0.22 * 11) < 0.01)
        #expect(t.sectionHeadingFont.pointSize == 17)
        #expect(t.verseNumberFont.pointSize == 10.5)
        #expect(t.verseNumberColor == Palette.inkVerse.platformColor && t.chapterLabelColor == Palette.inkVerse.platformColor)
        #expect(t.verseNumberColorOnMark == nil)
        #expect(ReaderTypography.default == t)
    }

    @Test(.enabled(if: TestPlatform.isMac, "UIKit's dynamic palette colors never compare equal"))
    func studyUsesAccentNumbersWithAPrimaryFallbackOnMarks() {
        var p = ReaderPreferences.default
        p.style = .study
        let t = ReaderTypography.styled(p)
        #expect(t.verseNumberColor == Palette.accent.platformColor && t.verseNumberColorOnMark == Palette.inkPrimary.platformColor)
        #expect(t.sectionHeadingFont.familyName != t.bodyFont.familyName)
        #expect((t.bodyFont.familyName as String?)?.contains("Source Serif") == true)
    }

    @Test(.enabled(if: TestPlatform.isMac, "UIKit's dynamic palette colors never compare equal"))
    func lecternAndClassicFaces() {
        var p = ReaderPreferences.default
        p.style = .lectern
        let lectern = ReaderTypography.styled(p)
        #expect(lectern.bodyFont.familyName == "Iowan Old Style")
        #expect(lectern.verseNumberFont.familyName == "Iowan Old Style" && lectern.verseNumberFont.pointSize == 11)
        #expect(lectern.verseNumberColor == Palette.inkSecondary.platformColor)
        #expect(lectern.titleFont.pointSize == 30 && lectern.sectionHeadingAlignment == .center)
        #expect(abs(lectern.titleKern - 0.16 * 30) < 0.01)
        p.style = .classic
        let classic = ReaderTypography.styled(p)
        #expect(classic.bodyFont.fontName.contains("NewYork"))
        #expect(classic.verseNumberColor == Palette.inkSecondary.platformColor)
        #expect(classic.sectionHeadingColor == Palette.inkPrimary.platformColor)
    }

    @Test(.enabled(if: TestPlatform.isMac, "UIKit's dynamic palette colors never compare equal"))
    func aFaceOverrideKeepsTheStylesArrangement() {
        var p = ReaderPreferences.default
        p.face = .charter
        let t = ReaderTypography.styled(p)
        #expect(t.style == .printed && t.chapterLabelColor == Palette.inkVerse.platformColor)
        #expect(p.resolvedFace == .charter && ReaderPreferences.default.resolvedFace == .literata)
    }

    @Test func columnWidthScalesTheMeasure() {
        var p = ReaderPreferences.default
        let measures = ColumnWidthChoice.allCases.map { choice -> CGFloat in
            p.columnWidth = choice
            return ReaderTypography.styled(p).measure
        }
        #expect(measures == [544, 640, 736])
        p.columnWidth = .wide
        p.fontSize = 28
        #expect(ReaderTypography.styled(p).measure <= ReaderTypography.measureRange.upperBound)
    }

    @Test func sizeRangeReaches28() {
        #expect(ReaderSettings.clampedFontSize(30) == 28)
    }

    @Test func switchesAndLayoutCarryThrough() {
        var p = ReaderPreferences.default
        p.showsVerseNumbers = false
        p.showsSectionHeadings = false
        p.layout = .versePerLine
        p.justified = true
        let t = ReaderTypography.styled(p)
        #expect(!t.showsVerseNumbers && !t.showsSectionHeadings && t.versePerLine && t.justified)
    }

    @Test func preferencesLoadFromDefaultsWithFallbacks() {
        let name = "PageStyleTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        #expect(ReaderPreferences.load(from: defaults) == .default)
        defaults.set("lectern", forKey: ReaderSettings.pageStyleKey)
        defaults.set("charter", forKey: ReaderSettings.pageFaceKey)
        defaults.set("wide", forKey: ReaderSettings.columnWidthKey)
        defaults.set("versePerLine", forKey: ReaderSettings.verseLayoutKey)
        defaults.set(false, forKey: ReaderSettings.showsVerseNumbersKey)
        defaults.set(true, forKey: ReaderSettings.justifiedKey)
        let loaded = ReaderPreferences.load(from: defaults)
        #expect(loaded.style == .lectern && loaded.face == .charter && loaded.columnWidth == .wide)
        #expect(loaded.layout == .versePerLine && !loaded.showsVerseNumbers && loaded.justified && loaded.showsSectionHeadings)
        for key in [ReaderSettings.pageStyleKey, ReaderSettings.pageFaceKey, ReaderSettings.columnWidthKey, ReaderSettings.verseLayoutKey] {
            defaults.set("bogus", forKey: key)
        }
        #expect(ReaderPreferences.load(from: defaults).style == .printed)
        #expect(ReaderPreferences.load(from: defaults).face == nil)
        #expect(ReaderPreferences.load(from: defaults).columnWidth == .normal)
        #expect(ReaderPreferences.load(from: defaults).layout == .paragraphs)
        defaults.set("", forKey: ReaderSettings.pageFaceKey)
        #expect(ReaderPreferences.load(from: defaults).face == nil)
    }

    @Test func runningHeadsFollowTheStyle() {
        #expect(PageStyle.printed.runningHead(bookName: "John", chapter: 3) == "JOHN · 3")
        #expect(PageStyle.lectern.runningHead(bookName: "John", chapter: 3) == "John · 3")
        #expect(PageStyle.study.runningHead(bookName: "John", chapter: 3) == "JOHN 3")
        #expect(PageStyle.classic.runningHead(bookName: "John", chapter: 3) == "John 3")
        #expect(PageStyle.allCases.map(\.defaultFace) == [.literata, .iowanOldStyle, .sourceSerif, .newYork])
    }

    /// The Mac's pinned head speaks in each style's chapter-label voice (spec 3.2): Printed's
    /// spaced bronze label, Lectern's small capitals, Study's uppercase SF label, Classic's
    /// headline-sized title face. Printed and Lectern centre it, Study and Classic set it flush.
    @Test(.enabled(if: TestPlatform.isMac, "The Mac's pinned head: its NSColor tokens and AppKit's font features"))
    func runningHeadsSpeakInEachStylesLabelVoice() {
        func styled(_ style: PageStyle) -> ReaderTypography {
            var p = ReaderPreferences.default
            p.style = style
            return ReaderTypography.styled(p)
        }
        let printed = styled(.printed)
        #expect(printed.runningHeadFont == printed.chapterLabelFont && printed.runningHeadFont.pointSize == 11)
        #expect(printed.runningHeadKern == printed.chapterLabelKern && printed.runningHeadColor == Palette.inkVerse.platformColor)
        #expect(printed.runningHeadIsCentred)

        let lectern = styled(.lectern)
        #expect(lectern.runningHeadFont.familyName == "Iowan Old Style" && lectern.runningHeadFont.pointSize == 17)
        let features = lectern.runningHeadFont.fontDescriptor.fontAttributes[.featureSettings] as? [[PlatformFontDescriptor.FeatureKey: Int]]
        #expect(features?.contains { $0[.typeIdentifier] == kLowerCaseType } == true)
        #expect(abs(lectern.runningHeadKern - 0.16 * 17) < 0.01 && lectern.runningHeadColor == Palette.inkSecondary.platformColor)
        #expect(lectern.runningHeadIsCentred)

        let study = styled(.study)
        #expect(study.runningHeadFont == study.subtitleFont && study.runningHeadKern == study.subtitleKern)
        #expect(study.runningHeadColor == Palette.inkSecondary.platformColor && !study.runningHeadIsCentred)

        let classic = styled(.classic)
        #expect(classic.runningHeadFont.pointSize == classic.headlineSize && classic.headlineSize == ReaderTypography.systemHeadlineSize)
        #expect(classic.runningHeadFont.familyName == classic.titleFont.familyName && classic.runningHeadKern == 0)
        #expect(classic.runningHeadColor == Palette.inkPrimary.platformColor && !classic.runningHeadIsCentred)
    }

    /// Final review: Classic's running head uses the headline size captured when the typography
    /// was made, never the system's current size. (Classic's later chapters had a label at that
    /// size on the page; Matt, 2026-11-13: the page carries none, so the head alone is set at it,
    /// and the page's layout hash leaves it out.)
    @Test func theHeadlineSizeIsCapturedWhenTheTypographyIsMade() throws {
        var prefs = ReaderPreferences.default
        prefs.style = .classic
        let made = ReaderTypography.styled(prefs, headlineSize: 40)
        #expect(made.headlineSize == 40 && made.runningHeadFont.pointSize == 40)
        #expect(made.layoutHash == ReaderTypography.styled(prefs, headlineSize: 40).layoutHash)
        // Nothing on Classic's page is set at it now, so a new headline size changes the
        // typography (the head) but not the page's layout (parked 2026-11-13, cleared 2026-11-16).
        #expect(made.layoutHash == ReaderTypography.styled(prefs, headlineSize: 41).layoutHash)
        #expect(made != ReaderTypography.styled(prefs, headlineSize: 41))
        // The other styles set nothing at the headline size, so a new one does not re-lay them out.
        #expect(ReaderTypography.styled(.default, headlineSize: 40).layoutHash == ReaderTypography.styled(.default, headlineSize: 41).layoutHash)

        let layout = BookLayout.build(chapters: JohnFixture.inputs(2...3), opening: JohnFixture.opening, typography: made)
        #expect(layout.id.typography == made.layoutHash)
        // A later chapter opens on its empty hairline, and nothing on the page is set at the
        // headline size: the running head carries it.
        for chapter in [2, 3] {
            let opening = try #require(layout.section(for: chapter)).openingRange
            #expect(layout.attributedString.readerRole(at: opening.location) == .chapterStart(chapter))
            let font = try #require(layout.attributedString.attribute(.font, at: opening.location, effectiveRange: nil) as? PlatformFont)
            #expect(font.pointSize == 1)
        }
        var sizes: Set<CGFloat> = []
        layout.attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: layout.attributedString.length)) { value, _, _ in
            if let font = value as? PlatformFont { sizes.insert(font.pointSize) }
        }
        #expect(!sizes.isEmpty && !sizes.contains(40))

        #if canImport(UIKit)
        let large = ReaderTypography.headlineSize(for: .accessibilityExtraLarge)
        #expect(large > ReaderTypography.headlineSize(for: .large))
        #expect(ReaderTypography.styled(prefs, headlineSize: large).runningHeadFont.pointSize == large)
        #endif
    }

    @Test(.enabled(if: TestPlatform.isMac, "UIKit's dynamic palette colors never compare equal"))
    func verseNumbersOnMarksFallBackToPrimaryExceptInPrinted() {
        var p = ReaderPreferences.default
        for style in PageStyle.allCases {
            p.style = style
            let expected: PlatformColor? = style == .printed ? nil : Palette.inkPrimary.platformColor
            #expect(ReaderTypography.styled(p).verseNumberColorOnMark == expected, "\(style)")
        }
    }

    @Test func tastePreferencesSyncAndDeviceOnesDoNot() {
        let keys = SyncedPreferences.keys
        for key in [ReaderSettings.pageStyleKey, ReaderSettings.pageFaceKey, ReaderSettings.verseLayoutKey,
                    ReaderSettings.showsVerseNumbersKey, ReaderSettings.showsSectionHeadingsKey, ReaderSettings.justifiedKey] {
            #expect(keys.contains(key), "\(key)")
        }
        for key in [ReaderSettings.fontSizeKey, ReaderSettings.lineSpacingKey, ReaderSettings.columnWidthKey, ReaderSettings.appearanceKey] {
            #expect(!keys.contains(key), "\(key)")
        }
    }
}
