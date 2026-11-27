import Foundation
import OSLog

/// A key-value store shared between the reader's devices. Values are property-list types.
public protocol KeyValueCloud: AnyObject {
    func object(forKey key: String) -> Any?
    /// Nil removes the value.
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
    /// Called with the keys another device changed.
    var onExternalChange: (([String]) -> Void)? { get set }
    /// Called when the device's iCloud account changed (signed out, or into another account):
    /// the store now holds that account's values, and a key it lacks is not a removal.
    var onAccountChange: (() -> Void)? { get set }
}

/// The iCloud key-value store. Changes arrive on the main queue; a quota violation is not a
/// change and is ignored.
public final class UbiquitousKeyValueCloud: KeyValueCloud, @unchecked Sendable {
    private let store = NSUbiquitousKeyValueStore.default
    private let center: NotificationCenter
    private var observer: (any NSObjectProtocol)?
    public var onExternalChange: (([String]) -> Void)?
    public var onAccountChange: (() -> Void)?

    public init(center: NotificationCenter = .default) {
        self.center = center
        observer = center.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] note in
            let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
                let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                self?.onExternalChange?(keys)
            case NSUbiquitousKeyValueStoreAccountChange:
                self?.onAccountChange?()
            default:
                break
            }
        }
    }

    deinit {
        if let observer { center.removeObserver(observer) }
    }

    public func object(forKey key: String) -> Any? {
        store.object(forKey: key)
    }

    public func set(_ value: Any?, forKey key: String) {
        if let value {
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    @discardableResult
    public func synchronize() -> Bool {
        store.synchronize()
    }
}

/// The `UserDefaults` keys that follow the reader between devices (Ruling 9): the reading
/// position, the default translation, the page settings that shape the text (style, face, verse
/// layout, verse numbers, section headings, justification), the noteless-highlights and
/// note-editing settings, the compare set, the Library's dates setting and whether its notice was answered, and the assistant's provider, models and compatible base URL, and which reading plan is followed. The text
/// size, line spacing,
/// column width and appearance stay on the device.
public enum SyncedPreferences {
    public static let positionKey = "readingPosition"
    /// Main-actor isolated because `MarkupModel`'s key is.
    @MainActor public static let keys: [String] = [
        positionKey,
        positionKey + ".translationID",
        ReaderSettings.defaultTranslationKey,
        ReaderSettings.pageStyleKey,
        ReaderSettings.pageFaceKey,
        ReaderSettings.verseLayoutKey,
        ReaderSettings.showsVerseNumbersKey,
        ReaderSettings.showsSectionHeadingsKey,
        ReaderSettings.justifiedKey,
        MarkupModel.showNotelessHighlightsKey,
        NoteEditingKeys.settingKey,
        CompareSet.key,
        LibraryDates.showKey,
        LibraryDates.noticeAnsweredKey,
        AssistantSettings.providerKey,
        AssistantSettings.anthropicModelKey,
        AssistantSettings.openAIModelKey,
        AssistantSettings.compatibleBaseURLKey,
        AssistantSettings.compatibleModelKey,
        ReadingPlanModel.followedPlanKey,
    ]
}

/// Mirrors a fixed set of `UserDefaults` keys onto a key-value cloud, so every `@AppStorage` that
/// reads them keeps working. A local change is pushed 2 seconds after the last one (or by
/// `pushPending()`); a change from another device is written into the defaults and not pushed back.
@MainActor public final class PreferenceSync {
    public var onExternalChange: (([String]) -> Void)?

    private let defaults: UserDefaults
    private let cloud: any KeyValueCloud
    private let keys: [String]
    private let center: NotificationCenter
    /// The value each key last had in the defaults, as this object knows it.
    private var known: [String: Any] = [:]
    private var pending: Set<String> = []
    private var pushTimer: Task<Void, Never>?
    private var observer: (any NSObjectProtocol)?
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")

    static let pushDelay: Duration = .seconds(2)

    public init(defaults: UserDefaults, cloud: any KeyValueCloud, keys: [String] = SyncedPreferences.keys,
                center: NotificationCenter = .default) {
        self.defaults = defaults
        self.cloud = cloud
        self.keys = keys
        self.center = center
    }

    isolated deinit {
        pushTimer?.cancel()
        if let observer { center.removeObserver(observer) }
    }

    /// Takes what the cloud holds, offers up what only this device has, then listens to both sides.
    public func start() {
        guard observer == nil else { return }
        let synchronized = cloud.synchronize()
        let (taken, offered) = merge()
        logger.log("key-value store synchronize \(synchronized, privacy: .public): \(taken.count) preferences taken, \(offered) offered")
        cloud.onExternalChange = { [weak self] changed in
            MainActor.assumeIsolated { self?.applyExternal(changed) }
        }
        cloud.onAccountChange = { [weak self] in
            MainActor.assumeIsolated { self?.applyAccountChange() }
        }
        // `readingPosition.translationID` has a dot, so the watched keys are compared on every
        // defaults change rather than key-value observed.
        observer = center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.noteLocalChanges() }
            } else {
                Task { @MainActor in self?.noteLocalChanges() }
            }
        }
    }

    /// Pushes every local change not yet in the cloud; a removal removes the cloud value.
    public func pushPending() {
        pushTimer?.cancel()
        pushTimer = nil
        guard !pending.isEmpty else { return }
        for key in keys where pending.contains(key) {
            cloud.set(defaults.object(forKey: key), forKey: key)
        }
        logger.log("pushed \(self.pending.sorted(), privacy: .public)")
        pending.removeAll()
    }

    private func noteLocalChanges() {
        var changed = false
        for key in keys {
            let value = defaults.object(forKey: key)
            guard !Self.same(value, known[key]) else { continue }
            known[key] = value
            pending.insert(key)
            changed = true
        }
        guard changed else { return }
        pushTimer?.cancel()
        pushTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.pushDelay)
            guard !Task.isCancelled else { return }
            self?.pushPending()
        }
    }

    /// For each key, a cloud value is written into the defaults and a key only the defaults have is
    /// pushed up; no local value is ever removed. Returns the keys whose local value changed and the
    /// number pushed.
    private func merge() -> (taken: [String], offered: Int) {
        var taken: [String] = []
        var offered = 0
        for key in keys {
            if let value = cloud.object(forKey: key) {
                // Known before the write, so the defaults notification it posts finds nothing to push.
                known[key] = value
                pending.remove(key)
                if !Self.same(value, defaults.object(forKey: key)) {
                    defaults.set(value, forKey: key)
                    taken.append(key)
                }
            } else if let value = defaults.object(forKey: key) {
                cloud.set(value, forKey: key)
                known[key] = value
                pending.remove(key)
                offered += 1
            } else {
                known[key] = nil
            }
        }
        return (taken, offered)
    }

    /// Another account's store is not a set of removals: merge with it as at launch.
    private func applyAccountChange() {
        let (taken, offered) = merge()
        logger.log("account change: \(taken, privacy: .public) taken, \(offered) offered")
        if !taken.isEmpty { onExternalChange?(taken) }
    }

    private func applyExternal(_ changed: [String]) {
        let watched = changed.filter(keys.contains)
        guard !watched.isEmpty else { return }
        for key in watched {
            let value = cloud.object(forKey: key)
            // Known before the write, so the defaults notification it posts finds nothing to push.
            known[key] = value
            pending.remove(key)
            guard !Self.same(value, defaults.object(forKey: key)) else { continue }
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        logger.log("external change \(watched, privacy: .public)")
        onExternalChange?(watched)
    }

    private static func same(_ a: Any?, _ b: Any?) -> Bool {
        (a as? NSObject) == (b as? NSObject)
    }
}
