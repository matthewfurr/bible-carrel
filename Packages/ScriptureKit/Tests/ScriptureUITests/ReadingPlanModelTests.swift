import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite final class ReadingPlanModelTests {
    private let calendar = PlanModelFixture.calendar
    private let small = PlanModelFixture.small

    private func day(_ y: Int, _ m: Int, _ d: Int) -> PlanDay { PlanModelFixture.day(y, m, d) }

    @Test func thePlanFollowedIsTheStoredOneElseTheNewest() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let (model, store, defaults) = (f.model, f.store, f.defaults)
        #expect(model.followed == nil && !model.showsWeek && model.now == nil && model.progress == PlanProgress(read: 0, total: 0))
        var older = PlanSample.gen1Shaped()
        older.createdAt = Date(timeIntervalSince1970: 0)
        try store.save(older)
        try store.save(small)
        model.reload()
        #expect(model.plans.count == 2 && model.followed?.id == small.id && defaults.string(forKey: "followedPlanID") == nil)   // the newest, and nothing written
        model.follow(older.id)
        #expect(model.followed?.id == older.id && defaults.string(forKey: "followedPlanID") == older.id.uuidString)
        let missing = UUID().uuidString
        defaults.set(missing, forKey: "followedPlanID")                                              // a plan that has not arrived, or was deleted elsewhere
        model.reload()
        #expect(model.followed?.id == small.id && defaults.string(forKey: "followedPlanID") == missing)
    }

    @Test func thisWeekAndTheButtonFollowTheDay() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let model = f.model
        model.save(small)
        #expect(model.followed?.id == small.id && model.thisWeek?.index == 1 && model.thisWeek?.count == 3 && model.showsWeek && !model.needsAnchor && !model.isFinished)
        f.clock.date = day(2026, 11, 18).date(in: calendar)                                          // the day after the meeting, with no relaunch
        model.refreshToday()
        #expect(model.thisWeek?.index == 2 && model.today == day(2026, 11, 18))
        f.clock.date = day(2026, 11, 25).date(in: calendar)
        model.refreshToday()
        #expect(model.isFinished && !model.showsWeek && model.thisWeek == nil)
        model.save(PlanSample.gen1Shaped())                                                          // a plan with no dates, now followed
        #expect(model.followed?.id == PlanSample.gen1ID && model.needsAnchor && !model.showsWeek)
        model.anchor(week: 62, on: day(2026, 11, 26))
        #expect(!model.needsAnchor && model.showsWeek && model.thisWeek?.week.number == 63 && model.thisWeek?.count == 67)
        model.setDay(day(2026, 12, 10), ofWeek: 62)                                                  // a break: later weeks follow
        #expect(model.followed?.weeks[63].day == day(2026, 12, 17) && model.followed?.weeks[61].day == day(2026, 11, 19))
    }

    @Test func tickingCountsAndSurvivesAReload() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let model = f.model
        model.save(small)
        let reading = small.weeks[1].readings[0]
        model.toggle(reading)
        #expect(model.isTicked(reading) && model.progress(ofWeek: 1).label == "1 of 2" && model.progress == PlanProgress(read: 1, total: 6))
        let clock = f.clock
        let other = ReadingPlanModel(store: f.store, navigation: f.navigation, defaults: f.defaults, calendar: calendar, now: { clock.date })
        #expect(other.isTicked(reading))                                                             // what another device ticked, once imported and reloaded
        other.toggle(reading)
        model.reload()
        #expect(!model.isTicked(reading) && model.progress(ofWeek: 1).label == nil)
    }

    /// Spec 5.4 and 11: opening a passage is reading, not a lookup.
    @Test func openingAPassageIsAReadingMoveNotALookup() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let (model, navigation, positions) = (f.model, f.navigation, f.positions)
        var opened: [PlanPassage] = []
        model.onOpenPassage = { opened.append($0) }
        navigation.open(ChapterLocation(book: "MAT", chapter: 1))
        navigation.lookUp(ChapterLocation(book: "PSA", chapter: 1), verse: 2)
        #expect(navigation.isLookingUp)
        let psalm = PlanPassage(book: "PSA", chapter: 2, verse: 1, endVerse: 6)
        model.open(psalm)
        #expect(!navigation.isLookingUp && navigation.location == ChapterLocation(book: "PSA", chapter: 2) && navigation.scrollTarget?.verse == 1)
        #expect(positions.load()?.chapterLocation == ChapterLocation(book: "PSA", chapter: 2) && opened == [psalm])
        model.open(PlanPassage(book: "MAT", chapter: 5, endChapter: 6))
        #expect(navigation.location == ChapterLocation(book: "MAT", chapter: 5) && navigation.screen == .reader)
    }

    /// Review Focus 1.
    @Test func aPassageTheTranslationLacksIsNotOffered() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let (model, navigation) = (f.model, f.navigation)
        var opened = 0
        model.onOpenPassage = { _ in opened += 1 }
        navigation.open(ChapterLocation(book: "MAT", chapter: 1))
        let genesis = PlanPassage(book: "GEN", chapter: 1), past = PlanPassage(book: "MAT", chapter: 28)
        #expect(!model.canOpen(genesis) && !model.canOpen(past) && model.canOpen(PlanPassage(book: "MAT", chapter: 5, endChapter: 28)))
        model.open(genesis)
        model.open(past)
        #expect(opened == 0 && navigation.location == ChapterLocation(book: "MAT", chapter: 1) && model.unavailableHelp == "Not in the WEB.")
        #expect(model.chapterCounts["MAT"] == navigation.chapterCount(ofBook: "MAT") && model.chapterCounts["GEN"] == nil)
    }

    @Test func deletingAPlanIsUndoable() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let (model, store) = (f.model, f.store)
        let undo = UndoManager()
        model.adoptUndoManager(undo)
        model.save(small)
        model.toggle(small.weeks[0].readings[0])
        model.delete(small.id)
        #expect(model.plans.isEmpty && model.followed == nil && undo.undoActionName == "Delete Plan")
        undo.undo()
        #expect(model.followed?.id == small.id && model.isTicked(small.weeks[0].readings[0]))
        undo.redo()
        #expect(try store.plans().isEmpty && model.plans.isEmpty)
    }

    /// Review Focus 5: the system's day-changed and time-zone notifications reach `refreshToday()`.
    @Test func theDayAndTheTimeZoneChangingMoveToday() async throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        f.clock.date = day(2026, 11, 18).date(in: calendar)
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        for _ in 0..<20 where f.model.today != day(2026, 11, 18) { await Task.yield() }
        #expect(f.model.today == day(2026, 11, 18))
        f.clock.date = day(2026, 11, 19).date(in: calendar)
        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        for _ in 0..<20 where f.model.today != day(2026, 11, 19) { await Task.yield() }
        #expect(f.model.today == day(2026, 11, 19))
    }

    /// A followed plan this build cannot read shows no week, and a date set on it changes nothing.
    @Test func anUnreadableFollowedPlanShowsNoWeekAndTakesNoDate() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let record = PlanRecord()
        record.title = "From a newer build"
        record.weeksData = Data(#"{"v":2,"weeks":[]}"#.utf8)
        f.store.container.mainContext.insert(record)
        try f.store.container.mainContext.save()
        f.model.reload()
        #expect(f.model.followed?.isReadable == false && f.model.now == nil && f.model.thisWeek == nil && !f.model.showsWeek && !f.model.needsAnchor)
        f.model.setDay(day(2026, 11, 17), ofWeek: 0)
        f.model.anchor(week: 0, on: day(2026, 11, 17))
        #expect(record.weeksData == Data(#"{"v":2,"weeks":[]}"#.utf8) && f.model.lastError == nil)
    }

    /// With no preference, of two plans made at one moment the lower uuid is followed.
    @Test func theNewestPlanTiesToTheLowestUUID() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        func plan(_ id: String) -> ReadingPlan {
            ReadingPlan(id: UUID(uuidString: id)!, title: id, createdAt: small.createdAt, modifiedAt: small.modifiedAt, weeks: small.weeks)
        }
        let low = plan("00000000-0000-4000-8000-000000000001"), high = plan("FFFFFFFF-0000-4000-8000-000000000001")
        try f.store.save(high)
        try f.store.save(low)
        f.model.reload()
        #expect(f.model.followed?.id == low.id)
    }

    /// I4: a tick refetches the ticks only, and a reload that finds nothing new changes nothing a view reads.
    @Test func aTickChangesOnlyTheTicks() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        let model = f.model
        model.save(small)
        let plans = ObservedChange.observing { _ = model.plans; _ = model.followed; _ = model.today }
        let ticked = ObservedChange.observing { _ = model.ticked }
        model.toggle(small.weeks[1].readings[0])
        #expect(!plans.fired && ticked.fired && model.isTicked(small.weeks[1].readings[0]))
        let reloaded = ObservedChange.observing { _ = model.plans; _ = model.followed; _ = model.ticked }
        model.reload()
        #expect(!reloaded.fired)
    }

    /// I1: `save` says whether the plan was stored.
    @Test func saveSaysWhetherThePlanWasStored() throws {
        let f = try PlanModelFixture(today: day(2026, 11, 16))
        #expect(f.model.save(small))
        var unreadable = small
        unreadable.isReadable = false
        #expect(!f.model.save(unreadable) && f.model.lastError == "That change could not be saved. Try it again.")
    }

    /// M4: a plan with no weeks is not a plan from a newer version.
    @Test func aPlanWithNoWeeksSaysSoAndAnUnreadableOneSaysWhy() {
        var empty = small
        empty.weeks = []
        var unreadable = empty
        unreadable.isReadable = false
        #expect(PlanWeekText.placeholderLine(for: empty) == "This plan has no weeks yet.")
        #expect(PlanWeekText.placeholderLine(for: unreadable) == "This plan was made by a newer version of Bible Carrel.")
        #expect(PlanWeekText.placeholderLine(for: small) == nil)
        #expect(ChangeMeetingDateView.caption(for: small.weeks[0]) == "Later weeks move by the same number of days.")
        var undated = small.weeks[0]
        undated.day = nil
        #expect(ChangeMeetingDateView.caption(for: undated) == nil)                                  // M7: nothing else moves
    }

    @Test func theLinesReadAsTheBandAndTheWindowShowThem() {
        let us = Locale(identifier: "en_US")
        let week = PlanWeek(number: 63, day: day(2026, 11, 17), label: nil, readings: small.weeks[0].readings)
        #expect(PlanWeekText.titleLine(week, count: 67, today: day(2026, 11, 16), locale: us, calendar: calendar) == "Week 63 of 67 · meets Tue, Nov 17")
        #expect(PlanWeekText.titleLine(week, count: 67, today: day(2026, 11, 17), locale: us, calendar: calendar) == "Week 63 of 67 · meets today, Tue, Nov 17")
        var off = week
        off.label = "OFF"
        #expect(PlanWeekText.titleLine(off, count: 86, today: day(2026, 11, 16), locale: us, calendar: calendar) == "Week 63 of 86 · meets Tue, Nov 17 · OFF")
        #expect(PlanWeekText.detailLine(off, progress: PlanProgress(read: 2, total: 5), locale: us, calendar: calendar) == "Meets Tuesday, November 17 · 2 of 5 read · OFF")
        #expect(PlanWeekText.sidebarLine(week, progress: PlanProgress(read: 5, total: 5), locale: us, calendar: calendar) == "Nov 17 · done")
        #expect(PlanWeekText.sidebarLine(week, progress: PlanProgress(read: 3, total: 5), locale: us, calendar: calendar) == "Nov 17 · 3 of 5")
        #expect(PlanWeekText.sidebarLine(week, progress: PlanProgress(read: 0, total: 5), locale: us, calendar: calendar) == "Nov 17")
        #expect(PlanWeekText.spokenWeek(week, progress: PlanProgress(read: 3, total: 5), locale: us, calendar: calendar) == "Week 63, Tuesday, November 17, 3 of 5 read")
        var undated = week
        undated.day = nil
        #expect(PlanWeekText.titleLine(undated, count: 67, today: day(2026, 11, 16), locale: us, calendar: calendar) == "Week 63 of 67")
        #expect(PlanWeekText.detailLine(undated, progress: PlanProgress(read: 0, total: 5), locale: us, calendar: calendar) == "0 of 5 read")
        #expect(PlanWeekText.sidebarLine(undated, progress: PlanProgress(read: 0, total: 5), locale: us, calendar: calendar) == "")
        #expect(PlanWeekText.sidebarLine(undated, progress: PlanProgress(read: 3, total: 5), locale: us, calendar: calendar) == "3 of 5")
        let esther = PlanReading(id: UUID(), label: nil, passages: [PlanPassage(book: "PSA", chapter: 84), PlanPassage(book: "EST", chapter: 7, endChapter: 8)])
        #expect(PlanWeekText.spoken(esther, index: 2, count: 5, isTicked: false) == "Reading 3 of 5, Psalms 84, Esther 7 to 8, not read")
        let focus = PlanReading(id: UUID(), label: "NT Focus Week", passages: [PlanPassage(book: "JHN", chapter: 11, endChapter: 12)])
        #expect(PlanWeekText.spoken(focus, index: 0, count: 5, isTicked: true) == "Reading 1 of 5, John 11 to 12, NT Focus Week, read")
    }
}
