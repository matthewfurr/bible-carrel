import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

/// What the versions view shows and the row says (spec 4.1, 4.2): the blocks in their order with
/// their choices, and the row's spoken title.
@MainActor @Suite struct NoteVersionsViewTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
    private var now: Date { date(19, 12, 0) }

    private func kept(_ body: String, writtenAt: Date, noteID: UUID?) -> KeptVersionSnapshot {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = body
        version.writtenAt = writtenAt
        version.deviceKind = "Mac"
        version.book = "JHN"
        version.chapter = 15
        version.verse = 5
        version.endVerse = 5
        version.translationID = "WEB"
        return KeptVersionSnapshot(version)
    }

    private func versions(noteID: UUID, kept: [KeptVersionSnapshot]) -> NoteVersions {
        NoteVersions(
            noteID: noteID, book: "JHN",
            current: .init(body: "This text", deviceKind: "iPhone", modifiedAt: date(19, 8, 14)),
            kept: kept)
    }

    @Test func theBlocksAreThisVersionThenTheKeptNewestFirst() {
        let noteID = UUID()
        let ten = kept("Ten", writtenAt: date(10, 9, 40), noteID: noteID)
        let twenty = kept("Twenty", writtenAt: date(18, 21, 40), noteID: noteID)
        // Oldest first on purpose: the blocks put the newest first whatever order they are given.
        let blocks = NoteVersionsView.blocks(for: versions(noteID: noteID, kept: [ten, twenty]), now: now, calendar: calendar, locale: locale)

        #expect(blocks.map(\.body) == ["This text", "Twenty", "Ten"])
        #expect(blocks[0].id == noteID && blocks[0].keptID == nil)
        #expect(blocks[0].choices.isEmpty && blocks[0].prominent == nil)
        #expect(blocks[0].name == "This version · iPhone" && blocks[0].time == "Today 8:14\u{202F}AM")
        #expect(blocks[0].spoken == "This version · iPhone, Today 8:14\u{202F}AM")
        #expect(blocks[1].keptID == twenty.uuid && blocks[2].keptID == ten.uuid)
        #expect(blocks[1].name == "Kept version · Mac" && blocks[1].time == "Yesterday 9:40\u{202F}PM")
        for block in blocks.dropFirst() {
            #expect(block.choices == [.use, .keepBoth, .discard])
            #expect(block.prominent == nil)
        }
        #expect(Set(blocks.map(\.id)).count == 3)

        let one = NoteVersionsView.blocks(for: versions(noteID: noteID, kept: [ten]), now: now, calendar: calendar, locale: locale)
        #expect(one.count == 2)
        #expect(one[1].choices == [.use, .keepBoth, .discard] && one[1].prominent == .use)
        #expect(one[0].prominent == nil)
    }

    @Test func aTextWithNoNoteOffersRestoreAndDiscard() {
        let orphan = kept("Lost words", writtenAt: date(18, 21, 40), noteID: UUID())
        let blocks = NoteVersionsView.blocks(forOrphan: orphan, now: now, calendar: calendar, locale: locale)
        #expect(blocks.count == 1)
        let block = blocks[0]
        #expect(block.id == orphan.uuid && block.keptID == orphan.uuid)
        #expect(block.choices == [.restoreAsNote, .discard] && block.prominent == .restoreAsNote)
        #expect(block.name == "Kept version · Mac" && block.body == "Lost words")
        #expect(block.spoken == "Kept version · Mac, Yesterday 9:40\u{202F}PM")
    }

    @Test func aRowSaysItsVersions() {
        func card(versions: Int, chapter: Bool = false) -> NoteCard {
            NoteCard(id: UUID(), highlightID: chapter ? nil : UUID(), referenceString: chapter ? "John 15" : "John 15:5", quotedText: "",
                     body: "N", modifiedAt: now, color: nil, isChapterNote: chapter, versionCount: versions)
        }
        #expect(NoteRowView.spokenTitle(for: card(versions: 2), colorName: "Yellow") == "Note, John 15:5, Yellow, 2 versions")
        #expect(NoteRowView.spokenTitle(for: card(versions: 1), colorName: "Yellow") == "Note, John 15:5, Yellow")
        #expect(NoteRowView.spokenTitle(for: card(versions: 1), colorName: nil) == "Note, John 15:5, No color")
        #expect(NoteRowView.spokenTitle(for: card(versions: 3, chapter: true), colorName: nil) == "Chapter note, John 15, 3 versions")
        #expect(NoteRowView.spokenTitle(for: card(versions: 1, chapter: true), colorName: nil) == "Chapter note, John 15")
    }
}
