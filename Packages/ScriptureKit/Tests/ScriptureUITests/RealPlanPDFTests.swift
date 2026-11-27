#if os(macOS)
import Foundation
import Testing
import ScriptureData
@testable import ScriptureUI

/// Spec 11: run once by the builder against the church's PDFs. They are never in the repository; this reads them where they are.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RTS_PLAN_PDFS"] != nil)) struct RealPlanPDFTests {
    private let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["RTS_PLAN_PDFS"] ?? "", isDirectory: true)
    private let today = PlanDay(year: 2026, month: 11, day: 16)!

    @Test func gen1IsSixtySevenWeeksOfFive() throws {
        let draft = try PlanFileImport.draft(fromFileAt: folder.appending(path: "Gen 1_ RTS Reading Plan.pdf"), today: today).get()
        #expect(draft.weeks.map(\.number) == Array(1...67) && draft.weeks.allSatisfy { $0.readings.count == 5 && $0.day == nil })
        #expect(draft.canSave && draft.firstYear == nil && PlanReview.flags(draft, chapterCounts: [:]).isEmpty && draft.title == "Gen 1 RTS Reading Plan")
        #expect(draft.weeks[62].readings.map(\.text) == ["Psalms 71; Esther 1-3", "Psalms 73; Esther 4-6", "Psalms 84; Esther 7-8", "Psalms 90; Esther 9-10", "Psalms 92; Ezra 1-3"])
        let lines = draft.weeks.flatMap(\.readings).map(\.text)
        #expect(lines.count { $0.hasSuffix("(Holidays)") } == 15 && lines.count { $0.hasSuffix("(NT Focus Week)") } == 25)
    }

    @Test func gen2IsEightySixWeeksStartingSeptember2026WithNothingFlagged() throws {
        var draft = try PlanFileImport.draft(fromFileAt: folder.appending(path: "Gen 2_ RTS Reading Plan.pdf"), today: today).get()
        #expect(draft.weeks.map(\.number) == Array(1...86) && draft.weeks.prefix(77).allSatisfy { $0.readings.count == 4 } && draft.weeks.suffix(9).allSatisfy { $0.readings.count == 3 })
        #expect(draft.canSave && draft.firstYear == 2026 && draft.weeks[0].day == PlanDay(year: 2026, month: 9, day: 15) && draft.weeks.allSatisfy { $0.day != nil })
        #expect(draft.weeks[0].label == "Leader Dinner" && draft.weeks[4].label == "Meet in Homes" && draft.weeks[9].label == "OFF")
        #expect(PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
        let lines = draft.weeks.flatMap(\.readings).map(\.text)
        #expect(lines.count == 335 && lines.count { $0.hasSuffix("(NT Focus)") } == 25 && lines.count { !$0.contains(";") && !$0.contains("(") } == 15)
        #expect(draft.weeks[67].day == PlanDay(year: 2028, month: 2, day: 29))
        draft.setFirstYear(2025)                                                  // the earlier reading is still there to choose, and flags the Feb 29
        #expect(draft.weeks[67].day == nil && PlanReview.flags(draft, chapterCounts: [:]).map(\.sentence) == ["Week 68: Feb 29 is not a date in 2027. Set the date, or change the year the plan starts."])
    }
}
#endif
