import Foundation
import SwiftData

/// What a prompt template applies to: the whole chapter (the heading menu) or the reader's
/// selection (the chat panel's chips).
public enum PromptScope: String, Codable, Sendable {
    case chapter
    case selection
}

/// Where a prompt is listed: the chapter's built-ins under three headings, the selection's under
/// one, and anything the reader adds under "Your prompts". Case order is listing order.
public enum PromptSection: String, Codable, CaseIterable, Sendable {
    case orient
    case study
    case reflect
    case passage
    case custom

    public var title: String {
        switch self {
        case .orient: "Get oriented"
        case .study: "Dig in"
        case .reflect: "Take it with you"
        case .passage: "About the passage"
        case .custom: "Your prompts"
        }
    }
}

/// A prompt template as shipped, before the reader edits it. `key` is the stable identity the
/// store seeds by and Settings restores from; `legacyTitle` is the title milestone 5 shipped,
/// which tells the migration whether the reader kept it. The values live in
/// `ScriptureLLM.BuiltInPrompts`.
public struct PromptSeed: Equatable, Sendable {
    public let key: String
    public let title: String
    public let summary: String
    public let body: String
    public let scope: PromptScope
    public let section: PromptSection
    public let legacyTitle: String

    public init(key: String, title: String, summary: String, body: String, scope: PromptScope, section: PromptSection, legacyTitle: String) {
        self.key = key
        self.title = title
        self.summary = summary
        self.body = body
        self.scope = scope
        self.section = section
        self.legacyTitle = legacyTitle
    }

    /// A seed with no summary, listed under "Your prompts", whose title never changed.
    public init(key: String, title: String, body: String, scope: PromptScope) {
        self.init(key: key, title: title, summary: "", body: body, scope: scope, section: .custom, legacyTitle: title)
    }
}

/// An editable study prompt: the built-ins seeded once from `PromptSeed`s and anything the reader
/// adds. Placeholders (`{{reference}}`, `{{chapter_text}}`, ...) are filled when it runs.
/// `outputKind` is stored for sync and later structured output; nothing reads it yet.
/// `summary` and `sectionRaw` arrived in milestone 6 with defaults, so an older store opens as it
/// is; a nil section reads as "Your prompts" until `migrateBuiltInsIfNeeded` fills a built-in's.
@Model
public final class PromptTemplate {
    public var uuid: UUID = UUID()
    public var title: String = ""
    public var summary: String = ""
    public var body: String = ""
    public var scopeRaw: String = PromptScope.chapter.rawValue
    public var sectionRaw: String?
    public var isEnabled: Bool = true
    public var sortOrder: Int = 0
    public var isBuiltIn: Bool = false
    public var builtInKey: String?
    public var outputKind: String = "text"

    public init(title: String, summary: String, body: String, scope: PromptScope, section: PromptSection, sortOrder: Int, isBuiltIn: Bool, builtInKey: String?) {
        self.title = title
        self.summary = summary
        self.body = body
        self.scopeRaw = scope.rawValue
        self.sectionRaw = Self.raw(section)
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
        self.builtInKey = builtInKey
    }

    public convenience init(title: String, body: String, scope: PromptScope, sortOrder: Int, isBuiltIn: Bool, builtInKey: String?) {
        self.init(title: title, summary: "", body: body, scope: scope, section: .custom, sortOrder: sortOrder, isBuiltIn: isBuiltIn, builtInKey: builtInKey)
    }

    public var scope: PromptScope {
        get { PromptScope(rawValue: scopeRaw) ?? .chapter }
        set { scopeRaw = newValue.rawValue }
    }

    /// "Your prompts" is stored as nil, the value a record from before milestone 6 has.
    public var section: PromptSection {
        get { sectionRaw.flatMap(PromptSection.init(rawValue:)) ?? .custom }
        set { sectionRaw = Self.raw(newValue) }
    }

    private static func raw(_ section: PromptSection) -> String? {
        section == .custom ? nil : section.rawValue
    }
}
