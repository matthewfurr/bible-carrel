import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ReaderDocumentTests {
    /// Eight chapters of four verses each.
    private func book(chapters: Int = 8, translation: String = "WEB") -> BookText {
        var map: [Int: [Verse]] = [:]
        for chapter in 1...chapters {
            map[chapter] = (1...4).map {
                Verse(id: VerseLocation(book: "JHN", chapter: chapter, verse: $0), translationID: translation,
                      text: "Chapter \(chapter) verse \($0) text.", breakAfter: false)
            }
        }
        return BookText(book: "JHN", translationID: translation, chapters: map)
    }

    private func document() throws -> ReaderDocument {
        ReaderDocument(store: try FixtureStore.make())
    }

    private func target(_ chapter: Int) -> ChapterLocation { ChapterLocation(book: "JHN", chapter: chapter) }

    @Test func showingAChapterBuildsThatChapterAlone() throws {
        let document = ReaderDocument(store: try FixtureStore.make())
        document.show(book(), target: ChapterLocation(book: "JHN", chapter: 3), typography: .default)
        #expect(document.window == 3...3)
        #expect(document.layout?.chapters == 3...3)
        #expect(document.layout?.sections.count == 1)
    }

    @Test func showingAnotherChapterRebuildsWithOnlyThatChapter() throws {
        let document = ReaderDocument(store: try FixtureStore.make())
        let john = book()
        document.show(john, target: ChapterLocation(book: "JHN", chapter: 3), typography: .default)
        document.show(john, target: ChapterLocation(book: "JHN", chapter: 4), typography: .default)
        #expect(document.layout?.chapters == 4...4)
    }

    /// Matt, 2026-11-13: a later chapter's page carries no label, only its empty hairline.
    @Test func chapterOneOpensWithTheTitleBlockAndLaterChaptersOnAnEmptyHairline() throws {
        let document = ReaderDocument(store: try FixtureStore.make())
        let john = book()
        func opening(_ chapter: Int) throws -> String {
            document.show(john, target: ChapterLocation(book: "JHN", chapter: chapter), typography: .default)
            let layout = try #require(document.layout)
            return (layout.attributedString.string as NSString).substring(with: layout.sections[0].openingRange)
        }
        #expect(try opening(1).contains("John"))
        #expect(try !opening(3).contains("John"))
        #expect(try opening(3) == "\u{2060}\n")
        #expect(document.layout?.opensWithTitleBlock == false)
    }

    @Test func showingTheSameChapterAgainDoesNotRebuild() throws {
        let doc = try document()
        doc.show(book(), target: target(4), typography: .default)
        let layout = try #require(doc.layout)
        doc.show(book(), target: target(4), typography: .default)
        #expect(doc.layout?.attributedString === layout.attributedString)
        #expect(doc.window == 4...4)
    }

    @Test func anEmptyBookShowsNothing() throws {
        let doc = try document()
        doc.show(BookText(book: "JHN", translationID: "WEB", chapters: [:]), target: target(1), typography: .default)
        #expect(doc.layout == nil && doc.window == nil)
    }

    @Test func aTargetTheBookLacksClampsIntoTheBook() throws {
        let doc = try document()
        doc.show(book(chapters: 3), target: target(40), typography: .default)
        #expect(doc.window == 3...3)
        #expect(doc.layout?.chapters == 3...3)
    }

    @Test func typographyChangeRebuildsTheSameChapter() throws {
        let doc = try document()
        doc.show(book(), target: target(4), typography: .default)
        let window = doc.window
        let before = doc.layout?.id.typography
        var prefs = ReaderPreferences.default
        prefs.fontSize += 4
        doc.show(book(), target: target(4), typography: .styled(prefs))
        #expect(doc.window == window)
        #expect(doc.layout?.id.typography != before)
    }

    @Test func aTranslationChangeRebuilds() throws {
        let doc = try document()
        doc.show(book(), target: target(4), typography: .default)
        doc.show(book(translation: "KJV"), target: target(4), typography: .default)
        #expect(doc.layout?.id.translationID == "KJV")
    }

    private struct FetchFailure: Error {}

    /// Final review: a failed headings fetch is retried on a later `show` no sooner than the
    /// retry interval after it, and the chapter is rebuilt only when a retry succeeds, as a layout
    /// with a new id (its `content`), so the controllers take it.
    @Test func aFailedHeadingsFetchIsRetriedAfterAWhileAndRebuildsOnlyWhenItSucceeds() throws {
        let doc = try document()
        let start = ContinuousClock.now
        var elapsed: Duration = .zero
        var fetches = 0
        var fails = true
        doc.now = { start + elapsed }
        doc.fetchHeadings = { _, _ in
            fetches += 1
            if fails { throw FetchFailure() }
            return [VerseLocation(book: "JHN", chapter: 4, verse: 1): [SectionHeading(text: "Found on a Retry", level: 1)]]
        }
        doc.show(book(), target: target(4), typography: .default)
        let failed = try #require(doc.layout)
        #expect(fetches == 1)

        // Within the interval nothing is fetched: not on showing the chapter again (nor rebuilt),
        // not on moving to another one.
        doc.show(book(), target: target(4), typography: .default)
        #expect(fetches == 1 && doc.layout?.attributedString === failed.attributedString)
        doc.show(book(), target: target(5), typography: .default)
        #expect(fetches == 1 && doc.layout?.chapters == 5...5)
        doc.show(book(), target: target(4), typography: .default)
        let shown = try #require(doc.layout)
        #expect(shown.id == failed.id)

        // After it, a retry that fails again rebuilds nothing, and waits another interval.
        elapsed += .seconds(31)
        doc.show(book(), target: target(4), typography: .default)
        #expect(fetches == 2 && doc.layout?.attributedString === shown.attributedString)
        elapsed += .seconds(10)
        doc.show(book(), target: target(4), typography: .default)
        #expect(fetches == 2)

        // One that succeeds rebuilds the same chapter with the headings, under a new id.
        fails = false
        elapsed += .seconds(31)
        doc.show(book(), target: target(4), typography: .default)
        let found = try #require(doc.layout)
        #expect(fetches == 3)
        #expect(found.id != failed.id && found.id.content != failed.id.content && found.chapters == failed.chapters)
        #expect(found.attributedString.string.contains("Found on a Retry"))
        // Loaded: never fetched again for this book.
        elapsed += .seconds(120)
        doc.show(book(), target: target(4), typography: .default)
        #expect(fetches == 3 && doc.layout?.id == found.id)

        // A different book (here, translation) fetches at once.
        doc.show(book(translation: "KJV"), target: target(4), typography: .default)
        #expect(fetches == 4)
    }

    /// Two layouts with the same id have the same string: the id's `content` follows the opening
    /// and the headings, and is the book's, so every chapter of the book shares it.
    @Test func theLayoutIDFollowsTheHeadingsAndTheOpening() throws {
        let inputs = JohnFixture.inputs(1...3)
        let bare = inputs.map { BookChapterInput(location: $0.location, verses: $0.verses) }
        let typography = ReaderTypography.default
        let withHeadings = BookLayout.build(chapters: inputs, opening: JohnFixture.opening, typography: typography)
        let again = BookLayout.build(chapters: inputs, opening: JohnFixture.opening, typography: typography)
        let without = BookLayout.build(chapters: bare, opening: JohnFixture.opening, typography: typography)
        let retitled = BookLayout.build(chapters: inputs, opening: BookOpening(bookName: "John", title: BookTitle(title: "John", subtitle: nil)),
                                        typography: typography)
        #expect(withHeadings.id == again.id && withHeadings.attributedString.isEqual(to: again.attributedString))
        #expect(withHeadings.id != without.id && withHeadings.attributedString.string != without.attributedString.string)
        #expect(withHeadings.id != retitled.id)

        let doc = try document()
        doc.show(book(), target: target(4), typography: .default)
        let before = try #require(doc.layout)
        doc.show(book(), target: target(3), typography: .default)
        #expect(doc.layout?.id.content == before.id.content && doc.layout?.id != before.id)
    }
}
