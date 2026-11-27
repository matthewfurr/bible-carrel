import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct PlanWindowStateTests {
    @Test func theWindowOpensOnThisWeek() {
        let today = PlanDay(year: 2026, month: 11, day: 16)!
        let plan = PlanSample.gen2Shaped(today: today)
        var state = PlanWindowState()
        state.open(on: plan, now: PlanSchedule.now(plan.weeks, today: today))
        #expect(state.chosenWeek == 52)
        state.move(by: 1, count: 86)
        state.move(by: -3, count: 86)
        #expect(state.chosenWeek == 50)
        state.choose(85)
        state.move(by: 1, count: 86)
        #expect(state.chosenWeek == 85)                                                              // held at the end
        state.open(on: plan, now: .finished)
        #expect(state.chosenWeek == 85)
        state.open(on: PlanSample.gen1Shaped(), now: .undated)
        #expect(state.chosenWeek == 0)
        state.open(on: nil, now: nil)
        #expect(state.chosenWeek == nil)
        var unreadable = plan
        unreadable.isReadable = false
        unreadable.weeks = []
        state.open(on: unreadable, now: nil)
        #expect(state.chosenWeek == nil)
    }

    /// M3: at midnight after the meeting, a window left on this week moves to the new this week;
    /// a window on another week stays there.
    @Test func theWindowFollowsTheDayFromThisWeek() {
        let today = PlanDay(year: 2026, month: 11, day: 16)!
        let plan = PlanSample.gen2Shaped(today: today)
        var state = PlanWindowState()
        state.open(on: plan, now: .week(index: 52))
        state.dayChanged(from: .week(index: 52), to: .week(index: 53), on: plan)
        #expect(state.chosenWeek == 53)
        state.choose(10)
        state.dayChanged(from: .week(index: 53), to: .week(index: 54), on: plan)
        #expect(state.chosenWeek == 10)
        state.choose(85)
        state.dayChanged(from: .week(index: 85), to: .finished, on: plan)
        #expect(state.chosenWeek == 85)
        state.dayChanged(from: .week(index: 85), to: .week(index: 85), on: plan)
        #expect(state.chosenWeek == 85)
    }
}
