import Foundation
import Testing
@testable import ScriptureData

private func day(_ y: Int, _ m: Int, _ d: Int) -> PlanDay { PlanDay(year: y, month: m, day: d)! }

@Test func yearsAreCountedOnFromTheFirstDate() {
    let dates = ["Sept 15", "Dec 29", "Jan 5", "May 25", "Aug 3", "Dec 28", "Jan 4", "Feb 22", "Feb 29", "Mar 7", "Aug 29"].map(PlanYears.monthDay)
    #expect(dates[0] == PlanYears.MonthDay(month: 9, day: 15) && PlanYears.monthDay("Sep 7") == PlanYears.MonthDay(month: 9, day: 7))
    #expect(PlanYears.monthDay("15 Nov") == PlanYears.MonthDay(month: 11, day: 15) && PlanYears.monthDay("Leader Dinner") == nil && PlanYears.monthDay("Feb 30") == nil)
    #expect(PlanYears.firstYear(for: dates, today: day(2026, 11, 16)) == 2026)                  // spec 6.1: only a first year of 2022 or 2026 keeps every date on one Tuesday (a Feb 29 exists); of those, 2026 holds today
    let placed = PlanYears.place(dates, firstYear: 2025)
    #expect(placed.days[0] == day(2025, 9, 15) && placed.days[2] == day(2026, 1, 5) && placed.days[4] == day(2026, 8, 3) && placed.days[6] == day(2027, 1, 4))
    #expect(placed.days[8] == nil && placed.years[8] == 2027 && placed.days[9] == day(2027, 3, 7))   // 29 February 2027 does not exist
    #expect(PlanYears.place(dates, firstYear: 2026).days[8] == day(2028, 2, 29))                 // another first year moves the rest
    #expect(PlanYears.place(dates, firstYear: 2026).days.compactMap { $0 }.allSatisfy { $0.days(until: day(2026, 9, 15)) % 7 == 0 } && PlanYears.place(dates, firstYear: 2025).days.contains { $0 == nil })
    let short = ["Sept 15", "Sept 22"].map(PlanYears.monthDay)
    #expect(PlanYears.firstYear(for: short, today: day(2026, 11, 16)) == 2026 && PlanYears.firstYear(for: short, today: day(2026, 6, 1)) == 2026)   // none fits: the nearest
    #expect(PlanYears.firstYear(for: short, today: day(2026, 1, 10)) == 2025 && PlanYears.firstYear(for: [nil, nil], today: day(2026, 11, 16)) == 2026)
}

@Test func aYearThatKeepsTheDatesOnOneWeekdayIsPreferred() {
    let today = day(2026, 11, 16)
    // The old rule gave 2025 here (it holds today) and left a Feb 29 that does not exist; 2026 and 2022 keep every date on a Tuesday, and 2026 holds today.
    let names = ["Sept 15", "Dec 29", "Jan 5", "May 25", "Aug 3", "Dec 28", "Jan 4", "Feb 22", "Feb 29", "Mar 7"]
    #expect(PlanYears.firstYear(for: names.map(PlanYears.monthDay), today: today) == 2026)
    var draft = PlanText.draft(from: names.enumerated().map { "Week \($0.offset + 1) \($0.element)\nPsalms \($0.offset + 1)" }.joined(separator: "\n"), title: "T", today: today)
    #expect(draft.firstYear == 2026 && draft.weeks.allSatisfy { $0.day != nil } && PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
    draft.setFirstYear(2025)
    #expect(PlanReview.flags(draft, chapterCounts: [:]).count == 1)
    // Exactly one candidate keeps the calendar (only 2027 reaches a Feb 29, in 2028); the old rule would take 2028, which is nearer.
    let crossing = ["Dec 28", "Jan 4", "Feb 22", "Feb 29", "Mar 7"].map(PlanYears.monthDay)
    #expect(PlanYears.firstYear(for: crossing, today: day(2029, 6, 1)) == 2027)
    // Two keep it (2023 and 2027 reach a Feb 29): the nearer of those to today, 2027, and not 2026, nearer still, which loses the Feb 29.
    #expect(PlanYears.firstYear(for: crossing, today: day(2026, 11, 16)) == 2027)
    // No candidate keeps one weekday: the old rule decides (the nearest to today), among every candidate.
    let loose = ["Sept 15", "Sept 23", "Oct 1"].map(PlanYears.monthDay)
    #expect(PlanYears.firstYear(for: loose, today: day(2026, 11, 16)) == 2026 && PlanYears.firstYear(for: loose, today: day(2026, 6, 1)) == 2026)
    #expect(PlanYears.firstYear(for: loose, today: day(2026, 1, 10)) == 2025)                    // last autumn's is nearer than this autumn's
    // Several keep it (every year does for dates a week apart): the old rule decides among them.
    let two = ["Sept 15", "Sept 22"].map(PlanYears.monthDay)
    #expect(PlanYears.firstYear(for: two, today: day(2026, 9, 18)) == 2026 && PlanYears.firstYear(for: two, today: day(2026, 1, 10)) == 2025)
}

