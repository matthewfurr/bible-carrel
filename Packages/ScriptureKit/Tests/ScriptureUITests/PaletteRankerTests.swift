import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct PaletteRankerTests {
    let books: [TranslationBook] = [("PSA", 150), ("MAT", 28), ("JHN", 21), ("ROM", 16), ("JUD", 1), ("JDG", 21)]
        .map { TranslationBook(book: BookCatalog.book(code: $0.0)!, chapterCount: $0.1) }
    let translations = [Translation(id: "ESV", title: "English Standard Version"), Translation(id: "KJV", title: "King James Version")]

    private func rank(_ query: String, verses: [Verse] = []) -> [PaletteItem] {
        PaletteRanker.rank(query: query, books: books, translations: translations, activeTranslationID: "ESV", verses: verses, commands: PaletteCommand.all)
    }

    private func isReference(_ item: PaletteItem) -> Bool {
        if case .reference = item { return true }
        return false
    }

    @Test func theShortcutsSheetIsACommand() {
        #expect(rank("keyb").contains(.command(.showShortcuts)))
        #expect(rank("short").contains(.command(.showShortcuts)))
        #expect(PaletteItem.command(.showShortcuts).title == "Keyboard Shortcuts" && PaletteItem.command(.showShortcuts).symbolName == "keyboard")
    }

    @Test func chapterReferenceComesFirst() {
        let items = rank("Rom 8")
        guard case .reference(let reference)? = items.first else { Issue.record("expected reference"); return }
        #expect(reference.book.id == "ROM")
        #expect(reference.chapter == 8)
        #expect(items.first?.subtitle == "Go to chapter")
    }

    @Test func verseReferenceIsOffered() {
        let items = rank("John 3:16")
        guard case .reference(let reference)? = items.first else { Issue.record("expected reference"); return }
        #expect(reference.verse == 16)
        #expect(items.first?.subtitle == "Go to verse")
    }

    @Test func chapterBeyondBookIsNotOffered() {
        #expect(!rank("Rom 99").contains(where: isReference))
    }

    @Test func bareBookBecomesBookItem() {
        let items = rank("ps")
        #expect(items.first == .book(BookCatalog.book(code: "PSA")!))
        #expect(!items.contains(where: isReference))
    }

    @Test func prefixMatchesFollowTheResolvedBookAndRespectAvailability() {
        let items = rank("jud")
        let bookIDs = items.compactMap { if case .book(let book) = $0 { book.id } else { nil } }
        // The parser resolves "jud" to Jude (shortest name); Judges follows as a prefix match.
        // Judith (JDT) is not in `books`, so it never appears.
        #expect(bookIDs == ["JUD", "JDG"])
    }

    @Test func translationsMatchByIDOrTitle() {
        #expect(rank("kjv").contains(.translation(translations[1])))
        #expect(rank("king").contains(.translation(translations[1])))
        #expect(!rank("esv").contains(.translation(translations[0])))   // active translation is excluded
    }

    @Test func versesComeLastAndAreCapped() {
        let verses = (1...12).map {
            Verse(id: VerseLocation(book: "MAT", chapter: 5, verse: $0), translationID: "ESV", text: "Blessed \($0)", breakAfter: false)
        }
        let items = rank("blessed", verses: verses)
        let verseItems = items.filter { if case .verse = $0 { true } else { false } }
        #expect(verseItems.count == 8)
        #expect(items.last == verseItems.last)
        #expect(verseItems.first?.title == "Matthew 5:1")
    }

    @Test func psalmRowsUseTheSingular() {
        #expect(rank("ps 23").first?.title == "Psalm 23")
        let verse = Verse(id: VerseLocation(book: "PSA", chapter: 23, verse: 1), translationID: "ESV", text: "The Lord is my shepherd", breakAfter: false)
        #expect(rank("shepherd", verses: [verse]).last?.title == "Psalm 23:1")
        #expect(rank("ps").first?.title == "Psalms")   // the whole book keeps the plural
    }

    @Test func blankQueryIsEmpty() {
        #expect(rank("   ").isEmpty)
    }

    @Test func commandsMatchByTitle() {
        #expect(rank("notes").contains(.command(.notesBrowser)))
        #expect(rank("sett").contains(.command(.settings)))
        #expect(!rank("rom 8").contains(where: { if case .command = $0 { true } else { false } }))
        #expect(PaletteItem.command(.notesBrowser).title == "Notes Browser")
        #expect(PaletteItem.command(.settings).title == "Settings" && PaletteItem.command(.settings).symbolName == "gearshape")
    }

    @Test func theAssistantIsACommand() {
        #expect(rank("assistant").contains(.command(.toggleAssistant)))
        #expect(rank("ask").contains(.command(.toggleAssistant)))
        #expect(PaletteItem.command(.toggleAssistant).title == "Ask the Assistant" && PaletteItem.command(.toggleAssistant).symbolName == "sparkles")
    }

    @Test func firstLineStripsMarkdown() {
        #expect(SearchMarkHit.firstLine(of: "# Heading\n\nbody") == "Heading")
        #expect(SearchMarkHit.firstLine(of: "**bold** rest") == "bold rest")
        #expect(SearchMarkHit.firstLine(of: "") == "")
        #expect(SearchMarkHit.firstLine(of: String(repeating: "a", count: 200)).count == 120)
    }

    @Test func commandsMatchWordPrefixesNotStrayLetters() {
        let isCommand: (PaletteItem) -> Bool = { if case .command = $0 { true } else { false } }
        #expect(!rank("n").contains(where: isCommand))
        #expect(!rank("ro").contains(where: isCommand))
        #expect(!rank("tes").contains(where: isCommand))
        #expect(rank("brow").contains(.command(.notesBrowser)))
        #expect(rank("page lec").contains(.command(.pageStyle(.lectern))))
        #expect(rank("sepia").contains(.command(.appearance(.sepia))))
    }

    private let verse = Verse(id: VerseLocation(book: "JHN", chapter: 15, verse: 4), translationID: "ESV", text: "Abide in me", breakAfter: false)

    private func recent(_ target: Recent.Target) -> PaletteItem {
        .recent(Recent(target: target, translationID: "ESV", date: .now))
    }

    /// A mark of `kind` in John 15:4, as a recent's target.
    private func mark(_ kind: SearchMarkHit.Kind) -> Recent.Target {
        let target = MarkupTarget(location: ChapterLocation(book: "JHN", chapter: 15), verse: 4, translationID: nil, highlightID: nil)
        return .mark(id: UUID(), kind: kind, target: target, reference: "John 15:4")
    }

    private func hit(_ kind: SearchMarkHit.Kind) -> SearchMarkHit {
        SearchRankerTests.entries.map(SearchMarkHit.init(entry:)).first { $0.kind == kind }!
    }

    @Test func returnsWordFollowsTheRowAndTabStepsTheChipsUnlessVoiceOverIsOn() {
        let john15 = ChapterLocation(book: "JHN", chapter: 15)
        #expect(rank("Rom 8").first?.returnVerb == "Read" && PaletteItem.book(BookCatalog.book(code: "PSA")!).returnVerb == "Read")
        #expect(PaletteItem.verse(verse).returnVerb == "Show verse")
        #expect([.note, .highlight, .bookmark, .thread].map { PaletteItem.mark(hit($0)).returnVerb }
                == ["Show note", "Show highlight", "Show bookmark", "Open conversation"])
        #expect(PaletteItem.translation(translations[1]).returnVerb == "Switch" && PaletteItem.command(.home).returnVerb == "Run")
        #expect(PaletteItem.suggestion(SearchSuggestion(query: "abide", verseCount: 3)).returnVerb == "Search")
        #expect(recent(.search(query: "abide", scope: .wholeBible, verseCount: 3)).returnVerb == "Search")
        #expect(recent(.chapter(john15)).returnVerb == "Read" && recent(.lookup(john15, verse: 4)).returnVerb == "Show verse")
        #expect(recent(mark(.note)).returnVerb == "Show note" && recent(mark(.thread)).returnVerb == "Open conversation")
        #expect(PaletteKeys.tabStepsChips(chipCount: 3, fullKeyboardAccess: false, voiceOver: false))
        // The controller's ruling: Keyboard navigation no longer hands Tab to the system; only VoiceOver does.
        #expect(PaletteKeys.tabStepsChips(chipCount: 3, fullKeyboardAccess: true, voiceOver: false))
        #expect(!PaletteKeys.tabStepsChips(chipCount: 3, fullKeyboardAccess: false, voiceOver: true))
        #expect(!PaletteKeys.tabStepsChips(chipCount: 0, fullKeyboardAccess: false, voiceOver: false))
    }

    /// ⌃Tab steps the scope while the scope menu shows, unless VoiceOver has Tab; the foot says so.
    @Test func controlTabStepsTheScopeWhileItsMenuShows() {
        #expect(PaletteKeys.controlTabStepsScope(showsScopeMenu: true, voiceOver: false))
        #expect(!PaletteKeys.controlTabStepsScope(showsScopeMenu: false, voiceOver: false))
        #expect(!PaletteKeys.controlTabStepsScope(showsScopeMenu: true, voiceOver: true))
        #expect(PaletteFoot.spoken(returnVerb: "Show verse", narrows: true, stepsScope: true, escapeWord: "Close")
                == "Return: Show verse. Up and down arrows: Move. Tab: Narrow. Control Tab: Scope. Escape: Close")
        #expect(PaletteFoot.spoken(returnVerb: nil, narrows: false, stepsScope: false, escapeWord: "Close")
                == "Up and down arrows: Move. Escape: Close")
    }
}
