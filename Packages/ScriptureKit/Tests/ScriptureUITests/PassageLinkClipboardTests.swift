import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct PassageLinkClipboardTests {
    @Test func theClipboardCarriesTheURLAndTheTitledLink() throws {
        let john = Reference(book: BookCatalog.book(code: "JHN")!, chapter: 3, verse: 16, endVerse: 18)
        let clipboard = PassageLinkClipboard(link: PassageLink(reference: john), scheme: "bible-dev")
        #expect(clipboard.plain == "bible-dev://jhn.3.16-18" && clipboard.url.absoluteString == clipboard.plain)
        #expect(clipboard.title == "John 3:16\u{2013}18")
        #expect(clipboard.html == "<a href=\"bible-dev://jhn.3.16-18\">John 3:16\u{2013}18</a>")
        let rtf = String(decoding: try #require(clipboard.rtf()), as: UTF8.self)
        #expect(rtf.contains("HYPERLINK \"bible-dev://jhn.3.16-18\""))
        let one = PassageLinkClipboard(link: PassageLink(reference: Reference(book: john.book, chapter: 3, verse: 16)), scheme: "bible")
        #expect(one.title == "John 3:16" && one.plain == "bible://jhn.3.16")
    }
}
