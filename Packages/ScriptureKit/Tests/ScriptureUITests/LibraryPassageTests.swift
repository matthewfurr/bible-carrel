import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct LibraryPassageTests {
    private func ref(_ code: String, _ chapter: Int, _ verse: Int) -> Reference {
        Reference(book: BookCatalog.book(code: code)!, chapter: chapter, verse: verse)
    }

    private func mt(_ chapter: Int, _ verse: Int) -> VerseLocation {
        VerseLocation(book: "MAT", chapter: chapter, verse: verse)
    }

    private func makeModel() throws -> NavigationModel {
        let defaults = UserDefaults(suiteName: "LibraryPassageTests-\(UUID().uuidString)")!
        return try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "WEB")
    }

    /// Review Focus 1. The fixture's WEB has no John.
    @Test func aReferenceTheTranslationLacksSaysSoAndOffersNoOpen() throws {
        let model = try makeModel()
        let before = model.libraryPlace
        let there = LibraryPassage.load(ref("MAT", 5, 3), navigation: model), missing = LibraryPassage.load(ref("JHN", 1, 1), navigation: model)
        guard case .verses(let preview) = there else { Issue.record("no verses"); return }
        #expect(preview.verses.map(\.id.verse) == [3] && there.missingLine == nil)
        #expect(missing == .missing(ref("JHN", 1, 1)) && missing.missingLine == "John 1:1 is not in the translation being read.")
        #expect(model.libraryPlace == before && model.screen == .frontPage && !model.isLookingUp)
    }

    @Test func referencesInTheirOwnBookDropItsName() {
        let references = VerseRuns.references([mt(1, 18), mt(1, 19), mt(2, 1)])
        #expect(String(ReferenceRunsText.text(references, inBook: BookCatalog.book(code: "MAT")).characters) == "1:18-19 · 2:1")
        #expect(String(ReferenceRunsText.text(references, inBook: nil).characters) == "Matthew 1:18-19 · Matthew 2:1")
        #expect(ReferenceRunsText.text(references, inBook: nil).runs.compactMap(\.link).count == 2)
    }
}

@MainActor @Suite struct LibraryViewRulesTests {
    /// Live finding L1: Esc closes an open Library view wherever the keyboard is on the front page
    /// (nowhere, after a ⌘K choice), but never while the toolbar's field holds it or the palette is
    /// up, and with no view open it is not taken at all (it may leave full screen).
    @Test func escClosesTheLibraryViewUnlessTheFieldOrThePaletteHasIt() {
        #expect(LibraryEscapeRule.closesView(viewOpen: true, searchFieldFocused: false, paletteShown: false))
        #expect(!LibraryEscapeRule.closesView(viewOpen: true, searchFieldFocused: true, paletteShown: false))
        #expect(!LibraryEscapeRule.closesView(viewOpen: true, searchFieldFocused: false, paletteShown: true))
        #expect(!LibraryEscapeRule.closesView(viewOpen: false, searchFieldFocused: false, paletteShown: false))
    }

    /// Live pass 1, project 4: Esc from Places with a place chosen opened an empty whole-Bible People view. A write
    /// through the front page's binding once the view is closed is a stale one (the going view's), and opens nothing.
    @Test func aWriteAfterTheViewClosedOpensNoView() {
        let stale = LibraryPlace(book: nil, topic: .people)
        #expect(LibraryEscapeRule.writing(stale, over: nil) == nil)
        var joshua = LibraryPlace(book: "JOS", topic: .places)
        joshua.choose(.place(882))
        let open = LibraryPlace(book: "JOS", topic: .places)
        #expect(LibraryEscapeRule.writing(joshua, over: open) == joshua)
    }

    @Test func typingInTheFrontPagesFieldReturnsTheLibraryViewToTheContents() throws {
        let defaults = UserDefaults(suiteName: "LibraryViewRulesTests-\(UUID().uuidString)")!
        let model = try NavigationModel(store: try FixtureStore.make(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "WEB")
        let place = LibraryPlace(book: "MAT", topic: .people)
        model.libraryPlace = place
        model.frontPageSearchChanged(to: "")
        model.frontPageSearchChanged(to: "  ")
        #expect(model.libraryPlace == place)          // clearing the field, or white space, leaves it
        model.frontPageSearchChanged(to: "r")
        #expect(model.libraryPlace == nil)
    }

    @Test func thePageIsReadOnceUntilTheBookViewPersonOrTranslationChanges() {
        let cache = LibraryView.LoadCache()
        let a = LibraryView.Source(book: "MAT", topic: .people, showing: .person(1), translationID: "WEB")
        _ = cache.loaded(for: a) { LibraryView.Loaded() }
        _ = cache.loaded(for: a) { LibraryView.Loaded() }
        #expect(cache.reads == 1)
        _ = cache.loaded(for: LibraryView.Source(book: "MAT", topic: .people, showing: .person(2), translationID: "WEB")) { LibraryView.Loaded() }
        #expect(cache.reads == 2)
    }
}

@MainActor @Suite struct ReferenceRunPopoverTests {
    /// The popover's arrow is a small rect at the pointer's place when the link was opened; with no
    /// pointer (VoiceOver's action, the keyboard) there is none, and the run's bounds are used.
    @Test func thePopoverPointsWhereTheLinkWasOpenedElseAtTheRun() throws {
        let rect = try #require(ReferenceRunsText.anchorRect(pointer: CGPoint(x: 120, y: 48)))
        #expect(rect.contains(CGPoint(x: 120, y: 48)) && rect.width <= 4 && rect.height <= 4)
        #expect(ReferenceRunsText.anchorRect(pointer: nil) == nil)
    }
}
