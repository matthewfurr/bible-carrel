import Foundation
import ScriptureData
import SwiftData

/// What an import did. Every record of the file is counted once: added, kept as a version, or already here.
public struct ImportSummary: Equatable, Sendable {
    /// By kind; `keptVersions` counts the file's kept versions that were added.
    public var added = RestoreSummary()
    /// Notes here already, or on a highlight that already has a note, that gained the file's text as a kept version.
    public var versionsKept = 0
    /// Records of the file neither added nor kept; a conversation counts once.
    public var alreadyHere = 0

    public init() {}
}

/// Reads a `DataFile` back into the store (spec 5.2): what the store lacks is added with its
/// identity and every fact the file holds; nothing here is changed or deleted. "Here already" is
/// judged as the store merges: a colour by its uuid or built-in key, a highlight, note, plan or
/// conversation by its uuid, a bookmark by its uuid or verse, a tick by its uuid or its plan and
/// reading, a built-in prompt by its key and another by its uuid, a kept version by its uuid or a
/// same text on its note. A note here whose text differs from the file's, without sight of it,
/// gains the file's text as a kept version; so does the note on a highlight that already carries
/// another (Departure 9). A note added is treated as an undone delete is: its text is journaled as
/// this device's and its markers naming that text go in the import's save.
public enum DataImport {
    /// Adds what the store lacks; never changes or deletes a record. One save; a failure rolls back and throws.
    @MainActor public static func apply(_ file: DataFile, to store: MarkupStore) throws -> ImportSummary {
        let pass = try ImportPass(store: store)
        return try pass.run(file)
    }
}

/// One import: everything the store holds is read before anything is inserted.
@MainActor private final class ImportPass {
    private let store: MarkupStore
    private var context: ModelContext { store.context }
    private var summary = ImportSummary()

    private var colorIDs: Set<UUID>
    private var colorsByKey: [String: UUID]
    /// A file colour here under another uuid, to the live colour's uuid.
    private var colorFor: [UUID: UUID] = [:]
    private var highlights: [UUID: Highlight]
    private var notes: [UUID: Note]
    private var keptIDs: Set<UUID>
    private var keptTexts: [UUID?: [String]]
    private var bookmarkIDs: Set<UUID>
    private var bookmarkedVerses: Set<VerseLocation>
    private var planIDs: Set<UUID>
    private var tickIDs: Set<UUID>
    private var tickedReadings: Set<[UUID]>
    private var threadIDs: Set<UUID>
    private var promptIDs: Set<UUID>
    private var builtInKeys: Set<String>
    private var addedNotes: [Note] = []

