import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The Library's BibleProject icon (spec 5): every book of the Old and New Testaments has its
/// overview video; a book with two offers both; a video covering several books is under each.
@Suite struct BibleProjectVideosTests {
    @Test func everyTestamentBookHasAVideoAndEveryKeyIsABook() throws {
        let testaments = BookCatalog.all.filter { $0.canon != .apocrypha }
        #expect(testaments.count == 66)
        for book in testaments {
            #expect(!BibleProjectVideos.videos(forBook: book.id).isEmpty, "\(book.id) has no video")
        }
        for code in BibleProjectVideos.table.keys {
            let book = try #require(BookCatalog.book(code: code), "\(code) is not a book")
            #expect(book.canon != .apocrypha)
        }
        for video in BibleProjectVideos.table.values.flatMap({ $0 }) {
            #expect(video.url.scheme == "https" && video.url.host() == "bibleproject.com")
            #expect(video.url.path().hasPrefix("/videos/"))
        }
    }

    @Test func johnOffersTwoAndTheLettersOfJohnShareOne() {
        #expect(BibleProjectVideos.videos(forBook: "JHN").map(\.title) == ["John 1–12", "John 13–21"])
        #expect(BibleProjectVideos.videos(forBook: "GEN").count == 2)
        #expect(BibleProjectVideos.videos(forBook: "RUT").count == 1)
        #expect(BibleProjectVideos.videos(forBook: "1KI") == BibleProjectVideos.videos(forBook: "2KI"))
        let letters = BibleProjectVideos.videos(forBook: "1JN")
        #expect(letters.count == 1)
        #expect(BibleProjectVideos.videos(forBook: "2JN") == letters && BibleProjectVideos.videos(forBook: "3JN") == letters)
        #expect(BibleProjectVideos.videos(forBook: "JUD").count == 1)
        #expect(BibleProjectVideos.videos(forBook: "TOB").isEmpty)
    }
}
