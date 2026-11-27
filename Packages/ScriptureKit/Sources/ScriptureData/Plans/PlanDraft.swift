import Foundation

/// What the review and the editor edit. A reading is its line of text until the plan is saved.
public struct PlanDraft: Equatable, Sendable {
    public struct Reading: Identifiable, Equatable, Sendable {
        public let id: UUID
        public var text: String

        public init(id: UUID = UUID(), text: String) {
            self.id = id
            self.text = text
        }
    }

    public struct Week: Identifiable, Equatable, Sendable {
        /// The editor's own; not stored.
        public let id: UUID
        public var number: Int
        /// Set through `setDay(_:ofWeek:)`, which keeps `monthDay` right; a date set here directly
        /// would be placed again by `setFirstYear`.
        public internal(set) var day: PlanDay?
        /// "" for none.
        public var label: String
        public var readings: [Reading]
        /// The file's own month and day, until the date is set or moved by hand.
        public var monthDay: PlanYears.MonthDay?

        public init(id: UUID = UUID(), number: Int, day: PlanDay? = nil, label: String = "", readings: [Reading], monthDay: PlanYears.MonthDay? = nil) {
            self.id = id
            self.number = number
            self.day = day
            self.label = label
            self.readings = readings
            self.monthDay = monthDay
        }
    }

    /// nil for a new plan.
    public var planID: UUID?
    public var createdAt: Date?
    public var title: String
    public var weeks: [Week]
    /// Set when a file gave dates without a year.
    public var firstYear: Int?

    /// New Plan: week 1, no date, one empty reading.
    public init(title: String) {
        self.title = title
        self.weeks = [Week(number: 1, readings: [Reading(text: "")])]
    }

    init(title: String, weeks: [Week], firstYear: Int?) {
        self.title = title
        self.weeks = weeks
        self.firstYear = firstYear
    }

    /// Edit Plan…: every reading keeps its id.
    public init(plan: ReadingPlan) {
        planID = plan.id
        createdAt = plan.createdAt
        title = plan.title
        weeks = plan.weeks.map { week in
            Week(number: week.number, day: week.day, label: week.label ?? "",
                 readings: week.readings.map { Reading(id: $0.id, text: PlanReadingText.line(for: $0)) })
        }
    }

    public var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !weeks.isEmpty else { return false }
        return weeks.allSatisfy { week in
            week.readings.allSatisfy { Self.isBlank($0.text) || (try? PlanReadingText.parse($0.text).get()) != nil }
        }
    }

    /// nil unless `canSave`.
    public func plan(now: Date) -> ReadingPlan? {
        guard canSave else { return nil }
        let planWeeks = weeks.map { week in
            let label = week.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let readings: [PlanReading] = week.readings.compactMap { reading in
                guard !Self.isBlank(reading.text), let parsed = try? PlanReadingText.parse(reading.text).get() else { return nil }
                return PlanReading(id: reading.id, label: parsed.label, passages: parsed.passages)
            }
            return PlanWeek(number: week.number, day: week.day, label: label.isEmpty ? nil : label, readings: readings)
        }
        return ReadingPlan(id: planID ?? UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                           createdAt: createdAt ?? now, modifiedAt: now, weeks: planWeeks)
    }

    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// After the last, numbered one more, dated seven days after it when it has a date.
    public mutating func addWeek() {
        weeks.append(Week(number: (weeks.last?.number ?? 0) + 1, day: weeks.last?.day?.adding(days: 7), readings: [Reading(text: "")]))
    }

    public mutating func removeWeek(_ id: UUID) {
        weeks.removeAll { $0.id == id }
    }

    public mutating func addReading(toWeek id: UUID) {
        guard let index = weeks.firstIndex(where: { $0.id == id }) else { return }
        weeks[index].readings.append(Reading(text: ""))
    }

    public mutating func removeReading(_ id: UUID) {
        for index in weeks.indices { weeks[index].readings.removeAll { $0.id == id } }
    }

    /// The same move SwiftUI's `onMove` asks for.
    public mutating func moveReadings(inWeek id: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard let index = weeks.firstIndex(where: { $0.id == id }) else { return }
        let readings = weeks[index].readings
        let moving = fromOffsets.filter { readings.indices.contains($0) }.map { readings[$0] }
        var rest = readings.enumerated().filter { !fromOffsets.contains($0.offset) }.map(\.element)
        let insertAt = max(0, min(rest.count, toOffset - fromOffsets.filter { $0 < toOffset }.count))
        rest.insert(contentsOf: moving, at: insertAt)
        weeks[index].readings = rest
    }

    /// `PlanSchedule.settingDay`'s rule. The week set, and every week that moved with it, no longer follows the file's own date.
    public mutating func setDay(_ day: PlanDay?, ofWeek id: UUID) {
        guard let index = weeks.firstIndex(where: { $0.id == id }) else { return }
        weeks[index].monthDay = nil
        guard let day else {
            weeks[index].day = nil
            return
        }
        let before = weeks.map(\.day)
        let moved = PlanSchedule.settingDay(day, ofWeek: index, in: weeks.map {
            PlanWeek(number: $0.number, day: $0.day, label: nil, readings: [])
        })
        for place in weeks.indices where moved[place].day != before[place] {
            weeks[place].day = moved[place].day
            weeks[place].monthDay = nil
        }
    }

    /// Every week that still has the file's own month and day is placed again.
    public mutating func setFirstYear(_ year: Int) {
        firstYear = year
        let placed = PlanYears.place(weeks.map(\.monthDay), firstYear: year)
        for index in weeks.indices where weeks[index].monthDay != nil {
            weeks[index].day = placed.days[index]
        }
    }

    /// Pasted text: its weeks come after the last; a draft that is one week with one blank line and no date is replaced by them.
    public mutating func append(text: String, today: PlanDay) {
        let read = PlanText.weeks(from: text, today: today)
        guard !read.weeks.isEmpty else { return }
        let isEmpty = weeks.count == 1 && weeks[0].day == nil && weeks[0].monthDay == nil
            && weeks[0].label.isEmpty && weeks[0].readings.allSatisfy { Self.isBlank($0.text) } && weeks[0].readings.count <= 1
        if isEmpty {
            weeks = read.weeks
            firstYear = read.firstYear
        } else {
            weeks.append(contentsOf: read.weeks)
            firstYear = firstYear ?? read.firstYear
        }
    }
}
