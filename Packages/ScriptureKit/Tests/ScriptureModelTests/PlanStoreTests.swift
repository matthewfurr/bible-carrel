import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct PlanStoreTests {
    private let plan = PlanSample.gen1Shaped()

    private func makeStore() throws -> PlanStore {
        PlanStore(container: try MarkupContainer.make(inMemory: true))
    }

    private func count<Model: PersistentModel>(_ type: Model.Type, in store: PlanStore) throws -> Int {
        try store.container.mainContext.fetchCount(FetchDescriptor<Model>())
    }

    @Test func aPlanIsOneRecordAndComesBackAsItWas() throws {
        let store = try makeStore()
        try store.save(plan)
        #expect(try store.plans() == [plan] && store.plan(id: plan.id) == plan && store.plan(id: UUID()) == nil)
        var edited = plan
        edited.title = "RTS Gen 1"
        edited.modifiedAt = Date(timeIntervalSince1970: 50)
        try store.save(edited)
        #expect(try store.plans() == [edited] && count(PlanRecord.self, in: store) == 1)             // replaced, never a second record
    }

    @Test func tickingIsOneRecordAndUntickingRemovesIt() throws {
        let store = try makeStore(), reading = plan.weeks[0].readings[0].id
        try store.save(plan)
        #expect(try store.toggleTick(planID: plan.id, readingID: reading, now: Date(timeIntervalSince1970: 5)))
        #expect(try store.tickedReadingIDs(planID: plan.id) == [reading] && count(PlanTick.self, in: store) == 1)
        #expect(try store.toggleTick(planID: plan.id, readingID: reading) == false)
        #expect(try store.tickedReadingIDs(planID: plan.id).isEmpty && count(PlanTick.self, in: store) == 0)
    }

    /// Spec 7: two devices ticked one reading before they synced.
    @Test func twoTicksForOneReadingMergeToTheEarlier() throws {
        let store = try makeStore(), context = store.container.mainContext
        try store.save(plan)
        let reading = plan.weeks[0].readings[0].id, other = plan.weeks[0].readings[1].id
        let late = PlanTick(planID: plan.id, readingID: reading, tickedAt: Date(timeIntervalSince1970: 200))
        let early = PlanTick(planID: plan.id, readingID: reading, tickedAt: Date(timeIntervalSince1970: 100))
        let stray = PlanTick(planID: UUID(), readingID: UUID(), tickedAt: Date(timeIntervalSince1970: 1))   // its plan has not arrived
        for tick in [late, early, stray, PlanTick(planID: plan.id, readingID: other, tickedAt: Date(timeIntervalSince1970: 300))] { context.insert(tick) }
        try context.save()
        #expect(try SeedMerge.mergeDuplicateTicks(in: context) == 1)
        let left = try context.fetch(FetchDescriptor<PlanTick>())
        #expect(left.count == 3 && left.first { $0.readingID == reading }?.uuid == early.uuid && left.contains { $0.uuid == stray.uuid })
        #expect(try SeedMerge.mergeAll(in: context, seeds: []) == 0)                                 // a second run changes nothing
        #expect(try store.tickedReadingIDs(planID: plan.id) == [reading, other])
    }

    @Test func savingAnEditDropsOnlyTheTicksOfReadingsRemoved() throws {
        let store = try makeStore(), ids = plan.weeks[0].readings.map(\.id)
        try store.save(plan)
        try store.toggleTick(planID: plan.id, readingID: ids[0])
        try store.toggleTick(planID: plan.id, readingID: ids[1])
        var edited = plan
        edited.weeks[0].readings.remove(at: 1)
        edited.weeks[0].readings.reverse()
        edited.weeks[0].number = 9
        try store.save(edited)
        #expect(try store.tickedReadingIDs(planID: plan.id) == [ids[0]] && count(PlanTick.self, in: store) == 1)
    }

    @Test func deletingAPlanTakesItsTicksAndRestoreBringsBothBack() throws {
        let store = try makeStore(), ids = plan.weeks[0].readings.map(\.id)
        try store.save(plan)
        try store.toggleTick(planID: plan.id, readingID: ids[0], now: Date(timeIntervalSince1970: 5))
        try store.toggleTick(planID: plan.id, readingID: ids[1], now: Date(timeIntervalSince1970: 6))
        let deletion = try #require(try store.delete(planID: plan.id))
        #expect(try store.plans().isEmpty && count(PlanTick.self, in: store) == 0 && deletion.plan == plan && deletion.ticks.count == 2)
        try store.restore(deletion)
        try store.restore(deletion)                                                                  // again: nothing doubles
        #expect(try store.plans() == [plan] && store.tickedReadingIDs(planID: plan.id) == [ids[0], ids[1]] && count(PlanTick.self, in: store) == 2)
        #expect(try Set(store.container.mainContext.fetch(FetchDescriptor<PlanTick>()).map(\.uuid)) == Set(deletion.ticks.map(\.uuid)))
        #expect(try store.delete(planID: UUID()) == nil)
    }

    @Test func aPlanFromANewerVersionIsListedAndNeverWrittenOver() throws {
        let store = try makeStore(), context = store.container.mainContext
        let newer = Data(#"{"v":2,"weeks":[]}"#.utf8), record = PlanRecord()
        record.title = "From a newer build"
        record.weeksData = newer
        context.insert(record)
        try context.save()
        let listed = try #require(try store.plans().first)
        #expect(listed.title == "From a newer build" && !listed.isReadable && listed.weeks.isEmpty && listed.id == record.uuid)
        #expect(throws: PlanStoreError.unreadable) { try store.save(listed) }
        #expect(record.weeksData == newer && record.title == "From a newer build")
    }

    /// Review Focus 3: a readable plan is never saved over a stored record of its id that this build cannot read.
    @Test func aReadablePlanIsNeverSavedOverAnUnreadableRecord() throws {
        let store = try makeStore(), context = store.container.mainContext
        try store.save(plan)
        let newer = Data(#"{"v":2,"weeks":[]}"#.utf8)
        let record = try #require(try context.fetch(FetchDescriptor<PlanRecord>()).first)
        record.weeksData = newer
        try context.save()
        var edited = plan
        edited.title = "Edited here"
        #expect(throws: PlanStoreError.unreadable) { try store.save(edited) }
        #expect(record.weeksData == newer && record.title == plan.title)
    }

    /// The reason `PlanDeletion.weeksData` is kept: a plan this build cannot read comes back byte for byte.
    @Test func anUnreadablePlanIsDeletedAndRestoredByteForByte() throws {
        let store = try makeStore(), context = store.container.mainContext
        let newer = Data(#"{"v":2,"weeks":[{"n":1}]}"#.utf8), record = PlanRecord()
        record.title = "From a newer build"
        record.weeksData = newer
        context.insert(record)
        try context.save()
        let id = record.uuid
        let deletion = try #require(try store.delete(planID: id))
        #expect(try store.plans().isEmpty && !deletion.plan.isReadable)
        try store.restore(deletion)
        let back = try #require(try context.fetch(FetchDescriptor<PlanRecord>()).first)
        #expect(try back.uuid == id && back.weeksData == newer && back.title == "From a newer build" && store.plan(id: id)?.isReadable == false)
    }

    /// I2: two devices each restored one backup before the other's restore arrived, so two records share a uuid.
    /// They are one plan: listed once, saved together, deleted together; neither is deleted as a duplicate.
    @Test func recordsSharingAUUIDAreOnePlan() throws {
        let store = try makeStore(), context = store.container.mainContext
        try store.save(plan)
        let twin = PlanRecord()
        twin.uuid = plan.id
        twin.title = "The twin, edited later"
        twin.createdAt = plan.createdAt
        twin.modifiedAt = Date(timeIntervalSince1970: 90)
        twin.weeksData = try PlanCoding.encode(plan.weeks)
        context.insert(twin)
        try context.save()
        #expect(try store.plans().map(\.title) == ["The twin, edited later"] && store.plan(id: plan.id)?.title == "The twin, edited later")
        #expect(try SeedMerge.mergeAll(in: context, seeds: []) == 0 && count(PlanRecord.self, in: store) == 2)
        var edited = plan
        edited.title = "Edited"
        edited.modifiedAt = Date(timeIntervalSince1970: 100)
        try store.save(edited)
        #expect(try context.fetch(FetchDescriptor<PlanRecord>()).map(\.title) == ["Edited", "Edited"] && store.plans() == [edited])
        try store.toggleTick(planID: plan.id, readingID: plan.weeks[0].readings[0].id)
        let deletion = try #require(try store.delete(planID: plan.id))
        #expect(try deletion.plan == edited && deletion.ticks.count == 1 && count(PlanRecord.self, in: store) == 0 && count(PlanTick.self, in: store) == 0)
        try store.restore(deletion)
        #expect(try count(PlanRecord.self, in: store) == 1 && store.plans() == [edited])
    }

    /// I2: a tick and its restored twin (one uuid) are both kept: no rule could make two devices delete the same
    /// one of two identical records. A tick of another uuid for the same reading still merges to the earlier.
    @Test func sameUUIDTicksSurviveTheMerge() throws {
        let store = try makeStore(), context = store.container.mainContext
        try store.save(plan)
        let reading = plan.weeks[0].readings[0].id
        let tick = PlanTick(planID: plan.id, readingID: reading, tickedAt: Date(timeIntervalSince1970: 100))
        let twin = PlanTick(planID: plan.id, readingID: reading, tickedAt: Date(timeIntervalSince1970: 100))
        twin.uuid = tick.uuid
        let later = PlanTick(planID: plan.id, readingID: reading, tickedAt: Date(timeIntervalSince1970: 200))
        for each in [tick, twin, later] { context.insert(each) }
        try context.save()
        #expect(try SeedMerge.mergeAll(in: context, seeds: []) == 1)
        let left = try context.fetch(FetchDescriptor<PlanTick>())
        #expect(left.count == 2 && left.allSatisfy { $0.uuid == tick.uuid })
        #expect(try SeedMerge.mergeAll(in: context, seeds: []) == 0 && store.tickedReadingIDs(planID: plan.id) == [reading])
        #expect(try store.toggleTick(planID: plan.id, readingID: reading) == false && count(PlanTick.self, in: store) == 0)   // unticking removes both
    }
}
