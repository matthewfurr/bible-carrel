import Foundation

/// A plan in the editor's own text form (spec 6.3).
public enum PlanText {
    /// A text file or pasted text.
    public static func draft(from text: String, title: String, today: PlanDay) -> PlanDraft {
        let read = weeks(from: text, today: today)
        return PlanDraft(title: title, weeks: read.weeks, firstYear: read.firstYear)
    }

    /// `Week 63 2026-11-17 Leader Dinner`, then the week's lines, one blank line between weeks.
    public static func text(for plan: ReadingPlan) -> String {
        plan.weeks.map { week in
            var header = "Week \(week.number)"
            if let day = week.day { header += " \(day.iso)" }
            if let label = week.label, !label.isEmpty { header += " \(label)" }
            return ([header] + week.readings.map(PlanReadingText.line(for:))).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    static func weeks(from text: String, today: PlanDay) -> (weeks: [PlanDraft.Week], firstYear: Int?) {
        var weeks: [PlanDraft.Week] = []
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if let header = header(line) {
                weeks.append(header)
            } else {
                if weeks.isEmpty { weeks.append(PlanDraft.Week(number: 1, readings: [])) }
                weeks[weeks.count - 1].readings.append(PlanDraft.Reading(text: line))
            }
        }
        let monthDays = weeks.map(\.monthDay)
        guard monthDays.contains(where: { $0 != nil }) else { return (weeks, nil) }
        let year = PlanYears.firstYear(for: monthDays, today: today)
        let placed = PlanYears.place(monthDays, firstYear: year)
        for index in weeks.indices where weeks[index].monthDay != nil { weeks[index].day = placed.days[index] }
        return (weeks, year)
    }

    /// "Week 13 Nov 24 - OFF": "Week" or "Wk", a number, then maybe a date, then maybe a label.
    private static func header(_ line: String) -> PlanDraft.Week? {
        let lower = line.lowercased()
        guard let keyword = ["week", "wk"].first(where: { lower.hasPrefix($0) }) else { return nil }
        var rest = Substring(line.dropFirst(keyword.count)).drop { $0.isWhitespace }
        let digits = rest.prefix { $0.isASCII && $0.isNumber }
        guard let number = Int(digits), rest.dropFirst(digits.count).first.map({ $0.isWhitespace }) ?? true else { return nil }
        rest = rest.dropFirst(digits.count)
        let words = rest.split(whereSeparator: \.isWhitespace).map(String.init)
        var week = PlanDraft.Week(number: number, readings: [])
        var used = 0
        if let first = words.first, let day = PlanDay(iso: first) {
            week.day = day
            used = 1
        } else if words.count >= 2, let monthDay = PlanYears.monthDay("\(words[0]) \(words[1])") {
            week.monthDay = monthDay
            used = 2
        }
        let label = words.dropFirst(used).joined(separator: " ")
            .drop { $0 == "/" || $0 == "-" || $0 == "·" || $0.isWhitespace }
        week.label = String(label)
        return week
    }
}
