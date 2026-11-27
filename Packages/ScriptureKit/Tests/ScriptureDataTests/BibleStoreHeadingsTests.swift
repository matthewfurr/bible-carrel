import Testing
@testable import ScriptureData

@Suite struct BibleStoreHeadingsTests {
    private func store() throws -> BibleStore {
        try BibleStore(databaseURL: try FixtureDatabase.build())
    }

    @Test func bookChaptersReturnsEveryChapterInOrder() throws {
        let chapters = try store().bookChapters("MAT", translationID: "WEB")
        #expect(chapters.keys.sorted() == Array(1...28))
        #expect(chapters[5]?.count == 48)
        for verses in chapters.values {
            #expect(verses.map(\.id.verse) == verses.map(\.id.verse).sorted())
        }
        #expect(try store().bookChapters("MAT", translationID: "NOPE").isEmpty)
    }

    @Test func headingsAttachToTheNextVerseTheTranslationHas() throws {
        // The fixture heading is at SUS 1:3; WEB's chapter lacks verse 3, so it attaches to 1:4.
        let headings = try store().headings(bookID: "SUS", translationID: "WEB")
        #expect(headings[VerseLocation(book: "SUS", chapter: 1, verse: 4)]?.first?.text == "Fixture Heading")
        #expect(headings[VerseLocation(book: "SUS", chapter: 1, verse: 3)] == nil)
    }

    @Test func aHeadingPastTheChaptersLastVerseIsDropped() throws {
        let headings = try store().headings(bookID: "SUS", translationID: "WEB")
        #expect(headings.count == 1)
        #expect(!headings.values.joined().contains { $0.text == "Past The End" })
    }

    @Test func headingsForOneVerseAreOrderedByOrdinal() throws {
        let headings = try store().headings(bookID: "MAT", translationID: "WEB")
        #expect(headings[VerseLocation(book: "MAT", chapter: 5, verse: 3)]?.map(\.text) == ["First Heading", "Second Heading"])
        #expect(headings[VerseLocation(book: "MAT", chapter: 5, verse: 3)]?.map(\.level) == [1, 2])
    }

    @Test func theCPDVGetsNoBorrowedHeadings() throws {
        #expect(try store().headings(bookID: "MAT", translationID: "CPDV").isEmpty)
    }

    @Test func kjvTakesItsOwnSubtitleOthersTheAppTable() throws {
        let store = try store()
        #expect(try store.bookTitle(bookID: "PSA", translationID: "KJV") == BookTitle(title: "Psalms", subtitle: "The Book of Psalms"))
        #expect(try store.bookTitle(bookID: "MAT", translationID: "WEB") == BookTitle(title: "Matthew", subtitle: "The Gospel According to Matthew"))
        #expect(try store.bookTitle(bookID: "PSA", translationID: "WEB") == BookTitle(title: "Psalms", subtitle: nil))
        #expect(try store.bookTitle(bookID: "SUS", translationID: "WEB") == BookTitle(title: "Susanna", subtitle: nil))
    }

    @Test func everyCanonBookHasAnAppTitle() {
        for book in BookCatalog.all where book.canon != .apocrypha {
            #expect(BookTitles.app(for: book.id) != nil, "\(book.id)")
        }
        for book in BookCatalog.all where book.canon == .apocrypha {
            #expect(BookTitles.app(for: book.id) == nil, "\(book.id)")
        }
        #expect(BookTitles.app(for: "GEN") == BookTitle(title: "Genesis", subtitle: "The First Book of Moses"))
        #expect(BookTitles.app(for: "ROM")?.subtitle == "The Letter of Paul to the Romans")
        #expect(BookTitles.app(for: "PSA") == BookTitle(title: "Psalms", subtitle: nil))
    }
}
