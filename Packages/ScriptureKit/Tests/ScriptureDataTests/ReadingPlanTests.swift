import Foundation
import Testing
@testable import ScriptureData

private func day(_ y: Int, _ m: Int, _ d: Int) -> PlanDay { PlanDay(year: y, month: m, day: d)! }
private func passage(_ text: String) -> PlanPassage { try! PlanReadingText.passage(text).get() }
private func weeks(_ days: [PlanDay?]) -> [PlanWeek] {
    days.enumerated().map { PlanWeek(number: $0.offset + 1, day: $0.element, label: nil, readings: []) }
}

@Test func aPassageReadsEachFormTheSpecNames() {
    #expect(passage("Psalms 84") == PlanPassage(book: "PSA", chapter: 84))
    #expect(passage("Esther 7-8") == PlanPassage(book: "EST", chapter: 7, endChapter: 8))
    #expect(passage("psalm 119:1–16") == PlanPassage(book: "PSA", chapter: 119, verse: 1, endVerse: 16))     // any accepted name; an en dash
    #expect(passage("Song 1").book == "SNG" && passage("1 Sam 25-27").book == "1SA" && passage("Jn 3:16").verse == 16)
    #expect(passage("Esther 7-8").displayString == "Esther 7–8" && passage("Ps 84").displayString == "Psalms 84")
    #expect(passage("Psalms 119:1-16").displayString == "Psalms 119:1–16" && passage("Song 1").displayString == "Song of Solomon 1")
    #expect(passage("Esther 7-8").spokenString == "Esther 7 to 8" && passage("Psalms 119:1-16").spokenString == "Psalms 119, verses 1 to 16")
    #expect(passage("Esther 7–8").editString == "Esther 7-8" && passage("Esther 7-8").startLocation == ChapterLocation(book: "EST", chapter: 7))
}

@Test func whatCannotBeReadSaysWhy() {
    #expect(PlanReadingText.passage("Hezekiah 3") == .failure(.unknownBook("Hezekiah")))
    #expect(PlanReadingText.passage("ma 3") == .failure(.unknownBook("ma")))                 // never a guess from a prefix
    for text in ["Esther", "Esther 8-7", "Esther 0", "Esther 7-8:3", "Psalms 119:16-1", "7-8", "Esther seven"] {
        #expect(PlanReadingText.passage(text) == .failure(.unreadable(text)), "\(text)")
    }
    #expect(PlanReadingText.parse("   ") == .failure(.empty))
    #expect(PlanReadingText.parse("Psalms 84; Hezekiah 3") == .failure(.unknownBook("Hezekiah")))
}

@Test func aLineIsAReadingOfOneOrMorePassagesWithItsLabel() throws {
    let two = try PlanReadingText.parse("Psalms 84; Esther 7-8").get()
    #expect(two.passages.map(\.displayString) == ["Psalms 84", "Esther 7–8"] && two.label == nil)
    let focus = try PlanReadingText.parse("John 11-12 (NT Focus Week)").get()
    #expect(focus.passages == [passage("John 11-12")] && focus.label == "NT Focus Week")
    #expect(try PlanReadingText.parse("2 John 1; 3 John 1; Jude 1").get().passages.map(\.book) == ["2JN", "3JN", "JUD"])
    #expect(PlanReadingText.line(for: PlanReading(id: UUID(), label: "Holidays", passages: [passage("Isaiah 7-9")])) == "Isaiah 7-9 (Holidays)")
    #expect(PlanReadingText.line(for: PlanReading(id: UUID(), label: nil, passages: two.passages)) == "Psalms 84; Esther 7-8")
}

@Test func thisWeekIsTheFirstWhoseMeetingIsTodayOrLater() {
    let plan = weeks([day(2026, 11, 10), day(2026, 11, 17), day(2026, 11, 24)])
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 1)) == .week(index: 0))       // before the first week it is week 1
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 11)) == .week(index: 1))
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 17)) == .week(index: 1))      // on the meeting day
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 18)) == .week(index: 2))      // the day after
    #expect(PlanSchedule.now(plan, today: day(2026, 11, 25)) == .finished)
    #expect(PlanSchedule.now(weeks([nil, nil]), today: day(2026, 11, 1)) == .undated)
    #expect(PlanSchedule.now(weeks([day(2026, 11, 10), nil, day(2026, 11, 24)]), today: day(2026, 11, 11)) == .week(index: 2))
}

@Test func movingADateMovesTheLaterWeeksAndAnchoringFillsEveryDate() {
    let plan = weeks([day(2026, 11, 10), day(2026, 11, 17), nil, day(2026, 12, 1)])
    #expect(PlanSchedule.settingDay(day(2026, 11, 24), ofWeek: 1, in: plan).map(\.day) == [day(2026, 11, 10), day(2026, 11, 24), nil, day(2026, 12, 8)])
    #expect(PlanSchedule.settingDay(day(2026, 11, 20), ofWeek: 2, in: plan).map(\.day) == [day(2026, 11, 10), day(2026, 11, 17), day(2026, 11, 20), day(2026, 12, 1)])
    let anchored = PlanSchedule.anchored(PlanSample.gen1Shaped().weeks, week: 62, on: day(2026, 11, 17))   // week 63 meets Tuesday 17 November
    #expect(anchored[62].day == day(2026, 11, 17) && anchored[63].day == day(2026, 11, 24))
    #expect(anchored[0].day == day(2025, 9, 9) && anchored[66].day == day(2026, 12, 15))
    #expect(PlanSchedule.now(anchored, today: day(2026, 11, 17)) == .week(index: 62) && PlanSchedule.now(anchored, today: day(2026, 11, 18)) == .week(index: 63))
}

