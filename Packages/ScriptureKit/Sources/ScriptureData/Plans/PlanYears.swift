import Foundation

/// A file that gives a month and day without a year: which years those dates are in.
public enum PlanYears {
    public struct MonthDay: Hashable, Sendable {
        public let month: Int, day: Int
        public init(month: Int, day: Int) {
            self.month = month
            self.day = day
        }
    }

    public struct Placed: Equatable, Sendable {
        /// nil for no date given, and for a day that does not exist in its year.
        public let days: [PlanDay?]
        /// The year each given date falls in.
        public let years: [Int?]

        public init(days: [PlanDay?], years: [Int?]) {
            self.days = days
            self.years = years
        }
    }

    static let monthNames = ["january", "february", "march", "april", "may", "june", "july",
                             "august", "september", "october", "november", "december"]
    private static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    /// The month as its first three letters, in English: "Feb".
    static func abbreviation(ofMonth month: Int) -> String {
        monthNames[month - 1].prefix(1).uppercased() + monthNames[month - 1].dropFirst().prefix(2)
    }

    /// "Sept 15", "Sep 15", "Feb 29", "15 Nov": a month by its first three letters and a day that month can have.
    public static func monthDay(_ text: String) -> MonthDay? {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count == 2 else { return nil }
        for (nameWord, dayWord) in [(words[0], words[1]), (words[1], words[0])] {
            let name = nameWord.trimmingCharacters(in: CharacterSet(charactersIn: ".,")).lowercased()
            guard name.count >= 3, name.allSatisfy(\.isLetter),
                  let index = monthNames.firstIndex(where: { $0.hasPrefix(name) }),
                  dayWord.allSatisfy({ $0.isASCII && $0.isNumber }), let day = Int(dayWord),
                  day >= 1, day <= daysInMonth[index] else { continue }
            return MonthDay(month: index + 1, day: day)
        }
        return nil
    }

    /// Years counted on from `firstYear`, one more each time a date is earlier in the year than the date before it.
    public static func place(_ dates: [MonthDay?], firstYear: Int) -> Placed {
        var year = firstYear
        var previous: MonthDay?
        var days: [PlanDay?] = []
        var years: [Int?] = []
        for date in dates {
            guard let date else {
                days.append(nil)
                years.append(nil)
                continue
            }
            if let previous, (date.month, date.day) < (previous.month, previous.day) { year += 1 }
            previous = date
            days.append(PlanDay(year: year, month: date.month, day: date.day))
            years.append(year)
        }
        return Placed(days: days, years: years)
    }

    /// The first year for dates that carry none. The only place a year is chosen: a different rule changes here and nowhere else.
    ///
    /// A year that keeps the calendar (every date exists and all fall on one weekday, which a plan that meets weekly does) is taken
    /// when exactly one does. Otherwise, among those that do (or among every candidate when none does), the earliest year that puts
    /// `today` inside the plan's span; when none does, the one that brings the span nearest to today (the earlier on a tie).
    public static func firstYear(for dates: [MonthDay?], today: PlanDay) -> Int {
        struct Candidate { let year: Int, first: PlanDay, last: PlanDay, keepsCalendar: Bool }
        var candidates: [Candidate] = []
        for year in (today.year - 5)...(today.year + 1) {
            let placed = place(dates, firstYear: year)
            let existing = placed.days.compactMap { $0 }
            guard let first = existing.min(), let last = existing.max() else { return today.year }
            let allExist = placed.days.indices.allSatisfy { dates[$0] == nil || placed.days[$0] != nil }
            let oneWeekday = existing.allSatisfy { first.days(until: $0) % 7 == 0 }
            candidates.append(Candidate(year: year, first: first, last: last, keepsCalendar: allExist && oneWeekday))
        }
        let keeping = candidates.filter(\.keepsCalendar)
        if keeping.count == 1 { return keeping[0].year }
        let pool = keeping.isEmpty ? candidates : keeping
        if let holding = pool.first(where: { $0.first <= today && today <= $0.last }) { return holding.year }
        func distance(_ candidate: Candidate) -> Int {
            today < candidate.first ? today.days(until: candidate.first) : candidate.last.days(until: today)
        }
        return pool.min { (distance($0), $0.year) < (distance($1), $1.year) }?.year ?? today.year
    }
}
