import ScriptureModel

/// The spec's prompts in panel order: eleven for the chapter heading (four to get oriented, five
/// to dig in, two to take with you), three for a selection. Each body names the place, gives the
/// text, then asks one thing; each title is what the reader is asking for, and the summary says
/// in a sentence what comes back. `legacyTitle` is the milestone 5 title the migration renames.
public enum BuiltInPrompts {
    private static let chapterLead = "Here is {{reference}} ({{translation}}):\n\n{{chapter_text}}\n\n"
    private static let selectionLead = "I am reading {{reference}} ({{translation}}). The passage:\n\n{{selection}}\n\n"

    public static let all: [PromptSeed] = [
        // Get oriented
        PromptSeed(
            key: "catch-me-up", title: "Catch me up",
            summary: "Where the story or argument stands as this chapter opens, in a few sentences.",
            body: "I am about to read {{reference}} ({{translation}}). Here is the chapter before it:\n\n{{previous_chapter_text}}\n\nCatch me up in a few sentences on where the story or argument stands as this chapter opens. If no previous chapter is given, say this is the start of the book and set the scene from what the book is.",
            scope: .chapter, section: .orient, legacyTitle: "Catch me up"),
        PromptSeed(
            key: "context", title: "Set the scene",
            summary: "Where this chapter sits in the book, what came before, the historical setting and who first read it.",
            body: chapterLead + "Give the context a reader needs for this chapter: where it sits in the book, what came before, the historical setting, and who the first readers were. Keep it to what is well established.",
            scope: .chapter, section: .orient, legacyTitle: "Context"),
        PromptSeed(
            key: "overall-summary", title: "Summarize this chapter",
            summary: "Two or three short paragraphs on what happens or is argued, and why it matters in the book.",
            body: chapterLead + "Give an overall summary of this chapter in two or three short paragraphs: what happens or is argued, and why it matters in the book.",
            scope: .chapter, section: .orient, legacyTitle: "Overall summary"),
        PromptSeed(
            key: "outline", title: "Outline this chapter",
            summary: "A numbered list of its sections, each with a verse range and a short heading.",
            body: chapterLead + "Outline this chapter as a numbered list of sections. Give each section its verse range and a short heading, and keep it to the chapter's own structure.",
            scope: .chapter, section: .orient, legacyTitle: "Outline"),
        // Dig in
        PromptSeed(
            key: "key-themes", title: "Name the key themes",
            summary: "Three to five themes, each in a sentence or two, with the verses that carry them.",
            body: chapterLead + "What are the key themes of this chapter? Name three to five, each in a sentence or two, and point to the verses that carry them.",
            scope: .chapter, section: .study, legacyTitle: "Key themes"),
        PromptSeed(
            key: "cross-references", title: "Find cross-references",
            summary: "Passages elsewhere that this chapter quotes, echoes or is read alongside, with a few words on each connection.",
            body: chapterLead + "List the most useful cross-references for this chapter: passages elsewhere in the Bible that it quotes, echoes, fulfils or is read alongside. Give the reference and a few words on the connection. Only cite passages you are sure exist.",
            scope: .chapter, section: .study, legacyTitle: "Cross-references"),
        PromptSeed(
            key: "people-and-places", title: "Identify people and places",
            summary: "Who and where is named here, with a sentence on each and where else they appear.",
            body: chapterLead + "Who are the people and what are the places named in this chapter? For each, a sentence on who or what they are and where else they appear.",
            scope: .chapter, section: .study, legacyTitle: "People and places"),
        PromptSeed(
            key: "hard-verses", title: "Explain the hard verses",
            summary: "The verses most often puzzled over, with the main readings careful interpreters hold.",
            body: chapterLead + "Which verses in this chapter are hardest to understand, and why? For each, give the main readings that careful interpreters hold, without settling the question for me.",
            scope: .chapter, section: .study, legacyTitle: "Hard verses"),
        PromptSeed(
            key: "word-study", title: "Study the key words",
            summary: "Two or three words worth a closer look: the Hebrew or Greek behind them, their range of meaning and how they are used.",
            body: chapterLead + "Pick the two or three words in this chapter most worth a word study. For each, give the original Hebrew or Greek word, its range of meaning, and how it is used here and elsewhere.",
            scope: .chapter, section: .study, legacyTitle: "Word study"),
        // Take it with you
        PromptSeed(
            key: "reflection-questions", title: "Write reflection questions",
            summary: "Five questions for a reader studying alone that send you back to the text and into your own life.",
            body: chapterLead + "Write five reflection questions on this chapter for a reader studying alone: questions that send me back to the text and into my own life, not quiz questions.",
            scope: .chapter, section: .reflect, legacyTitle: "Reflection questions"),
        PromptSeed(
            key: "memory-verse", title: "Suggest a memory verse",
            summary: "One verse from this chapter to carry with you, quoted exactly, with a sentence on why.",
            body: chapterLead + "Suggest one verse from this chapter to memorise, quote it exactly as given above with its reference, and say in a sentence or two why it is worth carrying.",
            scope: .chapter, section: .reflect, legacyTitle: "Memory verse"),
        // About the passage
        PromptSeed(
            key: "explain-this", title: "Explain this passage",
            summary: "What it says, what it means in its context, and what a careful reader should notice.",
            body: selectionLead + "Explain this passage: what it says, what it means in its context, and anything a careful reader should notice.",
            scope: .selection, section: .passage, legacyTitle: "Explain this"),
        PromptSeed(
            key: "define-words", title: "Define the words",
            summary: "The words that carry the meaning or might be unfamiliar, with the Hebrew or Greek behind them where it helps.",
            body: selectionLead + "Define the words in this passage that carry its meaning or might be unfamiliar. For each, the sense here and, where it helps, the original Hebrew or Greek word behind it.",
            scope: .selection, section: .passage, legacyTitle: "Define words"),
        PromptSeed(
            key: "compare-translations", title: "Compare translations",
            summary: "The same verses in the other bundled translations, with the differences that change the sense and what lies behind them.",
            body: "Here is {{reference}} as I am reading it ({{translation}}):\n\n{{selection}}\n\nThe same verses in other translations:\n\n{{other_translations}}\n\nCompare the wording. Point out the differences that change the sense and say what lies behind them.",
            scope: .selection, section: .passage, legacyTitle: "Compare translations"),
    ]

    /// The keys in the order milestone 5 seeded them. A store whose built-ins still stand in this
    /// order was never reordered, so the migration gives it the order above.
    public static let legacyOrder = [
        "overall-summary", "key-themes", "cross-references", "catch-me-up", "outline", "context", "people-and-places",
        "hard-verses", "reflection-questions", "word-study", "memory-verse", "explain-this", "define-words", "compare-translations",
    ]

    public static func seed(key: String) -> PromptSeed? {
        all.first { $0.key == key }
    }
}
