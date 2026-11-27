import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct SearchRankerTests {
    let books: [TranslationBook] = [("PSA", 150), ("MAT", 28), ("JHN", 21), ("ROM", 16), ("1JN", 5)]
        .map { TranslationBook(book: BookCatalog.book(code: $0.0)!, chapterCount: $0.1) }
    let translations = [Translation(id: "ESV", title: "English Standard Version"), Translation(id: "KJV", title: "King James Version")]

    static let yellow = MarkupColor(lightHex: "#F5D76E", darkHex: "#8A7424")
    static let green = MarkupColor(lightHex: "#A8D5A2", darkHex: "#3E6B38")

    private static func date(_ n: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(n * 1000)) }

    private static func entry(
        _ kind: NotesBrowserEntry.Kind, id: UUID, book: String = "JHN", chapter: Int = 15, verse: Int, endVerse: Int? = nil,
        color: MarkupColor? = nil, quoted: String = "", body: String = "", modified: Int
    ) -> NotesBrowserEntry {
        let name = BookCatalog.book(code: book)!.chapterName
        return NotesBrowserEntry(
            id: id, kind: kind, book: book, bookOrder: BookCatalog.book(code: book)!.order, chapter: chapter,
            verse: verse, endVerse: endVerse ?? verse, referenceString: "\(name) \(chapter):\(verse)",
            translationID: kind == .bookmark(id: id) ? nil : "KJV", color: color,
            quotedText: quoted, body: body, modifiedAt: date(modified))
    }

    static let noteID = UUID(), highlightID = UUID(), bookmarkID = UUID(), loveNoteID = UUID(), threadID = UUID(), letterNoteID = UUID()
    static let anchorID = UUID()

    /// Two notes, one bare highlight, one bookmark and one thread in John 15; one note in 1 John 2.
    static let entries: [NotesBrowserEntry] = [
        entry(.thread(id: threadID), id: threadID, verse: 15, quoted: "To remain in him.", body: "What does abide mean?", modified: 5),
        entry(.note(noteID: noteID, highlightID: anchorID), id: noteID, verse: 4, color: yellow,
              quoted: "Abide in me, and I in you.", body: "**Abide** first, then fruit", modified: 3),
        entry(.bookmark(id: bookmarkID), id: bookmarkID, verse: 5, quoted: "the vine and abiding", modified: 2),
        entry(.highlight(id: highlightID), id: highlightID, verse: 5, color: green,
              quoted: "I am the vine, ye are the branches", modified: 1),
        entry(.note(noteID: loveNoteID, highlightID: nil), id: loveNoteID, verse: 13,
              quoted: "Greater love hath no man than this", body: "Greater love", modified: 4),
        entry(.note(noteID: letterNoteID, highlightID: nil), id: letterNoteID, book: "1JN", chapter: 2, verse: 28,
              quoted: "And now, little children, abide in him", body: "Abiding is staying", modified: 6),
    ]

    private func verse(_ chapter: Int, _ number: Int, _ text: String) -> Verse {
        Verse(id: VerseLocation(book: "JHN", chapter: chapter, verse: number), translationID: "KJV", text: text, breakAfter: false)
    }

    private var abideVerses: [Verse] {
        [verse(15, 4, "Abide in me, and I in you."), verse(15, 5, "I am the vine: He that abideth in me"), verse(15, 7, "If ye abide in me")]
    }

    private func rank(
        _ query: String, verses: [Verse] = [], verseTotal: Int = 0, active: String = "KJV",
        commands: [PaletteCommand] = PaletteCommand.all, limits: SearchLimits = .palette
    ) -> SearchResults {
        SearchRanker.results(
            query: query, books: books, translations: translations, activeTranslationID: active,
            verses: verses, verseTotal: verseTotal, marks: Self.entries, commands: commands, limits: limits)
    }

    private func group(_ kind: SearchGroupKind, in results: SearchResults) -> SearchGroup? {
        results.groups.first { $0.kind == kind }
    }

    private func hits(_ group: SearchGroup?) -> [SearchMarkHit] {
        (group?.items ?? []).compactMap { if case .mark(let hit) = $0 { hit } else { nil } }
    }

    private func marks(_ results: SearchResults) -> [SearchMarkHit] {
        hits(group(.marksInPassage, in: results))
    }

    private func ids(_ kind: SearchGroupKind, _ query: String) -> [UUID] {
        hits(group(kind, in: rank(query))).map(\.id)
    }

    // MARK: - Word queries

    @Test func marksTakePhrasesAndExclusions() {
        #expect(ids(.notes, "\"greater love\"") == [Self.loveNoteID] && ids(.notes, "\"love greater\"").isEmpty)
        #expect(ids(.notes, "abid") == [Self.letterNoteID, Self.noteID])            // word starts, as before
        #expect(ids(.notes, "abide -fruit") == [Self.letterNoteID])                 // the John 15:4 note says "then fruit"
        #expect(ids(.asked, "\"abide mean\"") == [Self.threadID] && ids(.asked, "abide -remain").isEmpty)
        #expect(ids(.notes, "-abide").isEmpty)
        #expect(ids(.notes, "\"the vine\"") == [Self.highlightID])                  // not the bookmark that quotes it
        let text = "Abide in me, and I in you."
        #expect(SearchRanker.matchRanges(in: text, query: "\"in me\" -you").map { String(text[$0]) } == ["in", "me"])
    }

    @Test func aWordGroupsNotesAskedThenScripture() {
        let r = rank("abide", verses: abideVerses, verseTotal: 61)
        #expect(r.groups.map(\.kind) == [.notes, .asked, .scripture])
        #expect(r.groups[0].title == "Your notes")
        #expect(r.groups[1].title == "Asked")
        #expect(r.groups[2].title == "Scripture · KJV")
        #expect(r.groups[2].totalCount == 61)                    // verseTotal passed in
        #expect(r.groups[2].items.count == 3)
        #expect(hits(r.groups[1]).map(\.id) == [Self.threadID])
        #expect(r.flatItems == r.groups.flatMap(\.items))
    }

    @Test func aWordFindsABareHighlightByItsWordsButNeverABookmark() {
        let r = rank("vine")
        let notes = hits(group(.notes, in: r))
        #expect(notes.map(\.id) == [Self.highlightID])
        #expect(notes.first?.kind == .highlight && notes.first?.symbolName == "highlighter")
        #expect(!r.flatItems.contains { if case .mark(let hit) = $0 { hit.kind == .bookmark } else { false } })
        #expect(group(.asked, in: r) == nil)
    }

    @Test func aWordMatchesWordStartsFoldedForCaseAndDiacritics() {
        #expect(hits(group(.notes, in: rank("GRÉATER"))).map(\.id) == [Self.loveNoteID])
        #expect(hits(group(.notes, in: rank("reater"))).isEmpty)          // not mid-word
        #expect(hits(group(.notes, in: rank("love greater"))).map(\.id) == [Self.loveNoteID])   // every word, any order
        #expect(hits(group(.notes, in: rank("love vine"))).isEmpty)
    }

    @Test func notesAreNewestFirstAndLimited() {
        #expect(hits(group(.notes, in: rank("abide"))).map(\.id) == [Self.letterNoteID, Self.noteID])
        var limits = SearchLimits.palette
        limits.notes = 1
        let notes = group(.notes, in: rank("abide", limits: limits))
        #expect(notes?.items.count == 1)
        #expect(notes?.totalCount == 2)
        #expect(hits(notes).first?.id == Self.letterNoteID)
    }

    @Test func aMarkRowCarriesItsHit() {
        let hit = SearchMarkHit(entry: Self.entries[1])
        #expect(hit.kind == .note && hit.symbolName == "note.text")
        #expect(hit.firstLine == "Abide first, then fruit")
        #expect(hit.color == Self.yellow)
        #expect(hit.target == MarkupTarget(entry: Self.entries[1]))
        let item = PaletteItem.mark(hit)
        #expect(item.id == "mark:\(Self.noteID.uuidString)")
        #expect(item.title == "John 15:4" && item.subtitle == "Abide first, then fruit" && item.symbolName == "note.text")
        let thread = SearchMarkHit(entry: Self.entries[0])
        #expect(thread.kind == .thread && thread.symbolName == "sparkles" && thread.firstLine == "What does abide mean?")
        #expect(thread.target.threadID == Self.threadID)
        #expect(SearchMarkHit(entry: Self.entries[2]).symbolName == "bookmark.fill")
    }

    // MARK: - Passage queries

    @Test func aPassageListsEveryMarkThereInVerseOrder() {
        let r = rank("john 15")
        #expect(r.groups.map(\.kind).prefix(2) == [.goTo, .marksInPassage])
        #expect(r.groups[0].items == [.reference(ReferenceParser.parse("john 15")!)])
        #expect(r.groups[1].title == "Your marks in John 15")
        #expect(marks(r).map(\.target.verse) == [4, 5, 5, 13, 15])   // note, highlight, bookmark, note, thread
        #expect(marks(r).map(\.kind) == [.note, .highlight, .bookmark, .note, .thread])
        #expect(group(.notes, in: r) == nil && group(.asked, in: r) == nil)
    }

    @Test func aPassageWithAVerseKeepsOnlyOverlappingMarks() {
        let r = rank("john 15:5")
        #expect(marks(r).map(\.id) == [Self.highlightID, Self.bookmarkID])
        #expect(marks(rank("john 15:4-5")).map(\.target.verse) == [4, 5, 5])
    }

    @Test func aPassageWithoutMarksHasNoMarksGroup() {
        let r = rank("rom 8")
        #expect(r.groups.first?.kind == .goTo)
        #expect(group(.marksInPassage, in: r) == nil)
    }

    @Test func passageMarksAreLimited() {
        var limits = SearchLimits.palette
        limits.marksInPassage = 2
        let group = group(.marksInPassage, in: rank("john 15", limits: limits))
        #expect(group?.items.count == 2 && group?.totalCount == 5)
    }

    @Test func aMarkedVerseCarriesItsColor() {
        let r = rank("abide", verses: abideVerses, verseTotal: 3)
        #expect(r.verseColors[PaletteItem.verse(abideVerses[0]).id] == Self.yellow)   // the note's color
        #expect(r.verseColors[PaletteItem.verse(abideVerses[1]).id] == Self.green)    // the bare highlight's
        #expect(r.verseColors[PaletteItem.verse(abideVerses[2]).id] == nil)
    }

    /// The same verse number in two chapters takes each chapter's own mark, and a chapter with no
    /// mark colors nothing.
    @Test func marksInDifferentChaptersColorTheirOwnVerses() {
        let marks = [
            Self.entry(.highlight(id: UUID()), id: UUID(), chapter: 16, verse: 3, endVerse: 5, color: Self.green, modified: 1),
            Self.entry(.highlight(id: UUID()), id: UUID(), chapter: 15, verse: 4, color: Self.yellow, modified: 2),
            Self.entry(.highlight(id: UUID()), id: UUID(), chapter: 16, verse: 4, color: Self.yellow, modified: 3),
        ]
        let verses = [verse(15, 4, "Abide in me"), verse(16, 4, "abide with you"), verse(17, 4, "abide"), verse(15, 5, "abideth")]
        let r = SearchRanker.results(
            query: "abide", books: books, translations: translations, activeTranslationID: "KJV",
            verses: verses, verseTotal: 4, marks: marks, limits: .palette)
        #expect(r.verseColors[PaletteItem.verse(verses[0]).id] == Self.yellow)
        #expect(r.verseColors[PaletteItem.verse(verses[1]).id] == Self.green)   // the first in its chapter that spans it
        #expect(r.verseColors[PaletteItem.verse(verses[2]).id] == nil)
        #expect(r.verseColors[PaletteItem.verse(verses[3]).id] == nil)
    }

    // MARK: - Books, translations, commands

    @Test func commandsCanBeLeftOut() {
        #expect(group(.commands, in: rank("sett"))?.items.contains(.command(.settings)) == true)
        #expect(group(.commands, in: rank("sett", commands: [])) == nil)
        #expect(group(.commands, in: rank("sett")).map(\.title) == "Commands")
    }

    @Test func booksAndTranslationsKeepTheOldRules() {
        let psalms = rank("ps")
        #expect(psalms.groups.first?.kind == .books)
        #expect(psalms.groups.first?.title == "Books")
        #expect(psalms.groups.first?.items.first == .book(BookCatalog.book(code: "PSA")!))
        let kjv = rank("kjv", active: "ESV")
        #expect(group(.translations, in: kjv)?.items == [.translation(translations[1])])
        #expect(group(.translations, in: kjv)?.title == "Translations")
        #expect(group(.translations, in: rank("kjv")) == nil)     // the active translation is left out
    }

    @Test func emptyAndPunctuationQueriesReturnNothing() {
        #expect(rank("") == .empty)
        #expect(rank("  ") == .empty)
        #expect(rank("\"").groups.isEmpty)
        #expect(rank("*").groups.isEmpty)
        #expect(SearchResults.empty.groups.isEmpty && SearchResults.empty.flatItems.isEmpty)
    }

    @Test func onlyKeepsOneGroup() {
        let r = rank("abide", verses: abideVerses, verseTotal: 61)
        #expect(r.only(.asked).groups.map(\.kind) == [.asked])
        #expect(r.only(nil) == r)
    }

    // MARK: - Bolding

    @Test func matchRangesBoldWholeWordsThatStartWithTheQuery() {
        let text = "Abiding comes before bearing; abide."
        #expect(SearchRanker.matchRanges(in: text, query: "abide").map { String(text[$0]) } == ["abide"])
        #expect(SearchRanker.matchRanges(in: text, query: "abid").map { String(text[$0]) } == ["Abiding", "abide"])
        #expect(SearchRanker.matchRanges(in: "Élie came", query: "elie").map { String("Élie came"[$0]) } == ["Élie"])
        #expect(SearchRanker.matchRanges(in: text, query: "\"").isEmpty)
    }

    /// The Mac's palette and the phone's search bold the same words, in the quote and the note:
    /// only the matches carry the strong intent, and nothing else (no color) is set.
    @Test func boldedMarksOnlyTheMatchesStrong() {
        let bolded = SearchRanker.bolded("Abide in me, and I in you.", query: "abide")
        let strong = bolded.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(strong.map { String(bolded[$0.range].characters) } == ["Abide"])
        #expect(bolded.runs.count == 2)
        #expect(String(bolded.characters) == "Abide in me, and I in you.")
        #expect(SearchRanker.bolded("in me", query: "abide") == AttributedString("in me"))
    }

    /// The runs `bolded` marks, as (text, strong, underlined); every run is one or the other whole.
    private func marked(_ text: String, _ query: String) -> [(String, Bool, Bool)] {
        let bolded = SearchRanker.bolded(text, query: query)
        return bolded.runs.map { run in
            (String(bolded[run.range].characters),
             run.inlinePresentationIntent == .stronglyEmphasized,
             run.underlineStyle == .single)
        }
    }

    /// Bold alone did not stand out in the results (Matt, 2026-11-17): a matched word is also
    /// underlined, a single line in the text's own ink, and the rest of the line has neither.
    @Test func boldedUnderlinesTheMatchesAndNothingElse() {
        let runs = marked("Abide in me, and I in you.", "abide")
        #expect(runs.map(\.0) == ["Abide", " in me, and I in you."])
        #expect(runs.map(\.1) == [true, false] && runs.map(\.2) == [true, false])
        // No color: the underline takes the ink, and a quote keeps its mark's fill.
        let bolded = SearchRanker.bolded("Abide in me", query: "abide")
        #expect(bolded.runs.allSatisfy { $0.foregroundColor == nil && $0.backgroundColor == nil })
        // A phrase marks its words together; an excluded word is never marked.
        let phrase = marked("Abide in me, and I in you.", "\"in me\"")
        #expect(phrase.filter(\.1).map(\.0) == ["in", "me"] && phrase.filter(\.2).map(\.0) == ["in", "me"])
        let excluded = marked("Abide in me, and I in you.", "abide -you")
        #expect(excluded.filter(\.1).map(\.0) == ["Abide"] && excluded.filter(\.2).map(\.0) == ["Abide"])
    }

    @Test func chipsAreTheKindsPresentAndTabGoesRoundThem() {
        let words = rank("abide", verses: abideVerses, verseTotal: 61), passage = rank("john 15")
        #expect(words.chips() == [.notes, .asked, .scripture] && words.count(of: .scripture) == 61)
        #expect(passage.chips() == [.marks, .passages] && passage.chips(SearchChip.phone) == [.marks])
        #expect(words.showing(.scripture).groups.map(\.kind) == [.scripture] && words.showing(.passages) == words)
        let chips = words.chips()
        #expect(SearchResults.chip(after: nil, by: 1, among: chips) == .notes && SearchResults.chip(after: nil, by: -1, among: chips) == .scripture)
        #expect(SearchResults.chip(after: .scripture, by: 1, among: chips) == nil)  // round through All
        #expect(SearchResults.chip(after: .commands, by: 1, among: chips) == nil)   // a chip that has gone
    }

    /// The controller's ruling: "Did you mean" leads only when nothing else matched; otherwise it
    /// comes last, so a command typed by name stays first. A chip standing only for the suggestion
    /// (a count of 0) is not offered.
    @Test func didYouMeanLeadsOnlyWhenNothingElseMatched() {
        let near = SearchSuggestion(query: "sepal", verseCount: 2)
        let named = SearchRanker.results(
            query: "sepia", books: books, translations: translations, activeTranslationID: "KJV",
            verses: [], verseTotal: 0, suggestion: near, marks: Self.entries, commands: PaletteCommand.all, limits: .palette)
        #expect(named.groups.map(\.kind) == [.commands, .suggestion])
        #expect(named.flatItems.first == .command(.appearance(.sepia)) && named.flatItems.last == .suggestion(near))
        #expect(named.chips() == [.commands] && !named.chips().contains { named.count(of: $0) == 0 })
        let alone = SearchRanker.results(
            query: "jesis", books: books, translations: translations, activeTranslationID: "KJV",
            verses: [], verseTotal: 0, suggestion: near, marks: Self.entries, commands: PaletteCommand.all, limits: .palette)
        #expect(alone.groups.map(\.kind) == [.suggestion] && alone.chips().isEmpty)
    }

    // MARK: - People and places by name (spec 6.6)

    private let lightAppearance = PaletteCommand.appearance(.light)

    @Test func peopleAndPlacesAreTwoGroupsAfterCommandsWithTheirChips() {
        let david = PersonSummary(id: 994, name: "David", label: nil, verseCount: 896)
        let joseph = PersonSummary(id: 1715, name: "Joseph", label: "Mary's Husband", verseCount: 15)
        let ramah = PlaceSummary(id: 978, name: "Ramah", label: "Matthew 2:18", kind: "city", latitude: 31.896, longitude: 35.201,
                                 point: "31.896,35.201", isApproximate: true, verseCount: 1)
        let results = SearchRanker.results(
            query: "light", books: books, translations: [], activeTranslationID: "WEB", verses: [], verseTotal: 0, marks: [],
            commands: [lightAppearance], people: NameMatches(rows: [david, joseph], total: 9), places: NameMatches(rows: [ramah], total: 1), limits: .palette)
        #expect(results.groups.map(\.kind) == [.commands, .people, .places])                    // a command typed by name stays first
        #expect(results.groups[1].title == "People" && results.groups[1].totalCount == 9 && results.chips().contains(.people) && results.count(of: .places) == 1)
        #expect(results.showing(.people).flatItems == [.person(david), .person(joseph)])
        #expect(PaletteItem.person(joseph).subtitle == "Mary's Husband · 15 verses" && PaletteItem.person(david).subtitle == "896 verses")
        #expect(PaletteItem.place(ramah).subtitle == "city · Matthew 2:18 · 1 verse" && PaletteItem.place(ramah).returnVerb == "Open")
        #expect(PaletteItem.person(david).id == "person:994" && !PaletteItem.person(david).showsReaderWhenChosen)
        #expect(SearchLimits.palette.people == 4 && SearchLimits.palette.places == 4 && SearchLimits.paletteChip.people == 30 && SearchChip.phone.contains(.places))
    }

    /// In a passage query People and Places still come after Commands and before the marks' notes;
    /// in a word query, after Commands and before the reader's notes.
    @Test func peopleAndPlacesSitBeforeTheNotesInEitherKindOfQuery() {
        let matthew = PersonSummary(id: 1971, name: "Matthew", label: nil, verseCount: 2)
        let word = SearchRanker.results(
            query: "abide", books: books, translations: [], activeTranslationID: "WEB", verses: [], verseTotal: 0, marks: Self.entries,
            people: NameMatches(rows: [matthew], total: 1), limits: .palette)
        #expect(word.groups.map(\.kind).firstIndex(of: .people)! < word.groups.map(\.kind).firstIndex(of: .notes)!)
        let passage = SearchRanker.results(
            query: "matt 1", books: books, translations: [], activeTranslationID: "WEB", verses: [], verseTotal: 0, marks: [],
            people: NameMatches(rows: [matthew], total: 1), limits: .palette)
        #expect(passage.groups.map(\.kind) == [.goTo, .people])
        #expect(PaletteItem.person(matthew).symbolName == "person" && PaletteItem.place(
            PlaceSummary(id: 1, name: "X", label: nil, kind: nil, latitude: nil, longitude: nil, point: nil, isApproximate: false, verseCount: 2)
        ).subtitle == "2 verses")
    }
}
