import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct CompareSetTests {
    private let defaults: UserDefaults
    private let matthew5v3 = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 0, quotedText: "")

    init() {
        let name = "CompareSetTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }

    @Test func theSetReadsBackAndKeepsWhatThisBuildDoesNotKnow() {
        #expect(CompareSet.key == "compareTranslationIDs" && CompareSet.ids(from: defaults) == ["ESV", "NASB", "KJV", "WEB"])
        #expect(CompareSet.ids("") == [] && CompareSet.ids(" KJV, ,WEB,KJV ") == ["KJV", "WEB"])
        #expect(CompareSet.toggling("ASV", in: "ESV,KJV") == "ESV,KJV,ASV" && CompareSet.toggling("ESV", in: "ESV,KJV") == "KJV")
        #expect(CompareSet.toggling("KJV", in: "KJV") == "")                  // the last one can be unchecked
        #expect(CompareSet.toggling("WEB", in: "NLT,KJV") == "NLT,KJV,WEB")   // NLT, from another build, stays
    }

    @Test func changingTheSetChangesTheRowsAndIsSaved() throws {
        let store = try FixtureStore.make()
        func rows() throws -> [String] {
            try VerseComparison.load(selection: matthew5v3, readingTranslationID: "WEB", compareSet: CompareSet.ids(from: defaults),
                                     translations: store.translations(), store: store).rows.map(\.translationID)
        }
        #expect(try rows() == ["WEB", "KJV"])
        defaults.set(CompareSet.toggling("KJV", in: CompareSet.defaultValue), forKey: CompareSet.key)
        #expect(defaults.string(forKey: CompareSet.key) == "ESV,NASB,WEB")
        #expect(try rows() == ["WEB"])
    }
}
