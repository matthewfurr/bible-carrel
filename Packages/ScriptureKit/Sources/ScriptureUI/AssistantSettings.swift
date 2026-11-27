import Foundation
import Observation
import OSLog
import ScriptureLLM
#if canImport(AppKit)
import AppKit
#endif

/// The assistant's `UserDefaults` keys and the providers they configure. API keys are never here:
/// they live in the Keychain behind `SecretStore`.
public enum AssistantSettings {
    public static let providerKey = "assistantProvider"
    public static let anthropicModelKey = "anthropicModel"
    public static let openAIModelKey = "openAIModel"
    public static let compatibleBaseURLKey = "compatibleBaseURL"
    public static let compatibleModelKey = "compatibleModel"

    /// Settings › Assistant › "Answer with"; `auto` when missing or unknown.
    public static func preference(from defaults: UserDefaults) -> RoutingPreference {
        defaults.string(forKey: providerKey).flatMap(RoutingPreference.init(rawValue:)) ?? .auto
    }

    /// The configured providers in router order: on-device first (always; its availability says
    /// whether it can answer), then each cloud provider whose key is present.
    public static func providers(defaults: UserDefaults, secrets: any SecretStore) -> [any LLMProvider] {
        var providers: [any LLMProvider] = [AppleFoundationProvider()]
        if let key = secret(.anthropic, in: secrets) {
            providers.append(AnthropicProvider(apiKey: key, modelName: model(anthropicModelKey, in: defaults) ?? AnthropicProvider.defaultModel))
        }
        if let key = secret(.openAI, in: secrets) {
            providers.append(OpenAICompatibleProvider(
                baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: key,
                modelName: model(openAIModelKey, in: defaults) ?? OpenAICompatibleProvider.defaultOpenAIModel))
        }
        if let key = secret(.openAICompatible, in: secrets),
           let url = compatibleBaseURL(defaults.string(forKey: compatibleBaseURLKey) ?? ""),
           let name = model(compatibleModelKey, in: defaults) {
            providers.append(OpenAICompatibleProvider(baseURL: url, apiKey: key, modelName: name))
        }
        return providers
    }

    /// A compatible base URL is used only when it parses with an http or https scheme and a host.
    static func compatibleBaseURL(_ string: String) -> URL? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return url
    }

    private static func model(_ key: String, in defaults: UserDefaults) -> String? {
        let name = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    private static func secret(_ id: LLMProviderID, in secrets: any SecretStore) -> String? {
        do {
            return try secrets.secret(for: id)
        } catch {
            Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "assistant").error("Reading the \(id.rawValue) key failed: \(error)")
            return nil
        }
    }
}

