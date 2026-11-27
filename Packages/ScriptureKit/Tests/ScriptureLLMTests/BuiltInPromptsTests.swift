import Testing
import ScriptureModel
@testable import ScriptureLLM

@Suite struct BuiltInPromptsTests {
    @Test func everyBuiltInHasAShortTitleAndASentenceOrTwo() {
        for seed in BuiltInPrompts.all {
            #expect(seed.title.split(separator: " ").count <= 5, "\(seed.key)")
            #expect(seed.summary.hasSuffix("."), "\(seed.key)")
            #expect(seed.summary.count <= 160, "\(seed.key)")
            #expect(seed.summary.components(separatedBy: ". ").count <= 2, "\(seed.key)")
            #expect(!seed.legacyTitle.isEmpty, "\(seed.key)")
        }
    }

    @Test func legacyOrderIsMilestoneFivesOrderOfEveryBuiltIn() {
        #expect(BuiltInPrompts.legacyOrder == [
            "overall-summary", "key-themes", "cross-references", "catch-me-up", "outline", "context", "people-and-places",
            "hard-verses", "reflection-questions", "word-study", "memory-verse", "explain-this", "define-words", "compare-translations",
        ])
        #expect(Set(BuiltInPrompts.legacyOrder) == Set(BuiltInPrompts.all.map(\.key)))
    }

    /// A milestone 5 store, never reordered, comes out of the migration exactly as a fresh seed.
    @MainActor @Test func aMilestoneFiveStoreMigratesToTheFreshList() throws {
        let store = PromptTemplateStore(container: try MarkupContainer.make(inMemory: true))
        let legacy = try BuiltInPrompts.legacyOrder.map { key in
            let seed = try #require(BuiltInPrompts.seed(key: key))
            return PromptSeed(key: key, title: seed.legacyTitle, body: seed.body, scope: seed.scope)
        }
        try store.seedIfNeeded(legacy)
        #expect(try store.migrateBuiltInsIfNeeded(from: BuiltInPrompts.all, legacyOrder: BuiltInPrompts.legacyOrder) == 14)
        let migrated = try store.templates()
        #expect(migrated.map(\.builtInKey) == BuiltInPrompts.all.map(\.key))
        #expect(migrated.map(\.title) == BuiltInPrompts.all.map(\.title))
        #expect(migrated.map(\.summary) == BuiltInPrompts.all.map(\.summary))
        #expect(migrated.map(\.section) == BuiltInPrompts.all.map(\.section))
        #expect(try store.migrateBuiltInsIfNeeded(from: BuiltInPrompts.all, legacyOrder: BuiltInPrompts.legacyOrder) == 0)
    }

    @Test func sectionsMatchScopes() {
        for seed in BuiltInPrompts.all {
            #expect((seed.scope == .selection) == (seed.section == .passage), "\(seed.key)")
            #expect(seed.section != .custom, "\(seed.key)")
        }
    }
}
