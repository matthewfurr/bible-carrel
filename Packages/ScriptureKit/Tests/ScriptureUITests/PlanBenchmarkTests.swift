import CoreGraphics
import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The review's flags on the largest plan the church has, on both apps.
@MainActor @Suite struct PlanReviewBenchmarkTests {
    /// `PlanSample.gen2Shaped`'s draft with one line made unreadable.
    static func flaggedDraft(today: PlanDay) -> PlanDraft {
        var draft = PlanDraft(plan: PlanSample.gen2Shaped(today: today))
        draft.weeks[40].readings[1].text = "Hezekiah 3"
        return draft
    }

    @Test func theReviewsFlagsOnEightySixWeeks() throws {
        let fixture = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        let draft = Self.flaggedDraft(today: fixture.model.today)
        let counts = fixture.model.chapterCounts
        #expect(draft.weeks.count == 86 && PlanReview.flags(draft, chapterCounts: counts).filter { $0.kind == .unknownBook }.count == 1)
        let clock = ContinuousClock()
        let timings = (0..<9).map { _ in clock.measure { _ = PlanReview.flags(draft, chapterCounts: counts) } }.sorted()
        let median = timings[4]
        print("benchmark plan-review-flags median of 9 \(median)")
        #expect(median < .milliseconds(20))
    }
}

/// A median of `runs` runs of `work`, in milliseconds, printed under `label`. `prepare` runs before each run, unmeasured.
@MainActor private func planMedian(_ label: String, runs: Int = 9, prepare: () -> Void = {}, _ work: () -> Void) -> Duration {
    let clock = ContinuousClock()
    let timings = (0..<runs).map { _ -> Duration in
        prepare()
        return clock.measure(work)
    }.sorted()
    let median = timings[runs / 2]
    print("benchmark \(label) median of \(runs) \(String(format: "%.2f", planMilliseconds(median))) ms")
    return median
}

private func planMilliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
}

/// The model's work on the two largest shapes, on an in-memory store, on both apps.
@MainActor @Suite(.serialized) struct PlanModelBenchmarkTests {
    private static let today = PlanModelFixture.day(2026, 11, 16)
    private static let tickedAt = Date(timeIntervalSince1970: 1)

    /// A tick is a store write and a reload of every plan, with 334 of the 335 readings already ticked.
    @Test func tickingAReadingWithEveryOtherTicked() throws {
        let fixture = try PlanModelFixture(today: Self.today)
        let plan = PlanSample.gen1Shaped()
        fixture.model.save(plan)
        let readings = plan.weeks.flatMap(\.readings)
        for reading in readings.dropLast() { _ = try fixture.store.toggleTick(planID: plan.id, readingID: reading.id, now: Self.tickedAt) }
        fixture.model.reload()
        #expect(readings.count == 335 && fixture.model.ticked.count == 334)
        let last = try #require(readings.last)
        let median = planMedian("tick-with-334-ticked") { fixture.model.toggle(last) }
        #expect(fixture.model.ticked.count == 334 || fixture.model.ticked.count == 335)
        #expect(median < .milliseconds(16))
    }

    /// Both samples in the store, 335 ticks on each: what an import's reload reads.
    @Test func reloadingAfterAnImport() throws {
        let fixture = try PlanModelFixture(today: Self.today)
        for plan in [PlanSample.gen1Shaped(), PlanSample.gen2Shaped(today: Self.today)] {
            fixture.model.save(plan)
            for reading in plan.weeks.flatMap(\.readings) { _ = try fixture.store.toggleTick(planID: plan.id, readingID: reading.id, now: Self.tickedAt) }
        }
        fixture.model.reload()
        #expect(fixture.model.plans.count == 2 && fixture.model.ticked.count == 335)
        let median = planMedian("reload-after-import") { fixture.model.reload() }
        #expect(median < .milliseconds(20))
    }

