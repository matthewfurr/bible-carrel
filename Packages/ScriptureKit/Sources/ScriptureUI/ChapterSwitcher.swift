import CoreGraphics
import Foundation

/// The iPhone's chapter switcher (Matt, 2026-11-13; it replaces the carry-through drawer of spec
/// 3.2 and 4.3): a stack of chapter cards kept just past each end of the page, in the page's own
/// scroll. Pulling past the end (or the top) brings the page's edge away from the screen's and
/// the cards into the space that opens, so nothing on the page is covered; let go past
/// `pullThreshold` and the page rests there, the cards in view. They stay until a card is tapped
/// (the reader turns to that chapter) or the page is tapped (they go).
///
/// This file is the logic apart from UIKit, so `swift test` covers it: the constants, the deck
/// and its landing rules, and the tracker that reads a pull from the scroll.
public enum ChapterSwitcher {
    /// How far past an end the page must be pulled, finger down, for letting go to open the
    /// switcher. It is the page's own overscroll, which the system rubber-bands: on a phone about
    /// 110 points of finger travel, as a pull to refresh takes. (The drawer's 80 took about 160
    /// and felt unreliable; Matt, 2026-11-13.) A call; tune on a device.
    public static let pullThreshold: CGFloat = 56
    /// A finger lifting faster than this, still moving outward, in a drag that began inside the
    /// page, is a flick that ran on past the end, not a pull: it opens nothing. Points per second.
    /// A call; tune on a device.
    public static let flickSpeed: CGFloat = 800
    /// From a page already at an end, going on is the whole intent (Matt's film, 2026-11-13: at
    /// the foot of Genesis 14 he flicked up again and again and nothing opened, because only a
    /// slow pull held past the threshold did). A drag that begins with the page at an end opens
    /// the switcher there when it lifts this far past it, or still moving outward this fast: a
    /// short pull or a flick alike. Points, and points per second. Calls; tune on a device.
    public static let restPull: CGFloat = 20
    public static let restFlick: CGFloat = 300
    /// Within this of an end as a drag begins (or past it, still springing back from the last
    /// try), the page is at that end.
    public static let restReach: CGFloat = 8
    /// Points per second at which a coast reaching an end opens the switcher on its own (spec
    /// 3.2, Matt: "also triggered by scrolling really quickly at the start or end"); nil, and no
    /// coast does. It is the page's speed as it meets the end, after the scroll's own slowing,
    /// so only a hard flick made near the end reaches it. The drawer's 2,500 opened it through
    /// ordinary reading (Matt, 2026-11-13); this is twice that. A call; tune on a device.
    public static let arrivalSpeed: CGFloat? = 5000
    /// How far along its way a flick must be going to end (its travel and the momentum left in
    /// it) to move the cards by one, in points.
    public static let flickTravel: CGFloat = 40

    public enum Edge: Equatable, Sendable { case top, bottom }
    public enum Opening: Equatable, Sendable { case pull, arrival }

    /// The chapter of a neighbouring book that the switcher's last card opens (Matt,
    /// 2026-11-13: the cards cross books): the next book's first chapter past this book's end,
    /// the previous book's last before its start.
    public struct BookEnd: Equatable, Sendable {
        /// The book's code and the name it is shown by.
        public let book: String
        public let name: String
        public let chapter: Int

        public init(book: String, name: String, chapter: Int) {
            self.book = book
            self.name = name
            self.chapter = chapter
        }
    }

    /// Which ends have a switcher: the top when there is a chapter before `current` (in this
    /// book, or the book before), the bottom when there is one after.
    public static func edges(chapters: [Int], current: Int, previous: BookEnd? = nil, next: BookEnd? = nil) -> (top: Bool, bottom: Bool) {
        (previous != nil || chapters.contains { $0 < current }, next != nil || chapters.contains { $0 > current })
    }

    /// How much of its entrance the cards have made for a pull of `distance`: 0 at the page's
    /// end, 1 from the threshold on.
    public static func reveal(forPull distance: CGFloat) -> CGFloat {
        min(max(distance / pullThreshold, 0), 1)
    }

    /// A verse on a chapter's card: its number and its text on one line.
    public struct Verse: Equatable, Sendable {
        public let number: Int
        public let text: String