/// Settings › Assistant: who answers, the keys (written through `SecretStore`, never to
/// `UserDefaults`), the model names and the custom endpoint.
@MainActor @Observable
public final class AssistantSettingsModel {
    public var preference: RoutingPreference {
        didSet { defaults.set(preference.rawValue, forKey: AssistantSettings.providerKey) }
    }
    /// The fields' text; `saveKey(_:)` writes it, and `keyFieldChanged(_:)` schedules that.
    public var anthropicKey: String
    public var openAIKey: String
    public var compatibleKey: String
    public var anthropicModel: String {
        didSet { defaults.set(anthropicModel, forKey: AssistantSettings.anthropicModelKey) }
    }
    public var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: AssistantSettings.openAIModelKey) }
    }
    public var compatibleBaseURL: String {
        didSet { defaults.set(compatibleBaseURL, forKey: AssistantSettings.compatibleBaseURLKey) }
    }
    public var compatibleModel: String {
        didSet { defaults.set(compatibleModel, forKey: AssistantSettings.compatibleModelKey) }
    }
    public private(set) var hasAnthropicKey = false
    public private(set) var hasOpenAIKey = false
    public private(set) var hasCompatibleKey = false
    /// A plain sentence when a key could not be saved; the detail goes to the log.
    public private(set) var lastError: String?

    private let secrets: any SecretStore
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "assistant")
    /// One scheduled save per key field, replaced on every change.
    @ObservationIgnored private var pendingSaves: [LLMProviderID: Task<Void, Never>] = [:]
    /// What each field last held from the store (at launch, or `saveKey`'s write-back). A change
    /// to that value is the write-back itself, not the reader typing, so it schedules nothing:
    /// after a failed save it would put the old key back over the new one, and an empty
    /// read-back would delete the key.
    @ObservationIgnored private var fromStore: [LLMProviderID: String] = [:]
    @ObservationIgnored private var terminateObserver: (any NSObjectProtocol)?
    static let saveDelay: Duration = .milliseconds(400)

    /// Posted as the app quits: a key pasted inside `saveDelay` is saved then, not lost.
    static var terminateNotification: Notification.Name {
        #if canImport(AppKit)
        NSApplication.willTerminateNotification
        #else
        Notification.Name("AssistantSettingsModel.willTerminate")
        #endif
    }

    public init(secrets: any SecretStore, defaults: UserDefaults = .standard) {
        self.secrets = secrets
        self.defaults = defaults
        preference = AssistantSettings.preference(from: defaults)
        anthropicModel = defaults.string(forKey: AssistantSettings.anthropicModelKey) ?? AnthropicProvider.defaultModel
        openAIModel = defaults.string(forKey: AssistantSettings.openAIModelKey) ?? OpenAICompatibleProvider.defaultOpenAIModel
        compatibleBaseURL = defaults.string(forKey: AssistantSettings.compatibleBaseURLKey) ?? ""
        compatibleModel = defaults.string(forKey: AssistantSettings.compatibleModelKey) ?? ""
        anthropicKey = (try? secrets.secret(for: .anthropic)) ?? ""
        openAIKey = (try? secrets.secret(for: .openAI)) ?? ""
        compatibleKey = (try? secrets.secret(for: .openAICompatible)) ?? ""
        hasAnthropicKey = !anthropicKey.isEmpty
        hasOpenAIKey = !openAIKey.isEmpty
        hasCompatibleKey = !compatibleKey.isEmpty
        fromStore = [.anthropic: anthropicKey, .openAI: openAIKey, .openAICompatible: compatibleKey]
        // Delivered on the posting (main) thread, before the app exits.
        terminateObserver = NotificationCenter.default.addObserver(forName: Self.terminateNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushPendingSaves() }
        }
    }

    isolated deinit {
        if let terminateObserver { NotificationCenter.default.removeObserver(terminateObserver) }
    }

    private func field(_ id: LLMProviderID) -> String? {
        switch id {
        case .anthropic: anthropicKey
        case .openAI: openAIKey
        case .openAICompatible: compatibleKey
        case .appleOnDevice: nil
        }
    }

    /// A key field changed: save it once typing or pasting has paused for `saveDelay`. A field
    /// that holds what the store holds (`saveKey`'s own write-back) has nothing to save, and an
    /// emptied one is never saved here: the reader is clearing it to paste a replacement, and
    /// only Remove (or Return) deletes a key.
    public func keyFieldChanged(_ id: LLMProviderID) {
        guard let value = field(id) else { return }
        pendingSaves[id]?.cancel()
        guard value != fromStore[id], !Self.isEmpty(value) else {
            pendingSaves[id] = nil
            return
        }
        pendingSaves[id] = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveKey(id)
        }
    }

    /// Saves every scheduled key now (Settings is closing, or the app is quitting). A field left
    /// empty is dropped, not saved: that would delete the stored key.
    public func flushPendingSaves() {
        for id in Array(pendingSaves.keys) {
            if let value = field(id), !Self.isEmpty(value) {
                saveKey(id)
            } else {
                pendingSaves.removeValue(forKey: id)?.cancel()
            }
        }
    }

    private static func isEmpty(_ key: String) -> Bool {
        key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Writes the field's key (trimmed; empty removes it) and clears any earlier error. Any save
    /// still scheduled for the field is dropped: this one covers it.
    public func saveKey(_ id: LLMProviderID) {
        pendingSaves.removeValue(forKey: id)?.cancel()
        guard let value = field(id) else { return }
        do {
            try secrets.setSecret(value, for: id)
            lastError = nil
        } catch {
            lastError = "The key could not be saved in your Keychain. Try again."
            logger.error("Saving the \(id.rawValue) key failed: \(error)")
        }
        let stored = (try? secrets.secret(for: id)) ?? ""
        fromStore[id] = stored
        switch id {
        case .anthropic: anthropicKey = stored; hasAnthropicKey = !stored.isEmpty
        case .openAI: openAIKey = stored; hasOpenAIKey = !stored.isEmpty
        case .openAICompatible: compatibleKey = stored; hasCompatibleKey = !stored.isEmpty
        case .appleOnDevice: break
        }
    }

    /// Reads the keys from the store again (the Keychain moved them). A field the reader has
    /// changed, or one with a save scheduled, is left as it is.
    public func reloadKeys() {
        for id in [LLMProviderID.anthropic, .openAI, .openAICompatible]
        where pendingSaves[id] == nil && field(id) == fromStore[id] {
            let stored = (try? secrets.secret(for: id)) ?? ""
            fromStore[id] = stored
            switch id {
            case .anthropic: anthropicKey = stored; hasAnthropicKey = !stored.isEmpty
            case .openAI: openAIKey = stored; hasOpenAIKey = !stored.isEmpty
            case .openAICompatible: compatibleKey = stored; hasCompatibleKey = !stored.isEmpty
            case .appleOnDevice: break
            }
        }
    }

    /// Deletes the provider's key from the Keychain and clears its field.
    public func removeKey(_ id: LLMProviderID) {
        switch id {
        case .anthropic: anthropicKey = ""
        case .openAI: openAIKey = ""
        case .openAICompatible: compatibleKey = ""
        case .appleOnDevice: return
        }
        saveKey(id)
    }

    /// Whether the choice can answer as far as keys go: Automatic and On-device need none.
    public func hasKey(for preference: RoutingPreference) -> Bool {
        switch preference {
        case .auto, .appleOnDevice: true
        case .anthropic: hasAnthropicKey
        case .openAI: hasOpenAIKey
        case .openAICompatible: hasCompatibleKey
        }
    }

    /// "Available", or why the on-device model cannot answer.
    public var onDeviceStatus: String {
        switch AppleFoundationProvider().availability {
        case .available: "Available"
        case .unavailable(let reason): reason
        }
    }
}
