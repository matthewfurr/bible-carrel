import Testing
@testable import ScriptureLLM

@Suite struct OnDeviceFitTests {
    private func request(_ sizes: [Int], instructions: Int = 100) -> LLMRequest {
        LLMRequest(instructions: String(repeating: "i", count: instructions), messages: sizes.enumerated().map {
            LLMMessage(role: $0.offset.isMultiple(of: 2) ? .user : .assistant, content: String(repeating: "x", count: $0.element))
        }, maxTokens: OnDeviceFit.replyBudget)
    }

    @Test func fitIsJudgedAgainstThePromptLimit() {
        #expect(OnDeviceFit.fits(request([11_900])))
        #expect(!OnDeviceFit.fits(request([11_904])))
    }

    @Test func trimDropsOldestExchangesFirstAndKeepsTheLastMessage() {
        let trimmed = OnDeviceFit.trim(request([4000, 4000, 4000, 4000, 2000]))
        #expect(trimmed.messages.map(\.content.count) == [4000, 4000, 2000])
        let tooBig = OnDeviceFit.trim(request([20_000]))
        #expect(tooBig.messages.count == 1 && !OnDeviceFit.fits(tooBig))
    }

    /// A chapter thread's first message carries the passage; trimming keeps it and drops the
    /// oldest exchanges after it, unless even it and the last message cannot fit together.
    @Test func trimCanKeepTheFirstMessage() {
        let kept = OnDeviceFit.trim(request([4000, 4000, 2000, 4000, 2000]), keepingFirst: true)
        #expect(kept.messages.map(\.content.count) == [4000, 2000] && OnDeviceFit.fits(kept))
        #expect(OnDeviceFit.trim(request([4000, 4000, 2000, 4000, 2000])).messages.map(\.content.count) == [2000, 4000, 2000])
        let tooBig = OnDeviceFit.trim(request([10_000, 10, 4000]), keepingFirst: true)
        #expect(tooBig.messages.map(\.content.count) == [4000])
    }

    @Test func maxExchangesCapsTheHistory() {
        let trimmed = OnDeviceFit.trim(request([10, 10, 10, 10, 10, 10, 10]), maxExchanges: 1)
        #expect(trimmed.messages.map(\.content.count) == [10, 10, 10])
    }

    @Test func flattenedPromptLabelsTurns() {
        let messages = [LLMMessage(role: .user, content: "Who?"), LLMMessage(role: .assistant, content: "Matthew."), LLMMessage(role: .user, content: "When?")]
        #expect(OnDeviceFit.flattenedPrompt(messages) == "Reader: Who?\n\nAssistant: Matthew.\n\nReader: When?")
        #expect(OnDeviceFit.flattenedPrompt([messages[2]]) == "When?")
    }

    @Test func providerDescribesItself() {
        let provider = AppleFoundationProvider()
        #expect(provider.id == .appleOnDevice && provider.maxContextTokens == 4096)
        if case .unavailable(let reason) = provider.availability { #expect(!reason.isEmpty) }
    }
}
