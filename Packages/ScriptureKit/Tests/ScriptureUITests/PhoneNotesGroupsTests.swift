#if os(iOS)
import Foundation
import Testing
@testable import ScriptureUI

/// The phone's Notes tab takes the Mac window's groups: days with their counts when sorted by date,
/// the books with none when sorted by passage (milestone 11, project 5).
@MainActor @Suite(.serialized) struct PhoneNotesGroupsTests {
    @Test func thePhonesHeadingsAreTheModelsGroups() throws {
        let fixture = try NotesBrowserFixture()
        let model = fixture.model()

        model.sort = .date
        let days = PhoneNotesScreen.notesHeadings(for: model)
        #expect(days.count == model.days.count)
        #expect(days.map(\.title) == model.days.map(\.title))
        #expect(days[0] == (title: "Today", count: "2 items"))
        #expect(days[1] == (title: "Yesterday", count: "1 item"))
        #expect(days.allSatisfy { $0.count != nil })

        model.sort = .reference
        let books = PhoneNotesScreen.notesHeadings(for: model)
        #expect(books.map(\.title) == model.sections.map(\.title))
        #expect(books.allSatisfy { $0.count == nil })
        #expect(!books.isEmpty)
    }

    @Test func theCountFollowsTheFilter() throws {
        let fixture = try NotesBrowserFixture()
        let model = fixture.model()
        model.sort = .date
        model.filter = .notes
        let days = PhoneNotesScreen.notesHeadings(for: model)
        #expect(days[0] == (title: "Today", count: "2 notes"))
    }
}
#endif
