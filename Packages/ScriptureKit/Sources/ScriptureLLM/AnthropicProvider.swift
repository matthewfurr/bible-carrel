import Foundation

/// Anthropic's Messages API over `URLSession`, streaming (the spec: no SDK). Text arrives in
/// `content_block_delta` events; `message_delta` carries the stop reason, and a `refusal` is
/// reported as a decline. No sampling parameters are sent (this API version rejects them).
public struct AnthropicProvider: LLMProvider {
    public static let defaultModel = "claude-opus-5-5"
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let apiVersion = "2026-10-21"

    public let id: LLMProviderID = .anthropic
    public let modelName: String
    public let maxContextTokens: Int? = nil
    public let availability: LLMAvailability = .available

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, modelName: String = defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.modelName = modelName.isEmpty ? Self.defaultModel : modelName
        self.session = session
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, any Error> {
        let body: [String: Any] = [
            "model": modelName,
            "max_tokens": request.maxTokens,
            "stream": true,
            "system": request.instructions,
            "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.content] },
        ]
        let urlRequest: URLRequest
        do {
            urlRequest = try HTTPStreaming.jsonRequest(
                url: Self.endpoint,
                headers: ["x-api-key": apiKey, "anthropic-version": Self.apiVersion],
                body: body)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: LLMProviderError.transport(error.localizedDescription)) }
        }
        let usage = HTTPStreaming.Usage()
        return HTTPStreaming.stream(request: urlRequest, session: session) { event in
            guard let object = HTTPStreaming.json(event.data) else { return .events([]) }
            switch event.name ?? object["type"] as? String {
            case "message_start":
                let message = object["message"] as? [String: Any]
                usage.input = (message?["usage"] as? [String: Any])?["input_tokens"] as? Int
                return .events([])
            case "content_block_delta":
                let delta = object["delta"] as? [String: Any]
                if delta?["type"] as? String == "text_delta", let text = delta?["text"] as? String, !text.isEmpty {
                    return .events([.textDelta(text)])
                }
                return .events([])
            case "message_delta":
                if let output = (object["usage"] as? [String: Any])?["output_tokens"] as? Int { usage.output = output }
                let delta = object["delta"] as? [String: Any]
                switch delta?["stop_reason"] as? String {
                case "refusal": return .failed([], .declined(""))
                case "max_tokens": return .failed([], .cutShort)
                default: return .events([])
                }
            case "message_stop":
                return .finished([])
            case "error":
                let error = object["error"] as? [String: Any]
                throw LLMProviderError.server(status: 0, message: error?["message"] as? String ?? "The request failed.")
            default:
                return .events([])
            }
        }
        .withDone { usage.reported }
    }
}

extension AsyncThrowingStream where Element == LLMEvent, Failure == any Error {
    /// Appends `.done(usage())` after the wrapped stream finishes cleanly.
    func withDone(_ usage: @escaping @Sendable () -> LLMUsage?) -> AsyncThrowingStream<LLMEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in self { continuation.yield(event) }
                    continuation.yield(.done(usage()))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
