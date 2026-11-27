#if os(iOS)
import CoreText
import Observation
import SwiftUI
import UIKit

/// The chapter switcher's state on the reader screen (`ChapterSwitcher`): the deck at the end
/// being pulled or open, how far its cards have come in, and whether it is open. The page's text
/// controller writes it as the scroll goes (`pulled`, `opened`, `closed`), and only the cards'
/// view (`ChapterSwitcherDeckView`, hosted inside the page's scroll) reads it, so a pull's ticks
/// redraw the cards alone, never the screen.
///
/// The screen gives it the book (`chapters`, `current`), each chapter's opening words, where a
/// tap lands, and whether the switcher may show at all (`isAllowed`: not while VoiceOver runs,
/// the pen is on or a sheet covers the page).
@MainActor @Observable final class ChapterSwitcherModel {
    private(set) var deck: ChapterDeck?
    /// The cards' entrance: 0 at the page's end, 1 from the pull's threshold on and while open.
    private(set) var reveal: CGFloat = 0
    private(set) var isOpen = false
    /// The finger's travel along the flick's way while a flick on the open cards is under way,
    /// in points (positive: onward): the front card rides it.
    private(set) var dragTravel: CGFloat = 0
    /// Points per second the page was moving as the switcher opened: how hard the cards wobble
    /// as they settle.
    @ObservationIgnored private(set) var entranceSpeed: CGFloat = 0

    /// The chapters this translation has for the open book, and the one being read (`show`).
    @ObservationIgnored private(set) var chapters: [Int] = []
    @ObservationIgnored private(set) var current = 0
    /// The books either side of the open one, by the chapter of each the switcher's last card
    /// opens (`show`); nil at the Bible's ends.
    @ObservationIgnored private(set) var previousBook: ChapterSwitcher.BookEnd?
    @ObservationIgnored private(set) var nextBook: ChapterSwitcher.BookEnd?
    /// How many times a neighbouring book's card has come to the front: the cards close up and
    /// fan out again as it does.
    private(set) var bookArrivals = 0
    /// The opening verses of a chapter of the open book, for its card.
    @ObservationIgnored var openingVerses: (Int) -> [ChapterSwitcher.Verse] = { _ in [] }
    /// Every chapter past this book's end at `edge`, in reading order that way, for the stack to
    /// run on through (asked only as a stack is made). Without it the stack ends on the
    /// neighbouring book's nearest chapter.
    @ObservationIgnored var cardsBeyond: (ChapterSwitcher.Edge) -> [ChapterSwitcher.BookEnd] = { _ in [] }
    /// The opening verses of a neighbouring book's chapter, for its card.
    @ObservationIgnored var bookOpeningVerses: (ChapterSwitcher.BookEnd) -> [ChapterSwitcher.Verse] = { _ in [] }
    /// A tap on a card: turn to its chapter (of `book`; nil is the open book), at its start or
    /// with its foot in view.
    @ObservationIgnored var onLand: (_ book: String?, _ chapter: Int, _ atEnd: Bool) -> Void = { _, _, _ in }
    /// Whether the switcher may show. Set through `allow(_:)`.
    @ObservationIgnored private(set) var isAllowed = true
    /// Closes the switcher on the page (the text controller's, which owns the scroll).
    @ObservationIgnored var closeOnPage: (_ animated: Bool) -> Void = { _ in }

    @ObservationIgnored private var words: [Int: [ChapterSwitcher.Verse]] = [:]
    @ObservationIgnored private var bookWords: [String: [ChapterSwitcher.Verse]] = [:]
    @ObservationIgnored private var book: String?
    @ObservationIgnored private let arm = UIImpactFeedbackGenerator(style: .medium)
    @ObservationIgnored private let flipTap = UIImpactFeedbackGenerator(style: .light)

    /// Which ends have a switcher now.
    var edges: (top: Bool, bottom: Bool) {
        isAllowed ? ChapterSwitcher.edges(chapters: chapters, current: current, previous: previousBook, next: nextBook) : (false, false)
    }

    /// The screen's say on whether the switcher may show; taking it away closes it.
    func allow(_ allowed: Bool) {
        guard allowed != isAllowed else { return }
        isAllowed = allowed
        if !allowed { close() }
    }

    /// Closes the switcher from outside (a sheet, the pen, rotation), without moving.
    func close(animated: Bool = true) {
        guard deck != nil else { return }
        closeOnPage(animated)
    }