@Test func textIsReadInTheEditorsOwnForm() {
    let text = """
    Week 12 2026-11-17 Leader Dinner
    Psalms 84; Esther 7-8
    John 11-12 (NT Focus)

    wk 13 Nov 24 - OFF
    Psalms 90; Esther 9-10
    Hezekiah 3
    """
    let draft = PlanText.draft(from: text, title: "Typed", today: day(2026, 11, 16))
    #expect(draft.title == "Typed" && draft.planID == nil && draft.weeks.map(\.number) == [12, 13])
    #expect(draft.weeks[0].day == day(2026, 11, 17) && draft.weeks[0].label == "Leader Dinner" && draft.weeks[0].monthDay == nil)
    #expect(draft.weeks[1].day == day(2026, 11, 24) && draft.weeks[1].label == "OFF" && draft.weeks[1].monthDay == PlanYears.MonthDay(month: 11, day: 24))
    #expect(draft.weeks[0].readings.map(\.text) == ["Psalms 84; Esther 7-8", "John 11-12 (NT Focus)"] && draft.weeks[1].readings.count == 2)
    #expect(!draft.canSave)                                                                      // "Hezekiah 3"
    #expect(PlanText.draft(from: "Psalms 1\nPsalms 2", title: "T", today: day(2026, 11, 16)).weeks.map(\.number) == [1])
    let plan = PlanSample.gen2Shaped(today: day(2026, 11, 16))
    let again = PlanText.draft(from: PlanText.text(for: plan), title: plan.title, today: day(2026, 11, 16)).plan(now: plan.modifiedAt)
    #expect(again?.weeks.map(\.number) == plan.weeks.map(\.number) && again?.weeks.map(\.day) == plan.weeks.map(\.day) && again?.weeks.map(\.label) == plan.weeks.map(\.label))
    #expect(again?.weeks.map { $0.readings.map(\.passages) } == plan.weeks.map { $0.readings.map(\.passages) })
    #expect(again?.weeks[54].readings.map(\.label) == plan.weeks[54].readings.map(\.label))
}

