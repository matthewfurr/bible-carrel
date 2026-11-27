import Foundation
import Testing
@testable import ScriptureLLM

/// Nested under `CloudProviderTests` so the shared `StubURLProtocol` statics are never used by two tests at once.
extension CloudProviderTests {
@Suite struct AnthropicProviderTests {
    private func collect(_ provider: some LLMProvider, _ request: LLMRequest) async throws -> [LLMEvent] {
        var events: [LLMEvent] = []
        for try await event in provider.stream(request) { events.append(event) }
        return events
    }

    private let request = LLMRequest(instructions: "Be brief.", messages: [LLMMessage(role: .user, content: "Who wrote Matthew?")], maxTokens: 256)

    private func ok(_ chunks: [String]) {
        StubURLProtocol.handler = { _ in
            (HTTPURLResponse(url: AnthropicProvider.endpoint, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"])!, chunks.map { Data($0.utf8) })
        }
    }

    @Test func sendsTheMessagesRequestAndStreamsTextDeltas() async throws {
        ok([
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":12}}}\n\nevent: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Tradition says \"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Matthew.\"}}\n\nevent: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":5}}\n\nevent: message_stop\ndata: {\"type\":\"message_stop\"}\n\n",
        ])
        let provider = AnthropicProvider(apiKey: "sk-test", session: StubURLProtocol.session())
        let events = try await collect(provider, request)
        #expect(events == [.textDelta("Tradition says "), .textDelta("Matthew."), .done(LLMUsage(inputTokens: 12, outputTokens: 5))])
        let sent = try #require(StubURLProtocol.recordedRequest)
        #expect(sent.url == AnthropicProvider.endpoint && sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(sent.value(forHTTPHeaderField: "anthropic-version") == "2026-10-21")
        let bodyData = try #require(StubURLProtocol.recordedBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["model"] as? String == "claude-opus-5-5" && body["stream"] as? Bool == true && body["max_tokens"] as? Int == 256)
        #expect(body["system"] as? String == "Be brief." && body["temperature"] == nil)
        #expect((body["messages"] as? [[String: String]]) == [["role": "user", "content": "Who wrote Matthew?"]])
    }

    @Test func unauthorizedAndRateLimitedAndServerErrorsAreTyped() async throws {
        let cases: [(Int, LLMProviderError)] = [(401, .unauthorized), (403, .unauthorized), (429, .rateLimited), (500, .server(status: 500, message: "Overloaded"))]
        for (status, expected) in cases {
            StubURLProtocol.handler = { _ in
                (HTTPURLResponse(url: AnthropicProvider.endpoint, statusCode: status, httpVersion: nil, headerFields: nil)!, [Data("{\"type\":\"error\",\"error\":{\"type\":\"x\",\"message\":\"Overloaded\"}}".utf8)])
            }
            let provider = AnthropicProvider(apiKey: "k", session: StubURLProtocol.session())
            await #expect(throws: expected) { try await collect(provider, request) }
        }
    }

    @Test func refusalStopReasonIsADecline() async throws {
        ok(["event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"refusal\"},\"usage\":{\"output_tokens\":0}}\n\n"])
        let provider = AnthropicProvider(apiKey: "k", session: StubURLProtocol.session())
        await #expect(throws: LLMProviderError.declined("")) { try await collect(provider, request) }
    }

    /// A reply that ran out of `max_tokens` is not passed off as complete.
    @Test func maxTokensStopReasonIsCutShort() async throws {
        ok(["event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Half\"}}\n\nevent: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"max_tokens\"},\"usage\":{\"output_tokens\":256}}\n\nevent: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"])
        let provider = AnthropicProvider(apiKey: "k", session: StubURLProtocol.session())
        var received: [LLMEvent] = []
        await #expect(throws: LLMProviderError.cutShort) {
            for try await event in provider.stream(request) { received.append(event) }
        }
        #expect(received == [.textDelta("Half")])
    }

    @Test func truncatedStreamThrowsAfterTheDeltasReceived() async throws {
        ok(["event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Half\"}}\n\n"])
        let provider = AnthropicProvider(apiKey: "k", session: StubURLProtocol.session())
        var received: [LLMEvent] = []
        var failure: (any Error)?
        do {
            for try await event in provider.stream(request) { received.append(event) }
        } catch {
            failure = error
        }
        #expect(received == [.textDelta("Half")])
        #expect(failure as? LLMProviderError == .transport("The stream ended before the reply was complete."))
    }
}
}
