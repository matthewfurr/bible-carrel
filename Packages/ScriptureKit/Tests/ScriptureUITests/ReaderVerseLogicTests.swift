import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ReaderVerseLogicTests {
    private static let sentences = ["Lord, how many are my foes.", "Many are rising against me.", "Many are saying of me.",
                                    "But you, O Lord, are a shield.", "I cried aloud to the Lord."]

    /// Psalm 3 as one chapter in a book layout; with `combiningTwoAndThree`, verse 2 is "2-3".
    private static func book(typography: ReaderTypography = .default, combiningTwoAndThree: Bool = false) -> BookLayout {
        var verses: [Verse] = []
        for (offset, text) in sentences.enumerated() {
            let number = offset + 1
            if combiningTwoAndThree && number == 3 { continue }
            verses.append(Verse(id: VerseLocation(book: "PSA", chapter: 3, verse: number), translationID: "ESV",
                                endVerse: combiningTwoAndThree && number == 2 ? 3 : nil, text: text, breakAfter: false))
        }
        return BookLayout.build(chapters: [BookChapterInput(location: ChapterLocation(book: "PSA", chapter: 3), verses: verses)],
                                opening: BookOpening(bookName: "Psalms", title: BookTitle(title: "Psalms", subtitle: nil)),
                                typography: typography)
    }

    private var layout: BookLayout { Self.book() }
    private func t(_ n: Int) -> NSRange { layout.spans[n - 1].textRange }
    private func joined(_ a: Int, _ b: Int) -> NSRange { NSRange(location: t(a).location, length: NSMaxRange(t(b)) - t(a).location) }
    private func psa(_ n: Int) -> VerseLocation { VerseLocation(book: "PSA", chapter: 3, verse: n) }

    @Test func aCaretFindsItsVerseByItsNumberItsWordsAndItsEnd() {
        let span = layout.spans[1]
        for index in [span.numberRange.location, span.textRange.location + 2, NSMaxRange(span.textRange)] {
            #expect(ReaderTextLogic.verses(touching: NSRange(location: index, length: 0), in: layout) == [span])
        }
        #expect(ReaderTextLogic.verses(touching: NSRange(location: 0, length: 0), in: layout).isEmpty)   // the opening
        #expect(ReaderTextLogic.verses(touching: NSRange(location: NSNotFound, length: 0), in: layout).isEmpty)
    }

    @Test func aVerseIsFoundOnlyOnItsLines() {
        let span = layout.spans[2]
        #expect(ReaderTextLogic.verse(at: span.textRange.location + 1, in: layout) { _ in true } == span)
        #expect(ReaderTextLogic.verse(at: NSMaxRange(span.textRange), in: layout) { $0 == span } == span)   // its last letter's far half
        #expect(ReaderTextLogic.verse(at: span.textRange.location + 1, in: layout) { _ in false } == nil)
        #expect(ReaderTextLogic.verse(at: 0, in: layout) { _ in true } == nil)
    }

    @Test func jAndKStepFromTheSelectionsLastAndFirstVerse() {
        #expect(ReaderTextLogic.verseStep(.next, from: t(2), firstVisible: psa(1), in: layout) == t(3))
        #expect(ReaderTextLogic.verseStep(.previous, from: t(2), firstVisible: psa(1), in: layout) == t(1))
        #expect(ReaderTextLogic.verseStep(.next, from: joined(2, 3), firstVisible: nil, in: layout) == t(4))
        #expect(ReaderTextLogic.verseStep(.previous, from: joined(2, 3), firstVisible: nil, in: layout) == t(1))
        // A caret in verse 2 (after a colour collapsed the selection) carries on from verse 2.
        #expect(ReaderTextLogic.verseStep(.next, from: NSRange(location: t(2).location, length: 0), firstVisible: psa(5), in: layout) == t(3))
        // A partial selection steps by whole verses.
        #expect(ReaderTextLogic.verseStep(.next, from: NSRange(location: t(2).location + 1, length: 3), firstVisible: nil, in: layout) == t(3))
    }

    @Test func withNothingSelectedBothStartAtTheFirstVerseOnScreen() {
        for step in [VerseStep.next, .previous] {
            #expect(ReaderTextLogic.verseStep(step, from: nil, firstVisible: psa(4), in: layout) == t(4))
            #expect(ReaderTextLogic.verseStep(step, from: NSRange(location: 0, length: 0), firstVisible: psa(4), in: layout) == t(4))
            #expect(ReaderTextLogic.verseStep(step, from: nil, firstVisible: nil, in: layout) == nil)
        }
    }

    @Test func nothingHappensAtTheChaptersEnds() {
        #expect(ReaderTextLogic.verseStep(.next, from: t(5), firstVisible: psa(1), in: layout) == nil)
        #expect(ReaderTextLogic.verseStep(.previous, from: t(1), firstVisible: psa(1), in: layout) == nil)
        #expect(ReaderTextLogic.verseExtension(.next, of: t(5), anchor: nil, firstVisible: nil, in: layout) == nil)
    }

    @Test func shiftGrowsAndShrinksFromTheAnchorLikeAList() {
        let down = ReaderTextLogic.verseExtension(.next, of: t(2), anchor: nil, firstVisible: nil, in: layout)
        #expect(down?.range == joined(2, 3) && down?.anchor == t(2).location)
        let further = ReaderTextLogic.verseExtension(.next, of: joined(2, 3), anchor: t(2).location, firstVisible: nil, in: layout)
        #expect(further?.range == joined(2, 4))
        let back = ReaderTextLogic.verseExtension(.previous, of: joined(2, 4), anchor: t(2).location, firstVisible: nil, in: layout)
        #expect(back?.range == joined(2, 3))
        let toAnchor = ReaderTextLogic.verseExtension(.previous, of: joined(2, 3), anchor: t(2).location, firstVisible: nil, in: layout)
        #expect(toAnchor?.range == t(2))
        let above = ReaderTextLogic.verseExtension(.previous, of: t(2), anchor: t(2).location, firstVisible: nil, in: layout)
        #expect(above?.range == joined(1, 2) && above?.anchor == t(2).location)
        // With nothing selected it selects the first verse on screen, as J does.
        #expect(ReaderTextLogic.verseExtension(.next, of: nil, anchor: nil, firstVisible: psa(3), in: layout)?.range == t(3))
    }

    @Test func aCombinedVerseIsOneStep() {
        // Verse 2 is "2-3" (`Verse.endVerse == 3`), then verse 4.
        let combined = Self.book(combiningTwoAndThree: true)
        let spans = combined.spans
        #expect(ReaderTextLogic.verseStep(.next, from: spans[0].textRange, firstVisible: nil, in: combined) == spans[1].textRange)
        #expect(ReaderTextLogic.verseStep(.next, from: spans[1].textRange, firstVisible: nil, in: combined) == spans[2].textRange)
        #expect(ReaderTextLogic.verseStep(.next, from: nil, firstVisible: VerseLocation(book: "PSA", chapter: 3, verse: 3), in: combined) == spans[1].textRange)
    }

    @Test func aVerseWithoutItsNumberIsStillFound() {
        // Lectern removes verse 1's number (`BookLayout.removeVerseOneNumber`).
        var prefs = ReaderPreferences.default
        prefs.style = .lectern
        let lectern = Self.book(typography: ReaderSettings.typography(prefs))
        let first = lectern.spans[0]
        #expect(ReaderTextLogic.verses(touching: NSRange(location: first.textRange.location, length: 0), in: lectern) == [first])
        #expect(ReaderTextLogic.verseStep(.previous, from: lectern.spans[1].textRange, firstVisible: nil, in: lectern) == first.textRange)
    }
}
