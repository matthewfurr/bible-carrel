#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CloudKit
import CoreData
import Observation
import OSLog
import ScriptureLLM
import ScriptureModel
import ScriptureUI
import SwiftData

/// The one object that owns sync wiring: which container this build syncs with, where its store
/// lives, the status line's model and the monitor that feeds it, and the coordinator that seeds
/// after the first import and reloads the models after every import.
@MainActor @Observable final class AppSync {
    @ObservationIgnored let sync: SyncConfiguration?
    @ObservationIgnored let location: StoreLocation
    @ObservationIgnored let status: SyncStatusModel
    /// This device's last text of each note it wrote, beside the store (`location.lastTextsDirectory`).
    @ObservationIgnored let journal: LastTextJournal
    @ObservationIgnored private(set) var coordinator: SyncCoordinator?
    /// Settings › General › Backups; a restore reloads every model. Set once the container exists.
    @ObservationIgnored private(set) var backups: BackupsModel?
    /// File › Export All Data… and Import Data…, ⌘K's two commands and the phone's Your Data rows;
    /// an import reloads every model. Set once the container exists.
    @ObservationIgnored private(set) var dataTransfer: DataTransferModel?
    /// Mirrors the reading position and the named preferences through the iCloud key-value
    /// store; nil when this build does not sync.
    @ObservationIgnored private(set) var preferences: PreferenceSync?
    /// The reader, for a position another device wrote. Set once it is built.
    @ObservationIgnored var navigation: NavigationModel?
    /// Settings › Assistant, which reads the keys again once `start` has moved them. Set once it is built.
    @ObservationIgnored var assistantSettings: AssistantSettingsModel?
    /// Goes up each time the models reload, so Settings › Prompts reloads too.
    private(set) var templatesRevision = 0

    /// The models `refreshAll` reloads.
    struct Models {
        let markup: MarkupModel
        let assistant: AssistantModel
        let notesBrowser: NotesBrowserModel
        let versions: NoteVersionsModel
        let colorSettings: ColorSettingsModel
        let plans: ReadingPlanModel
    }

    @ObservationIgnored private var models: Models?
    @ObservationIgnored private var accountChecked = false
    @ObservationIgnored private var accountCheckFallback: Task<Void, Never>?
    /// How long `attach` waits for the first account check before preparing without an account.
    static let accountCheckTimeout: Duration = .seconds(15)
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private let monitor = SyncMonitor()
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var backup: Task<Void, Never>?
    /// A backup was asked for while one was running: take it again once that one is done.
    @ObservationIgnored private var backupAgain = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")

    /// The launch argument (`-initializeCloudKitSchema YES`) that pushes the schema to a Development container.
    static let initializeSchemaArgument = "initializeCloudKitSchema"

    init() {
        let sync = SyncConfiguration.current()
        self.sync = sync
        location = StoreLocation.resolve(
            sync: sync, storeName: UserDefaults.standard.string(forKey: StoreLocation.storeNameArgument))
        journal = LastTextJournal(directory: location.lastTextsDirectory)
        let account: any AccountStatusSource = sync.map { CloudKitAccountSource(containerIdentifier: $0.containerIdentifier) }
            ?? NoAccountSource()
        status = SyncStatusModel(sync: sync, account: account)
        #if DEBUG
        // `-forceSyncAttention YES` shows the toolbar's sync notice, which otherwise needs a day of failures.
        if UserDefaults.standard.bool(forKey: "forceSyncAttention") { status.forcedAttention = true }
        #endif
        let path = location.storeURL.path(percentEncoded: false)
        if let sync {
            logger.log("store \(path, privacy: .public), sync \(sync.containerIdentifier, privacy: .public) \(sync.environment.rawValue, privacy: .public)")
        } else {
            logger.log("store \(path, privacy: .public), sync off")
        }
    }

    /// The markup container at `location`, mirrored when this build syncs. Keep it alive as long
    /// as its contexts are used.
    func makeContainer() throws -> ModelContainer {
        if let sync, sync.environment == .development,
           UserDefaults.standard.bool(forKey: Self.initializeSchemaArgument) {
            // The schema step loads and unloads the store with a second stack; never on a live store.
            if location.storeName == StoreLocation.defaultStoreName {
                logger.error("schema initialization refused: use -storeName")
            } else {
                try initializeSchema(containerIdentifier: sync.containerIdentifier)
            }
        }
        #if DEBUG && os(macOS)
        // The clash rehearsal's `-syncProbeOffline YES`: the store opened with no mirror, so a probe's
        // change stays on this Mac until the next ordinary launch sends it. Never the main store.
        if SyncProbe.isOffline {
            if location.storeName == StoreLocation.defaultStoreName {
                logger.error("offline probe refused: use -storeName")
            } else {
                logger.log("offline probe: the store is opened without its mirror")
                return try MarkupContainer.make(at: location, sync: nil)
            }
        }
        #endif
        return try MarkupContainer.make(at: location, sync: sync)
    }