        public init(number: Int, text: String) {
            self.number = number
            self.text = text
        }
    }

    /// What a chapter's card shows beside its number: its first verses, each with its own number
    /// and its text on one line (poetry's line breaks as spaces), until there are at least
    /// `length` characters, so the card has its few lines to fill and cuts them off itself.
    public static func openingVerses(of verses: [Verse], atLeast length: Int = 200) -> [Verse] {
        var opening: [Verse] = []
        var count = 0
        for verse in verses {
            let line = verse.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !line.isEmpty else { continue }
            opening.append(Verse(number: verse.number, text: line))
            count += line.count
            if count >= length { break }
        }
        return opening
    }
}

/// The switcher's stack of cards at one end of the page: the chapters this translation has from
/// the next one that way to the book's end (or back to its first), the nearest in front, and
/// after them the chapters of the books beyond, in reading order that way (`others`): the next
/// book's first chapter, its second, and on; or the previous book's last chapter, the one before
/// it, and back. The first card of each of those books is its title card. A flick brings the
/// next card forward or the last one back; a tap on the front card lands on it.
public struct ChapterDeck: Equatable, Sendable {
    public let edge: ChapterSwitcher.Edge
    public let opening: ChapterSwitcher.Opening
    /// The chapter being read.
    public let current: Int
    /// The cards' chapters in this book, the nearest to `current` first.
    public let cards: [Int]
    /// The cards past this book's end, in order: the chapters of the books beyond (Matt,
    /// 2026-11-13: the stack had stopped at the next book's first chapter).
    public let others: [ChapterSwitcher.BookEnd]
    public private(set) var frontIndex = 0

    /// The first card past this book's end: the neighbouring book's nearest chapter.
    public var beyond: ChapterSwitcher.BookEnd? { others.first }

    /// Nil when there is no chapter that way, in this book or another. `beyond` is the
    /// neighbouring book's nearest chapter and `then` the chapters after it, in order.
    public init?(edge: ChapterSwitcher.Edge, opening: ChapterSwitcher.Opening, chapters: [Int], current: Int,
                 beyond: ChapterSwitcher.BookEnd? = nil, then: [ChapterSwitcher.BookEnd] = []) {
        let sorted = chapters.sorted()
        let cards: [Int] = switch edge {
        case .bottom: sorted.filter { $0 > current }
        case .top: sorted.filter { $0 < current }.reversed()
        }
        guard !cards.isEmpty || beyond != nil else { return nil }
        self.edge = edge
        self.opening = opening
        self.current = current
        self.cards = cards
        self.others = beyond.map { [$0] + then } ?? []
    }

    /// How many cards the stack has: this book's, and those of the books beyond.
    public var count: Int { cards.count + others.count }

    /// The card at `index` when it is past this book's end: another book's chapter.
    public func other(at index: Int) -> ChapterSwitcher.BookEnd? {
        let place = index - cards.count
        return others.indices.contains(place) ? others[place] : nil
    }

    /// Whether the card at `index` is a book's title card: the first card of another book.
    public func isBook(at index: Int) -> Bool {
        guard let here = other(at: index) else { return false }
        return other(at: index - 1)?.book != here.book
    }

    /// Whether the front card is another book's title card.
    public var isFrontBook: Bool { isBook(at: frontIndex) }

    /// The chapter on the front card (another book's, past this book's end).
    public var front: Int { other(at: frontIndex)?.chapter ?? cards[frontIndex] }

    /// Brings the card `pages` further from the chapter being read to the front (negative: back
    /// toward it), stopping at either end of the stack. Whether the front card changed.
    @discardableResult
    public mutating func flip(by pages: Int) -> Bool {
        let target = min(max(frontIndex + pages, 0), count - 1)
        guard target != frontIndex else { return false }
        frontIndex = target
        return true
    }

    /// Where a tap on `chapter`'s card lands (Matt's rules, spec 3.2): forward, at the chapter's
    /// start; back by one chapter after a pull at the top, at the end of that chapter, as if the
    /// reader had scrolled up into it; back by more, or after a coast opened the switcher, at its
    /// start. Nil for a chapter the deck has no card for.
    public func landing(on chapter: Int) -> (chapter: Int, atEnd: Bool)? {
        guard cards.contains(chapter) else { return nil }
        return (chapter, edge == .top && opening == .pull && chapter == cards[0])
    }

