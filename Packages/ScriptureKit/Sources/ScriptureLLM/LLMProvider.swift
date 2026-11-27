import Foundation

/// Which model answers: the on-device model, or one of the cloud endpoints behind a key.
public enum LLMProviderID: String, CaseIterable, Codable, Sendable {
    case appleOnDevice
    case anthropic
    case openAI
    case openAICompatible
}

public enum LLMRole: String, Codable, Sendable {
    case user
    case assistant
}

/// One turn of a conversation as a provider sees it.
public struct LLMMessage: Equatable, Sendable {
    public let role: LLMRole
    public let content: String

    public init(role: LLMRole, content: String) {
        self.role = role
        self.content = content
    }
}

/// Everything a provider needs for one reply: the system instructions, the turns so far (oldest
/// first, ending with the reader's new question) and the reply budget.
public struct LLMRequest: Equatable, Sendable {
    public let instructions: String
    public let messages: [LLMMessage]
    public let maxTokens: Int

    public init(instructions: String, messages: [LLMMessage], maxTokens: Int) {
        self.instructions = instructions
        self.messages = messages
        self.maxTokens = maxTokens
    }

    /// The estimate routing judges the on-device window by: instructions plus every turn.
    public var estimatedTokens: Int {
        TokenEstimator.estimate(instructions) + messages.reduce(0) { $0 + TokenEstimator.estimate($1.content) }
    }
}

public struct LLMUsage: Equatable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?

    public init(inputTokens: Int?, outputTokens: Int?) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public enum LLMEvent: Equatable, Sendable {
    case textDelta(String)
    case done(LLMUsage?)
}

public enum LLMAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

/// Why a provider could not answer, as the panel needs to tell it apart.
public enum LLMProviderError: Error, Equatable, Sendable {
    /// 401 or 403: the key was not accepted.
    case unauthorized
    /// 429.
    case rateLimited
    /// A refusal or a guardrail, with the provider's sentence when it gave one.
    case declined(String)
    /// The provider's own window refused the request.
    case tooLong
    case server(status: Int, message: String)
    /// A `URLError` or a stream that ended early.
    case transport(String)
    /// The on-device model cannot be used.
    case unavailable(String)
    /// The reply stopped at its token budget (`max_tokens`, `length`) after the text received.
    case cutShort
}

public protocol LLMProvider: Sendable {
    var id: LLMProviderID { get }
    var modelName: String { get }
    /// Nil for cloud providers, whose windows are not the limiting factor.
    var maxContextTokens: Int? { get }
    var availability: LLMAvailability { get }
    /// The endpoint's host for a compatible provider ("localhost", "lmstudio.local"), so a reply
    /// can name where it came from after Settings change; nil for the others.
    var hostName: String? { get }
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, any Error>
}

extension LLMProvider {
    public var hostName: String? { nil }
}
