import Foundation
import Testing
@testable import ScriptureLLM

/// Nested under `CloudProviderTests` so the shared `StubURLProtocol` statics are never used by two tests at once.
extension CloudProviderTests {
@Suite struct OpenAICompatibleProviderTests {
    private func collect(_ provider: some LLMProvider, _ request: LLMRequest) async throws -> [LLMEvent] {
        var events: [LLMEvent] = []
        for try await event in provider.stream(request) { events.append(event) }
        return events
    }

    private let request = LLMRequest(instructions: "Be brief.", messages: [LLMMessage(role: .user, content: "Who wrote Matthew?")], maxTokens: 256)

    private func ok(_ chunks: [String]) {
        StubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"])!, chunks.map { Data($0.utf8) })
        }
    }

    @Test func sendsTheChatCompletionsRequestAndStreamsTextDeltas() async throws {
        ok([
            "data: {\"choices\":[{\"delta\":{\"content\":\"Tra\"}}]}\n\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\"dition\"}}]}\n\n",
            "data: {\"choices\":[],\"usage\":{\"prompt_tokens\":9,\"completion_tokens\":2}}\n\ndata: [DONE]\n\n",
        ])
        let provider = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
        let events = try await collect(provider, request)
        #expect(events == [.textDelta("Tra"), .textDelta("dition"), .done(LLMUsage(inputTokens: 9, outputTokens: 2))])
        let sent = try #require(StubURLProtocol.recordedRequest)
        #expect(sent.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer k")
        let bodyData = try #require(StubURLProtocol.recordedBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["model"] as? String == "gpt-5" && body["stream"] as? Bool == true)
        let messages = body["messages"] as? [[String: String]]
        #expect(messages?.first == ["role": "system", "content": "Be brief."])
        #expect(messages?.last == ["role": "user", "content": "Who wrote Matthew?"])
    }

    @Test func lengthFinishReasonIsCutShort() async throws {
        ok(["data: {\"choices\":[{\"delta\":{\"content\":\"Half\"},\"finish_reason\":null}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"length\"}]}\n\ndata: [DONE]\n\n"])
        let provider = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
        var received: [LLMEvent] = []
        await #expect(throws: LLMProviderError.cutShort) {
            for try await event in provider.stream(request) { received.append(event) }
        }
        #expect(received == [.textDelta("Half")])
    }

    /// A server that closes after a `stop` finish without sending `[DONE]` gave a complete reply.
    @Test func aStopWithoutDoneIsComplete() async throws {
        ok(["data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"])
        let provider = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
        let events = try await collect(provider, request)
        #expect(events == [.textDelta("Hi"), .done(nil)])
    }

    /// OpenAI sends its usage chunk after the `stop` finish, so a stop does not end the reading.
    @Test func usageAfterStopIsStillReported() async throws {
        ok([
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\n",
            "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n",
            "data: {\"choices\":[],\"usage\":{\"prompt_tokens\":9,\"completion_tokens\":2}}\n\ndata: [DONE]\n\n",
        ])
        let provider = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
        let events = try await collect(provider, request)
        #expect(events == [.textDelta("Hi"), .done(LLMUsage(inputTokens: 9, outputTokens: 2))])
    }

    /// The last words arrive in the same event as the `length` finish; they are kept.
    @Test func aLengthFinishWithTextKeepsTheTextThenReportsCutShort() async throws {
        ok(["data: {\"choices\":[{\"delta\":{\"content\":\"Half\"},\"finish_reason\":\"length\"}]}\n\ndata: [DONE]\n\n"])
        let provider = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
        var received: [LLMEvent] = []
        var thrown: (any Error)?
        do { for try await event in provider.stream(request) { received.append(event) } } catch { thrown = error }
        #expect(received == [.textDelta("Half")])
        #expect(thrown as? LLMProviderError == .cutShort)
    }

    @Test func idFollowsTheBaseURL() async throws {
        let openAI = OpenAICompatibleProvider(baseURL: OpenAICompatibleProvider.openAIBaseURL, apiKey: "k", modelName: "gpt-5", session: StubURLProtocol.session())
        #expect(openAI.id == .openAI)
        let local = OpenAICompatibleProvider(baseURL: URL(string: "http://localhost:11434/v1/")!, apiKey: "k", modelName: "llama3", session: StubURLProtocol.session())
        #expect(local.id == .openAICompatible)
        ok(["data: [DONE]\n\n"])
        _ = try await collect(local, request)
        #expect(StubURLProtocol.recordedRequest?.url?.absoluteString == "http://localhost:11434/v1/chat/completions")
    }
}
}
