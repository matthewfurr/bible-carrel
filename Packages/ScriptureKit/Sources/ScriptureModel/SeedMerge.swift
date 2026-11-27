import Foundation
import ScriptureData
import SwiftData

/// Every device seeds its own default colors and built-in prompts, so with sync two devices can
/// each hold a "Yellow". This gives default colors a stable key and merges records that share a
/// key into one, deterministically, so every device keeps the same record: the lowest
/// `uuid.uuidString` (bookmarks and ticks: the earliest date, ties the lowest uuid). References
/// move to the survivor before any duplicate is deleted, and a record with no key is never merged
/// or deleted.
///
/// Each function returns how many of its own records it changed or removed (a survivor that took
/// a duplicate's values counts once, each deleted duplicate once; re-pointed highlights are not
/// counted), saves once when that is above zero, and changes nothing on a second run.
public enum SeedMerge {
    /// Gives each `isDefault` color with no key the key of the default it is, in three passes over
    /// all of them in `sortOrder` (ties: lowest `uuid.uuidString`), each only to a key not yet given
    /// out in this round: first a match by name (case-insensitive) against `defaultColors` or
    /// `legacyDefaultColors`, then a match by hex pair the same way, then, for a color with no name
    /// or hex match at all, the first such key in `defaultColorKeys` order. A key
    /// another color already holds (one that arrived by sync) is still available, so the local
    /// seed of that default takes it and `mergeDuplicateColors` folds the two into one. Rounds
    /// repeat until every keyless default has a key, so a second call changes nothing. Colors that
    /// are not defaults never get a key.
    @MainActor @discardableResult
    public static func assignDefaultColorKeysIfNeeded(in context: ModelContext) throws -> Int {
        let changed = try assignKeys(in: context)
        if changed > 0 { try context.save() }
        return changed
    }

    @MainActor
    private static func assignKeys(in context: ModelContext) throws -> Int {
        // Ordered by sortOrder, then uuidString, so every device holding the same records assigns the same keys.
        var keyless = try context.fetch(FetchDescriptor<HighlightColor>())
            .filter { $0.isDefault && $0.builtInKey == nil }
            .sorted { $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder : $0.uuid.uuidString < $1.uuid.uuidString }
        var changed = 0
        while !keyless.isEmpty {
            changed += assignRound(&keyless)
        }
        return changed
    }

    /// One round of the three passes; every key is available at its start. Pass 3 skips a color
    /// with a natural key (a name or hex-pair match), which waits for the next round. Gives out at
    /// least one key whenever `keyless` is not empty: the first color with a name match takes its
    /// key in pass 1; failing that, the first with a hex match in pass 2; failing that, no color
    /// has a natural key and the first takes "yellow" in pass 3. So the rounds loop ends.
    private static func assignRound(_ keyless: inout [HighlightColor]) -> Int {
        var used: Set<String> = []
        var changed = 0

        func pass(_ matches: (HighlightColor) -> Int?) {
            keyless.removeAll { color in
                guard let index = matches(color) else { return false }
                let key = MarkupContainer.defaultColorKeys[index]
                guard !used.contains(key) else { return false }
                color.builtInKey = key
                used.insert(key)
                changed += 1
                return true
            }
        }
        let keys = MarkupContainer.defaultColorKeys.indices
        pass { color in
            keys.first { index in
                !used.contains(MarkupContainer.defaultColorKeys[index])
                    && [MarkupContainer.defaultColors[index].name, MarkupContainer.legacyDefaultColors[index].name]
                        .contains { $0.caseInsensitiveCompare(color.name) == .orderedSame }
            }
        }
        pass { color in
            keys.first { index in
                !used.contains(MarkupContainer.defaultColorKeys[index])
                    && [MarkupContainer.defaultColors[index], MarkupContainer.legacyDefaultColors[index]]
                        .contains { sameHexes($0.lightHex, $0.darkHex, color) }
            }
        }
        // A color recognisable as some default waits for a later round, where its own key is free.
        pass { color in
            hasNaturalKey(color) ? nil : keys.first { !used.contains(MarkupContainer.defaultColorKeys[$0]) }
        }
        return changed
    }

    /// The color's name (case-insensitive) or hex pair matches some default or legacy default.
    private static func hasNaturalKey(_ color: HighlightColor) -> Bool {
        (MarkupContainer.defaultColors + MarkupContainer.legacyDefaultColors).contains {
            $0.name.caseInsensitiveCompare(color.name) == .orderedSame || sameHexes($0.lightHex, $0.darkHex, color)
        }
    }

