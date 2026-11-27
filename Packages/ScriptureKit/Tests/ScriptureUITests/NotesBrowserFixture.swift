import Foundation
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

/// A made-up Notes window on an in-memory store, both apps: three marks and a noted chapter of
/// the past week, a note with a kept version and a kept version whose note is gone, a bookmark,
/// two colourless anchors, and a conversation from a year ago. Every translation is ESV. Its
/// clock reads 2026-11-23 09:30 in Chicago (a Monday), and its `UserDefaults` suite goes with it.
/// Keep the fixture alive as long as the test uses the model.
///
/// By date, newest first: `abide`, `romans`, `stillWaters`, `vine`, `provide`, `ezraChapter`,
/// `johnThree`, `poorInSpirit`, `mark4`; `orphan` lists only under the Kept versions filter.
@MainActor final class NotesBrowserFixture {
    let store: MarkupStore
    let calendar: Calendar
    let locale = Locale(identifier: "en_US")
    let now: Date
    let defaults: UserDefaults

    /// A yellow highlight of John 15:4 with a note, today 08:14.
    let abide: UUID
    /// A blue highlight of Romans 8:28 with a note, today 07:52.
    let romans: UUID
    /// A green highlight of Psalm 23:2 with no note, yesterday 21:03.
    let stillWaters: UUID
    /// A note on a yellow highlight of John 15:5 with one kept version, 2026-11-20 10:00.
    let vine: UUID
    /// A kept version of John 15:9 whose note is gone, written 2026-11-20 09:00.
    let orphan: UUID
    /// A bookmark of Genesis 22:8 labelled "The Lord will provide", 2026-11-18 06:40.
    let provide: UUID
    /// A chapter note on Ezra 4 with a heading and a list, 2026-11-18 06:31.
    let ezraChapter: UUID
    /// A note on a colourless highlight of John 3:16, 2026-11-18 00:01.
    let johnThree: UUID
    /// A note on a colourless highlight of Matthew 5:3 that begins with a heading, 2026-11-17 23:59.
    let poorInSpirit: UUID
    /// A conversation on Mark 4 (chapter scope), updated 2025-11-14 21:03.
    let mark4: UUID

    private let suiteName = "NotesBrowserFixture-\(UUID().uuidString)"

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        self.calendar = calendar
        func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }
        now = at(2026, 11, 23, 9, 30)
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        self.store = store
        let colors = try store.colors()
        func color(_ name: String) throws -> UUID {
            try #require(colors.first { $0.name == name }).uuid
        }
        func highlight(_ book: String, _ chapter: Int, _ verse: Int, _ quote: String, color colorID: UUID?, at date: Date) throws -> Highlight {
            let highlight = try store.addHighlight(book: book, chapter: chapter, verse: verse, endVerse: verse, startOffset: 0, endOffset: quote.count,
                                                   translationID: "ESV", colorID: colorID, quotedText: quote)
            highlight.modifiedAt = date
            return highlight
        }
        func note(on anchor: Highlight, _ body: String) throws -> Note {
            let date = anchor.modifiedAt
            let note = try store.addNote(to: anchor, body: body)
            note.modifiedAt = date
            anchor.modifiedAt = date
            return note
        }

        abide = try note(on: highlight("JHN", 15, 4, "Abide in me, and I in you.", color: color("Yellow"), at: at(2026, 11, 23, 8, 14)),
                         "Abiding is not effort but staying put. Compare 1 John 2:28 on confidence at his coming.").uuid
        romans = try note(on: highlight("ROM", 8, 28, "for those who love God all things work together for good", color: color("Blue"), at: at(2026, 11, 23, 7, 52)),
                          "Who are \"those who love God\"? Verse 29 answers: those he foreknew. The promise is to the called.").uuid
        stillWaters = try highlight("PSA", 23, 2, "He leads me beside still waters.", color: color("Green"), at: at(2026, 11, 22, 21, 3)).uuid
        vine = try note(on: highlight("JHN", 15, 5, "I am the vine; you are the branches.", color: color("Yellow"), at: at(2026, 11, 20, 10, 0)),
                        "Apart from me you can do nothing.").uuid
        Self.keep("Remain in me, as I also remain in you.", of: vine, verse: 5, quote: "I am the vine; you are the branches.",
                  writtenAt: at(2026, 11, 19, 18, 0), in: store)
        orphan = Self.keep("The words of a note that was deleted on another device.", of: UUID(), verse: 9,
                           quote: "As the Father has loved me, so have I loved you.", writtenAt: at(2026, 11, 20, 9, 0), in: store)

        try store.toggleBookmark(at: VerseLocation(book: "GEN", chapter: 22, verse: 8))
        let bookmark = try #require(try store.bookmark(at: VerseLocation(book: "GEN", chapter: 22, verse: 8)))
        bookmark.label = "The Lord will provide"
        bookmark.createdAt = at(2026, 11, 18, 6, 40)
        provide = bookmark.uuid

        let chapterNote = try store.addChapterNote(book: "EZR", chapter: 4, translationID: "ESV",
                                                   body: "# Discouragement\n\nOpposition as discouragement.\n\n- verse 4\n- verse 5", sourceThreadID: nil)
        chapterNote.modifiedAt = at(2026, 11, 18, 6, 31)
        ezraChapter = chapterNote.uuid
        johnThree = try note(on: highlight("JHN", 3, 16, "For God so loved the world", color: nil, at: at(2026, 11, 18, 0, 1)), "For God so loved").uuid
        poorInSpirit = try note(on: highlight("MAT", 5, 3, "Blessed are the poor in spirit", color: nil, at: at(2026, 11, 17, 23, 59)),
                                "# Blessed (Luke 6:20)\nThe kingdom is theirs.").uuid

        let thread = try store.chat.createThread(scope: .chapter, book: "MRK", chapter: 4, verse: 0, endVerse: 0, startOffset: 0, endOffset: 0,
                                                 translationID: "ESV", quotedText: "", title: "Outline: Mark 4")
        let question = try store.chat.append(to: thread, role: .user, content: "Outline Mark 4", displayText: "Outline",
                                             providerID: "", modelName: "", attachedReference: nil)
        let answer = try store.chat.append(to: thread, role: .assistant, content: "The parable of the sower comes first.",
                                           providerID: "appleOnDevice", modelName: "m", attachedReference: nil)
        question.createdAt = at(2025, 11, 14, 21, 2)
        answer.createdAt = at(2025, 11, 14, 21, 3)
        thread.createdAt = at(2025, 11, 14, 21, 2)
        thread.updatedAt = at(2025, 11, 14, 21, 3)
        mark4 = thread.uuid

        try store.context.save()
    }

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    /// A model over the fixture's store and defaults, its clock at `now`, in the fixture's calendar and locale.
    func model() -> NotesBrowserModel {
        let now = now
        return NotesBrowserModel(store: store, defaults: defaults, now: { now }, calendar: calendar, locale: locale)
    }

    /// A kept version of a John 15 verse from a Mac, as `PhoneVersionsFixture.keep` makes one (that
    /// helper is the phone's alone), at a fixed time and in ESV. Saved with the fixture.
    @discardableResult
    private static func keep(_ body: String, of noteID: UUID, verse: Int, quote: String, writtenAt: Date, in store: MarkupStore) -> UUID {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = body
        version.writtenAt = writtenAt
        version.deviceKind = "Mac"
        version.book = "JHN"
        version.chapter = 15
        version.verse = verse
        version.endVerse = verse
        version.translationID = "ESV"
        version.quotedText = quote
        store.context.insert(version)
        return version.uuid
    }
}
