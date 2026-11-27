import Foundation
import ScriptureData

/// The Plan tab's rows, in order. With a week that is this week: every earlier week, then "This
/// week" with its readings, "Next" when a week follows, then every later week; the tab opens
/// scrolled so this week is at its head. A finished plan says so above every week, and a plan
/// with no dates asks for one above them. One week at a time is opened in place under its row,
/// as a book is in the Library; this week's readings are always shown and it has no row to open.
/// Platform-neutral, so it is tested on the Mac too.
public struct PhonePlanList: Equatable, Sendable {
    public enum Row: Hashable, Sendable {
        case finished, anchor, week(Int), thisWeek, reading(week: Int, id: UUID), next
    }

    public let rows: [Row]
    /// `.thisWeek`; nil when there is none.
    public let scrollTarget: Row?

    public init(plan: ReadingPlan, now: PlanSchedule.Now, openWeek: Int?) {
        let weeks = plan.weeks
        var rows: [Row] = []
        func readings(of index: Int) {
            rows.append(contentsOf: weeks[index].readings.map { .reading(week: index, id: $0.id) })
        }
        func weekRows(_ range: Range<Int>) {
            for index in range {
                rows.append(.week(index))
                if index == openWeek { readings(of: index) }
            }
        }
        switch now {
        case .week(let index) where weeks.indices.contains(index):
            weekRows(0..<index)
            rows.append(.thisWeek)
            readings(of: index)
            if index + 1 < weeks.count { rows.append(.next) }
            weekRows(index + 1..<weeks.count)
            scrollTarget = .thisWeek
        case .finished:
            rows.append(.finished)
            weekRows(weeks.indices)
            scrollTarget = nil
        case .undated:
            rows.append(.anchor)
            weekRows(weeks.indices)
            scrollTarget = nil
        case .week:
            weekRows(weeks.indices)
            scrollTarget = nil
        }
        self.rows = rows
    }
}
