import Foundation
import SwiftData

public enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
}

/// One turn. Assistant turns record who answered (`providerID`, `modelName`) so the panel can
/// label them; a reader turn sent from a new chapter in a book thread records where
/// (`attachedReference`). `content` is what the model was sent; `displayText`, when set, is what
/// the reader asked (a template's title, or the question without the chapter text before it).
/// An assistant turn also records the compatible endpoint's host it came from (`providerHost`),
/// why it ended early (`finishReason`: "declined", "cutShort", "stopped" or "failed"; nil when complete)
/// and the note Add as Note made of it (`savedNoteID`).
@Model
public final class ChatMessage {
    public var uuid: UUID = UUID()
    public var roleRaw: String = ChatRole.user.rawValue
    public var content: String = ""
    public var createdAt: Date = Date()
    public var providerID: String = ""
    public var modelName: String = ""
    public var attachedReference: String?
    public var displayText: String?
    public var providerHost: String?
    public var finishReason: String?
    public var savedNoteID: UUID?
    public var thread: ChatThread?

    public init(role: ChatRole, content: String, providerID: String, modelName: String, attachedReference: String?) {
        self.roleRaw = role.rawValue
        self.content = content
        self.providerID = providerID
        self.modelName = modelName
        self.attachedReference = attachedReference
    }

    public var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
}
