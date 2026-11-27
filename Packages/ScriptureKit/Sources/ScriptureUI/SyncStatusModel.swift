import CloudKit
import Foundation
import Observation
import ScriptureModel

/// The iCloud account as CloudKit reports it.
public enum AccountStatus: Sendable {
    case available, noAccount, restricted, temporarilyUnavailable, unknown
}

/// Where the account status comes from; a fake in tests, CloudKit in the app.
public protocol AccountStatusSource: Sendable {
    func status() async -> AccountStatus
}

/// The account status of one CloudKit container. An error reads as `.unknown`.
public struct CloudKitAccountSource: AccountStatusSource {
    private let containerIdentifier: String

    public init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
    }

    public func status() async -> AccountStatus {
        do {
            switch try await CKContainer(identifier: containerIdentifier).accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable: return .temporarilyUnavailable
            case .couldNotDetermine: return .unknown
            @unknown default: return .unknown
            }
        } catch {
            return .unknown
        }
    }
}

/// What the status line shows.
public enum SyncState: Equatable, Sendable {
    case off
    case noAccount
    case unavailable
    case waiting
    case syncing
    case synced(Date)
    case failing(SyncFailure, since: Date)
}

/// Turns sync events and the iCloud account status into the one sentence Settings shows.
@MainActor @Observable public final class SyncStatusModel {
    public private(set) var state: SyncState
    public private(set) var lastSynced: Date?
    /// True once an import has finished without a failure in this launch.
    public private(set) var hasImportedThisLaunch = false
    /// Failing for want of space or for an unknown reason, with no successful sync for at least a
    /// day (counted from the last sync recorded, across launches, or else from the first failure
    /// in this run); offline never counts. Recomputed on every event, every account check, and
    /// every 15 minutes while failing, so the toolbar notice appears without a state change.
    public private(set) var needsAttention = false
    public var onFirstImport: (() -> Void)?
    public var onImport: (() -> Void)?

    public static let lastSyncedKey = "lastSyncedAt"
    public static let attentionAfter: TimeInterval = 86_400
    /// How often the attention notice is checked again while sync is failing.
    static let attentionCheckInterval: Duration = .seconds(15 * 60)

    /// The locale for relative and calendar dates; tests pin it.
    var locale: Locale = .autoupdatingCurrent
    /// The device the sentences say the notes stay on ("Mac", "iPhone"); tests pin it.
    var deviceName = DeviceName.current

    @ObservationIgnored private let isSyncOn: Bool
    @ObservationIgnored private let account: any AccountStatusSource
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var attentionTimer: Task<Void, Never>?

    public init(
        sync: SyncConfiguration?,
        account: any AccountStatusSource,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        isSyncOn = sync != nil
        self.account = account
        self.defaults = defaults
        self.now = now
        state = sync == nil ? .off : .waiting
        lastSynced = defaults.object(forKey: Self.lastSyncedKey) as? Date
    }

    /// Asks iCloud for the account status and shows it.
    public func refreshAccount() async {
        guard isSyncOn else { return }
        switch await account.status() {
        case .noAccount:
            state = .noAccount
        case .restricted, .temporarilyUnavailable, .unknown:
            state = .unavailable
        case .available:
            switch state {
            case .syncing, .synced, .failing: break
            case .off, .noAccount, .unavailable, .waiting: state = .waiting
            }
        }
        refreshAttention()
    }

    /// Takes one event from the sync monitor.
    public func handle(_ event: SyncEvent) {
        guard isSyncOn else { return }
        defer { refreshAttention() }
        guard let ended = event.ended else {
            if case .failing = state { return }
            state = .syncing
            return
        }
        switch event.failure {
        case nil:
            state = .synced(ended)
            lastSynced = ended
            defaults.set(ended, forKey: Self.lastSyncedKey)
            if event.kind == .importing {
                if !hasImportedThisLaunch {
                    hasImportedThisLaunch = true
                    onFirstImport?()
                }
                onImport?()
            }
        case .noAccount:
            state = .noAccount
        case let failure?:
            if case let .failing(_, since) = state {
                state = .failing(failure, since: since)
            } else {
                state = .failing(failure, since: ended)
            }
        }
    }

