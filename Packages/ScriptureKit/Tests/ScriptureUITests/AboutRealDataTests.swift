import ScriptureData
import Testing
@testable import ScriptureUI

/// The real Theographic data as schema 6 keeps it: each event's length and part-of, a life's person, and the named corrections.
@Suite struct AboutRealDataTests {
    @Test(.needsRealBible) func theRealEventsCarryLengthsAndLinks() throws {
        let store = try BenchmarkChapter.realStore()
        let records = try store.eventRecords()
        #expect(records.count == 501)
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        #expect(byID[4]?.personID == 78 && byID[4]?.durationDays == 930 * 365.25)
        #expect(byID[129]?.partOf == 121 && byID[108]?.personID == 1639)
        let lives = records.filter { $0.title.hasPrefix("Lifetime of ") }
        #expect(!lives.isEmpty && lives.allSatisfy { $0.personID != nil })
        #expect(records.allSatisfy { $0.durationDays != nil })
    }

    @Test(.needsRealBible) func mosesAndJobOfUzAreOutOfGenesis() throws {
        let store = try BenchmarkChapter.realStore()
        let genesis = try store.events(inBook: "GEN").map(\.id)
        #expect(genesis.count == 113 && !genesis.contains(107) && !genesis.contains(108) && !genesis.contains(129))
        #expect(try store.events(inBook: "DEU").map(\.id).contains(129))
        #expect(try store.events(inBook: "JOB").map(\.id).contains(108))
    }

    @Test(.needsRealBible) func genesisIsTwentyFourLivesAndFortyOneEvents() throws {
        let timeline = try BookTimeline.load(book: "GEN", translationID: "ESV", store: BenchmarkChapter.realStore())
        #expect(timeline.lifeCount == 24 && timeline.eventCount == 41)
        let eraIDs = Set(timeline.entries.compactMap(\.era))
        #expect(eraIDs.count == 3)
        #expect(Set(eraIDs.compactMap { timeline.eras[$0]?.title }) == ["The Great Flood", "Sojourn in Canaan and Egypt", "7 years of famine"])
        let years = timeline.entries.map(\.year)
        #expect(years == years.sorted())
        #expect(timeline.entries.last?.title == "Joseph's brothers return to Egypt")
        #expect(timeline.years?.upperBound == -1634 && timeline.years.map(LibraryYear.spans) == "about 4004 to 1635 BC")
        let titles = timeline.entries.map(\.title)
        #expect(!titles.contains("Lifetime of Job") && !titles.contains("Job") && !titles.contains("Death of Moses"))
        #expect(!titles.contains { $0.hasPrefix("Birth of Seth") })
    }

