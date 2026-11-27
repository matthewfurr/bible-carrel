import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The fixture has Matthew 1-6 in WEB and KJV and, in KJV only, long Psalms 118 and 119.
@MainActor @Suite struct StudyPromptComposerTests {
    @Test func chapterTextNumbersVersesAndKeepsPoetry() throws {
        let store = try FixtureStore.make()
        let verses = try store.chapter(ChapterLocation(book: "MAT", chapter: 5), translationID: "WEB")
        let text = StudyPromptComposer.chapterText(verses)
        #expect(text.hasPrefix("1 ") && text.contains("\n2 ") && text.components(separatedBy: "\n").count >= verses.count)
        let combined = Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: 12), translationID: "WEB", endVerse: 13, text: "a\nb", breakAfter: false)
        #expect(StudyPromptComposer.chapterText([combined]) == "12-13 a\nb")
    }

    @Test func abridgedKeepsFirstAndLastFive() throws {
        let verses = (1...12).map { Verse(id: VerseLocation(book: "PSA", chapter: 119, verse: $0), translationID: "KJV", text: "v\($0)", breakAfter: false) }
        let lines = StudyPromptComposer.abridged(verses).components(separatedBy: "\n")
        #expect(lines == ["1 v1", "2 v2", "3 v3", "4 v4", "5 v5", "…", "8 v8", "9 v9", "10 v10", "11 v11", "12 v12"])
        #expect(StudyPromptComposer.abridged(Array(verses.prefix(10))).components(separatedBy: "\n").count == 10)
    }

    @Test func otherTranslationsAreTheOnesNamedInTheirOrderUpToTheLimit() throws {
        let composer = StudyPromptComposer(store: try FixtureStore.make())
        func text(_ ids: [String], limit: Int? = nil) throws -> String {
            try composer.otherTranslations(for: ChapterLocation(book: "PSA", chapter: 1), verse: 1, endVerse: 2, translationIDs: ids, limit: limit)
        }
        let all = try text(["WEB", "ESV", "KJV"])
        #expect(all.hasPrefix("WEB\n1 ") && all.contains("\n\nKJV\n1 ") && !all.contains("ESV"))   // not in the fixture: left out
        let one = try text(["ESV", "KJV", "WEB"], limit: 1)
        let none = try text([])
        #expect(one.hasPrefix("KJV\n1 ") && !one.contains("WEB\n") && none == "")
    }

    @Test func catchMeUpOnTheFirstChapterHasNoPreviousText() throws {
        let composer = StudyPromptComposer(store: try FixtureStore.make())
        #expect(try composer.previousChapter(of: ChapterLocation(book: "MAT", chapter: 1), translationID: "WEB") == nil)
        #expect(try composer.previousChapter(of: ChapterLocation(book: "MAT", chapter: 5), translationID: "WEB")?.first?.id.chapter == 4)
    }
}
