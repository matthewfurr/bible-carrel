import Foundation
import OSLog
import ScriptureData
import SwiftData

/// How many records a copy brought in. Notes count under `notes`, conversations (with their
/// turns) under `conversations`, reading plans under `plans`, their ticks under `ticks` and kept
/// versions under `keptVersions`.
public struct RestoreSummary: Equatable, Sendable {
    public var highlights = 0, notes = 0, bookmarks = 0, colors = 0, conversations = 0, prompts = 0, plans = 0, ticks = 0
    public var keptVersions = 0

    public init() {}

    public var total: Int { highlights + notes + bookmarks + colors + conversations + prompts + plans + ticks + keptVersions }
}

/// Copies what one markup store has and another lacks: the one-time import of the old local
/// store, and restoring from a backup. Only adds; never changes or deletes a live record.
public enum StoreCopy {
    /// Copies `source` (and its `-wal` and `-shm`) into a new temporary directory, opens the copy,
    /// inserts into `container` every record it is missing, saves once and removes the temporary
    /// directory. The source file itself is never opened as a store.
    ///
    /// Missing, in this order: a color whose `uuid` is absent; a highlight whose `uuid` is absent
    /// (with its note, unless that note's `uuid` is present); a highlight's note whose `uuid` is
    /// absent and whose highlight is live with no note (attached to it); a chapter note whose
    /// `uuid` is absent; a bookmark whose `uuid` is absent on a verse with no live bookmark; a plan whose
    /// `uuid` is absent; a tick whose `uuid` is absent and whose plan and reading have no live tick; a
    /// thread whose `uuid` is absent (with all its turns); a prompt that is not built in whose
    /// `uuid` is absent; a built-in prompt whose `builtInKey` no live prompt has; a kept version whose
    /// `uuid` is absent and whose note has no live kept version with the same text. A note comes with
    /// its three version values; deletion markers are never copied.
    @MainActor
    public static func copyMissing(from source: URL, into container: ModelContainer) throws -> RestoreSummary {
        try copy(from: source, into: container).summary
    }

