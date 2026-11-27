import Foundation
import ScriptureData

/// The words a plan's week is shown in, on the front page's band, in the plan window, in the
/// sidebar and to VoiceOver. Every date is written here and nowhere else, as the system writes it
/// for the locale: changing `format` changes every one.
public enum PlanWeekText {
    public static let finishedLine = "You have finished this plan."
    public static let unreadableLine = "This plan was made by a newer version of Bible Carrel."
    public static let noWeeksLine = "This plan has no weeks yet."

    /// What the plan window and the Plan tab say in place of the weeks: a plan this build cannot
    /// read, and one it can that has no weeks, each its own line; nil when there are weeks to show.
    public static func placeholderLine(for plan: ReadingPlan) -> String? {
        if !plan.isReadable { return unreadableLine }
        return plan.weeks.isEmpty ? noWeeksLine : nil
    }

    /// `"Week 63 of 67 · meets Tue, Nov 17"`; on the day, `"… meets today, Tue, Nov 17"`; a label
    /// follows (`" · OFF"`); a week with no date is `"Week 63 of 67"`.
    public static func titleLine(_ week: PlanWeek, count: Int, today: PlanDay, locale: Locale, calendar: Calendar) -> String {
        var parts = ["Week \(week.number) of \(count)"]
        if let day = week.day {
            let written = format(day, .short, locale: locale, calendar: calendar)
            parts.append("meets " + (day == today ? "today, " : "") + written)
        }
        if let label = week.label { parts.append(label) }
        return parts.joined(separator: " · ")
    }

    /// `"Meets Tuesday, November 17 · 2 of 5 read · Leader Dinner"`.
    public static func detailLine(_ week: PlanWeek, progress: PlanProgress, locale: Locale, calendar: Calendar) -> String {
        var parts: [String] = []
        if let day = week.day { parts.append("Meets " + format(day, .long, locale: locale, calendar: calendar)) }
        parts.append(readCount(progress))
        if let label = week.label { parts.append(label) }
        return parts.joined(separator: " · ")
    }

    /// `"Nov 17 · done"`, `"Nov 17 · 3 of 5"`, `"Nov 17"`; with no date `"3 of 5"` or `""`.
    public static func sidebarLine(_ week: PlanWeek, progress: PlanProgress, locale: Locale, calendar: Calendar) -> String {
        var parts: [String] = []
        if let day = week.day { parts.append(format(day, .abbreviated, locale: locale, calendar: calendar)) }
        if let label = progress.label { parts.append(label) }
        return parts.joined(separator: " · ")
    }

    /// `"Week 63, Tuesday, November 17, 3 of 5 read"`.
    public static func spokenWeek(_ week: PlanWeek, progress: PlanProgress, locale: Locale, calendar: Calendar) -> String {
        var parts = ["Week \(week.number)"]
        if let day = week.day { parts.append(format(day, .long, locale: locale, calendar: calendar)) }
        parts.append(readCount(progress))
        if let label = week.label { parts.append(label) }
        return parts.joined(separator: ", ")
    }

    /// `"Reading 3 of 5, Psalms 84, Esther 7 to 8, not read"`; a label comes after the passages.
    public static func spoken(_ reading: PlanReading, index: Int, count: Int, isTicked: Bool) -> String {
        var parts = ["Reading \(index + 1) of \(count)"]
        parts.append(contentsOf: reading.passages.map(\.spokenString))
        if let label = reading.label { parts.append(label) }
        parts.append(isTicked ? "read" : "not read")
        return parts.joined(separator: ", ")
    }

    /// The editor's week header to VoiceOver: `"Week 63, Tuesday, November 17"`; `"Week 63"` with no date.
    public static func spokenHeader(number: Int, day: PlanDay?, locale: Locale, calendar: Calendar) -> String {
        guard let day else { return "Week \(number)" }
        return "Week \(number), " + format(day, .long, locale: locale, calendar: calendar)
    }

    /// The review's first date, with its year: `"Tuesday, September 15, 2026"`.
    public static func dateWithYear(_ day: PlanDay, locale: Locale, calendar: Calendar) -> String {
        format(day, .longWithYear, locale: locale, calendar: calendar)
    }

    private static func readCount(_ progress: PlanProgress) -> String {
        "\(progress.read) of \(progress.total) read"
    }

    private enum DayForm { case abbreviated, short, long, longWithYear }

    /// The one place a date becomes text: the system's order and wording for `locale`, in the
    /// calendar's own time zone. `.abbreviated` is "Nov 17", `.short` "Tue, Nov 17", `.long`
    /// "Tuesday, November 17" in the US.
    private static func format(_ day: PlanDay, _ form: DayForm, locale: Locale, calendar: Calendar) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let date = day.date(in: calendar)
        switch form {
        case .abbreviated: return date.formatted(style.month(.abbreviated).day())
        case .short: return date.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
        case .long: return date.formatted(style.weekday(.wide).month(.wide).day())
        case .longWithYear: return date.formatted(style.weekday(.wide).month(.wide).day().year())
        }
    }
}
