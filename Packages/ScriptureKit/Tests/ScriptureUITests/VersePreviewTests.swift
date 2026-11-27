import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct VersePreviewTests {
    private let matthew = BookCatalog.book(code: "MAT")!

    @Test func loadsARange() throws {
        let store = try FixtureStore.make()
        let preview = try #require(try VersePreview.load(Reference(book: matthew, chapter: 1, verse: 1, endVerse: 2), translationID: "WEB", store: store))
        #expect(preview.verses.count == 2)
        #expect(preview.verses.map(\.id.verse) == [1, 2])
        #expect(preview.title == "Matthew 1:1-2")
        #expect(preview.translationID == "WEB")
        #expect(preview.id == "Matthew 1:1-2WEB")
    }

    @Test func loadsOneVerse() throws {
        let store = try FixtureStore.make()
        let preview = try #require(try VersePreview.load(Reference(book: matthew, chapter: 2, verse: 3), translationID: "WEB", store: store))
        #expect(preview.verses.map(\.text) == ["Chapter two verse three."])
    }

    @Test func aMissingVerseIsNil() throws {
        let store = try FixtureStore.make()
        #expect(try VersePreview.load(Reference(book: matthew, chapter: 1, verse: 9), translationID: "WEB", store: store) == nil)
        #expect(try VersePreview.load(Reference(book: matthew, chapter: 40, verse: 1), translationID: "WEB", store: store) == nil)
        #expect(try VersePreview.load(Reference(book: BookCatalog.book(code: "JHN")!, chapter: 1, verse: 1), translationID: "WEB", store: store) == nil)
    }
}
