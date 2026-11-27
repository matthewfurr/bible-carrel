import Testing
@testable import ScriptureLLM

@Suite struct TokenEstimatorTests {
    @Test func fourCharactersPerTokenRoundedUp() {
        #expect(TokenEstimator.estimate("") == 0)
        #expect(TokenEstimator.estimate("abcd") == 1)
        #expect(TokenEstimator.estimate("abcde") == 2)
        #expect(TokenEstimator.estimate(String(repeating: "a", count: 4000)) == 1000)
    }

    @Test func requestEstimateCoversInstructionsAndMessages() {
        let request = LLMRequest(instructions: String(repeating: "i", count: 40), messages: [
            LLMMessage(role: .user, content: String(repeating: "u", count: 8)),
            LLMMessage(role: .assistant, content: String(repeating: "a", count: 9)),
        ], maxTokens: 100)
        #expect(request.estimatedTokens == 10 + 2 + 3)
    }
}