    /// The 86-week sample's stored weeks.
    @Test func thePlansWeeksDecode() throws {
        let weeks = PlanSample.gen2Shaped(today: Self.today).weeks
        let data = try PlanCoding.encode(weeks)
        print("benchmark plan-weeks-encoded-size \(data.count) bytes")
        #expect(PlanCoding.decode(data)?.count == 86)
        let median = planMedian("plan-weeks-decode") { _ = PlanCoding.decode(data) }
        #expect(median < .milliseconds(5))
    }

    /// One keystroke in the editor on the 86-week draft, with the 66 books' real chapter counts, so
    /// nothing is flagged: the line's text set, its flags and whether the plan can be saved worked out.
    @Test func oneKeystrokeInTheEditorOnEightySixWeeks() throws {
        let fixture = try PlanModelFixture(today: Self.today)
        let session = PlanEditorSession(model: fixture.model)
        session.chapterCountsOverride = PlanEditorBenchmark.realChapterCounts
        session.draft = PlanDraft(plan: PlanSample.gen2Shaped(today: Self.today))
        #expect(session.draft?.weeks.count == 86 && session.canSave && session.flags.isEmpty)
        var typed = 0
        let median = planMedian("editor-keystroke-model") {
            typed += 1
            PlanEditorBenchmark.type(typed, in: session, week: 40, row: 2)
        }
        #expect(session.canSave && session.flags.isEmpty && median < .milliseconds(2))
    }

    /// The worst case beside it: the fixture Bible lacks most chapters, so most lines are flagged, and
    /// the line typed in goes between flagged and not, so the list to check changes on every key.
    @Test func oneKeystrokeInTheEditorWithEveryLineFlagged() throws {
        let fixture = try PlanModelFixture(today: Self.today)
        let session = PlanEditorSession(model: fixture.model)
        session.draft = PlanDraft(plan: PlanSample.gen2Shaped(today: Self.today))
        #expect(session.draft?.weeks.count == 86 && session.canSave)
        var typed = 0
        let median = planMedian("editor-keystroke-model-325-flags") {
            typed += 1
            PlanEditorBenchmark.type(typed, in: session, week: 40, row: 2)
        }
        print("benchmark editor-keystroke-model flags \(session.flags.count)")
        #expect(session.canSave && median < .milliseconds(30))
    }
}

/// What the editor's keystroke benchmarks share.
@MainActor enum PlanEditorBenchmark {
    /// The 66 books' chapter counts, in canon order.
    static let realChapterCounts: [String: Int] = {
        let counts = [50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10, 13, 10, 42, 150, 31, 12, 8, 66, 52, 5, 48,
                      12, 14, 3, 9, 1, 4, 7, 3, 3, 3, 2, 14, 4,
                      28, 16, 24, 21, 28, 16, 16, 13, 6, 6, 4, 4, 5, 3, 6, 4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22]
        let books = BookCatalog.all.filter { $0.canon != .apocrypha }
        precondition(books.count == counts.count)
        return Dictionary(uniqueKeysWithValues: zip(books.map(\.id), counts))
    }()

    /// The `typed`-th key in a line, through the field's own path: its text goes between two readable forms.
    static func type(_ typed: Int, in session: PlanEditorSession, week: Int, row: Int) {
        guard let id = session.draft?.weeks[week].readings[row].id else { return }
        session.setText(typed.isMultiple(of: 2) ? "Psalms 84; Genesis 1-3" : "Psalms 84; Genesis 1-33", ofReading: id)
    }
}

