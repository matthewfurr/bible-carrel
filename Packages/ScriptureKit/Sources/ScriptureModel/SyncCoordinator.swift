import Foundation
import OSLog
import SwiftData

/// Seeds the default colors and built-in prompts only once the store has seen what iCloud already
/// holds, and after every import merges duplicate defaults and asks the app to reload.
///
/// A fresh synced store with an iCloud account waits for the first import (or the timeout) before
/// preparing; any other store prepares at once. Preparing runs once per launch. Every step logs a
/// failure to the `sync` category and the rest still run: a failed step rolls back its unsaved
/// changes, the old store's import writes no marker on failure (so the next launch tries again),
/// and seeding is skipped by nothing but a non-empty table, so a later launch fills what is missing.
@MainActor
public final class SyncCoordinator {
    public private(set) var isPrepared = false
    /// Called once, at the end of the first `prepareNow()`.
    public var onPrepared: (@MainActor () -> Void)?
    /// Called after every merge of duplicates, before the refresh: keeps the texts this device lost
    /// to the import and tidies the kept versions (`MarkupStore.settleVersions`).
    public var onMerged: (@MainActor () throws -> Void)?

    private let container: ModelContainer
    private let location: StoreLocation
    private let sync: SyncConfiguration?
    private let seeds: [PromptSeed]
    private let legacyPromptOrder: [String]
    private let firstImportTimeout: Duration
    private let refresh: @MainActor () -> Void
    private var timeout: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")

    public init(
        container: ModelContainer, location: StoreLocation, sync: SyncConfiguration?, seeds: [PromptSeed],
        legacyPromptOrder: [String], firstImportTimeout: Duration = .seconds(15), refresh: @escaping @MainActor () -> Void
    ) {
        self.container = container
        self.location = location
        self.sync = sync
        self.seeds = seeds
        self.legacyPromptOrder = legacyPromptOrder
        self.firstImportTimeout = firstImportTimeout
        self.refresh = refresh
    }

    /// True only for a synced store with no colors and no prompts and an available account.
    public static func shouldWaitForFirstImport(sync: SyncConfiguration?, storeIsEmpty: Bool, accountAvailable: Bool) -> Bool {
        sync != nil && storeIsEmpty && accountAvailable
    }

    /// Prepares now, or arms the timeout and waits for the first import.
    public func start(accountAvailable: Bool) {
        guard !isPrepared, timeout == nil else { return }
        guard Self.shouldWaitForFirstImport(sync: sync, storeIsEmpty: storeIsEmpty(), accountAvailable: accountAvailable) else {
            prepareNow()
            return
        }
        logger.log("waiting for the first import")
        timeout = Task { [weak self, firstImportTimeout] in
            do {
                try await Task.sleep(for: firstImportTimeout)
            } catch {
                return
            }
            guard let self, !self.isPrepared else { return }
            self.logger.log("first import timed out")
            self.prepareNow()
        }
    }

    /// One import has finished: prepares if still waiting, otherwise merges duplicates, keeps lost texts and refreshes.
    public func importFinished() {
        logger.log("import finished")
        guard isPrepared else {
            prepareNow()
            return
        }
        step("merging duplicates") { _ = try SeedMerge.mergeAll(in: context, seeds: seeds) }
        step("keeping versions") { try onMerged?() }
        refresh()
    }

    /// The old store's import, the color seeding and migrations, the prompt seeding and migration,
    /// the merges, the kept versions, then `refresh` and `onPrepared`. Runs once; later calls do nothing.
    public func prepareNow() {
        guard !isPrepared else { return }
        isPrepared = true
        timeout?.cancel()
        timeout = nil

        step("importing the old store") {
            if let summary = try LegacyImport.importIfNeeded(location, into: container) {
                logger.log("old store imported: \(summary.total, privacy: .public) records")
            }
        }
        step("seeding the default colors") { try MarkupContainer.seedDefaultColorsIfNeeded(in: context) }
        step("migrating the default colors") { _ = try MarkupContainer.migrateDefaultColorsIfNeeded(in: context) }
        // Cosmetic: a failure leaves the old swatches.
        step("conforming the highlight colors") { _ = try MarkupContainer.conformColorsIfNeeded(in: context) }
        step("assigning default color keys") { _ = try SeedMerge.assignDefaultColorKeysIfNeeded(in: context) }
        let templates = PromptTemplateStore(container: container)
        step("seeding the built-in prompts") { _ = try templates.seedIfNeeded(seeds) }
        // Cosmetic too: the prompts keep their old order and sections.
        step("migrating the built-in prompts") { _ = try templates.migrateBuiltInsIfNeeded(from: seeds, legacyOrder: legacyPromptOrder) }
        step("merging duplicates") { _ = try SeedMerge.mergeAll(in: context, seeds: seeds) }
        step("keeping versions") { try onMerged?() }
        logger.log("prepared")
        refresh()
        onPrepared?()
    }

    private var context: ModelContext { container.mainContext }

    /// No colors and no prompts. A store that cannot be counted is treated as not empty, so it
    /// prepares at once rather than waiting.
    private func storeIsEmpty() -> Bool {
        do {
            return try context.fetchCount(FetchDescriptor<HighlightColor>()) == 0
                && context.fetchCount(FetchDescriptor<PromptTemplate>()) == 0
        } catch {
            logger.error("counting the store failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Runs one step; a failure is logged and its unsaved changes rolled back, and the next step runs.
    private func step(_ name: String, _ work: () throws -> Void) {
        do {
            try work()
        } catch {
            context.rollback()
            logger.error("\(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }
}
