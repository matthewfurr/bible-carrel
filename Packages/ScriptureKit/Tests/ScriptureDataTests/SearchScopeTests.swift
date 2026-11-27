import Testing
@testable import ScriptureData

/// ⌃Tab and ⌃⇧Tab in the Mac's palette step the scope menu's top level: Whole Bible, each section
/// the translation has, then This Book when a chapter is open, and round again.
@Suite struct SearchScopeTests {
    private func books(_ codes: [String]) -> [TranslationBook] {
        codes.compactMap { BookCatalog.book(code: $0) }.map { TranslationBook(book: $0, chapterCount: 1) }
    }

    private let protestant = ["GEN", "PSA", "MAT", "JHN"]
    private let withApocrypha = ["GEN", "PSA", "TOB", "MAT", "JHN"]
    private var john: Book { BookCatalog.book(code: "JHN")! }

    /// Every scope `step` reaches from Whole Bible until it comes round again.
    private func cycle(_ codes: [String], currentBook: Book?, by step: Int) -> [SearchScope] {
        var scope = SearchScope.wholeBible
        var seen: [SearchScope] = []
        repeat {
            seen.append(scope)
            scope = SearchScope.next(after: scope, in: books(codes), currentBook: currentBook, by: step)
        } while scope != .wholeBible && seen.count < 10
        return seen
    }

    @Test func forwardGoesRoundTheMenusTopLevel() {
        #expect(cycle(protestant, currentBook: nil, by: 1) == [.wholeBible, .oldTestament, .newTestament])
        #expect(cycle(withApocrypha, currentBook: nil, by: 1) == [.wholeBible, .oldTestament, .newTestament, .apocrypha])
        #expect(cycle(protestant, currentBook: john, by: 1) == [.wholeBible, .oldTestament, .newTestament, .book("JHN")])
        #expect(cycle(withApocrypha, currentBook: john, by: 1) == [.wholeBible, .oldTestament, .newTestament, .apocrypha, .book("JHN")])
        #expect(cycle(["MAT", "JHN"], currentBook: nil, by: 1) == [.wholeBible, .newTestament])
    }

    @Test func backGoesRoundTheOtherWay() {
        #expect(cycle(protestant, currentBook: nil, by: -1) == [.wholeBible, .newTestament, .oldTestament])
        #expect(cycle(withApocrypha, currentBook: john, by: -1) == [.wholeBible, .book("JHN"), .apocrypha, .newTestament, .oldTestament])
    }

    @Test func thisBookWrapsToTheWholeBibleAndBackToTheLastSection() {
        let all = books(withApocrypha)
        #expect(SearchScope.next(after: .book("JHN"), in: all, currentBook: john, by: 1) == .wholeBible)
        #expect(SearchScope.next(after: .book("JHN"), in: all, currentBook: john, by: -1) == .apocrypha)
        #expect(SearchScope.next(after: .wholeBible, in: all, currentBook: john, by: -1) == .book("JHN"))
    }

    /// A book chosen with the pointer from the Book submenu is not on the list: forward goes to
    /// Whole Bible, back to the list's last.
    @Test func anotherSingleBookStepsOntoTheList() {
        let all = books(withApocrypha)
        #expect(SearchScope.next(after: .book("PSA"), in: all, currentBook: john, by: 1) == .wholeBible)
        #expect(SearchScope.next(after: .book("PSA"), in: all, currentBook: john, by: -1) == .book("JHN"))
        #expect(SearchScope.next(after: .book("PSA"), in: all, currentBook: nil, by: -1) == .apocrypha)
        #expect(SearchScope.next(after: .book("PSA"), in: all, currentBook: nil, by: 1) == .wholeBible)
    }

    /// A section the translation lacks is not on the list either (a recent search's scope, say).
    @Test func aSectionTheTranslationLacksStepsOntoTheList() {
        #expect(SearchScope.next(after: .apocrypha, in: books(protestant), currentBook: nil, by: 1) == .wholeBible)
        #expect(SearchScope.next(after: .apocrypha, in: books(protestant), currentBook: nil, by: -1) == .newTestament)
    }
}
