import Foundation
import Testing
@testable import ScriptureData

@Suite struct PassageLinkTests {
    private func ref(_ code: String, _ chapter: Int? = nil, _ verse: Int? = nil, _ end: Int? = nil) -> Reference {
        Reference(book: BookCatalog.book(code: code)!, chapter: chapter, verse: verse, endVerse: end)
    }

    private func link(_ text: String) -> PassageLink? { PassageLink(string: text) }

    @Test func theSpecsExamplesParse() {
        #expect(link("bible://jhn.3.16")?.reference == ref("JHN", 3, 16))
        #expect(link("bible://jhn.3.16-18")?.reference == ref("JHN", 3, 16, 18))
        #expect(link("bible://rom.8")?.reference == ref("ROM", 8))
        #expect(link("bible://jhn")?.reference == Reference(book: BookCatalog.book(code: "JHN")!))
        let kjv = link("bible://1co.13.4-7?translation=KJV")
        #expect(kjv?.reference == ref("1CO", 13, 4, 7) && kjv?.translationID == "KJV")
        #expect(link("bible://jhn.3.16")?.translationID == nil)
    }

    @Test func theOtherAcceptedFormsParse() {
        #expect(link("bible://jhn.3.16-jhn.3.18")?.reference == ref("JHN", 3, 16, 18))     // the long range
        #expect(link("bible://jhn.3.16-jhn.4.2")?.reference == ref("JHN", 3, 16))          // into another chapter: its first verse
        #expect(link("bible:jhn.3.16")?.reference == ref("JHN", 3, 16))
        #expect(link("bible-dev://jhn.3.16")?.reference == ref("JHN", 3, 16))
        #expect(link("bible://john.3.16")?.reference == ref("JHN", 3, 16))                 // a path the parser reads
        #expect(link("bible://jhn.3.16?v=esv")?.translationID == "ESV")                    // route.bible's own
        #expect(link("bible://jhn.3.16?TRANSLATION=kjv&utm=x")?.translationID == "KJV")
        #expect(link("bible://jhn.3.16?utm=x")?.translationID == nil)
    }

    @Test func linksTheSystemsParserWouldMangleStillParse() {
        #expect(link("bible://John%203:16")?.reference == ref("JHN", 3, 16))
        if let url = URL(string: "bible://John%203:16") { #expect(PassageLink(url)?.reference == ref("JHN", 3, 16)) }
        #expect(link("BIBLE://JHN.3.16")?.reference == ref("JHN", 3, 16))
        #expect(link("bible://jhn.3.16/")?.reference == ref("JHN", 3, 16))
        #expect(link("bible://jhn.3.16#top")?.reference == ref("JHN", 3, 16))
        #expect(link("bible://1CO.13.4")?.reference == ref("1CO", 13, 4))
    }

    @Test func malformedLinksParseToNothing() {
        for text in ["bible://", "bible:", "bible://xyz.1.1", "bible://jhn.0", "bible://jhn.3.0", "bible://jhn.x",
                     "bible://jhn.3.16.2", "bible://jhn.3.18-16", "bible://jhn.3.16-16", "bible://jhn.3.16-",
                     "bible://jhn.3.16-act", "bible://jhn.3.16-jhn.3.x", "https://route.bible/jhn.3.16",
                     "scripture://JHN/3/16", "jhn.3.16", ""] {
            #expect(link(text) == nil, "\(text)")
        }
        // Hostile: non-ASCII digits, overflow, bad escapes, a lone dot or dash, a chapter range,
        // and a very long path.
        for text in ["bible://jhn.٣.١٦", "bible://jhn.99999999999999999999", "bible://%", "bible://%00", "bible://.",
                     "bible://-", "bible://jhn.3-5", "bible://" + String(repeating: "a", count: 100_000)] {
            #expect(link(text) == nil, "\(text.prefix(40))")
        }
        let empty = link("bible://jhn.3.16?translation=")
        #expect(empty?.reference == ref("JHN", 3, 16) && empty?.translationID == nil)
    }

    /// A link's book is a code, or exactly a book's name, short name or alias: a prefix is the
    /// palette's guess, not a link ("bible://ma" is not Mark). A name of one or two letters
    /// alone is a word ("bible:is" in a note is not Isaiah, though "Is" is its alias).
    @Test func aLinksBookIsExactNeverAPrefix() {
        for text in ["bible://ma", "bible:is", "bible://e", "bible://joh.3.16", "bible://Jn"] {
            #expect(link(text) == nil, "\(text)")
        }
        #expect(link("bible://John%203:16")?.reference == ref("JHN", 3, 16))
        #expect(link("bible://john.3.16")?.reference == ref("JHN", 3, 16))
        #expect(link("bible://Romans")?.reference == Reference(book: BookCatalog.book(code: "ROM")!))
        #expect(link("bible://jn.3.16")?.reference == ref("JHN", 3, 16))       // an alias, with a chapter
        #expect(link("bible://is.53")?.reference == ref("ISA", 53))
        // The palette and a note's plain references still read a prefix.
        #expect(ReferenceParser.parse("joh 3:16")?.book.id == "JHN")
    }

    @Test func aLinkFormatsAndRoundTrips() {
        #expect(PassageLink(reference: ref("JHN", 3, 16, 18)).url(scheme: "bible").absoluteString == "bible://jhn.3.16-18")
        #expect(PassageLink(reference: ref("ROM", 8)).url(scheme: "bible-dev").absoluteString == "bible-dev://rom.8")
        #expect(PassageLink(reference: Reference(book: BookCatalog.book(code: "JHN")!)).url(scheme: "bible").absoluteString == "bible://jhn")
        #expect(PassageLink(reference: ref("1CO", 13, 4, 7), translationID: "KJV").url(scheme: "bible").absoluteString
                == "bible://1co.13.4-7?translation=KJV")
        for reference in [ref("JHN", 3, 16, 18), ref("PSA", 119, 105), ref("ROM", 8)] {
            #expect(PassageLink(PassageLink(reference: reference).url(scheme: "bible"))?.reference == reference)
        }
    }

    @Test func everyBooksCodeRoundTrips() {
        for book in BookCatalog.all {
            let reference = Reference(book: book, chapter: 1, verse: 1)
            let url = PassageLink(reference: reference).url(scheme: "bible")
            #expect(url.absoluteString == "bible://\(book.id.lowercased()).1.1")
            #expect(PassageLink(url)?.reference == reference, "\(book.id)")
        }
    }

    @Test func theBuildsSchemeComesFromItsInfoPlist() {
        #expect(PassageLink.scheme(inInfo: ["PassageURLScheme": "bible-dev"]) == "bible-dev")
        #expect(PassageLink.scheme(inInfo: ["PassageURLScheme": "bible"]) == "bible")
        for info in [nil, [:], ["PassageURLScheme": ""], ["PassageURLScheme": "$(PASSAGE_URL_SCHEME)"], ["PassageURLScheme": "https"]] as [[String: Any]?] {
            #expect(PassageLink.scheme(inInfo: info) == "bible")
        }
    }
}
