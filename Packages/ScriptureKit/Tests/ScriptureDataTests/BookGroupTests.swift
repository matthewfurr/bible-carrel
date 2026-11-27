import Testing
@testable import ScriptureData

@Suite struct BookGroupTests {
    @Test func everyBookIsInExactlyOneGroupInCanonOrder() {
        let sixtySix = BookCatalog.all.filter { $0.canon != .apocrypha }
        #expect(sixtySix.count == 66 && sixtySix.allSatisfy { BookGroup.group(of: $0) != .apocrypha && BookGroup.group(of: $0).canon == $0.canon })
        var seen: [BookGroup] = []
        for book in sixtySix where seen.last != BookGroup.group(of: book) { seen.append(BookGroup.group(of: book)) }
        #expect(seen == Array(BookGroup.allCases.dropLast()))                       // each group is one unbroken run
        #expect(sixtySix.count { BookGroup.group(of: $0) == .history } == 12 && sixtySix.count { BookGroup.group(of: $0) == .paulsLetters } == 13)
        #expect(BookGroup.group(of: BookCatalog.book(code: "ACT")!) == .gospelsAndActs && BookGroup.group(of: BookCatalog.book(code: "HEB")!) == .generalLetters)
        #expect(BookCatalog.all.filter { $0.canon == .apocrypha }.allSatisfy { BookGroup.group(of: $0) == .apocrypha })
        #expect(BookGroup.paulsLetters.title == "Paul's Letters" && BookGroup.poetryAndWisdom.title == "Poetry & Wisdom")
    }
}
