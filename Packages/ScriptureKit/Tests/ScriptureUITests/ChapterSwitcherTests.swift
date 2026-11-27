import CoreGraphics
import Testing
@testable import ScriptureUI

/// The iPhone's chapter switcher, apart from UIKit (Matt, 2026-11-13): its stack of cards and
/// where a tap on one lands, and the tracker that reads a pull from the page's scroll.
@Suite struct ChapterSwitcherTests {
    typealias Event = ChapterSwitcherTracker.Event

    // MARK: The deck

    /// At the foot the cards run from the next chapter to the book's last; at the top from the
    /// previous one back to its first. The nearest is in front.
    @Test func theDeckStartsOnTheNextChapterThatWay() throws {
        let foot = try #require(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...24), current: 8))
        #expect(foot.front == 9)
        #expect(foot.cards == Array(9...24))
        let top = try #require(ChapterDeck(edge: .top, opening: .pull, chapters: Array(1...24), current: 8))
        #expect(top.front == 7)
        #expect(top.cards == [7, 6, 5, 4, 3, 2, 1])
    }

    /// It never crosses books: no chapter that way, no deck. A chapter the translation lacks has
    /// no card.
    @Test func theDeckKeepsToTheBooksOwnChapters() throws {
        #expect(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...24), current: 24) == nil)
        #expect(ChapterDeck(edge: .top, opening: .pull, chapters: Array(1...24), current: 1) == nil)
        let gappy = try #require(ChapterDeck(edge: .bottom, opening: .pull, chapters: [1, 2, 4, 5], current: 2))
        #expect(gappy.cards == [4, 5])
        let first = ChapterSwitcher.edges(chapters: Array(1...24), current: 1)
        #expect(!first.top && first.bottom)
        let last = ChapterSwitcher.edges(chapters: Array(1...24), current: 24)
        #expect(last.top && !last.bottom)
        let only = ChapterSwitcher.edges(chapters: [1], current: 1)
        #expect(!only.top && !only.bottom)
    }

    /// Matt, 2026-11-13: the cards cross books. Past this book's last chapter the stack ends on
    /// one more card, the next book's first chapter; before its first, the previous book's last.
    /// At a book's own end that card is the whole stack. A tap on it lands by the same rules as
    /// a chapter's: the next book at its start; the previous book's last chapter at its end when
    /// it is the one chapter back after a pull at the top, else at its start.
    @Test func theStackEndsOnTheNeighbouringBook() throws {
        typealias BookEnd = ChapterSwitcher.BookEnd
        let joshua = BookEnd(book: "JOS", name: "Joshua", chapter: 1)
        let numbers = BookEnd(book: "NUM", name: "Numbers", chapter: 36)
        var foot = try #require(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...34), current: 32, beyond: joshua))
        #expect(foot.cards == [33, 34] && foot.count == 3 && !foot.isFrontBook)
        foot.flip(by: 5)
        #expect(foot.frontIndex == 2 && foot.isFrontBook && foot.front == 1, "the last card is Joshua's")
        #expect(foot.landingOnBook().map { "\($0.book) \($0.chapter) \($0.atEnd)" } == "JOS 1 false")
        // At the book's last chapter the neighbouring book is the whole stack.
        let last = try #require(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...34), current: 34, beyond: joshua))
        #expect(last.cards.isEmpty && last.count == 1 && last.isFrontBook)
        #expect(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...34), current: 34) == nil, "and with no book beyond, none")
        // Back from a book's first chapter: the previous book's last, at its end (one chapter back).
        let top = try #require(ChapterDeck(edge: .top, opening: .pull, chapters: Array(1...34), current: 1, beyond: numbers))
        #expect(top.isFrontBook && top.front == 36)
        #expect(top.landingOnBook().map { "\($0.book) \($0.chapter) \($0.atEnd)" } == "NUM 36 true")
        // From further in, the previous book is back by more than one: at its start.
        let further = try #require(ChapterDeck(edge: .top, opening: .pull, chapters: Array(1...34), current: 3, beyond: numbers))
        #expect(further.cards == [2, 1] && further.landingOnBook()?.atEnd == false)
        let coasted = try #require(ChapterDeck(edge: .top, opening: .arrival, chapters: Array(1...34), current: 1, beyond: numbers))
        #expect(coasted.landingOnBook()?.atEnd == false, "after a coast: its start")
        #expect(foot.landing(on: 33)?.atEnd == false && ChapterDeck(edge: .bottom, opening: .pull, chapters: [1], current: 1)?.landingOnBook() == nil)
        // Either end has a switcher when there is a book beyond it.
        let genesisOne = ChapterSwitcher.edges(chapters: Array(1...50), current: 1, previous: nil, next: nil)
        #expect(!genesisOne.top && genesisOne.bottom)
        let obadiah = ChapterSwitcher.edges(chapters: [1], current: 1, previous: BookEnd(book: "AMO", name: "Amos", chapter: 9),
                                            next: BookEnd(book: "JON", name: "Jonah", chapter: 1))
        #expect(obadiah.top && obadiah.bottom)
    }