    /// An event that runs past its chapter ends at that chapter's last verse in the translation: the nine in
    /// Genesis read as the chapter itself gives them.
    @Test(.needsRealBible) func aPassagePastItsChapterEndsAtThatChaptersLastVerse() throws {
        let store = try BenchmarkChapter.realStore()
        let genesis = try #require(BookCatalog.book(code: "GEN"))
        let passages = try BookTimeline.passages(of: genesis, translationID: "ESV", store: store)
        let long = try store.events(inBook: "GEN").filter { $0.end.chapter != $0.start.chapter }
        #expect(long.count == 9 && passages.count == 113)
        for event in long {
            let last = try store.chapter(ChapterLocation(book: "GEN", chapter: event.start.chapter), translationID: "ESV").last
            let end = last.map { $0.endVerse ?? $0.id.verse }
            #expect(passages[event.id] == Reference(book: genesis, chapter: event.start.chapter, verse: event.start.verse,
                                                    endVerse: end.flatMap { $0 > event.start.verse ? $0 : nil }))
        }
    }

    @Test(.needsRealBible) func actsIsSeventyEightEventsInThreeJourneys() throws {
        let timeline = try BookTimeline.load(book: "ACT", translationID: "ESV", store: BenchmarkChapter.realStore())
        #expect(timeline.lifeCount == 0 && timeline.eventCount == 78)
        let titles = Set(Set(timeline.entries.compactMap(\.era)).compactMap { timeline.eras[$0]?.title })
        #expect(titles == ["First Missionary Journey", "Second Missionary Journey", "Third Missionary Journey"])
    }

    @Test(.needsRealBible, arguments: ["EXO", "GAL"]) func theSojournIsOneRowInExodusAndGalatians(book: String) throws {
        let timeline = try BookTimeline.load(book: book, translationID: "ESV", store: BenchmarkChapter.realStore())
        let rows = timeline.entries.filter { $0.title == "Sojourn in Canaan and Egypt" }
        #expect(rows.count == 1 && rows.first?.kind == .event && rows.first?.era == nil && rows.first?.isEra == true)
    }

    @Test(.needsRealBible) func firstChroniclesShowsLivesThroughTheirBirths() throws {
        let timeline = try BookTimeline.load(book: "1CH", translationID: "ESV", store: BenchmarkChapter.realStore())
        #expect(timeline.entries.map(\.title) == ["Seth", "Enos", "Cainan"] && timeline.eventCount == 0)
        #expect(timeline.entries.allSatisfy { $0.passage?.book.id == "1CH" })
    }

    @Test(.needsRealBible) func genesisFactsReadAsTheMockup() throws {
        let about = try #require(try BookAbout.load(book: "GEN", translationID: "ESV", store: BenchmarkChapter.realStore()))
        #expect(about.subtitle == "The First Book of Moses")
        #expect(about.testamentLine == "Old Testament, the Law" && about.lengthLine == "50 chapters, 1,533 verses")
        #expect(about.writers.map(\.name) == ["Moses"])
        #expect(about.topPeople.map(\.name) == ["God", "Jacob", "Abraham", "Joseph", "Isaac"] && about.morePeople == 347)
        #expect(about.topPlaces.map(\.name) == ["Egypt", "Canaan", "Sodom", "Beersheba", "Bethel"] && about.morePlaces == 114)
        #expect(about.spans(showingDates: true) == "about 4004 to 1635 BC")
    }

    @Test(.needsRealBible) func genesisFoldsThreeRunsAndDrawsFourHeaders() throws {
        let genesis = try BookTimeline.load(book: "GEN", translationID: "ESV", store: BenchmarkChapter.realStore())
        let items = TimelineItems.items(genesis, openFolds: [], showingDates: true)
        let lines = items.compactMap { item -> String? in if case .fold(let fold, _, _) = item { fold.line } else { nil } }
        #expect(lines == ["8 lives, Seth to Lamech", "4 lives, Arphaxad to Peleg", "3 lives, Nahor to Abraham"])
        let eraIDs = items.compactMap { item -> Int? in if case .era(let era, _) = item { era.id } else { nil } }
        #expect(eraIDs.count == 4 && Set(eraIDs).count == 3)
        let acts = try BookTimeline.load(book: "ACT", translationID: "ESV", store: BenchmarkChapter.realStore())
        let actIDs = TimelineItems.items(acts, openFolds: [], showingDates: true).compactMap { item -> Int? in
            if case .era(let era, _) = item { era.id } else { nil }
        }
        #expect(actIDs.count == 4 && Set(actIDs).count == 3)
    }

    @Test(.needsRealBible) func firstChroniclesFoldsItsThreeLives() throws {
        let timeline = try BookTimeline.load(book: "1CH", translationID: "ESV", store: BenchmarkChapter.realStore())
        let lines = TimelineItems.items(timeline, openFolds: [], showingDates: true).compactMap { item -> String? in
            if case .fold(let fold, _, _) = item { fold.line } else { nil }
        }
        #expect(lines == ["3 lives, Seth to Cainan"])
    }

    @Test(.needsRealBible) func genesisNeedsTenLanes() throws {
        let store = try BenchmarkChapter.realStore()
        let model = try TimelineChartModel(BookTimeline.load(book: "GEN", translationID: "ESV", store: store))
        #expect(model.laneCount == 10 && model.bars.count == 27)
        for (book, expected) in [("GEN", true), ("ACT", true), ("2SA", false), ("GAL", false)] {
            let timeline = try BookTimeline.load(book: book, translationID: "ESV", store: store)
            #expect(TimelineChartModel.shows(timeline, showingDates: true) == expected, "\(book)")
        }
    }
}
