import Foundation

/// What the two cloud providers share: send the request, check the status, feed the body
/// through `SSEParser`, and turn transport trouble into `LLMProviderError.transport`.
enum HTTPStreaming {
    static let truncatedMessage = "The stream ended before the reply was complete."

    /// What one SSE event means to the reply. Every case carries the text it brought, so an
    /// event that both ends the reply and carries its last words loses none of them.
    enum Step {
        /// More of the reply; keep reading.
        case events([LLMEvent])
        /// The reply's text is complete, but trailing events (usage) may follow: yield these and
        /// keep reading. The body ending after this is a complete reply, not a truncated one.
        case completeOnEnd([LLMEvent])
        /// The reply is complete: yield these, then finish (the body is no longer read).
        case finished([LLMEvent])
        /// The reply stops here: yield these, then fail with the error.
        case failed([LLMEvent], LLMProviderError)
    }

    /// Yields the step's events; returns true once the stream is finished, throws when it failed.
    /// A `.completeOnEnd` sets `completeOnEnd` and keeps reading.
    private static func apply(
        _ step: Step,
        to continuation: AsyncThrowingStream<LLMEvent, any Error>.Continuation,
        completeOnEnd: inout Bool
    ) throws -> Bool {
        switch step {
        case .events(let events):
            for event in events { continuation.yield(event) }
            return false
        case .completeOnEnd(let events):
            for event in events { continuation.yield(event) }
            completeOnEnd = true
            return false
        case .finished(let events):
            for event in events { continuation.yield(event) }
            return true
        case .failed(let events, let error):
            for event in events { continuation.yield(event) }
            throw error
        }
    }

    /// `parse` maps one SSE event to a `Step`. A body that ends before any `.finished` or
    /// `.completeOnEnd` is a truncated reply and fails with `transport(truncatedMessage)`.
    static func stream(
        request: URLRequest,
        session: URLSession,
        parse: @escaping @Sendable (SSEEvent) throws -> Step
    ) -> AsyncThrowingStream<LLMEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        throw error(status: status, body: body)
                    }
                    var parser = SSEParser()
                    var buffer: [UInt8] = []
                    var sawFinish = false
                    var completeOnEnd = false
                    for try await byte in bytes {
                        buffer.append(byte)
                        if byte == UInt8(ascii: "\n") || buffer.count >= 512 {
                            for event in parser.feed(buffer) {
                                sawFinish = try apply(parse(event), to: continuation, completeOnEnd: &completeOnEnd)
                                if sawFinish { break }
                            }
                            buffer.removeAll(keepingCapacity: true)
                            if sawFinish { break }
                        }
                        try Task.checkCancellation()
                    }
                    if !sawFinish {
                        for event in parser.feed(buffer) + parser.finish() {
                            sawFinish = try apply(parse(event), to: continuation, completeOnEnd: &completeOnEnd)
                            if sawFinish { break }
                        }
                    }
                    guard sawFinish || completeOnEnd else { throw LLMProviderError.transport(truncatedMessage) }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch let error as LLMProviderError {
                    continuation.finish(throwing: error)
                } catch let error as URLError {
                    continuation.finish(throwing: LLMProviderError.transport(error.localizedDescription))
                } catch {
                    continuation.finish(throwing: LLMProviderError.transport(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func error(status: Int, body: Data) -> LLMProviderError {
        switch status {
        case 401, 403: return .unauthorized
        case 429: return .rateLimited
        default:
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            let message = (object?["error"] as? [String: Any])?["message"] as? String
                ?? (object?["error"] as? String)
                ?? String(decoding: body.prefix(200), as: UTF8.self)
            return .server(status: status, message: message)
        }
    }

    static func jsonRequest(url: URL, headers: [String: String], body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("text/event-stream", forHTTPHeaderField: "accept")
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120
        return request
    }

    static func json(_ data: String) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any]
    }

    /// The token counts a stream reports as it goes, read once by `withDone`. A stream that
    /// reported neither count has no usage (`nil`), not a usage of nothing.
    final class Usage: @unchecked Sendable {
        var input: Int?
        var output: Int?

        var reported: LLMUsage? {
            input == nil && output == nil ? nil : LLMUsage(inputTokens: input, outputTokens: output)
        }
    }
}
