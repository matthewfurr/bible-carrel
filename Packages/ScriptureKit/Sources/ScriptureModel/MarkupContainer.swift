import Foundation
import SwiftData

/// Builds the SwiftData container for user markup: local only (`make(inMemory:)`), or at a
/// `StoreLocation` mirrored to CloudKit when the build carries a `SyncConfiguration`.
public enum MarkupContainer {
    public static let cloudKitContainerIdentifier = "iCloud.com.matthewfurr.ReadingThroughScripture"
    /// The Debug build's own container, so testing never touches the real one.
    public static let developmentContainerIdentifier = "iCloud.com.matthewfurr.ReadingThroughScripture.dev"

    /// The eleven markup models: the seven of the marks and the assistant, a reading plan and its
    /// ticks, then a note's kept versions and the markers its deletes leave.
    public static let models: [any PersistentModel.Type] = [
        Highlight.self, Note.self, Bookmark.self, HighlightColor.self, ChatThread.self, ChatMessage.self, PromptTemplate.self,
        PlanRecord.self, PlanTick.self,
        KeptVersion.self, DeletionMarker.self,
    ]

    /// Of `models`, shared by every container this type makes.
    public static let schema = Schema(models)

    /// `~/Library/Application Support/ReadingThroughScripture/Markup.store` (the app is not sandboxed).
    public static var storeURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "ReadingThroughScripture", directoryHint: .isDirectory)
            .appending(path: "Markup.store")
    }

    /// Keep the returned container alive for as long as its contexts are used: `ModelContext` does
    /// not retain its container, and a `#Predicate` fetch on a context whose container has been
    /// released traps inside SwiftData (EXC_BREAKPOINT, no message). `MarkupStore` owns it for the app.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        }
        let url = storeURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
    }

    /// Opens the store at `location.storeURL`, creating its directory, mirrored to the private
    /// database of `sync.containerIdentifier` when there is one and local only when not. The same
    /// lifetime rule as `make(inMemory:)` applies.
    public static func make(at location: StoreLocation, sync: SyncConfiguration?) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        let database: ModelConfiguration.CloudKitDatabase = sync.map { .private($0.containerIdentifier) } ?? .none
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: location.storeURL, cloudKitDatabase: database)])
    }

    /// The five starting colors, in sort order (DESIGN.md › Marks). All five sit at one OKLCH
    /// lightness (0.91 light, 0.40 dark) so no highlight is louder than another, and primary ink
    /// keeps above 11:1 on each in light mode and 7:1 in dark.
    public static let defaultColors: [(name: String, lightHex: String, darkHex: String)] = [
        ("Yellow", "#F8E18A", "#554704"),
        ("Green", "#BCF2BD", "#2E522F"),
        ("Blue", "#B8E8FF", "#144D6E"),
        ("Rose", "#FFCFE8", "#67344E"),
        ("Orange", "#FFD0A1", "#683B18"),
    ]

    /// Each default color's `builtInKey`, parallel to `defaultColors` and `legacyDefaultColors`.
    public static let defaultColorKeys = ["yellow", "green", "blue", "rose", "orange"]

    /// The defaults seeded before the Study Carrel palette, in the same order as `defaultColors`.
    /// A stored default still exactly at one of these is migrated; anything edited is left alone.
    public static let legacyDefaultColors: [(name: String, lightHex: String, darkHex: String)] = [
        ("Yellow", "#FFE86B", "#6B5B00"),
        ("Green", "#B5F0B0", "#1F5A2A"),
        ("Blue", "#B9DDFF", "#1F4C7A"),
        ("Pink", "#FFC7DE", "#7A2E55"),
        ("Orange", "#FFD3A3", "#7A4A1F"),
    ]

    /// Inserts the default colors, each with its `defaultColorKeys` key, when the table is empty;
    /// a no-op otherwise.
    @MainActor
    public static func seedDefaultColorsIfNeeded(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<HighlightColor>()) == 0 else { return }
        for (index, color) in defaultColors.enumerated() {
            let seeded = HighlightColor(name: color.name, lightHex: color.lightHex, darkHex: color.darkHex, sortOrder: index, isDefault: true)
            seeded.builtInKey = defaultColorKeys[index]
            context.insert(seeded)
        }
        try context.save()
    }

    /// Moves each default color the reader never changed onto its new value: same record (so its
    /// highlights keep it), new hex pair, and the new name only where the old name is untouched.
    /// A default whose name or either hex differs from the legacy value is left exactly as it is.
    /// Returns how many colors changed; running it again changes nothing.
    @MainActor @discardableResult
    public static func migrateDefaultColorsIfNeeded(in context: ModelContext) throws -> Int {
        var changed = 0
        for color in try context.fetch(FetchDescriptor<HighlightColor>()) where color.isDefault {
            guard let index = legacyDefaultColors.firstIndex(where: {
                $0.name == color.name
                    && $0.lightHex.caseInsensitiveCompare(color.lightHex) == .orderedSame
                    && $0.darkHex.caseInsensitiveCompare(color.darkHex) == .orderedSame
            }) else { continue }
            let target = defaultColors[index]
            color.name = target.name
            color.lightHex = target.lightHex
            color.darkHex = target.darkHex
            changed += 1
        }
        if changed > 0 { try context.save() }
        return changed
    }

    /// Holds every stored color to the marks' lightness band (`MarkLightness`), defaults and the
    /// reader's own alike. A variant already in band is left exactly as it is; one outside it is
    /// rewritten in place (same record, so its highlights keep it). Returns how many colors
    /// changed; running it again changes nothing.
    @MainActor @discardableResult
    public static func conformColorsIfNeeded(in context: ModelContext) throws -> Int {
        var changed = 0
        for color in try context.fetch(FetchDescriptor<HighlightColor>()) {
            let light = MarkLightness.isInBand(hex: color.lightHex, dark: false)
                ? color.lightHex : MarkLightness.conformed(hex: color.lightHex, dark: false)
            let dark = MarkLightness.isInBand(hex: color.darkHex, dark: true)
                ? color.darkHex : MarkLightness.conformed(hex: color.darkHex, dark: true)
            guard light != color.lightHex || dark != color.darkHex else { continue }
            color.lightHex = light
            color.darkHex = dark
            changed += 1
        }
        if changed > 0 { try context.save() }
        return changed
    }
}
