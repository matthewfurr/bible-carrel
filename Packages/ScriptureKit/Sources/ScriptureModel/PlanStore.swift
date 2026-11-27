import Foundation
import ScriptureData
import SwiftData

/// A tick as it was stored, kept so a deleted plan's ticks can come back.
public struct TickSnapshot: Equatable, Sendable {
    public let uuid: UUID, readingID: UUID, tickedAt: Date
}

/// A deleted plan with its ticks, kept so the delete can be undone.
public struct PlanDeletion: Equatable, Sendable {
    public let plan: ReadingPlan
    public let ticks: [TickSnapshot]
    public static let actionName = "Delete Plan"
    /// The record's weeks exactly as stored, so undoing the delete of a plan this build cannot read loses nothing.
    let weeksData: Data
}

public enum PlanStoreError: Error, Equatable {
    /// The plan, or its stored record, was written by a version this build cannot read.
    case unreadable
}

/// Reading plans and their ticks on the markup container, a second store as `ChatStore` is.
/// Every mutation saves.
@MainActor
public final class PlanStore {
    public let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Plans

    /// By `createdAt`, then `uuid.uuidString`. A record whose weeks cannot be read is listed with
    /// `isReadable` false and no weeks. Records that share a uuid are one plan (two devices that each
    /// restored one backup before the other's restore arrived): listed once, as the latest
    /// `modifiedAt` has it. Neither is ever deleted as a duplicate, since no rule could make two
    /// devices delete the same one of two identical records.
    public func plans() throws -> [ReadingPlan] {
        Dictionary(grouping: try context.fetch(FetchDescriptor<PlanRecord>()), by: \.uuid).values
            .compactMap(Self.latest)
            .sorted { $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.uuid.uuidString < $1.uuid.uuidString }
            .map(Self.plan(of:))
    }

    public func plan(id: UUID) throws -> ReadingPlan? {
        try Self.latest(records(id: id)).map(Self.plan(of:))
    }

    /// Inserts a record for a new id, or sets `title`, `modifiedAt` and `weeksData` on every stored
    /// record of that id, then deletes every tick of the plan whose reading it no longer has. Throws
    /// `.unreadable`, changing nothing, for a plan that is not readable or a stored record that is not.
    public func save(_ plan: ReadingPlan) throws {
        guard plan.isReadable else { throw PlanStoreError.unreadable }
        let stored = try records(id: plan.id)
        if stored.contains(where: { PlanCoding.decode($0.weeksData) == nil }) { throw PlanStoreError.unreadable }
        let weeksData = try PlanCoding.encode(plan.weeks)

        if stored.isEmpty {
            let record = PlanRecord()
            record.uuid = plan.id
            record.title = plan.title
            record.createdAt = plan.createdAt
            record.modifiedAt = plan.modifiedAt
            record.weeksData = weeksData
            context.insert(record)
        }
        for record in stored {
            record.title = plan.title
            record.modifiedAt = plan.modifiedAt
            record.weeksData = weeksData
        }
        let kept = plan.readingIDs
        for tick in try ticks(planID: plan.id) where tick.readingID.map(kept.contains) == false {
            context.delete(tick)
        }
        try context.save()
    }

    /// Removes every record of the plan and every tick and returns what it removed; nil when the plan is gone.
    @discardableResult
    public func delete(planID: UUID) throws -> PlanDeletion? {
        let records = try records(id: planID)
        guard let stored = Self.latest(records) else { return nil }
        let ticks = try ticks(planID: planID)
        let deletion = PlanDeletion(
            plan: Self.plan(of: stored),
            ticks: ticks.compactMap { tick in
                tick.readingID.map { TickSnapshot(uuid: tick.uuid, readingID: $0, tickedAt: tick.tickedAt) }
            },
            weeksData: stored.weeksData)
        for tick in ticks { context.delete(tick) }
        for record in records { context.delete(record) }
        try context.save()
        return deletion
    }

    /// Puts the plan back with its id and dates when it is absent, and each tick (by its own uuid)
    /// whose reading has no tick. A second call changes nothing.
    public func restore(_ deletion: PlanDeletion) throws {
        let plan = deletion.plan
        var changed = false
        if try records(id: plan.id).isEmpty {
            let record = PlanRecord()
            record.uuid = plan.id
            record.title = plan.title
            record.createdAt = plan.createdAt
            record.modifiedAt = plan.modifiedAt
            record.weeksData = deletion.weeksData
            context.insert(record)
            changed = true
        }
        var ticked = try tickedReadingIDs(planID: plan.id)
        for snapshot in deletion.ticks where !ticked.contains(snapshot.readingID) {
            let tick = PlanTick(planID: plan.id, readingID: snapshot.readingID, tickedAt: snapshot.tickedAt)
            tick.uuid = snapshot.uuid
            context.insert(tick)
            ticked.insert(snapshot.readingID)
            changed = true
        }
        if changed { try context.save() }
    }

    // MARK: - Ticks

    /// Every reading of the plan with a tick, whether or not the plan still has that reading.
    public func tickedReadingIDs(planID: UUID) throws -> Set<UUID> {
        Set(try ticks(planID: planID).compactMap(\.readingID))
    }

    /// Returns whether the reading is now ticked. Unticking deletes every tick the reading has in
    /// the plan; ticking inserts one.
    @discardableResult
    public func toggleTick(planID: UUID, readingID: UUID, now: Date = Date()) throws -> Bool {
        let existing = try ticks(planID: planID).filter { $0.readingID == readingID }
        if existing.isEmpty {
            context.insert(PlanTick(planID: planID, readingID: readingID, tickedAt: now))
        } else {
            for tick in existing { context.delete(tick) }
        }
        try context.save()
        return existing.isEmpty
    }

    // MARK: - Fetches

    private func records(id: UUID) throws -> [PlanRecord] {
        try context.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate { $0.uuid == id }))
    }

    /// Of records sharing a uuid, the one with the latest `modifiedAt`; twins with one date are the same.
    private static func latest(_ records: [PlanRecord]) -> PlanRecord? {
        records.max { $0.modifiedAt < $1.modifiedAt }
    }

    private func ticks(planID: UUID) throws -> [PlanTick] {
        let id: UUID? = planID
        return try context.fetch(FetchDescriptor<PlanTick>(predicate: #Predicate { $0.planID == id }))
    }

    private static func plan(of record: PlanRecord) -> ReadingPlan {
        let weeks = PlanCoding.decode(record.weeksData)
        return ReadingPlan(id: record.uuid, title: record.title, createdAt: record.createdAt, modifiedAt: record.modifiedAt,
                           weeks: weeks ?? [], isReadable: weeks != nil)
    }
}
