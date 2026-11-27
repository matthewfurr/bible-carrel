import Foundation

/// OpenAI's Chat Completions API, and any endpoint that speaks it (Ollama, LM Studio, a proxy),
/// over `URLSession` with streaming. The system prompt is the first message.
public struct OpenAICompatibleProvider: LLMProvider {
    public static let openAIBaseURL = URL(string: "https://api.openai.com/v1")!
    public static let defaultOpenAIModel = "gpt-5"

    public let id: LLMProviderID
    public let modelName: String
    public let maxContextTokens: Int? = nil
    public let availability: LLMAvailability = .available
    public let baseURL: URL

    private let apiKey: String
    private let session: URLSession

    /// `id` is `.openAI` for OpenAI's own base URL, `.openAICompatible` otherwise.
    public init(baseURL: URL, apiKey: String, modelName: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelName = modelName
        self.session = session
        let trimmed = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        self.id = trimmed == Self.openAIBaseURL.absoluteString ? .openAI : .openAICompatible
    }

    public var hostName: String? { baseURL.host() }

    var endpoint: URL {
        var string = baseURL.absoluteString
        if string.hasSuffix("/") { string.removeLast() }
        return URL(string: string + "/chat/completions") ?? baseURL
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, any Error> {
        var messages: [[String: String]] = [["role": "system", "content": request.instructions]]
        messages += request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = [
            "model": modelName,
            "stream": true,
            "stream_options": ["include_usage": true],
            "messages": messages,
        ]
        let urlRequest: URLRequest
        do {
            urlRequest = try HTTPStreaming.jsonRequest(url: endpoint, headers: ["Authorization": "Bearer \(apiKey)"], body: body)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: LLMProviderError.transport(error.localizedDescription)) }
        }
        let usage = HTTPStreaming.Usage()
        return HTTPStreaming.stream(request: urlRequest, session: session) { event in
            if event.data.trimmingCharacters(in: .whitespaces) == "[DONE]" { return .finished([]) }
            guard let object = HTTPStreaming.json(event.data) else { return .events([]) }
            if let error = object["error"] as? [String: Any] {
                throw LLMProviderError.server(status: 0, message: error["message"] as? String ?? "The request failed.")
            }
            if let counts = object["usage"] as? [String: Any] {
                usage.input = counts["prompt_tokens"] as? Int
                usage.output = counts["completion_tokens"] as? Int
            }
            guard let choice = (object["choices"] as? [[String: Any]])?.first else { return .events([]) }
            var events: [LLMEvent] = []
            if let text = (choice["delta"] as? [String: Any])?["content"] as? String, !text.isEmpty {
                events.append(.textDelta(text))
            }
            // A finish reason can arrive with the last words; they are yielded before it is acted on.
            // A stop keeps reading: the usage chunk and `[DONE]` follow it, and a server that
            // closes without them still gave a complete reply.
            switch choice["finish_reason"] as? String {
            case "stop": return .completeOnEnd(events)
            case "length": return .failed(events, .cutShort)
            case "content_filter": return .failed(events, .declined(""))
            default: return .events(events)
            }
        }
        .withDone { usage.reported }
    }
}
