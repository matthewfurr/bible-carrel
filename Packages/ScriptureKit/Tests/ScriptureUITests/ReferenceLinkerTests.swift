import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct ReferenceLinkerTests {
    private let john = BookCatalog.book(code: "JHN")!
    private let matthew = BookCatalog.book(code: "MAT")!

    /// Chapter counts for the books these tests name; any other book is unknown.
    private static let chapterCounts = ["JHN": 21, "1JN": 5, "PSA": 150, "MAT": 28, "SNG": 8]

    private func refs(_ text: String, context: Book? = nil) -> [Reference] {
        ReferenceLinker.references(in: text, contextBook: context, chapterCount: { Self.chapterCounts[$0] }).map(\.reference)
    }

    @Test func findsFullReferencesAndRanges() {
        let found = refs("the Spirit remains (John 1:32); see 1 John 2:6 and Ps 91:1, also John 15:4-5.")
        #expect(found.map(\.displayString) == ["John 1:32", "1 John 2:6", "Psalm 91:1", "John 15:4-5"])
    }

    @Test func theRangeCoversTheWholeReference() {
        let text = "see 1 John 2:6 and Song of Solomon 2:1\u{2013}3."
        let found = ReferenceLinker.references(in: text, contextBook: nil, chapterCount: { Self.chapterCounts[$0] })
        #expect(found.map { String(text[$0.range]) } == ["1 John 2:6", "Song of Solomon 2:1\u{2013}3"])
        #expect(found.map(\.reference.displayString) == ["1 John 2:6", "Song of Solomon 2:1-3"])
    }

    @Test func aLeadingCapitalisedWordIsNotPartOfTheBook() {
        let text = "In John 1:32 the Spirit remains."
        let found = ReferenceLinker.references(in: text, contextBook: nil, chapterCount: { Self.chapterCounts[$0] })
        #expect(found.map(\.reference) == [Reference(book: john, chapter: 1, verse: 32)])
        #expect(found.map { String(text[$0.range]) } == ["John 1:32"])
    }

    @Test func bareChapterVerseNeedsAContextBook() {
        #expect(refs("see 5:3", context: nil).isEmpty)
        #expect(refs("see 5:3", context: matthew).map(\.displayString) == ["Matthew 5:3"])
    }

    @Test func timesAndRatiosAreNotVerses() {
        #expect(refs("We meet at 3:30 pm or 10:45 a.m.", context: john).isEmpty)
        #expect(refs("We meet at 3:30PM or 10:45 A.M.", context: john).isEmpty)
        #expect(refs("version 12:3:4", context: john).isEmpty)
    }

    @Test func aReferenceBeforeAColonIsLinked() {
        #expect(refs("John 3:16: For God so loved the world").map(\.displayString) == ["John 3:16"])
        #expect(refs("**Romans 8:28:** And we know").map(\.displayString) == ["Romans 8:28"])
        #expect(refs("see John 15:4-5: abide in me").map(\.displayString) == ["John 15:4-5"])
    }

    @Test func aChapterPastTheBookIsNotLinked() {
        #expect(refs("John 40:1").isEmpty)
        #expect(refs("see 40:1", context: john).isEmpty)
        #expect(refs("John 21:25").map(\.displayString) == ["John 21:25"])
    }

    @Test func aChapterAloneIsNotLinked() {
        #expect(refs("John 15").isEmpty)
        #expect(refs("Read John 15 tonight", context: john).isEmpty)
    }

    @Test func urlRoundTrips() {
        let verse = Reference(book: BookCatalog.book(code: "1JN")!, chapter: 2, verse: 6)
        let range = Reference(book: john, chapter: 15, verse: 4, endVerse: 5)
        #expect(ReferenceLinker.url(for: verse).absoluteString == "scripture://1JN/2/6")
        #expect(ReferenceLinker.url(for: range).absoluteString == "scripture://JHN/15/4-5")
        #expect(ReferenceLinker.reference(from: ReferenceLinker.url(for: verse)) == verse)
        #expect(ReferenceLinker.reference(from: ReferenceLinker.url(for: range)) == range)
        #expect(ReferenceLinker.reference(from: URL(string: "https://example.com/JHN/15/4")!) == nil)
        #expect(ReferenceLinker.reference(from: URL(string: "scripture://XYZ/1/1")!) == nil)
    }

    @Test func linkedSetsLinksAndLeavesCodeAndExistingLinksAlone() {
        let source = NoteMarkdown.document("Abide (John 15:4). Not `John 3:16`, nor [John 1:1](https://example.com), but 5:3.")
        let linked = ReferenceLinker.linked(source, contextBook: matthew, chapterCount: { Self.chapterCounts[$0] })
        #expect(String(linked.characters) == String(source.characters))
        let links = linked.runs.compactMap { run in run.link.map { (String(linked[run.range].characters), $0.absoluteString) } }
        #expect(links.map(\.0) == ["John 15:4", "John 1:1", "5:3"])
        #expect(links.map(\.1) == ["scripture://JHN/15/4", "https://example.com", "scripture://MAT/5/3"])
        let code = linked.runs.first { $0.inlinePresentationIntent?.contains(.code) == true }
        #expect(code.map { String(linked[$0.range].characters) } == "John 3:16")
        #expect(code?.link == nil)
    }

    /// The reply row's VoiceOver actions: one per linked reference, each once, in reading order.
    @Test func aReplyOffersEachLinkedReferenceOnce() {
        let reply = "Menō, to remain (**John 1:32**); whoever abides ought to walk as he walked (1 John 2:6). Again John 1:32, but not `John 3:16`."
        let linked = ReferenceLinker.linked(NoteMarkdown.document(reply), contextBook: nil, chapterCount: { Self.chapterCounts[$0] })
        #expect(ChatTurnRow.linkedReferences(in: linked).map(\.displayString) == ["John 1:32", "1 John 2:6"])
    }

    // MARK: - Notes (spec 3.2, Matt 2026-11-12: "my typing in Gen 1:1 should become a link")

    private static let noteCounts = ["JHN": 21, "GEN": 50, "ROM": 16, "MRK": 16, "ACT": 28, "1CO": 16, "ISA": 66, "JOB": 42, "EXO": 40]

    private func noteRefs(_ text: String, book: Book? = nil) -> [Reference] {
        ReferenceLinker.references(in: text, contextBook: book, rules: .note, chapterCount: { Self.noteCounts[$0] }).map(\.reference)
    }

    @Test func aNoteLinksBookNamesInAnyCase() {
        #expect(noteRefs("see GEN 1:1, gen 1:2 and Gen 1:3").map(\.displayString) == ["Genesis 1:1", "Genesis 1:2", "Genesis 1:3"])
        #expect(noteRefs("compare 1 cor 13:4-7").map(\.displayString) == ["1 Corinthians 13:4-7"])
    }

    /// Lower-case words of one or two letters are words, not books: "is 5:3" is not Isaiah.
    @Test func aShortLowerCaseWordIsNotABook() {
        #expect(noteRefs("this is 5:3 in the list").isEmpty)
        #expect(noteRefs("this IS 5:3").map(\.displayString) == ["Isaiah 5:3"])
        #expect(noteRefs("ex 4:2 or Ex 4:2").map(\.displayString) == ["Exodus 4:2"])
        // Common words are not books; a book's own short name typed in lower case is.
        #expect(noteRefs("see the 3:16 and for 2:1, at 5:30 pm").isEmpty)
        #expect(noteRefs("mat 1:1 and act 3:2").map(\.displayString) == ["Matthew 1:1", "Acts 3:2"])
    }

    @Test func aBareVerseInANoteIsInTheNotesBook() {
        let john = BookCatalog.book(code: "JHN")!
        #expect(noteRefs("see GEN 1:1, Rom 8 and 5:3", book: john).map(\.displayString) == ["Genesis 1:1", "Romans 8", "John 5:3"])
    }

    /// A chapter alone links only behind a capital ("Romans 8", "ROM 8"), so prose like "mark 2
    /// items" or "acts 1 by one" never does; a chapter past the book's end does not either.
    @Test func aChapterAloneLinksInANoteOnlyBehindACapital() {
        #expect(noteRefs("read Romans 8 and ROM 8 tonight").map(\.displayString) == ["Romans 8", "Romans 8"])
        #expect(noteRefs("mark 2 items, acts 1 by one").isEmpty)
        #expect(noteRefs("Romans 17 is not there").isEmpty)
        #expect(noteRefs("Romans 8:28 and Romans 8").map(\.displayString) == ["Romans 8:28", "Romans 8"])
        // A chapter range is left alone, as is a number that is part of a larger one.
        #expect(noteRefs("Romans 1-3, Romans 12.5").isEmpty)
    }

    /// Replies keep their rules: book names need a capital, and a chapter alone never links.
    @Test func repliesKeepTheirRules() {
        #expect(refs("see gen 1:1 and Romans 8").isEmpty)
        #expect(refs("see bible://jhn.3.16").isEmpty)
    }

    @Test func aPassageLinkInANoteIsALinkLikeAnyReference() throws {
        let blocks = NoteBodyText.blocks("See bible://jhn.3.16-18 and [this](bible-dev://rom.8).", book: nil,
                                         chapterCount: { Self.noteCounts[$0] })
        try #require(blocks.count == 1)
        #expect(ChatTurnRow.linkedReferences(in: blocks[0]).map(\.displayString) == ["John 3:16-18", "Romans 8"])
        // One to a chapter the book lacks stays text, as "Romans 17" does.
        let lacking = NoteBodyText.blocks("bible://rom.17", book: nil, chapterCount: { Self.noteCounts[$0] })
        #expect(ChatTurnRow.linkedReferences(in: lacking[0]).isEmpty)
    }

    @Test func aLinkAtTheEndOfASentenceLeavesTheFullStopOut() {
        let text = "Read bible://jhn.3.16. Then (bible-dev://rom.8), and bible:psa.23!"
        #expect(ReferenceLinker.passageLinks(in: text).map { String(text[$0.range]) } == ["bible://jhn.3.16", "bible-dev://rom.8", "bible:psa.23"])
        #expect(ReferenceLinker.passageLinks(in: "the bible: a library").isEmpty)
    }

    /// A note is text anyone typed or pasted: none of these is a link, and each is read promptly.
    @Test func hostileTextMakesNoPassageLink() {
        let runOfSchemes = String(String(repeating: "bible:", count: 100_000 / 6 + 1).prefix(100_000))
        let longPath = "bible:" + String(repeating: "a", count: 100_000)
        for text in [runOfSchemes, longPath, "bible:%", "bible://", "a note that ends bible-dev:"] {
            let clock = ContinuousClock()
            var found: [(range: Range<String.Index>, reference: Reference)] = []
            let took = clock.measure { found = ReferenceLinker.passageLinks(in: text) }
            #expect(found.isEmpty, "\(text.prefix(40))")
            #expect(took < .seconds(2), "\(text.prefix(40)) took \(took)")
        }
        #expect(ReferenceLinker.passageLinks(in: "see bible:is.").isEmpty)       // a word, not Isaiah
    }

    @Test func aChapterLinkRoundTrips() {
        let romans8 = Reference(book: BookCatalog.book(code: "ROM")!, chapter: 8)
        #expect(ReferenceLinker.url(for: romans8).absoluteString == "scripture://ROM/8")
        #expect(ReferenceLinker.reference(from: ReferenceLinker.url(for: romans8)) == romans8)
    }

    /// A note reads as rendered markdown with its references linked, found as it is shown; with
    /// nowhere to lead (no `NoteLinks`), it stays plain.
    @Test func aNotesBlocksCarryTheirLinks() throws {
        let blocks = NoteBodyText.blocks("**Q:** what of *Rom 8*?\n\nSee 5:3.", book: BookCatalog.book(code: "JHN"),
                                         chapterCount: { Self.noteCounts[$0] })
        #expect(blocks.map { String($0.characters) } == ["Q: what of Rom 8?", "See 5:3."])
        try #require(blocks.count == 2)
        #expect(ChatTurnRow.linkedReferences(in: blocks[0]).map(\.displayString) == ["Romans 8"])
        #expect(ChatTurnRow.linkedReferences(in: blocks[1]).map(\.displayString) == ["John 5:3"])
        let plain = NoteBodyText.blocks("See Rom 8.", book: nil, chapterCount: nil)
        #expect(plain.allSatisfy { ChatTurnRow.linkedReferences(in: $0).isEmpty })
    }
}
