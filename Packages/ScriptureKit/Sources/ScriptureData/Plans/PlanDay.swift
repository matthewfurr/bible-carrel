import Foundation

/// A calendar day. A meeting date is never an instant.
public struct PlanDay: Hashable, Comparable, Sendable {
    public let year: Int, month: Int, day: Int

    /// Arithmetic on days is done in UTC so no zone or daylight-saving change can move a day.
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// nil for a day that does not exist (29 Feb 2027).
    public init?(year: Int, month: Int, day: Int) {
        guard let date = Self.utc.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let parts = Self.utc.dateComponents([.year, .month, .day], from: date)
        guard parts.year == year, parts.month == month, parts.day == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`.
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    /// `"2026-11-17"`.
    public init?(iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private var utcDate: Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int) -> PlanDay {
        let moved = Self.utc.date(byAdding: .day, value: days, to: utcDate) ?? utcDate
        return PlanDay(moved, calendar: Self.utc)
    }

    public func days(until other: PlanDay) -> Int {
        Self.utc.dateComponents([.day], from: utcDate, to: other.utcDate).day ?? 0
    }

    /// That day's start in `calendar`.
    public func date(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? utcDate
    }

    public static func < (lhs: PlanDay, rhs: PlanDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
