import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@Suite struct NotesBrowserQueryTests {
    private func entry(_ id: UUID = UUID(), kind: NotesBrowserEntry.Kind, book: String, chapter: Int, verse: Int, modified: TimeInterval) -> NotesBrowserEntry {
        NotesBrowserEntry(
            id: id, kind: kind, book: book, bookOrder: BookCatalog.book(code: book)?.order ?? Int.max,
            chapter: chapter, verse: verse, endVerse: verse,
            referenceString: MarkupReferenceText.string(book: book, chapter: chapter, verse: verse, endVerse: verse),
            translationID: "ESV", color: nil, quotedText: "", body: "", modifiedAt: Date(timeIntervalSince1970: modified))
    }

    let noteID = UUID(), hlID = UUID(), bmID = UUID()
    var mat5: NotesBrowserEntry { entry(noteID, kind: .note(noteID: noteID, highlightID: UUID()), book: "MAT", chapter: 5, verse: 3, modified: 100) }
    var gen1: NotesBrowserEntry { entry(hlID, kind: .highlight(id: hlID), book: "GEN", chapter: 1, verse: 1, modified: 300) }
    var jhn3: NotesBrowserEntry { entry(bmID, kind: .bookmark(id: bmID), book: "JHN", chapter: 3, verse: 16, modified: 200) }

    @Test func threadsFilterIsExclusive() {
        let thread = entry(kind: .thread(id: UUID()), book: "MAT", chapter: 5, verse: 0, modified: 100)
        let note = entry(kind: .note(noteID: UUID(), highlightID: nil), book: "MAT", chapter: 5, verse: 0, modified: 100)
        #expect(NotesBrowserQuery.filter([thread, note], by: .threads).map(\.id) == [thread.id])
        #expect(NotesBrowserQuery.filter([thread, note], by: .notes).map(\.id) == [note.id])
        #expect(NotesBrowserQuery.filter([thread, note], by: .highlights).isEmpty && NotesBrowserQuery.filter([thread, note], by: .bookmarks).isEmpty)
        #expect(NotesBrowserQuery.filter([thread, note], by: .all).count == 2)
    }

    @Test func cutoffs() {
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12))!
        #expect(NotesBrowserTimeFilter.anyTime.cutoff(from: now, calendar: cal) == nil)
        #expect(NotesBrowserTimeFilter.pastWeek.cutoff(from: now, calendar: cal) == cal.date(byAdding: .day, value: -7, to: now))
        #expect(NotesBrowserTimeFilter.pastMonth.cutoff(from: now, calendar: cal) == cal.date(byAdding: .month, value: -1, to: now))
        #expect(NotesBrowserTimeFilter.pastThreeMonths.cutoff(from: now, calendar: cal) == cal.date(byAdding: .month, value: -3, to: now))
        #expect(NotesBrowserTimeFilter.pastYear.cutoff(from: now, calendar: cal) == cal.date(byAdding: .year, value: -1, to: now))
    }

    @Test func titles() {
        #expect(NotesBrowserTimeFilter.allCases.map(\.title) == ["Any time", "Past week", "Past month", "Past 3 months", "Past year"])
    }

    @Test func sinceKeepsTheBoundaryAndTheFuture() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        func at(_ date: Date) -> NotesBrowserEntry {
            entry(kind: .bookmark(id: UUID()), book: "GEN", chapter: 1, verse: 1, modified: date.timeIntervalSince1970)
        }
        let beforeCutoff = at(cutoff.addingTimeInterval(-1)), atCutoff = at(cutoff), atNow = at(now), tomorrow = at(now.addingTimeInterval(86_400))
        let entries = [beforeCutoff, atCutoff, atNow, tomorrow]
        #expect(NotesBrowserQuery.filter(entries, since: cutoff).map(\.id) == [atCutoff.id, atNow.id, tomorrow.id])
        #expect(NotesBrowserQuery.filter(entries, since: nil).count == 4)
    }

    @Test func dateSortIsNewestFirst() {
        #expect(NotesBrowserQuery.sort([mat5, gen1, jhn3], by: .date).map(\.id) == [hlID, bmID, noteID])
    }

    @Test func referenceSortFollowsTheCanon() {
        #expect(NotesBrowserQuery.sort([mat5, jhn3, gen1], by: .reference).map(\.book) == ["GEN", "MAT", "JHN"])
    }

    @Test func filtersKeepTheRightKinds() {
        let all = [mat5, gen1, jhn3]
        #expect(NotesBrowserQuery.filter(all, by: .all).count == 3)
        #expect(NotesBrowserQuery.filter(all, by: .notes).map(\.id) == [noteID])
        #expect(NotesBrowserQuery.filter(all, by: .highlights).map(\.id) == [noteID, hlID])
        #expect(NotesBrowserQuery.filter(all, by: .bookmarks).map(\.id) == [bmID])
    }

    @Test func theKeptVersionsFilter() {
        func note(versions: Int) -> NotesBrowserEntry {
            let id = UUID()
            return NotesBrowserEntry(
                id: id, kind: .note(noteID: id, highlightID: nil), book: "GEN", bookOrder: 1, chapter: 1, verse: 0, endVerse: 0,
                referenceString: "Genesis 1", translationID: "WEB", color: nil, quotedText: "", body: "N", modifiedAt: Date(), versionCount: versions)
        }
        let id = UUID()
        let orphan = NotesBrowserEntry(
            id: id, kind: .keptVersion(id: id), book: "GEN", bookOrder: 1, chapter: 1, verse: 0, endVerse: 0,
            referenceString: "Genesis 1", translationID: "WEB", color: nil, quotedText: "", body: "K", modifiedAt: Date())
        let withVersions = note(versions: 2), plain = note(versions: 1)
        let all = [withVersions, plain, orphan, mat5, gen1, jhn3]
        // A note with a kept version stays, and one without goes.
        #expect(NotesBrowserQuery.filter(all, by: .keptVersions).map(\.id).contains(withVersions.id))
        #expect(!NotesBrowserQuery.filter(all, by: .keptVersions).map(\.id).contains(plain.id))
        // A text with no note stays, and nothing else does.
        #expect(NotesBrowserQuery.filter(all, by: .keptVersions).map(\.id) == [withVersions.id, orphan.id])
        // Every other filter, All included, drops a text with no note.
        for filter in NotesBrowserFilter.allCases where filter != .keptVersions {
            #expect(!NotesBrowserQuery.filter(all, by: filter).map(\.id).contains(orphan.id), "\(filter)")
        }
        #expect(NotesBrowserQuery.filter(all, by: .all).count == 5)
    }

    @Test func sectionsGroupByBookInCanonOrder() {
        let gen2 = entry(kind: .bookmark(id: UUID()), book: "GEN", chapter: 2, verse: 1, modified: 1)
        let sections = NotesBrowserQuery.sections(NotesBrowserQuery.sort([mat5, jhn3, gen1, gen2], by: .reference))
        #expect(sections.map(\.title) == ["Genesis", "Matthew", "John"])
        #expect(sections.map(\.id) == ["GEN", "MAT", "JHN"])
        #expect(sections[0].entries.map(\.chapter) == [1, 2])
    }

    @Test func chapterNotesAreRecognised() {
        let chapterNote = entry(kind: .note(noteID: UUID(), highlightID: nil), book: "MAT", chapter: 5, verse: 0, modified: 1)
        #expect(chapterNote.isChapterNote && !mat5.isChapterNote && !gen1.isChapterNote)
    }

    // MARK: - Days

    private static let chicago: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }()
    private static let enUS = Locale(identifier: "en_US")
    /// 2026-11-23 09:30 in Chicago, a Monday.
    private static let now = at(2026, 11, 23, 9, 30)

    private static func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        chicago.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func dated(_ date: Date, book: String = "GEN") -> NotesBrowserEntry {
        entry(kind: .bookmark(id: UUID()), book: book, chapter: 1, verse: 1, modified: date.timeIntervalSince1970)
    }

    private func days(_ entries: [NotesBrowserEntry], locale: Locale = enUS) -> [NotesBrowserSection] {
        NotesBrowserQuery.days(NotesBrowserQuery.sort(entries, by: .date), now: Self.now, calendar: Self.chicago, locale: locale)
    }

    @Test func daysAreHeadedTodayYesterdayThenTheDate() {
        let entries = [Self.at(2026, 11, 23, 8, 14), Self.at(2026, 11, 23, 7, 52), Self.at(2026, 11, 22, 21, 3),
                       Self.at(2026, 11, 18, 6, 40), Self.at(2026, 11, 17, 23, 59), Self.at(2025, 11, 14, 21, 3)].map { dated($0) }
        let days = self.days(entries)
        #expect(days.map(\.title) == ["Today", "Yesterday", "Wednesday, November 18", "Tuesday, November 17", "Friday, November 14, 2025"])
        #expect(days.map(\.entries.count) == [2, 1, 1, 1, 1])
        #expect(days.map(\.id) == ["day-2026-11-23", "day-2026-11-22", "day-2026-11-18", "day-2026-11-17", "day-2025-11-14"])
        #expect(days.flatMap(\.entries).map(\.id) == NotesBrowserQuery.sort(entries, by: .date).map(\.id))

        let british = self.days(entries, locale: Locale(identifier: "en_GB"))
        #expect(british.map(\.title) == ["Today", "Yesterday", "Wednesday 18 November", "Tuesday 17 November", "Friday, 14 November 2025"])

        // A clock ahead on another device: the day after today is the newest, titled by its date.
        let ahead = dated(Self.at(2026, 11, 24, 10, 0))
        let withAhead = self.days(entries + [ahead])
        #expect(withAhead.first?.title == "Tuesday, November 24")
        #expect(withAhead.first?.entries.map(\.id) == [ahead.id])
        #expect(withAhead.dropFirst().map(\.title) == days.map(\.title))
    }

    @Test func aMinuteEitherSideOfMidnightIsTwoDays() {
        let before = dated(Self.at(2026, 11, 17, 23, 59)), after = dated(Self.at(2026, 11, 18, 0, 1))
        let days = self.days([before, after])
        #expect(days.map(\.id) == ["day-2026-11-18", "day-2026-11-17"])
        #expect(days.map { $0.entries.map(\.id) } == [[after.id], [before.id]])

        // Two in the same second keep the date sort's order (its tie is the reference) inside one day.
        let second = Self.at(2026, 11, 18, 6, 40)
        let genesis = dated(second, book: "GEN"), exodus = dated(second, book: "EXO")
        let sameSecond = self.days([genesis, exodus])
        #expect(sameSecond.map(\.id) == ["day-2026-11-18"])
        #expect(sameSecond.first?.entries.map(\.id) == NotesBrowserQuery.sort([genesis, exodus], by: .date).map(\.id))
        #expect(sameSecond.first?.entries.map(\.id) == [exodus.id, genesis.id])
    }

    @Test func theCountsWordFollowsTheFilter() {
        let words: [(filter: NotesBrowserFilter, one: String, two: String)] = [
            (.all, "1 item", "2 items"), (.notes, "1 note", "2 notes"), (.highlights, "1 highlight", "2 highlights"),
            (.bookmarks, "1 bookmark", "2 bookmarks"), (.threads, "1 conversation", "2 conversations"),
            (.keptVersions, "1 kept version", "2 kept versions"),
        ]
        #expect(words.map { $0.filter } == NotesBrowserFilter.allCases)
        for word in words {
            #expect(NotesBrowserQuery.countLabel(1, filter: word.filter) == word.one, "\(word.filter)")
            #expect(NotesBrowserQuery.countLabel(2, filter: word.filter) == word.two, "\(word.filter)")
        }
        let today = NotesBrowserSection(id: "day-2026-11-23", title: "Today", entries: [mat5, gen1])
        let yesterday = NotesBrowserSection(id: "day-2026-11-22", title: "Yesterday", entries: [jhn3])
        #expect(NotesBrowserQuery.headingSpoken(today, filter: .notes) == "Today, 2 notes")
        #expect(NotesBrowserQuery.headingSpoken(yesterday, filter: .all) == "Yesterday, 1 item")
    }
}
