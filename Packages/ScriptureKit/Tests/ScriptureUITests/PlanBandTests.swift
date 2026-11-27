import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// When the Mac's "This week" band shows over the front page's contents.
@Suite struct PlanBandTests {
    @Test func theBandShowsOverTheContentsWhileAPlanIsFollowedAndNotFinished() {
        #expect(FrontPageView.showsBand(showsWeek: true, libraryViewOpen: false))
        #expect(!FrontPageView.showsBand(showsWeek: true, libraryViewOpen: true))          // People, Places and About have a header of their own
        #expect(!FrontPageView.showsBand(showsWeek: false, libraryViewOpen: false))        // no plan, no dates yet, or finished
    }

    /// The band is the window less the pane at its narrowest at 18 (316 pt) and `lg` at each side:
    /// 736 pt at 1100, 456 at 820. Five readings wrap 4 and 1 at the usual window.
    @Test func fourReadingsSitInOneRowAtTheUsualWindowWidth() {
        let minimum = PlanWeekSummary.minimumColumnWidth
        let pane = ChapterPaneMetrics(readerSize: 18).narrowestWidth
        #expect(PlanWeekSummary.columnCount(width: 1100 - pane - 2 * AppSpacing.lg, minimum: minimum) == 4)
        #expect(PlanWeekSummary.columnCount(width: 820 - pane - 2 * AppSpacing.lg, minimum: minimum) == 3)   // five wrap to a second row
        #expect(PlanWeekSummary.columnCount(width: 100, minimum: minimum) == 1)
    }
}

/// The plan model's undo goes to the window that is acting, never to one that has closed.
@MainActor @Suite struct PlanUndoWindowTests {
    @Test func theUndoManagerIsTheActingWindowsAndAClosedWindowLetsItGo() throws {
        let fixture = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        let main = UndoManager()
        let planWindow = UndoManager()
        fixture.model.adoptUndoManager(planWindow)
        fixture.model.adoptUndoManager(main)                                                  // the main window became key
        fixture.model.releaseUndoManager(planWindow)                                          // the plan window closed: not its manager now
        #expect(fixture.model.undoManager === main)
        fixture.model.adoptUndoManager(planWindow)
        fixture.model.releaseUndoManager(planWindow)                                          // closed while it held it
        #expect(fixture.model.undoManager == nil)
    }
}
