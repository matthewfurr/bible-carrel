import Foundation
import Observation
import ScriptureData
import ScriptureModel
import SwiftData
@testable import ScriptureUI

/// A `ReadingPlanModel` on an in-memory store, a scratch `UserDefaults` suite (removed when the
/// fixture goes), a fixed day, a Gregorian UTC calendar and the US locale, over the fixture Bible
/// (WEB: PSA, MAT, TOB). Keep the fixture alive as long as the test uses the model.
///
///     let f = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
///     f.model.save(PlanModelFixture.small)
///     f.clock.date = PlanModelFixture.day(2026, 11, 18).date(in: f.calendar)
///     f.model.refreshToday()
@MainActor final class PlanModelFixture {
    /// What the model reads as now; set `date`, then `model.refreshToday()`.
    final class Clock: @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    static let locale = Locale(identifier: "en_US")

    static func day(_ year: Int, _ month: Int, _ day: Int) -> PlanDay { PlanDay(year: year, month: month, day: day)! }

    /// Three weeks dated 10, 17 and 24 November 2026, each with "Psalms 2:1-6; Matthew 5-6" and
    /// "Genesis 1"; ids fixed, `createdAt` 1.
    static let small: ReadingPlan = {
        let weeks = (0..<3).map { offset in
            PlanWeek(number: offset + 1, day: day(2026, 11, 10 + 7 * offset), label: nil, readings: [
                PlanReading(id: UUID(uuidString: String(format: "5E000000-0000-4000-8000-%04X00000001", offset + 1))!, label: nil, passages: [
                    PlanPassage(book: "PSA", chapter: 2, verse: 1, endVerse: 6),
                    PlanPassage(book: "MAT", chapter: 5, endChapter: 6)]),
                PlanReading(id: UUID(uuidString: String(format: "5E000000-0000-4000-8000-%04X00000002", offset + 1))!, label: nil, passages: [
                    PlanPassage(book: "GEN", chapter: 1)]),
            ])
        }
        return ReadingPlan(id: UUID(uuidString: "5E000000-0000-4000-8000-000000000001")!, title: "Small plan",
                           createdAt: Date(timeIntervalSince1970: 1), modifiedAt: Date(timeIntervalSince1970: 1), weeks: weeks)
    }()

    let model: ReadingPlanModel
    let store: PlanStore
    let navigation: NavigationModel
    let positions: ReadingPositionStore
    let defaults: UserDefaults
    let clock: Clock
    let calendar = PlanModelFixture.calendar
    let locale = PlanModelFixture.locale
    private let container: ModelContainer
    private let suiteName: String

    init(today: PlanDay) throws {
        suiteName = "PlanModelFixture-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        positions = ReadingPositionStore(defaults: defaults)
        navigation = try NavigationModel(store: try FixtureStore.make(), positionStore: positions, defaultTranslationID: "WEB")
        container = try MarkupContainer.make(inMemory: true)
        store = PlanStore(container: container)
        clock = Clock(today.date(in: Self.calendar))
        let clock = clock
        model = ReadingPlanModel(store: store, navigation: navigation, defaults: defaults,
                                 calendar: Self.calendar, locale: Self.locale, now: { clock.date })
    }

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
}

/// Whether anything `read` reads has changed since `observing` was called: one change is enough.
final class ObservedChange: @unchecked Sendable {
    private(set) var fired = false

    @MainActor static func observing(_ read: () -> Void) -> ObservedChange {
        let change = ObservedChange()
        withObservationTracking(read) { change.fired = true }
        return change
    }
}
