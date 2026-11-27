import Foundation
import Observation
import OSLog
import ScriptureData
import ScriptureModel

/// The one model every plan surface reads: the Mac's band, the reader's button, the plan window and
/// the iPhone's Plan tab. Reloaded after an import, when the followed-plan preference arrives from
/// another device, after a change made here, and when the day changes.
@MainActor @Observable public final class ReadingPlanModel {
    public static let followedPlanKey = "followedPlanID"
    static let saveFailure = "That change could not be saved. Try it again."
    static let loadFailure = "Your reading plans could not be read. Quit and reopen the app to try again."

    public struct ThisWeek: Equatable, Sendable {
        public let index: Int
        public let week: PlanWeek
        public let count: Int
    }

    public private(set) var plans: [ReadingPlan] = []
    /// The plan the preference names, else the newest; nil with none.
    public private(set) var followed: ReadingPlan?
    /// The followed plan's ticked readings.
    public private(set) var ticked: Set<UUID> = []
    public private(set) var today: PlanDay
    public private(set) var lastError: String?
    /// The acting window's (`adoptUndoManager`); weak, and given up as its window closes, so an
    /// undo never registers in a closed window's manager.
    @ObservationIgnored public private(set) weak var undoManager: UndoManager?
    /// After a passage is opened: the main window comes forward on the Mac, the Read tab on the phone.
    @ObservationIgnored public var onOpenPassage: ((PlanPassage) -> Void)?
    /// What every date is written with, so no view or rule reads the current calendar or locale itself.
    @ObservationIgnored public let calendar: Calendar
    @ObservationIgnored public let locale: Locale