    /// Where a tap on the card at `index` lands when it is another book's chapter, by the same
    /// rules: forward, at that chapter's start; back, at its end only when it is the one chapter
    /// back (the stack's first card, after a pull at the top), else at its start. Nil when the
    /// card at `index` is this book's, or there is none.
    public func landingBeyond(at index: Int) -> (book: String, chapter: Int, atEnd: Bool)? {
        guard let card = other(at: index) else { return nil }
        return (card.book, card.chapter, edge == .top && opening == .pull && index == 0)
    }

    /// Where a tap on the neighbouring book's title card lands (`landingBeyond` for the first
    /// card past this book's end).
    public func landingOnBook() -> (book: String, chapter: Int, atEnd: Bool)? {
        landingBeyond(at: cards.count)
    }
}

/// Reads the switcher's pull from the page's scroll (the offsets, times and page ends the phone's
/// text controller hands it), apart from UIKit:
///
/// - **A pull:** the finger dragging the page past an end, in any drag (the drawer asked for one
///   that began with the page at rest there, and so missed the natural one: scrolling to the end
///   and pulling on). Every tick of it reports how far past the end the page is; a tick back
///   inside the page reports 0, once.
/// - **Letting go** past `ChapterSwitcher.pullThreshold` opens the switcher at that end; short of
///   it, or as a flick that only ran on past the end (`flickSpeed`), the pull is cancelled and
///   the page springs back as it always has.
/// - **From a page already at an end** going on at all opens it: a short pull (`restPull`) or a
///   flick outward (`restFlick`), which is how a reader at the foot of a chapter asks for more.
/// - **A coast** reaching an end faster than `arrivalSpeed` opens it too, when that is set.
///
/// Ordinary reading opens nothing: a scroll that stops at the end, a flick that bounces off it,
/// a pull eased back before the finger lifts.
public struct ChapterSwitcherTracker {
    public enum Event: Equatable, Sendable {
        /// The finger is pulling the page `distance` past `edge` (0: back inside the page).
        case pulled(edge: ChapterSwitcher.Edge, distance: CGFloat)
        /// The switcher opens at `edge`; `speed` is the page's, in points per second, as it does.
        case opened(edge: ChapterSwitcher.Edge, opening: ChapterSwitcher.Opening, speed: CGFloat)
        /// The finger lifted on a pull that opens nothing.
        case cancelled
    }

    /// Within this of an end, the page is at it.
    static let edgeTolerance: CGFloat = 1
    /// Ticks closer together than this (two in one frame) keep the speed already measured.
    static let shortestTick: CFTimeInterval = 0.001

    /// See `ChapterSwitcher.arrivalSpeed`; a test sets its own.
    public var arrivalSpeed: CGFloat? = ChapterSwitcher.arrivalSpeed

    public private(set) var isDragging = false
    public private(set) var isCoasting = false
    /// The ends the page was at rest at when this drag began. Set afresh by each drag.
    private var stoppedAtTop = false
    private var stoppedAtBottom = false
    /// Points per second, from the finger's lift velocity and then the coast's own ticks.
    public private(set) var speed: CGFloat = 0
    /// The edge this drag is pulling past, while it is past it.
    private var pulledEdge: ChapterSwitcher.Edge?
    /// The ends this coast has reached (or started at), so it arrives at each at most once.
    private var coastReachedTop = false
    private var coastReachedBottom = false
    private var lastTick: (y: CGFloat, time: CFTimeInterval)?

    public init() {}

    /// How far past which end `y` is, if it is past one.
    private static func past(_ y: CGFloat, _ ends: ClosedRange<CGFloat>) -> (edge: ChapterSwitcher.Edge, distance: CGFloat)? {
        if y > ends.upperBound + edgeTolerance { return (.bottom, y - ends.upperBound) }
        if y < ends.lowerBound - edgeTolerance { return (.top, ends.lowerBound - y) }
        return nil
    }

    public mutating func dragBegan(atY y: CGFloat, at time: CFTimeInterval, ends: ClosedRange<CGFloat>) {
        isDragging = true
        isCoasting = false
        pulledEdge = nil
        stoppedAtTop = y <= ends.lowerBound + ChapterSwitcher.restReach
        stoppedAtBottom = y >= ends.upperBound - ChapterSwitcher.restReach
        speed = 0
        lastTick = (y, time)
    }

