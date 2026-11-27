import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct ReadingPositionStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "ReadingPositionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func roundTrips() {
        let store = ReadingPositionStore(defaults: makeDefaults())
        #expect(store.load() == nil)
        let position = ReadingPosition(book: "MAT", chapter: 5, firstVisibleVerse: 17, translationID: "ESV")
        store.save(position)
        #expect(store.load() == position)
        #expect(store.load()?.chapterLocation == ChapterLocation(book: "MAT", chapter: 5))
    }

    /// The position travels between devices as raw bytes; an unchanged position must not look changed.
    @Test func theSamePositionEncodesToTheSameBytes() {
        let defaults = makeDefaults()
        let store = ReadingPositionStore(defaults: defaults)
        let position = ReadingPosition(book: "ROM", chapter: 8, firstVisibleVerse: 1, translationID: "ESV")
        store.save(position)
        let first = defaults.data(forKey: "readingPosition")
        store.save(ReadingPosition(book: "ROM", chapter: 8, firstVisibleVerse: 1, translationID: "ESV"))
        let second = defaults.data(forKey: "readingPosition")
        #expect(first != nil)
        #expect(first == second)
        // Sorted keys, so another process (another hash seed) writes the same bytes.
        #expect(second == Data(#"{"book":"ROM","chapter":8,"firstVisibleVerse":1,"translationID":"ESV"}"#.utf8))
        #expect(store.load() == position)
    }

    @Test func undecodableDataLoadsAsNil() {
        let defaults = makeDefaults()
        defaults.set(Data("junk".utf8), forKey: "readingPosition")
        #expect(ReadingPositionStore(defaults: defaults).load() == nil)
    }

    @Test func translationChoiceRoundTripsIndependently() {
        let store = ReadingPositionStore(defaults: makeDefaults())
        #expect(store.loadTranslationID() == nil)
        store.save(translationID: "KJV")
        #expect(store.loadTranslationID() == "KJV")
        store.clear()   // clearing the position keeps the translation choice
        #expect(store.loadTranslationID() == "KJV")
    }

    @Test func clearRemovesPosition() {
        let store = ReadingPositionStore(defaults: makeDefaults())
        store.save(ReadingPosition(book: "GEN", chapter: 1, firstVisibleVerse: 1, translationID: "KJV"))
        store.clear()
        #expect(store.load() == nil)
    }
}
