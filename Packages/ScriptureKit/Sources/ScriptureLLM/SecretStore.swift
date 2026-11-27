import Foundation
import Security

public enum SecretStoreError: Error, Equatable {
    case keychain(OSStatus)
}

/// Where API keys live. The app uses the Keychain; tests use memory. Keys are never written to
/// `UserDefaults` or the log.
public protocol SecretStore: Sendable {
    func secret(for id: LLMProviderID) throws -> String?
    /// Trims whitespace and newlines; an empty result deletes the item.
    func setSecret(_ value: String?, for id: LLMProviderID) throws
}

extension SecretStore {
    /// A pasted key with a stray space or newline is the key the reader meant.
    static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var secrets: [LLMProviderID: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func secret(for id: LLMProviderID) throws -> String? {
        lock.withLock { secrets[id] }
    }

    public func setSecret(_ value: String?, for id: LLMProviderID) throws {
        let normalized = Self.normalized(value)
        lock.withLock { secrets[id] = normalized }
    }
}

/// The four `SecItem*` calls `KeychainStore` makes, so tests can stand in for the Keychain.
public protocol KeychainAccess: Sendable {
    func copyMatching(_ query: CFDictionary) -> (OSStatus, CFTypeRef?)
    func add(_ attributes: CFDictionary) -> OSStatus
    func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}

/// The real Keychain.
public struct SecurityKeychain: KeychainAccess {
    public init() {}

    public func copyMatching(_ query: CFDictionary) -> (OSStatus, CFTypeRef?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query, &result)
        return (status, result)
    }

    public func add(_ attributes: CFDictionary) -> OSStatus {
        SecItemAdd(attributes, nil)
    }

    public func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus {
        SecItemUpdate(query, attributes)
    }

    public func delete(_ query: CFDictionary) -> OSStatus {
        SecItemDelete(query)
    }
}

/// Generic-password items, one per provider, kept as synchronizable items in the data-protection
/// keychain so iCloud Keychain carries them to the reader's other devices. Reads look there first,
/// then in the file-based (login) keychain an older, ad-hoc signed build wrote to. A build without
/// the keychain-access-groups entitlement is refused the data-protection keychain
/// (`errSecMissingEntitlement`), so a new key is then added to the file-based one as before.
/// A key updates the item in place, so a failed write never leaves the reader without the old one.
public struct KeychainStore: SecretStore {
    /// The app's bundle identifier, so a Debug build (`….dev`) never sees or moves the Release
    /// build's keys; the Release build keeps the service it always had.
    public static let service = service(forBundleIdentifier: Bundle.main.bundleIdentifier)

    /// The identifier when it is not empty, else the Release build's identifier.
    public static func service(forBundleIdentifier identifier: String?) -> String {
        guard let identifier, !identifier.isEmpty else { return "com.matthewfurr.ReadingThroughScripture" }
        return identifier
    }

    private let service: String
    private let access: any KeychainAccess

    public init(service: String = service, access: any KeychainAccess = SecurityKeychain()) {
        self.service = service
        self.access = access
    }

    static func account(for id: LLMProviderID) -> String {
        "llm.\(id.rawValue)"
    }

