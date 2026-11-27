import Foundation
import SwiftData

/// The reader's prompt templates: seeded once from the built-ins, then edited, reordered,
/// enabled or disabled, added to and deleted in Settings. Every mutation saves.
@MainActor
public final class PromptTemplateStore {
    public let container: ModelContainer
    public let context: ModelContext

    public init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    /// Inserts every seed whose key is absent, after whatever exists; records already present are
    /// never changed. Returns how many were added.
    @discardableResult
    public func seedIfNeeded(_ seeds: [PromptSeed]) throws -> Int {
        let existing = Set(try templates().compactMap(\.builtInKey))
        var next = (try templates().map(\.sortOrder).max() ?? -1) + 1
        var added = 0
        for seed in seeds where !existing.contains(seed.key) {
            context.insert(PromptTemplate(
                title: seed.title, summary: seed.summary, body: seed.body, scope: seed.scope, section: seed.section,
                sortOrder: next, isBuiltIn: true, builtInKey: seed.key))
            next += 1
            added += 1
        }
        if added > 0 { try context.save() }
        return added
    }

    /// Brings built-ins seeded before milestone 6 up to their seeds: an unedited title (still the
    /// legacy title, over the seed's body) takes the new wording, an empty summary takes the
    /// seed's, and a missing section the seed's. The reader's own edits are kept. Then, per scope,
    /// if the built-ins still stand in `legacyOrder` (the keys in milestone 5's order), the reader
    /// never reordered them, so they take the seeds' order (section, then seed order) with any
    /// other prompt after them as it was; an order the reader set is left alone. A second run
    /// changes nothing. Returns how many records changed.
    @discardableResult
    public func migrateBuiltInsIfNeeded(from seeds: [PromptSeed], legacyOrder: [String] = []) throws -> Int {
        let byKey = Dictionary(seeds.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var changed = Set<UUID>()
        for template in try templates() where template.isBuiltIn {
            guard let seed = template.builtInKey.flatMap({ byKey[$0] }) else { continue }
            if template.title == seed.legacyTitle, template.body == seed.body, template.title != seed.title {
                template.title = seed.title
                changed.insert(template.uuid)
            }
            if template.summary.isEmpty, !seed.summary.isEmpty {
                template.summary = seed.summary
                changed.insert(template.uuid)
            }
            if template.sectionRaw == nil, seed.section != .custom {
                template.section = seed.section
                changed.insert(template.uuid)
            }
        }
        if !legacyOrder.isEmpty {
            for scope in [PromptScope.chapter, .selection] {
                changed.formUnion(try renumberUntouched(scope: scope, seeds: seeds, legacyOrder: legacyOrder))
            }
        }
        if !changed.isEmpty { try context.save() }
        return changed.count
    }

    /// The milestone 6 renumbering for one scope; returns the templates whose `sortOrder` moved.
    /// The scope's existing numbers are reused, so the other scope's are untouched.
    private func renumberUntouched(scope: PromptScope, seeds: [PromptSeed], legacyOrder: [String]) throws -> Set<UUID> {
        let scoped = try templates(scope: scope)
        let seedIndex = Dictionary(seeds.enumerated().map { ($1.key, $0) }, uniquingKeysWith: { first, _ in first })
        let builtIns = scoped.filter { $0.isBuiltIn && $0.builtInKey.map { seedIndex[$0] != nil && legacyOrder.contains($0) } == true }
        let current = builtIns.compactMap(\.builtInKey)
        let present = Set(current)
        guard current == legacyOrder.filter(present.contains) else { return [] }
        let sectionRank = Dictionary(uniqueKeysWithValues: PromptSection.allCases.enumerated().map { ($1, $0) })
        func rank(_ template: PromptTemplate) -> (Int, Int) {
            let index = template.builtInKey.flatMap { seedIndex[$0] } ?? 0
            return (sectionRank[seeds[index].section] ?? 0, index)
        }
        let builtInIDs = Set(builtIns.map(\.uuid))
        let order = builtIns.sorted { rank($0) < rank($1) } + scoped.filter { !builtInIDs.contains($0.uuid) }
        var moved = Set<UUID>()
        for (template, sortOrder) in zip(order, scoped.map(\.sortOrder)) where template.sortOrder != sortOrder {
            template.sortOrder = sortOrder
            moved.insert(template.uuid)
        }
        return moved
    }

    /// By sort order; `scope` narrows to one kind. One per uuid (`Twins`), the first fetched.
    public func templates(scope: PromptScope? = nil) throws -> [PromptTemplate] {
        let all = Twins.firsts(try context.fetch(FetchDescriptor<PromptTemplate>(sortBy: [SortDescriptor(\.sortOrder)])), id: \.uuid)
        guard let scope else { return all }
        return all.filter { $0.scope == scope }
    }

    public func template(id: UUID) throws -> PromptTemplate? {
        var descriptor = FetchDescriptor<PromptTemplate>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// A prompt of the reader's own, listed under "Your prompts" after everything else.
    @discardableResult
    public func add(title: String, summary: String, body: String, scope: PromptScope) throws -> PromptTemplate {
        let next = (try templates().map(\.sortOrder).max() ?? -1) + 1
        let template = PromptTemplate(
            title: title, summary: summary, body: body, scope: scope, section: .custom,
            sortOrder: next, isBuiltIn: false, builtInKey: nil)
        context.insert(template)
        try context.save()
        return template
    }

    @discardableResult
    public func add(title: String, body: String, scope: PromptScope) throws -> PromptTemplate {
        try add(title: title, summary: "", body: body, scope: scope)
    }

    public func update(_ template: PromptTemplate, title: String, summary: String, body: String) throws {
        template.title = title
        template.summary = summary
        template.body = body
        try context.save()
    }

    /// Keeps the summary as it is.
    public func update(_ template: PromptTemplate, title: String, body: String) throws {
        try update(template, title: title, summary: template.summary, body: body)
    }

    public func setEnabled(_ template: PromptTemplate, _ enabled: Bool) throws {
        template.isEnabled = enabled
        try context.save()
    }

    /// Reorders within one scope (SwiftUI `move` semantics); the other scope's order is untouched.
    public func move(scope: PromptScope, fromOffsets: IndexSet, toOffset: Int) throws {
        let moved = MarkupStore.moving(try templates(scope: scope), fromOffsets: fromOffsets, toOffset: toOffset)
        try renumber(scope: scope, order: moved)
    }

    /// Move Up (-1) or Move Down (+1): swaps places with the neighbour listed beside it, which is
    /// the next one in the same scope and section. At either end it does nothing.
    public func move(_ template: PromptTemplate, by offset: Int) throws {
        let siblings = try templates(scope: template.scope).filter { $0.section == template.section }
        guard let index = siblings.firstIndex(where: { $0.uuid == template.uuid }),
              siblings.indices.contains(index + offset), offset != 0
        else { return }
        let neighbour = siblings[index + offset]
        (template.sortOrder, neighbour.sortOrder) = (neighbour.sortOrder, template.sortOrder)
        try context.save()
    }

    public func delete(_ template: PromptTemplate) throws {
        context.delete(template)
        try context.save()
    }

    /// Puts a built-in's title, summary, body and section back to its seed; a deleted built-in is
    /// re-created at the end.
    public func restoreBuiltIn(key: String, from seeds: [PromptSeed]) throws {
        guard let seed = seeds.first(where: { $0.key == key }) else { return }
        if let existing = try templates().first(where: { $0.builtInKey == key }) {
            existing.title = seed.title
            existing.summary = seed.summary
            existing.body = seed.body
            existing.section = seed.section
            try context.save()
        } else {
            try seedIfNeeded([seed])
        }
    }

    /// Rewrites `sortOrder` so `order` comes first within its scope, keeping the whole list's
    /// numbering unique.
    private func renumber(scope: PromptScope, order: [PromptTemplate]) throws {
        let others = try templates().filter { $0.scope != scope }
        var index = 0
        for template in order + others {
            template.sortOrder = index
            index += 1
        }
        try context.save()
    }
}