    init(store: MarkupStore) throws {
        self.store = store
        let context = store.context
        let colors = try context.fetch(FetchDescriptor<HighlightColor>())
        colorIDs = Set(colors.map(\.uuid))
        colorsByKey = Dictionary(colors.compactMap { color in color.builtInKey.map { ($0, color.uuid) } }, uniquingKeysWith: { first, _ in first })
        highlights = Dictionary(try store.allHighlights().map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        notes = Dictionary(try store.allNotes().map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let versions = try context.fetch(FetchDescriptor<KeptVersion>())
        keptIDs = Set(versions.map(\.uuid))
        keptTexts = Dictionary(grouping: versions, by: \.noteID).mapValues { $0.map(\.body) }
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        bookmarkIDs = Set(bookmarks.map(\.uuid))
        bookmarkedVerses = Set(bookmarks.map(\.location))
        planIDs = Set(try context.fetch(FetchDescriptor<PlanRecord>()).map(\.uuid))
        let ticks = try context.fetch(FetchDescriptor<PlanTick>())
        tickIDs = Set(ticks.map(\.uuid))
        tickedReadings = Set(ticks.compactMap(Self.reading))
        threadIDs = Set(try context.fetch(FetchDescriptor<ChatThread>()).map(\.uuid))
        let prompts = try context.fetch(FetchDescriptor<PromptTemplate>())
        promptIDs = Set(prompts.map(\.uuid))
        builtInKeys = Set(prompts.compactMap(\.builtInKey))
    }

    func run(_ file: DataFile) throws -> ImportSummary {
        var journaled: [(UUID, LastText?)] = []
        do {
            for color in file.colors { add(color) }
            for highlight in file.highlights { add(highlight) }
            for note in file.notes { add(note) }
            for version in file.keptVersions { add(version) }
            for bookmark in file.bookmarks { add(bookmark) }
            for plan in file.plans { try add(plan) }
            for tick in file.ticks { add(tick) }
            for conversation in file.conversations { add(conversation) }
            for prompt in file.prompts { add(prompt) }
            for note in addedNotes {
                journaled.append((note.uuid, store.journal.entry(for: note.uuid)))
                try store.restoreText(of: note, on: note.highlight)
            }
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            for (noteID, entry) in journaled {
                if let entry { try? store.journal.record(entry) } else { store.journal.forget(noteID) }
            }
            throw error
        }
        return summary
    }

    // MARK: - Each kind, in the rules' order

    private func add(_ color: DataFile.Color) {
        if colorIDs.contains(color.id) { return here() }
        if let key = color.builtInKey, let live = colorsByKey[key] {
            colorFor[color.id] = live
            return here()
        }
        let record = HighlightColor(name: color.name, lightHex: color.lightHex, darkHex: color.darkHex, sortOrder: color.sortOrder, isDefault: color.isDefault)
        record.uuid = color.id
        record.builtInKey = color.builtInKey
        context.insert(record)
        colorIDs.insert(color.id)
        if let key = color.builtInKey { colorsByKey[key] = color.id }
        summary.added.colors += 1
    }

    private func add(_ highlight: DataFile.Highlight) {
        guard highlights[highlight.id] == nil else { return here() }
        let record = Highlight(
            book: highlight.book, chapter: highlight.chapter, verse: highlight.verse, endVerse: highlight.endVerse,
            startOffset: highlight.startOffset, endOffset: highlight.endOffset, translationID: highlight.translationID,
            colorID: highlight.colorID.map { colorFor[$0] ?? $0 }, quotedText: highlight.quotedText)
        record.uuid = highlight.id
        record.createdAt = highlight.createdAt
        record.modifiedAt = highlight.modifiedAt
        context.insert(record)
        highlights[highlight.id] = record
        summary.added.highlights += 1
    }

    private func add(_ note: DataFile.Note) {
        if let live = notes[note.id] { return keep(note, on: live) }
        let anchor = note.highlightID.flatMap { highlights[$0] }
        if let other = anchor?.note { return keep(note, on: notes[other.uuid] ?? other) }
        let record = Note(body: note.body, scope: .highlight, book: note.book, chapter: note.chapter, verse: note.verse, endVerse: note.endVerse,
                          translationID: note.translationID, quotedText: note.quotedText)
        record.uuid = note.id
        record.scopeRaw = note.scope
        record.createdAt = note.createdAt
        record.modifiedAt = note.modifiedAt
        record.sourceThreadID = note.sourceThreadID
        record.versionMark = note.versionMark
        record.versionAncestry = note.versionAncestry
        record.deviceKind = note.deviceKind
        context.insert(record)
        anchor?.note = record
        notes[note.id] = record
        addedNotes.append(record)
        summary.added.notes += 1
    }

    /// The file's text as a kept version of `live` (its date and kind, the note's place), unless it
    /// is blank, the note was made with sight of it, or a kept version of the note already has it.
    private func keep(_ note: DataFile.Note, on live: Note) {
        let writer = NoteVersion.writer(text: note.body, mark: note.versionMark, ancestry: note.versionAncestry)
        let seen = NoteVersion.hasSight(of: note.body, writtenBy: writer, noteText: live.body, mark: live.versionMark, ancestry: live.versionAncestry)
        let kept = keptTexts[live.uuid, default: []].contains { NoteVersion.sameText($0, note.body) }
        guard !NoteVersion.isBlank(note.body), !seen, !kept else { return here() }
        let version = store.keptVersion(of: live)
        version.body = note.body
        version.writtenAt = note.modifiedAt
        version.deviceKind = note.deviceKind ?? ""
        context.insert(version)
        keptIDs.insert(version.uuid)
        keptTexts[live.uuid, default: []].append(note.body)
        summary.versionsKept += 1
    }

    private func add(_ version: DataFile.KeptVersion) {
        let sameText = keptTexts[version.noteID, default: []].contains { NoteVersion.sameText($0, version.body) }
        let noteText = version.noteID.flatMap { notes[$0] }.map { NoteVersion.sameText($0.body, version.body) } ?? false
        guard !keptIDs.contains(version.id), !sameText, !noteText else { return here() }
        let record = KeptVersion()
        record.uuid = version.id
        record.noteID = version.noteID
        record.body = version.body
        record.writtenAt = version.writtenAt
        record.deviceKind = version.deviceKind
        record.book = version.book
        record.chapter = version.chapter
        record.verse = version.verse
        record.endVerse = version.endVerse
        record.translationID = version.translationID
        record.quotedText = version.quotedText
        record.startOffset = version.startOffset
        record.endOffset = version.endOffset
        context.insert(record)
        keptIDs.insert(version.id)
        keptTexts[version.noteID, default: []].append(version.body)
        summary.added.keptVersions += 1
    }

    private func add(_ bookmark: DataFile.Bookmark) {
        let location = VerseLocation(book: bookmark.book, chapter: bookmark.chapter, verse: bookmark.verse)
        guard !bookmarkIDs.contains(bookmark.id), !bookmarkedVerses.contains(location) else { return here() }
        let record = Bookmark(book: bookmark.book, chapter: bookmark.chapter, verse: bookmark.verse, label: bookmark.label)
        record.uuid = bookmark.id
        record.createdAt = bookmark.createdAt
        context.insert(record)
        bookmarkIDs.insert(bookmark.id)
        bookmarkedVerses.insert(location)
        summary.added.bookmarks += 1
    }

    /// The weeks as written, whatever their `"v"`: one from a newer coding is listed as unreadable and never written over.
    private func add(_ plan: DataFile.Plan) throws {
        guard !planIDs.contains(plan.id) else { return here() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let record = PlanRecord()
        record.uuid = plan.id
        record.title = plan.title
        record.createdAt = plan.createdAt
        record.modifiedAt = plan.modifiedAt
        record.weeksData = try encoder.encode(plan.weeks)
        context.insert(record)
        planIDs.insert(plan.id)
        summary.added.plans += 1
    }

    private func add(_ tick: DataFile.Tick) {
        let reading = Self.reading(planID: tick.planID, readingID: tick.readingID)
        guard !tickIDs.contains(tick.id), !(reading.map(tickedReadings.contains) ?? false) else { return here() }
        let record = PlanTick(planID: UUID(), readingID: UUID(), tickedAt: tick.tickedAt)
        record.uuid = tick.id
        record.planID = tick.planID
        record.readingID = tick.readingID
        context.insert(record)
        tickIDs.insert(tick.id)
        if let reading { tickedReadings.insert(reading) }
        summary.added.ticks += 1
    }

    private func add(_ conversation: DataFile.Conversation) {
        guard !threadIDs.contains(conversation.id) else { return here() }
        let thread = ChatThread(
            scope: .chapter, book: conversation.book, chapter: conversation.chapter, verse: conversation.verse,
            endVerse: conversation.endVerse, startOffset: conversation.startOffset, endOffset: conversation.endOffset,
            translationID: conversation.translationID, quotedText: conversation.quotedText, title: conversation.title)
        thread.uuid = conversation.id
        thread.scopeRaw = conversation.scope
        thread.createdAt = conversation.createdAt
        thread.updatedAt = conversation.updatedAt
        context.insert(thread)
        for message in conversation.messages {
            let record = ChatMessage(role: .user, content: message.content, providerID: message.providerID, modelName: message.modelName,
                                     attachedReference: message.attachedReference)
            record.uuid = message.id
            record.roleRaw = message.role
            record.createdAt = message.createdAt
            record.displayText = message.displayText
            record.providerHost = message.providerHost
            record.finishReason = message.finishReason
            record.savedNoteID = message.savedNoteID
            context.insert(record)
            record.thread = thread
        }
        threadIDs.insert(conversation.id)
        summary.added.conversations += 1
    }

    private func add(_ prompt: DataFile.Prompt) {
        guard !promptIDs.contains(prompt.id) else { return here() }
        if prompt.isBuiltIn, let key = prompt.builtInKey, builtInKeys.contains(key) { return here() }
        let record = PromptTemplate(title: prompt.title, summary: prompt.summary, body: prompt.body, scope: .chapter, section: .custom,
                                    sortOrder: prompt.sortOrder, isBuiltIn: prompt.isBuiltIn, builtInKey: prompt.builtInKey)
        record.uuid = prompt.id
        record.scopeRaw = prompt.scope
        record.sectionRaw = prompt.section
        record.isEnabled = prompt.isEnabled
        record.outputKind = prompt.outputKind
        context.insert(record)
        promptIDs.insert(prompt.id)
        if let key = prompt.builtInKey { builtInKeys.insert(key) }
        summary.added.prompts += 1
    }

    // MARK: - Helpers

    private func here() { summary.alreadyHere += 1 }

    /// A tick's plan and reading; nil when it lacks either, so it matches by its uuid alone.
    private static func reading(planID: UUID?, readingID: UUID?) -> [UUID]? {
        guard let planID, let readingID else { return nil }
        return [planID, readingID]
    }

    private static func reading(_ tick: PlanTick) -> [UUID]? { reading(planID: tick.planID, readingID: tick.readingID) }
}
