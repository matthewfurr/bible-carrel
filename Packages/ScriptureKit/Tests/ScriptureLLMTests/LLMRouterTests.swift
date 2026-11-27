import Testing
@testable import ScriptureLLM

@Suite struct LLMRouterTests {
    private let small = LLMRequest(instructions: "i", messages: [LLMMessage(role: .user, content: "q")], maxTokens: 100)
    private let large = LLMRequest(instructions: "i", messages: [LLMMessage(role: .user, content: String(repeating: "x", count: 20_000))], maxTokens: 100)
    private let onDevice = FakeProvider(id: .appleOnDevice, modelName: "apple", maxContextTokens: 4096)
    private let offline = FakeProvider(id: .appleOnDevice, modelName: "apple", maxContextTokens: 4096, availability: .unavailable(reason: "Apple Intelligence is not enabled on this Mac."))
    private let claude = FakeProvider(id: .anthropic, modelName: "claude-opus-5-5")
    private let openAI = FakeProvider(id: .openAI, modelName: "gpt-5")

    private func id(_ decision: RoutingDecision) -> LLMProviderID? {
        if case .provider(let provider) = decision { return provider.id }
        return nil
    }

    @Test func autoPrefersOnDeviceWhenItFits() {
        let router = LLMRouter(providers: [onDevice, claude, openAI])
        #expect(id(router.route(small, preference: .auto)) == .appleOnDevice)
        #expect(id(router.route(large, preference: .auto)) == .anthropic)
    }

    @Test func aChosenCloudProviderWins() {
        let router = LLMRouter(providers: [onDevice, claude, openAI])
        #expect(id(router.route(small, preference: .openAI)) == .openAI)
        #expect(id(router.route(small, preference: .anthropic)) == .anthropic)
    }

    @Test func aMissingChoiceFallsBackToAuto() {
        let router = LLMRouter(providers: [onDevice, openAI])
        #expect(id(router.route(small, preference: .anthropic)) == .appleOnDevice)
        #expect(id(router.route(large, preference: .appleOnDevice)) == .openAI)
    }

    @Test func tooLongWithoutACloudKeyIsReported() {
        let router = LLMRouter(providers: [onDevice])
        if case .tooLongForOnDevice = router.route(large, preference: .auto) {} else { Issue.record("expected tooLongForOnDevice") }
    }

    @Test func unavailableOnDeviceFallsToCloudOrReports() {
        #expect(id(LLMRouter(providers: [offline, claude]).route(small, preference: .auto)) == .anthropic)
        if case .onDeviceUnavailable(let reason) = LLMRouter(providers: [offline]).route(small, preference: .auto) {
            #expect(reason == "Apple Intelligence is not enabled on this Mac.")
        } else {
            Issue.record("expected onDeviceUnavailable")
        }
        if case .nothingConfigured = LLMRouter(providers: []).route(small, preference: .auto) {} else { Issue.record("expected nothingConfigured") }
    }

    @Test func fallbackIsOnDeviceWhenItFits() {
        let router = LLMRouter(providers: [onDevice, claude, openAI])
        #expect(router.offlineFallback(for: small)?.id == .appleOnDevice)
    }

    @Test func noFallbackWhenTooLongOrUnavailable() {
        #expect(LLMRouter(providers: [onDevice, claude]).offlineFallback(for: large) == nil)
        #expect(LLMRouter(providers: [offline, claude]).offlineFallback(for: small) == nil)
        #expect(LLMRouter(providers: [claude, openAI]).offlineFallback(for: small) == nil)
    }
}
