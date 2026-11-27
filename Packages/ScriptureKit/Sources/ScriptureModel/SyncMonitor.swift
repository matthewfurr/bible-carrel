import CloudKit
import CoreData
import Foundation
import os

/// Why a sync did not finish, reduced to what the reader can act on.
public enum SyncFailure: Equatable, Sendable {
    case quotaExceeded
    case noAccount
    case network
    case other(String)
}

/// One Core Data CloudKit event: setting up, importing or exporting, in flight while `ended` is nil.
public struct SyncEvent: Equatable, Sendable {
    public enum Kind: Sendable {
        case setup, importing, exporting
    }

    public var kind: Kind
    public var started: Date
    public var ended: Date?
    public var failure: SyncFailure?

    public init(kind: Kind, started: Date, ended: Date?, failure: SyncFailure?) {
        self.kind = kind
        self.started = started
        self.ended = ended
        self.failure = failure
    }
}

/// Turns `NSPersistentCloudKitContainer` events into `SyncEvent`s and logs each one.
@MainActor public final class SyncMonitor {
    public var onEvent: ((SyncEvent) -> Void)?

    private let center: NotificationCenter
    private var observer: (any NSObjectProtocol)?
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")

    public init(center: NotificationCenter = .default) {
        self.center = center
    }

    isolated deinit {
        if let observer { center.removeObserver(observer) }
    }

    /// Starts observing the container's events. Calling it again does nothing.
    ///
    /// The observer runs on the posting thread (`queue: nil`) and hops to the main actor itself:
    /// a queue-bound observer makes CloudKit's thread wait for the main queue, which deadlocks
    /// against a main thread blocked in a synchronous call such as `initializeCloudKitSchema()`.
    public func start() {
        guard observer == nil else { return }
        observer = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  let mapped = Self.syncEvent(from: event) else { return }
            Task { @MainActor [weak self] in self?.receive(mapped) }
        }
    }

    private func receive(_ event: SyncEvent) {
        let ended = event.ended.map { "\($0)" } ?? "in flight"
        let failure = event.failure.map { "\($0)" } ?? "none"
        logger.log("\(String(describing: event.kind), privacy: .public) started \(event.started, privacy: .public), ended \(ended, privacy: .public), failure \(failure, privacy: .public)")
        onEvent?(event)
    }

    private nonisolated static func syncEvent(from event: NSPersistentCloudKitContainer.Event) -> SyncEvent? {
        let kind: SyncEvent.Kind
        switch event.type {
        case .setup: kind = .setup
        case .import: kind = .importing
        case .export: kind = .exporting
        @unknown default: return nil
        }
        var failure: SyncFailure?
        if event.endDate != nil, !event.succeeded {
            failure = Self.failure(from: event.error) ?? .other("")
        }
        return SyncEvent(kind: kind, started: event.startDate, ended: event.endDate, failure: failure)
    }

    /// Maps a CloudKit error to what the reader can act on; a partial failure reports its worst part.
    public nonisolated static func failure(from error: (any Error)?) -> SyncFailure? {
        guard let error else { return nil }
        let nsError = error as NSError
        guard nsError.domain == CKErrorDomain, let code = CKError.Code(rawValue: nsError.code) else {
            return .other(error.localizedDescription)
        }
        switch code {
        case .quotaExceeded:
            return .quotaExceeded
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return .noAccount
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .network
        case .partialFailure:
            let partErrors = (nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: any Error])?.values
            let parts = partErrors.map { $0.compactMap { failure(from: $0) } } ?? []
            for worst in [SyncFailure.quotaExceeded, .noAccount, .network] where parts.contains(worst) {
                return worst
            }
            return .other(error.localizedDescription)
        default:
            return .other(error.localizedDescription)
        }
    }
}