    /// Hands over the container, the markup store and the models once they exist: the coordinator
    /// seeds and migrates the store (at once, or after the first import), every import reaches it,
    /// and after each the store keeps the texts this device lost.
    func attach(container: ModelContainer, store: MarkupStore, models: Models) {
        self.models = models
        let coordinator = SyncCoordinator(
            container: container, location: location, sync: sync, seeds: BuiltInPrompts.all,
            legacyPromptOrder: BuiltInPrompts.legacyOrder, refresh: { [weak self] in self?.refreshAll() })
        self.coordinator = coordinator
        coordinator.onMerged = { _ = try store.settleVersions() }
        // A restore merges any duplicate defaults it brought, then reloads every model. It waits
        // until iCloud has brought the notes back, or it would add them a second time.
        backups = BackupsModel(
            location: location, store: store,
            onRestore: { [weak coordinator] in coordinator?.importFinished() },
            canRestore: { [status] in status.canRestore })
        // As a restore does: after iCloud has brought the notes back, and every model reloads after it.
        // An edit open in a note ends first, so nothing is unsaved when the import begins.
        let info = Bundle.main.infoDictionary
        let app = "\(info?["CFBundleShortVersionString"] as? String ?? "0") (\(info?["CFBundleVersion"] as? String ?? "0"))"
        dataTransfer = DataTransferModel(
            store: store, app: app,
            onImport: { [weak coordinator] in coordinator?.importFinished() },
            canImport: { [status] in status.canRestore },
            prepare: { [markup = models.markup] in markup.endOpenEdit() })
        status.onImport = { [weak coordinator] in coordinator?.importFinished() }
        coordinator.onPrepared = { [weak self] in
            #if DEBUG && os(macOS)
            // The rehearsal's `-syncProbe`: one change on the app's own store, once prepared, never
            // in the main store. The models are reloaded only when a probe ran, so Debug starts as Release does.
            if let self {
                if !self.location.refusesProbes(sync: self.sync) {
                    if SyncProbe.runIfAsked(store: store) { self.refreshAll() }
                } else if UserDefaults.standard.string(forKey: SyncProbe.argument)?.isEmpty == false {
                    self.logger.log("probe refused: never in the main store")
                }
            }
            #endif
            #if DEBUG
            // The kept-versions rehearsal's `-versionProbe`, on both apps, after `-syncProbe`; refused in the main store.
            if let self, VersionProbe.runIfAsked(store: store, location: self.location, sync: self.sync) {
                self.refreshAll()
            }
            // The plan rehearsal's `-planProbe`, on both apps; refused in the main store.
            if let self, PlanProbe.runIfAsked(container: container, location: self.location, sync: self.sync) {
                self.refreshAll()
            }
            #endif
            // The old store's import has run: today's backup, if it was taken empty, is taken again.
            self?.backUpIfNeeded()
        }
        // The account check already came back: start now rather than wait for the next one.
        if accountChecked {
            coordinator.start(accountAvailable: status.isAccountAvailable)
        } else {
            armAccountCheckFallback()
        }
        // The first backup, now that the container has opened the store.
        backUpIfNeeded()
    }

