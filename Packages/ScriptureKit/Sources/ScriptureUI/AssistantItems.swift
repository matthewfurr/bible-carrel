import Foundation
import ScriptureData
import ScriptureLLM
import ScriptureModel

/// A conversation by value, for the panel's header, its history menu and the Notes browser.
public struct ChatThreadItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let scope: ThreadScope
    public let title: String
    /// "Matthew 5:3" (selection), "Matthew 5" (chapter, and the chapter a general thread was
    /// opened from), "Matthew" (book).
    public let referenceString: String
    public let location: ChapterLocation
    public let verse: Int
    public let endVerse: Int
    public let startOffset: Int
    public let endOffset: Int
    public let translationID: String
    public let quotedText: String
    public let updatedAt: Date
    /// The last turn's first line, markdown stripped, whole: rows truncate it where they wrap.
    public let lastLine: String

    init(_ thread: ChatThread) {
        id = thread.uuid
        scope = thread.scope
        title = thread.title
        let book = BookCatalog.book(code: thread.book) ?? Book(id: thread.book, canon: .oldTestament, order: 0, name: thread.book, shortName: thread.book)
        switch thread.scope {
        case .selection:
            referenceString = Reference(book: book, chapter: thread.chapter, verse: thread.verse, endVerse: thread.endVerse == thread.verse ? nil : thread.endVerse).displayString
        case .chapter, .general:
            referenceString = Reference(book: book, chapter: thread.chapter).displayString
        case .book:
            referenceString = book.name
        }
        location = thread.chapterLocation
        verse = thread.verse
        endVerse = thread.endVerse
        startOffset = thread.startOffset
        endOffset = thread.endOffset
        translationID = thread.translationID
        quotedText = thread.quotedText
        updatedAt = thread.updatedAt
        lastLine = thread.orderedMessages.last.map { SearchMarkHit.firstLine(of: $0.displayText ?? $0.content, limit: nil) } ?? ""
    }
}

/// One turn by value. `content` is what the model was sent or said; `displayText` is what the
/// panel shows for a reader turn (the question, or a template's title).
public struct ChatMessageItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public var content: String
    public let displayText: String
    /// "On-device", "Claude · claude-opus-5-5"; nil for the reader's turns.
    public let providerLabel: String?
    public let attachedReference: String?
    public var isStreaming: Bool
    /// The note Add as Note made of this reply, while it exists.
    public var savedNoteID: UUID?
    /// Why the reply ended early; nil when it is complete.
    public var finishReason: ChatFinishReason?

    public init(id: UUID, role: ChatRole, content: String, displayText: String? = nil, providerLabel: String?, attachedReference: String?, isStreaming: Bool,
                savedNoteID: UUID? = nil, finishReason: ChatFinishReason? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.displayText = displayText ?? content
        self.providerLabel = providerLabel
        self.attachedReference = attachedReference
        self.isStreaming = isStreaming
        self.savedNoteID = savedNoteID
        self.finishReason = finishReason
    }
}

/// Why a reply that has text ended before the model finished, as its footer says.
public enum ChatFinishReason: String, Sendable {
    case declined
    case cutShort
    case stopped
    /// The connection or the provider failed after some text arrived.
    case failed

    public var footerText: String {
        switch self {
        case .declined: "Declined partway"
        case .cutShort: "Cut short"
        case .stopped: "Stopped"
        case .failed: "Ended early"
        }
    }
}

/// A prompt as the panel lists it: the title to run, the sentence or two under it, and the
/// section it is grouped in.
public struct PromptTemplateItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let summary: String
    public let scope: PromptScope
    public let section: PromptSection
    public let isEnabled: Bool

    public init(id: UUID, title: String, summary: String = "", scope: PromptScope, section: PromptSection = .custom, isEnabled: Bool) {
        self.id = id
        self.title = title
        self.summary = summary
        self.scope = scope
        self.section = section
        self.isEnabled = isEnabled
    }
}

/// Why the assistant could not answer, as one plain sentence (Ruling 9). The technical detail
/// goes to the log.
public enum AssistantNotice: Equatable, Sendable {
    case tooLongForOnDevice
    case onDeviceUnavailable(String)
    case nothingConfigured
    case unauthorized
    case rateLimited
    case unreachable
    case declined
    case cutShort
    case failed

    public var message: String {
        switch self {
        case .tooLongForOnDevice: "This is too long for the on-device model. Add a Claude or OpenAI key in Settings to ask about it."
        case .onDeviceUnavailable(let reason): "The on-device model can\u{2019}t answer right now. \(reason)"
        case .nothingConfigured: "No model is set up to answer. Add a key in Settings."
        case .unauthorized: "The API key was not accepted. Check it in Settings."
        case .rateLimited: "The provider is busy or this key has reached its limit. Try again in a minute."
        case .unreachable: "The assistant couldn\u{2019}t be reached. Check your connection and try again."
        case .declined: "The model declined to answer this. Try asking another way."
        case .cutShort: "The answer was cut short. Ask the assistant to go on."
        case .failed: "Something went wrong getting an answer. Try again."
        }
    }

    /// The four a change in Settings can fix.
    public var offersSettings: Bool {
        switch self {
        case .tooLongForOnDevice, .onDeviceUnavailable, .nothingConfigured, .unauthorized: true
        case .rateLimited, .unreachable, .declined, .cutShort, .failed: false
        }
    }
}

/// Who answered, as the reply's footer names it (Ruling 7).
public enum ProviderLabel {
    /// `host` names a compatible endpoint: the one the reply recorded, else the Settings one.
    public static func text(providerID: String, modelName: String, host: String?) -> String {
        switch LLMProviderID(rawValue: providerID) {
        case .appleOnDevice: "On-device"
        case .anthropic: "Claude · \(modelName)"
        case .openAI: "OpenAI · \(modelName)"
        case .openAICompatible: "\(host ?? "Custom endpoint") · \(modelName)"
        case nil: modelName
        }
    }

    public static func text(providerID: String, modelName: String, baseURL: URL?) -> String {
        text(providerID: providerID, modelName: modelName, host: baseURL?.host())
    }

    /// A reply the on-device model gave because the cloud provider could not be reached;
    /// `cloudName` is the cloud label's part before " · " ("Claude", "OpenAI", or the host).
    public static func fallbackText(cloudName: String) -> String {
        "On-device · \(cloudName) unreachable"
    }
}
