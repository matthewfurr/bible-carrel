#if os(macOS)
import AppKit
import CoreText
import Foundation
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// The front page's sizes from the reader size (spec 4.2, 5.2, 5.3) and the widest-name measure.
@Suite struct FrontPageMetricsTests {
    private static let sixtySix = BookCatalog.all.filter { $0.canon != .apocrypha }.map { TranslationBook(book: $0, chapterCount: 28) }
    private static let apocrypha = BookCatalog.all.filter { $0.canon == .apocrypha }.map { TranslationBook(book: $0, chapterCount: 28) }
    private static let catalogue66 = sixtySix.map(\.book.name)

    private func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.01 }

    @Test func theContentsSizesFollowTheReaderSize() {
        let base = ContentsMetrics(readerSize: 18)
        #expect(near(base.testamentTitleSize, 20.7) && near(base.groupLabelSize, 10.44))
        #expect(base.markDot == 3 && base.washInset == 8 && base.nameSize == 18 && base.scale == 1)
        let large = ContentsMetrics(readerSize: 28)
        #expect(near(large.groupLabelSize, 16.24) && near(large.scale, 28.0 / 18.0))
        #expect(ContentsMetrics(readerSize: 14).groupLabelSize == PageFace.baseSize(.caption2))
        #expect(ContentsMetrics(readerSize: 40).readerSize == 28)
        #expect(base.columnWidth(widestName: 100.2) == (100.2 + 8 + 3 + 16).rounded(.up))
    }

    @Test func theGroupLabelKeepsItsProportion() {
        #expect(near(GroupLabel.tracking(forSize: PageFace.baseSize(.caption2)), 1.4))
        #expect(near(GroupLabel.tracking(forSize: 16.24), 2.27))
    }

    @Test func thePaneSizesFollowTheReaderSize() {
        let base = ChapterPaneMetrics(readerSize: 18)
        #expect(base.cellWidth == 52 && base.cellHeight == 40 && base.numeralSize == 18)
        #expect(base.ringLineWidth == 1.5 && base.searchRingWidth == 3)
        #expect(ChapterPaneMetrics(readerSize: 14).narrowestWidth == 261)
        #expect(base.narrowestWidth == 316)
        #expect(ChapterPaneMetrics(readerSize: 28).narrowestWidth == 461)
    }

    @Test func theNarrowestNeverPassesFortyPercent() {
        let large = ChapterPaneMetrics(readerSize: 28)
        #expect(large.shownWidth(stored: nil, frontPageWidth: 1100) == 440)
        #expect(large.shownWidth(stored: nil, frontPageWidth: 820) == 328)
        let base = ChapterPaneMetrics(readerSize: 18)
        #expect(base.shownWidth(stored: nil, frontPageWidth: 1100) == 316)
        #expect(base.shownWidth(stored: 400, frontPageWidth: 1100) == 400)
        #expect(base.shownWidth(stored: 400, frontPageWidth: 800) == 320)
        #expect(base.shownWidth(stored: 300, frontPageWidth: 1100) == 316)
    }

    @Test func anUnknownWidthShowsTheNarrowest() {
        let base = ChapterPaneMetrics(readerSize: 18)
        #expect(base.shownWidth(stored: nil, frontPageWidth: 0) == base.narrowestWidth)
        #expect(base.shownWidth(stored: 400, frontPageWidth: 0) == 400)
    }

    @Test func theGridHoldsFiveAtTheNarrowestAndMoreAsItWidens() {
        let base = ChapterPaneMetrics(readerSize: 18)
        #expect(base.columns(paneWidth: 316) == 5 && base.columns(paneWidth: 376) == 6 && base.columns(paneWidth: 496) == 8)
        let large = ChapterPaneMetrics(readerSize: 28)
        #expect(large.columns(paneWidth: 440) == 4 && large.columns(paneWidth: 328) == 3 && large.columns(paneWidth: 100) == 3)
    }

    @Test func theWidestNameIsMeasuredOncePerFaceSizeAndNames() {
        let measure = BookNameMeasure()
        let names = Self.catalogue66
        let at18 = measure.widest(of: names, face: .literata, size: 18)
        #expect(measure.widest(of: names, face: .literata, size: 18) == at18 && measure.measurements == 1)
        let at28 = measure.widest(of: names, face: .literata, size: 28)
        #expect(at28 > at18 && measure.measurements == 2)
        _ = measure.widest(of: names, face: .sourceSerif, size: 18)
        #expect(measure.measurements == 3)
        let font = PageFace.literata.font(size: 18)
        for name in names { #expect(BookNameMeasure.width(of: name, font: font) <= at18) }
    }

    @Test func theApocryphaSetsTheWidthWhereATranslationHasIt() {
        let measure = BookNameMeasure()
        let with = measure.widest(of: Self.catalogue66 + Self.apocrypha.map(\.book.name), face: .literata, size: 18)
        #expect(with > measure.widest(of: Self.catalogue66, face: .literata, size: 18))
    }

    @Test func columnCountLeavesRoomForTheTestamentsGap() {
        let w: CGFloat = 177
        #expect(ContentsPage.columnCount(width: 4 * w + 3 * 16, minimumColumnWidth: w) == 3)
        #expect(ContentsPage.columnCount(width: 4 * w + 3 * 16 + 8, minimumColumnWidth: w) == 4)
    }

    /// Measured on the real bundle (spec 4.2; `measurements.md`): the ESV's and the KJV's books in
    /// Literata, in a 1,100 pt window with the pane at its narrowest and the divider taking no width.
    @Test(.needsRealBible) func theDefaultWindowHoldsTheMeasuredColumns() throws {
        let store = try BenchmarkChapter.realStore()
        for id in ["ESV", "KJV"] {
            let page = ContentsPage(books: try store.books(in: id), reading: nil, chosenBookID: nil)
            for (size, expected) in [(CGFloat(14), 5), (18, 3), (28, 2)] {
                let metrics = ContentsMetrics(readerSize: size)
                let widest = BookNameMeasure().widest(of: page.bookNames, face: .literata, size: size)
                let column = metrics.columnWidth(widestName: widest)
                let font = PageFace.literata.font(size: size)
                for name in page.bookNames {
                    #expect(BookNameMeasure.width(of: name, font: font) + metrics.dotGap + metrics.markDot + 2 * metrics.washInset <= column)
                }
                let pane = ChapterPaneMetrics(readerSize: size).shownWidth(stored: nil, frontPageWidth: 1100)
                let count = ContentsPage.columnCount(width: 1100 - pane - 2 * AppSpacing.lg, minimumColumnWidth: column)
                #expect(count == expected, "\(id) at \(Int(size))")
                if size == 28 {
                    let bands = page.layout(columns: count).bands
                    #expect(bands.map { $0.map(\.testament.title) } == [["Old Testament"], ["New Testament"]])
                }
            }
        }
    }
}

/// The measure against SwiftUI's own setting of the same name.
@MainActor @Suite(.serialized) struct FrontPageMeasureHostTests {
    @Test func aNameSetInSwiftUIFitsItsMeasure() {
        for name in ["2 Thessalonians", "Song of Solomon", "Bel and the Dragon"] {
            for size in [CGFloat(14), 18, 28] {
                let host = NSHostingView(rootView: Text(name).font(Font(PageFace.literata.font(size: size))).fixedSize())
                #expect(host.fittingSize.width <= BookNameMeasure().widest(of: [name], face: .literata, size: size))
            }
        }
    }
}
#endif