    /// If the first account check has not come back within 15 s (`CKContainer.accountStatus` can
    /// hang), starts the coordinator as if there were no account, once, so the old store's import
    /// and the seeding still run in this launch. A late answer then finds it prepared and does nothing.
    private func armAccountCheckFallback() {
        guard accountCheckFallback == nil else { return }
        accountCheckFallback = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.accountCheckTimeout)
            } catch {
                return
            }
            guard let self, !self.accountChecked else { return }
            self.logger.log("account check timed out")
            self.coordinator?.start(accountAvailable: false)
        }
    }

    /// Starts the monitor feeding the status line and keeps the account status current. Once the
    /// first account check is back, the coordinator starts.
    func start() {
        monitor.onEvent = { [status] event in status.handle(event) }
        monitor.start()
        Task { [weak self, status] in
            await status.refreshAccount()
            guard let self else { return }
            accountChecked = true
            accountCheckFallback?.cancel()
            accountCheckFallback = nil
            coordinator?.start(accountAvailable: status.isAccountAvailable)
        }
        let center = NotificationCenter.default
        for name in [Notification.Name.CKAccountChanged, AppLifecycle.didBecomeActive] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshAccount() }
            })
        }
        observers.append(center.addObserver(forName: AppLifecycle.didBecomeActive, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.backUpIfNeeded() }
        })
        // The first backup is taken in `attach`, once the container is open.
        upgradeKeys()
    }

    /// Takes the preferences and the reading position the key-value store already holds into
    /// `UserDefaults`, before the reader is built so it opens where the reader last was, then
    /// keeps both sides current. A position from another device goes to the reader; any other
    /// preference reloads the markup model (the rest are read through `@AppStorage`).
    func startPreferences() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AppLifecycle.resignActive, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.navigation?.isAppActive = false
                self?.preferences?.pushPending()
            }
        })
        observers.append(center.addObserver(forName: AppLifecycle.didBecomeActive, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.navigation?.isAppActive = true
                self?.models?.plans.refreshToday()
            }
        })
        observers.append(center.addObserver(forName: AppLifecycle.willTerminate, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.preferences?.pushPending() }
        })
        guard sync != nil else { return }
        let preferences = PreferenceSync(defaults: .standard, cloud: UbiquitousKeyValueCloud())
        preferences.onExternalChange = { [weak self] keys in
            guard let self else { return }
            if keys.contains(where: { $0.contains(SyncedPreferences.positionKey) }) {
                navigation?.adoptStoredPosition()
            }
            if keys.contains(where: { !$0.contains(SyncedPreferences.positionKey) }) {
                models?.markup.reload()
                models?.plans.reload()
            }
        }
        self.preferences = preferences
        preferences.start()
    }

    /// Moves API keys an older build left in the login keychain to synchronizable items, off the
    /// main actor, then has Settings › Assistant read them again. Only the providers are logged.
    private func upgradeKeys() {
        let work = Task.detached(priority: .utility) {
            KeychainStore().upgradeToSynchronizable([.anthropic, .openAI, .openAICompatible])
        }
        Task { [weak self, logger] in
            let moved = await work.value
            if !moved.isEmpty {
                logger.log("keys moved to iCloud Keychain: \(moved.map(\.rawValue).joined(separator: ", "), privacy: .public)")
            }
            self?.assistantSettings?.reloadKeys()
        }
    }

    private func refreshAccount() {
        Task { [status] in await status.refreshAccount() }
    }

    /// Reloads every model 300 ms after the last request, so a burst of imports reloads once.
    func refreshAll() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            self?.reloadModels()
        }
    }

    private func reloadModels() {
        pendingRefresh = nil
        guard let models else { return }
        models.markup.reload()
        models.assistant.refresh()
        models.assistant.reloadTemplates()
        models.notesBrowser.reload()
        models.versions.reload()
        models.colorSettings.reload()
        models.plans.reload()
        templatesRevision += 1
    }

    /// Takes today's backup of the store off the main actor, one at a time, then has Settings read
    /// the newest date again. A failure is logged to the `sync` category and never shown to the reader.
    func backUpIfNeeded() {
        guard backup == nil else {
            backupAgain = true
            return
        }
        let work = Task.detached(priority: .utility) { [location, logger] in
            do {
                switch try StoreBackup.takeBackup(location) {
                case let .taken(url):
                    logger.log("backup \(url.lastPathComponent, privacy: .public)")
                case .skippedEmptyStore:
                    logger.log("backup skipped: the store is empty and the newest backup is not")
                case .notNeeded:
                    break
                }
            } catch {
                logger.error("backup failed: \(String(describing: error), privacy: .public)")
            }
        }
        backup = work
        Task { [weak self] in
            await work.value
            guard let self else { return }
            backup = nil
            backups?.refresh()
            if backupAgain {
                backupAgain = false
                backUpIfNeeded()
            }
        }
    }

    /// Apple's documented schema initialization for SwiftData ("Syncing model data across a
    /// person's devices"): a Core Data CloudKit container on the same store, then the store unloaded.
    private func initializeSchema(containerIdentifier: String) throws {
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        try autoreleasepool {
            let description = NSPersistentStoreDescription(url: location.storeURL)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            description.shouldAddStoreAsynchronously = false
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: MarkupContainer.models) else {
                logger.error("schema initialization failed: no managed object model")
                throw SchemaInitializationError.noManagedObjectModel
            }
            let container = NSPersistentCloudKitContainer(name: location.storeName, managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: (any Error)?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema()
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
        logger.log("schema initialized")
    }
}

/// Why `-initializeCloudKitSchema` stopped before pushing anything.
private enum SchemaInitializationError: Error {
    case noManagedObjectModel
}

/// The account source when sync is off: never asked, and unknown if it were.
private struct NoAccountSource: AccountStatusSource {
    func status() async -> AccountStatus { .unknown }
}

/// The app's activation notifications on each platform. iOS has no "did resign": the reader
/// leaving the app is `willResignActive` there.
private enum AppLifecycle {
    #if os(macOS)
    static let didBecomeActive = NSApplication.didBecomeActiveNotification
    static let resignActive = NSApplication.didResignActiveNotification
    static let willTerminate = NSApplication.willTerminateNotification
    #else
    static let didBecomeActive = UIApplication.didBecomeActiveNotification
    static let resignActive = UIApplication.willResignActiveNotification
    static let willTerminate = UIApplication.willTerminateNotification
    #endif
}
