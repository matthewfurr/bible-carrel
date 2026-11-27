import Foundation
import ScriptureData

/// Which week the plan window shows: the selection is the only state, so the keys work whichever
/// row is on screen.
public struct PlanWindowState: Equatable, Sendable {
    /// An index into the followed plan's weeks.
    public private(set) var chosenWeek: Int?

    public init() {}

    /// This week; the last week of a finished plan; the first of a plan with no dates; nil with no
    /// plan or an unreadable one.
    public mutating func open(on plan: ReadingPlan?, now: PlanSchedule.Now?) {
        guard let plan, plan.isReadable, !plan.weeks.isEmpty else {
            chosenWeek = nil
            return
        }
        switch now {
        case .week(let index)?: chosenWeek = min(max(index, 0), plan.weeks.count - 1)
        case .finished?: chosenWeek = plan.weeks.count - 1
        case .undated?, nil: chosenWeek = 0
        }
    }

    /// The day changed (midnight after a meeting): a window left on this week moves to the new
    /// this week; one on any other week stays where it is.
    public mutating func dayChanged(from old: PlanSchedule.Now?, to new: PlanSchedule.Now?, on plan: ReadingPlan?) {
        guard old != new, case .week(let index)? = old, chosenWeek == index else { return }
        open(on: plan, now: new)
    }

    public mutating func choose(_ index: Int) {
        chosenWeek = index
    }

    /// Held at both ends; with nothing chosen, the first week.
    public mutating func move(by step: Int, count: Int) {
        guard count > 0 else { return }
        let current = chosenWeek ?? 0
        chosenWeek = min(max(current + (chosenWeek == nil ? 0 : step), 0), count - 1)
    }
}