    /// For each `builtInKey` held by more than one color: the lowest `uuid.uuidString` survives.
    /// If the survivor still has that key's default (or legacy default) name and hex pair and a
    /// duplicate does not, the survivor takes the name, hexes and `sortOrder` of the changed
    /// duplicate with the lowest uuid. Highlights using a duplicate move to the survivor, then the
    /// duplicates are deleted, but for one with the survivor's own uuid, which is left (and read as one).
    @MainActor @discardableResult
    public static func mergeDuplicateColors(in context: ModelContext) throws -> Int {
        let changed = try mergeColors(in: context)
        if changed > 0 { try context.save() }
        return changed
    }

    /// The same shape as `mergeDuplicateColors`, by `builtInKey`, for prompts. A prompt is changed
    /// when its `title` is neither the seed's `title` nor its `legacyTitle`, its `summary` or `body`
    /// differs from the seed's, or it is disabled; a key with no seed counts as changed, so its
    /// survivor keeps its own values. The survivor takes `title`, `summary`, `body`, `isEnabled`
    /// and `sortOrder` from the changed duplicate with the lowest uuid.
    @MainActor @discardableResult
    public static func mergeDuplicateBuiltInPrompts(in context: ModelContext, seeds: [PromptSeed]) throws -> Int {
        let changed = try mergePrompts(in: context, seeds: seeds)
        if changed > 0 { try context.save() }
        return changed
    }

    /// Bookmarks on one book, chapter and verse become one: the earliest `createdAt` survives
    /// (ties: the lowest uuid) and takes the first non-nil label among the others, in that same
    /// order, when it has none. The others are deleted, but for one with the survivor's own uuid,
    /// which is left as `mergeDuplicateTicks` leaves one (and read as one).
    @MainActor @discardableResult
    public static func mergeDuplicateBookmarks(in context: ModelContext) throws -> Int {
        let changed = try mergeBookmarks(in: context)
        if changed > 0 { try context.save() }
        return changed
    }

    /// Ticks with one `planID` and `readingID` become one: the earliest `tickedAt` survives (ties:
    /// the lowest uuid) and the others are deleted. A tick with no plan or no reading is left alone,
    /// and no tick is deleted because its plan or its reading is not in the store: an import can
    /// bring a tick before its plan.
    @MainActor @discardableResult
    public static func mergeDuplicateTicks(in context: ModelContext) throws -> Int {
        let changed = try mergeTicks(in: context)
        if changed > 0 { try context.save() }
        return changed
    }

    /// Assigns default color keys, then the four merges, saved once.
    @MainActor @discardableResult
    public static func mergeAll(in context: ModelContext, seeds: [PromptSeed]) throws -> Int {
        let changed = try assignKeys(in: context) + mergeColors(in: context) + mergePrompts(in: context, seeds: seeds)
            + mergeBookmarks(in: context) + mergeTicks(in: context)
        if changed > 0 { try context.save() }
        return changed
    }

    // MARK: - Merges, unsaved

