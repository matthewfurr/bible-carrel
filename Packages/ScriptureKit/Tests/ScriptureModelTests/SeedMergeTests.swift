import Foundation
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct SeedMergeTests {
    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-00000000000\(n)")!
    }

    /// A default color at Yellow's current values unless told otherwise.
    private func color(_ name: String, key: String?, uuid: UUID, lightHex: String = "#F8E18A", darkHex: String = "#554704",
                       sortOrder: Int = 0, isDefault: Bool = true) -> HighlightColor {
        let color = HighlightColor(name: name, lightHex: lightHex, darkHex: darkHex, sortOrder: sortOrder, isDefault: isDefault)
        color.uuid = uuid
        color.builtInKey = key
        return color
    }

    private let outlineSeed = PromptSeed(key: "outline", title: "Outline", summary: "The shape", body: "Outline {{reference}}",
                                         scope: .chapter, section: .orient, legacyTitle: "Outline this chapter")

    private func outline(uuid: UUID) -> PromptTemplate {
        let prompt = PromptTemplate(title: outlineSeed.title, summary: outlineSeed.summary, body: outlineSeed.body, scope: .chapter, section: .orient,
                                    sortOrder: 1, isBuiltIn: true, builtInKey: "outline")
        prompt.uuid = uuid
        return prompt
    }

    private func sorted(_ context: ModelContext) throws -> [HighlightColor] {
        try context.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    @Test func existingDefaultsGetTheirKeys() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let green = MarkupContainer.defaultColors[1]
        // "Mine" sorts first, so it only gets "blue" if the name and hex matches are made before it is given the first unused key.
        context.insert(color("Mine", key: nil, uuid: id(1), lightHex: "#123456", darkHex: "#654321", sortOrder: 0))
        context.insert(color("Yellow", key: nil, uuid: id(2), lightHex: "#FFE86B", darkHex: "#6B5B00", sortOrder: 1))
        context.insert(color("Gold", key: nil, uuid: id(3), lightHex: green.lightHex, darkHex: green.darkHex, sortOrder: 2))
        context.insert(color("Pink", key: nil, uuid: id(4), lightHex: "#FFC7DE", darkHex: "#7A2E55", sortOrder: 3))
        context.insert(color("Sky", key: nil, uuid: id(5), lightHex: "#B8E8FF", darkHex: "#144D6E", sortOrder: 4, isDefault: false))
        try context.save()

        #expect(try SeedMerge.assignDefaultColorKeysIfNeeded(in: context) == 4)
        let keys = Dictionary(uniqueKeysWithValues: try sorted(context).map { ($0.name, $0.builtInKey) })
        #expect(keys["Yellow"] == "yellow")
        #expect(keys["Pink"] == "rose")
        #expect(keys["Gold"] == "green")
        #expect(keys["Mine"] == "blue")
        let sky = try #require(try sorted(context).first { $0.name == "Sky" })
        #expect(sky.builtInKey == nil)
        #expect(try SeedMerge.assignDefaultColorKeysIfNeeded(in: context) == 0)
    }

    @Test func aLocalDefaultTakesTheKeyASyncedColorAlreadyHolds() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let synced = color("Yellow", key: "yellow", uuid: id(1))
        let local = color("Yellow", key: nil, uuid: id(2), lightHex: "#FFE86B", darkHex: "#6B5B00")
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: local.uuid, quotedText: "Blessed")
        context.insert(synced)
        context.insert(local)
        context.insert(highlight)
        try context.save()

        #expect(try SeedMerge.assignDefaultColorKeysIfNeeded(in: context) == 1)
        #expect(local.builtInKey == "yellow")
        #expect(try SeedMerge.mergeDuplicateColors(in: context) == 1)
        #expect(try context.fetch(FetchDescriptor<HighlightColor>()).map(\.uuid) == [id(1)])
        #expect(highlight.colorID == id(1))
    }

    @Test func mergeAllAssignsKeysFirst() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        for (index, current) in MarkupContainer.defaultColors.enumerated() {
            context.insert(color(current.name, key: MarkupContainer.defaultColorKeys[index], uuid: UUID(),
                                 lightHex: current.lightHex, darkHex: current.darkHex, sortOrder: index))
        }
        for (index, legacy) in MarkupContainer.legacyDefaultColors.enumerated() {
            context.insert(color(legacy.name, key: nil, uuid: UUID(), lightHex: legacy.lightHex, darkHex: legacy.darkHex, sortOrder: index))
        }
        try context.save()

        #expect(try SeedMerge.mergeAll(in: context, seeds: []) > 0)
        let colors = try context.fetch(FetchDescriptor<HighlightColor>())
        #expect(colors.count == 5)
        #expect(Set(colors.compactMap(\.builtInKey)) == Set(MarkupContainer.defaultColorKeys))
        #expect(try SeedMerge.mergeAll(in: context, seeds: []) == 0)
    }

    /// Two imported old stores, one incomplete: the second Yellow waits for "yellow" in a later round
    /// instead of taking a leftover key, so the synced Blue is never renamed.
    @Test func unevenImportedSetsKeepTheirNaturalKeys() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        for (index, current) in MarkupContainer.defaultColors.enumerated() {
            context.insert(color(current.name, key: MarkupContainer.defaultColorKeys[index], uuid: id(index + 1),
                                 lightHex: current.lightHex, darkHex: current.darkHex, sortOrder: index))
        }
        let legacyYellow = MarkupContainer.legacyDefaultColors[0], legacyGreen = MarkupContainer.legacyDefaultColors[1]
        let firstYellow = color(legacyYellow.name, key: nil, uuid: id(6), lightHex: legacyYellow.lightHex, darkHex: legacyYellow.darkHex, sortOrder: 0)
        let green = color(legacyGreen.name, key: nil, uuid: id(7), lightHex: legacyGreen.lightHex, darkHex: legacyGreen.darkHex, sortOrder: 1)
        let secondYellow = color(legacyYellow.name, key: nil, uuid: id(8), lightHex: legacyYellow.lightHex, darkHex: legacyYellow.darkHex, sortOrder: 0)
        context.insert(secondYellow)
        context.insert(green)
        context.insert(firstYellow)
        try context.save()

        #expect(try SeedMerge.assignDefaultColorKeysIfNeeded(in: context) == 3)
        #expect(firstYellow.builtInKey == "yellow")
        #expect(secondYellow.builtInKey == "yellow")
        #expect(green.builtInKey == "green")

        try SeedMerge.mergeAll(in: context, seeds: [])
        let colors = try context.fetch(FetchDescriptor<HighlightColor>())
        #expect(colors.count == 5)
        let blue = try #require(colors.first { $0.uuid == id(3) })
        let defaultBlue = MarkupContainer.defaultColors[2]
        #expect(blue.builtInKey == "blue")
        #expect(blue.name == defaultBlue.name && blue.lightHex == defaultBlue.lightHex && blue.darkHex == defaultBlue.darkHex)
        #expect(try SeedMerge.mergeAll(in: context, seeds: []) == 0)
    }

    @Test func theLowestUUIDSurvivesAndHighlightsFollow() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let a = color("Yellow", key: "yellow", uuid: id(1)), b = color("Yellow", key: "yellow", uuid: id(2))
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: b.uuid, quotedText: "Blessed")
        context.insert(b)
        context.insert(a)
        context.insert(highlight)
        try context.save()

        #expect(try SeedMerge.mergeDuplicateColors(in: context) == 1)
        #expect(try context.fetch(FetchDescriptor<HighlightColor>()).map(\.uuid) == [id(1)])
        #expect(highlight.colorID == id(1))
    }

    @Test func aRenamedDuplicateGivesItsNameToTheSurvivor() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let untouched = color("Yellow", key: "yellow", uuid: id(1), sortOrder: 0)
        let renamed = color("Gold", key: "yellow", uuid: id(2), lightHex: "#F0D060", darkHex: "#5A4A00", sortOrder: 3)
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: renamed.uuid, quotedText: "Blessed")
        context.insert(untouched)
        context.insert(renamed)
        context.insert(highlight)
        try context.save()

        try SeedMerge.mergeDuplicateColors(in: context)
        let colors = try context.fetch(FetchDescriptor<HighlightColor>())
        #expect(colors.count == 1)
        #expect(colors.first?.uuid == id(1))
        #expect(colors.first?.name == "Gold")
        #expect(colors.first?.lightHex == "#F0D060")
        #expect(colors.first?.darkHex == "#5A4A00")
        #expect(colors.first?.sortOrder == 3)
        #expect(highlight.colorID == id(1))
    }

    @Test func mergingTwiceChangesNothing() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(color("Yellow", key: "yellow", uuid: id(1)))
        context.insert(color("Gold", key: "yellow", uuid: id(2), lightHex: "#F0D060", darkHex: "#5A4A00"))
        context.insert(outline(uuid: id(3)))
        context.insert(outline(uuid: id(4)))
        let first = Bookmark(book: "GEN", chapter: 1, verse: 1)
        first.createdAt = Date(timeIntervalSince1970: 1_000)
        let second = Bookmark(book: "GEN", chapter: 1, verse: 1, label: "start")
        second.createdAt = Date(timeIntervalSince1970: 2_000)
        context.insert(first)
        context.insert(second)
        try context.save()

        // colors: the survivor takes Gold and one is deleted (2); prompts: one deleted (1); bookmarks: the survivor takes "start" and one is deleted (2)
        #expect(try SeedMerge.mergeAll(in: context, seeds: [outlineSeed]) == 5)
        #expect(try SeedMerge.mergeAll(in: context, seeds: [outlineSeed]) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HighlightColor>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PromptTemplate>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Bookmark>()) == 1)
    }

    @Test func coloursTheReaderMadeAreNeverMerged() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(color("Sky", key: nil, uuid: id(1), lightHex: "#B8E8FF", darkHex: "#144D6E", sortOrder: 5, isDefault: false))
        context.insert(color("Sky", key: nil, uuid: id(2), lightHex: "#B8E8FF", darkHex: "#144D6E", sortOrder: 6, isDefault: false))
        try context.save()

        #expect(try SeedMerge.assignDefaultColorKeysIfNeeded(in: context) == 0)
        #expect(try SeedMerge.mergeDuplicateColors(in: context) == 0)
        let colors = try sorted(context)
        #expect(colors.map(\.uuid) == [id(1), id(2)])
        #expect(colors.allSatisfy { $0.builtInKey == nil })
    }

    @Test func duplicateBuiltInPromptsMergeAndKeepTheEdit() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let edited = outline(uuid: id(2))
        edited.body = "my outline"
        edited.isEnabled = false
        context.insert(edited)
        context.insert(outline(uuid: id(1)))
        try context.save()

        #expect(try SeedMerge.mergeDuplicateBuiltInPrompts(in: context, seeds: [outlineSeed]) == 2)
        let prompts = try context.fetch(FetchDescriptor<PromptTemplate>())
        #expect(prompts.count == 1)
        #expect(prompts.first?.uuid == id(1))
        #expect(prompts.first?.body == "my outline")
        #expect(prompts.first?.isEnabled == false)
        #expect(try SeedMerge.mergeDuplicateBuiltInPrompts(in: context, seeds: [outlineSeed]) == 0)
    }

    /// Two devices could each delete a different one of two records with one uuid, and a delete
    /// always wins, so a twin of the survivor is left; one with the key and another uuid still goes.
    @Test func sameIdentityColorsAreLeftAlone() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(color("Yellow", key: "yellow", uuid: id(1)))
        context.insert(color("Yellow", key: "yellow", uuid: id(1)))
        context.insert(color("Yellow", key: "yellow", uuid: id(2)))
        try context.save()

        #expect(try SeedMerge.mergeDuplicateColors(in: context) == 1)
        #expect(try context.fetch(FetchDescriptor<HighlightColor>()).map(\.uuid) == [id(1), id(1)])
        #expect(try MarkupStore(container: container).colors().map(\.uuid) == [id(1)])
        #expect(try SeedMerge.mergeDuplicateColors(in: context) == 0)
    }

    @Test func sameIdentityPromptsAreLeftAlone() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(outline(uuid: id(1)))
        context.insert(outline(uuid: id(1)))
        context.insert(outline(uuid: id(2)))
        try context.save()

        #expect(try SeedMerge.mergeDuplicateBuiltInPrompts(in: context, seeds: [outlineSeed]) == 1)
        #expect(try context.fetch(FetchDescriptor<PromptTemplate>()).map(\.uuid) == [id(1), id(1)])
        #expect(try PromptTemplateStore(container: container).templates().map(\.uuid) == [id(1)])
        #expect(try SeedMerge.mergeDuplicateBuiltInPrompts(in: context, seeds: [outlineSeed]) == 0)
    }

    @Test func twoBookmarksOnOneVerseBecomeOne() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let earlier = Bookmark(book: "GEN", chapter: 1, verse: 1)
        earlier.uuid = id(2)
        earlier.createdAt = Date(timeIntervalSince1970: 1_000)
        let later = Bookmark(book: "GEN", chapter: 1, verse: 1, label: "start")
        later.uuid = id(1)
        later.createdAt = Date(timeIntervalSince1970: 2_000)
        let elsewhere = Bookmark(book: "GEN", chapter: 1, verse: 2)
        context.insert(later)
        context.insert(earlier)
        context.insert(elsewhere)
        try context.save()

        #expect(try SeedMerge.mergeDuplicateBookmarks(in: context) == 2)
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.verse)]))
        #expect(bookmarks.map(\.uuid) == [id(2), elsewhere.uuid])
        #expect(bookmarks.first?.label == "start")
        #expect(try SeedMerge.mergeDuplicateBookmarks(in: context) == 0)
    }

    /// Two devices could each delete a different one of two records with one uuid, and a delete
    /// always wins, so a twin of the survivor is left; it is read as one.
    @Test func sameIdentityBookmarksSurviveTheMerge() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        for _ in 0..<2 {
            let twin = Bookmark(book: "GEN", chapter: 1, verse: 1)
            twin.uuid = id(1)
            twin.createdAt = Date(timeIntervalSince1970: 1_000)
            context.insert(twin)
        }
        let first = Bookmark(book: "GEN", chapter: 1, verse: 2)
        first.uuid = id(2)
        first.createdAt = Date(timeIntervalSince1970: 1_000)
        let second = Bookmark(book: "GEN", chapter: 1, verse: 2)
        second.uuid = id(3)
        second.createdAt = Date(timeIntervalSince1970: 2_000)
        context.insert(second)
        context.insert(first)
        try context.save()

        #expect(try SeedMerge.mergeDuplicateBookmarks(in: context) == 1)
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        #expect(bookmarks.filter { $0.verse == 1 }.map(\.uuid) == [id(1), id(1)])
        #expect(bookmarks.filter { $0.verse == 2 }.map(\.uuid) == [id(2)])
        #expect(try SeedMerge.mergeDuplicateBookmarks(in: context) == 0)
    }
}
