import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct LibraryListTests {
    /// Genesis, Obadiah, Malachi, Matthew, John, Romans, Philemon, Revelation and Tobit, in the
    /// store's order (the Apocrypha sorts after the New Testament), with their chapter counts.
    private static let books: [TranslationBook] = [
        ("GEN", 50), ("OBA", 1), ("MAL", 4), ("MAT", 28), ("JHN", 21), ("ROM", 16), ("PHM", 1), ("REV", 22), ("TOB", 14),
    ].map { code, count in TranslationBook(book: BookCatalog.book(code: code)!, chapterCount: count) }

    private static func ids(_ entries: [TranslationBook]) -> [String] { entries.map(\.book.id) }

    @Test func eachBookIsInItsTestamentAndTheApocryphaIsWithTheOld() throws {
        #expect(LibraryList.testament(of: try #require(BookCatalog.book(code: "GEN"))) == .old)
        #expect(LibraryList.testament(of: try #require(BookCatalog.book(code: "MAL"))) == .old)
        #expect(LibraryList.testament(of: try #require(BookCatalog.book(code: "MAT"))) == .new)
        #expect(LibraryList.testament(of: try #require(BookCatalog.book(code: "REV"))) == .new)
        #expect(LibraryList.testament(of: try #require(BookCatalog.book(code: "TOB"))) == .old)
    }

    @Test func testamentsAreTitledForTheSegmentedControl() {
        #expect(LibraryList.Testament.allCases.map(\.title) == ["Old Testament", "New Testament"])
    }

    @Test func opensOnTheBookBeingReadWithItsBookOpen() {
        let list = LibraryList(books: Self.books, current: ChapterLocation(book: "JHN", chapter: 15))
        #expect(list.testament == .new)
        #expect(list.openBookID == "JHN")
        #expect(Self.ids(list.shownBooks) == ["MAT", "JHN", "ROM", "PHM", "REV"])
    }

    @Test func opensOnTheOldTestamentWithNothingOpenWhenNothingIsRead() {
        let list = LibraryList(books: Self.books, current: nil)
        #expect(list.testament == .old)
        #expect(list.openBookID == nil)
        #expect(Self.ids(list.shownBooks) == ["GEN", "OBA", "MAL", "TOB"])
    }

    @Test func aPlaceInABookTheTranslationLacksOpensNothing() {
        let list = LibraryList(books: Self.books, current: ChapterLocation(book: "1MA", chapter: 2))
        #expect(list.testament == .old)
        #expect(list.openBookID == nil)
    }

    @Test func tappingABookOpensItAndTappingItAgainClosesIt() {
        var list = LibraryList(books: Self.books, current: nil)
        list.tap(bookID: "GEN")
        #expect(list.openBookID == "GEN")
        list.tap(bookID: "GEN")
        #expect(list.openBookID == nil)
    }

    @Test func openingAnotherBookClosesTheFirst() {
        var list = LibraryList(books: Self.books, current: ChapterLocation(book: "JHN", chapter: 15))
        list.tap(bookID: "ROM")
        #expect(list.openBookID == "ROM")
    }

    /// Matt, 2026-11-16: with the reference icons under a book's name, a name that read its one
    /// chapter at once no longer said so. A book of one chapter opens like any other, showing its
    /// icons and its single chapter, "1".
    @Test func aBookOfOneChapterOpensLikeAnyOther() {
        var list = LibraryList(books: Self.books, current: ChapterLocation(book: "JHN", chapter: 15))
        list.tap(bookID: "PHM")
        #expect(list.openBookID == "PHM")
        list.tap(bookID: "PHM")
        #expect(list.openBookID == nil)
    }

    @Test func aOneChapterBookBeingReadOpensWithIt() {
        let list = LibraryList(books: Self.books, current: ChapterLocation(book: "OBA", chapter: 1))
        #expect(list.testament == .old)
        #expect(list.openBookID == "OBA")
        #expect(list.readingBookID == "OBA")
    }

    @Test func theBookBeingReadIsKnownWhetherOrNotItOpens() {
        #expect(LibraryList(books: Self.books, current: ChapterLocation(book: "JHN", chapter: 15)).readingBookID == "JHN")
        #expect(LibraryList(books: Self.books, current: nil).readingBookID == nil)
        #expect(LibraryList(books: Self.books, current: ChapterLocation(book: "1MA", chapter: 2)).readingBookID == nil)
    }

    @Test func switchingTestamentShowsItsBooksAndKeepsTheOpenBook() {
        var list = LibraryList(books: Self.books, current: ChapterLocation(book: "JHN", chapter: 15))
        list.testament = .old
        #expect(Self.ids(list.shownBooks) == ["GEN", "OBA", "MAL", "TOB"])
        list.testament = .new
        #expect(list.openBookID == "JHN")
    }

    /// Spec 4.5: the iPhone's headers. All 66 books and one Apocrypha book.
    @Test func eachTestamentListsItsGroupsInOrderAndEveryBookIsInExactlyOne() throws {
        let all = BookCatalog.all.filter { $0.canon != .apocrypha } + [try #require(BookCatalog.book(code: "TOB"))]
        let books = all.map { TranslationBook(book: $0, chapterCount: 3) }
        var list = LibraryList(books: books, current: nil)
        #expect(list.shownSections.map(\.group) == [.law, .history, .poetryAndWisdom, .majorProphets, .minorProphets, .apocrypha])
        let old = list.shownSections.flatMap(\.books)
        #expect(old.map(\.book.id) == list.shownBooks.map(\.book.id) && old.count == 40)
        list.testament = .new
        #expect(list.shownSections.map(\.group) == [.gospelsAndActs, .paulsLetters, .generalLetters, .revelation])
        #expect(list.shownSections.flatMap(\.books).map(\.book.id) == list.shownBooks.map(\.book.id))
        #expect(list.shownSections.allSatisfy { !$0.books.isEmpty })
    }

    /// Library reopened on a Library page opens that page's book; the book being read stays the reading book.
    @Test func aLibraryPageOpensItsBookInPlaceOfTheOneBeingRead() {
        let books = Self.books + [TranslationBook(book: BookCatalog.book(code: "PSA")!, chapterCount: 150)]
        let list = LibraryList(books: books, current: ChapterLocation(book: "MAT", chapter: 1), opening: "PSA")
        #expect(list.testament == .old && list.openBookID == "PSA" && list.readingBookID == "MAT")
        let missing = LibraryList(books: books, current: ChapterLocation(book: "MAT", chapter: 1), opening: "1MA")
        #expect(missing.testament == .new && missing.openBookID == "MAT")
    }

    @Test func aGroupWithNoBooksIsLeftOut() {
        var list = LibraryList(books: Self.books, current: nil)
        #expect(list.shownSections.map(\.group) == [.law, .history, .poetryAndWisdom, .majorProphets, .minorProphets, .apocrypha].filter { [.law, .minorProphets, .apocrypha].contains($0) })
        list.testament = .new
        #expect(list.shownSections.map(\.group) == [.gospelsAndActs, .paulsLetters, .revelation])
    }
}
