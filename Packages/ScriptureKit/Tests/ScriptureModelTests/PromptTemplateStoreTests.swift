import Foundation
import Testing
@testable import ScriptureModel

@MainActor @Suite struct PromptTemplateStoreTests {
    private let seeds = [
        PromptSeed(key: "a", title: "A", body: "{{chapter_text}} a", scope: .chapter),
        PromptSeed(key: "b", title: "B", body: "b", scope: .chapter),
        PromptSeed(key: "s", title: "S", body: "{{selection}}", scope: .selection),
    ]

    private func make() throws -> PromptTemplateStore {
        let store = PromptTemplateStore(container: try MarkupContainer.make(inMemory: true))
        try store.seedIfNeeded(seeds)
        return store
    }

    @Test func seedingIsIdempotentAndOrdered() throws {
        let store = try make()
        #expect(try store.seedIfNeeded(seeds) == 0)
        #expect(try store.templates().map(\.title) == ["A", "B", "S"])
        #expect(try store.templates(scope: .selection).map(\.builtInKey) == ["s"])
        #expect(try store.templates().allSatisfy { $0.isBuiltIn && $0.isEnabled })
    }

    @Test func templatesCanBeEditedReorderedDisabledAddedAndDeleted() throws {
        let store = try make()
        let a = try store.templates()[0]
        try store.update(a, title: "A2", body: "changed")
        try store.setEnabled(a, false)
        let mine = try store.add(title: "Mine", body: "m", scope: .chapter)
        #expect(mine.isBuiltIn == false && mine.sortOrder == 3)
        try store.move(scope: .chapter, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(try store.templates(scope: .chapter).map(\.title) == ["Mine", "A2", "B"])
        try store.delete(try store.templates(scope: .chapter)[2])
        #expect(try store.templates(scope: .chapter).map(\.title) == ["Mine", "A2"])
        #expect(try store.templates(scope: .chapter)[1].isEnabled == false)
    }

    @Test func builtInsCanBeRestoredEvenAfterDeletion() throws {
        let store = try make()
        let a = try store.templates()[0]
        try store.update(a, title: "A2", body: "changed")
        try store.restoreBuiltIn(key: "a", from: seeds)
        #expect(a.title == "A" && a.body == "{{chapter_text}} a")
        try store.delete(try store.templates()[1])
        try store.restoreBuiltIn(key: "b", from: seeds)
        #expect(try store.templates().map(\.title) == ["A", "S", "B"])
    }
}

/// Summaries, sections, the milestone 6 migration and Move Up / Move Down, each from an empty store.
@MainActor @Suite struct PromptTemplateSectionTests {
    private func make() throws -> PromptTemplateStore {
        PromptTemplateStore(container: try MarkupContainer.make(inMemory: true))
    }

    @Test func migrationRenamesUneditedBuiltInsAndFillsSummaries() throws {
        let store = try make()
        let old = PromptSeed(key: "overall-summary", title: "Overall summary", summary: "", body: "B", scope: .chapter, section: .custom, legacyTitle: "Overall summary")
        try store.seedIfNeeded([old])
        let new = PromptSeed(key: "overall-summary", title: "Summarize this chapter", summary: "Two or three paragraphs.", body: "B", scope: .chapter, section: .orient, legacyTitle: "Overall summary")
        #expect(try store.migrateBuiltInsIfNeeded(from: [new]) == 1)
        let template = try store.templates()[0]
        #expect(template.title == "Summarize this chapter")
        #expect(template.summary == "Two or three paragraphs.")
        #expect(template.section == .orient)
        #expect(try store.migrateBuiltInsIfNeeded(from: [new]) == 0)
    }

    @Test func anEditedBuiltInKeepsItsTitleButGainsSummaryAndSection() throws {
        let store = try make()
        let old = PromptSeed(key: "context", title: "Context", summary: "", body: "B", scope: .chapter, section: .custom, legacyTitle: "Context")
        try store.seedIfNeeded([old])
        try store.update(try store.templates()[0], title: "My context", body: "B")
        let new = PromptSeed(key: "context", title: "Set the scene", summary: "Where it sits.", body: "B", scope: .chapter, section: .orient, legacyTitle: "Context")
        _ = try store.migrateBuiltInsIfNeeded(from: [new])
        let template = try store.templates()[0]
        #expect(template.title == "My context")
        #expect(template.summary == "Where it sits.")
        #expect(template.section == .orient)
    }

    @Test func moveByOneStaysInsideTheScope() throws {
        let store = try make()
        let a = try store.add(title: "A", summary: "", body: "", scope: .chapter)
        let b = try store.add(title: "B", summary: "", body: "", scope: .chapter)
        let s = try store.add(title: "S", summary: "", body: "", scope: .selection)
        try store.move(b, by: -1)
        #expect(try store.templates(scope: .chapter).map(\.title) == ["B", "A"])
        try store.move(s, by: -1)
        #expect(try store.templates(scope: .selection).map(\.title) == ["S"])
        _ = a
    }

