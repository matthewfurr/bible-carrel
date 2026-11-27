import Testing
@testable import ScriptureData

@Suite struct ReferenceParserTests {
    @Test func parsesCommonForms() {
        let rom = ReferenceParser.parse("Rom 8")
        #expect(rom?.book.id == "ROM")
        #expect(rom?.chapter == 8)
        #expect(rom?.verse == nil)

        let john = ReferenceParser.parse("John 3:16")
        #expect(john?.book.id == "JHN")
        #expect(john?.chapter == 3)
        #expect(john?.verse == 16)

        let cor = ReferenceParser.parse("1 Cor 13:4-7")
        #expect(cor?.book.id == "1CO")
        #expect(cor?.verse == 4)
        #expect(cor?.endVerse == 7)

        #expect(ReferenceParser.parse("1cor13")?.chapter == 13)
        #expect(ReferenceParser.parse("Song of Songs 2:1")?.book.id == "SNG")
        #expect(ReferenceParser.parse("ps 23")?.book.id == "PSA")
    }

    @Test func normalisesCaseWhitespaceAndDashes() {
        #expect(ReferenceParser.parse("  MATT 5:3–7  ")?.endVerse == 7)   // en dash
        #expect(ReferenceParser.parse("matt.5.3")?.verse == 3)
    }

    @Test func bookOnly() {
        let r = ReferenceParser.parse("Genesis")
        #expect(r?.book.id == "GEN")
        #expect(r?.chapter == nil)
    }

    @Test func rejectsUnknownAndNonsense() {
        #expect(ReferenceParser.parse("Hezekiah 3:1") == nil)
        #expect(ReferenceParser.parse("") == nil)
        #expect(ReferenceParser.parse("3:16") == nil)
        #expect(ReferenceParser.parse("John 0:1") == nil)
        #expect(ReferenceParser.parse("John 3:16-2") == nil)
    }

    @Test func prefixMatchingInCanonOrder() {
        #expect(ReferenceParser.matchBooks(prefix: "J").map(\.id) == ["JOS", "JDG", "JOB", "JER", "JOL", "JON", "JHN", "JAS", "JUD", "JDT"])
        #expect(ReferenceParser.matchBooks(prefix: "Jud").map(\.id) == ["JDG", "JUD", "JDT"])
        #expect(ReferenceParser.matchBooks(prefix: "Zzz").isEmpty)
    }

    @Test func displayString() {
        #expect(ReferenceParser.parse("1 Cor 13:4-7")?.displayString == "1 Corinthians 13:4-7")
        #expect(ReferenceParser.parse("ps 23")?.displayString == "Psalm 23")       // singular for one psalm
        #expect(ReferenceParser.parse("ps 23:1")?.displayString == "Psalm 23:1")
        #expect(ReferenceParser.parse("Psalms")?.displayString == "Psalms")        // the whole book keeps the plural
        #expect(ReferenceParser.parse("John")?.displayString == "John")
        #expect(BookCatalog.book(code: "PSA")?.chapterName == "Psalm")
        #expect(BookCatalog.book(code: "MAT")?.chapterName == "Matthew")
    }
}
