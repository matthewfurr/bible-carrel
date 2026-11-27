import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model. A fresh session per request carries the instructions; the thread's
/// earlier turns are flattened into the prompt after `OnDeviceFit.trim`. Snapshots carry the
/// whole reply so far, so the provider yields only what is new.
public struct AppleFoundationProvider: LLMProvider {
    public static let onDeviceModelName = "apple-on-device"
    static let notEligible = "This Mac cannot run the on-device model."
    static let intelligenceOff = "Apple Intelligence is not enabled on this Mac. Turn it on in System Settings."
    static let downloading = "The on-device model is still downloading. Try again in a while."
    static let missing = "The on-device model is not available on this system."

    public let id: LLMProviderID = .appleOnDevice
    public let modelName = onDeviceModelName
    public let maxContextTokens: Int? = OnDeviceFit.contextWindow

    public init() {}

    public var availability: LLMAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unavailable(reason: Self.notEligible)
            case .appleIntelligenceNotEnabled: return .unavailable(reason: Self.intelligenceOff)
            case .modelNotReady: return .unavailable(reason: Self.downloading)
            @unknown default: return .unavailable(reason: Self.missing)
            }
        }
        #else
        return .unavailable(reason: Self.missing)
        #endif
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, any Error> {
        if case .unavailable(let reason) = availability {
            return AsyncThrowingStream { $0.finish(throwing: LLMProviderError.unavailable(reason)) }
        }
        guard OnDeviceFit.fits(request) else {
            return AsyncThrowingStream { $0.finish(throwing: LLMProviderError.tooLong) }
        }
        #if canImport(FoundationModels)
        let prompt = OnDeviceFit.flattenedPrompt(request.messages)
        let instructions = request.instructions
        let budget = min(request.maxTokens, OnDeviceFit.replyBudget)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    var sent = ""
                    let stream = session.streamResponse(to: prompt, options: GenerationOptions(maximumResponseTokens: budget))
                    for try await snapshot in stream {
                        let whole = snapshot.content
                        if whole.hasPrefix(sent) {
                            let delta = String(whole.dropFirst(sent.count))
                            if !delta.isEmpty { continuation.yield(.textDelta(delta)) }
                        } else {
                            continuation.yield(.textDelta(whole))
                        }
                        sent = whole
                        try Task.checkCancellation()
                    }
                    continuation.yield(.done(nil))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: Self.map(error))
                } catch {
                    continuation.finish(throwing: LLMProviderError.server(status: 0, message: error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        return AsyncThrowingStream { $0.finish(throwing: LLMProviderError.unavailable(Self.missing)) }
        #endif
    }

    #if canImport(FoundationModels)
    static func map(_ error: LanguageModelSession.GenerationError) -> LLMProviderError {
        switch error {
        case .exceededContextWindowSize: .tooLong
        case .guardrailViolation: .declined("")
        case .refusal: .declined("")
        case .assetsUnavailable: .unavailable(downloading)
        case .rateLimited: .rateLimited
        default: .server(status: 0, message: error.localizedDescription)
        }
    }
    #endif
}
