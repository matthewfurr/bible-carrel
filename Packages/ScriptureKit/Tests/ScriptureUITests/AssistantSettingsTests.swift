import Foundation
import ScriptureLLM
import Testing
@testable import ScriptureUI

/// A store that fails the next write after `failNextWrite()`; it counts the writes.
private final class FlakySecretStore: SecretStore, @unchecked Sendable {
    private let inner = InMemorySecretStore()
    private let lock = NSLock()
    private var failNext = false
    private var count = 0

    var writes: Int { lock.withLock { count } }

    func failNextWrite() { lock.withLock { failNext = true; count = 0 } }

    func secret(for id: LLMProviderID) throws -> String? { try inner.secret(for: id) }

    func setSecret(_ value: String?, for id: LLMProviderID) throws {
        let fail = lock.withLock {
            count += 1
            let fail = failNext
            failNext = false
            return fail
        }
        if fail { throw CocoaError(.fileWriteUnknown) }
        try inner.setSecret(value, for: id)
    }
}

@Suite struct AssistantSettingsTests {
    private func defaults() -> UserDefaults {
        let n = "AssistantSettingsTests-\(UUID())"
        let d = UserDefaults(suiteName: n)!
        d.removePersistentDomain(forName: n)
        return d
    }

    @Test func providersFollowTheKeysInRouterOrder() throws {
        let d = defaults(); let secrets = InMemorySecretStore()
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).map(\.id) == [.appleOnDevice])
        try secrets.setSecret("o", for: .openAI); try secrets.setSecret("a", for: .anthropic)
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).map(\.id) == [.appleOnDevice, .anthropic, .openAI])
        d.set("http://localhost:11434/v1", forKey: AssistantSettings.compatibleBaseURLKey); d.set("llama3", forKey: AssistantSettings.compatibleModelKey)
        try secrets.setSecret("c", for: .openAICompatible)
        let providers = AssistantSettings.providers(defaults: d, secrets: secrets)
        #expect(providers.map(\.id) == [.appleOnDevice, .anthropic, .openAI, .openAICompatible] && providers[3].modelName == "llama3")
        #expect(providers[1].modelName == "claude-opus-5-5" && providers[2].modelName == "gpt-5")
    }

    @Test func aCompatibleEndpointNeedsAValidURL() throws {
        let d = defaults(); let secrets = InMemorySecretStore()
        try secrets.setSecret("c", for: .openAICompatible)
        d.set("not a url", forKey: AssistantSettings.compatibleBaseURLKey)
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).map(\.id) == [.appleOnDevice])
        #expect(AssistantSettings.compatibleBaseURL("https://example.com/v1/") == URL(string: "https://example.com/v1/"))
        #expect(AssistantSettings.compatibleBaseURL("ftp://x") == nil)
    }

    @Test func preferenceDefaultsToAutoAndIgnoresGarbage() {
        let d = defaults()
        #expect(AssistantSettings.preference(from: d) == .auto)
        d.set("anthropic", forKey: AssistantSettings.providerKey)
        #expect(AssistantSettings.preference(from: d) == .anthropic)
        d.set("zzz", forKey: AssistantSettings.providerKey)
        #expect(AssistantSettings.preference(from: d) == .auto)
    }

    @MainActor @Test func savingAKeyWritesTheSecretStore() throws {
        let secrets = InMemorySecretStore()
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        model.anthropicKey = " sk-1 "
        model.saveKey(.anthropic)
        #expect(try secrets.secret(for: .anthropic) == "sk-1" && model.hasAnthropicKey)
        model.anthropicKey = ""
        model.saveKey(.anthropic)
        #expect(try secrets.secret(for: .anthropic) == nil && !model.hasAnthropicKey)
    }

    /// After the Keychain moves keys, the fields read again; one the reader is editing is kept.
    @MainActor @Test func reloadingKeysReadsTheStoreAndKeepsAnEditedField() throws {
        let secrets = InMemorySecretStore()
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        model.openAIKey = "typed"
        try secrets.setSecret("sk-a", for: .anthropic)
        try secrets.setSecret("sk-o", for: .openAI)
        model.reloadKeys()
        #expect(model.anthropicKey == "sk-a" && model.hasAnthropicKey)
        #expect(model.openAIKey == "typed" && !model.hasOpenAIKey)
    }

    /// Settings marks a cloud choice that has no key, so it is not chosen blind.
    @MainActor @Test func removingAKeyAndKnowingWhichChoicesCanAnswer() throws {
        let secrets = InMemorySecretStore()
        try secrets.setSecret("a", for: .anthropic)
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        #expect(model.hasKey(for: .anthropic) && !model.hasKey(for: .openAI) && model.hasKey(for: .auto) && model.hasKey(for: .appleOnDevice))
        model.removeKey(.anthropic)
        #expect(try secrets.secret(for: .anthropic) == nil && !model.hasAnthropicKey && model.anthropicKey.isEmpty && !model.hasKey(for: .anthropic))
    }

    @MainActor @Test func choicesAndModelNamesWriteTheirKeys() throws {
        let d = defaults(); let secrets = InMemorySecretStore()
        try secrets.setSecret("a", for: .anthropic)
        let model = AssistantSettingsModel(secrets: secrets, defaults: d)
        #expect(model.preference == .auto && model.hasAnthropicKey && model.anthropicModel == "claude-opus-5-5")
        model.preference = .anthropic
        model.anthropicModel = "claude-sonnet-5-5"
        #expect(AssistantSettings.preference(from: d) == .anthropic)
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).last?.modelName == "claude-sonnet-5-5")
        model.anthropicModel = "  "
        #expect(AssistantSettings.providers(defaults: d, secrets: secrets).last?.modelName == "claude-opus-5-5")
    }

    @MainActor @Test func aPastedKeyIsSavedWithoutReturn() async throws {
        let secrets = InMemorySecretStore()
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        model.anthropicKey = "sk-pasted"
        model.keyFieldChanged(.anthropic)
        model.flushPendingSaves()
        #expect(try secrets.secret(for: .anthropic) == "sk-pasted")
        #expect(model.hasAnthropicKey)
    }

    /// Clearing the field to paste a replacement, then pausing or closing Settings, keeps the
    /// stored key; only Remove (or Return on the empty field) deletes it. The field is left as
    /// the reader made it.
    @MainActor @Test func anEmptiedFieldDoesNotDeleteTheStoredKey() async throws {
        let secrets = InMemorySecretStore()
        try secrets.setSecret("sk-old", for: .anthropic)
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        model.anthropicKey = ""
        model.keyFieldChanged(.anthropic)
        try await Task.sleep(for: AssistantSettingsModel.saveDelay * 2)
        model.flushPendingSaves()
        #expect(try secrets.secret(for: .anthropic) == "sk-old" && model.hasAnthropicKey)
        #expect(model.anthropicKey == "")
        model.anthropicKey = "  "
        model.keyFieldChanged(.anthropic)
        model.flushPendingSaves()
        #expect(try secrets.secret(for: .anthropic) == "sk-old" && model.anthropicKey == "  ")
    }

    /// A key pasted just before Quit is saved as the app terminates, inside the debounce.
    @MainActor @Test func aPendingKeyIsSavedWhenTheAppTerminates() throws {
        let secrets = InMemorySecretStore()
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        model.anthropicKey = "sk-quit"
        model.keyFieldChanged(.anthropic)
        NotificationCenter.default.post(name: AssistantSettingsModel.terminateNotification, object: nil)
        #expect(try secrets.secret(for: .anthropic) == "sk-quit" && model.hasAnthropicKey)
    }

    /// A save that fails writes the stored key back into the field; that write-back (which the
    /// view reports as a change) must not schedule a save of the old key over the reader's.
    @MainActor @Test func aFailedSaveDoesNotRescheduleItself() throws {
        let secrets = FlakySecretStore()
        try secrets.setSecret("sk-old", for: .anthropic)
        secrets.failNextWrite()
        let model = AssistantSettingsModel(secrets: secrets, defaults: defaults())
        model.anthropicKey = "sk-new"
        model.keyFieldChanged(.anthropic)
        model.flushPendingSaves()
        #expect(secrets.writes == 1 && model.lastError != nil)
        #expect(model.anthropicKey == "sk-old" && model.hasAnthropicKey)
        model.keyFieldChanged(.anthropic)  // the view's onChange for the write-back
        model.flushPendingSaves()
        #expect(secrets.writes == 1 && model.lastError != nil)
        #expect(try secrets.secret(for: .anthropic) == "sk-old")
        model.anthropicKey = "sk-new"
        model.keyFieldChanged(.anthropic)
        model.flushPendingSaves()
        #expect(secrets.writes == 2 && model.lastError == nil)
        #expect(try secrets.secret(for: .anthropic) == "sk-new")
    }
}
