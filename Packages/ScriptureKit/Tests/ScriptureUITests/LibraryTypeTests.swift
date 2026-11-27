import SwiftUI
import Testing
@testable import ScriptureUI

/// The Library pages' type at the reader's page size (Matt's review, 2026-11-24): `.body` is the reader size,
/// every other style in proportion; the page's column is the reader's own measure.
@Suite struct LibraryTypeTests {
    #if os(macOS)
    @Test func bodyIsTheReaderSizeAndTheOtherStylesStepInProportion() {
        let type = LibraryType(readerSize: 18)
        #expect(type.size(.body) == 18)
        // 12, 10 and 22 pt at 13 pt, times 18 / 13, to the half point.
        #expect(type.size(.callout) == 16.5)
        #expect(type.size(.caption) == 14)
        #expect(type.size(.largeTitle) == 36)
        #expect(LibraryType(readerSize: 14).size(.body) == 14)
        #expect(LibraryType(readerSize: 28).size(.body) == 28)
    }

    @Test func theReaderSizeIsHeldToTheSettingsRange() {
        #expect(LibraryType(readerSize: 9).size(.body) == 14)
        #expect(LibraryType(readerSize: 40).size(.body) == 28)
    }

    @Test func noStyleIsSetSmallerThanTheSystemsOwn() {
        let type = LibraryType(readerSize: 14)
        for style: Font.TextStyle in [.largeTitle, .title, .title2, .title3, .headline, .body, .callout, .subheadline, .footnote, .caption, .caption2] {
            #expect(type.size(style) >= PageFace.baseSize(style), "\(style)")
        }
    }

    @Test func readingTextIsBodyAtTheReaderSize() {
        #expect(LibraryType(readerSize: 20).reading == .body)
        #expect(LibraryType.system.reading == .callout)
    }

    @Test func metricsTiedToTextScaleWithTheType() {
        #expect(LibraryType(readerSize: 26).metric(AppSpacing.xs) == 16)
        #expect(LibraryType.system.metric(AppSpacing.xs) == AppSpacing.xs)
    }

    @MainActor @Test func theMeasuredFontIsTheDrawnSize() {
        let type = LibraryType(readerSize: 18)
        #expect(type.platformFont(.callout).pointSize == 16.5)
        #expect(type.platformFont(.body, weight: .semibold).pointSize == 18)
        #expect(type.platformFont(.caption, italic: true).fontDescriptor.symbolicTraits.contains(.italic))
    }
    #endif

    @Test func theColumnIsTheReadersMeasure() {
        // 640 pt at 18, as the reader's page, times the column width setting.
        #expect(LibraryType(readerSize: 18).measure == 640)
        #expect(LibraryType(readerSize: 18, columnWidth: .narrow).measure == 544)
        #expect(LibraryType(readerSize: 24, columnWidth: .wide).measure == 981)
        #expect(LibraryType(readerSize: 18).measure == ReaderTypography.measure(size: 18, columnWidth: .normal))
        #expect(LibraryType.system.measure == nil)
    }

    @Test func theColumnIsTheMeasureOnTheMacAndTheOld520PageOnThePhone() {
        // The reader's measure whatever the system's page; the phone's (the system's styles) keeps the scaled 520 pt
        // page less its margins, as before; an outset widens either at each side.
        #expect(LibraryType(readerSize: 18).columnMaxWidth(systemPage: 520) == 640)
        #expect(LibraryType(readerSize: 18).columnMaxWidth(systemPage: 520, outset: AppSpacing.xs) == 640 + 2 * AppSpacing.xs)
        #expect(LibraryType.system.columnMaxWidth(systemPage: 520) == 520 - 2 * AppSpacing.lg)
        #expect(LibraryType.system.columnMaxWidth(systemPage: 700, outset: AppSpacing.xs) == 700 - 2 * AppSpacing.lg + 2 * AppSpacing.xs)
    }
}