@Test func theReviewFlagsEachKindAndSaveIsOffWithAnUnreadableLine() {
    var draft = PlanDraft(title: "Typed")
    #expect(draft.weeks.count == 1 && draft.weeks[0].number == 1 && draft.weeks[0].readings.map(\.text) == [""] && draft.canSave)
    let week = draft.weeks[0].id
    draft.weeks[0].readings[0].text = "Psalms 84; Esther 7-8"
    #expect(draft.canSave && PlanReview.flags(draft, chapterCounts: ["PSA": 150, "EST": 10]).isEmpty)
    for line in ["Hezekiah 3", "Psalms eighty", "Esther 9-11", "Tobit 1"] {
        draft.addReading(toWeek: week)
        draft.weeks[0].readings[draft.weeks[0].readings.count - 1].text = line
    }
    draft.weeks[0].day = day(2026, 11, 17)
    draft.addWeek()
    #expect(draft.weeks[1].number == 2 && draft.weeks[1].day == day(2026, 11, 24) && draft.weeks[1].readings.map(\.text) == [""])
    draft.weeks[1].number = 4
    draft.weeks[1].day = day(2026, 11, 10)
    let flags = PlanReview.flags(draft, chapterCounts: ["PSA": 150, "EST": 10])                  // no count for Tobit: not flagged
    #expect(flags.map(\.kind) == [.unknownBook, .unreadable, .missingChapter, .numberOutOfSequence, .dateOutOfOrder])
    #expect(flags.map(\.sentence) == [
        "Week 1: “Hezekiah 3” names a book Bible Carrel does not know.",
        "Week 1: “Psalms eighty” cannot be read.",
        "Week 1: Esther has no chapter 11.",
        "Week 4: numbered 4 after 1.",
        "Week 4: its date is not after week 1's.",
    ])
    #expect(flags[0].readingID == draft.weeks[0].readings[1].id && flags[3].readingID == nil && flags[3].weekID == draft.weeks[1].id)
    let saving = Date(timeIntervalSince1970: 10)
    #expect(!draft.canSave && draft.plan(now: saving) == nil)
    draft.removeReading(draft.weeks[0].readings[2].id)
    draft.removeReading(draft.weeks[0].readings[1].id)
    #expect(draft.canSave)                                                                       // a missing chapter and the dates do not block Save
    #expect(draft.plan(now: saving)?.weeks.map(\.readings.count) == [3, 0])                      // the blank line is left out
    draft.title = "  "
    #expect(!draft.canSave)
}

@Test func editingKeepsEachReadingsIdentity() throws {
    let plan = PlanSample.gen1Shaped(), ids = plan.weeks[0].readings.map(\.id)
    var draft = PlanDraft(plan: plan)
    #expect(draft.planID == plan.id && draft.firstYear == nil && draft.weeks[0].readings.map(\.id) == ids)
    draft.moveReadings(inWeek: draft.weeks[0].id, fromOffsets: IndexSet(integer: 0), toOffset: 5)     // the first reading to the end
    draft.weeks[0].readings[4].text = "Psalms 150"                                                  // its passages changed
    draft.weeks[0].number = 9                                                                       // renumbered
    draft.removeReading(ids[2])
    let saved = try #require(draft.plan(now: Date(timeIntervalSince1970: 10)))
    #expect(saved.id == plan.id && saved.createdAt == plan.createdAt && saved.modifiedAt == Date(timeIntervalSince1970: 10))
    #expect(saved.weeks[0].readings.map(\.id) == [ids[1], ids[3], ids[4], ids[0]] && saved.weeks[0].number == 9)
    #expect(saved.weeks[0].readings[3].passages == [PlanPassage(book: "PSA", chapter: 150)])
    #expect(saved.readingIDs.count == 334 && !saved.readingIDs.contains(ids[2]))
}

@Test func aNewFirstYearPlacesTheFilesDatesAgainAndAHandSetDateStays() {
    var draft = PlanText.draft(from: "Week 1 Feb 22\nPsalms 1\nWeek 2 Feb 29\nPsalms 2\nWeek 3 Mar 8\nPsalms 3", title: "T", today: day(2027, 2, 1))
    #expect(draft.firstYear == 2027 && draft.weeks.map(\.day) == [day(2027, 2, 22), nil, day(2027, 3, 8)])
    #expect(PlanReview.flags(draft, chapterCounts: [:]).map(\.sentence) == ["Week 2: Feb 29 is not a date in 2027. Set the date, or change the year the plan starts."])
    draft.setFirstYear(2028)
    #expect(draft.weeks.map(\.day) == [day(2028, 2, 22), day(2028, 2, 29), day(2028, 3, 8)] && PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
    draft.setFirstYear(2027)
    draft.setDay(day(2027, 3, 1), ofWeek: draft.weeks[1].id)                  // it had no date: nothing else moves
    #expect(draft.weeks.map(\.day) == [day(2027, 2, 22), day(2027, 3, 1), day(2027, 3, 8)] && PlanReview.flags(draft, chapterCounts: [:]).isEmpty)
    draft.setDay(day(2027, 3, 8), ofWeek: draft.weeks[1].id)                  // moved: the later week follows
    #expect(draft.weeks[2].day == day(2027, 3, 15))
    draft.setFirstYear(2028)                                                  // weeks set or moved by hand are not placed again
    #expect(draft.weeks.map(\.day) == [day(2028, 2, 22), day(2027, 3, 8), day(2027, 3, 15)])
}