@Test func aMeetingDateIsACalendarDayInAnyTimeZone() {
    #expect(PlanDay(year: 2027, month: 2, day: 29) == nil && PlanDay(year: 2028, month: 2, day: 29) != nil && PlanDay(year: 2026, month: 13, day: 1) == nil)
    #expect(day(2026, 12, 29).adding(days: 7) == day(2027, 1, 5) && day(2026, 11, 17).days(until: day(2026, 11, 24)) == 7 && day(2026, 11, 17) < day(2026, 11, 18))
    #expect(day(2026, 11, 17).iso == "2026-11-17" && PlanDay(iso: "2026-11-17") == day(2026, 11, 17) && PlanDay(iso: "2027-02-29") == nil)
    var tokyo = Calendar(identifier: .gregorian), chicago = Calendar(identifier: .gregorian)
    tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    chicago.timeZone = TimeZone(identifier: "America/Chicago")!
    let evening = day(2026, 11, 17).date(in: chicago).addingTimeInterval(20 * 3600)       // 8 pm on the 17th in Chicago
    #expect(PlanDay(evening, calendar: chicago) == day(2026, 11, 17) && PlanDay(evening, calendar: tokyo) == day(2026, 11, 18))
}

@Test func countsAreOfThePlansOwnReadings() {
    let plan = PlanSample.gen1Shaped(), first = plan.weeks[0].readings.map(\.id)
    let ticked = Set(first.prefix(3)).union([UUID()])                                      // one tick for a reading the plan does not have
    #expect(plan.progress(ticked: ticked) == PlanProgress(read: 3, total: 335) && plan.progress(ticked: []).fraction == 0)
    #expect(plan.progress(ofWeek: 0, ticked: ticked).label == "3 of 5" && plan.progress(ofWeek: 1, ticked: ticked).label == nil)
    #expect(plan.progress(ofWeek: 0, ticked: Set(first)).label == "done" && plan.readingIDs.count == 335)
}

@Test func theSamplesAreTheChurchsShapes() {
    let one = PlanSample.gen1Shaped(), two = PlanSample.gen2Shaped(today: day(2026, 11, 16))
    #expect(one.weeks.count == 67 && one.weeks.allSatisfy { $0.readings.count == 5 && $0.day == nil } && one == PlanSample.gen1Shaped())
    #expect(two.weeks.count == 86 && two.weeks.prefix(77).allSatisfy { $0.readings.count == 4 } && two.weeks.suffix(9).allSatisfy { $0.readings.count == 3 })
    #expect(two.readingIDs.count == 335 && two.weeks[52].day == day(2026, 11, 16) && two.weeks[53].day == day(2026, 11, 23))
    #expect(two.weeks[0].label == "Leader Dinner" && two.weeks[9].label == "OFF" && two.weeks[1].label == nil)
    #expect(two.weeks[54].readings.allSatisfy { $0.label == "NT Focus" && $0.passages.count == 1 })
    let standIn = PlanSample.standIn(today: day(2026, 11, 16))
    #expect(standIn.id == PlanSample.standInID && standIn.weeks.map(\.day) == [day(2026, 11, 17), day(2026, 11, 24)])
    #expect(standIn.weeks.map(\.readings.count) == [2, 2] && standIn.weeks[1].readings[1].passages.count == 3)
}

@Test func thePlansWeeksRoundTripAndANewerVersionIsNotRead() throws {
    let weeks = PlanSample.gen2Shaped(today: day(2026, 11, 16)).weeks
    let data = try PlanCoding.encode(weeks)
    #expect(PlanCoding.decode(data) == weeks && data.count < 100_000)
    #expect(String(decoding: data.prefix(18), as: UTF8.self) == #"{"v":1,"weeks":[{""#)
    #expect(PlanCoding.decode(Data(#"{"v":2,"weeks":[]}"#.utf8)) == nil && PlanCoding.decode(Data("junk".utf8)) == nil && PlanCoding.decode(Data()) == [])
}

@Test func aNameThatCarriesNumbersIsNotABookAndALeadingNumberStillIs() {
    #expect(PlanReadingText.passage("Psalms 1 2") == .failure(.unreadable("Psalms 1 2")))            // the 1 is never dropped; the line cannot be read
    #expect(PlanReadingText.passage("John 3:16 17") == .failure(.unreadable("John 3:16 17")))
    #expect(passage("1 John 3").book == "1JN" && passage("2 Kings 4-5").book == "2KI" && passage("3 John 1").book == "3JN")
    #expect(passage("Song 2").book == "SNG" && passage("1 Sam 25-27").endChapter == 27)
}

/// A line of only a label or only separators is empty; "()" is no label; a stored week with a day
/// that is not a day makes the plan unreadable rather than dropping the week (Review Focus 3).
@Test func anEmptyLineAnEmptyLabelAndABadStoredDay() throws {
    #expect(PlanReadingText.parse("(Holidays)") == .failure(.empty) && PlanReadingText.parse(" ; ;") == .failure(.empty))
    let bare = try PlanReadingText.parse("Psalms 1 ()").get()
    #expect(bare.label == nil && bare.passages == [passage("Psalms 1")])
    let good = #"{"v":1,"weeks":[{"d":"2026-11-17","n":1,"r":[]},{"n":2,"r":[]}]}"#
    #expect(PlanCoding.decode(Data(good.utf8))?.map(\.day) == [day(2026, 11, 17), nil])
    let bad = #"{"v":1,"weeks":[{"d":"2026-02-30","n":1,"r":[]},{"n":2,"r":[]}]}"#
    #expect(PlanCoding.decode(Data(bad.utf8)) == nil)
}