    /// The opening verses on `chapter`'s card, fetched once per chapter shown.
    func verses(for chapter: Int) -> [ChapterSwitcher.Verse] {
        if let known = words[chapter] { return known }
        let fetched = openingVerses(chapter)
        words[chapter] = fetched
        return fetched
    }

    /// The book as it is now. `book` names the book and its translation; when it changes, the
    /// cards' words are another's and are fetched again.
    func show(book: String?, chapters: [Int], current: Int,
              previous: ChapterSwitcher.BookEnd? = nil, next: ChapterSwitcher.BookEnd? = nil) {
        if book != self.book {
            self.book = book
            words = [:]
            bookWords = [:]
        }
        self.chapters = chapters
        self.current = current
        previousBook = previous
        nextBook = next
    }

    /// The opening verses on a neighbouring book's card, fetched once.
    func verses(for end: ChapterSwitcher.BookEnd) -> [ChapterSwitcher.Verse] {
        let key = "\(end.book) \(end.chapter)"
        if let known = bookWords[key] { return known }
        let fetched = bookOpeningVerses(end)
        bookWords[key] = fetched
        return fetched
    }

    /// The deck at `edge` as the book stands now.
    private func deck(at edge: ChapterSwitcher.Edge, opening: ChapterSwitcher.Opening) -> ChapterDeck? {
        let beyond = cardsBeyond(edge)
        guard !beyond.isEmpty else {
            return ChapterDeck(edge: edge, opening: opening, chapters: chapters, current: current,
                               beyond: edge == .bottom ? nextBook : previousBook)
        }
        return ChapterDeck(edge: edge, opening: opening, chapters: chapters, current: current,
                           beyond: beyond[0], then: Array(beyond.dropFirst()))
    }

    // MARK: From the page's scroll

    /// The finger is pulling the page `distance` past `edge`: the cards come in with it, and a
    /// tap marks the pull crossing the threshold, where letting go opens them.
    func pulled(edge: ChapterSwitcher.Edge, distance: CGFloat) {
        if deck?.edge != edge || isOpen {
            guard let next = deck(at: edge, opening: .pull) else { return }
            deck = next
            isOpen = false
            arm.prepare()
        }
        let next = ChapterSwitcher.reveal(forPull: distance)
        if next >= 1, reveal < 1 { arm.impactOccurred() }
        if next != reveal { reveal = next }
    }

    /// The switcher is open at `edge`: the page rests with the cards in view.
    func opened(edge: ChapterSwitcher.Edge, opening: ChapterSwitcher.Opening, speed: CGFloat = 0) {
        entranceSpeed = speed
        if deck?.edge != edge || deck?.opening != opening {
            deck = deck(at: edge, opening: opening)
        }
        guard let opened = deck else { return }
        reveal = 1
        isOpen = true
        flipTap.prepare()
        // A stack whose only card is another book's opens on it: the same firm tap.
        if opened.isFrontBook { arriveAtBook() }
    }

    /// The page is closing over the cards: they fade as it does.
    func closing() {
        isOpen = false
        reveal = 0
        dragTravel = 0
    }

    /// The cards are gone.
    func closed() {
        deck = nil
        reveal = 0
        isOpen = false
        dragTravel = 0
    }

    // MARK: From the cards, or a flick anywhere on the page while they are open

    /// A flick under way has travelled `travel` points onward (negative: back).
    func drag(onward travel: CGFloat) {
        guard isOpen, travel != dragTravel else { return }
        dragTravel = travel
    }

    /// The flick ended, predicted to end `predicted` points onward (its travel and the momentum
    /// left in it): past `ChapterSwitcher.flickTravel` either way it moves the cards by one.
    func endDrag(predictedOnward predicted: CGFloat) {
        let pages = predicted > ChapterSwitcher.flickTravel ? 1 : predicted < -ChapterSwitcher.flickTravel ? -1 : 0
        dragTravel = 0
        if pages != 0 { flip(by: pages) }
    }

    /// A flick on the open cards: the next card forward (positive) or the last one back. Back
    /// from the first card pushes the stack under the page again: the switcher closes.
    func flip(by pages: Int) {
        guard isOpen, var next = deck else { return }
        if next.flip(by: pages) {
            deck = next
            if next.isFrontBook {
                arriveAtBook()
            } else {
                flipTap.impactOccurred()
                flipTap.prepare()
            }
        } else if pages < 0 {
            close()
        }
    }

