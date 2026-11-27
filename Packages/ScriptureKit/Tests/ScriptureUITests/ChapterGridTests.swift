#if os(macOS)
import CoreGraphics
import Testing
@testable import ScriptureUI

/// The front page's chapter grid with its column count computed from the pane's width (spec 5.3):
/// the cursor's rectangle, the arrows' moves and the grid's edges follow the count.
@Suite struct ChapterGridTests {
    private static let base = ChapterPaneMetrics(readerSize: 18)

    @Test func theCursorsRectangleFollowsTheColumnCount() {
        #expect(ChapterGridView.cursorRect(chapter: 7, columns: 8, metrics: Self.base) == CGRect(x: 360, y: 0, width: 52, height: 40))
        #expect(ChapterGridView.cursorRect(chapter: 15, columns: 8, metrics: Self.base).origin == CGPoint(x: 360, y: 48))
        #expect(ChapterGridView.cursorRect(chapter: 6, columns: 5, metrics: Self.base).origin == CGPoint(x: 0, y: 48))
    }

    @Test func theArrowsMoveByTheColumnCount() {
        #expect(ChapterGridView.target(from: 3, moving: .down, columns: 8, chapterCount: 50) == 11)
        #expect(ChapterGridView.target(from: 11, moving: .up, columns: 8, chapterCount: 50) == 3)
        #expect(ChapterGridView.target(from: 8, moving: .right, columns: 8, chapterCount: 50) == 9)
        #expect(ChapterGridView.target(from: 3, moving: .down, columns: 5, chapterCount: 50) == 8)
    }

    @Test func theArrowsStopAtTheGridsEdges() {
        for move in [ChapterGridMove.up, .down, .left, .right] {
            #expect(ChapterGridView.target(from: 1, moving: move, columns: 8, chapterCount: 1) == nil, "Obadiah \(move)")
        }
        #expect(ChapterGridView.target(from: 148, moving: .down, columns: 8, chapterCount: 150) == nil)
        #expect(ChapterGridView.target(from: 142, moving: .down, columns: 8, chapterCount: 150) == 150)
        #expect(ChapterGridView.target(from: 150, moving: .right, columns: 8, chapterCount: 150) == nil)
        #expect(ChapterGridView.rowCount(chapters: 150, columns: 8) == 19)
        #expect(ChapterGridView.cursorRect(chapter: 150, columns: 8, metrics: Self.base).origin.y == CGFloat(18 * 48))
        #expect(ChapterGridView.rowCount(chapters: 1, columns: 8) == 1)
    }

    /// ⌘+ or a drag changes the column count: with the grid focused, the cursor's cell (Psalm 119)
    /// is brought back into view; with the keyboard elsewhere the pane's scroll stays where it is.
    @Test func aNewColumnCountRevealsTheCursorOnlyWhileTheGridHasFocus() {
        #expect(ChapterGridView.chapterToRevealOnRelayout(gridFocused: true, cursor: 119) == 119)
        #expect(ChapterGridView.chapterToRevealOnRelayout(gridFocused: false, cursor: 119) == nil)
    }
}
#endif
