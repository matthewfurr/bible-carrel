import Foundation
@testable import ScriptureLLM

/// A provider that streams canned deltas, optionally failing afterwards, and records every request.
final class FakeProvider: LLMProvider, @unchecked Sendable {
    let id: LLMProviderID
    let modelName: String
    let maxContextTokens: Int?
    let availability: LLMAvailability
    var deltas: [String]
    var failure: LLMProviderError?
    var hostName: String?
    var delayPerDelta: Duration = .zero
    private(set) var requests: [LLMRequest] = []
    private let lock = NSLock()

    init(id: LLMProviderID, modelName: String, maxContextTokens: Int? = nil, availability: LLMAvailability = .available, deltas: [String] = [], failure: LLMProviderError? = nil) {
        self.id = id
        self.modelName = modelName
        self.maxContextTokens = maxContextTokens
        self.availability = availability
        self.deltas = deltas
        self.failure = failure
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, any Error> {
        lock.withLock { requests.append(request) }
        let deltas = self.deltas, failure = self.failure, delay = self.delayPerDelta
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for delta in deltas {
                        if delay > .zero { try await Task.sleep(for: delay) }
                        try Task.checkCancellation()
                        continuation.yield(.textDelta(delta))
                    }
                    if let failure { throw failure }
                    continuation.yield(.done(nil))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