    /// Another book's card has come to the front: a firmer tap than a chapter's, and the cards
    /// close up and fan out again (Matt, 2026-11-13), so the edge of the book is felt and seen.
    private func arriveAtBook() {
        arm.impactOccurred()
        arm.prepare()
        bookArrivals += 1
    }

    /// A tap on `chapter`'s card: the reader turns to it.
    func choose(_ chapter: Int) {
        guard isOpen, let landing = deck?.landing(on: chapter) else { return }
        onLand(nil, landing.chapter, landing.atEnd)
    }

    /// A tap on the front card: the reader turns to its chapter, in this book or another.
    func chooseFront() {
        guard isOpen, let deck else { return }
        if let landing = deck.landingBeyond(at: deck.frontIndex) {
            onLand(landing.book, landing.chapter, landing.atEnd)
        } else if deck.cards.indices.contains(deck.frontIndex) {
            choose(deck.cards[deck.frontIndex])
        }
    }

    /// A tap on the neighbouring book's title card, when it is at the front.
    func chooseBook() {
        guard deck?.isFrontBook == true else { return }
        chooseFront()
    }
}

/// The chapter switcher's cards (Matt, 2026-11-13), hosted inside the page's scroll just past the
/// chapter's foot or above its top, so they come into view as the page is pulled and nothing on
/// the page is covered.
///
/// - **The stack:** the front card and up to two behind it, each behind standing `peek` further
///   from the page and a step smaller.
/// - **Coming in, like liquid** (Matt: the motion is the liquid part, not the material): while
///   the finger pulls, the stack is drawn out of the page's edge, squeezed narrow and short and
///   filling out as the pull goes; as the switcher opens it lets go, stretching past its size by
///   the speed it was let go with and wobbling back to rest, the cards behind fanning out
///   (`settle`, `fan`). Under Reduce Motion it fades in at its size.
/// - **A card** follows the reader's page style: a quiet sheet on `paper.overlay` with an
///   `ink.rule` hairline (DESIGN.md's one stroke exception), radius `lg`. On it "Chapter" in the
///   style's running-head voice over the chapter's number as a drop numeral (the page face's
///   lining figures, `accent`), and beside them the chapter's opening verses as the page sets
///   them: the page face at `.callout`, each verse with its number in the style's own number
///   face and ink (none where the reader has turned numbers off; none on verse 1 in Lectern,
///   whose numeral stands for it).
/// - **Flicking:** a flick on the cards, or anywhere on the page while they are open (the page's
///   text controller reports it), the way the page was pulled sends the front card on past the
///   page and brings the next forward; a flick back returns it, and back from the first card
///   pushes the stack away (the switcher closes). Each new front card is a light tap.
/// - **Choosing:** a tap on the front card opens its chapter. The cards stay until then, or
///   until the page is tapped.
///
/// It always keeps its full height, cards or none, so the page can measure the room it needs.
/// Hidden from VoiceOver, which the foot's links and the book thumb serve; the screen does not
/// allow it while VoiceOver runs.
struct ChapterSwitcherDeckView: View {
    let model: ChapterSwitcherModel
    /// The reader's typography: the page style and face, for everything on a card.
    let typography: ReaderTypography

    // MARK: Motion (calls; tune on a device)

    /// A card going on or coming back.
    static let flip = Animation.spring(response: 0.34, dampingFraction: 0.78)
    /// The cards behind fanning out as the switcher opens: it overshoots and settles.
    static let fan = Animation.spring(response: 0.42, dampingFraction: 0.58)
    /// The stack wobbling back to its size after it lets go of the page's edge.
    static let settle = Animation.spring(response: 0.5, dampingFraction: 0.42)
    /// Reduce Motion's flip and fan.
    static let fade = Animation.snappy(duration: 0.2)
    /// Cards standing behind the front one.
    static let cardsBehind = 2
    /// Each card behind is this much smaller than the one in front of it.
    static let scaleStep: CGFloat = 0.05
    /// How much of their fan the cards behind show while the finger still pulls.
    static let closedFan: CGFloat = 0.25
    /// A card sent on travels this far past the page, in card heights, as it fades.
    static let sendTravel: CGFloat = 0.6
    /// The stack's width and height, of its own, as a pull begins: it fills out to 1 by the threshold.
    static let drawnOut: (width: CGFloat, height: CGFloat) = (0.84, 0.62)
    /// The most the stack stretches past its height as it lets go, and the page speed (points
    /// per second) that stretches it that far; it narrows by `squeeze` of the stretch.
    static let greatestStretch: CGFloat = 0.14
    static let stretchSpeed: CGFloat = 3000
    static let squeeze: CGFloat = 0.4