    /// A scroll tick: a pull while the finger is down, an arrival while coasting. `isBusy` (a
    /// selection drag, the pen, the thumb) is asked only when the tick would report, never on
    /// the ticks of ordinary reading; while it holds, nothing is pulled.
    public mutating func scrolled(toY y: CGFloat, at time: CFTimeInterval, ends: ClosedRange<CGFloat>,
                                  isBusy: @autoclosure () -> Bool) -> Event? {
        if let lastTick {
            let interval = time - lastTick.time
            if interval >= Self.shortestTick {
                speed = abs(y - lastTick.y) / CGFloat(interval)
                self.lastTick = (y, time)
            }
        } else {
            lastTick = (y, time)
        }
        if isDragging {
            if let past = Self.past(y, ends), !isBusy() {
                pulledEdge = past.edge
                return .pulled(edge: past.edge, distance: past.distance)
            }
            // Back inside the page (or the page turned busy): the pull is at nothing, said once.
            guard let edge = pulledEdge else { return nil }
            pulledEdge = nil
            return .pulled(edge: edge, distance: 0)
        }
        guard isCoasting, let arrivalSpeed else { return nil }
        let edge: ChapterSwitcher.Edge
        if !coastReachedBottom, y >= ends.upperBound - Self.edgeTolerance {
            coastReachedBottom = true
            edge = .bottom
        } else if !coastReachedTop, y <= ends.lowerBound + Self.edgeTolerance {
            coastReachedTop = true
            edge = .top
        } else {
            return nil
        }
        guard speed > arrivalSpeed, !isBusy() else { return nil }
        return .opened(edge: edge, opening: .arrival, speed: speed)
    }

    /// The finger lifted at `y`, the page moving at `velocity` points per second (positive toward
    /// the page's foot, as the offset grows): a pull under way opens the switcher or is
    /// cancelled, and the coast begins. An end the page is at or past as the finger lifts is
    /// already reached (its bounce back is no arrival).
    public mutating func dragEnded(atY y: CGFloat, at time: CFTimeInterval, velocity: CGFloat,
                                   ends: ClosedRange<CGFloat>) -> Event? {
        let pulled = pulledEdge
        let beganAtTop = stoppedAtTop, beganAtBottom = stoppedAtBottom
        isDragging = false
        pulledEdge = nil
        isCoasting = true
        speed = abs(velocity)
        lastTick = (y, time)
        coastReachedTop = y <= ends.lowerBound + Self.edgeTolerance
        coastReachedBottom = y >= ends.upperBound - Self.edgeTolerance
        // From a page at an end: any real go at going on opens the switcher there, a short pull
        // or a flick (which may lift before the page has moved at all).
        let past = Self.past(y, ends)
        for edge in [ChapterSwitcher.Edge.bottom, .top] where edge == .bottom ? beganAtBottom : beganAtTop {
            let outward = edge == .bottom ? velocity : -velocity
            let distance = past?.edge == edge ? past?.distance ?? 0 : 0
            if distance >= ChapterSwitcher.restPull || (outward >= ChapterSwitcher.restFlick && past?.edge != (edge == .bottom ? .top : .bottom)) {
                return .opened(edge: edge, opening: .pull, speed: abs(velocity))
            }
        }
        guard let pulled else { return nil }
        // From inside the page: a pull held past the threshold, not a flick that ran on.
        guard let past, past.edge == pulled, past.distance >= ChapterSwitcher.pullThreshold else { return .cancelled }
        let outward = pulled == .bottom ? velocity : -velocity
        if outward > ChapterSwitcher.flickSpeed { return .cancelled }
        return .opened(edge: pulled, opening: .pull, speed: abs(velocity))
    }

    /// The coast stopped (or the finger lifted without one).
    public mutating func coastEnded() {
        isCoasting = false
    }

    /// The controller moved the page itself (a jump, a new chapter): the end it was stopped at and
    /// any coast are over. A pull under way is still settled when the finger lifts.
    public mutating func pageMoved() {
        isCoasting = false
        stoppedAtTop = false
        stoppedAtBottom = false
    }
}
