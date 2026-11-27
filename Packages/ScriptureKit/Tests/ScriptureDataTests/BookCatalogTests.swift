import Testing
@testable import ScriptureData

@Suite struct BookCatalogTests {
    @Test func catalogHas84BooksInCanonOrder() {
        #expect(BookCatalog.all.count == 84)
        #expect(BookCatalog.all.filter { $0.canon == .oldTestament }.count == 39)
        #expect(BookCatalog.all.filter { $0.canon == .newTestament }.count == 27)
        #expect(BookCatalog.all.filter { $0.canon == .apocrypha }.count == 18)
        #expect(BookCatalog.all.first?.id == "GEN")
        #expect(BookCatalog.all[38].id == "MAL")
        #expect(BookCatalog.all[39].id == "MAT")
        #expect(BookCatalog.all[65].id == "REV")
        #expect(BookCatalog.all.map(\.order) == Array(1...84))
    }

    @Test func lookupByCode() {
        #expect(BookCatalog.book(code: "NAM")?.name == "Nahum")
        #expect(BookCatalog.book(code: "PHP")?.name == "Philippians")
        #expect(BookCatalog.book(code: "SNG")?.name == "Song of Solomon")
        #expect(BookCatalog.book(code: "NAH") == nil)
        #expect(BookCatalog.book(code: "LKA") == nil)
    }
}