    /// The stack's scale while the finger pulls, at `reveal` of the way to the threshold.
    static func drawnScale(reveal: CGFloat) -> CGSize {
        CGSize(width: drawnOut.width + (1 - drawnOut.width) * reveal, height: drawnOut.height + (1 - drawnOut.height) * reveal)
    }

    /// How far past its height the stack stretches as it lets go at `speed`: at least a little,
    /// so even a slow pull settles with life.
    static func stretch(forSpeed speed: CGFloat) -> CGFloat {
        greatestStretch * min(max(speed / stretchSpeed, 0.35), 1)
    }

    // MARK: Geometry

    @ScaledMetric(relativeTo: .title) private var cardHeight: CGFloat = AppSpacing.xxxl + AppSpacing.xxl
    @ScaledMetric(relativeTo: .title) private var peek: CGFloat = AppSpacing.xs
    @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: CGFloat = AppSpacing.xxl
    @ScaledMetric(relativeTo: .callout) private var wordsSize: CGFloat = PageFace.baseSize(.callout)
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = PageFace.baseSize(.caption)
    @ScaledMetric(relativeTo: .callout) private var padding: CGFloat = AppSpacing.md

    /// The stretch past its size the stack still has to settle from, as it lets go.
    @State private var stretch: CGFloat = 0
    /// The cards behind drawn in close, for the moment a neighbouring book's card arrives.
    @State private var isClosedUp = false
    @ScaledMetric(relativeTo: .title2) private var bookNameSize: CGFloat = PageFace.baseSize(.title2)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    #if DEBUG
    /// How many times `body` has been evaluated, in debug builds only (the screen's gate checks
    /// that a pull reaches this view and not the screen).
    @MainActor static var bodyEvaluations = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyEvaluations += 1
        #endif
        let deck = model.deck
        let atTop = deck?.edge == .top
        let drawn = reduceMotion || model.isOpen ? CGSize(width: 1, height: 1) : Self.drawnScale(reveal: model.reveal)
        ZStack(alignment: atTop ? .bottom : .top) {
            if let deck {
                ForEach(slots(of: deck)) { slot in
                    card(slot, in: deck)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight + CGFloat(Self.cardsBehind) * peek, alignment: atTop ? .bottom : .top)
        // Drawn out of the page's edge, then let go: anchored at the side the page is on.
        .scaleEffect(x: drawn.width * (1 - stretch * Self.squeeze), y: drawn.height * (1 + stretch), anchor: atTop ? .bottom : .top)
        .opacity(Double(model.reveal))
        .contentShape(Rectangle())
        .allowsHitTesting(model.isOpen)
        .animation(reduceMotion ? Self.fade : Self.fan, value: model.isOpen)
        .animation(reduceMotion ? Self.fade : Self.flip, value: deck?.frontIndex)
        .animation(reduceMotion ? nil : Self.flip, value: model.dragTravel == 0)
        .onChange(of: model.bookArrivals) {
            guard !reduceMotion else { return }
            // Close up quickly, then fan out again on the opening's spring.
            withAnimation(.snappy(duration: 0.12)) { isClosedUp = true }
            Task {
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(Self.fan) { isClosedUp = false }
            }
        }
        .onChange(of: model.isOpen) { _, isOpen in
            guard isOpen, !reduceMotion else { return }
            var cut = Transaction()
            cut.disablesAnimations = true
            withTransaction(cut) { stretch = Self.stretch(forSpeed: model.entranceSpeed) }
            withAnimation(Self.settle) { stretch = 0 }
        }
        .accessibilityHidden(true)
    }

    // MARK: The stack

    private struct Slot: Identifiable {
        let id: Int
        /// The card's place in the deck; past the deck's end, a blank sheet behind a book's card.
        let index: Int
        /// 0 is the front card; behind it 1, 2…; -1 the card just sent on.
        let depth: Int
    }

    /// The cards drawn: the one just sent on (so it can come back), the front, those behind and
    /// one more out of sight (so the next comes in from the stack). Keyed by place in the deck,
    /// so a flip moves each card to its new place; under Reduce Motion by depth, so the cards
    /// stay put and their faces change.
    private func slots(of deck: ChapterDeck) -> [Slot] {
        let front = deck.frontIndex
        let first = reduceMotion ? front : max(0, front - 1)
        let last = min(deck.count - 1, front + Self.cardsBehind + (reduceMotion ? 0 : 1))
        return (first...last).map { index in
            Slot(id: reduceMotion ? index - front : index, index: index, depth: index - front)
        }
    }

    /// Away from the page: down for the foot's stack, up for the top's.
    private func far(_ deck: ChapterDeck) -> CGFloat { deck.edge == .bottom ? 1 : -1 }

    private func card(_ slot: Slot, in deck: ChapterDeck) -> some View {
        let sheet = RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        let depth = slot.depth
        let isFront = depth == 0
        // Behind: fanned out once open, closed up to a sliver while the finger still pulls and
        // for a moment as another book's card arrives.
        let fanned = model.isOpen && !isClosedUp ? peek : peek * Self.closedFan
        let behind = min(depth, Self.cardsBehind)
        var offset = depth < 0 ? -far(deck) * cardHeight * Self.sendTravel : far(deck) * CGFloat(behind) * fanned
        // The front card rides a flick a little, onward only.
        if isFront, model.dragTravel > 0, !reduceMotion { offset -= far(deck) * min(model.dragTravel, cardHeight) * 0.5 }
        return face(slot.index, in: deck, isFront: isFront)
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .background(sheet.fill(Color.paperOverlay))
            .overlay(sheet.strokeBorder(Color.inkRule, lineWidth: 1))
            .contentShape(sheet)
            .onTapGesture { if isFront { model.chooseFront() } }
            .scaleEffect(depth > 0 ? 1 - CGFloat(behind) * Self.scaleStep : 1, anchor: deck.edge == .bottom ? .bottom : .top)
            .offset(y: offset)
            .opacity(depth < 0 || depth > Self.cardsBehind ? 0 : 1)
            .zIndex(Double(-depth))
            .allowsHitTesting(isFront)
    }

    /// The face of the card at `index`: a chapter of this book, another book's title card (the
    /// first of its cards), or a later chapter of another book, set as this book's are. Only the
    /// front card shows its face; a card behind is a blank sheet's edge.
    @ViewBuilder
    private func face(_ index: Int, in deck: ChapterDeck, isFront: Bool) -> some View {
        if let other = deck.other(at: index) {
            if deck.isBook(at: index) {
                bookFace(other, isNext: deck.edge == .bottom).opacity(isFront ? 1 : 0)
            } else {
                face(other.chapter, verses: model.verses(for: other), isFront: isFront)
            }
        } else if index < deck.cards.count {
            face(deck.cards[index], verses: model.verses(for: deck.cards[index]), isFront: isFront)
        } else {
            Color.clear
        }
    }

    /// A neighbouring book's card (Matt chose the title card, 2026-11-13): a small title page.
    /// "Next book" or "Previous book" in the style's running-head voice, the book's name in the
    /// style's title face, a short rule, and the opening words of the chapter it opens, centred.
    private func bookFace(_ book: ChapterSwitcher.BookEnd, isNext: Bool) -> some View {
        // The name a size down from the page's title, so the card's four lines sit with even
        // air above "Next book" and below the opening words (Matt, 2026-11-13: the label sat too
        // near the card's top edge).
        VStack(spacing: 0) {
            Text(verbatim: Self.bookLabel(isNext: isNext, style: typography.style))
                .font(Font(Self.labelFont(for: typography, size: labelSize)))
                .kerning(Self.labelKern(for: typography, size: labelSize))
                .foregroundStyle(Color(platform: typography.runningHeadColor))
                .lineLimit(1)
            Text(verbatim: book.name)
                .font(Font(Self.bookNameFont(for: typography, size: bookNameSize)))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, AppSpacing.xxs)
            Rectangle()
                .fill(Color.inkRule)
                .frame(width: AppSpacing.xl, height: 1)
                .padding(.vertical, AppSpacing.xs)
            Self.words(model.verses(for: book), typography: typography, size: wordsSize, ink: .inkSecondary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        // The label's capitals reach the top of its line while the last line keeps room for its
        // descenders: a little more above evens what the eye sees.
        .padding(.top, AppSpacing.xxs)
        .padding(.horizontal, padding)
    }

    /// A card's face: "Chapter" over its number, and the chapter's opening verses beside them.
    /// Only the front card shows its face; a card behind is a blank sheet's edge.
    private func face(_ chapter: Int, verses: [ChapterSwitcher.Verse], isFront: Bool) -> some View {
        HStack(alignment: .center, spacing: padding) {
            VStack(spacing: 0) {
                Text(verbatim: Self.label(for: typography.style))
                    .font(Font(Self.labelFont(for: typography, size: labelSize)))
                    .kerning(Self.labelKern(for: typography, size: labelSize))
                    .foregroundStyle(Color(platform: typography.runningHeadColor))
                    .lineLimit(1)
                    .fixedSize()
                Text(verbatim: "\(chapter)")
                    .font(Font(Self.numeralFont(for: typography, size: numeralSize)))
                    .foregroundStyle(Color.accent)
                    .lineLimit(1)
                    .fixedSize()
            }
            Self.words(verses, typography: typography, size: wordsSize)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, padding)
        .opacity(isFront ? 1 : 0)
    }

    // MARK: The page style on a card

    /// "Next book" or "Previous book", in the case the style's running head is set in.
    static func bookLabel(isNext: Bool, style: PageStyle) -> String {
        let label = isNext ? "Next book" : "Previous book"
        switch style {
        case .printed, .study: return label.uppercased()
        case .lectern, .classic: return label
        }
    }

    /// The book's name on its card: the style's title face (its weight and features) at `size`.
    static func bookNameFont(for typography: ReaderTypography, size: CGFloat) -> CTFont {
        CTFontCreateCopyWithAttributes(typography.titleFont as CTFont, size, nil, nil)
    }

    /// "Chapter", in the case the style's running head is set in.
    static func label(for style: PageStyle) -> String {
        switch style {
        case .printed, .study: "CHAPTER"
        case .lectern, .classic: "Chapter"
        }
    }

    /// The label's face: the style's running-head voice (its face, weight and features) at `size`.
    static func labelFont(for typography: ReaderTypography, size: CGFloat) -> CTFont {
        CTFontCreateCopyWithAttributes(typography.runningHeadFont as CTFont, size, nil, nil)
    }

    /// The running head's tracking, kept in its ratio to the size.
    static func labelKern(for typography: ReaderTypography, size: CGFloat) -> CGFloat {
        let voice = typography.runningHeadFont.pointSize
        return voice > 0 ? typography.runningHeadKern / voice * size : 0
    }

    /// The card's numeral: the page face in lining figures, as Lectern's drop numeral is, in
    /// every page style, at `size`.
    static func numeralFont(for typography: ReaderTypography, size: CGFloat) -> CTFont {
        CTFontCreateCopyWithAttributes(DropNumeral.font(for: typography) as CTFont, size, nil, nil)
    }

    /// Whether `verse`'s number shows on a card: as on the page, not when the reader has turned
    /// numbers off, and not on verse 1 in Lectern, whose numeral stands for it.
    static func showsNumber(of verse: ChapterSwitcher.Verse, typography: ReaderTypography) -> Bool {
        typography.showsVerseNumbers && !(typography.style == .lectern && verse.number == 1)
    }

    /// The opening verses as the page sets them, at `size` for the body: each verse's number in
    /// the style's number face, ink and rise (all in their ratio to the body), then its text.
    static func words(_ verses: [ChapterSwitcher.Verse], typography: ReaderTypography, size: CGFloat, ink: Color = .inkPrimary) -> Text {
        let ratio = typography.bodyFont.pointSize > 0 ? size / typography.bodyFont.pointSize : 1
        let body = Font(CTFontCreateCopyWithAttributes(typography.bodyFont as CTFont, size, nil, nil))
        let number = Font(CTFontCreateCopyWithAttributes(typography.verseNumberFont as CTFont, typography.verseNumberFont.pointSize * ratio, nil, nil))
        var text = Text(verbatim: "")
        for (index, verse) in verses.enumerated() {
            if showsNumber(of: verse, typography: typography) {
                text = text + Text(verbatim: "\(verse.number)\u{00A0}")
                    .font(number)
                    .baselineOffset(typography.verseNumberBaselineOffset * ratio)
                    .foregroundColor(Color(platform: typography.verseNumberColor))
            }
            text = text + Text(verbatim: index == verses.count - 1 ? verse.text : verse.text + " ")
                .font(body)
                .foregroundColor(ink)
        }
        return text
    }
}
#endif
