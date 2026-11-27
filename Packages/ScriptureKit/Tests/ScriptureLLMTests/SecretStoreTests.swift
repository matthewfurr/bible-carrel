import Security
import Testing
@testable import ScriptureLLM

@Suite struct SecretStoreTests {
    @Test func keysAreTrimmedBeforeStorage() throws {
        let store = InMemorySecretStore()
        try store.setSecret("  sk-abc\n", for: .anthropic)
        #expect(try store.secret(for: .anthropic) == "sk-abc")
        #expect(try store.secret(for: .openAI) == nil)
    }

    @Test func emptyOrNilRemovesTheSecret() throws {
        let store = InMemorySecretStore()
        try store.setSecret("k", for: .openAI)
        try store.setSecret("   ", for: .openAI)
        #expect(try store.secret(for: .openAI) == nil)
        try store.setSecret("k", for: .openAI)
        try store.setSecret(nil, for: .openAI)
        #expect(try store.secret(for: .openAI) == nil)
    }

    /// A failed write leaves the old key in place; a second save updates the item rather than adding one.
    @Test func savingANewKeyNeverLeavesTheOldOneGone() throws {
        let keychain = FakeKeychain()
        let store = KeychainStore(service: "test", access: keychain)
        try store.setSecret("old", for: .anthropic)
        keychain.failNextWrite = errSecIO
        #expect(throws: SecretStoreError.self) { try store.setSecret("new", for: .anthropic) }
        #expect(try store.secret(for: .anthropic) == "old")
        try store.setSecret("new", for: .anthropic)
        #expect(try store.secret(for: .anthropic) == "new")
        #expect(keychain.adds == 1)   // the second save updated in place
    }

    @Test func keychainAccountsAreNamedPerProvider() {
        #expect(KeychainStore.account(for: .anthropic) == "llm.anthropic")
        #expect(KeychainStore.account(for: .openAICompatible) == "llm.openAICompatible")
        #expect(KeychainStore.service == "com.matthewfurr.ReadingThroughScripture")
    }

    @Test func theServiceFollowsTheBundleIdentifier() {
        #expect(KeychainStore.service(forBundleIdentifier: "com.matthewfurr.ReadingThroughScripture.dev")
            == "com.matthewfurr.ReadingThroughScripture.dev")
        #expect(KeychainStore.service(forBundleIdentifier: nil) == "com.matthewfurr.ReadingThroughScripture")
        #expect(KeychainStore.service(forBundleIdentifier: "") == "com.matthewfurr.ReadingThroughScripture")
    }

    private static let anthropicAccount = KeychainStore.account(for: .anthropic)

    @Test func aKeyFromTheOldKeychainIsStillRead() throws {
        let keychain = FakeKeychain()
        keychain.seedFileBased("sk-old", account: Self.anthropicAccount)
        let store = KeychainStore(service: "test", access: keychain)
        #expect(try store.secret(for: .anthropic) == "sk-old")
    }

    @Test func upgradingMovesTheKeyAndDeletesTheOldItem() throws {
        let keychain = FakeKeychain()
        keychain.seedFileBased("sk-old", account: Self.anthropicAccount)
        let store = KeychainStore(service: "test", access: keychain)
        #expect(store.upgradeToSynchronizable([.anthropic, .openAI, .openAICompatible]) == [.anthropic])
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: true) == "sk-old")
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: false) == nil)
        #expect(store.upgradeToSynchronizable([.anthropic, .openAI, .openAICompatible]) == [])
    }

    @Test func withoutTheEntitlementNothingMovesAndTheKeyStillReads() throws {
        let keychain = FakeKeychain()
        keychain.seedFileBased("sk-old", account: Self.anthropicAccount)
        keychain.dataProtectionAvailable = false
        let store = KeychainStore(service: "test", access: keychain)
        #expect(store.upgradeToSynchronizable([.anthropic]) == [])
        #expect(try store.secret(for: .anthropic) == "sk-old")
    }

    @Test func aFailedCopyLeavesTheOldItem() throws {
        let keychain = FakeKeychain()
        keychain.seedFileBased("sk-old", account: Self.anthropicAccount)
        keychain.failNextWrite = errSecIO
        let store = KeychainStore(service: "test", access: keychain)
        #expect(store.upgradeToSynchronizable([.anthropic]) == [])
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: false) == "sk-old")
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: true) == nil)
    }

    @Test func aNewKeyGoesToTheSyncedKeychain() throws {
        let keychain = FakeKeychain()
        let store = KeychainStore(service: "test", access: keychain)
        try store.setSecret("sk-new", for: .anthropic)
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: true) == "sk-new")
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: false) == nil)
    }

    @Test func removingAKeyRemovesItFromBoth() throws {
        let keychain = FakeKeychain()
        let store = KeychainStore(service: "test", access: keychain)
        try store.setSecret("sk-new", for: .anthropic)
        keychain.seedFileBased("sk-old", account: Self.anthropicAccount)
        try store.setSecret(nil, for: .anthropic)
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: true) == nil)
        #expect(keychain.stored(account: Self.anthropicAccount, dataProtection: false) == nil)
        #expect(try store.secret(for: .anthropic) == nil)
    }
}