    @ObservationIgnored private let store: PlanStore
    @ObservationIgnored private let navigation: NavigationModel
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "plans")
    @ObservationIgnored nonisolated(unsafe) private var dayObservers: [any NSObjectProtocol] = []

    /// `calendar` and `locale` default to the system's as they change, so a new time zone or region
    /// is seen without a relaunch.
    public init(store: PlanStore, navigation: NavigationModel, defaults: UserDefaults = .standard,
                calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.navigation = navigation
        self.defaults = defaults
        self.calendar = calendar
        self.locale = locale
        clock = now
        today = PlanDay(now(), calendar: calendar)
        // The day changing, and the time zone (today is the day where the reader is).
        dayObservers = [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshToday() }
            }
        }
        reload()
    }

    deinit {
        for observer in dayObservers { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - Loading

    /// After an import, a preference from another device, or a change made here. Each property is
    /// assigned only when it differs, so a reload that finds nothing new redraws nothing.
    public func reload() {
        do {
            let all = try store.plans()
            if all != plans { plans = all }
            let chosen = Self.followedPlan(among: all, named: defaults.string(forKey: Self.followedPlanKey))
            if chosen != followed { followed = chosen }
            let marks = try chosen.map { try store.tickedReadingIDs(planID: $0.id) } ?? []
            if marks != ticked { ticked = marks }
        } catch {
            lastError = Self.loadFailure
            logger.error("Plan reload failed: \(error)")
        }
    }

    /// The model's clock: what a saved plan's dates are stamped with.
    var currentDate: Date { clock() }

    /// The day changed, or the app came forward.
    public func refreshToday() {
        let day = PlanDay(clock(), calendar: calendar)
        if day != today { today = day }
    }

    /// The plan named, else the one with the latest `createdAt` (ties: the lowest uuid).
    private static func followedPlan(among plans: [ReadingPlan], named name: String?) -> ReadingPlan? {
        if let name, let id = UUID(uuidString: name), let match = plans.first(where: { $0.id == id }) { return match }
        return plans.min { lhs, rhs in
            lhs.createdAt != rhs.createdAt ? lhs.createdAt > rhs.createdAt : lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // MARK: - This week

    /// nil with no plan followed, or an unreadable one.
    public var now: PlanSchedule.Now? {
        guard let followed, followed.isReadable else { return nil }
        return PlanSchedule.now(followed.weeks, today: today)
    }

    public var thisWeek: ThisWeek? {
        guard let followed, case .week(let index)? = now else { return nil }
        return ThisWeek(index: index, week: followed.weeks[index], count: followed.weeks.count)
    }

    /// Followed, dated and not finished: the band and the reader's button.
    public var showsWeek: Bool { thisWeek != nil }
    public var needsAnchor: Bool { now == .undated }
    public var isFinished: Bool { now == .finished }

    public var progress: PlanProgress {
        followed?.progress(ticked: ticked) ?? PlanProgress(read: 0, total: 0)
    }

    public func progress(ofWeek index: Int) -> PlanProgress {
        followed?.progress(ofWeek: index, ticked: ticked) ?? PlanProgress(read: 0, total: 0)
    }

    public func isTicked(_ reading: PlanReading) -> Bool {
        ticked.contains(reading.id)
    }

    // MARK: - Changes

    /// One write and the followed plan's ticks fetched again; no plan is read or decoded.
    public func toggle(_ reading: PlanReading) {
        guard let followed else { return }
        do {
            try store.toggleTick(planID: followed.id, readingID: reading.id, now: clock())
            let marks = try store.tickedReadingIDs(planID: followed.id)
            if marks != ticked { ticked = marks }
        } catch {
            lastError = Self.saveFailure
            logger.error("Plan tick failed: \(error)")
        }
    }

    /// Writes the preference.
    public func follow(_ planID: UUID) {
        defaults.set(planID.uuidString, forKey: Self.followedPlanKey)
        reload()
    }

    /// A plan with a new id is followed. False, and the failure said, when the store refused it.
    @discardableResult
    public func save(_ plan: ReadingPlan) -> Bool {
        let isNew = !plans.contains { $0.id == plan.id }
        guard change({ try store.save(plan) }) else { return false }
        if isNew { follow(plan.id) }
        return true
    }

    /// Change Meeting Date…
    public func setDay(_ day: PlanDay, ofWeek index: Int) {
        guard var plan = followed, plan.isReadable, plan.weeks.indices.contains(index) else { return }
        plan.weeks = PlanSchedule.settingDay(day, ofWeek: index, in: plan.weeks)
        plan.modifiedAt = clock()
        change { try store.save(plan) }
    }

    public func anchor(week index: Int, on day: PlanDay) {
        guard var plan = followed, plan.isReadable, plan.weeks.indices.contains(index) else { return }
        plan.weeks = PlanSchedule.anchored(plan.weeks, week: index, on: day)
        plan.modifiedAt = clock()
        change { try store.save(plan) }
    }

    /// Undoable through the window's `UndoManager`; the reader is never asked to confirm.
    public func delete(_ planID: UUID) {
        var removed: PlanDeletion?
        guard change({ removed = try store.delete(planID: planID) }), let deletion = removed else { return }
        if let undoManager {
            undoManager.registerUndo(withTarget: self) { model in
                model.restoreUndoably(deletion)
            }
            undoManager.setActionName(PlanDeletion.actionName)
        }
    }

    /// The opposite is registered only after a write that succeeded.
    private func restoreUndoably(_ deletion: PlanDeletion) {
        guard change({ try store.restore(deletion) }) else { return }
        undoManager?.registerUndo(withTarget: self) { model in
            model.deleteAgain(deletion)
        }
        undoManager?.setActionName(PlanDeletion.actionName)
    }

    private func deleteAgain(_ deletion: PlanDeletion) {
        guard change({ try store.delete(planID: deletion.plan.id) }) else { return }
        undoManager?.registerUndo(withTarget: self) { model in
            model.restoreUndoably(deletion)
        }
        undoManager?.setActionName(PlanDeletion.actionName)
    }

    /// Runs a write, then reloads; a failure is said and nothing shown changes.
    @discardableResult
    private func change<T>(_ work: () throws -> T) -> Bool {
        do {
            _ = try work()
            reload()
            return true
        } catch {
            lastError = Self.saveFailure
            logger.error("Plan change failed: \(error)")
            return false
        }
    }

    /// A window that acts on the plan (the main window's band and popover, the plan window) hands
    /// over its manager as it appears or becomes key.
    public func adoptUndoManager(_ manager: UndoManager?) {
        guard let manager else { return }
        undoManager = manager
    }

    /// A window going away gives its manager back; another window's stays.
    public func releaseUndoManager(_ manager: UndoManager?) {
        if let manager, undoManager === manager { undoManager = nil }
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: - Opening a passage

    /// True when the translation being read has the passage's book and its first chapter.
    public func canOpen(_ passage: PlanPassage) -> Bool {
        guard let count = navigation.chapterCount(ofBook: passage.book) else { return false }
        return passage.chapter >= 1 && passage.chapter <= count
    }

    /// Reading, not a lookup: it ends a lookup and goes through the history.
    public func open(_ passage: PlanPassage) {
        guard canOpen(passage) else { return }
        navigation.open(passage.startLocation, verse: passage.verse)
        onOpenPassage?(passage)
    }

    /// The translation being read's, for the review.
    public var chapterCounts: [String: Int] {
        Dictionary(navigation.books.map { ($0.book.id, $0.chapterCount) }, uniquingKeysWith: { first, _ in first })
    }

    /// `"Not in the ESV."`
    public var unavailableHelp: String {
        "Not in the \(navigation.translationID)."
    }
}
