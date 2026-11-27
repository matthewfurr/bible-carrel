/// Settings › Assistant › "Answer with".
public enum RoutingPreference: String, CaseIterable, Sendable {
    case auto
    case appleOnDevice
    case anthropic
    case openAI
    case openAICompatible

    var providerID: LLMProviderID? {
        switch self {
        case .auto: nil
        case .appleOnDevice: .appleOnDevice
        case .anthropic: .anthropic
        case .openAI: .openAI
        case .openAICompatible: .openAICompatible
        }
    }
}

public enum RoutingDecision: Sendable {
    case provider(any LLMProvider)
    /// On-device is the only provider and the request does not fit its window.
    case tooLongForOnDevice
    /// No cloud provider is configured and on-device cannot answer, for this reason.
    case onDeviceUnavailable(String)
    /// No providers at all.
    case nothingConfigured
}

/// Picks who answers (the spec: on-device by default when it fits, a cloud provider when chosen or
/// when the request is too large) and says why not when nobody can, so the panel can point at
/// Settings instead of a dead end.
public struct LLMRouter: Sendable {
    private let providers: [any LLMProvider]

    /// `providers` are the configured ones: on-device when the framework exists, then each cloud
    /// provider with a key in the order Anthropic, OpenAI, compatible.
    public init(providers: [any LLMProvider]) {
        self.providers = providers
    }

    public func route(_ request: LLMRequest, preference: RoutingPreference) -> RoutingDecision {
        let onDevice = providers.first { $0.id == .appleOnDevice }
        let cloud = providers.filter { $0.id != .appleOnDevice }
        if let wanted = preference.providerID, wanted != .appleOnDevice, let chosen = cloud.first(where: { $0.id == wanted }) {
            return .provider(chosen)
        }
        if let onDevice, onDevice.availability == .available, OnDeviceFit.fits(request) {
            return .provider(onDevice)
        }
        if let first = cloud.first { return .provider(first) }
        guard let onDevice else { return .nothingConfigured }
        if case .unavailable(let reason) = onDevice.availability { return .onDeviceUnavailable(reason) }
        return .tooLongForOnDevice
    }

    /// Who answers when the cloud provider a reply went to cannot be reached: the on-device model,
    /// when it is available and the request fits its window; nil otherwise.
    public func offlineFallback(for request: LLMRequest) -> (any LLMProvider)? {
        guard let onDevice = providers.first(where: { $0.id == .appleOnDevice }),
              onDevice.availability == .available, OnDeviceFit.fits(request) else { return nil }
        return onDevice
    }
}