    /// The item in the file-based (login) keychain: neither data-protection flag, so on macOS the
    /// query reaches only that keychain, and only a non-synchronizable item matches.
    private func fileBasedQuery(for id: LLMProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account(for: id),
        ]
    }

    /// The item in the data-protection keychain, synchronizable or not.
    private func dataProtectionQuery(for id: LLMProviderID) -> [String: Any] {
        var query = fileBasedQuery(for: id)
        query[kSecUseDataProtectionKeychain as String] = true
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        return query
    }

    /// A new synchronizable item in the data-protection keychain.
    private func synchronizableItem(for id: LLMProviderID, data: Data) -> [String: Any] {
        var item = fileBasedQuery(for: id)
        item[kSecUseDataProtectionKeychain as String] = true
        item[kSecAttrSynchronizable as String] = true
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        item[kSecValueData as String] = data
        return item
    }

    /// The status of a lookup and, when it succeeded, the item's data.
    private func read(_ query: [String: Any]) -> (OSStatus, Data?) {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, result) = access.copyMatching(query as CFDictionary)
        return (status, status == errSecSuccess ? result as? Data : nil)
    }

    /// Nothing there, or a build that may not use that keychain: look in the other one.
    private static func isAbsent(_ status: OSStatus) -> Bool {
        status == errSecItemNotFound || status == errSecMissingEntitlement
    }

    private static func string(_ data: Data?) -> String? {
        normalized(data.flatMap { String(data: $0, encoding: .utf8) })
    }

    /// The data-protection keychain first, then the file-based one. A data-protection failure
    /// other than "nothing there" is thrown only when the file-based keychain has no key either.
    public func secret(for id: LLMProviderID) throws -> String? {
        let (status, data) = read(dataProtectionQuery(for: id))
        if status == errSecSuccess, let value = Self.string(data) { return value }
        let (fileStatus, fileData) = read(fileBasedQuery(for: id))
        if fileStatus == errSecSuccess { return Self.string(fileData) }
        guard fileStatus == errSecItemNotFound else { throw SecretStoreError.keychain(fileStatus) }
        guard status == errSecSuccess || Self.isAbsent(status) else { throw SecretStoreError.keychain(status) }
        return nil
    }

    /// Nil or blank deletes the item from both keychains. A key updates the item in place
    /// wherever it is and is added only when there is none, so the old key is never deleted
    /// before the new one is written. A new item goes to the data-protection keychain, or to the
    /// file-based one when this build may not use that.
    public func setSecret(_ value: String?, for id: LLMProviderID) throws {
        guard let normalized = Self.normalized(value) else {
            let status = access.delete(dataProtectionQuery(for: id) as CFDictionary)
            let fileStatus = access.delete(fileBasedQuery(for: id) as CFDictionary)
            guard status == errSecSuccess || Self.isAbsent(status) else { throw SecretStoreError.keychain(status) }
            guard fileStatus == errSecSuccess || fileStatus == errSecItemNotFound else {
                throw SecretStoreError.keychain(fileStatus)
            }
            return
        }
        let data = Data(normalized.utf8)
        let attributes = [kSecValueData as String: data] as CFDictionary
        let updateStatus = access.update(dataProtectionQuery(for: id) as CFDictionary, attributes)
        if updateStatus == errSecSuccess { return }
        guard Self.isAbsent(updateStatus) else { throw SecretStoreError.keychain(updateStatus) }
        let fileUpdateStatus = access.update(fileBasedQuery(for: id) as CFDictionary, attributes)
        if fileUpdateStatus == errSecSuccess { return }
        guard fileUpdateStatus == errSecItemNotFound else { throw SecretStoreError.keychain(fileUpdateStatus) }
        var status = access.add(synchronizableItem(for: id, data: data) as CFDictionary)
        if status == errSecMissingEntitlement || status == errSecParam {
            var item = fileBasedQuery(for: id)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            item[kSecValueData as String] = data
            status = access.add(item as CFDictionary)
        }
        guard status == errSecSuccess else { throw SecretStoreError.keychain(status) }
    }

    /// Moves each key an older build left in the file-based keychain to a synchronizable item in
    /// the data-protection keychain. A provider that already has a data-protection item is left
    /// alone. The old item is deleted only after its copy is written, so any failure leaves it in
    /// place, still read by `secret(for:)`. Returns the providers whose key moved.
    @discardableResult
    public func upgradeToSynchronizable(_ ids: [LLMProviderID]) -> [LLMProviderID] {
        ids.filter { id in
            let (status, _) = read(dataProtectionQuery(for: id))
            guard status == errSecItemNotFound else { return false }
            let (fileStatus, fileData) = read(fileBasedQuery(for: id))
            guard fileStatus == errSecSuccess, let fileData, Self.string(fileData) != nil else { return false }
            guard access.add(synchronizableItem(for: id, data: fileData) as CFDictionary) == errSecSuccess else { return false }
            return access.delete(fileBasedQuery(for: id) as CFDictionary) == errSecSuccess
        }
    }
}
