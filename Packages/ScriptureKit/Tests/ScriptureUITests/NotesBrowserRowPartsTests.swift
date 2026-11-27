import Foundation
import Testing
@testable import ScriptureUI

/// What the Notes window's row says, as words: the passage, the time or date, the marked words,
/// the note's line and VoiceOver's label, over the made-up store. Foundation's times carry a
/// narrow no-break space before AM and PM, written here as `\u{202F}`.
@MainActor @Suite struct NotesBrowserRowPartsTests {
    private let fixture: NotesBrowserFixture
    private let model: NotesBrowserModel

    init() throws {
        fixture = try NotesBrowserFixture()
        model = fixture.model()
    }

    private func parts(_ id: UUID, underDay: Bool = true) throws -> NotesBrowserRowParts {
        model.sort = .date
        model.filter = .keptVersions
        var entry = model.entries.first { $0.id == id }
        if entry == nil {
            model.filter = .all
            entry = model.entries.first { $0.id == id }
        }
        return NotesBrowserRowParts.make(try #require(entry), underDay: underDay, calendar: fixture.calendar, locale: fixture.locale)
    }

    @Test func aNotedHighlight() throws {
        let parts = try parts(fixture.abide)
        #expect(parts.title == "John 15:4")
        #expect(parts.placeAfterTitle == nil)
        #expect(parts.translationID == "ESV")
        #expect(parts.when == "8:14\u{202F}AM")
        #expect(parts.quote == "Abide in me, and I in you.")
        #expect(parts.quoteIsFilled)
        guard case .markdown(let body)? = parts.note else { Issue.record("expected a markdown note"); return }
        #expect(body.hasPrefix("Abiding is not effort"))
        #expect(parts.versions == nil)
        #expect(parts.spoken == "Note, John 15:4, 8:14\u{202F}AM")
    }

    @Test func aHighlightWithoutANote() throws {
        let parts = try parts(fixture.stillWaters)
        #expect(parts.quote == "He leads me beside still waters.")
        #expect(parts.quoteIsFilled)
        #expect(parts.note == nil)
        #expect(parts.spoken == "Highlight, Psalm 23:2, 9:03\u{202F}PM")
    }

    @Test func aBookmark() throws {
        let parts = try parts(fixture.provide)
        #expect(parts.quote == "The Lord will provide")
        #expect(!parts.quoteIsFilled)
        #expect(parts.translationID == nil)
        #expect(parts.note == nil)
        #expect(parts.spoken == "Bookmark, Genesis 22:8, 6:40\u{202F}AM")
    }

    @Test func aChapterNote() throws {
        let parts = try parts(fixture.ezraChapter)
        #expect(parts.quote == nil)
        guard case .markdown? = parts.note else { Issue.record("expected a markdown note"); return }
        #expect(parts.spoken == "Chapter note, Ezra 4, 6:31\u{202F}AM")
    }

    @Test func aColourlessAnchor() throws {
        let parts = try parts(fixture.poorInSpirit)
        #expect(parts.quote == "Blessed are the poor in spirit")
        #expect(!parts.quoteIsFilled)
    }

    @Test func aConversation() throws {
        let parts = try parts(fixture.mark4)
        #expect(parts.title == "Outline: Mark 4")
        #expect(parts.placeAfterTitle == "Mark 4")
        #expect(parts.quote == nil)
        #expect(parts.note == .lastTurn("The parable of the sower comes first."))
        #expect(parts.spoken == "Conversation, Mark 4, Outline: Mark 4, 9:03\u{202F}PM")
    }

    @Test func aNoteWithVersionsAndAKeptVersion() throws {
        let vine = try parts(fixture.vine)
        #expect(vine.versions == "2 versions")
        #expect(vine.spoken == "Note, John 15:5, 2 versions, 10:00\u{202F}AM")
        let orphan = try parts(fixture.orphan)
        #expect(orphan.versions == "Kept version")
        #expect(!orphan.quoteIsFilled)
        #expect(orphan.quote == "As the Father has loved me, so have I loved you.")
        guard case .markdown? = orphan.note else { Issue.record("expected a markdown note"); return }
        #expect(orphan.spoken == "Kept version, John 15:9, 9:00\u{202F}AM")
    }

    @Test func underABookHeadingTheDate() throws {
        #expect(try parts(fixture.abide, underDay: false).when == "Nov 23, 2026")
    }

    /// The hairline between two notes of a group goes when either of them is selected, and only then.
    @Test func theHairlinesHideBesideTheSelectionOnly() {
        let (above, below, other) = (UUID(), UUID(), UUID())
        #expect(NotesBrowserList.showsRule(above: above, below: below, selected: nil))
        #expect(!NotesBrowserList.showsRule(above: above, below: below, selected: above))
        #expect(!NotesBrowserList.showsRule(above: above, below: below, selected: below))
        #expect(NotesBrowserList.showsRule(above: above, below: below, selected: other))
    }

    /// A group's last row keeps `xxs` clear of the rule under it, so its wash, when it is selected,
    /// stops short of the line (spec 5.3: "the wash never sits on a line"); the next heading's `md` follows the rule.
    @Test func aGroupsLastRowStopsShortOfTheGroupRule() {
        #expect(NotesBrowserList.spaceAboveGroupRule == AppSpacing.xxs)
        #expect(NotesBrowserList.spaceAboveGroupRule > 0)
    }
}
