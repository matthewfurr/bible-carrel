import Foundation
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ReaderSettingsTests {
    @Test(.enabled(if: TestPlatform.isMac, "UIKit's dynamic palette colors never compare equal"))
    func defaultsReproduceTheCurrentTypography() {
        #expect(typo(18, .normal) == .default)
        #expect(ReaderSettings.defaultFontSize == 18 && ReaderSettings.fontSizeRange == 14...28)
    }

    /// Verse numbers, paragraph spacing and the measure follow the body size, so a 24 pt reader
    /// keeps its superscripts in proportion and its line at 65 to 75 characters.
    @Test func typographyScalesWithTheSize() {
        let base = typo(18, .normal)
        #expect(base.measure == 640 && base.verseNumberFont.pointSize == 10.5 && base.verseNumberBaselineOffset == 7 && base.paragraphSpacing == 14)
        let large = typo(24, .normal)
        #expect(large.verseNumberFont.pointSize == 14 && large.verseNumberBaselineOffset == 9 && large.paragraphSpacing == 19)
        #expect(large.measure == 853)
        let small = typo(14, .normal)
        #expect(small.measure == 498 && small.verseNumberFont.pointSize == 8)
        for size in stride(from: 14.0, through: 24.0, by: 1) {
            let t = typo(size, .normal)
            // About 0.5 em per character in a book serif: 65 to 75 characters fit the measure.
            let characters = t.measure / (CGFloat(size) * 0.5)
            #expect(characters >= 65 && characters <= 75, "\(size) pt: \(characters)")
        }
    }

    /// A line of body text, the unit a jump's scroll is measured in, follows the size and the spacing.
    @Test func aBodyLineFollowsTheSizeAndTheSpacing() {
        let normal = typo(18, .normal)
        let font = normal.bodyFont
        #expect(abs(normal.bodyLineHeight - (font.ascender - font.descender + font.leading) * 1.3) < 0.001)
        let relaxed = typo(18, .relaxed)
        #expect(abs(relaxed.bodyLineHeight / normal.bodyLineHeight - 1.5 / 1.3) < 0.001)
        #expect(typo(24, .normal).bodyLineHeight > normal.bodyLineHeight)
    }

    /// The printed page's paragraph shapes follow the body size too.
    @Test func metricsScaleWithTheSize() {
        let base = typo(18, .normal)
        #expect(base.firstLineIndent == 27)
        #expect(base.indentedParagraphSpacing == 5)
        #expect(base.poetryIndent == 18)
        #expect(base.poetryHang == 27)
        #expect(base.stanzaSpacing == 9)
        let large = typo(24, .normal)
        #expect(large.firstLineIndent == 36)
    }

    @Test func fontSizeIsClampedToTheRange() {
        #expect(ReaderSettings.clampedFontSize(9) == 14)
        #expect(ReaderSettings.clampedFontSize(40) == 28)
        #expect(ReaderSettings.clampedFontSize(20) == 20)
        #expect(typo(40, .normal).bodyFont.pointSize == 28)
        #expect(typo(22, .normal).bodyFont.pointSize == 22)
    }

    @Test func lineSpacingMapsOntoTheMultiple() {
        #expect(LineSpacingChoice.compact.lineHeightMultiple == 1.15)
        #expect(LineSpacingChoice.normal.lineHeightMultiple == 1.3)
        #expect(LineSpacingChoice.relaxed.lineHeightMultiple == 1.5)
        #expect(typo(18, .relaxed).lineHeightMultiple == 1.5)
        #expect(LineSpacingChoice.allCases.map(\.title) == ["Compact", "Normal", "Relaxed"])
    }

    @Test func appearanceMapsOntoColorScheme() {
        #expect(AppearanceChoice.system.colorScheme == nil)
        #expect(AppearanceChoice.light.colorScheme == .light)
        #expect(AppearanceChoice.dark.colorScheme == .dark)
        // Sepia is the light scheme with warm paper and ink.
        #expect(AppearanceChoice.sepia.colorScheme == .light)
        #expect(AppearanceChoice.allCases.map(\.title) == ["System", "Light", "Sepia", "Dark"])
        #expect(AppearanceChoice.allCases.filter(\.isSepia) == [.sepia])
        #expect(AppearanceChoice(rawValue: "sepia") == .sepia)
    }

    @Test func sectionHeadingsFooterNamesTheSource() {
        #expect(ReadingSettingsView.headingsFooter == "Headings from the Berean Standard Bible.")
    }

    @Test func keysAreStable() {
        #expect(ReaderSettings.defaultTranslationKey == "defaultTranslationID")
        #expect(ReaderSettings.fontSizeKey == "readerFontSize")
        #expect(ReaderSettings.lineSpacingKey == "readerLineSpacing")
        #expect(ReaderSettings.appearanceKey == "readerAppearance")
    }

    @Test func unknownDefaultTranslationFallsBack() throws {
        let name = "ReaderSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        #expect(ReaderSettings.defaultTranslationID(from: defaults) == "ESV")
        defaults.set("NIV", forKey: ReaderSettings.defaultTranslationKey)
        #expect(ReaderSettings.defaultTranslationID(from: defaults) == "NIV")
        // NavigationModel ignores an unbundled default, then tries the app's fallback (ESV, absent
        // from the fixture), then the first bundled translation.
        let model = try NavigationModel(
            store: try FixtureStore.make(),
            positionStore: ReadingPositionStore(defaults: defaults),
            defaultTranslationID: ReaderSettings.defaultTranslationID(from: defaults),
            fallbackTranslationID: ReaderSettings.defaultTranslationID)
        #expect(model.translationID == model.translations.first?.id && model.translationID != "NIV")
        defaults.set("KJV", forKey: ReaderSettings.defaultTranslationKey)
        let second = try NavigationModel(
            store: try FixtureStore.make(),
            positionStore: ReadingPositionStore(defaults: defaults),
            defaultTranslationID: ReaderSettings.defaultTranslationID(from: defaults))
        #expect(second.translationID == "KJV")
    }

    #if canImport(AppKit)
    @Test func appearanceMapsOntoAnAppWideNSAppearance() {
        #expect(AppearanceChoice.system.nsAppearance == nil)
        #expect(AppearanceChoice.light.nsAppearance?.name == .aqua)
        #expect(AppearanceChoice.dark.nsAppearance?.name == .darkAqua)
        // System controls stay light in Sepia.
        #expect(AppearanceChoice.sepia.nsAppearance?.name == .aqua)
    }
    #endif

    /// Final review: dragging the size slider writes the size once, when the drag ends, so the
    /// book is re-laid out once rather than at every point; the label follows the drag. A step
    /// without a drag (the keyboard, VoiceOver) is written at once.
    @Test func theSizeSliderWritesWhenItsDragEnds() {
        var draft = SliderDraft()
        var written: [Double] = []
        func move(_ value: Double) { if let value = draft.move(to: value) { written.append(value) } }
        func editing(_ on: Bool) { if let value = draft.editingChanged(on) { written.append(value) } }

        editing(true)
        for size in stride(from: 19.0, through: 24, by: 1) { move(size) }
        #expect(written.isEmpty && draft.shown(18) == 24)
        editing(false)
        #expect(written == [24] && draft.shown(24) == 24 && draft.value == nil)

        // A press that never moves writes nothing.
        editing(true); editing(false)
        #expect(written == [24])

        move(23)
        #expect(written == [24, 23])
    }
}
