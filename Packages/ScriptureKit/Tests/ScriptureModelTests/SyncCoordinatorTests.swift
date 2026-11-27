import Foundation
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct SyncCoordinatorTests {
    private let dev = SyncConfiguration(containerIdentifier: MarkupContainer.developmentContainerIdentifier, environment: .development)
    private let seeds = [
        PromptSeed(key: "a", title: "A", body: "{{chapter_text}} a", scope: .chapter),
        PromptSeed(key: "b", title: "B", body: "{{selection}} b", scope: .selection),
    ]

    /// Counts calls to the coordinator's `refresh` and `onPrepared`.
    private final class Counter {
        var value = 0
    }

    /// A location under a fresh temporary directory, for `sync` (nil: the local directory).
    private func makeLocation(sync: SyncConfiguration?) throws -> StoreLocation {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "SyncCoordinatorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return StoreLocation.resolve(sync: sync, applicationSupport: root)
    }

    private func makeCoordinator(
        _ container: ModelContainer, sync: SyncConfiguration?, location: StoreLocation? = nil,
        timeout: Duration = .seconds(60), refreshes: Counter
    ) throws -> SyncCoordinator {
        SyncCoordinator(
            container: container, location: try location ?? makeLocation(sync: sync), sync: sync, seeds: seeds,
            legacyPromptOrder: [], firstImportTimeout: timeout, refresh: { refreshes.value += 1 })
    }

    private func colors(in container: ModelContainer) throws -> [HighlightColor] {
        try container.mainContext.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    private func count<Model: PersistentModel>(_ type: Model.Type, in container: ModelContainer) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<Model>())
    }

    /// The five default colors as a first import would bring them: keyed, in their own records.
    private func insertKeyedDefaults(into container: ModelContainer) throws {
        let context = container.mainContext
        for (index, color) in MarkupContainer.defaultColors.enumerated() {
            let inserted = HighlightColor(name: color.name, lightHex: color.lightHex, darkHex: color.darkHex, sortOrder: index, isDefault: true)
            inserted.builtInKey = MarkupContainer.defaultColorKeys[index]
            context.insert(inserted)
        }
        try context.save()
    }

    @Test func thePolicyWaitsOnlyForAFreshSyncedStoreWithAnAccount() {
        #expect(SyncCoordinator.shouldWaitForFirstImport(sync: dev, storeIsEmpty: true, accountAvailable: true))
        #expect(!SyncCoordinator.shouldWaitForFirstImport(sync: nil, storeIsEmpty: true, accountAvailable: true))
        #expect(!SyncCoordinator.shouldWaitForFirstImport(sync: dev, storeIsEmpty: false, accountAvailable: true))
        #expect(!SyncCoordinator.shouldWaitForFirstImport(sync: dev, storeIsEmpty: true, accountAvailable: false))
    }

    @Test func withoutSyncEverythingIsSeededAtOnce() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: nil, refreshes: refreshes)
        coordinator.start(accountAvailable: true)
        let colors = try colors(in: container)
        #expect(colors.count == 5)
        #expect(colors.map(\.builtInKey) == MarkupContainer.defaultColorKeys.map(Optional.some))
        #expect(try count(PromptTemplate.self, in: container) == 2)
        #expect(coordinator.isPrepared)
        #expect(refreshes.value == 1)
    }

    @Test func aFreshSyncedStoreWaitsForTheFirstImport() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: dev, timeout: .seconds(60), refreshes: refreshes)
        coordinator.start(accountAvailable: true)
        #expect(try count(HighlightColor.self, in: container) == 0)
        #expect(!coordinator.isPrepared)
    }

    @Test func whatTheCloudBroughtIsNotSeededAgain() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: dev, refreshes: refreshes)
        coordinator.start(accountAvailable: true)
        try insertKeyedDefaults(into: container)
        coordinator.importFinished()
        #expect(try count(HighlightColor.self, in: container) == 5)
        #expect(coordinator.isPrepared)
    }

    @Test func anEmptyCloudSeedsAfterTheImport() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: dev, refreshes: refreshes)
        coordinator.start(accountAvailable: true)
        coordinator.importFinished()
        #expect(try count(HighlightColor.self, in: container) == 5)
        #expect(try count(PromptTemplate.self, in: container) == 2)
    }

    @Test func noAccountSeedsAtOnce() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: dev, refreshes: refreshes)
        coordinator.start(accountAvailable: false)
        #expect(try count(HighlightColor.self, in: container) == 5)
    }

    @Test func theTimeoutSeeds() async throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: dev, timeout: .milliseconds(10), refreshes: refreshes)
        coordinator.start(accountAvailable: true)
        try await Task.sleep(for: .milliseconds(200))
        // Under the whole parallel suite the main actor can be busy past 200 ms; allow up to 5 s.
        let deadline = ContinuousClock.now + .seconds(5)
        while !coordinator.isPrepared, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(coordinator.isPrepared)
        #expect(try count(HighlightColor.self, in: container) == 5)
    }

    @Test func theOldStoreIsImportedBeforeSeeding() throws {
        let location = try makeLocation(sync: dev)
        let legacyURL = try #require(location.legacyStoreURL)
        try FileManager.default.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = MarkupContainer.schema
        let legacy = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: legacyURL, cloudKitDatabase: .none)])
        let legacyContext = legacy.mainContext
        var yellowID: UUID?
        for (index, color) in MarkupContainer.defaultColors.enumerated() {
            let keyless = HighlightColor(name: color.name, lightHex: color.lightHex, darkHex: color.darkHex, sortOrder: index, isDefault: true)
            if index == 0 { yellowID = keyless.uuid }
            legacyContext.insert(keyless)
        }
        legacyContext.insert(Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7,
                                       translationID: "ESV", colorID: yellowID, quotedText: "Blessed"))
        try legacyContext.save()

        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: dev, location: location, refreshes: refreshes)
        withExtendedLifetime(legacy) { coordinator.prepareNow() }
        let colors = try colors(in: container)
        #expect(colors.count == 5)
        #expect(colors.allSatisfy { $0.builtInKey != nil })
        #expect(try count(Highlight.self, in: container) == 1)
    }

    @Test func aLaterImportMergesADuplicateDefault() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: nil, refreshes: refreshes)
        coordinator.start(accountAvailable: true)
        let yellow = MarkupContainer.defaultColors[0]
        let second = HighlightColor(name: yellow.name, lightHex: yellow.lightHex, darkHex: yellow.darkHex, sortOrder: 0, isDefault: true)
        second.builtInKey = "yellow"
        container.mainContext.insert(second)
        try container.mainContext.save()
        coordinator.importFinished()
        #expect(try count(HighlightColor.self, in: container) == 5)
    }

    @Test func everyImportRefreshes() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let coordinator = try makeCoordinator(container, sync: nil, refreshes: refreshes)
        coordinator.start(accountAvailable: true)
        coordinator.importFinished()
        coordinator.importFinished()
        #expect(refreshes.value == 3)
    }

    /// What ran, in order.
    private final class Events {
        var names: [String] = []
    }

    private struct Failure: Error {}

    @Test func everyImportSettlesBeforeItRefreshes() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let events = Events()
        let coordinator = SyncCoordinator(
            container: container, location: try makeLocation(sync: nil), sync: nil, seeds: seeds,
            legacyPromptOrder: [], refresh: { events.names.append("refresh") })
        coordinator.onMerged = { events.names.append("settle") }
        coordinator.start(accountAvailable: true)
        #expect(events.names == ["settle", "refresh"])
        coordinator.importFinished()
        coordinator.importFinished()
        #expect(events.names == ["settle", "refresh", "settle", "refresh", "settle", "refresh"])

        // One that throws is logged and rolled back, and the refresh still runs.
        coordinator.onMerged = {
            events.names.append("failing settle")
            throw Failure()
        }
        events.names = []
        coordinator.importFinished()
        #expect(events.names == ["failing settle", "refresh"])
    }

    @Test func onPreparedFiresOnce() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let refreshes = Counter()
        let prepared = Counter()
        let coordinator = try makeCoordinator(container, sync: nil, refreshes: refreshes)
        coordinator.onPrepared = { prepared.value += 1 }
        coordinator.start(accountAvailable: true)
        #expect(prepared.value == 1)
        coordinator.prepareNow()
        coordinator.importFinished()
        coordinator.importFinished()
        #expect(prepared.value == 1)
    }
}
