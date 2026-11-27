import Foundation

/// From the church's table to a draft the review shows (spec 6.1, 6.2).
public enum PlanImport {
    /// The file's name without its extension, underscores as spaces, runs of spaces as one: "Gen 1_ RTS Reading Plan.pdf" is "Gen 1 RTS Reading Plan".
    public static func title(forFileNamed name: String) -> String {
        (name as NSString).deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    public static func draft(from table: PlanTable, title: String, today: PlanDay) -> PlanDraft {
        var weeks: [PlanDraft.Week] = []
        for week in table.weeks {
            let number = week.number ?? (weeks.last?.number ?? 0) + 1
            let labels = Set(week.rows.filter { $0.wisdomChapters.isEmpty && !$0.wisdomBook.isEmpty }.map(\.wisdomBook))
            let merged = labels.count == 1 ? labels.first : nil
            let readings = week.rows.map { row in
                var row = row
                if row.wisdomBook.isEmpty, row.wisdomChapters.isEmpty, let merged { row.wisdomBook = merged }
                return PlanDraft.Reading(text: line(for: row))
            }
            let date = table.hasDates ? dateCell(week.dateText) : (monthDay: nil, label: "")
            weeks.append(PlanDraft.Week(number: number, label: date.label, readings: readings, monthDay: date.monthDay))
        }
        let monthDays = weeks.map(\.monthDay)
        guard monthDays.contains(where: { $0 != nil }) else { return PlanDraft(title: title, weeks: weeks, firstYear: nil) }
        let year = PlanYears.firstYear(for: monthDays, today: today)
        let placed = PlanYears.place(monthDays, firstYear: year)
        for index in weeks.indices { weeks[index].day = placed.days[index] }
        return PlanDraft(title: title, weeks: weeks, firstYear: year)
    }

    /// The Wisdom passage, then the others, joined by "; ", then " (label)".
    static func line(for row: PlanTable.Row) -> String {
        var passages: [String] = []
        var label: String?
        if !row.wisdomChapters.isEmpty {
            passages.append(passage(row.wisdomBook, row.wisdomChapters))
        } else if !row.wisdomBook.isEmpty {
            label = row.wisdomBook
        }
        if !row.otherBook.isEmpty || !row.otherChapters.isEmpty {
            passages += books(in: row.otherBook).map { passage($0, row.otherChapters) }
        }
        var text = passages.joined(separator: "; ")
        if let label { text = text.isEmpty ? label : "\(text) (\(label))" }
        return text.replacingOccurrences(of: "–", with: "-")
    }

    private static func passage(_ book: String, _ chapters: String) -> String {
        [book, chapters].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// A book cell with commas is several books; a part that is a number alone takes the next part's name ("2,3 John, Jude" is 2 John, 3 John, Jude).
    private static func books(in cell: String) -> [String] {
        let parts = cell.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard parts.count > 1 else { return [cell] }
        func isNumber(_ text: String) -> Bool { text.allSatisfy { $0.isASCII && $0.isNumber } }
        func name(_ part: String) -> String {
            let words = part.split(separator: " ")
            return words.count > 1 && isNumber(String(words[0])) ? words.dropFirst().joined(separator: " ") : part
        }
        return parts.indices.map { index in
            guard isNumber(parts[index]), let next = parts[(index + 1)...].first(where: { !isNumber($0) }) else { return parts[index] }
            return "\(parts[index]) \(name(next))"
        }
    }

    /// Split at its first " / " or " - ": a month and day, then the label. A first part that is no date makes the whole cell the label.
    private static func dateCell(_ text: String) -> (monthDay: PlanYears.MonthDay?, label: String) {
        let cell = text.trimmingCharacters(in: .whitespaces)
        let split = [" / ", " - "].compactMap { cell.range(of: $0) }.min { $0.lowerBound < $1.lowerBound }
        let first = split.map { String(cell[..<$0.lowerBound]) } ?? cell
        guard let monthDay = PlanYears.monthDay(first) else { return (nil, cell) }
        let rest = split.map { String(cell[$0.upperBound...]) } ?? ""
        return (monthDay, rest.trimmingCharacters(in: .whitespaces))
    }
}