@Test func pastedTextReplacesAnEmptyDraftAndIsAddedToAnyOther() {
    var draft = PlanDraft(title: "New")
    draft.append(text: "Week 5\nPsalms 1\nWeek 6\nPsalms 2", today: day(2026, 11, 16))
    #expect(draft.weeks.map(\.number) == [5, 6] && draft.title == "New")
    draft.append(text: "Psalms 3", today: day(2026, 11, 16))
    #expect(draft.weeks.map(\.number) == [5, 6, 1] && draft.weeks[2].readings.map(\.text) == ["Psalms 3"])
}

/// A line spaced as a person might type it ("Esther 7 - 8") is a line that cannot be read, never a book named "Esther 7 -".
@Test func aLineWithItsNumbersSpacedOutCannotBeReadAndNamesNoBook() {
    #expect(PlanReadingText.parse("Esther 7 - 8") == .failure(.unreadable("Esther 7 - 8")))
    #expect(PlanReadingText.parse("Psalms 119: 1-16") == .failure(.unreadable("Psalms 119: 1-16")))
    #expect(PlanReadingText.parse("Psalms 1, 2") == .failure(.unreadable("Psalms 1, 2")))
    #expect(PlanReadingText.parse("Hezekiah 3") == .failure(.unknownBook("Hezekiah")))
    #expect(PlanReadingText.parse("1 John 2; Song of Solomon 1-2").map(\.passages.count) == .success(2))
    var draft = PlanDraft(title: "Typed")
    draft.weeks[0].readings[0].text = "Esther 7 - 8"
    #expect(PlanReview.flags(draft, chapterCounts: [:]).map(\.sentence) == ["Week 1: “Esther 7 - 8” cannot be read."])
}

/// A line naming the same missing chapter twice gives two flags, each with its own id (a `ForEach` needs them unique).
@Test func eachFlagOfALineHasItsOwnID() {
    var draft = PlanDraft(title: "Typed")
    draft.weeks[0].readings[0].text = "Esther 11; Esther 11"
    let flags = PlanReview.flags(draft, chapterCounts: ["EST": 10])
    #expect(flags.map(\.kind) == [.missingChapter, .missingChapter] && flags.map(\.passageIndex) == [0, 1])
    #expect(Set(flags.map(\.id)).count == 2)
}

/// The mark under a line is its flag without "Week N:", which the line's own week header already says.
@Test func aLinesMarkLeavesOutItsWeek() {
    var draft = PlanDraft(title: "Typed")
    draft.weeks[0].number = 3
    draft.weeks[0].readings[0].text = "Hezekiah 3"
    draft.addReading(toWeek: draft.weeks[0].id)
    draft.weeks[0].readings[1].text = "Esther 9-11"
    let flags = PlanReview.flags(draft, chapterCounts: ["EST": 10])
    #expect(flags.map(\.sentence) == ["Week 3: “Hezekiah 3” names a book Bible Carrel does not know.", "Week 3: Esther has no chapter 11."])
    #expect(flags.map(\.lineSentence) == ["“Hezekiah 3” names a book Bible Carrel does not know.", "Esther has no chapter 11."])
}
