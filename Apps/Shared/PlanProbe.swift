#if DEBUG
import Foundation
import OSLog
import ScriptureData
import ScriptureModel
import SwiftData

/// A Debug-only hook for the plan rehearsal: `-planProbe make | large | clear`, run once the
/// coordinator has prepared, on both apps.
///
/// - `make` saves the stand-in plan and ticks its first two readings, unless that plan is there.
/// - `large` saves the 86-week plan, retitled "Probe: 86 weeks", and ticks every reading of weeks
///   1 to 51, three of week 52's and two of week 53's, unless that plan is there.
/// - `clear` deletes the plans with those two ids, with their ticks, and nothing else.
///
/// It refuses the main store of the containers Matt reads from (and any default-named store when
/// sync is off), and it never writes a preference.
enum PlanProbe {
    static let argument = "planProbe"
    private static let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")

    enum ProbeError: Error {
        case unrecognized
    }

    /// True when a probe was asked for and changed the store, so the models need reloading.
    @MainActor @discardableResult
    static func runIfAsked(container: ModelContainer, location: StoreLocation, sync: SyncConfiguration?) -> Bool {
        guard let form = UserDefaults.standard.string(forKey: argument), !form.isEmpty else { return false }
        // `StoreLocation.refusesProbes`, tested in `StoreLocationTests`.
        if location.refusesProbes(sync: sync) {
            logger.log("plan probe refused: never in the main store")
            return false
        }
        do {
            if try run(form, store: PlanStore(container: container)) {
                logger.log("plan probe done: \(form, privacy: .public)")
                return true
            }
            logger.log("plan probe already there: \(form, privacy: .public)")
        } catch {
            logger.error("plan probe failed: \(form, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        return false
    }

    /// False when `make` or `large` found its plan already stored and did nothing.
    @MainActor private static func run(_ form: String, store: PlanStore) throws -> Bool {
        let today = PlanDay(Date(), calendar: .current)
        switch form {
        case "make":
            guard try store.plan(id: PlanSample.standInID) == nil else { return false }
            let plan = PlanSample.standIn(today: today)
            try store.save(plan)
            for reading in plan.weeks.flatMap(\.readings).prefix(2) {
                try store.toggleTick(planID: plan.id, readingID: reading.id)
            }
        case "large":
            guard try store.plan(id: PlanSample.largeID) == nil else { return false }
            var plan = PlanSample.gen2Shaped(today: today)
            plan.title = "Probe: 86 weeks"
            try store.save(plan)
            for week in plan.weeks {
                let count = switch week.number {
                case ..<52: week.readings.count
                case 52: 3
                case 53: 2
                default: 0
                }
                for reading in week.readings.prefix(count) {
                    try store.toggleTick(planID: plan.id, readingID: reading.id)
                }
            }
        case "clear":
            try store.delete(planID: PlanSample.standInID)
            try store.delete(planID: PlanSample.largeID)
        default:
            throw ProbeError.unrecognized
        }
        return true
    }
}
#endif
