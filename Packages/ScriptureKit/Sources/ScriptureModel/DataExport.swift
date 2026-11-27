import Foundation
import ScriptureData
import SwiftData

/// Writes everything the reader has made as a `DataFile`. Reads through the store's list reads, so
/// two records sharing a uuid are written once. Deletion markers, the API key and preferences are
/// not in it; a kept version is, with any that has no note.
public enum DataExport {
    @MainActor
    public static func file(from store: MarkupStore, includesConversations: Bool, app: String, now: Date = Date()) throws -> DataFile {
        let context = store.context
        let ms = DataDates.milliseconds
        func byDate<Record>(_ records: [Record], _ date: (Record) -> Date, _ id: (Record) -> UUID) -> [Record] {
            records.sorted { (date($0), id($0).uuidString) < (date($1), id($1).uuidString) }
        }

        var file = DataFile(exportedAt: ms(now), app: app)

        file.colors = try store.colors().sorted { ($0.sortOrder, $0.uuid.uuidString) < ($1.sortOrder, $1.uuid.uuidString) }.map {
            DataFile.Color(id: $0.uuid, name: $0.name, lightHex: $0.lightHex, darkHex: $0.darkHex,
                           sortOrder: $0.sortOrder, isDefault: $0.isDefault, builtInKey: $0.builtInKey)
        }
        file.highlights = byDate(try store.allHighlights(), { $0.createdAt }, { $0.uuid }).map {
            DataFile.Highlight(id: $0.uuid, book: $0.book, chapter: $0.chapter, verse: $0.verse, endVerse: $0.endVerse,
                               startOffset: $0.startOffset, endOffset: $0.endOffset, translationID: $0.translationID,
                               colorID: $0.colorID, quotedText: $0.quotedText, createdAt: ms($0.createdAt), modifiedAt: ms($0.modifiedAt))
        }
        file.notes = byDate(try store.allNotes(), { $0.createdAt }, { $0.uuid }).map {
            DataFile.Note(id: $0.uuid, body: $0.body, createdAt: ms($0.createdAt), modifiedAt: ms($0.modifiedAt), scope: $0.scopeRaw,
                          book: $0.book, chapter: $0.chapter, verse: $0.verse, endVerse: $0.endVerse,
                          translationID: $0.translationID, quotedText: $0.quotedText, highlightID: $0.highlight?.uuid,
                          sourceThreadID: $0.sourceThreadID, versionMark: $0.versionMark,
                          versionAncestry: $0.versionAncestry, deviceKind: $0.deviceKind)
        }
        let kept = Twins.firsts(try context.fetch(FetchDescriptor<KeptVersion>()), id: \.uuid)
        file.keptVersions = byDate(kept, { $0.writtenAt }, { $0.uuid }).map {
            DataFile.KeptVersion(id: $0.uuid, noteID: $0.noteID, body: $0.body, writtenAt: ms($0.writtenAt), deviceKind: $0.deviceKind,
                                 book: $0.book, chapter: $0.chapter, verse: $0.verse, endVerse: $0.endVerse,
                                 translationID: $0.translationID, quotedText: $0.quotedText,
                                 startOffset: $0.startOffset, endOffset: $0.endOffset)
        }
        file.bookmarks = byDate(try store.allBookmarks(), { $0.createdAt }, { $0.uuid }).map {
            DataFile.Bookmark(id: $0.uuid, book: $0.book, chapter: $0.chapter, verse: $0.verse, createdAt: ms($0.createdAt), label: $0.label)
        }
        file.prompts = try PromptTemplateStore(container: store.container).templates()
            .sorted { ($0.sortOrder, $0.uuid.uuidString) < ($1.sortOrder, $1.uuid.uuidString) }.map {
                DataFile.Prompt(id: $0.uuid, title: $0.title, summary: $0.summary, body: $0.body, scope: $0.scopeRaw,
                                section: $0.sectionRaw, isEnabled: $0.isEnabled, sortOrder: $0.sortOrder,
                                isBuiltIn: $0.isBuiltIn, builtInKey: $0.builtInKey, outputKind: $0.outputKind)
            }
        // A plan's twins are one plan, as the latest `modifiedAt` has it (`PlanStore.plans()`).
        let records = Twins.firsts(try context.fetch(FetchDescriptor<PlanRecord>()), id: \.uuid, prefer: { $0.modifiedAt > $1.modifiedAt })
        file.plans = byDate(records, { $0.createdAt }, { $0.uuid }).compactMap { record in
            guard let weeks = try? JSONDecoder().decode(JSONValue.self, from: record.weeksData) else { return nil }
            return DataFile.Plan(id: record.uuid, title: record.title, createdAt: ms(record.createdAt), modifiedAt: ms(record.modifiedAt), weeks: weeks)
        }
        let ticks = Twins.firsts(try context.fetch(FetchDescriptor<PlanTick>()), id: \.uuid)
        file.ticks = byDate(ticks, { $0.tickedAt }, { $0.uuid }).map {
            DataFile.Tick(id: $0.uuid, planID: $0.planID, readingID: $0.readingID, tickedAt: ms($0.tickedAt))
        }
        if includesConversations {
            file.conversations = byDate(try store.chat.allThreads(), { $0.createdAt }, { $0.uuid }).map { thread in
                DataFile.Conversation(
                    id: thread.uuid, scope: thread.scopeRaw, book: thread.book, chapter: thread.chapter, verse: thread.verse,
                    endVerse: thread.endVerse, startOffset: thread.startOffset, endOffset: thread.endOffset,
                    translationID: thread.translationID, quotedText: thread.quotedText, title: thread.title,
                    createdAt: ms(thread.createdAt), updatedAt: ms(thread.updatedAt),
                    messages: Twins.firsts(thread.orderedMessages, id: \.uuid).map {
                        DataFile.Message(id: $0.uuid, role: $0.roleRaw, content: $0.content, createdAt: ms($0.createdAt),
                                         providerID: $0.providerID, modelName: $0.modelName, attachedReference: $0.attachedReference,
                                         displayText: $0.displayText, providerHost: $0.providerHost,
                                         finishReason: $0.finishReason, savedNoteID: $0.savedNoteID)
                    })
            }
        }
        return file
    }
}
