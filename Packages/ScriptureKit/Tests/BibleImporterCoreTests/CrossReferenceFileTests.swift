import Foundation
import Testing
@testable import BibleImporterCore
import ScriptureData

@Suite struct CrossReferenceFileTests {
    let header = "From Verse\tTo Verse\tVotes\t#www.openbible.info CC-BY 2026-09-21\n"

    func links(_ text: String) -> [CrossReferenceLink] {
        var warnings: [ImportWarning] = []
        let result = CrossReferenceFile.parse(header + text, warnings: &warnings)
        #expect(warnings.isEmpty)
        return result
    }

    func link(_ source: Int, _ start: Int, _ end: Int, _ votes: Int) -> CrossReferenceLink {
        CrossReferenceLink(source: source, targetStart: start, targetEnd: end, votes: votes)
    }

    @Test func singleVersesRangesAndThirdJohnLandAsExpected() {
        #expect(links("Matt.5.3\tPs.1.1\t12") == [link(40005003, 19001001, 19001001, 12)])
        #expect(links("Matt.5.3\tMatt.6.19-Matt.6.21\t9") == [link(40005003, 40006019, 40006021, 9)])       // inside a chapter
        #expect(links("Matt.5.3\tMatt.5.47-Matt.6.4\t2") == [link(40005003, 40005047, 40006004, 2)])        // into the next chapter
        #expect(links("Mal.4.6\tMal.4.5-Matt.1.1\t2") == [link(39004006, 39004005, 40001001, 2)])           // into the next book
        #expect(links("3John.1.15\tMatt.5.3\t2\nPs.1.6\t3John.1.15\t3")
                == [link(64001014, 40005003, 40005003, 2), link(19001006, 64001014, 64001014, 3)])
        #expect(VerseKey.location(19119176) == VerseLocation(book: "PSA", chapter: 119, verse: 176) && VerseKey.location(99001001) == nil)
    }

    @Test func linksUnderOneVoteAndLinesThatDoNotParseAreLeftOut() {
        var warnings: [ImportWarning] = []
        let text = header + "Matt.5.3\tJas.2.5\t0\nMatt.5.3\tProv.16.19\t-3\n\nMatt.5.3\tTob.1.1\t5\nMatt.5\tPs.1.1\t5\n"
            + "Matt.5.3\tPs.1.1\tmany\nMatt.5.3\tPs.1.2-Ps.1.1\t5\r\nMatt.5.3\tLuke.6.20\t1\r\n"
        #expect(CrossReferenceFile.parse(text, warnings: &warnings) == [link(40005003, 42006020, 42006020, 1)])
        #expect(warnings.count == 4)                          // Tobit, no verse, no number, a range backwards; a low vote is no warning
        #expect(CrossReferenceFile.parse("<html>Not Found</html>\n", warnings: &warnings).isEmpty)
        #expect(Set(CrossReferenceFile.books.values) == Set(BookCatalog.all.filter { $0.order <= 66 }.map(\.id)))
    }
}
