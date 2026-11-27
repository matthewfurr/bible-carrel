#if os(macOS)
import Foundation
import Testing
@testable import ScriptureUI

/// The chapter pane's width as the reader drags it, kept on this Mac (spec 5.1 and 6).
@Suite struct PaneWidthTests {
    private static let at14 = ChapterPaneMetrics(readerSize: 14)
    private static let at18 = ChapterPaneMetrics(readerSize: 18)
    private static let at28 = ChapterPaneMetrics(readerSize: 28)

    /// A suite of defaults of the test's own, removed when the test ends.
    private static func withDefaults(holding width: Double? = nil, _ body: (UserDefaults) throws -> Void) rethrows {
        let name = "PaneWidthTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        if let width { defaults.set(width, forKey: PaneWidth.key) }
        try body(defaults)
    }

    @Test func withNothingStoredThePaneFollowsTheNarrowest() {
        Self.withDefaults { defaults in
            let width = PaneWidth(defaults: defaults)
            #expect(width.stored == nil)
            #expect(width.shown(Self.at14, frontPageWidth: 1100) == 261)
            #expect(width.shown(Self.at18, frontPageWidth: 1100) == 316)
            #expect(width.shown(Self.at28, frontPageWidth: 1100) == 440)
        }
    }

    @Test func aStoredWidthIsReadOnOpening() {
        Self.withDefaults(holding: 400) { defaults in
            #expect(PaneWidth(defaults: defaults).shown(Self.at18, frontPageWidth: 1100) == 400)
        }
    }

    @Test func aStoredWidthBeyondTheLimitsShowsAtThemAndIsKept() {
        Self.withDefaults(holding: 400) { defaults in
            let width = PaneWidth(defaults: defaults)
            #expect(width.shown(Self.at28, frontPageWidth: 1100) == 440)
            #expect(width.shown(Self.at18, frontPageWidth: 800) == 320)
            #expect(defaults.double(forKey: PaneWidth.key) == 400)
        }
        Self.withDefaults(holding: 300) { defaults in
            let width = PaneWidth(defaults: defaults)
            #expect(width.shown(Self.at18, frontPageWidth: 1100) == 316)
            #expect(defaults.double(forKey: PaneWidth.key) == 300)
        }
    }

    @Test func aDragIsWrittenOnlyWhenItEnds() {
        Self.withDefaults { defaults in
            var width = PaneWidth(defaults: defaults)
            width.drag(translation: -84, Self.at18, frontPageWidth: 1100)
            #expect(width.isDragging)
            #expect(width.shown(Self.at18, frontPageWidth: 1100) == 400)
            #expect(defaults.object(forKey: PaneWidth.key) == nil)
            width.endDrag(Self.at18, frontPageWidth: 1100)
            #expect(!width.isDragging)
            #expect(defaults.double(forKey: PaneWidth.key) == 400)

            width.drag(translation: -200, Self.at18, frontPageWidth: 1100)
            width.endDrag(Self.at18, frontPageWidth: 1100)
            #expect(defaults.double(forKey: PaneWidth.key) == 440)

            width.drag(translation: 300, Self.at18, frontPageWidth: 1100)
            width.endDrag(Self.at18, frontPageWidth: 1100)
            #expect(defaults.double(forKey: PaneWidth.key) == 316)
        }
    }

    @Test func aDoubleClickRemovesTheStoredWidth() {
        Self.withDefaults(holding: 400) { defaults in
            var width = PaneWidth(defaults: defaults)
            width.reset()
            #expect(defaults.object(forKey: PaneWidth.key) == nil)
            #expect(width.stored == nil)
            #expect(width.shown(Self.at14, frontPageWidth: 1100) == 261)
        }
    }

    @Test func adjustingStopsAtBothLimits() {
        Self.withDefaults { defaults in
            var width = PaneWidth(defaults: defaults)
            for expected in [376.0, 436, 440, 440] {
                width.adjust(byColumns: 1, Self.at18, frontPageWidth: 1100)
                #expect(defaults.double(forKey: PaneWidth.key) == expected)
            }
            width.adjust(byColumns: -10, Self.at18, frontPageWidth: 1100)
            #expect(defaults.double(forKey: PaneWidth.key) == 316)
        }
    }

    @Test func openingAndShowingTheWidthWritesNothing() {
        Self.withDefaults { defaults in
            let width = PaneWidth(defaults: defaults)
            for metrics in [Self.at14, Self.at18, Self.at28] {
                for frontPageWidth in [820.0, 1100] {
                    _ = width.shown(metrics, frontPageWidth: frontPageWidth)
                }
            }
            #expect(defaults.object(forKey: PaneWidth.key) == nil)
        }
    }

    /// At 28 in 1,100 the cap (440) is under the narrowest (461): the divider cannot move.
    @Test func aDragThatChangesNothingStoresNothing() {
        Self.withDefaults { defaults in
            var width = PaneWidth(defaults: defaults)
            width.drag(translation: -50, Self.at28, frontPageWidth: 1100)
            width.endDrag(Self.at28, frontPageWidth: 1100)
            #expect(!width.isDragging)
            #expect(defaults.object(forKey: PaneWidth.key) == nil)
            #expect(width.stored == nil)
        }
    }

    @Test func anAdjustmentThatChangesNothingStoresNothing() {
        Self.withDefaults { defaults in
            var width = PaneWidth(defaults: defaults)
            width.adjust(byColumns: -1, Self.at18, frontPageWidth: 1100)
            #expect(defaults.object(forKey: PaneWidth.key) == nil)
        }
        // A kept 600 shows at the cap (440); one more column cannot widen it, so 600 stays.
        Self.withDefaults(holding: 600) { defaults in
            var width = PaneWidth(defaults: defaults)
            width.adjust(byColumns: 1, Self.at18, frontPageWidth: 1100)
            #expect(defaults.double(forKey: PaneWidth.key) == 600)
            #expect(width.stored == 600)
        }
    }

    @Test func aCancelledDragReturnsThePaneAndWritesNothing() {
        Self.withDefaults(holding: 400) { defaults in
            var width = PaneWidth(defaults: defaults)
            width.drag(translation: -20, Self.at18, frontPageWidth: 1100)
            #expect(width.shown(Self.at18, frontPageWidth: 1100) == 420)
            width.cancelDrag()
            #expect(!width.isDragging)
            #expect(width.shown(Self.at18, frontPageWidth: 1100) == 400)
            #expect(defaults.double(forKey: PaneWidth.key) == 400)
            // The next drag starts from the shown width, not the cancelled drag's start.
            width.drag(translation: -10, Self.at18, frontPageWidth: 1100)
            #expect(width.shown(Self.at18, frontPageWidth: 1100) == 410)
        }
        Self.withDefaults { defaults in
            var width = PaneWidth(defaults: defaults)
            width.drag(translation: -40, Self.at18, frontPageWidth: 1100)
            width.cancelDrag()
            #expect(width.shown(Self.at18, frontPageWidth: 1100) == 316)
            #expect(defaults.object(forKey: PaneWidth.key) == nil)
        }
    }

    @MainActor @Test func theWidthIsNotSynced() {
        #expect(!SyncedPreferences.keys.contains(PaneWidth.key))
        #expect(PaneWidth.key == "frontPagePaneWidth")
    }
}
#endif
