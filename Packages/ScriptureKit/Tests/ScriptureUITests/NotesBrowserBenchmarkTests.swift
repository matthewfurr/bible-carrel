#if os(macOS)
import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite(.serialized) struct NotesBrowserBenchmarkTests {
    private static let chicago: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }()
    /// 2026-11-23 09:30 in Chicago, a Monday.
    private static let now = chicago.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 9, minute: 30))!
    private static let books = ["GEN", "PSA", "ISA", "MAT", "JHN", "ROM"]

    /// Five made-up marks a day, for 400 days back from `now`: 08:00, 10:00, 12:00, 14:00 and 16:00 local.
    private static func entries() -> [NotesBrowserEntry] {
        let today = chicago.startOfDay(for: now)
        return (0..<2000).map { index in
            let day = chicago.date(byAdding: .day, value: -(index / 5), to: today)!
            let modified = chicago.date(byAdding: .hour, value: 8 + (index % 5) * 2, to: day)!
            let book = books[index % books.count]
            let id = UUID()
            let kind: NotesBrowserEntry.Kind = switch index % 3 {
            case 0: .note(noteID: id, highlightID: UUID())
            case 1: .highlight(id: id)
            default: .bookmark(id: id)
            }
            let chapter = 1 + index % 20, verse = 1 + index % 30
            return NotesBrowserEntry(
                id: id, kind: kind, book: book, bookOrder: BookCatalog.book(code: book)?.order ?? Int.max,
                chapter: chapter, verse: verse, endVerse: verse,
                referenceString: MarkupReferenceText.string(book: book, chapter: chapter, verse: verse, endVerse: verse),
                translationID: "ESV", color: nil, quotedText: "", body: "", modifiedAt: modified)
        }
    }

    /// Spec 5.6 and Departure 25: the day grouping of 2,000 entries over 400 days, date-sorted once in
    /// `prepare` (the sort is the model's, not the grouping's), the median of nine, debug build.
    /// Measured alone, three runs on 2026-11-24: 6.4, 6.5, 6.6 ms (load average about 5.5); bound 1.5 x 6.6 = 9.9, rounded up to 10 ms.
    @Test func groupingTwoThousandNotesByDay() {
        let unsorted = Self.entries()
        var sorted: [NotesBrowserEntry] = []
        var sections: [NotesBrowserSection] = []
        let median = ReaderBenchmarkTests.median("notes-browser-days-2000", prepare: {
            if sorted.isEmpty { sorted = NotesBrowserQuery.sort(unsorted, by: .date) }
        }) {
            sections = NotesBrowserQuery.days(sorted, now: Self.now, calendar: Self.chicago, locale: Locale(identifier: "en_US"))
        }
        #expect(sections.count == 400)
        #expect(median < .milliseconds(10))
    }
}
#endif
