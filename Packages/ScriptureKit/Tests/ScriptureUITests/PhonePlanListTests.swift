import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The iPhone's Plan tab, row by row: this week at its head with the weeks before above it and
/// the weeks after below, a week opened in place, a finished plan and one with no dates.
@Suite struct PhonePlanListTests {
    @Test func thisWeekIsAtTheHeadWithTheWeeksBeforeAboveAndAfterBelow() {
        let today = PlanDay(year: 2026, month: 11, day: 16)!
        let plan = PlanSample.gen2Shaped(today: today)
        func readings(_ week: Int) -> [PhonePlanList.Row] { plan.weeks[week].readings.map { PhonePlanList.Row.reading(week: week, id: $0.id) } }
        let list = PhonePlanList(plan: plan, now: .week(index: 52), openWeek: nil)
        #expect(list.rows.count == 52 + 1 + 4 + 1 + 33 && list.rows[51] == .week(51) && list.rows[52] == .thisWeek)
        #expect(Array(list.rows[53...56]) == readings(52) && list.rows[57] == .next && list.rows[58] == .week(53))
        #expect(list.scrollTarget == .thisWeek && !list.rows.contains(.week(52)))
        let open = PhonePlanList(plan: plan, now: .week(index: 52), openWeek: 85)
        #expect(Array(open.rows.suffix(4)) == [.week(85)] + readings(85))
        let last = PhonePlanList(plan: plan, now: .week(index: 85), openWeek: nil)
        #expect(!last.rows.contains(.next) && Array(last.rows.suffix(3)) == readings(85))
        let finished = PhonePlanList(plan: plan, now: .finished, openWeek: nil)
        #expect(finished.rows.first == .finished && finished.rows.count == 87 && finished.scrollTarget == nil)
        let undated = PhonePlanList(plan: PlanSample.gen1Shaped(), now: .undated, openWeek: 0)
        #expect(undated.rows.first == .anchor && undated.rows[1] == .week(0) && undated.rows.count == 1 + 67 + 5)
    }

    /// A week opened above this week has its readings under its row; a this week the plan does not
    /// have (a reload that shortened it) lists every week and scrolls nowhere.
    @Test func anEarlierOpenWeekAndAThisWeekOutOfRange() {
        let plan = PlanSample.gen2Shaped(today: PlanDay(year: 2026, month: 11, day: 16)!)
        let readings = plan.weeks[3].readings.map { PhonePlanList.Row.reading(week: 3, id: $0.id) }
        let open = PhonePlanList(plan: plan, now: .week(index: 52), openWeek: 3)
        #expect(Array(open.rows[3...7]) == [.week(3)] + readings && open.rows[8] == .week(4) && open.rows[56] == .thisWeek)
        let gone = PhonePlanList(plan: plan, now: .week(index: 99), openWeek: nil)
        #expect(gone.rows == plan.weeks.indices.map { .week($0) } && gone.scrollTarget == nil)
    }
}

#if os(iOS)
import SwiftUI
import UIKit

/// The copy of the Plan tab built out of sight to warm it runs none of the shown tab's side effects.
@MainActor @Suite struct PhonePlanWarmUpTests {
    @Test func theWarmUpCopyNeitherReloadsNorTakesTheUndoManager() throws {
        let fixture = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        try fixture.store.save(PlanModelFixture.small)                  // stored, and not yet reloaded
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.isHidden = false
        defer { window.isHidden = true }
        window.rootViewController = UIHostingController(rootView: PhonePlanScreen.warmUpCopy(plans: fixture.model, shell: PhoneShellModel()))
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date())
        #expect(fixture.model.plans.isEmpty && fixture.model.undoManager == nil)
        window.rootViewController = UIHostingController(rootView: PhonePlanScreen(plans: fixture.model, shell: PhoneShellModel()))
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date())
        #expect(fixture.model.plans.count == 1)                          // the shown tab reloads
    }
}
#endif
