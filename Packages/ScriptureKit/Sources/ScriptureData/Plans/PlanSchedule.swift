import Foundation

public enum PlanSchedule {
    public enum Now: Equatable, Sendable { case week(index: Int), finished, undated }

    /// The first week with a date that is today or later. A week with no date is passed over.
    public static func now(_ weeks: [PlanWeek], today: PlanDay) -> Now {
        guard weeks.contains(where: { $0.day != nil }) else { return .undated }
        let index = weeks.firstIndex { week in week.day.map { $0 >= today } ?? false }
        return index.map { .week(index: $0) } ?? .finished
    }

    /// When the week had a date, every later dated week moves by the same number of days; when it had none, nothing else moves.
    public static func settingDay(_ day: PlanDay, ofWeek index: Int, in weeks: [PlanWeek]) -> [PlanWeek] {
        guard weeks.indices.contains(index) else { return weeks }
        var result = weeks
        let old = weeks[index].day
        result[index].day = day
        guard let old else { return result }
        let shift = old.days(until: day)
        for later in result.indices where later > index {
            if let moved = result[later].day { result[later].day = moved.adding(days: shift) }
        }
        return result
    }

    /// Week `index` meets on `day`; every week is seven days from its neighbour, earlier weeks backwards.
    public static func anchored(_ weeks: [PlanWeek], week index: Int, on day: PlanDay) -> [PlanWeek] {
        var result = weeks
        for place in result.indices {
            result[place].day = day.adding(days: 7 * (place - index))
        }
        return result
    }
}