    /// Restore is safe when sync is off, or once iCloud has brought back what it holds in this
    /// launch; before that, every record a restore adds would arrive a second time from iCloud.
    public var canRestore: Bool {
        state == .off || (isAccountAvailable && hasImportedThisLaunch)
    }

    public var isAccountAvailable: Bool {
        switch state {
        case .off, .noAccount, .unavailable: false
        case .waiting, .syncing, .synced, .failing: true
        }
    }

    public var statusText: String {
        switch state {
        case .off:
            "Sync is off in this build. Your notes stay on this \(deviceName)."
        case .noAccount, .failing(.noAccount, _):
            "Not signed in to iCloud. Notes you make now stay on this \(deviceName), and your synced notes return when you sign in."
        case .unavailable:
            "iCloud is not available right now. Notes you make stay on this \(deviceName) until it is."
        case .waiting:
            lastSynced.map(syncedText) ?? "Waiting for iCloud."
        case .syncing:
            "Syncing…"
        case let .synced(date):
            syncedText(date)
        case .failing(.quotaExceeded, _):
            "iCloud storage is full. Notes you make stay on this \(deviceName) until there is room."
        case .failing(.network, _):
            "No connection. Your notes sync when you are back online."
        case .failing(.other, _):
            "Could not sync. The app will try again."
        }
    }

    public var symbolName: String {
        switch state {
        case .off, .noAccount, .unavailable, .failing(.noAccount, _): "icloud.slash"
        case .failing(.quotaExceeded, _), .failing(.other, _): "exclamationmark.icloud"
        case .waiting, .syncing, .synced, .failing(.network, _): "icloud"
        }
    }

    /// Shows the attention notice as if sync had been failing since a day ago, whatever the state.
    /// Set only by a Debug build's `-forceSyncAttention YES`, so the notice can be seen.
    public var forcedAttention = false {
        didSet { refreshAttention() }
    }

    /// Works out `needsAttention` from the state and the clock, and keeps a 15-minute timer
    /// running while sync fails in a way that can come to need attention.
    func refreshAttention() {
        let failingSince: Date? = switch state {
        case let .failing(.quotaExceeded, since), let .failing(.other, since): since
        default: nil
        }
        let attention = forcedAttention
            || failingSince.map { now().timeIntervalSince(lastSynced ?? $0) >= Self.attentionAfter } ?? false
        if needsAttention != attention { needsAttention = attention }

        if failingSince == nil {
            attentionTimer?.cancel()
            attentionTimer = nil
        } else if attentionTimer == nil {
            attentionTimer = Task { [weak self] in
                while true {
                    do {
                        try await Task.sleep(for: Self.attentionCheckInterval)
                    } catch {
                        return
                    }
                    guard let self else { return }
                    self.refreshAttention()
                }
            }
        }
    }

    /// Help for the attention badge, naming the day sync last worked (the last sync recorded, or
    /// else the first failure in this run). Empty unless failing.
    public var attentionHelp: String {
        let since: Date
        if forcedAttention {
            since = now().addingTimeInterval(-Self.attentionAfter)
        } else if case let .failing(_, failingSince) = state {
            since = lastSynced ?? failingSince
        } else {
            return ""
        }
        let day = since.formatted(Date.FormatStyle(locale: locale).weekday(.wide).month().day())
        return "Your notes have not synced since \(day). Open Settings."
    }

    private func syncedText(_ date: Date) -> String {
        let current = now()
        if current.timeIntervalSince(date) < 60 { return "Synced just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = locale
        return "Synced " + formatter.localizedString(for: date, relativeTo: current)
    }
}