    @MainActor
    private static func mergeColors(in context: ModelContext) throws -> Int {
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<HighlightColor>()).filter { $0.builtInKey != nil }) { $0.builtInKey! }
        let duplicatedKeys = groups.filter { $0.value.count > 1 }
        guard !duplicatedKeys.isEmpty else { return 0 }
        let highlights = try context.fetch(FetchDescriptor<Highlight>())
        var changed = 0

        for (key, colors) in duplicatedKeys {
            let ordered = colors.sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            let survivor = ordered[0], duplicates = ordered.dropFirst()
            if isPristine(survivor, key: key), let edited = duplicates.first(where: { !isPristine($0, key: key) }) {
                survivor.name = edited.name
                survivor.lightHex = edited.lightHex
                survivor.darkHex = edited.darkHex
                survivor.sortOrder = edited.sortOrder
                changed += 1
            }
            let duplicateIDs = Set(duplicates.map(\.uuid))
            for highlight in highlights where highlight.colorID.map(duplicateIDs.contains) == true {
                highlight.colorID = survivor.uuid
            }
            // A twin with the survivor's own uuid is left, as in `mergeTicks`, and read as one.
            for duplicate in duplicates where duplicate.uuid != survivor.uuid {
                context.delete(duplicate)
                changed += 1
            }
        }
        return changed
    }

    @MainActor
    private static func mergePrompts(in context: ModelContext, seeds: [PromptSeed]) throws -> Int {
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<PromptTemplate>()).filter { $0.builtInKey != nil }) { $0.builtInKey! }
        let seedsByKey = Dictionary(seeds.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var changed = 0

        for (key, prompts) in groups where prompts.count > 1 {
            let seed = seedsByKey[key]
            let ordered = prompts.sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            let survivor = ordered[0], duplicates = ordered.dropFirst()
            if isPristine(survivor, seed: seed), let edited = duplicates.first(where: { !isPristine($0, seed: seed) }) {
                survivor.title = edited.title
                survivor.summary = edited.summary
                survivor.body = edited.body
                survivor.isEnabled = edited.isEnabled
                survivor.sortOrder = edited.sortOrder
                changed += 1
            }
            // A twin with the survivor's own uuid is left, as in `mergeTicks`, and read as one.
            for duplicate in duplicates where duplicate.uuid != survivor.uuid {
                context.delete(duplicate)
                changed += 1
            }
        }
        return changed
    }

    @MainActor
    private static func mergeBookmarks(in context: ModelContext) throws -> Int {
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<Bookmark>())) { $0.location }
        var changed = 0

        for (_, bookmarks) in groups where bookmarks.count > 1 {
            let ordered = earliestFirst(bookmarks, date: \.createdAt, uuid: \.uuid)
            let survivor = ordered[0], others = ordered.dropFirst()
            if survivor.label == nil, let label = others.lazy.compactMap(\.label).first {
                survivor.label = label
                changed += 1
            }
            // A twin with the survivor's own uuid is left, as in `mergeTicks`.
            for other in others where other.uuid != survivor.uuid {
                context.delete(other)
                changed += 1
            }
        }
        return changed
    }

    private struct TickKey: Hashable {
        let planID: UUID, readingID: UUID
    }

    @MainActor
    private static func mergeTicks(in context: ModelContext) throws -> Int {
        let keyed = try context.fetch(FetchDescriptor<PlanTick>()).filter { $0.planID != nil && $0.readingID != nil }
        let groups = Dictionary(grouping: keyed) { TickKey(planID: $0.planID!, readingID: $0.readingID!) }
        var changed = 0

        for (_, ticks) in groups where ticks.count > 1 {
            let ordered = earliestFirst(ticks, date: \.tickedAt, uuid: \.uuid)
            // A twin with the survivor's own uuid (a restore made on two devices) is left alone: no
            // rule could make both devices delete the same one of two identical records. Counts are
            // sets, and unticking removes every tick of the reading.
            for other in ordered.dropFirst() where other.uuid != ordered[0].uuid {
                context.delete(other)
                changed += 1
            }
        }
        return changed
    }

    /// The survivor first: the earliest date, ties the lowest `uuid.uuidString`; then the rest in that order.
    private static func earliestFirst<Record>(_ records: [Record], date: (Record) -> Date, uuid: (Record) -> UUID) -> [Record] {
        records.sorted { date($0) != date($1) ? date($0) < date($1) : uuid($0).uuidString < uuid($1).uuidString }
    }

    // MARK: - Pristine checks

    private static func sameHexes(_ lightHex: String, _ darkHex: String, _ color: HighlightColor) -> Bool {
        lightHex.caseInsensitiveCompare(color.lightHex) == .orderedSame
            && darkHex.caseInsensitiveCompare(color.darkHex) == .orderedSame
    }

    /// The color still has its key's default, or legacy default, name and hex pair.
    private static func isPristine(_ color: HighlightColor, key: String) -> Bool {
        guard let index = MarkupContainer.defaultColorKeys.firstIndex(of: key) else { return false }
        return [MarkupContainer.defaultColors[index], MarkupContainer.legacyDefaultColors[index]].contains {
            $0.name == color.name && sameHexes($0.lightHex, $0.darkHex, color)
        }
    }

    private static func isPristine(_ prompt: PromptTemplate, seed: PromptSeed?) -> Bool {
        guard let seed else { return false }
        return (prompt.title == seed.title || prompt.title == seed.legacyTitle)
            && prompt.summary == seed.summary
            && prompt.body == seed.body
            && prompt.isEnabled
    }
}