    /// Settings lists a scope by section, so a move swaps with the neighbour in the same section.
    @Test func moveByOneStaysInsideTheSection() throws {
        let store = try make()
        try store.seedIfNeeded([
            PromptSeed(key: "o1", title: "O1", summary: "", body: "", scope: .chapter, section: .orient, legacyTitle: "O1"),
            PromptSeed(key: "s1", title: "S1", summary: "", body: "", scope: .chapter, section: .study, legacyTitle: "S1"),
            PromptSeed(key: "o2", title: "O2", summary: "", body: "", scope: .chapter, section: .orient, legacyTitle: "O2"),
        ])
        let o2 = try #require(try store.templates().first { $0.title == "O2" })
        try store.move(o2, by: -1)
        #expect(try store.templates(scope: .chapter).map(\.title) == ["O2", "S1", "O1"])
        try store.move(o2, by: -1)
        #expect(try store.templates(scope: .chapter).map(\.title) == ["O2", "S1", "O1"])
    }

    /// Four chapter built-ins as milestone 5 shipped them (one section, legacy order), the same
    /// four as milestone 6 seeds them (two sections, new order), and one selection built-in whose
    /// order is the same in both.
    private let legacyOrder = ["overall-summary", "key-themes", "catch-me-up", "context", "explain-this"]
    private var legacySeeds: [PromptSeed] {
        legacyOrder.map { key in
            PromptSeed(key: key, title: key, body: key, scope: key == "explain-this" ? .selection : .chapter)
        }
    }
    private let newSeeds = [
        PromptSeed(key: "catch-me-up", title: "Catch me up", summary: "S.", body: "catch-me-up", scope: .chapter, section: .orient, legacyTitle: "catch-me-up"),
        PromptSeed(key: "context", title: "Set the scene", summary: "S.", body: "context", scope: .chapter, section: .orient, legacyTitle: "context"),
        PromptSeed(key: "overall-summary", title: "Summarize this chapter", summary: "S.", body: "overall-summary", scope: .chapter, section: .orient, legacyTitle: "overall-summary"),
        PromptSeed(key: "key-themes", title: "Name the key themes", summary: "S.", body: "key-themes", scope: .chapter, section: .study, legacyTitle: "key-themes"),
        PromptSeed(key: "explain-this", title: "Explain this passage", summary: "S.", body: "explain-this", scope: .selection, section: .passage, legacyTitle: "explain-this"),
    ]

    @Test func anUntouchedStoreIsRenumberedToTheNewOrder() throws {
        let store = try make()
        try store.seedIfNeeded(legacySeeds)
        let mine = try store.add(title: "Mine", body: "", scope: .chapter)
        #expect(try store.migrateBuiltInsIfNeeded(from: newSeeds, legacyOrder: legacyOrder) == 5)
        #expect(try store.templates(scope: .chapter).map(\.builtInKey) == ["catch-me-up", "context", "overall-summary", "key-themes", nil])
        #expect(try store.templates(scope: .chapter).last?.uuid == mine.uuid)
        #expect(try store.templates(scope: .selection).map(\.builtInKey) == ["explain-this"])
        #expect(Set(try store.templates().map(\.sortOrder)).count == 6)
        #expect(try store.migrateBuiltInsIfNeeded(from: newSeeds, legacyOrder: legacyOrder) == 0)
    }

    @Test func aReorderedStoreKeepsItsOrder() throws {
        let store = try make()
        try store.seedIfNeeded(legacySeeds)
        try store.move(scope: .chapter, fromOffsets: IndexSet(integer: 3), toOffset: 0)
        let reordered = try store.templates(scope: .chapter).map(\.builtInKey)
        #expect(reordered == ["context", "overall-summary", "key-themes", "catch-me-up"])
        _ = try store.migrateBuiltInsIfNeeded(from: newSeeds, legacyOrder: legacyOrder)
        #expect(try store.templates(scope: .chapter).map(\.builtInKey) == reordered)
        #expect(try store.templates(scope: .chapter).map(\.title) == ["Set the scene", "Summarize this chapter", "Name the key themes", "Catch me up"])
    }

    @Test func restoreAndTheOldSignaturesKeepSummaryAndSection() throws {
        let store = try make()
        let seed = PromptSeed(key: "k", title: "T", summary: "A sentence.", body: "B", scope: .chapter, section: .study, legacyTitle: "Old")
        try store.seedIfNeeded([seed])
        let template = try store.templates()[0]
        #expect(template.summary == "A sentence." && template.section == .study)
        try store.update(template, title: "T2", body: "B2")
        #expect(template.summary == "A sentence.")
        try store.update(template, title: "T3", summary: "Mine.", body: "B3")
        template.section = .custom
        try store.restoreBuiltIn(key: "k", from: [seed])
        #expect(template.title == "T" && template.summary == "A sentence." && template.body == "B" && template.section == .study)
        let mine = try store.add(title: "M", body: "", scope: .selection)
        #expect(mine.summary.isEmpty && mine.section == .custom && mine.sectionRaw == nil)
    }
}