    /// `copyMissing`, and the uuids of the notes it brought in.
    @MainActor
    static func copy(from source: URL, into container: ModelContainer) throws -> (summary: RestoreSummary, noteIDs: Set<UUID>) {
        let files = FileManager.default
        let temporary = files.temporaryDirectory.appending(path: "StoreCopy-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: temporary) }

        let copy = temporary.appending(path: source.lastPathComponent)
        try files.copyItem(at: source, to: copy)
        for suffix in ["-wal", "-shm"] {
            let sidecar = URL(filePath: source.path + suffix)
            if files.fileExists(atPath: sidecar.path) {
                try files.copyItem(at: sidecar, to: URL(filePath: copy.path + suffix))
            }
        }
        return try insertMissing(fromStoreAt: copy, into: container.mainContext)
    }

    /// Opens the copy for the length of this call only, so it is closed before its directory goes.
    @MainActor
    private static func insertMissing(fromStoreAt url: URL, into live: ModelContext) throws -> (summary: RestoreSummary, noteIDs: Set<UUID>) {
        let schema = MarkupContainer.schema
        let sourceContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        return try withExtendedLifetime(sourceContainer) {
            let source = sourceContainer.mainContext

            // Read everything first, so nothing is inserted unless every fetch succeeded.
            let sourceColors = try source.fetch(FetchDescriptor<HighlightColor>())
            let sourceHighlights = try source.fetch(FetchDescriptor<Highlight>())
            let sourceNotes = try source.fetch(FetchDescriptor<Note>())
            let sourceBookmarks = try source.fetch(FetchDescriptor<Bookmark>())
            let sourcePlans = try source.fetch(FetchDescriptor<PlanRecord>())
            let sourceTicks = try source.fetch(FetchDescriptor<PlanTick>())
            let sourceThreads = try source.fetch(FetchDescriptor<ChatThread>())
            let sourcePrompts = try source.fetch(FetchDescriptor<PromptTemplate>())
            let sourceVersions = try source.fetch(FetchDescriptor<KeptVersion>())

            var colorIDs = Set(try live.fetch(FetchDescriptor<HighlightColor>()).map(\.uuid))
            var liveHighlights = Dictionary(try live.fetch(FetchDescriptor<Highlight>()).map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
            var noteIDs = Set(try live.fetch(FetchDescriptor<Note>()).map(\.uuid))
            let liveNoteIDs = noteIDs
            let liveBookmarks = try live.fetch(FetchDescriptor<Bookmark>())
            var bookmarkIDs = Set(liveBookmarks.map(\.uuid))
            var bookmarkedVerses = Set(liveBookmarks.map(\.location))
            var planIDs = Set(try live.fetch(FetchDescriptor<PlanRecord>()).map(\.uuid))
            let liveTicks = try live.fetch(FetchDescriptor<PlanTick>())
            var tickIDs = Set(liveTicks.map(\.uuid))
            var tickedReadings = Set(liveTicks.map(TickedReading.init))
            var threadIDs = Set(try live.fetch(FetchDescriptor<ChatThread>()).map(\.uuid))
            let livePrompts = try live.fetch(FetchDescriptor<PromptTemplate>())
            var promptIDs = Set(livePrompts.map(\.uuid))
            var builtInKeys = Set(livePrompts.compactMap(\.builtInKey))
            let liveVersions = try live.fetch(FetchDescriptor<KeptVersion>())
            var versionIDs = Set(liveVersions.map(\.uuid))
            var keptTexts = Dictionary(grouping: liveVersions, by: \.noteID).mapValues { $0.map(\.body) }

            var summary = RestoreSummary()

            for color in sourceColors where !colorIDs.contains(color.uuid) {
                live.insert(copy(color))
                colorIDs.insert(color.uuid)
                summary.colors += 1
            }

            for highlight in sourceHighlights where liveHighlights[highlight.uuid] == nil {
                let inserted = HighlightSnapshot(highlight).make()
                live.insert(inserted)
                liveHighlights[highlight.uuid] = inserted
                summary.highlights += 1
                if let note = highlight.note, !noteIDs.contains(note.uuid) {
                    let insertedNote = copy(note)
                    live.insert(insertedNote)
                    inserted.note = insertedNote
                    noteIDs.insert(note.uuid)
                    summary.notes += 1
                }
            }

            for note in sourceNotes where !noteIDs.contains(note.uuid) {
                guard let anchor = note.highlight else { continue }
                guard let target = liveHighlights[anchor.uuid], target.note == nil else { continue }
                let inserted = copy(note)
                live.insert(inserted)
                target.note = inserted
                noteIDs.insert(note.uuid)
                summary.notes += 1
            }

            for note in sourceNotes where note.highlight == nil && !noteIDs.contains(note.uuid) {
                live.insert(copy(note))
                noteIDs.insert(note.uuid)
                summary.notes += 1
            }

            for bookmark in sourceBookmarks where !bookmarkIDs.contains(bookmark.uuid) && !bookmarkedVerses.contains(bookmark.location) {
                live.insert(copy(bookmark))
                bookmarkIDs.insert(bookmark.uuid)
                bookmarkedVerses.insert(bookmark.location)
                summary.bookmarks += 1
            }

            for plan in sourcePlans where !planIDs.contains(plan.uuid) {
                live.insert(copy(plan))
                planIDs.insert(plan.uuid)
                summary.plans += 1
            }

            for tick in sourceTicks where !tickIDs.contains(tick.uuid) && !tickedReadings.contains(TickedReading(tick)) {
                live.insert(copy(tick))
                tickIDs.insert(tick.uuid)
                tickedReadings.insert(TickedReading(tick))
                summary.ticks += 1
            }

            for thread in sourceThreads where !threadIDs.contains(thread.uuid) {
                let snapshot = ThreadSnapshot(thread)
                let inserted = snapshot.make()
                inserted.scopeRaw = thread.scopeRaw
                live.insert(inserted)
                for (messageSnapshot, message) in zip(snapshot.messages, thread.orderedMessages) {
                    let insertedMessage = messageSnapshot.make()
                    insertedMessage.roleRaw = message.roleRaw
                    live.insert(insertedMessage)
                    insertedMessage.thread = inserted
                }
                threadIDs.insert(thread.uuid)
                summary.conversations += 1
            }

            for prompt in sourcePrompts where !promptIDs.contains(prompt.uuid) {
                if prompt.isBuiltIn, let key = prompt.builtInKey {
                    guard !builtInKeys.contains(key) else { continue }
                    builtInKeys.insert(key)
                }
                live.insert(copy(prompt))
                promptIDs.insert(prompt.uuid)
                summary.prompts += 1
            }

            for version in sourceVersions where !versionIDs.contains(version.uuid) {
                let texts = keptTexts[version.noteID, default: []]
                guard !texts.contains(where: { NoteVersion.sameText($0, version.body) }) else { continue }
                live.insert(KeptVersionSnapshot(version).make())
                versionIDs.insert(version.uuid)
                keptTexts[version.noteID, default: []].append(version.body)
                summary.keptVersions += 1
            }

            guard summary.total > 0 else { return (summary, []) }
            do {
                try live.save()
            } catch {
                live.rollback()
                throw error
            }
            return (summary, noteIDs.subtracting(liveNoteIDs))
        }
    }

    // MARK: - Copies, every stored field (one line per field)

    private static func copy(_ color: HighlightColor) -> HighlightColor {
        let copy = HighlightColor(name: color.name, lightHex: color.lightHex, darkHex: color.darkHex, sortOrder: color.sortOrder, isDefault: color.isDefault)
        copy.uuid = color.uuid
        copy.builtInKey = color.builtInKey
        return copy
    }

    /// `NoteSnapshot` leaves out `sourceThreadID` and reads the scope through its enum.
    private static func copy(_ note: Note) -> Note {
        let copy = NoteSnapshot(note).make()
        copy.scopeRaw = note.scopeRaw
        copy.sourceThreadID = note.sourceThreadID
        return copy
    }

    private static func copy(_ bookmark: Bookmark) -> Bookmark {
        let copy = Bookmark(book: bookmark.book, chapter: bookmark.chapter, verse: bookmark.verse, label: bookmark.label)
        copy.uuid = bookmark.uuid
        copy.createdAt = bookmark.createdAt
        return copy
    }

    private static func copy(_ plan: PlanRecord) -> PlanRecord {
        let copy = PlanRecord()
        copy.uuid = plan.uuid
        copy.title = plan.title
        copy.createdAt = plan.createdAt
        copy.modifiedAt = plan.modifiedAt
        copy.weeksData = plan.weeksData
        return copy
    }

    /// `PlanTick.init` takes a plan and a reading; a stored tick may have neither.
    private static func copy(_ tick: PlanTick) -> PlanTick {
        let copy = PlanTick(planID: UUID(), readingID: UUID(), tickedAt: tick.tickedAt)
        copy.uuid = tick.uuid
        copy.planID = tick.planID
        copy.readingID = tick.readingID
        return copy
    }

    /// A tick's plan and reading. A tick that lacks either matches no other, so it is copied by its uuid alone.
    private struct TickedReading: Hashable {
        let planID: UUID?, readingID: UUID?, orphan: UUID?

        init(_ tick: PlanTick) {
            planID = tick.planID
            readingID = tick.readingID
            orphan = tick.planID == nil || tick.readingID == nil ? tick.uuid : nil
        }
    }

    private static func copy(_ prompt: PromptTemplate) -> PromptTemplate {
        let copy = PromptTemplate(title: prompt.title, summary: prompt.summary, body: prompt.body, scope: prompt.scope, section: prompt.section,
                                  sortOrder: prompt.sortOrder, isBuiltIn: prompt.isBuiltIn, builtInKey: prompt.builtInKey)
        copy.uuid = prompt.uuid
        copy.scopeRaw = prompt.scopeRaw
        copy.sectionRaw = prompt.sectionRaw
        copy.isEnabled = prompt.isEnabled
        copy.outputKind = prompt.outputKind
        return copy
    }
}

extension MarkupStore {
    /// Restore from a backup: `StoreCopy.copyMissing` into this store, then each note it brought
    /// back is treated as an undone delete is (`restoreText`): its text journaled as this device's
    /// (a blank one is not) and its markers naming that text deleted, saved straight after the
    /// copy. A note already here is untouched; a kept version brought back is not journaled. A
    /// failure of the second save is logged and rolled back, and the copy stands.
    public func restoreMissing(fromBackup url: URL) throws -> RestoreSummary {
        let copied = try StoreCopy.copy(from: url, into: container)
        guard !copied.noteIDs.isEmpty else { return copied.summary }
        do {
            for id in copied.noteIDs {
                guard let note = try note(id: id) else { continue }
                try restoreText(of: note, on: note.highlight)
            }
            try context.save()
        } catch {
            context.rollback()
            logger.error("settling restored notes failed: \(error.localizedDescription, privacy: .public)")
        }
        return copied.summary
    }
}

/// Brings the old local store into the synced one, once.
public enum LegacyImport {
    /// Nil when the location has no old store, the file is absent, or the marker says it was
    /// already imported. Otherwise copies what is missing, writes the marker (the ISO 8601 date)
    /// and returns the summary. A failed copy writes no marker.
    @MainActor
    public static func importIfNeeded(_ location: StoreLocation, into container: ModelContainer) throws -> RestoreSummary? {
        let files = FileManager.default
        guard let legacy = location.legacyStoreURL,
              files.fileExists(atPath: legacy.path),
              !files.fileExists(atPath: location.legacyMarkerURL.path)
        else { return nil }
        let summary = try StoreCopy.copyMissing(from: legacy, into: container)
        try files.createDirectory(at: location.legacyMarkerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(Date.now.ISO8601Format().utf8).write(to: location.legacyMarkerURL, options: .atomic)
        return summary
    }
}
