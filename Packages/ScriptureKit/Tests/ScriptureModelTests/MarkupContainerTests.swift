import Foundation
import ScriptureData
import SwiftData
import Testing
@testable import ScriptureModel

@MainActor @Suite struct MarkupContainerTests {
    @Test func inMemoryContainerStoresAndFetchesAHighlightWithItsNote() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed")
        highlight.note = Note(body: "first", scope: .highlight, book: "MAT", chapter: 5, verse: 3, endVerse: 3, translationID: "ESV", quotedText: "Blessed")
        context.insert(highlight)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Highlight>())
        #expect(fetched.count == 1)
        #expect(fetched[0].location == VerseLocation(book: "MAT", chapter: 5, verse: 3))
        #expect(fetched[0].note?.body == "first")
        #expect(fetched[0].note?.highlight === fetched[0])
        #expect(fetched[0].isEmpty == false)
    }

    @Test func deletingAHighlightCascadesToItsNote() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: nil, quotedText: "Blessed")
        highlight.note = Note(body: "x", scope: .highlight, book: "MAT", chapter: 5, verse: 3, endVerse: 3, translationID: "ESV", quotedText: "Blessed")
        context.insert(highlight)
        try context.save()
        context.delete(highlight)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Note>()).isEmpty)
    }

    @Test func seedingAddsFiveDefaultColorsOnce() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        try MarkupContainer.seedDefaultColorsIfNeeded(in: context)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: context)
        let colors = try context.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(colors.map(\.name) == ["Yellow", "Green", "Blue", "Rose", "Orange"])
        #expect(colors.map(\.sortOrder) == [0, 1, 2, 3, 4])
        #expect(colors.filter { $0.isDefault }.count == 5)
        #expect(colors[0].lightHex == "#F8E18A" && colors[0].darkHex == "#554704")
    }

    @Test func seededColorsCarryTheirKeys() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        try MarkupContainer.seedDefaultColorsIfNeeded(in: context)
        let colors = try context.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(colors.map(\.builtInKey) == MarkupContainer.defaultColorKeys)
        #expect(MarkupContainer.defaultColorKeys == ["yellow", "green", "blue", "rose", "orange"])
    }

    /// A store seeded before the new palette: untouched defaults move to the new values (Pink
    /// becomes Rose), while a renamed default, a recolored default and a user color stay as they are.
    @Test func migrationMovesOnlyUntouchedLegacyDefaults() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        for (index, legacy) in MarkupContainer.legacyDefaultColors.enumerated() {
            context.insert(HighlightColor(name: legacy.name, lightHex: legacy.lightHex, darkHex: legacy.darkHex, sortOrder: index, isDefault: true))
        }
        context.insert(HighlightColor(name: "Mine", lightHex: "#FFE86B", darkHex: "#6B5B00", sortOrder: 5, isDefault: false))
        try context.save()
        let colors = try context.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
        colors[1].name = "Hope"                 // renamed: left alone
        colors[2].darkHex = "#000080"           // recolored: left alone
        let keptID = colors[0].uuid
        try context.save()

        #expect(try MarkupContainer.migrateDefaultColorsIfNeeded(in: context) == 3)
        let after = try context.fetch(FetchDescriptor<HighlightColor>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(after.map(\.name) == ["Yellow", "Hope", "Blue", "Rose", "Orange", "Mine"])
        #expect(after[0].uuid == keptID && after[0].lightHex == "#F8E18A" && after[0].darkHex == "#554704")
        #expect(after[1].lightHex == "#B5F0B0")
        #expect(after[2].lightHex == "#B9DDFF" && after[2].darkHex == "#000080")
        #expect(after[3].lightHex == "#FFCFE8" && after[4].darkHex == "#683B18")
        #expect(after[5].lightHex == "#FFE86B")
        #expect(try MarkupContainer.migrateDefaultColorsIfNeeded(in: context) == 0)
    }

    @Test func launchConformsStoredColorsOutsideTheBandOnce() throws {
        let container = try MarkupContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(HighlightColor(name: "Old", lightHex: "#1F4C7A", darkHex: "#FFFFFF", sortOrder: 9, isDefault: false))
        try context.save()
        #expect(try MarkupContainer.conformColorsIfNeeded(in: context) == 1)
        #expect(try MarkupContainer.conformColorsIfNeeded(in: context) == 0)
        let old = try context.fetch(FetchDescriptor<HighlightColor>()).first { $0.name == "Old" }!
        #expect(MarkLightness.isInBand(hex: old.lightHex, dark: false))
        #expect(MarkLightness.isInBand(hex: old.darkHex, dark: true))
    }

    /// A predicate fetch needs the container alive; `MarkupStore` keeps it so, and this pins that a
    /// store outliving the caller's container reference still fetches.
    @Test func predicateFetchWorksThroughAStoreThatOwnsItsContainer() throws {
        func makeStore() throws -> MarkupStore { MarkupStore(container: try MarkupContainer.make(inMemory: true)) }
        let store = try makeStore()
        store.context.insert(Bookmark(book: "MAT", chapter: 5, verse: 9))
        try store.context.save()
        #expect(try store.context.fetchCount(FetchDescriptor<Bookmark>(predicate: #Predicate { $0.verse == 9 })) == 1)
    }

    @Test func aStoreOnDiskOpensWhereTheLocationSays() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: support) }
        let location = StoreLocation.resolve(sync: nil, applicationSupport: support)
        let container = try MarkupContainer.make(at: location, sync: nil)
        container.mainContext.insert(Bookmark(book: "GEN", chapter: 1, verse: 1))
        try container.mainContext.save()
        #expect(FileManager.default.fileExists(atPath: location.storeURL.path))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()) == 1)
    }

    /// Spec 7 (plans) and keeping data safe 6: every value optional or defaulted, nothing unique, no relationship.
    @Test func theNewKindsObeyTheStoresRules() throws {
        #expect(MarkupContainer.models.count == 11 && MarkupContainer.schema.entities.count == 11)
        let entities = MarkupContainer.schema.entities.filter { ["PlanRecord", "PlanTick", "KeptVersion", "DeletionMarker"].contains($0.name) }
        #expect(entities.count == 4)
        for entity in entities {
            #expect(entity.uniquenessConstraints.isEmpty && entity.relationships.isEmpty)
            for attribute in entity.attributes {
                #expect(!attribute.isUnique && (attribute.isOptional || attribute.defaultValue != nil), "\(entity.name).\(attribute.name)")
            }
        }
        let note = try #require(MarkupContainer.schema.entities.first { $0.name == "Note" })
        for name in ["versionMark", "versionAncestry", "deviceKind"] {
            let attribute = try #require(note.attributes.first { $0.name == name }, "Note.\(name)")
            #expect(attribute.isOptional && !attribute.isUnique, "Note.\(name)")
        }
    }

    /// Keeping data safe 6: the two kinds and the note's three values are added by the store itself the first time this build opens it.
    @Test func aStoreFromBeforeKeptVersionsOpensAndKeepsItsNotes() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: "MarkupContainerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: support) }
        let location = StoreLocation.resolve(sync: nil, storeName: "Old", applicationSupport: support)
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        let noteID: UUID
        do {
            let nine = Schema(Array(MarkupContainer.models.prefix(9)))
            #expect(!nine.entities.contains { ["KeptVersion", "DeletionMarker"].contains($0.name) })
            let old = try ModelContainer(for: nine, configurations: [ModelConfiguration(schema: nine, url: location.storeURL, cloudKitDatabase: .none)])
            let note = Note(body: "in the beginning", scope: .chapter, book: "GEN", chapter: 1, verse: 0, endVerse: 0, translationID: "WEB", quotedText: "")
            noteID = note.uuid
            old.mainContext.insert(note)
            try old.mainContext.save()
        }
        let container = try MarkupContainer.make(at: location, sync: nil)
        let notes = try container.mainContext.fetch(FetchDescriptor<Note>())
        #expect(notes.count == 1 && notes.first?.uuid == noteID && notes.first?.body == "in the beginning")
        #expect(notes.first?.versionMark == nil && notes.first?.versionAncestry == nil && notes.first?.deviceKind == nil)
        let kept = KeptVersion()
        kept.noteID = noteID
        kept.body = "earlier"
        container.mainContext.insert(kept)
        try container.mainContext.save()
        let fetched = try container.mainContext.fetch(FetchDescriptor<KeptVersion>())
        #expect(fetched.count == 1 && fetched.first?.noteID == noteID && fetched.first?.body == "earlier")
    }

    /// Spec 7: adding the two kinds is a change the store makes by itself the first time the new build opens it.
    @Test func aStoreFromBeforePlansOpensAndKeepsItsMarks() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: "MarkupContainerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: support) }
        let location = StoreLocation.resolve(sync: nil, storeName: "Old", applicationSupport: support)
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        do {
            let seven = Schema([Highlight.self, Note.self, Bookmark.self, HighlightColor.self, ChatThread.self, ChatMessage.self, PromptTemplate.self])
            let old = try ModelContainer(for: seven, configurations: [ModelConfiguration(schema: seven, url: location.storeURL, cloudKitDatabase: .none)])
            old.mainContext.insert(Bookmark(book: "GEN", chapter: 1, verse: 1))
            try old.mainContext.save()
        }
        let container = try MarkupContainer.make(at: location, sync: nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()) == 1)
        let store = PlanStore(container: container)
        try store.save(PlanSample.gen1Shaped())
        #expect(try store.plans().count == 1)
    }

    @Test func noteScopeRoundTripsThroughRawValue() {
        let note = Note(body: "", scope: .chapter, book: "MAT", chapter: 5, verse: 1, endVerse: 1, translationID: "ESV", quotedText: "")
        #expect(note.scopeRaw == "chapter")
        note.scope = .verseRange
        #expect(note.scope == .verseRange)
    }
}
