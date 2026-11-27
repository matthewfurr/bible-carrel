/// What a template can draw on: the place, the text and, for the prompts that need them, the
/// previous chapter and the other translations. Built by the UI layer from `BibleStore`.
public struct PromptContext: Equatable, Sendable {
    /// "Matthew 5" or "Matthew 5:3-4".
    public var reference: String
    /// "ESV".
    public var translation: String
    /// One verse per line, numbered ("12-13" for a combined verse), poetry lines kept.
    public var chapterText: String
    /// The quoted phrase; "" for chapter scope.
    public var selection: String
    /// "" when there is none.
    public var previousChapterText: String
    /// "KJV\n3 …\n\nWEB\n3 …" or "".
    public var otherTranslations: String

    public init(reference: String, translation: String, chapterText: String, selection: String, previousChapterText: String, otherTranslations: String) {
        self.reference = reference
        self.translation = translation
        self.chapterText = chapterText
        self.selection = selection
        self.previousChapterText = previousChapterText
        self.otherTranslations = otherTranslations
    }
}

/// How a thread is scoped, for the instructions.
public enum ThreadScopeDescription: Equatable, Sendable {
    case selection(quoted: String)
    case chapter
    case book
}

public enum PromptBuilder {
    public static let placeholders = ["reference", "chapter_text", "translation", "selection", "previous_chapter_text", "other_translations"]

    /// Replaces `{{name}}` for the six known placeholders; anything else is left as typed, so a
    /// mistyped placeholder shows up in the reply where the reader can see and fix it.
    public static func fill(_ body: String, with context: PromptContext) -> String {
        let values = [
            "reference": context.reference,
            "chapter_text": context.chapterText,
            "translation": context.translation,
            "selection": context.selection,
            "previous_chapter_text": context.previousChapterText,
            "other_translations": context.otherTranslations,
        ]
        var result = body
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: value)
        }
        return result
    }

    private static let role = "You are a careful study assistant helping one reader through the Bible."
    private static let manner = "Begin with the answer: no greeting and no closing offer of more help. Cite verses by reference. Cite Scripture as Book Chapter:Verse, for example John 15:4. Say plainly when you are uncertain. Never invent references or quotations. Keep answers concise and in plain prose; use a numbered list only when the reader asks for an outline or a list."

    /// A "No context" conversation: the role alone, nothing about where the reader is.
    public static let generalInstructions = role + " " + manner

    /// The system instructions for every request: the role, where the reader is, and the scope.
    public static func instructions(reference: String, translation: String, scope: ThreadScopeDescription) -> String {
        let scopeSentence: String
        switch scope {
        case .selection(let quoted):
            scopeSentence = "They are asking about this passage: \u{201C}\(quoted)\u{201D}."
        case .chapter:
            scopeSentence = "They are asking about this chapter."
        case .book:
            scopeSentence = "They are reading through this book and may move between chapters; each message names where they are."
        }
        return "\(role) The reader is at \(reference) in the \(translation). \(scopeSentence) \(manner)"
    }
}