/// Spec 6.1: a PDF drawn at the church's second layout, 86 weeks of four readings and a date each.
@Suite(.serialized) struct PlanPDFBenchmarkTests {
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// 13 pages: six weeks on the first (under the header), seven on each after.
    static func drawnPlan() throws -> URL {
        let start = PlanDay(year: 2026, month: 9, day: 15)!
        var pages: [[PlanPDFDrawing.Cell]] = []
        var page = PlanPDFDrawing.gen2Header()
        var top: CGFloat = 643.6
        var onPage = 0
        for week in 1...86 {
            if onPage == (pages.isEmpty ? 6 : 7) {
                pages.append(page)
                page = []
                top = 700
                onPage = 0
            }
            var y = top - CGFloat(onPage) * 5 * 18.5
            for row in 0..<4 {
                let index = (week - 1) * 4 + row
                let first = 3 * (index % 16) + 1
                page += PlanPDFDrawing.gen2Row(wk: row == 1 ? "Wk" : row == 2 ? "\(week)" : "", "Psalms", "\(index % 150 + 1)", "Genesis", "\(first)-\(first + 2)", y: y)
                y -= 18.5
            }
            let day = start.adding(days: 7 * (week - 1))
            page.append(.init(text: "\(months[day.month - 1]) \(day.day)", centre: 338, y: y, leading: true))
            onPage += 1
        }
        pages.append(page)
        return try PlanPDFDrawing.pdf(named: "Gen 2 Drawn.pdf", pages: pages)
    }

    @Test func aDrawnPlanOfEightySixWeeksIsRead() throws {
        let url = try Self.drawnPlan()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var result: Result<PlanDraft, PlanFileImport.Failure>?
        let elapsed = ContinuousClock().measure { result = PlanFileImport.draft(fromFileAt: url, today: PlanDay(year: 2026, month: 11, day: 16)!) }
        let draft = try #require(try? result?.get())
        print("benchmark plan-pdf-86-weeks \(String(format: "%.0f", planMilliseconds(elapsed))) ms, 13 pages")
        #expect(draft.weeks.count == 86 && draft.weeks.allSatisfy { $0.readings.count == 4 } && draft.weeks.allSatisfy { $0.day != nil })
        #expect(elapsed < .seconds(3))
    }
}

#if os(macOS)
import AppKit
import SwiftUI

