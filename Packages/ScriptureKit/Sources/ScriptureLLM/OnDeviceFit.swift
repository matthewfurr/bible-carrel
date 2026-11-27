/// The on-device model's window is about 4,096 tokens shared by prompt and reply (the spec), so
/// routing sends it only what leaves room to answer, and the history it sees is trimmed first.
public enum OnDeviceFit {
    public static let contextWindow = 4096
    /// Instructions plus prompt, estimated by `TokenEstimator`.
    public static let promptLimit = 3000
    public static let replyBudget = 1000

    public static func fits(_ request: LLMRequest) -> Bool {
        request.estimatedTokens <= promptLimit
    }

    /// Drops the oldest exchanges (a reader turn and the assistant turn after it) until the
    /// request fits, never dropping the last message; `maxExchanges` first caps how many
    /// exchanges of history are kept before the last message. With `keepingFirst`, the first
    /// message (the one that carries the passage) stays and the exchanges after it go, unless
    /// it and the last message cannot fit together.
    public static func trim(_ request: LLMRequest, maxExchanges: Int? = nil, keepingFirst: Bool = false) -> LLMRequest {
        if keepingFirst, request.messages.count > 2, let first = request.messages.first {
            let rest = LLMRequest(instructions: request.instructions + "\n\n" + first.content, messages: Array(request.messages.dropFirst()), maxTokens: request.maxTokens)
            let kept = LLMRequest(instructions: request.instructions, messages: [first] + trim(rest, maxExchanges: maxExchanges).messages, maxTokens: request.maxTokens)
            if fits(kept) { return kept }
        }
        var messages = request.messages
        func dropOldestExchange() -> Bool {
            guard messages.count > 1 else { return false }
            messages.removeFirst()
            if messages.count > 1, messages[0].role == .assistant { messages.removeFirst() }
            return true
        }
        if let maxExchanges {
            while exchangeCount(messages) > maxExchanges, dropOldestExchange() {}
        }
        while !fits(LLMRequest(instructions: request.instructions, messages: messages, maxTokens: request.maxTokens)), dropOldestExchange() {}
        return LLMRequest(instructions: request.instructions, messages: messages, maxTokens: request.maxTokens)
    }

    /// Reader turns before the last message.
    private static func exchangeCount(_ messages: [LLMMessage]) -> Int {
        messages.dropLast().filter { $0.role == .user }.count
    }

    /// The history flattened into one prompt for a fresh session: labelled turns, then the new
    /// question. A lone message is sent as it is.
    public static func flattenedPrompt(_ messages: [LLMMessage]) -> String {
        guard messages.count > 1 else { return messages.first?.content ?? "" }
        return messages.map { ($0.role == .user ? "Reader: " : "Assistant: ") + $0.content }.joined(separator: "\n\n")
    }
}
