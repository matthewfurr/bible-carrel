import Foundation

/// Made-up plans in the church's shapes, for tests, renders and the Debug probe. No real plan is in the app.
public enum PlanSample {
    public static let standInID = UUID(uuidString: "5D000000-0000-4000-8000-000000000001")!
    public static let largeID = UUID(uuidString: "5D000000-0000-4000-8000-000000000002")!
    public static let gen1ID = UUID(uuidString: "5D000000-0000-4000-8000-000000000003")!

    private static let epoch = Date(timeIntervalSince1970: 0)

    /// Fixed by the plan, the week and the row, so two calls are equal.
    private static func readingID(plan: Int, week: Int, row: Int) -> UUID {
        UUID(uuidString: String(format: "5D%06X-0000-4000-8000-%04X%08X", plan, week, row))!
    }

    /// The i-th reading of a plan (from 0): Psalms `i % 150 + 1` with Genesis `3 * (i % 16) + 1` to `+ 3`.
    private static func passages(_ index: Int) -> (psalm: PlanPassage, genesis: PlanPassage) {
        let first = 3 * (index % 16) + 1
        return (PlanPassage(book: "PSA", chapter: index % 150 + 1),
                PlanPassage(book: "GEN", chapter: first, endChapter: first + 2))
    }

    private static func make(plan: Int, counts: [Int], label: (Int) -> String?, readingLabel: (Int) -> String?,
                             genesisOnly: (Int) -> Bool, day: (Int) -> PlanDay?) -> [PlanWeek] {
        var index = 0
        var weeks: [PlanWeek] = []
        for (offset, count) in counts.enumerated() {
            let number = offset + 1
            var readings: [PlanReading] = []
            for row in 0..<count {
                let pair = passages(index)
                readings.append(PlanReading(id: readingID(plan: plan, week: number, row: row),
                                            label: readingLabel(number),
                                            passages: genesisOnly(number) ? [pair.genesis] : [pair.psalm, pair.genesis]))
                index += 1
            }
            weeks.append(PlanWeek(number: number, day: day(number), label: label(number), readings: readings))
        }
        return weeks
    }

    public static func gen1Shaped() -> ReadingPlan {
        let weeks = make(plan: 1, counts: Array(repeating: 5, count: 67), label: { _ in nil },
                         readingLabel: { _ in nil }, genesisOnly: { _ in false }, day: { _ in nil })
        return ReadingPlan(id: gen1ID, title: "RTS Gen 1 (sample)", createdAt: epoch, modifiedAt: epoch, weeks: weeks)
    }

    public static func gen2Shaped(today: PlanDay, thisWeek: Int = 53) -> ReadingPlan {
        let counts = (1...86).map { $0 <= 77 ? 4 : 3 }
        let weeks = make(plan: 2, counts: counts,
                         label: { number in
                             switch number {
                             case 1, 8, 14: "Leader Dinner"
                             case 5: "Meet in Homes"
                             case 10, 11, 15, 16: "OFF"
                             default: nil
                             }
                         },
                         readingLabel: { $0 == 55 ? "NT Focus" : nil },
                         genesisOnly: { $0 == 55 },
                         day: { today.adding(days: 7 * ($0 - thisWeek)) })
        return ReadingPlan(id: largeID, title: "RTS Gen 2 (sample)", createdAt: epoch, modifiedAt: epoch, weeks: weeks)
    }

    public static func standIn(today: PlanDay) -> ReadingPlan {
        let lines = [["Psalms 1; Genesis 1-3", "Psalms 2; Genesis 4-6"],
                     ["John 1-2 (NT Focus)", "2 John 1; 3 John 1; Jude 1"]]
        let weeks = lines.enumerated().map { offset, rows in
            PlanWeek(number: offset + 1, day: today.adding(days: 1 + 7 * offset), label: nil,
                     readings: rows.enumerated().map { row, text in
                         let parsed = try! PlanReadingText.parse(text).get()
                         return PlanReading(id: readingID(plan: 3, week: offset + 1, row: row), label: parsed.label, passages: parsed.passages)
                     })
        }
        return ReadingPlan(id: standInID, title: "Stand-in plan", createdAt: epoch, modifiedAt: epoch, weeks: weeks)
    }
}