/// The plan surfaces hosted offscreen, on the largest plan the church has.
@MainActor @Suite(.serialized) struct PlanBenchmarkTests {
    private let fixture: PlanModelFixture
    private var model: ReadingPlanModel { fixture.model }
    private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 560), styleMask: [.titled], backing: .buffered, defer: false)

    /// `PlanSample.gen2Shaped` with week 53 this week and its first 200 readings ticked.
    init() throws {
        let today = PlanModelFixture.day(2026, 11, 16)
        fixture = try PlanModelFixture(today: today)
        let plan = PlanSample.gen2Shaped(today: today)
        fixture.model.save(plan)
        for reading in plan.weeks.flatMap(\.readings).prefix(200) {
            _ = try fixture.store.toggleTick(planID: plan.id, readingID: reading.id, now: Date(timeIntervalSince1970: 1))
        }
        fixture.model.reload()
    }

    /// The largest plan the church has: 86 weeks in the sidebar.
    @Test func thePlanWindowOpensOnEightySixWeeks() {
        #expect(model.followed?.weeks.count == 86 && model.ticked.count == 200 && model.thisWeek?.index == 52)
        let median = ReaderBenchmarkTests.median("plan-window-open") {
            let host = NSHostingView(rootView: PlanWindowView(model: model).frame(width: 780, height: 560))
            host.frame = NSRect(x: 0, y: 0, width: 780, height: 560)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        #expect(median < .milliseconds(150))
    }

    /// The review of 86 weeks, opened in its sheet's size.
    @Test func theReviewOpensOnEightySixWeeks() {
        let session = PlanEditorSession(model: model)
        let draft = PlanReviewBenchmarkTests.flaggedDraft(today: model.today)
        let median = ReaderBenchmarkTests.median("plan-review-open") {
            session.draft = draft
            let host = NSHostingView(rootView: PlanEditorView(session: session).frame(width: 680, height: 640))
            host.frame = NSRect(x: 0, y: 0, width: 680, height: 640)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        #expect(session.flags.count >= 1 && median < .milliseconds(300))
    }
    /// One tick on the 86-week plan with the window's views observing the model: the store's write, the
    /// followed plan's ticks fetched again (no plan is decoded), and the window laid out again over them.
    @Test func aTickWithTheWindowObservingTheModel() throws {
        let host = NSHostingView(rootView: PlanWindowView(model: model).frame(width: 780, height: 560))
        host.frame = NSRect(x: 0, y: 0, width: 780, height: 560)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        let readings = try #require(model.followed).weeks[52].readings
        var run = 0
        let median = ReaderBenchmarkTests.median("plan-window-tick-86-weeks") {
            let before = model.ticked.count
            model.toggle(readings[run % readings.count])
            run += 1
            RunLoop.current.run(until: Date())
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            #expect(model.ticked.count != before)
        }
        window.contentView = nil
        #expect(median < .milliseconds(20))
    }

    /// One keystroke in the editor on the 86-week draft with the real chapter counts (nothing is
    /// flagged), the editor laid out over the new text: in a line on screen and in one off it.
    @Test(arguments: [(0, 1, "visible"), (40, 2, "hidden")])
    func oneKeystrokeInTheHostedEditorOnEightySixWeeks(week: Int, row: Int, place: String) {
        let session = PlanEditorSession(model: model)
        session.chapterCountsOverride = PlanEditorBenchmark.realChapterCounts
        session.draft = PlanDraft(plan: PlanSample.gen2Shaped(today: model.today))
        let host = NSHostingView(rootView: PlanEditorView(session: session).frame(width: 680, height: 640))
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 640)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        var typed = 0
        let median = ReaderBenchmarkTests.median("plan-editor-keystroke-hosted-\(place)") {
            typed += 1
            PlanEditorBenchmark.type(typed, in: session, week: week, row: row)
            RunLoop.current.run(until: Date())
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        window.contentView = nil
        #expect(session.canSave && session.flags.isEmpty && median < .milliseconds(33))
    }

    /// The 67-week sample on week 63, five readings a week: each of its 67 weeks chosen in turn with the
    /// arrow keys (up from 63 to 1, then down to 67), the window laid out after each.
    @Test func choosingEachWeekInTurn() throws {
        let gen1 = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        gen1.model.save(PlanSample.gen1Shaped())
        gen1.model.anchor(week: 62, on: PlanModelFixture.day(2026, 11, 17))
        #expect(gen1.model.thisWeek?.index == 62)
        let host = NSHostingView(rootView: PlanWindowView(model: gen1.model).frame(width: 780, height: 560))
        host.frame = NSRect(x: 0, y: 0, width: 780, height: 560)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        window.makeFirstResponder(host)
        func press(_ code: Int, _ key: Int) {
            let character = String(UnicodeScalar(key)!)
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                         characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: UInt16(code))!
            window.sendEvent(event)
            RunLoop.current.run(until: Date())
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        func snapshot() -> Data? {
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
            host.cacheDisplay(in: host.bounds, to: rep)
            return rep.representation(using: .png, properties: [:])
        }
        let first = snapshot()
        let clock = ContinuousClock()
        var timings: [Duration] = []
        for _ in 0..<62 { timings.append(clock.measure { press(126, NSUpArrowFunctionKey) }) }     // weeks 62 down to 1
        let atWeekOne = snapshot()
        for _ in 0..<66 { timings.append(clock.measure { press(125, NSDownArrowFunctionKey) }) }       // weeks 2 up to 67
        window.contentView = nil
        #expect(timings.count == 128 && first != atWeekOne && atWeekOne != snapshot())
        let sorted = timings.sorted()
        let median = sorted[sorted.count / 2]
        print("benchmark plan-window-choose-week median of 128 moves (67 weeks) \(String(format: "%.1f", BookBenchmarkTests.milliseconds(median))) ms, slowest \(String(format: "%.1f", BookBenchmarkTests.milliseconds(sorted[sorted.count - 1]))) ms")
        #expect(median < .milliseconds(16))
    }

    /// The band's summary alone at 820 pt wide, on a week of five readings of three passages each.
    @Test func theBandWithAFullWeek() throws {
        let plans = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        var plan = PlanSample.gen1Shaped()
        for row in plan.weeks[62].readings.indices {
            plan.weeks[62].readings[row].passages.append(PlanPassage(book: "PRO", chapter: row + 1))
        }
        plans.model.save(plan)
        plans.model.anchor(week: 62, on: PlanModelFixture.day(2026, 11, 17))
        let week = try #require(plans.model.thisWeek)
        #expect(week.index == 62 && week.week.readings.count == 5 && week.week.readings.allSatisfy { $0.passages.count == 3 })
        let median = ReaderBenchmarkTests.median("plan-band-full-week") {
            let host = NSHostingView(rootView: PlanWeekSummary(model: plans.model, onShowWholePlan: {}).frame(width: 820))
            host.frame = NSRect(x: 0, y: 0, width: 820, height: 400)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        // The band as the front page lays it out in an 820 pt window: 512 pt wide, so the five wrap to a second row.
        let wrapped = ReaderBenchmarkTests.median("plan-band-full-week-wrapped-512") {
            let host = NSHostingView(rootView: PlanWeekSummary(model: plans.model, onShowWholePlan: {}).frame(width: 512))
            host.frame = NSRect(x: 0, y: 0, width: 512, height: 400)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
        }
        window.contentView = nil
        #expect(median < .milliseconds(30) && wrapped < .milliseconds(30))
    }
}
#endif

#if os(iOS)
import SwiftUI
import UIKit

/// The Plan tab hosted in a phone-sized window, on the largest plan the church has.
@MainActor @Suite(.serialized) struct PhonePlanBenchmarkTests {
    /// `PlanSample.gen2Shaped` with week 53 this week; 86 weeks, this week's readings open.
    @Test func thePlanTabLaysOutEightySixWeeks() throws {
        let today = PlanModelFixture.day(2026, 11, 16)
        let fixture = try PlanModelFixture(today: today)
        fixture.model.save(PlanSample.gen2Shaped(today: today))
        #expect(fixture.model.followed?.weeks.count == 86 && fixture.model.thisWeek?.index == 52)
        let shell = PhoneShellModel()
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.isHidden = false
        defer { window.isHidden = true }
        let clock = ContinuousClock()
        let timings = (0..<9).map { _ in
            clock.measure {
                window.rootViewController = UIHostingController(rootView: PhonePlanScreen(plans: fixture.model, shell: shell))
                window.layoutIfNeeded()
            }
        }.sorted()
        let median = timings[4]
        print("benchmark plan-tab-layout median of 9 \(median)")
        #expect(median < .milliseconds(250))
    }
    /// The 67-week sample on week 63 (five readings a week): the tab laid out and scrolled to this week.
    @Test func thePlanTabOpensOnWeekSixtyThree() throws {
        let fixture = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        fixture.model.save(PlanSample.gen1Shaped())
        fixture.model.anchor(week: 62, on: PlanModelFixture.day(2026, 11, 17))
        #expect(fixture.model.followed?.weeks.count == 67 && fixture.model.thisWeek?.index == 62)
        let shell = PhoneShellModel()
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.isHidden = false
        defer { window.isHidden = true }
        let clock = ContinuousClock()
        let timings = (0..<9).map { _ in
            clock.measure {
                window.rootViewController = UIHostingController(rootView: PhonePlanScreen(plans: fixture.model, shell: shell))
                window.layoutIfNeeded()
                RunLoop.current.run(until: Date())          // the scroll to this week, run again once the bar's inset is in
                window.layoutIfNeeded()
            }
        }.sorted()
        let median = timings[4]
        print("benchmark plan-tab-week-63-of-67 median of 9 \(median)")
        #expect(median < .milliseconds(250))
    }
}
#endif
