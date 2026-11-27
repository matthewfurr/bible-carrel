import Foundation
import ScriptureData
import SwiftData
@testable import ScriptureModel

/// One of everything, made up, on WEB text.
@MainActor enum DataSample {
    struct Ids {
        var firstNote: UUID
        var thread: UUID
        var plan: UUID
    }

    @discardableResult
    static func fill(_ store: MarkupStore) throws -> Ids {
        let context = store.context

        let yellow = HighlightColor(name: "Yellow", lightHex: "#FFE86B", darkHex: "#6B5B00", sortOrder: 0, isDefault: true)
        yellow.builtInKey = "yellow"
        context.insert(yellow)
        let custom = try store.addColor(name: "Marigold", lightHex: "#F5C242", darkHex: "#8A6A10")

        let quote = "In the beginning, God created the heavens and the earth."
        let thread = try store.chat.createThread(
            scope: .selection, book: "Genesis", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 57,
            translationID: "WEB", quotedText: quote, title: "The first verse")
        // Two turns made in one millisecond would have no defined order; give them times a second apart.
        let turnTime = Date(timeIntervalSince1970: 1_700_000_000)
        let question = try store.chat.append(to: thread, role: .user, content: "What does bara mean?", providerID: "test", modelName: "none", attachedReference: nil)
        question.createdAt = turnTime
        let answer = try store.chat.append(to: thread, role: .assistant, content: "It means to create.", displayText: nil, providerID: "test", modelName: "stand-in",
                                           providerHost: nil, attachedReference: nil, finishReason: nil, uuid: nil)
        answer.createdAt = turnTime.addingTimeInterval(1)
        try context.save()

        let marked = try store.addHighlight(book: "Genesis", chapter: 1, verse: 1, endVerse: 1, startOffset: 0, endOffset: 57,
                                            translationID: "WEB", colorID: yellow.uuid, quotedText: quote)
        let note = try store.addNote(to: marked, body: "God made it all.", sourceThreadID: thread.uuid)
        try store.addChapterNote(book: "Genesis", chapter: 1, translationID: "WEB", body: "The first chapter.", sourceThreadID: nil)
        try store.addHighlight(book: "Psalms", chapter: 23, verse: 1, endVerse: 1, startOffset: 0, endOffset: 20,
                               translationID: "WEB", colorID: custom.uuid, quotedText: "Yahweh is my shepherd")

        let kept = KeptVersion()
        kept.noteID = note.uuid
        kept.body = "God made everything."
        kept.writtenAt = Date(timeIntervalSince1970: 1_700_000_000)
        kept.deviceKind = "iPhone"
        kept.book = "Genesis"; kept.chapter = 1; kept.verse = 1; kept.endVerse = 1
        kept.translationID = "WEB"; kept.quotedText = quote; kept.endOffset = 57
        context.insert(kept)
        let orphan = KeptVersion()
        orphan.body = "A note whose note is gone."
        orphan.writtenAt = Date(timeIntervalSince1970: 1_700_000_100)
        orphan.deviceKind = "Mac"
        orphan.book = "John"; orphan.chapter = 3; orphan.verse = 16; orphan.endVerse = 16; orphan.translationID = "WEB"
        context.insert(orphan)

        _ = try store.toggleBookmark(at: VerseLocation(book: "Psalms", chapter: 23, verse: 1))
        try store.allBookmarks().first?.label = "Shepherd"

        let prompts = PromptTemplateStore(container: store.container)
        try prompts.seedIfNeeded([PromptSeed(key: "summary", title: "Summarize", summary: "A short summary", body: "Summarize {{reference}}.",
                                             scope: .chapter, section: .orient, legacyTitle: "Summarize")])
        try prompts.add(title: "My question", body: "Ask about {{reference}}.", scope: .selection)

        let plan = PlanSample.standIn(today: PlanDay(year: 2026, month: 11, day: 16)!)
        let plans = PlanStore(container: store.container)
        try plans.save(plan)
        try plans.toggleTick(planID: plan.id, readingID: plan.weeks[0].readings[0].id, now: Date(timeIntervalSince1970: 1_700_000_200))
        try plans.toggleTick(planID: plan.id, readingID: plan.weeks[0].readings[1].id, now: Date(timeIntervalSince1970: 1_700_000_300))

        try context.save()
        return Ids(firstNote: note.uuid, thread: thread.uuid, plan: plan.id)
    }
}
