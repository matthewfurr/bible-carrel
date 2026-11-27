import Testing
@testable import ScriptureLLM

@Suite struct PromptBuilderTests {
    private let context = PromptContext(reference: "Matthew 5", translation: "ESV", chapterText: "1 Seeing the crowds\n2 And he opened", selection: "", previousChapterText: "", otherTranslations: "")

    @Test func placeholdersAreFilled() {
        #expect(PromptBuilder.fill("{{reference}} ({{translation}}):\n{{chapter_text}}", with: context) == "Matthew 5 (ESV):\n1 Seeing the crowds\n2 And he opened")
    }

    @Test func unknownPlaceholdersAreLeftAsTyped() {
        #expect(PromptBuilder.fill("Explain {{verse}} of {{reference}}", with: context) == "Explain {{verse}} of Matthew 5")
    }

    @Test func builtInPromptsCoverTheSpecInOrder() {
        #expect(BuiltInPrompts.all.map(\.title) == ["Catch me up", "Set the scene", "Summarize this chapter", "Outline this chapter", "Name the key themes", "Find cross-references", "Identify people and places", "Explain the hard verses", "Study the key words", "Write reflection questions", "Suggest a memory verse", "Explain this passage", "Define the words", "Compare translations"])
        #expect(BuiltInPrompts.all.map(\.legacyTitle) == ["Catch me up", "Context", "Overall summary", "Outline", "Key themes", "Cross-references", "People and places", "Hard verses", "Word study", "Reflection questions", "Memory verse", "Explain this", "Define words", "Compare translations"])
        #expect(BuiltInPrompts.all.filter { $0.scope == .selection }.map(\.key) == ["explain-this", "define-words", "compare-translations"])
        #expect(Set(BuiltInPrompts.all.map(\.key)).count == 14)
        #expect(BuiltInPrompts.seed(key: "catch-me-up")?.body.contains("{{previous_chapter_text}}") == true)
        for seed in BuiltInPrompts.all where seed.scope == .chapter && seed.key != "catch-me-up" {
            #expect(seed.body.contains("{{chapter_text}}"), "\(seed.key)")
        }
        for seed in BuiltInPrompts.all where seed.scope == .selection {
            #expect(seed.body.contains("{{selection}}"), "\(seed.key)")
        }
    }

    /// "No context": the role alone, nothing about where the reader is (Ruling 2).
    @Test func generalInstructionsNameNoPlace() {
        let text = PromptBuilder.generalInstructions
        #expect(text.hasPrefix("You are a careful study assistant") && !text.contains("The reader is at"))
    }

    @Test func instructionsNameThePlaceAndScope() {
        let text = PromptBuilder.instructions(reference: "Matthew 5:3", translation: "ESV", scope: .selection(quoted: "Blessed are the poor"))
        #expect(text.hasPrefix("You are a careful study assistant"))
        #expect(text.contains("Matthew 5:3 in the ESV") && text.contains("“Blessed are the poor”") && text.contains("Never invent references"))
        #expect(PromptBuilder.instructions(reference: "Matthew", translation: "KJV", scope: .book).contains("move between chapters"))
    }

    /// References in a reply become links only in this form, so every instruction asks for it.
    @Test func instructionsAskForCitationsAsBookChapterVerse() {
        let sentence = "Cite Scripture as Book Chapter:Verse, for example John 15:4."
        #expect(PromptBuilder.generalInstructions.contains(sentence))
        for scope in [ThreadScopeDescription.chapter, .book, .selection(quoted: "Abide in me")] {
            #expect(PromptBuilder.instructions(reference: "John 15", translation: "ESV", scope: scope).contains(sentence))
        }
    }

    /// Patient and literate, not a chatbot: the on-device model opened with "Certainly!" and
    /// closed with "I hope this helps!" until told not to.
    @Test func instructionsAskForTheAnswerWithoutGreetingOrSignOff() {
        for text in [PromptBuilder.generalInstructions, PromptBuilder.instructions(reference: "Matthew 5", translation: "ESV", scope: .chapter)] {
            #expect(text.contains("Begin with the answer") && text.contains("no greeting"))
        }
    }
}