    /// Matt, 2026-11-13: "I can't swipe into the 2nd chapter. It stops at the first of the next
    /// book." The stack runs on through the books beyond: after this book's chapters, the next
    /// book's first (its title card), its second and on, then the book after's title card. Each
    /// book's first card is a title card and no other is; a tap on any lands in its book, at its
    /// chapter's start going on.
    @Test func theStackRunsOnThroughTheBooksBeyond() throws {
        typealias BookEnd = ChapterSwitcher.BookEnd
        let joshua = (1...3).map { BookEnd(book: "JOS", name: "Joshua", chapter: $0) }
        let judges = [BookEnd(book: "JDG", name: "Judges", chapter: 1)]
        var deck = try #require(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...34), current: 33,
                                            beyond: joshua[0], then: Array(joshua.dropFirst()) + judges))
        #expect(deck.cards == [34] && deck.count == 5)
        #expect((0..<5).map { deck.isBook(at: $0) } == [false, true, false, false, true])
        deck.flip(by: 2)
        #expect(deck.front == 2 && !deck.isFrontBook && deck.other(at: deck.frontIndex) == joshua[1])
        #expect(deck.landingBeyond(at: 2).map { "\($0.book) \($0.chapter) \($0.atEnd)" } == "JOS 2 false")
        deck.flip(by: 9)
        #expect(deck.frontIndex == 4 && deck.isFrontBook && deck.front == 1, "Judges' title card, the stack's last here")
        #expect(deck.landingBeyond(at: 0) == nil, "this book's own card lands by its chapter")
        // Back the other way: the previous book's last chapter is its title card, then the one before.
        let numbers = [36, 35].map { BookEnd(book: "NUM", name: "Numbers", chapter: $0) }
        let back = try #require(ChapterDeck(edge: .top, opening: .pull, chapters: Array(1...34), current: 1,
                                            beyond: numbers[0], then: [numbers[1]]))
        #expect(back.isBook(at: 0) && !back.isBook(at: 1))
        #expect(back.landingBeyond(at: 0)?.atEnd == true && back.landingBeyond(at: 1)?.atEnd == false, "only the one chapter back lands at its end")
    }

    /// A flick brings the next card forward or the last one back, and stops at either end.
    @Test func flickingMovesThroughTheStackAndStopsAtItsEnds() throws {
        var deck = try #require(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...12), current: 9))
        var moved = deck.flip(by: 1)
        #expect(moved && deck.front == 11)
        moved = deck.flip(by: 1)
        #expect(moved && deck.front == 12)
        moved = deck.flip(by: 1)
        #expect(!moved && deck.front == 12, "the book's last chapter")
        moved = deck.flip(by: -5)
        #expect(moved && deck.front == 10, "back to the first card, no further")
        moved = deck.flip(by: -1)
        #expect(!moved)
    }

    /// Matt's landing rules (spec 3.2): forward at the chapter's start; back by one after a pull
    /// at the top at that chapter's end; back by more at its start; after a coast, at its start.
    @Test func aTapLandsByMattsRules() throws {
        let foot = try #require(ChapterDeck(edge: .bottom, opening: .pull, chapters: Array(1...24), current: 8))
        #expect(foot.landing(on: 9).map { [$0.chapter, $0.atEnd ? 1 : 0] } == [9, 0])
        #expect(foot.landing(on: 12).map { [$0.chapter, $0.atEnd ? 1 : 0] } == [12, 0])
        #expect(foot.landing(on: 8) == nil, "the chapter being read has no card")
        #expect(foot.landing(on: 3) == nil, "nor has one the other way")
        let top = try #require(ChapterDeck(edge: .top, opening: .pull, chapters: Array(1...24), current: 8))
        #expect(top.landing(on: 7).map { [$0.chapter, $0.atEnd ? 1 : 0] } == [7, 1], "back by one: its end")
        #expect(top.landing(on: 5).map { [$0.chapter, $0.atEnd ? 1 : 0] } == [5, 0], "back by more: its start")
        let coasted = try #require(ChapterDeck(edge: .top, opening: .arrival, chapters: Array(1...24), current: 8))
        #expect(coasted.landing(on: 7).map { [$0.chapter, $0.atEnd ? 1 : 0] } == [7, 0], "after a coast: its start")
        // The previous chapter the translation has, when the one before is missing.
        let gappy = try #require(ChapterDeck(edge: .top, opening: .pull, chapters: [1, 2, 4, 5], current: 4))
        #expect(gappy.landing(on: 2).map { [$0.chapter, $0.atEnd ? 1 : 0] } == [2, 1])
    }

    /// A card shows the chapter's opening verses, each with its own number (Matt, 2026-11-13:
    /// "the verses are missing their verse numbers") and its text on one line, poetry's lines as
    /// spaces, until there is enough to fill the card.
    @Test func aCardShowsTheChaptersOpeningVersesWithTheirNumbers() {
        typealias Verse = ChapterSwitcher.Verse
        #expect(ChapterSwitcher.openingVerses(of: [Verse(number: 1, text: "In the beginning"), Verse(number: 2, text: "And the earth")], atLeast: 10)
                == [Verse(number: 1, text: "In the beginning")])
        #expect(ChapterSwitcher.openingVerses(of: [Verse(number: 1, text: "Blessed is the man\nwho walks not"), Verse(number: 2, text: "but his delight"),
                                                    Verse(number: 3, text: "He is like a tree")], atLeast: 40)
                == [Verse(number: 1, text: "Blessed is the man who walks not"), Verse(number: 2, text: "but his delight")])
        #expect(ChapterSwitcher.openingVerses(of: [Verse(number: 1, text: ""), Verse(number: 2, text: "Jesus wept.")]) == [Verse(number: 2, text: "Jesus wept.")])
        #expect(ChapterSwitcher.openingVerses(of: []).isEmpty)
    }

    @Test func theCardsComeInWithThePull() {
        #expect(ChapterSwitcher.pullThreshold == 56)
        #expect(ChapterSwitcher.reveal(forPull: 0) == 0)
        #expect(ChapterSwitcher.reveal(forPull: 28) == 0.5)
        #expect(ChapterSwitcher.reveal(forPull: 56) == 1)
        #expect(ChapterSwitcher.reveal(forPull: 200) == 1)
        #expect(ChapterSwitcher.reveal(forPull: -10) == 0)
    }

    // MARK: The tracker

    /// A page whose scroll runs from 0 to 1,000.
    private let ends: ClosedRange<CGFloat> = 0...1000

    /// Drags from `start` through `ys`, a tick every 16 ms, and lifts at the last with
    /// `velocity`; every event reported, in order.
    private func drag(from start: CGFloat, through ys: [CGFloat], liftVelocity velocity: CGFloat,
                      busy: Bool = false, tracker: inout ChapterSwitcherTracker) -> [Event] {
        var time: CFTimeInterval = 10
        var events: [Event] = []
        tracker.dragBegan(atY: start, at: time, ends: ends)
        for y in ys {
            time += 0.016
            if let event = tracker.scrolled(toY: y, at: time, ends: ends, isBusy: busy) { events.append(event) }
        }
        if let event = tracker.dragEnded(atY: ys.last ?? start, at: time, velocity: velocity, ends: ends) { events.append(event) }
        return events
    }

    /// Matt, 2026-11-13: "sometimes attempting to scroll down past the end ... doesn't make it
    /// show up". A drag that begins mid-page, reaches the foot and pulls on is a pull: each tick
    /// past the end reports how far, and letting go past the threshold opens the switcher.
    @Test func aPullOpensFromAnyDrag() {
        var tracker = ChapterSwitcherTracker()
        let events = drag(from: 700, through: [850, 1000, 1020, 1045, 1062], liftVelocity: 120, tracker: &tracker)
        #expect(events == [
            .pulled(edge: .bottom, distance: 20), .pulled(edge: .bottom, distance: 45), .pulled(edge: .bottom, distance: 62),
            .opened(edge: .bottom, opening: .pull, speed: 120),
        ])
    }

    /// The same at the top, pulling down.
    @Test func aPullAtTheTopOpensTheTopsSwitcher() {
        var tracker = ChapterSwitcherTracker()
        let events = drag(from: 200, through: [-20, -45, -70], liftVelocity: -60, tracker: &tracker)
        #expect(events.last == .opened(edge: .top, opening: .pull, speed: 60))
        #expect(events.first == .pulled(edge: .top, distance: 20))
    }

    /// From inside the page, letting go short of the threshold opens nothing, and so does a pull
    /// eased back under it before the finger lifts.
    @Test func aShortPullAndAPullEasedBackOpenNothing() {
        var tracker = ChapterSwitcherTracker()
        #expect(drag(from: 900, through: [1000, 1020, 1040], liftVelocity: 0, tracker: &tracker).last == .cancelled)
        #expect(drag(from: 900, through: [1030, 1070, 1040, 1030], liftVelocity: -200, tracker: &tracker).last == .cancelled)
    }

    /// Matt's film, 2026-11-13: at the foot of Genesis 14 he flicked up again and again and the
    /// cards never came. From a page already at an end, going on at all is the whole intent: a
    /// flick outward opens the switcher there, though the finger lifted with the page barely
    /// past its end; so does a short, slow pull; so does a second try while the page is still
    /// springing back from the first.
    @Test func fromThePagesEndAFlickOrAShortPullOpens() {
        #expect(ChapterSwitcher.restPull == 20 && ChapterSwitcher.restFlick == 300 && ChapterSwitcher.restReach == 8)
        var tracker = ChapterSwitcherTracker()
        #expect(drag(from: 1000, through: [1006, 1012], liftVelocity: 1800, tracker: &tracker).last
                == .opened(edge: .bottom, opening: .pull, speed: 1800), "a flick at the foot")
        #expect(drag(from: 1000, through: [], liftVelocity: 900, tracker: &tracker).last
                == .opened(edge: .bottom, opening: .pull, speed: 900), "a flick too quick to have moved the page")
        #expect(drag(from: 1000, through: [1010, 1024], liftVelocity: 0, tracker: &tracker).last
                == .opened(edge: .bottom, opening: .pull, speed: 0), "a short, slow pull")
        #expect(drag(from: 1035, through: [1040], liftVelocity: 600, tracker: &tracker).last
                == .opened(edge: .bottom, opening: .pull, speed: 600), "while it springs back from the last try")
        #expect(drag(from: 0, through: [-5], liftVelocity: -700, tracker: &tracker).last
                == .opened(edge: .top, opening: .pull, speed: 700), "a flick down at the top")
        // Not a go at going on: a touch that barely moves, and a drag back into the chapter.
        #expect(drag(from: 1000, through: [1004], liftVelocity: 60, tracker: &tracker).last == .cancelled)
        #expect(drag(from: 1000, through: [960, 900], liftVelocity: -1500, tracker: &tracker).isEmpty)
        // Nearly at the foot is not at it: a flick from 30 points short is still reading.
        #expect(drag(from: 970, through: [1004], liftVelocity: 1500, tracker: &tracker).last == .cancelled)
    }

    /// A pull taken back inside the page says so once (the cards go), and the lift there is
    /// nothing at all.
    @Test func aPullTakenBackInsideThePageIsOver() {
        var tracker = ChapterSwitcherTracker()
        let events = drag(from: 900, through: [1030, 1070, 990, 980], liftVelocity: -300, tracker: &tracker)
        #expect(events == [.pulled(edge: .bottom, distance: 30), .pulled(edge: .bottom, distance: 70), .pulled(edge: .bottom, distance: 0)])
    }

    /// Matt, 2026-11-13: "sometimes it is too easy to make it appear when scrolling down". A
    /// flick from inside the page whose finger runs on past the end and lifts still moving fast
    /// is reading, not a pull. Lifting while the page is already on its way back is no flick.
    @Test func aFlickThatRunsOnPastTheEndOpensNothing() {
        #expect(ChapterSwitcher.flickSpeed == 800)
        var tracker = ChapterSwitcherTracker()
        #expect(drag(from: 900, through: [960, 1030, 1075], liftVelocity: 2400, tracker: &tracker).last == .cancelled)
        #expect(drag(from: 900, through: [1030, 1090, 1075], liftVelocity: -1500, tracker: &tracker).last
                == .opened(edge: .bottom, opening: .pull, speed: 1500))
    }

    /// While a selection drag, the pen or the thumb is under way nothing is pulled.
    @Test func nothingIsPulledWhileThePageIsBusy() {
        var tracker = ChapterSwitcherTracker()
        #expect(drag(from: 900, through: [1030, 1080], liftVelocity: 0, busy: true, tracker: &tracker).isEmpty)
    }

    /// Ordinary reading: a firm scroll whose coast reaches the foot at 3,000 points a second (it
    /// opened the drawer at 2,500; Matt, 2026-11-13: "too easy") opens nothing. Only a coast
    /// still faster than 5,000 as it meets the end does.
    @Test func anOrdinaryCoastOpensNothing() {
        #expect(ChapterSwitcher.arrivalSpeed == 5000)
        var tracker = ChapterSwitcherTracker()
        #expect(drag(from: 400, through: [600, 800], liftVelocity: 3000, tracker: &tracker).isEmpty)
        var time: CFTimeInterval = 11
        for y in stride(from: CGFloat(856), through: 1048, by: 48) {
            time += 0.016
            #expect(tracker.scrolled(toY: y, at: time, ends: ends, isBusy: false) == nil, "coasting past \(y)")
        }
        tracker.coastEnded()
        #expect(!tracker.isCoasting)
    }

    /// A coast reaching an end faster than the arrival speed opens the switcher there, once;
    /// its bounce back opens nothing more.
    @Test func aFastArrivalOpensOnce() {
        var tracker = ChapterSwitcherTracker()
        #expect(drag(from: 400, through: [600, 800], liftVelocity: 6000, tracker: &tracker).isEmpty)
        var events: [Event] = []
        var time: CFTimeInterval = 10.032
        for y in [CGFloat(900), 1000, 1100, 1010, 1000] {
            time += 0.016
            if let event = tracker.scrolled(toY: y, at: time, ends: ends, isBusy: false) { events.append(event) }
        }
        #expect(events.count == 1)
        guard case .opened(edge: .bottom, opening: .arrival, speed: let speed) = events.first else {
            Issue.record("no arrival: \(events)")
            return
        }
        #expect(speed > 5000)
    }
}
