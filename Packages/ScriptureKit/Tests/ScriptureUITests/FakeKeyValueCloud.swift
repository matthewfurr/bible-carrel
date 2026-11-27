import Foundation
@testable import ScriptureUI

/// An in-memory key-value cloud: counts every write and delivers external changes on demand.
final class FakeKeyValueCloud: KeyValueCloud {
    private(set) var values: [String: Any] = [:]
    /// Every `set`, removals included.
    private(set) var sets = 0
    private(set) var synchronizeCount = 0
    var onExternalChange: (([String]) -> Void)?
    var onAccountChange: (() -> Void)?

    init(_ values: [String: Any] = [:]) {
        self.values = values
    }

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        sets += 1
        values[key] = value
    }

    @discardableResult
    func synchronize() -> Bool {
        synchronizeCount += 1
        return true
    }

    /// Applies changes made on another device (nil removes) and reports their keys.
    func simulateExternal(_ changes: [String: Any?]) {
        for (key, value) in changes {
            values[key] = value
        }
        onExternalChange?(Array(changes.keys))
    }

    /// The device signed into another iCloud account (or out): the store now holds `values`.
    func simulateAccountChange(to values: [String: Any]) {
        self.values = values
        onAccountChange?()
    }
}
