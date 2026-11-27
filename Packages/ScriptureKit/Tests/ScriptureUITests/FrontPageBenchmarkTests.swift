#if os(macOS)
import AppKit
import Foundation
import ScriptureData
import ScriptureModel
import SwiftUI
import Testing
@testable import ScriptureUI

/// The Mac's front page on the real store (spec 11): reading John 15 in the ESV, forty marked
/// chapters across ten books, hosted in a window that is never shown.
@MainActor @Suite(.serialized) struct FrontPageBenchmarkTests {
    private static let markedBooks = ["GEN", "EXO", "PSA", "PRO", "ISA", "MAT", "JHN", "ACT", "ROM", "REV"]

    private static func marks() -> [ChapterLocation: ChapterMarks] {
        let color = MarkupColor(lightHex: "#E8C547", darkHex: "#B8962A")
        var marks: [ChapterLocation: ChapterMarks] = [:]
        for book in markedBooks {
            for chapter in 1...4 { marks[ChapterLocation(book: book, chapter: chapter)] = ChapterMarks(colors: [color]) }
        }
        return marks
    }

    private static func navigation() throws -> NavigationModel {
        let defaults = UserDefaults(suiteName: "FrontPageBenchmarkTests-\(UUID().uuidString)")!
        let model = try NavigationModel(store: BenchmarkChapter.realStore(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "ESV")
        model.open(ChapterLocation(book: "JHN", chapter: 15))
        model.goHome()
        return model
    }

    /// Spec 11: the front page opens within 100 ms on Matt's Mac in a debug build, with the
    /// "This week" band over the contents: the 67-week sample on week 63 (five readings of two passages).
    @Test(.needsRealBible, arguments: [18.0, 28.0]) func theFrontPageOpensWithinAHundredMilliseconds(readerSize: Double) throws {
        let navigation = try Self.navigation()
        #expect(navigation.screen == .frontPage && navigation.selectedBookID == "JHN")
        let marks = Self.marks()
        let plans = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        plans.model.save(PlanSample.gen1Shaped())
        plans.model.anchor(week: 62, on: PlanModelFixture.day(2026, 11, 17))
        #expect(plans.model.thisWeek?.index == 62 && plans.model.thisWeek?.week.readings.count == 5)
        // A pane width of the test's own, holding nothing, so the pane is at its narrowest.
        let paneSuite = "FrontPageBenchmarkTests-pane-\(UUID().uuidString)"
        let paneDefaults = UserDefaults(suiteName: paneSuite)!
        defer { paneDefaults.removePersistentDomain(forName: paneSuite) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.titled], backing: .buffered, defer: true)
        let median = ReaderBenchmarkTests.median("front-page-open") {
            let host = NSHostingView(rootView: FrontPageView(navigation: navigation, marks: marks, plans: plans.model, onOpenSettings: {}, readerSize: readerSize, paneDefaults: paneDefaults).frame(width: 1100, height: 760))
            host.frame = NSRect(x: 0, y: 0, width: 1100, height: 760)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        #expect(median < .milliseconds(100))
    }
}
#endif
