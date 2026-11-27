import Foundation

/// Persistence of the reading position in `UserDefaults`. In a build that syncs, `PreferenceSync`
/// mirrors this key (and its `.translationID`) through the iCloud key-value store.
/// `UserDefaults` is documented thread-safe, so sharing one instance across isolation domains is sound.
public final class ReadingPositionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "readingPosition") {
        self.defaults = defaults
        self.key = key
    }

    /// Nil when nothing is stored or the stored data cannot be decoded.
    public func load() -> ReadingPosition? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReadingPosition.self, from: data)
    }

    /// Sorted keys, so an unchanged position is the same bytes in every process and is not synced again.
    public func save(_ position: ReadingPosition) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(position) else { return }
        defaults.set(data, forKey: key)
    }

    /// Removes the position; the translation choice is kept.
    public func clear() {
        defaults.removeObject(forKey: key)
    }

    // MARK: - Translation choice, kept apart from the position so it survives without a chapter

    private var translationKey: String { key + ".translationID" }

    public func loadTranslationID() -> String? {
        defaults.string(forKey: translationKey)
    }

    public func save(translationID: String) {
        defaults.set(translationID, forKey: translationKey)
    }
}
