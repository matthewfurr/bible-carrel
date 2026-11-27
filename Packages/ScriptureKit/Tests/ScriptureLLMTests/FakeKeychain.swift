import Foundation
import Security
@testable import ScriptureLLM

/// A Keychain in memory for `KeychainStore`: generic-password data keyed by account and by which
/// keychain holds it. A query with `kSecUseDataProtectionKeychain: true` or a true
/// `kSecAttrSynchronizable` reaches the data-protection keychain; one with neither reaches the
/// file-based (login) keychain, as on macOS. Set `dataProtectionAvailable` to false to make every
/// data-protection call return `errSecMissingEntitlement`, as in a build without the entitlement.
/// Set `failNextWrite` to make the next add, update or delete return that status and change nothing.
final class FakeKeychain: KeychainAccess, @unchecked Sendable {
    private struct Key: Hashable {
        let account: String
        let dataProtection: Bool
    }

    private var items: [Key: Data] = [:]
    private var _failNextWrite: OSStatus?
    private var _dataProtectionAvailable = true
    private var _adds = 0
    private var _updates = 0
    private let lock = NSLock()

    var failNextWrite: OSStatus? {
        get { lock.withLock { _failNextWrite } }
        set { lock.withLock { _failNextWrite = newValue } }
    }
    var dataProtectionAvailable: Bool {
        get { lock.withLock { _dataProtectionAvailable } }
        set { lock.withLock { _dataProtectionAvailable = newValue } }
    }
    var adds: Int { lock.withLock { _adds } }
    var updates: Int { lock.withLock { _updates } }

    /// An item the old (file-based) build saved.
    func seedFileBased(_ value: String, account: String) {
        lock.withLock { items[Key(account: account, dataProtection: false)] = Data(value.utf8) }
    }

    /// What one keychain holds for the account, or nil.
    func stored(account: String, dataProtection: Bool) -> String? {
        lock.withLock {
            items[Key(account: account, dataProtection: dataProtection)].map { String(decoding: $0, as: UTF8.self) }
        }
    }

    private static func key(_ dictionary: CFDictionary) -> Key {
        let dictionary = dictionary as NSDictionary
        let account = dictionary[kSecAttrAccount as String] as? String ?? ""
        let dataProtection = (dictionary[kSecUseDataProtectionKeychain as String] as? Bool) == true
            || (dictionary[kSecAttrSynchronizable as String] as? Bool) == true
        return Key(account: account, dataProtection: dataProtection)
    }

    private static func data(_ dictionary: CFDictionary) -> Data? {
        (dictionary as NSDictionary)[kSecValueData as String] as? Data
    }

    /// The status a call to the keychain `key` names returns before it does anything, if any:
    /// the missing entitlement, or (for a write) the injected failure, which it clears. Call it
    /// under the lock.
    private func refusal(_ key: Key, write: Bool) -> OSStatus? {
        if key.dataProtection, !_dataProtectionAvailable { return errSecMissingEntitlement }
        guard write else { return nil }
        defer { _failNextWrite = nil }
        return _failNextWrite
    }

    func copyMatching(_ query: CFDictionary) -> (OSStatus, CFTypeRef?) {
        lock.withLock {
            let key = Self.key(query)
            if let refusal = refusal(key, write: false) { return (refusal, nil) }
            guard let data = items[key] else { return (errSecItemNotFound, nil) }
            return (errSecSuccess, data as CFData)
        }
    }

    func add(_ attributes: CFDictionary) -> OSStatus {
        lock.withLock {
            let key = Self.key(attributes)
            if let refusal = refusal(key, write: true) { return refusal }
            guard items[key] == nil else { return errSecDuplicateItem }
            items[key] = Self.data(attributes) ?? Data()
            _adds += 1
            return errSecSuccess
        }
    }

    func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus {
        lock.withLock {
            let key = Self.key(query)
            if let refusal = refusal(key, write: true) { return refusal }
            guard items[key] != nil else { return errSecItemNotFound }
            if let data = Self.data(attributes) { items[key] = data }
            _updates += 1
            return errSecSuccess
        }
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        lock.withLock {
            let key = Self.key(query)
            if let refusal = refusal(key, write: true) { return refusal }
            return items.removeValue(forKey: key) == nil ? errSecItemNotFound : errSecSuccess
        }
    }
}
